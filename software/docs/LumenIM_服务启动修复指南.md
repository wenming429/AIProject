# LumenIM 服务启动问题排查与修复指南

## 一、问题概述

**服务器**: 192.168.23.131
**问题现象**: WebSocket 连接失败，502 Bad Gateway 错误
**根本原因**: Redis 配置错误导致 LumenIM 服务无法启动

---

## 二、服务架构

```
┌─────────────────────────────────────────────────────────┐
│                      Nginx (80/443)                     │
└─────────────────────────┬─────────────────────────────┘
                          │
          ┌───────────────┼───────────────┐
          │               │               │
          ▼               ▼               ▼
    ┌──────────┐   ┌──────────┐   ┌──────────┐
    │  MySQL    │   │  Redis   │   │  MinIO   │
    │  (3306)   │   │  (6379)  │   │  (9000)  │
    └──────────┘   └──────────┘   └──────────┘
          │               │
          └───────┬───────┘
                  ▼
    ┌─────────────────────┐    ┌─────────────────────┐
    │  LumenIM HTTP (9501)│    │  LumenIM Comet (9502)│
    │       Web API       │◄──►│     WebSocket        │
    └─────────────────────┘    └─────────────────────┘
```

---

## 三、排查步骤（按顺序）

### 步骤 1: SSH 连接测试

```bash
ssh wenming429@192.168.23.131
```

### 步骤 2: 检查磁盘空间

```bash
sudo df -h /
```

**关键指标**: 使用率应 < 95%

| 使用率 | 状态 | 处理 |
|--------|------|------|
| < 90% | ✅ 正常 | 无需处理 |
| 90-95% | ⚠️ 警告 | 清理日志/缓存 |
| > 95% | ❌ 严重 | 必须清理 |

**清理命令**:
```bash
# 清理 apt 缓存
sudo apt clean
sudo apt autoremove -y

# 清理日志
sudo journalctl --vacuum-time=7d
sudo find /var/log -name "*.gz" -delete

# 清理临时文件
sudo rm -rf /tmp/*
sudo rm -rf /var/tmp/*
```

### 步骤 3: 检查端口监听状态

```bash
sudo ss -tlnp | grep -E "3306|6379|9000|9501|9502"
```

**预期结果**:

| 端口 | 服务 | 必须监听 |
|------|------|----------|
| 3306 | MySQL | ✅ |
| 6379 | Redis | ✅ |
| 9000 | MinIO | ✅ |
| 9501 | LumenIM HTTP | ✅ |
| 9502 | LumenIM Comet | ✅ |

### 步骤 4: 检查服务进程

```bash
ps aux | grep lumenim | grep -v grep
```

**预期结果**: 应看到 `lumenim http` 和 `lumenim comet` 进程

### 步骤 5: 检查 Systemd 服务状态

```bash
sudo systemctl status lumenim-backend
sudo systemctl status lumenim-comet
```

**状态含义**:
- `active (running)` ✅ 正常
- `inactive (dead)` ❌ 需要启动
- `failed` ❌ 需要排查错误

### 步骤 6: 检查 Redis 状态

```bash
# 基本测试
sudo redis-cli ping

# 写入测试
sudo redis-cli SET test OK
sudo redis-cli GET test

# 检查配置
sudo redis-cli CONFIG GET stop-writes-on-bgsave-error
sudo redis-cli CONFIG GET dir
```

**问题识别**:
```
MISCONF Redis is configured to save RDB snapshots,
but it's currently unable to persist to disk.
```

→ 表示 `stop-writes-on-bgsave-error` 为 `yes`，但 Redis 无法写入磁盘

### 步骤 7: 查看服务日志

```bash
# LumenIM 日志
tail -50 /tmp/lumenim_http.log
tail -50 /tmp/lumenim_comet.log

# Systemd 日志
sudo journalctl -u lumenim-comet -n 50 --no-pager
sudo journalctl -u lumenim-backend -n 50 --no-pager

# Redis 日志
sudo tail -30 /var/log/redis/redis-server.log
```

---

## 四、解决方案

### 方案 A: 快速修复（临时）

适用于临时解决问题，后续需执行永久修复：

```bash
# 1. 临时修复 Redis
sudo redis-cli CONFIG SET stop-writes-on-bgsave-error no

# 2. 停止现有进程
sudo pkill -f lumenim

# 3. 启动 HTTP 服务
cd /var/www/lumenim/backend
sudo ./lumenim http > /tmp/http.log 2>&1 &

# 4. 启动 WebSocket 服务
sudo ./lumenim comet > /tmp/comet.log 2>&1 &

# 5. 验证端口
sudo ss -tlnp | grep -E "9501|9502"
```

### 方案 B: 永久修复（推荐）

适用于生产环境：

```bash
# 1. 编辑 Redis 配置
sudo nano /etc/redis/redis.conf

# 2. 找到并修改以下配置
stop-writes-on-bgsave-error no
dir /var/lib/redis

# 3. 创建数据目录并设置权限
sudo mkdir -p /var/lib/redis
sudo chown redis:redis /var/lib/redis

# 4. 重启 Redis
sudo systemctl restart redis-server

# 5. 验证 Redis
sudo redis-cli ping
sudo redis-cli SET test OK

# 6. 重启 LumenIM 服务
sudo systemctl restart lumenim-backend
sudo systemctl restart lumenim-comet

# 7. 验证服务
sudo ss -tlnp | grep -E "9501|9502"
```

### 方案 C: Systemd 服务修复

如果 Systemd 服务无法启动：

```bash
# 1. 重新加载 systemd
sudo systemctl daemon-reload

# 2. 启用服务
sudo systemctl enable lumenim-backend
sudo systemctl enable lumenim-comet

# 3. 启动服务
sudo systemctl start lumenim-backend
sudo systemctl start lumenim-comet

# 4. 检查状态
sudo systemctl status lumenim-backend
sudo systemctl status lumenim-comet
```

---

## 五、验证清单

服务修复后，按以下清单逐项验证：

### 5.1 基础服务验证

```bash
# MySQL
sudo mysqladmin ping -h localhost -uroot -proot123456

# Redis
sudo redis-cli ping
sudo redis-cli SET verify OK

# MinIO
curl http://localhost:9000/minio/health/live

# Nginx
sudo systemctl status nginx
```

### 5.2 LumenIM 服务验证

```bash
# 端口检查
sudo ss -tlnp | grep -E "9501|9502"

# 进程检查
ps aux | grep lumenim | grep -v grep

# HTTP API 测试
curl http://localhost:9501/api/v1/health

# WebSocket 测试（需要 wscat）
wscat -c ws://localhost:9502
```

### 5.3 外部访问验证

在浏览器中访问：
- Web 登录: `http://192.168.23.131`
- WebSocket 连接应成功建立

---

## 六、关键配置参考

### 6.1 Redis 配置关键项

```conf
# /etc/redis/redis.conf

# 数据目录（必须有写权限）
dir /var/lib/redis

# RDB 快照（生产环境建议设为 no）
stop-writes-on-bgsave-error no

# 绑定地址
bind 127.0.0.1

# 端口
port 6379
```

### 6.2 LumenIM 配置路径

```bash
# 二进制文件位置
/var/www/lumenim/backend/lumenim

# 配置文件位置
/var/www/lumenim/backend/config.yaml

# 日志位置
/tmp/lumenim_http.log
/tmp/lumenim_comet.log
```

### 6.3 Systemd 服务文件

```ini
# /etc/systemd/system/lumenim-backend.service
[Unit]
Description=LumenIM Backend Service
After=network.target mysql.service redis.service

[Service]
Type=simple
User=wenming429
WorkingDirectory=/var/www/lumenim/backend
ExecStart=/var/www/lumenim/backend/lumenim http
Restart=always

[Install]
WantedBy=multi-user.target
```

---

## 七、常见问题与解决方案

| 问题现象 | 根本原因 | 解决方案 |
|----------|----------|----------|
| 502 Bad Gateway | LumenIM 未运行 | 启动 lumenim 服务 |
| WebSocket 连接失败 | 9502 端口未监听 | 检查 comet 进程和日志 |
| Redis MISCONF 错误 | 配置错误 | 修改 stop-writes-on-bgsave-error |
| 磁盘 100% | 空间不足 | 清理日志和缓存 |
| 进程权限拒绝 | sudo 权限 | 使用 sudo 启动 |

---

## 八、预防措施

### 8.1 定期检查

```bash
# 每周检查一次
crontab -e

# 添加
0 9 * * 1 df -h / && ss -tlnp | grep -E "9501|9502"
```

### 8.2 监控告警

建议设置：
- 磁盘使用率 > 85% 告警
- 服务端口异常告警
- Systemd 服务失败告警

### 8.3 日志管理

```bash
# 配置日志轮转
sudo nano /etc/logrotate.d/lumenim

# 内容
/tmp/lumenim_*.log {
    daily
    rotate 7
    compress
    delaycompress
    missingok
    notifempty
    create 0644 wenming429 wenming429
}
```

---

## 九、修复流程速查表

```
发现问题
   │
   ├─► 步骤1: 检查磁盘 df -h /
   │         └─► 清理空间（如果 > 90%）
   │
   ├─► 步骤2: 检查端口 ss -tlnp
   │         └─► 9502 未监听 → 启动 comet
   │
   ├─► 步骤3: 检查 Redis redis-cli ping
   │         └─► MISCONF 错误 → 修复配置
   │
   ├─► 步骤4: 查看日志 tail -f
   │         └─► 根据错误信息修复
   │
   └─► 步骤5: 验证服务
             └─► 外部访问测试
```

---

## 十、联系方式与资源

- **项目地址**: https://github.com/wenming429/AIProject
- **SSH**: wenming429@192.168.23.131
- **LumenIM 路径**: /var/www/lumenim/backend

---

*文档生成时间: 2026-04-27*
*最后更新: 服务修复完成，所有端口正常监听*
