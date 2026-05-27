import Foundation
import UIKit

@MainActor
final class OrganizerUploadFlowViewModel: ObservableObject {
    enum InlineSearchFeedback: Equatable {
        case idle
        case empty(message: String)
        case failure(message: String)

        var message: String? {
            switch self {
            case .idle:
                return nil
            case .empty(let message), .failure(let message):
                return message
            }
        }

        var isFailure: Bool {
            if case .failure = self { return true }
            return false
        }
    }

    @Published var draft: OrganizerUploadDraft
    @Published var shouldConfirmRestoredDraft = false
    @Published var statusMessage: String?
    @Published var submitSuccess: OrganizerUploadSubmitSuccess?
    @Published var isSubmitting = false
    @Published var uploadingZones: Set<OrganizerUploadImageZone> = []
    @Published var eventSearchQuery = ""
    @Published var eventSearchResults: [WebEvent] = []
    @Published var isSearchingEvents = false
    @Published var eventSearchFeedback: InlineSearchFeedback = .idle
    @Published var boundEventNameByID: [String: String] = [:]

    private let wikiRepository: DiscoverWikiRepository
    private let webService: WebFeatureService
    private let store: OrganizerUploadDraftStore
    private let userID: String
    private let seedBrand: WebLearnFestival?
    private let sourceContextID: String?
    private var onDismiss: () -> Void = {}
    private var didDiscardDraft = false
    private var draftSaveTask: Task<Void, Never>?

    init(
        mode: OrganizerUploadMode,
        initialBrand: WebLearnFestival? = nil,
        initialName: String? = nil,
        sourceContextID: String? = nil,
        userID: String,
        wikiRepository: DiscoverWikiRepository = DiscoverWikiRepositoryAdapter(
            service: AppEnvironment.sharedWebService,
            socialService: AppEnvironment.sharedService
        ),
        webService: WebFeatureService = AppEnvironment.sharedWebService,
        store: OrganizerUploadDraftStore = .shared
    ) {
        self.wikiRepository = wikiRepository
        self.webService = webService
        self.store = store
        self.userID = userID
        self.seedBrand = initialBrand
        self.sourceContextID = sourceContextID

        let baseline: OrganizerUploadDraft
        if let initialBrand {
            baseline = .edit(from: initialBrand)
        } else {
            baseline = .create(initialName: initialName ?? "")
        }

        if let saved = store.load(mode: mode, userID: userID) {
            draft = saved
            shouldConfirmRestoredDraft = true
        } else {
            draft = baseline
            shouldConfirmRestoredDraft = false
        }

        OrganizerUploadAnalytics.track("organizer_upload_opened", properties: ["mode": draft.mode.storageKey])
    }

    func setDismissAction(_ action: @escaping () -> Void) {
        onDismiss = action
    }

    func continueRestoredDraft() {
        shouldConfirmRestoredDraft = false
    }

    func restartCreateDraft() async {
        draftSaveTask?.cancel()
        await deleteDraftImages(in: draft)
        store.clear(mode: draft.mode, userID: userID)
        if let seedBrand {
            draft = .edit(from: seedBrand)
        } else {
            draft = .create()
        }
        shouldConfirmRestoredDraft = false
    }

    func markDirty() {
        draft.dirty = true
    }

    func saveDraft(immediate: Bool = true) {
        guard !didDiscardDraft else { return }
        draftSaveTask?.cancel()
        if immediate {
            persistDraftNow()
            return
        }
        draftSaveTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                self?.persistDraftNow()
            }
        }
    }

    func saveDraftAndClose() {
        saveDraft()
        onDismiss()
    }

    func discardDraftAndClose() async {
        didDiscardDraft = true
        draftSaveTask?.cancel()
        await deleteDraftImages(in: draft)
        store.clear(mode: draft.mode, userID: userID)
        draft.dirty = false
        shouldConfirmRestoredDraft = false
        onDismiss()
    }

    func uploadImage(_ imageData: Data, zone: OrganizerUploadImageZone) async {
        let previousSingle = draft.image(for: zone)
        uploadingZones.insert(zone)
        defer { uploadingZones.remove(zone) }

        do {
            try await webService.prepareAuthenticatedRequestForUserAction(source: "organizer-upload-image")
            let jpegData = Self.jpegData(from: imageData)
            let response = try await wikiRepository.uploadWikiBrandImage(
                imageData: jpegData,
                fileName: "organizer-\(zone.rawValue)-\(UUID().uuidString).jpg",
                mimeType: "image/jpeg",
                brandID: nil,
                draftID: draft.id.uuidString,
                usage: zone.backendUsage
            )
            let uploaded = OrganizerUploadImageDraft(
                zone: zone,
                remoteURL: response.originalUrl ?? response.url,
                fileName: response.fileName,
                mimeType: response.mimeType,
                isPersisted: false
            )
            switch zone {
            case .avatar, .background:
                draft.setSingleImage(uploaded, for: zone)
            case .proof, .other:
                draft.appendImage(uploaded, to: zone)
            }
            draft.dirty = true
            saveDraft()

            if let previousSingle, !previousSingle.isPersisted {
                try? await wikiRepository.deleteWikiBrandUploadedImages(
                    brandID: nil,
                    draftID: draft.id.uuidString,
                    urls: [previousSingle.remoteURL]
                )
            }
        } catch {
            statusMessage = error.userFacingMessage ?? LT("图片上传失败", "Image upload failed", "画像のアップロードに失敗しました")
        }
    }

    func removeImage(zone: OrganizerUploadImageZone, imageID: UUID? = nil) async {
        let removed: OrganizerUploadImageDraft?
        switch zone {
        case .avatar, .background:
            removed = draft.image(for: zone)
            draft.setSingleImage(nil, for: zone)
        case .proof, .other:
            guard let imageID else { return }
            removed = draft.removeImage(id: imageID, from: zone)
        }
        guard let removed else { return }
        draft.dirty = true
        saveDraft()
        if !removed.isPersisted {
            try? await wikiRepository.deleteWikiBrandUploadedImages(
                brandID: nil,
                draftID: draft.id.uuidString,
                urls: [removed.remoteURL]
            )
        }
    }

    func handleDisappear() {
        guard !didDiscardDraft, submitSuccess == nil else { return }
        saveDraft(immediate: true)
    }

    func closeAfterSuccess() {
        onDismiss()
    }

    func goNext() {
        guard OrganizerUploadValidation.canAdvance(from: draft.currentStep, draft: draft) else {
            statusMessage = OrganizerUploadValidation
                .issues(for: draft)
                .first(where: { $0.step == draft.currentStep })?
                .message
            return
        }
        saveDraft(immediate: true)
        if draft.currentStep == .review {
            return
        }
        if let next = draft.currentStep.next {
            draft.currentStep = next
            saveDraft(immediate: true)
        }
    }

    func goBack() {
        guard let previous = draft.currentStep.previous else { return }
        draft.currentStep = previous
        saveDraft(immediate: true)
    }

    func prepareSubmitConfirmation() -> Bool {
        let issues = OrganizerUploadValidation.issues(for: draft)
        guard issues.isEmpty else {
            if let firstIssue = issues.first {
                draft.currentStep = firstIssue.step
                statusMessage = firstIssue.message
            }
            return false
        }
        saveDraft(immediate: true)
        return true
    }

    func submitAfterConfirmation() {
        Task { await submit() }
    }

    func updateEventSearchQuery(_ value: String) {
        eventSearchQuery = value
        eventSearchFeedback = .idle
        if value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            eventSearchResults = []
        }
    }

    func searchEvents(showEmptyMessage: Bool = true) async {
        let keyword = eventSearchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !keyword.isEmpty else {
            eventSearchResults = []
            eventSearchFeedback = .idle
            if showEmptyMessage {
                statusMessage = LT("请先输入活动名称。", "Enter an event name first.", "先にイベント名を入力してください。")
            }
            return
        }

        isSearchingEvents = true
        defer { isSearchingEvents = false }

        do {
            let page = try await webService.fetchEvents(
                page: 1,
                limit: 12,
                search: keyword,
                eventType: nil,
                status: nil,
                wikiFestivalId: nil
            )
            guard !Task.isCancelled else { return }
            eventSearchResults = page.items
            for event in page.items {
                boundEventNameByID[event.id] = event.name
            }
            if page.items.isEmpty {
                eventSearchFeedback = .empty(message: LT("没有找到匹配活动。", "No matching events found.", "一致するイベントが見つかりませんでした。"))
            } else {
                eventSearchFeedback = .idle
            }
        } catch {
            guard !Task.isCancelled else { return }
            eventSearchResults = []
            eventSearchFeedback = .failure(
                message: error.userFacingMessage ?? LT("搜索活动失败，请稍后重试。", "Failed to search events. Please try again.", "イベント検索に失敗しました。もう一度お試しください。")
            )
        }
    }

    func toggleBoundEvent(_ event: WebEvent) {
        boundEventNameByID[event.id] = event.name
        if let index = draft.boundEventIDs.firstIndex(of: event.id) {
            draft.boundEventIDs.remove(at: index)
        } else {
            draft.boundEventIDs.append(event.id)
        }
        draft.dirty = true
        saveDraft(immediate: true)
    }

    func removeBoundEvent(id: String) {
        draft.boundEventIDs.removeAll { $0 == id }
        draft.dirty = true
        saveDraft(immediate: true)
    }

    private func submit() async {
        guard prepareSubmitConfirmation() else { return }

        isSubmitting = true
        defer { isSubmitting = false }

        do {
            try await webService.prepareAuthenticatedRequestForUserAction(source: "organizer-upload-submit")
            let result: CreateContentResult<WebLearnFestival>
            switch draft.mode {
            case .create:
                result = try await wikiRepository.createLearnFestival(
                    input: OrganizerUploadMappers.createInput(from: draft)
                )
            case .edit(let id):
                result = try await wikiRepository.updateLearnFestival(
                    id: id,
                    input: OrganizerUploadMappers.updateInput(from: draft)
                )
            }

            draftSaveTask?.cancel()
            store.clear(mode: draft.mode, userID: userID)
            draft.dirty = false
            let createdBrand = extractCreatedBrand(from: result)

            if let createdBrand {
                NotificationCenter.default.post(
                    name: .discoverOrganizerDidCreate,
                    object: createdBrand,
                    userInfo: organizerCreatedUserInfo(for: createdBrand)
                )
            }

            switch (draft.mode, result) {
            case (.create, .submittedForReview(_)):
                NotificationCenter.default.post(
                    name: .discoverOrganizerSubmissionQueued,
                    object: nil,
                    userInfo: organizerSubmissionUserInfo()
                )
                submitSuccess = OrganizerUploadSubmitSuccess(
                    title: LT("主办方任务已提交", "Organizer Task Submitted", "主催者タスクを送信しました"),
                    message: LT(
                        "当前正在处理中，后续会通过通知更新为审核中或已入库。你也可以在我的发布里查看状态。",
                        "The task is processing now. Later updates will appear in notifications and My Posts.",
                        "現在処理中です。以降の更新は通知とマイ投稿で確認できます。"
                    )
                )
            case (.create, .created(_)):
                submitSuccess = OrganizerUploadSubmitSuccess(
                    title: LT("主办方已发布", "Organizer Published", "主催者を公開しました"),
                    message: LT(
                        "主办方资料已经生效，也可以在我的发布里继续管理。",
                        "The organizer profile is now live, and you can keep managing it from My Posts.",
                        "主催者プロフィールは公開されました。マイ投稿から引き続き管理できます。"
                    )
                )
            case (.edit(_), .submittedForReview(_)):
                submitSuccess = OrganizerUploadSubmitSuccess(
                    title: LT("主办方编辑已提交", "Organizer Edit Submitted", "主催者編集を送信しました"),
                    message: LT(
                        "当前正在处理中，后续会通过通知更新为审核中或已入库。你也可以在我的发布里查看状态。",
                        "The edit task is processing now. Later updates will appear in notifications and My Posts.",
                        "編集タスクは現在処理中です。以降の更新は通知とマイ投稿で確認できます。"
                    )
                )
            case (.edit(_), .created(_)):
                submitSuccess = OrganizerUploadSubmitSuccess(
                    title: LT("主办方已更新", "Organizer Updated", "主催者を更新しました"),
                    message: LT(
                        "更新已保存。你可以返回主办方页面查看最新内容，也可以在我的发布里继续管理。",
                        "Your changes are saved. Return to the organizer page for the latest content, or manage it from My Posts.",
                        "更新を保存しました。主催者ページで最新内容を確認するか、マイ投稿から管理できます。"
                    )
                )
            }
        } catch {
            statusMessage = error.userFacingMessage ?? LT("提交失败，请稍后重试。", "Submit failed. Please try again.", "送信に失敗しました。もう一度お試しください。")
        }
    }

    private func deleteDraftImages(in draft: OrganizerUploadDraft) async {
        let urls = draft.allImages
            .filter { !$0.isPersisted }
            .map(\.remoteURL)
        guard !urls.isEmpty else { return }
        try? await wikiRepository.deleteWikiBrandUploadedImages(
            brandID: nil,
            draftID: draft.id.uuidString,
            urls: urls
        )
    }

    private func persistDraftNow() {
        store.save(draft, userID: userID)
    }

    private func extractCreatedBrand(from result: CreateContentResult<WebLearnFestival>) -> WebLearnFestival? {
        guard case .created(let brand) = result else { return nil }
        return brand
    }

    private func organizerCreatedUserInfo(for brand: WebLearnFestival) -> [AnyHashable: Any] {
        var userInfo: [AnyHashable: Any] = ["brandID": brand.id]
        if let sourceContextID {
            userInfo["sourceContextID"] = sourceContextID
        }
        return userInfo
    }

    private func organizerSubmissionUserInfo() -> [AnyHashable: Any] {
        var userInfo: [AnyHashable: Any] = [:]
        if let sourceContextID {
            userInfo["sourceContextID"] = sourceContextID
        }
        return userInfo
    }

    private static func jpegData(from data: Data) -> Data {
        guard let image = UIImage(data: data),
              let encoded = image.jpegData(compressionQuality: 0.88) else {
            return data
        }
        return encoded
    }
}

struct OrganizerUploadSubmitSuccess: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let message: String
}
