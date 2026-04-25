import Foundation

enum RaverChatMediaResolver {
    static func resolvedURL(from rawValue: String?) -> URL? {
        guard let rawValue, !rawValue.isEmpty else {
            return nil
        }

        if rawValue.hasPrefix("file://") || rawValue.hasPrefix("/") {
            if let managedLocalURL = ChatMediaTempFileStore.resolveExistingFileURL(from: rawValue) {
                return managedLocalURL
            }
            if rawValue.hasPrefix("file://") {
                return URL(string: rawValue)
            }
            if rawValue.hasPrefix("/"),
               (rawValue.hasPrefix("/var/") || rawValue.hasPrefix("/private/") || rawValue.hasPrefix("/Users/")) {
                return URL(fileURLWithPath: rawValue)
            }
        }

        if let resolved = AppConfig.resolvedURLString(rawValue), let url = URL(string: resolved) {
            return url
        }

        return URL(string: rawValue)
    }

    static func previewRawURL(for message: ChatMessage) -> String? {
        switch message.kind {
        case .image:
            return message.media?.thumbnailURL ?? message.media?.mediaURL
        case .video:
            return message.media?.thumbnailURL ?? message.media?.mediaURL
        case .voice, .file:
            return message.media?.mediaURL
        default:
            return nil
        }
    }

    static func playbackRawURL(for message: ChatMessage) -> String? {
        switch message.kind {
        case .image:
            return message.media?.mediaURL ?? message.media?.thumbnailURL
        case .video, .voice, .file:
            return message.media?.mediaURL
        default:
            return nil
        }
    }
}
