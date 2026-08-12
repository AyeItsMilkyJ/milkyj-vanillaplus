[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
param(
    [Parameter(Mandatory)][string]$ProductionServerRoot,
    [Parameter(Mandatory)][string]$ProductionWorldName,
    [Parameter(Mandatory)][int]$StoppedProductionServerPid,
    [string]$ProjectRoot = (Split-Path -Parent $PSScriptRoot)
)

$ErrorActionPreference = 'Stop'
$root = [IO.Path]::GetFullPath($ProjectRoot)
$production = [IO.Path]::GetFullPath($ProductionServerRoot)
$sourceWorld = [IO.Path]::GetFullPath((Join-Path $production $ProductionWorldName))
$testRoot = [IO.Path]::GetFullPath((Join-Path $root 'build\copied-world-rc-test'))
$destination = [IO.Path]::GetFullPath((Join-Path $testRoot 'server\copied_rc_world'))
if (-not $destination.StartsWith(($testRoot.TrimEnd('\') + '\'), [StringComparison]::OrdinalIgnoreCase)) { throw 'Disposable destination escaped its guarded test root.' }
if ($destination.Equals($sourceWorld, [StringComparison]::OrdinalIgnoreCase)) { throw 'The disposable destination cannot equal the production world.' }
if (-not (Test-Path -LiteralPath $sourceWorld -PathType Container)) { throw "Stopped production world not found: $sourceWorld" }
if (Get-Process -Id $StoppedProductionServerPid -ErrorAction SilentlyContinue) { throw "Production server PID $StoppedProductionServerPid is still running." }
if (Get-NetTCPConnection -State Listen -LocalPort 25565 -ErrorAction SilentlyContinue) { throw 'Port 25565 is still listening; stop the production server before taking a snapshot.' }
if (Test-Path -LiteralPath (Join-Path $sourceWorld 'session.lock')) {
    try {
        $stream = [IO.File]::Open((Join-Path $sourceWorld 'session.lock'), 'Open', 'ReadWrite', 'None'); $stream.Dispose()
    } catch { throw 'The production world session lock is still held.' }
}

$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$backupRoot = Join-Path $production 'backups'
$backup = Join-Path $backupRoot "pre-rc-copy-$stamp.zip"
if (-not $PSCmdlet.ShouldProcess($sourceWorld, "create backup $backup and disposable copy $destination")) { return }
New-Item -ItemType Directory -Path $backupRoot -Force | Out-Null
Compress-Archive -LiteralPath $sourceWorld -DestinationPath $backup -CompressionLevel Optimal
if (-not (Test-Path -LiteralPath $backup -PathType Leaf)) { throw 'Timestamped production backup was not created.' }
if (Test-Path -LiteralPath $testRoot) { Remove-Item -LiteralPath $testRoot -Recurse -Force }
New-Item -ItemType Directory -Path (Split-Path -Parent $destination) -Force | Out-Null
Copy-Item -LiteralPath $sourceWorld -Destination $destination -Recurse
$manifest = [ordered]@{
    preparedAt = (Get-Date).ToString('o'); sourceWasStopped = $true; stoppedPid = $StoppedProductionServerPid
    timestampedBackup = $backup; disposableWorld = $destination; requiredRcPort = 25566
    productionWorldModified = $false; rcLaunchedAgainstProductionPath = $false
}
[IO.File]::WriteAllText((Join-Path $testRoot 'snapshot.json'), (($manifest | ConvertTo-Json) + "`r`n"), [Text.UTF8Encoding]::new($false))
Write-Host "Backup created: $backup"
Write-Host "Disposable copied world: $destination"
Write-Host 'Restart the unchanged stable production server separately, then follow docs/COPIED-WORLD-RC-TEST.md.'
