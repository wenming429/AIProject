# LumenIM 后端跨平台部署指南

## 概述

本文档详细说明如何在 Windows 本地开发环境交叉编译 Go 后端代码，并在 Ubuntu 20.04 服务器上部署。

---

## 一、前置条件

### 1.1 Windows 本地环境

```powershell
# 检查 Go 版本 (需要 Go 1.25.7)
go version

# 检查 Go 环境变量
go env GOOS GOARCH GOROOT GOPATH
```

### 1.2 Ubuntu 20.04 服务器环境

```bash
# 检查是否有 Go（用于依赖下载，编译在本地完成）
go version

# 创建部署目录
sudo mkdir -p /var/www/lumenim
sudo chown -R $USER:$USER /var/www/lumenim
```

---

## 二、交叉编译（Windows → Linux）

### 2.1 编译命令

```powershell
# 进入后端目录
cd d:\学习资料\AI_Projects\LumenIM\backend

# 交叉编译 Linux amd64 可执行文件
set GOOS=linux
set GOARCH=amd64
set CGO_ENABLED=0
go build -o lumenim ./cmd/lumenim

# 或者一行命令
GOOS=linux GOARCH=amd64 CGO_ENABLED=0 go build -o lumenim ./cmd/lumenim
```

### 2.2 使用 Makefile（推荐）

```powershell
cd d:\学习资料\AI_Projects\LumenIM\backend
make build-linux-amd64
```

### 2.3 编译选项说明

| 参数 | 值 | 说明 |
|------|-----|------|
| `GOOS` | `linux` | 目标操作系统 |
| `GOARCH` | `amd64` | 目标架构 |
| `CGO_ENABLED` | `0` | 禁用 CGO（静态编译） |

### 2.4 验证编译结果

```powershell
# 检查文件类型（应为 Linux 可执行文件）
file lumenim.exe   # Windows 查看 Linux 文件

# 或使用 PowerShell
Get-Item lumenim | Select Name, Length
```

---

## 三、准备部署包

### 3.1 打包目录结构

```
lumenim-deploy/
├── lumenim              # 编译好的可执行文件
├── config.example.yaml  # 配置文件模板
├── docker-compose.yaml  # Docker 编排文件（如需要）
└── init.sql            # 数据库初始化脚本（如需要）
```

### 3.2 创建部署目录并复制文件

```powershell
# 创建部署目录
$deployDir = "d:\学习资料\AI_Projects\LumenIM\deploy-package"
New-Item -ItemType Directory -Force -Path $deployDir

# 复制编译好的可执行文件
Copy-Item "d:\学习资料\AI_Projects\LumenIM\backend\lumenim" "$deployDir\"

# 复制配置文件
Copy-Item "d:\学习资料\AI_Projects\LumenIM\backend\config.example.yaml" "$deployDir\"

# 复制 Docker 相关文件（如需要）
Copy-Item "d:\学习资料\AI_Projects\LumenIM\docker-compose.yaml" "$deployDir\"

# 压缩打包
Compress-Archive -Path "$deployDir\*" -DestinationPath "d:\lumenim-deploy.zip" -Force
```

### 3.3 手动复制到 U 盘或共享目录

```
Windows:        d:\lumenim-deploy.zip
              ↓
U盘/共享目录    ↓
Ubuntu:        ~/lumenim-deploy.zip
```

---

## 四、传输文件到服务器

### 4.1 方法一：SCP（推荐）

```powershell
# Windows PowerShell
scp d:\lumenim-deploy.zip username@ubuntu-server:/home/username/

# 或使用 psftp
pscp -r d:\lumenim-deploy.zip username@ubuntu-server:/home/username/
```

### 4.2 方法二：Rsync（适合大文件）

```powershell
# Windows（需要 WSL 或 rsync for Windows）
rsync -avz --progress d:\lumenim-deploy.zip username@ubuntu-server:/home/username/
```

### 4.3 方法三：SMB 共享

```bash
# Ubuntu 服务器端
sudo apt install -y samba
sudo smbpasswd -a username

# Windows 资源管理器访问
\\ubuntu-server-ip\lumenim-deploy
```

### 4.4 方法四：Git 仓库

```powershell
# 本地提交并推送
git add .
git commit -m "编译版本"
git push

# 服务器拉取
cd /var/www/lumenim
git pull
```

---

## 五、服务器端部署

### 5.1 解压部署包

```bash
# 解压
cd /var/www/lumenim
unzip ~/lumenim-deploy.zip -d ./deploy-temp

# 或者直接使用后端目录
cp deploy-temp/lumenim ./backend/
```

### 5.2 配置

```bash
cd /var/www/lumenim/backend

# 复制配置文件
cp config.example.yaml config.yaml

# 编辑配置
nano config.yaml
```

### 5.3 设置权限

```bash
# 赋予执行权限
chmod +x lumenim

# 设置所有者
sudo chown root:root lumenim
sudo chmod 755 lumenim
```

### 5.4 数据库初始化（如需要）

```bash
# 导入数据库
mysql -u root -p lumenim < init.sql
```

---

## 六、运行服务

### 6.1 直接运行（测试）

```bash
cd /var/www/lumenim/backend
./lumenim --help
./lumenim serve
```

### 6.2 Systemd 服务（生产环境）

```bash
# 创建服务文件
sudo nano /etc/systemd/system/lumenim.service
```

```ini
[Unit]
Description=LumenIM Server
After=network.target mysql.service redis.service

[Service]
Type=simple
User=www-data
Group=www-data
WorkingDirectory=/var/www/lumenim/backend
ExecStart=/var/www/lumenim/backend/lumenim serve
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
```

```bash
# 启用并启动服务
sudo systemctl daemon-reload
sudo systemctl enable lumenim
sudo systemctl start lumenim

# 检查状态
sudo systemctl status lumenim
```

### 6.3 Docker 部署

```bash
cd /var/www/lumenim

# 构建镜像
docker build -t lumenim:latest ./backend

# 运行容器
docker run -d \
  --name lumenim \
  -p 8080:8080 \
  -v $(pwd)/backend/config.yaml:/app/config.yaml \
  lumenim:latest
```

---

## 七、自动化部署脚本

### 7.1 Windows 端构建脚本

```powershell
# build-deploy.ps1
param(
    [string]$Server = "ubuntu-server",
    [string]$User = "username",
    [string]$Password = ""
)

$ErrorActionPreference = "Stop"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  LumenIM 交叉编译与部署脚本" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

# 1. 交叉编译
Write-Host "`n[1/5] 交叉编译 Linux amd64..." -ForegroundColor Yellow
Set-Location "d:\学习资料\AI_Projects\LumenIM\backend"
$env:GOOS = "linux"
$env:GOARCH = "amd64"
$env:CGO_ENABLED = "0"
go build -o lumenim ./cmd/lumenim
Write-Host "编译完成: backend\lumenim" -ForegroundColor Green

# 2. 创建部署目录
Write-Host "`n[2/5] 创建部署包..." -ForegroundColor Yellow
$deployDir = "d:\lumenim-deploy-temp"
if (Test-Path $deployDir) { Remove-Item $deployDir -Recurse -Force }
New-Item -ItemType Directory -Force -Path $deployDir | Out-Null

Copy-Item "backend\lumenim" "$deployDir\"
Copy-Item "backend\config.example.yaml" "$deployDir\"
Copy-Item "docker-compose.yaml" "$deployDir\"

$zipPath = "d:\lumenim-deploy.zip"
Compress-Archive -Path "$deployDir\*" -DestinationPath $zipPath -Force
Write-Host "部署包已创建: $zipPath" -ForegroundColor Green

# 3. 传输文件
Write-Host "`n[3/5] 传输文件到服务器..." -ForegroundColor Yellow
$scpCmd = "scp $zipPath $User@$Server`:/home/$User/"
Write-Host "执行: $scpCmd" -ForegroundColor Gray
& scp $zipPath "$User@$Server`:/home/$User/"

# 4. 服务器端部署
Write-Host "`n[4/5] 服务器端部署..." -ForegroundColor Yellow
ssh $User@$Server @"
cd /var/www/lumenim
unzip -o /home/$User/lumenim-deploy.zip -d ./deploy-temp
cp deploy-temp/lumenim ./backend/
cp deploy-temp/config.example.yaml ./backend/
chmod +x ./backend/lumenim
"@

# 5. 重启服务
Write-Host "`n[5/5] 重启服务..." -ForegroundColor Yellow
ssh $User@$Server "sudo systemctl restart lumenim"

Write-Host "`n========================================" -ForegroundColor Green
Write-Host "  部署完成！" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
```

### 7.2 服务器端部署脚本

```bash
#!/bin/bash
# deploy-server.sh

DEPLOY_DIR="/var/www/lumenim"
TEMP_DIR="$DEPLOY_DIR/deploy-temp"

echo "========================================"
echo "  LumenIM 服务器部署脚本"
echo "========================================"

# 1. 解压部署包
echo "[1/4] 解压部署包..."
cd /home/$(whoami)
unzip -o lumenim-deploy.zip -d $TEMP_DIR

# 2. 备份当前版本
echo "[2/4] 备份当前版本..."
if [ -f "$DEPLOY_DIR/backend/lumenim" ]; then
    cp "$DEPLOY_DIR/backend/lumenim" "$DEPLOY_DIR/backend/lumenim.backup.$(date +%Y%m%d%H%M%S)"
fi

# 3. 更新文件
echo "[3/4] 更新文件..."
cp "$TEMP_DIR/lumenim" "$DEPLOY_DIR/backend/"
cp "$TEMP_DIR/config.example.yaml" "$DEPLOY_DIR/backend/config.yaml.new"
chmod +x "$DEPLOY_DIR/backend/lumenim"

# 4. 重启服务
echo "[4/4] 重启服务..."
sudo systemctl restart lumenim

# 验证
if systemctl is-active --quiet lumenim; then
    echo "服务运行正常！"
else
    echo "服务启动失败，检查日志："
    sudo journalctl -u lumenim -n 20
fi

echo ""
echo "========================================"
echo "  部署完成"
echo "========================================"
```

---

## 八、完整流程速查

```
┌─────────────────────────────────────────────────────────────┐
│                    Windows 本地                              │
├─────────────────────────────────────────────────────────────┤
│  1. 交叉编译                                                 │
│     GOOS=linux GOARCH=amd64 CGO_ENABLED=0 go build         │
│                     ↓                                       │
│  2. 打包                                                     │
│     Compress-Archive → lumenim-deploy.zip                   │
│                     ↓                                       │
│  3. 传输                                                     │
│     scp/rsync/SMB → Ubuntu 服务器                           │
└─────────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────────┐
│                   Ubuntu 20.04 服务器                        │
├─────────────────────────────────────────────────────────────┤
│  1. 解压                                                     │
│     unzip lumenim-deploy.zip                                │
│                     ↓                                       │
│  2. 复制文件                                                 │
│     cp lumenim backend/                                     │
│                     ↓                                       │
│  3. 设置权限                                                 │
│     chmod +x lumenim                                        │
│                     ↓                                       │
│  4. 启动服务                                                 │
│     systemctl start lumenim                                 │
└─────────────────────────────────────────────────────────────┘
```

---

## 九、常见问题

| 问题 | 解决方案 |
|------|----------|
| `scp: command not found` | Windows 安装 OpenSSH 或使用 PowerShell scp |
| `permission denied` | 检查 SSH 密钥或使用 sudo |
| `lumenim: No such file` | 检查文件路径和权限 |
| `service failed` | 查看日志 `journalctl -u lumenim` |

---

## 十、依赖说明

LumenIM 后端使用 Go 模块管理依赖，无需 `requirements.txt` 或 `package.json`。

**编译前确保依赖已下载**：
```powershell
cd d:\学习资料\AI_Projects\LumenIM\backend
go mod download
go mod tidy
```
