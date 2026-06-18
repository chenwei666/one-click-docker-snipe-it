@echo off
chcp 65001 >nul
setlocal

set "ROOT=%~dp0"
set "APP=%ROOT%launcher\SnipeItLauncher.py"

if not exist "%APP%" (
  echo [错误] 找不到启动器源码：%APP%
  pause
  exit /b 1
)

echo 正在生成图形化 EXE，请稍等...
cd /d "%ROOT%"

python "%ROOT%launcher\make_icon.py"
if errorlevel 1 (
  echo.
  echo [失败] 图标生成失败。
  pause
  exit /b 1
)

python -m PyInstaller ^
  --clean ^
  --noconfirm ^
  --onefile ^
  --windowed ^
  --uac-admin ^
  --icon "%ROOT%assets\app-icon.ico" ^
  --name "Snipe-IT-OneClick" ^
  "%APP%"

if errorlevel 1 (
  echo.
  echo [失败] EXE 生成失败，请确认 Python 和 PyInstaller 已安装。
  pause
  exit /b 1
)

copy /Y "%ROOT%dist\Snipe-IT-OneClick.exe" "%ROOT%Snipe-IT-OneClick.exe" >nul

echo.
echo [完成] 已生成：
echo %ROOT%Snipe-IT-OneClick.exe
echo %ROOT%dist\Snipe-IT-OneClick.exe
pause
