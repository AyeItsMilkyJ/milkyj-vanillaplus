[CmdletBinding()]
param([string]$ProjectRoot)

$ErrorActionPreference = 'Stop'
if (-not $ProjectRoot) { $ProjectRoot = Split-Path -Parent $PSScriptRoot }
$root = [IO.Path]::GetFullPath($ProjectRoot)
$output = Join-Path $root 'audit\repository-files.csv'
$rootPrefix = $root.TrimEnd('\') + '\'
$rows = @()
foreach ($file in Get-ChildItem -LiteralPath $root -Recurse -File -Force) {
    $relative = [IO.Path]::GetFullPath($file.FullName).Substring($rootPrefix.Length).Replace('\','/')
    if ($relative -eq 'audit/repository-files.csv' -or $relative -match '^(\.git|build|dist|\.tools)/|(^|/)__pycache__/|\.pyc$') { continue }
    $role = switch -Regex ($relative) {
        '^packwiz/mods/' { 'Packwiz mod metadata'; break }
        '^packwiz/' { 'Packwiz pack/index/file metadata'; break }
        '^payload/' { 'Hosted managed payload'; break }
        '^audit/' { 'Audit/report'; break }
        '^bootstrap/' { 'Prism bootstrap template'; break }
        '^server-tools/' { 'Dedicated-server safety/update tooling'; break }
        '^scripts/' { 'Maintainer/build/validation tooling'; break }
        '^docs/' { 'Documentation'; break }
        '^\.github/' { 'Continuous validation'; break }
        default { 'Repository control/documentation' }
    }
    $rows += [pscustomobject]@{
        Path = $relative
        Bytes = $file.Length
        Sha256 = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
        Role = $role
    }
}
$rows += [pscustomobject]@{ Path='audit/repository-files.csv'; Bytes='self'; Sha256='self-generated'; Role='Complete repository file inventory' }
$rows | Sort-Object Path | Export-Csv -LiteralPath $output -NoTypeInformation -Encoding utf8
Write-Host "Wrote $($rows.Count) repository file records: $output"
