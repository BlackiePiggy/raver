# Feature 04 - Messages Squads Notifications

## 1. 范围

包括：

- Messages Home
- Tencent IM bootstrap
- Conversation
- Custom cards
- Chat settings
- Squad profile
- Squad offline activity
- Notification Center
- Push route

## 2. iOS 来源

```text
Features/Messages/*
Infrastructure/TencentIM/*
Features/Squads/*
Features/Notifications/*
Core/ShareMessageRepository.swift
```

## 3. RN 目标目录

```text
features/messages/
features/squads/
features/notifications/
services/im/
services/push/
native/modules/TencentIM/
```

## 4. Tencent IM 分期

P0 不建议把完整 IM 放进首期。建议 P2 开始：

1. BFF bootstrap。
2. 会话列表。
3. 文本消息收发。
4. 图片消息。
5. 自定义业务卡片。
6. 群设置。
7. 消息搜索和本地缓存。

## 5. Squad

小队能力：

- Squad profile。
- 成员。
- 小队活动。
- 线下活动状态。
- 位置上传。

首期建议只做 read-only squad profile。线下协同和定位后置。

## 6. Notification Center

当前主线：

```text
/v1/notification-center
```

RN 需要：

- inbox。
- unread count。
- mark read。
- push token register。
- notification route target parse。

## 7. 路由

```text
MessagesHome
Conversation(target)
ChatSettings(conversationId)
SquadProfile(squadId)
SquadOfflineActivity(squadId)
NotificationsInbox
FollowedEventsInbox
FollowedDJsInbox
FollowedBrandsInbox
```

## 8. 验收

- notification inbox 可读并能跳转目标页面。
- unread count 和 tab badge 更新。
- IM 初始化失败不阻塞 App。
- conversation route 参数稳定。
- 权限拒绝时 push 设置有明确状态。

