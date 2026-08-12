[CmdletBinding()]
param(
    [string]$ProjectRoot = (Split-Path -Parent $PSScriptRoot),
    [switch]$AllowPlaceholder
)

$ErrorActionPreference = 'Stop'
$python = Get-Command python -ErrorAction SilentlyContinue
if (-not $python) { $python = Get-Command py -ErrorAction SilentlyContinue }
if (-not $python) { throw 'Python 3.11+ is required for strict TOML validation.' }

$arguments = @((Join-Path $PSScriptRoot 'validate_pack.py'), ([IO.Path]::GetFullPath($ProjectRoot)))
if ($AllowPlaceholder) { $arguments += '--allow-placeholder' }
& $python.Source @arguments
if ($LASTEXITCODE -ne 0) { throw 'Packwiz validation failed.' }
Write-Host 'Packwiz manifest validation passed.'

