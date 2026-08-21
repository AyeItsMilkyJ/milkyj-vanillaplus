[CmdletBinding()]
param(
    [string]$ProjectRoot,
    [string]$LanAddress,
    [int]$PackHttpPort = 8765,
    [int]$MinecraftPort = 25566,
    [string]$ForgeLibrariesPath
)

$ErrorActionPreference = 'Stop'
if (-not $ProjectRoot) { $ProjectRoot = Split-Path -Parent $PSScriptRoot }
if ($MinecraftPort -eq 25565 -or $PackHttpPort -eq 25565) { throw 'Port 25565 is production-reserved and cannot be used by the RC harness.' }
if ($MinecraftPort -eq $PackHttpPort) { throw 'The Packwiz HTTP and Minecraft ports must be different.' }
if ($PackHttpPort -lt 1024 -or $PackHttpPort -gt 65535 -or $MinecraftPort -lt 1024 -or $MinecraftPort -gt 65535) { throw 'Test ports must be between 1024 and 65535.' }

$root = [IO.Path]::GetFullPath($ProjectRoot)
$testRoot = [IO.Path]::GetFullPath((Join-Path $root 'build\rc-lan-test'))
$expectedRoot = [IO.Path]::GetFullPath((Join-Path $root 'build\rc-lan-test'))
if (-not $testRoot.Equals($expectedRoot, [StringComparison]::OrdinalIgnoreCase)) { throw "Unsafe RC test path: $testRoot" }
$statePath = Join-Path $testRoot 'state.json'
if (Test-Path -LiteralPath $statePath) {
    $oldState = Get-Content -LiteralPath $statePath -Raw | ConvertFrom-Json
    foreach ($pidValue in @($oldState.httpProcessId, $oldState.supervisorProcessId)) {
        if ($pidValue -and (Get-Process -Id $pidValue -ErrorAction SilentlyContinue)) { throw 'An RC LAN test appears to be running. Use Stop-RcLanTest.ps1 first.' }
    }
}

function Test-PrivateV4([string]$Value) {
    $parsed = $null
    if (-not [Net.IPAddress]::TryParse($Value, [ref]$parsed)) { return $false }
    if ($parsed.AddressFamily -ne [Net.Sockets.AddressFamily]::InterNetwork) { return $false }
    $bytes = $parsed.GetAddressBytes()
    return ($bytes[0] -eq 10) -or ($bytes[0] -eq 172 -and $bytes[1] -ge 16 -and $bytes[1] -le 31) -or ($bytes[0] -eq 192 -and $bytes[1] -eq 168)
}

if (-not $LanAddress) {
    $candidate = Get-NetIPAddress -AddressFamily IPv4 -ErrorAction Stop |
        Where-Object { $_.AddressState -eq 'Preferred' -and (Test-PrivateV4 $_.IPAddress) } |
        Sort-Object InterfaceMetric |
        Select-Object -First 1
    if (-not $candidate) { throw 'No preferred RFC1918 LAN address was found. Pass -LanAddress explicitly.' }
    $LanAddress = $candidate.IPAddress
}
if (-not (Test-PrivateV4 $LanAddress)) { throw 'LanAddress must be an RFC1918 IPv4 address (10/8, 172.16/12, or 192.168/16).' }
foreach ($port in @($PackHttpPort, $MinecraftPort)) {
    if (Get-NetTCPConnection -State Listen -LocalPort $port -ErrorAction SilentlyContinue) { throw "Port $port is already in use." }
}

& (Join-Path $PSScriptRoot 'Validate-Pack.ps1') -ProjectRoot $root -AllowPlaceholder
if (Test-Path -LiteralPath $testRoot) { Remove-Item -LiteralPath $testRoot -Recurse -Force }
$hostRoot = Join-Path $testRoot 'host'
$serverRoot = Join-Path $testRoot 'server'
$logRoot = Join-Path $testRoot 'logs'
New-Item -ItemType Directory -Path $hostRoot, $serverRoot, $logRoot -Force | Out-Null
Copy-Item -LiteralPath (Join-Path $root 'packwiz') -Destination (Join-Path $hostRoot 'packwiz') -Recurse
Copy-Item -LiteralPath (Join-Path $root 'payload') -Destination (Join-Path $hostRoot 'payload') -Recurse

$baseUrl = "http://${LanAddress}:$PackHttpPort"
$packUrl = "$baseUrl/packwiz/pack.toml"
foreach ($metadata in Get-ChildItem -LiteralPath (Join-Path $hostRoot 'packwiz') -Recurse -File -Filter '*.pw.toml') {
    $text = [IO.File]::ReadAllText($metadata.FullName)
    if ($text -notmatch '(?m)^url\s*=\s*"https?://[^"]+/payload/') { continue }
    $updated = [regex]::Replace($text, '(?m)^(url\s*=\s*")https?://[^"]+(/payload/)', ('$1' + $baseUrl + '$2'))
    [IO.File]::WriteAllText($metadata.FullName, $updated, [Text.UTF8Encoding]::new($false))
}
& (Join-Path $PSScriptRoot 'Update-PackMetadata.ps1') -ProjectRoot $hostRoot
& (Join-Path $PSScriptRoot 'Validate-Pack.ps1') -ProjectRoot $hostRoot -AllowPlaceholder -AllowPrivateLan

$zip = Join-Path $root 'dist\MilkyJ-VanillaPlus-1.9.0-rc2-LAN-TEST-Prism.zip'
& (Join-Path $PSScriptRoot 'Build-Prism-Bootstrap.ps1') -ProjectRoot $root -PackUrl $packUrl -OutputPath $zip -AllowPrivateLan

. (Join-Path $root 'server-tools\Common.ps1')
$java = Find-Java17 $null
$bootstrap = & (Join-Path $PSScriptRoot 'Get-PackwizInstaller.ps1') -ProjectRoot $root -PassThru
Copy-Item -LiteralPath $bootstrap -Destination (Join-Path $serverRoot 'packwiz-installer-bootstrap.jar')
$python = (Get-Command python -ErrorAction Stop).Source
$httpProcess = Start-Process -FilePath $python -ArgumentList @(
    ('"' + (Join-Path $PSScriptRoot 'limited_http_server.py') + '"'), '--bind', $LanAddress,
    '--port', "$PackHttpPort", '--directory', ('"' + $hostRoot + '"'), '--workers', '24'
) -WindowStyle Hidden -RedirectStandardOutput (Join-Path $logRoot 'http.stdout.log') -RedirectStandardError (Join-Path $logRoot 'http.stderr.log') -PassThru
try {
    $ready = $false
    $deadline = (Get-Date).AddSeconds(20)
    do {
        try { $null = Invoke-WebRequest -Uri $packUrl -UseBasicParsing -TimeoutSec 2; $ready = $true } catch { Start-Sleep -Milliseconds 250 }
    } while (-not $ready -and (Get-Date) -lt $deadline)
    if (-not $ready) { throw 'The LAN Packwiz host did not become ready.' }

    Push-Location $serverRoot
    try { & $java -jar 'packwiz-installer-bootstrap.jar' -g -s server $packUrl; $installExit = $LASTEXITCODE } finally { Pop-Location }
    if ($installExit -ne 0) { throw "Disposable server Packwiz install failed with exit code $installExit." }
    $serverJars = @(Get-ChildItem -LiteralPath (Join-Path $serverRoot 'mods') -File -Filter '*.jar').Count
    if ($serverJars -ne 206) { throw "Expected 206 server JARs; found $serverJars." }

    if (-not $ForgeLibrariesPath) { $ForgeLibrariesPath = Join-Path $root '.tools\forge-libraries' }
    $forge = [IO.Path]::GetFullPath($ForgeLibrariesPath)
    if (-not (Test-Path -LiteralPath (Join-Path $forge 'net\minecraftforge\forge\1.20.1-47.4.10\win_args.txt'))) { throw "Missing disposable Forge libraries: $forge" }
    Copy-Item -LiteralPath $forge -Destination (Join-Path $serverRoot 'libraries') -Recurse
    [IO.File]::WriteAllText((Join-Path $serverRoot 'eula.txt'), "eula=true`r`n", [Text.UTF8Encoding]::new($false))
    [IO.File]::WriteAllText((Join-Path $serverRoot 'user_jvm_args.txt'), "-Xms1G`r`n-Xmx4G`r`n", [Text.UTF8Encoding]::new($false))
    $properties = @(
        'allow-flight=true', 'difficulty=normal', 'enable-command-block=false', 'gamemode=survival',
        'level-name=rc_lan_test_world', 'max-players=4', 'motd=MilkyCraft Vanilla+ 1.9.0-rc2 LAN TEST',
        'online-mode=true', "server-ip=$LanAddress", "server-port=$MinecraftPort", 'simulation-distance=4',
        'spawn-protection=0', 'view-distance=6', 'white-list=false'
    ) -join "`r`n"
    [IO.File]::WriteAllText((Join-Path $serverRoot 'server.properties'), ($properties + "`r`n"), [Text.UTF8Encoding]::new($false))

    $stopFile = Join-Path $testRoot 'stop.request'
    $processInfo = Join-Path $testRoot 'server-process.json'
    $supervisor = Start-Process -FilePath $python -ArgumentList @(
        ('"' + (Join-Path $PSScriptRoot 'rc_lan_server_supervisor.py') + '"'),
        '--server-root', ('"' + $serverRoot + '"'), '--java', ('"' + $java + '"'),
        '--stop-file', ('"' + $stopFile + '"'), '--process-info', ('"' + $processInfo + '"'),
        '--stdout', ('"' + (Join-Path $logRoot 'server.stdout.log') + '"'),
        '--stderr', ('"' + (Join-Path $logRoot 'server.stderr.log') + '"')
    ) -WindowStyle Hidden -PassThru

    $state = [ordered]@{
        startedAt = (Get-Date).ToString('o'); testRoot = $testRoot; hostRoot = $hostRoot; serverRoot = $serverRoot
        lanAddress = $LanAddress; packHttpPort = $PackHttpPort; minecraftPort = $MinecraftPort
        packUrl = $packUrl; minecraftAddress = "${LanAddress}:$MinecraftPort"
        httpProcessId = $httpProcess.Id; supervisorProcessId = $supervisor.Id
        stopFile = $stopFile; zip = $zip; serverJarCount = $serverJars; productionPortUsed = $false
    }
    [IO.File]::WriteAllText($statePath, (($state | ConvertTo-Json -Depth 4) + "`r`n"), [Text.UTF8Encoding]::new($false))
    $latest = Join-Path $serverRoot 'logs\latest.log'
    $done = $false
    $deadline = (Get-Date).AddMinutes(6)
    do {
        Start-Sleep -Seconds 2
        if (Test-Path -LiteralPath $latest) { $done = [bool](Select-String -LiteralPath $latest -SimpleMatch 'Done (' -Quiet) }
        if ($supervisor.HasExited -and -not $done) { break }
    } while (-not $done -and (Get-Date) -lt $deadline)
    if (-not $done) { New-Item -ItemType File -Path $stopFile -Force | Out-Null; throw 'Disposable LAN server did not reach Done. Logs are in build/rc-lan-test/logs.' }
    Write-Host "LAN Packwiz URL: $packUrl"
    Write-Host "Disposable Minecraft server: ${LanAddress}:$MinecraftPort"
    Write-Host "Prism LAN-test ZIP: $zip"
    Write-Host 'No firewall, router, production server, world, whitelist, ops list, or playerdata changes were made.'
} catch {
    if ($httpProcess -and -not $httpProcess.HasExited) { Stop-Process -Id $httpProcess.Id -Force }
    throw
}
