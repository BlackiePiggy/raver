import Foundation

@MainActor
final class OpenIMDemoBaselineInMemoryDataProviderEventBridge: OpenIMDemoBaselineDataProviderEventBridge {
    struct ObserverBag<T> {
        var handlers: [UUID: T] = [:]
    }

    private var connectionSyncCompleteObservers = ObserverBag<() -> Void>()
    private var receivedMessagesObservers = ObserverBag<([OpenIMDemoBaselineMessageInfo], Bool) -> Void>()
    private var newMessageObservers = ObserverBag<(OpenIMDemoBaselineMessageInfo) -> Void>()
    private var groupMemberInfoChangedObservers = ObserverBag<(OpenIMDemoBaselineGroupMemberInfo) -> Void>()
    private var joinedGroupAddedObservers = ObserverBag<(OpenIMDemoBaselineGroupInfo) -> Void>()
    private var joinedGroupDeletedObservers = ObserverBag<(OpenIMDemoBaselineGroupInfo) -> Void>()
    private var friendInfoChangedObservers = ObserverBag<(OpenIMDemoBaselineFriendInfo) -> Void>()
    private var groupInfoChangedObservers = ObserverBag<(OpenIMDemoBaselineGroupInfo) -> Void>()
    private var groupMemberAddedObservers = ObserverBag<(OpenIMDemoBaselineGroupMemberInfo) -> Void>()
    private var groupMemberDeletedObservers = ObserverBag<(OpenIMDemoBaselineGroupMemberInfo) -> Void>()
    private var totalUnreadCountChangedObservers = ObserverBag<(Int) -> Void>()
    private var currentUserInfoChangedObservers = ObserverBag<(OpenIMDemoBaselineUserInfo) -> Void>()
    private var isInGroupChangedObservers = ObserverBag<(Bool) -> Void>()
    private var conversationChangedObservers = ObserverBag<([OpenIMDemoBaselineConversationInfo]) -> Void>()
    private var recordClearObservers = ObserverBag<(String) -> Void>()

    static let shared = OpenIMDemoBaselineInMemoryDataProviderEventBridge()

    private init() {}

    func observeConnectionSyncComplete(_ handler: @escaping () -> Void) -> UUID {
        add(&connectionSyncCompleteObservers, handler)
    }

    func observeReceivedMessages(
        _ handler: @escaping ([OpenIMDemoBaselineMessageInfo], Bool) -> Void
    ) -> UUID {
        add(&receivedMessagesObservers, handler)
    }

    func observeNewMessage(_ handler: @escaping (OpenIMDemoBaselineMessageInfo) -> Void) -> UUID {
        add(&newMessageObservers, handler)
    }

    func observeGroupMemberInfoChanged(
        _ handler: @escaping (OpenIMDemoBaselineGroupMemberInfo) -> Void
    ) -> UUID {
        add(&groupMemberInfoChangedObservers, handler)
    }

    func observeJoinedGroupAdded(_ handler: @escaping (OpenIMDemoBaselineGroupInfo) -> Void) -> UUID {
        add(&joinedGroupAddedObservers, handler)
    }

    func observeJoinedGroupDeleted(_ handler: @escaping (OpenIMDemoBaselineGroupInfo) -> Void) -> UUID {
        add(&joinedGroupDeletedObservers, handler)
    }

    func observeFriendInfoChanged(_ handler: @escaping (OpenIMDemoBaselineFriendInfo) -> Void) -> UUID {
        add(&friendInfoChangedObservers, handler)
    }

    func observeGroupInfoChanged(_ handler: @escaping (OpenIMDemoBaselineGroupInfo) -> Void) -> UUID {
        add(&groupInfoChangedObservers, handler)
    }

    func observeGroupMemberAdded(
        _ handler: @escaping (OpenIMDemoBaselineGroupMemberInfo) -> Void
    ) -> UUID {
        add(&groupMemberAddedObservers, handler)
    }

    func observeGroupMemberDeleted(
        _ handler: @escaping (OpenIMDemoBaselineGroupMemberInfo) -> Void
    ) -> UUID {
        add(&groupMemberDeletedObservers, handler)
    }

    func observeTotalUnreadCountChanged(_ handler: @escaping (Int) -> Void) -> UUID {
        add(&totalUnreadCountChangedObservers, handler)
    }

    func observeCurrentUserInfoChanged(_ handler: @escaping (OpenIMDemoBaselineUserInfo) -> Void) -> UUID {
        add(&currentUserInfoChangedObservers, handler)
    }

    func observeIsInGroupChanged(_ handler: @escaping (Bool) -> Void) -> UUID {
        add(&isInGroupChangedObservers, handler)
    }

    func observeConversationChanged(
        _ handler: @escaping ([OpenIMDemoBaselineConversationInfo]) -> Void
    ) -> UUID {
        add(&conversationChangedObservers, handler)
    }

    func observeRecordClear(_ handler: @escaping (String) -> Void) -> UUID {
        add(&recordClearObservers, handler)
    }

    func removeObserver(_ token: UUID) {
        connectionSyncCompleteObservers.handlers.removeValue(forKey: token)
        receivedMessagesObservers.handlers.removeValue(forKey: token)
        newMessageObservers.handlers.removeValue(forKey: token)
        groupMemberInfoChangedObservers.handlers.removeValue(forKey: token)
        joinedGroupAddedObservers.handlers.removeValue(forKey: token)
        joinedGroupDeletedObservers.handlers.removeValue(forKey: token)
        friendInfoChangedObservers.handlers.removeValue(forKey: token)
        groupInfoChangedObservers.handlers.removeValue(forKey: token)
        groupMemberAddedObservers.handlers.removeValue(forKey: token)
        groupMemberDeletedObservers.handlers.removeValue(forKey: token)
        totalUnreadCountChangedObservers.handlers.removeValue(forKey: token)
        currentUserInfoChangedObservers.handlers.removeValue(forKey: token)
        isInGroupChangedObservers.handlers.removeValue(forKey: token)
        conversationChangedObservers.handlers.removeValue(forKey: token)
        recordClearObservers.handlers.removeValue(forKey: token)
    }

    func emitConnectionSyncComplete() {
        for handler in connectionSyncCompleteObservers.handlers.values {
            handler()
        }
    }

    func emitReceived(messages: [OpenIMDemoBaselineMessageInfo], forceReload: Bool) {
        for handler in receivedMessagesObservers.handlers.values {
            handler(messages, forceReload)
        }
        if forceReload {
            for message in messages {
                for handler in newMessageObservers.handlers.values {
                    handler(message)
                }
            }
            return
        }
        guard let first = messages.first else {
            return
        }
        for handler in newMessageObservers.handlers.values {
            handler(first)
        }
    }

    func emitIsInGroup(_ isIn: Bool) {
        for handler in isInGroupChangedObservers.handlers.values {
            handler(isIn)
        }
    }

    func emitJoinedGroupAdded(_ info: OpenIMDemoBaselineGroupInfo) {
        for handler in joinedGroupAddedObservers.handlers.values {
            handler(info)
        }
    }

    func emitJoinedGroupDeleted(_ info: OpenIMDemoBaselineGroupInfo) {
        for handler in joinedGroupDeletedObservers.handlers.values {
            handler(info)
        }
    }

    func emitGroupMemberInfoChanged(_ info: OpenIMDemoBaselineGroupMemberInfo) {
        for handler in groupMemberInfoChangedObservers.handlers.values {
            handler(info)
        }
    }

    func emitGroupInfoChanged(_ info: OpenIMDemoBaselineGroupInfo) {
        for handler in groupInfoChangedObservers.handlers.values {
            handler(info)
        }
    }

    func emitFriendInfoChanged(_ info: OpenIMDemoBaselineFriendInfo) {
        for handler in friendInfoChangedObservers.handlers.values {
            handler(info)
        }
    }

    func emitMyUserInfoChanged(_ info: OpenIMDemoBaselineUserInfo) {
        for handler in currentUserInfoChangedObservers.handlers.values {
            handler(info)
        }
    }

    func emitGroupMembersChanged(added: Bool, info: OpenIMDemoBaselineGroupMemberInfo) {
        let target = added ? groupMemberAddedObservers.handlers.values : groupMemberDeletedObservers.handlers.values
        for handler in target {
            handler(info)
        }
    }

    func emitTotalUnreadCountChanged(_ count: Int) {
        for handler in totalUnreadCountChangedObservers.handlers.values {
            handler(count)
        }
    }

    func emitConversationChanged(_ conversations: [OpenIMDemoBaselineConversationInfo]) {
        for handler in conversationChangedObservers.handlers.values {
            handler(conversations)
        }
    }

    func emitRecordClear(conversationID: String) {
        for handler in recordClearObservers.handlers.values {
            handler(conversationID)
        }
    }

    private func add<T>(_ bag: inout ObserverBag<T>, _ handler: T) -> UUID {
        let token = UUID()
        bag.handlers[token] = handler
        return token
    }
}
