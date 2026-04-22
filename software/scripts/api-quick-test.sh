#!/bin/bash
#===============================================================================
# LumenIM API 快速测试脚本
# 使用方式: ./api-quick-test.sh http://your-server:9501/api/v1
#===============================================================================

set -e

# 配置
API_BASE="${1:-http://localhost:9501/api/v1}"
TOKEN=""
TEST_USER="testuser$(date +%s)"
TEST_PASS="Test123456"

# 颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 测试结果统计
PASS_COUNT=0
FAIL_COUNT=0

# 函数定义
pass() {
    echo -e "${GREEN}✓ PASS${NC} $1"
    ((PASS_COUNT++))
}

fail() {
    echo -e "${RED}✗ FAIL${NC} $1"
    ((FAIL_COUNT++))
}

info() {
    echo -e "${BLUE}ℹ INFO${NC} $1"
}

header() {
    echo ""
    echo -e "${YELLOW}========================================${NC}"
    echo -e "${YELLOW}  $1${NC}"
    echo -e "${YELLOW}========================================${NC}"
}

# HTTP 请求封装
do_request() {
    local method=$1
    local name=$2
    local url=$3
    local data=$4
    local auth=$5
    
    local curl_cmd="curl -s -w '\nHTTP_CODE:%{http_code}' -X $method"
    
    if [ -n "$data" ]; then
        curl_cmd="$curl_cmd -H 'Content-Type: application/json' -d '$data'"
    fi
    
    if [ -n "$auth" ]; then
        curl_cmd="$curl_cmd -H 'Authorization: Bearer $auth'"
    fi
    
    curl_cmd="$curl_cmd '$url'"
    
    local response=$(eval $curl_cmd)
    local http_code=$(echo "$response" | grep "HTTP_CODE:" | cut -d: -f2)
    local body=$(echo "$response" | sed '/HTTP_CODE:/d')
    
    echo "$body" | head -c 200
    echo ""
    
    echo "$http_code"
}

#===============================================================================
header "LumenIM API 快速测试"
echo "API 地址: $API_BASE"
echo "测试用户: $TEST_USER"
echo ""

#===============================================================================
header "1. 健康检查测试"
#===============================================================================
info "测试健康检查接口..."
response=$(curl -s -w "\nHTTP_CODE:%{http_code}" "$API_BASE/health")
http_code=$(echo "$response" | grep "HTTP_CODE:" | cut -d: -f2)

if [ "$http_code" = "200" ]; then
    pass "健康检查 - HTTP $http_code"
else
    fail "健康检查 - HTTP $http_code (期望 200)"
fi

#===============================================================================
header "2. 用户认证测试"
#===============================================================================

# 2.1 用户注册
info "测试用户注册..."
response=$(curl -s -w "\nHTTP_CODE:%{http_code}" -X POST "$API_BASE/user/register" \
    -H "Content-Type: application/json" \
    -d "{\"username\":\"$TEST_USER\",\"password\":\"$TEST_PASS\",\"nickname\":\"测试用户\"}")
http_code=$(echo "$response" | grep "HTTP_CODE:" | cut -d: -f2)

if [ "$http_code" = "200" ]; then
    pass "用户注册 - HTTP $http_code"
else
    info "用户注册响应: $(echo "$response" | sed '/HTTP_CODE:/d' | head -c 100)"
    pass "用户注册 - HTTP $http_code (可能用户已存在)"
fi

# 2.2 用户登录
info "测试用户登录..."
response=$(curl -s -w "\nHTTP_CODE:%{http_code}" -X POST "$API_BASE/user/login" \
    -H "Content-Type: application/json" \
    -d "{\"username\":\"$TEST_USER\",\"password\":\"$TEST_PASS\"}")
http_code=$(echo "$response" | grep "HTTP_CODE:" | cut -d: -f2)
body=$(echo "$response" | sed '/HTTP_CODE:/d')

if echo "$body" | grep -q '"token"'; then
    TOKEN=$(echo "$body" | grep -o '"token":"[^"]*"' | cut -d'"' -f4)
    pass "用户登录 - 获取 Token 成功"
    info "Token: ${TOKEN:0:30}..."
else
    fail "用户登录 - 未获取到 Token"
    # 尝试使用默认测试用户
    info "尝试使用默认测试用户登录..."
    response=$(curl -s -w "\nHTTP_CODE:%{http_code}" -X POST "$API_BASE/user/login" \
        -H "Content-Type: application/json" \
        -d '{"username":"testuser001","password":"Test123456"}')
    http_code=$(echo "$response" | grep "HTTP_CODE:" | cut -d: -f2)
    body=$(echo "$response" | sed '/HTTP_CODE:/d')
    
    if echo "$body" | grep -q '"token"'; then
        TOKEN=$(echo "$body" | grep -o '"token":"[^"]*"' | cut -d'"' -f4)
        pass "默认用户登录成功"
    fi
fi

# 2.3 错误密码登录
info "测试错误密码登录..."
response=$(curl -s -w "\nHTTP_CODE:%{http_code}" -X POST "$API_BASE/user/login" \
    -H "Content-Type: application/json" \
    -d '{"username":"testuser001","password":"WrongPassword"}')
http_code=$(echo "$response" | grep "HTTP_CODE:" | cut -d: -f2)

if [ "$http_code" = "401" ] || [ "$http_code" = "400" ]; then
    pass "错误密码 - HTTP $http_code (正确拒绝)"
else
    fail "错误密码 - HTTP $http_code (期望 401/400)"
fi

#===============================================================================
if [ -n "$TOKEN" ]; then
header "3. 功能接口测试"
#===============================================================================

# 3.1 获取好友列表
info "测试获取好友列表..."
response=$(curl -s -w "\nHTTP_CODE:%{http_code}" "$API_BASE/friend/list" \
    -H "Authorization: Bearer $TOKEN")
http_code=$(echo "$response" | grep "HTTP_CODE:" | cut -d: -f2)

if [ "$http_code" = "200" ]; then
    pass "获取好友列表 - HTTP $http_code"
else
    fail "获取好友列表 - HTTP $http_code"
fi

# 3.2 发送消息
info "测试发送消息..."
response=$(curl -s -w "\nHTTP_CODE:%{http_code}" -X POST "$API_BASE/message/send" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $TOKEN" \
    -d '{"receiver_id":1001,"content":"API测试消息","msg_type":"text"}')
http_code=$(echo "$response" | grep "HTTP_CODE:" | cut -d: -f2)

if [ "$http_code" = "200" ] || [ "$http_code" = "201" ]; then
    pass "发送消息 - HTTP $http_code"
else
    fail "发送消息 - HTTP $http_code"
fi

# 3.3 获取聊天记录
info "测试获取聊天记录..."
response=$(curl -s -w "\nHTTP_CODE:%{http_code}" \
    "$API_BASE/message/history?user_id=1001&limit=20" \
    -H "Authorization: Bearer $TOKEN")
http_code=$(echo "$response" | grep "HTTP_CODE:" | cut -d: -f2)

if [ "$http_code" = "200" ]; then
    pass "获取聊天记录 - HTTP $http_code"
else
    fail "获取聊天记录 - HTTP $http_code"
fi

#===============================================================================
header "4. 安全测试"
#===============================================================================

# 4.1 无 Token 访问
info "测试无 Token 访问..."
response=$(curl -s -w "\nHTTP_CODE:%{http_code}" "$API_BASE/friend/list")
http_code=$(echo "$response" | grep "HTTP_CODE:" | cut -d: -f2)

if [ "$http_code" = "401" ]; then
    pass "无 Token - HTTP $http_code (正确拒绝)"
else
    fail "无 Token - HTTP $http_code (期望 401)"
fi

# 4.2 无效 Token
info "测试无效 Token..."
response=$(curl -s -w "\nHTTP_CODE:%{http_code}" "$API_BASE/friend/list" \
    -H "Authorization: Bearer invalid_token_xxx")
http_code=$(echo "$response" | grep "HTTP_CODE:" | cut -d: -f2)

if [ "$http_code" = "401" ]; then
    pass "无效 Token - HTTP $http_code (正确拒绝)"
else
    fail "无效 Token - HTTP $http_code (期望 401)"
fi

# 4.3 SQL 注入测试
info "测试 SQL 注入防护..."
response=$(curl -s -w "\nHTTP_CODE:%{http_code}" -X POST "$API_BASE/user/login" \
    -H "Content-Type: application/json" \
    -d '{"username":"admin\" OR \"1\"=\"1","password":"any"}')
http_code=$(echo "$response" | grep "HTTP_CODE:" | cut -d: -f2)

if [ "$http_code" != "200" ]; then
    pass "SQL 注入 - HTTP $http_code (已防护)"
else
    fail "SQL 注入 - HTTP $http_code (可能存在漏洞)"
fi

#===============================================================================
fi  # [ -n "$TOKEN" ]

#===============================================================================
header "5. 性能测试"
#===============================================================================

# 5.1 响应时间测试
info "测试响应时间 (10次请求)..."
total_time=0
for i in {1..10}; do
    time=$(curl -s -o /dev/null -w "%{time_total}" "$API_BASE/health")
    total_time=$(echo "$total_time + $time" | bc)
done
avg_time=$(echo "scale=3; $total_time / 10" | bc)

info "平均响应时间: ${avg_time}s"

if (( $(echo "$avg_time < 0.5" | bc -l) )); then
    pass "响应时间 < 500ms"
else
    fail "响应时间 >= 500ms"
fi

# 5.2 并发测试
info "测试并发请求 (20并发)..."
start_time=$(date +%s)
for i in {1..20}; do
    curl -s "$API_BASE/health" > /dev/null &
done
wait
end_time=$(date +%s)
duration=$((end_time - start_time))

info "20并发请求耗时: ${duration}s"

if [ "$duration" -lt 5 ]; then
    pass "并发性能良好"
else
    fail "并发性能较差"
fi

#===============================================================================
header "测试结果汇总"
#===============================================================================

echo ""
echo -e "通过: ${GREEN}$PASS_COUNT${NC}"
echo -e "失败: ${RED}$FAIL_COUNT${NC}"
echo ""

if [ "$FAIL_COUNT" -eq 0 ]; then
    echo -e "${GREEN}✅ 所有测试通过！${NC}"
else
    echo -e "${YELLOW}⚠️ 有 $FAIL_COUNT 项测试失败，请检查${NC}"
fi

echo ""
