[CmdletBinding()]
param([string]$ServerRoot, [string]$SettingsPath, [switch]$AsJson)

. (Join-Path $PSScriptRoot 'Common.ps1')
$serverRootResolved = Assert-ValidServerRoot (Resolve-ServerRoot $ServerRoot)
$settings = Get-ServerSettings -ServerRoot $serverRootResolved -SettingsPath $SettingsPath
$activity = Get-ServerActivity $serverRootResolved
$state = $activity.State
$latestBackup = Get-LatestBackup $serverRootResolved $settings
$latestLog = Join-Path $serverRootResolved 'logs\latest.log'
$result = [ordered]@{
    serverRoot = $serverRootResolved
    server = if ($activity.Listeners.Count -gt 0 -or $activity.ServerProcesses.Count -gt 0) { 'RUNNING' } else { 'STOPPED' }
    minecraftPid = @($activity.Listeners | Select-Object -ExpandProperty OwningProcess -Unique)
    recordedLaunchPid = if ($activity.ServerProcesses.Count) { @($activity.ServerProcesses.ProcessId) } else { @() }
    port = $activity.Port
    portStatus = if ($activity.Listeners.Count -gt 0) { 'LISTENING' } else { 'NOT LISTENING' }
    supervisor = if ($activity.Supervisors.Count -gt 0) { 'RUNNING' } else { 'STOPPED' }
    supervisorPid = @($activity.Supervisors | Select-Object -ExpandProperty ProcessId -Unique)
    supervisorState = if ($state) { [string]$state.status } else { 'no state' }
    currentPackVersion = Get-CurrentPackVersion $serverRootResolved
    latestBackup = if ($latestBackup) { $latestBackup.FullName } else { 'none' }
    latestServerStartTime = if ($state -and $state.latestServerStartAt) { [string]$state.latestServerStartAt } else { 'unknown' }
    latestCrashOrRestartEvent = if ($state -and $state.latestCrashOrRestartEvent) { [string]$state.latestCrashOrRestartEvent } else { 'none recorded' }
    latestMinecraftLog = if (Test-Path -LiteralPath $latestLog) { $latestLog } else { 'none' }
    updateSafe = -not $activity.Running
}
if ($AsJson) { $result | ConvertTo-Json -Depth 6 } else { [pscustomobject]$result | Format-List }
