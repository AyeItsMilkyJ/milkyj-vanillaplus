[CmdletBinding()]
param(
    [string]$ProjectRoot,
    [ValidateNotNullOrEmpty()]
    [string]$BaselineRef = 'v1.0.0',
    [string]$ReportPath
)

$ErrorActionPreference = 'Stop'
if (-not $ProjectRoot) { $ProjectRoot = Split-Path -Parent $PSScriptRoot }
$projectRootResolved = [IO.Path]::GetFullPath($ProjectRoot)
$baselineCommit = @(& git -C $projectRootResolved rev-parse --verify "$BaselineRef^{commit}" 2>$null) | Select-Object -Last 1
if ($LASTEXITCODE -ne 0 -or -not $baselineCommit) { throw "Could not resolve local baseline ref '$BaselineRef' to a commit." }
$baselineCommit = ([string]$baselineCommit).Trim()
if (-not $ReportPath) { $ReportPath = Join-Path $projectRootResolved 'audit\packwiz-update-rollback.json' }
$reportPathResolved = if ([IO.Path]::IsPathRooted($ReportPath)) {
    [IO.Path]::GetFullPath($ReportPath)
}
else {
    [IO.Path]::GetFullPath((Join-Path $projectRootResolved $ReportPath))
}
$projectPathPrefix = $projectRootResolved.TrimEnd('\') + '\'
if (-not $reportPathResolved.StartsWith($projectPathPrefix, [StringComparison]::OrdinalIgnoreCase)) {
    throw "Rollback validation reports must remain inside the disposable project workspace: $reportPathResolved"
}
$temporaryRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\')
$testRoot = [IO.Path]::GetFullPath((Join-Path $temporaryRoot "milkycraft-packwiz-rollback-$PID"))
$temporaryPathPrefix = $temporaryRoot + '\'
if (-not $testRoot.StartsWith($temporaryPathPrefix, [StringComparison]::OrdinalIgnoreCase) -or
    (Split-Path -Leaf $testRoot) -ne "milkycraft-packwiz-rollback-$PID") {
    throw "Unsafe validation path: $testRoot"
}
if (Test-Path -LiteralPath $testRoot) { Remove-Item -LiteralPath $testRoot -Recurse -Force }
$hostRoot = Join-Path $testRoot 'host'
$baselineRoot = Join-Path $hostRoot 'baseline'
$rcRoot = Join-Path $hostRoot 'rc'
$clientRoot = Join-Path $testRoot 'client'
New-Item -ItemType Directory -Path $hostRoot, $baselineRoot, $rcRoot, $clientRoot -Force | Out-Null

$baselineArchive = Join-Path $testRoot 'baseline.zip'
& git -C $projectRootResolved archive --format=zip --output=$baselineArchive $baselineCommit -- packwiz payload project-settings.json
if ($LASTEXITCODE -ne 0) { throw "Could not materialise local baseline '$BaselineRef' ($baselineCommit)." }
Add-Type -AssemblyName System.IO.Compression.FileSystem
[IO.Compression.ZipFile]::ExtractToDirectory($baselineArchive, $baselineRoot)
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

    # This title is new in the rc4 quest expansion and is absent from rc3. The
    # file also exists in rc3, so the exact rc3 -> rc4 run proves a changed
    # managed quest is installed and then byte-for-byte restored.
    $questRelative = 'config\ftbquests\quests\chapters\create_projects.snbt'
    $candidateQuestProbe = 'title: "Put an Off Switch on the Damn Thing"'
    $baselineHostedQuestPath = Join-Path $baselineRoot "payload\both\$questRelative"
    $candidateHostedQuestPath = Join-Path $rcRoot "payload\both\$questRelative"
    $baselineQuestPresent = Test-Path -LiteralPath $baselineHostedQuestPath -PathType Leaf
    $baselineExpectedHash = if ($baselineQuestPresent) {
        (Get-FileHash -LiteralPath $baselineHostedQuestPath -Algorithm SHA256).Hash.ToLowerInvariant()
    }
    else {
        $null
    }
    if ($baselineQuestPresent -and [IO.File]::ReadAllText($baselineHostedQuestPath).Contains($candidateQuestProbe)) {
        throw "Baseline '$BaselineRef' already contains the rc4 quest probe; choose an older baseline or update the probe."
    }
    if (-not (Test-Path -LiteralPath $candidateHostedQuestPath -PathType Leaf)) {
        throw "Candidate quest probe file is missing: $questRelative"
    }
    if (-not [IO.File]::ReadAllText($candidateHostedQuestPath).Contains($candidateQuestProbe)) {
        throw "Candidate quest probe was not found in $questRelative"
    }
    $rcExpectedHash = (Get-FileHash -LiteralPath $candidateHostedQuestPath -Algorithm SHA256).Hash.ToLowerInvariant()

    Invoke-Install $baselineUrl
    Assert-PersonalFiles
    $installedQuestPath = Join-Path $clientRoot $questRelative
    if ($baselineQuestPresent) {
        if (-not (Test-Path -LiteralPath $installedQuestPath -PathType Leaf)) { throw "Initial '$BaselineRef' quest probe file was not installed." }
        $baselineInstalledHash = (Get-FileHash -LiteralPath $installedQuestPath -Algorithm SHA256).Hash.ToLowerInvariant()
        if ($baselineInstalledHash -ne $baselineExpectedHash) { throw "Initial '$BaselineRef' quest payload does not match its baseline host." }
    }
    else {
        $baselineInstalledHash = $null
        if (Test-Path -LiteralPath $installedQuestPath) { throw "Initial '$BaselineRef' unexpectedly installed the candidate quest probe file." }
    }
    $baselineClientJarCount = @(Get-ChildItem -LiteralPath (Join-Path $clientRoot 'mods') -File -Filter '*.jar').Count

    Invoke-Install $rcUrl
    Assert-PersonalFiles
    if (-not (Test-Path -LiteralPath $installedQuestPath -PathType Leaf)) { throw 'The candidate quest probe file was not installed.' }
    $rcInstalledHash = (Get-FileHash -LiteralPath $installedQuestPath -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($rcInstalledHash -ne $rcExpectedHash -or ($baselineQuestPresent -and $rcInstalledHash -eq $baselineInstalledHash)) {
        throw "The candidate quest payload was not applied over '$BaselineRef'."
    }
    $candidateQuestProbeApplied = [IO.File]::ReadAllText($installedQuestPath).Contains($candidateQuestProbe)
    if (-not $candidateQuestProbeApplied) { throw 'The rc4 quest-content probe was not present after the candidate update.' }
    $candidateClientJarCount = @(Get-ChildItem -LiteralPath (Join-Path $clientRoot 'mods') -File -Filter '*.jar').Count
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
    foreach ($relative in $compatibilityFiles) {
        if (-not (Test-Path -LiteralPath (Join-Path $clientRoot $relative) -PathType Leaf)) {
            throw "Integrated compatibility file was not installed by the candidate: $relative"
        }
    }

    Invoke-Install $baselineUrl
    Assert-PersonalFiles
    if ($baselineQuestPresent) {
        if (-not (Test-Path -LiteralPath $installedQuestPath -PathType Leaf)) { throw "Rollback removed the '$BaselineRef' quest probe file instead of restoring it." }
        $rollbackHash = (Get-FileHash -LiteralPath $installedQuestPath -Algorithm SHA256).Hash.ToLowerInvariant()
        if ($rollbackHash -ne $baselineExpectedHash) { throw "Rollback did not restore the '$BaselineRef' managed quest payload." }
    }
    else {
        $rollbackHash = $null
        if (Test-Path -LiteralPath $installedQuestPath) { throw "Rollback did not remove the candidate-only quest probe file for '$BaselineRef'." }
    }
    $candidateQuestProbeRemoved = -not (Test-Path -LiteralPath $installedQuestPath -PathType Leaf) -or
        -not [IO.File]::ReadAllText($installedQuestPath).Contains($candidateQuestProbe)
    if (-not $candidateQuestProbeRemoved) { throw 'Rollback left the rc4 quest-content probe installed.' }
    $obsoleteRemoved = -not (Test-Path -LiteralPath (Join-Path $clientRoot 'config\ftbquests\quests\rc-obsolete-validation-sentinel.txt'))
    if (-not $obsoleteRemoved) { throw 'Rollback did not remove an obsolete Packwiz-managed file.' }
    $compatibilityFilesRemoved = $true
    foreach ($relative in $compatibilityFiles) {
        if (Test-Path -LiteralPath (Join-Path $clientRoot $relative)) { $compatibilityFilesRemoved = $false }
    }
    if (-not $compatibilityFilesRemoved) { throw 'Rollback did not remove all candidate-only compatibility resources.' }

    $rollbackClientJarCount = @(Get-ChildItem -LiteralPath (Join-Path $clientRoot 'mods') -File -Filter '*.jar').Count
    if ($rollbackClientJarCount -ne $baselineClientJarCount) {
        throw "Rollback client JAR count $rollbackClientJarCount does not match the dynamically measured '$BaselineRef' count $baselineClientJarCount."
    }

    $settings = Get-Content -LiteralPath (Join-Path $projectRootResolved 'project-settings.json') -Raw | ConvertFrom-Json
    $baselinePackText = [IO.File]::ReadAllText((Join-Path $baselineRoot 'packwiz\pack.toml'))
    $baselineVersionMatch = [regex]::Match($baselinePackText, '(?m)^version\s*=\s*"([^"]+)"')
    $baselineVersion = if ($baselineVersionMatch.Success) { $baselineVersionMatch.Groups[1].Value } else { 'unknown' }
    $report = [ordered]@{
        testedAt = (Get-Date).ToString('o')
        baselineRef = $BaselineRef
        baselineCommit = $baselineCommit
        baselineVersion = $baselineVersion
        releaseCandidate = [string]$settings.packVersion
        questProbeFile = $questRelative.Replace('\', '/')
        questProbeText = $candidateQuestProbe
        baselineQuestPresent = $baselineQuestPresent
        baselineQuestHash = $baselineExpectedHash
        releaseCandidateQuestHash = $rcExpectedHash
        releaseCandidateApplied = $true
        candidateQuestProbeApplied = $candidateQuestProbeApplied
        candidateQuestProbeRemovedByRollback = $candidateQuestProbeRemoved
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
        baselineClientJarCount = $baselineClientJarCount
        candidateClientJarCount = $candidateClientJarCount
        rollbackClientJarCount = $rollbackClientJarCount
        liveFilesReadOrWritten = $false
        transport = 'local loopback HTTP only'
    }
    New-Item -ItemType Directory -Path (Split-Path -Parent $reportPathResolved) -Force | Out-Null
    [IO.File]::WriteAllText($reportPathResolved, (($report | ConvertTo-Json -Depth 5) + "`r`n"), [Text.UTF8Encoding]::new($false))
    $report | ConvertTo-Json -Depth 5
}
finally {
    if ($httpProcess -and -not $httpProcess.HasExited) { Stop-Process -Id $httpProcess.Id -Force }
}
