# Event 编辑 / Timetable 重构数据库与接口变更清单

更新时间：2026-05-29  
关联文档：

- [EVENT_EDIT_TIMETABLE_REARCHITECTURE_PLAN.md](/Users/blackie/Projects/raver/docs/EVENT_EDIT_TIMETABLE_REARCHITECTURE_PLAN.md)
- [EVENT_EDIT_MIXED_UPDATE_FULL_FLOW.md](/Users/blackie/Projects/raver/docs/EVENT_EDIT_MIXED_UPDATE_FULL_FLOW.md)

---

## 1. 文档目标

这份文档承接总方案，专门回答三件事：

1. 数据库层到底要怎么改
2. API / payload 契约到底要怎么改
3. worker / job / 状态机要怎么改

目标是把总方案再往前推进一层，形成可以直接进入：

- schema 设计
- migration 编写
- route/service 改造
- iOS payload 对齐
- 联调验收

的实施清单。

---

## 2. 总体设计原则

## 2.1 保留的东西

以下能力不推翻：

- `events`
- `event_weeks`
- `event_days`
- `event_stages`
- `event_artists`
- `event_artist_members`
- `event_performances`
- `content_submissions`
- `content_submission_processing_jobs`

也就是说，这次不是重做模型，而是：

- 重排职责
- 简化编辑协议
- 引入 timetable apply job
- 为 performance 写入补上幂等语义

## 2.2 删除或废弃的东西

以下协议能力应逐步废弃：

- `editMode = "patch"`
- `lineupChanges`
- `timetableChanges`
- `stageChanges`
- `incrementalBaseline`
- `baseEventRevision`

这些字段和逻辑不是“立刻删库”，而是：

- 先停止客户端发送
- 再停止服务端主路径依赖
- 最后清理死代码和兼容层

---

## 3. 数据库层变更

## 3.1 `events` 表

当前主要字段：

- `startDate`
- `endDate`
- `scheduleMode`
- `timeZone`
- `startTime`
- `endTime`
- `dayRolloverHour`
- `revision`

### 目标变化

`events` 表不做结构性大改。

建议：

- [ ] 保留 `revision`，但它不再作为客户端 patch 提交门槛
- [ ] `revision` 改成纯服务端内部版本号，用于：
  - 运维追踪
  - 异步 apply job 对账
  - timetable job 过期判断

### 建议新增字段

建议增加下面这些观测字段中的一部分：

- [ ] `timetableSyncStatus String?`
- [ ] `timetableSyncRequestedAt DateTime?`
- [ ] `timetableSyncCompletedAt DateTime?`
- [ ] `timetableSyncError String?`

推荐语义：

- `pending`
- `running`
- `succeeded`
- `failed`

### 为什么建议加

因为在 P2 之后：

- event 主结构可能已写成功
- timetable canonical apply 仍在异步执行

此时必须有一个 event 维度的可观测状态。

### 是否强制

不是绝对强制。

如果短期不想改 `events` 表，也可以只把状态放在 job metadata 里。
但中长期建议落 event 级别字段，方便：

- 管理后台
- 详情页诊断
- 运营追踪

## 3.2 `event_weeks` 表

不需要结构性改表。

目标是：

- [ ] 保持作为 schedule 主结构的一部分
- [ ] 继续由同步短事务负责

不建议把它并入异步层。

## 3.3 `event_days` 表

不需要结构性改表。

目标是：

- [ ] 继续作为 `timetable slot -> eventDayId` 的唯一锚点
- [ ] 继续由同步短事务负责

### 注意

后续 timetable async apply 时，`event_days` 将成为 worker 的事实来源。

因此 worker 必须只使用已经成功落库的 `event_days`，而不能依赖旧 payload 自己推导。

## 3.4 `event_stages` 表

建议不改表结构。

但需要调整写入语义：

- [ ] 不再依赖 patch rename/delete 语义
- [ ] 改成 full desired-state + 后端幂等 reconcile

### 建议增加约束检查

当前已有：

- `@@unique([eventId, normalizedName])`

建议保留。

这是后续 stage 幂等匹配的关键。

## 3.5 `event_artists` / `event_artist_members`

建议不改表结构。

需要改的是写入策略：

- [ ] 从 patch-merge 驱动改为 full desired-state normalize
- [ ] artist identity 的匹配仍在服务端内部做

### 说明

当前最大的复杂点不在 artist 表结构本身，而在：

- 客户端既能发 full，又能发 patch
- 服务端既要 diff，又要 merge

这次改造后，artist 表可以继续保留原模型。

## 3.6 `event_performances`

这是本次数据库改造的核心表。

当前字段重点：

- `eventId`
- `eventArtistId`
- `stageId`
- `eventDayId`
- `weekIndex`
- `dayIndexInWeek`
- `overallDayIndex`
- `localDate`
- `startAt`
- `endAt`
- `sortOrder`

### 目标变化

需要为它补上“幂等 slot identity”语义。

### 建议新增字段

方案 A：

- [ ] 新增 `deletedAt DateTime? @map("deleted_at")`

用途：

- worker retry 时支持软删除
- 便于对账
- 便于排查大批量 slot 变更

方案 B：

- [ ] 不加 `deletedAt`，只做物理删除

建议优先方案 A。

### 建议新增索引 / 唯一键

推荐候选幂等键：

- `eventId`
- `eventDayId`
- `startAt`
- `stageId`

目标是表达：

- 同一 event 的同一 eventDay
- 同一 stage
- 同一开始时间

只能有一个 slot。

### 需要确认的问题

- [ ] 是否允许同一 stage 同一开始时间并行两个不同 artist 的合法业务场景
- [ ] 如果允许，就需要把 `eventArtistId` 也并入幂等键
- [ ] 如果不允许，目前建议键可成立

### 推荐 migration 方向

- [ ] 若采用软删除：
  - 加 `deleted_at`
  - 幂等唯一索引考虑只对 `deleted_at IS NULL` 生效
- [ ] 若采用物理删除：
  - 直接上组合唯一索引

### 推荐查询约定

一旦引入 `deletedAt`：

- [ ] 所有查询 `event_performances` 的路径都必须补 `deletedAt IS NULL`
- [ ] 包括详情页 timetable
- [ ] 包括 admin / export / feed / analytics

## 3.7 `content_submissions`

表结构不需要大改。

但语义要改：

- [ ] submission 从“所有 event edit 必经之路”改成“需要审核时才使用”

建议保留：

- 审计
- 版本历史
- review notes

不建议继续把它当：

- 所有编辑都必须包一层的同步入口

## 3.8 `content_submission_processing_jobs`

这是后续复用的关键。

### 当前状态

已有 durable job 表。

### 目标变化

新增或复用新的 job type：

- [ ] `apply_event_timetable`

### 建议 metadata 字段内容

建议 job `metadata` 里统一存：

- `eventId`
- `submissionId`
- `jobPhase`
- `payloadHash`
- `requestedBy`
- `targetEventRevision`
- `scheduleFingerprint`
- `attemptReason`

### 为什么要这些字段

用于判断：

- 这个 job 是不是过时的
- 当前 event 主结构是否已经变了
- retry 是否在处理同一批数据

---

## 4. Migration 拆解建议

## 4.1 Migration 1：Event timetable observability

目标：

- [ ] 给 `events` 增加 timetable 同步状态字段

建议内容：

- `timetable_sync_status`
- `timetable_sync_requested_at`
- `timetable_sync_completed_at`
- `timetable_sync_error`

## 4.2 Migration 2：Performance soft delete + idempotency support

目标：

- [ ] 给 `event_performances` 增加 `deleted_at`
- [ ] 增加幂等索引

## 4.3 Migration 3：Job type and metadata normalization

目标：

- [ ] 补充 worker 所需索引
- [ ] 确保 `apply_event_timetable` job 查询高效

## 4.4 Migration 4：后续清理 migration

目标：

- [ ] 如果 patch 协议完全废弃，则不需要 DB 层动作
- [ ] 只做代码清理

---

## 5. API 契约层变更

## 5.1 iOS -> BFF Event Edit Payload

当前 `UpdateEventInput` 里有三类字段：

### 保留字段

- [ ] 基础 event metadata
- [ ] `schedule`
- [ ] `weeks`
- [ ] `eventDays`
- [ ] `lineupArtists`
- [ ] `lineupSlots`
- [ ] `stageOrder`
- [ ] `lineupSyncMode`
- [ ] `imageAssets`
- [ ] `ticketTiers`

### 废弃字段

- [x] iOS event edit 主路径已停止生成 `baseEventRevision`
- [x] iOS event edit 主路径已停止生成 `editMode`
- [x] iOS event edit 主路径已停止生成 `lineupChanges`
- [x] iOS event edit 主路径已停止生成 `timetableChanges`
- [x] iOS event edit 主路径已停止生成 `stageChanges`
- [x] iOS event edit 主路径已停止生成 `clearTimetableChanges`
- [x] iOS event edit 主路径已停止生成 `clearStageChanges`
- [ ] 服务端类型与兼容层中的废弃字段仍待最终删除

### 建议新增字段

不是必须，但可考虑：

- [ ] `clientMutationId`
- [ ] `payloadHash`

用途：

- 排查重复提交
- 服务端日志对账

## 5.2 BFF `PATCH /v1/events/:id`

### 当前问题

它现在同时承担：

- payload 校验
- submission 壳创建
- active edit guard
- review 编排入口

### 目标拆分

建议抽象成两条逻辑路由，而不是一定两条 URL：

#### 路由 A：Direct apply

适用：

- admin
- operator
- trusted internal editor

行为：

- [ ] 同步 apply event core
- [ ] enqueue timetable job
- [ ] 返回 “已保存，时间表同步中/已完成”

#### 路由 B：Submission apply

适用：

- UGC
- 需要人工审核的来源

行为：

- [ ] 创建 submission
- [ ] 审核通过后 apply core
- [ ] enqueue timetable job

### 统一要求

两条路由最终都要使用同一套后端服务：

- `applyEventCoreStructure(...)`
- `enqueueEventTimetableApplyJob(...)`

### 当前进度

- [x] BFF `PATCH /v1/events/:id` 已停止要求 `assertEventSubmissionBaseRevision(...)`
- [x] `content-submission.routes.ts` 的 event payload 创建入口已停止要求 `assertEventSubmissionBaseRevision(...)`
- [ ] direct apply / review apply 路由分流仍未实施

## 5.3 BFF `POST /v1/events`

创建路径也建议同步对齐。

### 可选策略

#### 策略 A：创建也拆 Phase A / B

优点：

- 大量 timetable 创建同样受益

缺点：

- 新建后会存在“活动已建但 timetable 未完全同步”的短中间态

#### 策略 B：先只对编辑拆，创建暂时保留旧模型

优点：

- 风险小

缺点：

- 创建和编辑行为不完全统一

建议：

- [ ] 第一期先优先改编辑
- [ ] 第二期再决定是否把创建也完全收敛到同一 phase model

## 5.4 Response Contract 改造

后续 direct apply 路径下，返回语义应该更明确。

### 当前

- created
- submittedForReview

### 目标

建议增加 event mutation result 状态：

- [ ] `saved`
- [ ] `saved_timetable_sync_pending`
- [ ] `submitted_for_review`
- [ ] `submitted_for_review_after_core_saved`（若未来需要）

### iOS 端需要适配

- [ ] 成功提示文案
- [ ] 编辑完成页状态
- [ ] 我的发布 / 我的活动状态展示

---

## 6. Service 层拆分清单

## 6.1 `content-submission-event.service.ts`

建议拆成三个明确职责的函数：

### A. `applyEventCoreStructure(...)`

职责：

- [ ] normalize schedule
- [ ] update `events`
- [ ] sync `event_weeks`
- [ ] sync `event_days`
- [ ] update ticket tiers / image metadata / basic fields

输出：

- `eventId`
- `eventRevision`
- `scheduleFingerprint`

### B. `enqueueEventTimetableApplyJob(...)`

职责：

- [ ] 创建或重置 timetable apply job
- [ ] 记录 payload hash
- [ ] 记录 target event revision

### C. `applyEventTimetableCanonicalState(...)`

职责：

- [ ] normalize lineup/stage/slots
- [ ] use current DB `event_days`
- [ ] idempotent apply to canonical tables

## 6.2 `event-lineup-canonical.service.ts`

目标不是继续做“全量 reconcile 一切”，而是更明确拆成：

- [ ] `normalizeDesiredStages(...)`
- [ ] `normalizeDesiredArtists(...)`
- [ ] `normalizeDesiredPerformances(...)`
- [ ] `upsertEventPerformancesIdempotently(...)`
- [ ] `reconcileEventStages(...)`
- [ ] `reconcileEventArtists(...)`

## 6.3 `content-submission-processing.service.ts`

需要支持新的 phase 编排：

- [ ] review phase
- [ ] core apply phase
- [ ] timetable enqueue phase

如果走 direct apply，则这份 service 不参与主流程。

---

## 7. Worker / Job 设计清单

## 7.1 新 job type

- [ ] `apply_event_timetable`

## 7.2 Job 输入模型

建议 metadata 至少包含：

- [ ] `eventId`
- [ ] `sourceType`
- [ ] `sourceId`
- [ ] `payloadHash`
- [ ] `targetEventRevision`
- [ ] `scheduleFingerprint`
- [ ] `requestedAt`

### `sourceType` 候选

- `submission_approval`
- `direct_event_edit`
- `direct_event_create`
- `admin_repair`

## 7.3 Job 执行前置检查

worker 开跑前必须检查：

- [ ] event 是否存在
- [ ] event revision 是否仍匹配 target revision
- [ ] 当前 schedule fingerprint 是否仍匹配 job 预期
- [ ] 是否已经有更晚的 timetable apply job supersede 当前 job

若不匹配：

- [ ] 当前 job 标记 `cancelled` 或 `superseded`

## 7.4 Job 重试策略

建议：

- [ ] retryable：DB timeout / temporary lock / network-like transient failure
- [ ] non-retryable：payload invalid / eventDay 不存在 / schema mismatch

### 重试退避

- [ ] 1st retry：30s
- [ ] 2nd retry：2min
- [ ] 3rd retry：10min

## 7.5 Job 成功后的状态回写

- [ ] 更新 `events.timetableSyncStatus = succeeded`
- [ ] 更新 `events.timetableSyncCompletedAt`
- [ ] 清空 `events.timetableSyncError`

## 7.6 Job 失败后的状态回写

- [ ] 更新 `events.timetableSyncStatus = failed`
- [ ] 更新 `events.timetableSyncError`
- [ ] 保留人工重试空间

---

## 8. iOS 契约调整清单

## 8.1 `WebFeatureModels.swift`

- [ ] 删除 patch 相关字段定义
- [ ] 补充新的 response 状态枚举
- [ ] 如后端增加 event sync 状态字段，则同步 `WebEvent`

## 8.2 `EventUploadMappers.swift`

- [ ] 删除 `patchChanges(from:)`
- [ ] 删除 patch-only payload 分支
- [ ] 始终构建完整 `UpdateEventInput`

## 8.3 `EventUploadDraft.swift`

- [ ] 删除 `incrementalBaseline`
- [ ] 保留 full draft hydration

## 8.4 `EventUploadFlowViewModel.swift`

- [ ] 提交成功后的提示支持：
  - 主结构已保存
  - 时间表同步中
  - 提交审核中

---

## 9. Feature Flag 清单

建议新增：

- [ ] `EVENT_EDIT_DIRECT_APPLY_ENABLED`
- [ ] `EVENT_TIMETABLE_ASYNC_APPLY_ENABLED`
- [ ] `EVENT_PATCH_PROTOCOL_ENABLED`

### 默认建议

- `EVENT_PATCH_PROTOCOL_ENABLED = true` 仅在过渡期保留
- 新路径稳定后改为 `false`

### Flag 使用顺序

1. 先上 `EVENT_TIMETABLE_ASYNC_APPLY_ENABLED`
2. 再上 `EVENT_PATCH_PROTOCOL_ENABLED = false`
3. 最后灰度 `EVENT_EDIT_DIRECT_APPLY_ENABLED`

---

## 10. 兼容层策略

## 10.1 旧客户端兼容

过渡期内，服务端可以暂时：

- [ ] 接收 patch 字段
- [ ] 但忽略 patch 语义
- [ ] 统一回退成 full desired-state 处理

这是最稳妥的过渡方式。

## 10.2 旧 submission 兼容

旧 submission payload 中如果还存在 patch 字段：

- [ ] worker 在 decode 时统一 normalize 为 full path

---

## 11. 测试与联调清单

## 11.1 数据库测试

- [ ] `event_performances` 幂等 upsert 单测
- [ ] 软删除过滤回归测试
- [ ] 幂等键冲突正确更新测试

## 11.2 Service 测试

- [ ] `applyEventCoreStructure(...)` 单测
- [ ] `enqueueEventTimetableApplyJob(...)` 单测
- [ ] `applyEventTimetableCanonicalState(...)` 单测

## 11.3 Worker 测试

- [ ] superseded job 取消测试
- [ ] retry 成功恢复测试
- [ ] schedule 变化导致旧 job 放弃测试

## 11.4 API 联调

- [ ] iOS full payload edit
- [ ] admin direct apply edit
- [ ] UGC submission edit
- [ ] mixed edit with 200+ slots

---

## 12. 变更实施顺序建议

## 阶段 1：Schema 与 worker 基建

- [ ] 确认 `event_performances` 幂等键
- [ ] 完成 migration 1~3
- [ ] 建立新 job type

## 阶段 2：后端服务拆分

- [ ] 落 `applyEventCoreStructure(...)`
- [ ] 落 `enqueueEventTimetableApplyJob(...)`
- [ ] 落 `applyEventTimetableCanonicalState(...)`

## 阶段 3：API 契约切换

- [ ] BFF 支持 full-only edit contract
- [ ] direct apply path behind flag
- [ ] submission path 复用新 apply services

## 阶段 4：iOS 切换

- [ ] 删除 patch payload 生成
- [ ] 适配新 response 状态
- [ ] 联调大批量 timetable

## 阶段 5：清理旧代码

- [ ] 删 patch service
- [ ] 删 baseline 逻辑
- [ ] 删旧兼容 flag

---

## 13. 当前进度

- [x] 2026-05-29：完成数据库层目标拆解
- [x] 2026-05-29：完成 API 契约层目标拆解
- [x] 2026-05-29：完成 worker / job 目标拆解
- [x] 2026-05-29：完成迁移、联调、兼容层 checklist
- [x] 2026-05-29：进入实施，已完成 full-payload edit 主路径的第一轮 API 收口

---

## 14. 最终建议

如果只看“落地风险最低”的推进方式，推荐按照下面顺序做：

1. 先做 `event_performances` 幂等化
2. 再切 full-only edit contract
3. 再拆 core apply / timetable apply
4. 最后把 submission 从强制路径降级成按需路径

这样能最大限度复用现有项目能力，同时逐步消掉当前最危险的复杂度来源。
