# LumenIM 依赖包处理方式分析报告

## 一、项目技术栈与构建工具

| 组件 | 技术栈 | 构建工具 | 产物类型 |
|------|--------|----------|----------|
| **前端** | Vue3 + TypeScript + NaiveUI | **Vite** (`vite build`) | 静态文件 (HTML/CSS/JS) |
| **后端** | Go (Gin + GORM) | **Go 编译器** (`go build`) | 单一可执行文件 (binary) |

---

## 二、前端依赖分析

### 2.1 构建配置（Vite）

从 `vite.config.ts` 可以看到：

```typescript
build: {
    emptyOutDir: true,
    chunkSizeWarningLimit: 1000,
    rollupOptions: {
        output: {
            manualChunks: isElectron
                ? {
                    'vendor-vue': ['vue', 'vue-router', 'pinia'],
                    'vendor-ui': ['naive-ui'],
                    'vendor-media': ['xgplayer', 'js-audio-recorder'],
                    'vendor-utils': ['crypto-js', 'dayjs', 'uuid', 'jsencrypt']
                }
                : undefined  // Web 模式：自动 code-splitting
        }
    }
}
```

### 2.2 依赖包含状态

| 依赖类型 | 数量 | 是否打包进产物 | 说明 |
|---------|------|---------------|------|
| **生产依赖** (dependencies) | 21个 | ✅ **全部内嵌** | Vite/Rollup 将所有 npm 包编译打包为静态 JS 文件 |
| **开发依赖** (devDependencies) | 37个 | ❌ **不包含** | 仅用于开发/构建过程，不进入最终产物 |
| **node_modules** | - | ❌ **不包含** | 构建时使用，产物中不存在 |

### 2.3 构建产物验证

当前 `front/dist/` 目录已包含完整的构建产物：

```
front/dist/
├── index.html              # 入口 HTML
├── embed.html              # 嵌入模式 HTML
├── favicon.ico / .svg      # 图标
└── assets/                 # 240 个文件
    ├── *.js (191个)        # 所有 JS 代码（含 vendor chunk）
    ├── *.css (42个)        # 样式文件
    └── *.png/.jpg/.svg     # 图片资源
```

**关键发现**：

- `naive-ui` 虽然在 `devDependencies` 中声明，但通过 `unplugin-vue-components` 的 `NaiveUiResolver()` **按需引入**，最终被打包进产物
- Vite 启用了 `vite-plugin-compression`（阈值 1MB），大文件会被 gzip 压缩
- **产物是完全自包含的静态文件，运行时无需任何 node_modules**

### 2.4 Electron 桌面端

```json
// electron-builder.json 第12-18行
"files": [
    "dist/**/*",           // 只包含构建产物
    "electron/**/*",       // Electron 主进程代码
    "!node_modules/**/*",  // 明确排除 node_modules
    "!src/**/*",
    "!scripts/**/*"
]
```

Electron 打包也明确排除了 `node_modules`。

---

## 三、后端依赖分析

### 3.1 构建配置（Go/Dockerfile）

```dockerfile
# Dockerfile 多阶段构建
FROM golang:1.25-alpine AS builder   # 构建阶段
WORKDIR /builder
COPY go.mod go.sum ./
RUN go mod download                  # 下载 Go 模块依赖
COPY . .
RUN go build -o lumenim ...          # 编译为单一二进制

FROM alpine:latest                   # 运行阶段（极简镜像）
COPY --from=builder /builder/lumenim .
ENTRYPOINT ["./lumenim"]
```

### 3.2 依赖包含状态

| 依赖类型 | 数量 | 是否打包进产物 | 说明 |
|---------|------|---------------|------|
| **直接依赖** (require) | 33个 | ✅ **静态链接** | `go build` 将所有 Go 模块编译进单一 binary |
| **间接依赖** (indirect) | 64个 | ✅ **静态链接** | 自动解析并编译 |
| **Go 标准库** | 全部 | ✅ **内置** | 运行时无需额外安装 |
| **外部服务** | MySQL/Redis/MinIO | ❌ **运行时依赖** | 需要独立部署 |

### 3.3 go.mod 关键信息

```
模块路径: github.com/gzydong/go-chat
Go 版本: 1.25.0
直接依赖: 33 个
间接依赖: 64 个
总计: ~97 个 Go 模块
```

**关键发现**：

- Go 使用 `CGO_ENABLED=0` 编译，生成**纯静态链接的二进制文件**
- 最终产物只有一个 `lumenim` 可执行文件（约几十 MB）
- **运行时零依赖** —— 不需要任何 Go module、动态库或运行时环境
- 外部依赖仅限 MySQL、Redis、MinIO 这三个基础设施服务

---

## 四、两娄依赖对比总表

| 维度 | 前端 (Vue3+Vite) | 后端 (Go) |
|------|-------------------|-----------|
| **构建工具** | Vite (Rollup) | Go compiler |
| **产物形式** | 静态文件 (HTML/JS/CSS) | 单一可执行文件 (ELF binary) |
| **依赖集成方式** | Tree-shaking + Code-splitting | 静态编译链接 |
| **产物自包含性** | ✅ 完全自包含 | ✅ 完全自包含 |
| **运行时是否需要源码** | ❌ 不需要 | ❌ 不需要 |
| **运行时是否需要 node_modules** | ❌ 不需要 | N/A |
| **运行时是否需要 vendor** | N/A | ❌ 不需要 |
| **外部运行时依赖** | 无 | MySQL / Redis / MinIO |

---

## 五、无外网环境下的离线部署方案

### 5.1 核心结论

```
┌─────────────────────────────────────────────────────────────┐
│                    依赖处理核心结论                          │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  前端:  pnpm build → dist/ (静态文件) → 直接部署 ✓         │
│         ↑                                                    │
│    需要: 有网络环境下提前执行 pnpm install + pnpm build      │
│                                                             │
│  后端:  go build → lumenim (二进制) → 直接部署 ✓           │
│         ↑                                                    │
│    需要: 有网络环境下提前执行 go mod download + go build     │
│         或: 提前打包 vendor 目录                             │
│                                                             │
│  基础设施: Docker 离线镜像 (MySQL, Redis, MinIO)             │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### 5.2 离线部署所需准备的物料清单

| 序号 | 物料 | 来源 | 用途 | 准备方式 |
|------|------|------|------|----------|
| 1 | **front/dist/** | 本地 `pnpm build` 产物 | 前端静态文件 | 在有网络机器上构建 |
| 2 | **backend/lumenim** | 本地 `go build` 产物 | 后端可执行文件 | 在有网络机器上交叉编译 |
| 3 | **Go vendor 包** (可选) | `go mod vendor` 导出 | 离线重新编译后备方案 | `go mod vendor && tar czf vendor.tar.gz vendor/` |
| 4 | **node_modules** (可选) | `pnpm install` 后整体复制 | 离线重新构建后备方案 | 将整个 `front/node_modules` 打包 |
| 5 | **MySQL Docker 镜像** | `docker save` 导出 | 数据库服务 | `docker save -o mysql.tar mysql:8.0` |
| 6 | **Redis Docker 镜像** | `docker save` 导出 | 缓存服务 | `docker save -o redis.tar redis:7` |
| 7 | **MinIO Docker 镜像** | `docker save` 导出 | 对象存储 | `docker save -o minio.tar minio/latest` |
| 8 | **config.yaml** | 手动编辑 | 后端配置 | 根据目标环境修改 |
| 9 | **SQL 初始化脚本** | 项目自带 `backend/sql/` | 数据库初始化 | 随项目代码一起打包 |

### 5.3 推荐的离线准备流程（在有网络的机器上执行）

```bash
#!/bin/bash
# ============================================
# LumenIM 离线部署包制作脚本（在有网络环境执行）
# ============================================
OUTPUT_DIR="/tmp/lumenim-offline"
PROJECT_DIR="/path/to/LumenIM"

mkdir -p $OUTPUT_DIR/{frontend,backend,images,vendor,config}

echo "=== 1. 准备前端构建产物 ==="
cd $PROJECT_DIR/front
pnpm install                    # 安装 npm 依赖（需要网络）
pnpm build --mode production   # 构建（产物输出到 dist/）
cp -r dist/* $OUTPUT_DIR/frontend/

echo "=== 2. 准备后端可执行文件（Linux amd64 交叉编译）==="
cd $PROJECT_DIR/backend
CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build \
    -o $OUTPUT_DIR/backend/lumenim \
    ./cmd/lumenim

echo "=== 3. 准备 Go vendor（用于离线重新编译）==="
go mod vendor
tar -czf $OUTPUT_DIR/vendor/vendor.tar.gz vendor/

echo "=== 4. 导出 Docker 镜像 ==="
docker pull mysql:8.0
docker pull redis:7-alpine
docker pull minio/minio:latest
docker save -o $OUTPUT_DIR/images/mysql.tar mysql:8.0
docker save -o $OUTPUT_DIR/images/redis.tar redis:7-alpine
docker save -o $OUTPUT_DIR/images/minio.tar minio/minio:latest

echo "=== 5. 备份配置和 SQL ==="
cp config.yaml $OUTPUT_DIR/config/
cp -r sql/ $OUTPUT_DIR/config/sql/

echo "=== 6. 打包全部离线物料 ==="
cd $OUTPUT_DIR
tar -czf ../lumenim-offline-package.tar.gz .
echo "✅ 完成! 离线包: /tmp/lumenim-offline-package.tar.gz"
```

### 5.4 在无外网服务器上的部署步骤

```bash
#!/bin/bash
# ============================================
# 无外网服务器部署脚本
# ============================================
PACKAGE_DIR="/mnt/usb/lumenim-offline"   # U盘挂载点
DEPLOY_DIR="/opt/lumenim"

# 1. 解压离线包
mkdir -p $DEPLOY_DIR
cd $PACKAGE_DIR
tar -xzf lumenim-offline-package.tar.gz -C $DEPLOY_DIR

# 2. 加载 Docker 镜像
docker load -i $PACKAGE_DIR/images/mysql.tar
docker load -i $PACKAGE_DIR/images/redis.tar
docker load -i $PACKAGE_DIR/images/minio.tar

# 3. 启动基础设施容器
docker run -d --name lumenim-mysql ... mysql:8.0
docker run -d --name lumenim-redis ... redis:7-alpine
docker run -d --name lumenim-minio ... minio/minio:latest

# 4. 部署前端（直接用预构建产物）
mkdir -p /var/www/html
cp -r $PACKAGE_DIR/frontend/* /var/www/html/

# 5. 部署后端（直接用预编译二进制）
cp $PACKAGE_DIR/backend/lumenim $DEPLOY_DIR/
chmod +x $DEPLOY_DIR/lumenim

# 6. 修改配置
cp $PACKAGE_DIR/config/config.yaml $DEPLOY_DIR/
vim $DEPLOY_DIR/config.yaml   # 修改数据库地址等

# 7. 启动后端服务
$DEPLOY_DIR/lumenim http --config=$DEPLOY_DIR/config.yaml
$DEPLOY_DIR/lumenim comet --config=$DEPLOY_DIR/config.yaml

# 8. 配置 Nginx 反向代理（指向 /var/www/html）
```

---

## 六、检查依赖包含状态的方法

### 6.1 前端检查命令

```bash
# 检查 dist 目录是否包含所有必要文件
ls -la front/dist/assets/*.js | wc -l   # 应有约 190+ 个 JS 文件

# 检查是否有 node_modules 泄漏到产物中
find front/dist -name "node_modules" -type d   # 应无输出

# 检查产物大小是否合理
du -sh front/dist/   # 通常 5-20MB（取决于项目规模）

# 验证产物完整性（检查入口文件）
cat front/dist/index.html | head -20

# 检查 vendor chunk 是否包含主要依赖
grep -l "vue\|pinia\|naive-ui" front/dist/assets/*.js
```

### 6.2 后端检查命令

```bash
# 检查二进制文件
file backend/lumenim
# 输出应类似: ELF 64-bit LSB executable, x86-64, statically linked

# 检查是否是静态链接
ldd backend/lumenim
# 输出应: "not a dynamic executable" 或 "statically linked"

# 检查二进制大小
ls -lh backend/lumenim
# 通常 20-80MB（Go 二进制典型大小）

# 检查是否嵌入运行时依赖
strings backend/lumenim | grep -c "gorm\|gin\|redis"  # 应 > 0
```

---

## 七、总结

| 问题 | 答案 |
|------|------|
| **前端依赖是否需要单独下载？** | ❌ 不需要。`vite build` 已将所有生产依赖编译为静态 JS 文件 |
| **后端依赖是否需要单独下载？** | ❌ 不需要。`go build` 已将所有 Go 模块静态链接为单一二进制 |
| **什么情况下需要离线依赖包？** | 仅当需要在**目标服务器上重新编译/重新构建**时 |
| **推荐的无外网部署方式** | **携带预构建产物**（dist/ + lumenim 二进制），而非携带源码+依赖 |
| **必须离线安装的基础设施** | MySQL、Redis、MinIO（通过 Docker 离线镜像） |

---

你的项目中已有的 `software/scripts/DEPLOY_CENTOS7_OFFLINE.md` 文档已经覆盖了大部分离线场景。
