import Foundation

enum AppRuntimeMode: String {
    case mock
    case live
}

enum AppConfig {
    private static let localUserAvatarAssets: [String] = (1...24).map { String(format: "LocalUserAvatar%02d", $0) }
    private static let localGroupAvatarAssets: [String] = (1...12).map { String(format: "LocalGroupAvatar%02d", $0) }

    static var runtimeMode: AppRuntimeMode {
        if ProcessInfo.processInfo.environment["RAVER_USE_MOCK"] == "0" {
            return .live
        }
        return .mock
    }

    static var bffBaseURL: URL {
        if let custom = ProcessInfo.processInfo.environment["RAVER_BFF_BASE_URL"],
           let url = URL(string: custom) {
            return url
        }
        return URL(string: "http://localhost:8787")!
    }

    static func resolvedURLString(_ value: String?) -> String? {
        guard let value, !value.isEmpty else { return nil }
        if value.hasPrefix("http://") || value.hasPrefix("https://") {
            return value
        }
        if value.hasPrefix("/") {
            let base = bffBaseURL.absoluteString.hasSuffix("/")
                ? String(bffBaseURL.absoluteString.dropLast())
                : bffBaseURL.absoluteString
            return "\(base)\(value)"
        }
        return value
    }

    static func resolvedUserAvatarAssetName(
        userID: String?,
        username: String?,
        avatarURL: String?
    ) -> String {
        if let explicit = explicitLocalAvatarName(from: avatarURL, allowed: localUserAvatarAssets) {
            return explicit
        }
        return avatarAssetName(from: userID ?? username ?? avatarURL ?? "user-default", pool: localUserAvatarAssets)
    }

    static func resolvedGroupAvatarAssetName(
        groupID: String?,
        groupName: String?,
        avatarURL: String?
    ) -> String {
        if let explicit = explicitLocalAvatarName(from: avatarURL, allowed: localGroupAvatarAssets) {
            return explicit
        }
        return avatarAssetName(from: groupID ?? groupName ?? avatarURL ?? "group-default", pool: localGroupAvatarAssets)
    }

    private static func explicitLocalAvatarName(from raw: String?, allowed: [String]) -> String? {
        guard let raw else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let localPrefixA = "local-avatar://"
        let localPrefixB = "local-avatar:"
        let token: String?

        if trimmed.hasPrefix(localPrefixA) {
            token = String(trimmed.dropFirst(localPrefixA.count))
        } else if trimmed.hasPrefix(localPrefixB) {
            token = String(trimmed.dropFirst(localPrefixB.count))
        } else {
            token = nil
        }

        if let token, allowed.contains(token) {
            return token
        }
        return nil
    }

    private static func avatarAssetName(from seed: String, pool: [String]) -> String {
        guard !pool.isEmpty else { return "LocalUserAvatar01" }
        let normalized = seed.lowercased()
        var hash: UInt64 = 1469598103934665603
        let prime: UInt64 = 1099511628211
        for scalar in normalized.unicodeScalars {
            hash ^= UInt64(scalar.value)
            hash = hash &* prime
        }
        let index = Int(hash % UInt64(pool.count))
        return pool[index]
    }
}
