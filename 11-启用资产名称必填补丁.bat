@echo off
chcp 65001 >nul
setlocal
set "ROOT=%~dp0"
set "RUNNER=%ROOT%scripts\ApplyAssetNameRequiredPatch.ps1"
set "TEMP_RUNNER=%TEMP%\SnipeIT-ApplyAssetNameRequiredPatch.ps1"
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
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "$prefix='::PS::'; $payload=New-Object System.Collections.Generic.List[string]; foreach($line in [System.IO.File]::ReadLines($args[0])){ if($line.StartsWith($prefix)){ $payload.Add($line.Substring($prefix.Length)) } }; if($payload.Count -eq 0){ throw 'payload missing' }; [System.IO.File]::WriteAllLines($args[1], $payload, [System.Text.UTF8Encoding]::new($false))" "%~f0" "%TEMP_RUNNER%"
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
::PS::if ([string]::IsNullOrWhiteSpace($Root)) {
::PS::    $Root = (Get-Location).Path
::PS::}
::PS::$Root = [System.IO.Path]::GetFullPath($Root)
::PS::Set-Location $Root
::PS::
::PS::function Write-Step { param([string]$Message) Write-Host ""; Write-Host "==> $Message" -ForegroundColor Cyan }
::PS::function Write-Ok { param([string]$Message) Write-Host "[OK] $Message" -ForegroundColor Green }
::PS::function Write-Warn { param([string]$Message) Write-Host "[提示] $Message" -ForegroundColor Yellow }
::PS::function Invoke-Checked { param([string]$File,[string[]]$Arguments) & $File @Arguments; if ($LASTEXITCODE -ne 0) { throw "命令执行失败：$File $($Arguments -join ' ')" } }
::PS::function Test-CommandAvailable { param([string]$Name) return $null -ne (Get-Command $Name -ErrorAction SilentlyContinue) }
::PS::
::PS::function Ensure-Docker {
::PS::    if (-not (Test-CommandAvailable "docker")) { throw "找不到 docker 命令，请先安装并启动 Docker Desktop。" }
::PS::    & docker version *> $null
::PS::    if ($LASTEXITCODE -ne 0) { throw "Docker 引擎未运行，请先打开 Docker Desktop。" }
::PS::}
::PS::
::PS::function Get-ComposeCommand {
::PS::    & docker compose version *> $null
::PS::    if ($LASTEXITCODE -eq 0) { return @{ File = "docker"; Prefix = @("compose") } }
::PS::    $localCompose = Join-Path $Root "offline-dependencies\docker-compose.exe"
::PS::    if (Test-Path -LiteralPath $localCompose) { return @{ File = $localCompose; Prefix = @() } }
::PS::    throw "找不到 Docker Compose。请确认 Docker Desktop 已安装，或 offline-dependencies\docker-compose.exe 存在。"
::PS::}
::PS::
::PS::function Invoke-Compose {
::PS::    param([string[]]$Arguments,[switch]$NoThrow)
::PS::    $compose = Get-ComposeCommand
::PS::    $allArgs = @($compose.Prefix) + $Arguments
::PS::    & $compose.File @allArgs
::PS::    if (-not $NoThrow -and $LASTEXITCODE -ne 0) { throw "命令执行失败：Docker Compose $($Arguments -join ' ')" }
::PS::}
::PS::
::PS::function New-EmbeddedPatchFile {
::PS::    $patchPath = Join-Path ([System.IO.Path]::GetTempPath()) "snipeit-oneclick-asset-name-required.php"
::PS::    $php = @'
::PS::<?php
::PS::declare(strict_types=1);
::PS::function find_app_root(): string {
::PS::    foreach ([getcwd(), '/var/www/html', '/var/www/html/snipe-it', '/app'] as $root) {
::PS::        if (!$root) { continue; }
::PS::        $root = rtrim($root, '/\\');
::PS::        if (is_file($root . '/app/Models/Asset.php')) { return $root; }
::PS::    }
::PS::    throw new RuntimeException('Snipe-IT application root was not found.');
::PS::}
::PS::function write_if_changed(string $path, string $content): bool {
::PS::    $old = file_get_contents($path);
::PS::    if ($old === $content) { return false; }
::PS::    $backup = $path . '.oneclick.bak';
::PS::    if (!is_file($backup)) { copy($path, $backup); }
::PS::    file_put_contents($path, $content);
::PS::    return true;
::PS::}
::PS::function patch_asset_model(string $root): void {
::PS::    $path = $root . '/app/Models/Asset.php';
::PS::    $content = file_get_contents($path);
::PS::    if (preg_match("/'name'\s*=>\s*\[[^\]]*'required'/", $content)) { echo "[OK] Asset model name validation is already required.\n"; return; }
::PS::    $updated = preg_replace("/'name'\s*=>\s*\[\s*'nullable'\s*,\s*'max:255'\s*\]/", "'name' => ['required', 'string', 'max:255']", $content, 1, $count);
::PS::    if ($count !== 1 || $updated === null) { throw new RuntimeException('Could not patch app/Models/Asset.php. The upstream validation rule changed.'); }
::PS::    write_if_changed($path, $updated);
::PS::    echo "[OK] Patched Asset model name validation.\n";
::PS::}
::PS::function patch_name_partial(string $root): void {
::PS::    $path = $root . '/resources/views/partials/forms/edit/name.blade.php';
::PS::    if (!is_file($path)) { echo "[WARN] Name partial was not found; server-side validation is still patched.\n"; return; }
::PS::    $content = file_get_contents($path);
::PS::    $updated = $content;
::PS::    $labelNeedle = '<label for="name" class="col-md-3 control-label">{{ $translated_name }}</label>';
::PS::    $labelReplacement = '<!-- oneclick-asset-name-required -->' . "\n" . '<label for="name" class="col-md-3 control-label">{{ $translated_name }} <span class="text-danger" aria-hidden="true">*</span></label>';
::PS::    if (strpos($updated, 'oneclick-asset-name-required') === false && strpos($updated, $labelNeedle) !== false) { $updated = str_replace($labelNeedle, $labelReplacement, $updated); }
::PS::    $updated = preg_replace('/\{!!\s*\(Helper::checkIfRequired\(\$item,\s*\'name\'\)\)\s*\?\s*\' required\'\s*:\s*\'\'\s*!!\}/', ' required aria-required="true"', $updated);
::PS::    if (write_if_changed($path, $updated)) { echo "[OK] Patched asset name form marker.\n"; } else { echo "[OK] Asset name form marker is already patched.\n"; }
::PS::}
::PS::function patch_hardware_edit(string $root): void {
::PS::    $path = $root . '/resources/views/hardware/edit.blade.php';
::PS::    if (!is_file($path)) { echo "[WARN] Hardware edit view was not found; server-side validation is still patched.\n"; return; }
::PS::    $content = file_get_contents($path);
::PS::    $needle = '<div id="optional_details" class="col-md-12" style="display:none">';
::PS::    $replacement = '<div id="optional_details" class="col-md-12" style="{{ $errors->has(\'name\') ? \'\' : \'display:none\' }}">';
::PS::    if (strpos($content, $replacement) !== false) { echo "[OK] Optional details error display is already patched.\n"; return; }
::PS::    if (strpos($content, $needle) === false) { echo "[WARN] Optional details block was not found; server-side validation is still patched.\n"; return; }
::PS::    write_if_changed($path, str_replace($needle, $replacement, $content));
::PS::    echo "[OK] Patched optional details error display.\n";
::PS::}
::PS::$root = find_app_root();
::PS::echo "[INFO] Snipe-IT root: {$root}\n";
::PS::patch_asset_model($root);
::PS::patch_name_partial($root);
::PS::patch_hardware_edit($root);
::PS::echo "[OK] Asset name required patch applied.\n";
::PS::'@
::PS::    Set-Content -LiteralPath $patchPath -Value $php -Encoding UTF8
::PS::    return $patchPath
::PS::}
::PS::
::PS::function Find-AppContainerId {
::PS::    Write-Step "查找 Snipe-IT app 容器"
::PS::    for ($i = 1; $i -le 60; $i++) {
::PS::        $containerId = (Invoke-Compose -Arguments @("ps", "-q", "app") -NoThrow | Out-String).Trim()
::PS::        if (-not [string]::IsNullOrWhiteSpace($containerId)) { Write-Ok "找到 app 容器：$containerId"; return $containerId }
::PS::        $fallback = (& docker ps --filter "name=snipeit" --format "{{.ID}} {{.Names}}" 2>$null | Where-Object { $_ -match "app" } | Select-Object -First 1)
::PS::        if ($fallback) { $id = ($fallback -split "\s+")[0]; Write-Ok "通过容器名称找到 app 容器：$fallback"; return $id }
::PS::        Start-Sleep -Seconds 2
::PS::    }
::PS::    throw "找不到 Snipe-IT app 容器。请先确认系统已经部署并启动。"
::PS::}
::PS::
::PS::try {
::PS::    Ensure-Docker
::PS::    $patchFile = New-EmbeddedPatchFile
::PS::    Write-Step "启动 app 服务（不会删除数据）"
::PS::    Invoke-Compose -Arguments @("up", "-d", "app") -NoThrow | Out-Host
::PS::    $appContainer = Find-AppContainerId
::PS::    Write-Step "复制并执行资产名称必填补丁"
::PS::    Invoke-Checked "docker" @("cp", $patchFile, "${appContainer}:/tmp/snipeit-oneclick-asset-name-required.php")
::PS::    Invoke-Checked "docker" @("exec", "-i", $appContainer, "php", "/tmp/snipeit-oneclick-asset-name-required.php")
::PS::    Write-Step "清理 Snipe-IT 缓存"
::PS::    & docker exec -i $appContainer php artisan optimize:clear
::PS::    if ($LASTEXITCODE -ne 0) { Write-Warn "缓存清理失败，但补丁可能已经应用。请刷新页面后测试。" }
::PS::    Write-Ok "完成。新增/编辑资产时，资产名称为空将无法保存。"
::PS::}
::PS::catch {
::PS::    Write-Host ""
::PS::    Write-Host "[错误] $($_.Exception.Message)" -ForegroundColor Red
::PS::    Write-Host ""
::PS::    Write-Warn "请确认：Docker Desktop 已启动；Snipe-IT 已部署；当前目录有 docker-compose.yml。"
::PS::    exit 1
::PS::}
