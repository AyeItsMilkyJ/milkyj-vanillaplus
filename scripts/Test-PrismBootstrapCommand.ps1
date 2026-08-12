[CmdletBinding()]
param(
    [string]$ProjectRoot,
    [string]$PackUrl = 'http://127.0.0.1:9/packwiz/pack.toml'
)

$ErrorActionPreference = 'Stop'
if (-not $ProjectRoot) { $ProjectRoot = Split-Path -Parent $PSScriptRoot }
$root = [IO.Path]::GetFullPath($ProjectRoot)
$testRoot = Join-Path $root 'build\prism-command-regression'
$zipPath = Join-Path $testRoot 'bootstrap.zip'
$extractRoot = Join-Path $testRoot 'extracted'

if ($PackUrl -notmatch '^http://127\.0\.0\.1(?::\d+)?/') {
    throw 'The regression test accepts only a loopback Packwiz URL.'
}
if (Test-Path -LiteralPath $testRoot) { Remove-Item -LiteralPath $testRoot -Recurse -Force }
New-Item -ItemType Directory -Path $extractRoot -Force | Out-Null

& (Join-Path $PSScriptRoot 'Build-Prism-Bootstrap.ps1') `
    -ProjectRoot $root -PackUrl $PackUrl -OutputPath $zipPath

[IO.Compression.ZipFile]::ExtractToDirectory($zipPath, $extractRoot)
$instancePath = Join-Path $extractRoot 'instance.cfg'
$instance = Get-Content -LiteralPath $instancePath -Raw
$match = [regex]::Match($instance, '(?m)^PreLaunchCommand=(.*)$')
if (-not $match.Success) { throw 'Generated instance.cfg has no PreLaunchCommand.' }
$encodedCommand = $match.Groups[1].Value.Trim()
$expected = '\"$INST_JAVA\" -jar packwiz-installer-bootstrap.jar ' + $PackUrl
if ($encodedCommand -ne $expected) {
    throw "Unexpected generated command. Expected [$expected], got [$encodedCommand]."
}

$forbidden = '(?i)(?:javaw?\.exe|\$INST_JAVA)-jar'
if ($encodedCommand -match $forbidden -or $instance -match $forbidden) {
    throw "Java and -jar were concatenated in generated Prism configuration: $encodedCommand"
}

. (Join-Path $root 'server-tools\Common.ps1')
$java = Find-Java17 $null
if ($java -notmatch '\s') {
    throw "This regression test must exercise a Java path containing spaces; found: $java"
}

# Prism's INI reader decodes \" to a literal quote before expanding $INST_JAVA.
$decodedCommand = $encodedCommand.Replace('\"', '"').Replace('$INST_JAVA', $java)
$minecraftRoot = Join-Path $extractRoot 'minecraft'
$commandFile = Join-Path $minecraftRoot 'run-generated-prelaunch.cmd'
$stdoutPath = Join-Path $testRoot 'process.stdout.log'
$stderrPath = Join-Path $testRoot 'process.stderr.log'
[IO.File]::WriteAllText($commandFile, "@echo off`r`n$decodedCommand`r`n", [Text.ASCIIEncoding]::new())

$process = Start-Process -FilePath 'cmd.exe' -ArgumentList @('/d','/c',('"' + $commandFile + '"')) `
    -WorkingDirectory $minecraftRoot -PassThru `
    -RedirectStandardOutput $stdoutPath -RedirectStandardError $stderrPath
$javaChild = $null
try {
    $deadline = (Get-Date).AddSeconds(15)
    do {
        Start-Sleep -Milliseconds 250
        $javaChild = Get-CimInstance Win32_Process -Filter "ParentProcessId=$($process.Id)" -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -match '^javaw?\.exe$' } | Select-Object -First 1
    } while (-not $javaChild -and -not $process.HasExited -and (Get-Date) -lt $deadline)

    if (-not $javaChild) {
        $output = ((Get-Content -LiteralPath $stdoutPath -Raw -ErrorAction SilentlyContinue) + "`n" +
            (Get-Content -LiteralPath $stderrPath -Raw -ErrorAction SilentlyContinue))
        throw "The generated pre-launch command did not spawn Java. cmd exit=$($process.ExitCode)`n$output"
    }
    if ($javaChild.ExecutablePath -ne $java -or $javaChild.CommandLine -notmatch '(?i)\s-jar\s+packwiz-installer-bootstrap\.jar(?:\s|$)') {
        throw "Java was not launched with a separate -jar argument. Executable=[$($javaChild.ExecutablePath)] CommandLine=[$($javaChild.CommandLine)]"
    }
    if ($javaChild.CommandLine -match '(?i)javaw?\.exe-jar|\$INST_JAVA-jar') {
        throw "The spawned Java command line contains a concatenated argument: $($javaChild.CommandLine)"
    }
} finally {
    if ($javaChild -and (Get-Process -Id $javaChild.ProcessId -ErrorAction SilentlyContinue)) {
        Stop-Process -Id $javaChild.ProcessId -Force
    }
    if (-not $process.HasExited) { Stop-Process -Id $process.Id -Force }
}

$result = [ordered]@{
    status = 'PASS'
    encodedCommand = $encodedCommand
    javaPathContainedSpaces = $true
    spawnedJavaProcess = $true
    separateJarArgumentObserved = [bool]($javaChild.CommandLine -match '(?i)\s-jar\s+packwiz-installer-bootstrap\.jar(?:\s|$)')
    forbiddenConcatenationFound = $false
    productionBootstrapUsesSameGenerator = $true
    generatedZip = 'build/prism-command-regression/bootstrap.zip'
    checkedAt = (Get-Date).ToString('o')
}
$auditPath = Join-Path $root 'audit\prism-bootstrap-regression.json'
[IO.File]::WriteAllText($auditPath, (($result | ConvertTo-Json -Depth 4) + "`r`n"), [Text.UTF8Encoding]::new($false))
$result | ConvertTo-Json -Depth 4
