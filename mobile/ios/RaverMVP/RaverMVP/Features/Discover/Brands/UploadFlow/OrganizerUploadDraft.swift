import Foundation

struct OrganizerUploadImageDraft: Identifiable, Hashable, Codable {
    enum Ownership: String, Codable {
        case pendingLocal
        case createDraftUploaded
        case editDraftUploaded
        case persistedBrand
    }

    var id: UUID = UUID()
    var zone: OrganizerUploadImageZone
    var localFileURL: URL?
    var remoteURL: String?
    var fileName: String
    var mimeType: String
    var ownership: Ownership = .pendingLocal

    var isPersisted: Bool {
        ownership == .persistedBrand
    }

    init(
        id: UUID = UUID(),
        zone: OrganizerUploadImageZone,
        localFileURL: URL? = nil,
        remoteURL: String? = nil,
        fileName: String,
        mimeType: String,
        ownership: Ownership = .pendingLocal
    ) {
        self.id = id
        self.zone = zone
        self.localFileURL = localFileURL
        self.remoteURL = remoteURL
        self.fileName = fileName
        self.mimeType = mimeType
        self.ownership = ownership
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case zone
        case localFileURL
        case remoteURL
        case fileName
        case mimeType
        case ownership
        case isPersisted
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        zone = try container.decode(OrganizerUploadImageZone.self, forKey: .zone)
        localFileURL = try container.decodeIfPresent(URL.self, forKey: .localFileURL)
        remoteURL = try container.decodeIfPresent(String.self, forKey: .remoteURL)
        fileName = try container.decode(String.self, forKey: .fileName)
        mimeType = try container.decode(String.self, forKey: .mimeType)
        if let ownership = try container.decodeIfPresent(Ownership.self, forKey: .ownership) {
            self.ownership = ownership
        } else {
            let legacyPersisted = try container.decodeIfPresent(Bool.self, forKey: .isPersisted) ?? false
            let resolvedOwnership: Ownership
            if legacyPersisted {
                resolvedOwnership = .persistedBrand
            } else if remoteURL?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfBlank != nil {
                resolvedOwnership = .createDraftUploaded
            } else {
                resolvedOwnership = .pendingLocal
            }
            self.ownership = resolvedOwnership
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(zone, forKey: .zone)
        try container.encodeIfPresent(localFileURL, forKey: .localFileURL)
        try container.encodeIfPresent(remoteURL, forKey: .remoteURL)
        try container.encode(fileName, forKey: .fileName)
        try container.encode(mimeType, forKey: .mimeType)
        try container.encode(ownership, forKey: .ownership)
    }
}

struct OrganizerUploadDraft: Identifiable, Hashable, Codable {
    var id: UUID = UUID()
    var mode: OrganizerUploadMode = .create
    var currentStep: OrganizerUploadStep = .media
    var preferredLanguage: EventUploadPreferredLanguage = .current
    var name: String = ""
    var nameI18n: EventUploadLocalizedFields = EventUploadLocalizedFields()
    var abbreviation: String = ""
    var aliases: [String] = []
    var country: String = ""
    var city: String = ""
    var foundedYear: String = ""
    var frequency: String = ""
    var tagline: String = ""
    var introduction: String = ""
    var descriptionI18n: EventUploadLocalizedFields = EventUploadLocalizedFields()
    var officialWebsite: String = ""
    var instagram: String = ""
    var facebook: String = ""
    var twitter: String = ""
    var youtube: String = ""
    var tiktok: String = ""
    var extraLinks: [LearnFestivalLinkPayload] = []
    var avatarImage: OrganizerUploadImageDraft?
    var backgroundImage: OrganizerUploadImageDraft?
    var posterImage: OrganizerUploadImageDraft?
    var proofImages: [OrganizerUploadImageDraft] = []
    var otherImages: [OrganizerUploadImageDraft] = []
    var boundEventIDs: [String] = []
    var baseBrandRevision: Int? = nil
    var rightsConfirmed = false
    var identityConfirmed = false
    var dirty = false
    var lastSavedAt: Date?

    var isCreate: Bool {
        if case .create = mode { return true }
        return false
    }

    var primaryName: String {
        let localized = nameI18n.primaryValue(preferredLanguage: preferredLanguage).trimmingCharacters(in: .whitespacesAndNewlines)
        if !localized.isEmpty { return localized }
        return name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var primaryIntroduction: String {
        let localized = descriptionI18n.primaryValue(preferredLanguage: preferredLanguage).trimmingCharacters(in: .whitespacesAndNewlines)
        if !localized.isEmpty { return localized }
        return introduction.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var hasAnyLink: Bool {
        [
            officialWebsite,
            instagram,
            facebook,
            twitter,
            youtube,
            tiktok,
        ].contains { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        || extraLinks.contains { !$0.url.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    var allImages: [OrganizerUploadImageDraft] {
        [avatarImage, backgroundImage, posterImage]
            .compactMap { $0 } + proofImages + otherImages
    }

    func image(for zone: OrganizerUploadImageZone) -> OrganizerUploadImageDraft? {
        switch zone {
        case .avatar:
            return avatarImage
        case .background:
            return backgroundImage
        case .poster:
            return posterImage
        case .proof, .other:
            return nil
        }
    }

    func images(for zone: OrganizerUploadImageZone) -> [OrganizerUploadImageDraft] {
        switch zone {
        case .avatar:
            return avatarImage.map { [$0] } ?? []
        case .background:
            return backgroundImage.map { [$0] } ?? []
        case .poster:
            return posterImage.map { [$0] } ?? []
        case .proof:
            return proofImages
        case .other:
            return otherImages
        }
    }

    mutating func appendImage(_ image: OrganizerUploadImageDraft, to zone: OrganizerUploadImageZone) {
        switch zone {
        case .proof:
            proofImages.append(image)
        case .other:
            otherImages.append(image)
        case .avatar, .background, .poster:
            setSingleImage(image, for: zone)
        }
    }

    @discardableResult
    mutating func removeImage(id: UUID, from zone: OrganizerUploadImageZone) -> OrganizerUploadImageDraft? {
        switch zone {
        case .avatar:
            guard avatarImage?.id == id else { return nil }
            defer { avatarImage = nil }
            return avatarImage
        case .background:
            guard backgroundImage?.id == id else { return nil }
            defer { backgroundImage = nil }
            return backgroundImage
        case .poster:
            guard posterImage?.id == id else { return nil }
            defer { posterImage = nil }
            return posterImage
        case .proof:
            guard let index = proofImages.firstIndex(where: { $0.id == id }) else { return nil }
            return proofImages.remove(at: index)
        case .other:
            guard let index = otherImages.firstIndex(where: { $0.id == id }) else { return nil }
            return otherImages.remove(at: index)
        }
    }

    mutating func setSingleImage(_ image: OrganizerUploadImageDraft?, for zone: OrganizerUploadImageZone) {
        switch zone {
        case .avatar:
            avatarImage = image
        case .background:
            backgroundImage = image
        case .poster:
            posterImage = image
        case .proof, .other:
            break
        }
    }

    mutating func setImages(_ images: [OrganizerUploadImageDraft], for zone: OrganizerUploadImageZone) {
        switch zone {
        case .proof:
            proofImages = images
        case .other:
            otherImages = images
        case .avatar:
            avatarImage = images.first
        case .background:
            backgroundImage = images.first
        case .poster:
            posterImage = images.first
        }
    }

    @discardableResult
    mutating func moveImage(id: UUID, in zone: OrganizerUploadImageZone, offset: Int) -> Bool {
        guard offset != 0 else { return false }

        switch zone {
        case .proof:
            return Self.moveImage(id: id, in: &proofImages, offset: offset)
        case .other:
            return Self.moveImage(id: id, in: &otherImages, offset: offset)
        case .avatar, .background, .poster:
            return false
        }
    }

    private static func moveImage(id: UUID, in images: inout [OrganizerUploadImageDraft], offset: Int) -> Bool {
        guard let currentIndex = images.firstIndex(where: { $0.id == id }) else { return false }
        let targetIndex = currentIndex + offset
        guard images.indices.contains(targetIndex) else { return false }
        let image = images.remove(at: currentIndex)
        images.insert(image, at: targetIndex)
        return true
    }

    static func create(initialName: String = "") -> OrganizerUploadDraft {
        var draft = OrganizerUploadDraft()
        let trimmedName = initialName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return draft }
        draft.name = trimmedName
        draft.nameI18n.zh = trimmedName
        draft.nameI18n.en = trimmedName
        draft.descriptionI18n.setValue(draft.introduction, for: draft.preferredLanguage)
        return draft
    }

    static func edit(from brand: WebLearnFestival) -> OrganizerUploadDraft {
        var draft = OrganizerUploadDraft()
        draft.mode = .edit(id: brand.id)
        draft.name = brand.name
        draft.nameI18n = OrganizerUploadMappers.localizedFields(
            name: brand.name,
            i18n: brand.nameI18n
        )
        draft.abbreviation = brand.abbreviation ?? ""
        draft.aliases = brand.aliases
        draft.country = brand.country
        draft.city = brand.city
        draft.foundedYear = brand.foundedYear
        draft.frequency = brand.frequency
        draft.tagline = brand.tagline
        draft.introduction = brand.introduction
        draft.descriptionI18n = OrganizerUploadMappers.localizedFields(
            name: brand.introduction,
            i18n: brand.descriptionI18n
        )
        draft.officialWebsite = brand.officialWebsite ?? ""
        draft.instagram = brand.instagramUrl ?? ""
        draft.facebook = brand.facebookUrl ?? ""
        draft.twitter = brand.twitterUrl ?? ""
        draft.youtube = brand.youtubeUrl ?? ""
        draft.tiktok = brand.tiktokUrl ?? ""
        let reservedURLs = Set(
            [
                brand.officialWebsite,
                brand.instagramUrl,
                brand.facebookUrl,
                brand.twitterUrl,
                brand.youtubeUrl,
                brand.tiktokUrl,
            ]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .filter { !$0.isEmpty }
        )
        draft.extraLinks = brand.links.filter { link in
            let key = link.url.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            return !key.isEmpty && !reservedURLs.contains(key)
        }
        draft.boundEventIDs = []
        draft.baseBrandRevision = brand.revision
        if let avatarURL = brand.avatarUrl?.nilIfBlank {
            draft.avatarImage = OrganizerUploadImageDraft(
                zone: .avatar,
                remoteURL: avatarURL,
                fileName: "avatar",
                mimeType: "image/jpeg",
                ownership: .persistedBrand
            )
        }
        if let backgroundURL = brand.backgroundUrl?.nilIfBlank {
            draft.backgroundImage = OrganizerUploadImageDraft(
                zone: .background,
                remoteURL: backgroundURL,
                fileName: "background",
                mimeType: "image/jpeg",
                ownership: .persistedBrand
            )
        }
        let reservedPublicURLs = Set(
            [draft.avatarImage?.remoteURL, draft.backgroundImage?.remoteURL]
                .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
                .map { $0.lowercased() }
                .filter { !$0.isEmpty }
        )
        let imageAssets = brand.imageAssets ?? []
        draft.posterImage = imageAssets
            .first(where: { asset in
                let type = asset.type?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
                let url = asset.url.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                return type == OrganizerUploadImageZone.poster.backendUsage && !url.isEmpty && !reservedPublicURLs.contains(url)
            })
            .map {
                OrganizerUploadImageDraft(
                    zone: .poster,
                    remoteURL: $0.url,
                    fileName: $0.fileName ?? "poster",
                    mimeType: "image/jpeg",
                    ownership: .persistedBrand
                )
            }
        draft.proofImages = imageAssets.compactMap { asset in
            let type = asset.type?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
            guard type == OrganizerUploadImageZone.proof.backendUsage else { return nil }
            let url = asset.url.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !url.isEmpty else { return nil }
            return OrganizerUploadImageDraft(
                zone: .proof,
                remoteURL: url,
                fileName: asset.fileName ?? "proof",
                mimeType: "image/jpeg",
                ownership: .persistedBrand
            )
        }
        draft.otherImages = imageAssets.compactMap { asset in
            let type = asset.type?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
            guard type == OrganizerUploadImageZone.other.backendUsage else { return nil }
            let url = asset.url.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !url.isEmpty else { return nil }
            return OrganizerUploadImageDraft(
                zone: .other,
                remoteURL: url,
                fileName: asset.fileName ?? "other",
                mimeType: "image/jpeg",
                ownership: .persistedBrand
            )
        }
        return draft
    }
}
