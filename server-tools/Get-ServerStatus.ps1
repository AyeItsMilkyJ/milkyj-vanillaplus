[CmdletBinding()]
param([string]$ServerRoot, [string]$SettingsPath, [switch]$AsJson)

. (Join-Path $PSScriptRoot 'Common.ps1')
. (Join-Path $PSScriptRoot 'Discord-Notifications.ps1')
$serverRootResolved = Assert-ValidServerRoot (Resolve-ServerRoot $ServerRoot)
$settings = Get-ServerSettings -ServerRoot $serverRootResolved -SettingsPath $SettingsPath
$activity = Repair-StaleServerState $serverRootResolved
$state = $activity.State
$latestBackup = Get-LatestBackup $serverRootResolved $settings
$latestLog = Join-Path $serverRootResolved 'logs\latest.log'
$discordWebhookFile = Get-DiscordWebhookFilePath -ServerRoot $serverRootResolved -Settings $settings
$discordEnvironmentUrl = [Environment]::GetEnvironmentVariable('MILKYJ_DISCORD_WEBHOOK_URL')
$discordAllowLocal = [bool](Get-DiscordSettingValue $settings 'discordAllowInsecureLocalTest' $false)
$discordConfiguration = 'NOT CONFIGURED'
if ($discordEnvironmentUrl) {
    $discordConfiguration = if (Test-DiscordWebhookUrl -WebhookUrl $discordEnvironmentUrl -AllowLocalTest:$discordAllowLocal) { 'CONFIGURED (ENVIRONMENT)' } else { 'INVALID ENVIRONMENT VALUE' }
} elseif (Test-Path -LiteralPath $discordWebhookFile -PathType Leaf) {
    try {
        $discordSavedUrl = [IO.File]::ReadAllText($discordWebhookFile).Trim()
        $discordConfiguration = if (Test-DiscordWebhookUrl -WebhookUrl $discordSavedUrl -AllowLocalTest:$discordAllowLocal) { 'CONFIGURED' } else { 'INVALID SAVED VALUE' }
    } catch {
        $discordConfiguration = 'UNREADABLE'
    }
}
$discordAuditPath = Join-Path (Get-ManagementRoot $serverRootResolved) 'discord-notifications.jsonl'
$lastDiscordAudit = $null
if (Test-Path -LiteralPath $discordAuditPath -PathType Leaf) {
    try {
        $lastDiscordLine = Get-Content -LiteralPath $discordAuditPath -Tail 1 -ErrorAction Stop
        if ($lastDiscordLine) { $lastDiscordAudit = $lastDiscordLine | ConvertFrom-Json -ErrorAction Stop }
    } catch { }
}
$minecraftActivity = ($activity.Listeners.Count -gt 0 -or $activity.ServerProcesses.Count -gt 0)
$managedActivity = ($activity.Supervisors.Count -gt 0 -or $activity.SupervisorLockHeld)
$serverStatus = if ($minecraftActivity -and $activity.Unmanaged) { 'RUNNING / UNMANAGED' } elseif ($minecraftActivity) { 'RUNNING' } else { 'STOPPED' }
$result = [ordered]@{
    serverRoot = $serverRootResolved
    server = $serverStatus
    minecraftPid = @($activity.Listeners | Select-Object -ExpandProperty OwningProcess -Unique)
    recordedLaunchPid = @($activity.ServerProcesses | Select-Object -ExpandProperty ProcessId -Unique)
    port = $activity.Port
    portStatus = if ($activity.Listeners.Count -gt 0) { 'LISTENING' } else { 'NOT LISTENING' }
    supervisor = if ($managedActivity) { 'RUNNING' } elseif ($minecraftActivity) { 'STOPPED / SERVER UNMANAGED' } else { 'STOPPED' }
    supervisorPid = @($activity.Supervisors | Select-Object -ExpandProperty ProcessId -Unique)
    supervisorState = if ($activity.Unmanaged) { 'unmanaged-running-process' } elseif ($state) { [string]$state.status } else { 'no state' }
    persistedSupervisorState = if ($state) { [string]$state.status } else { 'no state' }
    stateReconciledAt = if ($state -and (Get-OptionalPropertyValue $state 'stateReconciledAt')) { [string](Get-OptionalPropertyValue $state 'stateReconciledAt') } else { 'not reconciled' }
    staleRecordedSupervisorPid = [bool]$activity.RecordedSupervisorStale
    staleRecordedServerPid = [bool]$activity.RecordedServerStale
    unmanaged = [bool]$activity.Unmanaged
    supervisorConsole = if ($state -and $state.PSObject.Properties['serverGui'] -and $state.serverGui) {
        'MINECRAFT SERVER GUI'
    } elseif ($state -and $state.PSObject.Properties['interactiveConsole'] -and $state.interactiveConsole) {
        'RAW TERMINAL / INTERACTIVE'
    } else {
        'BACKGROUND / HEADLESS'
    }
    nextScheduledRestart = if ($managedActivity -and $state -and $state.PSObject.Properties['nextScheduledRestart'] -and $state.nextScheduledRestart) { [string]$state.nextScheduledRestart } else { 'not currently scheduled' }
    scheduledRestartMinutes = if ($state -and $state.PSObject.Properties['scheduledRestartMinutes']) { [double]$state.scheduledRestartMinutes } else { [double]$settings.scheduledRestartMinutes }
    currentPackVersion = Get-CurrentPackVersion $serverRootResolved
    latestBackup = if ($latestBackup) { $latestBackup.FullName } else { 'none' }
    latestServerStartTime = if ($state -and $state.latestServerStartAt) { [string]$state.latestServerStartAt } else { 'unknown' }
    latestCrashOrRestartEvent = if ($state -and $state.latestCrashOrRestartEvent) { [string]$state.latestCrashOrRestartEvent } else { 'none recorded' }
    latestMinecraftLog = if (Test-Path -LiteralPath $latestLog) { $latestLog } else { 'none' }
    discordNotifications = $discordConfiguration
    discordLastEvent = if ($lastDiscordAudit) { [string]$lastDiscordAudit.event } else { 'none recorded' }
    discordLastDelivery = if ($lastDiscordAudit) { if ([bool]$lastDiscordAudit.succeeded) { 'DELIVERED' } else { 'FAILED' } } else { 'none recorded' }
    discordLastAttemptAt = if ($lastDiscordAudit) { [string]$lastDiscordAudit.recordedAt } else { 'none recorded' }
    updateSafe = -not $activity.Running
}
if ($AsJson) { $result | ConvertTo-Json -Depth 6 } else { [pscustomobject]$result | Format-List }
