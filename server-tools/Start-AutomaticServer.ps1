[CmdletBinding()]
param([string]$ServerRoot, [string]$SettingsPath)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Common.ps1')
$root = Assert-ValidServerRoot (Resolve-ServerRoot $ServerRoot)
# The Task Scheduler BootTrigger owns the configurable network-initialization delay.
& (Join-Path $PSScriptRoot 'Start-Server.ps1') -ServerRoot $root -SettingsPath $SettingsPath
