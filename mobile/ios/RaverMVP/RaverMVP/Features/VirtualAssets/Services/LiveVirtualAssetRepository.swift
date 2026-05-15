import Foundation

private struct VirtualAssetErrorEnvelope: Codable {
    let error: String
}

private struct UpdateVirtualAssetEquipRequest: Encodable {
    let assetIds: [String]
}

private struct VirtualAssetAnyEncodable: Encodable {
    private let encodeClosure: (Encoder) throws -> Void

    init(_ wrapped: Encodable) {
        self.encodeClosure = wrapped.encode(to:)
    }

    func encode(to encoder: Encoder) throws {
        try encodeClosure(encoder)
    }
}

final class LiveVirtualAssetRepository: VirtualAssetRepository {
    private let baseURL: URL
    private let session: URLSession
    private let cacheStore: VirtualAssetCacheStore
    private var token: String? { SessionTokenStore.shared.token }

    init(
        baseURL: URL,
        session: URLSession = .shared,
        cacheStore: VirtualAssetCacheStore = .shared
    ) {
        self.baseURL = baseURL
        self.session = session
        self.cacheStore = cacheStore
    }

    func fetchCatalog(type: VirtualAssetType?, includeHidden: Bool = false) async throws -> [VirtualAssetDefinition] {
        var queryItems: [String] = []
        if let type {
            queryItems.append("type=\(urlEncode(type.rawValue))")
        }
        if includeHidden {
            queryItems.append("includeHidden=true")
        }
        let suffix = queryItems.isEmpty ? "" : "?\(queryItems.joined(separator: "&"))"
        let response: VirtualAssetCatalogResponse = try await request(
            path: "/v1/virtual-assets/catalog\(suffix)",
            method: "GET",
            includeAccessToken: false
        )
        return response.assets
    }

    func fetchMyAssets() async throws -> MyVirtualAssetsResponse {
        let response: MyVirtualAssetsResponse = try await request(path: "/v1/me/virtual-assets", method: "GET")
        cacheStore.saveMyAssets(response)
        return response
    }

    func updateEquip(assetType: VirtualAssetType, assetIDs: [String]) async throws -> UpdateVirtualAssetEquipResponse {
        var seenAssetIDs = Set<String>()
        let trimmedIDs = assetIDs.compactMap { rawID -> String? in
            let assetID = rawID.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !assetID.isEmpty, seenAssetIDs.insert(assetID).inserted else { return nil }
            return assetID
        }
        let response: UpdateVirtualAssetEquipResponse = try await request(
            path: "/v1/me/virtual-assets/equips/\(assetType.rawValue)",
            method: "PUT",
            body: UpdateVirtualAssetEquipRequest(assetIds: Array(trimmedIDs.prefix(assetType.maxEquippedCount)))
        )
        cacheStore.saveAppearance(response.appearance)
        return response
    }

    func fetchAppearance(userID: String) async throws -> UserAssetAppearance {
        let encodedUserID = urlEncode(userID)
        let appearance: UserAssetAppearance = try await request(
            path: "/v1/users/\(encodedUserID)/appearance",
            method: "GET",
            includeAccessToken: false
        )
        cacheStore.saveAppearance(appearance)
        return appearance
    }

    func cachedAppearance(userID: String) -> UserAssetAppearance? {
        cacheStore.loadAppearance(userID: userID)
    }

    func cachedMyAssets() -> MyVirtualAssetsResponse? {
        cacheStore.loadMyAssets()
    }

    private func request<T: Decodable>(
        path: String,
        method: String,
        body: Encodable? = nil,
        includeAccessToken: Bool = true
    ) async throws -> T {
        guard let url = URL(string: path, relativeTo: baseURL) else {
            throw ServiceError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = 15
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
        request.setValue("no-cache", forHTTPHeaderField: "Pragma")
        if includeAccessToken, let token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        if let body {
            request.httpBody = try JSONEncoder.raver.encode(VirtualAssetAnyEncodable(body))
        }

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw ServiceError.invalidResponse
        }

        if http.statusCode == 401 {
            NotificationCenter.default.post(name: .raverSessionExpired, object: nil)
            throw ServiceError.unauthorized
        }

        guard (200...299).contains(http.statusCode) else {
            let message = (try? JSONDecoder.raver.decode(VirtualAssetErrorEnvelope.self, from: data).error)
                ?? String(data: data, encoding: .utf8)
                ?? LT("请求失败", "Request failed", "リクエストに失敗しました")
            throw ServiceError.message(message)
        }

        do {
            return try JSONDecoder.raver.decode(T.self, from: data)
        } catch let decodingError as DecodingError {
            print("Virtual asset BFF decode error:", decodingError)
            throw ServiceError.message(LT("虚拟资产接口返回格式不匹配", "Virtual asset response format mismatch", "仮想アセットAPIのレスポンス形式が一致しません"))
        } catch {
            print("Virtual asset BFF decode error:", error)
            throw ServiceError.message(LT("虚拟资产接口返回格式不匹配", "Virtual asset response format mismatch", "仮想アセットAPIのレスポンス形式が一致しません"))
        }
    }

    private func urlEncode(_ value: String) -> String {
        value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? value
    }
}

final class MockVirtualAssetRepository: VirtualAssetRepository {
    private var appearanceByUserID: [String: UserAssetAppearance] = [:]
    private let cacheStore: VirtualAssetCacheStore

    init(cacheStore: VirtualAssetCacheStore = .shared) {
        self.cacheStore = cacheStore
    }

    func fetchCatalog(type: VirtualAssetType?, includeHidden: Bool) async throws -> [VirtualAssetDefinition] {
        let assets = Self.seedAssets
        guard let type else { return assets }
        return assets.filter { $0.type == type }
    }

    func fetchMyAssets() async throws -> MyVirtualAssetsResponse {
        let userID = "mock-user"
        let inventory = Self.seedAssets.map { asset in
            UserVirtualAsset(
                id: "mock-owned-\(asset.id)",
                userID: userID,
                assetID: asset.id,
                acquisitionSource: asset.source,
                status: .active,
                acquiredAt: Date(),
                expiresAt: nil,
                metadata: nil,
                isUsable: true,
                asset: asset
            )
        }
        let appearance = UserAssetAppearance(
            userID: userID,
            avatarFrame: Self.seedAssets.first { $0.type == .avatarFrame },
            titleMedal: Self.seedAssets.first { $0.type == .titleMedal },
            profileBadges: Self.seedAssets.filter { $0.type == .profileBadge },
            chatBubbleSkin: Self.seedAssets.first { $0.type == .chatBubbleSkin },
            version: 1
        )
        let response = MyVirtualAssetsResponse(inventory: inventory, equips: [], appearance: appearance)
        cacheStore.saveMyAssets(response)
        return response
    }

    func updateEquip(assetType: VirtualAssetType, assetIDs: [String]) async throws -> UpdateVirtualAssetEquipResponse {
        let userID = "mock-user"
        let equip = UserVirtualAssetEquip(userID: userID, assetType: assetType, assetIDs: assetIDs, updatedAt: Date())
        let myAssets = try await fetchMyAssets()
        let appearance = myAssets.appearance
        cacheStore.saveAppearance(appearance)
        return UpdateVirtualAssetEquipResponse(equip: equip, appearance: appearance)
    }

    func fetchAppearance(userID: String) async throws -> UserAssetAppearance {
        if let cached = appearanceByUserID[userID] ?? cacheStore.loadAppearance(userID: userID) {
            return cached
        }
        let appearance = UserAssetAppearance.empty(userID: userID)
        appearanceByUserID[userID] = appearance
        cacheStore.saveAppearance(appearance)
        return appearance
    }

    func cachedAppearance(userID: String) -> UserAssetAppearance? {
        appearanceByUserID[userID] ?? cacheStore.loadAppearance(userID: userID)
    }

    func cachedMyAssets() -> MyVirtualAssetsResponse? {
        cacheStore.loadMyAssets()
    }

    private static let seedAssets: [VirtualAssetDefinition] = [
        makeAsset(id: "mock-avatar-frame", type: .avatarFrame, name: "Mock Frame"),
        makeAsset(id: "mock-profile-badge", type: .profileBadge, name: "Mock Badge"),
        makeAsset(id: "mock-chat-bubble", type: .chatBubbleSkin, name: "Mock Bubble"),
        makeAsset(id: "mock-title-medal", type: .titleMedal, name: "Mock Title")
    ]

    private static func makeAsset(id: String, type: VirtualAssetType, name: String) -> VirtualAssetDefinition {
        VirtualAssetDefinition(
            id: id,
            code: id,
            type: type,
            name: name,
            description: nil,
            status: .active,
            renderPayload: [:],
            previewImageURL: nil,
            source: "mock",
            themeTags: [],
            startsAt: nil,
            endsAt: nil,
            createdAt: Date(),
            updatedAt: Date()
        )
    }
}
