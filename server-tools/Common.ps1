Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Resolve-ServerRoot([string]$ServerRoot) {
    if ($ServerRoot) { return [IO.Path]::GetFullPath($ServerRoot) }
    $candidate = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
    if (Test-Path -LiteralPath (Join-Path $candidate 'server.properties')) { return $candidate }
    return [IO.Path]::GetFullPath((Join-Path ([Environment]::GetFolderPath('Desktop')) 'Minecraft Server'))
}

function Assert-ValidServerRoot([string]$ServerRoot) {
    $resolved = [IO.Path]::GetFullPath($ServerRoot)
    if (-not (Test-Path -LiteralPath (Join-Path $resolved 'server.properties') -PathType Leaf)) {
        throw "Not a dedicated-server root (server.properties missing): $resolved"
    }
    if (-not (Test-Path -LiteralPath (Join-Path $resolved 'libraries') -PathType Container)) {
        throw "Not a Forge server root (libraries directory missing): $resolved"
    }
    return $resolved
}

function Get-ServerPort([string]$ServerRoot) {
    $properties = Join-Path $ServerRoot 'server.properties'
    $match = Select-String -LiteralPath $properties -Pattern '^server-port=(\d+)$' | Select-Object -First 1
    if ($match) { return [int]$match.Matches[0].Groups[1].Value }
    return 25565
}

function Get-ServerActivity([string]$ServerRoot) {
    $port = Get-ServerPort $ServerRoot
    $listeners = @(Get-NetTCPConnection -LocalPort $port -State Listen -ErrorAction SilentlyContinue)
    $escaped = [regex]::Escape($ServerRoot)
    $supervisors = @(Get-CimInstance Win32_Process -Filter "Name='powershell.exe' OR Name='pwsh.exe'" -ErrorAction SilentlyContinue |
        Where-Object { $_.CommandLine -and $_.CommandLine -match $escaped -and $_.CommandLine -match 'server-supervisor\.ps1' })
    return [pscustomobject]@{
        Port = $port
        Listeners = $listeners
        Supervisors = $supervisors
        Running = ($listeners.Count -gt 0 -or $supervisors.Count -gt 0)
    }
}

function Assert-ServerStopped([string]$ServerRoot) {
    $activity = Get-ServerActivity $ServerRoot
    if ($activity.Running) {
        $listenerPids = @($activity.Listeners | Select-Object -ExpandProperty OwningProcess -Unique) -join ', '
        $supervisorPids = @($activity.Supervisors | Select-Object -ExpandProperty ProcessId -Unique) -join ', '
        throw "Server update/backup refused: server activity is present on port $($activity.Port) (listener PID(s): $listenerPids; supervisor PID(s): $supervisorPids). Stop it cleanly first."
    }
}

function Find-Java17([string]$JavaPath) {
    if ($JavaPath) {
        $resolved = [IO.Path]::GetFullPath($JavaPath)
        if (-not (Test-Path -LiteralPath $resolved -PathType Leaf)) { throw "Java executable not found: $resolved" }
        return $resolved
    }
    $roots = @(
        (Join-Path $env:LOCALAPPDATA 'Programs\Eclipse Adoptium'),
        (Join-Path $env:ProgramFiles 'Eclipse Adoptium'),
        (Join-Path $env:ProgramFiles 'Java')
    )
    foreach ($root in $roots) {
        if (-not (Test-Path -LiteralPath $root)) { continue }
        foreach ($jdk in Get-ChildItem -LiteralPath $root -Directory | Sort-Object Name -Descending) {
            if ($jdk.Name -notmatch '(jdk|jre)-?17|17\.') { continue }
            $candidate = Join-Path $jdk.FullName 'bin\java.exe'
            if (Test-Path -LiteralPath $candidate) { return $candidate }
        }
    }
    throw 'Java 17 was not found. Install Temurin 17 x64 or pass -JavaPath.'
}

function Get-LevelName([string]$ServerRoot) {
    $properties = Join-Path $ServerRoot 'server.properties'
    $match = Select-String -LiteralPath $properties -Pattern '^level-name=(.+)$' | Select-Object -First 1
    if ($match) { return $match.Matches[0].Groups[1].Value.Trim() }
    return 'world'
}

function Get-BackupItems([string]$ServerRoot) {
    $levelName = Get-LevelName $ServerRoot
    return @(
        $levelName,
        'mods',
        'config',
        'defaultconfigs',
        'kubejs',
        'scripts',
        'resourcepacks',
        'moonlight-global-datapacks',
        '.packwiz-installer',
        '.packwiz-installer-cache',
        'packwiz.json',
        'server.properties',
        'eula.txt',
        'user_jvm_args.txt',
        'ops.json',
        'whitelist.json',
        'banned-ips.json',
        'banned-players.json',
        'run.bat',
        'server-supervisor.ps1'
    )
}

function Get-ManagedUpdateItems {
    return @('mods', 'config', 'defaultconfigs', 'kubejs', 'scripts', 'resourcepacks', 'moonlight-global-datapacks', '.packwiz-installer', '.packwiz-installer-cache', 'packwiz.json')
}

function Assert-SafeChildPath([string]$Root, [string]$Path) {
    $rootResolved = [IO.Path]::GetFullPath($Root).TrimEnd('\') + '\'
    $pathResolved = [IO.Path]::GetFullPath($Path)
    if (-not $pathResolved.StartsWith($rootResolved, [StringComparison]::OrdinalIgnoreCase)) {
        throw "Unsafe path outside server root: $pathResolved"
    }
}

function Restore-ManagedFiles([string]$ServerRoot, [string]$BackupPath) {
    $filesRoot = Join-Path $BackupPath 'files'
    if (-not (Test-Path -LiteralPath (Join-Path $BackupPath 'backup-manifest.json'))) {
        throw "Backup manifest is missing: $BackupPath"
    }
    foreach ($relative in Get-ManagedUpdateItems) {
        $target = Join-Path $ServerRoot $relative
        $source = Join-Path $filesRoot $relative
        Assert-SafeChildPath $ServerRoot $target
        if (Test-Path -LiteralPath $target) { Remove-Item -LiteralPath $target -Recurse -Force }
        if (Test-Path -LiteralPath $source) { Copy-Item -LiteralPath $source -Destination $target -Recurse }
    }
}

function Get-ServerSettings([string]$PackUrl) {
    $settingsPath = Join-Path $PSScriptRoot 'server-settings.json'
    $settings = if (Test-Path -LiteralPath $settingsPath) { Get-Content -LiteralPath $settingsPath -Raw | ConvertFrom-Json } else { $null }
    if (-not $PackUrl -and $settings) { $PackUrl = [string]$settings.packUrl }
    if (-not $PackUrl) { throw 'No Packwiz pack URL was configured.' }
    return [pscustomobject]@{ PackUrl=$PackUrl; Settings=$settings }
}
