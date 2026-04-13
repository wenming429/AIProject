#!/bin/bash

#===============================================================================
# LumenIM 网络配置脚本
# 
# 功能: 配置局域网 IP 和域名访问
# 版本: 1.0.0
# 日期: 2026-04-09
#===============================================================================

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# 默认配置
SERVER_IP="192.168.23.131"
DOMAIN="mylumenim.cfldcn.com"
API_PORT="9501"
WS_PORT="9502"
HTTP_PORT="80"

# 路径配置
NGINX_CONFIG="/etc/nginx/sites-available/lumenim"
BACKEND_CONFIG="/var/www/lumenim/backend/config.yaml"
FRONTEND_ENV="/var/www/lumenim/front/.env.production"
FRONTEND_DIST="/var/www/lumenim/front/dist"

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

show_help() {
    cat << EOF
LumenIM 网络配置脚本

用法: $0 [选项]

选项:
    -i, --ip IP           局域网 IP 地址 (默认: ${SERVER_IP})
    -d, --domain DOMAIN   域名 (默认: ${DOMAIN})
    -p, --port PORT       HTTP 端口 (默认: ${HTTP_PORT})
    -a, --api-port PORT   API 端口 (默认: ${API_PORT})
    -w, --ws-port PORT    WebSocket 端口 (默认: ${WS_PORT})
    -s, --show            显示当前配置
    -h, --help            显示帮助

示例:
    # 配置局域网 IP 访问
    $0 --ip 192.168.23.131

    # 配置域名访问
    $0 --domain mylumenim.cfldcn.com

    # 同时配置 IP 和域名
    $0 --ip 192.168.23.131 --domain mylumenim.cfldcn.com

    # 自定义端口
    $0 --ip 192.168.23.131 --port 8080

    # 查看当前配置
    $0 --show
EOF
}

# 检查 root 权限
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "此脚本需要 root 权限运行"
        exit 1
    fi
}

# 显示当前配置
show_current_config() {
    log_info "=========================================="
    log_info "  当前网络配置"
    log_info "=========================================="
    echo ""
    
    log_info "网络参数:"
    echo "  - 服务器 IP: ${SERVER_IP}"
    echo "  - 域名:       ${DOMAIN}"
    echo "  - HTTP 端口:  ${HTTP_PORT}"
    echo "  - API 端口:   ${API_PORT}"
    echo "  - WS 端口:    ${WS_PORT}"
    echo ""
    
    log_info "服务监听状态:"
    ss -tlnp 2>/dev/null | grep -E "${HTTP_PORT}|${API_PORT}|${WS_PORT}" || echo "  未检测到相关端口监听"
    echo ""
    
    log_info "配置文件:"
    [[ -f "${NGINX_CONFIG}" ]] && log_success "Nginx: ${NGINX_CONFIG}" || log_warn "Nginx: 未找到"
    [[ -f "${BACKEND_CONFIG}" ]] && log_success "Backend: ${BACKEND_CONFIG}" || log_warn "Backend: 未找到"
    [[ -f "${FRONTEND_ENV}" ]] && log_success "Frontend: ${FRONTEND_ENV}" || log_warn "Frontend: 未找到"
    echo ""
    
    log_info "访问地址:"
    log_info "  局域网 IP: http://${SERVER_IP}/"
    log_info "  域名:      http://${DOMAIN}/"
    log_info "  API:       http://${SERVER_IP}:${API_PORT}/api/v1/health"
    echo ""
}

# 配置 Nginx
configure_nginx() {
    log_info "配置 Nginx..."
    
    if [[ ! -d "/etc/nginx/sites-available" ]]; then
        log_error "Nginx 配置目录不存在"
        return 1
    fi
    
    cat > "${NGINX_CONFIG}" << NGINXCONF
server {
    listen ${HTTP_PORT};
    server_name _ ${SERVER_IP} ${DOMAIN};
    
    root ${FRONTEND_DIST};
    index index.html;

    # 前端静态文件
    location / {
        try_files \$uri \$uri/ /index.html;
    }

    # API 反向代理
    location /api/ {
        proxy_pass http://127.0.0.1:${API_PORT}/api/;
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_connect_timeout 300s;
        proxy_send_timeout 300s;
        proxy_read_timeout 300s;
    }

    # WebSocket 支持
    location /ws {
        proxy_pass http://127.0.0.1:${WS_PORT};
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_read_timeout 86400s;
        proxy_send_timeout 86400s;
    }

    # 静态资源缓存
    location ~* \\.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot)\$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
        access_log off;
    }

    # 禁止访问隐藏文件
    location ~ /\\. {
        deny all;
        access_log off;
        log_not_found off;
    }

    # Gzip 压缩
    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_types text/plain text/css text/xml text/javascript application/javascript application/json application/xml;
}
NGINXCONF
    
    # 启用配置
    ln -sf "${NGINX_CONFIG}" /etc/nginx/sites-enabled/lumenim
    rm -f /etc/nginx/sites-enabled/default
    
    # 测试并重载
    nginx -t && systemctl reload nginx
    
    log_success "Nginx 配置完成"
}

# 配置后端
configure_backend() {
    log_info "配置后端..."
    
    if [[ ! -f "${BACKEND_CONFIG}" ]]; then
        log_warn "后端配置文件不存在: ${BACKEND_CONFIG}"
        return 1
    fi
    
    # 配置 CORS 允许跨域
    if [[ -n "${DOMAIN}" ]]; then
        sed -i "s|origin: \*|origin: \"http://${DOMAIN}\"|g" "${BACKEND_CONFIG}"
        log_info "CORS 域名: http://${DOMAIN}"
    elif [[ -n "${SERVER_IP}" ]]; then
        sed -i "s|origin: \*|origin: \"http://${SERVER_IP}\"|g" "${BACKEND_CONFIG}"
        log_info "CORS IP: http://${SERVER_IP}"
    fi
    
    # 确保绑定所有网卡
    sed -i "s|http_addr: .*|http_addr: \":${API_PORT}\"|g" "${BACKEND_CONFIG}"
    sed -i "s|websocket_addr: .*|websocket_addr: \":${WS_PORT}\"|g" "${BACKEND_CONFIG}"
    
    log_success "后端配置完成"
}

# 配置前端
configure_frontend() {
    log_info "配置前端..."
    
    if [[ ! -d "${FRONTEND_DIST}" ]]; then
        log_warn "前端构建目录不存在: ${FRONTEND_DIST}"
        log_info "前端将在首次构建后生效"
        return 1
    fi
    
    # 创建前端环境配置
    cat > "${FRONTEND_ENV}" << FRONTENDENV
# API 配置
VITE_API_BASE_URL=http://${SERVER_IP}/api
VITE_WS_URL=ws://${SERVER_IP}/ws

# 应用配置
VITE_APP_NAME=LumenIM
VITE_APP_ENV=production
FRONTENDENV
    
    chown -R lumenimadmin:lumenimadmin "${FRONTEND_ENV}"
    
    log_success "前端配置完成"
    log_info "API 地址: http://${SERVER_IP}/api"
    log_info "WebSocket: ws://${SERVER_IP}/ws"
}

# 配置防火墙
configure_firewall() {
    log_info "配置防火墙..."
    
    if command -v ufw >/dev/null 2>&1; then
        ufw allow ${HTTP_PORT}/tcp comment 'HTTP'
        ufw allow ${API_PORT}/tcp comment 'API'
        ufw allow ${WS_PORT}/tcp comment 'WebSocket'
        ufw reload 2>/dev/null || true
        log_success "防火墙规则已更新"
    else
        log_info "ufw 未安装，跳过防火墙配置"
    fi
}

# 重启服务
restart_services() {
    log_info "重启服务..."
    
    systemctl restart nginx
    systemctl restart lumenim-backend 2>/dev/null || true
    
    sleep 3
    
    log_success "服务已重启"
}

# 验证配置
verify_config() {
    log_info "验证配置..."
    echo ""
    
    # 检查端口
    log_info "端口监听状态:"
    ss -tlnp 2>/dev/null | grep -E "${HTTP_PORT}|${API_PORT}|${WS_PORT}" || echo "  未检测到端口监听"
    echo ""
    
    # 测试 API
    log_info "API 健康检查:"
    if curl -s -o /dev/null -w "HTTP %{http_code}" http://127.0.0.1:${API_PORT}/api/v1/health 2>/dev/null | grep -q "200\|301\|302"; then
        log_success "API 响应正常"
    else
        log_warn "API 可能未正常响应"
    fi
    echo ""
    
    # 测试 Nginx
    log_info "Nginx 反向代理测试:"
    if curl -s -o /dev/null -w "HTTP %{http_code}" http://127.0.0.1/api/v1/health 2>/dev/null | grep -q "200\|301\|302"; then
        log_success "Nginx 代理正常"
    else
        log_warn "Nginx 代理可能未正常响应"
    fi
}

# 主函数
main() {
    # 解析参数
    while [[ $# -gt 0 ]]; do
        case $1 in
            -i|--ip)
                SERVER_IP="$2"
                shift 2
                ;;
            -d|--domain)
                DOMAIN="$2"
                shift 2
                ;;
            -p|--port)
                HTTP_PORT="$2"
                shift 2
                ;;
            -a|--api-port)
                API_PORT="$2"
                shift 2
                ;;
            -w|--ws-port)
                WS_PORT="$2"
                shift 2
                ;;
            -s|--show)
                show_current_config
                exit 0
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            *)
                log_error "未知选项: $1"
                show_help
                exit 1
                ;;
        esac
    done
    
    check_root
    
    echo ""
    log_info "=========================================="
    log_info "  LumenIM 网络配置"
    log_info "=========================================="
    echo ""
    
    log_info "配置参数:"
    log_info "  - 服务器 IP: ${SERVER_IP}"
    log_info "  - 域名:      ${DOMAIN}"
    log_info "  - HTTP 端口: ${HTTP_PORT}"
    log_info "  - API 端口:  ${API_PORT}"
    log_info "  - WS 端口:   ${WS_PORT}"
    echo ""
    
    # 执行配置
    configure_nginx
    configure_backend
    configure_frontend
    configure_firewall
    restart_services
    
    # 验证
    echo ""
    verify_config
    
    # 显示结果
    echo ""
    log_info "=========================================="
    log_success "  网络配置完成!"
    log_info "=========================================="
    echo ""
    log_info "访问地址:"
    echo ""
    log_info "  局域网 IP 访问:"
    log_info "    前端: http://${SERVER_IP}/"
    log_info "    API:  http://${SERVER_IP}:${API_PORT}/api/v1/health"
    log_info "    WS:   ws://${SERVER_IP}/ws"
    echo ""
    
    if [[ -n "${DOMAIN}" ]]; then
        log_info "  域名访问 (需配置客户端 hosts):"
        log_info "    前端: http://${DOMAIN}/"
        log_info "    API:  http://${DOMAIN}/api/v1/health"
        log_info "    WS:   ws://${DOMAIN}/ws"
        echo ""
        log_warn "客户端 hosts 配置 (192.168.23.131 替换为实际服务器IP):"
        echo "    Windows: C:\\Windows\\System32\\drivers\\etc\\hosts"
        echo "    Linux:   /etc/hosts"
        echo "    添加: ${SERVER_IP}  ${DOMAIN}"
    fi
    
    echo ""
    log_info "=========================================="
    log_info "  客户端 hosts 配置模板"
    log_info "=========================================="
    echo ""
    echo "Windows (C:\\Windows\\System32\\drivers\\etc\\hosts):"
    echo "${SERVER_IP}  ${DOMAIN}"
    echo ""
    echo "Linux/macOS (/etc/hosts):"
    echo "${SERVER_IP}  ${DOMAIN}"
    echo ""
}

# 运行
main "$@"
