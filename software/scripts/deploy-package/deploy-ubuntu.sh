#!/bin/bash
#===============================================================================
# LumenIM Ubuntu Deploy Package Builder
# Version: 2.0.0
# Target: Ubuntu 20.04 Server (192.168.23.131)
# Usage: bash deploy-ubuntu.sh [--remote-deploy] [--host <IP>] [--user <user>]
#===============================================================================

set -e

# Version
VERSION="2.0.0"

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Detect OS and calculate project root
OS="$(uname -s)"
if [[ "$OS" == "MSYS" || "$OS" == "MINGW"* || "$OS" == "CYGWIN"* ]]; then
    PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"
else
    PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
fi

# Output directories
OUTPUT_DIR="$SCRIPT_DIR/output"
TEMP_DIR="$SCRIPT_DIR/temp"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)

# Directories
FRONT_SRC="$PROJECT_ROOT/front"
BACK_SRC="$PROJECT_ROOT/backend"

# Deploy Configuration
REMOTE_DEPLOY=false
REMOTE_HOST="192.168.23.131"
REMOTE_USER="wenming429"
REMOTE_PASSWORD=""
REMOTE_DIR="/opt/lumenim"

# Service Ports
HTTP_PORT=9501
WEBSOCKET_PORT=9502

# Database Config
MYSQL_HOST="127.0.0.1"
MYSQL_PORT=3306
MYSQL_USER="root"
MYSQL_PASSWORD="wenming429"
MYSQL_DATABASE="go_chat"

# Redis Config
REDIS_HOST="127.0.0.1"
REDIS_PORT=6379
REDIS_PASSWORD=""

#===============================================================================
# Parse Arguments
#===============================================================================

while [[ $# -gt 0 ]]; do
    case $1 in
        --remote-deploy)
            REMOTE_DEPLOY=true
            shift
            ;;
        --host)
            REMOTE_HOST="$2"
            shift 2
            ;;
        --user)
            REMOTE_USER="$2"
            shift 2
            ;;
        --password)
            REMOTE_PASSWORD="$2"
            shift 2
            ;;
        --help|-h)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --remote-deploy     Deploy to remote server after build"
            echo "  --host <IP>         Remote server IP (default: 192.168.23.131)"
            echo "  --user <user>       SSH username (default: wenming429)"
            echo "  --password <pwd>    SSH password (optional, uses SSH key if not provided)"
            echo "  --help, -h         Show this help"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

#===============================================================================
# Helper Functions
#===============================================================================

log_info() {
    echo -e "${BLUE}[INFO] $1${NC}"
}

log_step() {
    echo -e "\n${YELLOW}[Step $1/$2] $3${NC}"
}

log_success() {
    echo -e "${GREEN}[OK] $1${NC}"
}

log_error() {
    echo -e "${RED}[ERROR] $1${NC}" >&2
}

check_command() {
    if ! command -v "$1" &> /dev/null; then
        log_error "Required command not found: $1"
        return 1
    fi
    log_success "$1: $(command -v $1)"
    return 0
}

cleanup() {
    log_info "Cleaning up temp files..."
    rm -rf "$TEMP_DIR"
}

error_exit() {
    log_error "$1"
    cleanup
    exit 1
}

# SSH Commands
ssh_cmd() {
    if [ -n "$REMOTE_PASSWORD" ]; then
        sshpass -p "$REMOTE_PASSWORD" ssh -o StrictHostKeyChecking=no "$REMOTE_USER@$REMOTE_HOST" "$1"
    else
        ssh -o StrictHostKeyChecking=no "$REMOTE_USER@$REMOTE_HOST" "$1"
    fi
}

scp_file() {
    if [ -n "$REMOTE_PASSWORD" ]; then
        sshpass -p "$REMOTE_PASSWORD" scp -o StrictHostKeyChecking=no "$1" "$REMOTE_USER@$REMOTE_HOST:$2"
    else
        scp -o StrictHostKeyChecking=no "$1" "$REMOTE_USER@$REMOTE_HOST:$2"
    fi
}

#===============================================================================
# Banner
#===============================================================================

echo ""
echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║       LumenIM Ubuntu Deploy Package Builder v${VERSION}           ║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${BLUE}Project Root:${NC} $PROJECT_ROOT"
echo -e "${BLUE}Output Dir:${NC}  $OUTPUT_DIR"
echo -e "${BLUE}Timestamp:${NC}   $TIMESTAMP"
echo ""

if [ "$REMOTE_DEPLOY" = true ]; then
    echo -e "${BLUE}Remote Host:${NC}  $REMOTE_HOST"
    echo -e "${BLUE}Remote User:${NC}  $REMOTE_USER"
    echo -e "${BLUE}Remote Dir:${NC}   $REMOTE_DIR"
    echo ""
fi

#===============================================================================
# Step 1: Check Dependencies
#===============================================================================

log_step 1 5 "Checking dependencies..."

if ! check_command "go"; then
    log_error "Please install Go 1.21+: https://go.dev/dl/"
    exit 1
fi

if ! check_command "node"; then
    log_error "Please install Node.js 18+: https://nodejs.org/"
    exit 1
fi

if ! check_command "pnpm"; then
    log_error "Please install pnpm: npm install -g pnpm"
    exit 1
fi

if ! check_command "tar"; then
    log_error "tar is required"
    exit 1
fi

# Check sshpass for password auth
if [ -n "$REMOTE_PASSWORD" ] && ! command -v sshpass &> /dev/null; then
    log_error "sshpass is required for password authentication"
    log_info "Install: apt install sshpass"
    exit 1
fi

#===============================================================================
# Step 2: Build Frontend
#===============================================================================

log_step 2 5 "Building frontend..."

if [ ! -d "$FRONT_SRC" ]; then
    error_exit "Frontend source not found: $FRONT_SRC"
fi

cd "$FRONT_SRC"

log_info "Installing frontend dependencies..."
pnpm install --production

log_info "Running production build..."
pnpm build

if [ ! -d "dist" ]; then
    error_exit "Frontend build failed - dist directory not found"
fi

# Create temp directory structure
mkdir -p "$TEMP_DIR/deploy/front/dist"
cp -r dist/* "$TEMP_DIR/deploy/front/dist/"

log_success "Frontend build completed"

#===============================================================================
# Step 3: Build Backend
#===============================================================================

log_step 3 5 "Building backend..."

if [ ! -d "$BACK_SRC" ]; then
    error_exit "Backend source not found: $BACK_SRC"
fi

cd "$BACK_SRC"

# Set cross-compile environment
export CGO_ENABLED=0
export GOOS=linux
export GOARCH=amd64
export GOPROXY=https://goproxy.cn,direct

log_info "Compiling backend for Linux amd64..."

# Find and build
if [ -f "./cmd/lumenim/main.go" ]; then
    go build -ldflags="-s -w" -o lumenim ./cmd/lumenim
elif [ -f "./cmd/server/main.go" ]; then
    go build -ldflags="-s -w" -o lumenim ./cmd/server
elif [ -f "./main.go" ]; then
    go build -ldflags="-s -w" -o lumenim .
else
    error_exit "main.go not found in backend"
fi

if [ ! -f "lumenim" ]; then
    error_exit "Backend build failed - executable not generated"
fi

# Create directory structure
mkdir -p "$TEMP_DIR/deploy/backend/sql"
mkdir -p "$TEMP_DIR/deploy/backend/uploads/images"
mkdir -p "$TEMP_DIR/deploy/backend/uploads/files"
mkdir -p "$TEMP_DIR/deploy/backend/uploads/avatars"
mkdir -p "$TEMP_DIR/deploy/backend/uploads/audio"
mkdir -p "$TEMP_DIR/deploy/backend/uploads/video"
mkdir -p "$TEMP_DIR/deploy/backend/runtime/logs"
mkdir -p "$TEMP_DIR/deploy/backend/runtime/cache"
mkdir -p "$TEMP_DIR/deploy/backend/runtime/temp"
mkdir -p "$TEMP_DIR/deploy/backend/config"

# Copy executable
cp lumenim "$TEMP_DIR/deploy/backend/"

# Copy SQL files
if [ -f "data/sql/lumenim.sql" ]; then
    cp data/sql/lumenim.sql "$TEMP_DIR/deploy/backend/sql/"
elif [ -f "sql/lumenim.sql" ]; then
    cp sql/lumenim.sql "$TEMP_DIR/deploy/backend/sql/"
fi

chmod +x "$TEMP_DIR/deploy/backend/lumenim"

log_success "Backend build completed (Linux amd64)"

#===============================================================================
# Step 4: Create Configuration Files
#===============================================================================

log_step 4 5 "Creating configuration files..."

# Frontend nginx.conf
cat > "$TEMP_DIR/deploy/front/config/nginx.conf" << 'EOF'
server {
    listen 80;
    server_name _;

    root /var/www/lumenim;
    index index.html;

    # Frontend Routes (SPA)
    location / {
        try_files $uri $uri/ /index.html;
    }

    # API Proxy
    location /api {
        proxy_pass http://127.0.0.1:9501;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    # WebSocket Proxy
    location /ws {
        proxy_pass http://127.0.0.1:9502;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
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
EOF

# Backend config.yaml
cat > "$TEMP_DIR/deploy/backend/config/config.yaml" << EOF
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
  http_addr: ":${HTTP_PORT}"
  websocket_addr: ":${WEBSOCKET_PORT}"
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
  host: ${REDIS_HOST}
  port: ${REDIS_PORT}
  auth: "${REDIS_PASSWORD}"
  database: 0
  pool_size: 100

# ==================== MySQL Config ====================
mysql:
  host: ${MYSQL_HOST}
  port: ${MYSQL_PORT}
  username: ${MYSQL_USER}
  password: "${MYSQL_PASSWORD}"
  database: ${MYSQL_DATABASE}
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
EOF

# Systemd Service Files
create_service() {
    local name="$1"
    local desc="$2"
    cat > "$TEMP_DIR/deploy/backend/config/lumenim-${name}.service" << EOF
[Unit]
Description=LumenIM ${desc}
After=network.target mysql.service redis.service

[Service]
Type=simple
User=lumenim
Group=lumenim
WorkingDirectory=${REMOTE_DIR}/backend
ExecStart=${REMOTE_DIR}/backend/lumenim ${name} --config=${REMOTE_DIR}/backend/config/config.yaml
Restart=always
RestartSec=5
StandardOutput=journal
StandardError=journal
SyslogIdentifier=lumenim-${name}
NoNewPrivileges=true
ProtectSystem=strict
ReadWritePaths=${REMOTE_DIR}/backend/runtime,${REMOTE_DIR}/backend/uploads

[Install]
WantedBy=multi-user.target
EOF
}

create_service "http" "HTTP Service"
create_service "comet" "WebSocket Service"
create_service "queue" "Queue Service"
create_service "crontab" "Crontab Service"

# Start/Stop Scripts
cat > "$TEMP_DIR/deploy/backend/config/start.sh" << EOF
#!/bin/bash
cd "\$(dirname "\${BASH_SOURCE[0]}")/.."
./lumenim http --config=config/config.yaml &
./lumenim comet --config=config/config.yaml &
./lumenim queue --config=config/config.yaml &
./lumenim crontab --config=config/config.yaml &
echo "All services started!"
EOF

cat > "$TEMP_DIR/deploy/backend/config/stop.sh" << 'EOF'
#!/bin/bash
pkill -f lumenim || true
echo "All services stopped!"
EOF

chmod +x "$TEMP_DIR/deploy/backend/config/start.sh"
chmod +x "$TEMP_DIR/deploy/backend/config/stop.sh"

# Deploy Script
mkdir -p "$TEMP_DIR/deploy/scripts"
cat > "$TEMP_DIR/deploy/deploy.sh" << 'DEPLOYEOF'
#!/bin/bash
set -e

DEPLOY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NGINX_WEB_ROOT="/var/www/lumenim"
APP_DIR="/opt/lumenim"

echo "==========================================="
echo "  LumenIM Ubuntu Deployment Script"
echo "==========================================="

if [ "$EUID" -ne 0 ]; then
    echo "Please run as root: sudo bash deploy.sh"
    exit 1
fi

# Backup existing deployment
if [ -d "$APP_DIR" ]; then
    echo "[Backup] Backing up existing deployment..."
    mv "$APP_DIR" "$APP_DIR-backup-$(date +%Y%m%d-%H%M%S)"
fi

# Create user
id lumenim &>/dev/null || useradd -r -s /bin/bash lumenim

# Deploy Backend
echo "[1/4] Deploying backend..."
mkdir -p "$APP_DIR/backend"
cp -r backend/* "$APP_DIR/backend/"
mkdir -p "$APP_DIR/backend/uploads"
mkdir -p "$APP_DIR/backend/runtime"
chmod +x "$APP_DIR/backend/lumenim"
chmod +x "$APP_DIR/backend/config/start.sh"
chmod +x "$APP_DIR/backend/config/stop.sh"
chown -R lumenim:lumenim "$APP_DIR/backend"

# Install Systemd Services
echo "[2/4] Installing systemd services..."
cp "$APP_DIR/backend/config/lumenim-http.service" /etc/systemd/system/
cp "$APP_DIR/backend/config/lumenim-comet.service" /etc/systemd/system/
cp "$APP_DIR/backend/config/lumenim-queue.service" /etc/systemd/system/
cp "$APP_DIR/backend/config/lumenim-crontab.service" /etc/systemd/system/
systemctl daemon-reload

# Deploy Frontend
echo "[3/4] Deploying frontend..."
mkdir -p "$NGINX_WEB_ROOT"
cp -r front/dist/* "$NGINX_WEB_ROOT/"
chown -R www-data:www-data "$NGINX_WEB_ROOT"

# Configure Nginx
echo "[4/4] Configuring Nginx..."
cp front/config/nginx.conf /etc/nginx/sites-available/lumenim
ln -sf /etc/nginx/sites-available/lumenim /etc/nginx/sites-enabled/lumenim
rm -f /etc/nginx/sites-enabled/default
nginx -t && nginx -s reload

echo ""
echo "==========================================="
echo "  Deployment Complete!"
echo "==========================================="
echo ""
echo "Next steps:"
echo "  1. Edit config: vim $APP_DIR/backend/config/config.yaml"
echo "  2. Import DB: mysql -u root -p < backend/sql/lumenim.sql"
echo "  3. Start: systemctl start lumenim-http lumenim-comet"
echo "  4. Check: systemctl status lumenim-http"
echo ""
DEPLOYEOF

chmod +x "$TEMP_DIR/deploy/deploy.sh"

# Init DB Script
cat > "$TEMP_DIR/deploy/scripts/init-db.sh" << EOF
#!/bin/bash
echo "Initializing database..."
mysql -h "${MYSQL_HOST}" -P ${MYSQL_PORT} -u ${MYSQL_USER} -p${MYSQL_PASSWORD} -e "CREATE DATABASE IF NOT EXISTS ${MYSQL_DATABASE} CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
mysql -h "${MYSQL_HOST}" -P ${MYSQL_PORT} -u ${MYSQL_USER} -p${MYSQL_PASSWORD} ${MYSQL_DATABASE} < backend/sql/lumenim.sql
echo "Database initialized successfully!"
EOF

chmod +x "$TEMP_DIR/deploy/scripts/init-db.sh"

# README
cat > "$TEMP_DIR/deploy/README.md" << EOF
# LumenIM Deployment Package

## Quick Start

1. Upload to server: scp lumenim-ubuntu-${TIMESTAMP}.tar.gz user@server:/opt/
2. SSH to server
3. Extract: tar -xzvf lumenim-ubuntu-${TIMESTAMP}.tar.gz
4. Deploy: cd lumenim-ubuntu && sudo bash deploy.sh
5. Configure: vim /opt/lumenim/backend/config/config.yaml
6. Import DB: mysql -u root -p < backend/sql/lumenim.sql
7. Start: systemctl start lumenim-http lumenim-comet

## Service Ports

| Service | Port | Description |
|---------|------|-------------|
| HTTP API | ${HTTP_PORT} | RESTful API |
| WebSocket | ${WEBSOCKET_PORT} | Real-time messaging |
| Nginx | 80 | Web frontend |

## Config Files

- Backend: /opt/lumenim/backend/config/config.yaml
- Nginx: /etc/nginx/sites-available/lumenim

## Update Deployment

1. Stop: systemctl stop lumenim-http lumenim-comet
2. Backup: mv /opt/lumenim /opt/lumenim-backup-$(date +%Y%m%d)
3. Deploy new: tar -xzvf new-package.tar.gz
4. Start: systemctl start lumenim-http lumenim-comet
EOF

log_success "Configuration files created"

#===============================================================================
# Step 5: Create Package
#===============================================================================

log_step 5 5 "Creating deploy package..."

mkdir -p "$OUTPUT_DIR"
cd "$TEMP_DIR"

PACKAGE_NAME="lumenim-ubuntu-${TIMESTAMP}.tar.gz"
PACKAGE_PATH="$OUTPUT_DIR/$PACKAGE_NAME"

tar -czvf "$PACKAGE_PATH" deploy/

if [ -f "$PACKAGE_PATH" ]; then
    SIZE=$(du -h "$PACKAGE_PATH" | cut -f1)
    
    echo ""
    echo -e "${GREEN}==================================================${NC}"
    echo -e "${GREEN}   Package Build Complete!${NC}"
    echo -e "${GREEN}==================================================${NC}"
    echo ""
    echo -e "${YELLOW}Package Location:${NC} $PACKAGE_PATH"
    echo -e "${YELLOW}Package Size:${NC}    $SIZE"
    echo ""
else
    error_exit "Package creation failed"
fi

# Cleanup
cleanup

#===============================================================================
# Step 6: Remote Deploy (Optional)
#===============================================================================

if [ "$REMOTE_DEPLOY" = true ]; then
    echo ""
    echo -e "${CYAN}==================================================${NC}"
    echo -e "${CYAN}   Remote Deployment${NC}"
    echo -e "${CYAN}==================================================${NC}"
    echo ""
    
    # Test SSH connection
    echo -n "Testing SSH connection to ${REMOTE_USER}@${REMOTE_HOST}..."
    if ssh_cmd "echo 'OK'" &>/dev/null; then
        echo -e "${GREEN} OK${NC}"
    else
        echo -e "${RED} Failed${NC}"
        echo -e "${YELLOW}Package created at: $PACKAGE_PATH${NC}"
        echo -e "${YELLOW}Please upload manually.${NC}"
        exit 1
    fi
    
    # Upload package
    echo -e "${BLUE}[INFO] Uploading package to server...${NC}"
    scp_file "$PACKAGE_PATH" "/tmp/$PACKAGE_NAME"
    echo -e "${GREEN}[OK] Package uploaded${NC}"
    
    # Execute deployment
    echo -e "${BLUE}[INFO] Executing deployment on server...${NC}"
    ssh_cmd "cd /tmp && tar -xzvf $PACKAGE_NAME && cd lumenim-ubuntu && bash deploy.sh"
    echo -e "${GREEN}[OK] Deployment completed${NC}"
    
    # Final check
    echo ""
    echo -e "${BLUE}[INFO] Checking service status...${NC}"
    ssh_cmd "systemctl status lumenim-http --no-pager | head -5"
fi

echo ""
echo -e "${GREEN}Build completed successfully!${NC}"
echo ""
