[CmdletBinding()]
param(
    [string]$ProjectRoot,
    [switch]$PassThru,
    [switch]$MainJarPassThru
)

$ErrorActionPreference = 'Stop'
if (-not $ProjectRoot) { $ProjectRoot = Split-Path -Parent $PSScriptRoot }
$toolDirectory = Join-Path ([IO.Path]::GetFullPath($ProjectRoot)) '.tools'
New-Item -ItemType Directory -Path $toolDirectory -Force | Out-Null
if ($PassThru -and $MainJarPassThru) { throw 'Choose either -PassThru or -MainJarPassThru, not both.' }

if ($MainJarPassThru) {
    $mainVersion = 'v0.5.14'
    $mainExpectedSha256 = 'c9f646908d340d84773948a9a7d98bc1dae250d35e1016dc6e2b8459760b5598'
    $mainUrl = "https://github.com/packwiz/packwiz-installer/releases/download/$mainVersion/packwiz-installer.jar"
    $mainDestination = Join-Path $toolDirectory "packwiz-installer-$mainVersion.jar"
    if (Test-Path -LiteralPath $mainDestination) {
        $mainActual = (Get-FileHash -LiteralPath $mainDestination -Algorithm SHA256).Hash.ToLowerInvariant()
        if ($mainActual -ne $mainExpectedSha256) { throw "Existing Packwiz installer failed SHA-256 validation: $mainDestination" }
    } else {
        $mainTemporary = "$mainDestination.download"
        Invoke-WebRequest -Uri $mainUrl -OutFile $mainTemporary -UseBasicParsing
        $mainActual = (Get-FileHash -LiteralPath $mainTemporary -Algorithm SHA256).Hash.ToLowerInvariant()
        if ($mainActual -ne $mainExpectedSha256) {
            Remove-Item -LiteralPath $mainTemporary -Force
            throw "Downloaded Packwiz installer failed SHA-256 validation. Expected $mainExpectedSha256, got $mainActual."
        }
        Move-Item -LiteralPath $mainTemporary -Destination $mainDestination
    }
    Write-Host "Verified Packwiz installer $mainVersion."
    return $mainDestination
}

$version = 'v0.0.3'
$expectedSha256 = 'a8fbb24dc604278e97f4688e82d3d91a318b98efc08d5dbfcbcbcab6443d116c'
$url = "https://github.com/packwiz/packwiz-installer-bootstrap/releases/download/$version/packwiz-installer-bootstrap.jar"
$destination = Join-Path $toolDirectory "packwiz-installer-bootstrap-$version.jar"

if (Test-Path -LiteralPath $destination) {
    $actual = (Get-FileHash -LiteralPath $destination -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($actual -ne $expectedSha256) {
        throw "Existing bootstrap JAR failed SHA-256 validation: $destination"
    }
} else {
    $temporary = "$destination.download"
    Invoke-WebRequest -Uri $url -OutFile $temporary -UseBasicParsing
    $actual = (Get-FileHash -LiteralPath $temporary -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($actual -ne $expectedSha256) {
        Remove-Item -LiteralPath $temporary -Force
        throw "Downloaded bootstrap JAR failed SHA-256 validation. Expected $expectedSha256, got $actual."
    }
    Move-Item -LiteralPath $temporary -Destination $destination
}

Write-Host "Verified Packwiz installer bootstrap $version."
if ($PassThru) {
    return $destination
}

