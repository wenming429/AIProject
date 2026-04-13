# LumenIM 发布包准备指南

## 概述

本指南介绍如何使用 `prepare-release.ps1` 脚本准备前后端部署所需的发布包。该脚本会自动识别和分类项目中的必需文件，并将它们复制到指定的 release 目录中。

---

## 前置准备

### 1. 编译前端

```bash
cd front
npm install
npm run build
```

### 2. 编译后端

```bash
cd backend
# 确保已编译 lumenim-backend 或 lumenim.exe
go build -o lumenim-backend ./cmd/server
```

---

## 使用脚本

### 基本用法

```powershell
# PowerShell 中执行
cd D:\学习资料\AI_Projects\LumenIM\software\scripts

# 打包全部（后端 + 前端）
.\prepare-release.ps1

# 仅打包后端
.\prepare-release.ps1 -Backend

# 仅打包前端
.\prepare-release.ps1 -Frontend

# 指定输出目录
.\prepare-release.ps1 -OutputDir "D:\release\lumenim"
```

### 参数说明

| 参数 | 说明 | 默认值 |
|------|------|--------|
| `-Backend` | 仅打包后端 | - |
| `-Frontend` | 仅打包前端 | - |
| `-All` | 打包全部 | 是 |
| `-OutputDir` | 输出目录 | `D:\temp\lumenim-release` |

---

## 文件分类说明

### 后端必需文件

| 类别 | 文件/目录 | 说明 |
|------|----------|------|
| **二进制文件** | `lumenim-backend.exe`, `lumenim-backend` | 编译后的可执行文件 |
| **配置文件** | `.env`, `config.yaml`, `docker-compose.yaml` | 环境配置和应用配置 |
| **数据库脚本** | `sql/` | 数据库初始化脚本 |
| **运行时目录** | `runtime/` | 运行时配置和数据 |
| **上传目录** | `uploads/` | 用户上传文件 |
| **Proto 文件** | `api/` | API 定义文件 |
| **构建文件** | `Makefile`, `Dockerfile` | 构建和部署配置 |

### 前端必需文件

| 类别 | 文件/目录 | 说明 |
|------|----------|------|
| **构建产物** | `dist/` | 编译后的静态文件（必须先执行 `npm run build`） |
| **环境配置** | `.env`, `vite.config.ts` | 构建配置 |
| **入口文件** | `index.html` | 主页面入口 |
| **静态资源** | `public/` | 公共静态资源 |

### 排除的文件

以下文件和目录不包含在发布包中：

| 目录/文件 | 排除原因 |
|-----------|----------|
| `node_modules/` | 依赖包，服务器无需 |
| `vendor/` | Go 依赖包，服务器无需 |
| `src/` | 源码，无需部署 |
| `api/*.pb.go` | 自动生成的代码 |
| `data/im-private/` | 私有数据 |
| `data/im-static/` | 静态媒体文件（可选） |
| `data/logs/` | 日志文件 |
| `*.meta` | 元数据文件 |

---

## 输出目录结构

```
D:\temp\lumenim-release\
├── backend/
│   ├── lumenim-backend.exe    # Windows 二进制
│   ├── lumenim-backend        # Linux 二进制
│   ├── .env                   # 环境配置
│   ├── config.yaml            # 应用配置
│   ├── docker-compose.yaml    # Docker 配置
│   ├── sql/                   # 数据库脚本
│   ├── runtime/               # 运行时目录
│   └── Makefile               # 构建脚本
│
├── frontend/
│   ├── dist/                  # 构建产物
│   ├── .env                   # 环境配置
│   ├── vite.config.ts         # 构建配置
│   └── index.html             # 入口文件
│
└── README.md                  # 部署说明
```

---

## 手动打包（不使用脚本）

如果需要手动打包，可以使用以下命令：

### Windows PowerShell

```powershell
# 创建输出目录
$out = "D:\temp\lumenim-release"
New-Item -ItemType Directory -Force -Path "$out\backend", "$out\frontend" | Out-Null

# 复制后端
Copy-Item backend\.env "$out\backend\"
Copy-Item backend\config.yaml "$out\backend\"
Copy-Item backend\lumenim-backend.exe "$out\backend\"  # Windows 二进制
Copy-Item backend\sql "$out\backend\" -Recurse
Copy-Item backend\runtime "$out\backend\" -Recurse -Force

# 复制前端
Copy-Item front\dist "$out\frontend\" -Recurse
```

### Linux/macOS/Git Bash

```bash
out=/tmp/lumenim-release
mkdir -p $out/backend $out/frontend

# 复制后端
cp backend/.env $out/backend/
cp backend/config.yaml $out/backend/
cp backend/lumenim-backend $out/backend/  # Linux 二进制
cp -r backend/sql $out/backend/
cp -r backend/runtime $out/backend/

# 复制前端
cp -r front/dist $out/frontend/
```

---

## 验证发布包

```bash
# 检查后端包内容
tar -tzf backend.tar.gz | head -20

# 检查是否包含 .env
tar -tzf backend.tar.gz | grep "\.env"

# 检查前端包内容
tar -tzf frontend.tar.gz | head -20
```

预期输出应包含：
- `backend.tar.gz`: `.env`, `config.yaml`, 二进制文件
- `frontend.tar.gz`: `dist/`, `index.html`

---

## 常见问题

### Q: dist 目录不存在？

```bash
# 先编译前端
cd front
npm install
npm run build
```

### Q: 二进制文件不存在？

```bash
# 编译后端
cd backend
go build -o lumenim-backend ./cmd/server
```

### Q: .env 文件不存在？

```bash
# 从模板复制
cp backend/.env.example backend/.env
# 编辑配置
vi backend/.env
```
