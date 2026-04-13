#!/bin/bash
#
# LumenIM Ubuntu 20.04 自动化部署脚本
# LumenIM Ubuntu 20.04 Automated Deployment Script
#
# 使用方法: sudo ./install-ubuntu20.sh [选项]
# Usage: sudo ./install-ubuntu20.sh [options]
#
# 版本: 2.0.0
# 更新日期: 2026-04-10
# 目标服务器: 192.168.23.131
# 部署用户: wenming429

set -e

# ============================================================
# 服务器配置 - 请根据实际环境修改
# ============================================================

# 代码仓库地址
GIT_REPO="https://github.com/wenming429/AIProject.git"

# 安装根目录
INSTALL_ROOT="/opt/lumenim"

# 项目目录
PROJECT_DIR="/var/www/lumenim"

# 数据目录
DATA_DIR="/var/lib/lumenim"

# 运行用户
RUN_USER="wenming429"

# 服务端口配置
HTTP_PORT=9501
WS_PORT=9502
TCP_PORT=9505
MYSQL_PORT=3306
REDIS_PORT=6379

# MySQL 配置
MYSQL_ROOT_PASSWORD="wenming429"
MYSQL_DATABASE="go_chat"
MYSQL_USER="lumenim"
MYSQL_PASSWORD="lumenim123"

# Redis 配置
REDIS_PASSWORD=""

# JWT 配置
JWT_SECRET="836c3fea9bba4e04d51bd0fbcc5d8e7f"

# 服务启动方式
SERVICE_MANAGER="systemd"

# 下载源配置（离线包目录）
OFFLINE_PACKAGE_DIR=""

# ============================================================
# 版本定义
# ============================================================

GO_VERSION="1.22.0"
NODE_VERSION="20.11.0"
MYSQL_VERSION="8.0"
REDIS_VERSION="7.0"
PROTOBUF_VERSION="25.1"
PNPM_VERSION="9.0.0"

# ============================================================
# 颜色定义
# ============================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# ============================================================
# 函数定义
# ============================================================

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

check_root() {
    if [ "$EUID" -ne 0 ]; then
        log_error "此脚本需要 root 权限运行，请使用 sudo"
        exit 1
    fi
}

check_command() {
    if ! command -v "$1" &> /dev/null; then
        return 1
    fi
    return 0
}

install_package() {
    local pkg="$1"
    log_info "安装软件包: $pkg"
    apt-get install -y "$pkg"
}

# ============================================================
# 环境检查
# ============================================================

check_environment() {
    log_step "检查服务器环境..."
    
    echo ""
    echo "=========================================="
    echo "系统信息"
    echo "=========================================="
    
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        log_info "操作系统: $NAME $VERSION"
        if [ "$ID" != "ubuntu" ]; then
            log_warn "非 Ubuntu 系统，部分功能可能不兼容"
        fi
    fi
    
    log_info "系统架构: $(uname -m)"
    log_info "内核版本: $(uname -r)"
    log_info "总内存: $(free -h | awk '/^Mem:/{print $2}')"
    log_info "可用空间: $(df -h / | awk 'NR==2{print $4}')"
    
    if ping -c 1 8.8.8.8 &>/dev/null; then
        log_success "网络连接: 正常"
    else
        log_warn "网络连接: 异常（可能无法访问外网）"
    fi
    
    if id "$RUN_USER" &>/dev/null; then
        log_success "部署用户: $RUN_USER 已存在"
    else
        log_warn "部署用户: $RUN_USER 不存在，将创建"
    fi
    
    echo ""
    echo "=========================================="
    echo "已安装软件检查"
    echo "=========================================="
    
    check_command go && log_success "Go: $(go version | grep -oP 'go\d+\.\d+\.\d+')" || log_warn "Go: 未安装"
    check_command node && log_success "Node.js: $(node --version)" || log_warn "Node.js: 未安装"
    check_command pnpm && log_success "pnpm: $(pnpm --version)" || log_warn "pnpm: 未安装"
    check_command mysql && log_success "MySQL: 已安装" || log_warn "MySQL: 未安装"
    check_command redis-server && log_success "Redis: 已安装" || log_warn "Redis: 未安装"
    check_command protoc && log_success "Protobuf: $(protoc --version)" || log_warn "Protobuf: 未安装"
    
    echo ""
    log_success "环境检查完成"
}

# ============================================================
# 安装系统依赖
# ============================================================

install_system_deps() {
    log_step "安装系统依赖..."
    
    echo "=========================================="
    echo "更新软件源"
    echo "=========================================="
    
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -qq
    
    install_package "build-essential"
    install_package "wget"
    install_package "curl"
    install_package "git"
    install_package "unzip"
    install_package "tar"
    install_package "xz-utils"
    install_package "ca-certificates"
    install_package "jq"
    install_package "net-tools"
    install_package "lsof"
    install_package "ssl-cert"
    install_package "mysql-server"
    install_package "redis-server"
    install_package "libssl-dev"
    
    log_success "系统依赖安装完成"
}

# ============================================================
# 安装 Go 环境
# ============================================================

install_go() {
    log_step "安装 Go ${GO_VERSION}..."
    
    local go_tarball="${OFFLINE_PACKAGE_DIR}/go${GO_VERSION}.linux-amd64.tar.gz"
    local go_link="/usr/local/go"
    
    if [ -f "$go_link/bin/go" ]; then
        local current_version=$("$go_link/bin/go" version 2>/dev/null | grep -oP 'go\d+\.\d+\.\d+' || true)
        if [ "$current_version" = "go${GO_VERSION}" ]; then
            log_info "Go ${GO_VERSION} 已安装，跳过"
            return 0
        fi
    fi
    
    if [ -f "$go_tarball" ]; then
        log_info "从离线包安装 Go: $go_tarball"
        tar -xzf "$go_tarball" -C /tmp/
        rm -rf "$go_link"
        mv /tmp/go "$go_link"
    else
        log_info "在线安装 Go ${GO_VERSION}..."
        cd /tmp
        wget -q "https://go.dev/dl/go${GO_VERSION}.linux-amd64.tar.gz" -O go.tar.gz
        tar -xzf go.tar.gz -C /tmp/
        rm -rf "$go_link"
        mv /tmp/go "$go_link"
        rm -f go.tar.gz
    fi
    
    cat > /etc/profile.d/go.sh << 'EOF'
export GOROOT=/usr/local/go
export PATH=$PATH:$GOROOT/bin
export GOPATH=$HOME/go
export GOPROXY=https://goproxy.cn,direct
EOF
    chmod +x /etc/profile.d/go.sh
    
    export GOROOT=/usr/local/go
    export PATH=$PATH:$GOROOT/bin
    export GOPATH=$HOME/go
    export GOPROXY=https://goproxy.cn,direct
    
    log_success "Go ${GO_VERSION} 安装完成"
    "$go_link/bin/go" version
}

# ============================================================
# 安装 Node.js 环境
# ============================================================

install_nodejs() {
    log_step "安装 Node.js ${NODE_VERSION}..."
    
    local node_tarball="${OFFLINE_PACKAGE_DIR}/node-v${NODE_VERSION}-linux-x64.tar.xz"
    local node_link="/usr/local/node"
    
    if [ -f "$node_link/bin/node" ]; then
        local current_version=$("$node_link/bin/node" --version 2>/dev/null || true)
        if [ "$current_version" = "v${NODE_VERSION}" ]; then
            log_info "Node.js ${NODE_VERSION} 已安装，跳过"
            return 0
        fi
    fi
    
    if [ -f "$node_tarball" ]; then
        log_info "从离线包安装 Node.js: $node_tarball"
        tar -xJf "$node_tarball" -C /tmp/
        rm -rf "$node_link"
        mv "/tmp/node-v${NODE_VERSION}-linux-x64" "$node_link"
    else
        log_info "在线安装 Node.js ${NODE_VERSION}..."
        cd /tmp
        wget -q "https://nodejs.org/dist/v${NODE_VERSION}/node-v${NODE_VERSION}-linux-x64.tar.xz" -O node.tar.xz
        tar -xJf node.tar.xz -C /tmp/
        rm -rf "$node_link"
        mv /tmp/node-v${NODE_VERSION}-linux-x64 "$node_link"
        rm -f node.tar.xz
    fi
    
    cat > /etc/profile.d/nodejs.sh << EOF
export NODE_PREFIX=/usr/local/node
export PATH=\$PATH:\$NODE_PREFIX/bin
EOF
    chmod +x /etc/profile.d/nodejs.sh
    
    export NODE_PREFIX=/usr/local/node
    export PATH=$PATH:$NODE_PREFIX/bin
    
    log_success "Node.js ${NODE_VERSION} 安装完成"
    "$node_link/bin/node" --version
    
    log_info "安装 pnpm ${PNPM_VERSION}..."
    "$node_link/bin/node" -e "require('child_process').execSync('npm install -g pnpm@${PNPM_VERSION}', {stdio: 'inherit'})"
    log_success "pnpm 安装完成"
}

# ============================================================
# 安装 MySQL
# ============================================================

install_mysql() {
    log_step "安装 MySQL ${MYSQL_VERSION}..."
    
    if check_command mysql; then
        log_info "MySQL 已安装，跳过"
        return 0
    fi
    
    export DEBIAN_FRONTEND=noninteractive
    apt-get install -y mysql-server
    log_success "MySQL 安装完成"
}

# ============================================================
# 安装 Redis
# ============================================================

install_redis() {
    log_step "安装 Redis ${REDIS_VERSION}..."
    
    if check_command redis-server; then
        log_info "Redis 已安装，跳过"
        return 0
    fi
    
    export DEBIAN_FRONTEND=noninteractive
    apt-get install -y redis-server
    log_success "Redis 安装完成"
}

# ============================================================
# 配置数据库
# ============================================================

configure_database() {
    log_step "配置数据库..."
    
    create_directory "$DATA_DIR" "$RUN_USER" "755"
    
    log_info "配置 MySQL..."
    cat > /etc/mysql/mysql.conf.d/lumenim.cnf << 'EOF'
[mysqld]
character-set-server = utf8mb4
collation-server = utf8mb4_general_ci
max_connections = 1000
innodb_buffer_pool_size = 256M
innodb_log_file_size = 64M
max_allowed_packet = 64M
default-authentication-plugin = mysql_native_password
EOF
    
    log_info "配置 Redis..."
    cat > /etc/redis/redis.conf << EOF
bind 127.0.0.1
port 6379
protected-mode yes
daemonize no
loglevel notice
databases 16
save 900 1
save 300 10
save 60 10000
maxmemory 256mb
maxmemory-policy allkeys-lru
$( [ -n "$REDIS_PASSWORD" ] && echo "requirepass $REDIS_PASSWORD" )
EOF
    
    log_success "数据库配置完成"
}

# ============================================================
# 初始化数据库
# ============================================================

init_database() {
    log_step "初始化数据库..."
    
    log_info "启动 MySQL..."
    service mysql start
    sleep 5
    
    log_info "设置 MySQL root 密码..."
    mysql -e "ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY '$MYSQL_ROOT_PASSWORD';" 2>/dev/null || true
    
    log_info "创建数据库和用户..."
    mysql -u root -p"$MYSQL_ROOT_PASSWORD" << 'EOSQL'
CREATE DATABASE IF NOT EXISTS go_chat CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;
CREATE USER IF NOT EXISTS 'lumenim'@'localhost' IDENTIFIED BY 'lumenim123';
CREATE USER IF NOT EXISTS 'lumenim'@'%' IDENTIFIED BY 'lumenim123';
GRANT ALL PRIVILEGES ON go_chat.* TO 'lumenim'@'localhost';
GRANT ALL PRIVILEGES ON go_chat.* TO 'lumenim'@'%';
FLUSH PRIVILEGES;
EOSQL
    
    if [ -f "$PROJECT_DIR/backend/sql/init.sql" ]; then
        log_info "导入数据库表结构..."
        mysql -u root -p"$MYSQL_ROOT_PASSWORD" go_chat < "$PROJECT_DIR/backend/sql/init.sql"
    fi
    
    log_info "启动 Redis..."
    service redis-server start
    log_success "数据库初始化完成"
}

# ============================================================
# 安装 Protocol Buffers
# ============================================================

install_protobuf() {
    log_step "安装 Protocol Buffers ${PROTOBUF_VERSION}..."
    
    local protoc_zip="${OFFLINE_PACKAGE_DIR}/protoc-${PROTOBUF_VERSION}-linux-x86_64.zip"
    local protoc_dir="${INSTALL_ROOT}/protobuf"
    
    if [ -f /usr/local/bin/protoc ]; then
        local current_version=$(/usr/local/bin/protoc --version | grep -oP '\d+\.\d+\.\d+' || true)
        if [ "$current_version" = "${PROTOBUF_VERSION}" ]; then
            log_info "Protocol Buffers ${PROTOBUF_VERSION} 已安装，跳过"
            return 0
        fi
    fi
    
    if [ -f "$protoc_zip" ]; then
        log_info "从离线包安装 Protocol Buffers: $protoc_zip"
        unzip -qo "$protoc_zip" -d "$protoc_dir"
    else
        log_info "在线安装 Protocol Buffers ${PROTOBUF_VERSION}..."
        mkdir -p "$protoc_dir"
        cd /tmp
        wget -q "https://github.com/protocolbuffers/protobuf/releases/download/v${PROTOBUF_VERSION}/protoc-${PROTOBUF_VERSION}-linux-x86_64.zip" -O protoc.zip
        unzip -qo protoc.zip -d "$protoc_dir"
        rm -f protoc.zip
    fi
    
    if [ -f "$protoc_dir/bin/protoc" ]; then
        cp -f "$protoc_dir/bin/protoc" /usr/local/bin/
    fi
    
    log_success "Protocol Buffers 安装完成"
    /usr/local/bin/protoc --version
}

# ============================================================
# 下载代码
# ============================================================

clone_repository() {
    log_step "克隆代码仓库..."
    
    if [ -d "$PROJECT_DIR" ]; then
        log_warn "项目目录已存在: $PROJECT_DIR"
        read -p "是否更新代码? (y/n): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            cd "$PROJECT_DIR"
            git pull origin master
        fi
        return 0
    fi
    
    log_info "克隆代码仓库: $GIT_REPO"
    git clone "$GIT_REPO" "$PROJECT_DIR"
    log_success "代码克隆完成"
}

# ============================================================
# 配置项目
# ============================================================

configure_project() {
    log_step "配置项目..."
    
    create_directory "$INSTALL_ROOT" "root" "755"
    create_directory "$PROJECT_DIR" "$RUN_USER" "755"
    create_directory "$DATA_DIR" "$RUN_USER" "755"
    
    log_info "配置后端..."
    cat > "$PROJECT_DIR/backend/config.yaml" << EOF
server:
  http_port: ${HTTP_PORT}
  ws_port: ${WS_PORT}
  tcp_port: ${TCP_PORT}

database:
  host: localhost
  port: ${MYSQL_PORT}
  username: root
  password: ${MYSQL_ROOT_PASSWORD}
  database: ${MYSQL_DATABASE}
  charset: utf8mb4

redis:
  host: localhost
  port: ${REDIS_PORT}
  password: ${REDIS_PASSWORD}

jwt:
  secret: ${JWT_SECRET}
  expires_time: 86400
  buffer_time: 3600
EOF
    
    log_info "配置前端..."
    cat > "$PROJECT_DIR/front/.env.production" << EOF
VITE_APP_TITLE=LumenIM
VITE_API_BASE_URL=http://192.168.23.131:${HTTP_PORT}/api/v1
VITE_WS_URL=ws://192.168.23.131:${WS_PORT}
VITE_UPLOAD_URL=http://192.168.23.131:${HTTP_PORT}/api/v1/upload
EOF
    
    chown -R "$RUN_USER:$RUN_USER" "$PROJECT_DIR"
    log_success "项目配置完成"
}

# ============================================================
# 构建后端
# ============================================================

build_backend() {
    log_step "构建后端..."
    
    export GOROOT=/usr/local/go
    export PATH=$PATH:$GOROOT/bin
    export GOPROXY=https://goproxy.cn,direct
    
    cd "$PROJECT_DIR/backend"
    
    log_info "下载 Go 依赖..."
    go mod download
    
    log_info "安装 protobuf 插件..."
    go install google.golang.org/protobuf/cmd/protoc-gen-go@latest
    go install github.com/envoyproxy/protoc-gen-validate@latest
    
    mkdir -p "$PROJECT_DIR/backend/bin"
    
    log_info "编译后端..."
    go build -o bin/lumenim .
    
    chown "$RUN_USER:$RUN_USER" "$PROJECT_DIR/backend/bin/lumenim"
    log_success "后端构建完成"
}

# ============================================================
# 安装前端依赖
# ============================================================

install_front_deps() {
    log_step "安装前端依赖..."
    
    export NODE_PREFIX=/usr/local/node
    export PATH=$PATH:$NODE_PREFIX/bin
    
    cd "$PROJECT_DIR/front"
    log_info "安装 npm 依赖..."
    pnpm install --frozen-lockfile || pnpm install
    log_success "前端依赖安装完成"
}

# ============================================================
# 创建用户
# ============================================================

create_deploy_user() {
    log_step "创建部署用户..."
    
    if id "$RUN_USER" &>/dev/null; then
        log_info "用户 $RUN_USER 已存在"
    else
        log_info "创建用户: $RUN_USER"
        useradd -m -s /bin/bash -G sudo "$RUN_USER"
        echo "$RUN_USER:$MYSQL_ROOT_PASSWORD" | chpasswd
    fi
    
    usermod -aG sudo "$RUN_USER"
    echo "$RUN_USER ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/$RUN_USER
    chmod 440 /etc/sudoers.d/$RUN_USER
    log_success "用户配置完成"
}

# ============================================================
# 创建 systemd 服务
# ============================================================

create_systemd_service() {
    log_step "创建 systemd 服务..."
    
    cat > /etc/profile.d/lumenim.sh << EOF
export GOROOT=/usr/local/go
export PATH=\$PATH:/usr/local/go/bin:/usr/local/node/bin
export GOPATH=\$HOME/go
export GOPROXY=https://goproxy.cn,direct
export NODE_PREFIX=/usr/local/node
EOF
    chmod +x /etc/profile.d/lumenim.sh
    
    cat > /etc/systemd/system/lumenim-backend.service << EOF
[Unit]
Description=LumenIM Backend Service
Documentation=https://github.com/wenming429/AIProject
After=network.target mysql.service redis.service
Wants=mysql.service redis.service

[Service]
Type=simple
User=${RUN_USER}
Group=${RUN_USER}
WorkingDirectory=${PROJECT_DIR}/backend
Environment="PATH=/usr/local/go/bin:/usr/local/node/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
Environment="GOPROXY=https://goproxy.cn,direct"
ExecStart=${PROJECT_DIR}/backend/bin/lumenim
Restart=on-failure
RestartSec=5s
LimitNOFILE=65536
StandardOutput=journal
StandardError=journal
SyslogIdentifier=lumenim-backend

[Install]
WantedBy=multi-user.target
EOF

    cat > /etc/systemd/system/lumenim-frontend.service << EOF
[Unit]
Description=LumenIM Frontend Service
Documentation=https://github.com/wenming429/AIProject
After=network.target
Wants=network-online.target

[Service]
Type=simple
User=${RUN_USER}
Group=${RUN_USER}
WorkingDirectory=${PROJECT_DIR}/front
Environment="PATH=/usr/local/node/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
ExecStart=/usr/local/node/bin/vite --port ${HTTP_PORT}
Restart=on-failure
RestartSec=5s
StandardOutput=journal
StandardError=journal
SyslogIdentifier=lumenim-frontend

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    log_success "systemd 服务创建完成"
}

# ============================================================
# 启动服务
# ============================================================

start_services() {
    log_step "启动服务..."
    
    log_info "启动 MySQL..."
    systemctl enable mysql
    systemctl start mysql
    
    log_info "启动 Redis..."
    systemctl enable redis-server
    systemctl start redis-server
    
    log_info "启动后端服务..."
    systemctl enable lumenim-backend
    systemctl start lumenim-backend
    
    log_info "启动前端服务..."
    systemctl enable lumenim-frontend
    systemctl start lumenim-frontend
    
    log_success "服务启动完成"
}

# ============================================================
# 检查服务状态
# ============================================================

check_services() {
    log_step "检查服务状态..."
    
    echo ""
    echo "=========================================="
    echo "服务状态"
    echo "=========================================="
    
    if systemctl is-active mysql &>/dev/null; then
        log_success "MySQL: 运行中"
        mysql -u root -p"$MYSQL_ROOT_PASSWORD" -e "SELECT 'MySQL OK' as Status;" 2>/dev/null && log_success "MySQL: 连接正常"
    else
        log_error "MySQL: 未运行"
    fi
    
    if systemctl is-active redis-server &>/dev/null; then
        log_success "Redis: 运行中"
        redis-cli ping &>/dev/null && log_success "Redis: PING 正常"
    else
        log_error "Redis: 未运行"
    fi
    
    if systemctl is-active lumenim-backend &>/dev/null; then
        log_success "lumenim-backend: 运行中"
    else
        log_error "lumenim-backend: 未运行"
        journalctl -u lumenim-backend -n 10 --no-pager
    fi
    
    if systemctl is-active lumenim-frontend &>/dev/null; then
        log_success "lumenim-frontend: 运行中"
    else
        log_warn "lumenim-frontend: 未运行"
    fi
    
    echo ""
    echo "=========================================="
    echo "端口占用"
    echo "=========================================="
    for port in $HTTP_PORT $WS_PORT $TCP_PORT $MYSQL_PORT $REDIS_PORT; do
        if lsof -i:$port &>/dev/null; then
            log_success "端口 $port: 已占用"
        else
            log_warn "端口 $port: 未占用"
        fi
    done
    
    echo ""
    echo "=========================================="
    echo "API 测试"
    echo "=========================================="
    if curl -s http://localhost:$HTTP_PORT/api/v1/health &>/dev/null; then
        log_success "API 健康检查: 通过"
    else
        log_warn "API 健康检查: 失败（服务可能仍在启动）"
    fi
}

# ============================================================
# 配置防火墙
# ============================================================

configure_firewall() {
    log_step "配置防火墙..."
    
    if check_command ufw; then
        log_info "配置 UFW 防火墙..."
        ufw allow 22/tcp
        ufw allow ${HTTP_PORT}/tcp
        ufw allow ${WS_PORT}/tcp
        ufw allow ${TCP_PORT}/tcp
        ufw allow from 192.168.0.0/16 to any port ${MYSQL_PORT}
        echo "y" | ufw enable
        log_success "防火墙配置完成"
        ufw status
    else
        log_warn "UFW 未安装，跳过防火墙配置"
    fi
}

# ============================================================
# 创建目录
# ============================================================

create_directory() {
    local dir="$1"
    local owner="${2:-$RUN_USER}"
    local perms="${3:-0755}"
    
    if [ ! -d "$dir" ]; then
        log_info "创建目录: $dir"
        mkdir -p "$dir"
        chmod "$perms" "$dir"
        chown "$owner:$owner" "$dir" 2>/dev/null || true
    fi
}

# ============================================================
# 显示帮助
# ============================================================

show_help() {
    cat << 'EOF'
LumenIM Ubuntu 20.04 自动化部署脚本

使用方法:
    sudo ./install-ubuntu20.sh [选项]

选项:
    -h, --help              显示帮助信息
    -c, --check            仅检查环境
    -d, --deps             安装系统依赖
    -r, --runtime          安装运行时环境 (Go, Node.js)
    -m, --mysql            安装 MySQL
    -e, --redis            安装 Redis
    -p, --protobuf         安装 Protocol Buffers
    -b, --backend          构建后端
    -f, --frontend         安装前端依赖
    -k, --database         配置并初始化数据库
    -g, --config           配置服务
    -s, --start            启动服务
    -a, --all              完整安装
    --clone                克隆代码仓库
    --firewall             配置防火墙
    --offline=[目录]       离线包目录

配置信息:
    服务器 IP: 192.168.23.131
    部署用户: wenming429
    MySQL 密码: wenming429
    代码仓库: https://github.com/wenming429/AIProject.git

示例:
    sudo ./install-ubuntu20.sh --all
    sudo ./install-ubuntu20.sh --deps --runtime --mysql --redis
    sudo ./install-ubuntu20.sh --clone --config --backend --frontend --start

EOF
}

# ============================================================
# 主函数
# ============================================================

main() {
    echo "=========================================="
    echo "LumenIM Ubuntu 20.04 自动化部署脚本"
    echo "=========================================="
    echo "目标服务器: 192.168.23.131"
    echo "部署用户: $RUN_USER"
    echo ""
    
    DO_CHECK=false
    DO_DEPS=false
    DO_RUNTIME=false
    DO_MYSQL=false
    DO_REDIS=false
    DO_PROTOBUF=false
    DO_BACKEND=false
    DO_FRONTEND=false
    DO_DATABASE=false
    DO_CONFIG=false
    DO_SERVICES=false
    DO_ALL=false
    DO_CLONE=false
    DO_FIREWALL=false
    
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help) show_help; exit 0 ;;
            -c|--check) DO_CHECK=true; shift ;;
            -d|--deps) DO_DEPS=true; shift ;;
            -r|--runtime) DO_RUNTIME=true; shift ;;
            -m|--mysql) DO_MYSQL=true; shift ;;
            -e|--redis) DO_REDIS=true; shift ;;
            -p|--protobuf) DO_PROTOBUF=true; shift ;;
            -b|--backend) DO_BACKEND=true; shift ;;
            -f|--frontend) DO_FRONTEND=true; shift ;;
            -k|--database) DO_DATABASE=true; shift ;;
            -g|--config) DO_CONFIG=true; shift ;;
            -s|--start) DO_SERVICES=true; shift ;;
            -a|--all) DO_ALL=true; shift ;;
            --clone) DO_CLONE=true; shift ;;
            --firewall) DO_FIREWALL=true; shift ;;
            --offline=*) OFFLINE_PACKAGE_DIR="${1#*=}"; shift ;;
            *) shift ;;
        esac
    done
    
    if [ "$DO_CHECK" = true ]; then
        check_environment
        exit 0
    fi
    
    if [ "$DO_ALL" = true ] || [ "$DO_DEPS" = true ]; then
        check_root
    fi
    
    if [ "$DO_ALL" = true ] || [ "$DO_DEPS" = true ]; then
        check_environment
        install_system_deps
    fi
    
    if [ "$DO_ALL" = true ] || [ "$DO_RUNTIME" = true ]; then
        install_go
        install_nodejs
    fi
    
    if [ "$DO_ALL" = true ] || [ "$DO_PROTOBUF" = true ]; then
        install_protobuf
    fi
    
    if [ "$DO_ALL" = true ] || [ "$DO_MYSQL" = true ]; then
        install_mysql
    fi
    
    if [ "$DO_ALL" = true ] || [ "$DO_REDIS" = true ]; then
        install_redis
    fi
    
    if [ "$DO_ALL" = true ] || [ "$DO_CLONE" = true ]; then
        create_deploy_user
        clone_repository
    fi
    
    if [ "$DO_ALL" = true ] || [ "$DO_CONFIG" = true ]; then
        configure_database
        configure_project
        create_systemd_service
    fi
    
    if [ "$DO_ALL" = true ] || [ "$DO_DATABASE" = true ]; then
        init_database
    fi
    
    if [ "$DO_ALL" = true ] || [ "$DO_BACKEND" = true ]; then
        build_backend
    fi
    
    if [ "$DO_ALL" = true ] || [ "$DO_FRONTEND" = true ]; then
        install_front_deps
    fi
    
    if [ "$DO_ALL" = true ] || [ "$DO_SERVICES" = true ]; then
        start_services
        check_services
    fi
    
    if [ "$DO_ALL" = true ] || [ "$DO_FIREWALL" = true ]; then
        configure_firewall
    fi
    
    if [ "$DO_ALL" = true ]; then
        echo ""
        echo "=========================================="
        echo "部署完成！"
        echo "=========================================="
        echo ""
        echo "访问信息:"
        echo "  前端: http://192.168.23.131:${HTTP_PORT}"
        echo "  后端 API: http://192.168.23.131:${HTTP_PORT}/api/v1"
        echo "  WebSocket: ws://192.168.23.131:${WS_PORT}"
        echo ""
        echo "服务管理命令:"
        echo "  sudo systemctl status lumenim-backend"
        echo "  sudo systemctl status lumenim-frontend"
        echo "  sudo systemctl restart lumenim-backend"
        echo ""
        echo "日志查看:"
        echo "  sudo journalctl -u lumenim-backend -f"
        echo "  sudo journalctl -u lumenim-frontend -f"
        echo ""
    fi
}

main "$@"
