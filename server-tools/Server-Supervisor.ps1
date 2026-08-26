[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$ServerRoot,
    [string]$SettingsPath,
    [switch]$Interactive,
    [switch]$ServerGui
)

$ErrorActionPreference = 'Stop'
if ($Interactive -and $ServerGui) { throw '-Interactive and -ServerGui are separate launch modes; choose only one.' }
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
$script:interactiveHostAvailable = [bool]$Interactive
$script:consoleFailureRecorded = $false

function Write-SupervisorLogFileOnlyBestEffort([string]$Message) {
    try {
        $line = "[{0}] {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss.fff zzz'), $Message
        [IO.File]::AppendAllText($supervisorLog, $line + "`r`n", [Text.UTF8Encoding]::new($false))
    } catch { }
}

function Write-InteractiveHostSafe([string]$Message, [string]$ForegroundColor = '') {
    if (-not $Interactive -or -not $script:interactiveHostAvailable) { return }
    try {
        if ($ForegroundColor) {
            Write-Host $Message -ForegroundColor $ForegroundColor
        } else {
            Write-Host $Message
        }
    } catch {
        # Closing/detaching a Windows console can make Write-Host throw a
        # HostException (0xE9). Console output is optional; server lifecycle and
        # atomic state persistence must continue without it.
        $script:interactiveHostAvailable = $false
        if (-not $script:consoleFailureRecorded) {
            $script:consoleFailureRecorded = $true
            Write-SupervisorLogFileOnlyBestEffort "Interactive console output disabled after host write failure: $($_.Exception.Message)"
        }
        if ($state) { $state.interactiveConsoleOutputAvailable = $false }
    }
}

function Write-SupervisorLog([string]$Message) {
    $line = "[{0}] {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss.fff zzz'), $Message
    [IO.File]::AppendAllText($supervisorLog, $line + "`r`n", [Text.UTF8Encoding]::new($false))
    Write-InteractiveHostSafe "[Supervisor] $Message" 'DarkCyan'
}

function Send-ServerCommand {
    param(
        [Parameter(Mandatory)][Diagnostics.Process]$Process,
        [Parameter(Mandatory)][string]$Command
    )

    if ($Process.HasExited) { return $false }
    try {
        $Process.StandardInput.WriteLine($Command)
        $Process.StandardInput.Flush()
        Write-SupervisorLog "> $Command"
        return $true
    } catch {
        Write-SupervisorLog "Unable to send '$Command' to server stdin: $($_.Exception.Message)"
        return $false
    }
}

function Wait-ForCleanProcessExit {
    param(
        [Parameter(Mandatory)][Diagnostics.Process]$Process,
        [Parameter(Mandatory)][int]$TimeoutSeconds
    )

    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    while (-not $Process.HasExited -and (Get-Date) -lt $deadline) { Start-Sleep -Milliseconds 250 }
    return $Process.HasExited
}

function Format-RestartWarning([int]$Seconds) {
    if ($Seconds -ge 60 -and ($Seconds % 60) -eq 0) {
        $minutes = [int]($Seconds / 60)
        if ($minutes -eq 1) { return '1 minute' }
        return "$minutes minutes"
    }
    if ($Seconds -eq 1) { return '1 second' }
    return "$Seconds seconds"
}

function Receive-InteractiveCommand {
    if (-not $Interactive -or $null -eq $script:consoleReadTask -or -not $script:consoleReadTask.IsCompleted) {
        return $null
    }
    try {
        $line = $script:consoleReadTask.GetAwaiter().GetResult()
    } catch {
        Write-SupervisorLog "Interactive console input ended: $($_.Exception.Message)"
        $script:consoleReadTask = $null
        return $null
    }
    if ($null -eq $line) {
        $script:consoleReadTask = $null
        return $null
    }
    try { $script:consoleReadTask = $script:consoleReader.ReadLineAsync() } catch { $script:consoleReadTask = $null }
    return $line.Trim()
}

$scheduledRestartMinutes = [double]$settings.scheduledRestartMinutes
$scheduledRestartDelaySeconds = [Math]::Max(0, [int]$settings.scheduledRestartDelaySeconds)
$scheduledRestartIntervalSeconds = $scheduledRestartMinutes * 60
$scheduledWarningSeconds = @($settings.scheduledRestartWarningSeconds | ForEach-Object { [int]$_ } |
    Where-Object { $_ -gt 0 -and $_ -le $scheduledRestartIntervalSeconds } | Sort-Object -Descending -Unique)
$script:consoleReader = $null
$script:consoleReadTask = $null
$supervisorFingerprint = Get-ProcessFingerprint -ProcessId $PID
$supervisorStartedAt = if ($supervisorFingerprint) { [string]$supervisorFingerprint.creationTimeUtc } else { (Get-Date).ToString('o') }
$state = [ordered]@{
    stateSchemaVersion = 2
    status = 'starting'
    supervisorPid = $PID
    supervisorProcessFingerprint = $supervisorFingerprint
    serverPid = $null
    serverProcessFingerprint = $null
    port = Get-ServerPort $serverRootResolved
    supervisorStartedAt = $supervisorStartedAt
    latestServerStartAt = $null
    latestServerExitAt = $null
    latestServerExitCode = $null
    latestCrashOrRestartEvent = $null
    nextScheduledRestart = $null
    scheduledRestartMinutes = $scheduledRestartMinutes
    interactiveConsole = [bool]$Interactive
    interactiveConsoleOutputAvailable = [bool]$Interactive
    serverGui = [bool]$ServerGui
    restartCount = 0
    rapidFailureCount = 0
    supervisorLog = $supervisorLog
    manualInterventionRequired = $false
}

function Save-State { Write-JsonAtomic $statePath $state }
function Set-Event([string]$Message) {
    $state.latestCrashOrRestartEvent = "$(Get-Date -Format o) $Message"
    Save-State
    Write-SupervisorLog $Message
}

function Mark-CurrentUpdateStartupVerified {
    try {
        $currentVersionPath = Join-Path $managementRoot 'current-version.json'
        $currentVersion = Read-JsonFile $currentVersionPath
        if (-not $currentVersion) { return }
        $updateRecordPath = [string](Get-OptionalPropertyValue $currentVersion 'updateRecord')
        if (-not $updateRecordPath) { return }
        $updateRecordPath = [IO.Path]::GetFullPath($updateRecordPath)
        $managementPrefix = $managementRoot.TrimEnd('\') + '\'
        if (-not $updateRecordPath.StartsWith($managementPrefix, [StringComparison]::OrdinalIgnoreCase)) {
            throw 'Current update record points outside server-management.'
        }
        $updateRecord = Read-JsonFile $updateRecordPath
        if (-not $updateRecord -or [string](Get-OptionalPropertyValue $updateRecord 'status') -ne 'installed-not-yet-start-verified') { return }
        Set-OptionalPropertyValue $updateRecord 'status' 'startup-verified'
        Set-OptionalPropertyValue $updateRecord 'startupVerifiedAt' (Get-Date).ToString('o')
        Write-JsonAtomic $updateRecordPath $updateRecord
        Write-SupervisorLog "Marked Packwiz update startup verification complete: $([string](Get-OptionalPropertyValue $currentVersion 'version'))."
    } catch {
        Write-SupervisorLog "Could not update Packwiz startup-verification bookkeeping: $($_.Exception.Message)"
    }
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
    $launchSpec = Get-LaunchSpec $serverRootResolved $settings -ServerGui:$ServerGui
    $launchMode = if ($ServerGui) { 'minecraft-gui' } elseif ($Interactive) { 'raw-console' } else { 'headless' }
    Write-SupervisorLog "Supervisor started as PID $PID. Port=$($state.port). Mode=$launchMode. Executable=$($launchSpec.Executable)"
    if ($Interactive) {
        try { [Console]::Title = 'MilkyCraft Vanilla+ Server - Java Console' } catch { }
        Write-InteractiveHostSafe ''
        Write-InteractiveHostSafe 'MilkyCraft Vanilla+ server console is active.' 'Green'
        Write-InteractiveHostSafe 'Type Minecraft commands normally. Type restart for a clean restart, or stop for a clean shutdown.' 'Cyan'
        Write-InteractiveHostSafe 'Do not close this window while the world is saving.' 'Yellow'
        Write-InteractiveHostSafe ''
        try {
            # Windows PowerShell 5.1's synchronized Console.In wrapper can make
            # ReadLineAsync block synchronously until an operator types a line.
            # Reading through StreamReader keeps startup non-blocking while still
            # forwarding commands from this single visible console to Minecraft.
            $script:consoleReader = [IO.StreamReader]::new(
                [Console]::OpenStandardInput(),
                [Console]::InputEncoding,
                $false,
                1024,
                $true
            )
            $script:consoleReadTask = $script:consoleReader.ReadLineAsync()
        } catch {
            Write-SupervisorLog "Interactive input is unavailable: $($_.Exception.Message)"
        }
    }

    while ($true) {
        if (Test-Path -LiteralPath $stopRequest) {
            $state.status = 'stopped'
            $state.serverPid = $null
            $state.serverProcessFingerprint = $null
            $state.nextScheduledRestart = $null
            Set-Event 'Intentional stop request observed while no server process was active.'
            break
        }

        $startAt = Get-Date
        $processInfo = [Diagnostics.ProcessStartInfo]::new()
        $processInfo.FileName = $launchSpec.Executable
        $processInfo.Arguments = $launchSpec.Arguments
        $processInfo.WorkingDirectory = $serverRootResolved
        $processInfo.UseShellExecute = $false
        $processInfo.CreateNoWindow = -not $Interactive
        $processInfo.RedirectStandardInput = $true
        # In interactive mode Java inherits this console's stdout/stderr. That gives
        # operators raw Forge/Minecraft output without opening a second terminal.
        $processInfo.RedirectStandardOutput = $false
        $processInfo.RedirectStandardError = $false
        $child = [Diagnostics.Process]::new()
        $child.StartInfo = $processInfo
        if (-not $child.Start()) { throw 'The Minecraft launch process did not start.' }

        $state.status = 'running'
        $state.serverPid = $child.Id
        $state.serverProcessFingerprint = Get-ProcessFingerprint -ProcessId $child.Id
        $state.latestServerStartAt = $startAt.ToString('o')
        $state.nextScheduledRestart = $null
        $state.manualInterventionRequired = $false
        Save-State
        Write-SupervisorLog "Minecraft launch process started as PID $($child.Id)."
        Send-DiscordServerNotification -ServerRoot $serverRootResolved -Settings $settings -Event starting `
            -Description 'The Minecraft process launched and is loading. An online message will follow only after the server reaches Done.' `
            -Fields @{ Port = $state.port; 'Server PID' = $child.Id }
        $onlineNotified = $false
        $scheduledRestartAt = $null
        $warningsSent = @{}
        $intentionalStop = $false
        $plannedRestart = $false
        $restartReason = $null

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
                    $state.status = 'online'
                    if ($scheduledRestartMinutes -gt 0) {
                        $scheduledRestartAt = (Get-Date).AddMinutes($scheduledRestartMinutes)
                        $state.nextScheduledRestart = $scheduledRestartAt.ToString('o')
                    }
                    Save-State
                    Mark-CurrentUpdateStartupVerified
                    Send-DiscordServerNotification -ServerRoot $serverRootResolved -Settings $settings -Event online `
                        -Description 'The server finished starting and is accepting players.' `
                        -Fields @{ Port = $state.port; 'Server PID' = $child.Id }
                }
            }

            if ($Interactive) {
                $operatorCommand = Receive-InteractiveCommand
                if ($operatorCommand -ieq 'stop') {
                    [IO.File]::WriteAllText($stopRequest, "requestedAt=$(Get-Date -Format o)`r`nrequestedBy=interactive-console`r`n", [Text.UTF8Encoding]::new($false))
                } elseif ($operatorCommand -ieq 'restart') {
                    $plannedRestart = $true
                    $restartReason = 'operator-requested'
                } elseif ($operatorCommand) {
                    $null = Send-ServerCommand -Process $child -Command $operatorCommand
                }
            }

            if (Test-Path -LiteralPath $stopRequest) {
                $intentionalStop = $true
                $state.status = 'stopping'
                $state.nextScheduledRestart = $null
                Set-Event "Intentional stop requested; saving and stopping Minecraft PID $($child.Id)."
                $null = Send-ServerCommand -Process $child -Command 'save-all flush'
                $null = Send-ServerCommand -Process $child -Command 'stop'
                if (-not (Wait-ForCleanProcessExit -Process $child -TimeoutSeconds ([int]$settings.gracefulStopTimeoutSeconds))) {
                    $state.status = 'manual-intervention-required'
                    $state.manualInterventionRequired = $true
                    Set-Event "Minecraft did not exit within $($settings.gracefulStopTimeoutSeconds)s after stop. It was NOT killed; manual intervention is required (possible lingering JVM/Distant Horizons shutdown)."
                    Send-DiscordServerNotification -ServerRoot $serverRootResolved -Settings $settings -Event failed `
                        -Description 'Minecraft did not finish its clean shutdown in time. Manual attention is required; the JVM was not force-killed.'
                    return
                }
                break
            }

            if (-not $plannedRestart -and $scheduledRestartAt) {
                $remainingSeconds = [int][Math]::Ceiling(($scheduledRestartAt - (Get-Date)).TotalSeconds)
                foreach ($warningSeconds in $scheduledWarningSeconds) {
                    if ($remainingSeconds -le $warningSeconds -and -not $warningsSent.ContainsKey($warningSeconds)) {
                        $warningText = Format-RestartWarning $warningSeconds
                        $null = Send-ServerCommand -Process $child -Command "say [MilkyCraft] Scheduled restart in $warningText."
                        $warningsSent[$warningSeconds] = $true
                    }
                }
                if ((Get-Date) -ge $scheduledRestartAt) {
                    $plannedRestart = $true
                    $restartReason = 'scheduled'
                }
            }

            if ($plannedRestart) {
                $state.status = 'scheduled-restart'
                $state.nextScheduledRestart = $null
                Set-Event "Clean $restartReason restart requested; saving and stopping Minecraft PID $($child.Id)."
                Send-DiscordServerNotification -ServerRoot $serverRootResolved -Settings $settings -Event restarting `
                    -Description "A clean $restartReason restart has begun. Players can reconnect when the online message appears."
                $null = Send-ServerCommand -Process $child -Command 'say [MilkyCraft] Server restarting now. Reconnect when it is back online.'
                $null = Send-ServerCommand -Process $child -Command 'save-all flush'
                $null = Send-ServerCommand -Process $child -Command 'stop'
                if (-not (Wait-ForCleanProcessExit -Process $child -TimeoutSeconds ([int]$settings.gracefulStopTimeoutSeconds))) {
                    $state.status = 'manual-intervention-required'
                    $state.manualInterventionRequired = $true
                    Set-Event "Minecraft did not exit within $($settings.gracefulStopTimeoutSeconds)s for a planned restart. It was NOT killed; manual intervention is required."
                    Send-DiscordServerNotification -ServerRoot $serverRootResolved -Settings $settings -Event failed `
                        -Description 'Minecraft did not finish its clean restart shutdown in time. The JVM was not force-killed.'
                    return
                }
                break
            }
            Start-Sleep -Milliseconds 250
        }

        if (-not $child.HasExited) { continue }
        $exitAt = Get-Date
        $exitCode = $child.ExitCode
        $state.serverPid = $null
        $state.serverProcessFingerprint = $null
        $state.latestServerExitAt = $exitAt.ToString('o')
        $state.latestServerExitCode = $exitCode
        $state.nextScheduledRestart = $null
        $uptime = $exitAt - $startAt
        # Persist terminal process identity immediately. Notifications and
        # console/log output happen later and must never leave a live-looking PID.
        Save-State

        # Commands entered in Minecraft's Swing GUI bypass the supervisor's stdin
        # command reader. Treat the GUI's own `stop` command or close button as an
        # intentional shutdown only when the exact session exited successfully and
        # the log proves Minecraft completed its normal full save. An unsaved or
        # non-zero GUI exit still follows the normal crash-recovery path.
        $cleanGuiShutdown = $false
        if ($ServerGui -and -not $intentionalStop -and -not $plannedRestart -and $exitCode -eq 0) {
            $latestLog = Join-Path $serverRootResolved 'logs\latest.log'
            if (Test-Path -LiteralPath $latestLog -PathType Leaf) {
                $latestLogItem = Get-Item -LiteralPath $latestLog
                if ($latestLogItem.LastWriteTime -ge $startAt) {
                    $normalStopLogged = [bool](Select-String -LiteralPath $latestLog -SimpleMatch 'Stopping server' -Quiet)
                    $allDimensionsSaved = [bool](Select-String -LiteralPath $latestLog -SimpleMatch 'ThreadedAnvilChunkStorage: All dimensions are saved' -Quiet)
                    $cleanGuiShutdown = $normalStopLogged -and $allDimensionsSaved
                }
            }
        }

        if ($cleanGuiShutdown) {
            $portDeadline = (Get-Date).AddSeconds(30)
            while ((Get-NetTCPConnection -LocalPort $state.port -State Listen -ErrorAction SilentlyContinue) -and (Get-Date) -lt $portDeadline) {
                Start-Sleep -Milliseconds 250
            }
            if (Get-NetTCPConnection -LocalPort $state.port -State Listen -ErrorAction SilentlyContinue) {
                $state.status = 'manual-intervention-required'
                $state.manualInterventionRequired = $true
                Set-Event "Minecraft GUI exited cleanly but port $($state.port) is still listening. No process was killed; manual intervention is required."
                break
            }
            $state.status = 'stopped'
            Set-Event "Intentional Minecraft GUI shutdown completed with exit code $exitCode; all dimensions saved and port $($state.port) released."
            Send-DiscordServerNotification -ServerRoot $serverRootResolved -Settings $settings -Event offline `
                -Description 'The server was stopped cleanly from the Minecraft server GUI and all dimensions were saved.' `
                -Fields @{ 'Exit code' = $exitCode }
            break
        }

        if ($intentionalStop -or $plannedRestart) {
            $portDeadline = (Get-Date).AddSeconds(30)
            while ((Get-NetTCPConnection -LocalPort $state.port -State Listen -ErrorAction SilentlyContinue) -and (Get-Date) -lt $portDeadline) {
                Start-Sleep -Milliseconds 250
            }
            if (Get-NetTCPConnection -LocalPort $state.port -State Listen -ErrorAction SilentlyContinue) {
                $state.status = 'manual-intervention-required'
                $state.manualInterventionRequired = $true
                Set-Event "Launch process exited but port $($state.port) is still listening. No process was killed; manual intervention is required."
                Send-DiscordServerNotification -ServerRoot $serverRootResolved -Settings $settings -Event failed `
                    -Description "The launch process exited but port $($state.port) is still open. Manual attention is required."
                break
            }

            if ($intentionalStop) {
                $state.status = 'stopped'
                Set-Event "Intentional shutdown completed with exit code $exitCode; port $($state.port) is no longer listening."
                Send-DiscordServerNotification -ServerRoot $serverRootResolved -Settings $settings -Event offline `
                    -Description 'The server stopped cleanly and the world was given time to save.' `
                    -Fields @{ 'Exit code' = $exitCode }
                break
            }

            $state.status = 'restart-delay'
            $state.restartCount = [int]$state.restartCount + 1
            Set-Event "Clean $restartReason shutdown completed; restart $($state.restartCount) begins in $scheduledRestartDelaySeconds seconds."
            $restartDeadline = (Get-Date).AddSeconds($scheduledRestartDelaySeconds)
            while ((Get-Date) -lt $restartDeadline) {
                $delayCommand = Receive-InteractiveCommand
                if ($delayCommand -ieq 'stop') {
                    [IO.File]::WriteAllText($stopRequest, "requestedAt=$(Get-Date -Format o)`r`nrequestedBy=interactive-console`r`n", [Text.UTF8Encoding]::new($false))
                } elseif ($delayCommand) {
                    Write-SupervisorLog "Server is between launches; '$delayCommand' was not sent. Type stop to cancel the restart."
                }
                if (Test-Path -LiteralPath $stopRequest) {
                    $state.status = 'stopped'
                    Set-Event 'Intentional stop request cancelled a pending planned restart.'
                    Send-DiscordServerNotification -ServerRoot $serverRootResolved -Settings $settings -Event offline `
                        -Description 'A pending restart was cancelled by an intentional stop request.'
                    return
                }
                Start-Sleep -Milliseconds 250
            }
            continue
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
            $backoffCommand = Receive-InteractiveCommand
            if ($backoffCommand -ieq 'stop') {
                [IO.File]::WriteAllText($stopRequest, "requestedAt=$(Get-Date -Format o)`r`nrequestedBy=interactive-console`r`n", [Text.UTF8Encoding]::new($false))
            } elseif ($backoffCommand) {
                Write-SupervisorLog "Server is in crash backoff; '$backoffCommand' was not sent. Type stop to cancel recovery."
            }
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
    $supervisorException = $_
    $state.status = 'supervisor-error'
    $state.manualInterventionRequired = $true
    $state.nextScheduledRestart = $null
    $state.latestCrashOrRestartEvent = "$(Get-Date -Format o) Supervisor error: $($supervisorException.Exception.Message)"

    # If Minecraft survived the supervisor error, request a normal save/stop.
    # Never force-kill it: an unresponsive child remains explicitly unmanaged.
    $childAliveAfterError = $false
    if ($child) {
        try { $childAliveAfterError = -not $child.HasExited } catch { }
    }
    if ($childAliveAfterError) {
        try { $child.StandardInput.WriteLine('save-all flush'); $child.StandardInput.Flush() } catch { }
        try { $child.StandardInput.WriteLine('stop'); $child.StandardInput.Flush() } catch { }
        try { $childAliveAfterError = -not (Wait-ForCleanProcessExit -Process $child -TimeoutSeconds ([int]$settings.gracefulStopTimeoutSeconds)) } catch { }
    }
    if (-not $childAliveAfterError) {
        $state.serverPid = $null
        $state.serverProcessFingerprint = $null
        if ($child) {
            $state.latestServerExitAt = (Get-Date).ToString('o')
            try { $state.latestServerExitCode = $child.ExitCode } catch { }
        }
    }
    try { Save-State } catch { }
    Write-SupervisorLogFileOnlyBestEffort "Supervisor error: $($supervisorException.Exception.Message)"
    try {
        Send-DiscordServerNotification -ServerRoot $serverRootResolved -Settings $settings -Event failed `
            -Description 'The server supervisor encountered an error and needs attention.'
    } catch { }
    throw $supervisorException
} finally {
    $childStillAlive = $false
    if ($child) {
        try { $childStillAlive = -not $child.HasExited } catch { }
    }
    if (-not $childStillAlive) {
        $state.serverPid = $null
        $state.serverProcessFingerprint = $null
    } else {
        $state.status = 'manual-intervention-required'
        $state.manualInterventionRequired = $true
        $state.nextScheduledRestart = $null
        $state.latestCrashOrRestartEvent = "$(Get-Date -Format o) Supervisor exited while Minecraft PID $($state.serverPid) remained alive. Nothing was killed; manual intervention is required."
    }
    if ([int]$state.supervisorPid -eq $PID) {
        $state.supervisorPid = $null
        $state.supervisorProcessFingerprint = $null
    }
    $state.nextScheduledRestart = $null
    try { Save-State } catch { }
    if ($child) { try { $child.Dispose() } catch { } }
    if ($lock) { try { $lock.Dispose() } catch { } }
    if (Test-Path -LiteralPath $lockPath) { Remove-Item -LiteralPath $lockPath -Force -ErrorAction SilentlyContinue }
}
