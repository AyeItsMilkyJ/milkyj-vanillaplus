[CmdletBinding()]
param(
    [string]$ProjectRoot = (Split-Path -Parent $PSScriptRoot),
    [string]$ShaderSourceDirectory = "$env:APPDATA\PrismLauncher\instances\Premium Modpack DEV\minecraft\shaderpacks",
    [Parameter(Mandatory = $true)]
    [string]$ServerAddress,
    [ValidateRange(1, 65535)]
    [int]$ServerPort = 25565,
    [ValidateRange(5, 10080)]
    [int]$RestartIntervalMinutes = 180,
    [string]$OutputPath
)

$ErrorActionPreference = 'Stop'
$root = [IO.Path]::GetFullPath($ProjectRoot)
$settings = Get-Content -LiteralPath (Join-Path $root 'project-settings.json') -Raw | ConvertFrom-Json
if (-not $OutputPath) {
    $OutputPath = Join-Path $root ("dist\MilkyJ-VanillaPlus-{0}-MATES-AUTO-UPDATING.zip" -f $settings.packVersion)
}
$output = [IO.Path]::GetFullPath($OutputPath)
$buildRoot = Join-Path $root 'build\mate-distribution'
$stage = Join-Path $buildRoot 'stage'
$temporaryBootstrap = Join-Path $buildRoot 'bootstrap.zip'
$minecraft = Join-Path $stage 'minecraft'
$shaderDestination = Join-Path $minecraft 'shaderpacks'

if (-not $buildRoot.StartsWith(($root.TrimEnd('\') + '\'), [StringComparison]::OrdinalIgnoreCase)) {
    throw "Unsafe build directory: $buildRoot"
}
if (Test-Path -LiteralPath $buildRoot) {
    Remove-Item -LiteralPath $buildRoot -Recurse -Force
}
New-Item -ItemType Directory -Path $stage, $shaderDestination, (Split-Path -Parent $output) -Force | Out-Null

& (Join-Path $PSScriptRoot 'Build-Prism-Bootstrap.ps1') `
    -ProjectRoot $root `
    -OutputPath $temporaryBootstrap
if (-not (Test-Path -LiteralPath $temporaryBootstrap -PathType Leaf)) {
    throw 'The base Prism bootstrap build did not create its output ZIP.'
}

Add-Type -AssemblyName System.IO.Compression.FileSystem
Add-Type -AssemblyName System.IO.Compression
[IO.Compression.ZipFile]::ExtractToDirectory($temporaryBootstrap, $stage)

$shaderNames = @(
    'Bloop-1.8.0-Alpha-3.zip',
    'BSL_v10.1.3.zip',
    'daybreak_0.2 .zip',
    'HyShaders Vanilla Lite 3.0.zip',
    'Hysteria-Shaders-Universal-v1.2.1.zip',
    'MakeUp-UltraFast-9.5c.zip',
    'NeonSkylines.2.3.zip',
    "Sildur's Enhanced Default v1.19 Fancy.zip",
    'Solas Shader V3.7.zip',
    'TAA 3.7.6.zip'
)
foreach ($name in $shaderNames) {
    $source = Join-Path $ShaderSourceDirectory $name
    if (-not (Test-Path -LiteralPath $source -PathType Leaf)) {
        throw "Required shader archive is missing: $source"
    }
    Copy-Item -LiteralPath $source -Destination (Join-Path $shaderDestination $name)

    $settingsSidecar = "$source.txt"
    if (Test-Path -LiteralPath $settingsSidecar -PathType Leaf) {
        Copy-Item -LiteralPath $settingsSidecar -Destination (Join-Path $shaderDestination "$name.txt")
    }
}

$restartHours = [math]::Round($RestartIntervalMinutes / 60, 2)
$serverInfo = @"
MILKYJ VANILLA+ — MATE SETUP

Minecraft: $($settings.minecraftVersion)
Forge: $($settings.forgeVersion)
Pack: $($settings.packVersion)
Server: ${ServerAddress}:$ServerPort

INSTALL ONCE
1. Open Prism Launcher.
2. Select Add Instance, then Import.
3. Browse to this ZIP itself. Do not unzip it.
4. Sign into Minecraft and press Play.
5. The first launch downloads the managed pack. Later launches download only changes.

SERVER RESTARTS
The server restarts cleanly every $RestartIntervalMinutes minutes ($restartHours hours), counted from when startup reaches Done.
Warnings appear in chat before a restart. Wait about a minute, then reconnect.

SHADERS
Ten shader choices are included but none is forced. Open Options > Video Settings > Shader Packs.
Low-cost choices: MakeUp Ultra Fast, HyShaders Vanilla Lite, Sildur's Enhanced Default.
Balanced/showcase choice: BSL. Distant-Horizons-focused choice: TAA.
If a shader misbehaves on a particular GPU, switch shaders before changing pack files.

MEMORY
The shared instance allows 4–8 GB. Do not allocate nearly all of the computer's RAM.

The installer does not contain accounts, tokens, worlds, saves, screenshots, logs, keybinds, or personal shader selection/settings.
"@
[IO.File]::WriteAllText(
    (Join-Path $minecraft 'README-MILKYJ-MATES.txt'),
    $serverInfo,
    [Text.UTF8Encoding]::new($false)
)
$serverInfoOutput = Join-Path (Split-Path -Parent $output) 'SERVER-INFO-FOR-MATES.txt'
[IO.File]::WriteAllText($serverInfoOutput, $serverInfo, [Text.UTF8Encoding]::new($false))
Copy-Item -LiteralPath (Join-Path $root 'docs\PLAYER-FEATURES-AND-CHANGELOG.md') `
    -Destination (Join-Path $minecraft 'MILKYJ-FEATURES-AND-UPDATES.md')
$featuresOutput = Join-Path (Split-Path -Parent $output) 'MILKYJ-FEATURES-AND-UPDATES.md'
$promptOutput = Join-Path (Split-Path -Parent $output) 'CHATGPT-CLASSIC-MODPACK-PAGE-PROMPT.md'
Copy-Item -LiteralPath (Join-Path $root 'docs\PLAYER-FEATURES-AND-CHANGELOG.md') -Destination $featuresOutput -Force
Copy-Item -LiteralPath (Join-Path $root 'docs\CHATGPT-CLASSIC-MODPACK-PAGE-PROMPT.md') -Destination $promptOutput -Force

if (Test-Path -LiteralPath $output) {
    Remove-Item -LiteralPath $output -Force
}
$archive = [IO.Compression.ZipFile]::Open($output, [IO.Compression.ZipArchiveMode]::Create)
try {
    $prefix = [IO.Path]::GetFullPath($stage).TrimEnd('\') + '\'
    foreach ($file in Get-ChildItem -LiteralPath $stage -Recurse -File) {
        $entryName = [IO.Path]::GetFullPath($file.FullName).Substring($prefix.Length).Replace('\', '/')
        [void][IO.Compression.ZipFileExtensions]::CreateEntryFromFile(
            $archive,
            $file.FullName,
            $entryName,
            [IO.Compression.CompressionLevel]::Optimal
        )
    }
} finally {
    $archive.Dispose()
}

$archive = [IO.Compression.ZipFile]::OpenRead($output)
try {
    $entries = @($archive.Entries.FullName)
    foreach ($required in @(
        'instance.cfg',
        'mmc-pack.json',
        'minecraft/packwiz-installer-bootstrap.jar',
        'minecraft/README-MILKYJ-MATES.txt',
        'minecraft/MILKYJ-FEATURES-AND-UPDATES.md'
    )) {
        if ($required -notin $entries) { throw "Mate ZIP is missing $required" }
    }
    $shaderCount = @($entries | Where-Object { $_ -match '^minecraft/shaderpacks/.+\.zip$' }).Count
    if ($shaderCount -ne 10) { throw "Expected 10 shader archives; packaged $shaderCount." }
    $forbidden = @($entries | Where-Object {
        $_ -match '(?i)(^|/)(options(?:shaders)?\.txt|servers\.dat|accounts\.json|saves|screenshots|logs|crash-reports)(/|$)'
    })
    if ($forbidden.Count -gt 0) {
        throw "Personal files entered the mate ZIP: $($forbidden -join ', ')"
    }
} finally {
    $archive.Dispose()
}

$result = [ordered]@{
    status = 'PASS'
    output = $output
    serverInfo = $serverInfoOutput
    featureHistory = $featuresOutput
    chatGptClassicPrompt = $promptOutput
    sizeMiB = [math]::Round((Get-Item -LiteralPath $output).Length / 1MB, 2)
    sha256 = (Get-FileHash -LiteralPath $output -Algorithm SHA256).Hash.ToLowerInvariant()
    packVersion = $settings.packVersion
    packUrl = $settings.packUrl
    server = "${ServerAddress}:$ServerPort"
    restartIntervalMinutes = $RestartIntervalMinutes
    shaderArchives = 10
    personalFilesIncluded = $false
}
$result | ConvertTo-Json -Depth 4
