# Web Event Upload / Edit Parity Audit

日期：2026-06-02

范围：
- `web/src/features/admin-content/event-studio/*`
- `web/src/components/admin/EventStudioForm.tsx`
- `web/src/components/admin/EventStudioAIImportDock.tsx`
- `web/src/app/admin/content/events/new/page.tsx`
- `web/src/app/admin/content/events/[id]/edit/page.tsx`
- `server/src/routes/bff.web.routes.ts`
- `server/src/services/content-submission-event.service.ts`
- `server/src/services/event-admin-contract-guardrail.service.ts`
- `contracts/openapi/event-admin.v1.yaml`
- `mobile/ios/RaverMVP/RaverMVP/Features/Discover/Events/UploadFlow/*`
- `mobile/ios/RaverMVP/RaverMVP/Core/EventAdminContractBridge.swift`

---

## 1. 结论先说

当前 web 端和 iOS 端在 **Event upload / edit 的底层 contract、核心 payload 结构、timezone / eventDay / cross-midnight 语义** 上，已经比之前统一得多。

现在真正没有完全对齐的，不再是“接口字段不一样”这一层，而是下面这些更上层的能力：

1. `workflow shell` 没对齐
2. 本地草稿持久化 / 恢复 / 放弃 / 过期治理没对齐
3. 分步校验、错误映射、提交失败恢复没对齐
4. AI 导入的编辑闭环和异常兜底没对齐
5. revision / stale edit / 冲突治理没对齐
6. 测试矩阵和验收标准没对齐

所以，后续最优方案不是再去改 iOS，也不是继续改 contract，而是：

**冻结 iOS 当前稳定链路，把 web 端收敛到“复用同一 contract + 补齐一层 web-only orchestration shell”的架构。**

这也是最商用、最稳、最不容易再次误伤 iOS 的做法。

---

## 1.1 最高优先级事项

在所有后续 web 改造里，以下 3 项必须作为最高优先级先完成。

目标不是“重新设计 web”，而是先确保 web 和 iOS 一样，能稳定完成一整次上传和修改闭环。

原则只有一条：

**全部向 iOS 当前已跑通的语义对齐，但不改 iOS 现有流程。**

### Priority 0.1 最终提交反馈必须与 iOS 语义对齐

当前 web 虽然已经接入真实 `POST /v1/events` 和 `PATCH /v1/events/:id`，但“点击提交后用户看到的成功”还不够精确。

必须对齐 iOS 当前语义：

1. `created`
   - 表示已经直接入库成功
   - 用户可以把它理解成“活动真的已经创建/更新完成”

2. `submittedForReview` / `submission accepted`
   - 表示只是任务已提交，正在处理中
   - 不能伪装成“活动已经完成更新”

web 必须补齐：

1. 明确区分两类成功态
2. 成功文案、跳转和后续动作与 iOS 语义一致
3. 不允许把“任务已提交处理中”渲染成“活动已成功保存”

这是最高优先级，因为它决定了后台用户是否真的知道这次提交有没有最终完成。

### Priority 0.2 图片上传归属必须与 iOS 对齐

当前 iOS 的图片上传语义更完整：

1. create 模式下按 `draftId` 上传
2. edit 模式下按 `eventId` 上传
3. 图片 ownership 会区分 create draft、edit draft、persisted event、pending local

web 现在还没完全做到这一点。

最高优先级要求：

1. web create 保持 `draftId` 上传
2. web edit 必须改成和 iOS 一样按 `eventId` 上传
3. web 图片归属语义要向 iOS 看齐，至少要能区分：
   - create draft uploaded
   - edit uploaded
   - persisted event
   - pending local / waiting upload

这样才能保证：

1. 上传后的媒体 owner 正确
2. 后续删除语义正确
3. 提交后 event 资源与 draft 资源不会混淆

### Priority 0.3 图片删除与 OSS 清理闭环必须与 iOS 对齐

这里不能只做到“前端看起来删除了”，而必须做到真正的资源闭环。

对齐 iOS 的目标语义：

1. 删除 draft 上传图时，能删除对应 draft 归属的远端资源
2. 编辑态删除已存在 event 图时，最终能把该 event 已不再引用的 OSS 资源标记删除并进入清理流程
3. 提交更新后，如果旧图已不再被 event 引用，必须进入 `markDeleted / purge` 闭环

web 当前这一块还不算完全闭环，所以必须最高优先级补齐：

1. 前端删除行为要区分 draft image 和 persisted event image
2. 提交 apply / submission apply 后要做旧图与新图 diff
3. 被移除的旧 `coverImageUrl` / `lineupImageUrl` / `imageAssets` 必须进入 `mediaAssetService.markDeletedByUrl(...)`
4. 最终依赖现有 purge worker 清理 OSS 对象

这一步完成前，不能说 web 已经和 iOS 一样具备可靠的 event media lifecycle。

### 这 3 项的执行约束

1. 不修改 iOS 当前 upload / edit 流程
2. 不改变 iOS 当前 contract 语义
3. 不改变 iOS 当前 timezone / eventDay / cross-midnight 逻辑
4. 只允许 web、web BFF、event submission apply 链路补齐对齐能力

### 当前执行清单

- [x] 把 web create / edit 成功态文案与跳转语义对齐到 iOS 的 `created` / `submittedForReview`
- [x] 把 web event studio 图片状态从粗粒度 `draft-upload/persisted` 扩展为与 iOS 语义兼容的 owner 分类
- [x] 把 web edit 模式图片上传从统一 `draftId` 改为和 iOS 一样按 `eventId` 上传
- [x] 把 web 删除图片逻辑区分为 draft uploaded / edit uploaded / persisted event 三类
- [x] 为 event submission 增加 draft media -> content submission 的归属迁移
- [x] 为 event approval/direct apply 增加 content submission media -> event 的归属迁移
- [x] 为 event update/apply 增加旧图与新图 diff，清理不再引用的 `coverImageUrl` / `lineupImageUrl` / `imageAssets`
- [x] 为这次最高优先级改造补最小验证，并回写文档完成状态

### 当前验证结果（2026-06-02）

- [x] `server`: `pnpm build`
- [x] `web`: `pnpm build`
- [x] web parity test fixture 已同步新的 `EventStudioImageOrigin` 语义
- [x] direct apply / pending submission / update apply 三条 event media 归属链路已补齐

---

## 2. 这次审计的核心判断

### 2.1 已经对齐的部分

以下能力已经具备较强的一致性，原则上不应该再大改：

1. shared contract 已经对齐
   - web 使用 `contracts/generated/web/event-admin`
   - iOS 使用生成后的 Swift contract，并通过 `EventAdminContractBridge.swift` 转桥接模型

2. create / update 主接口已对齐
   - `POST /v1/events`
   - `PATCH /v1/events/:id`
   - `POST /v1/events/lineup-timetable-alignment/preview`

3. schedule / weeks / eventDays 结构已基本对齐
   - web `buildEventStudioScheduleStructure`
   - iOS `EventUploadMappers` / `EventAdminContractBridge`

4. eventDayId / overallDayIndex / localDate / timezone 语义已基本对齐
   - web 已在 mapper / hydrate 中处理 eventDay 归属和跨天 offset
   - iOS 已明确采用 event timezone 解释 wall-clock 时间

5. lineup / timetable 主数据模型已基本对齐
   - web `lineupArtists` / `lineupSlots`
   - iOS `lineup artists` / `lineup slots`

6. web 端已有基础对齐测试
   - `web/tests/contracts/event-mapper-parity.ts`
   - 已覆盖 schedule identifier、eventDay id、cross-midnight slot、clear semantics 等关键点

### 2.2 现在的主要差异不是 contract，而是产品层和治理层

当前 web Event Studio 更像是：

- “一套已经能提交真实 payload 的强表单”

而 iOS V2 更像是：

- “一套完整的上传/编辑工作流系统”

两者的差距集中在：

- 生命周期管理
- 用户恢复能力
- 失败恢复能力
- AI 导入治理
- 冲突治理
- 可运维性

---

## 3. 当前 web 和 iOS 的对齐情况矩阵

### 3.1 已对齐

1. create / edit 共用同一套 event admin contract
2. event detail hydrate 回填主干数据
3. structured eventDays / weeks / scheduleMode
4. timetable slot 的 eventDay / localDate / offset 语义
5. lineupSyncMode
6. lineup-timetable alignment preview 接口
7. image zones 基础模型
8. update payload 的 clear semantics

### 3.2 部分对齐

1. 分步编辑
   - web 有 step form
   - iOS 有更完整的 step workflow

2. 校验
   - web 有 `validateEventStudioDraft`
   - iOS 有更细粒度、带上下文的 `EventUploadValidation`

3. 提交错误处理
   - web 有 `EventStudioApiError`
   - iOS 还有一层 `EventSubmissionErrorMapper`

4. AI 导入
   - web 已有 `EventStudioAIImportDock`
   - 但结果治理、异常修复、未解析项处理、应用策略还不够成熟

5. 编辑态 hydration
   - 主干已可用
   - 但页面壳、恢复、冲突提示、修订基线等治理能力不完整

### 3.3 未对齐

1. 本地草稿存储与恢复
2. autosave
3. 新建草稿“继续上次 / 重新开始”
4. 编辑草稿按 event id 独立保存
5. 草稿过期清理
6. 离开确认 / unsaved changes 防护
7. 提交失败后草稿与媒体恢复策略
8. stale revision / compare / reload 流程
9. 完整 AI 导入异常兜底
10. 端到端 parity test matrix

### 3.4 应保持分离，不要强行对齐

以下不建议为了“形式统一”而强行和 iOS 共用实现：

1. 具体 UI 组件实现
2. 本地草稿物理存储方式
3. 页面交互细节
4. web 专属的 beforeunload / multi-tab / browser storage 策略

应该统一的是：

- domain contract
- domain invariant
- validation vocabulary
- submission semantics
- AI result application semantics

---

## 4. 逐项审计：web 端还没对齐的地方

## 4.1 草稿生命周期没对齐

### 现状

iOS V2 已明确具备：

1. 本地草稿保存
2. 新建只保留每用户 1 份草稿
3. 编辑按 `event id + user id` 独立草稿
4. 继续草稿 / 重新开始提示
5. 14 天过期清理
6. 提交成功清理草稿
7. 提交失败保留草稿与本地媒体

web 当前只看到：

1. `EventStudioForm.tsx` 记住了当前 step
2. 没看到完整 draft persistence store
3. 没看到 restore banner / discard draft / expiry / autosave 体系

### 风险

1. web 端填写长表单时中断即丢
2. AI 导入结果和图片处理容易在刷新后丢失
3. 编辑态缺少可恢复性，运营体验不稳定
4. 无法达到商用后台应有的“可恢复、可继续、可放弃、可追溯”

### 建议

新增 web-only：

- `EventStudioDraftStore`
- `EventStudioDraftSession`
- `EventStudioUnsavedChangesGuard`

建议能力：

1. create 草稿 key
   - `eventStudio.create.<userId>`

2. edit 草稿 key
   - `eventStudio.edit.<eventId>.<userId>`

3. autosave
   - 用户修改后 debounce 500ms 到 1000ms
   - 页面隐藏、路由切换前再强制 flush 一次

4. 恢复策略
   - create 进入时弹“继续上次草稿 / 重新开始”
   - edit 进入时弹“恢复本地编辑草稿 / 以服务器最新版为准”

5. 过期策略
   - 默认 14 天
   - 过期后自动清理 storage 记录与临时上传引用

6. 成功清理
   - submit success 后删除当前 draft session

7. 失败保留
   - submit failed 后保留草稿，并展示恢复提示

---

## 4.2 web 端缺少完整 workflow shell

### 现状

当前 web create / edit 页面：

- `new/page.tsx` 和 `edit/page.tsx` 主要是 `useState + EventStudioForm`
- 提交成功后显示 notice
- 页面本身没有承担草稿会话、恢复、版本基线、导航保护、状态回显等 orchestration 责任

iOS V2 则有明显的：

- Draft
- ViewModel
- Validation
- DraftStore
- Submission result state
- Exit/discard handling

### 风险

1. 页面状态和业务状态耦合过重
2. 后续补 autosave / conflict / AI 恢复时会继续往大组件里堆逻辑
3. form 组件可维护性会越来越差

### 建议

新增一层 web-only orchestration：

1. `EventStudioController` 或 `useEventStudioSession`
2. 由它统一管理：
   - 初始加载
   - hydrate
   - 草稿恢复
   - autosave
   - submit
   - revision 基线
   - conflict notice
   - beforeunload
   - AI import apply pipeline

3. `EventStudioForm` 尽量降为：
   - 纯编辑 UI
   - 纯 step navigation UI
   - 少量局部交互状态

这是最成熟的做法，因为它能让 web 的“流程治理”独立演进，而不再挤压 iOS 或 contract 层。

---

## 4.3 校验层还不够对齐

### 现状

web `validation.ts` 当前是：

1. 平铺式 errors object
2. 能挡住主要非法输入
3. 但缺少 slot 级、stage 级、day 级上下文

iOS `EventUploadValidation.swift` 当前具备：

1. 分 step 校验
2. 具体到 stage / day / slot 的上下文错误
3. 更清晰的用户可读提示
4. 更细的 submission error normalization

### 风险

1. web 用户看到的错误颗粒度不够
2. 容易出现“知道失败了，但不知道哪个 slot 错了”
3. 当 payload 复杂时，运营修复成本高

### 建议

把 web 校验拆成两层：

1. client preflight validation
   - step-level
   - contextual
   - slot-level

2. server submission error mapping
   - 对 `EVENT_SUBMISSION_INVALID_PAYLOAD` 等 code 做统一 humanize

建议新增：

- `event-studio/error-mapper.ts`
- `event-studio/validation-context.ts`

并统一错误 vocab：

1. schedule invalid
2. eventDay invalid
3. timetable slot invalid
4. timezone unresolved
5. lineup/timetable mismatch
6. stale revision

---

## 4.4 提交错误映射和恢复策略没对齐

### 现状

web 当前只对一个冲突场景做了专门处理：

- `ACTIVE_EVENT_EDIT_SUBMISSION_EXISTS`

其他错误基本还是：

- `error.message`

iOS 已经有一层专门的 submission error mapper，会把后端 invariant 失败转成人类可读的修复提示。

### 风险

1. 运营在 web 端看到后端原始错误，理解成本高
2. 同一类错误在 iOS 和 web 的提示口径不一致
3. 日后排查时难以归类

### 建议

web 需要补齐：

1. error code -> user facing message mapping
2. error code -> focus step mapping
3. error code -> suggested recovery action

建议规则：

1. 先用 `code`
2. 再看 `details`
3. 最后 fallback 到 message

同时把错误展示拆成：

1. 全局错误 banner
2. step 级提示
3. field / slot 级提示

---

## 4.5 revision / stale edit / 冲突治理未完成

### 现状

当前 web Event Studio：

1. 已有 `conflictNotice`
2. 已处理“当前存在活跃编辑 submission”这个冲突
3. 但没有形成完整的 revision baseline / stale data / compare and reload 流程

现有 master plan 里也已经写到：

- “继续补 lineup-only slots 与更完整 revision conflict 语义”

### 风险

1. 两个后台用户同时编辑时，后提交者缺少足够清晰的提示
2. 本地草稿和服务器新版可能 silently drift
3. 改造后如果再增加 autosave，这个风险会更高

### 建议

web edit session 需要引入：

1. `baseRevision`
2. `loadedAt`
3. `serverSnapshotHash` 或等价字段

建议流程：

1. 打开 edit 页时记录基线 revision
2. submit 前若发现服务器 revision 已变：
   - 给出 stale warning
   - 可选 compare
   - 可选 reload server version
   - 可选保留本地 draft 做手工 merge

注意：

**这层必须是 web-only orchestration，不要回头再改 iOS 稳定链路。**

---

## 4.6 AI 导入已可用，但离商用成熟态还有距离

### 现状

web `EventStudioAIImportDock.tsx` 已经做了很多事：

1. poster / lineup / timetable 三类导入
2. job 创建、轮询、取消
3. warnings / unparsedTexts 展示
4. lineup / timetable 结果可编辑
5. DJ 搜索、绑定、清除绑定
6. apply result 写回 draft

这说明底层方向是对的。

但它还没有完全达到 iOS 那种“安全导入草稿”的成熟度。

### 还没对齐的点

1. 结果恢复
   - panel 关闭或刷新后结果是否可恢复，不完整

2. parse repair
   - 遇到模型返回半 JSON、嵌套 JSON、raw_json wrapper、trailing commas 等情况，web 缺少明确 repair pipeline

3. unresolved items 治理
   - warnings / unparsedTexts 现在主要还是文本展示
   - 还没有形成“必须先处理这些 unresolved items 才能 apply”的分级策略

4. AI 结果应用策略
   - 目前 apply 更偏向 append / direct merge
   - 缺少“replace / merge / append / preview diff”明确模式

5. timezone / eventDay 解释提示
   - timetable 导入涉及 eventDay 归属、当地 timezone、跨午夜逻辑
   - web 还缺少够强的解释和修正向导

6. idempotency
   - 同一个 job result 重复 apply 的控制还不够显式

### 建议

新增一层 AI import hardening：

1. `AIImportResultNormalizer`
   - 修复 JSON wrapper
   - 修复 raw_json/stringified payload
   - 兼容 `warnings` / `unparsed_texts` / `unparsedTexts`

2. `AIImportApplyPolicy`
   - `append`
   - `replace-target-day`
   - `replace-target-stage`
   - `merge-dedup`

3. `AIImportResolutionChecklist`
   - 未绑定 DJ
   - 未匹配 eventDay
   - 缺失时间
   - 未识别文本
   - stageName 不明确

4. apply preview
   - 应用前先展示“将新增/覆盖哪些 slot”

5. session persistence
   - 导入 job result 暂存在当前 draft session 内

---

## 4.7 提交链路与页面壳的耦合仍偏重

### 现状

当前 `EventStudioForm.tsx` 同时承担：

1. 大量表单编辑
2. step 状态
3. validation
4. submit
5. conflict notice
6. alignment preview
7. timetable selection UI
8. AI import dock 挂载点

### 风险

1. 组件继续膨胀
2. 后续改 web timetable 体验时容易连带影响 create / edit 提交逻辑
3. 很难做严格回归

### 建议

按成熟后台标准拆层：

1. `session/controller`
2. `draft store`
3. `validation`
4. `submit service`
5. `ai import service`
6. `presentational form sections`

这能保证 web 后续对齐 iOS 逻辑时，是“补一层治理”，而不是“继续在巨型组件里打补丁”。

---

## 4.8 测试矩阵还不够

### 现状

web 已有：

1. contract mapper parity test

但还缺少：

1. hydration parity tests
2. draft persistence tests
3. AI import apply tests
4. cross-midnight / logical day tests
5. stale revision tests
6. create/edit e2e tests

### 建议

至少补这几层：

1. unit
   - mapper
   - hydrate
   - validation
   - error mapping
   - AI result normalizer

2. integration
   - create draft restore
   - edit draft restore
   - submit fail keep draft
   - submit success clear draft
   - stale revision warning

3. e2e
   - create event
   - edit event
   - AI timetable import -> apply -> submit
   - multi-week + cross-midnight

---

## 5. 为什么之前引入 OpenAPI 是对的，但还不够

之前为了让 web 和 iOS 的 event upload / edit 走同一套模型与提交流程，引入 OpenAPI 这一步本身是正确的。

它解决的是：

1. 双端 payload 结构统一
2. shared field semantics 统一
3. mapper 输出口径统一
4. BFF / server invariant 有单一契约来源

但 OpenAPI 不能自动解决：

1. 本地草稿治理
2. 浏览器端恢复策略
3. 交互式错误修复流程
4. AI 导入闭环
5. stale revision 治理
6. 分步工作流体验

所以：

**OpenAPI 统一的是 contract layer，不是 workflow layer。**

web 现在缺的，恰恰就是 workflow layer。

---

## 6. 最优改造原则：在不影响 iOS 的前提下怎么做

## 6.1 总原则

1. iOS 当前链路冻结，不再为了 web 去改 iOS
2. contract 继续共用，但 workflow 各端独立实现
3. web 新增治理层，不去反向侵入 contract / BFF 核心语义
4. 先补 shell，再补局部 UI，不要反过来
5. 先补恢复与冲突治理，再追求更炫的 AI 体验

## 6.2 技术原则

1. Shared
   - OpenAPI contract
   - domain invariant
   - payload semantics
   - error code vocabulary
   - mapper parity tests

2. Web-only
   - localStorage / IndexedDB draft store
   - beforeunload protection
   - multi-tab conflict handling
   - browser-specific AI import session persistence
   - stale revision UX

3. iOS-only
   - sandbox media draft storage
   - native sheet / picker / background restore 行为

## 6.3 组织原则

1. 把 iOS 当成当前 event upload/edit 语义的 source of truth
2. web 跟语义，不跟具体 UI
3. 任何 server / contract 修改都必须满足：
   - 不破坏现有 iOS 提交链路
   - 不改变已确认的 timezone / eventDay / cross-midnight 语义

---

## 7. 推荐落地方案

## Phase 0：冻结稳定边界

目标：

- 不再为了 web 对齐去动 iOS 当前已跑通链路

动作：

1. 把 iOS 当前 upload/edit 行为语义整理成 source-of-truth checklist
2. 约束 server / contract 的变更必须通过 parity review
3. 明确 web 改造只允许新增 web session / draft / conflict / error mapping 层

交付物：

1. event admin invariants checklist
2. web-only orchestration ADR

## Phase 0.5：先完成最高优先级闭环

这是正式大规模补 shell 之前必须先落的 3 项。

### P0-A 提交成功语义对齐

目标：

- 让 web 的“提交成功”含义和 iOS 完全一致

动作：

1. 统一梳理 `created` 与 `submitted` 的 UI 呈现
2. create / edit 页面分别区分：
   - 已直接入库成功
   - 仅任务已提交处理中
3. 成功后的 notice / resultLink / follow-up CTA 全部与 iOS 语义一致

验收：

1. 后台用户能明确知道这次点击提交到底是“已生效”还是“已排队”

### P0-B 图片上传 owner 语义对齐

目标：

- 让 web 的 event media upload 模式和 iOS 一样

动作：

1. web create 上传继续走 `draftId`
2. web edit 上传改为走 `eventId`
3. 补齐前端图片状态上的 ownership 区分
4. 核对后端 `ownerType / ownerId / objectKey` 是否符合 event / event-draft 两套语义

验收：

1. 新建活动图片进入 draft 归属
2. 编辑活动新图进入 event 归属
3. 后续删除时不会混删或漏删

### P0-C 图片删除与 OSS 清理闭环

目标：

- 让 web 具备和 iOS 一样可靠的 media cleanup 闭环

动作：

1. 删除 draft 图时走 draft 删除链路
2. 删除 persisted event 图时走 event 删除语义
3. 在 event update / submission apply 完成后，做旧图与新图 diff
4. 对不再引用的旧图执行：
   - `markDeletedByUrl`
   - 进入 purge worker

验收：

1. draft 图删除后远端资源会清理
2. event 图在提交更新后若被移除，会进入删除闭环
3. 不会出现前端删了但 OSS 还长期残留的情况

## Phase 1：补 web Draft Session

目标：

- 让 web 端达到可恢复、可继续、可放弃

动作：

1. 新增 `EventStudioDraftStore`
2. 新增 `useEventStudioSession`
3. create / edit 区分 draft key
4. autosave
5. restore banner
6. discard draft
7. expiry cleanup
8. submit success cleanup
9. submit failed retain draft

验收：

1. 刷新页面不丢 draft
2. create 可继续上次草稿
3. edit 可恢复未提交修改
4. 成功提交后自动清理

## Phase 2：补 web Validation + Error Mapping

目标：

- 让 web 用户能明确知道哪里错、怎么改

动作：

1. 拆 step-level validation
2. 增加 timetable contextual validation
3. 新增 submission error mapper
4. 错误自动聚焦到对应 step
5. slot 级错误高亮

验收：

1. `EVENT_SUBMISSION_INVALID_PAYLOAD` 不再直接裸露后端语句
2. timetable 错误能定位到具体 day/stage/slot

## Phase 3：补 revision / stale edit 治理

目标：

- 避免后台多用户编辑时 silent overwrite

动作：

1. edit session 引入 `baseRevision`
2. submit 前检查 stale
3. stale warning + reload flow
4. 保留本地 draft 以便手工 merge

验收：

1. 双人编辑时能稳定识别冲突
2. 不会让后提交者无感覆盖

## Phase 4：补 AI 导入治理层

目标：

- 让 web 端 AI 导入达到可商用的稳定性

动作：

1. JSON/result normalizer
2. unresolved item checklist
3. apply policy 选择
4. apply preview
5. result persistence
6. duplicate apply 防重

验收：

1. 常见 malformed JSON / wrapped JSON 可自动修复
2. 用户能看清哪些 slot 会新增、覆盖、跳过

## Phase 5：补完整回归测试

目标：

- 把 web 对齐改造从“人工记忆”变成“自动守护”

动作：

1. hydration parity tests
2. draft lifecycle tests
3. AI import apply tests
4. stale revision tests
5. cross-midnight logical day tests
6. create/edit e2e smoke tests

验收：

1. 后续再改 web timetable / import 时，不会再次误伤 iOS 语义

---

## 8. 推荐的目录与职责拆分

建议新增或收敛为：

```text
web/src/features/admin-content/event-studio/
  session.ts
  draft-store.ts
  validation.ts
  error-mapper.ts
  ai-import-normalizer.ts
  ai-import-apply-policy.ts
  mapper.ts
  draft.ts
  api.ts
  types.ts
```

职责建议：

1. `draft.ts`
   - draft shape
   - hydrate
   - schedule structure sync

2. `draft-store.ts`
   - local persistence
   - restore / cleanup / expiry

3. `session.ts`
   - page lifecycle
   - loading / autosave / submit / conflict / unsaved guard

4. `validation.ts`
   - preflight validation

5. `error-mapper.ts`
   - API errors -> user-facing messages

6. `ai-import-normalizer.ts`
   - job result normalization / repair

7. `ai-import-apply-policy.ts`
   - apply preview / merge semantics

---

## 9. 这套方案为什么最商用成熟

因为它符合成熟后台系统的几个关键标准：

1. 不改稳定核心，只在边上补治理层
2. 把 contract 统一和 workflow 治理分开
3. 把浏览器特有风险单独处理
4. 优先补恢复、冲突、失败治理，而不是只补 UI
5. 让后续回归变成自动化，而不是继续靠人工记忆

简单说：

**最成熟的做法不是“再把 web 改得更像 iOS 页面”，而是“让 web 和 iOS 共享同一套业务语义，同时各自拥有适合自己平台的 workflow shell”。**

---

## 10. 建议的执行顺序

建议严格按下面顺序做：

1. 先做 draft session
2. 再做 validation / error mapping
3. 再做 stale revision
4. 再做 AI import hardening
5. 最后补 e2e 和 regression

不要反过来先继续改 EventStudioForm 的局部 UI。

因为如果 session / restore / conflict 这些基础治理没先补上，后面越改 UI，返工越大。

---

## 11. 最后一句判断

如果目标是：

- web 和 iOS 共用同一套 event admin 业务语义
- 但不影响 iOS 当前已经稳定可跑的 upload / edit 链路

那么最优路径就是：

**把 iOS 现在的语义当基线，冻结 contract 主干，web 新增一层 session-driven orchestration shell，逐步补齐草稿、校验、冲突、AI 导入和测试矩阵。**

这条路风险最低，也最容易长期商用。
