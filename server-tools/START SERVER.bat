@echo off
setlocal
cd /d "%~dp0"
title MilkyCraft Vanilla+ Server - Java Console
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0Start-Server.ps1" -Interactive
set "SERVER_RC=%ERRORLEVEL%"
echo.
if not "%SERVER_RC%"=="0" echo The server console exited with error code %SERVER_RC%.
echo The Minecraft server console is closed.
pause
exit /b %SERVER_RC%
