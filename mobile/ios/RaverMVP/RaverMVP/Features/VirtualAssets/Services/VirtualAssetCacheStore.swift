import Foundation

final class VirtualAssetCacheStore {
    static let shared = VirtualAssetCacheStore()

    private let defaults: UserDefaults
    private let encoder = JSONEncoder.raver
    private let decoder = JSONDecoder.raver
    private let myAssetsKey = "raver.virtualAssets.myAssets.v1"
    private let appearancePrefix = "raver.virtualAssets.appearance.v1."

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func saveMyAssets(_ response: MyVirtualAssetsResponse) {
        guard let data = try? encoder.encode(response) else { return }
        defaults.set(data, forKey: myAssetsKey)
        saveAppearance(response.appearance)
    }

    func loadMyAssets() -> MyVirtualAssetsResponse? {
        guard let data = defaults.data(forKey: myAssetsKey) else { return nil }
        return try? decoder.decode(MyVirtualAssetsResponse.self, from: data)
    }

    func saveAppearance(_ appearance: UserAssetAppearance) {
        guard let data = try? encoder.encode(appearance) else { return }
        defaults.set(data, forKey: appearanceKey(userID: appearance.userID))
    }

    func loadAppearance(userID: String) -> UserAssetAppearance? {
        guard let data = defaults.data(forKey: appearanceKey(userID: userID)) else { return nil }
        return try? decoder.decode(UserAssetAppearance.self, from: data)
    }

    private func appearanceKey(userID: String) -> String {
        appearancePrefix + userID
    }
}
