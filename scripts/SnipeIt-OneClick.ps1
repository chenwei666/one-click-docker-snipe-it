param(
    [ValidateSet("Deploy", "Open", "Status", "Stop", "Update", "Backup", "Validate", "PrepareOffline", "BootstrapDeploy", "ConfigureLan", "ConfigureAccess", "Diagnose", "SetUploadLimit", "ApplyAssetNameRequiredPatch")]
    [string]$Action = "Deploy",
    [int]$Port = 0,
    [ValidateSet("", "Local", "Lan")]
    [string]$AccessMode = ""
)

$ErrorActionPreference = "Stop"

# 定位到部署包根目录。这样不管你从哪里双击，命令都会在正确目录执行。
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$Root = Split-Path -Parent $ScriptDir
Set-Location $Root

# 使用部署包内的 Docker 配置目录，避免读取用户目录里可能没有权限的 Docker 配置文件。
$DockerConfigDir = Join-Path $Root ".docker-cli"
if (-not (Test-Path $DockerConfigDir)) {
    New-Item -ItemType Directory -Path $DockerConfigDir -Force | Out-Null
}
$DockerConfigFile = Join-Path $DockerConfigDir "config.json"
if (-not (Test-Path $DockerConfigFile)) {
    "{}" | Set-Content -Path $DockerConfigFile -Encoding ASCII
}
$env:DOCKER_CONFIG = $DockerConfigDir
$env:COMPOSE_PROJECT_NAME = "snipeit_oneclick"

$AppPort = 8088
$AppBindIp = "0.0.0.0"
$LocalAppUrl = "http://localhost:$AppPort"
$AppUrl = "http://localhost:$AppPort"
$MailpitUrl = "http://localhost:8025"
$OfflineRoot = Join-Path $Root "offline-dependencies"
$OfflineImagesDir = Join-Path $OfflineRoot "images"
$OfflineInstallerPath = Join-Path $OfflineRoot "Docker Desktop Installer.exe"
$WslKernelX64Path = Join-Path $OfflineRoot "wsl_update_x64.msi"
$WslKernelArm64Path = Join-Path $OfflineRoot "wsl_update_arm64.msi"
$ComposeVersion = "v5.1.4"
$ComposeExePath = Join-Path $OfflineRoot "docker-compose.exe"
$script:ComposeMode = $null
$script:ComposeExe = $null

# 新电脑需要的全部 Docker 镜像。生成离线包时会保存为 tar，新电脑部署时会自动导入。
$RequiredImages = @(
    @{ Image = "snipe/snipe-it:v8.6.1"; File = "snipe-snipe-it-v8.6.1.tar"; Label = "Snipe-IT 官方镜像" },
    @{ Image = "mariadb:11.4.7"; File = "mariadb-11.4.7.tar"; Label = "MariaDB 数据库镜像" },
    @{ Image = "axllent/mailpit:v1.27"; File = "axllent-mailpit-v1.27.tar"; Label = "Mailpit 本地邮件箱镜像" }
)

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

function Test-CommandAvailable {
    param([string]$Name)
    return $null -ne (Get-Command $Name -ErrorAction SilentlyContinue)
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

function Install-MsiQuiet {
    param([string]$MsiPath)

    $process = Start-Process -FilePath "msiexec.exe" -ArgumentList @("/i", $MsiPath, "/quiet", "/norestart") -Wait -PassThru
    if ($process.ExitCode -in @(0, 3010, 1638)) {
        if ($process.ExitCode -eq 3010) {
            Write-Warn "MSI 安装完成，但系统提示需要重启。"
        }
        elseif ($process.ExitCode -eq 1638) {
            Write-Ok "系统中已存在同版本或更新版本的组件。"
        }
        return
    }

    throw "MSI 安装失败：$MsiPath，退出码 $($process.ExitCode)"
}

function Get-DockerDesktopInstallerUrl {
    $arch = $env:PROCESSOR_ARCHITECTURE
    if ($arch -like "*ARM*") {
        return "https://desktop.docker.com/win/main/arm64/Docker%20Desktop%20Installer.exe"
    }

    return "https://desktop.docker.com/win/main/amd64/Docker%20Desktop%20Installer.exe"
}

function Get-DockerComposeStandaloneUrl {
    $arch = $env:PROCESSOR_ARCHITECTURE
    if ($arch -like "*ARM*") {
        return "https://github.com/docker/compose/releases/download/$ComposeVersion/docker-compose-windows-aarch64.exe"
    }

    return "https://github.com/docker/compose/releases/download/$ComposeVersion/docker-compose-windows-x86_64.exe"
}

function Get-WslKernelUpdatePath {
    $arch = $env:PROCESSOR_ARCHITECTURE
    if ($arch -like "*ARM*") {
        return $WslKernelArm64Path
    }

    return $WslKernelX64Path
}

function Get-WslKernelUpdateUrl {
    $arch = $env:PROCESSOR_ARCHITECTURE
    if ($arch -like "*ARM*") {
        return "https://wslstorestorage.blob.core.windows.net/wslblob/wsl_update_arm64.msi"
    }

    return "https://wslstorestorage.blob.core.windows.net/wslblob/wsl_update_x64.msi"
}

function Ensure-OfflineFolders {
    if (-not (Test-Path $OfflineRoot)) {
        New-Item -ItemType Directory -Path $OfflineRoot -Force | Out-Null
    }
    if (-not (Test-Path $OfflineImagesDir)) {
        New-Item -ItemType Directory -Path $OfflineImagesDir -Force | Out-Null
    }
}

function Download-DockerDesktopInstaller {
    Ensure-OfflineFolders
    if (Test-Path $OfflineInstallerPath) {
        Write-Ok "Docker Desktop 安装器已存在：$OfflineInstallerPath"
        return
    }

    Write-Step "下载 Docker Desktop 安装器到离线依赖包"
    Write-Warn "安装器文件较大，请耐心等待。"
    Invoke-WebRequest -Uri (Get-DockerDesktopInstallerUrl) -OutFile $OfflineInstallerPath
    Write-Ok "已下载：$OfflineInstallerPath"
}

function Download-DockerComposeStandalone {
    Ensure-OfflineFolders
    if (Test-Path $ComposeExePath) {
        Write-Ok "Docker Compose 独立版已存在：$ComposeExePath"
        return
    }

    Write-Step "下载 Docker Compose 独立版到离线依赖包"
    Invoke-WebRequest -Uri (Get-DockerComposeStandaloneUrl) -OutFile $ComposeExePath
    Write-Ok "已下载：$ComposeExePath"
}

function Test-DockerComposePlugin {
    try {
        & docker compose version *> $null
        return $LASTEXITCODE -eq 0
    }
    catch {
        return $false
    }
}

function Ensure-DockerCompose {
    if ($script:ComposeMode) {
        return
    }

    if (Test-DockerComposePlugin) {
        $script:ComposeMode = "Plugin"
        Write-Ok "Docker Compose 插件可用：docker compose"
        return
    }

    $standalone = Get-Command "docker-compose" -ErrorAction SilentlyContinue
    if ($standalone) {
        $script:ComposeMode = "Standalone"
        $script:ComposeExe = $standalone.Source
        Write-Ok "Docker Compose 独立命令可用：$($script:ComposeExe)"
        return
    }

    if (Test-Path $ComposeExePath) {
        $script:ComposeMode = "LocalStandalone"
        $script:ComposeExe = $ComposeExePath
        Write-Ok "使用本文件夹里的 Docker Compose：$ComposeExePath"
        return
    }

    try {
        Download-DockerComposeStandalone
    }
    catch {
        throw "找不到 Docker Compose，且无法下载。请确认 offline-dependencies\docker-compose.exe 存在，或网络可访问 GitHub。"
    }

    $script:ComposeMode = "LocalStandalone"
    $script:ComposeExe = $ComposeExePath
    Write-Ok "使用本文件夹里的 Docker Compose：$ComposeExePath"
}

function Invoke-Compose {
    param(
        [string[]]$Arguments,
        [switch]$NoThrow
    )

    Ensure-DockerCompose
    if ($script:ComposeMode -eq "Plugin") {
        & docker compose @Arguments
    }
    else {
        & $script:ComposeExe @Arguments
    }

    if (-not $NoThrow -and $LASTEXITCODE -ne 0) {
        throw "命令执行失败：Docker Compose $($Arguments -join ' ')"
    }
}

function Download-WslKernelUpdate {
    Ensure-OfflineFolders
    $wslMsi = Get-WslKernelUpdatePath
    if (Test-Path $wslMsi) {
        Write-Ok "WSL2 内核更新包已存在：$wslMsi"
        return
    }

    Write-Step "下载 WSL2 内核更新包到离线依赖包"
    Invoke-WebRequest -Uri (Get-WslKernelUpdateUrl) -OutFile $wslMsi
    Write-Ok "已下载：$wslMsi"
}

function Test-Administrator {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Ensure-Administrator {
    if (-not (Test-Administrator)) {
        throw "需要管理员权限。请双击 01-一键部署并启动Snipe-IT.bat，并在 UAC 弹窗里选择 是。"
    }
}

function Get-WindowsProfile {
    $os = Get-CimInstance Win32_OperatingSystem
    $computer = Get-CimInstance Win32_ComputerSystem
    $processor = Get-CimInstance Win32_Processor | Select-Object -First 1

    return [pscustomobject]@{
        Caption = $os.Caption
        Build = [int]$os.BuildNumber
        ProductType = [int]$os.ProductType
        IsServer = ([int]$os.ProductType -ne 1)
        IsVirtualMachine = ($computer.Model -match "Virtual|VMware|VirtualBox|KVM|Hyper-V|QEMU")
        VirtualizationFirmwareEnabled = [bool]$processor.VirtualizationFirmwareEnabled
        SecondLevelAddressTranslation = [bool]$processor.SecondLevelAddressTranslationExtensions
    }
}

function Write-WindowsProfile {
    $profile = Get-WindowsProfile
    Write-Step "检测 Windows 环境"
    Write-Host "系统：$($profile.Caption)"
    Write-Host "Build：$($profile.Build)"

    if ($profile.IsServer) {
        Write-Warn "检测到 Windows Server。Docker 官方不支持在 Windows Server 2019/2022 上运行 Docker Desktop；本脚本会尽力启用功能并继续尝试。"
    }
    elseif ($profile.Caption -match "Windows 10" -and $profile.Build -lt 19045) {
        Write-Warn "Windows 10 建议升级到 22H2 / build 19045 或更高。"
    }
    elseif ($profile.Caption -match "Windows 11" -and $profile.Build -lt 22631) {
        Write-Warn "Windows 11 建议升级到 23H2 / build 22631 或更高。"
    }

    if ($profile.IsVirtualMachine) {
        Write-Warn "检测到虚拟机环境。请确认虚拟机平台已开启 nested virtualization / 嵌套虚拟化。"
    }
    if (-not $profile.VirtualizationFirmwareEnabled) {
        Write-Warn "BIOS/UEFI 或虚拟机平台里的硬件虚拟化可能未开启；脚本无法在 Windows 内部替你打开这个开关。"
    }
    if (-not $profile.SecondLevelAddressTranslation) {
        Write-Warn "CPU/虚拟机未报告 SLAT 支持，WSL2/Hyper-V 可能无法运行。"
    }
}

function Enable-OptionalFeatureIfAvailable {
    param(
        [string]$Name,
        [string]$Label
    )

    $feature = Get-WindowsOptionalFeature -Online -FeatureName $Name -ErrorAction SilentlyContinue
    if (-not $feature) {
        Write-Warn "$Label 功能在当前系统不可用，已跳过。"
        return $false
    }

    if ($feature.State -eq "Enabled") {
        Write-Ok "$Label 已启用。"
        return $false
    }

    Write-Step "启用 Windows 功能：$Label"
    Enable-WindowsOptionalFeature -Online -FeatureName $Name -All -NoRestart | Out-Null
    Write-Ok "$Label 已启用。"
    return $true
}

function Ensure-WindowsServices {
    $service = Get-Service -Name "LanmanServer" -ErrorAction SilentlyContinue
    if (-not $service) {
        Write-Warn "未找到 LanmanServer 服务，已跳过。"
        return
    }

    Set-Service -Name "LanmanServer" -StartupType Automatic
    if ($service.Status -ne "Running") {
        Start-Service -Name "LanmanServer"
    }
    Write-Ok "Windows Server 服务 LanmanServer 已设置为自动启动。"
}

function Install-WslKernelUpdateIfAvailable {
    $wslMsi = Get-WslKernelUpdatePath
    if (Test-Path $wslMsi) {
        try {
            Write-Step "安装本地 WSL2 内核更新包"
            Install-MsiQuiet -MsiPath $wslMsi
            Write-Ok "WSL2 内核更新包已安装或已是最新。"
        }
        catch {
            Write-Warn "WSL2 内核更新包未能安装，可能是当前系统已使用新版 WSL；部署会继续。"
        }
        return
    }

    try {
        Download-WslKernelUpdate
        Write-Step "安装 WSL2 内核更新包"
        Install-MsiQuiet -MsiPath (Get-WslKernelUpdatePath)
        Write-Ok "WSL2 内核更新包已安装或已是最新。"
    }
    catch {
        Write-Warn "WSL2 内核更新包未能自动下载/安装；较新的 Windows 通常可通过 wsl --update 自动处理。"
    }
}

function Configure-WslDefaults {
    if (-not (Test-CommandAvailable "wsl")) {
        Write-Warn "当前还找不到 wsl.exe，重启后 Windows 通常会完成启用。"
        return
    }

    & wsl --set-default-version 2 *> $null
    if ($LASTEXITCODE -eq 0) {
        Write-Ok "WSL 默认版本已设置为 2。"
    }
    else {
        Write-Warn "WSL 默认版本暂时未能设置为 2，重启后脚本会继续尝试。"
    }
}

function Register-ResumeAfterReboot {
    param([string]$BatchFileName = "01-一键部署并启动Snipe-IT.bat")

    $bat = Join-Path $Root $BatchFileName
    $runOnce = "HKCU:\Software\Microsoft\Windows\CurrentVersion\RunOnce"
    $value = "cmd.exe /c `"`"$bat`"`""
    New-Item -Path $runOnce -Force | Out-Null
    New-ItemProperty -Path $runOnce -Name "SnipeIT-OneClick-Deploy" -Value $value -PropertyType String -Force | Out-Null
    Write-Ok "已设置重启后自动继续部署。"
}

function Enable-WindowsPrerequisites {
    param([string]$ResumeBatchFileName = "01-一键部署并启动Snipe-IT.bat")

    Ensure-Administrator
    Write-WindowsProfile
    Ensure-WindowsServices

    $changed = $false
    $changed = (Enable-OptionalFeatureIfAvailable -Name "Microsoft-Windows-Subsystem-Linux" -Label "Windows Subsystem for Linux") -or $changed
    $changed = (Enable-OptionalFeatureIfAvailable -Name "VirtualMachinePlatform" -Label "Virtual Machine Platform") -or $changed
    $changed = (Enable-OptionalFeatureIfAvailable -Name "Microsoft-Hyper-V-All" -Label "Hyper-V") -or $changed
    $changed = (Enable-OptionalFeatureIfAvailable -Name "Containers" -Label "Containers") -or $changed

    Install-WslKernelUpdateIfAvailable
    Configure-WslDefaults

    if ($changed) {
        Register-ResumeAfterReboot -BatchFileName $ResumeBatchFileName
        Write-Warn "Windows 功能刚启用，需要重启后才能继续部署。"
        $answer = Read-Host "按 Enter 立即重启；输入 N 后按 Enter 稍后自己重启"
        if ($answer -notmatch "^[Nn]") {
            Restart-Computer -Force
        }
        throw "请重启后继续部署。"
    }
}

function Save-Manifest {
    Ensure-OfflineFolders
    $manifest = Join-Path $OfflineRoot "离线依赖清单.txt"
    $lines = @(
        "Snipe-IT 新电脑离线依赖包",
        "生成时间：$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')",
        "",
        "复制整个 Snipe-IT 文件夹到新电脑后，双击：01-一键部署并启动Snipe-IT.bat",
        "",
        "包含依赖：",
        "- Docker Desktop Installer.exe",
        "- docker-compose.exe",
        "- WSL2 Linux kernel update package",
        "- snipe/snipe-it:v8.6.1",
        "- mariadb:11.4.7",
        "- axllent/mailpit:v1.27"
    )
    Set-Content -Path $manifest -Value ($lines -join [Environment]::NewLine) -Encoding UTF8
}

function New-HexSecret {
    param([int]$Bytes = 24)
    $buffer = New-Object byte[] $Bytes
    $rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
    try {
        $rng.GetBytes($buffer)
    }
    finally {
        $rng.Dispose()
    }
    return -join ($buffer | ForEach-Object { $_.ToString("x2") })
}

function New-LaravelAppKey {
    $buffer = New-Object byte[] 32
    $rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
    try {
        $rng.GetBytes($buffer)
    }
    finally {
        $rng.Dispose()
    }
    return "base64:" + [Convert]::ToBase64String($buffer)
}

function Ensure-EnvFile {
    $envPath = Join-Path $Root ".env"
    $examplePath = Join-Path $Root ".env.example"

    if (Test-Path $envPath) {
        Write-Ok "已存在 .env 配置文件，本次不会覆盖。"
        return
    }

    if (-not (Test-Path $examplePath)) {
        throw "找不到 .env.example，无法生成 .env。"
    }

    Write-Step "首次运行：生成随机密钥和数据库密码"
    $content = Get-Content -Path $examplePath -Raw
    $content = $content.Replace("__APP_KEY__", (New-LaravelAppKey))
    $content = $content.Replace("__DB_PASSWORD__", (New-HexSecret -Bytes 24))
    $content = $content.Replace("__MYSQL_ROOT_PASSWORD__", (New-HexSecret -Bytes 24))
    Set-Content -Path $envPath -Value $content -Encoding ASCII
    Write-Ok "已生成 .env。"
}

function Read-EnvFile {
    Ensure-EnvFile
    $map = @{}
    Get-Content -Path (Join-Path $Root ".env") | ForEach-Object {
        $line = $_.Trim()
        if ($line -eq "" -or $line.StartsWith("#")) {
            return
        }
        $parts = $line.Split("=", 2)
        if ($parts.Count -eq 2) {
            $map[$parts[0]] = $parts[1]
        }
    }
    return $map
}

function Set-AppPortRuntime {
    param([int]$NewPort)

    if ($NewPort -lt 1 -or $NewPort -gt 65535) {
        throw "端口必须是 1 到 65535 之间的数字。"
    }

    $script:AppPort = $NewPort
    $script:LocalAppUrl = "http://localhost:$NewPort"
}

function Sync-AppUrlFromEnv {
    Ensure-EnvFile
    $envMap = Read-EnvFile
    if ($envMap.ContainsKey("APP_PORT") -and $envMap.APP_PORT -match "^\d+$") {
        Set-AppPortRuntime -NewPort ([int]$envMap.APP_PORT)
    }
    if ($envMap.ContainsKey("APP_BIND_IP") -and -not [string]::IsNullOrWhiteSpace($envMap.APP_BIND_IP)) {
        $script:AppBindIp = $envMap.APP_BIND_IP
    }
    if ($envMap.ContainsKey("APP_URL") -and -not [string]::IsNullOrWhiteSpace($envMap.APP_URL)) {
        $script:AppUrl = $envMap.APP_URL
    }
    else {
        $script:AppUrl = $script:LocalAppUrl
    }
}

function Write-AccessInfoFile {
    param([string]$Url)

    $path = Join-Path $Root "局域网访问地址.txt"
    $lines = @(
        "Snipe-IT 访问地址",
        "",
        $Url,
        "",
        "如果是局域网模式，同一局域网内其他电脑请在浏览器打开上面的地址。",
        "如果是本机模式，只能在当前电脑打开。",
        "如果打不开，请在服务器上双击 08-局域网访问诊断.bat。"
    )
    Set-Content -Path $path -Value ($lines -join [Environment]::NewLine) -Encoding UTF8
}

function Set-EnvValue {
    param(
        [string]$Key,
        [string]$Value
    )

    Ensure-EnvFile
    $envPath = Join-Path $Root ".env"
    $lines = Get-Content -Path $envPath
    $found = $false
    $updated = foreach ($line in $lines) {
        if ($line -match "^\s*$([regex]::Escape($Key))=") {
            $found = $true
            "$Key=$Value"
        }
        else {
            $line
        }
    }

    if (-not $found) {
        $updated += "$Key=$Value"
    }

    Set-Content -Path $envPath -Value $updated -Encoding ASCII
}

function Get-AppContainerId {
    for ($i = 1; $i -le 60; $i++) {
        $containerId = (Invoke-Compose -Arguments @("ps", "-q", "app") -NoThrow | Out-String).Trim()
        if (-not [string]::IsNullOrWhiteSpace($containerId)) {
            return $containerId
        }
        Start-Sleep -Seconds 2
    }

    throw "找不到 Snipe-IT app 容器，请先启动系统。"
}

function Apply-AssetNameRequiredPatch {
    $patchFile = Join-Path $Root "patches\asset-name-required\apply.php"
    if (-not (Test-Path -LiteralPath $patchFile)) {
        throw "找不到资产名称必填补丁文件：$patchFile"
    }

    Write-Step "启用资产名称必填补丁"
    Ensure-Docker
    Invoke-Compose -Arguments @("up", "-d", "app")

    $appContainer = Get-AppContainerId
    Invoke-Checked "docker" @("cp", $patchFile, "${appContainer}:/tmp/snipeit-oneclick-asset-name-required.php")
    Invoke-Compose -Arguments @("exec", "-T", "app", "php", "/tmp/snipeit-oneclick-asset-name-required.php")

    Write-Step "清理应用缓存"
    Invoke-Compose -Arguments @("exec", "-T", "app", "php", "artisan", "optimize:clear") -NoThrow | Out-Host

    Write-Ok "资产名称已设置为必填。新增和编辑资产时，资产名称为空将无法保存。"
}

function Set-UploadLimit {
    $uploadMb = 100
    $postMb = 120
    $memoryMb = 256
    $projectName = "snipeit_oneclick"

    Write-Step "写入 Snipe-IT 上传大小限制"
    Set-EnvValue -Key "PHP_UPLOAD_LIMIT" -Value "$uploadMb"
    Set-EnvValue -Key "PHP_UPLOAD_MAX_FILESIZE" -Value "$uploadMb"
    Set-EnvValue -Key "PHP_POST_MAX_SIZE" -Value "$postMb"
    Set-EnvValue -Key "PHP_MEMORY_LIMIT" -Value "$memoryMb"
    Write-Ok "已设置图片/文件上传限制为 ${uploadMb}MB。"
    Write-Ok "POST 上限为 ${postMb}MB，PHP 内存上限为 ${memoryMb}MB。"

    Write-Step "重建 Snipe-IT app 容器以应用新 .env"
    Ensure-Docker
    Write-Warn "如果之前误生成过 snipeit-oneclick 临时容器，会先停止它；不会删除数据卷。"
    Invoke-Compose -Arguments @("-p", "snipeit-oneclick", "down", "--remove-orphans") -NoThrow | Out-Host
    Invoke-Compose -Arguments @("-p", $projectName, "up", "-d", "db")
    Invoke-Compose -Arguments @("-p", $projectName, "up", "-d", "--no-deps", "--force-recreate", "app")
    Apply-AssetNameRequiredPatch

    Write-Step "清理应用缓存"
    Invoke-Compose -Arguments @("-p", $projectName, "exec", "-T", "app", "php", "artisan", "config:clear") -NoThrow | Out-Host
    Invoke-Compose -Arguments @("-p", $projectName, "exec", "-T", "app", "php", "artisan", "cache:clear") -NoThrow | Out-Host

    Write-Step "验证 PHP 上传配置"
    Invoke-Compose -Arguments @(
        "-p",
        $projectName,
        "exec",
        "-T",
        "app",
        "php",
        "-r",
        "echo 'upload_max_filesize='.ini_get('upload_max_filesize').PHP_EOL; echo 'post_max_size='.ini_get('post_max_size').PHP_EOL; echo 'memory_limit='.ini_get('memory_limit').PHP_EOL;"
    ) -NoThrow | Out-Host

    Write-Step "当前原项目容器状态"
    Invoke-Compose -Arguments @("-p", $projectName, "ps") -NoThrow | Out-Host

    Write-Ok "处理完成。请刷新 Snipe-IT 页面后重新选择图片上传。"
}

function Test-PrivateIPv4 {
    param([string]$Address)

    if ($Address -match "^10\.") {
        return $true
    }
    if ($Address -match "^192\.168\.") {
        return $true
    }
    if ($Address -match "^172\.([1][6-9]|2[0-9]|3[0-1])\.") {
        return $true
    }
    return $false
}

function Get-LanIPv4Address {
    $candidates = @()
    $interfaces = [System.Net.NetworkInformation.NetworkInterface]::GetAllNetworkInterfaces()

    foreach ($nic in $interfaces) {
        if ($nic.OperationalStatus -ne [System.Net.NetworkInformation.OperationalStatus]::Up) {
            continue
        }
        if ($nic.NetworkInterfaceType -in @(
            [System.Net.NetworkInformation.NetworkInterfaceType]::Loopback,
            [System.Net.NetworkInformation.NetworkInterfaceType]::Tunnel
        )) {
            continue
        }

        $props = $nic.GetIPProperties()
        $hasGateway = $props.GatewayAddresses | Where-Object {
            $_.Address.AddressFamily -eq [System.Net.Sockets.AddressFamily]::InterNetwork -and
            $_.Address.ToString() -ne "0.0.0.0"
        }

        foreach ($addr in $props.UnicastAddresses) {
            if ($addr.Address.AddressFamily -ne [System.Net.Sockets.AddressFamily]::InterNetwork) {
                continue
            }

            $ip = $addr.Address.ToString()
            if ($ip -like "127.*" -or $ip -like "169.254.*") {
                continue
            }

            $score = 0
            if ($hasGateway) {
                $score += 10
            }
            if (Test-PrivateIPv4 -Address $ip) {
                $score += 5
            }
            if ($nic.NetworkInterfaceType -eq [System.Net.NetworkInformation.NetworkInterfaceType]::Ethernet) {
                $score += 2
            }
            if ($nic.NetworkInterfaceType -eq [System.Net.NetworkInformation.NetworkInterfaceType]::Wireless80211) {
                $score += 1
            }

            $candidates += [pscustomobject]@{
                IP = $ip
                Name = $nic.Name
                Score = $score
            }
        }
    }

    $best = $candidates | Sort-Object Score -Descending | Select-Object -First 1
    if (-not $best) {
        throw "没有检测到可用于局域网访问的 IPv4 地址。请确认网卡已连接到局域网。"
    }

    Write-Ok "检测到局域网 IP：$($best.IP)（$($best.Name)）"
    return $best.IP
}

function Remove-LanFirewallRules {
    Ensure-Administrator

    $ruleNames = @("Snipe-IT LAN", "Snipe-IT LAN 8088")
    try {
        foreach ($name in $ruleNames) {
            Get-NetFirewallRule -DisplayName $name -ErrorAction SilentlyContinue |
                Remove-NetFirewallRule -Confirm:$false
        }
    }
    catch {
        foreach ($name in $ruleNames) {
            & netsh advfirewall firewall delete rule name="$name" *> $null
        }
    }
}

function Ensure-LanFirewallRule {
    Ensure-Administrator

    $ruleName = "Snipe-IT LAN"
    try {
        Remove-LanFirewallRules

        New-NetFirewallRule `
            -DisplayName $ruleName `
            -Direction Inbound `
            -Action Allow `
            -Protocol TCP `
            -LocalPort $AppPort `
            -Profile Any | Out-Null
        Write-Ok "Windows 防火墙已放行 TCP $AppPort。"
    }
    catch {
        Write-Warn "PowerShell 防火墙命令失败，改用 netsh 方式。"
        Remove-LanFirewallRules
        & netsh advfirewall firewall add rule name="$ruleName" dir=in action=allow protocol=TCP localport=$AppPort profile=any | Out-Null
        if ($LASTEXITCODE -ne 0) {
            throw "Windows 防火墙规则创建失败，请确认已用管理员权限运行。"
        }
        Write-Ok "Windows 防火墙已通过 netsh 放行 TCP $AppPort。"
    }
}

function Set-AccessConfiguration {
    param(
        [int]$NewPort,
        [ValidateSet("Local", "Lan")]
        [string]$Mode,
        [switch]$RestartApp
    )

    Ensure-EnvFile
    Sync-AppUrlFromEnv

    if ($NewPort -eq 0) {
        $NewPort = $AppPort
    }
    Set-AppPortRuntime -NewPort $NewPort

    if ([string]::IsNullOrWhiteSpace($Mode)) {
        $Mode = "Lan"
    }

    Write-Step "写入访问配置"
    Set-EnvValue -Key "APP_PORT" -Value "$NewPort"

    if ($Mode -eq "Local") {
        $url = "http://localhost:$NewPort"
        Set-EnvValue -Key "APP_BIND_IP" -Value "127.0.0.1"
        Set-EnvValue -Key "APP_URL" -Value $url
        $script:AppBindIp = "127.0.0.1"
        $script:AppUrl = $url

        Write-Step "关闭局域网防火墙放行规则"
        Remove-LanFirewallRules
        Write-Ok "已设置为仅本机访问：$url"
    }
    else {
        $lanIp = Get-LanIPv4Address
        $url = "http://${lanIp}:$NewPort"
        Set-EnvValue -Key "APP_BIND_IP" -Value "0.0.0.0"
        Set-EnvValue -Key "APP_URL" -Value $url
        $script:AppBindIp = "0.0.0.0"
        $script:AppUrl = $url

        Write-Step "放行 Windows 防火墙端口"
        Ensure-LanFirewallRule
        Write-Ok "已设置为局域网访问：$url"
    }

    Write-AccessInfoFile -Url $script:AppUrl
    Write-Ok "APP_PORT 已设置为：$NewPort"
    Write-Ok "APP_URL 已设置为：$script:AppUrl"

    if ($RestartApp) {
        Write-Step "重建 Snipe-IT app 容器以应用端口和访问模式"
        Ensure-Docker
        Invoke-Compose -Arguments @("up", "-d", "--force-recreate", "app")
        Apply-AssetNameRequiredPatch
        Wait-AppReady
    }

    if ($Mode -eq "Lan") {
        Write-Warn "请在同一局域网其他电脑浏览器打开：$script:AppUrl"
    }
}

function Configure-LanAccess {
    param([switch]$RestartApp)

    Set-AccessConfiguration -NewPort 0 -Mode "Lan" -RestartApp:$RestartApp
}

function Install-DockerDesktopIfMissing {
    if (Test-CommandAvailable "docker") {
        return
    }

    Write-Step "未检测到 Docker，开始安装 Docker Desktop"
    Write-Warn "Docker Desktop 是 Snipe-IT 的运行底座；新电脑第一次安装后可能需要重启 Windows。"

    if (Test-Path $OfflineInstallerPath) {
        Write-Warn "使用本文件夹里的离线 Docker Desktop 安装器。若系统询问权限，请选择允许。"
        Start-Process -FilePath $OfflineInstallerPath -Wait -ArgumentList @("install", "--user")
    }
    elseif (Test-CommandAvailable "winget") {
        Invoke-Checked "winget" @(
            "install",
            "--id", "Docker.DockerDesktop",
            "-e",
            "--accept-package-agreements",
            "--accept-source-agreements"
        )
    }
    else {
        Download-DockerDesktopInstaller
        Write-Warn "正在启动 Docker Desktop 安装器。若系统询问权限，请选择允许。"
        Start-Process -FilePath $OfflineInstallerPath -Wait -ArgumentList @("install", "--user")
    }

    Write-Warn "Docker Desktop 安装完成后，请重启电脑或手动打开 Docker Desktop，再重新双击 01-一键部署并启动Snipe-IT.bat。"
    throw "Docker 刚安装完成，需要重新运行部署脚本。"
}

function Test-DockerDaemon {
    try {
        $serverVersion = & docker info --format "{{.ServerVersion}}" 2>$null
        return $LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace($serverVersion)
    }
    catch {
        return $false
    }
}

function Start-DockerDesktop {
    $candidates = @(
        (Join-Path $env:ProgramFiles "Docker\Docker\Docker Desktop.exe"),
        (Join-Path $env:LOCALAPPDATA "Programs\DockerDesktop\Docker Desktop.exe"),
        (Join-Path $env:LOCALAPPDATA "Programs\Docker\Docker\Docker Desktop.exe"),
        (Join-Path $env:LOCALAPPDATA "Docker\Docker Desktop.exe")
    )

    $desktop = $candidates | Where-Object { Test-Path $_ } | Select-Object -First 1
    if ($desktop) {
        Write-Warn "Docker 引擎还没启动，正在打开 Docker Desktop。"
        Start-Process -FilePath $desktop | Out-Null
    }
    else {
        Write-Warn "找不到 Docker Desktop 快捷程序，请手动打开 Docker Desktop。"
    }

    for ($i = 1; $i -le 120; $i++) {
        if (Test-DockerDaemon) {
            Write-Ok "Docker 引擎已启动。"
            return
        }
        Start-Sleep -Seconds 2
        if ($i % 10 -eq 0) {
            Write-Warn "仍在等待 Docker Desktop 启动..."
        }
    }

    Read-Host "Docker Desktop 启动完成后，按 Enter 继续"
    if (-not (Test-DockerDaemon)) {
        throw "Docker 引擎仍未启动。请确认 Docker Desktop 状态为 Running 后再运行。"
    }
}

function Ensure-Docker {
    Install-DockerDesktopIfMissing

    Invoke-Checked "docker" @("--version")
    Ensure-DockerCompose

    if (-not (Test-DockerDaemon)) {
        Start-DockerDesktop
    }
}

function Test-DockerImageExists {
    param([string]$Image)
    try {
        & docker image inspect $Image 2>$null | Out-Null
        return $LASTEXITCODE -eq 0
    }
    catch {
        return $false
    }
}

function Load-OfflineImages {
    if (-not (Test-Path $OfflineImagesDir)) {
        return
    }

    foreach ($item in $RequiredImages) {
        $image = $item.Image
        $tarPath = Join-Path $OfflineImagesDir $item.File
        if ((Test-DockerImageExists -Image $image) -or -not (Test-Path $tarPath)) {
            continue
        }

        Write-Step "从本地离线包导入 $($item.Label)"
        Invoke-Checked "docker" @("load", "-i", $tarPath)
    }
}

function Ensure-RequiredImages {
    Load-OfflineImages

    $missing = @()
    foreach ($item in $RequiredImages) {
        if (-not (Test-DockerImageExists -Image $item.Image)) {
            $missing += $item
        }
    }

    if ($missing.Count -eq 0) {
        Write-Ok "所需 Docker 镜像已全部在本机可用。"
        return
    }

    Write-Step "下载缺失的 Docker 镜像"
    foreach ($item in $missing) {
        Write-Warn "正在下载 $($item.Image)"
        Invoke-Checked "docker" @("pull", $item.Image)
    }
}

function Save-RequiredImages {
    Ensure-OfflineFolders
    foreach ($item in $RequiredImages) {
        $image = $item.Image
        $tarPath = Join-Path $OfflineImagesDir $item.File

        if (Test-Path $tarPath) {
            Write-Ok "离线镜像已存在：$tarPath"
            continue
        }

        Write-Step "同步 $($item.Label)：$image"
        if (-not (Test-DockerImageExists -Image $image)) {
            Invoke-Checked "docker" @("pull", $image)
        }

        Write-Warn "正在保存为 $tarPath"
        Invoke-Checked "docker" @("save", "-o", $tarPath, $image)
        Write-Ok "已保存：$tarPath"
    }
}

function Test-PortAvailable {
    $used = Get-NetTCPConnection -LocalPort $AppPort -ErrorAction SilentlyContinue
    if (-not $used) {
        Write-Ok "端口 $AppPort 可用。"
        return
    }

    $owners = $used | Select-Object -ExpandProperty OwningProcess -Unique
    $processNames = foreach ($processId in $owners) {
        $proc = Get-Process -Id $processId -ErrorAction SilentlyContinue
        if ($proc) {
            "$($proc.ProcessName)($processId)"
        }
        else {
            "PID $processId"
        }
    }

    throw "端口 $AppPort 已被占用：$($processNames -join ', ')。请关闭占用程序，或修改 .env 里的 APP_PORT。"
}

function Test-AppRunning {
    $containerId = (Invoke-Compose -Arguments @("ps", "-q", "app") -NoThrow 2>$null | Select-Object -First 1)
    if ([string]::IsNullOrWhiteSpace($containerId)) {
        return $false
    }

    $running = (& docker inspect -f "{{.State.Running}}" $containerId 2>$null | Select-Object -First 1)
    return $running -eq "true"
}

function Wait-AppReady {
    Write-Step "等待 Snipe-IT Web 页面就绪"
    for ($i = 1; $i -le 90; $i++) {
        try {
            Invoke-WebRequest -UseBasicParsing -Uri $AppUrl -TimeoutSec 5 | Out-Null
            Write-Ok "Snipe-IT 已可访问：$AppUrl"
            return
        }
        catch {
            Start-Sleep -Seconds 2
        }
    }
    Write-Warn "容器已启动，但网页响应较慢。稍等一分钟后打开：$AppUrl"
}

function Invoke-Deploy {
    Ensure-EnvFile
    Sync-AppUrlFromEnv
    Ensure-Docker
    Ensure-RequiredImages

    if (-not (Test-AppRunning)) {
        Test-PortAvailable
    }

    Write-Step "启动 Snipe-IT"
    Invoke-Compose -Arguments @("up", "-d")
    Apply-AssetNameRequiredPatch

    Wait-AppReady
    Start-Process $AppUrl

    Write-Ok "部署完成。Snipe-IT：$AppUrl"
    Write-Ok "本地测试邮件箱：$MailpitUrl"
}

function Invoke-Open {
    Sync-AppUrlFromEnv
    Start-Process $AppUrl
    Write-Ok "已打开 $AppUrl"
}

function Invoke-Status {
    Sync-AppUrlFromEnv
    Ensure-Docker
    Write-Step "容器状态"
    Invoke-Compose -Arguments @("ps")

    Write-Step "Snipe-IT 最近日志"
    Invoke-Compose -Arguments @("logs", "--tail", "60", "app")
}

function Invoke-Stop {
    Ensure-Docker
    Write-Step "停止 Snipe-IT 服务"
    Invoke-Compose -Arguments @("stop")
    Write-Ok "已停止。数据仍保存在 Docker 卷中。"
}

function Invoke-Update {
    Ensure-EnvFile
    Sync-AppUrlFromEnv
    Ensure-Docker

    Write-Step "同步当前配置指定版本的镜像"
    Ensure-RequiredImages

    Write-Step "重建并启动服务"
    Invoke-Compose -Arguments @("up", "-d")
    Apply-AssetNameRequiredPatch

    Wait-AppReady
    Write-Ok "更新完成。当前 APP_VERSION 可在 .env 中查看或修改。"
}

function Invoke-Backup {
    Ensure-EnvFile
    Ensure-Docker

    $envMap = Read-EnvFile
    $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $backupDir = Join-Path $Root "backups"
    if (-not (Test-Path $backupDir)) {
        New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
    }

    Write-Step "备份数据库"
    $dbFile = Join-Path $backupDir "snipeit-db-$timestamp.sql"
    Invoke-Compose -Arguments @("exec", "-T", "db", "mariadb-dump", "-uroot", "-p$($envMap.MYSQL_ROOT_PASSWORD)", $envMap.DB_DATABASE) -NoThrow |
        Out-File -FilePath $dbFile -Encoding UTF8
    if ($LASTEXITCODE -ne 0) {
        throw "数据库备份失败。"
    }
    Write-Ok "数据库备份：$dbFile"

    Write-Step "备份上传文件和附件"
    $appContainer = (Invoke-Compose -Arguments @("ps", "-q", "app") -NoThrow | Out-String).Trim()
    if (-not $appContainer) {
        throw "找不到正在运行的 app 容器，请先启动 Snipe-IT。"
    }

    $storageFolder = Join-Path $backupDir "snipeit-storage-$timestamp"
    $storageZip = Join-Path $backupDir "snipeit-storage-$timestamp.zip"
    New-Item -ItemType Directory -Path $storageFolder -Force | Out-Null
    Invoke-Checked "docker" @("cp", "${appContainer}:/var/lib/snipeit/.", $storageFolder)
    Compress-Archive -Path (Join-Path $storageFolder "*") -DestinationPath $storageZip -Force
    Remove-Item -LiteralPath $storageFolder -Recurse -Force
    Write-Ok "文件备份：$storageZip"
}

function Invoke-Validate {
    Ensure-EnvFile
    Invoke-Compose -Arguments @("config", "--quiet")
    Write-Ok "Docker Compose 配置验证通过。"
}

function Invoke-PrepareOffline {
    Ensure-EnvFile
    Enable-WindowsPrerequisites -ResumeBatchFileName "00-生成新电脑离线部署包.bat"
    Ensure-Docker
    Ensure-OfflineFolders

    Download-DockerDesktopInstaller
    Download-DockerComposeStandalone
    Download-WslKernelUpdate
    Save-RequiredImages
    Save-Manifest

    Write-Ok "新电脑离线部署包已准备完成：$OfflineRoot"
    Write-Warn "复制整个 Snipe-IT 文件夹到新 Windows/虚拟机后，双击 01-一键部署并启动Snipe-IT.bat。"
}

function Invoke-BootstrapDeploy {
    Enable-WindowsPrerequisites
    Configure-LanAccess
    Invoke-Deploy
}

function Invoke-ConfigureLan {
    Configure-LanAccess -RestartApp
}

function Invoke-ConfigureAccess {
    $mode = $AccessMode
    if ([string]::IsNullOrWhiteSpace($mode)) {
        $mode = "Lan"
    }

    Set-AccessConfiguration -NewPort $Port -Mode $mode -RestartApp
}

function Test-HttpEndpoint {
    param([string]$Url)

    try {
        $response = Invoke-WebRequest -UseBasicParsing -Uri $Url -TimeoutSec 10
        Write-Ok "$Url 返回 HTTP $($response.StatusCode)。"
        return $true
    }
    catch {
        Write-Warn "$Url 访问失败：$($_.Exception.Message)"
        return $false
    }
}

function Invoke-Diagnose {
    Ensure-EnvFile
    Sync-AppUrlFromEnv

    Write-Step "部署包检查"
    Write-Host "部署目录：$Root"
    Write-Host "监听地址：$AppBindIp"
    Write-Host "本机访问地址：$LocalAppUrl"
    Write-Host "配置访问地址：$AppUrl"
    Write-AccessInfoFile -Url $AppUrl

    Write-Step "局域网 IP 检查"
    try {
        $lanIp = Get-LanIPv4Address
        Write-Host "建议局域网地址：http://${lanIp}:$AppPort"
    }
    catch {
        Write-Warn $_.Exception.Message
    }

    Write-Step "Docker 和 Compose 检查"
    try {
        Ensure-Docker
        Write-Ok "Docker 引擎可用。"
    }
    catch {
        Write-Warn "Docker 检查失败：$($_.Exception.Message)"
    }

    Write-Step "Docker Compose 配置检查"
    try {
        Invoke-Compose -Arguments @("config", "--quiet")
        Write-Ok "Compose 配置通过。"
    }
    catch {
        Write-Warn "Compose 配置失败：$($_.Exception.Message)"
    }

    Write-Step "容器和端口检查"
    try {
        Invoke-Compose -Arguments @("ps")
    }
    catch {
        Write-Warn "容器状态读取失败：$($_.Exception.Message)"
    }

    try {
        $listeners = Get-NetTCPConnection -LocalPort $AppPort -State Listen -ErrorAction Stop
        if ($listeners) {
            Write-Ok "本机正在监听 TCP $AppPort。"
        }
    }
    catch {
        Write-Warn "未检测到 TCP $AppPort 监听，Snipe-IT 可能未启动。"
    }

    Write-Step "HTTP 访问检查"
    $localOk = Test-HttpEndpoint -Url $LocalAppUrl
    $configuredOk = Test-HttpEndpoint -Url $AppUrl

    Write-Step "Windows 防火墙检查"
    if ($AppBindIp -eq "127.0.0.1") {
        Write-Ok "当前是仅本机访问模式，不需要放行局域网防火墙端口。"
    }
    else {
        try {
            $rule = Get-NetFirewallRule -DisplayName "Snipe-IT LAN" -ErrorAction Stop
            $port = Get-NetFirewallPortFilter -AssociatedNetFirewallRule $rule
            if ($rule.Enabled -eq "True" -and $rule.Action -eq "Allow" -and $port.LocalPort -contains "$AppPort") {
                Write-Ok "Windows 防火墙规则存在并已放行 TCP $AppPort。"
            }
            else {
                Write-Warn "防火墙规则存在，但状态/端口不完全正确。请双击 07-启用局域网访问.bat。"
            }
        }
        catch {
            Write-Warn "未检测到防火墙放行规则。请双击 07-启用局域网访问.bat，并在 UAC 中点 是。"
        }
    }

    Write-Step "结论"
    if ($localOk -and $configuredOk) {
        Write-Ok "服务器本机检查通过。局域网电脑请访问：$AppUrl"
        Write-Warn "若其他电脑仍打不开，请检查是否同一网段、是否连接访客网络、路由/AP 是否开启客户端隔离、是否有第三方防火墙。"
        Write-Warn "可在其他电脑 PowerShell 执行：Test-NetConnection $($AppUrl.Replace('http://', '').Split(':')[0]) -Port $AppPort"
    }
    else {
        Write-Warn "服务器本机检查未完全通过，请先确认 01 部署成功，再运行 07 修复局域网访问。"
    }
}

try {
    switch ($Action) {
        "Deploy" { Invoke-Deploy }
        "Open" { Invoke-Open }
        "Status" { Invoke-Status }
        "Stop" { Invoke-Stop }
        "Update" { Invoke-Update }
        "Backup" { Invoke-Backup }
        "Validate" { Invoke-Validate }
        "PrepareOffline" { Invoke-PrepareOffline }
        "BootstrapDeploy" { Invoke-BootstrapDeploy }
        "ConfigureLan" { Invoke-ConfigureLan }
        "ConfigureAccess" { Invoke-ConfigureAccess }
        "Diagnose" { Invoke-Diagnose }
        "SetUploadLimit" { Set-UploadLimit }
        "ApplyAssetNameRequiredPatch" { Apply-AssetNameRequiredPatch }
    }
}
catch {
    Write-Host ""
    Write-Host "[错误] $($_.Exception.Message)" -ForegroundColor Red
    Write-Host ""
    Write-Warn "常见处理：确认 Docker Desktop 已打开；确认 8088 未被占用；确认离线依赖包存在或网络能访问 Docker Hub。"
    exit 1
}

