import Foundation

enum VirtualAssetType: Codable, Identifiable, Hashable {
    case avatarFrame
    case profileBadge
    case chatBubbleSkin
    case titleMedal
    case unknown(String)

    var id: String { rawValue }

    static let supportedCases: [VirtualAssetType] = [
        .avatarFrame,
        .profileBadge,
        .chatBubbleSkin,
        .titleMedal
    ]

    var rawValue: String {
        switch self {
        case .avatarFrame:
            return "avatar_frame"
        case .profileBadge:
            return "profile_badge"
        case .chatBubbleSkin:
            return "chat_bubble_skin"
        case .titleMedal:
            return "title_medal"
        case .unknown(let value):
            return value
        }
    }

    init(rawValue: String) {
        switch rawValue {
        case "avatar_frame":
            self = .avatarFrame
        case "profile_badge":
            self = .profileBadge
        case "chat_bubble_skin":
            self = .chatBubbleSkin
        case "title_medal":
            self = .titleMedal
        default:
            self = .unknown(rawValue)
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.init(rawValue: try container.decode(String.self))
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }

    var maxEquippedCount: Int {
        switch self {
        case .avatarFrame, .chatBubbleSkin, .titleMedal:
            return 1
        case .profileBadge:
            return 5
        case .unknown:
            return 1
        }
    }
}

enum VirtualAssetDefinitionStatus: String, Codable, Hashable {
    case draft
    case active
    case hidden
    case retired
}

enum VirtualAssetOwnershipStatus: String, Codable, Hashable {
    case active
    case expired
    case revoked
}

enum VirtualAssetJSONValue: Codable, Hashable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case object([String: VirtualAssetJSONValue])
    case array([VirtualAssetJSONValue])
    case null

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Double.self) {
            self = .number(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode([String: VirtualAssetJSONValue].self) {
            self = .object(value)
        } else if let value = try? container.decode([VirtualAssetJSONValue].self) {
            self = .array(value)
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unsupported virtual asset JSON value")
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value):
            try container.encode(value)
        case .number(let value):
            try container.encode(value)
        case .bool(let value):
            try container.encode(value)
        case .object(let value):
            try container.encode(value)
        case .array(let value):
            try container.encode(value)
        case .null:
            try container.encodeNil()
        }
    }

    var stringValue: String? {
        if case .string(let value) = self { return value }
        return nil
    }

    var objectValue: [String: VirtualAssetJSONValue]? {
        if case .object(let value) = self { return value }
        return nil
    }

    subscript(key: String) -> VirtualAssetJSONValue? {
        objectValue?[key]
    }
}

struct VirtualAssetDefinition: Codable, Identifiable, Hashable {
    let id: String
    var code: String
    var type: VirtualAssetType
    var name: String
    var description: String?
    var status: VirtualAssetDefinitionStatus
    var renderPayload: [String: VirtualAssetJSONValue]
    var previewImageURL: String?
    var source: String
    var themeTags: [String]
    var startsAt: Date?
    var endsAt: Date?
    var createdAt: Date
    var updatedAt: Date

    private enum CodingKeys: String, CodingKey {
        case id
        case code
        case type
        case name
        case description
        case status
        case renderPayload
        case previewImageURL
        case source
        case themeTags
        case startsAt
        case endsAt
        case createdAt
        case updatedAt
    }
}

struct UserVirtualAsset: Codable, Identifiable, Hashable {
    let id: String
    var userID: String
    var assetID: String
    var acquisitionSource: String
    var status: VirtualAssetOwnershipStatus
    var acquiredAt: Date
    var expiresAt: Date?
    var metadata: [String: VirtualAssetJSONValue]?
    var isUsable: Bool
    var asset: VirtualAssetDefinition

    private enum CodingKeys: String, CodingKey {
        case id
        case userID = "userId"
        case assetID = "assetId"
        case acquisitionSource
        case status
        case acquiredAt
        case expiresAt
        case metadata
        case isUsable
        case asset
    }
}

struct UserVirtualAssetEquip: Codable, Hashable {
    var userID: String
    var assetType: VirtualAssetType
    var assetIDs: [String]
    var updatedAt: Date

    private enum CodingKeys: String, CodingKey {
        case userID = "userId"
        case assetType
        case assetIDs = "assetIds"
        case updatedAt
    }
}

struct UserAssetAppearance: Codable, Hashable {
    var userID: String
    var avatarFrame: VirtualAssetDefinition?
    var titleMedal: VirtualAssetDefinition?
    var profileBadges: [VirtualAssetDefinition]
    var chatBubbleSkin: VirtualAssetDefinition?
    var version: Int

    static func empty(userID: String) -> UserAssetAppearance {
        UserAssetAppearance(
            userID: userID,
            avatarFrame: nil,
            titleMedal: nil,
            profileBadges: [],
            chatBubbleSkin: nil,
            version: 1
        )
    }

    private enum CodingKeys: String, CodingKey {
        case userID = "userId"
        case avatarFrame
        case titleMedal
        case profileBadges
        case chatBubbleSkin
        case version
    }
}

struct VirtualAssetCatalogResponse: Codable, Hashable {
    var assets: [VirtualAssetDefinition]
}

struct MyVirtualAssetsResponse: Codable, Hashable {
    var inventory: [UserVirtualAsset]
    var equips: [UserVirtualAssetEquip]
    var appearance: UserAssetAppearance
}

struct UpdateVirtualAssetEquipResponse: Codable, Hashable {
    var equip: UserVirtualAssetEquip
    var appearance: UserAssetAppearance
}
