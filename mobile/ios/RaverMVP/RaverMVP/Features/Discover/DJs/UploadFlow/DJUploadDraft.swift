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
    var aliases: [String] = []
    var genres: [String] = []
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
        draft.aliases = dj.aliases ?? []
        draft.genres = dj.genres ?? []
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
        draft.otherPlatformUrl = dj.otherPlatformUrl ?? ""
        draft.trackCount = dj.trackCount.map(String.init) ?? ""
        draft.playlistCount = dj.playlistCount.map(String.init) ?? ""
        draft.soundCloudFollowers = dj.soundCloudFollowers.map(String.init) ?? ""
        draft.soundCloudFavorites = dj.soundCloudFavorites.map(String.init) ?? ""
        return draft
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case mode
        case currentStep
        case preferredLanguage
        case name
        case aliases
        case aliasesText
        case genres
        case genresText
        case bio
        case country
        case avatar
        case banner
        case proofImage
        case spotifyId
        case spotifyUrl
        case spotifyFollowers
        case appleMusicId
        case instagramUrl
        case facebookUrl
        case soundcloudUrl
        case soundcloudId
        case twitterUrl
        case youtubeUrl
        case neteaseUrl
        case qqMusicUrl
        case website
        case otherPlatformUrl
        case trackCount
        case playlistCount
        case soundCloudFollowers
        case soundCloudFavorites
        case dirty
        case lastSavedAt
    }

    init() {}

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        mode = try container.decodeIfPresent(DJUploadMode.self, forKey: .mode) ?? .create
        currentStep = try container.decodeIfPresent(DJUploadStep.self, forKey: .currentStep) ?? .identity
        preferredLanguage = try container.decodeIfPresent(EventUploadPreferredLanguage.self, forKey: .preferredLanguage) ?? .current
        name = try container.decodeIfPresent(EventUploadLocalizedFields.self, forKey: .name) ?? EventUploadLocalizedFields()
        aliases = Self.decodeStringList(container: container, listKey: .aliases, legacyTextKey: .aliasesText)
        genres = Self.decodeStringList(container: container, listKey: .genres, legacyTextKey: .genresText)
        bio = try container.decodeIfPresent(EventUploadLocalizedFields.self, forKey: .bio) ?? EventUploadLocalizedFields()
        country = try container.decodeIfPresent(EventUploadLocalizedFields.self, forKey: .country) ?? EventUploadLocalizedFields()
        avatar = try container.decodeIfPresent(DJUploadImageDraft.self, forKey: .avatar)
        banner = try container.decodeIfPresent(DJUploadImageDraft.self, forKey: .banner)
        proofImage = try container.decodeIfPresent(DJUploadImageDraft.self, forKey: .proofImage)
        spotifyId = try container.decodeIfPresent(String.self, forKey: .spotifyId) ?? ""
        spotifyUrl = try container.decodeIfPresent(String.self, forKey: .spotifyUrl) ?? ""
        spotifyFollowers = try container.decodeIfPresent(String.self, forKey: .spotifyFollowers) ?? ""
        appleMusicId = try container.decodeIfPresent(String.self, forKey: .appleMusicId) ?? ""
        instagramUrl = try container.decodeIfPresent(String.self, forKey: .instagramUrl) ?? ""
        facebookUrl = try container.decodeIfPresent(String.self, forKey: .facebookUrl) ?? ""
        soundcloudUrl = try container.decodeIfPresent(String.self, forKey: .soundcloudUrl) ?? ""
        soundcloudId = try container.decodeIfPresent(String.self, forKey: .soundcloudId) ?? ""
        twitterUrl = try container.decodeIfPresent(String.self, forKey: .twitterUrl) ?? ""
        youtubeUrl = try container.decodeIfPresent(String.self, forKey: .youtubeUrl) ?? ""
        neteaseUrl = try container.decodeIfPresent(String.self, forKey: .neteaseUrl) ?? ""
        qqMusicUrl = try container.decodeIfPresent(String.self, forKey: .qqMusicUrl) ?? ""
        website = try container.decodeIfPresent(String.self, forKey: .website) ?? ""
        otherPlatformUrl = try container.decodeIfPresent(String.self, forKey: .otherPlatformUrl) ?? ""
        trackCount = try container.decodeIfPresent(String.self, forKey: .trackCount) ?? ""
        playlistCount = try container.decodeIfPresent(String.self, forKey: .playlistCount) ?? ""
        soundCloudFollowers = try container.decodeIfPresent(String.self, forKey: .soundCloudFollowers) ?? ""
        soundCloudFavorites = try container.decodeIfPresent(String.self, forKey: .soundCloudFavorites) ?? ""
        dirty = try container.decodeIfPresent(Bool.self, forKey: .dirty) ?? false
        lastSavedAt = try container.decodeIfPresent(Date.self, forKey: .lastSavedAt)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(mode, forKey: .mode)
        try container.encode(currentStep, forKey: .currentStep)
        try container.encode(preferredLanguage, forKey: .preferredLanguage)
        try container.encode(name, forKey: .name)
        try container.encode(aliases, forKey: .aliases)
        try container.encode(genres, forKey: .genres)
        try container.encode(bio, forKey: .bio)
        try container.encode(country, forKey: .country)
        try container.encodeIfPresent(avatar, forKey: .avatar)
        try container.encodeIfPresent(banner, forKey: .banner)
        try container.encodeIfPresent(proofImage, forKey: .proofImage)
        try container.encode(spotifyId, forKey: .spotifyId)
        try container.encode(spotifyUrl, forKey: .spotifyUrl)
        try container.encode(spotifyFollowers, forKey: .spotifyFollowers)
        try container.encode(appleMusicId, forKey: .appleMusicId)
        try container.encode(instagramUrl, forKey: .instagramUrl)
        try container.encode(facebookUrl, forKey: .facebookUrl)
        try container.encode(soundcloudUrl, forKey: .soundcloudUrl)
        try container.encode(soundcloudId, forKey: .soundcloudId)
        try container.encode(twitterUrl, forKey: .twitterUrl)
        try container.encode(youtubeUrl, forKey: .youtubeUrl)
        try container.encode(neteaseUrl, forKey: .neteaseUrl)
        try container.encode(qqMusicUrl, forKey: .qqMusicUrl)
        try container.encode(website, forKey: .website)
        try container.encode(otherPlatformUrl, forKey: .otherPlatformUrl)
        try container.encode(trackCount, forKey: .trackCount)
        try container.encode(playlistCount, forKey: .playlistCount)
        try container.encode(soundCloudFollowers, forKey: .soundCloudFollowers)
        try container.encode(soundCloudFavorites, forKey: .soundCloudFavorites)
        try container.encode(dirty, forKey: .dirty)
        try container.encodeIfPresent(lastSavedAt, forKey: .lastSavedAt)
    }

    private static func decodeStringList(
        container: KeyedDecodingContainer<CodingKeys>,
        listKey: CodingKeys,
        legacyTextKey: CodingKeys
    ) -> [String] {
        if let items = try? container.decodeIfPresent([String].self, forKey: listKey) {
            return items.map(normalizeListItem).filter { !$0.isEmpty }
        }
        let legacy = (try? container.decodeIfPresent(String.self, forKey: legacyTextKey)) ?? ""
        return legacy
            .split(whereSeparator: { $0 == "," || $0 == "，" || $0 == "\n" })
            .map { normalizeListItem(String($0)) }
            .filter { !$0.isEmpty }
    }

    private static func normalizeListItem(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
