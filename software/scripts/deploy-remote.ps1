#Requires -Version 5.1
<#
.SYNOPSIS
    LumenIM 远程部署脚本 - 自动部署到 Ubuntu 服务器
.DESCRIPTION
    通过 SSH 自动化部署 LumenIM 项目到远程 Ubuntu 服务器
    支持密码认证，自动检查依赖，打包并传输文件
.PARAMETER Host
    目标服务器 IP 地址
.PARAMETER Username
    SSH 用户名
.PARAMETER Password
    SSH 密码
.PARAMETER RemotePath
    远程部署目录，默认为 /opt/lumenim
.EXAMPLE
    .\deploy-remote.ps1 -Host "192.168.1.100" -Username "deploy" -Password "your_password"
#>

param(
    [Parameter(Mandatory=$true, HelpMessage="目标服务器 IP 地址")]
    [ValidateNotNullOrEmpty()]
    [string]$Host,

    [Parameter(Mandatory=$true, HelpMessage="SSH 用户名")]
    [ValidateNotNullOrEmpty()]
    [string]$Username,

    [Parameter(Mandatory=$true, HelpMessage="SSH 密码")]
    [ValidateNotNullOrEmpty()]
    [string]$Password,

    [Parameter(Mandatory=$false, HelpMessage="远程部署目录")]
    [string]$RemotePath = "/opt/lumenim"
)

# ============================================================
# 配置
# ============================================================
$ProjectRoot = "D:\学习资料\AI_Projects\LumenIM"
$DeployPackageDir = "$ProjectRoot\software\scripts\deploy-package"
$TempDir = "$DeployPackageDir\temp"
$OutputDir = "$DeployPackageDir\output"

# ============================================================
# 颜色输出函数
# ============================================================
function Write-Step { param($Msg) Write-Host "[STEP] $Msg" -ForegroundColor Cyan }
function Write-Success { param($Msg) Write-Host "[OK] $Msg" -ForegroundColor Green }
function Write-Warn { param($Msg) Write-Host "[WARN] $Msg" -ForegroundColor Yellow }
function Write-Error-Msg { param($Msg) Write-Host "[ERROR] $Msg" -ForegroundColor Red }
function Write-Info { param($Msg) Write-Host "[INFO] $Msg" -ForegroundColor Gray }
function Write-Banner {
    param($Title)
    $line = "=" * 60
    Write-Host ""
    Write-Host $line -ForegroundColor Magenta
    Write-Host "  $Title" -ForegroundColor Magenta
    Write-Host $line -ForegroundColor Magenta
}

# ============================================================
# 辅助函数
# ============================================================
function Test-Command {
    param([string]$Command)
    $null -ne (Get-Command $Command -ErrorAction SilentlyContinue)
}

function Get-FileHashMB {
    param([string]$Path)
    if (Test-Path $Path) {
        return [math]::Round((Get-Item $Path).Length / 1MB, 2)
    }
    return 0
}

# ============================================================
# 清理函数
# ============================================================
function Clean-Temp {
    Write-Info "清理临时文件..."
    if (Test-Path $TempDir) {
        Remove-Item -Path $TempDir -Recurse -Force -ErrorAction SilentlyContinue
    }
    if (Test-Path "$TempDir\deploy") {
        Remove-Item -Path "$TempDir\deploy" -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# ============================================================
# STEP 0: 环境检查
# ============================================================
Write-Banner "LumenIM 远程部署脚本"
Write-Host "目标服务器: $Host" -ForegroundColor Yellow
Write-Host "部署目录:   $RemotePath" -ForegroundColor Yellow
Write-Host "项目路径:   $ProjectRoot" -ForegroundColor Yellow
Write-Host ""

# ============================================================
# STEP 1: 检查本地依赖
# ============================================================
Write-Banner "Step 1: 检查本地依赖"

$LocalDeps = @{
    "Go"       = @{Cmd = "go"; Check = { (go version) -match "go\d" }}
    "Node.js"  = @{Cmd = "node"; Check = { (node --version) -match "v\d" }}
    "pnpm"     = @{Cmd = "pnpm"; Check = { (pnpm --version) -match "\d" }}
    "tar"      = @{Cmd = "tar"; Check = { Test-Command "tar" }}
    "sshpass"  = @{Cmd = "sshpass"; Check = { Test-Command "sshpass" }}
    "ssh"      = @{Cmd = "ssh"; Check = { Test-Command "ssh" }}
    "scp"      = @{Cmd = "scp"; Check = { Test-Command "scp" }}
}

$allLocalOk = $true

foreach ($dep in $LocalDeps.GetEnumerator()) {
    Write-Info "检查 $($dep.Key)..."
    try {
        $result = & $dep.Value.Check
        if ($result) {
            Write-Success "$($dep.Key) 已安装"
        } else {
            Write-Error-Msg "$($dep.Key) 未找到"
            $allLocalOk = $false
        }
    } catch {
        Write-Error-Msg "$($dep.Key) 未找到"
        $allLocalOk = $false
    }
}

if (-not $allLocalOk) {
    Write-Error-Msg "本地依赖检查失败，请安装缺失的组件"
    exit 1
}

Write-Success "所有本地依赖检查通过"

# ============================================================
# STEP 1.5: 检查 sshpass (Windows Git Bash 环境)
# ============================================================
Write-Banner "Step 1.5: sshpass 检查"

if (-not (Test-Command "sshpass")) {
    Write-Warn "sshpass 未安装，尝试通过 winget 安装..."

    # 检查 winget 是否可用
    if (Test-Command "winget") {
        try {
            Write-Info "正在通过 winget 安装 sshpass..."
            winget install --id Shinghan.Sshpass -e --silent --accept-package-agreements --accept-source-agreements
            # 刷新环境变量
            $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")

            if (Test-Command "sshpass") {
                Write-Success "sshpass 安装成功"
            } else {
                throw "sshpass 安装后仍不可用"
            }
        } catch {
            Write-Warn "winget 安装失败，尝试其他方法..."
        }
    }

    # 备选方案：通过 Chocolatey 安装
    if (-not (Test-Command "sshpass") -and (Test-Command "choco")) {
        try {
            Write-Info "正在通过 Chocolatey 安装 sshpass..."
            choco install sshpass -y
            if (Test-Command "sshpass") {
                Write-Success "sshpass 安装成功"
            }
        } catch {
            Write-Warn "Chocolatey 安装失败"
        }
    }

    # Git Bash 用户备选方案
    if (-not (Test-Command "sshpass") -and (Test-Path "C:\Program Files\Git\usr\bin\sshpass.exe" -PathType Leaf)) {
        Copy-Item "C:\Program Files\Git\usr\bin\sshpass.exe" "$env:LOCALAPPDATA\Microsoft\WindowsApps\sshpass.exe" -Force
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
    }

    # 最终检查
    if (-not (Test-Command "sshpass")) {
        Write-Error-Msg "sshpass 安装失败！"
        Write-Host ""
        Write-Host "========================================" -ForegroundColor Yellow
        Write-Host "sshpass 安装方法：" -ForegroundColor Yellow
        Write-Host "========================================" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "方法1: winget (推荐)" -ForegroundColor Cyan
        Write-Host "  winget install --id Shinghan.Sshpass -e"
        Write-Host ""
        Write-Host "方法2: Chocolatey" -ForegroundColor Cyan
        Write-Host "  choco install sshpass -y"
        Write-Host ""
        Write-Host "方法3: MSYS2" -ForegroundColor Cyan
        Write-Host "  pacman -S msys/sshpass"
        Write-Host ""
        Write-Host "方法4: 手动下载" -ForegroundColor Cyan
        Write-Host "  https://sourceforge.net/projects/sshpass/files/"
        Write-Host ""
        exit 1
    }
} else {
    Write-Success "sshpass 已安装"
}

# ============================================================
# STEP 2: 构建本地部署包
# ============================================================
Write-Banner "Step 2: 构建本地部署包"

# 调用现有的 deploy-ubuntu.ps1
$localBuildScript = "$DeployPackageDir\deploy-ubuntu.ps1"

if (-not (Test-Path $localBuildScript)) {
    Write-Error-Msg "本地构建脚本不存在: $localBuildScript"
    exit 1
}

Write-Info "执行本地构建脚本..."
Write-Host ""

try {
    # 使用 -NoProfile 避免环境干扰
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $localBuildScript

    if ($LASTEXITCODE -ne 0) {
        throw "本地构建脚本执行失败"
    }
} catch {
    Write-Error-Msg "本地构建失败: $_"
    exit 1
}

# 查找生成的包
$zipFiles = Get-ChildItem -Path $OutputDir -Filter "*.zip" -ErrorAction SilentlyContinue
if (-not $zipFiles) {
    Write-Error-Msg "未找到部署包 (.zip 文件)"
    exit 1
}

# 使用最新的包
$PackageFile = ($zipFiles | Sort-Object LastWriteTime -Descending | Select-Object -First 1).FullName
$PackageSize = Get-FileHashMB $PackageFile

Write-Success "部署包已准备就绪"
Write-Host "  文件: $PackageFile" -ForegroundColor White
Write-Host "  大小: $PackageSize MB" -ForegroundColor White

# ============================================================
# STEP 3: 远程连接测试
# ============================================================
Write-Banner "Step 3: 远程连接测试"

Write-Info "测试 SSH 连接: $Username@$Host"

# 使用 sshpass 测试连接
$testCmd = "sshpass -p '$Password' ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 $Username@$Host 'echo connected' 2>&1"
$testResult = Invoke-Expression $testCmd

if ($testResult -match "connected") {
    Write-Success "SSH 连接成功"
} else {
    Write-Error-Msg "SSH 连接失败"
    Write-Host "错误信息: $testResult" -ForegroundColor Red
    exit 1
}

# ============================================================
# STEP 4: 创建远程目录
# ============================================================
Write-Banner "Step 4: 创建远程目录"

Write-Info "在远程服务器创建部署目录..."

$mkDirCmd = "sshpass -p '$Password' ssh $Username@$Host 'mkdir -p $RemotePath && mkdir -p `"$RemotePath/backups`" && echo dir_created' 2>&1"
$mkDirResult = Invoke-Expression $mkDirCmd

if ($mkDirResult -match "dir_created") {
    Write-Success "远程目录已创建: $RemotePath"
} else {
    Write-Error-Msg "创建远程目录失败: $mkDirResult"
    exit 1
}

# ============================================================
# STEP 5: 备份旧版本（如存在）
# ============================================================
Write-Banner "Step 5: 备份旧版本"

$backupCheckCmd = "sshpass -p '$Password' ssh $Username@$Host 'if [ -f `"$RemotePath/lumenim`" ]; then echo exists; else echo not_exists; fi' 2>&1"
$backupCheckResult = Invoke-Expression $backupCheckCmd

if ($backupCheckResult -match "exists") {
    Write-Warn "检测到旧版本，正在备份..."

    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $backupDir = "$RemotePath/backups/$timestamp"

    $backupCmd = "sshpass -p '$Password' ssh $Username@$Host 'cp -r $RemotePath/lumenim `"$backupDir/lumenim`" 2>/dev/null; cp -r $RemotePath/scripts `"$backupDir/scripts`" 2>/dev/null; echo backup_done' 2>&1"
    $backupResult = Invoke-Expression $backupCmd

    if ($backupResult -match "backup_done") {
        Write-Success "旧版本已备份到: $backupDir"
    } else {
        Write-Warn "备份失败，继续部署..."
    }
} else {
    Write-Info "未检测到旧版本，跳过备份"
}

# ============================================================
# STEP 6: 传输部署包
# ============================================================
Write-Banner "Step 6: 传输部署包"

Write-Info "正在传输文件到 $Host..."
Write-Host "  包文件: $([System.IO.Path]::GetFileName($PackageFile))" -ForegroundColor White
Write-Host "  包大小: $PackageSize MB" -ForegroundColor White
Write-Host "  目标:   $Username@$Host:$RemotePath" -ForegroundColor White
Write-Host ""

# 显示进度
$progress = 0
$transferDone = $false

# 使用 scp 传输
$scpCmd = "sshpass -p '$Password' scp -o StrictHostKeyChecking=no -o ConnectTimeout=300 `"$PackageFile`" `"$Username@$Host:$RemotePath/deploy.zip`" 2>&1"

Write-Info "传输开始，请稍候..."

try {
    $transferResult = Invoke-Expression $scpCmd

    if ($LASTEXITCODE -eq 0) {
        Write-Success "文件传输成功"
        $transferDone = $true
    } else {
        Write-Error-Msg "文件传输失败: $transferResult"
        exit 1
    }
} catch {
    Write-Error-Msg "文件传输异常: $_"
    exit 1
}

# 验证传输
Write-Info "验证传输文件..."
$verifyCmd = "sshpass -p '$Password' ssh $Username@$Host 'ls -lh $RemotePath/deploy.zip' 2>&1"
$verifyResult = Invoke-Expression $verifyCmd

if ($verifyResult -match "deploy.zip") {
    Write-Success "文件验证通过"
} else {
    Write-Error-Msg "文件验证失败"
    exit 1
}

# ============================================================
# STEP 7: 远程部署
# ============================================================
Write-Banner "Step 7: 执行远程部署"

Write-Info "解压并配置部署包..."

# 解压部署包
$unzipCmd = "sshpass -p '$Password' ssh $Username@$Host 'cd $RemotePath && unzip -o deploy.zip && mv deploy/* . && rm -rf deploy && chmod +x lumenim scripts/*.sh 2>/dev/null || true && echo deploy_done' 2>&1"
$unzipResult = Invoke-Expression $unzipCmd

if ($unzipResult -match "deploy_done") {
    Write-Success "部署包解压成功"
} else {
    Write-Error-Msg "解压失败: $unzipResult"
    exit 1
}

# ============================================================
# STEP 8: 配置 systemd 服务
# ============================================================
Write-Banner "Step 8: 配置 systemd 服务"

Write-Info "检查并配置 systemd 服务..."

$serviceConfig = @"
[Unit]
Description=LumenIM Backend Service
After=network.target

[Service]
Type=simple
User=$Username
WorkingDirectory=$RemotePath
ExecStart=$RemotePath/lumenim
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
"@

# 将服务配置写入临时文件
$tempServiceFile = "$env:TEMP\lumenim.service"
$serviceConfig | Out-File -FilePath $tempServiceFile -Encoding UTF8

# 上传服务配置
$uploadServiceCmd = "sshpass -p '$Password' scp `"$tempServiceFile`" `"$Username@$Host:/tmp/lumenim.service`" 2>&1"
$uploadResult = Invoke-Expression $uploadServiceCmd

if ($LASTEXITCODE -eq 0) {
    Write-Success "服务配置文件已上传"
} else {
    Write-Warn "服务配置上传失败，尝试手动配置"
}

# 安装服务
$installServiceCmd = "sshpass -p '$Password' ssh $Username@$Host 'sudo mv /tmp/lumenim.service /etc/systemd/system/ && sudo systemctl daemon-reload && sudo systemctl enable lumenim && echo service_installed' 2>&1"
$installResult = Invoke-Expression $installServiceCmd

if ($installResult -match "service_installed") {
    Write-Success "systemd 服务已安装并启用"
} else {
    Write-Warn "systemd 服务安装可能失败，请手动检查"
}

# 清理临时文件
Remove-Item $tempServiceFile -Force -ErrorAction SilentlyContinue

# ============================================================
# STEP 9: 启动服务
# ============================================================
Write-Banner "Step 9: 启动服务"

Write-Info "启动 LumenIM 服务..."

$startCmd = "sshpass -p '$Password' ssh $Username@$Host 'sudo systemctl start lumenim && sleep 2 && sudo systemctl status lumenim --no-pager' 2>&1"
$startResult = Invoke-Expression $startCmd

if ($startResult -match "active \(running\)") {
    Write-Success "服务启动成功！"
} elseif ($startResult -match "Unit lumenim.service could not be found") {
    Write-Warn "systemd 服务未安装，使用直接启动方式"
    $directStartCmd = "sshpass -p '$Password' ssh $Username@$Host 'cd $RemotePath && nohup ./lumenim > lumenim.log 2>&1 &'" -ForegroundColor DarkCyan
    Invoke-Expression $directStartCmd
    Write-Success "进程已后台启动"
} else {
    Write-Warn "服务状态未知，请检查日志"
}

# ============================================================
# STEP 10: 部署完成
# ============================================================
Write-Banner "Deployment Complete!"
Write-Host ""
Write-Host "  部署目录:   $RemotePath" -ForegroundColor Green
Write-Host "  服务状态:   请在服务器上执行 'sudo systemctl status lumenim' 查看" -ForegroundColor Green
Write-Host "  日志查看:   'sudo journalctl -u lumenim -f'" -ForegroundColor Green
Write-Host "  直接启动:   'cd $RemotePath && ./lumenim'" -ForegroundColor Green
Write-Host ""
Write-Host "  常用命令:" -ForegroundColor Cyan
Write-Host "    sudo systemctl start lumenim    # 启动服务" -ForegroundColor White
Write-Host "    sudo systemctl stop lumenim     # 停止服务" -ForegroundColor White
Write-Host "    sudo systemctl restart lumenim  # 重启服务" -ForegroundColor White
Write-Host "    sudo systemctl status lumenim   # 查看状态" -ForegroundColor White
Write-Host ""

# 清理本地临时文件
Write-Info "清理本地临时文件..."
Clean-Temp

Write-Success "部署流程完成！"
