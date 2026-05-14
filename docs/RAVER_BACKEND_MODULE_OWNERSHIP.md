# Raver Backend Module Ownership

> Status: Active  
> Owner: Backend Architecture  
> Last Updated: 2026-05-13
> Applies To: `server/src/`、`server/prisma/schema.prisma`  
> Purpose: 为后端模块化收束建立 owner、当前文件位置、核心模型和目标目录，避免 routes/services/scripts 继续横向膨胀。

## 1. 目标

后端目标结构采用 modular monolith：

```text
server/src/
  modules/
  shared/
  infrastructure/
  jobs/
  legacy/
```

本文件回答：

- 某个领域归哪个 module
- 当前代码散落在哪
- 核心表有哪些
- 未来迁移到哪里
- 哪些路径是 current / compat / legacy

## 2. Module 总表

| Module | 状态 | 负责范围 | 当前主要 routes | 当前主要 services/scripts | 核心模型 | 目标目录 |
| --- | --- | --- | --- | --- | --- | --- |
| `auth` | Current | 注册、登录、短信、refresh token、会话恢复 | `auth.routes.ts` | `auth-smoke.ts`、`auth-integration.ts` | `User`、`AuthRefreshToken`、`AuthSmsCode`、`AuthPhoneAuthState` | `server/src/modules/auth/` |
| `users` | Current | 用户资料、头像、公开主页、关注用户/DJ、资料审核 | `auth.routes.ts`、`follow.routes.ts` | 现散落在 controllers 和 BFF | `User`、`Follow`、`UserProfileModerationJob` | `server/src/modules/users/` |
| `events` | Current + Compat | 活动、阵容、时间表、票档、现场评论 | `event.routes.ts` | `modules/events` facade、`event.controller.ts`、`lineup.controller.ts`、`timetable.controller.ts` | `Event`、`EventLineupArtist`、`EventTimetableSlot`、`EventTicketTier`、`EventLiveComment` | `server/src/modules/events/` |
| `music` | Current + Compat | DJ、Set、Tracklist、Track、Label、Genre、外部音乐数据 | `dj.routes.ts`、`djset.routes.ts`、`label.routes.ts`、`music.routes.ts`、`dj-aggregator.routes.ts` | `modules/music` facade、`djset.service.ts`、`dj-aggregator.service.ts`、`spotify-artist.service.ts`、`discogs-artist.service.ts`、`soundcloud-artist.service.ts`、`music-search.service.ts` | `DJ`、`DJSet`、`Tracklist`、`Track`、`TracklistTrack`、`Label`、`Genre` | `server/src/modules/music/` |
| `feed` | Current + Compat | Post、评论、点赞、收藏、转发、隐藏、FeedEvent | `bff.routes.ts`、`bff.web.routes.ts`、`comment.routes.ts` | `modules/feed` facade、`comment.service.ts`、`seed-rich-feed.ts` | `Post`、`PostLike`、`PostRepost`、`PostSave`、`PostShare`、`PostHide`、`FeedEvent`、`PostComment` | `server/src/modules/feed/` |
| `squads` | Current | 小队、成员、邀请、小队消息、线下活动、定位状态 | `squad.routes.ts` | `squad.service.ts`、`seed-squad-offline-activity-demo.ts` | `Squad`、`SquadMember`、`SquadInvite`、`SquadActivity`、`SquadOfflineActivity`、`SquadOfflineActivityLocation` | `server/src/modules/squads/` |
| `im` | Current + Migration | Tencent IM bootstrap、usersig、用户/群同步、IM 迁移和治理 | `tencent-im.routes.ts` | `modules/im` facade、`services/tencent-im/*` provider、`tencent-im-*.ts` scripts、`services/openim/*` legacy | `OpenIMSyncJob`、`OpenIMWebhookEvent`、`OpenIMMessageReport`、`OpenIMImageModerationJob`、`OpenIMMessageMigration` | `server/src/modules/im/` |
| `notifications` | Current | Notification Center、APNs、Inbox、Delivery、Template、Scheduler | `notification-center.routes.ts`、`notification.routes.ts` compat | `services/notification-center/*`、`notification-*.ts` scripts、`notification.service.ts` compat | `NotificationEvent`、`NotificationInboxItem`、`NotificationDelivery`、`DevicePushToken`、`NotificationSubscription`、`NotificationTemplate` | `server/src/modules/notifications/` |
| `checkins` | Current + Compat | Check-in v2、snapshot、projection、outbox、v1 compat | `checkins-v2.routes.ts`、`checkin.routes.ts` compat | `checkin-*.ts` services/scripts | `Checkin`、`CheckinSnapshot`、`CheckinSelection`、`UserCheckinTimelineEntry`、`UserCheckinStat`、`CheckinOutboxEvent` | `server/src/modules/checkins/` |
| `virtual-assets` | Current | 虚拟资产、装备、外观 | `virtual-asset.routes.ts` | `virtual-asset.service.ts`、`virtual-assets:seed` | `VirtualAssetDefinition`、`UserVirtualAsset`、`UserVirtualAssetEquip` | `server/src/modules/virtual-assets/` |
| `share` | Current | 短链、二维码、海报、分享事件、邀请 referral | `share.routes.ts` | `share-link.service.ts`、`share-*.ts` scripts | `ShareLink`、`ShareLinkEvent`、`InviteReferral` | `server/src/modules/share/` |
| `search` | Current | 全局搜索、跨领域聚合搜索 | `search.routes.ts` | `global-search.service.ts`、`music-search.service.ts` | 多领域读取 | `server/src/modules/search/` |
| `pre-registrations` | Current | 预报名、批次、审核、通知 | `pre-registration.routes.ts` | `pre-registration.controller.ts` | `PreRegistration`、`PreRegistrationBatch`、`PreRegistrationDecision`、`PreRegistrationNotification` | `server/src/modules/pre-registrations/` |
| `admin` | Current + Facade | 后台权限、运营入口、运营配置、审计、状态聚合 | `/api/admin/v1` facade；旧入口仍散落在 notification-center、pre-registration、checkins-v2、virtual-assets | `modules/admin` facade，后续补 shared admin auth / audit / status | `AdminAuditLog`、各 ops action 审计 | `server/src/modules/admin/` |
| `bff` | Compat / Migration | 当前 App/Web 聚合接口 | `bff.routes.ts`、`bff.web.routes.ts` | 大量内联逻辑 | 多领域聚合 | 逐步拆回各 module 或 `modules/bff/` |

## 3. Module 内部标准

目标结构：

```text
server/src/modules/<module>/
  <module>.routes.ts
  <module>.controller.ts
  <module>.service.ts
  <module>.repository.ts
  <module>.policy.ts
  <module>.dto.ts
  <module>.mapper.ts
  <module>.types.ts
  <module>.jobs.ts
  index.ts
```

不是每个模块一开始都必须完整，但新增业务能力必须遵守这个落位。

## 4. 访问规则

1. Controller 不直接写复杂 Prisma 查询。
2. Service 编排业务用例和事务。
3. Repository 负责数据库读写。
4. Policy 负责权限、角色和可见性。
5. Mapper 负责 DB model 到 DTO。
6. Worker / script 调用 module service，不复制业务规则。
7. 第三方 SDK 放入 `infrastructure/`，业务 module 通过 adapter 使用。
8. Legacy route 保留入口，但应逐步代理到 current module service。

## 5. 迁移优先级

| 优先级 | Module | 原因 |
| --- | --- | --- |
| P0 | `notifications` | 边界清晰，适合作为后端模块化试点 |
| P0 | `checkins` | 已有 projection / runbook，工程价值高 |
| P1 | `share` | 边界独立，可快速收束 |
| P1 | `virtual-assets` | 模块较独立 |
| P1 | `im` | 需要明确 Tencent 主线和 OpenIM legacy |
| P2 | `feed` | 互动多，迁移需谨慎 |
| P2 | `squads` | 涉及 IM 和线下状态 |
| P3 | `events` | 模型和 BFF 依赖较多 |
| P3 | `music` | 外部集成和内容模型多 |
| P3 | `auth` / `users` | 影响全局，应在 shared auth/policy 稳定后做 |

## 6. 当前禁止事项

- 不新增新的横向 `server/src/services/*.ts` 大服务，除非只是迁移前短期兼容。
- 不在 `bff.routes.ts` / `bff.web.routes.ts` 中继续扩大新领域能力。
- 不在 worker 中复制一套领域规则。
- 不绕过目标 module 直接跨领域写表。
- 不在未备份数据库的情况下执行 migration、backfill、reproject apply 或批量数据修复。

## 7. Phase 5 Content Module Facades

2026-05-13 已建立内容域 current facade：

| Module | Facade | 当前 route 入口 | 仍属 compat 的实现 |
| --- | --- | --- | --- |
| `feed` | `server/src/modules/feed/index.ts` | `comment.routes.ts`、`bff.routes.ts`、`bff.web.routes.ts` 的 feed/comment 入口 | `bff.routes.ts` 中 feed stream、post create/update/delete、DTO mapping、notification orchestration 仍为 compat；FeedEvent、Post interactions、PostComment 写入已进入 module service |
| `events` | `server/src/modules/events/index.ts` | `event.routes.ts` | `controllers/event.controller.ts`、`lineup.controller.ts`、`timetable.controller.ts` 尚未物理迁移 |
| `music` | `server/src/modules/music/index.ts` | `dj.routes.ts`、`djset.routes.ts`、`music.routes.ts`、`dj-aggregator.routes.ts`、`bff.web.routes.ts` 的 DJSet / external artist provider 入口 | `label.routes.ts` 内联 Prisma 逻辑、BFF web 中 DJ/Set 聚合逻辑 |

本批只收束 import boundary，不改变 API 行为，不做数据库动作。后续 deeper extraction 应以 service/repository 小切片推进，避免把 BFF 大文件整体平移成新的 module God Service。

## 8. Phase 0 待办

- [ ] 为每个 module 建立 README 或 owner 注释。
- [ ] 建立 `server/src/modules/` 骨架。
- [ ] 选择 `notifications` 作为第一个迁移试点。
- [ ] 为 `bff.routes.ts` 和 `bff.web.routes.ts` 建立拆分计划。
