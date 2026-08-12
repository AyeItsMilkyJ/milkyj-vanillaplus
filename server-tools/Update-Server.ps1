[CmdletBinding()]
param(
    [string]$ServerRoot,
    [string]$PackUrl,
    [string]$JavaPath,
    [string]$ExistingBackupPath
)

. (Join-Path $PSScriptRoot 'Common.ps1')
$serverRootResolved = Assert-ValidServerRoot (Resolve-ServerRoot $ServerRoot)
Assert-ServerStopped $serverRootResolved
$serverSettings = Get-ServerSettings $PackUrl
$PackUrl = $serverSettings.PackUrl
if ($PackUrl -match 'REPLACE_WITH_') { throw 'Set the real repository URL before updating the server.' }
$java = Find-Java17 $JavaPath

$backupPath = $ExistingBackupPath
if (-not $backupPath) {
    $backupPath = & (Join-Path $PSScriptRoot 'Backup-Server.ps1') -ServerRoot $serverRootResolved
}
if (-not (Test-Path -LiteralPath (Join-Path $backupPath 'backup-manifest.json'))) { throw "A complete backup is required before updating: $backupPath" }

$bootstrapVersion = 'v0.0.3'
$expectedSha256 = 'a8fbb24dc604278e97f4688e82d3d91a318b98efc08d5dbfcbcbcab6443d116c'
$bootstrapUrl = "https://github.com/packwiz/packwiz-installer-bootstrap/releases/download/$bootstrapVersion/packwiz-installer-bootstrap.jar"
$bootstrap = Join-Path $serverRootResolved 'packwiz-installer-bootstrap.jar'
if (-not (Test-Path -LiteralPath $bootstrap) -or (Get-FileHash -LiteralPath $bootstrap -Algorithm SHA256).Hash.ToLowerInvariant() -ne $expectedSha256) {
    $temporary = "$bootstrap.download"
    Invoke-WebRequest -Uri $bootstrapUrl -OutFile $temporary -UseBasicParsing
    $actual = (Get-FileHash -LiteralPath $temporary -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($actual -ne $expectedSha256) { Remove-Item -LiteralPath $temporary -Force; throw 'Packwiz bootstrap SHA-256 validation failed.' }
    Move-Item -LiteralPath $temporary -Destination $bootstrap -Force
}

Write-Host "Applying Packwiz server update from $PackUrl"
$exitCode = -1
Push-Location $serverRootResolved
try {
    & $java -jar $bootstrap -g -s server $PackUrl 2>&1 | ForEach-Object { Write-Host $_ }
    $exitCode = $LASTEXITCODE
} finally {
    Pop-Location
}
if ($exitCode -ne 0) {
    Write-Warning "Packwiz update failed with exit code $exitCode. Restoring the previous managed files."
    Restore-ManagedFiles $serverRootResolved $backupPath
    throw "Server update failed and was rolled back. Backup retained at $backupPath"
}

Write-Host "Server update succeeded. Backup retained at $backupPath"
return $backupPath
