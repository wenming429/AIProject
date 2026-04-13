# LumenIM Ubuntu 20.04 部署指南

**文档版本**: 4.0.0
**更新日期**: 2026-04-10
**适用系统**: Ubuntu 20.04 LTS / 22.04 LTS
**部署方式**: Docker Compose (推荐) / 原生部署

---

## 一、系统架构

### 1.1 Docker 部署架构

```
┌─────────────────────────────────────────────────────────────────────────┐
│                           用户访问层                                     │
│                    (浏览器 / 桌面客户端 / 移动端)                        │
└─────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                         Nginx 反向代理 (Docker)                          │
│                    端口: 80 (HTTP) / 443 (HTTPS)                         │
└─────────────────────────────────────────────────────────────────────────┘
                                    │
          ┌─────────────────────────┼─────────────────────────┐
          │                         │                         │
          ▼                         ▼                         ▼
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│   前端静态资源    │     │   HTTP API 服务  │     │  WebSocket 服务  │
│   (Nginx托管)   │     │   端口: 9501     │     │   端口: 9502     │
└─────────────────┘     └────────┬────────┘     └────────┬────────┘
                                 │                         │
                                 └───────────┬─────────────┘
                                             │
┌─────────────────────────────────────────────────────────────────────────┐
│                      Docker Network (lumenim-network)                     │
│                        lumenim_http / lumenim_comet                      │
│                          lumenim_queue / lumenim_cron                     │
└─────────────────────────────────────────────────────────────────────────┘
          │                    │                    │                    │
          ▼                    ▼                    ▼                    ▼
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│     MySQL       │     │     Redis       │     │     MinIO       │
│   端口: 3306    │     │   端口: 6379    │     │  端口: 9000/9090│
│   Docker 容器    │     │   Docker 容器   │     │   Docker 容器    │
└─────────────────┘     └─────────────────┘     └─────────────────┘
```

### 1.2 服务组件说明

| 服务名称 | 容器名 | 端口 | 说明 | 资源需求 |
|---------|--------|------|------|----------|
| mysql | lumenim-mysql | 3306 | MySQL 8.0 数据库 | 视用户量 |
| redis | lumenim-redis | 6379 | Redis 7.4 缓存 | 512MB+ |
| minio | lumenim-minio | 9000/9090 | MinIO 对象存储 | 视文件量 |
| nginx | lumenim-nginx | 80/443 | Nginx 反向代理 | 128MB |
| lumenim_http | lumenim-http | 9501 | RESTful API 服务 | 256MB |
| lumenim_comet | lumenim-comet | 9502 | WebSocket 长连接 | 512MB |
| lumenim_queue | lumenim-queue | - | 异步消息队列 | 256MB |
| lumenim_cron | lumenim-cron | - | 定时任务服务 | 128MB |

---

## 二、环境要求

### 2.1 硬件配置

| 项目 | 最低要求 | 推荐配置 |
|------|----------|----------|
| 系统 | Ubuntu 20.04 LTS | Ubuntu 22.04 LTS |
| CPU | 2 核 | 4 核+ |
| 内存 | 4 GB | 8 GB+ |
| 磁盘 | 30 GB | 50 GB+ SSD |
| 网络 | 带宽 5 Mbps | 带宽 10 Mbps+ |

### 2.2 部署规模推荐

| 部署规模 | 用户数 | CPU | 内存 | 磁盘 | 适用场景 |
|---------|--------|-----|------|------|----------|
| 入门版 | ≤50人 | 2核 | 4GB | 50GB | 小团队/测试环境 |
| 标准版 | 50-200人 | 4核 | 8GB | 100GB | 中型企业 |
| 企业版 | 200-1000人 | 8核 | 16GB | 200GB | 大型企业 |
| 旗舰版 | 1000+人 | 16核 | 32GB | 500GB | 超大规模部署 |

---

## 三、Docker 安装 (推荐方式)

### 3.1 卸载旧版本

```bash
# 卸载旧版本 Docker (如果存在)
sudo apt remove docker docker-engine docker.io containerd runc

# 清理残留
sudo apt autoremove --purge docker docker-engine docker.io containerd runc

# 确认已卸载
sudo apt-cache policy docker.io
```

### 3.2 安装 Docker

#### 方式一：使用官方仓库安装 (推荐)

```bash
# 1. 更新软件包索引
sudo apt update
sudo apt install -y ca-certificates curl gnupg lsb-release

# 2. 添加 Docker GPG 密钥
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

# 3. 设置 Docker 仓库 (Ubuntu 20.04/22.04)
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# 4. 安装 Docker
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# 5. 验证安装
docker --version
docker compose version
```

#### 方式二：使用阿里云镜像加速

```bash
# 1. 添加阿里云 Docker 镜像源
curl -fsSL https://mirrors.aliyun.com/docker-ce/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://mirrors.aliyun.com/docker-ce/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list

# 2. 安装 Docker
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
```

#### 方式三：一键安装脚本

```bash
# 使用官方安装脚本
curl -fsSL https://get.docker.com | sh -s -- --mirror Aliyun

# 或使用国内镜像
curl -fsSL https://get.docker.com | sh -s -- --mirror AzureChinaCloud
```

### 3.3 配置 Docker 镜像加速

```bash
# 创建 Docker 配置目录
sudo mkdir -p /etc/docker

# 配置镜像加速器
sudo tee /etc/docker/daemon.json <<'EOF'
{
  "registry-mirrors": [
    "https://docker.1ms.run",
    "https://docker.xuanyuan.me",
    "https://docker.m.daocloud.io"
  ],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m",
    "max-file": "3"
  },
  "storage-driver": "overlay2",
  "live-restore": true
}
EOF

# 重启 Docker 服务
sudo systemctl daemon-reload
sudo systemctl restart docker
sudo systemctl enable docker

# 验证配置
docker info | grep -A 10 "Registry Mirrors"
```

### 3.4 Docker 服务配置

```bash
# 配置 Docker 开机自启
sudo systemctl enable docker
sudo systemctl enable containerd

# 当前用户加入 docker 组 (免 sudo)
sudo usermod -aG docker $USER

# 重新登录生效
newgrp docker

# 验证 Docker 运行状态
sudo systemctl status docker
```

### 3.5 Docker 安装验证

```bash
# 基本信息检查
docker --version              # Docker 版本
docker compose version        # Docker Compose 版本
docker info                   # Docker 详细信息

# 运行测试容器
sudo docker run --rm hello-world
```

### 3.6 防火墙配置

```bash
# Ubuntu UFW 防火墙配置
sudo ufw allow 22/tcp                  # SSH
sudo ufw allow 80/tcp                  # HTTP
sudo ufw allow 443/tcp                 # HTTPS
sudo ufw allow 2375/tcp                # Docker API (仅内网)

# 保存规则
sudo ufw reload
```

---

## 四、Docker Compose 部署 (详细配置)

### 4.1 docker-compose.yaml 完整配置

```yaml
# LumenIM Docker Compose 配置文件 (Ubuntu 20.04/22.04)
# 
# 使用方法:
#   1. 复制到 backend 目录: cp docker-compose-ubuntu.yaml docker-compose.yaml
#   2. 编辑 .env 文件配置数据库密码
#   3. 编辑 config.yaml 后端配置
#   4. docker compose up -d

version: '3.8'

services:
  # ==================== MySQL 数据库 ====================
  mysql:
    image: mysql:8.0
    container_name: lumenim-mysql
    restart: always
    ports:
      - '3306:3306'
    environment:
      MYSQL_ROOT_PASSWORD: ${MYSQL_ROOT_PASSWORD:-lumenim123}
      MYSQL_DATABASE: ${MYSQL_DATABASE:-go_chat}
      MYSQL_USER: ${MYSQL_USER:-lumenim}
      MYSQL_PASSWORD: ${MYSQL_PASSWORD:-lumenim123}
      TZ: Asia/Shanghai
    volumes:
      # 数据卷: MySQL 数据持久化
      - mysql_data:/var/lib/mysql
      # 初始化脚本: 首次启动自动执行
      - ./sql:/docker-entrypoint-initdb.d:ro
    command: >
      --default-authentication-plugin=mysql_native_password
      --character-set-server=utf8mb4
      --collation-server=utf8mb4_unicode_ci
      --max_connections=1000
      --innodb_buffer_pool_size=512M
      --default-time-zone='+08:00'
      --slow_query_log=1
      --long_query_time=2
    networks:
      - lumenim-network
    healthcheck:
      test: ["CMD", "mysqladmin", "ping", "-h", "localhost", "-uroot", "-p${MYSQL_ROOT_PASSWORD}"]
      interval: 10s
      timeout: 5s
      retries: 10
      start_period: 60s
    deploy:
      resources:
        limits:
          memory: 2G
        reservations:
          memory: 512M

  # ==================== Redis 缓存 ====================
  redis:
    image: redis:7.4-alpine
    container_name: lumenim-redis
    restart: always
    ports:
      - '6379:6379'
    volumes:
      # 数据卷: Redis 数据持久化
      - redis_data:/data
      # 自定义配置
      - ./redis.conf:/usr/local/etc/redis/redis.conf:ro
    command: redis-server /usr/local/etc/redis/redis.conf
    networks:
      - lumenim-network
    healthcheck:
      test: ["CMD", "redis-cli", "-a", "${REDIS_PASSWORD}", "ping"]
      interval: 10s
      timeout: 5s
      retries: 5
    deploy:
      resources:
        limits:
          memory: 1G

  # ==================== MinIO 对象存储 ====================
  minio:
    image: minio/minio:latest
    container_name: lumenim-minio
    restart: always
    ports:
      - '9000:9000'     # API 端口
      - '9090:9090'     # Console 控制台
    environment:
      MINIO_ROOT_USER: ${MINIO_ROOT_USER:-minioadmin}
      MINIO_ROOT_PASSWORD: ${MINIO_ROOT_PASSWORD:-minioadmin123}
    volumes:
      # 数据卷: MinIO 数据持久化
      - minio_data:/data
    command: server /data --console-address ":9090"
    networks:
      - lumenim-network
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:9000/minio/health/live"]
      interval: 30s
      timeout: 20s
      retries: 3
      start_period: 30s
    deploy:
      resources:
        limits:
          memory: 2G

  # ==================== MinIO 初始化 ====================
  minio-init:
    image: minio/mc:latest
    container_name: lumenim-minio-init
    depends_on:
      minio:
        condition: service_healthy
    entrypoint: >
      /bin/sh -c "
      mc alias set local http://minio:9000 $${MINIO_ROOT_USER} $${MINIO_ROOT_PASSWORD};
      mc mb local/im-static --ignore-existing;
      mc mb local/im-private --ignore-existing;
      mc anonymous set download local/im-private;
      mc anonymous set public local/im-static;
      exit 0;
      "
    networks:
      - lumenim-network
    restart: "no"

  # ==================== Nginx 反向代理 ====================
  nginx:
    image: nginx:alpine
    container_name: lumenim-nginx
    restart: always
    ports:
      - '${NGINX_HTTP_PORT:-80}:80'      # HTTP
      - '${NGINX_HTTPS_PORT:-443}:443'   # HTTPS
    volumes:
      # 配置文件: Nginx 配置
      - ./nginx.conf:/etc/nginx/conf.d/default.conf:ro
      # 前端静态资源
      - ../front/dist:/usr/share/nginx/html:ro
      # SSL 证书
      - ./ssl:/etc/nginx/ssl:ro
      # 日志卷
      - nginx_logs:/var/log/nginx
    depends_on:
      lumenim_http:
        condition: service_healthy
      lumenim_comet:
        condition: service_healthy
    networks:
      - lumenim-network
    healthcheck:
      test: ["CMD", "wget", "-q", "--spider", "http://localhost/health"]
      interval: 30s
      timeout: 10s
      retries: 3
    deploy:
      resources:
        limits:
          memory: 256M

  # ==================== LumenIM HTTP API ====================
  lumenim_http:
    image: gzydong/lumenim:latest
    container_name: lumenim-http
    depends_on:
      mysql:
        condition: service_healthy
      redis:
        condition: service_healthy
      minio:
        condition: service_healthy
    ports:
      - '9501:9501'
    restart: always
    volumes:
      # 配置文件: 只读挂载
      - ./config.yaml:/work/config.yaml:ro
      # 上传目录: 读写权限
      - uploads:/work/uploads:rw
      # 运行时目录: 日志、缓存
      - runtime:/work/runtime:rw
    command: http --config=/work/config.yaml
    networks:
      - lumenim-network
    healthcheck:
      test: ["CMD", "wget", "-q", "--spider", "http://localhost:9501/api/v1/health"]
      interval: 30s
      timeout: 10s
      retries: 5
      start_period: 40s
    deploy:
      replicas: 2
      resources:
        limits:
          memory: 1G
        reservations:
          memory: 256M

  # ==================== LumenIM WebSocket ====================
  lumenim_comet:
    image: gzydong/lumenim:latest
    container_name: lumenim-comet
    depends_on:
      mysql:
        condition: service_healthy
      redis:
        condition: service_healthy
    ports:
      - '9502:9502'
    restart: always
    volumes:
      - ./config.yaml:/work/config.yaml:ro
      - runtime:/work/runtime:rw
    command: comet --config=/work/config.yaml
    networks:
      - lumenim-network
    deploy:
      replicas: 2
      resources:
        limits:
          memory: 512M
        reservations:
          memory: 256M

  # ==================== LumenIM 异步队列 ====================
  lumenim_queue:
    image: gzydong/lumenim:latest
    container_name: lumenim-queue
    depends_on:
      mysql:
        condition: service_healthy
      redis:
        condition: service_healthy
      minio:
        condition: service_healthy
    restart: always
    volumes:
      - ./config.yaml:/work/config.yaml:ro
      - uploads:/work/uploads:rw
      - runtime:/work/runtime:rw
    command: queue --config=/work/config.yaml
    networks:
      - lumenim-network
    deploy:
      replicas: 1
      resources:
        limits:
          memory: 512M

  # ==================== LumenIM 定时任务 ====================
  lumenim_cron:
    image: gzydong/lumenim:latest
    container_name: lumenim-cron
    depends_on:
      mysql:
        condition: service_healthy
      redis:
        condition: service_healthy
    restart: always
    volumes:
      - ./config.yaml:/work/config.yaml:ro
      - uploads:/work/uploads:rw
      - runtime:/work/runtime:rw
    command: crontab --config=/work/config.yaml
    networks:
      - lumenim-network
    deploy:
      replicas: 1
      resources:
        limits:
          memory: 256M

# ==================== 网络配置 ====================
networks:
  lumenim-network:
    driver: bridge
    ipam:
      config:
        - subnet: 172.28.0.0/16

# ==================== 数据卷配置 ====================
volumes:
  mysql_data:
    driver: local
    driver_opts:
      type: none
      o: bind
      device: ${DATA_DIR:-./data}/mysql
  redis_data:
    driver: local
    driver_opts:
      type: none
      o: bind
      device: ${DATA_DIR:-./data}/redis
  minio_data:
    driver: local
    driver_opts:
      type: none
      o: bind
      device: ${DATA_DIR:-./data}/minio
  nginx_logs:
  uploads:
  runtime:
```

### 4.2 端口映射详解

| 容器端口 | 宿主机端口 | 协议 | 服务 | 外部访问 | 说明 |
|---------|-----------|------|------|----------|------|
| 3306 | 3306 | TCP | MySQL | ❌ 不开放 | 仅 Docker 网络内访问 |
| 6379 | 6379 | TCP | Redis | ❌ 不开放 | 仅 Docker 网络内访问 |
| 9000 | 9000 | HTTP | MinIO API | ⚠️ 可选 | 对象存储 API |
| 9090 | 9090 | HTTP | MinIO Console | ⚠️ 可选 | MinIO 管理界面 |
| 9501 | 9501 | HTTP | HTTP API | ❌ 通过 Nginx | RESTful API |
| 9502 | 9502 | TCP | WebSocket | ❌ 通过 Nginx | 实时通信 |
| 80 | 80 | HTTP | Nginx | ✅ 开放 | 前端访问入口 |
| 443 | 443 | HTTPS | Nginx | ✅ 开放 | HTTPS 访问 |

### 4.3 数据卷挂载详解

```yaml
# 数据卷类型说明

# 1. 命名卷 (推荐用于数据持久化)
volumes:
  mysql_data:/var/lib/mysql        # MySQL 数据文件
  redis_data:/data                 # Redis AOF/RDB 文件
  minio_data:/data                 # MinIO 存储数据

# 2. 绑定挂载 (用于配置文件和源码)
volumes:
  - ./config.yaml:/work/config.yaml:ro          # 只读配置
  - ./nginx.conf:/etc/nginx/conf.d/default.conf:ro  # 只读 Nginx 配置
  - ../front/dist:/usr/share/nginx/html:ro     # 只读前端资源
  - ./ssl:/etc/nginx/ssl:ro                    # 只读 SSL 证书

# 3. 初始化脚本卷
volumes:
  - ./sql:/docker-entrypoint-initdb.d:ro        # MySQL 初始化 SQL

# 4. 读写卷 (运行时数据)
volumes:
  - uploads:/work/uploads:rw                   # 用户上传文件
  - runtime:/work/runtime:rw                   # 日志和缓存
```

### 4.4 网络配置详解

```yaml
# Docker 网络配置
networks:
  lumenim-network:
    driver: bridge           # 桥接网络
    ipam:                    # IP 地址管理
      config:
        - subnet: 172.28.0.0/16   # 自定义子网
          gateway: 172.28.0.1

# 容器间通信 (使用服务名作为主机名)
# lumenim_http 访问 MySQL: mysql:3306
# lumenim_http 访问 Redis: redis:6379
# lumenim_http 访问 MinIO: minio:9000
# nginx 访问 lumenim_http: lumenim_http:9501
```

### 4.5 .env 环境变量文件

```bash
# ==================== 数据库配置 ====================
MYSQL_ROOT_PASSWORD=lumenim123           # MySQL root 密码
MYSQL_DATABASE=go_chat                   # 数据库名称
MYSQL_USER=lumenim                       # 应用数据库用户
MYSQL_PASSWORD=lumenim123                # 应用数据库密码

# ==================== Redis 配置 ====================
REDIS_PASSWORD=redis_password            # Redis 密码
REDIS_PORT=6379                          # Redis 端口

# ==================== MinIO 配置 ====================
MINIO_ROOT_USER=minioadmin               # MinIO 用户名
MINIO_ROOT_PASSWORD=minioadmin123        # MinIO 密码

# ==================== 网络配置 ====================
BIND_IP=192.168.23.131                  # 服务器 IP
DOMAIN=mylumenim.cfldcn.com             # 域名 (可选)

# ==================== Nginx 配置 ====================
NGINX_HTTP_PORT=80                      # HTTP 端口
NGINX_HTTPS_PORT=443                    # HTTPS 端口

# ==================== 数据目录 ====================
DATA_DIR=/var/www/lumenim/data          # 数据存储目录

# ==================== 时区配置 ====================
TZ=Asia/Shanghai                        # 时区
```

### 4.6 Nginx 配置文件

```nginx
# nginx.conf - LumenIM Nginx 配置
# 位置: /var/www/lumenim/backend/nginx.conf

server {
    listen 80;
    server_name 192.168.23.131 mylumenim.cfldcn.com;

    # 根目录
    root /usr/share/nginx/html;
    index index.html;

    # ==================== 前端路由 (SPA) ====================
    location / {
        try_files $uri $uri/ /index.html;
    }

    # ==================== 静态资源缓存 ====================
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

    # ==================== API 代理 ====================
    location /api/ {
        proxy_pass http://lumenim_http:9501/api/;
        proxy_http_version 1.1;
        
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        
        # 超时设置
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }

    # ==================== WebSocket 代理 ====================
    location /ws/ {
        proxy_pass http://lumenim_comet:9502/ws/;
        proxy_http_version 1.1;
        
        # WebSocket 必需配置
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        
        # WebSocket 长连接超时
        proxy_read_timeout 86400;
        proxy_send_timeout 86400;
        
        # 禁用缓冲
        proxy_buffering off;
        proxy_cache off;
    }

    # ==================== 健康检查 ====================
    location /health {
        access_log off;
        return 200 "OK";
        add_header Content-Type text/plain;
    }
}
```

### 4.7 Redis 配置文件

```conf
# redis.conf - LumenIM Redis 配置
# 位置: /var/www/lumenim/backend/redis.conf

# ==================== 安全配置 ====================
requirepass redis_password              # Redis 密码
bind 0.0.0.0                            # 监听所有接口
protected-mode yes                      # 保护模式

# ==================== 性能配置 ====================
maxmemory 512mb                         # 最大内存
maxmemory-policy allkeys-lru             # 内存淘汰策略
tcp-backlog 511                         # TCP 连接队列
timeout 0                               # 空闲超时

# ==================== 持久化配置 ====================
appendonly yes                          # 开启 AOF
appendfilename "appendonly.aof"
appendfsync everysec                    # AOF 同步策略

# ==================== 日志配置 ====================
loglevel notice                         # 日志级别
```

---

## 五、Docker 部署步骤

### 5.1 完整部署流程

```bash
# 1. 创建项目目录
sudo mkdir -p /var/www/lumenim
cd /var/www/lumenim

# 2. 克隆源码
git clone https://github.com/gzydong/LumenIM.git .

# 3. 进入后端目录
cd backend

# 4. 复制 Docker Compose 配置
cp docker-compose-ubuntu.yaml docker-compose.yaml

# 5. 创建目录结构
mkdir -p data/mysql data/redis data/minio sql ssl

# 6. 配置环境变量
cp .env.example .env
nano .env  # 编辑密码

# 7. 配置后端
cp config.example.yaml config.yaml
nano config.yaml  # 编辑配置

# 8. 构建前端
cd ../front
pnpm install
pnpm build

# 9. 返回后端目录
cd ../backend

# 10. 拉取镜像
docker compose pull

# 11. 启动服务
docker compose up -d

# 12. 查看状态
docker compose ps

# 13. 查看日志
docker compose logs -f
```

### 5.2 使用部署脚本

```bash
# 进入脚本目录
cd /var/www/lumenim/backend

# 初始化并启动 (自动配置)
chmod +x docker-deploy.sh
sudo ./docker-deploy.sh --init

# 查看服务状态
sudo ./docker-deploy.sh --status

# 查看日志
sudo ./docker-deploy.sh --logs-follow

# 重启服务
sudo ./docker-deploy.sh --restart

# 停止服务
sudo ./docker-deploy.sh --stop
```

---

## 六、原生部署 (备选方式)

### 6.1 系统依赖安装

```bash
# 更新系统
sudo apt update && sudo apt upgrade -y

# 安装基础依赖
sudo apt install -y \
    curl wget git vim htop net-tools \
    ca-certificates gnupg lsb-release \
    build-essential gcc make pkg-config \
    libssl-dev nginx
```

### 6.2 Go 安装

```bash
# 下载 Go 1.25.0
wget https://go.dev/dl/go1.25.0.linux-amd64.tar.gz
sudo rm -rf /usr/local/go
sudo tar -C /usr/local -xzf go1.25.0.linux-amd64.tar.gz

# 配置环境变量
echo 'export PATH=$PATH:/usr/local/go/bin' >> ~/.bashrc
echo 'export GOPROXY=https://goproxy.cn,direct' >> ~/.bashrc
source ~/.bashrc

go version
```

### 6.3 Node.js 安装

```bash
# 使用 NodeSource 安装
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
sudo apt install -y nodejs

# 安装 pnpm
sudo npm install -g pnpm@10.0.0

node -v
pnpm -v
```

### 6.4 MySQL 8.0 安装

```bash
# 安装 MySQL
sudo apt install -y mysql-server

# 启动并配置
sudo systemctl start mysql
sudo systemctl enable mysql
sudo mysql_secure_installation

# 创建数据库
sudo mysql <<EOF
CREATE DATABASE go_chat CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER 'lumenim'@'%' IDENTIFIED BY 'lumenim_password';
GRANT ALL PRIVILEGES ON go_chat.* TO 'lumenim'@'%';
FLUSH PRIVILEGES;
EOF
```

### 6.5 Redis 安装

```bash
# 安装 Redis
sudo apt install -y redis-server

# 配置
sudo tee /etc/redis/redis.conf <<EOF
requirepass redis_password
maxmemory 512mb
maxmemory-policy allkeys-lru
appendonly yes
bind 0.0.0.0
EOF

# 启动
sudo systemctl restart redis-server
```

### 6.6 MinIO 安装

```bash
# 下载并安装
wget https://dl.min.io/server/minio/release/linux-amd64/minio
chmod +x minio
sudo mv minio /usr/local/bin/

# 创建用户和目录
sudo useradd -r minio-user -s /sbin/nologin
sudo mkdir -p /data/minio
sudo chown minio-user:minio-user /data/minio

# 创建 systemd 服务
sudo tee /etc/systemd/system/minio.service <<EOF
[Unit]
Description=MinIO

[Service]
User=minio-user
ExecStart=/usr/local/bin/minio server /data/minio --console-address ":9090"
Restart=always

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl start minio
sudo systemctl enable minio
```

---

## 七、服务管理命令

### 7.1 Docker 服务管理

```bash
# 启动所有服务
docker compose up -d

# 停止所有服务
docker compose down

# 重启所有服务
docker compose restart

# 查看服务状态
docker compose ps

# 查看日志
docker compose logs -f

# 查看特定服务日志
docker compose logs -f lumenim_http
docker compose logs -f lumenim_comet

# 重新构建并启动
docker compose up -d --build

# 清理未使用的镜像和容器
docker system prune -f
```

### 7.2 原生服务管理

```bash
# MySQL
sudo systemctl start mysql
sudo systemctl stop mysql
sudo systemctl restart mysql
sudo systemctl status mysql

# Redis
sudo systemctl start redis-server
sudo systemctl stop redis-server
sudo systemctl restart redis-server

# MinIO
sudo systemctl start minio
sudo systemctl stop minio
sudo systemctl restart minio

# Nginx
sudo systemctl start nginx
sudo systemctl stop nginx
sudo systemctl restart nginx

# LumenIM 后端
sudo systemctl start lumenim-backend
sudo systemctl stop lumenim-backend
sudo systemctl restart lumenim-backend
sudo journalctl -u lumenim-backend -f
```

---

## 八、常见问题排查

### 8.1 Docker 相关问题

#### 问题 1: Docker 权限错误

```bash
# 错误: permission denied while trying to connect to the Docker daemon
# 解决: 当前用户加入 docker 组
sudo usermod -aG docker $USER
newgrp docker

# 或使用 sudo 运行
sudo docker compose up -d
```

#### 问题 2: 端口占用

```bash
# 错误: ports are not available
# 解决: 检查并释放端口
sudo netstat -tlnp | grep -E "80|443|3306|6379|9000|9501|9502"

# 杀死占用进程
sudo kill -9 <PID>
```

#### 问题 3: 镜像拉取失败

```bash
# 错误: image pull failure
# 解决: 配置镜像加速器
sudo mkdir -p /etc/docker
sudo tee /etc/docker/daemon.json <<EOF
{
  "registry-mirrors": [
    "https://docker.1ms.run",
    "https://docker.m.daocloud.io"
  ]
}
EOF

sudo systemctl restart docker
```

#### 问题 4: 数据卷权限问题

```bash
# 错误: permission denied on volume
# 解决: 修改目录权限
sudo chown -R 1000:1000 /var/www/lumenim/data
sudo chmod -R 755 /var/www/lumenim/data
```

### 8.2 数据库相关问题

#### 问题 5: MySQL 连接失败

```bash
# 检查 MySQL 容器状态
docker compose ps mysql
docker compose logs mysql

# 进入 MySQL 容器测试
docker exec -it lumenim-mysql mysql -uroot -p

# 检查网络连通性
docker exec lumenim-http ping mysql
```

#### 问题 6: Redis 连接失败

```bash
# 检查 Redis 状态
docker compose ps redis
docker exec -it lumenim-redis redis-cli -a redis_password ping

# 检查配置
docker exec lumenim-http ping redis
```

### 8.3 服务相关问题

#### 问题 7: WebSocket 连接失败

```bash
# 检查 WebSocket 服务状态
docker compose ps lumenim_comet
docker compose logs lumenim_comet

# 测试 WebSocket 端口
telnet localhost 9502

# 检查 Nginx WebSocket 配置
grep -A 10 "ws/" nginx.conf
```

#### 问题 8: 前端页面空白

```bash
# 检查 Nginx 容器状态
docker compose ps nginx
docker compose logs nginx

# 检查前端文件是否存在
docker exec lumenim-nginx ls -la /usr/share/nginx/html/

# 检查 Nginx 配置语法
docker exec lumenim-nginx nginx -t
```

#### 问题 9: 文件上传失败

```bash
# 检查 MinIO 服务状态
docker compose ps minio
docker compose logs minio

# 检查上传目录权限
ls -la uploads/

# 测试 MinIO 连接
docker exec lumenim-minio mc ls local/
```

### 8.4 网络相关问题

#### 问题 10: 容器间通信失败

```bash
# 检查 Docker 网络
docker network ls
docker network inspect lumenim-network

# 重建网络
docker compose down
docker network rm lumenim-network
docker compose up -d
```

#### 问题 11: 外部无法访问

```bash
# 检查防火墙
sudo ufw status

# 开放必要端口
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw reload

# 检查端口监听
sudo netstat -tlnp | grep -E "80|443"
```

---

## 九、性能优化建议

### 9.1 Docker 资源限制

```yaml
# docker-compose.yaml 中添加资源限制
services:
  mysql:
    deploy:
      resources:
        limits:
          memory: 2G
        reservations:
          memory: 512M

  redis:
    deploy:
      resources:
        limits:
          memory: 1G

  lumenim_http:
    deploy:
      replicas: 2  # 增加副本数
      resources:
        limits:
          memory: 1G
```

### 9.2 MySQL 优化

```yaml
# docker-compose.yaml MySQL 配置
command: >
  --innodb_buffer_pool_size=1G
  --max_connections=500
  --innodb_log_file_size=256M
  --innodb_flush_log_at_trx_commit=2
  --slow_query_log=1
  --long_query_time=1
```

### 9.3 Redis 优化

```conf
# redis.conf
maxmemory 1gb
maxmemory-policy allkeys-lru
tcp-backlog 511
timeout 0
tcp-keepalive 300
```

### 9.4 Nginx 优化

```nginx
# nginx.conf
worker_processes auto;
worker_connections 4096;
multi_accept on;
use epoll;

http {
    # Gzip 压缩
    gzip on;
    gzip_comp_level 6;
    gzip_types text/plain text/css application/json application/javascript;
    
    # 缓存配置
    proxy_buffering on;
    proxy_buffer_size 4k;
    proxy_buffers 8 4k;
    
    # 连接复用
    proxy_http_version 1.1;
    proxy_set_header Connection "";
}
```

### 9.5 监控建议

```bash
# 安装监控工具
docker stats                           # 实时资源监控

# 查看容器资源使用
docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}"

# 查看磁盘使用
docker system df

# 查看日志大小
docker logs -f lumenim-http --tail=0 --since 24h | wc -l
```

---

## 十、安全加固建议

### 10.1 密码强度

```bash
# MySQL 密码: 至少 16 位，包含大小写字母、数字、特殊字符
# Redis 密码: 至少 32 位随机字符串
# MinIO 密码: 至少 16 位，包含大小写字母、数字

# 生成强密码
openssl rand -base64 32
```

### 10.2 防火墙配置

```bash
# 只开放必要端口
sudo ufw default deny incoming
sudo ufw default allow outgoing

sudo ufw allow 22/tcp    # SSH
sudo ufw allow 80/tcp    # HTTP
sudo ufw allow 443/tcp   # HTTPS

sudo ufw enable
sudo ufw status
```

### 10.3 文件权限

```bash
# 配置文件权限
chmod 600 /var/www/lumenim/backend/config.yaml
chmod 600 /var/www/lumenim/backend/.env
chmod 600 /var/www/lumenim/backend/ssl/*.pem

# 数据目录权限
chown -R 1000:1000 /var/www/lumenim/data
chmod -R 755 /var/www/lumenim/data
```

### 10.4 定期更新

```bash
# 更新 Docker 镜像
docker compose pull
docker compose up -d

# 更新系统
sudo apt update && sudo apt upgrade -y
```

---

## 十一、备份与恢复

### 11.1 数据备份

```bash
# 备份 MySQL 数据库
docker exec lumenim-mysql mysqldump -uroot -plumenim123 go_chat > backup_$(date +%Y%m%d).sql

# 备份 MinIO 数据
docker exec lumenim-minio mc mirror local/im-static /backup/im-static-$(date +%Y%m%d)
docker exec lumenim-minio mc mirror local/im-private /backup/im-private-$(date +%Y%m%d)

# 备份配置文件
tar czf lumenim-config-$(date +%Y%m%d).tar.gz config.yaml .env nginx.conf
```

### 11.2 数据恢复

```bash
# 恢复 MySQL 数据库
docker exec -i lumenim-mysql mysql -uroot -plumenim123 go_chat < backup_20260410.sql

# 恢复 MinIO 数据
docker exec lumenim-minio mc mirror /backup/im-static-20260410 local/im-static
```

---

## 十二、快速命令参考

```bash
# ==================== 一键部署 ====================
cd /var/www/lumenim/backend && docker compose up -d

# ==================== 服务管理 ====================
docker compose ps                      # 查看状态
docker compose logs -f                 # 查看日志
docker compose restart                 # 重启服务
docker compose down                    # 停止服务

# ==================== 健康检查 ====================
curl http://localhost/api/v1/health   # API 健康检查
curl http://localhost/health           # Nginx 健康检查

# ==================== 日志查看 ====================
docker compose logs -f lumenim_http    # HTTP 日志
docker compose logs -f lumenim_comet  # WebSocket 日志
docker compose logs -f mysql           # MySQL 日志

# ==================== 清理 ====================
docker system prune -f                 # 清理未使用资源
docker compose down -v                # 停止并删除数据卷
```

---

## 二十二、部署包打包工具

> 使用自动化脚本快速打包前后端部署文件。

### 22.1 打包脚本位置

```
software/scripts/deploy-package/
├── build-all.sh/.ps1         # 一键打包完整部署包
├── build-frontend.sh/.ps1     # 打包前端部署包
├── build-backend.sh/.ps1      # 打包后端部署包
├── deploy-ubuntu.sh/.ps1      # Ubuntu 一键打包部署包 (推荐)
│
├── front/                    # 前端部署目录
│   ├── dist/                # 前端构建产物
│   └── config/              # 配置文件
│
├── backend/                  # 后端部署目录
│   ├── lumenim             # 可执行文件
│   ├── sql/                # 数据库脚本
│   ├── uploads/            # 上传目录
│   ├── runtime/            # 运行时目录
│   └── config/            # 配置文件
│
├── docker/                  # Docker 配置
├── DEPLOY_PACKAGE_GUIDE.md  # 详细部署指南
└── README.md               # 快速开始指南
```


### 22.2 使用方法

**Windows (PowerShell) - 推荐**
```powershell
cd software/scripts/deploy-package
.\deploy-ubuntu.ps1
```

**Linux/Mac**
```bash
cd software/scripts/deploy-package
bash deploy-ubuntu.sh
```

**旧脚本（仍然可用）**
```powershell
.\build-all.ps1    # Windows PowerShell
bash build-all.sh  # Linux/Mac
```

### 22.3 Ubuntu 一键打包脚本 (deploy-ubuntu.sh/ps1)

功能特性：
- 自动构建前端（pnpm build）
- 自动编译后端（Linux amd64）
- 生成 tar.gz 格式部署包
- 包含所有配置文件模板
- 生成 systemd 服务文件
- 生成 Nginx 配置
- 生成部署脚本

输出文件：`output/lumenim-ubuntu-TIMESTAMP.tar.gz`

### 22.4 部署到 Ubuntu 服务器

```bash
# 1. 上传到服务器
scp lumenim-ubuntu-TIMESTAMP.tar.gz root@192.168.23.131:/opt/

# 2. 解压部署
ssh root@192.168.23.131
cd /opt
tar -xzvf lumenim-ubuntu-TIMESTAMP.tar.gz
cd lumenim-ubuntu
bash deploy.sh

# 3. 配置并启动
vim /opt/lumenim/backend/config/config.yaml
systemctl start lumenim-http
systemctl status lumenim-http
```


### 22.3 详细文档

详细的部署流程请参考：[DEPLOY_PACKAGE_GUIDE.md](./deploy-package/DEPLOY_PACKAGE_GUIDE.md)

---

**文档结束**

*最后更新: 2026-04-10*
*版本: 4.0.0*
