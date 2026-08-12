[CmdletBinding()]
param(
    [string]$ServerRoot,
    [string]$SettingsPath,
    [int]$TimeoutSeconds = 0
)

. (Join-Path $PSScriptRoot 'Common.ps1')
$serverRootResolved = Assert-ValidServerRoot (Resolve-ServerRoot $ServerRoot)
$settings = Get-ServerSettings -ServerRoot $serverRootResolved -SettingsPath $SettingsPath
if ($TimeoutSeconds -le 0) { $TimeoutSeconds = [int]$settings.gracefulStopTimeoutSeconds + 45 }
$activity = Get-ServerActivity $serverRootResolved
if (-not $activity.Running) {
    Write-Host 'Server and supervisor are already stopped.'
    return
}
if ($activity.Supervisors.Count -eq 0) {
    throw "Server activity exists on port $($activity.Port), but the management supervisor is not available to send a safe stop command. Nothing was killed; use the server console or investigate the recorded PID."
}

$request = Join-Path (Get-ManagementRoot $serverRootResolved) 'stop.request'
[IO.File]::WriteAllText($request, "requestedAt=$(Get-Date -Format o)`r`nrequestedByPid=$PID`r`n", [Text.UTF8Encoding]::new($false))
Write-Host "Normal Minecraft stop requested. Waiting up to $TimeoutSeconds seconds for saving, JVM exit, and port release..."
if (-not (Wait-ServerStopped $serverRootResolved $TimeoutSeconds)) {
    $state = Get-ServerState $serverRootResolved
    $detail = if ($state) { $state.latestCrashOrRestartEvent } else { 'No supervisor state available.' }
    throw "Graceful stop did not fully complete. No JVM was killed. Manual intervention is required. $detail"
}
Write-Host "Server stopped cleanly; port $($activity.Port) is no longer listening."
