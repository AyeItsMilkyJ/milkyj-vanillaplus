[CmdletBinding()]
param(
    [string]$ServerRoot,
    [string]$SettingsPath,
    [int]$StartupTimeoutSeconds = 0,
    [switch]$Interactive
)

. (Join-Path $PSScriptRoot 'Common.ps1')

function Write-LauncherHostSafe([string]$Message, [string]$ForegroundColor = '') {
    try {
        if ($ForegroundColor) { Write-Host $Message -ForegroundColor $ForegroundColor }
        else { Write-Host $Message }
    } catch {
        # A detached/closing Windows console must not prevent the supervisor
        # from starting or completing state recovery.
    }
}

$serverRootResolved = Assert-ValidServerRoot (Resolve-ServerRoot $ServerRoot)
$settings = Get-ServerSettings -ServerRoot $serverRootResolved -SettingsPath $SettingsPath
if ($StartupTimeoutSeconds -le 0) { $StartupTimeoutSeconds = [int]$settings.startupTimeoutSeconds }
Assert-ServerStopped $serverRootResolved

$managementRoot = Get-ManagementRoot $serverRootResolved
New-Item -ItemType Directory -Path $managementRoot -Force | Out-Null
$stopRequest = Join-Path $managementRoot 'stop.request'
if (Test-Path -LiteralPath $stopRequest) { Remove-Item -LiteralPath $stopRequest -Force }

$supervisor = Join-Path $PSScriptRoot 'Server-Supervisor.ps1'
if (-not (Test-Path -LiteralPath $supervisor -PathType Leaf)) { throw "Supervisor script not found: $supervisor" }

if ($Interactive) {
    try { [Console]::Title = 'MilkyCraft Vanilla+ Server - Java Console' } catch { }
    Write-LauncherHostSafe 'Starting Minecraft in this console.' 'Cyan'
    Write-LauncherHostSafe 'Server output and commands share this one window. Type stop for a clean shutdown.' 'Cyan'
    $supervisorParameters = @{ ServerRoot = $serverRootResolved; Interactive = $true }
    if ($SettingsPath) { $supervisorParameters.SettingsPath = [IO.Path]::GetFullPath($SettingsPath) }
    & $supervisor @supervisorParameters
    return
}

$arguments = @(
    '-NoProfile', '-ExecutionPolicy', 'Bypass', '-WindowStyle', 'Hidden',
    '-File', ('"' + $supervisor + '"'), '-ServerRoot', ('"' + $serverRootResolved + '"')
)
if ($SettingsPath) { $arguments += @('-SettingsPath', ('"' + [IO.Path]::GetFullPath($SettingsPath) + '"')) }
$process = Start-Process -FilePath 'powershell.exe' -ArgumentList $arguments -WorkingDirectory $serverRootResolved -WindowStyle Hidden -PassThru

$deadline = (Get-Date).AddSeconds($StartupTimeoutSeconds)
do {
    Start-Sleep -Seconds 1
    $activity = Get-ServerActivity $serverRootResolved
    if ($activity.Listeners.Count -gt 0) {
        Write-LauncherHostSafe "Server is listening on port $($activity.Port). Supervisor PID: $($process.Id)"
        return
    }
    if ($process.HasExited) {
        $state = Get-ServerState $serverRootResolved
        $detail = if ($state) { "$($state.status): $($state.latestCrashOrRestartEvent)" } else { 'no state was written' }
        throw "Server supervisor exited before the server listened. $detail"
    }
} while ((Get-Date) -lt $deadline)

New-Item -ItemType File -Path $stopRequest -Force | Out-Null
throw "Server did not begin listening within $StartupTimeoutSeconds seconds. A graceful stop was requested; check server-management logs."
