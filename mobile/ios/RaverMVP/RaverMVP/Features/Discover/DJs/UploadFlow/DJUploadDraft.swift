import Foundation

enum DJUploadMode: Hashable, Codable {
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

enum DJUploadStep: String, CaseIterable, Identifiable, Codable {
    case identity
    case profile
    case links
    case review

    var id: String { rawValue }

    var title: String {
        switch self {
        case .identity: return LT("身份", "Identity", "本人確認")
        case .profile: return LT("资料", "Profile", "プロフィール")
        case .links: return LT("链接", "Links", "リンク")
        case .review: return LT("检查", "Review", "確認")
        }
    }

    var next: DJUploadStep? {
        guard let index = Self.allCases.firstIndex(of: self) else { return nil }
        let nextIndex = Self.allCases.index(after: index)
        return nextIndex < Self.allCases.endIndex ? Self.allCases[nextIndex] : nil
    }

    var previous: DJUploadStep? {
        guard let index = Self.allCases.firstIndex(of: self), index > Self.allCases.startIndex else { return nil }
        return Self.allCases[Self.allCases.index(before: index)]
    }
}

enum DJUploadImageZone: String, CaseIterable, Identifiable, Codable {
    case avatar
    case banner
    case proof

    var id: String { rawValue }

    var title: String {
        switch self {
        case .avatar: return LT("头像", "Avatar", "アバター")
        case .banner: return LT("横幅", "Banner", "バナー")
        case .proof: return LT("证明图片", "Proof Image", "証明画像")
        }
    }

    var backendUsage: String { rawValue }
}

struct DJUploadImageDraft: Identifiable, Hashable, Codable {
    var id: UUID = UUID()
    var zone: DJUploadImageZone
    var remoteURL: String
    var fileName: String
    var mimeType: String
    var isPersisted: Bool = false
}

struct DJUploadDraft: Identifiable, Hashable, Codable {
    var id: UUID = UUID()
    var mode: DJUploadMode = .create
    var currentStep: DJUploadStep = .identity
    var preferredLanguage: EventUploadPreferredLanguage = .current
    var name: EventUploadLocalizedFields = EventUploadLocalizedFields()
    var aliasesText: String = ""
    var genresText: String = ""
    var bio: EventUploadLocalizedFields = EventUploadLocalizedFields()
    var country: EventUploadLocalizedFields = EventUploadLocalizedFields()
    var avatar: DJUploadImageDraft?
    var banner: DJUploadImageDraft?
    var proofImage: DJUploadImageDraft?
    var spotifyId: String = ""
    var spotifyUrl: String = ""
    var spotifyFollowers: String = ""
    var appleMusicId: String = ""
    var instagramUrl: String = ""
    var facebookUrl: String = ""
    var soundcloudUrl: String = ""
    var soundcloudId: String = ""
    var twitterUrl: String = ""
    var youtubeUrl: String = ""
    var neteaseUrl: String = ""
    var qqMusicUrl: String = ""
    var website: String = ""
    var otherPlatformUrl: String = ""
    var trackCount: String = ""
    var playlistCount: String = ""
    var soundCloudFollowers: String = ""
    var soundCloudFavorites: String = ""
    var dirty: Bool = false
    var lastSavedAt: Date?

    var isCreate: Bool {
        if case .create = mode { return true }
        return false
    }

    var primaryName: String {
        name.primaryValue(preferredLanguage: preferredLanguage).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var hasPlatformLink: Bool {
        [
            spotifyId,
            spotifyUrl,
            appleMusicId,
            instagramUrl,
            facebookUrl,
            soundcloudUrl,
            soundcloudId,
            twitterUrl,
            youtubeUrl,
            neteaseUrl,
            qqMusicUrl,
            website,
            otherPlatformUrl,
        ].contains { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    func image(for zone: DJUploadImageZone) -> DJUploadImageDraft? {
        switch zone {
        case .avatar: return avatar
        case .banner: return banner
        case .proof: return proofImage
        }
    }

    mutating func setImage(_ image: DJUploadImageDraft?, for zone: DJUploadImageZone) {
        switch zone {
        case .avatar: avatar = image
        case .banner: banner = image
        case .proof: proofImage = image
        }
    }

    static func create() -> DJUploadDraft {
        DJUploadDraft()
    }

    static func edit(from dj: WebDJ) -> DJUploadDraft {
        var draft = DJUploadDraft()
        draft.mode = .edit(id: dj.id)
        draft.name = EventUploadLocalizedFields(
            zh: dj.nameI18n?.zh ?? dj.name,
            en: dj.nameI18n?.en ?? dj.name,
            ja: dj.nameI18n?.ja ?? "",
            enFull: dj.nameI18n?.enFull ?? ""
        )
        draft.aliasesText = (dj.aliases ?? []).joined(separator: ", ")
        draft.genresText = (dj.genres ?? []).joined(separator: ", ")
        draft.bio = EventUploadLocalizedFields(
            zh: dj.bioI18n?.zh ?? dj.bio ?? "",
            en: dj.bioI18n?.en ?? dj.bio ?? "",
            ja: dj.bioI18n?.ja ?? "",
            enFull: dj.bioI18n?.enFull ?? ""
        )
        draft.country = EventUploadLocalizedFields(
            zh: dj.countryI18n?.zh ?? dj.country ?? "",
            en: dj.countryI18n?.en ?? dj.country ?? "",
            ja: dj.countryI18n?.ja ?? "",
            enFull: dj.countryI18n?.enFull ?? ""
        )
        if let url = dj.avatarUrl?.nilIfBlank {
            draft.avatar = DJUploadImageDraft(zone: .avatar, remoteURL: url, fileName: "avatar", mimeType: "image/jpeg", isPersisted: true)
        }
        if let url = dj.bannerUrl?.nilIfBlank {
            draft.banner = DJUploadImageDraft(zone: .banner, remoteURL: url, fileName: "banner", mimeType: "image/jpeg", isPersisted: true)
        }
        draft.spotifyId = dj.spotifyId ?? ""
        draft.spotifyUrl = dj.spotifyUrl ?? ""
        draft.spotifyFollowers = dj.spotifyFollowers.map(String.init) ?? ""
        draft.appleMusicId = dj.appleMusicId ?? ""
        draft.instagramUrl = dj.instagramUrl ?? ""
        draft.facebookUrl = dj.facebookUrl ?? ""
        draft.soundcloudUrl = dj.soundcloudUrl ?? ""
        draft.soundcloudId = dj.soundcloudId ?? ""
        draft.twitterUrl = dj.twitterUrl ?? ""
        draft.youtubeUrl = dj.youtubeUrl ?? ""
        draft.neteaseUrl = dj.neteaseUrl ?? ""
        draft.qqMusicUrl = dj.qqMusicUrl ?? ""
        draft.website = dj.website ?? ""
        draft.trackCount = dj.trackCount.map(String.init) ?? ""
        draft.playlistCount = dj.playlistCount.map(String.init) ?? ""
        draft.soundCloudFollowers = dj.soundCloudFollowers.map(String.init) ?? ""
        draft.soundCloudFavorites = dj.soundCloudFavorites.map(String.init) ?? ""
        return draft
    }
}
