# 10. Sets 列表

## iOS 来源

- `Features/Discover/Sets/Views/SetsModuleView.swift`

## Flutter 目标路径

```text
lib/features/discover/sets/list/
```

## 页面职责

- 展示 DJ Sets 列表。
- 支持排序、搜索、DJ 过滤。
- 进入 Set 详情。
- 入口到上传 Set。

## 路由

```text
/app/discover/sets
/sets/:setId
/sets/new
```

## API

- `GET /v1/dj-sets?page=&limit=&sortBy=&djID=`
- `GET /v1/dj-sets/mine`

## UI 复刻

- 网格/列表卡片按 iOS 当前 Sets 模块。
- 卡片展示缩略图、标题、DJ、活动、时长、播放/评论数据。
- 视频标识明确。
- 分页加载更多。

## 状态模型

```text
SetsListState
  sortBy
  search
  items
  page
  totalPages
  loading
  loadingMore
  error
```

## 实现步骤

1. 建 `SetsRepository`。
2. 建 `SetsListViewModel`。
3. 接分页接口。
4. 卡片复用 `RaverRemoteImage`。
5. 点击进入 `/sets/:id`。
6. 我的发布入口复用 `/dj-sets/mine`。

## 测试

- 列表分页。
- 缩略图失败态。
- 点击进入详情。
- 排序切换重载。

