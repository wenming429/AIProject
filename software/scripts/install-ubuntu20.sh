#!/bin/bash
#
# LumenIM Ubuntu 20.04 自动化部署脚本
# LumenIM Ubuntu 20.04 Automated Deployment Script
#
# 使用方法: sudo ./install-ubuntu20.sh [选项]
# Usage: sudo ./install-ubuntu20.sh [options]
#
# 版本: 3.0.0
# 更新日期: 2026-04-21
# 目标服务器: 192.168.23.131
# 部署用户: wenming429

set -e

# ============================================================
# 服务器配置 - 请根据实际环境修改
# ============================================================

# 服务器 IP
SERVER_IP="192.168.23.131"

# 代码仓库地址
GIT_REPO="https://github.com/wenming429/AIProject.git"

# Git 分支（默认为 master）
GIT_BRANCH="master"

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
MINIO_API_PORT=9000
MINIO_CONSOLE_PORT=9090
NGINX_HTTP_PORT=80
NGINX_HTTPS_PORT=443

# MySQL 配置
MYSQL_ROOT_PASSWORD="lumenim123"
MYSQL_DATABASE="go_chat"
MYSQL_USER="lumenim"
MYSQL_PASSWORD="lumenim123"

# Redis 配置
REDIS_PASSWORD=""

# MinIO 配置
MINIO_ROOT_USER="minioadmin"
MINIO_ROOT_PASSWORD="minioadmin123"

# JWT 配置
JWT_SECRET="836c3fea9bba4e04d51bd0fbcc5"

# 服务启动方式
SERVICE_MANAGER="systemd"
USE_DOCKER=false

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
DOCKER_VERSION="26.1.0"
DOCKER_COMPOSE_VERSION="2.24.0"

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
    echo "服务器信息"
    echo "=========================================="
    echo "目标 IP: $SERVER_IP"
    
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
    
    # 检查 IP 配置
    if ip addr show | grep -q "$SERVER_IP"; then
        log_success "服务器 IP $SERVER_IP 已配置"
    else
        log_warn "未检测到 IP $SERVER_IP，当前网络接口:"
        ip addr show | grep "inet " | head -5
    fi
    
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
    
    check_command docker && log_success "Docker: $(docker --version | grep -oP '\d+\.\d+\.\d+')" || log_warn "Docker: 未安装"
    check_command docker-compose && log_success "Docker Compose: $(docker-compose --version | grep -oP '\d+\.\d+')" || log_warn "Docker Compose: 未安装"
    check_command go && log_success "Go: $(go version | grep -oP 'go\d+\.\d+\.\d+')" || log_warn "Go: 未安装"
    check_command node && log_success "Node.js: $(node --version)" || log_warn "Node.js: 未安装"
    check_command pnpm && log_success "pnpm: $(pnpm --version)" || log_warn "pnpm: 未安装"
    check_command mysql && log_success "MySQL: 已安装" || log_warn "MySQL: 未安装"
    check_command redis-server && log_success "Redis: 已安装" || log_warn "Redis: 未安装"
    check_command protoc && log_success "Protobuf: $(protoc --version)" || log_warn "Protobuf: 未安装"
    
    echo ""
    echo "=========================================="
    echo "端口占用检查"
    echo "=========================================="
    
    for port in $NGINX_HTTP_PORT $NGINX_HTTPS_PORT $MYSQL_PORT $REDIS_PORT $MINIO_API_PORT $MINIO_CONSOLE_PORT $HTTP_PORT $WS_PORT; do
        if lsof -i:$port &>/dev/null; then
            log_warn "端口 $port: 已被占用"
        else
            log_success "端口 $port: 可用"
        fi
    done
    
    echo ""
    log_success "环境检查完成"
}

# ============================================================
# 安装 Docker
# ============================================================

install_docker() {
    log_step "安装 Docker Engine..."
    
    if check_command docker; then
        log_info "Docker 已安装，跳过"
        return 0
    fi
    
    log_info "卸载旧版本..."
    apt-get remove -y docker docker-engine docker.io containerd runc 2>/dev/null || true
    apt-get autoremove -y 2>/dev/null || true
    
    log_info "安装依赖包..."
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -qq
    apt-get install -y ca-certificates curl gnupg lsb-release
    
    log_info "添加 Docker GPG 密钥..."
    sudo mkdir -p /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    
    log_info "添加 Docker 仓库..."
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
      $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    log_info "安装 Docker..."
    apt-get update -qq
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    
    log_info "配置 Docker 镜像加速器..."
    sudo mkdir -p /etc/docker
    cat > /etc/docker/daemon.json <<'EOF'
{
  "registry-mirrors": [
    "https://docker.1ms.run",
    "https://docker.xuanyuan.me",
    "https://docker.m.daocloud.io",
    "https://docker.mirrors.ustc.edu.cn",
    "https://hub-mirror.c.163.com"
  ],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m",
    "max-file": "5"
  },
  "storage-driver": "overlay2",
  "live-restore": true,
  "default-address-pools": [
    {
      "base": "172.17.0.0/16",
      "size": 24
    }
  ],
  "dns": ["8.8.8.8", "114.114.114.114"]
}
EOF
    
    log_info "启动 Docker 服务..."
    systemctl daemon-reload
    systemctl start docker
    systemctl enable docker
    
    log_success "Docker 安装完成: $(docker --version)"
}

# ============================================================
# 安装 Docker Compose
# ============================================================

install_docker_compose() {
    log_step "安装 Docker Compose..."
    
    if check_command docker && docker compose version &>/dev/null; then
        log_info "Docker Compose (V2) 已安装: $(docker compose version)"
        return 0
    fi
    
    if check_command docker-compose; then
        log_info "Docker Compose 已安装，跳过"
        return 0
    fi
    
    log_info "下载 Docker Compose V2..."
    DOCKER_COMPOSE_PLUGINS_DIR="/usr/lib/docker/cli-plugins"
    sudo mkdir -p "$DOCKER_COMPOSE_PLUGINS_DIR"
    
    curl -SL "https://github.com/docker/compose/releases/download/v${DOCKER_COMPOSE_VERSION}/docker-compose-linux-x86_64" \
        -o /tmp/docker-compose
    chmod +x /tmp/docker-compose
    sudo mv /tmp/docker-compose "$DOCKER_COMPOSE_PLUGINS_DIR/docker-compose"
    sudo ln -sf "$DOCKER_COMPOSE_PLUGINS_DIR/docker-compose" /usr/local/bin/docker-compose
    
    log_success "Docker Compose 安装完成: $(docker compose version)"
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
    install_package "vim"
    install_package "htop"
    
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
    log_success "pnpm 安装完成: $(pnpm --version)"
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
    
    # MySQL 8.0 on Ubuntu 20.04 使用 auth_socket 插件
    # 需要先配置 root 用户使用密码认证
    log_info "配置 MySQL root 用户密码认证..."
    
    # 方法1: 使用 sudo mysql（绕过 auth_socket，适用于首次配置）
    if sudo mysql -e "ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY '$MYSQL_ROOT_PASSWORD';" 2>/dev/null; then
        log_info "Root 密码设置成功"
    elif sudo mysql -e "ALTER USER 'root'@'localhost' IDENTIFIED BY '$MYSQL_ROOT_PASSWORD';" 2>/dev/null; then
        log_info "Root 密码设置成功 (方式2)"
    else
        # 方法2: 如果 sudo 方式失败，尝试使用 auth_socket 直接操作
        log_warn "尝试备用配置方式..."
        sudo mysql << 'EOSQL'
ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY 'lumenim123';
EOSQL
    fi
    
    sleep 2
    
    log_info "创建数据库和用户..."
    
    # 使用 --login-path 或 stdin 方式传递密码（更可靠）
    # 方式A: 使用 --password= 格式（推荐）
    if mysql -u root --password="$MYSQL_ROOT_PASSWORD" -e "SELECT 1;" &>/dev/null; then
        log_info "使用密码认证连接成功"
        
        mysql -u root --password="$MYSQL_ROOT_PASSWORD" << EOSQL
CREATE DATABASE IF NOT EXISTS ${MYSQL_DATABASE} CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;
CREATE USER IF NOT EXISTS '${MYSQL_USER}'@'localhost' IDENTIFIED BY '${MYSQL_PASSWORD}';
CREATE USER IF NOT EXISTS '${MYSQL_USER}'@'%' IDENTIFIED BY '${MYSQL_PASSWORD}';
GRANT ALL PRIVILEGES ON ${MYSQL_DATABASE}.* TO '${MYSQL_USER}'@'localhost';
GRANT ALL PRIVILEGES ON ${MYSQL_DATABASE}.* TO '${MYSQL_USER}'@'%';
FLUSH PRIVILEGES;
EOSQL
        MYSQL_AUTH_OK=true
    else
        # 方式B: 使用 sudo mysql（auth_socket 认证）
        log_warn "密码认证失败，尝试 auth_socket 方式..."
        
        sudo mysql << 'EOSQL'
CREATE DATABASE IF NOT EXISTS go_chat CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;
CREATE USER IF NOT EXISTS 'lumenim'@'localhost' IDENTIFIED BY 'lumenim123';
CREATE USER IF NOT EXISTS 'lumenim'@'%' IDENTIFIED BY 'lumenim123';
GRANT ALL PRIVILEGES ON go_chat.* TO 'lumenim'@'localhost';
GRANT ALL PRIVILEGES ON go_chat.* TO 'lumenim'@'%';
FLUSH PRIVILEGES;
EOSQL
        MYSQL_AUTH_OK=true
    fi
    
    # 导入数据库表结构
    if [ -f "$PROJECT_DIR/backend/sql/init.sql" ]; then
        log_info "导入数据库表结构..."
        
        if [ "$MYSQL_AUTH_OK" = true ] && mysql -u root --password="$MYSQL_ROOT_PASSWORD" -e "SELECT 1;" &>/dev/null; then
            mysql -u root --password="$MYSQL_ROOT_PASSWORD" "$MYSQL_DATABASE" < "$PROJECT_DIR/backend/sql/init.sql" && \
            log_success "表结构导入成功"
        else
            sudo mysql "$MYSQL_DATABASE" < "$PROJECT_DIR/backend/sql/init.sql" && \
            log_success "表结构导入成功 (sudo)"
        fi
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
    
    usermod -aG docker "$RUN_USER" 2>/dev/null || true
    usermod -aG sudo "$RUN_USER"
    echo "$RUN_USER ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/$RUN_USER
    chmod 440 /etc/sudoers.d/$RUN_USER
    log_success "用户配置完成"
}

# ============================================================
# 下载代码
# ============================================================

clone_repository() {
    log_step "克隆代码仓库..."
    
    log_info "仓库地址: $GIT_REPO"
    log_info "目标目录: $PROJECT_DIR"
    
    if [ -d "$PROJECT_DIR" ]; then
        # 检查是否是 Git 仓库
        if [ -d "$PROJECT_DIR/.git" ] || git -C "$PROJECT_DIR" rev-parse --git-dir &>/dev/null; then
            log_warn "项目目录已存在且是 Git 仓库: $PROJECT_DIR"
            read -p "是否更新代码? (y/n): " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                cd "$PROJECT_DIR"
                log_info "执行 git pull origin master..."
                git pull origin master
                log_success "代码更新完成"
            else
                log_info "跳过代码更新"
            fi
        else
            log_warn "项目目录已存在但不是 Git 仓库: $PROJECT_DIR"
            read -p "是否删除并重新克隆? (y/n): " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                log_info "删除旧目录..."
                rm -rf "$PROJECT_DIR"
                log_info "克隆代码仓库..."
                git clone -b "$GIT_BRANCH" --single-branch "$GIT_REPO" "$PROJECT_DIR" || {
                    log_error "克隆失败，请检查:"
                    log_error "  1. 仓库地址是否正确"
                    log_error "  2. 网络连接是否正常"
                    log_error "  3. 仓库是否公开或访问权限"
                    log_error "  4. 分支 '$GIT_BRANCH' 是否存在"
                    return 1
                }
                chown -R "$RUN_USER:$RUN_USER" "$PROJECT_DIR"
                log_success "代码克隆完成"
            else
                log_info "跳过代码克隆，使用现有目录"
            fi
        fi
    else
        log_info "开始克隆代码仓库..."
        log_info "分支: $GIT_BRANCH"
        git clone -b "$GIT_BRANCH" --single-branch "$GIT_REPO" "$PROJECT_DIR" || {
            log_error "克隆失败，请检查:"
            log_error "  1. 仓库地址是否正确: $GIT_REPO"
            log_error "  2. 网络连接是否正常"
            log_error "  3. 仓库是否公开或访问权限"
            log_error "  4. 分支 '$GIT_BRANCH' 是否存在"
            echo ""
            echo "如果是私有仓库，请先配置 Git 凭据:"
            echo "  git config --global credential.helper store"
            echo "  git clone -b $GIT_BRANCH --single-branch $GIT_REPO"
            return 1
        }
        chown -R "$RUN_USER:$RUN_USER" "$PROJECT_DIR"
        log_success "代码克隆完成"
    fi
    
    # 验证克隆结果
    log_info "验证仓库内容..."
    if [ -f "$PROJECT_DIR/backend/go.mod" ]; then
        log_success "go.mod 文件验证通过"
    else
        log_error "go.mod 文件不存在，克隆可能不完整"
        log_error "请检查仓库是否包含 backend 目录"
        echo ""
        echo "当前仓库结构:"
        find "$PROJECT_DIR" -maxdepth 2 -type d 2>/dev/null | head -20
        return 1
    fi
}

# ============================================================
# 配置项目
# ============================================================

configure_project() {
    log_step "配置项目..."
    
    create_directory "$INSTALL_ROOT" "root" "755"
    create_directory "$PROJECT_DIR" "$RUN_USER" "755"
    create_directory "$DATA_DIR" "$RUN_USER" "755"
    
    # 创建后端目录结构
    create_directory "$PROJECT_DIR/backend/runtime" "$RUN_USER" "755"
    create_directory "$PROJECT_DIR/backend/uploads" "$RUN_USER" "755"
    create_directory "$PROJECT_DIR/backend/sql" "$RUN_USER" "755"
    create_directory "$DATA_DIR/mysql" "$RUN_USER" "755"
    create_directory "$DATA_DIR/redis" "$RUN_USER" "755"
    create_directory "$DATA_DIR/minio" "$RUN_USER" "755"
    
    log_info "配置后端 config.yaml..."
    cat > "$PROJECT_DIR/backend/config.yaml" << EOF
server:
  http_addr: ":${HTTP_PORT}"
  websocket_addr: ":${WS_PORT}"
  tcp_addr: ":${TCP_PORT}"

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

filesystem:
  default: minio
  minio:
    endpoint: "${SERVER_IP}:${MINIO_API_PORT}"
    secret_id: "${MINIO_ROOT_USER}"
    secret_key: "${MINIO_ROOT_PASSWORD}"
EOF
    
    log_info "配置前端环境变量..."
    mkdir -p "$PROJECT_DIR/front"
    cat > "$PROJECT_DIR/front/.env.production" << EOF
VITE_APP_TITLE=LumenIM
VITE_API_BASE_URL=http://${SERVER_IP}/api/v1
VITE_WS_URL=ws://${SERVER_IP}/ws
VITE_UPLOAD_URL=http://${SERVER_IP}/api/v1/upload
EOF
    
    chown -R "$RUN_USER:$RUN_USER" "$PROJECT_DIR"
    log_success "项目配置完成"
}

# ============================================================
# 配置 Docker Compose 项目
# ============================================================

configure_docker_compose() {
    log_step "配置 Docker Compose 项目..."
    
    create_directory "$PROJECT_DIR/docker" "$RUN_USER" "755"
    create_directory "$DATA_DIR/mysql" "999:999" "755"
    create_directory "$DATA_DIR/redis" "999:999" "755"
    create_directory "$DATA_DIR/minio" "1000:1000" "755"
    
    # 创建 .env 文件
    log_info "创建 .env 文件..."
    cat > "$PROJECT_DIR/docker/.env" << EOF
# LumenIM Docker Compose 环境变量
# 服务器 IP: ${SERVER_IP}

COMPOSE_PROJECT_NAME=lumenim
SERVER_IP=${SERVER_IP}

# 数据库配置
MYSQL_ROOT_PASSWORD=${MYSQL_ROOT_PASSWORD}
MYSQL_DATABASE=${MYSQL_DATABASE}
MYSQL_USER=${MYSQL_USER}
MYSQL_PASSWORD=${MYSQL_PASSWORD}

# Redis 配置
REDIS_PASSWORD=${REDIS_PASSWORD}
REDIS_PORT=${REDIS_PORT}

# MinIO 配置
MINIO_ROOT_USER=${MINIO_ROOT_USER}
MINIO_ROOT_PASSWORD=${MINIO_ROOT_PASSWORD}

# Nginx 配置
NGINX_HTTP_PORT=${NGINX_HTTP_PORT}
NGINX_HTTPS_PORT=${NGINX_HTTPS_PORT}

# 时区配置
TZ=Asia/Shanghai

# 数据目录
DATA_DIR=${DATA_DIR}
EOF
    
    # 创建 docker-compose.yaml
    log_info "创建 docker-compose.yaml..."
    cat > "$PROJECT_DIR/docker/docker-compose.yaml" << EOF
version: '3.8'

services:
  # ==================== MySQL 数据库 ====================
  mysql:
    image: mysql:8.0
    container_name: lumenim-mysql
    restart: always
    ports:
      - "127.0.0.1:3306:3306"
    environment:
      MYSQL_ROOT_PASSWORD: \${MYSQL_ROOT_PASSWORD}
      MYSQL_DATABASE: \${MYSQL_DATABASE}
      MYSQL_USER: \${MYSQL_USER}
      MYSQL_PASSWORD: \${MYSQL_PASSWORD}
      TZ: \${TZ}
    volumes:
      - mysql_data:/var/lib/mysql
      - ./sql:/docker-entrypoint-initdb.d:ro
    command: >
      --default-authentication-plugin=mysql_native_password
      --character-set-server=utf8mb4
      --collation-server=utf8mb4_unicode_ci
      --max_connections=1000
      --innodb_buffer_pool_size=512M
    networks:
      - lumenim-network
    healthcheck:
      test: ["CMD", "mysqladmin", "ping", "-h", "localhost"]
      interval: 10s
      timeout: 5s
      retries: 10
      start_period: 60s
    deploy:
      resources:
        limits:
          memory: 2G

  # ==================== Redis 缓存 ====================
  redis:
    image: redis:7.4-alpine
    container_name: lumenim-redis
    restart: always
    ports:
      - "127.0.0.1:6379:6379"
    volumes:
      - redis_data:/data
    command: redis-server --appendonly yes
    networks:
      - lumenim-network
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 10s
      timeout: 5s
      retries: 5

  # ==================== MinIO 对象存储 ====================
  minio:
    image: minio/minio:latest
    container_name: lumenim-minio
    restart: always
    ports:
      - "${SERVER_IP}:9000:9000"
      - "${SERVER_IP}:9090:9090"
    environment:
      MINIO_ROOT_USER: \${MINIO_ROOT_USER}
      MINIO_ROOT_PASSWORD: \${MINIO_ROOT_PASSWORD}
    volumes:
      - minio_data:/data
    command: server /data --console-address ":9090"
    networks:
      - lumenim-network
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:9000/minio/health/live"]
      interval: 30s
      timeout: 20s
      retries: 3

  # ==================== Nginx 反向代理 ====================
  nginx:
    image: nginx:alpine
    container_name: lumenim-nginx
    restart: always
    ports:
      - "${SERVER_IP}:80:80"
    volumes:
      - ./nginx.conf:/etc/nginx/conf.d/default.conf:ro
      - ../front/dist:/usr/share/nginx/html:ro
      - nginx_logs:/var/log/nginx
    depends_on:
      lumenim_http:
        condition: service_healthy
    networks:
      - lumenim-network
    healthcheck:
      test: ["CMD", "wget", "-q", "--spider", "http://localhost/health"]
      interval: 30s
      timeout: 10s
      retries: 3

  # ==================== LumenIM HTTP API ====================
  lumenim_http:
    image: gzydong/lumenim:latest
    container_name: lumenim-http
    depends_on:
      mysql:
        condition: service_healthy
      redis:
        condition: service_healthy
      minio:
        condition: service_started
    restart: always
    volumes:
      - ./config.yaml:/work/config.yaml:ro
      - uploads:/work/uploads:rw
      - runtime:/work/runtime:rw
    command: http --config=/work/config.yaml
    networks:
      - lumenim-network
    healthcheck:
      test: ["CMD", "wget", "-q", "--spider", "http://localhost:9501/api/v1/health"]
      interval: 30s
      timeout: 10s
      retries: 5
      start_period: 40s
    deploy:
      replicas: 2

  # ==================== LumenIM WebSocket ====================
  lumenim_comet:
    image: gzydong/lumenim:latest
    container_name: lumenim-comet
    depends_on:
      mysql:
        condition: service_healthy
      redis:
        condition: service_healthy
    restart: always
    volumes:
      - ./config.yaml:/work/config.yaml:ro
      - runtime:/work/runtime:rw
    command: comet --config=/work/config.yaml
    networks:
      - lumenim-network
    deploy:
      replicas: 2

  # ==================== LumenIM 异步队列 ====================
  lumenim_queue:
    image: gzydong/lumenim:latest
    container_name: lumenim-queue
    depends_on:
      mysql:
        condition: service_healthy
      redis:
        condition: service_healthy
      minio:
        condition: service_started
    restart: always
    volumes:
      - ./config.yaml:/work/config.yaml:ro
      - uploads:/work/uploads:rw
      - runtime:/work/runtime:rw
    command: queue --config=/work/config.yaml
    networks:
      - lumenim-network

  # ==================== LumenIM 定时任务 ====================
  lumenim_cron:
    image: gzydong/lumenim:latest
    container_name: lumenim-cron
    depends_on:
      mysql:
        condition: service_healthy
      redis:
        condition: service_healthy
    restart: always
    volumes:
      - ./config.yaml:/work/config.yaml:ro
      - uploads:/work/uploads:rw
      - runtime:/work/runtime:rw
    command: crontab --config=/work/config.yaml
    networks:
      - lumenim-network

networks:
  lumenim-network:
    driver: bridge
    ipam:
      config:
        - subnet: 172.28.0.0/16

volumes:
  mysql_data:
  redis_data:
  minio_data:
  nginx_logs:
  uploads:
  runtime:
EOF
    
    # 创建 nginx.conf
    log_info "创建 nginx.conf..."
    cat > "$PROJECT_DIR/docker/nginx.conf" << EOF
server {
    listen 80;
    server_name ${SERVER_IP};

    root /usr/share/nginx/html;
    index index.html;

    # 前端路由 (SPA)
    location / {
        try_files \$uri \$uri/ /index.html;
    }

    # 静态资源缓存
    location ~* \.(gif|jpg|jpeg|png|bmp|swf|flv|ico)$ {
        expires 7d;
        access_log off;
    }

    location ~* \.(js|css|less|scss|sass)$ {
        expires 7d;
        access_log off;
    }

    # API 代理
    location /api/ {
        proxy_pass http://lumenim_http:9501/api/;
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }

    # WebSocket 代理
    location /ws/ {
        proxy_pass http://lumenim_comet:9502/ws/;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
        proxy_read_timeout 86400;
        proxy_send_timeout 86400;
        proxy_buffering off;
    }

    # 健康检查
    location /health {
        access_log off;
        return 200 "OK";
        add_header Content-Type text/plain;
    }
}
EOF
    
    # 创建 Docker 用 config.yaml
    log_info "创建 Docker 用 config.yaml..."
    cat > "$PROJECT_DIR/docker/config.yaml" << EOF
app:
  env: prod
  debug: false
  admin_email:
    - admin@example.com

server:
  http_addr: ":9501"
  websocket_addr: ":9502"
  tcp_addr: ":9505"

log:
  path: "./runtime"

redis:
  host: lumenim-redis:6379
  auth: ${REDIS_PASSWORD}
  database: 0

mysql:
  host: lumenim-mysql
  port: 3306
  charset: utf8mb4
  username: root
  password: ${MYSQL_ROOT_PASSWORD}
  database: ${MYSQL_DATABASE}
  collation: utf8mb4_unicode_ci

jwt:
  secret: ${JWT_SECRET}
  expires_time: 3600
  buffer_time: 3600

cors:
  origin: "*"
  headers: "Content-Type,Cache-Control,User-Agent,Keep-Alive,DNT,AccessToken,Authorization"
  methods: "OPTIONS,GET,POST,PUT,DELETE"
  credentials: false
  max_age: 600

filesystem:
  default: minio
  minio:
    secret_id: "${MINIO_ROOT_USER}"
    secret_key: "${MINIO_ROOT_PASSWORD}"
    bucket_public: "im-static"
    bucket_private: "im-private"
    endpoint: "${SERVER_IP}:9000"
    ssl: false

email:
  host: smtp.163.com
  port: 465
  username:
  password:
  fromname: "Lumen IM"

oauth:
  github:
    client_id: ""
    client_secret: ""
    redirect_uri: "http://${SERVER_IP}/oauth/callback/github"
  gitee:
    client_id: ""
    client_secret: ""
    redirect_uri: "http://${SERVER_IP}/oauth/callback/gitee"
EOF
    
    chown -R "$RUN_USER:$RUN_USER" "$PROJECT_DIR/docker"
    log_success "Docker Compose 项目配置完成"
}

# ============================================================
# 构建后端
# ============================================================

build_backend() {
    log_step "构建后端..."
    
    export GOROOT=/usr/local/go
    export PATH=$PATH:$GOROOT/bin
    
    # 设置 Go 模块代理（优先使用国内镜像）
    export GOPROXY=https://goproxy.cn,direct
    export GOSUMDB=off  # 关闭 GOSUMDB 检查，加速下载
    
    # 诊断：检查项目目录状态
    log_info "=== 构建环境诊断 ==="
    log_info "项目目录: $PROJECT_DIR"
    log_info "后端目录: $PROJECT_DIR/backend"
    
    # 检查项目目录是否存在
    if [ ! -d "$PROJECT_DIR" ]; then
        log_error "项目目录不存在: $PROJECT_DIR"
        log_error "请先执行 --clone 选项克隆代码仓库"
        echo ""
        echo "正确执行顺序:"
        echo "  sudo ./install-ubuntu20.sh --clone    # 第1步: 克隆代码"
        echo "  sudo ./install-ubuntu20.sh --backend  # 第2步: 构建后端"
        return 1
    fi
    
    # 检查 backend 目录是否存在
    if [ ! -d "$PROJECT_DIR/backend" ]; then
        log_error "后端目录不存在: $PROJECT_DIR/backend"
        log_error "仓库克隆可能不完整，请重新克隆"
        echo ""
        echo "检查仓库内容:"
        ls -la "$PROJECT_DIR" 2>/dev/null || echo "无法访问目录"
        return 1
    fi
    
    # 切换到后端目录
    cd "$PROJECT_DIR/backend"
    
    # 检查 go.mod 是否存在
    if [ ! -f "go.mod" ]; then
        log_error "go.mod 文件不存在"
        log_error "请检查仓库地址是否正确: $GIT_REPO"
        echo ""
        echo "当前 backend 目录内容:"
        ls -la "$PROJECT_DIR/backend" 2>/dev/null | head -20
        echo ""
        echo "可能的原因:"
        echo "  1. Git 仓库地址错误: $GIT_REPO"
        echo "  2. 仓库克隆不完整"
        echo "  3. 使用了错误的分支"
        return 1
    fi
    
    log_info "检测到 go.mod 文件"
    log_info "Go 版本: $(go version 2>/dev/null || echo '未安装')"
    
    # 清理可能损坏的依赖缓存
    log_info "清理 Go 模块缓存..."
    go clean -modcache 2>/dev/null || true
    
    # 设置 Go 版本兼容模式
    # 修正 go.mod 中的 go 版本（如果版本过高）
    local go_version=$(go version 2>/dev/null | grep -oP 'go\d+\.\d+' | head -1)
    local mod_go_version=$(grep '^go ' go.mod | awk '{print $2}')
    
    log_info "go.mod 声明版本: $mod_go_version"
    log_info "当前 Go 版本: $go_version"
    
    # 如果 go.mod 版本高于实际版本，修正它
    if [ -n "$mod_go_version" ] && [ -n "$go_version" ]; then
        # 提取主版本号进行比较 (如 1.21 vs 1.22)
        local mod_major=$(echo "$mod_go_version" | cut -d. -f1)
        local mod_minor=$(echo "$mod_go_version" | cut -d. -f2)
        local cur_major=$(echo "$go_version" | grep -oP '\d+' | head -1)
        local cur_minor=$(echo "$go_version" | grep -oP '\d+$' | head -1)
        
        if [ "$mod_minor" -gt "$cur_minor" ] 2>/dev/null; then
            log_warn "go.mod 版本 ($mod_go_version) 高于当前 Go 版本"
            log_info "修正 go.mod 版本为 $go_version..."
            sed -i "s/^go $mod_go_version$/go $go_version/" go.mod
        fi
    fi
    
    log_info "下载 Go 依赖（使用 goproxy.cn 镜像）..."
    
    # 方法1: 使用 go mod tidy
    if go mod tidy 2>&1; then
        log_success "go mod tidy 执行成功"
    else
        log_warn "go mod tidy 执行失败，尝试备用方法..."
        
        # 方法2: 直接下载所有依赖
        log_info "尝试 go mod download..."
        go mod download 2>&1 || {
            log_error "go mod download 失败"
            log_info "检查网络连接和代理设置..."
        }
    fi
    
    # 验证依赖下载结果
    log_info "验证依赖..."
    if [ ! -f "go.sum" ] || [ ! -s "go.sum" ]; then
        log_warn "go.sum 文件缺失或为空"
        log_info "重新生成 go.sum..."
        go mod tidy
    fi
    
    log_info "安装 protobuf 插件..."
    go install google.golang.org/protobuf/cmd/protoc-gen-go@latest
    go install github.com/envoyproxy/protoc-gen-validate@latest
    
    mkdir -p "$PROJECT_DIR/backend/bin"
    
    log_info "编译后端..."
    # 使用 -mod=mod 强制使用 go.mod 中的版本
    if go build -mod=mod -o bin/lumenim . 2>&1; then
        log_success "后端编译成功！"
    else
        log_error "后端编译失败"
        echo ""
        echo "常见问题排查:"
        echo "1. 检查依赖下载是否完整: go mod download"
        echo "2. 清理缓存后重试: go clean -modcache && go mod tidy"
        echo "3. 检查网络代理设置: export GOPROXY=https://goproxy.cn,direct"
        echo "4. 尝试 GOPROXY 镜像:"
        echo "   - 阿里云: https://mirrors.aliyun.com/goproxy/"
        echo "   - 七牛云: https://goproxy.cn,direct"
        echo "   - goproxy.io: https://goproxy.io,direct"
        return 1
    fi
    
    chown "$RUN_USER:$RUN_USER" "$PROJECT_DIR/backend/bin/lumenim"
    log_success "后端构建完成"
    log_info "可执行文件: $PROJECT_DIR/backend/bin/lumenim"
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
    
    log_info "构建前端..."
    pnpm build
    
    log_success "前端依赖安装完成"
}

# ============================================================
# 启动 Docker Compose 服务
# ============================================================

start_docker_compose() {
    log_step "启动 Docker Compose 服务..."
    
    cd "$PROJECT_DIR/docker"
    
    # 拉取镜像
    log_info "拉取 Docker 镜像..."
    docker compose pull
    
    # 启动服务
    log_info "启动容器..."
    docker compose up -d
    
    # 等待健康检查
    log_info "等待服务启动..."
    sleep 15
    
    log_success "Docker Compose 服务启动完成"
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
ExecStart=${PROJECT_DIR}/backend/bin/lumenim http --config=${PROJECT_DIR}/backend/config.yaml
Restart=on-failure
RestartSec=5s
LimitNOFILE=65536
StandardOutput=journal
StandardError=journal
SyslogIdentifier=lumenim-backend

[Install]
WantedBy=multi-user.target
EOF

    cat > /etc/systemd/system/lumenim-comet.service << EOF
[Unit]
Description=LumenIM WebSocket Service
Documentation=https://github.com/wenming429/AIProject
After=network.target redis.service
Wants=redis.service

[Service]
Type=simple
User=${RUN_USER}
Group=${RUN_USER}
WorkingDirectory=${PROJECT_DIR}/backend
Environment="PATH=/usr/local/go/bin:/usr/local/node/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
Environment="GOPROXY=https://goproxy.cn,direct"
ExecStart=${PROJECT_DIR}/backend/bin/lumenim comet --config=${PROJECT_DIR}/backend/config.yaml
Restart=on-failure
RestartSec=5s
StandardOutput=journal
StandardError=journal
SyslogIdentifier=lumenim-comet

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
    
    if [ "$USE_DOCKER" = true ]; then
        start_docker_compose
        return
    fi
    
    log_info "启动 MySQL..."
    systemctl enable mysql
    systemctl start mysql
    
    log_info "启动 Redis..."
    systemctl enable redis-server
    systemctl start redis-server
    
    log_info "启动后端服务..."
    systemctl enable lumenim-backend
    systemctl start lumenim-backend
    
    log_info "启动 WebSocket 服务..."
    systemctl enable lumenim-comet
    systemctl start lumenim-comet
    
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
    
    if [ "$USE_DOCKER" = true ]; then
        cd "$PROJECT_DIR/docker"
        docker compose ps
        
        echo ""
        echo "=========================================="
        echo "容器健康检查"
        echo "=========================================="
        
        for container in lumenim-mysql lumenim-redis lumenim-minio lumenim-nginx lumenim-http lumenim-comet; do
            if docker ps | grep -q "$container"; then
                log_success "$container: 运行中"
            else
                log_error "$container: 未运行"
            fi
        done
    else
        if systemctl is-active mysql &>/dev/null; then
            log_success "MySQL: 运行中"
        else
            log_error "MySQL: 未运行"
        fi
        
        if systemctl is-active redis-server &>/dev/null; then
            log_success "Redis: 运行中"
        else
            log_error "Redis: 未运行"
        fi
        
        if systemctl is-active lumenim-backend &>/dev/null; then
            log_success "lumenim-backend: 运行中"
        else
            log_error "lumenim-backend: 未运行"
            journalctl -u lumenim-backend -n 10 --no-pager
        fi
    fi
    
    echo ""
    echo "=========================================="
    echo "端口占用"
    echo "=========================================="
    for port in $HTTP_PORT $WS_PORT $TCP_PORT $MYSQL_PORT $REDIS_PORT $MINIO_API_PORT $MINIO_CONSOLE_PORT $NGINX_HTTP_PORT; do
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
    if curl -s http://localhost:$NGINX_HTTP_PORT/health &>/dev/null; then
        log_success "Nginx 健康检查: 通过"
    else
        log_warn "Nginx 健康检查: 失败（服务可能仍在启动）"
    fi
}

# ============================================================
# 配置防火墙
# ============================================================

configure_firewall() {
    log_step "配置防火墙..."
    
    if check_command ufw; then
        log_info "配置 UFW 防火墙..."
        
        # 确保 SSH 规则第一
        sudo ufw allow 22/tcp comment 'SSH'
        
        # HTTP/HTTPS
        sudo ufw allow 80/tcp comment 'HTTP'
        sudo ufw allow 443/tcp comment 'HTTPS'
        
        # MinIO
        sudo ufw allow 9000/tcp comment 'MinIO API'
        sudo ufw allow 9090/tcp comment 'MinIO Console'
        
        # 设置默认策略
        sudo ufw default deny incoming
        sudo ufw default allow outgoing
        
        # 启用防火墙
        echo "y" | sudo ufw enable
        
        log_success "防火墙配置完成"
        ufw status numbered
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
    --docker               安装 Docker
    --docker-compose       安装 Docker Compose
    --use-docker           使用 Docker Compose 部署（默认）
    --use-native           使用原生部署方式
    --offline=[目录]       离线包目录

配置信息:
    服务器 IP: 192.168.23.131
    部署用户: wenming429
    MySQL 密码: lumenim123
    代码仓库: https://github.com/wenming429/AIProject.git

示例:
    sudo ./install-ubuntu20.sh --all
    sudo ./install-ubuntu20.sh --check
    sudo ./install-ubuntu20.sh --docker --use-docker --all
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
    echo "目标服务器: $SERVER_IP"
    echo "部署用户: $RUN_USER"
    echo "部署模式: $([ "$USE_DOCKER" = true ] && echo "Docker Compose" || echo "原生部署")"
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
    DO_DOCKER=false
    DO_DOCKER_COMPOSE=false
    
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
            --docker) DO_DOCKER=true; shift ;;
            --docker-compose) DO_DOCKER_COMPOSE=true; shift ;;
            --use-docker) USE_DOCKER=true; shift ;;
            --use-native) USE_DOCKER=false; shift ;;
            --offline=*) OFFLINE_PACKAGE_DIR="${1#*=}"; shift ;;
            *) shift ;;
        esac
    done
    
    if [ "$DO_CHECK" = true ]; then
        check_environment
        exit 0
    fi
    
    if [ "$DO_ALL" = true ] || [ "$DO_DOCKER" = true ] || [ "$DO_DOCKER_COMPOSE" = true ]; then
        check_root
    fi
    
    if [ "$DO_ALL" = true ] || [ "$DO_DEPS" = true ]; then
        check_root
    fi
    
    if [ "$DO_ALL" = true ] || [ "$DO_DEPS" = true ]; then
        check_environment
        install_system_deps
    fi
    
    if [ "$DO_ALL" = true ] || [ "$DO_DOCKER" = true ]; then
        install_docker
    fi
    
    if [ "$DO_ALL" = true ] || [ "$DO_DOCKER_COMPOSE" = true ]; then
        install_docker_compose
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
        if [ "$USE_DOCKER" = true ]; then
            configure_docker_compose
        else
            configure_database
            configure_project
            create_systemd_service
        fi
    fi
    
    if [ "$DO_ALL" = true ] || [ "$DO_DATABASE" = true ]; then
        if [ "$USE_DOCKER" != true ]; then
            init_database
        fi
    fi
    
    if [ "$DO_ALL" = true ] || [ "$DO_BACKEND" = true ]; then
        if [ "$USE_DOCKER" != true ]; then
            build_backend
        fi
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
        echo "部署完成!"
        echo "=========================================="
        echo ""
        echo "访问信息:"
        echo "  前端: http://$SERVER_IP"
        echo "  后端 API: http://$SERVER_IP/api/v1"
        echo "  WebSocket: ws://$SERVER_IP/ws/"
        echo "  MinIO API: http://$SERVER_IP:$MINIO_API_PORT"
        echo "  MinIO Console: http://$SERVER_IP:$MINIO_CONSOLE_PORT"
        echo ""
        if [ "$USE_DOCKER" = true ]; then
            echo "Docker Compose 管理命令:"
            echo "  cd $PROJECT_DIR/docker"
            echo "  docker compose ps"
            echo "  docker compose logs -f"
            echo "  docker compose restart"
        else
            echo "服务管理命令:"
            echo "  sudo systemctl status lumenim-backend"
            echo "  sudo systemctl status lumenim-comet"
            echo "  sudo systemctl restart lumenim-backend"
            echo ""
            echo "日志查看:"
            echo "  sudo journalctl -u lumenim-backend -f"
            echo "  sudo journalctl -u lumenim-comet -f"
        fi
        echo ""
    fi
}

main "$@"
