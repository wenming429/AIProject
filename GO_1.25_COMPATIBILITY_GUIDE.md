# LumenIM Go 1.25 开发环境配置指南

## 概述

本文档提供在 Windows (本地) 和 Ubuntu 20.04 (服务器) 上配置 Go 1.25.7 开发环境的详细步骤。

---

## 一、Windows 本地开发环境配置

### 1.1 安装 Go 1.25.7

**下载地址**: https://go.dev/dl/go1.25.7.windows-amd64.msi

**安装步骤**:
1. 下载 MSI 安装包
2. 双击运行，一路 Next 即可
3. 默认安装到 `C:\Program Files\Go\`

### 1.2 配置环境变量

打开系统环境变量设置，添加：

```
GOPATH = C:\Users\<用户名>\go
GOROOT = C:\Program Files\Go
PATH 添加 = C:\Program Files\Go\bin;C:\Users\<用户名>\go\bin
```

**验证安装**:
```powershell
go version
# 输出: go version go1.25.7 windows/amd64
```

### 1.3 配置 Go 代理

```powershell
go env -w GOPROXY=https://goproxy.cn,direct
go env -w GOSUMDB=off
go env -w GO111MODULE=on
```

### 1.4 克隆并配置项目

```powershell
# 克隆项目
git clone https://github.com/wenming429/AIProject.git
cd AIProject

# 进入后端目录
cd backend

# 下载并更新依赖
go mod tidy

# 编译
go build -o lumenim.exe ./cmd/lumenim
```

---

## 二、Ubuntu 20.04 服务器环境配置

### 2.1 安装 Go 1.25.7

```bash
# 下载 Go 1.25.7
wget https://go.dev/dl/go1.25.7.linux-amd64.tar.gz

# 解压到 /usr/local
sudo tar -C /usr/local -xzf go1.25.7.linux-amd64.tar.gz

# 清理安装包
rm go1.25.7.linux-amd64.tar.gz
```

### 2.2 配置环境变量

```bash
# 永久设置
echo 'export PATH=$PATH:/usr/local/go/bin' >> ~/.bashrc
echo 'export GOPROXY=https://goproxy.cn,direct' >> ~/.bashrc
echo 'export GOSUMDB=off' >> ~/.bashrc

# 使配置生效
source ~/.bashrc
```

**验证安装**:
```bash
go version
# 输出: go version go1.25.7 linux/amd64
```

### 2.3 克隆并配置项目

```bash
# 创建项目目录
sudo mkdir -p /var/www/lumenim
cd /var/www/lumenim

# 克隆项目
sudo git clone https://github.com/wenming429/AIProject.git .

# 更新依赖
cd backend
go mod tidy

# 编译 Linux amd64
CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -o lumenim ./cmd/lumenim
```

---

## 三、交叉编译指南

### 3.1 使用 Makefile

```bash
# 进入 backend 目录
cd backend

# 本地编译 (Linux)
make build

# 编译 Linux amd64
make build-linux-amd64

# 编译 Linux arm64
make build-linux-arm64

# 自定义目标平台
GOOS=linux GOARCH=arm64 make build
```

### 3.2 手动交叉编译

```bash
# Windows 编译 Linux
GOOS=linux GOARCH=amd64 go build -o lumenim-linux ./cmd/lumenim

# Linux 编译 Windows
GOOS=windows GOARCH=amd64 go build -o lumenim.exe ./cmd/lumenim
```

### 3.3 常用平台组合

| 目标 OS | 目标 ARCH | GOOS | GOARCH |
|---------|-----------|------|--------|
| Linux | x86-64 | linux | amd64 |
| Linux | ARM64 | linux | arm64 |
| Windows | x86-64 | windows | amd64 |
| macOS | x86-64 | darwin | amd64 |
| macOS | ARM64 (Apple Silicon) | darwin | arm64 |

---

## 四、Docker 构建

项目已配置多阶段 Docker 构建：

```bash
cd backend

# 构建镜像
docker build -t lumenim:latest .

# 带版本标签
docker build -t lumenim:v1.0 --build-arg IMAGE_TAG=v1.0 .

# 运行容器
docker run -p 8080:8080 lumenim:latest
```

Dockerfile 默认配置：
- 基础镜像: `golang:1.25-alpine`
- 目标平台: `linux/amd64`
- CGO: 禁用 (CGO_ENABLED=0)

---

## 五、依赖管理

### 5.1 常用命令

```bash
# 下载依赖
go mod download

# 整理依赖
go mod tidy

# 清理模块缓存
go clean -modcache

# 查看依赖列表
go list -m all

# 查看可更新依赖
go list -m -u all
```

### 5.2 依赖更新

```bash
# 更新主依赖
go get github.com/gin-gonic/gin@latest

# 更新间接依赖
go get github.com/gin-contrib/sse@latest

# 降级到特定版本
go get github.com/gin-contrib/sse@v0.1.0
```

---

## 六、常见问题排查

| 错误信息 | 原因 | 解决方案 |
|----------|------|----------|
| `go: command not found` | PATH 未包含 Go | 添加 Go 到 PATH |
| `cannot find package` | 依赖未下载 | 运行 `go mod download` |
| `version requires Go 1.25+` | Go 版本过低 | 升级 Go |
| `dns lookup failed` | 网络问题 | 配置 GOPROXY |

---

## 七、环境变量速查表

### Windows (PowerShell)
```powershell
$env:GOPATH = "$HOME\go"
$env:GOROOT = "C:\Program Files\Go"
$env:PATH = "C:\Program Files\Go\bin;$env:PATH"
$env:GOPROXY = "https://goproxy.cn,direct"
$env:GOSUMDB = "off"
```

### Linux (Bash)
```bash
export GOROOT=/usr/local/go
export PATH=$PATH:/usr/local/go/bin
export GOPATH=$HOME/go
export GOPROXY=https://goproxy.cn,direct
export GOSUMDB=off
```

### 构建环境变量
```bash
export GOOS=linux
export GOARCH=amd64
export CGO_ENABLED=0
```
