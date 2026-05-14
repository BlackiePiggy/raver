# Raver Legacy And Current Mainline Inventory

> Status: Active  
> Owner: Architecture  
> Last Updated: 2026-05-12  
> Applies To: `server/`、`mobile/ios/RaverMVP/`、`web/`、`docs/`  
> Purpose: 明确当前主线、历史兼容、迁移中路线和后续处理策略，避免架构改造中路线混淆。

## 1. 判定规则

| 状态 | 含义 | 处理方式 |
| --- | --- | --- |
| Current | 当前主线，新能力应进入这里 | 继续维护和演进 |
| Compat | 兼容路径，仍可能被旧客户端或旧页面调用 | 保留入口，内部逐步代理到 Current |
| Migration | 迁移中，正在从旧方案切到新方案 | 冻结新增能力，只做迁移和验证 |
| Legacy | 历史路线，不再扩展新能力 | 标记、隔离、保留必要文档 |
| Archive | 归档内容，不参与当前运行 | 移入 archived 或仅作参考 |

## 2. 当前主线总表

| 领域 | 当前主线 | 历史 / 兼容路线 | 处理策略 |
| --- | --- | --- | --- |
| 产品客户端 | iOS Native App | Web-first、React Native 旧口径 | README 和 ADR 已修正，Web 定位为 Admin/CMS/fallback |
| IM | Tencent IM | OpenIM 相关方案 | Tencent 为 Current，OpenIM 标记为 Legacy/Migration |
| 通知 | Notification Center + APNs | 旧 `/api/notifications` | notification-center 为 Current，旧通知 Compat |
| Check-in | Check-in v2 projection read model | Check-in v1 查询路径 | v2 为 Current，v1 Compat/Legacy |
| 后端架构 | Modular monolith | routes/services/scripts 横向平铺 | 逐步迁移到 `server/src/modules` |
| Web | Admin / CMS / Public fallback | Web 主产品入口 | Web-first 口径 Legacy |
| 数据库 | 领域分组 + owner + repository 边界 | 所有模型平铺、任意 service 直连 | 先分组和建 owner，不急着改表名 |

## 3. IM 路线

### Current

Tencent IM。

相关路径：

```text
server/src/routes/tencent-im.routes.ts
server/src/modules/im/
server/src/services/tencent-im/
mobile/ios/RaverMVP/RaverMVP/Infrastructure/TencentIM/
mobile/ios/RaverMVP/RaverMVP/Features/Messages/
```

当前能力：

- IM bootstrap
- usersig 生成
- Raver user 与 IM user 映射
- Squad 与 IM group 同步
- 会话列表、消息渲染、自定义卡片

### Legacy / Migration

OpenIM。

相关路径：

```text
server/src/services/openim/
server/src/services/openim/README.md
mobile/ios/RaverMVP/RaverMVP/Infrastructure/LegacyOpenIM/
thirdparty/openimApp/
docs/OPENIM_*.md
docs/reports/openim-*
```

处理策略：

- 不再为 OpenIM 扩展新业务能力。
- 保留迁移、排障和历史参考价值。
- Phase 4 已在 `server/src/services/openim/README.md` 和 `mobile/ios/RaverMVP/RaverMVP/Infrastructure/LegacyOpenIM/README.md` 标记 legacy / migration；后续只整理 OpenIM 文档索引和第三方目录，不扩展新能力。

## 4. 通知路线

### Current

Notification Center + APNs。

相关路径：

```text
server/src/routes/notification-center.routes.ts
server/src/services/notification-center/
server/src/scripts/notification-*.ts
mobile/ios/RaverMVP/RaverMVP/Features/Notifications/
mobile/ios/RaverMVP/RaverNotificationService/
```

当前能力：

- inbox
- unread count
- device push token
- notification event / delivery
- APNs handler
- event countdown
- daily digest
- route DJ reminder
- followed DJ / brand update
- admin config / templates

### Compat

旧通知接口：

```text
server/src/routes/notification.routes.ts
server/src/controllers/notification.controller.ts
server/src/services/notification.service.ts
```

处理策略：

- 保留兼容入口。
- 新能力进入 notification-center。
- Phase 1 优先以 notification-center 作为后端模块化试点。

## 5. Check-in 路线

### Current

Check-in v2 projection read model。

相关路径：

```text
server/src/routes/checkins-v2.routes.ts
server/src/services/checkin-domain.ts
server/src/services/checkin-projection.ts
server/src/services/checkin-projection-read-model.ts
server/src/services/checkin-projection-worker.ts
server/src/scripts/checkin-*.ts
```

核心模型：

```text
Checkin
CheckinSnapshot
CheckinSelection
CheckinSelectionDJ
UserCheckinTimelineEntry
UserCheckinStat
UserCheckinGalleryDJAggregate
UserCheckinGalleryEventAggregate
UserCheckinDerivedSignal
CheckinOutboxEvent
```

处理策略：

- v2 projection 是当前主线。
- Projection 和 snapshot 相关数据动作前必须备份。
- v1 路径保留兼容，不新增复杂能力。

### Compat / Legacy

旧接口：

```text
server/src/routes/checkin.routes.ts
server/src/controllers/checkin.controller.ts
```

## 6. Web 路线

### Current

Web 作为 Admin / CMS / Public fallback。

相关路径：

```text
web/src/app/admin/
web/src/app/pre-register/
web/src/app/community/openim/
web/src/lib/api/
```

处理策略：

- 后续 Web 改造围绕运营后台、预报名和公开 fallback。
- App-first 能力优先在 iOS 里演进。

### Legacy

Web-first 产品口径。

处理策略：

- README 已修正。
- docs index 已说明 Web 当前定位。
- 后续 Web 页面按 Admin / Public / Legacy 分区整理。

## 7. iOS Service 路线

### Current

Feature Repository + App/Core/Infrastructure 分层。

已出现的 repository 形态：

```text
DiscoverEventsRepository
DiscoverDJsRepository
DiscoverSetsRepository
DiscoverWikiRepository
DiscoverNewsRepository
CircleFeedRepository
MessagesRepository
ProfileSocialRepository
VirtualAssetRepository
```

### Compat

历史大 Service：

```text
SocialService
WebFeatureService
LiveSocialService
LiveWebFeatureService
MockSocialService
MockWebFeatureService
```

处理策略：

- 暂时保留作为 API client / compatibility adapter。
- 新 ViewModel 优先依赖 Repository protocol。
- 后续逐步拆分为领域 repository。

## 8. API 路线

### Current Target

目标 API 分区：

```text
/api/app/v1/*
/api/admin/v1/*
/api/public/v1/*
/api/internal/v1/*
/api/legacy/*
```

### Compat

当前仍存在：

```text
/api/*
/v1/*
/v2/*
/v1/im/tencent
/v1/notification-center
```

处理策略：

- 不立即破坏旧路径。
- 新 module service 先承接业务逻辑。
- 旧 route 保留，逐步代理到新模块。
- 新客户端和新后台优先使用目标 API 分区。

## 9. 数据库路线

### Current Target

领域分组 + owner + repository 访问边界。

### Compat

当前 `schema.prisma` 大文件平铺。

处理策略：

- Phase 0 只建立 owner 和分类，不做 schema 改动。
- 改数据库前必须备份并验证。
- 后续优先加分组注释和 repository ownership，再考虑结构变更。

## 10. Legacy 清理原则

1. Legacy 不新增业务能力。
2. Legacy 不作为新功能依赖。
3. Compat 可以保留入口，但内部应逐步代理到 Current。
4. Migration 必须有退出条件。
5. 删除 legacy 前必须确认没有客户端、脚本、后台或数据任务依赖。
6. 涉及数据库删除或清洗前必须备份。

## 11. 当前待处理

- [x] 为 OpenIM 服务目录和 iOS legacy runtime 目录补充 legacy 标记。
- [ ] 将旧 notification 路线标记为 compat。
- [ ] 将 Check-in v1 路线标记为 compat / legacy。
- [ ] 将 Web 页面逐步分为 Admin / Public / Legacy。
- [ ] 将旧大 Service 迁移计划纳入 iOS repository 命名规范。
