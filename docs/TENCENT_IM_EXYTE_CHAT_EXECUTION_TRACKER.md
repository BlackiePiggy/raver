# Raver iOS `Exyte Chat UI + Tencent IM` 改造路线与进度记录

> 目标：保留当前 `Exyte Chat` 风格聊天界面，使用腾讯 IM 作为底层消息与会话能力，逐步把整个聊天系统跑通，并以“进度记录式”持续推进。

配套架构文档：
- [TENCENT_IM_EXYTE_CHAT_ARCHITECTURE.md](/Users/blackie/Projects/raver/docs/TENCENT_IM_EXYTE_CHAT_ARCHITECTURE.md)

---

## 1. 目标边界

### 1.1 最终目标
- 聊天页 UI 使用 `thirdparty/chat` 的 `ExyteChat`
- 会话、消息、发送、重发、已读、实时刷新能力使用腾讯 IM
- 从列表进入聊天、从他人主页发起私聊、群聊进入聊天三条主路径都能跑通
- 保持当前 Raver 导航壳，不再追求 Exyte demo 顶栏 1:1

### 1.2 本阶段不做
- 不再继续接腾讯 Chat UIKit 的页面层
- 不要求 `ChatExample` 顶层容器完全照搬
- 不先做音视频通话
- 不先做全量聊天扩展能力（如 Giphy、位置、名片、自定义卡片）

### 1.3 核心原则
- UI 层：`ExyteChat`
- IM 层：`TencentIMSession + SocialService + RaverChatController`
- 路由层：继续复用 Raver 现有 `MainTabCoordinator`
- 改造顺序：先“能跑通主链路”，再补“增强能力”
- 每一轮改造必须先对照
  [TENCENT_IM_EXYTE_CHAT_ARCHITECTURE.md](/Users/blackie/Projects/raver/docs/TENCENT_IM_EXYTE_CHAT_ARCHITECTURE.md)
  中对应 step 的“腾讯 Demo 参考文件”后再动手

---

## 2. 当前基线

### 2.1 已完成
- `ExyteChat` 已作为本地 package 接入工程
- `ExyteChat` 依赖链已全部切到本地 `thirdparty` 路径
- 当前工程已可成功构建
- 聊天入口已从腾讯 UIKit 页面壳切到 Exyte 风格页面壳
- Exyte 页面已接入现有 `RaverChatController`

### 2.2 当前技术落点
- 聊天页入口：
  - `/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Application/Coordinator/MainTabCoordinator.swift`
- Exyte 聊天页封装：
  - `/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Messages/UIKitChat/TencentUIKitChatView.swift`
- 腾讯 IM 会话与消息：
  - `/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Core/AppState.swift`
  - `/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Messages/UIKitChat/RaverChatController.swift`

### 2.3 当前已知风险
- `ExyteChat` 是通用 UI 库，不原生理解腾讯 IM 消息模型
- 回复、重发、媒体上传、消息状态需要继续适配
- Xcode 的 package UI 缓存可能偶尔与命令行状态不一致

---

## 3. 分阶段路线

## Phase 0：基建冻结与可编译基线

### 目标
- 本地依赖稳定
- 工程始终可编译
- Exyte 页面可被路由到

### 验收
- `xcodebuild` 能成功
- Xcode workspace 能成功 build
- 聊天页可打开，不崩溃

### 状态
- `Done`

---

## Phase 1：打通单聊主链路

### 目标
- 列表进入单聊
- 个人主页进入单聊
- 单聊历史消息正确展示
- 文本消息发送成功并实时回显
- 对端新消息实时出现在当前页

### 任务拆分
- [x] 统一聊天入口 route target，按腾讯 Demo 的 `userID/groupID` 目标语义进入详情页
- [x] 校准 `Conversation -> ExyteChat header` 的标题、头像、状态文案
- [x] 校准消息发送者头像与昵称映射，避免腾讯 IM 缺失字段导致显示错误
- [x] 校准 `ChatMessage -> ExyteChat.Message` 的文本消息映射
- [x] 校准文本发送链路：输入框 -> `DraftMessage` -> 腾讯 IM -> 本地回显
- [x] 校准实时消息订阅：腾讯 IM 新消息 -> 当前 Exyte 页面刷新
- [x] 校准失败发送态：failed / resend
- [x] 接入历史消息分页：详情 controller 持有 oldest cursor，service 按 cursor 加载上一页并 prepend

### 腾讯 Demo 参考文件
- 会话头与列表来源：
  [TUIConversationListDataProvider_Minimalist.swift](/Users/blackie/Projects/raver/thirdparty/Chat_UIKit-main/Swift/TUIKit/TUIConversation/UI_Minimalist/DataProvider/TUIConversationListDataProvider_Minimalist.swift)
  [ConversationController_Minimalist.swift](/Users/blackie/Projects/raver/thirdparty/Chat_UIKit-main/Swift/TUIKit/TIMAppKit/UI_Minimalist/Conversation/ConversationController_Minimalist.swift)
- 聊天详情消息流：
  [TUIBaseChatViewController_Minimalist.swift](/Users/blackie/Projects/raver/thirdparty/Chat_UIKit-main/Swift/TUIKit/TUIChat/UI_Minimalist/Chat/TUIBaseChatViewController_Minimalist.swift)
  [TUIChatDataProvider.swift](/Users/blackie/Projects/raver/thirdparty/Chat_UIKit-main/Swift/TUIKit/TUIChat/CommonModel/TUIChatDataProvider.swift)
  [TUIMessageBaseDataProvider.swift](/Users/blackie/Projects/raver/thirdparty/Chat_UIKit-main/Swift/TUIKit/TUIChat/BaseDataProvider/Base/TUIMessageBaseDataProvider.swift)

### 验收
- A 进入 B 的私聊页可以看到历史消息
- A/B 在聊天页顶部、消息气泡、引用头里看到的头像和昵称正确
- A 发送文本，A 本地立即可见
- B 在线时实时收到
- A/B 任一方停留聊天页时，不需要退回列表刷新

### 状态
- `Done`

### 最新进展
- 已统一 `ChatRouteTarget`，详情页入口按腾讯 Demo 的 `userID / groupID` 目标语义收口
- `IMChatStore` 已具备会话信息 merge 保护，不会再让空标题、空头像覆盖更完整的列表会话
- `IMChatStore` 的会话列表更新链路已收口到腾讯单路：
  - 会话预览 / 未读数 / 会话变化只吃 `TencentIMSession`
  - 不再保留“实时消息直接改列表预览”的第二条兼容写路径
- `ConversationLoaderView + TencentUIKitChatView` 已支持“更优会话对象晚到后刷新顶部信息”
- `TencentUIKitChatView` 的身份解析已和列表页优先级对齐：
  - 顶部标题/头像优先取 `conversation.peer`
  - 单聊对端消息头像/昵称优先取当前会话 peer
  - 自己发送的消息优先取当前 session user
- 会话列表预览策略已与腾讯最小化方案对齐：
  - 私聊预览不显示发送者名称
  - 群聊预览显示 `发送者名: 内容`
- `RaverChatController` 已统一历史消息、实时消息、发送回写、失败重发的 reply/mention 标准化逻辑
- 文本发送已改为腾讯式乐观发送：
  - 本地先落 `sending` 气泡
  - SDK 成功后原位回填 `sent/read`
  - 失败时保留失败气泡并支持重试
- 单聊已读状态已接回当前页实时刷新：
  - 双方停留在聊天页时，无需退回列表再进入
- 会话列表实时未读与预览刷新已接回腾讯会话监听：
  - 列表停留时收到新消息，红点与预览可即时更新
- 历史消息分页主链路已接通：
  - `RaverChatController` 持有 `oldestLoadedMessageID`
  - `LiveSocialService` 支持 `startClientMsgID + count` 的分页桥接
  - `TencentIMSession` 使用 `findMessages(messageIDList:) + getC2CHistoryMessageList/getGroupHistoryMessageList(lastMsg:)`
  - 当前 prepend 逻辑已通过构建，可继续进入双端 smoke 验证

---

## Phase 2：打通群聊主链路

### 目标
- 列表进入群聊
- 群历史消息展示
- 群文本消息发送与实时刷新

### 任务拆分
- [x] 校准 `ConversationType.group` 头部文案与头像策略
- [x] 校准群消息 sender 展示
- [x] 校准群消息实时刷新
- [x] 校准群内回复展示

### 腾讯 Demo 参考文件
- [TUIGroupChatViewController_Minimalist.swift](/Users/blackie/Projects/raver/thirdparty/Chat_UIKit-main/Swift/TUIKit/TUIChat/UI_Minimalist/Chat/TUIGroupChatViewController_Minimalist.swift)
- [TUIBaseChatViewController_Minimalist.swift](/Users/blackie/Projects/raver/thirdparty/Chat_UIKit-main/Swift/TUIKit/TUIChat/UI_Minimalist/Chat/TUIBaseChatViewController_Minimalist.swift)
- [TUIChatDataProvider.swift](/Users/blackie/Projects/raver/thirdparty/Chat_UIKit-main/Swift/TUIKit/TUIChat/CommonModel/TUIChatDataProvider.swift)

### 验收
- 群聊页能正常收发文本
- 不同发送者的消息样式与名字显示正确

### 状态
- `Done`

---

## Phase 3：补齐媒体消息能力

### 目标
- 图片
- 视频
- 语音

### 任务拆分
- [x] 图片消息：发送、缩略图、点击预览
- [x] 视频消息：发送、缩略图、点击播放
- [x] 语音消息：发送、时长、点击播放
- [x] 媒体失败重试

### 腾讯 Demo 参考文件
- [TUIBaseChatViewController_Minimalist.swift](/Users/blackie/Projects/raver/thirdparty/Chat_UIKit-main/Swift/TUIKit/TUIChat/UI_Minimalist/Chat/TUIBaseChatViewController_Minimalist.swift)
- [TUIMessageBaseDataProvider.swift](/Users/blackie/Projects/raver/thirdparty/Chat_UIKit-main/Swift/TUIKit/TUIChat/BaseDataProvider/Base/TUIMessageBaseDataProvider.swift)

### 验收
- 三类媒体消息都能成功发送与展示
- 当前页实时可见
- 失败有明确状态

### 状态
- `Done`

---

## Phase 4：补齐聊天交互能力

### 目标
- 回复
- 重发
- 已读/状态位
- 输入中状态

### 任务拆分
- [x] Exyte swipe reply 与腾讯消息 reply 元数据双向映射
- [x] failed message -> resend
- [x] 已读状态位接回腾讯 IM 数据
- [x] typing 状态接入当前页提示

### 腾讯 Demo 参考文件
- [TUIC2CChatViewController_Minimalist.swift](/Users/blackie/Projects/raver/thirdparty/Chat_UIKit-main/Swift/TUIKit/TUIChat/UI_Minimalist/Chat/TUIC2CChatViewController_Minimalist.swift)
- [TUIRepliesDetailViewController_Minimalist.swift](/Users/blackie/Projects/raver/thirdparty/Chat_UIKit-main/Swift/TUIKit/TUIChat/UI_Minimalist/Chat/TUIRepliesDetailViewController_Minimalist.swift)
- [TUIMessageBaseDataProvider.swift](/Users/blackie/Projects/raver/thirdparty/Chat_UIKit-main/Swift/TUIKit/TUIChat/BaseDataProvider/Base/TUIMessageBaseDataProvider.swift)

### 验收
- 回复消息能带引用头展示
- 失败消息可重发
- 已读状态不再丢失
- 输入中状态有稳定展示策略

### 状态
- `Done`

---

## Phase 5：补齐扩展聊天能力

### 目标
- 在保持 `ExyteChat` UI 壳的前提下，继续按腾讯 Demo 的能力边界补齐增强功能
- 所有新增能力先锁定腾讯参考文件，再开始实现，避免脱离腾讯原有数据流

### 任务拆分
- [ ] 消息撤回 / revoke
  - 自己的消息在腾讯允许时窗内，长按气泡可撤回
  - 参考文件：
    [TUIBaseChatViewController_Minimalist.swift](/Users/blackie/Projects/raver/thirdparty/Chat_UIKit-main/Swift/TUIKit/TUIChat/UI_Minimalist/Chat/TUIBaseChatViewController_Minimalist.swift)
    [TUIMessageBaseDataProvider.swift](/Users/blackie/Projects/raver/thirdparty/Chat_UIKit-main/Swift/TUIKit/TUIChat/BaseDataProvider/Base/TUIMessageBaseDataProvider.swift)
    [TUIChatExtensionObserver_Minimalist.swift](/Users/blackie/Projects/raver/thirdparty/Chat_UIKit-main/Swift/TUIKit/TUIChat/UI_Minimalist/Service/TUIChatExtensionObserver_Minimalist.swift)
- [ ] 删除消息
  - 长按气泡触发删除，区分“本地删除 / 腾讯当前能力边界”
  - 参考文件：
    [TUIBaseChatViewController_Minimalist.swift](/Users/blackie/Projects/raver/thirdparty/Chat_UIKit-main/Swift/TUIKit/TUIChat/UI_Minimalist/Chat/TUIBaseChatViewController_Minimalist.swift)
    [TUIMessageBaseDataProvider.swift](/Users/blackie/Projects/raver/thirdparty/Chat_UIKit-main/Swift/TUIKit/TUIChat/BaseDataProvider/Base/TUIMessageBaseDataProvider.swift)
- [ ] 附件入口改造
  - 输入栏左侧附件按钮改成 `+`
  - 点击后展开一个与当前主题适配的扩展面板
  - 面板首批能力：图片、视频、文件
  - 拍照入口迁移到该面板中
  - 参考文件：
    [TUIInputController_Minimalist.swift](/Users/blackie/Projects/raver/thirdparty/Chat_UIKit-main/Swift/TUIKit/TUIChat/UI_Minimalist/Input/TUIInputController_Minimalist.swift)
    [TUIBaseChatViewController_Minimalist.swift](/Users/blackie/Projects/raver/thirdparty/Chat_UIKit-main/Swift/TUIKit/TUIChat/UI_Minimalist/Chat/TUIBaseChatViewController_Minimalist.swift)
- [ ] 文件消息
  - 当前仅支持音频类文件，后续扩展为标准文件消息链路
  - 先对齐腾讯的文件消息发送、接收、展示、点击打开语义
  - 参考文件：
    [TUIMessageBaseDataProvider.swift](/Users/blackie/Projects/raver/thirdparty/Chat_UIKit-main/Swift/TUIKit/TUIChat/BaseDataProvider/Base/TUIMessageBaseDataProvider.swift)
    [TUIBaseChatViewController_Minimalist.swift](/Users/blackie/Projects/raver/thirdparty/Chat_UIKit-main/Swift/TUIKit/TUIChat/UI_Minimalist/Chat/TUIBaseChatViewController_Minimalist.swift)
- [ ] 表情包扩展
  - 表情包按钮替换当前拍照按钮
  - 表情包数据与交互方式优先参考腾讯逻辑
  - 拍照能力转移到 `+` 面板
  - 参考文件：
    [TUIInputController_Minimalist.swift](/Users/blackie/Projects/raver/thirdparty/Chat_UIKit-main/Swift/TUIKit/TUIChat/UI_Minimalist/Input/TUIInputController_Minimalist.swift)
    [TUIChatExtensionObserver_Minimalist.swift](/Users/blackie/Projects/raver/thirdparty/Chat_UIKit-main/Swift/TUIKit/TUIChat/UI_Minimalist/Service/TUIChatExtensionObserver_Minimalist.swift)
- [ ] 语音按钮位置调整
  - 语音按钮移到文字输入框最左侧
  - 保持当前 UI 主题，但交互逻辑按腾讯输入区组织方式调整
  - 参考文件：
    [TUIInputController_Minimalist.swift](/Users/blackie/Projects/raver/thirdparty/Chat_UIKit-main/Swift/TUIKit/TUIChat/UI_Minimalist/Input/TUIInputController_Minimalist.swift)
- [ ] 群管理相关扩展入口
  - 放在 header 右上角
  - 先对齐腾讯群聊页右上角能力组织，再映射到当前 Raver 页面壳
  - 参考文件：
    [TUIGroupChatViewController_Minimalist.swift](/Users/blackie/Projects/raver/thirdparty/Chat_UIKit-main/Swift/TUIKit/TUIChat/UI_Minimalist/Chat/TUIGroupChatViewController_Minimalist.swift)
    [TUIBaseChatViewController_Minimalist.swift](/Users/blackie/Projects/raver/thirdparty/Chat_UIKit-main/Swift/TUIKit/TUIChat/UI_Minimalist/Chat/TUIBaseChatViewController_Minimalist.swift)
- [ ] 消息搜索的完整聊天内体验
  - 搜索入口、搜索结果列表、点击定位回原消息
  - 参考文件：
    [TUIBaseChatViewController_Minimalist.swift](/Users/blackie/Projects/raver/thirdparty/Chat_UIKit-main/Swift/TUIKit/TUIChat/UI_Minimalist/Chat/TUIBaseChatViewController_Minimalist.swift)
    [TUIMessageController_Minimalist.swift](/Users/blackie/Projects/raver/thirdparty/Chat_UIKit-main/Swift/TUIKit/TUIChat/UI_Minimalist/Chat/TUIMessageController_Minimalist.swift)
- [ ] 会话管理能力
  - 置顶会话
  - 批量操作
  - 编辑态
  - 参考文件：
    [ConversationController_Minimalist.swift](/Users/blackie/Projects/raver/thirdparty/Chat_UIKit-main/Swift/TUIKit/TIMAppKit/UI_Minimalist/Conversation/ConversationController_Minimalist.swift)
    [TUIConversationListController_Minimalist.swift](/Users/blackie/Projects/raver/thirdparty/Chat_UIKit-main/Swift/TUIKit/TUIConversation/UI_Minimalist/UI/TUIConversationListController_Minimalist.swift)
    [TUIConversationListDataProvider_Minimalist.swift](/Users/blackie/Projects/raver/thirdparty/Chat_UIKit-main/Swift/TUIKit/TUIConversation/UI_Minimalist/DataProvider/TUIConversationListDataProvider_Minimalist.swift)
- [ ] 点击头像进入对应用户主页
  - 单聊 / 群聊中的头像点击都要能路由回 Raver 的用户主页
  - 参考文件：
    [TUIBaseChatViewController_Minimalist.swift](/Users/blackie/Projects/raver/thirdparty/Chat_UIKit-main/Swift/TUIKit/TUIChat/UI_Minimalist/Chat/TUIBaseChatViewController_Minimalist.swift)
    [TUIMessageController_Minimalist.swift](/Users/blackie/Projects/raver/thirdparty/Chat_UIKit-main/Swift/TUIKit/TUIChat/UI_Minimalist/Chat/TUIMessageController_Minimalist.swift)

### 执行限制
- 上述每个能力开始编码前，必须先打开本节列出的腾讯参考文件
- 优先复用腾讯 Demo 现有的能力边界、状态归属、事件流，不允许先自行发明交互再倒推 IM 逻辑
- 如果当前 `ExyteChat` UI 无法原样承载腾讯交互，只允许改“展示壳”，不允许改掉腾讯原有消息语义

### 验收
- 撤回、删除、搜索、会话管理、群管理入口等增强能力都有明确可回归的 smoke case
- 输入区扩展面板完成第一版：图片、视频、文件、拍照
- 表情、语音、附件入口布局与当前主题一致，但底层事件流与腾讯 Demo 对齐

### 状态
- `Planned`

---

## Phase 6：收口 UI 与稳定性

### 目标
- 保持当前 Exyte 风格
- 修掉明显与业务冲突的地方
- 完成 smoke checklist

### 任务拆分
- [ ] 顶栏信息、间距、返回行为稳定化
- [ ] 输入区与键盘联动检查
- [ ] 页面生命周期与订阅释放检查
- [ ] 聊天页 smoke checklist

### 腾讯 Demo 参考文件
- [ConversationController_Minimalist.swift](/Users/blackie/Projects/raver/thirdparty/Chat_UIKit-main/Swift/TUIKit/TIMAppKit/UI_Minimalist/Conversation/ConversationController_Minimalist.swift)
- [TUIBaseChatViewController_Minimalist.swift](/Users/blackie/Projects/raver/thirdparty/Chat_UIKit-main/Swift/TUIKit/TUIChat/UI_Minimalist/Chat/TUIBaseChatViewController_Minimalist.swift)

### 验收
- 聊天页连续进出无崩溃
- 单聊/群聊/媒体/回复各自至少过一轮 smoke

### 状态
- `NotStarted`

---

## 4. 关键映射表

### 4.1 UI 层
- `ExyteChat.Message`
  <- `ChatMessage`
- `ExyteChat.User`
  <- `UserSummary`
- `ExyteChat.Attachment`
  <- `ChatMessageMediaPayload`
- `ExyteChat.ReplyMessage`
  <- `ChatMessage.replyToMessageID + replyPreview`

### 4.2 业务控制层
- 页面 View
  -> `ExyteChatConversationViewModel`
  -> `RaverChatController`
  -> `RaverChatDataProvider`
  -> `SocialService`
  -> `TencentIMSession`

### 4.3 主链路
1. 路由拿到 `Conversation`
2. 聊天页创建 `ExyteChatConversationViewModel`
3. `RaverChatController.start()`
4. 拉取历史消息
5. `ChatMessage` 映射为 `ExyteChat.Message`
6. 用户发送 `DraftMessage`
7. 转成腾讯 IM 发送动作
8. 回包或实时消息刷新当前页

---

## 5. 验收清单

### 5.1 单聊
- [x] 会话列表进入单聊正常
- [x] 主页进入单聊正常
- [x] 历史消息加载正常
- [x] 文本消息发送正常
- [x] 新消息实时刷新正常

### 5.2 群聊
- [x] 群聊进入正常
- [x] 群文本消息正常
- [x] 多发送者显示正常

### 5.3 媒体
- [x] 图片发送正常
- [x] 视频发送正常
- [x] 语音发送正常

### 5.4 交互
- [x] 回复正常
- [x] 重发正常
- [x] 已读状态正常
- [x] 输入中状态正常

---

## 6. 进度记录

## 2026-04-29

### 已完成
- 接入本地 `ExyteChat` package
- 将 `MediaPicker / ActivityIndicatorView / AnchoredPopup / GiphyUISDK / libwebp / Kingfisher` 切到本地依赖
- 修复 `ExyteChat` 与本地 `ActivityIndicatorView` 的一个 API 兼容问题
- 完成可编译基线，`xcodebuild` 已成功
- 聊天入口切到 Exyte 风格聊天页
- 输出“严格参照腾讯 Demo 架构，但保留 Exyte UI”的独立架构方案文档

### 进行中
- Phase 5 规划：扩展聊天能力补齐

### 本轮已落地
- 顶部导航头像不再依赖远程头像存在，缺图时仍会正常显示标题与状态
- 聊天气泡头像映射改为优先使用当前登录用户 / 当前会话 peer / 消息 sender 三层身份信息
- 当腾讯 IM 缺失头像地址时，聊天页开始回退到 Raver 现有本地用户头像与群头像策略
- 引用消息头部的头像与昵称也已切到同一套兜底逻辑
- 改造后工程重新构建通过，`xcodebuild` 结果为 `BUILD SUCCEEDED`
- 已新增
  [ChatRouteTarget.swift](/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Messages/ChatRuntime/ChatRouteTarget.swift)
  作为统一聊天目标模型
- 已将
  [MainTabCoordinator.swift](/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Application/Coordinator/MainTabCoordinator.swift)
  的聊天路由改为 `.conversation(target:)`
- 已将消息列表、用户主页私聊、小队入口统一改为产出 `ChatRouteTarget`
- 已将 `ConversationLoaderView` 改为优先按 `preferredConversationID + kind(userID/groupID)` 解析会话
- 路由改造后再次全量构建通过，`xcodebuild` 结果仍为 `BUILD SUCCEEDED`
- 已对
  [IMChatStore.swift](/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Core/IMChatStore.swift)
  补充 direct 会话的 `peer.id / peer.username` 匹配能力
- 已将 `stageConversation` 与 SDK 会话回调统一接入“完整身份信息优先”的 merge 规则，避免空标题/空头像覆盖更完整数据
- Store 改造后再次全量构建通过，`xcodebuild` 结果仍为 `BUILD SUCCEEDED`
- 已将
  [ConversationLoaderView](/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Application/Coordinator/MainTabCoordinator.swift)
  改为在 `IMChatStore` 会话更新时持续尝试采用更优版本，而不是只在首次解析时取值
- 已将
  [TencentUIKitChatView.swift](/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Messages/UIKitChat/TencentUIKitChatView.swift)
  补成可响应父层 `Conversation` 更新，详情页顶部标题/头像会跟随更完整会话信息刷新
- 详情页会话刷新链路改造后再次全量构建通过，`xcodebuild` 结果仍为 `BUILD SUCCEEDED`
- 已对
  [RaverChatController.swift](/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Messages/UIKitChat/RaverChatController.swift)
  统一文本消息标准化链路，历史消息、实时消息、发送回写都走同一套 reply/mention 解析规则
- 已补齐失败消息重发后的本地状态回写，避免 controller 只返回结果却不更新当前消息列表
- controller 状态流改造后再次全量构建通过，`xcodebuild` 结果仍为 `BUILD SUCCEEDED`
- 已将会话列表的会话变化 / 未读数 / 预览刷新收口到腾讯单路：
  - `IMChatStore` 不再同时监听旧 `IMSession` 的列表级消息、会话、未读流
  - 会话列表以 `TencentIMSession` 的 `onNewConversation / onConversationChanged / onTotalUnreadMessageCountChanged` 为准
- 已修正会话列表预览文案策略：
  - 私聊不再显示发送者名
  - 群聊保留 `发送者名: 内容`
- 已补齐单聊已读实时链路，当前聊天页内即可收到已读状态刷新
- 已将文本发送改成腾讯 Demo 一致的乐观发送体验，减少等待 SDK 成功后才出气泡的延迟感
- 最近一次全量构建结果仍为 `BUILD SUCCEEDED`
- Phase 1 双端 smoke 已通过：
  - 私聊历史消息分页通过
  - 私聊顶部头像/名称通过
  - 文本发送、失败重发通过
  - 当前页已读实时刷新通过
  - 会话列表红点和预览实时刷新通过
- Phase 2 双端 smoke 已通过：
  - 群聊进入与历史展示通过
  - 群文本消息发送与实时刷新通过
  - 多发送者名字与样式展示通过
  - 群内回复展示通过

### 当前进行中
- Phase 3：媒体消息能力补齐

### 下一步
- 严格对照
  [TUIBaseChatViewController_Minimalist.swift](/Users/blackie/Projects/raver/thirdparty/Chat_UIKit-main/Swift/TUIKit/TUIChat/UI_Minimalist/Chat/TUIBaseChatViewController_Minimalist.swift)
  与
  [TUIMessageBaseDataProvider.swift](/Users/blackie/Projects/raver/thirdparty/Chat_UIKit-main/Swift/TUIKit/TUIChat/BaseDataProvider/Base/TUIMessageBaseDataProvider.swift)
  开始补图片/视频/语音消息
- 优先顺序：
  - 图片发送、缩略图、点击预览
  - 视频发送、缩略图、点击播放
  - 语音发送、时长、点击播放
- 验证是否仍存在“列表正确但详情页拿到另一份残缺会话”的情况
- 校准文本消息历史展示
- 校准文本发送与实时刷新
- 开始接消息历史分页，向腾讯 `TUIMessageBaseDataProvider` 的历史加载方式靠拢

### 风险备注
- 当前“可编译”不等于“所有聊天能力已跑通”
- 后续重点在消息映射与实时链路，而不是依赖工程问题

---

## 7. 执行约定

- 每完成一个明确节点，都更新本文：
  - `状态`
  - `已完成`
  - `下一步`
  - `风险备注`
- 优先保证：
  - 工程始终可编译
  - 单聊主链路先稳定
  - 再向群聊和媒体扩展
