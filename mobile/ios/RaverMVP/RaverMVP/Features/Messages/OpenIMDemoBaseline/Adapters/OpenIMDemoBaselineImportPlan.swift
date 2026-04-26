import Foundation

enum OpenIMDemoBaselineImportStage: String, CaseIterable {
    case chatMain = "chat_main"
    case chatRendering = "chat_rendering"
    case conversationAndSetting = "conversation_and_setting"
    case coreBridge = "core_bridge"
}

struct OpenIMDemoBaselineImportGroup {
    let stage: OpenIMDemoBaselineImportStage
    let name: String
    let sourceRootRelativePath: String
    let filePaths: [String]
}

enum OpenIMDemoBaselineImportPlan {
    static let vendorRootRelativePath =
        "Features/Messages/OpenIMDemoBaseline/Vendor/OpenIMIOSDemo"

    static let groups: [OpenIMDemoBaselineImportGroup] = [
        OpenIMDemoBaselineImportGroup(
            stage: .chatMain,
            name: "Chat container and controller",
            sourceRootRelativePath: "OUIIM/Classes/OIMUIChat",
            filePaths: [
                "ChatViewController.swift",
                "ChatViewControllerBuilder.swift",
                "Controller/ChatController.swift",
                "Controller/ChatControllerDelegate.swift",
                "Controller/DefaultChatController.swift",
                "Model/DataProviderDelegate.swift",
                "Model/DefaultDataProvider.swift",
                "Model/Entity/Cell.swift",
                "Model/Entity/Message.swift",
                "Model/Entity/Section.swift",
                "Model/Entity/TypingState.swift",
                "Model/Entity/User.swift",
                "View/DataSource/ChatCollectionDataSource.swift",
                "View/DataSource/DefaultChatCollectionDataSource.swift",
                "View/InputView/CoustomInputBarAccessoryView.swift",
                "View/InputView/CustomAutocompleteCell.swift",
                "View/InputView/InputPadView.swift",
                "View/AccessoryView/DateAccessoryController.swift",
                "View/AccessoryView/DateAccessoryView.swift",
                "View/AccessoryView/EditingAccessoryController.swift",
                "View/AccessoryView/EditingAccessoryControllerDelegate.swift",
                "View/AccessoryView/EditingAccessoryView.swift",
                "View/Other/ChatTitleView.swift",
                "View/Other/ContentContainerView.swift",
                "View/Other/MainContainerView.swift",
            ]
        ),
        OpenIMDemoBaselineImportGroup(
            stage: .chatRendering,
            name: "Message cells and preview",
            sourceRootRelativePath: "OUIIM/Classes/OIMUIChat",
            filePaths: [
                "View/Cell/CellBaseController.swift",
                "View/Cell/CellBaseView.swift",
                "View/Cell/AvatarView/AvatarViewController.swift",
                "View/Cell/AvatarView/ChatAvatarView.swift",
                "View/Cell/StatusView/StatusView.swift",
                "View/Cell/TextMessageView/TextMessageController.swift",
                "View/Cell/TextMessageView/TextMessageView.swift",
                "View/Cell/NoticeView/NoticeViewController.swift",
                "View/Cell/NoticeView/NoticeView.swift",
                "View/Cell/SystemTipsView/SystemTipsViewController.swift",
                "View/Cell/SystemTipsView/SystemTipsView.swift",
                "View/Cell/TypingIndicator/TypingIndicatorController.swift",
                "View/Cell/TypingIndicator/TypingIndicator.swift",
                "View/Cell/ImageView/ImageController.swift",
                "View/Cell/ImageView/ImageView.swift",
                "View/Other/BubbleController.swift",
                "View/Other/BezierMaskedView.swift",
                "File/FileDownloadManager.swift",
                "File/FilePreviewViewController.swift",
            ]
        ),
        OpenIMDemoBaselineImportGroup(
            stage: .conversationAndSetting,
            name: "Conversation list and chat setting",
            sourceRootRelativePath: "OUIIM/Classes/OIMUIConversation",
            filePaths: [
                "ChatListHeaderView.swift",
                "ChatListViewController.swift",
                "ChatListViewModel.swift",
                "ChatTableViewCell.swift",
                "ChatSetting/SingleChatSettingTableViewController.swift",
                "ChatSetting/SingleChatSettingViewModel.swift",
                "ChatSetting/GroupChatSettingTableViewController.swift",
                "ChatSetting/GroupChatSettingViewModel.swift",
                "ChatSetting/GroupSettingManageTableViewController.swift",
                "ChatSetting/GroupSettingManageViewModel.swift",
                "ChatSetting/ModifyNicknameViewController.swift",
                "ChatSetting/MemberList/MemberListViewController.swift",
                "ChatSetting/MemberList/MemberListViewModel.swift",
            ]
        ),
        OpenIMDemoBaselineImportGroup(
            stage: .coreBridge,
            name: "Core runtime bridge",
            sourceRootRelativePath: "OUICore/Classes",
            filePaths: [
                "Api/OIMApi.swift",
                "Core/CallBack.swift",
                "Core/Events.swift",
                "Core/IMController.swift",
                "Core/JNNotificationCenter.swift",
                "Core/StandardUI.swift",
                "Core/ViewControllerFactory.swift",
                "Model/Model+Extension.swift",
            ]
        ),
    ]
}
