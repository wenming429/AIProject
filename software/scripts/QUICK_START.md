# LumenIM Ubuntu 20.04 快速部署清单

**文档版本**: 2.1.0  
**更新日期**: 2026-04-09  
**适用系统**: Ubuntu 20.04 LTS  
**应用账号**: `lumenimadmin` / `lumenim123`
**源码仓库**: `https://github.com/wenming429/AIProject` (分支: main/master)

---

## 一、访问方式

| 访问方式 | 地址 | 说明 |
|----------|------|------|
| 局域网 IP | `http://192.168.23.131` | 局域网内设备访问 |
| 域名访问 | `http://mylumenim.cfldcn.com` | 需配置 hosts |
| 本地访问 | `http://localhost` | 服务器本地 |

---

## 二、部署方式

### 方式一：自动化脚本部署（推荐）

```bash
# 1. 上传脚本到服务器
scp -r software/scripts root@服务器IP:/tmp/

# 2. 完整部署 + 网络配置
chmod +x /tmp/software/scripts/deploy-ubuntu20.sh
sudo /tmp/software/scripts/deploy-ubuntu20.sh \
    --all \
    --bind-ip=192.168.23.131 \
    --domain=mylumenim.cfldcn.com
```

### 方式二：仅配置网络（已部署后修改）

```bash
chmod +x /tmp/software/scripts/configure-network.sh
sudo /tmp/software/scripts/configure-network.sh \
    --ip=192.168.23.131 \
    --domain=mylumenim.cfldcn.com
```

### 方式三：Docker Compose 部署

```bash
cd backend
cp ../software/scripts/docker-compose-ubuntu.yaml docker-compose.yaml
cp ../software/scripts/nginx.conf .
cp ../software/scripts/config.yaml .

# 编辑 config.yaml 修改密码
vi config.yaml

# 启动
docker-compose up -d
```

---

## 三、配置文件位置

| 文件 | 路径 | 说明 |
|------|------|------|
| Nginx 配置 | `/etc/nginx/sites-available/lumenim` | 监听地址、server_name |
| 后端配置 | `/var/www/lumenim/backend/config.yaml` | 数据库、CORS |
| 前端环境 | `/var/www/lumenim/front/.env.production` | API 地址 |
| systemd 服务 | `/etc/systemd/system/lumenim-backend.service` | 启动参数 |

---

## 四、关键配置说明

### 4.1 Nginx 配置

```nginx
server {
    listen 80;
    # 同时支持 IP 和域名
    server_name _ 192.168.23.131 mylumenim.cfldcn.com;
    
    # API 代理
    location /api/ {
        proxy_pass http://127.0.0.1:9501/api/;
    }
    
    # WebSocket 代理
    location /ws {
        proxy_pass http://127.0.0.1:9502;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
    }
}
```

### 4.2 前端环境配置

```env
# /var/www/lumenim/front/.env.production
VITE_API_BASE_URL=http://192.168.23.131/api
VITE_WS_URL=ws://192.168.23.131/ws
```

### 4.3 后端 CORS 配置

```yaml
# /var/www/lumenim/backend/config.yaml
cors:
  origin: "http://192.168.23.131"  # 或 http://mylumenim.cfldcn.com
```

---

## 五、客户端 hosts 配置

### Windows

文件: `C:\Windows\System32\drivers\etc\hosts`

```
192.168.23.131  mylumenim.cfldcn.com
```

### Linux/macOS

文件: `/etc/hosts`

```
192.168.23.131  mylumenim.cfldcn.com
```

---

## 六、服务管理命令

```bash
# 查看状态
systemctl status lumenim-backend

# 重启服务
systemctl restart lumenim-backend
systemctl restart nginx

# 查看日志
journalctl -u lumenim-backend -f
tail -f /var/log/nginx/access.log

# 端口检查
ss -tlnp | grep -E "80|9501|9502"
```

---

## 七、验证命令

```bash
# 测试 API
curl http://localhost:9501/api/v1/health
curl http://192.168.23.131:9501/api/v1/health

# 测试前端
curl http://localhost/
curl http://192.168.23.131/

# 测试 Nginx 代理
curl http://localhost/api/v1/health
curl http://192.168.23.131/api/v1/health
```

---

## 八、防火墙配置

```bash
# 开放端口
sudo ufw allow 22/tcp    # SSH
sudo ufw allow 80/tcp    # HTTP
sudo ufw allow 443/tcp   # HTTPS
sudo ufw allow 9501/tcp  # API
sudo ufw allow 9502/tcp  # WebSocket

# 启用防火墙
sudo ufw enable
sudo ufw status
```

---

## 九、常见问题

### Q1: 无法通过 IP 访问

```bash
# 检查防火墙
sudo ufw status

# 检查端口监听
ss -tlnp | grep 80

# 检查 Nginx 配置
sudo nginx -t
sudo systemctl status nginx
```

### Q2: 域名解析失败

1. 确认客户端 hosts 文件配置正确
2. 如果使用公网域名，确认 DNS 解析生效
3. 清除浏览器缓存

### Q3: WebSocket 连接失败

确认 Nginx 配置包含:
```nginx
proxy_http_version 1.1;
proxy_set_header Upgrade $http_upgrade;
proxy_set_header Connection "upgrade";
proxy_read_timeout 86400s;
```

---

## 十、访问地址汇总

```
局域网 IP 访问:
  - 前端:    http://192.168.23.131/
  - API:     http://192.168.23.131/api/v1/health
  - WebSocket: ws://192.168.23.131/ws
  - MinIO:   http://192.168.23.131:9090

域名访问:
  - 前端:    http://mylumenim.cfldcn.com/
  - API:     http://mylumenim.cfldcn.com/api/v1/health
  - WebSocket: ws://mylumenim.cfldcn.com/ws
  - MinIO:   http://mylumenim.cfldcn.com:9090

本地访问:
  - 前端:    http://localhost/
  - API:     http://localhost:9501/api/v1/health
  - MinIO:   http://localhost:9090
```

---

**部署完成后，客户端首次访问可能需要配置 hosts 文件才能使用域名访问。**
