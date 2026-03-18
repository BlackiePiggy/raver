# 多 Tracklist 功能测试指南

## 功能概述
现在支持同一个视频有多个用户上传不同的 tracklist，用户可以在播放页面通过弹窗选择使用哪个 tracklist。

## 核心特性
- ✅ 每个 tracklist 有独立的 UUID
- ✅ 支持通过 ID、用户名、Tracklist 名称快速搜索
- ✅ 显示上传者头像和昵称
- ✅ 美观的弹窗选择界面，符合页面主题
- ✅ 默认 Tracklist 始终可用

## 数据库变更
已创建新的数据表：
- `tracklists` - 存储 tracklist 元数据（ID、标题、上传者、创建时间等）
- `tracklist_tracks` - 存储 tracklist 中的歌曲

## 新增 API 端点

### 1. 获取视频的所有 tracklists
```
GET /api/dj-sets/:id/tracklists
```
返回该视频的所有 tracklist 列表（包含上传者信息和歌曲数量）

### 2. 获取特定 tracklist 的详细信息
```
GET /api/dj-sets/:setId/tracklists/:tracklistId
```
返回 tracklist 及其所有歌曲

### 3. 创建新的 tracklist
```
POST /api/dj-sets/:id/tracklists
Authorization: Bearer <token>
Content-Type: application/json

{
  "title": "我的版本",  // 可选
  "tracks": [
    {
      "position": 1,
      "startTime": 0,
      "endTime": 120,
      "title": "Song Title",
      "artist": "Artist Name",
      "status": "released"
    }
  ]
}
```

## 前端变更

### DJSetPlayer 组件
1. 添加了 Tracklist 选择按钮（显示当前使用的 tracklist）
2. 点击按钮弹出 TracklistSelectorModal
3. 添加了"上传我的 Tracklist"按钮（需要登录）
4. 切换 tracklist 时会动态加载对应的歌曲列表

### TracklistSelectorModal 组件（新建）
美观的弹窗选择界面，包含：
- 搜索框：支持搜索 ID、用户名、Tracklist 名称
- Tracklist 卡片：显示上传者头像、昵称、歌曲数量、上传时间、ID
- 默认 Tracklist 选项（带官方标签）
- 当前选中的 tracklist 会高亮显示
- 符合网站主题的渐变色和样式

### TracklistUploadModal 组件（新建）
上传模态框，支持：
- 批量粘贴歌单文本
- 自动解析时间戳和歌曲信息
- 可选的 tracklist 标题
- 显示解析结果预览

## UI 设计特点
- 🎨 使用网站主题色（紫色/蓝色渐变）
- 🔍 支持实时搜索过滤
- 👤 显示上传者头像和信息
- 🏷️ 每个 tracklist 显示完整 ID（前 8 位）
- ✨ 悬停效果和选中状态高亮
- 📱 响应式设计，适配移动端

## 测试步骤

### 1. 启动服务
```bash
# 启动后端
cd server
npm run dev

# 启动前端
cd web
npm run dev
```

### 2. 测试上传 tracklist
1. 登录账号
2. 打开任意 DJ Set 播放页面
3. 点击右上角"上传我的 Tracklist"按钮
4. 粘贴歌单文本，格式如下：
```
0:00 - Artist 1 - Song 1
1:30 - Artist 2 - Song 2
3:45 - Artist 3 - Song 3
```
5. 点击"解析歌单"查看解析结果
6. （可选）输入 Tracklist 标题
7. 点击"上传 Tracklist"

### 3. 测试选择 tracklist
1. 上传成功后，点击歌单标题下方的 Tracklist 选择按钮
2. 弹出选择窗口，显示所有可用的 tracklist
3. 可以使用搜索框搜索特定的 tracklist
4. 点击任意 tracklist 卡片进行切换
5. 歌曲列表会自动更新

### 4. 测试搜索功能
在选择窗口的搜索框中输入：
- Tracklist ID（完整或部分）
- 上传者用户名
- 上传者昵称
- Tracklist 标题

### 5. 测试多用户上传
1. 用不同账号登录
2. 对同一个视频上传不同的 tracklist
3. 验证所有用户的 tracklist 都能在选择窗口中显示
4. 验证每个 tracklist 显示正确的上传者信息

## 注意事项
- 原有的 `tracks` 表保持不变，作为默认 tracklist
- 新的 `tracklist_tracks` 表用于存储用户上传的 tracklist
- 每个 tracklist 都有独立的 UUID
- 每个 tracklist 都会显示上传者信息（头像、昵称）
- 用户可以为自己的 tracklist 添加标题
- 支持通过 ID、用户名、标题快速搜索
- 选择窗口采用卡片式布局，美观易用
