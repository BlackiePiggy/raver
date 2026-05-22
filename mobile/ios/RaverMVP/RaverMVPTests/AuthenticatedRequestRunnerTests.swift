import XCTest
@testable import RaverMVP

final class AuthenticatedRequestRunnerTests: XCTestCase {
    override func tearDown() async throws {
        await MockHTTPHandler.shared.reset()
        try await super.tearDown()
    }

    func testExecuteReturnsSuccessfulResponseWithoutRefresh() async throws {
        await MockHTTPHandler.shared.setHandler { request in
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer old-token")
            return Self.response(statusCode: 200, body: #"{"ok":true}"#)
        }

        let runner = makeRunner(refreshSession: {
            XCTFail("refresh should not run for a successful request")
            return Self.session(token: "new-token")
        })

        let (data, response) = try await runner.execute(
            request: Self.request(accessToken: "old-token"),
            path: "/v1/events/test",
            allowAuthRetry: true,
            includeAccessToken: true,
            postSessionExpiredOnUnauthorized: true
        )

        XCTAssertEqual(response.statusCode, 200)
        XCTAssertEqual(String(data: data, encoding: .utf8), #"{"ok":true}"#)
    }

    func testUnauthorizedRefreshesAndRetriesOnce() async throws {
        let requestCount = LockedBox(0)
        let refreshCount = LockedBox(0)
        await MockHTTPHandler.shared.setHandler { request in
            let count = requestCount.increment()
            if count == 1 {
                XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer old-token")
                return Self.response(statusCode: 401, body: #"{"code":"AUTH_ACCESS_TOKEN_EXPIRED"}"#)
            }

            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer new-token")
            return Self.response(statusCode: 200, body: #"{"ok":true}"#)
        }

        let runner = makeRunner(refreshSession: {
            refreshCount.increment()
            return Self.session(token: "new-token")
        })

        let (_, response) = try await runner.execute(
            request: Self.request(accessToken: "old-token"),
            path: "/v1/events/test",
            allowAuthRetry: true,
            includeAccessToken: true,
            postSessionExpiredOnUnauthorized: true
        )

        XCTAssertEqual(response.statusCode, 200)
        XCTAssertEqual(requestCount.value, 2)
        XCTAssertEqual(refreshCount.value, 1)
    }

    func testRecoverableRefreshTransportFailureDoesNotExpireSession() async throws {
        await MockHTTPHandler.shared.setHandler { _ in
            Self.response(statusCode: 401, body: #"{"code":"AUTH_ACCESS_TOKEN_EXPIRED"}"#)
        }

        let expiredReasons = LockedBox<[SessionExpirationReason]>([])
        let runner = makeRunner(
            refreshSession: {
                throw URLError(.notConnectedToInternet)
            },
            handleSessionExpired: { reason in
                expiredReasons.mutate { $0.append(reason) }
            }
        )

        do {
            _ = try await runner.execute(
                request: Self.request(accessToken: "old-token"),
                path: "/v1/events/test",
                allowAuthRetry: true,
                includeAccessToken: true,
                postSessionExpiredOnUnauthorized: true
            )
            XCTFail("request should throw the recoverable transport error")
        } catch let error as URLError {
            XCTAssertEqual(error.code, .notConnectedToInternet)
        }

        XCTAssertTrue(expiredReasons.value.isEmpty)
    }

    func testAccountInactiveExitsWithoutRefresh() async throws {
        await MockHTTPHandler.shared.setHandler { _ in
            Self.response(statusCode: 401, body: #"{"code":"AUTH_ACCOUNT_INACTIVE"}"#)
        }

        let accountInactiveCount = LockedBox(0)
        let runner = makeRunner(
            refreshSession: {
                XCTFail("refresh should not run for account inactive")
                return Self.session(token: "new-token")
            },
            handleAccountInactive: { notify in
                XCTAssertTrue(notify)
                accountInactiveCount.increment()
            }
        )

        do {
            _ = try await runner.execute(
                request: Self.request(accessToken: "old-token"),
                path: "/v1/events/test",
                allowAuthRetry: true,
                includeAccessToken: true,
                postSessionExpiredOnUnauthorized: true
            )
            XCTFail("request should throw accountInactive")
        } catch ServiceError.accountInactive {
            XCTAssertEqual(accountInactiveCount.value, 1)
        }
    }

    func testConcurrentUnauthorizedRequestsShareOneRefresh() async throws {
        let refreshCount = LockedBox(0)
        await MockHTTPHandler.shared.setHandler { request in
            if request.value(forHTTPHeaderField: "Authorization") == "Bearer new-token" {
                return Self.response(statusCode: 200, body: #"{"ok":true}"#)
            }
            return Self.response(statusCode: 401, body: #"{"code":"AUTH_ACCESS_TOKEN_EXPIRED"}"#)
        }

        let gate = AppAuthRefreshGate()
        let runner = makeRunner(
            refreshGate: gate,
            refreshSession: {
                refreshCount.increment()
                try await Task.sleep(nanoseconds: 50_000_000)
                return Self.session(token: "new-token")
            }
        )

        try await withThrowingTaskGroup(of: Int.self) { group in
            for _ in 0..<10 {
                group.addTask {
                    let (_, response) = try await runner.execute(
                        request: Self.request(accessToken: "old-token"),
                        path: "/v1/events/test",
                        allowAuthRetry: true,
                        includeAccessToken: true,
                        postSessionExpiredOnUnauthorized: true
                    )
                    return response.statusCode
                }
            }

            for try await statusCode in group {
                XCTAssertEqual(statusCode, 200)
            }
        }

        XCTAssertEqual(refreshCount.value, 1)
    }

    private static func request(accessToken: String) -> URLRequest {
        var request = URLRequest(url: URL(string: "https://example.test/v1/events/test")!)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        return request
    }

    private static func response(statusCode: Int, body: String) -> (Data, URLResponse) {
        let url = URL(string: "https://example.test/v1/events/test")!
        let response = HTTPURLResponse(
            url: url,
            statusCode: statusCode,
            httpVersion: nil,
            headerFields: ["Content-Type": "application/json"]
        )!
        return (Data(body.utf8), response)
    }

    private static func session(token: String) -> Session {
        Session(
            token: token,
            refreshToken: "refresh-token",
            accessTokenExpiresIn: 900,
            user: UserSummary(
                id: "user-1",
                username: "tester",
                displayName: "Tester",
                avatarURL: nil,
                isFollowing: false
            )
        )
    }

    private func makeRunner(
        refreshGate: AppAuthRefreshGate = AppAuthRefreshGate(),
        refreshSession: @escaping () async throws -> Session,
        handleAccountInactive: @escaping (Bool) -> Void = { _ in },
        handleSessionExpired: @escaping (SessionExpirationReason) -> Void = { _ in }
    ) -> AuthenticatedRequestRunner {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]

        return AuthenticatedRequestRunner(
            session: URLSession(configuration: configuration),
            refreshGate: refreshGate,
            refreshSession: refreshSession,
            sessionExpirationReasonFromData: Self.reason(from:),
            sessionExpirationReasonFromError: { _ in .unknown },
            handleAccountInactive: handleAccountInactive,
            handleSessionExpired: handleSessionExpired
        )
    }

    private static func reason(from data: Data) -> SessionExpirationReason {
        let payload = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
        switch payload?["code"] as? String {
        case "AUTH_ACCOUNT_INACTIVE":
            return .accountInactive
        case "AUTH_SESSION_REVOKED":
            return .revoked
        default:
            return .expired
        }
    }
}

private final class MockURLProtocol: URLProtocol {
    override class func canInit(with request: URLRequest) -> Bool { true }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        Task {
            do {
                let (data, response) = try await MockHTTPHandler.shared.handle(request)
                client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
                client?.urlProtocol(self, didLoad: data)
                client?.urlProtocolDidFinishLoading(self)
            } catch {
                client?.urlProtocol(self, didFailWithError: error)
            }
        }
    }

    override func stopLoading() {}
}

private actor MockHTTPHandler {
    static let shared = MockHTTPHandler()

    private var handler: ((URLRequest) async throws -> (Data, URLResponse))?

    func setHandler(_ handler: @escaping (URLRequest) async throws -> (Data, URLResponse)) {
        self.handler = handler
    }

    func handle(_ request: URLRequest) async throws -> (Data, URLResponse) {
        guard let handler else {
            throw URLError(.badServerResponse)
        }
        return try await handler(request)
    }

    func reset() {
        handler = nil
    }
}

private final class LockedBox<Value> {
    private let lock = NSLock()
    private var storage: Value

    init(_ value: Value) {
        storage = value
    }

    var value: Value {
        lock.lock()
        defer { lock.unlock() }
        return storage
    }

    @discardableResult
    func increment() -> Int where Value == Int {
        lock.lock()
        defer { lock.unlock() }
        storage += 1
        return storage
    }

    func mutate(_ update: (inout Value) -> Void) {
        lock.lock()
        update(&storage)
        lock.unlock()
    }
}
