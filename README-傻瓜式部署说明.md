# Snipe-IT 傻瓜式一键部署包

目标：把整个 `Snipe-IT` 文件夹复制到一台新的 Windows 11、Windows 10、Windows Server 或 Windows 虚拟机上，然后双击一个文件部署。

Snipe-IT 访问地址固定为：

```text
http://localhost:8088
```

## 当前电脑先做一次

在当前这台已经能联网、已经准备好的电脑上，先双击：

```text
00-生成新电脑离线部署包.bat
```

它会把新电脑需要的依赖同步到本文件夹里的 `offline-dependencies`：

- Docker Desktop 安装器
- Docker Compose 独立版 `docker-compose.exe`
- WSL2 Linux 内核更新包
- `snipe/snipe-it:v8.6.1`
- `mariadb:11.4.7`
- `axllent/mailpit:v1.27`

生成完成后，直接复制整个 `Snipe-IT` 文件夹到新电脑或 Windows 虚拟机。

## 新电脑只点这个

在新电脑上双击：

```text
01-一键部署并启动Snipe-IT.bat
```

它会自动请求管理员权限，然后尽量自动完成：

- 检测 Windows 版本、是否 Windows Server、是否虚拟机。
- 启用 `Windows Subsystem for Linux`。
- 启用 `Virtual Machine Platform`。
- 启用 `Hyper-V`，当前系统不支持时会自动跳过。
- 启用 `Containers`，当前系统不支持时会自动跳过。
- 设置 `LanmanServer` 服务为自动启动。
- 安装本文件夹里的 WSL2 内核更新包。
- 如果没装 Docker Desktop，优先使用本文件夹里的离线安装器安装。
- 如果 Docker Desktop 没有自带 `docker compose` 插件，会自动使用本文件夹里的 `docker-compose.exe`。
- 如果 Docker Desktop 没启动，会自动尝试打开并等待启动完成。
- 如果 Docker 镜像还没导入，会优先从本文件夹里的 `.tar` 镜像导入。
- 自动生成 `.env`、随机 `APP_KEY`、数据库密码和 root 密码。
- 自动检测本机局域网 IP，把 `APP_URL` 设置为 `http://本机IP:8088`。
- 自动添加 Windows 防火墙规则，允许局域网访问 `8088`。
- 自动启动 Snipe-IT、MariaDB、本地测试邮件箱。
- 自动打开 Snipe-IT 页面。

如果脚本启用了 Windows 功能，会提示重启，并设置重启后自动继续部署。重启后如果没有自动弹出，再双击 `01-一键部署并启动Snipe-IT.bat` 一次即可。

## Windows Server 和虚拟机说明

- Docker 官方不支持在 Windows Server 2019/2022 上运行 Docker Desktop。脚本会尽力启用功能并继续尝试，但最稳的是 Windows 10/11 Pro、Enterprise、Education，或直接用 Linux Server。
- 如果你是在 VMware、Hyper-V、ESXi、Proxmox、VirtualBox、云服务器虚拟机里运行，宿主机必须开启 nested virtualization / 嵌套虚拟化。这个开关脚本无法在 Windows 内部替你打开。
- 如果 BIOS/UEFI 没开硬件虚拟化，脚本也无法替你打开，需要进 BIOS/虚拟机平台设置。

## 常用按钮

- `00-生成新电脑离线部署包.bat`：在当前电脑生成给新电脑复制用的离线依赖包。
- `01-一键部署并启动Snipe-IT.bat`：启用 Windows 功能、安装 Docker、导入镜像、部署、打开网页。
- `02-打开Snipe-IT网页.bat`：只打开 `http://localhost:8088`。
- `03-查看运行状态.bat`：查看容器状态和最近日志。
- `04-停止Snipe-IT.bat`：停止服务，不删除数据。
- `05-更新Snipe-IT.bat`：重新导入/拉取镜像并启动。
- `06-备份Snipe-IT数据.bat`：备份数据库和上传附件到 `backups` 文件夹。
- `07-启用局域网访问.bat`：本机能打开但局域网打不开时，修复 `APP_URL` 和 Windows 防火墙。
- `08-局域网访问诊断.bat`：检查 Docker、容器、端口、HTTP 和防火墙规则，并显示局域网访问地址。

## 重要说明

- Snipe-IT 没有 WordPress 那种“插件市场”。这里的“插件/依赖”指运行它必须要的 Docker Desktop、WSL2、Snipe-IT 镜像、数据库镜像和邮件测试镜像。
- 数据保存在 Docker 卷里，不会因为关闭网页而丢失。
- 不要随便删除 Docker 卷，否则资产数据、附件和数据库都会丢失。
- 局域网其他电脑访问地址是 `http://服务器IP:8088`，例如 `http://192.168.1.20:8088`。如果打不开，先双击 `07-启用局域网访问.bat`，再双击 `08-局域网访问诊断.bat` 看结果。
- 部署成功后，文件夹里会生成 `局域网访问地址.txt`，可以把里面的地址发给同事使用。
- 默认界面语言设置为 `zh-CN`，时区为 `Asia/Shanghai`。需要英文界面可把 `.env` 里的 `APP_LOCALE` 改为 `en-US`。
- 如果看到 `docker: unknown command: docker compose`，说明那台机器缺 Docker Compose 插件。请确认 `offline-dependencies\docker-compose.exe` 存在，然后重新双击 `01-一键部署并启动Snipe-IT.bat`。

## 端口

- Snipe-IT：`8088`
- 本地测试邮件箱 Mailpit：`8025`

## 升级版本

当前固定版本是 `v8.6.1`。以后升级前先双击 `06-备份Snipe-IT数据.bat`，再修改 `.env` 和 `docker-compose.yml` 中的版本号，然后重新生成离线包。




