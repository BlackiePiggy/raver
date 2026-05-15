import Foundation
import Combine
import OSLog
import UIKit
import AVFoundation
#if canImport(ImSDK_Plus)
import ImSDK_Plus
#endif

struct TencentC2CReadReceiptEvent: Equatable {
    let conversationID: String
    let messageID: String?
    let peerRead: Bool
    let readAt: Date?
}

struct TencentMessageRevocationEvent: Equatable {
    let conversationID: String
    let messageID: String
    let displayText: String
}

enum TencentIMConnectionState: Equatable {
    case idle
    case disabled
    case unavailable
    case initializing
    case connecting
    case connected(userID: String)
    case userSigExpired
    case kickedOffline
    case failed(String)
}

#if canImport(ImSDK_Plus)
final class TencentIMAPNSBadgeBridge: NSObject, V2TIMAPNSListener {
    static let shared = TencentIMAPNSBadgeBridge()

    private let lock = NSLock()
    private var unifiedUnreadCount: UInt32 = 0

    func setUnifiedUnreadCount(_ count: Int) {
        lock.lock()
        unifiedUnreadCount = UInt32(max(0, count))
        lock.unlock()
    }

    func onSetAPPUnreadCount() -> UInt32 {
        lock.lock()
        let count = unifiedUnreadCount
        lock.unlock()
        return count
    }
}
#endif

@MainActor
final class TencentIMSession: NSObject {
    static let shared = TencentIMSession()
    private static let loggedInStatusRawValue = 1
    private static let loggedOutStatusRawValue = 3
    private static let infoLogLevelRawValue = 4
    private static let messageStatusSendingRawValue = 1
    private static let messageStatusSentRawValue = 2
    private static let messageStatusFailedRawValue = 3
    private static let messageStatusLocalRevokedRawValue = 6
    private static let elemTypeTextRawValue = 1
    private static let elemTypeCustomRawValue = 2
    private static let elemTypeImageRawValue = 3
    private static let elemTypeSoundRawValue = 4
    private static let elemTypeVideoRawValue = 5
    private static let elemTypeFileRawValue = 6
    private static let elemTypeLocationRawValue = 7
    private static let elemTypeFaceRawValue = 8
    private static let elemTypeGroupTipsRawValue = 9
    private static let elemTypeMergerRawValue = 10
    private static let elemTypeStreamRawValue = 11
    private static let conversationTypeDirectRawValue = 1
    private static let conversationTypeGroupRawValue = 2
    private static let receiveMessageOptRawValue = 0
    private static let receiveNoNotifyRawValue = 2
    private static let typingBusinessID = "user_typing_status"
    private static let customCardBusinessID = "raver_custom_card"
    private static let friendCreatedTipBusinessID = "raver_friend_created_tip"

    private struct TencentFriendCreatedTipEnvelope: Codable {
        let businessID: String
        let version: Int
        let text: String
    }

    private struct TencentEventCardEnvelope: Codable {
        let businessID: String
        let version: Int
        let cardType: String
        let payload: EventShareCardPayload
    }

    private struct TencentDJCardEnvelope: Codable {
        let businessID: String
        let version: Int
        let cardType: String
        let payload: DJShareCardPayload
    }

    private struct TencentSetCardEnvelope: Codable {
        let businessID: String
        let version: Int
        let cardType: String
        let payload: SetShareCardPayload
    }

    private struct TencentBrandCardEnvelope: Codable {
        let businessID: String
        let version: Int
        let cardType: String
        let payload: BrandShareCardPayload
    }

    private struct TencentLabelCardEnvelope: Codable {
        let businessID: String
        let version: Int
        let cardType: String
        let payload: LabelShareCardPayload
    }

    private struct TencentNewsCardEnvelope: Codable {
        let businessID: String
        let version: Int
        let cardType: String
        let payload: NewsShareCardPayload
    }

    private struct TencentRankingBoardCardEnvelope: Codable {
        let businessID: String
        let version: Int
        let cardType: String
        let payload: RankingBoardShareCardPayload
    }

    private struct TencentRatingEventCardEnvelope: Codable {
        let businessID: String
        let version: Int
        let cardType: String
        let payload: RatingEventShareCardPayload
    }

    private struct TencentRatingUnitCardEnvelope: Codable {
        let businessID: String
        let version: Int
        let cardType: String
        let payload: RatingUnitShareCardPayload
    }

    private struct TencentPostCardEnvelope: Codable {
        let businessID: String
        let version: Int
        let cardType: String
        let payload: PostShareCardPayload
    }

    private struct TencentCircleIDCardEnvelope: Codable {
        let businessID: String
        let version: Int
        let cardType: String
        let payload: CircleIDShareCardPayload
    }

    private struct TencentMyCheckinsCardEnvelope: Codable {
        let businessID: String
        let version: Int
        let cardType: String
        let payload: MyCheckinsShareCardPayload
    }

    private struct TencentEventRouteCardEnvelope: Codable {
        let businessID: String
        let version: Int
        let cardType: String
        let payload: EventRouteShareCardPayload
    }

    private struct TencentSquadOfflineActivityCardEnvelope: Codable {
        let businessID: String
        let version: Int
        let cardType: String
        let payload: SquadOfflineActivityCardPayload
    }

    var onStateChange: ((TencentIMConnectionState) -> Void)?
    var onUnreadCountChange: ((Int) -> Void)?
    let messageSubject = PassthroughSubject<ChatMessage, Never>()
    let conversationSubject = PassthroughSubject<[Conversation], Never>()
    let totalUnreadSubject = PassthroughSubject<Int, Never>()
    let c2cReadReceiptSubject = PassthroughSubject<[TencentC2CReadReceiptEvent], Never>()
    let messageRevocationSubject = PassthroughSubject<TencentMessageRevocationEvent, Never>()
    var messagePublisher: AnyPublisher<ChatMessage, Never> {
        messageSubject.eraseToAnyPublisher()
    }
    var conversationPublisher: AnyPublisher<[Conversation], Never> {
        conversationSubject.eraseToAnyPublisher()
    }
    var totalUnreadPublisher: AnyPublisher<Int, Never> {
        totalUnreadSubject.eraseToAnyPublisher()
    }
    var c2cReadReceiptPublisher: AnyPublisher<[TencentC2CReadReceiptEvent], Never> {
        c2cReadReceiptSubject.eraseToAnyPublisher()
    }
    var messageRevocationPublisher: AnyPublisher<TencentMessageRevocationEvent, Never> {
        messageRevocationSubject.eraseToAnyPublisher()
    }

    private(set) var state: TencentIMConnectionState = .idle {
        didSet {
            onStateChange?(state)
        }
    }
    private(set) var unreadCount: Int = 0 {
        didSet {
            guard oldValue != unreadCount else { return }
            onUnreadCountChange?(unreadCount)
        }
    }

    private var hasInitializedSDK = false
    private var hasRegisteredListeners = false
    private var currentBootstrap: TencentIMBootstrap?
    private var currentUserID: String?
    private var latestAPNSTokenData: Data?

    private override init() {
        super.init()
    }

    func updateAPNSToken(hexToken: String) async {
        latestAPNSTokenData = Self.decodeHexAPNSToken(hexToken)
        await applyAPNSConfigurationIfPossible(reason: "token-updated")
    }

    func connectionStateSnapshot() -> TencentIMConnectionState {
        state
    }

    func totalUnreadCountSnapshot() -> Int {
        unreadCount
    }

    func currentBusinessUserIDSnapshot() -> String? {
        currentUserID
    }

    func isBootstrapEnabledSnapshot() -> Bool {
        currentBootstrap?.enabled == true
    }

    func recoverSessionAfterAppBecameActive() async -> Bool {
#if canImport(ImSDK_Plus)
        guard hasInitializedSDK,
              let manager = V2TIMManager.sharedInstance() else { return false }
        guard manager.getLoginStatus().rawValue == Self.loggedInStatusRawValue,
              let userID = manager.getLoginUser(),
              !userID.isEmpty else {
            return false
        }

        currentUserID = userID
        state = .connected(userID: userID)
        await applyAPNSConfigurationIfPossible(reason: "recover-after-active")
        await refreshTotalUnreadCount()
        return true
#else
        false
#endif
    }

    func reset() {
#if canImport(ImSDK_Plus)
        if let manager = V2TIMManager.sharedInstance() {
            if hasRegisteredListeners {
                manager.removeIMSDKListener(listener: self)
                manager.removeConversationListener(listener: self)
                manager.removeAdvancedMsgListener(listener: self)
                hasRegisteredListeners = false
            }
            if hasInitializedSDK {
                manager.unInitSDK()
            }
        }
#endif
        hasInitializedSDK = false
        hasRegisteredListeners = false
        currentBootstrap = nil
        currentUserID = nil
        unreadCount = 0
        state = .idle
    }

    func sync(with bootstrap: TencentIMBootstrap?) async {
        guard let bootstrap else {
            reset()
            return
        }

        currentBootstrap = bootstrap

        guard bootstrap.enabled else {
            reset()
            state = .disabled
            return
        }

        guard bootstrap.sdkAppID > 0 else {
            reset()
            state = .failed("Tencent IM bootstrap missing sdkAppID")
            return
        }

        guard let userSig = bootstrap.userSig, !userSig.isEmpty else {
            reset()
            state = .failed("Tencent IM bootstrap missing userSig")
            return
        }

#if canImport(ImSDK_Plus)
        guard let manager = V2TIMManager.sharedInstance() else {
            state = .unavailable
            return
        }
        state = .initializing

        if !hasInitializedSDK {
            let config = V2TIMSDKConfig()
            config.logLevel = V2TIMLogLevel(rawValue: Self.infoLogLevelRawValue) ?? config.logLevel
            let initialized = manager.initSDK(Int32(bootstrap.sdkAppID), config: config)
            guard initialized else {
                state = .failed("Tencent IM initSDK failed")
                return
            }
            hasInitializedSDK = true
        }

        if !hasRegisteredListeners {
            manager.addIMSDKListener(listener: self)
            manager.addConversationListener(listener: self)
            manager.addAdvancedMsgListener(listener: self)
            hasRegisteredListeners = true
        }

        let loginStatus = manager.getLoginStatus()
        let loginUserID = manager.getLoginUser()
        if loginStatus.rawValue == Self.loggedInStatusRawValue, loginUserID == bootstrap.userID {
            currentUserID = bootstrap.userID
            state = .connected(userID: bootstrap.userID)
            await applyAPNSConfigurationIfPossible(reason: "reuse-existing-login")
            await refreshTotalUnreadCount()
            return
        }

        if loginStatus.rawValue != Self.loggedOutStatusRawValue {
            do {
                try await logout(manager: manager)
            } catch {
                // Continue attempting a clean login with the latest bootstrap.
            }
        }

        state = .connecting
        do {
            try await login(manager: manager, userID: bootstrap.userID, userSig: userSig)
            currentUserID = bootstrap.userID
            state = .connected(userID: bootstrap.userID)
            await applyAPNSConfigurationIfPossible(reason: "fresh-login")
            await refreshTotalUnreadCount()
        } catch {
            state = .failed(error.localizedDescription)
        }
#else
        state = .unavailable
#endif
    }

#if canImport(ImSDK_Plus)
    func fetchConversations(type: ConversationType) async throws -> [Conversation]? {
        guard currentBootstrap?.enabled == true else {
            return nil
        }

        let manager = try requireReadyManager()
        let remote = try await fetchAllConversations(manager: manager)
        return remote.compactMap(mapConversation(_:)).filter { $0.type == type }
    }

    func markConversationRead(conversationID: String) async throws -> Bool {
        guard currentBootstrap?.enabled == true else {
            return false
        }

        let manager = try requireReadyManager()
        let target = try await resolveConversationTarget(conversationID: conversationID, manager: manager)
        try await withCheckedThrowingContinuation { continuation in
            manager.cleanConversationUnreadMessageCount(
                conversationID: target.rawConversationID,
                cleanTimestamp: 0,
                cleanSequence: 0
            ) {
                continuation.resume()
            } fail: { code, desc in
                continuation.resume(throwing: self.buildTencentIMError(code: code, desc: desc, fallback: "Mark conversation read failed"))
            }
        }
        await refreshTotalUnreadCount()
        return true
    }

    func setConversationPinned(conversationID: String, pinned: Bool) async throws -> Bool {
        guard currentBootstrap?.enabled == true else {
            return false
        }

        let manager = try requireReadyManager()
        let target = try await resolveConversationTarget(conversationID: conversationID, manager: manager)
        try await withCheckedThrowingContinuation { continuation in
            manager.pinConversation(conversationID: target.rawConversationID, isPinned: pinned) {
                continuation.resume()
            } fail: { code, desc in
                continuation.resume(throwing: self.buildTencentIMError(code: code, desc: desc, fallback: "Set conversation pinned failed"))
            }
        }
        return true
    }

    func markConversationUnread(conversationID: String, unread: Bool) async throws -> Bool {
        guard currentBootstrap?.enabled == true else {
            return false
        }

        let manager = try requireReadyManager()
        let target = try await resolveConversationTarget(conversationID: conversationID, manager: manager)
        let markType = NSNumber(value: V2TIMConversationMarkType.CONVERSATION_MARK_TYPE_UNREAD.rawValue)
        try await withCheckedThrowingContinuation { continuation in
            manager.markConversation(
                conversationIDList: [target.rawConversationID],
                markType: markType,
                enableMark: unread
            ) { _ in
                continuation.resume()
            } fail: { code, desc in
                continuation.resume(throwing: self.buildTencentIMError(code: code, desc: desc, fallback: "Mark conversation unread failed"))
            }
        }
        await refreshTotalUnreadCount()
        return true
    }

    func hideConversation(conversationID: String) async throws -> Bool {
        guard currentBootstrap?.enabled == true else {
            return false
        }

        let manager = try requireReadyManager()
        let target = try await resolveConversationTarget(conversationID: conversationID, manager: manager)
        let markType = NSNumber(value: V2TIMConversationMarkType.CONVERSATION_MARK_TYPE_HIDE.rawValue)
        try await withCheckedThrowingContinuation { continuation in
            manager.markConversation(
                conversationIDList: [target.rawConversationID],
                markType: markType,
                enableMark: true
            ) { _ in
                continuation.resume()
            } fail: { code, desc in
                continuation.resume(throwing: self.buildTencentIMError(code: code, desc: desc, fallback: "Hide conversation failed"))
            }
        }
        await refreshTotalUnreadCount()
        return true
    }

    func setConversationMuted(conversationID: String, muted: Bool) async throws -> Bool {
        guard currentBootstrap?.enabled == true else {
            return false
        }

        let manager = try requireReadyManager()
        let target = try await resolveConversationTarget(conversationID: conversationID, manager: manager)
        let receiveOpt = V2TIMReceiveMessageOpt(
            rawValue: muted ? Self.receiveNoNotifyRawValue : Self.receiveMessageOptRawValue
        ) ?? V2TIMReceiveMessageOpt(rawValue: Self.receiveMessageOptRawValue)

        guard let opt = receiveOpt else {
            throw ServiceError.message("Tencent IM receive option unavailable")
        }

        switch target.type {
        case .direct:
            guard let userID = target.userID else {
                throw ServiceError.message("Tencent IM direct conversation missing userID")
            }
            try await withCheckedThrowingContinuation { continuation in
                manager.setC2CReceiveMessageOpt(userIDList: [userID], opt: opt) {
                    continuation.resume()
                } fail: { code, desc in
                    continuation.resume(throwing: self.buildTencentIMError(code: code, desc: desc, fallback: "Set direct conversation mute failed"))
                }
            }
        case .group:
            guard let groupID = target.groupID else {
                throw ServiceError.message("Tencent IM group conversation missing groupID")
            }
            try await withCheckedThrowingContinuation { continuation in
                manager.setGroupReceiveMessageOpt(groupID: groupID, opt: opt) {
                    continuation.resume()
                } fail: { code, desc in
                    continuation.resume(throwing: self.buildTencentIMError(code: code, desc: desc, fallback: "Set group conversation mute failed"))
                }
            }
        }

        return true
    }

    func clearConversationHistory(conversationID: String) async throws -> Bool {
        guard currentBootstrap?.enabled == true else {
            return false
        }

        let manager = try requireReadyManager()
        let target = try await resolveConversationTarget(conversationID: conversationID, manager: manager)

        switch target.type {
        case .direct:
            guard let userID = target.userID else {
                throw ServiceError.message("Tencent IM direct conversation missing userID")
            }
            try await withCheckedThrowingContinuation { continuation in
                manager.clearC2CHistoryMessage(userID: userID) {
                    continuation.resume()
                } fail: { code, desc in
                    continuation.resume(throwing: self.buildTencentIMError(code: code, desc: desc, fallback: "Clear direct conversation history failed"))
                }
            }
        case .group:
            guard let groupID = target.groupID else {
                throw ServiceError.message("Tencent IM group conversation missing groupID")
            }
            try await withCheckedThrowingContinuation { continuation in
                manager.clearGroupHistoryMessage(groupID: groupID) {
                    continuation.resume()
                } fail: { code, desc in
                    continuation.resume(throwing: self.buildTencentIMError(code: code, desc: desc, fallback: "Clear group conversation history failed"))
                }
            }
        }

        await refreshTotalUnreadCount()
        return true
    }

    func inviteUsersToSquad(squadID: String, userIDs: [String]) async throws -> Bool {
        guard currentBootstrap?.enabled == true else {
            return false
        }

        let normalizedSquadID = TencentIMIdentity.toTencentIMSquadGroupID(squadID)
        let targetUserIDs = Array(
            Set(
                userIDs
                    .map { TencentIMIdentity.toTencentIMUserID($0) }
                    .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            )
        ).sorted()

        guard !normalizedSquadID.isEmpty else {
            throw ServiceError.message("Tencent IM groupID is empty")
        }

        guard !targetUserIDs.isEmpty else {
            return true
        }

        let manager = try requireReadyManager()
        let _: [V2TIMGroupMemberOperationResult] = try await withCheckedThrowingContinuation { continuation in
            manager.inviteUserToGroup(groupID: normalizedSquadID, userList: targetUserIDs) { results in
                continuation.resume(returning: results ?? [])
            } fail: { code, desc in
                continuation.resume(
                    throwing: self.buildTencentIMError(
                        code: code,
                        desc: desc,
                        fallback: "Invite users to Tencent IM group failed"
                    )
                )
            }
        }
        return true
    }

    func fetchSquadInviteOption(squadID: String) async throws -> GroupInviteOption {
        guard currentBootstrap?.enabled == true else {
            return .forbid
        }

        let manager = try requireReadyManager()
        let groupInfo = try await fetchGroupInfo(
            groupID: TencentIMIdentity.toTencentIMSquadGroupID(squadID),
            manager: manager
        )

        switch groupInfo.groupApproveOpt {
        case .GROUP_ADD_ANY:
            return .any
        case .GROUP_ADD_AUTH:
            return .auth
        case .GROUP_ADD_FORBID:
            return .forbid
        default:
            return .forbid
        }
    }

    func setSquadInviteOption(squadID: String, option: GroupInviteOption) async throws -> Bool {
        guard currentBootstrap?.enabled == true else {
            return false
        }

        let manager = try requireReadyManager()
        let info = V2TIMGroupInfo()
        info.groupID = TencentIMIdentity.toTencentIMSquadGroupID(squadID)
        switch option {
        case .forbid:
            info.groupApproveOpt = .GROUP_ADD_FORBID
        case .auth:
            info.groupApproveOpt = .GROUP_ADD_AUTH
        case .any:
            info.groupApproveOpt = .GROUP_ADD_ANY
        }

        try await withCheckedThrowingContinuation { continuation in
            manager.setGroupInfo(info: info) {
                continuation.resume()
            } fail: { code, desc in
                continuation.resume(
                    throwing: self.buildTencentIMError(
                        code: code,
                        desc: desc,
                        fallback: "Set Tencent IM group invite option failed"
                    )
                )
            }
        }
        return true
    }

    func fetchSquadMemberDirectory(squadID: String) async throws -> GroupMemberDirectory {
        guard currentBootstrap?.enabled == true else {
            return GroupMemberDirectory(members: [], myRole: nil)
        }

        let manager = try requireReadyManager()
        let groupID = TencentIMIdentity.toTencentIMSquadGroupID(squadID)
        let loginUserID = manager.getLoginUser()
        var nextSeq: UInt64 = 0
        var aggregatedMembers: [V2TIMGroupMemberFullInfo] = []

        repeat {
            let page: (nextSeq: UInt64, members: [V2TIMGroupMemberFullInfo]) = try await withCheckedThrowingContinuation { continuation in
                manager.getGroupMemberList(
                    groupID,
                    filter: UInt32(V2TIMGroupMemberFilter.GROUP_MEMBER_FILTER_ALL.rawValue),
                    nextSeq: nextSeq
                ) { fetchedNextSeq, memberList in
                    continuation.resume(returning: (fetchedNextSeq, memberList ?? []))
                } fail: { code, desc in
                    continuation.resume(
                        throwing: self.buildTencentIMError(
                            code: code,
                            desc: desc,
                            fallback: "Fetch Tencent IM group member list failed"
                        )
                    )
                }
            }

            aggregatedMembers.append(contentsOf: page.members)
            nextSeq = page.nextSeq
        } while nextSeq != 0

        let members = aggregatedMembers.map { mapSquadMemberProfile(from: $0) }
        let myRole = aggregatedMembers.first(where: { normalizedText($0.userID) == normalizedText(loginUserID) }).map {
            mapSquadMemberRole(rawValue: $0.role)
        }
        return GroupMemberDirectory(members: members, myRole: myRole)
    }

    func fetchSquadProfile(squadID: String) async throws -> SquadProfile {
        guard currentBootstrap?.enabled == true else {
            throw ServiceError.message("Tencent IM unavailable")
        }

        let manager = try requireReadyManager()
        let groupID = TencentIMIdentity.toTencentIMSquadGroupID(squadID)
        let groupInfo = try await fetchGroupInfo(groupID: groupID, manager: manager)
        let memberDirectory = try await fetchSquadMemberDirectory(squadID: squadID)
        let loginUserID = normalizedText(manager.getLoginUser()) ?? ""
        let myMember = memberDirectory.members.first {
            TencentIMIdentity.toTencentIMUserID($0.id) == loginUserID
        }

        let ownerTencentUserID = normalizedText(groupInfo.owner) ?? ""
        let ownerMember = memberDirectory.members.first {
            TencentIMIdentity.toTencentIMUserID($0.id) == ownerTencentUserID
        }
        let leader = ownerMember.map { member in
            UserSummary(
                id: member.id,
                username: member.username,
                displayName: member.displayName,
                avatarURL: member.avatarURL,
                isFollowing: member.isFollowing
            )
        } ?? UserSummary(
            id: TencentIMIdentity.normalizePlatformUserIDForProfile(ownerTencentUserID),
            username: TencentIMIdentity.normalizePlatformUserIDForProfile(ownerTencentUserID),
            displayName: ownerTencentUserID.isEmpty ? (normalizedText(groupInfo.groupName) ?? squadID) : ownerTencentUserID,
            avatarURL: nil,
            isFollowing: false
        )

        let myRole = memberDirectory.myRole ?? mapSquadMemberRole(rawValue: groupInfo.role)
        let updatedTimestamp = max(groupInfo.lastInfoTime, groupInfo.lastMessageTime, groupInfo.createTime)

        return SquadProfile(
            id: TencentIMIdentity.normalizePlatformSquadID(groupID),
            name: normalizedText(groupInfo.groupName) ?? TencentIMIdentity.normalizePlatformSquadID(groupID),
            description: normalizedText(groupInfo.introduction),
            avatarURL: normalizedText(groupInfo.faceURL),
            bannerURL: nil,
            notice: normalizedText(groupInfo.notification) ?? "",
            qrCodeURL: nil,
            isPublic: isTencentPublicGroupType(groupInfo.groupType),
            maxMembers: max(0, Int(groupInfo.memberMaxCount)),
            memberCount: max(memberDirectory.members.count, Int(groupInfo.memberCount)),
            isMember: true,
            canEditGroup: myRole == "leader" || myRole == "admin",
            myRole: myRole,
            myNickname: myMember?.nickname,
            myNotificationsEnabled: isGroupNotificationsEnabled(groupInfo.recvOpt),
            leader: leader,
            members: memberDirectory.members,
            lastMessage: nil,
            updatedAt: Date(timeIntervalSince1970: TimeInterval(updatedTimestamp)),
            recentMessages: [],
            activities: []
        )
    }

    func joinSquad(squadID: String) async throws -> Bool {
        guard currentBootstrap?.enabled == true else {
            return false
        }

        let manager = try requireReadyManager()
        let groupID = TencentIMIdentity.toTencentIMSquadGroupID(squadID)
        try await withCheckedThrowingContinuation { continuation in
            manager.joinGroup(groupID: groupID, msg: nil) {
                continuation.resume()
            } fail: { code, desc in
                continuation.resume(
                    throwing: self.buildTencentIMError(
                        code: code,
                        desc: desc,
                        fallback: "Join Tencent IM group failed"
                    )
                )
            }
        }
        return true
    }

    func leaveSquad(squadID: String) async throws -> Bool {
        guard currentBootstrap?.enabled == true else {
            return false
        }

        let manager = try requireReadyManager()
        let groupID = TencentIMIdentity.toTencentIMSquadGroupID(squadID)
        try await withCheckedThrowingContinuation { continuation in
            manager.quitGroup(groupID: groupID) {
                continuation.resume()
            } fail: { code, desc in
                continuation.resume(
                    throwing: self.buildTencentIMError(
                        code: code,
                        desc: desc,
                        fallback: "Leave Tencent IM group failed"
                    )
                )
            }
        }
        return true
    }

    func disbandSquad(squadID: String) async throws -> Bool {
        guard currentBootstrap?.enabled == true else {
            return false
        }

        let manager = try requireReadyManager()
        let groupID = TencentIMIdentity.toTencentIMSquadGroupID(squadID)
        try await withCheckedThrowingContinuation { continuation in
            manager.dismissGroup(groupID: groupID) {
                continuation.resume()
            } fail: { code, desc in
                continuation.resume(
                    throwing: self.buildTencentIMError(
                        code: code,
                        desc: desc,
                        fallback: "Dismiss Tencent IM group failed"
                    )
                )
            }
        }
        return true
    }

    func createSquad(input: CreateSquadInput) async throws -> Conversation? {
        guard currentBootstrap?.enabled == true else {
            return nil
        }

        let manager = try requireReadyManager()
        let platformGroupUUID = UUID().uuidString.lowercased()
        let groupID = TencentIMIdentity.toTencentIMSquadGroupID(platformGroupUUID)
        let groupInfo = V2TIMGroupInfo()
        groupInfo.groupID = groupID
        groupInfo.groupType = input.isPublic ? "Public" : "Work"
        let groupName = input.name?.trimmingCharacters(in: .whitespacesAndNewlines)
        groupInfo.groupName = (groupName?.isEmpty == false ? groupName : LT("新建群聊", "New Group", "新しいグループチャット"))!
        groupInfo.introduction = input.description?.trimmingCharacters(in: .whitespacesAndNewlines)

        let memberList: [V2TIMCreateGroupMemberInfo] = Array(Set(input.memberIds)).map { rawUserID in
            let info = V2TIMCreateGroupMemberInfo()
            info.userID = TencentIMIdentity.toTencentIMUserID(rawUserID)
            return info
        }

        let createdGroupID: String = try await withCheckedThrowingContinuation { continuation in
            manager.createGroup(info: groupInfo, memberList: memberList) { createdGroupID in
                continuation.resume(returning: createdGroupID ?? groupID)
            } fail: { code, desc in
                continuation.resume(
                    throwing: self.buildTencentIMError(
                        code: code,
                        desc: desc,
                        fallback: "Create Tencent IM group failed"
                    )
                )
            }
        }

        return Conversation(
            id: TencentIMIdentity.normalizePlatformSquadID(createdGroupID),
            type: .group,
            title: groupInfo.groupName ?? LT("新建群聊", "New Group", "新しいグループチャット"),
            avatarURL: normalizedText(groupInfo.faceURL),
            sdkConversationID: "group_\(createdGroupID)",
            lastMessage: LT("暂无消息", "No messages yet", "メッセージはまだありません"),
            lastMessageSenderID: nil,
            unreadCount: 0,
            updatedAt: Date(),
            peer: nil
        )
    }

    func updateSquadMySettings(squadID: String, input: UpdateSquadMySettingsInput) async throws -> Bool {
        guard currentBootstrap?.enabled == true else {
            return false
        }

        let manager = try requireReadyManager()
        let groupID = TencentIMIdentity.toTencentIMSquadGroupID(squadID)

        let memberInfo = V2TIMGroupMemberFullInfo()
        memberInfo.userID = manager.getLoginUser()
        let trimmedNameCard = normalizedText(input.nickname)
        memberInfo.nameCard = trimmedNameCard
        try await withCheckedThrowingContinuation { continuation in
            manager.setGroupMemberInfo(groupID: groupID, info: memberInfo) {
                continuation.resume()
            } fail: { code, desc in
                continuation.resume(
                    throwing: self.buildTencentIMError(
                        code: code,
                        desc: desc,
                        fallback: "Update Tencent IM group nickname failed"
                    )
                )
            }
        }

        let opt = V2TIMReceiveMessageOpt(
            rawValue: input.notificationsEnabled ? Self.receiveMessageOptRawValue : Self.receiveNoNotifyRawValue
        ) ?? V2TIMReceiveMessageOpt(rawValue: Self.receiveMessageOptRawValue)
        guard let opt else {
            throw ServiceError.message("Tencent IM group receive option unavailable")
        }
        try await withCheckedThrowingContinuation { continuation in
            manager.setGroupReceiveMessageOpt(groupID: groupID, opt: opt) {
                continuation.resume()
            } fail: { code, desc in
                continuation.resume(
                    throwing: self.buildTencentIMError(
                        code: code,
                        desc: desc,
                        fallback: "Update Tencent IM group receive option failed"
                    )
                )
            }
        }
        return true
    }

    func updateSquadInfo(squadID: String, input: UpdateSquadInfoInput) async throws -> Bool {
        guard currentBootstrap?.enabled == true else {
            return false
        }

        let manager = try requireReadyManager()
        let info = V2TIMGroupInfo()
        info.groupID = TencentIMIdentity.toTencentIMSquadGroupID(squadID)
        info.groupName = input.name.trimmingCharacters(in: .whitespacesAndNewlines)
        info.introduction = input.description.trimmingCharacters(in: .whitespacesAndNewlines)
        info.notification = input.notice.trimmingCharacters(in: .whitespacesAndNewlines)
        info.faceURL = normalizedText(input.avatarURL)
        try await withCheckedThrowingContinuation { continuation in
            manager.setGroupInfo(info: info) {
                continuation.resume()
            } fail: { code, desc in
                continuation.resume(
                    throwing: self.buildTencentIMError(
                        code: code,
                        desc: desc,
                        fallback: "Update Tencent IM group info failed"
                    )
                )
            }
        }
        return true
    }

    func updateSquadMemberRole(squadID: String, memberUserID: String, role: String) async throws -> Bool {
        guard currentBootstrap?.enabled == true else {
            return false
        }

        let manager = try requireReadyManager()
        let groupID = TencentIMIdentity.toTencentIMSquadGroupID(squadID)
        let targetUserID = TencentIMIdentity.toTencentIMUserID(memberUserID)

        switch role {
        case "leader":
            try await withCheckedThrowingContinuation { continuation in
                manager.transferGroupOwner(groupID: groupID, memberUserID: targetUserID) {
                    continuation.resume()
                } fail: { code, desc in
                    continuation.resume(
                        throwing: self.buildTencentIMError(
                            code: code,
                            desc: desc,
                            fallback: "Transfer Tencent IM group owner failed"
                        )
                    )
                }
            }
        case "admin":
            try await withCheckedThrowingContinuation { continuation in
                manager.setGroupMemberRole(
                    groupID: groupID,
                    memberUserID: targetUserID,
                    newRole: UInt32(V2TIMGroupMemberRole.GROUP_MEMBER_ROLE_ADMIN.rawValue)
                ) {
                    continuation.resume()
                } fail: { code, desc in
                    continuation.resume(
                        throwing: self.buildTencentIMError(
                            code: code,
                            desc: desc,
                            fallback: "Promote Tencent IM admin failed"
                        )
                    )
                }
            }
        default:
            try await withCheckedThrowingContinuation { continuation in
                manager.setGroupMemberRole(
                    groupID: groupID,
                    memberUserID: targetUserID,
                    newRole: UInt32(V2TIMGroupMemberRole.GROUP_MEMBER_ROLE_MEMBER.rawValue)
                ) {
                    continuation.resume()
                } fail: { code, desc in
                    continuation.resume(
                        throwing: self.buildTencentIMError(
                            code: code,
                            desc: desc,
                            fallback: "Demote Tencent IM member failed"
                        )
                    )
                }
            }
        }
        return true
    }

    func removeUsersFromSquad(squadID: String, userIDs: [String]) async throws -> Bool {
        guard currentBootstrap?.enabled == true else {
            return false
        }

        let normalizedSquadID = TencentIMIdentity.toTencentIMSquadGroupID(squadID)
        let targetUserIDs = Array(
            Set(
                userIDs
                    .map { TencentIMIdentity.toTencentIMUserID($0) }
                    .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            )
        ).sorted()

        guard !normalizedSquadID.isEmpty else {
            throw ServiceError.message("Tencent IM groupID is empty")
        }

        guard !targetUserIDs.isEmpty else {
            return true
        }

        let manager = try requireReadyManager()
        let _: [V2TIMGroupMemberOperationResult] = try await withCheckedThrowingContinuation { continuation in
            manager.kickGroupMember(normalizedSquadID, memberList: targetUserIDs, reason: "") { results in
                continuation.resume(returning: results ?? [])
            } fail: { code, desc in
                continuation.resume(
                    throwing: self.buildTencentIMError(
                        code: code,
                        desc: desc,
                        fallback: "Remove users from Tencent IM group failed"
                    )
                )
            }
        }
        return true
    }

    func fetchFriendRemark(userID: String) async throws -> String? {
        guard currentBootstrap?.enabled == true else {
            return nil
        }

        let manager = try requireReadyManager()
        let targetUserID = TencentIMIdentity.toTencentIMUserID(userID)
        let results: [V2TIMFriendInfoResult] = try await withCheckedThrowingContinuation { continuation in
            manager.getFriendsInfo([targetUserID]) { infoResults in
                continuation.resume(returning: infoResults ?? [])
            } fail: { code, desc in
                continuation.resume(throwing: self.buildTencentIMError(code: code, desc: desc, fallback: "Fetch friend remark failed"))
            }
        }

        let match = results.first {
            $0.friendInfo.userID == targetUserID
        } ?? results.first
        return normalizedText(match?.friendInfo.friendRemark)
    }

    func isTencentFriend(userID: String) async throws -> Bool {
        guard currentBootstrap?.enabled == true else {
            return false
        }

        let manager = try requireReadyManager()
        let targetUserID = TencentIMIdentity.toTencentIMUserID(userID)
        let results: [V2TIMFriendCheckResult] = try await withCheckedThrowingContinuation { continuation in
            manager.checkFriend(userIDList: [targetUserID], checkType: .FRIEND_TYPE_BOTH) { resultList in
                continuation.resume(returning: resultList ?? [])
            } fail: { code, desc in
                continuation.resume(
                    throwing: self.buildTencentIMError(
                        code: code,
                        desc: desc,
                        fallback: "Check Tencent friend relation failed"
                    )
                )
            }
        }

        guard let result = results.first else { return false }
        switch result.relationType {
        case .FRIEND_RELATION_TYPE_IN_MY_FRIEND_LIST, .FRIEND_RELATION_TYPE_BOTH_WAY:
            return true
        default:
            return false
        }
    }

    func setFriendRemark(userID: String, remark: String?) async throws -> Bool {
        guard currentBootstrap?.enabled == true else {
            return false
        }

        let manager = try requireReadyManager()
        let info = V2TIMFriendInfo()
        info.userID = TencentIMIdentity.toTencentIMUserID(userID)
        let trimmedRemark = normalizedText(remark)
        info.friendRemark = trimmedRemark
        try await withCheckedThrowingContinuation { continuation in
            manager.setFriendInfo(info: info) {
                continuation.resume()
            } fail: { code, desc in
                continuation.resume(throwing: self.buildTencentIMError(code: code, desc: desc, fallback: "Set friend remark failed"))
            }
        }
        return true
    }

    func isUserBlacklisted(userID: String) async throws -> Bool {
        guard currentBootstrap?.enabled == true else {
            return false
        }

        let manager = try requireReadyManager()
        let targetUserID = TencentIMIdentity.toTencentIMUserID(userID)
        let list: [V2TIMFriendInfo] = try await withCheckedThrowingContinuation { continuation in
            manager.getBlackList { infoList in
                continuation.resume(returning: infoList ?? [])
            } fail: { code, desc in
                continuation.resume(throwing: self.buildTencentIMError(code: code, desc: desc, fallback: "Fetch blacklist failed"))
            }
        }
        return list.contains { $0.userID == targetUserID }
    }

    func setUserBlacklisted(userID: String, blacklisted: Bool) async throws -> Bool {
        guard currentBootstrap?.enabled == true else {
            return false
        }

        let manager = try requireReadyManager()
        let targetUserID = TencentIMIdentity.toTencentIMUserID(userID)

        if blacklisted {
            let _: [V2TIMFriendOperationResult] = try await withCheckedThrowingContinuation { continuation in
                manager.addToBlackList(userIDList: [targetUserID]) { results in
                    continuation.resume(returning: results ?? [])
                } fail: { code, desc in
                    continuation.resume(throwing: self.buildTencentIMError(code: code, desc: desc, fallback: "Add to blacklist failed"))
                }
            }
        } else {
            let _: [V2TIMFriendOperationResult] = try await withCheckedThrowingContinuation { continuation in
                manager.deleteFromBlackList(userIDList: [targetUserID]) { results in
                    continuation.resume(returning: results ?? [])
                } fail: { code, desc in
                    continuation.resume(throwing: self.buildTencentIMError(code: code, desc: desc, fallback: "Remove from blacklist failed"))
                }
            }
        }

        return true
    }

    func fetchMessages(conversationID: String, count: Int = 50) async throws -> [ChatMessage]? {
        let page = try await fetchMessagesPage(
            conversationID: conversationID,
            startClientMsgID: nil,
            count: count
        )
        return page?.messages
    }

    func fetchMessagesPage(
        conversationID: String,
        startClientMsgID: String?,
        count: Int = 50
    ) async throws -> ChatMessageHistoryPage? {
        guard currentBootstrap?.enabled == true else {
            return nil
        }

        let manager = try requireReadyManager()
        let target = try await resolveConversationTarget(conversationID: conversationID, manager: manager)
        let anchorMessage = try await resolveHistoryAnchorMessage(
            manager: manager,
            target: target,
            startClientMsgID: startClientMsgID
        )
        let remoteMessages = try await fetchHistoryMessages(
            manager: manager,
            target: target,
            count: max(1, count),
            lastMessage: anchorMessage
        )

        var mapped: [ChatMessage] = []
        mapped.reserveCapacity(remoteMessages.count)
        for message in remoteMessages {
            mapped.append(await mapMessage(message, conversationID: target.businessConversationID))
        }

        let sorted = mapped.sorted { lhs, rhs in
            if lhs.createdAt != rhs.createdAt {
                return lhs.createdAt < rhs.createdAt
            }
            return lhs.id < rhs.id
        }
        return ChatMessageHistoryPage(messages: sorted, isEnd: remoteMessages.count < max(1, count))
    }

    func sendTextMessage(
        conversationID: String,
        content: String,
        mentionedUserIDs: [String] = []
    ) async throws -> ChatMessage? {
        guard currentBootstrap?.enabled == true else {
            return nil
        }

        let manager = try requireReadyManager()
        let target = try await resolveConversationTarget(conversationID: conversationID, manager: manager)
        guard let rawMessage = manager.createTextMessage(text: content) else {
            throw ServiceError.message("Tencent IM create text message failed")
        }
        let message = try createMentionSignedTextMessageIfNeeded(
            manager: manager,
            message: rawMessage,
            target: target,
            mentionedUserIDs: mentionedUserIDs
        )
        message.needReadReceipt = shouldRequestReadReceipt(for: target)
        let offlinePushInfo = await buildTextOfflinePushInfo(
            manager: manager,
            target: target,
            content: content,
            mentionedUserIDs: mentionedUserIDs
        )
        return try await sendMessage(
            manager: manager,
            message: message,
            target: target,
            offlinePushInfo: offlinePushInfo,
            progress: nil
        )
    }

    private func createMentionSignedTextMessageIfNeeded(
        manager: V2TIMManager,
        message: V2TIMMessage,
        target: TencentConversationTarget,
        mentionedUserIDs: [String]
    ) throws -> V2TIMMessage {
        guard target.type == .group else { return message }
        let atUserList = buildTencentIMAtUserList(from: mentionedUserIDs)
        guard atUserList.count > 0 else { return message }
        guard let signedMessage = manager.createAtSignedGroupMessage(message: message, atUserList: atUserList) else {
            throw ServiceError.message(LT("腾讯 IM 群 @ 消息创建失败", "Tencent IM failed to create group @ message", "Tencent IMのグループ@メッセージ作成に失敗しました"))
        }
        return signedMessage
    }

    private func buildTencentIMAtUserList(from mentionedUserIDs: [String]) -> NSMutableArray {
        let result = NSMutableArray()
        for mentionedUserID in mentionedUserIDs {
            let trimmed = mentionedUserID.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            if trimmed == "all" {
                result.add(kImSDK_MesssageAtALL)
                continue
            }
            result.add(TencentIMIdentity.toTencentIMUserID(trimmed))
        }
        return result
    }

    func sendEventCardMessage(
        conversationID: String,
        payload: EventShareCardPayload
    ) async throws -> ChatMessage? {
        guard currentBootstrap?.enabled == true else {
            return nil
        }

        let manager = try requireReadyManager()
        let target = try await resolveConversationTarget(conversationID: conversationID, manager: manager)
        let envelope = TencentEventCardEnvelope(
            businessID: Self.customCardBusinessID,
            version: 1,
            cardType: "event",
            payload: payload
        )
        let data = try JSONEncoder().encode(envelope)
        guard let message = manager.createCustomMessage(data: data) else {
            throw ServiceError.message("Tencent IM create event card message failed")
        }
        message.needReadReceipt = shouldRequestReadReceipt(for: target)
        let offlinePushInfo = await buildCardOfflinePushInfo(
            manager: manager,
            target: target,
            previewText: "\(LT("[活动卡片]", "[Event Card]", "[イベントカード]")) \(payload.eventName)"
        )
        var sent = try await sendMessage(
            manager: manager,
            message: message,
            target: target,
            offlinePushInfo: offlinePushInfo,
            progress: nil
        )
        sent.kind = .card
        sent.content = String(data: data, encoding: .utf8) ?? payload.eventName
        sent.media = ChatMessageMediaPayload(
            thumbnailURL: payload.coverImageURL
        )
        return sent
    }

    func sendDJCardMessage(
        conversationID: String,
        payload: DJShareCardPayload
    ) async throws -> ChatMessage? {
        guard currentBootstrap?.enabled == true else {
            return nil
        }

        let manager = try requireReadyManager()
        let target = try await resolveConversationTarget(conversationID: conversationID, manager: manager)
        let envelope = TencentDJCardEnvelope(
            businessID: Self.customCardBusinessID,
            version: 1,
            cardType: "dj",
            payload: payload
        )
        let data = try JSONEncoder().encode(envelope)
        guard let message = manager.createCustomMessage(data: data) else {
            throw ServiceError.message("Tencent IM create dj card message failed")
        }
        message.needReadReceipt = shouldRequestReadReceipt(for: target)
        let offlinePushInfo = await buildCardOfflinePushInfo(
            manager: manager,
            target: target,
            previewText: "\(LT("[DJ卡片]", "[DJ Card]", "[DJカード]")) \(payload.djName)"
        )
        var sent = try await sendMessage(
            manager: manager,
            message: message,
            target: target,
            offlinePushInfo: offlinePushInfo,
            progress: nil
        )
        sent.kind = .card
        sent.content = String(data: data, encoding: .utf8) ?? payload.djName
        sent.media = ChatMessageMediaPayload(
            thumbnailURL: payload.coverImageURL
        )
        return sent
    }

    func sendSetCardMessage(
        conversationID: String,
        payload: SetShareCardPayload
    ) async throws -> ChatMessage? {
        guard currentBootstrap?.enabled == true else {
            return nil
        }

        let manager = try requireReadyManager()
        let target = try await resolveConversationTarget(conversationID: conversationID, manager: manager)
        let envelope = TencentSetCardEnvelope(
            businessID: Self.customCardBusinessID,
            version: 1,
            cardType: "set",
            payload: payload
        )
        let data = try JSONEncoder().encode(envelope)
        guard let message = manager.createCustomMessage(data: data) else {
            throw ServiceError.message("Tencent IM create set card message failed")
        }
        message.needReadReceipt = shouldRequestReadReceipt(for: target)
        let offlinePushInfo = await buildCardOfflinePushInfo(
            manager: manager,
            target: target,
            previewText: "\(LT("[Set卡片]", "[Set Card]", "[Setカード]")) \(payload.setTitle)"
        )
        var sent = try await sendMessage(
            manager: manager,
            message: message,
            target: target,
            offlinePushInfo: offlinePushInfo,
            progress: nil
        )
        sent.kind = .card
        sent.content = String(data: data, encoding: .utf8) ?? payload.setTitle
        sent.media = ChatMessageMediaPayload(
            thumbnailURL: payload.coverImageURL
        )
        return sent
    }

    func sendBrandCardMessage(
        conversationID: String,
        payload: BrandShareCardPayload
    ) async throws -> ChatMessage? {
        guard currentBootstrap?.enabled == true else {
            return nil
        }

        let manager = try requireReadyManager()
        let target = try await resolveConversationTarget(conversationID: conversationID, manager: manager)
        let envelope = TencentBrandCardEnvelope(
            businessID: Self.customCardBusinessID,
            version: 1,
            cardType: "brand",
            payload: payload
        )
        let data = try JSONEncoder().encode(envelope)
        guard let message = manager.createCustomMessage(data: data) else {
            throw ServiceError.message("Tencent IM create brand card message failed")
        }
        message.needReadReceipt = shouldRequestReadReceipt(for: target)
        let offlinePushInfo = await buildCardOfflinePushInfo(
            manager: manager,
            target: target,
            previewText: "\(LT("[音乐节卡片]", "[Festival Card]", "[フェスカード]")) \(payload.brandName)"
        )
        var sent = try await sendMessage(
            manager: manager,
            message: message,
            target: target,
            offlinePushInfo: offlinePushInfo,
            progress: nil
        )
        sent.kind = .card
        sent.content = String(data: data, encoding: .utf8) ?? payload.brandName
        sent.media = ChatMessageMediaPayload(
            thumbnailURL: payload.coverImageURL
        )
        return sent
    }

    func sendLabelCardMessage(
        conversationID: String,
        payload: LabelShareCardPayload
    ) async throws -> ChatMessage? {
        guard currentBootstrap?.enabled == true else {
            return nil
        }

        let manager = try requireReadyManager()
        let target = try await resolveConversationTarget(conversationID: conversationID, manager: manager)
        let envelope = TencentLabelCardEnvelope(
            businessID: Self.customCardBusinessID,
            version: 1,
            cardType: "label",
            payload: payload
        )
        let data = try JSONEncoder().encode(envelope)
        guard let message = manager.createCustomMessage(data: data) else {
            throw ServiceError.message("Tencent IM create label card message failed")
        }
        message.needReadReceipt = shouldRequestReadReceipt(for: target)
        let offlinePushInfo = await buildCardOfflinePushInfo(
            manager: manager,
            target: target,
            previewText: "\(LT("[厂牌卡片]", "[Label Card]", "[レーベルカード]")) \(payload.labelName)"
        )
        var sent = try await sendMessage(
            manager: manager,
            message: message,
            target: target,
            offlinePushInfo: offlinePushInfo,
            progress: nil
        )
        sent.kind = .card
        sent.content = String(data: data, encoding: .utf8) ?? payload.labelName
        sent.media = ChatMessageMediaPayload(
            thumbnailURL: payload.coverImageURL
        )
        return sent
    }

    func sendNewsCardMessage(
        conversationID: String,
        payload: NewsShareCardPayload
    ) async throws -> ChatMessage? {
        guard currentBootstrap?.enabled == true else {
            return nil
        }

        let manager = try requireReadyManager()
        let target = try await resolveConversationTarget(conversationID: conversationID, manager: manager)
        let envelope = TencentNewsCardEnvelope(
            businessID: Self.customCardBusinessID,
            version: 1,
            cardType: "news",
            payload: payload
        )
        let data = try JSONEncoder().encode(envelope)
        guard let message = manager.createCustomMessage(data: data) else {
            throw ServiceError.message("Tencent IM create news card message failed")
        }
        message.needReadReceipt = shouldRequestReadReceipt(for: target)
        let offlinePushInfo = await buildCardOfflinePushInfo(
            manager: manager,
            target: target,
            previewText: "\(LT("[资讯卡片]", "[News Card]", "[ニュースカード]")) \(payload.headline)"
        )
        var sent = try await sendMessage(
            manager: manager,
            message: message,
            target: target,
            offlinePushInfo: offlinePushInfo,
            progress: nil
        )
        sent.kind = .card
        sent.content = String(data: data, encoding: .utf8) ?? payload.headline
        sent.media = ChatMessageMediaPayload(
            thumbnailURL: payload.coverImageURL
        )
        return sent
    }

    func sendRankingBoardCardMessage(
        conversationID: String,
        payload: RankingBoardShareCardPayload
    ) async throws -> ChatMessage? {
        guard currentBootstrap?.enabled == true else {
            return nil
        }

        let manager = try requireReadyManager()
        let target = try await resolveConversationTarget(conversationID: conversationID, manager: manager)
        let envelope = TencentRankingBoardCardEnvelope(
            businessID: Self.customCardBusinessID,
            version: 1,
            cardType: "ranking",
            payload: payload
        )
        let data = try JSONEncoder().encode(envelope)
        guard let message = manager.createCustomMessage(data: data) else {
            throw ServiceError.message("Tencent IM create ranking board card message failed")
        }
        message.needReadReceipt = shouldRequestReadReceipt(for: target)
        let offlinePushInfo = await buildCardOfflinePushInfo(
            manager: manager,
            target: target,
            previewText: "\(LT("[榜单卡片]", "[Ranking Card]", "[ランキングカード]")) \(payload.boardName) · \(payload.year)"
        )
        var sent = try await sendMessage(
            manager: manager,
            message: message,
            target: target,
            offlinePushInfo: offlinePushInfo,
            progress: nil
        )
        sent.kind = .card
        sent.content = String(data: data, encoding: .utf8) ?? payload.boardName
        sent.media = ChatMessageMediaPayload(
            thumbnailURL: payload.coverImageURL
        )
        return sent
    }

    func sendRatingEventCardMessage(
        conversationID: String,
        payload: RatingEventShareCardPayload
    ) async throws -> ChatMessage? {
        guard currentBootstrap?.enabled == true else {
            return nil
        }

        let manager = try requireReadyManager()
        let target = try await resolveConversationTarget(conversationID: conversationID, manager: manager)
        let envelope = TencentRatingEventCardEnvelope(
            businessID: Self.customCardBusinessID,
            version: 1,
            cardType: "rating_event",
            payload: payload
        )
        let data = try JSONEncoder().encode(envelope)
        guard let message = manager.createCustomMessage(data: data) else {
            throw ServiceError.message("Tencent IM create rating event card message failed")
        }
        message.needReadReceipt = shouldRequestReadReceipt(for: target)
        let offlinePushInfo = await buildCardOfflinePushInfo(
            manager: manager,
            target: target,
            previewText: "\(LT("[打分事件卡片]", "[Rating Event Card]", "[評価イベントカード]")) \(payload.eventName)"
        )
        var sent = try await sendMessage(
            manager: manager,
            message: message,
            target: target,
            offlinePushInfo: offlinePushInfo,
            progress: nil
        )
        sent.kind = .card
        sent.content = String(data: data, encoding: .utf8) ?? payload.eventName
        sent.media = ChatMessageMediaPayload(
            thumbnailURL: payload.coverImageURL
        )
        return sent
    }

    func sendRatingUnitCardMessage(
        conversationID: String,
        payload: RatingUnitShareCardPayload
    ) async throws -> ChatMessage? {
        guard currentBootstrap?.enabled == true else {
            return nil
        }

        let manager = try requireReadyManager()
        let target = try await resolveConversationTarget(conversationID: conversationID, manager: manager)
        let envelope = TencentRatingUnitCardEnvelope(
            businessID: Self.customCardBusinessID,
            version: 1,
            cardType: "rating_unit",
            payload: payload
        )
        let data = try JSONEncoder().encode(envelope)
        guard let message = manager.createCustomMessage(data: data) else {
            throw ServiceError.message("Tencent IM create rating unit card message failed")
        }
        message.needReadReceipt = shouldRequestReadReceipt(for: target)
        let offlinePushInfo = await buildCardOfflinePushInfo(
            manager: manager,
            target: target,
            previewText: "\(LT("[打分单位卡片]", "[Rating Unit Card]", "[評価ユニットカード]")) \(payload.unitName)"
        )
        var sent = try await sendMessage(
            manager: manager,
            message: message,
            target: target,
            offlinePushInfo: offlinePushInfo,
            progress: nil
        )
        sent.kind = .card
        sent.content = String(data: data, encoding: .utf8) ?? payload.unitName
        sent.media = ChatMessageMediaPayload(
            thumbnailURL: payload.coverImageURL
        )
        return sent
    }

    func sendPostCardMessage(
        conversationID: String,
        payload: PostShareCardPayload
    ) async throws -> ChatMessage? {
        guard currentBootstrap?.enabled == true else {
            return nil
        }

        let manager = try requireReadyManager()
        let target = try await resolveConversationTarget(conversationID: conversationID, manager: manager)
        let envelope = TencentPostCardEnvelope(
            businessID: Self.customCardBusinessID,
            version: 1,
            cardType: "post",
            payload: payload
        )
        let data = try JSONEncoder().encode(envelope)
        guard let message = manager.createCustomMessage(data: data) else {
            throw ServiceError.message("Tencent IM create post card message failed")
        }
        message.needReadReceipt = shouldRequestReadReceipt(for: target)
        let offlinePushInfo = await buildCardOfflinePushInfo(
            manager: manager,
            target: target,
            previewText: "\(LT("[帖子卡片]", "[Post Card]", "[投稿カード]")) \(payload.authorDisplayName)"
        )
        var sent = try await sendMessage(
            manager: manager,
            message: message,
            target: target,
            offlinePushInfo: offlinePushInfo,
            progress: nil
        )
        sent.kind = .card
        sent.content = String(data: data, encoding: .utf8) ?? payload.contentText
        sent.media = ChatMessageMediaPayload(
            thumbnailURL: payload.coverImageURL
        )
        return sent
    }

    func sendCircleIDCardMessage(
        conversationID: String,
        payload: CircleIDShareCardPayload
    ) async throws -> ChatMessage? {
        guard currentBootstrap?.enabled == true else {
            return nil
        }

        let manager = try requireReadyManager()
        let target = try await resolveConversationTarget(conversationID: conversationID, manager: manager)
        let envelope = TencentCircleIDCardEnvelope(
            businessID: Self.customCardBusinessID,
            version: 1,
            cardType: "circle_id",
            payload: payload
        )
        let data = try JSONEncoder().encode(envelope)
        guard let message = manager.createCustomMessage(data: data) else {
            throw ServiceError.message("Tencent IM create ID card message failed")
        }
        message.needReadReceipt = shouldRequestReadReceipt(for: target)
        let offlinePushInfo = await buildCardOfflinePushInfo(
            manager: manager,
            target: target,
            previewText: "\(LT("[ID卡片]", "[ID Card]", "[IDカード]")) \(payload.songName)"
        )
        var sent = try await sendMessage(
            manager: manager,
            message: message,
            target: target,
            offlinePushInfo: offlinePushInfo,
            progress: nil
        )
        sent.kind = .card
        sent.content = String(data: data, encoding: .utf8) ?? payload.songName
        sent.media = ChatMessageMediaPayload(thumbnailURL: payload.coverImageURL)
        return sent
    }

    func sendMyCheckinsCardMessage(
        conversationID: String,
        payload: MyCheckinsShareCardPayload
    ) async throws -> ChatMessage? {
        guard currentBootstrap?.enabled == true else {
            return nil
        }

        let manager = try requireReadyManager()
        let target = try await resolveConversationTarget(conversationID: conversationID, manager: manager)
        let envelope = TencentMyCheckinsCardEnvelope(
            businessID: Self.customCardBusinessID,
            version: 1,
            cardType: "my_checkins",
            payload: payload
        )
        let data = try JSONEncoder().encode(envelope)
        guard let message = manager.createCustomMessage(data: data) else {
            throw ServiceError.message("Tencent IM create my check-ins card message failed")
        }
        message.needReadReceipt = shouldRequestReadReceipt(for: target)
        let offlinePushInfo = await buildCardOfflinePushInfo(
            manager: manager,
            target: target,
            previewText: "\(LT("[打卡卡片]", "[Check-ins Card]", "[チェックインカード]")) \(payload.title)"
        )
        var sent = try await sendMessage(
            manager: manager,
            message: message,
            target: target,
            offlinePushInfo: offlinePushInfo,
            progress: nil
        )
        sent.kind = .card
        sent.content = String(data: data, encoding: .utf8) ?? payload.title
        sent.media = ChatMessageMediaPayload(thumbnailURL: payload.coverImageURL)
        return sent
    }

    func sendEventRouteCardMessage(
        conversationID: String,
        payload: EventRouteShareCardPayload
    ) async throws -> ChatMessage? {
        guard currentBootstrap?.enabled == true else {
            return nil
        }

        let manager = try requireReadyManager()
        let target = try await resolveConversationTarget(conversationID: conversationID, manager: manager)
        let envelope = TencentEventRouteCardEnvelope(
            businessID: Self.customCardBusinessID,
            version: 1,
            cardType: "event_route",
            payload: payload
        )
        let data = try JSONEncoder().encode(envelope)
        guard let message = manager.createCustomMessage(data: data) else {
            throw ServiceError.message("Tencent IM create event route card message failed")
        }
        message.needReadReceipt = shouldRequestReadReceipt(for: target)
        let offlinePushInfo = await buildCardOfflinePushInfo(
            manager: manager,
            target: target,
            previewText: "\(LT("[路线卡片]", "[Route Card]", "[ルートカード]")) \(payload.title)"
        )
        var sent = try await sendMessage(
            manager: manager,
            message: message,
            target: target,
            offlinePushInfo: offlinePushInfo,
            progress: nil
        )
        sent.kind = .card
        sent.content = String(data: data, encoding: .utf8) ?? payload.title
        sent.media = ChatMessageMediaPayload(thumbnailURL: payload.coverImageURL)
        return sent
    }

    func sendImageMessage(
        conversationID: String,
        fileURL: URL,
        onProgress: ((Int) -> Void)?
    ) async throws -> ChatMessage? {
        guard currentBootstrap?.enabled == true else {
            return nil
        }

        let manager = try requireReadyManager()
        let target = try await resolveConversationTarget(conversationID: conversationID, manager: manager)
        guard let message = manager.createImageMessage(imagePath: fileURL.path) else {
            throw ServiceError.message("Tencent IM create image message failed")
        }
        message.needReadReceipt = shouldRequestReadReceipt(for: target)
        return try await sendMessage(
            manager: manager,
            message: message,
            target: target,
            progress: onProgress
        )
    }

    func sendVideoMessage(
        conversationID: String,
        fileURL: URL,
        onProgress: ((Int) -> Void)?
    ) async throws -> ChatMessage? {
        guard currentBootstrap?.enabled == true else {
            return nil
        }

        let manager = try requireReadyManager()
        let target = try await resolveConversationTarget(conversationID: conversationID, manager: manager)
        let snapshotURL = try makeVideoSnapshotURL(for: fileURL)
        guard let message = manager.createVideoMessage(
            videoFilePath: fileURL.path,
            type: fileURL.pathExtension.isEmpty ? "mp4" : fileURL.pathExtension,
            duration: 0,
            snapshotPath: snapshotURL.path
        ) else {
            throw ServiceError.message("Tencent IM create video message failed")
        }
        message.needReadReceipt = shouldRequestReadReceipt(for: target)
        return try await sendMessage(
            manager: manager,
            message: message,
            target: target,
            progress: onProgress
        )
    }

    func sendVoiceMessage(
        conversationID: String,
        fileURL: URL
    ) async throws -> ChatMessage? {
        guard currentBootstrap?.enabled == true else {
            return nil
        }

        let manager = try requireReadyManager()
        let target = try await resolveConversationTarget(conversationID: conversationID, manager: manager)
        let duration = try audioDurationSeconds(for: fileURL)
        guard let message = manager.createSoundMessage(audioFilePath: fileURL.path, duration: duration) else {
            throw ServiceError.message("Tencent IM create voice message failed")
        }
        message.needReadReceipt = shouldRequestReadReceipt(for: target)
        return try await sendMessage(
            manager: manager,
            message: message,
            target: target,
            progress: nil
        )
    }

    func sendFileMessage(
        conversationID: String,
        fileURL: URL
    ) async throws -> ChatMessage? {
        guard currentBootstrap?.enabled == true else {
            return nil
        }

        let manager = try requireReadyManager()
        let target = try await resolveConversationTarget(conversationID: conversationID, manager: manager)
        let fileName = fileURL.lastPathComponent.trimmingCharacters(in: .whitespacesAndNewlines)
        let audioDuration = audioFileDurationSecondsIfSupported(for: fileURL)
        let fileSizeBytes = fileSizeInBytes(for: fileURL)
        guard let message = manager.createFileMessage(
            filePath: fileURL.path,
            fileName: fileName.isEmpty ? fileURL.lastPathComponent : fileName
        ) else {
            throw ServiceError.message("Tencent IM create file message failed")
        }
        message.needReadReceipt = shouldRequestReadReceipt(for: target)
        var sentMessage = try await sendMessage(
            manager: manager,
            message: message,
            target: target,
            progress: nil
        )
        if audioDuration != nil || fileSizeBytes != nil {
            var media = sentMessage.media ?? ChatMessageMediaPayload()
            if media.mediaURL?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true {
                media.mediaURL = fileURL.path
            }
            if media.fileName?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true {
                media.fileName = fileName.isEmpty ? fileURL.lastPathComponent : fileName
            }
            if media.fileSizeBytes == nil {
                media.fileSizeBytes = fileSizeBytes
            }
            if media.durationSeconds == nil {
                media.durationSeconds = audioDuration
            }
            sentMessage.media = media
        }
        return sentMessage
    }

    func sendTypingStatus(
        conversationID: String,
        isTyping: Bool
    ) async throws -> Bool {
        guard currentBootstrap?.enabled == true else {
            return false
        }

        let manager = try requireReadyManager()
        let target = try await resolveConversationTarget(conversationID: conversationID, manager: manager)
        guard target.type == .direct else {
            return false
        }

        let payload: [String: Any] = [
            "businessID": Self.typingBusinessID,
            "typingStatus": isTyping ? 1 : 0,
            "version": 1,
            "userAction": 14,
            "actionParam": isTyping ? "EIMAMSG_InputStatus_Ing" : "EIMAMSG_InputStatus_End"
        ]
        let data = try JSONSerialization.data(withJSONObject: payload, options: [])
        guard let message = manager.createCustomMessage(data: data) else {
            throw ServiceError.message("Tencent IM create typing message failed")
        }

        guard let priority = V2TIMMessagePriority(rawValue: 2) else {
            throw ServiceError.message("Tencent IM message priority unavailable")
        }

        try await withCheckedThrowingContinuation { continuation in
            _ = manager.sendMessage(
                message: message,
                receiver: target.userID,
                groupID: target.groupID,
                priority: priority,
                onlineUserOnly: true,
                offlinePushInfo: nil,
                progress: nil,
                succ: {
                    continuation.resume()
                },
                fail: { code, desc in
                    continuation.resume(
                        throwing: self.buildTencentIMError(
                            code: code,
                            desc: desc,
                            fallback: "Send Tencent IM typing status failed"
                        )
                    )
                }
            )
        }

        return true
    }

    func revokeMessage(
        conversationID: String,
        messageID: String
    ) async throws -> String? {
        guard currentBootstrap?.enabled == true else {
            return nil
        }

        let manager = try requireReadyManager()
        let target = try await resolveConversationTarget(conversationID: conversationID, manager: manager)
        let message = try await findMessage(
            manager: manager,
            messageID: messageID,
            conversationID: target.businessConversationID
        )
        let displayText = revokeDisplayText(for: message, operateUser: nil)

        try await withCheckedThrowingContinuation { continuation in
            manager.revokeMessage(msg: message) {
                continuation.resume()
            } fail: { code, desc in
                continuation.resume(
                    throwing: self.buildTencentIMError(
                        code: code,
                        desc: desc,
                        fallback: "Revoke Tencent IM message failed"
                    )
                )
            }
        }

        return displayText
    }

    func deleteMessage(
        conversationID: String,
        messageID: String
    ) async throws -> Bool {
        guard currentBootstrap?.enabled == true else {
            return false
        }

        let manager = try requireReadyManager()
        let target = try await resolveConversationTarget(conversationID: conversationID, manager: manager)
        let message = try await findMessage(
            manager: manager,
            messageID: messageID,
            conversationID: target.businessConversationID
        )

        try await withCheckedThrowingContinuation { continuation in
            manager.deleteMessages(msgList: [message]) {
                continuation.resume()
            } fail: { code, desc in
                continuation.resume(
                    throwing: self.buildTencentIMError(
                        code: code,
                        desc: desc,
                        fallback: "Delete Tencent IM message failed"
                    )
                )
            }
        }

        return true
    }

    func fetchTotalUnreadCount() async -> Int? {
        guard currentBootstrap?.enabled == true, hasInitializedSDK else {
            return nil
        }

        guard let manager = V2TIMManager.sharedInstance(),
              manager.getLoginStatus().rawValue == Self.loggedInStatusRawValue else {
            return nil
        }

        return await requestTotalUnreadCount(manager: manager)
    }

    private func login(manager: V2TIMManager, userID: String, userSig: String) async throws {
        try await withCheckedThrowingContinuation { continuation in
            manager.login(userID: userID, userSig: userSig) {
                continuation.resume()
            } fail: { code, desc in
                let message = desc?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                let resolved = message.isEmpty ? "Tencent IM login failed (\(code))" : message
                continuation.resume(throwing: ServiceError.message(resolved))
            }
        }
    }

    private func logout(manager: V2TIMManager) async throws {
        try await withCheckedThrowingContinuation { continuation in
            manager.logout {
                continuation.resume()
            } fail: { code, desc in
                let message = desc?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                let resolved = message.isEmpty ? "Tencent IM logout failed (\(code))" : message
                continuation.resume(throwing: ServiceError.message(resolved))
            }
        }
    }

    private func refreshTotalUnreadCount() async {
        guard let manager = V2TIMManager.sharedInstance() else {
            unreadCount = 0
            return
        }
        unreadCount = await requestTotalUnreadCount(manager: manager) ?? 0
    }

    private func requestTotalUnreadCount(manager: V2TIMManager) async -> Int? {
        await withCheckedContinuation { continuation in
            manager.getTotalUnreadMessageCount { totalUnreadCount in
                continuation.resume(returning: Int(totalUnreadCount))
            } fail: { _, _ in
                continuation.resume(returning: nil)
            }
        }
    }

    private struct TencentConversationTarget {
        let businessConversationID: String
        let rawConversationID: String
        let type: ConversationType
        let userID: String?
        let groupID: String?
    }

    private struct TencentConversationPage {
        let list: [V2TIMConversation]
        let nextSeq: UInt64
        let isFinished: Bool
    }

    private func requireReadyManager() throws -> V2TIMManager {
        guard let manager = V2TIMManager.sharedInstance(), hasInitializedSDK else {
            throw ServiceError.message("Tencent IM SDK not initialized")
        }

        guard manager.getLoginStatus().rawValue == Self.loggedInStatusRawValue else {
            throw ServiceError.message("Tencent IM not connected")
        }

        return manager
    }

    private func applyAPNSConfigurationIfPossible(reason: String) async {
#if canImport(ImSDK_Plus)
        guard currentBootstrap?.enabled == true else {
            debugAPNS("skip apply reason=\(reason): bootstrap disabled")
            return
        }
        guard AppConfig.tencentIMAPNSBusinessID > 0 else {
            debugAPNS("skip apply reason=\(reason): missing TencentIMAPNSBusinessID")
            return
        }
        guard let token = latestAPNSTokenData, !token.isEmpty else {
            debugAPNS("skip apply reason=\(reason): missing APNs token")
            return
        }
        guard let manager = V2TIMManager.sharedInstance(), hasInitializedSDK else {
            debugAPNS("skip apply reason=\(reason): SDK not initialized")
            return
        }
        guard manager.getLoginStatus().rawValue == Self.loggedInStatusRawValue else {
            debugAPNS("skip apply reason=\(reason): IM not logged in")
            return
        }

        manager.setAPNSListener(apnsListener: TencentIMAPNSBadgeBridge.shared)
        let config = V2TIMAPNSConfig()
        config.token = token
        config.businessID = Int32(AppConfig.tencentIMAPNSBusinessID)

        await withCheckedContinuation { continuation in
            manager.setAPNS(config: config) { [weak self] in
                self?.debugAPNS("config applied reason=\(reason) businessID=\(AppConfig.tencentIMAPNSBusinessID)")
                continuation.resume()
            } fail: { [weak self] code, desc in
                let message = desc?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                let resolved = message.isEmpty ? "Tencent APNS config failed (\(code))" : message
                self?.debugAPNS("config failed reason=\(reason): \(resolved)")
                continuation.resume()
            }
        }
#else
        _ = reason
#endif
    }

    private static func decodeHexAPNSToken(_ hexToken: String) -> Data? {
        let normalized = hexToken.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty, normalized.count.isMultiple(of: 2) else { return nil }

        var data = Data(capacity: normalized.count / 2)
        var index = normalized.startIndex
        while index < normalized.endIndex {
            let next = normalized.index(index, offsetBy: 2)
            guard let byte = UInt8(normalized[index..<next], radix: 16) else { return nil }
            data.append(byte)
            index = next
        }
        return data
    }

    private func debugAPNS(_ message: String) {
#if DEBUG
        print("[TencentIMAPNS] \(message)")
#endif
    }

    private func shouldRequestReadReceipt(for target: TencentConversationTarget) -> Bool {
        false
    }

    private func fetchAllConversations(manager: V2TIMManager) async throws -> [V2TIMConversation] {
        var nextSeq: UInt64 = 0
        var merged: [V2TIMConversation] = []
        var isFinished = false

        repeat {
            let page = try await fetchConversationPage(
                manager: manager,
                nextSeq: nextSeq,
                count: 100
            )
            merged.append(contentsOf: page.list)
            nextSeq = page.nextSeq
            isFinished = page.isFinished
        } while !isFinished

        return merged
    }

    private func fetchConversationPage(
        manager: V2TIMManager,
        nextSeq: UInt64,
        count: Int
    ) async throws -> TencentConversationPage {
        try await withCheckedThrowingContinuation { continuation in
            manager.getConversationList(nextSeq: nextSeq, count: Int32(max(1, count))) { list, nextSeq, isFinished in
                continuation.resume(
                    returning: TencentConversationPage(
                        list: list ?? [],
                        nextSeq: nextSeq,
                        isFinished: isFinished
                    )
                )
            } fail: { code, desc in
                continuation.resume(
                    throwing: self.buildTencentIMError(
                        code: code,
                        desc: desc,
                        fallback: "Fetch Tencent IM conversations failed"
                    )
                )
            }
        }
    }

    private func fetchGroupInfo(groupID: String, manager: V2TIMManager) async throws -> V2TIMGroupInfo {
        let results: [V2TIMGroupInfoResult] = try await withCheckedThrowingContinuation { continuation in
            manager.getGroupsInfo([groupID]) { resultList in
                continuation.resume(returning: resultList ?? [])
            } fail: { code, desc in
                continuation.resume(
                    throwing: self.buildTencentIMError(
                        code: code,
                        desc: desc,
                        fallback: "Fetch Tencent IM group info failed"
                    )
                )
            }
        }

        guard let info = results.first?.info else {
            throw ServiceError.message("Tencent IM group info unavailable")
        }
        return info
    }

    private func mapSquadMemberProfile(from info: V2TIMGroupMemberFullInfo) -> SquadMemberProfile {
        let rawTencentUserID = normalizedText(info.userID) ?? ""
        let platformUserID = TencentIMIdentity.normalizePlatformUserIDForProfile(rawTencentUserID)
        let resolvedDisplayName = normalizedText(info.nameCard)
            ?? normalizedText(info.friendRemark)
            ?? normalizedText(info.nickName)
            ?? (platformUserID.isEmpty ? rawTencentUserID : platformUserID)
        let role = mapSquadMemberRole(rawValue: info.role)

        return SquadMemberProfile(
            id: platformUserID.isEmpty ? rawTencentUserID : platformUserID,
            username: platformUserID.isEmpty ? rawTencentUserID : platformUserID,
            displayName: resolvedDisplayName,
            avatarURL: normalizedText(info.faceURL),
            isFollowing: false,
            role: role,
            nickname: normalizedText(info.nameCard),
            isCaptain: role == "leader",
            isAdmin: role == "admin"
        )
    }

    private func mapSquadMemberRole(rawValue: UInt32) -> String {
        switch rawValue {
        case UInt32(V2TIMGroupMemberRole.GROUP_MEMBER_ROLE_SUPER.rawValue):
            return "leader"
        case UInt32(V2TIMGroupMemberRole.GROUP_MEMBER_ROLE_ADMIN.rawValue):
            return "admin"
        default:
            return "member"
        }
    }

    private func isTencentPublicGroupType(_ rawType: String?) -> Bool {
        let normalized = rawType?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
        return normalized != "work"
    }

    private func isGroupNotificationsEnabled(_ opt: V2TIMReceiveMessageOpt) -> Bool {
        opt.rawValue == Self.receiveMessageOptRawValue
    }

    private func resolveConversationTarget(
        conversationID: String,
        manager: V2TIMManager
    ) async throws -> TencentConversationTarget {
        let trimmed = conversationID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw ServiceError.message("Conversation ID is empty")
        }

        if trimmed.hasPrefix("c2c_") {
            let userID = String(trimmed.dropFirst(4))
            return TencentConversationTarget(
                businessConversationID: userID,
                rawConversationID: trimmed,
                type: .direct,
                userID: userID,
                groupID: nil
            )
        }

        if trimmed.hasPrefix("tu_") {
            return TencentConversationTarget(
                businessConversationID: trimmed,
                rawConversationID: "c2c_\(trimmed)",
                type: .direct,
                userID: trimmed,
                groupID: nil
            )
        }

        if trimmed.hasPrefix("group_") {
            let groupID = String(trimmed.dropFirst(6))
            return TencentConversationTarget(
                businessConversationID: groupID,
                rawConversationID: trimmed,
                type: .group,
                userID: nil,
                groupID: groupID
            )
        }

        let conversations = try await fetchAllConversations(manager: manager)
        for item in conversations {
            guard let mapped = mapConversation(item) else { continue }
            if mapped.id == trimmed || mapped.sdkConversationID == trimmed {
                return TencentConversationTarget(
                    businessConversationID: mapped.id,
                    rawConversationID: mapped.sdkConversationID ?? mapped.id,
                    type: mapped.type,
                    userID: mapped.type == .direct ? mapped.id : nil,
                    groupID: mapped.type == .group ? mapped.id : nil
                )
            }
        }

        throw ServiceError.message("Tencent IM conversation not found")
    }

    private func fetchHistoryMessages(
        manager: V2TIMManager,
        target: TencentConversationTarget,
        count: Int,
        lastMessage: V2TIMMessage?
    ) async throws -> [V2TIMMessage] {
        try await withCheckedThrowingContinuation { continuation in
            let success: V2TIMMessageListSucc = { messages in
                continuation.resume(returning: messages ?? [])
            }
            let failure: V2TIMFail = { code, desc in
                continuation.resume(
                    throwing: self.buildTencentIMError(
                        code: code,
                        desc: desc,
                        fallback: "Fetch Tencent IM history messages failed"
                    )
                )
            }

            switch target.type {
            case .direct:
                guard let userID = target.userID else {
                    continuation.resume(throwing: ServiceError.message("Tencent IM direct conversation missing userID"))
                    return
                }
                manager.getC2CHistoryMessageList(
                    userID: userID,
                    count: Int32(max(1, count)),
                    lastMsg: lastMessage,
                    succ: success,
                    fail: failure
                )
            case .group:
                guard let groupID = target.groupID else {
                    continuation.resume(throwing: ServiceError.message("Tencent IM group conversation missing groupID"))
                    return
                }
                manager.getGroupHistoryMessageList(
                    groupID: groupID,
                    count: Int32(max(1, count)),
                    lastMsg: lastMessage,
                    succ: success,
                    fail: failure
                )
            }
        }
    }

    private func searchLocalMessages(
        manager: V2TIMManager,
        target: TencentConversationTarget,
        query: String,
        limit: Int
    ) async throws -> [V2TIMMessage] {
        try await withCheckedThrowingContinuation { continuation in
            let searchParam = V2TIMMessageSearchParam()
            searchParam.keywordList = [query]
            searchParam.messageTypeList = nil
            searchParam.conversationID = target.rawConversationID
            searchParam.searchTimePosition = 0
            searchParam.searchTimePeriod = 0
            searchParam.pageIndex = 0
            searchParam.pageSize = UInt(max(1, limit))

            manager.searchLocalMessages(param: searchParam) { searchResult in
                guard let searchResult else {
                    continuation.resume(returning: [])
                    return
                }

                let items = searchResult.messageSearchResultItems ?? []
                let flattened = items.flatMap { $0.messageList ?? [] }
                continuation.resume(returning: flattened)
            } fail: { code, desc in
                continuation.resume(
                    throwing: self.buildTencentIMError(
                        code: code,
                        desc: desc,
                        fallback: "Search Tencent IM local messages failed"
                    )
                )
            }
        }
    }

    private func resolveHistoryAnchorMessage(
        manager: V2TIMManager,
        target: TencentConversationTarget,
        startClientMsgID: String?
    ) async throws -> V2TIMMessage? {
        guard let startClientMsgID = normalizedText(startClientMsgID) else {
            return nil
        }

        let messages = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[V2TIMMessage], Error>) in
            manager.findMessages(messageIDList: [startClientMsgID], succ: { messages in
                continuation.resume(returning: messages ?? [])
            }, fail: { code, desc in
                continuation.resume(
                    throwing: self.buildTencentIMError(
                        code: code,
                        desc: desc,
                        fallback: "Resolve Tencent IM history anchor failed"
                    )
                )
            })
        }

        return messages.first(where: { [weak self] message in
            guard let self else { return false }
            return self.resolveBusinessConversationID(for: message) == target.businessConversationID
        }) ?? messages.first
    }

    private func findMessage(
        manager: V2TIMManager,
        messageID: String,
        conversationID: String? = nil
    ) async throws -> V2TIMMessage {
        let trimmedMessageID = messageID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedMessageID.isEmpty else {
            throw ServiceError.message("Tencent IM message ID is empty")
        }

        let messages = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[V2TIMMessage], Error>) in
            manager.findMessages(messageIDList: [trimmedMessageID], succ: { messages in
                continuation.resume(returning: messages ?? [])
            }, fail: { code, desc in
                continuation.resume(
                    throwing: self.buildTencentIMError(
                        code: code,
                        desc: desc,
                        fallback: "Find Tencent IM message failed"
                    )
                )
            })
        }

        if let conversationID,
           let matched = messages.first(where: { [weak self] message in
               guard let self else { return false }
               return self.resolveBusinessConversationID(for: message) == conversationID
           }) {
            return matched
        }

        if let first = messages.first {
            return first
        }

        throw ServiceError.message("Tencent IM message not found")
    }

    private func sendMessage(
        manager: V2TIMManager,
        message: V2TIMMessage,
        target: TencentConversationTarget,
        offlinePushInfo: V2TIMOfflinePushInfo? = nil,
        progress: ((Int) -> Void)?
    ) async throws -> ChatMessage {
        guard let priority = V2TIMMessagePriority(rawValue: 2) else {
            throw ServiceError.message("Tencent IM message priority unavailable")
        }

        let sentMessage = try await withCheckedThrowingContinuation { continuation in
            _ = manager.sendMessage(
                message: message,
                receiver: target.userID,
                groupID: target.groupID,
                priority: priority,
                onlineUserOnly: false,
                offlinePushInfo: offlinePushInfo,
                progress: { percent in
                    progress?(Int(percent))
                },
                succ: {
                    continuation.resume(returning: message)
                },
                fail: { code, desc in
                    continuation.resume(
                        throwing: self.buildTencentIMError(
                            code: code,
                            desc: desc,
                            fallback: "Send Tencent IM message failed"
                        )
                    )
                }
            )
        }

        await refreshTotalUnreadCount()
        return await mapMessage(sentMessage, conversationID: target.businessConversationID)
    }

    private func buildTextOfflinePushInfo(
        manager: V2TIMManager,
        target: TencentConversationTarget,
        content: String,
        mentionedUserIDs: [String]
    ) async -> V2TIMOfflinePushInfo? {
        let trimmedContent = normalizedPushText(content)
        guard !trimmedContent.isEmpty else { return nil }

        let conversation = await fetchConversationIfPossible(
            manager: manager,
            conversationID: target.rawConversationID
        )
        let conversationTitle = normalizedText(conversation?.showName)
        let receiveOpt = conversation?.recvOpt.rawValue

        let info = V2TIMOfflinePushInfo()
        switch target.type {
        case .direct:
            info.title = conversationTitle ?? target.businessConversationID
            info.desc = trimmedContent
        case .group:
            let senderName = await resolveCurrentUserPushDisplayName(manager: manager)
                ?? currentUserID
                ?? LT("成员", "Member", "メンバー")
            info.title = conversationTitle ?? target.businessConversationID
            info.desc = "\(senderName): \(trimmedContent)"
        }

        info.disablePush = false
        info.ignoreIOSBadge = true
        info.iOSSound = "default"
        info.ext = buildPushRoutingExt(
            target: target,
            conversationTitle: conversationTitle,
            previewText: trimmedContent,
            receiveOpt: receiveOpt,
            mentionedUserIDs: mentionedUserIDs
        )
        return info
    }

    private func buildCardOfflinePushInfo(
        manager: V2TIMManager,
        target: TencentConversationTarget,
        previewText: String
    ) async -> V2TIMOfflinePushInfo? {
        let normalizedPreview = normalizedPushText(previewText)
        guard !normalizedPreview.isEmpty else { return nil }

        let conversation = await fetchConversationIfPossible(
            manager: manager,
            conversationID: target.rawConversationID
        )
        let conversationTitle = normalizedText(conversation?.showName)
        let receiveOpt = conversation?.recvOpt.rawValue

        let info = V2TIMOfflinePushInfo()
        switch target.type {
        case .direct:
            info.title = conversationTitle ?? target.businessConversationID
            info.desc = normalizedPreview
        case .group:
            let senderName = await resolveCurrentUserPushDisplayName(manager: manager)
                ?? currentUserID
                ?? LT("成员", "Member", "メンバー")
            info.title = conversationTitle ?? target.businessConversationID
            info.desc = "\(senderName): \(normalizedPreview)"
        }

        info.disablePush = false
        info.ignoreIOSBadge = true
        info.iOSSound = "default"
        info.ext = buildPushRoutingExt(
            target: target,
            conversationTitle: conversationTitle,
            previewText: normalizedPreview,
            receiveOpt: receiveOpt,
            mentionedUserIDs: []
        )
        return info
    }

    private func fetchConversationIfPossible(
        manager: V2TIMManager,
        conversationID: String
    ) async -> V2TIMConversation? {
        await withCheckedContinuation { continuation in
            manager.getConversation(conversationID: conversationID) { conversation in
                continuation.resume(returning: conversation)
            } fail: { _, _ in
                continuation.resume(returning: nil)
            }
        }
    }

    private func fetchUserFullInfo(
        userID: String,
        manager: V2TIMManager
    ) async throws -> V2TIMUserFullInfo {
        try await withCheckedThrowingContinuation { continuation in
            manager.getUsersInfo([userID]) { infos in
                guard let info = infos?.first else {
                    continuation.resume(throwing: ServiceError.message("Tencent IM user info unavailable"))
                    return
                }
                continuation.resume(returning: info)
            } fail: { code, desc in
                continuation.resume(
                    throwing: self.buildTencentIMError(
                        code: code,
                        desc: desc,
                        fallback: "Fetch Tencent IM user info failed"
                    )
                )
            }
        }
    }

    private func resolveCurrentUserPushDisplayName(manager: V2TIMManager) async -> String? {
        guard let loginUserID = currentUserID, !loginUserID.isEmpty else { return nil }
        guard let info = try? await fetchUserFullInfo(userID: loginUserID, manager: manager) else { return nil }
        return normalizedText(info.nickName)
            ?? normalizedText(info.userID)
    }

    private func buildPushRoutingExt(
        target: TencentConversationTarget,
        conversationTitle: String?,
        previewText: String,
        receiveOpt: Int?,
        mentionedUserIDs: [String]
    ) -> String {
        let normalizedMentionedUserIDs = mentionedUserIDs
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let senderUserID = currentUserID?.trimmingCharacters(in: .whitespacesAndNewlines)
        let effectiveBusinessConversationID: String
        let effectiveSDKConversationID: String
        let effectivePeerID: String

        switch target.type {
        case .direct:
            let fallbackPeerID = target.userID ?? target.businessConversationID
            let routePeerID = senderUserID?.nilIfBlank ?? fallbackPeerID
            effectiveBusinessConversationID = routePeerID
            effectiveSDKConversationID = routePeerID.hasPrefix("c2c_") ? routePeerID : "c2c_\(routePeerID)"
            effectivePeerID = routePeerID
        case .group:
            effectiveBusinessConversationID = target.businessConversationID
            effectiveSDKConversationID = target.rawConversationID
            effectivePeerID = ""
        }

        let payload: [String: Any] = [
            "route": "chat",
            "conversationType": target.type.rawValue,
            "conversationID": effectiveBusinessConversationID,
            "sdkConversationID": effectiveSDKConversationID,
            "peerID": effectivePeerID,
            "groupID": target.groupID ?? "",
            "receiverUserID": target.userID ?? "",
            "senderUserID": senderUserID ?? "",
            "title": conversationTitle ?? "",
            "preview": previewText,
            "mentionedUserIDs": normalizedMentionedUserIDs,
            "mentionAll": normalizedMentionedUserIDs.contains("all"),
            "recvOpt": receiveOpt ?? Self.receiveMessageOptRawValue,
            "version": 1
        ]

        guard let data = try? JSONSerialization.data(withJSONObject: payload, options: []),
              let string = String(data: data, encoding: .utf8) else {
            return ""
        }
        return string
    }

    private func normalizedPushText(_ content: String) -> String {
        let collapsed = content
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        guard !collapsed.isEmpty else { return "" }
        let limit = 120
        if collapsed.count <= limit {
            return collapsed
        }
        let endIndex = collapsed.index(collapsed.startIndex, offsetBy: limit)
        return String(collapsed[..<endIndex]) + "…"
    }

    private func mentionAlertType(from groupAtInfoList: [V2TIMGroupAtInfo]?) -> GroupMentionAlertType {
        guard let groupAtInfoList, !groupAtInfoList.isEmpty else { return .none }
        var hasAtMe = false
        var hasAtAll = false
        for info in groupAtInfoList {
            switch info.atType {
            case .AT_ME:
                hasAtMe = true
            case .AT_ALL:
                hasAtAll = true
            case .AT_ALL_AT_ME:
                hasAtMe = true
                hasAtAll = true
            default:
                break
            }
        }
        switch (hasAtMe, hasAtAll) {
        case (true, true):
            return .atAllAndMe
        case (true, false):
            return .atMe
        case (false, true):
            return .atAll
        case (false, false):
            return .none
        }
    }

    private func mapConversation(_ item: V2TIMConversation) -> Conversation? {
        let rawType = item.type.rawValue
        let conversationType: ConversationType
        let businessID: String

        switch rawType {
        case Self.conversationTypeDirectRawValue:
            guard let userID = normalizedText(item.userID) else { return nil }
            conversationType = .direct
            businessID = userID
        case Self.conversationTypeGroupRawValue:
            guard let groupID = normalizedText(item.groupID) else { return nil }
            conversationType = .group
            businessID = groupID
        default:
            return nil
        }

        let title = normalizedText(item.showName) ?? businessID
        let avatarURL = normalizedText(item.faceUrl)
        let senderID = previewSenderLabel(for: item.lastMessage, conversationType: conversationType)
        let updatedAt = item.lastMessage?.timestamp ?? item.draftTimestamp ?? .distantPast
        let peer: UserSummary?
        if conversationType == .direct {
            peer = UserSummary(
                id: businessID,
                username: businessID,
                displayName: title,
                avatarURL: avatarURL,
                isFollowing: false
            )
        } else {
            peer = nil
        }

#if DEBUG
        print(
            """
            [IMProfile][ConversationMap] \
            type=\(conversationType == .direct ? "direct" : "group") \
            businessID=\(businessID) \
            showName=\(title) \
            faceUrl=\(avatarURL ?? "nil") \
            userID=\(normalizedText(item.userID) ?? "nil") \
            groupID=\(normalizedText(item.groupID) ?? "nil") \
            sdkConversationID=\(normalizedText(item.conversationID) ?? "nil")
            """
        )
#endif

        return Conversation(
            id: businessID,
            type: conversationType,
            title: title,
            avatarURL: avatarURL,
            sdkConversationID: normalizedText(item.conversationID),
            lastMessage: previewText(for: item.lastMessage),
            lastMessageSenderID: senderID,
            unreadCount: max(0, Int(item.unreadCount)),
            updatedAt: updatedAt,
            peer: peer,
            isPinned: item.isPinned,
            isMuted: item.recvOpt.rawValue == Self.receiveNoNotifyRawValue,
            unreadMentionType: mentionAlertType(from: item.groupAtInfolist)
        )
    }

    private func previewSenderLabel(
        for message: V2TIMMessage?,
        conversationType: ConversationType
    ) -> String? {
        guard let message else { return nil }

        let senderID = normalizedText(message.sender)
        let resolvedIsMine = senderID == currentUserID || message.isSelf
        if resolvedIsMine {
            return LT("我", "Me", "自分")
        }

        let displayName = normalizedText(message.friendRemark)
            ?? normalizedText(message.nameCard)
            ?? normalizedText(message.nickName)
        if let displayName {
            return displayName
        }

        // Direct chats should stay visually stable even when the SDK only returns a raw sender id.
        // Falling back to nil avoids "username: content" replacing an already-correct display name preview.
        if conversationType == .direct {
            return nil
        }

        return senderID
    }

    private func previewText(for message: V2TIMMessage?) -> String {
        guard let message else {
            return LT("暂无消息", "No messages yet", "メッセージはまだありません")
        }

        switch message.elemType.rawValue {
        case Self.elemTypeTextRawValue:
            return normalizedText(message.textElem?.text) ?? ""
        case Self.elemTypeImageRawValue:
            return LT("[图片]", "[Image]", "[画像]")
        case Self.elemTypeSoundRawValue:
            return LT("[语音]", "[Voice]", "[音声]")
        case Self.elemTypeVideoRawValue:
            return LT("[视频]", "[Video]", "[動画]")
        case Self.elemTypeFileRawValue:
            return normalizedText(message.fileElem?.filename) ?? LT("[文件]", "[File]", "[ファイル]")
        case Self.elemTypeLocationRawValue:
            return normalizedText(message.locationElem?.desc) ?? LT("[位置]", "[Location]", "[位置情報]")
        case Self.elemTypeFaceRawValue:
            return LT("[表情]", "[Sticker]", "[スタンプ]")
        case Self.elemTypeCustomRawValue:
            if let typingStatus = typingStatusPayload(from: message.customElem?.data) {
                return typingStatus == 1
                    ? LT("正在输入...", "Typing...", "入力中...")
                    : LT("停止输入", "Typing ended", "入力を停止しました")
            }
            if let friendTip = friendCreatedTipPayload(from: message.customElem?.data) {
                return friendTip
            }
            if let eventCard = customEventCardPayload(from: message.customElem?.data) {
                return "\(LT("[活动卡片]", "[Event Card]", "[イベントカード]")) \(eventCard.eventName)"
            }
            if let djCard = customDJCardPayload(from: message.customElem?.data) {
                return "\(LT("[DJ卡片]", "[DJ Card]", "[DJカード]")) \(djCard.djName)"
            }
            if let setCard = customSetCardPayload(from: message.customElem?.data) {
                return "\(LT("[Set卡片]", "[Set Card]", "[Setカード]")) \(setCard.setTitle)"
            }
            if let brandCard = customBrandCardPayload(from: message.customElem?.data) {
                return "\(LT("[音乐节卡片]", "[Festival Card]", "[フェスカード]")) \(brandCard.brandName)"
            }
            if let labelCard = customLabelCardPayload(from: message.customElem?.data) {
                return "\(LT("[厂牌卡片]", "[Label Card]", "[レーベルカード]")) \(labelCard.labelName)"
            }
            if let newsCard = customNewsCardPayload(from: message.customElem?.data) {
                return "\(LT("[资讯卡片]", "[News Card]", "[ニュースカード]")) \(newsCard.headline)"
            }
            if let rankingCard = customRankingBoardCardPayload(from: message.customElem?.data) {
                return "\(LT("[榜单卡片]", "[Ranking Card]", "[ランキングカード]")) \(rankingCard.boardName) · \(rankingCard.year)"
            }
            if let ratingEventCard = customRatingEventCardPayload(from: message.customElem?.data) {
                return "\(LT("[打分事件卡片]", "[Rating Event Card]", "[評価イベントカード]")) \(ratingEventCard.eventName)"
            }
            if let ratingUnitCard = customRatingUnitCardPayload(from: message.customElem?.data) {
                return "\(LT("[打分单位卡片]", "[Rating Unit Card]", "[評価ユニットカード]")) \(ratingUnitCard.unitName)"
            }
            if let postCard = customPostCardPayload(from: message.customElem?.data) {
                return "\(LT("[帖子卡片]", "[Post Card]", "[投稿カード]")) \(postCard.authorDisplayName)"
            }
            if let idCard = customCircleIDCardPayload(from: message.customElem?.data) {
                return "\(LT("[ID卡片]", "[ID Card]", "[IDカード]")) \(idCard.songName)"
            }
            if let myCheckinsCard = customMyCheckinsCardPayload(from: message.customElem?.data) {
                return "\(LT("[打卡卡片]", "[Check-ins Card]", "[チェックインカード]")) \(myCheckinsCard.title)"
            }
            if let eventRouteCard = customEventRouteCardPayload(from: message.customElem?.data) {
                return "\(LT("[路线卡片]", "[Route Card]", "[ルートカード]")) \(eventRouteCard.title)"
            }
            return normalizedText(message.customElem?.desc) ?? LT("[自定义消息]", "[Custom Message]", "[カスタムメッセージ]")
        case Self.elemTypeGroupTipsRawValue:
            return LT("[群提示]", "[Group Notice]", "[グループ通知]")
        case Self.elemTypeMergerRawValue:
            return LT("[聊天记录]", "[Merged Messages]", "[チャット履歴]")
        case Self.elemTypeStreamRawValue:
            return LT("[流式消息]", "[Stream Message]", "[ストリームメッセージ]")
        default:
            return LT("[消息]", "[Message]", "[メッセージ]")
        }
    }

    private func mapMessage(_ message: V2TIMMessage, conversationID: String) async -> ChatMessage {
        let senderID = normalizedText(message.sender) ?? "unknown"
        let senderDisplayName = normalizedText(message.friendRemark)
            ?? normalizedText(message.nameCard)
            ?? normalizedText(message.nickName)
            ?? senderID
        let resolvedIsMine = (currentUserID == senderID) || message.isSelf
        let sender = UserSummary(
            id: senderID,
            username: senderID,
            displayName: senderDisplayName,
            avatarURL: normalizedText(message.faceURL),
            isFollowing: false
        )

        if message.status.rawValue == Self.messageStatusLocalRevokedRawValue {
            return ChatMessage(
                id: normalizedText(message.msgID) ?? fallbackMessageID(for: message, conversationID: conversationID),
                conversationID: conversationID,
                sender: sender,
                content: revokeDisplayText(for: message, operateUser: nil),
                createdAt: message.timestamp ?? Date(),
                isMine: resolvedIsMine,
                kind: .system,
                media: nil,
                deliveryStatus: .sent,
                deliveryError: nil,
                peerRead: nil,
                readReceiptReadCount: nil,
                readReceiptUnreadCount: nil
            )
        }

        var kind: ChatMessageKind = .unknown
        var content = previewText(for: message)
        var media: ChatMessageMediaPayload?

        switch message.elemType.rawValue {
        case Self.elemTypeTextRawValue:
            kind = .text
            content = normalizedText(message.textElem?.text) ?? ""
        case Self.elemTypeImageRawValue:
            kind = .image
            content = LT("[图片]", "[Image]", "[画像]")
            media = mapImagePayload(from: message.imageElem)
        case Self.elemTypeSoundRawValue:
            kind = .voice
            content = LT("[语音]", "[Voice]", "[音声]")
            media = await mapSoundPayload(from: message.soundElem)
        case Self.elemTypeVideoRawValue:
            kind = .video
            content = LT("[视频]", "[Video]", "[動画]")
            media = await mapVideoPayload(from: message.videoElem)
        case Self.elemTypeFileRawValue:
            kind = .file
            content = normalizedText(message.fileElem?.filename) ?? LT("[文件]", "[File]", "[ファイル]")
            media = await mapFilePayload(from: message.fileElem)
        case Self.elemTypeLocationRawValue:
            kind = .location
            content = normalizedText(message.locationElem?.desc) ?? LT("[位置]", "[Location]", "[位置情報]")
        case Self.elemTypeFaceRawValue:
            kind = .emoji
            content = LT("[表情]", "[Sticker]", "[スタンプ]")
        case Self.elemTypeCustomRawValue:
            if let typingStatus = typingStatusPayload(from: message.customElem?.data) {
                kind = .typing
                content = typingStatus == 1
                    ? LT("正在输入...", "Typing...", "入力中...")
                    : LT("停止输入", "Typing ended", "入力を停止しました")
            } else if let friendTip = friendCreatedTipPayload(from: message.customElem?.data) {
                kind = .system
                content = friendTip
            } else if let eventCard = customEventCardPayload(from: message.customElem?.data) {
                kind = .card
                content = (try? String(data: JSONEncoder().encode(eventCard), encoding: .utf8))
                    ?? eventCard.eventName
                media = ChatMessageMediaPayload(
                    thumbnailURL: eventCard.coverImageURL
                )
            } else if let djCard = customDJCardPayload(from: message.customElem?.data) {
                kind = .card
                content = (try? String(data: JSONEncoder().encode(djCard), encoding: .utf8))
                    ?? djCard.djName
                media = ChatMessageMediaPayload(
                    thumbnailURL: djCard.coverImageURL
                )
            } else if let setCard = customSetCardPayload(from: message.customElem?.data) {
                kind = .card
                content = (try? String(data: JSONEncoder().encode(setCard), encoding: .utf8))
                    ?? setCard.setTitle
                media = ChatMessageMediaPayload(
                    thumbnailURL: setCard.coverImageURL
                )
            } else if let brandCard = customBrandCardPayload(from: message.customElem?.data) {
                kind = .card
                content = (try? String(data: JSONEncoder().encode(brandCard), encoding: .utf8))
                    ?? brandCard.brandName
                media = ChatMessageMediaPayload(
                    thumbnailURL: brandCard.coverImageURL
                )
            } else if let labelCard = customLabelCardPayload(from: message.customElem?.data) {
                kind = .card
                content = (try? String(data: JSONEncoder().encode(labelCard), encoding: .utf8))
                    ?? labelCard.labelName
                media = ChatMessageMediaPayload(
                    thumbnailURL: labelCard.coverImageURL
                )
            } else if let newsCard = customNewsCardPayload(from: message.customElem?.data) {
                kind = .card
                content = (try? String(data: JSONEncoder().encode(newsCard), encoding: .utf8))
                    ?? newsCard.headline
                media = ChatMessageMediaPayload(
                    thumbnailURL: newsCard.coverImageURL
                )
            } else if let rankingCard = customRankingBoardCardPayload(from: message.customElem?.data) {
                kind = .card
                content = (try? String(data: JSONEncoder().encode(rankingCard), encoding: .utf8))
                    ?? rankingCard.boardName
                media = ChatMessageMediaPayload(
                    thumbnailURL: rankingCard.coverImageURL
                )
            } else if let ratingEventCard = customRatingEventCardPayload(from: message.customElem?.data) {
                kind = .card
                content = message.customElem?.data.flatMap { String(data: $0, encoding: .utf8) }
                    ?? (try? String(data: JSONEncoder().encode(ratingEventCard), encoding: .utf8))
                    ?? ratingEventCard.eventName
                media = ChatMessageMediaPayload(
                    thumbnailURL: ratingEventCard.coverImageURL
                )
            } else if let ratingUnitCard = customRatingUnitCardPayload(from: message.customElem?.data) {
                kind = .card
                content = message.customElem?.data.flatMap { String(data: $0, encoding: .utf8) }
                    ?? (try? String(data: JSONEncoder().encode(ratingUnitCard), encoding: .utf8))
                    ?? ratingUnitCard.unitName
                media = ChatMessageMediaPayload(
                    thumbnailURL: ratingUnitCard.coverImageURL
                )
            } else if let postCard = customPostCardPayload(from: message.customElem?.data) {
                kind = .card
                content = (try? String(data: JSONEncoder().encode(postCard), encoding: .utf8))
                    ?? postCard.contentText
                media = ChatMessageMediaPayload(
                    thumbnailURL: postCard.coverImageURL
                )
            } else if let idCard = customCircleIDCardPayload(from: message.customElem?.data) {
                kind = .card
                content = (try? String(data: JSONEncoder().encode(idCard), encoding: .utf8))
                    ?? idCard.songName
                media = ChatMessageMediaPayload(
                    thumbnailURL: idCard.coverImageURL
                )
            } else if let myCheckinsCard = customMyCheckinsCardPayload(from: message.customElem?.data) {
                kind = .card
                content = message.customElem?.data.flatMap { String(data: $0, encoding: .utf8) }
                    ?? (try? String(data: JSONEncoder().encode(myCheckinsCard), encoding: .utf8))
                    ?? myCheckinsCard.title
                media = ChatMessageMediaPayload(
                    thumbnailURL: myCheckinsCard.coverImageURL
                )
            } else if let eventRouteCard = customEventRouteCardPayload(from: message.customElem?.data) {
                kind = .card
                content = message.customElem?.data.flatMap { String(data: $0, encoding: .utf8) }
                    ?? (try? String(data: JSONEncoder().encode(eventRouteCard), encoding: .utf8))
                    ?? eventRouteCard.title
                media = ChatMessageMediaPayload(
                    thumbnailURL: eventRouteCard.coverImageURL
                )
            } else if let offlineActivityCard = customSquadOfflineActivityCardPayload(from: message.customElem?.data) {
                kind = .card
                content = message.customElem?.data.flatMap { String(data: $0, encoding: .utf8) }
                    ?? (try? String(data: JSONEncoder().encode(offlineActivityCard), encoding: .utf8))
                    ?? offlineActivityCard.title
                media = ChatMessageMediaPayload(
                    thumbnailURL: offlineActivityCard.coverImageURL
                )
            } else {
                kind = .custom
                content = normalizedText(message.customElem?.desc) ?? LT("[自定义消息]", "[Custom Message]", "[カスタムメッセージ]")
            }
        case Self.elemTypeGroupTipsRawValue:
            kind = .system
            content = LT("[群提示]", "[Group Notice]", "[グループ通知]")
        case Self.elemTypeMergerRawValue:
            kind = .card
            content = LT("[聊天记录]", "[Merged Messages]", "[チャット履歴]")
        case Self.elemTypeStreamRawValue:
            kind = .custom
            content = LT("[流式消息]", "[Stream Message]", "[ストリームメッセージ]")
        default:
            break
        }

        let deliveryStatus: ChatMessageDeliveryStatus
        switch message.status.rawValue {
        case Self.messageStatusSendingRawValue:
            deliveryStatus = .sending
        case Self.messageStatusFailedRawValue:
            deliveryStatus = .failed
        case Self.messageStatusSentRawValue:
            deliveryStatus = .sent
        default:
            deliveryStatus = resolvedIsMine ? .sending : .sent
        }

#if DEBUG
        print(
            """
            [IMProfile][MessageMap] \
            conversationID=\(conversationID) \
            msgID=\(normalizedText(message.msgID) ?? "nil") \
            senderID=\(senderID) \
            senderName=\(senderDisplayName) \
            senderFace=\(normalizedText(message.faceURL) ?? "nil") \
            sdk_isSelf=\(message.isSelf) \
            resolved_isMine=\(resolvedIsMine) \
            currentUserID=\(currentUserID ?? "nil")
            """
        )
#endif

        return ChatMessage(
            id: normalizedText(message.msgID) ?? fallbackMessageID(for: message, conversationID: conversationID),
            conversationID: conversationID,
            sender: sender,
            content: content,
            createdAt: message.timestamp ?? Date(),
            isMine: resolvedIsMine,
            kind: kind,
            media: media,
            deliveryStatus: deliveryStatus,
            deliveryError: deliveryStatus == .failed ? LT("发送失败", "Send failed", "送信に失敗しました") : nil,
            mentionedUserIDs: mappedMentionedUserIDs(from: message),
            peerRead: dynamicBoolValue("isPeerRead", from: message),
            readReceiptReadCount: dynamicIntValue("groupReadCount", from: message)
                ?? dynamicIntValue("readCount", from: message)
                ?? dynamicIntValue("readReceiptCount", from: message),
            readReceiptUnreadCount: dynamicIntValue("groupUnreadCount", from: message)
                ?? dynamicIntValue("unreadCount", from: message)
                ?? dynamicIntValue("unreadReceiptCount", from: message)
        )
    }

    private func mappedMentionedUserIDs(from message: V2TIMMessage) -> [String] {
        let rawList = message.groupAtUserList as? [String] ?? []
        var result: [String] = []
        for rawEntry in rawList {
            let trimmed = rawEntry.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            if trimmed == kImSDK_MesssageAtALL {
                if !result.contains("all") {
                    result.append("all")
                }
                continue
            }
            let platformUserID = TencentIMIdentity.decodePlatformUserID(fromTencentIMUserID: trimmed) ?? trimmed
            if !result.contains(platformUserID) {
                result.append(platformUserID)
            }
        }
        return result
    }

    private func mapImagePayload(from elem: V2TIMImageElem?) -> ChatMessageMediaPayload? {
        guard let elem else { return nil }
        let images = elem.imageList ?? []
        let thumbnail = images.min { lhs, rhs in
            let lhsArea = max(1, lhs.width) * max(1, lhs.height)
            let rhsArea = max(1, rhs.width) * max(1, rhs.height)
            return lhsArea < rhsArea
        }
        let original = images.max { lhs, rhs in
            let lhsScore = max(lhs.size, lhs.width * lhs.height)
            let rhsScore = max(rhs.size, rhs.width * rhs.height)
            return lhsScore < rhsScore
        }

        return ChatMessageMediaPayload(
            mediaURL: normalizedText(original?.url) ?? normalizedText(thumbnail?.url),
            thumbnailURL: normalizedText(thumbnail?.url) ?? normalizedText(original?.url),
            width: {
                guard let value = original?.width ?? thumbnail?.width, value > 0 else { return nil }
                return Double(value)
            }(),
            height: {
                guard let value = original?.height ?? thumbnail?.height, value > 0 else { return nil }
                return Double(value)
            }(),
            durationSeconds: nil,
            fileName: nil,
            fileSizeBytes: {
                let value = original?.size ?? 0
                return value > 0 ? Int(value) : nil
            }()
        )
    }

    private func typingStatusPayload(from data: Data?) -> Int? {
        guard let data,
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let businessID = object["businessID"] as? String,
              businessID == Self.typingBusinessID else {
            return nil
        }

        if let typingStatus = object["typingStatus"] as? Int {
            return typingStatus
        }
        if let typingStatus = object["typingStatus"] as? NSNumber {
            return typingStatus.intValue
        }
        return nil
    }

    private func friendCreatedTipPayload(from data: Data?) -> String? {
        guard let data,
              let envelope = try? JSONDecoder().decode(TencentFriendCreatedTipEnvelope.self, from: data),
              envelope.businessID == Self.friendCreatedTipBusinessID else {
            return nil
        }

        return normalizedText(envelope.text)
    }

    private func customEventCardPayload(from data: Data?) -> EventShareCardPayload? {
        guard let data,
              let envelope = try? JSONDecoder().decode(TencentEventCardEnvelope.self, from: data),
              envelope.businessID == Self.customCardBusinessID,
              envelope.cardType == "event" else {
            return nil
        }
        return envelope.payload
    }

    private func customDJCardPayload(from data: Data?) -> DJShareCardPayload? {
        guard let data,
              let envelope = try? JSONDecoder().decode(TencentDJCardEnvelope.self, from: data),
              envelope.businessID == Self.customCardBusinessID,
              envelope.cardType == "dj" else {
            return nil
        }
        return envelope.payload
    }

    private func customSetCardPayload(from data: Data?) -> SetShareCardPayload? {
        guard let data,
              let envelope = try? JSONDecoder().decode(TencentSetCardEnvelope.self, from: data),
              envelope.businessID == Self.customCardBusinessID,
              envelope.cardType == "set" else {
            return nil
        }
        return envelope.payload
    }

    private func customBrandCardPayload(from data: Data?) -> BrandShareCardPayload? {
        guard let data,
              let envelope = try? JSONDecoder().decode(TencentBrandCardEnvelope.self, from: data),
              envelope.businessID == Self.customCardBusinessID,
              envelope.cardType == "brand" else {
            return nil
        }
        return envelope.payload
    }

    private func customLabelCardPayload(from data: Data?) -> LabelShareCardPayload? {
        guard let data,
              let envelope = try? JSONDecoder().decode(TencentLabelCardEnvelope.self, from: data),
              envelope.businessID == Self.customCardBusinessID,
              envelope.cardType == "label" else {
            return nil
        }
        return envelope.payload
    }

    private func customNewsCardPayload(from data: Data?) -> NewsShareCardPayload? {
        guard let data,
              let envelope = try? JSONDecoder().decode(TencentNewsCardEnvelope.self, from: data),
              envelope.businessID == Self.customCardBusinessID,
              envelope.cardType == "news" else {
            return nil
        }
        return envelope.payload
    }

    private func customRankingBoardCardPayload(from data: Data?) -> RankingBoardShareCardPayload? {
        guard let data,
              let envelope = try? JSONDecoder().decode(TencentRankingBoardCardEnvelope.self, from: data),
              envelope.businessID == Self.customCardBusinessID,
              envelope.cardType == "ranking" else {
            return nil
        }
        return envelope.payload
    }

    private func customRatingEventCardPayload(from data: Data?) -> RatingEventShareCardPayload? {
        guard let data,
              let envelope = try? JSONDecoder().decode(TencentRatingEventCardEnvelope.self, from: data),
              envelope.businessID == Self.customCardBusinessID,
              envelope.cardType == "rating_event" else {
            return nil
        }
        return envelope.payload
    }

    private func customRatingUnitCardPayload(from data: Data?) -> RatingUnitShareCardPayload? {
        guard let data,
              let envelope = try? JSONDecoder().decode(TencentRatingUnitCardEnvelope.self, from: data),
              envelope.businessID == Self.customCardBusinessID,
              envelope.cardType == "rating_unit" else {
            return nil
        }
        return envelope.payload
    }

    private func customPostCardPayload(from data: Data?) -> PostShareCardPayload? {
        guard let data,
              let envelope = try? JSONDecoder().decode(TencentPostCardEnvelope.self, from: data),
              envelope.businessID == Self.customCardBusinessID,
              envelope.cardType == "post" else {
            return nil
        }
        return envelope.payload
    }

    private func customCircleIDCardPayload(from data: Data?) -> CircleIDShareCardPayload? {
        guard let data,
              let envelope = try? JSONDecoder().decode(TencentCircleIDCardEnvelope.self, from: data),
              envelope.businessID == Self.customCardBusinessID,
              envelope.cardType == "circle_id" else {
            return nil
        }
        return envelope.payload
    }

    private func customMyCheckinsCardPayload(from data: Data?) -> MyCheckinsShareCardPayload? {
        guard let data,
              let envelope = try? JSONDecoder().decode(TencentMyCheckinsCardEnvelope.self, from: data),
              envelope.businessID == Self.customCardBusinessID,
              envelope.cardType == "my_checkins" else {
            return nil
        }
        return envelope.payload
    }

    private func customEventRouteCardPayload(from data: Data?) -> EventRouteShareCardPayload? {
        guard let data,
              let envelope = try? JSONDecoder().decode(TencentEventRouteCardEnvelope.self, from: data),
              envelope.businessID == Self.customCardBusinessID,
              envelope.cardType == "event_route" else {
            return nil
        }
        return envelope.payload
    }

    private func customSquadOfflineActivityCardPayload(from data: Data?) -> SquadOfflineActivityCardPayload? {
        guard let data,
              let envelope = try? JSONDecoder.raverISO8601().decode(TencentSquadOfflineActivityCardEnvelope.self, from: data),
              envelope.businessID == Self.customCardBusinessID,
              envelope.cardType == "squad_offline_activity" else {
            return nil
        }
        return envelope.payload
    }

    private func mapSoundPayload(from elem: V2TIMSoundElem?) async -> ChatMessageMediaPayload? {
        guard let elem else { return nil }
        let remoteURL = await resolveSoundURL(elem)
        return ChatMessageMediaPayload(
            mediaURL: remoteURL ?? normalizedText(elem.path),
            thumbnailURL: nil,
            width: nil,
            height: nil,
            durationSeconds: elem.duration > 0 ? Int(elem.duration) : nil,
            fileName: normalizedText(elem.uuid),
            fileSizeBytes: elem.dataSize > 0 ? Int(elem.dataSize) : nil
        )
    }

    private func mapVideoPayload(from elem: V2TIMVideoElem?) async -> ChatMessageMediaPayload? {
        guard let elem else { return nil }
        async let videoURL = resolveVideoURL(elem)
        async let snapshotURL = resolveVideoSnapshotURL(elem)
        let resolvedVideoURL = await videoURL
        let resolvedSnapshotURL = await snapshotURL
        return ChatMessageMediaPayload(
            mediaURL: resolvedVideoURL ?? normalizedText(elem.videoPath),
            thumbnailURL: resolvedSnapshotURL ?? normalizedText(elem.snapshotPath),
            width: elem.snapshotWidth > 0 ? Double(elem.snapshotWidth) : nil,
            height: elem.snapshotHeight > 0 ? Double(elem.snapshotHeight) : nil,
            durationSeconds: elem.duration > 0 ? Int(elem.duration) : nil,
            fileName: normalizedText(elem.videoUUID),
            fileSizeBytes: elem.videoSize > 0 ? Int(elem.videoSize) : nil
        )
    }

    private func mapFilePayload(from elem: V2TIMFileElem?) async -> ChatMessageMediaPayload? {
        guard let elem else { return nil }
        let remoteURL = await resolveFileURL(elem)
        return ChatMessageMediaPayload(
            mediaURL: remoteURL ?? normalizedText(elem.path),
            thumbnailURL: nil,
            width: nil,
            height: nil,
            durationSeconds: nil,
            fileName: normalizedText(elem.filename),
            fileSizeBytes: elem.fileSize > 0 ? Int(elem.fileSize) : nil
        )
    }

    private func fallbackMessageID(for message: V2TIMMessage, conversationID: String) -> String {
        "\(conversationID)-\(message.seq)-\(message.random)"
    }

    private func buildTencentIMError(code: Int32, desc: String?, fallback: String) -> ServiceError {
        let message = desc?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if message.isEmpty {
            return .message("\(fallback) (\(code))")
        }
        return .message(message)
    }

    private func normalizedText(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
            return nil
        }
        return trimmed
    }

    private func dynamicBoolValue(_ key: String, from object: NSObject) -> Bool? {
        guard object.responds(to: NSSelectorFromString(key)) else { return nil }
        if let value = object.value(forKey: key) as? NSNumber {
            return value.boolValue
        }
        return object.value(forKey: key) as? Bool
    }

    private func dynamicIntValue(_ key: String, from object: NSObject) -> Int? {
        guard object.responds(to: NSSelectorFromString(key)) else { return nil }
        if let value = object.value(forKey: key) as? NSNumber {
            return value.intValue
        }
        return object.value(forKey: key) as? Int
    }

    private func resolveSoundURL(_ elem: V2TIMSoundElem) async -> String? {
        await withCheckedContinuation { continuation in
            elem.getUrl { url in
                continuation.resume(returning: self.normalizedText(url))
            }
        }
    }

    private func resolveVideoURL(_ elem: V2TIMVideoElem) async -> String? {
        await withCheckedContinuation { continuation in
            elem.getVideoUrl { url in
                continuation.resume(returning: self.normalizedText(url))
            }
        }
    }

    private func resolveVideoSnapshotURL(_ elem: V2TIMVideoElem) async -> String? {
        await withCheckedContinuation { continuation in
            elem.getSnapshotUrl { url in
                continuation.resume(returning: self.normalizedText(url))
            }
        }
    }

    private func resolveFileURL(_ elem: V2TIMFileElem) async -> String? {
        await withCheckedContinuation { continuation in
            elem.getUrl { url in
                continuation.resume(returning: self.normalizedText(url))
            }
        }
    }

    private func makeVideoSnapshotURL(for fileURL: URL) throws -> URL {
        let asset = AVURLAsset(url: fileURL)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        let time = CMTime(seconds: 0.1, preferredTimescale: 600)
        guard let imageRef = try? generator.copyCGImage(at: time, actualTime: nil) else {
            throw ServiceError.message("Failed to create Tencent IM video snapshot")
        }

        let image = UIImage(cgImage: imageRef)
        guard let data = image.jpegData(compressionQuality: 0.82) else {
            throw ServiceError.message("Failed to encode Tencent IM video snapshot")
        }

        let snapshotURL = URL(
            fileURLWithPath: NSTemporaryDirectory(),
            isDirectory: true
        ).appendingPathComponent("tencent-im-video-\(UUID().uuidString).jpg")
        try data.write(to: snapshotURL, options: .atomic)
        return snapshotURL
    }

    private func audioDurationSeconds(for fileURL: URL) throws -> Int32 {
        let asset = AVURLAsset(url: fileURL)
        let durationSeconds = CMTimeGetSeconds(asset.duration)
        if durationSeconds.isFinite, durationSeconds > 0 {
            let clamped = max(1, min(Int(durationSeconds.rounded()), 600))
            return Int32(clamped)
        }
        return 1
    }

    private func audioFileDurationSecondsIfSupported(for fileURL: URL) -> Int? {
        guard isSupportedAudioFile(fileURL) else { return nil }
        guard let duration = try? audioDurationSeconds(for: fileURL) else { return nil }
        let resolved = Int(duration)
        return resolved > 0 ? resolved : nil
    }

    private func isSupportedAudioFile(_ fileURL: URL) -> Bool {
        let ext = fileURL.pathExtension.lowercased()
        return ["mp3", "m4a", "aac", "wav", "caf"].contains(ext)
    }

    private func fileSizeInBytes(for fileURL: URL) -> Int? {
        let values = try? fileURL.resourceValues(forKeys: [.fileSizeKey])
        return values?.fileSize
    }

    private func resolveBusinessConversationID(for message: V2TIMMessage) -> String? {
        if let groupID = normalizedText(message.groupID) {
            return groupID
        }
        if let userID = normalizedText(message.userID) {
            return userID
        }
        if let senderID = normalizedText(message.sender), message.isSelf {
            // Fallback for some SDK edge cases where userID is empty.
            return senderID
        }
        return nil
    }

    private func revokeDisplayText(
        for message: V2TIMMessage,
        operateUser: V2TIMUserFullInfo?
    ) -> String {
        let revokerID = normalizedText(operateUser?.userID)
            ?? normalizedText(message.revokerInfo?.userID)
            ?? normalizedText(message.sender)
        let messageSenderID = normalizedText(message.sender)
        let senderDisplayName = normalizedText(message.friendRemark)
            ?? normalizedText(message.nameCard)
            ?? normalizedText(message.nickName)
            ?? messageSenderID
            ?? LT("用户", "User", "ユーザー")
        let revokerDisplayName = normalizedText(operateUser?.nickName)
            ?? normalizedText(message.revokerInfo?.nickName)
            ?? senderDisplayName

        if revokerID == messageSenderID {
            if message.isSelf {
                return LT("你撤回了一条消息", "You recalled a message", "メッセージを取り消しました")
            }
            if normalizedText(message.userID) != nil {
                return LT("对方撤回了一条消息", "The other user recalled a message", "相手がメッセージを取り消しました")
            }
            return String(format: LT("%@ 撤回了一条消息", "%@ recalled a message", "%@ がメッセージを取り消しました"), senderDisplayName)
        }

        return String(format: LT("%@ 撤回了一条消息", "%@ recalled a message", "%@ がメッセージを取り消しました"), revokerDisplayName)
    }
#endif
}

#if canImport(ImSDK_Plus)
extension TencentIMSession: V2TIMSDKListener {
    nonisolated func onConnecting() {
        Task { @MainActor [weak self] in
            self?.state = .connecting
        }
    }

    nonisolated func onConnectSuccess() {
        Task { @MainActor [weak self] in
            guard let self, let currentUserID = self.currentUserID else { return }
            self.state = .connected(userID: currentUserID)
        }
    }

    nonisolated func onConnectFailed(_ code: Int32, err: String?) {
        let message = err?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let resolved = message.isEmpty ? "Tencent IM connect failed (\(code))" : message
        Task { @MainActor [weak self] in
            self?.state = .failed(resolved)
        }
    }

    nonisolated func onKickedOffline() {
        Task { @MainActor [weak self] in
            self?.unreadCount = 0
            self?.state = .kickedOffline
        }
    }

    nonisolated func onUserSigExpired() {
        Task { @MainActor [weak self] in
            self?.state = .userSigExpired
        }
    }
}

extension TencentIMSession: V2TIMConversationListener {
    nonisolated func onNewConversation(conversationList: [V2TIMConversation]) {
        Task { @MainActor [weak self] in
            self?.publishConversationChanges(conversationList)
        }
    }

    nonisolated func onConversationChanged(conversationList: [V2TIMConversation]) {
        Task { @MainActor [weak self] in
            self?.publishConversationChanges(conversationList)
        }
    }

    nonisolated func onTotalUnreadMessageCountChanged(totalUnreadCount: UInt64) {
        Task { @MainActor [weak self] in
            let count = Int(totalUnreadCount)
            self?.unreadCount = count
            self?.totalUnreadSubject.send(max(0, count))
        }
    }
}

extension TencentIMSession: V2TIMAdvancedMsgListener {
    nonisolated func onRecvNewMessage(msg: V2TIMMessage) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            guard let conversationID = self.resolveBusinessConversationID(for: msg) else { return }
            let mapped = await self.mapMessage(msg, conversationID: conversationID)
            self.messageSubject.send(mapped)
        }
    }

    nonisolated func onRecvMessageRevoked(msgID: String, operateUser: V2TIMUserFullInfo, reason: String?) {
        _ = reason
        Task { @MainActor [weak self] in
            guard let self else { return }
            guard let manager = V2TIMManager.sharedInstance() else { return }
            guard let revokedMessage = try? await self.findMessage(manager: manager, messageID: msgID) else { return }
            guard let conversationID = self.resolveBusinessConversationID(for: revokedMessage) else { return }
            let mapped = await self.mapMessage(revokedMessage, conversationID: conversationID)
            self.messageSubject.send(mapped)
            self.messageRevocationSubject.send(
                TencentMessageRevocationEvent(
                    conversationID: conversationID,
                    messageID: mapped.id,
                    displayText: self.revokeDisplayText(for: revokedMessage, operateUser: operateUser)
                )
            )
        }
    }

    nonisolated func onRecvC2CReadReceipt(receiptList: [V2TIMMessageReceipt]) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            let events = receiptList.compactMap { receipt -> TencentC2CReadReceiptEvent? in
                guard let conversationID = self.normalizedText(receipt.userID) else { return nil }
                let messageID = self.normalizedText(receipt.msgID)
                let readAt = receipt.timestamp > 0 ? Date(timeIntervalSince1970: TimeInterval(receipt.timestamp)) : nil
                return TencentC2CReadReceiptEvent(
                    conversationID: conversationID,
                    messageID: messageID,
                    peerRead: receipt.isPeerRead,
                    readAt: readAt
                )
            }
            guard !events.isEmpty else { return }
            self.c2cReadReceiptSubject.send(events)
        }
    }
}

#if canImport(ImSDK_Plus)
@MainActor
private extension TencentIMSession {
    func publishConversationChanges(_ items: [V2TIMConversation]) {
        let conversations = items.compactMap(mapConversation(_:))
        guard !conversations.isEmpty else { return }
        conversationSubject.send(conversations)
    }
}
#endif
#endif

#if !canImport(ImSDK_Plus)
@MainActor
extension TencentIMSession {
    func fetchConversations(type: ConversationType) async throws -> [Conversation]? {
        _ = type
        return nil
    }

    func markConversationRead(conversationID: String) async throws -> Bool {
        _ = conversationID
        return false
    }

    func setConversationPinned(conversationID: String, pinned: Bool) async throws -> Bool {
        _ = conversationID
        _ = pinned
        return false
    }

    func markConversationUnread(conversationID: String, unread: Bool) async throws -> Bool {
        _ = conversationID
        _ = unread
        return false
    }

    func hideConversation(conversationID: String) async throws -> Bool {
        _ = conversationID
        return false
    }

    func setConversationMuted(conversationID: String, muted: Bool) async throws -> Bool {
        _ = conversationID
        _ = muted
        return false
    }

    func clearConversationHistory(conversationID: String) async throws -> Bool {
        _ = conversationID
        return false
    }

    func fetchFriendRemark(userID: String) async throws -> String? {
        _ = userID
        return nil
    }

    func setFriendRemark(userID: String, remark: String?) async throws -> Bool {
        _ = userID
        _ = remark
        return false
    }

    func isUserBlacklisted(userID: String) async throws -> Bool {
        _ = userID
        return false
    }

    func setUserBlacklisted(userID: String, blacklisted: Bool) async throws -> Bool {
        _ = userID
        _ = blacklisted
        return false
    }

    func fetchMessages(conversationID: String, count: Int = 50) async throws -> [ChatMessage]? {
        _ = conversationID
        _ = count
        return nil
    }

    func fetchMessagesPage(
        conversationID: String,
        startClientMsgID: String?,
        count: Int = 50
    ) async throws -> ChatMessageHistoryPage? {
        _ = conversationID
        _ = startClientMsgID
        _ = count
        return nil
    }

    func sendTextMessage(conversationID: String, content: String) async throws -> ChatMessage? {
        _ = conversationID
        _ = content
        return nil
    }

    func sendImageMessage(
        conversationID: String,
        fileURL: URL,
        onProgress: ((Int) -> Void)?
    ) async throws -> ChatMessage? {
        _ = conversationID
        _ = fileURL
        _ = onProgress
        return nil
    }

    func sendVideoMessage(
        conversationID: String,
        fileURL: URL,
        onProgress: ((Int) -> Void)?
    ) async throws -> ChatMessage? {
        _ = conversationID
        _ = fileURL
        _ = onProgress
        return nil
    }

    func sendVoiceMessage(conversationID: String, fileURL: URL) async throws -> ChatMessage? {
        _ = conversationID
        _ = fileURL
        return nil
    }

    func revokeMessage(conversationID: String, messageID: String) async throws -> String? {
        _ = conversationID
        _ = messageID
        return nil
    }

    func deleteMessage(conversationID: String, messageID: String) async throws -> Bool {
        _ = conversationID
        _ = messageID
        return false
    }
}
#endif
