#!/bin/bash
#
# LumenIM Ubuntu 20.04 远程部署脚本
# LumenIM Ubuntu 20.04 Remote Deployment Script
#
# 使用方法: ./deploy-ubuntu20.sh [选项]
# Usage: ./deploy-ubuntu20.sh [options]
#
# 版本: 2.0.0
# 更新日期: 2026-04-10
# 目标服务器: 192.168.23.131
# 部署用户: wenming429

set -e

# ============================================================
# 服务器配置
# ============================================================

# 默认配置
DEFAULT_HOST="192.168.23.131"
DEFAULT_USER="wenming429"
DEFAULT_PORT="22"
GIT_REPO="https://github.com/wenming429/AIProject.git"

# 运行时配置
HOST=""
USER=""
PORT=""
PASSWORD=""
KEY_FILE=""
REMOTE_SCRIPT="/tmp/install-ubuntu20.sh"
DEPLOY_SCRIPT=""
USE_SSHPASS=false

# 颜色定义
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

# ============================================================
# 检查本地依赖
# ============================================================

check_local_deps() {
    log_step "检查本地依赖..."
    
    local missing=()
    
    if ! command -v ssh &>/dev/null; then
        missing+=("ssh")
    fi
    
    if ! command -v scp &>/dev/null; then
        missing+=("scp")
    fi
    
    if ! command -v git &>/dev/null; then
        missing+=("git")
    fi
    
    if command -v sshpass &>/dev/null; then
        USE_SSHPASS=true
        log_info "sshpass: 已安装"
    else
        log_warn "sshpass: 未安装（需要安装以使用密码认证）"
        log_info "安装方法: apt-get install sshpass 或 brew install sshpass"
    fi
    
    if [ ${#missing[@]} -gt 0 ]; then
        log_error "缺少必要依赖: ${missing[*]}"
        exit 1
    fi
    
    log_success "本地依赖检查完成"
}

# ============================================================
# SSH 连接测试
# ============================================================

test_connection() {
    log_step "测试 SSH 连接..."
    
    local ssh_opts="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"
    
    if [ -n "$KEY_FILE" ]; then
        ssh_opts="$ssh_opts -i $KEY_FILE"
    fi
    
    if sshpass -p "$PASSWORD" ssh $ssh_opts -p "$PORT" "$USER@$HOST" "echo 'Connection OK'" 2>/dev/null; then
        log_success "SSH 连接成功"
        return 0
    elif [ -z "$PASSWORD" ] && [ -z "$KEY_FILE" ]; then
        log_error "请提供密码或 SSH 密钥文件"
        exit 1
    else
        log_error "SSH 连接失败，请检查配置"
        exit 1
    fi
}

# ============================================================
# 上传部署脚本到远程服务器
# ============================================================

upload_script() {
    log_step "上传部署脚本到远程服务器..."
    
    local ssh_opts="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"
    [ -n "$KEY_FILE" ] && ssh_opts="$ssh_opts -i $KEY_FILE"
    
    if [ -n "$PASSWORD" ]; then
        sshpass -p "$PASSWORD" scp -P "$PORT" $ssh_opts "$DEPLOY_SCRIPT" "$USER@$HOST:$REMOTE_SCRIPT"
    else
        scp -P "$PORT" $ssh_opts "$DEPLOY_SCRIPT" "$USER@$HOST:$REMOTE_SCRIPT"
    fi
    
    log_success "脚本上传完成"
}

# ============================================================
# 在远程服务器执行部署
# ============================================================

execute_deploy() {
    log_step "执行远程部署..."
    
    local ssh_opts="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -t -t"
    [ -n "$KEY_FILE" ] && ssh_opts="$ssh_opts -i $KEY_FILE"
    
    if [ -n "$PASSWORD" ]; then
        sshpass -p "$PASSWORD" ssh $ssh_opts -p "$PORT" "$USER@$HOST" "chmod +x $REMOTE_SCRIPT && sudo $REMOTE_SCRIPT $@"
    else
        ssh $ssh_opts -p "$PORT" "$USER@$HOST" "chmod +x $REMOTE_SCRIPT && sudo $REMOTE_SCRIPT $@"
    fi
}

# ============================================================
# 清理远程脚本
# ============================================================

cleanup_remote() {
    log_info "清理临时文件..."
    
    local ssh_opts="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"
    [ -n "$KEY_FILE" ] && ssh_opts="$ssh_opts -i $KEY_FILE"
    
    if [ -n "$PASSWORD" ]; then
        sshpass -p "$PASSWORD" ssh $ssh_opts -p "$PORT" "$USER@$HOST" "rm -f $REMOTE_SCRIPT"
    else
        ssh $ssh_opts -p "$PORT" "$USER@$HOST" "rm -f $REMOTE_SCRIPT"
    fi
}

# ============================================================
# 完整远程部署流程
# ============================================================

full_deploy() {
    log_step "开始完整部署流程..."
    
    echo ""
    echo "=========================================="
    echo "部署配置"
    echo "=========================================="
    echo "目标服务器: $HOST"
    echo "SSH 用户: $USER"
    echo "SSH 端口: $PORT"
    echo "代码仓库: $GIT_REPO"
    echo ""
    
    check_local_deps
    test_connection
    upload_script
    execute_deploy --all
    cleanup_remote
    
    echo ""
    echo "=========================================="
    log_success "部署完成！"
    echo "=========================================="
    echo ""
    echo "访问信息:"
    echo "  http://$HOST:9501"
    echo ""
    echo "SSH 连接命令:"
    echo "  ssh $USER@$HOST -p $PORT"
    echo ""
}

# ============================================================
# 显示帮助
# ============================================================

show_help() {
    cat << 'EOF'
LumenIM Ubuntu 20.04 远程部署脚本

使用方法:
    ./deploy-ubuntu20.sh [选项]

必需选项:
    --host <IP>              服务器 IP地址
    --user <用户名>          SSH 用户名
    --password <密码>        SSH 密码
    或
    --key <密钥文件>         SSH 密钥文件

其他选项:
    --port <端口>            SSH 端口 (默认: 22)
    --script <脚本路径>      本地部署脚本路径
    --help                   显示帮助

部署选项:
    --all                    完整部署
    --deps                   仅安装依赖
    --runtime                仅安装运行时
    --config                 仅配置服务
    --start                  仅启动服务

示例:
    # 密码认证 - 完整部署
    ./deploy-ubuntu20.sh --host 192.168.23.131 --user wenming429 --password your_password --all

    # SSH 密钥认证 - 完整部署
    ./deploy-ubuntu20.sh --host 192.168.23.131 --user wenming429 --key ~/.ssh/id_rsa --all

配置信息:
    默认服务器 IP: 192.168.23.131
    默认用户名: wenming429
    代码仓库: https://github.com/wenming429/AIProject.git
    MySQL 密码: wenming429

EOF
}

# ============================================================
# 参数解析
# ============================================================

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --host)
                HOST="$2"
                shift 2
                ;;
            --user)
                USER="$2"
                shift 2
                ;;
            --password)
                PASSWORD="$2"
                shift 2
                ;;
            --key)
                KEY_FILE="$2"
                shift 2
                ;;
            --port)
                PORT="$2"
                shift 2
                ;;
            --script)
                DEPLOY_SCRIPT="$2"
                shift 2
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            *)
                shift
                ;;
        esac
    done
}

# ============================================================
# 主函数
# ============================================================

main() {
    echo "=========================================="
    echo "LumenIM Ubuntu 20.04 远程部署脚本"
    echo "=========================================="
    echo ""
    
    HOST="$DEFAULT_HOST"
    USER="$DEFAULT_USER"
    PORT="$DEFAULT_PORT"
    
    parse_args "$@"
    
    if [ -z "$HOST" ] || [ -z "$USER" ]; then
        log_error "缺少必需参数: --host 和 --user"
        echo ""
        show_help
        exit 1
    fi
    
    if [ -z "$PASSWORD" ] && [ -z "$KEY_FILE" ]; then
        log_error "请提供 --password 或 --key 参数"
        echo ""
        show_help
        exit 1
    fi
    
    if [ -z "$DEPLOY_SCRIPT" ]; then
        SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
        if [ -f "$SCRIPT_DIR/install-ubuntu20.sh" ]; then
            DEPLOY_SCRIPT="$SCRIPT_DIR/install-ubuntu20.sh"
        elif [ -f "./install-ubuntu20.sh" ]; then
            DEPLOY_SCRIPT="./install-ubuntu20.sh"
        else
            log_error "找不到 install-ubuntu20.sh 部署脚本"
            exit 1
        fi
    fi
    
    log_info "使用部署脚本: $DEPLOY_SCRIPT"
    
    full_deploy
}

main "$@"
