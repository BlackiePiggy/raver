import Foundation

final class DisabledVirtualAssetRepository: VirtualAssetRepository {
    func fetchCatalog(type: VirtualAssetType?, includeHidden: Bool) async throws -> [VirtualAssetDefinition] {
        []
    }

    func fetchMyAssets() async throws -> MyVirtualAssetsResponse {
        let appearance = UserAssetAppearance.empty(userID: "disabled")
        return MyVirtualAssetsResponse(inventory: [], equips: [], appearance: appearance)
    }

    func updateEquip(assetType: VirtualAssetType, assetIDs: [String]) async throws -> UpdateVirtualAssetEquipResponse {
        let equip = UserVirtualAssetEquip(
            userID: "disabled",
            assetType: assetType,
            assetIDs: [],
            updatedAt: Date()
        )
        return UpdateVirtualAssetEquipResponse(
            equip: equip,
            appearance: UserAssetAppearance.empty(userID: "disabled")
        )
    }

    func fetchAppearance(userID: String) async throws -> UserAssetAppearance {
        UserAssetAppearance.empty(userID: userID)
    }

    func cachedAppearance(userID: String) -> UserAssetAppearance? {
        nil
    }

    func cachedMyAssets() -> MyVirtualAssetsResponse? {
        nil
    }
}
