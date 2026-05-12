# Raver 商用级架构整理与重构方案

> Status: Active Draft  
> Owner: Architecture / Backend / iOS  
> Last Updated: 2026-05-12  
> Applies To: `server/`、`mobile/ios/RaverMVP/`、`web/`、`server/prisma/schema.prisma`、`docs/`  
> Related: `docs/RAVER_PLATFORM_ARCHITECTURE.md`、`docs/RAVER_COMMERCIAL_ARCHITECTURE_RESTRUCTURE_TRACKER.md`

## 0. 需求对齐

### 0.1 你当前真正想解决的问题

你现在感受到的“乱”，不是单纯文档乱，也不是文件多，而是：

> Raver 的业务复杂度已经进入平台级，但后端、iOS、数据库和工程目录仍然带着快速迭代期的组织方式。

这导致你在看项目时很难一眼判断：

- 某个文件属于哪个业务领域
- 某个 Service 是当前主线还是历史兼容
- 某个 API 是 App 用、Web 用、Admin 用，还是内部任务用
- 某张表是 source of truth、projection、outbox、audit，还是第三方系统镜像
- 某个 iOS Model / Service / ViewModel 应该放在哪里
- OpenIM、Tencent IM、旧通知、新通知、Check-in v1/v2 之间哪个是当前主线

所以这次改造的目标不是“美化目录”，而是把项目整理成商用级项目应有的清晰骨架。

### 0.2 本次改造目标

本次架构整理要达成：

1. 后端按业务领域收拢，而不是继续按 `routes/services/scripts` 横向平铺。
2. iOS 按 App Shell、Core Infrastructure、Feature Modules、Domain Repositories 清晰分层。
3. 数据库模型按领域、写模型、读模型、任务、审计、外部集成分组。
4. API 明确区分 App、Admin、Public、Internal、Legacy。
5. 历史路线明确标注和隔离，如 OpenIM、旧 notification、Check-in v1、旧 Web 主线。
6. 不做一次性大爆炸重构，而是按阶段渐进迁移。
7. 每一阶段都可验证、可回滚、可继续开发。
8. 使用 checkbox 跟踪大步骤和小步骤，任何阶段都能知道当前进度。
9. 使用独立 tracker / log 文档记录需求、进度、开发路径、风险和变更日志。
10. 改造过程始终围绕核心路线，避免新增外扩需求导致路线漂移。
11. 任何数据库结构变更、数据迁移、批量回填、清理动作前，必须先备份已有数据并验证备份可用。
12. iOS 编译验证复用固定 xcodebuild DerivedData 路径，默认不清理 `/tmp/raver-xcodebuild-derived`，避免每轮都触发全量编译；其他一次性过程文件仍及时清理。

### 0.3 本次不做什么

为避免重构失控，本次方案不建议一开始就做：

- 不重写后端框架。Express 可以继续用，重点是模块边界。
- 不把单体拆微服务。当前阶段单体模块化更适合。
- 不大规模改数据库表名。先做逻辑分组和访问边界。
- 不一次性移动所有 iOS 文件。先建立目标结构和适配层。
- 不同时重构业务逻辑和 UI 体验。
- 不把历史兼容代码直接删除。先标记、隔离、迁移、验证，再删除。

---

## 1. 总体改造原则

### 1.1 先收束，后重构

先定义主线架构、模块边界和命名规则，再逐步移动代码。不要在边界不清楚时开始搬文件。

### 1.2 领域优先

后端、iOS、数据库都以领域为中心组织：

- Auth & Identity
- Users & Social Graph
- Events
- Music Content
- Feed / Community
- Squads / Offline Collaboration
- IM / Messaging
- Notifications
- Check-ins
- Virtual Assets
- Share / Deep Links
- Admin / Operations

### 1.3 Source of Truth 明确

每个领域必须明确：

- 谁是主写模型
- 谁是读模型 / projection
- 谁是 outbox / job
- 谁是外部系统镜像
- 谁可以重建
- 谁不能丢

### 1.4 新旧分离

历史能力不要和当前主线混在一起。对于旧 API、旧模型、旧 IM 路线、旧 Web 方向，统一归类为：

- `legacy`
- `compat`
- `migration`
- `archive`

### 1.5 渐进式迁移

每次只迁移一个领域或一个边界，保留旧入口代理到新模块，验证后再删除旧入口。

### 1.6 可跟踪执行

本方案只定义蓝图；实际执行进度统一记录在：

```text
docs/RAVER_COMMERCIAL_ARCHITECTURE_RESTRUCTURE_TRACKER.md
```

执行规则：

- 每个 Phase 必须拆成 checkbox。
- 每个 checkbox 完成后更新 tracker。
- 每次实际改代码或改数据前，在 tracker 的 log 区记录目的、范围、风险和验证方式。
- 每次完成后记录结果、验证命令和后续动作。

### 1.7 核心路线防漂移

重构过程中只允许处理以下核心路线：

- 后端模块化收束
- iOS feature / repository 收束
- 数据库领域分组和访问边界
- API 分区和 legacy 隔离
- IM 当前主线确认
- Notification / Check-in / Share / VirtualAsset 等已存在核心能力的结构化迁移
- Web/Admin 作为运营台的结构收束

以下需求默认不进入本次改造，除非单独确认：

- 新产品功能
- 新推荐算法
- 新商业化玩法
- 新 UI 大改版
- 新第三方平台接入
- 微服务拆分
- 大规模数据库表重命名
- 与架构收束无关的性能优化

新增需求判断规则：

1. 是否直接服务当前阶段的架构收束目标。
2. 是否会扩大当前阶段的验证范围。
3. 是否会影响数据库、IM、通知、登录等核心链路稳定性。
4. 是否可以放入 backlog，而不是阻塞当前 Phase。

如果答案不明确，先记录到 tracker 的 `Backlog / Deferred`，不进入当前执行。

### 1.8 数据库备份门禁

在进行以下任何动作之前，必须先做数据备份：

- Prisma migration
- 手写 SQL 修改结构
- 批量 update / delete / insert
- backfill
- reproject apply
- snapshot rebuild
- 数据清洗
- 删除 legacy 表或字段

最低备份要求：

```bash
pg_dump "$DATABASE_URL" --format=custom --file backups/raver_$(date +%Y%m%d_%H%M%S).dump
```

执行前必须在 tracker 中记录：

- 备份文件路径
- 备份时间
- 目标数据库环境
- 操作人
- 本次数据动作范围
- 回滚方式

备份完成后必须至少做一个验证：

- 确认备份文件存在且大小合理
- 在临时库执行 restore smoke test
- 或至少执行 `pg_restore --list <dump-file>` 验证 dump 可读

没有备份记录，不进入数据库改造阶段。

---

## 2. 目标项目结构总览

目标不是让项目看起来复杂，而是让任何人打开项目后能快速回答：

> App 在哪，后端模块在哪，数据模型在哪，运营后台在哪，历史兼容在哪。

建议最终结构：

```text
raver/
  server/
    src/
      app/
      modules/
      shared/
      infrastructure/
      jobs/
      legacy/
      main.ts
    prisma/
      schema.prisma
      migrations/
      seeds/
      scripts/

  mobile/
    ios/
      RaverMVP/
        RaverMVP/
          App/
          Core/
          DesignSystem/
          Modules/
          Shared/
          Infrastructure/
          Legacy/

  web/
    src/
      app/
      modules/
      components/
      lib/
      admin/

  docs/
    README.md
    architecture/
    backend/
    ios/
    database/
    operations/
    runbooks/
    adr/
    legacy/
```

---

## 3. 后端架构改造

### 3.1 当前问题

当前后端结构是：

```text
server/src/
  controllers/
  routes/
  services/
  scripts/
  middleware/
  utils/
```

这属于早期 Express 项目的常见结构。问题是当业务领域变多以后，一个领域会散落在多个目录：

```text
Notification =
  routes/notification-center.routes.ts
  services/notification-center/*
  scripts/notification-*.ts
  prisma Notification*
  web admin page
  iOS NotificationsViewModel
```

这会导致：

- 按领域阅读困难
- Service 职责膨胀
- API 边界不清
- 脚本和业务逻辑重复
- 权限、DTO、Repository 没有固定位置
- 新人不知道新代码该放哪里

### 3.2 商用级目标结构

建议目标结构：

```text
server/src/
  app/
    createApp.ts
    routes.ts
    error-handler.ts
    health.routes.ts

  modules/
    auth/
      auth.routes.ts
      auth.controller.ts
      auth.service.ts
      auth.repository.ts
      auth.policy.ts
      auth.dto.ts
      auth.types.ts
      auth.mapper.ts

    users/
    events/
    music/
    feed/
    squads/
    im/
    notifications/
    checkins/
    virtual-assets/
    share/
    search/
    admin/

  shared/
    auth/
    errors/
    http/
    validation/
    pagination/
    logging/
    config/
    types/

  infrastructure/
    prisma/
    redis/
    oss/
    apns/
    tencent-im/
    sms/
    external-music/

  jobs/
    notification/
    checkin-projection/
    im-sync/
    imports/
    maintenance/

  legacy/
    openim/
    old-notifications/
    old-checkins/
```

### 3.3 模块内部标准

每个后端 module 统一使用以下结构：

```text
modules/<domain>/
  <domain>.routes.ts       # HTTP 路由注册
  <domain>.controller.ts   # HTTP 入参/出参
  <domain>.service.ts      # 应用用例编排
  <domain>.repository.ts   # 数据访问
  <domain>.policy.ts       # 权限和可见性规则
  <domain>.dto.ts          # API DTO / validation schema
  <domain>.mapper.ts       # DB model -> DTO
  <domain>.types.ts        # 领域类型
  <domain>.jobs.ts         # 领域相关 job 入口，可选
  index.ts                 # 对外导出
```

不是每个模块都必须一开始补齐所有文件，但新增代码必须按这个位置放。

### 3.4 分层职责

| 层 | 职责 | 不应该做 |
| --- | --- | --- |
| routes | 注册路径和 middleware | 写业务逻辑 |
| controller | 解析请求、调用 service、返回响应 | 直接写复杂 Prisma 查询 |
| service | 编排业务用例、事务、外部调用 | 直接处理 HTTP req/res |
| repository | 数据库读写 | 写权限规则和第三方 API 编排 |
| policy | 权限、可见性、角色判断 | 拼 DTO |
| mapper | DB model 到 API DTO | 查询数据库 |
| jobs | worker / scheduler 入口 | 复制 service 业务逻辑 |
| infrastructure | 第三方 SDK 封装 | 直接承载业务规则 |

### 3.5 后端领域模块划分

| Module | 负责 | 核心模型 |
| --- | --- | --- |
| `auth` | 登录、注册、短信、refresh token | `AuthRefreshToken`、`AuthSmsCode`、`AuthPhoneAuthState` |
| `users` | 用户资料、关注、主页、审核 | `User`、`Follow`、`UserProfileModerationJob` |
| `events` | 活动、阵容、时间表、票档、现场评论 | `Event`、`EventLineupArtist`、`EventTimetableSlot` |
| `music` | DJ、Set、Tracklist、Track、Label、Genre | `DJ`、`DJSet`、`Tracklist`、`Track`、`Label` |
| `feed` | Post、互动、评论、FeedEvent | `Post`、`PostLike`、`PostComment`、`FeedEvent` |
| `squads` | 小队、成员、邀请、线下活动、定位 | `Squad`、`SquadMember`、`SquadOfflineActivity` |
| `im` | Tencent IM、会话、群组同步、自定义卡片 | `OpenIMSyncJob`、`DirectConversation`、`DirectMessage` |
| `notifications` | 通知中心、APNs、订阅、投递 | `NotificationEvent`、`NotificationInboxItem`、`NotificationDelivery` |
| `checkins` | 打卡、快照、投影、outbox | `Checkin`、`CheckinSnapshot`、`UserCheckinStat` |
| `virtual-assets` | 虚拟资产、装备、外观 | `VirtualAssetDefinition`、`UserVirtualAsset` |
| `share` | 短链、二维码、邀请、打开埋点 | `ShareLink`、`ShareLinkEvent`、`InviteReferral` |
| `search` | 全局搜索、音乐搜索 | 多领域聚合 |
| `admin` | 后台权限、审核、运营配置、审计 | `AdminAuditLog`、运营相关模型 |

### 3.6 API 入口规范

目标 API 分区：

```text
/api/app/v1/*
/api/admin/v1/*
/api/public/v1/*
/api/internal/v1/*
/api/legacy/*
```

含义：

| 前缀 | 用途 |
| --- | --- |
| `/api/app/v1` | iOS / Android App 使用 |
| `/api/admin/v1` | 后台运营台使用 |
| `/api/public/v1` | 分享页、预报名页、公开落地页 |
| `/api/internal/v1` | worker、scheduler、内部服务 |
| `/api/legacy` | 旧 API 兼容层，逐步下线 |

迁移策略：

1. 保留当前 `/api`、`/v1`、`/v2`。
2. 新增统一路由聚合，不立即破坏旧客户端。
3. 旧 routes 内部代理到新 module service。
4. 新客户端和新页面使用新路径。
5. 观察稳定后标记旧路径 deprecated。

### 3.7 后端迁移顺序

建议按风险从低到高迁移：

1. `shared/` 和 `infrastructure/` 基础目录，不改变业务。
2. `notifications`，因为已经相对独立且有 worker 概念。
3. `checkins`，保持 v2 projection strict read model。
4. `share`，边界较清晰。
5. `virtual-assets`，当前较独立。
6. `im`，先隔离 Tencent IM 和 OpenIM legacy。
7. `feed`，处理互动模型和 FeedEvent。
8. `squads`，处理小队和线下协同。
9. `events` 和 `music`，模型最多，最后做。
10. `auth` 和 `users`，因为影响所有模块，建议在 shared auth/policy 稳定后做。

---

## 4. iOS 架构改造

### 4.1 当前问题

当前 iOS 已经有：

```text
Application/
Core/
Features/
Shared/
```

这是好的基础。混乱主要来自：

- `Core` 放了太多领域服务和模型。
- `SocialService`、`WebFeatureService` 名字过大且带历史阶段。
- `Core/Models.swift`、`WebFeatureModels.swift` 容易变成大杂烩。
- `Discover` 承载 Event、DJ、Set、Wiki 等多个领域。
- ViewModel 直接面对后端 DTO，领域模型和 UI model 边界不够清楚。
- IM、Feed、Squad、Notification、VirtualAsset 等复杂模块成熟度不同。

### 4.2 商用级目标结构

建议目标结构：

```text
RaverMVP/
  App/
    RaverMVPApp.swift
    AppState.swift
    AppContainer.swift
    Routing/
    Coordinator/

  Core/
    Networking/
    Auth/
    Storage/
    Logging/
    Localization/
    Config/
    Utilities/

  DesignSystem/
    Theme/
    Components/
    Feedback/
    Media/

  Modules/
    Auth/
    Home/
    Discover/
      Events/
      DJs/
      Sets/
      Wiki/
    Feed/
    Messages/
    Squads/
    Profile/
    Search/
    Notifications/
    Checkins/
    VirtualAssets/
    Share/

  Infrastructure/
    TencentIM/
    APNs/
    ImageLoading/
    MediaUpload/
    WidgetSync/

  Shared/
    Models/
    UI/
    Extensions/

  Legacy/
    WebFeatureCompat/
    OpenIMCompat/
```

### 4.3 iOS 模块内部标准

每个 Feature Module 建议：

```text
Modules/<Feature>/
  Views/
  ViewModels/
  Models/
  Repositories/
  UseCases/
  Coordinators/
  Components/
  Mappers/
```

并不是每个 feature 都必须完整，但新功能按这个标准落位。

### 4.4 iOS 分层职责

| 层 | 职责 |
| --- | --- |
| App | 启动、全局状态、依赖注入、全局路由 |
| Core | 网络、认证、存储、配置、日志等基础能力 |
| Infrastructure | 第三方 SDK 或平台能力，如 Tencent IM、APNs、图片加载 |
| Modules | 按业务功能组织页面、ViewModel、Repository、UseCase |
| DesignSystem | 主题、通用组件、反馈状态、媒体渲染 |
| Shared | 跨模块轻量模型、扩展、通用 UI |
| Legacy | 历史兼容层，等待迁移 |

### 4.5 Service 命名收束

当前：

```text
SocialService
WebFeatureService
LiveSocialService
LiveWebFeatureService
```

目标不是一次性删除，而是逐步被更明确的 Repository 替代：

```text
AuthRepository
UserRepository
EventRepository
DJRepository
SetRepository
FeedRepository
MessageRepository
SquadRepository
NotificationRepository
CheckinRepository
VirtualAssetRepository
ShareRepository
SearchRepository
```

迁移方式：

1. 先保留 `SocialService` / `WebFeatureService` 作为底层 API client 或 compat adapter。
2. 新建领域 Repository，内部调用旧 service。
3. ViewModel 改为依赖 Repository。
4. 等所有调用迁移完成，再拆分旧 service。

### 4.6 iOS 模型收束

目标模型分层：

```text
DTO          # 后端接口返回
DomainModel  # App 内业务模型
ViewState    # 页面展示状态
ViewModel    # 页面交互和状态管理
```

规则：

- View 不直接依赖后端 DTO。
- DTO 到 DomainModel 通过 Mapper。
- ViewModel 只暴露 ViewState。
- 大型 `Models.swift` 按领域拆分。

### 4.7 iOS 迁移顺序

建议顺序：

1. 建立 `Modules/` 目标目录，不移动大量文件。
2. 新增 Repository 命名规范和 protocol。
3. 从 `Notifications`、`VirtualAssets`、`Share` 这类边界清晰模块开始。
4. 再迁移 `Messages`，保留 UIKitChat 内部结构。
5. 迁移 `Squads` 和 offline activity。
6. 迁移 `Feed`。
7. 拆分 `Discover` 为 Events / DJs / Sets / Wiki。
8. 最后处理 Auth、Profile、AppState、AppContainer。

---

## 5. 数据库架构改造

### 5.1 当前问题

当前 Prisma schema 模型很多，已经覆盖平台级领域，但视觉上平铺在一个大文件中。问题是：

- 业务主模型、读模型、outbox、audit、外部集成模型混在一起。
- 新旧路线并存，如旧通知 / 新通知、OpenIM / Tencent IM、Checkin v1 / v2 projection。
- 难以判断某张表是否可以重建。
- 难以判断某张表属于哪个领域。
- Repository 边界不清时，任何服务都可能直接访问任何表。

### 5.2 先做逻辑分组，不急着拆 schema

Prisma 单文件 schema 可以继续保留，但需要用清晰注释分组：

```prisma
// =========================================================
// Auth & Identity
// Source of Truth
// =========================================================

// =========================================================
// Events Domain
// Source of Truth
// =========================================================

// =========================================================
// Music Content Domain
// Source of Truth
// =========================================================

// =========================================================
// Feed / Community Domain
// Source of Truth + Interaction Events
// =========================================================

// =========================================================
// Squads & Offline Collaboration
// Source of Truth + State Snapshots
// =========================================================

// =========================================================
// IM Integration
// External Mirror / Migration / Moderation
// =========================================================

// =========================================================
// Check-in Domain
// Write Models
// =========================================================

// =========================================================
// Check-in Read Models
// Rebuildable Projections
// =========================================================

// =========================================================
// Notification Center
// Outbox + Inbox + Delivery
// =========================================================

// =========================================================
// Operation / Audit / Moderation
// =========================================================
```

### 5.3 数据模型分类

| 分类 | 含义 | 示例 |
| --- | --- | --- |
| Source of Truth | 业务主写模型，不能随意重建 | `User`、`Event`、`DJ`、`Post`、`Squad`、`Checkin` |
| Snapshot | 固化历史展示语义 | `CheckinSnapshot` |
| Projection / Read Model | 可由写模型重建 | `UserCheckinTimelineEntry`、`UserCheckinStat` |
| Outbox / Job | 异步任务和投递可靠性 | `CheckinOutboxEvent`、`NotificationEvent`、`OpenIMSyncJob` |
| External Mirror | 第三方系统同步或 webhook 镜像 | `OpenIMWebhookEvent`、`OpenIMMessageMigration` |
| Audit / Moderation | 审计、审核、治理 | `AdminAuditLog`、`OpenIMMessageReport`、`UserProfileModerationJob` |
| Operation | 运营后台和预报名 | `PreRegistration`、`PreRegistrationBatch` |
| Analytics / Events | 行为事件和埋点 | `FeedEvent`、`ShareLinkEvent` |

### 5.4 数据访问规则

商用级项目中，数据库访问不能到处散落。建议规则：

1. 每张表原则上只由所属 module 的 repository 写入。
2. 跨领域读取通过 service 或 query adapter，不直接跨模块写表。
3. Projection 只能由 projection worker 或明确的 rebuild service 写入。
4. Outbox 只能通过对应 domain service 创建和状态推进。
5. Admin 操作必须写 `AdminAuditLog`。
6. 外部 webhook payload 原样保存后，再进入业务处理。
7. 所有 deletion / status transition 要有领域 service 承担，不在 controller 中直接 Prisma update。

### 5.5 数据库迁移优先级

短期不改表名，先做三件事：

1. 给 schema 加领域分组注释。
2. 建立 repository ownership 表。
3. 禁止新代码绕过 repository 直接访问非本领域表。

中期再考虑：

1. 补齐重要外键和唯一约束。
2. 清理历史冗余模型。
3. 为高频查询补 read model。
4. 为敏感模型补审计。

---

## 6. Web / Admin 架构改造

### 6.1 当前定位

当前 Web 不应作为主产品客户端叙述中心。它更适合定位为：

- Admin Console
- Pre-registration Website
- Content CMS
- Public fallback pages
- Legacy web frontend

### 6.2 目标结构

```text
web/src/
  app/
    admin/
    public/
    legacy/

  modules/
    admin-notifications/
    pre-registrations/
    events/
    music/
    community/
    openim-ops/

  components/
    ui/
    layout/
    data-table/
    forms/

  lib/
    api/
    auth/
    config/
```

### 6.3 Admin Console 标准能力

商用级运营后台至少应逐步具备：

- 登录与后台权限
- 用户管理
- 内容管理
- 活动管理
- DJ / Set / Label 数据治理
- 通知模板与投递管理
- 预报名审核
- IM 举报和图片审核
- Projection / worker 状态看板
- AdminAuditLog 查询

---

## 7. 历史路线收束

### 7.1 需要标记的历史/兼容路线

当前项目中建议明确标记：

| 路线 | 当前处理 |
| --- | --- |
| Web-first 产品口径 | 标记为 legacy / admin-oriented |
| React Native 旧口径 | README 修正为 iOS native 主线 |
| OpenIM 路线 | 放入 IM legacy / migration 说明 |
| Tencent IM 路线 | 标记为当前 IM 主线 |
| Check-in v1 | 标记为 legacy write/read path |
| Check-in v2 projection | 标记为当前主线 |
| 旧 notification | 标记为 legacy |
| notification-center | 标记为当前主线 |

### 7.2 Legacy 规则

凡是 legacy 代码：

- 文件头或目录 README 标明原因
- 不新增业务能力
- 新能力只进入当前主线模块
- 保留兼容测试
- 定期清理下线

---

## 8. 文档与 ADR 改造

虽然这次重点不是文档乱，但商用级项目需要文档和架构边界同步。

### 8.1 目标 docs 结构

```text
docs/
  README.md
  architecture/
    RAVER_PLATFORM_ARCHITECTURE.md
    RAVER_COMMERCIAL_ARCHITECTURE_RESTRUCTURE_PLAN.md
  backend/
  ios/
  database/
  operations/
  runbooks/
  adr/
  legacy/
  generated/
  handoffs/
  archived/
```

### 8.2 ADR 列表

建议补充：

```text
docs/adr/
  0001-app-first-ios-native.md
  0002-use-tencent-im-as-current-im-provider.md
  0003-checkin-v2-projection-read-model.md
  0004-notification-center-as-current-notification-system.md
  0005-modular-monolith-before-microservices.md
  0006-admin-console-over-public-web-first.md
```

每篇 ADR 固定格式：

```md
# ADR-0001 Title

## Status
Accepted / Deprecated / Superseded

## Context

## Decision

## Consequences

## Migration Notes
```

---

## 9. 分阶段执行计划

实际进度以 tracker 为准；本节是执行蓝图。每个 Phase 都必须在 tracker 中使用 checkbox 记录大步骤和小步骤。

### Phase 0：架构冻结与命名对齐

目标：先定规则，不动大代码。

任务：

- [ ] 确认本文档作为架构整理蓝图。
- [ ] 新增 tracker / log 文档并开始记录。
- [ ] 新增 docs 入口和 ADR 目录。
- [ ] 更新 README 中过时口径。
- [ ] 列出 legacy 清单。
- [ ] 建立后端 module ownership 表。
- [ ] 建立 iOS repository 命名规范。
- [ ] 建立数据库备份门禁规则。
- [ ] 建立新增需求防漂移规则。

验收：

- [ ] 新人能通过 docs README 找到当前主线。
- [ ] 每个核心领域都有 owner、核心表、核心 API、核心 service 说明。
- [ ] tracker 中能看到当前阶段进度、日志、风险和 deferred backlog。

### Phase 1：后端模块骨架

目标：建立商用级后端骨架，但不破坏现有 API。

任务：

- [ ] 新增 `server/src/modules/`。
- [ ] 新增 `server/src/shared/`。
- [ ] 新增 `server/src/infrastructure/`。
- [ ] 新增 `server/src/jobs/`。
- [ ] 将 `notification-center` 作为第一个模块迁移试点。
- [ ] 旧 routes 继续保留，但调用新 module service。
- [ ] 更新 tracker log，记录迁移范围和验证方式。

验收：

- [ ] 通知中心 API 行为不变。
- [ ] notification worker 仍可运行。
- [ ] 新模块结构被验证可用。
- [ ] 没有引入新产品功能或额外需求。

### Phase 2：Check-in 和 Share 收束

目标：迁移边界清晰、工程价值高的模块。

任务：

- [ ] 执行数据库备份并验证备份可读。
- [ ] 在 tracker 记录备份文件、数据库环境和回滚方式。
- [ ] 迁移 `checkins` module。
- [ ] 将 projection worker 放入 `jobs/checkin-projection/`。
- [ ] 迁移 `share` module。
- [ ] 明确 v2 projection read model ownership。

验收：

- [ ] `checkins:projection:freshness` 正常。
- [ ] `checkins:projection:run` 正常。
- [ ] share link smoke 正常。
- [ ] 若执行过 reproject / rebuild / backfill，tracker 中有备份记录和结果记录。

### Phase 3：iOS Repository 层收束

目标：让 ViewModel 不再直接依赖巨型 service。

任务：

- [ ] 建立 `Modules/*/Repositories/`。
- [ ] 从 Notifications、VirtualAssets、Share 开始迁移。
- [ ] 为 Event、DJ、Set、Feed、Squad 定义 repository protocol。
- [ ] `SocialService` 和 `WebFeatureService` 暂时降级为底层 API client。
- [ ] 更新 tracker log，记录每个迁移模块的 ViewModel 调整范围。

验收：

- [ ] 新 ViewModel 依赖 Repository protocol。
- [ ] 旧 service 调用逐步减少。
- [ ] 单个模块可 mock repository 做预览和测试。
- [ ] iOS 编译通过。

### Phase 4：IM 和 Squad 收束

目标：明确 Tencent IM 主线，隔离 OpenIM 历史兼容。

任务：

- [ ] 后端 `im` module 收拢 Tencent IM integration。
- [ ] OpenIM 相关模型和服务标记为 legacy / migration。
- [ ] iOS `Infrastructure/TencentIM/` 收拢 SDK 会话、store、media resolver。
- [ ] `Messages` module 保留 UIKitChat，但收束 custom card、repository、route target。
- [ ] Squad offline activity 与 IM group sync 分清边界。
- [ ] 若涉及 IM 数据迁移或同步 job apply，先执行数据库备份并记录。

验收：

- [ ] IM bootstrap 正常。
- [ ] 会话列表正常。
- [ ] 群组同步路径清楚。
- [ ] OpenIM 文件不再被误认为当前主线。
- [ ] 没有把 OpenIM 历史方案继续扩展为新主线。

### Phase 5：Feed / Events / Music 大领域收束

目标：处理复杂内容域。

任务：

- [ ] 迁移 `feed` module。
- [ ] 将 `FeedEvent`、Post interactions 和 comment tree 收束。
- [ ] 迁移 `events` module。
- [ ] 迁移 `music` module。
- [ ] iOS Discover 拆分 Events / DJs / Sets / Wiki。
- [ ] 若涉及数据回填、索引调整或 schema migration，先执行数据库备份并记录。

验收：

- [ ] Feed 发布、点赞、收藏、评论正常。
- [ ] 活动详情、DJ 详情、Set 详情正常。
- [ ] Discover 内部领域边界清楚。
- [ ] 没有顺手加入推荐算法、内容商业化等外扩需求。

### Phase 6：Admin / Operations 商用化

目标：把 Web/Admin 从页面集合升级为运营系统。

任务：

- [ ] Admin API 统一到 `/api/admin/v1`。
- [ ] 补后台 RBAC。
- [ ] 补 AdminAuditLog。
- [ ] 建立运营看板入口。
- [ ] 接入 notification、pre-registration、projection、IM moderation。
- [ ] 若涉及运营数据迁移或批量修复，先执行数据库备份并记录。

验收：

- [ ] 后台敏感操作有权限和审计。
- [ ] 运营入口不再散落。
- [ ] 能查关键 worker / projection / notification 状态。
- [ ] Admin 改造没有改变 App 核心用户链路。

---

## 10. 商用级验收标准

### 10.1 后端验收

- 任意一个业务领域可以在 `server/src/modules/<domain>` 找到主体代码。
- Controller 不直接写复杂 Prisma 查询。
- Worker 不复制业务规则，而是调用 service。
- 第三方 SDK 封装在 `infrastructure/`。
- 旧 API 有 legacy 标记。
- 新 API 有 app/admin/public/internal 分区。
- 权限判断有 policy 层或 shared auth 能力。

### 10.2 iOS 验收

- ViewModel 依赖 Repository protocol，而不是直接依赖巨型 service。
- 新功能落在 `Modules/<Feature>`。
- 第三方 SDK 能力放在 `Infrastructure/`。
- DesignSystem 和业务模块分离。
- DTO、DomainModel、ViewState 边界明确。
- `Core` 不再继续膨胀成业务大杂烩。

### 10.3 数据库验收

- Prisma schema 有明确领域分组。
- 每张核心表有 owner module。
- Projection 表明确可重建。
- Outbox / Job 表有处理 worker。
- Audit / Moderation 表不和业务主模型混淆。
- 新代码通过 repository 访问核心表。

### 10.4 运营验收

- Admin 入口统一。
- 敏感操作写审计。
- 通知、预报名、IM 举报、Projection 状态可运营。
- 关键 worker 有运行命令和 runbook。

---

## 11. 推荐优先级

如果只能先做最有价值的事情，建议顺序：

1. 后端建立 `modules/shared/infrastructure/jobs/legacy` 骨架。
2. Prisma schema 加领域分组注释和 owner 清单。
3. iOS 建立 Repository protocol，先迁移 Notifications / VirtualAssets。
4. IM 明确 Tencent 为当前主线，OpenIM 放入 legacy。
5. API 新增 app/admin/public/internal 设计，但旧 API 保持兼容。
6. 更新 README 和 docs 入口，降低心智噪音。

---

## 12. 最终目标状态

完成改造后，Raver 应该呈现为一个清晰的商用级模块化单体：

- 后端是 modular monolith，不是 routes/services 大平铺。
- iOS 是 feature modular architecture，不是 Core 巨型服务集合。
- 数据库是领域分组模型，不是所有表平铺。
- Web 是 Admin / CMS / Public fallback，不再和主 App 定位冲突。
- IM、Notification、Check-in、Share、VirtualAsset 都有明确主线。
- Legacy 被隔离，历史路线不会干扰当前判断。
- 新功能知道放哪里，旧功能知道怎么迁移。

一句话：

> 让 Raver 从“功能已经很强的快速迭代项目”，升级为“领域边界清晰、演进路径明确、多人可协作、可上线运营的商用级项目骨架”。
