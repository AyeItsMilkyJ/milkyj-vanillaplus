[CmdletBinding()]
param(
    [string]$ProjectRoot
)

$ErrorActionPreference = 'Stop'
if (-not $ProjectRoot) { $ProjectRoot = Split-Path -Parent $PSScriptRoot }
$projectRootResolved = [IO.Path]::GetFullPath($ProjectRoot)
$testRoot = Join-Path $projectRootResolved 'build\rollback'
$expectedTestRoot = [IO.Path]::GetFullPath((Join-Path $projectRootResolved 'build\rollback'))
if (-not ([IO.Path]::GetFullPath($testRoot)).Equals($expectedTestRoot, [StringComparison]::OrdinalIgnoreCase)) {
    throw "Unsafe validation path: $testRoot"
}
if (Test-Path -LiteralPath $testRoot) { Remove-Item -LiteralPath $testRoot -Recurse -Force }
$hostRoot = Join-Path $testRoot 'host'
$baselineRoot = Join-Path $hostRoot 'baseline'
$rcRoot = Join-Path $hostRoot 'rc'
$clientRoot = Join-Path $testRoot 'client'
New-Item -ItemType Directory -Path $hostRoot, $baselineRoot, $rcRoot, $clientRoot -Force | Out-Null

$baselineArchive = Join-Path $testRoot 'v1.0.0.zip'
& git -C $projectRootResolved archive --format=zip --output=$baselineArchive v1.0.0 -- packwiz payload
if ($LASTEXITCODE -ne 0) { throw 'Could not materialise the local v1.0.0 baseline tag.' }
Expand-Archive -LiteralPath $baselineArchive -DestinationPath $baselineRoot
Copy-Item -LiteralPath (Join-Path $projectRootResolved 'packwiz') -Destination (Join-Path $rcRoot 'packwiz') -Recurse
Copy-Item -LiteralPath (Join-Path $projectRootResolved 'payload') -Destination (Join-Path $rcRoot 'payload') -Recurse
Copy-Item -LiteralPath (Join-Path $projectRootResolved 'project-settings.json') -Destination (Join-Path $rcRoot 'project-settings.json')

$listener = [Net.Sockets.TcpListener]::new([Net.IPAddress]::Loopback, 0)
$listener.Start(); $port = ([Net.IPEndPoint]$listener.LocalEndpoint).Port; $listener.Stop()
$localBase = "http://127.0.0.1:$port"

function Set-LocalHostedUrls([string]$PackProjectRoot, [string]$UrlPrefix) {
    foreach ($metadata in Get-ChildItem -LiteralPath (Join-Path $PackProjectRoot 'packwiz') -Recurse -File -Filter '*.pw.toml') {
        $text = [IO.File]::ReadAllText($metadata.FullName)
        if ($text -notmatch '(?m)^url\s*=\s*"https?://[^"]+/payload/') { continue }
        $updated = [regex]::Replace($text, '(?m)^(url\s*=\s*")https?://[^"]+(/payload/)', ('$1' + $UrlPrefix + '$2'))
        [IO.File]::WriteAllText($metadata.FullName, $updated, [Text.UTF8Encoding]::new($false))
    }
    & (Join-Path $PSScriptRoot 'Update-PackMetadata.ps1') -ProjectRoot $PackProjectRoot
}

Set-LocalHostedUrls -PackProjectRoot $baselineRoot -UrlPrefix "$localBase/baseline"
Set-LocalHostedUrls -PackProjectRoot $rcRoot -UrlPrefix "$localBase/rc"

# Add one host-only managed file to prove rollback removes obsolete Packwiz files.
$obsoleteSource = Join-Path $testRoot 'rc-obsolete-validation-sentinel.txt'
[IO.File]::WriteAllText($obsoleteSource, 'temporary managed rollback sentinel', [Text.UTF8Encoding]::new($false))
& (Join-Path $PSScriptRoot 'Add-HostedFile.ps1') -ProjectRoot $rcRoot -DestinationPath 'config/ftbquests/quests/rc-obsolete-validation-sentinel.txt' -Side both -SourcePath $obsoleteSource
Set-LocalHostedUrls -PackProjectRoot $rcRoot -UrlPrefix "$localBase/rc"

$python = (Get-Command python -ErrorAction Stop).Source
$httpOut = Join-Path $testRoot 'http.stdout.log'
$httpErr = Join-Path $testRoot 'http.stderr.log'
$serverScript = Join-Path $PSScriptRoot 'limited_http_server.py'
$httpProcess = Start-Process -FilePath $python -ArgumentList @(('"' + $serverScript + '"'), '--port', "$port", '--directory', ('"' + $hostRoot + '"'), '--workers', '24') -WindowStyle Hidden -RedirectStandardOutput $httpOut -RedirectStandardError $httpErr -PassThru
try {
    $baselineUrl = "$localBase/baseline/packwiz/pack.toml"
    $rcUrl = "$localBase/rc/packwiz/pack.toml"
    $deadline = (Get-Date).AddSeconds(20)
    do {
        try { $null = Invoke-WebRequest -Uri $baselineUrl -UseBasicParsing -TimeoutSec 2; $ready = $true }
        catch { Start-Sleep -Milliseconds 250 }
    } while (-not $ready -and (Get-Date) -lt $deadline)
    if (-not $ready) { throw "Local Packwiz rollback host did not start. See $httpErr" }

    . (Join-Path $projectRootResolved 'server-tools\Common.ps1')
    $java = Find-Java17 $null
    $bootstrap = & (Join-Path $PSScriptRoot 'Get-PackwizInstaller.ps1') -ProjectRoot $projectRootResolved -PassThru
    $mainInstaller = & (Join-Path $PSScriptRoot 'Get-PackwizInstaller.ps1') -ProjectRoot $projectRootResolved -MainJarPassThru
    Copy-Item -LiteralPath $bootstrap -Destination (Join-Path $clientRoot 'packwiz-installer-bootstrap.jar')
    Copy-Item -LiteralPath $mainInstaller -Destination (Join-Path $clientRoot 'packwiz-installer.jar')

    $sentinels = [ordered]@{
        'options.txt' = 'options-and-keybindings-sentinel'
        'optionsshaders.txt' = 'shader-settings-sentinel'
        'screenshots\sentinel.txt' = 'screenshot-sentinel'
        'saves\personal-world\level.dat' = 'save-sentinel'
        'shaderpacks\personal.txt' = 'shaderpack-sentinel'
    }
    foreach ($relative in $sentinels.Keys) {
        $path = Join-Path $clientRoot $relative
        New-Item -ItemType Directory -Path (Split-Path -Parent $path) -Force | Out-Null
        [IO.File]::WriteAllText($path, $sentinels[$relative], [Text.UTF8Encoding]::new($false))
    }

    function Invoke-Install([string]$PackUrl) {
        Push-Location $clientRoot
        try { & $java -jar 'packwiz-installer-bootstrap.jar' --bootstrap-no-update --bootstrap-main-jar 'packwiz-installer.jar' -g -s client $PackUrl; $exitCode = $LASTEXITCODE }
        finally { Pop-Location }
        if ($exitCode -ne 0) { throw "Packwiz install failed with exit code $exitCode for $PackUrl" }
    }

    function Assert-PersonalFiles {
        foreach ($relative in $sentinels.Keys) {
            $path = Join-Path $clientRoot $relative
            if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Personal sentinel was removed: $relative" }
            if ([IO.File]::ReadAllText($path) -ne $sentinels[$relative]) { throw "Personal sentinel was changed: $relative" }
        }
    }

    $questRelative = 'config\ftbquests\quests\chapters\create_basics.snbt'
    Invoke-Install $baselineUrl
    Assert-PersonalFiles
    $baselineInstalledHash = (Get-FileHash -LiteralPath (Join-Path $clientRoot $questRelative) -Algorithm SHA256).Hash.ToLowerInvariant()
    $baselineExpectedHash = (Get-FileHash -LiteralPath (Join-Path $baselineRoot "payload\both\$questRelative") -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($baselineInstalledHash -ne $baselineExpectedHash) { throw 'Initial v1.0.0 quest payload does not match its baseline host.' }

    Invoke-Install $rcUrl
    Assert-PersonalFiles
    $rcInstalledHash = (Get-FileHash -LiteralPath (Join-Path $clientRoot $questRelative) -Algorithm SHA256).Hash.ToLowerInvariant()
    $rcExpectedHash = (Get-FileHash -LiteralPath (Join-Path $rcRoot "payload\both\$questRelative") -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($rcInstalledHash -ne $rcExpectedHash -or $rcInstalledHash -eq $baselineInstalledHash) { throw 'The RC quest payload was not applied over v1.0.0.' }
    $obsoleteInstalled = Test-Path -LiteralPath (Join-Path $clientRoot 'config\ftbquests\quests\rc-obsolete-validation-sentinel.txt')
    if (-not $obsoleteInstalled) { throw 'Host-only RC managed sentinel was not installed.' }
    $rcBothRoot = Join-Path $rcRoot 'payload\both'
    $baselineBothRoot = Join-Path $baselineRoot 'payload\both'
    $compatibilityRoot = Join-Path $rcBothRoot 'moonlight-global-datapacks\milkyj-compat-fixes'
    $compatibilityFiles = @(
        Get-ChildItem -LiteralPath $compatibilityRoot -Recurse -File |
            ForEach-Object { $_.FullName.Substring($rcBothRoot.Length).TrimStart('\') } |
            Where-Object { -not (Test-Path -LiteralPath (Join-Path $baselineBothRoot $_) -PathType Leaf) } |
            Sort-Object
    )
    if ($compatibilityFiles.Count -ne 11) { throw "Expected 11 candidate-only compatibility resources; found $($compatibilityFiles.Count)." }
    foreach ($relative in $compatibilityFiles) {
        if (-not (Test-Path -LiteralPath (Join-Path $clientRoot $relative) -PathType Leaf)) {
            throw "Integrated compatibility file was not installed by the candidate: $relative"
        }
    }

    Invoke-Install $baselineUrl
    Assert-PersonalFiles
    $rollbackHash = (Get-FileHash -LiteralPath (Join-Path $clientRoot $questRelative) -Algorithm SHA256).Hash.ToLowerInvariant()
    $obsoleteRemoved = -not (Test-Path -LiteralPath (Join-Path $clientRoot 'config\ftbquests\quests\rc-obsolete-validation-sentinel.txt'))
    if ($rollbackHash -ne $baselineExpectedHash) { throw 'Rollback did not restore the v1.0.0 managed quest payload.' }
    if (-not $obsoleteRemoved) { throw 'Rollback did not remove an obsolete Packwiz-managed file.' }
    $compatibilityFilesRemoved = $true
    foreach ($relative in $compatibilityFiles) {
        if (Test-Path -LiteralPath (Join-Path $clientRoot $relative)) { $compatibilityFilesRemoved = $false }
    }
    if (-not $compatibilityFilesRemoved) { throw 'Rollback did not remove all candidate-only compatibility resources.' }

    $clientJarCount = @(Get-ChildItem -LiteralPath (Join-Path $clientRoot 'mods') -File -Filter '*.jar').Count
    if ($clientJarCount -ne 236) { throw "Expected 236 baseline client JARs after rollback; found $clientJarCount." }

    $report = [ordered]@{
        testedAt = (Get-Date).ToString('o')
        baselineTag = 'v1.0.0'
        releaseCandidate = '1.9.0-rc2'
        baselineQuestHash = $baselineExpectedHash
        releaseCandidateQuestHash = $rcExpectedHash
        releaseCandidateApplied = $true
        compatibilityFilesInstalledByCandidate = $true
        compatibilityFileCount = $compatibilityFiles.Count
        rollbackRestoredBaseline = $true
        compatibilityFilesRemovedByRollback = $compatibilityFilesRemoved
        obsoleteManagedFileInstalledForTest = $obsoleteInstalled
        obsoleteManagedFileRemovedOnRollback = $obsoleteRemoved
        personalOptionsAndKeybindingsPreserved = $true
        personalScreenshotsPreserved = $true
        personalSavesPreserved = $true
        personalShaderSettingsPreserved = $true
        personalShaderpacksPreserved = $true
        clientJarCount = $clientJarCount
        liveFilesReadOrWritten = $false
    }
    [IO.File]::WriteAllText((Join-Path $projectRootResolved 'audit\packwiz-update-rollback.json'), (($report | ConvertTo-Json -Depth 5) + "`r`n"), [Text.UTF8Encoding]::new($false))
    $report | ConvertTo-Json -Depth 5
}
finally {
    if ($httpProcess -and -not $httpProcess.HasExited) { Stop-Process -Id $httpProcess.Id -Force }
}
