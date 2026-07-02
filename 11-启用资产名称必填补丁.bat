@echo off
chcp 65001 >nul
setlocal

set "ROOT=%~dp0"
set "RUNNER=%ROOT%scripts\ApplyAssetNameRequiredPatch.ps1"
set "EXITCODE=0"

cd /d "%ROOT%"

if exist "%RUNNER%" goto run
echo [ERROR] Patch script was not found:
echo "%RUNNER%"
echo.
echo Please keep the scripts folder in this Snipe-IT project folder.
set "EXITCODE=1"
goto done

:run
echo Running Snipe-IT asset-name required patch...
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%RUNNER%" -Root "%ROOT%"
set "EXITCODE=%ERRORLEVEL%"

:done
echo.
if "%EXITCODE%"=="0" (
    echo [OK] Patch command finished.
) else (
    echo [ERROR] Patch command failed. Please send a screenshot of this window.
)
echo.
pause
exit /b %EXITCODE%
