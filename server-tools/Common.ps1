Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$script:ServerToolsRoot = $PSScriptRoot

function Resolve-ServerRoot([string]$ServerRoot) {
    if ($ServerRoot) { return [IO.Path]::GetFullPath($ServerRoot) }
    $candidate = [IO.Path]::GetFullPath((Join-Path $script:ServerToolsRoot '..'))
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

function Get-ManagementRoot([string]$ServerRoot) {
    return Join-Path $ServerRoot 'server-management'
}

function Get-StatePath([string]$ServerRoot) {
    return Join-Path (Get-ManagementRoot $ServerRoot) 'state.json'
}

function Write-JsonAtomic([string]$Path, $Value) {
    $parent = Split-Path -Parent $Path
    New-Item -ItemType Directory -Path $parent -Force | Out-Null
    $temporary = "$Path.new"
    [IO.File]::WriteAllText($temporary, (($Value | ConvertTo-Json -Depth 12) + "`r`n"), [Text.UTF8Encoding]::new($false))
    Move-Item -LiteralPath $temporary -Destination $Path -Force
}

function Read-JsonFile([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return $null }
    try { return Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json } catch { return $null }
}

function Get-ServerPort([string]$ServerRoot) {
    $properties = Join-Path $ServerRoot 'server.properties'
    $match = Select-String -LiteralPath $properties -Pattern '^server-port=(\d+)$' | Select-Object -First 1
    if ($match) { return [int]$match.Matches[0].Groups[1].Value }
    return 25565
}

function Get-ServerSettings {
    [CmdletBinding()]
    param([string]$ServerRoot, [string]$SettingsPath, [string]$PackUrl)

    if (-not $SettingsPath) {
        if ($ServerRoot -and (Test-Path -LiteralPath (Join-Path $ServerRoot 'packwiz-tools\server-settings.json'))) {
            $SettingsPath = Join-Path $ServerRoot 'packwiz-tools\server-settings.json'
        } else {
            $SettingsPath = Join-Path $script:ServerToolsRoot 'server-settings.json'
        }
    }
    $provided = Read-JsonFile $SettingsPath
    $defaults = [ordered]@{
        packUrl = ''
        backupDirectory = 'backups\packwiz'
        gracefulStopTimeoutSeconds = 240
        startupTimeoutSeconds = 180
        startupDelaySeconds = 60
        restartBackoffSeconds = @(15, 30, 60, 120)
        rapidFailureWindowMinutes = 10
        maxRapidFailures = 4
        stableRunResetMinutes = 20
        backupRetentionDaily = 7
        backupRetentionWeekly = 4
        taskNamePrefix = 'MilkyJ Minecraft Server'
        discordWebhookFile = 'discord-webhook.txt'
        discordServerName = 'MilkyJ Vanilla+'
        discordWebhookUsername = 'MilkyJ Server Status'
        discordAllowInsecureLocalTest = $false
        launchExecutable = ''
        launchArguments = @()
    }
    if ($provided) {
        foreach ($property in $provided.PSObject.Properties) { $defaults[$property.Name] = $property.Value }
    }
    if ($PackUrl) { $defaults.packUrl = $PackUrl }
    return [pscustomobject]$defaults
}

function Get-ServerState([string]$ServerRoot) {
    return Read-JsonFile (Get-StatePath $ServerRoot)
}

function Test-ProcessIdentity([int]$ProcessId, [string]$ExpectedCommandPattern) {
    if ($ProcessId -le 0) { return $false }
    $process = Get-CimInstance Win32_Process -Filter "ProcessId=$ProcessId" -ErrorAction SilentlyContinue
    return [bool]($process -and $process.CommandLine -and $process.CommandLine -match $ExpectedCommandPattern)
}

function Get-ServerActivity([string]$ServerRoot) {
    $port = Get-ServerPort $ServerRoot
    $listeners = @(Get-NetTCPConnection -LocalPort $port -State Listen -ErrorAction SilentlyContinue)
    $state = Get-ServerState $ServerRoot
    $supervisors = @()
    $serverProcesses = @()
    if ($state -and $state.supervisorPid -and (Test-ProcessIdentity ([int]$state.supervisorPid) 'Server-Supervisor\.ps1')) {
        $supervisors = @(Get-CimInstance Win32_Process -Filter "ProcessId=$([int]$state.supervisorPid)" -ErrorAction SilentlyContinue)
    }
    if ($state -and $state.serverPid) {
        $serverProcesses = @(Get-CimInstance Win32_Process -Filter "ProcessId=$([int]$state.serverPid)" -ErrorAction SilentlyContinue)
    }
    if ($supervisors.Count -eq 0) {
        $escapedRoot = [regex]::Escape($ServerRoot)
        $supervisors = @(Get-CimInstance Win32_Process -Filter "Name='powershell.exe' OR Name='pwsh.exe'" -ErrorAction SilentlyContinue |
            Where-Object { $_.CommandLine -and $_.CommandLine -match 'Server-Supervisor\.ps1' -and $_.CommandLine -match $escapedRoot })
    }
    return [pscustomobject]@{
        Port = $port
        Listeners = $listeners
        Supervisors = $supervisors
        ServerProcesses = $serverProcesses
        State = $state
        Running = ($listeners.Count -gt 0 -or $supervisors.Count -gt 0 -or $serverProcesses.Count -gt 0)
    }
}

function Assert-ServerStopped([string]$ServerRoot) {
    $activity = Get-ServerActivity $ServerRoot
    if ($activity.Running) {
        $listenerPids = @($activity.Listeners | Select-Object -ExpandProperty OwningProcess -Unique) -join ', '
        $supervisorPids = @($activity.Supervisors | Select-Object -ExpandProperty ProcessId -Unique) -join ', '
        $serverPids = @($activity.ServerProcesses | Select-Object -ExpandProperty ProcessId -Unique) -join ', '
        throw "Operation refused: server activity exists on port $($activity.Port) (listener=$listenerPids; supervisor=$supervisorPids; recorded-server=$serverPids). Stop it cleanly first."
    }
}

function Wait-ServerStopped([string]$ServerRoot, [int]$TimeoutSeconds) {
    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    do {
        if (-not (Get-ServerActivity $ServerRoot).Running) { return $true }
        Start-Sleep -Seconds 1
    } while ((Get-Date) -lt $deadline)
    return $false
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
    $match = Select-String -LiteralPath (Join-Path $ServerRoot 'server.properties') -Pattern '^level-name=(.+)$' | Select-Object -First 1
    if ($match) { return $match.Matches[0].Groups[1].Value.Trim() }
    return 'world'
}

function Get-BackupItems([string]$ServerRoot) {
    return @(
        (Get-LevelName $ServerRoot), 'mods', 'config', 'defaultconfigs', 'kubejs', 'scripts', 'resourcepacks',
        'moonlight-global-datapacks', '.packwiz-installer', '.packwiz-installer-cache', 'packwiz.json',
        'server.properties', 'eula.txt', 'user_jvm_args.txt', 'ops.json', 'whitelist.json',
        'banned-ips.json', 'banned-players.json', 'run.bat', 'run.sh', 'libraries', 'packwiz-tools',
        'server-management\current-version.json'
    ) | Select-Object -Unique
}

function Get-ManagedUpdateItems {
    return @('mods', 'config', 'defaultconfigs', 'kubejs', 'scripts', 'resourcepacks',
        'moonlight-global-datapacks', '.packwiz-installer', '.packwiz-installer-cache', 'packwiz.json')
}

function Assert-SafeChildPath([string]$Root, [string]$Path) {
    $rootResolved = [IO.Path]::GetFullPath($Root).TrimEnd('\') + '\'
    $pathResolved = [IO.Path]::GetFullPath($Path)
    if (-not $pathResolved.StartsWith($rootResolved, [StringComparison]::OrdinalIgnoreCase)) {
        throw "Unsafe path outside server root: $pathResolved"
    }
}

function Get-CurrentPackVersion([string]$ServerRoot) {
    $record = Read-JsonFile (Join-Path (Get-ManagementRoot $ServerRoot) 'current-version.json')
    if ($record -and $record.version) { return [string]$record.version }
    return 'unknown (no successful managed update recorded)'
}

function Get-LatestBackup([string]$ServerRoot, $Settings) {
    $root = [string]$Settings.backupDirectory
    if (-not [IO.Path]::IsPathRooted($root)) { $root = Join-Path $ServerRoot $root }
    if (-not (Test-Path -LiteralPath $root)) { return $null }
    return Get-ChildItem -LiteralPath $root -File -Filter '*.zip' | Sort-Object LastWriteTimeUtc -Descending | Select-Object -First 1
}

function Quote-WindowsArgument([string]$Value) {
    if ($Value -notmatch '[\s"]') { return $Value }
    return '"' + ([regex]::Replace($Value, '(\\*)"', '$1$1\"') -replace '(\\+)$', '$1$1') + '"'
}

function Get-LaunchSpec([string]$ServerRoot, $Settings) {
    if ([string]$Settings.launchExecutable) {
        $executable = [IO.Path]::GetFullPath([string]$Settings.launchExecutable)
        if (-not (Test-Path -LiteralPath $executable -PathType Leaf)) { throw "Configured server executable not found: $executable" }
        $arguments = @($Settings.launchArguments | ForEach-Object { Quote-WindowsArgument ([string]$_) }) -join ' '
        return [pscustomobject]@{ Executable=$executable; Arguments=$arguments }
    }
    $java = Find-Java17 $null
    $forgeRoot = Join-Path $ServerRoot 'libraries\net\minecraftforge\forge'
    $winArgs = Get-ChildItem -LiteralPath $forgeRoot -Recurse -File -Filter 'win_args.txt' -ErrorAction SilentlyContinue |
        Sort-Object FullName -Descending | Select-Object -First 1
    if (-not $winArgs) { throw "Forge win_args.txt not found under $forgeRoot" }
    $relativeArgs = $winArgs.FullName.Substring($ServerRoot.TrimEnd('\').Length + 1)
    $jvmArgs = Join-Path $ServerRoot 'user_jvm_args.txt'
    if (-not (Test-Path -LiteralPath $jvmArgs -PathType Leaf)) { throw "Forge user_jvm_args.txt not found: $jvmArgs" }
    # Launch Java directly so this supervisor owns stdin and the true JVM PID. This
    # deliberately avoids legacy run.bat wrappers that may start another watchdog.
    return [pscustomobject]@{ Executable=$java; Arguments=(('@user_jvm_args.txt', ('@' + $relativeArgs), 'nogui') -join ' ') }
}
