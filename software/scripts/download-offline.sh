#!/bin/bash
#
# LumenIM CentOS 7 离线依赖下载脚本
# Offline package download script for LumenIM CentOS 7
#
# 使用方法: ./download-offline.sh [目标目录]
# Usage: ./download-offline.sh [target_directory]
#
# 版本: 1.0.0
# 更新日期: 2026-04-08

set -e

# ============================================================
# 配置
# ============================================================

TARGET_DIR="${1:-./packages}"
CENTOS_VERSION="7"

# ============================================================
# 版本定义（CentOS 7 兼容版本）
# ============================================================

# Go 版本
GO_VERSION="1.21.14"

# Node.js 版本
NODE_VERSION="18.20.5"

# pnpm 版本
PNPM_VERSION="8.15.0"

# MySQL Docker 镜像版本
MYSQL_VERSION="8.0.35"

# Redis 版本
REDIS_VERSION="7.4.1"

# Protocol Buffers 版本
PROTOBUF_VERSION="25.1"

# Docker 版本（CentOS 7 专用）
DOCKER_VERSION="24.0.9"

# ============================================================
# 下载链接
# ============================================================

# Go
GO_URL="https://go.dev/dl/go${GO_VERSION}.linux-amd64.tar.gz"
GO_FILE="go${GO_VERSION}.linux-amd64.tar.gz"

# Node.js（使用二进制）
NODE_URL="https://nodejs.org/dist/v${NODE_VERSION}/node-v${NODE_VERSION}-linux-x64.tar.xz"
NODE_FILE="node-v${NODE_VERSION}-linux-x64.tar.xz"

# pnpm
PNPM_URL="https://github.com/pnpm/pnpm/releases/download/v${PNPM_VERSION}/pnpm-linux-x64"
PNPM_FILE="pnpm"

# Protocol Buffers
PROTOBUF_URL="https://github.com/protocolbuffers/protobuf/releases/download/v${PROTOBUF_VERSION}/protoc-${PROTOBUF_VERSION}-linux-x86_64.zip"
PROTOBUF_FILE="protoc-${PROTOBUF_VERSION}-linux-x86_64.zip"

# Docker（CentOS 7 离线安装包）
DOCKER_CE_REPO_URL="https://download.docker.com/linux/centos/7/x86_64/stable/Packages"
DOCKER_FILES=(
    "containerd.io-1.6.28-3.el7.x86_64.rpm"
    "docker-ce-24.0.9-3.el7.x86_64.rpm"
    "docker-ce-cli-24.0.9-3.el7.x86_64.rpm"
    "docker-ce-rootless-extras-24.0.9-3.el7.x86_64.rpm"
    "docker-buildx-plugin-0.12.1-1.el7.x86_64.rpm"
    "docker-compose-plugin-2.24.5-1.el7.x86_64.rpm"
    "containerd.io-debuginfo-1.6.28-3.el7.x86_64.rpm"
    "docker-ce-debuginfo-24.0.9-3.el7.x86_64.rpm"
)

#============================================================
# 颜色定义
# ============================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# ============================================================
# 函数
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

create_dir() {
    if [ ! -d "$TARGET_DIR" ]; then
        mkdir -p "$TARGET_DIR"
    fi
}

download() {
    local url="$1"
    local file="$2"
    local desc="$3"
    
    log_step "下载 $desc..."
    
    if [ -f "$TARGET_DIR/$file" ]; then
        log_warn "$desc 已存在，跳过"
        return 0
    fi
    
    if command -v curl &> /dev/null; then
        curl -L --progress-bar -o "$TARGET_DIR/$file" "$url"
    elif command -v wget &> /dev/null; then
        wget --show-progress -O "$TARGET_DIR/$file" "$url"
    else
        log_error "需要 curl 或 wget"
        return 1
    fi
    
    if [ $? -eq 0 ]; then
        log_info "$desc 下载完成"
    else
        log_error "$desc 下载失败"
        return 1
    fi
}

download_go() {
    download "$GO_URL" "$GO_FILE" "Go ${GO_VERSION}"
}

download_node() {
    download "$NODE_URL" "$NODE_FILE" "Node.js ${NODE_VERSION}"
}

download_pnpm() {
    download "$PNPM_URL" "$PNPM_FILE" "pnpm ${PNPM_VERSION}"
    chmod +x "$TARGET_DIR/$PNPM_FILE"
}

download_protobuf() {
    download "$PROTOBUF_URL" "$PROTOBUF_FILE" "Protocol Buffers ${PROTOBUF_VERSION}"
}

download_docker() {
    log_step "下载 Docker 离线安装包..."
    
    mkdir -p "$TARGET_DIR/docker"
    
    for pkg in "${DOCKER_FILES[@]}"; do
        local url="${DOCKER_CE_REPO_URL}/${pkg}"
        local file="docker/${pkg}"
        
        if [ -f "$TARGET_DIR/$file" ]; then
            log_warn "$pkg 已存在，跳过"
            continue
        fi
        
        log_info "下载 $pkg..."
        curl -L --progress-bar -o "$TARGET_DIR/$file" "$url" || wget -q -O "$TARGET_DIR/$file" "$url"
    done
    
    log_info "Docker 包下载完成"
}

download_all() {
    log_step "下载所有离线包..."
    
    create_dir
    
    download_go
    download_node
    download_pnpm
    download_protobuf
    
    echo ""
    log_info "离线包下载完成！"
    log_info "保存位置: $TARGET_DIR"
    
    # 显示文件列表
    echo ""
    echo "=========================================="
    echo "已下载的离线包:"
    echo "=========================================="
    ls -lh "$TARGET_DIR"
    ls -lh "$TARGET_DIR"/docker 2>/dev/null || true
}

# ============================================================
# 主函数
# ============================================================

main() {
    echo "=========================================="
    echo "LumenIM 离线包下载脚本"
    echo "=========================================="
    echo ""
    
    create_dir
    
    # 解析参数
    case "${1:-}" in
        -h|--help)
            echo "使用方法: $0 [选项] [目标目录]"
            echo ""
            echo "选项:"
            echo "  -h, --help       显示帮助"
            echo "  -a, --all      下载所有（默认）"
            echo "  -g, --go       仅下载 Go"
            echo "  -n, --node     仅下载 Node.js"
            echo "  -p, --pnpm     仅下载 pnpm"
            echo "  -d, --docker  下载 Docker"
            echo "  -t, --tools   下载工具链"
            exit 0
            ;;
        -g|--go)
            download_go
            ;;
        -n|--node)
            download_node
            ;;
        -p|--pnpm)
            download_pnpm
            ;;
        -d|--docker)
            download_docker
            ;;
        -t|--tools)
            download_protobuf
            ;;
        -a|--all|"")
            download_all
            ;;
        *)
            TARGET_DIR="$1"
            download_all
            ;;
    esac
    
    echo ""
    log_info "完成！"
}

main "$@"