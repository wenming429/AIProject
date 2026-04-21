# LumenIM 部署检查清单

**服务器 IP**: 192.168.23.131
**部署日期**: 2026-04-21
**部署模式**: Docker Compose / 原生部署

---

## 一、部署前检查清单

### 1.1 服务器环境检查

| 检查项 | 预期结果 | 检查命令 |
|--------|----------|----------|
| 操作系统 | Ubuntu 20.04/22.04 LTS | `cat /etc/os-release` |
| CPU 核心数 | ≥ 2 核 | `nproc` |
| 内存 | ≥ 4 GB | `free -h` |
| 磁盘空间 | ≥ 30 GB 可用 | `df -h /` |
| 网络连通性 | 可访问外网 | `ping -c 1 8.8.8.8` |
| IP 地址 | 192.168.23.131 | `ip addr show \| grep 192.168.23.131` |

### 1.2 端口检查

| 端口 | 服务 | 状态 | 检查命令 |
|------|------|------|----------|
| 22 | SSH | 开放 | `sudo ufw status \| grep 22` |
| 80 | HTTP | 可用 | `sudo lsof -i:80` |
| 443 | HTTPS | 可用 | `sudo lsof -i:443` |
| 3306 | MySQL | 未占用或仅本地 | `sudo lsof -i:3306` |
| 6379 | Redis | 未占用或仅本地 | `sudo lsof -i:6379` |
| 9000 | MinIO API | 可用 | `sudo lsof -i:9000` |
| 9090 | MinIO Console | 可用 | `sudo lsof -i:9090` |

### 1.3 软件依赖检查

| 软件 | 最低版本 | 检查命令 |
|------|----------|----------|
| Docker | 20.10+ | `docker --version` |
| Docker Compose | 2.0+ | `docker compose version` |
| Git | 2.0+ | `git --version` |
| Wget/Curl | 最新 | `wget --version` |

---

## 二、部署执行清单

### 2.1 Docker Compose 部署模式

```bash
# Step 1: 环境检查
sudo ./install-ubuntu20.sh --check

# Step 2: 安装系统依赖
sudo ./install-ubuntu20.sh --deps

# Step 3: 安装 Docker
sudo ./install-ubuntu20.sh --docker --docker-compose

# Step 4: 克隆代码
sudo ./install-ubuntu20.sh --clone

# Step 5: 配置项目（自动创建 docker-compose.yaml）
sudo ./install-ubuntu20.sh --config --use-docker

# Step 6: 构建前端
sudo ./install-ubuntu20.sh --frontend

# Step 7: 启动服务
sudo ./install-ubuntu20.sh --start

# Step 8: 配置防火墙
sudo ./install-ubuntu20.sh --firewall

# 或一键部署
sudo ./install-ubuntu20.sh --docker --docker-compose --use-docker --all
```

### 2.2 原生部署模式

```bash
# Step 1: 环境检查
sudo ./install-ubuntu20.sh --check

# Step 2: 安装系统依赖
sudo ./install-ubuntu20.sh --deps

# Step 3: 安装运行时
sudo ./install-ubuntu20.sh --runtime

# Step 4: 安装数据库
sudo ./install-ubuntu20.sh --mysql --redis

# Step 5: 安装 Protocol Buffers
sudo ./install-ubuntu20.sh --protobuf

# Step 6: 克隆代码
sudo ./install-ubuntu20.sh --clone

# Step 7: 配置项目
sudo ./install-ubuntu20.sh --config --use-native

# Step 8: 初始化数据库
sudo ./install-ubuntu20.sh --database

# Step 9: 构建后端
sudo ./install-ubuntu20.sh --backend

# Step 10: 安装前端
sudo ./install-ubuntu20.sh --frontend

# Step 11: 启动服务
sudo ./install-ubuntu20.sh --start

# Step 12: 配置防火墙
sudo ./install-ubuntu20.sh --firewall

# 或一键部署
sudo ./install-ubuntu20.sh --use-native --all
```

---

## 三、部署后验证清单

### 3.1 服务状态检查

```bash
# Docker Compose 模式
cd /var/www/lumenim/docker
docker compose ps

# 原生模式
sudo systemctl status lumenim-backend
sudo systemctl status lumenim-comet
sudo systemctl status mysql
sudo systemctl status redis-server
```

### 3.2 端口监听检查

```bash
# 检查端口监听
sudo ss -tlnp | grep 192.168.23.131
```

预期结果：
```
192.168.23.131:80     # Nginx HTTP
192.168.23.131:9000  # MinIO API
192.168.23.131:9090  # MinIO Console
127.0.0.1:3306       # MySQL (仅本地)
127.0.0.1:6379       # Redis (仅本地)
```

### 3.3 健康检查

```bash
# HTTP 健康检查
curl -I http://192.168.23.131/health

# API 健康检查
curl http://192.168.23.131/api/v1/health

# MinIO 健康检查
curl http://192.168.23.131:9000/minio/health/live

# MinIO Console
curl http://192.168.23.131:9090/minio/health/live
```

### 3.4 日志检查

```bash
# Docker Compose 模式
cd /var/www/lumenim/docker
docker compose logs -f

# 原生模式
sudo journalctl -u lumenim-backend -f
sudo journalctl -u lumenim-comet -f
```

---

## 四、浏览器访问测试

### 4.1 访问地址

| 服务 | 地址 | 预期结果 |
|------|------|----------|
| 前端首页 | http://192.168.23.131 | 显示登录页面 |
| API 文档 | http://192.168.23.131/api/v1/health | 返回 JSON |
| MinIO Console | http://192.168.23.131:9090 | 显示登录页面 |

### 4.2 功能测试

- [ ] 访问前端首页，显示正常
- [ ] 用户注册功能
- [ ] 用户登录功能
- [ ] 发送消息功能
- [ ] 文件上传功能
- [ ] WebSocket 连接

---

## 五、部署配置确认

### 5.1 关键配置文件

| 文件 | 路径 | 用途 |
|------|------|------|
| config.yaml | `/var/www/lumenim/docker/config.yaml` | 后端配置 |
| docker-compose.yaml | `/var/www/lumenim/docker/docker-compose.yaml` | 容器编排 |
| .env | `/var/www/lumenim/docker/.env` | 环境变量 |
| nginx.conf | `/var/www/lumenim/docker/nginx.conf` | Nginx 配置 |

### 5.2 配置检查项

```bash
# 检查配置文件是否存在
ls -la /var/www/lumenim/docker/

# 检查 IP 配置是否正确
grep -r "192.168.23.131" /var/www/lumenim/docker/

# 检查数据库密码
grep "PASSWORD" /var/www/lumenim/docker/.env
```

---

## 六、安全配置确认

### 6.1 防火墙状态

```bash
sudo ufw status verbose
```

预期规则：
```
Status: active

To                         Action      From
--                         ------      ----
22/tcp                     ALLOW IN    Anywhere
80/tcp                     ALLOW IN    Anywhere
443/tcp                    ALLOW IN    Anywhere
9000/tcp                   ALLOW IN    Anywhere
9090/tcp                   ALLOW IN    Anywhere
3306/tcp                   DENY IN     Anywhere
6379/tcp                   DENY IN     Anywhere
```

### 6.2 敏感文件权限

```bash
# 检查配置文件权限
ls -la /var/www/lumenim/docker/.env
ls -la /var/www/lumenim/docker/config.yaml
```

预期权限：`-rw-------` (600)

---

## 七、备份配置

### 7.1 自动备份脚本

```bash
#!/bin/bash
# backup.sh - LumenIM 备份脚本

BACKUP_DIR="/var/backups/lumenim"
DATE=$(date +%Y%m%d_%H%M%S)

mkdir -p $BACKUP_DIR

# 备份数据库
cd /var/www/lumenim/docker
docker exec lumenim-mysql mysqldump -uroot -plumenim123 go_chat > $BACKUP_DIR/mysql_$DATE.sql

# 备份配置
tar czf $BACKUP_DIR/config_$DATE.tar.gz config.yaml .env nginx.conf

# 清理 7 天前的备份
find $BACKUP_DIR -mtime +7 -delete

echo "备份完成: $BACKUP_DIR"
```

---

## 八、快速故障排查

### 8.1 服务无法启动

```bash
# 检查 Docker 状态
sudo systemctl status docker

# 检查容器日志
docker compose logs -f

# 重启 Docker
sudo systemctl restart docker
```

### 8.2 端口被占用

```bash
# 查找占用端口的进程
sudo lsof -i:80
sudo lsof -i:3306

# 杀死进程
sudo kill -9 <PID>
```

### 8.3 权限问题

```bash
# 修复目录权限
sudo chown -R 1000:1000 /var/www/lumenim/docker/data
sudo chmod -R 755 /var/www/lumenim/docker/data
```

---

## 九、部署完成确认

### 9.1 签署确认

| 项目 | 状态 | 备注 |
|------|------|------|
| 环境检查完成 | ☐ | |
| Docker 安装完成 | ☐ | |
| 代码克隆完成 | ☐ | |
| 配置生成完成 | ☐ | |
| 前端构建完成 | ☐ | |
| 服务启动成功 | ☐ | |
| 健康检查通过 | ☐ | |
| 浏览器访问正常 | ☐ | |
| 防火墙配置完成 | ☐ | |

### 9.2 访问信息记录

| 配置项 | 值 |
|--------|-----|
| 服务器 IP | 192.168.23.131 |
| 前端地址 | http://192.168.23.131 |
| MinIO Console | http://192.168.23.131:9090 |
| MinIO 用户 | minioadmin |
| MySQL 密码 | lumenim123 |
| 部署日期 | |
| 部署人员 | |

---

**检查清单结束**
