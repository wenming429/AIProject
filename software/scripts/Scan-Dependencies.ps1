# ============================================================
# LumenIM 本地依赖扫描脚本
# 扫描项目本地依赖包，识别版本号低于2.4的系统依赖
# ============================================================

param(
    [string]$ProjectDir = "d:\学习资料\AI_Projects\LumenIM",
    [string]$OutputDir = "D:\LumenIM-Packages\sysdeps",
    [string]$VersionThreshold = "2.4"
)

# ============================================================
# 颜色定义
# ============================================================

function Get-ColorOutput {
    param([string]$Text, [string]$Color = "White")
    $colors = @{
        "Red" = [ConsoleColor]::Red
        "Green" = [ConsoleColor]::Green
        "Yellow" = [ConsoleColor]::Yellow
        "Blue" = [ConsoleColor]::Blue
        "Cyan" = [ConsoleColor]::Cyan
        "White" = [ConsoleColor]::White
    }
    $host.UI.RawUI.ForegroundColor = $colors[$Color]
    Write-Host $Text
    $host.UI.RawUI.ForegroundColor = [ConsoleColor]::White
}

# ============================================================
# 系统依赖包定义（本地源）- 版本低于2.4的包
# ============================================================

$SystemDeps = @{
    "wget" = "1.14-18.el7_9.1"
    "curl" = "7.61.1-9.el7"
    "git" = "1.8.3.1-23.el7_9"
    "gcc" = "4.8.5-44.el7"
    "gcc-c++" = "4.8.5-44.el7"
    "make" = "3.82-29.el7"
    "net-tools" = "2.0-0.0.20161004git.el7"
    "unzip" = "6.0-24.el7_9"
    "tar" = "1.26-35.el7"
    "xz" = "5.2.2-2.el7"
}

# ============================================================
# 函数
# ============================================================

function New-OutputDirectory {
    param([string]$Path)
    
    Get-ColorOutput "[STEP] 创建输出目录: $Path" "Blue"
    
    if (-not (Test-Path $Path)) {
        New-Item -ItemType Directory -Path $Path -Force | Out-Null
    }
    
    if (Test-Path $Path) {
        Get-ColorOutput "[SUCCESS] 目录创建成功" "Green"
    } else {
        Get-ColorOutput "[ERROR] 目录创建失败" "Red"
        exit 1
    }
}

function Get-ExistingPackages {
    Get-ColorOutput "[STEP] 检查已有离线包" "Blue"
    Write-Host ""
    
    $foundCount = 0
    $missingCount = 0
    
    foreach ($pkg in $SystemDeps.Keys) {
        $version = $SystemDeps[$pkg]
        $found = $false
        
        # 尝试查找文件
        $patterns = @(
            "$pkg-$version.x86_64.rpm",
            "$pkg-$version.i686.rpm",
            "$pkg-$version.i386.rpm",
            "$pkg-$version.noarch.rpm",
            "$pkg-*.rpm"
        )
        
        foreach ($pattern in $patterns) {
            $files = Get-ChildItem -Path $OutputDir -Filter $pattern -ErrorAction SilentlyContinue
            if ($files) {
                $size = ($files[0].Length / 1MB).ToString("F2")
                Get-ColorOutput "  [FOUND] $pkg ($size MB)" "Green"
                $found = $true
                $foundCount++
                break
            }
        }
        
        if (-not $found) {
            Get-ColorOutput "  [MISSING] $pkg" "Yellow"
            $missingCount++
        }
    }
    
    Write-Host ""
    Get-ColorOutput "统计: 已找到 $foundCount 个, 缺失 $missingCount 个" "Cyan"
}

function Show-LowVersionPackages {
    Get-ColorOutput "[STEP] 识别版本号低于 $VersionThreshold 的包" "Blue"
    Write-Host ""
    
    Write-Host "----------------------------------------"
    Write-Host "  软件包          | 版本                       | 状态"
    Write-Host "----------------------------------------"
    
    foreach ($pkg in $SystemDeps.Keys) {
        $fullVersion = $SystemDeps[$pkg]
        
        # 提取主版本号
        $major = [regex]::Match($fullVersion, "^[0-9]+").Value
        $threshold = [regex]::Match($VersionThreshold, "^[0-9]+").Value
        
        if ([int]$major -lt [int]$threshold) {
            $status = "[需下载]"
            $color = "Yellow"
        } else {
            $status = "[高于阈值]"
            $color = "Cyan"
        }
        
        Write-Host ("  {0,-15} | {1,-25} | {2}" -f $pkg, $fullVersion, $status)
    }
    
    Write-Host "----------------------------------------"
    Write-Host ""
    Get-ColorOutput "所有列出的系统依赖版本号均低于 $VersionThreshold" "Cyan"
}

function Get-DownloadScript {
    Get-ColorOutput "[STEP] 生成下载脚本" "Blue"
    
    $scriptPath = Join-Path $OutputDir "download-sysdeps.ps1"
    
    $scriptContent = @"
# CentOS 7 系统依赖下载脚本
# 自动下载版本低于 2.4 的系统依赖包

`$OutputDir = "`$(`$PSScriptRoot)"
`$MIRROR = "https://mirrors.tuna.tsinghua.edu.cn/centos-vault/7.9.2009/os/x86_64/Packages/"
`$ErrorActionPreference = "Continue"

`$Packages = @(
    "wget-1.14-18.el7_9.1.x86_64.rpm",
    "curl-7.61.1-9.el7.x86_64.rpm", 
    "git-1.8.3.1-23.el7_9.x86_64.rpm",
    "gcc-4.8.5-44.el7.x86_64.rpm",
    "gcc-c++-4.8.5-44.el7.x86_64.rpm",
    "make-3.82-29.el7.x86_64.rpm",
    "net-tools-2.0-0.0.20161004git.el7.x86_64.rpm",
    "unzip-6.0-24.el7_9.x86_64.rpm",
    "tar-1.26-35.el7.x86_64.rpm",
    "xz-5.2.2-2.el7.x86_64.rpm"
)

`$Deps = @(
    "glibc-2.17-317.el7.x86_64.rpm",
    "glibc-common-2.17-317.el7.x86_64.rpm",
    "kernel-headers-3.10.0-1160.el7.x86_64.rpm",
    "glibc-headers-2.17-317.el7.x86_64.rpm",
    "mpfr-3.1.1-4.el7.x86_64.rpm",
    "libmpc-1.0.2-3.el7.x86_64.rpm",
    "libstdc++-4.8.5-44.el7.x86_64.rpm",
    "libstdc++-devel-4.8.5-44.el7.x86_64.rpm"
)

`$webClient = New-Object System.Net.WebClient

Write-Host "开始下载系统依赖..." -ForegroundColor Cyan

# 下载主包
foreach (`$pkg in `$Packages) {
    Write-Host "下载: `$pkg" -ForegroundColor Yellow
    try {
        `$url = "`$MIRROR`$pkg"
        `$path = Join-Path `$OutputDir `$pkg
        `$webClient.DownloadFile(`$url, `$path)
        Write-Host "  [OK]" -ForegroundColor Green
    } catch {
        Write-Host "  [FAILED]" -ForegroundColor Red
    }
}

# 下载依赖
Write-Host "下载依赖..." -ForegroundColor Cyan
foreach (`$dep in `$Deps) {
    Write-Host "下载: `$dep" -ForegroundColor Yellow
    try {
        `$url = "`$MIRROR`$dep"
        `$path = Join-Path `$OutputDir `$dep
        `$webClient.DownloadFile(`$url, `$path)
        Write-Host "  [OK]" -ForegroundColor Green
    } catch {
        Write-Host "  [FAILED]" -ForegroundColor Red
    }
}

`$webClient.Dispose()
Write-Host "下载完成!" -ForegroundColor Green
"@

    $scriptContent | Out-File -FilePath $scriptPath -Encoding UTF8
    Get-ColorOutput "[SUCCESS] 下载脚本已生成: $scriptPath" "Green"
}

function Get-InstallReadme {
    Get-ColorOutput "[STEP] 生成安装说明" "Blue"
    
    $readmePath = Join-Path $OutputDir "INSTALL_README.txt"
    
    $content = @"
======================================================
LumenIM 系统依赖离线包安装说明
======================================================

目录: D:\LumenIM-Packages\sysdeps

包含的系统依赖包 (版本 < 2.4):
----------------------------------------
包名          | 版本                       | 状态
----------------------------------------
wget          | 1.14-18.el7_9.1           | 需下载
curl          | 7.61.1-9.el7              | 需下载
git           | 1.8.3.1-23.el7_9          | 需下载
gcc           | 4.8.5-44.el7              | 需下载
gcc-c++       | 4.8.5-44.el7              | 需下载
make          | 3.82-29.el7               | 需下载
net-tools     | 2.0-0.0.20161004git.el7   | 需下载
unzip         | 6.0-24.el7_9              | 需下载
tar           | 1.26-35.el7               | 需下载
xz            | 5.2.2-2.el7               | 需下载
----------------------------------------

安装方法 (CentOS 7 服务器):
----------------------------------------
# 1. 挂载 U 盘或传输文件到服务器
# 2. 安装 RPM 包
cd /path/to/sysdeps
rpm -Uvh --force *.rpm

# 或使用 yum 本地安装
yum localinstall *.rpm

推荐方案 - 使用 CentOS 7 ISO:
----------------------------------------
1. 下载 CentOS-7-x86_64-DVD-2009.iso (~4.5GB)
2. 挂载 ISO: mount -o loop /dev/cdrom /mnt/iso
3. 配置本地源: /etc/yum.repos.d/local.repo
4. 安装: yum install gcc gcc-c++ make wget curl git

清华大学镜像:
https://mirrors.tuna.tsinghua.edu.cn/centos/7.9.2009/isos/x86_64/

======================================================
"@

    $content | Out-File -FilePath $readmePath -Encoding UTF8
    Get-ColorOutput "[SUCCESS] 安装说明已生成: $readmePath" "Green"
}

# ============================================================
# 主函数
# ============================================================

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "  LumenIM 本地依赖扫描脚本" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

Get-ColorOutput "项目目录: $ProjectDir" "White"
Get-ColorOutput "输出目录: $OutputDir" "White"
Get-ColorOutput "版本阈值: $VersionThreshold" "White"
Write-Host ""

# 创建输出目录
New-OutputDirectory -Path $OutputDir

# 识别低版本包
Show-LowVersionPackages

# 检查已有包
Get-ExistingPackages

# 生成下载脚本
Get-DownloadScript

# 生成安装说明
Get-InstallReadme

Write-Host ""
Get-ColorOutput "扫描完成!" "Green"
Write-Host ""
Write-Host "下一步操作:" -ForegroundColor Yellow
Write-Host "1. 运行 download-sysdeps.ps1 下载缺失的包"
Write-Host "2. 或使用 CentOS 7 ISO 作为本地源"
Write-Host "3. 将 sysdeps 目录复制到 U 盘上传到服务器"