[CmdletBinding()]
param(
    [string]$ServerRoot,
    [switch]$InstallRootLaunchers
)

. (Join-Path $PSScriptRoot 'Common.ps1')
$serverRootResolved = Assert-ValidServerRoot (Resolve-ServerRoot $ServerRoot)
if ($InstallRootLaunchers) { Assert-ServerStopped $serverRootResolved }
$destination = Join-Path $serverRootResolved 'packwiz-tools'
$deploymentBackupRoot = $null
if ($InstallRootLaunchers) {
    $deploymentBackupRoot = Join-Path $serverRootResolved ("server-management\deployment-backups\{0}" -f (Get-Date -Format 'yyyyMMdd-HHmmss'))
    if (Test-Path -LiteralPath $destination -PathType Container) {
        New-Item -ItemType Directory -Path $deploymentBackupRoot -Force | Out-Null
        Copy-Item -LiteralPath $destination -Destination (Join-Path $deploymentBackupRoot 'packwiz-tools') -Recurse -Force
    }
}
New-Item -ItemType Directory -Path $destination -Force | Out-Null
foreach ($file in Get-ChildItem -LiteralPath $PSScriptRoot -File) {
    if ($file.Name -eq 'Install-ServerTools.ps1') { continue }
    Copy-Item -LiteralPath $file.FullName -Destination (Join-Path $destination $file.Name) -Force
}
Write-Host "Installed Packwiz server tools without touching the running server or world: $destination"

if ($InstallRootLaunchers) {
    $launcherNames = @('run.bat', 'START SERVER - AUTO RESTART.bat', 'RUN SERVER CONSOLE.bat', 'STOP SERVER.bat', 'SERVER STATUS.bat')
    $existingLaunchers = @($launcherNames | ForEach-Object {
        $candidate = Join-Path $serverRootResolved $_
        if (Test-Path -LiteralPath $candidate -PathType Leaf) { Get-Item -LiteralPath $candidate }
    })
    $backupRoot = $null
    if ($existingLaunchers.Count -gt 0) {
        if (-not $deploymentBackupRoot) {
            $deploymentBackupRoot = Join-Path $serverRootResolved ("server-management\deployment-backups\{0}" -f (Get-Date -Format 'yyyyMMdd-HHmmss'))
        }
        $backupRoot = Join-Path $deploymentBackupRoot 'root-launchers'
        New-Item -ItemType Directory -Path $backupRoot -Force | Out-Null
        foreach ($launcher in $existingLaunchers) {
            Copy-Item -LiteralPath $launcher.FullName -Destination (Join-Path $backupRoot $launcher.Name) -Force
        }
    }

    $runLauncher = @'
@echo off
setlocal
cd /d "%~dp0"
start "" wscript.exe //NoLogo "%~dp0packwiz-tools\Launch-ServerGui.vbs" "%~dp0."
exit /b 0
'@
    $legacyStartAlias = @'
@echo off
call "%~dp0run.bat"
exit /b %ERRORLEVEL%
'@
    $debugConsoleLauncher = @'
@echo off
setlocal
cd /d "%~dp0"
title MilkyCraft Vanilla+ Server - Raw Debug Console
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0packwiz-tools\Start-Server.ps1" -ServerRoot "%~dp0." -Interactive
set "SERVER_RC=%ERRORLEVEL%"
echo.
if not "%SERVER_RC%"=="0" echo The server console exited with error code %SERVER_RC%.
echo The Minecraft server console is closed.
pause
exit /b %SERVER_RC%
'@
    $stopLauncher = @'
@echo off
setlocal
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0packwiz-tools\Stop-Server.ps1" -ServerRoot "%~dp0."
set "SERVER_RC=%ERRORLEVEL%"
pause
exit /b %SERVER_RC%
'@
    $statusLauncher = @'
@echo off
setlocal
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0packwiz-tools\Get-ServerStatus.ps1" -ServerRoot "%~dp0."
set "SERVER_RC=%ERRORLEVEL%"
pause
exit /b %SERVER_RC%
'@
    $encoding = [Text.ASCIIEncoding]::new()
    [IO.File]::WriteAllText((Join-Path $serverRootResolved 'run.bat'), $runLauncher.TrimStart() + "`r`n", $encoding)
    [IO.File]::WriteAllText((Join-Path $serverRootResolved 'START SERVER - AUTO RESTART.bat'), $legacyStartAlias.TrimStart() + "`r`n", $encoding)
    [IO.File]::WriteAllText((Join-Path $serverRootResolved 'RUN SERVER CONSOLE.bat'), $debugConsoleLauncher.TrimStart() + "`r`n", $encoding)
    [IO.File]::WriteAllText((Join-Path $serverRootResolved 'STOP SERVER.bat'), $stopLauncher.TrimStart() + "`r`n", $encoding)
    [IO.File]::WriteAllText((Join-Path $serverRootResolved 'SERVER STATUS.bat'), $statusLauncher.TrimStart() + "`r`n", $encoding)

    $legacyRuntimePaths = @('server-supervisor.ps1', 'server-supervisor.stop', 'logs\supervisor-status.json')
    $legacyRuntimeMoved = @()
    foreach ($relativeLegacyPath in $legacyRuntimePaths) {
        $legacySource = [IO.Path]::GetFullPath((Join-Path $serverRootResolved $relativeLegacyPath))
        $serverPrefix = $serverRootResolved.TrimEnd('\') + '\'
        if (-not $legacySource.StartsWith($serverPrefix, [StringComparison]::OrdinalIgnoreCase)) {
            throw "Unsafe legacy runtime source path: $legacySource"
        }
        if (-not (Test-Path -LiteralPath $legacySource -PathType Leaf)) { continue }
        if (-not $deploymentBackupRoot) {
            $deploymentBackupRoot = Join-Path $serverRootResolved ("server-management\deployment-backups\{0}" -f (Get-Date -Format 'yyyyMMdd-HHmmss'))
        }
        $legacyDestination = [IO.Path]::GetFullPath((Join-Path (Join-Path $deploymentBackupRoot 'legacy-runtime') $relativeLegacyPath))
        $backupPrefix = [IO.Path]::GetFullPath($deploymentBackupRoot).TrimEnd('\') + '\'
        if (-not $legacyDestination.StartsWith($backupPrefix, [StringComparison]::OrdinalIgnoreCase)) {
            throw "Unsafe legacy runtime backup path: $legacyDestination"
        }
        New-Item -ItemType Directory -Path (Split-Path -Parent $legacyDestination) -Force | Out-Null
        Move-Item -LiteralPath $legacySource -Destination $legacyDestination -Force
        $legacyRuntimeMoved += $relativeLegacyPath
    }

    Write-Host 'Installed root run/stop/status launchers. run.bat now opens the real Minecraft server GUI; RUN SERVER CONSOLE.bat is the raw troubleshooting terminal.'
    if ($legacyRuntimeMoved.Count -gt 0) {
        Write-Host "Quarantined retired runtime status files: $($legacyRuntimeMoved -join ', ')"
    }
    if ($deploymentBackupRoot -and (Test-Path -LiteralPath $deploymentBackupRoot)) {
        Write-Host "Previous management tools and root launchers were preserved at: $deploymentBackupRoot"
    }
}

