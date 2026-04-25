import Foundation

enum DemoAlignedChatLogEvent {
    case sendFailed(kind: String, conversationID: String, errorDescription: String)
    case resendFailed(conversationID: String, messageID: String, errorDescription: String)
    case mediaPickerError(conversationID: String, reason: String, message: String)
    case sendFailureHintShown(conversationID: String)
    case failureHintShown(conversationID: String, reason: String)
    case assemblyDependencyMissing(conversationID: String, step: String, dependencies: String)
    case assemblyActionUnhandled(conversationID: String, action: String)

    var line: String {
        switch self {
        case let .sendFailed(kind, conversationID, errorDescription):
            return "[DemoAlignedChat] send \(kind) failed conversation=\(conversationID) error=\(errorDescription)"
        case let .resendFailed(conversationID, messageID, errorDescription):
            return "[DemoAlignedChat] resend failed conversation=\(conversationID) message=\(messageID) error=\(errorDescription)"
        case let .mediaPickerError(conversationID, reason, message):
            return "[DemoAlignedChat] media picker error conversation=\(conversationID) reason=\(reason) message=\(message)"
        case let .sendFailureHintShown(conversationID):
            return "[DemoAlignedChat] send failure hint shown conversation=\(conversationID)"
        case let .failureHintShown(conversationID, reason):
            return "[DemoAlignedChat] failure hint shown conversation=\(conversationID) reason=\(reason)"
        case let .assemblyDependencyMissing(conversationID, step, dependencies):
            return "[DemoAlignedChat] assembly dependency missing conversation=\(conversationID) step=\(step) dependencies=\(dependencies)"
        case let .assemblyActionUnhandled(conversationID, action):
            return "[DemoAlignedChat] assembly action unhandled conversation=\(conversationID) action=\(action)"
        }
    }
}

enum DemoAlignedChatLogger {
    static func log(_ event: DemoAlignedChatLogEvent) {
        OpenIMProbeLogger.log(event.line)
    }

    static func sendFailed(kind: String, conversationID: String, error: Error) {
        log(
            .sendFailed(
                kind: kind,
                conversationID: conversationID,
                errorDescription: error.localizedDescription
            )
        )
    }

    static func resendFailed(conversationID: String, messageID: String, error: Error) {
        log(
            .resendFailed(
                conversationID: conversationID,
                messageID: messageID,
                errorDescription: error.localizedDescription
            )
        )
    }

    static func mediaPickerError(conversationID: String, reason: String, message: String) {
        log(
            .mediaPickerError(
                conversationID: conversationID,
                reason: reason,
                message: message
            )
        )
    }

    static func sendFailureHintShown(conversationID: String) {
        log(.sendFailureHintShown(conversationID: conversationID))
    }

    static func failureHintShown(conversationID: String, reason: String) {
        log(.failureHintShown(conversationID: conversationID, reason: reason))
    }

    static func assemblyDependencyMissing(conversationID: String, step: String, dependencies: String) {
        log(
            .assemblyDependencyMissing(
                conversationID: conversationID,
                step: step,
                dependencies: dependencies
            )
        )
    }

    static func assemblyActionUnhandled(conversationID: String, action: String) {
        log(
            .assemblyActionUnhandled(
                conversationID: conversationID,
                action: action
            )
        )
    }
}
