[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$ServerRoot,
    [string]$SettingsPath
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Common.ps1')
. (Join-Path $PSScriptRoot 'Discord-Notifications.ps1')
$serverRootResolved = Assert-ValidServerRoot $ServerRoot
$settings = Get-ServerSettings -ServerRoot $serverRootResolved -SettingsPath $SettingsPath
$managementRoot = Get-ManagementRoot $serverRootResolved
$statePath = Get-StatePath $serverRootResolved
$stopRequest = Join-Path $managementRoot 'stop.request'
$lockPath = Join-Path $managementRoot 'supervisor.lock'
$logRoot = Join-Path $managementRoot 'logs'
New-Item -ItemType Directory -Path $logRoot -Force | Out-Null
$supervisorLog = Join-Path $logRoot ("supervisor-{0}.log" -f (Get-Date -Format 'yyyyMMdd-HHmmss'))

function Write-SupervisorLog([string]$Message) {
    $line = "[{0}] {1}`r`n" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss.fff zzz'), $Message
    [IO.File]::AppendAllText($supervisorLog, $line, [Text.UTF8Encoding]::new($false))
}

$state = [ordered]@{
    status = 'starting'
    supervisorPid = $PID
    serverPid = $null
    port = Get-ServerPort $serverRootResolved
    supervisorStartedAt = (Get-Date).ToString('o')
    latestServerStartAt = $null
    latestServerExitAt = $null
    latestServerExitCode = $null
    latestCrashOrRestartEvent = $null
    restartCount = 0
    rapidFailureCount = 0
    supervisorLog = $supervisorLog
    manualInterventionRequired = $false
}

function Save-State { Write-JsonAtomic $statePath $state }
function Set-Event([string]$Message) {
    $state.latestCrashOrRestartEvent = "$(Get-Date -Format o) $Message"
    Write-SupervisorLog $Message
    Save-State
}

$lock = $null
$child = $null
try {
    try {
        $lock = [IO.File]::Open($lockPath, [IO.FileMode]::OpenOrCreate, [IO.FileAccess]::ReadWrite, [IO.FileShare]::None)
    } catch {
        throw 'Another supervisor owns the server-management lock; duplicate start refused.'
    }
    if (Test-Path -LiteralPath $stopRequest) { Remove-Item -LiteralPath $stopRequest -Force }
    $crashTimes = [Collections.Generic.List[datetime]]::new()
    $launchSpec = Get-LaunchSpec $serverRootResolved $settings
    Write-SupervisorLog "Supervisor started as PID $PID. Port=$($state.port). Executable=$($launchSpec.Executable)"

    while ($true) {
        if (Test-Path -LiteralPath $stopRequest) {
            $state.status = 'stopped'
            $state.serverPid = $null
            Set-Event 'Intentional stop request observed while no server process was active.'
            break
        }

        $startAt = Get-Date
        $processInfo = [Diagnostics.ProcessStartInfo]::new()
        $processInfo.FileName = $launchSpec.Executable
        $processInfo.Arguments = $launchSpec.Arguments
        $processInfo.WorkingDirectory = $serverRootResolved
        $processInfo.UseShellExecute = $false
        $processInfo.CreateNoWindow = $true
        $processInfo.RedirectStandardInput = $true
        $child = [Diagnostics.Process]::new()
        $child.StartInfo = $processInfo
        if (-not $child.Start()) { throw 'The Minecraft launch process did not start.' }

        $state.status = 'running'
        $state.serverPid = $child.Id
        $state.latestServerStartAt = $startAt.ToString('o')
        $state.manualInterventionRequired = $false
        Save-State
        Write-SupervisorLog "Minecraft launch process started as PID $($child.Id)."
        $onlineNotified = $false

        $intentional = $false
        while (-not $child.HasExited) {
            if (-not $onlineNotified) {
                $latestLog = Join-Path $serverRootResolved 'logs\latest.log'
                $freshDone = $false
                if (Test-Path -LiteralPath $latestLog -PathType Leaf) {
                    $logItem = Get-Item -LiteralPath $latestLog
                    if ($logItem.LastWriteTime -ge $startAt) {
                        $freshDone = [bool](Select-String -LiteralPath $latestLog -SimpleMatch 'Done (' -Quiet)
                    }
                }
                if ($freshDone) {
                    $onlineNotified = $true
                    Send-DiscordServerNotification -ServerRoot $serverRootResolved -Settings $settings -Event online `
                        -Description 'The server finished starting and is accepting players.' `
                        -Fields @{ Port = $state.port; 'Server PID' = $child.Id }
                }
            }
            if (Test-Path -LiteralPath $stopRequest) {
                $intentional = $true
                $state.status = 'stopping'
                Set-Event "Intentional stop requested; sending Minecraft's normal stop command to PID $($child.Id)."
                try {
                    $child.StandardInput.WriteLine('stop')
                    $child.StandardInput.Flush()
                } catch {
                    Write-SupervisorLog "Unable to write stop to server stdin: $($_.Exception.Message)"
                }
                $deadline = (Get-Date).AddSeconds([int]$settings.gracefulStopTimeoutSeconds)
                while (-not $child.HasExited -and (Get-Date) -lt $deadline) { Start-Sleep -Milliseconds 500 }
                if (-not $child.HasExited) {
                    $state.status = 'manual-intervention-required'
                    $state.manualInterventionRequired = $true
                    Set-Event "Minecraft did not exit within $($settings.gracefulStopTimeoutSeconds)s after stop. It was NOT killed; manual intervention is required (possible lingering JVM/Distant Horizons shutdown)."
                    Send-DiscordServerNotification -ServerRoot $serverRootResolved -Settings $settings -Event failed `
                        -Description 'Minecraft did not finish its clean shutdown in time. Manual attention is required; the JVM was not force-killed.'
                    return
                }
                break
            }
            Start-Sleep -Milliseconds 500
        }

        if (-not $child.HasExited) { continue }
        $exitAt = Get-Date
        $exitCode = $child.ExitCode
        $state.serverPid = $null
        $state.latestServerExitAt = $exitAt.ToString('o')
        $state.latestServerExitCode = $exitCode
        $uptime = $exitAt - $startAt

        if ($intentional) {
            $portDeadline = (Get-Date).AddSeconds(30)
            while ((Get-NetTCPConnection -LocalPort $state.port -State Listen -ErrorAction SilentlyContinue) -and (Get-Date) -lt $portDeadline) {
                Start-Sleep -Milliseconds 500
            }
            if (Get-NetTCPConnection -LocalPort $state.port -State Listen -ErrorAction SilentlyContinue) {
                $state.status = 'manual-intervention-required'
                $state.manualInterventionRequired = $true
                Set-Event "Launch process exited but port $($state.port) is still listening. No process was killed; manual intervention is required."
                Send-DiscordServerNotification -ServerRoot $serverRootResolved -Settings $settings -Event failed `
                    -Description "The launch process exited but port $($state.port) is still open. Manual attention is required."
            } else {
                $state.status = 'stopped'
                Set-Event "Intentional shutdown completed with exit code $exitCode; port $($state.port) is no longer listening."
                Send-DiscordServerNotification -ServerRoot $serverRootResolved -Settings $settings -Event offline `
                    -Description 'The server stopped cleanly and the world was given time to save.' `
                    -Fields @{ 'Exit code' = $exitCode }
            }
            break
        }

        if ($uptime.TotalMinutes -ge [double]$settings.stableRunResetMinutes) { $crashTimes.Clear() }
        $crashTimes.Add($exitAt)
        $cutoff = $exitAt.AddMinutes(-[double]$settings.rapidFailureWindowMinutes)
        for ($i = $crashTimes.Count - 1; $i -ge 0; $i--) {
            if ($crashTimes[$i] -lt $cutoff) { $crashTimes.RemoveAt($i) }
        }
        $state.rapidFailureCount = $crashTimes.Count
        if ($crashTimes.Count -ge [int]$settings.maxRapidFailures) {
            $state.status = 'failed-repeatedly'
            $state.manualInterventionRequired = $true
            Set-Event "Minecraft exited unexpectedly $($crashTimes.Count) times inside $($settings.rapidFailureWindowMinutes) minutes. Automatic restarts stopped. Last exit=$exitCode."
            Send-DiscordServerNotification -ServerRoot $serverRootResolved -Settings $settings -Event failed `
                -Description "The server exited unexpectedly $($crashTimes.Count) times in $($settings.rapidFailureWindowMinutes) minutes. Automatic retries stopped." `
                -Fields @{ 'Last exit code' = $exitCode }
            break
        }

        $backoffs = @($settings.restartBackoffSeconds | ForEach-Object { [int]$_ })
        if ($backoffs.Count -eq 0) { $backoffs = @(15) }
        $backoffIndex = [Math]::Min($crashTimes.Count - 1, $backoffs.Count - 1)
        $delay = $backoffs[$backoffIndex]
        $state.status = 'restart-backoff'
        $state.restartCount = [int]$state.restartCount + 1
        Set-Event "Unexpected exit code $exitCode after $([Math]::Round($uptime.TotalSeconds, 1))s; restart $($state.restartCount) scheduled after ${delay}s backoff."
        Send-DiscordServerNotification -ServerRoot $serverRootResolved -Settings $settings -Event crashed `
            -Description "The server exited unexpectedly. A recovery restart is scheduled in $delay seconds." `
            -Fields @{ 'Exit code' = $exitCode; Uptime = "$([Math]::Round($uptime.TotalSeconds, 1)) seconds"; Attempt = $state.restartCount }
        $backoffDeadline = (Get-Date).AddSeconds($delay)
        while ((Get-Date) -lt $backoffDeadline) {
            if (Test-Path -LiteralPath $stopRequest) {
                $state.status = 'stopped'
                Set-Event 'Intentional stop request cancelled a pending crash restart.'
                Send-DiscordServerNotification -ServerRoot $serverRootResolved -Settings $settings -Event offline `
                    -Description 'A pending crash-recovery restart was cancelled by an intentional stop request.'
                return
            }
            Start-Sleep -Milliseconds 250
        }
    }
} catch {
    $state.status = 'supervisor-error'
    $state.manualInterventionRequired = $true
    Set-Event "Supervisor error: $($_.Exception.Message)"
    Send-DiscordServerNotification -ServerRoot $serverRootResolved -Settings $settings -Event failed `
        -Description 'The server supervisor encountered an error and needs attention.'
    throw
} finally {
    if ($lock) { $lock.Dispose() }
    if (Test-Path -LiteralPath $lockPath) { Remove-Item -LiteralPath $lockPath -Force -ErrorAction SilentlyContinue }
}
