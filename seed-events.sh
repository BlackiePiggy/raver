#!/bin/bash

# 创建测试活动数据

API_URL="http://localhost:3001/api"

echo "🎪 创建测试活动数据"
echo ""

# 颜色定义
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

# 首先登录获取 token
echo -e "${BLUE}1. 登录获取 token...${NC}"
LOGIN_RESPONSE=$(curl -s -X POST "$API_URL/auth/login" \
  -H "Content-Type: application/json" \
  -d '{
    "email": "test@example.com",
    "password": "password123"
  }')

TOKEN=$(echo "$LOGIN_RESPONSE" | grep -o '"token":"[^"]*' | cut -d'"' -f4)

if [ -z "$TOKEN" ]; then
    echo "登录失败，请先运行 test-auth.sh 创建测试用户"
    exit 1
fi

echo -e "${GREEN}✓ 登录成功${NC}"
echo ""

# 创建测试活动
echo -e "${BLUE}2. 创建测试活动...${NC}"

# 活动 1
curl -s -X POST "$API_URL/events" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{
    "name": "Ultra Music Festival 2026",
    "slug": "ultra-music-festival-2026",
    "description": "全球最大的电子音乐节之一，汇聚世界顶级DJ和制作人。",
    "city": "Miami",
    "country": "USA",
    "venueName": "Bayfront Park",
    "venueAddress": "301 Biscayne Blvd, Miami, FL 33132",
    "startDate": "2026-03-27T12:00:00Z",
    "endDate": "2026-03-29T23:00:00Z",
    "ticketUrl": "https://ultramusicfestival.com",
    "officialWebsite": "https://ultramusicfestival.com",
    "status": "upcoming"
  }' > /dev/null

echo -e "${GREEN}✓ 创建活动: Ultra Music Festival 2026${NC}"

# 活动 2
curl -s -X POST "$API_URL/events" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{
    "name": "Tomorrowland 2026",
    "slug": "tomorrowland-2026",
    "description": "比利时传奇电音节，以其梦幻般的舞台设计和顶级阵容闻名。",
    "city": "Boom",
    "country": "Belgium",
    "venueName": "De Schorre",
    "startDate": "2026-07-17T12:00:00Z",
    "endDate": "2026-07-26T23:00:00Z",
    "ticketUrl": "https://www.tomorrowland.com",
    "officialWebsite": "https://www.tomorrowland.com",
    "status": "upcoming"
  }' > /dev/null

echo -e "${GREEN}✓ 创建活动: Tomorrowland 2026${NC}"

# 活动 3
curl -s -X POST "$API_URL/events" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{
    "name": "EDC Las Vegas 2026",
    "slug": "edc-las-vegas-2026",
    "description": "Electric Daisy Carnival，北美最大的电子音乐节。",
    "city": "Las Vegas",
    "country": "USA",
    "venueName": "Las Vegas Motor Speedway",
    "startDate": "2026-05-15T18:00:00Z",
    "endDate": "2026-05-17T06:00:00Z",
    "ticketUrl": "https://lasvegas.electricdaisycarnival.com",
    "officialWebsite": "https://lasvegas.electricdaisycarnival.com",
    "status": "upcoming"
  }' > /dev/null

echo -e "${GREEN}✓ 创建活动: EDC Las Vegas 2026${NC}"

# 活动 4
curl -s -X POST "$API_URL/events" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{
    "name": "Creamfields 2026",
    "slug": "creamfields-2026",
    "description": "英国最大的电子音乐节，拥有多个舞台和多样化的音乐风格。",
    "city": "Daresbury",
    "country": "UK",
    "venueName": "Daresbury Estate",
    "startDate": "2026-08-27T12:00:00Z",
    "endDate": "2026-08-30T23:00:00Z",
    "ticketUrl": "https://www.creamfields.com",
    "officialWebsite": "https://www.creamfields.com",
    "status": "upcoming"
  }' > /dev/null

echo -e "${GREEN}✓ 创建活动: Creamfields 2026${NC}"

# 活动 5
curl -s -X POST "$API_URL/events" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{
    "name": "Storm Festival Shanghai 2026",
    "slug": "storm-festival-shanghai-2026",
    "description": "中国最大的电子音乐节之一，汇聚国内外顶级DJ。",
    "city": "上海",
    "country": "中国",
    "venueName": "上海世博公园",
    "startDate": "2026-04-30T14:00:00Z",
    "endDate": "2026-05-02T23:00:00Z",
    "status": "upcoming"
  }' > /dev/null

echo -e "${GREEN}✓ 创建活动: Storm Festival Shanghai 2026${NC}"

# 活动 6
curl -s -X POST "$API_URL/events" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{
    "name": "Road to Ultra Beijing 2026",
    "slug": "road-to-ultra-beijing-2026",
    "description": "Ultra Music Festival 的中国站，带来国际顶级电音体验。",
    "city": "北京",
    "country": "中国",
    "venueName": "北京奥林匹克公园",
    "startDate": "2026-09-12T14:00:00Z",
    "endDate": "2026-09-12T23:00:00Z",
    "status": "upcoming"
  }' > /dev/null

echo -e "${GREEN}✓ 创建活动: Road to Ultra Beijing 2026${NC}"

echo ""
echo -e "${GREEN}✅ 测试数据创建完成！${NC}"
echo ""
echo "访问 http://localhost:3002/events 查看活动列表"
