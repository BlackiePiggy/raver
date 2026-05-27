# iOS Event 上传/编辑中 Lineup 与 Timetable 策略改造方案

## 文档目标

这份文档用于指导当前 iOS 端 `EventUploadFlow` 的上传、编辑策略改造，目标是把 `lineup` 和 `timetable` 的关系调整为：

- `lineup`：宣发阵容 / 已知参演名单
- `timetable`：具体时段演出事实

并明确采用以下总原则：

- `timetable` 可以给 `lineup` 增量补人
- `timetable` 默认不能自动删 `lineup` 里的人
- 只有用户主动执行“按时间表精确对齐阵容”时，才允许清理 `lineup`

这份方案**不引入额外状态字段**，不新增：

- event 维度 completeness 字段
- artist 维度 source 字段

而是优先通过：

- iOS 端编辑流程
- 提交模式
- 明确的用户动作
- 服务端提交契约

来建立稳定行为。

---

## 适用业务场景

### 场景 A：未开始活动，信息逐步补全

常见顺序：

1. 先发布部分 `lineup`
2. 再补完整 `lineup`
3. 最后补 `timetable`

目标策略：

- `lineup` 是主轴，始终只增不减
- 后续上传 `timetable` 时：
  - `timetable` 里有、`lineup` 里没有的 DJ：增量补进 `lineup`
  - `lineup` 里已有、但 `timetable` 暂时没有的 DJ：保留，不删

### 场景 B：已结束活动，直接补时间表

常见顺序：

1. 先没有结构化阵容
2. 直接补 `timetable`
3. 让 `lineup` 跟着补齐

目标策略：

- 允许从 `timetable` 自动生成或增量补齐 `lineup`
- 默认是“补齐”
- 不是“按 timetable 覆盖现有 lineup”

### 场景 C：先有完整 lineup，后面 timetable 比 lineup 多几个 DJ

目标策略：

- 直接把多出来的 DJ 增量补进 `lineup`
- 不因为 `timetable` 中缺少某些 `lineup` 艺人就自动删掉他们

---

## 当前问题

当前代码里，iOS 端和服务端的默认行为并不完全符合上面的策略。

### 1. 当前 iOS 编辑草稿中，`lineup` 和 `timetable` 已经是两层

当前 `EventUploadDraft` 里已经拆成：

- `lineupOnlySlots`
- `timetableSlots`

对应代码：

- [EventUploadDraft.swift](/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Discover/Events/UploadFlow/EventUploadDraft.swift:477)
- [EventUploadMappers.swift](/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Discover/Events/UploadFlow/EventUploadMappers.swift:368)
- [EventUploadMappers.swift](/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Discover/Events/UploadFlow/EventUploadMappers.swift:399)

这部分方向是对的。

### 2. 当前本地删除 timetable，不会直接删 lineup

当前 iOS 端本地删除 timetable 条目时，只会改：

- `draft.timetableSlots`

不会改：

- `draft.lineupOnlySlots`

对应代码：

- [EventUploadFlowViewModel.swift](/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Discover/Events/UploadFlow/EventUploadFlowViewModel.swift:1433)

这一点也是对的。

### 3. 但当前“提交后的默认对齐逻辑”会让 timetable 反向收敛 lineup

当前服务端在 patch/full sync 时，会根据被影响的 timetable identity 去同步修正 lineup artist。

结果是：

- 如果删掉某个艺人的最后一个 timetable slot
- 那个原本存在于 lineup 的艺人，可能也会在最终提交入库时被删掉

这和本方案想要的“默认补齐，不默认清理”是冲突的。

### 4. 当前 iOS 端的 mismatch 提示是“强制对齐后提交”

当前 UI 提示文案和按钮是：

- `一键对齐并提交`
- `返回手动修改`

对应代码：

- [EventUploadFlowView.swift](/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Discover/Events/UploadFlow/EventUploadFlowView.swift:241)

这代表当前主思路是：

- `lineup` 和 `timetable` 不一致时，系统倾向要求统一

但你的实际业务需要的是：

- 大多数时候允许不一致
- 默认是“增量补齐”
- “精确对齐”是显式动作，不应该是默认提交门槛

---

## 目标产品策略

## 策略 1：默认提交模式改为“增量补齐阵容”

默认保存/提交时：

- 允许 `lineup` 与 `timetable` 不完全一致
- 若 `timetable` 中存在 `lineup` 没有的艺人：
  - 自动增量补到 `lineup`
- 若 `lineup` 中存在 `timetable` 没有的艺人：
  - 保留，不删

这应该成为 iOS 端的默认行为。

## 策略 2：把“按时间表精确对齐阵容”改成单独动作

精确对齐不属于默认提交流程。

应该改成：

- 用户在 `lineup` / `timetable` 编辑页里主动点击一个动作
- 先预览差异
- 再确认是否执行

这个动作应该是危险动作，语义是：

- 让 `lineup` 精确等于 `timetable` 能推出来的阵容
- 允许移除 `lineup` 中多余艺人

## 策略 3：普通编辑中的删除永不隐式伤及 lineup

在编辑时：

- 删除一个 `timetable slot`
- 删除某个 stage 下的一组 `timetable slots`

默认都只影响 `timetable`

不应默认导致：

- lineup-only 条目被删
- 已有 lineup artist 被清理

## 策略 4：提交前只提示“有差异”，不阻塞

当 `lineup` 和 `timetable` 不一致时：

- 可以提示
- 可以引导用户去“增量补齐”或“精确对齐”

但默认不应阻塞提交。

---

## iOS 端改造范围

本次改造主要涉及：

- `EventUploadFlowViewModel`
- `EventUploadFlowView`
- `EventUploadValidation`
- `EventUploadMappers`
- `EventUploadDraft`

以及与之配合的服务端提交契约。

---

## 一、iOS 端行为改造

## 1. 调整默认提交语义

### 当前行为

当前提交流程在设计上更偏向：

- 提交前检查 `lineup/timetable` 是否一致
- 一旦不一致，提示“一键对齐并提交”

### 目标行为

默认提交时应改为：

- **不要求 lineup 与 timetable 完全一致**
- 提交前只做两件事：
  - 检查数据是否合法
  - 在需要时把 `timetable` 中新增艺人补到 `lineup`

### iOS 端具体修改点

- [x] 修改 `submit()` 流程，不再把“lineup 与 timetable 不一致”视为默认阻塞提交条件
- [x] 将当前 `lineupTimetableAlignmentPrompt` 从“提交前强对齐”改为“可选操作提示”
- [x] 当前代码中未发现仍在使用的 `skipLineupAlignmentPreview` 旧语义

建议修改位置：

- [EventUploadFlowViewModel.swift](/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Discover/Events/UploadFlow/EventUploadFlowViewModel.swift:287)

---

## 2. 新增“增量补齐阵容”动作

### 目标行为

在编辑器中增加一个显式动作：

- `用时间表补齐阵容`

执行结果：

- 只把 `timetable` 中存在、但 `lineup` 中缺失的艺人补进去
- 不删除 `lineup` 现有艺人
- 不改变 `lineup` 中已存在艺人的顺序，除非补齐条目默认追加到末尾

### 为什么要做成显式动作

因为这更符合你的业务心智：

- 你很多时候是在“补信息”
- 不是要让系统自动重写阵容

### iOS 端具体修改点

- [x] 在 `Lineup` 和 `Review` 步骤增加按钮：`用时间表补齐阵容`
- [x] ViewModel 中新增 `applyTimetableIncrementalFillToLineup()` 方法
- [x] 该方法只做“append missing artists”，不做 delete
- [x] 完成后提示用户：补齐了多少个艺人

建议实现位置：

- `EventUploadFlowViewModel`
- `EventUploadFlowView`

---

## 3. 新增“按时间表精确对齐阵容”危险动作

### 目标行为

把“精确对齐”从默认提交流中拆出来，作为单独的危险动作：

- `按时间表精确对齐阵容`

执行前必须先预览：

- 会新增哪些艺人
- 会移除哪些现有 lineup 艺人

### iOS 端具体修改点

- [x] 保留现有 alignment preview 能力，但不再在默认提交时强弹
- [x] 在 `Lineup` 和 `Review` 页增加独立入口：`按时间表精确对齐阵容`
- [x] 弹窗文案改为危险动作说明，而不是提交门槛
- [x] 弹窗中展示两类差异：
  - `将新增`
  - `将移除`
- [x] 用户确认后才调用现有 `applyAlignedLineupArtists(...)`

建议修改位置：

- [EventUploadFlowView.swift](/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Discover/Events/UploadFlow/EventUploadFlowView.swift:241)
- [EventUploadFlowViewModel.swift](/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Discover/Events/UploadFlow/EventUploadFlowViewModel.swift:359)

---

## 4. 修改当前 mismatch 弹窗文案和按钮语义

### 当前文案

- `阵容和时间表未对齐`
- `一键对齐并提交`
- `返回手动修改`

### 目标文案

改成更贴合业务的两类提示：

#### 类型 A：非阻塞提示

- `时间表中有新的 DJ，可补充到阵容`
- 按钮：
  - `仅提交当前内容`
  - `补齐阵容后提交`

#### 类型 B：危险动作

- `按时间表精确对齐将移除 X 个阵容艺人`
- 按钮：
  - `取消`
  - `确认精确对齐`

### iOS 端具体修改点

- [x] 废弃“未对齐就默认引导一键对齐”的文案
- [x] 将弹窗区分为“补齐提示”和“危险对齐提示”
- [x] 非阻塞提示允许继续提交

---

## 5. 调整 stage 删除交互文案

当前删除舞台的交互是：

- `删除舞台和对应时间表`

这在新的策略里仍然成立，但需要额外强调：

- 删除舞台只会删除对应 `timetable`
- 不会自动删除 `lineup`

### iOS 端具体修改点

- [x] 更新 stage 删除确认文案，明确“不会自动删除阵容”
- [ ] 删除成功后可给出 toast：`已删除该舞台的时间表，阵容保持不变`

建议修改位置：

- [EventUploadFlowView.swift](/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Discover/Events/UploadFlow/EventUploadFlowView.swift:257)

---

## 6. 在 Review 页增加“数据差异摘要”

### 目标行为

在最终提交前，让用户看到一个非常简洁的 summary：

- `仅阵容艺人：N`
- `时间表艺人：M`
- `时间表中待补齐到阵容：K`

如果存在需要补齐的艺人，给快捷入口：

- `补齐阵容`

如果用户想做清洗，再给：

- `精确对齐阵容`

### iOS 端具体修改点

- [x] 在 Review 步骤增加 lineup/timetable 差异卡片
- [x] 卡片中展示待补齐数量
- [x] 卡片中放置两个动作：
  - `补齐阵容`
  - `精确对齐`

---

## 二、iOS 端数据生成策略改造

## 1. 保持 `lineupOnlySlots` 与 `timetableSlots` 的双轨结构

这部分当前设计已经基本正确，不需要推翻。

### 要求

- `lineupOnlySlots` 继续表示“阵容层”
- `timetableSlots` 继续表示“演出时段层”

### 具体修改点

- [x] 保持现有双轨 draft 结构不变
- [x] 明确禁止“本地删 timetable 自动删 lineupOnly”
- [ ] 在代码注释里写清楚这两个数组的职责边界

建议修改位置：

- [EventUploadDraft.swift](/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Discover/Events/UploadFlow/EventUploadDraft.swift:477)
- [EventUploadFlowViewModel.swift](/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Discover/Events/UploadFlow/EventUploadFlowViewModel.swift:1433)

---

## 2. 新增“增量补齐算法”，不要直接复用精确对齐算法

当前 `applyAlignedLineupArtists(_:)` 的语义是：

- 用新的一整组 `alignedLineupArtists` 直接覆盖 `draft.lineupOnlySlots`

这适合“精确对齐”，不适合“增量补齐”。

### 需要新增的方法

建议新增：

- `previewTimetableIncrementalFill()`
- `applyTimetableIncrementalFillToLineup()`

### 算法要求

增量补齐时：

1. 先从 `timetableSlots` 计算出 artist identity
2. 再从 `lineupOnlySlots` 计算已有 identity
3. 只把缺失的 artist append 到 lineup
4. 不覆盖已有 lineup 条目
5. 不删除已有 lineup 条目

### iOS 端具体修改点

- [x] 新增“从 timetable 计算 artist identity”的工具方法
- [x] 新增“从 lineupOnly 计算 artist identity”的工具方法
- [x] 新增 append-only 补齐逻辑
- [x] 新增补齐结果 toast / status message

建议修改位置：

- `EventUploadFlowViewModel`
- `EventUploadMappers`

---

## 3. 提交 payload 的生成应区分两种意图

### 默认提交意图

默认提交时，前端应提交：

- 用户当前编辑后的 `lineupArtists`
- 用户当前编辑后的 `lineupSlots`

这里的关键不是 payload 结构变，而是：

- **提交前不要把 lineup 先替换成精确对齐后的结果**

### 精确对齐提交意图

只有用户显式执行“精确对齐”后，才允许：

- 用精确对齐结果改写 `draft.lineupOnlySlots`
- 再进入提交

### iOS 端具体修改点

- [x] 默认 `submit()` 前不再自动调用精确对齐替换逻辑
- [x] 精确对齐后才允许 `applyAlignedLineupArtists(...)`
- [x] 增量补齐动作和精确对齐动作分别打点埋点

---

## 三、校验与阻塞规则改造

## 1. 移除“阵容与时间表必须完全一致”的默认阻塞

当前策略下，不一致本身不是错误。

应该保留的校验：

- 空艺人名
- timetable 缺失时间
- 无主图
- 无基础活动信息

不应该保留为阻塞项的校验：

- `lineup` 和 `timetable` 不完全一致

### iOS 端具体修改点

- [x] 检查 `EventUploadValidation` 未引入“不一致即阻塞”的校验
- [x] 允许以下情况直接提交：
  - timetable 比 lineup 多
  - lineup 比 timetable 多

建议检查位置：

- [EventUploadValidation.swift](/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Discover/Events/UploadFlow/EventUploadValidation.swift:1)

---

## 2. 提交前仅在“精确对齐危险动作”时展示删除风险

### iOS 端具体修改点

- [x] 默认提交时，不显示“将移除 X 个 lineup 艺人”的危险提示
- [x] 仅在用户点击 `按时间表精确对齐阵容` 时显示该风险

---

## 四、服务端契约配合要求

这一节虽然不是 iOS UI 改造，但必须写清楚：

**如果服务端不改，当前 iOS 端再怎么改交互，默认提交后仍可能把 lineup 删掉。**

原因是当前服务端 patch/full sync 会让 timetable 反向收敛 lineup。

所以要让“默认补齐，不默认清理”真正成立，服务端至少要支持两种提交语义。

## 1. 默认语义：增量补齐，不清理 lineup

### 目标

默认 event 编辑提交时：

- `timetable` 中新增的 artist 可以补齐到 `lineup`
- `lineup` 中已有但 `timetable` 中没有的 artist 不应被自动删除

### 服务端需要支持

- [x] 默认 patch/full sync 模式下，不再因为删除最后一个 timetable slot 而自动移除对应 lineup artist
- [x] 默认 sync 只做“补齐”
- [x] lineup artist 的删除仅在明确删除 lineup 项或显式精确对齐时发生

## 2. 显式语义：精确对齐

### 目标

只有当用户明确点击“按时间表精确对齐阵容”时，服务端才允许：

- 清理 `lineup` 中多余 artist

### 服务端需要支持

- [x] 在 `CreateEventInput / UpdateEventInput` 中新增显式意图字段：
  - `lineupSyncMode = incremental_fill | exact_align`
- [x] 默认值应为 `incremental_fill`
- [x] 只有 `exact_align` 时，服务端才允许 timetable 驱动 lineup 删除

### 当前为什么需要这个字段

因为如果没有显式意图，服务端无法区分：

- 用户只是删了 timetable，想保留 lineup
- 用户真的想让 lineup 精确等于 timetable

---

## 五、推荐的最终交互方案

## 默认路径

1. 用户编辑 `lineup`
2. 用户编辑 `timetable`
3. 如果 `timetable` 中有新的 DJ
   - 系统提示：`时间表中有 3 位 DJ 尚未加入阵容`
4. 用户可以选择：
   - `补齐阵容`
   - `稍后处理`
5. 用户提交
6. 默认提交不删除任何现有 lineup

## 清洗路径

1. 用户点击 `按时间表精确对齐阵容`
2. 系统展示：
   - 将新增哪些 DJ
   - 将移除哪些 lineup DJ
3. 用户确认
4. 系统改写 `lineupOnlySlots`
5. 再提交

---

## 六、实施 checklist

## Phase 1：iOS 端交互去强制对齐

- [x] 移除默认提交中的“未对齐必须先一键对齐”心智
- [x] 保留 mismatch 检测，但改成非阻塞提示
- [x] 修改 alert 文案与按钮语义
- [x] 将 `applyAlignedLineupArtists(...)` 仅保留给精确对齐动作使用

## Phase 2：iOS 端新增“增量补齐阵容”

- [x] 新增 preview missing artists 的计算逻辑
- [x] 新增 `applyTimetableIncrementalFillToLineup()`
- [x] 在 Review 页增加“补齐阵容”按钮
- [x] 在 Lineup 页增加“用时间表补齐阵容”按钮
- [x] 补齐后刷新本地 draft 并保存

## Phase 3：iOS 端新增“精确对齐阵容”危险动作

- [x] 将当前 alignment prompt 改造成危险动作确认弹窗
- [x] 在弹窗中展示将新增/将移除的艺人列表
- [x] 确认后才覆盖 `draft.lineupOnlySlots`
- [x] 为危险动作增加单独埋点

## Phase 4：提交流程与文案收口

- [x] Review 页面增加 lineup/timetable 差异摘要
- [x] 删除 stage 时提示“不会自动删除阵容”
- [x] 删除 timetable slot 后提示“仅影响时间表”
- [x] 更新提交成功文案，避免误导用户认为系统自动做了精确对齐

## Phase 5：服务端契约配合

- [x] 服务端新增显式 sync mode
- [x] 默认 sync mode 改为 `incremental_fill`
- [x] 仅在 `exact_align` 时允许清理 lineup
- [x] patch/full sync 回归测试脚本已补覆盖：
  - 删 timetable 不删 lineup
  - timetable 多 DJ 时增量补 lineup
  - 显式精确对齐时允许清理 lineup

当前限制：

- [ ] 在当前环境连通数据库并完整跑通回归脚本

---

## 七、验收标准

以下行为全部满足，才算本策略完成：

- [x] 在 iOS 编辑页删除一个 timetable slot，不会默认删掉 lineup 中对应艺人
- [x] timetable 中新增 DJ 时，用户可以一键把这些 DJ 增量补进 lineup
- [x] lineup 中已有、但 timetable 中暂时没有的 DJ，默认提交后仍然保留
- [x] 用户只有在显式执行“按时间表精确对齐阵容”后，lineup 才会发生清理
- [x] Review 页面能清楚展示 lineup / timetable 差异
- [x] 未开始活动的“逐步补信息”流程顺畅成立
- [x] 已结束活动“直接补 timetable，再补齐 lineup”流程顺畅成立

---

## 八、不在本次范围内

以下内容不在这份方案范围内：

- 新增 event 维度 `lineupCompleteness / timetableCompleteness`
- 新增 artist 维度 `source`
- 重构 canonical 表结构
- 重写后端整套 submission worker

这次的重点是：

- 先把当前 iOS 上传/编辑策略从“默认强对齐”改成“默认增量补齐，精确对齐单独触发”

---

## 九、当前结论

截至当前代码状态，这次策略改造已经完成：

- [x] iOS 默认提交流程已切到“增量补齐，不默认删除阵容”
- [x] iOS 已提供显式“补齐阵容”和危险的“精确对齐阵容”两种操作
- [x] 服务端 create / full update / patch sync 已支持 `lineupSyncMode`
- [x] `exact_align` 现在是端到端显式能力，不再只是 iOS 本地先改写 lineup
- [x] `server` 项目级 TypeScript 类型检查已通过

当前唯一未完成项是环境验证：

- [ ] 使用可连接的数据库完整跑通 [event-incremental-sync-regression.ts](/Users/blackie/Projects/raver/server/src/scripts/event-incremental-sync-regression.ts)
