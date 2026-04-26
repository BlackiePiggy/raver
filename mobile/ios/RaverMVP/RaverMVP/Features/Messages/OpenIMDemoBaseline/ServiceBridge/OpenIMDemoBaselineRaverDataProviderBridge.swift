import Foundation

@MainActor
final class OpenIMDemoBaselineRaverDataProviderBridge: OpenIMDemoBaselineDataProviderBridge {
    static let shared = OpenIMDemoBaselineRaverDataProviderBridge(
        session: .shared,
        service: AppEnvironment.makeService(),
        imBridge: OpenIMDemoBaselineRaverIMControllerBridge.shared
    )

    private let session: OpenIMSession
    private let service: SocialService
    private let imBridge: OpenIMDemoBaselineIMControllerBridge

    init(
        session: OpenIMSession,
        service: SocialService,
        imBridge: OpenIMDemoBaselineIMControllerBridge
    ) {
        self.session = session
        self.service = service
        self.imBridge = imBridge
    }

    var currentUserID: String? {
        session.currentBusinessUserIDSnapshot()
    }

    var currentUserInfo: OpenIMDemoBaselineUserInfo? {
        guard let userID = currentUserID else { return nil }
        return OpenIMDemoBaselineUserInfo(
            userID: userID,
            nickname: userID,
            remark: nil,
            faceURL: nil
        )
    }

    func getGroupInfo(
        groupIDs: [String],
        completion: @escaping ([OpenIMDemoBaselineGroupInfo]) -> Void
    ) {
        Task {
            let groups = await groupInfos(for: groupIDs)
            await MainActor.run {
                completion(groups)
            }
        }
    }

    func isJoinedGroup(
        groupID: String,
        completion: @escaping (Bool) -> Void
    ) {
        Task {
            let joined = await isJoinedGroup(groupID: groupID)
            await MainActor.run {
                completion(joined)
            }
        }
    }

    func getGroupMembersInfo(
        groupID: String,
        userIDs: [String],
        completion: @escaping ([OpenIMDemoBaselineGroupMemberInfo]) -> Void
    ) {
        Task {
            let members = await groupMembers(groupID: groupID, filtering: userIDs)
            await MainActor.run {
                completion(members)
            }
        }
    }

    func getAllGroupMembers(groupID: String) async -> [OpenIMDemoBaselineGroupMemberInfo] {
        await groupMembers(groupID: groupID, filtering: nil)
    }

    func getFriendsInfo(
        userIDs: [String],
        completion: @escaping ([OpenIMDemoBaselineFriendInfo]) -> Void
    ) {
        Task {
            let infos = await friendInfos(userIDs: userIDs)
            await MainActor.run {
                completion(infos)
            }
        }
    }

    func getHistoryMessageList(
        conversationID: String,
        conversationType: OpenIMDemoBaselineConversationType,
        startClientMsgID: String?,
        count: Int,
        completion: @escaping (_ isEnd: Bool, _ messages: [OpenIMDemoBaselineMessageInfo]) -> Void
    ) {
        Task {
            let result = await historyMessages(
                conversationID: conversationID,
                conversationType: conversationType,
                startClientMsgID: startClientMsgID,
                count: count,
                reverse: false
            )
            await MainActor.run {
                completion(result.isEnd, result.messages)
            }
        }
    }

    func getHistoryMessageListReverse(
        conversationID: String,
        startClientMsgID: String?,
        count: Int,
        completion: @escaping (_ isEnd: Bool, _ messages: [OpenIMDemoBaselineMessageInfo]) -> Void
    ) {
        Task {
            let result = await historyMessages(
                conversationID: conversationID,
                conversationType: .c2c,
                startClientMsgID: startClientMsgID,
                count: count,
                reverse: true
            )
            await MainActor.run {
                completion(result.isEnd, result.messages)
            }
        }
    }

    private func historyMessages(
        conversationID: String,
        conversationType: OpenIMDemoBaselineConversationType,
        startClientMsgID: String?,
        count: Int,
        reverse: Bool
    ) async -> (isEnd: Bool, messages: [OpenIMDemoBaselineMessageInfo]) {
        let sessionKind: OpenIMDemoBaselineConversationSeed.SessionKind = conversationType == .superGroup ? .group : .direct
        let seed = OpenIMDemoBaselineConversationSeed(
            businessConversationID: conversationID,
            openIMConversationID: conversationID,
            sessionKind: sessionKind,
            currentUserID: currentUserID,
            peerUserID: sessionKind == .direct ? conversationID : nil,
            groupID: sessionKind == .group ? conversationID : nil,
            title: conversationID,
            faceURL: nil
        )

        #if canImport(OpenIMSDK)
        if let rawService = service as? OpenIMRawChatService {
            do {
                let page: OpenIMRawMessagePage?
                if reverse, startClientMsgID == nil {
                    page = try await rawService.fetchRawMessagesPage(
                        conversationID: conversationID,
                        startClientMsgID: nil,
                        count: count
                    )
                } else {
                    page = try await rawService.fetchRawMessagesPage(
                        conversationID: conversationID,
                        startClientMsgID: startClientMsgID,
                        count: count
                    )
                }
                let rawMessages = page?.messages ?? []
                let mapped = rawMessages.map { raw in
                    let chatMessage = rawService.chatMessageSnapshot(from: raw, conversationID: conversationID)
                    return imBridge.messageInfo(from: chatMessage, seed: seed)
                }
                return (page?.isEnd ?? true, reverse ? mapped : mapped)
            } catch {
                return (true, [])
            }
        }
        #endif

        do {
            let messages = try await service.fetchMessages(conversationID: conversationID)
            let sorted = messages.sorted(by: { $0.createdAt < $1.createdAt })
            let filtered: [ChatMessage]
            if let startClientMsgID, let anchorIndex = sorted.firstIndex(where: { $0.id == startClientMsgID }) {
                filtered = Array(sorted.prefix(anchorIndex))
            } else {
                filtered = sorted
            }
            let slice = Array(filtered.suffix(max(0, count)))
            return (filtered.count <= count, imBridge.messageInfos(from: slice, seed: seed))
        } catch {
            return (true, [])
        }
    }

    private func friendInfos(userIDs: [String]) async -> [OpenIMDemoBaselineFriendInfo] {
        var result: [OpenIMDemoBaselineFriendInfo] = []
        for userID in userIDs {
            if let info = await friendInfo(userID: userID) {
                result.append(info)
            }
        }
        return result
    }

    private func friendInfo(userID: String) async -> OpenIMDemoBaselineFriendInfo? {
        do {
            let profile = try await service.fetchUserProfile(userID: userID)
            return OpenIMDemoBaselineFriendInfo(
                userID: profile.id,
                nickname: profile.displayName,
                faceURL: profile.avatarURL,
                ownerUserID: currentUserID,
                remark: nil
            )
        } catch {
            return OpenIMDemoBaselineFriendInfo(
                userID: userID,
                nickname: userID,
                faceURL: nil,
                ownerUserID: currentUserID,
                remark: nil
            )
        }
    }

    private func groupInfos(for groupIDs: [String]) async -> [OpenIMDemoBaselineGroupInfo] {
        var result: [OpenIMDemoBaselineGroupInfo] = []
        for groupID in groupIDs {
            if let info = await groupInfo(groupID: groupID) {
                result.append(info)
            }
        }
        return result
    }

    private func groupInfo(groupID: String) async -> OpenIMDemoBaselineGroupInfo? {
        do {
            let squad = try await service.fetchSquadProfile(squadID: groupID)
            return OpenIMDemoBaselineGroupInfo(
                groupID: squad.id,
                groupName: squad.name,
                faceURL: squad.avatarURL,
                ownerUserID: squad.leader.id,
                memberCount: squad.memberCount
            )
        } catch {
            do {
                let groups = try await service.fetchConversations(type: .group)
                if let conversation = groups.first(where: { $0.id == groupID }) {
                    return OpenIMDemoBaselineGroupInfo(
                        groupID: groupID,
                        groupName: conversation.title,
                        faceURL: conversation.avatarURL,
                        ownerUserID: nil,
                        memberCount: 0
                    )
                }
            } catch {}
            return OpenIMDemoBaselineGroupInfo(
                groupID: groupID,
                groupName: groupID,
                faceURL: nil,
                ownerUserID: nil,
                memberCount: 0
            )
        }
    }

    private func groupMembers(
        groupID: String,
        filtering userIDs: [String]?
    ) async -> [OpenIMDemoBaselineGroupMemberInfo] {
        do {
            let squad = try await service.fetchSquadProfile(squadID: groupID)
            let members = squad.members.filter { member in
                guard let userIDs, !userIDs.isEmpty else { return true }
                return userIDs.contains(member.id)
            }
            return members.map {
                OpenIMDemoBaselineGroupMemberInfo(
                    userID: $0.id,
                    groupID: groupID,
                    nickname: $0.shownName,
                    faceURL: $0.avatarURL
                )
            }
        } catch {
            let ids = userIDs ?? []
            return ids.map {
                OpenIMDemoBaselineGroupMemberInfo(
                    userID: $0,
                    groupID: groupID,
                    nickname: $0,
                    faceURL: nil
                )
            }
        }
    }

    private func isJoinedGroup(groupID: String) async -> Bool {
        do {
            let squads = try await service.fetchMySquads()
            return squads.contains(where: { $0.id == groupID })
        } catch {
            return false
        }
    }
}
