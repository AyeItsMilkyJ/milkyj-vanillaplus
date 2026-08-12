[CmdletBinding()]
param([string]$ServerRoot, [string]$SettingsPath, [int]$StartupTimeoutSeconds = 0)

$ErrorActionPreference = 'Stop'
& (Join-Path $PSScriptRoot 'Stop-Server.ps1') -ServerRoot $ServerRoot -SettingsPath $SettingsPath
& (Join-Path $PSScriptRoot 'Start-Server.ps1') -ServerRoot $ServerRoot -SettingsPath $SettingsPath -StartupTimeoutSeconds $StartupTimeoutSeconds
Write-Host 'Graceful restart completed.'
