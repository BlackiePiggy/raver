# DJ Set 功能使用指南

## 🎯 功能位置

### 1. 查看DJ的所有Sets
在任何DJ详情页面，点击 **"🎵 查看DJ Sets"** 按钮

**路径**: DJ列表 → 选择DJ → 点击"查看DJ Sets"按钮

**URL**: `http://localhost:3000/djs/{djId}/sets`

### 2. 观看DJ Set视频和歌单
在DJ Sets列表页面，点击任意Set卡片

**功能**:
- 🎥 YouTube/Bilibili视频播放
- 🎵 交互式歌单（点击跳转到对应时间）
- 🔗 流媒体平台链接（Spotify、Apple Music等）
- 🏷️ 歌曲状态标记（已发行/ID/Remix/Edit）

**URL**: `http://localhost:3000/dj-sets/{setId}`

### 3. 上传新的DJ Set
访问上传页面

**URL**: `http://localhost:3000/upload`

## 📊 当前数据状态

已创建示例数据：
- ✅ Amelie Lens - Boiler Room Berlin (4首歌)
- ✅ Charlotte de Witte - Tomorrowland 2023 (3首歌)

## 🔄 同步DJ头像和信息

### 方法1: 使用API同步单个DJ
```bash
# 获取DJ ID
curl http://localhost:3001/api/djs | jq '.djs[] | {id, name}'

# 同步DJ信息（会从Spotify获取头像）
curl -X POST http://localhost:3001/api/dj-aggregator/sync/{DJ_ID}
```

### 方法2: 批量同步所有DJ
```bash
cd server
pnpm ts-node prisma/sync-all-djs.ts
```

**注意**: 需要在 `server/.env` 中配置Spotify API密钥：
```env
SPOTIFY_CLIENT_ID=your_client_id
SPOTIFY_CLIENT_SECRET=your_client_secret
```

## 🎬 完整使用流程

### 查看现有DJ Sets

1. 访问 `http://localhost:3000/djs`
2. 找到 "Amelie Lens" 或 "Charlotte de Witte"
3. 点击进入DJ详情页
4. 点击 **"🎵 查看DJ Sets"** 按钮
5. 在Sets列表中点击任意Set
6. 享受交互式视频播放体验！

### 上传新的DJ Set

1. 访问 `http://localhost:3000/upload`
2. 填写基本信息：
   - DJ ID（从DJ列表获取）
   - Set标题
   - 视频URL（YouTube或Bilibili）
   - 描述（可选）
3. 添加歌单：
   - 点击"添加歌曲"
   - 填写开始时间（格式: mm:ss）
   - 填写歌曲名和艺术家
   - 选择状态（已发行/ID/Remix/Edit）
4. 点击"创建 DJ Set"
5. 系统会自动搜索并链接流媒体平台

## 🎨 界面特点

### DJ Sets列表页
- 卡片式布局
- 显示场地和活动名称
- 显示歌曲数量
- 悬停放大效果

### 视频播放器页面
- 左侧：视频播放器
- 右侧：可滚动歌单
- 当前播放歌曲高亮显示
- 点击歌曲跳转到对应时间
- 流媒体平台快速链接

### 歌曲状态图标
- 🎵 已发行 - 可在流媒体找到
- 🆔 ID - 未发行曲目
- 🎹 Remix - 混音版本
- ✂️ Edit - 编辑版本

## 🔧 故障排除

### 问题1: DJ没有头像
**解决方案**: 运行同步脚本
```bash
cd server
pnpm ts-node prisma/sync-all-djs.ts
```

### 问题2: 找不到DJ Sets
**解决方案**: 确保已运行种子脚本
```bash
cd server
pnpm ts-node prisma/seed-djsets.ts
```

### 问题3: 视频无法播放
**原因**: 示例数据使用的是占位视频ID
**解决方案**: 上传真实的YouTube视频URL

### 问题4: 流媒体链接不显示
**原因**: 需要配置Spotify API并运行auto-link
**解决方案**:
```bash
# 配置.env后，运行
curl -X POST http://localhost:3001/api/dj-sets/{setId}/auto-link
```

## 📱 移动端体验

所有页面都是响应式设计：
- 手机端：视频和歌单垂直排列
- 平板/桌面：视频和歌单并排显示

## 🚀 下一步

1. 配置Spotify API密钥获取DJ头像
2. 上传真实的DJ Set视频
3. 邀请用户上传更多内容
4. 添加搜索和筛选功能

## 💡 提示

- 使用真实的YouTube视频URL可以获得最佳体验
- 歌单时间格式支持 mm:ss 或 hh:mm:ss
- 建议每个Set至少添加3-5首歌
- 可以在上传后使用auto-link自动添加流媒体链接