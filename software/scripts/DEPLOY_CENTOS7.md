# LumenIM CentOS 7 部署指南

**文档版本**: 1.0.0  
**更新日期**: 2026-04-08  
**适用系统**: CentOS 7.x

---

## 一、兼容性分析

### 1.1 核心问题

CentOS 7 存在以下兼容性限制：

| 软件 | 官方要求 | CentOS 7 默认 | 问题 |
|------|----------|---------------|------|
| glibc | 2.28+ | 2.17 | **不兼容** |
| Node.js 22.x | glibc 2.28 | 2.17 | **无法运行** |
| Go 1.25.x | glibc 2.17 | 2.17 | 兼容 |
| MySQL 8.0 | glibc 2.17 | 2.17 | 兼容 |

### 1.2 解决方案

| 方案 | 说明 | 优点 | 缺点 |
|------|------|------|------|
| **A. Docker 部署（推荐）** | 使用容器运行高版本组件 | 兼容性最好，无需修改系统 | 需要 Docker |
| **B. 使用兼容版本** | Go 1.21 + Node.js 18 | 稳定可靠 | 版本较旧 |
| **C. 升级 glibc** | 手动升级 glibc 到 2.28 | 可使用最新版 | 风险较高 |

### 1.3 推荐版本

本方案采用 **方案 A（Docker）+ 方案 B（兼容版本）** 混合模式：

| 软件 | 使用版本 | 说明 |
|------|----------|------|
| Go | 1.21.14 | 兼容 CentOS 7 |
| Node.js | 18.20.5 | LTS，CentOS 7 兼容 |
| MySQL | 8.0.35 | Docker 容器运行 |
| Redis | 7.4.1 | Docker 容器运行 |
| pnpm | 8.15.0 | 兼容 Node.js 18 |

---

## 二、系统要求

### 2.1 硬件要求

| 项目 | 最低要求 | 推荐配置 |
|------|----------|----------|
| CPU | 2 核 | 4 核+ |
| 内存 | 4 GB | 8 GB+ |
| 磁盘 | 30 GB | 50 GB+ SSD |
| 系统盘 | 20 GB | - |

### 2.2 软件要求

| 项目 | 要求 |
|------|------|
| 操作系统 | CentOS 7.x (x86_64) |
| 内核 | 3.10+ |
| Bash | 4.0+ |
| sudo/root | 需要 |
| 网络 | 需访问外网或提前准备离线包 |

### 2.3 端口要求

| 端口 | 服务 | 说明 |
|------|------|------|
| 9501 | HTTP API | 后端 |
| 9502 | WebSocket | 后端 |
| 9505 | TCP | 后端 |
| 3306 | MySQL | 数据库 |
| 6379 | Redis | 缓存 |
| 5173 | Frontend | 前端 |

---

## 三、部署方案

### 3.1 方案一：Docker 部署（推荐）

适用于大多数生产环境，使用容器运行 MySQL 和 Redis：

```bash
# 1. 完整部署（推荐）
sudo ./install-centos7.sh --all
```

### 3.2 方案二：纯本地部署

适用于无法使用 Docker 的环境：

```bash
sudo ./install-centos7.sh --all --no-docker
```

### 3.3 分步部署

```bash
# 1. 检查环境
./install-centos7.sh --check

# 2. 安装系统依赖
sudo ./install-centos7.sh --deps

# 3. 安装运行时
sudo ./install-centos7.sh --go --node

# 4. 安装数据库
sudo ./install-centos7.sh --mysql --redis

# 5. 启动服务
sudo ./install-centos7.sh --services
```

---

## 四、Docker 部署详解

### 4.1 为什么选择 Docker

1. **解决 glibc 兼容问题**：容器内 glibc 版本可控
2. **环境隔离**：不影响系统其他服务
3. **便于管理**：使用 systemd 管理
4. **版本灵活**：可使用最新版本

### 4.2 Docker 安装

```bash
# 安装 Docker
sudo ./install-centos7.sh --all

# 或手动安装
sudo yum install -y docker-ce docker-ce-cli containerd.io
sudo systemctl start docker
sudo systemctl enable docker
```

### 4.3 容器管理

```bash
# 查看容器
docker ps -a

# 启动容器
docker start lumenim-mysql
docker start lumenim-redis

# 停止容器
docker stop lumenim-mysql
docker stop lumenim-redis

# 查看日志
docker logs lumenim-mysql
docker logs lumenim-redis

# 进入容器
docker exec -it lumenim-mysql bash
docker exec -it lumenim-redis redis-cli
```

---

## 五、版本兼容说明

### 5.1 Go 版本对比

| 版本 | CentOS 7 兼容性 | 推荐 |
|------|----------------|------|
| 1.25.x | 需要 glibc 2.17 | ❌ 不兼容 |
| 1.23.x | 需要 glibc 2.17 | ⚠️ 需测试 |
| 1.21.x | 需要 glibc 2.17 | ✅ 推荐 |
| 1.19.x | 需要 glibc 2.17 | ✅ 可用 |

**本方案使用**：Go 1.21.14

### 5.2 Node.js 版本对比

| 版本 | CentOS 7 兼容性 | 推荐 |
|------|----------------|------|
| 22.x | 需要 glibc 2.28 | ❌ 不兼容 |
| 20.x | 需要 glibc 2.18 | ❌ 不兼容 |
| 18.x LTS | 需要 glibc 2.17 | ✅ 推荐 |
| 16.x | 需要 glibc 2.17 | ✅ 可用 |

**本方案使用**：Node.js 18.20.5 LTS

### 5.3 前端依赖兼容性

由于 Node.js 降级到 18.x，部分依赖可能需要调整版本：

| 依赖 | 推荐版本 |
|------|----------|
| electron | 28.x |
| vite | 5.x |
| node-sass | 8.x |

---

## 六、脚本参数说明

### 6.1 可用参数

```bash
./install-centos7.sh [参数]
```

| 参数 | 说明 |
|------|------|
| `-h, --help` | 显示帮助 |
| `-c, --check` | 检查环境 |
| `-d, --deps` | 安装系统依赖 |
| `-g, --go` | 安装 Go |
| `-n, --node` | 安装 Node.js |
| `-m, --mysql` | 安装 MySQL |
| `-r, --redis` | 安装 Redis |
| `-p, --protobuf` | 安装 protobuf |
| `-s, --services` | 启动服务 |
| `-a, --all` | 完整安装 |
| `--no-docker` | 不使用 Docker |
| `--offline=目录` | 离线包目录 |

### 6.2 使用示例

```bash
# 完整安装（推荐）
sudo ./install-centos7.sh --all

# 不使用 Docker
sudo ./install-centos7.sh --all --no-docker

# 仅检查环境
./install-centos7.sh --check

# 仅安装运行时
sudo ./install-centos7.sh --go --node
```

---

## 七、服务管理

### 7.1 systemd 服务

```bash
# 查看状态
systemctl status lumenim-backend
systemctl status lumenim-frontend

# 启动
systemctl start lumenim-backend
systemctl start lumenim-frontend

# 重启
systemctl restart lumenim-backend
systemctl restart lumenim-frontend

# 停止
systemctl stop lumenim-backend
systemctl stop lumenim-frontend

# 开机自启
systemctl enable lumenim-backend
systemctl enable lumenim-frontend
```

### 7.2 Docker 容器

```bash
# 启动
docker start lumenim-mysql
docker start lumenim-redis

# 停止
docker stop lumenim-mysql
docker stop lumenim-redis

# 重启
docker restart lumenim-mysql
docker restart lumenim-redis

# 日志
docker logs -f lumenim-mysql
docker logs -f lumenim-redis
```

### 7.3 端口检查

```bash
# 检查端口占用
lsof -i:9501
lsof -i:9502
lsof -i:9505
lsof -i:3306
lsof -i:6379
```

---

## 八、常见问题排查

### 8.1 Node.js 安装失败

**错误**：
```
node: /lib64/libstdc++.so.6: version `GLIBCXX_3.4.21' not found
```

**解决方案**：
```bash
# 升级 libstdc++
yum install -y libstdc++.so.6
```

### 8.2 Docker 安装失败

**错误**：
```
No package docker-ce available.
```

**解决方案**：
```bash
# 安装 EPEL 源
yum install -y epel-release

# 清除缓存
yum clean all
yum makecache
```

### 8.3 MySQL 容器无法启动

**错误**：
```
docker: Error response from daemon: driver failed programming external connectivity on endpoint
```

**解决方案**：
```bash
# 检查端口占用
netstat -tlnp | grep 3306

# 停止原有 MySQL 服务
systemctl stop mysqld 2>/dev/null
```

### 8.4 Node.js 版本问题

**错误**：
```
engine strict mode error
```

**解决方案**：
```bash
# 忽略引擎检查
npm install --engine-strict=false

# 或使用 pnpm
pnpm install --ignore-engines
```

### 8.5 SELinux 阻止服务

**错误**：
```
Permission denied
```

**解决方案**：
```bash
# 临时禁用
setenforce 0

# 永久修改
sed -i 's/SELINUX=enforcing/SELINUX=permissive/' /etc/selinux/config
reboot
```

---

## 九、数��备份与迁移

### 9.1 MySQL 数据备份

```bash
# Docker 环境
docker exec lumenim-mysql mysqldump -u root -p"$MYSQL_ROOT_PASSWORD" go_chat > /backup/go_chat.sql

# 本地环境
mysqldump -u root -p"$MYSQL_ROOT_PASSWORD" go_chat > /backup/go_chat.sql
```

### 9.2 Redis 数据备份

```bash
# Docker 环境
docker exec lumenim-redis redis-cli SAVE
docker cp lumenim-redis:/data/dump.rdb /backup/

# 本地环境
redis-cli SAVE
cp /var/lib/redis/dump.rdb /backup/
```

### 9.3 项目文件备份

```bash
# 备份项目目录
rsync -avz /var/www/lumenim/ /backup/lumenim/
```

---

## 十、性能优化建议

### 10.1 内核参数优化

```bash
# 添加到 /etc/sysctl.conf
cat >> /etc/sysctl.conf << EOF
# 网络优化
net.core.somaxconn = 65535
net.ipv4.tcp_max_syn_backlog = 65535

# 文件描述符
fs.file-max = 65535
EOF

# 生效
sysctl -p
```

### 10.2 资源限制

```bash
# 添加到 /etc/security/limits.conf
cat >> /etc/security/limits.conf << EOF
www-data soft nofile 65535
www-data hard nofile 65535
www-data soft nproc 65535
www-data hard nproc 65535
EOF
```

### 10.3 Docker 资源限制

```bash
# MySQL 内存限制
docker update -m 512m --memory-swap 1g lumenim-mysql

# Redis 内存限制
docker update -m 256m --memory-swap 512m lumenim-redis
```

---

## 十一、回滚与卸载

### 11.1 停止服务

```bash
# 停止 systemd 服务
systemctl stop lumenim-backend
systemctl stop lumenim-frontend

# 停止 Docker 容器
docker stop lumenim-mysql
docker stop lumenim-redis
```

### 11.2 卸载

```bash
# 移除服务
rm /etc/systemd/system/lumenim-*.service
systemctl daemon-reload

# 移除容器
docker rm -f lumenim-mysql lumenim-redis

# 移除 Docker
yum remove -y docker-ce docker-ce-cli containerd.io

# 移除安装目录
rm -rf /opt/lumenim
rm -rf /var/www/lumenim
rm -rf /var/lib/lumenim
```

---

## 十二、快速参考

### 12.1 环境检查命令

```bash
# 系统信息
cat /etc/centos-release
uname -r
free -h
df -h

# glibc 版本
ldd --version

# Docker 版本
docker --version

# Node.js 版本
node --version

# Go 版本
go version
```

### 12.2 服务管理命令

```bash
# 启动所有服务
sudo systemctl start lumenim-backend
sudo systemctl start lumenim-frontend

# 查看状态
systemctl status lumenim-backend

# 查看日志
journalctl -u lumenim-backend -f
```

### 12.3 访问地址

```
前端: http://localhost:5173
后端 API: http://localhost:9501
WebSocket: ws://localhost:9502
MySQL: localhost:3306
Redis: localhost:6379
```

---

**文档结束**