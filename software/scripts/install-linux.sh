#!/bin/bash
#
# LumenIM Linux 环境自动化部署脚本
# Automated deployment script for LumenIM Linux environment
#
# 使用方法: sudo ./install-linux.sh [选项]
# Usage: sudo ./install-linux.sh [options]
#
# 版本: 1.0.0
# 更新日期: 2026-04-08

set -e

# ============================================================
# 配置区域 - 根据服务器环境修改
# ============================================================

# 安装根目录
INSTALL_ROOT="/opt/lumenim"

# 项目目录
PROJECT_DIR="/var/www/lumenim"

# 数据目录
DATA_DIR="/var/lib/lumenim"

# 运行用户（请根据实际修改）
RUN_USER="root"

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
REDIS_PASSWORD="lumenimadmin"

# JWT 配置
JWT_SECRET="836c3fea9bba4e04d51bd0fbcc5"

# 服务启动方式: native | systemd | docker
SERVICE_MANAGER="systemd"

# 下载源配置（离线包目录）
OFFLINE_PACKAGE_DIR=""

# ============================================================
# 版本定义
# ============================================================

GO_VERSION="1.25.0"
NODE_VERSION="22.14.0"
MYSQL_VERSION="8.0.40"
REDIS_VERSION="7.4.3"
PROTOBUF_VERSION="25.1"

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
        log_warn "命令 '$1' 未找到"
        return 1
    fi
    return 0
}

install_package() {
    local pkg="$1"
    log_info "安装软件包: $pkg"
    
    if check_command apt-get; then
        apt-get install -y "$pkg"
    elif check_command yum; then
        yum install -y "$pkg"
    elif check_command dnf; then
        dnf install -y "$pkg"
    elif check_command apk; then
        apk add --no-cache "$pkg"
    else
        log_error "不支持的包管理器"
        return 1
    fi
}

create_user() {
    local user="$1"
    if ! id "$user" &> /dev/null; then
        log_info "创建用户: $user"
        useradd -r -s /bin/false -d /nonexistent -c "LumenIM Service" "$user" 2>/dev/null || true
    fi
}

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

backup_file() {
    local file="$1"
    if [ -f "$file" ]; then
        local backup="${file}.bak.$(date +%Y%m%d%H%M%S)"
        log_info "备份文件: $file -> $backup"
        cp -p "$file" "$backup"
    fi
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
    
    # 检查操作系统
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        log_info "操作系统: $NAME $VERSION"
    else
        log_info "操作系统: $(uname -s)"
    fi
    
    # 检查架构
    log_info "系统架构: $(uname -m)"
    
    # 检查内核版本
    log_info "内核版本: $(uname -r)"
    
    # 检查内存
    log_info "总内存: $(free -h | awk '/^Mem:/{print $2}')"
    
    # 检查磁盘空间
    log_info "可用空间: $(df -h / | awk 'NR==2{print $4}')"
    
    # 检查是否 root
    if [ "$EUID" -eq 0 ]; then
        log_success "Root 权限: 已确认"
    else
        log_warn "Root 权限: 未确认（非 root 运行）"
    fi
    
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
    
    if check_command apt-get; then
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
    elif check_command yum; then
        install_package " gcc gcc-c++ make"
        install_package "wget"
        install_package "git"
        install_package "unzip"
        install_package "tar"
        install_package "xz"
        install_package "ca-certificates"
        install_package "jq"
        install_package "net-tools"
        install_package "lsof"
    fi
    
    log_success "系统依赖安装完成"
}

# ============================================================
# 安装 Go 环境
# ============================================================

install_go() {
    log_step "安装 Go 环境..."
    
    local go_tarball="${OFFLINE_PACKAGE_DIR}/go${GO_VERSION}.linux-amd64.tar.gz"
    local go_dir="${INSTALL_ROOT}/go"
    local go_link="/usr/local/go"
    
    # 检查是否已安装
    if [ -f "$go_link/bin/go" ]; then
        local current_version=$("$go_link/bin/go" version 2>/dev/null | grep -oP 'go\d+\.\d+\.\d+' || true)
        if [ "$current_version" = "go${GO_VERSION}" ]; then
            log_info "Go ${GO_VERSION} 已安装"
            return 0
        fi
    fi
    
    # 从离线包安装
    if [ -f "$go_tarball" ]; then
        log_info "从离线包安装 Go: $go_tarball"
        tar -xzf "$go_tarball" -C /tmp/
        rm -rf "$go_link"
        mv "/tmp/go" "$go_link"
    else
        # 在线安装
        log_info "在线安装 Go ${GO_VERSION}..."
        cd /tmp
        wget -q "https://go.dev/dl/go${GO_VERSION}.linux-amd64.tar.gz" -O go.tar.gz
        tar -xzf go.tar.gz -C /tmp/
        rm -rf "$go_link"
        mv /tmp/go "$go_link"
        rm -f go.tar.gz
    fi
    
    # 配置环境变量
    if ! grep -q '/usr/local/go/bin' /etc/profile.d/go.sh 2>/dev/null; then
        cat > /etc/profile.d/go.sh << EOF
export GOROOT=/usr/local/go
export PATH=\$PATH:\$GOROOT/bin
export GOPATH=\$HOME/go
EOF
        chmod +x /etc/profile.d/go.sh
    fi
    
    # 设置当前会话环境变量
    export GOROOT=/usr/local/go
    export PATH=$PATH:$GOROOT/bin
    export GOPATH=$HOME/go
    
    log_success "Go ${GO_VERSION} 安装完成"
    "$go_link/bin/go" version
}

# ============================================================
# 安装 Node.js 环境
# ============================================================

install_nodejs() {
    log_step "安装 Node.js 环境..."
    
    local node_tarball="${OFFLINE_PACKAGE_DIR}/node-v${NODE_VERSION}-linux-x64.tar.xz"
    local node_dir="${INSTALL_ROOT}/nodejs"
    local node_link="/usr/local/node"
    
    # 检查是否已安装
    if [ -f "$node_link/bin/node" ]; then
        local current_version=$("$node_link/bin/node" --version 2>/dev/null || true)
        if [ "$current_version" = "v${NODE_VERSION}" ]; then
            log_info "Node.js ${NODE_VERSION} 已安装"
            return 0
        fi
    fi
    
    # 从离线包安装
    if [ -f "$node_tarball" ]; then
        log_info "从离线包安装 Node.js: $node_tarball"
        tar -xJf "$node_tarball" -C /tmp/
        rm -rf "$node_link"
        mv "/tmp/node-v${NODE_VERSION}-linux-x64" "$node_link"
    else
        # 在线安装
        log_info "在线安装 Node.js ${NODE_VERSION}..."
        cd /tmp
        wget -q "https://nodejs.org/dist/v${NODE_VERSION}/node-v${NODE_VERSION}-linux-x64.tar.xz" -O node.tar.xz
        tar -xJf node.tar.xz -C /tmp/
        rm -rf "$node_link"
        mv /tmp/node-v${NODE_VERSION}-linux-x64 "$node_link"
        rm -f node.tar.xz
    fi
    
    # 配置环境变量
    if ! grep -q '/usr/local/node/bin' /etc/profile.d/nodejs.sh 2>/dev/null; then
        cat > /etc/profile.d/nodejs.sh << EOF
export NODE_PREFIX=/usr/local/node
export PATH=\$PATH:\$NODE_PREFIX/bin
EOF
        chmod +x /etc/profile.d/nodejs.sh
    fi
    
    # 设置当前会话环境变量
    export NODE_PREFIX=/usr/local/node
    export PATH=$PATH:$NODE_PREFIX/bin
    
    log_success "Node.js ${NODE_VERSION} 安装完成"
    "$node_link/bin/node" --version
    
    # 安装 pnpm
    log_info "安装 pnpm..."
    "$node_link/bin/node" -e "require('global').npm.config.set('prefix', '$node_link')" 2>/dev/null || true
    npm install -g pnpm@10.0.0 || true
    
    log_success "pnpm 安装完成"
}

# ============================================================
# 安装 MySQL
# ============================================================

install_mysql() {
    log_step "安装 MySQL..."
    
    local mysql_tarball="${OFFLINE_PACKAGE_DIR}/mysql-${MYSQL_VERSION}-linux-glibc2.28-x86_64.tar.gz"
    local mysql_dir="${INSTALL_ROOT}/mysql"
    
    # 检查包管理器安装
    if check_command apt-get; then
        log_info "通过 apt-get 安装 MySQL..."
        export DEBIAN_FRONTEND=noninteractive
        apt-get install -y mysql-server
    else
        # 从离线包安装
        if [ -f "$mysql_tarball" ]; then
            log_info "从离线包安装 MySQL: $mysql_tarball"
            cd /tmp
            tar -xzf "$mysql_tarball"
            rm -rf "$mysql_dir"
            mkdir -p "$mysql_dir"
            mv mysql-${MYSQL_VERSION}-linux-glibc2.28-x86_64/* "$mysql_dir/"
        fi
    fi
    
    log_success "MySQL 安装完成"
}

# ============================================================
# 安装 Redis
# ============================================================

install_redis() {
    log_step "安装 Redis..."
    
    local redis_dir="${INSTALL_ROOT}/redis"
    
    # 检查包管理器安装
    if check_command apt-get; then
        log_info "通过 apt-get 安装 Redis..."
        apt-get install -y redis-server
    else
        # 从源码编译安装
        log_info "从源码编译安装 Redis..."
        cd /tmp
        
        if [ ! -f "redis-${REDIS_VERSION}.tar.gz" ]; then
            wget -q "https://github.com/redis/redis/archive/refs/tags/${REDIS_VERSION}.tar.gz" -O redis.tar.gz
        fi
        
        tar -xzf redis.tar.gz
        cd "redis-${REDIS_VERSION}"
        make -j$(nproc)
        make install PREFIX="$redis_dir"
    fi
    
    log_success "Redis 安装完成"
}

# ============================================================
# 安装 Protocol Buffers
# ============================================================

install_protobuf() {
    log_step "安装 Protocol Buffers..."
    
    local protoc_zip="${OFFLINE_PACKAGE_DIR}/protoc-${PROTOBUF_VERSION}-linux-x86_64.zip"
    local protoc_dir="${INSTALL_ROOT}/protobuf"
    
    # 从离线包安装
    if [ -f "$protoc_zip" ]; then
        log_info "从离线包安装 Protocol Buffers: $protoc_zip"
        unzip -qo "$protoc_zip" -d "$protoc_dir"
    else
        # 在线安装
        log_info "在线安装 Protocol Buffers ${PROTOBUF_VERSION}..."
        mkdir -p "$protoc_dir"
        cd /tmp
        wget -q "https://github.com/protocolbuffers/protobuf/releases/download/v${PROTOBUF_VERSION}/protoc-${PROTOBUF_VERSION}-linux-x86_64.zip" -O protoc.zip
        unzip -qo protoc.zip -d "$protoc_dir"
        rm -f protoc.zip
    fi
    
    # 移动到系统目录
    if [ -f "$protoc_dir/bin/protoc" ]; then
        cp -f "$protoc_dir/bin/protoc" /usr/local/bin/
    fi
    
    log_success "Protocol Buffers 安装完成"
    /usr/local/bin/protoc --version
}

# ============================================================
# 安装 Go 依赖
# ============================================================

install_go_deps() {
    log_step "安装 Go 项目依赖..."
    
    if [ ! -d "$PROJECT_DIR" ]; then
        log_error "项目目录不存在: $PROJECT_DIR"
        return 1
    fi
    
    cd "$PROJECT_DIR/backend"
    
    # 安装 protobuf 插件
    log_info "安装 protobuf 插件..."
    go install google.golang.org/protobuf/cmd/protoc-gen-go@latest
    go install github.com/envoyproxy/protoc-gen-validate@latest
    
    # 下载项目依赖
    log_info "下载项目依赖..."
    go mod download
    
    log_success "Go 依赖安装完成"
}

# ============================================================
# 安装前端依赖
# ============================================================

install_front_deps() {
    log_step "安装前端依赖..."
    
    if [ ! -d "$PROJECT_DIR" ]; then
        log_error "项目目录不存在: $PROJECT_DIR"
        return 1
    fi
    
    cd "$PROJECT_DIR/front"
    
    # 安装依赖
    log_info "安装前端依赖..."
    pnpm install
    
    log_success "前端依赖安装完成"
}

# ============================================================
# 配置服务
# ============================================================

configure_services() {
    log_step "配置服务..."
    
    create_directory "$INSTALL_ROOT"
    create_directory "$PROJECT_DIR"
    create_directory "$DATA_DIR"
    create_user "$RUN_USER"
    
    # 配置 MySQL
    if check_command mysql; then
        log_info "配置 MySQL..."
        cat > /etc/mysql/conf.d/lumenim.cnf << EOF
[mysqld]
character-set-server = utf8mb4
collation-server = utf8mb4_general_ci
max_connections = 1000
innodb_buffer_pool_size = 256M
EOF
    fi
    
    # 配置 Redis
    if check_command redis-server; then
        log_info "配置 Redis..."
        cat > /etc/redis/lumenim.conf << EOF
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
EOF
    fi
    
    log_success "服务配置完成"
}

# ============================================================
# 创建 systemd 服务
# ============================================================

create_systemd_service() {
    log_step "创建 systemd 服务..."
    
    # 后端服务
    cat > /etc/systemd/system/lumenim-backend.service << EOF
[Unit]
Description=LumenIM Backend Service
After=network.target mysql.service redis.service

[Service]
Type=simple
User=$RUN_USER
Group=$RUN_USER
WorkingDirectory=$PROJECT_DIR/backend
Environment="PATH=/usr/local/go/bin:/usr/local/node/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
Environment="PORT=$HTTP_PORT"
ExecStart=$PROJECT_DIR/backend/bin/lumenim
Restart=on-failure
RestartSec=5s
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF

    # 前端服务
    cat > /etc/systemd/system/lumenim-frontend.service << EOF
[Unit]
Description=LumenIM Frontend Service
After=network.target

[Service]
Type=simple
User=$RUN_USER
Group=$RUN_USER
WorkingDirectory=$PROJECT_DIR/front
Environment="PATH=/usr/local/node/bin:\$PATH"
ExecStart=/usr/local/node/bin/vite --port 5173
Restart=on-failure
RestartSec=5s

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
    
    # 启动 MySQL
    if check_command systemctl; then
        log_info "启动 MySQL..."
        systemctl start mysql 2>/dev/null || true
        systemctl enable mysql 2>/dev/null || true
    fi
    
    # 启动 Redis
    log_info "启动 Redis..."
    redis-server --daemonize yes 2>/dev/null || true
    systemctl start redis 2>/dev/null || true
    systemctl enable redis 2>/dev/null || true
    
    # 启动后端服务
    log_info "启动后端服务..."
    systemctl start lumenim-backend
    systemctl enable lumenim-backend
    
    # 启动前端服务
    log_info "启动前端服务..."
    systemctl start lumenim-frontend
    systemctl enable lumenim-frontend
    
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
    
    # 检查端口
    log_info "检查端口占用..."
    for port in $HTTP_PORT $WS_PORT $TCP_PORT $MYSQL_PORT $REDIS_PORT; do
        if lsof -i:$port &>/dev/null; then
            log_success "端口 $port: 已占用"
        else
            log_warn "端口 $port: 未占用"
        fi
    done
    
    # 检查进程
    log_info "检查进程..."
    pgrep -f lumenim >/dev/null && log_success "后端进程: 运行中" || log_warn "后端进程: 未运行"
    pgrep -f vite >/dev/null && log_success "前端进程: 运行中" || log_warn "前端进程: 未运行"
    
    # 检查 MySQL
    if check_command mysql; then
        mysql -u root -p"$MYSQL_ROOT_PASSWORD" -e "SELECT 1" &>/dev/null && \
            log_success "MySQL: 正常" || log_warn "MySQL: 异常"
    fi
    
    # 检查 Redis
    if check_command redis-cli; then
        redis-cli ping &>/dev/null && \
            log_success "Redis: 正常" || log_warn "Redis: 异常"
    fi
}

# ============================================================
# 防火墙配置
# ============================================================

configure_firewall() {
    log_step "配置防火墙..."
    
    if check_command firewall-cmd; then
        log_info "配置 firewalld..."
        firewall-cmd --permanent --add-port=${HTTP_PORT}/tcp
        firewall-cmd --permanent --add-port=${WS_PORT}/tcp
        firewall-cmd --permanent --add-port=${TCP_PORT}/tcp
        firewall-cmd --reload
    elif check_command ufw; then
        log_info "配置 ufw..."
        ufw allow ${HTTP_PORT}/tcp
        ufw allow ${WS_PORT}/tcp
        ufw allow ${TCP_PORT}/tcp
    fi
    
    log_success "防火墙配置完成"
}

# ============================================================
# 显示帮助
# ============================================================

show_help() {
    cat << EOF
LumenIM Linux 自动化部署脚本

使用方法:
    sudo ./install-linux.sh [选项]

选项:
    -h, --help              显示帮助信息
    -c, --check            仅检查环境
    -d, --deps             仅安装系统依赖
    -g, --go              仅安装 Go
    -n, --node            仅安装 Node.js
    -m, --mysql           仅安装 MySQL
    -r, --redis           仅安装 Redis
    -p, --protobuf        仅安装 Protocol Buffers
    -b, --backend         仅配置后端
    -f, --frontend        仅配置前端
    -s, --services        仅启动服务
    -a, --all             完整安装（默认）
    --offline=[目录]      离线包目录

示例:
    # 完整安装
    sudo ./install-linux.sh --all

    # 使用离线包安装
    sudo ./install-linux.sh --all --offline=/tmp/packages

    # 仅安装运行时环境
    sudo ./install-linux.sh --go --node --mysql --redis

    # 仅启动服务
    sudo ./install-linux.sh --services

    # 检查环境
    sudo ./install-linux.sh --check

EOF
}

# ============================================================
# 主函数
# ============================================================

main() {
    echo "=========================================="
    echo "LumenIM 自动化部署脚本"
    echo "=========================================="
    echo ""
    
    # 解析参数
    DO_CHECK=false
    DO_DEPS=false
    DO_GO=false
    DO_NODE=false
    DO_MYSQL=false
    DO_REDIS=false
    DO_PROTOBUF=false
    DO_BACKEND=false
    DO_FRONTEND=false
    DO_SERVICES=false
    DO_ALL=false
    
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                show_help
                exit 0
                ;;
            -c|--check)
                DO_CHECK=true
                shift
                ;;
            -d|--deps)
                DO_DEPS=true
                shift
                ;;
            -g|--go)
                DO_GO=true
                shift
                ;;
            -n|--node)
                DO_NODE=true
                shift
                ;;
            -m|--mysql)
                DO_MYSQL=true
                shift
                ;;
            -r|--redis)
                DO_REDIS=true
                shift
                ;;
            -p|--protobuf)
                DO_PROTOBUF=true
                shift
                ;;
            -b|--backend)
                DO_BACKEND=true
                shift
                ;;
            -f|--frontend)
                DO_FRONTEND=true
                shift
                ;;
            -s|--services)
                DO_SERVICES=true
                shift
                ;;
            -a|--all)
                DO_ALL=true
                shift
                ;;
            --offline=*)
                OFFLINE_PACKAGE_DIR="${1#*=}"
                shift
                ;;
            *)
                shift
                ;;
        esac
    done
    
    # 检查环境
    if [ "$DO_CHECK" = true ]; then
        check_environment
        exit 0
    fi
    
    # 检查 root
    if [ "$DO_ALL" = true ]; then
        check_root
    fi
    
    # 执行任务
    if [ "$DO_ALL" = true ] || [ "$DO_DEPS" = true ]; then
        check_environment
        install_system_deps
    fi
    
    if [ "$DO_ALL" = true ] || [ "$DO_GO" = true ]; then
        install_go
    fi
    
    if [ "$DO_ALL" = true ] || [ "$DO_NODE" = true ]; then
        install_nodejs
    fi
    
    if [ "$DO_ALL" = true ] || [ "$DO_MYSQL" = true ]; then
        install_mysql
    fi
    
    if [ "$DO_ALL" = true ] || [ "$DO_REDIS" = true ]; then
        install_redis
    fi
    
    if [ "$DO_ALL" = true ] || [ "$DO_PROTOBUF" = true ]; then
        install_protobuf
    fi
    
    if [ "$DO_ALL" = true ]; then
        configure_services
        create_systemd_service
    fi
    
    if [ "$DO_ALL" = true ] || [ "$DO_BACKEND" = true ]; then
        install_go_deps
    fi
    
    if [ "$DO_ALL" = true ] || [ "$DO_FRONTEND" = true ]; then
        install_front_deps
    fi
    
    if [ "$DO_ALL" = true ] || [ "$DO_SERVICES" = true ]; then
        start_services
        check_services
    fi
    
    if [ "$DO_ALL" = true ]; then
        configure_firewall
    fi
    
    echo ""
    log_success "部署完成！"
    echo ""
    echo "=========================================="
    echo "访问信息"
    echo "=========================================="
    echo "前端: http://localhost:${HTTP_PORT}"
    echo "后端 API: http://localhost:${HTTP_PORT}"
    echo "WebSocket: ws://localhost:${WS_PORT}"
    echo ""
}

# 执行主函数
main "$@"