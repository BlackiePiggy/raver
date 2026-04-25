import Foundation
import Security

final class SessionTokenStore {
    static let shared = SessionTokenStore()

    private let service = "com.raver.auth.session"
    private let accessTokenAccount = "access_token"
    private let refreshTokenAccount = "refresh_token"

    private init() {}

    var token: String? {
        get { read(account: accessTokenAccount) }
        set { write(account: accessTokenAccount, value: newValue) }
    }

    var refreshToken: String? {
        get { read(account: refreshTokenAccount) }
        set { write(account: refreshTokenAccount, value: newValue) }
    }

    func clear() {
        token = nil
        refreshToken = nil
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

    private func write(account: String, value: String?) {
        let query = baseQuery(account: account)
        guard let value else {
            SecItemDelete(query as CFDictionary)
            return
        }

        let data = Data(value.utf8)
        let status = SecItemCopyMatching(query as CFDictionary, nil)
        if status == errSecSuccess {
            let attributes: [String: Any] = [
                kSecValueData as String: data,
            ]
            SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
            return
        }

        var insertQuery = query
        insertQuery[kSecValueData as String] = data
        insertQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        SecItemAdd(insertQuery as CFDictionary, nil)
    }
}
