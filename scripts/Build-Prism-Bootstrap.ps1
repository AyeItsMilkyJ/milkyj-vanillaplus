[CmdletBinding()]
param(
    [string]$ProjectRoot = (Split-Path -Parent $PSScriptRoot),
    [string]$PackUrl,
    [string]$OutputPath,
    [switch]$AllowPlaceholder
)

$ErrorActionPreference = 'Stop'
$projectRootResolved = [IO.Path]::GetFullPath($ProjectRoot)
$settings = Get-Content -LiteralPath (Join-Path $projectRootResolved 'project-settings.json') -Raw | ConvertFrom-Json
if (-not $PackUrl) { $PackUrl = $settings.packUrl }
if (-not $PackUrl.StartsWith('https://') -and -not $PackUrl.StartsWith('http://127.0.0.1')) {
    throw 'PackUrl must be HTTPS (or local loopback for validation).'
}
if (-not $AllowPlaceholder -and $PackUrl -match 'REPLACE_WITH_') {
    throw 'Set the real repository URL with Set-PackUrl.ps1 before building the player bootstrap.'
}
if (-not $OutputPath) {
    $OutputPath = Join-Path $projectRootResolved 'dist\MilkyJ-VanillaPlus-AutoUpdating-Prism.zip'
}
$outputResolved = [IO.Path]::GetFullPath($OutputPath)
$buildRoot = Join-Path $projectRootResolved 'build\prism-bootstrap'
$minecraftDirectory = Join-Path $buildRoot 'minecraft'

if ($buildRoot -notlike "$projectRootResolved*") {
    throw "Unsafe build path: $buildRoot"
}
if (Test-Path -LiteralPath $buildRoot) {
    Remove-Item -LiteralPath $buildRoot -Recurse -Force
}
New-Item -ItemType Directory -Path $minecraftDirectory -Force | Out-Null
New-Item -ItemType Directory -Path (Split-Path -Parent $outputResolved) -Force | Out-Null

Copy-Item -LiteralPath (Join-Path $projectRootResolved 'bootstrap\template\mmc-pack.json') -Destination (Join-Path $buildRoot 'mmc-pack.json')
$instanceTemplate = Get-Content -LiteralPath (Join-Path $projectRootResolved 'bootstrap\template\instance.cfg') -Raw
$instanceTemplate = [regex]::Replace(
    $instanceTemplate,
    '(?m)^PreLaunchCommand=.*$',
    ('PreLaunchCommand="$INST_JAVA" -jar packwiz-installer-bootstrap.jar ' + $PackUrl)
)
[IO.File]::WriteAllText((Join-Path $buildRoot 'instance.cfg'), $instanceTemplate, [Text.UTF8Encoding]::new($false))

$bootstrapJar = & (Join-Path $PSScriptRoot 'Get-PackwizInstaller.ps1') -ProjectRoot $projectRootResolved -PassThru
Copy-Item -LiteralPath $bootstrapJar -Destination (Join-Path $minecraftDirectory 'packwiz-installer-bootstrap.jar')

if (Test-Path -LiteralPath $outputResolved) {
    Remove-Item -LiteralPath $outputResolved -Force
}
Add-Type -AssemblyName System.IO.Compression.FileSystem
Add-Type -AssemblyName System.IO.Compression
$archive = [IO.Compression.ZipFile]::Open($outputResolved, [IO.Compression.ZipArchiveMode]::Create)
try {
    foreach ($file in Get-ChildItem -LiteralPath $buildRoot -Recurse -File) {
        $basePrefix = [IO.Path]::GetFullPath($buildRoot).TrimEnd('\') + '\'
        $entryName = [IO.Path]::GetFullPath($file.FullName).Substring($basePrefix.Length).Replace('\', '/')
        [void][IO.Compression.ZipFileExtensions]::CreateEntryFromFile($archive, $file.FullName, $entryName, [IO.Compression.CompressionLevel]::Optimal)
    }
} finally {
    $archive.Dispose()
}

$archive = [IO.Compression.ZipFile]::OpenRead($outputResolved)
try {
    $entries = @($archive.Entries.FullName)
    foreach ($required in @('instance.cfg', 'mmc-pack.json', 'minecraft/packwiz-installer-bootstrap.jar')) {
        if ($required -notin $entries) { throw "Bootstrap ZIP is missing $required" }
    }
    if ($entries | Where-Object { $_ -match 'options\.txt|servers\.dat|saves/|screenshots/|accounts|token' }) {
        throw 'Bootstrap ZIP unexpectedly contains personal data.'
    }
} finally {
    $archive.Dispose()
}

Write-Host "Created one-time Prism import: $outputResolved"
Write-Host "Pre-launch updater URL: $PackUrl"
