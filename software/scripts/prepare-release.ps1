#!/usr/bin/env pwsh
#===============================================
# LumenIM 前后端发布包准备脚本
# 将部署所需文件分类并拷贝到 release 目录
#===============================================

param(
    [switch]$Backend,      # 仅打包后端
    [switch]$Frontend,     # 仅打包前端
    [switch]$All,          # 打包全部（默认）
    [string]$OutputDir = "D:\temp\lumenim-release"  # 输出目录
)

$ErrorActionPreference = "Stop"
$ProjectRoot = Split-Path -Parent $PSScriptRoot | Split-Path -Parent

# 颜色输出
function Write-Info { param($msg) Write-Host "[INFO] $msg" -ForegroundColor Cyan }
function Write-Success { param($msg) Write-Host "[SUCCESS] $msg" -ForegroundColor Green }
function Write-Warn { param($msg) Write-Host "[WARN] $msg" -ForegroundColor Yellow }
function Write-Error { param($msg) Write-Host "[ERROR] $msg" -ForegroundColor Red }

# 显示帮助
function Show-Help {
    Write-Host @"
LumenIM 发布包准备脚本

用法: $($MyInvocation.MyCommand.Name) [选项]

选项:
    -Backend      仅打包后端
    -Frontend     仅打包前端
    -All          打包全部（默认）
    -OutputDir    指定输出目录（默认: D:\temp\lumenim-release）

示例:
    $($MyInvocation.MyCommand.Name)           # 打包全部
    $($MyInvocation.MyCommand.Name) -Backend  # 仅打包后端
    $($MyInvocation.MyCommand.Name) -Frontend -OutputDir "D:\release"
"@
}

# 复制目录结构（保留文件）
function Copy-DirectoryStructure {
    param(
        [string]$Source,
        [string]$Destination,
        [string[]]$Include = @("*"),
        [string[]]$Exclude = @()
    )
    
    if (-not (Test-Path $Source)) {
        Write-Warn "源目录不存在: $Source"
        return
    }
    
    $items = Get-ChildItem -Path $Source -Recurse -File
    foreach ($item in $items) {
        $relativePath = $item.FullName.Substring($Source.Length).TrimStart('\', '/')
        
        # 检查是否在排除列表中
        $isExcluded = $false
        foreach ($pattern in $Exclude) {
            if ($relativePath -like $pattern -or $item.Name -like $pattern) {
                $isExcluded = $true
                break
            }
        }
        
        if ($isExcluded) { continue }
        
        $destPath = Join-Path $Destination $relativePath
        $destDir = Split-Path -Parent $destPath
        
        if (-not (Test-Path $destDir)) {
            New-Item -ItemType Directory -Path $destDir -Force | Out-Null
        }
        
        Copy-Item -Path $item.FullName -Destination $destPath -Force
    }
}

# 复制单个文件
function Copy-FileIfExists {
    param([string]$Source, [string]$Destination)
    
    if (Test-Path $Source) {
        $destDir = Split-Path -Parent $Destination
        if (-not (Test-Path $destDir)) {
            New-Item -ItemType Directory -Path $destDir -Force | Out-Null
        }
        Copy-Item -Path $Source -Destination $Destination -Force
        return $true
    }
    return $false
}

Write-Host "========================================" -ForegroundColor Magenta
Write-Host "  LumenIM 发布包准备脚本" -ForegroundColor Magenta
Write-Host "========================================" -ForegroundColor Magenta

# 解析参数
$DoBackend = $All -or (-not $Frontend -and -not $Backend)
$DoFrontend = $All -or $Frontend

# 创建输出目录
$backendOutput = Join-Path $OutputDir "backend"
$frontendOutput = Join-Path $OutputDir "frontend"

New-Item -ItemType Directory -Force -Path $backendOutput | Out-Null
New-Item -ItemType Directory -Force -Path $frontendOutput | Out-Null

Write-Info "输出目录: $OutputDir"

#===============================================
# 打包后端
#===============================================
if ($DoBackend) {
    Write-Host ""
    Write-Info "========== 打包后端 =========="
    
    $srcBackend = Join-Path $ProjectRoot "backend"
    
    # 1. 复制配置文件（必须）
    Write-Info "复制配置文件..."
    $configs = @(
        ".env",
        ".env.example",
        "config.yaml",
        "config.example.yaml",
        "docker-compose.yaml"
    )
    
    foreach ($cfg in $configs) {
        $src = Join-Path $srcBackend $cfg
        if (Test-Path $src) {
            Copy-FileIfExists -Source $src -Destination (Join-Path $backendOutput $cfg)
            Write-Success "已复制: $cfg"
        } else {
            Write-Warn "配置文件不存在（跳过）: $cfg"
        }
    }
    
    # 2. 复制 SQL 脚本（数据库初始化）
    Write-Info "复制 SQL 脚本..."
    $sqlDir = Join-Path $srcBackend "sql"
    if (Test-Path $sqlDir) {
        Copy-DirectoryStructure -Source $sqlDir -Destination (Join-Path $backendOutput "sql")
        Write-Success "已复制: sql/"
    }
    
    # 3. 复制编译后的二进制文件
    Write-Info "复制二进制文件..."
    $binaries = @(
        "lumenim-backend.exe",
        "lumenim-backend",
        "lumenim.exe",
        "lumenim.exe~"
    )
    
    foreach ($bin in $binaries) {
        $src = Join-Path $srcBackend $bin
        if (Test-Path $src) {
            Copy-FileIfExists -Source $src -Destination (Join-Path $backendOutput $bin)
            Write-Success "已复制: $bin"
        }
    }
    
    # 4. 复制 runtime 目录（运行时配置）
    Write-Info "复制 runtime 目录..."
    $runtimeDir = Join-Path $srcBackend "runtime"
    if (Test-Path $runtimeDir) {
        Copy-DirectoryStructure -Source $runtimeDir -Destination (Join-Path $backendOutput "runtime")
        Write-Success "已复制: runtime/"
    }
    
    # 5. 复制 uploads 目录（用户上传）
    Write-Info "复制 uploads 目录..."
    $uploadsDir = Join-Path $srcBackend "uploads"
    if (Test-Path $uploadsDir) {
        Copy-DirectoryStructure -Source $uploadsDir -Destination (Join-Path $backendOutput "uploads")
        Write-Success "已复制: uploads/"
    }
    
    # 6. 复制 proto 文件（如果需要）
    Write-Info "复制 proto 文件..."
    $protoDir = Join-Path $srcBackend "api"
    if (Test-Path $protoDir) {
        Copy-DirectoryStructure -Source $protoDir -Destination (Join-Path $backendOutput "api") -Exclude @("*.pb.go", "*.pb.gw.go")
        Write-Success "已复制: api/ (proto)"
    }
    
    # 7. 复制 Makefile 和构建脚本
    Write-Info "复制构建文件..."
    $buildFiles = @(
        "Makefile",
        "Dockerfile",
        "README.md"
    )
    
    foreach ($file in $buildFiles) {
        $src = Join-Path $srcBackend $file
        if (Test-Path $src) {
            Copy-FileIfExists -Source $src -Destination (Join-Path $backendOutput $file)
        }
    }
    
    Write-Success "后端打包完成: $backendOutput"
}

#===============================================
# 打包前端
#===============================================
if ($DoFrontend) {
    Write-Host ""
    Write-Info "========== 打包前端 =========="
    
    $srcFront = Join-Path $ProjectRoot "front"
    
    # 1. 复制 dist 目录（构建产物，必须）
    Write-Info "复制 dist 目录（构建产物）..."
    $distDir = Join-Path $srcFront "dist"
    if (Test-Path $distDir) {
        Copy-DirectoryStructure -Source $distDir -Destination (Join-Path $frontendOutput "dist")
        Write-Success "已复制: dist/"
    } else {
        Write-Warn "dist 目录不存在，请先执行: cd front; npm run build"
    }
    
    # 2. 如果需要源码部署，复制配置文件
    Write-Info "复制配置文件..."
    $configs = @(
        ".env",
        ".env.example",
        "vite.config.ts",
        "package.json",
        "tsconfig.json",
        "index.html"
    )
    
    foreach ($cfg in $configs) {
        $src = Join-Path $srcFront $cfg
        if (Test-Path $src) {
            Copy-FileIfExists -Source $src -Destination (Join-Path $frontendOutput $cfg)
        }
    }
    
    # 3. 复制 public 目录（静态资源）
    Write-Info "复制 public 目录..."
    $publicDir = Join-Path $srcFront "public"
    if (Test-Path $publicDir) {
        Copy-DirectoryStructure -Source $publicDir -Destination (Join-Path $frontendOutput "public")
        Write-Success "已复制: public/"
    }
    
    Write-Success "前端打包完成: $frontendOutput"
}

#===============================================
# 生成部署说明
#===============================================
Write-Host ""
Write-Info "========== 生成部署说明 =========="

$readmeContent = @"
# LumenIM 发布包说明

## 目录结构

    lumenim-release/
    ├── backend/          # 后端服务
    │   ├── lumenim-backend.exe    # Windows 二进制文件
    │   ├── lumenim-backend        # Linux 二进制文件
    │   ├── .env                   # 环境配置（需手动编辑）
    │   ├── config.yaml            # 应用配置
    │   ├── docker-compose.yaml    # Docker 配置
    │   ├── sql/                   # 数据库脚本
    │   └── runtime/               # 运行时目录
    │
    └── frontend/         # 前端应用
        ├── dist/         # 构建产物
        ├── .env          # 环境配置
        └── vite.config.ts # 构建配置

## 后端部署

1. 上传 backend 目录到服务器 `/var/www/lumenim/backend/`

2. 配置环境变量：
   - 编辑 .env 文件，设置数据库和 Redis 连接

3. 启动服务：
   ```bash
   chmod +x lumenim-backend
   ./lumenim-backend
   ```

## 前端部署

1. 上传 frontend 目录到服务器 `/var/www/lumenim/front/`

2. 配置 Nginx：
   ```nginx
   server {
       listen 9501;
       server_name _;
       root /var/www/lumenim/front/dist;
       index index.html;
       
       location / {
           try_files \$uri \$uri/ /index.html;
       }
       
       location /api/ {
           proxy_pass http://127.0.0.1:8080/api/;
       }
   }
   ```

## 快速部署

使用自动化脚本：
```bash
sudo ./software/deploy-packages.sh
```
"@

$readmePath = Join-Path $OutputDir "README.md"
Set-Content -Path $readmePath -Value $readmeContent -Encoding UTF8

Write-Success "已生成部署说明: $readmePath"

#===============================================
# 完成
#===============================================
Write-Host ""
Write-Host "========================================" -ForegroundColor Magenta
Write-Success "发布包准备完成！"
Write-Host ""
Write-Host "输出目录: $OutputDir" -ForegroundColor Cyan
Write-Host ""
Write-Host "后端文件:" -ForegroundColor Yellow
Get-ChildItem $backendOutput -Recurse | ForEach-Object { Write-Host "  $($_.FullName.Replace($OutputDir, '$OUTPUT'))" }
Write-Host ""
Write-Host "前端文件:" -ForegroundColor Yellow
Get-ChildItem $frontendOutput -Recurse | ForEach-Object { Write-Host "  $($_.FullName.Replace($OutputDir, '$OUTPUT'))" }
