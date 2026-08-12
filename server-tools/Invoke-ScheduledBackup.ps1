[CmdletBinding()]
param([string]$ServerRoot, [string]$SettingsPath)

$ErrorActionPreference = 'Stop'
& (Join-Path $PSScriptRoot 'Backup-Server.ps1') -ServerRoot $ServerRoot -SettingsPath $SettingsPath -RestartIfRunning
