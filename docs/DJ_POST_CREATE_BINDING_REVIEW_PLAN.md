# DJ 入库后历史阵容/时间表绑定审核方案

## 目标

当一个 DJ 成功入库后，后台自动扫描已有 event 的 lineup 和 timetable 中未绑定 DJ 的艺人名称，生成一份“待绑定审核任务”。festival-viewer 后台收到通知后，管理员可以打开任务页，查看高置信匹配和模糊匹配，并选择一键绑定或逐条绑定。

触发范围：

- 管理员直接新增 DJ 成功入库。
- 普通用户创建 DJ，审核通过后成功入库。
- 其他 server 侧创建 DJ 的路径，只要产生了新的 DJ 记录，也应触发同一流程。

不做的事：

- 不在 iOS 端做匹配或绑定。
- 不自动覆盖已经绑定到其他 DJ 的 lineup/timetable 项。
- 第一版不自动写入模糊匹配结果，只生成候选给后台确认。

## 匹配对象

扫描 canonical event 数据：

- `EventArtist`
  - `displayName`
  - `primaryDjId` 为空的主艺人。
  - `EventArtistMember.djId` 为空的成员名。
- `EventPerformance`
  - 实际时间表通过 `eventArtistId` 关联到 `EventArtist`。
  - 绑定时优先更新 `EventArtist` / `EventArtistMember`，时间表自然跟随 canonical artist。

候选上下文需要展示：

- event 名称、城市、开始时间。
- 来源：lineup artist、lineup member、timetable slot。
- 原始名称。
- stage、day、start/end time，如果来自 timetable。
- 当前是否已有部分成员绑定。

## 名称标准化

需要两套 key：一套用于高置信“完全匹配”，一套用于模糊匹配打分。

### `normalizedKey`

用于高置信完全匹配。

规则：

- Unicode `NFKC`，统一全角/半角。
- lowercase。
- 去重音符号，例如 `Beyoncé` -> `beyonce`。
- trim 首尾空白。
- 多个空格折叠为一个空格。
- 将常见中英文标点和分隔符统一为空格：
  - `.`, `。`, `·`, `•`, `_`, `-`, `–`, `—`, `/`, `\`, `,`, `，`, `:`, `：`
- 标点转空格后再次折叠空格。

示例：

- `Da. bin` -> `da bin`
- `Da.bin` -> `da bin`
- `Da   Bin` -> `da bin`
- `Ｄａ．ｂｉｎ` -> `da bin`

因此 `Da. bin` 和 `Da.bin` 会进入高置信完全匹配区域。

### `compactKey`

用于补充高置信匹配，但需要防误伤。

规则：

- 基于 `normalizedKey`。
- 去掉所有空格和常见分隔符。

示例：

- `Da. bin` -> `dabin`
- `Da-bin` -> `dabin`
- `Da bin` -> `dabin`

进入高置信区域的条件：

- `compactKey` 完全相等。
- `compactKey` 长度 >= 4。
- 两边至少有一个字母或中文字符。

短名字例如 `AN`, `A`, `YY` 不用 `compactKey` 自动进高置信，避免误绑。

## DJ 侧匹配源

新入库 DJ 的候选 key 来自：

- `dj.name`
- `dj.aliases`
- `dj.nameI18n.zh/en/ja/enFull`

去重后生成：

- `normalizedKeys`
- `compactKeys`

## 候选分层

### 高置信完全匹配

进入“完全匹配”区域，允许一键全选绑定。

条件任一满足：

- candidate `normalizedKey` 命中 DJ 的 `normalizedKeys`。
- candidate `compactKey` 命中 DJ 的 `compactKeys`，且符合长度/字符安全条件。

这层覆盖：

- 大小写不同。
- 多空格。
- 全角/半角不同。
- 标点差异，例如 `Da. bin` / `Da.bin`。
- 重音符号差异。

### 模糊匹配

进入“模糊匹配”区域，只能逐条勾选或由管理员选择，不默认全选。

建议打分：

- `normalizedKey` 包含关系：`+25`
- `compactKey` 包含关系：`+20`
- Levenshtein/Jaro-Winkler 相似度：
  - >= 0.92：强模糊
  - 0.86 - 0.92：中模糊
  - < 0.86：不展示
- token 集合相似度：
  - token 完全相同但顺序不同，加分。
  - token 缺 1 个短词，加少量分。

模糊区示例：

- `Martin Garrixx` vs `Martin Garrix`
- `Charlotte de Witte` vs `Charlotte Witte`
- `DJ Snake Official` vs `DJ Snake`

## 绑定策略

### Solo artist

如果 `EventArtist.primaryDjId` 为空，并且 `displayName` 命中新 DJ：

- 更新 `EventArtist.primaryDjId = dj.id`。
- 确保存在一个 `EventArtistMember`，其 `memberNameSnapshot` 为原名称，并更新 `djId = dj.id`。

### Member artist

如果 `EventArtistMember.djId` 为空，并且 `memberNameSnapshot` 命中新 DJ：

- 只更新该 member 的 `djId`。
- 不自动改 `EventArtist.primaryDjId`，除非这个 artist 只有一个 member。

### B2B / 多人组合

如果 `displayName` 是 `A b2b B`、`A / B`、`A & B`：

- 第一版优先匹配 `EventArtistMember.memberNameSnapshot`。
- 如果历史数据没有拆 member，可以生成候选但标记为 `needsSplit = true`。
- `needsSplit` 候选不能一键绑定，需要后台 UI 提醒“需要先拆成员或确认作为组合绑定”。

### Timetable

`EventPerformance` 不直接存 DJ 绑定，它通过 `eventArtistId` 指向 `EventArtist`：

- 绑定 `EventArtist` 或 member 后，timetable 展示自然同步。
- 如果 timetable slot 的 `displayNameSnapshot` 和 lineup artist display name 不一致，候选里展示 slot 名称，但落库仍改对应 artist/member。

## 数据模型建议

新增两张表。

### `DJEventBindingReviewJob`

字段：

- `id`
- `djId`
- `djNameSnapshot`
- `triggerSource`
  - `admin_create`
  - `manual_import`
  - `content_submission_approved`
  - `migration`
- `status`
  - `pending`
  - `partially_applied`
  - `applied`
  - `dismissed`
- `exactCount`
- `fuzzyCount`
- `appliedCount`
- `createdById`
- `createdAt`
- `updatedAt`
- `completedAt`

索引：

- `[djId, createdAt]`
- `[status, createdAt]`

### `DJEventBindingReviewCandidate`

字段：

- `id`
- `jobId`
- `djId`
- `eventId`
- `eventArtistId`
- `eventArtistMemberId`
- `eventPerformanceId`
- `sourceType`
  - `lineup_artist`
  - `lineup_member`
  - `timetable_slot`
- `matchTier`
  - `exact`
  - `fuzzy`
- `matchScore`
- `matchReason`
  - `normalized_equal`
  - `compact_equal`
  - `contains`
  - `similarity`
- `rawName`
- `normalizedKey`
- `compactKey`
- `eventNameSnapshot`
- `stageNameSnapshot`
- `startAtSnapshot`
- `status`
  - `pending`
  - `selected`
  - `applied`
  - `dismissed`
  - `skipped_already_bound`
- `appliedAt`
- `createdAt`

唯一约束建议：

- `[jobId, eventArtistId, eventArtistMemberId, eventPerformanceId, rawName]`

## Server 流程

### 触发函数

新增 service：

`server/src/services/dj-event-binding-review.service.ts`

核心函数：

- `createDJEventBindingReviewJobForDJ(djId, options)`
- `findCandidatesForDJ(dj)`
- `applyDJEventBindingCandidates(candidateIds, adminUserId)`
- `dismissDJEventBindingCandidates(candidateIds, adminUserId)`

触发点：

- `bff.web.routes.ts` 管理员/可绕过审核的 `manual/import` 创建 DJ 后。
- `content-submission.routes.ts` 审核通过创建 DJ 后。
- legacy/admin `dj.routes.ts` 创建 DJ 后，如果仍在使用，也接入。

建议异步执行：

- DJ 创建成功后，立即创建 job。
- 候选扫描可以同步跑，但最好包在 try/catch，不影响 DJ 入库成功。
- 如果候选数量大，后续可以改为后台 worker。

### 扫描范围

第一版扫描全部 event canonical artist/member：

- `EventArtist.primaryDjId = null`
- `EventArtistMember.djId = null`

性能优化：

- 先在应用层取未绑定行。
- 用 key set 做 O(n) exact 匹配。
- fuzzy 只对长度接近、首字符/首 token 接近的候选做相似度，避免全量 Levenshtein。

### 应用绑定

应用 candidate 时必须二次校验：

- candidate 仍为 `pending`。
- event artist/member 仍未绑定。
- 如果已经被其他流程绑定，则标记 `skipped_already_bound`。
- 不覆盖其他 DJ。

事务内更新：

- `EventArtist.primaryDjId`
- `EventArtistMember.djId`
- candidate status
- job applied count/status

## API 设计

### festival-viewer 查询待处理 job

`GET /v1/admin/dj-event-binding-review/jobs?status=pending&page=1&limit=20`

返回：

- job 基础信息。
- DJ 名称、头像。
- exact/fuzzy/applied count。

### 查询 job 详情

`GET /v1/admin/dj-event-binding-review/jobs/:id`

返回：

- job
- dj
- exactCandidates
- fuzzyCandidates

候选字段包含 event context 和 match reason。

### 应用候选

`POST /v1/admin/dj-event-binding-review/jobs/:id/apply`

body：

```json
{
  "candidateIds": ["..."]
}
```

### 一键应用 exact

`POST /v1/admin/dj-event-binding-review/jobs/:id/apply-exact`

只应用 `matchTier = exact` 且 `status = pending` 的候选。

### 忽略候选/job

`POST /v1/admin/dj-event-binding-review/jobs/:id/dismiss`

body：

```json
{
  "candidateIds": ["..."],
  "dismissAll": false
}
```

## festival-viewer UI

### 通知入口

在后台顶部或 DJ 模块入口增加一个 notification badge：

- 文案：`有 3 个新 DJ 绑定审核任务`
- 点击打开 `DJ 入库绑定审核` modal/page。

触发方式：

- 第一版轮询 `GET /v1/admin/dj-event-binding-review/jobs?status=pending&limit=10`。
- 后续可接 WebSocket/SSE。

### 任务列表

展示：

- DJ 名称/头像。
- 入库来源。
- exact/fuzzy 数量。
- 创建时间。
- 操作：打开、忽略。

### 任务详情

分两个区域：

- `完全匹配，可一键绑定`
  - 默认全选。
  - 顶部按钮：`全选完全匹配并绑定`。
  - 每条可以取消勾选。
- `模糊匹配，请人工确认`
  - 默认不选。
  - 显示 score/reason。
  - 单条勾选后点击绑定。

候选卡片展示：

- 原始名称。
- 匹配到的新 DJ 名称。
- 匹配原因，例如 `标点/空格归一后完全一致`。
- event 名称、日期、城市。
- 来源：lineup / timetable / member。
- stage/time，如果有。

## 安全和边界

- 不自动覆盖已有 `djId`。
- exact 可以一键，但仍由后台确认，不在 DJ 入库后自动绑定。
- fuzzy 永远不默认选中。
- 短名称谨慎处理：
  - `compactKey` 长度 < 4 不进 exact。
  - 只允许 `normalizedKey` 完全一致进入 exact。
- 组合艺人谨慎处理：
  - 如果需要拆分成员，标记 `needsSplit`，不一键应用。
- 所有 apply 操作写 admin audit log。

## 推荐实施顺序

- [x] 第一阶段后端实现完成。
- [ ] 新增 normalize/match utility，并写单元测试覆盖 `Da. bin` vs `Da.bin`。
- [x] 新增 Prisma 表和 migration。
- [x] 新增 `dj-event-binding-review.service.ts`，支持创建 job、扫描候选、查询 job、apply/dismiss。
- [x] 接入 DJ 创建成功触发点：BFF direct create、content-submission approved。
- [x] 接入现有 BFF direct create 的 Spotify / Discogs / manual 三条创建 DJ 路径。
- [ ] 接入 legacy admin create（如果线上仍有独立旧入口在直接 create DJ）。
- [x] 新增 admin API：job list/detail/apply/apply-exact/dismiss。
- [x] festival-viewer Review 工作台增加 DJ Binding Review 通知 badge / source 入口 / 任务列表。
- [x] festival-viewer 增加 job detail 处理界面，分 exact/fuzzy 两区，支持一键 apply exact、手动 apply selected、dismiss。
- [x] web_tool 代理新增 DJ Binding Review list/detail/apply/apply-exact/dismiss 接口。
- [x] apply 后刷新 event detail / DJ detail 相关缓存。
- [ ] 加 regression 测试：大小写、空格、标点、全角、重音、短名、已绑定不覆盖、member-only 绑定。
- [x] `workspace build` 通过。
