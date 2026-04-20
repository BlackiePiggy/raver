# 03. Discover 推荐

## iOS 来源

- `Features/Discover/Recommend/Views/RecommendEventsModuleView.swift`
- `Features/Discover/Recommend/ViewModels/RecommendEventsViewModel.swift`

## Flutter 目标路径

```text
lib/features/discover/recommend/
```

## 页面职责

- 展示推荐活动。
- 引导进入活动详情、DJ、Set 或搜索。
- 作为 Discover 首屏的内容承载。

## API

- `GET /v1/events/recommendations?limit=&statuses=`
- 可补充：热门 DJ、最新 Sets，首期可从对应列表接口取。

## UI 复刻

- 顶部推荐卡片横向滚动。
- 活动卡使用封面、名称、城市、时间、状态。
- 空状态展示“暂无推荐”。
- 首屏 skeleton 不要撑动布局。

## 状态模型

```text
RecommendState
  recommendedEvents
  featuredDjs
  latestSets
  loading
  error
```

## 实现步骤

1. 建 `RecommendRepository`，首期可代理 `DiscoverRepository`。
2. 建 `RecommendViewModel`。
3. 接推荐活动 API。
4. 复用 EventCard、DjAvatarRow、SetCard。
5. 卡片点击进入全局详情 route。
6. 下拉刷新重新请求。

## 测试

- 推荐活动可加载。
- 点击推荐活动进入 EventDetail。
- API 失败显示 retry。
- 无数据展示 empty state。

