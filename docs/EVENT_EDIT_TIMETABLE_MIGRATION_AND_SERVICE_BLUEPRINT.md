# Event 编辑 / Timetable 重构 Migration 与 Service Blueprint

更新时间：2026-05-29  
关联文档：

- [EVENT_EDIT_TIMETABLE_REARCHITECTURE_PLAN.md](/Users/blackie/Projects/raver/docs/EVENT_EDIT_TIMETABLE_REARCHITECTURE_PLAN.md)
- [EVENT_EDIT_TIMETABLE_DB_API_CHANGESET.md](/Users/blackie/Projects/raver/docs/EVENT_EDIT_TIMETABLE_DB_API_CHANGESET.md)
- [EVENT_EDIT_MIXED_UPDATE_FULL_FLOW.md](/Users/blackie/Projects/raver/docs/EVENT_EDIT_MIXED_UPDATE_FULL_FLOW.md)

---

## 1. 文档目标

这份文档继续向实施层推进，目标是把前两份方案变成：

- 可以拆 ticket 的 migration 草案
- 可以直接分配给工程师的 TypeScript service 重构蓝图
- 可以用于 code review 的目录级职责拆分

这份文档重点覆盖：

- Prisma / SQL migration 草案
- service 文件拆分建议
- route / worker / job 的调用关系
- 函数级别推荐命名与职责
- 上线顺序与代码删除顺序

---

## 2. 最终目标状态

重构完成后，event edit/create 的核心代码路径应尽量收敛为：

### 同步主结构路径

- 输入：完整 event desired-state payload
- 输出：已落库的 `events + event_weeks + event_days`

### 异步 timetable apply 路径

- 输入：eventId + desired timetable payload snapshot + event revision / schedule fingerprint
- 输出：已收敛的：
  - `event_stages`
  - `event_artists`
  - `event_artist_members`
  - `event_performances`

### 审核编排路径

- 输入：是否需要 review
- 输出：
  - 需要 review：submission -> review -> apply
  - 不需要 review：direct apply -> enqueue timetable job

---

## 3. Prisma / Schema 改造 Blueprint

## 3.1 `Event` 模型建议改动

### 当前状态

当前 `Event` 模型已有：

- `revision`
- `scheduleMode`
- `timeZone`
- `dayRolloverHour`

### 建议新增字段

```prisma
model Event {
  ...
  timetableSyncStatus      String?   @map("timetable_sync_status")
  timetableSyncRequestedAt DateTime? @map("timetable_sync_requested_at")
  timetableSyncCompletedAt DateTime? @map("timetable_sync_completed_at")
  timetableSyncError       String?   @map("timetable_sync_error") @db.Text
  ...

  @@index([timetableSyncStatus, updatedAt])
}
```

### 字段语义建议

- `timetableSyncStatus`
  - `pending`
  - `running`
  - `succeeded`
  - `failed`
- `timetableSyncRequestedAt`
  - 最后一次 timetable apply 被请求的时间
- `timetableSyncCompletedAt`
  - 最后一次成功完成时间
- `timetableSyncError`
  - 最近一次失败原因摘要

### 当前进度

- [ ] 未实施
- [x] 方案已定义

## 3.2 `EventPerformance` 模型建议改动

### 推荐版本：支持软删除

```prisma
model EventPerformance {
  ...
  deletedAt DateTime? @map("deleted_at")
  ...

  @@index([eventId, eventDayId, startAt])
  @@index([eventId, deletedAt, updatedAt])
}
```

### 为什么建议加 `deletedAt`

- 幂等 apply 时可以先标记“本次 payload 不再包含的 slot”
- retry / 审计 / 对账更自然
- 减少“误删后难排查”的风险

### 查询约束

一旦引入：

- 所有业务查询都要统一过滤 `deletedAt IS NULL`

包括：

- event detail timetable
- admin timetable view
- export / feed / recommendation 引用

### 当前进度

- [ ] 未实施
- [x] 方案已定义

## 3.3 `ContentSubmissionProcessingJob` 模型建议改动

当前表可直接复用，不一定要新增字段。

### 建议新增索引

如果 timetable apply job 会频繁按 event 维度查找，建议补充：

```prisma
model ContentSubmissionProcessingJob {
  ...
  @@index([jobType, status, availableAt])
}
```

### Metadata 规范化约定

建议在应用层统一写入下列 metadata key：

- `eventId`
- `submissionId`
- `sourceType`
- `payloadHash`
- `targetEventRevision`
- `scheduleFingerprint`
- `phase`
- `supersedesJobId`

### 当前进度

- [ ] 未实施
- [x] 方案已定义

---

## 4. SQL Migration 草案

## 4.1 Migration A：event timetable sync observability

### 目标

- 给 `events` 增加 timetable sync 状态字段

### SQL 草案

```sql
ALTER TABLE events
  ADD COLUMN timetable_sync_status VARCHAR(32),
  ADD COLUMN timetable_sync_requested_at TIMESTAMP(3),
  ADD COLUMN timetable_sync_completed_at TIMESTAMP(3),
  ADD COLUMN timetable_sync_error TEXT;

CREATE INDEX idx_events_timetable_sync_status_updated_at
  ON events(timetable_sync_status, updated_at);
```

### 验证 checklist

- [ ] migration 可成功执行
- [ ] Prisma schema 与 DB 对齐
- [ ] 现有 event 查询不受影响

## 4.2 Migration B：event performance soft delete

### 目标

- 给 `event_performances` 增加软删除能力

### SQL 草案

```sql
ALTER TABLE event_performances
  ADD COLUMN deleted_at TIMESTAMP(3);

CREATE INDEX idx_event_performances_event_deleted_updated
  ON event_performances(event_id, deleted_at, updated_at);
```

### 验证 checklist

- [ ] 旧数据默认 `deleted_at IS NULL`
- [ ] 查询层已准备过滤逻辑

## 4.3 Migration C：幂等唯一键

这个 migration 需要谨慎，因为要先确认业务上是否允许：

- 同一 eventDay
- 同一 stage
- 同一 startAt

存在两个并行 slot。

### 候选唯一键

#### 方案 1

```sql
CREATE UNIQUE INDEX uq_event_performance_slot_identity
  ON event_performances(event_id, event_day_id, stage_id, start_at)
  WHERE deleted_at IS NULL;
```

#### 方案 2

如果需要把 artist 也纳入身份：

```sql
CREATE UNIQUE INDEX uq_event_performance_slot_identity
  ON event_performances(event_id, event_day_id, stage_id, start_at, event_artist_id)
  WHERE deleted_at IS NULL;
```

### 建议

- [ ] 先通过历史数据扫描验证方案 1 是否冲突
- [ ] 若冲突率 > 0，则切换方案 2

### 上线前必做脚本

- [ ] 扫描重复键候选数据
- [ ] 输出修复清单
- [ ] 若存在冲突，先修数据再上唯一索引

## 4.4 Migration D：job type 索引优化

### SQL 草案

```sql
CREATE INDEX idx_content_submission_jobs_type_status_available
  ON content_submission_processing_jobs(job_type, status, available_at);
```

### 验证 checklist

- [ ] worker claim job 查询命中索引
- [ ] 不影响旧 submission worker

---

## 5. Prisma Schema 修改顺序建议

推荐按下面顺序改 schema：

1. `Event` 增加 timetable sync 状态字段
2. `EventPerformance` 增加 `deletedAt`
3. `ContentSubmissionProcessingJob` 补索引
4. 最后再加 unique slot identity

原因：

- 前三步风险低
- unique identity 是最需要历史数据验证的一步

---

## 6. TypeScript Service 目录重构 Blueprint

## 6.1 当前主要问题

当前 event apply 逻辑的主要问题不是“文件太大”本身，而是职责混在一起：

- submission payload normalize
- event core apply
- weeks/days sync
- lineup/timetable normalize
- patch 逻辑
- canonical reconcile
- worker 编排

这些职责应该拆开。

## 6.2 推荐目录结构

建议新增或重构为：

```text
server/src/services/events/
  event-core-apply.service.ts
  event-schedule-normalize.service.ts
  event-timetable-apply-job.service.ts
  event-timetable-canonical-apply.service.ts
  event-timetable-idempotent-write.service.ts
  event-apply-contract.types.ts
  event-apply-observability.service.ts

server/src/services/content-submission/
  content-submission-event-route.service.ts
  content-submission-event-review.service.ts

server/src/jobs/events/
  event-timetable-apply.worker.ts
```

### 为什么建议单独拆 `services/events/`

因为 event apply 已经不只是 submission 的一个子步骤，而是会同时被：

- direct apply path
- submission approval path
- admin repair path
- future replay/retry path

复用。

---

## 7. 文件级职责建议

## 7.1 `event-apply-contract.types.ts`

### 职责

- 定义统一的 service 层 contract

### 建议包含类型

- `EventFullDesiredStateInput`
- `EventCoreApplyResult`
- `EventTimetableApplyJobInput`
- `EventTimetableDesiredStateInput`
- `EventTimetableApplyResult`
- `EventScheduleFingerprint`

### 进度

- [ ] 未实施

## 7.2 `event-schedule-normalize.service.ts`

### 职责

- 专门负责：
  - `schedule`
  - `weeks`
  - `eventDays`
  的 normalize 和 validate

### 推荐函数

- `normalizeEventScheduleFromPayload(...)`
- `validateWeeksAndEventDaysConsistency(...)`
- `buildScheduleFingerprint(...)`
- `buildEventDaysFromPersistedEvent(...)`

### 迁移策略

- [ ] 从 `content-submission-event.service.ts` 中逐步抽出

## 7.3 `event-core-apply.service.ts`

### 职责

- 只做 event 主结构同步 apply

### 推荐函数

- `applyEventCoreStructure(...)`
- `updateEventCoreRecord(...)`
- `syncStructuredEventSchedule(...)`
- `updateEventTimetableSyncStatus(...)`

### 输入

- 完整 desired state

### 输出

- `eventId`
- `eventRevision`
- `scheduleFingerprint`

### 明确不负责

- 不负责 canonical timetable apply
- 不负责 submission 审核编排

## 7.4 `event-timetable-apply-job.service.ts`

### 职责

- 负责任务入队、重置、去重、supersede 逻辑

### 推荐函数

- `enqueueEventTimetableApplyJob(...)`
- `resetExistingEventTimetableApplyJob(...)`
- `markSupersededEventTimetableJobs(...)`
- `buildEventTimetableJobMetadata(...)`

### 需要处理的规则

- 同一 event 是否只允许一个 running/pending timetable job
- 新 job 是否自动 supersede 旧 job

## 7.5 `event-timetable-canonical-apply.service.ts`

### 职责

- 把 desired timetable state 规范化为 canonical rows

### 推荐函数

- `normalizeDesiredStagesFromPayload(...)`
- `normalizeDesiredArtistsFromPayload(...)`
- `normalizeDesiredPerformancesFromPayload(...)`
- `applyEventTimetableCanonicalState(...)`

### 明确不负责

- 不直接关心 submission
- 不直接关心 HTTP

## 7.6 `event-timetable-idempotent-write.service.ts`

### 职责

- 真正落 performance / stage / artist 的幂等写入

### 推荐函数

- `upsertEventPerformancesIdempotently(...)`
- `softDeleteMissingEventPerformances(...)`
- `reconcileEventStagesByDesiredState(...)`
- `reconcileEventArtistsByDesiredState(...)`
- `rewriteEventArtistMembersIfChanged(...)`

### 说明

这是 P0 的核心落点文件。

## 7.7 `event-apply-observability.service.ts`

### 职责

- event apply 过程的日志、状态更新、错误摘要

### 推荐函数

- `markEventTimetableSyncPending(...)`
- `markEventTimetableSyncRunning(...)`
- `markEventTimetableSyncSucceeded(...)`
- `markEventTimetableSyncFailed(...)`

### 说明

把状态更新集中起来，避免散落在 route / worker / service 各处。

## 7.8 `content-submission-event-route.service.ts`

### 职责

- route 层决策：走 direct apply 还是 submission path

### 推荐函数

- `resolveEventMutationExecutionMode(...)`
- `submitEventMutationForReview(...)`
- `applyEventMutationDirectly(...)`

### 输出模式建议

- `direct_apply`
- `review_required`

## 7.9 `content-submission-event-review.service.ts`

### 职责

- submission approval 后，调用新 event apply services

### 推荐函数

- `approveEventSubmissionAndApplyCore(...)`
- `enqueueApprovedEventTimetableApply(...)`

---

## 8. Worker 文件 Blueprint

## 8.1 `server/src/jobs/events/event-timetable-apply.worker.ts`

### 职责

- 处理 `apply_event_timetable` job

### 推荐执行步骤

1. `claimEventTimetableApplyJob(...)`
2. `loadJobMetadata(...)`
3. `assertJobStillCurrent(...)`
4. `markEventTimetableSyncRunning(...)`
5. `loadDesiredTimetableState(...)`
6. `applyEventTimetableCanonicalState(...)`
7. `markEventTimetableSyncSucceeded(...)`
8. `completeJob(...)`

若失败：

9. `markEventTimetableSyncFailed(...)`
10. `retryOrFailJob(...)`

### 当前进度

- [ ] 未实施

---

## 9. Route 层改造 Blueprint

## 9.1 `server/src/routes/bff.web.routes.ts`

### 当前建议改法

不要一开始就把 route 全拆成多个 URL。

建议先在现有：

- `POST /v1/events`
- `PATCH /v1/events/:id`

内部引入 execution mode 决策。

### 推荐控制流

```ts
const mode = resolveEventMutationExecutionMode(user, payload, flags);

if (mode === "direct_apply") {
  return applyEventMutationDirectly(...);
}

return submitEventMutationForReview(...);
```

### direct apply 返回建议

```json
{
  "mode": "direct_apply",
  "status": "saved_timetable_sync_pending",
  "eventId": "xxx"
}
```

### review path 返回建议

继续保留 submission accepted payload。

---

## 10. 旧代码清理 Blueprint

## 10.1 第一批可删

在 full-only contract 稳定后：

- [ ] `patchChanges(from:)`
- [ ] `applySubmissionLineupPatch(...)`
- [ ] `EventLineupArtistPatchChange`
- [ ] `EventLineupSlotPatchChange`
- [ ] `EventStagePatchChange`

### 当前进度

- [x] iOS event edit 主路径已不再调用 `patchChanges(from:)`
- [ ] 服务端 patch 兼容分支仍保留，等待后续彻底移除

## 10.2 第二批可删

在 direct apply + async timetable 路径稳定后：

- [ ] 旧单事务“event core + canonical timetable”耦合路径

## 10.3 第三批可删

在客户端全面切换后：

- [ ] `incrementalBaseline`
- [ ] `baseEventRevision`
- [ ] 旧 patch-only response / validation 分支

---

## 11. 上线顺序与代码提交顺序建议

## Commit 1：Schema observability

- [ ] `events` timetable sync fields
- [ ] `event_performances.deleted_at`
- [ ] basic indexes

## Commit 2：Service types and core extraction

- [ ] 新增 `event-apply-contract.types.ts`
- [ ] 新增 `event-core-apply.service.ts`
- [ ] 抽 `event-schedule-normalize.service.ts`

## Commit 3：Timetable job enqueue + worker skeleton

- [ ] 新增 `event-timetable-apply-job.service.ts`
- [ ] 新增 worker file
- [ ] 不切主路径，仅 skeleton + tests

## Commit 4：Idempotent performance write path

- [ ] 新增 `event-timetable-idempotent-write.service.ts`
- [ ] 大量测试

## Commit 5：Canonical apply switch

- [ ] 主 timetable apply 切到新写入路径

## Commit 6：Full-only contract

- [ ] iOS 停发 patch
- [ ] backend 停用 patch mainline

## Commit 7：Direct apply mode

- [ ] route 决策
- [ ] feature flag 灰度

## Commit 8：Delete legacy patch code

- [ ] 清理 dead code

---

## 12. SQL / Prisma / Service 联动注意点

## 12.1 加 `deletedAt` 后的联动

- [ ] Prisma model 更新
- [ ] 读取 performance 的 service 全部补过滤条件
- [ ] event detail query 回归测试

## 12.2 唯一键后的联动

- [ ] 任何 createMany / insert 逻辑都要改成 upsert 风格
- [ ] 原先靠 UUID 保证唯一的逻辑要改为业务 identity

## 12.3 direct apply 后的联动

- [ ] event mutation analytics 埋点要区分 direct / review
- [ ] 我的发布状态页要兼容新状态

---

## 13. 建议的历史数据检查脚本

上线唯一键前，建议准备 3 类脚本：

### 13.1 performance 冲突检测脚本

- [ ] 找出 `(event_id, event_day_id, stage_id, start_at)` 重复数据

### 13.2 deletedAt 查询回归脚本

- [ ] 校验所有关键查询都不会读到软删除 slot

### 13.3 superseded job 检查脚本

- [ ] 找出同 event 下重复 pending/running timetable jobs

---

## 14. 当前进度

- [x] 2026-05-29：完成 schema 改造 blueprint
- [x] 2026-05-29：完成 SQL migration 草案
- [x] 2026-05-29：完成 service 目录与函数级 blueprint
- [x] 2026-05-29：完成 route / worker / cleanup 顺序建议
- [x] 2026-05-29：进入实施，已完成 full-only edit 主路径的第一轮代码收口

---

## 15. 最终建议

如果接下来要真的开始写代码，建议不要直接扑到一个大 PR 里一起做。

最稳妥的做法是：

1. 先上 schema 和 observability
2. 再抽 core apply
3. 再把 timetable apply 独立成 job
4. 再切 full-only
5. 最后灰度 direct apply

这样每一步都可验证、可回滚、可灰度，也最适合当前这个已有复杂主线的项目。
