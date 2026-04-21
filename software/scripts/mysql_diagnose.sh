#!/bin/bash
#
# MySQL 连接诊断脚本
# 用于验证局域网内计算机访问服务器 MySQL 的连通性
#
# 使用方法: ./mysql_diagnose.sh [服务器IP] [MySQL端口]
#

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 默认值
SERVER_IP="${1:-192.168.23.131}"
MYSQL_PORT="${2:-3306}"
MYSQL_USER="lumenim"
MYSQL_PASS="lumenim123"
MYSQL_DB="go_chat"

# 测试计数器
TESTS_PASSED=0
TESTS_FAILED=0

print_header() {
    echo -e "\n${BLUE}========================================${NC}"
    echo -e "${BLUE}  MySQL 连接诊断工具${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""
    echo -e "${YELLOW}目标服务器:${NC} $SERVER_IP"
    echo -e "${YELLOW}MySQL 端口:${NC} $MYSQL_PORT"
    echo -e "${YELLOW}数据库用户:${NC} $MYSQL_USER"
    echo -e "${YELLOW}数据库名称:${NC} $MYSQL_DB"
    echo ""
}

log_pass() {
    echo -e "${GREEN}[PASS]${NC} $1"
    ((TESTS_PASSED++))
}

log_fail() {
    echo -e "${RED}[FAIL]${NC} $1"
    ((TESTS_FAILED++))
}

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

# ============================================================
# 测试 1: Ping 连通性测试
# ============================================================
test_ping() {
    echo -e "\n${YELLOW}=== 测试 1: 网络连通性 (Ping) ===${NC}"
    
    echo "正在 Ping $SERVER_IP..."
    
    # 发送 4 个 ping 包
    if command -v ping &> /dev/null; then
        if ping -c 4 -W 3 "$SERVER_IP" &> /dev/null; then
            log_pass "服务器 $SERVER_IP 可以 ping 通"
            return 0
        else
            log_fail "无法 ping 通 $SERVER_IP"
            log_warn "可能原因:"
            log_warn "  - 服务器关机或离线"
            log_warn "  - 网络隔离/VLAN 分隔"
            log_warn "  - 防火墙阻止 ICMP"
            return 1
        fi
    else
        log_warn "ping 命令不可用，跳过此测试"
        return 0
    fi
}

# ============================================================
# 测试 2: TCP 端口连通性测试
# ============================================================
test_tcp_port() {
    echo -e "\n${YELLOW}=== 测试 2: MySQL 端口连通性 ===${NC}"
    
    echo "正在测试端口 $SERVER_IP:$MYSQL_PORT..."
    
    if command -v nc &> /dev/null; then
        # 使用 nc 测试端口
        if nc -z -v -w 5 "$SERVER_IP" "$MYSQL_PORT" 2>&1 | grep -q "succeeded"; then
            log_pass "MySQL 端口 $MYSQL_PORT 已开放"
            return 0
        elif nc -z -w 5 "$SERVER_IP" "$MYSQL_PORT" 2>/dev/null; then
            log_pass "MySQL 端口 $MYSQL_PORT 可连接"
            return 0
        else
            log_fail "MySQL 端口 $MYSQL_PORT 无法连接"
            return 1
        fi
    elif command -v telnet &> /dev/null; then
        # 使用 telnet 测试（交互式）
        echo "使用 telnet 测试..."
        if echo "quit" | telnet "$SERVER_IP" "$MYSQL_PORT" 2>&1 | grep -q "Connected"; then
            log_pass "MySQL 端口 $MYSQL_PORT 可连接"
            return 0
        else
            log_fail "MySQL 端口 $MYSQL_PORT 无法连接"
            return 1
        fi
    elif command -v curl &> /dev/null; then
        # 使用 curl 测试
        if timeout 5 curl --connect-timeout 3 "$SERVER_IP:$MYSQL_PORT" 2>/dev/null; then
            log_pass "端口 $MYSQL_PORT 可连接"
            return 0
        else
            log_fail "端口 $MYSQL_PORT 无法连接"
            return 1
        fi
    else
        log_warn "无可用端口测试工具，建议安装: nc, telnet, 或 curl"
        log_info "或使用 Bash 内置方法测试: "
        log_info "  timeout 3 bash -c \"cat < /dev/null > /dev/tcp/$SERVER_IP/$MYSQL_PORT\" 2>/dev/null && echo 'OPEN'"
        return 1
    fi
}

# ============================================================
# 测试 3: MySQL 连接测试（基础）
# ============================================================
test_mysql_basic() {
    echo -e "\n${YELLOW}=== 测试 3: MySQL 服务状态 ===${NC}"
    
    # 检查本地 MySQL 服务
    log_info "检查 MySQL 服务状态..."
    
    if command -v mysql &> /dev/null; then
        # 本地测试
        log_info "尝试本地连接测试..."
        if mysql -u root -p"$MYSQL_ROOT_PASSWORD" -e "SELECT 1;" 2>/dev/null; then
            log_pass "MySQL 服务正在运行"
        else
            log_warn "本地 MySQL 连接失败（可能未安装或服务未启动）"
        fi
    else
        log_info "MySQL 客户端未安装"
    fi
    
    return 0
}

# ============================================================
# 测试 4: 远程 MySQL 连接测试
# ============================================================
test_mysql_remote() {
    echo -e "\n${YELLOW}=== 测试 4: 远程 MySQL 连接测试 ===${NC}"
    
    if ! command -v mysql &> /dev/null; then
        log_warn "MySQL 客户端未安装，无法测试远程连接"
        log_info "安装方法: apt install mysql-client"
        return 1
    fi
    
    echo "正在尝试连接 $SERVER_IP:$MYSQL_PORT..."
    
    # 尝试连接
    if mysql -h "$SERVER_IP" -P "$MYSQL_PORT" -u "$MYSQL_USER" -p"$MYSQL_PASS" \
        --connect-timeout=10 -e "SELECT 1;" "$MYSQL_DB" 2>/dev/null; then
        log_pass "远程 MySQL 连接成功！"
        
        # 获取服务器版本
        echo ""
        log_info "数据库信息:"
        mysql -h "$SERVER_IP" -P "$MYSQL_PORT" -u "$MYSQL_USER" -p"$MYSQL_PASS" \
            -e "SELECT VERSION() as 'MySQL Version';" "$MYSQL_DB" 2>/dev/null
        return 0
    else
        log_fail "远程 MySQL 连接失败"
        return 1
    fi
}

# ============================================================
# 常见问题诊断
# ============================================================
diagnose_issues() {
    echo -e "\n${BLUE}========================================${NC}"
    echo -e "${BLUE}  常见问题诊断${NC}"
    echo -e "${BLUE}========================================${NC}"
    
    echo -e "\n${YELLOW}1. 防火墙检查（服务器端）:${NC}"
    echo "   # 查看 UFW 防火墙状态"
    echo "   sudo ufw status"
    echo ""
    echo "   # 开放 MySQL 端口"
    echo "   sudo ufw allow $MYSQL_PORT/tcp"
    echo "   sudo ufw reload"
    
    echo -e "\n${YELLOW}2. MySQL 用户权限检查（服务器端）:${NC}"
    echo "   # 登录 MySQL"
    echo "   sudo mysql -u root -p"
    echo ""
    echo "   # 查看用户权限"
    echo "   SELECT user, host FROM mysql.user WHERE user='$MYSQL_USER';"
    echo ""
    echo "   # 授予远程访问权限"
    echo "   CREATE USER IF NOT EXISTS '$MYSQL_USER'@'%' IDENTIFIED BY '$MYSQL_PASS';"
    echo "   GRANT ALL PRIVILEGES ON $MYSQL_DB.* TO '$MYSQL_USER'@'%';"
    echo "   FLUSH PRIVILEGES;"
    
    echo -e "\n${YELLOW}3. MySQL 配置检查（服务器端）:${NC}"
    echo "   # 编辑 MySQL 配置"
    echo "   sudo nano /etc/mysql/mysql.conf.d/mysqld.cnf"
    echo ""
    echo "   # 确认 bind-address 设置"
    echo "   # 注释掉 bind-address = 127.0.0.1 或改为 0.0.0.0"
    echo "   # 重启 MySQL: sudo systemctl restart mysql"
    
    echo -e "\n${YELLOW}4. 客户端工具安装:${NC}"
    echo "   # Ubuntu/Debian"
    echo "   sudo apt update && sudo apt install mysql-client"
    echo ""
    echo "   # CentOS/RHEL"
    echo "   sudo yum install mysql"
}

# ============================================================
# 快速测试脚本（单次执行）
# ============================================================
quick_test() {
    print_header
    
    echo -e "\n${BLUE}开始诊断测试...${NC}\n"
    
    # 执行测试
    test_ping
    test_tcp_port
    test_mysql_basic
    test_mysql_remote
    
    # 输出结果汇总
    echo -e "\n${BLUE}========================================${NC}"
    echo -e "${BLUE}  测试结果汇总${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""
    echo -e "通过: ${GREEN}$TESTS_PASSED${NC} 项"
    echo -e "失败: ${RED}$TESTS_FAILED${NC} 项"
    
    if [ $TESTS_FAILED -gt 0 ]; then
        echo ""
        diagnose_issues
    else
        echo ""
        log_pass "所有测试通过！MySQL 连接正常。"
    fi
}

# ============================================================
# 交互式测试
# ============================================================
interactive_test() {
    print_header
    
    echo -e "\n${YELLOW}请输入 MySQL 用户密码（用于测试连接）:${NC}"
    read -s -p "密码: " MYSQL_PASS
    echo ""
    
    quick_test
}

# 显示帮助
show_help() {
    echo "MySQL 连接诊断工具"
    echo ""
    echo "用法: $0 [服务器IP] [端口] [-i]"
    echo ""
    echo "参数:"
    echo "  服务器IP   MySQL 服务器 IP（默认: 192.168.23.131）"
    echo "  端口       MySQL 端口（默认: 3306）"
    echo "  -i         交互式输入密码"
    echo "  -h         显示帮助"
    echo ""
    echo "示例:"
    echo "  $0                        # 使用默认配置测试"
    echo "  $0 192.168.1.100         # 测试指定 IP"
    echo "  $0 192.168.1.100 3307    # 测试指定 IP 和端口"
    echo "  $0 -i                     # 交互式测试"
}

# 主程序
case "${3:-}" in
    -i|--interactive)
        interactive_test
        ;;
    -h|--help)
        show_help
        ;;
    *)
        quick_test
        ;;
esac
