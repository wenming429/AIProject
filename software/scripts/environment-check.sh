#!/bin/bash
#===============================================================================
# LumenIM 环境全面验证脚本
# 使用方式: sudo ./environment-check.sh
#===============================================================================

set -e

# 配置
APP_NAME="LumenIM"
APP_DIR="/var/www/lumenim/backend"
FRONTEND_DIR="/var/www/lumenim/frontend"
BACKEND_PORT=9501
MYSQL_PORT=3306
REDIS_PORT=6379

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# 测试结果统计
TOTAL_CHECKS=0
PASS_CHECKS=0
FAIL_CHECKS=0
WARN_CHECKS=0

# 函数定义
print_header() {
    echo ""
    echo -e "${BOLD}${BLUE}============================================================${NC}"
    echo -e "${BOLD}${BLUE}  $1${NC}"
    echo -e "${BOLD}${BLUE}============================================================${NC}"
}

print_section() {
    echo ""
    echo -e "${CYAN}━━━ $1 ━━━${NC}"
}

pass() {
    echo -e "  ${GREEN}✓${NC} $1"
    ((PASS_CHECKS++))
}

fail() {
    echo -e "  ${RED}✗${NC} $1"
    ((FAIL_CHECKS++))
}

warn() {
    echo -e "  ${YELLOW}⚠${NC} $1"
    ((WARN_CHECKS++))
}

info() {
    echo -e "  ${BLUE}ℹ${NC} $1"
}

result() {
    ((TOTAL_CHECKS++))
    local status=$1
    local message=$2
    case $status in
        pass) pass "$message" ;;
        fail) fail "$message" ;;
        warn) warn "$message" ;;
    esac
}

separator() {
    echo ""
    echo "─────────────────────────────────────────────────────────"
}

# 获取命令输出（带超时）
run_cmd() {
    timeout 5 bash -c "$1" 2>/dev/null || echo "TIMEOUT_OR_ERROR"
}

#===============================================================================
print_header "LumenIM 运行环境全面验证"
echo -e "${BLUE}验证时间:${NC} $(date '+%Y-%m-%d %H:%M:%S')"
echo -e "${BLUE}主机名:${NC} $(hostname)"
echo -e "${BLUE}用户:${NC} $(whoami)"
echo -e "${BLUE}工作目录:${NC} $(pwd)"

#===============================================================================
print_section "一、系统环境检查"

# 1.1 系统信息
info "操作系统: $(cat /etc/os-release | grep PRETTY_NAME | cut -d'"' -f2)"
info "内核版本: $(uname -r)"
info "系统架构: $(uname -m)"

# 1.2 CPU 检查
CPU_CORES=$(nproc 2>/dev/null || echo "未知")
result pass "CPU 核心数: $CPU_CORES"

# 1.3 内存检查
MEM_TOTAL=$(free -h | grep Mem | awk '{print $2}')
MEM_USED=$(free -h | grep Mem | awk '{print $3}')
MEM_FREE=$(free -h | grep Mem | awk '{print $4}')
result pass "内存总量: $MEM_TOTAL (已用: $MEM_USED, 可用: $MEM_FREE)"

# 1.4 磁盘检查
DISK_USAGE=$(df -h / | tail -1 | awk '{print $5}' | sed 's/%//')
DISK_AVAIL=$(df -h / | tail -1 | awk '{print $4}')
if [ "$DISK_USAGE" -lt 80 ]; then
    result pass "磁盘使用率: ${DISK_USAGE}% (可用: $DISK_AVAIL)"
else
    result warn "磁盘使用率: ${DISK_USAGE}% (可用: $DISK_AVAIL) - 建议清理"
fi

# 1.5 运行时间
UPTIME=$(uptime -p 2>/dev/null || uptime)
result pass "系统运行时间: $UPTIME"

separator

#===============================================================================
print_section "二、网络连接检查"

# 2.1 DNS 解析
if run_cmd "ping -c 1 -W 2 8.8.8.8 &>/dev/null"; then
    result pass "外网连接: 正常"
else
    result fail "外网连接: 失败"
fi

# 2.2 DNS 解析测试
if run_cmd "nslookup github.com &>/dev/null"; then
    result pass "DNS 解析: github.com 正常"
else
    result warn "DNS 解析: github.com 异常"
fi

# 2.3 本地端口检查
if netstat -tlnp 2>/dev/null | grep -q ":" || ss -tlnp 2>/dev/null | grep -q ":"; then
    result pass "网络服务: 正常"
else
    result warn "网络服务: 无法检测"
fi

separator

#===============================================================================
print_section "三、Go 环境检查"

# 3.1 Go 安装检查
if command -v go &>/dev/null; then
    GO_VERSION=$(go version | grep -oP 'go[0-9]+\.[0-9]+(\.[0-9]+)?' | head -1)
    GO_PATH=$(which go)
    result pass "Go 已安装: $GO_VERSION"
    info "安装路径: $GO_PATH"

    # 3.2 Go 环境变量
    info "GOPATH: ${GOPATH:-$HOME/go}"
    info "GOROOT: $(go env GOROOT)"

    # 3.3 Go 模块代理
    GOPROXY=$(go env GOPROXY)
    if echo "$GOPROXY" | grep -q "goproxy.cn\|goproxy.io"; then
        result pass "Go 代理配置: $GOPROXY"
    else
        result warn "Go 代理配置: $GOPROXY (建议使用 https://goproxy.cn)"
    fi
else
    result fail "Go 未安装或未在 PATH 中"
fi

separator

#===============================================================================
print_section "四、Docker 环境检查"

# 4.1 Docker 安装检查
if command -v docker &>/dev/null; then
    DOCKER_VERSION=$(docker --version | grep -oP '[0-9]+\.[0-9]+(\.[0-9]+)?')
    result pass "Docker 已安装: $DOCKER_VERSION"

    # 4.2 Docker 服务状态
    if systemctl is-active --quiet docker 2>/dev/null; then
        result pass "Docker 服务: 运行中"
    else
        result fail "Docker 服务: 未运行"
    fi

    # 4.3 Docker 镜像检查
    DOCKER_IMAGES=$(docker images -q 2>/dev/null | wc -l)
    result pass "Docker 镜像数量: $DOCKER_IMAGES"

else
    result fail "Docker 未安装"
fi

separator

#===============================================================================
print_section "五、数据库服务检查 (MySQL)"

# 5.1 MySQL 容器检查
if docker ps --format '{{.Names}}' 2>/dev/null | grep -q "mysql\|lumenim-mysql"; then
    MYSQL_CONTAINER=$(docker ps --format '{{.Names}}' | grep -E "mysql|lumenim-mysql" | head -1)
    result pass "MySQL 容器: $MYSQL_CONTAINER"

    # 5.2 MySQL 容器状态
    if docker ps | grep -q "$MYSQL_CONTAINER.*Up"; then
        result pass "MySQL 容器状态: 运行中"
    else
        result fail "MySQL 容器状态: 未运行"
    fi

    # 5.3 MySQL 连接测试
    if docker exec $MYSQL_CONTAINER mysql -u root -pwenming429 -e "SELECT 1" &>/dev/null; then
        result pass "MySQL 连接: 成功"

        # 5.4 数据库检查
        DB_COUNT=$(docker exec $MYSQL_CONTAINER mysql -u root -pwenming429 -e "SHOW DATABASES;" 2>/dev/null | grep -c go_chat)
        if [ "$DB_COUNT" -gt 0 ]; then
            result pass "目标数据库 go_chat: 存在"
        else
            result warn "目标数据库 go_chat: 不存在"
        fi
    else
        result fail "MySQL 连接: 失败 (检查密码)"
    fi
else
    # 检查主机 MySQL
    if command -v mysql &>/dev/null; then
        if mysql -u root -e "SELECT 1" &>/dev/null; then
            result pass "MySQL 服务: 运行中"
        else
            result warn "MySQL 客户端存在但无法连接"
        fi
    else
        result warn "MySQL 容器: 未运行"
    fi
fi

separator

#===============================================================================
print_section "六、Redis 服务检查"

# 6.1 Redis 容器检查
if docker ps --format '{{.Names}}' 2>/dev/null | grep -q "redis\|lumenim-redis"; then
    REDIS_CONTAINER=$(docker ps --format '{{.Names}}' | grep -E "redis|lumenim-redis" | head -1)
    result pass "Redis 容器: $REDIS_CONTAINER"

    # 6.2 Redis 连接测试
    if docker exec $REDIS_CONTAINER redis-cli ping 2>/dev/null | grep -q "PONG"; then
        result pass "Redis 连接: PONG"
    else
        result fail "Redis 连接: 失败"
    fi
else
    # 检查主机 Redis
    if command -v redis-cli &>/dev/null; then
        if redis-cli ping 2>/dev/null | grep -q "PONG"; then
            result pass "Redis 服务: 运行中"
        else
            result warn "Redis 客户端存在但无法连接"
        fi
    else
        result warn "Redis 容器: 未运行"
    fi
fi

separator

#===============================================================================
print_section "七、后端服务检查"

# 7.1 应用目录检查
if [ -d "$APP_DIR" ]; then
    result pass "应用目录存在: $APP_DIR"
else
    result fail "应用目录不存在: $APP_DIR"
fi

# 7.2 可执行文件检查
if [ -f "$APP_DIR/lumenim" ]; then
    result pass "后端程序: lumenim 存在"

    # 检查执行权限
    if [ -x "$APP_DIR/lumenim" ]; then
        result pass "后端程序: 有执行权限"
    else
        result warn "后端程序: 缺少执行权限"
    fi

    # 7.3 程序信息
    info "程序大小: $(ls -lh $APP_DIR/lumenim | awk '{print $5}')"
    info "编译平台: $(file $APP_DIR/lumenim | grep -oP 'for .+$')"
else
    result fail "后端程序: lumenim 不存在"
fi

# 7.4 配置文件检查
if [ -f "$APP_DIR/config.yaml" ]; then
    result pass "配置文件: config.yaml 存在"
else
    result fail "配置文件: config.yaml 不存在"
fi

# 7.5 Systemd 服务检查
SERVICE_NAME="lumenim-backend"
if systemctl list-unit-files | grep -q "$SERVICE_NAME"; then
    result pass "Systemd 服务: $SERVICE_NAME 已注册"

    if systemctl is-active --quiet "$SERVICE_NAME" 2>/dev/null; then
        result pass "Systemd 服务: 运行中"

        # 7.6 服务进程检查
        PID=$(systemctl show -p MainPID --value "$SERVICE_NAME" 2>/dev/null)
        if [ -n "$PID" ] && [ "$PID" -gt 0 ]; then
            result pass "服务进程 PID: $PID"
        else
            result warn "服务进程: 无法获取 PID"
        fi
    else
        result fail "Systemd 服务: 未运行"
    fi
else
    result warn "Systemd 服务: $SERVICE_NAME 未注册"
fi

separator

#===============================================================================
print_section "八、端口监听检查"

# 8.1 后端端口
if netstat -tlnp 2>/dev/null | grep -q ":$BACKEND_PORT" || ss -tlnp 2>/dev/null | grep -q ":$BACKEND_PORT"; then
    result pass "后端端口 $BACKEND_PORT: 已监听"
else
    result warn "后端端口 $BACKEND_PORT: 未监听"
fi

# 8.2 MySQL 端口
if netstat -tlnp 2>/dev/null | grep -q ":$MYSQL_PORT" || ss -tlnp 2>/dev/null | grep -q ":$MYSQL_PORT"; then
    result pass "MySQL 端口 $MYSQL_PORT: 已监听"
else
    result warn "MySQL 端口 $MYSQL_PORT: 未监听 (可能在 Docker 内)"
fi

# 8.3 Redis 端口
if netstat -tlnp 2>/dev/null | grep -q ":$REDIS_PORT" || ss -tlnp 2>/dev/null | grep -q ":$REDIS_PORT"; then
    result pass "Redis 端口 $REDIS_PORT: 已监听"
else
    result warn "Redis 端口 $REDIS_PORT: 未监听 (可能在 Docker 内)"
fi

separator

#===============================================================================
print_section "九、后端健康检查"

# 9.1 HTTP 健康检查
HEALTH_URL="http://localhost:$BACKEND_PORT/api/v1/health"
if command -v curl &>/dev/null; then
    HEALTH_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 5 "$HEALTH_URL" 2>/dev/null || echo "000")
    if [ "$HEALTH_RESPONSE" = "200" ]; then
        result pass "健康检查 HTTP $HEALTH_RESPONSE: 正常"

        # 9.2 响应时间
        RESPONSE_TIME=$(curl -s -o /dev/null -w "%{time_total}" --connect-timeout 5 "$HEALTH_URL" 2>/dev/null || echo "0")
        if (( $(echo "$RESPONSE_TIME < 1" | bc -l 2>/dev/null || echo 1) )); then
            result pass "响应时间: ${RESPONSE_TIME}s (良好)"
        else
            result warn "响应时间: ${RESPONSE_TIME}s (较慢)"
        fi
    else
        result fail "健康检查 HTTP $HEALTH_RESPONSE: 异常"
    fi
else
    result warn "curl 未安装，无法进行 HTTP 检查"
fi

# 9.3 服务日志检查
LOG_FILE="$APP_DIR/logs/stdout.log"
if [ -f "$LOG_FILE" ]; then
    LOG_LINES=$(wc -l < "$LOG_FILE")
    info "日志行数: $LOG_LINES"

    # 检查是否有错误
    if grep -qi "panic\|fatal\|error" "$LOG_FILE" 2>/dev/null; then
        ERROR_COUNT=$(grep -ci "panic\|fatal\|error" "$LOG_FILE")
        result warn "日志中发现 $ERROR_COUNT 个错误关键字"
    else
        result pass "日志中无明显错误"
    fi
else
    info "日志文件: 未找到 (可能使用 journald)"
fi

separator

#===============================================================================
print_section "十、防火墙检查"

# 10.1 UFW 检查
if command -v ufw &>/dev/null; then
    if ufw status 2>/dev/null | grep -q "Status: active"; then
        result warn "防火墙 UFW: 已启用"
        info "后端端口 $BACKEND_PORT 规则:"
        ufw status 2>/dev/null | grep -E "$BACKEND_PORT|ALLOW" | head -3 || true
    else
        result pass "防火墙 UFW: 未启用"
    fi
else
    info "防火墙 UFW: 未安装"
fi

# 10.2 iptables 检查
if command -v iptables &>/dev/null; then
    IPT_RULES=$(iptables -L -n 2>/dev/null | wc -l)
    info "iptables 规则数: $IPT_RULES"
fi

separator

#===============================================================================
print_section "十一、依赖完整性检查"

# 11.1 go.mod 检查
if [ -f "$APP_DIR/go.mod" ]; then
    result pass "go.mod 文件: 存在"
    info "Go 版本要求: $(grep '^go ' $APP_DIR/go.mod | head -1)"
else
    result warn "go.mod 文件: 不存在"
fi

# 11.2 vendor 目录检查
if [ -d "$APP_DIR/vendor" ]; then
    VENDOR_SIZE=$(du -sh $APP_DIR/vendor 2>/dev/null | cut -f1)
    result pass "vendor 目录: 存在 ($VENDOR_SIZE)"
else
    result warn "vendor 目录: 不存在 (需要 go mod vendor)"
fi

# 11.3 SQL 文件检查
if [ -d "$APP_DIR/sql" ]; then
    SQL_FILES=$(ls $APP_DIR/sql/*.sql 2>/dev/null | wc -l)
    result pass "SQL 文件: $SQL_FILES 个"
else
    result warn "SQL 目录: 不存在"
fi

separator

#===============================================================================
print_section "十二、综合性能测试"

# 12.1 并发连接测试
info "测试并发请求 (10并发)..."
START_TIME=$(date +%s.%N)
for i in {1..10}; do
    curl -s "http://localhost:$BACKEND_PORT/api/v1/health" > /dev/null 2>&1 &
done
wait
END_TIME=$(date +%s.%N)
DURATION=$(echo "$END_TIME - $START_TIME" | bc 2>/dev/null || echo "0")

if (( $(echo "$DURATION < 3" | bc -l 2>/dev/null || echo 1) )); then
    result pass "并发性能: ${DURATION}s (良好)"
else
    result warn "并发性能: ${DURATION}s (较慢)"
fi

separator

#===============================================================================
print_section "十三、最终结果汇总"

echo ""
echo -e "${BOLD}检查项目统计:${NC}"
echo "─────────────────────────────────────────────────────────"
echo -e "  ${GREEN}通过: $PASS_CHECKS${NC}"
echo -e "  ${RED}失败: $FAIL_CHECKS${NC}"
echo -e "  ${YELLOW}警告: $WARN_CHECKS${NC}"
echo "─────────────────────────────────────────────────────────"

echo ""
if [ "$FAIL_CHECKS" -eq 0 ]; then
    if [ "$WARN_CHECKS" -eq 0 ]; then
        echo -e "${GREEN}${BOLD}✅ 环境验证通过！所有检查项正常。${NC}"
        EXIT_CODE=0
    else
        echo -e "${YELLOW}${BOLD}⚠️ 环境验证完成，有 $WARN_CHECKS 个警告项，但无失败项。${NC}"
        EXIT_CODE=0
    fi
else
    echo -e "${RED}${BOLD}❌ 环境验证失败！有 $FAIL_CHECKS 个检查项未通过。${NC}"
    echo ""
    echo -e "${RED}请根据上述失败项进行修复:${NC}"
    EXIT_CODE=1
fi

#===============================================================================
print_header "快速修复建议"

echo "
${YELLOW}常见问题修复命令:${NC}

1. 启动 Docker:
   sudo systemctl start docker
   sudo systemctl enable docker

2. 启动 MySQL 容器:
   docker run -d --name lumenim-mysql \\
     -e MYSQL_ROOT_PASSWORD=wenming429 \\
     -e MYSQL_DATABASE=go_chat \\
     -p 3306:3306 \\
     mysql:8.0.35

3. 启动 Redis 容器:
   docker run -d --name lumenim-redis \\
     -p 6379:6379 \\
     redis:7.4.1

4. 启动后端服务:
   cd $APP_DIR
   sudo systemctl daemon-reload
   sudo systemctl enable lumenim-backend
   sudo systemctl start lumenim-backend

5. 重新运行验证:
   sudo ./environment-check.sh
"

exit $EXIT_CODE
