# 11. Set 详情、播放器与 Tracklist

## iOS 来源

- `Features/Discover/Sets/Views/SetsModuleView.swift` 中 `DJSetDetailView`
- `Vendor/KSPlayerLite`

## Flutter 目标路径

```text
lib/features/discover/sets/detail/
lib/features/media/player/
```

## 页面职责

- 展示 Set 详情。
- 播放视频/音频。
- 展示 Tracklist。
- 评论。
- 自动关联 tracks。

## 路由

```text
/sets/:setId
/sets/:setId/tracklists/:tracklistId
```

route meta：

```text
hideBottomBar: true
navigationChrome: immersiveFloating
```

## API

- `GET /v1/dj-sets/:id`
- `GET /v1/dj-sets/:id/tracklists`
- `GET /v1/dj-sets/:setId/tracklists/:tracklistId`
- `POST /v1/dj-sets/:id/auto-link`
- `GET /v1/dj-sets/:id/comments`
- `POST /v1/dj-sets/:id/comments`
- `PATCH /v1/comments/:id`
- `DELETE /v1/comments/:id`

## UI 复刻

- 顶部媒体区域固定比例。
- 播放器点击进入 fullscreen。
- tracklist 以时间轴方式展示。
- 评论区复用 Post comment 样式。
- DJ/贡献者点击进入 User/DJ 详情。

## 状态模型

```text
SetDetailState
  set
  tracklists
  selectedTracklist
  comments
  playerState
  loading
  error
```

## 实现步骤

1. loader 按 setId 拉取详情。
2. 如果有 videoURL，初始化播放器但不自动播放。
3. 懒加载 tracklists 和 comments。
4. fullscreen player 控制横屏。
5. 评论提交后局部刷新。
6. 点击 track 进入外链音乐平台。

## 测试

- 无视频时显示封面。
- fullscreen back 只退出 fullscreen。
- tracklist 加载失败可重试。
- 评论新增成功。

