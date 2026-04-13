# LumenIM Windows → Linux 离线部署完整指南

**文档版本**: 1.0.0  
**更新日期**: 2026-04-08  
**适用系统**: Windows 10/11 → CentOS 7 (离线部署)

---

## 一、部署流程概览

```
┌────────────────────────────────────────────────────────────────────────┐
│             Windows → CentOS 7 离线部署流程             │
└────────────────────────────────────────────────────────────────────────┘
                           │
     ┌─────────────────────┐
     │  阶段一：下载      │  Windows 有网
     │  准备离线包      │  环境
     └────────┬──────────┘
              │
              ▼
     ┌─────────────────────┐
     │  阶段二：传输      │  U盘/局域网
     │  打包上传        │
     └────────┬──────────┘
              │
              ▼
     ┌─────────────────────┐
     │  阶段三：安装      │  CentOS 7
     │  离线部署        │  目标服务器
     └────────┬──────────┘
              │
              ▼
     ┌─────────────────────┐
     │  阶段四：验证      │  验证部署
     │  服务测试        │  结果
     └─────────────────────┘
```

---

## 二、阶段一：Windows 下载离线包

### 2.1 使用 PowerShell 脚本下载（推荐）

```powershell
# 1. 打开 PowerShell（管理员）
# 进入脚本目录
cd D:\学习资料\AI_Projects\LumenIM\software\scripts

# 2. 下载所有离线包
.\Download-Packages.ps1 -OutputDir "D:\LumenIM-Packages"

# 或按需下载
.\Download-Packages.ps1 -OutputDir "D:\LumenIM-Packages" -Go       # 仅 Go
.\Download-Packages.ps1 -OutputDir "D:\LumenIM-Packages" -Node      # 仅 Node.js
.\Download-Packages.ps1 -OutputDir "D:\LumenIM-Packages" -Docker    # 仅 Docker
```

### 2.2 手动下载

```powershell
# 创建目录
New-Item -ItemType Directory -Path "D:\LumenIM-Packages" -Force

# Go 1.21.14
Invoke-WebRequest -Uri "https://go.dev/dl/go1.21.14.linux-amd64.tar.gz" `
    -OutFile "D:\LumenIM-Packages\go1.21.14.linux-amd64.tar.gz"

# Node.js 18.20.5
Invoke-WebRequest -Uri "https://nodejs.org/dist/v18.20.5/node-v18.20.5-linux-x64.tar.xz" `
    -OutFile "D:\LumenIM-Packages\node-v18.20.5-linux-x64.tar.xz"

# pnpm
Invoke-WebRequest -Uri "https://github.com/pnpm/pnpm/releases/download/v8.15.0/pnpm-linux-x64" `
    -OutFile "D:\LumenIM-Packages\pnpm"

# Protocol Buffers
Invoke-WebRequest -Uri "https://github.com/protocolbuffers/protobuf/releases/download/v25.1/protoc-25.1-linux-x86_64.zip" `
    -OutFile "D:\LumenIM-Packages\protoc-25.1-linux-x86_64.zip"

# Docker RPM 包
$dockerPackages = @(
    "containerd.io-24.0.9-3.el7.x86_64.rpm",
    "docker-ce-24.0.9-3.el7.x86_64.rpm",
    "docker-ce-cli-24.0.9-3.el7.x86_64.rpm",
    "docker-buildx-plugin-0.12.1-1.el7.x86_64.rpm",
    "docker-compose-plugin-2.24.5-1.el7.x86_64.rpm"
)

foreach ($pkg in $dockerPackages) {
    $url = "https://download.docker.com/linux/centos/7/x86_64/stable/Packages/$pkg"
    $outFile = "D:\LumenIM-Packages\docker\$pkg"
    New-Item -ItemType Directory -Path "D:\LumenIM-Packages\docker" -Force
    Invoke-WebRequest -Uri $url -OutFile $outFile
}
```

### 2.3 打包项目文件

```powershell
# 打包后端
Compress-Archive -Path "D:\学习资料\AI_Projects\LumenIM\backend" `
    -DestinationPath "D:\LumenIM-Packages\backend.tar.gz" -Force

# 打包前端（排除 node_modules）
Get-ChildItem -Path "D:\学习资料\AI_Projects\LumenIM\front" -Exclude "node_modules" |
    Compress-Archive -DestinationPath "D:\LumenIM-Packages\front.tar.gz" -Force
```

### 2.4 下载清单

下载完成后，`D:\LumenIM-Packages` 目录结构：

```
D:\LumenIM-Packages\
├── go1.21.14.linux-amd64.tar.gz       (~105 MB)
├── node-v18.20.5-linux-x64.tar.xz   (~35 MB)
├── pnpm                              (~15 KB)
├── protoc-25.1-linux-x86_64.zip     (~3 MB)
├── backend.tar.gz                    (项目相关)
├── front.tar.gz                     (项目相关)
└── docker\
    ├── containerd.io-24.0.9-3.el7.x86_64.rpm
    ├── docker-ce-24.0.9-3.el7.x86_64.rpm
    ├── docker-ce-cli-24.0.9-3.el7.x86_64.rpm
    └── ...
```

### 2.5 文件大小汇总

| 文件 | 预计大小 |
|------|----------|
| Go | 105 MB |
| Node.js | 35 MB |
| pnpm | 15 KB |
| Protocol Buffers | 3 MB |
| Docker RPM | 75 MB |
| 后端 | 视项目 |
| 前端 | 视项目 |
| **合计** | **~220 MB+** |

---

## 三、阶段二：传输到目标服务器

### 3.1 U 盘方式（推荐）

```powershell
# 1. 格式化 U 盘为 NTFS 或 exFAT
# 2. 复制文件

# 在 Windows 文件管理器中复制
# D:\LumenIM-Packages\* -> U 盘

# 3. 在 CentOS 服务器上挂载
# 插入 U 盘后执行：
sudo fdisk -l                          # 查看磁盘
sudo mount /dev/sdb1 /mnt/usb          # 挂载（假设 sdb1 是 U 盘）
ls -la /mnt/usb                       # 确认文件
```

### 3.2 网络传输（如果可以访问）

```powershell
# Windows 作为临时服务器
cd D:\LumenIM-Packages
python -m http.server 8080

# 或者使用 SMB
# 右键文件夹 -> 属性 -> 共享
```

```bash
# CentOS 服务器上下载（如果有网络）
wget -r -ncpv --no-parent http://windows-pc:8080/ -P /mnt/packages
```

### 3.3 SCP 文件传输

```bash
# 从 Windows（使用 WinSCP 或类似工具）
# 或从其他 Linux 服务器
scp -r /path/to/packages user@centos7-server:/tmp/packages
```

---

## 四、阶段三：CentOS 7 离线安装

### 4.1 前置准备

```bash
# 1. 以 root 登录或使用 sudo
su -

# 2. 挂载离线包目录
# 方法 A：U 盘挂载
mount /dev/sdb1 /mnt/packages

# 方法 B：如果已经用 scp 传输
ls -la /tmp/packages
```

### 4.2 一键离线安装

```bash
# 进入脚本目录
cd /tmp/packages  # 或其他挂载点

# 执行离线安装脚本
chmod +x install-offline.sh
./install-offline.sh --all --dir=/mnt/packages
```

### 4.3 分步安装（可选）

```bash
# 1. 检查环境
./install-offline.sh --check --dir=/mnt/packages

# 2. 安装系统依赖
./install-offline.sh --dir=/mnt/packages --deps

# 3. 安装运行时
./install-offline.sh --dir=/mnt/packages --go --node

# 4. 安装 protobuf
./install-offline.sh --dir=/mnt/packages --protobuf

# 5. 安装 Docker（可选，需要离线包中有 docker 目录）
./install-offline.sh --dir=/mnt/packages --docker

# 6. 安装 MySQL/Redis（需要先安装 Docker）
./install-offline.sh --dir=/mnt/packages --mysql --redis

# 7. 启动服务
./install-offline.sh --dir=/mnt/packages --services
```

### 4.4 手动安装步骤

如果上述脚本无法���用，按以下手动步骤：

```bash
# ===== 步骤 1: 安装系统依赖 =====
yum install -y wget curl git unzip tar xz gcc gcc-c++ make
yum install -y epel-release
yum install -y net-tools lsof jq openssl perl
yum groupinstall -y "Development Tools"

# ===== 步骤 2: 安装 Go =====
cd /
rm -rf /usr/local/go
tar -xzf /mnt/packages/go1.21.14.linux-amd64.tar.gz
cat > /etc/profile.d/go.sh << 'EOF'
export GOROOT=/usr/local/go
export PATH=$PATH:$GOROOT/bin
export GOPATH=$HOME/go
EOF
chmod +x /etc/profile.d/go.sh

# 验证
source /etc/profile.d/go.sh
go version

# ===== 步骤 3: 安装 Node.js =====
cd /
rm -rf /usr/local/node
tar -xJf /mnt/packages/node-v18.20.5-linux-x64.tar.xz
mv node-v18.20.5-linux-x64 /usr/local/node
cp /mnt/packages/pnpm /usr/local/node/bin/pnpm
chmod +x /usr/local/node/bin/pnpm

cat > /etc/profile.d/nodejs.sh << 'EOF'
export NODE_PREFIX=/usr/local/node
export PATH=$PATH:$NODE_PREFIX/bin
EOF
chmod +x /etc/profile.d/nodejs.sh

source /etc/profile.d/nodejs.sh
node --version

# ===== 步骤 4: 安装 Protocol Buffers =====
unzip -qo /mnt/packages/protoc-25.1-linux-x86_64.zip -d /usr/local/
cp -f /usr/local/protobuf/bin/protoc /usr/local/bin/
protoc --version

# ===== 步骤 5: 安装 Docker =====
cd /mnt/packages/docker
rpm -Uvh --force *.rpm
systemctl start docker
systemctl enable docker
docker --version

# ===== 步骤 6: 安装 MySQL =====
docker pull mysql:8.0.35
mkdir -p /var/lib/lumenim/mysql
docker run -d --name lumenim-mysql \
    -e MYSQL_ROOT_PASSWORD=wenming429 \
    -e MYSQL_DATABASE=go_chat \
    -e MYSQL_USER=lumenim \
    -e MYSQL_PASSWORD=lumenim123 \
    -p 3306:3306 \
    -v /var/lib/lumenim/mysql:/var/lib/mysql \
    mysql:8.0.35 --default-authentication-plugin=mysql_native_password

# ===== 步骤 7: 安装 Redis =====
docker pull redis:7.4.1
mkdir -p /var/lib/lumenim/redis
docker run -d --name lumenim-redis \
    -p 6379:6379 \
    -v /var/lib/lumenim/redis:/data \
    redis:7.4.1 redis-server --appendonly yes

# ===== 步骤 8: 部署项目 =====
# 复制项目文件
cp /mnt/packages/backend.tar.gz /var/www/
cp /mnt/packages/front.tar.gz /var/www/
cd /var/www
tar -xzf backend.tar.gz
tar -xzf front.tar.gz

# 移动目录
mv backend lumenim
mv front lumenim/front

# 配置权限
useradd -r -s /bin/false -d /nonexistent www-data 2>/dev/null || true
chown -R www-data:www-data /var/www/lumenim

# ===== 步骤 9: 创建 systemd 服务 =====
cat > /etc/systemd/system/lumenim-backend.service << 'EOF'
[Unit]
Description=LumenIM Backend Service
After=network.target mysql.service redis.service docker.service

[Service]
Type=simple
User=www-data
Group=www-data
WorkingDirectory=/var/www/lumenim/backend
Environment="PATH=/usr/local/go/bin:/usr/local/node/bin:$PATH"
Environment="PORT=9501"
ExecStart=/var/www/lumenim/backend/bin/lumenim
Restart=on-failure
RestartSec=5s

[Install]
WantedBy=multi-user.target
EOF

cat > /etc/systemd/system/lumenim-frontend.service << 'EOF'
[Unit]
Description=LumenIM Frontend Service
After=network.target

[Service]
Type=simple
User=www-data
Group=www-data
WorkingDirectory=/var/www/lumenim/front
Environment="PATH=/usr/local/node/bin:$PATH"
ExecStart=/usr/local/node/bin/node /var/www/lumenim/front/node_modules/.bin/vite --port 5173
Restart=on-failure
RestartSec=5s

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload

# ===== 步骤 10: 启动服务 =====
systemctl start lumenim-backend
systemctl enable lumenim-backend
```

---

## 五、阶段四：验证部署

### 5.1 运行验证脚本

```bash
# 在服务器上执行
./verify-offline.sh
```

### 5.2 手动验证

```bash
# ===== 1. 系统检查 =====
cat /etc/centos-release
# 应该是 CentOS Linux release 7.

# ===== 2. 运行时检�� =====
source /etc/profile.d/go.sh
go version
# 应该是 go1.21.14

source /etc/profile.d/nodejs.sh
node --version
# 应该是 v18.20.5

pnpm --version
# 应该是 8.x.x

protoc --version
# 应该是 libprotoc 25.1.0

# ===== 3. Docker 检查 =====
docker --version
docker ps

# ===== 4. 端口检查 =====
lsof -i:9501   # 后端 HTTP
lsof -i:9502   # WebSocket
lsof -i:3306   # MySQL
lsof -i:6379   # Redis

# ===== 5. 服务状态 =====
systemctl status lumenim-backend
systemctl status lumenim-frontend

# ===== 6. API 测试 =====
curl http://localhost:9501/api/v1/health

# ===== 7. 日志 =====
journalctl -u lumenim-backend -f
journalctl -u lumenim-frontend -f
```

### 5.3 访问测试

| 服务 | 地址 | 说明 |
|------|------|------|
| 后端 API | http://localhost:9501 | HTTP API |
| WebSocket | ws://localhost:9502 | WebSocket |
| 前端 | http://localhost:5173 | Vite 开发服务器 |
| MySQL | localhost:3306 | Docker 容器 |
| Redis | localhost:6379 | Docker 容器 |

---

## 六、故障排查

### 6.1 文件不存在

```bash
# 检查挂载点
mount | grep sdb

# 重新挂载
umount /mnt/usb
mount -t vfat /dev/sdb1 /mnt/usb
```

### 6.2 权限问题

```bash
# 添加执行权限
chmod +x install-offline.sh
chmod +x verify-offline.sh
chmod +x /mnt/packages/pnpm
```

### 6.3 端口占用

```bash
# 查找占用
lsof -i:9501
netstat -tlnp | grep 9501

# 释放
kill -9 <PID>
```

### 6.4 Docker 启动失败

```bash
# 检查 Docker 状态
systemctl status docker
journalctl -u docker -n 20

# 手动启动
dockerd &
```

### 6.5 数据库连接失败

```bash
# 查看容器日志
docker logs lumenim-mysql
docker logs lumenim-redis

# 重启容器
docker restart lumenim-mysql
docker restart lumenim-redis

# 等待启动
sleep 30
```

---

## 七、快速参考

### 7.1 Windows 命令汇总

```powershell
# 下载离线包
cd D:\学习资料\AI_Projects\LumenIM\software\scripts
.\Download-Packages.ps1 -OutputDir "D:\LumenIM-Packages"

# 打包项目
Compress-Archive -Path "backend" -DestinationPath "D:\LumenIM-Packages\backend.tar.gz"
Get-ChildItem front -Exclude node_modules | Compress-Archive -DestinationPath "D:\LumenIM-Packages\front.tar.gz"
```

### 7.2 CentOS 命令汇总

```bash
# ===== 挂载 =====
mount /dev/sdb1 /mnt/packages
ls -la /mnt/packages

# ===== 安装 =====
chmod +x install-offline.sh
./install-offline.sh --all --dir=/mnt/packages

# ===== 验证 =====
./verify-offline.sh

# ===== 手动验证 =====
source /etc/profile.d/go.sh && go version
source /etc/profile.d/nodejs.sh && node --version
docker ps
curl http://localhost:9501/api/v1/health
```

---

**文档结束**