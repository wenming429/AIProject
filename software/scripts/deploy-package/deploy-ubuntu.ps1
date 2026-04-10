#===============================================================================
# LumenIM Ubuntu Deploy Package Builder (Windows PowerShell)
# Version: 2.0.0
# Target: Ubuntu 20.04 Server (192.168.23.131)
# Usage: .\deploy-ubuntu.ps1 [-RemoteDeploy] [-ServerHost <IP>] [-ServerUser <user>] [-Password <pwd>]
#===============================================================================

# NOTE: param() block MUST be the first non-comment statement in the script

param(
    [switch]$RemoteDeploy,
    [string]$ServerHost = "192.168.23.131",
    [string]$ServerUser = "wenming429",
    [string]$Password = ""
)

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$ErrorActionPreference = "Stop"

#===============================================================================
# Configuration
#===============================================================================

$ScriptVersion = "2.0.0"

# Remote Server Configuration (using renamed variables to avoid PowerShell reserved names)
$DeployConfig = @{
    ServerHost = $ServerHost
    ServerUser = $ServerUser
    Password = $Password
    RemoteDir = "/opt/lumenim"
    BackupDir = "/opt/lumenim-backup"
    
    # Service Ports
    HttpPort = 9501
    WebSocketPort = 9502
    
    # Database Config
    MySQLHost = "127.0.0.1"
    MySQLPort = 3306
    MySQLUser = "root"
    MySQLPassword = "wenming429"
    MySQLDatabase = "go_chat"
    
    # Redis Config
    RedisHost = "127.0.0.1"
    RedisPort = 6379
    RedisPassword = ""
}

# Path Configuration
$ScriptDir = $PSScriptRoot
$ProjectRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $ScriptDir))
$OutputDir = Join-Path $ScriptDir "output"
$TempDir = Join-Path $ScriptDir "temp"

# Directories
$FrontSrc = Join-Path $ProjectRoot "front"
$BackSrc = Join-Path $ProjectRoot "backend"

# Timestamps
$Timestamp = Get-Date -Format "yyyyMMdd-HHmmss"

#===============================================================================
# Helper Functions
#===============================================================================

function Write-Banner {
    param([string]$Text)
    $line = "=" * 60
    Write-Host ""
    Write-Host $line -ForegroundColor Cyan
    Write-Host "  $Text" -ForegroundColor Cyan
    Write-Host $line -ForegroundColor Cyan
    Write-Host ""
}

function Write-Step($num, $total, $text) {
    Write-Host "[Step $num/$total] $text" -ForegroundColor Yellow
}

function Write-Success($text) {
    Write-Host "[OK] $text" -ForegroundColor Green
}

function Write-Error-Msg($text) {
    Write-Host "[ERROR] $text" -ForegroundColor Red
}

function Test-Command($cmd) {
    try {
        Get-Command $cmd -ErrorAction Stop | Out-Null
        return $true
    } catch {
        return $false
    }
}

function Remove-ItemSafe($path) {
    if (Test-Path $path) {
        Remove-Item -Path $path -Recurse -Force -ErrorAction SilentlyContinue
    }
}

function Test-SSHConnection {
    param([string]$ServerHost, [string]$ServerUser, [string]$Password)
    
    Write-Host "Testing SSH connection to $ServerUser@$ServerHost..." -NoNewline
    
    if ($Password -ne "") {
        # Using password
        $test = sshpass -p $Password ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 "$ServerUser@$ServerHost" "echo 'OK'" 2>$null
        if ($test -eq "OK") {
            Write-Success "Connected"
            return $true
        }
    } else {
        # Using SSH key
        $test = ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 "$ServerUser@$ServerHost" "echo 'OK'" 2>$null
        if ($test -eq "OK") {
            Write-Success "Connected"
            return $true
        }
    }
    
    Write-Error-Msg "Connection failed"
    return $false
}

function Invoke-SSHCommand {
    param(
        [string]$ServerHost,
        [string]$ServerUser,
        [string]$Password,
        [string]$Command
    )
    
    if ($Password -ne "") {
        sshpass -p $Password ssh -o StrictHostKeyChecking=no "$ServerUser@$ServerHost" $Command 2>$null
    } else {
        ssh -o StrictHostKeyChecking=no "$ServerUser@$ServerHost" $Command 2>$null
    }
}

function Copy-FileRemote {
    param(
        [string]$ServerHost,
        [string]$ServerUser,
        [string]$Password,
        [string]$LocalFile,
        [string]$RemotePath
    )
    
    if ($Password -ne "") {
        sshpass -p $Password scp -o StrictHostKeyChecking=no $LocalFile "$ServerUser@$ServerHost`:$RemotePath" 2>$null
    } else {
        scp -o StrictHostKeyChecking=no $LocalFile "$ServerUser@$ServerHost`:$RemotePath" 2>$null
    }
}

function Copy-DirRemote {
    param(
        [string]$ServerHost,
        [string]$ServerUser,
        [string]$Password,
        [string]$LocalDir,
        [string]$RemotePath
    )
    
    if ($Password -ne "") {
        sshpass -p $Password scp -r -o StrictHostKeyChecking=no $LocalDir "$ServerUser@$ServerHost`:$RemotePath" 2>$null
    } else {
        scp -r -o StrictHostKeyChecking=no $LocalDir "$ServerUser@$ServerHost`:$RemotePath" 2>$null
    }
}

#===============================================================================
# Main Script
#===============================================================================

Write-Banner "LumenIM Ubuntu Deploy Package Builder v$ScriptVersion"
Write-Host "Project Root: $ProjectRoot"
Write-Host "Output Dir:   $OutputDir"
Write-Host "Timestamp:    $Timestamp"

if ($RemoteDeploy) {
    Write-Host "Remote Host:  $($DeployConfig.ServerHost)"
    Write-Host "Remote User:  $($DeployConfig.ServerUser)"
    Write-Host "Remote Dir:   $($DeployConfig.RemoteDir)"
}

Write-Host ""

#===============================================================================
# Step 1: Check Dependencies
#===============================================================================

Write-Step 1 5 "Checking dependencies..."
Write-Host ""

$deps = @{
    "go"   = @{ Cmd = "go";   Args = @("version") }
    "node" = @{ Cmd = "node"; Args = @("--version") }
    "pnpm" = @{ Cmd = "pnpm"; Args = @("--version") }
}

$allOk = $true
foreach ($dep in $deps.Keys) {
    $cmd = $deps[$dep].Cmd
    $args = $deps[$dep].Args
    if (Test-Command $cmd) {
        try {
            $version = & $cmd $args 2>$null | Select-Object -First 1
            Write-Success "$cmd : $version"
        } catch {
            Write-Error-Msg "$cmd check failed"
            $allOk = $false
        }
    } else {
        Write-Error-Msg "$cmd not found - Please install $cmd"
        $allOk = $false
    }
}

# Check tar
if (Test-Command "tar") {
    Write-Success "tar : installed"
} elseif (Test-Command "git") {
    Write-Host "[INFO] tar not found, will use Git Bash tar" -ForegroundColor Cyan
}

# Check sshpass for password auth
if ($DeployConfig.Password -ne "" -and -not (Test-Command "sshpass")) {
    Write-Error-Msg "sshpass not found - Required for password authentication"
    Write-Host "Install: choco install sshpass OR download from http://sourceforge.net/projects/sshpass/" -ForegroundColor Yellow
    $allOk = $false
}

if (-not $allOk) {
    Write-Host ""
    Write-Error-Msg "Missing dependencies. Please install them first."
    exit 1
}

Write-Host ""

#===============================================================================
# Step 2: Build Frontend
#===============================================================================

Write-Step 2 5 "Building frontend..."
Write-Host ""

# Verify frontend source directory
if (-not (Test-Path $FrontSrc)) {
    Write-Error-Msg "Frontend source not found: $FrontSrc"
    Write-Host "Expected path: $FrontSrc" -ForegroundColor Yellow
    exit 1
}

Write-Success "Frontend source verified: $FrontSrc"

Push-Location $FrontSrc

Write-Host "[INFO] Installing frontend dependencies..." -ForegroundColor Cyan
# NOTE: Do NOT use --production flag, Vite is a dev dependency needed for build
pnpm install

Write-Host "[INFO] Running production build..." -ForegroundColor Cyan
Write-Host "[INFO] Build source: $FrontSrc" -ForegroundColor Cyan
# Use pnpm to run vite build directly
pnpm run build

$FrontDist = Join-Path $TempDir "deploy\front\dist"
New-Item -ItemType Directory -Path $FrontDist -Force | Out-Null

if (Test-Path "dist") {
    $distCount = (Get-ChildItem "dist" -Recurse -File).Count
    $distSize = "{0:N2}" -f ((Get-ChildItem "dist" -Recurse | Measure-Object -Property Length -Sum).Sum / 1MB)
    Copy-Item -Path "dist\*" -Destination $FrontDist -Recurse -Force
    Write-Success "Frontend build completed - Files: $distCount, Size: $distSize MB"
} else {
    Pop-Location
    Write-Error-Msg "Frontend build failed - dist directory not found"
    exit 1
}

# Copy frontend source files for reference
Write-Host "[INFO] Copying frontend source reference..." -ForegroundColor Cyan
$FrontSrcCopy = Join-Path $TempDir "deploy\front\src"
New-Item -ItemType Directory -Path $FrontSrcCopy -Force | Out-Null

# Copy key frontend files
$frontSrcDirs = @("src", "public", "script")
foreach ($dir in $frontSrcDirs) {
    $srcDir = Join-Path $FrontSrc $dir
    if (Test-Path $srcDir) {
        Copy-Item -Path $srcDir -Destination (Join-Path (Join-Path $TempDir "deploy\front") $dir) -Recurse -Force
    }
}

# Copy essential config files
$configFiles = @("package.json", "vite.config.ts", "tsconfig.json", ".env", ".env.production", "index.html")
foreach ($file in $configFiles) {
    $srcFile = Join-Path $FrontSrc $file
    $destFile = Join-Path (Join-Path $TempDir "deploy\front") $file
    if (Test-Path $srcFile) {
        Copy-Item -Path $srcFile -Destination $destFile -Force
    }
}

Pop-Location
Write-Host ""

#===============================================================================
# Step 3: Build Backend
#===============================================================================

Write-Step 3 5 "Building backend..."
Write-Host ""

# Verify source directories
$requiredDirs = @(
    $BackSrc,
    (Join-Path $BackSrc "cmd"),
    (Join-Path $BackSrc "cmd\lumenim"),
    (Join-Path $BackSrc "api"),
    (Join-Path $BackSrc "internal"),
    (Join-Path $BackSrc "go.mod")
)

foreach ($dir in $requiredDirs) {
    if (-not (Test-Path $dir)) {
        Write-Error-Msg "Required path not found: $dir"
        exit 1
    }
}

Write-Success "Backend source verified"

Push-Location $BackSrc

# Set cross-compile environment
$env:CGO_ENABLED = "0"
$env:GOOS = "linux"
$env:GOARCH = "amd64"
$env:GOPROXY = "https://goproxy.cn,direct"

Write-Host "[INFO] Compiling backend for Linux amd64..." -ForegroundColor Cyan
Write-Host "[INFO] Build source: $BackSrc" -ForegroundColor Cyan

# Build from the correct path
$buildPath = "./cmd/lumenim"
Write-Host "[INFO] Building from: $buildPath" -ForegroundColor Cyan

go build -ldflags="-s -w -X main.Version=${ScriptVersion}" -o lumenim $buildPath

if (-not (Test-Path "lumenim")) {
    Pop-Location
    Write-Error-Msg "Backend build failed - executable not generated"
    exit 1
}

$exeSize = "{0:N2}" -f ((Get-Item "lumenim").Length / 1MB)
Write-Success "Backend build completed (Linux amd64) - Size: $exeSize MB"

# Create directory structure for deployment
$BackDir = Join-Path $TempDir "deploy\backend"
$backDirs = @(
    $BackDir,
    "$BackDir\sql",
    "$BackDir\uploads\images",
    "$BackDir\uploads\files",
    "$BackDir\uploads\avatars",
    "$BackDir\uploads\audio",
    "$BackDir\uploads\video",
    "$BackDir\runtime\logs",
    "$BackDir\runtime\cache",
    "$BackDir\runtime\temp",
    "$BackDir\config",
    "$BackDir\api",
    "$BackDir\internal",
    "$BackDir\data"
)

foreach ($dir in $backDirs) {
    New-Item -ItemType Directory -Path $dir -Force | Out-Null
}

# Copy executable
Copy-Item -Path "lumenim" -Destination $BackDir -Force

# Copy essential backend source files for reference and potential rebuild
Write-Host "[INFO] Copying backend source files..." -ForegroundColor Cyan

# Copy api directory (protobuf definitions)
$apiSrc = Join-Path $BackSrc "api"
if (Test-Path $apiSrc) {
    Copy-Item -Path $apiSrc -Destination "$BackDir\api" -Recurse -Force
    Write-Success "Copied: api/"
}

# Copy internal directory (core business logic)
$internalSrc = Join-Path $BackSrc "internal"
if (Test-Path $internalSrc) {
    Copy-Item -Path $internalSrc -Destination "$BackDir\internal" -Recurse -Force
    Write-Success "Copied: internal/"
}

# Copy config directory (core config logic)
$configSrc = Join-Path $BackSrc "config"
if (Test-Path $configSrc) {
    Copy-Item -Path $configSrc -Destination "$BackDir\config_core" -Recurse -Force
    Write-Success "Copied: config/ -> config_core/"
}

# Copy cmd directory (entry point)
$cmdSrc = Join-Path $BackSrc "cmd"
if (Test-Path $cmdSrc) {
    Copy-Item -Path $cmdSrc -Destination "$BackDir\cmd" -Recurse -Force
    Write-Success "Copied: cmd/"
}

# Copy data directory (initial data)
$dataSrc = Join-Path $BackSrc "data"
if (Test-Path $dataSrc) {
    Copy-Item -Path $dataSrc -Destination "$BackDir\data" -Recurse -Force
    Write-Success "Copied: data/"
}

# Copy third_party directory (dependencies)
$thirdPartySrc = Join-Path $BackSrc "third_party"
if (Test-Path $thirdPartySrc) {
    Copy-Item -Path $thirdPartySrc -Destination "$BackDir\third_party" -Recurse -Force
    Write-Success "Copied: third_party/"
}

# Copy Go module files
Copy-Item -Path "go.mod" -Destination $BackDir -Force
Copy-Item -Path "go.sum" -Destination $BackDir -Force -ErrorAction SilentlyContinue

# Copy Makefile for rebuild reference
Copy-Item -Path "Makefile" -Destination $BackDir -Force -ErrorAction SilentlyContinue

# Copy config.yaml example
$configExampleSrc = Join-Path $BackSrc "config.example.yaml"
if (Test-Path $configExampleSrc) {
    Copy-Item -Path $configExampleSrc -Destination "$BackDir\config\" -Force
}

# Copy SQL files from multiple possible locations
$sqlFound = $false
$sqlLocations = @(
    (Join-Path $BackSrc "sql"),
    (Join-Path $BackSrc "data\sql"),
    (Join-Path $BackSrc "internal\mission")
)

foreach ($sqlDir in $sqlLocations) {
    if (Test-Path $sqlDir) {
        $sqlFiles = Get-ChildItem -Path $sqlDir -Filter "*.sql" -ErrorAction SilentlyContinue
        foreach ($sql in $sqlFiles) {
            Copy-Item -Path $sql.FullName -Destination "$BackDir\sql\" -Force
            Write-Success "Copied SQL: $($sql.Name)"
            $sqlFound = $true
        }
    }
}

if (-not $sqlFound) {
    Write-Host "[WARN] No SQL files found in expected locations" -ForegroundColor Yellow
}

Pop-Location
Write-Host ""

#===============================================================================
# Step 4: Create Configuration Files
#===============================================================================

Write-Step 4 5 "Creating configuration files..."
Write-Host ""

$FrontConfig = Join-Path $TempDir "deploy\front\config"
$BackConfig = Join-Path $TempDir "deploy\backend\config"
$ScriptsDir = Join-Path $TempDir "deploy\scripts"
$DeployDir = Join-Path $TempDir "deploy"
$NginxDir = Join-Path $TempDir "deploy\nginx"

New-Item -ItemType Directory -Path $FrontConfig -Force | Out-Null
New-Item -ItemType Directory -Path $BackConfig -Force | Out-Null
New-Item -ItemType Directory -Path $ScriptsDir -Force | Out-Null
New-Item -ItemType Directory -Path $NginxDir -Force | Out-Null

Write-Success "Configuration directories created"

# Frontend - nginx.conf
@"
# Frontend Nginx Configuration
server {
    listen 80;
    server_name _;

    root /var/www/lumenim;
    index index.html;

    # Frontend Routes (SPA)
    location / {
        try_files `$uri `$uri/ /index.html;
    }

    # API Proxy
    location /api {
        proxy_pass http://127.0.0.1:$($DeployConfig.HttpPort);
        proxy_http_version 1.1;
        proxy_set_header Host `$host;
        proxy_set_header X-Real-IP `$remote_addr;
        proxy_set_header X-Forwarded-For `$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto `$scheme;
    }

    # WebSocket Proxy
    location /ws {
        proxy_pass http://127.0.0.1:$($DeployConfig.WebSocketPort);
        proxy_http_version 1.1;
        proxy_set_header Upgrade `$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host `$host;
        proxy_set_header X-Real-IP `$remote_addr;
    }

    # Static Resources Cache
    location ~* \.(gif|jpg|jpeg|png|bmp|swf|flv|ico)$ {
        expires 7d;
        access_log off;
        add_header Cache-Control "public, immutable";
    }

    location ~* \.(js|css|less|scss|sass)$ {
        expires 7d;
        access_log off;
        add_header Cache-Control "public, immutable";
    }

    location ~* \.(woff|woff2|ttf|eot|svg|otf)$ {
        expires 30d;
        access_log off;
        add_header Cache-Control "public";
    }

    # Health Check
    location /health {
        access_log off;
        return 200 "OK";
        add_header Content-Type text/plain;
    }
}
"@ | Out-File -FilePath "$FrontConfig\nginx.conf" -Encoding UTF8

# Backend - config.yaml
$configYaml = @"
# ==================== Application Config ====================
app:
  env: prod
  debug: false
  admin_email:
    - admin@example.com
  public_key: |
    -----BEGIN PUBLIC KEY-----
    YOUR_PUBLIC_KEY_HERE
    -----END PUBLIC KEY-----
  private_key: |
    -----BEGIN PRIVATE KEY-----
    YOUR_PRIVATE_KEY_HERE
    -----END PRIVATE KEY-----
  aes_key: "32-char-random-string-for-aes-encryption"

# ==================== Server Ports ====================
server:
  http_addr: ":$($DeployConfig.HttpPort)"
  websocket_addr: ":$($DeployConfig.WebSocketPort)"
  tcp_addr: ":9505"

# ==================== Log Config ====================
log:
  path: "./runtime/logs"
  level: "info"
  max_size: 100
  max_backups: 30
  max_age: 7

# ==================== Redis Config ====================
redis:
  host: $($DeployConfig.RedisHost)
  port: $($DeployConfig.RedisPort)
  auth: "$($DeployConfig.RedisPassword)"
  database: 0
  pool_size: 100

# ==================== MySQL Config ====================
mysql:
  host: $($DeployConfig.MySQLHost)
  port: $($DeployConfig.MySQLPort)
  username: $($DeployConfig.MySQLUser)
  password: "$($DeployConfig.MySQLPassword)"
  database: $($DeployConfig.MySQLDatabase)
  charset: utf8mb4
  max_open_conns: 100
  max_idle_conns: 10

# ==================== JWT Config ====================
jwt:
  secret: "your_jwt_secret_key_32chars"
  expires_time: 86400
  buffer_time: 86400

# ==================== CORS Config ====================
cors:
  origin: "*"
  headers: "Content-Type,Cache-Control,User-Agent,AccessToken,Authorization"
  methods: "OPTIONS,GET,POST,PUT,DELETE"
  credentials: true
  max_age: 600

# ==================== File Storage Config ====================
filesystem:
  default: local
  local:
    root: "./uploads"
    bucket_public: "public"
    bucket_private: "private"
  minio:
    secret_id: "minioadmin"
    secret_key: "your_minio_password"
    bucket_public: "im-static"
    bucket_private: "im-private"
    endpoint: "127.0.0.1:9000"
    ssl: false

# ==================== Email Config (Optional) ====================
email:
  host: smtp.ym.163.com
  port: 465
  username: noreply@yourcompany.com
  password: "smtp_password"
  fromname: "LumenIM"
"@ | Out-File -FilePath "$BackConfig\config.yaml" -Encoding UTF8

# Systemd Service Files
$serviceContent = @"
[Unit]
Description=LumenIM HTTP Service
After=network.target mysql.service redis.service

[Service]
Type=simple
User=lumenim
Group=lumenim
WorkingDirectory=$($DeployConfig.RemoteDir)/backend
ExecStart=$($DeployConfig.RemoteDir)/backend/lumenim http --config=$($DeployConfig.RemoteDir)/backend/config/config.yaml
Restart=always
RestartSec=5
StandardOutput=journal
StandardError=journal
SyslogIdentifier=lumenim-http
NoNewPrivileges=true
ProtectSystem=strict
ReadWritePaths=$($DeployConfig.RemoteDir)/backend/runtime,$($DeployConfig.RemoteDir)/backend/uploads

[Install]
WantedBy=multi-user.target
"@

$serviceContent -replace "Description=LumenIM HTTP Service", "Description=LumenIM HTTP Service" | 
    Out-File -FilePath "$BackConfig\lumenim-http.service" -Encoding ASCII

$serviceContent -replace "Description=LumenIM HTTP Service", "Description=LumenIM WebSocket Service" -replace "lumenim-http", "lumenim-comet" -replace "SyslogIdentifier=lumenim-http", "SyslogIdentifier=lumenim-comet" |
    Out-File -FilePath "$BackConfig\lumenim-comet.service" -Encoding ASCII

$serviceContent -replace "Description=LumenIM HTTP Service", "Description=LumenIM Queue Service" -replace "lumenim-http", "lumenim-queue" -replace "SyslogIdentifier=lumenim-http", "SyslogIdentifier=lumenim-queue" |
    Out-File -FilePath "$BackConfig\lumenim-queue.service" -Encoding ASCII

$serviceContent -replace "Description=LumenIM HTTP Service", "Description=LumenIM Crontab Service" -replace "lumenim-http", "lumenim-crontab" -replace "SyslogIdentifier=lumenim-http", "SyslogIdentifier=lumenim-crontab" |
    Out-File -FilePath "$BackConfig\lumenim-crontab.service" -Encoding ASCII

# Start/Stop Scripts
@"
#!/bin/bash
cd "$(Split-Path -Parent $BackConfig)"
./lumenim http --config=config.yaml &
./lumenim comet --config=config.yaml &
./lumenim queue --config=config.yaml &
./lumenim crontab --config=config.yaml &
echo "All services started!"
"@ | Out-File -FilePath "$BackConfig\start.sh" -Encoding ASCII

@"
#!/bin/bash
pkill -f lumenim || true
echo "All services stopped!"
"@ | Out-File -FilePath "$BackConfig\stop.sh" -Encoding ASCII

# Deploy Script
$deployScript = @"
#!/bin/bash
set -e

DEPLOY_DIR="`$(cd "`$(dirname "`\${BASH_SOURCE[0]}")`" && pwd)"
NGINX_WEB_ROOT="/var/www/lumenim"
APP_DIR="$($DeployConfig.RemoteDir)"

echo "==========================================="
echo "  LumenIM Ubuntu Deployment Script"
echo "==========================================="

if [ "`$EUID" -ne 0 ]; then
    echo "Please run as root: sudo bash deploy.sh"
    exit 1
fi

# Backup existing deployment
if [ -d "`$APP_DIR" ]; then
    echo "[Backup] Backing up existing deployment..."
    mv "`$APP_DIR" "`$APP_DIR-backup-`$(date +%Y%m%d-%H%M%S)"
fi

# Create user
id lumenim &>/dev/null || useradd -r -s /bin/bash lumenim

# Deploy Backend
echo "[1/5] Deploying backend..."
mkdir -p "`$APP_DIR/backend"
cp -r backend/* "`$APP_DIR/backend/"
mkdir -p "`$APP_DIR/backend/uploads/images"
mkdir -p "`$APP_DIR/backend/uploads/files"
mkdir -p "`$APP_DIR/backend/uploads/avatars"
mkdir -p "`$APP_DIR/backend/uploads/audio"
mkdir -p "`$APP_DIR/backend/uploads/video"
mkdir -p "`$APP_DIR/backend/runtime/logs"
mkdir -p "`$APP_DIR/backend/runtime/cache"
mkdir -p "`$APP_DIR/backend/runtime/temp"
chmod +x "`$APP_DIR/backend/lumenim"

# Install Systemd Services
echo "[2/5] Installing systemd services..."
cp "`$APP_DIR/backend/config/lumenim-http.service" /etc/systemd/system/
cp "`$APP_DIR/backend/config/lumenim-comet.service" /etc/systemd/system/
cp "`$APP_DIR/backend/config/lumenim-queue.service" /etc/systemd/system/
cp "`$APP_DIR/backend/config/lumenim-crontab.service" /etc/systemd/system/
systemctl daemon-reload

# Deploy Frontend
echo "[3/5] Deploying frontend..."
mkdir -p "`$NGINX_WEB_ROOT"
cp -r front/dist/* "`$NGINX_WEB_ROOT/"
chown -R www-data:www-data "`$NGINX_WEB_ROOT"

# Configure Nginx
echo "[4/5] Configuring Nginx..."
cp front/config/nginx.conf /etc/nginx/sites-available/lumenim
ln -sf /etc/nginx/sites-available/lumenim /etc/nginx/sites-enabled/lumenim
rm -f /etc/nginx/sites-enabled/default
nginx -t && nginx -s reload

# Set permissions
echo "[5/5] Setting permissions..."
chown -R lumenim:lumenim "`$APP_DIR/backend"
chmod -R 755 "`$APP_DIR/backend"

echo ""
echo "==========================================="
echo "  Deployment Complete!"
echo "==========================================="
echo ""
echo "Next steps:"
echo "  1. Edit config: vim `($APP_DIR)/backend/config/config.yaml"
echo "  2. Import DB: mysql -u root -p < `($APP_DIR)/backend/sql/lumenim.sql"
echo "  3. Start: systemctl start lumenim-http lumenim-comet"
echo "  4. Check: systemctl status lumenim-http"
echo "  5. View logs: journalctl -u lumenim-http -f"
echo ""
"@ | Out-File -FilePath "$DeployDir\deploy.sh" -Encoding ASCII

# Init DB Script
@"
#!/bin/bash
# Database Initialization Script

MYSQL_HOST="$($DeployConfig.MySQLHost)"
MYSQL_PORT="$($DeployConfig.MySQLPort)"
MYSQL_USER="$($DeployConfig.MySQLUser)"
MYSQL_PASS="$($DeployConfig.MySQLPassword)"
MYSQL_DB="$($DeployConfig.MySQLDatabase)"

echo "Initializing database..."
mysql -h `"$MYSQL_HOST`" -P `"$MYSQL_PORT`" -u `"$MYSQL_USER`" -p`"$MYSQL_PASS`" -e "CREATE DATABASE IF NOT EXISTS `"$MYSQL_DB`" CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
mysql -h `"$MYSQL_HOST`" -P `"$MYSQL_PORT`" -u `"$MYSQL_USER`" -p`"$MYSQL_PASS`" `"$MYSQL_DB`" < backend/sql/lumenim.sql
echo "Database initialized successfully!"
"@ | Out-File -FilePath "$ScriptsDir\init-db.sh" -Encoding ASCII

# README
$readmeContent = @"
# LumenIM Deployment Package

## Package Contents

This package contains both backend and frontend for LumenIM.

### Backend Structure
```
backend/
├── lumenim              # Linux executable (main service)
├── api/                 # API definitions (protobuf)
├── internal/            # Core business logic
├── cmd/                  # Entry points
├── sql/                  # Database scripts
├── config_core/          # Core configuration logic
├── data/                 # Initial data
├── go.mod               # Go module definition
├── go.sum               # Go dependencies checksum
├── Makefile             # Build reference
├── config.yaml          # Configuration template
└── runtime/             # Runtime directory (logs, cache, temp)
    ├── logs/
    ├── cache/
    └── temp/
```

### Frontend Structure
```
front/
├── dist/                # Built frontend (production)
├── src/                 # Source code reference
├── public/              # Public assets
├── script/              # Build scripts
└── config/              # Configuration files
    └── nginx.conf       # Nginx configuration
```

## Quick Start

1. Upload to server: scp lumenim-ubuntu-TIMESTAMP.tar.gz user@server:/opt/
2. SSH to server
3. Extract: tar -xzvf lumenim-ubuntu-TIMESTAMP.tar.gz
4. Deploy: cd lumenim-ubuntu && sudo bash deploy.sh
5. Configure: vim /opt/lumenim/backend/config/config.yaml
6. Import DB: mysql -u root -p < /opt/lumenim/backend/sql/lumenim.sql
7. Start: systemctl start lumenim-http lumenim-comet

## Service Ports

| Service | Port | Description |
|---------|------|-------------|
| HTTP API | $($DeployConfig.HttpPort) | RESTful API |
| WebSocket | $($DeployConfig.WebSocketPort) | Real-time messaging |
| Nginx | 80 | Web frontend |

## Config Files

- Backend: /opt/lumenim/backend/config/config.yaml
- Nginx: /etc/nginx/sites-available/lumenim

## Service Management

```bash
# Start services
systemctl start lumenim-http lumenim-comet lumenim-queue lumenim-crontab

# Stop services
systemctl stop lumenim-http lumenim-comet lumenim-queue lumenim-crontab

# Check status
systemctl status lumenim-http

# View logs
journalctl -u lumenim-http -f
```

## Update Deployment

1. Stop services: systemctl stop lumenim-http lumenim-comet
2. Backup: mv /opt/lumenim /opt/lumenim-backup-`date +%Y%m%d`
3. Deploy new: tar -xzvf new-package.tar.gz && cd lumenim-ubuntu && sudo bash deploy.sh
4. Start: systemctl start lumenim-http lumenim-comet

## Build from Source (Optional)

If you need to rebuild the backend on the server:

```bash
cd /opt/lumenim/backend
# Install Go 1.21+ first if not installed
CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -o lumenim ./cmd/lumenim
```
"@ | Out-File -FilePath "$DeployDir\README.md" -Encoding UTF8

Write-Success "Configuration files created"
Write-Host ""

#===============================================================================
# Step 5: Create Package
#===============================================================================

Write-Step 5 5 "Creating deploy package..."
Write-Host ""

# Package name
$PackageName = "lumenim-ubuntu-$Timestamp.tar.gz"
$PackagePath = Join-Path $OutputDir $PackageName

Write-Host "[DEBUG] ===== Packaging Debug Info =====" -ForegroundColor DarkGray
Write-Host "[DEBUG] ScriptDir:  $ScriptDir" -ForegroundColor DarkGray
Write-Host "[DEBUG] TempDir:    $TempDir" -ForegroundColor DarkGray
Write-Host "[DEBUG] OutputDir:  $OutputDir" -ForegroundColor DarkGray
Write-Host "[DEBUG] DeployDir:  $DeployDir" -ForegroundColor DarkGray
Write-Host "[DEBUG] PackagePath: $PackagePath" -ForegroundColor DarkGray

# Create output directory FIRST and verify
Write-Host "[INFO] Creating output directory..." -ForegroundColor Cyan
try {
    if (-not (Test-Path $OutputDir)) {
        New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
        Write-Success "Created output directory: $OutputDir"
    } else {
        Write-Success "Output directory exists: $OutputDir"
    }
} catch {
    Write-Error-Msg "Failed to create output directory: $_"
    exit 1
}

# Create scripts directory
New-Item -ItemType Directory -Path "$DeployDir\scripts" -Force | Out-Null

# Verify deployment directory contents before packaging
Write-Host "[INFO] Verifying deployment package contents..." -ForegroundColor Cyan

$verifyItems = @(
    (Join-Path $DeployDir "backend\lumenim"),
    (Join-Path $DeployDir "backend\api"),
    (Join-Path $DeployDir "backend\internal"),
    (Join-Path $DeployDir "front\dist")
)

$allVerified = $true
foreach ($item in $verifyItems) {
    if (Test-Path $item) {
        $itemSize = (Get-Item $item -ErrorAction SilentlyContinue).Length
        if ($itemSize) {
            Write-Success "Verified: $(Split-Path $item -Leaf) ($([math]::Round($itemSize/1MB, 2)) MB)"
        } else {
            Write-Success "Verified: $(Split-Path $item -Leaf)"
        }
    } else {
        Write-Error-Msg "Missing: $item"
        $allVerified = $false
    }
}

if (-not $allVerified) {
    Write-Error-Msg "Deployment package verification failed"
    exit 1
}

# Create ZIP package using PowerShell native compression
# Note: Using ZIP instead of tar.gz to avoid encoding issues with Chinese paths in tar
Write-Host "[INFO] Using PowerShell native compression..." -ForegroundColor Cyan

# Create output directory
if (-not (Test-Path $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
    Write-Host "[DEBUG] Created output directory: $OutputDir" -ForegroundColor DarkGray
}

# Verify paths
if (-not (Test-Path $DeployDir)) {
    Write-Error-Msg "Deploy source directory does not exist: $DeployDir"
    exit 1
}

# Output ZIP path (compatible format)
$zipPath = $PackagePath -replace '\.tar\.gz$', '.zip'
Write-Host "[DEBUG] Source: $DeployDir" -ForegroundColor DarkGray
Write-Host "[DEBUG] Output: $zipPath" -ForegroundColor DarkGray

# Remove existing file if present
if (Test-Path $zipPath) {
    Remove-Item $zipPath -Force
}

try {
    # Load .NET compression assembly
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    
    # Use .NET ZipFile.CreateFromDirectory for reliable compression
    [System.IO.Compression.ZipFile]::CreateFromDirectory($DeployDir, $zipPath)
    $PackagePath = $zipPath
    
    Write-Host "[DEBUG] ZIP package created successfully" -ForegroundColor DarkGray
} catch {
    # Fallback to Compress-Archive cmdlet
    Write-Host "[DEBUG] Falling back to Compress-Archive..." -ForegroundColor DarkGray
    Compress-Archive -Path "$DeployDir\*" -DestinationPath $zipPath -Force
    $PackagePath = $zipPath
}

# Verify package was created
if (Test-Path $PackagePath) {
    $pkgSize = (Get-Item $PackagePath).Length / 1MB
    Write-Success "Package created: $PackagePath ($([math]::Round($pkgSize, 2)) MB)"
    Write-Host "[NOTE] Using ZIP format for cross-platform compatibility" -ForegroundColor Yellow
} else {
    Write-Error-Msg "Failed to create package"
    exit 1
}

# Get file size
if (Test-Path $PackagePath) {
    $size = (Get-Item $PackagePath).Length / 1MB
    $sizeStr = "{0:N2}" -f $size
    
    Write-Host ""
    Write-Banner "Package Build Complete!"
    Write-Host "Package Location: $PackagePath" -ForegroundColor Yellow
    Write-Host "Package Size:     $sizeStr MB" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Package Contents:" -ForegroundColor Cyan
    Write-Host "  |-- backend/" -ForegroundColor White
    Write-Host "  |     |-- lumenim          # Linux executable" -ForegroundColor White
    Write-Host "  |     |-- api/             # API definitions" -ForegroundColor White
    Write-Host "  |     |-- internal/        # Core business logic" -ForegroundColor White
    Write-Host "  |     |-- cmd/             # Entry points" -ForegroundColor White
    Write-Host "  |     |-- sql/             # Database scripts" -ForegroundColor White
    Write-Host "  |     |-- go.mod           # Go module" -ForegroundColor White
    Write-Host "  |     |-- config.yaml      # Config template" -ForegroundColor White
    Write-Host "  |     +-- runtime/         # Runtime directory" -ForegroundColor White
    Write-Host "  |" -ForegroundColor White
    Write-Host "  |-- front/" -ForegroundColor White
    Write-Host "  |     |-- dist/            # Built frontend" -ForegroundColor White
    Write-Host "  |     +-- config/          # Nginx config" -ForegroundColor White
    Write-Host "  |" -ForegroundColor White
    Write-Host "  +-- deploy.sh             # Deployment script" -ForegroundColor White
    Write-Host ""
} else {
    Write-Error-Msg "Package creation failed"
    exit 1
}

# Cleanup temp
Remove-ItemSafe $TempDir

#===============================================================================
# Step 6: Remote Deploy (Optional)
#===============================================================================

if ($RemoteDeploy) {
    Write-Host ""
    Write-Banner "Remote Deployment"
    Write-Host ""
    
    # Test SSH connection
    if (-not (Test-SSHConnection $DeployConfig.ServerHost $DeployConfig.ServerUser $DeployConfig.Password)) {
        Write-Error-Msg "Cannot connect to remote server"
        Write-Host "Package created at: $PackagePath" -ForegroundColor Yellow
        Write-Host "Please upload manually." -ForegroundColor Yellow
        exit 1
    }
    
    # Upload package
    Write-Host "[INFO] Uploading package to server..." -ForegroundColor Cyan
    $remoteTemp = "/tmp/$PackageName"
    Copy-FileRemote $DeployConfig.ServerHost $DeployConfig.ServerUser $DeployConfig.Password $PackagePath $remoteTemp
    Write-Success "Package uploaded"
    
    # Execute deployment
    Write-Host "[INFO] Executing deployment on server..." -ForegroundColor Cyan
    $deployCmd = @"
cd /tmp && tar -xzvf $PackageName && cd lumenim-ubuntu && bash deploy.sh
"@
    Invoke-SSHCommand $DeployConfig.ServerHost $DeployConfig.ServerUser $DeployConfig.Password $deployCmd
    Write-Success "Deployment completed"
    
    # Final check
    Write-Host ""
    Write-Host "[INFO] Checking service status..." -ForegroundColor Cyan
    $statusCmd = "systemctl status lumenim-http --no-pager | head -5"
    Invoke-SSHCommand $DeployConfig.ServerHost $DeployConfig.ServerUser $DeployConfig.Password $statusCmd
}

Write-Host ""
Write-Success "All tasks completed!"
Write-Host ""
