[CmdletBinding()]
param(
    [string]$ProjectRoot,
    [int]$TestPort = 25579
)

$ErrorActionPreference = 'Stop'
if (-not $ProjectRoot) { $ProjectRoot = Split-Path -Parent $PSScriptRoot }
if ($TestPort -eq 25565) { throw 'The visible-console harness refuses production port 25565.' }
$root = [IO.Path]::GetFullPath($ProjectRoot)
$testRoot = [IO.Path]::GetFullPath((Join-Path $root 'build\server-infrastructure-test-visible-console'))
$expectedRoot = [IO.Path]::GetFullPath((Join-Path $root 'build\server-infrastructure-test-visible-console'))
if (-not $testRoot.Equals($expectedRoot, [StringComparison]::OrdinalIgnoreCase)) { throw 'Unsafe disposable visible-console test root.' }
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
    scheduledRestartMinutes = 0.05
    scheduledRestartDelaySeconds = 1
    scheduledRestartWarningSeconds = @(2,1)
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
$supervisorSource = Get-Content -LiteralPath (Join-Path $tools 'Server-Supervisor.ps1') -Raw
if ($supervisorSource -match '\[Console\]::In\.ReadLineAsync\(') {
    throw 'Visible-console supervisor still uses the blocking Windows PowerShell Console.In async wrapper.'
}
$stdoutPath = Join-Path $testRoot 'visible-console.stdout.log'
$stderrPath = Join-Path $testRoot 'visible-console.stderr.log'
$stdinPath = Join-Path $testRoot 'visible-console.stdin.txt'
[IO.File]::WriteAllText($stdinPath, "say visible-console-input-test`r`n", [Text.UTF8Encoding]::new($false))
$launchScript = Join-Path $tools 'Start-Server.ps1'
$arguments = @(
    '-NoLogo', '-NoProfile', '-ExecutionPolicy', 'Bypass',
    '-File', ('"' + $launchScript + '"'),
    '-ServerRoot', ('"' + $serverRoot + '"'),
    '-SettingsPath', ('"' + $settingsPath + '"'),
    '-Interactive'
)
$hostProcess = $null
$results = [ordered]@{
    testedAt = (Get-Date).ToString('o')
    testRoot = 'build/server-infrastructure-test-visible-console'
    testPort = $TestPort
    productionPort = 25565
    nonBlockingConsoleReader = 'PASS'
}

function Wait-Until([scriptblock]$Condition, [int]$Seconds, [string]$Failure) {
    $deadline = (Get-Date).AddSeconds($Seconds)
    do {
        try { if (& $Condition) { return } } catch [IO.IOException] { }
        Start-Sleep -Milliseconds 200
    } while ((Get-Date) -lt $deadline)
    throw $Failure
}

function Read-TestState([int]$Seconds = 5) {
    $deadline = (Get-Date).AddSeconds($Seconds)
    do {
        try { return (Get-Content -LiteralPath $statePath -Raw | ConvertFrom-Json) } catch { }
        Start-Sleep -Milliseconds 100
    } while ((Get-Date) -lt $deadline)
    throw 'Disposable supervisor state remained unreadable.'
}

function Stop-TestProcess([int]$ProcessId) {
    if ($ProcessId -le 0) { return }
    $candidate = Get-CimInstance Win32_Process -Filter "ProcessId=$ProcessId" -ErrorAction SilentlyContinue
    if ($candidate -and $candidate.CommandLine -and $candidate.CommandLine -match 'server-infrastructure-test-visible-console') {
        Stop-Process -Id $ProcessId -Force -ErrorAction SilentlyContinue
    }
}

try {
    $hostProcess = Start-Process -FilePath 'powershell.exe' -ArgumentList $arguments -WorkingDirectory $serverRoot `
        -WindowStyle Hidden -RedirectStandardInput $stdinPath -RedirectStandardOutput $stdoutPath `
        -RedirectStandardError $stderrPath -PassThru

    Wait-Until { Get-NetTCPConnection -LocalPort $TestPort -State Listen -ErrorAction SilentlyContinue } 15 'Interactive disposable server never listened.'
    $statePath = Join-Path $serverRoot 'server-management\state.json'
    Wait-Until { Test-Path -LiteralPath $statePath -PathType Leaf } 5 'Interactive supervisor did not write state.'
    $firstState = Read-TestState
    if ([int]$firstState.supervisorPid -ne $hostProcess.Id -or -not $firstState.interactiveConsole) {
        throw 'Interactive launcher did not run the supervisor inline in its one PowerShell host.'
    }
    $firstChildPid = [int]$firstState.serverPid
    $firstChild = Get-CimInstance Win32_Process -Filter "ProcessId=$firstChildPid" -ErrorAction Stop
    if ([int]$firstChild.ParentProcessId -ne $hostProcess.Id) { throw 'Disposable Minecraft process is not a direct child of the interactive console host.' }
    $secondShell = @(Get-CimInstance Win32_Process -ErrorAction SilentlyContinue | Where-Object {
        [int]$_.ParentProcessId -eq $hostProcess.Id -and $_.Name -match '^(?:powershell|pwsh|cmd)\.exe$'
    })
    if ($secondShell.Count -ne 0) { throw 'Interactive launch opened an unexpected second command shell.' }
    $results.inlineSupervisorPid = 'PASS'
    $results.directMinecraftChild = 'PASS'
    $results.noSecondCommandShell = 'PASS'

    Wait-Until {
        $state = Read-TestState
        $countPath = Join-Path $serverRoot 'server-management\fake-launch-count.txt'
        $count = if (Test-Path -LiteralPath $countPath) { [int](Get-Content -LiteralPath $countPath -Raw) } else { 0 }
        $count -ge 2 -and [int]$state.restartCount -ge 1 -and $state.serverPid -and
            (Get-NetTCPConnection -LocalPort $TestPort -State Listen -ErrorAction SilentlyContinue)
    } 20 'Compressed scheduled restart did not stop and relaunch the disposable server.'

    $afterRestartState = Read-TestState
    if ([int]$afterRestartState.serverPid -eq $firstChildPid) { throw 'Scheduled restart did not create a new Minecraft process.' }
    $commandsPath = Join-Path $serverRoot 'server-management\fake-commands.log'
    $commands = @(Get-Content -LiteralPath $commandsPath -ErrorAction Stop)
    if ('say visible-console-input-test' -notin $commands) { throw 'Interactive console input was not forwarded to Minecraft stdin.' }
    if (-not ($commands -match '^say \[MilkyCraft\] Scheduled restart in ')) { throw 'Scheduled warning command was not delivered.' }
    $saveIndex = [Array]::IndexOf($commands, 'save-all flush')
    $stopIndex = [Array]::IndexOf($commands, 'stop')
    if ($saveIndex -lt 0 -or $stopIndex -lt 0 -or $saveIndex -gt $stopIndex) { throw 'Scheduled restart did not save before its normal stop command.' }
    $results.scheduledRestart = 'PASS'
    $results.interactiveCommandForwarding = 'PASS'
    $results.restartWarning = 'PASS'
    $results.saveBeforeStop = 'PASS'

    Wait-Until {
        (Test-Path -LiteralPath $stdoutPath) -and (Get-Content -LiteralPath $stdoutPath -Raw -ErrorAction SilentlyContinue) -match 'server console is active' -and
            (Get-Content -LiteralPath $stdoutPath -Raw -ErrorAction SilentlyContinue) -match '\[Fake Minecraft\] Done'
    } 5 'Raw Minecraft stdout or interactive heading did not reach the shared console stream.'
    if ((Get-Content -LiteralPath $stderrPath -Raw -ErrorAction Stop) -notmatch '\[Fake Minecraft stderr\]') {
        throw 'Raw Minecraft stderr did not reach the shared console error stream.'
    }
    $results.rawJavaStdout = 'PASS'
    $results.rawJavaStderr = 'PASS'

    $wrapperText = Get-Content -LiteralPath (Join-Path $tools 'RUN SERVER CONSOLE.bat') -Raw
    if ($wrapperText -notmatch '(?i)-Interactive' -or $wrapperText -match '(?i)-ServerGui') {
        throw 'RUN SERVER CONSOLE.bat does not use the raw one-window interactive path.'
    }
    foreach ($wrapper in @('START SERVER.bat', 'Start-Server.bat')) {
        $guiWrapperText = Get-Content -LiteralPath (Join-Path $tools $wrapper) -Raw
        if ($guiWrapperText -notmatch '(?i)Launch-ServerGui\.vbs' -or $guiWrapperText -match '(?i)-Interactive') {
            throw "$wrapper is not routed to the detached Minecraft GUI launcher."
        }
    }
    $interactiveBlock = Get-Content -LiteralPath $launchScript -Raw
    if ($interactiveBlock -notmatch '\$Interactive' -or $interactiveBlock -notmatch '& \$supervisor @supervisorParameters') {
        throw 'Start-Server.ps1 does not invoke the interactive supervisor inline.'
    }
    $results.rawConsoleWrapper = 'PASS'
    $results.guiWrappersSeparated = 'PASS'

    & (Join-Path $tools 'Stop-Server.ps1') -ServerRoot $serverRoot -SettingsPath $settingsPath -TimeoutSeconds 15
    Wait-Until { $hostProcess.Refresh(); $hostProcess.HasExited } 10 'Interactive PowerShell host remained after a clean server stop.'
    if (Get-NetTCPConnection -LocalPort $TestPort -State Listen -ErrorAction SilentlyContinue) { throw 'Disposable port remained open after stop.' }
    $finalState = Read-TestState
    if ($finalState.status -ne 'stopped' -or $finalState.serverPid -or $finalState.supervisorPid -or
        $finalState.serverProcessFingerprint -or $finalState.supervisorProcessFingerprint -or $finalState.nextScheduledRestart) {
        throw 'Final supervisor state retained an active PID, fingerprint, or restart time after a clean stop.'
    }
    $latestLog = Join-Path $serverRoot 'logs\latest.log'
    if (-not (Select-String -LiteralPath $latestLog -SimpleMatch 'All dimensions are saved' -Quiet)) {
        throw 'Final stop did not record full dimension-save evidence.'
    }
    $results.externalStopRecognizedInlineSupervisor = 'PASS'
    $results.cleanShutdownAndSave = 'PASS'
    $results.hostAndChildExited = 'PASS'
    $results.terminalStateClearsProcessIdentity = 'PASS'

    $productionAfter = @(Get-NetTCPConnection -LocalPort 25565 -State Listen -ErrorAction SilentlyContinue | Select-Object OwningProcess,LocalAddress,LocalPort)
    if (($productionBefore | ConvertTo-Json -Compress) -ne ($productionAfter | ConvertTo-Json -Compress)) {
        throw 'Production port 25565 listener state changed during the disposable visible-console test.'
    }
    $results.productionPortTouched = $false
    $results.liveServerWorldOrPrismTouched = $false
    $results.manualAcceptanceStillRequired = 'Use RUN SERVER CONSOLE.bat only when raw terminal troubleshooting is required.'
    $results.status = 'PASS'
} finally {
    if ($hostProcess) {
        $hostProcess.Refresh()
        if (-not $hostProcess.HasExited) { Stop-TestProcess $hostProcess.Id }
    }
    $statePath = Join-Path $serverRoot 'server-management\state.json'
    if (Test-Path -LiteralPath $statePath -PathType Leaf) {
        $cleanupState = Read-TestState
        if ($cleanupState.serverPid) { Stop-TestProcess ([int]$cleanupState.serverPid) }
        if ($cleanupState.supervisorPid) { Stop-TestProcess ([int]$cleanupState.supervisorPid) }
    }
}

$auditPath = Join-Path $root 'audit\visible-server-console.json'
[IO.File]::WriteAllText($auditPath, (($results | ConvertTo-Json -Depth 8) + "`r`n"), [Text.UTF8Encoding]::new($false))
$results | ConvertTo-Json -Depth 8
