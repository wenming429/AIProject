#Requires -Version 5.1
<#
.SYNOPSIS
    LumenIM 远程部署脚本 - 增强版（修复 scp 权限问题）
.DESCRIPTION
    支持密码认证和 SSH 密钥认证两种方式
    增强错误处理和调试信息
.PARAMETER Host
    目标服务器 IP 地址
.PARAMETER Username
    SSH 用户名
.PARAMETER Password
    SSH 密码（可选，有密钥时可不填）
.PARAMETER KeyPath
    SSH 私钥路径（可选）
.PARAMETER RemotePath
    远程部署目录
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$Host,

    [Parameter(Mandatory=$true)]
    [string]$Username,

    [Parameter(Mandatory=$false)]
    [string]$Password,

    [Parameter(Mandatory=$false)]
    [string]$KeyPath,

    [Parameter(Mandatory=$false)]
    [string]$RemotePath = "/opt/lumenim"
)

# ============================================================
# 配置
# ============================================================
$ProjectRoot = "D:\学习资料\AI_Projects\LumenIM"
$DeployPackageDir = "$ProjectRoot\software\scripts\deploy-package"
$OutputDir = "$DeployPackageDir\output"

# ============================================================
# 输出函数
# ============================================================
function Write-Step { param($Msg) Write-Host "[STEP] $Msg" -ForegroundColor Cyan }
function Write-Success { param($Msg) Write-Host "[OK] $Msg" -ForegroundColor Green }
function Write-Warn { param($Msg) Write-Host "[WARN] $Msg" -ForegroundColor Yellow }
function Write-Error-Msg { param($Msg) Write-Host "[ERROR] $Msg" -ForegroundColor Red }
function Write-Info { param($Msg) Write-Host "[INFO] $Msg" -ForegroundColor Gray }
function Write-Debug { param($Msg) Write-Host "[DEBUG] $Msg" -ForegroundColor DarkGray }

# ============================================================
# 诊断函数
# ============================================================
function Test-SshConnectivity {
    param($Username, $Host, $Password, $KeyPath)

    Write-Info "测试 SSH 连接..."

    # 方法1: 使用密钥
    if ($KeyPath -and (Test-Path $KeyPath)) {
        Write-Info "使用 SSH 密钥认证..."
        $testCmd = "ssh -i `"$KeyPath`" -o StrictHostKeyChecking=no -o ConnectTimeout=10 -o BatchMode=yes $Username@$Host 'echo key_auth_ok' 2>&1"
        $result = Invoke-Expression $testCmd

        if ($result -match "key_auth_ok") {
            return @{ Success = $true; Method = "Key"; KeyPath = $KeyPath }
        }
    }

    # 方法2: 使用 sshpass
    if ($Password) {
        Write-Info "使用密码认证..."
        $escapedPassword = $Password -replace "'", "'\''"

        # 使用 -v 选项查看详细输出帮助调试
        $testCmd = "sshpass -p '$escapedPassword' ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 -o BatchMode=no $Username@$Host 'echo pass_auth_ok' 2>&1"
        Write-Debug "执行命令: $testCmd"

        $result = Invoke-Expression $testCmd
        $exitCode = $LASTEXITCODE

        Write-Debug "退出码: $exitCode"
        Write-Debug "输出: $result"

        if ($result -match "pass_auth_ok") {
            return @{ Success = $true; Method = "Password"; Password = $Password; EscapedPassword = $escapedPassword }
        }

        # 分析失败原因
        if ($result -match "Permission denied") {
            Write-Error-Msg "密码认证失败：用户名或密码错误"
            Write-Info "请检查: 1) 用户名是否正确 2) 密码是否正确 3) SSH 服务器是否允许密码认证"
        } elseif ($result -match "Connection refused") {
            Write-Error-Msg "连接被拒绝：SSH 服务可能未运行或端口被阻止"
        } elseif ($result -match "Connection timed out") {
            Write-Error-Msg "连接超时：检查网络连接和防火墙"
        } elseif ($result -match "Host key verification failed") {
            Write-Error-Msg "主机密钥验证失败"
        }

        return @{ Success = $false; Error = $result }
    }

    return @{ Success = $false; Error = "未提供密码或密钥" }
}

# ============================================================
# SCP 传输函数（增强版）
# ============================================================
function Copy-FileViaScp {
    param(
        $LocalFile,
        $RemoteFile,
        $AuthInfo
    )

    $escapedLocal = $LocalFile -replace '\\', '/'

    if ($AuthInfo.Method -eq "Key") {
        $scpCmd = "scp -i `"$($AuthInfo.KeyPath)`" -o StrictHostKeyChecking=no -o ConnectTimeout=300 `"$escapedLocal`" `"$Username@$Host`:$RemoteFile`" 2>&1"
    } else {
        # 密码方式：使用环境变量方式传递密码更可靠
        $env:SSHPASS = $AuthInfo.Password
        $scpCmd = "sshpass -e scp -o StrictHostKeyChecking=no -o ConnectTimeout=300 `"$escapedLocal`" `"$Username@$Host`:$RemoteFile`" 2>&1"
    }

    Write-Debug "SCP 命令: $scpCmd"

    $result = Invoke-Expression $scpCmd
    $exitCode = $LASTEXITCODE

    if ($exitCode -eq 0) {
        return @{ Success = $true }
    } else {
        Write-Debug "SCP 失败: $result"
        return @{ Success = $false; Error = $result }
    }
}

# ============================================================
# SSH 命令执行函数
# ============================================================
function Invoke-SshCommand {
    param(
        $Command,
        $AuthInfo,
        $Timeout = 30
    )

    if ($AuthInfo.Method -eq "Key") {
        $sshCmd = "ssh -i `"$($AuthInfo.KeyPath)`" -o StrictHostKeyChecking=no -o ConnectTimeout=$Timeout $Username@$Host `"$Command`" 2>&1"
    } else {
        $escapedPass = $AuthInfo.EscapedPassword
        $sshCmd = "sshpass -p '$escapedPass' ssh -o StrictHostKeyChecking=no -o ConnectTimeout=$Timeout $Username@$Host `"$Command`" 2>&1"
    }

    Write-Debug "SSH 命令: $sshCmd"

    $result = Invoke-Expression $sshCmd
    $exitCode = $LASTEXITCODE

    return @{ Output = $result; ExitCode = $exitCode }
}

# ============================================================
# 主流程
# ============================================================
Write-Host ""
Write-Host "========================================" -ForegroundColor Magenta
Write-Host "   LumenIM 远程部署脚本 (增强版)" -ForegroundColor Magenta
Write-Host "========================================" -ForegroundColor Magenta
Write-Host ""
Write-Host "目标服务器: $Host" -ForegroundColor Yellow
Write-Host "部署目录:   $RemotePath" -ForegroundColor Yellow
Write-Host ""

# ============================================================
# Step 1: 检查本地依赖
# ============================================================
Write-Step "检查本地依赖"

$deps = @{
    "ssh" = { Test-Command "ssh" }
    "scp" = { Test-Command "scp" }
    "sshpass" = { Test-Command "sshpass" }
}

$missing = @()
foreach ($d in $deps.Keys) {
    if (-not (& $deps[$d])) {
        $missing += $d
    }
}

if ($missing.Count -gt 0) {
    Write-Error-Msg "缺少依赖: $($missing -join ', ')"

    if (-not (Test-Command "sshpass")) {
        Write-Host ""
        Write-Host "请安装 sshpass:" -ForegroundColor Yellow
        Write-Host "  winget install --id Shinghan.Sshpass -e" -ForegroundColor Cyan
        Write-Host "  或访问: https://sourceforge.net/projects/sshpass/" -ForegroundColor Cyan
    }
    exit 1
}

Write-Success "依赖检查通过"

# ============================================================
# Step 2: 测试 SSH 连接
# ============================================================
Write-Step "测试 SSH 连接"

$authInfo = Test-SshConnectivity -Username $Username -Host $Host -Password $Password -KeyPath $KeyPath

if (-not $authInfo.Success) {
    Write-Error-Msg "SSH 连接失败"
    exit 1
}

Write-Success "SSH 连接成功 (使用 $($authInfo.Method) 认证)"

# ============================================================
# Step 3: 查找部署包
# ============================================================
Write-Step "查找部署包"

$zipFiles = Get-ChildItem -Path $OutputDir -Filter "*.zip" -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending

if (-not $zipFiles) {
    Write-Error-Msg "未找到部署包，请先运行 deploy-ubuntu.ps1 构建"
    exit 1
}

$PackageFile = $zipFiles[0].FullName
$PackageSize = [math]::Round($zipFiles[0].Length / 1MB, 2)

Write-Info "找到部署包: $(Split-Path $PackageFile -Leaf)"
Write-Info "包大小: $PackageSize MB"

# ============================================================
# Step 4: 创建远程目录
# ============================================================
Write-Step "创建远程目录"

$result = Invoke-SshCommand -Command "mkdir -p $RemotePath && mkdir -p `"$RemotePath/backups`" && chmod 755 $RemotePath && echo dir_created" -AuthInfo $authInfo

if ($result.ExitCode -eq 0 -and $result.Output -match "dir_created") {
    Write-Success "远程目录已创建"
} else {
    Write-Error-Msg "创建目录失败: $($result.Output)"
    exit 1
}

# ============================================================
# Step 5: 备份旧版本
# ============================================================
Write-Step "检查旧版本并备份"

$result = Invoke-SshCommand -Command "if [ -f `"$RemotePath/lumenim`" ]; then echo 'exists'; else echo 'not_exists'; fi" -AuthInfo $authInfo

if ($result.Output -match "exists") {
    Write-Info "检测到旧版本，正在备份..."

    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $backupDir = "$RemotePath/backups/$timestamp"

    $backupResult = Invoke-SshCommand -Command "mkdir -p `"$backupDir`" && cp -r `"$RemotePath/lumenim`" `"$backupDir/`" 2>/dev/null; cp -r `"$RemotePath/scripts`" `"$backupDir/`" 2>/dev/null; echo backup_done" -AuthInfo $authInfo

    if ($backupResult.Output -match "backup_done") {
        Write-Success "旧版本已备份到: $backupDir"
    }
} else {
    Write-Info "未检测到旧版本"
}

# ============================================================
# Step 6: 传输文件
# ============================================================
Write-Step "传输部署包到远程服务器"

Write-Host "  包文件: $(Split-Path $PackageFile -Leaf)" -ForegroundColor White
Write-Host "  包大小: $PackageSize MB" -ForegroundColor White
Write-Host "  目标:   $Username@$Host`:$RemotePath" -ForegroundColor White
Write-Host ""

# 先清理可能存在的旧文件
$cleanupResult = Invoke-SshCommand -Command "rm -f `"$RemotePath/deploy.zip`"" -AuthInfo $authInfo

# 执行传输
Write-Info "正在传输，请稍候..."

$transferResult = Copy-FileViaScp -LocalFile $PackageFile -RemoteFile "$RemotePath/deploy.zip" -AuthInfo $authInfo

if ($transferResult.Success) {
    Write-Success "文件传输成功"
} else {
    Write-Error-Msg "文件传输失败"

    # 提供详细诊断
    Write-Host ""
    Write-Host "故障排除:" -ForegroundColor Yellow
    Write-Host "  1. 检查 SSH 服务: sudo systemctl status ssh" -ForegroundColor White
    Write-Host "  2. 检查磁盘空间: df -h" -ForegroundColor White
    Write-Host "  3. 检查目录权限: ls -la $RemotePath" -ForegroundColor White
    Write-Host "  4. 检查 SSH 配置: sudo cat /etc/ssh/sshd_config | grep -i password" -ForegroundColor White
    Write-Host ""

    # 尝试手动测试
    Write-Info "尝试手动测试 SCP..."
    if ($authInfo.Method -eq "Password") {
        $escapedPass = $authInfo.EscapedPassword
        Write-Debug "sshpass -p '***' scp -o StrictHostKeyChecking=no `"$PackageFile`" `"$Username@$Host`:$RemotePath/deploy.zip`""
    }

    exit 1
}

# 验证传输
Write-Info "验证传输..."
$verifyResult = Invoke-SshCommand -Command "ls -lh `"$RemotePath/deploy.zip`"" -AuthInfo $authInfo

if ($verifyResult.ExitCode -eq 0) {
    Write-Success "文件验证通过: $($verifyResult.Output.Trim())"
} else {
    Write-Warn "验证失败，请手动检查"
}

# ============================================================
# Step 7: 解压部署
# ============================================================
Write-Step "解压并部署"

$deployCmd = "cd `"$RemotePath`" && unzip -o deploy.zip && mv deploy/* . 2>/dev/null || true && mv deploy/* . 2>/dev/null || true && rm -rf deploy && chmod +x lumenim scripts/*.sh 2>/dev/null && echo deploy_done"
$result = Invoke-SshCommand -Command $deployCmd -AuthInfo $authInfo -Timeout 60

if ($result.Output -match "deploy_done") {
    Write-Success "部署完成"
} else {
    Write-Warn "部署可能未完全成功: $($result.Output)"
}

# ============================================================
# Step 8: 配置服务
# ============================================================
Write-Step "配置 systemd 服务"

$serviceFile = @"
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
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
"@

# 写入临时文件
$tempServiceFile = "$env:TEMP\lumenim_$PID.service"
$serviceFile | Out-File -FilePath $tempServiceFile -Encoding UTF8

# 上传服务文件
$uploadResult = Copy-FileViaScp -LocalFile $tempServiceFile -RemoteFile "/tmp/lumenim.service" -AuthInfo $authInfo
Remove-Item $tempServiceFile -Force

if ($uploadResult.Success) {
    Write-Info "上传服务配置文件..."

    $installResult = Invoke-SshCommand -Command "sudo mv /tmp/lumenim.service /etc/systemd/system/ && sudo systemctl daemon-reload && sudo systemctl enable lumenim && echo service_installed" -AuthInfo $authInfo

    if ($installResult.Output -match "service_installed") {
        Write-Success "服务已安装并启用"
    } else {
        Write-Warn "服务安装可能失败: $($installResult.Output)"
    }
} else {
    Write-Warn "服务配置上传失败"
}

# ============================================================
# Step 9: 启动服务
# ============================================================
Write-Step "启动服务"

$startResult = Invoke-SshCommand -Command "sudo systemctl start lumenim && sleep 2 && sudo systemctl status lumenim --no-pager -l" -AuthInfo $authInfo -Timeout 30

if ($startResult.Output -match "active \(running\)") {
    Write-Success "服务启动成功"
} else {
    Write-Warn "服务可能未正常启动，检查输出:"
    Write-Host $startResult.Output -ForegroundColor DarkGray
}

# ============================================================
# 完成
# ============================================================
Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "   部署完成！" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "  部署目录: $RemotePath" -ForegroundColor White
Write-Host ""
Write-Host "  远程命令:" -ForegroundColor Cyan
Write-Host "    sudo systemctl status lumenim   # 查看状态" -ForegroundColor White
Write-Host "    sudo journalctl -u lumenim -f    # 查看日志" -ForegroundColor White
Write-Host "    sudo systemctl restart lumenim   # 重启服务" -ForegroundColor White
Write-Host ""

Write-Host "  建议首次部署后检查:" -ForegroundColor Yellow
Write-Host "    1. 服务状态: sudo systemctl status lumenim" -ForegroundColor White
Write-Host "    2. 端口监听: sudo netstat -tlnp | grep lumenim" -ForegroundColor White
Write-Host "    3. 配置文件: $RemotePath/config.yaml" -ForegroundColor White
Write-Host ""
