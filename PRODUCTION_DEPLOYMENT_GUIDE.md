# LumenIM 生产环境部署技术文档

## 文档信息

| 项目 | 内容 |
|------|------|
| 版本 | v1.0.0 |
| 更新日期 | 2026-04-10 |
| 适用系统 | Linux (Ubuntu 20.04+ / CentOS 7+) |
| 文档类型 | 部署技术规范 |

---

## 一、部署架构总览

```
┌─────────────────────────────────────────────────────────────────────────┐
│                              用户访问层                                  │
│                     (浏览器 / 桌面客户端 / 移动端)                       │
└─────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                           反向代理层 (Nginx)                              │
│                     端口: 80 (HTTP) / 443 (HTTPS)                        │
│                     功能: SSL终结 / 负载均衡 / 静态资源服务               │
└─────────────────────────────────────────────────────────────────────────┘
                                    │
          ┌─────────────────────────┼─────────────────────────┐
          │                         │                         │
          ▼                         ▼                         ▼
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│   前端静态资源   │     │   HTTP API 服务  │     │  WebSocket 服务  │
│   (Nginx托管)   │     │   端口: 9501     │     │   端口: 9502     │
└─────────────────┘     └────────┬────────┘     └────────┬────────┘
                                 │                         │
                                 └───────────┬─────────────┘
                                             │
┌─────────────────────────────────────────────────────────────────────────┐
│                           Docker Network (lumenim-network)              │
│                     基础设施层 / 数据服务层                              │
└─────────────────────────────────────────────────────────────────────────┘
          │                    │                    │                    │
          ▼                    ▼                    ▼                    ▼
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│     MySQL       │     │     Redis       │     │     MinIO       │     │  后台任务服务    │
│   端口: 3306    │     │   端口: 6379    │     │  端口: 9000/9090│     │  Queue / Cron   │
│   数据库存储     │     │   缓存/消息队列  │     │   对象存储       │     │                 │
└─────────────────┘     └─────────────────┘     └─────────────────┘     └─────────────────┘
```

---

## 二、服务器目录结构

### 2.1 完整目录树

```
/opt/lumenim/                           # 项目根目录
│
├── front/                              # 前端部署目录
│   ├── dist/                          # ⭐ 前端构建产物 (Nginx托管)
│   │   ├── index.html                 # 入口HTML文件
│   │   ├── embed.html                 # 嵌入页面
│   │   ├── favicon.ico                # 网站图标
│   │   ├── favicon.svg                # SVG图标
│   │   └── assets/                    # ⭐ 静态资源目录
│   │       ├── *.js                   # JavaScript 打包文件
│   │       ├── *.css                  # CSS 样式文件
│   │       ├── *.png                  # PNG 图片资源
│   │       └── *.svg                  # SVG 图标资源
│   │
│   └── (构建时使用,部署后仅保留 dist)
│
├── backend/                            # 后端部署目录
│   ├── lumenim                         # ⭐ Go 可执行文件 (Linux)
│   ├── config.yaml                     # ⭐ 后端配置文件
│   ├── sql/                            # 数据库初始化脚本
│   │   └── lumenim.sql                # 数据库结构定义
│   ├── uploads/                        # ⭐ 上传文件存储目录
│   │   ├── images/                    # 用户上传图片
│   │   ├── files/                     # 用户上传文件
│   │   └── avatars/                   # 用户头像
│   └── runtime/                       # ⭐ 运行时目录
│       ├── logs/                      # 日志文件
│       ├── cache/                     # 缓存文件
│       └── temp/                      # 临时文件
│
├── nginx/                              # Nginx 配置目录
│   ├── nginx.conf                      # ⭐ Nginx 主配置文件
│   ├── conf.d/                        # 站点配置目录
│   │   └── lumenim.conf               # ⭐ LumenIM 站点配置
│   └── ssl/                           # SSL 证书目录
│       ├── fullchain.pem              # ⭐ SSL 完整证书
│       └── privkey.pem                # ⭐ SSL 私钥文件
│
├── data/                               # 数据存储目录
│   ├── mysql/                         # MySQL 数据卷 (Docker)
│   ├── redis/                         # Redis 数据卷 (Docker)
│   └── minio/                         # MinIO 数据卷 (Docker)
│       └── minio-data/                # MinIO 存储数据
│
├── backups/                            # ⭐ 备份文件目录
│   ├── lumenim-backup-YYYYMMDD-HHMMSS-backend.tar.gz
│   └── lumenim-backup-YYYYMMDD-HHMMSS-frontend.tar.gz
│
├── docker-compose.yaml                # Docker 编排配置
├── docker-compose.prod.yaml           # ⭐ 生产环境编排配置
└── .env                               # ⭐ 环境变量文件
```

### 2.2 目录权限要求

```bash
# 设置目录所有者
chown -R 1000:1000 /opt/lumenim/backend/runtime
chown -R 1000:1000 /opt/lumenim/backend/uploads

# 设置敏感配置文件权限
chmod 600 /opt/lumenim/backend/config.yaml
chmod 600 /opt/lumenim/nginx/ssl/privkey.pem

# 设置日志目录权限
chmod 755 /opt/lumenim/backend/runtime/logs
```

---

## 三、前端构建产物详解

### 3.1 构建产物目录结构

```
front/dist/                              # 生产构建目录 (打包后约 5-20MB)
│
├── index.html                          # 主入口页面
│   ├── 引用编译后的 JS/CSS
│   └── 注入环境变量
│
├── embed.html                          # 嵌入式页面 (用于iframe嵌入)
│
├── favicon.ico                         # 网站图标 (32x32)
├── favicon.svg                         # SVG 矢量图标
│
└── assets/                             # ⭐ 静态资源目录
    │
    ├── *.js                            # JavaScript 打包文件
    │   ├── index-*.js                  # 主包
    │   ├── vendor-vue-*.js             # Vue 框架库 (长期缓存)
    │   ├── vendor-ui-*.js              # NaiveUI 组件库 (长期缓存)
    │   ├── vendor-media-*.js           # 音视频库 (长期缓存)
    │   ├── vendor-utils-*.js           # 工具库 (长期缓存)
    │   └── Tabs-*.js                   # 懒加载模块
    │
    ├── *.css                           # CSS 样式文件
    │   ├── index-*.css                 # 主样式
    │   └── vendor-*.css                # 第三方样式
    │
    ├── *.png                           # PNG 图片资源
    │   └── logo-*.png                  # Logo 等品牌资源
    │
    └── *.svg                           # SVG 图标文件
```

### 3.2 资源缓存策略

| 资源类型 | 缓存时间 | 配置原因 |
|---------|---------|---------|
| `.js` / `.css` | 7 天 | 含有 hash, 可长期缓存 |
| 图片 (`.png/.jpg`) | 7 天 | 含有 hash, 可长期缓存 |
| `index.html` | 不缓存 | 内容随时变化 |
| 字体文件 | 30 天 | 更新频率低 |

### 3.3 前端构建命令

```bash
# 进入前端目录
cd /opt/lumenim/front

# 安装依赖 (生产环境)
pnpm install --production

# 生产构建
pnpm build

# 构建产物输出到 dist 目录
```

---

## 四、后端发布包详解

### 4.1 后端核心文件

```
backend/
│
├── lumenim                             # ⭐ Go 可执行文件 (Linux amd64)
│   ├── 文件大小: 约 30-50 MB
│   ├── 启动模式:
│   │   ├── lumenim http               # HTTP API 服务 (端口 9501)
│   │   ├── lumenim comet              # WebSocket 服务 (端口 9502)
│   │   ├── lumenim queue              # 异步队列服务
│   │   └── lumenim crontab            # 定时任务服务
│   │
│
├── config.yaml                         # ⭐ 主配置文件
│
├── lumenim.db                          # SQLite 数据库 (如使用)
│
├── sql/                                # 数据库脚本
│   └── lumenim.sql                    # 数据库初始化SQL
│
├── uploads/                            # ⭐ 用户上传目录
│   ├── images/                        # 聊天图片
│   ├── files/                         # 文件传输
│   ├── audio/                         # 语音消息
│   ├── video/                         # 视频消息
│   └── avatars/                       # 用户头像
│
└── runtime/                            # ⭐ 运行时目录
    ├── logs/                          # 日志文件
    │   ├── lumenim.log                # 主日志
    │   └── lumenim-error.log          # 错误日志
    ├── cache/                         # 缓存文件
    └── temp/                         # 临时文件
```

### 4.2 后端构建命令

```bash
# 进入后端目录
cd /opt/lumenim/backend

# 设置交叉编译环境
export CGO_ENABLED=0
export GOOS=linux
export GOARCH=amd64

# 构建 Linux 可执行文件
go build -ldflags="-s -w" -o lumenim ./cmd/lumenim

# Windows 本地构建 (开发调试用)
go build -ldflags="-s -w" -o lumenim.exe ./cmd/lumenim
```

### 4.3 后端服务说明

| 服务 | 命令 | 端口 | 说明 |
|------|------|------|------|
| HTTP API | `lumenim http` | 9501 | RESTful API 服务 |
| WebSocket | `lumenim comet` | 9502 | 实时消息长连接 |
| Queue | `lumenim queue` | - | 异步任务处理 |
| Cron | `lumenim crontab` | - | 定时任务执行 |

---

## 五、环境变量配置

### 5.1 Docker Compose 环境变量 (.env)

```bash
# 文件位置: /opt/lumenim/.env

# ==================== 数据库配置 ====================
MYSQL_ROOT_PASSWORD=your_secure_mysql_password
MYSQL_DATABASE=go_chat

# ==================== Redis 配置 ====================
REDIS_PASSWORD=your_redis_password
REDIS_PORT=6379

# ==================== MinIO 配置 ====================
MINIO_ROOT_USER=minioadmin
MINIO_ROOT_PASSWORD=your_minio_password

# ==================== 应用配置 ====================
APP_ENV=production
APP_DEBUG=false
```

### 5.2 后端配置文件 (config.yaml)

```yaml
# 文件位置: /opt/lumenim/backend/config.yaml

# ==================== 应用配置 ====================
app:
  env: prod                           # 环境: dev/test/prod
  debug: false                        # 调试模式
  admin_email:
    - admin@yourcompany.com
  public_key: |                        # RSA 公钥 (Base64编码)
    -----BEGIN PUBLIC KEY-----
    MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA...
    -----END PUBLIC KEY-----
  private_key: |                       # RSA 私钥 (Base64编码)
    -----BEGIN PRIVATE KEY-----
    MIIEvQIBADANBgkqhkiG9w0BAQEFAASCBKcwggSj...
    -----END PRIVATE KEY-----
  aes_key: "32位随机字符串用于AES加密"

# ==================== 服务端口 ====================
server:
  http_addr: ":9501"                   # HTTP API 端口
  websocket_addr: ":9502"              # WebSocket 端口
  tcp_addr: ":9505"                    # TCP 端口 (预留)

# ==================== 日志配置 ====================
log:
  path: "/opt/lumenim/backend/runtime/logs"
  level: "info"                        # 日志级别: debug/info/warn/error
  max_size: 100                        # 单文件最大 MB
  max_backups: 30                      # 保留备份数
  max_age: 7                           # 保留天数

# ==================== Redis 配置 ====================
redis:
  host: redis                          # Docker 内部网络地址
  port: 6379
  auth: "your_redis_password"
  database: 0
  pool_size: 100

# ==================== MySQL 配置 ====================
mysql:
  host: mysql
  port: 3306
  username: root
  password: "your_mysql_password"
  database: go_chat
  charset: utf8mb4
  collation: utf8mb4_unicode_ci
  max_open_conns: 100
  max_idle_conns: 10
  conn_max_lifetime: 3600

# ==================== JWT 配置 ====================
jwt:
  secret: "your_jwt_secret_key_32chars"
  expires_time: 86400                  # 24小时
  buffer_time: 86400

# ==================== 跨域配置 ====================
cors:
  origin: "https://im.yourcompany.com"
  headers: "Content-Type,Cache-Control,User-Agent,Keep-Alive,DNT,AccessToken,Authorization"
  methods: "OPTIONS,GET,POST,PUT,DELETE"
  credentials: true
  max_age: 600

# ==================== 文件存储配置 ====================
filesystem:
  default: minio                       # 存储驱动: local/minio
  local:
    root: "/opt/lumenim/backend/uploads"
    bucket_public: "public"
    bucket_private: "private"
  minio:
    secret_id: "minioadmin"
    secret_key: "your_minio_password"
    bucket_public: "im-static"
    bucket_private: "im-private"
    endpoint: "minio:9000"
    ssl: false

# ==================== 邮件配置 (可选) ====================
email:
  host: smtp.ym.163.com
  port: 465
  username: noreply@yourcompany.com
  password: "smtp_password"
  fromname: "LumenIM"
```

### 5.3 前端环境变量 (.env.production)

```bash
# 文件位置: /opt/lumenim/front/.env.production

# ==================== 应用配置 ====================
ENV = 'production'
VITE_APP_NAME=LumenIM
VITE_APP_ENV=production

# ==================== 路由配置 ====================
VITE_BASE=/
VITE_ROUTER_MODE=history

# ==================== API 配置 ====================
VITE_BASE_API=https://im.yourcompany.com/api
VITE_SOCKET_API=wss://im.yourcompany.com/ws

# ==================== 安全配置 ====================
VITE_RSA_PUBLIC_KEY="-----BEGIN PUBLIC KEY-----
MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA...
-----END PUBLIC KEY-----"
```

---

## 六、反向代理配置 (Nginx)

### 6.1 Nginx 主配置文件

```nginx
# 文件位置: /opt/lumenim/nginx/nginx.conf

user nginx;
worker_processes auto;
error_log /var/log/nginx/error.log warn;
pid /var/run/nginx.pid;

events {
    worker_connections 4096;
    multi_accept on;
    use epoll;
}

http {
    include /etc/nginx/mime.types;
    default_type application/octet-stream;

    # 日志格式
    log_format main '$remote_addr - $remote_user [$time_local] "$request" '
                    '$status $body_bytes_sent "$http_referer" '
                    '"$http_user_agent" "$http_x_forwarded_for" '
                    'rt=$request_time uct="$upstream_connect_time" '
                    'uht="$upstream_header_time" urt="$upstream_response_time"';

    access_log /var/log/nginx/access.log main;

    # 性能优化
    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 65;
    types_hash_max_size 2048;
    server_tokens off;

    # Gzip 压缩
    gzip on;
    gzip_vary on;
    gzip_proxied any;
    gzip_comp_level 6;
    gzip_min_length 1024;
    gzip_types text/plain text/css text/xml application/json 
               application/javascript application/rss+xml 
               application/atom+xml image/svg+xml;
    gzip_disable "msie6";

    # 安全响应头
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Referrer-Policy "strict-origin-when-cross-origin" always;

    # 客户端限制
    client_max_body_size 100M;
    client_body_buffer_size 1m;

    # 连接限制
    limit_conn_zone $binary_remote_addr zone=addr:10m;
    limit_conn addr 100;
    limit_req_zone $binary_remote_addr zone=req:10m rate=10r/s;

    # 上游服务器
    upstream lumenim_http {
        server lumenim_http:9501;
        keepalive 32;
    }

    upstream lumenim_comet {
        server lumenim_comet:9502;
        keepalive 64;
    }

    include /etc/nginx/conf.d/*.conf;
}
```

### 6.2 LumenIM 站点配置

```nginx
# 文件位置: /opt/lumenim/nginx/conf.d/lumenim.conf

# ==================== HTTP 重定向 ====================
server {
    listen 80;
    server_name im.yourcompany.com;

    # 强制 HTTPS
    return 301 https://$server_name$request_uri;
}

# ==================== HTTPS 服务 ====================
server {
    listen 443 ssl http2;
    server_name im.yourcompany.com;

    # SSL 证书配置
    ssl_certificate /etc/nginx/ssl/fullchain.pem;
    ssl_certificate_key /etc/nginx/ssl/privkey.pem;
    
    # SSL 安全配置
    ssl_session_cache shared:SSL:50m;
    ssl_session_timeout 1d;
    ssl_session_tickets off;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256;
    ssl_prefer_server_ciphers off;
    ssl_stapling on;
    ssl_stapling_verify on;

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

    location ~* \.(woff|woff2|ttf|eot|svg|otf)$ {
        expires 30d;
        access_log off;
        add_header Cache-Control "public";
    }

    # ==================== API 代理 ====================
    location /api/ {
        proxy_pass http://lumenim_http/api/;
        proxy_http_version 1.1;
        
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header Connection "";
        
        # 超时设置
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
        
        # 缓冲设置
        proxy_buffering on;
        proxy_buffer_size 4k;
        proxy_buffers 8 4k;
        proxy_busy_buffers_size 8k;
        
        # 限流
        limit_conn addr 50;
    }

    # ==================== WebSocket 代理 ====================
    location /ws/ {
        proxy_pass http://lumenim_comet/ws/;
        proxy_http_version 1.1;
        
        # WebSocket 必需头
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        
        # WebSocket 超时 (长连接)
        proxy_read_timeout 86400;
        proxy_send_timeout 86400;
        
        # 连接复用
        proxy_buffering off;
        proxy_cache off;
        
        # 限流
        limit_conn addr 100;
    }

    # ==================== 文件上传代理 ====================
    location /upload/ {
        proxy_pass http://lumenim_http/upload/;
        proxy_http_version 1.1;
        
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        
        # 文件上传超时 (大文件)
        proxy_connect_timeout 300s;
        proxy_send_timeout 300s;
        proxy_read_timeout 300s;
        
        # 关闭缓冲
        proxy_request_buffering off;
    }

    # ==================== MinIO 控制台代理 (可选) ====================
    location /minio/ {
        proxy_pass http://minio:9000/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_buffering off;
    }

    # ==================== 健康检查 ====================
    location /health {
        access_log off;
        return 200 "OK";
        add_header Content-Type text/plain;
    }

    # ==================== 错误页面 ====================
    error_page 500 502 503 504 /50x.html;
    location = /50x.html {
        root /usr/share/nginx/html;
    }
}
```

---

## 七、负载均衡配置

### 7.1 多实例部署架构

```
                    ┌─────────────────────────────────┐
                    │          Nginx 负载均衡器         │
                    │            443 (HTTPS)           │
                    └───────────────┬───────────────────┘
                                    │
        ┌───────────────────────────┼───────────────────────────┐
        │                           │                           │
        ▼                           ▼                           ▼
┌───────────────┐         ┌───────────────┐         ┌───────────────┐
│  Backend-01   │         │  Backend-02   │         │  Backend-03   │
│  lumenim http │         │  lumenim http │         │  lumenim http │
│    :9501      │         │    :9501      │         │    :9501      │
└───────┬───────┘         └───────┬───────┘         └───────┬───────┘
        │                           │                           │
        │     ┌─────────────────────┼─────────────────────┐     │
        │     │         Docker Swarm / Kubernetes        │     │
        │     │                                         │     │
        ▼     ▼                                         ▼     ▼
   ┌─────────────┐                                ┌─────────────┐
   │   MySQL     │                                │    Redis    │
   │  主从复制   │                                │   集群模式   │
   └─────────────┘                                └─────────────┘
```

### 7.2 Nginx 负载均衡配置

```nginx
# ==================== 上游服务器组 ====================
upstream lumenim_api {
    # 负载均衡算法
    # least_conn;                          # 最少连接
    # ip_hash;                             # IP哈希 (session保持)
    # hash $request_uri consistent;         # 一致性哈希
    
    server backend-01:9501 weight=5;      # 后端实例1
    server backend-02:9501 weight=5;      # 后端实例2
    server backend-03:9501 weight=3 backup; # 后端实例3 (备用)
    
    keepalive 32;
    keepalive_requests 1000;
    keepalive_timeout 60s;
}

upstream lumenim_ws {
    # WebSocket 不支持普通负载均衡,使用 ip_hash
    ip_hash;
    
    server backend-01:9502;
    server backend-02:9502;
    # 注意: WebSocket 连接需要保持同一后端
}

# ==================== 健康检查配置 ====================
upstream lumenim_api {
    zone lumenim_api 64k;
    
    server backend-01:9501;
    server backend-02:9501;
    server backend-03:9501 backup;
    
    keepalive 32;
}

# ==================== 使用示例 ====================
location /api/ {
    proxy_pass http://lumenim_api/;
    # ... 其他代理配置
}
```

### 7.3 Docker Swarm 部署配置

```yaml
# docker-compose.prod.yaml (关键部分)

services:
  lumenim_http:
    deploy:
      replicas: 3
      restart_policy:
        condition: on-failure
        delay: 5s
        max_attempts: 3
      resources:
        limits:
          cpus: '2'
          memory: 2G
        reservations:
          cpus: '1'
          memory: 1G
      placement:
        constraints:
          - node.role == worker
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:9501/api/v1/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 60s
```

---

## 八、Docker Compose 生产配置

### 8.1 完整配置

```yaml
# 文件位置: /opt/lumenim/docker-compose.prod.yaml

version: '3.8'

services:
  # ==================== MySQL 数据库 ====================
  mysql:
    image: mysql:8.0
    container_name: lumenim-mysql
    restart: always
    ports:
      - "3306:3306"
    environment:
      MYSQL_ROOT_PASSWORD: ${MYSQL_ROOT_PASSWORD}
      MYSQL_DATABASE: go_chat
      TZ: Asia/Shanghai
    volumes:
      - mysql_data:/var/lib/mysql
      - ./backend/sql:/docker-entrypoint-initdb.d:ro
    command:
      - --default-authentication-plugin=mysql_native_password
      - --character-set-server=utf8mb4
      - --collation-server=utf8mb4_unicode_ci
      - --innodb-buffer-pool-size=1G
      - --max-connections=500
      - --slow-query-log=1
      - --long-query-time=2
    networks:
      - lumenim-network
    healthcheck:
      test: ["CMD", "mysqladmin", "ping", "-h", "localhost", "-u", "root", "-p${MYSQL_ROOT_PASSWORD}"]
      interval: 10s
      timeout: 5s
      retries: 5

  # ==================== Redis 缓存 ====================
  redis:
    image: redis:7.2-alpine
    container_name: lumenim-redis
    restart: always
    ports:
      - "6379:6379"
    volumes:
      - redis_data:/data
      - ./redis.conf:/usr/local/etc/redis/redis.conf:ro
    command: redis-server /usr/local/etc/redis/redis.conf
    networks:
      - lumenim-network
    healthcheck:
      test: ["CMD", "redis-cli", "-a", "${REDIS_PASSWORD}", "ping"]
      interval: 10s
      timeout: 5s
      retries: 5

  # ==================== MinIO 对象存储 ====================
  minio:
    image: minio/minio:latest
    container_name: lumenim-minio
    restart: always
    ports:
      - "9000:9000"
      - "9090:9090"
    environment:
      MINIO_ROOT_USER: ${MINIO_ROOT_USER}
      MINIO_ROOT_PASSWORD: ${MINIO_ROOT_PASSWORD}
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

  # ==================== HTTP API 服务 ====================
  lumenim_http:
    image: gzydong/lumenim:latest
    container_name: lumenim-http
    restart: always
    ports:
      - "9501:9501"
    depends_on:
      mysql:
        condition: service_healthy
      redis:
        condition: service_healthy
      minio:
        condition: service_healthy
    volumes:
      - ./backend/config.yaml:/work/config.yaml:ro
      - ./backend/uploads:/work/uploads:rw
      - ./backend/runtime:/work/runtime:rw
    command: http --config=/work/config.yaml
    networks:
      - lumenim-network
    deploy:
      replicas: 2
      resources:
        limits:
          memory: 1G
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:9501/api/v1/health"]
      interval: 30s
      timeout: 10s
      retries: 3

  # ==================== WebSocket 服务 ====================
  lumenim_comet:
    image: gzydong/lumenim:latest
    container_name: lumenim-comet
    restart: always
    ports:
      - "9502:9502"
    depends_on:
      mysql:
        condition: service_healthy
      redis:
        condition: service_healthy
    volumes:
      - ./backend/config.yaml:/work/config.yaml:ro
      - ./backend/runtime:/work/runtime:rw
    command: comet
    networks:
      - lumenim-network
    deploy:
      replicas: 2
      resources:
        limits:
          memory: 512M
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:9502/health"]
      interval: 30s
      timeout: 10s
      retries: 3

  # ==================== 异步队列服务 ====================
  lumenim_queue:
    image: gzydong/lumenim:latest
    container_name: lumenim-queue
    restart: always
    depends_on:
      mysql:
        condition: service_healthy
      redis:
        condition: service_healthy
      minio:
        condition: service_healthy
    volumes:
      - ./backend/config.yaml:/work/config.yaml:ro
      - ./backend/uploads:/work/uploads:rw
      - ./backend/runtime:/work/runtime:rw
    command: queue
    networks:
      - lumenim-network
    deploy:
      replicas: 1
      resources:
        limits:
          memory: 512M

  # ==================== 定时任务服务 ====================
  lumenim_cron:
    image: gzydong/lumenim:latest
    container_name: lumenim-cron
    restart: always
    depends_on:
      mysql:
        condition: service_healthy
      redis:
        condition: service_healthy
    volumes:
      - ./backend/config.yaml:/work/config.yaml:ro
      - ./backend/uploads:/work/uploads:rw
      - ./backend/runtime:/work/runtime:rw
    command: crontab
    networks:
      - lumenim-network
    deploy:
      replicas: 1
      resources:
        limits:
          memory: 256M

  # ==================== Nginx 反向代理 ====================
  nginx:
    image: nginx:alpine
    container_name: lumenim-nginx
    restart: always
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx/nginx.conf:/etc/nginx/nginx.conf:ro
      - ./nginx/conf.d:/etc/nginx/conf.d:ro
      - ./nginx/ssl:/etc/nginx/ssl:ro
      - ./front/dist:/usr/share/nginx/html:ro
    depends_on:
      - lumenim_http
      - lumenim_comet
    networks:
      - lumenim-network
    deploy:
      replicas: 2
      resources:
        limits:
          memory: 256M
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost/health"]
      interval: 30s
      timeout: 10s
      retries: 3

networks:
  lumenim-network:
    driver: bridge

volumes:
  mysql_data:
    driver: local
  redis_data:
    driver: local
  minio_data:
    driver: local
```

---

## 九、部署检查清单

### 9.1 部署前检查

```bash
# 1. 服务器环境检查
cat /etc/os-release                    # 确认操作系统版本
docker --version                        # 确认 Docker 已安装
docker-compose --version               # 确认 Docker Compose 已安装

# 2. 端口检查
netstat -tuln | grep -E "80|443|3306|6379|9000|9090|9501|9502"

# 3. 磁盘空间检查
df -h /opt/lumenim

# 4. 创建项目目录
mkdir -p /opt/lumenim/{backend/runtime,backend/uploads,nginx/{conf.d,ssl},front,backups}

# 5. SSL 证书准备
ls -la /opt/lumenim/nginx/ssl/
```

### 9.2 部署步骤

```bash
# 步骤 1: 上传项目文件
scp -r backend/ root@server:/opt/lumenim/
scp -r front/dist/ root@server:/opt/lumenim/front/

# 步骤 2: 配置环境变量
scp .env root@server:/opt/lumenim/
scp config.yaml root@server:/opt/lumenim/backend/

# 步骤 3: 配置 Nginx
scp nginx.conf root@server:/opt/lumenim/nginx/
scp lumenim.conf root@server:/opt/lumenim/nginx/conf.d/

# 步骤 4: 启动服务
cd /opt/lumenim
docker-compose -f docker-compose.prod.yaml up -d

# 步骤 5: 检查服务状态
docker-compose -f docker-compose.prod.yaml ps
docker-compose -f docker-compose.prod.yaml logs --tail=50
```

### 9.3 部署后验证

```bash
# 1. 检查容器状态
docker ps -a | grep lumenim

# 2. 检查健康状态
curl http://localhost:9501/api/v1/health
curl http://localhost/health

# 3. 检查日志
docker-compose logs lumenim_http --tail=100
docker-compose logs lumenim_comet --tail=100

# 4. 检查 WebSocket 连接
curl -i -N \
  -H "Connection: Upgrade" \
  -H "Upgrade: websocket" \
  http://localhost:9502/health

# 5. 访问前端
curl -I https://im.yourcompany.com
```

---

## 十、运维管理命令

### 10.1 服务管理

```bash
# 启动所有服务
docker-compose -f /opt/lumenim/docker-compose.prod.yaml up -d

# 停止所有服务
docker-compose -f /opt/lumenim/docker-compose.prod.yaml down

# 重启指定服务
docker-compose -f /opt/lumenim/docker-compose.prod.yaml restart lumenim_http

# 查看服务状态
docker-compose -f /opt/lumenim/docker-compose.prod.yaml ps

# 查看实时日志
docker-compose -f /opt/lumenim/docker-compose.prod.yaml logs -f
```

### 10.2 数据备份

```bash
# 备份 MySQL 数据库
docker exec lumenim-mysql mysqldump -uroot -p"${MYSQL_ROOT_PASSWORD}" go_chat > backup_$(date +%Y%m%d).sql

# 备份 MinIO 数据
docker exec lumenim-minio mc mirror local/im-static /data/backup/im-static-$(date +%Y%m%d)
docker exec lumenim-minio mc mirror local/im-private /data/backup/im-private-$(date +%Y%m%d)

# 备份配置文件
tar czf config-backup-$(date +%Y%m%d).tar.gz backend/config.yaml nginx/conf.d/
```

### 10.3 日志管理

```bash
# 查看后端日志
docker logs -f lumenim_http --tail=100

# 查看 WebSocket 日志
docker logs -f lumenim_comet --tail=100

# Nginx 访问日志
docker exec lumenim-nginx tail -f /var/log/nginx/access.log

# Nginx 错误日志
docker exec lumenim-nginx tail -f /var/log/nginx/error.log
```

### 10.4 性能监控

```bash
# 查看容器资源使用
docker stats

# 查看特定容器
docker stats lumenim_http lumenim_comet

# 查看磁盘使用
docker system df

# 查看网络连接数
docker exec lumenim-nginx ss -s
```

---

## 十一、安全配置

### 11.1 防火墙配置

```bash
# Ubuntu (UFW)
ufw allow 22/tcp    # SSH
ufw allow 80/tcp    # HTTP
ufw allow 443/tcp   # HTTPS

# CentOS (Firewalld)
firewall-cmd --permanent --add-service=http
firewall-cmd --permanent --add-service=https
firewall-cmd --reload
```

### 11.2 Redis 安全配置

```conf
# redis.conf
requirepass your_redis_password
bind 0.0.0.0
protected-mode yes
rename-command FLUSHALL ""
rename-command CONFIG ""
maxmemory 2gb
maxmemory-policy allkeys-lru
appendonly yes
tcp-backlog 511
timeout 0
```

### 11.3 MySQL 安全配置

```sql
-- 创建应用专用用户
CREATE USER 'lumenim'@'%' IDENTIFIED BY 'app_password';
GRANT SELECT, INSERT, UPDATE, DELETE ON go_chat.* TO 'lumenim'@'%';
FLUSH PRIVILEGES;

-- 修改 root 密码
ALTER USER 'root'@'localhost' IDENTIFIED BY 'new_strong_password';
```

---

## 十二、故障排查

### 12.1 常见问题

| 问题 | 原因 | 解决方案 |
|------|------|----------|
| WebSocket 连接失败 | Nginx 未配置 upgrade | 添加 WebSocket 必需的 proxy_set_header |
| 文件上传失败 | MinIO bucket 权限问题 | 运行 mc anonymous set public |
| 数据库连接失败 | 密码错误或网络问题 | 检查 docker-compose 网络配置 |
| 前端页面空白 | 路由配置错误 | 检查 try_files 配置 |
| 502 Bad Gateway | 后端服务未启动 | 检查容器健康状态 |

### 12.2 诊断命令

```bash
# 检查网络连通性
docker exec lumenim_http ping mysql
docker exec lumenim_http ping redis

# 检查端口监听
docker exec lumenim-nginx netstat -tlnp

# 检查 DNS 解析
docker exec lumenim_http nslookup mysql

# 检查容器日志
docker-compose logs --tail=100 --follow
```

---

## 附录

### A. 端口映射表

| 容器端口 | 宿主机端口 | 服务 | 外部访问 |
|---------|-----------|------|---------|
| 3306 | 3306 | MySQL | ❌ 不开放 |
| 6379 | 6379 | Redis | ❌ 不开放 |
| 9000 | 9000 | MinIO API | ⚠️ 可选开放 |
| 9090 | 9090 | MinIO Console | ⚠️ 可选开放 |
| 9501 | 9501 | HTTP API | ❌ Nginx代理 |
| 9502 | 9502 | WebSocket | ❌ Nginx代理 |
| 80 | 80 | Nginx HTTP | ✅ 开放 |
| 443 | 443 | Nginx HTTPS | ✅ 开放 |

### B. 资源需求估算

| 规模 | 用户数 | CPU | 内存 | 磁盘 |
|------|--------|-----|------|------|
| 入门 | ≤50 | 2核 | 4GB | 50GB |
| 标准 | 50-200 | 4核 | 8GB | 100GB |
| 企业 | 200-1000 | 8核 | 16GB | 200GB |
| 大型 | 1000+ | 16核 | 32GB | 500GB |

### C. 联系与支持

- 项目地址: https://github.com/gzydong/LumenIM
- 问题反馈: https://github.com/gzydong/LumenIM/issues
- 社区交流: 837215079

### D. 自动化部署包

详细的部署包打包和部署流程请参考：

- [部署包打包指南](./software/scripts/deploy-package/DEPLOY_PACKAGE_GUIDE.md)
- [部署包快速开始](./software/scripts/deploy-package/README.md)

---

*文档生成时间: 2026-04-10*
*版本: v1.0.0*
