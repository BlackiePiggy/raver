import Foundation

protocol ShareLinkRepository {
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

struct ShareLinkRepositoryAdapter: ShareLinkRepository {
    let service: ShareLinkService

    func resolve(
        target: ShareTarget,
        channel: String,
        campaign: String?,
        preferPermanent: Bool,
        expiresInHours: Int?,
        maxUses: Int?
    ) async throws -> ShareLinkPayload {
        try await service.resolve(
            target: target,
            channel: channel,
            campaign: campaign,
            preferPermanent: preferPermanent,
            expiresInHours: expiresInHours,
            maxUses: maxUses
        )
    }

    func getLink(code: String) async throws -> ShareLinkPayload {
        try await service.getLink(code: code)
    }

    func recordEvent(
        code: String,
        eventType: String,
        channel: String,
        anonymousId: String?,
        metadata: [String: String]?
    ) async throws {
        try await service.recordEvent(
            code: code,
            eventType: eventType,
            channel: channel,
            anonymousId: anonymousId,
            metadata: metadata
        )
    }
}
