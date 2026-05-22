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
            AuthSessionBreadcrumbStore.shared.record(
                "request.unauthorized.account_inactive",
                path: path,
                statusCode: http.statusCode,
                reason: .accountInactive
            )
            handleAccountInactive(postSessionExpiredOnUnauthorized)
            throw ServiceError.accountInactive
        }

        if http.statusCode == 401,
           allowAuthRetry,
           includeAccessToken,
           path != "/v1/auth/refresh" {
            AuthSessionBreadcrumbStore.shared.record(
                "request.unauthorized.refresh_start",
                path: path,
                statusCode: http.statusCode,
                reason: sessionExpirationReasonFromData(data)
            )
            do {
                let refreshed = try await refreshGate.run {
                    try await refreshSession()
                }
                AuthSessionBreadcrumbStore.shared.record("request.unauthorized.refresh_success", path: path)
                request.setValue("Bearer \(refreshed.token)", forHTTPHeaderField: "Authorization")
                (data, http) = try await performRequest(request)
                AuthSessionBreadcrumbStore.shared.record(
                    "request.retry.completed",
                    path: path,
                    statusCode: http.statusCode,
                    reason: http.statusCode == 401 ? sessionExpirationReasonFromData(data) : nil
                )
                if http.statusCode == 401,
                   sessionExpirationReasonFromData(data) == .accountInactive {
                    AuthSessionBreadcrumbStore.shared.record(
                        "request.retry.account_inactive",
                        path: path,
                        statusCode: http.statusCode,
                        reason: .accountInactive
                    )
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
                    AuthSessionBreadcrumbStore.shared.record(
                        "request.refresh.recoverable_failure",
                        path: path,
                        error: error
                    )
                    throw error
                }
                let reason = sessionExpirationReasonFromError(error)
                AuthSessionBreadcrumbStore.shared.record(
                    "request.refresh.hard_failure",
                    path: path,
                    reason: reason,
                    error: error
                )
                if postSessionExpiredOnUnauthorized {
                    handleSessionExpired(reason)
                }
                throw ServiceError.sessionExpired(reason)
            }
        }

        if http.statusCode == 401 {
            let reason = sessionExpirationReasonFromData(data)
            AuthSessionBreadcrumbStore.shared.record(
                "request.unauthorized.final",
                path: path,
                statusCode: http.statusCode,
                reason: reason
            )
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
