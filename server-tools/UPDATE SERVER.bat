@echo off
setlocal
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Update-And-Start-Server.ps1" -ServerGui
set "SERVER_RC=%ERRORLEVEL%"
pause
exit /b %SERVER_RC%
