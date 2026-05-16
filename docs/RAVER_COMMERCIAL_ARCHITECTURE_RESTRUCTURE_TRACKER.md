# Raver 商用级架构改造进度与日志

> Status: Active  
> Owner: Architecture / Backend / iOS  
> Created: 2026-05-12  
> Related Plan: `docs/RAVER_COMMERCIAL_ARCHITECTURE_RESTRUCTURE_PLAN.md`  
> Purpose: 用于跟踪架构改造需求、进度、开发路径、数据库备份、风险、验证结果和日志。

## 0. 使用规则

### 0.1 更新频率

- 每次开始一个改造任务前，先在本文件记录任务范围。
- 每完成一个 checkbox，立即更新状态。
- 每次改数据库前，必须先填写数据库备份记录。
- 每次完成实际代码或结构改动后，补充日志和验证结果。
- 每次出现新增需求，先进入 `Backlog / Deferred`，不要直接插入当前路线。
- iOS 验证默认保留 `/tmp/raver-xcodebuild-derived` 作为 xcodebuild 增量编译缓存，不再每次 build 后删除；只有用户明确要求、缓存损坏或需要验证 clean build 时才清理该目录。
- 其他一次性过程文件、日志导出、smoke test 临时文件仍应在验证结束后及时删除，避免堆积成无用历史文件。

### 0.2 状态标记

- `[ ]` 未开始
- `[~]` 进行中
- `[x]` 已完成
- `[!]` 阻塞 / 风险
- `[-]` 取消 / 不再执行

Markdown checkbox 原生不支持 `[~]` 和 `[!]`，如果渲染不显示为 checkbox，也保留该状态文本作为人工跟踪标记。

### 0.3 核心路线约束

本次改造只围绕以下核心路线：

- 后端模块化收束
- iOS feature / repository 收束
- 数据库领域分组和访问边界
- API 分区和 legacy 隔离
- IM 当前主线确认
- Notification / Check-in / Share / VirtualAsset 等既有核心能力结构化迁移
- Web/Admin 作为运营台的结构收束

不在当前路线内的需求，默认进入 `Backlog / Deferred`。

---

## 1. 总进度

| Phase | 名称 | 状态 | 开始时间 | 完成时间 | 备注 |
| --- | --- | --- | --- | --- | --- |
| Phase 0 | 架构冻结与命名对齐 | `[x]` | 2026-05-12 | 2026-05-12 | Phase 0 文档治理已完成，下一步进入 Phase 1 后端模块骨架 |
| Phase 1 | 后端模块骨架 | `[x]` | 2026-05-12 | 2026-05-12 | notifications facade 已建立；旧 route/app bootstrap 已通过新 module 入口引用 |
| Phase 2 | Check-in 和 Share 收束 | `[x]` | 2026-05-12 | 2026-05-12 | Check-in/Share facade、projection job 入口和验证均完成 |
| Phase 3 | iOS Repository 层收束 | `[x]` | 2026-05-12 | 2026-05-12 | 已完成 Phase 3 逻辑边界收束；IM/Realtime 进入 Phase 4，Rating/Content 深拆进入 Phase 5，物理目录大搬迁 deferred |
| Phase 4 | IM 和 Squad 收束 | `[x]` | 2026-05-12 | 2026-05-12 | 代码边界与真实运行 smoke 均已通过；数据迁移或同步 apply 前仍必须备份 |
| Phase 5 | Feed / Events / Music 大领域收束 | `[x]` | 2026-05-12 | 2026-05-13 | Feed / Events / Music 代码 closure 与真实运行 smoke 均已通过；未触发数据库动作 |
| Phase 6 | Admin / Operations 商用化 | `[~]` | 2026-05-13 |  | P0 inventory / ownership 已启动；先做 facade 和权限边界，不做数据迁移 |
| Phase 7 | Content CMS 统一后台入口 | `[~]` | 2026-05-13 |  | 集成 festival-viewer 到 Web Admin；第一批不做 RBAC 表和数据库迁移 |
| Phase 8 | Auth Session 商用化 | `[~]` | 2026-05-16 |  | 已新增专项主控文档；先补后台管理登录态、iOS 会话管理、审计、二次验证和环境门禁 |

---

## 2. Phase Checklist

### Phase 0：架构冻结与命名对齐

目标：先定规则，不动大代码。

- [x] 确认商用级架构整理总方案。
- [x] 新增 tracker / log 文档。
- [x] 新增 docs 入口。
- [x] 新增 ADR 目录。
- [x] 更新 README 中过时口径。
- [x] 列出 legacy 清单。
- [x] 建立后端 module ownership 表。
- [x] 建立 iOS repository 命名规范。
- [x] 建立数据库备份门禁规则。
- [x] 建立新增需求防漂移规则。

验收：

- [x] 新人能通过 docs README 找到当前主线。
- [x] 每个核心领域都有 owner、核心表、核心 API、核心 service 说明。
- [x] 本 tracker 能看到当前阶段进度、日志、风险和 deferred backlog。

### Phase 1：后端模块骨架

目标：建立商用级后端骨架，但不破坏现有 API。

- [x] 新增 `server/src/modules/`。
- [x] 新增 `server/src/shared/`。
- [x] 新增 `server/src/infrastructure/`。
- [x] 新增 `server/src/jobs/`。
- [x] 将 `notification-center` 作为第一个模块迁移试点。
- [x] 旧 routes 继续保留，但调用新 module service。
- [x] 更新 tracker log，记录迁移范围和验证方式。

验收：

- [x] 通知中心 API 行为不变。
- [x] notification worker 仍可运行。
- [x] 新模块结构被验证可用。
- [x] 没有引入新产品功能或额外需求。

### Phase 2：Check-in 和 Share 收束

目标：迁移边界清晰、工程价值高的模块。

- [x] 执行数据库备份并验证备份可读。
- [x] 在本文件记录备份文件、数据库环境和回滚方式。
- [x] 迁移 `checkins` module。
- [x] 将 projection worker 放入 `jobs/checkin-projection/`。
- [x] 迁移 `share` module。
- [x] 明确 v2 projection read model ownership。

验收：

- [x] `checkins:projection:freshness` 正常。
- [x] `checkins:projection:run` 正常。
- [x] share link smoke 正常。
- [x] 若执行过 reproject / rebuild / backfill，本文件有备份记录和结果记录。

### Phase 3：iOS Repository 层收束

目标：让 ViewModel 不再直接依赖巨型 service。

- [x] 建立 Repository 边界；Phase 3 完成逻辑边界收束，当前沿用现有 `Features/*` / `Core` 布局，物理 `Modules/*/Repositories/` 大搬迁 deferred。
- [x] 从 Notifications、VirtualAssets、Share 开始迁移。
- [x] Notifications ViewModel 改为依赖 `NotificationRepository` protocol。
- [x] VirtualAssets 已确认具备 `VirtualAssetRepository` protocol / live / disabled / mock 形态，本轮不重复迁移。
- [x] Share 建立 `ShareLinkRepository` protocol 和 adapter，`ShareLinkCoordinator` 改为依赖 repository，同时保留 `ShareLinkService` initializer 兼容旧调用。
- [x] 为 Event、DJ、Set、Feed、Squad 定义 repository protocol；Discover Event/DJ/Set 已有 repository，Feed 已扩展到列表/发布/详情，SquadProfile 主 ViewModel 已迁移。
- [x] `SocialService`、`WebFeatureService`、`ShareLinkService` 暂时降级为底层 API client；Phase 3 目标范围内页面 / ViewModel 直连已收口，剩余 IM/Realtime/Rating detail 已归入 Phase 4/5。
- [x] 标记并治理 Fat Repository 风险；`ProfileSocialRepository`、`DiscoverEventsRepository`、`SquadProfileRepository`、`MessagesRepository` 已列为过渡 adapter，并有后续拆分方向。
- [x] 更新 tracker log，记录每个迁移模块的 ViewModel 调整范围。

验收：

- [x] Notifications ViewModel 依赖 Repository protocol。
- [x] 旧 service 调用逐步减少；Phase 3 目标范围已完成，剩余直连已按 Phase 4 IM/Realtime、Phase 5 Rating/Content、基础设施 adapter 分类。
- [x] 单个模块可 mock repository 做预览和测试；Notifications 已新增 `MockNotificationRepository` 和 `Notifications Repository Seam` preview，VirtualAssets 已有 mock repository。
- [x] iOS 编译通过。

### Phase 4：IM 和 Squad 收束

目标：明确 Tencent IM 主线，隔离 OpenIM 历史兼容。

- [x] 后端 `im` module 收拢 Tencent IM integration。
- [x] OpenIM 相关服务目录标记为 legacy / migration。
- [x] iOS `Infrastructure/TencentIM/` 收拢 SDK 会话、store、media resolver；store、search index、probe logger、storage governance、media cache/resolver 已归位，`TencentIMSession` 已从 `AppState.swift` 拆到 `Infrastructure/TencentIM/Session`。
- [x] `Messages` module 第一批 repository 边界拆分：旧 `MessagesRepository` 已拆为 `ConversationRepository` / `MessageNotificationRepository`。
- [x] `Messages` module 保留 UIKitChat，但完成 Phase 4 范围内的 custom card、ChatSettings repository、route target 收束；后续 renderer / preview 继续细拆进入 Phase 5/后续 UI 模块治理，不在 Phase 4 继续扩面。
- [x] Squad offline activity 与 IM group sync 分清边界；iOS offline activity 已拆为 `SquadActivityRepository` / `LocationSyncRepository`，IM group sync 保留在 Tencent IM / squad membership 路径。
- [x] 本 Phase 4 代码收束未执行 IM 数据迁移、同步 job apply、群组关系回填或批量修复；若后续执行这些数据动作，必须先备份数据库并记录。

验收：

- [x] IM bootstrap 真实运行正常：用户已确认 Tencent IM bootstrap smoke 通过；iOS `AppState.refreshTencentIMBootstrap` 调用 `/v1/im/tencent/bootstrap` 并同步到 `TencentIMSession.sync`。
- [x] 会话列表真实运行正常：用户已确认 conversation list、direct/group chat open smoke 通过；`ConversationRepository` -> `SocialService.fetchConversations` -> `TencentIMSession.fetchConversations` / `IMChatStore` 边界清楚。
- [x] 群组同步路径清楚：后端 Squad 创建、加入、退出、转让、移除等路径通过 `tencentIMGroupService` / `server/src/modules/im` 进入 Tencent IM；iOS offline activity 与 IM group sync 已分离。
- [x] 群成员同步真实运行正常：用户已确认 group member sync smoke 通过。
- [x] OpenIM 文件不再被误认为当前主线：后端 `server/src/services/openim/README.md` 与 iOS `Infrastructure/LegacyOpenIM/README.md` 已标记 Legacy / Migration，Current 路径为 `Infrastructure/TencentIM` 和 `server/src/modules/im`。
- [x] 没有把 OpenIM 历史方案继续扩展为新主线：本 Phase 4 仅新增 legacy marker 和 Tencent IM facade / boundary，没有新增 OpenIM 业务能力。

### Phase 5：Feed / Events / Music 大领域收束

目标：处理复杂内容域。

- [x] 迁移 `feed` module。
- [x] 将 `FeedEvent`、Post interactions 和 comment tree 收束。
- [x] 迁移 `events` module。
- [x] 迁移 `music` module。
- [x] iOS Discover 拆分 Events / DJs / Sets / Wiki。
- [-] 若涉及数据回填、索引调整或 schema migration，先执行数据库备份并记录。本 Phase 5 代码 closure 未触发数据库动作。

验收：

- [x] Feed 发布、点赞、收藏、评论正常。2026-05-13 用户确认真实运行 smoke 通过。
- [x] 活动详情、DJ 详情、Set 详情正常。2026-05-13 用户确认真实运行 smoke 通过。
- [x] Discover 内部领域边界清楚。
- [x] 没有顺手加入推荐算法、内容商业化等外扩需求。

### Phase 6：Admin / Operations 商用化

目标：把 Web/Admin 从页面集合升级为运营系统。

- [x] 完成 Admin / Operations route、Web 页面、ops scripts inventory。
- [x] 新增 `docs/RAVER_ADMIN_OPERATIONS_PHASE6_INVENTORY.md`，明确 Phase 6 ownership、迁移顺序和 scope guard。
- [x] 标记 OpenIM admin client 为 legacy / not current，不扩展为当前 IM 后台主线。
- [x] 本 Phase 6 P0 只做文档和边界清点，不执行数据库 schema/data migration、projection rebuild、snapshot rebuild、IM sync apply 或批量修复。
- [x] Admin API facade 统一到 `/api/admin/v1`，旧入口保留兼容。
- [x] 补 shared admin auth / role policy，先统一 `admin` / `operator` 判定，再评估 RBAC。
- [x] 补 AdminAuditLog 接入；已确认 schema / migration 既有，本批只接入 shared audit service，不需要数据库备份。
- [x] 建立运营状态入口，聚合 notification、checkin projection、worker/APNs 关键状态。
- [x] Web Admin 接入统一 Admin API client；Admin shell 页面结构不在本批重构。
- [x] OpenIM admin client/page 已降级为 legacy / deferred 兼容入口，不接入 current Admin 主线。
- [ ] 若涉及运营数据迁移或批量修复，先执行数据库备份并记录。

验收：

- [ ] 后台敏感操作有权限和审计。
- [x] 运营入口不再散落。
- [x] 能查关键 worker / projection / notification 状态。
- [x] Admin 改造没有改变 App 核心用户链路。

### Phase 7：Content CMS 统一后台入口

目标：把 `festival-viewer` 从 Python 单独入口收束到 Web Admin 的单一后台入口中，同时明确管理员、入驻主办方、普通用户、艺人的内容管理权限边界。

- [x] 新增 `/admin/content-cms` 作为内容后台唯一可见入口。
- [x] `/admin` 从纯运营总览升级为后台工作台：普通用户、艺人、主办方也可进入，但只看到自己角色可用的内容管理入口。
- [x] `festival-viewer` 通过 Next rewrites 挂到 `/admin/festival-viewer.html` 和 `/admin/festival-viewer/*`，不再要求用户直接打开 Python 入口。
- [x] 代理 `festival-viewer` 依赖的专用 API：`/api/raver/*`、`/api/viewer/*`、`/api/coze/*`、`/api/scrape/*`、`/api/dj-source-cache/*`、`/api/proxy-image`、`/api/open-folder`、`/api/search`。
- [x] 新增 Web 端角色策略 helper，统一 `admin`、`operator`、`organizer`、`artist`、`user`、`guest` 的后台入口判断。
- [x] Navigation 只保留一个后台入口，不再把内容后台、预登记、通知中心作为散落的主入口。
- [x] 明确第一批权限落地方式：仍使用现有 `User.role` 字符串、`Event.organizerId`、`DJContributor`、`DJSet.uploadedById`、`WikiFestivalContributor` 等已有 owner/contributor 边界；不新增 RBAC 表。
- [x] 若后续要新增 `Organization`、`OrganizationMember`、`ArtistClaim`、`ContentOwnership`、`AdminRolePolicy` 等正式 RBAC / 入驻主体表，必须先执行数据库备份并验证可读。

验收：

- [x] 登录用户只需要从 `/admin` 进入后台；内容管理入口在 `/admin/content-cms`。
- [x] 管理员可进入内容后台，并保留运营状态、通知中心、预登记后台等敏感能力。
- [x] 入驻主办方可进入内容后台，定位为官方活动 / 资讯发布和自己名下活动维护。
- [x] 艺人可进入内容后台，定位为艺人资料维护，同时具备普通用户内容管理能力。
- [x] 普通用户可进入内容后台，定位为自己上传活动、DJ、Set、资讯等内容的管理。
- [x] 本批未执行数据库 schema/data migration、backfill、projection rebuild、snapshot rebuild、IM sync apply 或批量修复，因此不需要新增数据库备份记录。

### Phase 8：Auth Session 商用化

目标：把后台管理端和 iOS 端的登录态、续期、会话撤销、审计、二次验证和环境门禁补齐到商用级。

主控文档：

```text
docs/AUTH_SESSION_COMMERCIALIZATION_PLAN.md
```

- [x] 完成当前 Web Admin 与 iOS 登录态现状盘点。
- [x] 确认 Web Admin 当前仍是旧 `/api/auth/*` 单 JWT + `localStorage`。
- [x] 确认 iOS 当前已接入 `/v1/auth/*` 双 token + Keychain + refresh rotation。
- [x] 新增 `docs/AUTH_SESSION_COMMERCIALIZATION_PLAN.md`。
- [x] 在本 tracker 增加 Phase 8 入口。
- [~] 确认 dev / staging / production 认证环境变量；local 已确认，dev/staging/prod 待部署环境核验。
- [x] 执行 Phase 1 后端会话模型补齐前，先完成数据库备份门禁。
- [x] Web Admin 迁移到 `/v1/auth/*` + HttpOnly refresh cookie。
- [~] 后台补 idle timeout、absolute timeout、会话列表、踢下线和二次验证；idle/absolute/session list/revoke/管理员踢下线已完成，账号处罚和账号删除重试/到期处理二次验证已完成，其他高风险操作二次验证待补。
- [x] iOS 补登录设备管理、logout-all 和 session revoked 差异化体验。
- [ ] Auth 审计落库并接入后台检索。

验收：

- [x] Web Admin 不再把主 token 存入 `localStorage`。
- [x] Web Admin 具备 access 内存态 + refresh HttpOnly cookie。
- [x] Web Admin 具备 30 分钟 idle timeout 和 12 小时 absolute timeout。
- [x] iOS 保持 15 分钟 access token + 30 天 refresh token，并支持设备会话管理。
- [x] 管理员可查看和撤销会话。
- [~] 高风险后台操作具备二次验证；账号处罚写操作、账号删除重试和账号删除到期处理已完成，其他高风险操作待扩展。
- [ ] Auth 审计可后台检索和导出。
- [ ] dev / staging / production 环境变量通过门禁。
- [ ] 后端、Web、iOS、真机回归全部通过。

Phase 8 数据库备份记录：

| 时间 | 环境 | 操作范围 | 备份文件 | 验证方式 | 回滚方式 | 状态 |
| --- | --- | --- | --- | --- | --- | --- |
| 2026-05-16 16:58 | local `raver_dev` | Auth Session Phase 1 前置备份，准备扩展 `auth_refresh_tokens` 会话字段 | `backups/raver_20260516_165823_before_auth_session_commercialization.dump` | `docker exec -i raver-postgres pg_restore --list < dump`，输出 752 行；dump 大小 16MB | 本地可停止服务后使用 `pg_restore --clean --if-exists` 恢复该 dump，或回滚对应 migration | 已验证 |

---

## 3. 当前执行路径

当前阶段：Phase 8 Auth Session commercialization planning

当前焦点：

1. Phase 0 / Phase 1 / Phase 2 已完成。
2. Phase 3 已完成：iOS Repository 逻辑边界收束完成。
3. Phase 4 已完成：代码边界收束与真实账号 / 真机 IM smoke 均已通过。
4. Phase 5 已完成 Feed / Events / Rating / Music first cuts，并进一步完成 DJ import、DJ residual、Events residual、`EventRatingRepository` 兼容命名清理、Profile adapter physical split、Rating adapter physical split、Events adapter physical split、Music adapter physical split、Feed adapter physical split、repository compatibility cleanup、后端 content module facade、FeedEvent telemetry service、PostInteraction service 和 PostComment service；真实运行 smoke 已通过。
5. iOS build 使用固定 `-derivedDataPath /tmp/raver-xcodebuild-derived` 复用增量编译缓存；默认不清理该目录。
6. Phase 6 P0 inventory、P1 Admin route facade、P2 backend admin policy、Web admin client alignment、AdminAuditLog write/query、Admin status backend aggregation、Web status API client、`/admin` 运营总览入口和 OpenIM legacy / deferred cleanup 已完成；本轮不涉及数据库结构变更或数据动作，不需要数据库备份。
7. Phase 7 第一批已完成：`festival-viewer` 内容管理能力已收束到 Web Admin `/admin/content-cms`，未做 DB / RBAC migration。
8. Phase 8 已启动：登录态与后台管理商用化主控文档已建立，下一步进入环境变量核查和后端会话模型补齐 preflight。

下一步建议：

1. 按 `docs/AUTH_SESSION_COMMERCIALIZATION_PLAN.md` 先完成 Phase 0 未勾选项：环境变量核查、后台角色分级、二次验证方式确认。
2. Phase 1 涉及 `auth_refresh_tokens` 字段扩展，执行前必须按 `docs/DATABASE_BACKUP_GATEKEEPER.md` 完成备份并记录。
3. Web Admin 迁移登录态时优先做兼容迁移：清理旧 `localStorage.token`，新 session 走 `/v1/auth/*` + HttpOnly cookie。
4. iOS 继续保持当前 Keychain + refresh rotation，不在后台迁移时破坏 App 端 30 天体验。
5. 正式 RBAC / 入驻组织 / 艺人认领模型继续 deferred，不混入 Auth Session Phase 8。

### Phase 8 Scope Check

- [x] 当前任务属于哪个 Phase：Phase 8 Auth Session 商用化。
- [x] 当前任务是否服务该 Phase 目标：是，建立登录态商用化主控计划和 tracker 入口。
- [x] 是否新增产品功能：否，本批是计划、范围和验收口径。
- [x] 是否改 App 核心用户链路：否。
- [x] 是否迁移数据库：否。
- [x] 是否涉及 schema migration、auth session 字段、审计表、reauth proof 表或批量修复：否，因此本批不需要新增数据库备份。
- [x] 是否需要进入 Backlog / Deferred：正式 RBAC / Organization / ArtistClaim / ContentOwnership 继续 deferred。

### Phase 7 Scope Check

- [x] 当前任务属于哪个 Phase：Phase 7 Content CMS 统一后台入口。
- [x] 当前任务是否服务该 Phase 目标：是，把 `festival-viewer` 收束到 `/admin/content-cms`。
- [x] 是否新增产品功能：否，本批是入口整合和权限边界表达，不增加新的内容类型。
- [x] 是否改 App 核心用户链路：否。
- [x] 是否迁移数据库：否。
- [x] 是否涉及 schema migration、RBAC 表、组织/艺人认领表、运营数据迁移、projection rebuild、snapshot rebuild、IM sync apply 或批量修复：否，因此本批不需要新增数据库备份。
- [x] 是否需要进入 Backlog / Deferred：正式 RBAC / Organization / ArtistClaim / ContentOwnership 表设计进入后续 Phase 7 小批次，执行前必须走数据库备份门禁。

### Phase 7 Content CMS Unified Entry Plan

- [x] 在 tracker 中记录 Phase 7 目标、scope guard、角色模型和验证方式。
- [x] 新增 Web role policy helper，统一后台角色能力判断。
- [x] 新增 `/admin/content-cms` 页面，作为内容 CMS 权限检查和登录态同步的跳转桥接页，不使用 iframe 内嵌。
- [x] `/admin` 增加“内容管理中心”入口，并允许普通登录用户进入后台工作台。
- [x] Navigation 收束为单个“后台管理”入口；通知中心、预登记保留在 `/admin` 内部卡片。
- [x] Next rewrites 增加 festival-viewer 静态资源和专用 API 代理，且必须放在通用 `/api/:path*` 后端代理之前。
- [x] 新增 `docs/RAVER_CONTENT_CMS_UNIFIED_ADMIN_PLAN.md`，记录统一入口、角色模型、代理结构和后续正式 RBAC 方向。
- [x] Web build 和 whitespace validation 通过。
- [x] 本批不执行数据库动作；若后续需要正式 RBAC 表，先备份数据库。

Phase 7 第一批角色模型：

| 角色 | 当前落地方式 | 第一批后台能力 | 后续正式化方向 |
| --- | --- | --- | --- |
| `admin` | `User.role = admin` | 全站内容管理、运营状态、通知中心、预登记后台 | 可进入 AdminRolePolicy 细粒度权限 |
| `operator` | `User.role = operator` | 运营协作、预登记、状态巡检、内容工具访问 | 与 admin 区分敏感写权限 |
| `organizer` | `User.role = organizer` + `Event.organizerId` | 官方发布活动 / 资讯，维护自己名下活动 | `Organization` / `OrganizationMember` |
| `artist` | `User.role = artist` + DJ contributor / future claim | 维护艺人资料，同时具备普通用户内容管理 | `ArtistClaim` / verified artist ownership |
| `user` | `User.role = user` + existing owner fields | 管理自己上传的活动、DJ、Set、资讯 | `ContentOwnership` 统一 owner / contributor |

### Phase 6 Scope Check

- [x] 当前任务属于哪个 Phase：Phase 6 Admin / Operations 商用化。
- [x] 当前任务是否服务该 Phase 目标：是，先把 Admin route、Web Admin、ops scripts、ownership 和迁移顺序清点清楚。
- [x] 是否新增产品功能：否。
- [x] 是否改 App 核心用户链路：否。
- [x] 是否迁移 API：否，本 P0 只做 inventory 文档。
- [x] 是否涉及数据库：否。
- [x] 是否涉及 schema migration、AdminAuditLog、RBAC 表、运营数据迁移、projection rebuild、snapshot rebuild、IM sync apply 或批量修复：否，因此本批不需要新增数据库备份。
- [x] 是否需要进入 Backlog / Deferred：OpenIM admin current 化不进入 Phase 6 主线，保留 legacy / deferred。

### Phase 6 P0 Admin / Operations Inventory Plan

- [x] 清点 notification admin endpoints：publish、test publish、status、deliveries、config、templates。
- [x] 清点 pre-registration admin endpoints：registrations、batches、results、decisions、notifications。
- [x] 清点 checkin ops endpoint：projection status。
- [x] 清点 virtual asset ops endpoint：asset grants。
- [x] 清点 Web Admin 页面和 API client：notification center、pre-registrations、OpenIM legacy client。
- [x] 清点 ops jobs/scripts：checkin projection、notification jobs、Tencent IM sync/export/delete。
- [x] 明确 Phase 6 ownership model：admin-shell、notification-ops、pre-registration-ops、checkin-ops、virtual-asset-ops、im current/legacy、content-ops。
- [x] 明确 Phase 6 migration order：P0 inventory、P1 route facade、P2 shared admin auth、P3 audit log、P4 status dashboard、P5 legacy cleanup。
- [x] 新增 Phase 6 inventory 文档。
- [x] 运行文档 whitespace validation。

Phase 6 P0 验证：

- [x] `git diff --check -- docs/RAVER_ADMIN_OPERATIONS_PHASE6_INVENTORY.md docs/RAVER_COMMERCIAL_ARCHITECTURE_RESTRUCTURE_TRACKER.md docs/README.md` 通过。
- [x] 本批只改文档，不需要后端 / Web / iOS build。
- [x] 本批未执行数据库 schema/data migration、backfill、projection rebuild、snapshot rebuild、IM sync apply 或批量修复，因此不需要新增数据库备份记录。

### Phase 6 P1 Admin Route Facade Plan

- [x] 新增 `server/src/modules/admin/README.md`，明确 Admin module 只做运营聚合，不吞并领域业务规则。
- [x] 新增 `server/src/modules/admin/admin.routes.ts` 和 `index.ts`。
- [x] 新增 `/api/admin/v1` router，先做 facade，不删除旧入口。
- [x] 将 notification admin endpoints 代理到 `/api/admin/v1/notifications/*`。
- [x] 将 pre-registration admin endpoints 代理到 `/api/admin/v1/pre-registrations/*`、`/api/admin/v1/pre-registration-batches/*`、`/api/admin/v1/pre-registration-notifications`。
- [x] 将 checkin projection status 代理到 `/api/admin/v1/checkins/projection/status`。
- [x] 将 virtual asset grant 代理到 `/api/admin/v1/virtual-assets/grants`。
- [x] `server/src/index.ts` 暴露 admin route，并在 `/api` endpoint map 中标注。
- [x] 后端 build 通过；不需要 DB backup，因为不改 schema / data。

Phase 6 P1 验证：

- [x] `git diff --check -- server/src/modules/admin/README.md server/src/modules/admin/admin.routes.ts server/src/modules/admin/index.ts server/src/index.ts docs/RAVER_ADMIN_OPERATIONS_PHASE6_INVENTORY.md docs/RAVER_COMMERCIAL_ARCHITECTURE_RESTRUCTURE_TRACKER.md docs/RAVER_BACKEND_MODULE_OWNERSHIP.md docs/README.md` 通过。
- [x] 新增 untracked admin module 文件已用 `git diff --no-index --check /dev/null <file>` 单独验证。
- [x] 后端 build 通过：`cd server && pnpm build`。
- [x] 本批只新增 Admin facade 和 route mount，旧入口保留兼容，未修改响应结构。
- [x] 本批未执行数据库 schema/data migration、backfill、projection rebuild、snapshot rebuild、IM sync apply 或批量修复，因此不需要新增数据库备份记录。

### Phase 6 P2 Shared Admin Auth / Role Policy Plan

- [x] 新增 `server/src/modules/admin/admin-auth.policy.ts`。
- [x] 提供 `requireAdmin`、`requireAdminOrOperator`、`isAdmin`、`isAdminOrOperator`，统一当前 Admin / Operations 角色判断。
- [x] Notification Center admin endpoints 改用 `requireAdmin`。
- [x] Pre-registration admin endpoints 改用 `requireAdminOrOperator`。
- [x] Virtual asset grant admin endpoint 改用 `requireAdminOrOperator`。
- [x] Check-in projection status 局部 helper 改为委托 `isAdminOrOperator`。
- [x] 保持 `authenticate` / `authorize` 原有行为兼容，不改全局 auth middleware。
- [x] 后端 build 通过；不需要 DB backup，因为不改 schema / data。
- [x] Web admin client 统一到 `/api/admin/v1` facade；token/error handling 保持现有行为，不做页面重构。
- [x] Web build 通过。

Phase 6 P2 验证：

- [x] `git diff --check -- server/src/modules/admin/admin-auth.policy.ts server/src/modules/admin/README.md server/src/modules/admin/index.ts server/src/routes/pre-registration.routes.ts server/src/routes/virtual-asset.routes.ts server/src/routes/notification-center.routes.ts server/src/routes/checkins-v2.routes.ts docs/RAVER_ADMIN_OPERATIONS_PHASE6_INVENTORY.md docs/RAVER_COMMERCIAL_ARCHITECTURE_RESTRUCTURE_TRACKER.md` 通过。
- [x] 新增 untracked `admin-auth.policy.ts` 已用 `git diff --no-index --check /dev/null server/src/modules/admin/admin-auth.policy.ts` 单独验证。
- [x] 后端 build 通过：`cd server && pnpm build`。
- [x] 目标范围旧 admin/operator 判断清零：notification admin、pre-registration admin、virtual asset grant、checkin projection status 不再直接使用 `authorize('admin...')` 或重复 `role !== 'admin' && role !== 'operator'`。
- [x] 本批只统一后端 Admin / Operations role policy；未执行数据库 schema/data migration、backfill、projection rebuild、snapshot rebuild、IM sync apply 或批量修复，因此不需要新增数据库备份记录。

### Phase 6 Web Admin Client Alignment Plan

- [x] Notification Center admin client 从 `/v1/notification-center/admin/*` 切到 `/api/admin/v1/notifications/*`。
- [x] Pre-registration admin client 从 `/api/admin/*` 切到 `/api/admin/v1/*`。
- [x] 保持现有 token/error handling，不新增 Web admin 页面、不改 UI、不改响应结构。
- [x] OpenIM admin client 保持 legacy，不接入 current `/api/admin/v1`。
- [x] Web build 通过。

Phase 6 Web Admin client alignment 验证：

- [x] `git diff --check -- web/src/lib/api/notification-center-admin.ts web/src/lib/api/pre-registration.ts docs/RAVER_ADMIN_OPERATIONS_PHASE6_INVENTORY.md docs/RAVER_COMMERCIAL_ARCHITECTURE_RESTRUCTURE_TRACKER.md` 通过。
- [x] `rg` 验证 notification / pre-registration admin client 已命中 `/admin/v1`，旧 notification-center/pre-registration admin API base 已清零；OpenIM admin 仍为 legacy 命中。
- [x] Web build 通过：`cd web && pnpm build`。
- [x] Build warning 均为既有 Web lint warning：React hook dependency 和 `<img>` 优化建议，非本批新增阻塞。
- [x] 本批未执行数据库 schema/data migration、backfill、projection rebuild、snapshot rebuild、IM sync apply 或批量修复，因此不需要新增数据库备份记录。

### Phase 6 AdminAuditLog Write Integration Plan

- [x] 核对 `server/prisma/schema.prisma`：`AdminAuditLog` 已存在，映射 `admin_audit_logs`。
- [x] 核对历史 migration：`server/prisma/migrations/20260421125500_add_admin_audit_logs/migration.sql` 已存在。
- [x] 新增 `server/src/modules/admin/admin-audit.service.ts`，提供 `adminAuditService.createAction` 和事务内可复用的 `buildAdminAuditLogCreateData`。
- [x] Pre-registration batch create / decision / notification enqueue 改为统一审计入口。
- [x] Notification config update / template upsert 接入审计。
- [x] Virtual asset grant 接入审计。
- [x] 保持现有 API 响应结构不变，不新增后台页面。
- [-] 本批不执行 Prisma migration、不新增字段、不新增索引，因此不需要数据库备份。

Phase 6 AdminAuditLog write integration 验证：

- [x] `git diff --check -- server/src/modules/admin/admin-audit.service.ts server/src/modules/admin/README.md server/src/modules/admin/index.ts server/src/controllers/pre-registration.controller.ts server/src/routes/notification-center.routes.ts server/src/routes/virtual-asset.routes.ts` 通过。
- [x] 后端 build 通过：`cd server && pnpm build`。
- [x] `rg` 验证审计 action 已覆盖 notification config/template、virtual asset grant、pre-registration batch/decision/notification enqueue。
- [x] 本批未执行数据库 schema/data migration、backfill、projection rebuild、snapshot rebuild、IM sync apply 或批量修复，因此不需要新增数据库备份记录。

### Phase 6 Admin Audit Query Plan

- [x] `adminAuditService.listLogs` 支持按 `actorId`、`action`、`targetType`、`targetId`、`before/cursor` 过滤。
- [x] 新增 `GET /api/admin/v1/audit-logs`，使用 `authenticate` + `requireAdmin`。
- [x] 返回 `success`、`items`、`nextCursor`，不改写任何数据。
- [x] 新增 Web admin audit API client：`web/src/lib/api/admin-audit.ts`，暂不新增页面。
- [x] 保持 OpenIM legacy audit client 不接入 current Admin API。
- [-] 本批只读现有 `admin_audit_logs`，不执行 Prisma migration、不新增字段、不新增索引，因此不需要数据库备份。

Phase 6 Admin audit query 验证：

- [x] `git diff --check -- server/src/modules/admin/admin-audit.service.ts server/src/modules/admin/admin.routes.ts server/src/modules/admin/README.md web/src/lib/api/admin-audit.ts docs/RAVER_ADMIN_OPERATIONS_PHASE6_INVENTORY.md docs/RAVER_COMMERCIAL_ARCHITECTURE_RESTRUCTURE_TRACKER.md` 通过。
- [x] 后端 build 通过：`cd server && pnpm build`。
- [x] Web build 通过：`cd web && pnpm build`。
- [x] 本批未执行数据库 schema/data migration、backfill、projection rebuild、snapshot rebuild、IM sync apply 或批量修复，因此不需要新增数据库备份记录。

### Phase 6 Admin Status Backend Aggregation Plan

- [x] 新增 `server/src/modules/admin/admin-status.service.ts`，作为跨域只读聚合层。
- [x] 新增 `GET /api/admin/v1/status`，使用 `authenticate` + `requireAdminOrOperator`。
- [x] 聚合 Notification delivery stats、APNs config、Notification outbox worker runtime config。
- [x] 聚合 Check-in projection freshness/status。
- [x] 返回 `overallStatus`、`alertReasons`、`notification`、`checkinProjection`，不触发 worker、不执行 rebuild、不写业务数据。
- [x] 新增 `web/src/lib/api/admin-status.ts`，先提供 client，不新增页面。
- [x] 不新增运营策略、不新增推荐/审核/商业化需求、不改 App 用户链路。
- [-] 本批只读现有表和运行时配置，不执行 Prisma migration、不新增字段、不新增索引，因此不需要数据库备份。

Phase 6 Admin status backend aggregation 验证：

- [x] `git diff --check -- server/src/modules/admin/admin-status.service.ts server/src/modules/admin/admin.routes.ts server/src/modules/admin/index.ts server/src/modules/admin/README.md server/src/services/notification-center/notification-outbox.scheduler.ts web/src/lib/api/admin-status.ts docs/RAVER_ADMIN_OPERATIONS_PHASE6_INVENTORY.md docs/RAVER_COMMERCIAL_ARCHITECTURE_RESTRUCTURE_TRACKER.md` 通过。
- [x] 后端 build 通过：`cd server && pnpm build`。
- [x] Web build 通过：`cd web && pnpm build`。
- [x] 本批未执行数据库 schema/data migration、backfill、projection rebuild、snapshot rebuild、IM sync apply 或批量修复，因此不需要新增数据库备份记录。

### Phase 6 Web Admin Shell Status Entry Plan

- [x] 新增 `/admin` 运营总览页面，消费 `web/src/lib/api/admin-status.ts`。
- [x] `/admin` 只展示 `overallStatus`、notification、APNs、outbox worker、check-in projection 状态，不新增写操作。
- [x] Navigation 对 admin/operator 增加“运营总览”入口。
- [x] Notification Center admin 页面增加返回“运营总览”的轻量链接。
- [x] Pre-registration admin 页面增加返回“运营总览”的轻量链接。
- [x] 不做 UI 重设计、不新增运营策略、不触发 worker/rebuild、不改 App 核心用户链路。
- [-] 本批只读现有 Admin status API，不执行 Prisma migration、不新增字段、不新增索引，因此不需要数据库备份。

Phase 6 Web Admin shell status entry 验证：

- [x] `git diff --check -- web/src/app/admin/page.tsx web/src/app/admin/notification-center/page.tsx web/src/app/admin/pre-registrations/page.tsx web/src/components/Navigation.tsx docs/RAVER_ADMIN_OPERATIONS_PHASE6_INVENTORY.md docs/RAVER_COMMERCIAL_ARCHITECTURE_RESTRUCTURE_TRACKER.md` 通过。
- [x] Web build 通过：`cd web && pnpm build`。
- [x] 本批未执行数据库 schema/data migration、backfill、projection rebuild、snapshot rebuild、IM sync apply 或批量修复，因此不需要新增数据库备份记录。

### Phase 6 Legacy / Deferred Cleanup Plan

- [x] `web/src/lib/api/openim-admin.ts` 增加 legacy/deprecated 注释，明确不新增 current Admin 能力。
- [x] `web/src/app/community/openim/page.tsx` 页面标题和说明标记为 OpenIM Legacy / Deferred。
- [x] Navigation 中 OpenIM 入口降噪为 `OpenIM Legacy`，避免被误认为 current Admin 主线。
- [x] `docs/RAVER_PLATFORM_ARCHITECTURE.md` 将 OpenIM 管理从 current operations 口径改为历史兼容入口。
- [x] `docs/README.md` 标记 OpenIM runbooks 为 legacy / migration references。
- [x] 不删除兼容页面、不删除 OpenIM 历史文档、不迁移 OpenIM 数据、不执行清理脚本。
- [-] 本批只改文案和文档边界，不执行 Prisma migration、不新增字段、不新增索引，因此不需要数据库备份。

Phase 6 legacy / deferred cleanup 验证：

- [x] `git diff --check -- web/src/lib/api/openim-admin.ts web/src/app/community/openim/page.tsx web/src/components/Navigation.tsx docs/RAVER_ADMIN_OPERATIONS_PHASE6_INVENTORY.md docs/RAVER_PLATFORM_ARCHITECTURE.md docs/README.md docs/RAVER_COMMERCIAL_ARCHITECTURE_RESTRUCTURE_TRACKER.md` 通过。
- [x] Web build 通过：`cd web && pnpm build`。
- [x] 本批未执行数据库 schema/data migration、backfill、projection rebuild、snapshot rebuild、IM sync apply、OpenIM cleanup script 或批量修复，因此不需要新增数据库备份记录。

### Phase 5 Smoke Runbook

执行原则：

- [x] 只验证 Phase 5 改造影响到的现有核心路径，不新增测试数据批量脚本，不做数据回填。
- [x] 不删除 `/tmp/raver-xcodebuild-derived`，继续保留 iOS 增量编译缓存。
- [x] smoke 过程中如创建临时帖子或评论，验证完成后由 App 正常删除；不使用数据库直接删除。
- [x] 如果发现需要 schema migration、索引调整、projection rebuild 或数据修复，先暂停并执行数据库备份门禁。

Feed smoke：

- [x] 打开 Feed 列表，确认列表正常加载、图片/视频卡片不空白。2026-05-13 用户复测通过；此前 `Failed to load posts` 已通过取消请求静默处理修复。
- [x] 发布一条纯文本或普通图片 Feed，确认发布成功并能在列表或个人发布中看到。2026-05-13 用户复测通过；此前新帖不立刻出现在 Feed 已通过本地去重置顶修复。
- [x] 打开刚发布或已有 Feed 详情，确认详情页正常加载。
- [x] 点赞该 Feed，确认点赞状态和数量变化正常。
- [x] 取消点赞该 Feed，确认状态回退正常。
- [x] 收藏该 Feed，确认收藏状态和数量变化正常。
- [x] 取消收藏该 Feed，确认状态回退正常。
- [x] 新增一条评论，确认评论出现在评论列表且评论数变化正常。2026-05-13 用户复测通过；此前 `Failed to load comments` 已通过取消请求静默处理修复。
- [x] 返回 Feed 列表，确认列表刷新后该 Feed 的互动状态没有异常回退。

Discover / content detail smoke：

- [x] 打开一个 Event 详情，确认基础信息、封面、lineup / timetable / live discussion 入口不报错。
- [x] 打开一个 DJ 详情，确认基础信息、关注状态、关联 Set/Event/Rating/Checkin count 等内容正常。
- [x] 打开一个 Set 详情，确认曲目、媒体、互动状态和详情内容正常。

Phase 5 close 条件：

- [x] Feed smoke 全部通过。
- [x] Discover / content detail smoke 全部通过。
- [x] 未发现需要数据库修复、schema migration、projection rebuild 的阻塞问题。
- [x] 未引入推荐算法、内容商业化、举报系统、UI 重设计等外扩需求。

### Phase 4 Scope Check

- [x] 当前任务属于哪个 Phase：Phase 4 IM 和 Squad 收束。
- [x] 当前任务是否服务该 Phase 目标：是，明确 Tencent IM 主线并减少 IM / Messages 过渡 repository 膨胀。
- [x] 是否新增产品功能：否。
- [x] 是否扩大验证范围：否，本批只做协议拆分、facade 和 import boundary 收束。
- [x] 是否涉及数据库：否。
- [x] 是否涉及 IM 数据迁移、同步 job apply、群组关系回填或批量修复：否，因此本批不需要新增数据库备份。
- [x] 是否需要进入 Backlog / Deferred：否。

### Phase 4 Execution Notes

- [x] `MessagesRepository` 过渡命名已移除，避免继续演变成新的 Fat Repository。
- [x] `MessagesViewModel` 拆为 `ConversationRepository` 和 `MessageNotificationRepository` 两个依赖。
- [x] `MessagesCoordinator`、`MainTabView`、`MainTabCoordinator`、`MessageNotificationsViewModel`、`MessagesHomeView`、`UserProfileView` 已切换到更小 repository 注入。
- [x] 后端新增 `server/src/modules/im/`，作为 Tencent IM 当前主线 facade。
- [x] 后端 App route、BFF route、Squad service、Share invite service、auth controller 和 Tencent IM scripts 已改为从 `modules/im` 引入 IM 能力。
- [x] 新增 `server/src/services/openim/README.md`，明确 OpenIM 是 Legacy / Migration，不再承载新产品能力。
- [x] `ChatSettingsView` 已由直接依赖 `SocialService` 改为依赖 `ChatSettingsRepository`，`AppContainer`、`MainTabCoordinator` 和 UIKit chat settings route 已切到 repository 注入。
- [x] `ChatSettingsRepository` 当前是专属过渡边界，后续应继续拆成 direct chat settings、group settings、member management 等更小 repository / use case，避免成为新的 Fat Repository。
- [x] `SquadOfflineActivityView`、`SquadOfflineActivityHistoryView`、`SquadOfflineActivityStarterSheet` 和 `SquadOfflineActivityLocationUploader` 已从直接依赖 `SocialService` / `WebFeatureService` 切到 `SquadActivityRepository`、`LocationSyncRepository`、`DiscoverEventsRepository`。
- [x] Squad offline activity 明确归属线下协同 / location sync；IM group sync 仍归 Tencent IM / squad membership，不和 location upload 放在同一个 repository。
- [x] `RaverChatController` / `RaverChatDataProvider` 已切到 `ChatMessageRepository`，消息拉取、发送、媒体消息、业务卡片消息、撤回、删除不再直接依赖 `SocialService`。
- [x] `TencentUIKitChatView` 内的 Exyte chat ViewModel 已通过 `ChatMessageRepository` 处理已读与 typing，不再把消息状态同步直连到 `SocialService`。
- [x] `ChatMessageRepository` 当前只承接 chat message transport/read/typing，不承接会话列表、聊天设置、Squad activity、分享入口或 custom card registry，避免形成新的 Fat Repository。
- [x] iOS 新增 `Infrastructure/TencentIM/`，承接 `IMChatStore`、`ChatMessageSearchIndex`、`IMProbeLogger`、`IMStorageGovernance` 以及 `Media/ChatMediaTempFileStore`、`Media/RaverChatMediaResolver`。
- [x] OpenIM 旧兼容 `IMSession.swift` 已从 `Core` 移到 `Infrastructure/LegacyOpenIM/`，避免与 Tencent IM 当前主线混淆。
- [x] `TencentIMSession` 已从 `Core/AppState.swift` 拆到 `Infrastructure/TencentIM/Session/TencentIMSession.swift`，`TencentIMIdentity` 已拆到 `Infrastructure/TencentIM/TencentIMIdentity.swift`；`AppState.swift` 收回为应用状态与启动协调入口。
- [x] `TencentC2CReadReceiptEvent`、`TencentMessageRevocationEvent` 随 session 边界归位，read receipt / revocation publisher 不再依赖 `AppState.swift` 内部类型。
- [x] 拆分后已通过 `plutil -lint mobile/ios/RaverMVP/RaverMVP.xcodeproj/project.pbxproj`、`git diff --check` 和一次 iOS 增量 build：`xcodebuild -workspace mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/raver-xcodebuild-derived build`。
- [x] `TencentUIKitChatView` 的聊天卡片导航新增 `ChatCardRouteTarget` / `RecentChatCardRoute`，卡片点击从裸 `kind/id/perform` 收束为明确 route target，保留 event/rating event 同 ID 冲突防抖，不新增卡片类型或页面功能。
- [x] 聊天卡片主体复用 `chatCardButton` / `openChatCardRoute`，减少 custom card 点击、长按、路由样板散落；header、settings、profile、composer 等非卡片入口暂不纳入本批。
- [x] route target 批次已通过 `plutil -lint mobile/ios/RaverMVP/RaverMVP.xcodeproj/project.pbxproj`、`git diff --check` 和一次 iOS 增量 build：`xcodebuild -workspace mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/raver-xcodebuild-derived build`。
- [x] 新增 `ChatCustomCardCodec` / `ChatCustomCardWireType`，统一聊天自定义卡片 envelope / bare payload 解析；保留 rating event 不走 bare fallback、DJ bare payload 避免误判 Set、Squad offline activity 使用 ISO8601 decoder 等兼容行为。
- [x] `TencentUIKitChatView` 的 preview parser 和 message customData parser 已改为复用 codec，减少重复 `Envelope` 定义，为后续 custom card registry / renderer 拆分做准备。
- [x] custom card codec 批次已通过 `plutil -lint mobile/ios/RaverMVP/RaverMVP.xcodeproj/project.pbxproj`、`git diff --check` 和一次 iOS 增量 build：`xcodebuild -workspace mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/raver-xcodebuild-derived build`。
- [x] 本批未执行数据库 schema/data migration、backfill、projection rebuild、IM sync apply 或群组关系批量修复，因此不需要新增数据库备份记录。
- [x] 2026-05-12 用户确认真实运行 smoke 通过：Tencent IM bootstrap、conversation list、direct/group chat open、group member sync 均通过。

### Phase 5 Scope Check

- [x] 当前任务属于哪个 Phase：Phase 5 Feed / Events / Music 大领域收束。
- [x] 当前任务是否服务该 Phase 目标：是，先解决 Feed 侧 repository 过胖和职责边界不清。
- [x] 是否新增产品功能：否。
- [x] 是否进行目录大搬迁：否，本批只做协议边界和调用方依赖收窄。
- [x] 是否涉及数据库：否。
- [x] 是否涉及 schema migration、索引调整、数据回填、projection rebuild：否，因此本批不需要新增数据库备份。
- [x] 是否需要进入 Backlog / Deferred：否。

### Phase 5 Feed First Cut Plan

- [x] 盘点 `CircleFeedRepository` 当前职责：Feed stream、Post read/command、interaction、comments、media upload、IM share、feed event tracking 混在同一个协议。
- [x] 明确治理原则：不能把 `SocialService` 的 God Service 问题平移成新的 Fat Repository。
- [x] 拆出小协议：`FeedStreamRepository`、`PostReadRepository`、`PostCommandRepository`、`PostInteractionRepository`、`PostCommentRepository`、`PostMediaRepository`、`FeedEventTrackingRepository`。
- [x] `CircleFeedRepository` 降级为过渡组合协议；`CircleFeedRepositoryAdapter` 先保持行为不变，避免第一刀引入实现层风险。
- [x] `FeedViewModel` 改为依赖 Feed stream、post interaction、event tracking 三个小边界。
- [x] `ComposePostView` 改为依赖 post command 和 post media 两个小边界。
- [x] `PostDetailView` 改为依赖 post read、post interaction、post comment、event tracking 和 share message 边界。
- [x] `PostCardView` 分享发送改走 `ShareMessageRepository`，分享统计改走 `PostInteractionRepository`，不再直接拿 `CircleFeedRepository` 做 IM 发送。
- [x] `EventDetailView` 的 event-scoped feed 改为依赖 `FeedStreamRepository` / `PostInteractionRepository`。
- [x] 运行一次统一 iOS build，复用 `/tmp/raver-xcodebuild-derived`。
- [x] build 通过后删除 `/tmp/raver_phase5_feed_boundary_build.log`。
- [x] 根据 build 结果更新本 tracker。

Phase 5 Feed first cut 验证：

- [x] `git diff --check` 通过。
- [x] `plutil -lint mobile/ios/RaverMVP/RaverMVP.xcodeproj/project.pbxproj` 通过。
- [x] iOS 增量 build 通过：`xcodebuild -workspace mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/raver-xcodebuild-derived build`。
- [x] 已删除一次性日志：`/tmp/raver_phase5_feed_boundary_build.log`。
- [x] 本批未执行数据库 schema/data migration、backfill、索引调整或 projection rebuild，因此不需要新增数据库备份记录。

### Phase 5 Events First Cut Plan

- [x] 盘点 `DiscoverEventsRepository` 当前职责：event list/detail/command、recommended events、rating event/unit、live discussion、checkin、event media、post media、lineup image import、event related rating/sets 混在同一个协议。
- [x] 明确治理原则：先做协议边界和调用方依赖收窄，不做 `EventDetailView` 大拆分、不做目录大搬迁、不改 API 行为。
- [x] 当前任务是否涉及数据库：否。
- [x] 是否涉及 schema migration、索引调整、数据回填、projection rebuild：否，因此本批不需要新增数据库备份。
- [x] 拆出小协议：`EventListRepository`、`EventRecommendationRepository`、`EventReadRepository`、`EventCommandRepository`、`EventMediaRepository`、`EventDiscussionMediaRepository`、`EventLiveDiscussionRepository`、`EventRatingRepository`、`EventCheckinRepository`、`EventRelatedContentRepository`。
- [x] `DiscoverEventsRepository` 降级为过渡组合协议；`DiscoverEventsRepositoryAdapter` 先保持行为不变。
- [x] `EventsModuleViewModel` / use cases 改为依赖 event list/read/checkin 小边界。
- [x] `RecommendEventsViewModel` 改为依赖 recommendation/list/checkin 小边界。
- [x] `EventDetailView` 内部私有 repository getter 改为 event read/rating/checkin/related/command 小边界，不继续整页依赖 `DiscoverEventsRepository`。
- [x] 路由 loader/editor 入口先按小协议收窄可执行部分，复杂 editor 继续保留兼容入口，避免本批扩面。
- [x] 更新 iOS repository guide，记录 Events first cut 边界和 deferred 项。
- [x] 运行一次统一 iOS build，复用 `/tmp/raver-xcodebuild-derived`。
- [x] build 通过后删除 `/tmp/raver_phase5_events_boundary_build.log`。
- [x] 根据 build 结果更新本 tracker。

Phase 5 Events first cut 验证：

- [x] `git diff --check` 通过。
- [x] `plutil -lint mobile/ios/RaverMVP/RaverMVP.xcodeproj/project.pbxproj` 通过。
- [x] iOS 增量 build 通过：`xcodebuild -workspace mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/raver-xcodebuild-derived build`。
- [x] 已删除一次性日志：`/tmp/raver_phase5_events_boundary_build.log`。
- [x] 本批未执行数据库 schema/data migration、backfill、索引调整或 projection rebuild，因此不需要新增数据库备份记录。
- [x] Deferred：`EventEditorView`、Learn 关联活动、Squad 活动选择、MainTabView 内 rating/detail 复杂入口仍保留过渡组合协议，后续按更小批次拆分。

### Phase 5 Rating First Cut Plan

- [x] 盘点 Rating 当前职责分布：创建/详情读取挂在 `EventRatingRepository`，编辑/删除/图片上传挂在 `ProfileSocialRepository`，IM 分享挂在 `ShareMessageRepository`。
- [x] 明确治理原则：本批只收 `RatingEvent` / `RatingUnit` 数据读写边界，不碰 IM 分享、不改页面设计、不做数据库 migration。
- [x] 当前任务是否涉及数据库：否。
- [x] 是否涉及 schema migration、索引调整、数据回填、projection rebuild：否，因此本批不需要新增数据库备份。
- [x] 建立 `RatingRepository`，承接 rating event/unit 的 list/read/create/update/delete/media upload。
- [x] 让 `DiscoverEventsRepositoryAdapter` 继续实现 `RatingRepository`，保持 API 行为不变。
- [x] 将 `EventRatingRepository` 降级为兼容别名/过渡口径，不再作为长期目标命名。
- [x] `CircleRatingHubView` / `CircleRatingEventDetailView` 改走 `RatingRepository`，不再直连 `WebFeatureService`。
- [x] `CreateRatingEventSheet` / `CreateRatingEventFromEventSheet` / `CreateRatingUnitSheet` 的 rating media 或 event list 依赖收窄到 `RatingRepository` / `EventListRepository`。
- [x] `RatingEventEditorSheet` / `RatingUnitEditorSheet` 改走 `RatingRepository`，不再依赖 `ProfileSocialRepository`。
- [x] Profile rating editor loader 改用 `RatingRepository`。
- [x] 更新 iOS repository guide，记录 Rating first cut 边界和 deferred 项。
- [x] 运行一次统一 iOS build，复用 `/tmp/raver-xcodebuild-derived`。
- [x] build 通过后删除 `/tmp/raver_phase5_rating_boundary_build.log`。
- [x] 根据 build 结果更新本 tracker。

Phase 5 Rating first cut 验证：

- [x] `git diff --check` 通过。
- [x] `plutil -lint mobile/ios/RaverMVP/RaverMVP.xcodeproj/project.pbxproj` 通过。
- [x] iOS 增量 build 通过：`xcodebuild -workspace mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/raver-xcodebuild-derived build`。
- [x] 已删除一次性日志：`/tmp/raver_phase5_rating_boundary_build.log`。
- [x] 本批未执行数据库 schema/data migration、backfill、索引调整或 projection rebuild，因此不需要新增数据库备份记录。
- [x] Deferred：`MyPublishesView` 的 rating 删除仍通过 `ProfileSocialRepository` 聚合处理，因为它同时管理 DJSet/Event/Rating 发布物删除；后续拆 `ProfileContentRepository` 时统一收口。

### Phase 5 Music First Cut Plan

- [x] 盘点 Music 当前职责分布：`DiscoverDJsRepository` 混有 DJ list/detail/follow、DJ events/sets/rating units、ranking、Spotify/Discogs/manual import、DJ media upload；`DiscoverSetsRepository` 混有 Set list/detail/comment、Tracklist、Set media、Set command、event binding。
- [x] 明确治理原则：本批只做协议边界和低风险调用方依赖收窄，不做 DJ/Set 页面大拆分、不改 API、不做数据库 migration。
- [x] 当前任务是否涉及数据库：否。
- [x] 是否涉及 schema migration、索引调整、数据回填、projection rebuild：否，因此本批不需要新增数据库备份。
- [x] 拆出 DJ 小协议：`DJListRepository`、`DJReadRepository`、`DJRelationRepository`、`DJLinkedContentRepository`、`DJCommandRepository`、`DJRankingRepository`、`DJImportRepository`、`DJMediaRepository`。
- [x] 拆出 Set 小协议：`SetListRepository`、`SetReadRepository`、`SetCommentRepository`、`SetCommandRepository`、`SetMediaRepository`、`TracklistRepository`、`SetEventLookupRepository`。
- [x] `DiscoverDJsRepository` / `DiscoverSetsRepository` 降级为过渡组合协议；adapter 保持行为不变。
- [x] `DJsModuleViewModel` 改为依赖 `DJListRepository`。
- [x] `SetsModuleView` / `DJSetDetailView` / `UploadTracklistSheet` / `DJSetEditorView` / `SetEventBindingSheet` / `TracklistEditorView` 的 repository getter 按小协议收窄。
- [x] Profile / Discover set editor loader 改用 `SetReadRepository`。
- [x] 更新 iOS repository guide，记录 Music first cut 边界和 deferred 项。
- [x] 运行一次统一 iOS build，复用 `/tmp/raver-xcodebuild-derived`。
- [x] build 通过后删除 `/tmp/raver_phase5_music_boundary_build.log`。
- [x] 根据 build 结果更新本 tracker。

Phase 5 Music first cut 验证：

- [x] `git diff --check` 通过。
- [x] `plutil -lint mobile/ios/RaverMVP/RaverMVP.xcodeproj/project.pbxproj` 通过。
- [x] iOS 增量 build 通过：`xcodebuild -workspace mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/raver-xcodebuild-derived build`。
- [x] 已删除一次性日志：`/tmp/raver_phase5_music_boundary_build.log`。
- [x] 本批未执行数据库 schema/data migration、backfill、索引调整或 projection rebuild，因此不需要新增数据库备份记录。
- [x] Deferred：DJ detail / import 大页面、Learn ranking 页面、EventEditor lineup DJ picker 仍保留过渡组合协议，后续按 DJ detail、DJ import、Ranking 三个小批次继续收窄。

### Phase 5 DJ Detail First Cut Plan

- [x] 盘点 `DJDetailView` 当前职责：DJ 详情读取、关联 Set/Event/RatingUnit/Checkin count、关注关系、Spotify import、DJ 编辑、DJ media upload 都通过 `DiscoverDJsRepository` 组合协议。
- [x] 明确治理原则：本批只收窄 `DJDetailView` 内部 repository getter，不拆 UI、不改 import 流程、不做数据库 migration。
- [x] 当前任务是否涉及数据库：否。
- [x] 是否涉及 schema migration、索引调整、数据回填、projection rebuild：否，因此本批不需要新增数据库备份。
- [x] `DJDetailView` 改用 `DJReadRepository`、`DJLinkedContentRepository`、`DJRelationRepository`、`DJImportRepository`、`DJCommandRepository`、`DJMediaRepository`。
- [x] `DJDetailView` 的 load/cache/reload/follow/import/edit/media 路径分别切到对应小协议。
- [x] 保留 DJ import 大页面结构，不做 UI 或流程重构。
- [x] 更新 tracker 和必要文档，记录 DJ import / Ranking / EventEditor lineup picker deferred。
- [x] 运行一次统一 iOS build，复用 `/tmp/raver-xcodebuild-derived`。
- [x] build 通过后删除 `/tmp/raver_phase5_dj_detail_boundary_build.log`。
- [x] 根据 build 结果更新本 tracker。

Phase 5 DJ Detail first cut 验证：

- [x] `git diff --check` 通过。
- [x] `plutil -lint mobile/ios/RaverMVP/RaverMVP.xcodeproj/project.pbxproj` 通过。
- [x] iOS 增量 build 通过：`xcodebuild -workspace mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/raver-xcodebuild-derived build`。
- [x] 已删除一次性日志：`/tmp/raver_phase5_dj_detail_boundary_build.log`。
- [x] 本批未执行数据库 schema/data migration、backfill、索引调整或 projection rebuild，因此不需要新增数据库备份记录。
- [x] Deferred：`DJsModuleView` 顶部 DJ import sheet、Learn ranking 页面、EventEditor lineup DJ picker 仍保留过渡组合协议，后续按小批次继续收窄。

### Phase 5 DJ Import First Cut Plan

- [x] 盘点 `DJsModuleView` 顶部 import sheet 当前职责：Spotify 搜索、Discogs 搜索、Discogs 详情读取、Spotify/Discogs/manual 导入、manual avatar/banner 上传都通过 `DiscoverDJsRepository` 组合协议。
- [x] 明确治理原则：本批只收窄 import sheet 的 repository getter，不改导入 UI、不改导入流程、不做数据库 migration。
- [x] 当前任务是否涉及数据库：否。
- [x] 是否涉及 schema migration、索引调整、数据回填、projection rebuild：否，因此本批不需要新增数据库备份。
- [x] `DJsModuleView` 顶部 import sheet 改用 `DJImportRepository` 承接搜索、详情读取和导入提交。
- [x] `DJsModuleView` 顶部 manual avatar/banner 上传改用 `DJMediaRepository`。
- [x] 验证 `DJsModuleView` import sheet 范围内无 `private var repository: DiscoverDJsRepository` / `repository.` 残留。
- [x] 运行一次统一 iOS build，复用 `/tmp/raver-xcodebuild-derived`。
- [x] build 通过后删除 `/tmp/raver_phase5_dj_import_boundary_build.log`。
- [x] 根据 build 结果更新本 tracker。

Phase 5 DJ Import first cut 验证：

- [x] `git diff --check` 通过。
- [x] `plutil -lint mobile/ios/RaverMVP/RaverMVP.xcodeproj/project.pbxproj` 通过。
- [x] `rg "private var repository: DiscoverDJsRepository|repository\\." mobile/ios/RaverMVP/RaverMVP/Features/Discover/DJs/Views/DJsModuleView.swift -n` 无残留。
- [x] iOS 增量 build 通过：`xcodebuild -workspace mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/raver-xcodebuild-derived build`。
- [x] 已删除一次性日志：`/tmp/raver_phase5_dj_import_boundary_build.log`。
- [x] 本批未执行数据库 schema/data migration、backfill、索引调整或 projection rebuild，因此不需要新增数据库备份记录。
- [x] Deferred：Learn ranking 页面、EventEditor lineup DJ picker 仍保留过渡组合协议，后续按 Ranking / Event editor picker 小批次继续收窄。

### Phase 5 DJ Residual Boundary Plan

- [x] 盘点剩余 `DiscoverDJsRepository` 调用点：Learn 榜单、Ranking detail、Circle ID DJ picker、EventEditor lineup DJ 匹配仍可收窄到已有小协议。
- [x] 明确治理原则：本批只替换 repository getter 和调用方依赖，不改榜单 UI、不改 Circle ID 流程、不改 EventEditor lineup 逻辑。
- [x] 当前任务是否涉及数据库：否。
- [x] 是否涉及 schema migration、索引调整、数据回填、projection rebuild：否，因此本批不需要新增数据库备份。
- [x] `LearnModuleView` / `RankingBoardDetailView` 改用 `DJRankingRepository`。
- [x] `CircleIDDJPickerSheet` 改用 `DJListRepository`。
- [x] `EventEditorView` lineup DJ 匹配改用 `DJListRepository`。
- [x] 更新 iOS repository guide，移除 Circle ID / lineup picker 继续依赖宽 `DiscoverDJsRepository` 的说明。
- [x] 验证目标范围内无不必要的 `DiscoverDJsRepository` 残留。
- [x] 运行一次统一 iOS build，复用 `/tmp/raver-xcodebuild-derived`。
- [x] build 通过后删除 `/tmp/raver_phase5_dj_residual_boundary_build.log`。
- [x] 根据 build 结果更新本 tracker。

Phase 5 DJ Residual boundary 验证：

- [x] `git diff --check` 通过。
- [x] `plutil -lint mobile/ios/RaverMVP/RaverMVP.xcodeproj/project.pbxproj` 通过。
- [x] 目标范围 `DiscoverDJsRepository` 宽协议命中已清理或归类为过渡入口。
- [x] iOS 增量 build 通过：`xcodebuild -workspace mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/raver-xcodebuild-derived build`。
- [x] 已删除一次性日志：`/tmp/raver_phase5_dj_residual_boundary_build.log`。
- [x] 本批未执行数据库 schema/data migration、backfill、索引调整或 projection rebuild，因此不需要新增数据库备份记录。
- [x] Deferred：`DiscoverDJsRepository` 仍作为 transition composition protocol 和 adapter 类型保留，后续等调用方稳定后再做物理目录与兼容协议删除。

### Phase 5 Events Residual Boundary Plan

- [x] 盘点剩余 `DiscoverEventsRepository` 调用点：Circle ID event picker、Learn festival related events、Squad offline activity event selector、DJ checkin event binding、EventEditor create/update/media/import 仍可收窄到已有小协议。
- [x] 明确治理原则：本批只替换 repository getter / 参数类型，不改活动创建 UI、不改小队活动流程、不改打卡绑定流程、不做数据库 migration。
- [x] 当前任务是否涉及数据库：否。
- [x] 是否涉及 schema migration、索引调整、数据回填、projection rebuild：否，因此本批不需要新增数据库备份。
- [x] Circle ID event picker 改用 `EventListRepository`。
- [x] Learn festival related events 改用 `EventListRepository`。
- [x] Squad offline activity starter 改用 `EventListRepository`，构造端继续复用现有 adapter 实例。
- [x] DJ checkin event binding 按 `EventListRepository` / `EventCheckinRepository` 拆分。
- [x] EventEditor create/update/upload/import 按 `EventCommandRepository` / `EventMediaRepository` 拆分。
- [x] 更新 iOS repository guide，记录 Event picker / selector 不再依赖宽 `DiscoverEventsRepository`。
- [x] 验证目标范围内无不必要的 `DiscoverEventsRepository` 残留。
- [x] 运行一次统一 iOS build，复用 `/tmp/raver-xcodebuild-derived`。
- [x] build 通过后删除 `/tmp/raver_phase5_events_residual_boundary_build.log`。
- [x] 根据 build 结果更新本 tracker。

Phase 5 Events residual boundary 验证：

- [x] `git diff --check` 通过。
- [x] `plutil -lint mobile/ios/RaverMVP/RaverMVP.xcodeproj/project.pbxproj` 通过。
- [x] 目标范围 `DiscoverEventsRepository` 宽协议命中已清理或归类为过渡入口。
- [x] iOS 增量 build 通过：`xcodebuild -workspace mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/raver-xcodebuild-derived build`。
- [x] 已删除一次性日志：`/tmp/raver_phase5_events_residual_boundary_build.log`。
- [x] 本批未执行数据库 schema/data migration、backfill、索引调整或 projection rebuild，因此不需要新增数据库备份记录。
- [x] Deferred：`DiscoverEventsRepository` 仍作为 transition composition protocol 和 adapter 类型保留；Event detail / recommend / loader 兼容构造可后续单独清理。

### Phase 5 Rating Compatibility Cleanup Plan

- [x] 盘点 `EventRatingRepository` 残留：当前只剩兼容别名、`DiscoverEventsRepository` 组合协议继承和 `EventDetailView` getter 使用。
- [x] 明确治理原则：本批只删除兼容命名，不改 rating API、不改 UI、不做数据库 migration。
- [x] 当前任务是否涉及数据库：否。
- [x] 是否涉及 schema migration、索引调整、数据回填、projection rebuild：否，因此本批不需要新增数据库备份。
- [x] `DiscoverEventsRepository` 直接继承 `RatingRepository`。
- [x] `EventDetailView` 改用 `RatingRepository` getter。
- [x] 删除 `EventRatingRepository` 兼容别名和 guide 中的兼容说明。
- [x] 验证 `EventRatingRepository` 命名无代码残留。
- [x] 运行一次统一 iOS build，复用 `/tmp/raver-xcodebuild-derived`。
- [x] build 通过后删除 `/tmp/raver_phase5_rating_compat_cleanup_build.log`。
- [x] 根据 build 结果更新本 tracker。

Phase 5 Rating compatibility cleanup 验证：

- [x] `git diff --check` 通过。
- [x] `plutil -lint mobile/ios/RaverMVP/RaverMVP.xcodeproj/project.pbxproj` 通过。
- [x] `EventRatingRepository` 代码命中清零。
- [x] iOS 增量 build 通过：`xcodebuild -workspace mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/raver-xcodebuild-derived build`。
- [x] 已删除一次性日志：`/tmp/raver_phase5_rating_compat_cleanup_build.log`。
- [x] 本批未执行数据库 schema/data migration、backfill、索引调整或 projection rebuild，因此不需要新增数据库备份记录。

### Phase 5 Profile Repository Split First Cut Plan

- [x] 盘点 `ProfileSocialRepository` 当前职责：用户资料 / follow、个人动态流、互动历史、MySaves、MyPublishes、MyCheckins v2、rating editor legacy、头像上传混在同一个过渡协议。
- [x] 明确治理原则：本批只拆协议和调用方依赖，adapter 暂时继续复用现有 `SocialService` / `WebFeatureService`，不改 UI、不改 API、不做数据库 migration。
- [x] 当前任务是否涉及数据库：否。
- [x] 是否涉及 schema migration、索引调整、数据回填、projection rebuild：否，因此本批不需要新增数据库备份。
- [x] 新增 `ProfileUserRepository`，承接用户资料、follow list、follow toggle、头像上传、资料更新。
- [x] 新增 `ProfileContentRepository`，承接用户动态、互动历史、MySaves、MyPublishes 和发布物删除。
- [x] 新增 `ProfileCheckinRepository`，承接用户打卡列表、MyCheckins v2 overview/timeline/gallery 和删除打卡。
- [x] `ProfileSocialRepository` 降级为 `ProfileUserRepository & ProfileContentRepository & ProfileCheckinRepository` 的过渡组合协议。
- [x] `ProfileViewModel` / `LoadMyProfileDashboardUseCase` 按 user/content/checkin 小协议拆分依赖。
- [x] `UserProfileViewModel` 按 user/content/checkin 小协议拆分依赖。
- [x] `MyPublishesViewModel` / `MyPublishesView` 改用 `ProfileUserRepository` + `ProfileContentRepository`。
- [x] `MySavesViewModel` / `MySavesView` 改用 `ProfileContentRepository` + `ProfileCheckinRepository`。
- [x] `MyCheckinsViewModel` / `MyCheckinsView` 改用 `ProfileCheckinRepository`。
- [x] `CurrentUserProfileLoaderView` / Settings loader 改用 `ProfileUserRepository`。
- [x] 更新 iOS repository guide，记录 Profile first cut 边界和 deferred 项。
- [x] 运行一次统一 iOS build，复用 `/tmp/raver-xcodebuild-derived`。
- [x] build 通过后删除 `/tmp/raver_phase5_profile_repository_split_build.log`。
- [x] 根据 build 结果更新本 tracker。

Phase 5 Profile repository split first cut 验证：

- [x] `git diff --check` 通过。
- [x] `plutil -lint mobile/ios/RaverMVP/RaverMVP.xcodeproj/project.pbxproj` 通过。
- [x] 目标页面不再直接依赖 `ProfileSocialRepository` 处理 my publishes / my saves / my checkins。
- [x] iOS 增量 build 通过：`xcodebuild -workspace mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/raver-xcodebuild-derived build`。
- [x] 已删除一次性日志：`/tmp/raver_phase5_profile_repository_split_build.log`。
- [x] 本批未执行数据库 schema/data migration、backfill、索引调整或 projection rebuild，因此不需要新增数据库备份记录。
- [x] Deferred：`ProfileSocialRepositoryAdapter` 仍作为过渡 adapter 实现多个小协议；后续再做物理目录拆分、adapter 拆分和 rating legacy 方法删除。

### Phase 5 Profile Rating Legacy Cleanup Plan

- [x] 盘点 `ProfileRatingLegacyRepository` 残留：rating editor 页面已使用 `RatingRepository`，Profile 侧只剩 legacy 协议和 adapter 转发方法。
- [x] 明确治理原则：本批只删除 Profile adapter 的 rating editor legacy 能力，不改 rating 页面、不改 API、不做数据库 migration。
- [x] 当前任务是否涉及数据库：否。
- [x] 是否涉及 schema migration、索引调整、数据回填、projection rebuild：否，因此本批不需要新增数据库备份。
- [x] 删除 `ProfileRatingLegacyRepository`。
- [x] `ProfileSocialRepository` 不再继承 rating legacy 能力。
- [x] 删除 `ProfileSocialRepositoryAdapter` 中 rating image upload / rating update 的 legacy 转发方法。
- [x] 更新 iOS repository guide，记录 Profile adapter 不再承接 rating editor。
- [x] 验证 `ProfileRatingLegacyRepository` 代码命中清零。
- [x] 运行一次统一 iOS build，复用 `/tmp/raver-xcodebuild-derived`。
- [x] build 通过后删除 `/tmp/raver_phase5_profile_rating_legacy_cleanup_build.log`。
- [x] 根据 build 结果更新本 tracker。

Phase 5 Profile rating legacy cleanup 验证：

- [x] `git diff --check` 通过。
- [x] `plutil -lint mobile/ios/RaverMVP/RaverMVP.xcodeproj/project.pbxproj` 通过。
- [x] `ProfileRatingLegacyRepository` 代码命中清零。
- [x] iOS 增量 build 通过：`xcodebuild -workspace mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/raver-xcodebuild-derived build`。
- [x] 已删除一次性日志：`/tmp/raver_phase5_profile_rating_legacy_cleanup_build.log`。
- [x] 本批未执行数据库 schema/data migration、backfill、索引调整或 projection rebuild，因此不需要新增数据库备份记录。

### Phase 5 Profile Adapter Physical Split Plan

- [x] 盘点 `ProfileSocialRepositoryAdapter` 当前实现：即使调用方已拆小协议，adapter 仍同时持有 user/content/checkin 三类实现。
- [x] 明确治理原则：本批只拆 adapter 实现和 AppContainer 出口，不改页面、不改 API、不做数据库 migration。
- [x] 当前任务是否涉及数据库：否。
- [x] 是否涉及 schema migration、索引调整、数据回填、projection rebuild：否，因此本批不需要新增数据库备份。
- [x] 新增 `ProfileUserRepositoryAdapter`，仅持有 `SocialService`。
- [x] 新增 `ProfileContentRepositoryAdapter`，持有 `SocialService` + `WebFeatureService`。
- [x] 新增 `ProfileCheckinRepositoryAdapter`，仅持有 `WebFeatureService`。
- [x] 删除 `ProfileSocialRepository` 组合协议和 `ProfileSocialRepositoryAdapter`。
- [x] `AppContainer` 的 `profileUserRepository` / `profileContentRepository` / `profileCheckinRepository` 直接返回对应小 adapter。
- [x] 更新 iOS repository guide，记录 Profile adapter 已从 transition composition 进入物理 split。
- [x] 验证 `ProfileSocialRepository` / `profileSocialRepository` 代码命中清零。
- [x] 运行一次统一 iOS build，复用 `/tmp/raver-xcodebuild-derived`。
- [x] build 通过后删除 `/tmp/raver_phase5_profile_adapter_split_build.log`。
- [x] 根据 build 结果更新本 tracker。

Phase 5 Profile adapter physical split 验证：

- [x] `git diff --check` 通过。
- [x] `plutil -lint mobile/ios/RaverMVP/RaverMVP.xcodeproj/project.pbxproj` 通过。
- [x] `ProfileSocialRepository` / `profileSocialRepository` 代码命中清零。
- [x] iOS 增量 build 通过：`xcodebuild -workspace mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/raver-xcodebuild-derived build`。
- [x] 已删除一次性日志：`/tmp/raver_phase5_profile_adapter_split_build.log`。
- [x] 本批未执行数据库 schema/data migration、backfill、索引调整或 projection rebuild，因此不需要新增数据库备份记录。

### Phase 5 Rating Adapter Physical Split Plan

- [x] 盘点 `RatingRepository` 当前实现：协议已独立，但实现仍由 `DiscoverEventsRepositoryAdapter` 承接，导致 Events adapter 继续暴露 rating event/unit 创建、编辑、删除、评论和媒体上传能力。
- [x] 明确治理原则：本批只拆 Rating adapter 实现和 AppContainer 出口，不改 rating UI、不改 API、不做数据库 migration。
- [x] 当前任务是否涉及数据库：否。
- [x] 是否涉及 schema migration、索引调整、数据回填、projection rebuild：否，因此本批不需要新增数据库备份。
- [x] 新增 `RatingRepositoryAdapter`，仅持有 `WebFeatureService`。
- [x] `DiscoverEventsRepository` 不再继承 `RatingRepository`。
- [x] `DiscoverEventsRepositoryAdapter` 移除 rating event/unit list/read/create/update/delete、活动关联 rating 读取、rating comment submit 和 rating image upload 实现。
- [x] `AppContainer` 新增 `ratingRepository` 出口。
- [x] `CircleRatingHubView`、`CircleRatingEventDetailView`、`CircleRatingUnitDetailView`、rating 创建 sheet、Profile rating editor loader 和 Circle/MainTab rating 创建路由切到 `appContainer.ratingRepository`。
- [x] 更新 iOS repository guide，记录 `RatingRepositoryAdapter` 为当前适配来源，`DiscoverEventsRepository` 不再承接 rating 能力。
- [x] 验证 `RatingRepository` 不再通过 `appContainer.discoverEventsRepository` 注入。
- [x] 验证 Event 小协议未误接到 `appContainer.ratingRepository`。
- [x] 运行一次统一 iOS build，复用 `/tmp/raver-xcodebuild-derived`。
- [x] build 通过后删除 `/tmp/raver_phase5_rating_adapter_split_build.log`。
- [x] 根据 build 结果更新本 tracker。

Phase 5 Rating adapter physical split 验证：

- [x] `git diff --check` 通过。
- [x] `plutil -lint mobile/ios/RaverMVP/RaverMVP.xcodeproj/project.pbxproj` 通过。
- [x] `RatingRepository` 通过 `appContainer.discoverEventsRepository` 注入命中清零。
- [x] Event 小协议误接 `appContainer.ratingRepository` 命中清零。
- [x] iOS 增量 build 通过：`xcodebuild -workspace mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/raver-xcodebuild-derived build`。
- [x] 已删除一次性日志：`/tmp/raver_phase5_rating_adapter_split_build.log`。
- [x] 本批未执行数据库 schema/data migration、backfill、索引调整或 projection rebuild，因此不需要新增数据库备份记录。

### Phase 5 Events Adapter Physical Split Plan

- [x] 盘点 `DiscoverEventsRepository` 当前实现：Rating 已移出，但 Events adapter 仍同时承接 list/recommendation/read/live discussion/command/media/checkin/related content 多类能力。
- [x] 明确治理原则：本批只拆 Events 小 adapter 实现和 AppContainer 出口，不改活动 UI、不改 API、不做数据库 migration。
- [x] 当前任务是否涉及数据库：否。
- [x] 是否涉及 schema migration、索引调整、数据回填、projection rebuild：否，因此本批不需要新增数据库备份。
- [x] 新增 `EventListRepositoryAdapter`、`EventRecommendationRepositoryAdapter`、`EventReadRepositoryAdapter`、`EventLiveDiscussionRepositoryAdapter`、`EventCommandRepositoryAdapter`、`EventMediaRepositoryAdapter`、`EventCheckinRepositoryAdapter`、`EventRelatedContentRepositoryAdapter`。
- [x] `AppContainer` 新增 event list / recommendation / read / live discussion / command / media / discussion media / checkin / related content 小出口。
- [x] Discover events root / recommend root 改为用小 repository 构造 ViewModel。
- [x] MainTab / Discover route 中 event editor loader、event live discussion、event route loader 改为小 repository 注入。
- [x] `EventDetailView` 内部 event read/checkin/related/command getter 改走小出口。
- [x] `EventEditorView` 内部 event list/checkin/command/media getter 改走小出口。
- [x] Learn 关联活动和 MainTab 中 Circle ID / rating import event picker 改走 `eventListRepository` 小出口。
- [x] 更新 iOS repository guide，记录 Events adapter 已从 transition composition 进入 physical split。
- [x] 验证页面 / 路由层 `appContainer.discoverEventsRepository` 命中清零。
- [x] 运行一次统一 iOS build，复用 `/tmp/raver-xcodebuild-derived`。
- [x] build 通过后删除 `/tmp/raver_phase5_events_adapter_split_build.log`。
- [x] 根据 build 结果更新本 tracker。

Phase 5 Events adapter physical split 验证：

- [x] `git diff --check` 通过。
- [x] `plutil -lint mobile/ios/RaverMVP/RaverMVP.xcodeproj/project.pbxproj` 通过。
- [x] 页面 / 路由层 `appContainer.discoverEventsRepository` 命中清零；仅允许 `AppContainer` 兼容出口保留。
- [x] iOS 增量 build 通过：`xcodebuild -workspace mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/raver-xcodebuild-derived build`。
- [x] 已删除一次性日志：`/tmp/raver_phase5_events_adapter_split_build.log`。
- [x] 本批未执行数据库 schema/data migration、backfill、索引调整或 projection rebuild，因此不需要新增数据库备份记录。

### Phase 5 Music Adapter Physical Split Plan

- [x] 盘点 `DiscoverDJsRepository` / `DiscoverSetsRepository` 当前实现：调用方已按小协议声明依赖，但实现和 AppContainer 出口仍集中在宽组合 adapter。
- [x] 明确治理原则：本批只拆 DJ / Set 小 adapter 实现和 AppContainer 出口，不改 DJ/Set UI、不改 API、不做数据库 migration。
- [x] 当前任务是否涉及数据库：否。
- [x] 是否涉及 schema migration、索引调整、数据回填、projection rebuild：否，因此本批不需要新增数据库备份。
- [x] 新增 DJ 小 adapter：`DJListRepositoryAdapter`、`DJReadRepositoryAdapter`、`DJLinkedContentRepositoryAdapter`、`DJRelationRepositoryAdapter`、`DJCommandRepositoryAdapter`、`DJRankingRepositoryAdapter`、`DJImportRepositoryAdapter`、`DJMediaRepositoryAdapter`。
- [x] 新增 Set 小 adapter：`SetListRepositoryAdapter`、`SetReadRepositoryAdapter`、`SetCommentRepositoryAdapter`、`SetCommandRepositoryAdapter`、`TracklistRepositoryAdapter`、`SetEventLookupRepositoryAdapter`、`SetMediaRepositoryAdapter`。
- [x] `AppContainer` 新增 DJ / Set / Tracklist 小出口。
- [x] `DJsModuleView`、`DJDetailView`、Learn ranking、Circle ID DJ picker、EventEditor lineup DJ 匹配改走 DJ 小出口。
- [x] `SetsModuleView`、`DJSetDetailView`、Tracklist upload/editor、Set editor、Set event binding、Profile/Discover set editor loader 改走 Set / Tracklist 小出口。
- [x] 更新 iOS repository guide，记录 Music adapter 已从 transition composition 进入 physical split。
- [x] 验证页面 / 路由层 `appContainer.discoverDJsRepository` 和 `appContainer.discoverSetsRepository` 命中清零。
- [x] 运行一次统一 iOS build，复用 `/tmp/raver-xcodebuild-derived`。
- [x] build 通过后删除 `/tmp/raver_phase5_music_adapter_split_build.log`。
- [x] 根据 build 结果更新本 tracker。

Phase 5 Music adapter physical split 验证：

- [x] `git diff --check` 通过。
- [x] `plutil -lint mobile/ios/RaverMVP/RaverMVP.xcodeproj/project.pbxproj` 通过。
- [x] 页面 / 路由层 `appContainer.discoverDJsRepository` 和 `appContainer.discoverSetsRepository` 命中清零；仅允许 `AppContainer` 兼容出口保留。
- [x] iOS 增量 build 通过：`xcodebuild -workspace mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/raver-xcodebuild-derived build`。
- [x] 已删除一次性日志：`/tmp/raver_phase5_music_adapter_split_build.log`。
- [x] 本批未执行数据库 schema/data migration、backfill、索引调整或 projection rebuild，因此不需要新增数据库备份记录。

### Phase 5 Feed Adapter Physical Split Plan

- [x] 盘点 `CircleFeedRepository` 当前实现：调用方已按 Feed/Post 小协议声明依赖，但实现和 AppContainer 出口仍集中在宽组合 adapter。
- [x] 明确治理原则：本批只拆 Feed/Post 小 adapter 实现和 AppContainer 出口，不改 Feed UI、不改 API、不做数据库 migration。
- [x] 当前任务是否涉及数据库：否。
- [x] 是否涉及 schema migration、索引调整、数据回填、projection rebuild：否，因此本批不需要新增数据库备份。
- [x] 新增 `FeedStreamRepositoryAdapter`、`PostReadRepositoryAdapter`、`PostCommandRepositoryAdapter`、`PostInteractionRepositoryAdapter`、`FeedEventTrackingRepositoryAdapter`、`PostCommentRepositoryAdapter`、`PostMediaRepositoryAdapter`。
- [x] `AppContainer` 新增 Feed/Post 小出口。
- [x] `FeedView`、`PostCardView`、`EventDetailView` 的 Feed/Post 依赖改走小出口。
- [x] MainTab / Circle route 中 post create、event post create、post edit、post detail loader 改走小出口。
- [x] 更新 iOS repository guide，记录 Feed adapter 已从 transition composition 进入 physical split。
- [x] 验证页面 / 路由层 `appContainer.circleFeedRepository` 命中清零。
- [x] 运行一次统一 iOS build，复用 `/tmp/raver-xcodebuild-derived`。
- [x] build 通过后删除 `/tmp/raver_phase5_feed_adapter_split_build.log`。
- [x] 根据 build 结果更新本 tracker。

Phase 5 Feed adapter physical split 验证：

- [x] `git diff --check` 通过。
- [x] `plutil -lint mobile/ios/RaverMVP/RaverMVP.xcodeproj/project.pbxproj` 通过。
- [x] 页面 / 路由层 `appContainer.circleFeedRepository` 命中清零；仅允许 `AppContainer` 兼容出口保留。
- [x] iOS 增量 build 通过：`xcodebuild -workspace mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/raver-xcodebuild-derived build`。
- [x] 已删除一次性日志：`/tmp/raver_phase5_feed_adapter_split_build.log`。
- [x] 本批未执行数据库 schema/data migration、backfill、索引调整或 projection rebuild，因此不需要新增数据库备份记录。

### Phase 5 Repository Compatibility Cleanup Plan

- [x] 盘点宽组合 repository 残留：`ProfileSocialRepository`、`DiscoverEventsRepository`、`DiscoverDJsRepository`、`DiscoverSetsRepository`、`CircleFeedRepository`。
- [x] 明确治理原则：小 repository adapter 已经完成 physical split 后，不再保留宽组合协议作为 active compatibility shell；历史日志可以保留，当前代码入口必须收敛到小协议。
- [x] 当前任务是否涉及数据库：否。
- [x] 是否涉及 schema migration、索引调整、数据回填、projection rebuild、IM sync apply、群组关系批量修复：否，因此本批不需要新增数据库备份。
- [x] 移除 `ProfileSocialRepository` 兼容协议、adapter 和 `AppContainer.profileSocialRepository` 旧出口。
- [x] 移除 `DiscoverEventsRepository` 兼容协议、adapter、`AppContainer.discoverEventsRepository` 旧出口，以及 Events 相关兼容 init。
- [x] 移除 `CircleFeedRepository` 兼容协议、adapter、`AppContainer.circleFeedRepository` 旧出口，以及 Feed 相关兼容 init。
- [x] 移除 `DiscoverDJsRepository` / `DiscoverSetsRepository` 兼容协议、adapter 和 `AppContainer.discoverDJsRepository` / `AppContainer.discoverSetsRepository` 旧出口。
- [x] 验证宽组合 repository 名称和旧 AppContainer 出口在 Swift 代码中清零。
- [x] 验证 `git diff --check` 通过。
- [x] 验证 `plutil -lint mobile/ios/RaverMVP/RaverMVP.xcodeproj/project.pbxproj` 通过。
- [x] 运行一次统一 iOS build，复用 `/tmp/raver-xcodebuild-derived`。
- [x] build 通过后删除 `/tmp/raver_phase5_closure_cleanup_build.log`，不删除 `/tmp/raver-xcodebuild-derived`。
- [x] 根据 build 结果更新本 tracker 和 iOS repository guide。

Phase 5 compatibility cleanup 验证：

- [x] `rg` 验证宽组合 repository / AppContainer 旧出口无活跃代码残留。
- [x] iOS 增量 build 通过：`xcodebuild -workspace mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/raver-xcodebuild-derived build`。
- [x] 已删除一次性日志：`/tmp/raver_phase5_closure_cleanup_build.log`。
- [x] 本批未执行数据库 schema/data migration、backfill、索引调整、projection rebuild、IM sync apply 或群组关系批量修复，因此不需要新增数据库备份记录。

### Phase 5 Backend Content Module Facade Plan

- [x] 盘点 Phase 5 顶层未勾项：iOS Discover 拆分已完成；剩余核心缺口是后端 `feed` / `events` / `music` module 尚未建立 current facade。
- [x] 明确治理原则：本批只建立后端内容域 module facade 和 route import boundary，不物理搬迁 controller/service，不改 API，不做数据库 migration。
- [x] 当前任务是否涉及数据库：否。
- [x] 是否涉及 schema migration、索引调整、数据回填、projection rebuild：否，因此本批不需要新增数据库备份。
- [x] 新增 `server/src/modules/feed/`，先 re-export `comment.service`，并记录 BFF feed/post 仍是 compat 内联逻辑。
- [x] 新增 `server/src/modules/events/`，re-export event / lineup / timetable controller。
- [x] 新增 `server/src/modules/music/`，re-export DJ controller、DJSet service、music search、DJ aggregator、Spotify/Discogs/SoundCloud provider service。
- [x] `comment.routes.ts` 改从 `modules/feed` 引入 `commentService`。
- [x] `event.routes.ts` 改从 `modules/events` 引入 event / lineup / timetable controller。
- [x] `dj.routes.ts`、`djset.routes.ts`、`music.routes.ts`、`dj-aggregator.routes.ts` 改从 `modules/music` 引入对应 controller/service。
- [x] `bff.web.routes.ts` 中 DJSet / comment / external artist provider import 改从 `modules/music` / `modules/feed` 引入；大段 BFF 聚合逻辑暂不拆，避免扩面。
- [x] 更新 backend ownership 文档和 tracker。
- [x] 运行 `cd server && pnpm build`。
- [x] build 通过后删除一次性日志 `/tmp/raver_phase5_backend_content_modules_build.log`。

Phase 5 backend content module facade 验证：

- [x] `server/src/modules/feed` / `events` / `music` facade 存在。
- [x] 目标 routes 不再直接从旧 `services/comment.service`、`services/djset.service`、`services/music-search.service`、`services/dj-aggregator.service` 或 event/music controller 文件引入；`dj.controller` 内部仍复用 Spotify provider 作为 module facade 内部 compat implementation。
- [x] 后端 build 通过：`cd server && pnpm build`。
- [x] 已删除一次性日志：`/tmp/raver_phase5_backend_content_modules_build.log`。
- [x] 本批未执行数据库 schema/data migration、backfill、索引调整或 projection rebuild，因此不需要新增数据库备份记录。

### Phase 5 FeedEvent Telemetry Service Extraction Plan

- [x] 盘点 `FeedEvent` / Post interactions / comment tree：Post interactions 与评论链路涉及发布、点赞、收藏、转发、分享、隐藏、通知和 hydrate 映射，暂不一刀硬搬；`FeedEvent` telemetry 边界独立，适合先抽服务。
- [x] 明确治理原则：本批只抽 `/feed/events` telemetry normalization + persistence，不改 API、不改 feed ranking、不改 post interaction 行为、不做数据库 migration。
- [x] 当前任务是否涉及数据库：否，只复用已有 `FeedEvent` 表写入。
- [x] 是否涉及 schema migration、索引调整、数据回填、projection rebuild：否，因此本批不需要新增数据库备份。
- [x] 新增 `server/src/modules/feed/feed-ranking.config.ts`，承接 feed ranking experiment bucket 与 weights version helper。
- [x] 新增 `server/src/modules/feed/feed-event.service.ts`，承接 feed event payload 校验、metadata 归一化、post existence 校验和写入。
- [x] `server/src/modules/feed/index.ts` export telemetry service/config。
- [x] `bff.routes.ts` 的 `/feed/events` handler 改为调用 `recordFeedEvent`，保持错误码和返回格式不变。
- [x] 删除 `bff.routes.ts` 中只服务 feed event 的 normalization helper；保留 feed ranking 主链路仍需要的 experiment helper。
- [x] 更新 Feed module README 和 tracker。
- [x] 运行 `cd server && pnpm build`。
- [x] build 通过后删除一次性日志 `/tmp/raver_phase5_feed_event_service_build.log`。

Phase 5 FeedEvent telemetry service extraction 验证：

- [x] `bff.routes.ts` 中 `/feed/events` 不再直接调用 `prisma.feedEvent.create`。
- [x] 后端 build 通过：`cd server && pnpm build`。
- [x] 已删除一次性日志：`/tmp/raver_phase5_feed_event_service_build.log`。
- [x] 本批未执行数据库 schema/data migration、backfill、索引调整或 projection rebuild，因此不需要新增数据库备份记录。

### Phase 5 PostInteraction Service Extraction Plan

- [x] 盘点 Post interactions：like/unlike、repost/unrepost、save/unsave、share、hide/unhide 当前全部内联在 `bff.routes.ts`，并混有 hydrate/mapPost 与通知发布。
- [x] 明确治理原则：本批只抽互动写入事务、计数维护、分享/隐藏参数归一化和 post existence 校验；BFF 暂时继续负责 hydrate/mapPost 和通知发布，避免一次性搬 DTO/通知链路。
- [x] 当前任务是否涉及数据库：否，只复用已有 Post interaction 表。
- [x] 是否涉及 schema migration、索引调整、数据回填、projection rebuild：否，因此本批不需要新增数据库备份。
- [x] 新增 `server/src/modules/feed/post-interaction.service.ts`。
- [x] `server/src/modules/feed/index.ts` export post interaction service。
- [x] `/feed/posts/:id/like` / `unlike` 改为调用 service。
- [x] `/feed/posts/:id/repost` / `unrepost` 改为调用 service。
- [x] `/feed/posts/:id/save` / `unsave` 改为调用 service。
- [x] `/feed/posts/:id/share` 改为调用 service。
- [x] `/feed/posts/:id/hide` / `unhide` 改为调用 service。
- [x] 删除 `bff.routes.ts` 中只服务 post interaction 的 share/hide normalization helper。
- [x] 运行 `cd server && pnpm build`。
- [x] build 通过后删除一次性日志 `/tmp/raver_phase5_post_interaction_service_build.log`。

Phase 5 PostInteraction service extraction 验证：

- [x] `bff.routes.ts` 的 interaction handlers 不再直接调用 `prisma.postLike` / `postRepost` / `postSave` / `postShare` / `postHide` 写入。
- [x] 后端 build 通过：`cd server && pnpm build`。
- [x] 已删除一次性日志：`/tmp/raver_phase5_post_interaction_service_build.log`。
- [x] 本批未执行数据库 schema/data migration、backfill、索引调整或 projection rebuild，因此不需要新增数据库备份记录。

### Phase 5 PostComment Service Extraction Plan

- [x] 盘点 comment tree：`/feed/posts/:id/comments` 当前负责评论读取、父评论校验、创建评论、`commentCount` 维护、DTO 映射和通知发布。
- [x] 明确治理原则：本批只抽评论读取/创建、父评论校验和 `commentCount` 维护；BFF 暂时继续负责 DTO 映射和通知发布，避免响应结构漂移。
- [x] 当前任务是否涉及数据库：否，只复用已有 `PostComment` / `Post` 表。
- [x] 是否涉及 schema migration、索引调整、数据回填、projection rebuild：否，因此本批不需要新增数据库备份。
- [x] 新增 `server/src/modules/feed/post-comment.service.ts`。
- [x] `server/src/modules/feed/index.ts` export post comment service。
- [x] `/feed/posts/:id/comments` GET 改为调用 service 读取评论。
- [x] `/feed/posts/:id/comments` POST 改为调用 service 创建评论。
- [x] 保持 BFF 内 DTO 映射和通知发布不变。
- [x] 运行 `cd server && pnpm build`。
- [x] build 通过后删除一次性日志 `/tmp/raver_phase5_post_comment_service_build.log`。

Phase 5 PostComment service extraction 验证：

- [x] `bff.routes.ts` 的 feed comment handlers 不再直接调用 `prisma.postComment` 写入/读取。
- [x] 后端 build 通过：`cd server && pnpm build`。
- [x] 已删除一次性日志：`/tmp/raver_phase5_post_comment_service_build.log`。
- [x] 本批未执行数据库 schema/data migration、backfill、索引调整或 projection rebuild，因此不需要新增数据库备份记录。

### Phase 3 Remaining Closure Plan

- [x] 清理 Xcode 用户态文件：`mobile/ios/RaverMVP/RaverMVP.xcworkspace/xcuserdata/blackie.xcuserdatad/UserInterfaceState.xcuserstate` 不应作为架构改造内容继续变化。
- [x] 对 `temp2` 后的 repository 改造补跑一次统一 iOS build。
- [x] 收口 `PostCardView` 的分享面板 IM 发送和分享统计直连。
- [x] 收口 Profile 编辑 loader 的 `WebFeatureService` 直连。
- [x] 收口 `CircleIDDJPickerSheet` 等小型 picker 的 `WebFeatureService` 直连。
- [x] 对剩余 `SocialService` / `WebFeatureService` 命中做归类：Phase 3 可收口、Phase 4 IM/Realtime、Phase 5 Content/Rating、基础设施保留。
- [x] 更新 Phase 3 验收：记录仍保留的 service 直连为什么暂缓，以及目标 Phase。

### Fat Repository Control

Phase 3 曾允许 `ProfileSocialRepository`、`DiscoverEventsRepository` 等作为过渡 adapter 变宽，用于先切断页面对巨型 service 的依赖；Phase 5 compatibility cleanup 后，这些宽组合入口已从 active code 移除，后续不得恢复为长期 God Repository。

治理规则：

- 新增迁移优先选择目标领域 repository，不继续把无关能力塞进已偏胖 repository。
- 跨领域流程用 UseCase / ViewModel 组合多个 repository，不把编排逻辑放进某一个 repository。
- 任何超过 25 个业务方法、覆盖 3 个以上领域名词、同时服务多个独立页面的 repository，都进入拆分候选。
- Phase 5 处理内容域时，优先把 `ProfileSocialRepository` 中的 checkin/rating/content 能力拆到 `CheckinRepository`、`RatingRepository`、`ProfileContentRepository`。
- Phase 4 处理 IM/Squad 时，优先把 `MessagesRepository` 和 Squad offline/realtime 相关能力拆成 Conversation / ChatSettings / SquadRealtime 等更小边界。
- Profile 编辑入口加载活动 / Set 已进一步收窄到 `EventReadRepository` / `SetReadRepository`；Circle ID DJ picker 已收窄到 `DJListRepository`。这类迁移只减少页面直连，不恢复 `ProfileSocialRepository` 或 Discover 宽组合协议。
- Rating 相关残留不得继续扩张到 `ProfileSocialRepository`；Phase 5 应建立 `RatingRepository`，承接 `fetchRatingEvents`、`fetchRatingEvent`、`fetchRatingUnit`、rating image upload、rating event/unit create/update/delete。

### Remaining Service Dependency Classification

以下归类用于防止后续看到 `SocialService` / `WebFeatureService` 命中就无差别迁移，从而把 God Service 变成 Fat Repository。

| 范围 | 当前残留 | 目标 Phase | 处理方式 |
| --- | --- | --- | --- |
| IM / Conversation | `ConversationLoaderView`、`MessagesHomeView`、`MessagesViewModel`、`TencentUIKitChatView`、`DemoAlignedChat*`、`RaverChatDataProvider` | Phase 4 | 拆 `ConversationRepository` / `ChatMessageRepository` / `ChatCompatibilityGateway`，不塞进 `MessagesRepository` |
| Chat Settings | `ChatSettingsView`、`ChatSettingsSheet` | Phase 4 | 拆 `ChatSettingsRepository`，和会话列表、消息收发分离 |
| Squad realtime / offline activity | `SquadOfflineActivityView`、`SquadOfflineActivityStarterSheet`、`SquadOfflineActivityHistoryView`、location uploader | Phase 4 | 拆 `SquadRealtimeRepository` / `SquadActivityRepository` / `LocationSyncRepository` |
| Squad hall / create squad | `LoadSquadHallDataUseCase`、`CreateSquadView` | Phase 4 | 拆 `SquadDiscoveryRepository` / `SquadMembershipRepository`，不继续扩大 `SquadProfileRepository` |
| Rating hub / detail | `CircleRatingHubView`、`CircleRatingEventDetailView`、`CircleRatingUnitDetailView` | Phase 5 | 建 `RatingRepository`，承接 rating event/unit 查询、提交、评论、分享统计相关数据访问 |
| Legacy / usage verification | 旧 `FeedViewModel`、旧 `ProfileViewModel` 中仍有 service 字段 | Phase 5 或清理阶段 | 先确认是否仍被路由构造；若已废弃则删除或降级 legacy，不为其新增 repository 方法 |
| Infrastructure adapters | `AppContainer`、`AppEnvironment`、各 repository adapter 内部 service 字段 | 保留 | 允许作为底层 API client 注入点；页面和 ViewModel 不应直接依赖 |

### Phase 3 Scope Check

- [x] 当前任务属于哪个 Phase：Phase 3 iOS Repository 层收束。
- [x] 当前任务是否服务该 Phase 目标：是，降低 ViewModel / coordinator 对巨型 service 的直接依赖。
- [x] 是否新增产品功能：否。
- [x] 是否扩大验证范围：否，同类 repository 改造批量完成后统一做 iOS 编译验证和 repository 边界验证。
- [x] 是否涉及数据库：否。
- [x] 是否涉及核心链路：是，Notifications / Share / Search / SquadProfile / Feed；采用 adapter 兼容旧调用并通过编译验证。
- [x] 是否需要进入 Backlog / Deferred：否。

---

## 4. 数据库备份记录

> 规则：任何数据库结构变更、迁移、回填、reproject apply、snapshot rebuild、批量修复前必须填写。

| 时间 | 环境 | 操作范围 | 备份文件 | 验证方式 | 回滚方式 | 状态 |
| --- | --- | --- | --- | --- | --- | --- |
| 2026-05-12 12:06:57 | local `raver_dev` | Phase 2 开始前备份；本轮计划仅做 Check-in / Share 模块骨架，不做 schema migration | `backups/raver_20260512_120657_before_phase2.dump` | `pg_restore --list` 成功，输出 `/tmp/raver_restore_list_20260512_120657.txt`，649 行 | 如后续数据动作失败，可使用该 dump restore 到本地库；本轮当前无数据动作 | Completed |

### 备份命令模板

```bash
mkdir -p backups
pg_dump "$DATABASE_URL" --format=custom --file "backups/raver_$(date +%Y%m%d_%H%M%S).dump"
pg_restore --list "backups/<dump-file>.dump" >/tmp/raver_restore_list.txt
```

### Restore Smoke Test 模板

```bash
createdb raver_restore_smoke
pg_restore --dbname raver_restore_smoke "backups/<dump-file>.dump"
psql raver_restore_smoke -c '\dt'
dropdb raver_restore_smoke
```

---

## 5. 变更日志

### 2026-05-12

- 新增商用级架构整理总方案。
- 新增本 tracker / log 文档。
- 确认改造过程必须使用 checkbox 跟踪。
- 确认数据库改造前必须备份已有数据。
- 确认新增需求先进入 deferred backlog，避免核心路线漂移。
- 新增 `docs/README.md` 作为统一文档入口。
- 新增 `docs/adr/` 目录和第一批 6 个 ADR。
- 更新根 README，修正 App-first、iOS Native、Tencent IM、Notification Center、Check-in v2 projection 和 Web/Admin 定位。
- 新增 `RAVER_LEGACY_AND_CURRENT_MAINLINE_INVENTORY.md`，明确 Current / Compat / Migration / Legacy / Archive。
- 新增 `RAVER_BACKEND_MODULE_OWNERSHIP.md`，建立后端 module owner、当前文件和目标目录映射。
- 新增 `IOS_REPOSITORY_NAMING_AND_MODULE_GUIDE.md`，建立 iOS Repository 命名和旧 Service 迁移规则。
- 更新 docs 入口，挂载 legacy 清单、backend ownership 和 iOS repository guide。
- 新增 `DATABASE_BACKUP_GATEKEEPER.md`，建立数据库改造前强制备份和验证规则。
- 新增 `ARCHITECTURE_SCOPE_CONTROL.md`，建立新增需求防漂移和 Phase scope check 规则。
- Phase 0 checklist 全部完成。
- Phase 1 启动，已写入 Scope Check；本轮只新增后端目录骨架和说明，不迁移业务逻辑。
- Phase 1 最小骨架已落地：新增 `server/src/modules/`、`shared/`、`infrastructure/`、`jobs/`、`legacy/` README。
- 新增 `server/src/modules/notifications/README.md`，将 Notification Center 标记为第一个模块化试点。
- 本轮没有修改现有 routes / services / scripts，没有数据库动作。
- 新增 `server/src/modules/notifications/index.ts` facade，复用现有 `services/notification-center` 实现。
- `notification-center.routes.ts` 和 `server/src/index.ts` 已改为从 `modules/notifications` 导入 Notification Center 能力。
- Phase 1 完成；当前没有迁移通知业务实现，只建立稳定 module import path。
- Phase 2 启动前已完成本地数据库备份：`backups/raver_20260512_120657_before_phase2.dump`。
- 已用 `pg_restore --list` 验证 dump 可读，输出 649 行目录。
- 新增 `server/src/modules/checkins/index.ts` facade，复用现有 Check-in domain / projection / read-model / status / worker 实现。
- 新增 `server/src/modules/share/index.ts` facade，复用现有 share link service 实现。
- `checkins-v2.routes.ts` 和 `share.routes.ts` 已改为从新 module 入口导入相关能力。
- 本轮没有执行 schema migration、reproject apply、snapshot rebuild 或 backfill。
- 新增 `server/src/jobs/checkin-projection/projection-worker.job.ts`，旧 `checkin-projection-worker-run.ts` 变为薄包装。
- `checkins:projection:freshness` 通过，状态 healthy，dirty/outbox/dead 均为 0。
- `checkins:projection:run` 通过，scanned=0 processed=0 failed=0。
- `share-links:smoke` 使用已有 share code `FfXVPa0U` 通过；未创建新的 share link 测试数据。
- 临时后端服务已停止；本轮生成的 `/tmp/raver_restore_list_20260512_120657.txt` 已删除。
- 仓库已有 `.tmp_app_localized_text.swiftfrag` 和 `.tmp_ll_translate_cache.json`，非本轮产生，未擅自删除。
- Phase 2 checklist 全部完成。
- Phase 3 启动：采用小步 iOS repository 收束，不做大规模目录搬迁。
- 新增 `NotificationRepository` protocol 和 `NotificationRepositoryAdapter`，复用现有 `SocialService` 通知接口。
- `NotificationsViewModel` 已由直接依赖 `SocialService` 改为依赖 `NotificationRepository`。
- `NotificationsView` 已改为从 `AppContainer.notificationRepository` 注入通知 repository。
- Xcode project 已补充 `NotificationRepository.swift` 文件引用和 target sources。
- VirtualAssets 已确认具备 `VirtualAssetRepository` / `LiveVirtualAssetRepository` / `DisabledVirtualAssetRepository` / mock repository 形态，本轮不重复改造。
- 新增 `ShareLinkRepository` protocol 和 `ShareLinkRepositoryAdapter`，复用现有 `ShareLinkService`。
- `ShareLinkCoordinator` 已改为依赖 `ShareLinkRepository`，并保留 `init(service:)`，避免一次性修改所有分享调用点。
- `AppEnvironment` 新增 `makeShareLinkRepository()`，为后续页面逐步迁移提供统一入口。
- Xcode project 已补充 `ShareLinkRepository.swift` 文件引用和 target sources。
- iOS build 使用 `iPhone 17` simulator 通过；`iPhone 16` simulator 不可用的失败重试未计入功能失败。
- 本轮未执行数据库 schema migration、数据回填、reproject apply 或 snapshot rebuild。
- 本轮生成的 `/tmp/raver-xcodebuild-derived` 已删除。
- Xcode 输出中的 `RaverMVP/Core/Widget` duplicate group warning、Pods run script warning、第三方 chat warnings 均为既有工程/依赖警告，非本轮新增阻塞。
- Phase 3 执行节奏调整：相同 repository 改造逻辑批量完成后统一 build，避免每改一处都触发完整 Xcode 编译。
- 新增 `GlobalSearchRepository` protocol 和 adapter，`GlobalSearchResultsViewModel` / placeholder / coordinator 已改为 repository 注入。
- 新增 `SquadProfileRepository` protocol 和 adapter，`SquadProfileViewModel` 已改为 repository 注入；`SquadProfileView` 内部编辑/上传子流程仍保留 service，后续单独收束。
- `AppContainer` 已补充 `globalSearchRepository` 和 `squadProfileRepository` 统一注入入口。
- iOS build 使用 `iPhone 17` simulator 通过，验证 Search / SquadProfile repository 批次；存在既有 warning。
- 本轮生成的 `/tmp/raver-xcodebuild-derived` 已删除，Xcode 用户态构建噪声已恢复。
- Feed repository 批次启动并完成：`CircleFeedRepository` 扩展到 post detail、compose、comments、in-app share 和 media upload 所需能力。
- `ComposePostView` 已由直接依赖 `SocialService` / `WebFeatureService` 改为依赖 `CircleFeedRepository`。
- `PostDetailView` 已由直接依赖 `SocialService` 改为依赖 `CircleFeedRepository`。
- `CircleCoordinator` 和 `MainTabCoordinator` 的 post create / edit / detail loader 已改为从 `AppContainer.circleFeedRepository` 注入。
- Feed 批次未执行数据库 schema migration、数据回填、reproject apply 或 snapshot rebuild。
- Feed repository 批次已按新节奏统一执行一次 iOS build，编译通过；未进行逐文件 build。
- Feed 批次生成的 `/tmp/raver-xcodebuild-derived` 已删除，未发现新的 Xcode 用户态构建噪声需要恢复。
- 根据新规则，后续 iOS 验证默认保留 `/tmp/raver-xcodebuild-derived` 以复用 xcodebuild 增量缓存；不再把 DerivedData 当作普通临时文件清理。
- 更新 `docs/IOS_REPOSITORY_NAMING_AND_MODULE_GUIDE.md`，明确 iOS build 默认保留 `/tmp/raver-xcodebuild-derived`，只清理其他一次性过程文件。
- Event detail Feed-like 讨论流已改为通过 `CircleFeedRepository` 获取活动动态、加载更多、点赞、转发和收藏。
- 新增 `ShareMessageRepository` protocol 和 adapter，收束分享面板的会话加载、Event card 发送、Event route card 发送和备注消息发送。
- `EventDetailView` 和 `EventRoutePlannerView` 的活动分享 / 路线分享 IM 调用已改为通过 `AppContainer.shareMessageRepository` 注入。
- Xcode project 已补充 `ShareMessageRepository.swift` 文件引用和 target sources。
- 本轮不涉及数据库 schema migration、数据回填、reproject apply 或 snapshot rebuild。
- `ShareMessageRepository` 已扩展覆盖 DJ / Set / Brand / Label / News / RankingBoard / MyCheckins 卡片发送。
- `DJsModuleView`、`SetsModuleView`、`DiscoverNewsDetailView`、`LearnModuleView`、`MyCheckinsView` 的分享面板 IM 会话加载、卡片发送和备注消息发送已改为通过 `AppContainer.shareMessageRepository`。
- 目标范围内 `appContainer.socialService.fetchConversations` / `send*CardMessage` / `sendMessage` 直接调用已清零，分享面板 IM 发送边界进一步收口。
- 本批次按“同类改造统一 build”执行，只跑一次 iOS build；`/tmp/raver-xcodebuild-derived` 已按新规则保留用于后续增量编译。
- 本轮没有新增产品功能、UI 重设计、数据库 schema migration、数据回填、reproject apply 或 snapshot rebuild。
- Xcode 用户态构建噪声 `xcschememanagement.plist` / `UserInterfaceState.xcuserstate` 已恢复；DerivedData 缓存未删除。
- `ProfileSocialRepository` 已扩展覆盖个人收藏 / 我的发布页面所需的个人打卡、活动详情、关注 DJ、发布列表和删除发布项能力。
- `MySavesViewModel` 已由 `ProfileSocialRepository + WebFeatureService` 改为只依赖 `ProfileSocialRepository`。
- `MyPublishesViewModel` 已由直接依赖 `WebFeatureService` / `SocialService` 改为只依赖 `ProfileSocialRepository`。
- `MainTabCoordinator` 中 MySaves / MyPublishes 路由已改为只注入 `appContainer.profileSocialRepository`。
- Profile 子页面 repository 批次已统一执行一次 iOS build，编译通过；`/tmp/raver-xcodebuild-derived` 继续保留用于后续增量编译。
- Profile 子页面批次没有新增产品功能、UI 重设计、数据库 schema migration、数据回填、reproject apply 或 snapshot rebuild。
- `DiscoverWikiRepository` 已扩展覆盖关注品牌动态偏好的读取与更新，继续把 `SocialService` 降级为 Learn/Wiki repository 的底层 client，而不是页面直接依赖。
- `AppContainer.discoverWikiRepository` 已改为同时注入 `webService` 和 `socialService`，不新增新 repository 类型，也不扩大 Learn 领域边界。
- `LearnFestivalDetailView` 的关注品牌动态偏好加载和切换已改为通过 `wikiRepository` 调用；本批次只收口依赖边界，不改 UI、交互和通知业务逻辑。
- `ProfileSocialRepository` 已扩展覆盖 MyCheckins v2 页面所需的概览、时间线、活动画廊、DJ 画廊和删除打卡接口，继续复用现有 Profile repository 边界，不新增新 repository 类型。
- `MyCheckinsViewModel` 已由直接依赖 `WebFeatureService` 改为依赖 `ProfileSocialRepository`，页面刷新、分页、画廊加载和删除打卡调用都经由 repository。
- `MainTabCoordinator` 的 `myCheckins` 路由已改为注入 `appContainer.profileSocialRepository`；本批次只收口依赖边界，不改打卡 UI、投影读模型和分享逻辑。
- `SquadProfileRepository` 已扩展覆盖小队管理子流程所需的资料加载、资料保存、小队头像上传和旗帜图上传，继续复用现有 Squad repository 边界，不新增新 repository 类型。
- `SquadManageRouteView` 与 `SquadManageFormView` 已由直接依赖 `SocialService` / `WebFeatureService` 改为依赖 `SquadProfileRepository`；本批次只收口管理子流程边界，不改主小队详情页、入队逻辑和分享逻辑。
- `AppContainer.squadProfileRepository` 已改为同时注入 `socialService` 和 `webService`，`MainTabCoordinator` 的 `squadManage` 路由已切到 repository 注入。
- `SquadProfileView` 顶层已移除未使用的 `SocialService` 注入，主详情页表层现在只保留 `SquadProfileRepository` 依赖；本批次不改小队分享链接流程和 `ShareLinkCoordinator` 兼容层。
- `SquadProfileView` 的分享链接协调器已从 `AppEnvironment.makeShareLinkService()` 兼容入口切到 `AppEnvironment.makeShareLinkRepository()`，让该页面分享链路也对齐现有 Share repository 边界。
- `ProfileView`、`UserProfileView`、`PostDetailView`、`PostCardView` 的分享链接协调器已统一从 `AppEnvironment.makeShareLinkService()` 兼容入口切到 `AppEnvironment.makeShareLinkRepository()`，本批次只收口分享链接依赖边界，不改分享 UI、渠道和埋点逻辑。
- `EventDetailView`、`SetsModuleView`、`DiscoverNewsDetailView`、`DJsModuleView`、`LearnModuleView` 各详情/分享子页，以及 `MainTabView` 中剩余 share-link 协调器点位，已统一切到 `AppEnvironment.makeShareLinkRepository()`；页面层旧 `ShareLinkCoordinator(service: ...)` 工厂直连现已清零。
- `MessagesRepository` 已扩展覆盖发起私聊会话入口，`UserProfileView` 的私信按钮已由直接依赖 `appContainer.socialService.startDirectConversation` 改为通过 `appContainer.messagesRepository` 调用；本批次只收口消息会话边界，不改 IM store、会话跳转和发信行为。
- `ShareMessageRepository` 已扩展覆盖 `Circle ID`、`RatingEvent`、`RatingUnit` 卡片发送能力；`MainTabView` 中对应分享面板会话加载和卡片发送 helper 已从 `socialService` 直连切到 `shareMessageRepository`，继续沿用现有分享消息 repository 边界。
- `LoginView` 注册成功后的头像上传已由直接依赖 `appContainer.socialService.uploadMyAvatar` 改为通过 `appContainer.profileSocialRepository` 调用，继续复用现有 Profile repository 边界，不改注册流程和错误提示文案。
- `ProfileSocialRepository` 已扩展覆盖评分事件/评分单位编辑所需的封面上传与更新能力，`RatingEventEditorSheet` / `RatingUnitEditorSheet` 及其 `ViewModel` 已由直接依赖 `WebFeatureService` 改为依赖 `ProfileSocialRepository`；本批次只收口 Profile 子页面编辑边界，不改评分创建流程。
- `DiscoverEventsRepository` 已扩展覆盖事件讨论区所需的评论加载、评论发布、评论点赞和附图上传能力，`EventLiveDiscussionView` 已由直接依赖 `SocialService` / `WebFeatureService` 改为依赖 `DiscoverEventsRepository`；`MainTabCoordinator` 的 `eventLiveDiscussion` 路由也已切到 repository 注入。
- `DiscoverEventsRepository` 已进一步扩展覆盖评分事件/评分单位创建链所需的活动搜索、封面上传、事件导入建单与单位创建能力；`CreateRatingEventSheet`、`CreateRatingEventFromEventSheet`、`CreateRatingUnitSheet` 以及 `MainTabCoordinator` / `CircleCoordinator` 对应构造层提交已由直接依赖 `webService` 改为通过 `discoverEventsRepository` 调用。
- `CircleIDEventPickerSheet` 的活动分页加载已由直接依赖 `webService.fetchEvents` 改为通过 `discoverEventsRepository.fetchEvents(request:)` 调用，继续沿用现有事件搜索 repository 边界。
- `temp2` 后统一 build 首次发现 `SquadProfileView` sheet 调用仍传入旧 `service:` 参数，已移除并改为只注入 `SquadProfileRepository`，随后统一 build 通过。
- `PostCardView` 的分享面板会话加载、普通消息发送、Post 卡片发送和分享统计已由 `appContainer.socialService` 直连切到 `CircleFeedRepository`；`/tmp/raver_phase3_build.log` 已删除，`/tmp/raver-xcodebuild-derived` 已保留。
- Profile 编辑 loader 已由 `appContainer.webService` 直连逐步收窄到 Event / Set / Rating 小 repository；活动、Set、评分事件、评分单位加载不再在该路由层直连 `WebFeatureService`。
- `CircleIDDJPickerSheet` 已由 `appContainer.webService.fetchDJs` 改为通过 `DiscoverDJsRepository.fetchDJs` 分页加载；本批不处理 rating hub/detail 的更大 Rating 域直连，避免继续扩大过渡 repository。
- 剩余 service 命中已按 Phase 4 IM/Realtime、Phase 5 Rating/Content、基础设施 adapter 三类归档；Phase 3 不再继续向过渡 repository 塞入 chat、location、rating detail 等跨域能力。
- Xcode 用户态文件 `UserInterfaceState.xcuserstate` 已恢复；本轮只删除一次性 `/tmp/raver_phase3_build.log`，继续保留 `/tmp/raver-xcodebuild-derived` 作为增量编译缓存。
- `NotificationRepository` 已新增 Debug-only `MockNotificationRepository`，`NotificationsView` 已新增 `Notifications Repository Seam` preview，用于验证单模块可脱离 `SocialService` 做 mock / preview。
- Phase 3 closure build 已通过；Phase 3 状态从 `[~]` 更新为 `[x]`。后续 IM/Realtime 进入 Phase 4，Rating/Content 深拆进入 Phase 5，物理目录大搬迁进入 deferred。
- Phase 4 启动：先处理 IM / Messages 边界，不触碰数据库、不执行 Tencent IM 同步 job、不做群组关系回填。
- `MessagesRepository` 过渡接口已拆为 `ConversationRepository` 和 `MessageNotificationRepository`；`MessagesViewModel`、`MessagesCoordinator`、`MessagesHomeView`、`MessageNotificationsViewModel`、`MainTabView`、`MainTabCoordinator`、`UserProfileView` 已改为注入对应小 repository。
- Phase 4 Messages repository split 已统一执行 iOS build，编译通过；一次性 `/tmp/raver_phase4_messages_build.log` 已删除，`/tmp/raver-xcodebuild-derived` 已保留。
- 新增后端 `server/src/modules/im/` facade，收拢 Tencent IM current integration export。
- `tencent-im.routes.ts`、`bff.routes.ts`、`squad.service.ts`、`share-link.service.ts`、`auth.controller.ts` 和 `tencent-im-*` scripts 已改为通过 `modules/im` 引用 Tencent IM 能力。
- 新增 `server/src/services/openim/README.md` legacy marker，明确 OpenIM 不再扩展新业务能力；本批未删除 OpenIM 文档和历史迁移表。
- `ChatSettingsView` 已新增 `ChatSettingsRepository` / `ChatSettingsRepositoryAdapter`，覆盖聊天设置当前需要的会话设置、直聊设置、群资料、邀请和成员管理能力。
- `ChatSettingsView`、`InviteSquadMembersView`、`GroupMemberListView` 已改为依赖 `ChatSettingsRepository`，不再直接持有 `SocialService`。
- `AppContainer.chatSettingsRepository`、`MainTabCoordinator` 的 chat settings route、UIKit chat `DemoAlignedChatRouteCoordinator` 已完成 repository 注入。
- Phase 4 ChatSettings 批次已统一执行 iOS build，编译通过；一次性 `/tmp/raver_phase4_chat_settings_build.log` 已删除，`/tmp/raver-xcodebuild-derived` 已保留。
- 新增 `SquadActivityRepository` / `SquadActivityRepositoryAdapter`，承接线下活动 current/history/start/join/leave/end/status/member removal 和 squad invite 能力。
- 新增 `LocationSyncRepository` / `LocationSyncRepositoryAdapter`，只承接 `uploadSquadOfflineActivityLocation`，避免定位同步和活动生命周期混成一个大仓储。
- `SquadOfflineActivityView`、`SquadOfflineActivityHistoryView`、`SquadOfflineActivityStarterSheet`、`SquadOfflineActivityInviteSheet` 和 `SquadOfflineActivityLocationUploader` 已切换到对应 repository。
- `TencentUIKitChatView` 的 offline activity banner / starter 入口已通过 `SquadActivityRepository` 和 `DiscoverEventsRepository` 访问数据。
- Phase 4 Squad offline activity 批次已统一执行 iOS build，编译通过；本批未执行数据库 schema migration、数据回填、IM sync apply 或群组关系批量修复。
- 新增 `ChatMessageRepository` / `ChatMessageRepositoryAdapter`，收束 UIKit chat 的消息拉取、发送、媒体发送、卡片发送、撤回、删除、已读和 typing。
- `RaverChatController`、`RaverChatDataProvider`、`TencentUIKitChatView` 的 Exyte chat ViewModel 和 `DemoAlignedChatViewController` 已切到 `ChatMessageRepository`；`SocialService` 仅保留为当前 adapter 底层实现与更宽 UIKit 入口的过渡依赖。
- Phase 4 ChatMessageRepository 批次已统一执行 iOS build，编译通过；本批未执行数据库 schema migration、数据回填、IM sync apply 或群组关系批量修复；一次性 `/tmp/raver_phase4_chat_message_build.log` 已删除，`/tmp/raver-xcodebuild-derived` 已保留。
- `Infrastructure/TencentIM/` 第一批目录归位已完成：IM store、conversation/message search index、probe log、storage governance、chat media cache/resolver 从 `Core` / `UIKitChat` 移入基础设施目录。
- `Infrastructure/LegacyOpenIM/IMSession.swift` 标记 OpenIM 旧兼容入口；后续不在该路径扩展 Tencent IM 新能力。
- Phase 4 iOS Infrastructure 批次已统一执行 iOS build，编译通过；本批未执行数据库 schema migration、数据回填、IM sync apply 或群组关系批量修复；一次性 `/tmp/raver_phase4_infrastructure_build.log` 已删除，`/tmp/raver-xcodebuild-derived` 已保留。

### 2026-05-13

- Phase 5 compatibility cleanup 启动：目标是关闭已完成 physical split 后遗留的宽组合 repository 兼容壳，防止 God Service 变成长期 Fat Repository。
- 本批只做 iOS repository 入口收束，不改 UI、不改 API、不新增业务能力、不执行数据库 schema/data migration、backfill、索引调整、projection rebuild、IM sync apply 或群组关系批量修复。
- 已确认 Events、Feed、Profile 宽入口已无页面 / 路由层调用；本批继续移除 Music 的 `DiscoverDJsRepository` / `DiscoverSetsRepository` 兼容协议、adapter 和 AppContainer 旧出口。
- 本批继续保留 `/tmp/raver-xcodebuild-derived` 作为增量编译缓存；build 成功后只清理一次性 `/tmp/raver_phase5_closure_cleanup_build.log`。
- Phase 5 compatibility cleanup 已完成：Swift 活跃代码中 `ProfileSocialRepository`、`DiscoverEventsRepository`、`DiscoverDJsRepository`、`DiscoverSetsRepository`、`CircleFeedRepository` 以及对应旧 AppContainer 出口均已清零。
- 已通过 `git diff --check`、`plutil -lint` 和一次统一 iOS 增量 build；一次性 `/tmp/raver_phase5_closure_cleanup_build.log` 已删除，`/tmp/raver-xcodebuild-derived` 已保留。
- Phase 5 后端 content module facade 已完成：新增 `server/src/modules/feed`、`server/src/modules/events`、`server/src/modules/music`，并将 comment/event/DJ/DJSet/music search/DJ aggregator/BFF web 相关入口切到 module import boundary。
- 本批后端 build 已通过；一次性 `/tmp/raver_phase5_backend_content_modules_build.log` 已删除。本批未执行数据库 schema/data migration、backfill、索引调整或 projection rebuild。
- Phase 5 FeedEvent telemetry service extraction 已完成：`/feed/events` handler 已从 BFF 内联校验/写入改为调用 `modules/feed.recordFeedEvent`，feed ranking experiment config 也已归入 Feed module。后端 build 已通过，一次性 `/tmp/raver_phase5_feed_event_service_build.log` 已删除。
- Phase 5 PostInteraction service extraction 已完成：like/repost/save/share/hide 写入事务、计数维护和 share/hide 参数归一化已进入 `modules/feed/post-interaction.service.ts`；BFF 暂时继续负责 hydrate/mapPost 和通知发布。后端 build 已通过，一次性 `/tmp/raver_phase5_post_interaction_service_build.log` 已删除。
- Phase 5 PostComment service extraction 已完成：feed comment 读取、父评论校验、创建评论和 `commentCount` 维护已进入 `modules/feed/post-comment.service.ts`；BFF 暂时继续负责 DTO 映射和通知发布。后端 build 已通过，一次性 `/tmp/raver_phase5_post_comment_service_build.log` 已删除。
- Phase 5 smoke 发现 Feed 列表刷新、发帖后列表即时显示、评论后评论列表刷新存在真实运行问题；本批先修复 iOS 本地状态同步：`FeedViewModel.mergeNewPost` 去重置顶，`PostDetailView` 评论成功后递增 `commentCount` 并广播 `.circlePostDidUpdate`。
- 本地 BFF 验证 `/v1/feed?mode=latest`、`/v1/feed?mode=recommended`、`/v1/feed/posts/:id/comments` 均返回 200；iOS 增量 build 通过。若用户重新 smoke 仍提示 failed，需要继续抓 App 控制台中的 `Social BFF decode error` 或确认当前 App `RAVER_BFF_BASE_URL` 指向的服务实例。
- 用户反馈服务端日志为 `GET /v1/feed?limit=12&mode=recommended - - ms - -`，这类 morgan 记录通常表示请求被客户端取消而非正常 500；已验证带 Authorization 的 recommended Feed 本地返回 200 且约 0.08s。
- 已补 iOS 取消请求静默处理：`FeedViewModel.load` / `loadMoreIfNeeded` 和 `PostDetailView.loadComments` 遇到 `CancellationError` / `URLError.cancelled` 不再进入 failed UI，避免 SwiftUI `.task` 重启或页面切换造成假失败。
- 用户确认 Phase 5 真实运行 smoke 全部通过：Feed 列表刷新、发帖即时显示、点赞/取消、收藏/取消、评论创建/列表、Event 详情、DJ 详情、Set 详情均已通过。Phase 5 状态更新为 `[x]`，下一步进入 Phase 6 Admin / Operations 商用化。
- Phase 6 P0 inventory 已完成：新增 `docs/RAVER_ADMIN_OPERATIONS_PHASE6_INVENTORY.md`，清点 notification、pre-registration、checkin projection、virtual asset、Web Admin、ops scripts 和 OpenIM legacy admin client。
- Phase 6 ownership model 已明确：admin-shell、notification-ops、pre-registration-ops、checkin-ops、virtual-asset-ops、im current/legacy、content-ops；下一步只做 `/api/admin/v1` facade，不做数据库动作。
- OpenIM admin client 已标记为 legacy / not current；当前 IM ops 主线只围绕 Tencent IM，不把 OpenIM 历史后台扩展为新主线。
- docs index 已挂载 Phase 6 Admin / Operations inventory，避免后续执行时找不到当前 Admin 改造路线。
- 本批只改文档和路线边界，未执行 API 迁移、数据库 schema/data migration、projection rebuild、snapshot rebuild、IM sync apply 或批量修复。
- Phase 6 P1 Admin route facade 已完成：新增 `server/src/modules/admin/` 和 `/api/admin/v1` mount，先代理 notification、pre-registration、checkin projection status、virtual asset grant 等现有后台入口。
- P1 保留旧 admin 路径兼容，不改现有 handler 响应结构；后端 build 已通过。本批未执行数据库动作，不需要新增备份记录。
- Backend module ownership 已将 `admin` 从 Target 更新为 Current + Facade，记录当前 `/api/admin/v1` facade 与后续 shared auth / audit / status 方向。
- Phase 6 P2 后端 shared admin auth / role policy 已完成：新增 `admin-auth.policy.ts`，notification admin、pre-registration admin、virtual asset grant、checkin projection status 已统一角色判断。
- P2 本批未改全局 auth middleware，未新增 RBAC 表，未执行数据库动作；Web admin client token/error handling 留作下一小步。
- Web Admin client alignment 已完成：notification center / pre-registration 后台 client 已切到 `/api/admin/v1`；`cd web && pnpm build` 通过，只有既有 lint warning。
- Admin audit query 已完成：新增只读 `GET /api/admin/v1/audit-logs` 和 Web API client `admin-audit.ts`，只查既有 `admin_audit_logs`，未执行数据库动作。

---

## 6. 风险与阻塞

| 时间 | 风险 | 影响 | 处理策略 | 状态 |
| --- | --- | --- | --- | --- |
| 2026-05-12 | 重构过程中顺手加入新功能导致路线漂移 | 拖慢核心架构收束，扩大验证范围 | 新需求进入 Backlog / Deferred | Open |
| 2026-05-12 | 数据库改造未备份导致数据不可恢复 | 高风险数据丢失 | 数据库备份门禁；无备份不执行数据动作 | Open |
| 2026-05-12 | 新旧 API 并存期间调用路径混乱 | 客户端行为不一致 | 旧入口代理到新 module，逐步标记 legacy | Open |
| 2026-05-12 | Xcode project 已存在 `RaverMVP/Core/Widget` duplicate group warning | 影响工程整洁度，但本轮 build 可通过 | 记录为既有工程整理项，后续 iOS 工程治理阶段单独处理 | Open |

---

## 7. Backlog / Deferred

> 不服务当前核心路线的需求先放这里，后续单独评估。

| 需求 | 来源 | 为什么暂缓 | 重新评估条件 |
| --- | --- | --- | --- |
| 推荐算法升级 | 架构讨论 | 不属于本轮架构收束核心路径 | Feed module 收束完成后 |
| 新商业化玩法 | 架构讨论 | 会扩大产品范围 | VirtualAsset / Checkin 边界稳定后 |
| 微服务拆分 | 架构讨论 | 当前更适合模块化单体 | 单体模块边界稳定且出现明确规模瓶颈后 |
| 大规模表重命名 | 架构讨论 | 风险高且收益不如先做逻辑分组 | 数据库 owner 和 repository 边界稳定后 |

---

## 8. 验证命令记录

| 时间 | 阶段 | 命令 | 结果 | 备注 |
| --- | --- | --- | --- | --- |
| 2026-05-12 | Phase 0 | 文档变更检查 | 通过 | 本次只改文档，不涉及业务代码和数据库 |
| 2026-05-12 | Phase 1 | `find server/src/modules server/src/shared server/src/infrastructure server/src/jobs server/src/legacy -maxdepth 2 -type f` | 通过 | 骨架 README 均已落地；未修改现有运行代码 |
| 2026-05-12 | Phase 1 | `cd server && pnpm build` | 通过 | notifications module facade 和 import 切换编译通过 |
| 2026-05-12 | Phase 2 | `docker exec raver-postgres pg_dump -U raver -d raver_dev --format=custom` | 通过 | 备份到 `backups/raver_20260512_120657_before_phase2.dump` |
| 2026-05-12 | Phase 2 | `pg_restore --list backups/raver_20260512_120657_before_phase2.dump` | 通过 | 649 行目录，可读性验证通过 |
| 2026-05-12 | Phase 2 | `cd server && pnpm build` | 通过 | Check-in / Share module facade 和 route import 切换编译通过 |
| 2026-05-12 | Phase 2 | `cd server && pnpm checkins:projection:freshness` | 通过 | status=healthy，dirtyCheckins=0，pendingOutbox=0，deadOutbox=0 |
| 2026-05-12 | Phase 2 | `cd server && pnpm checkins:projection:run` | 通过 | scanned=0，processed=0，failed=0 |
| 2026-05-12 | Phase 2 | `SHARE_LINK_SMOKE_CODE=FfXVPa0U pnpm share-links:smoke` | 通过 | 使用已有 active share link，未创建临时测试数据 |
| 2026-05-12 | Phase 2 | `rm -f /tmp/raver_restore_list_20260512_120657.txt` | 通过 | 清理本轮临时验证产物 |
| 2026-05-16 | Phase 8 | `docker exec raver-postgres pg_dump -U raver -d raver_dev --format=custom` | 通过 | 备份到 `backups/raver_20260516_165823_before_auth_session_commercialization.dump`，大小 16MB |
| 2026-05-16 | Phase 8 | `docker exec -i raver-postgres pg_restore --list < backups/raver_20260516_165823_before_auth_session_commercialization.dump` | 通过 | 输出 752 行目录，可读性验证通过 |
| 2026-05-16 | Phase 8 | `cd server && npx prisma migrate deploy --schema prisma/schema.prisma && npx prisma generate --schema prisma/schema.prisma` | 通过 | 应用 `20260516170000_expand_auth_refresh_tokens_for_sessions` 并生成 Prisma client |
| 2026-05-16 | Phase 8 | `cd server && pnpm build` | 通过 | Auth session 字段、refresh 校验、session list/revoke 编译通过 |
| 2026-05-16 | Phase 8 | `cd server && AUTH_INTEGRATION_ENABLE_SMS=false pnpm auth:integration` | 通过 | 覆盖 register/login、refresh rotation、old refresh rejected、session list、revoke current session、web_admin session metadata、logout、rate limit；短信流本轮跳过 |
| 2026-05-16 | Phase 8 | `cd web && pnpm build` | 通过 | Web Admin auth client 切到 `/v1/auth/*`、access token 内存态、旧 `localStorage.token` 清理；仅有既有 lint warning |
| 2026-05-16 | Phase 8 | `cd web && pnpm build` | 通过 | Web Admin authenticated fetch wrapper 接入 account/content/pre-registration/status/audit/notification-center clients；401 refresh-retry 编译通过，仅有既有 lint warning |
| 2026-05-16 | Phase 8 | `cd web && pnpm test:e2e` | 通过 | Playwright 覆盖 `/admin` 401 后 refresh 并重试成功、refresh 失败跳 `/login?reason=session-expired` |
| 2026-05-16 | Phase 8 | `cd web && pnpm build` | 通过 | Web Admin idle warning/auto logout、后台过期重定向和 Playwright 配置编译通过；仅有既有 lint warning |
| 2026-05-16 | Phase 8 | `cd web && pnpm test:e2e` | 通过 | Playwright 4 条覆盖：401 refresh retry、refresh 失败回登录、会话列表撤销其他设备、撤销当前会话回登录态 |
| 2026-05-16 | Phase 8 | `cd web && pnpm build` | 通过 | 新增 `/admin/auth-sessions` 当前账号会话管理页面和后台入口；仅有既有 lint warning |
| 2026-05-16 | Phase 8 | `cd server && pnpm build` | 通过 | 新增 Admin Auth Sessions API，支持 admin 按用户检索会话和踢下线，撤销写 AdminAuditLog |
| 2026-05-16 | Phase 8 | `cd web && pnpm build` | 通过 | `/admin/auth-sessions` 增加 admin-only 用户会话检索与踢下线区块；仅有既有 lint warning |
| 2026-05-16 | Phase 8 | `cd web && pnpm test:e2e` | 通过 | Playwright 5 条覆盖：新增管理员检索目标用户会话并踢下线 |
| 2026-05-16 | Phase 8 | `cd server && pnpm build` | 通过 | 新增 `/v1/auth/reauth` 和 reauth proof 校验，账号处罚写操作要求二次验证 |
| 2026-05-16 | Phase 8 | `cd web && pnpm build` | 通过 | 账号处罚后台新增密码复验弹窗和 reauth proof 透传；仅有既有 lint warning |
| 2026-05-16 | Phase 8 | `cd web && pnpm test:e2e` | 通过 | Playwright 6 条覆盖：新增账号处罚创建前密码复验并携带 reauth proof |
| 2026-05-16 | Phase 8 | `cd server && pnpm build` | 通过 | 账号删除 retry/process-due 接入 `account_deletion.write` reauth proof 校验 |
| 2026-05-16 | Phase 8 | `cd web && pnpm build` | 通过 | 账号删除后台新增密码复验弹窗和 reauth proof 透传；仅有既有 lint warning |
| 2026-05-16 | Phase 8 | `cd web && pnpm test:e2e` | 通过 | Playwright 7 条覆盖：新增账号删除重试前密码复验并携带 reauth proof |
| 2026-05-16 | Phase 8 | `xcodebuild -workspace mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/raver-xcodebuild-derived build` | 通过 | iOS 登录设备管理、logout-all 和 session revoked 差异化提示编译通过；存在既有 warning |
| 2026-05-16 | Phase 8 | `cd server && pnpm build` | 通过 | Auth integration 脚本补充 logout-all 和 iOS/Web Admin TTL 分流断言后编译通过 |
| 2026-05-16 | Phase 8 | `cd server && AUTH_INTEGRATION_ENABLE_SMS=false pnpm auth:integration` | 通过 | 覆盖 logout-all 全会话撤销、iOS 30 天 refresh TTL 不受 Web Admin 12 小时策略影响 |
| 2026-05-16 | Phase 8 | `cd server && pnpm build` | 通过 | 新增 `/v1/auth/password`，账号删除/停用和改密会话撤销逻辑编译通过 |
| 2026-05-16 | Phase 8 | `cd server && AUTH_INTEGRATION_ENABLE_SMS=false pnpm auth:integration` | 通过 | 覆盖改密保留当前会话并撤销其他 refresh token、删号后当前/其他 refresh token 均被撤销 |
| 2026-05-16 | Phase 8 / SMS Phase 6 | `cd server && pnpm build` | 通过 | 短信登录生产化第一批：provider 启动门禁、稳定错误码、短信指标和 Admin status 聚合编译通过 |
| 2026-05-16 | Phase 8 / SMS Phase 6 | `cd web && pnpm build` | 通过 | Web Admin 工作台新增 Auth SMS provider/失败率/限流/验证失败状态；仅有既有 lint warning |
| 2026-05-16 | Phase 8 / SMS Phase 6 | `cd server && AUTH_INTEGRATION_ENABLE_SMS=false pnpm auth:integration` | 通过 | 关闭真实短信 provider 的 auth/session 回归通过，短信外部通道待真机与阿里云模板审核后验证 |
| 2026-05-16 | Phase 8 / SMS Phase 6 | `cd server && pnpm build` | 通过 | 新增 Firebase Phone ID token 换 Raver session 服务端入口和 Admin status 配置状态 |
| 2026-05-16 | Phase 8 / SMS Phase 6 | `AUTH_INTEGRATION_BASE_URL=http://127.0.0.1:3911/v1 AUTH_INTEGRATION_ENABLE_SMS=false AUTH_FIREBASE_PHONE_MOCK=true pnpm auth:integration` | 通过 | 临时后端启用 Firebase phone mock，覆盖成功登录和无效 token 401 |
| 2026-05-16 | Phase 8 / SMS Phase 6 | `cd web && pnpm build` | 通过 | Web Admin Auth SMS 状态展示 Firebase phone configured/mock 标记；仅有既有 lint warning |
| 2026-05-16 | Phase 8 / SMS Phase 6 | `xcodebuild -workspace mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/raver-xcodebuild-derived build` | 通过 | iOS 服务层新增 Firebase Phone ID token 换 Raver session 方法；尚未接 FirebaseAuth SDK |
| 2026-05-16 | Phase 8 / SMS Phase 6 | `pod install` | 通过 | 使用代理 `127.0.0.1:7897` 安装 FirebaseAuth 12.6.0；`GoogleService-Info.plist` 已加入主 App target |
| 2026-05-16 | Phase 8 / SMS Phase 6 | `cd server && pnpm build` | 通过 | Firebase Admin service account 通过被忽略的 `server/.env` 本地路径配置；service account JSON 不进入 git |
| 2026-05-16 | Phase 8 / SMS Phase 6 | `cd web && pnpm build` | 通过 | Web Admin Auth SMS / Firebase phone 状态编译通过；仅有既有 React hook / `<img>` lint warning |
| 2026-05-16 | Phase 8 / SMS Phase 6 | `AUTH_INTEGRATION_BASE_URL=http://127.0.0.1:3911/v1 AUTH_INTEGRATION_ENABLE_SMS=false AUTH_FIREBASE_PHONE_MOCK=true pnpm auth:integration` | 通过 | Firebase phone mock 覆盖成功登录、无效 token 401；临时 3911 后端已停止 |
| 2026-05-16 | Phase 8 / SMS Phase 6 | `xcodebuild -workspace mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/raver-xcodebuild-derived build` | 通过 | iOS FirebaseAuth SDK、FirebaseApp.configure、URL callback 和短信 ID token 换 Raver session 编译通过；APNs token 保持 Firebase 默认 swizzling 自动处理；存在既有 Pods script warning |
| 2026-05-16 | Phase 8 / SMS Phase 6 | `xcodebuild -workspace mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/raver-xcodebuild-derived build` | 通过 | 修复 FirebaseAuth phone verify 崩溃风险：补 encoded app id URL scheme 和 `canHandleNotification`；存在既有 Pods script warning |
| 2026-05-16 | Phase 8 / SMS Phase 6 | `cd server && pnpm build` | 通过 | Firebase phone login 支持新手机号注册时写入昵称；昵称唯一冲突返回 `AUTH_DISPLAY_NAME_TAKEN` |
| 2026-05-16 | Phase 8 / SMS Phase 6 | `xcodebuild -workspace mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/raver-xcodebuild-derived build` | 通过 | iOS 登录/注册手机号支持国家区号选择；注册改为手机号验证码优先并采集出生年月日；邮箱验证码待后端 email verification provider |
| 2026-05-16 | Phase 8 / SMS Phase 6 | `cd server && pnpm build` | 通过 | 新增 `GET /v1/auth/display-name/check`，注册前可只读检测昵称是否可用 |
| 2026-05-16 | Phase 8 / SMS Phase 6 | `xcodebuild -workspace mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/raver-xcodebuild-derived build` | 通过 | iOS 注册页昵称输入防抖检测可用性，展示可用/占用/非法/失败状态并阻止占用昵称提交 |
| 2026-05-16 | Phase 8 | `cd web && pnpm build` | 通过 | Playwright 增补旧 `localStorage.token` 清理和主 token 不落 localStorage 断言后编译通过；仅有既有 lint warning |
| 2026-05-16 | Phase 8 | `cd web && pnpm test:e2e` | 通过 | Playwright 9 条覆盖：新增旧 localStorage token 清理、登录后 access token 不落 localStorage |
| 2026-05-12 | Phase 3 | `xcodebuild -workspace mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/raver-xcodebuild-derived build` | 通过 | Notifications repository 切片编译通过；存在既有 warning |
| 2026-05-12 | Phase 3 | `xcodebuild -workspace mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/raver-xcodebuild-derived build` | 通过 | Share repository 切片编译通过；存在既有 warning |
| 2026-05-12 | Phase 3 | `rm -rf /tmp/raver-xcodebuild-derived` | 通过 | 清理本轮 iOS 编译临时产物 |
| 2026-05-12 | Phase 3 | `xcodebuild -workspace mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/raver-xcodebuild-derived build` | 通过 | Search / SquadProfile repository 批次编译通过；存在既有 warning |
| 2026-05-12 | Phase 3 | `rm -rf /tmp/raver-xcodebuild-derived` | 通过 | 清理 Search / SquadProfile 批次 iOS 编译临时产物 |
| 2026-05-12 | Phase 3 | `git diff --check -- <Phase 3 Feed files>` | 通过 | Feed repository 批次补丁无 whitespace error |
| 2026-05-12 | Phase 3 | `xcodebuild -workspace mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/raver-xcodebuild-derived build` | 通过 | Feed repository 批次编译通过；存在既有 warning |
| 2026-05-12 | Phase 3 | `rm -rf /tmp/raver-xcodebuild-derived` | 通过 | 清理 Feed 批次 iOS 编译临时产物 |
| 2026-05-12 | Phase 3 | `plutil -lint mobile/ios/RaverMVP/RaverMVP.xcodeproj/project.pbxproj` | 通过 | Xcode project 文件仍可解析 |
| 2026-05-12 | Phase 3 | `rg -n "appContainer\\.socialService\\.(fetchConversations|send.*CardMessage|sendMessage)" mobile/ios/RaverMVP/RaverMVP/Features/Discover mobile/ios/RaverMVP/RaverMVP/Features/Profile` | 通过 | 目标范围内分享面板 IM 直连调用已清零 |
| 2026-05-12 | Phase 3 | `git diff --check -- <Phase 3 ShareMessage files>` | 通过 | 分享 IM repository 批次补丁无 whitespace error |
| 2026-05-12 | Phase 3 | `xcodebuild -workspace mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/raver-xcodebuild-derived build` | 通过 | ShareMessage repository 批次编译通过；`/tmp/raver-xcodebuild-derived` 已保留用于增量编译，存在既有 warning |
| 2026-05-12 | Phase 3 | `git diff --check -- <Phase 3 Profile child view files>` | 通过 | Profile 子页面 repository 批次补丁无 whitespace error |
| 2026-05-12 | Phase 3 | `xcodebuild -workspace mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/raver-xcodebuild-derived build` | 通过 | Profile 子页面 repository 批次编译通过；`/tmp/raver-xcodebuild-derived` 已保留用于增量编译，存在既有 warning |
| 2026-05-12 | Phase 3 | `git diff --check -- mobile/ios/RaverMVP/RaverMVP/Features/Discover/Shared/DiscoverRepositories.swift mobile/ios/RaverMVP/RaverMVP/Application/DI/AppContainer.swift mobile/ios/RaverMVP/RaverMVP/Features/Discover/Learn/Views/LearnModuleView.swift` | 通过 | Learn/Wiki repository 小批次补丁无 whitespace error |
| 2026-05-12 | Phase 3 | `rg -n "appContainer\\.socialService\\.(fetchFollowedBrandUpdatePreference|updateFollowedBrandUpdatePreference)" mobile/ios/RaverMVP/RaverMVP/Features/Discover/Learn/Views/LearnModuleView.swift` | 通过 | `LearnFestivalDetailView` 中关注品牌动态偏好 `SocialService` 直连调用已清零 |
| 2026-05-12 | Phase 3 | `git diff --check -- mobile/ios/RaverMVP/RaverMVP/Features/Profile/ProfileViewModel.swift mobile/ios/RaverMVP/RaverMVP/Features/Profile/Views/Checkins/MyCheckinsView.swift mobile/ios/RaverMVP/RaverMVP/Application/Coordinator/MainTabCoordinator.swift` | 通过 | MyCheckins repository 小批次补丁无 whitespace error |
| 2026-05-12 | Phase 3 | `rg -n "WebFeatureService|appContainer\\.webService|reload\\(service:|loadMore\\(service:|ensureGallery.*service:|delete\\(id: .*service:" mobile/ios/RaverMVP/RaverMVP/Features/Profile/Views/Checkins/MyCheckinsView.swift` | 通过 | `MyCheckinsView` 范围内 `WebFeatureService` 直连和旧 `service` 形态调用已清零 |
| 2026-05-12 | Phase 3 | `git diff --check -- mobile/ios/RaverMVP/RaverMVP/Features/Squads/SquadProfileRepository.swift mobile/ios/RaverMVP/RaverMVP/Features/Squads/SquadProfileView.swift mobile/ios/RaverMVP/RaverMVP/Application/DI/AppContainer.swift mobile/ios/RaverMVP/RaverMVP/Application/Coordinator/MainTabCoordinator.swift` | 通过 | SquadManage repository 小批次补丁无 whitespace error |
| 2026-05-12 | Phase 3 | `rg -n "SquadManageRouteView|SquadManageFormView|webService:|socialService:|uploadSquadAvatar|uploadEventImage|fetchSquadProfile\\(|updateSquadInfo\\(" mobile/ios/RaverMVP/RaverMVP/Features/Squads/SquadProfileView.swift mobile/ios/RaverMVP/RaverMVP/Application/Coordinator/MainTabCoordinator.swift mobile/ios/RaverMVP/RaverMVP/Application/DI/AppContainer.swift mobile/ios/RaverMVP/RaverMVP/Features/Squads/SquadProfileRepository.swift` | 通过 | `SquadManage` 子流程已收口到 `SquadProfileRepository`；页面内无直接 service 注入残留 |
| 2026-05-12 | Phase 3 | `git diff --check -- mobile/ios/RaverMVP/RaverMVP/Features/Squads/SquadProfileView.swift mobile/ios/RaverMVP/RaverMVP/Application/Coordinator/MainTabCoordinator.swift` | 通过 | SquadProfile 顶层依赖收口补丁无 whitespace error |
| 2026-05-12 | Phase 3 | `rg -n "private let service: SocialService|init\\(squadID: String, service: SocialService" mobile/ios/RaverMVP/RaverMVP/Features/Squads/SquadProfileView.swift` | 通过 | `SquadProfileView` 顶层 `SocialService` 注入已清零 |
| 2026-05-12 | Phase 3 | `rg -n "private let service: SocialService|makeShareLinkService\\(|ShareLinkCoordinator\\(service:" mobile/ios/RaverMVP/RaverMVP/Features/Squads/SquadProfileView.swift` | 通过 | `SquadProfileView` 中旧 `SocialService` / `ShareLinkService` 工厂直连已清零 |
| 2026-05-12 | Phase 3 | `git diff --check -- mobile/ios/RaverMVP/RaverMVP/Features/Profile/ProfileView.swift mobile/ios/RaverMVP/RaverMVP/Features/Profile/UserProfileView.swift mobile/ios/RaverMVP/RaverMVP/Features/Feed/PostDetailView.swift mobile/ios/RaverMVP/RaverMVP/Shared/PostCardView.swift` | 通过 | ShareLink repository 小批次补丁无 whitespace error |
| 2026-05-12 | Phase 3 | `rg -n "ShareLinkCoordinator\\(service: AppEnvironment\\.makeShareLinkService\\(\\)\\)|makeShareLinkService\\(" mobile/ios/RaverMVP/RaverMVP/Features/Profile/ProfileView.swift mobile/ios/RaverMVP/RaverMVP/Features/Profile/UserProfileView.swift mobile/ios/RaverMVP/RaverMVP/Features/Feed/PostDetailView.swift mobile/ios/RaverMVP/RaverMVP/Shared/PostCardView.swift` | 通过 | 目标范围内旧 `ShareLinkService` 工厂直连已清零 |
| 2026-05-12 | Phase 3 | `git diff --check -- mobile/ios/RaverMVP/RaverMVP/Features/Discover/Events/Views/EventDetailView.swift mobile/ios/RaverMVP/RaverMVP/Features/Discover/Sets/Views/SetsModuleView.swift mobile/ios/RaverMVP/RaverMVP/Features/Discover/News/Views/DiscoverNewsDetailView.swift mobile/ios/RaverMVP/RaverMVP/Features/Discover/DJs/Views/DJsModuleView.swift mobile/ios/RaverMVP/RaverMVP/Features/Discover/Learn/Views/LearnModuleView.swift mobile/ios/RaverMVP/RaverMVP/Features/MainTabView.swift` | 通过 | Discover / MainTab ShareLink repository 批次补丁无 whitespace error |
| 2026-05-12 | Phase 3 | `rg -n "ShareLinkCoordinator\\(service: AppEnvironment\\.makeShareLinkService\\(\\)\\)" mobile/ios/RaverMVP/RaverMVP` | 通过 | 页面层旧 `ShareLinkCoordinator(service: ...)` 工厂直连已清零；剩余 `makeShareLinkService()` 仅在 AppCoordinator / AppEnvironment 基础设施层 |
| 2026-05-12 | Phase 3 | `git diff --check -- mobile/ios/RaverMVP/RaverMVP/Features/Messages/MessagesViewModel.swift mobile/ios/RaverMVP/RaverMVP/Features/Profile/UserProfileView.swift` | 通过 | UserProfile 私信 repository 小批次补丁无 whitespace error |
| 2026-05-12 | Phase 3 | `rg -n "startDirectConversation\\(|appContainer\\.socialService\\.startDirectConversation" mobile/ios/RaverMVP/RaverMVP/Features/Profile/UserProfileView.swift mobile/ios/RaverMVP/RaverMVP/Features/Messages/MessagesViewModel.swift` | 通过 | `UserProfileView` 私信入口已切到 `MessagesRepository`，页面内无 `socialService.startDirectConversation` 直连残留 |
| 2026-05-12 | Phase 3 | `git diff --check -- mobile/ios/RaverMVP/RaverMVP/Core/ShareMessageRepository.swift mobile/ios/RaverMVP/RaverMVP/Features/MainTabView.swift` | 通过 | MainTab 分享消息 repository 小批次补丁无 whitespace error |
| 2026-05-12 | Phase 3 | `rg -n "loadCircleIDSharePanelConversations\\(using: socialService\\)|sendCircleIDSharePayload\\(.*using: socialService|loadRatingSharePanelConversations\\(using: appContainer\\.socialService\\)|sendRatingSharePayload\\(.*using: appContainer\\.socialService" mobile/ios/RaverMVP/RaverMVP/Features/MainTabView.swift` | 通过 | `MainTabView` 中 Circle ID / Rating 分享面板 `socialService` 直连调用已清零 |
| 2026-05-12 | Phase 3 | `git diff --check -- mobile/ios/RaverMVP/RaverMVP/Features/Auth/LoginView.swift` | 通过 | Login avatar upload repository 小批次补丁无 whitespace error |
| 2026-05-12 | Phase 3 | `rg -n "appContainer\\.socialService\\.uploadMyAvatar|appContainer\\.profileSocialRepository\\.uploadMyAvatar" mobile/ios/RaverMVP/RaverMVP/Features/Auth/LoginView.swift` | 通过 | `LoginView` 头像上传已切到 `ProfileSocialRepository` |
| 2026-05-12 | Phase 3 | `git diff --check -- mobile/ios/RaverMVP/RaverMVP/Features/Profile/ProfileViewModel.swift mobile/ios/RaverMVP/RaverMVP/Features/Profile/Views/RatingEditors/RatingEditors.swift` | 通过 | RatingEditors repository 小批次补丁无 whitespace error |
| 2026-05-12 | Phase 3 | `rg -n "WebFeatureService|appContainer\\.webService|save\\(service:|uploadRatingImage\\(|updateRatingEvent\\(|updateRatingUnit\\(" mobile/ios/RaverMVP/RaverMVP/Features/Profile/Views/RatingEditors/RatingEditors.swift mobile/ios/RaverMVP/RaverMVP/Features/Profile/ProfileViewModel.swift` | 通过 | `RatingEditors` 页面侧已切到 `ProfileSocialRepository`；`webService` 仅保留在 repository adapter 底层 |
| 2026-05-12 | Phase 3 | `git diff --check -- mobile/ios/RaverMVP/RaverMVP/Features/Discover/Events/ViewModels/EventsModuleViewModel.swift mobile/ios/RaverMVP/RaverMVP/Application/DI/AppContainer.swift mobile/ios/RaverMVP/RaverMVP/Features/Discover/Events/Views/EventDetailView.swift mobile/ios/RaverMVP/RaverMVP/Application/Coordinator/MainTabCoordinator.swift` | 通过 | Event live discussion repository 小批次补丁无 whitespace error |
| 2026-05-12 | Phase 3 | `rg -n "let service: SocialService|let webService: WebFeatureService|service\\.fetchEventLiveComments|service\\.addEventLiveComment|service\\.toggleEventLiveCommentLike|webService\\.fetchEvent|webService\\.uploadPostImage|repository: appContainer\\.discoverEventsRepository" mobile/ios/RaverMVP/RaverMVP/Features/Discover/Events/Views/EventDetailView.swift mobile/ios/RaverMVP/RaverMVP/Application/Coordinator/MainTabCoordinator.swift` | 通过 | `EventLiveDiscussionView` 已切到 `DiscoverEventsRepository`；路由端已改为 repository 注入 |
| 2026-05-12 | Phase 3 | `git diff --check -- mobile/ios/RaverMVP/RaverMVP/Features/Discover/Events/ViewModels/EventsModuleViewModel.swift mobile/ios/RaverMVP/RaverMVP/Features/MainTabView.swift mobile/ios/RaverMVP/RaverMVP/Features/Circle/Coordinator/CircleCoordinator.swift mobile/ios/RaverMVP/RaverMVP/Application/Coordinator/MainTabCoordinator.swift` | 通过 | Rating creation repository 小批次补丁无 whitespace error |
| 2026-05-12 | Phase 3 | `rg -n "webService\\.fetchEvents|webService\\.uploadRatingImage|appContainer\\.webService\\.createRatingEvent|appContainer\\.webService\\.createRatingEventFromEvent|appContainer\\.webService\\.createRatingUnit|discoverEventsRepository\\.createRatingEvent|discoverEventsRepository\\.createRatingEventFromEvent|discoverEventsRepository\\.createRatingUnit" mobile/ios/RaverMVP/RaverMVP/Features/MainTabView.swift mobile/ios/RaverMVP/RaverMVP/Features/Circle/Coordinator/CircleCoordinator.swift mobile/ios/RaverMVP/RaverMVP/Application/Coordinator/MainTabCoordinator.swift` | 通过 | 评分创建流的 `webService` 构造层直连已切到 `DiscoverEventsRepository`；剩余 `webService.fetchEvents` 命中来自其他未处理子流 |
| 2026-05-12 | Phase 3 | `git diff --check -- mobile/ios/RaverMVP/RaverMVP/Features/MainTabView.swift` | 通过 | CircleID event picker repository 小批次补丁无 whitespace error |
| 2026-05-12 | Phase 3 | `rg -n "CircleIDEventPickerSheet|webService\\.fetchEvents|private var repository: DiscoverEventsRepository" mobile/ios/RaverMVP/RaverMVP/Features/MainTabView.swift` | 通过 | `CircleIDEventPickerSheet` 已切到 `DiscoverEventsRepository`；该 sheet 内无 `webService.fetchEvents` 残留 |
| 2026-05-12 | Phase 3 | `git diff --check -- docs/IOS_REPOSITORY_NAMING_AND_MODULE_GUIDE.md docs/RAVER_COMMERCIAL_ARCHITECTURE_RESTRUCTURE_TRACKER.md docs/RAVER_COMMERCIAL_ARCHITECTURE_RESTRUCTURE_PLAN.md mobile/ios/RaverMVP/RaverMVP/Application/Coordinator/MainTabCoordinator.swift mobile/ios/RaverMVP/RaverMVP/Features/Discover/Events/ViewModels/EventsModuleViewModel.swift mobile/ios/RaverMVP/RaverMVP/Features/MainTabView.swift` | 通过 | Fat Repository 规则、Profile loader、CircleID DJ picker 补丁无 whitespace error |
| 2026-05-12 | Phase 3 | `plutil -lint mobile/ios/RaverMVP/RaverMVP.xcodeproj/project.pbxproj` | 通过 | Xcode project 文件仍可解析 |
| 2026-05-12 | Phase 3 | `rg -n "Profile(Event\\|Set\\|RatingEvent\\|RatingUnit)EditorLoaderView...|webService\\.fetchDJs|appContainer\\.socialService\\.(fetchConversations|sendPostCardMessage|sendMessage|recordShare)" ...` | 通过 | Profile 编辑 loader、CircleID DJ picker、PostCardView 目标直连已清零 |
| 2026-05-12 | Phase 3 | `xcodebuild -workspace mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/raver-xcodebuild-derived build` | 通过 | 本批统一 iOS build 通过；`/tmp/raver-xcodebuild-derived` 已保留，存在既有 warning |
| 2026-05-12 | Phase 3 | `rm -f /tmp/raver_phase3_build.log` | 通过 | 清理本轮一次性 build 日志，未删除 DerivedData 缓存 |
| 2026-05-12 | Phase 3 | `git restore -- mobile/ios/RaverMVP/RaverMVP.xcworkspace/xcuserdata/blackie.xcuserdatad/UserInterfaceState.xcuserstate` | 通过 | 恢复 Xcode 用户态构建噪声；不影响架构代码 |
| 2026-05-12 | Phase 3 | `git diff --check -- mobile/ios/RaverMVP/RaverMVP/Features/Notifications/NotificationRepository.swift mobile/ios/RaverMVP/RaverMVP/Features/Notifications/NotificationsView.swift` | 通过 | Notifications mock repository / preview seam 补丁无 whitespace error |
| 2026-05-12 | Phase 3 | `rg -n "MockNotificationRepository|Notifications Repository Seam|phase3Preview|NotificationsViewModel\\(repository: MockNotificationRepository" mobile/ios/RaverMVP/RaverMVP/Features/Notifications` | 通过 | Notifications 已具备可 mock repository preview seam |
| 2026-05-12 | Phase 3 | `xcodebuild -workspace mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/raver-xcodebuild-derived build` | 通过 | Phase 3 closure build 通过；`/tmp/raver-xcodebuild-derived` 已保留，存在既有 warning |
| 2026-05-12 | Phase 4 | `rg -n "MessagesRepository|MessagesRepositoryAdapter|appContainer\\.messagesRepository|MessagesCoordinatorView\\(repository:|MessagesViewModel\\(repository:" mobile/ios/RaverMVP/RaverMVP -g '*.swift'` | 通过 | 旧 Messages fat repository 命名和构造入口已清零 |
| 2026-05-12 | Phase 4 | `git diff --check -- <Phase 4 Messages repository split files>` | 通过 | Messages repository split 补丁无 whitespace error |
| 2026-05-12 | Phase 4 | `plutil -lint mobile/ios/RaverMVP/RaverMVP.xcodeproj/project.pbxproj` | 通过 | Xcode project 文件仍可解析 |
| 2026-05-12 | Phase 4 | `xcodebuild -workspace mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/raver-xcodebuild-derived build` | 通过 | Phase 4 Messages repository split 编译通过；`/tmp/raver-xcodebuild-derived` 已保留 |
| 2026-05-12 | Phase 4 | `rm -f /tmp/raver_phase4_messages_build.log` | 通过 | 清理一次性 build 日志，未删除 DerivedData 缓存 |
| 2026-05-12 | Phase 4 | `rg -n "../services/tencent-im|../../services/tencent-im|services/tencent-im" server/src -g '*.ts'` | 通过 | 业务层直接引用 Tencent IM provider 已清零；仅 `modules/im/index.ts` 作为 facade 引用底层实现 |
| 2026-05-12 | Phase 4 | `cd server && pnpm build` | 通过 | 后端 IM module facade、OpenIM legacy marker 和 import boundary 切换编译通过 |
| 2026-05-12 | Phase 4 | `git diff --check -- <Phase 4 ChatSettings repository files>` | 通过 | ChatSettings repository 批次补丁无 whitespace error |
| 2026-05-12 | Phase 4 | `plutil -lint mobile/ios/RaverMVP/RaverMVP.xcodeproj/project.pbxproj` | 通过 | Xcode project 文件仍可解析 |
| 2026-05-12 | Phase 4 | `xcodebuild -workspace mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/raver-xcodebuild-derived build` | 通过 | Phase 4 ChatSettings repository 批次编译通过；`/tmp/raver-xcodebuild-derived` 已保留 |
| 2026-05-12 | Phase 4 | `rm -f /tmp/raver_phase4_chat_settings_build.log` | 通过 | 清理一次性 build 日志，未删除 DerivedData 缓存 |
| 2026-05-12 | Phase 4 | `git diff --check -- <Phase 4 Squad offline activity repository files>` | 通过 | Squad offline activity repository 批次补丁无 whitespace error |
| 2026-05-12 | Phase 4 | `plutil -lint mobile/ios/RaverMVP/RaverMVP.xcodeproj/project.pbxproj` | 通过 | Xcode project 文件仍可解析 |
| 2026-05-12 | Phase 4 | `xcodebuild -workspace mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/raver-xcodebuild-derived build` | 通过 | Phase 4 Squad offline activity repository 批次编译通过；`/tmp/raver-xcodebuild-derived` 已保留 |
| 2026-05-12 | Phase 4 | `rg -n "currentService|dataProvider\\.currentService|updateContext\\(conversation: Conversation, service:|RaverChatDataProvider\\([^\\)]*service:" mobile/ios/RaverMVP/RaverMVP/Features/Messages/UIKitChat -g '*.swift'` | 通过 | UIKit chat message controller / data provider 已无 `SocialService` 消息主线直连残留 |
| 2026-05-12 | Phase 4 | `git diff --check -- <Phase 4 ChatMessageRepository files>` | 通过 | ChatMessageRepository 批次补丁无 whitespace error |
| 2026-05-12 | Phase 4 | `plutil -lint mobile/ios/RaverMVP/RaverMVP.xcodeproj/project.pbxproj` | 通过 | Xcode project 文件仍可解析 |
| 2026-05-12 | Phase 4 | `xcodebuild -workspace mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/raver-xcodebuild-derived build` | 通过 | Phase 4 ChatMessageRepository 批次编译通过；`/tmp/raver-xcodebuild-derived` 已保留 |
| 2026-05-12 | Phase 4 | `rm -f /tmp/raver_phase4_chat_message_build.log` | 通过 | 清理一次性 build 日志，未删除 DerivedData 缓存 |
| 2026-05-12 | Phase 4 | `git diff --check -- mobile/ios/RaverMVP/RaverMVP.xcodeproj/project.pbxproj mobile/ios/RaverMVP/RaverMVP/Infrastructure mobile/ios/RaverMVP/RaverMVP/Core mobile/ios/RaverMVP/RaverMVP/Features/Messages/UIKitChat` | 通过 | iOS Infrastructure 目录归位批次无 whitespace error |
| 2026-05-12 | Phase 4 | `plutil -lint mobile/ios/RaverMVP/RaverMVP.xcodeproj/project.pbxproj` | 通过 | Xcode project 文件仍可解析 |
| 2026-05-12 | Phase 4 | `xcodebuild -workspace mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/raver-xcodebuild-derived build` | 通过 | Phase 4 iOS Infrastructure 目录归位编译通过；`/tmp/raver-xcodebuild-derived` 已保留 |
| 2026-05-12 | Phase 4 | `rm -f /tmp/raver_phase4_infrastructure_build.log` | 通过 | 清理一次性 build 日志，未删除 DerivedData 缓存 |
| 2026-05-13 | Phase 5 | `git diff --check -- docs/RAVER_BACKEND_MODULE_OWNERSHIP.md docs/RAVER_COMMERCIAL_ARCHITECTURE_RESTRUCTURE_TRACKER.md` | 通过 | Phase 5 closure 文档补丁无 whitespace error |
| 2026-05-13 | Phase 5 | `rg -n "prisma\\.feedEvent\\.create|prisma\\.post(Like|Repost|Save|Share|Hide)\\.(create|delete|update|upsert)|prisma\\.postComment" server/src/routes/bff.routes.ts` | 通过 | BFF 中 FeedEvent / PostInteraction / PostComment 目标直写模式已清零 |
| 2026-05-13 | Phase 5 | `cd server && pnpm build` | 通过 | Phase 5 backend content module facade、FeedEvent、PostInteraction、PostComment service extraction closure build 通过 |
| 2026-05-13 | Phase 5 | `ls /tmp/raver_phase5_closure_build.log` | 通过 | 一次性 closure build log 已不存在；未删除 `/tmp/raver-xcodebuild-derived` |
| 2026-05-13 | Phase 5 | `curl -sS -o /tmp/raver_phase5_feed_latest_smoke.json -w '%{http_code}' 'http://127.0.0.1:3901/v1/feed?limit=3&mode=latest'` | 通过 | 返回 200；临时 response 文件已删除 |
| 2026-05-13 | Phase 5 | `curl -sS -o /tmp/raver_phase5_feed_recommended_smoke.json -w '%{http_code}' 'http://127.0.0.1:3901/v1/feed?limit=3&mode=recommended'` | 通过 | 返回 200；临时 response 文件已删除 |
| 2026-05-13 | Phase 5 | `curl -sS -o /tmp/raver_phase5_comments_smoke.json -w '%{http_code}' 'http://127.0.0.1:3901/v1/feed/posts/f6d59245-01c3-4764-af2c-61ed0ed99f03/comments'` | 通过 | 返回 200；临时 response 文件已删除 |
| 2026-05-13 | Phase 5 | `xcodebuild -workspace mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/raver-xcodebuild-derived build` | 通过 | Feed smoke local-state fix 编译通过；`/tmp/raver-xcodebuild-derived` 已保留 |
| 2026-05-13 | Phase 5 | `rm -f /tmp/raver_phase5_feed_smoke_fix_build.log` | 通过 | 清理一次性 build 日志，未删除 DerivedData 缓存 |
| 2026-05-13 | Phase 5 | `curl -sS -o /tmp/raver_phase5_auth_recommended_smoke.json -w 'status=%{http_code} time=%{time_total}\\n' -H "Authorization: Bearer <local-smoke-token>" 'http://127.0.0.1:3901/v1/feed?limit=12&mode=recommended'` | 通过 | 带登录态 recommended Feed 返回 200，约 0.08s；临时 response 文件已删除 |
| 2026-05-13 | Phase 5 | `xcodebuild -workspace mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/raver-xcodebuild-derived build` | 通过 | Feed/comment cancellation handling fix 编译通过；`/tmp/raver-xcodebuild-derived` 已保留 |
| 2026-05-13 | Phase 5 | `rm -f /tmp/raver_phase5_feed_cancellation_fix_build.log` | 通过 | 清理一次性 build 日志，未删除 DerivedData 缓存 |
| 2026-05-13 | Phase 5 | 用户真实运行 smoke | 通过 | Feed 发布/刷新/点赞/收藏/评论、Event 详情、DJ 详情、Set 详情均通过；Phase 5 可关闭 |
| 2026-05-13 | Phase 6 | `git diff --check -- docs/RAVER_ADMIN_OPERATIONS_PHASE6_INVENTORY.md docs/RAVER_COMMERCIAL_ARCHITECTURE_RESTRUCTURE_TRACKER.md docs/README.md` | 通过 | Phase 6 P0 只改文档；不需要后端 / Web / iOS build，不需要数据库备份 |
| 2026-05-13 | Phase 6 | `git diff --check -- server/src/modules/admin/README.md server/src/modules/admin/admin.routes.ts server/src/modules/admin/index.ts server/src/index.ts docs/RAVER_ADMIN_OPERATIONS_PHASE6_INVENTORY.md docs/RAVER_COMMERCIAL_ARCHITECTURE_RESTRUCTURE_TRACKER.md docs/RAVER_BACKEND_MODULE_OWNERSHIP.md docs/README.md` | 通过 | Admin facade 代码和文档补丁无 whitespace error |
| 2026-05-13 | Phase 6 | `cd server && pnpm build` | 通过 | Admin `/api/admin/v1` facade 编译通过；旧入口保留兼容，不涉及数据库 |
| 2026-05-13 | Phase 6 | `cd server && pnpm build` | 通过 | Shared admin auth / role policy 编译通过；不涉及数据库 |
| 2026-05-13 | Phase 6 | `cd web && pnpm build` | 通过 | Web admin client alignment 编译通过；仅有既有 lint warning |
| 2026-05-13 | Phase 6 | `cd server && pnpm build` | 通过 | Admin audit query endpoint 编译通过；只读现有表，不涉及数据库迁移 |
| 2026-05-13 | Phase 6 | `cd web && pnpm build` | 通过 | Admin audit API client 编译通过；未新增页面，仅有既有 lint warning |
| 2026-05-13 | Phase 6 | `git diff --check -- server/src/modules/admin/admin-status.service.ts server/src/modules/admin/admin.routes.ts server/src/modules/admin/index.ts server/src/modules/admin/README.md server/src/services/notification-center/notification-outbox.scheduler.ts web/src/lib/api/admin-status.ts docs/RAVER_ADMIN_OPERATIONS_PHASE6_INVENTORY.md docs/RAVER_COMMERCIAL_ARCHITECTURE_RESTRUCTURE_TRACKER.md` | 通过 | Admin status backend aggregation 补丁无 whitespace error |
| 2026-05-13 | Phase 6 | `cd server && pnpm build` | 通过 | `/api/admin/v1/status` 只读聚合 endpoint 编译通过；不触发 worker/rebuild，不涉及数据库迁移 |
| 2026-05-13 | Phase 6 | `cd web && pnpm build` | 通过 | Admin status API client 编译通过；仅有既有 React hook / `<img>` warning |
| 2026-05-13 | Phase 6 | `git diff --check -- web/src/app/admin/page.tsx web/src/app/admin/notification-center/page.tsx web/src/app/admin/pre-registrations/page.tsx web/src/components/Navigation.tsx docs/RAVER_ADMIN_OPERATIONS_PHASE6_INVENTORY.md docs/RAVER_COMMERCIAL_ARCHITECTURE_RESTRUCTURE_TRACKER.md` | 通过 | Web Admin shell status entry 补丁无 whitespace error |
| 2026-05-13 | Phase 6 | `cd web && pnpm build` | 通过 | `/admin` 运营总览页面编译通过；仅有既有 React hook / `<img>` warning |
| 2026-05-13 | Phase 6 | `git diff --check -- web/src/lib/api/openim-admin.ts web/src/app/community/openim/page.tsx web/src/components/Navigation.tsx docs/RAVER_ADMIN_OPERATIONS_PHASE6_INVENTORY.md docs/RAVER_PLATFORM_ARCHITECTURE.md docs/README.md docs/RAVER_COMMERCIAL_ARCHITECTURE_RESTRUCTURE_TRACKER.md` | 通过 | OpenIM legacy / deferred cleanup 补丁无 whitespace error |
| 2026-05-13 | Phase 6 | `cd web && pnpm build` | 通过 | OpenIM Legacy 页面/导航文案编译通过；仅有既有 React hook / `<img>` warning |
| 2026-05-13 | Phase 7 | `git diff --check -- web/src/lib/admin/role-policy.ts web/src/app/admin/content-cms/page.tsx web/src/app/admin/page.tsx web/src/components/Navigation.tsx web/next.config.js docs/RAVER_CONTENT_CMS_UNIFIED_ADMIN_PLAN.md docs/RAVER_COMMERCIAL_ARCHITECTURE_RESTRUCTURE_TRACKER.md docs/README.md` | 通过 | Content CMS 统一入口、role policy、Next rewrites 和文档补丁无 whitespace error |
| 2026-05-13 | Phase 7 | `cd web && pnpm build` | 通过 | `/admin/content-cms` 和 `/admin` 后台工作台编译通过；仅有既有 React hook / `<img>` warning |
| 2026-05-13 | Phase 7 | 数据库动作检查 | 通过 | 本批只改 Web shell、Next rewrites 和文档，未执行 schema/data migration、backfill、projection rebuild、snapshot rebuild、IM sync apply 或批量修复，因此不需要新增数据库备份 |
| 2026-05-13 | Phase 7 | `git diff --check -- web/src/app/admin/content-cms/page.tsx docs/RAVER_CONTENT_CMS_UNIFIED_ADMIN_PLAN.md docs/RAVER_COMMERCIAL_ARCHITECTURE_RESTRUCTURE_TRACKER.md` | 通过 | 按用户要求取消 iframe 内嵌，`/admin/content-cms` 改为登录态同步后跳转完整 `/admin/festival-viewer.html` 页面 |
| 2026-05-13 | Phase 7 | `cd web && pnpm build` | 通过 | Content CMS 跳转桥接页编译通过；仅有既有 React hook / `<img>` warning |

常用验证候选：

```bash
cd server && pnpm build
cd server && pnpm auth:smoke
cd server && pnpm checkins:projection:freshness
cd server && pnpm share-links:smoke
cd web && pnpm build
```

iOS 验证应记录 Xcode scheme、设备或模拟器、关键路径结果。

---

## 9. 决策记录摘要

| 时间 | 决策 | 原因 | 后续 ADR |
| --- | --- | --- | --- |
| 2026-05-12 | iOS Native 是当前主客户端 | 当前真实产品体验集中在 iOS App | `docs/adr/0001-app-first-ios-native.md` |
| 2026-05-12 | Tencent IM 是当前 IM 主线 | 仓库已有 Tencent IM bootstrap / usersig / routes / services | `docs/adr/0002-tencent-im-as-current-im-provider.md` |
| 2026-05-12 | Check-in v2 projection 是当前打卡主线 | MyCheckins 已采用 strict read model 和 projection worker | `docs/adr/0003-checkin-v2-projection-read-model.md` |
| 2026-05-12 | Notification Center 是当前通知主线 | 新通知系统已包含 inbox、delivery、APNs、template、scheduler | `docs/adr/0004-notification-center-current-system.md` |
| 2026-05-12 | 本轮先做模块化单体，不拆微服务 | 当前最大问题是边界和组织方式，不是独立部署 | `docs/adr/0005-modular-monolith-before-microservices.md` |
| 2026-05-12 | Web 定位为 Admin / CMS / Public fallback | 当前主客户端是 iOS，Web 更适合承载运营和公开页 | `docs/adr/0006-admin-console-over-public-web-first.md` |
| 2026-05-12 | 新需求默认进入 deferred | 防止架构改造路线漂移 | 已写入 tracker 和改造总方案 |
