[CmdletBinding()]
param(
    [string]$ServerRoot,
    [string]$PackUrl,
    [string]$JavaPath,
    [string]$SettingsPath,
    [int]$StartupTimeoutSeconds = 0,
    [switch]$ServerGui
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Common.ps1')
. (Join-Path $PSScriptRoot 'Discord-Notifications.ps1')
$serverRootResolved = Assert-ValidServerRoot (Resolve-ServerRoot $ServerRoot)
$settings = Get-ServerSettings -ServerRoot $serverRootResolved -SettingsPath $SettingsPath
if ($StartupTimeoutSeconds -le 0) { $StartupTimeoutSeconds = [int]$settings.startupTimeoutSeconds }
$operationStarted = Get-Date
$backup = & (Join-Path $PSScriptRoot 'Update-Server.ps1') -ServerRoot $serverRootResolved -PackUrl $PackUrl -JavaPath $JavaPath -SettingsPath $SettingsPath
try {
    $backupResolved = [IO.Path]::GetFullPath([string]$backup)
    $managementRoot = Get-ManagementRoot $serverRootResolved
    $currentVersionPath = Join-Path $managementRoot 'current-version.json'
    $currentVersion = Read-JsonFile $currentVersionPath
    if (-not $currentVersion) { throw 'The updater did not create a readable current-version record.' }
    $installedVersion = [string](Get-OptionalPropertyValue $currentVersion 'version')
    $updateRecordPath = [string](Get-OptionalPropertyValue $currentVersion 'updateRecord')
    $currentRollbackBackup = [string](Get-OptionalPropertyValue $currentVersion 'rollbackBackup')
    if (-not $installedVersion -or -not $updateRecordPath -or -not $currentRollbackBackup) {
        throw 'The current-version record is missing version, updateRecord or rollbackBackup.'
    }
    $updateRecordPath = [IO.Path]::GetFullPath($updateRecordPath)
    $managementPrefix = $managementRoot.TrimEnd('\') + '\'
    if (-not $updateRecordPath.StartsWith($managementPrefix, [StringComparison]::OrdinalIgnoreCase)) {
        throw 'The current-version update record points outside server-management.'
    }
    if (-not ([IO.Path]::GetFullPath($currentRollbackBackup)).Equals($backupResolved, [StringComparison]::OrdinalIgnoreCase)) {
        throw 'The current-version rollback backup does not match this update invocation.'
    }
    $updateRecord = Read-JsonFile $updateRecordPath
    if (-not $updateRecord) { throw 'The updater did not create a readable update operation record.' }
    if ([string](Get-OptionalPropertyValue $updateRecord 'status') -ne 'installed-not-yet-start-verified') {
        throw 'The update operation is not awaiting startup verification.'
    }
    if ([string](Get-OptionalPropertyValue $updateRecord 'installedVersion') -ne $installedVersion) {
        throw 'The update operation and current-version records disagree on the installed version.'
    }
    $recordRollbackBackup = [string](Get-OptionalPropertyValue $updateRecord 'rollbackBackup')
    if (-not $recordRollbackBackup -or -not ([IO.Path]::GetFullPath($recordRollbackBackup)).Equals($backupResolved, [StringComparison]::OrdinalIgnoreCase)) {
        throw 'The update operation rollback backup does not match this update invocation.'
    }

    & (Join-Path $PSScriptRoot 'Start-Server.ps1') -ServerRoot $serverRootResolved -SettingsPath $SettingsPath -StartupTimeoutSeconds $StartupTimeoutSeconds -ServerGui:$ServerGui
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
    $updateRecord = Read-JsonFile $updateRecordPath
    if (-not $updateRecord) { throw 'The update operation record became unreadable during startup verification.' }
    $verificationStatus = [string](Get-OptionalPropertyValue $updateRecord 'status')
    if ($verificationStatus -eq 'installed-not-yet-start-verified') {
        Set-OptionalPropertyValue $updateRecord 'status' 'startup-verified'
        Set-OptionalPropertyValue $updateRecord 'startupVerifiedAt' (Get-Date).ToString('o')
        Write-JsonAtomic $updateRecordPath $updateRecord
    } elseif ($verificationStatus -ne 'startup-verified') {
        throw "The update operation entered unexpected status '$verificationStatus' during startup verification."
    }
    Write-Host "Update-and-start verified Minecraft reached Done. Pre-update backup: $backup"
} catch {
    Write-Warning "Updated server failed startup verification: $($_.Exception.Message)"
    try { & (Join-Path $PSScriptRoot 'Stop-Server.ps1') -ServerRoot $serverRootResolved -SettingsPath $SettingsPath } catch { Write-Warning $_.Exception.Message }
    Send-DiscordServerNotification -ServerRoot $serverRootResolved -Settings $settings -Event failed `
        -Description 'The update installed, but the server did not pass its post-update startup verification. Operator attention is required before rollback or retry.' `
        -Fields @{ 'Installed version' = (Get-CurrentPackVersion $serverRootResolved) }
    Write-Warning "Rollback is operator-controlled. Run: .\Rollback-ServerUpdate.ps1 -BackupPath `"$backup`" -ServerRoot `"$serverRootResolved`" -StartAfterRollback"
    throw
}
