@echo off
setlocal
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Configure-DiscordNotifications.ps1"
pause
