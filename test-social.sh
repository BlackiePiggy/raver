#!/bin/bash

# 测试打卡和关注功能

API_URL="http://localhost:3001/api"

echo "🧪 测试打卡和关注功能"
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

# 获取第一个 DJ
echo -e "${BLUE}2. 获取 DJ 列表...${NC}"
DJS_RESPONSE=$(curl -s "$API_URL/djs?limit=1")
DJ_ID=$(echo "$DJS_RESPONSE" | grep -o '"id":"[^"]*' | head -1 | cut -d'"' -f4)
DJ_NAME=$(echo "$DJS_RESPONSE" | grep -o '"name":"[^"]*' | head -1 | cut -d'"' -f4)

if [ -z "$DJ_ID" ]; then
    echo -e "${RED}✗ 没有找到 DJ${NC}"
    exit 1
fi

echo -e "${GREEN}✓ 找到 DJ: $DJ_NAME${NC}"
echo ""

# 测试关注 DJ
echo -e "${BLUE}3. 测试关注 DJ...${NC}"
FOLLOW_RESPONSE=$(curl -s -X POST "$API_URL/follows/dj" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d "{\"djId\": \"$DJ_ID\"}")

if echo "$FOLLOW_RESPONSE" | grep -q "id"; then
    echo -e "${GREEN}✓ 关注成功${NC}"
else
    echo -e "${RED}✗ 关注失败${NC}"
    echo "$FOLLOW_RESPONSE"
fi
echo ""

# 测试检查关注状态
echo -e "${BLUE}4. 测试检查关注状态...${NC}"
STATUS_RESPONSE=$(curl -s "$API_URL/follows/dj/$DJ_ID/status" \
  -H "Authorization: Bearer $TOKEN")

if echo "$STATUS_RESPONSE" | grep -q "true"; then
    echo -e "${GREEN}✓ 关注状态正确${NC}"
else
    echo -e "${RED}✗ 关注状态错误${NC}"
fi
echo ""

# 测试 DJ 打卡
echo -e "${BLUE}5. 测试 DJ 打卡...${NC}"
CHECKIN_RESPONSE=$(curl -s -X POST "$API_URL/checkins" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d "{
    \"djId\": \"$DJ_ID\",
    \"type\": \"dj\",
    \"note\": \"测试打卡 $DJ_NAME\",
    \"rating\": 5
  }")

if echo "$CHECKIN_RESPONSE" | grep -q "id"; then
    echo -e "${GREEN}✓ 打卡成功${NC}"
    CHECKIN_ID=$(echo "$CHECKIN_RESPONSE" | grep -o '"id":"[^"]*' | head -1 | cut -d'"' -f4)
else
    echo -e "${RED}✗ 打卡失败${NC}"
    echo "$CHECKIN_RESPONSE"
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

# 测试获取我关注的 DJ
echo -e "${BLUE}7. 测试获取我关注的 DJ...${NC}"
MY_FOLLOWS_RESPONSE=$(curl -s "$API_URL/follows/my/djs" \
  -H "Authorization: Bearer $TOKEN")

if echo "$MY_FOLLOWS_RESPONSE" | grep -q "follows"; then
    echo -e "${GREEN}✓ 获取关注列表成功${NC}"
    FOLLOW_COUNT=$(echo "$MY_FOLLOWS_RESPONSE" | grep -o '"total":[0-9]*' | cut -d':' -f2)
    echo "  关注数: $FOLLOW_COUNT"
else
    echo -e "${RED}✗ 获取关注列表失败${NC}"
fi
echo ""

# 测试取消关注
echo -e "${BLUE}8. 测试取消关注...${NC}"
UNFOLLOW_RESPONSE=$(curl -s -X DELETE "$API_URL/follows/dj/$DJ_ID" \
  -H "Authorization: Bearer $TOKEN" \
  -w "%{http_code}")

if [ "$UNFOLLOW_RESPONSE" = "204" ]; then
    echo -e "${GREEN}✓ 取消关注成功${NC}"
else
    echo -e "${RED}✗ 取消关注失败${NC}"
fi
echo ""

echo -e "${GREEN}✅ 打卡和关注功能测试完成！${NC}"
