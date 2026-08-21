[CmdletBinding()]
param(
    [string]$ProjectRoot
)

$ErrorActionPreference = 'Stop'
if (-not $ProjectRoot) { $ProjectRoot = Split-Path -Parent $PSScriptRoot }
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

function Convert-TextFileToLf([string]$Path) {
    if ([IO.Path]::GetExtension($Path).Equals('.png', [StringComparison]::OrdinalIgnoreCase)) { return }
    $bytes = [IO.File]::ReadAllBytes($Path)
    if ($bytes -contains 0) { return }
    $stream = [IO.MemoryStream]::new($bytes.Length)
    try {
        for ($index = 0; $index -lt $bytes.Length; $index++) {
            if ($bytes[$index] -eq 13 -and ($index + 1) -lt $bytes.Length -and $bytes[$index + 1] -eq 10) {
                continue
            }
            $stream.WriteByte($bytes[$index])
        }
        $normalised = $stream.ToArray()
    } finally {
        $stream.Dispose()
    }
    if ($normalised.Length -ne $bytes.Length) {
        [IO.File]::WriteAllBytes($Path, $normalised)
    }
}

# GitHub raw serves the LF-normalised Git blobs. Normalise the local host copy
# before hashing so Windows LAN tests, committed metadata, and repository
# downloads all use the same bytes. NUL-containing binary payloads are left as-is.
foreach ($payloadFile in Get-ChildItem -LiteralPath (Join-Path $projectRootResolved 'payload') -Recurse -File) {
    Convert-TextFileToLf $payloadFile.FullName
}
foreach ($metadataFile in Get-ChildItem -LiteralPath $packRoot -Recurse -File) {
    if ($metadataFile.FullName -like '*\.packwiz-cache\*' -or $metadataFile.Extension -in @('.exe', '.jar')) { continue }
    Convert-TextFileToLf $metadataFile.FullName
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

    $isMetafile = $relative.EndsWith('.pw.toml', [StringComparison]::OrdinalIgnoreCase)
    $preservePlayerCopy = $false
    if ($isMetafile -and $relative.StartsWith('config/', [StringComparison]::OrdinalIgnoreCase)) {
        $metadataText = [IO.File]::ReadAllText($file.FullName)
        $sideMatch = [regex]::Match($metadataText, '(?m)^side\s*=\s*"([^"]+)"')
        $filenameMatch = [regex]::Match($metadataText, '(?m)^filename\s*=\s*"([^"]+)"')
        $isClientOnly = $sideMatch.Success -and $sideMatch.Groups[1].Value -eq 'client'
        $isTextSetting = $filenameMatch.Success -and
            -not [IO.Path]::GetExtension($filenameMatch.Groups[1].Value).Equals('.png', [StringComparison]::OrdinalIgnoreCase) -and
            -not [IO.Path]::GetExtension($filenameMatch.Groups[1].Value).Equals('.jpg', [StringComparison]::OrdinalIgnoreCase) -and
            -not [IO.Path]::GetExtension($filenameMatch.Groups[1].Value).Equals('.jpeg', [StringComparison]::OrdinalIgnoreCase) -and
            -not [IO.Path]::GetExtension($filenameMatch.Groups[1].Value).Equals('.gif', [StringComparison]::OrdinalIgnoreCase) -and
            -not [IO.Path]::GetExtension($filenameMatch.Groups[1].Value).Equals('.webp', [StringComparison]::OrdinalIgnoreCase)
        $preservePlayerCopy = $isClientOnly -and $isTextSetting
    }

    $entries += [pscustomobject]@{
        File = $relative
        Hash = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
        Metafile = $isMetafile
        Preserve = $preservePlayerCopy
    }
}
$entries = @($entries | Sort-Object File)

$builder = [Text.StringBuilder]::new()
[void]$builder.Append("hash-format = `"sha256`"`n")
foreach ($entry in $entries) {
    [void]$builder.Append("`n[[files]]`n")
    [void]$builder.Append("file = $(ConvertTo-TomlString $entry.File)`n")
    [void]$builder.Append("hash = $(ConvertTo-TomlString $entry.Hash)`n")
    if ($entry.Metafile) {
        [void]$builder.Append("metafile = true`n")
    }
    if ($entry.Preserve) {
        # Packwiz installs the supplied default on a clean client, then leaves an
        # existing player's copy untouched during later updates.
        [void]$builder.Append("preserve = true`n")
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

# Keep the repository's machine-readable mod and count audits aligned with the
# Packwiz manifests. Disposable host copies do not contain an audit directory,
# so their metadata refresh remains isolated from repository evidence.
$auditRoot = Join-Path $projectRootResolved 'audit'
if (Test-Path -LiteralPath $auditRoot -PathType Container) {
    function Get-RequiredTomlValue([string]$Text, [string]$Key, [string]$SourcePath) {
        $match = [regex]::Match($Text, "(?m)^$([regex]::Escape($Key))\s*=\s*`"([^`"]+)`"\s*$")
        if (-not $match.Success) { throw "Missing $Key in $SourcePath" }
        return $match.Groups[1].Value
    }

    $modRows = @()
    $modSideCounts = [ordered]@{ both = 0; client = 0; server = 0 }
    foreach ($metadataFile in Get-ChildItem -LiteralPath (Join-Path $packRoot 'mods') -File -Filter '*.pw.toml') {
        $text = [IO.File]::ReadAllText($metadataFile.FullName)
        $side = Get-RequiredTomlValue $text 'side' $metadataFile.FullName
        if (-not $modSideCounts.Contains($side)) { throw "Invalid mod side '$side' in $($metadataFile.FullName)" }
        $hashFormat = Get-RequiredTomlValue $text 'hash-format' $metadataFile.FullName
        if ($hashFormat -ne 'sha512') { throw "Mod audit requires SHA-512 metadata: $($metadataFile.FullName)" }
        $modSideCounts[$side]++
        $modRows += [pscustomobject][ordered]@{
            Filename = Get-RequiredTomlValue $text 'filename' $metadataFile.FullName
            Name = Get-RequiredTomlValue $text 'name' $metadataFile.FullName
            Side = $side
            Sha512 = Get-RequiredTomlValue $text 'hash' $metadataFile.FullName
            Source = Get-RequiredTomlValue $text 'url' $metadataFile.FullName
            Confidence = 'manifest: Packwiz side and declared exact hash; see validation audits for runtime proof'
        }
    }
    $modCsv = @($modRows | Sort-Object Filename | ConvertTo-Csv -NoTypeInformation)
    [IO.File]::WriteAllLines((Join-Path $auditRoot 'mods.csv'), $modCsv, $utf8)

    $managedRows = @()
    foreach ($metadataFile in Get-ChildItem -LiteralPath $packRoot -Recurse -File -Filter '*.pw.toml') {
        $relativeMetadata = (Get-RelativePath $packRoot $metadataFile.FullName).Replace('\', '/')
        if ($relativeMetadata.StartsWith('mods/', [StringComparison]::OrdinalIgnoreCase)) { continue }
        $text = [IO.File]::ReadAllText($metadataFile.FullName)
        $directory = [IO.Path]::GetDirectoryName($relativeMetadata).Replace('\', '/')
        $filename = Get-RequiredTomlValue $text 'filename' $metadataFile.FullName
        $destination = if ($directory) { "$directory/$filename" } else { $filename }
        $hashFormat = Get-RequiredTomlValue $text 'hash-format' $metadataFile.FullName
        $hash = Get-RequiredTomlValue $text 'hash' $metadataFile.FullName
        $source = Get-RequiredTomlValue $text 'url' $metadataFile.FullName
        $isHostedPayload = $source -match '/payload/'
        $managedRows += [pscustomobject][ordered]@{
            Path = $destination
            Side = Get-RequiredTomlValue $text 'side' $metadataFile.FullName
            Source = $source
            Sha256 = if ($hashFormat -eq 'sha256') { $hash } else { "see $hashFormat metadata" }
            Reason = if ($isHostedPayload) {
                'Packwiz-managed repository payload; side and exact hash declared in metadata.'
            } else {
                'Packwiz-managed external download; side and exact hash declared in metadata.'
            }
        }
    }
    $managedCsv = @($managedRows | Sort-Object Path | ConvertTo-Csv -NoTypeInformation)
    [IO.File]::WriteAllLines((Join-Path $auditRoot 'managed-files.csv'), $managedCsv, $utf8)

    $minecraftMatch = [regex]::Match($packText, '(?m)^minecraft\s*=\s*"([^"]+)"\s*$')
    $forgeMatch = [regex]::Match($packText, '(?m)^forge\s*=\s*"([^"]+)"\s*$')
    if (-not $minecraftMatch.Success -or -not $forgeMatch.Success) { throw 'Could not read Minecraft/Forge versions for audit summary.' }
    $excludedPath = Join-Path $auditRoot 'excluded-files.csv'
    $excludedCount = if (Test-Path -LiteralPath $excludedPath -PathType Leaf) { @(Import-Csv -LiteralPath $excludedPath).Count } else { 0 }
    $summary = [ordered]@{
        generatedAt = (Get-Date).ToString('o')
        minecraft = $minecraftMatch.Groups[1].Value
        forge = $forgeMatch.Groups[1].Value
        clientMods = $modSideCounts.both + $modSideCounts.client
        serverMods = $modSideCounts.both + $modSideCounts.server
        modSides = $modSideCounts
        managedPayloadFiles = @(Get-ChildItem -LiteralPath $payloadRoot -Recurse -File).Count
        excludedFiles = $excludedCount
        shaderpacksManaged = $false
        note = 'Shader archives and settings are deliberately outside automatic management.'
    }
    [IO.File]::WriteAllText((Join-Path $auditRoot 'summary.json'), (($summary | ConvertTo-Json -Depth 10) + "`r`n"), $utf8)
}

Write-Host "Refreshed $($entries.Count) Packwiz index entries."
Write-Host "Preserving $(@($entries | Where-Object Preserve).Count) client setting files after first install."
Write-Host "index.toml SHA-256: $indexHash"
