[CmdletBinding()]
param(
    [string]$ServerRoot,
    [string]$PackUrl,
    [string]$JavaPath,
    [string]$SettingsPath,
    [int]$StartupTimeoutSeconds = 0
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Common.ps1')
$serverRootResolved = Assert-ValidServerRoot (Resolve-ServerRoot $ServerRoot)
$settings = Get-ServerSettings -ServerRoot $serverRootResolved -SettingsPath $SettingsPath
if ($StartupTimeoutSeconds -le 0) { $StartupTimeoutSeconds = [int]$settings.startupTimeoutSeconds }
$operationStarted = Get-Date
$backup = & (Join-Path $PSScriptRoot 'Update-Server.ps1') -ServerRoot $serverRootResolved -PackUrl $PackUrl -JavaPath $JavaPath -SettingsPath $SettingsPath
try {
    & (Join-Path $PSScriptRoot 'Start-Server.ps1') -ServerRoot $serverRootResolved -SettingsPath $SettingsPath -StartupTimeoutSeconds $StartupTimeoutSeconds
    $latest = Join-Path $serverRootResolved 'logs\latest.log'
    $deadline = (Get-Date).AddSeconds($StartupTimeoutSeconds)
    $done = $false
    do {
        if (Test-Path -LiteralPath $latest) {
            $item = Get-Item -LiteralPath $latest
            if ($item.LastWriteTime -ge $operationStarted) { $done = [bool](Select-String -LiteralPath $latest -SimpleMatch 'Done (' -Quiet) }
        }
        if (-not $done) { Start-Sleep -Seconds 2 }
    } while (-not $done -and (Get-Date) -lt $deadline)
    if (-not $done) { throw "Updated server listened but did not record a fresh Done line within $StartupTimeoutSeconds seconds." }
    Write-Host "Update-and-start verified Minecraft reached Done. Pre-update backup: $backup"
} catch {
    Write-Warning "Updated server failed startup verification: $($_.Exception.Message)"
    try { & (Join-Path $PSScriptRoot 'Stop-Server.ps1') -ServerRoot $serverRootResolved -SettingsPath $SettingsPath } catch { Write-Warning $_.Exception.Message }
    Write-Warning "Rollback is operator-controlled. Run: .\Rollback-ServerUpdate.ps1 -BackupPath `"$backup`" -ServerRoot `"$serverRootResolved`" -StartAfterRollback"
    throw
}
