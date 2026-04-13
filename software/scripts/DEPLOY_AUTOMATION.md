# LumenIM 自动化部署文档

**文档版本**: 1.0.0
**更新日期**: 2026-04-09
**目标服务器**: CentOS 7.x (IP: 192.168.23.129)

---

## 一、部署架构概览

```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│   开发机器      │     │   目标服务器    │     │   Docker 容器   │
│  (本地构建)     │ ──> │  192.168.23.129│     │                 │
│                 │     │                 │     │ ┌─────────────┐ │
│  ┌───────────┐  │     │ ┌─────────────┐ │     │ │   MySQL    │ │
│  │ 前端构建  │  │     │ │  后端服务   │ │     │ └─────────────┘ │
│  │ (Vite)   │  │     │ │  (lumenim) │ │     │ ┌─────────────┐ │
│  └───────────┘  │     │ └─────────────┘ │     │ │   Redis    │ │
│  ┌───────────┐  │     │ ┌─────────────┐ │     │ └─────────────┘ │
│  │ 后端构建  │  │     │ │  Nginx      │ │     │ ┌─────────────┐ │
│  │ (Go)     │  │     │ │  (静态文件) │ │     │ │   MinIO    │ │
│  └───────────┘  │     │ └─────────────┘ │     │ └─────────────┘ │
└─────────────────┘     └─────────────────┘     └─────────────────┘
```

---

## 二、部署前准备

### 2.1 服务器要求

| 项目 | 要求 |
|------|------|
| 操作系统 | CentOS 7.x |
| CPU | 2 核+ |
| 内存 | 4GB+ |
| 磁盘 | 50GB+ |
| 网络 | 能访问内网 |

### 2.2 需要安装的软件

| 软件 | 版本 | 用途 |
|------|------|------|
| Docker | 24.x | 容器运行时 |
| MySQL | 8.0 | 数据库 |
| Redis | 7.x | 缓存 |
| MinIO | latest | 对象存储 |

### 2.3 防火墙配置

```bash
# 在目标服务器上执行
firewall-cmd --permanent --add-port=80/tcp
firewall-cmd --permanent --add-port=443/tcp
firewall-cmd --permanent --add-port=9501/tcp
firewall-cmd --permanent --add-port=9502/tcp
firewall-cmd --permanent --add-port=3306/tcp
firewall-cmd --permanent --add-port=6379/tcp
firewall-cmd --permanent --add-port=9000/tcp
firewall-cmd --reload
```

---

## 三、快速部署（Windows PowerShell）

### 3.1 一键发布脚本 (publish.ps1)

使用 `publish.ps1` 脚本可自动完成环境检查、构建、打包：

```powershell
cd D:\学习资料\AI_Projects\LumenIM\software\scripts

# 完整发布（检查环境 + 构建 + 打包）
.\publish.ps1

# 仅检查环境
.\publish.ps1 -CheckEnv

# 跳过构建（使用已有构建）
.\publish.ps1 -SkipBuild

# 仅构建后端
.\publish.ps1 -BackendOnly

# 仅构建前端
.\publish.ps1 -FrontendOnly

# 指定输出目录
.\publish.ps1 -OutputDir "D:\release\lumenim"
```

### 3.2 环境检查

脚本会自动检查以下工具：

| 工具 | 最低版本 | 用途 |
|------|---------|------|
| Docker | - | 容器运行时 |
| Go | 1.21 | 后端编译 |
| Node.js | 18 | 前端依赖 |
| pnpm | 8 | 包管理 |
| Git | - | 版本控制 |

如缺失，脚本会显示安装提示。

### 3.3 脚本输出

脚本执行后会生成：

```
D:\temp\lumenim-release\
├── backend/           # 后端部署文件
├── frontend/          # 前端部署文件
├── tarballs/
│   ├── backend.tar.gz # 后端压缩包
│   └── frontend.tar.gz # 前端压缩包
└── README.md          # 部署说明
```

### 3.4 部署到服务器

将 `tarballs` 目录下的压缩包上传到服务器：

```powershell
# 使用 pscp 上传
pscp D:\temp\lumenim-release\tarballs\backend.tar.gz root@192.168.23.129:/mnt/packages/
pscp D:\temp\lumenim-release\tarballs\frontend.tar.gz root@192.168.23.129:/mnt/packages/
```

然后在服务器执行：

```bash
sudo ./software/deploy-packages.sh
```

---

## 四、手动部署步骤

### 4.1 服务器端环境准备

#### 4.1.1 创建应用用户

```bash
# 创建 lumenimadmin 用户
useradd -r -s /sbin/nologin lumenimadmin 2>/dev/null || true
echo "lumenimadmin:wenming429" | chpasswd
id lumenimadmin
```

#### 4.1.2 创建必要目录

```bash
mkdir -p /var/www/lumenim/{backend,front}
mkdir -p /var/lib/lumenim/{mysql,redis,backups}
mkdir -p /mnt/packages
chown -R lumenimadmin:lumenimadmin /var/www/lumenim
chown -R lumenimadmin:lumenimadmin /var/lib/lumenim
```

#### 4.1.3 创建 Docker 容器

```bash
# MySQL 容器
docker run -d --name lumenim-mysql \
    -p 3306:3306 \
    -e MYSQL_ROOT_PASSWORD=wenming429 \
    -e MYSQL_DATABASE=go_chat \
    -v /var/lib/lumenim/mysql:/var/lib/mysql \
    --restart=always mysql:8.0.35 \
    --character-set-server=utf8mb4

# Redis 容器
docker run -d --name lumenim-redis \
    -p 6379:6379 \
    -v /var/lib/lumenim/redis:/data \
    --restart=always redis:7.4.1 redis-server --appendonly yes

docker ps
```

#### 4.1.4 安装配置 Nginx

```bash
yum install -y nginx
systemctl start nginx && systemctl enable nginx
```

### 4.2 本地构建

#### Windows PowerShell

```powershell
cd D:\学习资料\AI_Projects\LumenIM

# 后端
cd backend
go build -ldflags="-s -w" -o lumenim.exe ./cmd/server

# 前端
cd ..\front
pnpm install && pnpm run build

# 打包
$pkgDir = "D:\temp\lumenim-packages"
New-Item -ItemType Directory -Force -Path $pkgDir | Out-Null
tar -czvf "$pkgDir\backend.tar.gz" -C backend .
tar -czvf "$pkgDir\front.tar.gz" -C front .
```

#### Linux/macOS

```bash
cd /path/to/LumenIM

# 后端交叉编译
cd backend
CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -ldflags="-s -w" -o lumenim-backend ./cmd/server

# 前端
cd ../front
pnpm install && pnpm run build

# 打包
mkdir -p /tmp/lumenim-packages
tar -czvf /tmp/lumenim-packages/backend.tar.gz -C backend .
tar -czvf /tmp/lumenim-packages/front.tar.gz -C front .
```

### 4.3 传输文件到服务器

```bash
# Linux/macOS
scp /tmp/lumenim-packages/*.tar.gz root@192.168.23.129:/mnt/packages/

# Windows PowerShell
pscp D:\temp\lumenim-packages\backend.tar.gz root@192.168.23.129:/mnt/packages/
pscp D:\temp\lumenim-packages\front.tar.gz root@192.168.23.129:/mnt/packages/
```

### 4.4 服务器端部署后端

```bash
cd /mnt/packages

# 解压后端
mkdir -p /var/www/lumenim/backend
tar -xzvf backend.tar.gz -C /var/www/lumenim/backend/
chown -R lumenimadmin:lumenimadmin /var/www/lumenim/backend

# 配置 .env
cd /var/www/lumenim/backend
[ -f .env ] || cp .env.example .env
vi .env
```

**`.env` 必需配置项**:

```env
DB_HOST=127.0.0.1
DB_PORT=3306
DB_USER=root
DB_PASSWORD=wenming429
DB_NAME=go_chat
REDIS_HOST=127.0.0.1
REDIS_PORT=6379
HTTP_PORT=8080
```

### 4.5 创建 systemd 服务

```bash
cat > /etc/systemd/system/lumenim-backend.service << 'EOF'
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
EOF

systemctl daemon-reload
systemctl enable lumenim-backend
systemctl start lumenim-backend
systemctl status lumenim-backend
```

### 4.6 服务器端部署前端

```bash
cd /mnt/packages
mkdir -p /var/www/lumenim/front
tar -xzvf front.tar.gz -C /var/www/lumenim/front/
chown -R lumenimadmin:lumenimadmin /var/www/lumenim/front
```

### 4.7 配置 Nginx

```bash
cat > /etc/nginx/conf.d/lumenim.conf << 'EOF'
server {
    listen 9501;
    server_name _;
    root /var/www/lumenim/front/dist;
    index index.html;

    location / {
        try_files $uri $uri/ /index.html;
    }

    location /api/ {
        proxy_pass http://127.0.0.1:8080/api/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }

    location /ws {
        proxy_pass http://127.0.0.1:8080/ws;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
    }

    location ~* \.(js|css|png|jpg|gif|ico|svg|woff)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
    }
}
EOF

nginx -t && systemctl reload nginx
```

### 4.8 初始化数据库

```bash
sleep 10
docker exec -i lumenim-mysql mysql -uroot -pwenming429 go_chat < /var/www/lumenim/backend/sql/*.sql
```

### 4.9 部署验证

```bash
# 服务状态
systemctl status lumenim-backend
docker ps

# 端口检查
ss -tlnp | grep -E "3306|6379|8080|9501"

# API 测试
curl http://127.0.0.1:8080/api/v1/health

# 前端测试
curl http://127.0.0.1:9501

# 日志查看
journalctl -u lumenim-backend -n 50 --no-pager
```

### 4.10 手动部署检查清单

| 步骤 | 操作 | 验证命令 |
|------|------|----------|
| 1 | 创建应用用户 | `id lumenimadmin` |
| 2 | 创建 Docker 容器 | `docker ps | grep mysql` |
| 3 | 部署后端文件 | `ls /var/www/lumenim/backend/lumenim-backend` |
| 4 | 配置 .env | `grep DB_HOST /var/www/lumenim/backend/.env` |
| 5 | 创建 systemd 服务 | `systemctl status lumenim-backend` |
| 6 | 部署前端文件 | `ls /var/www/lumenim/front/dist` |
| 7 | 配置 Nginx | `nginx -t` |
| 8 | 初始化数据库 | `docker exec lumenim-mysql mysql -uroot -pwenming429 -e "SHOW DATABASES;"` |
| 9 | 验证服务 | `curl http://localhost:9501` |

---

## 五、自动化部署脚本详解

### 5.1 脚本功能

| 步骤 | 功能 | 说明 |
|------|------|------|
| 1 | 环境检查 | 检查 Go、Node.js、pnpm 等工具 |
| 2 | 清理旧构建 | 清理临时文件和旧构建 |
| 3 | 构建后端 | 交叉编译 Linux amd64 二进制 |
| 4 | 构建前端 | 使用 Vite 构建生产版本 |
| 5 | 打包部署文件 | 打包所有部署文件 |
| 6 | 传输到服务器 | 使用 scp 传输文件 |
| 7 | 远程部署 | 自动配置和启动服务 |
| 8 | 健康检查 | 检查所有服务状态 |

### 5.2 配置参数

编辑脚本开头的配置区域：

```bash
# 部署配置
DEPLOY_HOST="192.168.23.129"    # 目标服务器 IP
DEPLOY_USER="root"              # SSH 用户名
DEPLOY_PASSWORD="123456"        # SSH 密码
REMOTE_DEPLOY_DIR="/opt/lumenim" # 远程部署目录
```

### 5.3 使用 ssh-key 免密登录

如果不想使用密码，可以在部署前配置 SSH 密钥：

```bash
# 本地生成密钥
ssh-keygen -t rsa -b 4096 -C "deploy@local"

# 复制公钥到服务器
ssh-copy-id root@192.168.23.129

# 修改脚本，注释掉 sshpass 相关命令
```

---

## 六、服务管理

### 6.1 登录服务器

```bash
ssh root@192.168.23.129
```

### 6.2 服务状态检查

```bash
# Docker 容器
docker ps
docker ps -a

# 后端服务
systemctl status lumenim-backend

# 端口监听
ss -tlnp | grep -E "9501|3306|6379"
```

### 6.3 服务启停

```bash
# 后端服务
systemctl start lumenim-backend
systemctl stop lumenim-backend
systemctl restart lumenim-backend

# Docker 容器
docker start lumenim-mysql
docker start lumenim-redis
docker restart lumenim-mysql
docker restart lumenim-redis
```

### 6.4 日志查看

```bash
# 后端日志
journalctl -u lumenim-backend -f
journalctl -u lumenim-backend -n 100

# Docker 日志
docker logs -f lumenim-mysql
docker logs -f lumenim-redis
```

---

## 七、健康检查

### 7.1 API 健康检查

```bash
curl http://localhost:9501/api/v1/health
```

### 7.2 数据库连接测试

```bash
docker exec lumenim-mysql mysql -u root -pwenming429 -e "SELECT 1;"
```

### 7.3 Redis 连接测试

```bash
docker exec lumenim-redis redis-cli ping
```

---

## 八、CentOS 7 EOL 问题说明

### 8.1 问题背景

**重要提醒**：CentOS 7 已于 **2024 年 6 月 30 日** 正式结束生命周期（EOL）。

这意味着：
- 官方软件源（`mirrorlist.centos.org`）已停止服务
- 运行 `yum update` 或 `yum install` 会报 **无法解析主机** 或 **curl#6** 错误
- 原有脚本需要修改镜像源配置才能正常工作

### 8.2 脚本自动修复

`install-centos7.sh` 脚本已内置自动修复功能：

| 修复项 | 说明 |
|--------|------|
| **Base 源** | 替换为阿里云 Vault 归档源 |
| **EPEL 源** | 替换为腾讯云 EPEL Vault 源 |
| **Docker 源** | 优先使用官方源，失败时切换阿里云镜像 |

### 8.3 可用镜像源列表

如果脚本自动修复失败，可手动替换：

```bash
# 1. 备份原有配置
sudo cp /etc/yum.repos.d/CentOS-Base.repo /etc/yum.repos.d/CentOS-Base.repo.bak

# 2. 备份并删除原有的 CentOS-Base.repo（避免重复配置问题）
sudo cp /etc/yum.repos.d/CentOS-Base.repo /etc/yum.repos.d/CentOS-Base.repo.bak
sudo mv /etc/yum.repos.d/CentOS-Base.repo /etc/yum.repos.d/CentOS-Base.repo.disabled

# 3. 创建新的 Vault 源配置（使用唯一的段落名避免冲突）
sudo cat > /etc/yum.repos.d/CentOS-Vault.repo << 'EOF'
[vault-base]
name=CentOS-7 - Base - Vault
baseurl=https://mirrors.aliyun.com/centos-vault/7.9.2009/os/x86_64/
gpgcheck=1
gpgkey=https://mirrors.aliyun.com/centos/RPM-GPG-KEY-CentOS-7
enabled=1

[vault-extras]
name=CentOS-7 - Extras - Vault
baseurl=https://mirrors.aliyun.com/centos-vault/7.9.2009/extras/x86_64/
gpgcheck=1
gpgkey=https://mirrors.aliyun.com/centos/RPM-GPG-KEY-CentOS-7
enabled=1

[vault-updates]
name=CentOS-7 - Updates - Vault
baseurl=https://mirrors.aliyun.com/centos-vault/7.9.2009/updates/x86_64/
gpgcheck=1
gpgkey=https://mirrors.aliyun.com/centos/RPM-GPG-KEY-CentOS-7
enabled=1
EOF

# 3. 添加 EPEL Vault 源
sudo cat > /etc/yum.repos.d/epel-vault.repo << 'EOF'
[epel-vault]
name=Extra Packages for Enterprise Linux 7 - x86_64
baseurl=https://mirrors.cloud.tencent.com/epel/7/x86_64/
gpgcheck=0
enabled=1
EOF

# 4. 禁用原有失效源
sudo sed -i 's/enabled=1/enabled=0/' /etc/yum.repos.d/CentOS-Base.repo

# 5. 清理并重建缓存
sudo yum clean all
sudo yum makecache
```

### 8.4 备用镜像源

如需更换镜像源，可使用以下任一选项：

| 镜像站 | Base URL | EPEL URL |
|--------|----------|----------|
| 阿里云 | `https://mirrors.aliyun.com/centos-vault/` | `https://mirrors.aliyun.com/epel/` |
| 清华 TUNA | `https://mirrors.tuna.tsinghua.edu.cn/centos-vault/` | `https://mirrors.tuna.tsinghua.edu.cn/epel/` |
| 网易 | `https://mirrors.163.com/centos-vault/` | `https://mirrors.163.com/epel/` |
| 中科大 | `https://mirrors.ustc.edu.cn/centos-vault/` | `https://mirrors.ustc.edu.cn/epel/` |
| 腾讯云 | - | `https://mirrors.cloud.tencent.com/epel/` |

### 8.5 长期建议

如果可能，建议升级到仍在支持的 Linux 发行版：

| 发行版 | 支持期限 | 优点 |
|--------|----------|------|
| **Rocky Linux 9** | 2032 年 | 与 RHEL 完全兼容 |
| **AlmaLinux 9** | 2032 年 | 与 RHEL 完全兼容 |
| **Ubuntu 22.04 LTS** | 2027 年 | 社区活跃 |

---

## 九、常见问题

### 9.1 SSH 连接失败

### 9.1 SSH 连接失败

```bash
# 检查 SSH 服务
systemctl status sshd

# 启动 SSH
systemctl start sshd
systemctl enable sshd
```

### 9.2 Docker 无法启动

```bash
# 检查 Docker 状态
systemctl status docker

# 启动 Docker
systemctl start docker
systemctl enable docker
```

### 9.3 端口被占用

```bash
# 查看端口占用
ss -tlnp | grep 9501

# 杀死占用进程
kill -9 <PID>
```

---

## 十、快速命令参考

```bash
# 完整部署
./deploy.sh

# 只构建不上传
./deploy.sh --build-only

# 查看服务状态
ssh root@192.168.23.129 "docker ps && systemctl status lumenim-backend"

# 重启所有服务
ssh root@192.168.23.129 "systemctl restart lumenim-backend && docker restart lumenim-mysql lumenim-redis"
```

---

**文档结束**
