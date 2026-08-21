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
    supervisorConsole = if ($state -and $state.PSObject.Properties['interactiveConsole'] -and $state.interactiveConsole) { 'VISIBLE / INTERACTIVE' } else { 'BACKGROUND' }
    nextScheduledRestart = if ($managedActivity -and $state -and $state.PSObject.Properties['nextScheduledRestart'] -and $state.nextScheduledRestart) { [string]$state.nextScheduledRestart } else { 'not currently scheduled' }
    scheduledRestartMinutes = if ($state -and $state.PSObject.Properties['scheduledRestartMinutes']) { [double]$state.scheduledRestartMinutes } else { [double]$settings.scheduledRestartMinutes }
    currentPackVersion = Get-CurrentPackVersion $serverRootResolved
    latestBackup = if ($latestBackup) { $latestBackup.FullName } else { 'none' }
    latestServerStartTime = if ($state -and $state.latestServerStartAt) { [string]$state.latestServerStartAt } else { 'unknown' }
    latestCrashOrRestartEvent = if ($state -and $state.latestCrashOrRestartEvent) { [string]$state.latestCrashOrRestartEvent } else { 'none recorded' }
    latestMinecraftLog = if (Test-Path -LiteralPath $latestLog) { $latestLog } else { 'none' }
    discordNotifications = if (Test-Path -LiteralPath $discordWebhookFile -PathType Leaf) { 'CONFIGURED' } else { 'NOT CONFIGURED' }
    updateSafe = -not $activity.Running
}
if ($AsJson) { $result | ConvertTo-Json -Depth 6 } else { [pscustomobject]$result | Format-List }
