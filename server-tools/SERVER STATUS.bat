@echo off
setlocal
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Get-ServerStatus.ps1"
set "SERVER_RC=%ERRORLEVEL%"
pause
exit /b %SERVER_RC%
