import Foundation
import UIKit

@MainActor
final class DJUploadFlowViewModel: ObservableObject {
    @Published var draft: DJUploadDraft
    @Published var pendingRestoreDraft: DJUploadDraft?
    @Published var shouldConfirmRestoredDraft = false
    @Published var statusMessage: String?
    @Published var submitSuccess: DJUploadSubmitSuccess?
    @Published var isSubmitting = false
    @Published var uploadingZones: Set<DJUploadImageZone> = []

    private let importRepository: DJImportRepository
    private let commandRepository: DJCommandRepository
    private let mediaRepository: DJMediaRepository
    private let store: DJUploadDraftStore
    private let webService: WebFeatureService
    private let userID: String
    private let seedDJ: WebDJ?
    private let onCompleted: ((WebDJ?) -> Void)?
    private var onDismiss: () -> Void = {}
    private var didDiscardDraft = false

    init(
        mode: DJUploadMode,
        initialDJ: WebDJ?,
        userID: String,
        importRepository: DJImportRepository,
        commandRepository: DJCommandRepository,
        mediaRepository: DJMediaRepository,
        webService: WebFeatureService = AppEnvironment.sharedWebService,
        store: DJUploadDraftStore = .shared,
        onCompleted: ((WebDJ?) -> Void)? = nil
    ) {
        self.importRepository = importRepository
        self.commandRepository = commandRepository
        self.mediaRepository = mediaRepository
        self.store = store
        self.webService = webService
        self.userID = userID
        self.seedDJ = initialDJ
        self.onCompleted = onCompleted

        let baseline: DJUploadDraft
        if let initialDJ {
            baseline = DJUploadDraft.edit(from: initialDJ)
        } else {
            baseline = DJUploadDraft.create()
        }
        if let saved = store.load(mode: mode, userID: userID) {
            draft = saved
            pendingRestoreDraft = saved
            shouldConfirmRestoredDraft = true
        } else {
            draft = baseline
            pendingRestoreDraft = nil
            shouldConfirmRestoredDraft = false
        }
    }

    func setDismissAction(_ action: @escaping () -> Void) {
        onDismiss = action
    }

    func continueRestoredDraft() {
        pendingRestoreDraft = nil
        shouldConfirmRestoredDraft = false
    }

    func restartCreateDraft() async {
        if let pendingRestoreDraft {
            await deleteDraftImages(in: pendingRestoreDraft)
            store.clear(mode: pendingRestoreDraft.mode, userID: userID)
        }
        pendingRestoreDraft = nil
        if let seedDJ {
            draft = .edit(from: seedDJ)
        } else {
            draft = .create()
        }
        shouldConfirmRestoredDraft = false
    }

    func markDirty() {
        draft.dirty = true
    }

    func saveDraft() {
        guard !didDiscardDraft else { return }
        store.save(draft, userID: userID)
    }

    func saveDraftAndClose() {
        saveDraft()
        onDismiss()
    }

    func discardDraftAndClose() async {
        didDiscardDraft = true
        await deleteDraftImages(in: draft)
        store.clear(mode: draft.mode, userID: userID)
        draft.dirty = false
        shouldConfirmRestoredDraft = false
        onDismiss()
    }

    func handleDisappear() {
        guard !didDiscardDraft, submitSuccess == nil else { return }
        saveDraft()
    }

    func closeAfterSuccess() {
        onDismiss()
    }

    func goNext() {
        guard DJUploadValidation.canAdvance(from: draft.currentStep, draft: draft) else {
            statusMessage = DJUploadValidation.issues(for: draft).first(where: { $0.step == draft.currentStep })?.message
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
            try await webService.prepareAuthenticatedRequestForUserAction(source: "dj-upload-image")
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
            statusMessage = error.userFacingMessage ?? LT("图片上传失败", "Image upload failed", "画像のアップロードに失敗しました")
        }
    }

    func removeImage(zone: DJUploadImageZone) async {
        guard zone == .banner || zone == .proof else {
            statusMessage = LT("头像为必填，不能删除为空", "Avatar is required and cannot be removed", "アバターは必須です")
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
            if let firstIssue = issues.first {
                draft.currentStep = firstIssue.step
                statusMessage = firstIssue.message
            }
            return
        }

        isSubmitting = true
        defer { isSubmitting = false }

        do {
            try await webService.prepareAuthenticatedRequestForUserAction(source: "dj-upload-submit")
            switch draft.mode {
            case .create:
                let result = try await importRepository.importManualDJ(input: makeCreateInput())
                store.clear(mode: draft.mode, userID: userID)
                draft.dirty = false
                switch result {
                case .submittedForReview:
                    submitSuccess = DJUploadSubmitSuccess(
                        title: LT("任务已提交", "Task Submitted", "タスクを送信しました"),
                        message: LT("当前正在处理中，后续会通过通知更新为审核中或已入库。你可以在我的发布里查看状态。", "The task is now processing. Later updates will arrive through notifications and My Posts.", "現在処理中です。以降の更新は通知とマイ投稿で確認できます。")
                    )
                    onCompleted?(nil)
                case .imported(let payload):
                    submitSuccess = DJUploadSubmitSuccess(
                        title: LT("DJ 已发布", "DJ Published", "DJを公開しました"),
                        message: LT("DJ 资料已经生效，也可以在我的发布里继续管理。", "The DJ profile is now live, and you can keep managing it from My Posts.", "DJプロフィールは公開されました。マイ投稿からも管理できます。")
                    )
                    onCompleted?(payload.dj)
                }
            case .edit(let id):
                let result = try await commandRepository.updateDJ(id: id, input: makeUpdateInput())
                store.clear(mode: draft.mode, userID: userID)
                draft.dirty = false
                switch result {
                case .submittedForReview:
                    submitSuccess = DJUploadSubmitSuccess(
                        title: LT("编辑任务已提交", "Edit Task Submitted", "編集タスクを送信しました"),
                        message: LT("当前正在处理中，后续会通过通知更新为审核中或已入库。你可以在我的发布里查看状态。", "The edit task is now processing. Later updates will arrive through notifications and My Posts.", "編集タスクは現在処理中です。以降の更新は通知とマイ投稿で確認できます。")
                    )
                    onCompleted?(nil)
                case .created(let updated):
                    submitSuccess = DJUploadSubmitSuccess(
                        title: LT("DJ 已更新", "DJ Updated", "DJを更新しました"),
                        message: LT("更新已保存。你可以返回 DJ 页面查看最新内容，也可以在我的发布里继续管理。", "Your changes are saved. Return to the DJ page to view the latest content, or manage it from My Posts.", "更新を保存しました。DJページで最新内容を確認するか、マイ投稿から管理できます。")
                    )
                    onCompleted?(updated)
                }
            }
        } catch {
            statusMessage = error.userFacingMessage ?? LT("提交失败，请稍后重试。", "Submit failed. Please try again.", "送信に失敗しました。もう一度お試しください。")
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

struct DJUploadSubmitSuccess: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let message: String
}
