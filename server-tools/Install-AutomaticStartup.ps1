[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$ServerRoot,
    [string]$SettingsPath,
    [switch]$IncludeDailyBackup,
    [switch]$GenerateOnly,
    [string]$OutputDirectory
)

. (Join-Path $PSScriptRoot 'Common.ps1')
$root = Assert-ValidServerRoot (Resolve-ServerRoot $ServerRoot)
$settings = Get-ServerSettings -ServerRoot $root -SettingsPath $SettingsPath
$toolsRoot = $PSScriptRoot
$prefix = [string]$settings.taskNamePrefix
$principal = [Security.Principal.WindowsIdentity]::GetCurrent()
$userSid = $principal.User.Value
if (-not $OutputDirectory) { $OutputDirectory = Join-Path (Get-ManagementRoot $root) 'scheduled-task-preview' }
$OutputDirectory = [IO.Path]::GetFullPath($OutputDirectory)
New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null

function Escape-Xml([string]$Value) { return [Security.SecurityElement]::Escape($Value) }
function New-TaskXml([string]$ScriptPath, [string]$TriggerXml, [string]$Description) {
    $arguments = '-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "{0}" -ServerRoot "{1}"' -f $ScriptPath, $root
    if ($SettingsPath) { $arguments += ' -SettingsPath "{0}"' -f ([IO.Path]::GetFullPath($SettingsPath)) }
    $date = Get-Date -Format s
    return @"
<?xml version="1.0" encoding="UTF-16"?>
<Task version="1.4" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task">
  <RegistrationInfo><Date>$date</Date><Author>MilkyJ Packwiz</Author><Description>$(Escape-Xml $Description)</Description></RegistrationInfo>
  <Triggers>$TriggerXml</Triggers>
  <Principals><Principal id="Author"><UserId>$userSid</UserId><LogonType>S4U</LogonType><RunLevel>HighestAvailable</RunLevel></Principal></Principals>
  <Settings><MultipleInstancesPolicy>IgnoreNew</MultipleInstancesPolicy><DisallowStartIfOnBatteries>false</DisallowStartIfOnBatteries><StopIfGoingOnBatteries>false</StopIfGoingOnBatteries><AllowHardTerminate>false</AllowHardTerminate><StartWhenAvailable>true</StartWhenAvailable><RunOnlyIfNetworkAvailable>true</RunOnlyIfNetworkAvailable><IdleSettings><StopOnIdleEnd>false</StopOnIdleEnd><RestartOnIdle>false</RestartOnIdle></IdleSettings><AllowStartOnDemand>true</AllowStartOnDemand><Enabled>true</Enabled><Hidden>false</Hidden><ExecutionTimeLimit>PT0S</ExecutionTimeLimit><Priority>7</Priority></Settings>
  <Actions Context="Author"><Exec><Command>powershell.exe</Command><Arguments>$(Escape-Xml $arguments)</Arguments><WorkingDirectory>$(Escape-Xml $root)</WorkingDirectory></Exec></Actions>
</Task>
"@
}

$startupName = "$prefix - Startup"
$startupXml = New-TaskXml (Join-Path $toolsRoot 'Start-AutomaticServer.ps1') ('<BootTrigger><Enabled>true</Enabled><Delay>PT{0}S</Delay></BootTrigger>' -f [int]$settings.startupDelaySeconds) 'Starts the supervised Minecraft server after Windows boots. It never applies Packwiz updates.'
$startupPreview = Join-Path $OutputDirectory 'minecraft-startup-task.xml'
[IO.File]::WriteAllText($startupPreview, $startupXml.TrimStart(), [Text.UnicodeEncoding]::new($false, $true))

$tasks = @([pscustomobject]@{ name=$startupName; xml=$startupXml; preview=$startupPreview })
if ($IncludeDailyBackup) {
    $backupName = "$prefix - Daily Backup"
    $backupXml = New-TaskXml (Join-Path $toolsRoot 'Invoke-ScheduledBackup.ps1') '<CalendarTrigger><StartBoundary>2026-01-01T04:00:00</StartBoundary><Enabled>true</Enabled><ScheduleByDay><DaysInterval>1</DaysInterval></ScheduleByDay></CalendarTrigger>' 'Stops the server gracefully if needed, creates and verifies a cold backup, applies retention, then restarts. It never updates mods.'
    $backupPreview = Join-Path $OutputDirectory 'minecraft-daily-backup-task.xml'
    [IO.File]::WriteAllText($backupPreview, $backupXml.TrimStart(), [Text.UnicodeEncoding]::new($false, $true))
    $tasks += [pscustomobject]@{ name=$backupName; xml=$backupXml; preview=$backupPreview }
}

if ($GenerateOnly) {
    Write-Host 'Scheduled-task XML generated only; no task was installed or enabled.'
    $tasks | Select-Object name,preview
    return
}
foreach ($task in $tasks) {
    if ($PSCmdlet.ShouldProcess($task.name, 'Register automatic Minecraft task')) {
        Register-ScheduledTask -TaskName $task.name -Xml $task.xml -Force | Out-Null
        Write-Host "Installed scheduled task: $($task.name)"
    }
}
