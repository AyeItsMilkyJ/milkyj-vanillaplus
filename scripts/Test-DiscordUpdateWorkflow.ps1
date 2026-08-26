[CmdletBinding()]
param([string]$ProjectRoot)

$ErrorActionPreference = 'Stop'
if (-not $ProjectRoot) { $ProjectRoot = Split-Path -Parent $PSScriptRoot }
$root = [IO.Path]::GetFullPath($ProjectRoot)
$testRoot = [IO.Path]::GetFullPath((Join-Path $root 'build\discord-update-workflow'))
$expectedRoot = [IO.Path]::GetFullPath((Join-Path $root 'build\discord-update-workflow'))
if (-not $testRoot.Equals($expectedRoot, [StringComparison]::OrdinalIgnoreCase)) { throw 'Unsafe Discord updater test root.' }
if (Test-Path -LiteralPath $testRoot) { Remove-Item -LiteralPath $testRoot -Recurse -Force }

$serverRoot = Join-Path $testRoot 'server'
$managementRoot = Join-Path $serverRoot 'server-management'
New-Item -ItemType Directory -Path $managementRoot,(Join-Path $serverRoot 'libraries'),(Join-Path $serverRoot 'mods'), `
    (Join-Path $serverRoot 'config'),(Join-Path $serverRoot 'world') -Force | Out-Null
$utf8 = [Text.UTF8Encoding]::new($false)
[IO.File]::WriteAllText((Join-Path $serverRoot 'server.properties'), "level-name=world`r`nserver-port=25579`r`n", $utf8)
[IO.File]::WriteAllText((Join-Path $serverRoot 'eula.txt'), "eula=true`r`n", $utf8)
[IO.File]::WriteAllText((Join-Path $serverRoot 'user_jvm_args.txt'), "-Xmx1G`r`n", $utf8)
[IO.File]::WriteAllBytes((Join-Path $serverRoot 'mods\test.jar'), [byte[]](1,2,3))
[IO.File]::WriteAllText((Join-Path $serverRoot 'config\managed-test.txt'), 'known-good', $utf8)
[IO.File]::WriteAllBytes((Join-Path $serverRoot 'world\level.dat'), [byte[]](10,20,30,40))
[IO.File]::WriteAllText((Join-Path $serverRoot 'packwiz.json'), '{"test":true}', $utf8)
[IO.File]::WriteAllText((Join-Path $managementRoot 'current-version.json'), (([ordered]@{
    version = '1.9.0-rc2'
    installedAt = (Get-Date).AddDays(-1).ToString('o')
} | ConvertTo-Json) + "`r`n"), $utf8)

$listener = [Net.Sockets.TcpListener]::new([Net.IPAddress]::Loopback, 0)
$listener.Start()
$webhookPort = ([Net.IPEndPoint]$listener.LocalEndpoint).Port
$listener.Stop()
$recording = Join-Path $testRoot 'discord-requests.jsonl'
$python = (Get-Command python -ErrorAction Stop).Source
$webhookProcess = Start-Process -FilePath $python -ArgumentList @(
    ('"' + (Join-Path $root 'tests\fake_discord_webhook.py') + '"'), '--port', "$webhookPort", '--output', ('"' + $recording + '"')
) -WindowStyle Hidden -RedirectStandardOutput (Join-Path $testRoot 'webhook-stdout.log') `
    -RedirectStandardError (Join-Path $testRoot 'webhook-stderr.log') -PassThru

try {
    $deadline = (Get-Date).AddSeconds(10)
    $ready = $false
    do {
        try {
            $client = [Net.Sockets.TcpClient]::new()
            $client.Connect('127.0.0.1', $webhookPort)
            $ready = $client.Connected
            $client.Dispose()
        } catch { Start-Sleep -Milliseconds 100 }
    } while (-not $ready -and (Get-Date) -lt $deadline)
    if (-not $ready) { throw 'Disposable updater webhook did not start.' }

    [IO.File]::WriteAllText((Join-Path $serverRoot 'discord-webhook.txt'), "http://127.0.0.1:$webhookPort/webhook`r`n", $utf8)
    $packUrl = [string](Get-Content -LiteralPath (Join-Path $root 'project-settings.json') -Raw | ConvertFrom-Json).packUrl
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
    $tools = Join-Path $root 'server-tools'
    $backup = & (Join-Path $tools 'Backup-Server.ps1') -ServerRoot $serverRoot -SettingsPath $settingsPath -SkipRetention

    $fakeJava = Join-Path $testRoot 'fake-java.cmd'
    [IO.File]::WriteAllText($fakeJava, "@echo off`r`nexit /b 1`r`n", [Text.ASCIIEncoding]::new())
    $failedAsExpected = $false
    try {
        & (Join-Path $tools 'Update-Server.ps1') -ServerRoot $serverRoot -SettingsPath $settingsPath -JavaPath $fakeJava -ExistingBackupPath $backup
    } catch {
        $failedAsExpected = $_.Exception.Message -like 'Server update failed and managed files were rolled back*'
    }
    if (-not $failedAsExpected) { throw 'The disposable failed update did not follow its rollback path.' }
    $failureRecord = Get-ChildItem -LiteralPath $managementRoot -File -Filter 'update-*.json' | Sort-Object LastWriteTimeUtc -Descending | Select-Object -First 1
    $failureData = Get-Content -LiteralPath $failureRecord.FullName -Raw | ConvertFrom-Json
    if ($failureData.status -ne 'installer-failed-managed-files-restored' -or -not $failureData.failedAt -or -not $failureData.failureType) {
        throw 'The failed update record lacks its terminal rollback state.'
    }
    if ((Get-Content -LiteralPath (Join-Path $managementRoot 'current-version.json') -Raw | ConvertFrom-Json).version -ne '1.9.0-rc2') {
        throw 'The failed update did not preserve the previous version record.'
    }

    Start-Sleep -Milliseconds 1100
    [IO.File]::WriteAllText($fakeJava, "@echo off`r`nexit /b 0`r`n", [Text.ASCIIEncoding]::new())
    $returnedBackup = & (Join-Path $tools 'Update-Server.ps1') -ServerRoot $serverRoot -SettingsPath $settingsPath -JavaPath $fakeJava -ExistingBackupPath $backup
    if (-not ([IO.Path]::GetFullPath([string]$returnedBackup)).Equals([IO.Path]::GetFullPath($backup), [StringComparison]::OrdinalIgnoreCase)) {
        throw 'The successful update returned the wrong rollback backup.'
    }
    $currentVersion = Get-Content -LiteralPath (Join-Path $managementRoot 'current-version.json') -Raw | ConvertFrom-Json
    $successRecord = Get-Content -LiteralPath ([string]$currentVersion.updateRecord) -Raw | ConvertFrom-Json
    if ($currentVersion.version -ne '1.9.0-rc3' -or $successRecord.status -ne 'installed-not-yet-start-verified' -or
        $successRecord.installedVersion -ne $currentVersion.version) {
        throw 'The successful update did not create matching pending runtime-verification records.'
    }

    & (Join-Path $tools 'Rollback-ServerUpdate.ps1') -BackupPath $backup -ServerRoot $serverRoot -SettingsPath $settingsPath -Confirm:$false
    $rolledBackVersion = (Get-Content -LiteralPath (Join-Path $managementRoot 'current-version.json') -Raw | ConvertFrom-Json).version
    if ($rolledBackVersion -ne '1.9.0-rc2') { throw 'Rollback did not restore the prior version record.' }

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
        events = $events
        failedUpdateTerminalState = [string]$failureData.status
        failedUpdateRestoredPriorVersion = $true
        successfulUpdatePendingRuntimeVerification = $true
        rollbackRestoredPriorVersion = $true
        durableDeliveries = $auditRecords.Count
        realPackwizFeedContacted = $true
        realDiscordContacted = $false
        productionPortTouched = $false
        liveServerTouched = $false
    }
    $auditPath = Join-Path $root 'audit\discord-update-workflow.json'
    [IO.File]::WriteAllText($auditPath, (($result | ConvertTo-Json -Depth 6) + "`r`n"), $utf8)
    $result | ConvertTo-Json -Depth 6
} finally {
    if ($webhookProcess -and -not $webhookProcess.HasExited) { Stop-Process -Id $webhookProcess.Id -Force }
}
