#!/bin/bash

#===============================================================================
# LumenIM Docker Compose 快速部署脚本
#
# 版本: 1.0.0
# 日期: 2026-04-09
# 适用: Ubuntu 20.04 LTS
#===============================================================================

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 配置
APP_NAME="lumenim"
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DOCKER_DIR="${PROJECT_DIR}/backend"

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

show_help() {
    cat << EOF
LumenIM Docker Compose 快速部署脚本

用法: $0 [选项]

选项:
    -h, --help          显示帮助
    -s, --start         启动服务
    -S, --stop          停止服务
    -r, --restart       重启服务
    -l, --logs          查看日志
    -L, --logs-follow   跟踪日志
    -S, --status        查看状态
    -i, --init          初始化并启动
    -u, --update        更新镜像
    -c, --clean         清理容器和数据

示例:
    $0 --init           # 初始化并启动
    $0 --logs-follow    # 跟踪日志
EOF
}

check_docker() {
    if ! command -v docker &> /dev/null; then
        log_error "Docker 未安装"
        echo "请先安装 Docker: https://docs.docker.com/engine/install/ubuntu/"
        exit 1
    fi
    
    if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
        log_error "Docker Compose 未安装"
        echo "请先安装 Docker Compose"
        exit 1
    fi
    
    # 获取 docker compose 命令
    if docker compose version &> /dev/null; then
        DOCKER_COMPOSE="docker compose"
    else
        DOCKER_COMPOSE="docker-compose"
    fi
    
    log_success "Docker: $(docker --version)"
    log_success "Docker Compose: $($DOCKER_COMPOSE version 2>/dev/null | head -1)"
}

start_services() {
    log_info "启动 LumenIM 服务..."
    cd "${DOCKER_DIR}"
    $DOCKER_COMPOSE up -d
    log_success "服务启动完成"
}

stop_services() {
    log_info "停止 LumenIM 服务..."
    cd "${DOCKER_DIR}"
    $DOCKER_COMPOSE down
    log_success "服务已停止"
}

restart_services() {
    log_info "重启 LumenIM 服务..."
    cd "${DOCKER_DIR}"
    $DOCKER_COMPOSE restart
    log_success "服务重启完成"
}

show_status() {
    log_info "服务状态:"
    cd "${DOCKER_DIR}"
    $DOCKER_COMPOSE ps
}

show_logs() {
    cd "${DOCKER_DIR}"
    $DOCKER_COMPOSE logs --tail=100
}

follow_logs() {
    cd "${DOCKER_DIR}"
    $DOCKER_COMPOSE logs -f
}

init_and_start() {
    log_info "=========================================="
    log_info "  LumenIM Docker Compose 初始化部署"
    log_info "=========================================="
    echo ""
    
    check_docker
    
    # 检查目录
    if [[ ! -d "${DOCKER_DIR}" ]]; then
        log_error "未找到 backend 目录: ${DOCKER_DIR}"
        exit 1
    fi
    
    # 检查 docker-compose 文件
    if [[ ! -f "${DOCKER_DIR}/docker-compose.yaml" ]]; then
        log_error "未找到 docker-compose.yaml"
        exit 1
    fi
    
    # 配置环境
    cd "${DOCKER_DIR}"
    
    if [[ -f ".env.example" ]]; then
        if [[ ! -f ".env" ]]; then
            cp .env.example .env
            log_warn "已创建 .env 配置文件，请编辑后继续"
            log_info "配置文件: ${DOCKER_DIR}/.env"
            echo ""
            read -p "按 Enter 继续或 Ctrl+C 退出..."
        fi
    fi
    
    # 拉取镜像
    log_info "拉取 Docker 镜像..."
    $DOCKER_COMPOSE pull
    
    # 创建网络
    log_info "创建网络..."
    docker network create lumenim-network 2>/dev/null || true
    
    # 启动服务
    log_info "启动服务..."
    $DOCKER_COMPOSE up -d
    
    # 等待服务启动
    log_info "等待服务启动..."
    sleep 10
    
    # 显示状态
    echo ""
    show_status
    
    echo ""
    log_info "=========================================="
    log_success "  部署完成!"
    log_info "=========================================="
    echo ""
    log_info "访问地址:"
    log_info "  - 前端 (HTTP):  http://localhost:9503/"
    log_info "  - API:          http://localhost:9501/api/v1/health"
    log_info "  - WebSocket:    ws://localhost:9502"
    log_info "  - MinIO:        http://localhost:9090"
    echo ""
    log_info "查看日志: $0 --logs-follow"
    log_info "停止服务: $0 --stop"
}

update_images() {
    log_info "更新 Docker 镜像..."
    cd "${DOCKER_DIR}"
    $DOCKER_COMPOSE pull
    $DOCKER_COMPOSE up -d
    log_success "镜像更新完成"
}

clean_all() {
    log_warn "这将删除所有容器和数据卷!"
    read -p "确认清理? (yes/no): " confirm
    if [[ "$confirm" == "yes" ]]; then
        cd "${DOCKER_DIR}"
        $DOCKER_COMPOSE down -v
        docker network rm lumenim-network 2>/dev/null || true
        log_success "清理完成"
    else
        log_info "取消清理"
    fi
}

# 检查 root
if [[ $EUID -eq 0 ]]; then
    log_warn "建议不要以 root 用户运行 Docker 命令"
fi

# 解析参数
case "${1:-}" in
    -h|--help)
        show_help
        ;;
    -s|--start)
        check_docker
        start_services
        ;;
    -S|--stop)
        check_docker
        stop_services
        ;;
    -r|--restart)
        check_docker
        restart_services
        ;;
    -l|--logs)
        check_docker
        show_logs
        ;;
    -L|--logs-follow)
        check_docker
        follow_logs
        ;;
    -S|--status)
        check_docker
        show_status
        ;;
    -i|--init)
        init_and_start
        ;;
    -u|--update)
        check_docker
        update_images
        ;;
    -c|--clean)
        clean_all
        ;;
    *)
        show_help
        ;;
esac
