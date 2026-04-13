#!/bin/bash
#
# LumenIM CentOS 7 离线安装脚本
# Offline installation script for LumenIM CentOS 7
#
# 使用方法: sudo ./install-offline.sh [选项]
# Usage: sudo ./install-offline.sh [options]
#
# 版本: 1.0.1
# 更新日期: 2026-04-08
# 适配系统: CentOS 7.x (离线环境)

# 禁用错误退出，继续执行
set +e

# ============================================================
# 配置
# ============================================================

# 离线包目录（必须在目标服务器上）
OFFLINE_DIR="${OFFLINE_DIR:-/mnt/packages}"

# 安装目录
INSTALL_ROOT="/opt/lumenim"

# 项目目录
PROJECT_DIR="/var/www/lumenim"

# 数据目录
DATA_DIR="/var/lib/lumenim"

# 运行用户
RUN_USER="www-data"

# 端口
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

# JWT
JWT_SECRET="836c3fea9bba4e04d51bd0fbcc5"

# 版本（会尝试自动检测）
GO_VERSION="1.21.13"
NODE_VERSION="18.20.5"
PROTOBUF_VERSION="25.1"
DOCKER_VERSION="26.1.4"
MYSQL_VERSION="8.0.35"
REDIS_VERSION="7.4.1"

# ============================================================
# 颜色
# ============================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# 日志函数
log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_step() { echo -e "${BLUE}[STEP]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_detail() { echo -e "${CYAN}[DETAIL]${NC} $1"; }

# ============================================================
# 工具函数
# ============================================================

check_root() {
    if [ "$EUID" -ne 0 ]; then
        log_error "需要 root 权限，请使用 sudo"
        exit 1
    fi
}

check_dir() {
    if [ ! -d "$OFFLINE_DIR" ]; then
        log_error "离线目录不存在: $OFFLINE_DIR"
        log_error "请先挂载离线包或指定正确路径: --dir=/path/to/packages"
        exit 1
    fi
    log_info "离线目录: $OFFLINE_DIR"
}

# 查找本地安装包（支持多种文件名模式）
find_local_pkg() {
    local pattern="$1"
    local dir="${2:-$OFFLINE_DIR}"
    local found
    found=$(find "$dir" -maxdepth 2 -name "$pattern" 2>/dev/null | head -1)
    echo "$found"
}

# 获取文件大小
get_file_size() {
    local file="$1"
    if [ -f "$file" ]; then
        local size=$(stat -c%s "$file" 2>/dev/null || stat -f%z "$file" 2>/dev/null)
        echo "$size"
    else
        echo "0"
    fi
}

# 格式化大小
format_size() {
    local bytes=$1
    if [ "$bytes" -gt 1073741824 ]; then
        echo "$(echo "scale=2; $bytes/1073741824" | bc)GB"
    elif [ "$bytes" -gt 1048576 ]; then
        echo "$(echo "scale=2; $bytes/1048576" | bc)MB"
    elif [ "$bytes" -gt 1024 ]; then
        echo "$(echo "scale=2; $bytes/1024" | bc)KB"
    else
        echo "${bytes}B"
    fi
}

install_yum() {
    yum install -y "$@" 2>/dev/null || log_warn "yum install failed for: $*"
}

create_dir() {
    local dir="$1"
    local owner="${2:-$RUN_USER}"
    mkdir -p "$dir"
    chown "$owner:$owner" "$dir" 2>/dev/null || true
}

# ============================================================
# 环境检查
# ============================================================

check_env() {
    log_step "=========================================="
    log_step "环境检查"
    log_step "=========================================="
    
    echo ""
    log_detail "系统信息:"
    cat /etc/centos-release 2>/dev/null || echo "CentOS"
    echo "  架构: $(uname -m)"
    echo "  内核: $(uname -r)"
    echo "  内存: $(free -h | awk '/^Mem:/{print $2}')"
    echo "  磁盘: $(df -h / | awk 'NR==2{print $4}')"
    
    echo ""
    log_detail "检查离线目录: $OFFLINE_DIR"
    if [ -d "$OFFLINE_DIR" ]; then
        log_info "离线目录存在"
        echo ""
        echo "离线包内容:"
        ls -la "$OFFLINE_DIR" 2>/dev/null | head -20
        
        # 统计
        local total_files=$(find "$OFFLINE_DIR" -type f 2>/dev/null | wc -l)
        local total_size=$(du -sb "$OFFLINE_DIR" 2>/dev/null | awk '{print $1}')
        echo ""
        log_detail "文件数: $total_files, 总大小: $(format_size $total_size)"
    else
        log_error "离线目录不存在"
    fi
    
    echo ""
    log_success "环境检查完成"
}

# ============================================================
# 安装系统依赖
# ============================================================

install_deps() {
    log_step "=========================================="
    log_step "安装系统依赖"
    log_step "=========================================="
    
    # 检查本地 RPM
    local sysdeps_dir="${OFFLINE_DIR}/sysdeps"
    if [ -d "$sysdeps_dir" ] && [ "$(ls -A $sysdeps_dir 2>/dev/null)" ]; then
        log_info "从本地sysdeps安装..."
        rpm -Uvh --force $sysdeps_dir/*.rpm 2>/dev/null || true
    fi
    
    # 尝试 yum 安装（可能失败，但会有日志）
    log_info "安装基础工具..."
    install_yum wget curl git unzip tar xz gcc gcc-c++ make net-tools
    
    # EPEL
    if [ ! -f /etc/yum.repos.d/epel.repo ]; then
        log_info "安装 EPEL 源..."
        install_yum epel-release 2>/dev/null || log_warn "EPEL 安装失败，需要网络或本地源"
    fi
    
    log_success "系统依赖安装完成"
}

# ============================================================
# 安装 Go
# ============================================================

install_go() {
    log_step "=========================================="
    log_step "安装 Go"
    log_step "=========================================="
    
    check_dir
    
    # 尝试多种可能的车名
    local go_pkgs=(
        "go${GO_VERSION}.linux-amd64.tar.gz"
        "go*.linux-amd64.tar.gz"
    )
    
    local go_pkg=""
    local found_size=0
    
    for pattern in "${go_pkgs[@]}"; do
        local candidate=$(find "$OFFLINE_DIR" -maxdepth 1 -name "$pattern" 2>/dev/null | head -1)
        if [ -n "$candidate" ] && [ -f "$candidate" ]; then
            local size=$(get_file_size "$candidate")
            if [ "$size" -gt 10000000 ]; then  # > 10MB
                go_pkg="$candidate"
                found_size=$size
                break
            fi
        fi
    done
    
    if [ -z "$go_pkg" ] || [ ! -f "$go_pkg" ]; then
        log_error "Go 安装包未找到"
        log_error "搜索模式: go*.linux-amd64.tar.gz"
        return 1
    fi
    
    log_info "找到: $(basename $go_pkg) ($(format_size $found_size))"
    log_info "安装��: /usr/local/go"
    
    rm -rf /usr/local/go
    tar -xzf "$go_pkg" -C /tmp/
    mv /tmp/go /usr/local/go
    
    # 环境变量
    cat > /etc/profile.d/go.sh << 'EOF'
export GOROOT=/usr/local/go
export PATH=$PATH:$GOROOT/bin
export GOPATH=$HOME/go
EOF
    chmod +x /etc/profile.d/go.sh
    
    # 当前会话
    export GOROOT=/usr/local/go
    export PATH=$PATH:$GOROOT/bin
    
    log_success "Go 安装完成"
    /usr/local/go/bin/go version 2>/dev/null || log_warn "Go 命令不可用"
}

# ============================================================
# 安装 Node.js
# ============================================================

install_node() {
    log_step "=========================================="
    log_step "安装 Node.js"
    log_step "=========================================="
    
    check_dir
    
    # 查找 Node.js 包
    local node_pkgs=(
        "node-v${NODE_VERSION}-linux-x64.tar.xz"
        "node-*.linux-x64.tar.xz"
    )
    
    local node_pkg=""
    local found_size=0
    
    for pattern in "${node_pkgs[@]}"; do
        local candidate=$(find "$OFFLINE_DIR" -maxdepth 1 -name "$pattern" 2>/dev/null | head -1)
        if [ -n "$candidate" ] && [ -f "$candidate" ]; then
            local size=$(get_file_size "$candidate")
            if [ "$size" -gt 5000000 ]; then
                node_pkg="$candidate"
                found_size=$size
                break
            fi
        fi
    done
    
    if [ -z "$node_pkg" ] || [ ! -f "$node_pkg" ]; then
        log_error "Node.js 安装包未找到"
        return 1
    fi
    
    log_info "找到: $(basename $node_pkg) ($(format_size $found_size))"
    log_info "安装到: /usr/local/node"
    
    rm -rf /usr/local/node
    tar -xJf "$node_pkg" -C /tmp/
    mv /tmp/node-v${NODE_VERSION}-linux-x64 /usr/local/node
    
    # pnpm
    local pnpm_src="${OFFLINE_DIR}/pnpm"
    if [ -f "$pnpm_src" ]; then
        cp "$pnpm_src" /usr/local/node/bin/pnpm
        chmod +x /usr/local/node/bin/pnpm
        log_info "安装 pnpm"
    else
        # 尝试 pnpm-linux-x64
        pnpm_src=$(find "$OFFLINE_DIR" -maxdepth 1 -name "pnpm-*" 2>/dev/null | head -1)
        if [ -f "$pnpm_src" ]; then
            cp "$pnpm_src" /usr/local/node/bin/pnpm
            chmod +x /usr/local/node/bin/pnpm
        fi
    fi
    
    # 环境变量
    cat > /etc/profile.d/nodejs.sh << 'EOF'
export NODE_PREFIX=/usr/local/node
export PATH=$PATH:$NODE_PREFIX/bin
EOF
    chmod +x /etc/profile.d/nodejs.sh
    
    export NODE_PREFIX=/usr/local/node
    export PATH=$PATH:$NODE_PREFIX/bin
    
    log_success "Node.js 安装完成"
    /usr/local/node/bin/node --version 2>/dev/null || log_warn "node 命令不可用"
}

# ============================================================
# 安装 Docker（离线）
# ============================================================

install_docker() {
    log_step "=========================================="
    log_step "安装 Docker"
    log_step "=========================================="
    
    check_dir
    local docker_dir="${OFFLINE_DIR}/docker"
    
    if [ -d "$docker_dir" ] && [ "$(ls -A $docker_dir 2>/dev/null)" ]; then
        log_info "从离线包安装 Docker..."
        
        # 列出要安装的包
        log_detail "RPM 包:"
        ls -la "$docker_dir"/*.rpm 2>/dev/null | while read line; do
            local name=$(echo "$line" | awk '{print $NF}')
            log_detail "  - $(basename $name)"
        done
        
        # 安装
        log_info "安装 RPM..."
        yum localinstall -y "$docker_dir"/*.rpm 2>/dev/null || \
        rpm -Uvh --force "$docker_dir"/*.rpm 2>/dev/null || \
        log_warn "Docker RPM 安装失败"
    else
        log_error "Docker 离线包目录不存在: $docker_dir"
        return 1
    fi
    
    # 启动
    log_info "启动 Docker..."
    systemctl start docker 2>/dev/null || service docker start 2>/dev/null || true
    systemctl enable docker 2>/dev/null || true
    
    log_success "Docker 安装完成"
    docker --version 2>/dev/null || log_warn "docker 命令不可用"
}

# ============================================================
# 安装 MySQL Docker
# ============================================================

install_mysql() {
    log_step "=========================================="
    log_step "安装 MySQL"
    log_step "=========================================="
    
    if ! command -v docker &>/dev/null; then
        log_error "Docker 不可用"
        return 1
    fi
    
    # 尝试加载离线镜像
    local mysql_image="${OFFLINE_DIR}/mysql-${MYSQL_VERSION}.tar"
    if [ -f "$mysql_image" ]; then
        log_info "加载 MySQL 离线镜像..."
        docker load -i "$mysql_image" 2>/dev/null || log_warn "镜像加载失败"
    else
        # 尝试其他文件名
        mysql_image=$(find "$OFFLINE_DIR" -name "mysql*.tar" 2>/dev/null | head -1)
        if [ -f "$mysql_image" ]; then
            log_info "加载: $(basename $mysql_image)"
            docker load -i "$mysql_image" 2>/dev/null || log_warn "镜像加载失败"
        fi
    fi
    
    # 检查镜像
    if ! docker images mysql:${MYSQL_VERSION} 2>/dev/null | grep -q "${MYSQL_VERSION}"; then
        log_warn "MySQL 镜像不存在，将尝试拉取"
        docker pull mysql:${MYSQL_VERSION} 2>/dev/null || true
    fi
    
    # 创建容器
    if docker ps -a | grep -q "lumenim-mysql"; then
        log_info "MySQL 容器已存在"
    else
        log_info "创建 MySQL 容器..."
        create_dir "$DATA_DIR/mysql" "root"
        
        docker run -d \
            --name lumenim-mysql \
            -e MYSQL_ROOT_PASSWORD="$MYSQL_ROOT_PASSWORD" \
            -e MYSQL_DATABASE="$MYSQL_DATABASE" \
            -e MYSQL_USER="$MYSQL_USER" \
            -e MYSQL_PASSWORD="$MYSQL_PASSWORD" \
            -p 3306:3306 \
            -v "$DATA_DIR/mysql":/var/lib/mysql \
            mysql:${MYSQL_VERSION} \
            --default-authentication-plugin=mysql_native_password
        
        log_success "MySQL 容器创建完成"
    fi
}

# ============================================================
# 安装 Redis Docker
# ============================================================

install_redis() {
    log_step "=========================================="
    log_step "安装 Redis"
    log_step "=========================================="
    
    if ! command -v docker &>/dev/null; then
        log_error "Docker 不可用"
        return 1
    fi
    
    # 加载离线镜像
    local redis_image="${OFFLINE_DIR}/redis-${REDIS_VERSION}.tar"
    if [ -f "$redis_image" ]; then
        log_info "加载 Redis 离线镜像..."
        docker load -i "$redis_image" 2>/dev/null || log_warn "镜像加载失败"
    else
        redis_image=$(find "$OFFLINE_DIR" -name "redis*.tar" 2>/dev/null | head -1)
        if [ -f "$redis_image" ]; then
            log_info "加载: $(basename $redis_image)"
            docker load -i "$redis_image" 2>/dev/null || log_warn "镜像加载失败"
        fi
    fi
    
    # 创建容器
    if docker ps -a | grep -q "lumenim-redis"; then
        log_info "Redis 容器已存在"
    else
        log_info "创建 Redis 容器..."
        create_dir "$DATA_DIR/redis" "root"
        
        docker run -d \
            --name lumenim-redis \
            -p 6379:6379 \
            -v "$DATA_DIR/redis":/data \
            redis:${REDIS_VERSION} redis-server --appendonly yes
        
        log_success "Redis 容器创建完成"
    fi
}

# ============================================================
# 安装 Protocol Buffers
# ============================================================

install_protobuf() {
    log_step "=========================================="
    log_step "安装 Protocol Buffers"
    log_step "=========================================="
    
    check_dir
    
    # 查找 protoc
    local protoc_pkgs=(
        "protoc-${PROTOBUF_VERSION}-linux-x86_64.zip"
        "protoc-*-linux-x86_64.zip"
    )
    
    local protoc_pkg=""
    for pattern in "${protoc_pkgs[@]}"; do
        local candidate=$(find "$OFFLINE_DIR" -maxdepth 1 -name "$pattern" 2>/dev/null | head -1)
        if [ -n "$candidate" ] && [ -f "$candidate" ]; then
            protoc_pkg="$candidate"
            break
        fi
    done
    
    if [ -z "$protoc_pkg" ] || [ ! -f "$protoc_pkg" ]; then
        log_error "protoc 安装包未找到"
        return 1
    fi
    
    log_info "找到: $(basename $protoc_pkg)"
    log_info "安装到: /usr/local/protobuf"
    
    mkdir -p /usr/local/protobuf
    unzip -qo "$protoc_pkg" -d /usr/local/protobuf
    cp -f /usr/local/protobuf/bin/protoc /usr/local/bin/
    
    log_success "Protocol Buffers 安装完成"
    protoc --version 2>/dev/null || log_warn "protoc 命令不可用"
}

# ============================================================
# 配置防火墙
# ============================================================

config_firewall() {
    log_step "=========================================="
    log_step "配置防火墙"
    log_step "=========================================="
    
    if systemctl is-active firewalld &>/dev/null; then
        log_info "配置防火墙规则..."
        firewall-cmd --permanent --add-port=${HTTP_PORT}/tcp 2>/dev/null || true
        firewall-cmd --permanent --add-port=${WS_PORT}/tcp 2>/dev/null || true
        firewall-cmd --permanent --add-port=${TCP_PORT}/tcp 2>/dev/null || true
        firewall-cmd --permanent --add-port=${MYSQL_PORT}/tcp 2>/dev/null || true
        firewall-cmd --permanent --add-port=${REDIS_PORT}/tcp 2>/dev/null || true
        firewall-cmd --reload 2>/dev/null || true
    fi
    
    # SELinux
    if [ -f /etc/selinux/config ]; then
        log_info "配置 SELinux..."
        sed -i 's/SELINUX=enforcing/SELINUX=permissive/' /etc/selinux/config 2>/dev/null || true
    fi
    
    log_success "防火墙配置完成"
}

# ============================================================
# 创建 systemd 服务
# ============================================================

create_service() {
    log_step "=========================================="
    log_step "创建 systemd 服务"
    log_step "=========================================="
    
    # 后端服务
    cat > /etc/systemd/system/lumenim-backend.service << 'EOF'
[Unit]
Description=LumenIM Backend Service
After=network.target mysql.service redis.service docker.service

[Service]
Type=simple
User=www-data
Group=www-data
WorkingDirectory=/var/www/lumenim/backend
Environment="PATH=/usr/local/go/bin:/usr/local/node/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
Environment="PORT=9501"
ExecStart=/var/www/lumenim/backend/bin/lumenim
Restart=on-failure
RestartSec=5s
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF

    # 前端服务
    cat > /etc/systemd/system/lumenim-frontend.service << 'EOF'
[Unit]
Description=LumenIM Frontend Service
After=network.target

[Service]
Type=simple
User=www-data
Group=www-data
WorkingDirectory=/var/www/lumenim/front
Environment="PATH=/usr/local/node/bin:$PATH"
ExecStart=/usr/local/node/bin/node /var/www/lumenim/front/node_modules/.bin/vite --port 5173
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
    log_step "=========================================="
    log_step "启动服务"
    log_step "=========================================="
    
    # Docker
    if command -v docker &>/dev/null; then
        log_info "启动 Docker..."
        systemctl start docker 2>/dev/null || service docker start 2>/dev/null || true
        docker start lumenim-mysql 2>/dev/null || true
        docker start lumenim-redis 2>/dev/null || true
    fi
    
    log_success "服务启动完成"
}

# ============================================================
# 检查服务
# ============================================================

check_services() {
    log_step "=========================================="
    log_step "检查服务状态"
    log_step "=========================================="
    
    # 端口
    echo ""
    log_detail "端口状态:"
    for port in $HTTP_PORT $WS_PORT $TCP_PORT $MYSQL_PORT $REDIS_PORT; do
        if lsof -i:$port &>/dev/null 2>&1; then
            log_success "端口 $port: 已占用"
        else
            log_warn "端口 $port: 未占用"
        fi
    done
    
    # Docker
    if command -v docker &>/dev/null; then
        echo ""
        log_detail "Docker 容器:"
        docker ps -a --filter "name=lumenim" --format "table {{.Names}}\t{{.Status}}" 2>/dev/null || true
    fi
    
    # 进程
    echo ""
    pgrep -f lumenim &>/dev/null && log_success "后端: 运行中" || log_warn "后端: 未运行"
    pgrep -f vite &>/dev/null && log_success "前端: 运行中" || log_warn "前端: 未运行"
}

# ============================================================
# 帮助
# ============================================================

show_help() {
    cat << EOF
LumenIM CentOS 7 离线部署脚本

使用方法:
    sudo ./install-offline.sh [选项]

选项:
    -h, --help          显示帮助
    -c, --check        检查环境
    -d, --deps         安装系统依赖
    -g, --go          安装 Go
    -n, --node        安装 Node.js
    -m, --mysql       安装 MySQL
    -r, --redis       安装 Redis
    -p, --protobuf    安装 protobuf
    -s, --services    启动服务
    -a, --all         完整安装
    --dir=目录         离线包目录

示例:
    # 完整安装
    sudo ./install-offline.sh --all --dir=/mnt/packages

    # 检查环境
    ./install-offline.sh --check --dir=/mnt/packages

    # 分步安装
    sudo ./install-offline.sh --dir=/mnt/packages --deps
    sudo ./install-offline.sh --dir=/mnt/packages --go --node
    sudo ./install-offline.sh --dir=/mnt/packages --mysql --redis

EOF
}

# ============================================================
# 主函数
# ============================================================

main() {
    echo "=========================================="
    echo "LumenIM 离线部署脚本 v1.0.1"
    echo "=========================================="
    echo ""
    
    # 参数
    DO_CHECK=false
    DO_DEPS=false
    DO_GO=false
    DO_NODE=false
    DO_MYSQL=false
    DO_REDIS=false
    DO_PROTOBUF=false
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
            -s|--services)
                DO_SERVICES=true
                shift
                ;;
            -a|--all)
                DO_ALL=true
                shift
                ;;
            --dir=*)
                OFFLINE_DIR="${1#*=}"
                shift
                ;;
            *)
                shift
                ;;
        esac
    done
    
    log_info "离线目录: $OFFLINE_DIR"
    
    # 检查环境
    if [ "$DO_CHECK" = true ]; then
        check_env
        exit 0
    fi
    
    # 需要 root
    if [ "$DO_ALL" = true ]; then
        check_root
    fi
    
    # 执行
    if [ "$DO_ALL" = true ] || [ "$DO_DEPS" = true ]; then
        check_env
        install_deps
    fi
    
    if [ "$DO_ALL" = true ] || [ "$DO_GO" = true ]; then
        install_go
    fi
    
    if [ "$DO_ALL" = true ] || [ "$DO_NODE" = true ]; then
        install_node
    fi
    
    if [ "$DO_ALL" = true ] || [ "$DO_MYSQL" = true ]; then
        install_docker
        install_mysql
    fi
    
    if [ "$DO_ALL" = true ] || [ "$DO_REDIS" = true ]; then
        install_redis
    fi
    
    if [ "$DO_ALL" = true ] || [ "$DO_PROTOBUF" = true ]; then
        install_protobuf
    fi
    
    if [ "$DO_ALL" = true ]; then
        config_firewall
        create_service
    fi
    
    if [ "$DO_ALL" = true ] || [ "$DO_SERVICES" = true ]; then
        start_services
        check_services
    fi
    
    echo ""
    log_success "离线部署完成！"
}

main "$@"