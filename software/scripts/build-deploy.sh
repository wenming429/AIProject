#!/bin/bash

#===============================================================================
# LumenIM 本地打包与远程部署脚本 (Bash 版)
#
# 版本: 1.0.0
# 日期: 2026-04-09
# 功能: 本地打包前后端 → 安全传输 → 远程服务器部署
#===============================================================================

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# 配置
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEPLOY_DIR="${PROJECT_ROOT}/deploy-package"
BACKEND_SRC="${PROJECT_ROOT}/backend"
FRONTEND_SRC="${PROJECT_ROOT}/front"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
LOG_FILE="${DEPLOY_DIR}/deploy-${TIMESTAMP}.log"
MAX_BACKUP=3

# 服务器配置（默认值）
SERVER_IP="192.168.23.131"
SERVER_USER="root"
SERVER_PORT="22"
AUTH_TYPE="key"
KEY_PATH="$HOME/.ssh/id_rsa"
REMOTE_PATH="/var/www/lumenim"
BRANCH="main"

# 模式标志
MODE_BUILD_ONLY=false
MODE_UPLOAD=false
MODE_DEPLOY=false
MODE_ROLLBACK=false
SKIP_BACKUP=false

#===============================================================================
# 函数
#===============================================================================

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] $1" >> "$LOG_FILE"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; echo "[$(date '+%Y-%m-%d %H:%M:%S')] [SUCCESS] $1" >> "$LOG_FILE"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; echo "[$(date '+%Y-%m-%d %H:%M:%S')] [WARN] $1" >> "$LOG_FILE"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; echo "[$(date '+%Y-%m-%d %H:%M:%S')] [ERROR] $1" >> "$LOG_FILE"; }
log_section() {
    echo ""
    echo -e "${CYAN}========================================${NC}"
    echo -e "${CYAN}  $1${NC}"
    echo -e "${CYAN}========================================${NC}"
}

show_help() {
    cat << EOF
LumenIM 本地打包与远程部署脚本 v1.0

用法: $0 [选项]

选项:
    --server-ip=IP        服务器 IP (默认: ${SERVER_IP})
    --server-user=USER    SSH 用户 (默认: ${SERVER_USER})
    --server-port=PORT    SSH 端口 (默认: ${SERVER_PORT})
    --auth-type=TYPE      认证方式: key/password (默认: key)
    --key-path=PATH       SSH 密钥路径 (默认: ~/.ssh/id_rsa)
    --remote-path=PATH    远程部署路径 (默认: /var/www/lumenim)
    --branch=BRANCH       Git 分支 (默认: main)

模式:
    --build-only          仅打包，不上传
    --upload              打包并上传，不部署
    --deploy              完整部署
    --rollback            回滚到上一版本
    --skip-backup         跳过备份

示例:
    # 仅打包
    $0 --build-only

    # 打包并上传
    $0 --upload --server-ip=192.168.23.131

    # 完整部署
    $0 --deploy --server-ip=192.168.23.131 --server-user=root

    # 回滚
    $0 --rollback --server-ip=192.168.23.131

环境变量:
    SERVER_IP            服务器 IP
    SERVER_USER           SSH 用户
    SERVER_PASSWORD       SSH 密码（密码认证时）
EOF
}

# 解析参数
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --server-ip=*) SERVER_IP="${1#*=}"; shift ;;
            --server-user=*) SERVER_USER="${1#*=}"; shift ;;
            --server-port=*) SERVER_PORT="${1#*=}"; shift ;;
            --auth-type=*) AUTH_TYPE="${1#*=}"; shift ;;
            --key-path=*) KEY_PATH="${1#*=}"; shift ;;
            --remote-path=*) REMOTE_PATH="${1#*=}"; shift ;;
            --branch=*) BRANCH="${1#*=}"; shift ;;
            --build-only) MODE_BUILD_ONLY=true; shift ;;
            --upload) MODE_UPLOAD=true; shift ;;
            --deploy) MODE_DEPLOY=true; shift ;;
            --rollback) MODE_ROLLBACK=true; shift ;;
            --skip-backup) SKIP_BACKUP=true; shift ;;
            -h|--help) show_help; exit 0 ;;
            *) echo "未知选项: $1"; show_help; exit 1 ;;
        esac
    done
}

# 检查命令
check_command() {
    if ! command -v "$1" &>/dev/null; then
        log_error "$1 未安装"
        return 1
    fi
    return 0
}

# 检查环境
check_environment() {
    log_section "检查构建环境"

    local all_ok=true

    check_command "go" && log_success "Go: $(go version | awk '{print $3}')" || all_ok=false
    check_command "node" && log_success "Node.js: $(node -v)" || all_ok=false
    check_command "pnpm" && log_success "pnpm: $(pnpm -v)" || all_ok=false
    check_command "git" && log_success "Git: $(git --version | awk '{print $3}')" || all_ok=false
    check_command "ssh" && log_success "SSH: 已安装" || all_ok=false
    check_command "scp" && log_success "SCP: 已安装" || all_ok=false

    if [[ "$all_ok" == false ]]; then
        log_error "环境检查未通过"
        return 1
    fi

    return 0
}

# 构建后端
build_backend() {
    log_section "构建后端"

    if [[ ! -d "$BACKEND_SRC" ]]; then
        log_error "后端源码目录不存在: $BACKEND_SRC"
        return 1
    fi

    cd "$BACKEND_SRC"

    log_info "下载 Go 依赖..."
    export GOPROXY="https://goproxy.cn,direct"
    go env -w GOPROXY=$GOPROXY

    if ! go mod download; then
        log_error "Go 依赖下载失败"
        return 1
    fi

    log_info "编译后端..."
    export CGO_ENABLED=0
    export GOOS=linux
    export GOARCH=amd64

    if go build -ldflags="-s -w" -o lumenim ./cmd/lumenim; then
        local size=$(du -h lumenim | cut -f1)
        log_success "后端构建成功: $size"
        return 0
    fi

    log_error "后端构建失败"
    return 1
}

# 构建前端
build_frontend() {
    log_section "构建前端"

    if [[ ! -d "$FRONTEND_SRC" ]]; then
        log_error "前端源码目录不存在: $FRONTEND_SRC"
        return 1
    fi

    cd "$FRONTEND_SRC"

    # 创建环境配置
    local api_url="http://${SERVER_IP}/api"
    local ws_url="ws://${SERVER_IP}/ws"

    cat > .env.production << EOF
VITE_API_BASE_URL=$api_url
VITE_WS_URL=$ws_url
VITE_APP_NAME=LumenIM
VITE_APP_ENV=production
EOF

    log_info "安装前端依赖..."
    pnpm config set registry https://registry.npmmirror.com

    if ! pnpm install; then
        log_error "前端依赖安装失败"
        return 1
    fi

    log_info "构建前端..."
    if pnpm build; then
        local files=$(find dist -type f | wc -l)
        local size=$(du -sh dist | cut -f1)
        log_success "前端构建成功: $files 文件, $size"
        return 0
    fi

    log_error "前端构建失败"
    return 1
}

# 打包
create_package() {
    log_section "打包部署文件"

    mkdir -p "$DEPLOY_DIR"
    mkdir -p "$DEPLOY_DIR/backup"

    # 打包后端
    log_info "打包后端..."
    cd "$PROJECT_ROOT"
    BACKEND_PKG="${DEPLOY_DIR}/lumenim-backend-${TIMESTAMP}.tar.gz"

    tar --exclude='.git' \
        --exclude='node_modules' \
        --exclude='vendor' \
        --exclude='*.exe' \
        --exclude='dist' \
        --exclude='build' \
        -czf "$BACKEND_PKG" backend/

    if [[ -f "$BACKEND_PKG" ]]; then
        log_success "后端包: $BACKEND_PKG ($(du -h $BACKEND_PKG | cut -f1))"
    fi

    # 打包前端
    log_info "打包前端..."
    FRONTEND_PKG="${DEPLOY_DIR}/lumenim-frontend-${TIMESTAMP}.tar.gz"

    tar --exclude='.git' \
        --exclude='node_modules' \
        --exclude='src' \
        --exclude='public' \
        --exclude='*.log' \
        --exclude='.env*' \
        -czf "$FRONTEND_PKG" front/dist/

    if [[ -f "$FRONTEND_PKG" ]]; then
        log_success "前端包: $FRONTEND_PKG ($(du -h $FRONTEND_PKG | cut -f1))"
    fi

    log_success "打包完成"
}

# 测试连接
test_connection() {
    log_section "测试服务器连接"

    log_info "服务器: ${SERVER_IP}:${SERVER_PORT}"
    log_info "用户: ${SERVER_USER}"
    log_info "认证: ${AUTH_TYPE}"

    local ssh_opts="-o StrictHostKeyChecking=no -o ConnectTimeout=10"

    if [[ "$AUTH_TYPE" == "key" ]]; then
        ssh_opts="$ssh_opts -i $KEY_PATH"
    fi

    if timeout 10 ssh $ssh_opts -p $SERVER_PORT ${SERVER_USER}@${SERVER_IP} "echo 'OK'" &>/dev/null; then
        log_success "服务器连接成功"
        return 0
    fi

    log_error "服务器连接失败"
    return 1
}

# 备份服务器
backup_server() {
    if [[ "$SKIP_BACKUP" == true ]]; then
        log_info "跳过备份 (--skip-backup)"
        return 0
    fi

    log_section "备份服务器数据"

    local backup_name="lumenim-backup-${TIMESTAMP}"
    local remote_backup_dir="$(dirname $REMOTE_PATH)/backups"

    local ssh_opts="-o StrictHostKeyChecking=no -i $KEY_PATH"
    local backup_cmd="
        mkdir -p $remote_backup_dir
        cd $REMOTE_PATH
        [ -d backend ] && tar -czf $remote_backup_dir/${backup_name}-backend.tar.gz backend/ 2>/dev/null || true
        [ -d front/dist ] && tar -czf $remote_backup_dir/${backup_name}-frontend.tar.gz front/dist/ 2>/dev/null || true
        echo 'Backup completed: $backup_name'
    "

    if ssh $ssh_opts -p $SERVER_PORT ${SERVER_USER}@${SERVER_IP} "$backup_cmd"; then
        log_success "备份完成"
    else
        log_warn "备份失败"
    fi

    return 0
}

# 上传到服务器
upload_package() {
    log_section "上传部署文件"

    local ssh_opts="-o StrictHostKeyChecking=no -i $KEY_PATH"

    log_info "上传后端..."
    if scp -P $SERVER_PORT $ssh_opts "$BACKEND_PKG" ${SERVER_USER}@${SERVER_IP}:/tmp/; then
        log_success "后端上传成功"
    else
        log_error "后端上传失败"
        return 1
    fi

    log_info "上传前端..."
    if scp -P $SERVER_PORT $ssh_opts "$FRONTEND_PKG" ${SERVER_USER}@${SERVER_IP}:/tmp/; then
        log_success "前端上传成功"
    else
        log_error "前端上传失败"
        return 1
    fi

    return 0
}

# 远程部署
deploy_server() {
    log_section "部署到远程服务器"

    local ssh_opts="-o StrictHostKeyChecking=no -i $KEY_PATH"

    local deploy_cmd="
        set -e
        cd $REMOTE_PATH

        # 停止服务
        systemctl stop lumenim-backend 2>/dev/null || true

        # 解压后端
        if [ -f /tmp/lumenim-backend-${TIMESTAMP}.tar.gz ]; then
            [ -d backend ] && mv backend backend.bak || true
            mkdir -p backend
            tar -xzf /tmp/lumenim-backend-${TIMESTAMP}.tar.gz -C backend/ --strip-components=1
            chmod +x backend/lumenim
        fi

        # 解压前端
        if [ -f /tmp/lumenim-frontend-${TIMESTAMP}.tar.gz ]; then
            [ -d front/dist ] && mv front/dist front/dist.bak || true
            mkdir -p front/dist
            tar -xzf /tmp/lumenim-frontend-${TIMESTAMP}.tar.gz -C front/ --strip-components=1
        fi

        # 更新配置
        [ -f backend/config.example.yaml ] && cp backend/config.example.yaml backend/config.yaml || true

        # 设置权限
        chown -R lumenimadmin:lumenimadmin backend/ 2>/dev/null || true
        chown -R lumenimadmin:lumenimadmin front/dist/ 2>/dev/null || true

        # 启动服务
        systemctl start lumenim-backend
        systemctl status lumenim-backend --no-pager

        # 清理临时文件
        rm -f /tmp/lumenim-*.tar.gz

        echo 'Deployment completed!'
    "

    if ssh $ssh_opts -p $SERVER_PORT ${SERVER_USER}@${SERVER_IP} "$deploy_cmd"; then
        log_success "远程部署成功"
        return 0
    fi

    log_error "远程部署失败"
    return 1
}

# 健康检查
health_check() {
    log_section "健康检查"

    sleep 3

    log_info "检查 API..."
    if curl -s -o /dev/null -w "%{http_code}" http://${SERVER_IP}:9501/api/v1/health | grep -q "200"; then
        log_success "API 健康检查: OK"
    else
        log_warn "API 健康检查失败"
    fi

    log_info "检查前端..."
    if curl -s -o /dev/null -w "%{http_code}" http://${SERVER_IP} | grep -q "200"; then
        log_success "前端健康检查: OK"
    else
        log_warn "前端健康检查失败"
    fi
}

# 回滚
rollback_server() {
    log_section "回滚到上一版本"

    local ssh_opts="-o StrictHostKeyChecking=no -i $KEY_PATH"

    local rollback_cmd="
        set -e
        backup_dir=\$(dirname $REMOTE_PATH)/backups

        echo 'Available backups:'
        ls -lt \$backup_dir/*.tar.gz 2>/dev/null | head -5

        backend_backup=\$(ls -t \$backup_dir/lumenim-backup-*-backend.tar.gz 2>/dev/null | head -1)

        if [ -z \"\$backend_backup\" ]; then
            echo 'No backup found'
            exit 1
        fi

        # 停止服务
        systemctl stop lumenim-backend

        # 恢复后端
        cd $REMOTE_PATH
        rm -rf backend
        mkdir -p backend
        tar -xzf \$backend_backup -C backend/

        frontend_backup=\$(ls -t \$backup_dir/lumenim-backup-*-frontend.tar.gz 2>/dev/null | head -1)
        if [ -n \"\$frontend_backup\" ]; then
            rm -rf front/dist
            mkdir -p front/dist
            tar -xzf \$frontend_backup -C front/
        fi

        # 设置权限
        chown -R lumenimadmin:lumenimadmin backend/ 2>/dev/null || true
        chown -R lumenimadmin:lumenimadmin front/dist/ 2>/dev/null || true

        # 启动服务
        systemctl start lumenim-backend

        echo 'Rollback completed!'
    "

    if ssh $ssh_opts -p $SERVER_PORT ${SERVER_USER}@${SERVER_IP} "$rollback_cmd"; then
        log_success "回滚成功"
        return 0
    fi

    log_error "回滚失败"
    return 1
}

#===============================================================================
# 主程序
#===============================================================================

main() {
    # 解析参数
    parse_args "$@"

    # 创建日志目录
    mkdir -p "$DEPLOY_DIR"

    log_section "LumenIM 打包与部署"
    log_info "开始时间: $(date '+%Y-%m-%d %H:%M:%S')"
    log_info "日志文件: $LOG_FILE"

    # 回滚模式
    if [[ "$MODE_ROLLBACK" == true ]]; then
        test_connection || exit 1
        rollback_server
        exit 0
    fi

    # 检查环境
    check_environment || exit 1

    # 构建
    build_backend || exit 1
    build_frontend || exit 1

    # 仅打包
    if [[ "$MODE_BUILD_ONLY" == true ]]; then
        create_package
        log_success "打包完成: $DEPLOY_DIR"
        exit 0
    fi

    # 上传和部署
    if [[ "$MODE_UPLOAD" == true ]] || [[ "$MODE_DEPLOY" == true ]]; then
        test_connection || exit 1
        create_package
        backup_server
        upload_package || exit 1

        if [[ "$MODE_DEPLOY" == true ]]; then
            deploy_server || exit 1
            health_check
        fi
    fi

    log_section "完成"
    log_info "结束时间: $(date '+%Y-%m-%d %H:%M:%S')"
    log_success "日志文件: $LOG_FILE"
}

main "$@"
