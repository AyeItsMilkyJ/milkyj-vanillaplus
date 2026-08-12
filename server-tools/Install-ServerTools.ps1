[CmdletBinding()]
param([string]$ServerRoot)

. (Join-Path $PSScriptRoot 'Common.ps1')
$serverRootResolved = Assert-ValidServerRoot (Resolve-ServerRoot $ServerRoot)
$destination = Join-Path $serverRootResolved 'packwiz-tools'
New-Item -ItemType Directory -Path $destination -Force | Out-Null
foreach ($file in Get-ChildItem -LiteralPath $PSScriptRoot -File) {
    if ($file.Name -eq 'Install-ServerTools.ps1') { continue }
    Copy-Item -LiteralPath $file.FullName -Destination (Join-Path $destination $file.Name) -Force
}
Write-Host "Installed Packwiz server tools without touching the running server or world: $destination"

