[CmdletBinding()]
param(
    [string]$ProjectRoot,
    [switch]$PassThru
)

$ErrorActionPreference = 'Stop'
if (-not $ProjectRoot) { $ProjectRoot = Split-Path -Parent $PSScriptRoot }
$version = 'v0.0.3'
$expectedSha256 = 'a8fbb24dc604278e97f4688e82d3d91a318b98efc08d5dbfcbcbcab6443d116c'
$url = "https://github.com/packwiz/packwiz-installer-bootstrap/releases/download/$version/packwiz-installer-bootstrap.jar"
$toolDirectory = Join-Path ([IO.Path]::GetFullPath($ProjectRoot)) '.tools'
$destination = Join-Path $toolDirectory "packwiz-installer-bootstrap-$version.jar"

New-Item -ItemType Directory -Path $toolDirectory -Force | Out-Null
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

