[CmdletBinding()]
param(
    [string]$ProjectRoot,
    [switch]$AllowPlaceholder,
    [switch]$AllowPrivateLan
)

$ErrorActionPreference = 'Stop'
if (-not $ProjectRoot) { $ProjectRoot = Split-Path -Parent $PSScriptRoot }
$python = Get-Command python -ErrorAction SilentlyContinue
if (-not $python) { $python = Get-Command py -ErrorAction SilentlyContinue }
if (-not $python) { throw 'Python 3.11+ is required for strict TOML validation.' }

$arguments = @((Join-Path $PSScriptRoot 'validate_pack.py'), ([IO.Path]::GetFullPath($ProjectRoot)))
if ($AllowPlaceholder) { $arguments += '--allow-placeholder' }
if ($AllowPrivateLan) { $arguments += '--allow-private-lan' }
& $python.Source @arguments
if ($LASTEXITCODE -ne 0) { throw 'Packwiz validation failed.' }
Write-Host 'Packwiz manifest validation passed.'

& $python.Source (Join-Path $PSScriptRoot 'check_encoding.py') ([IO.Path]::GetFullPath($ProjectRoot))
if ($LASTEXITCODE -ne 0) { throw 'UTF-8/mojibake validation failed.' }
Write-Host 'UTF-8/mojibake validation passed.'

$creatorRegistry = Join-Path ([IO.Path]::GetFullPath($ProjectRoot)) 'creator-capture\candidate-registry.json'
if (Test-Path -LiteralPath $creatorRegistry -PathType Leaf) {
    & $python.Source (Join-Path $PSScriptRoot 'validate_creator_capture.py') ([IO.Path]::GetFullPath($ProjectRoot))
    if ($LASTEXITCODE -ne 0) { throw 'Creator Capture fail-closed validation failed.' }
    Write-Host 'Creator Capture fail-closed validation passed.'
} else {
    Write-Host 'Creator Capture validation skipped for this Packwiz-only staging root.'
}
