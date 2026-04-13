# LumenIM Ubuntu 20.04 网络访问配置指南

**文档版本**: 1.1.0
**更新日期**: 2026-04-09
**适用系统**: Ubuntu 20.04 LTS
**源码仓库**: `https://github.com/wenming429/AIProject`

---

## 一、网络访问概述

### 1.1 支持的访问方式

| 访问方式 | 示例地址 | 说明 |
|----------|----------|------|
| 本地访问 | `http://localhost` | 仅本机访问 |
| 局域网 IP | `http://192.168.23.131` | 局域网内设备访问 |
| 域名访问 | `http://mylumenim.cfldcn.com` | 内网域名或公网域名 |
| 完整域名 | `http://mylumenim.cfldcn.com:9501` | 带端口的完整访问 |

### 1.2 架构图

```
┌─────────────────────────────────────────────────────────────┐
│                      客户端访问                               │
│    192.168.23.x ──► 192.168.23.131:80 ──► LumenIM          │
│    mylumenim.cfldcn.com ──► Nginx ──► Backend :9501        │
└─────────────────────────────────────────────────────────────┘
```

---

## 二、配置文件说明

### 2.1 需要修改的配置文件

| 配置文件 | 位置 | 修改内容 |
|----------|------|----------|
| 后端 config.yaml | `/var/www/lumenim/backend/config.yaml` | 监听地址 |
| Nginx 配置 | `/etc/nginx/sites-available/lumenim` | server_name、代理地址 |
| 前端环境 | `/var/www/lumenim/front/.env.production` | API 地址 |
| systemd 服务 | `/etc/systemd/system/lumenim-*.service` | 绑定地址 |

---

## 三、局域网 IP 访问配置

### 3.1 后端配置

修改 `/var/www/lumenim/backend/config.yaml`:

```yaml
server:
  # 监听所有网卡（包括局域网）
  http_addr: ":9501"
  websocket_addr: ":9502"
  tcp_addr: ":9505"

# 或者绑定特定 IP
# http_addr: "192.168.23.131:9501"
```

### 3.2 Nginx 配置

修改 `/etc/nginx/sites-available/lumenim`:

```nginx
server {
    # 监听所有网卡
    listen 80;
    # 或绑定特定 IP
    # listen 192.168.23.131:80;
    
    # 使用 _ 匹配所有域名，或指定具体 IP
    server_name _;
    # 或指定局域网 IP
    # server_name 192.168.23.131;
    
    root /var/www/lumenim/front/dist;
    index index.html;

    # 前端静态文件
    location / {
        try_files $uri $uri/ /index.html;
    }

    # API 反向代理
    location /api/ {
        proxy_pass http://127.0.0.1:9501/api/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    # WebSocket 支持
    location /ws {
        proxy_pass http://127.0.0.1:9502;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_read_timeout 86400s;
        proxy_send_timeout 86400s;
    }
}
```

### 3.3 防火墙配置

```bash
# 开放防火墙端口
sudo ufw allow 80/tcp    # HTTP
sudo ufw allow 443/tcp   # HTTPS
sudo ufw allow 9501/tcp  # HTTP API
sudo ufw allow 9502/tcp  # WebSocket

# 如果需要直接访问后端（非 Nginx 方式）
sudo ufw allow 9501/tcp
sudo ufw allow 9502/tcp
sudo ufw allow 9505/tcp
```

---

## 四、域名访问配置

### 4.1 内网域名配置

如果使用内网 DNS（如 AD、DNS 服务器）:

1. 添加 DNS 解析记录:
   - 域名: `mylumenim.cfldcn.com`
   - 类型: A
   - 值: `192.168.23.131`

2. 如果没有内网 DNS，修改客户端 hosts 文件:

**Windows 客户端:**
```
C:\Windows\System32\drivers\etc\hosts
```

添加:
```
192.168.23.131  mylumenim.cfldcn.com
```

**Linux/macOS 客户端:**
```bash
sudo vim /etc/hosts
```

添加:
```
192.168.23.131  mylumenim.cfldcn.com
```

### 4.2 Nginx 域名配置

```nginx
server {
    listen 80;
    server_name mylumenim.cfldcn.com;
    
    root /var/www/lumenim/front/dist;
    index index.html;

    # 前端静态文件
    location / {
        try_files $uri $uri/ /index.html;
    }

    # API 反向代理
    location /api/ {
        proxy_pass http://127.0.0.1:9501/api/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    # WebSocket 支持
    location /ws {
        proxy_pass http://127.0.0.1:9502;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_read_timeout 86400s;
        proxy_send_timeout 86400s;
    }
}
```

### 4.3 同时支持 IP 和域名

```nginx
server {
    listen 80;
    server_name _ 192.168.23.131 mylumenim.cfldcn.com;
    
    root /var/www/lumenim/front/dist;
    index index.html;

    location / {
        try_files $uri $uri/ /index.html;
    }

    location /api/ {
        proxy_pass http://127.0.0.1:9501/api/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    location /ws {
        proxy_pass http://127.0.0.1:9502;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_read_timeout 86400s;
        proxy_send_timeout 86400s;
    }
}
```

---

## 五、前端环境配置

### 5.1 创建生产环境配置

创建 `/var/www/lumenim/front/.env.production`:

```env
# 局域网 IP 访问
VITE_API_BASE_URL=http://192.168.23.131/api
VITE_WS_URL=ws://192.168.23.131/ws

# 或使用域名
# VITE_API_BASE_URL=http://mylumenim.cfldcn.com/api
# VITE_WS_URL=ws://mylumenim.cfldcn.com/ws
```

### 5.2 重新构建前端

```bash
cd /var/www/lumenim/front
sudo -u lumenimadmin pnpm build
```

---

## 六、服务绑定地址配置

### 6.1 systemd 服务配置

创建后端服务时指定绑定地址:

```ini
[Unit]
Description=LumenIM Backend Service
After=network.target mysql.service redis.service

[Service]
Type=simple
User=lumenimadmin
WorkingDirectory=/var/www/lumenim/backend
# 绑定所有网卡
ExecStart=/var/www/lumenim/backend/lumenim http --config=/var/www/lumenim/backend/config.yaml --addr=:9501
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
```

### 6.2 检查服务监听地址

```bash
# 检查后端监听
ss -tlnp | grep lumenim

# 检查结果示例
# LISTEN 0 128 *:9501 *:* users:(("lumenim",pid=1234),...)
# LISTEN 0 128 *:9502 *:* users:(("lumenim",pid=1235),...)

# 检查 Nginx 监听
ss -tlnp | grep nginx
```

---

## 七、自动化脚本配置参数

### 7.1 使用脚本配置网络

```bash
# 完整部署并配置局域网访问
sudo ./deploy-ubuntu20.sh --all --bind-ip=192.168.23.131 --domain=mylumenim.cfldcn.com

# 仅配置网络
sudo ./deploy-ubuntu20.sh --network --bind-ip=192.168.23.131 --domain=mylumenim.cfldcn.com

# 更新 Nginx 配置
sudo ./deploy-ubuntu20.sh --nginx --domain=mylumenim.cfldcn.com
```

### 7.2 脚本参数说明

| 参数 | 说明 | 示例 |
|------|------|------|
| `--bind-ip` | 绑定局域网 IP | `--bind-ip=192.168.23.131` |
| `--domain` | 域名 | `--domain=mylumenim.cfldcn.com` |
| `--http-port` | HTTP 端口 | `--http-port=80` |
| `--api-port` | API 端口 | `--api-port=9501` |

---

## 八、完整配置示例

### 8.1 环境信息

- 服务器 IP: `192.168.23.131`
- 域名: `mylumenim.cfldcn.com`
- 应用用户: `lumenimadmin`
- 应用密码: `lumenim123`

### 8.2 配置文件清单

**1. `/var/www/lumenim/backend/config.yaml`**
```yaml
server:
  http_addr: ":9501"
  websocket_addr: ":9502"
  tcp_addr: ":9505"

mysql:
  host: localhost
  port: 3306
  username: lumenim
  password: lumenim123
  database: go_chat

redis:
  host: localhost
  port: 6379
  database: 0
```

**2. `/etc/nginx/sites-available/lumenim`**
```nginx
server {
    listen 80;
    server_name _ 192.168.23.131 mylumenim.cfldcn.com;
    
    root /var/www/lumenim/front/dist;
    index index.html;

    location / {
        try_files $uri $uri/ /index.html;
    }

    location /api/ {
        proxy_pass http://127.0.0.1:9501/api/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    location /ws {
        proxy_pass http://127.0.0.1:9502;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_read_timeout 86400s;
        proxy_send_timeout 86400s;
    }
}
```

**3. `/var/www/lumenim/front/.env.production`**
```env
VITE_API_BASE_URL=http://192.168.23.131/api
VITE_WS_URL=ws://192.168.23.131/ws
```

**4. `/var/www/lumenim/front/.env.production` (域名版)**
```env
VITE_API_BASE_URL=http://mylumenim.cfldcn.com/api
VITE_WS_URL=ws://mylumenim.cfldcn.com/ws
```

### 8.3 客户端 hosts 配置

**Windows:**
```
192.168.23.131  mylumenim.cfldcn.com
```

**Linux/macOS:**
```
192.168.23.131  mylumenim.cfldcn.com
```

---

## 九、验证访问

### 9.1 本地验证

```bash
# 测试 API
curl http://localhost:9501/api/v1/health

# 测试前端
curl http://localhost/

# 测试 Nginx
curl http://localhost/api/v1/health
```

### 9.2 局域网验证

```bash
# 从局域网其他机器测试
curl http://192.168.23.131/api/v1/health

# 或使用域名（需配置 hosts）
curl http://mylumenim.cfldcn.com/api/v1/health
```

### 9.3 WebSocket 测试

```bash
# 使用 websocat 测试
websocat ws://192.168.23.131/ws

# 或使用浏览器控制台
# new WebSocket('ws://192.168.23.131/ws')
```

---

## 十、常见问题

### 10.1 无法通过 IP 访问

1. 检查防火墙是否开放 80 端口
2. 检查 Nginx 是否监听 0.0.0.0
3. 检查后端是否绑定 0.0.0.0

```bash
# 检查防火墙
sudo ufw status

# 检查监听
ss -tlnp | grep -E "80|9501"

# 重启 Nginx
sudo systemctl restart nginx
```

### 10.2 域名解析问题

1. 检查 hosts 文件配置
2. 检查 DNS 解析
3. 清除浏览器缓存

```bash
# Windows 测试
ping mylumenim.cfldcn.com

# Linux/macOS 测试
ping mylumenim.cfldcn.com
```

### 10.3 WebSocket 连接失败

1. 检查 Nginx WebSocket 配置
2. 检查 proxy_read_timeout 设置
3. 检查防火墙是否开放 9502 端口

```nginx
# 确保包含这些配置
proxy_http_version 1.1;
proxy_set_header Upgrade $http_upgrade;
proxy_set_header Connection "upgrade";
proxy_read_timeout 86400s;
```

### 10.4 跨域问题

如果前后端在不同域名，需要配置 CORS:

```yaml
# config.yaml
cors:
  origin: "http://192.168.23.131"  # 或 "http://mylumenim.cfldcn.com"
  methods: "OPTIONS,GET,POST,PUT,DELETE"
  credentials: true
```

---

**文档结束**
