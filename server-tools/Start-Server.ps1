[CmdletBinding()]
param(
    [string]$ServerRoot,
    [int]$StartupTimeoutSeconds = 90
)

. (Join-Path $PSScriptRoot 'Common.ps1')
$serverRootResolved = Assert-ValidServerRoot (Resolve-ServerRoot $ServerRoot)
Assert-ServerStopped $serverRootResolved
$supervisor = Join-Path $serverRootResolved 'server-supervisor.ps1'
if (-not (Test-Path -LiteralPath $supervisor -PathType Leaf)) { throw "Supervisor script not found: $supervisor" }

$arguments = @('-NoProfile','-ExecutionPolicy','Bypass','-WindowStyle','Hidden','-File',('"' + $supervisor + '"'))
$process = Start-Process -FilePath 'powershell.exe' -ArgumentList $arguments -WorkingDirectory $serverRootResolved -WindowStyle Hidden -PassThru
$deadline = (Get-Date).AddSeconds($StartupTimeoutSeconds)
do {
    Start-Sleep -Seconds 1
    $activity = Get-ServerActivity $serverRootResolved
    if ($activity.Listeners.Count -gt 0) {
        Write-Host "Server is listening on port $($activity.Port). Supervisor PID: $($process.Id)"
        return
    }
    if ($process.HasExited) { throw "Server supervisor exited early with code $($process.ExitCode)." }
} while ((Get-Date) -lt $deadline)
throw "Server did not begin listening within $StartupTimeoutSeconds seconds. Check supervisor/latest logs."

