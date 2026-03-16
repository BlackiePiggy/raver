#!/bin/bash

# DJ Set 功能快速测试脚本

echo "🎵 DJ Set 功能测试"
echo "===================="
echo ""

API_URL="http://localhost:3001/api"

# 测试1: 搜索DJ信息
echo "1️⃣ 测试搜索DJ信息..."
curl -s "$API_URL/dj-aggregator/search/Amelie%20Lens" | jq '.' || echo "❌ 失败"
echo ""

# 测试2: 获取DJ列表
echo "2️⃣ 获取DJ列表..."
DJ_ID=$(curl -s "$API_URL/djs" | jq -r '.djs[0].id')
echo "找到DJ ID: $DJ_ID"
echo ""

# 测试3: 同步DJ信息
if [ ! -z "$DJ_ID" ]; then
  echo "3️⃣ 同步DJ信息..."
  curl -s -X POST "$API_URL/dj-aggregator/sync/$DJ_ID" | jq '.' || echo "❌ 失败"
  echo ""
fi

# 测试4: 创建DJ Set
echo "4️⃣ 创建DJ Set..."
if [ ! -z "$DJ_ID" ]; then
  SET_RESPONSE=$(curl -s -X POST "$API_URL/dj-sets" \
    -H "Content-Type: application/json" \
    -d "{
      \"djId\": \"$DJ_ID\",
      \"title\": \"Test Set - Boiler Room\",
      \"videoUrl\": \"https://www.youtube.com/watch?v=dQw4w9WgXcQ\",
      \"description\": \"测试DJ Set\",
      \"venue\": \"Berghain\"
    }")

  echo "$SET_RESPONSE" | jq '.'
  SET_ID=$(echo "$SET_RESPONSE" | jq -r '.id')
  echo "创建的Set ID: $SET_ID"
  echo ""
fi

# 测试5: 添加歌单
if [ ! -z "$SET_ID" ]; then
  echo "5️⃣ 添加歌单..."
  curl -s -X POST "$API_URL/dj-sets/$SET_ID/tracks/batch" \
    -H "Content-Type: application/json" \
    -d '{
      "tracks": [
        {
          "position": 1,
          "startTime": 0,
          "endTime": 300,
          "title": "Exhale",
          "artist": "Amelie Lens",
          "status": "released"
        },
        {
          "position": 2,
          "startTime": 300,
          "endTime": 600,
          "title": "Unreleased ID",
          "artist": "Unknown",
          "status": "id"
        }
      ]
    }' | jq '.'
  echo ""
fi

# 测试6: 获取DJ Set详情
if [ ! -z "$SET_ID" ]; then
  echo "6️⃣ 获取DJ Set详情..."
  curl -s "$API_URL/dj-sets/$SET_ID" | jq '.'
  echo ""
fi

echo "✅ 测试完成！"
echo ""
echo "📝 访问以下页面查看效果："
echo "   - DJ Set播放器: http://localhost:3000/dj-sets/$SET_ID"
echo "   - 上传管理: http://localhost:3000/upload"