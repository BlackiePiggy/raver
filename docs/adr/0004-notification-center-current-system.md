# ADR-0004 Notification Center As Current Notification System

## Status

Accepted

## Context

Raver 通知能力包括站内 inbox、APNs、设备 token、通知模板、通知订阅、定时提醒和投递状态。仓库中同时存在旧通知路由和新的 notification-center 服务。

当前更完整的通知主线位于：

```text
server/src/services/notification-center/
server/src/routes/notification-center.routes.ts
```

## Decision

Notification Center 是当前通知系统主线。

旧 notification 能力作为兼容路径处理，后续逐步收束到 notification-center module。

## Consequences

- 新通知能力进入 notification-center。
- APNs、Inbox、Delivery、Template、Subscription 应归入 notifications module。
- 旧 `/api/notifications` 路径需要保留兼容，但不再扩展新复杂能力。

## Migration Notes

- Phase 1 将 notification-center 作为后端模块化试点。
- Worker 和 scheduler 继续可运行。
- 后续 Admin Console 应接入 notification-center 的配置、投递和模板能力。
