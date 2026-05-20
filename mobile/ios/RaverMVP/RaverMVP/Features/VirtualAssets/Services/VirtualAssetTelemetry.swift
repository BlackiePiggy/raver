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
        _ = serviceProvider
        _ = event
        _ = surface
        _ = userID
        _ = assetID
        _ = assetType
        _ = error
    }
}
