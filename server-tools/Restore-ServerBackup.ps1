[CmdletBinding(SupportsShouldProcess, ConfirmImpact='High')]
param(
    [Parameter(Mandatory)][string]$BackupPath,
    [string]$ServerRoot,
    [string]$SettingsPath,
    [switch]$RestoreWorld,
    [switch]$RestoreImportantFiles,
    [switch]$SkipManagedFiles
)

. (Join-Path $PSScriptRoot 'Common.ps1')
$serverRootResolved = Assert-ValidServerRoot (Resolve-ServerRoot $ServerRoot)
Assert-ServerStopped $serverRootResolved
$backupResolved = [IO.Path]::GetFullPath($BackupPath)
$validation = & (Join-Path $PSScriptRoot 'Test-ServerBackup.ps1') -BackupPath $backupResolved -PassThru
if (-not $validation.valid) { throw "Invalid backup: $($validation.errors -join '; ')" }

if ($RestoreWorld) {
    Write-Host 'Creating and validating a fresh safety backup before replacing the current world...'
    & (Join-Path $PSScriptRoot 'Backup-Server.ps1') -ServerRoot $serverRootResolved -SettingsPath $SettingsPath | Out-Host
}

$stagingRoot = Join-Path (Get-ManagementRoot $serverRootResolved) ('restore-staging\' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $stagingRoot -Force | Out-Null
try {
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    [IO.Compression.ZipFile]::ExtractToDirectory($backupResolved, $stagingRoot)
    $filesRoot = Join-Path $stagingRoot 'files'
    $manifest = Get-Content -LiteralPath (Join-Path $stagingRoot 'backup-manifest.json') -Raw | ConvertFrom-Json

    if (-not $SkipManagedFiles) {
        foreach ($relative in Get-ManagedUpdateItems) {
            $target = Join-Path $serverRootResolved $relative
            $source = Join-Path $filesRoot $relative
            Assert-SafeChildPath $serverRootResolved $target
            if ($PSCmdlet.ShouldProcess($target, "Restore managed item from $backupResolved")) {
                if (Test-Path -LiteralPath $target) { Remove-Item -LiteralPath $target -Recurse -Force }
                if (Test-Path -LiteralPath $source) { Copy-Item -LiteralPath $source -Destination $target -Recurse -Force }
            }
        }
    }

    if ($RestoreImportantFiles) {
        foreach ($relative in @('server.properties','eula.txt','user_jvm_args.txt','ops.json','whitelist.json','banned-ips.json','banned-players.json','run.bat','run.sh')) {
            $source = Join-Path $filesRoot $relative
            $target = Join-Path $serverRootResolved $relative
            if ((Test-Path -LiteralPath $source) -and $PSCmdlet.ShouldProcess($target, 'Restore important server file')) {
                Copy-Item -LiteralPath $source -Destination $target -Force
            }
        }
    }

    if ($RestoreWorld) {
        $worldName = [string]$manifest.worldName
        $source = Join-Path $filesRoot $worldName
        $target = Join-Path $serverRootResolved $worldName
        if (-not (Test-Path -LiteralPath (Join-Path $source 'level.dat') -PathType Leaf)) { throw 'Selected backup does not contain a valid world/level.dat.' }
        Assert-SafeChildPath $serverRootResolved $target
        if ($PSCmdlet.ShouldProcess($target, 'Replace world from selected verified backup')) {
            if (Test-Path -LiteralPath $target) { Remove-Item -LiteralPath $target -Recurse -Force }
            Copy-Item -LiteralPath $source -Destination $target -Recurse -Force
        }
    }
} finally {
    if (Test-Path -LiteralPath $stagingRoot) { Remove-Item -LiteralPath $stagingRoot -Recurse -Force }
}
Write-Host "Restore completed from verified backup $backupResolved"
