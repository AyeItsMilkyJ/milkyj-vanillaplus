[CmdletBinding()]
param(
    [string]$ClientMinecraftRoot = (Join-Path $env:APPDATA 'PrismLauncher\instances\Premium Modpack DEV\minecraft'),
    [string]$ServerRoot = (Join-Path ([Environment]::GetFolderPath('Desktop')) 'Minecraft Server'),
    [string]$ModrinthManifest = (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'release-builds\MilkyJ-VanillaPlus-1.8.0\modrinth.index.json'),
    [string]$ProjectRoot = (Split-Path -Parent $PSScriptRoot),
    [switch]$Apply
)

$ErrorActionPreference = 'Stop'
$projectRootResolved = [IO.Path]::GetFullPath($ProjectRoot)
$clientRootResolved = [IO.Path]::GetFullPath($ClientMinecraftRoot)
$serverRootResolved = [IO.Path]::GetFullPath($ServerRoot)
$settings = Get-Content -LiteralPath (Join-Path $projectRootResolved 'project-settings.json') -Raw | ConvertFrom-Json
$rawBaseUrl = ([string]$settings.rawRepositoryBaseUrl).TrimEnd('/')

foreach ($required in @(
    (Join-Path $clientRootResolved 'mods'),
    (Join-Path $serverRootResolved 'mods'),
    $ModrinthManifest
)) {
    if (-not (Test-Path -LiteralPath $required)) { throw "Required source does not exist: $required" }
}

function ConvertTo-TomlString([string]$Value) {
    return '"' + $Value.Replace('\', '\\').Replace('"', '\"').Replace("`r", '\r').Replace("`n", '\n') + '"'
}

function ConvertTo-Slug([string]$Value) {
    $slug = $Value.ToLowerInvariant() -replace '[^a-z0-9]+', '-'
    return $slug.Trim('-')
}

function Get-RelativePath([string]$BasePath, [string]$ChildPath) {
    $base = [IO.Path]::GetFullPath($BasePath).TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar
    $child = [IO.Path]::GetFullPath($ChildPath)
    if (-not $child.StartsWith($base, [StringComparison]::OrdinalIgnoreCase)) {
        throw "Path is outside the expected root: $child"
    }
    return $child.Substring($base.Length)
}

function Get-RelativeFileMap([string]$Root) {
    $map = @{}
    if (-not (Test-Path -LiteralPath $Root -PathType Container)) { return $map }
    foreach ($file in Get-ChildItem -LiteralPath $Root -Recurse -File -Force) {
        $relative = (Get-RelativePath $Root $file.FullName).Replace('\', '/')
        $map[$relative] = [pscustomobject]@{
            Path = $file.FullName
            Hash = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
            Sha512 = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA512).Hash.ToLowerInvariant()
            Length = $file.Length
        }
    }
    return $map
}

function Get-JarMap([string]$Root) {
    $map = @{}
    foreach ($file in Get-ChildItem -LiteralPath $Root -File -Filter *.jar) {
        $map[$file.Name] = [pscustomobject]@{
            Path = $file.FullName
            Hash = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA512).Hash.ToLowerInvariant()
            Length = $file.Length
        }
    }
    return $map
}

function Read-PrismIndex([string]$IndexRoot) {
    $result = @{}
    if (-not (Test-Path -LiteralPath $IndexRoot)) { return $result }
    foreach ($file in Get-ChildItem -LiteralPath $IndexRoot -File -Filter *.pw.toml) {
        $text = Get-Content -LiteralPath $file.FullName -Raw
        $filenameMatch = [regex]::Match($text, '(?m)^filename\s*=\s*["'']([^"'']+)["'']')
        if (-not $filenameMatch.Success) { continue }
        $nameMatch = [regex]::Match($text, '(?m)^name\s*=\s*["'']([^"'']+)["'']')
        $result[$filenameMatch.Groups[1].Value] = [pscustomobject]@{
            Name = if ($nameMatch.Success) { $nameMatch.Groups[1].Value } else { [IO.Path]::GetFileNameWithoutExtension($filenameMatch.Groups[1].Value) }
            MetaName = $file.Name
        }
    }
    return $result
}

function New-ExternalMetadata {
    param(
        [string]$Path,
        [string]$Name,
        [string]$Filename,
        [ValidateSet('client', 'server', 'both')][string]$Side,
        [string]$Url,
        [string]$HashFormat,
        [string]$Hash,
        [string]$UpdateKind,
        [string]$ProjectId,
        [string]$VersionId
    )
    $lines = [Collections.Generic.List[string]]::new()
    $lines.Add("name = $(ConvertTo-TomlString $Name)")
    $lines.Add("filename = $(ConvertTo-TomlString $Filename)")
    $lines.Add("side = $(ConvertTo-TomlString $Side)")
    $lines.Add('')
    $lines.Add('[download]')
    $lines.Add("url = $(ConvertTo-TomlString $Url)")
    $lines.Add("hash-format = $(ConvertTo-TomlString $HashFormat)")
    $lines.Add("hash = $(ConvertTo-TomlString $Hash)")
    if ($UpdateKind -eq 'modrinth') {
        $lines.Add('')
        $lines.Add('[update.modrinth]')
        $lines.Add("mod-id = $(ConvertTo-TomlString $ProjectId)")
        $lines.Add("version = $(ConvertTo-TomlString $VersionId)")
    } elseif ($UpdateKind -eq 'curseforge') {
        $lines.Add('')
        $lines.Add('[update.curseforge]')
        $lines.Add("project-id = $ProjectId")
        $lines.Add("file-id = $VersionId")
    }
    New-Item -ItemType Directory -Path (Split-Path -Parent $Path) -Force | Out-Null
    [IO.File]::WriteAllLines($Path, $lines, [Text.UTF8Encoding]::new($false))
}

function ConvertTo-UrlPath([string]$RelativePath) {
    return (($RelativePath.Replace('\', '/') -split '/') | ForEach-Object { [Uri]::EscapeDataString($_) }) -join '/'
}

$personalPatterns = @(
    '^jei/world/',
    '^jei/jei-client\.pre-',
    '^chunky/tasks/',
    '^DistantHorizons\.toml$',
    '^embeddium-options\.json$',
    '^entity_model_features\.json$',
    '^fabric/indigo-renderer\.properties$',
    '^jade/plugins\.json$',
    '^jade/sort-order\.json$',
    '^jei/ingredient-list-',
    '^jei/recipe-category-sort-order\.ini$',
    '^oculus\.properties$',
    '^sidebar_buttons\.json$',
    '^sound_physics_remastered/'
)
$uncertainPatterns = @(
    '^the_bumblezone/',
    '^connector\.json$',
    '^continuity\.json$',
    '^sodiumdynamiclights-client\.toml$',
    '^prehistoricfauna-client\.toml$',
    '^treasure2-client\.toml$'
)
$serverCanonicalChanged = @(
    'chalk-common.toml',
    'endrem.toml',
    'fetzis_displays/fetzis-displays-config.json',
    'immersive_melodies.json',
    'packetfixer.properties',
    'quark-common.toml',
    'sereneseasons/fertility.toml',
    'sereneseasons/seasons.toml',
    'sophisticatedcore-common.toml',
    'terrablender.toml',
    'untamedwilds-common.toml'
)
$clientCanonicalChanged = @('alexscaves-client.toml')
$allowedServerOnly = @('chunky/config.json', 'immersive_paintings.json', 'jade/server-plugin-overrides.json', 'moblassos-server.toml')

function Test-MatchesAny([string]$Value, [string[]]$Patterns) {
    foreach ($pattern in $Patterns) { if ($Value -match $pattern) { return $true } }
    return $false
}

function Get-HeuristicSide([string]$RelativePath) {
    $leaf = [IO.Path]::GetFileName($RelativePath).ToLowerInvariant()
    $lower = $RelativePath.ToLowerInvariant()
    if ($leaf -match '(^|[-_.])client([-_.]|$)' -or $lower -match '(^|/)(xaero|jei)(/|$)') { return 'client' }
    if ($leaf -match '(^|[-_.])server([-_.]|$)') { return 'server' }
    return 'both'
}

$stageRoot = Join-Path $projectRootResolved ("build\import-stage-" + [guid]::NewGuid().ToString('N'))
$stagePack = Join-Path $stageRoot 'packwiz'
$stagePayload = Join-Path $stageRoot 'payload'
$stageAudit = Join-Path $stageRoot 'audit'
New-Item -ItemType Directory -Path $stagePack, $stagePayload, $stageAudit -Force | Out-Null

$clientMods = Get-JarMap (Join-Path $clientRootResolved 'mods')
$serverMods = Get-JarMap (Join-Path $serverRootResolved 'mods')
$prismIndex = Read-PrismIndex (Join-Path $clientRootResolved 'mods\.index')
$manifest = Get-Content -LiteralPath $ModrinthManifest -Raw | ConvertFrom-Json
$manifestByName = @{}
foreach ($entry in $manifest.files | Where-Object { $_.path -like 'mods/*' }) {
    $manifestByName[[IO.Path]::GetFileName($entry.path)] = $entry
}

$extraSources = @{
    'alternate_current-mc1.20-1.7.0.jar' = @{ Name='Alternate Current'; Url='https://cdn.modrinth.com/data/r0v8vy1s/versions/kC6SY4Zp/alternate_current-mc1.20-1.7.0.jar'; Hash='d9ae21a3a389c63466bf22b36d4a78c859f30c901397622f1f1438737901a2c67e4d911c83831e0d4f1edabf0b86b58f4192d9980ecef8278393fd4af64a9585'; Kind='modrinth'; Project='r0v8vy1s'; Version='kC6SY4Zp' }
    'Chunky-1.3.146.jar' = @{ Name='Chunky'; Url='https://cdn.modrinth.com/data/fALzjamp/versions/4FTDk9wv/Chunky-1.3.146.jar'; Hash='13ef9d5bfea1895118eec45aa3071e2d79408241f29990624f67e157d4c525391753b0a1539ff3359dad79a6e5ab5e0b84fffbe528bdefcaaefd579ec794d9c9'; Kind='modrinth'; Project='fALzjamp'; Version='4FTDk9wv' }
    'fairylights-7.0.0-1.20.1.jar' = @{ Name='Fairy Lights'; Url='https://edge.forgecdn.net/files/4961/775/fairylights-7.0.0-1.20.1.jar'; Hash='e07d7fa52768f4866fc36e1bd7f2120784cdd9f5a4a2b261c03634986ffbad396ddbf2cae8d4520da61810e001c95a51815e1cdf3dca84a45e5308466656b7c8'; Kind='curseforge'; Project='233342'; Version='4961775' }
    'ftb-filter-system-forge-20.0.1.jar' = @{ Name='FTB Filter System'; Url='https://edge.forgecdn.net/files/6466/153/ftb-filter-system-forge-20.0.1.jar'; Hash='4344015842a0bec06ad25751d2dd7f63bf0c2d9346b1dee272fd3183a8bf2a6c30c9e3c0141bf586fe1b0f2add34c918e46119b8f9ef0a1d0ba127785c026211'; Kind='curseforge'; Project='943925'; Version='6466153' }
    'ftb-library-forge-2001.2.13.jar' = @{ Name='FTB Library'; Url='https://edge.forgecdn.net/files/8226/927/ftb-library-forge-2001.2.13.jar'; Hash='433c890fc64b31f140cdb92c6f03f78400bcc105229d1026dbbecb027ff75a8e2f94af5b1eef083d7cf3d37a9afa176731bc59cfeb771d01738353f9f1c113bf'; Kind='curseforge'; Project='404465'; Version='8226927' }
    'ftb-quests-forge-2001.4.22.jar' = @{ Name='FTB Quests'; Url='https://edge.forgecdn.net/files/8078/538/ftb-quests-forge-2001.4.22.jar'; Hash='7ffec667d4bb73e33e1815655361c93a7564d9040af937b26035bfa3cc26f6125962f173c623eb71cf949b0b0a49181a0459648007b3054e97150bd72fcc0bf8'; Kind='curseforge'; Project='289412'; Version='8078538' }
    'ftb-teams-forge-2001.3.2.jar' = @{ Name='FTB Teams'; Url='https://edge.forgecdn.net/files/7499/810/ftb-teams-forge-2001.3.2.jar'; Hash='45f8980fa1cfcb7cd772f6a03abb0ac680f7c502dc569839e325553dcaa9105148a2c27a214cd1f1131f6b06bca957f8dd01dfb4a1ccb8e13d49502513480cae'; Kind='curseforge'; Project='404468'; Version='7499810' }
    'ftb-ultimine-forge-2001.1.8.jar' = @{ Name='FTB Ultimine'; Url='https://edge.forgecdn.net/files/7880/472/ftb-ultimine-forge-2001.1.8.jar'; Hash='57e04a50f96e533d9f92aaa26861ec78709681faf98812b666f7240cb265140f6ac0c5f28025adc4961d8e51b22f65c3eead17bdba2ea7f2929815cafbfc65e5'; Kind='curseforge'; Project='386134'; Version='7880472' }
    'ftb-xmod-compat-forge-2.1.3.jar' = @{ Name='FTB XMod Compat'; Url='https://edge.forgecdn.net/files/6402/486/ftb-xmod-compat-forge-2.1.3.jar'; Hash='4eb5aba1aff66721d19e54ceb40863684d0caab0735a9dcc04df86804ffcc19454f88ff89eb000db166aae2c1ef53ddbdadf61a62814db227638a8e86d37f2b9'; Kind='curseforge'; Project='889915'; Version='6402486' }
    'statisticsplus-1.0.0.jar' = @{ Name='Statistics Plus'; Url='https://edge.forgecdn.net/files/8049/929/statisticsplus-1.0.0.jar'; Hash='544206d657026d12bb4d8f4d53830ebad8000c788454771cd471e10a52115298146256f213f9e83311891fde1a4f9a793ef4eda43bb84403e3b25c5863ed7e48'; Kind='curseforge'; Project='1535784'; Version='8049929' }
    'Statues-1.20.1-0.4.2.jar' = @{ Name='Statues'; Url='https://edge.forgecdn.net/files/7459/974/Statues-1.20.1-0.4.2.jar'; Hash='e18829a1361a88a294c62c659f9ad2f8bc29133143c3fbfd313ccda45cd3272b60bda54c3f9dad095837969f5edd0e54218f8a611275d2f4aaef4fcf16eebc7d'; Kind='curseforge'; Project='253172'; Version='7459974' }
}

$modAudit = @()
$allModNames = @($clientMods.Keys + $serverMods.Keys | Sort-Object -Unique)
$usedMetaNames = @{}
foreach ($filename in $allModNames) {
    $inClient = $clientMods.ContainsKey($filename)
    $inServer = $serverMods.ContainsKey($filename)
    if ($inClient -and $inServer -and $clientMods[$filename].Hash -ne $serverMods[$filename].Hash) {
        throw "Client/server mod hashes differ for $filename"
    }
    $side = if ($inClient -and $inServer) { 'both' } elseif ($inClient) { 'client' } else { 'server' }
    $actualHash = if ($inClient) { $clientMods[$filename].Hash } else { $serverMods[$filename].Hash }
    $name = if ($prismIndex.ContainsKey($filename)) { $prismIndex[$filename].Name } else { [IO.Path]::GetFileNameWithoutExtension($filename) }
    $metaName = if ($prismIndex.ContainsKey($filename)) { $prismIndex[$filename].MetaName } else { (ConvertTo-Slug ([IO.Path]::GetFileNameWithoutExtension($filename))) + '.pw.toml' }
    if ($usedMetaNames.ContainsKey($metaName)) { $metaName = (ConvertTo-Slug ([IO.Path]::GetFileNameWithoutExtension($filename))) + '-' + $actualHash.Substring(0, 8) + '.pw.toml' }
    $usedMetaNames[$metaName] = $true

    if ($manifestByName.ContainsKey($filename)) {
        $source = $manifestByName[$filename]
        if ($source.hashes.sha512 -ne $actualHash) { throw "Manifest hash does not match installed file: $filename" }
        $url = [string]$source.downloads[0]
        $match = [regex]::Match($url, '/data/([^/]+)/versions/([^/]+)/')
        $kind = if ($match.Success) { 'modrinth' } else { '' }
        $projectId = if ($match.Success) { $match.Groups[1].Value } else { '' }
        $versionId = if ($match.Success) { $match.Groups[2].Value } else { '' }
    } elseif ($extraSources.ContainsKey($filename)) {
        $source = $extraSources[$filename]
        if ($source.Hash -ne $actualHash) { throw "Known download hash does not match installed file: $filename" }
        $url = $source.Url; $kind = $source.Kind; $projectId = $source.Project; $versionId = $source.Version; $name = $source.Name
    } else {
        throw "No trusted download source is known for installed mod: $filename"
    }

    New-ExternalMetadata -Path (Join-Path $stagePack "mods\$metaName") -Name $name -Filename $filename -Side $side -Url $url -HashFormat 'sha512' -Hash $actualHash -UpdateKind $kind -ProjectId $projectId -VersionId $versionId
    $modAudit += [pscustomobject]@{ Filename=$filename; Name=$name; Side=$side; Sha512=$actualHash; Source=$url; Confidence='high: observed install side and exact hash' }
}

$script:fileAudit = @()
$excludedAudit = @()
function Add-ManagedPayload {
    param([string]$Category, [string]$RelativePath, [string]$SourcePath, [string]$Side, [string]$Reason)
    $payloadRelative = "$Side/$Category/$RelativePath"
    $payloadPath = Join-Path $stagePayload ($payloadRelative.Replace('/', '\'))
    New-Item -ItemType Directory -Path (Split-Path -Parent $payloadPath) -Force | Out-Null
    Copy-Item -LiteralPath $SourcePath -Destination $payloadPath
    $hash = (Get-FileHash -LiteralPath $payloadPath -Algorithm SHA256).Hash.ToLowerInvariant()
    $url = "$rawBaseUrl/payload/$(ConvertTo-UrlPath $payloadRelative)"
    $metaPath = Join-Path $stagePack (($Category + '/' + $RelativePath + '.pw.toml').Replace('/', '\'))
    New-ExternalMetadata -Path $metaPath -Name "Managed ${Category}: $RelativePath" -Filename ([IO.Path]::GetFileName($RelativePath)) -Side $Side -Url $url -HashFormat 'sha256' -Hash $hash
    $sourceOrigin = if ($SourcePath.StartsWith($clientRootResolved, [StringComparison]::OrdinalIgnoreCase)) {
        "working-client/$Category/$RelativePath"
    } elseif ($SourcePath.StartsWith($serverRootResolved, [StringComparison]::OrdinalIgnoreCase)) {
        "working-server/$Category/$RelativePath"
    } else {
        'explicit maintainer source'
    }
    $script:fileAudit += [pscustomobject]@{ Path="$Category/$RelativePath"; Side=$Side; Source=$sourceOrigin; Sha256=$hash; Reason=$Reason }
}

foreach ($category in @('config', 'defaultconfigs', 'kubejs', 'scripts', 'moonlight-global-datapacks')) {
    $clientMap = Get-RelativeFileMap (Join-Path $clientRootResolved $category)
    $serverMap = Get-RelativeFileMap (Join-Path $serverRootResolved $category)
    $all = @($clientMap.Keys + $serverMap.Keys | Sort-Object -Unique)
    foreach ($relative in $all) {
        $hasClient = $clientMap.ContainsKey($relative)
        $hasServer = $serverMap.ContainsKey($relative)
        $same = $hasClient -and $hasServer -and $clientMap[$relative].Hash -eq $serverMap[$relative].Hash

        if ($category -eq 'config' -and (Test-MatchesAny $relative $personalPatterns)) {
            $excludedAudit += [pscustomobject]@{ Path="$category/$relative"; Classification='personal/generated'; Reason='Not Packwiz-managed; protects player choices or generated state.' }
            continue
        }
        if ($category -eq 'config' -and (Test-MatchesAny $relative $uncertainPatterns)) {
            $excludedAudit += [pscustomobject]@{ Path="$category/$relative"; Classification='uncertain/stale'; Reason='Left untouched because the owning mod is absent or classification is not reliable.' }
            continue
        }

        if ($same) {
            $side = Get-HeuristicSide $relative
            $sourcePath = $clientMap[$relative].Path
            $reason = 'Identical client/server source; side inferred from conventional filename, otherwise both.'
        } elseif ($hasClient -and -not $hasServer) {
            $side = 'client'; $sourcePath = $clientMap[$relative].Path; $reason = 'Present only in the working client.'
        } elseif ($hasServer -and -not $hasClient) {
            if ($category -eq 'config' -and $relative -notin $allowedServerOnly -and (Get-HeuristicSide $relative) -ne 'server') {
                $excludedAudit += [pscustomobject]@{ Path="$category/$relative"; Classification='uncertain/server-only source'; Reason='Left untouched rather than packaging a server-only residual file without confidence.' }
                continue
            }
            $side = 'server'; $sourcePath = $serverMap[$relative].Path; $reason = 'Present only in the working dedicated server.'
        } elseif ($category -eq 'config' -and $relative -in $serverCanonicalChanged) {
            $side = 'both'; $sourcePath = $serverMap[$relative].Path; $reason = 'Gameplay/common config differed; working dedicated-server value is canonical for both.'
        } elseif ($category -eq 'config' -and $relative -in $clientCanonicalChanged) {
            $side = 'client'; $sourcePath = $clientMap[$relative].Path; $reason = 'Explicit client config; working client value is canonical.'
        } else {
            $excludedAudit += [pscustomobject]@{ Path="$category/$relative"; Classification='conflicting'; Reason='Client/server contents differ and no safe canonical source was inferred.' }
            continue
        }
        Add-ManagedPayload -Category $category -RelativePath $relative -SourcePath $sourcePath -Side $side -Reason $reason
    }
}

# Publicly hosted resource packs retain exact versions from the working 1.8.0 manifest.
foreach ($entry in $manifest.files | Where-Object { $_.path -like 'resourcepacks/*' }) {
    $filename = [IO.Path]::GetFileName($entry.path)
    $url = [string]$entry.downloads[0]
    $match = [regex]::Match($url, '/data/([^/]+)/versions/([^/]+)/')
    $metaName = (ConvertTo-Slug ([IO.Path]::GetFileNameWithoutExtension($filename))) + '.pw.toml'
    New-ExternalMetadata -Path (Join-Path $stagePack "resourcepacks\$metaName") -Name ([IO.Path]::GetFileNameWithoutExtension($filename)) -Filename $filename -Side 'client' -Url $url -HashFormat 'sha512' -Hash $entry.hashes.sha512 -UpdateKind 'modrinth' -ProjectId $match.Groups[1].Value -VersionId $match.Groups[2].Value
    $fileAudit += [pscustomobject]@{ Path="resourcepacks/$filename"; Side='client'; Source=$url; Sha256='see sha512 metadata'; Reason='Exact resource-pack version from the working release manifest.' }
}

$customResourceRoot = Join-Path $clientRootResolved 'resourcepacks\MilkyJ Stability Fixes'
if (Test-Path -LiteralPath $customResourceRoot) {
    foreach ($file in Get-ChildItem -LiteralPath $customResourceRoot -Recurse -File) {
        $relative = 'MilkyJ Stability Fixes/' + (Get-RelativePath $customResourceRoot $file.FullName).Replace('\', '/')
        Add-ManagedPayload -Category 'resourcepacks' -RelativePath $relative -SourcePath $file.FullName -Side 'client' -Reason 'Custom client resource-pack file from the working instance.'
    }
}

$modAudit | Sort-Object Side, Filename | Export-Csv -LiteralPath (Join-Path $stageAudit 'mods.csv') -NoTypeInformation -Encoding utf8
$fileAudit | Sort-Object Side, Path | Export-Csv -LiteralPath (Join-Path $stageAudit 'managed-files.csv') -NoTypeInformation -Encoding utf8
$excludedAudit | Sort-Object Path | Export-Csv -LiteralPath (Join-Path $stageAudit 'excluded-files.csv') -NoTypeInformation -Encoding utf8
$summary = [ordered]@{
    generatedAt = (Get-Date).ToString('o')
    minecraft = '1.20.1'
    forge = '47.4.10'
    clientMods = $clientMods.Count
    serverMods = $serverMods.Count
    modSides = [ordered]@{
        both = @($modAudit | Where-Object Side -eq 'both').Count
        client = @($modAudit | Where-Object Side -eq 'client').Count
        server = @($modAudit | Where-Object Side -eq 'server').Count
    }
    managedPayloadFiles = $fileAudit.Count
    excludedFiles = $excludedAudit.Count
    shaderpacksManaged = $false
    note = 'Shader archives and settings are deliberately outside automatic management.'
}
$summary | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath (Join-Path $stageAudit 'summary.json') -Encoding utf8

Write-Host "Audit complete: $($modAudit.Count) mods; $($fileAudit.Count) managed non-mod files; $($excludedAudit.Count) exclusions."
Write-Host "Sides: both=$(@($modAudit | Where-Object Side -eq 'both').Count), client=$(@($modAudit | Where-Object Side -eq 'client').Count), server=$(@($modAudit | Where-Object Side -eq 'server').Count)."
if (-not $Apply) {
    Write-Host 'Dry run only. Re-run with -Apply to replace generated Packwiz metadata/payload/audit directories.'
    Write-Host "Dry-run artefacts: $stageRoot"
    return
}

$generatedNames = @('mods', 'resourcepacks', 'config', 'defaultconfigs', 'kubejs', 'scripts', 'moonlight-global-datapacks')
$backupRoot = Join-Path $projectRootResolved ("build\import-backup-" + (Get-Date -Format 'yyyyMMdd-HHmmss'))
New-Item -ItemType Directory -Path $backupRoot -Force | Out-Null
foreach ($name in $generatedNames) {
    $existing = Join-Path (Join-Path $projectRootResolved 'packwiz') $name
    if (Test-Path -LiteralPath $existing) {
        Move-Item -LiteralPath $existing -Destination (Join-Path $backupRoot $name)
    }
    $staged = Join-Path $stagePack $name
    if (Test-Path -LiteralPath $staged) {
        Copy-Item -LiteralPath $staged -Destination $existing -Recurse
    }
}
foreach ($name in @('payload', 'audit')) {
    $existing = Join-Path $projectRootResolved $name
    if (Test-Path -LiteralPath $existing) {
        Move-Item -LiteralPath $existing -Destination (Join-Path $backupRoot $name)
    }
    Copy-Item -LiteralPath (Join-Path $stageRoot $name) -Destination $existing -Recurse
}

& (Join-Path $PSScriptRoot 'Update-PackMetadata.ps1') -ProjectRoot $projectRootResolved
Write-Host "Applied generated pack. Previous generated content, if any: $backupRoot"
