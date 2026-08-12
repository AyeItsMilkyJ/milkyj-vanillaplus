[CmdletBinding()]
param(
    [string]$ServerRoot,
    [string]$PackUrl,
    [string]$JavaPath,
    [int]$StartupTimeoutSeconds = 90
)

$ErrorActionPreference = 'Stop'
$backup = & (Join-Path $PSScriptRoot 'Update-Server.ps1') -ServerRoot $ServerRoot -PackUrl $PackUrl -JavaPath $JavaPath
& (Join-Path $PSScriptRoot 'Start-Server.ps1') -ServerRoot $ServerRoot -StartupTimeoutSeconds $StartupTimeoutSeconds
Write-Host "Update-and-start completed. Pre-update backup: $backup"

