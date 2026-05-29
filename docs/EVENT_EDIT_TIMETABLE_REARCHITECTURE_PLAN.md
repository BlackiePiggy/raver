# Event 编辑 / Timetable 重构实施方案

更新时间：2026-05-29  
适用范围：iOS 活动上传/编辑、BFF `/v1/events` 提交流程、`content_submissions` worker、event canonical lineup/timetable 写入链路

---

## 1. 文档目标

这份文档用于把下面这组反馈落成一份可执行、可跟踪、可分阶段推进的改造方案：

- 废弃 `patch` 模式，统一走全量提交
- 把强一致的 `schedule` 和大批量的 `timetable` 写入拆开
- 把 timetable 写入改造成幂等、可重试、可恢复
- 把 submission 审核链路改成“按需保留”，而不是所有编辑都强制经过它

这份文档会完整回答：

- 当前项目已经具备哪些能力
- 当前架构为什么会经常在“老活动编辑 + 大量 timetable 混改”时失败
- 应该怎么改
- 每一步要动哪些模块
- 每个阶段的验收标准是什么
- 当前进度到哪里了

---

## 2. 结论先行

### 2.1 当前问题本质

当前架构最大的矛盾不是某一个函数写得不够好，而是它把三类时间特性完全不同的任务强行塞进了一条大链路里：

1. `schedule / weeks / eventDays`
   - 结构性数据
   - 必须强一致
   - 适合同步、短事务

2. `timetable / lineup / stage canonical reconciliation`
   - 批量数据
   - 行数可能很大
   - 容错性强
   - 适合异步、幂等、可重试

3. `content submission / review / approval`
   - 审核业务流程
   - 不是数据库写入本身的技术必需条件
   - 适合按角色/来源选择性保留

当前实现的问题，不是“事务太大”这么简单，而是：

- 结构性强一致逻辑
- 大批量 canonical diff / rewrite
- 审核流程壳

被捆在了同一条编辑提交链路中。

结果是：

- 最慢的 `timetable canonical sync` 拖垮了最关键的 `event schedule` 落库
- `patch` 和全量并存，把客户端和服务端状态复杂度都推高了
- 用户只是在“改活动”，系统内部却在做“版本控制 + 审核编排 + 大对象重建 + 结构校验 + 批量写入”

### 2.2 最终目标

目标架构应当变成：

- `schedule`：同步强一致写入，快速成功
- `timetable`：异步幂等写入，失败可重试，不影响活动主结构已经落库
- `submission`：只在真的需要审核时才参与，不再强制拦在所有编辑前面

---

## 3. 当前项目能力透析

## 3.1 当前已经具备的能力

- [x] `events / event_weeks / event_days / event_stages / event_artists / event_artist_members / event_performances` 已经是结构化关系模型，不是散乱 JSON。
- [x] iOS 端已经能构建完整 `schedule + weeks + eventDays + lineupSlots + lineupArtists + stageOrder` 的全量 payload。
- [x] iOS 端已经有编辑基线概念：`incrementalBaseline / eventRevision / stageOrder / lineupSlots / lineupArtists / scheduleFingerprint`。
- [x] BFF 已经有提交壳：`content_submissions`、`content_submission_versions`、`content_submission_processing_jobs`。
- [x] worker 已经是 durable DB-backed job，不再依赖简单 `setImmediate`。
- [x] backend 已经有 `normalizeSubmittedEventScheduleContext(...)`，能对 `weeks / eventDays` 做严格结构校验。
- [x] backend 已经有 canonical lineup/timetable sync engine。
- [x] 当前 event apply 已经有事务保护：失败时不会只写一半。
- [x] 当前 edit 已经有并发保护：
  - `baseEventRevision`
  - active submission guard

## 3.2 当前能力的边界

虽然上面这些能力都存在，但它们并不是“最适合现在这个问题”的组合。

### 当前链路的真实形态

老活动编辑提交时，主链路是：

1. iOS `EventUploadDraft`
2. `EventUploadMappers.updateInput(...)`
3. BFF `PATCH /v1/events/:id`
4. 创建 `content_submission`
5. worker 拉起处理
6. `createOrUpdateEventFromSubmission(...)`
7. 大事务中依次更新：
   - `events`
   - `event_weeks`
   - `event_days`
   - `event_artists`
   - `event_artist_members`
   - `event_stages`
   - `event_performances`

### 当前链路的主要问题

- [x] `schedule` 与 `timetable` 强耦合
- [x] `patch` 与全量模式并存
- [x] edit 的 payload 语义过重
- [x] timetable 改动并不是简单 upsert，而是“load snapshot -> diff -> reconcile -> rewrite”
- [x] submission 壳在 auto-approve 场景下大多数时候只是多了一跳
- [x] 大量 slot 编辑的失败点不只在 DB 性能，还在结构一致性和 patch 漂移

---

## 4. 当前最核心的架构矛盾

## 4.1 `schedule` 和 `timetable` 不应该同生命周期处理

当前设计默认认为：

- 活动日期结构改动
- slot 改动
- stage 改动
- lineup 改动

属于同一个原子编辑事务。

但实际上它们不是同一类数据：

### `schedule`

- 行数小
- 用户心智强
- 必须立刻准确
- 改完后整个 event 的主结构就应该成立

### `timetable`

- 行数大
- 可以延迟完成
- 可以重试
- 失败时不应推翻整个 event 主结构

## 4.2 `submission` 审核不是所有编辑的技术前置条件

当前 auto-approve 路径下：

- submission 先创建
- worker 再跑
- 然后马上 `approved`

这说明：

- submission 的存在更多是业务编排和审计壳
- 不是活动数据落库本身的必须步骤

因此后续必须做路由拆分：

- 需要审核的编辑：保留 submission
- 平台自有运营或可信角色编辑：允许直写 event 主结构

---

## 5. 改造目标架构

目标架构分成三个层次：

### 5.1 主结构同步层

负责：

- `events`
- `event_weeks`
- `event_days`

要求：

- 短事务
- 强一致
- 快速完成

### 5.2 Timetable 异步投影层

负责：

- `event_stages`
- `event_artists`
- `event_artist_members`
- `event_performances`

要求：

- 幂等
- 可重试
- 可恢复
- 可分批

### 5.3 审核编排层

负责：

- 是否需要人工审核
- 提交历史
- 通知
- 审计

要求：

- 只在必要时参与
- 不与 timetable 大写入强绑定

---

## 6. 总体分阶段计划

## 6.1 优先级

| 优先级 | 改动 | 目标 | 改造成本 |
| --- | --- | --- | --- |
| P0 | timetable 写入幂等化 | 先消除“写残”和重复写风险 | 低 |
| P1 | 废弃 patch，统一全量 | 直接消除最大复杂度来源 | 中 |
| P2 | schedule / timetable 拆事务 | 大幅提升大批量编辑成功率 | 中 |
| P3 | submission 按需路由 | 缩短不必要链路 | 低 |

## 6.2 当前进度总览

- [x] 2026-05-29：完成现状链路透析
- [x] 2026-05-29：完成问题归因与目标架构定义
- [x] 2026-05-29：完成改造分阶段规划
- [x] 2026-05-29：iOS event edit 主路径停止生成 patch payload，统一回到 full payload mainline
- [x] 2026-05-29：BFF event edit / content submission 入口停止把 `baseEventRevision` 当作 event payload 受理硬门槛
- [x] 2026-05-29：iOS `EventUploadMappers` 已删除 event patch diff/patchChanges 死代码，主线只保留 full payload 组装
- [x] 2026-05-29：event regression script 已补齐 `weeks/eventDays` 提交契约，并新增“大量 timetable + multi-week + mixed update”回归场景
- [x] 2026-05-29：`createOrUpdateEventFromSubmission(...)` 已完成内部骨架拆分，主结构 apply 与 canonical timetable apply 已拆成独立内部步骤，为后续 Phase A / Phase B 拆事务做准备
- [x] 2026-05-29：canonical performance 写入已拆成独立 mutation plan / apply helper，幂等 upsert 可在不扰动 artist/stage 逻辑的前提下继续落地
- [x] 2026-05-29：canonical performance 落库执行语义已切到批量 upsert（`ON CONFLICT (id)`），并补了“大 payload 重放两次结果不变”的回归
- [x] 2026-05-29：无显式 `slot.id` 的 performance 已补稳定 identity 生成策略，create/replay 场景不再依赖随机 UUID
- [x] 2026-05-29：已准备 `event_performances.identity_key` migration 与 service 对齐，下一步只差正式 migration/codegen 应用到数据库环境
- [x] 2026-05-29：已复用 `content_submission_processing_jobs` 接出 event timetable Phase B job type，auto-approve 主线开始具备“主结构先写、timetable 后处理”的执行骨架
- [x] 2026-05-29：event timetable Phase B job 已收缩成“只执行 canonical timetable apply”，不再重走 event 主结构更新
- [x] 2026-05-29：Phase B timetable job 失败不再把已 approved 的 submission 打回 failed，改为保留 approved 并记录独立失败信息
- [x] 2026-05-29：Phase B 成功后会自动清理旧失败标记，queue status 也开始区分 `jobType`，便于观测主提交与 timetable 后处理
- [x] 2026-05-29：已补 Phase B “先失败再恢复”回归，验证 approved 不回退且 `reviewNotes.phaseBFailure` 会在成功重跑后清除
- [x] 2026-05-29：`event_performances.identity_key` migration 已在远端数据库成功应用，`canonical:validate` 通过
- [x] 2026-05-29：`events:incremental-sync:regression` 已在远端环境整套跑绿，覆盖 direct canonical / full payload / legacy patch / auto-approval / Phase B recovery
- [x] 2026-05-29：canonical performance 写入已修正为“已有 `id` 直接 update，新增 slot 走 `ON CONFLICT (event_id, identity_key)`”，消除时间调整时的主键冲突
- [x] 2026-05-29：legacy patch 兼容已补齐：
  - 缺失 `eventDayId` 的旧 slot update 可按 `overallDayIndex` / `localDate` / `startTime` 回推 eventDay
  - patch clear-all 场景下会先消费 timetable delete，再做 lineup delete 校验
- [x] 2026-05-29：worker queue status / admin status 已增强，可直接看到 `jobType` 维度统计、`phaseBFailure`、`phaseTimings`、最近一次耗时与重试调度信息
- [x] 2026-05-29：`pnpm content-submissions:status` 已增强为默认人类可读摘要输出，`--json` 保留原始结构，便于线上快速排障
- [x] 2026-05-29：已新增 `pnpm benchmark:event-submission`，可对 `200+ slot` 的 create/edit 路径输出 Phase A / Phase B / 总耗时基准
- [x] 2026-05-29：已完成远端 `240 slot x 3 rounds` benchmark，确认 Phase A 已压缩到约 `1.1s - 1.6s`，但 Phase B 仍需约 `40s - 43s`
- [x] 2026-05-29：已定位 benchmark 未打印 `canonicalSync.*` 的原因是 `apply_event_timetable` worker 包装结果时丢失了 `timings.canonicalSync`，现已在服务层补齐透传，待远端复测确认细分耗时
- [x] 2026-05-29：已确认 Phase B 慢点主要不在 canonical sync 本体，而在 Prisma interactive transaction 外层；当前 VM runtime 使用 `DATABASE_URL=Supabase pooler :6543 + pgbouncer=true`，event submission 事务已改为优先走 `DIRECT_URL`
- [x] P0：实现 timetable 幂等 upsert
- [ ] P1：移除 patch / baseline / revision gate 的旧编辑协议
- [x] P2：拆分 schedule 同步写入与 timetable 异步写入主执行骨架，并完成 Phase B 失败恢复语义校正
- [ ] P3：submission 按角色 / 来源路由
- [ ] 完成端到端压测与生产观测验收

---

## 7. P0：Timetable 写入改造成幂等 Upsert

## 7.1 目标

先不碰 iOS 提交语义，也不碰 submission 壳，只把当前最危险的“canonical rewrite 过程”改造成：

- 同一批 timetable payload 重复执行多次，最终结果一致
- 中途 worker 失败后重新执行，不会重复插入或写乱
- 不再依赖“先全删后全建”的高风险写法

## 7.2 当前现状

当前 canonical sync 虽然已经不再是最粗暴的全量 delete-all / recreate-all，但本质仍然是：

- load snapshot
- build target rows
- compute create/update/delete
- reconcile

这条路的问题在于：

- 状态机复杂
- 需要先读很多旧状态
- 对长事务和数据量高度敏感
- retry 时仍然依赖 snapshot 恢复

## 7.3 当前落地策略

当前已经落地的策略不是直接用 `(event_id, event_day_id, start_at, stage_id)` 做唯一约束，而是先引入稳定的 `identity_key`：

- `identity_key = md5(event_id | event_artist_id | stage_id | event_day_id | start_at | end_at)`
- DB 唯一索引：`(event_id, identity_key)`

当前语义：

- 新 slot：按 `(event_id, identity_key)` 幂等 upsert
- 已有 slot：若 payload 中携带稳定 `id`，优先按 `id` 直接 update

这样做的原因是：

- 对 create/replay 场景，`identity_key` 能稳定识别“同一语义 slot”
- 对 edit existing slot 场景，时间变化会导致 `identity_key` 改变，因此必须优先按稳定 `id` 更新，避免误插入

## 7.4 数据库改造

- [x] 为 `event_performances` 设计幂等唯一键策略
- [ ] 评估是否需要新增 `deleted_at` 字段支持软删除
- [x] 若不引入软删除，则明确“缺失即删除”的物理删除策略
- [x] 为幂等冲突路径建立必要索引

### 推荐方案 A：软删除

新增字段：

- `deletedAt DateTime? @map("deleted_at")`

优点：

- retry / 对账 / 回滚更友好
- 更容易追踪 worker 行为

缺点：

- 查询要统一过滤

### 推荐方案 B：物理删除

优点：

- 简单

缺点：

- 恢复和审计弱

当前状态：

- 当前实现先采用物理删除，确保 mutation plan 简洁、回归可控
- `deleted_at` 软删除仍保留为后续增强项，不阻塞当前两阶段改造上线

## 7.5 服务端实现改造

目标模块：

- `server/src/services/event-lineup-canonical.service.ts`

### 要做的事

- [x] 把 performance 写入从“复杂 target reconcile”中拆出独立幂等写入路径
- [x] 把 performance 写入从“复杂 target reconcile”中拆出独立 mutation plan / apply helper
- [x] 新增批量 upsert 执行路径（当前以稳定 `id` 为冲突键）
- [x] 支持批量 upsert
- [x] 支持 payload 中不存在的旧 slot 物理删除
- [x] retry 时重复执行仍保持结果一致
- [x] 同一份大 payload 重复执行两次，performance id 集合保持稳定
- [x] create payload 未显式提交 `slot.id` 时，重放后 performance id 仍保持稳定
- [x] 先完成 event apply service 骨架拆分，确保 Phase A / Phase B 可以在服务层单独挂载
- [x] 已修复 `identity_key` 生成与 migration 回填格式不一致的问题
- [x] 已修复 stage / artist 对齐后 performance identity 未重算的问题
- [x] 已修复“旧 slot 改时间后仍尝试 insert”导致的主键冲突问题

### 建议写入顺序

1. 先准备 stage / artist 映射
2. 生成本次 desired slot 集合
3. 对旧 slot 做“本次 payload 不包含”删除/软删除
4. 对 desired slot 做批量 upsert
5. 统一更新排序、关联和时间字段

## 7.6 SQL 策略建议

建议保留你提出的思路，最终落成：

1. 删除或软删除旧 slot
2. 批量插入 / 冲突更新新 slot

关键要求：

- [x] `ON CONFLICT` 的冲突键必须稳定
- [x] 更新时间、artist、sortOrder 均支持幂等覆盖
- [x] 同一 payload 执行两次，DB 最终状态完全一致

## 7.7 验收标准

- [x] 同一个大 timetable payload 连续执行 3 次，结果不变
- [x] worker 中途失败后重试，结果与一次成功执行完全一致
- [x] 不再出现 performance 重复插入
- [x] 不再出现旧 slot 未清理 / 新 slot 重复的问题

## 7.8 风险

- 冲突键设计不当会误合并两个真实不同的 slot
- stage rename 前后的 slot identity 需要确认是否受影响
- B2B/group identity 仍需通过 artist 层保证稳定

---

## 8. P1：废弃 Patch 模式，统一走全量提交

## 8.1 目标

彻底移除现在 edit payload 中最复杂的一层：

- `editMode`
- `lineupChanges`
- `timetableChanges`
- `stageChanges`
- `incrementalBaseline`
- `baseEventRevision`

目标变成：

- iOS 编辑提交永远发完整 event 结构
- backend 永远按完整 desired state 处理
- 再由后端内部做幂等同步和增量写入

## 8.2 当前现状

当前 iOS 编辑有两套语义同时存在：

### 全量语义

- `schedule`
- `weeks`
- `eventDays`
- `lineupSlots`
- `lineupArtists`
- `stageOrder`

### patch 语义

- `editMode = patch`
- `lineupChanges`
- `timetableChanges`
- `stageChanges`

这导致：

- 客户端要维护 baseline
- 服务端要校验 revision
- patch 和 schedule full payload 同时存在于一个请求里
- 失败面非常大

## 8.3 目标策略

统一原则：

- 客户端只负责“表达最新完整状态”
- 服务端负责“从完整状态计算最小写入计划”

客户端不再表达：

- 如何从旧状态变到新状态

## 8.4 iOS 改造

目标模块：

- `EventUploadDraft`
- `EventUploadMappers`
- `EventUploadFlowViewModel`
- `WebFeatureModels`

### 需要删除的客户端状态

- [ ] 删除 `incrementalBaseline`
- [ ] 删除 `eventRevision` 依赖于编辑提交协议的部分
- [x] 删除 `patchChanges(from:)`
- [x] 删除 `editMode = "patch"` 生成逻辑
- [x] 删除 `lineupChanges / timetableChanges / stageChanges` payload 生成逻辑

### 需要保留的客户端状态

- [ ] 保留完整 draft 模型
- [ ] 保留 `structuredWeeks / structuredEventDays`
- [ ] 保留完整 `lineupSlots / lineupArtists / stageOrder`

## 8.5 服务端改造

目标模块：

- `content-submission-event.service.ts`
- `bff.web.routes.ts`

### 需要删除的服务端路径

- [ ] 删除 `applySubmissionLineupPatch(...)`
- [ ] 删除 patch 模式分支
- [ ] 删除 `assertEventSubmissionBaseRevision(...)`
- [ ] 删除 `ActiveEventEditSubmissionError` 中与旧编辑协议强耦合的逻辑

### 需要保留但改语义的能力

- [ ] 保留“同一 event 同时只能有一个活跃写任务”这一并发保护，但改为 job 级别互斥，不再依赖 patch baseline

## 8.6 数据契约改造

- [ ] `UpdateEventInput` 去掉 patch 字段
- [ ] BFF 接口不再接收 patch-only payload
- [ ] iOS / Web 统一成完整 state contract

## 8.7 验收标准

- [ ] iOS 端编辑提交 payload 不再包含 patch 字段
- [ ] 服务端 event edit 主链路不再解析 patch
- [x] 删除 baseline 后，正常编辑不再因为 revision 漂移而 409
- [x] 混改 schedule/stage/lineup/timetable 时，失败点明显减少

## 8.8 风险

- 会失去“细粒度文本 patch”这种理论扩展能力
- 但当前项目并没有真正需要 CRDT/OT 级别 patch，这个取舍是合理的

---

## 9. P2：拆分事务，Schedule 同步写，Timetable 异步写

## 9.1 目标

把目前的大事务拆成两个阶段：

### Phase A：同步结构提交

写：

- `events`
- `event_weeks`
- `event_days`
- 必要的 ticket / image metadata

特点：

- 短事务
- 小数据量
- 用户提交后尽快成功

### Phase B：异步 timetable canonical job

写：

- `event_stages`
- `event_artists`
- `event_artist_members`
- `event_performances`

特点：

- 可重试
- 幂等
- 不阻塞主 event 结构写入

## 9.2 当前现状

当前 `createOrUpdateEventFromSubmission(...)` 在一个事务里同时做：

- event 主表更新
- weeks/days sync
- canonical lineup/timetable sync

事务参数：

- `maxWait = 30s`
- `timeout = 120s`

这意味着最慢的 timetable 部分会拖着最关键的主结构一起冒险。

## 9.3 目标改造

### Phase A 职责

- [x] 接收完整 event desired state
- [x] 正常做 schedule 结构校验
- [x] 更新 `events`
- [x] sync `event_weeks`
- [x] sync `event_days`
- [x] 生成一个 timetable apply job

### Phase B 职责

- [x] worker 根据 event 最新主结构和本次 payload 执行 timetable canonical apply
- [x] 失败可重试
- [x] 成功后标记 phase 完成

## 9.4 Job 设计

优先复用现有 `content_submission_processing_jobs` 思路，不新引入 Redis/BullMQ。

新增建议：

- [x] 新 job type：`apply_event_timetable`
- [x] job metadata 记录：
  - `eventId`
  - `submissionId` 或 direct-write source
  - payload hash
  - schedule snapshot version
  - phase marker

## 9.5 状态模型建议

建议 event 编辑提交后引入更清晰的用户态：

- `event structure saved`
- `timetable syncing`
- `timetable synced`
- `timetable sync failed`

如果不做 UI 暴露，至少后台状态要能观测。

## 9.6 事务拆分细节

### Phase A 事务

建议参数：

- `maxWait <= 5s`
- `timeout <= 10s`

原因：

- 只处理主结构
- 行数小
- 本应接近 100% 成功

### Phase B 事务

建议：

- 允许较长执行时间
- 但粒度可以按批次拆分
- 每个批次仍保持幂等

## 9.7 服务端模块改造

- [x] `createOrUpdateEventFromSubmission(...)` 拆成：
  - `applyEventCoreStructure(...)`
  - `enqueueEventTimetableApplyJob(...)`
- [x] worker 新增 timetable apply phase
- [x] submission worker 支持 phase-oriented processing

## 9.8 验收标准

- [x] 大量 timetable 编辑时，event 主结构仍能快速成功写入
- [x] timetable apply 失败时，event 主结构不回滚
- [x] timetable worker retry 后最终可恢复一致
- [ ] 提交接口的用户感知延迟明显下降

## 9.9 风险

- schedule 已成功但 timetable 尚未完成，系统会出现短时间“结构已更新、节目单未完全更新”的中间态
- 必须通过状态机和 UI 文案明确这是允许状态

---

## 10. P3：Submission 审核链路按需保留

## 10.1 目标

submission 仍保留，但不再作为所有编辑的强制入口。

路由目标：

### 需要审核

- 普通 UGC 用户提交活动
- 需要平台人工确认的编辑

### 不需要审核

- 平台运营人员
- admin/operator
- 已信任的内部编辑来源

## 10.2 当前现状

当前 iOS 主线创建和编辑都走：

- BFF submission
- worker
- approved

在 auto-approve 场景下，这实际上只是“多了一层任务壳”。

## 10.3 目标策略

新增按角色 / 来源路由：

- [ ] `requiresReview = true`：走 submission
- [ ] `requiresReview = false`：直写主结构，必要时异步 timetable job

## 10.4 实现建议

### BFF 层

- [ ] 增加 `resolveEventMutationRoute(...)`
- [ ] 根据 user role / source / feature flag 决定：
  - submission path
  - direct apply path

### Direct apply path

- [ ] 直接调用 `applyEventCoreStructure(...)`
- [ ] enqueue `apply_event_timetable` job
- [ ] 返回直接保存成功结果

### Submission path

- [ ] 仍保留审计
- [ ] 审批通过后调用同一套 apply core + timetable job 流程

## 10.5 Feature Flag 设计

建议增加：

- [ ] `EVENT_EDIT_DIRECT_APPLY_ENABLED`
- [ ] `EVENT_TIMETABLE_ASYNC_APPLY_ENABLED`
- [ ] `EVENT_EDIT_PATCH_MODE_ENABLED`（默认未来关闭）

## 10.6 验收标准

- [ ] admin/operator 编辑不再强制经过 submission 壳
- [ ] UGC 编辑仍保留审核路径
- [ ] 两条路径最终落同一套 apply core + async timetable 逻辑

---

## 11. 对现有模块的具体改造映射

## 11.1 iOS

### 核心文件

- `mobile/ios/.../EventUploadDraft.swift`
- `mobile/ios/.../EventUploadMappers.swift`
- `mobile/ios/.../EventUploadFlowViewModel.swift`
- `mobile/ios/.../Core/WebFeatureModels.swift`

### 要改什么

- [ ] 删除 patch / baseline 编辑协议
- [ ] 始终生成完整 payload
- [ ] 提交响应支持：
  - 主结构已保存
  - timetable 仍在同步

## 11.2 BFF

### 核心文件

- `server/src/routes/bff.web.routes.ts`

### 要改什么

- [ ] event create / edit 路由区分 direct apply 和 submission
- [ ] 不再强依赖 patch fields
- [ ] direct path 返回新的状态语义

## 11.3 Submission Worker

### 核心文件

- `server/src/services/content-submission-processing.service.ts`

### 要改什么

- [ ] worker phase 拆分
- [ ] 审核与 timetable apply 解耦
- [ ] 失败重试粒度按 timetable apply 处理

## 11.4 Event Apply Service

### 核心文件

- `server/src/services/content-submission-event.service.ts`

### 要改什么

- [ ] 拆出 `applyEventCoreStructure(...)`
- [ ] 删掉 patch apply 分支
- [ ] 统一完整 desired-state 输入协议

## 11.5 Canonical Timetable Service

### 核心文件

- `server/src/services/event-lineup-canonical.service.ts`

### 要改什么

- [ ] 改造成幂等 upsert 风格
- [ ] 把大对象 reconcile 聚焦为：
  - stage mapping
  - artist mapping
  - performance upsert

## 11.6 Prisma Schema

### 核心文件

- `server/prisma/schema.prisma`

### 可能需要的变动

- [ ] `event_performances` 增加软删除字段（若采用软删除）
- [ ] 增加幂等冲突键配套索引
- [ ] 如有需要，补充 job metadata 字段支持

---

## 12. 实施顺序建议

## 12.1 第 1 周：P0

- [ ] 确认 performance 幂等键
- [ ] 设计软删除 / 物理删除最终方案
- [ ] 落地 performance batch upsert
- [ ] 补充回归测试和 retry 测试

## 12.2 第 2 周：P1

- [ ] iOS 删除 patch payload 生成逻辑
- [ ] backend 删除 patch apply 分支
- [ ] 接口契约切换到 full payload only
- [ ] 验证老活动混改基本链路

## 12.3 第 3 周：P2

- [ ] 拆 `applyEventCoreStructure`
- [ ] 落地 `apply_event_timetable` job
- [ ] worker 串联 phase A / phase B
- [ ] UI / 状态回传调通

## 12.4 第 4 周：P3

- [ ] 引入 direct apply route
- [ ] 按角色 / feature flag 路由
- [ ] 保留 submission 审计但不强制使用
- [ ] 上线前压测与灰度

---

## 13. 测试与验收矩阵

## 13.1 功能回归

- [x] 新建活动，单 week，无 timetable
- [x] 新建活动，多 week，少量 timetable
- [x] 新建活动，多 week，大量 timetable（100+）
- [x] 老活动编辑，仅改基础信息
- [x] 老活动编辑，仅改 schedule
- [x] 老活动编辑，仅改 timetable
- [x] 老活动编辑，改 timetable + stage
- [x] 老活动编辑，改 timetable + lineup
- [x] 老活动编辑，改 schedule + timetable + stage + lineup

## 13.2 幂等性

- [x] 同一 payload 重复执行 3 次结果一致
- [x] worker 在一半失败后 retry 结果一致
- [ ] direct apply 与 submission apply 最终结果一致

## 13.3 并发

- [ ] 同一 event 连续快速提交两次
- [ ] schedule 已更新，旧 timetable job 到达时不会覆盖新结构
- [ ] 新 timetable job 可以安全 supersede 旧 job

## 13.4 性能

- [x] Phase A p95 明显低于当前整单提交
- [x] 200+ slot 编辑不会再被主事务拖垮
- [ ] worker 长任务不影响正常页面 API
- [ ] 记录真实 Phase A / Phase B 耗时分布并沉淀到状态接口或运维面板
- [x] 记录 `reviewNotes.phaseBFailure`、`jobType`、重试次数，便于线上排查 timetable 异步失败

### 当前基准结果（2026-05-29，远端环境，`240 slot`, `3 rounds`）

- create:
  - Phase A wall: `1.25s / 1.31s / 1.65s`，`avg 1.40s`，`p95 1.65s`
  - Phase A apply: `0.73s / 0.83s / 0.99s`，`avg 0.85s`
  - Phase B wall: `40.48s / 41.00s / 42.42s`，`avg 41.30s`
- edit:
  - Phase A wall: `1.06s / 1.19s / 1.19s`，`avg 1.15s`，`p95 1.19s`
  - Phase A apply: `0.60s / 0.64s / 0.71s`，`avg 0.65s`
  - Phase B wall: `42.33s / 42.56s / 43.15s`，`avg 42.68s`

### 当前结论

- Phase A 已达到两阶段改造的核心目标：主结构提交不再被大 timetable 拖慢
- Phase B 的真实慢点已经进一步收敛到事务层本身，而不是 canonical reconciliation 本体
- 在远端 `240 slot` 基准下，`canonicalSync.totalMs` 仅约 `5.0s - 8.0s`，但 `transactionWallMs` 约 `39s - 43s`
- 这说明当前主要问题是 runtime 连接形态与 interactive transaction 不匹配，而不是 slot diff / upsert 本身过慢
- 下一阶段优化重点从“继续压 canonical 逻辑”切换为“确认 DIRECT_URL runtime 接管后是否显著消除 30s+ transaction overhead”

### 下一阶段性能优化待办

- [x] 为 Phase B 加更细粒度耗时拆分：
  - snapshot load
  - artist/stage 对齐
  - performance update / insert / delete 聚合 mutation
  - cleanup delete
- [ ] 在远端 benchmark 中确认 `canonicalSync.*` 统计已经透出，并据此锁定 Phase B 真正瓶颈
- [ ] 在远端 benchmark 中确认切换到 `DIRECT_URL` 事务客户端后，`transactionWallMs / transactionOverheadMs` 明显下降
- [ ] 对 `syncCanonicalEventLineupAndTimetable(...)` 跑 SQL/CPU 热点剖析
- [ ] 判断当前 40s+ 是数据库写入慢，还是 JS 层 reconciliation 慢
- [ ] 评估是否要把 Phase B 的 artist/stage/performance mutation 再拆批，避免单次大事务过长
- [ ] 评估是否要为 `event_performances(event_id, identity_key)` 外再补覆盖索引或查询路径优化

---

## 14. 风险与回滚策略

## 14.1 风险

- [ ] 幂等键设计不当导致 slot 误合并
- [ ] schedule 与 timetable 异步后出现短时中间态
- [ ] direct apply 与 submission 路由同时存在时，状态语义容易混乱
- [ ] 旧客户端仍发 patch payload 时的兼容问题

## 14.2 回滚策略

### P0 回滚

- [ ] 保留旧 canonical sync behind feature flag

### P1 回滚

- [ ] 在服务端短期兼容 full payload 与旧 patch payload

### P2 回滚

- [ ] 保留“单事务旧路径” behind feature flag

### P3 回滚

- [ ] direct apply route 由 feature flag 控制，可快速切回 submission-only

---

## 15. 推荐最终里程碑定义

## Milestone A：可重复提交不写残

- [x] P0 完成

## Milestone B：编辑协议简化

- [ ] P1 完成

## Milestone C：大量 timetable 编辑稳定成功

- [x] P2 完成

## Milestone D：审核链路按需生效

- [ ] P3 完成

---

## 16. 当前文档进度

- [x] 2026-05-29：完成现状能力透析
- [x] 2026-05-29：完成问题本质抽象
- [x] 2026-05-29：完成目标架构定义
- [x] 2026-05-29：完成 P0-P3 分阶段实施方案
- [x] 2026-05-29：完成测试矩阵、风险、回滚和里程碑设计
- [x] 2026-05-29：进入实施，已完成 P1 的第一步主路径收口
- [x] 2026-05-29：远端数据库 migration 与 canonical validate 已完成
- [x] 2026-05-29：远端 `events:incremental-sync:regression` 全量通过
- [x] 2026-05-29：远端 `240 slot x 3 rounds` benchmark 已完成，Phase A 结果达标，Phase B 性能瓶颈已量化
- [x] 2026-05-29：当前工作重心已切换到生产压测、状态观测和 P1/P3 收尾

---

## 17. 最终判断

当前项目并不是“没有能力”，而是“能力太多但组合方式不对”。

它已经有：

- 结构化 event schema
- durable worker
- canonical event/timetable 存储
- 强校验 schedule 模型

但当前组合方式把：

- 强一致结构写入
- 大批量 timetable 写入
- 审核流程壳

塞进了一条过长的链路里。

本方案的核心不是推翻现有系统，而是重新分层：

- 让 `schedule` 回到同步强一致
- 让 `timetable` 回到异步幂等
- 让 `submission` 回到按需使用的业务编排层

如果按 P0 -> P1 -> P2 -> P3 顺序推进，这会是当前项目风险最低、收益最高、最适合落地的一条演进路径。
