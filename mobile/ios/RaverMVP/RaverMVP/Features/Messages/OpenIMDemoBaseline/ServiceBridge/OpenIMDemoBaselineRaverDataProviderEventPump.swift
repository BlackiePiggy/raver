import Combine
import Foundation
import OpenIMSDK
import OUICore
import RxSwift

@MainActor
final class OpenIMDemoBaselineRaverDataProviderEventPump {
    static let shared = OpenIMDemoBaselineRaverDataProviderEventPump(
        session: .shared,
        imBridge: OpenIMDemoBaselineRaverIMControllerBridge.shared,
        eventBridge: OpenIMDemoBaselineInMemoryDataProviderEventBridge.shared
    )

    private let session: OpenIMSession
    private let imBridge: OpenIMDemoBaselineIMControllerBridge
    private let eventBridge: OpenIMDemoBaselineDataProviderEventBridge
    private var cancellables = Set<AnyCancellable>()
    private let rxDisposeBag = DisposeBag()
    private var notificationDisposables: [Disposable] = []
    private static var didAttachOUICoreListeners = false

    init(
        session: OpenIMSession,
        imBridge: OpenIMDemoBaselineIMControllerBridge,
        eventBridge: OpenIMDemoBaselineDataProviderEventBridge
    ) {
        self.session = session
        self.imBridge = imBridge
        self.eventBridge = eventBridge
        bind()
    }

    private func bind() {
        attachOUICoreListenersIfNeeded()

        IMController.shared.totalUnreadSubject
            .subscribe(onNext: { [weak self] count in
                self?.eventBridge.emitTotalUnreadCountChanged(max(0, count))
            })
            .disposed(by: rxDisposeBag)

        IMController.shared.conversationChangedSubject
            .subscribe(onNext: { [weak self] conversations in
                guard let self else { return }
                let mapped = conversations.map(self.mapConversation)
                self.eventBridge.emitConversationChanged(mapped)
            })
            .disposed(by: rxDisposeBag)

        IMController.shared.newMsgReceivedSubject
            .subscribe(onNext: { [weak self] message in
                self?.emitIncomingMessage(message.toOIMMessageInfo())
            })
            .disposed(by: rxDisposeBag)

        IMController.shared.connectionRelay
            .skip(1)
            .subscribe(onNext: { [weak self] state in
                guard state.status == .syncComplete else {
                    return
                }
                self?.eventBridge.emitConnectionSyncComplete()
            })
            .disposed(by: rxDisposeBag)

        IMController.shared.groupMemberInfoChange
            .compactMap { $0 }
            .subscribe(onNext: { [weak self] info in
                guard let self else { return }
                self.eventBridge.emitGroupMemberInfoChanged(self.mapGroupMemberInfo(info))
            })
            .disposed(by: rxDisposeBag)

        IMController.shared.joinedGroupAdded
            .compactMap { $0 }
            .subscribe(onNext: { [weak self] info in
                guard let self else { return }
                self.eventBridge.emitJoinedGroupAdded(self.mapGroupInfo(info))
            })
            .disposed(by: rxDisposeBag)

        IMController.shared.joinedGroupDeleted
            .compactMap { $0 }
            .subscribe(onNext: { [weak self] info in
                guard let self else { return }
                self.eventBridge.emitJoinedGroupDeleted(self.mapGroupInfo(info))
            })
            .disposed(by: rxDisposeBag)

        IMController.shared.friendInfoChangedSubject
            .compactMap { $0 }
            .subscribe(onNext: { [weak self] info in
                guard let self else { return }
                self.eventBridge.emitFriendInfoChanged(self.mapFriendInfo(info))
            })
            .disposed(by: rxDisposeBag)

        IMController.shared.groupInfoChangedSubject
            .subscribe(onNext: { [weak self] info in
                guard let self else { return }
                self.eventBridge.emitGroupInfoChanged(self.mapGroupInfo(info))
            })
            .disposed(by: rxDisposeBag)

        IMController.shared.groupMemberAdded
            .compactMap { $0 }
            .subscribe(onNext: { [weak self] info in
                guard let self else { return }
                self.eventBridge.emitGroupMembersChanged(added: true, info: self.mapGroupMemberInfo(info))
            })
            .disposed(by: rxDisposeBag)

        IMController.shared.groupMemberDeleted
            .compactMap { $0 }
            .subscribe(onNext: { [weak self] info in
                guard let self else { return }
                self.eventBridge.emitGroupMembersChanged(added: false, info: self.mapGroupMemberInfo(info))
            })
            .disposed(by: rxDisposeBag)

        IMController.shared.currentUserRelay
            .compactMap { $0 }
            .subscribe(onNext: { [weak self] info in
                guard let self else { return }
                self.eventBridge.emitMyUserInfoChanged(self.mapUserInfo(info))
            })
            .disposed(by: rxDisposeBag)

        notificationDisposables.append(
            JNNotificationCenter.shared.observeEvent { [weak self] (event: EventRecordClear) in
                self?.eventBridge.emitRecordClear(conversationID: event.conversationId)
            }
        )
    }

    private func attachOUICoreListenersIfNeeded() {
        guard Self.didAttachOUICoreListeners == false else {
            return
        }

        let controller = IMController.shared
        controller.imManager = OIMManager.manager
        if let userID = session.currentBusinessUserIDSnapshot() {
            controller.uid = userID
        }

        OpenIMSDK.OIMManager.callbacker.addUserListener(listener: controller)
        OpenIMSDK.OIMManager.callbacker.addFriendListener(listener: controller)
        OpenIMSDK.OIMManager.callbacker.addGroupListener(listener: controller)
        OpenIMSDK.OIMManager.callbacker.addConversationListener(listener: controller)
        OpenIMSDK.OIMManager.callbacker.addAdvancedMsgListener(listener: controller)
        OpenIMSDK.OIMManager.callbacker.addCustomBusinessListener(listener: controller)

        Self.didAttachOUICoreListeners = true
    }

    private func emitIncomingMessage(_ raw: OIMMessageInfo) {
        guard let businessConversationID = session.businessConversationIDSnapshot(for: raw) else {
            return
        }
        let chatMessage = session.chatMessageSnapshot(from: raw, conversationID: businessConversationID)
        let seed = seedForIncomingMessage(raw, businessConversationID: businessConversationID)
        let mapped = imBridge.messageInfo(from: chatMessage, seed: seed)
        eventBridge.emitReceived(messages: [mapped], forceReload: false)
    }

    private func mapConversation(_ conversation: Conversation) -> OpenIMDemoBaselineConversationInfo {
        let sessionKind: OpenIMDemoBaselineConversationSeed.SessionKind = conversation.type == .group ? .group : .direct
        let seed = OpenIMDemoBaselineConversationSeed(
            businessConversationID: conversation.id,
            openIMConversationID: conversation.openIMConversationID ?? conversation.id,
            sessionKind: sessionKind,
            currentUserID: session.currentBusinessUserIDSnapshot(),
            peerUserID: sessionKind == .direct ? conversation.peer?.id : nil,
            groupID: sessionKind == .group ? conversation.id : nil,
            title: conversation.title,
            faceURL: conversation.avatarURL
        )
        return imBridge.conversationInfo(from: seed, unreadCount: max(0, conversation.unreadCount), latestMessage: nil)
    }

    private func mapConversation(_ conversation: ConversationInfo) -> OpenIMDemoBaselineConversationInfo {
        let sessionKind: OpenIMDemoBaselineConversationSeed.SessionKind =
            conversation.conversationType == .superGroup ? .group : .direct
        let latestMessage = conversation.latestMsg.map { message in
            imBridge.messageInfo(
                from: session.chatMessageSnapshot(
                    from: message.toOIMMessageInfo(),
                    conversationID: conversation.conversationID
                ),
                seed: OpenIMDemoBaselineConversationSeed(
                    businessConversationID: conversation.conversationID,
                    openIMConversationID: conversation.conversationID,
                    sessionKind: sessionKind,
                    currentUserID: session.currentBusinessUserIDSnapshot(),
                    peerUserID: sessionKind == .direct ? normalized(conversation.userID) : nil,
                    groupID: sessionKind == .group ? normalized(conversation.groupID) : nil,
                    title: conversation.showName ?? conversation.conversationID,
                    faceURL: normalized(conversation.faceURL)
                )
            )
        }
        let seed = OpenIMDemoBaselineConversationSeed(
            businessConversationID: conversation.conversationID,
            openIMConversationID: conversation.conversationID,
            sessionKind: sessionKind,
            currentUserID: session.currentBusinessUserIDSnapshot(),
            peerUserID: sessionKind == .direct ? normalized(conversation.userID) : nil,
            groupID: sessionKind == .group ? normalized(conversation.groupID) : nil,
            title: conversation.showName ?? conversation.conversationID,
            faceURL: normalized(conversation.faceURL)
        )
        return imBridge.conversationInfo(
            from: seed,
            unreadCount: max(0, conversation.unreadCount),
            latestMessage: latestMessage
        )
    }

    private func seedForIncomingMessage(
        _ raw: OIMMessageInfo,
        businessConversationID: String
    ) -> OpenIMDemoBaselineConversationSeed {
        let currentUserID = session.currentBusinessUserIDSnapshot()
        let groupID = normalized(raw.groupID)
        let isGroup = groupID != nil
        let peerUserID: String?
        if isGroup {
            peerUserID = nil
        } else if raw.isSelf() {
            peerUserID = normalized(raw.recvID)
        } else {
            peerUserID = normalized(raw.sendID)
        }

        return OpenIMDemoBaselineConversationSeed(
            businessConversationID: businessConversationID,
            openIMConversationID: businessConversationID,
            sessionKind: isGroup ? .group : .direct,
            currentUserID: currentUserID,
            peerUserID: peerUserID,
            groupID: groupID,
            title: businessConversationID,
            faceURL: nil
        )
    }

    private func normalized(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func mapUserInfo(_ info: UserInfo) -> OpenIMDemoBaselineUserInfo {
        OpenIMDemoBaselineUserInfo(
            userID: info.userID,
            nickname: info.nickname,
            remark: info.remark,
            faceURL: normalized(info.faceURL)
        )
    }

    private func mapFriendInfo(_ info: FriendInfo) -> OpenIMDemoBaselineFriendInfo {
        OpenIMDemoBaselineFriendInfo(
            userID: normalized(info.userID) ?? "",
            nickname: info.nickname,
            faceURL: normalized(info.faceURL),
            ownerUserID: normalized(info.ownerUserID),
            remark: info.remark
        )
    }

    private func mapGroupInfo(_ info: GroupInfo) -> OpenIMDemoBaselineGroupInfo {
        OpenIMDemoBaselineGroupInfo(
            groupID: info.groupID,
            groupName: info.groupName,
            faceURL: normalized(info.faceURL),
            ownerUserID: normalized(info.ownerUserID),
            memberCount: info.memberCount
        )
    }

    private func mapGroupMemberInfo(_ info: GroupMemberInfo) -> OpenIMDemoBaselineGroupMemberInfo {
        OpenIMDemoBaselineGroupMemberInfo(
            userID: normalized(info.userID) ?? "",
            groupID: normalized(info.groupID),
            nickname: info.nickname,
            faceURL: normalized(info.faceURL)
        )
    }
}
