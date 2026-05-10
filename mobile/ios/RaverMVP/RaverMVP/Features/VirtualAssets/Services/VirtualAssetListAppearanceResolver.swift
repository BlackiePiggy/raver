import Foundation

@MainActor
final class VirtualAssetListAppearanceResolver: ObservableObject {
    @Published private var version = 0

    private let repository: VirtualAssetRepository
    private let surface: String
    private var appearancesByUserID: [String: UserAssetAppearance] = [:]
    private var inFlightUserIDs = Set<String>()

    init(repository: VirtualAssetRepository, surface: String = "list") {
        self.repository = repository
        self.surface = surface
    }

    func appearance(userID: String) -> UserAssetAppearance? {
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
            if appearancesByUserID[userID] != nil || inFlightUserIDs.contains(userID) {
                continue
            }
            if let cached = repository.cachedAppearance(userID: userID) {
                appearancesByUserID[userID] = cached
                continue
            }
            inFlightUserIDs.insert(userID)
            Task { [weak self] in
                guard let self else { return }
                let fetched = try? await self.repository.fetchAppearance(userID: userID)
                await MainActor.run {
                    self.inFlightUserIDs.remove(userID)
                    guard let fetched else {
                        VirtualAssetTelemetry.record(event: "load_failed", surface: self.surface, userID: userID)
                        return
                    }
                    self.appearancesByUserID[userID] = fetched
                    self.recordExposureIfNeeded(appearance: fetched)
                    self.version += 1
                }
            }
        }
    }

    private func recordExposureIfNeeded(appearance: UserAssetAppearance) {
        let visibleAssets = [
            appearance.avatarFrame,
            appearance.titleMedal,
            appearance.profileBadges.first
        ].compactMap { $0 }

        for asset in visibleAssets {
            VirtualAssetTelemetry.record(
                event: "exposure",
                surface: surface,
                userID: appearance.userID,
                assetID: asset.id,
                assetType: asset.type
            )
        }
    }

    private func normalizedUserID(_ value: String) -> String {
        TencentIMIdentity.normalizePlatformUserIDForProfile(
            value.trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }
}
