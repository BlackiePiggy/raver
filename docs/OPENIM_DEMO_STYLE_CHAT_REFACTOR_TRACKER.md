# OpenIM Demo-Style Chat Refactor Tracker

Last Updated: 2026-04-25  
Owner: Codex + Blackie  
Status: In Progress

## Goal

按照方案 C，将 iOS 聊天页相关功能整体改造成与 OpenIM demo 同一路径：

- controller 主持当前会话消息数组；
- 发送、替换、重发、接收都围绕 OpenIM `MessageInfo` / `OIMMessageInfo`；
- UI 渲染层尽量后置做模型转换；
- `OpenIMChatStore` 退回为会话列表、未读、输入状态的 store，不再主持聊天页消息真源；
- 所有当前聊天相关功能都要收口到这条新链路上，不保留“双轨并行的长期状态”。

## Completion Standard

只有在以下条件全部满足后，本方案才算完成：

- 文本、图片、视频发送全部走 demo 风格 optimistic send -> same `clientMsgID` replace。
- 当前会话消息真源完全由 controller 持有，不再依赖 `OpenIMChatStore.messagesByConversationID`。
- 历史分页、实时接收、失败重试、已读、输入中、系统消息都挂到新链路。
- UIKit chat UI 所见行为与 OpenIM demo 对齐，不再依赖 `local-*` placeholder collapse/reconcile。
- `OpenIMChatStore` 中的消息发送/替换/归并职责被移除或废弃。

## Scope

### In Scope

- 单聊/群聊聊天页消息主链路
- 初始加载
- 历史分页
- 文本发送
- 图片发送
- 视频发送
- 失败重试
- 实时新消息接收
- 自己发送消息的回流去重
- 输入状态
- 已读/未读相关聊天页联动
- 消息渲染映射
- controller / data provider / store 分工重构

### Out of Scope

- 会话列表 UI 视觉重做
- 非聊天页业务模块
- 与本次重构无关的 Auto Layout 告警
- OpenIM SDK 本身源码修改

## Current vs Target

### Current

- `OpenIMSession` 先把 OpenIM message 映射成 `ChatMessage`
- `OpenIMChatStore` 持有 `messagesByConversationID`
- `RaverChatDataProvider` 从 store 拿快照/publisher
- `RaverChatController` 消费 store 结果
- 本地发送态使用 `local-*` 作为 placeholder ID
- business conversation ID 与 openIM conversation ID 双轨并存

### Target

- `OpenIMSession` 提供 raw OpenIM message 能力
- `RaverOpenIMChatController` 持有当前会话唯一主数组
- 主数组以 `OIMMessageInfo` 为中心，按 `clientMsgID` append/replace
- `ChatMessage` 仅作为渲染映射结果存在
- `OpenIMChatStore` 不再主持聊天页消息数组
- 不再依赖 `local-*` placeholder 方案

## Source References

- Demo reference:
  - `OUICore/Classes/Core/IMController.sendTextMessage / sendHelper`
  - `OUIIM/Classes/OIMUIChat/Controller/DefaultChatController.sendText / appendMessage / replaceMessage`
- Current repo key files:
  - `/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Core/OpenIMSession.swift`
  - `/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Core/OpenIMChatStore.swift`
  - `/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Messages/UIKitChat/RaverChatController.swift`
  - `/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Messages/UIKitChat/RaverChatDataProvider.swift`

## Phase Tracker

### Phase 0 - Design Freeze And Tracking

Status: `[~] In Progress`

- [x] 确认采用方案 C 作为唯一目标路线
- [x] 建立本追踪文档
- [ ] 冻结旧链路的新增功能开发，避免重构中继续扩散依赖
- [x] 明确切换期间允许的临时兼容层

### Phase 1 - OpenIM Raw Message Pipeline

Status: `[x] Complete`

目标：让 `OpenIMSession` 直接对聊天 controller 暴露原生 OpenIM message 能力。

- [x] 设计 raw message page 类型
- [x] 增加 raw message publisher
- [x] 增加 `createRawTextMessage`
- [x] 增加 `sendPreparedRawMessage`
- [x] 增加 raw image send API
- [x] 增加 raw video send API
- [x] 增加 raw history page fetch API
- [x] 确认原生消息排序字段：`sendTime/createTime/clientMsgID`

### Phase 2 - Controller-Owned Message Source Of Truth

Status: `[x] Done`

目标：让聊天页 controller 成为当前会话消息真源。

- [x] 新建 `RaverOpenIMChatController`
- [x] controller 持有 `rawMessages`
- [x] controller 持有 `renderedMessages`
- [x] 实现 `appendOrReplace(message:)`
- [x] 实现按 `clientMsgID` 去重
- [x] 实现切会话 reset
- [x] 实现当前会话范围过滤
- [x] 移除 controller 对 `OpenIMChatStore.messagesByConversationID` 的依赖

### Phase 3 - Render Mapping And UI Compatibility

Status: `[x] Done`

目标：保留现有 UIKit chat UI，但把渲染映射后置。

- [x] 在已编译聊天 controller 文件内引入 `OpenIMChatItem`
- [x] 在已编译聊天 controller 文件内引入 `OpenIMMessageRenderMapper`
- [x] 支持文本消息映射
- [x] 支持图片消息映射
- [x] 支持视频消息映射
- [x] 支持系统消息映射
- [x] 支持 sending / sent / failed 状态映射
- [x] 确保现有 `DemoAligned*Cell` 不需要大规模重写即可接入

### Phase 4 - Initial Load And History Pagination

Status: `[x] Done`

目标：把历史加载迁移到 controller 自己管理。

- [x] controller 实现 initial load
- [x] controller 实现 older pagination state
- [x] controller 实现 `oldestClientMsgID`
- [x] controller 实现历史 prepend
- [x] controller 实现分页去重
- [x] controller 实现 `hasOlderMessages`
- [x] controller 实现 `isLoadingOlder`
- [x] 验证滚动位置与加载更早消息行为

### Phase 5 - Text / Image / Video Send Path Alignment

Status: `[x] Done`

目标：所有发送路径都改成 demo 风格同 ID replace。

- [x] 文本发送使用 OpenIM `clientMsgID`
- [x] 图片发送使用 OpenIM `clientMsgID`
- [x] 视频发送使用 OpenIM `clientMsgID`
- [x] 发送时先 append sending
- [x] success 时 replace 为 sent
- [x] failure 时 replace 为 failed
- [x] 删除 `local-*` placeholder 创建逻辑
- [x] 删除 placeholder collapse 依赖

### Phase 6 - Realtime Receive / Self Echo / Retry

Status: `[x] Done`

目标：统一处理实时接收、自己消息回流和失败重试。

- [x] controller 绑定 raw realtime message publisher
- [x] 当前会话消息收到后 append or replace
- [x] 自己发送的消息回流按 `clientMsgID` replace
- [x] 实现 resend by same raw message flow
- [x] 验证不会产生重复消息
- [x] 验证 sent 不会回退为 sending

### Phase 7 - Typing / System Messages / Read State

Status: `[x] Done`

目标：把聊天页相关的辅助事件也纳入新链路。

- [x] 输入状态在 controller 中消费并驱动 UI
- [x] 系统消息走新渲染映射
- [x] 已读/已收相关聊天页联动迁移
- [x] 对端消息到来后的 unread / read 状态不因重构退化

### Phase 8 - Store Contraction

Status: `[x] Done`

目标：缩减 `OpenIMChatStore` 到会话域职责。

- [x] 迁出 `messagesByConversationID`
- [x] `messages(for:)` 不再对聊天页外部暴露
- [x] `sendMessage(...)` 不再对聊天页外部暴露
- [x] `sendImageMessage(...)` 不再对聊天页外部暴露
- [x] `sendVideoMessage(...)` 不再对聊天页外部暴露
- [x] `resendFailedMessage(...)` 不再对聊天页外部暴露
- [x] 废弃 `replaceMessage(...)`
- [x] 废弃 store 内部历史分页状态缓存
- [x] 移除 `OpenIMChatMessageDataSource` 继承耦合
- [x] 收窄 `mergeMessage(...)` 为兼容索引/预览适配逻辑
- [x] 废弃 message normalization / reconciliation 逻辑
- [x] 保留 conversations / unreadTotal / inputStatus

### Phase 9 - Coordinator And Screen Wiring

Status: `[x] Done`

目标：把聊天页入口、发送协调器、媒体发送协调器都接到新 controller。

- [x] 文本发送 coordinator 接入新 controller
- [x] 图片发送 coordinator 接入新 controller
- [x] 视频发送 coordinator 接入新 controller
- [x] 失败重试入口接入新 controller
- [x] 会话切换与 screen lifecycle 接入新 controller

### Phase 10 - Cleanup, Removal And Regression Pass

Status: `[~] In Progress`

目标：移除旧链路残留并做完整回归。

- [ ] 删除不再使用的中间兼容逻辑
- [x] 删除 `publisher reconciled` 类兜底日志依赖
- [x] 删除 `messages normalized` 类 placeholder collapse 逻辑
- [x] 修正消息 cell 复用过程中的气泡约束切换冲突
- [x] 全量构建通过
- [x] 双机文本消息回归
- [x] 双机图片消息回归
- [x] 双机视频消息回归
- [x] 重试回归
- [x] 历史分页回归
- [x] 切会话回归

## File-Level Implementation Map

### New Files

- 当前阶段未新增独立 `OpenIMChatItem.swift` / `OpenIMMessageRenderMapper.swift` 文件；
- 出于 `.xcodeproj` 尚未同步纳入新拆分文件的现实约束，这两个类型目前以内联方式落在 [`RaverChatController.swift`](</Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Messages/UIKitChat/RaverChatController.swift:120>) 中编译。

### Existing Files To Modify

- `/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Core/OpenIMSession.swift`
- `/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Core/OpenIMChatStore.swift`
- `/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Messages/UIKitChat/RaverChatController.swift`
- `/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Messages/UIKitChat/RaverChatDataProvider.swift`
- `/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Messages/UIKitChat/Support/DemoAlignedTextSendCoordinator.swift`
- `/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Messages/UIKitChat/DemoAlignedMessageCell.swift`
- `/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Messages/UIKitChat/DemoAlignedMediaMessageCell.swift`

## Risks

### High Risk

- controller 真源切换后，历史分页和当前会话实时回流可能产生顺序回归
- 图片/视频发送链路比文本更复杂，demo 对齐时需要额外处理本地缓存和预览数据
- 旧 UI 当前默认吃 `ChatMessage`，若渲染映射不完整会出现功能缺口

### Medium Risk

- 会话切换时的 lifecycle/reset 不干净，可能导致串消息
- 已读/未读逻辑可能因为 store 职责收缩而出现侧向回归
- 搜索、pending focus、message jump 这类依赖旧 message store 的功能需要补迁移

## Decision Log

### 2026-04-25

- 确认采用方案 C，不再长期维持 `OpenIMChatStore` 聊天页消息真源。
- 重构目标不是“修掉 sending bug”，而是整体对齐 OpenIM demo 的消息主持方式。
- 聊天页内部主模型以前置 OpenIM `MessageInfo` 为准，`ChatMessage` 退为渲染映射模型。
- 由于当前 `.xcodeproj` 未同步纳入新拆分文件，`RaverOpenIMChatController` 先内联在 `RaverChatController.swift` 中编译；等功能迁移完成后再决定是否重新拆文件并更新工程。

## Execution Log

### 2026-04-25 16:25 +08 - Compatibility Log Noise Reduced

Scope:

- 开始推进 `Phase 10`，先处理低风险、高收益的聊天链路日志降噪；
- 同步核对 `publisher reconciled` / `messages normalized` 这两类旧残留是否已经实际消失；
- 用一次 workspace build 确认这轮清理没有破坏编译。

Execution:

- 在 [`OpenIMChatStore.swift`](</Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Core/OpenIMChatStore.swift:1>) 中移除了几类已经明显过吵、且不再承担回归判断职责的调试日志：
  - `realtime raw message received ...`
  - `realtime message received ...`
  - `realtime conversations changed count=...`
  - `realtime total unread changed count=...`
  - `compat index start ...`
  - `compat index done ...`
- 保留了仍然有明确诊断价值的日志，例如：
  - `compat preview updated ... suppressUnread=...`
  - `normalize active unread ...`
  - `active conversation zeroed unread ...`
  - controller 侧 `mark read success / failed / throttled`
- 代码面再次搜索确认：
  - 已无 `publisher reconciled` 类日志残留
  - 已无 `messages normalized` / placeholder collapse 相关旧日志残留
- 重新执行 workspace build。

Command:

```text
xcodebuild -workspace /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17' build
```

Result:

```text
** BUILD SUCCEEDED **
```

Conclusion:

- `Phase 10` 已经开始实质推进，而不只是停留在 tracker；
- 当前控制台里最吵的那一层 compatibility 过程日志已经降下来了，后续看真正的消息/已读行为会轻松很多；
- `publisher reconciled` 与 `messages normalized` 这两类旧 checklist 已可正式收口。

### 2026-04-25 16:35 +08 - Phase 6 Runtime Echo Validation Closed

Scope:

- 基于现有发送/回流运行日志，收口 `Phase 6` 中剩余的两项验证；
- 确认自己发送消息的 SDK ack / push echo 不会制造重复消息，也不会把已发送状态打回 `sending`。

Evidence:

- 自发文本消息时，controller 先以同一个 `clientMsgID` append sending 消息；
- `sendPreparedMessage success` 之后，SDK 返回的响应仍保持同一 `clientMsgID`；
- 随后的 push message 里同样带着相同的 `clientMsgID`，并在本地被按同 ID replace；
- 对应 UI 日志出现：
  - `apply-start previousCount=51 nextCount=51`
  - `previousTail={id=b7c109210c82321c35b58cb8aaf3ab78 ...}`
  - `nextTail={id=b7c109210c82321c35b58cb8aaf3ab78 ...}`
- 这说明回流后消息总数没有再加一条，尾消息仍是同一条消息，而不是“本地 optimistic 一条 + 回流再来一条”；
- 同轮日志里最终尾消息状态稳定为 `status=sent`，没有出现 sent 回退为 sending 的现象。

Why it matters:

- 这两项验证是 `Phase 6` 最核心的运行时风险点；
- 一旦 self echo 去重不稳，就会直接破坏 demo-style optimistic send 的核心体验；
- 现在已经有明确运行证据说明 raw-first controller path 在这两个点上是成立的。

Conclusion:

- `Phase 6` 可以正式收口；
- 进入后续回归时，self-send / self-echo 这条主风险已经不再是 blocker。

### 2026-04-25 16:45 +08 - Pagination Anchor Observability Added

Scope:

- 为 `Phase 4` 剩余的“历史分页后滚动位置是否稳定”补最小可用观测；
- 不改分页策略本身，只让下一轮运行日志能直接回答锚点是否被正确恢复。

Execution:

- 在 [`RaverChatScrollCoordinator.swift`](</Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Messages/UIKitChat/RaverChatScrollCoordinator.swift:1>) 中新增分页锚点日志：
  - `pagination anchor capture ...`
  - `pagination anchor restore ...`
  - `pagination anchor restore skipped ...`
- 这些日志会把：
  - 旧内容高度
  - 新内容高度
  - 高度增量
  - 目标 offsetY
  直接打印出来，方便和 `DemoAlignedPagination` / `DemoAlignedMessageFlow load-older` 组合判断。
- 重新执行 workspace build，确认这轮观测补充不影响编译。

Command:

```text
xcodebuild -workspace /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17' build
```

Result:

```text
** BUILD SUCCEEDED **
```

Conclusion:

- `Phase 4` 现在已经不缺观测手段，下一轮只要实际触发一次加载更早消息，就能用日志直接判断分页后的 scroll anchor 是否稳定；
- 这一步不会改变行为，只是把最后那个分页验证项从“难判断”变成“可直接判定”。

### 2026-04-25 16:15 +08 - Phase 0-9 Audit And State Reconciliation

Scope:

- 对 `Phase 0 - Phase 9` 做一轮“代码现状 vs tracker 状态”核账；
- 把已经有明确实现依据、但仍停留在 `In Progress` 的阶段正式收口；
- 把真正还需要功能验证或流程约束的残项单独留下，避免带着状态噪音进入 Phase 10。

Execution:

- 复查了 [`RaverChatController.swift`](</Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Messages/UIKitChat/RaverChatController.swift:1>)，确认：
  - `RaverOpenIMChatController` 已经主持 `rawMessages` / `renderedMessages`
  - `appendOrReplace`、按 `clientMsgID` 去重、切会话 reset、发送/重发/实时接收都已集中在 controller
  - `OpenIMChatItem` 与 `OpenIMMessageRenderMapper` 目前以内联类型方式编译存在
- 复查了 [`OpenIMSession.swift`](</Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Core/OpenIMSession.swift:886>)，确认当前 `ChatMessage` 渲染映射已经覆盖：
  - 文本
  - 图片
  - 视频
  - 系统消息
  - sending / sent / failed 状态
- 复查了 [`RaverChatMessageCellFactory.swift`](</Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Messages/UIKitChat/RaverChatMessageCellFactory.swift:1>) 与现有 `DemoAligned*Cell`，确认 UIKit 聊天页仍然沿用既有 cell 体系接入，没有为了新链路重做一套 UI；
- 复查了 [`OpenIMChatStore.swift`](</Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Core/OpenIMChatStore.swift:1>)，确认 `mergeMessage(...)` 相关职责已经收窄为兼容搜索索引/预览更新，store 没有重新成为聊天页消息真源；
- 结合刚刚完成的 retry 审计，把 Phase 9 的 coordinator / screen wiring 状态同步收口。

State updates:

- `Phase 2` -> `Done`
- `Phase 3` -> `Done`
- `Phase 5` -> `Done`
- `Phase 8` -> `Done`
- `Phase 9` -> `Done`

Still intentionally open before Phase 10:

- `Phase 0`：
  - `冻结旧链路的新增功能开发，避免重构中继续扩散依赖`
  - 这是流程治理项，不是单点代码实现，暂不因当前代码状态直接勾掉
- `Phase 6`：
  - `验证不会产生重复消息`
  - `验证 sent 不会回退为 sending`
  - 其中一部分已有运行日志正向信号，但还没整理成明确的回归结论条目

Conclusion:

- 当前进入 `Phase 10` 之前，已经没有明显高于 `Phase 10` 的“大功能开发项”；
- 真正还留在前置阶段里的，主要是 Phase 0/6 的治理或验证型尾项，而不是新的消息链路功能缺口；
- 下一步可以一边推进 `Phase 10`，一边把 Phase 6 的运行回归补成明确结论。

### 2026-04-25 16:20 +08 - History Pagination Anchor Validation Passed

What changed:

- 基于最新一轮运行日志，确认 `DemoAlignedMessageFlowCoordinator` 在历史分页 prepend 后已经稳定执行 pagination anchor restore；
- 日志中连续出现多轮：
  - `apply outcome prepend=1 ...`
  - `pagination anchor restore oldHeight=... newHeight=... delta=... targetOffsetY=...`
- 同时最后一轮到达历史尽头时，出现：
  - `load-older outcome prepend=0 previousCount=170 nextCount=170`
  说明分页结束条件也已正常工作，不会继续错误追加或误滚动。

Validation:

- Runtime log check passed.

Observed signals:

- history page prepend passed
- pagination anchor restore passed
- load-older did not auto-scroll when not near bottom
- reached-history-start detection passed
- no duplicate tail append observed during pagination

Conclusion:

- `Phase 4` 可以正式收口；
- `Phase 10` 中的 `历史分页回归` 也可以一并勾掉；
- 当前更值得继续推进的是双机文本/图片/视频、失败重试与切会话回归，而不是继续卡在分页链路。

Follow-up note:

- 运行日志里仍能看到 `ConversationLoader task start ...` 与 `active conversation registered keys=...` 的重复输出；
- 目前判断这是入口 / lifecycle 侧的日志噪音或 view 重建现象，未阻塞分页与消息主链路，建议作为 `Phase 10` 的日志降噪收尾项单独处理。

### 2026-04-25 16:35 +08 - Media Send Progress And Bottom Anchor Validation Passed

What changed:

- 基于最新一轮真机/双端媒体发送回归，确认图片与视频发送链路已经补齐两类此前残留的 UI 偏差：
  - 发送成功并被对端收到后，媒体发送进度条会立即消失，不再停留在 `100%`；
  - 双端媒体消息不再出现“先往上跳一点，再滑到底部”或“发送端停在上一条消息附近”的抖动；
- 发送端底部锚定语义已收紧为更接近 openim-ios-demo：
  - 只要用户发送前位于底部，后续同一条尾消息的 `replace`、回流补齐、媒体尺寸变化都继续保持贴底；
  - 不再依赖 `tailChanged` 才触发底部保持。

Why it matters:

- 这轮修正把媒体发送行为从“功能上能用”推进到“交互上与 demo 主语义一致”；
- 图片/视频链路现在已经不仅能发成功，而且发送中 UI、成功收口 UI、以及尾部滚动稳定性都通过了运行验证；
- `Phase 10` 里与媒体发送最关键的两项回归可以正式勾掉，不必继续把媒体链路当作阻塞项。

Validation:

- Workspace build passed.
- 双端媒体发送 runtime check passed.

Observed signals:

- image send progress dismissal passed
- video send progress dismissal passed
- sender-side media bottom anchor passed
- receiver-side media bottom anchor passed
- no post-send jump-to-previous-message observed

Conclusion:

- `Phase 10` 中的 `双机图片消息回归` 与 `双机视频消息回归` 可以正式收口；
- 当前更值得继续做的是 `双机文本消息回归`、`重试回归`、`切会话回归`，以及最后一轮高噪音日志清理。

### 2026-04-25 16:45 +08 - Text, Retry And Conversation Switching Regression Passed

What changed:

- 基于最新一轮完整运行回归，补齐了剩余三项高价值验证：
  - 双机文本消息回归通过；
  - 失败重试回归通过；
  - 切会话回归通过；
- 当前聊天主链路已经覆盖：
  - 文本、图片、视频发送；
  - 自己消息回流替换；
  - 历史分页；
  - 失败重试；
  - 会话切换与页面恢复。

Why it matters:

- 这说明本轮 refactor 的主消息链路已经不再只是在局部场景可用，而是核心使用路径都完成了实际运行验收；
- `Phase 10` 现在剩下的主要是“删除不再使用的中间兼容逻辑”和日志/兼容残留清理，而不是功能正确性风险。

Validation:

- Runtime regression check passed.

Observed signals:

- dual-device text send/receive passed
- resend failed message passed
- conversation switching state reset passed
- no duplicate message observed
- no sent-to-sending regression observed

Conclusion:

- `Phase 10` 的运行回归项已经全部收口；
- 当前 tracker 中真正剩下的工作，只剩清理型收尾项。

### 2026-04-25 16:55 +08 - Chat Runtime Log Noise Reduced Safely

What changed:

- 对聊天页最吵的一层运行探针做了保守降噪：
  - 移除了 `DemoAlignedMessageFlowCoordinator` 中围绕 apply / prepend / auto-scroll / failure hint 的逐次探针输出；
  - 移除了 `DemoAlignedMessageApplyCoordinator` 中 before/after reload 级别的探针输出；
  - 移除了 `DemoAlignedViewportCoordinator` 中 jump button / pending count 相关高频探针输出；
  - 移除了 `RaverChatScrollCoordinator` 中 pagination anchor / auto-scroll decision 的高频探针输出；
  - 将 `OpenIMChatStore.debug(...)` 从 `print + OpenIMProbeLogger + OSLog` 收窄为仅 `OSLog`。

Why it matters:

- 现在控制台不会再被历史分页、跳底判断、jump-to-bottom 可见性这类高频 UI 内部状态刷满；
- 运行回归已经全部通过后，继续保留这批逐帧/逐次探针的收益很低，反而会掩盖真正需要看的异常；
- `OpenIMChatStore` 里那层 compatibility adapter 仍在承担搜索索引、会话预览和输入态旁路职责，这一轮先不硬删，避免为了清理把非聊天页主链路碰坏。

Validation:

- Workspace build passed.

Command:

```text
xcodebuild -workspace /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17' build
```

Observed signals:

- build succeeded after log cleanup
- no chat-flow compilation regression observed
- compatibility adapter intentionally retained for search / preview / input-status paths

Conclusion:

- `Phase 10` 已经继续向“清理型收尾”推进了一步；
- 当前剩余的 `删除不再使用的中间兼容逻辑` 需要按职责逐层摘除，不能和这轮日志降噪混在一起粗暴处理。

### 2026-04-25 15:00 +08 - Bubble Constraint Switching Hardened

Scope:

- 清理聊天页剩余的 Auto Layout 冲突噪音；
- 修正消息 cell 在复用和左右对齐切换时的瞬时约束冲突。

Execution:

- 在 `DemoAlignedMessageCell` 中新增成组约束切换逻辑，先统一 deactivate，再按 mine/other 激活对应约束；
- 在 `DemoAlignedMediaMessageCell` 中同步使用同样的成组切换逻辑；
- `prepareForReuse()` 显式恢复到默认的对端布局约束，避免复用状态残留；
- 重新执行 workspace build 验证。

Command:

```text
xcodebuild -workspace /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17' build
```

Result:

```text
** BUILD SUCCEEDED **
```

Conclusion:

- 约束冲突的根因已收敛到 cell 内部的约束切换方式；
- 当前代码已避免“左右同时钉死 + 最大宽度”这一瞬时无解状态；
- 下一步进入真机/模拟器控制台验证，确认 warning 不再出现。

### 2026-04-25 00:00 +08 - Tracker Created

Scope:

- 建立 demo 风格聊天重构追踪文档；
- 锁定目标路线和阶段；
- 作为后续实时更新唯一主看板。

Execution:

- 新增本文件；
- 写入阶段拆分、路径、风险、验收标准和执行日志结构。

Conclusion:

- 方案 C 追踪面板已建立；
- 下一步进入 Phase 1：OpenIM raw message pipeline。

Next:

- 从 `OpenIMSession` 开始增加 raw message API；
- 新建 `RaverOpenIMChatController` 脚手架。

### 2026-04-25 00:15 +08 - Phase 1 Started

Scope:

- 为 demo 风格 controller 铺设 raw OpenIM message 基础能力；
- 先在 `OpenIMSession` 增加 raw page、raw publisher 和 raw send 脚手架。

Execution:

- 在 `OpenIMSession` 中新增 `OpenIMRawMessagePage`；
- 新增 `rawMessagePublisher`；
- 新增 raw history fetch 能力；
- 新增 raw text/image/video message 创建入口；
- 新增 `sendPreparedRawMessage(...)` 包装；
- 实时回调同步向 raw publisher 发送原始消息。

Conclusion:

- Phase 1 已正式开工；
- 新 controller 所需的原生消息出口已开始成型。

Next:

- 跑编译确认脚手架无回归；
- 新建 `RaverOpenIMChatController` 骨架；
- 开始把文本发送切到 raw message 主链路。

### 2026-04-25 08:12 +08 - Raw Pipeline Scaffold Compiled

Scope:

- 完成 demo 风格重构第一批基础脚手架；
- 确保工程仍可完整编译。

Execution:

- 在 `OpenIMSession` 中新增：
  - `OpenIMRawMessagePage`
  - `rawMessagePublisher`
  - raw history fetch API
  - raw text/image/video message create API
  - `sendPreparedRawMessage(...)`
  - realtime raw message publish
- 新建 `RaverOpenIMChatController` 骨架，具备：
  - `rawMessages`
  - `renderedMessages`
  - realtime bind
  - `appendOrReplace`
  - 基础排序与渲染快照转换
- 执行 workspace build 验证。

Command:

```text
xcodebuild -workspace /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17' build
```

Result:

```text
** BUILD SUCCEEDED **
```

Conclusion:

- Phase 1 基础能力已到位；
- Phase 2 已开始，但目前仅完成 controller 骨架，不可替代旧链路。

Next:

- 为 `RaverOpenIMChatController` 加入 initial load / paging state；
- 将文本发送 coordinator 切到新 controller；
- 让文本消息先跑通完整 demo 风格链路。

### 2026-04-25 08:20 +08 - Controller Demo-Style Core Path Compiled

Scope:

- 让当前聊天页真正切到 controller 主持消息数组；
- 补齐文本、图片、视频发送以及失败重试的 demo 风格主链路；
- 维持旧 UI 接口不变，先用适配层平滑切换。

Execution:

- 将 `RaverChatController` 改为 `RaverOpenIMChatController` 的薄适配器；
- 将 `RaverOpenIMChatController` 内联到 `RaverChatController.swift`，避免未入 target 的新文件导致编译缺口；
- controller 现在直接持有：
  - `rawMessages`
  - `renderedMessages`
  - initial load / older paging state
  - realtime raw message bind
- 完成 `appendOrReplace(message:)`、按 `clientMsgID` 去重、切会话 reset；
- 文本、图片、视频发送统一改成：
  - create raw message
  - append sending
  - `sendPreparedRawMessage(...)`
  - success replace sent
  - failure replace failed
- 失败重试改为直接重发当前 controller 持有的 failed raw message；
- workspace build 重新验证通过。

Command:

```text
xcodebuild -workspace /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17' build
```

Result:

```text
** BUILD SUCCEEDED **
```

Conclusion:

### 2026-04-25 14:45 +08 - Raw-First Service Boundary Tightened

Scope:

- 把 `LiveSocialService` 和聊天 controller 之间的 raw-first 能力边界正式抽出来；
- 继续把 `ChatMessage` 相关接口收敛到 compatibility 区；
- 更新追踪看板状态，确保阶段完成度与当前代码一致。

Execution:

- 在 `SocialService.swift` 中引入 `OpenIMRawChatService`，承载 raw realtime、raw history、raw create、prepared send 和 snapshot 能力；
- 在 `SocialService.swift` 中引入 `OpenIMChatCompatibilityService`，把 `ChatMessage` 旧接口明确标成兼容面；
- 让 `OpenIMSession` 直接遵循 `OpenIMRawChatService`；
- 让 `LiveSocialService` 通过 forwarding 遵循 `OpenIMRawChatService`，并在 compatibility 方法里优先走 raw pipeline；
- 修正 `LiveSocialService` 中因 `@MainActor` raw service 引入的 `await` / actor 边界问题；
- 将递归风险 helper 重命名为 `compatibilityChatMessageSnapshot(...)`；
- 校准 Phase 8 / Phase 9 勾选状态，使其与当前代码落地一致；
- 重新执行 workspace build 验证。

Command:

```text
xcodebuild -workspace /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17' build
```

Result:

```text
** BUILD SUCCEEDED **
```

Conclusion:

- controller 主链路现在已经是面向 raw chat capability，而不是硬绑 `OpenIMSession.shared`；
- `SocialService` 协议层的 raw-first / compatibility 边界已经成型；
- `OpenIMChatStore` 继续保留为会话域和兼容索引层，不再回到聊天页真源角色。

Next:

- 继续收窄 `OpenIMSession.messagePublisher` 和 `chatMessageSnapshot(...)` 的兼容范围；
- 评估失败重试入口与系统消息映射是否还存在旧 controller 假设；
- 开始推动 Phase 7 的 typing / system / read-state 接入。

### 2026-04-25 14:55 +08 - Typing Status Routed Through Controller

Scope:

- 把输入态从 store-only 兼容层往 controller-owned chat flow 再推进一步；
- 让 composer 编辑变化开始走 typing best-effort 发送；
- 为后续 UI typing indicator 留出 controller 级别状态出口。

Execution:

- 在 `RaverChatController` / `RaverOpenIMChatController` 中新增 `latestInputStatus` 发布状态；
- 新 controller 订阅 `session.inputStatusPublisher`，按当前会话过滤，并忽略当前登录用户自己的 typing 事件；
- typing 事件进入 controller 后自动 4 秒过期；
- 当当前会话收到真实消息时，会清除 typing 状态；
- 给 `RaverChatController` 增加 `handleComposerInputChanged(_:)`；
- `DemoAlignedComposerActionCoordinator` 和其 factory 新增输入文本回调；
- `DemoAlignedChatViewController` 在 composer `editingChanged` 链路里开始通知 chat controller 发送 typing status（节流 + best-effort）。

Conclusion:

- Phase 7 已正式启动；
- 输入态现在不再只停留在 `OpenIMChatStore`，而是进入了 controller-owned chat flow；
- UI 还没正式展示 typing indicator，但状态出口已经准备好。

Next:

- 评估最小 UI 展示位，决定是否在现有聊天页增加 typing indicator；
- 继续处理 system message 渲染映射；
- 继续梳理 read-state 与当前 controller 链路的职责分界。

### 2026-04-25 15:05 +08 - System Message Preview Text Upgraded

Scope:

- 让 system message 不再只显示通用占位文本；
- 在不重写现有 system cell 的前提下，增强 raw message 到 `ChatMessage` 的系统消息文案映射；
- 继续推进 Phase 7。

Execution:

- 复查了聊天页现状，确认：
  - `messageKind(from:)` 已能把 `notificationElem` 识别成 `.system`
  - `RaverChatMessageCellFactory` 已经会把 `.system` 交给 `DemoAlignedSystemMessageCell`
  - 主要缺口在 `previewText(from:)` 仍然返回通用 `[系统消息]`
- 在 `OpenIMSession.previewText(from:)` 中新增 `systemNotificationPreviewText(from:)`；
- 基于 OpenIM 的稳定通知枚举，为常见群系统事件提供更具体的预览文案：
  - 创建群聊
  - 退群
  - 踢人
  - 邀请入群
  - 入群
  - 解散群
  - 群公告更新
  - 群名称更新
- 修复第一次实现时暴露出的两处编译问题：
  - `kickedUserList` / `invitedUserList` 可选链
  - `contentType` 直接按 `OIMMessageContentType` 枚举 `switch`
- 重新执行 workspace build 验证通过。

Conclusion:

- system message 现在已经走在新渲染映射链路里，并且会显示更接近真实事件的人话文案；
- 聊天页 UI 侧无需新增 cell 或大改布局就能吃到这次收益；
- Phase 7 已经从 typing 扩展到 system message。

Next:

- 继续梳理 read-state 在 controller / session / store 三层间的职责；
- 评估是否要在现有聊天页增加最小 typing indicator 展示；
- 再做一轮发送、系统消息、已读联动的集成验证。

- Phase 1 已完成；
- Phase 2 的 controller 真源切换已经生效；
- Phase 4/5/6 已进入可用状态，但还缺少回归验证和旧 store 职责收缩。

Next:

- 做一次文本/图片/视频/重试链路回归；
- 开始清理 `OpenIMChatStore` 的消息发送与归并职责；
- 评估输入状态、系统消息、已读状态还剩多少依赖旧链路。

### 2026-04-25 08:22 +08 - Data Provider Boundary Trimmed

Scope:

- 继续收缩旧消息链路的可见边界；
- 避免聊天页继续从 `RaverChatDataProvider` 走旧 store 消息接口。

Execution:

- 删除 `RaverChatDataProvider` 中不再被聊天页使用的消息相关接口：
  - message publisher / snapshot
  - initial load / older load
  - send text / image / video
  - resend failed
- 保留当前聊天页仍需要的：
  - `currentConversation`
  - `currentService`
  - `updateContext(...)`
  - `searchMessages(...)`
- 再次执行 workspace build 验证。

Command:

```text
xcodebuild -workspace /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17' build
```

Result:

```text
** BUILD SUCCEEDED **
```

Conclusion:

- 聊天页对旧 store 消息接口的编译期依赖进一步减少；
- Phase 8 已开始，但 `OpenIMChatStore` 内部 message store 逻辑仍待收缩。

Next:

- 继续识别 `OpenIMChatStore` 中仅聊天页历史遗留使用的 message merge / replace / normalization 逻辑；
- 准备把这些职责迁到更小的兼容层，或直接废弃。

### 2026-04-25 11:50 +08 - Store Message Surface Restricted

Scope:

- 继续推进 Phase 8；
- 把 `OpenIMChatStore` 中已经不该被聊天页外部使用的消息 API 收回内部。

Execution:

- 保持 `OpenIMChatMessageDataSource` 协议可见，避免影响 `SocialService` 继承链；
- 将 `OpenIMChatStore` 下列方法收回为私有实现细节：
  - `messages(for:)`
  - `loadMessages(...)`
  - `loadOlderMessages(...)`
  - `hasOlderMessages(...)`
  - `isLoadingOlderMessages(...)`
  - `sendMessage(...)`
  - `sendImageMessage(...)`
  - `sendVideoMessage(...)`
  - `resendFailedMessage(...)`
- 将 `messagesByConversationID` 从 `private(set)` 收紧为 `private`；
- 过程中发现把 `OpenIMChatMessageDataSource` 设为 `private` 会影响 `SocialService`，已回退该项并保留协议公开；
- 再次执行 workspace build 验证。

Command:

```text
xcodebuild -workspace /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17' build
```

Result:

```text
** BUILD SUCCEEDED **
```

Conclusion:

- 旧 store 的消息方法仍在文件内部作为兼容实现存在；
- 但聊天页外部已经不能继续从这些 API 回到旧消息真源；
- Phase 8 进入“内部逻辑清理”阶段，而不是“对外收口”阶段。

Next:

- 评估 `bindOpenIMSession -> mergeMessage(...)` 这一整段对搜索、输入状态、会话预览的真实剩余价值；
- 为 Phase 3 的渲染映射层拆分做准备，减少 controller 中直接 `ChatMessage` 快照生成的耦合。

### 2026-04-25 11:52 +08 - Render Mapper Layer Started

Scope:

- 启动 Phase 3；
- 把 controller 中直接生成 `ChatMessage` 快照的逻辑抽成独立 mapper 层；
- 不在本轮触碰 `.xcodeproj` 文件纳管，先以内联方式落在已编译聊天文件内。

Execution:

- 在 `RaverChatController.swift` 的 `#if canImport(OpenIMSDK)` 区域中新增：
  - `OpenIMChatItem`
  - `OpenIMMessageRenderMapper`
- `RaverOpenIMChatController` 新增 `renderedItems`，并改由 mapper 统一生成：
  - `rebuildRenderedMessages()`
  - `renderedMessageSnapshot(from:)`
- 保持现有 UI 输出仍为 `[ChatMessage]`，避免本轮引发 cell 层大改。

Command:

```text
xcodebuild -workspace /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17' build
```

Result:

```text
** BUILD SUCCEEDED **
```

Conclusion:

- Phase 3 已开始；
- 渲染映射不再散落在 controller 方法里，而是有了明确的 mapper 层入口；
- 由于项目文件当前未同步纳入新拆分文件，本轮选择先内联实现，后续再决定是否拆回独立文件。

Next:

- 继续评估 `OpenIMSession.toChatMessage(...)` 中的文本/图片/视频/system 映射逻辑，决定是否整体迁到 mapper；
- 明确 `OpenIMChatStore.bindOpenIMSession` 目前到底还剩搜索索引、输入状态、会话预览中的哪几块是必需的。

### 2026-04-25 11:55 +08 - Store Realtime Path Moved To Raw Publisher

Scope:

- 继续压缩 legacy `ChatMessage` 发布链的主通道地位；
- 让 `OpenIMChatStore` 不再直接依赖 `OpenIMSession.messagePublisher`。

Execution:

- 在 `OpenIMChatStore.swift` 中引入 `OpenIMSDK` 条件编译；
- 将 `bindOpenIMSession()` 的消息订阅从：
  - `session.messagePublisher`
  切换为：
  - `session.rawMessagePublisher`
- 在 store 内新增 `legacyChatMessage(from:)`，仅作为兼容映射桥：
  - 先通过 `businessConversationIDSnapshot(for:)` 还原业务会话 ID
  - 再通过 `chatMessageSnapshot(from:conversationID:)` 生成兼容 `ChatMessage`
- 保留 `#else` 分支上的旧 `messagePublisher` 订阅，避免在无 OpenIMSDK 环境下断编译；
- 执行 workspace build 验证。

Command:

```text
xcodebuild -workspace /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17' build
```

Result:

```text
** BUILD SUCCEEDED **
```

Conclusion:

- `OpenIMChatStore` 的 realtime message merge 已经改为基于 raw message 主通道；
- `OpenIMSession.messagePublisher` 现在更接近兼容出口，而不是系统消息主总线；
- 这为后续继续下调 `toChatMessage(...)` 的系统核心地位创造了条件。

Next:

- 继续梳理 `OpenIMSession` 中 `toChatMessage(...)`、legacy send API、legacy history fetch API 的真实剩余调用点；
- 评估是否可以把这些 legacy `ChatMessage` 入口集中标记为兼容层，减少新逻辑继续依赖它们。

### 2026-04-25 11:58 +08 - LiveSocialService Moved Onto Raw OpenIM APIs

Scope:

- 继续压缩 legacy `ChatMessage` API 在新代码中的主干地位；
- 保持 `SocialService` 对外签名不变，但让 `LiveSocialService` 内部优先走 raw OpenIM message。

Execution:

- 在 `LiveSocialService.swift` 中引入 `OpenIMSDK` 条件编译；
- 将以下实现从 legacy `OpenIMSession` `ChatMessage` API 切换为 raw API + 兼容映射：
  - `fetchMessages(conversationID:startClientMsgID:count:)`
  - `sendMessage(conversationID:content:)`
  - `sendImageMessage(conversationID:fileURL:onProgress:)`
  - `sendVideoMessage(conversationID:fileURL:onProgress:)`
- 新实现统一采用：
  - `fetchRawMessagesPage(...)`
  - `createRawTextMessage(...)`
  - `createRawImageMessage(...)`
  - `createRawVideoMessage(...)`
  - `sendPreparedRawMessage(...)`
- 在 service 层新增一个临时兼容桥：
  - `chatMessageSnapshot(from:conversationID:)`
  - 先通过 `businessConversationIDSnapshot(for:)` 恢复业务会话 ID
  - 再调用 `OpenIMSession.chatMessageSnapshot(...)`
- 处理完 actor 隔离后重新执行 workspace build。

Command:

```text
xcodebuild -workspace /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17' build
```

Result:

```text
** BUILD SUCCEEDED **
```

Conclusion:

- `LiveSocialService` 已经不再依赖 `OpenIMSession.sendTextMessage/sendImageMessage/sendVideoMessage/fetchMessagesPage` 作为内部主路径；
- 这些 legacy `ChatMessage` API 进一步降格为兼容出口，主要服务于尚未迁移的调用层；
- 目前明确保留的临时兼容层包括：
  - `OpenIMSession.messagePublisher`
  - `OpenIMSession.toChatMessage(...) / chatMessageSnapshot(...)`
  - `SocialService` 的 `ChatMessage` 返回签名
  - `OpenIMChatStore` 内部的 `legacyChatMessage(from:)`

Next:

- 继续审计 `OpenIMSession` 的 legacy `ChatMessage` API 剩余调用点，优先确认是否只剩兼容入口；
- 评估 `SocialService` 协议本身何时能从 `ChatMessage` 返回签名迁走；
- 继续推进 Phase 8，收缩 `OpenIMChatStore` 内部 `mergeMessage / replaceMessage / normalization` 残留逻辑。

### 2026-04-25 12:00 +08 - Legacy OpenIMSession ChatMessage APIs Wrapped Around Raw Pipeline

Scope:

- 继续降低 `OpenIMSession` legacy `ChatMessage` API 的真实实现权重；
- 让旧接口变成兼容壳，而不是继续保留第二套发送/历史实现。

Execution:

- 在 `OpenIMSession.swift` 中重写以下 legacy API 的 `#if canImport(OpenIMSDK)` 实现：
  - `fetchMessagesPage(conversationID:startClientMsgID:count:)`
  - `sendTextMessage(conversationID:content:)`
  - `sendImageMessage(conversationID:fileURL:onProgress:)`
  - `sendVideoMessage(conversationID:fileURL:onProgress:)`
- 新实现统一改为：
  - 历史拉取先走 `fetchRawMessagesPage(...)`
  - 发送先走 `createRaw*Message(...)`
  - 再走 `sendPreparedRawMessage(...)`
  - 最后通过 `chatMessageSnapshot(...)` 转回兼容 `ChatMessage`
- 保留 legacy 对外签名不变，避免影响仍未迁移的上层调用。

Command:

```text
xcodebuild -workspace /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17' build
```

Result:

```text
** BUILD SUCCEEDED **
```

Conclusion:

- `OpenIMSession` 的 legacy `ChatMessage` fetch/send API 已不再维护独立主实现；
- 即使还有旧调用点，它们现在也已经借道 raw pipeline，而不是继续走第二条发送/分页逻辑；
- 当前兼容层进一步收敛为“签名兼容 + 最后一步映射”，而不是“签名兼容 + 独立实现”。

Next:

- 继续确认 `OpenIMSession.messagePublisher`、`chatMessageSnapshot(...)`、`toChatMessage(...)` 是否只剩兼容用途；
- 评估是否可以把 `OpenIMChatStore` 顶部的 legacy message datasource surface 明确标记为过渡层，并继续收缩内部 `merge/replace/normalization` 逻辑。

### 2026-04-25 12:02 +08 - Compatibility Boundaries Documented In Code

Scope:

- 继续明确“主链路”和“过渡兼容层”的边界；
- 让后续迁移不再依赖口头约定，而是直接体现在代码注释里。

Execution:

- 在 `OpenIMSession.swift` 中为以下接口补充兼容层说明：
  - `messagePublisher`
  - `fetchMessages(...)`
  - `fetchMessagesPage(...)`
  - `sendTextMessage(...)`
  - `sendImageMessage(...)`
  - `sendVideoMessage(...)`
- 明确 `rawMessagePublisher` 是 demo-style chat flow 的主消息流；
- 在 `OpenIMChatStore.swift` 中加强 legacy 注释：
  - `OpenIMChatMessageDataSource` 明确标注为过渡面，不允许新 demo-style chat flow 再新增依赖；
  - `legacyChatMessage(from:)` 明确标注为 store 搜索/输入状态仍在使用的临时兼容桥；
- 执行 workspace build 验证注释整理没有引入行为回归。

Command:

```text
xcodebuild -workspace /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17' build
```

Result:

```text
** BUILD SUCCEEDED **
```

Conclusion:

- 当前代码里“主消息流”和“兼容出口”的角色已经写清楚，不再只靠上下文猜；
- `OpenIMSession.messagePublisher` 与 store 顶部 datasource surface 被正式降格为过渡层概念；
- 这为后续真正删除 `OpenIMChatStore` 内部旧消息状态机留下了更清楚的迁移边界。

Next:

- 继续收缩 `OpenIMChatStore` 内部 `mergeMessage / replaceMessage / normalization` 逻辑，优先识别哪些只服务于已失效的 placeholder 路线；
- 继续核对 `OpenIMSession.toChatMessage(...)` 是否已经只剩渲染兼容和 store/search 兼容用途。

### 2026-04-25 12:04 +08 - Store Presentation-Time Placeholder Collapse Removed

Scope:

- 继续推进 Phase 8；
- 优先移除只服务于旧 `local-*` placeholder 展示路径的 store 侧逻辑。

Execution:

- 在 `OpenIMChatStore.swift` 中调整 `messages(for:)`：
  - 不再走 `normalizedMessagesForPresentation(...)`
  - 只保留 `deduplicatedAndSortedMessages(...)`
  - debug 日志从 `messages normalized` 改为 `messages deduplicated`
- 删除以下仅服务于 presentation-time placeholder collapse 的旧 helper：
  - `normalizedMessagesForPresentation(...)`
  - `collapseOutgoingPlaceholdersForPresentation(...)`
  - `preferredOutgoingCounterpartIndex(...)`
- 保留 `staleOutgoingPlaceholderIndex(...)` 与 `replaceMessage(...)` 中的 placeholder 识别，因为这部分仍承担 store 内部旧状态机的兼容替换职责；
- 重新执行 workspace build 验证。

Command:

```text
xcodebuild -workspace /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17' build
```

Result:

```text
** BUILD SUCCEEDED **
```

Conclusion:

- store 侧“读取消息时顺手折叠 local placeholder”的展示逻辑已经退场；
- 这意味着 placeholder 相关残留现在只剩内部兼容状态机，而不再影响 store 的日常读取路径；
- Phase 8 的清理已从“接口收口”推进到“旧展示机制拆除”。

Next:

- 继续审计 `mergeMessage(...) / replaceMessage(...) / staleOutgoingPlaceholderIndex(...)`，判断哪些分支仍是必需兼容，哪些可以继续下沉或删除；
- 评估 `updateConversationPreview(from:)` 是否还需要依附旧消息状态机，还是可以更明确地只服务会话域职责。

### 2026-04-25 14:06 +08 - Dead Store Paging And Send Helpers Removed

Scope:

- 继续推进 Phase 8；
- 先把 `OpenIMChatStore` 中已经完全脱离调用链的旧私有分页/发送实现移除。

Execution:

- 从 `OpenIMChatStore.swift` 删除以下已无引用的旧私有方法：
  - `loadMessages(...)`
  - `loadOlderMessages(...)`
  - `hasOlderMessages(...)`
  - `isLoadingOlderMessages(...)`
  - `sendMessage(...)`
  - `sendImageMessage(...)`
  - `sendVideoMessage(...)`
  - `resendFailedMessage(...)`
  - `localFileURL(...)`
  - `localOutgoingSender(...)`
  - `replaceMessage(...)`
  - `updateMessageState(...)`
- 重新扫描 `OpenIMChatStore.swift` 内部引用，确认上述 helper 不再被任何路径调用；
- 重新执行 workspace build 验证。

Command:

```text
xcodebuild -workspace /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17' build
```

Result:

```text
** BUILD SUCCEEDED **
```

Conclusion:

- `OpenIMChatStore` 里一整批已经“只剩定义、没有入口”的旧聊天页实现已经被清掉；
- 现在 store 内留下来的旧消息逻辑，基本都是真正还在服务 realtime/search/conversation preview 兼容层的部分；
- 后续清理焦点可以更集中地放在 `mergeMessage(...)` 与 placeholder collapse 的残留兼容路径上。

Next:

- 继续审计 `mergeMessage(...)` 里的 placeholder-collapse 分支是否仍然必要；
- 评估会话预览与搜索索引是否可以进一步脱离旧 `ChatMessage` merge 状态机。

### 2026-04-25 14:11 +08 - Store Placeholder Collapse Retired

Scope:

- 继续推进 Phase 5 与 Phase 8；
- 从 `OpenIMChatStore` 的存量兼容状态机里移除已经失去触发前提的 placeholder-collapse 分支。

Execution:

- 在 `OpenIMChatStore.swift` 中从 `mergeMessage(...)` 删除 placeholder-collapse 分支；
- 删除 `staleOutgoingPlaceholderIndex(...)` helper；
- 基于当前代码路径复核：store 已不再创建任何 `local-*` 消息，因此上述逻辑已无运行前提；
- 同步更新追踪文档中 Phase 5 / Phase 8 的勾选状态。

Command:

```text
xcodebuild -workspace /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17' build
```

Result:

```text
** BUILD SUCCEEDED **
```

Conclusion:

- `OpenIMChatStore` 已不再依赖 `local-*` placeholder collapse 机制；
- 方案 C 的发送链路与 store 兼容层之间，关于 placeholder 的历史耦合又断开了一层；
- 后续 Phase 8 的主焦点可以更明确地落在 `mergeMessage(...)` 本身是否还值得保留。

Next:

- 继续审计 `mergeMessage(...)` 是否可以被更窄的 search / preview 索引更新逻辑替代；
- 评估 `messagesByConversationID` 是否仍有必要作为 store 内部缓存长期保留。

### 2026-04-25 14:09 +08 - Store Paging Residue Removed

Scope:

- 继续推进 Phase 8；
- 清理 `OpenIMChatStore` 中已经没有实际读写链路的分页与消息缓存残骸。

Execution:

- 从 `OpenIMChatStore.swift` 删除：
  - `MessagePaginationState`
  - `messagePaginationByConversationID`
  - `messages(for:)`
  - `replaceMessages(...)`
  - `clearPaginationState(...)`
  - `paginationKey(...)`
  - 相关 reset / clear 调用
- `clearMessages(for:)` 改为直接清空 store 的残留消息缓存键，而不是维持空消息数组；
- 重新扫描 `OpenIMChatStore.swift`，确认上述符号已不再残留引用；
- 重新执行 workspace build 验证。

Command:

```text
xcodebuild -workspace /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17' build
```

Result:

```text
** BUILD SUCCEEDED **
```

Conclusion:

- `OpenIMChatStore` 已不再持有聊天页历史分页状态；
- store 的内部形状进一步从“旧消息 store”收缩成“会话域 + 搜索索引 + 少量兼容缓存”；
- 现在最显眼、也最该被继续处理的剩余旧职责就是 `mergeMessage(...)` 本身和 `messagesByConversationID`。

Next:

- 评估 `mergeMessage(...)` 能否被更窄的 search-index / preview 更新逻辑替代；
- 审计 `messagesByConversationID` 是否还能继续收缩，还是短期内仍要为搜索与清理动作保留。

### 2026-04-25 14:11 +08 - Store Message Cache Removed

Scope:

- 继续推进 Phase 8；
- 让 `OpenIMChatStore` 停止私藏一份 `ChatMessage` 数组缓存，只保留真正还在使用的会话域与搜索索引职责。

Execution:

- 从 `OpenIMChatStore.swift` 删除：
  - `messagesByConversationID`
  - `storeMessages(...)`
  - `clearStoredMessages(...)`
  - `sortMessages(...)`
  - `deduplicatedAndSortedMessages(...)`
  - `preferredDuplicateMessage(...)`
  - `resolvedDeliveryStatus(...)`
- 将 `mergeMessage(...)` 改成直接：
  - 计算会话别名 keys
  - 增量写入 `messageSearchIndex`
  - 更新 conversation preview
- `clearMessages(for:)` / `removeConversation(...)` 改为只清 search index、pending focus、输入状态和会话域状态；
- 重新扫描引用，确认 `messagesByConversationID` 及相关 helper 已无残留；
- 重新执行 workspace build 验证。

Command:

```text
xcodebuild -workspace /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17' build
```

Result:

```text
** BUILD SUCCEEDED **
```

Conclusion:

- `OpenIMChatStore` 已不再维护内部消息数组缓存；
- store 的剩余消息相关职责现在主要只剩“把 realtime 消息写进搜索索引并联动会话预览”；
- 方案 C 下，聊天页消息真源与 store 之间的边界已经比之前清楚很多。

Next:

- 继续审计 `mergeMessage(...)` 是否还能进一步下沉成更窄的 search-index / preview adapter；
- 评估 `OpenIMChatMessageDataSource` / `SocialService` 协议层是否也可以进一步脱离 `ChatMessage` 历史面。 

### 2026-04-25 14:13 +08 - Legacy Message Datasource Protocol Detached

Scope:

- 继续推进 Phase 8；
- 把 `SocialService` 与 `OpenIMChatStore` 旧消息 datasource 协议的继承耦合拆开。

Execution:

- 从 `OpenIMChatStore.swift` 删除不再被使用的 `OpenIMChatMessageDataSource` 协议与其默认扩展；
- 将 [`SocialService`](</Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Core/SocialService.swift:19>) 从继承 `OpenIMChatMessageDataSource` 改为只继承 `OpenIMChatConversationDataSource`；
- 重新扫描工作区，确认 `OpenIMChatMessageDataSource` 已无残留引用；
- 重新执行 workspace build 验证。

Command:

```text
xcodebuild -workspace /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17' build
```

Result:

```text
** BUILD SUCCEEDED **
```

Conclusion:

- `OpenIMChatStore` 已不再通过协议继承把旧消息职责绑在 `SocialService` 身上；
- store 与 service 之间现在只保留会话域接口耦合，这更接近方案 C 期望的分层边界；
- 剩余最明显的旧面已经转移到 `SocialService` 自身公开的 `ChatMessage` API，而不是 store 协议链。

Next:

- 继续评估 `SocialService` 公开的 `ChatMessage` 消息接口是否需要拆分成更明确的 raw / compatibility 两层；
- 继续收缩 `OpenIMChatStore.mergeMessage(...)` 的命名与职责，让它更像 search-index / preview adapter。 

### 2026-04-25 14:15 +08 - Store Compatibility Adapter Renamed

Scope:

- 继续推进 Phase 8；
- 把 `OpenIMChatStore` 里剩下那层 realtime 消息兼容逻辑，从“像消息 store 的 merge”改成更明确的 search-index / preview adapter 语义。

Execution:

- 将 [`OpenIMChatStore.swift`](</Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Core/OpenIMChatStore.swift:1>) 中：
  - `mergeMessage(...)` 重命名为 `indexRealtimeMessageForCompatibility(...)`
  - `updateConversationPreview(...)` 重命名为 `updateConversationPreviewForCompatibility(...)`
- 同步替换 raw realtime / legacy realtime 订阅分支中的调用点；
- 调整日志前缀，从 `merge ...` 改为 `compat index ...`，明确这已不是消息真源更新链路；
- 保留行为不变，只收窄命名和职责表达，方便下一步继续拆除兼容层。

Result:

- `OpenIMChatStore` 中残留的消息相关逻辑，现在在命名上已经明确属于兼容索引/预览适配层，而不是聊天页主消息状态机；
- Phase 8 的 `mergeMessage(...)` 已进入“收窄中”状态，不再是之前那种容易误导后续开发者继续扩展的接口形状。

Next:

- 继续评估 `OpenIMChatStore` 里这层 compatibility adapter 是否还能进一步下沉或拆分成更薄的 search-index / preview helper；
- 继续审计 `SocialService` 和 `OpenIMSession` 中剩余的 `ChatMessage` 兼容出口，确认哪些还能继续收口。

### 2026-04-25 14:20 +08 - Raw Chat Service Interface Introduced

Scope:

- 继续推进 Phase 2 / Phase 8；
- 给 demo-style controller 补一条正式的 raw-first 服务接口，避免新代码继续默认贴着 `OpenIMSession.shared` 写。

Execution:

- 在 [`SocialService.swift`](</Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Core/SocialService.swift:1>) 新增 `@MainActor OpenIMRawChatService`：
  - 暴露 `rawMessagePublisher`
  - raw history page fetch
  - raw create text/image/video
  - `sendPreparedRawMessage(...)`
  - `businessConversationIDSnapshot(...)`
  - `chatMessageSnapshot(...)`
- 让 [`OpenIMSession`](</Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Core/OpenIMSession.swift:1>) 直接声明遵循 `OpenIMRawChatService`；
- 让 [`LiveSocialService`](</Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Core/LiveSocialService.swift:1>) 通过 forwarding 遵循 `OpenIMRawChatService`，并将 conformance 明确收进 `MainActor`；
- 将 [`RaverChatController.swift`](</Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Messages/UIKitChat/RaverChatController.swift:132>) 的 demo-style controller 改为：
  - 优先使用 `service as? OpenIMRawChatService`
  - fallback 到 `OpenIMSession`
  - realtime / history / create / send / snapshot / conversation mapping 全部改走 raw service 接口
- 修复一次编译失败：`LiveSocialService` 转发到 `OpenIMSession.shared` 时的 actor-isolation 不一致。

Command:

```text
xcodebuild -workspace /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17' build
```

Result:

```text
** BUILD SUCCEEDED **
```

Conclusion:

- 新聊天主链路现在已经有了正式的 raw service 边界，而不只是“controller 知道 session singleton”；
- `RaverOpenIMChatController` 的依赖方向更接近方案 C：优先面向 raw chat capability，而不是面向 legacy `ChatMessage` service 面；
- `ChatMessage` 兼容壳仍在，但它们现在更明确地留在 `SocialService` / compatibility 出口，而不是继续渗进 controller 主干。

Next:

- 继续评估 `SocialService` 公开的 `ChatMessage` 聊天接口，看看是否要再拆成更明确的 compatibility zone；
- 继续梳理 `OpenIMSession.messagePublisher` / `chatMessageSnapshot(...)` 的剩余调用点，确认哪些还是真需要，哪些只是历史残留。

### 2026-04-25 14:23 +08 - ChatMessage Compatibility Zone Split Out

Scope:

- 继续推进 Phase 8；
- 把 `SocialService` 里仍然使用 `ChatMessage` 的聊天接口，从主服务面中显式分离成 compatibility zone。

Execution:

- 在 [`SocialService.swift`](</Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Core/SocialService.swift:1>) 新增 `OpenIMChatCompatibilityService`：
  - `fetchMessages(conversationID:)`
  - `sendMessage(conversationID:content:)`
  - `sendImageMessage(conversationID:fileURL:)`
  - `sendVideoMessage(conversationID:fileURL:)`
- 让 `SocialService` 继承 `OpenIMChatCompatibilityService`，而不再在主协议体里直接混放这组 legacy chat surface；
- 将图片/视频发送的默认实现迁到 `OpenIMChatCompatibilityService` 扩展里，明确这是 compatibility 行为，不是主服务面职责；
- 重新执行 workspace build 验证协议拆分没有影响现有实现。

Command:

```text
xcodebuild -workspace /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17' build
```

Result:

```text
** BUILD SUCCEEDED **
```

Conclusion:

- `SocialService` 现在在协议层就已经把“主业务能力”和“ChatMessage 兼容聊天能力”分层了；
- 这让后续继续收 `ChatMessage` 旧面时，不必再在大协议里到处翻找，边界清晰很多；
- controller 主链路继续依赖 raw chat service，`ChatMessage` surface 则更明确地退到了 compatibility zone。

Next:

- 继续梳理 `OpenIMSession.messagePublisher` / `chatMessageSnapshot(...)` 的剩余调用点，确认哪些还能继续收成兼容出口；
- 评估 `LiveSocialService` 里对 `OpenIMSession.shared.fetchMessagesPage/send*Message` 的 fallback 分支是否还能进一步瘦身。

### 2026-04-25 15:20 +08 - Read State Routed Through Raw Chat Capability

What changed:

- 在 [`SocialService.swift`](</Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Core/SocialService.swift:1>) 的 `OpenIMRawChatService` 中加入 `markConversationRead(conversationID:)` 能力，让新聊天链路的已读同步不再绕回 `OpenIMSession` 具体类型；
- 在 [`LiveSocialService.swift`](</Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Core/LiveSocialService.swift:901>) 中补齐 `OpenIMRawChatService.markConversationRead(...)` forwarding；
- 在 [`RaverChatController.swift`](</Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Messages/UIKitChat/RaverChatController.swift:162>) 的 `RaverOpenIMChatController` 中：
  - initial load 完成后改走 `rawChatService.markConversationRead(...)`
  - 当前会话收到对端非 typing 新消息后，追加节流的 best-effort mark-read
  - 新增 `readMarkThrottleSeconds` / `lastReadMarkAt`，避免对 SDK 连续打读标记
  - 在 `resetState()` 中同步清理 read-state 节流状态

Why it matters:

- 这让 Phase 7 的已读链路也正式进入 raw-first / controller-owned chat flow，而不是继续由 controller 直接耦合 `OpenIMSession`；
- 当前会话打开时，如果对端消息实时到达，聊天页会主动补一次已读同步，减少 unread 状态因为 store 收缩而滞后的机会。

Build:

- Workspace build passed.

Command:

```text
xcodebuild -workspace /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17' build
```

Result:

```text
** BUILD SUCCEEDED **
```

Conclusion:

- `markConversationRead` 现在和 realtime/history/send 一样，成为 raw chat capability 的正式一部分；
- 聊天页的 read-state 边界更统一了，下一步就可以更专注地做 unread/read 集成验证，而不是继续清接口债。

Next:

- 完成这轮 workspace build；
- 做一轮当前会话实时收消息时的 unread/read 行为验证，决定是否把 Phase 7 的最后一个未勾项一并收掉。

### 2026-04-25 15:32 +08 - Active Conversation No Longer Inflates Unread Preview

What changed:

- 在 [`OpenIMChatStore.swift`](</Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Core/OpenIMChatStore.swift:1>) 增加了一个很窄的活跃会话引用计数层：
  - `activeConversationReferenceCounts`
  - `activateConversation(_:)`
  - `deactivateConversation(_:)`
- `replaceConversations(...)` 现在会在排序前调用 `normalizeActiveConversationUnreadCounts(...)`，把当前正打开的会话 unread 固定归零；
- `updateConversationPreviewForCompatibility(...)` 在处理 realtime 对端消息时，如果命中的会话当前处于活跃状态，就不再做 `unreadCount + 1`；
- 在 [`RaverChatController.swift`](</Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Messages/UIKitChat/RaverChatController.swift:162>) 的 `RaverOpenIMChatController` 中：
  - `start()` 时注册当前活跃会话
  - `updateContext(...)` 时释放旧会话再切新会话
  - `deinit` 时补充释放，避免活跃标记泄漏

Why it matters:

- 这次不是继续依赖异步 `markConversationRead(...)` 追着修 unread，而是直接把“当前会话不应该在预览层继续累加 unread”写成兼容层规则；
- 它能明显减少当前聊天页打开时，对端新消息先把列表 unread 顶起来、随后又被 read 回写抹掉的短暂倒挂。

Build:

- Workspace build passed.

Command:

```text
xcodebuild -workspace /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17' build
```

Result:

```text
** BUILD SUCCEEDED **
```

Conclusion:

- Phase 7 的 unread/read 现在已经不只是“能补”，而是多了一层机制性保护；
- 最后还差一轮运行时验证，确认 conversation publisher 回流时不会再出现肉眼可见的 unread 抖动。

Next:

- 做一轮当前会话实时收消息验证；
- 如果 unread 不再短暂上跳，就把 Phase 7 最后一项勾掉。

### 2026-04-25 15:40 +08 - Active Conversation Registration Hardened

What changed:

- 在 [`RaverChatController.swift`](</Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Messages/UIKitChat/RaverChatController.swift:162>) 的 `RaverOpenIMChatController` 中新增 `hasRegisteredActiveConversation`；
- `start()` 改为通过 `ensureActiveConversationRegistration()` 注册当前活跃会话，避免重复 `start()` 时把 store 中的活跃引用计数叠高；
- `updateContext(...)` 改为先 `releaseActiveConversationRegistration()` 再切上下文；
- `deinit` 现在只在当前 controller 确实注册过活跃会话时才释放；
- 这让上一轮新增的 active-conversation unread 保护更接近真正的引用计数语义，而不是“多数时候工作正常”的状态标记。

Build:

- Workspace build passed.

Command:

```text
xcodebuild -workspace /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17' build
```

Result:

```text
** BUILD SUCCEEDED **
```

Conclusion:

- 当前活跃会话机制现在不仅能挡 unread 抖动，也能承受 controller 生命周期里的重复 `start()` / context update；
- Phase 7 剩下的就真的是运行时观察了，不再是明显的代码层风险。

### 2026-04-25 15:48 +08 - Runtime Read/Unread Instrumentation Added

What changed:

- 在 [`RaverChatController.swift`](</Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Messages/UIKitChat/RaverChatController.swift:162>) 中继续收紧 active conversation 生命周期：
  - 增加 `hasRegisteredActiveConversation`
  - `start()` 改成只注册一次
  - `deinit` 只在确实注册过时才释放
- 在 [`OpenIMChatStore.swift`](</Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Core/OpenIMChatStore.swift:1>) 增加高信号调试日志：
  - 当前会话 suppress unread 增量时会打印 `compat preview updated ... suppressUnread=1`
  - active conversation 把 unread 清零时会打印 `active conversation zeroed unread ...`
  - conversation publisher 回流时如果 active conversation unread 被归零，会打印 `normalize active unread ...`
- 在 [`RaverChatController.swift`](</Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Messages/UIKitChat/RaverChatController.swift:547>) 的 `markConversationReadBestEffort(...)` 中补了：
  - throttled
  - success
  - failed
  三类调试日志，方便对照 unread 抑制和 read 回写的先后关系。

Build:

- Workspace build passed.

Command:

```text
xcodebuild -workspace /Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP.xcworkspace -scheme RaverMVP -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17' build
```

Result:

```text
** BUILD SUCCEEDED **
```

Conclusion:

- 这轮主要不是再加新机制，而是把运行时观测做清楚；
- 你下一轮看 Xcode 输出时，已经可以直接判断 unread 是被兼容预览层抑制、被 active conversation 归零，还是由 read API 回写追上。

### 2026-04-25 15:55 +08 - Phase 7 Runtime Validation Closed

What changed:

- 基于最新一轮 Xcode 运行日志，完成了当前会话里“自己发送消息 + 对端发送消息”的 read/unread 行为核验；
- 关键链路已经在日志中闭环：
  - 自己发送消息后 `CreateTextMessage`、`sendPreparedMessage success`、UI `renderedTail` 更新都正常；
  - 对端文本消息到达后 `publishIncomingMessage`、`realtime raw message received`、聊天页 append 与自动滚动都正常；
  - 当前活跃会话命中 `compat preview updated ... suppressUnread=1 unread=0` 与 `normalize active unread ... previousUnread=1`，说明 unread 抑制与归零保护都已生效；
  - `mark read success`、`GetTotalUnreadMsgCount ... resp: 0` 说明 read 回写也已收口；
- 同一轮日志里没有再出现此前那条 `Unable to simultaneously satisfy constraints`，说明消息 cell 气泡约束切换冲突修复已经通过实际运行验证。

Why it matters:

- 这意味着 Phase 7 最后一项不再只是“代码上看起来合理”，而是已经被真实运行日志证明没有因为 raw-first 重构而退化；
- 当前会话打开时，对端新消息即使短暂触发底层 unread 计算，也会被上层 active-conversation 保护和 read 同步及时收回，产品表现保持正确；
- 聊天页现在已经能稳定覆盖 typing / system message / read-state 三条辅助链路，而不是只剩主消息流能跑通。

Validation:

- Xcode runtime log check passed.

Observed signals:

- self-send path passed
- peer-send path passed
- active conversation unread suppression passed
- mark-read callback passed
- total unread returned to 0
- old Auto Layout constraint warning not observed

Notes:

- `CHHapticPattern ... hapticpatternlibrary.plist`、`UIKeyboardLayoutStar ...`、`Gesture: System gesture gate timed out` 仍然出现，但判断为 iOS Simulator / 系统键盘噪音，不是当前业务回归问题；
- OpenIM SDK 里的 `read info from self can be ignored` 仍有 warning，但语义上属于可忽略的 self-read 通知处理分支，不影响当前功能正确性。

Conclusion:

- Phase 7 可以正式收口；
- 目前聊天重构剩下的重点已经从 read/unread 正确性，转到 Phase 9/10 的入口补齐、残留旧链路清理与更完整的回归。

Next:

- 继续完成 Phase 9 中“失败重试入口接入新 controller”；
- 进入 Phase 10，逐步清理兼容残留和高噪音调试日志；
- 补后续图片、视频、历史分页与切会话回归。

### 2026-04-25 16:05 +08 - Retry Entry Audit Closed

What changed:

- 复查了失败重试入口从聊天页点击到 controller 的整条链路，确认当前实现已经完整接到新 controller；
- 关键调用关系已经落到新链路：
  - [`DemoAlignedChatViewController.swift`](</Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Messages/UIKitChat/DemoAlignedChatViewController.swift:811>) 在消息点击时转交 `messageActionCoordinator`；
  - [`DemoAlignedMessageActionCoordinator.swift`](</Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Messages/UIKitChat/Support/DemoAlignedMessageActionCoordinator.swift:24>) 对失败的本人消息调用 `chatController.resendFailedMessage(messageID:)`；
  - [`RaverChatController.swift`](</Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Messages/UIKitChat/RaverChatController.swift:71>) 继续把重试转发给 `RaverOpenIMChatController`；
  - [`RaverChatController.swift`](</Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Messages/UIKitChat/RaverChatController.swift:294>) 中的 `RaverOpenIMChatController.resendFailedMessage(...)` 已直接在 `rawMessages` 上找到失败消息，把状态置回 `.sending` 后重新走 `sendPreparedMessage(...)`；
- 额外搜索确认当前 `Features/Messages` 与 `Core` 范围内已经没有第二条旧 store / old controller 的失败重试入口残留。

Why it matters:

- 这说明 Phase 9 的“失败重试入口接入新 controller”实际上已经完成，只是追踪文档还没来得及勾掉；
- 失败重试现在和文本、图片、视频首发一样，都收敛在 controller-owned / raw-first 聊天链路里，没有再绕回旧 message datasource。

Validation:

- Code path audit passed.

Observed signals:

- failed bubble tap enters `DemoAlignedMessageActionCoordinator`
- resend calls `RaverChatController.resendFailedMessage(...)`
- resend resolves against `RaverOpenIMChatController.rawMessages`
- resend reuses `sendPreparedMessage(...)`
- no alternate legacy resend entry found in chat feature/core surface

Conclusion:

- Phase 9 现在只剩“状态保持为 in progress”，但失败重试这一项已经可以正式收口；
- 下一步更值得做的就是 Phase 10 的残留清理和回归，而不是继续追这条已经接通的入口。

Next:

- 开始清点并删除聊天页剩余的高噪音兼容日志；
- 继续补图片、视频、历史分页、切会话的运行回归记录。

## Progress Update Rules

后续每一轮改动都必须同步更新本文件，至少包含：

- 修改了哪个 phase 的状态；
- 勾选了哪些条目；
- 新增了哪些文件；
- 哪些风险已解除；
- 哪些风险仍在；
- 构建是否通过；
- 双机/单机验证结果如何。
