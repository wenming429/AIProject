# LumenIM Ubuntu 20.04 部署指南

**文档版本**: 5.0.0
**更新日期**: 2026-04-21
**适用系统**: Ubuntu 20.04 LTS / 22.04 LTS
**目标服务器**: 192.168.23.131
**部署方式**: Docker Compose (推荐) / 原生部署

---

## 一、服务器信息

| 配置项 | 值 |
|--------|-----|
| 服务器 IP | **192.168.23.131** |
| SSH 端口 | 22 |
| 部署用户 | wenming429 |
| 代码仓库 | https://github.com/wenming429/AIProject.git |
| 安装目录 | /opt/lumenim |
| 项目目录 | /var/www/lumenim |
| 数据目录 | /var/lib/lumenim |

---

## 二、系统架构

### 2.1 Docker 部署架构

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

### 2.2 服务端口映射

| 服务 | 容器端口 | 宿主机绑定 | 协议 | 外部访问 | 说明 |
|------|----------|-----------|------|----------|------|
| Nginx | 80 | 192.168.23.131:80 | HTTP | ✅ | 前端入口 |
| Nginx | 443 | 192.168.23.131:443 | HTTPS | ✅ | HTTPS |
| MySQL | 3306 | 127.0.0.1:3306 | TCP | ❌ | 仅本地 |
| Redis | 6379 | 127.0.0.1:6379 | TCP | ❌ | 仅本地 |
| MinIO API | 9000 | 192.168.23.131:9000 | HTTP | ✅ | 对象存储 |
| MinIO Console | 9090 | 192.168.23.131:9090 | HTTP | ✅ | 管理界面 |
| LumenIM HTTP | 9501 | 9501 (内部) | HTTP | ❌ | 通过 Nginx |
| LumenIM WebSocket | 9502 | 9502 (内部) | TCP | ❌ | 通过 Nginx |

---

## 三、环境要求

### 3.1 硬件配置

| 项目 | 最低要求 | 推荐配置 |
|------|----------|----------|
| 系统 | Ubuntu 20.04 LTS | Ubuntu 22.04 LTS |
| CPU | 2 核 | 4 核+ |
| 内存 | 4 GB | 8 GB+ |
| 磁盘 | 30 GB | 50 GB+ SSD |
| 网络 | 带宽 5 Mbps | 带宽 10 Mbps+ |

### 3.2 部署规模推荐

| 部署规模 | 用户数 | CPU | 内存 | 磁盘 | 适用场景 |
|---------|--------|-----|------|------|----------|
| 入门版 | ≤50人 | 2核 | 4GB | 50GB | 小团队/测试环境 |
| 标准版 | 50-200人 | 4核 | 8GB | 100GB | 中型企业 |
| 企业版 | 200-1000人 | 8核 | 16GB | 200GB | 大型企业 |
| 旗舰版 | 1000+人 | 16核 | 32GB | 500GB | 超大规模部署 |

---

## 四、自动化部署（一键安装）

### 4.1 快速开始

```bash
# 方式一：直接下载并执行脚本
curl -fsSL https://raw.githubusercontent.com/wenming429/AIProject/main/scripts/install-ubuntu20.sh -o /tmp/install-ubuntu20.sh
chmod +x /tmp/install-ubuntu20.sh
sudo /tmp/install-ubuntu20.sh --all

# 方式二：克隆项目后执行
git clone https://github.com/wenming429/AIProject.git /opt/lumenim
cd /opt/lumenim/software/scripts
chmod +x install-ubuntu20.sh
sudo ./install-ubuntu20.sh --all
```

### 4.2 脚本选项说明

```bash
sudo ./install-ubuntu20.sh [选项]

选项:
  -h, --help              显示帮助信息
  -c, --check            仅检查环境
  -d, --deps             安装系统依赖
  -r, --runtime          安装运行时环境 (Go, Node.js)
  -m, --mysql            安装 MySQL
  -e, --redis            安装 Redis
  -p, --protobuf         安装 Protocol Buffers
  -b, --backend          构建后端
  -f, --frontend         安装前端依赖
  -k, --database         配置并初始化数据库
  -g, --config           配置服务
  -s, --start            启动服务
  -a, --all              完整安装（推荐）
  --clone                克隆代码仓库
  --firewall             配置防火墙
  --docker               安装 Docker
  --docker-compose       安装 Docker Compose
```

### 4.3 完整部署流程

```bash
# 1. 环境检查
sudo ./install-ubuntu20.sh --check

# 2. 安装系统依赖
sudo ./install-ubuntu20.sh --deps

# 3. 安装 Docker（如需要）
sudo ./install-ubuntu20.sh --docker --docker-compose

# 4. 安装运行时环境
sudo ./install-ubuntu20.sh --runtime

# 5. 安装数据库
sudo ./install-ubuntu20.sh --mysql --redis

# 6. 克隆代码并配置
sudo ./install-ubuntu20.sh --clone --config

# 7. 初始化数据库
sudo ./install-ubuntu20.sh --database

# 8. 构建应用
sudo ./install-ubuntu20.sh --backend --frontend

# 9. 启动服务
sudo ./install-ubuntu20.sh --start

# 10. 配置防火墙
sudo ./install-ubuntu20.sh --firewall

# 或一键完整安装
sudo ./install-ubuntu20.sh --all
```

---

## 五、Docker 安装与配置

### 5.1 卸载旧版本

```bash
# 卸载旧版本 Docker (如果存在)
sudo apt remove docker docker-engine docker.io containerd runc

# 清理残留
sudo apt autoremove --purge docker docker-engine docker.io containerd runc

# 确认已卸载
sudo apt-cache policy docker.io
```

### 5.2 安装 Docker

#### 方式一：使用官方仓库安装 (推荐)

```bash
# 1. 更新软件包索引
sudo apt update
sudo apt install -y ca-certificates curl gnupg lsb-release

# 2. 添加 Docker GPG 密钥
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

# 3. 设置 Docker 仓库
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
# 添加阿里云 Docker 镜像源
curl -fsSL https://mirrors.aliyun.com/docker-ce/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://mirrors.aliyun.com/docker-ce/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list

# 安装 Docker
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
```

#### 方式三：一键安装脚本

```bash
# 使用官方安装脚本
curl -fsSL https://get.docker.com | sh -s -- --mirror Aliyun
```

### 5.3 配置 Docker 镜像加速

```bash
# 创建 Docker 配置目录
sudo mkdir -p /etc/docker

# 配置镜像加速器
sudo tee /etc/docker/daemon.json <<'EOF'
{
  "registry-mirrors": [
    "https://docker.1ms.run",
    "https://docker.xuanyuan.me",
    "https://docker.m.daocloud.io",
    "https://docker.mirrors.ustc.edu.cn",
    "https://hub-mirror.c.163.com"
  ],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m",
    "max-file": "5"
  },
  "storage-driver": "overlay2",
  "live-restore": true,
  "default-address-pools": [
    {
      "base": "172.17.0.0/16",
      "size": 24
    }
  ],
  "dns": ["8.8.8.8", "114.114.114.114"]
}
EOF

# 重启 Docker 服务
sudo systemctl daemon-reload
sudo systemctl restart docker
sudo systemctl enable docker

# 验证配置
docker info | grep -A 10 "Registry Mirrors"
```

### 5.4 Docker 服务配置

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

---

## 六、Docker Compose 部署

### 6.1 端口绑定配置 (192.168.23.131)

针对服务器 IP `192.168.23.131`，使用以下 `docker-compose.yaml` 配置：

```yaml
# docker-compose.yaml - LumenIM Docker Compose 配置
# 服务器 IP: 192.168.23.131
# 
# 使用方法:
#   1. 编辑 .env 文件配置数据库密码
#   2. 编辑 config.yaml 后端配置
#   3. docker compose up -d

version: '3.8'

services:
  # ==================== MySQL 数据库 ====================
  mysql:
    image: mysql:8.0
    container_name: lumenim-mysql
    restart: always
    ports:
      - "127.0.0.1:3306:3306"    # 仅本地访问
    environment:
      MYSQL_ROOT_PASSWORD: ${MYSQL_ROOT_PASSWORD:-lumenim123}
      MYSQL_DATABASE: ${MYSQL_DATABASE:-go_chat}
      MYSQL_USER: ${MYSQL_USER:-lumenim}
      MYSQL_PASSWORD: ${MYSQL_PASSWORD:-lumenim123}
      TZ: Asia/Shanghai
    volumes:
      - mysql_data:/var/lib/mysql
      - ./sql:/docker-entrypoint-initdb.d:ro
    command: >
      --default-authentication-plugin=mysql_native_password
      --character-set-server=utf8mb4
      --collation-server=utf8mb4_unicode_ci
      --max_connections=1000
      --innodb_buffer_pool_size=512M
      --default-time-zone='+08:00'
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

  # ==================== Redis 缓存 ====================
  redis:
    image: redis:7.4-alpine
    container_name: lumenim-redis
    restart: always
    ports:
      - "127.0.0.1:6379:6379"    # 仅本地访问
    volumes:
      - redis_data:/data
    command: redis-server --appendonly yes --bind 0.0.0.0
    networks:
      - lumenim-network
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
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
      - "192.168.23.131:9000:9000"    # API 端口 - 绑定到指定 IP
      - "192.168.23.131:9090:9090"    # Console 端口 - 绑定到指定 IP
    environment:
      MINIO_ROOT_USER: ${MINIO_ROOT_USER:-minioadmin}
      MINIO_ROOT_PASSWORD: ${MINIO_ROOT_PASSWORD:-minioadmin123}
    volumes:
      - minio_data:/data
    command: server /data --console-address ":9090"
    networks:
      - lumenim-network
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:9000/minio/health/live"]
      interval: 30s
      timeout: 20s
      retries: 3
    deploy:
      resources:
        limits:
          memory: 2G

  # ==================== Nginx 反向代理 ====================
  nginx:
    image: nginx:alpine
    container_name: lumenim-nginx
    restart: always
    ports:
      - "192.168.23.131:80:80"       # HTTP - 绑定到指定 IP
      - "192.168.23.131:443:443"     # HTTPS - 绑定到指定 IP
    volumes:
      - ./nginx.conf:/etc/nginx/conf.d/default.conf:ro
      - ../front/dist:/usr/share/nginx/html:ro
      - nginx_logs:/var/log/nginx
    depends_on:
      lumenim_http:
        condition: service_healthy
    networks:
      - lumenim-network
    healthcheck:
      test: ["CMD", "wget", "-q", "--spider", "http://localhost/health"]
      interval: 30s
      timeout: 10s
      retries: 3

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
        condition: service_started
    restart: always
    volumes:
      - ./config.yaml:/work/config.yaml:ro
      - uploads:/work/uploads:rw
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

  # ==================== LumenIM WebSocket ====================
  lumenim_comet:
    image: gzydong/lumenim:latest
    container_name: lumenim-comet
    depends_on:
      mysql:
        condition: service_healthy
      redis:
        condition: service_healthy
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
        condition: service_started
    restart: always
    volumes:
      - ./config.yaml:/work/config.yaml:ro
      - uploads:/work/uploads:rw
      - runtime:/work/runtime:rw
    command: queue --config=/work/config.yaml
    networks:
      - lumenim-network

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
  redis_data:
  minio_data:
  nginx_logs:
  uploads:
  runtime:
```

### 6.2 .env 环境变量文件

```bash
# .env 文件 - LumenIM Docker Compose 环境变量
# 服务器 IP: 192.168.23.131

# ==================== 项目配置 ====================
COMPOSE_PROJECT_NAME=lumenim
SERVER_IP=192.168.23.131

# ==================== 数据库配置 ====================
MYSQL_ROOT_PASSWORD=lumenim123
MYSQL_DATABASE=go_chat
MYSQL_USER=lumenim
MYSQL_PASSWORD=lumenim123

# ==================== Redis 配置 ====================
REDIS_PASSWORD=
REDIS_PORT=6379

# ==================== MinIO 配置 ====================
MINIO_ROOT_USER=minioadmin
MINIO_ROOT_PASSWORD=minioadmin123

# ==================== Nginx 配置 ====================
NGINX_HTTP_PORT=80
NGINX_HTTPS_PORT=443

# ==================== 时区配置 ====================
TZ=Asia/Shanghai
```

### 6.3 Nginx 配置文件

```nginx
# nginx.conf - LumenIM Nginx 配置
# 服务器 IP: 192.168.23.131

server {
    listen 80;
    server_name 192.168.23.131;

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

---

## 七、后端配置 (config.yaml)

针对 Docker 部署，`config.yaml` 需要使用容器服务名而非 `localhost`：

```yaml
# config.yaml - LumenIM 后端配置
# 服务器 IP: 192.168.23.131

app:
  env: prod
  debug: false
  admin_email:
    - admin@example.com
  public_key: |
    -----BEGIN PUBLIC KEY-----
    ... (保持不变) ...
    -----END PUBLIC KEY-----
  private_key: |
    -----BEGIN PRIVATE KEY-----
    ... (保持不变) ...
    -----END PRIVATE KEY-----
  aes_key: "BLHPzm3Urx5t9DTA"

server:
  http_addr: ":9501"
  websocket_addr: ":9502"
  tcp_addr: ":9505"

log:
  path: "./runtime"

# Redis 配置 - 使用 Docker 服务名
redis:
  host: lumenim-redis:6379
  auth:
  database: 0

# MySQL 配置 - 使用 Docker 服务名
mysql:
  host: lumenim-mysql
  port: 3306
  charset: utf8mb4
  username: root
  password: lumenim123
  database: go_chat
  collation: utf8mb4_unicode_ci

jwt:
  secret: 836c3fea9bba4e04d51bd0fbcc5
  expires_time: 3600
  buffer_time: 3600

cors:
  origin: "*"
  headers: "Content-Type,Cache-Control,User-Agent,Keep-Alive,DNT,AccessToken,Authorization"
  methods: "OPTIONS,GET,POST,PUT,DELETE"
  credentials: false
  max_age: 600

filesystem:
  default: minio
  local:
    root: "/work/"
    bucket_public: "public"
    bucket_private: "private"
    endpoint: "192.168.23.131:9000"
    ssl: false
  minio:
    secret_id: "minioadmin"
    secret_key: "minioadmin123"
    bucket_public: "im-static"
    bucket_private: "im-private"
    endpoint: "192.168.23.131:9000"
    ssl: false

email:
  host: smtp.163.com
  port: 465
  username:
  password:
  fromname: "Lumen IM"

oauth:
  github:
    client_id: ""
    client_secret: ""
    redirect_uri: "http://192.168.23.131/oauth/callback/github"
  gitee:
    client_id: ""
    client_secret: ""
    redirect_uri: "http://192.168.23.131/oauth/callback/gitee"
```

---

## 八、防火墙配置

### 8.1 UFW 防火墙配置

```bash
# 检查 UFW 状态
sudo ufw status verbose

# 添加规则（SSH 必须第一！）
sudo ufw allow 22/tcp comment 'SSH'

# HTTP/HTTPS
sudo ufw allow 80/tcp comment 'HTTP'
sudo ufw allow 443/tcp comment 'HTTPS'

# LumenIM 服务端口
sudo ufw allow 9000/tcp comment 'MinIO API'
sudo ufw allow 9090/tcp comment 'MinIO Console'

# 设置默认策略
sudo ufw default deny incoming
sudo ufw default allow outgoing

# 启用防火墙
echo "y" | sudo ufw enable

# 验证配置
sudo ufw status numbered
```

### 8.2 防火墙规则说明

| 端口 | 协议 | 说明 | 外部访问 |
|------|------|------|----------|
| 22 | TCP | SSH | ✅ 仅限管理 |
| 80 | TCP | HTTP | ✅ 开放 |
| 443 | TCP | HTTPS | ✅ 开放 |
| 9000 | TCP | MinIO API | ✅ 开放 |
| 9090 | TCP | MinIO Console | ✅ 开放 |
| 3306 | TCP | MySQL | ❌ 禁止 |
| 6379 | TCP | Redis | ❌ 禁止 |

---

## 九、服务管理

### 9.1 Docker Compose 服务管理

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

# 清理未使用的资源
docker system prune -f
```

### 9.2 原生服务管理 (systemd)

```bash
# 启动服务
sudo systemctl start lumenim-backend
sudo systemctl start lumenim-frontend

# 停止服务
sudo systemctl stop lumenim-backend
sudo systemctl stop lumenim-frontend

# 重启服务
sudo systemctl restart lumenim-backend

# 查看状态
sudo systemctl status lumenim-backend

# 查看日志
sudo journalctl -u lumenim-backend -f
sudo journalctl -u lumenim-frontend -f

# 开机自启
sudo systemctl enable lumenim-backend
sudo systemctl enable lumenim-frontend
```

---

## 十、常见问题排查

### 10.1 Docker 相关问题

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
# 检查端口占用
sudo netstat -tlnp | grep -E "80|443|3306|6379|9000|9501|9502"

# 杀死占用进程
sudo kill -9 <PID>
```

#### 问题 3: 镜像拉取失败

```bash
# 检查网络连接
curl -I https://registry-1.docker.io

# 重新配置镜像加速器
sudo tee /etc/docker/daemon.json <<'EOF'
{
  "registry-mirrors": [
    "https://docker.1ms.run",
    "https://docker.m.daocloud.io"
  ]
}
EOF

sudo systemctl restart docker
```

### 10.2 数据库相关问题

#### 问题 4: MySQL 连接失败

```bash
# 检查 MySQL 容器状态
docker compose ps mysql
docker compose logs mysql

# 进入 MySQL 容器测试
docker exec -it lumenim-mysql mysql -uroot -p

# 检查网络连通性
docker exec lumenim-http ping lumenim-mysql
```

#### 问题 5: Redis 连接失败

```bash
# 检查 Redis 状态
docker compose ps redis
docker exec -it lumenim-redis redis-cli ping

# 检查配置
docker exec lumenim-http ping lumenim-redis
```

### 10.3 服务相关问题

#### 问题 6: WebSocket 连接失败

```bash
# 检查 WebSocket 服务状态
docker compose ps lumenim_comet
docker compose logs lumenim_comet

# 测试 WebSocket 端口
telnet localhost 9502
```

#### 问题 7: 前端页面空白

```bash
# 检查 Nginx 容器状态
docker compose ps nginx
docker compose logs nginx

# 检查前端文件是否存在
docker exec lumenim-nginx ls -la /usr/share/nginx/html/
```

---

## 十一、性能优化

### 11.1 Docker 资源限制

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
```

### 11.2 MySQL 优化

```yaml
command: >
  --innodb_buffer_pool_size=1G
  --max_connections=500
  --innodb_log_file_size=256M
  --slow_query_log=1
  --long_query_time=1
```

### 11.3 Nginx 优化

```nginx
worker_processes auto;
worker_connections 4096;
multi_accept on;

http {
    gzip on;
    gzip_comp_level 6;
    gzip_types text/plain text/css application/json application/javascript;
}
```

---

## 十二、安全加固

### 12.1 密码强度

```bash
# 生成强密码
openssl rand -base64 32

# MySQL 密码: 至少 16 位
# Redis 密码: 至少 32 位随机字符串
# MinIO 密码: 至少 16 位
```

### 12.2 文件权限

```bash
# 配置文件权限
chmod 600 config.yaml
chmod 600 .env

# 数据目录权限
chown -R 1000:1000 data/
```

---

## 十三、备份与恢复

### 13.1 数据备份

```bash
# 备份 MySQL 数据库
docker exec lumenim-mysql mysqldump -uroot -plumenim123 go_chat > backup_$(date +%Y%m%d).sql

# 备份配置文件
tar czf lumenim-config-$(date +%Y%m%d).tar.gz config.yaml .env nginx.conf
```

### 13.2 数据恢复

```bash
# 恢复 MySQL 数据库
docker exec -i lumenim-mysql mysql -uroot -plumenim123 go_chat < backup_20260421.sql
```

---

## 十四、访问信息

| 服务 | 地址 |
|------|------|
| 前端 | http://192.168.23.131 |
| 后端 API | http://192.168.23.131/api/v1 |
| WebSocket | ws://192.168.23.131/ws/ |
| MinIO API | http://192.168.23.131:9000 |
| MinIO Console | http://192.168.23.131:9090 |

---

**文档结束**

*最后更新: 2026-04-21*
*版本: 5.0.0*
