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
. (Join-Path $PSScriptRoot 'Discord-Notifications.ps1')
$root = Assert-ValidServerRoot (Resolve-ServerRoot $ServerRoot)
Assert-ServerStopped $root
$settings = Get-ServerSettings -ServerRoot $root -SettingsPath $SettingsPath
if ($PSCmdlet.ShouldProcess($root, "Rollback Packwiz-managed files from $BackupPath")) {
    Send-DiscordServerNotification -ServerRoot $root -Settings $settings -Event rollingback `
        -Description 'An operator-approved rollback of Packwiz-managed server files has started. Minecraft is stopped.'
    try {
        & (Join-Path $PSScriptRoot 'Restore-ServerBackup.ps1') -BackupPath $BackupPath -ServerRoot $root -SettingsPath $SettingsPath -Confirm:$false
        & (Join-Path $PSScriptRoot 'Test-ServerInstallation.ps1') -ServerRoot $root | Out-Host
        Send-DiscordServerNotification -ServerRoot $root -Settings $settings -Event rolledback `
            -Description 'The rollback restored and structurally validated the managed server files.' `
            -Fields @{ 'Restored version' = (Get-CurrentPackVersion $root) }
        if ($StartAfterRollback) { & (Join-Path $PSScriptRoot 'Start-Server.ps1') -ServerRoot $root -SettingsPath $SettingsPath -ServerGui:$ServerGui }
    } catch {
        Send-DiscordServerNotification -ServerRoot $root -Settings $settings -Event failed `
            -Description 'The rollback did not complete. Operator attention is required; no automatic destructive recovery was attempted.'
        throw
    }
}
