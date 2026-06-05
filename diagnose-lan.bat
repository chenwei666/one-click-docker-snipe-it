@echo off
chcp 65001 >nul
set "ROOT=%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%ROOT%scripts\SnipeIt-OneClick.ps1" -Action Diagnose
echo.
pause
