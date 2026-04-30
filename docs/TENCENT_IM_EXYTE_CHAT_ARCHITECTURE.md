# Raver iOS `Exyte UI + 腾讯 IM Demo 架构` 设计方案

> 目标：严格参照腾讯 IM Demo 的架构思路与操作逻辑，在保留当前 `ExyteChat` 页面表现的前提下，实现一套在行为上与腾讯 Demo 一致的聊天系统。

---

## 1. 设计目标

### 1.1 要对齐的不是页面，而是架构
- 页面表现：继续使用当前 `ExyteChat`
- 会话逻辑：对齐腾讯 Demo 的会话列表数据流
- 聊天逻辑：对齐腾讯 Demo 的聊天详情页数据流
- 路由逻辑：对齐腾讯 Demo 的“列表 -> 详情 -> SDK 实时同步”工作方式

### 1.2 最终效果要求
- 聊天列表与聊天详情页使用同一套会话真相源
- 聊天详情页顶部信息、消息身份信息、消息状态与腾讯 IM 状态同步
- 文本、图片、视频、语音、回复、重发、已读、输入中等能力在交互上与腾讯 Demo 一致
- 现有 `Raver` 路由体系、页面壳、视觉风格保留

### 1.3 设计原则
- `UI` 与 `IM 逻辑` 分离
- `Conversation` 与 `Message` 分离
- `列表状态` 与 `详情状态` 分离
- `实时事件` 统一先进入 Store/Controller，再分发给页面
- 页面不直接依赖腾讯 SDK 对象

### 1.4 严格参考规则
- 后续每一步改造都必须先对照腾讯 Demo 对应文件，再动我们自己的代码
- 优先参考“同层职责”的腾讯文件，禁止跨层抄逻辑
- 如果某个能力在腾讯 Demo 中分散在多个文件里，必须先列出主参考文件和次参考文件，再开始改造
- 如果我们的实现和腾讯 Demo 做法不一致，默认以腾讯 Demo 的数据流和状态归属为准，除非文档里明确记录偏离原因

---

## 1.5 腾讯 Demo 核心参考文件总表

## 会话列表
- 页面壳：
  [ConversationController_Minimalist.swift](/Users/blackie/Projects/raver/thirdparty/Chat_UIKit-main/Swift/TUIKit/TIMAppKit/UI_Minimalist/Conversation/ConversationController_Minimalist.swift)
- 列表控制器：
  [TUIConversationListController_Minimalist.swift](/Users/blackie/Projects/raver/thirdparty/Chat_UIKit-main/Swift/TUIKit/TUIConversation/UI_Minimalist/UI/TUIConversationListController_Minimalist.swift)
- 会话 provider：
  [TUIConversationListDataProvider_Minimalist.swift](/Users/blackie/Projects/raver/thirdparty/Chat_UIKit-main/Swift/TUIKit/TUIConversation/UI_Minimalist/DataProvider/TUIConversationListDataProvider_Minimalist.swift)
- 会话 cell：
  [TUIConversationCell_Minimalist.swift](/Users/blackie/Projects/raver/thirdparty/Chat_UIKit-main/Swift/TUIKit/TUIConversation/UI_Minimalist/Cell/CellUI/TUIConversationCell_Minimalist.swift)

## 聊天详情
- 单聊入口：
  [TUIC2CChatViewController_Minimalist.swift](/Users/blackie/Projects/raver/thirdparty/Chat_UIKit-main/Swift/TUIKit/TUIChat/UI_Minimalist/Chat/TUIC2CChatViewController_Minimalist.swift)
- 群聊入口：
  [TUIGroupChatViewController_Minimalist.swift](/Users/blackie/Projects/raver/thirdparty/Chat_UIKit-main/Swift/TUIKit/TUIChat/UI_Minimalist/Chat/TUIGroupChatViewController_Minimalist.swift)
- 通用聊天基类：
  [TUIBaseChatViewController_Minimalist.swift](/Users/blackie/Projects/raver/thirdparty/Chat_UIKit-main/Swift/TUIKit/TUIChat/UI_Minimalist/Chat/TUIBaseChatViewController_Minimalist.swift)
- 消息列表控制器：
  [TUIMessageController_Minimalist.swift](/Users/blackie/Projects/raver/thirdparty/Chat_UIKit-main/Swift/TUIKit/TUIChat/UI_Minimalist/Chat/TUIMessageController_Minimalist.swift)
- 消息基类控制器：
  [TUIBaseMessageController_Minimalist.swift](/Users/blackie/Projects/raver/thirdparty/Chat_UIKit-main/Swift/TUIKit/TUIChat/UI_Minimalist/Chat/TUIBaseMessageController_Minimalist.swift)
- 输入区控制器：
  [TUIInputController_Minimalist.swift](/Users/blackie/Projects/raver/thirdparty/Chat_UIKit-main/Swift/TUIKit/TUIChat/UI_Minimalist/Input/TUIInputController_Minimalist.swift)
- 聊天 provider / 基础消息 provider：
  [TUIChatDataProvider.swift](/Users/blackie/Projects/raver/thirdparty/Chat_UIKit-main/Swift/TUIKit/TUIChat/CommonModel/TUIChatDataProvider.swift)
  [TUIMessageBaseDataProvider.swift](/Users/blackie/Projects/raver/thirdparty/Chat_UIKit-main/Swift/TUIKit/TUIChat/BaseDataProvider/Base/TUIMessageBaseDataProvider.swift)
- 会话模型：
  [TUIChatConversationModel.swift](/Users/blackie/Projects/raver/thirdparty/Chat_UIKit-main/Swift/TUIKit/TUIChat/CommonModel/TUIChatConversationModel.swift)

## 回复与扩展行为
- 回复详情：
  [TUIRepliesDetailViewController_Minimalist.swift](/Users/blackie/Projects/raver/thirdparty/Chat_UIKit-main/Swift/TUIKit/TUIChat/UI_Minimalist/Chat/TUIRepliesDetailViewController_Minimalist.swift)
- 聊天扩展观察器：
  [TUIChatExtensionObserver_Minimalist.swift](/Users/blackie/Projects/raver/thirdparty/Chat_UIKit-main/Swift/TUIKit/TUIChat/UI_Minimalist/Service/TUIChatExtensionObserver_Minimalist.swift)

---

## 2. 腾讯 Demo 架构要点

## 2.1 聊天列表

腾讯 Demo 的简约版聊天列表，核心分为三层：

1. 外层页面壳
- `ConversationController_Minimalist`
- 负责导航栏、编辑态、更多菜单、页面跳转

2. 列表页面控制器
- `TUIConversationListController_Minimalist`
- 负责 `UITableView`、cell 渲染、交互事件

3. 数据提供者
- `TUIConversationListDataProvider_Minimalist`
- 负责会话拉取、分页、排序、置顶、未读、删除、草稿等

也就是说，腾讯 Demo 的列表页不是“页面自己请求 + 页面自己拼状态”，而是：

`Page Shell -> List Controller -> Conversation Data Provider -> SDK`

## 2.2 聊天详情

腾讯 Demo 的简约版聊天详情，核心分为三层：

1. 外层聊天控制器
- `TUIC2CChatViewController_Minimalist`
- `TUIGroupChatViewController_Minimalist`

2. 通用聊天基类
- `TUIBaseChatViewController_Minimalist`
- 负责顶部栏、消息列表、输入区、媒体、回复、已读、键盘联动、生命周期

3. 数据提供者
- `TUIChatDataProvider`
- 负责消息拉取、实时消息、状态变化、发送与接收

也就是说，腾讯 Demo 的详情页不是“消息列表 view 自己订阅 SDK”，而是：

`Chat VC -> Chat Data Provider -> SDK`

## 2.3 列表跳详情

腾讯 Demo 不是把完整会话对象直接传给聊天页长期使用，而是：

1. 列表点击某会话
2. 传入 `userID` 或 `groupID`
3. 聊天详情页内部再通过 provider 补齐 title、faceUrl、messages、typing、read 状态

这意味着它天然具备：
- 列表和详情的会话身份可以统一
- 聊天详情页有自己的详情状态源
- 页面销毁后重新进入也不会丢逻辑

---

## 3. 我们自己的对应架构

## 3.1 总体分层

我们要做成下面这 5 层：

1. `Route Layer`
- 负责从列表、用户主页、小队主页进入聊天

2. `Conversation Store Layer`
- 负责聊天列表、会话标题、会话头像、未读、最后一条消息

3. `Chat Controller Layer`
- 负责聊天详情的消息流、发送链路、回复态、已读态、输入中态

4. `UI Mapping Layer`
- 负责把内部 `Conversation/ChatMessage` 映射成 `ExyteChat`

5. `SDK Adapter Layer`
- 负责所有腾讯 IM SDK 调用与事件监听

---

## 4. 各层职责与当前文件映射

## 4.1 Route Layer

### 目标
- 仿照腾讯 Demo 的进入方式，统一聊天目标
- 所有入口在进入聊天页前先把“当前已知最完整的会话信息”暂存

### 当前对应文件
- [MainTabCoordinator.swift](/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Application/Coordinator/MainTabCoordinator.swift)
- [MessagesHomeView.swift](/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Messages/MessagesHomeView.swift)
- [UserProfileView.swift](/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Profile/UserProfileView.swift)
- [SquadProfileView.swift](/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Squads/SquadProfileView.swift)

### 最终职责
- 输入：
  - `conversationID`
  - `sdkConversationID`
  - `userID`
  - `groupID`
- 输出：
  - 统一后的 `ChatRouteTarget`

### 建议新增模型
```swift
struct ChatRouteTarget: Hashable {
    enum Kind {
        case direct(userID: String)
        case group(groupID: String)
    }

    let kind: Kind
    let preferredConversationID: String?
    let stagedConversation: Conversation?
}
```

### 设计要求
- 路由层不直接决定聊天详情页显示什么名字头像
- 只负责告诉详情页“我要打开哪个聊天对象”
- 如果手里有一份更完整的 `Conversation`，先暂存到 `IMChatStore`

---

## 4.2 Conversation Store Layer

### 对标腾讯 Demo
- 对标 `TUIConversationListDataProvider_Minimalist`

### 主参考文件
- [TUIConversationListDataProvider_Minimalist.swift](/Users/blackie/Projects/raver/thirdparty/Chat_UIKit-main/Swift/TUIKit/TUIConversation/UI_Minimalist/DataProvider/TUIConversationListDataProvider_Minimalist.swift)

### 次参考文件
- [TUIConversationListController_Minimalist.swift](/Users/blackie/Projects/raver/thirdparty/Chat_UIKit-main/Swift/TUIKit/TUIConversation/UI_Minimalist/UI/TUIConversationListController_Minimalist.swift)
- [ConversationController_Minimalist.swift](/Users/blackie/Projects/raver/thirdparty/Chat_UIKit-main/Swift/TUIKit/TIMAppKit/UI_Minimalist/Conversation/ConversationController_Minimalist.swift)

### 当前对应文件
- [IMChatStore.swift](/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Core/IMChatStore.swift)

### 这层应该成为
- 聊天列表唯一真相源
- 聊天页顶部会话信息的共享真相源

### 它应该管理的状态
- 会话列表
- 会话标题
- 会话头像
- peer 信息
- 会话最后消息
- 未读数
- 输入中状态
- 搜索索引
- 临时 staged conversation

### 关键设计要求
1. 不允许“更差的会话信息”覆盖“更完整的会话信息”
2. 列表页和聊天页顶部必须共用同一份 `Conversation`
3. 任何腾讯 IM 会话更新事件，都先 merge 到这里
4. 用户主页私聊、小队进入聊天时产生的会话，也先 merge 到这里

### 后续建议补充能力
- conversation completeness scoring 正式抽成工具方法
- staged conversation 记录来源与过期策略
- direct/group route target 到 conversation 的解析缓存

---

## 4.3 Chat Controller Layer

### 对标腾讯 Demo
- 对标 `TUIChatDataProvider + TUIBaseChatViewController_Minimalist` 内部消息控制逻辑

### 主参考文件
- [TUIBaseChatViewController_Minimalist.swift](/Users/blackie/Projects/raver/thirdparty/Chat_UIKit-main/Swift/TUIKit/TUIChat/UI_Minimalist/Chat/TUIBaseChatViewController_Minimalist.swift)
- [TUIChatDataProvider.swift](/Users/blackie/Projects/raver/thirdparty/Chat_UIKit-main/Swift/TUIKit/TUIChat/CommonModel/TUIChatDataProvider.swift)
- [TUIMessageBaseDataProvider.swift](/Users/blackie/Projects/raver/thirdparty/Chat_UIKit-main/Swift/TUIKit/TUIChat/BaseDataProvider/Base/TUIMessageBaseDataProvider.swift)

### 次参考文件
- [TUIC2CChatViewController_Minimalist.swift](/Users/blackie/Projects/raver/thirdparty/Chat_UIKit-main/Swift/TUIKit/TUIChat/UI_Minimalist/Chat/TUIC2CChatViewController_Minimalist.swift)
- [TUIGroupChatViewController_Minimalist.swift](/Users/blackie/Projects/raver/thirdparty/Chat_UIKit-main/Swift/TUIKit/TUIChat/UI_Minimalist/Chat/TUIGroupChatViewController_Minimalist.swift)
- [TUIMessageController_Minimalist.swift](/Users/blackie/Projects/raver/thirdparty/Chat_UIKit-main/Swift/TUIKit/TUIChat/UI_Minimalist/Chat/TUIMessageController_Minimalist.swift)
- [TUIBaseMessageController_Minimalist.swift](/Users/blackie/Projects/raver/thirdparty/Chat_UIKit-main/Swift/TUIKit/TUIChat/UI_Minimalist/Chat/TUIBaseMessageController_Minimalist.swift)
- [TUIInputController_Minimalist.swift](/Users/blackie/Projects/raver/thirdparty/Chat_UIKit-main/Swift/TUIKit/TUIChat/UI_Minimalist/Input/TUIInputController_Minimalist.swift)

### 当前对应文件
- [RaverChatController.swift](/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Messages/UIKitChat/RaverChatController.swift)
- [RaverChatDataProvider.swift](/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Messages/UIKitChat/RaverChatDataProvider.swift)
- [LiveSocialService.swift](/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Core/LiveSocialService.swift)
- [AppState.swift](/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Core/AppState.swift)

### 它应该成为
- 聊天详情唯一真相源

### 这层应该管理的状态
- 当前聊天消息列表
- 初始加载状态
- 加载更多状态
- 历史分页 cursor
- reply draft
- voice playing state
- failed message state
- typing status
- read state
- scroll / locate target

### 关键设计要求
1. 页面不直接订阅 `TencentIMSession.messagePublisher`
2. 页面只订阅 `RaverChatController`
3. `RaverChatController` 内部统一处理：
   - 首次历史拉取
   - 历史消息分页 prepend
   - 实时消息合并
   - 本地发送回显
   - 失败消息替换
   - 回复元数据恢复
   - 已读状态更新
4. `RaverChatController` 必须可根据 route target 重新初始化上下文

### 当前已落地的腾讯对齐点
- 历史消息加载已开始对齐腾讯 `TUIMessageBaseDataProvider.lastMsg` 语义
- 我们当前的锚点 cursor 采用 `ChatMessage.id == V2TIMMessage.msgID`
- live 腾讯链路通过 `findMessages(messageIDList:)` 反查锚点消息，再传给
  `getC2CHistoryMessageList(... lastMsg:) / getGroupHistoryMessageList(... lastMsg:)`
- 这和腾讯 Demo 的 provider 持有上一页锚点、继续向前翻页的方式一致

### 建议的最终接口
```swift
@MainActor
protocol ChatRuntimeController: ObservableObject {
    var messages: [ChatMessage] { get }
    var headerConversation: Conversation? { get }
    var latestInputStatus: IMInputStatusEvent? { get }

    func start()
    func stop()
    func reload() async
    func loadOlderMessagesIfNeeded() async

    func sendTextMessage(_ text: String) async throws -> ChatMessage
    func sendImageMessage(fileURL: URL) async throws -> ChatMessage
    func sendVideoMessage(fileURL: URL) async throws -> ChatMessage
    func sendVoiceMessage(fileURL: URL) async throws -> ChatMessage

    func toggleReplyDraft(for messageID: String)
    func resendFailedMessage(messageID: String) async throws -> ChatMessage
}
```

---

## 4.4 UI Mapping Layer

### 对标腾讯 Demo
- 对标腾讯聊天页内部的 cellData -> UI 过程
- 这里只是把我们的内部状态适配给 `ExyteChat`

### 主参考文件
- [TUIBaseChatViewController_Minimalist.swift](/Users/blackie/Projects/raver/thirdparty/Chat_UIKit-main/Swift/TUIKit/TUIChat/UI_Minimalist/Chat/TUIBaseChatViewController_Minimalist.swift)
- [TUIMessageController_Minimalist.swift](/Users/blackie/Projects/raver/thirdparty/Chat_UIKit-main/Swift/TUIKit/TUIChat/UI_Minimalist/Chat/TUIMessageController_Minimalist.swift)

### 次参考文件
- [TUIConversationCell_Minimalist.swift](/Users/blackie/Projects/raver/thirdparty/Chat_UIKit-main/Swift/TUIKit/TUIConversation/UI_Minimalist/Cell/CellUI/TUIConversationCell_Minimalist.swift)

### 当前对应文件
- [TencentUIKitChatView.swift](/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Messages/UIKitChat/TencentUIKitChatView.swift)

### 它应该承担的职责
- `Conversation -> header avatar/title/status`
- `ChatMessage -> ExyteChat.Message`
- `UserSummary -> ExyteChat.User`
- `ChatMessageMediaPayload -> ExyteChat.Attachment`
- `reply metadata -> ExyteChat.ReplyMessage`

### 关键设计要求
1. 这层不能再自己做“聊天业务决策”
- 不负责实时订阅 SDK
- 不负责消息去重
- 不负责会话合并

2. 这层只做两件事
- 展示
- UI 回调转发给 `RaverChatController`

3. 顶部信息必须来自共享会话真相源
- 不允许顶部标题靠消息 sender 反推

4. 消息身份必须来自 controller 归一化后的消息
- 不允许 UI 层再自己猜谁是当前用户/对端用户

---

## 4.5 SDK Adapter Layer

### 对标腾讯 Demo
- 对标腾讯内部 provider 最底部的 SDK 调用层

### 主参考文件
- [TUIConversationListDataProvider_Minimalist.swift](/Users/blackie/Projects/raver/thirdparty/Chat_UIKit-main/Swift/TUIKit/TUIConversation/UI_Minimalist/DataProvider/TUIConversationListDataProvider_Minimalist.swift)
- [TUIChatDataProvider.swift](/Users/blackie/Projects/raver/thirdparty/Chat_UIKit-main/Swift/TUIKit/TUIChat/CommonModel/TUIChatDataProvider.swift)
- [TUIMessageBaseDataProvider.swift](/Users/blackie/Projects/raver/thirdparty/Chat_UIKit-main/Swift/TUIKit/TUIChat/BaseDataProvider/Base/TUIMessageBaseDataProvider.swift)

### 当前对应文件
- [AppState.swift](/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Core/AppState.swift)
- [IMSession.swift](/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Core/IMSession.swift)
- 当前实际在用的腾讯实现类 `TencentIMSession`

### 它应该承担的职责
- fetch conversations
- fetch messages
- send text/image/video/voice
- realtime message listener
- realtime conversation listener
- read receipt updates
- typing status updates
- mute / clear history

### 关键设计要求
1. 统一出口，不让 UI 直接碰腾讯 SDK
2. 输出统一的业务模型：
- `Conversation`
- `ChatMessage`
- `IMInputStatusEvent`
3. 所有腾讯 SDK 字段缺失都在这一层做第一次归一化

---

## 5. 与腾讯 Demo 严格对齐的行为清单

以下行为要作为“必须对齐”的标准：

## 5.1 列表 -> 详情
- 点列表项进入详情页
- 列表和详情顶部看到同一份会话标题与头像
- 已读后列表未读立刻清零

## 5.2 历史消息加载
- 进入页先显示已有历史
- 消息顺序稳定
- 不重复、不闪烁

## 5.3 文本发送
- 发送后本地立刻出现
- 失败可转为失败态
- 成功后状态切 sent/read

## 5.4 实时新消息
- 当前页停留时实时插入
- 不用退回列表再进来
- 如果是当前会话，同时更新详情与列表 preview

## 5.5 回复
- 划动回复
- 发送时带 reply 元数据
- 详情页可恢复 reply 头

## 5.6 媒体
- 图片
- 视频
- 语音
- 失败态与重发

## 5.7 输入中
- 单聊输入时发送 typing
- 对端输入时当前页展示 typing 状态

## 5.8 已读
- 自己消息状态从 sending -> sent -> read
- 单聊已读与群聊状态展示策略分开

---

## 6. 改造顺序

## Step 1：统一 route target
- 新建 `ChatRouteTarget`
- 所有聊天入口统一产出 target
- 进入聊天前把完整会话 stage 到 `IMChatStore`

### 腾讯 Demo 参考文件
- 主参考：
  [ConversationController_Minimalist.swift](/Users/blackie/Projects/raver/thirdparty/Chat_UIKit-main/Swift/TUIKit/TIMAppKit/UI_Minimalist/Conversation/ConversationController_Minimalist.swift)
- 次参考：
  [TUIChatConversationModel.swift](/Users/blackie/Projects/raver/thirdparty/Chat_UIKit-main/Swift/TUIKit/TUIChat/CommonModel/TUIChatConversationModel.swift)

### 对齐点
- 参考腾讯从列表点击后，只向详情页传 `userID/groupID` 的思想
- 我们可以保留 `stagedConversation` 作为优化，但它不能替代 route target 本身
- 禁止继续把“任意一份临时 `Conversation`”直接当成详情页长期真相源

### 当前落地状态
- `Done`
- 已新增
  [/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Messages/ChatRuntime/ChatRouteTarget.swift](/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Messages/ChatRuntime/ChatRouteTarget.swift)
- 已将列表入口、用户主页私聊入口、小队入口统一改为产出 `ChatRouteTarget`
- 已将
  [ConversationLoaderView](/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Application/Coordinator/MainTabCoordinator.swift:292)
  改为优先基于 `preferredConversationID + kind(userID/groupID)` 解析聊天目标
- 已通过 `xcodebuild` 编译验证

## Step 2：Conversation Store 对齐腾讯列表 provider 语义
- 让 `IMChatStore` 成为列表唯一真相源
- 完成 merge / completeness / staging 规则
- 列表页只读 `IMChatStore`

### 腾讯 Demo 参考文件
- 主参考：
  [TUIConversationListDataProvider_Minimalist.swift](/Users/blackie/Projects/raver/thirdparty/Chat_UIKit-main/Swift/TUIKit/TUIConversation/UI_Minimalist/DataProvider/TUIConversationListDataProvider_Minimalist.swift)
- 次参考：
  [TUIConversationListController_Minimalist.swift](/Users/blackie/Projects/raver/thirdparty/Chat_UIKit-main/Swift/TUIKit/TUIConversation/UI_Minimalist/UI/TUIConversationListController_Minimalist.swift)
  [TUIConversationCell_Minimalist.swift](/Users/blackie/Projects/raver/thirdparty/Chat_UIKit-main/Swift/TUIKit/TUIConversation/UI_Minimalist/Cell/CellUI/TUIConversationCell_Minimalist.swift)

### 对齐点
- 会话排序、未读、标题、头像都应先收敛到 Store
- 列表页只负责消费 Store，不自行拼会话身份
- 禁止在列表 UI 层修修补补会话标题与头像

### 当前落地状态
- `InProgress`
- 下一步将严格对照
  [TUIConversationListDataProvider_Minimalist.swift](/Users/blackie/Projects/raver/thirdparty/Chat_UIKit-main/Swift/TUIKit/TUIConversation/UI_Minimalist/DataProvider/TUIConversationListDataProvider_Minimalist.swift)
  收口以下能力：
- 会话 merge 的完整度优先级
- route target 到 conversation 的稳定解析
- 列表与聊天详情顶部共用同一份会话真相源

## Step 3：RaverChatController 对齐腾讯 chat provider 语义
- 历史消息加载
- 实时消息 merge
- 文本发送
- 失败重发
- reply draft

### 腾讯 Demo 参考文件
- 主参考：
  [TUIBaseChatViewController_Minimalist.swift](/Users/blackie/Projects/raver/thirdparty/Chat_UIKit-main/Swift/TUIKit/TUIChat/UI_Minimalist/Chat/TUIBaseChatViewController_Minimalist.swift)
  [TUIChatDataProvider.swift](/Users/blackie/Projects/raver/thirdparty/Chat_UIKit-main/Swift/TUIKit/TUIChat/CommonModel/TUIChatDataProvider.swift)
  [TUIMessageBaseDataProvider.swift](/Users/blackie/Projects/raver/thirdparty/Chat_UIKit-main/Swift/TUIKit/TUIChat/BaseDataProvider/Base/TUIMessageBaseDataProvider.swift)
- 次参考：
  [TUIC2CChatViewController_Minimalist.swift](/Users/blackie/Projects/raver/thirdparty/Chat_UIKit-main/Swift/TUIKit/TUIChat/UI_Minimalist/Chat/TUIC2CChatViewController_Minimalist.swift)
  [TUIGroupChatViewController_Minimalist.swift](/Users/blackie/Projects/raver/thirdparty/Chat_UIKit-main/Swift/TUIKit/TUIChat/UI_Minimalist/Chat/TUIGroupChatViewController_Minimalist.swift)

### 对齐点
- 聊天详情状态必须像腾讯那样集中在 controller/provider，而不是散落在 view
- 历史消息、实时消息、发送态、失败态都必须先进入 controller，再分发给 UI
- 禁止让 `ExyteChat` 页面直接订阅 SDK 或自行合并消息

## Step 4：Exyte UI 彻底退化为映射层
- `TencentUIKitChatView` 不再直接承担业务状态
- 只读 controller 输出
- 只把 UI 事件转发回 controller

### 腾讯 Demo 参考文件
- 主参考：
  [TUIBaseChatViewController_Minimalist.swift](/Users/blackie/Projects/raver/thirdparty/Chat_UIKit-main/Swift/TUIKit/TUIChat/UI_Minimalist/Chat/TUIBaseChatViewController_Minimalist.swift)
  [TUIMessageController_Minimalist.swift](/Users/blackie/Projects/raver/thirdparty/Chat_UIKit-main/Swift/TUIKit/TUIChat/UI_Minimalist/Chat/TUIMessageController_Minimalist.swift)
- 次参考：
  [TUIInputController_Minimalist.swift](/Users/blackie/Projects/raver/thirdparty/Chat_UIKit-main/Swift/TUIKit/TUIChat/UI_Minimalist/Input/TUIInputController_Minimalist.swift)

### 对齐点
- UI 只负责“展示 controller 当前状态”和“把用户操作回传给 controller”
- 顶部标题、头像、状态不在 UI 层自行推断
- 禁止 UI 层再出现业务级 merge / fetch / reconcile 逻辑

## Step 5：补齐媒体 / typing / read
- 图片
- 视频
- 语音
- typing
- read

### 腾讯 Demo 参考文件
- 主参考：
  [TUIBaseChatViewController_Minimalist.swift](/Users/blackie/Projects/raver/thirdparty/Chat_UIKit-main/Swift/TUIKit/TUIChat/UI_Minimalist/Chat/TUIBaseChatViewController_Minimalist.swift)
  [TUIC2CChatViewController_Minimalist.swift](/Users/blackie/Projects/raver/thirdparty/Chat_UIKit-main/Swift/TUIKit/TUIChat/UI_Minimalist/Chat/TUIC2CChatViewController_Minimalist.swift)
  [TUIMessageBaseDataProvider.swift](/Users/blackie/Projects/raver/thirdparty/Chat_UIKit-main/Swift/TUIKit/TUIChat/BaseDataProvider/Base/TUIMessageBaseDataProvider.swift)
- 次参考：
  [TUIRepliesDetailViewController_Minimalist.swift](/Users/blackie/Projects/raver/thirdparty/Chat_UIKit-main/Swift/TUIKit/TUIChat/UI_Minimalist/Chat/TUIRepliesDetailViewController_Minimalist.swift)

### 对齐点
- typing 逻辑优先参考单聊 VC 的处理方式
- read / resend / media 发送链路优先参考 provider 层
- reply 行为优先参考 replies detail 和 message provider 的消息定位方式

---

## 7. 当前项目建议落地文件

## 7.1 建议新增
- `/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Messages/ChatRuntime/ChatRouteTarget.swift`
- `/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Messages/ChatRuntime/ChatConversationIdentityResolver.swift`
- `/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Messages/ChatRuntime/ChatConversationMergePolicy.swift`
- `/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Messages/ChatRuntime/ChatMessageIdentityResolver.swift`

## 7.2 建议继续演进而不是推倒重写
- [IMChatStore.swift](/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Core/IMChatStore.swift)
- [RaverChatController.swift](/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Messages/UIKitChat/RaverChatController.swift)
- [RaverChatDataProvider.swift](/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Messages/UIKitChat/RaverChatDataProvider.swift)
- [TencentUIKitChatView.swift](/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Messages/UIKitChat/TencentUIKitChatView.swift)
- [MainTabCoordinator.swift](/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Application/Coordinator/MainTabCoordinator.swift)

---

## 8. 与当前 tracker 的关系

这份文档定义的是“目标架构”。

执行顺序、完成状态、每日进度继续记录在：
- [TENCENT_IM_EXYTE_CHAT_EXECUTION_TRACKER.md](/Users/blackie/Projects/raver/docs/TENCENT_IM_EXYTE_CHAT_EXECUTION_TRACKER.md)

建议后续每一轮改造都遵循下面节奏：

1. 先更新 tracker 里当前 phase 的任务项
2. 再按本架构文档对应层落代码
3. 每完成一个能力点都补一次 build 与 smoke 结果

---

## 9. 一句话结论

你现在最优解不是“把腾讯 Demo 页面搬进来”，而是：

- **严格照腾讯 Demo 的分层与数据流重建你自己的聊天系统**
- **UI 继续用 Exyte**
- **列表逻辑像腾讯列表 provider**
- **详情逻辑像腾讯 chat provider**
- **Store/Controller 成为真相源，页面只负责展示**
