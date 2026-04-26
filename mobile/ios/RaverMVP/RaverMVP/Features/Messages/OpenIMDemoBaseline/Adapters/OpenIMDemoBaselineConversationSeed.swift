import Foundation

struct OpenIMDemoBaselineConversationSeed: Equatable {
    enum SessionKind: Equatable {
        case direct
        case group
    }

    let businessConversationID: String
    let openIMConversationID: String?
    let sessionKind: SessionKind
    let currentUserID: String?
    let peerUserID: String?
    let groupID: String?
    let title: String
    let faceURL: String?
}

extension OpenIMDemoBaselineConversationSeed {
    init(conversationInfo: OpenIMDemoBaselineConversationInfo) {
        self.init(
            businessConversationID: conversationInfo.conversationID,
            openIMConversationID: conversationInfo.conversationID,
            sessionKind: conversationInfo.conversationType == .superGroup ? .group : .direct,
            currentUserID: nil,
            peerUserID: conversationInfo.userID,
            groupID: conversationInfo.groupID,
            title: conversationInfo.showName ?? conversationInfo.conversationID,
            faceURL: conversationInfo.faceURL
        )
    }
}

@MainActor
enum OpenIMDemoBaselineConversationSeedFactory {
    static func make(
        from conversation: Conversation,
        session: OpenIMSession
    ) -> OpenIMDemoBaselineConversationSeed {
        let kind: OpenIMDemoBaselineConversationSeed.SessionKind
        switch conversation.type {
        case .direct:
            kind = .direct
        case .group:
            kind = .group
        }

        let currentBusinessUserID = session.currentBusinessUserIDSnapshot()
        let resolvedPeerUserID: String? = {
            if conversation.type != .direct { return nil }
            if let peerID = normalizedID(conversation.peer?.id) {
                return peerID
            }
            return inferDirectPeerBusinessUserID(
                fromOpenIMConversationID: conversation.openIMConversationID,
                currentBusinessUserID: currentBusinessUserID
            )
        }()

        return OpenIMDemoBaselineConversationSeed(
            businessConversationID: conversation.id,
            openIMConversationID: conversation.openIMConversationID,
            sessionKind: kind,
            currentUserID: currentBusinessUserID,
            peerUserID: resolvedPeerUserID,
            groupID: conversation.type == .group ? conversation.id : nil,
            title: conversation.title,
            faceURL: conversation.avatarURL
        )
    }

    private static func normalizedID(_ value: String?) -> String? {
        guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !value.isEmpty else {
            return nil
        }
        return value
    }

    private static func inferDirectPeerBusinessUserID(
        fromOpenIMConversationID openIMConversationID: String?,
        currentBusinessUserID: String?
    ) -> String? {
        guard let source = normalizedID(openIMConversationID) else { return nil }
        let pattern = #"u_[0-9a-zA-Z\-]+"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(source.startIndex..<source.endIndex, in: source)
        let matches = regex.matches(in: source, range: range)
        let openIMUserIDs = matches.compactMap {
            Range($0.range, in: source).map { String(source[$0]) }
        }
        guard !openIMUserIDs.isEmpty else { return nil }
        let businessUserIDs = openIMUserIDs.map {
            String($0.dropFirst(2))
        }
        guard let currentBusinessUserID else {
            return businessUserIDs.first
        }
        return businessUserIDs.first(where: { $0 != currentBusinessUserID }) ?? businessUserIDs.first
    }
}
