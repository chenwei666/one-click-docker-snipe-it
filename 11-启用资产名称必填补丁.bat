@echo off
chcp 65001 >nul
setlocal
set "ROOT=%~dp0"
set "RUNNER=%ROOT%scripts\ApplyAssetNameRequiredPatch.ps1"
set "TEMP_RUNNER=%TEMP%\SnipeIT-ApplyAssetNameRequiredPatch.ps1"
set "BAT_SELF=%~f0"
set "EXITCODE=0"

net session >nul 2>&1
if %errorlevel% neq 0 goto elevate
goto run

:elevate
echo Requesting administrator permission. Please click Yes in the UAC prompt...
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
exit /b

:run
if exist "%RUNNER%" goto run_file
goto run_embedded

:run_file
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%RUNNER%" -Root "%ROOT%"
set "EXITCODE=%ERRORLEVEL%"
goto done

:run_embedded
echo [提示] 未找到 scripts\ApplyAssetNameRequiredPatch.ps1，正在使用本 bat 内置补丁...
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "$bat=$env:BAT_SELF; $out=$env:TEMP_RUNNER; $prefix='::PS::'; $payload=New-Object System.Collections.Generic.List[string]; foreach($line in [System.IO.File]::ReadLines($bat)){ if($line.StartsWith($prefix)){ $payload.Add($line.Substring($prefix.Length)) } }; if($payload.Count -eq 0){ throw 'payload missing' }; [System.IO.File]::WriteAllLines($out, $payload, [System.Text.UTF8Encoding]::new($true))"
if errorlevel 1 goto extract_failed
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%TEMP_RUNNER%" -Root "%ROOT%"
set "EXITCODE=%ERRORLEVEL%"
goto done

:extract_failed
set "EXITCODE=1"
echo [错误] 无法生成临时补丁脚本。
goto done

:done
echo.
if "%EXITCODE%"=="0" goto success_pause
echo [错误] 补丁执行失败。请把这个窗口截图发给我。

:success_pause
pause
exit /b %EXITCODE%

::POWERSHELL_PAYLOAD_START
::PS::param([string]$Root = "")
::PS::
::PS::$ErrorActionPreference = "Stop"
::PS::
::PS::if ([string]::IsNullOrWhiteSpace($Root)) {
::PS::    $ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
::PS::    $Root = Split-Path -Parent $ScriptDir
::PS::}
::PS::
::PS::$Root = [System.IO.Path]::GetFullPath($Root)
::PS::Set-Location $Root
::PS::
::PS::function Write-Step {
::PS::    param([string]$Message)
::PS::    Write-Host ""
::PS::    Write-Host "==> $Message" -ForegroundColor Cyan
::PS::}
::PS::
::PS::function Write-Ok {
::PS::    param([string]$Message)
::PS::    Write-Host "[OK] $Message" -ForegroundColor Green
::PS::}
::PS::
::PS::function Write-Warn {
::PS::    param([string]$Message)
::PS::    Write-Host "[提示] $Message" -ForegroundColor Yellow
::PS::}
::PS::
::PS::function Invoke-Checked {
::PS::    param(
::PS::        [string]$File,
::PS::        [string[]]$Arguments
::PS::    )
::PS::
::PS::    & $File @Arguments
::PS::    if ($LASTEXITCODE -ne 0) {
::PS::        throw "命令执行失败：$File $($Arguments -join ' ')"
::PS::    }
::PS::}
::PS::
::PS::function Test-CommandAvailable {
::PS::    param([string]$Name)
::PS::    return $null -ne (Get-Command $Name -ErrorAction SilentlyContinue)
::PS::}
::PS::
::PS::function Ensure-Docker {
::PS::    if (-not (Test-CommandAvailable "docker")) {
::PS::        throw "找不到 docker 命令，请先安装并启动 Docker Desktop。"
::PS::    }
::PS::
::PS::    & docker version *> $null
::PS::    if ($LASTEXITCODE -ne 0) {
::PS::        throw "Docker 引擎未运行，请先打开 Docker Desktop。"
::PS::    }
::PS::}
::PS::
::PS::function Get-ComposeCommand {
::PS::    & docker compose version *> $null
::PS::    if ($LASTEXITCODE -eq 0) {
::PS::        return @{ File = "docker"; Prefix = @("compose") }
::PS::    }
::PS::
::PS::    $localCompose = Join-Path $Root "offline-dependencies\docker-compose.exe"
::PS::    if (Test-Path -LiteralPath $localCompose) {
::PS::        return @{ File = $localCompose; Prefix = @() }
::PS::    }
::PS::
::PS::    throw "找不到 Docker Compose。请确认 Docker Desktop 已安装，或 offline-dependencies\docker-compose.exe 存在。"
::PS::}
::PS::
::PS::function Invoke-Compose {
::PS::    param(
::PS::        [string[]]$Arguments,
::PS::        [switch]$NoThrow
::PS::    )
::PS::
::PS::    $compose = Get-ComposeCommand
::PS::    $allArgs = @($compose.Prefix) + $Arguments
::PS::    & $compose.File @allArgs
::PS::    if (-not $NoThrow -and $LASTEXITCODE -ne 0) {
::PS::        throw "命令执行失败：Docker Compose $($Arguments -join ' ')"
::PS::    }
::PS::}
::PS::
::PS::function New-EmbeddedPatchFile {
::PS::    $patchPath = Join-Path ([System.IO.Path]::GetTempPath()) "snipeit-oneclick-asset-name-required.php"
::PS::    $chunks = @(
::PS::        'PD9waHAKZGVjbGFyZShzdHJpY3RfdHlwZXM9MSk7CgpmdW5jdGlvbiBmaW5kX2FwcF9yb290KCk6IHN0cmluZwp7CiAgICAk'
::PS::        'Y2FuZGlkYXRlcyA9IFsKICAgICAgICBnZXRjd2QoKSwKICAgICAgICBkaXJuYW1lKF9fRElSX18sIDIpLAogICAgICAgICcv'
::PS::        'dmFyL3d3dy9odG1sJywKICAgICAgICAnL3Zhci93d3cvaHRtbC9zbmlwZS1pdCcsCiAgICAgICAgJy9hcHAnLAogICAgXTsK'
::PS::        'CiAgICBmb3JlYWNoICgkY2FuZGlkYXRlcyBhcyAkcm9vdCkgewogICAgICAgIGlmICghJHJvb3QpIHsKICAgICAgICAgICAg'
::PS::        'Y29udGludWU7CiAgICAgICAgfQogICAgICAgICRhc3NldCA9IHJ0cmltKCRyb290LCAnL1xcJykgLiAnL2FwcC9Nb2RlbHMv'
::PS::        'QXNzZXQucGhwJzsKICAgICAgICBpZiAoaXNfZmlsZSgkYXNzZXQpKSB7CiAgICAgICAgICAgIHJldHVybiBydHJpbSgkcm9v'
::PS::        'dCwgJy9cXCcpOwogICAgICAgIH0KICAgIH0KCiAgICB0aHJvdyBuZXcgUnVudGltZUV4Y2VwdGlvbignU25pcGUtSVQgYXBw'
::PS::        'bGljYXRpb24gcm9vdCB3YXMgbm90IGZvdW5kLicpOwp9CgpmdW5jdGlvbiB3cml0ZV9pZl9jaGFuZ2VkKHN0cmluZyAkcGF0'
::PS::        'aCwgc3RyaW5nICRjb250ZW50KTogYm9vbAp7CiAgICAkb2xkID0gZmlsZV9nZXRfY29udGVudHMoJHBhdGgpOwogICAgaWYg'
::PS::        'KCRvbGQgPT09ICRjb250ZW50KSB7CiAgICAgICAgcmV0dXJuIGZhbHNlOwogICAgfQoKICAgICRiYWNrdXAgPSAkcGF0aCAu'
::PS::        'ICcub25lY2xpY2suYmFrJzsKICAgIGlmICghaXNfZmlsZSgkYmFja3VwKSkgewogICAgICAgIGNvcHkoJHBhdGgsICRiYWNr'
::PS::        'dXApOwogICAgfQoKICAgIGZpbGVfcHV0X2NvbnRlbnRzKCRwYXRoLCAkY29udGVudCk7CiAgICByZXR1cm4gdHJ1ZTsKfQoK'
::PS::        'ZnVuY3Rpb24gcGF0Y2hfYXNzZXRfbW9kZWwoc3RyaW5nICRyb290KTogYm9vbAp7CiAgICAkcGF0aCA9ICRyb290IC4gJy9h'
::PS::        'cHAvTW9kZWxzL0Fzc2V0LnBocCc7CiAgICAkY29udGVudCA9IGZpbGVfZ2V0X2NvbnRlbnRzKCRwYXRoKTsKCiAgICBpZiAo'
::PS::        'cHJlZ19tYXRjaCgiLyduYW1lJ1xzKj0+XHMqXFtbXlxdXSoncmVxdWlyZWQnLyIsICRjb250ZW50KSkgewogICAgICAgIGVj'
::PS::        'aG8gIltPS10gQXNzZXQgbW9kZWwgbmFtZSB2YWxpZGF0aW9uIGlzIGFscmVhZHkgcmVxdWlyZWQuXG4iOwogICAgICAgIHJl'
::PS::        'dHVybiBmYWxzZTsKICAgIH0KCiAgICAkdXBkYXRlZCA9IHByZWdfcmVwbGFjZSgKICAgICAgICAiLyduYW1lJ1xzKj0+XHMq'
::PS::        'XFtccyonbnVsbGFibGUnXHMqLFxzKidtYXg6MjU1J1xzKlxdLyIsCiAgICAgICAgIiduYW1lJyA9PiBbJ3JlcXVpcmVkJywg'
::PS::        'J3N0cmluZycsICdtYXg6MjU1J10iLAogICAgICAgICRjb250ZW50LAogICAgICAgIDEsCiAgICAgICAgJGNvdW50CiAgICAp'
::PS::        'OwoKICAgIGlmICgkY291bnQgIT09IDEgfHwgJHVwZGF0ZWQgPT09IG51bGwpIHsKICAgICAgICB0aHJvdyBuZXcgUnVudGlt'
::PS::        'ZUV4Y2VwdGlvbignQ291bGQgbm90IHBhdGNoIGFwcC9Nb2RlbHMvQXNzZXQucGhwLiBUaGUgdXBzdHJlYW0gdmFsaWRhdGlv'
::PS::        'biBydWxlIGNoYW5nZWQuJyk7CiAgICB9CgogICAgd3JpdGVfaWZfY2hhbmdlZCgkcGF0aCwgJHVwZGF0ZWQpOwogICAgZWNo'
::PS::        'byAiW09LXSBQYXRjaGVkIEFzc2V0IG1vZGVsIG5hbWUgdmFsaWRhdGlvbi5cbiI7CiAgICByZXR1cm4gdHJ1ZTsKfQoKZnVu'
::PS::        'Y3Rpb24gcGF0Y2hfbmFtZV9wYXJ0aWFsKHN0cmluZyAkcm9vdCk6IGJvb2wKewogICAgJHBhdGggPSAkcm9vdCAuICcvcmVz'
::PS::        'b3VyY2VzL3ZpZXdzL3BhcnRpYWxzL2Zvcm1zL2VkaXQvbmFtZS5ibGFkZS5waHAnOwogICAgaWYgKCFpc19maWxlKCRwYXRo'
::PS::        'KSkgewogICAgICAgIGVjaG8gIltXQVJOXSBOYW1lIHBhcnRpYWwgd2FzIG5vdCBmb3VuZDsgc2VydmVyLXNpZGUgdmFsaWRh'
::PS::        'dGlvbiBpcyBzdGlsbCBwYXRjaGVkLlxuIjsKICAgICAgICByZXR1cm4gZmFsc2U7CiAgICB9CgogICAgJGNvbnRlbnQgPSBm'
::PS::        'aWxlX2dldF9jb250ZW50cygkcGF0aCk7CiAgICAkdXBkYXRlZCA9ICRjb250ZW50OwoKICAgICRsYWJlbE5lZWRsZSA9IDw8'
::PS::        'PCdCTEFERScKPGxhYmVsIGZvcj0ibmFtZSIgY2xhc3M9ImNvbC1tZC0zIGNvbnRyb2wtbGFiZWwiPnt7ICR0cmFuc2xhdGVk'
::PS::        'X25hbWUgfX08L2xhYmVsPgpCTEFERTsKICAgICRsYWJlbFJlcGxhY2VtZW50ID0gPDw8J0JMQURFJwo8bGFiZWwgZm9yPSJu'
::PS::        'YW1lIiBjbGFzcz0iY29sLW1kLTMgY29udHJvbC1sYWJlbCI+e3sgJHRyYW5zbGF0ZWRfbmFtZSB9fSA8c3BhbiBjbGFzcz0i'
::PS::        'dGV4dC1kYW5nZXIiIGFyaWEtaGlkZGVuPSJ0cnVlIj4qPC9zcGFuPjwvbGFiZWw+CkJMQURFOwogICAgaWYgKHN0cnBvcygk'
::PS::        'dXBkYXRlZCwgJ29uZWNsaWNrLWFzc2V0LW5hbWUtcmVxdWlyZWQnKSA9PT0gZmFsc2UgJiYgc3RycG9zKCR1cGRhdGVkLCAk'
::PS::        'bGFiZWxOZWVkbGUpICE9PSBmYWxzZSkgewogICAgICAgICR1cGRhdGVkID0gc3RyX3JlcGxhY2UoJGxhYmVsTmVlZGxlLCAi'
::PS::        'PCEtLSBvbmVjbGljay1hc3NldC1uYW1lLXJlcXVpcmVkIC0tPlxuIiAuICRsYWJlbFJlcGxhY2VtZW50LCAkdXBkYXRlZCk7'
::PS::        'CiAgICB9CgogICAgJGlucHV0TmVlZGxlID0gPDw8J0JMQURFJwo8aW5wdXQgY2xhc3M9ImZvcm0tY29udHJvbCIgc3R5bGU9'
::PS::        'IndpZHRoOjEwMCU7IiB0eXBlPSJ0ZXh0IiBuYW1lPSJuYW1lIiBhcmlhLWxhYmVsPSJuYW1lIiBpZD0ibmFtZSIgdmFsdWU9'
::PS::        'Int7IG9sZCgnbmFtZScsICRpdGVtLT5uYW1lKSB9fSJ7ISEgIChIZWxwZXI6OmNoZWNrSWZSZXF1aXJlZCgkaXRlbSwgJ25h'
::PS::        'bWUnKSkgPyAnIHJlcXVpcmVkJyA6ICcnICEhfSBtYXhsZW5ndGg9IjE5MSIgLz4KQkxBREU7CiAgICAkaW5wdXRSZXBsYWNl'
::PS::        'bWVudCA9IDw8PCdCTEFERScKPGlucHV0IGNsYXNzPSJmb3JtLWNvbnRyb2wiIHN0eWxlPSJ3aWR0aDoxMDAlOyIgdHlwZT0i'
::PS::        'dGV4dCIgbmFtZT0ibmFtZSIgYXJpYS1sYWJlbD0ibmFtZSIgaWQ9Im5hbWUiIHZhbHVlPSJ7eyBvbGQoJ25hbWUnLCAkaXRl'
::PS::        'bS0+bmFtZSkgfX0iIGFyaWEtcmVxdWlyZWQ9InRydWUiIG1heGxlbmd0aD0iMTkxIiAvPgpCTEFERTsKICAgIGlmIChzdHJw'
::PS::        'b3MoJHVwZGF0ZWQsICRpbnB1dE5lZWRsZSkgIT09IGZhbHNlKSB7CiAgICAgICAgJHVwZGF0ZWQgPSBzdHJfcmVwbGFjZSgk'
::PS::        'aW5wdXROZWVkbGUsICRpbnB1dFJlcGxhY2VtZW50LCAkdXBkYXRlZCk7CiAgICB9CgogICAgaWYgKHdyaXRlX2lmX2NoYW5n'
::PS::        'ZWQoJHBhdGgsICR1cGRhdGVkKSkgewogICAgICAgIGVjaG8gIltPS10gUGF0Y2hlZCBhc3NldCBuYW1lIGZvcm0gbWFya2Vy'
::PS::        'LlxuIjsKICAgICAgICByZXR1cm4gdHJ1ZTsKICAgIH0KCiAgICBlY2hvICJbT0tdIEFzc2V0IG5hbWUgZm9ybSBtYXJrZXIg'
::PS::        'aXMgYWxyZWFkeSBwYXRjaGVkLlxuIjsKICAgIHJldHVybiBmYWxzZTsKfQoKZnVuY3Rpb24gcGF0Y2hfaGFyZHdhcmVfZWRp'
::PS::        'dChzdHJpbmcgJHJvb3QpOiBib29sCnsKICAgICRwYXRoID0gJHJvb3QgLiAnL3Jlc291cmNlcy92aWV3cy9oYXJkd2FyZS9l'
::PS::        'ZGl0LmJsYWRlLnBocCc7CiAgICBpZiAoIWlzX2ZpbGUoJHBhdGgpKSB7CiAgICAgICAgZWNobyAiW1dBUk5dIEhhcmR3YXJl'
::PS::        'IGVkaXQgdmlldyB3YXMgbm90IGZvdW5kOyBzZXJ2ZXItc2lkZSB2YWxpZGF0aW9uIGlzIHN0aWxsIHBhdGNoZWQuXG4iOwog'
::PS::        'ICAgICAgIHJldHVybiBmYWxzZTsKICAgIH0KCiAgICAkY29udGVudCA9IGZpbGVfZ2V0X2NvbnRlbnRzKCRwYXRoKTsKICAg'
::PS::        'ICRuZWVkbGUgPSAnPGRpdiBpZD0ib3B0aW9uYWxfZGV0YWlscyIgY2xhc3M9ImNvbC1tZC0xMiIgc3R5bGU9ImRpc3BsYXk6'
::PS::        'bm9uZSI+JzsKICAgICRyZXBsYWNlbWVudCA9ICc8ZGl2IGlkPSJvcHRpb25hbF9kZXRhaWxzIiBjbGFzcz0iY29sLW1kLTEy'
::PS::        'IiBzdHlsZT0ie3sgJGVycm9ycy0+aGFzKFwnbmFtZVwnKSA/IFwnXCcgOiBcJ2Rpc3BsYXk6bm9uZVwnIH19Ij4nOwoKICAg'
::PS::        'IGlmIChzdHJwb3MoJGNvbnRlbnQsICRyZXBsYWNlbWVudCkgIT09IGZhbHNlKSB7CiAgICAgICAgZWNobyAiW09LXSBPcHRp'
::PS::        'b25hbCBkZXRhaWxzIGVycm9yIGRpc3BsYXkgaXMgYWxyZWFkeSBwYXRjaGVkLlxuIjsKICAgICAgICByZXR1cm4gZmFsc2U7'
::PS::        'CiAgICB9CgogICAgaWYgKHN0cnBvcygkY29udGVudCwgJG5lZWRsZSkgPT09IGZhbHNlKSB7CiAgICAgICAgZWNobyAiW1dB'
::PS::        'Uk5dIE9wdGlvbmFsIGRldGFpbHMgYmxvY2sgd2FzIG5vdCBmb3VuZDsgc2VydmVyLXNpZGUgdmFsaWRhdGlvbiBpcyBzdGls'
::PS::        'bCBwYXRjaGVkLlxuIjsKICAgICAgICByZXR1cm4gZmFsc2U7CiAgICB9CgogICAgJHVwZGF0ZWQgPSBzdHJfcmVwbGFjZSgk'
::PS::        'bmVlZGxlLCAkcmVwbGFjZW1lbnQsICRjb250ZW50KTsKICAgIHdyaXRlX2lmX2NoYW5nZWQoJHBhdGgsICR1cGRhdGVkKTsK'
::PS::        'ICAgIGVjaG8gIltPS10gUGF0Y2hlZCBvcHRpb25hbCBkZXRhaWxzIGVycm9yIGRpc3BsYXkuXG4iOwogICAgcmV0dXJuIHRy'
::PS::        'dWU7Cn0KCiRyb290ID0gZmluZF9hcHBfcm9vdCgpOwplY2hvICJbSU5GT10gU25pcGUtSVQgcm9vdDogeyRyb290fVxuIjsK'
::PS::        'CnBhdGNoX2Fzc2V0X21vZGVsKCRyb290KTsKcGF0Y2hfbmFtZV9wYXJ0aWFsKCRyb290KTsKcGF0Y2hfaGFyZHdhcmVfZWRp'
::PS::        'dCgkcm9vdCk7CgplY2hvICJbT0tdIEFzc2V0IG5hbWUgcmVxdWlyZWQgcGF0Y2ggYXBwbGllZC5cbiI7Cg=='
::PS::    )
::PS::    $bytes = [Convert]::FromBase64String(($chunks -join ""))
::PS::    [System.IO.File]::WriteAllBytes($patchPath, $bytes)
::PS::    return $patchPath
::PS::}
::PS::function Get-PatchFile {
::PS::    $packaged = Join-Path $Root "patches\asset-name-required\apply.php"
::PS::    if (Test-Path -LiteralPath $packaged) {
::PS::        return $packaged
::PS::    }
::PS::
::PS::    Write-Warn "没有找到 patches\asset-name-required\apply.php，将使用脚本内置补丁。"
::PS::    return New-EmbeddedPatchFile
::PS::}
::PS::
::PS::function Find-AppContainerId {
::PS::    Write-Step "查找 Snipe-IT app 容器"
::PS::
::PS::    for ($i = 1; $i -le 60; $i++) {
::PS::        $containerId = (Invoke-Compose -Arguments @("ps", "-q", "app") -NoThrow | Out-String).Trim()
::PS::        if (-not [string]::IsNullOrWhiteSpace($containerId)) {
::PS::            Write-Ok "找到 app 容器：$containerId"
::PS::            return $containerId
::PS::        }
::PS::
::PS::        $fallback = (& docker ps --filter "name=snipeit" --format "{{.ID}} {{.Names}}" 2>$null |
::PS::            Where-Object { $_ -match "app" } |
::PS::            Select-Object -First 1)
::PS::        if ($fallback) {
::PS::            $id = ($fallback -split "\s+")[0]
::PS::            Write-Ok "通过容器名称找到 app 容器：$fallback"
::PS::            return $id
::PS::        }
::PS::
::PS::        Start-Sleep -Seconds 2
::PS::    }
::PS::
::PS::    throw "找不到 Snipe-IT app 容器。请先确认系统已经部署并启动。"
::PS::}
::PS::
::PS::function Apply-Patch {
::PS::    Ensure-Docker
::PS::    $patchFile = Get-PatchFile
::PS::
::PS::    Write-Step "启动 app 服务（不会删除数据）"
::PS::    Invoke-Compose -Arguments @("up", "-d", "app") -NoThrow | Out-Host
::PS::
::PS::    $appContainer = Find-AppContainerId
::PS::
::PS::    Write-Step "复制并执行资产名称必填补丁"
::PS::    Invoke-Checked "docker" @("cp", $patchFile, "${appContainer}:/tmp/snipeit-oneclick-asset-name-required.php")
::PS::    Invoke-Checked "docker" @("exec", "-i", $appContainer, "php", "/tmp/snipeit-oneclick-asset-name-required.php")
::PS::
::PS::    Write-Step "清理 Snipe-IT 缓存"
::PS::    & docker exec -i $appContainer php artisan optimize:clear
::PS::    if ($LASTEXITCODE -ne 0) {
::PS::        Write-Warn "缓存清理失败，但补丁可能已经应用。请刷新页面后测试。"
::PS::    }
::PS::
::PS::    Write-Ok "完成。新增/编辑资产时，资产名称为空将无法保存。"
::PS::}
::PS::
::PS::try {
::PS::    Apply-Patch
::PS::}
::PS::catch {
::PS::    Write-Host ""
::PS::    Write-Host "[错误] $($_.Exception.Message)" -ForegroundColor Red
::PS::    Write-Host ""
::PS::    Write-Warn "请确认：Docker Desktop 已启动；Snipe-IT 已部署；当前目录有 docker-compose.yml。"
::PS::    exit 1
::PS::}
