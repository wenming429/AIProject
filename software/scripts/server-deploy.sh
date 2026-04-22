#!/bin/bash
#===============================================================================
# LumenIM 服务器部署脚本 - 服务器端执行
# 使用说明: 将编译好的 lumenim 二进制文件传到服务器后执行此脚本
#===============================================================================

set -e

# 配置参数
APP_DIR="/var/www/lumenim/backend"
BACKUP_DIR="/var/www/lumenim/backup/$(date +%Y%m%d_%H%M%S)"
SERVICE_NAME="lumenim-backend"
ZIP_FILE="lumenim-deploy.zip"

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
# 步骤 1: 检查环境
#===============================================================================
check_env() {
    log_info "========== 步骤 1: 检查环境 =========="

    if [ ! -d "$APP_DIR" ]; then
        log_error "应用目录不存在: $APP_DIR"
        exit 1
    fi

    if [ -f "$ZIP_FILE" ]; then
        log_info "找到部署包: $ZIP_FILE"
    else
        log_warn "未找到部署包文件: $ZIP_FILE"
        log_info "请确保已将 lumenim 二进制文件或部署包放到当前目录"
    fi

    log_info "环境检查完成 ✓"
}

#===============================================================================
# 步骤 2: 备份
#===============================================================================
backup() {
    log_info "========== 步骤 2: 备份当前版本 =========="

    mkdir -p "$BACKUP_DIR"
    log_info "备份目录: $BACKUP_DIR"

    if [ -f "$APP_DIR/lumenim" ]; then
        cp "$APP_DIR/lumenim" "$BACKUP_DIR/"
        log_info "已备份 lumenim 二进制文件"
    fi

    if [ -f "$APP_DIR/config.yaml" ]; then
        cp "$APP_DIR/config.yaml" "$BACKUP_DIR/"
        log_info "已备份 config.yaml"
    fi

    log_info "备份完成 ✓"
}

#===============================================================================
# 步骤 3: 停止服务
#===============================================================================
stop_service() {
    log_info "========== 步骤 3: 停止服务 =========="

    if systemctl is-active --quiet "$SERVICE_NAME" 2>/dev/null; then
        systemctl stop "$SERVICE_NAME"
        log_info "服务已停止"
    else
        log_info "服务未运行，无需停止"
    fi

    # 强制杀死可能残留的进程
    pkill -f lumenim 2>/dev/null || true

    log_info "停止服务完成 ✓"
}

#===============================================================================
# 步骤 4: 解压部署包
#===============================================================================
deploy() {
    log_info "========== 步骤 4: 部署新版本 =========="

    if [ -f "$ZIP_FILE" ]; then
        log_info "解压部署包..."
        unzip -o "$ZIP_FILE" -d "$APP_DIR" 2>/dev/null || \
        tar -xzf "$ZIP_FILE" -C "$APP_DIR" 2>/dev/null || \
        log_error "无法解压 $ZIP_FILE"
    fi

    # 设置执行权限
    chmod +x "$APP_DIR/lumenim"
    log_info "已设置执行权限"

    log_info "部署完成 ✓"
}

#===============================================================================
# 步骤 5: 启动服务
#===============================================================================
start_service() {
    log_info "========== 步骤 5: 启动服务 =========="

    # 创建 systemd 服务文件
    cat > /etc/systemd/system/${SERVICE_NAME}.service << 'EOF'
[Unit]
Description=LumenIM Backend Service
After=network.target docker.service mysql.service redis.service
Wants=mysql.service redis.service

[Service]
Type=simple
User=root
Group=root
WorkingDirectory=/var/www/lumenim/backend
ExecStart=/var/www/lumenim/backend/lumenim
Restart=always
RestartSec=5s
LimitNOFILE=65536
StandardOutput=append:/var/www/lumenim/backend/logs/stdout.log
StandardError=append:/var/www/lumenim/backend/logs/stderr.log
Environment="GOPROXY=https://goproxy.cn,direct"
Environment="GOSUMDB=off"

[Install]
WantedBy=multi-user.target
EOF

    # 创建日志目录
    mkdir -p "$APP_DIR/logs"
    mkdir -p "$APP_DIR/tmp"

    # 重载 systemd
    systemctl daemon-reload

    # 启用并启动服务
    systemctl enable "$SERVICE_NAME"
    systemctl start "$SERVICE_NAME"

    log_info "服务启动完成 ✓"
}

#===============================================================================
# 步骤 6: 检查状态
#===============================================================================
check_status() {
    log_info "========== 步骤 6: 检查服务状态 =========="

    sleep 3

    echo ""
    echo "=========================================="
    echo "服务状态"
    echo "=========================================="
    echo ""

    # 检查 systemd 服务状态
    if systemctl is-active --quiet "$SERVICE_NAME" 2>/dev/null; then
        echo -e "${GREEN}✓${NC} 服务运行中"
    else
        echo -e "${RED}✗${NC} 服务未运行"
    fi

    # 显示详细信息
    systemctl status "$SERVICE_NAME" --no-pager || true

    echo ""
    echo "最近日志 (最后 20 行):"
    journalctl -u "$SERVICE_NAME" -n 20 --no-pager || true

    echo ""
    echo "=========================================="
}

#===============================================================================
# 主函数
#===============================================================================
main() {
    echo ""
    echo "=============================================="
    echo "  LumenIM 服务器部署脚本"
    echo "  应用目录: $APP_DIR"
    echo "  备份目录: $BACKUP_DIR"
    echo "=============================================="
    echo ""

    check_env
    backup
    stop_service
    deploy
    start_service
    check_status

    echo ""
    echo "=============================================="
    echo -e "${GREEN}  部署完成!${NC}"
    echo "=============================================="
    echo ""
    echo "管理命令:"
    echo "  查看状态: systemctl status $SERVICE_NAME"
    echo "  查看日志: journalctl -u $SERVICE_NAME -f"
    echo "  重启服务: systemctl restart $SERVICE_NAME"
    echo "  停止服务: systemctl stop $SERVICE_NAME"
    echo ""
}

# 运行
main "$@"
