# LumenIM Ubuntu 20.04 部署指南

**文档版本**: 2.0.0
**更新日期**: 2026-04-10
**适用系统**: Ubuntu 20.04 LTS
**目标服务器**: 192.168.23.131
**部署用户**: wenming429

---

## 一、部署信息

### 1.1 服务器配置

| 配置项 | 值 |
|--------|-----|
| 服务器 IP | 192.168.23.131 |
| SSH 端口 | 22 |
| 登录用户名 | wenming429 |
| 代码仓库 | https://github.com/wenming429/AIProject.git |
| 部署目录 | /opt/lumenim |
| 项目目录 | /var/www/lumenim |

### 1.2 数据库配置

| 配置项 | 值 |
|--------|-----|
| MySQL 版本 | 8.0 |
| MySQL 端口 | 3306 |
| Root 密码 | wenming429 |
| 数据库名 | go_chat |

### 1.3 服务端口

| 服务 | 端口 | 协议 |
|------|------|------|
| 后端 HTTP API | 9501 | HTTP |
| 后端 WebSocket | 9502 | WS |
| 后端 TCP | 9505 | TCP |
| MySQL | 3306 | TCP |
| Redis | 6379 | TCP |

### 1.4 系统架构

```
┌─────────────────────────────────────────────┐
│               前端 / Frontend              │
│         (Vue 3 + Vite + Naive UI)          │
│           http://192.168.23.131:5173        │
└─────────────────────┬───────────────────────┘
                      │ HTTP API
                      ▼
┌─────────────────────────────────────────────┐
│               后端 / Backend                │
│            (Go + Gin + GORM)                │
│   HTTP :9501  |  WS :9502  |  TCP :9505    │
└─────────────────────┬───────────────────────┘
                      │
        ┌─────────────┴─────────────┐
        ▼                           ▼
┌───────────────┐          ┌───────────────┐
│    MySQL 8.0  │          │   Redis 7.x   │
│     :3306     │          │    :6379      │
└───────────────┘          └───────────────┘
```

---

## 二、快速部署（从本地执行）

### 2.1 前置条件

**本地环境要求：**
- PowerShell 5.1+ 或 Bash
- SSH 客户端
- SSH 密码认证已启用（或配置 SSH 密钥）

**服务器要求：**
- Ubuntu 20.04 LTS 已安装
- 具有 sudo 权限的用户账户

### 2.2 一键部署命令

在本地 Windows/PowerShell 终端执行：

```powershell
# 1. 下载部署脚本
git clone https://github.com/wenming429/AIProject.git D:\temp\LumenIM
cd D:\temp\LumenIM\software\scripts

# 2. 添加执行权限并执行
chmod +x deploy-ubuntu20.sh
./deploy-ubuntu20.sh --host 192.168.23.131 --user wenming429 --password 你的密码 --all
```

### 2.3 SSH 密钥方式（推荐）

```powershell
# 1. 首先生成 SSH 密钥（如果还没有）
ssh-keygen -t rsa -C "wenming429@lumenim"

# 2. 复制公钥到服务器
ssh-copy-id wenming429@192.168.23.131

# 3. 使用密钥部署
./deploy-ubuntu20.sh --host 192.168.23.131 --user wenming429 --key ~/.ssh/id_rsa --all
```

---

## 三、服务器端手动部署

### 3.1 SSH 连接服务器

```bash
ssh wenming429@192.168.23.131
```

### 3.2 切换到 root（如果需要）

```bash
sudo -i
```

### 3.3 下载代码

```bash
# 进入工作目录
cd /tmp

# 克隆代码仓库
git clone https://github.com/wenming429/AIProject.git

# 或者使用 HTTPS + Token
# git clone https://wenming429:YOUR_TOKEN@github.com/wenming429/AIProject.git
```

### 3.4 运行自动化脚本

```bash
cd LumenIM/software/scripts

# 添加执行权限
chmod +x install-ubuntu20.sh

# 完整安装
sudo ./install-ubuntu20.sh --all

# 或分步安装
sudo ./install-ubuntu20.sh --deps      # 安装系统依赖
sudo ./install-ubuntu20.sh --runtime   # 安装运行时环境
sudo ./install-ubuntu20.sh --database  # 安装数据库
sudo ./install-ubuntu20.sh --config   # 配置服务
sudo ./install-ubuntu20.sh --start    # 启动服务
```

---

## 四、脚本参数说明

### 4.1 deploy-ubuntu20.sh（远程部署脚本）

| 参数 | 说明 | 示例 |
|------|------|------|
| `--host` | 服务器 IP | 192.168.23.131 |
| `--user` | SSH 用户名 | wenming429 |
| `--password` | SSH 密码 | your_password |
| `--key` | SSH 密钥路径 | ~/.ssh/id_rsa |
| `--port` | SSH 端口 | 22 |
| `--all` | 执行完整部署 | - |
| `--deps` | 仅安装依赖 | - |
| `--config` | 仅配置 | - |
| `--help` | 显示帮助 | - |

### 4.2 install-ubuntu20.sh（服务器端安装脚本）

| 参数 | 说明 |
|------|------|
| `--all` | 完整安装 |
| `--check` | 检查环境 |
| `--deps` | 安装系统依赖 |
| `--runtime` | 安装运行时 (Go, Node.js) |
| `--database` | 安装数据库 (MySQL, Redis) |
| `--config` | 配置服务 |
| `--start` | 启动服务 |
| `--firewall` | 配置防火墙 |

---

## 五、服务管理命令

### 5.1 systemd 服务

```bash
# 查看状态
systemctl status lumenim-backend
systemctl status lumenim-frontend

# 启动/停止/重启
sudo systemctl start lumenim-backend
sudo systemctl stop lumenim-backend
sudo systemctl restart lumenim-backend

# 查看日志
sudo journalctl -u lumenim-backend -f
sudo journalctl -u lumenim-frontend -f
```

### 5.2 服务健康检查

```bash
# 检查端口
lsof -i:9501
lsof -i:9502
lsof -i:3306
lsof -i:6379

# 测试 API
curl http://localhost:9501/api/v1/health

# 检查进程
ps aux | grep lumenim
```

### 5.3 手动启动（调试模式）

```bash
# 后端
cd /var/www/lumenim/backend
./bin/lumenim --debug

# 前端
cd /var/www/lumenim/front
pnpm dev
```

---

## 六、数据库配置

### 6.1 MySQL 初始化

```bash
# 连接 MySQL（使用 root 密码）
mysql -u root -p

# 在 MySQL 中执行：
CREATE DATABASE IF NOT EXISTS go_chat CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;
CREATE USER IF NOT EXISTS 'lumenim'@'localhost' IDENTIFIED BY 'lumenim123';
CREATE USER IF NOT EXISTS 'lumenim'@'%' IDENTIFIED BY 'lumenim123';
GRANT ALL PRIVILEGES ON go_chat.* TO 'lumenim'@'localhost';
GRANT ALL PRIVILEGES ON go_chat.* TO 'lumenim'@'%';
FLUSH PRIVILEGES;
EXIT;
```

### 6.2 初始化数据库表

```bash
cd /var/www/lumenim/backend
mysql -u root -p go_chat < sql/init.sql
```

---

## 七、关键配置文件

### 7.1 后端配置

文件: `/var/www/lumenim/backend/config.yaml`

```yaml
server:
  http_port: 9501
  ws_port: 9502
  tcp_port: 9505

database:
  host: localhost
  port: 3306
  username: root
  password: wenming429
  database: go_chat
  charset: utf8mb4

redis:
  host: localhost
  port: 6379

jwt:
  secret: 836c3fea9bba4e04d51bd0fbcc5d8e7f
  expires_time: 86400
```

### 7.2 环境变量覆盖

```bash
# /etc/profile.d/lumenim.sh
export LUMENIM_DB_HOST=localhost
export LUMENIM_DB_PORT=3306
export LUMENIM_DB_PASSWORD=wenming429
export LUMENIM_REDIS_HOST=localhost
export LUMENIM_REDIS_PORT=6379
```

---

## 八、防火墙配置

### 8.1 UFW 防火墙

```bash
# 允许 SSH
sudo ufw allow 22/tcp

# 允许服务端口
sudo ufw allow 9501/tcp
sudo ufw allow 9502/tcp
sudo ufw allow 9505/tcp

# 允许外部访问 MySQL（仅内网）
sudo ufw allow from 192.168.0.0/16 to any port 3306

# 启用防火墙
sudo ufw enable
sudo ufw status
```

---

## 九、常见问题

### 9.1 SSH 连接失败

```bash
# 检查 SSH 服务
sudo systemctl status ssh

# 检查端口
sudo ss -tlnp | grep 22

# 检查防火墙
sudo ufw status
```

### 9.2 数据库连接失败

```bash
# 检查 MySQL 服务
sudo systemctl status mysql

# 检查 MySQL 日志
sudo tail -f /var/log/mysql/error.log

# 测试连接
mysql -u root -p -e "SELECT 1"
```

### 9.3 Go 依赖下载失败

```bash
# 设置 Go 代理
export GOPROXY=https://goproxy.cn,direct

# 清理缓存
go clean -modcache

# 重新下载
cd /var/www/lumenim/backend
go mod download
```

### 9.4 pnpm 安装失败

```bash
# 使用 npm 安装
npm install -g pnpm

# 或使用 corepack
corepack enable
corepack prepare pnpm@10.0.0 --activate
```

---

## 十、回滚与卸载

### 10.1 停止服务

```bash
sudo systemctl stop lumenim-backend
sudo systemctl stop lumenim-frontend
sudo systemctl disable lumenim-backend
sudo systemctl disable lumenim-frontend
```

### 10.2 卸载服务

```bash
# 移除 systemd 服务
sudo rm /etc/systemd/system/lumenim-*.service
sudo systemctl daemon-reload

# 移除目录
sudo rm -rf /opt/lumenim
sudo rm -rf /var/www/lumenim

# 移除配置
sudo rm -f /etc/mysql/conf.d/lumenim.cnf
sudo rm -f /etc/redis/lumenim.conf
```

### 10.3 数据备份

```bash
# 备份数据库
mysqldump -u root -p wenming429 go_chat > /backup/go_chat_$(date +%Y%m%d).sql

# 备份 Redis
redis-cli SAVE
sudo cp /var/lib/redis/dump.rdb /backup/
```

---

## 十一、部署检查清单

部署完成后，请逐项确认：

- [ ] 服务器 SSH 连接正常
- [ ] MySQL 服务运行正常
- [ ] Redis 服务运行正常
- [ ] 后端服务运行正常（端口 9501）
- [ ] 前端服务运行正常（端口 5173）
- [ ] API 健康检查通过
- [ ] 防火墙规则已配置
- [ ] 数据库已初始化

---

**文档结束**
