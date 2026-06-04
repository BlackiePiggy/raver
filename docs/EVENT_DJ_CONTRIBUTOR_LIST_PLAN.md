# Event / DJ 贡献者列表完整方案

## 1. 背景与目标

本方案目标是把 `event`、`DJ` 的“贡献者”从当前偏单人的概念，升级为可持续维护的“贡献者列表”能力，并覆盖：

- 创建者自动进入贡献者列表。
- 后续用户对 `event`、`DJ` 发起修改申请，且内容审核通过并成功写入正式数据后，也进入该对象的贡献者列表。
- iOS 详情页默认折叠展示贡献者摘要。
- 点击摘要后进入独立页面，展示完整贡献者列表、时间信息、跳转贡献者主页。
- 列表按“最近一次成功修改时间倒序”排列。

## 2. 现状审计

### 2.1 DJ 现状

当前代码里，`DJ` 已经有一层基础贡献者能力：

- 数据层已有 `dj_contributors` 表。
- 服务层 `mapDJ` 已经会把 `contributors`、`uploadedByUsername`、`isContributor`、`canEdit` 返回给 iOS。
- `createOrUpdateDJFromSubmission` 在创建和更新 DJ 成功后，已经会调用 `ensureDJContributor(...)` 把提交人加入 `dj_contributors`。

但现状仍有明显缺口：

- `dj_contributors` 只有“这个用户和 DJ 有关系”，没有“首次贡献时间 / 最近贡献时间 / 角色 / 来源 / 次数”。
- 现在无法支持“完整贡献者列表页”的时间展示。
- 现在无法严格区分“创建者”和“后续贡献者”。

### 2.2 Event 现状

当前 `event` 还没有同等级的贡献者体系：

- `events` 表没有 `created_by_id`。
- `event` 详情返回里当前只有 `organizer`，没有 `contributors`。
- `GET /v1/events/:id/summary` 的 `mapEvent(...)` 目前不返回创建者或贡献者字段。
- 现有 event 审核 / 提交流中，`content_submissions` 里能拿到 `submitterId`、`createdEntityId`、`reviewedAt` 等数据，但没有把这些归因沉淀成单独的 event 贡献者关系。

结论：

- `DJ` 适合“在现有能力上升级”。
- `event` 需要“补齐与 DJ 同构的贡献者基础设施”。

## 3. 需求拆解

基于您的描述，产品需求可拆成 4 层：

### 3.1 贡献者归因规则

- 创建对象的人，进入贡献者列表，且标记为创建者。
- 后续用户对对象发起修改申请。
- 只有当该申请通过审核，且修改成功落库后，该用户才进入贡献者列表。
- 同一用户多次贡献时，不重复新增列表项，只更新该用户在该对象上的贡献时间信息。

### 3.2 iOS 折叠摘要展示

- 默认不展开完整列表。
- 文案核心格式为：`创建人的昵称 等 X 人`。
- 只有 1 人时：显示创建人的单头像 + 名称。
- 2 人时：显示 2 个贡献者头像，采用 event detail 页 `lineup tab` 的 `b2b` 叠放样式。
- 3 人及以上时：只显示前 3 个贡献者头像，采用 `b3b` 叠放样式。

### 3.3 iOS 详情页跳转页

- 点击贡献者摘要，进入独立页面。
- 页面展示完整贡献者列表。
- 每条展示：
  - 头像
  - 昵称 / 用户名
  - 角色（创建者 / 贡献者）
  - 时间信息
- 每条都可以点击，跳转到贡献者主页。
- 默认排序：最近修改的贡献者在最上面。

### 3.4 Web overlay 详情页

- web 端这些对象的 overlay 详情页，也应该增加一个独立的 `贡献` tab。
- `贡献` tab 专门承载当前对象的贡献信息，不与简介、lineup、schedule 等内容混排。
- `贡献` tab 内展示内容与 iOS 贡献者列表页保持语义一致：
  - 完整贡献者列表
  - 创建者 / 贡献者角色
  - UTC 时间
  - 点击进入贡献者主页

### 3.5 时间展示

用户需求里提到“显示完整的贡献者列表和对应的创建时间和修改时间，精确到 UTC 日期”，这部分建议拆成：

- 创建者：
  - `创建时间` = 对象首次创建并正式入库的时间
  - `最近修改时间` = 该创建者最近一次成功贡献并生效的时间
- 非创建者：
  - 建议显示 `首次贡献时间`
  - 显示 `最近修改时间`

原因：

- 对非创建者直接显示“创建时间”会有语义误导。
- 但如果产品必须完全统一文案，也可以显示为：
  - `创建/首次贡献时间`
  - `最近修改时间`

## 4. 默认产品规则

为了让方案可直接落地，先定义一组默认规则。

### 4.1 列表排序规则

完整贡献者列表按以下规则排序：

1. `lastContributedAt` 倒序
2. 相同时间下，`creator` 优先于 `editor`
3. 再按 `firstContributedAt` 升序
4. 再按 `userId` 升序保证稳定

### 4.2 折叠摘要规则

为了兼顾“创建人昵称必须明确”与“列表默认按最近修改排序”，建议：

- 摘要文案始终使用创建者昵称：
  - `Alice`
  - `Alice 等 2 人`
  - `Alice 等 5 人`
- 摘要头像的取值规则：
  - 第一位固定为创建者
  - 其余名额从“最近修改排序后的非创建者列表”中取

这样可以保证：

- 摘要语义稳定，永远围绕创建者展开。
- 同时又能体现最近活跃的其他贡献者。

### 4.3 计入贡献者的写入时机

默认将以下两类写入都计为有效贡献：

- 审核通过后正式入库的 submission 写入
- 具有直接编辑权限、且写入正式数据成功的后台直改

原因：

- 从最终结果看，二者都属于“内容被系统正式采纳”。
- 如果只统计 submission，不统计直改，贡献者口径会在不同入口下不一致。

如果产品希望更严格限定为“必须经过审核”，可以把第二类排除掉，但需要额外接受口径割裂。

## 5. 数据模型设计

## 5.1 DJ：升级现有 `dj_contributors`

当前 `dj_contributors` 建议升级为“可表达贡献历史摘要”的关系表。

建议新增字段：

- `role`
  - `creator | editor`
- `first_contributed_at`
  - 该用户第一次对这个 DJ 的有效贡献时间
- `last_contributed_at`
  - 该用户最近一次有效贡献时间
- `contribution_count`
  - 成功被采纳的贡献次数
- `first_submission_id`
  - 首次贡献对应的 submission id，可空
- `last_submission_id`
  - 最近一次贡献对应的 submission id，可空
- `last_contribution_source`
  - `submission_create | submission_edit | direct_commit | backfill`

保留字段：

- `id`
- `dj_id`
- `user_id`
- `created_at`
- `updated_at`

说明：

- `created_at / updated_at` 继续保留为关系行自身审计字段。
- 前端展示时间统一使用 `first_contributed_at / last_contributed_at`，不要直接使用 `created_at / updated_at`。

## 5.2 Event：新增 `event_contributors`

由于 event 当前没有对应关系表，建议新增：

### `event_contributors`

字段建议：

- `id`
- `event_id`
- `user_id`
- `role`
  - `creator | editor`
- `first_contributed_at`
- `last_contributed_at`
- `contribution_count`
- `first_submission_id`
- `last_submission_id`
- `last_contribution_source`
  - `submission_create | submission_edit | direct_commit | backfill`
- `created_at`
- `updated_at`

索引建议：

- unique(`event_id`, `user_id`)
- index(`event_id`, `last_contributed_at desc`)
- index(`user_id`, `last_contributed_at desc`)
- index(`event_id`, `role`)

## 5.3 是否要给 `events` / `djs` 增加 `created_by_id`

本方案建议：

- `DJ` 暂不新增 `created_by_id`
- `event` 暂不新增 `created_by_id`

而是统一通过贡献者表中：

- `role = creator`

来解析创建者。

原因：

- 与现有 `dj_contributors` 升级方向一致。
- 避免对象主表与贡献者关系表双写出一致性问题。
- 当前读取场景主要是详情页和列表页，查询 creator relation 成本可控。

如果后续出现强烈的性能诉求，再做 creator id 冗余字段。

## 6. 贡献归因写入规则

## 6.1 创建对象时

### DJ 创建

- 创建 DJ 成功后：
  - upsert `dj_contributors`
  - `role = creator`
  - `first_contributed_at = DJ.createdAt`
  - `last_contributed_at = DJ.createdAt`
  - `contribution_count = 1`

### Event 创建

- event 首次创建并正式入库成功后：
  - upsert `event_contributors`
  - `role = creator`
  - `first_contributed_at = Event.createdAt`
  - `last_contributed_at = Event.createdAt`
  - `contribution_count = 1`

## 6.2 修改对象时

当一次编辑成功被采纳并正式写入对象后：

- 如果该用户此前不在贡献者表中：
  - 新增一条 contributor
  - `role = editor`
  - `first_contributed_at = approvedAt`
  - `last_contributed_at = approvedAt`
  - `contribution_count = 1`
- 如果该用户已存在：
  - 不新增
  - 更新 `last_contributed_at = approvedAt`
  - `contribution_count += 1`
  - 若原角色为 `creator`，保持 `creator`
  - 若原角色为 `editor`，保持 `editor`

## 6.3 只有“成功生效”的修改才记贡献

以下情况不进入贡献者列表：

- 提交了申请但被拒绝
- 提交通过但落库失败
- 处理中 / 审核中
- 被后续 submission supersede，且未真正生效

## 6.4 是否要求“内容有实质变化”

建议默认要求“成功写入且有实质字段变化”才计为一次贡献。

建议判定口径：

- 如果这次提交最终导致对象 revision 增长，记为贡献。
- 如果只是重复提交完全相同内容、最终未造成任何正式数据变化，不记贡献次数，也不更新最近修改时间。

这样可以避免用户通过无意义重复提交刷贡献列表。

## 7. 后端落地方案

## 7.1 Prisma / Migration

建议变更：

- 更新 `server/prisma/schema.prisma`
- 新增 migration：
  - 扩展 `dj_contributors`
  - 新建 `event_contributors`

建议新增 Prisma model：

- `EventContributor`
- 扩展现有 `DJContributor`

## 7.2 服务层抽象

建议新增统一 helper，避免 event / DJ 各写一套近似逻辑：

- `upsertDJContributorContribution(...)`
- `upsertEventContributorContribution(...)`
- 或进一步抽象为统一 service：
  - `recordEntityContribution({ entityType, entityId, userId, role, contributedAt, submissionId, source })`

推荐先保持 event / DJ 两套 helper，但共享内部通用逻辑，原因是：

- 当前 repo 已经是按实体拆表拆 service 风格。
- 改动更贴近现有代码结构。

## 7.3 DJ 写路径

重点改造点：

- `server/src/services/content-submission-dj.service.ts`

把当前的：

- `ensureDJContributor(...)`

升级为：

- `recordDJContribution(...)`

行为变更：

- 创建 DJ 时写 creator
- 编辑 DJ 且落库成功时写 editor / update contributor timestamp
- 支持记录 `submissionId`、`approvedAt`

## 7.4 Event 写路径

重点改造点：

- `server/src/services/content-submission-event.service.ts`
- 以及任何绕过 submission 直接落 event 正式数据的管理写口

新增：

- `recordEventContribution(...)`

触发时机：

- event 创建成功后
- event 编辑成功写入后
- 直接管理权限写入成功后

## 7.5 审核完成与时间来源

建议时间优先级：

1. 如果是审核型 submission：
   - 取 `reviewedAt`
2. 如果是 direct commit：
   - 取本次写事务成功时间
3. fallback：
   - 取对象 `updatedAt`

## 8. 读取接口设计

## 8.1 Event 详情摘要接口

当前 `GET /v1/events/:id/summary` 建议增加以下字段：

- `contributors`
  - 轻量版贡献者数组，至少含用户基础信息
- `contributorSummary`
  - 专门给折叠摘要 UI 用
- `isContributor`
  - 当前查看人是否是贡献者
- `canEdit`
  - 当前查看人是否可编辑

建议结构：

```json
{
  "contributors": [
    {
      "id": "user_1",
      "username": "alice",
      "displayName": "Alice",
      "avatarUrl": "..."
    }
  ],
  "contributorSummary": {
    "creatorUserId": "user_1",
    "creatorDisplayName": "Alice",
    "totalCount": 5,
    "previewUsers": [
      { "id": "user_1", "displayName": "Alice", "avatarUrl": "..." },
      { "id": "user_2", "displayName": "Bob", "avatarUrl": "..." },
      { "id": "user_3", "displayName": "Chris", "avatarUrl": "..." }
    ],
    "previewStyle": "b3b",
    "latestContributedAt": "2026-06-04T10:22:33.000Z"
  }
}
```

## 8.2 DJ 详情摘要接口

当前 DJ 已返回 `contributors`，建议补齐：

- `contributorSummary`
- 每位 contributor 的角色与时间信息不要直接塞进 DJ 详情主接口，避免主包过重

即：

- `GET /v1/djs/:id`
  - 返回轻量 contributors + contributorSummary
- `GET /v1/djs/:id/contributors`
  - 返回完整列表

## 8.3 新增完整列表接口

建议新增两个接口：

- `GET /v1/events/:id/contributors`
- `GET /v1/djs/:id/contributors`

返回结构建议：

```json
{
  "items": [
    {
      "user": {
        "id": "user_1",
        "username": "alice",
        "displayName": "Alice",
        "avatarUrl": "..."
      },
      "role": "creator",
      "firstContributedAt": "2026-05-01T08:00:00.000Z",
      "lastContributedAt": "2026-05-16T09:30:00.000Z",
      "contributionCount": 3,
      "latestSubmissionId": "sub_123"
    }
  ],
  "total": 5
}
```

前端展示文案映射：

- `role = creator` -> `创建者`
- `role = editor` -> `贡献者`

## 8.4 时间格式

后端统一返回 ISO 8601 UTC：

- `2026-06-04T10:22:33.000Z`

iOS 统一格式化成：

- `2026-06-04 10:22:33 UTC`

不要返回本地化字符串，避免客户端无法稳定控制样式。

web overlay 端也应统一格式化成：

- `2026-06-04 10:22:33 UTC`

不要让 web / iOS 对同一贡献时间出现不同口径。

## 9. iOS 端设计

## 9.1 数据模型

建议扩展：

- `WebEvent`
  - 新增 `contributors: [WebUserLite]?`
  - 新增 `contributorSummary: WebContributorSummary?`
  - 新增 `isContributor: Bool?`
  - 新增 `canEdit: Bool?`
- `WebDJ`
  - 已有 `contributors`
  - 新增 `contributorSummary: WebContributorSummary?`
- 新增：
  - `WebContributorSummary`
  - `WebEntityContributorItem`

建议结构：

```swift
struct WebContributorSummary: Codable, Hashable {
    var creatorUserId: String
    var creatorDisplayName: String
    var totalCount: Int
    var previewUsers: [WebUserLite]
    var previewStyle: String
    var latestContributedAt: Date?
}

struct WebEntityContributorItem: Codable, Hashable, Identifiable {
    var id: String { user.id }
    var user: WebUserLite
    var role: String
    var firstContributedAt: Date?
    var lastContributedAt: Date?
    var contributionCount: Int
}
```

## 9.2 摘要组件

建议新增一个通用组件：

- `ContributorSummaryRow`

复用范围：

- event detail
- DJ detail

组件职责：

- 处理 1 人 / 2 人 / 3+ 人样式切换
- 生成摘要文案
- 接收点击回调

### 摘要样式规则

#### 1 人

- 单头像
- 创建者昵称

示例：

- `[头像] Alice`

#### 2 人

- 2 个头像叠放
- 直接复用 event detail lineup tab 的 `b2b` 叠放视觉
- 文案：`Alice 等 2 人`

#### 3 人及以上

- 取 3 个头像叠放
- 复用 `b3b` 叠放视觉
- 文案：`Alice 等 X 人`

## 9.3 Event 详情页接入位置

建议放在 event detail 头部信息区域内，位置优先级：

1. 标题 / 时间 / 地点下面
2. 描述和 lineup tab 上面

原因：

- 贡献者信息属于“这个对象是谁维护出来的”，是对象元信息。
- 不应埋得太深。

## 9.4 DJ 详情页接入位置

建议放在 DJ hero / stats 区块下方、简介上方。

原因：

- DJ 详情页顶部已有身份和统计信息。
- 贡献者摘要更适合作为一个轻量 metadata row 插入，不打断主阅读流。

## 9.5 完整贡献者列表页

建议新建一个通用页面：

- `ContributorListView`

入参：

- `entityType: event | dj`
- `entityId`
- `title`

页面结构：

- Navigation title：`贡献者`
- 顶部 summary：
  - 总人数
  - 最近更新时间（可选）
- 列表 cell：
  - 左侧头像
  - 中间昵称 / 用户名
  - 角色 badge
  - 时间两行
  - 右侧跳转箭头

### Cell 时间展示建议

#### 创建者

- `创建时间：2026-06-01 08:00:00 UTC`
- `最近修改：2026-06-03 14:22:10 UTC`

#### 非创建者

- `首次贡献：2026-06-02 11:10:00 UTC`
- `最近修改：2026-06-04 17:45:09 UTC`

如果产品强制要统一文案，则显示：

- `创建/首次贡献：...`
- `最近修改：...`

## 9.6 跳转用户主页

每条 contributor cell 点击后：

- event contributor -> 用户主页
- DJ contributor -> 用户主页

建议直接复用现有 profile route，不新增 contributor 专属路由。

## 9.7 Web overlay 详情页

web 端 overlay 详情页建议新增一个独立的 `贡献` tab，纳入与对象详情同级的 tab 体系。

推荐范围：

- event overlay detail
- DJ overlay detail

推荐规则：

- `贡献` tab 单独存在，不塞进简介正文。
- `贡献` tab 展示完整贡献者列表，而不是只显示摘要。
- 排序规则与 iOS 一致：
  - `lastContributedAt desc`
- 时间展示与 iOS 一致：
  - UTC 精确到秒
- 每条贡献者支持点击跳转到对应主页或 profile overlay。

如果首期 web 只先做 event overlay，也建议后端数据结构按 event / DJ 一起设计，避免后续二次返工。

## 10. 视觉与交互细节

## 10.1 不展开的定义

“默认不展开”建议实现为：

- 在详情页只显示一行贡献者摘要
- 不在详情页内联展开完整列表
- 点击后进入独立页面

不建议做详情页内 accordion 展开，因为：

- 完整列表还有跳主页需求
- 还要展示时间，内容长度明显超过一行摘要

## 10.2 头像叠放复用策略

建议不要复制一套新样式，而是抽出当前 lineup tab 用到的叠放头像逻辑，形成通用组件：

- `OverlappingAvatarStack`

支持：

- `solo`
- `b2b`
- `b3b`

这样 event detail / contributor summary 都可以共用。

## 10.3 空状态

理论上不会出现 0 个 contributor 的正式对象。

但为了安全：

- 如果对象没有 contributor 数据：
  - 摘要入口隐藏
  - 列表页显示 `暂无贡献者`

## 10.4 异常降级

如果详情主接口成功，但 contributor 列表接口失败：

- 详情页摘要继续显示
- 进入完整列表页时展示错误卡片 + 重试

## 11. 回填策略

## 11.1 DJ 回填

由于 DJ 已有 `dj_contributors`，建议：

### 第一阶段

- 为现有 `dj_contributors` 回填：
  - `role`
  - `first_contributed_at`
  - `last_contributed_at`
  - `contribution_count`

### 回填规则

- 能从 `content_submissions` 准确找到 DJ 创建 submission 的：
  - 最早创建者标记为 `creator`
- 能从历史 approved DJ submissions 找到编辑记录的：
  - 回填对应 contributor 的 first / last contributed time
- 如果无法高置信回推历史编辑：
  - 保底保留现有 contributor 关系
  - `first_contributed_at = existing.created_at`
  - `last_contributed_at = existing.updated_at`
  - `last_contribution_source = backfill`

## 11.2 Event 回填

event 没有现成 contributor 关系，建议分层回填：

### 第一阶段

- 从 `content_submissions`
  - `entityType = event`
  - `status = approved`
  - `createdEntityId = event.id`

回推 contributor 记录。

### 回填优先级

1. 能识别“创建 submission”的，标记 creator
2. 能识别后续 approved edits 的，写 editor
3. 完全无法识别创建来源的 event：
   - 不盲目把 `organizerId` 当 creator
   - 只在有业务共识时才 fallback 到 organizer

原因：

- `organizer` 是主办方，不一定是内容创建者。
- 直接拿 organizer 兜底会污染贡献者口径。

### 建议策略

对历史 event 回填采用“宁可少，不可错”：

- 高置信数据才回填 contributor
- 低置信 event 保持 creator 空缺，待后续人工或二次脚本补齐

如果产品必须要求所有 event 都有 creator，则可以加一个产品兜底策略：

- 当历史数据无法识别 creator 时，前端显示 `Raver` 或 `官方整理`

但这不建议作为第一优先方案。

## 12. 权限与安全

贡献者身份不等于编辑权限。

建议维持：

- `canEdit` 继续由现有业务权限判定
- `isContributor` 只表示是否在贡献者列表中

避免出现：

- 某用户曾贡献过一次，就永久获得该对象编辑权限

权限仍应由：

- admin
- organizer / manager
- 现有 contributor-based DJ edit rules

分别控制。

## 13. 埋点与可观测性

建议增加事件埋点：

- `contributor_summary_tapped`
  - `entityType`
  - `entityId`
  - `totalCount`
- `contributor_list_profile_tapped`
  - `entityType`
  - `entityId`
  - `targetUserId`
- `contributor_record_written`
  - `entityType`
  - `entityId`
  - `userId`
  - `role`
  - `source`

建议日志：

- 贡献者写入成功 / 跳过 / 幂等命中
- 回填脚本统计：
  - 扫描对象数
  - 写入 contributor 数
  - 无法判定 creator 数

## 14. 测试方案

## 14.1 后端测试

必须覆盖：

- 创建 DJ -> creator 入表
- 编辑 DJ 审核通过 -> editor 入表
- 同一 editor 第二次通过 -> 不重复新增，只更新时间与次数
- rejected submission -> 不入表
- approved 但落库失败 -> 不入表
- 创建 event -> creator 入表
- 编辑 event -> editor 入表
- contributor 列表按 `lastContributedAt desc` 排序
- contributorSummary 1 / 2 / 3+ 样式输出正确

## 14.2 iOS 测试

必须覆盖：

- 1 contributor 摘要样式
- 2 contributors 摘要样式
- 3+ contributors 摘要样式
- creator 文案正确
- 点击摘要进入完整列表页
- 列表页时间格式正确且为 UTC
- 点击 contributor 进入用户主页
- 网络失败降级

web 也必须覆盖：

- overlay detail 出现独立 `贡献` tab
- `贡献` tab 内贡献者列表排序正确
- UTC 时间展示正确
- 点击贡献者进入主页链路正确

## 14.3 回填验证

必须抽样检查：

- 已知 creator 的 DJ
- 已知多人编辑过的 DJ
- 已知走审核流的 event
- 无法判定 creator 的历史 event

## 15. 实施顺序建议

建议拆成 4 个阶段：

### Phase 1. 数据与后端写链路

- 扩展 `dj_contributors`
- 新增 `event_contributors`
- 接入 DJ / event 正式写入路径
- 补充 contributors 详情接口

### Phase 2. 后端读接口与 iOS 数据模型

- 扩展 event / DJ 详情返回
- 接入 `contributorSummary`
- iOS 增加模型定义

### Phase 3. iOS UI

- 摘要组件
- 完整列表页
- 用户主页跳转

### Phase 3.5 Web overlay UI

- event overlay 增加 `贡献` tab
- DJ overlay 增加 `贡献` tab
- tab 内接入完整贡献者列表
- 与 iOS 时间 / 排序 / 角色口径对齐

### Phase 4. 历史回填与 QA

- 回填脚本
- 抽样校验
- 上线灰度

## 16. 具体代码落点建议

后端：

- `server/prisma/schema.prisma`
- `server/src/services/content-submission-dj.service.ts`
- `server/src/services/content-submission-event.service.ts`
- `server/src/routes/bff.web.routes.ts`
- 回填脚本建议新增到 `server/src/scripts/`

iOS：

- `mobile/ios/RaverMVP/RaverMVP/Core/WebFeatureModels.swift`
- `mobile/ios/RaverMVP/RaverMVP/Core/LiveWebFeatureService.swift`
- `mobile/ios/RaverMVP/RaverMVP/Features/Discover/DJs/Views/DJsModuleView.swift`
- event detail 对应 view 文件
- 新增通用组件：
  - `ContributorSummaryRow`
  - `OverlappingAvatarStack`
  - `ContributorListView`

web：

- web overlay detail 对应 tab 容器
- `ContributionTabPanel`
- 贡献者列表展示组件

## 17. 风险与注意事项

### 17.1 “创建者”与“主办方”不是一个概念

这是本需求最大的语义风险。

- `organizer`
  - 是活动主办方
- `creator`
  - 是谁把该内容创建进系统

两者不能混用。

### 17.2 历史数据可能无法完整回推

尤其是老 event。

因此历史回填要接受：

- 部分对象只能先补 creator
- 部分对象短期内无法恢复完整编辑历史

### 17.3 贡献者不应被刷榜

如果没有“实质修改”判断，容易出现：

- 用户重复提交同内容刷最近修改时间

因此建议把“是否造成正式数据变化”作为计数前置条件。

## 18. 验收标准

以下全部满足，视为需求完成：

- event、DJ 都能展示贡献者摘要
- web overlay detail 能展示独立 `贡献` tab
- 创建者默认进入贡献者列表
- 审核通过并成功落库的后续编辑者进入贡献者列表
- 1 / 2 / 3+ 人摘要样式符合要求
- 点击摘要进入独立贡献者列表页
- web `贡献` tab 能展示完整贡献者列表
- 列表按最近修改倒序
- 每条可跳转用户主页
- 时间按 UTC 精确展示
- 历史数据至少能保证 creator 与高置信编辑记录被回填

## 19. 待确认项

以下 4 项建议您拍板后再进入正式开发：

### 19.1 非创建者的时间文案

推荐：

- 创建者显示 `创建时间`
- 非创建者显示 `首次贡献时间`

如果您坚持统一文案，也可以全部显示 `创建/首次贡献时间`。

### 19.2 直改是否计入贡献者

推荐计入，只要正式数据成功写入。

否则同样的最终修改，走不同入口会得到不同贡献者结果。

### 19.3 折叠摘要头像顺序

推荐：

- 文案永远使用创建者昵称
- 头像第一位固定创建者
- 其余头像按最近修改顺序补齐

### 19.4 历史 event 无法识别 creator 时是否允许 fallback 到 organizer

我不推荐默认 fallback。

推荐先保持严格口径，只回填高置信 creator。

---

## 20. 本方案采用的默认假设

为了先把方案完整落文档，本文默认采用以下假设：

- 非创建者页面文案使用 `首次贡献时间`
- 直改成功也计入贡献者
- 折叠摘要头像固定包含创建者
- 历史 event creator 不默认 fallback 到 organizer

如果您确认这 4 条，我们就可以直接进入开发拆解。
