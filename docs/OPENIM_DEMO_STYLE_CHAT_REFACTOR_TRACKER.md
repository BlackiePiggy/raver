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
- [ ] 明确切换期间允许的临时兼容层

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

Status: `[~] In Progress`

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

Status: `[ ] Not Started`

目标：保留现有 UIKit chat UI，但把渲染映射后置。

- [ ] 新建 `OpenIMChatItem`
- [ ] 新建 `OpenIMMessageRenderMapper`
- [ ] 支持文本消息映射
- [ ] 支持图片消息映射
- [ ] 支持视频消息映射
- [ ] 支持系统消息映射
- [ ] 支持 sending / sent / failed 状态映射
- [ ] 确保现有 `DemoAligned*Cell` 不需要大规模重写即可接入

### Phase 4 - Initial Load And History Pagination

Status: `[~] In Progress`

目标：把历史加载迁移到 controller 自己管理。

- [x] controller 实现 initial load
- [x] controller 实现 older pagination state
- [x] controller 实现 `oldestClientMsgID`
- [x] controller 实现历史 prepend
- [x] controller 实现分页去重
- [x] controller 实现 `hasOlderMessages`
- [x] controller 实现 `isLoadingOlder`
- [ ] 验证滚动位置与加载更早消息行为

### Phase 5 - Text / Image / Video Send Path Alignment

Status: `[~] In Progress`

目标：所有发送路径都改成 demo 风格同 ID replace。

- [x] 文本发送使用 OpenIM `clientMsgID`
- [x] 图片发送使用 OpenIM `clientMsgID`
- [x] 视频发送使用 OpenIM `clientMsgID`
- [x] 发送时先 append sending
- [x] success 时 replace 为 sent
- [x] failure 时 replace 为 failed
- [ ] 删除 `local-*` placeholder 创建逻辑
- [ ] 删除 placeholder collapse 依赖

### Phase 6 - Realtime Receive / Self Echo / Retry

Status: `[~] In Progress`

目标：统一处理实时接收、自己消息回流和失败重试。

- [x] controller 绑定 raw realtime message publisher
- [x] 当前会话消息收到后 append or replace
- [x] 自己发送的消息回流按 `clientMsgID` replace
- [x] 实现 resend by same raw message flow
- [ ] 验证不会产生重复消息
- [ ] 验证 sent 不会回退为 sending

### Phase 7 - Typing / System Messages / Read State

Status: `[ ] Not Started`

目标：把聊天页相关的辅助事件也纳入新链路。

- [ ] 输入状态在 controller 中消费并驱动 UI
- [ ] 系统消息走新渲染映射
- [ ] 已读/已收相关聊天页联动迁移
- [ ] 对端消息到来后的 unread / read 状态不因重构退化

### Phase 8 - Store Contraction

Status: `[~] In Progress`

目标：缩减 `OpenIMChatStore` 到会话域职责。

- [ ] 迁出 `messagesByConversationID`
- [ ] 废弃 `messages(for:)`
- [ ] 废弃 `sendMessage(...)`
- [ ] 废弃 `sendImageMessage(...)`
- [ ] 废弃 `sendVideoMessage(...)`
- [ ] 废弃 `resendFailedMessage(...)`
- [ ] 废弃 `mergeMessage(...)`
- [ ] 废弃 `replaceMessage(...)`
- [ ] 废弃 message normalization / reconciliation 逻辑
- [ ] 保留 conversations / unreadTotal / inputStatus

### Phase 9 - Coordinator And Screen Wiring

Status: `[ ] Not Started`

目标：把聊天页入口、发送协调器、媒体发送协调器都接到新 controller。

- [ ] 文本发送 coordinator 接入新 controller
- [ ] 图片发送 coordinator 接入新 controller
- [ ] 视频发送 coordinator 接入新 controller
- [ ] 失败重试入口接入新 controller
- [ ] 会话切换与 screen lifecycle 接入新 controller

### Phase 10 - Cleanup, Removal And Regression Pass

Status: `[ ] Not Started`

目标：移除旧链路残留并做完整回归。

- [ ] 删除不再使用的中间兼容逻辑
- [ ] 删除 `publisher reconciled` 类兜底日志依赖
- [ ] 删除 `messages normalized` 类 placeholder collapse 逻辑
- [ ] 全量构建通过
- [ ] 双机文本消息回归
- [ ] 双机图片消息回归
- [ ] 双机视频消息回归
- [ ] 重试回归
- [ ] 历史分页回归
- [ ] 切会话回归

## File-Level Implementation Map

### New Files

- `/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Messages/UIKitChat/Models/OpenIMChatItem.swift`
- `/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Messages/UIKitChat/Models/OpenIMMessageRenderMapper.swift`

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

## Progress Update Rules

后续每一轮改动都必须同步更新本文件，至少包含：

- 修改了哪个 phase 的状态；
- 勾选了哪些条目；
- 新增了哪些文件；
- 哪些风险已解除；
- 哪些风险仍在；
- 构建是否通过；
- 双机/单机验证结果如何。
