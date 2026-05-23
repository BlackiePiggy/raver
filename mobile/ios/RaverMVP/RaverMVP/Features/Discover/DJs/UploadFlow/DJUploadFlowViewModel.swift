import Foundation
import UIKit

@MainActor
final class DJUploadFlowViewModel: ObservableObject {
    @Published var draft: DJUploadDraft
    @Published var pendingRestoreDraft: DJUploadDraft?
    @Published var errorMessage: String?
    @Published var successMessage: String?
    @Published var isSubmitting = false
    @Published var uploadingZones: Set<DJUploadImageZone> = []

    private let importRepository: DJImportRepository
    private let commandRepository: DJCommandRepository
    private let mediaRepository: DJMediaRepository
    private let store: DJUploadDraftStore
    private let userID: String
    private let onCompleted: ((WebDJ?) -> Void)?

    init(
        mode: DJUploadMode,
        initialDJ: WebDJ?,
        userID: String,
        importRepository: DJImportRepository,
        commandRepository: DJCommandRepository,
        mediaRepository: DJMediaRepository,
        store: DJUploadDraftStore = .shared,
        onCompleted: ((WebDJ?) -> Void)? = nil
    ) {
        self.importRepository = importRepository
        self.commandRepository = commandRepository
        self.mediaRepository = mediaRepository
        self.store = store
        self.userID = userID
        self.onCompleted = onCompleted

        let baseline: DJUploadDraft
        if let initialDJ {
            baseline = DJUploadDraft.edit(from: initialDJ)
        } else {
            baseline = DJUploadDraft.create()
        }
        draft = baseline
        pendingRestoreDraft = store.load(mode: mode, userID: userID)
    }

    func restoreDraft() {
        guard let pendingRestoreDraft else { return }
        draft = pendingRestoreDraft
        self.pendingRestoreDraft = nil
    }

    func discardRestoreDraft() async {
        if let pendingRestoreDraft {
            await deleteDraftImages(in: pendingRestoreDraft)
            store.clear(mode: pendingRestoreDraft.mode, userID: userID)
        }
        pendingRestoreDraft = nil
        saveDraft()
    }

    func markDirty() {
        draft.dirty = true
    }

    func saveDraft() {
        store.save(draft, userID: userID)
    }

    func goNext() {
        guard DJUploadValidation.canAdvance(from: draft.currentStep, draft: draft) else {
            errorMessage = DJUploadValidation.issues(for: draft).first(where: { $0.step == draft.currentStep })?.message
            return
        }
        saveDraft()
        if let next = draft.currentStep.next {
            draft.currentStep = next
            saveDraft()
        }
    }

    func goBack() {
        if let previous = draft.currentStep.previous {
            draft.currentStep = previous
            saveDraft()
        }
    }

    func uploadImage(_ imageData: Data, zone: DJUploadImageZone) async {
        let previous = draft.image(for: zone)
        uploadingZones.insert(zone)
        defer { uploadingZones.remove(zone) }

        do {
            let jpegData = Self.jpegData(from: imageData)
            let response = try await mediaRepository.uploadDJImage(
                imageData: jpegData,
                fileName: "dj-\(zone.rawValue)-\(UUID().uuidString).jpg",
                mimeType: "image/jpeg",
                djID: nil,
                draftID: draft.id.uuidString,
                usage: zone.backendUsage
            )
            draft.setImage(
                DJUploadImageDraft(
                    zone: zone,
                    remoteURL: response.originalUrl ?? response.url,
                    fileName: response.fileName,
                    mimeType: response.mimeType,
                    isPersisted: false
                ),
                for: zone
            )
            draft.dirty = true
            saveDraft()
            if let previous, !previous.isPersisted {
                try? await mediaRepository.deleteDJUploadedImages(draftID: draft.id.uuidString, urls: [previous.remoteURL])
            }
        } catch {
            errorMessage = error.userFacingMessage ?? LT("图片上传失败", "Image upload failed", "画像のアップロードに失敗しました")
        }
    }

    func removeImage(zone: DJUploadImageZone) async {
        guard zone == .banner || zone == .proof else {
            errorMessage = LT("头像为必填，不能删除为空", "Avatar is required and cannot be removed", "アバターは必須です")
            return
        }
        guard let image = draft.image(for: zone) else { return }
        draft.setImage(nil, for: zone)
        draft.dirty = true
        saveDraft()
        if !image.isPersisted {
            try? await mediaRepository.deleteDJUploadedImages(draftID: draft.id.uuidString, urls: [image.remoteURL])
        }
    }

    func submit() async {
        let issues = DJUploadValidation.issues(for: draft)
        guard issues.isEmpty else {
            errorMessage = issues.first?.message
            return
        }

        isSubmitting = true
        defer { isSubmitting = false }

        do {
            switch draft.mode {
            case .create:
                let result = try await importRepository.importManualDJ(input: makeCreateInput())
                store.clear(mode: draft.mode, userID: userID)
                switch result {
                case .submittedForReview:
                    successMessage = LT("DJ 信息已提交审核", "DJ submitted for review", "DJ情報を審査に送信しました")
                    onCompleted?(nil)
                case .imported(let payload):
                    successMessage = LT("DJ 信息已保存", "DJ saved", "DJ情報を保存しました")
                    onCompleted?(payload.dj)
                }
            case .edit(let id):
                let updated = try await commandRepository.updateDJ(id: id, input: makeUpdateInput())
                store.clear(mode: draft.mode, userID: userID)
                successMessage = LT("DJ 信息已更新", "DJ profile updated", "DJプロフィールを更新しました")
                onCompleted?(updated)
            }
        } catch {
            errorMessage = error.userFacingMessage ?? LT("提交失败，请稍后重试", "Submit failed. Please try again.", "送信に失敗しました")
        }
    }

    private func deleteDraftImages(in draft: DJUploadDraft) async {
        let urls = [draft.avatar, draft.banner, draft.proofImage]
            .compactMap { image -> String? in
                guard let image, !image.isPersisted else { return nil }
                return image.remoteURL
            }
        try? await mediaRepository.deleteDJUploadedImages(draftID: draft.id.uuidString, urls: urls)
    }

    private func makeCreateInput() -> ImportManualDJInput {
        ImportManualDJInput(
            name: draft.primaryName,
            nameI18n: webBiText(from: draft.name),
            spotifyId: draft.spotifyId.nilIfBlank,
            aliases: normalizedList(draft.aliases),
            genres: normalizedList(draft.genres),
            bio: draft.bio.primaryValue(preferredLanguage: draft.preferredLanguage).nilIfBlank,
            bioI18n: webBiText(from: draft.bio),
            country: draft.country.primaryValue(preferredLanguage: draft.preferredLanguage).nilIfBlank,
            countryI18n: webBiText(from: draft.country),
            avatarUrl: draft.avatar?.remoteURL,
            bannerUrl: draft.banner?.remoteURL,
            proofImageUrl: draft.proofImage?.remoteURL,
            spotifyUrl: draft.spotifyUrl.nilIfBlank,
            spotifyFollowers: intValue(draft.spotifyFollowers),
            appleMusicId: draft.appleMusicId.nilIfBlank,
            instagramUrl: draft.instagramUrl.nilIfBlank,
            facebookUrl: draft.facebookUrl.nilIfBlank,
            soundcloudUrl: draft.soundcloudUrl.nilIfBlank,
            soundcloudId: draft.soundcloudId.nilIfBlank,
            twitterUrl: draft.twitterUrl.nilIfBlank,
            youtubeUrl: draft.youtubeUrl.nilIfBlank,
            neteaseUrl: draft.neteaseUrl.nilIfBlank,
            qqMusicUrl: draft.qqMusicUrl.nilIfBlank,
            website: draft.website.nilIfBlank,
            otherPlatformUrl: draft.otherPlatformUrl.nilIfBlank,
            trackCount: intValue(draft.trackCount),
            playlistCount: intValue(draft.playlistCount),
            soundCloudFollowers: intValue(draft.soundCloudFollowers),
            soundCloudFavorites: intValue(draft.soundCloudFavorites),
            isVerified: true
        )
    }

    private func makeUpdateInput() -> UpdateDJInput {
        UpdateDJInput(
            name: draft.primaryName,
            nameI18n: webBiText(from: draft.name),
            aliases: normalizedList(draft.aliases),
            genres: normalizedList(draft.genres),
            bio: draft.bio.primaryValue(preferredLanguage: draft.preferredLanguage).nilIfBlank,
            bioI18n: webBiText(from: draft.bio),
            avatarUrl: draft.avatar?.remoteURL,
            bannerUrl: draft.banner?.remoteURL,
            country: draft.country.primaryValue(preferredLanguage: draft.preferredLanguage).nilIfBlank,
            countryI18n: webBiText(from: draft.country),
            spotifyId: draft.spotifyId.nilIfBlank,
            appleMusicId: draft.appleMusicId.nilIfBlank,
            spotifyUrl: draft.spotifyUrl.nilIfBlank,
            spotifyFollowers: intValue(draft.spotifyFollowers),
            instagramUrl: draft.instagramUrl.nilIfBlank,
            facebookUrl: draft.facebookUrl.nilIfBlank,
            soundcloudUrl: draft.soundcloudUrl.nilIfBlank,
            soundcloudId: draft.soundcloudId.nilIfBlank,
            twitterUrl: draft.twitterUrl.nilIfBlank,
            youtubeUrl: draft.youtubeUrl.nilIfBlank,
            neteaseUrl: draft.neteaseUrl.nilIfBlank,
            qqMusicUrl: draft.qqMusicUrl.nilIfBlank,
            website: draft.website.nilIfBlank,
            trackCount: intValue(draft.trackCount),
            playlistCount: intValue(draft.playlistCount),
            soundCloudFollowers: intValue(draft.soundCloudFollowers),
            soundCloudFavorites: intValue(draft.soundCloudFavorites),
            isVerified: true
        )
    }

    private func normalizedList(_ values: [String]) -> [String]? {
        let items = values
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return items.isEmpty ? nil : items
    }

    private func intValue(_ value: String) -> Int? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return Int(trimmed)
    }

    private func webBiText(from fields: EventUploadLocalizedFields) -> WebBiText? {
        guard fields.hasAnyValue else { return nil }
        let primary = fields.primaryValue(preferredLanguage: draft.preferredLanguage)
        return WebBiText(
            en: fields.en.nilIfBlank ?? fields.enFull.nilIfBlank ?? primary,
            zh: fields.zh.nilIfBlank ?? primary,
            ja: fields.ja.nilIfBlank,
            enFull: fields.enFull.nilIfBlank
        )
    }

    private static func jpegData(from data: Data) -> Data {
        guard let image = UIImage(data: data),
              let encoded = image.jpegData(compressionQuality: 0.88) else {
            return data
        }
        return encoded
    }
}
