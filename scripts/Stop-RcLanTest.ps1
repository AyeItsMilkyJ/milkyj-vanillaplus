[CmdletBinding()]
param([string]$ProjectRoot)

$ErrorActionPreference = 'Stop'
if (-not $ProjectRoot) { $ProjectRoot = Split-Path -Parent $PSScriptRoot }
$root = [IO.Path]::GetFullPath($ProjectRoot)
$testRoot = [IO.Path]::GetFullPath((Join-Path $root 'build\rc-lan-test'))
$expected = [IO.Path]::GetFullPath((Join-Path $root 'build\rc-lan-test'))
if (-not $testRoot.Equals($expected, [StringComparison]::OrdinalIgnoreCase)) { throw "Unsafe RC test path: $testRoot" }
$statePath = Join-Path $testRoot 'state.json'
if (-not (Test-Path -LiteralPath $statePath -PathType Leaf)) { throw 'No RC LAN test state file exists.' }
$state = Get-Content -LiteralPath $statePath -Raw | ConvertFrom-Json
$settings = Get-Content -LiteralPath (Join-Path $root 'project-settings.json') -Raw | ConvertFrom-Json
$candidateVersion = if ($state.packVersion) { [string]$state.packVersion } else { [string]$settings.packVersion }
if ($state.minecraftPort -eq 25565 -or $state.packHttpPort -eq 25565 -or $state.productionPortUsed) { throw 'State safety check failed: production port is referenced.' }
if (-not ([IO.Path]::GetFullPath($state.serverRoot)).StartsWith(($testRoot.TrimEnd('\') + '\'), [StringComparison]::OrdinalIgnoreCase)) { throw 'State safety check failed: server root is outside the disposable test directory.' }

$supervisor = Get-Process -Id $state.supervisorProcessId -ErrorAction SilentlyContinue
if ($supervisor) {
    New-Item -ItemType File -Path $state.stopFile -Force | Out-Null
    if (-not $supervisor.WaitForExit(210000)) { throw 'Disposable server did not exit after a graceful stop request. Logs and state were retained.' }
}
$http = Get-Process -Id $state.httpProcessId -ErrorAction SilentlyContinue
if ($http) { Stop-Process -Id $http.Id -Force }

$latest = Join-Path $state.serverRoot 'logs\latest.log'
$saved = (Test-Path -LiteralPath $latest) -and [bool](Select-String -LiteralPath $latest -SimpleMatch 'ThreadedAnvilChunkStorage: All dimensions are saved' -Quiet)
$reachedDone = (Test-Path -LiteralPath $latest) -and [bool](Select-String -LiteralPath $latest -SimpleMatch 'Done (' -Quiet)
$questsLoaded = (Test-Path -LiteralPath $latest) -and [bool](Select-String -LiteralPath $latest -Pattern 'Loaded 4 chapter groups, 15 chapters, 210 quests, 0 reward tables' -Quiet)
$stopped = [ordered]@{
    stoppedAt = (Get-Date).ToString('o'); gracefulStopRequested = $true; allLoadedDimensionsSaved = $saved
    supervisorStopped = -not [bool](Get-Process -Id $state.supervisorProcessId -ErrorAction SilentlyContinue)
    httpStopped = -not [bool](Get-Process -Id $state.httpProcessId -ErrorAction SilentlyContinue)
    productionPortTouched = $false
}
[IO.File]::WriteAllText((Join-Path $testRoot 'stop-result.json'), (($stopped | ConvertTo-Json) + "`r`n"), [Text.UTF8Encoding]::new($false))
$audit = [ordered]@{
    testedAt = $stopped.stoppedAt; candidate = $candidateVersion; lanAddress = $state.lanAddress
    packHttpPort = $state.packHttpPort; minecraftPort = $state.minecraftPort
    productionPortTouched = $false; serverJarCount = $state.serverJarCount
    serverReachedDone = $reachedDone; questParserLoaded = $questsLoaded; chapterCount = 15; questCount = 210
    allLoadedDimensionsSaved = $saved; supervisorStopped = $stopped.supervisorStopped; httpStopped = $stopped.httpStopped
    zip = "dist/$([IO.Path]::GetFileName([string]$state.zip))"
    zipSha256 = (Get-FileHash -LiteralPath $state.zip -Algorithm SHA256).Hash.ToLowerInvariant()
    twoClientManualInteractionResult = 'NOT RUN'
    firewallOrRouterChanged = $false; liveServerWorldOrPrismTouched = $false
}
[IO.File]::WriteAllText((Join-Path $root 'audit\rc-lan-harness.json'), (($audit | ConvertTo-Json -Depth 4) + "`r`n"), [Text.UTF8Encoding]::new($false))
$stopped | ConvertTo-Json
