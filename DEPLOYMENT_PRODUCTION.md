# Lumen IM 正式环境私有化部署指南

## 概述

本文档提供 Lumen IM 即时通讯系统生产环境私有化部署的完整指南。该系统采用前后端分离架构，后端使用 Go 语言开发，前端使用 Vue3 + TypeScript 构建，支持私聊、群聊、文件传输、笔记等功能。

## 系统要求

### 硬件配置

| 配置级别 | 适用场景 | CPU | 内存 | 磁盘 |
|---------|---------|-----|------|------|
| 入门配置 | 小规模部署（50人以下） | 2核 | 4GB | 50GB |
| 标准配置 | 中等规模（50-200人） | 4核 | 8GB | 100GB |
| 企业配置 | 大规模部署（200+人） | 8核 | 16GB | 200GB |

### 软件依赖

**服务端软件版本要求：**

- **操作系统**：Ubuntu 20.04+ / CentOS 7+ / Debian 10+
- **Docker**：20.10+
- **Docker Compose**：1.29+
- **MySQL**：8.0
- **Redis**：5.0+
- **MinIO**：latest

**开发环境（可选）：**

- **Go**：1.25+
- **Node.js**：18+
- **pnpm**：8+

## 部署架构

### 服务组件说明

Lumen IM 采用微服务架构设计，包含以下核心组件：

| 服务名称 | 端口 | 说明 | 资源需求 |
|---------|------|------|---------|
| mysql | 3306 | 数据库服务 | 视用户量 |
| redis | 6379 | 缓存与消息队列 | 512MB+ |
| minio | 9000/9090 | 对象存储服务 | 视文件量 |
| lumenim_http | 9501 | RESTful API 服务 | 256MB |
| lumenim_comet | 9502 | WebSocket 长连接服务 | 512MB |
| lumenim_queue | - | 异步消息队列服务 | 256MB |
| lumenim_cron | - | 定时任务服务 | 128MB |

### 网络拓扑

```
                    ┌─────────────────┐
                    │   Nginx         │
                    │   (反向代理)      │
                    │   80/443        │
                    └────────┬────────┘
                             │
          ┌───────────────────┼───────────────────┐
          │                   │                   │
    ┌─────▼─────┐     ┌──────▼──────┐    ┌──────▼──────┐
    │   前端     │     │  HTTP API   │    │  WebSocket   │
    │  (静态)    │     │   9501      │    │    9502      │
    └───────────┘     └──────┬──────┘    └──────┬──────┘
                             │                   │
                    ┌────────┴───────────────────┴────────┐
                    │           Docker Network              │
                    │           lumenim-network             │
                    └────────┬────────┬────────┬───────────┘
                             │        │        │
                    ┌───────▼──┐ ┌───▼───┐ ┌─▼───────┐
                    │   MySQL   │ │ Redis  │ │  MinIO  │
                    │   3306    │ │  6379  │ │  9000   │
                    └──────────┘ └────────┘ └─────────┘
```

## 部署前准备

### 域名与 SSL 证书

生产环境建议使用域名访问，提前准备好以下材料：

- 域名（如 im.yourcompany.com）
- SSL 证书（.pem 和 .key 文件）或使用 Let's Encrypt 自动签发

### 服务器环境检查

```bash
# 检查 Docker 版本
docker --version
docker-compose --version

# 检查端口占用
netstat -tuln | grep -E "3306|6379|9000|9090|9501|9502|80|443"

# 创建项目目录
mkdir -p /opt/lumenim
cd /opt/lumenim
```

## 部署步骤

### 第一步：下载项目代码

```bash
cd /opt/lumenim

# 克隆前端代码
git clone https://github.com/gzydong/LumenIM.git front

# 克隆后端代码
git clone https://github.com/gzydong/go-chat.git backend

# 克隆前端API（如果需要）
git clone https://github.com/gzydong/lumenim-api.git front
```

### 第二步：配置后端

#### 创建生产配置文件

```bash
cd /opt/lumenim/backend
cp config.example.yaml config.yaml
```

编辑 `config.yaml`，以下为生产环境推荐配置：

```yaml
# 项目配置信息
app:
  env: prod
  debug: false
  admin_email:
    - admin@yourcompany.com
  public_key: |
    -----BEGIN PUBLIC KEY-----
    # 请生成新的 2048 位 RSA 公钥
    MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCA...
    -----END PUBLIC KEY-----

  private_key: |
    -----BEGIN PRIVATE KEY-----
    # 请生成新的 2048 位 RSA 私钥
    MIIEvQIBADANBgkqhkiG9w0BAQEFAASCBKcwggSj...
    -----END PRIVATE KEY-----

  aes_key: "随机32位字符串"
  # 生成方式：openssl rand -base64 24

server:
  http_addr: ":9501"
  websocket_addr: ":9502"
  tcp_addr: ":9505"

# 日志配置
log:
  path: "/opt/lumenim/runtime"

# Redis 配置
redis:
  host: redis:6379
  auth: "your-redis-password"
  database: 0

# MySQL 配置
mysql:
  host: mysql:3306
  port: 3306
  charset: utf8mb4
  username: root
  password: "your-mysql-root-password"
  database: go_chat
  collation: utf8mb4_general_ci

# JWT 配置
jwt:
  secret: "随机JWT密钥-至少32位"
  expires_time: 86400
  buffer_time: 86400

# 跨域配置
cors:
  origin: "https://im.yourcompany.com"
  headers: "Content-Type,Cache-Control,User-Agent,Keep-Alive,DNT,AccessToken,Authorization"
  methods: "OPTIONS,GET,POST,PUT,DELETE"
  credentials: true
  max_age: 600

# 文件系统配置
filesystem:
  default: minio
  local:
    root: "/opt/lumenim/uploads"
    bucket_public: "public"
    bucket_private: "private"
    endpoint: "minio:9000"
    ssl: false
  minio:
    secret_id: "minioadmin"
    secret_key: "minioadmin-password"
    bucket_public: "im-static"
    bucket_private: "im-private"
    endpoint: "minio:9000"
    ssl: false

# 邮件配置（可选）
email:
  host: smtp.ym.163.com
  port: 465
  username: noreply@yourcompany.com
  password: "smtp-password"
  fromname: "Lumen IM"
```

### 第三步：生成 RSA 密钥对

```bash
# 生成 2048 位 RSA 密钥对
openssl genrsa -out private_key.pem 2048
openssl rsa -in private_key.pem -pubout -out public_key.pem

# 查看公钥
cat public_key.pem

# 查看私钥
cat private_key.pem
```

将生成的公钥和私钥填入配置文件。

### 第四步：配置前端

```bash
cd /opt/lumenim/front
```

创建生产环境配置文件 `.env.production`：

```bash
# just a flag
ENV = 'production'

VITE_BASE=/
VITE_ROUTER_MODE=history

# API 地址（Docker 部署时使用容器内部地址）
VITE_BASE_API=http://your-domain.com/api
VITE_SOCKET_API=wss://your-domain.com/ws

# RSA 公钥（与后端配置一致）
VITE_RSA_PUBLIC_KEY="-----BEGIN PUBLIC KEY-----
MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCA...
-----END PUBLIC KEY-----"
```

### 第五步：构建前端

```bash
cd /opt/lumenim/front

# 安装依赖
pnpm install

# 构建生产版本
pnpm build
```

构建产物在 `dist` 目录中。

### 第六步：准备 Docker Compose 配置

在 `/opt/lumenim` 目录下创建或修改 `docker-compose.prod.yaml`：

```yaml
version: '3.6'

services:
  # MySQL 数据库
  mysql:
    image: mysql:8.0
    container_name: lumenim-mysql
    restart: always
    ports:
      - '3306:3306'
    environment:
      MYSQL_ROOT_PASSWORD: ${MYSQL_ROOT_PASSWORD:-root123456}
      MYSQL_DATABASE: go_chat
      TZ: Asia/Shanghai
    volumes:
      - mysql_data:/var/lib/mysql
      - ./backend/sql:/docker-entrypoint-initdb.d
    command: --default-authentication-plugin=mysql_native_password --character-set-server=utf8mb4 --collation-server=utf8mb4_unicode_ci
    networks:
      - lumenim-network

  # Redis 缓存
  redis:
    image: redis:5.0
    container_name: lumenim-redis
    restart: always
    ports:
      - '6379:6379'
    volumes:
      - redis_data:/data
      - ./redis.conf:/usr/local/etc/redis/redis.conf
    command: redis-server /usr/local/etc/redis/redis.conf
    networks:
      - lumenim-network

  # Minio 对象存储
  minio:
    image: minio/minio:latest
    container_name: lumenim-minio
    restart: always
    ports:
      - '9000:9000'
      - '9090:9090'
    environment:
      MINIO_ROOT_USER: ${MINIO_ROOT_USER:-minioadmin}
      MINIO_ROOT_PASSWORD: ${MINIO_ROOT_PASSWORD:-minioadmin123}
    volumes:
      - minio_data:/data
    command: server /data --console-address ":9090"
    networks:
      - lumenim-network

  # MinIO 初始化（首次部署时创建 bucket）
  minio-init:
    image: minio/mc:latest
    container_name: lumenim-minio-init
    depends_on:
      - minio
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

  # LumenIM HTTP 服务
  lumenim_http:
    image: gzydong/lumenim:latest
    container_name: lumenim-http
    depends_on:
      - mysql
      - redis
      - minio
    ports:
      - '9501:9501'
    restart: always
    volumes:
      - ./backend/config.yaml:/work/config.yaml
      - ./uploads:/work/uploads/:rw
      - ./runtime:/work/runtime
    command: http --config=/work/config.yaml
    networks:
      - lumenim-network

  # LumenIM WebSocket 服务
  lumenim_comet:
    image: gzydong/lumenim:latest
    container_name: lumenim-comet
    depends_on:
      - mysql
      - redis
    ports:
      - '9502:9502'
    restart: always
    volumes:
      - ./backend/config.yaml:/work/config.yaml
      - ./runtime:/work/runtime
    command: comet
    networks:
      - lumenim-network

  # LumenIM 异步队列
  lumenim_queue:
    image: gzydong/lumenim:latest
    container_name: lumenim-queue
    depends_on:
      - mysql
      - redis
      - minio
    restart: always
    volumes:
      - ./backend/config.yaml:/work/config.yaml
      - ./uploads:/work/uploads/:rw
      - ./runtime:/work/runtime
    command: queue
    networks:
      - lumenim-network

  # LumenIM 定时任务
  lumenim_cron:
    image: gzydong/lumenim:latest
    container_name: lumenim-cron
    depends_on:
      - mysql
      - redis
    restart: always
    volumes:
      - ./backend/config.yaml:/work/config.yaml
      - ./uploads:/work/uploads/:rw
      - ./runtime:/work/runtime
    command: crontab
    networks:
      - lumenim-network

  # Nginx 反向代理
  nginx:
    image: nginx:alpine
    container_name: lumenim-nginx
    restart: always
    ports:
      - '80:80'
      - '443:443'
    volumes:
      - ./nginx/nginx.conf:/etc/nginx/nginx.conf
      - ./nginx/conf.d:/etc/nginx/conf.d
      - ./nginx/ssl:/etc/nginx/ssl
      - ./front/dist:/usr/share/nginx/html
    depends_on:
      - lumenim_http
      - lumenim_comet
    networks:
      - lumenim-network

networks:
  lumenim-network:
    driver: bridge

volumes:
  mysql_data:
  redis_data:
  minio_data:
```

### 第七步：配置 Nginx

创建目录结构：

```bash
mkdir -p /opt/lumenim/nginx/conf.d /opt/lumenim/nginx/ssl
```

创建主配置文件 `/opt/lumenim/nginx/nginx.conf`：

```nginx
user nginx;
worker_processes auto;
error_log /var/log/nginx/error.log warn;
pid /var/run/nginx.pid;

events {
    worker_connections 4096;
    multi_accept on;
}

http {
    include /etc/nginx/mime.types;
    default_type application/octet-stream;

    log_format main '$remote_addr - $remote_user [$time_local] "$request" '
                    '$status $body_bytes_sent "$http_referer" '
                    '"$http_user_agent" "$http_x_forwarded_for"';

    access_log /var/log/nginx/access.log main;

    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 65;
    types_hash_max_size 2048;

    # Gzip 压缩
    gzip on;
    gzip_vary on;
    gzip_proxied any;
    gzip_comp_level 6;
    gzip_types text/plain text/css text/xml application/json application/javascript 
               application/rss+xml application/atom+xml image/svg+xml;

    include /etc/nginx/conf.d/*.conf;
}
```

创建站点配置 `/opt/lumenim/nginx/conf.d/lumenim.conf`：

```nginx
# HTTP 自动跳转 HTTPS
server {
    listen 80;
    server_name im.yourcompany.com;

    return 301 https://$server_name$request_uri;
}

# HTTPS 配置
server {
    listen 443 ssl http2;
    server_name im.yourcompany.com;

    # SSL 证书配置
    ssl_certificate /etc/nginx/ssl/fullchain.pem;
    ssl_certificate_key /etc/nginx/ssl/privkey.pem;
    
    # SSL 安全配置
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
    ssl_prefer_server_ciphers on;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;

    # 安全响应头
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;

    # 前端静态资源
    root /usr/share/nginx/html;
    index index.html;

    location / {
        try_files $uri $uri/ /index.html;
    }

    # 静态资源缓存
    location ~ .*\.(gif|jpg|jpeg|png|bmp|swf|flv|ico)$ {
        expires 7d;
        access_log off;
    }

    location ~ .*\.(js|css)?$ {
        expires 7d;
        access_log off;
    }

    # API 代理
    location /api/ {
        proxy_pass http://lumenim_http:9501/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }

    # WebSocket 代理
    location /ws/ {
        proxy_pass http://lumenim_comet:9502/;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_read_timeout 86400;
        proxy_send_timeout 86400;
    }

    # MinIO 控制台代理（可选）
    location /minio/ {
        proxy_pass http://minio:9000/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_buffering off;
    }
}
```

### 第八步：配置 SSL 证书

将 SSL 证书文件复制到指定目录：

```bash
# 复制证书文件
cp /path/to/fullchain.pem /opt/lumenim/nginx/ssl/
cp /path/to/privkey.pem /opt/lumenim/nginx/ssl/

# 或者使用 Let's Encrypt 自动证书
# certbot --nginx -d im.yourcompany.com
```

### 第九步：启动服务

```bash
cd /opt/lumenim

# 创建必要的目录
mkdir -p uploads runtime

# 创建环境变量文件 .env
cat > .env << EOF
MYSQL_ROOT_PASSWORD=your-secure-password
MINIO_ROOT_USER=minioadmin
MINIO_ROOT_PASSWORD=your-minio-password
EOF

# 拉取镜像
docker-compose -f docker-compose.prod.yaml pull

# 启动所有服务
docker-compose -f docker-compose.prod.yaml up -d

# 查看服务状态
docker-compose -f docker-compose.prod.yaml ps

# 查看日志
docker-compose -f docker-compose.prod.yaml logs -f
```

### 第十步：初始化数据库

首次部署时，MySQL 容器会自动执行 `backend/sql/lumenim.sql` 初始化数据库结构。

如果需要导入测试数据：

```bash
# 进入 MySQL 容器
docker exec -it lumenim-mysql mysql -uroot -p

# 在 MySQL shell 中执行
use go_chat;
source /docker-entrypoint-initdb.d/your-test-data.sql;
exit;
```

## 部署后配置

### 默认账号

| 用户 | 手机号 | 密码 | 岗位 |
|------|--------|------|------|
| XiaoMing | 13800000001 | admin123 | CTO |
| XiaoHong | 13800000002 | admin123 | Product Manager |
| ZhangSan | 13800000003 | admin123 | Tech Lead |
| LiSi | 13800000004 | admin123 | Developer |
| WangWu | 13800000005 | admin123 | Developer |

**重要**：生产环境请立即修改所有默认密码。

### MinIO Bucket 访问策略

确认 MinIO bucket 策略正确配置：

```bash
# 进入 MinIO 容器
docker exec -it lumenim-minio /bin/sh

# 设置 bucket 访问策略
mc anonymous set download local/im-private
mc anonymous set public local/im-static

# 验证配置
mc anonymous list local/
```

## 运维管理

### 服务管理命令

```bash
# 启动所有服务
docker-compose -f /opt/lumenim/docker-compose.prod.yaml start

# 停止所有服务
docker-compose -f /opt/lumenim/docker-compose.prod.yaml stop

# 重启指定服务
docker-compose -f /opt/lumenim/docker-compose.prod.yaml restart lumenim_http

# 查看服务状态
docker-compose -f /opt/lumenim/docker-compose.prod.yaml ps

# 查看服务日志
docker-compose -f /opt/lumenim/docker-compose.prod.yaml logs -f [service_name]
```

### 更新部署

```bash
cd /opt/lumenim

# 拉取最新代码
cd front && git pull && pnpm install && pnpm build && cd ..
cd backend && git pull && cd ..

# 重新构建并启动
docker-compose -f docker-compose.prod.yaml pull
docker-compose -f docker-compose.prod.yaml up -d --build
```

### 数据备份

#### MySQL 数据库备份

```bash
# 备份数据库
docker exec lumenim-mysql mysqldump -uroot -p"${MYSQL_ROOT_PASSWORD}" go_chat > backup_$(date +%Y%m%d).sql

# 恢复数据库
docker exec -i lumenim-mysql mysql -uroot -p"${MYSQL_ROOT_PASSWORD}" go_chat < backup_20240101.sql
```

#### MinIO 数据备份

```bash
# 使用 mc 客户端备份
docker exec -it lumenim-minio mc mirror local/im-static /data/backup/im-static-$(date +%Y%m%d)
docker exec -it lumenim-minio mc mirror local/im-private /data/backup/im-private-$(date +%Y%m%d)
```

### 日志管理

```bash
# 查看后端日志
docker logs -f lumenim_http --tail 100

# 查看 WebSocket 日志
docker logs -f lumenim_comet --tail 100

# 日志轮转配置（在宿主机上配置 logrotate）
cat > /etc/logrotate.d/lumenim << EOF
/opt/lumenim/runtime/*.log {
    daily
    rotate 7
    compress
    delaycompress
    notifempty
    create 0644 root root
}
EOF
```

### 监控配置

#### 健康检查

```bash
# 检查 MySQL
docker exec lumenim-mysql mysqladmin ping -uroot -p"${MYSQL_ROOT_PASSWORD}"

# 检查 Redis
docker exec lumenim-redis redis-cli ping

# 检查 MinIO
docker exec lumenim-minio mc ready local
```

#### 自动重启策略

所有服务已配置 `restart: always`，服务异常退出时自动重启。

如需更精细的监控，建议集成：

- Prometheus + Grafana（容器监控）
- Alertmanager（告警通知）
- ELK Stack（日志分析）

## 安全加固

### 防火墙配置

```bash
# 只开放必要端口
ufw allow 80/tcp    # HTTP
ufw allow 443/tcp    # HTTPS
ufw allow 22/tcp    # SSH

# 启用防火墙
ufw enable
```

### 数据库安全

- 修改 MySQL root 强密码
- 创建专用应用数据库用户，限制权限
- 启用 SSL 连接（生产环境推荐）

### Redis 安全

创建 `/opt/lumenim/redis.conf`：

```conf
# 设置密码
requirepass your-redis-password

# 禁用危险命令
rename-command FLUSHALL ""
rename-command CONFIG ""
rename-command SHUTDOWN ""

# 限制内存使用
maxmemory 1gb
maxmemory-policy allkeys-lru
```

### 文件权限

```bash
# 设置目录权限
chown -R 1000:1000 /opt/lumenim/runtime
chown -R 1000:1000 /opt/lumenim/uploads

# 设置配置文件权限（敏感信息）
chmod 600 /opt/lumenim/backend/config.yaml
chmod 600 /opt/lumenim/nginx/ssl/privkey.pem
```

### 定期安全更新

```bash
# 更新 Docker 镜像
docker-compose -f /opt/lumenim/docker-compose.prod.yaml pull

# 更新系统包
apt update && apt upgrade -y
```

## 故障排除

### 常见问题

#### 1. WebSocket 连接失败

```bash
# 检查 WebSocket 服务状态
docker logs lumenim_comet

# 检查 Nginx WebSocket 配置
# 确保以下配置存在：
# proxy_set_header Upgrade $http_upgrade;
# proxy_set_header Connection "upgrade";
# proxy_read_timeout 86400;
```

#### 2. 文件上传失败

```bash
# 检查 MinIO 服务状态
docker logs lumenim-minio

# 检查 bucket 权限
docker exec -it lumenim-minio mc ls local/

# 检查存储目录权限
ls -la /opt/lumenim/uploads
```

#### 3. 数据库连接失败

```bash
# 检查 MySQL 服务状态
docker logs lumenim-mysql

# 测试连接
docker exec -it lumenim-mysql mysql -uroot -p

# 检查网络连通性
docker exec lumenim_http ping mysql
```

#### 4. 前端页面空白

```bash
# 检查 Nginx 配置
docker exec lumenim-nginx nginx -t

# 查看 Nginx 错误日志
docker logs lumenim-nginx --tail 50
```

### 性能优化

#### MySQL 优化

在 `docker-compose.prod.yaml` 的 MySQL 服务中添加：

```yaml
mysql:
  # ... 其他配置
  command: >
    --default-authentication-plugin=mysql_native_password 
    --character-set-server=utf8mb4 
    --collation-server=utf8mb4_unicode_ci
    --innodb-buffer-pool-size=1G
    --max-connections=500
    --slow-query-log=1
    --long-query-time=2
```

#### Redis 优化

```conf
# redis.conf
maxmemory 2gb
maxmemory-policy allkeys-lru
appendonly yes
tcp-backlog 511
timeout 0
```

## 技术支持

- 官方文档：https://github.com/gzydong/LumenIM
- 问题反馈：https://github.com/gzydong/LumenIM/issues
- 社区交流：837215079

## 附录

### A. 环境变量参考

| 变量名 | 说明 | 默认值 |
|-------|------|--------|
| MYSQL_ROOT_PASSWORD | MySQL root 密码 | root123456 |
| MINIO_ROOT_USER | MinIO 用户名 | minioadmin |
| MINIO_ROOT_PASSWORD | MinIO 密码 | minioadmin123 |

### B. 端口映射

| 容器端口 | 宿主机端口 | 说明 |
|---------|-----------|------|
| 3306 | 3306 | MySQL |
| 6379 | 6379 | Redis |
| 9000 | 9000 | MinIO API |
| 9090 | 9090 | MinIO Console |
| 9501 | 9501 | HTTP API |
| 9502 | 9502 | WebSocket |
| 80 | 80 | Nginx HTTP |
| 443 | 443 | Nginx HTTPS |

### C. 目录结构

```
/opt/lumenim/
├── backend/
│   ├── config.yaml          # 后端配置
│   ├── sql/                 # 数据库脚本
│   └── ...
├── front/
│   └── dist/                # 前端构建产物
├── nginx/
│   ├── nginx.conf           # Nginx 主配置
│   ├── conf.d/              # 站点配置
│   └── ssl/                 # SSL 证书
├── uploads/                 # 上传文件目录
├── runtime/                 # 运行时日志
├── docker-compose.prod.yaml # Docker 编排配置
└── .env                     # 环境变量
```
