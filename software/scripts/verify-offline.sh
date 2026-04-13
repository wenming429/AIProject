#!/bin/bash
#
# LumenIM CentOS 7 离线安装验证脚本
# Offline installation verification script
#
# 使用方法: ./verify-offline.sh
#
# 版本: 1.0.0
# 更新日期: 2026-04-08

set -e

# ============================================================
# 颜色定义
# ============================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_step() { echo -e "${BLUE}[STEP]${NC} $1"; }
log_success() { echo -e "${GREEN}[OK]${NC} $1"; }

# ============================================================
# 版本定义
# ============================================================

EXPECTED_GO="1.21.14"
EXPECTED_NODE="18.20.5"
EXPECTED_PROTOBUF="25.1"

# ============================================================
# 检查函数
# ============================================================

check_command() {
    command -v "$1" &>/dev/null
}

check_port() {
    lsof -i:$1 &>/dev/null
}

check_process() {
    pgrep -f "$1" &>/dev/null
}

# ============================================================
# 主验证
# ============================================================

main() {
    echo "=========================================="
    echo "LumenIM 离线安装验证"
    echo "=========================================="
    echo ""
    
    local failed=0
    
    # 1. 系统检查
    log_step "1. 系统信息"
    log_info "操作系统: $(cat /etc/centos-release)"
    log_info "内核: $(uname -r)"
    log_info "架构: $(uname -m)"
    log_info "内存: $(free -h | awk '/^Mem:/{print $2}')"
    log_info "磁盘: $(df -h / | awk 'NR==2{print $4}')"
    
    # 2. 运行时检查
    log_step "2. 运行时环境"
    
    # Go
    if check_command go; then
        local go_version=$(go version | grep -oP 'go\d+\.\d+\.\d+')
        if [ "$go_version" = "$EXPECTED_GO" ]; then
            log_success "Go: $go_version"
        else
            log_warn "Go: $go_version (期望 $EXPECTED_GO)"
        fi
    else
        log_error "Go: 未安装"
        ((failed++))
    fi
    
    # Node.js
    if check_command node; then
        local node_version=$(node --version | sed 's/v//')
        if [ "$node_version" = "$EXPECTED_NODE" ]; then
            log_success "Node.js: $node_version"
        else
            log_warn "Node.js: $node_version (期望 $EXPECTED_NODE)"
        fi
    else
        log_error "Node.js: 未安装"
        ((failed++))
    fi
    
    # pnpm
    if check_command pnpm; then
        log_success "pnpm: $(pnpm --version)"
    else
        log_warn "pnpm: 未安装"
    fi
    
    # protoc
    if check_command protoc; then
        local proto_version=$(protoc --version | sed 's/libprotoc //')
        if [ "$proto_version" = "$EXPECTED_PROTOBUF" ]; then
            log_success "Protocol Buffers: $proto_version"
        else
            log_warn "Protocol Buffers: $proto_version"
        fi
    else
        log_warn "Protocol Buffers: 未安装"
    fi
    
    # 3. Docker 检查
    log_step "3. Docker 环境"
    
    if check_command docker; then
        log_success "Docker: $(docker --version | sed 's/Docker version //')"
        
        # 检查容器
        if docker ps &>/dev/null; then
            local mysql=$(docker ps -a --filter 'name=lumenim-mysql' --format '{{.Names}}')
            local redis=$(docker ps -a --filter 'name=lumenim-redis' --format '{{.Names}}')
            
            if [ -n "$mysql" ]; then
                log_success "MySQL 容器: $mysql"
            else
                log_warn "MySQL 容器: 未创建"
            fi
            
            if [ -n "$redis" ]; then
                log_success "Redis 容器: $redis"
            else
                log_warn "Redis 容器: 未创建"
            fi
        fi
    else
        log_error "Docker: 未安装"
        ((failed++))
    fi
    
    # 4. 端口检查
    log_step "4. 端口占用"
    
    local http_port=9501
    local ws_port=9502
    local mysql_port=3306
    local redis_port=6379
    
    check_port $http_port && log_success "HTTP $http_port: 已占用" || log_warn "HTTP $http_port: 未占用"
    check_port $ws_port && log_success "WebSocket $ws_port: 已占用" || log_warn "WebSocket $ws_port: 未占用"
    check_port $mysql_port && log_success "MySQL $mysql_port: 已占用" || log_warn "MySQL $mysql_port: 未占用"
    check_port $redis_port && log_success "Redis $redis_port: 已占用" || log_warn "Redis $redis_port: 未占用"
    
    # 5. 服务检查
    log_step "5. systemd 服务"
    
    if systemctl list-unit-files | grep -q lumenim-backend; then
        log_success "lumenim-backend: 已注册"
        
        if systemctl is-active lumenim-backend &>/dev/null; then
            log_success "lumenim-backend: 运行中"
        else
            log_warn "lumenim-backend: 未运行"
        fi
    else
        log_warn "lumenim-backend: 未注册"
    fi
    
    if systemctl list-unit-files | grep -q lumenim-frontend; then
        log_success "lumenim-frontend: 已注册"
    else
        log_warn "lumenim-frontend: 未注册"
    fi
    
    # 6. 进程检查
    log_step "6. 进程状态"
    
    check_process "lumenim" && log_success "后端进程: 运行中" || log_warn "后端进程: 未运行"
    check_process "vite" && log_success "前端进程: 运行中" || log_warn "前端进程: 未运行"
    
    # 7. 日志检查
    log_step "7. 服务日志（最近 10 条）"
    journalctl -u lumenim-backend -n 10 --no-pager 2>/dev/null | tail -10 || true
    
    # 总结
    echo ""
    echo "=========================================="
    
    if [ $failed -eq 0 ]; then
        log_success "验证通过！"
    else
        log_error "验证失败！有 $failed 项检查未通过"
    fi
    
    echo ""
    echo "=========================================="
    echo "访问测试"
    echo "=========================================="
    echo "后端 API: http://localhost:9501"
    echo "WebSocket: ws://localhost:9502"
    echo "前端: http://localhost:5173"
    echo ""
}

# 执行
main