#!/bin/bash

echo "🎵 DJ Set 功能演示"
echo "=================="
echo ""

# 颜色定义
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 获取Amelie Lens的ID
AMELIE_ID=$(curl -s http://localhost:3001/api/djs | jq -r '.djs[] | select(.name == "Amelie Lens") | .id')
CHARLOTTE_ID=$(curl -s http://localhost:3001/api/djs | jq -r '.djs[] | select(.name == "Charlotte de Witte") | .id')

echo -e "${GREEN}✅ 找到示例DJ:${NC}"
echo "   Amelie Lens ID: $AMELIE_ID"
echo "   Charlotte de Witte ID: $CHARLOTTE_ID"
echo ""

# 获取DJ Sets
echo -e "${BLUE}📺 获取DJ Sets...${NC}"
AMELIE_SET=$(curl -s "http://localhost:3001/api/dj-sets/dj/$AMELIE_ID" | jq -r '.[0].id')
CHARLOTTE_SET=$(curl -s "http://localhost:3001/api/dj-sets/dj/$CHARLOTTE_ID" | jq -r '.[0].id')

echo "   Amelie Lens Set ID: $AMELIE_SET"
echo "   Charlotte de Witte Set ID: $CHARLOTTE_SET"
echo ""

echo -e "${YELLOW}🌐 访问以下链接查看DJ Sets:${NC}"
echo ""
echo "1️⃣  Amelie Lens 的所有Sets:"
echo "   http://localhost:3000/djs/$AMELIE_ID/sets"
echo ""
echo "2️⃣  Amelie Lens - Boiler Room Berlin (视频播放器):"
echo "   http://localhost:3000/dj-sets/$AMELIE_SET"
echo ""
echo "3️⃣  Charlotte de Witte 的所有Sets:"
echo "   http://localhost:3000/djs/$CHARLOTTE_ID/sets"
echo ""
echo "4️⃣  Charlotte de Witte - Tomorrowland 2023 (视频播放器):"
echo "   http://localhost:3000/dj-sets/$CHARLOTTE_SET"
echo ""
echo "5️⃣  上传新的DJ Set:"
echo "   http://localhost:3000/upload"
echo ""

echo -e "${GREEN}💡 提示:${NC}"
echo "   - 在DJ详情页点击 '🎵 查看DJ Sets' 按钮"
echo "   - 在视频播放器页面点击歌曲可跳转到对应时间"
echo "   - 示例视频使用占位ID，上传真实YouTube URL获得最佳体验"
echo ""

echo -e "${BLUE}🔄 同步DJ头像 (需要Spotify API):${NC}"
echo "   cd server && pnpm ts-node prisma/sync-all-djs.ts"
echo ""