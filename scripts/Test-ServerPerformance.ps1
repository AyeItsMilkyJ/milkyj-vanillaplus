[CmdletBinding()]
param(
    [string]$ProjectRoot = (Split-Path -Parent $PSScriptRoot),
    [string]$InstalledServerSource,
    [string]$JavaPath,
    [ValidateRange(1, 65535)][int]$TestPort = 25579,
    [ValidateRange(10, 180)][int]$IdleSeconds = 30,
    [ValidateRange(30, 600)][int]$ChunkyTimeoutSeconds = 300,
    [ValidateRange(15, 180)][int]$ExplorationSeconds = 45,
    [ValidateRange(15, 180)][int]$LoadedBaseSeconds = 45
)

$ErrorActionPreference = 'Stop'
$project = [IO.Path]::GetFullPath($ProjectRoot)
if (-not $InstalledServerSource) { $InstalledServerSource = Join-Path $project 'build\end-to-end\server' }
$source = [IO.Path]::GetFullPath($InstalledServerSource)
$benchmarkRoot = Join-Path $project 'build\performance-audit'
$expectedBenchmarkRoot = [IO.Path]::GetFullPath((Join-Path $project 'build\performance-audit'))
$outputPath = Join-Path $project 'audit\performance-benchmark.json'

if ($TestPort -eq 25565) { throw 'Production port 25565 is forbidden for disposable benchmarking.' }
if ([IO.Path]::GetFullPath($benchmarkRoot) -ne $expectedBenchmarkRoot) { throw "Unsafe benchmark path: $benchmarkRoot" }
if (-not $source.StartsWith(($project.TrimEnd('\') + '\'), [StringComparison]::OrdinalIgnoreCase)) {
    throw "The installed source must be a disposable project path: $source"
}
if (-not (Test-Path -LiteralPath (Join-Path $source 'mods') -PathType Container)) {
    throw "Disposable installed server source is missing: $source"
}
if (@(Get-ChildItem -LiteralPath (Join-Path $source 'mods') -File -Filter '*.jar').Count -ne 203) {
    throw 'The disposable installed server source must contain exactly 203 mod JARs.'
}
$occupied = Get-NetTCPConnection -State Listen -LocalPort $TestPort -ErrorAction SilentlyContinue
if ($occupied) { throw "Disposable benchmark port $TestPort is already in use." }

if (-not $JavaPath) {
    $javaCommand = Get-Command java -ErrorAction SilentlyContinue
    if (-not $javaCommand) { throw 'Java 17 was not found.' }
    $JavaPath = $javaCommand.Source
}
$JavaPath = [IO.Path]::GetFullPath($JavaPath)
$savedErrorPreference = $ErrorActionPreference
$ErrorActionPreference = 'Continue'
$javaVersion = (& $JavaPath -version 2>&1) -join "`n"
$ErrorActionPreference = $savedErrorPreference
if ($javaVersion -notmatch 'version "17\.') { throw "Java 17 is required; found: $javaVersion" }
$jstat = Join-Path (Split-Path -Parent $JavaPath) 'jstat.exe'
if (-not (Test-Path -LiteralPath $jstat -PathType Leaf)) { $jstat = $null }

if (Test-Path -LiteralPath $benchmarkRoot) { Remove-Item -LiteralPath $benchmarkRoot -Recurse -Force }
New-Item -ItemType Directory -Path $benchmarkRoot -Force | Out-Null
foreach ($directory in @('mods', 'config', 'defaultconfigs', 'libraries', 'moonlight-global-datapacks', 'patchouli_books', 'mod_data')) {
    $from = Join-Path $source $directory
    if (Test-Path -LiteralPath $from) { Copy-Item -LiteralPath $from -Destination (Join-Path $benchmarkRoot $directory) -Recurse }
}
if (-not (Test-Path -LiteralPath (Join-Path $benchmarkRoot 'libraries\net\minecraftforge\forge\1.20.1-47.4.10\win_args.txt') -PathType Leaf)) {
    throw 'Forge 47.4.10 Windows launch arguments are missing from the disposable source.'
}

$utf8 = [Text.UTF8Encoding]::new($false)
[IO.File]::WriteAllText((Join-Path $benchmarkRoot 'eula.txt'), "eula=true`r`n", $utf8)
[IO.File]::WriteAllText((Join-Path $benchmarkRoot 'user_jvm_args.txt'), (@(
    '-Xmx8G',
    '-Xms2G',
    '-XX:+UseG1GC',
    '-XX:+ParallelRefProcEnabled',
    '-XX:MaxGCPauseMillis=150',
    '-XX:+DisableExplicitGC'
) -join "`r`n") + "`r`n", $utf8)
[IO.File]::WriteAllText((Join-Path $benchmarkRoot 'server.properties'), (@(
    'allow-flight=true',
    'difficulty=hard',
    'enable-command-block=false',
    'enable-jmx-monitoring=false',
    'entity-broadcast-range-percentage=80',
    'gamemode=survival',
    'generate-structures=true',
    'level-name=benchmark_world',
    'max-players=10',
    'max-tick-time=60000',
    'motd=MilkyJ disposable benchmark',
    'online-mode=false',
    "server-port=$TestPort",
    'simulation-distance=6',
    'spawn-protection=0',
    'sync-chunk-writes=false',
    'view-distance=12'
) -join "`r`n") + "`r`n", $utf8)

function Send-Command([Diagnostics.Process]$Process, [string]$Command) {
    if ($Process.HasExited) { throw "Server exited before command: $Command" }
    $Process.StandardInput.WriteLine($Command)
    $Process.StandardInput.Flush()
}

function Get-LogText([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return '' }
    for ($attempt = 0; $attempt -lt 5; $attempt++) {
        try {
            $stream = [IO.FileStream]::new($Path, [IO.FileMode]::Open, [IO.FileAccess]::Read, ([IO.FileShare]::ReadWrite -bor [IO.FileShare]::Delete))
            try {
                $reader = [IO.StreamReader]::new($stream, [Text.Encoding]::UTF8, $true, 4096, $false)
                try { return $reader.ReadToEnd() } finally { $reader.Dispose() }
            } finally { $stream.Dispose() }
        } catch [IO.IOException] {
            if ($attempt -eq 4) { throw }
            Start-Sleep -Milliseconds 100
        }
    }
}

function Get-NewLogText([string]$Path, [int]$StartLength) {
    $text = Get-LogText $Path
    if ($text.Length -le $StartLength) { return '' }
    return $text.Substring($StartLength)
}

function Get-JstatSample([int]$ProcessId) {
    if (-not $script:jstat) { return $null }
    try {
        $lines = @(& $script:jstat -gc $ProcessId 1 1 2>$null | Where-Object { $_.Trim() })
        if ($lines.Count -lt 2) { return $null }
        $headers = @($lines[-2].Trim() -split '\s+')
        $values = @($lines[-1].Trim() -split '\s+')
        if ($headers.Count -ne $values.Count) { return $null }
        $map = @{}
        for ($i = 0; $i -lt $headers.Count; $i++) { $map[$headers[$i]] = [double]::Parse($values[$i], [Globalization.CultureInfo]::InvariantCulture) }
        $usedKb = $map.S0U + $map.S1U + $map.EU + $map.OU
        $committedKb = $map.S0C + $map.S1C + $map.EC + $map.OC
        return [ordered]@{
            heapUsedMiB = [math]::Round($usedKb / 1024, 1)
            heapCommittedMiB = [math]::Round($committedKb / 1024, 1)
            youngCollections = [int]$map.YGC
            youngGcSeconds = [math]::Round($map.YGCT, 3)
            fullCollections = [int]$map.FGC
            fullGcSeconds = [math]::Round($map.FGCT, 3)
            concurrentCollections = if ($map.ContainsKey('CGC')) { [int]$map.CGC } else { $null }
            concurrentGcSeconds = if ($map.ContainsKey('CGCT')) { [math]::Round($map.CGCT, 3) } else { $null }
            totalGcSeconds = [math]::Round($map.GCT, 3)
        }
    } catch { return $null }
}

function Get-ResourceSample([Diagnostics.Process]$Process) {
    $Process.Refresh()
    return [ordered]@{
        at = (Get-Date).ToString('o')
        workingSetMiB = [math]::Round($Process.WorkingSet64 / 1MB, 1)
        privateMiB = [math]::Round($Process.PrivateMemorySize64 / 1MB, 1)
        cpuSeconds = [math]::Round($Process.TotalProcessorTime.TotalSeconds, 3)
        gc = Get-JstatSample $Process.Id
    }
}

function Measure-Resources([Diagnostics.Process]$Process, [int]$Seconds, [string]$LogPath, [string]$UntilPattern = '') {
    $samples = @()
    $started = Get-Date
    $deadline = $started.AddSeconds($Seconds)
    $matched = $false
    do {
        if ($Process.HasExited) { throw 'Server exited during a benchmark scenario.' }
        $samples += Get-ResourceSample $Process
        if ($UntilPattern -and (Get-LogText $LogPath) -match $UntilPattern) { $matched = $true; break }
        Start-Sleep -Seconds 5
    } while ((Get-Date) -lt $deadline)
    if (-not $matched -and $UntilPattern -and (Get-LogText $LogPath) -match $UntilPattern) { $matched = $true }
    $working = @($samples | ForEach-Object workingSetMiB)
    $private = @($samples | ForEach-Object privateMiB)
    $heap = @($samples | ForEach-Object { if ($_.gc) { $_.gc.heapUsedMiB } })
    $firstGc = @($samples | Where-Object gc | Select-Object -First 1).gc
    $lastGc = @($samples | Where-Object gc | Select-Object -Last 1).gc
    return [ordered]@{
        durationSeconds = [math]::Round(((Get-Date) - $started).TotalSeconds, 2)
        completionPatternMatched = if ($UntilPattern) { $matched } else { $null }
        sampleCount = $samples.Count
        workingSetMiB = [ordered]@{ average = if ($working) { [math]::Round(($working | Measure-Object -Average).Average, 1) } else { $null }; maximum = if ($working) { ($working | Measure-Object -Maximum).Maximum } else { $null } }
        privateMiB = [ordered]@{ average = if ($private) { [math]::Round(($private | Measure-Object -Average).Average, 1) } else { $null }; maximum = if ($private) { ($private | Measure-Object -Maximum).Maximum } else { $null } }
        heapUsedMiB = [ordered]@{ average = if ($heap) { [math]::Round(($heap | Measure-Object -Average).Average, 1) } else { $null }; maximum = if ($heap) { ($heap | Measure-Object -Maximum).Maximum } else { $null } }
        gcDelta = if ($firstGc -and $lastGc) { [ordered]@{
            youngCollections = $lastGc.youngCollections - $firstGc.youngCollections
            fullCollections = $lastGc.fullCollections - $firstGc.fullCollections
            concurrentCollections = if ($null -ne $lastGc.concurrentCollections) { $lastGc.concurrentCollections - $firstGc.concurrentCollections } else { $null }
            totalGcSeconds = [math]::Round($lastGc.totalGcSeconds - $firstGc.totalGcSeconds, 3)
        } } else { $null }
        samples = $samples
    }
}

function Get-TickSnapshot([Diagnostics.Process]$Process, [string]$LogPath) {
    $before = (Get-LogText $LogPath).Length
    Send-Command $Process 'forge tps'
    Send-Command $Process 'forge entity list'
    Start-Sleep -Seconds 3
    $delta = Get-NewLogText $LogPath $before
    $tickMatches = @([regex]::Matches($delta, '(?i)([^\r\n]*?):\s*Mean tick time:\s*([0-9.]+)\s*ms\.\s*Mean TPS:\s*([0-9.]+)'))
    $ticks = @($tickMatches | ForEach-Object { [ordered]@{
        scope = $_.Groups[1].Value.Trim()
        meanTickMilliseconds = [double]::Parse($_.Groups[2].Value, [Globalization.CultureInfo]::InvariantCulture)
        meanTps = [double]::Parse($_.Groups[3].Value, [Globalization.CultureInfo]::InvariantCulture)
    } })
    $overall = @($ticks | Where-Object { $_.scope -match 'Overall' } | Select-Object -Last 1)
    $entityLines = @($delta -split "`r?`n" | Where-Object { $_ -match '(?i)entities|entity list|total:' } | Select-Object -Last 30)
    $entityTotalMatch = [regex]::Matches($delta, '(?m): Total: (\d+)') | Select-Object -Last 1
    return [ordered]@{
        overallMeanTickMilliseconds = if ($overall) { $overall.meanTickMilliseconds } else { $null }
        overallMeanTps = if ($overall) { $overall.meanTps } else { $null }
        dimensionTicks = $ticks
        entityCommandOutput = $entityLines
        totalEntityCount = if ($entityTotalMatch) { [int]$entityTotalMatch.Groups[1].Value } else { $null }
        loadedChunkCount = $null
        loadedChunkCountNote = 'Forge 1.20.1 exposes tick timing but no reliable loaded-chunk total through the available console commands.'
    }
}

$startInfo = [Diagnostics.ProcessStartInfo]::new()
$startInfo.FileName = $JavaPath
$startInfo.WorkingDirectory = $benchmarkRoot
$startInfo.Arguments = '@user_jvm_args.txt @libraries/net/minecraftforge/forge/1.20.1-47.4.10/win_args.txt nogui'
$startInfo.UseShellExecute = $false
$startInfo.RedirectStandardInput = $true
$startInfo.RedirectStandardOutput = $true
$startInfo.RedirectStandardError = $true
$startInfo.CreateNoWindow = $true
$process = [Diagnostics.Process]::new()
$process.StartInfo = $startInfo
$stdoutTask = $null
$stderrTask = $null
$latestLog = Join-Path $benchmarkRoot 'logs\latest.log'
$serverExitedNormally = $false

try {
    $startupWatch = [Diagnostics.Stopwatch]::StartNew()
    if (-not $process.Start()) { throw 'Disposable benchmark JVM did not start.' }
    $stdoutTask = $process.StandardOutput.ReadToEndAsync()
    $stderrTask = $process.StandardError.ReadToEndAsync()
    $deadline = (Get-Date).AddMinutes(8)
    $done = $false
    do {
        Start-Sleep -Seconds 2
        if (Test-Path -LiteralPath $latestLog) { $done = [bool](Select-String -LiteralPath $latestLog -SimpleMatch 'Done (' -Quiet) }
        if ($process.HasExited -and -not $done) { break }
    } while (-not $done -and (Get-Date) -lt $deadline)
    $startupWatch.Stop()
    if (-not $done) { throw 'Disposable benchmark server did not reach Done.' }

    $idle = Measure-Resources $process $IdleSeconds $latestLog
    $idle.tick = Get-TickSnapshot $process $latestLog

    $chunkyStart = (Get-LogText $latestLog).Length
    Send-Command $process 'chunky world minecraft:overworld'
    Send-Command $process 'chunky center 16384 16384'
    Send-Command $process 'chunky radius 128'
    Send-Command $process 'chunky start'
    $chunkGeneration = Measure-Resources $process $ChunkyTimeoutSeconds $latestLog 'Task finished for minecraft:overworld'
    $chunkGeneration.tick = Get-TickSnapshot $process $latestLog
    $chunkGeneration.commandOutput = @((Get-NewLogText $latestLog $chunkyStart) -split "`r?`n" | Where-Object { $_ -match 'Chunky|Task (started|finished)|Radius changed|World changed' } | Select-Object -Last 30)

    $explorationStart = (Get-LogText $latestLog).Length
    foreach ($coordinate in @(
        @(4096, 4096), @(-4096, 4096), @(4096, -4096), @(-4096, -4096),
        @(8192, 0), @(-8192, 0), @(0, 8192), @(0, -8192)
    )) {
        $x = $coordinate[0]; $z = $coordinate[1]
        Send-Command $process "execute in minecraft:overworld run forceload add $x $z"
        Start-Sleep -Seconds 5
    }
    $exploration = Measure-Resources $process $ExplorationSeconds $latestLog
    $exploration.tick = Get-TickSnapshot $process $latestLog
    $exploration.forceloadCommandOutput = @((Get-NewLogText $latestLog $explorationStart) -split "`r?`n" | Where-Object { $_ -match '(?i)force.loaded|forceload|marked chunk' } | Select-Object -Last 30)

    Send-Command $process 'execute in minecraft:overworld run forceload remove all'
    Send-Command $process 'execute in minecraft:overworld run forceload add -64 -64 127 127'
    for ($i = 0; $i -lt 24; $i++) {
        $x = (($i % 8) * 8) - 28; $z = ([math]::Floor($i / 8) * 8) - 8
        Send-Command $process "execute in minecraft:overworld run summon minecraft:villager $x 120 $z {Tags:[`"benchmark`"],PersistenceRequired:1b,Invulnerable:1b}"
    }
    for ($i = 0; $i -lt 32; $i++) {
        $x = (($i % 8) * 8) - 28; $z = ([math]::Floor($i / 8) * 8) + 16
        Send-Command $process "execute in minecraft:overworld run summon minecraft:cow $x 120 $z {Tags:[`"benchmark`"],PersistenceRequired:1b,Invulnerable:1b}"
    }
    for ($i = 0; $i -lt 16; $i++) {
        $x = (($i % 8) * 8) - 28; $z = ([math]::Floor($i / 8) * 8) + 56
        Send-Command $process "execute in minecraft:overworld run summon minecraft:bee $x 120 $z {Tags:[`"benchmark`"],PersistenceRequired:1b,Invulnerable:1b}"
    }
    Start-Sleep -Seconds 10
    $loadedBase = Measure-Resources $process $LoadedBaseSeconds $latestLog
    $loadedBase.tick = Get-TickSnapshot $process $latestLog
    $loadedBase.syntheticEntitiesRequested = [ordered]@{ villagers = 24; cows = 32; bees = 16; total = 72 }
    $loadedBase.syntheticLoadedArea = '12x12 chunks around spawn (forceload -64,-64 through 127,127)'

    $saveLogStart = (Get-LogText $latestLog).Length
    $saveWatch = [Diagnostics.Stopwatch]::StartNew()
    Send-Command $process 'save-all flush'
    $saveDeadline = (Get-Date).AddMinutes(3)
    $explicitSaveCompleted = $false
    do {
        Start-Sleep -Milliseconds 500
        $saveDelta = Get-NewLogText $latestLog $saveLogStart
        $explicitSaveCompleted = $saveDelta -match '(?i)Saved the game|All dimensions are saved'
        if ($process.HasExited) { break }
    } while (-not $explicitSaveCompleted -and (Get-Date) -lt $saveDeadline)
    $saveWatch.Stop()

    $shutdownWatch = [Diagnostics.Stopwatch]::StartNew()
    Send-Command $process 'stop'
    $serverExitedNormally = $process.WaitForExit(300000)
    $shutdownWatch.Stop()
    if (-not $serverExitedNormally) { throw 'Disposable benchmark JVM did not exit within five minutes after stop.' }
    if ($process.ExitCode -ne 0) { throw "Disposable benchmark JVM exited with code $($process.ExitCode)." }

    $finalLog = Get-LogText $latestLog
    $result = [ordered]@{
        schemaVersion = 1
        measuredAt = (Get-Date).ToString('o')
        status = 'PASS'
        disposableRoot = 'build/performance-audit'
        productionPortTouched = $false
        testPort = $TestPort
        minecraft = '1.20.1'
        forge = '47.4.10'
        serverJarCount = 203
        java = [ordered]@{ executable = 'java.exe (absolute host path intentionally omitted)'; versionOutput = $javaVersion }
        jvmArguments = @('-Xmx8G', '-Xms2G', '-XX:+UseG1GC', '-XX:+ParallelRefProcEnabled', '-XX:MaxGCPauseMillis=150', '-XX:+DisableExplicitGC')
        serverSettings = [ordered]@{ viewDistance = 12; simulationDistance = 6; entityBroadcastRangePercentage = 80; syncChunkWrites = $false }
        startupSeconds = [math]::Round($startupWatch.Elapsed.TotalSeconds, 2)
        scenarios = [ordered]@{ cleanIdle = $idle; controlledChunkGeneration = $chunkGeneration; controlledExplorationWorldgen = $exploration; simulatedLoadedBase = $loadedBase }
        save = [ordered]@{ explicitSaveCompletionObserved = $explicitSaveCompleted; durationSeconds = if ($explicitSaveCompleted) { [math]::Round($saveWatch.Elapsed.TotalSeconds, 2) } else { $null }; note = if ($explicitSaveCompleted) { 'Measured from save-all flush command until a completion marker in latest.log.' } else { 'No explicit completion marker was exposed in latest.log; stop-time saving was still verified.' } }
        shutdownSeconds = [math]::Round($shutdownWatch.Elapsed.TotalSeconds, 2)
        allLoadedDimensionsSaved = $finalLog.Contains('ThreadedAnvilChunkStorage: All dimensions are saved')
        savedDimensions = @([regex]::Matches($finalLog, "Saving chunks for level '[^']+'/(\S+)") | ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique)
        jvmExited = $serverExitedNormally
        jvmExitCode = $process.ExitCode
        distantHorizonsShutdownCompleted = ($finalLog.Contains('Closed DhWorld of type [SERVER_ONLY]') -and $finalLog.Contains('Closing all [7] database connections'))
        limitations = @(
            'The benchmark uses a newly generated disposable world, not a snapshot of the production world.',
            'The simulated base uses forced chunks and 72 vanilla entities; it does not fabricate Create contraption or train results.',
            'No real players or client Distant Horizons LOD requests were connected.',
            'Loaded chunk count was unavailable from reliable built-in Forge console output.'
        )
    }
    [IO.File]::WriteAllText($outputPath, (($result | ConvertTo-Json -Depth 12) + "`n"), $utf8)
    [IO.File]::WriteAllText((Join-Path $benchmarkRoot 'server.stdout.log'), $stdoutTask.Result, $utf8)
    [IO.File]::WriteAllText((Join-Path $benchmarkRoot 'server.stderr.log'), $stderrTask.Result, $utf8)
    Write-Host "Disposable performance benchmark passed. Report: $outputPath"
} finally {
    if ($process -and -not $process.HasExited) {
        try { Send-Command $process 'stop' } catch {}
        if (-not $process.WaitForExit(120000)) { $process.Kill(); $process.WaitForExit() }
    }
    if ($stdoutTask -and $stdoutTask.IsCompleted) { [IO.File]::WriteAllText((Join-Path $benchmarkRoot 'server.stdout.log'), $stdoutTask.Result, $utf8) }
    if ($stderrTask -and $stderrTask.IsCompleted) { [IO.File]::WriteAllText((Join-Path $benchmarkRoot 'server.stderr.log'), $stderrTask.Result, $utf8) }
}
