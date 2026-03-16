#!/bin/bash

# 测试认证系统

API_URL="http://localhost:3001/api"

echo "🧪 测试 Raver 认证系统"
echo ""

# 颜色定义
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

# 1. 测试健康检查
echo -e "${BLUE}1. 测试健康检查...${NC}"
HEALTH=$(curl -s http://localhost:3001/health)
if echo "$HEALTH" | grep -q "ok"; then
    echo -e "${GREEN}✓ 服务器运行正常${NC}"
else
    echo -e "${RED}✗ 服务器未运行${NC}"
    exit 1
fi
echo ""

# 2. 测试注册
echo -e "${BLUE}2. 测试用户注册...${NC}"
REGISTER_RESPONSE=$(curl -s -X POST "$API_URL/auth/register" \
  -H "Content-Type: application/json" \
  -d '{
    "username": "testuser",
    "email": "test@example.com",
    "password": "password123",
    "displayName": "Test User"
  }')

if echo "$REGISTER_RESPONSE" | grep -q "token"; then
    echo -e "${GREEN}✓ 注册成功${NC}"
    TOKEN=$(echo "$REGISTER_RESPONSE" | grep -o '"token":"[^"]*' | cut -d'"' -f4)
    echo "Token: ${TOKEN:0:20}..."
else
    echo -e "${RED}✗ 注册失败${NC}"
    echo "$REGISTER_RESPONSE"
fi
echo ""

# 3. 测试登录
echo -e "${BLUE}3. 测试用户登录...${NC}"
LOGIN_RESPONSE=$(curl -s -X POST "$API_URL/auth/login" \
  -H "Content-Type: application/json" \
  -d '{
    "email": "test@example.com",
    "password": "password123"
  }')

if echo "$LOGIN_RESPONSE" | grep -q "token"; then
    echo -e "${GREEN}✓ 登录成功${NC}"
    TOKEN=$(echo "$LOGIN_RESPONSE" | grep -o '"token":"[^"]*' | cut -d'"' -f4)
else
    echo -e "${RED}✗ 登录失败${NC}"
    echo "$LOGIN_RESPONSE"
    exit 1
fi
echo ""

# 4. 测试获取个人信息
echo -e "${BLUE}4. 测试获取个人信息...${NC}"
PROFILE_RESPONSE=$(curl -s "$API_URL/auth/profile" \
  -H "Authorization: Bearer $TOKEN")

if echo "$PROFILE_RESPONSE" | grep -q "username"; then
    echo -e "${GREEN}✓ 获取个人信息成功${NC}"
    echo "$PROFILE_RESPONSE" | grep -o '"username":"[^"]*' | cut -d'"' -f4
else
    echo -e "${RED}✗ 获取个人信息失败${NC}"
    echo "$PROFILE_RESPONSE"
fi
echo ""

echo -e "${GREEN}✅ 认证系统测试完成！${NC}"
