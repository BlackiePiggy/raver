import Foundation
import DifferenceKit
import MJRefresh
import OUICore
import OUICoreView
import PhotosUI
import UniformTypeIdentifiers
import UIKit

@MainActor
protocol OpenIMDemoBaselineDataProviderDelegate: AnyObject {
    func received(messages: [OpenIMDemoBaselineMessageInfo], forceReload: Bool)
    func isInGroup(with isIn: Bool)
    func groupMemberInfoChanged(info: OpenIMDemoBaselineGroupMemberInfo)
    func groupInfoChanged(info: OpenIMDemoBaselineGroupInfo)
    func friendInfoChanged(info: OpenIMDemoBaselineFriendInfo)
    func myUserInfoChanged(info: OpenIMDemoBaselineUserInfo)
    func groupMembersChanged(added: Bool, info: OpenIMDemoBaselineGroupMemberInfo)
    func unreadCountChanged(count: Int)
    func clearMessage()
    func conversationChanged(info: OpenIMDemoBaselineConversationInfo)
}

typealias OpenIMDemoBaselineBuilderDataProviderDelegate = OpenIMDemoBaselineDataProviderDelegate

@MainActor
protocol OpenIMDemoBaselineDataProvider: AnyObject {
    func loadInitialMessages(completion: @escaping ([OpenIMDemoBaselineMessageInfo]) -> Void)
    func loadPreviousMessages(completion: @escaping ([OpenIMDemoBaselineMessageInfo]) -> Void)
    func loadMoreMessages(completion: @escaping ([OpenIMDemoBaselineMessageInfo]) -> Void)
    func getGroupInfo(groupInfoHandler: @escaping (OpenIMDemoBaselineGroupInfo) -> Void)
    func getGroupMembers(
        userIDs: [String]?,
        handler: @escaping ([OpenIMDemoBaselineGroupMemberInfo]) -> Void,
        isAdminHandler: ((Bool) -> Void)?
    )
    func getUserInfo(
        otherInfo: ((OpenIMDemoBaselineFriendInfo) -> Void)?,
        mine: ((OpenIMDemoBaselineUserInfo) -> Void)?
    )
    func isJoinedGroup(groupID: String, handler: @escaping (Bool) -> Void)
}

struct OpenIMDemoBaselineSection: Equatable {
    let id: Int
    let title: String
    let cells: [OpenIMDemoBaselineCell]
}

enum OpenIMDemoBaselineCell: Equatable {
    case date(String)
    case message(OpenIMDemoBaselineMessageInfo)
}

extension OpenIMDemoBaselineSection: DifferentiableSection {
    var differenceIdentifier: Int {
        id
    }

    func isContentEqual(to source: OpenIMDemoBaselineSection) -> Bool {
        id == source.id
    }

    var elements: [OpenIMDemoBaselineCell] {
        cells
    }

    init<C: Swift.Collection>(
        source: OpenIMDemoBaselineSection,
        elements: C
    ) where C.Element == OpenIMDemoBaselineCell {
        self.init(id: source.id, title: source.title, cells: Array(elements))
    }
}

extension OpenIMDemoBaselineCell: Differentiable {
    var differenceIdentifier: String {
        switch self {
        case let .date(text):
            return "date:\(text)"
        case let .message(message):
            return "message:\(message.clientMsgID)"
        }
    }

    func isContentEqual(to source: OpenIMDemoBaselineCell) -> Bool {
        self == source
    }
}

enum OpenIMDemoBaselineUpdateTriggerSource: String {
    case initialLoad = "initial-load"
    case previousLoad = "previous-load"
    case moreLoad = "more-load"
    case send = "send"
    case receive = "receive"
    case externalUpdate = "external-update"
}

@MainActor
protocol OpenIMDemoBaselineBuilderChatControllerDelegate: AnyObject {
    func isInGroup(with isIn: Bool)
    func update(with sections: [OpenIMDemoBaselineSection], requiresIsolatedProcess: Bool)
    func updateFromReceive(with sections: [OpenIMDemoBaselineSection], requiresIsolatedProcess: Bool)
    func updateUnreadCount(count: Int)
    func groupInfoChanged(info: OpenIMDemoBaselineGroupInfo)
    func friendInfoChanged(info: OpenIMDemoBaselineFriendInfo)
}
typealias ChatControllerDelegate = OpenIMDemoBaselineBuilderChatControllerDelegate

extension OpenIMDemoBaselineBuilderChatControllerDelegate {
    func isInGroup(with _: Bool) {}
    func updateFromReceive(with sections: [OpenIMDemoBaselineSection], requiresIsolatedProcess: Bool) {
        update(with: sections, requiresIsolatedProcess: requiresIsolatedProcess)
    }
    func updateUnreadCount(count _: Int) {}
    func groupInfoChanged(info _: OpenIMDemoBaselineGroupInfo) {}
    func friendInfoChanged(info _: OpenIMDemoBaselineFriendInfo) {}
}

@MainActor
protocol OpenIMDemoBaselineBuilderReloadDelegate: AnyObject {
    func reloadMessage(with id: String)
    func resendMessage(messageID: String)
    func removeMessage(messageID: String, completion: (() -> Void)?)
}
typealias ReloadDelegate = OpenIMDemoBaselineBuilderReloadDelegate

extension OpenIMDemoBaselineBuilderReloadDelegate {
    func resendMessage(messageID _: String) {}
    func removeMessage(messageID _: String, completion _: (() -> Void)?) {}
}

@MainActor
protocol OpenIMDemoBaselineBuilderGestureDelegate: AnyObject {
    func didTapContent(with id: String, data: OpenIMDemoBaselineMessageInfo)
}
typealias GestureDelegate = OpenIMDemoBaselineBuilderGestureDelegate

extension OpenIMDemoBaselineBuilderGestureDelegate {
    func didTapContent(with _: String, data _: OpenIMDemoBaselineMessageInfo) {}
}

final class OpenIMDemoBaselineBuilderEditNotifier {
    private(set) var isEditing = false

    func setIsEditing(_ isEditing: Bool) {
        self.isEditing = isEditing
    }
}

final class OpenIMDemoBaselineBuilderSwipeNotifier {}

@MainActor
final class DefaultDataProvider: DataProvider {
    let conversation: OpenIMDemoBaselineConversationInfo
    let anchorMessage: OpenIMDemoBaselineMessageInfo?
    let receiverId: String
    private let bridge: OpenIMDemoBaselineDataProviderBridge
    private let eventBridge: OpenIMDemoBaselineDataProviderEventBridge
    weak var delegate: DataProviderDelegate?
    private let pageSize = 20
    private var startingTimestamp = Date().timeIntervalSince1970
    private let users: [String] = []
    private var lastMessageIndex: Int = 0
    private var lastReadString: String?
    private var lastReceivedString: String?
    private let enableNewMessages = true
    private var startClientMsgID: String?
    private var reverseStartClientMsgID: String?
    private var isEnd = false
    private var reverseIsEnd = false
    private var messageStorage: [OpenIMDemoBaselineMessageInfo] = []
    private var observerTokens: [UUID] = []

    init(
        conversation: OpenIMDemoBaselineConversationInfo,
        anchorMessage: OpenIMDemoBaselineMessageInfo?,
        bridge: OpenIMDemoBaselineDataProviderBridge,
        eventBridge: OpenIMDemoBaselineDataProviderEventBridge
    ) {
        self.conversation = conversation
        self.anchorMessage = anchorMessage
        self.bridge = bridge
        self.eventBridge = eventBridge
        self.receiverId = conversation.conversationType == .c2c
            ? (conversation.userID ?? "")
            : (conversation.groupID ?? "")
        self.startClientMsgID = anchorMessage?.clientMsgID
        self.reverseStartClientMsgID = anchorMessage?.clientMsgID
        addObservers()
    }

    deinit {
        iLogger.print("\(type(of: self)) - \(#function)")
        _ = startingTimestamp
    }

    convenience init(
        conversation: OpenIMDemoBaselineConversationInfo,
        anchorMessage: OpenIMDemoBaselineMessageInfo? = nil
    ) {
        self.init(
            conversation: conversation,
            anchorMessage: anchorMessage,
            bridge: OpenIMDemoBaselineFactory.dataProviderBridge,
            eventBridge: OpenIMDemoBaselineFactory.dataProviderEventBridge
        )
    }

    func loadInitialMessages(completion: @escaping ([OpenIMDemoBaselineMessageInfo]) -> Void) {
        if anchorMessage != nil {
            startClientMsgID = anchorMessage?.clientMsgID
            reverseStartClientMsgID = anchorMessage?.clientMsgID
            var markedAnchor = anchorMessage!
            markedAnchor.isAnchor = true
            var result = [markedAnchor]
            getHistoryMessageListFromStorage(loadInitial: true, reverse: true) { messages in
                result = messages + result
                completion(result)
            }
        } else {
            startClientMsgID = nil
            getHistoryMessageListFromStorage(loadInitial: true, reverse: false) { messages in
                completion(messages)
            }
        }
    }

    func loadPreviousMessages(completion: @escaping ([OpenIMDemoBaselineMessageInfo]) -> Void) {
        getHistoryMessageListFromStorage(loadInitial: false, reverse: false, completion: completion)
    }

    func loadMoreMessages(completion: @escaping ([OpenIMDemoBaselineMessageInfo]) -> Void) {
        guard let anchorMessage else {
            completion([])
            return
        }
        _ = anchorMessage
        getHistoryMessageListFromStorage(loadInitial: false, reverse: true, completion: completion)
    }

    func getGroupInfo(completion: @escaping ([OpenIMDemoBaselineGroupInfo]) -> Void) {
        guard let groupID = conversation.groupID, !groupID.isEmpty else {
            completion([])
            return
        }
        bridge.getGroupInfo(groupIDs: [groupID]) { [weak self] groups in
            if let first = groups.first {
                self?.eventBridge.emitGroupInfoChanged(first)
            }
            completion(groups)
        }
    }

    func getGroupMembers(
        userIDs: [String]?,
        completion: @escaping ([OpenIMDemoBaselineGroupMemberInfo]) -> Void
    ) {
        guard let groupID = conversation.groupID, !groupID.isEmpty else {
            completion([])
            return
        }
        if let userIDs, !userIDs.isEmpty {
            bridge.getGroupMembersInfo(
                groupID: groupID,
                userIDs: userIDs,
                completion: completion
            )
        } else {
            Task {
                let members = await bridge.getAllGroupMembers(groupID: groupID)
                await MainActor.run {
                    completion(members)
                }
            }
        }
    }

    func getUserInfo(completion: @escaping ([OpenIMDemoBaselineFriendInfo], OpenIMDemoBaselineUserInfo?) -> Void) {
        let userIDs = [conversation.userID].compactMap { $0 }.filter { !$0.isEmpty }
        bridge.getFriendsInfo(userIDs: userIDs) { friends in
            if let first = friends.first {
                self.eventBridge.emitFriendInfoChanged(first)
            }
            if let me = self.bridge.currentUserInfo {
                self.eventBridge.emitMyUserInfoChanged(me)
            }
            completion(friends, self.bridge.currentUserInfo)
        }
    }

    func isJoinedGroup(completion: @escaping (Bool) -> Void) {
        guard let groupID = conversation.groupID, !groupID.isEmpty else {
            completion(false)
            return
        }
        bridge.isJoinedGroup(groupID: groupID) { [weak self] isJoined in
            self?.eventBridge.emitIsInGroup(isJoined)
            completion(isJoined)
        }
    }

    // MARK: - Demo-shape compatibility surface

    func getGroupInfo(groupInfoHandler: @escaping (OpenIMDemoBaselineGroupInfo) -> Void) {
        guard let groupID = conversation.groupID, !groupID.isEmpty else {
            return
        }
        bridge.getGroupInfo(groupIDs: [groupID]) { [weak self] groups in
            guard let self, let first = groups.first else {
                return
            }
            groupInfoHandler(first)
            self.bridge.isJoinedGroup(groupID: self.receiverId) { [weak self] isIn in
                self?.delegate?.isInGroup(with: isIn)
            }
        }
    }

    func getGroupMembers(
        userIDs: [String]?,
        handler: @escaping ([OpenIMDemoBaselineGroupMemberInfo]) -> Void,
        isAdminHandler: ((Bool) -> Void)?
    ) {
        getGroupMembers(userIDs: userIDs) { members in
            handler(members)
            isAdminHandler?(false)
        }
    }

    func getUserInfo(
        otherInfo: ((OpenIMDemoBaselineFriendInfo) -> Void)?,
        mine: ((OpenIMDemoBaselineUserInfo) -> Void)?
    ) {
        if let me = bridge.currentUserInfo {
            mine?(me)
        }
        getUserInfo { friends, me in
            if let first = friends.first {
                otherInfo?(first)
            } else if let otherInfo {
                otherInfo(
                    OpenIMDemoBaselineFriendInfo(
                        userID: self.receiverId,
                        nickname: self.conversation.showName,
                        faceURL: self.conversation.faceURL,
                        ownerUserID: nil,
                        remark: nil
                    )
                )
            }
            if let me {
                mine?(me)
            }
        }
    }

    func isJoinedGroup(groupID: String, handler: @escaping (Bool) -> Void) {
        guard !groupID.isEmpty else {
            handler(false)
            return
        }
        if conversation.groupID == groupID {
            isJoinedGroup(completion: handler)
            return
        }
        bridge.isJoinedGroup(groupID: groupID, completion: handler)
    }

    private func addObservers() {
        observerTokens.append(
            eventBridge.observeConnectionSyncComplete { [weak self] in
                guard let self else {
                    return
                }
                self.startClientMsgID = nil
                self.isEnd = false
                let count = self.messageStorage.count < self.pageSize
                    ? 4 * self.pageSize
                    : self.messageStorage.count
                self.getHistoryMessageList(reverse: false, count: count) { [weak self] messages in
                    guard let self else {
                        return
                    }
                    self.messageStorage.removeAll()
                    self.messageStorage.append(contentsOf: messages)
                    self.delegate?.received(messages: messages, forceReload: true)
                }
            }
        )
        observerTokens.append(
            eventBridge.observeNewMessage { [weak self] message in
                guard let self else {
                    return
                }
                let syncState = IMController.shared.connectionRelay.value
                if syncState.status == .syncProgress, self.isCurrentConversationMessage(message) {
                    let count = self.messageStorage.count < self.pageSize
                        ? 4 * self.pageSize
                        : self.messageStorage.count
                    self.getHistoryMessageList(reverse: false, count: count) { [weak self] reloaded in
                        guard let self else {
                            return
                        }
                        self.receivedNewMessages(messages: reloaded, forceReload: true)
                    }
                    return
                }
                self.receivedNewMessages(messages: [message], forceReload: false)
            }
        )
        observerTokens.append(
            eventBridge.observeIsInGroupChanged { [weak self] isIn in
                self?.delegate?.isInGroup(with: isIn)
            }
        )
        observerTokens.append(
            eventBridge.observeJoinedGroupAdded { [weak self] info in
                guard
                    let self,
                    info.groupID == self.receiverId
                else {
                    return
                }
                self.delegate?.isInGroup(with: true)
            }
        )
        observerTokens.append(
            eventBridge.observeJoinedGroupDeleted { [weak self] info in
                guard
                    let self,
                    info.groupID == self.receiverId
                else {
                    return
                }
                self.delegate?.isInGroup(with: false)
            }
        )
        observerTokens.append(
            eventBridge.observeGroupMemberInfoChanged { [weak self] info in
                guard let self, info.groupID == self.receiverId else {
                    return
                }
                for index in self.messageStorage.indices where self.messageStorage[index].sendID == info.userID {
                    self.messageStorage[index].senderNickname = info.nickname
                    self.messageStorage[index].senderFaceURL = info.faceURL
                }
                self.delegate?.groupMemberInfoChanged(info: info)
            }
        )
        observerTokens.append(
            eventBridge.observeGroupInfoChanged { [weak self] info in
                guard info.groupID == self?.receiverId else {
                    return
                }
                self?.delegate?.groupInfoChanged(info: info)
            }
        )
        observerTokens.append(
            eventBridge.observeFriendInfoChanged { [weak self] info in
                guard let self, info.userID == self.receiverId else {
                    return
                }
                for index in self.messageStorage.indices where self.messageStorage[index].sendID == info.userID {
                    self.messageStorage[index].senderNickname = info.nickname ?? info.remark
                    self.messageStorage[index].senderFaceURL = info.faceURL
                }
                self.delegate?.friendInfoChanged(info: info)
            }
        )
        observerTokens.append(
            eventBridge.observeCurrentUserInfoChanged { [weak self] info in
                self?.delegate?.myUserInfoChanged(info: info)
            }
        )
        observerTokens.append(
            eventBridge.observeGroupMemberAdded { [weak self] info in
                guard info.groupID == self?.receiverId else {
                    return
                }
                self?.delegate?.groupMembersChanged(added: true, info: info)
            }
        )
        observerTokens.append(
            eventBridge.observeGroupMemberDeleted { [weak self] info in
                guard info.groupID == self?.receiverId else {
                    return
                }
                self?.delegate?.groupMembersChanged(added: false, info: info)
            }
        )
        observerTokens.append(
            eventBridge.observeTotalUnreadCountChanged { [weak self] count in
                self?.delegate?.unreadCountChanged(count: count)
            }
        )
        observerTokens.append(
            eventBridge.observeConversationChanged { [weak self] conversations in
                guard let self else {
                    return
                }
                guard let matched = conversations.first(where: {
                    $0.conversationID == self.conversation.conversationID
                }) else {
                    return
                }
                self.delegate?.conversationChanged(info: matched)
            }
        )
        observerTokens.append(
            eventBridge.observeRecordClear { [weak self] _ in
                self?.messageStorage.removeAll()
                self?.delegate?.clearMessage()
            }
        )
    }

    private func getHistoryMessageListFromStorage(
        loadInitial: Bool = false,
        reverse: Bool = false,
        completion: @escaping ([OpenIMDemoBaselineMessageInfo]) -> Void
    ) {
        if loadInitial {
            let count = reverse ? pageSize : pageSize * 4
            getHistoryMessageList(reverse: reverse, count: count) { [weak self] messages in
                guard let self else {
                    completion([])
                    return
                }
                self.messageStorage.append(contentsOf: messages)
                let result = Array(self.messageStorage.suffix(self.pageSize))
                self.messageStorage.removeLast(min(result.count, self.messageStorage.count))
                completion(result)
            }
            return
        }

        if !messageStorage.isEmpty {
            let result = Array(messageStorage.suffix(pageSize))
            messageStorage.removeLast(min(result.count, messageStorage.count))
            completion(result)
        }

        let fetchCount = messageStorage.isEmpty ? pageSize : (reverse ? pageSize : pageSize * 3)
        getHistoryMessageList(reverse: reverse, count: fetchCount) { [weak self] messages in
            guard let self else {
                completion([])
                return
            }
            if self.messageStorage.isEmpty {
                self.messageStorage.insert(contentsOf: messages, at: 0)
                let result = Array(self.messageStorage.suffix(self.pageSize))
                self.messageStorage.removeLast(min(result.count, self.messageStorage.count))
                completion(result)
            } else {
                self.messageStorage.insert(contentsOf: messages, at: 0)
            }
        }
    }

    private func getHistoryMessageList(
        reverse: Bool,
        count: Int,
        completion: @escaping ([OpenIMDemoBaselineMessageInfo]) -> Void
    ) {
        if reverse, reverseIsEnd {
            completion([])
            return
        }
        if !reverse, isEnd {
            completion([])
            return
        }

        let startID = reverse ? reverseStartClientMsgID : startClientMsgID
        let handler: (Bool, [OpenIMDemoBaselineMessageInfo]) -> Void = { [weak self] isEnd, messages in
            guard let self else {
                completion([])
                return
            }
            if reverse {
                self.reverseIsEnd = isEnd
                self.reverseStartClientMsgID = messages.last?.clientMsgID
            } else {
                self.isEnd = isEnd
                self.startClientMsgID = messages.first?.clientMsgID
            }
            completion(messages)
        }

        if reverse {
            bridge.getHistoryMessageListReverse(
                conversationID: conversation.conversationID,
                startClientMsgID: startID,
                count: count,
                completion: handler
            )
        } else {
            bridge.getHistoryMessageList(
                conversationID: conversation.conversationID,
                conversationType: conversation.conversationType,
                startClientMsgID: startID,
                count: count,
                completion: handler
            )
        }
    }

    private func isCurrentConversationMessage(_ message: OpenIMDemoBaselineMessageInfo) -> Bool {
        switch conversation.conversationType {
        case .c2c, .notification:
            return message.recvID == conversation.userID
        case .superGroup:
            return message.groupID == conversation.groupID
        case .undefine:
            return false
        }
    }

    private func receivedNewMessages(
        messages: [OpenIMDemoBaselineMessageInfo],
        forceReload: Bool = false
    ) {
        guard enableNewMessages else {
            return
        }
        OpenIMProbeLogger.log(
            "[OpenIMDemoBaselineChain] provider.receivedNewMessages " +
            "conversation=\(conversation.conversationID) " +
            "count=\(messages.count) forceReload=\(forceReload)"
        )
        if let last = messages.last {
            lastReadString = last.clientMsgID
            lastReceivedString = last.clientMsgID
            lastMessageIndex = messages.count
        }
        delegate?.received(messages: messages, forceReload: forceReload)
    }
}

typealias OpenIMDemoBaselineBuilderDataProviderShell = DefaultDataProvider
typealias OpenIMDemoBaselineDefaultDataProvider = DefaultDataProvider
typealias OpenIMDemoBaselineDefaultChatController = DefaultChatController
typealias OpenIMDemoBaselineDefaultChatCollectionDataSource = DefaultChatCollectionDataSource
typealias OpenIMDemoBaselineDefaultChatViewController = ChatViewController
typealias DataProviderDelegate = OpenIMDemoBaselineDataProviderDelegate
typealias DataProvider = OpenIMDemoBaselineDataProvider
typealias EditNotifier = OpenIMDemoBaselineBuilderEditNotifier
typealias SwipeNotifier = OpenIMDemoBaselineBuilderSwipeNotifier

final class DefaultChatController:
    DataProviderDelegate,
    ReloadDelegate {
    let dataProvider: DefaultDataProvider
    private let receiverId: String
    private let conversationType: OpenIMDemoBaselineConversationType
    let senderID: String
    private(set) var conversation: OpenIMDemoBaselineConversationInfo
    weak var delegate: ChatControllerDelegate?
    private(set) var messages: [OpenIMDemoBaselineMessageInfo] = []
    private var selecteMessages: [OpenIMDemoBaselineMessageInfo] = []
    private var selectedUsers: [String] = []
    private var isAdminOrOwner = false
    private(set) var groupInfo: OpenIMDemoBaselineGroupInfo?
    private(set) var groupMembers: [String: OpenIMDemoBaselineGroupMemberInfo] = [:]
    private(set) var otherInfo: OpenIMDemoBaselineFriendInfo?
    private(set) var myInfo: OpenIMDemoBaselineUserInfo?
    private(set) var unreadCount: Int = 0
    private(set) var isInGroup: Bool = true
    private var recvMessageIsCurrentChat = false
    private var isSynchronizingCurrentChatRead = false
    private let imBridge: OpenIMDemoBaselineIMControllerBridge

    init(
        dataProvider: DefaultDataProvider,
        senderID: String,
        conversation: OpenIMDemoBaselineConversationInfo
    ) {
        self.dataProvider = dataProvider
        self.receiverId = conversation.conversationType == .c2c
            ? (conversation.userID ?? "")
            : (conversation.groupID ?? "")
        self.conversationType = conversation.conversationType
        self.senderID = senderID
        self.conversation = conversation
        self.unreadCount = conversation.unreadCount
        self.imBridge = OpenIMDemoBaselineFactory.imControllerBridge
    }

    deinit {
        iLogger.print("\(type(of: self)) - \(#function)")
    }

    func loadInitialMessages(completion: @escaping ([OpenIMDemoBaselineSection]) -> Void) {
        dataProvider.loadInitialMessages { [weak self] messages in
            guard let self else {
                completion([])
                return
            }
            let hadUnreadBeforeInitialLoad = self.conversation.unreadCount != 0
            self.appendConvertingToMessages(messages, removeAll: true)
            self.markAllMessagesAsReceived { [weak self] in
                guard let self else {
                    completion([])
                    return
                }
                    self.markAllMessagesAsRead { [weak self] in
                        guard let self else {
                            completion([])
                            return
                        }
                        let sections = self.propagateLatestSections()
                        completion(sections)
                        self.bootstrapConversationDetailsAfterInitialLoad()
                        self.refreshTotalUnreadAfterCurrentChatReadIfNeeded(hadUnreadBeforeInitialLoad)
                    }
                }
        }
    }

    func getTitle() {
        switch conversationType {
        case .c2c:
            guard let userID = conversation.userID, !userID.isEmpty else {
                return
            }
            delegate?.friendInfoChanged(
                info: OpenIMDemoBaselineFriendInfo(
                    userID: userID,
                    nickname: conversation.showName,
                    faceURL: conversation.faceURL,
                    ownerUserID: nil,
                    remark: nil
                )
            )
        case .superGroup:
            guard let groupID = conversation.groupID, !groupID.isEmpty else {
                return
            }
            delegate?.groupInfoChanged(
                info: OpenIMDemoBaselineGroupInfo(
                    groupID: groupID,
                    groupName: conversation.showName,
                    faceURL: conversation.faceURL,
                    ownerUserID: nil,
                    memberCount: groupInfo?.memberCount ?? 0
                )
            )
        case .notification:
            delegate?.friendInfoChanged(
                info: OpenIMDemoBaselineFriendInfo(
                    userID: receiverId,
                    nickname: "SystemNotice",
                    faceURL: conversation.faceURL,
                    ownerUserID: nil,
                    remark: nil
                )
            )
        case .undefine:
            break
        }
    }

    func messageIsExsit(with id: String) -> Bool {
        messages.contains { $0.clientMsgID == id }
    }

    func defaultSelecteUsers(with usersID: [String]) {
        selectedUsers.append(contentsOf: usersID)
    }

    func defaultSelecteMessage(with id: String?, onlySelect _: Bool = false) {
        guard let id else {
            selecteMessages.removeAll()
            return
        }
        if let message = messages.first(where: { $0.clientMsgID == id }) {
            selecteMessages = [message]
        } else {
            selecteMessages.removeAll()
        }
    }

    func getConversation() -> OpenIMDemoBaselineConversationInfo {
        conversation
    }

    func getGroupMembers(
        userIDs: [String]?,
        memory: Bool,
        completion: @escaping ([OpenIMDemoBaselineGroupMemberInfo]) -> Void
    ) {
        if memory, let userIDs, !userIDs.isEmpty {
            let cached = userIDs.compactMap { groupMembers[$0] }
            if !cached.isEmpty {
                completion(cached)
                return
            }
        }
        dataProvider.getGroupMembers(userIDs: userIDs) { [weak self] members in
            for member in members {
                self?.groupMembers[member.userID] = member
            }
            completion(members)
        }
    }

    func getMessageInfo(ids: [String]) -> [OpenIMDemoBaselineMessageInfo] {
        messages.filter { ids.contains($0.clientMsgID) }
    }

    func getSelectedMessages() -> [OpenIMDemoBaselineMessageInfo] {
        selecteMessages
    }

    func getSelfInfo() -> OpenIMDemoBaselineUserInfo? {
        myInfo
    }

    func getIsAdminOrOwner() -> Bool {
        isAdminOrOwner
    }

    func loadPreviousMessages(completion: @escaping ([OpenIMDemoBaselineSection]) -> Void) {
        dataProvider.loadPreviousMessages { [weak self] messages in
            guard let self else {
                completion([])
                return
            }
            self.appendConvertingToMessages(messages)
            self.markAllMessagesAsReceived { [weak self] in
                guard let self else {
                    completion([])
                    return
                }
                self.markAllMessagesAsRead { [weak self] in
                    guard let self else {
                        completion([])
                        return
                    }
                    let sections = self.propagateLatestSections()
                    completion(sections)
                }
            }
        }
    }

    func loadMoreMessages(completion: @escaping ([OpenIMDemoBaselineSection]) -> Void) {
        dataProvider.loadMoreMessages { [weak self] messages in
            guard let self else {
                completion([])
                return
            }
            self.insertConvertingToMessages(messages)
            self.markAllMessagesAsReceived { [weak self] in
                guard let self else {
                    completion([])
                    return
                }
                self.markAllMessagesAsRead { [weak self] in
                    guard let self else {
                        completion([])
                        return
                    }
                    let sections = self.propagateLatestSections()
                    completion(sections)
                }
            }
        }
    }

    func received(messages: [OpenIMDemoBaselineMessageInfo], forceReload: Bool) {
        OpenIMProbeLogger.log(
            "[OpenIMDemoBaselineChain] controller.received " +
            "conversation=\(conversation.conversationID) " +
            "count=\(messages.count) forceReload=\(forceReload) existing=\(self.messages.count)"
        )
        if forceReload {
            recvMessageIsCurrentChat = !messages.isEmpty
            appendConvertingToMessages(messages, removeAll: true)
            markAllMessagesAsReceived { [weak self] in
                self?.markAllMessagesAsRead { [weak self] in
                    self?.repopulateMessages(triggerSource: .receive)
                }
            }
            return
        }

        guard let message = messages.first else {
            return
        }

        if isMessageInCurrentConversation(message) {
            recvMessageIsCurrentChat = true
            appendConvertingToMessages([message])
            markAllMessagesAsReceived { [weak self] in
                self?.markAllMessagesAsRead { [weak self] in
                    self?.repopulateMessages(triggerSource: .receive)
                }
            }
        } else {
            recvMessageIsCurrentChat = false
            if message.sendID != senderID {
                unreadCount += 1
            }
        }
    }

    private func isMessageInCurrentConversation(_ message: OpenIMDemoBaselineMessageInfo) -> Bool {
        switch conversation.conversationType {
        case .c2c, .notification:
            guard conversation.conversationType == message.sessionType else {
                return false
            }
            let peerUserID = conversation.userID
            let sentByPeer = message.sendID == peerUserID
            let sentByMeToPeer = message.sendID == senderID && message.recvID == peerUserID
            return sentByPeer || sentByMeToPeer
        case .superGroup:
            return message.sessionType == .superGroup && message.groupID == conversation.groupID
        case .undefine:
            return false
        }
    }

    private func accumulateUnreadIfNeeded(for messages: [OpenIMDemoBaselineMessageInfo]) {
        let increment = messages.reduce(into: 0) { partialResult, message in
            if shouldIncreaseUnread(for: message) {
                partialResult += 1
            }
        }
        guard increment > 0 else {
            return
        }
        unreadCount += increment
        conversation.unreadCount += increment
        propagateTotalUnreadCount()
    }

    private func shouldIncreaseUnread(for message: OpenIMDemoBaselineMessageInfo) -> Bool {
        guard !isMessageInCurrentConversation(message) else {
            return false
        }
        return message.sendID != senderID
    }

    func isInGroup(with isIn: Bool) {
        self.isInGroup = isIn
        delegate?.isInGroup(with: isIn)
    }

    func groupMemberInfoChanged(info: OpenIMDemoBaselineGroupMemberInfo) {
        if groupMembers[info.userID] != nil {
            groupMembers[info.userID] = info
        }
        let didChangeMessages = updateMessagesSenderInfo(
            userID: info.userID,
            nickname: info.nickname,
            faceURL: info.faceURL
        )
        if didChangeMessages {
            repopulateMessages(requiresIsolatedProcess: true)
        }
    }

    func groupInfoChanged(info: OpenIMDemoBaselineGroupInfo) {
        groupInfo = info
        delegate?.groupInfoChanged(info: info)
    }

    func friendInfoChanged(info: OpenIMDemoBaselineFriendInfo) {
        var didChangeMessages = false
        if info.userID == otherInfo?.userID {
            didChangeMessages = updateMessagesSenderInfo(
                userID: info.userID,
                nickname: info.nickname ?? info.remark,
                faceURL: info.faceURL
            )
            otherInfo = info
        }
        delegate?.friendInfoChanged(info: info)
        if didChangeMessages {
            repopulateMessages(requiresIsolatedProcess: true)
        }
    }

    func myUserInfoChanged(info: OpenIMDemoBaselineUserInfo) {
        myInfo = info
        _ = updateMessagesSenderInfo(
            userID: info.userID,
            nickname: info.nickname ?? info.remark,
            faceURL: info.faceURL
        )
        repopulateMessages(requiresIsolatedProcess: true)
    }

    func groupMembersChanged(added: Bool, info: OpenIMDemoBaselineGroupMemberInfo) {
        guard conversation.conversationType == .superGroup, info.groupID == conversation.groupID else {
            return
        }
        if added {
            groupMembers[info.userID] = info
        } else {
            groupMembers.removeValue(forKey: info.userID)
        }
    }

    func unreadCountChanged(count: Int) {
        unreadCount = count
        conversation.unreadCount = count
        if isSynchronizingCurrentChatRead {
            return
        }
        if !recvMessageIsCurrentChat {
            propagateTotalUnreadCount()
        }
    }

    func clearMessage() {
        messages.removeAll()
        repopulateMessages()
    }

    func conversationChanged(info: OpenIMDemoBaselineConversationInfo) {
        conversation = info
        if isSynchronizingCurrentChatRead {
            conversation.unreadCount = 0
            unreadCount = 0
            return
        }
        unreadCount = info.unreadCount
    }

    func reloadMessage(with id: String) {
        repopulateMessages(requiresIsolatedProcess: true)
    }

    func removeMessage(messageID: String, completion: (() -> Void)?) {
        repopulateMessages(requiresIsolatedProcess: true)
        completion?()
    }

    private func appendConvertingToMessages(
        _ rawMessages: [OpenIMDemoBaselineMessageInfo],
        removeAll: Bool = false
    ) {
        if removeAll {
            messages.removeAll()
        }

        guard !rawMessages.isEmpty else {
            return
        }

        messages.append(contentsOf: rawMessages)
        messages.sort {
            if $0.sendTime == $1.sendTime {
                return $0.clientMsgID < $1.clientMsgID
            }
            return $0.sendTime < $1.sendTime
        }
    }

    private func insertConvertingToMessages(_ rawMessages: [OpenIMDemoBaselineMessageInfo]) {
        guard !rawMessages.isEmpty else {
            return
        }

        var messages = messages
        messages.insert(contentsOf: rawMessages, at: 0)
        self.messages = messages.sorted {
            if $0.sendTime == $1.sendTime {
                return $0.clientMsgID < $1.clientMsgID
            }
            return $0.sendTime < $1.sendTime
        }
    }

    private func updateMessagesSenderInfo(
        userID: String,
        nickname: String?,
        faceURL: String?
    ) -> Bool {
        guard !userID.isEmpty else {
            return false
        }

        var didChange = false
        for index in messages.indices where messages[index].sendID == userID {
            let nextNickname = nickname ?? messages[index].senderNickname
            let nextFaceURL = faceURL ?? messages[index].senderFaceURL
            if messages[index].senderNickname != nextNickname || messages[index].senderFaceURL != nextFaceURL {
                messages[index].senderNickname = nextNickname
                messages[index].senderFaceURL = nextFaceURL
                didChange = true
            }
        }
        return didChange
    }

    private func repopulateMessages(
        requiresIsolatedProcess: Bool = false,
        triggerSource: OpenIMDemoBaselineUpdateTriggerSource = .externalUpdate
    ) {
        let sections = propagateLatestSections()
        OpenIMProbeLogger.log(
            "[OpenIMDemoBaselineChain] controller.repopulateMessages " +
            "conversation=\(conversation.conversationID) " +
            "trigger=\(triggerSource.rawValue) isolated=\(requiresIsolatedProcess) " +
            "messages=\(messages.count) sections=\(sections.count)"
        )
        switch triggerSource {
        case .receive:
            delegate?.updateFromReceive(
                with: sections,
                requiresIsolatedProcess: requiresIsolatedProcess
            )
        default:
            delegate?.update(
                with: sections,
                requiresIsolatedProcess: requiresIsolatedProcess
            )
        }
    }

    private func markAllMessagesAsReceived(completion: @escaping () -> Void) {
        completion()
    }

    private func markAllMessagesAsRead(completion: @escaping () -> Void) {
        completion()
    }

    private func propagateTotalUnreadCount() {
        delegate?.updateUnreadCount(count: unreadCount)
    }

    private func bootstrapConversationDetailsAfterInitialLoad() {
        propagateConversationTitleFallback()

        switch conversation.conversationType {
        case .c2c, .notification:
            refreshOtherAndSelfInfo()
        case .superGroup:
            refreshGroupInfo(force: true)
            refreshGroupMembers(userIDs: nil, memory: false)
        case .undefine:
            break
        }
    }

    private func refreshTotalUnreadAfterCurrentChatReadIfNeeded(_ hadUnreadBeforeInitialLoad: Bool) {
        guard hadUnreadBeforeInitialLoad else {
            return
        }
        isSynchronizingCurrentChatRead = true
        markMessageAsReaded { [weak self] in
            guard let self else {
                return
            }
            self.isSynchronizingCurrentChatRead = false
            self.recvMessageIsCurrentChat = false
            self.propagateTotalUnreadCount()
        }
    }

    func markMessageAsReaded(
        messageID: String? = nil,
        completion: (() -> Void)? = nil
    ) {
        if messageID == nil, conversation.unreadCount == 0 {
            completion?()
            return
        }
        unreadCount = 0
        conversation.unreadCount = 0
        if let messageID, let index = messages.firstIndex(where: { $0.clientMsgID == messageID }) {
            messages[index].isRead = true
        }
        completion?()
    }

    func clearUnreadCount() {
        guard conversation.unreadCount > 0 || unreadCount > 0 else {
            return
        }
        unreadCount = 0
        conversation.unreadCount = 0
    }

    func sendTextMessage(_ text: String, completion: @escaping ([OpenIMDemoBaselineSection]) -> Void) {
        let messageText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !messageText.isEmpty else {
            completion(propagateLatestSections())
            return
        }
        OpenIMProbeLogger.log(
            "[OpenIMDemoBaselineChain] controller.sendTextMessage start " +
            "conversation=\(conversation.conversationID) textLength=\(messageText.count)"
        )

        Task { @MainActor [weak self] in
            guard let self else {
                completion([])
                return
            }

            do {
                let sent = try await OpenIMSession.shared.sendTextMessage(
                    conversationID: self.conversation.conversationID,
                    content: messageText
                )

                if let sent {
                    let seed = OpenIMDemoBaselineConversationSeed(conversationInfo: self.conversation)
                    let sentMessage = self.imBridge.messageInfo(from: sent, seed: seed)
                    self.appendConvertingToMessages([sentMessage])
                    let sections = self.propagateLatestSections()
                    OpenIMProbeLogger.log(
                        "[OpenIMDemoBaselineChain] controller.sendTextMessage success " +
                        "conversation=\(self.conversation.conversationID) " +
                        "clientMsgID=\(sentMessage.clientMsgID) messages=\(self.messages.count) sections=\(sections.count)"
                    )
                    completion(sections)
                    return
                }

                OpenIMProbeLogger.log(
                    "[OpenIMDemoBaselineChain] controller.sendTextMessage success-empty " +
                    "conversation=\(self.conversation.conversationID)"
                )
                completion(self.propagateLatestSections())
            } catch {
                iLogger.print("DefaultChatController.sendTextMessage failed: \(error.localizedDescription)")
                OpenIMProbeLogger.log(
                    "[OpenIMDemoBaselineChain] controller.sendTextMessage failed " +
                    "conversation=\(self.conversation.conversationID) error=\(error.localizedDescription)"
                )
                completion(self.propagateLatestSections())
            }
        }
    }

    func sendImageMessage(
        fileURL: URL,
        completion: @escaping ([OpenIMDemoBaselineSection]) -> Void
    ) {
        sendMediaMessage(
            fileURL: fileURL,
            kind: "image",
            send: { conversationID in
                try await OpenIMSession.shared.sendImageMessage(
                    conversationID: conversationID,
                    fileURL: fileURL
                )
            },
            completion: completion
        )
    }

    func sendVideoMessage(
        fileURL: URL,
        completion: @escaping ([OpenIMDemoBaselineSection]) -> Void
    ) {
        sendMediaMessage(
            fileURL: fileURL,
            kind: "video",
            send: { conversationID in
                try await OpenIMSession.shared.sendVideoMessage(
                    conversationID: conversationID,
                    fileURL: fileURL
                )
            },
            completion: completion
        )
    }

    private func sendMediaMessage(
        fileURL: URL,
        kind: String,
        send: @escaping (_ conversationID: String) async throws -> ChatMessage?,
        completion: @escaping ([OpenIMDemoBaselineSection]) -> Void
    ) {
        OpenIMProbeLogger.log(
            "[OpenIMDemoBaselineChain] controller.sendMediaMessage start " +
            "conversation=\(conversation.conversationID) kind=\(kind) file=\(fileURL.lastPathComponent)"
        )

        Task { @MainActor [weak self] in
            guard let self else {
                completion([])
                return
            }

            do {
                let sent = try await send(self.conversation.conversationID)
                if let sent {
                    let seed = OpenIMDemoBaselineConversationSeed(conversationInfo: self.conversation)
                    let sentMessage = self.imBridge.messageInfo(from: sent, seed: seed)
                    self.appendConvertingToMessages([sentMessage])
                    let sections = self.propagateLatestSections()
                    OpenIMProbeLogger.log(
                        "[OpenIMDemoBaselineChain] controller.sendMediaMessage success " +
                        "conversation=\(self.conversation.conversationID) kind=\(kind) " +
                        "clientMsgID=\(sentMessage.clientMsgID) messages=\(self.messages.count) sections=\(sections.count)"
                    )
                    completion(sections)
                    return
                }

                OpenIMProbeLogger.log(
                    "[OpenIMDemoBaselineChain] controller.sendMediaMessage success-empty " +
                    "conversation=\(self.conversation.conversationID) kind=\(kind)"
                )
                completion(self.propagateLatestSections())
            } catch {
                iLogger.print("DefaultChatController.sendMediaMessage(\(kind)) failed: \(error.localizedDescription)")
                OpenIMProbeLogger.log(
                    "[OpenIMDemoBaselineChain] controller.sendMediaMessage failed " +
                    "conversation=\(self.conversation.conversationID) kind=\(kind) error=\(error.localizedDescription)"
                )
                completion(self.propagateLatestSections())
            }
        }
    }

    private func propagateConversationTitleFallback() {
        switch conversation.conversationType {
        case .c2c:
            guard let userID = conversation.userID, !userID.isEmpty else {
                return
            }
            delegate?.friendInfoChanged(
                info: OpenIMDemoBaselineFriendInfo(
                    userID: userID,
                    nickname: conversation.showName,
                    faceURL: conversation.faceURL,
                    ownerUserID: nil,
                    remark: nil
                )
            )
        case .superGroup:
            guard let groupID = conversation.groupID, !groupID.isEmpty else {
                return
            }
            delegate?.groupInfoChanged(
                info: OpenIMDemoBaselineGroupInfo(
                    groupID: groupID,
                    groupName: conversation.showName,
                    faceURL: conversation.faceURL,
                    ownerUserID: nil,
                    memberCount: groupInfo?.memberCount ?? 0
                )
            )
        case .notification:
            let userID = conversation.userID ?? conversation.conversationID
            delegate?.friendInfoChanged(
                info: OpenIMDemoBaselineFriendInfo(
                    userID: userID,
                    nickname: "SystemNotice",
                    faceURL: conversation.faceURL,
                    ownerUserID: nil,
                    remark: nil
                )
            )
        case .undefine:
            break
        }
    }

    private func refreshOtherAndSelfInfo() {
        dataProvider.getUserInfo { [weak self] friends, me in
            guard let self else {
                return
            }

            var didChangeMessages = false

            if let friend = friends.first {
                if friend.userID == self.otherInfo?.userID {
                    didChangeMessages = self.updateMessagesSenderInfo(
                        userID: friend.userID,
                        nickname: friend.nickname ?? friend.remark,
                        faceURL: friend.faceURL
                    ) || didChangeMessages
                }
                self.otherInfo = friend
                self.delegate?.friendInfoChanged(info: friend)
            } else if let userID = self.conversation.userID, !userID.isEmpty {
                let fallback = OpenIMDemoBaselineFriendInfo(
                    userID: userID,
                    nickname: self.conversation.showName,
                    faceURL: self.conversation.faceURL,
                    ownerUserID: nil,
                    remark: nil
                )
                if fallback.userID == self.otherInfo?.userID {
                    didChangeMessages = self.updateMessagesSenderInfo(
                        userID: fallback.userID,
                        nickname: fallback.nickname ?? fallback.remark,
                        faceURL: fallback.faceURL
                    ) || didChangeMessages
                }
                self.otherInfo = fallback
                self.delegate?.friendInfoChanged(info: fallback)
            }

            if let me {
                self.myInfo = me
                didChangeMessages = self.updateMessagesSenderInfo(
                    userID: me.userID,
                    nickname: me.nickname ?? me.remark,
                    faceURL: me.faceURL
                ) || didChangeMessages
            }

            if didChangeMessages {
                self.repopulateMessages(requiresIsolatedProcess: true)
            }
        }
    }

    private func refreshGroupInfo(force: Bool) {
        if !force, let groupInfo {
            delegate?.groupInfoChanged(info: groupInfo)
            return
        }

        dataProvider.getGroupInfo { [weak self] group in
            guard let self else {
                return
            }
            self.groupInfoChanged(info: group)
            self.repopulateMessages(requiresIsolatedProcess: true)
        }
    }

    private func refreshGroupMembers(userIDs: [String]?, memory: Bool) {
        if memory, let userIDs, !userIDs.isEmpty {
            let cachedMembers = userIDs.compactMap { groupMembers[$0] }
            guard !cachedMembers.isEmpty else {
                return
            }
            applyGroupMembers(cachedMembers)
            return
        }

        dataProvider.getGroupMembers(userIDs: userIDs) { [weak self] members in
            self?.applyGroupMembers(members)
        }
    }

    private func applyGroupMembers(_ members: [OpenIMDemoBaselineGroupMemberInfo]) {
        guard !members.isEmpty else {
            return
        }

        for member in members {
            groupMembers[member.userID] = member
            _ = updateMessagesSenderInfo(
                userID: member.userID,
                nickname: member.nickname,
                faceURL: member.faceURL
            )
        }

        repopulateMessages(requiresIsolatedProcess: true)
    }

    private func propagateLatestSections() -> [OpenIMDemoBaselineSection] {
        guard !messages.isEmpty else {
            return [OpenIMDemoBaselineSection(id: 0, title: "", cells: [])]
        }

        var cells: [OpenIMDemoBaselineCell] = []
        var lastDateBucket: String?

        for message in messages {
            let dateBucket = sectionDateString(for: message.sendTime)
            if lastDateBucket != dateBucket {
                cells.append(.date(dateBucket))
                lastDateBucket = dateBucket
            }
            cells.append(.message(message))
        }

        return [OpenIMDemoBaselineSection(id: 0, title: "", cells: cells)]
    }

    private func sectionDateString(for sendTime: TimeInterval) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HH"
        return formatter.string(from: Date(timeIntervalSince1970: sendTime / 1000))
    }
}

final class DefaultChatCollectionDataSource: NSObject, UICollectionViewDataSource, ChatLayoutDelegate {
    var sections: [OpenIMDemoBaselineSection] = [] {
        didSet {
            oldSections = oldValue
        }
    }
    var mediaImageViews: [String: Int] = [:]

    let editNotifier: OpenIMDemoBaselineBuilderEditNotifier
    let swipeNotifier: OpenIMDemoBaselineBuilderSwipeNotifier
    let reloadDelegate: ReloadDelegate
    let editingDelegate: ReloadDelegate
    let currentUserID: String
    weak var gestureDelegate: GestureDelegate?
    private var oldSections: [OpenIMDemoBaselineSection] = []

    init(
        editNotifier: OpenIMDemoBaselineBuilderEditNotifier,
        swipeNotifier: OpenIMDemoBaselineBuilderSwipeNotifier,
        reloadDelegate: ReloadDelegate,
        editingDelegate: ReloadDelegate
    ) {
        self.editNotifier = editNotifier
        self.swipeNotifier = swipeNotifier
        self.reloadDelegate = reloadDelegate
        self.editingDelegate = editingDelegate
        self.currentUserID = OpenIMDemoBaselineFactory.dataProviderBridge.currentUserID ?? ""
    }

    deinit {
        iLogger.print("\(type(of: self)) - \(#function)")
    }

    func prepare(with collectionView: UICollectionView) {
        collectionView.register(
            OpenIMDemoBaselineDateCollectionViewCell.self,
            forCellWithReuseIdentifier: OpenIMDemoBaselineDateCollectionViewCell.reuseIdentifier
        )
        collectionView.register(
            OpenIMDemoBaselineMessageCollectionViewCell.self,
            forCellWithReuseIdentifier: OpenIMDemoBaselineMessageCollectionViewCell.reuseIdentifier
        )
    }

    func didSelectItemAt(_ collectionView: UICollectionView, indexPath: IndexPath) {
        guard
            sections.indices.contains(indexPath.section),
            sections[indexPath.section].cells.indices.contains(indexPath.item)
        else {
            return
        }
        guard case let .message(message) = sections[indexPath.section].cells[indexPath.item] else {
            return
        }
        gestureDelegate?.didTapContent(with: message.clientMsgID, data: message)
        _ = collectionView
    }

    func numberOfSections(in collectionView: UICollectionView) -> Int {
        _ = collectionView
        return sections.count
    }

    func collectionView(
        _ collectionView: UICollectionView,
        numberOfItemsInSection section: Int
    ) -> Int {
        _ = collectionView
        guard sections.indices.contains(section) else {
            return 0
        }
        return sections[section].cells.count
    }

    func collectionView(
        _ collectionView: UICollectionView,
        cellForItemAt indexPath: IndexPath
    ) -> UICollectionViewCell {
        guard sections.indices.contains(indexPath.section),
              sections[indexPath.section].cells.indices.contains(indexPath.item) else {
            return collectionView.dequeueReusableCell(
                withReuseIdentifier: OpenIMDemoBaselineDateCollectionViewCell.reuseIdentifier,
                for: indexPath
            )
        }

        switch sections[indexPath.section].cells[indexPath.item] {
        case let .date(text):
            let cell = collectionView.dequeueReusableCell(
                withReuseIdentifier: OpenIMDemoBaselineDateCollectionViewCell.reuseIdentifier,
                for: indexPath
            ) as! OpenIMDemoBaselineDateCollectionViewCell
            cell.configure(text: text)
            return cell

        case let .message(message):
            let cell = collectionView.dequeueReusableCell(
                withReuseIdentifier: OpenIMDemoBaselineMessageCollectionViewCell.reuseIdentifier,
                for: indexPath
            ) as! OpenIMDemoBaselineMessageCollectionViewCell
            cell.configure(
                message: message,
                isOutgoing: message.sendID == currentUserID
            )
            let previewTag = mediaViewTag(for: message.clientMsgID)
            cell.previewSourceView.tag = previewTag
            if message.contentType == .image || message.contentType == .video {
                mediaImageViews[message.clientMsgID] = previewTag
            } else {
                mediaImageViews.removeValue(forKey: message.clientMsgID)
            }
            return cell
        }
    }

    private func mediaViewTag(for messageID: String) -> Int {
        var hasher = Hasher()
        hasher.combine(messageID)
        let raw = hasher.finalize()
        let normalized = raw == Int.min ? 0 : abs(raw)
        return 600_000 + (normalized % 300_000)
    }

    func alignmentForItem(
        _ chatLayout: CollectionViewChatLayout,
        of kind: ItemKind,
        at indexPath: IndexPath
    ) -> ChatItemAlignment {
        _ = chatLayout
        guard kind == .cell,
              sections.indices.contains(indexPath.section),
              sections[indexPath.section].cells.indices.contains(indexPath.item) else {
            return .fullWidth
        }
        switch sections[indexPath.section].cells[indexPath.item] {
        case .date:
            return .center
        case let .message(message):
            return message.sendID == currentUserID ? .trailing : .leading
        }
    }

    func sizeForItem(
        _ chatLayout: CollectionViewChatLayout,
        of kind: ItemKind,
        at indexPath: IndexPath
    ) -> ItemSize {
        _ = chatLayout
        guard kind == .cell,
              sections.indices.contains(indexPath.section),
              sections[indexPath.section].cells.indices.contains(indexPath.item) else {
            return .estimated(CGSize(width: 120, height: 44))
        }
        switch sections[indexPath.section].cells[indexPath.item] {
        case .date:
            return .exact(CGSize(width: 180, height: 28))
        case .message:
            return .estimated(CGSize(width: 280, height: 72))
        }
    }
}

@MainActor
final class ChatViewController:
    UIViewController,
    ChatControllerDelegate,
    GestureDelegate,
    UICollectionViewDelegate,
    UITextViewDelegate {
    private enum InterfaceAction: Hashable {
        case changingKeyboardFrame
        case changingContentInsets
        case changingFrameSize
        case sendingMessage
        case scrollingToTop
        case scrollingToBottom
        case updatingCollection
        case updatingCollectionInIsolation
    }

    private enum ControllerAction: Hashable {
        case loadingInitialMessages
        case loadingPreviousMessages
        case loadingMoreMessages
        case updatingCollection
    }

    private enum ReactionType {
        case delayedUpdate
    }

    private enum UpdateApplicationPath: String {
        case initialReload = "initial-reload"
        case forcedReload = "forced-reload"
        case fallbackReload = "fallback-reload"
        case lightweightReloadOnly = "lightweight-reload-only"
        case lightweightBatch = "lightweight-batch"
    }

    private enum UpdateMutationKind: String {
        case reloadOnly = "reload-only"
        case prepend = "prepend"
        case append = "append"
        case trimTop = "trim-top"
        case trimBottom = "trim-bottom"
        case mixed = "mixed"
    }

    private let chatController: DefaultChatController
    private let dataSource: DefaultChatCollectionDataSource
    private let seed: OpenIMDemoBaselineConversationSeed
    private let hiddenInputBar: Bool
    private let scrollToTop: Bool
    private let titleView = OpenIMDemoBaselineNavigationTitleView()
    private let showDebugOverlay = ProcessInfo.processInfo.environment["RAVER_OPENIM_BASELINE_DEBUG_OVERLAY"] == "1"
    private var ignoreInterfaceActions = true
    private var sections: [OpenIMDemoBaselineSection] = []
    private var currentInterfaceActions: SetActor<Set<InterfaceAction>, ReactionType> = SetActor()
    private var currentControllerActions: SetActor<Set<ControllerAction>, ReactionType> = SetActor()
    private var nextAppliedUpdateSequence = 0
    private var lastAppliedUpdateSummary = "seq=0|trigger=-|path=-|mutation=-|isolated=false"
    private let chatLayout = CollectionViewChatLayout()
    private lazy var collectionView = UICollectionView(
        frame: .zero,
        collectionViewLayout: chatLayout
    )
    private let contentStackView = UIStackView()
    private let stateLabel = UILabel()
    private let inputBarShell = UIView()
    private let inputBarHairline = UIView()
    private let inputTextView = UITextView()
    private let inputMediaButton = UIButton(type: .system)
    private let inputSendButton = UIButton(type: .system)
    private let inputPlaceholderLabel = UILabel()
    private lazy var settingButton: UIBarButtonItem = {
        let item = UIBarButtonItem(
            image: UIImage(nameInBundle: "common_more_btn_icon"),
            style: .done,
            target: self,
            action: #selector(settingButtonAction)
        )
        item.tintColor = .black
        return item
    }()
    private lazy var mediaButton: UIBarButtonItem = {
        let item = UIBarButtonItem(
            image: UIImage(nameInBundle: "chat_call_btn_icon"),
            style: .done,
            target: self,
            action: #selector(mediaButtonAction)
        )
        item.tintColor = .black
        item.imageInsets = UIEdgeInsets(top: 0, left: 18, bottom: 0, right: 0)
        return item
    }()
    private var inputBarBottomConstraint: NSLayoutConstraint?
    private var contentStackViewBottomConstraint: NSLayoutConstraint?
    private var inputTextViewHeightConstraint: NSLayoutConstraint?
    private var lastContentOffset: CGFloat = 0
    private var animator: OpenIMDemoBaselineManualAnimator?
    private var keepContentOffsetAtBottom = true {
        didSet {
            chatLayout.keepContentOffsetAtBottomOnBatchUpdates = keepContentOffsetAtBottom
        }
    }

    init(
        chatController: DefaultChatController,
        dataSource: DefaultChatCollectionDataSource,
        hiddenInputBar: Bool,
        scrollToTop: Bool
    ) {
        self.chatController = chatController
        self.seed = OpenIMDemoBaselineConversationSeed(conversationInfo: chatController.conversation)
        self.hiddenInputBar = hiddenInputBar
        self.scrollToTop = scrollToTop
        self.dataSource = dataSource
        super.init(nibName: nil, bundle: nil)
        _ = dataSource
    }

    convenience init(
        chatController: DefaultChatController,
        dataSource: DefaultChatCollectionDataSource,
        editNotifier: OpenIMDemoBaselineBuilderEditNotifier,
        swipeNotifier: OpenIMDemoBaselineBuilderSwipeNotifier,
        hiddenInputBar: Bool,
        scrollToTop: Bool
    ) {
        _ = editNotifier
        _ = swipeNotifier
        self.init(
            chatController: chatController,
            dataSource: dataSource,
            hiddenInputBar: hiddenInputBar,
            scrollToTop: scrollToTop
        )
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        iLogger.print(
            "[OpenIMDemoBaselineRoute] lifecycle=viewDidLoad conversation=\(seed.businessConversationID)"
        )
        view.backgroundColor = UIColor(RaverTheme.background)
        title = seed.title
        setupNavigationBar()
        setupCollectionView()
        setupRefreshControl()
        setupStateLabel()
        setupInputBarShell()
        if !hiddenInputBar {
            KeyboardListener.shared.add(delegate: self)
        }
        loadInitialMessages()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        iLogger.print(
            "[OpenIMDemoBaselineRoute] lifecycle=viewDidAppear conversation=\(seed.businessConversationID)"
        )
        collectionView.collectionViewLayout.invalidateLayout()
        if !scrollToTop {
            scrollToLatestMessageIfNeeded(animated: false)
        }
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        iLogger.print(
            "[OpenIMDemoBaselineRoute] lifecycle=viewDidDisappear conversation=\(seed.businessConversationID)"
        )
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        if currentInterfaceActions.options.contains(.changingContentInsets) {
            return
        }
        inputTextView.textContainerInset = UIEdgeInsets(top: 10, left: 2, bottom: 10, right: 2)
    }

    func update(with sections: [OpenIMDemoBaselineSection], requiresIsolatedProcess: Bool) {
        OpenIMProbeLogger.log(
            "[OpenIMDemoBaselineChain] view.update " +
            "conversation=\(seed.businessConversationID) " +
            "sections=\(sections.count) isolated=\(requiresIsolatedProcess)"
        )
        processUpdates(
            with: sections,
            animated: true,
            requiresIsolatedProcess: requiresIsolatedProcess,
            triggerSource: .externalUpdate
        )
    }

    func updateFromReceive(with sections: [OpenIMDemoBaselineSection], requiresIsolatedProcess: Bool) {
        OpenIMProbeLogger.log(
            "[OpenIMDemoBaselineChain] view.updateFromReceive " +
            "conversation=\(seed.businessConversationID) " +
            "sections=\(sections.count) isolated=\(requiresIsolatedProcess)"
        )
        processUpdates(
            with: sections,
            animated: true,
            requiresIsolatedProcess: requiresIsolatedProcess,
            triggerSource: .receive
        )
    }

    func updateUnreadCount(count: Int) {
        renderState(extra: "unread=\(count)")
    }

    func groupInfoChanged(info: OpenIMDemoBaselineGroupInfo) {
        if info.groupName?.isEmpty == false {
            title = info.groupName
        }
        titleView.mainLabel.text = info.groupName
        titleView.mainTailLabel.text = "(\(info.memberCount))"
        titleView.mainTailLabel.isHidden = false
        if !hiddenInputBar {
            setRightButtons(show: isGroupSettingsVisible(for: info))
            settingButton.isEnabled = info.memberCount > 0
        }
        renderState(extra: "groupInfoChanged=1")
    }

    func friendInfoChanged(info: OpenIMDemoBaselineFriendInfo) {
        if let nickname = info.nickname ?? info.remark, !nickname.isEmpty {
            title = nickname
        }
        titleView.mainLabel.text = info.nickname ?? info.remark ?? seed.title
        titleView.mainTailLabel.text = nil
        titleView.mainTailLabel.isHidden = true
        if !hiddenInputBar {
            setRightButtons(show: chatController.getConversation().conversationType == .c2c)
            settingButton.isEnabled = true
        }
        renderState(extra: "friendInfoChanged=1")
    }

    func didTapContent(with id: String, data: OpenIMDemoBaselineMessageInfo) {
        switch data.contentType {
        case .image, .video:
            previewMedia(id: id, data: data)
        case .file:
            if let url = resolveURL(from: data) {
                UIApplication.shared.open(url)
                renderState(extra: "tap=\(id)|type=\(data.contentType.rawValue)|action=open-file")
            } else {
                renderState(extra: "tap=\(id)|type=\(data.contentType.rawValue)|action=file-url-missing")
            }
        default:
            if let url = resolveTextLink(from: data.content) {
                UIApplication.shared.open(url)
                renderState(extra: "tap=\(id)|type=\(data.contentType.rawValue)|action=open-url")
                return
            }
            renderState(extra: "tap=\(id)|type=\(data.contentType.rawValue)")
        }
    }

    private func resolveTextLink(from raw: String?) -> URL? {
        guard let raw else { return nil }
        let normalized = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty,
              let url = URL(string: normalized),
              let scheme = url.scheme?.lowercased(),
              ["http", "https"].contains(scheme) else {
            return nil
        }
        return url
    }

    private func resolveURL(from message: OpenIMDemoBaselineMessageInfo) -> URL? {
        let candidates = [
            message.media?.mediaURL,
            message.content
        ].compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        for value in candidates {
            if let parsed = parseURLOrPath(value) {
                return parsed
            }
        }
        return nil
    }

    private func parseURLOrPath(_ raw: String) -> URL? {
        if let url = URL(string: raw), url.scheme != nil {
            return url
        }
        if raw.hasPrefix("/") {
            return URL(fileURLWithPath: raw)
        }
        return nil
    }

    private func configMediaResource(id: String, data: OpenIMDemoBaselineMessageInfo) -> MediaResource? {
        guard let mediaURL = resolveURL(from: data) else {
            return nil
        }
        let thumbURL = data.media?.thumbnailURL
            .flatMap { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .flatMap(parseURLOrPath)
        let fileSize = data.media?.fileSizeBytes ?? 0

        switch data.contentType {
        case .image:
            return MediaResource(
                thumbUrl: thumbURL ?? mediaURL,
                url: mediaURL,
                type: .image,
                ID: id,
                fileSize: fileSize
            )
        case .video:
            return MediaResource(
                thumbUrl: thumbURL,
                url: mediaURL,
                type: .video,
                ID: id,
                fileSize: fileSize
            )
        default:
            return nil
        }
    }

    private func previewMedia(id: String, data: OpenIMDemoBaselineMessageInfo) {
        guard let item = configMediaResource(id: id, data: data) else {
            renderState(extra: "tap=\(id)|type=\(data.contentType.rawValue)|action=preview-missing")
            return
        }

        let controller = MediaPreviewViewController(resources: [item])
        controller.showIn(controller: self) { [weak self] _ in
            guard let self else { return nil }
            guard let tag = self.dataSource.mediaImageViews[id] else { return nil }
            return self.collectionView.viewWithTag(tag)
        }
        renderState(extra: "tap=\(id)|type=\(data.contentType.rawValue)|action=preview")
    }

    func collectionView(
        _ collectionView: UICollectionView,
        didSelectItemAt indexPath: IndexPath
    ) {
        dataSource.didSelectItemAt(collectionView, indexPath: indexPath)
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        lastContentOffset = scrollView.contentOffset.y

        guard !currentControllerActions.options.contains(.loadingInitialMessages),
              !currentControllerActions.options.contains(.loadingPreviousMessages),
              !currentControllerActions.options.contains(.loadingMoreMessages),
              !currentInterfaceActions.options.contains(.scrollingToTop),
              !currentInterfaceActions.options.contains(.scrollingToBottom) else {
            return
        }

        if currentControllerActions.options.contains(.updatingCollection), collectionView.isDragging {
            UIView.performWithoutAnimation {
                self.collectionView.performBatchUpdates({}, completion: { _ in
                    let context = ChatLayoutInvalidationContext()
                    context.invalidateLayoutMetrics = false
                    self.collectionView.collectionViewLayout.invalidateLayout(with: context)
                })
            }
        }

        if scrollView.contentOffset.y <= -scrollView.adjustedContentInset.top + scrollView.bounds.height {
            loadPreviousMessages()
            return
        }

        if !currentControllerActions.options.contains(.loadingPreviousMessages), !keepContentOffsetAtBottom {
            chatLayout.keepContentOffsetAtBottomOnBatchUpdates = collectionViewIsAtBottom
        }

        let contentOffsetY = scrollView.contentOffset.y
        let contentSizeHeight = scrollView.contentSize.height
        let scrollViewHeight = scrollView.bounds.height
        let footerViewY = max(contentSizeHeight, scrollViewHeight) + scrollView.contentInset.bottom
        let footerViewFullAppearance = contentOffsetY + scrollViewHeight
        let canTriggerLoadMore = footerViewFullAppearance - footerViewY - 50 > 0

        if scrollView.isDragging, canTriggerLoadMore {
            loadMoreMessages()
        }
    }

    func scrollViewShouldScrollToTop(_ scrollView: UIScrollView) -> Bool {
        guard scrollView.contentSize.height > 0,
              !currentInterfaceActions.options.contains(.scrollingToTop),
              !currentInterfaceActions.options.contains(.scrollingToBottom) else {
            return false
        }
        currentInterfaceActions.options.insert(.scrollingToTop)
        return true
    }

    func scrollViewDidScrollToTop(_ scrollView: UIScrollView) {
        guard !currentControllerActions.options.contains(.loadingInitialMessages),
              !currentControllerActions.options.contains(.loadingPreviousMessages) else {
            return
        }
        currentInterfaceActions.options.remove(.scrollingToTop)
        loadPreviousMessages()
    }

    private func renderState(extra: String? = nil) {
        guard showDebugOverlay else {
            return
        }
        let messageCells = sections.flatMap(\.cells).compactMap { cell -> OpenIMDemoBaselineMessageInfo? in
            guard case let .message(message) = cell else {
                return nil
            }
            return message
        }
        let dateCells = sections.flatMap(\.cells).filter {
            if case .date = $0 { return true }
            return false
        }.count

        let extraLine = extra.map { "\n\($0)" } ?? ""
        stateLabel.text = """
        conversation=\(seed.businessConversationID)
        kind=\(seed.sessionKind)
        sections=\(sections.count)
        dateCells=\(dateCells)
        messageCells=\(messageCells.count)
        unread=\(chatController.unreadCount)
        isInGroup=\(chatController.isInGroup)
        update=\(lastAppliedUpdateSummary)\(extraLine)
        """
    }

    private func setRightButtons(show: Bool) {
        guard !hiddenInputBar else {
            navigationItem.rightBarButtonItems = nil
            return
        }

        if show {
            navigationItem.rightBarButtonItems = chatController.getConversation().conversationType == .superGroup
                ? [settingButton]
                : [settingButton, mediaButton]
        } else {
            navigationItem.rightBarButtonItems = nil
        }
    }

    private func setupNavigationBar() {
        chatController.getTitle()
        navigationItem.titleView = titleView
        setRightButtons(show: chatController.getConversation().conversationType == .c2c)
        if let navigationBar = navigationController?.navigationBar,
           navigationBar.viewWithTag(991_001) == nil {
            let underline = UIView()
            underline.tag = 991_001
            underline.backgroundColor = .cE8EAEF
            underline.translatesAutoresizingMaskIntoConstraints = false
            navigationBar.addSubview(underline)
            NSLayoutConstraint.activate([
                underline.heightAnchor.constraint(equalToConstant: 1),
                underline.leadingAnchor.constraint(equalTo: navigationBar.leadingAnchor),
                underline.trailingAnchor.constraint(equalTo: navigationBar.trailingAnchor),
                underline.bottomAnchor.constraint(equalTo: navigationBar.bottomAnchor)
            ])
        }
    }

    private func isGroupSettingsVisible(for info: OpenIMDemoBaselineGroupInfo) -> Bool {
        info.memberCount > 0 && chatController.isInGroup
    }

    @objc
    private func mediaButtonAction() {
        showMediaSendSheet()
    }

    @objc
    private func settingButtonAction() {
        let conversation = chatController.getConversation()
        switch conversation.conversationType {
        case .c2c:
            let viewModel = SingleChatSettingViewModel(
                conversation: makeOUICoreConversationInfo(from: conversation),
                userInfo: makeOUICoreUserInfo(
                    from: OpenIMDemoBaselineFriendInfo(
                        userID: conversation.userID ?? "",
                        nickname: conversation.showName,
                        faceURL: conversation.faceURL,
                        ownerUserID: nil,
                        remark: nil
                    )
                )
            )
            let vc = SingleChatSettingTableViewController(viewModel: viewModel, style: .grouped)
            navigationController?.pushViewController(vc, animated: true)
            renderState(extra: "action=open-single-settings")
        case .superGroup:
            let fallbackGroupInfo = OpenIMDemoBaselineGroupInfo(
                groupID: conversation.groupID ?? "",
                groupName: conversation.showName,
                faceURL: conversation.faceURL,
                ownerUserID: nil,
                memberCount: chatController.groupInfo?.memberCount ?? 0
            )
            let sourceInfo = chatController.groupInfo ?? fallbackGroupInfo
            chatController.getGroupMembers(userIDs: nil, memory: true) { [weak self] members in
                guard let self else { return }
                let vc = GroupChatSettingTableViewController(
                    conversation: self.makeOUICoreConversationInfo(from: conversation),
                    groupInfo: self.makeOUICoreGroupInfo(from: sourceInfo),
                    groupMembers: members.map(self.makeOUICoreGroupMemberInfo(from:)),
                    style: .grouped
                )
                self.navigationController?.pushViewController(vc, animated: true)
            }
            renderState(extra: "action=open-group-settings")
        case .notification, .undefine:
            break
        }
    }

    private func showMediaSendSheet() {
        guard !hiddenInputBar else { return }
        let sheet = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        sheet.addAction(UIAlertAction(title: "发送图片", style: .default, handler: { [weak self] _ in
            self?.presentMediaPicker(filter: .images)
        }))
        sheet.addAction(UIAlertAction(title: "发送视频", style: .default, handler: { [weak self] _ in
            self?.presentMediaPicker(filter: .videos)
        }))
        sheet.addAction(UIAlertAction(title: "取消", style: .cancel))
        if let popover = sheet.popoverPresentationController {
            popover.barButtonItem = mediaButton
        }
        present(sheet, animated: true)
    }

    private func makeOUICoreConversationInfo(
        from conversation: OpenIMDemoBaselineConversationInfo
    ) -> ConversationInfo {
        let info = ConversationInfo(conversationID: conversation.conversationID)
        info.userID = conversation.userID
        info.groupID = conversation.groupID
        info.showName = conversation.showName
        info.faceURL = conversation.faceURL
        info.recvMsgOpt = makeOUICoreReceiveMessageOpt(from: conversation.recvMsgOpt)
        info.unreadCount = conversation.unreadCount
        info.conversationType = makeOUICoreConversationType(from: conversation.conversationType)
        info.latestMsgSendTime = conversation.latestMsgSendTime
        info.draftText = conversation.draftText
        info.draftTextTime = conversation.draftTextTime
        info.isPinned = conversation.isPinned
        info.isNotInGroup = !chatController.isInGroup
        return info
    }

    private func makeOUICoreUserInfo(from info: OpenIMDemoBaselineFriendInfo) -> UserInfo {
        UserInfo(
            userID: info.userID,
            nickname: info.nickname ?? info.remark,
            remark: info.remark,
            faceURL: info.faceURL
        )
    }

    private func makeOUICoreGroupInfo(from info: OpenIMDemoBaselineGroupInfo) -> GroupInfo {
        let group = GroupInfo(groupID: info.groupID, groupName: info.groupName)
        group.faceURL = info.faceURL
        group.ownerUserID = info.ownerUserID
        group.memberCount = info.memberCount
        return group
    }

    private func makeOUICoreGroupMemberInfo(
        from info: OpenIMDemoBaselineGroupMemberInfo
    ) -> GroupMemberInfo {
        let member = GroupMemberInfo()
        member.userID = info.userID
        member.groupID = info.groupID
        member.nickname = info.nickname
        member.faceURL = info.faceURL
        return member
    }

    private func makeOUICoreReceiveMessageOpt(
        from opt: OpenIMDemoBaselineReceiveMessageOpt
    ) -> ReceiveMessageOpt {
        switch opt {
        case .receive:
            return .receive
        case .notReceive:
            return .notReceive
        case .notNotify:
            return .notNotify
        }
    }

    private func makeOUICoreConversationType(
        from type: OpenIMDemoBaselineConversationType
    ) -> OUICore.ConversationType {
        switch type {
        case .c2c:
            return .c2c
        case .superGroup:
            return .superGroup
        case .notification:
            return .notification
        case .undefine:
            return .undefine
        }
    }

    private func logUpdateApplication(
        sequence: Int,
        triggerSource: OpenIMDemoBaselineUpdateTriggerSource,
        path: UpdateApplicationPath,
        mutation: UpdateMutationKind?,
        requiresIsolatedProcess: Bool,
        oldSections: [OpenIMDemoBaselineSection],
        newSections: [OpenIMDemoBaselineSection]
    ) {
        let oldMessageCount = oldSections.reduce(into: 0) { partialResult, section in
            partialResult += section.cells.reduce(into: 0) { count, cell in
                if case .message = cell {
                    count += 1
                }
            }
        }
        let newMessageCount = newSections.reduce(into: 0) { partialResult, section in
            partialResult += section.cells.reduce(into: 0) { count, cell in
                if case .message = cell {
                    count += 1
                }
            }
        }
        let oldCellCount = oldSections.reduce(0) { $0 + $1.cells.count }
        let newCellCount = newSections.reduce(0) { $0 + $1.cells.count }
        let mutationValue = mutation?.rawValue ?? "-"

        iLogger.print(
            "[OpenIMDemoBaselineUpdate] conversation=\(seed.businessConversationID) " +
            "seq=\(sequence) " +
            "trigger=\(triggerSource.rawValue) " +
            "path=\(path.rawValue) mutation=\(mutationValue) isolated=\(requiresIsolatedProcess) " +
            "sections=\(oldSections.count)->\(newSections.count) " +
            "cells=\(oldCellCount)->\(newCellCount) " +
            "messages=\(oldMessageCount)->\(newMessageCount)"
        )
    }

    private func setupCollectionView() {
        chatLayout.settings.interItemSpacing = 8
        chatLayout.settings.interSectionSpacing = 4
        chatLayout.settings.additionalInsets = UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
        chatLayout.keepContentOffsetAtBottomOnBatchUpdates = true

        collectionView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.backgroundColor = .clear
        collectionView.alwaysBounceVertical = true
        collectionView.keyboardDismissMode = .interactive
        collectionView.dataSource = dataSource
        collectionView.delegate = self
        chatLayout.delegate = dataSource
        dataSource.prepare(with: collectionView)

        contentStackView.translatesAutoresizingMaskIntoConstraints = false
        contentStackView.axis = .vertical
        contentStackView.spacing = 0
        contentStackView.addArrangedSubview(collectionView)
        view.addSubview(contentStackView)

        NSLayoutConstraint.activate([
            contentStackView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            contentStackView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            contentStackView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
    }

    private func setupRefreshControl() {
        let header = MJRefreshNormalHeader(refreshingTarget: self, refreshingAction: #selector(handleRefresh))
        header.stateLabel?.isHidden = true
        header.lastUpdatedTimeLabel?.isHidden = true
        header.isCollectionViewAnimationBug = true
        collectionView.mj_header = header
    }

    private func setupStateLabel() {
        guard showDebugOverlay else {
            stateLabel.isHidden = true
            return
        }
        stateLabel.translatesAutoresizingMaskIntoConstraints = false
        stateLabel.numberOfLines = 0
        stateLabel.font = .systemFont(ofSize: 11, weight: .medium)
        stateLabel.textColor = UIColor(RaverTheme.secondaryText)
        stateLabel.backgroundColor = UIColor(RaverTheme.card).withAlphaComponent(0.92)
        stateLabel.layer.cornerRadius = 10
        stateLabel.layer.masksToBounds = true
        stateLabel.textAlignment = .left
        view.addSubview(stateLabel)

        NSLayoutConstraint.activate([
            stateLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
            stateLabel.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -12),
            stateLabel.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: hiddenInputBar ? -12 : -74)
        ])
    }

    private func setupInputBarShell() {
        inputBarShell.translatesAutoresizingMaskIntoConstraints = false
        inputBarShell.backgroundColor = UIColor(RaverTheme.card)
        inputBarShell.isHidden = hiddenInputBar

        inputBarHairline.translatesAutoresizingMaskIntoConstraints = false
        inputBarHairline.backgroundColor = UIColor(RaverTheme.cardBorder)

        inputTextView.translatesAutoresizingMaskIntoConstraints = false
        inputTextView.delegate = self
        inputTextView.backgroundColor = UIColor(RaverTheme.background)
        inputTextView.font = .systemFont(ofSize: 15)
        inputTextView.textColor = UIColor(RaverTheme.primaryText)
        inputTextView.layer.cornerRadius = 18
        inputTextView.layer.masksToBounds = true
        inputTextView.returnKeyType = .send
        inputTextView.textContainer.lineFragmentPadding = 8
        inputTextView.isScrollEnabled = false

        inputPlaceholderLabel.translatesAutoresizingMaskIntoConstraints = false
        inputPlaceholderLabel.text = "Message"
        inputPlaceholderLabel.font = .systemFont(ofSize: 14)
        inputPlaceholderLabel.textColor = UIColor(RaverTheme.secondaryText)
        inputPlaceholderLabel.isUserInteractionEnabled = false

        inputMediaButton.translatesAutoresizingMaskIntoConstraints = false
        inputMediaButton.setImage(UIImage(systemName: "plus.circle.fill"), for: .normal)
        inputMediaButton.tintColor = UIColor(RaverTheme.accent)
        inputMediaButton.addTarget(self, action: #selector(handleMediaComposerTap), for: .touchUpInside)

        inputSendButton.translatesAutoresizingMaskIntoConstraints = false
        inputSendButton.setTitle("Send", for: .normal)
        inputSendButton.titleLabel?.font = .systemFont(ofSize: 15, weight: .semibold)
        inputSendButton.isEnabled = false
        inputSendButton.addTarget(self, action: #selector(handleSendButtonTap), for: .touchUpInside)

        inputBarShell.addSubview(inputBarHairline)
        inputBarShell.addSubview(inputMediaButton)
        inputBarShell.addSubview(inputTextView)
        inputBarShell.addSubview(inputPlaceholderLabel)
        inputBarShell.addSubview(inputSendButton)
        view.addSubview(inputBarShell)

        inputBarBottomConstraint = inputBarShell.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        inputBarBottomConstraint?.isActive = true
        inputTextViewHeightConstraint = inputTextView.heightAnchor.constraint(equalToConstant: 42)
        inputTextViewHeightConstraint?.isActive = true

        NSLayoutConstraint.activate([
            inputBarShell.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            inputBarShell.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            inputBarHairline.topAnchor.constraint(equalTo: inputBarShell.topAnchor),
            inputBarHairline.leadingAnchor.constraint(equalTo: inputBarShell.leadingAnchor),
            inputBarHairline.trailingAnchor.constraint(equalTo: inputBarShell.trailingAnchor),
            inputBarHairline.heightAnchor.constraint(equalToConstant: 1),
            inputTextView.topAnchor.constraint(equalTo: inputBarShell.topAnchor, constant: 10),
            inputTextView.leadingAnchor.constraint(equalTo: inputMediaButton.trailingAnchor, constant: 10),
            inputTextView.trailingAnchor.constraint(equalTo: inputSendButton.leadingAnchor, constant: -10),
            inputTextView.bottomAnchor.constraint(equalTo: inputBarShell.safeAreaLayoutGuide.bottomAnchor, constant: -10),
            inputMediaButton.leadingAnchor.constraint(equalTo: inputBarShell.leadingAnchor, constant: 12),
            inputMediaButton.centerYAnchor.constraint(equalTo: inputTextView.centerYAnchor),
            inputMediaButton.widthAnchor.constraint(equalToConstant: 26),
            inputMediaButton.heightAnchor.constraint(equalToConstant: 26),
            inputSendButton.trailingAnchor.constraint(equalTo: inputBarShell.trailingAnchor, constant: -12),
            inputSendButton.centerYAnchor.constraint(equalTo: inputTextView.centerYAnchor),
            inputSendButton.widthAnchor.constraint(equalToConstant: 52),
            inputPlaceholderLabel.leadingAnchor.constraint(equalTo: inputTextView.leadingAnchor, constant: 12),
            inputPlaceholderLabel.trailingAnchor.constraint(equalTo: inputTextView.trailingAnchor, constant: -12),
            inputPlaceholderLabel.centerYAnchor.constraint(equalTo: inputTextView.centerYAnchor)
        ])

        configureInputView(hidden: hiddenInputBar)
    }

    private func configureInputView(hidden: Bool) {
        contentStackViewBottomConstraint?.isActive = false
        contentStackViewBottomConstraint = contentStackView.bottomAnchor.constraint(
            equalTo: hidden ? view.bottomAnchor : inputBarShell.topAnchor
        )
        contentStackViewBottomConstraint?.isActive = true
    }

    func textViewDidChange(_ textView: UITextView) {
        inputPlaceholderLabel.isHidden = !textView.text.isEmpty
        inputSendButton.isEnabled = !textView.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        updateInputTextViewHeight()

        guard !currentInterfaceActions.options.contains(.sendingMessage) else {
            return
        }
        scrollToLatestMessageIfNeeded(animated: false)
    }

    func textViewDidBeginEditing(_ textView: UITextView) {
        _ = textView
        scrollToLatestMessageIfNeeded(animated: false)
    }

    func textView(
        _ textView: UITextView,
        shouldChangeTextIn range: NSRange,
        replacementText text: String
    ) -> Bool {
        if text == "\n" {
            let currentText = textView.text ?? ""
            let nextText = (currentText as NSString).replacingCharacters(in: range, with: text)
            if !nextText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                handleSendButtonTap()
            }
            return false
        }
        return true
    }

    @objc
    private func handleMediaComposerTap() {
        showMediaSendSheet()
    }

    @objc
    private func handleSendButtonTap() {
        guard !currentInterfaceActions.options.contains(.sendingMessage) else {
            return
        }

        let messageText = inputTextView.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !messageText.isEmpty else {
            return
        }
        OpenIMProbeLogger.log(
            "[OpenIMDemoBaselineChain] view.handleSendButtonTap " +
            "conversation=\(seed.businessConversationID) textLength=\(messageText.count)"
        )

        currentInterfaceActions.options.insert(.sendingMessage)
        keepContentOffsetAtBottom = true
        inputSendButton.isEnabled = false
        scrollToLatestMessageIfNeeded(animated: false)

        chatController.sendTextMessage(messageText) { [weak self] sections in
            guard let self else {
                return
            }
            self.inputTextView.text = ""
            self.inputPlaceholderLabel.isHidden = false
            self.updateInputTextViewHeight()
            self.processUpdates(
                with: sections,
                animated: true,
                requiresIsolatedProcess: false,
                triggerSource: .send
            ) {
                self.currentInterfaceActions.options.remove(.sendingMessage)
                self.inputSendButton.isEnabled = false
            }
        }
    }

    @objc
    private func handleRefresh() {
        if !currentControllerActions.options.contains(.loadingPreviousMessages) {
            currentControllerActions.options.insert(.loadingPreviousMessages)
        }

        chatController.loadPreviousMessages { [weak self] sections in
            guard let self else { return }
            self.processUpdates(
                with: sections,
                animated: false,
                requiresIsolatedProcess: true,
                triggerSource: .previousLoad
            ) {
                self.collectionView.mj_header?.endRefreshing()
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    self.currentControllerActions.options.remove(.loadingPreviousMessages)
                }
            }
        }
    }

    private func updateInputTextViewHeight() {
        let fittingSize = CGSize(width: inputTextView.bounds.width, height: .greatestFiniteMagnitude)
        let targetHeight = min(max(inputTextView.sizeThatFits(fittingSize).height, 42), 120)
        guard inputTextViewHeightConstraint?.constant != targetHeight else {
            return
        }
        inputTextViewHeightConstraint?.constant = targetHeight
        view.layoutIfNeeded()
    }

    private func loadInitialMessages() {
        guard !currentControllerActions.options.contains(.loadingInitialMessages) else {
            return
        }
        currentControllerActions.options.insert(.loadingInitialMessages)
        chatController.loadInitialMessages { [weak self] sections in
            guard let self else {
                return
            }
            self.currentControllerActions.options.remove(.loadingInitialMessages)
            self.processUpdates(
                with: sections,
                animated: false,
                requiresIsolatedProcess: true,
                triggerSource: .initialLoad
            )
        }
    }

    private func loadPreviousMessages() {
        guard !currentControllerActions.options.contains(.loadingPreviousMessages) else {
            return
        }
        currentControllerActions.options.insert(.loadingPreviousMessages)
        let snapshot = chatLayout.getContentOffsetSnapshot(from: .top)
        chatController.loadPreviousMessages { [weak self] sections in
            guard let self else {
                return
            }
            let animated = !self.isUserInitiatedScrolling
            self.processUpdates(
                with: sections,
                animated: animated,
                requiresIsolatedProcess: false,
                preferredSnapshot: snapshot,
                triggerSource: .previousLoad
            ) {
                self.currentControllerActions.options.remove(.loadingPreviousMessages)
            }
        }
    }

    private func loadMoreMessages() {
        guard !currentControllerActions.options.contains(.loadingMoreMessages) else {
            return
        }
        currentControllerActions.options.insert(.loadingMoreMessages)
        keepContentOffsetAtBottom = false
        let snapshot = chatLayout.getContentOffsetSnapshot(from: .bottom)
        chatController.loadMoreMessages { [weak self] sections in
            guard let self else {
                return
            }
            self.processUpdates(
                with: sections,
                animated: false,
                requiresIsolatedProcess: true,
                preferredSnapshot: snapshot,
                triggerSource: .moreLoad
            ) {
                self.keepContentOffsetAtBottom = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    self.currentControllerActions.options.remove(.loadingMoreMessages)
                }
            }
        }
    }

    private func scrollToLatestMessageIfNeeded(animated: Bool) {
        scrollToBottom(animated: animated)
    }

    private func scrollToBottom(animated: Bool = true, completion: (() -> Void)? = nil) {
        let contentOffsetAtBottom = CGPoint(
            x: collectionView.contentOffset.x,
            y: chatLayout.collectionViewContentSize.height - collectionView.frame.height + collectionView.adjustedContentInset.bottom
        )

        guard contentOffsetAtBottom.y > collectionView.contentOffset.y else {
            completion?()
            return
        }

        let initialOffset = collectionView.contentOffset.y
        let delta = contentOffsetAtBottom.y - initialOffset
        if abs(delta) > chatLayout.visibleBounds.height {
            animator = OpenIMDemoBaselineManualAnimator()
            animator?.animate(duration: TimeInterval(animated ? 0.25 : 0.1), curve: .easeInOut) { [weak self] percentage in
                guard let self else { return }
                self.collectionView.contentOffset = CGPoint(
                    x: self.collectionView.contentOffset.x,
                    y: initialOffset + (delta * percentage)
                )
                if percentage == 1.0 {
                    self.animator = nil
                    let positionSnapshot = ChatLayoutPositionSnapshot(
                        indexPath: IndexPath(item: 0, section: 0),
                        kind: .footer,
                        edge: .bottom
                    )
                    self.chatLayout.restoreContentOffset(with: positionSnapshot)
                    self.currentInterfaceActions.options.remove(.scrollingToBottom)
                    completion?()
                }
            }
        } else {
            currentInterfaceActions.options.insert(.scrollingToBottom)
            UIView.animate(withDuration: 0.25, animations: { [weak self] in
                self?.collectionView.setContentOffset(contentOffsetAtBottom, animated: true)
            }, completion: { [weak self] _ in
                self?.currentInterfaceActions.options.remove(.scrollingToBottom)
                completion?()
            })
        }
    }

    private func processUpdates(
        with sections: [OpenIMDemoBaselineSection],
        animated: Bool = true,
        requiresIsolatedProcess: Bool,
        preferredSnapshot: ChatLayoutPositionSnapshot? = nil,
        triggerSource: OpenIMDemoBaselineUpdateTriggerSource = .externalUpdate,
        completion: (() -> Void)? = nil
    ) {
        OpenIMProbeLogger.log(
            "[OpenIMDemoBaselineChain] view.processUpdates enter " +
            "conversation=\(seed.businessConversationID) trigger=\(triggerSource.rawValue) " +
            "animated=\(animated) isolated=\(requiresIsolatedProcess) " +
            "oldSections=\(self.sections.count) newSections=\(sections.count) " +
            "interfaceActions=\(currentInterfaceActions.options.count) controllerActions=\(currentControllerActions.options.count)"
        )
        guard isViewLoaded else {
            self.sections = sections
            dataSource.sections = sections
            completion?()
            return
        }

        guard currentInterfaceActions.options.isEmpty || ignoreInterfaceActions else {
            OpenIMProbeLogger.log(
                "[OpenIMDemoBaselineChain] view.processUpdates deferred " +
                "conversation=\(seed.businessConversationID) trigger=\(triggerSource.rawValue)"
            )
            let reaction = SetActor<Set<InterfaceAction>, ReactionType>.Reaction(
                type: .delayedUpdate,
                action: .onEmpty,
                executionType: .once,
                actionBlock: { [weak self] in
                    guard let self else { return }
                    self.processUpdates(
                        with: sections,
                        animated: animated,
                        requiresIsolatedProcess: requiresIsolatedProcess,
                        preferredSnapshot: preferredSnapshot,
                        triggerSource: triggerSource,
                        completion: completion
                    )
                }
            )
            currentInterfaceActions.add(reaction: reaction)
            return
        }

        currentControllerActions.options.insert(.updatingCollection)
        currentInterfaceActions.options.insert(.updatingCollection)

        let targetSnapshot = preferredSnapshot ?? makePreferredSnapshot(for: sections)

        let previousSections = self.sections

        let applyCompletion = { [weak self] (path: UpdateApplicationPath, mutation: UpdateMutationKind?) in
            guard let self else { return }
            let updateSequence = self.nextAppliedUpdateSequence + 1
            self.nextAppliedUpdateSequence = updateSequence
            let mutationValue = mutation?.rawValue ?? "-"
            self.lastAppliedUpdateSummary =
                "seq=\(updateSequence)|trigger=\(triggerSource.rawValue)|path=\(path.rawValue)|mutation=\(mutationValue)|isolated=\(requiresIsolatedProcess)"
            self.logUpdateApplication(
                sequence: updateSequence,
                triggerSource: triggerSource,
                path: path,
                mutation: mutation,
                requiresIsolatedProcess: requiresIsolatedProcess,
                oldSections: previousSections,
                newSections: sections
            )
            self.sections = sections
            let mutationExtra = mutation.map { "|mutation=\($0.rawValue)" } ?? ""
            self.renderState(
                extra: "trigger=\(triggerSource.rawValue)|isolated=\(requiresIsolatedProcess)|path=\(path.rawValue)\(mutationExtra)"
            )
            if let targetSnapshot {
                self.chatLayout.restoreContentOffset(with: targetSnapshot)
            } else if !self.scrollToTop, self.keepContentOffsetAtBottom {
                self.scrollToLatestMessageIfNeeded(animated: false)
            }
            self.currentInterfaceActions.options.remove(.updatingCollection)
            self.currentControllerActions.options.remove(.updatingCollection)
            self.ignoreInterfaceActions = false
            completion?()
        }

        func process() {
            var changeSet = StagedChangeset(
                source: dataSource.sections,
                target: sections
            ).flattenIfPossible()
            guard !changeSet.isEmpty else {
                currentInterfaceActions.options.remove(.updatingCollection)
                currentControllerActions.options.remove(.updatingCollection)
                ignoreInterfaceActions = false
                completion?()
                return
            }

            if ignoreInterfaceActions {
                guard let data = changeSet.last?.data else {
                    currentInterfaceActions.options.remove(.updatingCollection)
                    currentControllerActions.options.remove(.updatingCollection)
                    ignoreInterfaceActions = false
                    completion?()
                    return
                }
                dataSource.sections = data

                if requiresIsolatedProcess {
                    chatLayout.processOnlyVisibleItemsOnAnimatedBatchUpdates = true
                    currentInterfaceActions.options.insert(.updatingCollectionInIsolation)
                }

                collectionView.reloadData()
                collectionView.layoutIfNeeded()
                if let targetSnapshot {
                    chatLayout.restoreContentOffset(with: targetSnapshot)
                }

                chatLayout.processOnlyVisibleItemsOnAnimatedBatchUpdates = false
                if requiresIsolatedProcess {
                    currentInterfaceActions.options.remove(.updatingCollectionInIsolation)
                }
                applyCompletion(.initialReload, nil)
                return
            }

            if requiresIsolatedProcess {
                chatLayout.processOnlyVisibleItemsOnAnimatedBatchUpdates = true
                currentInterfaceActions.options.insert(.updatingCollectionInIsolation)
            }

            collectionView.reload(
                using: changeSet,
                interrupt: { changeset in
                    !changeset.sectionInserted.isEmpty
                },
                onInterruptedReload: { [weak self] in
                    guard let self else { return }
                    self.collectionView.reloadData()
                    if let targetSnapshot {
                        self.chatLayout.restoreContentOffset(with: targetSnapshot)
                    }
                },
                completion: { [weak self] didPerformAnimatedBatch in
                    guard let self else { return }
                    self.chatLayout.processOnlyVisibleItemsOnAnimatedBatchUpdates = false
                    if requiresIsolatedProcess {
                        self.currentInterfaceActions.options.remove(.updatingCollectionInIsolation)
                    }
                    let path: UpdateApplicationPath = didPerformAnimatedBatch
                        ? .lightweightBatch
                        : .fallbackReload
                    self.applyUpdateCompletion(
                        with: applyCompletion,
                        path: path
                    )
                },
                setData: { [weak self] data in
                    self?.dataSource.sections = data
                }
            )
        }

        if animated {
            process()
        } else {
            UIView.performWithoutAnimation {
                process()
            }
        }
    }

    private func applyUpdateCompletion(
        with completion: @escaping (UpdateApplicationPath, UpdateMutationKind?) -> Void,
        path: UpdateApplicationPath
    ) {
        completion(path, nil)
    }

    private func applyLightweightDiffUpdatesIfPossible(
        with sections: [OpenIMDemoBaselineSection],
        completion: @escaping (UpdateApplicationPath, UpdateMutationKind?) -> Void
    ) -> Bool {
        guard sections.count == 1,
              dataSource.sections.count == 1 else {
            return false
        }

        let oldCells = dataSource.sections[0].cells
        let newCells = sections[0].cells
        let oldIdentifiers = oldCells.map(cellDiffIdentifier)
        let newIdentifiers = newCells.map(cellDiffIdentifier)

        guard oldIdentifiers != newIdentifiers || oldCells != newCells else {
            dataSource.sections = sections
            chatLayout.processOnlyVisibleItemsOnAnimatedBatchUpdates = false
            completion(.lightweightReloadOnly, .reloadOnly)
            return true
        }

        let difference = newIdentifiers.difference(from: oldIdentifiers)
        let hasMoves = difference.insertions.contains(where: { change in
            if case let .insert(_, _, associatedWith) = change {
                return associatedWith != nil
            }
            return false
        }) || difference.removals.contains(where: { change in
            if case let .remove(_, _, associatedWith) = change {
                return associatedWith != nil
            }
            return false
        })
        guard !hasMoves else {
            return false
        }

        let deletedIndexPaths = difference.removals
            .compactMap { change -> IndexPath? in
                guard case let .remove(offset, _, _) = change else {
                    return nil
                }
                return IndexPath(item: offset, section: 0)
            }
            .sorted { lhs, rhs in lhs.item > rhs.item }
        let insertedIndexPaths = difference.insertions
            .compactMap { change -> IndexPath? in
                guard case let .insert(offset, _, _) = change else {
                    return nil
                }
                return IndexPath(item: offset, section: 0)
            }
            .sorted { lhs, rhs in lhs.item < rhs.item }

        let insertedIndexPathSet = Set(insertedIndexPaths)
        let oldCellsByIdentifier = Dictionary(uniqueKeysWithValues: zip(oldIdentifiers, oldCells))
        let reloadedIndexPaths = newCells.enumerated().compactMap { index, cell -> IndexPath? in
            let identifier = newIdentifiers[index]
            let indexPath = IndexPath(item: index, section: 0)
            guard let oldCell = oldCellsByIdentifier[identifier],
                  oldCell != cell,
                  !insertedIndexPathSet.contains(indexPath) else {
                return nil
            }
            return indexPath
        }

        let mutationKind = classifyMutation(
            oldSection: dataSource.sections[0],
            newSection: sections[0],
            deletedIndexPaths: deletedIndexPaths,
            insertedIndexPaths: insertedIndexPaths,
            reloadedIndexPaths: reloadedIndexPaths
        )

        guard !shouldInterruptLightweightDiff(
            oldSection: dataSource.sections[0],
            newSection: sections[0],
            deletedIndexPaths: deletedIndexPaths,
            insertedIndexPaths: insertedIndexPaths,
            reloadedIndexPaths: reloadedIndexPaths
        ) else {
            return false
        }

        let applySectionData = { [weak self] in
            self?.dataSource.sections = sections
        }

        if deletedIndexPaths.isEmpty && insertedIndexPaths.isEmpty {
            applySectionData()
            if !reloadedIndexPaths.isEmpty {
                collectionView.reloadItems(at: reloadedIndexPaths)
            }
            chatLayout.processOnlyVisibleItemsOnAnimatedBatchUpdates = false
            completion(.lightweightReloadOnly, mutationKind)
            return true
        }

        collectionView.performBatchUpdates {
            applySectionData()
            if !deletedIndexPaths.isEmpty {
                collectionView.deleteItems(at: deletedIndexPaths)
            }
            if !insertedIndexPaths.isEmpty {
                collectionView.insertItems(at: insertedIndexPaths)
            }
        } completion: { [weak self] _ in
            guard let self else {
                return
            }
            if !reloadedIndexPaths.isEmpty {
                self.collectionView.reloadItems(at: reloadedIndexPaths)
            }
            self.chatLayout.processOnlyVisibleItemsOnAnimatedBatchUpdates = false
            completion(.lightweightBatch, mutationKind)
        }

        return true
    }

    private func applyReloadDataFallback(
        with sections: [OpenIMDemoBaselineSection],
        animated: Bool
    ) {
        dataSource.sections = sections
        if animated {
            collectionView.reloadData()
            return
        }
        UIView.performWithoutAnimation {
            self.collectionView.reloadData()
            self.collectionView.layoutIfNeeded()
        }
    }

    private func shouldForceReloadForCurrentViewState() -> Bool {
        if collectionView.window == nil {
            return true
        }

        if collectionView.numberOfSections != dataSource.sections.count {
            return true
        }

        return false
    }

    private func classifyMutation(
        oldSection: OpenIMDemoBaselineSection,
        newSection: OpenIMDemoBaselineSection,
        deletedIndexPaths: [IndexPath],
        insertedIndexPaths: [IndexPath],
        reloadedIndexPaths: [IndexPath]
    ) -> UpdateMutationKind {
        if deletedIndexPaths.isEmpty && insertedIndexPaths.isEmpty {
            return .reloadOnly
        }

        if !deletedIndexPaths.isEmpty && !insertedIndexPaths.isEmpty {
            return .mixed
        }

        if !insertedIndexPaths.isEmpty {
            let insertedItems = insertedIndexPaths.map(\.item).sorted()
            if insertedItems.first == 0 {
                return .prepend
            }
            if insertedItems.last == newSection.cells.count - 1 {
                return .append
            }
            return .mixed
        }

        if !deletedIndexPaths.isEmpty {
            let deletedItems = deletedIndexPaths.map(\.item).sorted()
            if deletedItems.first == 0 {
                return reloadedIndexPaths.isEmpty ? .trimTop : .mixed
            }
            if deletedItems.last == oldSection.cells.count - 1 {
                return reloadedIndexPaths.isEmpty ? .trimBottom : .mixed
            }
        }

        return .mixed
    }

    private func shouldInterruptLightweightDiff(
        oldSection: OpenIMDemoBaselineSection,
        newSection: OpenIMDemoBaselineSection,
        deletedIndexPaths: [IndexPath],
        insertedIndexPaths: [IndexPath],
        reloadedIndexPaths: [IndexPath]
    ) -> Bool {
        guard oldSection.id == newSection.id,
              oldSection.title == newSection.title else {
            return true
        }

        let changeCount = deletedIndexPaths.count + insertedIndexPaths.count + reloadedIndexPaths.count
        let largerCount = max(oldSection.cells.count, newSection.cells.count)
        guard changeCount > 0 else {
            return false
        }

        if changeCount >= 48 {
            return true
        }

        if largerCount > 0, Double(changeCount) / Double(largerCount) > 0.6 {
            return true
        }

        if !deletedIndexPaths.isEmpty && !insertedIndexPaths.isEmpty {
            return true
        }

        if !insertedIndexPaths.isEmpty,
           !isBoundaryOnlyMutation(
                indexPaths: insertedIndexPaths,
                expectedSection: 0,
                totalCount: newSection.cells.count
           ) {
            return true
        }

        if !deletedIndexPaths.isEmpty,
           !isBoundaryOnlyMutation(
                indexPaths: deletedIndexPaths,
                expectedSection: 0,
                totalCount: oldSection.cells.count
           ) {
            return true
        }

        if !deletedIndexPaths.isEmpty && !reloadedIndexPaths.isEmpty {
            return true
        }

        if !insertedIndexPaths.isEmpty && !reloadedIndexPaths.isEmpty {
            return true
        }

        return false
    }

    private func isBoundaryOnlyMutation(
        indexPaths: [IndexPath],
        expectedSection: Int,
        totalCount: Int
    ) -> Bool {
        guard !indexPaths.isEmpty else {
            return true
        }

        let sortedItems = indexPaths.sorted { lhs, rhs in
            lhs.item < rhs.item
        }

        guard sortedItems.allSatisfy({ $0.section == expectedSection }) else {
            return false
        }

        for (offset, indexPath) in sortedItems.enumerated() where indexPath.item != sortedItems[0].item + offset {
            return false
        }

        guard let first = sortedItems.first?.item,
              let last = sortedItems.last?.item else {
            return true
        }

        if first == 0 {
            return true
        }

        if totalCount > 0, last == totalCount - 1 {
            return true
        }

        return false
    }

    private func cellDiffIdentifier(_ cell: OpenIMDemoBaselineCell) -> String {
        switch cell {
        case let .date(text):
            return "date:\(text)"
        case let .message(message):
            return "message:\(message.clientMsgID)"
        }
    }

    private func makePreferredSnapshot(
        for sections: [OpenIMDemoBaselineSection]
    ) -> ChatLayoutPositionSnapshot? {
        guard !sections.isEmpty else {
            return nil
        }
        if scrollToTop {
            return ChatLayoutPositionSnapshot(
                indexPath: IndexPath(item: 0, section: 0),
                kind: .cell,
                edge: .top
            )
        }
        guard let lastSectionIndex = sections.indices.last,
              let lastItemIndex = sections[lastSectionIndex].cells.indices.last else {
            return nil
        }
        return ChatLayoutPositionSnapshot(
            indexPath: IndexPath(item: lastItemIndex, section: lastSectionIndex),
            kind: .cell,
            edge: .bottom
        )
    }

    private var isUserInitiatedScrolling: Bool {
        collectionView.isDragging || collectionView.isDecelerating
    }

    private var collectionViewIsAtBottom: Bool {
        let contentOffsetAtBottom = CGPoint(
            x: collectionView.contentOffset.x,
            y: chatLayout.collectionViewContentSize.height - collectionView.frame.height + collectionView.adjustedContentInset.bottom
        )
        return contentOffsetAtBottom.y <= collectionView.contentOffset.y
    }

    private func presentMediaPicker(filter: PHPickerFilter) {
        var config = PHPickerConfiguration(photoLibrary: .shared())
        config.filter = filter
        config.selectionLimit = 1
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = self
        present(picker, animated: true)
    }

    private func sendPickedMedia(fileURL: URL) {
        let pathExtension = fileURL.pathExtension.lowercased()
        let isVideo = ["mp4", "mov", "m4v", "avi", "hevc"].contains(pathExtension)
        currentInterfaceActions.options.insert(.sendingMessage)
        inputSendButton.isEnabled = false
        inputMediaButton.isEnabled = false

        let complete: ([OpenIMDemoBaselineSection]) -> Void = { [weak self] sections in
            guard let self else { return }
            self.processUpdates(
                with: sections,
                animated: true,
                requiresIsolatedProcess: true,
                triggerSource: .send
            )
            self.currentInterfaceActions.options.remove(.sendingMessage)
            self.inputMediaButton.isEnabled = true
            self.inputSendButton.isEnabled = !self.inputTextView.text
                .trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            self.scrollToLatestMessageIfNeeded(animated: true)
        }

        if isVideo {
            chatController.sendVideoMessage(fileURL: fileURL, completion: complete)
        } else {
            chatController.sendImageMessage(fileURL: fileURL, completion: complete)
        }
    }

    private func persistPickedFile(
        from sourceURL: URL,
        preferredExtension: String?
    ) throws -> URL {
        let ext = preferredExtension?.isEmpty == false
            ? preferredExtension!
            : sourceURL.pathExtension
        let fileName = "baseline-media-\(UUID().uuidString).\(ext)"
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(
            "openim-baseline-picked-media",
            isDirectory: true
        )
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let destination = folder.appendingPathComponent(fileName)
        if FileManager.default.fileExists(atPath: destination.path) {
            try FileManager.default.removeItem(at: destination)
        }
        try FileManager.default.copyItem(at: sourceURL, to: destination)
        return destination
    }
}

extension ChatViewController: PHPickerViewControllerDelegate {
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)
        guard let first = results.first else { return }
        let provider = first.itemProvider
        let requestedType = provider.hasItemConformingToTypeIdentifier(UTType.movie.identifier)
            ? UTType.movie.identifier
            : UTType.image.identifier

        provider.loadFileRepresentation(forTypeIdentifier: requestedType) { [weak self] url, error in
            guard let self else { return }
            if let error {
                DispatchQueue.main.async {
                    self.presentAlert(title: "读取媒体失败：\(error.localizedDescription)")
                }
                return
            }
            guard let url else {
                DispatchQueue.main.async {
                    self.presentAlert(title: "读取媒体失败：文件地址为空")
                }
                return
            }
            do {
                // PHPicker's file URL is ephemeral; persist it before this callback returns.
                let ext = url.pathExtension
                let localURL = try self.persistPickedFile(from: url, preferredExtension: ext)
                DispatchQueue.main.async { [weak self] in
                    self?.sendPickedMedia(fileURL: localURL)
                }
            } catch {
                DispatchQueue.main.async { [weak self] in
                    self?.presentAlert(title: "保存媒体失败：\(error.localizedDescription)")
                }
            }
        }
    }
}

public extension UICollectionView {
    func reload<C>(
        using stagedChangeset: StagedChangeset<C>,
        interrupt: ((Changeset<C>) -> Bool)? = nil,
        onInterruptedReload: (() -> Void)? = nil,
        completion: ((Bool) -> Void)? = nil,
        setData: (C) -> Void
    ) {
        if case .none = window, let data = stagedChangeset.last?.data {
            setData(data)
            if let onInterruptedReload {
                onInterruptedReload()
            } else {
                reloadData()
            }
            completion?(false)
            return
        }

        let dispatchGroup: DispatchGroup? = completion != nil ? DispatchGroup() : nil
        let completionHandler: ((Bool) -> Void)? = completion != nil
            ? { _ in dispatchGroup?.leave() }
            : nil

        for changeset in stagedChangeset {
            if let interrupt,
               interrupt(changeset),
               let data = stagedChangeset.last?.data {
                setData(data)
                if let onInterruptedReload {
                    onInterruptedReload()
                } else {
                    reloadData()
                }
                completion?(false)
                return
            }

            performBatchUpdates({
                setData(changeset.data)
                dispatchGroup?.enter()

                if !changeset.sectionDeleted.isEmpty {
                    deleteSections(IndexSet(changeset.sectionDeleted))
                }
                if !changeset.sectionInserted.isEmpty {
                    insertSections(IndexSet(changeset.sectionInserted))
                }
                if !changeset.sectionUpdated.isEmpty {
                    reloadSections(IndexSet(changeset.sectionUpdated))
                }
                for (source, target) in changeset.sectionMoved {
                    moveSection(source, toSection: target)
                }

                if !changeset.elementDeleted.isEmpty {
                    deleteItems(at: changeset.elementDeleted.map {
                        IndexPath(item: $0.element, section: $0.section)
                    })
                }
                if !changeset.elementInserted.isEmpty {
                    insertItems(at: changeset.elementInserted.map {
                        IndexPath(item: $0.element, section: $0.section)
                    })
                }
                if !changeset.elementUpdated.isEmpty {
                    reloadItems(at: changeset.elementUpdated.map {
                        IndexPath(item: $0.element, section: $0.section)
                    })
                }
                for (source, target) in changeset.elementMoved {
                    moveItem(
                        at: IndexPath(item: source.element, section: source.section),
                        to: IndexPath(item: target.element, section: target.section)
                    )
                }
            }, completion: completionHandler)
        }

        dispatchGroup?.notify(queue: .main) {
            completion?(true)
        }
    }
}

extension StagedChangeset {
    func flattenIfPossible() -> StagedChangeset {
        if count == 2,
           self[0].sectionChangeCount == 0,
           self[1].sectionChangeCount == 0,
           self[0].elementDeleted.count == self[0].elementChangeCount,
           self[1].elementInserted.count == self[1].elementChangeCount {
            return StagedChangeset(
                arrayLiteral: Changeset(
                    data: self[1].data,
                    elementDeleted: self[0].elementDeleted,
                    elementInserted: self[1].elementInserted
                )
            )
        }
        return self
    }
}

extension ChatViewController: KeyboardListenerDelegate {
    func keyboardWillChangeFrame(info: KeyboardInfo) {
        guard !hiddenInputBar,
              !currentInterfaceActions.options.contains(.changingFrameSize),
              collectionView.contentInsetAdjustmentBehavior != .never,
              let keyboardFrame = collectionView.window?.convert(info.frameEnd, to: view),
              keyboardFrame.minY > 0,
              inputTextView.isFirstResponder else {
            return
        }

        currentInterfaceActions.options.insert(.changingKeyboardFrame)
        let newBottomInset = UIScreen.main.bounds.height - keyboardFrame.minY

        if collectionView.contentInset.bottom != newBottomInset {
            let positionSnapshot = chatLayout.getContentOffsetSnapshot(from: .bottom)

            if currentControllerActions.options.contains(.updatingCollection) {
                UIView.performWithoutAnimation {
                    self.collectionView.performBatchUpdates({})
                }
            }

            currentInterfaceActions.options.insert(.changingContentInsets)
            inputBarBottomConstraint?.constant = -newBottomInset

            UIView.animate(
                withDuration: info.animationDuration,
                delay: 0,
                options: keyboardAnimationOptions(from: info.animationCurve),
                animations: {
                self.view.layoutIfNeeded()
                if let positionSnapshot, !self.isUserInitiatedScrolling {
                    self.chatLayout.restoreContentOffset(with: positionSnapshot)
                }
                self.collectionView.collectionViewLayout.invalidateLayout()
            }, completion: { _ in
                self.currentInterfaceActions.options.remove(.changingContentInsets)
            })
        }

        if newBottomInset == 0,
           info.frameEnd.minY == UIScreen.main.bounds.height,
           info.frameEnd.minY > info.frameBegin.minY,
           inputTextView.inputView == nil {
            resetOffset(newBottomInset: newBottomInset, duration: info.animationDuration)
        }
    }

    func keyboardDidChangeFrame(info: KeyboardInfo) {
        _ = info
        guard currentInterfaceActions.options.contains(.changingKeyboardFrame) else {
            return
        }
        currentInterfaceActions.options.remove(.changingKeyboardFrame)
    }

    func keyboardWillShow(info: KeyboardInfo) {
        _ = info
        scrollToLatestMessageIfNeeded(animated: false)
    }

    func keyboardDidShow(info: KeyboardInfo) {
        _ = info
        guard !isUserInitiatedScrolling else {
            return
        }
        scrollToLatestMessageIfNeeded(animated: false)
    }

    func keyboardWillHide(info: KeyboardInfo) {
        guard !hiddenInputBar else {
            return
        }
        resetOffset(newBottomInset: 0, duration: info.animationDuration, curve: info.animationCurve)
    }

    func keyboardDidHide(info: KeyboardInfo) {
        _ = info
        currentInterfaceActions.options.remove(.changingKeyboardFrame)
        currentInterfaceActions.options.remove(.changingContentInsets)
    }

    private func resetOffset(
        newBottomInset: CGFloat,
        duration: CGFloat = 0.25,
        curve: UIView.AnimationCurve = .easeInOut
    ) {
        let positionSnapshot = chatLayout.getContentOffsetSnapshot(from: .bottom)
        inputBarBottomConstraint?.constant = -newBottomInset

        UIView.animate(
            withDuration: duration,
            delay: 0,
            options: keyboardAnimationOptions(from: curve),
            animations: {
                self.view.layoutIfNeeded()
            }
        )

        if let positionSnapshot, !isUserInitiatedScrolling {
            chatLayout.restoreContentOffset(with: positionSnapshot)
        }
        currentInterfaceActions.options.remove(.changingContentInsets)
    }

    private func keyboardAnimationOptions(from curve: UIView.AnimationCurve) -> UIView.AnimationOptions {
        switch curve {
        case .easeInOut:
            return [.curveEaseInOut, .beginFromCurrentState]
        case .easeIn:
            return [.curveEaseIn, .beginFromCurrentState]
        case .easeOut:
            return [.curveEaseOut, .beginFromCurrentState]
        case .linear:
            return [.curveLinear, .beginFromCurrentState]
        @unknown default:
            return [.curveEaseInOut, .beginFromCurrentState]
        }
    }
}

private final class OpenIMDemoBaselineNavigationTitleView: UIView {
    let mainLabel = UILabel()
    let mainTailLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        translatesAutoresizingMaskIntoConstraints = false

        mainLabel.font = .systemFont(ofSize: 17, weight: .semibold)
        mainLabel.textColor = UIColor(RaverTheme.primaryText)
        mainLabel.textAlignment = .center

        mainTailLabel.font = .systemFont(ofSize: 17, weight: .regular)
        mainTailLabel.textColor = UIColor(RaverTheme.primaryText)
        mainTailLabel.textAlignment = .center
        mainTailLabel.isHidden = true

        let stack = UIStackView(arrangedSubviews: [mainLabel, mainTailLabel])
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .horizontal
        stack.spacing = 4
        stack.alignment = .center

        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

struct KeyboardInfo: Equatable {
    let animationDuration: Double
    let animationCurve: UIView.AnimationCurve
    let frameBegin: CGRect
    let frameEnd: CGRect
    let isLocal: Bool

    init?(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let animationCurveNumber = userInfo[UIResponder.keyboardAnimationCurveUserInfoKey] as? NSNumber,
              let animationDurationNumber = userInfo[UIResponder.keyboardAnimationDurationUserInfoKey] as? NSNumber,
              let isLocalNumber = userInfo[UIResponder.keyboardIsLocalUserInfoKey] as? NSNumber,
              let frameBeginValue = userInfo[UIResponder.keyboardFrameBeginUserInfoKey] as? NSValue,
              let frameEndValue = userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue else {
            return nil
        }

        animationDuration = animationDurationNumber.doubleValue
        var animationCurve = UIView.AnimationCurve.easeInOut
        animationCurveNumber.getValue(&animationCurve)
        self.animationCurve = animationCurve
        isLocal = isLocalNumber.boolValue
        frameBegin = frameBeginValue.cgRectValue
        frameEnd = frameEndValue.cgRectValue
    }
}

@MainActor
protocol KeyboardListenerDelegate: AnyObject {
    func keyboardWillShow(info: KeyboardInfo)
    func keyboardDidShow(info: KeyboardInfo)
    func keyboardWillHide(info: KeyboardInfo)
    func keyboardDidHide(info: KeyboardInfo)
    func keyboardWillChangeFrame(info: KeyboardInfo)
    func keyboardDidChangeFrame(info: KeyboardInfo)
}

extension KeyboardListenerDelegate {
    func keyboardWillShow(info: KeyboardInfo) {}
    func keyboardDidShow(info: KeyboardInfo) {}
    func keyboardWillHide(info: KeyboardInfo) {}
    func keyboardDidHide(info: KeyboardInfo) {}
    func keyboardWillChangeFrame(info: KeyboardInfo) {}
    func keyboardDidChangeFrame(info: KeyboardInfo) {}
}

@MainActor
final class KeyboardListener {
    static let shared = KeyboardListener()

    private var delegates = NSHashTable<AnyObject>.weakObjects()

    private init() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillShow(_:)),
            name: UIResponder.keyboardWillShowNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardDidShow(_:)),
            name: UIResponder.keyboardDidShowNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillHide(_:)),
            name: UIResponder.keyboardWillHideNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardDidHide(_:)),
            name: UIResponder.keyboardDidHideNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillChangeFrame(_:)),
            name: UIResponder.keyboardWillChangeFrameNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardDidChangeFrame(_:)),
            name: UIResponder.keyboardDidChangeFrameNotification,
            object: nil
        )
    }

    func add(delegate: KeyboardListenerDelegate) {
        delegates.add(delegate)
    }

    @objc private func keyboardWillShow(_ notification: Notification) {
        guard let info = KeyboardInfo(notification) else { return }
        delegates.allObjects.compactMap { $0 as? KeyboardListenerDelegate }.forEach {
            $0.keyboardWillShow(info: info)
        }
    }

    @objc private func keyboardDidShow(_ notification: Notification) {
        guard let info = KeyboardInfo(notification) else { return }
        delegates.allObjects.compactMap { $0 as? KeyboardListenerDelegate }.forEach {
            $0.keyboardDidShow(info: info)
        }
    }

    @objc private func keyboardWillHide(_ notification: Notification) {
        guard let info = KeyboardInfo(notification) else { return }
        delegates.allObjects.compactMap { $0 as? KeyboardListenerDelegate }.forEach {
            $0.keyboardWillHide(info: info)
        }
    }

    @objc private func keyboardDidHide(_ notification: Notification) {
        guard let info = KeyboardInfo(notification) else { return }
        delegates.allObjects.compactMap { $0 as? KeyboardListenerDelegate }.forEach {
            $0.keyboardDidHide(info: info)
        }
    }

    @objc private func keyboardWillChangeFrame(_ notification: Notification) {
        guard let info = KeyboardInfo(notification) else { return }
        delegates.allObjects.compactMap { $0 as? KeyboardListenerDelegate }.forEach {
            $0.keyboardWillChangeFrame(info: info)
        }
    }

    @objc private func keyboardDidChangeFrame(_ notification: Notification) {
        guard let info = KeyboardInfo(notification) else { return }
        delegates.allObjects.compactMap { $0 as? KeyboardListenerDelegate }.forEach {
            $0.keyboardDidChangeFrame(info: info)
        }
    }
}

private final class OpenIMDemoBaselineDateCollectionViewCell: UICollectionViewCell {
    static let reuseIdentifier = "OpenIMDemoBaselineDateCollectionViewCell"

    private let label = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.addSubview(label)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 11, weight: .medium)
        label.textColor = UIColor(RaverTheme.secondaryText)
        label.textAlignment = .center
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 8),
            label.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -8),
            label.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 4),
            label.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -4)
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(text: String) {
        label.text = text
    }
}

private final class OpenIMDemoBaselineMessageCollectionViewCell: UICollectionViewCell {
    static let reuseIdentifier = "OpenIMDemoBaselineMessageCollectionViewCell"

    private let bubbleView = UIView()
    private let senderLabel = UILabel()
    private let messageLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)

        contentView.addSubview(bubbleView)
        bubbleView.translatesAutoresizingMaskIntoConstraints = false
        bubbleView.layer.cornerRadius = 14
        bubbleView.layer.masksToBounds = true

        senderLabel.translatesAutoresizingMaskIntoConstraints = false
        senderLabel.font = .systemFont(ofSize: 11, weight: .semibold)
        senderLabel.textColor = UIColor(RaverTheme.secondaryText)

        messageLabel.translatesAutoresizingMaskIntoConstraints = false
        messageLabel.numberOfLines = 2
        messageLabel.font = .systemFont(ofSize: 15, weight: .regular)

        bubbleView.addSubview(senderLabel)
        bubbleView.addSubview(messageLabel)

        NSLayoutConstraint.activate([
            bubbleView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 8),
            bubbleView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -8),
            bubbleView.topAnchor.constraint(equalTo: contentView.topAnchor),
            bubbleView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            senderLabel.leadingAnchor.constraint(equalTo: bubbleView.leadingAnchor, constant: 12),
            senderLabel.trailingAnchor.constraint(equalTo: bubbleView.trailingAnchor, constant: -12),
            senderLabel.topAnchor.constraint(equalTo: bubbleView.topAnchor, constant: 10),
            messageLabel.leadingAnchor.constraint(equalTo: bubbleView.leadingAnchor, constant: 12),
            messageLabel.trailingAnchor.constraint(equalTo: bubbleView.trailingAnchor, constant: -12),
            messageLabel.topAnchor.constraint(equalTo: senderLabel.bottomAnchor, constant: 4),
            messageLabel.bottomAnchor.constraint(lessThanOrEqualTo: bubbleView.bottomAnchor, constant: -10)
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(message: OpenIMDemoBaselineMessageInfo, isOutgoing: Bool) {
        let senderName = message.senderNickname?.isEmpty == false ? message.senderNickname! : message.sendID
        senderLabel.text = senderName
        messageLabel.text = renderedText(for: message)
        bubbleView.backgroundColor = isOutgoing
            ? UIColor(RaverTheme.accent).withAlphaComponent(0.12)
            : UIColor(RaverTheme.card)
        messageLabel.textColor = UIColor(RaverTheme.primaryText)
    }

    var previewSourceView: UIView { bubbleView }

    private func renderedText(for message: OpenIMDemoBaselineMessageInfo) -> String {
        if let content = message.content, !content.isEmpty {
            return content
        }
        switch message.contentType {
        case .image:
            return "[image]"
        case .video:
            return "[video]"
        case .custom:
            return "[custom]"
        default:
            return "[\(message.contentType.rawValue)]"
        }
    }
}
