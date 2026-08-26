[CmdletBinding()]
param(
    [string]$ProjectRoot
)

$ErrorActionPreference = 'Stop'
if (-not $ProjectRoot) { $ProjectRoot = Split-Path -Parent $PSScriptRoot }
$projectRootResolved = [IO.Path]::GetFullPath($ProjectRoot)
$patcher = Join-Path $projectRootResolved 'payload\client\scripts\milkycraft-controls\Apply-RecommendedControls.ps1'
$profilePath = Join-Path $projectRootResolved 'payload\client\scripts\milkycraft-controls\recommended-controls.json'
$testRoot = Join-Path $projectRootResolved 'build\recommended-controls-test'
$auditPath = Join-Path $projectRootResolved 'audit\control-profile-validation.json'

if (-not $testRoot.StartsWith(($projectRootResolved.TrimEnd('\') + '\'), [StringComparison]::OrdinalIgnoreCase)) {
    throw "Unsafe controls test path: $testRoot"
}
if (Test-Path -LiteralPath $testRoot) { Remove-Item -LiteralPath $testRoot -Recurse -Force }
New-Item -ItemType Directory -Path $testRoot -Force | Out-Null

$profile = Get-Content -LiteralPath $profilePath -Raw -Encoding UTF8 | ConvertFrom-Json
$bindings = @($profile.bindings)
if ($bindings.Count -ne 24) { throw "Expected 24 recommended bindings; found $($bindings.Count)." }

$guardRoot = Join-Path $testRoot 'process-guard'
New-Item -ItemType Directory -Path $guardRoot -Force | Out-Null
$guardOptions = Join-Path $guardRoot 'options.txt'
[IO.File]::WriteAllText($guardOptions, "version:3465`r`n", [Text.UTF8Encoding]::new($false))
$guardHash = (Get-FileHash -LiteralPath $guardOptions -Algorithm SHA256).Hash
$forwardSlashRoot = $guardRoot.Replace('\', '/')
$guardBlocked = $false
try {
    & $patcher -MinecraftRoot $guardRoot -ProfilePath $profilePath -ProcessCommandLines @("javaw.exe --gameDir `"$forwardSlashRoot`" --launchTarget forgeclient")
} catch {
    $guardBlocked = $_.Exception.Message -like '*Minecraft is using this instance*'
}
if (-not $guardBlocked) { throw 'The running-game guard did not detect a forward-slash Prism gameDir.' }
if ((Get-FileHash -LiteralPath $guardOptions -Algorithm SHA256).Hash -ne $guardHash) {
    throw 'The running-game guard allowed options.txt to change.'
}

$customBinding = $bindings[0]
$customValue = 'key.keyboard.k:ALT'
$lines = [Collections.Generic.List[string]]::new()
$lines.Add('version:3465')
$lines.Add('resourcePacks:["vanilla","file/MilkyJ Stability Fixes"]')
$lines.Add('renderDistance:18')
$lines.Add('key_key.chat:key.keyboard.t')
foreach ($binding in $bindings) {
    $value = if ($binding.id -eq $customBinding.id) { $customValue } else { [string]$binding.from }
    $lines.Add("$($binding.id):$value")
}
$lines.Add('soundCategory_master:0.8')
$originalText = ($lines -join "`r`n") + "`r`n"
$optionsPath = Join-Path $testRoot 'options.txt'
[IO.File]::WriteAllBytes($optionsPath, [Text.UTF8Encoding]::new($false).GetBytes($originalText))
$originalHash = (Get-FileHash -LiteralPath $optionsPath -Algorithm SHA256).Hash

& $patcher -MinecraftRoot $testRoot -ProfilePath $profilePath -SkipProcessCheck
$afterFirst = [IO.File]::ReadAllText($optionsPath, [Text.Encoding]::UTF8)
$afterFirstHash = (Get-FileHash -LiteralPath $optionsPath -Algorithm SHA256).Hash
foreach ($binding in $bindings) {
    $expected = if ($binding.id -eq $customBinding.id) { $customValue } else { [string]$binding.to }
    if ($afterFirst -notmatch "(?m)^$([regex]::Escape([string]$binding.id)):$([regex]::Escape($expected))(?=\r?$)") {
        throw "Recommended control was not applied or preserved correctly: $($binding.id)"
    }
}

function Mask-ManagedBindings([string]$Text, [object[]]$ManagedBindings) {
    $masked = $Text
    foreach ($binding in $ManagedBindings) {
        $id = [string]$binding.id
        $masked = [regex]::Replace($masked, "(?m)^$([regex]::Escape($id)):[^\r\n]*(?=\r?$)", "$id`:<managed>")
    }
    return $masked
}
if ((Mask-ManagedBindings $originalText $bindings) -cne (Mask-ManagedBindings $afterFirst $bindings)) {
    throw 'The patcher changed data outside the declared key bindings.'
}

$backupsAfterFirst = @(Get-ChildItem -LiteralPath (Join-Path $testRoot 'milkycraft-control-backups') -File -Filter 'options-before-controls-*.txt')
if ($backupsAfterFirst.Count -ne 1) { throw 'The first application did not create exactly one backup.' }
if ((Get-FileHash -LiteralPath $backupsAfterFirst[0].FullName -Algorithm SHA256).Hash -ne $originalHash) {
    throw 'The pre-change backup is not byte-identical to the original options file.'
}

& $patcher -MinecraftRoot $testRoot -ProfilePath $profilePath -SkipProcessCheck
$backupsAfterSecond = @(Get-ChildItem -LiteralPath (Join-Path $testRoot 'milkycraft-control-backups') -File -Filter 'options-before-controls-*.txt')
if ($backupsAfterSecond.Count -ne 1) { throw 'Idempotent application created an unnecessary second backup.' }
if ((Get-FileHash -LiteralPath $optionsPath -Algorithm SHA256).Hash -ne $afterFirstHash) {
    throw 'Idempotent application changed options.txt on the second run.'
}

& $patcher -MinecraftRoot $testRoot -ProfilePath $profilePath -RestoreLatest -SkipProcessCheck
$restoredHash = (Get-FileHash -LiteralPath $optionsPath -Algorithm SHA256).Hash
if ($restoredHash -ne $originalHash) { throw 'Restore did not reproduce the original options file byte-for-byte.' }
$restoreSafety = @(Get-ChildItem -LiteralPath (Join-Path $testRoot 'milkycraft-control-backups') -File -Filter 'options-before-restore-*.txt')
if ($restoreSafety.Count -ne 1 -or (Get-FileHash -LiteralPath $restoreSafety[0].FullName -Algorithm SHA256).Hash -ne $afterFirstHash) {
    throw 'Restore did not preserve the replaced options file byte-for-byte.'
}

$bomRoot = Join-Path $testRoot 'bom-lf'
New-Item -ItemType Directory -Path $bomRoot -Force | Out-Null
$bomOptions = Join-Path $bomRoot 'options.txt'
$presentBindings = @($bindings | Select-Object -First ($bindings.Count - 1))
$bomLines = [Collections.Generic.List[string]]::new()
$bomLines.Add('version:3465')
foreach ($binding in $presentBindings) { $bomLines.Add("$($binding.id):$($binding.from)") }
$bomText = ($bomLines -join "`n") + "`n"
$bomEncoding = [Text.UTF8Encoding]::new($true)
$bomBody = $bomEncoding.GetBytes($bomText)
$bomPreamble = $bomEncoding.GetPreamble()
$bomBytes = [byte[]]::new($bomPreamble.Length + $bomBody.Length)
[Array]::Copy($bomPreamble, 0, $bomBytes, 0, $bomPreamble.Length)
[Array]::Copy($bomBody, 0, $bomBytes, $bomPreamble.Length, $bomBody.Length)
[IO.File]::WriteAllBytes($bomOptions, $bomBytes)
& $patcher -MinecraftRoot $bomRoot -ProfilePath $profilePath -SkipProcessCheck
$bomAfter = [IO.File]::ReadAllBytes($bomOptions)
if ($bomAfter.Length -lt 3 -or $bomAfter[0] -ne 0xEF -or $bomAfter[1] -ne 0xBB -or $bomAfter[2] -ne 0xBF) {
    throw 'The patcher did not preserve the UTF-8 BOM.'
}
$bomAfterText = [Text.Encoding]::UTF8.GetString($bomAfter, 3, $bomAfter.Length - 3)
if ($bomAfterText.Contains("`r`n")) { throw 'The patcher changed LF newlines to CRLF.' }
if ($bomAfterText -match "(?m)^$([regex]::Escape([string]$bindings[-1].id)):") {
    throw 'The patcher invented a missing key binding.'
}

$report = [ordered]@{
    testedAt = (Get-Date).ToString('o')
    status = 'PASS'
    profileVersion = [string]$profile.profileVersion
    declaredBindings = $bindings.Count
    changedUntouchedDefaults = $bindings.Count - 1
    preservedCustomBindings = 1
    missingBindings = 0
    nonKeySettingsByteStable = $true
    crlfPreserved = $true
    utf8BomAndLfPreserved = $true
    missingBindingSkipped = $true
    forwardSlashGameDirGuard = $true
    exactBackupVerified = $true
    idempotentSecondRun = $true
    exactRestoreVerified = $true
    restoreSafetyBackupVerified = $true
    optionsPackwizManaged = $false
    testInstallation = 'disposable'
}
[IO.File]::WriteAllText($auditPath, (($report | ConvertTo-Json -Depth 10) + "`r`n"), [Text.UTF8Encoding]::new($false))
Write-Host "Recommended controls validation passed. Report: $auditPath"
