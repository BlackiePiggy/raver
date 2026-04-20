# 16. 动态 Feed、详情与发帖

## iOS 来源

- `Features/Feed/FeedView.swift`
- `Features/Feed/FeedViewModel.swift`
- `Features/Feed/PostDetailView.swift`
- `Features/Feed/ComposePostView.swift`
- `Shared/PostCardView.swift`

## Flutter 目标路径

```text
lib/features/circle/feed/
```

## 页面职责

- 动态列表。
- 动态详情。
- 评论、点赞、转发。
- 发布/编辑动态。
- 绑定 DJ、厂牌、活动。

## 路由

```text
/app/circle/feed
/posts/:postId
/posts/new
/posts/:postId/edit
```

## API

- `GET /v1/feed`
- `GET /v1/feed/search?q=`
- `GET /v1/feed/posts/:id`
- `POST /v1/feed/posts`
- `PATCH /v1/feed/posts/:id`
- `DELETE /v1/feed/posts/:id`
- `POST /v1/feed/posts/:id/like`
- `DELETE /v1/feed/posts/:id/like`
- `POST /v1/feed/posts/:id/repost`
- `DELETE /v1/feed/posts/:id/repost`
- `GET /v1/feed/posts/:id/comments`
- `POST /v1/feed/posts/:id/comments`
- `POST /v1/feed/upload-image`
- `POST /v1/feed/upload-video`

## UI 复刻

- PostCard 展示作者、内容、图片、绑定对象、互动区。
- 图片九宫格稳定尺寸。
- 详情页系统导航。
- 发帖页支持图片/视频选择、位置、绑定对象。

## 状态模型

```text
FeedState
  posts
  nextCursor
  loading
  loadingMore
  error

ComposePostState
  content
  selectedMedia
  location
  boundDjs
  boundBrands
  boundEvents
  uploading
  submitting
```

## 实现步骤

1. 建 FeedRepository。
2. 列表 cursor 分页。
3. PostCard 所有跳转走全局 route。
4. 点赞/转发乐观更新。
5. 发帖先上传媒体，再提交 post。
6. 详情页评论独立加载。

## 测试

- feed 分页。
- 点赞失败回滚。
- 发帖上传失败重试。
- 评论成功后数量更新。

