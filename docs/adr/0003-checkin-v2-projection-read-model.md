# ADR-0003 Check-in v2 Projection Read Model

## Status

Accepted

## Context

Raver 的 Check-in 已经从简单打卡演进为用户身份沉淀、活动/DJ 集邮、Timeline、Gallery、Stats 和派生信号系统。

当前 MyCheckins v2 已经采用 projection read model：

- 写模型：`Checkin`、`CheckinSelection`、`CheckinSelectionDJ`
- 快照：`CheckinSnapshot`
- 读模型：`UserCheckinTimelineEntry`、`UserCheckinStat`、`UserCheckinGalleryDJAggregate`、`UserCheckinGalleryEventAggregate`
- 异步事件：`CheckinOutboxEvent`

## Decision

Check-in v2 projection read model 是当前打卡系统主线。

App 查询应优先读取 projection tables，而不是直接从写模型临时聚合。

## Consequences

- Check-in 读性能由 projection 保证。
- Projection 缺失或不新鲜时，应通过 worker、reproject、snapshot rebuild 修复。
- 数据库改造、reproject apply、snapshot rebuild 前必须先备份数据。
- Check-in v1 路径逐步标记为 legacy。

## Migration Notes

- Phase 2 中迁移 `checkins` module。
- 保留并强化 `checkins:projection:freshness`、`checkins:projection:run`、`checkins:reproject:*`。
- 所有数据修复动作必须记录到 tracker 的数据库备份记录。
