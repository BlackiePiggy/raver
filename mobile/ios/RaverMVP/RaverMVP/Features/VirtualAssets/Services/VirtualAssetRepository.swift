import Foundation

protocol VirtualAssetRepository {
    func fetchCatalog(type: VirtualAssetType?, includeHidden: Bool) async throws -> [VirtualAssetDefinition]
    func fetchMyAssets() async throws -> MyVirtualAssetsResponse
    func updateEquip(assetType: VirtualAssetType, assetIDs: [String]) async throws -> UpdateVirtualAssetEquipResponse
    func fetchAppearance(userID: String) async throws -> UserAssetAppearance
    func cachedAppearance(userID: String) -> UserAssetAppearance?
    func cachedMyAssets() -> MyVirtualAssetsResponse?
}
