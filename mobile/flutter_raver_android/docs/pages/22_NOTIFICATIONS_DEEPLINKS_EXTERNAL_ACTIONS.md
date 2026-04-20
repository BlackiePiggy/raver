# 22. 通知、Deep Link 与外部动作

## iOS 来源

- `Features/Notifications/NotificationsView.swift`
- `Features/Notifications/NotificationsViewModel.swift`
- `Application/Coordinator/MainTabCoordinator.swift`
- 详情页地图、分享、日历入口

## Flutter 目标路径

```text
lib/features/notifications/
lib/core/platform/deep_links/
lib/core/platform/external_actions/
```

## 页面职责

- 通知列表。
- 未读数。
- 标记已读。
- 点击通知进入目标详情。
- Android 外部动作：地图、分享、浏览器、日历。

## 路由

```text
/notifications
raver://events/:id
raver://djs/:id
raver://sets/:id
raver://posts/:id
raver://users/:id
```

## API

- `GET /v1/notifications?limit=`
- `GET /v1/notifications/unread-count`
- `POST /v1/notifications/read`

## UI 复刻

- 通知卡展示类型、内容、时间、是否已读。
- 未读 badge 与 messages/profile 入口联动。
- 通知详情通常不单独存在，点击进入业务详情。

## 外部动作

统一封装：

```text
ExternalActions.openMap
ExternalActions.share
ExternalActions.openUrl
ExternalActions.addToCalendar
```

不要在页面里直接散落 `url_launcher`。

## 状态模型

```text
NotificationsState
  items
  unreadCount
  loading
  error
```

## 实现步骤

1. 建 NotificationsRepository。
2. App active 时刷新 unread count。
3. 通知列表拉取并展示。
4. 点击通知先 mark read，再根据 payload 路由。
5. 建 deep link parser。
6. 接 Android intent filter。

## 测试

- 未读数刷新。
- 点击通知进入正确详情。
- deep link 冷启动。
- 地图/分享/浏览器 intent 真机验证。

