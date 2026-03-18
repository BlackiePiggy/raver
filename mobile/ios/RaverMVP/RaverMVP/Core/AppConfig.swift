import Foundation

enum AppRuntimeMode: String {
    case mock
    case live
}

enum AppConfig {
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
}
