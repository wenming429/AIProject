# LumenIM 依赖包自动化下载脚本
# LumenIM Dependencies Auto-Download Script
# 版本: 1.0.0
# 更新日期: 2026-04-07

#Requires -Version 5.1

<#
.SYNOPSIS
    LumenIM 依赖包自动化下载脚本
.DESCRIPTION
    自动下载 LumenIM 项目运行所需的所有依赖安装包
.PARAMETER SkipExisting
    跳过已存在的文件（默认：$true）
.PARAMETER Components
    指定要下载的组件：Core, Database, Proto, DevTools, Frontend, All
.PARAMETER OutputDir
    输出目录（默认：当前目录下的 software 文件夹）
.EXAMPLE
    .\download-dependencies.ps1 -Components All
.EXAMPLE
    .\download-dependencies.ps1 -SkipExisting $false
#>

[CmdletBinding()]
param(
    [Parameter()]
    [bool]$SkipExisting = $true,

    [Parameter()]
    [ValidateSet('Core', 'Database', 'Proto', 'DevTools', 'Frontend', 'All')]
    [string[]]$Components = @('All'),

    [Parameter()]
    [string]$OutputDir = (Join-Path $PSScriptRoot "")
)

# ============================================================
# 配置区域
# ============================================================

$Script:ProjectRoot = $PSScriptRoot
$Script:SoftwareDir = Join-Path $ProjectRoot "software"
$Script:BinDir = Join-Path $SoftwareDir "bin"
$Script:LogDir = Join-Path $SoftwareDir "logs"

# 镜像源配置（中国大陆用户可使用国内镜像加速）
$UseMirror = $true
$MirrorBase = "https://npm.taobao.org/mirrors"
$OfficialBase = "https://"

# ============================================================
# 包清单定义
# ============================================================

$CorePackages = @(
    @{
        Name = "Go"
        Version = "1.25.0"
        FileName = "go1.25.0.windows-amd64.msi"
        Url = "https://go.dev/dl/go1.25.0.windows-amd64.msi"
        InstallType = "msi"
        Description = "Go 语言运行环境"
    },
    @{
        Name = "Node.js"
        Version = "22.14.0"
        FileName = "node-v22.14.0-x64.msi"
        Url = "https://nodejs.org/dist/v22.14.0/node-v22.14.0-x64.msi"
        InstallType = "msi"
        Description = "Node.js JavaScript 运行时"
    },
    @{
        Name = "pnpm"
        Version = "10.0.0"
        FileName = "pnpm-windows-x64.exe"
        Url = "https://github.com/pnpm/pnpm/releases/download/v10.0.0/pnpm-windows-x64.exe"
        InstallType = "exe"
        Description = "高性能包管理器"
    }
)

$DatabasePackages = @(
    @{
        Name = "MySQL"
        Version = "8.0.40"
        FileName = "mysql-8.0.40-winx64.zip"
        Url = "https://dev.mysql.com/get/Downloads/MySQL-8.0/mysql-8.0.40-winx64.zip"
        InstallType = "zip"
        Description = "MySQL 8.0 数据库"
    },
    @{
        Name = "Redis"
        Version = "5.0.14.1"
        FileName = "Redis-x64-5.0.14.1.msi"
        Url = "https://github.com/tporadowski/redis/releases/download/v5.0.14.1/Redis-x64-5.0.14.1.msi"
        InstallType = "msi"
        Description = "Redis 缓存数据库"
    }
)

$ProtoPackages = @(
    @{
        Name = "protoc"
        Version = "25.1"
        FileName = "protoc-25.1-win64.zip"
        Url = "https://github.com/protocolbuffers/protobuf/releases/download/v25.1/protoc-25.1-win64.zip"
        InstallType = "zip"
        Description = "Protocol Buffers 编译器"
    },
    @{
        Name = "buf"
        Version = "1.28.1"
        FileName = "buf-Windows-x86_64.exe"
        Url = "https://github.com/bufbuild/buf/releases/download/v1.28.1/buf-Windows-x86_64.exe"
        InstallType = "exe"
        Description = "Buf CLI 工具"
    }
)

$DevToolsPackages = @(
    @{
        Name = "Git"
        Version = "2.48.1"
        FileName = "Git-2.48.1-64-bit.exe"
        Url = "https://github.com/git-for-windows/git/releases/download/v2.48.1.windows.1/Git-2.48.1-64-bit.exe"
        InstallType = "exe"
        Description = "Git 版本控制系统"
    },
    @{
        Name = "Make"
        Version = "3.81"
        FileName = "make-3.81-bin.zip"
        Url = "https://sourceforge.net/projects/gnuwin32/files/make/3.81/make-3.81-bin.zip"
        InstallType = "zip"
        Description = "GNU Make 构建工具"
    }
)

$FrontendPackages = @(
    @{
        Name = "electron"
        Version = "33.4.0"
        FileName = "electron-v33.4.0-win32-x64.zip"
        Url = "https://cdn.npmmirror.com/binaries/electron/v33.4.0/electron-v33.4.0-win32-x64.zip"
        InstallType = "zip"
        Description = "Electron 跨平台桌面框架"
    }
)

# ============================================================
# 函数定义
# ============================================================

function Write-Log {
    param(
        [Parameter(Mandatory)]
        [string]$Message,
        [Parameter()]
        [ValidateSet('Info', 'Success', 'Warning', 'Error')]
        [string]$Level = 'Info'
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $color = switch ($Level) {
        'Info' { 'Cyan' }
        'Success' { 'Green' }
        'Warning' { 'Yellow' }
        'Error' { 'Red' }
    }
    
    $logMessage = "[$timestamp] [$Level] $Message"
    Write-Host $logMessage -ForegroundColor $color
    
    # 写入日志文件
    $logFile = Join-Path $LogDir "download-$(Get-Date -Format 'yyyyMMdd').log"
    Add-Content -Path $logFile -Value $logMessage -Encoding UTF8
}

function Initialize-Directories {
    $dirs = @($SoftwareDir, $BinDir, $LogDir)
    foreach ($dir in $dirs) {
        if (-not (Test-Path $dir)) {
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
            Write-Log "创建目录: $dir" -Level Success
        }
    }
}

function Test-FileExists {
    param(
        [Parameter(Mandatory)]
        [string]$FilePath,
        [Parameter()]
        [bool]$SkipCheck = $true
    )
    
    if ($SkipCheck -and (Test-Path $FilePath)) {
        Write-Log "文件已存在，跳过下载: $FilePath" -Level Warning
        return $true
    }
    return $false
}

function Get-FileHash256 {
    param(
        [Parameter(Mandatory)]
        [string]$FilePath
    )
    
    if (Test-Path $FilePath) {
        $hash = Get-FileHash -Path $FilePath -Algorithm SHA256
        return $hash.Hash
    }
    return $null
}

function Download-File {
    param(
        [Parameter(Mandatory)]
        [string]$Url,
        [Parameter(Mandatory)]
        [string]$OutputPath,
        [Parameter()]
        [int]$MaxRetries = 3
    )
    
    $retryCount = 0
    $downloaded = $false
    
    while (-not $downloaded -and $retryCount -lt $MaxRetries) {
        try {
            Write-Log "正在下载: $Url"
            
            # 使用 WebClient 下载，支持进度显示
            $webClient = New-Object System.Net.WebClient
            $webClient.DownloadFile($Url, $OutputPath)
            $webClient.Dispose()
            
            $downloaded = $true
            $fileSize = (Get-Item $OutputPath).Length / 1MB
            Write-Log "下载完成: $OutputPath (${fileSize:N2} MB)" -Level Success
            
        }
        catch {
            $retryCount++
            Write-Log "下载失败 (重试 $retryCount/$MaxRetries): $($_.Exception.Message)" -Level Warning
            
            if (Test-Path $OutputPath) {
                Remove-Item $OutputPath -Force
            }
            
            Start-Sleep -Seconds 3
        }
    }
    
    if (-not $downloaded) {
        Write-Log "下载失败，已达到最大重试次数: $Url" -Level Error
        return $false
    }
    
    return $true
}

function Install-GoTool {
    param(
        [Parameter(Mandatory)]
        [string]$ToolName,
        [Parameter(Mandatory)]
        [string]$InstallCmd
    )
    
    $goBinPath = Join-Path $env:USERPROFILE "go\bin"
    
    if (Test-Path (Join-Path $goBinPath "$ToolName.exe")) {
        Write-Log "Go 工具已安装: $ToolName" -Level Warning
        return $true
    }
    
    try {
        Write-Log "正在安装 Go 工具: $ToolName"
        Write-Log "执行命令: go install $InstallCmd" -Level Info
        
        $process = Start-Process -FilePath "go" -ArgumentList "install", $InstallCmd -NoNewWindow -Wait -PassThru
        
        if ($process.ExitCode -eq 0) {
            Write-Log "Go 工具安装成功: $ToolName" -Level Success
            return $true
        }
        else {
            Write-Log "Go 工具安装失败: $ToolName" -Level Error
            return $false
        }
    }
    catch {
        Write-Log "Go 工具安装异常: $($_.Exception.Message)" -Level Error
        return $false
    }
}

function Get-ComponentPackages {
    param(
        [Parameter(Mandatory)]
        [string[]]$SelectedComponents
    )
    
    $allPackages = @()
    
    foreach ($component in $SelectedComponents) {
        switch ($component) {
            'Core' { $allPackages += $CorePackages }
            'Database' { $allPackages += $DatabasePackages }
            'Proto' { $allPackages += $ProtoPackages }
            'DevTools' { $allPackages += $DevToolsPackages }
            'Frontend' { $allPackages += $FrontendPackages }
            'All' {
                $allPackages += $CorePackages
                $allPackages += $DatabasePackages
                $allPackages += $ProtoPackages
                $allPackages += $DevToolsPackages
                $allPackages += $FrontendPackages
            }
        }
    }
    
    # 去重
    return $allPackages | Sort-Object { $_.Name } -Unique
}

# ============================================================
# 主程序
# ============================================================

function Main {
    Write-Host ""
    Write-Host "==================================================" -ForegroundColor Cyan
    Write-Host "   LumenIM 依赖包自动化下载脚本 v1.0.0" -ForegroundColor Cyan
    Write-Host "==================================================" -ForegroundColor Cyan
    Write-Host ""
    
    # 初始化目录
    Initialize-Directories
    
    # 获取要下载的包
    $packages = Get-ComponentPackages -SelectedComponents $Components
    
    Write-Log "准备下载 $($packages.Count) 个软件包" -Level Info
    Write-Log "输出目录: $SoftwareDir" -Level Info
    Write-Log "跳过已存在文件: $SkipExisting" -Level Info
    Write-Host ""
    
    # 统计信息
    $successCount = 0
    $skipCount = 0
    $failCount = 0
    $totalSize = 0
    
    foreach ($pkg in $packages) {
        $outputPath = Join-Path $BinDir $pkg.FileName
        
        Write-Host "----------------------------------------" -ForegroundColor DarkGray
        Write-Log "正在处理: $($pkg.Name) $($pkg.Version)" -Level Info
        Write-Log "描述: $($pkg.Description)" -Level Info
        
        # 检查文件是否已存在
        if (Test-FileExists -FilePath $outputPath -SkipCheck (-not $SkipExisting)) {
            $skipCount++
            continue
        }
        
        # 下载文件
        $result = Download-File -Url $pkg.Url -OutputPath $outputPath
        
        if ($result) {
            $successCount++
            $totalSize += (Get-Item $outputPath).Length / 1MB
        }
        else {
            $failCount++
        }
        
        Write-Host ""
    }
    
    # 安装 Go 工具
    Write-Host "==================================================" -ForegroundColor Cyan
    Write-Log "安装 Go 工具..." -Level Info
    
    $goTools = @(
        "google.golang.org/protobuf/cmd/protoc-gen-go@v1.36.11",
        "github.com/envoyproxy/protoc-gen-validate@v1.2.1",
        "github.com/google/wire/cmd/wire@v0.7.0"
    )
    
    foreach ($tool in $goTools) {
        $toolName = ($tool -split '@')[0] -split '/' | Select-Object -Last 1
        Install-GoTool -ToolName $toolName -InstallCmd $tool
    }
    
    # 输出统计
    Write-Host ""
    Write-Host "==================================================" -ForegroundColor Cyan
    Write-Host "   下载完成！" -ForegroundColor Cyan
    Write-Host "==================================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Log "成功: $successCount 个" -Level Success
    Write-Log "跳过: $skipCount 个" -Level Warning
    Write-Log "失败: $failCount 个" -Level $(if ($failCount -gt 0) { 'Error' } else { 'Info' })
    Write-Log "总大小: $([math]::Round($totalSize, 2)) MB" -Level Info
    Write-Host ""
    
    # 显示已下载的文件
    Write-Host "已下载的文件:" -ForegroundColor Yellow
    Get-ChildItem -Path $BinDir -File | ForEach-Object {
        $size = $_.Length / 1MB
        Write-Host "  - $($_.Name) ($([math]::Round($size, 2)) MB)" -ForegroundColor White
    }
    
    Write-Host ""
    Write-Host "下一步操作:" -ForegroundColor Yellow
    Write-Host "  1. 运行安装指南: .\INSTALL_GUIDE.md" -ForegroundColor White
    Write-Host "  2. 查看软件包清单: .\PACKAGE_LIST.md" -ForegroundColor White
    Write-Host ""
}

# 执行主程序
Main
