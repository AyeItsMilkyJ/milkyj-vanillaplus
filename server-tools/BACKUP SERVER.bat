@echo off
setlocal
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Backup-Server.ps1" -RestartIfRunning
set "SERVER_RC=%ERRORLEVEL%"
pause
exit /b %SERVER_RC%
