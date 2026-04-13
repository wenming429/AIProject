# LumenIM CentOS 7 离线部署指南

**文档版本**: 1.1.0  
**更新日期**: 2026-04-08  
**适用系统**: CentOS 7.x (离线环境)

---

## 一、概述

本文档提供在无法访问外网的 CentOS 7 服务器环境下，部署 LumenIM 系统的完整离线部署方案。

### 1.1 离线部署流程

```
┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│ 1. 准备阶段  │ -> │ 2. 传输阶段  │ -> │ 3. 安装阶段  │
│ 下载离线包   │    │ U盘/光盘     │    │ 离线安装    │
└─────────────┘    └─────────────┘    └─────────────┘
                                               │
                                               ▼
┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│ 6. 验证阶段  │ <- │ 5. 配置阶段  │ <- │ 4. 启动阶段  │
│ 检查服务     │    │ 配置修改     │    │ 服务启动    │
└─────────────┘    └─────────────┘    └─────────────┘
```

---

## 二、离线软件包清单

### 2.1 必需软件包

| 序号 | 软件包 | 版本 | 文件名 | 大小约 |
|------|--------|------|--------|--------|
| 1 | Go | 1.21.14 | go1.21.14.linux-amd64.tar.gz | 105MB |
| 2 | Node.js | **16.20.5** | node-v16.20.5-linux-x64.tar.xz | 35MB | **CentOS 7 推荐版本**（18+ 需要 glibc 2.27） |
| 3 | pnpm | 8.15.0 | pnpm | 15MB |
| 4 | Protocol Buffers | 25.1 | protoc-25.1-linux-x86_64.zip | 3MB |

### 2.2 Docker 相关（**必须先安装 container-selinux**）

| 序号 | 软件包 | 版本 | 文件名 | 大小约 |
|------|--------|------|--------|--------|
| **0** | **container-selinux** | 2.119.2 | container-selinux-2.119.2-1.git875a4a4.el7.noarch.rpm | 50KB | **必须先安装** |
| 5 | containerd | 1.6.33 | containerd.io-1.6.33-3.1.el7.x86_64.rpm | 30MB |
| 6 | Docker Engine | 26.1.4 | docker-ce-26.1.4-1.el7.x86_64.rpm | 20MB |
| 7 | Docker CLI | 26.1.4 | docker-ce-cli-26.1.4-1.el7.x86_64.rpm | 5MB |
| 8 | Docker Buildx | 0.12.1 | docker-buildx-plugin-0.12.1-1.el7.x86_64.rpm | 10MB |
| 9 | Docker Compose | 2.24.5 | docker-compose-plugin-2.24.5-1.el7.x86_64.rpm | 10MB |

### 2.3 Docker 镜像（离线导出）

| 镜像 | 版本 | 说明 |
|------|------|------|
| mysql | 8.0.35 | MySQL 数据库 |
| redis | 7.4.1 | Redis 缓存 |

### 2.4 系统依赖（本地源）

| 软件包 | 仓库 | 说明 |
|--------|------|------|
| wget | Base | 下载工具 |
| curl | Base | HTTP 客户端 |
| git | Base | 版本控制 |
| unzip | Base | 解压缩 |
| tar | Base | 解压缩 |
| xz | Base | 解压缩 |
| gcc/gcc-c++ | Base | 编译工具 |
| make | Base | 构建工具 |
| openssl | Base | SSL 库 |
| perl | Base | 脚本语言 |
| net-tools | Base | 网络工具 |
| jq | EPEL | JSON 处理 |
| epel-release | Base | EPEL 源 |

---

## 三、环境准备

### 3.1 下载离线包（在有网络的机器上）

#### 方式一：使用下载脚本

```bash
# 在有网络的机器上执行
cd software/scripts

# 下载所有离线包
./download-offline.sh /path/to/packages

# 或分项下载
./download-offline.sh --go
./download-offline.sh --node
./download-offline.sh --docker
```

#### 方式二：手动下载

```bash
# 创建目录
mkdir -p /tmp/lumenim-packages

# Go
wget -O /tmp/lumenim-packages/go1.21.14.linux-amd64.tar.gz \
    https://go.dev/dl/go1.21.14.linux-amd64.tar.gz

# Node.js（CentOS 7 推荐使用 16.x 版本）
wget -O /tmp/lumenim-packages/node-v16.20.5-linux-x64.tar.xz \
    https://nodejs.org/dist/v16.20.5/node-v16.20.5-linux-x64.tar.xz

# pnpm
wget -O /tmp/lumenim-packages/pnpm \
    https://github.com/pnpm/pnpm/releases/download/v8.15.0/pnpm-linux-x64
chmod +x /tmp/lumenim-packages/pnpm

# Protocol Buffers
wget -O /tmp/lumenim-packages/protoc-25.1-linux-x86_64.zip \
    https://github.com/protocolbuffers/protobuf/releases/download/v25.1/protoc-25.1-linux-x86_64.zip
```

#### 方式三：Docker 离线包

```bash
# Docker RPM 包（CentOS 7）
mkdir -p /tmp/lumenim-packages/docker
cd /tmp/lumenim-packages/docker

# 1. 必须先下载 container-selinux（这是安装 Docker 的前提依赖）
wget https://download.docker.com/linux/centos/7/x86_64/stable/Packages/container-selinux-2.119.2-1.git875a4a4.el7.noarch.rpm

# 2. 下载 Docker CE 各组件
wget https://download.docker.com/linux/centos/7/x86_64/stable/Packages/containerd.io-1.6.33-3.1.el7.x86_64.rpm
wget https://download.docker.com/linux/centos/7/x86_64/stable/Packages/docker-ce-26.1.4-1.el7.x86_64.rpm
wget https://download.docker.com/linux/centos/7/x86_64/stable/Packages/docker-ce-cli-26.1.4-1.el7.x86_64.rpm
wget https://download.docker.com/linux/centos/7/x86_64/stable/Packages/docker-buildx-plugin-0.12.1-1.el7.x86_64.rpm
wget https://download.docker.com/linux/centos/7/x86_64/stable/Packages/docker-compose-plugin-2.24.5-1.el7.x86_64.rpm
```

### 3.2 导出 Docker 镜像（离线）

```bash
# 在有 Docker 的机器上拉取镜像
docker pull mysql:8.0.35
docker pull redis:7.4.1

# 导出为 tar 文件
docker save -o mysql-8.0.35.tar mysql:8.0.35
docker save -o redis-7.4.1.tar redis:7.4.1
```

### 3.3 打包项目文件

```bash
# 在项目根目录
cd /path/to/LumenIM

# 打包后端
tar -czf backend.tar.gz backend/

# 打包前端（排除 node_modules）
cd front
tar --exclude='node_modules' -czf ../front.tar.gz .
```

### 3.4 制作离线介质

#### U 盘方式

```bash
# 格式化 U 盘
sudo mkfs.vfat -I /dev/sdc1

# 复制文件
mount /dev/sdc1 /mnt/usb
cp -r /tmp/lumenim-packages/* /mnt/usb/
umount /mnt/usb
```

#### 光盘方式

```bash
# 制作 ISO
mkisofs -o lumenim-packages.iso -r -J /tmp/lumenim-packages/
```

---

## 四、上传与准备

### 4.1 文件传输到目标服务器

#### U 盘挂载

```bash
# 插入 U 盘后
lsblk  # 查看设备

# 挂载
mount /dev/sdc1 /mnt/packages

# 验证
ls -la /mnt/packages
```

#### SCP（如果内网可访问）

```bash
# 从有网络的机器传输
scp -r /tmp/lumenim-packages user@target-server:/tmp/
```

#### 光盘挂载

```bash
# 挂载光盘
mount -o loop /dev/cdrom /mnt/packages
```

### 4.2 目录结构

离线包上传后的目标服务器目录结构：

```
/mnt/packages/
├── go1.21.14.linux-amd64.tar.gz
├── node-v16.20.5-linux-x64.tar.xz    # CentOS 7 推荐使用 16.x 版本
├── pnpm
├── protoc-25.1-linux-x86_64.zip
├── backend.tar.gz        # 项目后端
├── front.tar.gz        # 项目前端（可选）
├── docker/              # Docker RPM 包
│   ├── container-selinux-2.119.2-1.git875a4a4.el7.noarch.rpm   # 必须先安装
│   ├── containerd.io-1.6.33-3.1.el7.x86_64.rpm
│   ├── docker-ce-26.1.4-1.el7.x86_64.rpm
│   ├── docker-ce-cli-26.1.4-1.el7.x86_64.rpm
│   └── ...
└── images/              # Docker 镜像（离线）
    ├── mysql-8.0.35.tar
    └── redis-7.4.1.tar
```

---

## 五、软件安装

### 5.1 安装系统依赖

```bash
# 进入目标服务器（使用 root）

# 检查离线包目录
ls -la /mnt/packages

# 安装本地 yum 源（如果有本地 repo）
# 或者直接 rpm 安装

# 先安装基础工具
rpm -Uvh --force /mnt/packages/*.rpm || true

# 安装 EPEL（如果本地有）
rpm -Uvh /mnt/packages/epel-release-*.rpm || true
```

### 5.2 安装 Go

```bash
# 安装 Go
cd /
rm -rf /usr/local/go
tar -xzf /mnt/packages/go1.21.14.linux-amd64.tar.gz

# 配置环境变量
cat > /etc/profile.d/go.sh << 'EOF'
export GOROOT=/usr/local/go
export PATH=$PATH:$GOROOT/bin
export GOPATH=$HOME/go
EOF
chmod +x /etc/profile.d/go.sh

# 验证
source /etc/profile.d/go.sh
go version
```

### 5.3 安装 Node.js

> **兼容性说明**：CentOS 7 默认 glibc 版本为 2.17，Node.js 18+ 需要更高版本（glibc 2.27+）。如果遇到 `GLIBC_2.27 not found` 错误，请使用 Node.js 16 或通过 Docker 方式运行构建。

#### 方案一：直接安装 Node.js 16（推荐）

```bash
# 安装 Node.js 16（兼容 CentOS 7）
cd /
rm -rf /usr/local/node
tar -xJf /mnt/packages/node-v16.20.5-linux-x64.tar.xz
mv node-v16.20.5-linux-x64 /usr/local/node

# 安装 pnpm
cp /mnt/packages/pnpm /usr/local/node/bin/pnpm
chmod +x /usr/local/node/bin/pnpm

# 配置环境变量
cat > /etc/profile.d/nodejs.sh << 'EOF'
export NODE_PREFIX=/usr/local/node
export PATH=$PATH:$NODE_PREFIX/bin
EOF
chmod +x /etc/profile.d/nodejs.sh

# 验证
source /etc/profile.d/nodejs.sh
node --version    # 应显示 v16.x.x
pnpm --version
```

#### 方案二：使用 Docker 运行 Node.js（完全隔离，推荐生产环境）

如果直接安装 Node.js 仍然遇到兼容性问题，建议使用 Docker 运行前端构建：

```bash
# 在有网络的机器上导出 Node.js Docker 镜像
docker pull node:16-alpine
docker save node:16-alpine -o node-16-alpine.tar

# 在离线服务器导入
docker load -i node-16-alpine.tar

# 使用 Docker 运行前端构建
cd /var/www/lumenim/front
docker run -it --rm \
  -v $(pwd):/app \
  -w /app \
  node:16-alpine \
  sh -c "pnpm install && pnpm build"
```

#### 方案三：使用 nvm 安装兼容版本

```bash
# 安装 nvm（需要网络）
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash
source ~/.bashrc

# 安装兼容版本
nvm install 16
nvm use 16
nvm alias default 16
```

### 5.4 安装 Protocol Buffers

```bash
# 安装 protoc
unzip -qo /mnt/packages/protoc-25.1-linux-x86_64.zip -d /usr/local/
cp -f /usr/local/bin/protoc /usr/local/bin/protoc.bak 2>/dev/null || true
cp -f /usr/local/protobuf/bin/protoc /usr/local/bin/

# 验证
protoc --version
```

---

## 六、Docker 安装

### 6.0 重要：安装 container-selinux 依赖

> **必须先安装此依赖！** CentOS 7 安装 Docker CE 时，必须先安装 `container-selinux`，否则会报错：`container-selinux >= 2:2.74 is needed by containerd.io`

#### 方案一：在线安装 container-selinux（推荐）

```bash
# 方法1：从 Docker 官方源下载
yum install -y http://mirror.centos.org/centos/7.9.2009/extras/x86_64/Packages/container-selinux-2.119.2-1.git875a4a4.el7.noarch.rpm

# 方法2：如果上面失败，尝试备用地址
yum install -y https://download.docker.com/linux/centos/7/x86_64/stable/Packages/container-selinux-2.119.2-1.git875a4a4.el7.noarch.rpm
```

#### 方案二：手动下载（完全离线环境）

在有网络的机器上下载以下文件：

| 文件名 | 下载地址 |
|--------|----------|
| container-selinux-2.119.2-1.git875a4a4.el7.noarch.rpm | https://download.docker.com/linux/centos/7/x86_64/stable/Packages/ |

```bash
# 在离线服务器安装
rpm -ivh container-selinux-2.119.2-1.git875a4a4.el7.noarch.rpm
```

#### 方案三：使用阿里云镜像源（国内服务器推荐）

```bash
# 添加阿里云 Docker 源
yum-config-manager --add-repo https://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo

# 安装 container-selinux
yum install -y container-selinux

# 安装完成后，再继续安装 Docker
```

---

### 6.1 离线安装 Docker

```bash
# 进入 Docker RPM 目录
cd /mnt/packages/docker

# 安装（按依赖顺序）
rpm -Uvh --force *.rpm

# 或者
yum localinstall -y *.rpm

# 启动 Docker
systemctl start docker
systemctl enable docker

# 验证
docker --version
docker ps
```

### 6.2 加载 Docker 镜像

```bash
# 进入镜像目录
cd /mnt/packages/images

# 加载镜像
docker load -i mysql-8.0.35.tar
docker load -i redis-7.4.1.tar

# 验证
docker images
```

### 6.3 配置镜像加速

```bash
# 创建配置目录
mkdir -p /etc/docker

# 配置镜像加速（离线环境可选）
cat > /etc/docker/daemon.json << 'EOF'
{
    "registry-mirrors": []
}
EOF

# 重启 Docker
systemctl restart docker
```

---

## 七、数据库服务

### 7.1 启动 MySQL 容器

```bash
# 创建数据目录
mkdir -p /var/lib/lumenim/mysql
mkdir -p /var/lib/lumenim/redis

# 启动 MySQL
docker run -d \
    --name lumenim-mysql \
    -e MYSQL_ROOT_PASSWORD=wenming429 \
    -e MYSQL_DATABASE=go_chat \
    -e MYSQL_USER=lumenim \
    -e MYSQL_PASSWORD=lumenim123 \
    -p 3306:3306 \
    -v /var/lib/lumenim/mysql:/var/lib/mysql \
    mysql:8.0.35 \
    --default-authentication-plugin=mysql_native_password

# 等待启动
sleep 30

# 验证
docker ps
docker logs lumenim-mysql
```

### 7.2 启动 Redis 容器

```bash
# 启动 Redis
docker run -d \
    --name lumenim-redis \
    -p 6379:6379 \
    -v /var/lib/lumenim/redis:/data \
    redis:7.4.1 redis-server --appendonly yes

# 验证
docker ps
docker logs lumenim-redis
```

---

## 八、部署项目

### 8.1 上传项目文件

```bash
# 从 U 盘复制
cp /mnt/packages/backend.tar.gz /var/www/
cp /mnt/packages/front.tar.gz /var/www/

# 解压
cd /var/www
tar -xzf backend.tar.gz
tar -xzf front.tar.gz

# 重命名
mv backend lumenim
cd lumenim
mv front-tar.gz front 2>/dev/null || true
```

### 8.2 配置项目

```bash
# 编辑配置文件
vim /var/www/lumenim/backend/config.yaml

# 修改数据库配置
mysql:
  host: localhost
  port: 3306
  username: lumenim
  password: lumenim123
  database: go_chat

# 修改 Redis 配置
redis:
  host: localhost:6379
  database: 0

# 创建运行用户
useradd -r -s /bin/false -d /nonexistent www-data 2>/dev/null || true

# 设置权限
chown -R www-data:www-data /var/www/lumenim
```

### 8.3 安装后端依赖

```bash
# 设置环境变量
export GOROOT=/usr/local/go
export PATH=$PATH:$GOROOT/bin
export GOPATH=$HOME/go

# 进入后端目录
cd /var/www/lumenim/backend

# 下载 Go 依赖（需要网络）
go mod download

# 或者：如果完全离线，需要提前打包 go.mod cache
# 复制 vendor 目录
cp -r /mnt/packages/vendor ./vendor 2>/dev/null || true
```

### 8.4 安装前端依赖

```bash
# 设置环境变量
export NODE_PREFIX=/usr/local/node
export PATH=$PATH:$NODE_PREFIX/bin

# 进入前端目录
cd /var/www/lumenim/front

# 安装依赖
pnpm install

# 或者：如果完全离线
# 提前在有网络机器打包 node_modules
# rsync -avz node_modules/ target:/var/www/lumenim/front/
```

### 8.5 编译后端

```bash
cd /var/www/lumenim/backend

# 编译
go build -o bin/lumenim .

# 或使用构建脚本
chmod +x build.sh
./build.sh
```

---

## 九、服务配置

### 9.1 创建 systemd 服务

```bash
# 后端服务
cat > /etc/systemd/system/lumenim-backend.service << 'EOF'
[Unit]
Description=LumenIM Backend Service
After=network.target mysql.service redis.service docker.service

[Service]
Type=simple
User=www-data
Group=www-data
WorkingDirectory=/var/www/lumenim/backend
Environment="PATH=/usr/local/go/bin:/usr/local/node/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
Environment="PORT=9501"
ExecStart=/var/www/lumenim/backend/bin/lumenim
Restart=on-failure
RestartSec=5s
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF

# 前端服务
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

# 重新加载
systemctl daemon-reload
```

### 9.2 配置防火墙

```bash
# 开放端口
firewall-cmd --permanent --add-port=9501/tcp
firewall-cmd --permanent --add-port=9502/tcp
firewall-cmd --permanent --add-port=9505/tcp
firewall-cmd --permanent --add-port=3306/tcp
firewall-cmd --permanent --add-port=6379/tcp
firewall-cmd --reload

# 禁用 SELinux（可选）
setenforce 0
sed -i 's/SELINUX=enforcing/SELINUX=permissive/' /etc/selinux/config
```

### 9.3 配置内核参数

```bash
# 添加到 /etc/sysctl.conf
cat >> /etc/sysctl.conf << 'EOF'
net.core.somaxconn = 65535
net.ipv4.tcp_max_syn_backlog = 65535
fs.file-max = 65535
EOF

# 生效
sysctl -p

# 添加资源限制
cat >> /etc/security/limits.conf << 'EOF'
www-data soft nofile 65535
www-data hard nofile 65535
www-data soft nproc 65535
www-data hard nproc 65535
EOF
```

---

## 十、服务管理

### 10.1 启动服务

```bash
# 启动 Docker
systemctl start docker

# 启动数据库容器
docker start lumenim-mysql
docker start lumenim-redis

# 等待数据库就绪
sleep 30

# 启动后端
systemctl start lumenim-backend
systemctl enable lumenim-backend

# 启动前端
systemctl start lumenim-frontend
systemctl enable lumenim-frontend
```

### 10.2 停止服务

```bash
# 停止应用
systemctl stop lumenim-backend
systemctl stop lumenim-frontend

# 停止数据库
docker stop lumenim-mysql
docker stop lumenim-redis

# 停止 Docker
systemctl stop docker
```

### 10.3 重启服务

```bash
# 重启后端
systemctl restart lumenim-backend

# 重启前端
systemctl restart lumenim-frontend
```

### 10.4 查看服务状态

```bash
# systemd 服务状态
systemctl status lumenim-backend
systemctl status lumenim-frontend

# Docker 容器状态
docker ps
docker logs lumenim-mysql
docker logs lumenim-redis

# 端口检查
lsof -i:9501
lsof -i:9502
lsof -i:3306
lsof -i:6379
```

### 10.5 查看日志

```bash
# systemd 日志
journalctl -u lumenim-backend -n 100 -f
journalctl -u lumenim-frontend -n 100 -f

# Docker 日志
docker logs -f lumenim-mysql
docker logs -f lumenim-redis
```

---

## 十一、验证部署

### 11.1 服务验证

```bash
# API 健康检查
curl http://localhost:9501/api/v1/health

# WebSocket 测试
# 使用 wscat 或浏览器测试 ws://localhost:9502

# 前端访问
curl http://localhost:5173
```

### 11.2 数据库验证

```bash
# MySQL 连接
docker exec lumenim-mysql mysql -u root -pwenming429 -e "SELECT 1"

# 创建数据库（如果不存在）
docker exec lumenim-mysql mysql -u root -pwenming429 -e \
    "CREATE DATABASE IF NOT EXISTS go_chat CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;"
```

### 11.3 Redis 验证

```bash
# Redis 连接
docker exec lumenim-redis redis-cli ping
```

---

## 十二、常见问题排查

### 12.1 端口占用

```bash
# 查找占用端口的进程
lsof -i:9501
netstat -tlnp | grep 9501

# 释放端口
kill -9 <PID>
```

### 12.2 权限问题

```bash
# 修改权限
chown -R www-data:www-data /var/www/lumenim

# 赋权
chmod +x /var/www/lumenim/backend/bin/lumenim
```

### 12.3 数据库连接失败

```bash
# 检查容器状态
docker ps -a

# 检查容器日志
docker logs lumenim-mysql

# 重启容器
docker restart lumenim-mysql
```

### 12.4 环境变量未生效

```bash
# 手动设置
export GOROOT=/usr/local/go
export PATH=$PATH:$GOROOT/bin
export NODE_PREFIX=/usr/local/node
export PATH=$PATH:$NODE_PREFIX/bin
```

### 12.5 Node.js GLIBC 版本不兼容

**错误信息**：
```
node: /lib64/libm.so.6: version `GLIBC_2.27' not found (required by node)
node: /lib64/libc.so.6: version `GLIBC_2.25' not found (required by node)
```

**解决方案**：

```bash
# 方案1：降级到 Node.js 16（推荐）
# 下载 Node.js 16
wget -O /tmp/node-v16.20.5-linux-x64.tar.xz \
    https://nodejs.org/dist/v16.20.5/node-v16.20.5-linux-x64.tar.xz

# 重新安装
rm -rf /usr/local/node
tar -xJf /tmp/node-v16.20.5-linux-x64.tar.xz -C /
mv /node-v16.20.5-linux-x64 /usr/local/node

# 方案2：使用 Docker 运行 Node.js（完全隔离）
docker pull node:16-alpine
docker save node:16-alpine -o node-16-alpine.tar
docker load -i node-16-alpine.tar

# 使用 Docker 进行前端构建
docker run -it --rm \
  -v /var/www/lumenim/front:/app \
  -w /app \
  node:16-alpine \
  sh -c "pnpm install && pnpm build"
```

### 12.6 Docker 安装时报错 container-selinux 依赖缺失

**错误信息**：
```
错误：依赖检测失败：
container-selinux >= 2:2.74 被 containerd.io-1.6.33-3.1.el7.x86_64 需要
```

**解决方案**：

```bash
# 方案1：在线安装
yum install -y http://mirror.centos.org/centos/7.9.2009/extras/x86_64/Packages/container-selinux-2.119.2-1.git875a4a4.el7.noarch.rpm

# 方案2：使用阿里云源
yum-config-manager --add-repo https://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo
yum install -y container-selinux

# 方案3：完全离线（需要在外网机器下载）
# 下载地址：
# https://download.docker.com/linux/centos/7/x86_64/stable/Packages/container-selinux-2.119.2-1.git875a4a4.el7.noarch.rpm

# 在离线服务器安装
rpm -ivh container-selinux-2.119.2-1.git875a4a4.el7.noarch.rpm

# 重新安装 Docker
cd /mnt/packages/docker
rpm -Uvh --force *.rpm
```

---

## 十三、快速参考命令

### 13.1 离线安装完整命令

```bash
# 1. 挂载离线包
mount /dev/sdc1 /mnt/packages

# 2. 安装 container-selinux（必须先安装，否则 Docker 无法安装）
cd /mnt/packages/docker
rpm -ivh container-selinux-2.119.2-1.git875a4a4.el7.noarch.rpm

# 3. 安装 Docker
cd /mnt/packages/docker
rpm -Uvh --force *.rpm
systemctl start docker
systemctl enable docker

# 4. 加载 Docker 镜像
docker load -i /mnt/packages/images/mysql-8.0.35.tar
docker load -i /mnt/packages/images/redis-7.4.1.tar

# 5. 安装运行时
cd / && tar -xzf /mnt/packages/go*.tar.gz
cd / && tar -xJf /mnt/packages/node*.tar.xz   # 使用 node-v16.x.x（CentOS 7 兼容版本）
cp /mnt/packages/pnpm /usr/local/node/bin/

# 6. 启动数据库容器
docker run -d --name lumenim-mysql ...
docker run -d --name lumenim-redis ...

# 7. 部署项目
tar -xzf /mnt/packages/backend.tar.gz -C /var/www/
cd /var/www/lumenim/backend && go build

# 8. 启动服务
systemctl start lumenim-backend
systemctl enable lumenim-backend
```

### 13.2 服务管理

```bash
# 启动所有
systemctl start docker && \
docker start lumenim-mysql lumenim-redis && \
systemctl start lumenim-backend

# 停止所有
systemctl stop lumenim-backend lumenim-frontend && \
docker stop lumenim-mysql lumenim-redis

# 查看状态
systemctl status lumenim-backend
docker ps
```

---

**文档结束**