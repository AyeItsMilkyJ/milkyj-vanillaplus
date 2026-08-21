[CmdletBinding()]
param(
    [string]$ProjectRoot,
    [string]$SourceServerRoot,
    [int]$TestPort = 25578
)

$ErrorActionPreference = 'Stop'
if (-not $ProjectRoot) { $ProjectRoot = Split-Path -Parent $PSScriptRoot }
if ($TestPort -eq 25565) { throw 'Forge supervisor integration refuses production port 25565.' }
$root = [IO.Path]::GetFullPath($ProjectRoot)
$sourceDescription = 'clean disposable RC installation'
if ($SourceServerRoot) {
    $source = [IO.Path]::GetFullPath($SourceServerRoot)
    $sourceDescription = 'read-only current server payload clone (world and private server files excluded)'
} else {
    $source = Join-Path $root 'build\rc-lan-test\server'
}
$testRoot = [IO.Path]::GetFullPath((Join-Path $root 'build\forge-supervisor-integration'))
$expected = [IO.Path]::GetFullPath((Join-Path $root 'build\forge-supervisor-integration'))
if (-not $testRoot.Equals($expected, [StringComparison]::OrdinalIgnoreCase)) { throw 'Unsafe Forge supervisor test path.' }
if (-not (Test-Path -LiteralPath (Join-Path $source 'mods') -PathType Container)) { throw 'Clean disposable RC server source is unavailable.' }
if ($SourceServerRoot) {
    $sourceProperties = Join-Path $source 'server.properties'
    $sourcePortMatch = Select-String -LiteralPath $sourceProperties -Pattern '^server-port=(\d+)$' | Select-Object -First 1
    $sourcePort = if ($sourcePortMatch) { [int]$sourcePortMatch.Matches[0].Groups[1].Value } else { 25565 }
    $sourceJava = @(Get-CimInstance Win32_Process -Filter "Name='java.exe' OR Name='javaw.exe'" -ErrorAction SilentlyContinue |
        Where-Object { $_.CommandLine -and $_.CommandLine -match [regex]::Escape($source) })
    if ($sourceJava.Count -gt 0 -or (Get-NetTCPConnection -LocalPort $sourcePort -State Listen -ErrorAction SilentlyContinue)) {
        throw 'Current server payload source is active; read-only cloning was refused until it is fully stopped.'
    }
}
if (Get-NetTCPConnection -LocalPort $TestPort -State Listen -ErrorAction SilentlyContinue) { throw "Test port $TestPort is already listening." }
$productionBefore = @(Get-NetTCPConnection -LocalPort 25565 -State Listen -ErrorAction SilentlyContinue | Select-Object OwningProcess,LocalAddress,LocalPort)
if (Test-Path -LiteralPath $testRoot) { Remove-Item -LiteralPath $testRoot -Recurse -Force }
$serverRoot = Join-Path $testRoot 'server'
New-Item -ItemType Directory -Path $serverRoot -Force | Out-Null

foreach ($directory in @('mods','config','defaultconfigs','libraries','moonlight-global-datapacks','patchouli_books')) {
    $sourceDirectory = Join-Path $source $directory
    if (Test-Path -LiteralPath $sourceDirectory) { Copy-Item -LiteralPath $sourceDirectory -Destination $serverRoot -Recurse }
}
foreach ($file in @('packwiz.json')) {
    if (Test-Path -LiteralPath (Join-Path $source $file)) { Copy-Item -LiteralPath (Join-Path $source $file) -Destination (Join-Path $serverRoot $file) }
}
[IO.File]::WriteAllText((Join-Path $serverRoot 'eula.txt'), "eula=true`r`n", [Text.UTF8Encoding]::new($false))
[IO.File]::WriteAllText((Join-Path $serverRoot 'user_jvm_args.txt'), "-Xms1G`r`n-Xmx4G`r`n", [Text.UTF8Encoding]::new($false))
$properties = @(
    'allow-flight=true', 'difficulty=normal', 'gamemode=survival', 'level-name=infra_forge_world',
    'max-players=2', 'motd=Disposable 24-7 supervisor integration', 'online-mode=false',
    'server-ip=127.0.0.1', "server-port=$TestPort", 'simulation-distance=4', 'spawn-protection=0',
    'view-distance=4', 'white-list=false'
) -join "`r`n"
[IO.File]::WriteAllText((Join-Path $serverRoot 'server.properties'), ($properties + "`r`n"), [Text.UTF8Encoding]::new($false))
$settingsPath = Join-Path $testRoot 'settings.json'
$settings = [ordered]@{
    packUrl='https://example.invalid/packwiz/pack.toml'; backupDirectory=(Join-Path $testRoot 'backups')
    gracefulStopTimeoutSeconds=240; startupTimeoutSeconds=360; startupDelaySeconds=0
    scheduledRestartMinutes=0; scheduledRestartDelaySeconds=1; scheduledRestartWarningSeconds=@()
    restartBackoffSeconds=@(2,5,10); rapidFailureWindowMinutes=10; maxRapidFailures=3; stableRunResetMinutes=20
    backupRetentionDaily=2; backupRetentionWeekly=2; taskNamePrefix='MilkyJ Disposable Forge Integration'
    launchExecutable=''; launchArguments=@()
}
[IO.File]::WriteAllText($settingsPath, (($settings | ConvertTo-Json -Depth 6) + "`r`n"), [Text.UTF8Encoding]::new($false))
$tools = Join-Path $root 'server-tools'
$result = [ordered]@{
    testedAt=(Get-Date).ToString('o'); testPort=$TestPort; productionPort=25565; source=$sourceDescription
    serverJarCount=@(Get-ChildItem -LiteralPath (Join-Path $serverRoot 'mods') -File -Filter '*.jar').Count
}

try {
    $startedAt = Get-Date
    & (Join-Path $tools 'Start-Server.ps1') -ServerRoot $serverRoot -SettingsPath $settingsPath -StartupTimeoutSeconds 360
    $latest = Join-Path $serverRoot 'logs\latest.log'
    $deadline = (Get-Date).AddMinutes(6)
    do {
        $done = (Test-Path -LiteralPath $latest) -and [bool](Select-String -LiteralPath $latest -SimpleMatch 'Done (' -Quiet)
        if (-not $done) { Start-Sleep -Seconds 2 }
    } while (-not $done -and (Get-Date) -lt $deadline)
    if (-not $done) { throw 'Disposable Forge server did not reach Done.' }
    $state = Get-Content -LiteralPath (Join-Path $serverRoot 'server-management\state.json') -Raw | ConvertFrom-Json
    $serverProcess = Get-CimInstance Win32_Process -Filter "ProcessId=$([int]$state.serverPid)" -ErrorAction Stop
    if ($serverProcess.Name -notmatch '^javaw?\.exe$' -or $serverProcess.CommandLine -notmatch '@libraries\\net\\minecraftforge\\forge\\1\.20\.1-47\.4\.10\\win_args\.txt') {
        throw "Supervisor did not own the direct Forge Java process: $($serverProcess.CommandLine)"
    }
    $result.directJavaOwnership = 'PASS'
    $result.serverReachedDone = $true
    $result.startupSeconds = [Math]::Round(((Get-Date) - $startedAt).TotalSeconds, 3)
    & (Join-Path $tools 'Stop-Server.ps1') -ServerRoot $serverRoot -SettingsPath $settingsPath -TimeoutSeconds 285
    $saved = [bool](Select-String -LiteralPath $latest -SimpleMatch 'ThreadedAnvilChunkStorage: All dimensions are saved' -Quiet)
    if (-not $saved) { throw 'Disposable Forge shutdown did not confirm all dimensions saved.' }
    if (Get-Process -Id $state.serverPid -ErrorAction SilentlyContinue) { throw 'Recorded Forge JVM remained alive after graceful supervisor stop.' }
    if (Get-NetTCPConnection -LocalPort $TestPort -State Listen -ErrorAction SilentlyContinue) { throw 'Disposable Forge port remained listening.' }
    $result.normalStopCommand = 'PASS'
    $result.allLoadedDimensionsSaved = $true
    $result.jvmExited = $true
    $result.testPortReleased = $true
    $productionAfter = @(Get-NetTCPConnection -LocalPort 25565 -State Listen -ErrorAction SilentlyContinue | Select-Object OwningProcess,LocalAddress,LocalPort)
    if (($productionBefore | ConvertTo-Json -Compress) -ne ($productionAfter | ConvertTo-Json -Compress)) { throw 'Production port listener state changed.' }
    $result.productionPortTouched = $false
    $result.liveServerWorldOrPrismTouched = $false
    $result.status = 'PASS'
} finally {
    $statePath = Join-Path $serverRoot 'server-management\state.json'
    if (Test-Path -LiteralPath $statePath) {
        $state = Get-Content -LiteralPath $statePath -Raw | ConvertFrom-Json
        foreach ($pidValue in @($state.serverPid,$state.supervisorPid)) {
            if (-not $pidValue) { continue }
            $candidate = Get-CimInstance Win32_Process -Filter "ProcessId=$([int]$pidValue)" -ErrorAction SilentlyContinue
            if ($candidate -and $candidate.CommandLine -match 'forge-supervisor-integration') { Stop-Process -Id $pidValue -Force }
        }
    }
}

[IO.File]::WriteAllText((Join-Path $root 'audit\forge-supervisor-integration.json'), (($result | ConvertTo-Json -Depth 6) + "`r`n"), [Text.UTF8Encoding]::new($false))
$result | ConvertTo-Json -Depth 6
