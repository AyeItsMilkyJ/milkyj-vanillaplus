@echo off
setlocal
cd /d "%~dp0"
start "" wscript.exe //NoLogo "%~dp0Launch-ServerGui.vbs" "%~dp0.."
exit /b 0
