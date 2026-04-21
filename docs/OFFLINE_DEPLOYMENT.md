# LumenIM 前后端离线部署操作指南

## 目录

- [概述](#概述)
- [前置准备](#前置准备)
- [准备离线包](#准备离线包)
- [部署后端](#部署后端)
- [部署前端](#部署前端)
- [自动化部署](#自动化部署)
- [验证部署](#验证部署)
- [回滚操作](#回滚操作)
- [常见问题](#常见问题)

---

## 概述

本文档介绍如何在离线环境下部署 LumenIM 前后端服务，适用于 CentOS 7.x 服务器。

### 环境要求

| 组件 | 版本要求 | 说明 |
|------|---------|------|
| 操作系统 | CentOS 7.x | 64位 |
| Docker | 20.10+ | 容器运行时 |
| Docker Compose | 2.0+ | 容器编排 |
| Nginx | 1.20+ | Web 服务器 |
| MySQL | 8.0.35 | 数据库（Docker） |
| Redis | 7.4.1 | 缓存（Docker） |

---

## 前置准备

### 1. 创建 LumenIM 应用用户

LumenIM 使用专用应用用户 `lumenimadmin` 运行服务，该用户具有以下特点：
- 用户名：`lumenimadmin`
- 密码：`wenming429`
- 系统用户（不可登录 shell）

```bash
# 创建用户（如已存在则跳过）
useradd -r -s /sbin/nologin lumenimadmin 2>/dev/null || true

# 设置密码
echo "lumenimadmin:wenming429" | chpasswd

# 验证用户创建成功
id lumenimadmin
```

预期输出：
```
uid=xxx(lumenimadmin) gid=xxx(lumenimadmin) groups=xxx(lumenimadmin)
```

> **注意**：使用自动化脚本部署时，用户创建步骤会自动执行，无需手动创建。

### 2. 检查 Docker 环境

```bash
# 检查 Docker 版本
docker --version

# 检查 Docker 服务状态
systemctl status docker

# 如果服务未启动
systemctl start docker
systemctl enable docker
```

### 3. 创建 MySQL 容器

```bash
docker run -d \
  --name lumenim-mysql \
  -p 3306:3306 \
  -e MYSQL_ROOT_PASSWORD=wenming429 \
  -e MYSQL_DATABASE=go_chat \
  -v /var/lib/lumenim/mysql:/var/lib/mysql \
  --restart=always \
  mysql:8.0.35 \
  --character-set-server=utf8mb4 \
  --collation-server=utf8mb4_unicode_ci
```

### 4. 创建 Redis 容器

```bash
docker run -d \
  --name lumenim-redis \
  -p 6379:6379 \
  -v /var/lib/lumenim/redis:/data \
  --restart=always \
  redis:7.4.1 \
  redis-server --appendonly yes
```

### 5. 配置 Nginx

```bash
# 安装 Nginx（如未安装）
yum install -y nginx

# 启动并启用 Nginx
systemctl start nginx
systemctl enable nginx
```

---

## 准备离线包

### 打包前准备

**重要**：打包前请确保后端目录包含 `.env` 配置文件：

```bash
# 检查 .env 文件是否存在
ls -la backend/.env

# 如果 .env.example 存在但 .env 不存在，先复制
cp backend/.env.example backend/.env

# 编辑 .env 配置数据库和 Redis 连接信息
vi backend/.env
```

### Linux/macOS 打包

在 Linux 或 macOS 终端执行以下命令：

```bash
cd /path/to/LumenIM

# 创建临时目录
mkdir -p /tmp/lumenim-packages

# 打包后端（包含 .env 配置文件）
tar -czvf /tmp/lumenim-packages/backend.tar.gz \
  --exclude='backend/data/im-private' \
  --exclude='backend/data/im-static' \
  --exclude='backend/data/logs' \
  --exclude='backend/vendor' \
  --exclude='**/.git' \
  -C backend .

# 打包前端
tar -czvf /tmp/lumenim-packages/front.tar.gz \
  --exclude='node_modules' \
  --exclude='dist' \
  --exclude='**/.git' \
  -C front .
```

### Windows 11 打包

#### 方式 A：使用 Git Bash（推荐）

```bash
# 进入项目目录
cd /d/学习资料/AI_Projects/LumenIM

# 创建临时目录
mkdir -p /tmp/lumenim-packages

# 打包后端（包含 .env）
tar -czvf /tmp/lumenim-packages/backend.tar.gz \
  --exclude='backend/data/im-private' \
  --exclude='backend/data/im-static' \
  --exclude='backend/data/logs' \
  --exclude='backend/vendor' \
  --exclude='**/.git' \
  -C backend .

# 打包前端
tar -czvf /tmp/lumenim-packages/front.tar.gz \
  --exclude='node_modules' \
  --exclude='dist' \
  --exclude='**/.git' \
  -C front .

# 查看打包结果
ls -la /tmp/lumenim-packages/
```

#### 方式 B：使用 PowerShell（Windows 11 原生 tar）

Windows 11 内置了 tar 命令，无需安装额外软件：

```powershell
# 进入项目目录
cd D:\学习资料\AI_Projects\LumenIM

# 创建临时目录
$pkgDir = "D:\temp\lumenim-packages"
New-Item -ItemType Directory -Force -Path $pkgDir | Out-Null

# 打包后端（包含 .env）
tar -czvf "$pkgDir\backend.tar.gz" -C backend .

# 打包前端
tar -czvf "$pkgDir\front.tar.gz" -C front .

# 查看打包结果
Get-ChildItem $pkgDir
```

> **注意**：PowerShell 的 tar 命令不支持 --exclude 参数，请确保 `backend` 和 `front` 目录中已清理不需要的文件（如 `node_modules`、`vendor`、`dist` 等），或者在打包后手动删除这些目录。

#### 方式 C：使用 PowerShell + 7-Zip（需安装 7-Zip）

如果已安装 7-Zip，可使用以下命令：

```powershell
# 进入项目目录
cd D:\学习资料\AI_Projects\LumenIM

# 创建临时目录
$pkgDir = "D:\temp\lumenim-packages"
New-Item -ItemType Directory -Force -Path $pkgDir | Out-Null

# 使用 7z 打包后端（包含 .env）
7z a -ttar -tgzip "$pkgDir\backend.tar.gz" `
  -x!backend\data\im-private `
  -x!backend\data\im-static `
  -x!backend\data\logs `
  -x!backend\vendor `
  -x!**\.git `
  "backend\*"

# 使用 7z 打包前端
7z a -ttar -tgzip "$pkgDir\front.tar.gz" `
  -x!front\node_modules `
  -x!front\dist `
  -x!**\.git `
  "front\*"

# 查看打包结果
Get-ChildItem $pkgDir
```

### 打包完成后验证

**Linux/macOS/Git Bash：**
```bash
# 在目标服务器上验证 .env 是否存在
tar -tzf /mnt/packages/backend.tar.gz | grep -E "\.env$"
```

**PowerShell：**
```powershell
# 检查 backend.tar.gz 是否包含 .env
tar -tzf "$pkgDir\backend.tar.gz" | Select-String "\.env"
```

预期输出应包含：
```
.env
```

### 传输离线包到服务器

```bash
# Linux/macOS
scp /tmp/lumenim-packages/*.tar.gz root@目标服务器:/mnt/packages/

# Windows PowerShell
pscp D:\temp\lumenim-packages\*.tar.gz root@目标服务器:/mnt/packages/
```

---

## 部署后端

### 方式一：手动部署

```bash
# 创建部署目录
mkdir -p /var/www/lumenim/backend
mkdir -p /var/lib/lumenim/backups

# 解压后端包
tar -xzvf /mnt/packages/backend.tar.gz -C /var/www/lumenim/backend/

# 设置权限（使用 lumenimadmin 用户）
chown -R lumenimadmin:lumenimadmin /var/www/lumenim/backend

# 检查配置文件
ls -la /var/www/lumenim/backend/.env
ls -la /var/www/lumenim/backend/config.yaml
```

### 配置后端服务

创建 systemd 服务文件 `/etc/systemd/system/lumenim-backend.service`：

```ini
[Unit]
Description=LumenIM Backend Service
After=network.target mysql.service redis.service
Wants=mysql.service redis.service

[Service]
Type=simple
User=lumenimadmin
WorkingDirectory=/var/www/lumenim/backend
ExecStart=/var/www/lumenim/backend/lumenim-backend
Restart=always
RestartSec=5
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
```

启动服务：

```bash
# 重载 systemd
systemctl daemon-reload

# 启用并启动服务
systemctl enable lumenim-backend
systemctl start lumenim-backend

# 检查服务状态
systemctl status lumenim-backend
```

### 后端配置说明

编辑 `.env` 文件：

```bash
vi /var/www/lumenim/backend/.env
```

关键配置项：

| 配置项 | 说明 | 示例值 |
|-------|------|--------|
| DB_HOST | 数据库地址 | 127.0.0.1 |
| DB_PORT | 数据库端口 | 3306 |
| DB_USER | 数据库用户 | root |
| DB_PASSWORD | 数据库密码 | wenming429 |
| DB_NAME | 数据库名 | go_chat |
| REDIS_HOST | Redis 地址 | 127.0.0.1 |
| REDIS_PORT | Redis 端口 | 6379 |
| HTTP_PORT | HTTP 服务端口 | 8080 |

---

## 部署前端

### 方式一：手动部署

```bash
# 创建部署目录
mkdir -p /var/www/lumenim/front

# 解压前端包
tar -xzvf /mnt/packages/front.tar.gz -C /var/www/lumenim/front/

# 设置权限（使用 lumenimadmin 用户）
chown -R lumenimadmin:lumenimadmin /var/www/lumenim/front
```

### 配置 Nginx

创建 Nginx 配置文件 `/etc/nginx/conf.d/lumenim.conf`：

```nginx
server {
    listen 9501;
    server_name _;

    root /var/www/lumenim/front/dist;
    index index.html;

    # 前端静态文件
    location / {
        try_files $uri $uri/ /index.html;
    }

    # API 反向代理
    location /api/ {
        proxy_pass http://127.0.0.1:8080/api/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    # WebSocket 支持
    location /ws {
        proxy_pass http://127.0.0.1:8080/ws;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
    }

    # 静态资源缓存
    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
    }
}
```

重载 Nginx：

```bash
# 测试配置
nginx -t

# 重载 Nginx
systemctl reload nginx
```

---

## 自动化部署

使用提供的自动化脚本 `deploy-packages.sh`：

```bash
# 上传离线包到 /mnt/packages 目录
# 确保包含 backend.tar.gz 和 front.tar.gz

# 完整部署
sudo ./software/deploy-packages.sh

# 仅验证离线包
sudo ./software/deploy-packages.sh --check

# 仅部署后端
sudo ./software/deploy-packages.sh --backend

# 仅部署前端
sudo ./software/deploy-packages.sh --frontend

# 指定包目录
sudo ./software/deploy-packages.sh --dir=/tmp/packages

# 回滚
sudo ./software/deploy-packages.sh --rollback
```

### 脚本功能

| 功能 | 说明 |
|------|------|
| 用户创建 | 自动创建 `lumenimadmin` 应用用户（用户名/密码：lumenimadmin/wenming429） |
| 文件验证 | tar.gz 格式校验、完整性检查 |
| 自动备份 | 部署前备份到 `/var/lib/lumenim/backups/` |
| 后端部署 | 解压 + systemd 服务配置 |
| 前端部署 | 解压 + Nginx 反向代理配置 |
| 部署验证 | 端口、容器、服务状态检查 |
| 一键回滚 | 恢复上一版本 |

### 应用用户说明

脚本会自动创建并使用 `lumenimadmin` 用户运行 LumenIM 服务：

| 项目 | 值 |
|------|---|
| 用户名 | `lumenimadmin` |
| 密码 | `wenming429` |
| 用户 ID | 系统自动分配 |
| Shell | `/sbin/nologin`（禁止登录） |
| 主目录 | `/home/lumenimadmin` |

---

## 验证部署

### 检查服务状态

```bash
# 检查 Docker 容器
docker ps | grep -E "mysql|redis"

# 检查后端服务
systemctl status lumenim-backend

# 检查 Nginx
systemctl status nginx
```

### 检查端口监听

```bash
ss -tlnp | grep -E "3306|6379|8080|9501"
```

预期输出：
```
LISTEN  0  128  *:3306  *:*  users:(("docker-proxy",pid=xxx),...)
LISTEN  0  128  *:6379  *:*  users:(("docker-proxy",pid=xxx),...)
LISTEN  0  128  *:8080  *:*  users:((lumenim-backend,pid=xxx),...)
LISTEN  0  511  *:9501  *:*  users:(("nginx",pid=xxx),...)
```

### 测试访问

```bash
# 测试后端 API
curl http://127.0.0.1:8080/api/v1/health

# 测试前端
curl http://127.0.0.1:9501

# 检查日志
journalctl -u lumenim-backend -n 50 --no-pager
```

---

## 回滚操作

### 使用脚本回滚

```bash
sudo ./software/deploy-packages.sh --rollback
```

### 手动回滚

```bash
# 查看可用备份
ls -la /var/lib/lumenim/backups/

# 停止服务
systemctl stop lumenim-backend

# 恢复备份
cp -a /var/lib/lumenim/backups/backend_YYYYMMDD_HHMMSS /var/www/lumenim/backend

# 设置权限
chown -R lumenimadmin:lumenimadmin /var/www/lumenim/backend

# 重启服务
systemctl restart lumenim-backend
```

---

## 常见问题

### 1. Docker 镜像拉取超时

配置国内镜像加速器：

```bash
mkdir -p /etc/docker
cat > /etc/docker/daemon.json << EOF
{
  "registry-mirrors": [
    "https://docker.mirrors.ustc.edu.cn",
    "https://hub-mirror.c.163.com",
    "https://mirror.baidubce.com"
  ]
}
EOF

systemctl daemon-reload
systemctl restart docker
```

### 2. 端口被占用

```bash
# 查看端口占用
ss -tlnp | grep 8080

# 杀死占用进程或修改配置使用其他端口
```

### 3. 权限问题

```bash
# 修复目录权限
chown -R lumenimadmin:lumenimadmin /var/www/lumenim
chmod -R 755 /var/www/lumenim
```

### 4. 数据库连接失败

```bash
# 检查 MySQL 容器日志
docker logs lumenim-mysql

# 进入 MySQL 容器测试
docker exec -it lumenim-mysql mysql -uroot -p
```

### 5. 服务启动失败

```bash
# 查看详细日志
journalctl -u lumenim-backend -xf

# 检查配置文件
cat /var/www/lumenim/backend/.env
```

---

## 快速部署清单

### 开发环境（Windows 11）

- [ ] 检查后端 `.env` 配置文件存在
- [ ] 执行打包命令生成 `backend.tar.gz` 和 `front.tar.gz`
- [ ] 验证打包文件包含 `.env`
- [ ] 传输离线包到服务器

### 服务器环境

- [ ] 服务器环境准备（Docker、Nginx）
- [ ] 创建 `lumenimadmin` 应用用户（如使用自动化脚本可跳过）
- [ ] 创建 MySQL 和 Redis 容器
- [ ] 上传离线包到 `/mnt/packages`
- [ ] 执行部署脚本或手动部署
- [ ] 验证服务状态
- [ ] 测试访问

---

## 联系方式

如遇问题，请检查：
1. Docker 容器状态：`docker ps -a`
2. 服务日志：`journalctl -u lumenim-backend -n 100`
3. Nginx 日志：`tail -f /var/log/nginx/error.log`
