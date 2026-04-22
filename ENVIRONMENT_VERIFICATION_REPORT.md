# LumenIM 运行环境验证报告

> 验证时间: 2026-04-22
> 验证脚本: `software/scripts/environment-check.sh`

---

## 一、验证概述

### 1.1 验证目的
- 确认 LumenIM 项目运行的所有必要条件是否满足
- 检查缺少的组件或需要额外配置的项目
- 验证各组件配置信息是否正确
- 确保运行环境兼容
- 测试前后端服务及相关依赖服务能否正常启动和稳定运行

### 1.2 验证范围

| 类别 | 检查项 | 优先级 |
|------|--------|--------|
| 系统环境 | CPU、内存、磁盘、网络 | 必须 |
| Go 环境 | Go 安装、版本、环境变量、代理 | 必须 |
| Docker 环境 | Docker 安装、服务状态、镜像 | 必须 |
| 数据库服务 | MySQL 容器、连接、数据库 | 必须 |
| 缓存服务 | Redis 容器、连接 | 必须 |
| 后端服务 | 程序文件、配置、服务状态 | 必须 |
| 网络端口 | 端口监听、防火墙 | 必须 |
| 健康检查 | HTTP 接口、日志 | 必须 |

---

## 二、系统环境检查

### 2.1 检查点清单

| 检查项 | 验证方法 | 预期结果 | 状态 |
|--------|----------|----------|------|
| 操作系统 | `cat /etc/os-release` | Ubuntu 20.04+ | - |
| CPU 核心数 | `nproc` | ≥ 2 核 | - |
| 内存总量 | `free -h` | ≥ 2 GB | - |
| 磁盘空间 | `df -h /` | 使用率 < 80% | - |
| 系统运行时间 | `uptime -p` | 正常显示 | - |

### 2.2 验证命令

```bash
# 查看系统信息
cat /etc/os-release
uname -a

# CPU 检查
nproc
lscpu | grep -E "^CPU\(s\)|^Model name"

# 内存检查
free -h

# 磁盘检查
df -h /
```

---

## 三、网络连接检查

### 3.1 检查点清单

| 检查项 | 验证方法 | 预期结果 | 状态 |
|--------|----------|----------|------|
| 外网连接 | `ping -c 1 8.8.8.8` | 成功 | - |
| DNS 解析 | `nslookup github.com` | 正常解析 | - |
| 网络服务 | `netstat -tlnp` | 有监听端口 | - |

### 3.2 验证命令

```bash
# 外网连接测试
ping -c 3 -W 2 8.8.8.8

# DNS 解析测试
nslookup github.com
nslookup registry.npmmirror.com

# 查看监听端口
netstat -tlnp | head -20
ss -tlnp | head -20
```

---

## 四、Go 环境检查

### 4.1 检查点清单

| 检查项 | 验证方法 | 预期结果 | 状态 |
|--------|----------|----------|------|
| Go 安装 | `go version` | 1.20+ | - |
| Go 路径 | `which go` | /usr/local/go/bin/go | - |
| GOPATH | `go env GOPATH` | 已设置 | - |
| GOROOT | `go env GOROOT` | /usr/local/go | - |
| Go 代理 | `go env GOPROXY` | goproxy.cn | - |

### 4.2 验证命令

```bash
# Go 版本检查
go version

# Go 环境变量
go env GOROOT
go env GOPATH
go env GOPROXY
go env GOSUMDB

# Go 依赖下载测试
go mod download
```

### 4.3 Go 环境配置（如果需要）

```bash
# 安装 Go 1.22
wget https://go.dev/dl/go1.22.0.linux-amd64.tar.gz
sudo tar -C /usr/local -xzf go1.22.0.linux-amd64.tar.gz

# 配置环境变量
echo 'export PATH=$PATH:/usr/local/go/bin' >> ~/.bashrc
echo 'export GOPROXY=https://goproxy.cn,direct' >> ~/.bashrc
source ~/.bashrc
```

---

## 五、Docker 环境检查

### 5.1 检查点清单

| 检查项 | 验证方法 | 预期结果 | 状态 |
|--------|----------|----------|------|
| Docker 安装 | `docker --version` | 20.10+ | - |
| Docker 服务 | `systemctl status docker` | active (running) | - |
| Docker 镜像 | `docker images` | 有 mysql, redis | - |

### 5.2 验证命令

```bash
# Docker 版本
docker --version

# Docker 服务状态
systemctl status docker

# 查看 Docker 镜像
docker images

# 查看运行中的容器
docker ps

# 查看所有容器（包括停止的）
docker ps -a
```

### 5.3 Docker 配置

```bash
# Docker 服务管理
sudo systemctl start docker
sudo systemctl enable docker
sudo systemctl status docker
```

---

## 六、MySQL 数据库检查

### 6.1 检查点清单

| 检查项 | 验证方法 | 预期结果 | 状态 |
|--------|----------|----------|------|
| MySQL 容器 | `docker ps` | lumenim-mysql 运行中 | - |
| MySQL 连接 | `docker exec` 测试 | 连接成功 | - |
| 数据库存在 | `SHOW DATABASES` | go_chat 存在 | - |

### 6.2 验证命令

```bash
# 查看 MySQL 容器
docker ps | grep mysql

# MySQL 连接测试
docker exec lumenim-mysql mysql -u root -pwenming429 -e "SELECT 1"

# 查看数据库
docker exec lumenim-mysql mysql -u root -pwenming429 -e "SHOW DATABASES;"

# 查看表
docker exec lumenim-mysql mysql -u root -pwenming429 go_chat -e "SHOW TABLES;"
```

### 6.3 MySQL 容器配置

```bash
# 创建 MySQL 容器
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

# 导入数据库
docker exec -i lumenim-mysql mysql -u root -pwenming429 go_chat < backend/sql/*.sql
```

---

## 七、Redis 服务检查

### 7.1 检查点清单

| 检查项 | 验证方法 | 预期结果 | 状态 |
|--------|----------|----------|------|
| Redis 容器 | `docker ps` | lumenim-redis 运行中 | - |
| Redis 连接 | `redis-cli ping` | PONG | - |

### 7.2 验证命令

```bash
# 查看 Redis 容器
docker ps | grep redis

# Redis 连接测试
docker exec lumenim-redis redis-cli ping

# Redis 信息
docker exec lumenim-redis redis-cli info
```

### 7.3 Redis 容器配置

```bash
# 创建 Redis 容器
docker run -d \
  --name lumenim-redis \
  -p 6379:6379 \
  -v /var/lib/lumenim/redis:/data \
  redis:7.4.1 redis-server --appendonly yes
```

---

## 八、后端服务检查

### 8.1 检查点清单

| 检查项 | 验证方法 | 预期结果 | 状态 |
|--------|----------|----------|------|
| 应用目录 | `ls -la` | /var/www/lumenim/backend 存在 | - |
| 程序文件 | `ls -la lumenim` | lumenim 存在且可执行 | - |
| 配置文件 | `ls -la config.yaml` | config.yaml 存在 | - |
| Systemd 服务 | `systemctl status` | lumenim-backend active | - |
| 服务进程 | `systemctl show` | MainPID > 0 | - |

### 8.2 验证命令

```bash
# 查看应用目录
ls -la /var/www/lumenim/backend/

# 查看程序文件
ls -lh /var/www/lumenim/backend/lumenim
file /var/www/lumenim/backend/lumenim

# 查看配置文件
cat /var/www/lumenim/backend/config.yaml

# Systemd 服务状态
systemctl status lumenim-backend
systemctl is-active lumenim-backend

# 查看服务进程
systemctl show lumenim-backend -p MainPID,ExecStart
```

### 8.3 Systemd 服务配置

```bash
# 创建服务文件
sudo nano /etc/systemd/system/lumenim-backend.service
```

```ini
[Unit]
Description=LumenIM Backend Service
After=network.target docker.service mysql.service redis.service
Wants=mysql.service redis.service

[Service]
Type=simple
User=root
Group=root
WorkingDirectory=/var/www/lumenim/backend
ExecStart=/var/www/lumenim/backend/lumenim
Restart=always
RestartSec=5s
LimitNOFILE=65536
StandardOutput=append:/var/www/lumenim/backend/logs/stdout.log
StandardError=append:/var/www/lumenim/backend/logs/stderr.log
Environment="GOPROXY=https://goproxy.cn,direct"
Environment="GOSUMDB=off"

[Install]
WantedBy=multi-user.target
```

```bash
# 重新加载并启动服务
sudo systemctl daemon-reload
sudo systemctl enable lumenim-backend
sudo systemctl start lumenim-backend
sudo systemctl status lumenim-backend
```

---

## 九、端口监听检查

### 9.1 检查点清单

| 端口 | 服务 | 验证方法 | 预期结果 | 状态 |
|------|------|----------|----------|------|
| 9501 | 后端 HTTP | `netstat` | 已监听 | - |
| 9502 | 后端 WebSocket | `netstat` | 已监听 | - |
| 3306 | MySQL | `netstat` | 已监听 | - |
| 6379 | Redis | `netstat` | 已监听 | - |

### 9.2 验证命令

```bash
# 查看所有监听端口
netstat -tlnp
ss -tlnp

# 查看特定端口
netstat -tlnp | grep 9501
ss -tlnp | grep 9501

# 查看端口占用
lsof -i :9501
```

---

## 十、健康检查

### 10.1 检查点清单

| 检查项 | 验证方法 | 预期结果 | 状态 |
|--------|----------|----------|------|
| HTTP 健康检查 | `curl /health` | HTTP 200 | - |
| 响应时间 | - | < 1 秒 | - |
| 日志无错误 | `grep` panic/fatal | 无关键错误 | - |

### 10.2 验证命令

```bash
# HTTP 健康检查
curl -s http://localhost:9501/api/v1/health

# 完整健康检查（带详细信息）
curl -v http://localhost:9501/api/v1/health

# 响应时间测试
time curl -s http://localhost:9501/api/v1/health

# 查看服务日志
tail -f /var/www/lumenim/backend/logs/stdout.log
journalctl -u lumenim-backend -f
```

### 10.3 预期响应格式

```json
{
    "code": 200,
    "msg": "success",
    "data": {
        "status": "ok",
        "version": "1.0.0",
        "uptime": "24h"
    }
}
```

---

## 十一、防火墙检查

### 11.1 检查点清单

| 检查项 | 验证方法 | 预期结果 | 状态 |
|--------|----------|----------|------|
| UFW 状态 | `ufw status` | inactive 或允许 9501 | - |
| iptables 规则 | `iptables -L` | 不阻止必要端口 | - |

### 11.2 验证命令

```bash
# UFW 状态
ufw status verbose

# 开放端口（如需要）
sudo ufw allow 9501/tcp
sudo ufw allow 9502/tcp

# iptables 规则
sudo iptables -L -n | head -30
```

---

## 十二、自动化验证脚本使用说明

### 12.1 脚本位置
```
software/scripts/environment-check.sh
```

### 12.2 执行方法

```bash
# 1. 拉取最新代码
cd /var/www/lumenim
git pull

# 2. 添加执行权限
chmod +x software/scripts/environment-check.sh

# 3. 以 root 权限运行
sudo ./software/scripts/environment-check.sh
```

### 12.3 脚本功能

脚本自动检查以下 13 个方面：

1. ✅ 系统环境（CPU、内存、磁盘、运行时间）
2. ✅ 网络连接（外网、DNS）
3. ✅ Go 环境（安装、版本、代理）
4. ✅ Docker 环境（安装、服务、镜像）
5. ✅ MySQL 数据库（容器、连接、数据库）
6. ✅ Redis 缓存（容器、连接）
7. ✅ 后端服务（目录、文件、配置）
8. ✅ 端口监听（9501、9502、3306、6379）
9. ✅ 健康检查（HTTP、响应时间、日志）
10. ✅ 防火墙（UFW、iptables）
11. ✅ 依赖完整性（go.mod、vendor、sql）
12. ✅ 性能测试（并发连接）
13. ✅ 汇总报告（通过/失败/警告统计）

### 12.4 预期输出

```
============================================================
  LumenIM 运行环境全面验证
============================================================
验证时间: 2026-04-22 09:51:00
主机名: lumenimserver
用户: root
工作目录: /var/www/lumenim

━━━ 一、系统环境检查 ━━━
  ✓ CPU 核心数: 4
  ✓ 内存总量: 7.6G (已用: 2.1G, 可用: 5.5G)
  ✓ 磁盘使用率: 45% (可用: 50G)
  ✓ 系统运行时间: up 3 days

━━━ 二、网络连接检查 ━━━
  ✓ 外网连接: 正常
  ✓ DNS 解析: github.com 正常

━━━ 三、Go 环境检查 ━━━
  ✓ Go 已安装: go1.22.0
  ✓ Go 代理配置: https://goproxy.cn,direct

━━━ 四、Docker 环境检查 ━━━
  ✓ Docker 已安装: 24.0.0
  ✓ Docker 服务: 运行中
  ✓ Docker 镜像数量: 5

━━━ 五、数据库服务检查 (MySQL) ━━━
  ✓ MySQL 容器: lumenim-mysql
  ✓ MySQL 容器状态: 运行中
  ✓ MySQL 连接: 成功
  ✓ 目标数据库 go_chat: 存在

━━━ 六、Redis 服务检查 ━━━
  ✓ Redis 容器: lumenim-redis
  ✓ Redis 连接: PONG

━━━ 七、后端服务检查 ━━━
  ✓ 应用目录存在: /var/www/lumenim/backend
  ✓ 后端程序: lumenim 存在
  ✓ 后端程序: 有执行权限
  ✓ Systemd 服务: lumenim-backend 已注册
  ✓ Systemd 服务: 运行中

━━━ 八、端口监听检查 ━━━
  ✓ 后端端口 9501: 已监听
  ✓ MySQL 端口 3306: 已监听
  ✓ Redis 端口 6379: 已监听

━━━ 九、后端健康检查 ━━━
  ✓ 健康检查 HTTP 200: 正常
  ✓ 响应时间: 0.023s (良好)
  ✓ 日志中无明显错误

============================================================
检查项目统计:
─────────────────────────────────────────────────────────
  通过: 22
  失败: 0
  警告: 0
─────────────────────────────────────────────────────────

✅ 环境验证通过！所有检查项正常。
```

---

## 十三、常见问题及解决方案

### 问题 1: Go 未安装

**症状**: `go: command not found`

**解决方案**:
```bash
wget https://go.dev/dl/go1.22.0.linux-amd64.tar.gz
sudo tar -C /usr/local -xzf go1.22.0.linux-amd64.tar.gz
echo 'export PATH=$PATH:/usr/local/go/bin' >> ~/.bashrc
source ~/.bashrc
```

### 问题 2: Docker 服务未运行

**症状**: `Cannot connect to the Docker daemon`

**解决方案**:
```bash
sudo systemctl start docker
sudo systemctl enable docker
```

### 问题 3: MySQL 连接失败

**症状**: `Access denied for user 'root'@'localhost'`

**解决方案**:
```bash
# 检查容器状态
docker ps -a | grep mysql

# 重置密码或重建容器
docker stop lumenim-mysql
docker rm lumenim-mysql
docker run -d --name lumenim-mysql \
  -e MYSQL_ROOT_PASSWORD=wenming429 \
  -e MYSQL_DATABASE=go_chat \
  -p 3306:3306 \
  mysql:8.0.35
```

### 问题 4: 后端服务启动失败

**症状**: `systemctl status` 显示 failed

**解决方案**:
```bash
# 查看详细日志
journalctl -u lumenim-backend -xe --no-pager

# 手动前台运行查看错误
cd /var/www/lumenim/backend
./lumenim

# 常见问题:
# - 配置文件缺失: 创建 config.yaml
# - 端口被占用: 修改端口或杀死占用进程
# - 数据库未连接: 检查 MySQL/Redis 是否运行
```

### 问题 5: 端口未监听

**症状**: `curl localhost:9501` 连接被拒绝

**解决方案**:
```bash
# 检查服务是否运行
systemctl status lumenim-backend

# 检查端口占用
netstat -tlnp | grep 9501

# 查看防火墙规则
ufw status
```

---

## 十四、验证清单汇总

| 序号 | 检查项 | 必须 | 状态 |
|------|--------|------|------|
| 1 | 操作系统: Ubuntu 20.04+ | ✅ | ☐ |
| 2 | CPU: ≥ 2 核 | ✅ | ☐ |
| 3 | 内存: ≥ 2 GB | ✅ | ☐ |
| 4 | 磁盘: 使用率 < 80% | ✅ | ☐ |
| 5 | 网络: 外网可连接 | ✅ | ☐ |
| 6 | Go: 1.20+ 已安装 | ✅ | ☐ |
| 7 | Docker: 20.10+ 已安装 | ✅ | ☐ |
| 8 | MySQL: 容器运行中 | ✅ | ☐ |
| 9 | Redis: 容器运行中 | ✅ | ☐ |
| 10 | 后端程序: lumenim 存在 | ✅ | ☐ |
| 11 | 配置文件: config.yaml 存在 | ✅ | ☐ |
| 12 | Systemd: 服务已注册 | ✅ | ☐ |
| 13 | Systemd: 服务运行中 | ✅ | ☐ |
| 14 | 端口 9501: 已监听 | ✅ | ☐ |
| 15 | 健康检查: HTTP 200 | ✅ | ☐ |
| 16 | 响应时间: < 1 秒 | ✅ | ☐ |

---

**验证完成日期**: _____________

**验证人员**: _____________

**验证结果**: ☐ 通过  ☐ 部分通过  ☐ 未通过

**备注**: _______________________________________________
