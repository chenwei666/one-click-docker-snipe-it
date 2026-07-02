# 一键docker部署Snipe-IT

中文 | [English](#one-click-docker-deployment-for-snipe-it)

一个面向 Windows 10/11、Windows Server 和 Windows 虚拟机的 Snipe-IT 一键 Docker 部署包。目标是让新电脑只需要双击脚本，就能完成 Windows 功能启用、Docker 安装、Docker Compose 兼容、Snipe-IT 启动和局域网访问配置。

> 说明：Docker 官方不支持在 Windows Server 2019/2022 上运行 Docker Desktop。本项目会尽力自动配置，但最稳的环境仍然是 Windows 10/11 Pro、Enterprise、Education，或 Linux Server。

## 功能

- 一键启用 WSL2、Virtual Machine Platform、Hyper-V、Containers 等 Windows 功能。
- 自动安装或启动 Docker Desktop。
- 自动使用 Docker Compose 插件；如果缺失，会使用本地 `docker-compose.exe`。
- 自动生成 `.env`，包含随机 `APP_KEY`、数据库密码和 root 密码。
- 自动导入离线 Docker 镜像；没有离线包时会联网拉取 Snipe-IT、MariaDB、Mailpit。
- 固定 Snipe-IT 端口为 `8088`。
- 自动配置局域网访问地址和 Windows 防火墙规则。
- 提供状态查看、停止、更新、备份、上传限制修复、资产名称必填补丁和局域网诊断脚本。

## 快速开始

### 方式 0：图形化 EXE 启动器

如果文件夹里已有 `Snipe-IT-OneClick.exe`，直接双击它，按界面按钮执行部署、状态查看、局域网修复、上传限制修复等操作。

图形化启动器支持中英文切换，并提供“访问设置”：可以修改 Snipe-IT 访问端口，也可以选择“仅本机访问”或“局域网访问”。局域网访问会绑定 `0.0.0.0` 并配置 Windows 防火墙；仅本机访问会绑定 `127.0.0.1` 并移除本项目的局域网放行规则。

如果你的业务要求资产名称必填，可以在图形化启动器里点击 `启用资产名称必填`，或双击 `11-启用资产名称必填补丁.bat`。该补丁不修改数据库结构，不会删除已有资产；但旧资产如果名称为空，之后编辑保存时需要补上资产名称。

如果需要重新生成 EXE，双击：

```text
10-生成图形化EXE.bat
build-exe.bat
```

重新生成 EXE 需要当前电脑已安装 Python 和 PyInstaller；运行 EXE 本身不需要 Python。

### 方式 A：直接在线部署

适合从 GitHub 下载 ZIP 或 `git clone` 后，目标电脑可以访问互联网的情况。

1. 下载或克隆本项目。
2. 在目标 Windows 电脑上双击任意一个：

   ```text
   install.bat
   01-一键部署并启动Snipe-IT.bat
   ```

3. 如果脚本提示重启，重启后再次双击同一个脚本。
4. 部署完成后，查看生成的：

   ```text
   局域网访问地址.txt
   ```

### 方式 B：准备离线部署包

适合目标电脑不能稳定访问 Docker Hub、GitHub 或 Docker Desktop 下载地址的情况。

1. 在一台能联网的准备机上，双击任意一个：

   ```text
   prepare-offline.bat
   00-生成新电脑离线部署包.bat
   ```

2. 它会生成 `offline-dependencies/`，里面包含 Docker Desktop、Docker Compose、WSL2 内核更新包和 Docker 镜像。
3. 把整个 `Snipe-IT` 文件夹复制到目标 Windows 电脑或虚拟机。
4. 在目标机器上双击 `install.bat` 或 `01-一键部署并启动Snipe-IT.bat`。

## 脚本说明

- `install.bat`：英文别名，一键部署。
- `prepare-offline.bat`：英文别名，生成离线依赖包。
- `00-生成新电脑离线部署包.bat`：下载 Docker Desktop、Docker Compose、WSL2 内核更新包，并导出 Docker 镜像。
- `01-一键部署并启动Snipe-IT.bat`：启用 Windows 功能、安装 Docker、导入/拉取镜像、部署系统、配置局域网访问。
- `02-打开Snipe-IT网页.bat` / `open-snipe-it.bat`：打开当前配置的 Snipe-IT 地址。
- `03-查看运行状态.bat` / `status.bat`：查看容器状态和最近日志。
- `04-停止Snipe-IT.bat` / `stop.bat`：停止服务，不删除数据。
- `05-更新Snipe-IT.bat` / `update.bat`：重新导入/拉取镜像并启动。
- `06-备份Snipe-IT数据.bat` / `backup.bat`：备份数据库和附件。
- `07-启用局域网访问.bat` / `enable-lan-access.bat`：修复 `APP_URL` 和 Windows 防火墙。
- `08-局域网访问诊断.bat` / `diagnose-lan.bat`：检查 Docker、容器、端口、HTTP 和防火墙规则。
- `09-修复上传限制为100M.bat` / `fix-upload-limit.bat`：把上传限制调整为 100MB，只重建原来的 `app` 容器，不新建另一套系统。
- `10-生成图形化EXE.bat` / `build-exe.bat`：生成 `Snipe-IT-OneClick.exe` 图形化启动器。
- `11-启用资产名称必填补丁.bat` / `require-asset-name.bat`：把 Snipe-IT 原生资产名称字段改为必填校验。
- 图形化启动器里的“访问设置”：修改 `APP_PORT`、`APP_BIND_IP` 和 `APP_URL`，并重建原来的 `app` 容器应用配置。

## GitHub 下载包里不包含什么

GitHub 仓库默认不包含 `offline-dependencies/`。因此：

- 有互联网：直接运行 `install.bat`。
- 无互联网或网络受限：先在能联网的电脑运行 `prepare-offline.bat`，再复制整个文件夹。

## 不会上传到 GitHub 的内容

以下内容会被 `.gitignore` 忽略：

- `.env`
- `.docker-cli/`
- `offline-dependencies/`
- `backups/`
- `局域网访问地址.txt`

`offline-dependencies/` 里会包含大体积安装器和 Docker 镜像，不适合直接放入 GitHub。

---

# One-Click Docker Deployment for Snipe-IT

English | [中文](#一键docker部署snipe-it)

A one-click Docker deployment package for Snipe-IT on Windows 10/11, Windows Server, and Windows virtual machines. It is designed so a fresh Windows machine can deploy Snipe-IT by double-clicking batch files.

> Note: Docker Desktop is not officially supported on Windows Server 2019/2022. This project performs a best-effort setup there, but Windows 10/11 Pro, Enterprise, Education, or Linux Server remains the most reliable choice.

## Features

- Enables WSL2, Virtual Machine Platform, Hyper-V, Containers, and related Windows prerequisites.
- Installs or starts Docker Desktop.
- Uses the Docker Compose plugin when available, or falls back to local `docker-compose.exe`.
- Generates `.env` with random `APP_KEY`, database password, and root password.
- Imports offline Docker images when available; otherwise pulls Snipe-IT, MariaDB, and Mailpit online.
- Exposes Snipe-IT on fixed port `8088`.
- Configures LAN access and Windows Firewall inbound rules.
- Includes status, stop, update, backup, upload-limit repair, required asset-name patch, LAN repair, and diagnostic scripts.

## Quick Start

### Option 0: GUI EXE launcher

If `Snipe-IT-OneClick.exe` exists in the folder, double-click it and use the GUI buttons for deployment, status checks, LAN repair, upload-limit repair, and maintenance tasks.

The GUI launcher supports Chinese/English switching and includes Access Settings. You can change the Snipe-IT port and choose Local only or LAN access. LAN access binds to `0.0.0.0` and configures Windows Firewall. Local only binds to `127.0.0.1` and removes this project's LAN firewall rule.

If your business requires asset names, click `Require Asset Name` in the GUI launcher or run `11-启用资产名称必填补丁.bat`. The patch does not change the database schema and does not delete existing assets. Existing assets with an empty name will need a name the next time they are edited and saved.

To rebuild the EXE, double-click:

```text
10-生成图形化EXE.bat
build-exe.bat
```

Rebuilding the EXE requires Python and PyInstaller on the build machine. Running the generated EXE does not require Python.

### Option A: Online one-click deployment

Use this if the target machine can access the internet after downloading the GitHub ZIP or cloning the repository.

1. Download or clone this repository.
2. On the target Windows machine, double-click either:

   ```text
   install.bat
   01-一键部署并启动Snipe-IT.bat
   ```

3. If Windows asks for a reboot, reboot and run the same script again.
4. After deployment, open the generated file:

   ```text
   局域网访问地址.txt
   ```

### Option B: Prepare an offline package

Use this if the target machine cannot reliably access Docker Hub, GitHub, or Docker Desktop downloads.

1. On a network-connected preparation machine, double-click either:

   ```text
   prepare-offline.bat
   00-生成新电脑离线部署包.bat
   ```

2. This generates `offline-dependencies/` with Docker Desktop, Docker Compose, WSL2 kernel update package, and Docker images.
3. Copy the entire `Snipe-IT` folder to the target Windows machine or VM.
4. On the target machine, double-click `install.bat` or `01-一键部署并启动Snipe-IT.bat`.

## Scripts

- `install.bat`: English alias for one-click deployment.
- `prepare-offline.bat`: English alias for preparing offline dependencies.
- `00-生成新电脑离线部署包.bat`: downloads Docker Desktop, Docker Compose, WSL2 kernel update package, and exports Docker images.
- `01-一键部署并启动Snipe-IT.bat`: enables Windows features, installs Docker, imports/pulls images, deploys Snipe-IT, and configures LAN access.
- `02-打开Snipe-IT网页.bat` / `open-snipe-it.bat`: opens the configured Snipe-IT URL.
- `03-查看运行状态.bat` / `status.bat`: shows container status and recent logs.
- `04-停止Snipe-IT.bat` / `stop.bat`: stops services without deleting data.
- `05-更新Snipe-IT.bat` / `update.bat`: reloads/pulls images and restarts services.
- `06-备份Snipe-IT数据.bat` / `backup.bat`: backs up the database and uploaded files.
- `07-启用局域网访问.bat` / `enable-lan-access.bat`: repairs `APP_URL` and Windows Firewall rules.
- `08-局域网访问诊断.bat` / `diagnose-lan.bat`: diagnoses Docker, containers, ports, HTTP, and firewall rules.
- `09-修复上传限制为100M.bat` / `fix-upload-limit.bat`: raises the upload limit to 100MB and recreates only the original `app` container.
- `10-生成图形化EXE.bat` / `build-exe.bat`: builds the `Snipe-IT-OneClick.exe` GUI launcher.
- `11-启用资产名称必填补丁.bat` / `require-asset-name.bat`: makes the native Snipe-IT asset name field required.
- Access Settings in the GUI launcher: updates `APP_PORT`, `APP_BIND_IP`, and `APP_URL`, then recreates the original `app` container to apply the change.

## What GitHub Downloads Do Not Include

The GitHub repository does not include `offline-dependencies/`. Therefore:

- Internet available: run `install.bat` directly.
- Offline or restricted network: first run `prepare-offline.bat` on a network-connected machine, then copy the entire folder.

## Ignored Local Files

The following are intentionally ignored by Git:

- `.env`
- `.docker-cli/`
- `offline-dependencies/`
- `backups/`
- `局域网访问地址.txt`

`offline-dependencies/` contains large installers and Docker image archives, so it is not suitable for GitHub.

