# LumenIM 离线部署安装指南
# LumenIM Offline Deployment Installation Guide
# 版本: 1.0.0
# 更新日期: 2026-04-07

## 目录

1. [系统环境检查](#1-系统环境检查)
2. [依赖安装](#2-依赖安装)
3. [环境变量配置](#3-环境变量配置)
4. [安装验证](#4-安装验证)
5. [项目构建](#5-项目构建)
6. [数据库配置](#6-数据库配置)
7. [常见问题解决](#7-常见问题解决)

---

## 1. 系统环境检查

### 1.1 检查操作系统

```powershell
# Windows
$PSVersionTable.PSVersion
systeminfo | findstr /B /C:"OS Name" /C:"OS Version"

# Linux
cat /etc/os-release
uname -a

# macOS
sw_vers
system_profiler SPSoftwareDataType
```

**最低系统要求：**
- Windows 10/11 (64-bit)
- Linux (Ubuntu 20.04+ / CentOS 8+)
- macOS 11+ (Big Sur)

### 1.2 检查硬件资源

```powershell
# CPU 和内存
systeminfo | findstr /B /C:"Processor(s)" /C:"Total Physical Memory"

# 磁盘空间 (至少 10GB 可用空间)
Get-PSDrive -PSProvider FileSystem | Where-Object { $_.Used -ne $null }
```

### 1.3 检查已安装的软件

```powershell
# 检查 Go
go version 2>&1 || echo "Go 未安装"

# 检查 Node.js
node --version 2>&1 || echo "Node.js 未安装"

# 检查 Git
git --version 2>&1 || echo "Git 未安装"

# 检查 MySQL (Windows 服务)
Get-Service | Where-Object { $_.Name -like "*mysql*" }
```

---

## 2. 依赖安装

### 2.1 自动下载依赖包

```powershell
# 进入 software 目录
cd software

# 执行下载脚本
.\download-dependencies.ps1 -Components All -SkipExisting $true
```

**参数说明：**
- `-Components`: 选择下载的组件 (Core, Database, Proto, DevTools, Frontend, All)
- `-SkipExisting`: 跳过已存在的文件 (默认: $true)

### 2.2 手动下载（备选方案）

如果自动下载失败，请访问 `PACKAGE_LIST.md` 获取下载链接：

| 优先级 | 组件 | 说明 |
|--------|------|------|
| 1 | Go | 后端运行环境（必须） |
| 2 | Node.js + pnpm | 前端构建环境（必须） |
| 3 | MySQL + Redis | 数据库服务（必须） |
| 4 | protoc + buf | Proto 代码生成（开发必须） |
| 5 | Git + Make | 版本控制和构建工具（推荐） |

### 2.3 Windows 安装步骤

#### 2.3.1 安装 Go

1. 打开 `software/bin/` 目录
2. 双击 `go1.25.0.windows-amd64.msi`
3. 按照向导完成安装（默认安装到 `C:\Program Files\Go`）
4. 验证安装：
   ```powershell
   go version
   # 应输出: go version go1.25.0 windows/amd64
   ```

#### 2.3.2 安装 Node.js

1. 打开 `software/bin/` 目录
2. 双击 `node-v22.14.0-x64.msi`
3. 按照向导完成安装（默认安装到 `C:\Program Files\nodejs`）
4. 验证安装：
   ```powershell
   node --version
   # 应输出: v22.14.0
   
   npm --version
   # 应输出: 10.x.x
   ```

#### 2.3.3 安装 pnpm

```powershell
# 方法一：使用 npm 安装（推荐）
npm install -g pnpm

# 方法二：使用下载的二进制文件
Copy-Item "software/bin/pnpm-windows-x64.exe" "$env:USERPROFILE\AppData\Local\Microsoft\WindowsApps\pnpm.exe"

# 验证
pnpm --version
# 应输出: 10.0.0
```

#### 2.3.4 安装 MySQL

**方式一：使用 MSI 安装包（推荐）**

1. 双击 `mysql-8.0.40-winx64.zip`
2. 解压到 `C:\mysql`
3. 创建配置文件 `C:\mysql\my.ini`
4. 初始化并启动服务

**方式二：使用 Chocolatey**

```powershell
choco install mysql -y
```

**方式三：使用 Docker（推荐用于开发）**

```powershell
docker run -d --name lumenim-mysql -p 3306:3306 -e MYSQL_ROOT_PASSWORD=root123456 mysql:8.0
```

#### 2.3.5 安装 Redis

```powershell
# 使用 MSI 安装
.\software\bin\Redis-x64-5.0.14.1.msi

# 或使用 Chocolatey
choco install redis-64 -y

# 验证服务
redis-cli ping
```

### 2.4 Linux 安装步骤

#### 2.4.1 安装 Go

```bash
wget https://go.dev/dl/go1.25.0.linux-amd64.tar.gz
sudo tar -C /usr/local -xzf go1.25.0.linux-amd64.tar.gz
echo 'export PATH=$PATH:/usr/local/go/bin' >> ~/.bashrc
source ~/.bashrc
go version
```

#### 2.4.2 安装 Node.js

```bash
curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash -
sudo apt-get install -y nodejs
sudo npm install -g pnpm
```

---

## 3. 环境变量配置

### 3.1 Windows 环境变量

需要添加的环境变量：

| 变量名 | 值 | 说明 |
|--------|-----|------|
| GOROOT | `C:\Program Files\Go` | Go 安装目录 |
| GOPATH | `%USERPROFILE%\go` | Go 工作目录 |
| Path | 添加 `%GOROOT%\bin;%GOPATH%\bin` | Go 命令路径 |

### 3.2 Linux 环境变量

```bash
cat >> ~/.bashrc << 'EOF'
export GOROOT=/usr/local/go
export GOPATH=$HOME/go
export PATH=$PATH:$GOROOT/bin:$GOPATH/bin
export GOPROXY=https://goproxy.cn,direct
EOF
source ~/.bashrc
```

---

## 4. 安装验证

### 4.1 一键验证脚本

```powershell
# software/scripts/verify-installation.ps1

$ErrorCount = 0

Write-Host "======================================" -ForegroundColor Cyan
Write-Host "  LumenIM 环境验证" -ForegroundColor Cyan
Write-Host "======================================" -ForegroundColor Cyan

$checks = @(
    @{ Name = "Go"; Cmd = "go version"; Pattern = "go1\.\d+" },
    @{ Name = "Node.js"; Cmd = "node --version"; Pattern = "v22\.\d+" },
    @{ Name = "pnpm"; Cmd = "pnpm --version"; Pattern = "\d+" },
    @{ Name = "protoc"; Cmd = "protoc --version"; Pattern = "\d+" },
    @{ Name = "MySQL"; Cmd = "mysql --version"; Pattern = "\d+" },
    @{ Name = "Redis"; Cmd = "redis-cli --version"; Pattern = "\d+" }
)

foreach ($check in $checks) {
    Write-Host "检查 $($check.Name)..." -NoNewline
    try {
        $output = Invoke-Expression $check.Cmd 2>&1
        if ($output -match $check.Pattern) {
            Write-Host " [OK] $output" -ForegroundColor Green
        }
    }
    catch {
        Write-Host " [FAIL]" -ForegroundColor Red
        $ErrorCount++
    }
}

Write-Host ""
if ($ErrorCount -eq 0) {
    Write-Host "所有检查通过！" -ForegroundColor Green
} else {
    Write-Host "有 $ErrorCount 项检查失败" -ForegroundColor Red
}
```

运行验证：
```powershell
.\software\scripts\verify-installation.ps1
```

---

## 5. 项目构建

### 5.1 后端构建

```powershell
cd backend
go mod download
make proto
make build
```

### 5.2 前端构建

```powershell
cd front
pnpm install
pnpm build
```

---

## 6. 数据库配置

```sql
CREATE DATABASE IF NOT EXISTS go_chat CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE go_chat;
SOURCE backend/sql/lumenim.sql;
```

---

## 7. 常见问题解决

### 7.1 权限问题

```powershell
# Windows 以管理员身份运行 PowerShell
Start-Process powershell -Verb RunAs

# 或设置执行策略
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### 7.2 网络问题

```powershell
# npm 使用国内镜像
npm config set registry https://registry.npmmirror.com

# Go 使用代理
go env -w GOPROXY=https://goproxy.cn,direct
```

### 7.3 端口占用

```powershell
netstat -ano | findstr "9501"
taskkill /PID <PID> /F
```

---

*文档版本：1.0.0*
*最后更新：2026-04-07*
