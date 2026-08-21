[CmdletBinding()]
param(
    [string]$ProjectRoot,
    [int]$TestPort = 25581
)

$ErrorActionPreference = 'Stop'
if (-not $ProjectRoot) { $ProjectRoot = Split-Path -Parent $PSScriptRoot }
if ($TestPort -eq 25565) { throw 'The supervisor-resilience harness refuses production port 25565.' }
$root = [IO.Path]::GetFullPath($ProjectRoot)
$testRoot = [IO.Path]::GetFullPath((Join-Path $root 'build\server-infrastructure-test-supervisor-resilience'))
$expectedRoot = [IO.Path]::GetFullPath((Join-Path $root 'build\server-infrastructure-test-supervisor-resilience'))
if (-not $testRoot.Equals($expectedRoot, [StringComparison]::OrdinalIgnoreCase)) { throw 'Unsafe disposable supervisor-resilience test root.' }
if (Get-NetTCPConnection -LocalPort $TestPort -State Listen -ErrorAction SilentlyContinue) { throw "Disposable test port $TestPort is already in use." }
$productionBefore = @(Get-NetTCPConnection -LocalPort 25565 -State Listen -ErrorAction SilentlyContinue | Select-Object OwningProcess,LocalAddress,LocalPort)
if (Test-Path -LiteralPath $testRoot) { Remove-Item -LiteralPath $testRoot -Recurse -Force }

$serverRoot = Join-Path $testRoot 'server'
New-Item -ItemType Directory -Path $serverRoot,(Join-Path $serverRoot 'libraries'),(Join-Path $serverRoot 'logs'),(Join-Path $serverRoot 'server-management') -Force | Out-Null
[IO.File]::WriteAllText((Join-Path $serverRoot 'server.properties'), "level-name=world`r`nserver-ip=127.0.0.1`r`nserver-port=$TestPort`r`n", [Text.UTF8Encoding]::new($false))
$python = (Get-Command python -ErrorAction Stop).Source
$fake = Join-Path $root 'tests\fake_minecraft_server.py'
$settingsPath = Join-Path $testRoot 'test-settings.json'
$settings = [ordered]@{
    gracefulStopTimeoutSeconds = 5
    startupTimeoutSeconds = 15
    scheduledRestartMinutes = 0
    scheduledRestartDelaySeconds = 1
    scheduledRestartWarningSeconds = @()
    restartBackoffSeconds = @(1,2,3)
    rapidFailureWindowMinutes = 2
    maxRapidFailures = 3
    stableRunResetMinutes = 5
    discordAllowInsecureLocalTest = $false
    launchExecutable = $python
    launchArguments = @($fake, '--server-root', $serverRoot, '--port', "$TestPort")
}
[IO.File]::WriteAllText($settingsPath, (($settings | ConvertTo-Json -Depth 8) + "`r`n"), [Text.UTF8Encoding]::new($false))

$tools = Join-Path $root 'server-tools'
. (Join-Path $tools 'Common.ps1')
$statePath = Join-Path $serverRoot 'server-management\state.json'
$results = [ordered]@{
    testedAt = (Get-Date).ToString('o')
    testRoot = 'build/server-infrastructure-test-supervisor-resilience'
    testPort = $TestPort
    productionPort = 25565
}
$trackedPids = [Collections.Generic.List[int]]::new()
$unrelatedProcess = $null
$diagnosticDecoy = $null

function Wait-Until([scriptblock]$Condition, [int]$Seconds, [string]$Failure) {
    $deadline = (Get-Date).AddSeconds($Seconds)
    do {
        try { if (& $Condition) { return } } catch { }
        Start-Sleep -Milliseconds 200
    } while ((Get-Date) -lt $deadline)
    throw $Failure
}

function Get-TestState {
    if (-not (Test-Path -LiteralPath $statePath -PathType Leaf)) { return $null }
    return Get-Content -LiteralPath $statePath -Raw | ConvertFrom-Json
}

function Assert-TerminalIdentityCleared($State, [string]$Context) {
    if ($State.serverPid -or $State.supervisorPid -or $State.serverProcessFingerprint -or
        $State.supervisorProcessFingerprint -or $State.nextScheduledRestart) {
        throw "$Context retained an active PID, process fingerprint, or restart time."
    }
}

function Stop-TrackedDisposableProcess([int]$ProcessId) {
    if ($ProcessId -le 0) { return }
    $candidate = Get-CimInstance Win32_Process -Filter "ProcessId=$ProcessId" -ErrorAction SilentlyContinue
    if (-not $candidate) { return }
    $safeCommand = [string]$candidate.CommandLine
    if ($safeCommand -notmatch [regex]::Escape($testRoot) -and $safeCommand -notmatch 'server-supervisor-resilience-unrelated') {
        throw "Refusing to stop non-disposable PID $ProcessId."
    }
    Stop-Process -Id $ProcessId -Force -ErrorAction SilentlyContinue
}

try {
    # Phase 1: deterministically reproduce the historical Write-Host HostException.
    $wrapper = Join-Path $testRoot 'Server-Supervisor.ps1'
    $wrapperText = @'
[CmdletBinding()]
param([string]$Supervisor, [string]$ServerRoot, [string]$SettingsPath)
function Write-Host {
    param([object]$Object, [ConsoleColor]$ForegroundColor, [switch]$NoNewline, [object]$Separator)
    throw [System.Management.Automation.Host.HostException]::new('The Win32 internal error "No process is on the other end of the pipe" 0xE9 occurred while getting the console mode.')
}
& $Supervisor -ServerRoot $ServerRoot -SettingsPath $SettingsPath -Interactive
'@
    [IO.File]::WriteAllText($wrapper, $wrapperText, [Text.UTF8Encoding]::new($false))
    $brokenConsoleStdout = Join-Path $testRoot 'broken-console.stdout.log'
    $brokenConsoleStderr = Join-Path $testRoot 'broken-console.stderr.log'
    $brokenConsoleStdin = Join-Path $testRoot 'broken-console.stdin.txt'
    [IO.File]::WriteAllText($brokenConsoleStdin, '', [Text.UTF8Encoding]::new($false))
    $wrapperArguments = @(
        '-NoLogo','-NoProfile','-ExecutionPolicy','Bypass','-File',('"' + $wrapper + '"'),
        '-Supervisor',('"' + (Join-Path $tools 'Server-Supervisor.ps1') + '"'),
        '-ServerRoot',('"' + $serverRoot + '"'),'-SettingsPath',('"' + $settingsPath + '"')
    )
    $brokenConsoleHost = Start-Process -FilePath 'powershell.exe' -ArgumentList $wrapperArguments -WorkingDirectory $serverRoot `
        -WindowStyle Hidden -RedirectStandardInput $brokenConsoleStdin -RedirectStandardOutput $brokenConsoleStdout `
        -RedirectStandardError $brokenConsoleStderr -PassThru
    $trackedPids.Add($brokenConsoleHost.Id)
    Wait-Until { Get-NetTCPConnection -LocalPort $TestPort -State Listen -ErrorAction SilentlyContinue } 15 'Broken-console supervisor did not launch the disposable server.'
    Wait-Until { $state = Get-TestState; $state -and $state.status -eq 'online' } 10 'Broken-console supervisor never reached online state.'
    $brokenState = Get-TestState
    $trackedPids.Add([int]$brokenState.serverPid)
    $brokenConsoleHost.Refresh()
    if ($brokenConsoleHost.HasExited) { throw 'Simulated Write-Host HostException terminated the supervisor.' }
    if ($brokenState.interactiveConsoleOutputAvailable) { throw 'Supervisor did not disable the failed interactive output channel.' }
    $supervisorLogText = Get-Content -LiteralPath ([string]$brokenState.supervisorLog) -Raw
    if ($supervisorLogText -notmatch 'Interactive console output disabled after host write failure') {
        throw 'Supervisor did not record the simulated console failure in its file log.'
    }
    if ((Get-Content -LiteralPath $brokenConsoleStderr -Raw -ErrorAction SilentlyContinue) -match 'HostException|No process is on the other end of the pipe') {
        throw 'The simulated HostException escaped the no-throw console boundary.'
    }
    $results.brokenConsoleHostExceptionContained = 'PASS'
    $results.fileLoggingSurvivedBrokenConsole = 'PASS'
    $results.minecraftRemainedManagedAfterConsoleWriteFailure = 'PASS'

    & (Join-Path $tools 'Stop-Server.ps1') -ServerRoot $serverRoot -SettingsPath $settingsPath -TimeoutSeconds 15
    Wait-Until { $brokenConsoleHost.Refresh(); $brokenConsoleHost.HasExited } 10 'Broken-console supervisor host did not exit after a clean stop.'
    $terminalState = Get-TestState
    if ($terminalState.status -ne 'stopped') { throw 'Broken-console phase did not finish in stopped state.' }
    Assert-TerminalIdentityCleared $terminalState 'Broken-console clean stop'
    $results.brokenConsoleCleanSaveAndExit = 'PASS'
    $results.cleanStopClearsAllProcessIdentity = 'PASS'

    # Phase 2: a live unrelated process must never be accepted merely because
    # Windows reused a PID recorded in stale state.
    $unrelatedProcess = Start-Process -FilePath $python -ArgumentList @('-c','"import time; time.sleep(120)"','server-supervisor-resilience-unrelated') -WindowStyle Hidden -PassThru
    $trackedPids.Add($unrelatedProcess.Id)
    $staleState = Get-TestState
    $staleState.status = 'online'
    $staleState.serverPid = $unrelatedProcess.Id
    $staleState.serverProcessFingerprint = [pscustomobject]@{
        processId = $unrelatedProcess.Id
        creationTimeUtc = '2000-01-01T00:00:00.0000000Z'
        executablePath = 'C:\not-the-recorded-server.exe'
        commandLineSha256 = ('0' * 64)
        parentProcessId = 1
    }
    $staleState.supervisorPid = $null
    $staleState.supervisorProcessFingerprint = $null
    $staleState.nextScheduledRestart = (Get-Date).AddHours(1).ToString('o')
    Write-JsonAtomic $statePath $staleState
    $recycledStatus = & (Join-Path $tools 'Get-ServerStatus.ps1') -ServerRoot $serverRoot -SettingsPath $settingsPath -AsJson | ConvertFrom-Json
    $reconciledState = Get-TestState
    $unrelatedProcess.Refresh()
    if ($unrelatedProcess.HasExited) { throw 'Unrelated PID test process exited unexpectedly.' }
    $recordedLaunchCount = @($recycledStatus.recordedLaunchPid).Count
    if ($recycledStatus.server -ne 'STOPPED' -or -not $recycledStatus.updateSafe -or $recordedLaunchCount -ne 0) {
        throw "A recycled unrelated PID was incorrectly classified as the Minecraft server (server=$($recycledStatus.server); updateSafe=$($recycledStatus.updateSafe); recordedLaunchCount=$recordedLaunchCount)."
    }
    if ($reconciledState.status -ne 'stopped-after-abrupt-exit' -or -not $reconciledState.stateReconciledAt) {
        throw 'Stale PID state was not reconciled to stopped-after-abrupt-exit.'
    }
    Assert-TerminalIdentityCleared $reconciledState 'Recycled-PID reconciliation'
    $results.recycledUnrelatedPidRejected = 'PASS'
    $results.stalePidStateReconciled = 'PASS'
    Stop-TrackedDisposableProcess $unrelatedProcess.Id
    Wait-Until { -not (Get-Process -Id $unrelatedProcess.Id -ErrorAction SilentlyContinue) } 5 'Unrelated disposable process did not exit during cleanup.'

    # A diagnostic PowerShell command may mention the supervisor filename and
    # server root as plain text. Only an actual `-File ...\Server-Supervisor.ps1`
    # launch is a fallback supervisor; textual mentions must not block updates.
    $decoyCommand = "Start-Sleep -Seconds 120 # Server-Supervisor.ps1 $testRoot"
    $diagnosticDecoy = Start-Process -FilePath 'powershell.exe' -ArgumentList @('-NoProfile','-Command',('"' + $decoyCommand + '"')) -WindowStyle Hidden -PassThru
    $trackedPids.Add($diagnosticDecoy.Id)
    Start-Sleep -Milliseconds 500
    $decoyActivity = Get-ServerActivity $serverRoot
    if ($decoyActivity.Supervisors.Count -ne 0 -or $decoyActivity.Running) {
        throw 'A diagnostic command that merely mentioned Server-Supervisor.ps1 was misclassified as a live supervisor.'
    }
    $results.textualSupervisorFilenameDecoyRejected = 'PASS'
    Stop-TrackedDisposableProcess $diagnosticDecoy.Id
    Wait-Until { -not (Get-Process -Id $diagnosticDecoy.Id -ErrorAction SilentlyContinue) } 5 'Diagnostic decoy process did not exit during cleanup.'

    # Phase 3: if the supervisor is terminated but Minecraft survives, status
    # must stay unsafe and explicitly unmanaged. Once both are gone, stale state
    # is reconciled and a fresh managed launch is allowed.
    New-Item -ItemType File -Path (Join-Path $serverRoot 'linger-on-stdin-eof.flag') -Force | Out-Null
    & (Join-Path $tools 'Start-Server.ps1') -ServerRoot $serverRoot -SettingsPath $settingsPath
    $orphanState = Get-TestState
    $orphanSupervisorPid = [int]$orphanState.supervisorPid
    $orphanServerPid = [int]$orphanState.serverPid
    $trackedPids.Add($orphanSupervisorPid)
    $trackedPids.Add($orphanServerPid)
    $supervisorProcess = Get-CimInstance Win32_Process -Filter "ProcessId=$orphanSupervisorPid" -ErrorAction Stop
    if ($supervisorProcess.CommandLine -notmatch 'Server-Supervisor\.ps1' -or $supervisorProcess.CommandLine -notmatch [regex]::Escape($testRoot)) {
        throw 'Refusing to terminate a supervisor whose command line is not disposable.'
    }
    Stop-Process -Id $orphanSupervisorPid -Force
    Wait-Until { -not (Get-Process -Id $orphanSupervisorPid -ErrorAction SilentlyContinue) } 5 'Disposable supervisor did not terminate.'
    Wait-Until { (Get-Process -Id $orphanServerPid -ErrorAction SilentlyContinue) -and (Get-NetTCPConnection -LocalPort $TestPort -State Listen -ErrorAction SilentlyContinue) } 5 'Disposable Minecraft child did not remain as the intended orphan.'
    $unmanagedStatus = & (Join-Path $tools 'Get-ServerStatus.ps1') -ServerRoot $serverRoot -SettingsPath $settingsPath -AsJson | ConvertFrom-Json
    if ($unmanagedStatus.server -ne 'RUNNING / UNMANAGED' -or -not $unmanagedStatus.unmanaged -or $unmanagedStatus.updateSafe) {
        throw 'Orphaned Minecraft process was not reported as RUNNING / UNMANAGED and update-unsafe.'
    }
    try {
        & (Join-Path $tools 'Start-Server.ps1') -ServerRoot $serverRoot -SettingsPath $settingsPath
        throw 'Duplicate start unexpectedly succeeded while an unmanaged child was listening.'
    } catch {
        if ($_.Exception.Message -eq 'Duplicate start unexpectedly succeeded while an unmanaged child was listening.') { throw }
    }
    $results.orphanReportedRunningUnmanaged = 'PASS'
    $results.unmanagedServerBlocksUpdateAndDuplicateStart = 'PASS'

    Stop-TrackedDisposableProcess $orphanServerPid
    Wait-Until { -not (Get-NetTCPConnection -LocalPort $TestPort -State Listen -ErrorAction SilentlyContinue) } 5 'Disposable orphan did not release its port after test cleanup.'
    $afterAbruptStatus = & (Join-Path $tools 'Get-ServerStatus.ps1') -ServerRoot $serverRoot -SettingsPath $settingsPath -AsJson | ConvertFrom-Json
    $afterAbruptState = Get-TestState
    if ($afterAbruptStatus.server -ne 'STOPPED' -or -not $afterAbruptStatus.updateSafe -or $afterAbruptState.status -ne 'stopped-after-abrupt-exit') {
        throw 'Abrupt supervisor/server exit did not reconcile to a safe stopped state.'
    }
    Assert-TerminalIdentityCleared $afterAbruptState 'Abrupt-exit reconciliation'
    $results.abruptExitReconcilesAfterProcessesGone = 'PASS'

    Remove-Item -LiteralPath (Join-Path $serverRoot 'linger-on-stdin-eof.flag') -Force
    & (Join-Path $tools 'Start-Server.ps1') -ServerRoot $serverRoot -SettingsPath $settingsPath
    & (Join-Path $tools 'Stop-Server.ps1') -ServerRoot $serverRoot -SettingsPath $settingsPath -TimeoutSeconds 15
    $recoveryState = Get-TestState
    if ($recoveryState.status -ne 'stopped') { throw 'Fresh managed launch after stale-state recovery did not stop cleanly.' }
    Assert-TerminalIdentityCleared $recoveryState 'Post-reconciliation recovery launch'
    if (-not (Select-String -LiteralPath (Join-Path $serverRoot 'logs\latest.log') -SimpleMatch 'All dimensions are saved' -Quiet)) {
        throw 'Recovery launch did not record all-dimensions-saved evidence.'
    }
    $results.cleanRelaunchAfterReconciliation = 'PASS'
    $results.recoveryShutdownSavedAllDimensions = 'PASS'

    $productionAfter = @(Get-NetTCPConnection -LocalPort 25565 -State Listen -ErrorAction SilentlyContinue | Select-Object OwningProcess,LocalAddress,LocalPort)
    if (($productionBefore | ConvertTo-Json -Compress) -ne ($productionAfter | ConvertTo-Json -Compress)) {
        throw 'Production port 25565 listener state changed during the disposable resilience test.'
    }
    $results.productionPortTouched = $false
    $results.liveServerWorldOrPrismTouched = $false
    $results.status = 'PASS'
} finally {
    foreach ($trackedPid in @($trackedPids | Sort-Object -Unique)) {
        try { Stop-TrackedDisposableProcess $trackedPid } catch { }
    }
}

$auditPath = Join-Path $root 'audit\server-supervisor-resilience.json'
[IO.File]::WriteAllText($auditPath, (($results | ConvertTo-Json -Depth 8) + "`r`n"), [Text.UTF8Encoding]::new($false))
$results | ConvertTo-Json -Depth 8
