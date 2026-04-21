# LumenIM Go 1.22 开发环境配置指南

## 概述

本文档提供在 Windows (本地) 和 Ubuntu 20.04 (服务器) 上配置 Go 1.22 开发环境的详细步骤，确保项目代码兼容并能跨平台编译运行。

---

## 一、Windows 本地开发环境配置

### 1.1 安装 Go 1.22

**下载地址**: https://go.dev/dl/go1.22.0.windows-amd64.msi

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
# 输出: go version go1.22.0 windows/amd64
```

### 1.3 配置 Go 代理（解决国内访问问题）

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

# 下载依赖
go mod download

# 运行依赖修复脚本（如果需要）
.\..\software\scripts\fix_go_deps.sh

# 验证编译
go build -o lumenim.exe ./cmd/server
```

---

## 二、Ubuntu 20.04 服务器环境配置

### 2.1 安装 Go 1.22

```bash
# 下载 Go 1.22
wget https://go.dev/dl/go1.22.0.linux-amd64.tar.gz

# 解压到 /usr/local
sudo tar -C /usr/local -xzf go1.22.0.linux-amd64.tar.gz

# 清理安装包
rm go1.22.0.linux-amd64.tar.gz
```

### 2.2 配置环境变量

```bash
# 临时设置（当前会话有效）
export PATH=$PATH:/usr/local/go/bin
export GOPROXY=https://goproxy.cn,direct
export GOSUMDB=off
export GOTOOLCHAIN=local

# 永久设置
echo 'export PATH=$PATH:/usr/local/go/bin' >> ~/.bashrc
echo 'export GOPROXY=https://goproxy.cn,direct' >> ~/.bashrc
echo 'export GOSUMDB=off' >> ~/.bashrc
echo 'export GOTOOLCHAIN=local' >> ~/.bashrc

# 使配置生效
source ~/.bashrc
```

**验证安装**:
```bash
go version
# 输出: go version go1.22.0 linux/amd64
```

### 2.3 克隆并配置项目

```bash
# 创建项目目录
sudo mkdir -p /var/www/lumenim
cd /var/www/lumenim

# 克隆项目
sudo git clone https://github.com/wenming429/AIProject.git .

# 设置权限
sudo chown -R $USER:$USER /var/www/lumenim
```

### 2.4 运行依赖修复脚本

```bash
cd /var/www/lumenim
sudo ./software/scripts/fix_go_deps.sh
```

---

## 三、已知依赖兼容性问题及解决方案

### 3.1 依赖问题汇总表

| 依赖包 | 问题版本 | 兼容版本 | 解决方案 |
|--------|----------|----------|----------|
| `filipio.io/edwards25519` | 拼写错误 | `filippo.io/edwards25519` | 自动修复 |
| `gin-contrib/sse` | v1.1.0 需要 Go 1.23+ | v0.1.0 | 自动降级 |
| `google.golang.org/genproto` | 最新版需要 Go 1.24+ | v0.0.0-20240814211410 | replace 规则 |
| `buf.build/*` | 与 Go 1.22 不兼容 | - | 移除 |

### 3.2 修复脚本详解

`fix_go_deps.sh` 脚本自动执行以下修复：

```bash
# 1. 修复域名拼写错误
sed -i 's/filipio\.io/filippo.io/g' go.mod go.sum

# 2. 降级不兼容依赖
sed -i 's/github.com\/gin-contrib\/sse v1.1.0/github.com\/gin-contrib\/sse v0.1.0/g' go.mod

# 3. 移除不兼容依赖
sed -i '/buf.build/d' go.mod

# 4. 添加 replace 规则
cat >> go.mod << 'EOF'
replace (
    github.com/gin-contrib/sse => github.com/gin-contrib/sse v0.1.0
    google.golang.org/genproto/googleapis/api => google.golang.org/genproto/googleapis/api v0.0.0-20240814211410-ddb44dafa142
    google.golang.org/genproto/googleapis/rpc => google.golang.org/genproto/googleapis/rpc v0.0.0-20240814211410-ddb44dafa142
)
EOF

# 5. 重新下载依赖
go mod tidy
```

---

## 四、跨平台编译

### 4.1 Linux 交叉编译（从 Windows 编译 Linux 可执行文件）

**安装交叉编译工具**:
```powershell
# 使用 xgo 或手动设置
go env -w GOOS=linux GOARCH=amd64
```

**编译**:
```powershell
cd backend
GOOS=linux GOARCH=amd64 go build -o lumenim-linux ./cmd/server
```

### 4.2 Windows 交叉编译

**Linux 服务器上交叉编译 Windows**:
```bash
# 安装 mingw-w64
sudo apt-get install -y gcc-multilib

# 编译 Windows 可执行文件
GOOS=windows GOARCH=amd64 go build -o lumenim.exe ./cmd/server
```

---

## 五、验证编译结果

### 5.1 编译测试

```bash
# 在项目 backend 目录
cd /var/www/lumenim/backend

# 编译
go build -o lumenim ./cmd/server

# 检查生成的文件
ls -lh lumenim
```

### 5.2 运行测试

```bash
# 赋予执行权限
chmod +x lumenim

# 尝试运行（按 Ctrl+C 停止）
./lumenim
```

### 5.3 常见编译错误排查

| 错误信息 | 原因 | 解决方案 |
|----------|------|----------|
| `go: command not found` | PATH 未包含 Go | 添加 Go 到 PATH |
| `cannot find package` | 依赖未下载 | 运行 `go mod download` |
| `version requires Go 1.23+` | 依赖版本过高 | 运行 `fix_go_deps.sh` |
| `dns lookup failed: filipio.io` | 域名拼写错误 | 运行 `fix_go_deps.sh` |

---

## 六、环境变量速查表

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
export GOTOOLCHAIN=local
```

---

## 七、常用命令速查

```bash
# 查看 Go 版本
go version

# 查看 Go 环境
go env

# 下载依赖
go mod download

# 整理依赖
go mod tidy

# 清理模块缓存
go clean -modcache

# 编译项目
go build -o output ./cmd/server

# 运行项目
go run ./cmd/server

# 查看依赖版本
go list -m all
```
