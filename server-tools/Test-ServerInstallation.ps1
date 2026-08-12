[CmdletBinding()]
param([string]$ServerRoot)

. (Join-Path $PSScriptRoot 'Common.ps1')
$root = Assert-ValidServerRoot (Resolve-ServerRoot $ServerRoot)
$errors = @()
foreach ($required in @('server.properties','eula.txt','user_jvm_args.txt','libraries','mods','config','packwiz.json')) {
    if (-not (Test-Path -LiteralPath (Join-Path $root $required))) { $errors += "missing $required" }
}
$jarCount = if (Test-Path -LiteralPath (Join-Path $root 'mods')) { @(Get-ChildItem -LiteralPath (Join-Path $root 'mods') -File -Filter '*.jar').Count } else { 0 }
if ($jarCount -eq 0) { $errors += 'mods contains no JAR files' }
if ($errors) { throw "Server installation validation failed: $($errors -join '; ')" }
[pscustomobject]@{ valid=$true; serverRoot=$root; modJarCount=$jarCount; port=Get-ServerPort $root }
