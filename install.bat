@echo off
chcp 65001 >nul
set "ROOT=%~dp0"

net session >nul 2>&1
if %errorlevel% neq 0 (
    echo Requesting administrator permission. Please click Yes in the UAC prompt...
    powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b
)

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%ROOT%scripts\SnipeIt-OneClick.ps1" -Action BootstrapDeploy
echo.
pause
