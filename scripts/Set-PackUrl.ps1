[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidatePattern('^(https://|http://127\.0\.0\.1(?::\d+)?(?:/|$))')]
    [string]$RawRepositoryBaseUrl,

    [string]$ProjectRoot = (Split-Path -Parent $PSScriptRoot)
)

$ErrorActionPreference = 'Stop'
$projectRootResolved = [IO.Path]::GetFullPath($ProjectRoot)
$settingsPath = Join-Path $projectRootResolved 'project-settings.json'
$rawBase = $RawRepositoryBaseUrl.TrimEnd('/')
$packUrl = "$rawBase/packwiz/pack.toml"

$settings = Get-Content -LiteralPath $settingsPath -Raw | ConvertFrom-Json
$settings.rawRepositoryBaseUrl = $rawBase
$settings.packUrl = $packUrl
$settings | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $settingsPath -Encoding utf8

$metadataFiles = Get-ChildItem -LiteralPath (Join-Path $projectRootResolved 'packwiz') -Recurse -File -Filter *.pw.toml
$changed = 0
foreach ($file in $metadataFiles) {
    $text = Get-Content -LiteralPath $file.FullName -Raw
    if ($text -notmatch '(?m)^url\s*=\s*"https?://[^\"]+/payload/') {
        continue
    }
    $newText = [regex]::Replace(
        $text,
        '(?m)^(url\s*=\s*")https?://[^\"]+(/payload/)',
        ('$1' + $rawBase + '$2')
    )
    if ($newText -ne $text) {
        [IO.File]::WriteAllText($file.FullName, $newText, [Text.UTF8Encoding]::new($false))
        $changed++
    }
}

$templatePath = Join-Path $projectRootResolved 'bootstrap\template\instance.cfg'
$template = Get-Content -LiteralPath $templatePath -Raw
$template = [regex]::Replace(
    $template,
    '(?m)^PreLaunchCommand=.*$',
    ('PreLaunchCommand=\"$INST_JAVA\" -jar packwiz-installer-bootstrap.jar ' + $packUrl)
)
[IO.File]::WriteAllText($templatePath, $template, [Text.UTF8Encoding]::new($false))

$serverSettingsPath = Join-Path $projectRootResolved 'server-tools\server-settings.json'
if (Test-Path -LiteralPath $serverSettingsPath) {
    $serverSettings = Get-Content -LiteralPath $serverSettingsPath -Raw | ConvertFrom-Json
    $serverSettings.packUrl = $packUrl
    $serverSettings | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $serverSettingsPath -Encoding utf8
}

& (Join-Path $PSScriptRoot 'Update-PackMetadata.ps1') -ProjectRoot $projectRootResolved
Write-Host "Configured $changed hosted payload references."
Write-Host "Final Packwiz URL: $packUrl"
