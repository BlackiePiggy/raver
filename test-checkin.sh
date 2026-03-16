#!/bin/bash

# 测试打卡功能

API_URL="http://localhost:3001/api"

echo "🧪 测试打卡功能"
echo ""

# 颜色定义
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

# 登录获取 token
echo -e "${BLUE}1. 登录获取 token...${NC}"
LOGIN_RESPONSE=$(curl -s -X POST "$API_URL/auth/login" \
  -H "Content-Type: application/json" \
  -d '{
    "email": "test@example.com",
    "password": "password123"
  }')

TOKEN=$(echo "$LOGIN_RESPONSE" | grep -o '"token":"[^"]*' | cut -d'"' -f4)

if [ -z "$TOKEN" ]; then
    echo -e "${RED}✗ 登录失败${NC}"
    exit 1
fi

echo -e "${GREEN}✓ 登录成功${NC}"
echo ""

# 获取第一个活动
echo -e "${BLUE}2. 获取活动...${NC}"
EVENTS_RESPONSE=$(curl -s "$API_URL/events?limit=1")
EVENT_ID=$(echo "$EVENTS_RESPONSE" | grep -o '"id":"[^"]*' | head -1 | cut -d'"' -f4)
EVENT_NAME=$(echo "$EVENTS_RESPONSE" | grep -o '"name":"[^"]*' | head -1 | cut -d'"' -f4)

if [ -z "$EVENT_ID" ]; then
    echo -e "${RED}✗ 没有找到活动${NC}"
    exit 1
fi

echo -e "${GREEN}✓ 找到活动: $EVENT_NAME${NC}"
echo ""

# 获取第一个 DJ
echo -e "${BLUE}3. 获取 DJ...${NC}"
DJS_RESPONSE=$(curl -s "$API_URL/djs?limit=1")
DJ_ID=$(echo "$DJS_RESPONSE" | grep -o '"id":"[^"]*' | head -1 | cut -d'"' -f4)
DJ_NAME=$(echo "$DJS_RESPONSE" | grep -o '"name":"[^"]*' | head -1 | cut -d'"' -f4)

if [ -z "$DJ_ID" ]; then
    echo -e "${RED}✗ 没有找到 DJ${NC}"
    exit 1
fi

echo -e "${GREEN}✓ 找到 DJ: $DJ_NAME${NC}"
echo ""

# 测试活动打卡
echo -e "${BLUE}4. 测试活动打卡...${NC}"
EVENT_CHECKIN_RESPONSE=$(curl -s -X POST "$API_URL/checkins" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d "{
    \"eventId\": \"$EVENT_ID\",
    \"type\": \"event\",
    \"note\": \"参加了 $EVENT_NAME\",
    \"rating\": 5
  }")

if echo "$EVENT_CHECKIN_RESPONSE" | grep -q "id"; then
    echo -e "${GREEN}✓ 活动打卡成功${NC}"
    EVENT_CHECKIN_ID=$(echo "$EVENT_CHECKIN_RESPONSE" | grep -o '"id":"[^"]*' | head -1 | cut -d'"' -f4)
else
    echo -e "${RED}✗ 活动打卡失败${NC}"
    echo "$EVENT_CHECKIN_RESPONSE"
fi
echo ""

# 测试 DJ 打卡
echo -e "${BLUE}5. 测试 DJ 打卡...${NC}"
DJ_CHECKIN_RESPONSE=$(curl -s -X POST "$API_URL/checkins" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d "{
    \"djId\": \"$DJ_ID\",
    \"type\": \"dj\",
    \"note\": \"打卡 $DJ_NAME\",
    \"rating\": 5
  }")

if echo "$DJ_CHECKIN_RESPONSE" | grep -q "id"; then
    echo -e "${GREEN}✓ DJ 打卡成功${NC}"
    DJ_CHECKIN_ID=$(echo "$DJ_CHECKIN_RESPONSE" | grep -o '"id":"[^"]*' | head -1 | cut -d'"' -f4)
else
    echo -e "${RED}✗ DJ 打卡失败${NC}"
    echo "$DJ_CHECKIN_RESPONSE"
fi
echo ""

# 测试获取我的打卡记录
echo -e "${BLUE}6. 测试获取我的打卡记录...${NC}"
MY_CHECKINS_RESPONSE=$(curl -s "$API_URL/checkins/my" \
  -H "Authorization: Bearer $TOKEN")

if echo "$MY_CHECKINS_RESPONSE" | grep -q "checkins"; then
    echo -e "${GREEN}✓ 获取打卡记录成功${NC}"
    CHECKIN_COUNT=$(echo "$MY_CHECKINS_RESPONSE" | grep -o '"total":[0-9]*' | cut -d':' -f2)
    echo "  打卡记录数: $CHECKIN_COUNT"
else
    echo -e "${RED}✗ 获取打卡记录失败${NC}"
fi
echo ""

echo -e "${GREEN}✅ 打卡功能测试完成！${NC}"
echo ""
echo "现在可以访问以下页面测试："
echo "  - 活动详情: http://localhost:3002/events/$EVENT_ID"
echo "  - DJ 详情: http://localhost:3002/djs/$DJ_ID"
echo "  - 我的打卡: http://localhost:3002/checkins"
