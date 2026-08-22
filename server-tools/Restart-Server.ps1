[CmdletBinding()]
param([string]$ServerRoot, [string]$SettingsPath, [int]$StartupTimeoutSeconds = 0, [switch]$ServerGui)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Common.ps1')
. (Join-Path $PSScriptRoot 'Discord-Notifications.ps1')
$serverRootResolved = Assert-ValidServerRoot (Resolve-ServerRoot $ServerRoot)
$settings = Get-ServerSettings -ServerRoot $serverRootResolved -SettingsPath $SettingsPath
$priorState = Get-ServerState $serverRootResolved
$restartWithServerGui = [bool]$ServerGui -or [bool]($priorState -and $priorState.PSObject.Properties['serverGui'] -and $priorState.serverGui)
Send-DiscordServerNotification -ServerRoot $serverRootResolved -Settings $settings -Event restarting `
    -Description 'A clean operator-requested restart has begun. Players can reconnect when the online message appears.'
& (Join-Path $PSScriptRoot 'Stop-Server.ps1') -ServerRoot $ServerRoot -SettingsPath $SettingsPath
& (Join-Path $PSScriptRoot 'Start-Server.ps1') -ServerRoot $ServerRoot -SettingsPath $SettingsPath -StartupTimeoutSeconds $StartupTimeoutSeconds -ServerGui:$restartWithServerGui
Write-Host 'Graceful restart completed.'
