[CmdletBinding()]
param(
    [string]$ServerRoot,
    [string]$PackUrl,
    [string]$JavaPath,
    [string]$SettingsPath,
    [string]$ExistingBackupPath
)

. (Join-Path $PSScriptRoot 'Common.ps1')
. (Join-Path $PSScriptRoot 'Discord-Notifications.ps1')
$serverRootResolved = Assert-ValidServerRoot (Resolve-ServerRoot $ServerRoot)
Assert-ServerStopped $serverRootResolved
$settings = Get-ServerSettings -ServerRoot $serverRootResolved -SettingsPath $SettingsPath -PackUrl $PackUrl
$PackUrl = [string]$settings.packUrl
if (-not $PackUrl -or $PackUrl -match 'REPLACE_WITH_') { throw 'Set the real repository URL before updating the server.' }
if ($PackUrl -notmatch '^https://') { throw 'Production server updates require an HTTPS Packwiz URL.' }
$java = Find-Java17 $JavaPath

$backupPath = $ExistingBackupPath
if (-not $backupPath) {
    $backupPath = & (Join-Path $PSScriptRoot 'Backup-Server.ps1') -ServerRoot $serverRootResolved -SettingsPath $SettingsPath
}
$backupPath = [IO.Path]::GetFullPath($backupPath)
$backupValidation = & (Join-Path $PSScriptRoot 'Test-ServerBackup.ps1') -BackupPath $backupPath -PassThru
if (-not $backupValidation.valid) { throw 'A complete, verified cold backup is required before updating.' }
$priorVersion = Get-CurrentPackVersion $serverRootResolved

$managementRoot = Get-ManagementRoot $serverRootResolved
New-Item -ItemType Directory -Path $managementRoot -Force | Out-Null
$before = [ordered]@{
    recordedAt = (Get-Date).ToString('o')
    packUrl = $PackUrl
    priorVersion = $priorVersion
    priorPackwizStateSha256 = if (Test-Path -LiteralPath (Join-Path $serverRootResolved 'packwiz.json')) { (Get-FileHash -LiteralPath (Join-Path $serverRootResolved 'packwiz.json') -Algorithm SHA256).Hash.ToLowerInvariant() } else { $null }
    rollbackBackup = $backupPath
    status = 'update-starting'
}
$updateRecord = Join-Path $managementRoot ("update-{0}.json" -f (Get-Date -Format 'yyyyMMdd-HHmmss'))
Write-JsonAtomic $updateRecord $before

Send-DiscordServerNotification -ServerRoot $serverRootResolved -Settings $settings -Event updating `
    -Description 'A protected Packwiz server update has started. Minecraft is stopped and a verified cold backup exists.' `
    -Fields @{ 'Previous version' = $priorVersion }

try {
$bootstrapVersion = 'v0.0.3'
$bootstrapExpectedSha256 = 'a8fbb24dc604278e97f4688e82d3d91a318b98efc08d5dbfcbcbcab6443d116c'
$bootstrapUrl = "https://github.com/packwiz/packwiz-installer-bootstrap/releases/download/$bootstrapVersion/packwiz-installer-bootstrap.jar"
$bootstrap = Join-Path $serverRootResolved 'packwiz-installer-bootstrap.jar'
if (-not (Test-Path -LiteralPath $bootstrap) -or (Get-FileHash -LiteralPath $bootstrap -Algorithm SHA256).Hash.ToLowerInvariant() -ne $bootstrapExpectedSha256) {
    $temporary = "$bootstrap.download"
    Invoke-WebRequest -Uri $bootstrapUrl -OutFile $temporary -UseBasicParsing
    $actual = (Get-FileHash -LiteralPath $temporary -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($actual -ne $bootstrapExpectedSha256) { Remove-Item -LiteralPath $temporary -Force; throw 'Packwiz bootstrap SHA-256 validation failed.' }
    Move-Item -LiteralPath $temporary -Destination $bootstrap -Force
}

$installerVersion = 'v0.5.14'
$installerExpectedSha256 = 'c9f646908d340d84773948a9a7d98bc1dae250d35e1016dc6e2b8459760b5598'
$installerUrl = "https://github.com/packwiz/packwiz-installer/releases/download/$installerVersion/packwiz-installer.jar"
$installer = Join-Path $serverRootResolved 'packwiz-installer.jar'
if (-not (Test-Path -LiteralPath $installer) -or (Get-FileHash -LiteralPath $installer -Algorithm SHA256).Hash.ToLowerInvariant() -ne $installerExpectedSha256) {
    $temporary = "$installer.download"
    Invoke-WebRequest -Uri $installerUrl -OutFile $temporary -UseBasicParsing
    $actual = (Get-FileHash -LiteralPath $temporary -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($actual -ne $installerExpectedSha256) { Remove-Item -LiteralPath $temporary -Force; throw 'Packwiz installer SHA-256 validation failed.' }
    Move-Item -LiteralPath $temporary -Destination $installer -Force
}

Write-Host "Applying operator-approved Packwiz server update from $PackUrl"
$exitCode = -1
Push-Location $serverRootResolved
try {
    & $java -jar $bootstrap --bootstrap-no-update --bootstrap-main-jar 'packwiz-installer.jar' -g -s server $PackUrl 2>&1 | ForEach-Object { Write-Host $_ }
    $exitCode = $LASTEXITCODE
} finally { Pop-Location }

if ($exitCode -ne 0) {
    $before.status = 'installer-failed-restoring-managed-files'
    Write-JsonAtomic $updateRecord $before
    Write-Warning "Packwiz update failed with exit code $exitCode. Restoring only the previous managed files from the verified backup."
    & (Join-Path $PSScriptRoot 'Restore-ServerBackup.ps1') -BackupPath $backupPath -ServerRoot $serverRootResolved -SettingsPath $SettingsPath -Confirm:$false
    $before.status = 'installer-failed-managed-files-restored'
    Write-JsonAtomic $updateRecord $before
    throw "Server update failed and managed files were rolled back. Backup retained: $backupPath"
}

& (Join-Path $PSScriptRoot 'Test-ServerInstallation.ps1') -ServerRoot $serverRootResolved | Out-Null
$packText = (Invoke-WebRequest -Uri $PackUrl -UseBasicParsing -TimeoutSec 30).Content
$versionMatch = [regex]::Match($packText, '(?m)^version\s*=\s*"([^"]+)"')
$version = if ($versionMatch.Success) { $versionMatch.Groups[1].Value } else { 'unknown' }
$current = [ordered]@{
    version = $version
    packUrl = $PackUrl
    installedAt = (Get-Date).ToString('o')
    packwizStateSha256 = (Get-FileHash -LiteralPath (Join-Path $serverRootResolved 'packwiz.json') -Algorithm SHA256).Hash.ToLowerInvariant()
    rollbackBackup = $backupPath
    updateRecord = $updateRecord
}
Write-JsonAtomic (Join-Path $managementRoot 'current-version.json') $current
$before.status = 'installed-not-yet-start-verified'
$before.installedVersion = $version
$before.completedAt = (Get-Date).ToString('o')
Write-JsonAtomic $updateRecord $before
Write-Host "Server update installed and structurally validated. Version=$version. Backup retained: $backupPath"
Send-DiscordServerNotification -ServerRoot $serverRootResolved -Settings $settings -Event updated `
    -Description 'The managed server files were updated and structurally validated. Runtime verification occurs when the server next reaches Done.' `
    -Fields @{ 'Previous version' = $priorVersion; 'Installed version' = $version }
return $backupPath
} catch {
    $failure = $_
    $stage = if ($before.status) { [string]$before.status } else { 'unknown' }
    if ($stage -eq 'update-starting') { $before.status = 'update-failed' }
    elseif ($stage -eq 'installed-not-yet-start-verified') { $before.status = 'post-install-validation-failed' }
    $before.failedAt = (Get-Date).ToString('o')
    $before.failureType = $failure.Exception.GetType().Name
    try { Write-JsonAtomic $updateRecord $before } catch { }
    $terminalStage = if ($before.status) { [string]$before.status } else { $stage }
    Send-DiscordServerNotification -ServerRoot $serverRootResolved -Settings $settings -Event failed `
        -Description 'The protected server update did not complete. Check the local update record and retained verified backup before retrying.' `
        -Fields @{ 'Previous version' = $priorVersion; Stage = $terminalStage }
    throw $failure
}
