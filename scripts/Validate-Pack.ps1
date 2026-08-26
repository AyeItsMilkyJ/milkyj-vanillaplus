[CmdletBinding()]
param(
    [string]$ProjectRoot,
    [switch]$AllowPlaceholder,
    [switch]$AllowPrivateLan
)

$ErrorActionPreference = 'Stop'
if (-not $ProjectRoot) { $ProjectRoot = Split-Path -Parent $PSScriptRoot }
$projectRootResolved = [IO.Path]::GetFullPath($ProjectRoot)
$python = Get-Command python -ErrorAction SilentlyContinue
if (-not $python) { $python = Get-Command py -ErrorAction SilentlyContinue }
if (-not $python) { throw 'Python 3.11+ is required for strict TOML validation.' }

$arguments = @((Join-Path $PSScriptRoot 'validate_pack.py'), $projectRootResolved)
if ($AllowPlaceholder) { $arguments += '--allow-placeholder' }
if ($AllowPrivateLan) { $arguments += '--allow-private-lan' }
& $python.Source @arguments
if ($LASTEXITCODE -ne 0) { throw 'Packwiz validation failed.' }
Write-Host 'Packwiz manifest validation passed.'

# The same release number is deliberately repeated in four user-facing places.
# Refuse a complete repository where one was bumped without the others. A few
# disposable tests intentionally materialise only packwiz/ and payload/, so a
# Packwiz-only staging root skips this repository-level assertion.
$projectSettingsPath = Join-Path $projectRootResolved 'project-settings.json'
$instancePath = Join-Path $projectRootResolved 'bootstrap\template\instance.cfg'
if ((Test-Path -LiteralPath $projectSettingsPath -PathType Leaf) -and (Test-Path -LiteralPath $instancePath -PathType Leaf)) {
    $packText = [IO.File]::ReadAllText((Join-Path $projectRootResolved 'packwiz\pack.toml'))
    $packVersionMatch = [regex]::Match($packText, '(?m)^version\s*=\s*"([^"]+)"')
    if (-not $packVersionMatch.Success) { throw 'Packwiz pack.toml has no top-level version.' }
    $projectVersion = [string](Get-Content -LiteralPath $projectSettingsPath -Raw | ConvertFrom-Json).packVersion
    $instanceText = [IO.File]::ReadAllText($instancePath)
    $instanceVersionMatch = [regex]::Match($instanceText, '(?m)^ExportVersion=([^\r\n]+)$')
    if (-not $instanceVersionMatch.Success) { throw 'Prism instance template has no ExportVersion.' }
    $controlsVersion = [string](Get-Content -LiteralPath (Join-Path $projectRootResolved 'payload\client\scripts\milkycraft-controls\recommended-controls.json') -Raw | ConvertFrom-Json).packVersion
    $versions = [ordered]@{
        'packwiz/pack.toml' = $packVersionMatch.Groups[1].Value
        'project-settings.json' = $projectVersion
        'bootstrap/template/instance.cfg' = $instanceVersionMatch.Groups[1].Value.Trim()
        'recommended-controls.json' = $controlsVersion
    }
    $uniqueVersions = @($versions.Values | Select-Object -Unique)
    if ($uniqueVersions.Count -ne 1 -or [string]::IsNullOrWhiteSpace([string]$uniqueVersions[0])) {
        $details = @($versions.GetEnumerator() | ForEach-Object { "$($_.Key)=$($_.Value)" }) -join '; '
        throw "Release-version metadata is out of sync: $details"
    }
    Write-Host "Release-version parity passed ($($uniqueVersions[0]))."
} elseif ((Test-Path -LiteralPath $projectSettingsPath) -or (Test-Path -LiteralPath $instancePath)) {
    throw 'Repository-level release-version metadata is incomplete.'
} else {
    Write-Host 'Release-version parity skipped for this Packwiz-only staging root.'
}

& $python.Source (Join-Path $PSScriptRoot 'check_encoding.py') $projectRootResolved
if ($LASTEXITCODE -ne 0) { throw 'UTF-8/mojibake validation failed.' }
Write-Host 'UTF-8/mojibake validation passed.'

$creatorRegistry = Join-Path $projectRootResolved 'creator-capture\candidate-registry.json'
if (Test-Path -LiteralPath $creatorRegistry -PathType Leaf) {
    & $python.Source (Join-Path $PSScriptRoot 'validate_creator_capture.py') $projectRootResolved
    if ($LASTEXITCODE -ne 0) { throw 'Creator Capture fail-closed validation failed.' }
    Write-Host 'Creator Capture fail-closed validation passed.'
} else {
    Write-Host 'Creator Capture validation skipped for this Packwiz-only staging root.'
}
