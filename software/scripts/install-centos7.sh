#!/bin/bash
#
# LumenIM CentOS 7 自动化部署脚本
# Automated deployment script for LumenIM on CentOS 7
#
# 使用方法: sudo ./install-centos7.sh [选项]
# Usage: sudo ./install-centos7.sh [options]
#
# 版本: 1.1.0
# 更新日期: 2026-04-09
# 适配系统: CentOS 7.x（含 EOL 镜像源自动修复）

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

# 运行用户
RUN_USER="root"

# 服务端口
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

# JWT 配置
JWT_SECRET="836c3fea9bba4e04d51bd0fbcc5"

# 是否使用 Docker 容器（推荐 CentOS 7）
USE_DOCKER=true

# 下载源配置
OFFLINE_PACKAGE_DIR=""

# ============================================================
# 版本定义（CentOS 7 兼容版本）
# ============================================================

# Go 版本（推荐 1.21.x，兼容性更好）
GO_VERSION="1.21.14"
GO_VERSION_SHORT="1.21"

# Node.js 版本（使用 18.x LTS，CentOS 7 兼容）
NODE_VERSION="18.20.5"
NODE_MAJOR_VERSION=18

# pnpm 版本
PNPM_VERSION="8.15.0"

# MySQL 版本（使用 MySQL 8.0.35 兼容性更好）
MYSQL_VERSION="8.0.35"

# Redis 版本
REDIS_VERSION="7.4.1"

# Protocol Buffers 版本
PROTOBUF_VERSION="25.1"

# Electron 版本（使用较低版本）
ELECTRON_VERSION="28.3.3"

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
# CentOS 7 EOL 镜像源修复函数
# 解决 CentOS 7 于 2024-06-30 生命周期结束后官方源不可用的问题
# ============================================================

fix_centos7_mirror() {
    # 检查是否为 CentOS 7
    if [ ! -f /etc/centos-release ]; then
        return 0
    fi
    
    local centos_version=$(grep -oE '[0-9]+\.[0-9]+' /etc/centos-release | head -1)
    if [[ "$centos_version" != "7."* ]]; then
        return 0
    fi
    
    log_info "检测到 CentOS 7.x，官方源已 EOL，正在替换为归档镜像源..."
    
    # 备份并删除原有的 CentOS-Base.repo（避免重复配置问题）
    if [ -f /etc/yum.repos.d/CentOS-Base.repo ]; then
        if [ ! -f /etc/yum.repos.d/CentOS-Base.repo.bak ]; then
            cp /etc/yum.repos.d/CentOS-Base.repo /etc/yum.repos.d/CentOS-Base.repo.bak
        fi
        mv /etc/yum.repos.d/CentOS-Base.repo /etc/yum.repos.d/CentOS-Base.repo.disabled
    fi
    
    # 删除其他可能冲突的 CentOS 源文件
    for repo_file in /etc/yum.repos.d/CentOS-CR.repo \
                     /etc/yum.repos.d/CentOS-CBS.repo \
                     /etc/yum.repos.d/CentOS-centosplus.repo \
                     /etc/yum.repos.d/CentOS-Debuginfo.repo \
                     /etc/yum.repos.d/CentOS-Fasttrack.repo \
                     /etc/yum.repos.d/CentOS-Sources.repo; do
        if [ -f "$repo_file" ]; then
            mv "$repo_file" "$repo_file.disabled" 2>/dev/null || true
        fi
    done
    
    # 替换为阿里云 Vault 源（使用唯一的 [vault-base] 段落名避免冲突）
    cat > /etc/yum.repos.d/CentOS-Vault.repo << 'EOF'
[vault-base]
name=CentOS-7 - Base - Vault - Aliyun
baseurl=https://mirrors.aliyun.com/centos-vault/7.9.2009/os/x86_64/
gpgcheck=1
gpgkey=https://mirrors.aliyun.com/centos/RPM-GPG-KEY-CentOS-7
enabled=1
priority=1

[vault-extras]
name=CentOS-7 - Extras - Vault - Aliyun
baseurl=https://mirrors.aliyun.com/centos-vault/7.9.2009/extras/x86_64/
gpgcheck=1
gpgkey=https://mirrors.aliyun.com/centos/RPM-GPG-KEY-CentOS-7
enabled=1
priority=1

[vault-updates]
name=CentOS-7 - Updates - Vault - Aliyun
baseurl=https://mirrors.aliyun.com/centos-vault/7.9.2009/updates/x86_64/
gpgcheck=1
gpgkey=https://mirrors.aliyun.com/centos/RPM-GPG-KEY-CentOS-7
enabled=1
priority=1
EOF

    # 禁用旧的 EPEL 源并移除（如果存在）
    if [ -f /etc/yum.repos.d/epel.repo ]; then
        mv /etc/yum.repos.d/epel.repo /etc/yum.repos.d/epel.repo.disabled 2>/dev/null || true
    fi
    if [ -f /etc/yum.repos.d/epel-testing.repo ]; then
        mv /etc/yum.repos.d/epel-testing.repo /etc/yum.repos.d/epel-testing.repo.disabled 2>/dev/null || true
    fi
    
    # 添加腾讯云 EPEL Vault 源
    cat > /etc/yum.repos.d/epel-vault.repo << 'EOF'
[epel-vault]
name=Extra Packages for Enterprise Linux 7 - x86_64 - Vault
baseurl=https://mirrors.cloud.tencent.com/epel/7/x86_64/
gpgcheck=0
enabled=1
priority=10
EOF

    # 清理缓存并重建
    yum clean all
    yum makecache fast
    
    log_success "镜像源替换完成（已切换至阿里云 Vault + 腾讯云 EPEL Vault）"
}

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

install_yum() {
    local pkg="$1"
    log_info "安装软件包: $pkg"
    yum install -y "$pkg"
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

# ============================================================
# 环境检查
# ============================================================

check_environment() {
    log_step "检查 CentOS 7 服务器环境..."
    
    echo ""
    echo "=========================================="
    echo "系统信息"
    echo "=========================================="
    
    # 检查操作系统
    if [ -f /etc/centos-release ]; then
        log_info "操作系统: $(cat /etc/centos-release)"
    elif [ -f /etc/redhat-release ]; then
        log_info "操作系统: $(cat /etc/redhat-release)"
    fi
    
    # 检查架构
    log_info "系统架构: $(uname -m)"
    
    # 检查内核版本
    log_info "内核版本: $(uname -r)"
    
    # 检查 glibc 版本
    log_info "glibc 版本: $(ldd --version | head -n1)"
    
    # 检查 GCC 版本
    if check_command gcc; then
        log_info "GCC 版本: $(gcc --version | head -n1)"
    else
        log_warn "GCC: 未安装"
    fi
    
    # 检查内存
    log_info "总内存: $(free -h | awk '/^Mem:/{print $2}')"
    
    # 检查磁盘空间
    log_info "可用空间: $(df -h / | awk 'NR==2{print $4}')"
    
    # 检查 Docker
    if check_command docker; then
        log_success "Docker: 已安装"
    else
        log_warn "Docker: 未安装"
    fi
    
    echo ""
    log_success "环境检查完成"
}

# ============================================================
# 安装 Docker（CentOS 7 推荐方案）
# ============================================================

install_docker() {
    log_step "安装 Docker..."
    
    if check_command docker; then
        log_info "Docker 已安装"
        docker --version
        return 0
    fi
    
    # 安装 Docker
    log_info "安装 Docker..."
    yum install -y yum-utils
    
    # 添加 Docker 官方源（CentOS 7）
    yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
    
    # 安装 Docker（如果官方源失败，尝试使用阿里云镜像源）
    if ! yum install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin 2>/dev/null; then
        log_warn "Docker 官方源安装失败，尝试使用阿里云镜像源..."
        
        # 使用阿里云 Docker 镜像源
        cat > /etc/yum.repos.d/docker-ce.repo << 'EOF'
[docker-ce-stable]
name=Docker CE Stable - Aliyun
baseurl=https://mirrors.aliyun.com/docker-ce/linux/centos/7/x86_64/stable/
gpgcheck=1
gpgkey=https://mirrors.aliyun.com/docker-ce/linux/centos/gpg
enabled=1
EOF
        yum install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    fi
    
    # 启动 Docker
    systemctl start docker
    systemctl enable docker
    
    # 配置镜像加速
    if [ ! -f /etc/docker/daemon.json ]; then
        mkdir -p /etc/docker
        cat > /etc/docker/daemon.json << 'EOF'
{
    "registry-mirrors": [
        "https://docker.mirrors.ustc.edu.cn",
        "https://hub-mirror.c.163.com"
    ]
}
EOF
        systemctl restart docker
    fi
    
    log_success "Docker 安装完成"
    docker --version
}

# ============================================================
# 安装系统依赖
# ============================================================

install_system_deps() {
    log_step "安装系统依赖..."
    
    # CentOS 7 EOL 修复：替换为国内镜像源
    fix_centos7_mirror
    
    echo "=========================================="
    echo "更新软件源"
    echo "=========================================="
    
    # 安装 EPEL Vault 源（已在 fix_centos7_mirror 中配置）
    
    # 安装基础依赖
    install_yum "wget"
    install_yum "curl"
    install_yum "git"
    install_yum "unzip"
    install_yum "tar"
    install_yum "xz"
    install_yum "jq"
    install_yum "net-tools"
    install_yum "lsof"
    install_yum "gcc"
    install_yum "gcc-c++"
    install_yum "make"
    install_yum "openssl"
    install_yum "perl"
    
    # 安装开发工具
    yum groupinstall -y "Development Tools"
    
    log_success "系统依赖安装完成"
}

# ============================================================
# 安装 Go 环境（兼容版本）
# ============================================================

install_go() {
    log_step "安装 Go 环境..."
    
    local go_link="/usr/local/go"
    
    # 检查是否已安装
    if [ -f "$go_link/bin/go" ]; then
        local current_version=$("$go_link/bin/go" version 2>/dev/null | grep -oP 'go\d+\.\d+\.\d+' || true)
        if [ "$current_version" = "go${GO_VERSION}" ]; then
            log_info "Go ${GO_VERSION} 已安装"
            return 0
        fi
    fi
    
    # 下载兼容版本
    log_info "下载 Go ${GO_VERSION}..."
    cd /tmp
    wget -q "https://go.dev/dl/go${GO_VERSION}.linux-amd64.tar.gz" -O go.tar.gz
    
    # 安装
    rm -rf "$go_link"
    tar -xzf go.tar.gz -C /tmp/
    mv /tmp/go "$go_link"
    rm -f go.tar.gz
    
    # 配置环境变量
    cat > /etc/profile.d/go.sh << EOF
export GOROOT=/usr/local/go
export PATH=\$PATH:\$GOROOT/bin
export GOPATH=\$HOME/go
EOF
    chmod +x /etc/profile.d/go.sh
    
    # 设置当前会话
    export GOROOT=/usr/local/go
    export PATH=$PATH:$GOROOT/bin
    
    log_success "Go ${GO_VERSION} 安装完成"
    "$go_link/bin/go" version
}

# ============================================================
# 安装 Node.js（CentOS 7 兼容方案）
# ============================================================

install_nodejs() {
    log_step "安装 Node.js 环境..."
    
    local node_link="/usr/local/node"
    
    # 检查是否已安装
    if [ -f "$node_link/bin/node" ]; then
        local current_version=$("$node_link/bin/node" --version 2>/dev/null || true)
        if [ "$current_version" = "v${NODE_VERSION}" ]; then
            log_info "Node.js ${NODE_VERSION} 已安装"
            return 0
        fi
    fi
    
    # 使用 NodeSource 仓库安装 LTS 版本
    log_info "安装 Node.js ${NODE_MAJOR_VERSION}.x..."
    
    # 添加 NodeSource 仓库
    curl -fsSL "https://rpm.nodesource.com/setup_${NODE_MAJOR_VERSION}.x" | bash -
    
    # 安装 Node.js
    yum install -y nodejs
    
    # 安装 pnpm
    log_info "安装 pnpm..."
    npm install -g pnpm@${PNPM_VERSION}
    
    log_success "Node.js 安装完成"
    node --version
    pnpm --version
}

# ============================================================
# 安装 MySQL（使用 Docker 或官方 RPM）
# ============================================================

install_mysql() {
    log_step "安装 MySQL..."
    
    if check_command docker; then
        # 使用 Docker 安装
        log_info "使用 Docker 安装 MySQL..."
        
        # 检查是否已有容器
        if docker ps -a | grep -q mysql; then
            log_info "MySQL 容器已存在"
            return 0
        fi
        
        # 创建 MySQL 数据目录
        create_directory "$DATA_DIR/mysql" "root"
        
        # 启动 MySQL 容器
        docker run -d \
            --name lumenim-mysql \
            -e MYSQL_ROOT_PASSWORD="$MYSQL_ROOT_PASSWORD" \
            -e MYSQL_DATABASE="$MYSQL_DATABASE" \
            -e MYSQL_USER="$MYSQL_USER" \
            -e MYSQL_PASSWORD="$MYSQL_PASSWORD" \
            -p 3306:3306 \
            -v "$DATA_DIR/mysql":/var/lib/mysql \
            mysql:${MYSQL_VERSION}
        
        # 等待 MySQL 启动
        log_info "等待 MySQL 启动..."
        sleep 30
        
        log_success "MySQL Docker 容器启动完成"
    else
        # 直接安装
        log_info "安装 MySQL 服务器..."
        yum install -y mysql-server
        systemctl start mysqld
        systemctl enable mysqld
        
        # 初始化
        log_info "初始化 MySQL..."
        systemctl start mysqld
    fi
}

# ============================================================
# 安装 Redis（源码编译）
# ============================================================

install_redis() {
    log_step "安装 Redis..."
    
    if check_command docker; then
        # 使用 Docker 安装
        log_info "使用 Docker 安装 Redis..."
        
        if docker ps -a | grep -q redis; then
            log_info "Redis 容器已存在"
            return 0
        fi
        
        create_directory "$DATA_DIR/redis" "root"
        
        docker run -d \
            --name lumenim-redis \
            -p 6379:6379 \
            -v "$DATA_DIR/redis":/data \
            redis:${REDIS_VERSION} redis-server --appendonly yes
        
        log_success "Redis Docker 容器启动完成"
    else
        # 源码编译安装
        log_info "从源码编译安装 Redis..."
        
        cd /tmp
        wget -q "https://github.com/redis/redis/archive/refs/tags/${REDIS_VERSION}.tar.gz" -O redis.tar.gz
        tar -xzf redis.tar.gz
        cd "redis-${REDIS_VERSION}"
        
        make -j$(ngrep)
        make install PREFIX="${INSTALL_ROOT}/redis"
        
        log_success "Redis 安装完成"
    fi
}

# ============================================================
# 安装 Protocol Buffers
# ============================================================

install_protobuf() {
    log_step "安装 Protocol Buffers..."
    
    local protoc_dir="${INSTALL_ROOT}/protobuf"
    
    # 下载
    cd /tmp
    wget -q "https://github.com/protocolbuffers/protobuf/releases/download/v${PROTOBUF_VERSION}/protoc-${PROTOBUF_VERSION}-linux-x86_64.zip" -O protoc.zip
    
    # 安装
    mkdir -p "$protoc_dir"
    unzip -qo protoc.zip -d "$protoc_dir"
    cp -f "$protoc_dir/bin/protoc" /usr/local/bin/
    
    rm -f protoc.zip
    
    log_success "Protocol Buffers 安装完成"
    protoc --version
}

# ============================================================
# 配置防火墙
# ============================================================

configure_firewall() {
    log_step "配置防火墙..."
    
    # 检查 firewalld
    if check_command firewall-cmd; then
        log_info "配置 firewalld..."
        
        # 检查是否运行
        if systemctl is-active firewalld &>/dev/null; then
            firewall-cmd --permanent --add-port=${HTTP_PORT}/tcp
            firewall-cmd --permanent --add-port=${WS_PORT}/tcp
            firewall-cmd --permanent --add-port=${TCP_PORT}/tcp
            firewall-cmd --permanent --add-port=${MYSQL_PORT}/tcp
            firewall-cmd --permanent --add-port=${REDIS_PORT}/tcp
            firewall-cmd --reload
            
            log_success "firewalld 配置完成"
        else
            log_warn "firewalld 未运行，跳过配置"
        fi
    else
        log_info "firewalld 未安装，跳过"
    fi
    
    # 配置 SELinux（如有）
    if [ -f /etc/selinux/config ]; then
        local selinux_status=$(grep "^SELINUX=" /etc/selinux/config | cut -d= -f2)
        if [ "$selinux_status" = "enforcing" ]; then
            log_warn "SELinux 处于强制模式，建议将其设置为 permissive"
        fi
    fi
}

# ============================================================
# 创建 systemd 服务
# ============================================================

create_systemd_service() {
    log_step "创建 systemd 服务..."
    
    # 获取 Node.js 路径
    local node_path=$(which node 2>/dev/null || echo "/usr/bin/node")
    local pnpm_path=$(which pnpm 2>/dev/null || echo "/usr/bin/pnpm")
    
    # 后端服务
    cat > /etc/systemd/system/lumenim-backend.service << EOF
[Unit]
Description=LumenIM Backend Service
After=network.target mysql.service redis.service docker.service

[Service]
Type=simple
User=$RUN_USER
Group=$RUN_USER
WorkingDirectory=$PROJECT_DIR/backend
Environment="PATH=$node_path:/usr/local/go/bin:\$PATH"
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
Environment="PATH=$node_path:$pnpm_path:/usr/local/go/bin:\$PATH"
ExecStart=$node_path $PROJECT_DIR/front/node_modules/.bin/vite --port 5173
Restart=on-failure
RestartSec=5s

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    log_success "systemd 服务创建完成"
}

# ============================================================
# 服务管理
# ============================================================

start_services() {
    log_step "启动服务..."
    
    # 启动 Docker 容器
    if check_command docker; then
        log_info "启动 Docker 容器..."
        docker start lumenim-mysql 2>/dev/null || true
        docker start lumenim-redis 2>/dev/null || true
    fi
    
    # 启动后端服务
    log_info "启动后端服务..."
    systemctl start lumenim-backend
    systemctl enable lumenim-backend
    
    log_success "服务启动完成"
}

check_services() {
    log_step "检查服务状态..."
    
    echo ""
    echo "=========================================="
    echo "服务状态"
    echo "=========================================="
    
    # 检查端口
    for port in $HTTP_PORT $WS_PORT $TCP_PORT $MYSQL_PORT $REDIS_PORT; do
        if lsof -i:$port &>/dev/null; then
            log_success "端口 $port: 已占用"
        else
            log_warn "端口 $port: 未占用"
        fi
    done
    
    # 检查 Docker 容器
    if check_command docker; then
        docker ps --filter "name=lumenim" --format "table {{.Names}}\t{{.Status}}"
    fi
    
    # 检查进程
    pgrep -f lumenim >/dev/null && log_success "后端进程: 运行中" || log_warn "后端进程: 未运行"
    pgrep -f vite >/dev/null && log_success "前端进程: 运行中" || log_warn "前端进程: 未运行"
}

# ============================================================
# 显示帮助
# ============================================================

show_help() {
    cat << EOF
LumenIM CentOS 7 自动化部署脚本

使用方法:
    sudo ./install-centos7.sh [选项]

选项:
    -h, --help              显示帮助信息
    -c, --check            仅检查环境
    -d, --deps             仅安装系统依赖
    -g, --go              仅安装 Go
    -n, --node            仅安装 Node.js
    -m, --mysql           仅安装 MySQL
    -r, --redis           仅安装 Redis
    -p, --protobuf        仅安装 Protocol Buffers
    -s, --services        仅启动服务
    -a, --all             完整安装（默认）
    --no-docker           不使用 Docker（使用本地安装）
    --offline=[目录]      离线包目录

兼容性说明:
- Go: ${GO_VERSION} (CentOS 7 兼容)
- Node.js: ${NODE_VERSION} (LTS, CentOS 7 兼容)
- MySQL: ${MYSQL_VERSION}
- Redis: ${REDIS_VERSION}

示例:
    # 完整安装（推荐 Docker 方案）
    sudo ./install-centos7.sh --all

    # 不使用 Docker
    sudo ./install-centos7.sh --all --no-docker

    # 仅检查环境
    ./install-centos7.sh --check

EOF
}

# ============================================================
# 主函数
# ============================================================

main() {
    echo "=========================================="
    echo "LumenIM CentOS 7 部署脚本"
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
            --no-docker)
                USE_DOCKER=false
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
    
    # 需要 root 权限
    if [ "$DO_ALL" = true ] || [ "$DO_DEPS" = true ]; then
        check_root
    fi
    
    # 执行任务
    if [ "$DO_ALL" = true ] || [ "$DO_DEPS" = true ]; then
        check_environment
        install_system_deps
    fi
    
    # 安装 Docker（推荐）
    if [ "$USE_DOCKER" = true ] && [ "$DO_ALL" = true ]; then
        install_docker
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
        create_systemd_service
        configure_firewall
    fi
    
    if [ "$DO_ALL" = true ] || [ "$DO_SERVICES" = true ]; then
        start_services
        check_services
    fi
    
    echo ""
    log_success "CentOS 7 部署完成！"
    echo ""
    echo "=========================================="
    echo "访问信息"
    echo "=========================================="
    echo "前端: http://localhost:${HTTP_PORT}"
    echo "后端 API: http://localhost:${HTTP_PORT}"
    echo "WebSocket: ws://localhost:${WS_PORT}"
    echo ""
    
    if [ "$USE_DOCKER" = true ]; then
        echo "MySQL: localhost:3306 (Docker 容器)"
        echo "Redis: localhost:6379 (Docker 容器)"
    fi
}

# 执行主函数
main "$@"