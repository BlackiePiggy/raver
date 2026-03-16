#!/bin/bash

# 创建测试 DJ 数据

API_URL="http://localhost:3001/api"

echo "🎧 创建测试 DJ 数据"
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

# 创建测试 DJ
echo -e "${BLUE}2. 创建测试 DJ...${NC}"

# DJ 1 - Martin Garrix
curl -s -X POST "$API_URL/djs" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{
    "name": "Martin Garrix",
    "slug": "martin-garrix",
    "bio": "荷兰DJ和音乐制作人，以其充满活力的电子舞曲而闻名。代表作品包括《Animals》、《Scared to be Lonely》等。",
    "country": "Netherlands",
    "spotifyId": "60d24wfXkVzDSfLS6hyCjZ",
    "soundcloudUrl": "https://soundcloud.com/martingarrix",
    "instagramUrl": "https://instagram.com/martingarrix",
    "twitterUrl": "https://twitter.com/MartinGarrix",
    "followerCount": 8500000
  }' > /dev/null

echo -e "${GREEN}✓ 创建 DJ: Martin Garrix${NC}"

# DJ 2 - David Guetta
curl -s -X POST "$API_URL/djs" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{
    "name": "David Guetta",
    "slug": "david-guetta",
    "bio": "法国DJ、音乐制作人和词曲作者，电子舞曲界的传奇人物。多次获得格莱美奖，代表作品包括《Titanium》、《When Love Takes Over》等。",
    "country": "France",
    "spotifyId": "1Cs0zKBU1kc0i8ypK3B9ai",
    "soundcloudUrl": "https://soundcloud.com/davidguetta",
    "instagramUrl": "https://instagram.com/davidguetta",
    "twitterUrl": "https://twitter.com/davidguetta",
    "followerCount": 12000000
  }' > /dev/null

echo -e "${GREEN}✓ 创建 DJ: David Guetta${NC}"

# DJ 3 - Armin van Buuren
curl -s -X POST "$API_URL/djs" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{
    "name": "Armin van Buuren",
    "slug": "armin-van-buuren",
    "bio": "荷兰Trance音乐DJ和制作人，五次获得DJ Mag全球百大DJ冠军。主持著名电台节目《A State of Trance》。",
    "country": "Netherlands",
    "spotifyId": "0SfsnGyD8FpIN4U4WCkBZ5",
    "soundcloudUrl": "https://soundcloud.com/arminvanbuuren",
    "instagramUrl": "https://instagram.com/arminvanbuuren",
    "twitterUrl": "https://twitter.com/arminvanbuuren",
    "followerCount": 9200000
  }' > /dev/null

echo -e "${GREEN}✓ 创建 DJ: Armin van Buuren${NC}"

# DJ 4 - Tiësto
curl -s -X POST "$API_URL/djs" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{
    "name": "Tiësto",
    "slug": "tiesto",
    "bio": "荷兰DJ和音乐制作人，电子舞曲界的先驱人物。曾在2004年雅典奥运会开幕式上表演，代表作品包括《Red Lights》、《The Business》等。",
    "country": "Netherlands",
    "spotifyId": "2o5jDhtHVPhrJdv3cEQ99Z",
    "soundcloudUrl": "https://soundcloud.com/tiesto",
    "instagramUrl": "https://instagram.com/tiesto",
    "twitterUrl": "https://twitter.com/tiesto",
    "followerCount": 11500000
  }' > /dev/null

echo -e "${GREEN}✓ 创建 DJ: Tiësto${NC}"

# DJ 5 - Marshmello
curl -s -X POST "$API_URL/djs" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{
    "name": "Marshmello",
    "slug": "marshmello",
    "bio": "美国电子音乐制作人和DJ，以其标志性的棉花糖头盔而闻名。代表作品包括《Alone》、《Happier》等。",
    "country": "USA",
    "spotifyId": "64KEffDW9EtZ1y2vBYgq8T",
    "soundcloudUrl": "https://soundcloud.com/marshmellomusic",
    "instagramUrl": "https://instagram.com/marshmello",
    "twitterUrl": "https://twitter.com/marshmello",
    "followerCount": 15000000
  }' > /dev/null

echo -e "${GREEN}✓ 创建 DJ: Marshmello${NC}"

# DJ 6 - Calvin Harris
curl -s -X POST "$API_URL/djs" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{
    "name": "Calvin Harris",
    "slug": "calvin-harris",
    "bio": "苏格兰DJ、音乐制作人和词曲作者，多次获得格莱美奖和全英音乐奖。代表作品包括《Summer》、《Feel So Close》等。",
    "country": "UK",
    "spotifyId": "7CajNmpbOovFoOoasH2HaY",
    "soundcloudUrl": "https://soundcloud.com/calvinharris",
    "instagramUrl": "https://instagram.com/calvinharris",
    "twitterUrl": "https://twitter.com/CalvinHarris",
    "followerCount": 13500000
  }' > /dev/null

echo -e "${GREEN}✓ 创建 DJ: Calvin Harris${NC}"

# DJ 7 - Alan Walker
curl -s -X POST "$API_URL/djs" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{
    "name": "Alan Walker",
    "slug": "alan-walker",
    "bio": "挪威DJ和音乐制作人，以其标志性的面具和连帽衫形象而闻名。代表作品《Faded》在全球范围内大获成功。",
    "country": "Norway",
    "spotifyId": "7vk5e3vY1uw9plTHJAMwjN",
    "soundcloudUrl": "https://soundcloud.com/alanwalker",
    "instagramUrl": "https://instagram.com/alanwalkermusic",
    "twitterUrl": "https://twitter.com/IAmAlanWalker",
    "followerCount": 10500000
  }' > /dev/null

echo -e "${GREEN}✓ 创建 DJ: Alan Walker${NC}"

# DJ 8 - Kygo
curl -s -X POST "$API_URL/djs" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{
    "name": "Kygo",
    "slug": "kygo",
    "bio": "挪威DJ和音乐制作人，Tropical House风格的先驱。代表作品包括《Firestone》、《Stole the Show》等。",
    "country": "Norway",
    "spotifyId": "23fqKkggKUBHNkbKtXEls4",
    "soundcloudUrl": "https://soundcloud.com/kygo",
    "instagramUrl": "https://instagram.com/kygomusic",
    "twitterUrl": "https://twitter.com/KygoMusic",
    "followerCount": 9800000
  }' > /dev/null

echo -e "${GREEN}✓ 创建 DJ: Kygo${NC}"

echo ""
echo -e "${GREEN}✅ 测试数据创建完成！${NC}"
echo ""
echo "访问 http://localhost:3002/djs 查看 DJ 列表"
