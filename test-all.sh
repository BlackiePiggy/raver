#!/bin/bash

# Raver 项目完整测试脚本

echo "🎵 Raver 项目完整测试"
echo "===================="
echo ""

# 颜色定义
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

# 测试计数
PASSED=0
FAILED=0

# 测试函数
test_endpoint() {
    local name=$1
    local url=$2
    local expected=$3

    echo -n "测试 $name... "

    response=$(curl -s "$url")

    if echo "$response" | grep -q "$expected"; then
        echo -e "${GREEN}✓ 通过${NC}"
        ((PASSED++))
        return 0
    else
        echo -e "${RED}✗ 失败${NC}"
        echo "  响应: $response"
        ((FAILED++))
        return 1
    fi
}

# 1. 检查 Docker 容器
echo -e "${BLUE}1. 检查基础设施${NC}"
echo "-------------------"

if docker ps | grep -q "raver-postgres"; then
    echo -e "${GREEN}✓ PostgreSQL 运行中${NC}"
    ((PASSED++))
else
    echo -e "${RED}✗ PostgreSQL 未运行${NC}"
    ((FAILED++))
fi

if docker ps | grep -q "raver-redis"; then
    echo -e "${GREEN}✓ Redis 运行中${NC}"
    ((PASSED++))
else
    echo -e "${RED}✗ Redis 未运行${NC}"
    ((FAILED++))
fi

echo ""

# 2. 测试后端服务器
echo -e "${BLUE}2. 测试后端 API${NC}"
echo "-------------------"

test_endpoint "健康检查" "http://localhost:3001/health" "ok"
test_endpoint "API 根路径" "http://localhost:3001/api" "Raver API Server"

echo ""

# 3. 测试认证 API
echo -e "${BLUE}3. 测试认证系统${NC}"
echo "-------------------"

# 登录获取 token
LOGIN_RESPONSE=$(curl -s -X POST "http://localhost:3001/api/auth/login" \
  -H "Content-Type: application/json" \
  -d '{
    "email": "test@example.com",
    "password": "password123"
  }')

if echo "$LOGIN_RESPONSE" | grep -q "token"; then
    echo -e "${GREEN}✓ 用户登录${NC}"
    ((PASSED++))
    TOKEN=$(echo "$LOGIN_RESPONSE" | grep -o '"token":"[^"]*' | cut -d'"' -f4)
else
    echo -e "${RED}✗ 用户登录失败${NC}"
    ((FAILED++))
    TOKEN=""
fi

if [ -n "$TOKEN" ]; then
    PROFILE_RESPONSE=$(curl -s "http://localhost:3001/api/auth/profile" \
      -H "Authorization: Bearer $TOKEN")

    if echo "$PROFILE_RESPONSE" | grep -q "username"; then
        echo -e "${GREEN}✓ 获取用户信息${NC}"
        ((PASSED++))
    else
        echo -e "${RED}✗ 获取用户信息失败${NC}"
        ((FAILED++))
    fi
fi

echo ""

# 4. 测试活动 API
echo -e "${BLUE}4. 测试活动模块${NC}"
echo "-------------------"

test_endpoint "活动列表" "http://localhost:3001/api/events" "events"

EVENTS_RESPONSE=$(curl -s "http://localhost:3001/api/events?limit=1")
EVENT_ID=$(echo "$EVENTS_RESPONSE" | grep -o '"id":"[^"]*' | head -1 | cut -d'"' -f4)

if [ -n "$EVENT_ID" ]; then
    test_endpoint "活动详情" "http://localhost:3001/api/events/$EVENT_ID" "name"
else
    echo -e "${YELLOW}⚠ 跳过活动详情测试（无活动数据）${NC}"
fi

echo ""

# 5. 测试 DJ API
echo -e "${BLUE}5. 测试 DJ 模块${NC}"
echo "-------------------"

test_endpoint "DJ 列表" "http://localhost:3001/api/djs" "djs"

DJS_RESPONSE=$(curl -s "http://localhost:3001/api/djs?limit=1")
DJ_ID=$(echo "$DJS_RESPONSE" | grep -o '"id":"[^"]*' | head -1 | cut -d'"' -f4)

if [ -n "$DJ_ID" ]; then
    test_endpoint "DJ 详情" "http://localhost:3001/api/djs/$DJ_ID" "name"
else
    echo -e "${YELLOW}⚠ 跳过 DJ 详情测试（无 DJ 数据）${NC}"
fi

echo ""

# 6. 测试打卡和关注 API
echo -e "${BLUE}6. 测试打卡和关注${NC}"
echo "-------------------"

if [ -n "$TOKEN" ] && [ -n "$DJ_ID" ]; then
    # 测试关注
    FOLLOW_RESPONSE=$(curl -s -X POST "http://localhost:3001/api/follows/dj" \
      -H "Content-Type: application/json" \
      -H "Authorization: Bearer $TOKEN" \
      -d "{\"djId\": \"$DJ_ID\"}" 2>/dev/null)

    if echo "$FOLLOW_RESPONSE" | grep -q "id"; then
        echo -e "${GREEN}✓ 关注 DJ${NC}"
        ((PASSED++))
    else
        echo -e "${YELLOW}⚠ 关注 DJ（可能已关注）${NC}"
    fi

    # 测试打卡
    CHECKIN_RESPONSE=$(curl -s -X POST "http://localhost:3001/api/checkins" \
      -H "Content-Type: application/json" \
      -H "Authorization: Bearer $TOKEN" \
      -d "{\"djId\": \"$DJ_ID\", \"type\": \"dj\", \"note\": \"测试打卡\"}" 2>/dev/null)

    if echo "$CHECKIN_RESPONSE" | grep -q "id"; then
        echo -e "${GREEN}✓ DJ 打卡${NC}"
        ((PASSED++))
    else
        echo -e "${RED}✗ DJ 打卡失败${NC}"
        ((FAILED++))
    fi

    # 测试获取打卡记录
    MY_CHECKINS=$(curl -s "http://localhost:3001/api/checkins/my" \
      -H "Authorization: Bearer $TOKEN" 2>/dev/null)

    if echo "$MY_CHECKINS" | grep -q "checkins"; then
        echo -e "${GREEN}✓ 获取打卡记录${NC}"
        ((PASSED++))
    else
        echo -e "${RED}✗ 获取打卡记录失败${NC}"
        ((FAILED++))
    fi
else
    echo -e "${YELLOW}⚠ 跳过打卡和关注测试（需要登录和 DJ 数据）${NC}"
fi

echo ""

# 7. 测试前端
echo -e "${BLUE}7. 测试前端页面${NC}"
echo "-------------------"

test_endpoint "首页" "http://localhost:3002" "Raver"
test_endpoint "登录页" "http://localhost:3002/login" "Login"
test_endpoint "注册页" "http://localhost:3002/register" "Register"
test_endpoint "活动列表页" "http://localhost:3002/events" "电音活动"
test_endpoint "DJ 列表页" "http://localhost:3002/djs" "DJ 库"

echo ""

# 8. 数据统计
echo -e "${BLUE}8. 数据统计${NC}"
echo "-------------------"

EVENTS_COUNT=$(curl -s "http://localhost:3001/api/events" | grep -o '"total":[0-9]*' | cut -d':' -f2)
DJS_COUNT=$(curl -s "http://localhost:3001/api/djs" | grep -o '"total":[0-9]*' | cut -d':' -f2)

echo "活动数量: ${EVENTS_COUNT:-0}"
echo "DJ 数量: ${DJS_COUNT:-0}"

echo ""

# 总结
echo "===================="
echo -e "${BLUE}测试总结${NC}"
echo "===================="
echo -e "通过: ${GREEN}$PASSED${NC}"
echo -e "失败: ${RED}$FAILED${NC}"
echo ""

if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}✅ 所有测试通过！${NC}"
    echo ""
    echo "访问以下地址体验应用:"
    echo -e "  前端: ${BLUE}http://localhost:3002${NC}"
    echo -e "  后端: ${BLUE}http://localhost:3001${NC}"
    echo ""
    exit 0
else
    echo -e "${RED}❌ 部分测试失败${NC}"
    echo ""
    echo "请检查失败的测试项并修复问题"
    echo ""
    exit 1
fi
