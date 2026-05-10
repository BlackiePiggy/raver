import Foundation

final class VirtualAssetChatAppearanceResolver {
    var onAppearanceUpdated: (() -> Void)?

    private let repository: VirtualAssetRepository
    private var appearancesByUserID: [String: UserAssetAppearance] = [:]
    private var inFlightUserIDs = Set<String>()

    init(repository: VirtualAssetRepository) {
        self.repository = repository
    }

    func cachedAppearance(userID: String) -> UserAssetAppearance? {
        let key = normalizedUserID(userID)
        guard !key.isEmpty else { return nil }
        if let appearance = appearancesByUserID[key] {
            return appearance
        }
        if let cached = repository.cachedAppearance(userID: key) {
            appearancesByUserID[key] = cached
            return cached
        }
        return nil
    }

    func warmAppearances(for userIDs: [String]) {
        let uniqueUserIDs = Set(userIDs.map(normalizedUserID).filter { !$0.isEmpty })
        for userID in uniqueUserIDs {
            if cachedAppearance(userID: userID) != nil || inFlightUserIDs.contains(userID) {
                continue
            }
            inFlightUserIDs.insert(userID)
            Task { [weak self] in
                guard let self else { return }
                let fetched = try? await self.repository.fetchAppearance(userID: userID)
                await MainActor.run {
                    self.inFlightUserIDs.remove(userID)
                    guard let fetched else {
                        VirtualAssetTelemetry.record(event: "load_failed", surface: "messages", userID: userID)
                        return
                    }
                    self.appearancesByUserID[userID] = fetched
                    self.recordExposureIfNeeded(appearance: fetched)
                    self.onAppearanceUpdated?()
                }
            }
        }
    }

    func reset() {
        appearancesByUserID.removeAll(keepingCapacity: true)
        inFlightUserIDs.removeAll(keepingCapacity: true)
    }

    private func normalizedUserID(_ value: String) -> String {
        TencentIMIdentity.normalizePlatformUserIDForProfile(
            value.trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }

    private func recordExposureIfNeeded(appearance: UserAssetAppearance) {
        let visibleAssets = [
            appearance.avatarFrame,
            appearance.titleMedal,
            appearance.profileBadges.first,
            appearance.chatBubbleSkin
        ].compactMap { $0 }

        for asset in visibleAssets {
            VirtualAssetTelemetry.record(
                event: "exposure",
                surface: "messages",
                userID: appearance.userID,
                assetID: asset.id,
                assetType: asset.type
            )
        }
    }
}
