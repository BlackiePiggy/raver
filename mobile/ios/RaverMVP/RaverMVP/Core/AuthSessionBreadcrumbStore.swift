import Foundation
import OSLog

struct AuthSessionBreadcrumb: Codable, Identifiable, Equatable {
    let id: UUID
    let occurredAt: Date
    let event: String
    let source: String?
    let path: String?
    let statusCode: Int?
    let reason: String?
    let errorClass: String?
    let metadata: [String: String]
}

final class AuthSessionBreadcrumbStore {
    static let shared = AuthSessionBreadcrumbStore()

    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.raver.mvp",
        category: "AuthSessionBreadcrumb"
    )
    private static let storageKey = "raver.auth.session.breadcrumbs.v1"
    private static let maxEntries = 120

    private let queue = DispatchQueue(label: "com.raver.auth.breadcrumb-store")
    private let defaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }

    func record(
        _ event: String,
        source: String? = nil,
        path: String? = nil,
        statusCode: Int? = nil,
        reason: SessionExpirationReason? = nil,
        error: Error? = nil,
        metadata: [String: String] = [:]
    ) {
        let breadcrumb = AuthSessionBreadcrumb(
            id: UUID(),
            occurredAt: Date(),
            event: sanitized(event, maxLength: 80) ?? "unknown",
            source: sanitized(source, maxLength: 80),
            path: sanitizedPath(path),
            statusCode: statusCode,
            reason: reason?.rawValue,
            errorClass: error.map { String(describing: type(of: $0)) },
            metadata: sanitizedMetadata(metadata)
        )

        queue.async {
            var items = self.loadUnlocked()
            items.append(breadcrumb)
            if items.count > Self.maxEntries {
                items.removeFirst(items.count - Self.maxEntries)
            }
            self.saveUnlocked(items)
            Self.logger.info("[AuthSession] breadcrumb event=\(breadcrumb.event, privacy: .public) source=\(breadcrumb.source ?? "nil", privacy: .public) path=\(breadcrumb.path ?? "nil", privacy: .public) status=\(breadcrumb.statusCode ?? 0, privacy: .public) reason=\(breadcrumb.reason ?? "nil", privacy: .public)")
        }
    }

    func recent(limit: Int = 50) -> [AuthSessionBreadcrumb] {
        queue.sync {
            Array(loadUnlocked().suffix(max(1, min(limit, Self.maxEntries))).reversed())
        }
    }

    func clear() {
        queue.async {
            self.defaults.removeObject(forKey: Self.storageKey)
        }
    }

    private func loadUnlocked() -> [AuthSessionBreadcrumb] {
        guard let data = defaults.data(forKey: Self.storageKey),
              let items = try? decoder.decode([AuthSessionBreadcrumb].self, from: data) else {
            return []
        }
        return items
    }

    private func saveUnlocked(_ items: [AuthSessionBreadcrumb]) {
        guard let data = try? encoder.encode(items) else { return }
        defaults.set(data, forKey: Self.storageKey)
    }

    private func sanitizedMetadata(_ metadata: [String: String]) -> [String: String] {
        let blockedKeys = ["authorization", "token", "refreshToken", "accessToken", "password", "email", "phone", "idToken"]
        var next: [String: String] = [:]
        for (key, value) in metadata {
            let normalizedKey = key.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !normalizedKey.isEmpty else { continue }
            if blockedKeys.contains(where: { normalizedKey.localizedCaseInsensitiveContains($0) }) {
                continue
            }
            next[sanitized(normalizedKey, maxLength: 64) ?? normalizedKey] = sanitized(value, maxLength: 160) ?? ""
            if next.count >= 12 { break }
        }
        return next
    }

    private func sanitizedPath(_ value: String?) -> String? {
        guard let value = sanitized(value, maxLength: 200), !value.isEmpty else { return nil }
        guard let questionMark = value.firstIndex(of: "?") else { return value }
        return String(value[..<questionMark])
    }

    private func sanitized(_ value: String?, maxLength: Int) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return String(trimmed.prefix(maxLength))
    }
}
