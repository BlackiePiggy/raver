import Foundation

final class DemoAlignedChatContextProvider {
    private let conversationIDResolver: () -> String

    init(conversationIDResolver: @escaping () -> String) {
        self.conversationIDResolver = conversationIDResolver
    }

    var conversationID: String {
        conversationIDResolver()
    }
}
