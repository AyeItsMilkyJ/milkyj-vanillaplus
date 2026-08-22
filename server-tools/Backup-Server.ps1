[CmdletBinding()]
param(
    [string]$ServerRoot,
    [string]$SettingsPath,
    [string]$BackupRoot,
    [switch]$RestartIfRunning,
    [switch]$SkipRetention
)

. (Join-Path $PSScriptRoot 'Common.ps1')
$serverRootResolved = Assert-ValidServerRoot (Resolve-ServerRoot $ServerRoot)
$settings = Get-ServerSettings -ServerRoot $serverRootResolved -SettingsPath $SettingsPath
$priorState = Get-ServerState $serverRootResolved
$restartWithServerGui = [bool]($priorState -and $priorState.PSObject.Properties['serverGui'] -and $priorState.serverGui)
$wasRunning = (Get-ServerActivity $serverRootResolved).Running
if ($wasRunning -and -not $RestartIfRunning) {
    throw 'Cold backup refused while the server is active. Use -RestartIfRunning for a controlled stop, backup, and restart.'
}
if ($wasRunning) {
    & (Join-Path $PSScriptRoot 'Stop-Server.ps1') -ServerRoot $serverRootResolved -SettingsPath $SettingsPath
}

$backupSucceeded = $false
try {
    Assert-ServerStopped $serverRootResolved
    if (-not $BackupRoot) { $BackupRoot = [string]$settings.backupDirectory }
    if (-not [IO.Path]::IsPathRooted($BackupRoot)) { $BackupRoot = Join-Path $serverRootResolved $BackupRoot }
    $backupRootResolved = [IO.Path]::GetFullPath($BackupRoot)
    New-Item -ItemType Directory -Path $backupRootResolved -Force | Out-Null

    $timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $archivePath = Join-Path $backupRootResolved "$timestamp.zip"
    $suffix = 1
    while (Test-Path -LiteralPath $archivePath) {
        $archivePath = Join-Path $backupRootResolved ("{0}-{1}.zip" -f $timestamp, $suffix)
        $suffix++
    }
    $temporaryArchive = "$archivePath.incomplete"
    $staging = Join-Path $backupRootResolved ('.staging-' + [guid]::NewGuid().ToString('N'))
    $filesRoot = Join-Path $staging 'files'
    New-Item -ItemType Directory -Path $filesRoot -Force | Out-Null

    $copied = @()
    try {
        foreach ($relative in Get-BackupItems $serverRootResolved) {
            $source = Join-Path $serverRootResolved $relative
            if (-not (Test-Path -LiteralPath $source)) { continue }
            $destination = Join-Path $filesRoot $relative
            New-Item -ItemType Directory -Path (Split-Path -Parent $destination) -Force | Out-Null
            Copy-Item -LiteralPath $source -Destination $destination -Recurse -Force
            $copied += $relative
        }
        $worldName = Get-LevelName $serverRootResolved
        $worldPath = Join-Path $serverRootResolved $worldName
        $worldBytes = if (Test-Path -LiteralPath $worldPath) { (Get-ChildItem -LiteralPath $worldPath -Recurse -File | Measure-Object Length -Sum).Sum } else { 0 }
        $packwizHash = if (Test-Path -LiteralPath (Join-Path $serverRootResolved 'packwiz.json')) {
            (Get-FileHash -LiteralPath (Join-Path $serverRootResolved 'packwiz.json') -Algorithm SHA256).Hash.ToLowerInvariant()
        } else { $null }
        $manifest = [ordered]@{
            format = 2
            createdAt = (Get-Date).ToString('o')
            serverRootAtCreation = $serverRootResolved
            worldName = $worldName
            worldIncluded = ($worldName -in $copied)
            worldBytes = $worldBytes
            copiedItems = $copied
            packVersion = Get-CurrentPackVersion $serverRootResolved
            packwizStateSha256 = $packwizHash
            purpose = 'Cold, pre-update/recovery-capable dedicated-server backup'
        }
        Write-JsonAtomic (Join-Path $staging 'backup-manifest.json') $manifest
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        [IO.Compression.ZipFile]::CreateFromDirectory($staging, $temporaryArchive, [IO.Compression.CompressionLevel]::Optimal, $false)
        Move-Item -LiteralPath $temporaryArchive -Destination $archivePath
    } finally {
        if (Test-Path -LiteralPath $staging) { Remove-Item -LiteralPath $staging -Recurse -Force }
    }

    $validation = & (Join-Path $PSScriptRoot 'Test-ServerBackup.ps1') -BackupPath $archivePath -PassThru
    if (-not $validation.valid) {
        $invalidPath = "$archivePath.invalid"
        Move-Item -LiteralPath $archivePath -Destination $invalidPath -Force
        throw "Created archive failed validation and was quarantined as ${invalidPath}: $($validation.errors -join '; ')"
    }
    $sidecar = [ordered]@{
        archive = [IO.Path]::GetFileName($archivePath)
        sha256 = (Get-FileHash -LiteralPath $archivePath -Algorithm SHA256).Hash.ToLowerInvariant()
        sizeBytes = (Get-Item -LiteralPath $archivePath).Length
        validatedAt = (Get-Date).ToString('o')
        entriesRead = $validation.entriesRead
        worldIncluded = $validation.worldIncluded
    }
    Write-JsonAtomic "$archivePath.manifest.json" $sidecar
    $backupSucceeded = $true
    Write-Host "Verified backup complete: $archivePath"

    if (-not $SkipRetention) {
        & (Join-Path $PSScriptRoot 'Invoke-BackupRetention.ps1') -ServerRoot $serverRootResolved -SettingsPath $SettingsPath -BackupRoot $backupRootResolved -NewValidBackup $archivePath
    }
    return $archivePath
} finally {
    if ($wasRunning) {
        if ($backupSucceeded) {
            & (Join-Path $PSScriptRoot 'Start-Server.ps1') -ServerRoot $serverRootResolved -SettingsPath $SettingsPath -ServerGui:$restartWithServerGui
        } else {
            Write-Warning 'Backup failed after a controlled stop. The server was left stopped so the failure can be investigated safely.'
        }
    }
}
