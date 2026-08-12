[CmdletBinding(SupportsShouldProcess)]
param([string]$ServerRoot, [string]$SettingsPath, [switch]$IncludeDailyBackup)

. (Join-Path $PSScriptRoot 'Common.ps1')
$root = Assert-ValidServerRoot (Resolve-ServerRoot $ServerRoot)
$settings = Get-ServerSettings -ServerRoot $root -SettingsPath $SettingsPath
$names = @("$($settings.taskNamePrefix) - Startup")
if ($IncludeDailyBackup) { $names += "$($settings.taskNamePrefix) - Daily Backup" }
foreach ($name in $names) {
    if (Get-ScheduledTask -TaskName $name -ErrorAction SilentlyContinue) {
        if ($PSCmdlet.ShouldProcess($name, 'Unregister scheduled task')) {
            Unregister-ScheduledTask -TaskName $name -Confirm:$false
            Write-Host "Removed scheduled task: $name"
        }
    } else { Write-Host "Scheduled task is not installed: $name" }
}
