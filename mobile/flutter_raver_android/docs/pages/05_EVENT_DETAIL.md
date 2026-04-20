# 05. 活动详情

## iOS 来源

- `Features/Discover/Events/Views/EventDetailView.swift`
- `Features/Discover/EventDetailRepresentable.swift`
- `Features/Discover/EventDetailScrollViewController.swift`
- `Features/Discover/EventDetailTabBarView.swift`

## Flutter 目标路径

```text
lib/features/discover/events/detail/
```

## 页面职责

- 展示活动 hero、基础信息、地点、时间、票档。
- 展示阵容、时间表、打卡、关联 Sets、关联评分。
- 收藏/打卡。
- 地图、路线、分享、日历。

## 路由

```text
/events/:eventId
```

route meta：

```text
hideBottomBar: true
presentation: push
navigationChrome: immersiveFloating
```

## API

- `GET /v1/events/:id`
- `GET /v1/events/:id/rating-events`
- `GET /v1/dj-sets?eventName=`
- `GET /v1/checkins?eventID=`
- `POST /v1/checkins`
- `PATCH /v1/checkins/:id`
- `DELETE /v1/checkins/:id`

## UI 复刻

- `CustomScrollView` + hero section。
- 左上悬浮圆形返回。
- 详情内容 tab：介绍 / 阵容 / 时间表 / 打卡 / Sets。
- tab header pinned。
- hero 图片滚动折叠时保留标题可读。
- 地图入口使用 Android 外部地图 intent。

## 状态模型

```text
EventDetailState
  event
  selectedTab
  lineupByDay
  relatedSets
  ratingEvents
  checkins
  markedCheckinId
  loading
  error
```

## 实现步骤

1. 建 EventDetail loader，只收 eventId。
2. 首屏请求 event。
3. 次级内容懒加载。
4. 建 `EventHeroSliver`。
5. 建 pinned tab header。
6. 实现收藏/打卡乐观更新。
7. 接地图、日历、分享外部动作。

## 测试

- deep link 直接进入详情。
- hero 图片失败态。
- tab 切换保留滚动。
- back 回到来源页。
- 收藏/打卡失败回滚。

