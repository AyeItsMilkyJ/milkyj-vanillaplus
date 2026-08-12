[CmdletBinding()]
param(
    [string]$ServerRoot,
    [string]$SettingsPath,
    [string]$BackupRoot,
    [Parameter(Mandatory)][string]$NewValidBackup
)

. (Join-Path $PSScriptRoot 'Common.ps1')
$serverRootResolved = Assert-ValidServerRoot (Resolve-ServerRoot $ServerRoot)
$settings = Get-ServerSettings -ServerRoot $serverRootResolved -SettingsPath $SettingsPath
if (-not $BackupRoot) { $BackupRoot = [string]$settings.backupDirectory }
if (-not [IO.Path]::IsPathRooted($BackupRoot)) { $BackupRoot = Join-Path $serverRootResolved $BackupRoot }
$root = [IO.Path]::GetFullPath($BackupRoot)
$newest = [IO.Path]::GetFullPath($NewValidBackup)
if (-not $newest.StartsWith(($root.TrimEnd('\') + '\'), [StringComparison]::OrdinalIgnoreCase)) { throw 'New valid backup is outside the configured backup root.' }
if (-not (Test-Path -LiteralPath "$newest.manifest.json")) { throw 'Retention refused because the new backup has no validation sidecar.' }

$archives = @(Get-ChildItem -LiteralPath $root -File -Filter '*.zip' | Sort-Object LastWriteTimeUtc -Descending)
if ($archives.Count -le 1) { return }
$keep = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
[void]$keep.Add($newest)
$dailyKeys = [Collections.Generic.HashSet[string]]::new()
$weeklyKeys = [Collections.Generic.HashSet[string]]::new()
$calendar = [Globalization.CultureInfo]::InvariantCulture.Calendar
foreach ($archive in $archives) {
    $path = $archive.FullName
    if (-not (Test-Path -LiteralPath "$path.manifest.json")) { [void]$keep.Add($path); continue }
    $dayKey = $archive.LastWriteTime.ToString('yyyy-MM-dd')
    if ($dailyKeys.Count -lt [int]$settings.backupRetentionDaily -and $dailyKeys.Add($dayKey)) { [void]$keep.Add($path) }
    $week = $calendar.GetWeekOfYear($archive.LastWriteTime, [Globalization.CalendarWeekRule]::FirstFourDayWeek, [DayOfWeek]::Monday)
    $weekKey = '{0}-W{1:D2}' -f $archive.LastWriteTime.Year, $week
    if ($weeklyKeys.Count -lt [int]$settings.backupRetentionWeekly -and $weeklyKeys.Add($weekKey)) { [void]$keep.Add($path) }
}
foreach ($archive in $archives) {
    if ($keep.Contains($archive.FullName)) { continue }
    Remove-Item -LiteralPath $archive.FullName -Force
    if (Test-Path -LiteralPath "$($archive.FullName).manifest.json") { Remove-Item -LiteralPath "$($archive.FullName).manifest.json" -Force }
    Write-Host "Retention removed superseded verified backup: $($archive.FullName)"
}
