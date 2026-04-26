# `openim-ios-demo` Source Import Manifest

> 用途：把 `thirdparty/openimApp/openim-ios-demo` 中需要迁入 Raver 的源码，按“原始来源 -> 目标目录 -> 优先级 -> 是否允许改动”的方式固定下来。

## Source Root

当前第三方源码根目录：

- [`/Users/blackie/Projects/raver/thirdparty/openimApp/openim-ios-demo/`](/Users/blackie/Projects/raver/thirdparty/openimApp/openim-ios-demo/)

当前 Raver 目标根目录：

- [`/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Messages/OpenIMDemoBaseline/`](/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Messages/OpenIMDemoBaseline/)

## Import Rules

- 优先迁原文件，不做“先抄逻辑再自己重写”
- 首轮迁入允许：
  - 修编译
  - 修模块引用
  - 补 adapter / bridge
- 首轮迁入不允许：
  - 改行为
  - 改布局策略
  - 改状态机
  - 用现有 `DemoAligned*` 替代 demo 原文件

## Phase 1: Must Import First

这一批决定聊天页能不能真正变成 demo 同源实现。

### 1. Chat Main Container

Source:

- [`OUIIM/Classes/OIMUIChat/ChatViewController.swift`](/Users/blackie/Projects/raver/thirdparty/openimApp/openim-ios-demo/OUIIM/Classes/OIMUIChat/ChatViewController.swift)
- [`OUIIM/Classes/OIMUIChat/ChatViewControllerBuilder.swift`](/Users/blackie/Projects/raver/thirdparty/openimApp/openim-ios-demo/OUIIM/Classes/OIMUIChat/ChatViewControllerBuilder.swift)

Target:

- `OpenIMDemoBaseline/Chat/`

Priority:

- `P0`

Policy:

- 尽量保留原页面容器与 builder 结构
- 不再让 `DemoAlignedChatViewController` 继续扮演最终聊天容器

### 2. Chat Controller Layer

Source:

- [`OUIIM/Classes/OIMUIChat/Controller/ChatController.swift`](/Users/blackie/Projects/raver/thirdparty/openimApp/openim-ios-demo/OUIIM/Classes/OIMUIChat/Controller/ChatController.swift)
- [`OUIIM/Classes/OIMUIChat/Controller/ChatControllerDelegate.swift`](/Users/blackie/Projects/raver/thirdparty/openimApp/openim-ios-demo/OUIIM/Classes/OIMUIChat/Controller/ChatControllerDelegate.swift)
- [`OUIIM/Classes/OIMUIChat/Controller/DefaultChatController.swift`](/Users/blackie/Projects/raver/thirdparty/openimApp/openim-ios-demo/OUIIM/Classes/OIMUIChat/Controller/DefaultChatController.swift)

Target:

- `OpenIMDemoBaseline/Chat/Controller/`

Priority:

- `P0`

Policy:

- 发送态、回流替换、重试、typing、滚动联动的核心状态机都以这层为准
- 当前 `RaverChatController` 之后应退为过渡层

### 3. Chat Data Provider Layer

Source:

- [`OUIIM/Classes/OIMUIChat/Model/DefaultDataProvider.swift`](/Users/blackie/Projects/raver/thirdparty/openimApp/openim-ios-demo/OUIIM/Classes/OIMUIChat/Model/DefaultDataProvider.swift)
- [`OUIIM/Classes/OIMUIChat/Model/DataProviderDelegate.swift`](/Users/blackie/Projects/raver/thirdparty/openimApp/openim-ios-demo/OUIIM/Classes/OIMUIChat/Model/DataProviderDelegate.swift)

Supporting entities:

- [`OUIIM/Classes/OIMUIChat/Model/Entity/Cell.swift`](/Users/blackie/Projects/raver/thirdparty/openimApp/openim-ios-demo/OUIIM/Classes/OIMUIChat/Model/Entity/Cell.swift)
- [`OUIIM/Classes/OIMUIChat/Model/Entity/Message.swift`](/Users/blackie/Projects/raver/thirdparty/openimApp/openim-ios-demo/OUIIM/Classes/OIMUIChat/Model/Entity/Message.swift)
- [`OUIIM/Classes/OIMUIChat/Model/Entity/Section.swift`](/Users/blackie/Projects/raver/thirdparty/openimApp/openim-ios-demo/OUIIM/Classes/OIMUIChat/Model/Entity/Section.swift)
- [`OUIIM/Classes/OIMUIChat/Model/Entity/TypingState.swift`](/Users/blackie/Projects/raver/thirdparty/openimApp/openim-ios-demo/OUIIM/Classes/OIMUIChat/Model/Entity/TypingState.swift)
- [`OUIIM/Classes/OIMUIChat/Model/Entity/User.swift`](/Users/blackie/Projects/raver/thirdparty/openimApp/openim-ios-demo/OUIIM/Classes/OIMUIChat/Model/Entity/User.swift)

Target:

- `OpenIMDemoBaseline/Chat/Model/`

Priority:

- `P0`

Policy:

- 历史分页、section 组织、typing state、cell entity 都以 demo 结构为准
- 当前 `RaverChatDataProvider` 之后只允许存在为 bridge，不允许继续做最终逻辑层

### 4. Chat Data Source Layer

Source:

- [`OUIIM/Classes/OIMUIChat/View/DataSource/ChatCollectionDataSource.swift`](/Users/blackie/Projects/raver/thirdparty/openimApp/openim-ios-demo/OUIIM/Classes/OIMUIChat/View/DataSource/ChatCollectionDataSource.swift)
- [`OUIIM/Classes/OIMUIChat/View/DataSource/DefaultChatCollectionDataSource.swift`](/Users/blackie/Projects/raver/thirdparty/openimApp/openim-ios-demo/OUIIM/Classes/OIMUIChat/View/DataSource/DefaultChatCollectionDataSource.swift)

Target:

- `OpenIMDemoBaseline/Chat/View/DataSource/`

Priority:

- `P0`

Policy:

- cell 注册、section/source 驱动方式以 demo 为准
- 当前 `RaverChatCollectionDataSource` 不再作为最终实现扩展

### 5. Chat Input / Accessory / Container Views

Source:

- [`OUIIM/Classes/OIMUIChat/View/InputView/CoustomInputBarAccessoryView.swift`](/Users/blackie/Projects/raver/thirdparty/openimApp/openim-ios-demo/OUIIM/Classes/OIMUIChat/View/InputView/CoustomInputBarAccessoryView.swift)
- [`OUIIM/Classes/OIMUIChat/View/InputView/CustomAutocompleteCell.swift`](/Users/blackie/Projects/raver/thirdparty/openimApp/openim-ios-demo/OUIIM/Classes/OIMUIChat/View/InputView/CustomAutocompleteCell.swift)
- [`OUIIM/Classes/OIMUIChat/View/InputView/InputPadView.swift`](/Users/blackie/Projects/raver/thirdparty/openimApp/openim-ios-demo/OUIIM/Classes/OIMUIChat/View/InputView/InputPadView.swift)
- [`OUIIM/Classes/OIMUIChat/View/AccessoryView/DateAccessoryController.swift`](/Users/blackie/Projects/raver/thirdparty/openimApp/openim-ios-demo/OUIIM/Classes/OIMUIChat/View/AccessoryView/DateAccessoryController.swift)
- [`OUIIM/Classes/OIMUIChat/View/AccessoryView/DateAccessoryView.swift`](/Users/blackie/Projects/raver/thirdparty/openimApp/openim-ios-demo/OUIIM/Classes/OIMUIChat/View/AccessoryView/DateAccessoryView.swift)
- [`OUIIM/Classes/OIMUIChat/View/AccessoryView/EditingAccessoryController.swift`](/Users/blackie/Projects/raver/thirdparty/openimApp/openim-ios-demo/OUIIM/Classes/OIMUIChat/View/AccessoryView/EditingAccessoryController.swift)
- [`OUIIM/Classes/OIMUIChat/View/AccessoryView/EditingAccessoryControllerDelegate.swift`](/Users/blackie/Projects/raver/thirdparty/openimApp/openim-ios-demo/OUIIM/Classes/OIMUIChat/View/AccessoryView/EditingAccessoryControllerDelegate.swift)
- [`OUIIM/Classes/OIMUIChat/View/AccessoryView/EditingAccessoryView.swift`](/Users/blackie/Projects/raver/thirdparty/openimApp/openim-ios-demo/OUIIM/Classes/OIMUIChat/View/AccessoryView/EditingAccessoryView.swift)
- [`OUIIM/Classes/OIMUIChat/View/Other/MainContainerView.swift`](/Users/blackie/Projects/raver/thirdparty/openimApp/openim-ios-demo/OUIIM/Classes/OIMUIChat/View/Other/MainContainerView.swift)
- [`OUIIM/Classes/OIMUIChat/View/Other/ContentContainerView.swift`](/Users/blackie/Projects/raver/thirdparty/openimApp/openim-ios-demo/OUIIM/Classes/OIMUIChat/View/Other/ContentContainerView.swift)
- [`OUIIM/Classes/OIMUIChat/View/Other/ChatTitleView.swift`](/Users/blackie/Projects/raver/thirdparty/openimApp/openim-ios-demo/OUIIM/Classes/OIMUIChat/View/Other/ChatTitleView.swift)

Target:

- `OpenIMDemoBaseline/Chat/View/`

Priority:

- `P0`

Policy:

- 输入区、顶部标题、editing accessory、日期 accessory、主容器视图都尽量直接迁原文件

## Phase 2: Message Rendering Core

这一批决定“视觉和交互是不是原味 demo”。

### 6. Message Cell Base

Source:

- [`OUIIM/Classes/OIMUIChat/View/Cell/CellBaseController.swift`](/Users/blackie/Projects/raver/thirdparty/openimApp/openim-ios-demo/OUIIM/Classes/OIMUIChat/View/Cell/CellBaseController.swift)
- [`OUIIM/Classes/OIMUIChat/View/Cell/CellBaseView.swift`](/Users/blackie/Projects/raver/thirdparty/openimApp/openim-ios-demo/OUIIM/Classes/OIMUIChat/View/Cell/CellBaseView.swift)
- [`OUIIM/Classes/OIMUIChat/View/Cell/AvatarView/AvatarViewController.swift`](/Users/blackie/Projects/raver/thirdparty/openimApp/openim-ios-demo/OUIIM/Classes/OIMUIChat/View/Cell/AvatarView/AvatarViewController.swift)
- [`OUIIM/Classes/OIMUIChat/View/Cell/AvatarView/ChatAvatarView.swift`](/Users/blackie/Projects/raver/thirdparty/openimApp/openim-ios-demo/OUIIM/Classes/OIMUIChat/View/Cell/AvatarView/ChatAvatarView.swift)
- [`OUIIM/Classes/OIMUIChat/View/Cell/StatusView/StatusView.swift`](/Users/blackie/Projects/raver/thirdparty/openimApp/openim-ios-demo/OUIIM/Classes/OIMUIChat/View/Cell/StatusView/StatusView.swift)
- [`OUIIM/Classes/OIMUIChat/View/Other/BubbleController.swift`](/Users/blackie/Projects/raver/thirdparty/openimApp/openim-ios-demo/OUIIM/Classes/OIMUIChat/View/Other/BubbleController.swift)
- [`OUIIM/Classes/OIMUIChat/View/Other/BezierMaskedView.swift`](/Users/blackie/Projects/raver/thirdparty/openimApp/openim-ios-demo/OUIIM/Classes/OIMUIChat/View/Other/BezierMaskedView.swift)

Target:

- `OpenIMDemoBaseline/Chat/View/Cell/`

Priority:

- `P1`

### 7. Text / Notice / System / Typing

Source:

- [`OUIIM/Classes/OIMUIChat/View/Cell/TextMessageView/TextMessageController.swift`](/Users/blackie/Projects/raver/thirdparty/openimApp/openim-ios-demo/OUIIM/Classes/OIMUIChat/View/Cell/TextMessageView/TextMessageController.swift)
- [`OUIIM/Classes/OIMUIChat/View/Cell/TextMessageView/TextMessageView.swift`](/Users/blackie/Projects/raver/thirdparty/openimApp/openim-ios-demo/OUIIM/Classes/OIMUIChat/View/Cell/TextMessageView/TextMessageView.swift)
- [`OUIIM/Classes/OIMUIChat/View/Cell/NoticeView/NoticeViewController.swift`](/Users/blackie/Projects/raver/thirdparty/openimApp/openim-ios-demo/OUIIM/Classes/OIMUIChat/View/Cell/NoticeView/NoticeViewController.swift)
- [`OUIIM/Classes/OIMUIChat/View/Cell/NoticeView/NoticeView.swift`](/Users/blackie/Projects/raver/thirdparty/openimApp/openim-ios-demo/OUIIM/Classes/OIMUIChat/View/Cell/NoticeView/NoticeView.swift)
- [`OUIIM/Classes/OIMUIChat/View/Cell/SystemTipsView/SystemTipsViewController.swift`](/Users/blackie/Projects/raver/thirdparty/openimApp/openim-ios-demo/OUIIM/Classes/OIMUIChat/View/Cell/SystemTipsView/SystemTipsViewController.swift)
- [`OUIIM/Classes/OIMUIChat/View/Cell/SystemTipsView/SystemTipsView.swift`](/Users/blackie/Projects/raver/thirdparty/openimApp/openim-ios-demo/OUIIM/Classes/OIMUIChat/View/Cell/SystemTipsView/SystemTipsView.swift)
- [`OUIIM/Classes/OIMUIChat/View/Cell/TypingIndicator/TypingIndicatorController.swift`](/Users/blackie/Projects/raver/thirdparty/openimApp/openim-ios-demo/OUIIM/Classes/OIMUIChat/View/Cell/TypingIndicator/TypingIndicatorController.swift)
- [`OUIIM/Classes/OIMUIChat/View/Cell/TypingIndicator/TypingIndicator.swift`](/Users/blackie/Projects/raver/thirdparty/openimApp/openim-ios-demo/OUIIM/Classes/OIMUIChat/View/Cell/TypingIndicator/TypingIndicator.swift)

Target:

- `OpenIMDemoBaseline/Chat/View/Cell/`

Priority:

- `P1`

### 8. Image And Preview Core

Source:

- [`OUIIM/Classes/OIMUIChat/View/Cell/ImageView/ImageController.swift`](/Users/blackie/Projects/raver/thirdparty/openimApp/openim-ios-demo/OUIIM/Classes/OIMUIChat/View/Cell/ImageView/ImageController.swift)
- [`OUIIM/Classes/OIMUIChat/View/Cell/ImageView/ImageView.swift`](/Users/blackie/Projects/raver/thirdparty/openimApp/openim-ios-demo/OUIIM/Classes/OIMUIChat/View/Cell/ImageView/ImageView.swift)
- [`OUICoreView/Classes/ViewController/MediaPreview/MediaPreviewViewController.swift`](/Users/blackie/Projects/raver/thirdparty/openimApp/openim-ios-demo/OUICoreView/Classes/ViewController/MediaPreview/MediaPreviewViewController.swift)
- [`OUICoreView/Classes/ViewController/MediaPreview/ImageZoomCell.swift`](/Users/blackie/Projects/raver/thirdparty/openimApp/openim-ios-demo/OUICoreView/Classes/ViewController/MediaPreview/ImageZoomCell.swift)
- [`OUICoreView/Classes/ViewController/MediaPreview/VideoZoomCell.swift`](/Users/blackie/Projects/raver/thirdparty/openimApp/openim-ios-demo/OUICoreView/Classes/ViewController/MediaPreview/VideoZoomCell.swift)
- [`OUICoreView/Classes/ViewController/MediaPreview/PageIndicator.swift`](/Users/blackie/Projects/raver/thirdparty/openimApp/openim-ios-demo/OUICoreView/Classes/ViewController/MediaPreview/PageIndicator.swift)
- [`OUICoreView/Classes/ViewController/MediaPreview/PreviewModalView.swift`](/Users/blackie/Projects/raver/thirdparty/openimApp/openim-ios-demo/OUICoreView/Classes/ViewController/MediaPreview/PreviewModalView.swift)

Target:

- `OpenIMDemoBaseline/Chat/View/Cell/`
- `OpenIMDemoBaseline/CommonWidgets/`

Priority:

- `P1`

### 9. File Preview

Source:

- [`OUIIM/Classes/OIMUIChat/File/FileDownloadManager.swift`](/Users/blackie/Projects/raver/thirdparty/openimApp/openim-ios-demo/OUIIM/Classes/OIMUIChat/File/FileDownloadManager.swift)
- [`OUIIM/Classes/OIMUIChat/File/FilePreviewViewController.swift`](/Users/blackie/Projects/raver/thirdparty/openimApp/openim-ios-demo/OUIIM/Classes/OIMUIChat/File/FilePreviewViewController.swift)

Target:

- `OpenIMDemoBaseline/Chat/File/`

Priority:

- `P1`

## Phase 3: Conversation And Setting

### 10. Conversation List

Source:

- [`OUIIM/Classes/OIMUIConversation/ChatListViewController.swift`](/Users/blackie/Projects/raver/thirdparty/openimApp/openim-ios-demo/OUIIM/Classes/OIMUIConversation/ChatListViewController.swift)
- [`OUIIM/Classes/OIMUIConversation/ChatListViewModel.swift`](/Users/blackie/Projects/raver/thirdparty/openimApp/openim-ios-demo/OUIIM/Classes/OIMUIConversation/ChatListViewModel.swift)
- [`OUIIM/Classes/OIMUIConversation/ChatListHeaderView.swift`](/Users/blackie/Projects/raver/thirdparty/openimApp/openim-ios-demo/OUIIM/Classes/OIMUIConversation/ChatListHeaderView.swift)
- [`OUIIM/Classes/OIMUIConversation/ChatTableViewCell.swift`](/Users/blackie/Projects/raver/thirdparty/openimApp/openim-ios-demo/OUIIM/Classes/OIMUIConversation/ChatTableViewCell.swift)

Target:

- `OpenIMDemoBaseline/Conversation/`

Priority:

- `P1`

### 11. Chat Setting

Source:

- [`OUIIM/Classes/OIMUIConversation/ChatSetting/SingleChatSettingTableViewController.swift`](/Users/blackie/Projects/raver/thirdparty/openimApp/openim-ios-demo/OUIIM/Classes/OIMUIConversation/ChatSetting/SingleChatSettingTableViewController.swift)
- [`OUIIM/Classes/OIMUIConversation/ChatSetting/SingleChatSettingViewModel.swift`](/Users/blackie/Projects/raver/thirdparty/openimApp/openim-ios-demo/OUIIM/Classes/OIMUIConversation/ChatSetting/SingleChatSettingViewModel.swift)
- [`OUIIM/Classes/OIMUIConversation/ChatSetting/GroupChatSettingTableViewController.swift`](/Users/blackie/Projects/raver/thirdparty/openimApp/openim-ios-demo/OUIIM/Classes/OIMUIConversation/ChatSetting/GroupChatSettingTableViewController.swift)
- [`OUIIM/Classes/OIMUIConversation/ChatSetting/GroupChatSettingViewModel.swift`](/Users/blackie/Projects/raver/thirdparty/openimApp/openim-ios-demo/OUIIM/Classes/OIMUIConversation/ChatSetting/GroupChatSettingViewModel.swift)
- [`OUIIM/Classes/OIMUIConversation/ChatSetting/GroupSettingManageTableViewController.swift`](/Users/blackie/Projects/raver/thirdparty/openimApp/openim-ios-demo/OUIIM/Classes/OIMUIConversation/ChatSetting/GroupSettingManageTableViewController.swift)
- [`OUIIM/Classes/OIMUIConversation/ChatSetting/GroupSettingManageViewModel.swift`](/Users/blackie/Projects/raver/thirdparty/openimApp/openim-ios-demo/OUIIM/Classes/OIMUIConversation/ChatSetting/GroupSettingManageViewModel.swift)
- [`OUIIM/Classes/OIMUIConversation/ChatSetting/ModifyNicknameViewController.swift`](/Users/blackie/Projects/raver/thirdparty/openimApp/openim-ios-demo/OUIIM/Classes/OIMUIConversation/ChatSetting/ModifyNicknameViewController.swift)
- [`OUIIM/Classes/OIMUIConversation/ChatSetting/MemberList/MemberListViewController.swift`](/Users/blackie/Projects/raver/thirdparty/openimApp/openim-ios-demo/OUIIM/Classes/OIMUIConversation/ChatSetting/MemberList/MemberListViewController.swift)
- [`OUIIM/Classes/OIMUIConversation/ChatSetting/MemberList/MemberListViewModel.swift`](/Users/blackie/Projects/raver/thirdparty/openimApp/openim-ios-demo/OUIIM/Classes/OIMUIConversation/ChatSetting/MemberList/MemberListViewModel.swift)
- `ChatSetting/Cells/*`

Target:

- `OpenIMDemoBaseline/ChatSetting/`

Priority:

- `P1`

## Phase 4: Core Dependencies And Bridges

### 12. Core Runtime Dependencies

Source:

- [`OUICore/Classes/Core/IMController.swift`](/Users/blackie/Projects/raver/thirdparty/openimApp/openim-ios-demo/OUICore/Classes/Core/IMController.swift)
- [`OUICore/Classes/Core/Events.swift`](/Users/blackie/Projects/raver/thirdparty/openimApp/openim-ios-demo/OUICore/Classes/Core/Events.swift)
- [`OUICore/Classes/Core/CallBack.swift`](/Users/blackie/Projects/raver/thirdparty/openimApp/openim-ios-demo/OUICore/Classes/Core/CallBack.swift)
- [`OUICore/Classes/Core/JNNotificationCenter.swift`](/Users/blackie/Projects/raver/thirdparty/openimApp/openim-ios-demo/OUICore/Classes/Core/JNNotificationCenter.swift)
- [`OUICore/Classes/Core/ViewControllerFactory.swift`](/Users/blackie/Projects/raver/thirdparty/openimApp/openim-ios-demo/OUICore/Classes/Core/ViewControllerFactory.swift)
- [`OUICore/Classes/Core/StandardUI.swift`](/Users/blackie/Projects/raver/thirdparty/openimApp/openim-ios-demo/OUICore/Classes/Core/StandardUI.swift)

Target:

- `OpenIMDemoBaseline/ServiceBridge/`
- `OpenIMDemoBaseline/ThemeBridge/`
- `OpenIMDemoBaseline/RoutingBridge/`

Priority:

- `P2`

Policy:

- 这批不一定原路径原封不动接入，但职责必须对齐
- 很可能需要用 `OpenIMSession` 包一层 `IMControllerBridge`

### 13. Core Widgets And Shared Utilities

Source:

- `OUICore/Classes/Widgets/*`
- `OUICore/Classes/Utils/*`
- `OUICore/Classes/Model/Model+Extension.swift`
- `OUICore/Classes/Api/OIMApi.swift`

Target:

- `OpenIMDemoBaseline/CommonWidgets/`
- `OpenIMDemoBaseline/Adapters/`

Priority:

- `P2`

Policy:

- 优先只迁聊天主路径真正依赖的部分
- 不做全量无脑搬运

## Raver Replacement Map

当前这些实现后续会被 baseline 实现逐步替换或降级：

- `DemoAlignedChatViewController`
- `RaverChatController`
- `RaverChatDataProvider`
- `RaverChatCollectionDataSource`
- `DemoAligned*Coordinator`
- 当前 UIKit 聊天输入区与消息 cell 体系

## Immediate Next Step

建议下一步开始做这 4 件事：

1. 把 `OIMUIChat` 首批原文件复制进 `OpenIMDemoBaseline/Vendor/OpenIMIOSDemo/`
2. 建 `OpenIMDemoBaseline/Chat` 到 vendor 原文件的薄封装入口
3. 先尝试把 `ChatViewController + DefaultChatController + DefaultDataProvider + DefaultChatCollectionDataSource` 编进工程
4. 再补 `IMController` 到 `OpenIMSession` 的 bridge

