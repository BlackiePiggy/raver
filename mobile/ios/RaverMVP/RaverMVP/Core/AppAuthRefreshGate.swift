import Foundation

actor AppAuthRefreshGate {
    static let shared = AppAuthRefreshGate()

    private var inFlightTask: Task<Session, Error>?

    func run(_ operation: @escaping () async throws -> Session) async throws -> Session {
        if let inFlightTask {
            return try await inFlightTask.value
        }

        let task = Task { try await operation() }
        inFlightTask = task
        defer { inFlightTask = nil }
        return try await task.value
    }
}
