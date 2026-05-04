import Foundation
import UserNotifications

final class NotificationService: UNNotificationServiceExtension {
    private enum SharedContext {
        static let suiteName = "group.com.raver.mvp"
        static let currentUserIDKey = "push.currentUserID"
    }

    private var contentHandler: ((UNNotificationContent) -> Void)?
    private var bestAttemptContent: UNMutableNotificationContent?

    override func didReceive(
        _ request: UNNotificationRequest,
        withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void
    ) {
        self.contentHandler = contentHandler
        guard let content = (request.content.mutableCopy() as? UNMutableNotificationContent) else {
            contentHandler(request.content)
            return
        }

        bestAttemptContent = content
        applyMentionPresentationIfNeeded(to: content)
        contentHandler(content)
    }

    override func serviceExtensionTimeWillExpire() {
        guard let contentHandler, let bestAttemptContent else { return }
        contentHandler(bestAttemptContent)
    }

    private func applyMentionPresentationIfNeeded(to content: UNMutableNotificationContent) {
        guard let extPayload = extractPushExtPayload(from: content.userInfo) else { return }
        let mentionState = resolveMentionState(from: extPayload)
        guard mentionState != .none else { return }

        let originalBody = content.body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !originalBody.isEmpty else { return }

        let prefix = mentionState.previewPrefix
        guard !prefix.isEmpty, !originalBody.hasPrefix(prefix) else { return }
        content.body = "\(prefix) \(originalBody)"
    }

    private func extractPushExtPayload(from userInfo: [AnyHashable: Any]) -> [String: Any]? {
        if let ext = userInfo["ext"] as? String,
           let payload = decodeJSONObject(from: ext) {
            return payload
        }
        if let ext = userInfo["entity"] as? String,
           let payload = decodeJSONObject(from: ext) {
            return payload
        }
        if let ext = userInfo["ext"] as? [String: Any] {
            return ext
        }
        if let ext = userInfo["entity"] as? [String: Any] {
            return ext
        }
        return nil
    }

    private func decodeJSONObject(from string: String) -> [String: Any]? {
        guard let data = string.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data, options: []),
              let dictionary = object as? [String: Any] else {
            return nil
        }
        return dictionary
    }

    private func resolveMentionState(from payload: [String: Any]) -> GroupMentionAlertType {
        let mentionedUserIDs = (payload["mentionedUserIDs"] as? [Any])?
            .compactMap { ($0 as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty } ?? []
        let mentionAll = (payload["mentionAll"] as? Bool) ?? mentionedUserIDs.contains("all")
        let currentUserID = UserDefaults(suiteName: SharedContext.suiteName)?
            .string(forKey: SharedContext.currentUserIDKey)?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let mentionMe = currentUserID.map { mentionedUserIDs.contains($0) } ?? false
        switch (mentionMe, mentionAll) {
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
}

private enum GroupMentionAlertType {
    case none
    case atMe
    case atAll
    case atAllAndMe

    var previewPrefix: String {
        switch self {
        case .none:
            return ""
        case .atMe:
            return "[@你]"
        case .atAll:
            return "[@所有人]"
        case .atAllAndMe:
            return "[@你][@所有人]"
        }
    }
}
