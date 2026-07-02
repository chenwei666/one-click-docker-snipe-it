param([string]$Root = "")

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($Root)) {
    $Root = $env:SNIPEIT_ONECLICK_ROOT
}

if ([string]::IsNullOrWhiteSpace($Root)) {
    $ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
    $Root = Split-Path -Parent $ScriptDir
}

$Root = $Root.Trim().Trim('"')
$Root = [System.IO.Path]::GetFullPath($Root)
Set-Location $Root

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

function New-EmbeddedPatchFile {
    $patchPath = Join-Path ([System.IO.Path]::GetTempPath()) "snipeit-oneclick-asset-name-required.php"
    $chunks = @(
        'PD9waHAKZGVjbGFyZShzdHJpY3RfdHlwZXM9MSk7CgpmdW5jdGlvbiBmaW5kX2FwcF9yb290KCk6IHN0cmluZwp7CiAgICAk'
        'Y2FuZGlkYXRlcyA9IFsKICAgICAgICBnZXRjd2QoKSwKICAgICAgICBkaXJuYW1lKF9fRElSX18sIDIpLAogICAgICAgICcv'
        'dmFyL3d3dy9odG1sJywKICAgICAgICAnL3Zhci93d3cvaHRtbC9zbmlwZS1pdCcsCiAgICAgICAgJy9hcHAnLAogICAgXTsK'
        'CiAgICBmb3JlYWNoICgkY2FuZGlkYXRlcyBhcyAkcm9vdCkgewogICAgICAgIGlmICghJHJvb3QpIHsKICAgICAgICAgICAg'
        'Y29udGludWU7CiAgICAgICAgfQogICAgICAgICRhc3NldCA9IHJ0cmltKCRyb290LCAnL1xcJykgLiAnL2FwcC9Nb2RlbHMv'
        'QXNzZXQucGhwJzsKICAgICAgICBpZiAoaXNfZmlsZSgkYXNzZXQpKSB7CiAgICAgICAgICAgIHJldHVybiBydHJpbSgkcm9v'
        'dCwgJy9cXCcpOwogICAgICAgIH0KICAgIH0KCiAgICB0aHJvdyBuZXcgUnVudGltZUV4Y2VwdGlvbignU25pcGUtSVQgYXBw'
        'bGljYXRpb24gcm9vdCB3YXMgbm90IGZvdW5kLicpOwp9CgpmdW5jdGlvbiB3cml0ZV9pZl9jaGFuZ2VkKHN0cmluZyAkcGF0'
        'aCwgc3RyaW5nICRjb250ZW50KTogYm9vbAp7CiAgICAkb2xkID0gZmlsZV9nZXRfY29udGVudHMoJHBhdGgpOwogICAgaWYg'
        'KCRvbGQgPT09ICRjb250ZW50KSB7CiAgICAgICAgcmV0dXJuIGZhbHNlOwogICAgfQoKICAgICRiYWNrdXAgPSAkcGF0aCAu'
        'ICcub25lY2xpY2suYmFrJzsKICAgIGlmICghaXNfZmlsZSgkYmFja3VwKSkgewogICAgICAgIGNvcHkoJHBhdGgsICRiYWNr'
        'dXApOwogICAgfQoKICAgIGZpbGVfcHV0X2NvbnRlbnRzKCRwYXRoLCAkY29udGVudCk7CiAgICByZXR1cm4gdHJ1ZTsKfQoK'
        'ZnVuY3Rpb24gcGF0Y2hfYXNzZXRfbW9kZWwoc3RyaW5nICRyb290KTogYm9vbAp7CiAgICAkcGF0aCA9ICRyb290IC4gJy9h'
        'cHAvTW9kZWxzL0Fzc2V0LnBocCc7CiAgICAkY29udGVudCA9IGZpbGVfZ2V0X2NvbnRlbnRzKCRwYXRoKTsKCiAgICBpZiAo'
        'cHJlZ19tYXRjaCgiLyduYW1lJ1xzKj0+XHMqXFtbXlxdXSoncmVxdWlyZWQnLyIsICRjb250ZW50KSkgewogICAgICAgIGVj'
        'aG8gIltPS10gQXNzZXQgbW9kZWwgbmFtZSB2YWxpZGF0aW9uIGlzIGFscmVhZHkgcmVxdWlyZWQuXG4iOwogICAgICAgIHJl'
        'dHVybiBmYWxzZTsKICAgIH0KCiAgICAkdXBkYXRlZCA9IHByZWdfcmVwbGFjZSgKICAgICAgICAiLyduYW1lJ1xzKj0+XHMq'
        'XFtccyonbnVsbGFibGUnXHMqLFxzKidtYXg6MjU1J1xzKlxdLyIsCiAgICAgICAgIiduYW1lJyA9PiBbJ3JlcXVpcmVkJywg'
        'J3N0cmluZycsICdtYXg6MjU1J10iLAogICAgICAgICRjb250ZW50LAogICAgICAgIDEsCiAgICAgICAgJGNvdW50CiAgICAp'
        'OwoKICAgIGlmICgkY291bnQgIT09IDEgfHwgJHVwZGF0ZWQgPT09IG51bGwpIHsKICAgICAgICB0aHJvdyBuZXcgUnVudGlt'
        'ZUV4Y2VwdGlvbignQ291bGQgbm90IHBhdGNoIGFwcC9Nb2RlbHMvQXNzZXQucGhwLiBUaGUgdXBzdHJlYW0gdmFsaWRhdGlv'
        'biBydWxlIGNoYW5nZWQuJyk7CiAgICB9CgogICAgd3JpdGVfaWZfY2hhbmdlZCgkcGF0aCwgJHVwZGF0ZWQpOwogICAgZWNo'
        'byAiW09LXSBQYXRjaGVkIEFzc2V0IG1vZGVsIG5hbWUgdmFsaWRhdGlvbi5cbiI7CiAgICByZXR1cm4gdHJ1ZTsKfQoKZnVu'
        'Y3Rpb24gcGF0Y2hfbmFtZV9wYXJ0aWFsKHN0cmluZyAkcm9vdCk6IGJvb2wKewogICAgJHBhdGggPSAkcm9vdCAuICcvcmVz'
        'b3VyY2VzL3ZpZXdzL3BhcnRpYWxzL2Zvcm1zL2VkaXQvbmFtZS5ibGFkZS5waHAnOwogICAgaWYgKCFpc19maWxlKCRwYXRo'
        'KSkgewogICAgICAgIGVjaG8gIltXQVJOXSBOYW1lIHBhcnRpYWwgd2FzIG5vdCBmb3VuZDsgc2VydmVyLXNpZGUgdmFsaWRh'
        'dGlvbiBpcyBzdGlsbCBwYXRjaGVkLlxuIjsKICAgICAgICByZXR1cm4gZmFsc2U7CiAgICB9CgogICAgJGNvbnRlbnQgPSBm'
        'aWxlX2dldF9jb250ZW50cygkcGF0aCk7CiAgICAkdXBkYXRlZCA9ICRjb250ZW50OwoKICAgICRsYWJlbE5lZWRsZSA9IDw8'
        'PCdCTEFERScKPGxhYmVsIGZvcj0ibmFtZSIgY2xhc3M9ImNvbC1tZC0zIGNvbnRyb2wtbGFiZWwiPnt7ICR0cmFuc2xhdGVk'
        'X25hbWUgfX08L2xhYmVsPgpCTEFERTsKICAgICRsYWJlbFJlcGxhY2VtZW50ID0gPDw8J0JMQURFJwo8bGFiZWwgZm9yPSJu'
        'YW1lIiBjbGFzcz0iY29sLW1kLTMgY29udHJvbC1sYWJlbCI+e3sgJHRyYW5zbGF0ZWRfbmFtZSB9fSA8c3BhbiBjbGFzcz0i'
        'dGV4dC1kYW5nZXIiIGFyaWEtaGlkZGVuPSJ0cnVlIj4qPC9zcGFuPjwvbGFiZWw+CkJMQURFOwogICAgaWYgKHN0cnBvcygk'
        'dXBkYXRlZCwgJ29uZWNsaWNrLWFzc2V0LW5hbWUtcmVxdWlyZWQnKSA9PT0gZmFsc2UgJiYgc3RycG9zKCR1cGRhdGVkLCAk'
        'bGFiZWxOZWVkbGUpICE9PSBmYWxzZSkgewogICAgICAgICR1cGRhdGVkID0gc3RyX3JlcGxhY2UoJGxhYmVsTmVlZGxlLCAi'
        'PCEtLSBvbmVjbGljay1hc3NldC1uYW1lLXJlcXVpcmVkIC0tPlxuIiAuICRsYWJlbFJlcGxhY2VtZW50LCAkdXBkYXRlZCk7'
        'CiAgICB9CgogICAgJGlucHV0TmVlZGxlID0gPDw8J0JMQURFJwo8aW5wdXQgY2xhc3M9ImZvcm0tY29udHJvbCIgc3R5bGU9'
        'IndpZHRoOjEwMCU7IiB0eXBlPSJ0ZXh0IiBuYW1lPSJuYW1lIiBhcmlhLWxhYmVsPSJuYW1lIiBpZD0ibmFtZSIgdmFsdWU9'
        'Int7IG9sZCgnbmFtZScsICRpdGVtLT5uYW1lKSB9fSJ7ISEgIChIZWxwZXI6OmNoZWNrSWZSZXF1aXJlZCgkaXRlbSwgJ25h'
        'bWUnKSkgPyAnIHJlcXVpcmVkJyA6ICcnICEhfSBtYXhsZW5ndGg9IjE5MSIgLz4KQkxBREU7CiAgICAkaW5wdXRSZXBsYWNl'
        'bWVudCA9IDw8PCdCTEFERScKPGlucHV0IGNsYXNzPSJmb3JtLWNvbnRyb2wiIHN0eWxlPSJ3aWR0aDoxMDAlOyIgdHlwZT0i'
        'dGV4dCIgbmFtZT0ibmFtZSIgYXJpYS1sYWJlbD0ibmFtZSIgaWQ9Im5hbWUiIHZhbHVlPSJ7eyBvbGQoJ25hbWUnLCAkaXRl'
        'bS0+bmFtZSkgfX0iIGFyaWEtcmVxdWlyZWQ9InRydWUiIG1heGxlbmd0aD0iMTkxIiAvPgpCTEFERTsKICAgIGlmIChzdHJw'
        'b3MoJHVwZGF0ZWQsICRpbnB1dE5lZWRsZSkgIT09IGZhbHNlKSB7CiAgICAgICAgJHVwZGF0ZWQgPSBzdHJfcmVwbGFjZSgk'
        'aW5wdXROZWVkbGUsICRpbnB1dFJlcGxhY2VtZW50LCAkdXBkYXRlZCk7CiAgICB9CgogICAgaWYgKHdyaXRlX2lmX2NoYW5n'
        'ZWQoJHBhdGgsICR1cGRhdGVkKSkgewogICAgICAgIGVjaG8gIltPS10gUGF0Y2hlZCBhc3NldCBuYW1lIGZvcm0gbWFya2Vy'
        'LlxuIjsKICAgICAgICByZXR1cm4gdHJ1ZTsKICAgIH0KCiAgICBlY2hvICJbT0tdIEFzc2V0IG5hbWUgZm9ybSBtYXJrZXIg'
        'aXMgYWxyZWFkeSBwYXRjaGVkLlxuIjsKICAgIHJldHVybiBmYWxzZTsKfQoKZnVuY3Rpb24gcGF0Y2hfaGFyZHdhcmVfZWRp'
        'dChzdHJpbmcgJHJvb3QpOiBib29sCnsKICAgICRwYXRoID0gJHJvb3QgLiAnL3Jlc291cmNlcy92aWV3cy9oYXJkd2FyZS9l'
        'ZGl0LmJsYWRlLnBocCc7CiAgICBpZiAoIWlzX2ZpbGUoJHBhdGgpKSB7CiAgICAgICAgZWNobyAiW1dBUk5dIEhhcmR3YXJl'
        'IGVkaXQgdmlldyB3YXMgbm90IGZvdW5kOyBzZXJ2ZXItc2lkZSB2YWxpZGF0aW9uIGlzIHN0aWxsIHBhdGNoZWQuXG4iOwog'
        'ICAgICAgIHJldHVybiBmYWxzZTsKICAgIH0KCiAgICAkY29udGVudCA9IGZpbGVfZ2V0X2NvbnRlbnRzKCRwYXRoKTsKICAg'
        'ICRuZWVkbGUgPSAnPGRpdiBpZD0ib3B0aW9uYWxfZGV0YWlscyIgY2xhc3M9ImNvbC1tZC0xMiIgc3R5bGU9ImRpc3BsYXk6'
        'bm9uZSI+JzsKICAgICRyZXBsYWNlbWVudCA9ICc8ZGl2IGlkPSJvcHRpb25hbF9kZXRhaWxzIiBjbGFzcz0iY29sLW1kLTEy'
        'IiBzdHlsZT0ie3sgJGVycm9ycy0+aGFzKFwnbmFtZVwnKSA/IFwnXCcgOiBcJ2Rpc3BsYXk6bm9uZVwnIH19Ij4nOwoKICAg'
        'IGlmIChzdHJwb3MoJGNvbnRlbnQsICRyZXBsYWNlbWVudCkgIT09IGZhbHNlKSB7CiAgICAgICAgZWNobyAiW09LXSBPcHRp'
        'b25hbCBkZXRhaWxzIGVycm9yIGRpc3BsYXkgaXMgYWxyZWFkeSBwYXRjaGVkLlxuIjsKICAgICAgICByZXR1cm4gZmFsc2U7'
        'CiAgICB9CgogICAgaWYgKHN0cnBvcygkY29udGVudCwgJG5lZWRsZSkgPT09IGZhbHNlKSB7CiAgICAgICAgZWNobyAiW1dB'
        'Uk5dIE9wdGlvbmFsIGRldGFpbHMgYmxvY2sgd2FzIG5vdCBmb3VuZDsgc2VydmVyLXNpZGUgdmFsaWRhdGlvbiBpcyBzdGls'
        'bCBwYXRjaGVkLlxuIjsKICAgICAgICByZXR1cm4gZmFsc2U7CiAgICB9CgogICAgJHVwZGF0ZWQgPSBzdHJfcmVwbGFjZSgk'
        'bmVlZGxlLCAkcmVwbGFjZW1lbnQsICRjb250ZW50KTsKICAgIHdyaXRlX2lmX2NoYW5nZWQoJHBhdGgsICR1cGRhdGVkKTsK'
        'ICAgIGVjaG8gIltPS10gUGF0Y2hlZCBvcHRpb25hbCBkZXRhaWxzIGVycm9yIGRpc3BsYXkuXG4iOwogICAgcmV0dXJuIHRy'
        'dWU7Cn0KCiRyb290ID0gZmluZF9hcHBfcm9vdCgpOwplY2hvICJbSU5GT10gU25pcGUtSVQgcm9vdDogeyRyb290fVxuIjsK'
        'CnBhdGNoX2Fzc2V0X21vZGVsKCRyb290KTsKcGF0Y2hfbmFtZV9wYXJ0aWFsKCRyb290KTsKcGF0Y2hfaGFyZHdhcmVfZWRp'
        'dCgkcm9vdCk7CgplY2hvICJbT0tdIEFzc2V0IG5hbWUgcmVxdWlyZWQgcGF0Y2ggYXBwbGllZC5cbiI7Cg=='
    )
    $bytes = [Convert]::FromBase64String(($chunks -join ""))
    [System.IO.File]::WriteAllBytes($patchPath, $bytes)
    return $patchPath
}
function Get-PatchFile {
    $packaged = Join-Path $Root "patches\asset-name-required\apply.php"
    if (Test-Path -LiteralPath $packaged) {
        return $packaged
    }

    Write-Warn "没有找到 patches\asset-name-required\apply.php，将使用脚本内置补丁。"
    return New-EmbeddedPatchFile
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
    Ensure-Docker
    $patchFile = Get-PatchFile

    Write-Step "启动 app 服务（不会删除数据）"
    Invoke-Compose -Arguments @("up", "-d", "app") -NoThrow | Out-Host

    $appContainer = Find-AppContainerId

    Write-Step "复制并执行资产名称必填补丁"
    Invoke-Checked "docker" @("cp", $patchFile, "${appContainer}:/tmp/snipeit-oneclick-asset-name-required.php")
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
    Write-Warn "请确认：Docker Desktop 已启动；Snipe-IT 已部署；当前目录有 docker-compose.yml。"
    exit 1
}
