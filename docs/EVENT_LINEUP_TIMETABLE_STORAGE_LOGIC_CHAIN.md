# Event 上传/编辑时 Lineup 与 Timetable 的入库逻辑链路

## 结论先说

当前仓库里和 `event` 上传/编辑相关的 `lineup` / `timetable` 写库，实际上并不是直接把一份 JSON 存进 `events` 表里，而是最终统一落到下面这组 canonical 表：

- `events`
- `event_ticket_tiers`
- `event_artists`
- `event_artist_members`
- `event_stages`
- `event_performances`

其中：

- `lineup` 的核心实体是 `event_artists` + `event_artist_members`
- `timetable` 的核心实体是 `event_performances`
- `stage` 的核心实体是 `event_stages`

也就是说，前端提交时虽然会带 `lineupArtists`、`lineupSlots`、`lineupChanges`、`timetableChanges` 这类字段，但真正的“入库真相”是统一同步到 canonical 关系表，而不是把提交 payload 原样长期保存为活动主数据。

## 我看到的两套链路

仓库里并存两套和 event 编辑相关的后端链路：

1. 当前主链路：`/v1/events`
2. 旧链路：`/api/events`

从 iOS 当前上传流代码看，主链路应该是 `/v1/events`。`/api/events` 还在，但更像旧接口或兼容接口。

---

## 一、当前主链路：`EventUploadFlow` / `LiveWebFeatureService` -> `/v1/events`

### 1. 前端草稿里的两份数据源

当前上传流里，前端实际上把 `lineup` 和 `timetable` 分成两套草稿：

- `lineupOnlySlots`
  - 表示“只在阵容里展示”的艺人数据
  - 最终映射成 `lineupArtists`
- `timetableSlots`
  - 表示真正有开始/结束时间的演出条目
  - 最终映射成 `lineupSlots`

也就是：

- `lineupArtists` 更像“阵容名单”
- `lineupSlots` 更像“时间表演出单元”

### 2. 前端提交前如何组装 payload

在 `EventUploadMappers` 里会做两类转换：

#### 2.1 `lineupOnlySlots` -> `lineupArtists`

每个阵容条目会被整理成：

- `id`
- `djId`
- `memberDjIds`
- `memberNames`
- `djName`
- `sortOrder`

这里保留了组合艺人信息，比如：

- `memberDjIds`
- `memberNames`
- 组合名 `djName`

#### 2.2 `timetableSlots` -> `lineupSlots`

每个 timetable 条目会整理成：

- `id`
- `lineupArtistId`
- `djId`
- `memberDjIds`
- `memberNames`
- `festivalDayIndex`
- `djName`
- `stageName`
- `sortOrder`
- `startTime`
- `endTime`

这里的关键点是：

- 如果某个 timetable slot 能匹配到某个 lineup artist，会提前把 `lineupArtistId` 带上
- 如果没有匹配上，后端后续还会再做一次对齐和补链

### 3. 编辑模式下会优先走 patch，而不是整单覆盖

如果草稿里有 `incrementalBaseline`，前端会做 diff，生成三类增量：

- `lineupChanges`
- `timetableChanges`
- `stageChanges`

同时把：

- `editMode = "patch"`
- `baseEventRevision`

一起带上。

这意味着新上传流的编辑不是简单“整单覆盖”，而是：

- 先拿基线版本
- 前端算 diff
- 后端按 patch 应用

### 4. 图片会先上传，再提交 event

新上传流会先把图片上传完成，然后再提交 `/v1/events`。

所以真正提交 event 时，payload 里已经有：

- `imageAssets`
- `coverImageUrl`
- `lineupImageUrl`

后端也会强校验：至少要有一张 `poster / lineup / cover` 主图。

### 5. `/v1/events` 并不会立刻直接写 event 主数据

`POST /v1/events` 和 `PATCH /v1/events/:id` 的第一跳不是直接写 `events`，而是：

1. 校验基础字段
2. 归一化 payload
3. 创建 `content_submissions`
4. 创建/唤起 `content_submission_processing_jobs`
5. 返回 `202 submitted_for_review`

也就是说，**当前主链路是“先入提交队列，再异步决定是否真正入库”**。

---

## 二、`/v1/events` 的服务端处理链路

### 1. 路由层会先做校验

主要校验：

- `name / startDate / endDate`
- `timeZone`
- `imageAssets` 必须至少有一张主图

### 2. 创建时会先做一次 lineup/timetable 自动对齐

在 `POST /v1/events` 时，路由会调用 `normalizeSubmittedEventLineupToTimetable`。

这一步对 create 很重要：

- 如果 payload 里有 `lineupSlots`
- 会根据 timetable 自动生成/修正 `lineupArtists`
- 并把 slot 和 artist 尽量重新关联

但这里有一个细节：

- **create 会先做这一步**
- **edit 因为带了 `targetEventId`，路由层不会做这一步**

也就是说，创建和编辑在“路由层自动对齐”这件事上行为并不完全一致。

### 3. 创建 content submission

`createPendingContentSubmission` 会做几件事：

- 给 payload 挂上 change summary
- 对 event 编辑检查是否已有同一个 event 的活跃编辑任务
- 写入 `content_submissions`
- 状态直接记为 `processing`
- 创建或唤起处理 job
- 给用户发“处理中”通知

这里有两个并发控制点：

#### 3.1 同一个 event 不允许并发活跃编辑任务

会查同一 `targetEventId` 下是否已有：

- `pending`
- `processing`
- `reviewing`

中的任务。

如果有，会直接拒绝新的编辑提交。

#### 3.2 编辑必须带正确的 `baseEventRevision`

编辑提交时，后端会要求：

- `baseEventRevision == 当前 event.revision`

不一致就会冲突报错。

这说明当前设计是有“乐观锁”意识的。

---

## 三、队列 worker 怎么决定是否真正入库

`processContentSubmission` 的逻辑是：

1. 取出 submission
2. `processing/pending` -> 先转成 `reviewing`
3. 判断是否自动批准

自动批准条件是：

- `entityType` 是 `event`
- 且提交者角色是 `admin` 或 `operator`

所以这里非常关键：

- 普通用户提交 event 后，不会马上写入 `events/event_performances`
- 普通用户通常会停在 `reviewing`
- 只有管理员/运营提交，或者后续审核通过，才会真正入库

也就是说，**“提交成功”不等于“已入库”**。

---

## 四、真正入库时：`createOrUpdateEventFromSubmission`

真正写业务表时，核心函数是 `createOrUpdateEventFromSubmission`。

### 1. 先写 `events` 主表和 `event_ticket_tiers`

它会先整理出 `eventData`，写入或更新：

- `events`
- `event_ticket_tiers`

如果是 edit：

- 会校验 `baseEventRevision`
- 更新成功时 `events.revision + 1`

### 2. 再同步 lineup/timetable canonical 数据

主表写完后，不会直接把前端那份 `lineupArtists/lineupSlots` 存着不管，而是进入：

- `syncSubmissionEventLineupAndTimetable`

这一步才是 `lineup/timetable` 真正的核心入库逻辑。

---

## 五、`syncSubmissionEventLineupAndTimetable` 的两条分支

### A. patch 模式

如果 `editMode == "patch"`，会走：

- `applySubmissionLineupPatch`

处理顺序是：

1. 先加载当前 event 的 canonical snapshot
   - `artists`
   - `slots`
   - `stageOrder`
2. 逐条应用：
   - `lineupChanges`
   - `timetableChanges`
   - `stageChanges`
3. 根据受影响的 timetable identity key，重新修正 lineup artist
4. 重新把 slot relink 到 artist
5. 再整体同步到 canonical 表

patch 支持的动作包括：

- lineup
  - `add`
  - `update`
  - `delete`
  - `reorder`
- timetable
  - `add`
  - `update`
  - `delete`
  - `reorder`
- stage
  - `rename`
  - `delete`

这里还有几个硬约束：

- 删除 lineup artist 时，如果还有 slot 引用它，会报错
- 删除 stage 时，如果没带 `confirmDeleteLinkedPerformances = true`，会报错

### B. full overwrite 模式

如果不是 patch，就会把提交体当成整单重算：

1. `lineupSlots` -> normalize 成 canonical slots
2. `lineupArtists` -> normalize 成 canonical artists
3. 如果 slots 非空，会根据 slots 再次调整 artists
4. 重新把 slots 和 artists 对齐
5. 带着 `stageOrder` 一起同步到 canonical 表

这意味着 full 模式下，**timetable 实际上对 lineup 有反向塑形作用**，不是两份数据彼此完全独立。

---

## 六、最终 canonical 入库：`syncCanonicalEventLineupAndTimetable`

这是整个链路里最关键的一步。

它会把“目标状态”同步到 4 组表：

- `event_artists`
- `event_artist_members`
- `event_stages`
- `event_performances`

### 1. 先读当前库里的 canonical 状态

会先加载现有：

- artists
- artist members
- stages
- performances

### 2. 根据提交结果构造目标行

它会把前面归一化后的 artists/slots 转成：

- target artist rows
- target member rows
- target stage rows
- target performance rows

### 3. 尝试复用已有 ID，而不是无脑全删全建

它会按多种 key 去匹配老数据：

- `artist.id`
- `primaryDjId`
- normalized name
- group member ids
- fallback 的 member names
- performance 的语义 key

这一步的目标是：

- 尽量保留已有 `artist/performance/stage` 的主键
- 降低编辑时整表重建带来的抖动

### 4. 执行同步

实际执行顺序大致是：

1. 删除目标里不存在的 `event_performances`
2. create/update `event_artists`
3. 重写有变化的 `event_artist_members`
4. create/update `event_stages`
5. create/update `event_performances`
6. 删除多余的 `event_artists`
7. 删除多余的 `event_stages`

最终结果是：

- `lineup` 以 `event_artists + event_artist_members` 为准
- `timetable` 以 `event_performances` 为准

---

## 七、读取时是怎么还原成前端看到的数据的

活动详情读取时，不是直接拿某个 JSON 字段，而是：

1. 读取 canonical snapshot
2. 映射成：
   - `lineupArtists`
   - `lineupSlots`
   - `timetableSlots`

当前读法里：

- `lineupSlots`
- `timetableSlots`

本质上都是从 `event_performances` 映射出来的同一批 slot。

所以读模型层面，`timetable` 才是真正有时间语义的那份事实数据。

---

## 八、还有一条“即时直写 canonical”的旁路

除了整单 `/v1/events` 提交，仓库里还提供了这些接口：

- `POST /v1/events/:id/lineup`
- `PATCH /v1/events/:id/lineup/:artistId`
- `DELETE /v1/events/:id/lineup/:artistId`
- `POST /v1/events/:id/timetable`
- `PATCH /v1/events/:id/timetable/:slotId`
- `DELETE /v1/events/:id/timetable/:slotId`

这组接口的特点是：

- **不走 content submission 队列**
- **直接读 snapshot + 调 `syncCanonicalEventLineupAndTimetable`**
- **立即改 canonical 表**

所以当前仓库其实有两种编辑语义并存：

1. 整单 event 上传/编辑：先入队，再异步入库
2. 单条 lineup/timetable 直接改：立即入库

这是一个很重要的设计现实，因为它意味着：

- 同样是“改 lineup/timetable”
- 不同入口的一致性和时效性并不完全一样

---

## 九、旧链路：`/api/events` 还在，但和当前主链路不完全一致

旧接口在 `server/src/controllers/event.controller.ts`。

它的特点是：

- create/update 更偏同步直写
- admin/operator create 会直接写 `events`，然后同步 canonical
- create 时如果不是 admin/operator，只是简单写一条 `content_submissions`
- update 则允许 event owner 直接更新 event，并直接同步 canonical

这套逻辑和 `/v1/events` 的差异很大：

- `/v1/events` 强调提交队列、worker、reviewing、revision、active edit lock
- `/api/events` 更像传统 CRUD + 部分审核

所以如果你在排查“为什么不同入口行为不一致”，这就是其中一个根源。

---

## 十、我认为这条链路里最值得你重点评判的点

### 1. 真正的 source of truth 已经不是 event payload，而是 canonical 表

这是当前设计最核心的事实。

好处：

- 读写模型更清晰
- lineup / timetable / stage 关系更结构化

代价：

- payload 只是中间态
- 排查问题必须看 canonical sync，而不是只看 controller 收到了什么

### 2. create 和 edit 的“自动对齐时机”不完全一致

当前：

- create 路由层会先做 auto-align
- edit 路由层不会
- edit 更多依赖后续 patch/full sync 逻辑去收敛

这个差异容易导致：

- 同样的 lineup/timetable 数据
- create 与 edit 的表现不完全一致

### 3. “整单提交流程”和“单条直改流程”并存

这会导致：

- 有的修改立刻进 canonical 表
- 有的修改先只进入 `content_submissions`

如果产品层没有明确区分，用户会感知成“为什么有时改完立即生效，有时只是提交审核”。

### 4. normal user 的 event 编辑并不是立即入库

这一点非常关键：

- 普通用户点保存/提交
- 大多数情况下只会写 `content_submissions`
- 不会立刻更新 `event_performances`

如果前端文案或管理后台认知没对齐，业务上很容易误判。

### 5. 旧 `EventEditorView` 这条路看起来已经和当前新契约有脱节风险

我从代码上看到两个风险：

- 它构造 `lineupSlots` 时更偏“单 slot + 组合名”，对组合成员信息保留不完整
- 它的创建后图片补传模式，看起来和当前 `/v1/events` 依赖 `imageAssets` 的要求不完全同频

这更像一条遗留编辑入口，而不是当前主上传流。

---

## 十一、把整条链路压缩成一句话

当前 event 上传/编辑里，`lineup` 和 `timetable` 的提交数据会先在前端被拆成“阵容名单 + 时间表 slot + 增量 patch”，再走 `/v1/events` 进入 `content_submissions` 队列；真正入库时，后端不会直接保存这份原始 payload，而是把它统一同步成 `event_artists / event_artist_members / event_stages / event_performances` 这套 canonical 关系表，之后所有详情读取再从这套 canonical 表反推回前端所见的 lineup 和 timetable。

---

## 十二、建议你评判时重点看这 4 个问题

1. 你是否接受“普通用户编辑 event 只是入队，不是立即入库”这件事。
2. 你是否接受“create 和 edit 的 auto-align 时机不同”。
3. 你是否接受“整单提交”和“单条直改”并存导致的双重写入语义。
4. 你是否接受“canonical 表才是真正事实来源，而不是 event payload 本身”。

