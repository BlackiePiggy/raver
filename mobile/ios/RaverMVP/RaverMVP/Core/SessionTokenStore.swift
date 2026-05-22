import Foundation
import OSLog
import Security

final class SessionTokenStore {
    static let shared = SessionTokenStore()
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.raver.mvp",
        category: "SessionTokenStore"
    )

    private let service = "com.raver.auth.session"
    private let accessTokenAccount = "access_token"
    private let refreshTokenAccount = "refresh_token"
    private let accessTokenExpiresAtKey = "raver.auth.accessTokenExpiresAt"
    private let lock = NSLock()
    private var cachedToken: String?
    private var cachedRefreshToken: String?
    private var cachedAccessTokenExpiresAt: Date?

    private init() {
        cachedToken = read(account: accessTokenAccount)
        cachedRefreshToken = read(account: refreshTokenAccount)
        cachedAccessTokenExpiresAt = readAccessTokenExpiresAt()
    }

    var token: String? {
        get {
            lock.lock()
            defer { lock.unlock() }
            return cachedToken
        }
        set {
            lock.lock()
            cachedToken = newValue
            lock.unlock()
            persist(account: accessTokenAccount, value: newValue)
        }
    }

    var refreshToken: String? {
        get {
            lock.lock()
            defer { lock.unlock() }
            return cachedRefreshToken
        }
        set {
            lock.lock()
            cachedRefreshToken = newValue
            lock.unlock()
            persist(account: refreshTokenAccount, value: newValue)
        }
    }

    var accessTokenExpiresAt: Date? {
        get {
            lock.lock()
            defer { lock.unlock() }
            return cachedAccessTokenExpiresAt
        }
        set {
            lock.lock()
            cachedAccessTokenExpiresAt = newValue
            lock.unlock()
            persistAccessTokenExpiresAt(newValue)
        }
    }

    func storeSessionTokens(accessToken: String, refreshToken: String?, accessTokenExpiresIn: Int?) {
        // Persist refresh token first so a rotated token is not lost while the app is still running.
        self.refreshToken = refreshToken
        token = accessToken
        recordAccessTokenIssued(expiresIn: accessTokenExpiresIn)
    }

    func markRecoverablePersistenceIssue(_ message: String) {
        Self.logger.error("[AuthSession] keychain persistence issue: \(message, privacy: .public)")
    }

    func recordAccessTokenIssued(expiresIn seconds: Int?, now: Date = Date()) {
        guard let seconds, seconds > 0 else {
            accessTokenExpiresAt = nil
            return
        }
        accessTokenExpiresAt = now.addingTimeInterval(TimeInterval(seconds))
    }

    func clear() {
        lock.lock()
        cachedToken = nil
        cachedRefreshToken = nil
        cachedAccessTokenExpiresAt = nil
        lock.unlock()
        persist(account: accessTokenAccount, value: nil)
        persist(account: refreshTokenAccount, value: nil)
        persistAccessTokenExpiresAt(nil)
    }

    private func readAccessTokenExpiresAt() -> Date? {
        let timestamp = UserDefaults.standard.double(forKey: accessTokenExpiresAtKey)
        guard timestamp > 0 else { return nil }
        return Date(timeIntervalSince1970: timestamp)
    }

    private func persistAccessTokenExpiresAt(_ value: Date?) {
        let defaults = UserDefaults.standard
        if let value {
            defaults.set(value.timeIntervalSince1970, forKey: accessTokenExpiresAtKey)
        } else {
            defaults.removeObject(forKey: accessTokenExpiresAtKey)
        }
    }

    private func persist(account: String, value: String?) {
        do {
            try write(account: account, value: value)
        } catch {
            Self.logger.error("[AuthSession] keychain write failed account=\(account, privacy: .public) error=\(error.localizedDescription, privacy: .public)")
        }
    }

    private func baseQuery(account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }

    private func read(account: String) -> String? {
        var query = baseQuery(account: account)
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        query[kSecReturnData as String] = kCFBooleanTrue

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess else {
            return nil
        }
        guard let data = item as? Data else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    private func write(account: String, value: String?) throws {
        let query = baseQuery(account: account)
        guard let value else {
            let deleteStatus = SecItemDelete(query as CFDictionary)
            if deleteStatus != errSecSuccess && deleteStatus != errSecItemNotFound {
                throw NSError(
                    domain: NSOSStatusErrorDomain,
                    code: Int(deleteStatus),
                    userInfo: [NSLocalizedDescriptionKey: "SecItemDelete failed with status \(deleteStatus)"]
                )
            }
            return
        }

        let data = Data(value.utf8)
        let status = SecItemCopyMatching(query as CFDictionary, nil)
        if status == errSecSuccess {
            let attributes: [String: Any] = [
                kSecValueData as String: data,
            ]
            let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
            guard updateStatus == errSecSuccess else {
                throw NSError(
                    domain: NSOSStatusErrorDomain,
                    code: Int(updateStatus),
                    userInfo: [NSLocalizedDescriptionKey: "SecItemUpdate failed with status \(updateStatus)"]
                )
            }
            return
        }

        if status != errSecItemNotFound {
            throw NSError(
                domain: NSOSStatusErrorDomain,
                code: Int(status),
                userInfo: [NSLocalizedDescriptionKey: "SecItemCopyMatching failed with status \(status)"]
            )
        }

        var insertQuery = query
        insertQuery[kSecValueData as String] = data
        insertQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        let addStatus = SecItemAdd(insertQuery as CFDictionary, nil)
        guard addStatus == errSecSuccess else {
            throw NSError(
                domain: NSOSStatusErrorDomain,
                code: Int(addStatus),
                userInfo: [NSLocalizedDescriptionKey: "SecItemAdd failed with status \(addStatus)"]
            )
        }
    }
}
