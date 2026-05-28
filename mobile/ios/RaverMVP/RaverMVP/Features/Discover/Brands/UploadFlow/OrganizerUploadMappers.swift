import Foundation

enum OrganizerUploadMappers {
    static func imageAssetsSnapshot(from draft: OrganizerUploadDraft) -> [WebEventImageAsset] {
        imageAssets(from: draft)
    }

    static func createInput(from draft: OrganizerUploadDraft) -> CreateLearnFestivalInput {
        CreateLearnFestivalInput(
            name: draft.primaryName,
            nameI18n: webBiText(from: draft.nameI18n, preferredLanguage: draft.preferredLanguage),
            abbreviation: normalizedString(draft.abbreviation),
            aliases: normalizedList(draft.aliases),
            country: normalizedString(draft.country),
            city: normalizedString(draft.city),
            foundedYear: normalizedString(draft.foundedYear),
            frequency: normalizedString(draft.frequency),
            tagline: normalizedString(draft.tagline),
            introduction: normalizedString(draft.primaryIntroduction),
            descriptionI18n: webBiText(from: draft.descriptionI18n, preferredLanguage: draft.preferredLanguage),
            officialWebsite: normalizedString(draft.officialWebsite),
            facebookUrl: normalizedString(draft.facebook),
            instagramUrl: normalizedString(draft.instagram),
            twitterUrl: normalizedString(draft.twitter),
            youtubeUrl: normalizedString(draft.youtube),
            tiktokUrl: normalizedString(draft.tiktok),
            avatarUrl: normalizedRemoteURL(draft.avatarImage),
            backgroundUrl: normalizedRemoteURL(draft.backgroundImage),
            proofImageUrl: normalizedRemoteURL(draft.proofImages.first),
            imageAssets: imageAssetsSnapshot(from: draft).nilIfEmpty,
            boundEventIDs: normalizedList(draft.boundEventIDs),
            rightsConfirmed: draft.rightsConfirmed,
            identityConfirmed: draft.identityConfirmed,
            links: normalizedLinks(from: draft).nilIfEmpty
        )
    }

    static func updateInput(from draft: OrganizerUploadDraft) -> UpdateLearnFestivalInput {
        UpdateLearnFestivalInput(
            name: draft.primaryName,
            nameI18n: webBiText(from: draft.nameI18n, preferredLanguage: draft.preferredLanguage, includeEmptyForEdit: true),
            baseBrandRevision: draft.baseBrandRevision,
            editMode: "patch",
            abbreviation: draft.abbreviation.trimmingCharacters(in: .whitespacesAndNewlines),
            aliases: normalizedList(draft.aliases) ?? [],
            country: draft.country.trimmingCharacters(in: .whitespacesAndNewlines),
            city: draft.city.trimmingCharacters(in: .whitespacesAndNewlines),
            foundedYear: draft.foundedYear.trimmingCharacters(in: .whitespacesAndNewlines),
            frequency: draft.frequency.trimmingCharacters(in: .whitespacesAndNewlines),
            tagline: draft.tagline.trimmingCharacters(in: .whitespacesAndNewlines),
            introduction: draft.primaryIntroduction,
            descriptionI18n: webBiText(from: draft.descriptionI18n, preferredLanguage: draft.preferredLanguage, includeEmptyForEdit: true),
            officialWebsite: draft.officialWebsite.trimmingCharacters(in: .whitespacesAndNewlines),
            facebookUrl: draft.facebook.trimmingCharacters(in: .whitespacesAndNewlines),
            instagramUrl: draft.instagram.trimmingCharacters(in: .whitespacesAndNewlines),
            twitterUrl: draft.twitter.trimmingCharacters(in: .whitespacesAndNewlines),
            youtubeUrl: draft.youtube.trimmingCharacters(in: .whitespacesAndNewlines),
            tiktokUrl: draft.tiktok.trimmingCharacters(in: .whitespacesAndNewlines),
            avatarUrl: draft.avatarImage?.remoteURL ?? "",
            backgroundUrl: draft.backgroundImage?.remoteURL ?? "",
            proofImageUrl: draft.proofImages.first?.remoteURL ?? "",
            imageAssets: imageAssetsSnapshot(from: draft),
            boundEventIDs: normalizedList(draft.boundEventIDs) ?? [],
            rightsConfirmed: draft.rightsConfirmed,
            identityConfirmed: draft.identityConfirmed,
            links: normalizedLinks(from: draft)
        )
    }

    static func localizedFields(name: String, i18n: WebBiText?) -> EventUploadLocalizedFields {
        EventUploadLocalizedFields(
            zh: i18n?.zh ?? name,
            en: i18n?.en ?? name,
            ja: i18n?.ja ?? "",
            enFull: i18n?.enFull ?? ""
        )
    }

    static func summary(for draft: OrganizerUploadDraft) -> [String] {
        [
            draft.primaryName,
            draft.country.trimmingCharacters(in: .whitespacesAndNewlines),
            draft.city.trimmingCharacters(in: .whitespacesAndNewlines),
        ].filter { !$0.isEmpty }
    }

    private static func imageAssets(from draft: OrganizerUploadDraft) -> [WebEventImageAsset] {
        OrganizerUploadImageZone.allCases.flatMap { zone in
            draft.images(for: zone).enumerated().reduce(into: [WebEventImageAsset]()) { result, item in
                let (index, image) = item
                let url = image.remoteURL?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                guard !url.isEmpty else { return }
                result.append(WebEventImageAsset(
                    url: url,
                    type: zone.backendUsage,
                    label: zone.title,
                    sort: index,
                    order: index + 1,
                    source: "ios-organizer-upload-v1",
                    fileName: image.fileName
                ))
            }
        }
    }

    private static func normalizedList(_ values: [String]) -> [String]? {
        let items = values
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return items.isEmpty ? nil : items
    }

    private static func normalizedLinks(from draft: OrganizerUploadDraft) -> [LearnFestivalLinkPayload] {
        draft.extraLinks.compactMap { item in
            let title = item.title.trimmingCharacters(in: .whitespacesAndNewlines)
            let url = item.url.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !url.isEmpty else { return nil }
            return LearnFestivalLinkPayload(
                title: title.isEmpty ? inferredLinkTitle(from: url) : title,
                icon: item.icon.trimmingCharacters(in: .whitespacesAndNewlines).nilIfBlank ?? "link",
                url: url
            )
        }
    }

    private static func normalizedString(_ value: String) -> String? {
        value.trimmingCharacters(in: .whitespacesAndNewlines).nilIfBlank
    }

    private static func normalizedRemoteURL(_ image: OrganizerUploadImageDraft?) -> String? {
        guard let remoteURL = image?.remoteURL else { return nil }
        return remoteURL.trimmingCharacters(in: .whitespacesAndNewlines).nilIfBlank
    }

    private static func webBiText(
        from fields: EventUploadLocalizedFields,
        preferredLanguage: EventUploadPreferredLanguage,
        includeEmptyForEdit: Bool = false
    ) -> WebBiText? {
        guard includeEmptyForEdit || fields.hasAnyValue else { return nil }
        let primary = fields.primaryValue(preferredLanguage: preferredLanguage)
        return WebBiText(
            en: fields.en.nilIfBlank ?? fields.enFull.nilIfBlank ?? primary,
            zh: fields.zh.nilIfBlank ?? primary,
            ja: fields.ja.nilIfBlank,
            enFull: fields.enFull.nilIfBlank
        )
    }

    private static func inferredLinkTitle(from rawURL: String) -> String {
        guard let host = URL(string: rawURL)?.host?.trimmingCharacters(in: .whitespacesAndNewlines),
              !host.isEmpty else {
            return "Link"
        }
        let normalized = host
            .replacingOccurrences(of: "www.", with: "")
            .split(separator: ".")
            .first
            .map(String.init)?
            .capitalized
        return normalized?.nilIfBlank ?? "Link"
    }
}

private extension Array {
    var nilIfEmpty: Self? {
        isEmpty ? nil : self
    }
}
