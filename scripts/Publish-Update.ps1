[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$CommitMessage,
    [string]$ProjectRoot,
    [switch]$Push
)

$ErrorActionPreference = 'Stop'
if (-not $ProjectRoot) { $ProjectRoot = Split-Path -Parent $PSScriptRoot }
$projectRootResolved = [IO.Path]::GetFullPath($ProjectRoot)
& (Join-Path $PSScriptRoot 'Update-PackMetadata.ps1') -ProjectRoot $projectRootResolved
& (Join-Path $PSScriptRoot 'Validate-Pack.ps1') -ProjectRoot $projectRootResolved

if (-not (Test-Path -LiteralPath (Join-Path $projectRootResolved '.git'))) {
    throw 'This project has not been initialised as a Git repository.'
}
Push-Location $projectRootResolved
try {
    $forbidden = @(git status --porcelain | Where-Object { $_ -match '(options\.txt|servers\.dat|launcher_accounts|accounts\.json|(^|/)world/|backups/|screenshots/|crash-reports/)' })
    if ($forbidden.Count -gt 0) { throw "Refusing to publish personal/world data:`n$($forbidden -join "`n")" }
    git add -- .
    git commit -m $CommitMessage
    if ($LASTEXITCODE -ne 0) { throw 'git commit failed (or there were no changes).' }
    if ($Push) {
        git push
        if ($LASTEXITCODE -ne 0) { throw 'git push failed.' }
    }
} finally {
    Pop-Location
}
Write-Host 'Update committed. Existing clients will receive it on their next launch after it is pushed.'

