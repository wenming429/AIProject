# LumenIM Ubuntu 20.04 自动化部署指南

**文档版本**: 2.1.0
**更新日期**: 2026-04-10
**目标服务器**: Ubuntu 20.04 (IP: 192.168.23.131, 用户: wenming429)

---

## 一、部署架构

```
┌─────────────────────┐      ┌─────────────────────┐      ┌─────────────────────┐
│   开发机器 (本地)    │      │   目标服务器         │      │   Docker 容器        │
│  (Windows/Mac/Linux)│ ──>  │  192.168.23.131     │      │                     │
│                     │      │  (wenming429)       │      │  ┌───────────────┐  │
│  ┌───────────────┐  │      │  ┌───────────────┐  │      │  │    MySQL     │  │
│  │  前端构建      │  │      │  │   Nginx       │  │      │  └───────────────┘  │
│  │  (pnpm build) │  │      │  │  (反向代理)    │  │      │  ┌───────────────┐  │
│  └───────────────┘  │      │  └───────────────┘  │      │  │    Redis     │  │
│  ┌───────────────┐  │      │  ┌───────────────┐  │      │  └───────────────┘  │
│  │  后端编译      │  │      │  │   LumenIM    │  │      │  ┌───────────────┐  │
│  │  (Linux amd64)│  │      │  │  (Go 服务)   │  │      │  │    MinIO     │  │
│  └───────────────┘  │      │  └───────────────┘  │      │  └───────────────┘  │
└─────────────────────┘      └─────────────────────┘      └─────────────────────┘
```

---

## 二、快速开始

### 2.1 本地构建打包 (Windows PowerShell)

```powershell
cd D:\学习资料\AI_Projects\LumenIM\software\scripts\deploy-package
.\deploy-ubuntu.ps1
```

### 2.2 本地构建打包 (Linux/Mac)

```bash
cd software/scripts/deploy-package
bash deploy-ubuntu.sh
```

### 2.3 一键远程部署

**方式一：使用增强版远程部署脚本（推荐）**

```powershell
# 密码认证
& "D:\学习资料\AI_Projects\LumenIM\software\scripts\deploy-remote-v2.ps1" `
    -Host "192.168.23.131" `
    -Username "wenming429" `
    -Password "your_password"

# SSH 密钥认证（更稳定）
& "D:\学习资料\AI_Projects\LumenIM\software\scripts\deploy-remote-v2.ps1" `
    -Host "192.168.23.131" `
    -Username "wenming429" `
    -KeyPath "C:\Users\YourUser\.ssh\id_rsa"
```

**方式二：使用内嵌远程部署**

```powershell
cd software/scripts/deploy-package
.\deploy-ubuntu.ps1 -RemoteDeploy -ServerHost 192.168.23.131 -ServerUser wenming429 -Password "your_password"
```

### 2.4 手动部署到服务器

```bash
# 1. 上传包 (使用 ZIP 格式)
scp D:\学习资料\AI_Projects\LumenIM\software\scripts\deploy-package\output\lumenim-*.zip wenming429@192.168.23.131:/tmp/

# 2. SSH 登录并部署
ssh wenming429@192.168.23.131
cd /tmp
unzip -o lumenim-*.zip
mv deploy /opt/lumenim
cd /opt/lumenim
sudo bash deploy.sh
```

---

## 三、服务器环境准备

### 3.1 初始服务器配置

在目标服务器上执行以下命令：

```bash
# ===== 更新系统 =====
sudo apt update && sudo apt upgrade -y

# ===== 创建应用用户 =====
sudo useradd -r -s /bin/bash lumenim 2>/dev/null || true
sudo mkdir -p /home/lumenim
sudo chown -R lumenim:lumenim /home/lumenim

# ===== 安装基础软件 =====
sudo apt install -y curl wget git vim net-tools unzip

# ===== 安装 MySQL =====
sudo apt install -y mysql-server
sudo systemctl enable mysql
sudo systemctl start mysql

# ===== 安装 Redis =====
sudo apt install -y redis-server
sudo systemctl enable redis-server
sudo systemctl start redis-server

# ===== 安装 Nginx =====
sudo apt install -y nginx
sudo systemctl enable nginx
sudo systemctl start nginx

# ===== 配置防火墙 =====
sudo ufw allow 22/tcp
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw enable
```

### 3.2 配置 MySQL

```bash
# 设置 MySQL root 密码
sudo mysql_secure_installation

# 创建数据库和用户
sudo mysql -u root -p << 'EOF'
CREATE DATABASE go_chat CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER 'lumenim'@'localhost' IDENTIFIED BY 'YourStrongPassword123';
GRANT ALL PRIVILEGES ON go_chat.* TO 'lumenim'@'localhost';
FLUSH PRIVILEGES;
EOF

# 导入数据库脚本 (部署时执行)
# mysql -u lumenim -p go_chat < /opt/lumenim/backend/sql/lumenim.sql
```

### 3.3 配置 Redis

```bash
# 配置 Redis 密码
sudo vim /etc/redis/redis.conf
# 添加: requirepass YourRedisPassword123

sudo systemctl restart redis-server
```

### 3.4 确保 SSH 允许密码认证

```bash
# 检查 SSH 配置
sudo grep "PasswordAuthentication" /etc/ssh/sshd_config

# 如果显示 PasswordAuthentication no，需要改为 yes
sudo sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config

# 重启 SSH 服务
sudo systemctl restart sshd
```

---

## 四、打包脚本详解

### 4.1 脚本文件

| 脚本 | 功能 | 平台 |
|------|------|------|
| `deploy-ubuntu.ps1` | 本地构建打包脚本 | Windows PowerShell |
| `deploy-ubuntu.sh` | 本地构建打包脚本 | Linux/Mac |
| `deploy-remote-v2.ps1` | 增强版远程部署脚本 | Windows PowerShell |

### 4.2 打包流程

| 步骤 | 功能 | 说明 |
|------|------|------|
| 1 | 环境检查 | 检查 Go、Node.js、pnpm、sshpass 等工具 |
| 2 | 前端构建 | 执行 pnpm build 生成生产版本 |
| 3 | 后端编译 | 交叉编译 Linux amd64 二进制文件 |
| 4 | 生成配置 | 自动生成所有配置文件模板 |
| 5 | 打包发布 | 生成 ZIP 压缩包（支持中文路径） |
| 6 | 远程部署 | 可选：SSH 自动部署到服务器 |

### 4.3 配置参数

编辑 `deploy-ubuntu.ps1` 开头的配置区域：

```powershell
$DeployConfig = @{
    # 远程服务器配置
    ServerHost = "192.168.23.131"
    ServerUser = "wenming429"
    Password = ""  # 如为空则使用 SSH 密钥
    RemoteDir = "/opt/lumenim"
    
    # 服务端口
    HttpPort = 9501
    WebSocketPort = 9502
    
    # 数据库配置
    MySQLHost = "127.0.0.1"
    MySQLPort = 3306
    MySQLUser = "root"
    MySQLPassword = "wenming429"
    MySQLDatabase = "go_chat"
    
    # Redis 配置
    RedisHost = "127.0.0.1"
    RedisPort = 6379
    RedisPassword = ""
}
```

### 4.4 使用 SSH 密钥免密登录

```bash
# 本地生成密钥 (Windows PowerShell)
ssh-keygen -t rsa -b 4096 -C "deploy@lumenim"

# 复制公钥到服务器
ssh-copy-id wenming429@192.168.23.131

# 或手动复制
cat ~/.ssh/id_rsa.pub | ssh wenming429@192.168.23.131 "mkdir -p ~/.ssh && cat >> ~/.ssh/authorized_keys"
```

---

## 五、增强版远程部署脚本

### 5.1 功能特性

`deploy-remote-v2.ps1` 是增强版远程部署脚本，解决了以下问题：

- **SCP 权限问题**：使用环境变量方式传递密码，避免命令行特殊字符问题
- **SSH 密钥支持**：支持密钥认证，避免密码认证的不稳定性
- **详细诊断**：自动诊断连接问题并提供解决方案
- **备份机制**：部署前自动备份旧版本

### 5.2 使用方法

```powershell
# 参数说明
-Host           # 目标服务器 IP
-Username       # SSH 用户名
-Password       # SSH 密码（可选）
-KeyPath        # SSH 私钥路径（可选，推荐）
-RemotePath     # 远程部署目录（默认 /opt/lumenim）

# 示例 1: 密码认证
& "D:\学习资料\AI_Projects\LumenIM\software\scripts\deploy-remote-v2.ps1" `
    -Host "192.168.23.131" `
    -Username "wenming429" `
    -Password "your_password"

# 示例 2: SSH 密钥认证（推荐）
& "D:\学习资料\AI_Projects\LumenIM\software\scripts\deploy-remote-v2.ps1" `
    -Host "192.168.23.131" `
    -Username "wenming429" `
    -KeyPath "$env:USERPROFILE\.ssh\id_rsa"
```

### 5.3 部署流程

```
Step 1: 检查本地依赖 (ssh, scp, sshpass)
Step 2: 测试 SSH 连接
Step 3: 查找部署包
Step 4: 创建远程目录
Step 5: 备份旧版本
Step 6: 传输部署包
Step 7: 解压并部署
Step 8: 配置 systemd 服务
Step 9: 启动服务
```

---

## 六、部署包目录结构

```
lumenim-ubuntu-TIMESTAMP/
│
├── front/                              # 前端部署
│   ├── dist/                          # 前端构建产物
│   │   ├── index.html
│   │   ├── embed.html
│   │   └── assets/
│   ├── src/                           # 源码备份
│   ├── public/                        # 公共资源
│   └── config/
│       └── nginx.conf                 # Nginx 配置
│
├── backend/                             # 后端部署
│   ├── lumenim                        # Go 可执行文件 (Linux amd64)
│   ├── lumenim.exe                    # Windows 可执行文件 (备份)
│   ├── sql/
│   │   └── lumenim.sql              # 数据库初始化脚本
│   ├── uploads/                       # 上传目录
│   │   ├── images/
│   │   ├── files/
│   │   ├── avatars/
│   │   ├── audio/
│   │   └── video/
│   ├── runtime/                       # 运行时目录
│   │   ├── logs/
│   │   ├── cache/
│   │   └── temp/
│   └── config/
│       ├── config.yaml               # 主配置文件
│       ├── lumenim-http.service     # HTTP 服务
│       ├── lumenim-comet.service    # WebSocket 服务
│       ├── lumenim-queue.service    # 队列服务
│       ├── lumenim-crontab.service  # 定时任务服务
│       ├── start.sh                  # 启动脚本
│       └── stop.sh                   # 停止脚本
│
├── scripts/
│   ├── deploy.sh                    # 服务器部署脚本
│   └── init-db.sh                   # 数据库初始化脚本
│
└── README.md                         # 部署说明
```

---

## 七、服务配置详解

### 7.1 后端服务 (systemd)

#### lumenim-http.service

```ini
[Unit]
Description=LumenIM HTTP API Service
Documentation=https://github.com/gzydong/LumenIM
After=network.target mysql.service redis.service
Wants=mysql.service redis.service

[Service]
Type=simple
User=lumenim
Group=lumenim
WorkingDirectory=/opt/lumenim/backend
ExecStart=/opt/lumenim/backend/lumenim http --config=/opt/lumenim/backend/config/config.yaml
Restart=always
RestartSec=5
StandardOutput=journal
StandardError=journal
SyslogIdentifier=lumenim-http

# Security
NoNewPrivileges=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=/opt/lumenim/backend/runtime /opt/lumenim/backend/uploads

[Install]
WantedBy=multi-user.target
```

#### lumenim-comet.service (WebSocket)

```ini
[Unit]
Description=LumenIM WebSocket Service
After=network.target mysql.service redis.service
Wants=mysql.service redis.service

[Service]
Type=simple
User=lumenim
Group=lumenim
WorkingDirectory=/opt/lumenim/backend
ExecStart=/opt/lumenim/backend/lumenim comet --config=/opt/lumenim/backend/config/config.yaml
Restart=always
RestartSec=5
StandardOutput=journal
StandardError=journal
SyslogIdentifier=lumenim-comet

NoNewPrivileges=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=/opt/lumenim/backend/runtime /opt/lumenim/backend/uploads

[Install]
WantedBy=multi-user.target
```

### 7.2 启动脚本

#### start.sh

```bash
#!/bin/bash
# LumenIM Backend Start Script

APP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$APP_DIR"

CONFIG_FILE="${CONFIG_FILE:-config.yaml}"

echo "Starting LumenIM Backend Services..."
echo "Config: $CONFIG_FILE"
echo ""

# Start services in background
./lumenim http --config="$CONFIG_FILE" &
HTTP_PID=$!
echo "HTTP API started (PID: $HTTP_PID)"

./lumenim comet --config="$CONFIG_FILE" &
COMET_PID=$!
echo "WebSocket started (PID: $COMET_PID)"

./lumenim queue --config="$CONFIG_FILE" &
QUEUE_PID=$!
echo "Queue worker started (PID: $QUEUE_PID)"

./lumenim crontab --config="$CONFIG_FILE" &
CRON_PID=$!
echo "Crontab service started (PID: $CRON_PID)"

echo ""
echo "All services started!"
echo "HTTP API:  http://0.0.0.0:9501"
echo "WebSocket: ws://0.0.0.0:9502"
echo ""
echo "To stop: pkill -f lumenim"
```

#### stop.sh

```bash
#!/bin/bash
# LumenIM Backend Stop Script

echo "Stopping LumenIM Backend Services..."
pkill -f "lumenim http" || true
pkill -f "lumenim comet" || true
pkill -f "lumenim queue" || true
pkill -f "lumenim crontab" || true
echo "All services stopped!"
```

### 7.3 Nginx 配置

```nginx
# /etc/nginx/sites-available/lumenim
server {
    listen 80;
    server_name _;

    # Root directory
    root /var/www/lumenim;
    index index.html;

    # ========== Frontend Routes (SPA) ==========
    location / {
        try_files $uri $uri/ /index.html;
    }

    # ========== API Proxy ==========
    location /api {
        proxy_pass http://127.0.0.1:9501;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        
        # Timeouts
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }

    # ========== WebSocket Proxy ==========
    location /ws {
        proxy_pass http://127.0.0.1:9502;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        
        # WebSocket timeouts
        proxy_read_timeout 86400s;
        proxy_send_timeout 86400s;
    }

    # ========== Static Resources Cache ==========
    location ~* \.(gif|jpg|jpeg|png|bmp|swf|flv|ico)$ {
        expires 7d;
        access_log off;
        add_header Cache-Control "public, immutable";
    }

    location ~* \.(js|css|less|scss|sass)$ {
        expires 7d;
        access_log off;
        add_header Cache-Control "public, immutable";
    }

    location ~* \.(woff|woff2|ttf|eot|svg|otf)$ {
        expires 30d;
        access_log off;
        add_header Cache-Control "public";
    }

    # ========== Health Check ==========
    location /health {
        access_log off;
        return 200 "OK";
        add_header Content-Type text/plain;
    }

    # ========== Security Headers ==========
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
}
```

---

## 八、环境变量配置

### 8.1 后端配置 (config.yaml)

```yaml
# ==================== Application Config ====================
app:
  env: prod                           # dev/test/prod
  debug: false                         # Debug mode
  admin_email:
    - admin@yourcompany.com
  public_key: |                        # RSA Public Key
    -----BEGIN PUBLIC KEY-----
    MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA...
    -----END PUBLIC KEY-----
  private_key: |                       # RSA Private Key
    -----BEGIN PRIVATE KEY-----
    MIIEvQIBADANBgkqhkiG9w0BAQEFAASCBKcwggSj...
    -----END PRIVATE KEY-----
  aes_key: "32-char-random-string-for-aes-encryption"

# ==================== Server Ports ====================
server:
  http_addr: ":9501"                   # HTTP API port
  websocket_addr: ":9502"              # WebSocket port
  tcp_addr: ":9505"                    # TCP port (reserved)

# ==================== Log Config ====================
log:
  path: "./runtime/logs"
  level: "info"
  max_size: 100
  max_backups: 30
  max_age: 7

# ==================== Redis Config ====================
redis:
  host: 127.0.0.1
  port: 6379
  auth: "your_redis_password"
  database: 0
  pool_size: 100

# ==================== MySQL Config ====================
mysql:
  host: 127.0.0.1
  port: 3306
  username: root
  password: "your_mysql_password"
  database: go_chat
  charset: utf8mb4
  max_open_conns: 100
  max_idle_conns: 10

# ==================== JWT Config ====================
jwt:
  secret: "your_jwt_secret_key_32chars"
  expires_time: 86400
  buffer_time: 86400

# ==================== CORS Config ====================
cors:
  origin: "https://your-domain.com"
  headers: "Content-Type,Cache-Control,User-Agent,AccessToken,Authorization"
  methods: "OPTIONS,GET,POST,PUT,DELETE"
  credentials: true
  max_age: 600

# ==================== File Storage Config ====================
filesystem:
  default: local                       # local/minio
  local:
    root: "./uploads"
    bucket_public: "public"
    bucket_private: "private"
  minio:
    secret_id: "minioadmin"
    secret_key: "your_minio_password"
    bucket_public: "im-static"
    bucket_private: "im-private"
    endpoint: "127.0.0.1:9000"
    ssl: false

# ==================== Email Config (Optional) ====================
email:
  host: smtp.ym.163.com
  port: 465
  username: noreply@yourcompany.com
  password: "smtp_password"
  fromname: "LumenIM"
```

### 8.2 前端环境变量 (.env.production)

```bash
# ==================== Application Config ====================
ENV='production'
VITE_APP_NAME=LumenIM
VITE_APP_ENV=production

# ==================== Router Config ====================
VITE_BASE=/
VITE_ROUTER_MODE=history

# ==================== API Config ====================
# Modify to your server address
VITE_BASE_API=https://your-domain.com/api
VITE_SOCKET_API=wss://your-domain.com/ws

# ==================== Security Config ====================
VITE_RSA_PUBLIC_KEY="-----BEGIN PUBLIC KEY-----
MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA...
-----END PUBLIC KEY-----"
```

---

## 九、服务管理命令

### 9.1 基础管理

```bash
# 启动所有服务
sudo systemctl start lumenim-http lumenim-comet lumenim-queue lumenim-crontab

# 停止所有服务
sudo systemctl stop lumenim-http lumenim-comet lumenim-queue lumenim-crontab

# 重启服务
sudo systemctl restart lumenim-http

# 查看状态
sudo systemctl status lumenim-http

# 设置开机启动
sudo systemctl enable lumenim-http lumenim-comet lumenim-queue lumenim-crontab
```

### 9.2 日志查看

```bash
# 实时查看日志
sudo journalctl -u lumenim-http -f
sudo journalctl -u lumenim-comet -f

# 查看最近 100 行
sudo journalctl -u lumenim-http -n 100

# 按时间过滤
sudo journalctl -u lumenim-http --since "1 hour ago"
```

### 9.3 健康检查

```bash
# API 健康检查
curl http://localhost:9501/health
curl http://localhost:9501/api/v1/health

# Nginx 健康检查
curl http://localhost/health

# 数据库连接
mysql -u root -p -e "SELECT 1;"

# Redis 连接
redis-cli ping
redis-cli -a YourRedisPassword ping
```

---

## 十、故障排除

### 10.1 SCP/Permission Denied 问题

**问题**: 使用 `scp` 传输文件时报 "Permission denied" 错误

**可能原因**:

| 原因 | 检查方法 | 解决方案 |
|------|----------|----------|
| 密码错误 | - | 确认用户名和密码正确 |
| SSH 配置禁用密码认证 | `grep PasswordAuthentication /etc/ssh/sshd_config` | 修改为 `PasswordAuthentication yes` |
| 密码包含特殊字符 | - | 使用 `sshpass -e` 环境变量方式 |
| 目录权限不足 | `ls -la /opt/` | 确保目标目录存在且有写权限 |
| sshpass 未安装 | `which sshpass` | 安装 sshpass |

**解决方案**:

1. 使用增强版部署脚本 `deploy-remote-v2.ps1`
2. 使用 SSH 密钥认证代替密码认证
3. 服务器端检查 `/etc/ssh/sshd_config`:
   ```bash
   sudo sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config
   sudo systemctl restart sshd
   ```

### 10.2 常见问题

| 问题 | 可能原因 | 解决方案 |
|------|----------|----------|
| 服务启动失败 | 端口被占用 | `netstat -tlnp \| grep 9501` |
| 数据库连接失败 | MySQL 未启动 | `systemctl start mysql` |
| Redis 连接失败 | Redis 未启动/密码错误 | `systemctl start redis-server` |
| 前端无法访问 | Nginx 未启动 | `systemctl start nginx` |
| API 请求超时 | 防火墙阻止 | `ufw allow 9501/tcp` |
| WebSocket 断开 | 代理超时 | 增加 nginx proxy_read_timeout |

### 10.3 诊断命令

```bash
# 检查所有服务状态
systemctl status mysql redis nginx lumenim-http

# 检查端口监听
netstat -tlnp | grep -E "3306|6379|80|9501|9502"

# 检查进程
ps aux | grep lumenim

# 检查日志
sudo journalctl -xe --no-pager

# 检查防火墙
sudo ufw status verbose

# 检查资源使用
free -h
df -h
top

# 测试 SSH 连接（本地）
ssh -v wenming429@192.168.23.131
```

---

## 十一、维护命令

```bash
# ===== 备份 =====
# 备份数据库
mysqldump -u root -p go_chat > backup_$(date +%Y%m%d).sql

# 备份上传文件
zip -r uploads_backup_$(date +%Y%m%d).zip /opt/lumenim/backend/uploads

# 备份完整部署
zip -r lumenim_backup_$(date +%Y%m%d).zip /opt/lumenim

# ===== 清理 =====
# 清理日志
sudo rm -rf /opt/lumenim/backend/runtime/logs/*
sudo journalctl --vacuum-time=7d

# 清理缓存
sudo rm -rf /opt/lumenim/backend/runtime/cache/*

# ===== 更新 =====
# 1. 本地重新打包
# 2. 上传到服务器
# 3. 执行更新
sudo systemctl stop lumenim-http lumenim-comet
unzip -o new-package.zip -d /opt/
sudo systemctl start lumenim-http lumenim-comet
```

---

## 十二、安全建议

1. **修改默认密码**：MySQL、Redis、应用密码
2. **配置防火墙**：仅开放 80、443 端口
3. **使用 HTTPS**：配置 SSL 证书
4. **限制权限**：敏感配置文件使用 `chmod 600`
5. **定期更新**：保持系统和依赖更新
6. **禁用 root SSH**：使用 sudo 或普通用户登录
7. **配置 fail2ban**：防止暴力破解
8. **使用 SSH 密钥**：避免密码认证的安全风险

---

## 附录：脚本文件清单

| 文件路径 | 说明 |
|----------|------|
| `software/scripts/deploy-package/deploy-ubuntu.ps1` | 本地打包脚本 (Windows) |
| `software/scripts/deploy-package/deploy-ubuntu.sh` | 本地打包脚本 (Linux) |
| `software/scripts/deploy-remote.ps1` | 远程部署脚本 (基础版) |
| `software/scripts/deploy-remote-v2.ps1` | 远程部署脚本 (增强版) |

---

*文档更新时间: 2026-04-10*
*版本: 2.1.0*
