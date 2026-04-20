# 04. 活动列表与收藏活动

## iOS 来源

- `Features/Discover/Events/Views/EventsModuleView.swift`
- `Features/Discover/Events/ViewModels/EventsModuleViewModel.swift`
- `Features/Discover/Events/Views/EventPresentationSupport.swift`

## Flutter 目标路径

```text
lib/features/discover/events/
```

## 页面职责

- 全部活动列表。
- 收藏/标记活动列表。
- 搜索、状态、类型筛选。
- 分页和下拉刷新。
- 点击进入活动详情。

## 路由

```text
/app/discover/events
/events/:eventId
```

## API

- `GET /v1/events?page=&limit=&search=&eventType=&status=`
- `GET /v1/checkins?type=event`
- `POST /v1/checkins`
- `DELETE /v1/checkins/:id`

## UI 复刻

- 顶部二级 tab：全部活动 / 收藏活动。
- 筛选条使用 chips 或 segmented controls。
- 活动卡固定封面比例，避免滚动跳动。
- 收藏按钮支持乐观更新。
- 分页到底部自动加载。

## 状态模型

```text
EventsListState
  query
  eventType
  status
  items
  page
  totalPages
  markedCheckinIdsByEventId
  loading
  loadingMore
  error
```

## 实现步骤

1. 建 `EventsRepository`。
2. 建 `EventsListViewModel`。
3. 实现全部列表分页。
4. 拉取 checkins 生成收藏 map。
5. 实现 toggle marked event。
6. 补筛选和搜索。
7. 列表卡点击全局 route。

## 测试

- 首屏、分页、刷新。
- 收藏/取消收藏。
- 筛选变化重置分页。
- 收藏列表只显示已收藏活动。

