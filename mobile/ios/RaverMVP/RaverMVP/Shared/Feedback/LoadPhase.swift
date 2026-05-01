import Foundation

enum LoadPhase: Equatable {
    case idle
    case initialLoading
    case success
    case empty
    case failure(message: String)
    case offline(message: String)

    var message: String? {
        switch self {
        case .failure(let message), .offline(let message):
            return message
        case .idle, .initialLoading, .success, .empty:
            return nil
        }
    }

    var isBlocking: Bool {
        switch self {
        case .idle, .initialLoading:
            return true
        case .success, .empty, .failure, .offline:
            return false
        }
    }
}
