# Lumen IM 本地部署指南

## 部署状态总览

| 组件 | 状态 | 位置/说明 |
|------|------|----------|
| 前端代码 | ✅ 已完成 | `front/` |
| 前端构建 | ✅ 已完成 | `front/dist/` |
| 后端代码 | ✅ 已完成 | `backend/` |
| Go 环境 | ✅ 已完成 | `C:\Go` (v1.24.0) |
| 后端编译 | ✅ 已完成 | `backend/lumenim.exe` |
| MySQL | ✅ 已完成 | 端口 3306, 密码: wenming429 |
| 数据库 | ✅ 已完成 | `go_chat` 数据库已创建并初始化 |
| MinIO | ✅ 已完成 | 端口 9000/9090, 用户: minioadmin |
| Redis | ✅ 已完成 | 端口 6379 (Windows 原生 Redis) |

---

## 快速启动

### 方式一：使用一键启动脚本

```bash
cd d:\学习资料\AI_Projects\LumenIM
start-all.bat
```

### 方式二：手动分步启动

#### 1. 启动 MySQL、Redis、MinIO

这些服务应该已经在后台运行，如需重启：

```powershell
# MySQL - 通常自动启动
net start MySQL

# Redis - 通常自动启动
net start Redis

# MinIO (新窗口执行)
cd d:\学习资料\AI_Projects\LumenIM\backend
$env:MINIO_ROOT_USER="minioadmin"
$env:MINIO_ROOT_PASSWORD="minioadmin123"
.\minio.exe server data --console-address ":9090"
```

#### 2. 配置 MinIO Bucket（新窗口执行）

```powershell
cd d:\学习资料\AI_Projects\LumenIM\backend
.\mc.exe alias set local http://localhost:9000 minioadmin minioadmin123
.\mc.exe mb local/im-static --ignore-existing
.\mc.exe mb local/im-private --ignore-existing
```

#### 3. 启动后端服务

```powershell
cd d:\学习资料\AI_Projects\LumenIM\backend

# HTTP API 服务 (9501)
.\lumenim.exe http

# WebSocket 服务 (9502) - 新窗口执行
.\lumenim.exe comet
```

#### 4. 启动前端

```powershell
cd d:\学习资料\AI_Projects\LumenIM\front
pnpm dev
```

---

## 服务端口

| 服务 | 端口 | 说明 |
|------|------|------|
| 前端开发服务器 | 5173 | Vite 开发服务器 |
| 后端 HTTP API | 9501 | REST API (PID: 48820) |
| 后端 WebSocket | 9502 | 实时通信 (PID: 27192) |
| MySQL | 3306 | 数据库 |
| Redis | 6379 | 缓存/消息队列 |
| MinIO API | 9000 | 对象存储 API |
| MinIO Console | 9090 | 对象存储控制台 |

---

## 配置文件位置

- 后端配置: `backend/config.yaml`
- 前端配置: `front/.env` (开发环境)
- 前端配置: `front/.env.production` (生产环境)

### 前端环境变量说明

```env
VITE_BASE_API=http://localhost:9501    # 后端 API 地址
VITE_SOCKET_API=ws://localhost:9502    # WebSocket 地址
```

---

## 默认测试账号

访问 http://localhost:5173

| 用户 | 手机号 | 密码 | 岗位 |
|------|--------|------|------|
| XiaoMing | 13800000001 | admin123 | CTO |
| XiaoHong | 13800000002 | admin123 | Product Manager |
| ZhangSan | 13800000003 | admin123 | Tech Lead |
| LiSi | 13800000004 | admin123 | Developer |
| WangWu | 13800000005 | admin123 | Developer |
| ZhaoLiu | 13800000006 | admin123 | Designer |
| SunQi | 13800000007 | admin123 | Designer |
| ZhouBa | 13800000008 | admin123 | Designer |

---

## 数据库初始化

### 基础测试数据
```bash
mysql -u root -pwenming429 go_chat < test_data.sql
```

### 系统资源数据
```bash
mysql -u root -pwenming429 go_chat < system_data.sql
```

---

## 故障排除

### 检查服务状态

```powershell
# 查看所有端口占用
netstat -ano | findstr ":9501"
netstat -ano | findstr ":9502"
netstat -ano | findstr ":3306"
netstat -ano | findstr ":6379"
netstat -ano | findstr ":9000"

# 查看进程信息
Get-Process -Id <PID>
```

### Redis 连接失败
```bash
# 检查 Redis 服务状态
Get-Service Redis

# 重启 Redis
net stop Redis
net start Redis

# 测试连接
redis-cli ping
# 返回 PONG 表示连接成功
```

### 后端启动失败
```bash
cd d:\学习资料\AI_Projects\LumenIM\backend
.\lumenim.exe http
# 查看终端输出的错误信息
```

### MinIO 无法访问
```bash
# 检查 MinIO 进程
Get-Process minio

# 检查端口
Test-NetConnection localhost -Port 9000
```

---

## 项目结构

```
d:\学习资料\AI_Projects\LumenIM\
├── front/                    # Vue3 前端
│   ├── src/
│   │   ├── apis/           # API 接口
│   │   ├── components/      # 组件
│   │   ├── store/          # 状态管理
│   │   ├── plugins/        # 插件 (WebSocket)
│   │   └── views/          # 页面视图
│   ├── dist/               # 生产构建
│   ├── .env                # 开发环境变量
│   └── .env.production     # 生产环境变量
├── backend/                 # Go 后端
│   ├── lumenim.exe         # 编译后的可执行文件
│   ├── minio.exe           # MinIO 对象存储
│   ├── mc.exe              # MinIO 客户端
│   ├── config.yaml         # 后端配置
│   ├── data/               # MinIO 数据目录
│   └── sql/
│       └── lumenim.sql     # 数据库初始化脚本
├── test_data.sql           # 基础测试数据
├── system_data.sql         # 系统资源数据
├── docker-compose.yaml     # Docker 编排配置
├── daemon.json             # Docker 镜像加速配置
├── start-all.bat           # 一键启动脚本
├── start-backend.bat       # 启动后端脚本
├── start-http.bat          # 启动 HTTP 服务脚本
├── setup-redis.bat         # Redis 安装辅助脚本
└── DEPLOYMENT_GUIDE.md     # 本文档
```

---

## 组织架构

系统内置了完整的组织架构数据：

```
Headquarters (总部)
├── Technology Dept (技术部)
│   ├── Frontend Team (前端组)
│   └── Backend Team (后端组)
└── Product Dept (产品部)
    ├── UI Design Team (UI设计组)
    └── UX Research Team (UX研究组)
```
