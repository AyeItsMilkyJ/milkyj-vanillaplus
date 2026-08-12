[CmdletBinding()]
param(
    [string]$ServerRoot,
    [string]$BackupRoot
)

. (Join-Path $PSScriptRoot 'Common.ps1')
$serverRootResolved = Assert-ValidServerRoot (Resolve-ServerRoot $ServerRoot)
Assert-ServerStopped $serverRootResolved

if (-not $BackupRoot) { $BackupRoot = Join-Path $serverRootResolved 'backups\packwiz' }
$backupRootResolved = [IO.Path]::GetFullPath($BackupRoot)
$timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$backupPath = Join-Path $backupRootResolved $timestamp
$filesPath = Join-Path $backupPath 'files'
New-Item -ItemType Directory -Path $filesPath -Force | Out-Null
[IO.File]::WriteAllText((Join-Path $backupPath '.incomplete'), "Backup started $(Get-Date -Format o)", [Text.UTF8Encoding]::new($false))

$copied = @()
try {
    foreach ($relative in Get-BackupItems $serverRootResolved) {
        $source = Join-Path $serverRootResolved $relative
        if (-not (Test-Path -LiteralPath $source)) { continue }
        $destination = Join-Path $filesPath $relative
        New-Item -ItemType Directory -Path (Split-Path -Parent $destination) -Force | Out-Null
        Copy-Item -LiteralPath $source -Destination $destination -Recurse -Force
        $copied += $relative
    }
    $levelName = Get-LevelName $serverRootResolved
    $worldPath = Join-Path $serverRootResolved $levelName
    $worldBytes = if (Test-Path -LiteralPath $worldPath) { (Get-ChildItem -LiteralPath $worldPath -Recurse -File | Measure-Object Length -Sum).Sum } else { 0 }
    $manifest = [ordered]@{
        createdAt = (Get-Date).ToString('o')
        serverRoot = $serverRootResolved
        worldName = $levelName
        worldIncluded = ($levelName -in $copied)
        worldBytes = $worldBytes
        copiedItems = $copied
        purpose = 'Pre-Packwiz-update safety backup'
    }
    $manifest | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $backupPath 'backup-manifest.json') -Encoding utf8
    Remove-Item -LiteralPath (Join-Path $backupPath '.incomplete') -Force
} catch {
    Write-Error "Backup failed and has been left marked incomplete at $backupPath. No update was attempted. $($_.Exception.Message)"
    throw
}

Write-Host "Backup complete: $backupPath"
return $backupPath
