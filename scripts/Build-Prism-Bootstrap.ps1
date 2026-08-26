[CmdletBinding()]
param(
    [string]$ProjectRoot,
    [string]$PackUrl,
    [string]$OutputPath,
    [switch]$AllowPlaceholder,
    [switch]$AllowPrivateLan
)

$ErrorActionPreference = 'Stop'
if (-not $ProjectRoot) { $ProjectRoot = Split-Path -Parent $PSScriptRoot }
$projectRootResolved = [IO.Path]::GetFullPath($ProjectRoot)
$settings = Get-Content -LiteralPath (Join-Path $projectRootResolved 'project-settings.json') -Raw | ConvertFrom-Json
if (-not $PackUrl) { $PackUrl = $settings.packUrl }
$packUri = [Uri]$PackUrl
$isLoopback = $packUri.Scheme -eq 'http' -and $packUri.Host -eq '127.0.0.1'
$isPrivateLan = $false
if ($AllowPrivateLan -and $packUri.Scheme -eq 'http') {
    $address = $null
    if ([Net.IPAddress]::TryParse($packUri.Host, [ref]$address) -and $address.AddressFamily -eq [Net.Sockets.AddressFamily]::InterNetwork) {
        $bytes = $address.GetAddressBytes()
        $isPrivateLan = ($bytes[0] -eq 10) -or ($bytes[0] -eq 172 -and $bytes[1] -ge 16 -and $bytes[1] -le 31) -or ($bytes[0] -eq 192 -and $bytes[1] -eq 168)
    }
}
if ($packUri.Scheme -ne 'https' -and -not $isLoopback -and -not $isPrivateLan) {
    throw 'PackUrl must be HTTPS, loopback HTTP, or explicitly allowed RFC1918 LAN HTTP.'
}
if (-not $AllowPlaceholder -and $PackUrl -match 'REPLACE_WITH_') {
    throw 'Set the real repository URL with Set-PackUrl.ps1 before building the player bootstrap.'
}
if (-not $OutputPath) {
    $OutputPath = Join-Path $projectRootResolved 'dist\MilkyCraft-VanillaPlus-AutoUpdating-Prism.zip'
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
    ('PreLaunchCommand=\"$INST_JAVA\" -jar packwiz-installer-bootstrap.jar ' + $PackUrl)
)
$instanceTemplate = [regex]::Replace(
    $instanceTemplate,
    '(?m)^ExportVersion=.*$',
    ('ExportVersion=' + [string]$settings.packVersion)
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

    $instanceEntry = $archive.GetEntry('instance.cfg')
    $reader = [IO.StreamReader]::new($instanceEntry.Open(), [Text.UTF8Encoding]::new($false))
    try { $generatedInstance = $reader.ReadToEnd() } finally { $reader.Dispose() }
    $preLaunch = [regex]::Match($generatedInstance, '(?m)^PreLaunchCommand=(.*)$').Groups[1].Value
    if ($preLaunch -ne ('\"$INST_JAVA\" -jar packwiz-installer-bootstrap.jar ' + $PackUrl)) {
        throw "Generated Prism pre-launch command is malformed: $preLaunch"
    }
    if ($preLaunch -match '(?i)(?:javaw?\.exe|\$INST_JAVA)-jar') {
        throw "Generated Prism pre-launch command concatenates Java and -jar: $preLaunch"
    }
    $exportVersion = [regex]::Match($generatedInstance, '(?m)^ExportVersion=(.*)$').Groups[1].Value
    if ($exportVersion -ne [string]$settings.packVersion) {
        throw "Generated Prism export version '$exportVersion' does not match project version '$($settings.packVersion)'."
    }
} finally {
    $archive.Dispose()
}

Write-Host "Created one-time Prism import: $outputResolved"
Write-Host "Pre-launch updater URL: $PackUrl"
