#!/bin/bash
#===============================================================================
# LumenIM 服务器初始化脚本
# 使用说明: 在目标 CentOS 7 服务器上以 root 用户执行此脚本
#===============================================================================

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# 日志函数
log_info() {
    echo -e "${GREEN}[INFO]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

#===============================================================================
# 配置
#===============================================================================
MYSQL_ROOT_PASSWORD="wenming429"
MYSQL_DATABASE="go_chat"
MYSQL_USER="lumenim"
MYSQL_PASSWORD="lumenim123"

DEPLOY_DIR="/opt/lumenim"
DATA_DIR="/var/lib/lumenim"

#===============================================================================
# 检查是否为 root 用户
#===============================================================================
check_root() {
    if [ "$EUID" -ne 0 ]; then
        log_error "请使用 root 用户执行此脚本"
        exit 1
    fi
    log_info "Root 权限检查通过"
}

#===============================================================================
# 步骤 1: 更新系统
#===============================================================================
update_system() {
    log_info "========== 步骤 1: 更新系统 =========="
    yum update -y
    yum install -y epel-release
    log_info "系统更新完成"
}

#===============================================================================
# 步骤 2: 安装基础工具
#===============================================================================
install_basic_tools() {
    log_info "========== 步骤 2: 安装基础工具 =========="
    yum install -y wget curl git vim net-tools bind-utils yum-utils \
        device-mapper-persistent-data lvm2 jq tar gzip
    log_info "基础工具安装完成"
}

#===============================================================================
# 步骤 3: 安装 Docker
#===============================================================================
install_docker() {
    log_info "========== 步骤 3: 安装 Docker =========="

    if command -v docker &> /dev/null; then
        log_warn "Docker 已安装: $(docker --version)"
        return
    fi

    log_info "安装 container-selinux..."
    yum install -y http://mirror.centos.org/centos/7.9.2009/extras/x86_64/Packages/container-selinux-2.119.2-1.git875a4a4.el7.noarch.rpm

    log_info "添加 Docker 源..."
    yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo

    log_info "安装 Docker CE..."
    yum install -y docker-ce docker-ce-cli containerd.io

    log_info "启动 Docker 服务..."
    systemctl start docker
    systemctl enable docker

    log_info "Docker 安装完成: $(docker --version)"
}

#===============================================================================
# 步骤 4: 创建目录结构
#===============================================================================
create_directories() {
    log_info "========== 步骤 4: 创建目录结构 =========="
    mkdir -p ${DEPLOY_DIR}/{backend,frontend,config,images,logs}
    mkdir -p ${DATA_DIR}/{mysql,redis,minio}
    log_info "目录结构创建完成"
}

#===============================================================================
# 步骤 5: 安装 Go
#===============================================================================
install_go() {
    log_info "========== 步骤 5: 安装 Go =========="

    if command -v go &> /dev/null; then
        log_warn "Go 已安装: $(go version)"
        return
    fi

    log_info "下载并安装 Go 1.21.14..."
    cd /tmp
    wget -q https://go.dev/dl/go1.21.14.linux-amd64.tar.gz
    rm -rf /usr/local/go
    tar -C /usr/local -xzf go1.21.14.linux-amd64.tar.gz

    cat > /etc/profile.d/go.sh << 'EOF'
export GOROOT=/usr/local/go
export PATH=$PATH:$GOROOT/bin
export GOPATH=$HOME/go
EOF
    chmod +x /etc/profile.d/go.sh

    source /etc/profile.d/go.sh
    log_info "Go 安装完成: $(go version)"
}

#===============================================================================
# 步骤 6: 安装 Node.js
#===============================================================================
install_nodejs() {
    log_info "========== 步骤 6: 安装 Node.js =========="

    if command -v node &> /dev/null; then
        log_warn "Node.js 已安装: $(node --version)"
        return
    fi

    log_info "下载并安装 Node.js 16.20.5..."
    cd /tmp
    wget -q https://nodejs.org/dist/v16.20.5/node-v16.20.5-linux-x64.tar.xz
    rm -rf /usr/local/node
    tar -xJf node-v16.20.5-linux-x64.tar.xz
    mv node-v16.20.5-linux-x64 /usr/local/node

    log_info "安装 pnpm..."
    curl -fsSL https://get.pnpm.io/install.sh | sh -

    cat > /etc/profile.d/nodejs.sh << 'EOF'
export NODE_PREFIX=/usr/local/node
export PATH=$PATH:$NODE_PREFIX/bin:$HOME/.local/share/pnpm:$PATH
EOF
    chmod +x /etc/profile.d/nodejs.sh

    source /etc/profile.d/nodejs.sh
    log_info "Node.js 安装完成: $(node --version)"
    log_info "pnpm 安装完成: $(pnpm --version)"
}

#===============================================================================
# 步骤 7: 配置防火墙
#===============================================================================
configure_firewall() {
    log_info "========== 步骤 7: 配置防火墙 =========="
    local ports=(80 443 9501 9502 3306 6379 9000)
    for port in "${ports[@]}"; do
        firewall-cmd --permanent --add-port=${port}/tcp 2>/dev/null || true
    done
    firewall-cmd --reload
    log_info "防火墙配置完成"
}

#===============================================================================
# 步骤 8: 配置 SELinux
#===============================================================================
disable_selinux() {
    log_info "========== 步骤 8: 配置 SELinux =========="
    if getenforce | grep -q "Enforcing"; then
        log_warn "SELinux 设置为 Permissive 模式..."
        setenforce 0
        sed -i 's/SELINUX=enforcing/SELINUX=permissive/' /etc/selinux/config
    fi
    log_info "SELinux 配置完成"
}

#===============================================================================
# 步骤 9: 配置内核参数
#===============================================================================
configure_kernel() {
    log_info "========== 步骤 9: 配置内核参数 =========="
    cat >> /etc/sysctl.conf << 'EOF'
net.core.somaxconn = 65535
net.ipv4.tcp_max_syn_backlog = 65535
fs.file-max = 65535
vm.max_map_count = 262144
EOF
    sysctl -p
    log_info "内核参数配置完成"
}

#===============================================================================
# 步骤 10: 创建 systemd 服务
#===============================================================================
create_systemd_service() {
    log_info "========== 步骤 10: 创建 systemd 服务 =========="
    cat > /etc/systemd/system/lumenim-backend.service << 'EOF'
[Unit]
Description=LumenIM Backend Service
After=network.target docker.service
Wants=docker.service

[Service]
Type=simple
User=root
WorkingDirectory=/opt/lumenim/backend
ExecStart=/opt/lumenim/backend/lumenim
Restart=on-failure
RestartSec=5s
LimitNOFILE=65536
Environment="PATH=/usr/local/go/bin:/usr/local/node/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload
    log_info "systemd 服务创建完成"
}

#===============================================================================
# 步骤 11: 准备部署目录
#===============================================================================
prepare_deploy_directory() {
    log_info "========== 步骤 11: 准备部署目录 =========="
    cat > ${DEPLOY_DIR}/config/config.yaml.example << 'EOF'
app:
  env: production
  port: 9501

mysql:
  host: 127.0.0.1
  port: 3306
  username: root
  password: wenming429
  database: go_chat

redis:
  host: 127.0.0.1
  port: 6379
  database: 0
EOF
    chmod 644 ${DEPLOY_DIR}/config/config.yaml.example
    log_info "部署目录准备完成"
}

#===============================================================================
# 步骤 12: 验证环境
#===============================================================================
verify_environment() {
    log_info "========== 步骤 12: 验证环境 =========="
    echo ""
    echo "=========================================="
    echo "环境验证"
    echo "=========================================="
    [ -f "/etc/profile.d/go.sh" ] && source /etc/profile.d/go.sh
    [ -f "/etc/profile.d/nodejs.sh" ] && source /etc/profile.d/nodejs.sh

    echo "Docker:   $(command -v docker &>/dev/null && docker --version || echo '未安装')"
    echo "Go:       $(command -v go &>/dev/null && go version || echo '未安装')"
    echo "Node.js:  $(command -v node &>/dev/null && node --version || echo '未安装')"
    echo "pnpm:     $(command -v pnpm &>/dev/null && pnpm --version || echo '未安装')"
    echo ""
    echo "部署目录: ${DEPLOY_DIR}"
    echo "=========================================="
}

#===============================================================================
# 主函数
#===============================================================================
main() {
    echo ""
    echo "=============================================="
    echo "  LumenIM CentOS 7 服务器初始化脚本"
    echo "=============================================="
    echo ""
    check_root
    update_system
    install_basic_tools
    install_docker
    create_directories
    install_go
    install_nodejs
    configure_firewall
    disable_selinux
    configure_kernel
    create_systemd_service
    prepare_deploy_directory
    verify_environment
    echo ""
    log_info "=========================================="
    log_info "服务器初始化完成!"
    log_info "=========================================="
    echo ""
    echo "下一步: 上传部署包并执行部署"
    echo ""
}

main "$@"
