# Raver Documentation Index

> Status: Active  
> Last Updated: 2026-05-12  
> Purpose: Raver 项目的统一文档入口，用于区分当前主线、架构改造、运行手册、历史方案和阶段性记录。

## 1. 当前主线

如果你是第一次阅读项目，建议按这个顺序看：

1. [Raver Platform Architecture](./RAVER_PLATFORM_ARCHITECTURE.md)  
   当前项目的平台级架构总览，解释产品定位、领域架构、iOS、后端、实时系统、内容系统和工程亮点。

2. [Raver 商用级架构整理与重构方案](./RAVER_COMMERCIAL_ARCHITECTURE_RESTRUCTURE_PLAN.md)  
   架构收束目标、后端/iOS/数据库/Web 改造方案、分阶段路线和验收标准。

3. [Raver 商用级架构改造进度与日志](./RAVER_COMMERCIAL_ARCHITECTURE_RESTRUCTURE_TRACKER.md)  
   当前改造进度、checkbox、日志、数据库备份记录、风险和 deferred backlog。

4. [Raver Legacy And Current Mainline Inventory](./RAVER_LEGACY_AND_CURRENT_MAINLINE_INVENTORY.md)  
   当前主线、历史兼容、迁移中路线和后续处理策略。

5. [Raver Backend Module Ownership](./RAVER_BACKEND_MODULE_OWNERSHIP.md)  
   后端模块 owner、当前 routes/services/scripts、核心模型和目标目录。

6. [iOS Repository Naming And Module Guide](./IOS_REPOSITORY_NAMING_AND_MODULE_GUIDE.md)  
   iOS Repository 命名规范、模块落位规则和旧 Service 迁移方向。

7. [Database Backup Gatekeeper](./DATABASE_BACKUP_GATEKEEPER.md)  
   数据库迁移、回填、reproject、snapshot rebuild 和批量修复前的备份门禁。

8. [Architecture Scope Control](./ARCHITECTURE_SCOPE_CONTROL.md)  
   架构改造期间的核心路线约束和新增需求防漂移规则。

9. [Raver App 端后端概述](./RAVER_APP_BACKEND_OVERVIEW_FOR_ENGINEER.md)  
   给后端工程师看的 App 端后端能力概述。

## 2. 核心架构专题

### iOS

- [iOS Repository Naming And Module Guide](./IOS_REPOSITORY_NAMING_AND_MODULE_GUIDE.md)
- [MVVM Coordinator Migration Plan](./MVVM_COORDINATOR_MIGRATION_PLAN.md)
- [iOS Single Root Navigation Refactor Basis](./IOS_SINGLE_ROOT_STACK_COVERING_NAVIGATION_REFACTOR_BASIS.md)
- [iOS Loading State System Guide](./IOS_LOADING_STATE_SYSTEM_GUIDE.md)
- [iOS Notification Center Lifecycle Guide](./IOS_NOTIFICATION_CENTER_LIFECYCLE_GUIDE.md)
- [iOS Virtual Asset Skin System Plan](./IOS_VIRTUAL_ASSET_SKIN_SYSTEM_PLAN.md)
- [iOS Share Short Link QR System Plan](./IOS_SHARE_SHORT_LINK_QR_SYSTEM_PLAN.md)

### Backend / Data

- [Raver Backend Module Ownership](./RAVER_BACKEND_MODULE_OWNERSHIP.md)
- [Database Backup Gatekeeper](./DATABASE_BACKUP_GATEKEEPER.md)
- [MyCheckins Commercial Architecture Rebuild Master Plan](./MYCHECKINS_COMMERCIAL_ARCHITECTURE_REBUILD_MASTER_PLAN.md)
- [MyCheckins Projection Runbook](./MYCHECKINS_PROJECTION_RUNBOOK.md)
- [Auth Login State Full Guide](./AUTH_LOGIN_STATE_FULL_GUIDE.md)
- [Notification System V1 Plan](./NOTIFICATION_SYSTEM_V1_PLAN.md)
- [APNs Unified Push Service Implementation Plan](./APNS_UNIFIED_PUSH_SERVICE_IMPLEMENTATION_PLAN.md)

### IM / Realtime

- [Tencent IM Migration Master Plan](./TENCENT_IM_MIGRATION_MASTER_PLAN.md)
- [Tencent IM Exyte Chat Architecture](./TENCENT_IM_EXYTE_CHAT_ARCHITECTURE.md)
- [Chat Custom Cards Plan](./CHAT_CUSTOM_CARDS_PLAN.md)
- [OpenIM Local Dev](./OPENIM_LOCAL_DEV.md)

当前 IM 主线是 Tencent IM；OpenIM 相关文档属于历史、迁移或兼容参考。

## 3. 运营与运行手册

- [APNs Real Device Setup And E2E Runbook](./APNS_REAL_DEVICE_SETUP_AND_E2E_RUNBOOK.md)
- [OpenIM Chat UIKit Rollout Runbook](./OPENIM_CHAT_UIKIT_ROLLOUT_RUNBOOK.md)
- [OpenIM Storage Governance Runbook](./OPENIM_STORAGE_GOVERNANCE_RUNBOOK.md)
- [Dev Proxy DB Runbook](./DEV_PROXY_DB_RUNBOOK.md)
- [Test Environment Deployment Plan](./TEST_ENV_DEPLOYMENT_PLAN.md)

## 4. 架构决策记录

ADR 位于：

```text
docs/adr/
```

当前建议优先阅读：

- [ADR-0001 App-first iOS Native](./adr/0001-app-first-ios-native.md)
- [ADR-0002 Tencent IM As Current IM Provider](./adr/0002-tencent-im-as-current-im-provider.md)
- [ADR-0003 Check-in v2 Projection Read Model](./adr/0003-checkin-v2-projection-read-model.md)
- [ADR-0004 Notification Center As Current Notification System](./adr/0004-notification-center-current-system.md)
- [ADR-0005 Modular Monolith Before Microservices](./adr/0005-modular-monolith-before-microservices.md)
- [ADR-0006 Admin Console Over Public Web First](./adr/0006-admin-console-over-public-web-first.md)

## 5. 文档状态说明

文档头部建议使用：

```md
> Status: Active / Draft / Deprecated / Archived
> Owner: Backend / iOS / Product / Ops
> Last Updated: YYYY-MM-DD
> Applies To: path-or-domain
```

含义：

| Status | 含义 |
| --- | --- |
| Active | 当前主线，需要优先遵循 |
| Draft | 草案，可以参考但未完全固化 |
| Deprecated | 已被新方案替代，只用于理解历史 |
| Archived | 历史归档，不再作为当前方案 |

## 6. 目录说明

| 目录 | 用途 |
| --- | --- |
| `docs/` | 当前平铺文档区，正在逐步整理 |
| `docs/adr/` | 架构决策记录 |
| `docs/handoffs/` | 阶段性交接文档 |
| `docs/generated/` | 自动生成或导出的资料 |
| `docs/reports/` | 执行报告、测试报告、迁移报告 |
| `docs/archived/` | 已归档历史文档 |

## 7. 改造纪律

商用级架构改造期间：

- [Architecture Scope Control](./ARCHITECTURE_SCOPE_CONTROL.md)
- [Database Backup Gatekeeper](./DATABASE_BACKUP_GATEKEEPER.md)

- 进度只在 tracker 中更新。
- 新需求先进入 deferred backlog。
- 数据库改造前必须备份并验证备份可读。
- 当前阶段不做与架构收束无关的新功能。
- 旧路线先标记 legacy，再迁移，再删除。
