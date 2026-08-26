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
    $destination = [IO.Path]::GetFullPath($Path)
    $parent = Split-Path -Parent $destination
    New-Item -ItemType Directory -Path $parent -Force | Out-Null
    $temporary = "$destination.new"
    [IO.File]::WriteAllText($temporary, (($Value | ConvertTo-Json -Depth 12) + "`r`n"), [Text.UTF8Encoding]::new($false))
    if (Test-Path -LiteralPath $destination -PathType Leaf) {
        # File.Replace keeps readers from observing the brief missing-file gap
        # created by Remove + Move on Windows.
        $replaceBackup = "$destination.replace-backup"
        if ([IO.File]::Exists($replaceBackup)) { [IO.File]::Delete($replaceBackup) }
        [IO.File]::Replace($temporary, $destination, $replaceBackup, $true)
        try { [IO.File]::Delete($replaceBackup) } catch { }
    } else {
        [IO.File]::Move($temporary, $destination)
    }
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
        scheduledRestartMinutes = 180
        scheduledRestartDelaySeconds = 10
        scheduledRestartWarningSeconds = @(600, 300, 60, 30, 10)
        restartBackoffSeconds = @(15, 30, 60, 120)
        rapidFailureWindowMinutes = 10
        maxRapidFailures = 4
        stableRunResetMinutes = 20
        backupRetentionDaily = 7
        backupRetentionWeekly = 4
        taskNamePrefix = 'MilkyJ Minecraft Server'
        discordWebhookFile = 'discord-webhook.txt'
        discordServerName = 'MilkyCraft Vanilla+'
        discordWebhookUsername = 'MilkyCraft Server Status'
        discordAllowInsecureLocalTest = $false
        discordMaxAttempts = 3
        discordRetryBaseMilliseconds = 500
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

function Get-OptionalPropertyValue($Object, [string]$Name) {
    if ($null -eq $Object) { return $null }
    if ($Object -is [Collections.IDictionary]) {
        if ($Object.Contains($Name)) { return $Object[$Name] }
        return $null
    }
    $property = $Object.PSObject.Properties[$Name]
    if ($property) { return $property.Value }
    return $null
}

function Set-OptionalPropertyValue($Object, [string]$Name, $Value) {
    if ($Object -is [Collections.IDictionary]) {
        $Object[$Name] = $Value
        return
    }
    $property = $Object.PSObject.Properties[$Name]
    if ($property) {
        $property.Value = $Value
    } else {
        $Object | Add-Member -NotePropertyName $Name -NotePropertyValue $Value
    }
}

function Get-TextSha256([string]$Text) {
    if ($null -eq $Text) { return $null }
    $algorithm = [Security.Cryptography.SHA256]::Create()
    try {
        $bytes = [Text.Encoding]::UTF8.GetBytes($Text)
        return ([BitConverter]::ToString($algorithm.ComputeHash($bytes))).Replace('-', '').ToLowerInvariant()
    } finally {
        $algorithm.Dispose()
    }
}

function Convert-ProcessCreationTimeToUtcString($CreationDate) {
    if ($null -eq $CreationDate) { return $null }
    try {
        $value = if ($CreationDate -is [datetime]) {
            [datetime]$CreationDate
        } else {
            [Management.ManagementDateTimeConverter]::ToDateTime([string]$CreationDate)
        }
        return $value.ToUniversalTime().ToString('o')
    } catch {
        return $null
    }
}

function Convert-ToUtcDateTime($Value) {
    if ($null -eq $Value) { return $null }
    try {
        if ($Value -is [datetime]) { return ([datetime]$Value).ToUniversalTime() }
        return ([DateTimeOffset]::Parse([string]$Value, [Globalization.CultureInfo]::InvariantCulture, [Globalization.DateTimeStyles]::RoundtripKind)).UtcDateTime
    } catch {
        return $null
    }
}

function Get-ProcessFingerprint {
    [CmdletBinding()]
    param([Parameter(Mandatory)][int]$ProcessId)

    if ($ProcessId -le 0) { return $null }
    $process = Get-CimInstance Win32_Process -Filter "ProcessId=$ProcessId" -ErrorAction SilentlyContinue
    if (-not $process) { return $null }
    $createdAt = Convert-ProcessCreationTimeToUtcString $process.CreationDate
    if (-not $createdAt) { return $null }
    return [ordered]@{
        processId = [int]$process.ProcessId
        creationTimeUtc = $createdAt
        executablePath = [string]$process.ExecutablePath
        commandLineSha256 = Get-TextSha256 ([string]$process.CommandLine)
        parentProcessId = [int]$process.ParentProcessId
    }
}

function Test-ProcessFingerprint($Process, $Fingerprint) {
    if (-not $Process -or -not $Fingerprint) { return $false }
    $recordedPid = Get-OptionalPropertyValue $Fingerprint 'processId'
    $recordedCreation = Get-OptionalPropertyValue $Fingerprint 'creationTimeUtc'
    if (-not $recordedPid -or -not $recordedCreation -or [int]$Process.ProcessId -ne [int]$recordedPid) { return $false }

    $actualCreation = Convert-ProcessCreationTimeToUtcString $Process.CreationDate
    if (-not $actualCreation) { return $false }
    try {
        $actualCreationUtc = Convert-ToUtcDateTime $actualCreation
        $recordedCreationUtc = Convert-ToUtcDateTime $recordedCreation
        if ($null -eq $actualCreationUtc -or $null -eq $recordedCreationUtc) { return $false }
        $creationDelta = [Math]::Abs($actualCreationUtc.Subtract($recordedCreationUtc).TotalSeconds)
    } catch {
        return $false
    }
    if ($creationDelta -gt 1) { return $false }

    $recordedExecutable = [string](Get-OptionalPropertyValue $Fingerprint 'executablePath')
    if ($recordedExecutable -and -not $recordedExecutable.Equals([string]$Process.ExecutablePath, [StringComparison]::OrdinalIgnoreCase)) {
        return $false
    }
    $recordedCommandHash = [string](Get-OptionalPropertyValue $Fingerprint 'commandLineSha256')
    if ($recordedCommandHash -and $recordedCommandHash -ne (Get-TextSha256 ([string]$Process.CommandLine))) { return $false }
    $recordedParent = Get-OptionalPropertyValue $Fingerprint 'parentProcessId'
    if ($null -ne $recordedParent -and [int]$recordedParent -ne [int]$Process.ParentProcessId) { return $false }
    return $true
}

function Test-LegacyProcessStartTime($Process, $RecordedStartAt, [int]$ToleranceSeconds = 30) {
    if (-not $Process -or -not $RecordedStartAt) { return $false }
    $actualCreation = Convert-ProcessCreationTimeToUtcString $Process.CreationDate
    if (-not $actualCreation) { return $false }
    try {
        $actualCreationUtc = Convert-ToUtcDateTime $actualCreation
        $recordedCreationUtc = Convert-ToUtcDateTime $RecordedStartAt
        if ($null -eq $actualCreationUtc -or $null -eq $recordedCreationUtc) { return $false }
        return [Math]::Abs($actualCreationUtc.Subtract($recordedCreationUtc).TotalSeconds) -le $ToleranceSeconds
    } catch {
        return $false
    }
}

function Test-SupervisorLockHeld([string]$ServerRoot) {
    $lockPath = Join-Path (Get-ManagementRoot $ServerRoot) 'supervisor.lock'
    if (-not (Test-Path -LiteralPath $lockPath -PathType Leaf)) { return $false }
    $probe = $null
    try {
        $probe = [IO.File]::Open($lockPath, [IO.FileMode]::Open, [IO.FileAccess]::ReadWrite, [IO.FileShare]::None)
        return $false
    } catch [IO.IOException] {
        return $true
    } finally {
        if ($probe) { $probe.Dispose() }
    }
}

function Get-ServerActivity([string]$ServerRoot) {
    $serverRootResolved = [IO.Path]::GetFullPath($ServerRoot)
    $port = Get-ServerPort $serverRootResolved
    $listeners = @(Get-NetTCPConnection -LocalPort $port -State Listen -ErrorAction SilentlyContinue)
    $listenerPids = @($listeners | Select-Object -ExpandProperty OwningProcess -Unique)
    $state = Get-ServerState $serverRootResolved
    $supervisors = @()
    $serverProcesses = @()
    $recordedSupervisorStale = $false
    $recordedServerStale = $false
    $lockHeld = Test-SupervisorLockHeld $serverRootResolved
    # Headless and Minecraft-GUI modes run Server-Supervisor.ps1 in their own
    # hidden PowerShell process. Raw troubleshooting mode runs it inline from
    # Start-Server.ps1 so Java can share that one console. All command lines
    # represent the same supervisor identity.
    $supervisorIdentityPattern = '(?:Server-Supervisor|Start-Server)\.ps1'
    $backgroundSupervisorLaunchPattern = '(?i)(?:^|\s)-File\s+(?:"[^"]*[\\/]Server-Supervisor\.ps1"|[^\s"]*[\\/]Server-Supervisor\.ps1)(?:\s|$)'
    $escapedRoot = [regex]::Escape($serverRootResolved)
    $recordedSupervisorPid = Get-OptionalPropertyValue $state 'supervisorPid'
    if ($recordedSupervisorPid) {
        $candidate = Get-CimInstance Win32_Process -Filter "ProcessId=$([int]$recordedSupervisorPid)" -ErrorAction SilentlyContinue
        $commandMatches = [bool]($candidate -and $candidate.CommandLine -and $candidate.CommandLine -match $supervisorIdentityPattern -and $candidate.CommandLine -match $escapedRoot)
        $fingerprint = Get-OptionalPropertyValue $state 'supervisorProcessFingerprint'
        $fingerprintMatches = if ($fingerprint) {
            Test-ProcessFingerprint $candidate $fingerprint
        } else {
            Test-LegacyProcessStartTime $candidate (Get-OptionalPropertyValue $state 'supervisorStartedAt')
        }
        if ($commandMatches -and $fingerprintMatches) {
            $supervisors = @($candidate)
        } else {
            $recordedSupervisorStale = $true
        }
    }
    if ($supervisors.Count -eq 0) {
        $supervisors = @(Get-CimInstance Win32_Process -Filter "Name='powershell.exe' OR Name='pwsh.exe'" -ErrorAction SilentlyContinue |
            # Fallback discovery deliberately excludes Start-Server.ps1 because
            # this function is called by that script before it becomes the
            # recorded interactive supervisor; matching it here would reject
            # every legitimate visible start as a duplicate.
            Where-Object { $_.CommandLine -and $_.CommandLine -match $backgroundSupervisorLaunchPattern -and $_.CommandLine -match $escapedRoot })
    }

    $recordedServerPid = Get-OptionalPropertyValue $state 'serverPid'
    if ($recordedServerPid) {
        $candidate = Get-CimInstance Win32_Process -Filter "ProcessId=$([int]$recordedServerPid)" -ErrorAction SilentlyContinue
        $fingerprint = Get-OptionalPropertyValue $state 'serverProcessFingerprint'
        $identityMatches = if ($fingerprint) {
            Test-ProcessFingerprint $candidate $fingerprint
        } else {
            $supervisorPids = @($supervisors | Select-Object -ExpandProperty ProcessId -Unique)
            $relatedToKnownServer = $candidate -and (($listenerPids -contains [int]$candidate.ProcessId) -or ($supervisorPids -contains [int]$candidate.ParentProcessId))
            $relatedToKnownServer -and (Test-LegacyProcessStartTime $candidate (Get-OptionalPropertyValue $state 'latestServerStartAt'))
        }
        if ($identityMatches) {
            $serverProcesses = @($candidate)
        } else {
            $recordedServerStale = $true
        }
    }

    $running = ($listeners.Count -gt 0 -or $supervisors.Count -gt 0 -or $serverProcesses.Count -gt 0 -or $lockHeld)
    $status = [string](Get-OptionalPropertyValue $state 'status')
    $activeStatuses = @('starting','running','online','stopping','scheduled-restart','restart-delay','restart-backoff')
    $stateClaimsActivity = $activeStatuses -contains $status
    $stateStale = [bool]($state -and ($recordedSupervisorStale -or $recordedServerStale -or ($stateClaimsActivity -and -not $running)))
    $unmanaged = [bool](($listeners.Count -gt 0 -or $serverProcesses.Count -gt 0) -and $supervisors.Count -eq 0 -and -not $lockHeld)
    return [pscustomobject]@{
        Port = $port
        Listeners = $listeners
        Supervisors = $supervisors
        ServerProcesses = $serverProcesses
        State = $state
        SupervisorLockHeld = $lockHeld
        RecordedSupervisorStale = $recordedSupervisorStale
        RecordedServerStale = $recordedServerStale
        StateStale = $stateStale
        Unmanaged = $unmanaged
        Running = $running
    }
}

function Repair-StaleServerState([string]$ServerRoot) {
    $activity = Get-ServerActivity $ServerRoot
    if ($activity.Running -or -not $activity.StateStale -or -not $activity.State) { return $activity }

    # Recheck immediately before the write. A listener or held supervisor lock
    # always wins over stale metadata and is never modified or killed here.
    $confirmation = Get-ServerActivity $ServerRoot
    if ($confirmation.Running -or -not $confirmation.StateStale -or -not $confirmation.State) { return $confirmation }
    $state = $confirmation.State
    $activeStatuses = @('starting','running','online','stopping','scheduled-restart','restart-delay','restart-backoff')
    if ($activeStatuses -contains [string](Get-OptionalPropertyValue $state 'status')) {
        Set-OptionalPropertyValue $state 'status' 'stopped-after-abrupt-exit'
        Set-OptionalPropertyValue $state 'manualInterventionRequired' $false
        Set-OptionalPropertyValue $state 'latestCrashOrRestartEvent' "$(Get-Date -Format o) Reconciled stale state after an abrupt supervisor/server exit; no matching process, listener, or held supervisor lock remained."
    }
    Set-OptionalPropertyValue $state 'supervisorPid' $null
    Set-OptionalPropertyValue $state 'serverPid' $null
    Set-OptionalPropertyValue $state 'supervisorProcessFingerprint' $null
    Set-OptionalPropertyValue $state 'serverProcessFingerprint' $null
    Set-OptionalPropertyValue $state 'nextScheduledRestart' $null
    Set-OptionalPropertyValue $state 'stateReconciledAt' (Get-Date).ToString('o')
    Write-JsonAtomic (Get-StatePath $ServerRoot) $state
    return Get-ServerActivity $ServerRoot
}

function Assert-ServerStopped([string]$ServerRoot) {
    $activity = Repair-StaleServerState $ServerRoot
    if ($activity.Running) {
        $listenerPids = @($activity.Listeners | Select-Object -ExpandProperty OwningProcess -Unique) -join ', '
        $supervisorPids = @($activity.Supervisors | Select-Object -ExpandProperty ProcessId -Unique) -join ', '
        $serverPids = @($activity.ServerProcesses | Select-Object -ExpandProperty ProcessId -Unique) -join ', '
        throw "Operation refused: server activity exists on port $($activity.Port) (listener=$listenerPids; supervisor=$supervisorPids; recorded-server=$serverPids; supervisor-lock=$($activity.SupervisorLockHeld)). Stop it cleanly first."
    }
}

function Wait-ServerStopped([string]$ServerRoot, [int]$TimeoutSeconds) {
    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    do {
        if (-not (Repair-StaleServerState $ServerRoot).Running) { return $true }
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
        'moonlight-global-datapacks', '.packwiz-installer', '.packwiz-installer-cache', 'packwiz.json',
        'server-management\current-version.json')
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

function Get-LaunchSpec([string]$ServerRoot, $Settings, [switch]$ServerGui) {
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
    # Forge/Minecraft creates its Swing server window only when `nogui` is absent.
    # Keep headless mode as the safe default for Task Scheduler and unattended
    # sessions; the operator-facing run.bat opts into the real server GUI.
    $arguments = @('@user_jvm_args.txt', ('@' + $relativeArgs))
    if (-not $ServerGui) { $arguments += 'nogui' }
    return [pscustomobject]@{ Executable=$java; Arguments=($arguments -join ' ') }
}
