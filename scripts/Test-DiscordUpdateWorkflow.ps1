[CmdletBinding()]
param([string]$ProjectRoot)

$ErrorActionPreference = 'Stop'
if (-not $ProjectRoot) { $ProjectRoot = Split-Path -Parent $PSScriptRoot }
$root = [IO.Path]::GetFullPath($ProjectRoot)
$testRoot = [IO.Path]::GetFullPath((Join-Path ([IO.Path]::GetTempPath()) 'milkycraft-discord-update-workflow'))
$expectedRoot = [IO.Path]::GetFullPath((Join-Path ([IO.Path]::GetTempPath()) 'milkycraft-discord-update-workflow'))
if (-not $testRoot.Equals($expectedRoot, [StringComparison]::OrdinalIgnoreCase)) { throw 'Unsafe Discord updater test root.' }
if (Test-Path -LiteralPath $testRoot) { Remove-Item -LiteralPath $testRoot -Recurse -Force }
New-Item -ItemType Directory -Path $testRoot -Force | Out-Null

$utf8 = [Text.UTF8Encoding]::new($false)
$productionUpdater = Join-Path $root 'server-tools\Update-Server.ps1'
$productionUpdaterHashBefore = (Get-FileHash -LiteralPath $productionUpdater -Algorithm SHA256).Hash

function Get-FreeLoopbackPort {
    $listener = [Net.Sockets.TcpListener]::new([Net.IPAddress]::Loopback, 0)
    try {
        $listener.Start()
        return ([Net.IPEndPoint]$listener.LocalEndpoint).Port
    } finally {
        $listener.Stop()
    }
}

function Wait-LoopbackPort([int]$Port, [string]$Description) {
    $deadline = (Get-Date).AddSeconds(20)
    do {
        try {
            $client = [Net.Sockets.TcpClient]::new()
            try {
                $client.Connect('127.0.0.1', $Port)
                if ($client.Connected) { return }
            } finally {
                $client.Dispose()
            }
        } catch {
            Start-Sleep -Milliseconds 100
        }
    } while ((Get-Date) -lt $deadline)
    throw "$Description did not start on loopback port $Port."
}

function Copy-DirectoryTree([string]$Source, [string]$Destination) {
    New-Item -ItemType Directory -Path $Destination -Force | Out-Null
    & robocopy.exe $Source $Destination /E /COPY:DAT /DCOPY:DAT /R:1 /W:1 /NFL /NDL /NJH /NJS /NP | Out-Null
    if ($LASTEXITCODE -ge 8) { throw "Robocopy failed with exit code $LASTEXITCODE while staging $Source." }
}

# Materialise and validate the current candidate locally. Rewriting happens only
# in this disposable copy, so the release metadata and production URLs are never
# changed by the workflow test.
$hostRoot = Join-Path $testRoot 'pack-host'
New-Item -ItemType Directory -Path $hostRoot -Force | Out-Null
Copy-DirectoryTree -Source (Join-Path $root 'packwiz') -Destination (Join-Path $hostRoot 'packwiz')
Copy-DirectoryTree -Source (Join-Path $root 'payload') -Destination (Join-Path $hostRoot 'payload')
$packPort = Get-FreeLoopbackPort
$localBase = "http://127.0.0.1:$packPort"
foreach ($metadata in Get-ChildItem -LiteralPath (Join-Path $hostRoot 'packwiz') -Recurse -File -Filter '*.pw.toml') {
    $text = [IO.File]::ReadAllText($metadata.FullName)
    if ($text -notmatch '(?m)^url\s*=\s*"https?://[^"]+/payload/') { continue }
    $updated = [regex]::Replace($text, '(?m)^(url\s*=\s*")https?://[^"]+(/payload/)', ('$1' + $localBase + '$2'))
    [IO.File]::WriteAllText($metadata.FullName, $updated, $utf8)
}
& (Join-Path $root 'scripts\Update-PackMetadata.ps1') -ProjectRoot $hostRoot
& (Join-Path $root 'scripts\Validate-Pack.ps1') -ProjectRoot $hostRoot -AllowPlaceholder -AllowPrivateLan
$packText = [IO.File]::ReadAllText((Join-Path $hostRoot 'packwiz\pack.toml'))
$candidateMatch = [regex]::Match($packText, '(?m)^version\s*=\s*"([^"]+)"\s*$')
if (-not $candidateMatch.Success) { throw 'The local candidate pack.toml has no top-level version.' }
$candidateVersion = $candidateMatch.Groups[1].Value
$priorVersion = 'test-prior-version'
# Python's generic static server labels .toml as binary, which Windows
# PowerShell 5.1 exposes as byte[] instead of text. Serve an exact byte-for-byte
# text/plain alias so the unmodified production version parser is exercised.
$packAlias = Join-Path $hostRoot 'packwiz\pack.txt'
Copy-Item -LiteralPath (Join-Path $hostRoot 'packwiz\pack.toml') -Destination $packAlias
$packUrl = "$localBase/packwiz/pack.txt"

# Production deliberately refuses HTTP. Patch only a disposable tools copy to
# allow this test's exact generated loopback URL; assert the shipped updater is
# byte-identical after the workflow.
$disposableTools = Join-Path $testRoot 'server-tools'
Copy-DirectoryTree -Source (Join-Path $root 'server-tools') -Destination $disposableTools
$disposableUpdater = Join-Path $disposableTools 'Update-Server.ps1'
$updaterText = [IO.File]::ReadAllText($disposableUpdater)
$productionGuard = "if (`$PackUrl -notmatch '^https://') { throw 'Production server updates require an HTTPS Packwiz URL.' }"
$testGuard = "if (`$PackUrl -notmatch '^https://' -and `$PackUrl -ne '$packUrl') { throw 'Production server updates require HTTPS; this disposable test permits only its exact loopback candidate URL.' }"
if (-not $updaterText.Contains($productionGuard)) { throw 'Could not locate the production HTTPS guard in the disposable updater copy.' }
$updaterText = $updaterText.Replace($productionGuard, $testGuard)
[IO.File]::WriteAllText($disposableUpdater, $updaterText, $utf8)
if ([IO.File]::ReadAllText($disposableUpdater).Contains($productionGuard)) { throw 'Disposable updater loopback guard replacement was incomplete.' }

$serverRoot = Join-Path $testRoot 'server'
$managementRoot = Join-Path $serverRoot 'server-management'
New-Item -ItemType Directory -Path $managementRoot,(Join-Path $serverRoot 'libraries'),(Join-Path $serverRoot 'mods'), `
    (Join-Path $serverRoot 'config'),(Join-Path $serverRoot 'world') -Force | Out-Null
[IO.File]::WriteAllText((Join-Path $serverRoot 'server.properties'), "level-name=world`r`nserver-port=25579`r`n", $utf8)
[IO.File]::WriteAllText((Join-Path $serverRoot 'eula.txt'), "eula=true`r`n", $utf8)
[IO.File]::WriteAllText((Join-Path $serverRoot 'user_jvm_args.txt'), "-Xmx1G`r`n", $utf8)
[IO.File]::WriteAllBytes((Join-Path $serverRoot 'mods\test.jar'), [byte[]](1,2,3))
[IO.File]::WriteAllText((Join-Path $serverRoot 'config\managed-test.txt'), 'known-good', $utf8)
[IO.File]::WriteAllBytes((Join-Path $serverRoot 'world\level.dat'), [byte[]](10,20,30,40))
[IO.File]::WriteAllText((Join-Path $serverRoot 'packwiz.json'), '{"test":true}', $utf8)
[IO.File]::WriteAllText((Join-Path $managementRoot 'current-version.json'), (([ordered]@{
    version = $priorVersion
    installedAt = (Get-Date).AddDays(-1).ToString('o')
} | ConvertTo-Json) + "`r`n"), $utf8)

# Seed the pinned, hash-verified installers so neither update attempt needs to
# fetch tooling. The fake Java command controls only installer success/failure.
$bootstrapSource = & (Join-Path $root 'scripts\Get-PackwizInstaller.ps1') -ProjectRoot $root -PassThru
$installerSource = & (Join-Path $root 'scripts\Get-PackwizInstaller.ps1') -ProjectRoot $root -MainJarPassThru
Copy-Item -LiteralPath $bootstrapSource -Destination (Join-Path $serverRoot 'packwiz-installer-bootstrap.jar')
Copy-Item -LiteralPath $installerSource -Destination (Join-Path $serverRoot 'packwiz-installer.jar')

$webhookPort = Get-FreeLoopbackPort
$recording = Join-Path $testRoot 'discord-requests.jsonl'
$python = (Get-Command python -ErrorAction Stop).Source
$packProcess = $null
$webhookProcess = $null
$result = $null
try {
    $packProcess = Start-Process -FilePath $python -ArgumentList @(
        ('"' + (Join-Path $root 'scripts\limited_http_server.py') + '"'), '--port', "$packPort", '--directory', ('"' + $hostRoot + '"'), '--workers', '24'
    ) -WindowStyle Hidden -RedirectStandardOutput (Join-Path $testRoot 'pack-http-stdout.log') `
        -RedirectStandardError (Join-Path $testRoot 'pack-http-stderr.log') -PassThru
    $webhookProcess = Start-Process -FilePath $python -ArgumentList @(
        ('"' + (Join-Path $root 'tests\fake_discord_webhook.py') + '"'), '--port', "$webhookPort", '--output', ('"' + $recording + '"')
    ) -WindowStyle Hidden -RedirectStandardOutput (Join-Path $testRoot 'webhook-stdout.log') `
        -RedirectStandardError (Join-Path $testRoot 'webhook-stderr.log') -PassThru
    Wait-LoopbackPort -Port $packPort -Description 'Disposable local candidate Packwiz host'
    Wait-LoopbackPort -Port $webhookPort -Description 'Disposable updater webhook'

    $servedPackPath = Join-Path $testRoot 'served-pack.toml'
    Invoke-WebRequest -Uri $packUrl -UseBasicParsing -TimeoutSec 10 -OutFile $servedPackPath
    $servedHash = (Get-FileHash -LiteralPath $servedPackPath -Algorithm SHA256).Hash
    $candidateHash = (Get-FileHash -LiteralPath (Join-Path $hostRoot 'packwiz\pack.toml') -Algorithm SHA256).Hash
    if ($servedHash -ne $candidateHash) { throw 'The loopback Packwiz host did not serve the validated local candidate bytes.' }

    [IO.File]::WriteAllText((Join-Path $serverRoot 'discord-webhook.txt'), "http://127.0.0.1:$webhookPort/webhook`r`n", $utf8)
    $settingsPath = Join-Path $testRoot 'server-settings.json'
    $settings = [ordered]@{
        packUrl = $packUrl
        backupDirectory = (Join-Path $testRoot 'backups')
        discordWebhookFile = 'discord-webhook.txt'
        discordServerName = 'Disposable Update Workflow'
        discordWebhookUsername = 'Disposable Status'
        discordAllowInsecureLocalTest = $true
        discordMaxAttempts = 3
        discordRetryBaseMilliseconds = 100
    }
    [IO.File]::WriteAllText($settingsPath, (($settings | ConvertTo-Json -Depth 5) + "`r`n"), $utf8)
    $backup = & (Join-Path $disposableTools 'Backup-Server.ps1') -ServerRoot $serverRoot -SettingsPath $settingsPath -SkipRetention

    $fakeJava = Join-Path $testRoot 'fake-java.cmd'
    [IO.File]::WriteAllText($fakeJava, "@echo off`r`nexit /b 1`r`n", [Text.ASCIIEncoding]::new())
    $failedAsExpected = $false
    try {
        & $disposableUpdater -ServerRoot $serverRoot -SettingsPath $settingsPath -JavaPath $fakeJava -ExistingBackupPath $backup
    } catch {
        $failedAsExpected = $_.Exception.Message -like 'Server update failed and managed files were rolled back*'
    }
    if (-not $failedAsExpected) { throw 'The disposable failed update did not follow its rollback path.' }
    $failureRecord = Get-ChildItem -LiteralPath $managementRoot -File -Filter 'update-*.json' | Sort-Object LastWriteTimeUtc -Descending | Select-Object -First 1
    $failureData = Get-Content -LiteralPath $failureRecord.FullName -Raw | ConvertFrom-Json
    if ($failureData.status -ne 'installer-failed-managed-files-restored' -or -not $failureData.failedAt -or -not $failureData.failureType) {
        throw 'The failed update record lacks its terminal rollback state.'
    }
    if ((Get-Content -LiteralPath (Join-Path $managementRoot 'current-version.json') -Raw | ConvertFrom-Json).version -ne $priorVersion) {
        throw 'The failed update did not preserve the neutral prior-version record.'
    }

    Start-Sleep -Milliseconds 1100
    [IO.File]::WriteAllText($fakeJava, "@echo off`r`nexit /b 0`r`n", [Text.ASCIIEncoding]::new())
    $returnedBackup = & $disposableUpdater -ServerRoot $serverRoot -SettingsPath $settingsPath -JavaPath $fakeJava -ExistingBackupPath $backup
    if (-not ([IO.Path]::GetFullPath([string]$returnedBackup)).Equals([IO.Path]::GetFullPath($backup), [StringComparison]::OrdinalIgnoreCase)) {
        throw 'The successful update returned the wrong rollback backup.'
    }
    $currentVersion = Get-Content -LiteralPath (Join-Path $managementRoot 'current-version.json') -Raw | ConvertFrom-Json
    $successRecord = Get-Content -LiteralPath ([string]$currentVersion.updateRecord) -Raw | ConvertFrom-Json
    if ($currentVersion.version -ne $candidateVersion -or $successRecord.status -ne 'installed-not-yet-start-verified' -or
        $successRecord.installedVersion -ne $currentVersion.version) {
        throw 'The successful update did not create matching candidate-version runtime-verification records.'
    }

    & (Join-Path $disposableTools 'Rollback-ServerUpdate.ps1') -BackupPath $backup -ServerRoot $serverRoot -SettingsPath $settingsPath -Confirm:$false
    $rolledBackVersion = (Get-Content -LiteralPath (Join-Path $managementRoot 'current-version.json') -Raw | ConvertFrom-Json).version
    if ($rolledBackVersion -ne $priorVersion) { throw 'Rollback did not restore the neutral prior-version record.' }

    $deadline = (Get-Date).AddSeconds(5)
    do {
        Start-Sleep -Milliseconds 100
        $requests = if (Test-Path -LiteralPath $recording) { @(Get-Content -LiteralPath $recording | ForEach-Object { $_ | ConvertFrom-Json }) } else { @() }
    } while ($requests.Count -lt 6 -and (Get-Date) -lt $deadline)
    $events = @($requests | ForEach-Object { [regex]::Match([string]$_.body.embeds[0].footer.text, 'event=([a-z]+)').Groups[1].Value })
    $expectedEvents = @('updating', 'failed', 'updating', 'updated', 'rollingback', 'rolledback')
    if (@(Compare-Object $expectedEvents $events -SyncWindow 0).Count -ne 0) {
        throw "Update/rollback event order mismatch. Actual=$($events -join ',')"
    }
    $auditRecords = @(Get-Content -LiteralPath (Join-Path $managementRoot 'discord-notifications.jsonl') | ForEach-Object { $_ | ConvertFrom-Json })
    if ($auditRecords.Count -ne 6 -or @($auditRecords | Where-Object { -not $_.succeeded -or [int]$_.attempts -ne 1 }).Count -ne 0) {
        throw 'Updater notification audit does not contain six one-attempt successful deliveries.'
    }

    $result = [ordered]@{
        testedAt = (Get-Date).ToString('o')
        powershellVersion = $PSVersionTable.PSVersion.ToString()
        status = 'PASS'
        candidateVersion = $candidateVersion
        priorVersionSentinel = $priorVersion
        events = $events
        failedUpdateTerminalState = [string]$failureData.status
        failedUpdateRestoredPriorVersion = $true
        successfulUpdatePendingRuntimeVerification = $true
        rollbackRestoredPriorVersion = $true
        durableDeliveries = $auditRecords.Count
        localCandidatePackwizFeedContacted = $true
        publicPackwizFeedContacted = $false
        realDiscordContacted = $false
        productionUpdaterUnchanged = $false
        disposableUpdaterLoopbackException = $true
        localPackHostStopped = $false
        localWebhookStopped = $false
        productionPortTouched = $false
        liveServerTouched = $false
    }
} finally {
    foreach ($process in @($webhookProcess, $packProcess)) {
        if ($process -and -not $process.HasExited) {
            Stop-Process -Id $process.Id -Force
            Wait-Process -Id $process.Id -ErrorAction SilentlyContinue
        }
    }
}

$productionUpdaterHashAfter = (Get-FileHash -LiteralPath $productionUpdater -Algorithm SHA256).Hash
if ($productionUpdaterHashAfter -ne $productionUpdaterHashBefore) { throw 'The workflow test changed the production updater.' }
if (Get-Process -Id $packProcess.Id -ErrorAction SilentlyContinue) { throw 'The disposable local Packwiz host is still running.' }
if (Get-Process -Id $webhookProcess.Id -ErrorAction SilentlyContinue) { throw 'The disposable webhook is still running.' }
$result['productionUpdaterUnchanged'] = $true
$result['localPackHostStopped'] = $true
$result['localWebhookStopped'] = $true
$auditPath = Join-Path $root 'audit\discord-update-workflow.json'
[IO.File]::WriteAllText($auditPath, (($result | ConvertTo-Json -Depth 6) + "`r`n"), $utf8)
$result | ConvertTo-Json -Depth 6
