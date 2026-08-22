[CmdletBinding(SupportsShouldProcess, ConfirmImpact='High')]
param(
    [Parameter(Mandatory)][string]$BackupPath,
    [string]$ServerRoot,
    [string]$SettingsPath,
    [switch]$StartAfterRollback,
    [switch]$ServerGui
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Common.ps1')
$root = Assert-ValidServerRoot (Resolve-ServerRoot $ServerRoot)
Assert-ServerStopped $root
if ($PSCmdlet.ShouldProcess($root, "Rollback Packwiz-managed files from $BackupPath")) {
    & (Join-Path $PSScriptRoot 'Restore-ServerBackup.ps1') -BackupPath $BackupPath -ServerRoot $root -SettingsPath $SettingsPath -Confirm:$false
    & (Join-Path $PSScriptRoot 'Test-ServerInstallation.ps1') -ServerRoot $root | Out-Host
    if ($StartAfterRollback) { & (Join-Path $PSScriptRoot 'Start-Server.ps1') -ServerRoot $root -SettingsPath $SettingsPath -ServerGui:$ServerGui }
}
