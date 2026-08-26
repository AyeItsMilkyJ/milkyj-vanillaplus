@echo off
setlocal
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Apply-RecommendedControls.ps1" -MinecraftRoot "%~dp0..\.." -RestoreLatest
if errorlevel 1 (
  echo.
  echo Controls were not restored. Read the error above.
)
echo.
pause
