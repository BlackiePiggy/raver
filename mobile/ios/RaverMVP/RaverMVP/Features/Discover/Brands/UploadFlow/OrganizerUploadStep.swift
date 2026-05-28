import Foundation

enum OrganizerUploadMode: Hashable, Codable {
    case create
    case edit(id: String)

    var storageKey: String {
        switch self {
        case .create:
            return "create"
        case .edit(let id):
            return "edit-\(id)"
        }
    }
}

enum OrganizerUploadStep: String, CaseIterable, Identifiable, Codable {
    case media
    case basic
    case profile
    case links
    case relations
    case review

    var id: String { rawValue }

    var title: String {
        switch self {
        case .media: return LT("媒体", "Media", "メディア")
        case .basic: return LT("基础", "Basic", "基本")
        case .profile: return LT("资料", "Profile", "プロフィール")
        case .links: return LT("链接", "Links", "リンク")
        case .relations: return LT("关联", "Relations", "関連")
        case .review: return LT("检查", "Review", "確認")
        }
    }

    var next: OrganizerUploadStep? {
        guard let index = Self.allCases.firstIndex(of: self) else { return nil }
        let nextIndex = Self.allCases.index(after: index)
        return nextIndex < Self.allCases.endIndex ? Self.allCases[nextIndex] : nil
    }

    var previous: OrganizerUploadStep? {
        guard let index = Self.allCases.firstIndex(of: self), index > Self.allCases.startIndex else { return nil }
        return Self.allCases[Self.allCases.index(before: index)]
    }
}

enum OrganizerUploadImageZone: String, CaseIterable, Identifiable, Codable {
    case avatar
    case background
    case poster
    case proof
    case other

    var id: String { rawValue }

    var title: String {
        switch self {
        case .avatar: return LT("头像", "Avatar", "アバター")
        case .background: return LT("背景图", "Background", "背景")
        case .poster: return LT("海报 / 主 KV", "Poster / Key Visual", "ポスター / キービジュアル")
        case .proof: return LT("证明图", "Proof", "証明")
        case .other: return LT("补充图", "Other", "その他")
        }
    }

    var backendUsage: String {
        rawValue
    }
}
