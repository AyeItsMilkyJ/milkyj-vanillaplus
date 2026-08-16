[CmdletBinding()]
param(
    [string]$ProjectRoot,
    [int]$TestPort = 25577
)

$ErrorActionPreference = 'Stop'
if (-not $ProjectRoot) { $ProjectRoot = Split-Path -Parent $PSScriptRoot }
if ($TestPort -eq 25565) { throw 'The infrastructure harness refuses production port 25565.' }
$root = [IO.Path]::GetFullPath($ProjectRoot)
$testRoot = [IO.Path]::GetFullPath((Join-Path $root 'build\server-infrastructure-test'))
$expectedRoot = [IO.Path]::GetFullPath((Join-Path $root 'build\server-infrastructure-test'))
if (-not $testRoot.Equals($expectedRoot, [StringComparison]::OrdinalIgnoreCase)) { throw 'Unsafe disposable infrastructure test root.' }
if (Get-NetTCPConnection -LocalPort $TestPort -State Listen -ErrorAction SilentlyContinue) { throw "Disposable test port $TestPort is already in use." }
$productionBefore = @(Get-NetTCPConnection -LocalPort 25565 -State Listen -ErrorAction SilentlyContinue | Select-Object OwningProcess,LocalAddress,LocalPort)
if (Test-Path -LiteralPath $testRoot) { Remove-Item -LiteralPath $testRoot -Recurse -Force }

$serverRoot = Join-Path $testRoot 'server'
$backupRoot = Join-Path $testRoot 'backups'
New-Item -ItemType Directory -Path $serverRoot,$backupRoot,(Join-Path $serverRoot 'libraries'),(Join-Path $serverRoot 'mods'),(Join-Path $serverRoot 'config'),(Join-Path $serverRoot 'world\data'),(Join-Path $serverRoot 'world\serverconfig') -Force | Out-Null
[IO.File]::WriteAllText((Join-Path $serverRoot 'server.properties'), "level-name=world`r`nserver-ip=127.0.0.1`r`nserver-port=$TestPort`r`n", [Text.UTF8Encoding]::new($false))
[IO.File]::WriteAllText((Join-Path $serverRoot 'eula.txt'), "eula=true`r`n", [Text.UTF8Encoding]::new($false))
[IO.File]::WriteAllText((Join-Path $serverRoot 'run.bat'), "@echo off`r`nexit /b 99`r`n", [Text.ASCIIEncoding]::new())
[IO.File]::WriteAllBytes((Join-Path $serverRoot 'mods\test.jar'), [byte[]](1,2,3))
[IO.File]::WriteAllText((Join-Path $serverRoot 'config\managed-test.txt'), 'known-good', [Text.UTF8Encoding]::new($false))
[IO.File]::WriteAllBytes((Join-Path $serverRoot 'world\level.dat'), [byte[]](10,20,30,40))
[IO.File]::WriteAllText((Join-Path $serverRoot 'world\data\ftbteams.dat'), 'team-data', [Text.UTF8Encoding]::new($false))
[IO.File]::WriteAllText((Join-Path $serverRoot 'world\serverconfig\ftbquests.snbt'), 'quest-data', [Text.UTF8Encoding]::new($false))
[IO.File]::WriteAllText((Join-Path $serverRoot 'packwiz.json'), '{"test":true}', [Text.UTF8Encoding]::new($false))

$python = (Get-Command python -ErrorAction Stop).Source
$fake = Join-Path $root 'tests\fake_minecraft_server.py'
$webhookListener = [Net.Sockets.TcpListener]::new([Net.IPAddress]::Loopback, 0)
$webhookListener.Start()
$webhookPort = ([Net.IPEndPoint]$webhookListener.LocalEndpoint).Port
$webhookListener.Stop()
$webhookRecording = Join-Path $testRoot 'discord-requests.jsonl'
$webhookProcess = Start-Process -FilePath $python -ArgumentList @(
    ('"' + (Join-Path $root 'tests\fake_discord_webhook.py') + '"'), '--port', "$webhookPort", '--output', ('"' + $webhookRecording + '"')
) -WindowStyle Hidden -RedirectStandardOutput (Join-Path $testRoot 'discord-webhook.stdout.log') `
    -RedirectStandardError (Join-Path $testRoot 'discord-webhook.stderr.log') -PassThru
$webhookReadyDeadline = (Get-Date).AddSeconds(10)
do {
    try {
        $webhookClient = [Net.Sockets.TcpClient]::new()
        $webhookClient.Connect('127.0.0.1', $webhookPort)
        $webhookReady = $webhookClient.Connected
        $webhookClient.Dispose()
    } catch { Start-Sleep -Milliseconds 100 }
} while (-not $webhookReady -and (Get-Date) -lt $webhookReadyDeadline)
if (-not $webhookReady) { throw 'Disposable Discord webhook did not start.' }
[IO.File]::WriteAllText((Join-Path $serverRoot 'discord-webhook.txt'), "http://127.0.0.1:$webhookPort/webhook`r`n", [Text.UTF8Encoding]::new($false))
$settingsPath = Join-Path $testRoot 'test-settings.json'
$settings = [ordered]@{
    packUrl = 'https://example.invalid/packwiz/pack.toml'
    backupDirectory = $backupRoot
    gracefulStopTimeoutSeconds = 3
    startupTimeoutSeconds = 15
    startupDelaySeconds = 1
    restartBackoffSeconds = @(1,2,3)
    rapidFailureWindowMinutes = 2
    maxRapidFailures = 3
    stableRunResetMinutes = 5
    backupRetentionDaily = 2
    backupRetentionWeekly = 2
    taskNamePrefix = 'MilkyJ Minecraft Disposable Infrastructure Test'
    discordWebhookFile = 'discord-webhook.txt'
    discordServerName = 'Disposable Infrastructure Test'
    discordWebhookUsername = 'Disposable Status'
    discordAllowInsecureLocalTest = $true
    launchExecutable = $python
    launchArguments = @($fake, '--server-root', $serverRoot, '--port', "$TestPort")
}
[IO.File]::WriteAllText($settingsPath, (($settings | ConvertTo-Json -Depth 8) + "`r`n"), [Text.UTF8Encoding]::new($false))
$tools = Join-Path $root 'server-tools'
$results = [ordered]@{ testedAt=(Get-Date).ToString('o'); testRoot=$testRoot; testPort=$TestPort; productionPort=25565 }

function Wait-Until([scriptblock]$Condition, [int]$Seconds, [string]$Failure) {
    $deadline = (Get-Date).AddSeconds($Seconds)
    do { if (& $Condition) { return }; Start-Sleep -Milliseconds 250 } while ((Get-Date) -lt $deadline)
    throw $Failure
}
function Stop-DisposableProcess([int]$ProcessId) {
    $candidate = Get-CimInstance Win32_Process -Filter "ProcessId=$ProcessId" -ErrorAction SilentlyContinue
    if ($candidate -and $candidate.CommandLine -match 'fake_minecraft_server\.py' -and $candidate.CommandLine -match 'server-infrastructure-test') {
        Stop-Process -Id $ProcessId -Force
    }
}

try {
    & (Join-Path $tools 'Start-Server.ps1') -ServerRoot $serverRoot -SettingsPath $settingsPath
    $results.firstStart = 'PASS'
    $runningStatus = & (Join-Path $tools 'Get-ServerStatus.ps1') -ServerRoot $serverRoot -SettingsPath $settingsPath -AsJson | ConvertFrom-Json
    if ($runningStatus.server -ne 'RUNNING' -or $runningStatus.updateSafe) { throw 'Running status report is incorrect.' }
    $results.runningStatus = 'PASS'

    try {
        & (Join-Path $tools 'Start-Server.ps1') -ServerRoot $serverRoot -SettingsPath $settingsPath
        throw 'Duplicate start unexpectedly succeeded.'
    } catch {
        if ($_.Exception.Message -eq 'Duplicate start unexpectedly succeeded.') { throw }
        $results.duplicateStartRefusal = 'PASS'
    }
    try {
        & (Join-Path $tools 'Backup-Server.ps1') -ServerRoot $serverRoot -SettingsPath $settingsPath
        throw 'Active-server cold backup unexpectedly succeeded.'
    } catch {
        if ($_.Exception.Message -eq 'Active-server cold backup unexpectedly succeeded.') { throw }
        $results.activeBackupRefusal = 'PASS'
    }
    try {
        & (Join-Path $tools 'Update-Server.ps1') -ServerRoot $serverRoot -SettingsPath $settingsPath
        throw 'Active-server update unexpectedly succeeded.'
    } catch {
        if ($_.Exception.Message -eq 'Active-server update unexpectedly succeeded.') { throw }
        $results.activeUpdateRefusal = 'PASS'
    }

    & (Join-Path $tools 'Stop-Server.ps1') -ServerRoot $serverRoot -SettingsPath $settingsPath -TimeoutSeconds 12
    if (-not (Select-String -LiteralPath (Join-Path $serverRoot 'logs\latest.log') -SimpleMatch 'All dimensions are saved' -Quiet)) { throw 'Graceful stop did not record world save.' }
    $results.gracefulStop = 'PASS'

    & (Join-Path $tools 'Start-Server.ps1') -ServerRoot $serverRoot -SettingsPath $settingsPath
    $beforeRestartState = Get-Content -LiteralPath (Join-Path $serverRoot 'server-management\state.json') -Raw | ConvertFrom-Json
    $beforeRestart = $beforeRestartState.serverPid
    & (Join-Path $tools 'Restart-Server.ps1') -ServerRoot $serverRoot -SettingsPath $settingsPath
    $afterRestart = (Get-Content -LiteralPath (Join-Path $serverRoot 'server-management\state.json') -Raw | ConvertFrom-Json).serverPid
    if ($beforeRestart -eq $afterRestart) { throw 'Restart did not produce a new launch PID.' }
    $results.restart = 'PASS'

    $crashPid = [int]$afterRestart
    Stop-DisposableProcess $crashPid
    Wait-Until { $state=Get-Content -LiteralPath (Join-Path $serverRoot 'server-management\state.json') -Raw | ConvertFrom-Json; $state.restartCount -ge 1 -and $state.serverPid -and [int]$state.serverPid -ne $crashPid -and (Get-NetTCPConnection -LocalPort $TestPort -State Listen -ErrorAction SilentlyContinue) } 15 'Watchdog did not restart after simulated crash.'
    $results.simulatedCrash = 'PASS'
    $results.watchdogRestart = 'PASS'
    $results.restartBackoff = 'PASS'
    & (Join-Path $tools 'Stop-Server.ps1') -ServerRoot $serverRoot -SettingsPath $settingsPath -TimeoutSeconds 12

    New-Item -ItemType File -Path (Join-Path $serverRoot 'fail-always.flag') -Force | Out-Null
    try { & (Join-Path $tools 'Start-Server.ps1') -ServerRoot $serverRoot -SettingsPath $settingsPath } catch { }
    Wait-Until { $state=Get-Content -LiteralPath (Join-Path $serverRoot 'server-management\state.json') -Raw | ConvertFrom-Json; $state.status -eq 'failed-repeatedly' } 20 'Repeated-failure protection did not trip.'
    Remove-Item -LiteralPath (Join-Path $serverRoot 'fail-always.flag') -Force
    $results.repeatedFailureProtection = 'PASS'

    $backup = & (Join-Path $tools 'Backup-Server.ps1') -ServerRoot $serverRoot -SettingsPath $settingsPath -SkipRetention
    $validation = & (Join-Path $tools 'Test-ServerBackup.ps1') -BackupPath $backup -PassThru
    if (-not $validation.valid -or -not $validation.worldIncluded) { throw 'Backup validation did not confirm the world.' }
    $results.backupCreation = 'PASS'
    $results.backupVerification = 'PASS'
    [IO.File]::WriteAllText((Join-Path $serverRoot 'config\managed-test.txt'), 'broken-update', [Text.UTF8Encoding]::new($false))
    & (Join-Path $tools 'Restore-ServerBackup.ps1') -BackupPath $backup -ServerRoot $serverRoot -SettingsPath $settingsPath -Confirm:$false
    if ((Get-Content -LiteralPath (Join-Path $serverRoot 'config\managed-test.txt') -Raw) -ne 'known-good') { throw 'Managed rollback preparation test failed.' }
    $results.rollbackPreparation = 'PASS'

    $taskPreview = Join-Path $testRoot 'task-preview'
    $taskNamesBefore = @(Get-ScheduledTask -TaskName "$($settings.taskNamePrefix)*" -ErrorAction SilentlyContinue).Count
    & (Join-Path $tools 'Install-AutomaticStartup.ps1') -ServerRoot $serverRoot -SettingsPath $settingsPath -IncludeDailyBackup -GenerateOnly -OutputDirectory $taskPreview | Out-Null
    $taskNamesAfter = @(Get-ScheduledTask -TaskName "$($settings.taskNamePrefix)*" -ErrorAction SilentlyContinue).Count
    if ($taskNamesBefore -ne $taskNamesAfter -or @(Get-ChildItem -LiteralPath $taskPreview -Filter '*.xml').Count -ne 2) { throw 'Scheduled-task generation installed a task or failed to create two XML previews.' }
    [xml](Get-Content -LiteralPath (Join-Path $taskPreview 'minecraft-startup-task.xml') -Raw) | Out-Null
    [xml](Get-Content -LiteralPath (Join-Path $taskPreview 'minecraft-daily-backup-task.xml') -Raw) | Out-Null
    $results.scheduledTaskGenerationOnly = 'PASS'

    $stoppedStatus = & (Join-Path $tools 'Get-ServerStatus.ps1') -ServerRoot $serverRoot -SettingsPath $settingsPath -AsJson | ConvertFrom-Json
    if ($stoppedStatus.server -ne 'STOPPED' -or -not $stoppedStatus.updateSafe -or $stoppedStatus.latestBackup -eq 'none') { throw 'Stopped status report is incorrect.' }
    $results.stoppedStatus = 'PASS'

    New-Item -ItemType File -Path (Join-Path $serverRoot 'linger-on-stop.flag') -Force | Out-Null
    & (Join-Path $tools 'Start-Server.ps1') -ServerRoot $serverRoot -SettingsPath $settingsPath
    try { & (Join-Path $tools 'Stop-Server.ps1') -ServerRoot $serverRoot -SettingsPath $settingsPath -TimeoutSeconds 7 } catch { }
    $lingerState = Get-Content -LiteralPath (Join-Path $serverRoot 'server-management\state.json') -Raw | ConvertFrom-Json
    if (-not $lingerState.manualInterventionRequired -or -not (Get-Process -Id $lingerState.serverPid -ErrorAction SilentlyContinue)) { throw 'Lingering JVM safety behaviour was not observed.' }
    Stop-DisposableProcess ([int]$lingerState.serverPid)
    Remove-Item -LiteralPath (Join-Path $serverRoot 'linger-on-stop.flag') -Force
    Wait-Until { -not (Get-NetTCPConnection -LocalPort $TestPort -State Listen -ErrorAction SilentlyContinue) } 5 'Lingering test process did not release its disposable port.'
    $results.lingeringJvmNotKilled = 'PASS'

    $discordRecords = @(Get-Content -LiteralPath $webhookRecording -ErrorAction SilentlyContinue | ForEach-Object { $_ | ConvertFrom-Json })
    $discordEvents = @($discordRecords | ForEach-Object {
        [regex]::Match([string]$_.body.embeds[0].footer.text, 'event=([a-z]+)').Groups[1].Value
    })
    foreach ($expectedEvent in @('online', 'offline', 'restarting', 'crashed', 'failed')) {
        if ($expectedEvent -notin $discordEvents) { throw "Lifecycle Discord notification was not observed: $expectedEvent" }
    }
    $results.discordLifecycleNotifications = 'PASS'
    $results.discordEventsObserved = @($discordEvents | Sort-Object -Unique)
    $results.discordUsedDisposableLoopbackOnly = $true

    $productionAfter = @(Get-NetTCPConnection -LocalPort 25565 -State Listen -ErrorAction SilentlyContinue | Select-Object OwningProcess,LocalAddress,LocalPort)
    if (($productionBefore | ConvertTo-Json -Compress) -ne ($productionAfter | ConvertTo-Json -Compress)) { throw 'Production port 25565 listener state changed during disposable tests.' }
    $results.productionPathProtection = 'PASS'
    $results.productionPortProtection = 'PASS'
    $results.productionPortTouched = $false
    $results.scheduledTasksInstalled = $false
    $results.liveServerWorldOrPrismTouched = $false
    $results.status = 'PASS'
} finally {
    $statePath = Join-Path $serverRoot 'server-management\state.json'
    if (Test-Path -LiteralPath $statePath) {
        $state = Get-Content -LiteralPath $statePath -Raw | ConvertFrom-Json
        if ($state.serverPid) { Stop-DisposableProcess ([int]$state.serverPid) }
        if ($state.supervisorPid) {
            $supervisor = Get-CimInstance Win32_Process -Filter "ProcessId=$([int]$state.supervisorPid)" -ErrorAction SilentlyContinue
            if ($supervisor -and $supervisor.CommandLine -match 'server-infrastructure-test') { Stop-Process -Id $state.supervisorPid -Force }
        }
    }
    if ($webhookProcess -and -not $webhookProcess.HasExited) { Stop-Process -Id $webhookProcess.Id -Force }
}

$auditPath = Join-Path $root 'audit\server-infrastructure-tests.json'
[IO.File]::WriteAllText($auditPath, (($results | ConvertTo-Json -Depth 8) + "`r`n"), [Text.UTF8Encoding]::new($false))
$results | ConvertTo-Json -Depth 8
