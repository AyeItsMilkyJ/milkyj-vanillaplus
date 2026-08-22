[CmdletBinding()]
param(
    [string]$ProjectRoot,
    [string]$SourceServerRoot,
    [int]$TestPort = 25582,
    [int]$StartupTimeoutSeconds = 420
)

$ErrorActionPreference = 'Stop'
if (-not $ProjectRoot) { $ProjectRoot = Split-Path -Parent $PSScriptRoot }
if ($TestPort -eq 25565) { throw 'The Forge GUI harness refuses production port 25565.' }
$root = [IO.Path]::GetFullPath($ProjectRoot)
$source = if ($SourceServerRoot) {
    [IO.Path]::GetFullPath($SourceServerRoot)
} else {
    [IO.Path]::GetFullPath((Join-Path $root 'build\end-to-end\server'))
}
$testRoot = [IO.Path]::GetFullPath((Join-Path $root 'build\forge-server-gui-integration'))
$expectedRoot = [IO.Path]::GetFullPath((Join-Path $root 'build\forge-server-gui-integration'))
if (-not $testRoot.Equals($expectedRoot, [StringComparison]::OrdinalIgnoreCase)) {
    throw 'Unsafe disposable Forge GUI test path.'
}
if (-not (Test-Path -LiteralPath (Join-Path $source 'mods') -PathType Container)) {
    throw "Disposable Forge server source is unavailable: $source"
}
if (-not (Test-Path -LiteralPath (Join-Path $source 'libraries\net\minecraftforge\forge') -PathType Container)) {
    throw "Disposable Forge libraries are unavailable: $source"
}
if (Get-NetTCPConnection -LocalPort $TestPort -State Listen -ErrorAction SilentlyContinue) {
    throw "Disposable test port $TestPort is already in use."
}

$sourceJava = @(Get-CimInstance Win32_Process -Filter "Name='java.exe' OR Name='javaw.exe'" -ErrorAction SilentlyContinue |
    Where-Object { $_.CommandLine -and $_.CommandLine -match [regex]::Escape($source) })
if ($sourceJava.Count -gt 0) {
    throw 'Selected source installation is active; read-only cloning was refused.'
}

function Get-PortSnapshot([int]$Port) {
    return @(Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue |
        Sort-Object OwningProcess,LocalAddress,LocalPort |
        Select-Object OwningProcess,LocalAddress,LocalPort)
}

function Wait-Until([scriptblock]$Condition, [int]$Seconds, [string]$Failure) {
    $deadline = (Get-Date).AddSeconds($Seconds)
    do {
        try { if (& $Condition) { return } } catch [IO.IOException] { }
        Start-Sleep -Milliseconds 250
    } while ((Get-Date) -lt $deadline)
    throw $Failure
}

function Get-ProcessWindow([int]$ProcessId) {
    if ($ProcessId -le 0) { return $null }
    try {
        $process = Get-Process -Id $ProcessId -ErrorAction Stop
        $process.Refresh()
        return [pscustomobject]@{
            Handle = [Int64]$process.MainWindowHandle
            Title = [string]$process.MainWindowTitle
        }
    } catch {
        return $null
    }
}

function Stop-DisposableProcess([int]$ProcessId, $Fingerprint) {
    if ($ProcessId -le 0) { return }
    $candidate = Get-CimInstance Win32_Process -Filter "ProcessId=$ProcessId" -ErrorAction SilentlyContinue
    if (-not $candidate) { return }
    $isTestSupervisor = $candidate.CommandLine -and $candidate.CommandLine -match [regex]::Escape($testRoot)
    $isRecordedTestJava = $candidate.Name -match '^javaw?\.exe$' -and
        $Fingerprint -and (Test-ProcessFingerprint $candidate $Fingerprint)
    if (-not $isTestSupervisor -and -not $isRecordedTestJava) {
        throw "Refusing to terminate non-disposable PID $ProcessId."
    }
    Stop-Process -Id $ProcessId -Force -ErrorAction SilentlyContinue
}

$productionBefore = Get-PortSnapshot 25565
if (Test-Path -LiteralPath $testRoot) { Remove-Item -LiteralPath $testRoot -Recurse -Force }
$serverRoot = Join-Path $testRoot 'server'
New-Item -ItemType Directory -Path $serverRoot -Force | Out-Null

foreach ($directory in @(
    'mods', 'config', 'defaultconfigs', 'libraries', 'kubejs', 'scripts',
    'moonlight-global-datapacks', 'patchouli_books'
)) {
    $sourceDirectory = Join-Path $source $directory
    if (Test-Path -LiteralPath $sourceDirectory -PathType Container) {
        Copy-Item -LiteralPath $sourceDirectory -Destination $serverRoot -Recurse
    }
}
foreach ($file in @('packwiz.json')) {
    $sourceFile = Join-Path $source $file
    if (Test-Path -LiteralPath $sourceFile -PathType Leaf) {
        Copy-Item -LiteralPath $sourceFile -Destination (Join-Path $serverRoot $file)
    }
}

[IO.File]::WriteAllText((Join-Path $serverRoot 'eula.txt'), "eula=true`r`n", [Text.UTF8Encoding]::new($false))
[IO.File]::WriteAllText((Join-Path $serverRoot 'user_jvm_args.txt'), "-Xms1G`r`n-Xmx4G`r`n", [Text.UTF8Encoding]::new($false))
$properties = @(
    'allow-flight=true', 'difficulty=normal', 'gamemode=survival',
    'level-name=gui_forge_world', 'max-players=2',
    'motd=Disposable MilkyCraft Forge GUI integration', 'online-mode=false',
    'server-ip=127.0.0.1', "server-port=$TestPort", 'simulation-distance=4',
    'spawn-protection=0', 'view-distance=4', 'white-list=false'
) -join "`r`n"
[IO.File]::WriteAllText((Join-Path $serverRoot 'server.properties'), ($properties + "`r`n"), [Text.UTF8Encoding]::new($false))

$settingsPath = Join-Path $testRoot 'settings.json'
$settings = [ordered]@{
    packUrl = 'https://example.invalid/packwiz/pack.toml'
    backupDirectory = (Join-Path $testRoot 'backups')
    gracefulStopTimeoutSeconds = 240
    startupTimeoutSeconds = $StartupTimeoutSeconds
    startupDelaySeconds = 0
    scheduledRestartMinutes = 0
    scheduledRestartDelaySeconds = 1
    scheduledRestartWarningSeconds = @()
    restartBackoffSeconds = @(2,5,10)
    rapidFailureWindowMinutes = 10
    maxRapidFailures = 3
    stableRunResetMinutes = 20
    backupRetentionDaily = 2
    backupRetentionWeekly = 2
    taskNamePrefix = 'MilkyCraft Disposable Forge GUI Integration'
    launchExecutable = ''
    launchArguments = @()
}
[IO.File]::WriteAllText($settingsPath, (($settings | ConvertTo-Json -Depth 8) + "`r`n"), [Text.UTF8Encoding]::new($false))

$tools = Join-Path $root 'server-tools'
. (Join-Path $tools 'Common.ps1')
$statePath = Join-Path $serverRoot 'server-management\state.json'
$latestLog = Join-Path $serverRoot 'logs\latest.log'
$sourceJarCount = @(Get-ChildItem -LiteralPath (Join-Path $source 'mods') -File -Filter '*.jar').Count
$result = [ordered]@{
    testedAt = (Get-Date).ToString('o')
    testRoot = 'build/forge-server-gui-integration'
    testPort = $TestPort
    productionPort = 25565
    sourceJarCount = $sourceJarCount
    disposableJarCount = @(Get-ChildItem -LiteralPath (Join-Path $serverRoot 'mods') -File -Filter '*.jar').Count
}
$resolvedSettings = Get-ServerSettings -ServerRoot $serverRoot -SettingsPath $settingsPath
$headlessLaunchSpec = Get-LaunchSpec $serverRoot $resolvedSettings
$serverGuiLaunchSpec = Get-LaunchSpec $serverRoot $resolvedSettings -ServerGui
$noguiPattern = '(?i)(?:^|\s)nogui(?:\s|$)'
if ($headlessLaunchSpec.Arguments -notmatch $noguiPattern) {
    throw 'Default/headless Forge launch no longer contains the required nogui argument.'
}
if ($serverGuiLaunchSpec.Arguments -match $noguiPattern) {
    throw 'Explicit ServerGui Forge launch still contains the nogui argument.'
}
$result.headlessLaunchRetainsNogui = 'PASS'
$result.serverGuiLaunchOmitsNogui = 'PASS'
$recordedServerPid = 0
$recordedSupervisorPid = 0
$recordedServerFingerprint = $null
$recordedSupervisorFingerprint = $null
$recordedWindowHandle = 0

try {
    $startedAt = Get-Date
    & (Join-Path $tools 'Start-Server.ps1') -ServerRoot $serverRoot -SettingsPath $settingsPath `
        -StartupTimeoutSeconds $StartupTimeoutSeconds -ServerGui

    Wait-Until { Test-Path -LiteralPath $statePath -PathType Leaf } 10 'GUI supervisor did not write state.'
    $state = Get-Content -LiteralPath $statePath -Raw | ConvertFrom-Json
    $recordedServerPid = [int]$state.serverPid
    $recordedSupervisorPid = [int]$state.supervisorPid
    $recordedServerFingerprint = $state.serverProcessFingerprint
    $recordedSupervisorFingerprint = $state.supervisorProcessFingerprint
    if (-not $state.serverGui) { throw 'Supervisor state did not record ServerGui mode.' }
    $result.supervisorRecordedServerGui = 'PASS'

    $serverProcess = Get-CimInstance Win32_Process -Filter "ProcessId=$recordedServerPid" -ErrorAction Stop
    if ($serverProcess.Name -notmatch '^javaw?\.exe$' -or
        $serverProcess.CommandLine -notmatch '@libraries\\net\\minecraftforge\\forge\\1\.20\.1-47\.4\.10\\win_args\.txt') {
        throw "Supervisor did not own the direct Forge Java process: $($serverProcess.CommandLine)"
    }
    if ([int]$serverProcess.ParentProcessId -ne $recordedSupervisorPid) {
        throw 'Forge Java is not a direct child of the hidden supervisor.'
    }
    if ($serverProcess.CommandLine -match '(?i)(?:^|\s)nogui(?:\s|$)') {
        throw "Forge GUI launch still contains the nogui argument: $($serverProcess.CommandLine)"
    }
    $result.directForgeJavaOwnership = 'PASS'
    $result.noguiArgumentAbsent = 'PASS'

    Wait-Until {
        $window = Get-ProcessWindow $recordedServerPid
        $window -and $window.Handle -ne 0 -and $window.Title
    } 90 'Forge Java never exposed a visible top-level server GUI window.'
    $javaWindow = Get-ProcessWindow $recordedServerPid
    $recordedWindowHandle = [Int64]$javaWindow.Handle
    if ($javaWindow.Title -notmatch '(?i)minecraft.*server|server.*minecraft') {
        throw "Unexpected Forge Java GUI title: $($javaWindow.Title)"
    }
    $supervisorWindow = Get-ProcessWindow $recordedSupervisorPid
    if ($supervisorWindow -and $supervisorWindow.Handle -ne 0) {
        throw "Hidden supervisor unexpectedly owns a visible window: $($supervisorWindow.Title)"
    }
    $result.javaSwingWindow = 'PASS'
    $result.javaWindowTitle = $javaWindow.Title
    $result.hiddenSupervisorWindow = 'PASS'

    Wait-Until {
        (Test-Path -LiteralPath $latestLog -PathType Leaf) -and
            (Select-String -LiteralPath $latestLog -SimpleMatch 'Done (' -Quiet)
    } $StartupTimeoutSeconds 'Disposable GUI Forge server did not reach Done.'
    # latest.log is written directly by Forge. The supervisor observes the same
    # line on its polling interval, so allow that state update to follow Done.
    Wait-Until {
        $observedState = Get-Content -LiteralPath $statePath -Raw | ConvertFrom-Json
        $observedState.status -eq 'online'
    } 15 'Supervisor did not transition to online after Forge reached Done.'
    $result.serverReachedDone = $true
    $result.supervisorOnline = 'PASS'
    $result.startupSeconds = [Math]::Round(((Get-Date) - $startedAt).TotalSeconds, 3)

    & (Join-Path $tools 'Stop-Server.ps1') -ServerRoot $serverRoot -SettingsPath $settingsPath -TimeoutSeconds 285
    Wait-Until {
        -not (Get-Process -Id $recordedServerPid -ErrorAction SilentlyContinue) -and
            -not (Get-Process -Id $recordedSupervisorPid -ErrorAction SilentlyContinue)
    } 30 'Forge Java or its hidden supervisor remained alive after a graceful stop.'
    if (-not (Select-String -LiteralPath $latestLog -SimpleMatch 'ThreadedAnvilChunkStorage: All dimensions are saved' -Quiet)) {
        throw 'Disposable GUI Forge shutdown did not confirm all dimensions saved.'
    }
    if (Get-NetTCPConnection -LocalPort $TestPort -State Listen -ErrorAction SilentlyContinue) {
        throw 'Disposable Forge GUI port remained listening after shutdown.'
    }
    if ($recordedWindowHandle -ne 0 -and (Get-ProcessWindow $recordedServerPid)) {
        throw 'The Java server GUI remained after the Forge JVM exited.'
    }
    $finalState = Get-Content -LiteralPath $statePath -Raw | ConvertFrom-Json
    if ($finalState.status -ne 'stopped' -or $finalState.serverPid -or $finalState.supervisorPid -or
        $finalState.serverProcessFingerprint -or $finalState.supervisorProcessFingerprint -or
        $finalState.nextScheduledRestart) {
        throw 'Final GUI supervisor state retained an active process identity or restart time.'
    }
    $result.normalStopCommand = 'PASS'
    $result.allLoadedDimensionsSaved = $true
    $result.jvmExited = $true
    $result.supervisorExited = $true
    $result.javaWindowClosed = $true
    $result.testPortReleased = $true

    $productionAfter = Get-PortSnapshot 25565
    if (($productionBefore | ConvertTo-Json -Compress) -ne ($productionAfter | ConvertTo-Json -Compress)) {
        throw 'Production port 25565 listener state changed during the disposable Forge GUI test.'
    }
    $result.productionPortTouched = $false
    $result.liveServerWorldOrPrismTouched = $false
    $result.status = 'PASS'
} finally {
    if ($recordedServerPid -gt 0 -and (Get-Process -Id $recordedServerPid -ErrorAction SilentlyContinue)) {
        try {
            & (Join-Path $tools 'Stop-Server.ps1') -ServerRoot $serverRoot -SettingsPath $settingsPath -TimeoutSeconds 60
        } catch { }
    }
    try { Stop-DisposableProcess $recordedServerPid $recordedServerFingerprint } catch { }
    try { Stop-DisposableProcess $recordedSupervisorPid $recordedSupervisorFingerprint } catch { }
}

$auditPath = Join-Path $root 'audit\forge-server-gui-integration.json'
[IO.File]::WriteAllText($auditPath, (($result | ConvertTo-Json -Depth 8) + "`r`n"), [Text.UTF8Encoding]::new($false))
$result | ConvertTo-Json -Depth 8
