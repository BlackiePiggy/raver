import Foundation

enum AppRuntimeMode: String {
    case mock
    case live
}

enum AppConfig {
    enum DJAvatarSize {
        case original
        case medium
        case small
    }

    private static let localUserAvatarAssets: [String] = (1...24).map { String(format: "LocalUserAvatar%02d", $0) }
    private static let localGroupAvatarAssets: [String] = (1...12).map { String(format: "LocalGroupAvatar%02d", $0) }
    private static let persistedRuntimeModeKey = "raver.persisted.runtimeMode"
    private static let persistedBFFBaseURLKey = "raver.persisted.bffBaseURL"

    static var runtimeMode: AppRuntimeMode {
        if let envMode = runtimeModeFromEnvironmentValue(ProcessInfo.processInfo.environment["RAVER_USE_MOCK"]) {
            UserDefaults.standard.set(envMode.rawValue, forKey: persistedRuntimeModeKey)
            return envMode
        }

        if let persisted = UserDefaults.standard.string(forKey: persistedRuntimeModeKey),
           let mode = AppRuntimeMode(rawValue: persisted) {
            return mode
        }

        return .mock
    }

    static var bffBaseURL: URL {
        if let custom = normalizedBaseURLString(ProcessInfo.processInfo.environment["RAVER_BFF_BASE_URL"]),
           let url = URL(string: custom) {
            UserDefaults.standard.set(custom, forKey: persistedBFFBaseURLKey)
            return url
        }

        if let persisted = normalizedBaseURLString(UserDefaults.standard.string(forKey: persistedBFFBaseURLKey)),
           let url = URL(string: persisted) {
            return url
        }
        return URL(string: "http://localhost:8787")!
    }

    private static func normalizedBaseURLString(_ raw: String?) -> String? {
        guard let raw else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if let url = URL(string: trimmed), url.scheme != nil {
            return url.absoluteString
        }

        let withDefaultScheme = "http://\(trimmed)"
        guard let url = URL(string: withDefaultScheme), url.host != nil else { return nil }
        return url.absoluteString
    }

    private static func runtimeModeFromEnvironmentValue(_ raw: String?) -> AppRuntimeMode? {
        guard let raw else { return nil }
        let normalized = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalized.isEmpty else { return nil }

        switch normalized {
        case "0", "false", "live":
            return .live
        case "1", "true", "mock":
            return .mock
        default:
            return nil
        }
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

    static func resolvedDJAvatarURLString(_ value: String?, size: DJAvatarSize = .original) -> String? {
        guard let resolved = resolvedURLString(value), !resolved.isEmpty else { return nil }
        guard size != .original else { return resolved }
        guard var components = URLComponents(string: resolved),
              let host = components.host?.lowercased() else {
            return resolved
        }

        let pathLooksLikeDJMedia = components.path.lowercased().contains("/djs/")
        if !isLikelyOssImageHost(host) && !pathLooksLikeDJMedia {
            return resolved
        }

        let process: String
        switch size {
        case .original:
            return resolved
        case .medium:
            process = "image/resize,m_fill,w_480,h_480/quality,q_88/format,webp"
        case .small:
            process = "image/resize,m_fill,w_160,h_160/quality,q_82/format,webp"
        }

        var items = components.queryItems?.filter { $0.name.lowercased() != "x-oss-process" } ?? []
        items.append(URLQueryItem(name: "x-oss-process", value: process))
        components.queryItems = items
        return components.string ?? resolved
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

    private static func isLikelyOssImageHost(_ host: String) -> Bool {
        if host == "aliyuncs.com" || host.hasSuffix(".aliyuncs.com") {
            return true
        }
        let extraHosts = ProcessInfo.processInfo.environment["RAVER_OSS_IMAGE_HOSTS"]?
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .filter { !$0.isEmpty } ?? []
        return extraHosts.contains(where: { suffix in
            host == suffix || host.hasSuffix(".\(suffix)")
        })
    }
}
