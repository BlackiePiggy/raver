import Foundation

struct ChatRouteTarget: Hashable {
    enum Kind: Hashable {
        case direct(userID: String)
        case group(groupID: String)
    }

    let kind: Kind?
    let preferredConversationID: String
    let fallbackConversationIDs: [String]
    let stagedConversation: Conversation?

    init(
        kind: Kind?,
        preferredConversationID: String,
        fallbackConversationIDs: [String] = [],
        stagedConversation: Conversation? = nil
    ) {
        self.kind = kind
        self.preferredConversationID = preferredConversationID
        self.fallbackConversationIDs = fallbackConversationIDs
        self.stagedConversation = stagedConversation
    }

    static func fromConversation(_ conversation: Conversation) -> ChatRouteTarget {
        let preferredConversationID = conversation.sdkConversationID ?? conversation.id
        let kind: Kind?
        switch conversation.type {
        case .direct:
            let directID = conversation.peer?.id.nilIfBlank
                ?? conversation.peer?.username.nilIfBlank
                ?? conversation.id.nilIfBlank
                ?? preferredConversationID
            kind = .direct(userID: directID)
        case .group:
            kind = .group(groupID: conversation.id)
        }
        let target = ChatRouteTarget(
            kind: kind,
            preferredConversationID: preferredConversationID,
            fallbackConversationIDs: [conversation.id, conversation.sdkConversationID].compactMap { $0?.nilIfBlank },
            stagedConversation: conversation
        )
        PushRouteTrace.log("ConversationRoute", "fromConversation target=\(target.debugSummary)")
        return target
    }

    static func conversationReference(_ conversationID: String) -> ChatRouteTarget {
        ChatRouteTarget(
            kind: nil,
            preferredConversationID: conversationID,
            fallbackConversationIDs: [conversationID],
            stagedConversation: nil
        )
    }

    static func pushReference(
        preferredConversationID: String,
        businessConversationID: String?,
        conversationType: String?,
        peerID: String?,
        groupID: String?
    ) -> ChatRouteTarget {
        let normalizedType = conversationType?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let normalizedPeerID = peerID?.nilIfBlank
        let normalizedGroupID = groupID?.nilIfBlank

        let kind: Kind?
        switch normalizedType {
        case ConversationType.direct.rawValue:
            kind = normalizedPeerID.map { .direct(userID: $0) }
        case ConversationType.group.rawValue:
            kind = normalizedGroupID.map { .group(groupID: $0) }
        default:
            if let normalizedPeerID {
                kind = .direct(userID: normalizedPeerID)
            } else if let normalizedGroupID {
                kind = .group(groupID: normalizedGroupID)
            } else {
                kind = nil
            }
        }

        let normalizedPreferred = preferredConversationID.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedBusinessConversationID = businessConversationID?.nilIfBlank
        let fallbackConversationIDs = [
            normalizedPreferred.nilIfBlank,
            normalizedBusinessConversationID,
            normalizedPeerID,
            normalizedGroupID
        ]
        .compactMap { $0 }

        let target = ChatRouteTarget(
            kind: kind,
            preferredConversationID: normalizedBusinessConversationID ?? normalizedPreferred,
            fallbackConversationIDs: fallbackConversationIDs,
            stagedConversation: nil
        )
        PushRouteTrace.log("ConversationRoute", "pushReference target=\(target.debugSummary)")
        return target
    }

    var debugSummary: String {
        let kindSummary: String
        switch kind {
        case .direct(let userID):
            kindSummary = "direct(\(userID))"
        case .group(let groupID):
            kindSummary = "group(\(groupID))"
        case .none:
            kindSummary = "nil"
        }

        let stagedSummary: String
        if let stagedConversation {
            stagedSummary = "id=\(stagedConversation.id),sdk=\(stagedConversation.sdkConversationID ?? "nil"),type=\(stagedConversation.type.rawValue)"
        } else {
            stagedSummary = "nil"
        }

        return "preferred=\(preferredConversationID) fallback=\(fallbackConversationIDs) kind=\(kindSummary) staged=\(stagedSummary)"
    }
}

extension String {
    var nilIfBlank: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
