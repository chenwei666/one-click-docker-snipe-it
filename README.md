# 一键docker部署Snipe-IT

中文 | [English](#one-click-docker-deployment-for-snipe-it)

一个面向 Windows 10/11、Windows Server 和 Windows 虚拟机的 Snipe-IT 一键 Docker 部署包。目标是让新电脑只需要双击脚本，就能完成 Windows 功能启用、Docker 安装、离线镜像导入、Snipe-IT 启动和局域网访问配置。

> 说明：Docker 官方不支持在 Windows Server 2019/2022 上运行 Docker Desktop。本项目会尽力自动配置，但最稳的环境仍然是 Windows 10/11 Pro、Enterprise、Education，或 Linux Server。

## 功能

- 一键启用 WSL2、Virtual Machine Platform、Hyper-V、Containers 等 Windows 功能。
- 自动安装或启动 Docker Desktop。
- 自动使用 Docker Compose 插件；如果缺失，会使用本地 `docker-compose.exe`。
- 自动生成 `.env`，包含随机 `APP_KEY`、数据库密码和 root 密码。
- 自动导入离线 Docker 镜像：Snipe-IT、MariaDB、Mailpit。
- 固定 Snipe-IT 端口为 `8088`。
- 自动配置局域网访问地址和 Windows 防火墙规则。
- 提供状态查看、停止、更新、备份和局域网诊断脚本。

## 快速开始

1. 在一台能联网的准备机上，双击：

   ```text
   00-生成新电脑离线部署包.bat
   ```

2. 把整个 `Snipe-IT` 文件夹复制到目标 Windows 电脑或虚拟机。

3. 在目标机器上双击：

   ```text
   01-一键部署并启动Snipe-IT.bat
   ```

4. 如果脚本提示重启，重启后再次双击 `01-一键部署并启动Snipe-IT.bat`。

5. 部署完成后，查看生成的：

   ```text
   局域网访问地址.txt
   ```

## 脚本说明

- `00-生成新电脑离线部署包.bat`：下载 Docker Desktop、Docker Compose、WSL2 内核更新包，并导出 Docker 镜像。
- `01-一键部署并启动Snipe-IT.bat`：启用 Windows 功能、安装 Docker、导入镜像、部署系统、配置局域网访问。
- `02-打开Snipe-IT网页.bat`：打开当前配置的 Snipe-IT 地址。
- `03-查看运行状态.bat`：查看容器状态和最近日志。
- `04-停止Snipe-IT.bat`：停止服务，不删除数据。
- `05-更新Snipe-IT.bat`：重新导入/拉取镜像并启动。
- `06-备份Snipe-IT数据.bat`：备份数据库和附件。
- `07-启用局域网访问.bat`：修复 `APP_URL` 和 Windows 防火墙。
- `08-局域网访问诊断.bat`：检查 Docker、容器、端口、HTTP 和防火墙规则。

## 不会上传到 GitHub 的内容

以下内容会被 `.gitignore` 忽略：

- `.env`
- `.docker-cli/`
- `offline-dependencies/`
- `backups/`
- `局域网访问地址.txt`

`offline-dependencies/` 里会包含大体积安装器和 Docker 镜像，不适合直接放入 GitHub。请在发布后按需运行 `00-生成新电脑离线部署包.bat` 生成。

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
- Imports offline Docker images for Snipe-IT, MariaDB, and Mailpit.
- Exposes Snipe-IT on fixed port `8088`.
- Configures LAN access and Windows Firewall inbound rules.
- Includes status, stop, update, backup, LAN repair, and diagnostic scripts.

## Quick Start

1. On a network-connected preparation machine, double-click:

   ```text
   00-生成新电脑离线部署包.bat
   ```

2. Copy the entire `Snipe-IT` folder to the target Windows machine or VM.

3. On the target machine, double-click:

   ```text
   01-一键部署并启动Snipe-IT.bat
   ```

4. If Windows asks for a reboot, reboot and double-click `01-一键部署并启动Snipe-IT.bat` again.

5. After deployment, open the generated file:

   ```text
   局域网访问地址.txt
   ```

## Scripts

- `00-生成新电脑离线部署包.bat`: downloads Docker Desktop, Docker Compose, WSL2 kernel update package, and exports Docker images.
- `01-一键部署并启动Snipe-IT.bat`: enables Windows features, installs Docker, imports images, deploys Snipe-IT, and configures LAN access.
- `02-打开Snipe-IT网页.bat`: opens the configured Snipe-IT URL.
- `03-查看运行状态.bat`: shows container status and recent logs.
- `04-停止Snipe-IT.bat`: stops services without deleting data.
- `05-更新Snipe-IT.bat`: reloads/pulls images and restarts services.
- `06-备份Snipe-IT数据.bat`: backs up the database and uploaded files.
- `07-启用局域网访问.bat`: repairs `APP_URL` and Windows Firewall rules.
- `08-局域网访问诊断.bat`: diagnoses Docker, containers, ports, HTTP, and firewall rules.

## Ignored Local Files

The following are intentionally ignored by Git:

- `.env`
- `.docker-cli/`
- `offline-dependencies/`
- `backups/`
- `局域网访问地址.txt`

`offline-dependencies/` contains large installers and Docker image archives, so it is not suitable for GitHub. Generate it locally with `00-生成新电脑离线部署包.bat`.
