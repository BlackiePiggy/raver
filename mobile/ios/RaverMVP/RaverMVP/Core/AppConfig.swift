import Foundation

enum AppRuntimeMode: String {
    case mock
    case live
}

enum RegionalComplianceRegion: String, Codable {
    case global = "GLOBAL"
    case japan = "JP"
}

enum UserAgeBand: String, Codable, Hashable {
    case under13 = "under_13"
    case minor
    case adult
    case unknown
}

struct RegionalCompliancePolicy {
    struct MinorRestrictions {
        let strangerDirectMessages: Bool
        let locationSharing: Bool
        let lateNightEventTicketLinks: Bool
        let adultContentExposure: Bool
    }

    let region: RegionalComplianceRegion
    let isEnabled: Bool
    let requiresAgeDeclaration: Bool
    let minimumAge: Int
    let minorAgeThreshold: Int
    let minorRestrictions: MinorRestrictions
}

enum RegionalCompliance {
    static var activePolicy: RegionalCompliancePolicy {
        let raw = ProcessInfo.processInfo.environment["RAVER_COMPLIANCE_DEFAULT_REGION"]?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()

        if raw == "GLOBAL" || raw == "OFF" || raw == "DISABLED" {
            return globalPolicy
        }

        return japanPolicy
    }

    static let globalPolicy = RegionalCompliancePolicy(
        region: .global,
        isEnabled: true,
        requiresAgeDeclaration: false,
        minimumAge: 13,
        minorAgeThreshold: 18,
        minorRestrictions: .init(
            strangerDirectMessages: false,
            locationSharing: false,
            lateNightEventTicketLinks: false,
            adultContentExposure: false
        )
    )

    static let japanPolicy = RegionalCompliancePolicy(
        region: .japan,
        isEnabled: true,
        requiresAgeDeclaration: true,
        minimumAge: 13,
        minorAgeThreshold: 18,
        minorRestrictions: .init(
            strangerDirectMessages: true,
            locationSharing: true,
            lateNightEventTicketLinks: true,
            adultContentExposure: true
        )
    )

    static func ageBand(for birthYear: Int, now: Date = Date()) -> UserAgeBand {
        let currentYear = Calendar(identifier: .gregorian).component(.year, from: now)
        let age = currentYear - birthYear
        if age < activePolicy.minimumAge { return .under13 }
        if age < activePolicy.minorAgeThreshold { return .minor }
        return .adult
    }
}

enum AppConfig {
    enum DJAvatarSize {
        case original
        case medium
        case small
    }

    private static let defaultUserAvatarURLs: [String] = [
        "https://wen-jasonlee.oss-cn-shanghai.aliyuncs.com/defaults/avatars/user/user-avatar-01.png",
        "https://wen-jasonlee.oss-cn-shanghai.aliyuncs.com/defaults/avatars/user/user-avatar-02.png",
        "https://wen-jasonlee.oss-cn-shanghai.aliyuncs.com/defaults/avatars/user/user-avatar-03.png",
        "https://wen-jasonlee.oss-cn-shanghai.aliyuncs.com/defaults/avatars/user/user-avatar-04.png",
        "https://wen-jasonlee.oss-cn-shanghai.aliyuncs.com/defaults/avatars/user/user-avatar-05.png",
        "https://wen-jasonlee.oss-cn-shanghai.aliyuncs.com/defaults/avatars/user/user-avatar-06.png",
        "https://wen-jasonlee.oss-cn-shanghai.aliyuncs.com/defaults/avatars/user/user-avatar-07.png",
        "https://wen-jasonlee.oss-cn-shanghai.aliyuncs.com/defaults/avatars/user/user-avatar-08.png",
        "https://wen-jasonlee.oss-cn-shanghai.aliyuncs.com/defaults/avatars/user/user-avatar-09.png",
        "https://wen-jasonlee.oss-cn-shanghai.aliyuncs.com/defaults/avatars/user/user-avatar-10.png",
        "https://wen-jasonlee.oss-cn-shanghai.aliyuncs.com/defaults/avatars/user/user-avatar-11.png",
        "https://wen-jasonlee.oss-cn-shanghai.aliyuncs.com/defaults/avatars/user/user-avatar-12.png",
        "https://wen-jasonlee.oss-cn-shanghai.aliyuncs.com/defaults/avatars/user/user-avatar-13.png",
        "https://wen-jasonlee.oss-cn-shanghai.aliyuncs.com/defaults/avatars/user/user-avatar-14.png",
        "https://wen-jasonlee.oss-cn-shanghai.aliyuncs.com/defaults/avatars/user/user-avatar-15.png",
        "https://wen-jasonlee.oss-cn-shanghai.aliyuncs.com/defaults/avatars/user/user-avatar-16.png",
        "https://wen-jasonlee.oss-cn-shanghai.aliyuncs.com/defaults/avatars/user/user-avatar-17.png",
        "https://wen-jasonlee.oss-cn-shanghai.aliyuncs.com/defaults/avatars/user/user-avatar-18.png",
        "https://wen-jasonlee.oss-cn-shanghai.aliyuncs.com/defaults/avatars/user/user-avatar-19.png",
        "https://wen-jasonlee.oss-cn-shanghai.aliyuncs.com/defaults/avatars/user/user-avatar-20.png",
        "https://wen-jasonlee.oss-cn-shanghai.aliyuncs.com/defaults/avatars/user/user-avatar-21.png",
        "https://wen-jasonlee.oss-cn-shanghai.aliyuncs.com/defaults/avatars/user/user-avatar-22.png",
        "https://wen-jasonlee.oss-cn-shanghai.aliyuncs.com/defaults/avatars/user/user-avatar-23.png",
        "https://wen-jasonlee.oss-cn-shanghai.aliyuncs.com/defaults/avatars/user/user-avatar-24.png",
    ]
    private static let defaultGroupAvatarURLs: [String] = [
        "https://wen-jasonlee.oss-cn-shanghai.aliyuncs.com/defaults/avatars/group/group-avatar-01.png",
        "https://wen-jasonlee.oss-cn-shanghai.aliyuncs.com/defaults/avatars/group/group-avatar-02.png",
        "https://wen-jasonlee.oss-cn-shanghai.aliyuncs.com/defaults/avatars/group/group-avatar-03.png",
        "https://wen-jasonlee.oss-cn-shanghai.aliyuncs.com/defaults/avatars/group/group-avatar-04.png",
        "https://wen-jasonlee.oss-cn-shanghai.aliyuncs.com/defaults/avatars/group/group-avatar-05.png",
        "https://wen-jasonlee.oss-cn-shanghai.aliyuncs.com/defaults/avatars/group/group-avatar-06.png",
        "https://wen-jasonlee.oss-cn-shanghai.aliyuncs.com/defaults/avatars/group/group-avatar-07.png",
        "https://wen-jasonlee.oss-cn-shanghai.aliyuncs.com/defaults/avatars/group/group-avatar-08.png",
        "https://wen-jasonlee.oss-cn-shanghai.aliyuncs.com/defaults/avatars/group/group-avatar-09.png",
        "https://wen-jasonlee.oss-cn-shanghai.aliyuncs.com/defaults/avatars/group/group-avatar-10.png",
        "https://wen-jasonlee.oss-cn-shanghai.aliyuncs.com/defaults/avatars/group/group-avatar-11.png",
        "https://wen-jasonlee.oss-cn-shanghai.aliyuncs.com/defaults/avatars/group/group-avatar-12.png",
    ]
    private static let persistedRuntimeModeKey = "raver.persisted.runtimeMode"
    private static let persistedBFFBaseURLKey = "raver.persisted.bffBaseURL"
    private static let persistedRealNameEnforcementEnabledKey = "raver.persisted.realNameEnforcementEnabled"
    private static let persistedVirtualAssetsEnabledKey = "raver.persisted.virtualAssetsEnabled"
    private static let tencentIMAPNSBusinessIDInfoPlistKey = "TencentIMAPNSBusinessID"

    static var runtimeMode: AppRuntimeMode {
        if let envMode = runtimeModeFromEnvironmentValue(ProcessInfo.processInfo.environment["RAVER_USE_MOCK"]) {
            UserDefaults.standard.set(envMode.rawValue, forKey: persistedRuntimeModeKey)
            return envMode
        }

#if DEBUG
        if let persisted = UserDefaults.standard.string(forKey: persistedRuntimeModeKey),
           let mode = AppRuntimeMode(rawValue: persisted) {
            return mode
        }

        return .mock
#else
        return .live
#endif
    }

    static var bffBaseURL: URL {
        if let custom = normalizedBaseURLString(ProcessInfo.processInfo.environment["RAVER_BFF_BASE_URL"]),
           let url = URL(string: custom) {
#if DEBUG
            UserDefaults.standard.set(custom, forKey: persistedBFFBaseURLKey)
#endif
            return url
        }

#if DEBUG
        if let persisted = normalizedBaseURLString(UserDefaults.standard.string(forKey: persistedBFFBaseURLKey)),
           let url = URL(string: persisted) {
            return url
        }
        return URL(string: "http://localhost:8787")!
#else
        return URL(string: "https://api.raver.app")!
#endif
    }

    static var tencentIMAPNSBusinessID: Int {
        if let env = normalizedIntegerString(ProcessInfo.processInfo.environment["RAVER_TENCENT_IM_APNS_BUSINESS_ID"]),
           let value = Int(env),
           value > 0 {
            return value
        }

        if let plistValue = Bundle.main.object(forInfoDictionaryKey: tencentIMAPNSBusinessIDInfoPlistKey) as? NSNumber {
            let value = plistValue.intValue
            return value > 0 ? Int(value) : 0
        }

        if let plistString = Bundle.main.object(forInfoDictionaryKey: tencentIMAPNSBusinessIDInfoPlistKey) as? String,
           let value = Int(plistString.trimmingCharacters(in: .whitespacesAndNewlines)),
           value > 0 {
            return value
        }

        return 0
    }

    static var canOverrideRealNameEnforcement: Bool {
#if DEBUG
        true
#else
        false
#endif
    }

    static var isRealNameEnforcementEnabled: Bool {
#if DEBUG
        if let env = normalizedBool(ProcessInfo.processInfo.environment["RAVER_REAL_NAME_ENFORCEMENT_ENABLED"]) {
            UserDefaults.standard.set(env, forKey: persistedRealNameEnforcementEnabledKey)
            return env
        }

        if UserDefaults.standard.object(forKey: persistedRealNameEnforcementEnabledKey) != nil {
            return UserDefaults.standard.bool(forKey: persistedRealNameEnforcementEnabledKey)
        }

        return false
#else
        true
#endif
    }

    static func setRealNameEnforcementEnabled(_ isEnabled: Bool) {
#if DEBUG
        UserDefaults.standard.set(isEnabled, forKey: persistedRealNameEnforcementEnabledKey)
#endif
    }

    static var virtualAssetsEnabled: Bool {
        if let env = normalizedBool(ProcessInfo.processInfo.environment["RAVER_VIRTUAL_ASSETS_ENABLED"]) {
            UserDefaults.standard.set(env, forKey: persistedVirtualAssetsEnabledKey)
            return env
        }

        if UserDefaults.standard.object(forKey: persistedVirtualAssetsEnabledKey) != nil {
            return UserDefaults.standard.bool(forKey: persistedVirtualAssetsEnabledKey)
        }

        return true
    }

    static func setVirtualAssetsEnabled(_ isEnabled: Bool) {
#if DEBUG
        UserDefaults.standard.set(isEnabled, forKey: persistedVirtualAssetsEnabledKey)
#endif
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

    private static func normalizedIntegerString(_ raw: String?) -> String? {
        guard let raw else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return trimmed
    }

    private static func normalizedBool(_ raw: String?) -> Bool? {
        guard let raw else { return nil }
        let normalized = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalized.isEmpty else { return nil }

        switch normalized {
        case "1", "true", "yes", "on", "enabled":
            return true
        case "0", "false", "no", "off", "disabled":
            return false
        default:
            return nil
        }
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
        if let mappedDefaultAvatarURL = explicitDefaultAvatarURL(from: value) {
            return mappedDefaultAvatarURL
        }
        if value.hasPrefix("http://") || value.hasPrefix("https://") {
            return rewrittenShareAssetURLString(value) ?? httpsUpgradedOssURLString(value) ?? value
        }
        if value.hasPrefix("/") {
            let base = bffBaseURL.absoluteString.hasSuffix("/")
                ? String(bffBaseURL.absoluteString.dropLast())
                : bffBaseURL.absoluteString
            return "\(base)\(value)"
        }
        return value
    }

    private static func rewrittenShareAssetURLString(_ raw: String) -> String? {
        guard let remote = URLComponents(string: raw),
              let remoteHost = remote.host?.lowercased(),
              remote.scheme?.hasPrefix("http") == true else {
            return nil
        }

        guard remoteHost == "raver.app" || remoteHost == "www.raver.app" else {
            return nil
        }

        let path = remote.path.lowercased()
        let isShareAsset = path.hasPrefix("/qr/") || path.hasPrefix("/poster/") || path.hasPrefix("/s/")
        guard isShareAsset else { return nil }

        guard let local = localShareOriginURL(),
              let localHost = local.host?.lowercased(),
              localHost != remoteHost else {
            return nil
        }

        var rewritten = URLComponents()
        rewritten.scheme = local.scheme
        rewritten.host = local.host
        rewritten.port = local.port
        rewritten.path = remote.path
        rewritten.percentEncodedQuery = remote.percentEncodedQuery
        rewritten.fragment = remote.fragment
        return rewritten.string
    }

    private static func httpsUpgradedOssURLString(_ raw: String) -> String? {
        guard var components = URLComponents(string: raw),
              components.scheme?.lowercased() == "http",
              let host = components.host?.lowercased(),
              isLikelyOssImageHost(host) else {
            return nil
        }
        components.scheme = "https"
        return components.string
    }

    private static func localShareOriginURL() -> URL? {
        guard let components = URLComponents(url: bffBaseURL, resolvingAgainstBaseURL: false),
              let host = components.host?.trimmingCharacters(in: .whitespacesAndNewlines),
              !host.isEmpty else {
            return nil
        }

        var origin = URLComponents()
        origin.scheme = components.scheme
        origin.host = host
        origin.port = components.port
        return origin.url
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

    static func resolvedUserAvatarURLString(
        userID: String?,
        username: String?,
        avatarURL: String?
    ) -> String? {
        if let resolved = resolvedURLString(avatarURL),
           resolved.hasPrefix("http://") || resolved.hasPrefix("https://") {
            return resolved
        }
        let seed = userID ?? username ?? avatarURL ?? "user-default"
        return defaultAvatarURL(from: seed, pool: defaultUserAvatarURLs)
    }

    static func resolvedGroupAvatarURLString(
        groupID: String?,
        groupName: String?,
        avatarURL: String?
    ) -> String? {
        if let resolved = resolvedURLString(avatarURL),
           resolved.hasPrefix("http://") || resolved.hasPrefix("https://") {
            return resolved
        }
        let seed = groupID ?? groupName ?? avatarURL ?? "group-default"
        return defaultAvatarURL(from: seed, pool: defaultGroupAvatarURLs)
    }

    private static func explicitDefaultAvatarURL(from raw: String?) -> String? {
        guard let raw else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let localPrefixA = "local-avatar://"
        let localPrefixB = "local-avatar:"
        let token: String

        if trimmed.hasPrefix(localPrefixA) {
            token = String(trimmed.dropFirst(localPrefixA.count))
        } else if trimmed.hasPrefix(localPrefixB) {
            token = String(trimmed.dropFirst(localPrefixB.count))
        } else {
            return nil
        }

        if let userIndex = explicitAvatarIndex(token: token, prefix: "LocalUserAvatar"),
           defaultUserAvatarURLs.indices.contains(userIndex - 1) {
            return defaultUserAvatarURLs[userIndex - 1]
        }
        if let groupIndex = explicitAvatarIndex(token: token, prefix: "LocalGroupAvatar"),
           defaultGroupAvatarURLs.indices.contains(groupIndex - 1) {
            return defaultGroupAvatarURLs[groupIndex - 1]
        }
        return nil
    }

    private static func explicitAvatarIndex(token: String, prefix: String) -> Int? {
        guard token.hasPrefix(prefix) else { return nil }
        let suffix = String(token.dropFirst(prefix.count))
        guard let parsed = Int(suffix), parsed > 0 else { return nil }
        return parsed
    }

    private static func defaultAvatarURL(from seed: String, pool: [String]) -> String? {
        guard !pool.isEmpty else { return nil }
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
