import Foundation

final class SessionTokenStore {
    static let shared = SessionTokenStore()

    private init() {}

    var token: String?
}
