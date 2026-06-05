# 贡献模块执行 Tracker

关联方案：

- [EVENT_DJ_CONTRIBUTOR_LIST_PLAN.md](/Users/blackie/Projects/raver/docs/EVENT_DJ_CONTRIBUTOR_LIST_PLAN.md)
- [CONTRIBUTION_MODULE_RELEASE_CHECKLIST.md](/Users/blackie/Projects/raver/docs/CONTRIBUTION_MODULE_RELEASE_CHECKLIST.md)

---

## 1. 模块定义

`贡献模块` 是一个独立能力模块，负责统一管理：

- `event` / `DJ` 的贡献者关系
- 每个账号的贡献历史流水
- iOS 详情页的贡献者摘要与完整列表
- web overlay 详情页的独立 `贡献` tab
- iOS 个人主页的 `贡献中心` 快捷入口
- iOS `贡献中心` 页面中的历史贡献总览

本模块明确不负责：

- 审核策略本身
- 对象编辑权限本身
- profile 基础资料模块
- `My Publishes` / `content submission` 原有任务态页面的职责

也就是说：

- `My Publishes`
  - 关注“我提交了什么任务、任务状态如何”
- `贡献模块`
  - 关注“哪些内容正式采纳了我的贡献、我的历史贡献是什么”

---

## 2. 模块边界

### 2.1 Backend 边界

贡献模块后端只做三件事：

1. 记录对象维度的当前贡献者关系
2. 记录用户维度的贡献历史流水
3. 提供对象维度和用户维度的读取接口

贡献模块后端不直接决定：

- 这个用户是否能编辑
- submission 是否该通过审核
- profile 页面如何排版

### 2.2 Client 边界

贡献模块客户端只做四件事：

1. 在 event / DJ 详情页展示贡献者摘要与列表
2. 在 web overlay 详情页展示独立 `贡献` tab
3. 在个人主页提供 `贡献中心` 快捷入口
4. 在 `贡献中心` 页面展示账号的历史贡献

贡献模块客户端不负责：

- 审核任务详情编辑
- 用户资料编辑
- 原有 `我的发布` 任务管理

---

## 3. 模块内子域

为了降低耦合，贡献模块内部再拆成两个子域。

### 3.1 A 域：Contributor Registry

职责：

- 维护对象当前有哪些贡献者
- 维护创建者、最近修改时间、贡献次数
- 支撑 event / DJ 详情页摘要与完整贡献者列表

核心对象：

- `event_contributors`
- 升级后的 `dj_contributors`

### 3.2 B 域：Contribution History Ledger

职责：

- 记录用户的每一次有效贡献历史
- 支撑个人主页 `贡献中心`
- 支撑“我历史上贡献过哪些 event / DJ”

核心对象：

- `contribution_history_entries`

这个历史流水必须是追加式的，不应只靠 contributor relation 倒推。

原因：

- contributor relation 只能表达“当前状态”
- 贡献中心需要表达“历史过程”
- 同一用户对同一对象多次贡献，需要逐条保留

---

## 4. 模块目标

### 4.1 第一阶段目标

- event 支持贡献者列表
- DJ 升级为完整贡献者列表
- iOS event / DJ 详情页都能展示贡献者摘要
- web event / DJ overlay 详情页都能展示独立 `贡献` tab
- 点击可进入完整贡献者列表页
- 列表支持时间、角色、跳用户主页

### 4.2 第二阶段目标

- iOS 个人主页新增 `贡献中心` 快捷入口
- `贡献中心` 页面展示当前账号的全部历史贡献
- 历史贡献按时间倒序
- 支持按实体类型筛选：
  - 全部
  - Event
  - DJ

### 4.3 第三阶段目标

- 历史数据回填
- 埋点与监控
- 回归 checklist 固化

---

## 5. 数据模型总览

## 5.1 Contributor Registry

### `event_contributors`

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
- `created_at`
- `updated_at`

### `dj_contributors` 升级

保留现有主键与唯一约束，新增：

- `role`
- `first_contributed_at`
- `last_contributed_at`
- `contribution_count`
- `first_submission_id`
- `last_submission_id`
- `last_contribution_source`

## 5.2 Contribution History Ledger

建议新增统一历史流水表：

### `contribution_history_entries`

- `id`
- `user_id`
- `entity_type`
  - `event | dj`
- `entity_id`
- `entity_title_snapshot`
- `entity_cover_snapshot`
- `role_snapshot`
  - `creator | editor`
- `action_type`
  - `create | edit`
- `source`
  - `submission_create | submission_edit | direct_commit | backfill`
- `submission_id`
- `occurred_at`
- `approved_at`
- `version_after`
- `change_summary`
- `metadata`
- `created_at`

说明：

- `occurred_at`
  - 该次贡献真正生效的时间
- `approved_at`
  - 审核通过时间，可空
- `entity_title_snapshot`
  - 避免对象后续改名导致历史页全部跟着变化
- `change_summary`
  - 给贡献中心列表提供一行轻量摘要

---

## 6. 读接口范围

## 6.1 对象维度接口

- `GET /v1/events/:id/summary`
  - 增加 `contributors`
  - 增加 `contributorSummary`
  - 增加 `isContributor`
  - 增加 `canEdit`
- `GET /v1/events/:id/contributors`

- `GET /v1/djs/:id`
  - 补 `contributorSummary`
- `GET /v1/djs/:id/contributors`

## 6.2 用户维度接口

建议新增：

- `GET /v1/me/contribution-center/summary`
- `GET /v1/me/contributions`

推荐首版只做 `me` 维度，不开放任意用户贡献历史查询。

### `GET /v1/me/contribution-center/summary`

建议返回：

- 总贡献次数
- 贡献过的 event 数
- 贡献过的 DJ 数
- 最近一次贡献时间
- 最近贡献的 3 条预览

### `GET /v1/me/contributions`

支持：

- 游标分页
- `entityType=all|event|dj`
- `cursor`
- `limit`

返回：

- 历史贡献条目列表
- 分页信息

---

## 7. iOS 范围

## 7.1 event / DJ 详情页

- 贡献者摘要组件
- 贡献者完整列表页

## 7.1.1 Web overlay 详情页

- event overlay detail 新增 `贡献` tab
- DJ overlay detail 新增 `贡献` tab
- `贡献` tab 内展示完整贡献者列表
- 点击 contributor 跳对应主页 / profile overlay

## 7.2 个人主页快捷入口

当前 `ProfileView.swift` 已有 `快捷入口` 卡片和 `我的发布` 入口。

建议新增：

- `贡献中心`

放置策略：

- 与 `我的发布` 同层
- 默认放在 `我的发布` 后面

建议文案：

- 中文：`贡献中心`
- 英文：`Contributions`
- 日文：`貢献センター`

## 7.3 贡献中心页面

建议新建：

- `ContributionCenterView`

页面内容：

1. 顶部总览卡
   - 总贡献次数
   - 贡献过的 Event 数
   - 贡献过的 DJ 数
   - 最近贡献时间
2. 筛选栏
   - 全部
   - Event
   - DJ
3. 历史列表
   - 每条显示对象封面 / 标题 / 类型 / 角色 / 时间 / 变更摘要
4. 点击跳转
   - event -> event detail
   - DJ -> DJ detail

## 7.4 贡献中心与我的发布的区别

`我的发布`

- 看 submission 任务与状态
- 关注“是否审核通过”

`贡献中心`

- 看已经生效的正式贡献历史
- 关注“哪些贡献真正成为了线上内容”

两者要并存，不互相替代。

---

## 8. 执行原则

- 优先保持贡献模块自包含
- 新增的读写逻辑尽量聚合到专门 service
- 不把贡献历史页面逻辑散落进 Profile 主逻辑
- 不让 `My Publishes` 直接承担贡献中心职责
- 不把对象贡献者摘要与个人贡献历史混成一个接口

---

## 9. Phase Checklist

> 执行规则：每完成一项即勾选；如果范围变更，在本 tracker 的 `变更日志` 记录原因。

### Phase 0. 模块边界冻结

- [x] 确认贡献模块独立边界，不并入 `My Publishes`。
- [x] 确认个人主页只增加 `贡献中心` 快捷入口，不改写 profile 主信息结构。
- [x] 确认用户维度历史页首版只支持“查看我自己的贡献历史”。
- [x] 确认 contribution history 采用独立流水表，而不是只靠 relation 表倒推。

### Phase 1. 数据层

- [x] 为 `dj_contributors` 增加角色、时间、次数、来源字段。
- [x] 新增 `event_contributors`。
- [x] 新增 `contribution_history_entries`。
- [x] 为上述表补齐唯一约束、排序索引、用户维度索引。
- [x] 输出 migration 风险说明。

### Phase 2. 写链路接入

- [x] DJ 创建成功时写 creator relation。
- [x] DJ 编辑成功生效时写 editor relation。
- [x] event 创建成功时写 creator relation。
- [x] event 编辑成功生效时写 editor relation。
- [x] 每一次有效贡献同步写入 `contribution_history_entries`。
- [x] rejected / failed / no-op submission 不写历史流水。
- [x] direct commit 是否计入贡献已按已确认规则实现。

### Phase 3. 对象维度读接口

- [x] `GET /v1/events/:id/summary` 增加 contributor summary。
- [x] 新增 `GET /v1/events/:id/contributors`。
- [x] `GET /v1/djs/:id` 增加 contributor summary。
- [x] 新增 `GET /v1/djs/:id/contributors`。
- [x] event / DJ 贡献者列表统一排序规则。
- [x] 时间统一按 UTC ISO 输出。

### Phase 4. 用户维度读接口

- [x] 新增 `GET /v1/me/contribution-center/summary`。
- [x] 新增 `GET /v1/me/contributions`。
- [x] 支持 `all / event / dj` 筛选。
- [x] 支持分页与空状态。
- [x] 为历史条目补齐对象标题 / 封面 / 摘要快照。

### Phase 5. iOS 数据模型与路由

- [x] 扩展 `WebEvent` contributor 相关字段。
- [x] 扩展 `WebDJ` contributorSummary 字段。
- [x] 新增 `WebEntityContributorItem`。
- [x] 新增 `WebContributionHistoryItem`。
- [x] `ProfileRoute` 增加 `contributionCenter`。
- [x] 必要时 `AppRoute` 或 discover/profile coordinator 补充深链支持。

### Phase 6. iOS 对象详情页

- [x] event detail 接入 `ContributorSummaryRow`。
- [x] DJ detail 接入 `ContributorSummaryRow`。
- [x] 抽出 `OverlappingAvatarStack` 复用 `solo / b2b / b3b`。
- [x] 新增 `ContributorListView`。
- [x] contributor cell 点击跳转用户主页。
- [x] 1 人 / 2 人 / 3+ 人摘要样式全部对齐。

### Phase 6.5 Web overlay 对象详情页

- [x] event overlay detail 增加独立 `贡献` tab。
- [x] DJ overlay detail 增加独立 `贡献` tab。
- [x] `贡献` tab 接入完整贡献者列表。
- [x] web 时间展示与 iOS 保持 UTC 口径一致。
- [x] web contributor 点击跳转主页链路完成。

### Phase 7. iOS 个人主页与贡献中心

- [x] 个人主页 `快捷入口` 增加 `贡献中心`。
- [x] 新建 `ContributionCenterView`。
- [x] 顶部 summary card 接口联调完成。
- [x] 历史列表分页加载完成。
- [x] `全部 / Event / DJ` 筛选完成。
- [x] 点击历史条目可跳转对应对象详情页。
- [x] 空状态、失败重试、离线降级完成。

### Phase 8. 回填与校验

- [x] DJ contributor 历史字段回填脚本完成。
- [x] event contributor relation 回填脚本完成。
- [x] contribution history 回填策略明确。
- [x] 无法高置信回推 creator 的历史 event 有明确兜底处理。
- [ ] 抽样校验 20 个 DJ / 20 个 event。

说明：

- 本地已完成 `dry-run` 验证，并补齐独立 `verify` 脚本。
- 正式回填执行后置到更接近线上数据规模的环境，不作为当前开发阻塞项。

### Phase 9. 埋点与监控

- [x] contributor summary 点击埋点完成。
- [x] contributor list profile 点击埋点完成。
- [x] contribution center 曝光与筛选埋点完成。
- [x] contribution record 写入日志完成。
- [x] 回填脚本输出统计日志完成。

### Phase 10. QA 与发布门禁

- [ ] 后端单测补齐。
- [x] iOS 交互 smoke checklist 补齐。
- [ ] 个人主页入口回归完成。
- [ ] event / DJ 详情页贡献者展示回归完成。
- [ ] contribution center 历史链路回归完成。
- [x] 文档与 tracker 状态同步。

---

## 10. 任务 Checklist

## 10.1 Backend 数据任务

- [x] 定义 `event_contributors` Prisma model。
- [x] 扩展 `DJContributor` Prisma model。
- [x] 定义 `ContributionHistoryEntry` Prisma model。
- [x] 增加 migration SQL。
- [x] 增加数据库回滚说明。

## 10.2 Backend 写入任务

- [x] 新增 `recordEventContribution(...)`。
- [x] 新增 `recordDJContribution(...)`。
- [x] 新增 `recordContributionHistoryEntry(...)`。
- [x] event 写链路接入贡献模块。
- [x] DJ 写链路接入贡献模块。
- [x] 统一 no-op 判定。

## 10.3 Backend 读取任务

- [x] 实现 event contributor summary builder。
- [x] 实现 DJ contributor summary builder。
- [x] 实现 contributor list query。
- [x] 实现 my contribution center summary query。
- [x] 实现 my contributions history query。

## 10.4 iOS 路由任务

- [x] `ProfileRoute.contributionCenter`
- [x] `ProfileCoordinatorView` 导航接线
- [x] 如有需要补深链：`raver://profile/contributions`

## 10.5 iOS UI 任务

- [x] `ContributorSummaryRow`
- [x] `OverlappingAvatarStack`
- [x] `ContributorListView`
- [x] `ContributionCenterView`
- [x] `ContributionHistoryRow`
- [x] `ContributionCenterSummaryCard`

## 10.5.1 Web UI 任务

- [x] web event overlay `贡献` tab
- [x] web DJ overlay `贡献` tab
- [x] `ContributionTabPanel`
- [x] web contributor list row
- [x] web UTC time formatter

## 10.6 文案任务

- [ ] `贡献中心`
- [ ] `全部贡献`
- [ ] `贡献过的活动`
- [ ] `贡献过的 DJ`
- [ ] `最近贡献`
- [ ] `首次贡献`
- [ ] `最近修改`
- [ ] `创建者`
- [ ] `贡献者`
- [ ] `暂无贡献记录`

---

## 11. 验收 Checklist

### 11.1 对象详情

- [x] event 详情页能显示贡献者摘要。
- [x] DJ 详情页能显示贡献者摘要。
- [x] 1 人时摘要样式正确。
- [x] 2 人时摘要样式正确。
- [x] 3+ 人时摘要样式正确。
- [x] 点击进入完整贡献者列表页。
- [x] 列表按最近修改倒序。
- [x] 列表时间显示为 UTC。
- [x] 点击 contributor 跳用户主页。
- [x] web overlay detail 存在独立 `贡献` tab。
- [x] web `贡献` tab 内列表排序与时间展示正确。
- [x] web `贡献` tab 点击 contributor 跳转正确。

### 11.2 个人主页与贡献中心

- [x] 个人主页快捷入口出现 `贡献中心`。
- [x] 点击可进入贡献中心。
- [x] 贡献中心顶部 summary 正确。
- [x] 历史页能展示 event 与 DJ 两类贡献。
- [x] 筛选可用。
- [x] 点击历史条目可跳对象详情。
- [x] 空状态与加载态完整。

### 11.3 贡献历史准确性

- [ ] 创建对象后，创建者历史出现 1 条 create 记录。
- [ ] 编辑审核通过后，出现 1 条 edit 记录。
- [ ] 重复编辑同一对象，历史可见多条记录。
- [ ] 被拒绝 submission 不出现在贡献中心。
- [ ] 未生效修改不出现在贡献中心。

---

## 12. 风险清单

- [ ] 历史 event creator 无法完整回推。
- [ ] direct commit 与审核流混合导致口径不一致。
- [ ] no-op 判定不严谨导致刷贡献次数。
- [ ] 对象改名后历史页快照与当前标题不一致。
- [ ] profile 首页入口过多导致视觉拥挤。

## 12.1 回填 / 发布门禁补充

- 正式回填不要求在本地开发环境先执行完成。
- 本地环境只要求：
  - `backfill` 脚本可编译
  - `dry-run` 可跑通
  - `verify` 脚本可抽样校验
- 正式回填建议放到准线上或线上窗口执行，原因：
  - 本地数据库连接与 I/O 性能不代表真实环境
  - `content_submissions.payload` 与历史 DJ contributor 扫描在本地耗时显著更高
  - 正式回填后更适合同环境直接做抽样校验与问题回滚

## 12.2 数据库回滚说明

如果贡献模块 cutover 后需要回滚，建议按以下顺序执行：

1. 先停用正式回填脚本与相关发布窗口操作，避免继续写入新回填数据。
2. 仅回滚“贡献模块读路径”时：
   - 可以先在服务端关闭贡献模块读取入口或回退到旧版本应用代码
   - 不必立即删除新表数据
3. 需要回滚“回填写入结果”时：
   - 删除 `contribution_history_entries` 中 `source = backfill` 或 `metadata.backfillModule = contribution_module_phase8` 的历史数据
   - 重建 `event_contributors` / `dj_contributors` 到回滚目标状态
4. 需要回滚 schema 时：
   - 必须确认线上代码已不再依赖 `event_contributors`、扩展后的 `dj_contributors` 字段、`contribution_history_entries`
   - 再执行单独 migration 回滚或人工 DDL

注意：

- 数据回滚与代码回滚应拆开执行，不建议直接把 schema 回滚作为第一步。
- `dj_contributors` 已被新逻辑复用，回滚前必须先确认是否仍有旧 DJ 编辑权限逻辑依赖该表。

## 12.3 Migration 风险说明

- `event_contributors` 是新增表，风险主要在 migration deploy 顺序而不是历史兼容。
- `dj_contributors` 是扩字段升级，风险主要在：
  - 旧代码若假设表内只有 `dj_id / user_id / created_at` 等简化结构，可能出现读写口径不一致。
  - 正式回填前如果新代码已上线但 migration 未完整部署，DJ 贡献写链路会直接失败。
- `contribution_history_entries` 是新增追加式流水表，风险主要在：
  - 如果写链路先上线但表未创建，event / DJ 审核生效路径会因写 history 失败而中断。
  - 如果后续发现 `no-op` 判定不严谨，会放大历史脏数据，需要依赖 source / metadata 做定向清理。
- 因为贡献模块读写已经接入 event / DJ 生效链路，正式发布顺序必须是：
  1. 先 deploy migration
  2. 再 deploy 服务端代码
  3. 最后在窗口内执行正式 backfill
- 回填窗口内不建议并发运行其他同表 repair / backfill，避免：
  - `contribution_count` 统计被重复放大
  - `last_contributed_at` 被不同批任务交错刷新
  - verify 抽样时难以判断问题归因

---

## 13. 建议的实现顺序

1. 先完成数据模型和写链路。
2. 再完成对象维度读取接口。
3. 接着完成 event / DJ 详情页 UI。
4. 然后实现 contribution history ledger 读取接口。
5. 最后再接个人主页入口和贡献中心页面。

这样能保证：

- 即使贡献中心延后，贡献者列表能力也可独立上线。
- 用户维度历史页不会反向绑死对象详情功能。

---

## 14. 变更日志

### 2026-06-04

- [x] 建立独立 `贡献模块` tracker。
- [x] 明确模块拆分为 `Contributor Registry` 与 `Contribution History Ledger` 两个子域。
- [x] 将“个人主页贡献中心快捷入口”和“贡献历史页”纳入模块正式范围。
- [x] 将“web overlay 详情页独立 `贡献` tab”纳入模块正式范围。
- [x] 后端完成 `GET /v1/me/contribution-center/summary` 与 `GET /v1/me/contributions`。
- [x] 服务端补齐 event / DJ submission 生效写链路的统一 `no-op` 判定，避免未生效重复提交写入 contributor relation / contribution history。
- [x] iOS 个人主页已接入 `贡献中心` 快捷入口与历史贡献页首版。
- [x] iOS event / DJ 详情页已接入贡献者摘要与独立贡献者列表页首版。
- [x] Phase 8 回填脚本补齐 `dry-run` 范围控制、分页读取、重试与统计日志。
- [x] 新增 `contribution-module:verify` 抽样校验脚本。
- [x] 确认正式回填后置到准线上 / 线上环境执行，不阻塞当前开发。
- [x] 服务端补齐 contribution record 写入成功 / 失败日志。

### 2026-06-05

- [x] iOS 详情页 contributor summary 点击埋点接入 event / DJ 两侧入口。
- [x] iOS 贡献者列表 profile 点击埋点接入。
- [x] iOS `贡献中心` 曝光、筛选、入口点击埋点接入。
- [x] web `贡献` tab exposure 与 contributor profile 点击埋点接入。
- [x] 增补 `Migration 风险说明`，明确 migration -> code -> backfill 发布顺序。
- [x] 新增 `contribution-module:regression` 后端回归脚本，用于覆盖贡献写入、列表排序、历史分页与筛选。
- [x] 发布清单补齐 iOS / web / backend smoke 与本地门禁说明。
