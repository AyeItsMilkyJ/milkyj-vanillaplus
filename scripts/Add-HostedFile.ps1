[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$SourcePath,
    [Parameter(Mandatory)][ValidatePattern('^(config|defaultconfigs|kubejs|scripts|resourcepacks|moonlight-global-datapacks)/')][string]$DestinationPath,
    [Parameter(Mandatory)][ValidateSet('client','server','both')][string]$Side,
    [string]$ProjectRoot
)

$ErrorActionPreference = 'Stop'
if (-not $ProjectRoot) { $ProjectRoot = Split-Path -Parent $PSScriptRoot }
$projectRootResolved = [IO.Path]::GetFullPath($ProjectRoot)
$sourceResolved = [IO.Path]::GetFullPath($SourcePath)
if (-not (Test-Path -LiteralPath $sourceResolved -PathType Leaf)) { throw "Source file not found: $sourceResolved" }
$destinationNormal = $DestinationPath.Replace('\','/').TrimStart('/')
$parts = $destinationNormal -split '/'
$category = $parts[0]
$withinCategory = ($parts[1..($parts.Length - 1)] -join '/')
$payloadRelative = "$Side/$destinationNormal"
$payloadPath = Join-Path (Join-Path $projectRootResolved 'payload') ($payloadRelative.Replace('/','\'))
$metadataPath = Join-Path (Join-Path $projectRootResolved 'packwiz') (($destinationNormal + '.pw.toml').Replace('/','\'))
$settings = Get-Content -LiteralPath (Join-Path $projectRootResolved 'project-settings.json') -Raw | ConvertFrom-Json
$encodedPath = (($payloadRelative -split '/') | ForEach-Object { [Uri]::EscapeDataString($_) }) -join '/'
$url = ([string]$settings.rawRepositoryBaseUrl).TrimEnd('/') + '/payload/' + $encodedPath

New-Item -ItemType Directory -Path (Split-Path -Parent $payloadPath), (Split-Path -Parent $metadataPath) -Force | Out-Null
Copy-Item -LiteralPath $sourceResolved -Destination $payloadPath -Force
$hash = (Get-FileHash -LiteralPath $payloadPath -Algorithm SHA256).Hash.ToLowerInvariant()
function Quote([string]$Value) { '"' + $Value.Replace('\','\\').Replace('"','\"') + '"' }
$metadata = @(
    "name = $(Quote "Managed ${category}: $withinCategory")",
    "filename = $(Quote ([IO.Path]::GetFileName($withinCategory)) )",
    "side = $(Quote $Side)",
    '',
    '[download]',
    "url = $(Quote $url)",
    'hash-format = "sha256"',
    "hash = $(Quote $hash)"
) -join "`n"
[IO.File]::WriteAllText($metadataPath, ($metadata + "`n"), [Text.UTF8Encoding]::new($false))
& (Join-Path $PSScriptRoot 'Update-PackMetadata.ps1') -ProjectRoot $projectRootResolved
Write-Host "Added hosted $Side file: $destinationNormal"

