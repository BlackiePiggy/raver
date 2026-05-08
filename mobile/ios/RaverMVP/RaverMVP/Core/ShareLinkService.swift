import Foundation
import UIKit

enum ShareTargetType: String, Codable, Hashable {
    case userCard = "user_card"
    case squadCard = "squad_card"
    case squadInvite = "squad_invite"
    case post = "post"
    case event = "event"
    case news = "news"
    case dj = "dj"
    case set = "set"
    case label = "label"
    case festival = "festival"
    case rankingBoard = "ranking_board"
    case circleID = "circle_id"
    case ratingEvent = "rating_event"
    case ratingUnit = "rating_unit"
}

struct ShareTarget: Codable, Hashable {
    let type: ShareTargetType
    let id: String
    let title: String?
    let subtitle: String?
    let imageURL: String?
    let metadata: [String: String]
    let canonicalURL: String?
    let deepLink: String?
    let fallbackURL: String?
    let previewType: String?
    let visibility: String?

    init(
        type: ShareTargetType,
        id: String,
        title: String? = nil,
        subtitle: String? = nil,
        imageURL: String? = nil,
        metadata: [String: String] = [:],
        canonicalURL: String? = nil,
        deepLink: String? = nil,
        fallbackURL: String? = nil,
        previewType: String? = nil,
        visibility: String? = nil
    ) {
        self.type = type
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.imageURL = imageURL
        self.metadata = metadata
        self.canonicalURL = canonicalURL
        self.deepLink = deepLink
        self.fallbackURL = fallbackURL
        self.previewType = previewType
        self.visibility = visibility
    }
}

private struct ShareTargetSeedRequest: Encodable {
    let canonicalUrl: String?
    let deepLink: String?
    let fallbackUrl: String?
    let title: String?
    let subtitle: String?
    let imageUrl: String?
    let previewType: String?
    let visibility: String?
}

struct ShareLinkPayload: Codable, Hashable {
    let code: String
    let shortURL: String
    let canonicalURL: String
    let deepLink: String
    let fallbackURL: String
    let qrCodeURL: String
    let posterURL: String?
    let title: String
    let subtitle: String?
    let imageURL: String?
    let previewType: String
    let status: String

    enum CodingKeys: String, CodingKey {
        case code
        case shortURL = "shortUrl"
        case canonicalURL = "canonicalUrl"
        case deepLink
        case fallbackURL = "fallbackUrl"
        case qrCodeURL = "qrCodeUrl"
        case posterURL = "posterUrl"
        case title
        case subtitle
        case imageURL = "imageUrl"
        case previewType
        case status
    }
}

protocol ShareLinkService {
    func resolve(
        target: ShareTarget,
        channel: String,
        campaign: String?,
        preferPermanent: Bool,
        expiresInHours: Int?,
        maxUses: Int?
    ) async throws -> ShareLinkPayload

    func getLink(code: String) async throws -> ShareLinkPayload

    func recordEvent(
        code: String,
        eventType: String,
        channel: String,
        anonymousId: String?,
        metadata: [String: String]?
    ) async throws
}

private struct ShareLinkEventResponse: Decodable {
    let code: String
}

struct UniversalLinkRouter {
    let service: ShareLinkService
    var allowedHosts: Set<String> = ["raver.app", "www.raver.app"]

    func resolve(_ url: URL) async -> String? {
        guard let scheme = url.scheme?.lowercased() else { return nil }
        if scheme == "raver" {
            return url.absoluteString
        }

        guard (scheme == "https" || scheme == "http"),
              let host = url.host?.lowercased(),
              allowedHosts.contains(host) else {
            return nil
        }

        let pathParts = url.pathComponents.filter { $0 != "/" && !$0.isEmpty }
        guard let first = pathParts.first?.lowercased() else { return nil }

        if first == "s", pathParts.count >= 2 {
            let code = pathParts[1]
            guard let payload = try? await service.getLink(code: code) else { return nil }
            try? await service.recordEvent(
                code: payload.code,
                eventType: "app_open",
                channel: "universal_link",
                anonymousId: nil,
                metadata: [
                    "source": "universal-link",
                    "incomingURL": url.absoluteString
                ]
            )
            return appendShareCode(to: payload.deepLink, code: payload.code)
        }

        return canonicalDeepLink(pathParts: pathParts, query: url.query)
    }

    private func canonicalDeepLink(pathParts: [String], query: String?) -> String? {
        guard pathParts.count >= 2 else { return nil }
        let kind = pathParts[0].lowercased()
        let id = pathParts[1]
        let base: String?

        switch kind {
        case "p", "posts":
            base = "raver://community/post/\(id)"
        case "e", "event", "events":
            base = "raver://event/\(id)"
        case "n", "news":
            base = "raver://news/\(id)"
        case "dj", "djs":
            base = "raver://dj/\(id)"
        case "set", "sets":
            base = "raver://set/\(id)"
        case "label", "labels":
            base = "raver://label/\(id)"
        case "festival", "festivals":
            base = "raver://festival/\(id)"
        case "ranking-board", "rankings":
            base = "raver://ranking-board/\(id)"
        case "rating-event", "rating-events":
            base = "raver://circle/rating-event/\(id)"
        case "rating-unit", "rating-units":
            base = "raver://rating-unit/\(id)"
        case "u", "user", "profile":
            base = "raver://profile/\(id)"
        case "g", "squad", "squads":
            base = "raver://squad/\(id)"
        case "circle":
            if pathParts.count >= 3, pathParts[1].lowercased() == "id" {
                base = "raver://circle/id/\(pathParts[2])"
            } else if pathParts.count >= 3, pathParts[1].lowercased() == "rating-event" {
                base = "raver://circle/rating-event/\(pathParts[2])"
            } else {
                base = nil
            }
        default:
            base = nil
        }

        guard let base else { return nil }
        if let query, !query.isEmpty {
            return "\(base)?\(query)"
        }
        return base
    }

    private func appendShareCode(to value: String, code: String) -> String {
        guard var components = URLComponents(string: value) else {
            let separator = value.contains("?") ? "&" : "?"
            return "\(value)\(separator)shareCode=\(code)"
        }
        var queryItems = components.queryItems ?? []
        if !queryItems.contains(where: { $0.name == "shareCode" }) {
            queryItems.append(URLQueryItem(name: "shareCode", value: code))
        }
        components.queryItems = queryItems
        return components.string ?? value
    }
}

final class LiveShareLinkService: ShareLinkService {
    private let baseURL: URL
    private let session: URLSession

    init(baseURL: URL, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
    }

    func resolve(
        target: ShareTarget,
        channel: String = "copy_link",
        campaign: String? = nil,
        preferPermanent: Bool = true,
        expiresInHours: Int? = nil,
        maxUses: Int? = nil
    ) async throws -> ShareLinkPayload {
        let body = ShareLinkResolveRequest(
            targetType: target.type.rawValue,
            targetId: target.id,
            channel: channel,
            campaign: campaign,
            preferPermanent: preferPermanent,
            expiresInHours: expiresInHours,
            maxUses: maxUses,
            targetSeed: ShareTargetSeedRequest(
                canonicalUrl: target.canonicalURL,
                deepLink: target.deepLink,
                fallbackUrl: target.fallbackURL,
                title: target.title,
                subtitle: target.subtitle,
                imageUrl: target.imageURL,
                previewType: target.previewType,
                visibility: target.visibility
            )
        )
        return try await request(
            path: "/v1/share-links/resolve",
            method: "POST",
            body: body
        )
    }

    func getLink(code: String) async throws -> ShareLinkPayload {
        try await request(
            path: "/v1/share-links/\(code)",
            method: "GET"
        )
    }

    func recordEvent(
        code: String,
        eventType: String,
        channel: String,
        anonymousId: String? = nil,
        metadata: [String: String]? = nil
    ) async throws {
        let _: ShareLinkEventResponse = try await request(
            path: "/v1/share-links/\(code)/events",
            method: "POST",
            body: ShareLinkEventRequest(
                eventType: eventType,
                channel: channel,
                anonymousId: anonymousId,
                platform: "iOS",
                metadata: metadata
            )
        )
    }

    private func request<T: Decodable>(
        path: String,
        method: String,
        body: Encodable? = nil
    ) async throws -> T {
        guard let url = URL(string: path, relativeTo: baseURL) else {
            throw ServiceError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = 15
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let token = SessionTokenStore.shared.token, !token.isEmpty {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        if let body {
            request.httpBody = try JSONEncoder().encode(AnyEncodable(body))
        }

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw ServiceError.invalidResponse
        }

        if (200..<300).contains(http.statusCode) {
            do {
                return try JSONDecoder().decode(T.self, from: data)
            } catch {
                throw ServiceError.invalidResponse
            }
        }

        if http.statusCode == 401 {
            throw ServiceError.unauthorized
        }

        if let serverError = try? JSONDecoder().decode(ShareLinkServerError.self, from: data) {
            throw ServiceError.message(serverError.message ?? serverError.error)
        }

        throw ServiceError.message(HTTPURLResponse.localizedString(forStatusCode: http.statusCode))
    }
}

final class MockShareLinkService: ShareLinkService {
    func resolve(
        target: ShareTarget,
        channel: String,
        campaign: String?,
        preferPermanent: Bool,
        expiresInHours: Int?,
        maxUses: Int?
    ) async throws -> ShareLinkPayload {
        _ = channel
        _ = campaign
        _ = preferPermanent
        _ = expiresInHours
        _ = maxUses
        let short = "https://raver.app/s/mock-\(target.type.rawValue)-\(target.id)"
        return ShareLinkPayload(
            code: "mock-\(target.id)",
            shortURL: short,
            canonicalURL: ShareLinkCoordinator.canonicalFallback(for: target),
            deepLink: ShareLinkCoordinator.deepLinkFallback(for: target),
            fallbackURL: ShareLinkCoordinator.canonicalFallback(for: target),
            qrCodeURL: "https://raver.app/qr/mock-\(target.id).png",
            posterURL: nil,
            title: target.title ?? "Raver Share",
            subtitle: target.subtitle,
            imageURL: target.imageURL,
            previewType: "content_card",
            status: "active"
        )
    }

    func getLink(code: String) async throws -> ShareLinkPayload {
        let normalizedCode = code.trimmingCharacters(in: .whitespacesAndNewlines)
        let targetId = normalizedCode
            .replacingOccurrences(of: "mock-", with: "")
            .split(separator: "-")
            .last
            .map(String.init) ?? normalizedCode
        let target = ShareTarget(type: .post, id: targetId, title: "Raver Share")
        return ShareLinkPayload(
            code: normalizedCode,
            shortURL: "https://raver.app/s/\(normalizedCode)",
            canonicalURL: ShareLinkCoordinator.canonicalFallback(for: target),
            deepLink: ShareLinkCoordinator.deepLinkFallback(for: target),
            fallbackURL: ShareLinkCoordinator.canonicalFallback(for: target),
            qrCodeURL: "https://raver.app/qr/\(normalizedCode).png",
            posterURL: nil,
            title: target.title ?? "Raver Share",
            subtitle: target.subtitle,
            imageURL: target.imageURL,
            previewType: "content_card",
            status: "active"
        )
    }

    func recordEvent(
        code: String,
        eventType: String,
        channel: String,
        anonymousId: String?,
        metadata: [String: String]?
    ) async throws {
        _ = code
        _ = eventType
        _ = channel
        _ = anonymousId
        _ = metadata
    }
}

struct ShareCopyResult: Hashable {
    let copiedText: String
    let usedCanonicalFallback: Bool
    let usedDeepLinkFallback: Bool
}

struct ShareResolvedResult: Hashable {
    let payload: ShareLinkPayload
    let usedFallbackPayload: Bool
}

struct ShareLinkCoordinator {
    let service: ShareLinkService

    func resolveLink(
        target: ShareTarget,
        channel: String = "copy_link",
        campaign: String? = nil,
        preferPermanent: Bool = true,
        expiresInHours: Int? = nil,
        maxUses: Int? = nil
    ) async throws -> ShareResolvedResult {
        do {
            let payload = try await service.resolve(
                target: target,
                channel: channel,
                campaign: campaign,
                preferPermanent: preferPermanent,
                expiresInHours: expiresInHours,
                maxUses: maxUses
            )
            return ShareResolvedResult(payload: payload, usedFallbackPayload: false)
        } catch {
            return ShareResolvedResult(
                payload: Self.fallbackPayload(for: target),
                usedFallbackPayload: true
            )
        }
    }

    func copyLink(
        target: ShareTarget,
        channel: String = "copy_link",
        campaign: String? = nil,
        preferPermanent: Bool = true,
        expiresInHours: Int? = nil,
        maxUses: Int? = nil
    ) async throws -> ShareCopyResult {
        do {
            let payload = try await service.resolve(
                target: target,
                channel: channel,
                campaign: campaign,
                preferPermanent: preferPermanent,
                expiresInHours: expiresInHours,
                maxUses: maxUses
            )

            await MainActor.run {
                UIPasteboard.general.string = payload.shortURL
            }

            try? await service.recordEvent(
                code: payload.code,
                eventType: "copy",
                channel: channel,
                anonymousId: nil,
                metadata: nil
            )
            return ShareCopyResult(copiedText: payload.shortURL, usedCanonicalFallback: false, usedDeepLinkFallback: false)
        } catch {
            let canonicalFallback = Self.canonicalFallback(for: target)
            if !canonicalFallback.isEmpty {
                await MainActor.run {
                    UIPasteboard.general.string = canonicalFallback
                }
                return ShareCopyResult(copiedText: canonicalFallback, usedCanonicalFallback: true, usedDeepLinkFallback: false)
            }

            let deepLinkFallback = Self.deepLinkFallback(for: target)
            if !deepLinkFallback.isEmpty {
                await MainActor.run {
                    UIPasteboard.general.string = deepLinkFallback
                }
                return ShareCopyResult(copiedText: deepLinkFallback, usedCanonicalFallback: false, usedDeepLinkFallback: true)
            }

            throw error
        }
    }

    static func fallbackPayload(for target: ShareTarget) -> ShareLinkPayload {
        let code = "fallback-\(target.type.rawValue)-\(target.id)"
        let canonicalURL = canonicalFallback(for: target)
        return ShareLinkPayload(
            code: code,
            shortURL: canonicalURL,
            canonicalURL: canonicalURL,
            deepLink: deepLinkFallback(for: target),
            fallbackURL: canonicalURL,
            qrCodeURL: "",
            posterURL: nil,
            title: target.title ?? "Raver Share",
            subtitle: target.subtitle,
            imageURL: target.imageURL,
            previewType: "content_card",
            status: "active"
        )
    }

    static func canonicalFallback(for target: ShareTarget) -> String {
        switch target.type {
        case .post:
            return "https://raver.app/p/\(target.id)"
        case .event:
            return "https://raver.app/e/\(target.id)"
        case .news:
            return "https://raver.app/n/\(target.id)"
        case .dj:
            return "https://raver.app/dj/\(target.id)"
        case .set:
            return "https://raver.app/set/\(target.id)"
        case .label:
            return "https://raver.app/label/\(target.id)"
        case .festival:
            return "https://raver.app/festival/\(target.id)"
        case .rankingBoard:
            return "https://raver.app/ranking-board/\(target.id)"
        case .circleID:
            return "https://raver.app/circle/id/\(target.id)"
        case .ratingEvent:
            return "https://raver.app/rating-event/\(target.id)"
        case .ratingUnit:
            return "https://raver.app/rating-unit/\(target.id)"
        case .userCard:
            return "https://raver.app/u/\(target.id)"
        case .squadCard:
            return "https://raver.app/g/\(target.id)"
        case .squadInvite:
            return "https://raver.app/s/\(target.id)"
        }
    }

    static func deepLinkFallback(for target: ShareTarget) -> String {
        switch target.type {
        case .post:
            return "raver://community/post/\(target.id)"
        case .event:
            return "raver://event/\(target.id)"
        case .news:
            return "raver://news/\(target.id)"
        case .dj:
            return "raver://dj/\(target.id)"
        case .set:
            return "raver://set/\(target.id)"
        case .label:
            return "raver://label/\(target.id)"
        case .festival:
            return "raver://festival/\(target.id)"
        case .rankingBoard:
            return "raver://ranking-board/\(target.id)"
        case .circleID:
            return "raver://circle/id/\(target.id)"
        case .ratingEvent:
            return "raver://circle/rating-event/\(target.id)"
        case .ratingUnit:
            return "raver://rating-unit/\(target.id)"
        case .userCard:
            return "raver://profile/\(target.id)"
        case .squadCard, .squadInvite:
            return "raver://squad/\(target.id)"
        }
    }
}

private struct ShareLinkResolveRequest: Encodable {
    let targetType: String
    let targetId: String
    let channel: String
    let campaign: String?
    let preferPermanent: Bool
    let expiresInHours: Int?
    let maxUses: Int?
    let targetSeed: ShareTargetSeedRequest?
}

private struct ShareLinkEventRequest: Encodable {
    let eventType: String
    let channel: String
    let anonymousId: String?
    let platform: String
    let metadata: [String: String]?
}

private struct ShareLinkServerError: Decodable {
    let error: String
    let message: String?
}

private struct AnyEncodable: Encodable {
    private let encodeImpl: (Encoder) throws -> Void

    init(_ wrapped: Encodable) {
        self.encodeImpl = wrapped.encode
    }

    func encode(to encoder: Encoder) throws {
        try encodeImpl(encoder)
    }
}
