#===============================================================================
# LumenIM 自动化部署脚本 - Windows PowerShell 版本
# 使用说明: 在 Windows 机器上以管理员权限执行
# 前提条件: 安装 plink.exe 和 pscp.exe (来自 PuTTY 包)
#===============================================================================

param(
    [string]$Host = "192.168.23.129",
    [string]$User = "root",
    [string]$Password = "123456",
    [string]$ProjectPath = "d:\学习资料\AI_Projects\LumenIM",
    [string]$MySqlPassword = "wenming429"
)

# 配置
$RemoteDeployDir = "/opt/lumenim"
$LocalTempDir = "$env:TEMP\LumenIM-Build-$(Get-Date -Format 'yyyyMMddHHmmss')"
$PackageName = "lumenim-package.tar.gz"
$RemoteScriptName = "remote-deploy.sh"

# 颜色函数
function Write-Info { param($Message) Write-Host "[INFO] $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - $Message" -ForegroundColor Green }
function Write-Warn { param($Message) Write-Host "[WARN] $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - $Message" -ForegroundColor Yellow }
function Write-Err { param($Message) Write-Host "[ERROR] $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - $Message" -ForegroundColor Red }

#===============================================================================
# 生成远程部署脚本内容
#===============================================================================
function Get-RemoteDeployScript {
    $scriptLines = @()
    $scriptLines += "cd $RemoteDeployDir"
    $scriptLines += ""
    $scriptLines += "echo '=========================================='"
    $scriptLines += "echo 'LumenIM 远程部署'"
    $scriptLines += "echo '=========================================='"
    $scriptLines += ""
    $scriptLines += "echo '[1/5] 检查 Docker...'"
    $scriptLines += "systemctl start docker"
    $scriptLines += "systemctl enable docker"
    $scriptLines += "echo `"Docker: `$(docker --version)`""
    $scriptLines += ""
    $scriptLines += "echo '[2/5] 启动 MySQL...'"
    $scriptLines += "if docker ps | grep -q lumenim-mysql; then"
    $scriptLines += "    echo 'MySQL 已在运行'"
    $scriptLines += "else"
    $scriptLines += "    docker run -d --name lumenim-mysql -e MYSQL_ROOT_PASSWORD=$MySqlPassword -e MYSQL_DATABASE=go_chat -p 3306:3306 -v /var/lib/lumenim/mysql:/var/lib/mysql mysql:8.0 2>/dev/null"
    $scriptLines += "    echo 'MySQL 启动完成'"
    $scriptLines += "fi"
    $scriptLines += ""
    $scriptLines += "echo '[3/5] 启动 Redis...'"
    $scriptLines += "if docker ps | grep -q lumenim-redis; then"
    $scriptLines += "    echo 'Redis 已在运行'"
    $scriptLines += "else"
    $scriptLines += "    docker run -d --name lumenim-redis -p 6379:6379 -v /var/lib/lumenim/redis:/data redis:7.4.1 2>/dev/null"
    $scriptLines += "    echo 'Redis 启动完成'"
    $scriptLines += "fi"
    $scriptLines += ""
    $scriptLines += "echo '[4/5] 创建配置...'"
    $scriptLines += "cat > backend/config.yaml << 'ENDCONFIG'"
    $scriptLines += "app:"
    $scriptLines += "  env: production"
    $scriptLines += "  port: 9501"
    $scriptLines += ""
    $scriptLines += "mysql:"
    $scriptLines += "  host: 127.0.0.1"
    $scriptLines += "  port: 3306"
    $scriptLines += "  username: root"
    $scriptLines += "  password: $MySqlPassword"
    $scriptLines += "  database: go_chat"
    $scriptLines += ""
    $scriptLines += "redis:"
    $scriptLines += "  host: 127.0.0.1"
    $scriptLines += "  port: 6379"
    $scriptLines += "  database: 0"
    $scriptLines += "ENDCONFIG"
    $scriptLines += ""
    $scriptLines += "echo '[5/5] 启动后端服务...'"
    $scriptLines += "cat > /etc/systemd/system/lumenim-backend.service << 'ENDSERVICE'"
    $scriptLines += "[Unit]"
    $scriptLines += "Description=LumenIM Backend"
    $scriptLines += "After=network.target docker.service"
    $scriptLines += ""
    $scriptLines += "[Service]"
    $scriptLines += "Type=simple"
    $scriptLines += "User=root"
    $scriptLines += "WorkingDirectory=$RemoteDeployDir/backend"
    $scriptLines += "ExecStart=$RemoteDeployDir/backend/lumenim"
    $scriptLines += "Restart=on-failure"
    $scriptLines += "RestartSec=5s"
    $scriptLines += "Environment=`"PATH=/usr/local/go/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin`""
    $scriptLines += ""
    $scriptLines += "[Install]"
    $scriptLines += "WantedBy=multi-user.target"
    $scriptLines += "ENDSERVICE"
    $scriptLines += ""
    $scriptLines += "systemctl daemon-reload"
    $scriptLines += "systemctl enable lumenim-backend"
    $scriptLines += "systemctl restart lumenim-backend"
    $scriptLines += ""
    $scriptLines += "echo ''"
    $scriptLines += "echo '=========================================='"
    $scriptLines += "echo '部署完成!'"
    $scriptLines += "echo '=========================================='"
    $scriptLines += "systemctl status lumenim-backend --no-pager"
    $scriptLines += "echo ''"
    $scriptLines += "echo 'Docker 容器:'"
    $scriptLines += "docker ps"

    return ($scriptLines -join "`n")
}

#===============================================================================
# 步骤 1: 环境检查
#===============================================================================
function Step-EnvironmentCheck {
    Write-Info "========== 步骤 1: 环境检查 =========="

    $goCmd = Get-Command go -ErrorAction SilentlyContinue
    if (-not $goCmd) {
        Write-Err "Go 未安装，请先安装: https://go.dev/dl/"
        exit 1
    }
    Write-Info "Go 版本: $((go version) -replace 'go version ', '')"

    $nodeCmd = Get-Command node -ErrorAction SilentlyContinue
    if (-not $nodeCmd) {
        Write-Err "Node.js 未安装，请先安装: https://nodejs.org/"
        exit 1
    }
    Write-Info "Node 版本: $((node --version) -replace 'v', '')"

    if (-not (Test-Path "$ProjectPath\backend") -or -not (Test-Path "$ProjectPath\frontend")) {
        Write-Err "项目目录结构不正确，缺少 backend 或 frontend 文件夹"
        exit 1
    }
    Write-Info "项目目录: $ProjectPath"

    $plinkPath = Get-Command plink.exe -ErrorAction SilentlyContinue
    if (-not $plinkPath) {
        Write-Err "plink.exe 未找到，请安装 PuTTY 并将安装目录添加到 PATH"
        exit 1
    }
    Write-Info "plink.exe: $($plinkPath.Source)"

    $pscpPath = Get-Command pscp.exe -ErrorAction SilentlyContinue
    if (-not $pscpPath) {
        Write-Err "pscp.exe 未找到，请安装 PuTTY 并将安装目录添加到 PATH"
        exit 1
    }
    Write-Info "pscp.exe: $($pscpPath.Source)"

    Write-Info "环境检查通过"
}

#===============================================================================
# 步骤 2: 安装依赖工具
#===============================================================================
function Step-InstallTools {
    Write-Info "========== 步骤 2: 安装依赖工具 =========="

    $pnpmCmd = Get-Command pnpm -ErrorAction SilentlyContinue
    if (-not $pnpmCmd) {
        Write-Info "安装 pnpm..."
        npm install -g pnpm
    }
    Write-Info "pnpm 版本: $(pnpm --version)"
}

#===============================================================================
# 步骤 3: 构建后端
#===============================================================================
function Step-BuildBackend {
    Write-Info "========== 步骤 3: 构建后端 =========="

    $backendDir = "$ProjectPath\backend"
    Push-Location $backendDir

    try {
        Write-Info "下载 Go 依赖..."
        go mod download

        Write-Info "交叉编译后端 (Linux amd64)..."
        $env:CGO_ENABLED = "0"
        $env:GOOS = "linux"
        $env:GOARCH = "amd64"
        $buildResult = go build -ldflags="-s -w" -o lumenim ./cmd/lumenim 2>&1

        if ($LASTEXITCODE -ne 0) {
            Write-Err "后端构建失败: $buildResult"
            exit 1
        }

        if (-not (Test-Path ".\lumenim")) {
            Write-Err "后端构建失败: lumenim 可执行文件未生成"
            exit 1
        }

        Write-Info "后端构建成功"
    }
    finally {
        Pop-Location
    }
}

#===============================================================================
# 步骤 4: 构建前端
#===============================================================================
function Step-BuildFrontend {
    Write-Info "========== 步骤 4: 构建前端 =========="

    $frontendDir = "$ProjectPath\frontend"
    Push-Location $frontendDir

    try {
        Write-Info "安装前端依赖..."
        pnpm install

        Write-Info "构建前端..."
        pnpm build --mode production

        if (-not (Test-Path ".\dist")) {
            Write-Err "前端构建失败: dist 目录未生成"
            exit 1
        }

        Write-Info "前端构建成功"
    }
    finally {
        Pop-Location
    }
}

#===============================================================================
# 步骤 5: 打包文件
#===============================================================================
function Step-Package {
    Write-Info "========== 步骤 5: 打包部署文件 =========="

    New-Item -ItemType Directory -Force -Path $LocalTempDir | Out-Null
    $packageDir = "$LocalTempDir\package"
    New-Item -ItemType Directory -Force -Path $packageDir | Out-Null

    Write-Info "复制后端文件..."
    Copy-Item "$ProjectPath\backend\lumenim" "$packageDir\" -Force
    Copy-Item "$ProjectPath\backend\config.yaml" "$packageDir\" -ErrorAction SilentlyContinue
    Copy-Item "$ProjectPath\backend\sql" "$packageDir\" -Recurse -ErrorAction SilentlyContinue

    Write-Info "复制前端文件..."
    Copy-Item "$ProjectPath\frontend\dist" "$packageDir\" -Recurse -Force

    Push-Location $LocalTempDir
    try {
        Write-Info "创建部署包..."
        tar -czf $PackageName -C package .

        $packagePath = "$LocalTempDir\$PackageName"
        if (Test-Path $packagePath) {
            $fileSize = (Get-Item $packagePath).Length / 1MB
            Write-Info "部署包创建完成: $packagePath (${fileSize:F2} MB)"
        }
        else {
            Write-Err "部署包创建失败"
            exit 1
        }
    }
    finally {
        Pop-Location
    }
}

#===============================================================================
# 步骤 6: 传输文件
#===============================================================================
function Step-Transfer {
    Write-Info "========== 步骤 6: 传输文件到服务器 =========="

    $sshTarget = "${User}@${Host}"

    Write-Info "检查 SSH 连接..."
    $null = echo y | plink -pw $Password $sshTarget "echo ok" 2>$null
    if ($LASTEXITCODE -ne 0) {
        Write-Err "无法连接到服务器 $Host"
        exit 1
    }
    Write-Info "SSH 连接成功"

    Write-Info "创建远程目录..."
    plink -pw $Password $sshTarget "mkdir -p $RemoteDeployDir"

    Write-Info "传输部署包..."
    pscp -pw $Password "$LocalTempDir\$PackageName" "${sshTarget}:/tmp/"

    Write-Info "解压部署包..."
    plink -pw $Password $sshTarget "cd $RemoteDeployDir ; tar -xzf /tmp/$PackageName --overwrite ; chmod +x backend/lumenim"

    Write-Info "文件传输完成"
}

#===============================================================================
# 步骤 7: 远程部署
#===============================================================================
function Step-RemoteDeploy {
    Write-Info "========== 步骤 7: 执行远程部署 =========="

    # 生成远程脚本
    $scriptContent = Get-RemoteDeployScript

    # 写入本地文件
    $scriptPath = Join-Path $LocalTempDir $RemoteScriptName
    $scriptContent | Out-File -FilePath $scriptPath -Encoding UTF8 -NoNewline

    Write-Info "上传远程部署脚本..."
    $sshTarget = "${User}@${Host}"
    pscp -pw $Password $scriptPath "${sshTarget}:/tmp/$RemoteScriptName"

    # 设置脚本执行权限
    Write-Info "设置脚本执行权限..."
    plink -pw $Password $sshTarget "chmod +x /tmp/$RemoteScriptName"

    Write-Info "执行远程部署脚本..."
    plink -batch -pw $Password $sshTarget "bash /tmp/$RemoteScriptName"

    Write-Info "远程部署完成"
}

#===============================================================================
# 步骤 8: 健康检查
#===============================================================================
function Step-HealthCheck {
    Write-Info "========== 步骤 8: 健康检查 =========="

    Start-Sleep -Seconds 5

    $sshTarget = "${User}@${Host}"

    $healthCmd = "echo '' ; echo 'Docker 容器状态:' ; docker ps --format '  {{.Names}}: {{.Status}}' ; echo '' ; echo '后端服务状态:' ; systemctl is-active lumenim-backend ; echo '' ; echo '健康检查:' ; curl -s http://localhost:9501/api/v1/health 2>/dev/null || echo '暂无响应'"
    plink -pw $Password $sshTarget $healthCmd

    Write-Info "=========================================="
    Write-Info "部署完成!"
    Write-Info "=========================================="
    Write-Info "访问地址: http://$Host`:9501"
}

#===============================================================================
# 清理
#===============================================================================
function Cleanup {
    Write-Info "清理临时文件..."
    if (Test-Path $LocalTempDir) {
        Remove-Item -Path $LocalTempDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}

#===============================================================================
# 主函数
#===============================================================================
function Main {
    Write-Host ""
    Write-Host "==============================================" -ForegroundColor Cyan
    Write-Host "  LumenIM 自动化部署脚本 (Windows)" -ForegroundColor Cyan
    Write-Host "  目标服务器: $Host" -ForegroundColor Cyan
    Write-Host "==============================================" -ForegroundColor Cyan
    Write-Host ""

    try {
        Step-EnvironmentCheck
        Step-InstallTools
        Step-BuildBackend
        Step-BuildFrontend
        Step-Package
        Step-Transfer
        Step-RemoteDeploy
        Step-HealthCheck
    }
    catch {
        Write-Err "部署失败: $_"
    }
    finally {
        Cleanup
    }
}

Main
