[CmdletBinding()]
param([string]$ServerRoot, [switch]$NoOpen)

. (Join-Path $PSScriptRoot 'Common.ps1')
$serverRootResolved = Assert-ValidServerRoot (Resolve-ServerRoot $ServerRoot)
$latest = Join-Path $serverRootResolved 'logs\latest.log'
if (-not (Test-Path -LiteralPath $latest -PathType Leaf)) { throw "Minecraft latest.log does not exist: $latest" }
Write-Host $latest
Get-Content -LiteralPath $latest -Tail 80
if (-not $NoOpen) { Start-Process -FilePath 'notepad.exe' -ArgumentList ('"' + $latest + '"') | Out-Null }
