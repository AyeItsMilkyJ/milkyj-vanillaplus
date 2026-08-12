[CmdletBinding()]
param(
    [string]$ProjectRoot = (Split-Path -Parent $PSScriptRoot)
)

$ErrorActionPreference = 'Stop'
$projectRootResolved = [IO.Path]::GetFullPath($ProjectRoot)
$packRoot = Join-Path $projectRootResolved 'packwiz'
$packFile = Join-Path $packRoot 'pack.toml'
$indexFile = Join-Path $packRoot 'index.toml'

if (-not (Test-Path -LiteralPath $packFile -PathType Leaf)) {
    throw "Pack metadata not found: $packFile"
}

function ConvertTo-TomlString([string]$Value) {
    return '"' + $Value.Replace('\', '\\').Replace('"', '\"').Replace("`r", '\r').Replace("`n", '\n') + '"'
}

function Get-RelativePath([string]$BasePath, [string]$ChildPath) {
    $base = [IO.Path]::GetFullPath($BasePath).TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar
    $child = [IO.Path]::GetFullPath($ChildPath)
    if (-not $child.StartsWith($base, [StringComparison]::OrdinalIgnoreCase)) {
        throw "Path is outside the expected root: $child"
    }
    return $child.Substring($base.Length)
}

function Get-FileDigest([string]$Path, [string]$Algorithm) {
    switch ($Algorithm.ToLowerInvariant()) {
        'sha256' { $native = 'SHA256' }
        'sha512' { $native = 'SHA512' }
        'sha1' { $native = 'SHA1' }
        'md5' { $native = 'MD5' }
        default { throw "Unsupported hosted-payload hash format: $Algorithm" }
    }
    return (Get-FileHash -LiteralPath $Path -Algorithm $native).Hash.ToLowerInvariant()
}

# A config/script/resource file hosted from this repository has two hashes:
# its payload hash in the metafile, and the metafile hash in index.toml. Refresh
# the payload hash first so one command safely updates both layers.
$payloadRoot = Join-Path $projectRootResolved 'payload'
foreach ($metadataFile in Get-ChildItem -LiteralPath $packRoot -Recurse -File -Filter *.pw.toml) {
    $metadataText = [IO.File]::ReadAllText($metadataFile.FullName)
    $urlMatch = [regex]::Match($metadataText, '(?m)^url\s*=\s*"https?://[^\"]+/payload/([^\"]+)"')
    if (-not $urlMatch.Success) { continue }
    $payloadRelative = [Uri]::UnescapeDataString($urlMatch.Groups[1].Value).Replace('/', '\')
    $payloadPath = [IO.Path]::GetFullPath((Join-Path $payloadRoot $payloadRelative))
    $payloadRootPrefix = [IO.Path]::GetFullPath($payloadRoot).TrimEnd('\') + '\'
    if (-not $payloadPath.StartsWith($payloadRootPrefix, [StringComparison]::OrdinalIgnoreCase)) {
        throw "Hosted payload path escapes payload root: $($metadataFile.FullName)"
    }
    if (-not (Test-Path -LiteralPath $payloadPath -PathType Leaf)) {
        throw "Hosted payload is missing: $payloadPath"
    }
    $formatMatch = [regex]::Match($metadataText, '(?ms)\[download\].*?^hash-format\s*=\s*"([^\"]+)"')
    if (-not $formatMatch.Success) { throw "Hosted payload metadata has no hash format: $($metadataFile.FullName)" }
    $actualPayloadHash = Get-FileDigest $payloadPath $formatMatch.Groups[1].Value
    $payloadPattern = [regex]::new('(?ms)(\[download\].*?^hash\s*=\s*")[^\"]*(")')
    $updatedText = $payloadPattern.Replace(
        $metadataText,
        [Text.RegularExpressions.MatchEvaluator]{ param($match) $match.Groups[1].Value + $actualPayloadHash + $match.Groups[2].Value },
        1
    )
    if ($updatedText -ne $metadataText) {
        [IO.File]::WriteAllText($metadataFile.FullName, $updatedText, [Text.UTF8Encoding]::new($false))
    }
}

$excluded = @('pack.toml', 'index.toml', '.packwizignore')
$entries = @()
foreach ($file in Get-ChildItem -LiteralPath $packRoot -Recurse -File -Force) {
    $relative = (Get-RelativePath $packRoot $file.FullName).Replace('\', '/')
    if ($relative -in $excluded -or $relative.StartsWith('.packwiz-cache/')) {
        continue
    }

    $entries += [pscustomobject]@{
        File = $relative
        Hash = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
        Metafile = $relative.EndsWith('.pw.toml', [StringComparison]::OrdinalIgnoreCase)
    }
}
$entries = @($entries | Sort-Object File)

$builder = [Text.StringBuilder]::new()
[void]$builder.AppendLine('hash-format = "sha256"')
foreach ($entry in $entries) {
    [void]$builder.AppendLine()
    [void]$builder.AppendLine('[[files]]')
    [void]$builder.AppendLine("file = $(ConvertTo-TomlString $entry.File)")
    [void]$builder.AppendLine("hash = $(ConvertTo-TomlString $entry.Hash)")
    if ($entry.Metafile) {
        [void]$builder.AppendLine('metafile = true')
    }
}

$utf8 = [Text.UTF8Encoding]::new($false)
[IO.File]::WriteAllText($indexFile, $builder.ToString(), $utf8)
$indexHash = (Get-FileHash -LiteralPath $indexFile -Algorithm SHA256).Hash.ToLowerInvariant()

$packText = [IO.File]::ReadAllText($packFile)
if ($packText -notmatch '(?ms)\[index\].*?^hash\s*=\s*"[^"]*"') {
    throw 'pack.toml does not contain a writable [index] hash field.'
}
$indexPattern = [regex]::new('(?ms)(\[index\].*?^hash\s*=\s*")[^"]*(")')
$packText = $indexPattern.Replace(
    $packText,
    [Text.RegularExpressions.MatchEvaluator]{ param($match) $match.Groups[1].Value + $indexHash + $match.Groups[2].Value },
    1
)
[IO.File]::WriteAllText($packFile, $packText, $utf8)

Write-Host "Refreshed $($entries.Count) Packwiz index entries."
Write-Host "index.toml SHA-256: $indexHash"
