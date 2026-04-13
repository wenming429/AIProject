#!/bin/bash
# LumenIM 一键部署脚本 (Linux/macOS)
# 版本: 1.0.0
# 更新日期: 2026-04-07

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 日志函数
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 检查是否为 root
check_root() {
    if [[ $EUID -eq 0 ]]; then
        log_warning "Running as root. Some operations may fail."
    fi
}

# 安装 Go
install_go() {
    log_info "Installing Go 1.25.0..."
    
    if command -v go &> /dev/null; then
        GO_VERSION=$(go version | grep -oP 'go\d+\.\d+')
        log_warning "Go is already installed: $GO_VERSION"
        read -p "Do you want to reinstall? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            return
        fi
    fi
    
    cd /tmp
    wget -q https://go.dev/dl/go1.25.0.linux-amd64.tar.gz
    sudo rm -rf /usr/local/go
    sudo tar -C /usr/local -xzf go1.25.0.linux-amd64.tar.gz
    rm go1.25.0.linux-amd64.tar.gz
    
    # 添加到 PATH
    if ! grep -q '/usr/local/go/bin' ~/.bashrc; then
        echo 'export PATH=$PATH:/usr/local/go/bin' >> ~/.bashrc
    fi
    export PATH=$PATH:/usr/local/go/bin
    
    log_success "Go installed successfully"
}

# 安装 Node.js
install_nodejs() {
    log_info "Installing Node.js 22.x..."
    
    if command -v node &> /dev/null; then
        NODE_VERSION=$(node --version)
        log_warning "Node.js is already installed: $NODE_VERSION"
        read -p "Do you want to reinstall? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            return
        fi
    fi
    
    curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash -
    sudo apt-get install -y nodejs
    sudo npm install -g pnpm
    
    log_success "Node.js installed successfully"
}

# 安装 MySQL
install_mysql() {
    log_info "Installing MySQL 8.0..."
    
    if command -v mysql &> /dev/null; then
        MYSQL_VERSION=$(mysql --version)
        log_warning "MySQL is already installed: $MYSQL_VERSION"
        read -p "Do you want to reinstall? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            return
        fi
    fi
    
    sudo apt update
    sudo apt install -y mysql-server
    sudo systemctl start mysql
    sudo systemctl enable mysql
    
    log_success "MySQL installed successfully"
}

# 安装 Redis
install_redis() {
    log_info "Installing Redis..."
    
    if command -v redis-server &> /dev/null; then
        REDIS_VERSION=$(redis-server --version)
        log_warning "Redis is already installed: $REDIS_VERSION"
        read -p "Do you want to reinstall? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            return
        fi
    fi
    
    sudo apt update
    sudo apt install -y redis-server
    sudo systemctl start redis-server
    sudo systemctl enable redis-server
    
    log_success "Redis installed successfully"
}

# 安装 Docker
install_docker() {
    log_info "Installing Docker..."
    
    if command -v docker &> /dev/null; then
        log_warning "Docker is already installed"
        return
    fi
    
    curl -fsSL https://get.docker.com -o get-docker.sh
    sudo sh get-docker.sh
    rm get-docker.sh
    sudo usermod -aG docker $USER
    
    log_success "Docker installed successfully"
}

# 安装 Proto 工具
install_proto_tools() {
    log_info "Installing Protocol Buffers tools..."
    
    # protoc
    if ! command -v protoc &> /dev/null; then
        PROTOC_VERSION=25.1
        cd /tmp
        wget -q https://github.com/protocolbuffers/protobuf/releases/download/v${PROTOC_VERSION}/protoc-${PROTOC_VERSION}-linux-x86_64.zip
        sudo unzip -o protoc-${PROTOC_VERSION}-linux-x86_64.zip -d /usr/local
        rm protoc-${PROTOC_VERSION}-linux-x86_64.zip
        log_success "protoc installed"
    fi
    
    # Go tools
    log_info "Installing Go protobuf tools..."
    go install google.golang.org/protobuf/cmd/protoc-gen-go@latest
    go install github.com/envoyproxy/protoc-gen-validate@latest
    
    log_success "Proto tools installed"
}

# 配置环境变量
setup_env() {
    log_info "Setting up environment variables..."
    
    cat >> ~/.bashrc << 'EOF'
# LumenIM Environment
export GOROOT=/usr/local/go
export GOPATH=$HOME/go
export PATH=$PATH:$GOROOT/bin:$GOPATH/bin

# Go Module Proxy (China mirror)
export GOPROXY=https://goproxy.cn,direct

# Electron mirror
export ELECTRON_MIRROR=https://npmmirror.com/mirrors/electron/
EOF
    
    log_success "Environment variables configured"
}

# 验证安装
verify_install() {
    log_info "Verifying installation..."
    
    echo ""
    echo "========================================"
    echo "  Installation Verification"
    echo "========================================"
    echo ""
    
    local errors=0
    
    check_cmd() {
        if command -v $1 &> /dev/null; then
            echo -e "[OK] $1: $(eval $2)"
        else
            echo -e "[FAIL] $1 not found"
            errors=$((errors + 1))
        fi
    }
    
    check_cmd "go" "go version | grep -oP 'go\d+\.\d+\.\d+'"
    check_cmd "node" "node --version"
    check_cmd "npm" "npm --version"
    check_cmd "pnpm" "pnpm --version"
    check_cmd "git" "git --version"
    check_cmd "mysql" "mysql --version | grep -oP '\d+\.\d+'"
    check_cmd "redis-server" "redis-server --version | grep -oP 'v=\d+\.\d+'"
    check_cmd "protoc" "protoc --version"
    
    echo ""
    if [[ $errors -eq 0 ]]; then
        log_success "All checks passed!"
    else
        log_error "$errors check(s) failed!"
    fi
    
    return $errors
}

# 主菜单
show_menu() {
    echo ""
    echo "========================================"
    echo "  LumenIM 快速部署"
    echo "========================================"
    echo ""
    echo "1. 安装所有组件"
    echo "2. 仅安装核心组件 (Go, Node.js)"
    echo "3. 仅安装数据库 (MySQL, Redis)"
    echo "4. 仅安装开发工具"
    echo "5. 安装 Docker (可选)"
    echo "6. 验证安装"
    echo "7. 配置环境变量"
    echo "0. 退出"
    echo ""
    read -p "请选择操作 [0-7]: " choice
}

# 主程序
main() {
    check_root
    
    if [[ $# -eq 0 ]]; then
        show_menu
    else
        choice=$1
    fi
    
    case $choice in
        1)
            install_go
            install_nodejs
            install_mysql
            install_redis
            install_proto_tools
            setup_env
            verify_install
            ;;
        2)
            install_go
            install_nodejs
            verify_install
            ;;
        3)
            install_mysql
            install_redis
            verify_install
            ;;
        4)
            install_proto_tools
            ;;
        5)
            install_docker
            ;;
        6)
            verify_install
            ;;
        7)
            setup_env
            ;;
        0)
            log_info "Exiting..."
            exit 0
            ;;
        *)
            log_error "Invalid option"
            exit 1
            ;;
    esac
}

# 执行
main "$@"
