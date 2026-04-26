import Foundation
import UIKit
import OUICore

@MainActor
struct ChatViewControllerBuilder {
    func build(
        _ conversation: ConversationInfo,
        anchorMessage: OpenIMDemoBaselineMessageInfo? = nil,
        hiddenInputBar: Bool = false
    ) -> UIViewController {
        let baselineConversation = OpenIMDemoBaselineConversationInfo(ouicore: conversation)
        return build(
            baselineConversation,
            anchorMessage: anchorMessage,
            hiddenInputBar: hiddenInputBar
        )
    }

    func build(
        _ conversation: OpenIMDemoBaselineConversationInfo,
        anchorMessage: OpenIMDemoBaselineMessageInfo? = nil,
        hiddenInputBar: Bool = false
    ) -> UIViewController {
        let dataProvider = DefaultDataProvider(
            conversation: conversation,
            anchorMessage: anchorMessage
        )
        let messageController = DefaultChatController(
            dataProvider: dataProvider,
            senderID: IMController.shared.uid,
            conversation: conversation
        )
        dataProvider.delegate = messageController

        let editNotifier = EditNotifier()
        let swipeNotifier = SwipeNotifier()
        let extractedExpr = DefaultChatCollectionDataSource(
            editNotifier: editNotifier,
            swipeNotifier: swipeNotifier,
            reloadDelegate: messageController,
            editingDelegate: messageController
        )
        let dataSource = extractedExpr

        let messageViewController = ChatViewController(
            chatController: messageController,
            dataSource: dataSource,
            editNotifier: editNotifier,
            swipeNotifier: swipeNotifier,
            hiddenInputBar: hiddenInputBar,
            scrollToTop: anchorMessage != nil
        )
        messageController.delegate = messageViewController
        dataSource.gestureDelegate = messageViewController

        return messageViewController
    }

    init() {
    }
}

typealias OpenIMDemoBaselineChatViewControllerBuilder = ChatViewControllerBuilder

private extension OpenIMDemoBaselineConversationInfo {
    init(ouicore conversation: ConversationInfo) {
        let recvMsgOpt = OpenIMDemoBaselineReceiveMessageOpt(
            rawValue: Int(conversation.recvMsgOpt.rawValue)
        ) ?? .receive
        let conversationType = OpenIMDemoBaselineConversationType(
            rawValue: Int(conversation.conversationType.rawValue)
        ) ?? .undefine

        self.init(
            conversationID: conversation.conversationID,
            userID: conversation.userID,
            groupID: conversation.groupID,
            showName: conversation.showName,
            faceURL: conversation.faceURL,
            recvMsgOpt: recvMsgOpt,
            unreadCount: Int(conversation.unreadCount),
            conversationType: conversationType,
            latestMsgSendTime: Int(conversation.latestMsgSendTime),
            draftText: conversation.draftText,
            draftTextTime: Int(conversation.draftTextTime),
            isPinned: conversation.isPinned,
            latestMsg: nil
        )
    }
}
