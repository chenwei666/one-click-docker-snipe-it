@echo off
chcp 65001 >nul
setlocal
set "ROOT=%~dp0"
call "%ROOT%11-启用资产名称必填补丁.bat"
