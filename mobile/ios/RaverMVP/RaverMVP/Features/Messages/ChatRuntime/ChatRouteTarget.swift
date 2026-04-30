import Foundation

struct ChatRouteTarget: Hashable {
    enum Kind: Hashable {
        case direct(userID: String)
        case group(groupID: String)
    }

    let kind: Kind?
    let preferredConversationID: String
    let stagedConversation: Conversation?

    init(
        kind: Kind?,
        preferredConversationID: String,
        stagedConversation: Conversation? = nil
    ) {
        self.kind = kind
        self.preferredConversationID = preferredConversationID
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
        return ChatRouteTarget(
            kind: kind,
            preferredConversationID: preferredConversationID,
            stagedConversation: conversation
        )
    }

    static func conversationReference(_ conversationID: String) -> ChatRouteTarget {
        ChatRouteTarget(
            kind: nil,
            preferredConversationID: conversationID,
            stagedConversation: nil
        )
    }
}

extension String {
    var nilIfBlank: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
