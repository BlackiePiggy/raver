# DJ Set 视频展示系统

## 功能概述

这个系统解决了两个核心问题：

### 1. DJ信息自动聚合
不需要手动维护所有DJ信息，系统可以从多个平台自动获取和同步：
- **Spotify** - 艺术家照片、简介、粉丝数
- **Discogs** - 详细的艺术家资料和作品信息
- **支持批量同步** - 一次性更新多个DJ的信息

### 2. 交互式DJ Set视频播放器
展示DJ的现场表演视频，配合完整的歌单：
- **视频嵌入** - 支持YouTube和Bilibili
- **时间轴歌单** - 每首歌的开始/结束时间
- **点击跳转** - 点击歌曲直接跳转到视频对应位置
- **歌曲状态标记**：
  - 🎵 已发行 - 可以在流媒体找到
  - 🆔 ID/未发行 - 还没发布的歌曲
  - 🎹 Remix - 混音版本
  - ✂️ Edit - 编辑版本
- **流媒体链接** - 自动搜索并链接到Spotify、Apple Music等平台
- **精美UI** - 现代化的深色主题设计

## 技术架构

### 后端 (Node.js + Express + Prisma)
```
server/
├── src/
│   ├── services/
│   │   ├── dj-aggregator.service.ts    # DJ数据聚合服务
│   │   └── djset.service.ts            # DJ Set管理服务
│   └── routes/
│       ├── dj-aggregator.routes.ts     # DJ聚合API
│       └── djset.routes.ts             # DJ Set API
└── prisma/
    ├── schema.prisma                   # 数据库模型
    └── seed-djsets.ts                  # 示例数据
```

### 前端 (Next.js + React + TypeScript)
```
web/
├── src/
│   ├── components/
│   │   ├── DJSetPlayer.tsx             # 视频播放器组件
│   │   └── DJSetUploader.tsx           # 上传管理界面
│   ├── app/
│   │   ├── dj-sets/[id]/page.tsx       # DJ Set播放页面
│   │   ├── djs/[djId]/sets/page.tsx    # DJ的所有Sets
│   │   └── upload/page.tsx             # 上传页面
│   └── lib/
│       └── api.ts                      # API客户端
```

## 数据库模型

### DJSet (DJ表演视频)
- 视频URL和平台信息
- 关联的DJ
- 表演地点、活动名称
- 浏览量、点赞数

### Track (歌单曲目)
- 在Set中的位置
- 开始/结束时间戳
- 歌曲信息（标题、艺术家）
- 状态（已发行/ID/Remix/Edit）
- 流媒体平台链接

## 快速开始

### 1. 配置环境变量

`server/.env`:
```env
DATABASE_URL=postgresql://user:password@localhost:5432/raver_dev
SPOTIFY_CLIENT_ID=your_client_id
SPOTIFY_CLIENT_SECRET=your_client_secret
DISCOGS_TOKEN=your_token  # 可选
```

`web/.env.local`:
```env
NEXT_PUBLIC_API_URL=http://localhost:3001/api
```

### 2. 安装依赖和运行迁移

```bash
# 后端
cd server
pnpm install
pnpm prisma migrate dev
pnpm prisma generate

# 前端
cd ../web
pnpm install
```

### 3. 启动服务

```bash
# 后端 (终端1)
cd server
pnpm dev

# 前端 (终端2)
cd web
pnpm dev
```

### 4. 创建示例数据

```bash
cd server
pnpm ts-node prisma/seed-djsets.ts
```

## 使用示例

### 同步DJ信息

```bash
# 搜索DJ数据
curl http://localhost:3001/api/dj-aggregator/search/Amelie%20Lens

# 同步单个DJ
curl -X POST http://localhost:3001/api/dj-aggregator/sync/{djId}

# 批量同步
curl -X POST http://localhost:3001/api/dj-aggregator/batch-sync \
  -H "Content-Type: application/json" \
  -d '{"djIds": ["id1", "id2", "id3"]}'
```

### 创建DJ Set

```bash
curl -X POST http://localhost:3001/api/dj-sets \
  -H "Content-Type: application/json" \
  -d '{
    "djId": "dj-uuid",
    "title": "Boiler Room Berlin 2024",
    "videoUrl": "https://www.youtube.com/watch?v=xxxxx",
    "description": "Amazing techno set",
    "venue": "Berghain"
  }'
```

### 添加歌单

```bash
curl -X POST http://localhost:3001/api/dj-sets/{setId}/tracks/batch \
  -H "Content-Type: application/json" \
  -d '{
    "tracks": [
      {
        "position": 1,
        "startTime": 0,
        "endTime": 300,
        "title": "Track Name",
        "artist": "Artist Name",
        "status": "released"
      },
      {
        "position": 2,
        "startTime": 300,
        "title": "Unreleased ID",
        "artist": "Unknown",
        "status": "id"
      }
    ]
  }'
```

### 自动链接流媒体

```bash
# 自动搜索并添加Spotify等平台链接
curl -X POST http://localhost:3001/api/dj-sets/{setId}/auto-link
```

## 页面访问

- **播放页面**: `http://localhost:3000/dj-sets/{setId}`
- **DJ的所有Sets**: `http://localhost:3000/djs/{djId}/sets`
- **上传管理**: `http://localhost:3000/upload`

## 核心特性

### 视频播放器
- YouTube IFrame API集成
- Bilibili播放器支持
- 实时时间同步
- 当前播放曲目高亮

### 交互式歌单
- 点击歌曲跳转到对应时间
- 歌曲状态图标显示
- 流媒体平台快速链接
- 响应式设计（移动端友好）

### 数据聚合
- 多平台API集成
- 自动数据同步
- 批量处理支持
- 速率限制保护

## API文档

详细的API文档请查看 `DJSET_SETUP.md`

## 下一步优化建议

1. **添加搜索功能** - 搜索DJ Sets和曲目
2. **用户收藏** - 收藏喜欢的Sets和曲目
3. **评论系统** - 用户可以评论Sets
4. **推荐算法** - 基于用户喜好推荐Sets
5. **移动端优化** - 改进移动端播放体验
6. **缓存优化** - 减少API调用次数
7. **CDN集成** - 加速视频加载

## 技术栈

- **后端**: Node.js, Express, Prisma, PostgreSQL
- **前端**: Next.js 15, React 18, TypeScript, Tailwind CSS
- **API集成**: Spotify API, Discogs API, YouTube IFrame API
- **数据库**: PostgreSQL with Prisma ORM