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
| Phase 3 | iOS Repository 层收束 | `[~]` | 2026-05-12 |  | Notifications / VirtualAssets / Share / Search / SquadProfile / Feed repository 批次已完成；继续按同类逻辑批量改造后统一 build |
| Phase 4 | IM 和 Squad 收束 | `[ ]` |  |  | 数据迁移或同步 apply 前必须备份 |
| Phase 5 | Feed / Events / Music 大领域收束 | `[ ]` |  |  | 数据回填、索引或 migration 前必须备份 |
| Phase 6 | Admin / Operations 商用化 | `[ ]` |  |  |  |

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

- [~] 建立 Repository 边界；当前沿用现有 `Features/*` / `Core` 布局，暂不强行大规模挪目录。
- [x] 从 Notifications、VirtualAssets、Share 开始迁移。
- [x] Notifications ViewModel 改为依赖 `NotificationRepository` protocol。
- [x] VirtualAssets 已确认具备 `VirtualAssetRepository` protocol / live / disabled / mock 形态，本轮不重复迁移。
- [x] Share 建立 `ShareLinkRepository` protocol 和 adapter，`ShareLinkCoordinator` 改为依赖 repository，同时保留 `ShareLinkService` initializer 兼容旧调用。
- [~] 为 Event、DJ、Set、Feed、Squad 定义 repository protocol；Discover Event/DJ/Set 已有 repository，Feed 已扩展到列表/发布/详情，SquadProfile 主 ViewModel 已迁移。
- [~] `SocialService`、`WebFeatureService`、`ShareLinkService` 暂时降级为底层 API client；当前已减少 Notifications / Share / Search / SquadProfile / Feed 直接依赖。
- [x] 更新 tracker log，记录每个迁移模块的 ViewModel 调整范围。

验收：

- [x] Notifications ViewModel 依赖 Repository protocol。
- [~] 旧 service 调用逐步减少；当前已减少 Notifications / Share / Search / SquadProfile / Feed 直接依赖。
- [~] 单个模块可 mock repository 做预览和测试；Notifications / Share / Search / SquadProfile / Feed 已具备 protocol seam，后续补 mock preview/test。
- [x] iOS 编译通过。

### Phase 4：IM 和 Squad 收束

目标：明确 Tencent IM 主线，隔离 OpenIM 历史兼容。

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

## 3. 当前执行路径

当前阶段：Phase 3 in progress

当前焦点：

1. Phase 0 / Phase 1 / Phase 2 已完成。
2. Phase 3 正在进行：iOS Repository 层收束。
3. 当前采用“同类逻辑批量迁移 + 单次统一 build”节奏：先按 repository 边界批量处理相近模块，再统一编译验证，避免每改一处都 build。
4. iOS build 使用固定 `-derivedDataPath /tmp/raver-xcodebuild-derived` 复用增量编译缓存；默认不清理该目录。
5. 本轮不涉及数据库结构变更或数据动作，不需要数据库备份。

下一步建议：

1. 继续为剩余直接依赖 `SocialService` / `WebFeatureService` 的 iOS 页面定义 repository protocol。
2. 优先选择 ViewModel 直接依赖 `SocialService` / `WebFeatureService` 的小模块切入。
3. 避免在 Phase 3 中新增分享玩法、推荐策略、页面功能或 UI 重设计。

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
