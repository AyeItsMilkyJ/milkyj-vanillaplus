[CmdletBinding(SupportsShouldProcess, ConfirmImpact='High')]
param(
    [Parameter(Mandatory)][string]$BackupPath,
    [string]$ServerRoot,
    [switch]$RestoreWorld,
    [switch]$RestoreImportantFiles
)

. (Join-Path $PSScriptRoot 'Common.ps1')
$serverRootResolved = Assert-ValidServerRoot (Resolve-ServerRoot $ServerRoot)
Assert-ServerStopped $serverRootResolved
$backupResolved = [IO.Path]::GetFullPath($BackupPath)
if (-not (Test-Path -LiteralPath (Join-Path $backupResolved 'backup-manifest.json'))) { throw "Invalid/incomplete backup: $backupResolved" }

if ($RestoreWorld) {
    Write-Host 'Creating a fresh safety backup before replacing the current world...'
    & (Join-Path $PSScriptRoot 'Backup-Server.ps1') -ServerRoot $serverRootResolved | Out-Host
}

if ($PSCmdlet.ShouldProcess($serverRootResolved, "Restore Packwiz-managed files from $backupResolved")) {
    Restore-ManagedFiles $serverRootResolved $backupResolved
}

if ($RestoreImportantFiles) {
    foreach ($relative in @('server.properties','eula.txt','user_jvm_args.txt','ops.json','whitelist.json','banned-ips.json','banned-players.json','run.bat','server-supervisor.ps1')) {
        $source = Join-Path (Join-Path $backupResolved 'files') $relative
        $target = Join-Path $serverRootResolved $relative
        if ((Test-Path -LiteralPath $source) -and $PSCmdlet.ShouldProcess($target, 'Restore important server file')) {
            Copy-Item -LiteralPath $source -Destination $target -Force
        }
    }
}

if ($RestoreWorld) {
    $manifest = Get-Content -LiteralPath (Join-Path $backupResolved 'backup-manifest.json') -Raw | ConvertFrom-Json
    $worldName = if ($manifest.worldName) { [string]$manifest.worldName } else { 'world' }
    $source = Join-Path (Join-Path $backupResolved 'files') $worldName
    $target = Join-Path $serverRootResolved $worldName
    if (-not (Test-Path -LiteralPath $source -PathType Container)) { throw 'Selected backup does not contain a world.' }
    Assert-SafeChildPath $serverRootResolved $target
    if ($PSCmdlet.ShouldProcess($target, 'Replace world from selected backup')) {
        if (Test-Path -LiteralPath $target) { Remove-Item -LiteralPath $target -Recurse -Force }
        Copy-Item -LiteralPath $source -Destination $target -Recurse
    }
}

Write-Host "Restore completed from $backupResolved"
