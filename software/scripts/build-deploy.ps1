# ============================================================================
# LumenIM Local Build and Remote Deploy Script
# Version: 1.2.0
# Date: 2026-04-09
# ============================================================================

[CmdletBinding()]
param(
    [string]$ServerIP = "192.168.23.131",
    [string]$ServerUser = "wenming429",
    [int]$ServerPort = 22,
    [ValidateSet("key", "password")]
    [string]$AuthType = "key",
    [string]$KeyPath = "$env:USERPROFILE\.ssh\id_rsa",
    [string]$Password = "",
    [string]$RemotePath = "/var/www/lumenim",
    [string]$Branch = "main",
    [switch]$BuildOnly,
    [switch]$Upload,
    [switch]$Deploy,
    [switch]$Rollback,
    [switch]$SkipBackup
)

# ============================================================================
# Configuration
# ============================================================================

$ProjectRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$DeployPackageDir = Join-Path $ProjectRoot "deploy-package"
$BackendSrcDir = Join-Path $ProjectRoot "backend"
$FrontendSrcDir = Join-Path $ProjectRoot "front"
$Timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$LogFile = Join-Path $DeployPackageDir "deploy-$Timestamp.log"

# ============================================================================
# Logging Functions
# ============================================================================

function Write-Log {
    param(
        [string]$Message,
        [ValidateSet("INFO", "SUCCESS", "WARN", "ERROR", "STEP")]
        [string]$Level = "INFO"
    )

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Level] $Message"

    if (-not (Test-Path $DeployPackageDir)) {
        New-Item -ItemType Directory -Force -Path $DeployPackageDir | Out-Null
    }

    Add-Content -Path $LogFile -Value $logEntry -Encoding UTF8

    $color = switch ($Level) {
        "INFO"   { "Cyan" }
        "SUCCESS"{ "Green" }
        "WARN"   { "Yellow" }
        "ERROR"  { "Red" }
        "STEP"   { "Blue" }
    }

    if ($VerbosePreference -eq "Continue" -or $Level -in @("ERROR", "WARN", "SUCCESS", "STEP")) {
        Write-Host $logEntry -ForegroundColor $color
    }
}

function Write-Section {
    param([string]$Title)
    $line = "=" * 60
    Write-Log $line -Level "INFO"
    Write-Log "  $Title" -Level "INFO"
    Write-Log $line -Level "INFO"
}

# ============================================================================
# Utility Functions
# ============================================================================

function Test-CommandExists {
    param([string]$Command)
    $null -ne (Get-Command $Command -ErrorAction SilentlyContinue)
}

function Test-PortOpen {
    param([string]$Host, [int]$Port, [int]$Timeout = 5000)
    try {
        $tcp = New-Object System.Net.Sockets.TcpClient
        $result = $tcp.BeginConnect($Host, $Port, $null, $null)
        $wait = $result.AsyncWaitHandle.WaitOne($Timeout, $false)
        $tcp.Close()
        return $wait
    }
    catch {
        return $false
    }
}

function Invoke-SSH {
    param(
        [string]$Host,
        [int]$Port,
        [string]$User,
        [string]$Command
    )

    $sshCmd = "ssh"
    $sshArgs = @(
        "-o", "StrictHostKeyChecking=no",
        "-o", "ConnectTimeout=15",
        "-o", "BatchMode=yes",
        "-p", $Port
    )

    if ($AuthType -eq "key" -and (Test-Path $KeyPath)) {
        $sshArgs += @("-i", $KeyPath)
    }

    $sshArgs += @("$User@$Host", $Command)

    try {
        $process = Start-Process -FilePath $sshCmd -ArgumentList $sshArgs -NoNewWindow -Wait -PassThru -RedirectStandardOutput "$env:TEMP\ssh_stdout_$PID.txt" -RedirectStandardError "$env:TEMP\ssh_stderr_$PID.txt"

        $stdout = if (Test-Path "$env:TEMP\ssh_stdout_$PID.txt") { Get-Content "$env:TEMP\ssh_stdout_$PID.txt" -Raw -Encoding UTF8 }
        $stderr = if (Test-Path "$env:TEMP\ssh_stderr_$PID.txt") { Get-Content "$env:TEMP\ssh_stderr_$PID.txt" -Raw -Encoding UTF8 }

        Remove-Item "$env:TEMP\ssh_stdout_$PID.txt" -Force -EA SilentlyContinue
        Remove-Item "$env:TEMP\ssh_stderr_$PID.txt" -Force -EA SilentlyContinue

        $output = if ($stdout) { $stdout.Trim() } else { $stderr.Trim() }

        return @{
            Success = ($process.ExitCode -eq 0)
            Output = $output
            ExitCode = $process.ExitCode
        }
    }
    catch {
        return @{
            Success = $false
            Output = $_.Exception.Message
            ExitCode = -1
        }
    }
}

function Copy-FileSCP {
    param(
        [string]$LocalFile,
        [string]$RemoteDest,
        [string]$Host,
        [int]$Port,
        [string]$User
    )

    if (-not (Test-Path $LocalFile)) {
        Write-Log "Local file not found: $LocalFile" -Level "ERROR"
        return $false
    }

    $scpCmd = "scp"
    $scpArgs = @(
        "-o", "StrictHostKeyChecking=no",
        "-o", "ConnectTimeout=60",
        "-P", $Port,
        "-r"
    )

    if ($AuthType -eq "key" -and (Test-Path $KeyPath)) {
        $scpArgs += @("-i", $KeyPath)
    }

    $scpArgs += @($LocalFile, "$User@$Host`:$RemoteDest")

    try {
        $process = Start-Process -FilePath $scpCmd -ArgumentList $scpArgs -NoNewWindow -Wait -PassThru
        return ($process.ExitCode -eq 0)
    }
    catch {
        Write-Log "SCP transfer failed: $($_.Exception.Message)" -Level "ERROR"
        return $false
    }
}

# ============================================================================
# Environment Check
# ============================================================================

function Test-BuildEnvironment {
    Write-Section "Build Environment Check"

    $allOk = $true

    if (Test-CommandExists "go") {
        $goVersion = (go version) -replace 'go', ''
        Write-Log "Go: $goVersion" -Level "SUCCESS"
    }
    else {
        Write-Log "Go not found in PATH" -Level "ERROR"
        $allOk = $false
    }

    if (Test-CommandExists "node") {
        $nodeVersion = node -v
        Write-Log "Node.js: $nodeVersion" -Level "SUCCESS"
    }
    else {
        Write-Log "Node.js not found" -Level "ERROR"
        $allOk = $false
    }

    if (Test-CommandExists "pnpm") {
        $pnpmVersion = pnpm -v
        Write-Log "pnpm: $pnpmVersion" -Level "SUCCESS"
    }
    else {
        Write-Log "pnpm not found, installing..." -Level "WARN"
        npm install -g pnpm 2>&1 | Out-Null
        if (Test-CommandExists "pnpm") {
            Write-Log "pnpm installed" -Level "SUCCESS"
        }
        else {
            $allOk = $false
        }
    }

    if (Test-CommandExists "git") {
        $gitVersion = git --version
        Write-Log $gitVersion -Level "SUCCESS"
    }
    else {
        Write-Log "Git not found" -Level "ERROR"
        $allOk = $false
    }

    if (Test-CommandExists "ssh") {
        Write-Log "SSH client: installed" -Level "SUCCESS"
    }
    else {
        Write-Log "SSH client not found" -Level "ERROR"
        $allOk = $false
    }

    if (-not $allOk) {
        Write-Log "Environment check failed" -Level "ERROR"
        return $false
    }

    return $true
}

# ============================================================================
# Build Backend
# ============================================================================

function Build-Backend {
    Write-Section "Build Backend"

    if (-not (Test-Path $BackendSrcDir)) {
        Write-Log "Backend source not found: $BackendSrcDir" -Level "ERROR"
        return $false
    }

    Push-Location $BackendSrcDir

    try {
        Write-Log "Download Go dependencies..." -Level "INFO"
        $env:GOPROXY = "https://goproxy.cn,direct"
        go env -w GOPROXY=$env:GOPROXY | Out-Null

        if (-not (go mod download)) {
            Write-Log "Go dependencies download failed" -Level "ERROR"
            return $false
        }

        Write-Log "Compile backend..." -Level "INFO"
        $env:CGO_ENABLED = "0"
        $env:GOOS = "linux"
        $env:GOARCH = "amd64"

        $buildResult = go build -ldflags="-s -w" -o lumenim ./cmd/lumenim 2>&1

        if ($LASTEXITCODE -eq 0) {
            $exePath = Join-Path $BackendSrcDir "lumenim"
            if (Test-Path $exePath) {
                $size = [math]::Round((Get-Item $exePath).Length / 1MB, 2)
                Write-Log "Backend build success: $size MB" -Level "SUCCESS"
                return $true
            }
        }

        Write-Log "Backend build failed: $buildResult" -Level "ERROR"
        return $false
    }
    catch {
        Write-Log "Build exception: $($_.Exception.Message)" -Level "ERROR"
        return $false
    }
    finally {
        Pop-Location
    }
}

# ============================================================================
# Build Frontend
# ============================================================================

function Build-Frontend {
    Write-Section "Build Frontend"

    if (-not (Test-Path $FrontendSrcDir)) {
        Write-Log "Frontend source not found: $FrontendSrcDir" -Level "ERROR"
        return $false
    }

    Push-Location $FrontendSrcDir

    try {
        # Create environment config
        $envFile = Join-Path $FrontendSrcDir ".env.production"
        $apiUrl = "http://$ServerIP/api"
        $wsUrl = "ws://$ServerIP/ws"

        $envContent = @"
VITE_API_BASE_URL=$apiUrl
VITE_WS_URL=$wsUrl
VITE_APP_NAME=LumenIM
VITE_APP_ENV=production
"@
        $envContent | Out-File -FilePath $envFile -Encoding UTF8

        Write-Log "Frontend env created" -Level "INFO"

        # Install dependencies
        Write-Log "Install frontend dependencies..." -Level "INFO"
        pnpm config set registry https://registry.npmmirror.com 2>&1 | Out-Null

        $installResult = pnpm install 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Log "Frontend dependencies install failed" -Level "ERROR"
            return $false
        }

        # Build
        Write-Log "Build frontend..." -Level "INFO"

        $buildResult = pnpm build 2>&1
        if ($LASTEXITCODE -eq 0) {
            $distPath = Join-Path $FrontendSrcDir "dist"
            if (Test-Path $distPath) {
                $fileCount = (Get-ChildItem $distPath -Recurse -File).Count
                $totalSize = (Get-ChildItem $distPath -Recurse | Measure-Object -Property Length -Sum).Sum
                $size = [math]::Round($totalSize / 1MB, 2)
                Write-Log "Frontend build success: $fileCount files, $size MB" -Level "SUCCESS"
                return $true
            }
        }

        Write-Log "Frontend build failed" -Level "ERROR"
        return $false
    }
    catch {
        Write-Log "Build exception: $($_.Exception.Message)" -Level "ERROR"
        return $false
    }
    finally {
        Pop-Location
    }
}

# ============================================================================
# Package
# ============================================================================

function New-DeploymentPackage {
    Write-Section "Package Deployment Files"

    if (-not (Test-Path $DeployPackageDir)) {
        New-Item -ItemType Directory -Force -Path $DeployPackageDir | Out-Null
    }

    $success = $true

    # Package backend
    $backendTar = Join-Path $DeployPackageDir "lumenim-backend-$Timestamp.tar.gz"
    Write-Log "Package backend..." -Level "INFO"

    if (Test-CommandExists "tar") {
        # Use tar if available (Git Bash)
        Push-Location $ProjectRoot
        $excludeArgs = @(
            "--exclude=.git",
            "--exclude=node_modules",
            "--exclude=vendor",
            "--exclude=*.exe",
            "--exclude=dist",
            "--exclude=build",
            "--exclude=*.log",
            "--exclude=backend/node_modules",
            "--exclude=backend/vendor"
        )
        $cmd = "tar -czf `"$backendTar`" $excludeArgs backend/"
        Invoke-Expression $cmd 2>&1 | Out-Null
        Pop-Location
    }
    else {
        # Fallback to PowerShell Compress-Archive
        $tempZip = $backendTar -replace '\.tar\.gz$', '.zip'
        Compress-Archive -Path "$BackendSrcDir\*" -DestinationPath $tempZip -Force
        if (Test-Path $tempZip) {
            Move-Item $tempZip $backendTar -Force
        }
    }

    if (Test-Path $backendTar) {
        $size = [math]::Round((Get-Item $backendTar).Length / 1MB, 2)
        Write-Log "Backend package: $size MB" -Level "SUCCESS"
        $script:BackendPackage = $backendTar
    }
    else {
        Write-Log "Backend package failed" -Level "ERROR"
        $success = $false
    }

    # Package frontend
    $frontendTar = Join-Path $DeployPackageDir "lumenim-frontend-$Timestamp.tar.gz"
    Write-Log "Package frontend..." -Level "INFO"

    $distPath = Join-Path $FrontendSrcDir "dist"
    if (Test-Path $distPath) {
        if (Test-CommandExists "tar") {
            Push-Location $ProjectRoot
            $cmd = "tar -czf `"$frontendTar`" --exclude=.git front/dist/"
            Invoke-Expression $cmd 2>&1 | Out-Null
            Pop-Location
        }
        else {
            $tempZip = $frontendTar -replace '\.tar\.gz$', '.zip'
            Compress-Archive -Path "$distPath\*" -DestinationPath $tempZip -Force
            if (Test-Path $tempZip) {
                Move-Item $tempZip $frontendTar -Force
            }
        }

        if (Test-Path $frontendTar) {
            $size = [math]::Round((Get-Item $frontendTar).Length / 1MB, 2)
            Write-Log "Frontend package: $size MB" -Level "SUCCESS"
            $script:FrontendPackage = $frontendTar
        }
    }
    else {
        Write-Log "Frontend dist not found" -Level "ERROR"
        $success = $false
    }

    if ($success) {
        Write-Log "Package completed" -Level "SUCCESS"
    }

    return $success
}

# ============================================================================
# Remote Deploy
# ============================================================================

function Test-ServerConnection {
    Write-Section "Test Server Connection"

    Write-Log "Server: $ServerIP`:$ServerPort" -Level "INFO"
    Write-Log "User: $ServerUser" -Level "INFO"
    Write-Log "Auth: $AuthType" -Level "INFO"

    # Check port
    if (-not (Test-PortOpen -Host $ServerIP -Port $ServerPort)) {
        Write-Log "SSH port $ServerPort unreachable" -Level "ERROR"
        return $false
    }

    # Test SSH
    $result = Invoke-SSH -Host $ServerIP -Port $ServerPort -User $ServerUser -Command "echo OK"

    if ($result.Success) {
        Write-Log "Server connection success" -Level "SUCCESS"
        return $true
    }
    else {
        Write-Log "Server connection failed: $($result.Output)" -Level "ERROR"
        return $false
    }
}

function Backup-RemoteServer {
    if ($SkipBackup) {
        Write-Log "Skip backup" -Level "INFO"
        return $true
    }

    Write-Section "Backup Server Data"

    $backupName = "lumenim-backup-$Timestamp"
    $remoteBackupDir = "$RemotePath/../backups"

    # Build backup command for Linux server
    $cmd = @"
mkdir -p $remoteBackupDir
cd $RemotePath
if [ -d backend ]; then
    tar czf $remoteBackupDir/$backupName-backend.tar.gz backend/ 2>/dev/null
fi
if [ -d front/dist ]; then
    tar czf $remoteBackupDir/$backupName-frontend.tar.gz front/dist/ 2>/dev/null
fi
echo "Backup completed"
"@

    $result = Invoke-SSH -Host $ServerIP -Port $ServerPort -User $ServerUser -Command $cmd

    if ($result.Success) {
        Write-Log "Backup completed" -Level "SUCCESS"
    }
    else {
        Write-Log "Backup failed: $($result.Output)" -Level "WARN"
    }

    return $true
}

function Deploy-RemoteServer {
    Write-Section "Deploy to Remote Server"

    # Upload backend
    if ($BackendPackage) {
        Write-Log "Upload backend..." -Level "INFO"
        $remoteFile = "/tmp/lumenim-backend-$Timestamp.tar.gz"

        if (Copy-FileSCP -LocalFile $BackendPackage -RemoteDest $remoteFile -Host $ServerIP -Port $ServerPort -User $ServerUser) {
            Write-Log "Backend upload success" -Level "SUCCESS"
        }
        else {
            Write-Log "Backend upload failed" -Level "ERROR"
            return $false
        }
    }

    # Upload frontend
    if ($FrontendPackage) {
        Write-Log "Upload frontend..." -Level "INFO"
        $remoteFile = "/tmp/lumenim-frontend-$Timestamp.tar.gz"

        if (Copy-FileSCP -LocalFile $FrontendPackage -RemoteDest $remoteFile -Host $ServerIP -Port $ServerPort -User $ServerUser) {
            Write-Log "Frontend upload success" -Level "SUCCESS"
        }
        else {
            Write-Log "Frontend upload failed" -Level "ERROR"
            return $false
        }
    }

    # Execute remote deploy
    Write-Log "Execute remote deploy..." -Level "INFO"

    $deployCmd = @"
cd $RemotePath
systemctl stop lumenim-backend 2>/dev/null || true

if [ -f /tmp/lumenim-backend-$Timestamp.tar.gz ]; then
    rm -rf backend.bak 2>/dev/null || true
    mv backend backend.bak 2>/dev/null || true
    mkdir -p backend
    tar xzf /tmp/lumenim-backend-$Timestamp.tar.gz -C backend/ --strip-components=1
    chmod +x backend/lumenim 2>/dev/null || true
fi

if [ -f /tmp/lumenim-frontend-$Timestamp.tar.gz ]; then
    rm -rf front/dist.bak 2>/dev/null || true
    mv front/dist front/dist.bak 2>/dev/null || true
    mkdir -p front/dist
    tar xzf /tmp/lumenim-frontend-$Timestamp.tar.gz -C front/ --strip-components=1
fi

if [ -f backend/config.example.yaml ]; then
    cp backend/config.example.yaml backend/config.yaml 2>/dev/null || true
fi

chown -R lumenimadmin:lumenimadmin backend/ 2>/dev/null || true
chown -R lumenimadmin:lumenimadmin front/dist/ 2>/dev/null || true

systemctl start lumenim-backend
systemctl status lumenim-backend --no-pager || true

rm -f /tmp/lumenim-*.tar.gz
echo "Deploy completed"
"@

    $result = Invoke-SSH -Host $ServerIP -Port $ServerPort -User $ServerUser -Command $deployCmd

    if ($result.Success) {
        Write-Log "Remote deploy success" -Level "SUCCESS"
        Write-Log "Output: $($result.Output)" -Level "INFO"
    }
    else {
        Write-Log "Remote deploy failed: $($result.Output)" -Level "ERROR"
        return $false
    }

    return $true
}

function Test-RemoteHealth {
    Write-Section "Health Check"

    Start-Sleep -Seconds 3

    # Check API
    try {
        $apiUrl = "http://${ServerIP}:9501/api/v1/health"
        $response = Invoke-WebRequest -Uri $apiUrl -TimeoutSec 10 -UseBasicParsing -ErrorAction SilentlyContinue

        if ($response.StatusCode -eq 200) {
            Write-Log "API health: OK" -Level "SUCCESS"
        }
        else {
            Write-Log "API response: $($response.StatusCode)" -Level "WARN"
        }
    }
    catch {
        Write-Log "API health check failed: $($_.Exception.Message)" -Level "WARN"
    }

    # Check frontend
    try {
        $webUrl = "http://$ServerIP"
        $response = Invoke-WebRequest -Uri $webUrl -TimeoutSec 10 -UseBasicParsing -ErrorAction SilentlyContinue

        if ($response.StatusCode -eq 200) {
            Write-Log "Frontend health: OK" -Level "SUCCESS"
        }
        else {
            Write-Log "Frontend response: $($response.StatusCode)" -Level "WARN"
        }
    }
    catch {
        Write-Log "Frontend health check failed: $($_.Exception.Message)" -Level "WARN"
    }
}

function Invoke-Rollback {
    Write-Section "Rollback to Previous Version"

    $rollbackCmd = @"
backup_dir=\$(dirname $RemotePath)/backups
echo 'Available backups:'
ls -lt \$backup_dir/*.tar.gz 2>/dev/null | head -5

backend_backup=\$(ls -t \$backup_dir/lumenim-backup-*-backend.tar.gz 2>/dev/null | head -1)

if [ -z ""\$backend_backup"" ]; then
    echo 'No backup found'
    exit 1
fi

systemctl stop lumenim-backend 2>/dev/null || true

cd $RemotePath
rm -rf backend 2>/dev/null || true
mkdir -p backend
tar xzf \$backend_backup -C backend/

frontend_backup=\$(ls -t \$backup_dir/lumenim-backup-*-frontend.tar.gz 2>/dev/null | head -1)
if [ -n ""\$frontend_backup"" ]; then
    rm -rf front/dist 2>/dev/null || true
    mkdir -p front/dist
    tar xzf \$frontend_backup -C front/
fi

chown -R lumenimadmin:lumenimadmin backend/ 2>/dev/null || true
chown -R lumenimadmin:lumenimadmin front/dist/ 2>/dev/null || true

systemctl start lumenim-backend
echo 'Rollback completed'
"@

    $result = Invoke-SSH -Host $ServerIP -Port $ServerPort -User $ServerUser -Command $rollbackCmd

    if ($result.Success) {
        Write-Log "Rollback success" -Level "SUCCESS"
    }
    else {
        Write-Log "Rollback failed: $($result.Output)" -Level "ERROR"
        return $false
    }

    return $true
}

# ============================================================================
# Main
# ============================================================================

function Main {
    if (-not (Test-Path $DeployPackageDir)) {
        New-Item -ItemType Directory -Force -Path $DeployPackageDir | Out-Null
    }

    Write-Section "LumenIM Build and Deploy"
    Write-Log "Start: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -Level "INFO"
    Write-Log "Log: $LogFile" -Level "INFO"

    # Rollback mode
    if ($Rollback) {
        if (-not (Test-ServerConnection)) {
            exit 1
        }
        Invoke-Rollback
        exit 0
    }

    # Check environment
    if (-not (Test-BuildEnvironment)) {
        Write-Log "Environment check failed" -Level "ERROR"
        exit 1
    }

    # Build
    $buildSuccess = $true

    if (Test-Path $BackendSrcDir) {
        if (-not (Build-Backend)) {
            $buildSuccess = $false
        }
    }
    else {
        Write-Log "Skip backend (directory not found)" -Level "WARN"
    }

    if (Test-Path $FrontendSrcDir) {
        if (-not (Build-Frontend)) {
            $buildSuccess = $false
        }
    }
    else {
        Write-Log "Skip frontend (directory not found)" -Level "WARN"
    }

    if (-not $buildSuccess) {
        Write-Log "Build failed" -Level "ERROR"
        exit 1
    }

    # Build only mode
    if ($BuildOnly) {
        New-DeploymentPackage
        Write-Log "Package completed" -Level "SUCCESS"
        Write-Log "Package dir: $DeployPackageDir" -Level "INFO"
        exit 0
    }

    # Upload and deploy
    if ($Upload -or $Deploy) {
        if (-not (Test-ServerConnection)) {
            exit 1
        }

        if (-not (New-DeploymentPackage)) {
            Write-Log "Package failed" -Level "ERROR"
            exit 1
        }

        Backup-RemoteServer

        if (Deploy-RemoteServer) {
            Test-RemoteHealth
        }
        else {
            Write-Log "Deploy failed. Use -Rollback to rollback" -Level "ERROR"
            exit 1
        }
    }

    Write-Section "Completed"
    Write-Log "End: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -Level "INFO"
    Write-Log "Log: $LogFile" -Level "SUCCESS"
}

Main
