import Foundation

struct AuthenticatedRequestRunner {
    let session: URLSession
    let refreshGate: AppAuthRefreshGate
    let refreshSession: () async throws -> Session
    let sessionExpirationReasonFromData: (Data) -> SessionExpirationReason
    let sessionExpirationReasonFromError: (Error) -> SessionExpirationReason
    let handleAccountInactive: (_ notify: Bool) -> Void
    let handleSessionExpired: (SessionExpirationReason) -> Void

    func execute(
        request: URLRequest,
        path: String,
        allowAuthRetry: Bool,
        includeAccessToken: Bool,
        postSessionExpiredOnUnauthorized: Bool
    ) async throws -> (Data, HTTPURLResponse) {
        var request = request
        var (data, http) = try await performRequest(request)

        if http.statusCode == 401,
           sessionExpirationReasonFromData(data) == .accountInactive {
            handleAccountInactive(postSessionExpiredOnUnauthorized)
            throw ServiceError.accountInactive
        }

        if http.statusCode == 401,
           allowAuthRetry,
           includeAccessToken,
           path != "/v1/auth/refresh" {
            do {
                let refreshed = try await refreshGate.run {
                    try await refreshSession()
                }
                request.setValue("Bearer \(refreshed.token)", forHTTPHeaderField: "Authorization")
                (data, http) = try await performRequest(request)
                if http.statusCode == 401,
                   sessionExpirationReasonFromData(data) == .accountInactive {
                    handleAccountInactive(postSessionExpiredOnUnauthorized)
                    throw ServiceError.accountInactive
                }
            } catch {
                if case ServiceError.accountInactive = error {
                    throw error
                }
                if case ServiceError.sessionExpired = error {
                    throw error
                }
                if error.isRecoverableAuthTransportFailure {
                    throw error
                }
                let reason = sessionExpirationReasonFromError(error)
                if postSessionExpiredOnUnauthorized {
                    handleSessionExpired(reason)
                }
                throw ServiceError.sessionExpired(reason)
            }
        }

        if http.statusCode == 401 {
            let reason = sessionExpirationReasonFromData(data)
            if postSessionExpiredOnUnauthorized {
                handleSessionExpired(reason)
            }
            throw ServiceError.sessionExpired(reason)
        }

        return (data, http)
    }

    private func performRequest(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw ServiceError.invalidResponse
        }
        return (data, http)
    }
}
