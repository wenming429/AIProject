#!/bin/bash
#
# LumenIM Linux 环境依赖下载脚本
# Download script for LumenIM Linux environment dependencies
# 
# 使用方法 ./download-linux.sh [目标目录]
# Usage: ./download-linux.sh [target_directory]
#
# 版本: 1.0.0
# 更新日期: 2026-04-08

set -e

# ============================================================
# 配置区域 - 可根据网络环境修改
# ============================================================

# 下载目标目录（默认为当前目录下的 packages）
TARGET_DIR="${1:-./packages}"

# 镜像源配置（中国大陆地区可使用国内镜像）
USE_MIRROR="${USE_MIRROR:-false}"

# Go 版本
GO_VERSION="1.25.0"
GO_VERSION_SHORT="1.25"

# Node.js 版本
NODE_VERSION="22.14.0"

# pnpm 版本
PNPM_VERSION="10.0.0"

# MySQL 版本
MYSQL_VERSION="8.0.40"

# Redis 版本
REDIS_VERSION="7.4.3"

# Protocol Buffers 版本
PROTOBUF_VERSION="25.1"

# Buf CLI 版本
BUF_VERSION="1.28.1"

# Git 版本
GIT_VERSION="2.48.1"

# Electron 版本
ELECTRON_VERSION="33.4.0"

# ============================================================
# 下载链接定义
# ============================================================

# Go 下载链接
GO_BASE_URL="https://go.dev/dl"
GO_PACKAGE="go${GO_VERSION}.linux-amd64.tar.gz"

# Node.js 下载链接
NODE_BASE_URL="https://nodejs.org/dist/v${NODE_VERSION}"
NODE_PACKAGE="node-v${NODE_VERSION}-linux-x64.tar.xz"

# pnpm 下载链接
PNPM_BASE_URL="https://github.com/pnpm/pnpm/releases/download/v${PNPM_VERSION}"
PNPM_PACKAGE="pnpm-linux-x64"

# MySQL 下载链接
MYSQL_BASE_URL="https://dev.mysql.com/get/Downloads/MySQL-8.0"
MYSQL_PACKAGE="mysql-${MYSQL_VERSION}-linux-glibc2.28-x86_64.tar.gz"

# Redis 下载链接
REDIS_BASE_URL="https://github.com/redis/redis/archive/refs/tags"
REDIS_PACKAGE="redis-${REDIS_VERSION}.tar.gz"

# Protocol Buffers 下载链接
PROTOBUF_BASE_URL="https://github.com/protocolbuffers/protobuf/releases/download/v${PROTOBUF_VERSION}"
PROTOBUF_PACKAGE="protoc-${PROTOBUF_VERSION}-linux-x86_64.zip"

# Buf CLI 下载链接
BUF_BASE_URL="https://github.com/bufbuild/buf/releases/download/v${BUF_VERSION}"
BUF_PACKAGE="buf-Linux-x86_64"

# Git 下载链接
GIT_BASE_URL="https://github.com/git/git/archive/refs/tags"
GIT_PACKAGE="v${GIT_VERSION}.tar.gz"

# Electron 下载链接（使用淘宝镜像）
ELECTRON_BASE_URL="https://cdn.npm.taobao.org/dist/electron/v${ELECTRON_VERSION}"
ELECTRON_PACKAGE="electron-v${ELECTRON_VERSION}-linux-x64.tar.gz"

# ============================================================
# 颜色定义
# ============================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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

check_command() {
    if ! command -v "$1" &> /dev/null; then
        log_error "命令 '$1' 未找到，请先安装"
        return 1
    fi
    return 0
}

create_target_dir() {
    if [ ! -d "$TARGET_DIR" ]; then
        log_info "创建目标目录: $TARGET_DIR"
        mkdir -p "$TARGET_DIR"
    fi
}

download_file() {
    local url="$1"
    local output="$2"
    local description="$3"
    
    log_step "下载 $description..."
    log_info "URL: $url"
    
    if [ -f "$output" ]; then
        log_warn "$description 已存在，跳过下载"
        return 0
    fi
    
    if command -v curl &> /dev/null; then
        curl -L --progress-bar -o "$output" "$url"
    elif command -v wget &> /dev/null; then
        wget --show-progress -O "$output" "$url"
    else
        log_error "未找到 curl 或 wget，请至少安装其一"
        return 1
    fi
    
    if [ $? -eq 0 ]; then
        log_info "$description 下载完成"
    else
        log_error "$description 下载失败"
        return 1
    fi
}

download_go() {
    local output="$TARGET_DIR/$GO_PACKAGE"
    download_file "$GO_BASE_URL/$GO_PACKAGE" "$output" "Go ${GO_VERSION}"
}

download_node() {
    local output="$TARGET_DIR/$NODE_PACKAGE"
    download_file "$NODE_BASE_URL/$NODE_PACKAGE" "$output" "Node.js ${NODE_VERSION}"
}

download_pnpm() {
    local output="$TARGET_DIR/pnpm"
    download_file "$PNPM_BASE_URL/$PNPM_PACKAGE" "$output" "pnpm ${PNPM_VERSION}"
    # 添加执行权限
    chmod +x "$output" 2>/dev/null || true
}

download_mysql() {
    local output="$TARGET_DIR/$MYSQL_PACKAGE"
    download_file "$MYSQL_BASE_URL/$MYSQL_PACKAGE" "$output" "MySQL ${MYSQL_VERSION}"
}

download_redis() {
    local output="$TARGET_DIR/$REDIS_PACKAGE"
    download_file "$REDIS_BASE_URL/$REDIS_PACKAGE" "$output" "Redis ${REDIS_VERSION}"
}

download_protobuf() {
    local output="$TARGET_DIR/$PROTOBUF_PACKAGE"
    download_file "$PROTOBUF_BASE_URL/$PROTOBUF_PACKAGE" "$output" "Protocol Buffers ${PROTOBUF_VERSION}"
}

download_buf() {
    local output="$TARGET_DIR/buf"
    download_file "$BUF_BASE_URL/$BUF_PACKAGE" "$output" "Buf CLI ${BUF_VERSION}"
    chmod +x "$output" 2>/dev/null || true
}

download_git() {
    local output="$TARGET_DIR/$GIT_PACKAGE"
    download_file "$GIT_BASE_URL/$GIT_PACKAGE" "$output" "Git ${GIT_VERSION}"
}

download_electron() {
    local output="$TARGET_DIR/$ELECTRON_PACKAGE"
    download_file "$ELECTRON_BASE_URL/$ELECTRON_PACKAGE" "$output" "Electron ${ELECTRON_VERSION}"
}

show_help() {
    cat << EOF
LumenIM Linux 环境依赖下载脚本

使用方法:
    $0 [选项] [目标目录]

选项:
    -h, --help              显示帮助信息
    -m, --mirror           使用国内镜像源（可选）
    -a, --all              下载所有软件包
    -g, --go               仅下载 Go
    -n, --node             仅下载 Node.js
    -p, --pnpm             仅下载 pnpm
    -d, --database         下载数据库 (MySQL + Redis)
    -t, --tools            下载工具链 (Protocol Buffers + Buf)
    -e, --electron         下载 Electron（桌面应用构建）

示例:
    # 下载所有软件包到 ./packages 目录
    $0 --all

    # 使用国内镜像源
    $0 --mirror --all

    # 仅下载 Go 和 Node.js
    $0 --go --node

    # 仅下载数据库组件
    $0 --database

EOF
}

# ============================================================
# 主函数
# ============================================================

main() {
    echo "=========================================="
    echo "LumenIM 依赖下载脚本"
    echo "=========================================="
    echo ""
    
    # 解析命令行参数
    DO_ALL=false
    DO_GO=false
    DO_NODE=false
    DO_PNPM=false
    DO_DATABASE=false
    DO_TOOLS=false
    DO_ELECTRON=false
    
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                show_help
                exit 0
                ;;
            -m|--mirror)
                USE_MIRROR=true
                shift
                ;;
            -a|--all)
                DO_ALL=true
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
            -p|--pnpm)
                DO_PNPM=true
                shift
                ;;
            -d|--database)
                DO_DATABASE=true
                shift
                ;;
            -t|--tools)
                DO_TOOLS=true
                shift
                ;;
            -e|--electron)
                DO_ELECTRON=true
                shift
                ;;
            *)
                TARGET_DIR="$1"
                shift
                ;;
        esac
    done
    
    # 创建目标目录
    create_target_dir
    
    log_info "下载目标目录: $TARGET_DIR"
    echo ""
    
    # 执行下载
    if [ "$DO_ALL" = true ] || [ "$DO_GO" = true ]; then
        download_go
    fi
    
    if [ "$DO_ALL" = true ] || [ "$DO_NODE" = true ]; then
        download_node
    fi
    
    if [ "$DO_ALL" = true ] || [ "$DO_PNPM" = true ]; then
        download_pnpm
    fi
    
    if [ "$DO_ALL" = true ] || [ "$DO_DATABASE" = true ]; then
        download_mysql
        download_redis
    fi
    
    if [ "$DO_ALL" = true ] || [ "$DO_TOOLS" = true ]; then
        download_protobuf
        download_buf
    fi
    
    if [ "$DO_ALL" = true ] || [ "$DO_GIT" = true ]; then
        download_git
    fi
    
    if [ "$DO_ALL" = true ] || [ "$DO_ELECTRON" = true ]; then
        download_electron
    fi
    
    # 如果没有指定任何选项，显示帮助
    if [ "$DO_ALL" = false ] && [ "$DO_GO" = false ] && [ "$DO_NODE" = false ] && \
       [ "$DO_PNPM" = false ] && [ "$DO_DATABASE" = false ] && \
       [ "$DO_TOOLS" = false ] && [ "$DO_ELECTRON" = false ]; then
        show_help
    fi
    
    echo ""
    log_info "下载完成！"
    log_info "软件包保存在: $TARGET_DIR"
    echo ""
    
    # 列出下载的文件
    echo "=========================================="
    echo "已下载的软件包:"
    echo "=========================================="
    ls -lh "$TARGET_DIR"
}

# 执行主函数
main "$@"