[CmdletBinding()]
param(
    [string]$ProjectRoot = (Split-Path -Parent $PSScriptRoot),
    [string]$ForgeLibrariesPath,
    [switch]$SkipServerLaunch
)

$ErrorActionPreference = 'Stop'
$projectRootResolved = [IO.Path]::GetFullPath($ProjectRoot)
if (-not $ForgeLibrariesPath) { $ForgeLibrariesPath = Join-Path $projectRootResolved '.tools\forge-libraries' }
$testRoot = Join-Path $projectRootResolved 'build\end-to-end'
if (-not $testRoot.StartsWith(($projectRootResolved.TrimEnd('\') + '\'), [StringComparison]::OrdinalIgnoreCase)) {
    throw "Unsafe validation path: $testRoot"
}
if (Test-Path -LiteralPath $testRoot) { Remove-Item -LiteralPath $testRoot -Recurse -Force }
$hostRoot = Join-Path $testRoot 'host'
$clientRoot = Join-Path $testRoot 'client'
$serverRoot = Join-Path $testRoot 'server'
New-Item -ItemType Directory -Path $hostRoot, $clientRoot, $serverRoot -Force | Out-Null
Copy-Item -LiteralPath (Join-Path $projectRootResolved 'packwiz') -Destination (Join-Path $hostRoot 'packwiz') -Recurse
Copy-Item -LiteralPath (Join-Path $projectRootResolved 'payload') -Destination (Join-Path $hostRoot 'payload') -Recurse

$listener = [Net.Sockets.TcpListener]::new([Net.IPAddress]::Loopback, 0)
$listener.Start(); $port = ([Net.IPEndPoint]$listener.LocalEndpoint).Port; $listener.Stop()
$localBase = "http://127.0.0.1:$port"
$localPackUrl = "$localBase/packwiz/pack.toml"
foreach ($metadata in Get-ChildItem -LiteralPath (Join-Path $hostRoot 'packwiz') -Recurse -File -Filter *.pw.toml) {
    $text = [IO.File]::ReadAllText($metadata.FullName)
    if ($text -notmatch '(?m)^url\s*=\s*"https?://[^\"]+/payload/') { continue }
    $newText = [regex]::Replace($text, '(?m)^(url\s*=\s*")https?://[^\"]+(/payload/)', ('$1' + $localBase + '$2'))
    [IO.File]::WriteAllText($metadata.FullName, $newText, [Text.UTF8Encoding]::new($false))
}
& (Join-Path $PSScriptRoot 'Update-PackMetadata.ps1') -ProjectRoot $hostRoot
& (Join-Path $PSScriptRoot 'Validate-Pack.ps1') -ProjectRoot $hostRoot -AllowPlaceholder

$python = (Get-Command python -ErrorAction Stop).Source
$httpOut = Join-Path $testRoot 'http.stdout.log'
$httpErr = Join-Path $testRoot 'http.stderr.log'
$serverScript = Join-Path $PSScriptRoot 'limited_http_server.py'
$httpProcess = Start-Process -FilePath $python -ArgumentList @(('"' + $serverScript + '"'),'--port',"$port",'--directory',('"' + $hostRoot + '"'),'--workers','24') -WindowStyle Hidden -RedirectStandardOutput $httpOut -RedirectStandardError $httpErr -PassThru
try {
    $deadline = (Get-Date).AddSeconds(20)
    do {
        try { $null = Invoke-WebRequest -Uri $localPackUrl -UseBasicParsing -TimeoutSec 2; $ready = $true } catch { Start-Sleep -Milliseconds 250 }
    } while (-not $ready -and (Get-Date) -lt $deadline)
    if (-not $ready) { throw "Local Packwiz test host did not start. See $httpErr" }

    . (Join-Path $projectRootResolved 'server-tools\Common.ps1')
    $java = Find-Java17 $null
    $bootstrap = & (Join-Path $PSScriptRoot 'Get-PackwizInstaller.ps1') -ProjectRoot $projectRootResolved -PassThru

    [IO.File]::WriteAllText((Join-Path $clientRoot 'options.txt'), 'personal-sentinel=true', [Text.UTF8Encoding]::new($false))
    [IO.File]::WriteAllText((Join-Path $clientRoot 'optionsshaders.txt'), 'shader-settings-sentinel=true', [Text.UTF8Encoding]::new($false))
    New-Item -ItemType Directory -Path (Join-Path $clientRoot 'screenshots'), (Join-Path $clientRoot 'saves\personal-world'), (Join-Path $clientRoot 'shaderpacks') -Force | Out-Null
    [IO.File]::WriteAllText((Join-Path $clientRoot 'screenshots\personal-sentinel.txt'), 'keep me', [Text.UTF8Encoding]::new($false))
    [IO.File]::WriteAllText((Join-Path $clientRoot 'saves\personal-world\level.dat'), 'save-sentinel', [Text.UTF8Encoding]::new($false))
    [IO.File]::WriteAllText((Join-Path $clientRoot 'shaderpacks\personal-sentinel.txt'), 'shaderpack-sentinel', [Text.UTF8Encoding]::new($false))
    Copy-Item -LiteralPath $bootstrap -Destination (Join-Path $clientRoot 'packwiz-installer-bootstrap.jar')
    Push-Location $clientRoot
    try { & $java -jar 'packwiz-installer-bootstrap.jar' -g -s client $localPackUrl; $clientExit = $LASTEXITCODE } finally { Pop-Location }
    if ($clientExit -ne 0) { throw "Client Packwiz installation failed with exit code $clientExit" }
    if ((Get-Content -LiteralPath (Join-Path $clientRoot 'options.txt') -Raw) -ne 'personal-sentinel=true') { throw 'Packwiz overwrote options.txt.' }
    if ((Get-Content -LiteralPath (Join-Path $clientRoot 'optionsshaders.txt') -Raw) -ne 'shader-settings-sentinel=true') { throw 'Packwiz overwrote shader settings.' }
    if (-not (Test-Path -LiteralPath (Join-Path $clientRoot 'screenshots\personal-sentinel.txt'))) { throw 'Packwiz removed a personal screenshot sentinel.' }
    if (-not (Test-Path -LiteralPath (Join-Path $clientRoot 'saves\personal-world\level.dat'))) { throw 'Packwiz removed a personal save sentinel.' }
    if (-not (Test-Path -LiteralPath (Join-Path $clientRoot 'shaderpacks\personal-sentinel.txt'))) { throw 'Packwiz removed a personal shaderpack sentinel.' }
    $clientJars = @(Get-ChildItem -LiteralPath (Join-Path $clientRoot 'mods') -File -Filter *.jar)
    if ($clientJars.Count -ne 236) { throw "Expected 236 client JARs; installed $($clientJars.Count)." }

    Copy-Item -LiteralPath $bootstrap -Destination (Join-Path $serverRoot 'packwiz-installer-bootstrap.jar')
    Push-Location $serverRoot
    try { & $java -jar 'packwiz-installer-bootstrap.jar' -g -s server $localPackUrl; $serverExit = $LASTEXITCODE } finally { Pop-Location }
    if ($serverExit -ne 0) { throw "Server Packwiz installation failed with exit code $serverExit" }
    $serverJars = @(Get-ChildItem -LiteralPath (Join-Path $serverRoot 'mods') -File -Filter *.jar)
    if ($serverJars.Count -ne 203) { throw "Expected 203 server JARs; installed $($serverJars.Count)." }

    if (-not $SkipServerLaunch) {
        $forgeLibrariesResolved = [IO.Path]::GetFullPath($ForgeLibrariesPath)
        if (-not (Test-Path -LiteralPath (Join-Path $forgeLibrariesResolved 'net\minecraftforge\forge\1.20.1-47.4.10\win_args.txt') -PathType Leaf)) {
            throw "Disposable Forge libraries are missing. Populate the ignored test cache first: $forgeLibrariesResolved"
        }
        Copy-Item -LiteralPath $forgeLibrariesResolved -Destination (Join-Path $serverRoot 'libraries') -Recurse
        [IO.File]::WriteAllText((Join-Path $serverRoot 'eula.txt'), "eula=true`r`n", [Text.UTF8Encoding]::new($false))
        [IO.File]::WriteAllText((Join-Path $serverRoot 'user_jvm_args.txt'), "-Xms1G`r`n-Xmx4G`r`n", [Text.UTF8Encoding]::new($false))
        $validationPort = $port + 1
        $serverProperties = @(
            'allow-flight=true',
            'difficulty=normal',
            'enable-command-block=false',
            'gamemode=survival',
            'level-name=validation_world',
            'max-players=2',
            'motd=Packwiz validation',
            'online-mode=false',
            "server-port=$validationPort",
            'simulation-distance=4',
            'spawn-protection=0',
            'view-distance=6'
        ) -join "`r`n"
        [IO.File]::WriteAllText((Join-Path $serverRoot 'server.properties'), ($serverProperties + "`r`n"), [Text.UTF8Encoding]::new($false))

        $startInfo = [Diagnostics.ProcessStartInfo]::new()
        $startInfo.FileName = $java
        $startInfo.WorkingDirectory = $serverRoot
        $startInfo.Arguments = '@user_jvm_args.txt @libraries/net/minecraftforge/forge/1.20.1-47.4.10/win_args.txt nogui'
        $startInfo.UseShellExecute = $false
        $startInfo.RedirectStandardInput = $true
        $startInfo.RedirectStandardOutput = $true
        $startInfo.RedirectStandardError = $true
        $process = [Diagnostics.Process]::new(); $process.StartInfo = $startInfo
        if (-not $process.Start()) { throw 'Validation server process did not start.' }
        $stdoutTask = $process.StandardOutput.ReadToEndAsync()
        $stderrTask = $process.StandardError.ReadToEndAsync()
        $launchDeadline = (Get-Date).AddMinutes(6)
        $latestLog = Join-Path $serverRoot 'logs\latest.log'
        $done = $false
        do {
            Start-Sleep -Seconds 2
            if (Test-Path -LiteralPath $latestLog) {
                $done = [bool](Select-String -LiteralPath $latestLog -SimpleMatch 'Done (' -Quiet)
            }
            if ($process.HasExited -and -not $done) { break }
        } while (-not $done -and (Get-Date) -lt $launchDeadline)
        if (-not $done) {
            if (-not $process.HasExited) { $process.Kill() }
            $process.WaitForExit()
            [IO.File]::WriteAllText((Join-Path $testRoot 'server.stdout.log'), $stdoutTask.Result)
            [IO.File]::WriteAllText((Join-Path $testRoot 'server.stderr.log'), $stderrTask.Result)
            throw 'Disposable Forge server did not reach Done. Logs were retained in build/end-to-end.'
        }
        $process.StandardInput.WriteLine('stop'); $process.StandardInput.Flush()
        $serverProcessExited = $process.WaitForExit(180000)
        $savedAllDimensions = [bool](Select-String -LiteralPath $latestLog -SimpleMatch 'ThreadedAnvilChunkStorage: All dimensions are saved' -Quiet)
        $questParserLoaded = [bool](Select-String -LiteralPath $latestLog -Pattern 'Loaded 4 chapter groups, 9 chapters, 118 quests, 0 reward tables' -Quiet)
        if (-not $serverProcessExited) {
            $process.Kill()
            if (-not $savedAllDimensions) { throw 'Disposable Forge server neither exited nor confirmed that all dimensions were saved.' }
            Write-Warning 'Disposable server saved all dimensions, but a lingering mod thread kept the validation JVM alive. The process was cleaned up after the save completed.'
        }
        [IO.File]::WriteAllText((Join-Path $testRoot 'server.stdout.log'), $stdoutTask.Result)
        [IO.File]::WriteAllText((Join-Path $testRoot 'server.stderr.log'), $stderrTask.Result)
        if ($serverProcessExited -and $process.ExitCode -ne 0) { throw "Disposable Forge server exited with code $($process.ExitCode)." }
        if (-not $questParserLoaded) { throw 'FTB Quests did not report the expected 9 chapters and 118 quests.' }
        if (-not $savedAllDimensions) { throw 'Disposable server did not confirm that all loaded dimensions were saved.' }
    }

    $report = [ordered]@{
        testedAt = (Get-Date).ToString('o')
        packUrl = $localPackUrl
        clientJarCount = $clientJars.Count
        serverJarCount = $serverJars.Count
        personalFilesPreserved = $true
        personalOptionsPreserved = $true
        personalKeybindContainerPreserved = $true
        personalScreenshotsPreserved = $true
        personalSavesPreserved = $true
        personalShaderSettingsPreserved = $true
        serverReachedDone = (-not $SkipServerLaunch)
        questParserLoaded = if ($SkipServerLaunch) { $null } else { $questParserLoaded }
        allLoadedDimensionsSaved = if ($SkipServerLaunch) { $null } else { $savedAllDimensions }
        serverProcessExited = if ($SkipServerLaunch) { $null } else { $serverProcessExited }
    }
    $report | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $testRoot 'result.json') -Encoding utf8
    Write-Host "End-to-end Packwiz validation passed. Report: $(Join-Path $testRoot 'result.json')"
} finally {
    if ($httpProcess -and -not $httpProcess.HasExited) { Stop-Process -Id $httpProcess.Id -Force }
}
