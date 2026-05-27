import Foundation

struct OrganizerUploadImageDraft: Identifiable, Hashable, Codable {
    var id: UUID = UUID()
    var zone: OrganizerUploadImageZone
    var remoteURL: String
    var fileName: String
    var mimeType: String
    var isPersisted: Bool = false
}

struct OrganizerUploadDraft: Identifiable, Hashable, Codable {
    var id: UUID = UUID()
    var mode: OrganizerUploadMode = .create
    var currentStep: OrganizerUploadStep = .media
    var preferredLanguage: EventUploadPreferredLanguage = .current
    var name: String = ""
    var nameI18n: EventUploadLocalizedFields = EventUploadLocalizedFields()
    var aliases: [String] = []
    var country: String = ""
    var city: String = ""
    var foundedYear: String = ""
    var frequency: String = ""
    var tagline: String = ""
    var introduction: String = ""
    var officialWebsite: String = ""
    var instagram: String = ""
    var facebook: String = ""
    var twitter: String = ""
    var youtube: String = ""
    var tiktok: String = ""
    var avatarImage: OrganizerUploadImageDraft?
    var backgroundImage: OrganizerUploadImageDraft?
    var proofImages: [OrganizerUploadImageDraft] = []
    var otherImages: [OrganizerUploadImageDraft] = []
    var boundEventIDs: [String] = []
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

    var hasAnyLink: Bool {
        [
            officialWebsite,
            instagram,
            facebook,
            twitter,
            youtube,
            tiktok,
        ].contains { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    func images(for zone: OrganizerUploadImageZone) -> [OrganizerUploadImageDraft] {
        switch zone {
        case .avatar:
            return avatarImage.map { [$0] } ?? []
        case .background:
            return backgroundImage.map { [$0] } ?? []
        case .proof:
            return proofImages
        case .other:
            return otherImages
        }
    }

    mutating func setSingleImage(_ image: OrganizerUploadImageDraft?, for zone: OrganizerUploadImageZone) {
        switch zone {
        case .avatar:
            avatarImage = image
        case .background:
            backgroundImage = image
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
        }
    }

    static func create() -> OrganizerUploadDraft {
        OrganizerUploadDraft()
    }

    static func edit(from brand: WebLearnFestival) -> OrganizerUploadDraft {
        var draft = OrganizerUploadDraft()
        draft.mode = .edit(id: brand.id)
        draft.name = brand.name
        draft.nameI18n = OrganizerUploadMappers.localizedFields(
            name: brand.name,
            i18n: brand.nameI18n
        )
        draft.aliases = brand.aliases
        draft.country = brand.country
        draft.city = brand.city
        draft.foundedYear = brand.foundedYear
        draft.frequency = brand.frequency
        draft.tagline = brand.tagline
        draft.introduction = brand.introduction
        draft.officialWebsite = brand.officialWebsite ?? ""
        draft.instagram = brand.instagramUrl ?? ""
        draft.facebook = brand.facebookUrl ?? ""
        draft.twitter = brand.twitterUrl ?? ""
        draft.youtube = brand.youtubeUrl ?? ""
        draft.tiktok = brand.tiktokUrl ?? ""
        draft.boundEventIDs = []
        if let avatarURL = brand.avatarUrl?.nilIfBlank {
            draft.avatarImage = OrganizerUploadImageDraft(
                zone: .avatar,
                remoteURL: avatarURL,
                fileName: "avatar",
                mimeType: "image/jpeg",
                isPersisted: true
            )
        }
        if let backgroundURL = brand.backgroundUrl?.nilIfBlank {
            draft.backgroundImage = OrganizerUploadImageDraft(
                zone: .background,
                remoteURL: backgroundURL,
                fileName: "background",
                mimeType: "image/jpeg",
                isPersisted: true
            )
        }
        return draft
    }
}
