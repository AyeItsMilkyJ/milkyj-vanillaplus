[CmdletBinding()]
param(
    [string]$MinecraftRoot,
    [string]$OptionsPath,
    [string]$ProfilePath = (Join-Path $PSScriptRoot 'recommended-controls.json'),
    [switch]$RestoreLatest,
    [switch]$SkipProcessCheck,
    [string[]]$ProcessCommandLines
)

$ErrorActionPreference = 'Stop'

if (-not $MinecraftRoot) {
    $MinecraftRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
} else {
    $MinecraftRoot = [IO.Path]::GetFullPath($MinecraftRoot)
}
if (-not $OptionsPath) { $OptionsPath = Join-Path $MinecraftRoot 'options.txt' }
$OptionsPath = [IO.Path]::GetFullPath($OptionsPath)
$ProfilePath = [IO.Path]::GetFullPath($ProfilePath)
$backupRoot = Join-Path $MinecraftRoot 'milkycraft-control-backups'

function Assert-MinecraftStopped {
    if ($SkipProcessCheck) { return }
    $rootNeedle = $MinecraftRoot.Replace('/', '\').TrimEnd('\').ToLowerInvariant()
    $rootPattern = '(?:^|[\s"''=])' + [regex]::Escape($rootNeedle) + '(?:$|[\s"''\\])'
    if ($null -ne $ProcessCommandLines) {
        $javaCommandLines = @($ProcessCommandLines | Where-Object { $_ })
    } else {
        try {
            $javaCommandLines = @(Get-CimInstance Win32_Process -ErrorAction Stop | Where-Object {
                $_.Name -in @('java.exe', 'javaw.exe') -and $_.CommandLine
            } | ForEach-Object { [string]$_.CommandLine })
        } catch {
            throw "Could not prove Minecraft is closed. Close Minecraft and retry. Process check failed: $($_.Exception.Message)"
        }
    }
    $minecraftJava = @($javaCommandLines | Where-Object {
        $normalisedCommandLine = $_.Replace('/', '\').ToLowerInvariant()
        [regex]::IsMatch($normalisedCommandLine, $rootPattern)
    })
    if ($minecraftJava.Count -gt 0) {
        throw 'Minecraft is using this instance. Close the game before changing or restoring controls.'
    }
}

function Read-Utf8File([string]$Path) {
    $bytes = [IO.File]::ReadAllBytes($Path)
    $hasBom = $bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF
    $offset = if ($hasBom) { 3 } else { 0 }
    $bodyLength = $bytes.Length - $offset
    $text = if ($bodyLength -gt 0) {
        [Text.Encoding]::UTF8.GetString($bytes, $offset, $bodyLength)
    } else { '' }
    return [pscustomobject]@{ Bytes = $bytes; Text = $text; HasBom = $hasBom }
}

function Write-Utf8Atomic([string]$Path, [string]$Text, [bool]$WithBom) {
    $body = [Text.Encoding]::UTF8.GetBytes($Text)
    if ($WithBom) {
        $preamble = [byte[]](0xEF, 0xBB, 0xBF)
        $output = [byte[]]::new($preamble.Length + $body.Length)
        [Array]::Copy($preamble, 0, $output, 0, $preamble.Length)
        [Array]::Copy($body, 0, $output, $preamble.Length, $body.Length)
    } else {
        $output = $body
    }
    $temporary = "$Path.milkycraft-$([Guid]::NewGuid().ToString('N')).tmp"
    $replaceBackup = "$Path.milkycraft-$([Guid]::NewGuid().ToString('N')).bak"
    try {
        [IO.File]::WriteAllBytes($temporary, $output)
        [IO.File]::Replace($temporary, $Path, $replaceBackup, $true)
    } finally {
        if (Test-Path -LiteralPath $temporary) { Remove-Item -LiteralPath $temporary -Force }
        if (Test-Path -LiteralPath $replaceBackup) { Remove-Item -LiteralPath $replaceBackup -Force }
    }
}

function Copy-BytesAtomic([string]$Source, [string]$Destination) {
    $temporary = "$Destination.milkycraft-$([Guid]::NewGuid().ToString('N')).tmp"
    $replaceBackup = "$Destination.milkycraft-$([Guid]::NewGuid().ToString('N')).bak"
    try {
        [IO.File]::WriteAllBytes($temporary, [IO.File]::ReadAllBytes($Source))
        [IO.File]::Replace($temporary, $Destination, $replaceBackup, $true)
    } finally {
        if (Test-Path -LiteralPath $temporary) { Remove-Item -LiteralPath $temporary -Force }
        if (Test-Path -LiteralPath $replaceBackup) { Remove-Item -LiteralPath $replaceBackup -Force }
    }
}

Assert-MinecraftStopped
if (-not (Test-Path -LiteralPath $OptionsPath -PathType Leaf)) {
    throw "options.txt does not exist yet: $OptionsPath. Launch the pack once, close Minecraft, then retry."
}
New-Item -ItemType Directory -Path $backupRoot -Force | Out-Null

if ($RestoreLatest) {
    $latestBackup = Get-ChildItem -LiteralPath $backupRoot -File -Filter 'options-before-controls-*.txt' |
        Sort-Object LastWriteTimeUtc -Descending |
        Select-Object -First 1
    if (-not $latestBackup) { throw "No control-profile backup exists in $backupRoot" }
    $restoreSafety = Join-Path $backupRoot ("options-before-restore-{0}.txt" -f (Get-Date -Format 'yyyyMMdd-HHmmss-fff'))
    [IO.File]::WriteAllBytes($restoreSafety, [IO.File]::ReadAllBytes($OptionsPath))
    Copy-BytesAtomic -Source $latestBackup.FullName -Destination $OptionsPath
    Write-Host "Restored controls from $($latestBackup.FullName)"
    Write-Host "The replaced file was preserved at $restoreSafety"
    return
}

if (-not (Test-Path -LiteralPath $ProfilePath -PathType Leaf)) {
    throw "Control profile not found: $ProfilePath"
}
$profile = Get-Content -LiteralPath $ProfilePath -Raw -Encoding UTF8 | ConvertFrom-Json
$bindings = @($profile.bindings)
if ($bindings.Count -eq 0) { throw 'The recommended control profile contains no bindings.' }
$duplicateIds = @($bindings | Group-Object id | Where-Object Count -gt 1)
if ($duplicateIds.Count -gt 0) { throw "The control profile contains duplicate IDs: $($duplicateIds.Name -join ', ')" }

$source = Read-Utf8File $OptionsPath
$updatedText = $source.Text
$changed = [Collections.Generic.List[string]]::new()
$alreadyApplied = [Collections.Generic.List[string]]::new()
$customised = [Collections.Generic.List[string]]::new()
$missing = [Collections.Generic.List[string]]::new()

foreach ($binding in $bindings) {
    $id = [string]$binding.id
    $expected = [string]$binding.from
    $target = [string]$binding.to
    if (-not $id.StartsWith('key_') -or -not $expected.StartsWith('key.') -or -not $target.StartsWith('key.')) {
        throw "Invalid profile entry for $id"
    }
    $match = [regex]::Match($updatedText, "(?m)^$([regex]::Escape($id)):([^\r\n]*)(?=\r?$)")
    if (-not $match.Success) {
        $missing.Add($id)
        continue
    }
    $current = $match.Groups[1].Value
    if ($current -eq $target) {
        $alreadyApplied.Add($id)
        continue
    }
    if ($current -ne $expected) {
        $customised.Add($id)
        continue
    }
    $replacement = "$id`:$target"
    $updatedText = $updatedText.Substring(0, $match.Index) + $replacement + $updatedText.Substring($match.Index + $match.Length)
    $changed.Add($id)
}

if ($changed.Count -gt 0) {
    $backup = Join-Path $backupRoot ("options-before-controls-{0}.txt" -f (Get-Date -Format 'yyyyMMdd-HHmmss-fff'))
    [IO.File]::WriteAllBytes($backup, $source.Bytes)
    Write-Utf8Atomic -Path $OptionsPath -Text $updatedText -WithBom $source.HasBom
    Write-Host "Applied $($changed.Count) recommended control changes."
    Write-Host "Exact backup: $backup"
} else {
    Write-Host 'No control changes were needed; no backup was created.'
}
if ($customised.Count -gt 0) {
    Write-Host "Preserved $($customised.Count) player-customised binding(s): $($customised -join ', ')"
}
if ($missing.Count -gt 0) {
    Write-Host "Skipped $($missing.Count) binding(s) not registered by this installation: $($missing -join ', ')"
}
Write-Host "Profile $($profile.profileVersion): $($alreadyApplied.Count) already applied, $($changed.Count) changed, $($customised.Count) customised, $($missing.Count) missing."
