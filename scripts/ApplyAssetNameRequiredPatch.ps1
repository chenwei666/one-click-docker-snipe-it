param()

$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$Root = Split-Path -Parent $ScriptDir
Set-Location $Root

$PatchFile = Join-Path $Root "patches\asset-name-required\apply.php"

function Write-Step {
    param([string]$Message)
    Write-Host ""
    Write-Host "==> $Message" -ForegroundColor Cyan
}

function Write-Ok {
    param([string]$Message)
    Write-Host "[OK] $Message" -ForegroundColor Green
}

function Write-Warn {
    param([string]$Message)
    Write-Host "[提示] $Message" -ForegroundColor Yellow
}

function Invoke-Checked {
    param(
        [string]$File,
        [string[]]$Arguments
    )

    & $File @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "命令执行失败：$File $($Arguments -join ' ')"
    }
}

function Test-CommandAvailable {
    param([string]$Name)
    return $null -ne (Get-Command $Name -ErrorAction SilentlyContinue)
}

function Ensure-Docker {
    if (-not (Test-CommandAvailable "docker")) {
        throw "找不到 docker 命令，请先安装并启动 Docker Desktop。"
    }

    & docker version *> $null
    if ($LASTEXITCODE -ne 0) {
        throw "Docker 引擎未运行，请先打开 Docker Desktop。"
    }
}

function Get-ComposeCommand {
    & docker compose version *> $null
    if ($LASTEXITCODE -eq 0) {
        return @{ File = "docker"; Prefix = @("compose") }
    }

    $localCompose = Join-Path $Root "offline-dependencies\docker-compose.exe"
    if (Test-Path -LiteralPath $localCompose) {
        return @{ File = $localCompose; Prefix = @() }
    }

    throw "找不到 Docker Compose。请确认 Docker Desktop 已安装，或 offline-dependencies\docker-compose.exe 存在。"
}

function Invoke-Compose {
    param(
        [string[]]$Arguments,
        [switch]$NoThrow
    )

    $compose = Get-ComposeCommand
    $allArgs = @($compose.Prefix) + $Arguments
    & $compose.File @allArgs
    if (-not $NoThrow -and $LASTEXITCODE -ne 0) {
        throw "命令执行失败：Docker Compose $($Arguments -join ' ')"
    }
}

function Find-AppContainerId {
    Write-Step "查找 Snipe-IT app 容器"

    for ($i = 1; $i -le 60; $i++) {
        $containerId = (Invoke-Compose -Arguments @("ps", "-q", "app") -NoThrow | Out-String).Trim()
        if (-not [string]::IsNullOrWhiteSpace($containerId)) {
            Write-Ok "找到 app 容器：$containerId"
            return $containerId
        }

        $fallback = (& docker ps --filter "name=snipeit" --format "{{.ID}} {{.Names}}" 2>$null |
            Where-Object { $_ -match "app" } |
            Select-Object -First 1)
        if ($fallback) {
            $id = ($fallback -split "\s+")[0]
            Write-Ok "通过容器名称找到 app 容器：$fallback"
            return $id
        }

        Start-Sleep -Seconds 2
    }

    throw "找不到 Snipe-IT app 容器。请先确认系统已经部署并启动。"
}

function Apply-Patch {
    if (-not (Test-Path -LiteralPath $PatchFile)) {
        throw "找不到补丁文件：$PatchFile。请复制完整最新版 Snipe-IT 文件夹。"
    }

    Ensure-Docker

    Write-Step "启动 app 服务（不会删除数据）"
    Invoke-Compose -Arguments @("up", "-d", "app") -NoThrow | Out-Host

    $appContainer = Find-AppContainerId

    Write-Step "复制并执行资产名称必填补丁"
    Invoke-Checked "docker" @("cp", $PatchFile, "${appContainer}:/tmp/snipeit-oneclick-asset-name-required.php")
    Invoke-Checked "docker" @("exec", "-i", $appContainer, "php", "/tmp/snipeit-oneclick-asset-name-required.php")

    Write-Step "清理 Snipe-IT 缓存"
    & docker exec -i $appContainer php artisan optimize:clear
    if ($LASTEXITCODE -ne 0) {
        Write-Warn "缓存清理失败，但补丁可能已经应用。请刷新页面后测试。"
    }

    Write-Ok "完成。新增/编辑资产时，资产名称为空将无法保存。"
}

try {
    Apply-Patch
}
catch {
    Write-Host ""
    Write-Host "[错误] $($_.Exception.Message)" -ForegroundColor Red
    Write-Host ""
    Write-Warn "请确认：Docker Desktop 已启动；Snipe-IT 已部署；已复制完整最新版文件夹，包括 patches 目录。"
    exit 1
}
