import Foundation

enum VirtualAssetTelemetry {
    private static var serviceProvider: (() -> SocialService)?

    static func configure(serviceProvider: @escaping () -> SocialService) {
        self.serviceProvider = serviceProvider
    }

    static func record(
        event: String,
        surface: String,
        userID: String? = nil,
        assetID: String? = nil,
        assetType: VirtualAssetType? = nil,
        error: String? = nil
    ) {
        guard AppConfig.virtualAssetsEnabled else { return }
        guard let service = serviceProvider?() else { return }

        var metadata: [String: String] = [
            "surface": surface,
            "feature": "virtual_assets"
        ]
        if let userID, !userID.isEmpty {
            metadata["userId"] = userID
        }
        if let assetID, !assetID.isEmpty {
            metadata["assetId"] = assetID
        }
        if let assetType {
            metadata["assetType"] = assetType.rawValue
        }
        if let error, !error.isEmpty {
            metadata["error"] = String(error.prefix(180))
        }

        Task {
            try? await service.recordFeedEvent(
                input: FeedEventInput(
                    sessionID: "virtual-assets-\(UUID().uuidString)",
                    eventType: "virtual_asset_\(event)",
                    postID: nil,
                    feedMode: nil,
                    position: nil,
                    metadata: metadata
                )
            )
        }
    }
}
