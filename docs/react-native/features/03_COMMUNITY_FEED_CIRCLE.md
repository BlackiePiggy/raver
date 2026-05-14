# Feature 03 - Community Feed Circle

## 1. 范围

包括：

- Circle Tab
- Feed stream
- PostCard
- Post Detail
- Comments
- Compose Post
- Like / Save / Share / Hide
- Feed event tracking

## 2. iOS 来源

```text
Features/Circle/Coordinator/CircleCoordinator.swift
Features/Feed/FeedView.swift
Features/Feed/FeedViewModel.swift
Features/Feed/PostDetailView.swift
Features/Feed/ComposePostView.swift
Shared/PostCardView.swift
Application/DI/AppContainer.swift 中 feed/post/comment repositories
```

## 3. RN 目标目录

```text
features/circle/
features/feed/
features/comments/
shared/components/PostCard.tsx
services/media/
```

## 4. 状态与 Query

```text
['feed', 'home', params]
['posts', 'detail', postId]
['comments', 'post', postId, params]
['post', postId, 'interaction']
```

本地 store：

```text
composeDraftStore
feedFilterStore
```

## 5. API

当前后端已有 feed module：

```text
server/src/modules/feed/
server/src/routes/comment.routes.ts
```

RN repository：

```text
feedRepository
postRepository
commentRepository
postInteractionRepository
mediaUploadRepository
```

## 6. 复现步骤

1. 先实现 `PostCard`，对齐 iOS 信息层级。
2. Feed 列表使用 FlashList。
3. Post Detail 加载帖子 + 评论。
4. 点赞/收藏使用 optimistic update。
5. 评论提交成功后插入评论或 invalidate。
6. Compose Post 使用 draft store 和 media upload service。
7. 分享入口接入 share service。
8. hide/report 先做 API 和 UI 状态，运营后台闭环后再增强。

## 7. 首期取舍

首期必须：

- Feed。
- Post detail。
- Comment list。
- Like/save/comment。
- Compose text + images。

后置：

- Video post。
- Complex topic/community taxonomy。
- Advanced moderation UI。
- Offline post queue。

## 8. 验收

- Feed 刷新/分页正常。
- PostCard 在 Discover/Profile/Search 也可复用。
- 评论分页和提交稳定。
- optimistic update 失败能回滚。
- 发帖失败保留草稿。

