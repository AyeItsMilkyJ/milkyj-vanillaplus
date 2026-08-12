[CmdletBinding()]
param(
    [string]$ProjectRoot = (Split-Path -Parent $PSScriptRoot),
    [int]$Port = 8765
)

$ErrorActionPreference = 'Stop'
$projectRootResolved = [IO.Path]::GetFullPath($ProjectRoot)
$hostRoot = [IO.Path]::GetFullPath((Join-Path $projectRootResolved 'build\rc-local-host'))
$expected = [IO.Path]::GetFullPath((Join-Path $projectRootResolved 'build\rc-local-host'))
if (-not $hostRoot.Equals($expected, [StringComparison]::OrdinalIgnoreCase)) { throw "Unsafe test host path: $hostRoot" }
if (Test-Path -LiteralPath $hostRoot) { Remove-Item -LiteralPath $hostRoot -Recurse -Force }
New-Item -ItemType Directory -Path $hostRoot -Force | Out-Null
Copy-Item -LiteralPath (Join-Path $projectRootResolved 'packwiz') -Destination (Join-Path $hostRoot 'packwiz') -Recurse
Copy-Item -LiteralPath (Join-Path $projectRootResolved 'payload') -Destination (Join-Path $hostRoot 'payload') -Recurse

$localBase = "http://127.0.0.1:$Port"
foreach ($metadata in Get-ChildItem -LiteralPath (Join-Path $hostRoot 'packwiz') -Recurse -File -Filter '*.pw.toml') {
    $text = [IO.File]::ReadAllText($metadata.FullName)
    if ($text -notmatch '(?m)^url\s*=\s*"https?://[^"]+/payload/') { continue }
    $updated = [regex]::Replace($text, '(?m)^(url\s*=\s*")https?://[^"]+(/payload/)', ('$1' + $localBase + '$2'))
    [IO.File]::WriteAllText($metadata.FullName, $updated, [Text.UTF8Encoding]::new($false))
}
& (Join-Path $PSScriptRoot 'Update-PackMetadata.ps1') -ProjectRoot $hostRoot
& (Join-Path $PSScriptRoot 'Validate-Pack.ps1') -ProjectRoot $hostRoot -AllowPlaceholder

$output = Join-Path $projectRootResolved 'dist\MilkyJ-VanillaPlus-1.9.0-rc1-LOCAL-TEST-Prism.zip'
& (Join-Path $PSScriptRoot 'Build-Prism-Bootstrap.ps1') -ProjectRoot $projectRootResolved -PackUrl "$localBase/packwiz/pack.toml" -OutputPath $output

$result = [ordered]@{
    preparedAt = (Get-Date).ToString('o')
    releaseCandidate = '1.9.0-rc1'
    hostDirectory = 'build/rc-local-host'
    packUrl = "$localBase/packwiz/pack.toml"
    bootstrap = 'dist/MilkyJ-VanillaPlus-1.9.0-rc1-LOCAL-TEST-Prism.zip'
    bootstrapSha256 = (Get-FileHash -LiteralPath $output -Algorithm SHA256).Hash.ToLowerInvariant()
    serverCommand = "python scripts\limited_http_server.py --port $Port --directory build\rc-local-host --workers 24"
    productionFilesTouched = $false
}
[IO.File]::WriteAllText((Join-Path $projectRootResolved 'audit\local-rc-test.json'), (($result | ConvertTo-Json -Depth 4) + "`r`n"), [Text.UTF8Encoding]::new($false))
$result | ConvertTo-Json -Depth 4
