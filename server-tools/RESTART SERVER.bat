@echo off
setlocal
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Restart-Server.ps1"
set "SERVER_RC=%ERRORLEVEL%"
pause
exit /b %SERVER_RC%
