# Notifications Module

Status: Phase 1 pilot target.

This module is the target home for Notification Center domain code.

Current source locations remain active:

```text
server/src/routes/notification-center.routes.ts
server/src/routes/notification.routes.ts
server/src/services/notification-center/
server/src/services/notification.service.ts
server/src/scripts/notification-*.ts
```

Target ownership:

- Notification inbox
- Unread count
- Device push tokens
- Notification subscriptions and preferences
- Notification events
- Notification delivery records
- Notification templates
- APNs delivery integration via infrastructure adapter
- Notification schedulers and outbox worker orchestration

Core models:

- `NotificationEvent`
- `NotificationInboxItem`
- `NotificationDelivery`
- `DevicePushToken`
- `NotificationSubscription`
- `NotificationTemplate`
- `NotificationAdminConfig`

Migration rule:

The existing `notification-center.routes.ts` remains the public entrypoint until behavior is covered by tests or smoke checks. During migration, old routes should call this module's service instead of duplicating business logic.

Current facade:

```text
server/src/modules/notifications/index.ts
```

The facade currently re-exports the existing Notification Center implementation. This keeps runtime behavior unchanged while giving routes, app bootstrap, and future jobs a stable module import path.
