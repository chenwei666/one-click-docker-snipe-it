@echo off
chcp 65001 >nul
setlocal
set "ROOT=%~dp0"
set "RUNNER=%ROOT%scripts\ApplyAssetNameRequiredPatch.ps1"
set "TEMP_RUNNER=%TEMP%\SnipeIT-ApplyAssetNameRequiredPatch.ps1"

net session >nul 2>&1
if %errorlevel% neq 0 (
    echo Requesting administrator permission. Please click Yes in the UAC prompt...
    powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b
)

if exist "%RUNNER%" (
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%RUNNER%" -Root "%ROOT%"
) else (
    echo [提示] 未找到 scripts\ApplyAssetNameRequiredPatch.ps1，正在使用本 bat 内置补丁...
    powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "$bat=$args[0]; $out=$args[1]; $lines=Get-Content -LiteralPath $bat -Encoding UTF8; $marker='# POWERSHELL_PAYLOAD_START'; $idx=[Array]::IndexOf($lines,$marker); if($idx -lt 0){throw 'payload marker missing'}; $payload=$lines[($idx+1)..($lines.Count-1)]; Set-Content -LiteralPath $out -Value $payload -Encoding UTF8" "%~f0" "%TEMP_RUNNER%"
    if errorlevel 1 (
        echo [错误] 无法生成临时补丁脚本。
        echo.
        pause
        exit /b 1
    )
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%TEMP_RUNNER%" -Root "%ROOT%"
)

echo.
pause
exit /b
# POWERSHELL_PAYLOAD_START
param([string]$Root = "")

$ErrorActionPreference = "Stop"
if ([string]::IsNullOrWhiteSpace($Root)) {
    $Root = (Get-Location).Path
}
$Root = [System.IO.Path]::GetFullPath($Root)
Set-Location $Root

function Write-Step { param([string]$Message) Write-Host ""; Write-Host "==> $Message" -ForegroundColor Cyan }
function Write-Ok { param([string]$Message) Write-Host "[OK] $Message" -ForegroundColor Green }
function Write-Warn { param([string]$Message) Write-Host "[提示] $Message" -ForegroundColor Yellow }
function Invoke-Checked { param([string]$File,[string[]]$Arguments) & $File @Arguments; if ($LASTEXITCODE -ne 0) { throw "命令执行失败：$File $($Arguments -join ' ')" } }
function Test-CommandAvailable { param([string]$Name) return $null -ne (Get-Command $Name -ErrorAction SilentlyContinue) }

function Ensure-Docker {
    if (-not (Test-CommandAvailable "docker")) { throw "找不到 docker 命令，请先安装并启动 Docker Desktop。" }
    & docker version *> $null
    if ($LASTEXITCODE -ne 0) { throw "Docker 引擎未运行，请先打开 Docker Desktop。" }
}

function Get-ComposeCommand {
    & docker compose version *> $null
    if ($LASTEXITCODE -eq 0) { return @{ File = "docker"; Prefix = @("compose") } }
    $localCompose = Join-Path $Root "offline-dependencies\docker-compose.exe"
    if (Test-Path -LiteralPath $localCompose) { return @{ File = $localCompose; Prefix = @() } }
    throw "找不到 Docker Compose。请确认 Docker Desktop 已安装，或 offline-dependencies\docker-compose.exe 存在。"
}

function Invoke-Compose {
    param([string[]]$Arguments,[switch]$NoThrow)
    $compose = Get-ComposeCommand
    $allArgs = @($compose.Prefix) + $Arguments
    & $compose.File @allArgs
    if (-not $NoThrow -and $LASTEXITCODE -ne 0) { throw "命令执行失败：Docker Compose $($Arguments -join ' ')" }
}

function New-EmbeddedPatchFile {
    $patchPath = Join-Path ([System.IO.Path]::GetTempPath()) "snipeit-oneclick-asset-name-required.php"
    $php = @'
<?php
declare(strict_types=1);
function find_app_root(): string {
    foreach ([getcwd(), '/var/www/html', '/var/www/html/snipe-it', '/app'] as $root) {
        if (!$root) { continue; }
        $root = rtrim($root, '/\\');
        if (is_file($root . '/app/Models/Asset.php')) { return $root; }
    }
    throw new RuntimeException('Snipe-IT application root was not found.');
}
function write_if_changed(string $path, string $content): bool {
    $old = file_get_contents($path);
    if ($old === $content) { return false; }
    $backup = $path . '.oneclick.bak';
    if (!is_file($backup)) { copy($path, $backup); }
    file_put_contents($path, $content);
    return true;
}
function patch_asset_model(string $root): void {
    $path = $root . '/app/Models/Asset.php';
    $content = file_get_contents($path);
    if (preg_match("/'name'\s*=>\s*\[[^\]]*'required'/", $content)) { echo "[OK] Asset model name validation is already required.\n"; return; }
    $updated = preg_replace("/'name'\s*=>\s*\[\s*'nullable'\s*,\s*'max:255'\s*\]/", "'name' => ['required', 'string', 'max:255']", $content, 1, $count);
    if ($count !== 1 || $updated === null) { throw new RuntimeException('Could not patch app/Models/Asset.php. The upstream validation rule changed.'); }
    write_if_changed($path, $updated);
    echo "[OK] Patched Asset model name validation.\n";
}
function patch_name_partial(string $root): void {
    $path = $root . '/resources/views/partials/forms/edit/name.blade.php';
    if (!is_file($path)) { echo "[WARN] Name partial was not found; server-side validation is still patched.\n"; return; }
    $content = file_get_contents($path);
    $updated = $content;
    $labelNeedle = '<label for="name" class="col-md-3 control-label">{{ $translated_name }}</label>';
    $labelReplacement = '<!-- oneclick-asset-name-required -->' . "\n" . '<label for="name" class="col-md-3 control-label">{{ $translated_name }} <span class="text-danger" aria-hidden="true">*</span></label>';
    if (strpos($updated, 'oneclick-asset-name-required') === false && strpos($updated, $labelNeedle) !== false) { $updated = str_replace($labelNeedle, $labelReplacement, $updated); }
    $updated = preg_replace('/\{!!\s*\(Helper::checkIfRequired\(\$item,\s*\'name\'\)\)\s*\?\s*\' required\'\s*:\s*\'\'\s*!!\}/', ' required aria-required="true"', $updated);
    if (write_if_changed($path, $updated)) { echo "[OK] Patched asset name form marker.\n"; } else { echo "[OK] Asset name form marker is already patched.\n"; }
}
function patch_hardware_edit(string $root): void {
    $path = $root . '/resources/views/hardware/edit.blade.php';
    if (!is_file($path)) { echo "[WARN] Hardware edit view was not found; server-side validation is still patched.\n"; return; }
    $content = file_get_contents($path);
    $needle = '<div id="optional_details" class="col-md-12" style="display:none">';
    $replacement = '<div id="optional_details" class="col-md-12" style="{{ $errors->has(\'name\') ? \'\' : \'display:none\' }}">';
    if (strpos($content, $replacement) !== false) { echo "[OK] Optional details error display is already patched.\n"; return; }
    if (strpos($content, $needle) === false) { echo "[WARN] Optional details block was not found; server-side validation is still patched.\n"; return; }
    write_if_changed($path, str_replace($needle, $replacement, $content));
    echo "[OK] Patched optional details error display.\n";
}
$root = find_app_root();
echo "[INFO] Snipe-IT root: {$root}\n";
patch_asset_model($root);
patch_name_partial($root);
patch_hardware_edit($root);
echo "[OK] Asset name required patch applied.\n";
'@
    Set-Content -LiteralPath $patchPath -Value $php -Encoding UTF8
    return $patchPath
}

function Find-AppContainerId {
    Write-Step "查找 Snipe-IT app 容器"
    for ($i = 1; $i -le 60; $i++) {
        $containerId = (Invoke-Compose -Arguments @("ps", "-q", "app") -NoThrow | Out-String).Trim()
        if (-not [string]::IsNullOrWhiteSpace($containerId)) { Write-Ok "找到 app 容器：$containerId"; return $containerId }
        $fallback = (& docker ps --filter "name=snipeit" --format "{{.ID}} {{.Names}}" 2>$null | Where-Object { $_ -match "app" } | Select-Object -First 1)
        if ($fallback) { $id = ($fallback -split "\s+")[0]; Write-Ok "通过容器名称找到 app 容器：$fallback"; return $id }
        Start-Sleep -Seconds 2
    }
    throw "找不到 Snipe-IT app 容器。请先确认系统已经部署并启动。"
}

try {
    Ensure-Docker
    $patchFile = New-EmbeddedPatchFile
    Write-Step "启动 app 服务（不会删除数据）"
    Invoke-Compose -Arguments @("up", "-d", "app") -NoThrow | Out-Host
    $appContainer = Find-AppContainerId
    Write-Step "复制并执行资产名称必填补丁"
    Invoke-Checked "docker" @("cp", $patchFile, "${appContainer}:/tmp/snipeit-oneclick-asset-name-required.php")
    Invoke-Checked "docker" @("exec", "-i", $appContainer, "php", "/tmp/snipeit-oneclick-asset-name-required.php")
    Write-Step "清理 Snipe-IT 缓存"
    & docker exec -i $appContainer php artisan optimize:clear
    if ($LASTEXITCODE -ne 0) { Write-Warn "缓存清理失败，但补丁可能已经应用。请刷新页面后测试。" }
    Write-Ok "完成。新增/编辑资产时，资产名称为空将无法保存。"
}
catch {
    Write-Host ""
    Write-Host "[错误] $($_.Exception.Message)" -ForegroundColor Red
    Write-Host ""
    Write-Warn "请确认：Docker Desktop 已启动；Snipe-IT 已部署；当前目录有 docker-compose.yml。"
    exit 1
}
