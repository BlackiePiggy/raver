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
    @Published var failedUploadZones: Set<OrganizerUploadImageZone> = []
    @Published var eventSearchQuery = ""
    @Published var eventSearchResults: [WebEvent] = []
    @Published var isSearchingEvents = false
    @Published var eventSearchFeedback: InlineSearchFeedback = .idle
    @Published var boundEventNameByID: [String: String] = [:]
    @Published var similarBrandResults: [WebLearnFestival] = []
    @Published var isSearchingSimilarBrands = false
    @Published var similarBrandFeedback: InlineSearchFeedback = .idle

    var validationIssues: [OrganizerUploadValidationIssue] {
        OrganizerUploadValidation.issues(for: draft)
    }

    private let wikiRepository: DiscoverWikiRepository
    private let webService: WebFeatureService
    private let store: OrganizerUploadDraftStore
    private let userID: String
    private let seedBrand: WebLearnFestival?
    private let sourceContextID: String?
    private var onDismiss: () -> Void = {}
    private var didDiscardDraft = false
    private var draftSaveTask: Task<Void, Never>?
    private var similarBrandSearchTask: Task<Void, Never>?

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

    func updatePrimaryName(_ value: String) {
        draft.name = value
        draft.nameI18n.setValue(value, for: draft.preferredLanguage)
        draft.dirty = true
        saveDraft(immediate: false)
        scheduleSimilarBrandSearch(for: value)
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

        do {
            let jpegData = Self.jpegData(from: imageData)
            let fileName = "organizer-\(zone.rawValue)-\(UUID().uuidString).jpg"
            let localURL = try store.saveImageData(
                jpegData,
                draftID: draft.id,
                zone: zone,
                fileExtension: "jpg"
            )

            let draftImage = OrganizerUploadImageDraft(
                zone: zone,
                localFileURL: localURL,
                remoteURL: nil,
                fileName: fileName,
                mimeType: "image/jpeg",
                ownership: .pendingLocal
            )

            switch zone {
            case .avatar, .background, .poster:
                draft.setSingleImage(draftImage, for: zone)
            case .proof, .other:
                draft.appendImage(draftImage, to: zone)
            }
            draft.dirty = true
            failedUploadZones.remove(zone)
            saveDraft(immediate: true)

            if let previousSingle, matchesSingleImageZone(zone) {
                await cleanupRemovedImage(previousSingle)
            }

            try await uploadStoredImage(imageID: draftImage.id, zone: zone)
        } catch {
            failedUploadZones.insert(zone)
            statusMessage = error.userFacingMessage ?? LT("图片上传失败", "Image upload failed", "画像のアップロードに失敗しました")
        }
    }

    func removeImage(zone: OrganizerUploadImageZone, imageID: UUID? = nil) async {
        let removed: OrganizerUploadImageDraft?
        switch zone {
        case .avatar, .background, .poster:
            removed = draft.image(for: zone)
            draft.setSingleImage(nil, for: zone)
        case .proof, .other:
            guard let imageID else { return }
            removed = draft.removeImage(id: imageID, from: zone)
        }
        guard let removed else { return }
        draft.dirty = true
        saveDraft(immediate: true)
        reconcileUploadFailureState(for: zone)
        await cleanupRemovedImage(removed)
    }

    func moveImage(id: UUID, in zone: OrganizerUploadImageZone, offset: Int) {
        guard draft.moveImage(id: id, in: zone, offset: offset) else { return }
        draft.dirty = true
        saveDraft(immediate: true)
    }

    func retryImageUpload(zone: OrganizerUploadImageZone, imageID: UUID? = nil) async {
        let resolvedImageID: UUID?
        switch zone {
        case .avatar, .background, .poster:
            resolvedImageID = draft.image(for: zone)?.id
        case .proof, .other:
            resolvedImageID = imageID
        }
        guard let resolvedImageID else { return }

        do {
            try await uploadStoredImage(imageID: resolvedImageID, zone: zone)
        } catch {
            failedUploadZones.insert(zone)
            statusMessage = error.userFacingMessage ?? LT("图片上传失败，请重试。", "Image upload failed. Please retry.", "画像のアップロードに失敗しました。再試行してください。")
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

    func jump(to step: OrganizerUploadStep) {
        guard step != draft.currentStep else { return }
        guard canNavigate(to: step) else {
            if let blockingIssue = firstBlockingIssue(before: step) {
                draft.currentStep = blockingIssue.step
                statusMessage = blockingIssue.message
                saveDraft(immediate: true)
            }
            return
        }
        draft.currentStep = step
        saveDraft(immediate: true)
    }

    func prepareSubmitConfirmation() -> Bool {
        if !uploadingZones.isEmpty {
            draft.currentStep = .media
            statusMessage = LT("仍有图片上传中，请等待上传完成后再提交。", "Some images are still uploading. Wait for them to finish before submitting.", "まだアップロード中の画像があります。完了してから送信してください。")
            return false
        }
        if hasPendingUploadFailure {
            draft.currentStep = .media
            statusMessage = LT("仍有图片上传失败，请先重试后再提交。", "Some images failed to upload. Retry them before submitting.", "アップロードに失敗した画像があります。再試行してから送信してください。")
            return false
        }
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

    func validationIssues(for step: OrganizerUploadStep) -> [OrganizerUploadValidationIssue] {
        validationIssues.filter { $0.step == step }
    }

    func hasIssue(for step: OrganizerUploadStep) -> Bool {
        !validationIssues(for: step).isEmpty
    }

    func isStepCompleted(_ step: OrganizerUploadStep) -> Bool {
        let currentIndex = stepIndex(for: draft.currentStep)
        let targetIndex = stepIndex(for: step)
        guard targetIndex < currentIndex else { return false }
        return !hasIssue(for: step)
    }

    func canNavigate(to step: OrganizerUploadStep) -> Bool {
        let currentIndex = stepIndex(for: draft.currentStep)
        let targetIndex = stepIndex(for: step)
        guard targetIndex > currentIndex else { return true }

        for index in 0..<targetIndex {
            let candidate = OrganizerUploadStep.allCases[index]
            if hasIssue(for: candidate) {
                return false
            }
        }
        return true
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

    func scheduleSimilarBrandSearch(for rawValue: String) {
        let keyword = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        similarBrandSearchTask?.cancel()

        guard keyword.count >= 2 else {
            similarBrandResults = []
            similarBrandFeedback = .idle
            isSearchingSimilarBrands = false
            return
        }

        similarBrandSearchTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 350_000_000)
            guard !Task.isCancelled else { return }
            await self?.searchSimilarBrands(keyword: keyword)
        }
    }

    private func submit() async {
        guard prepareSubmitConfirmation() else { return }

        isSubmitting = true
        defer { isSubmitting = false }

        do {
            do {
                try await uploadPendingImagesIfNeeded()
            } catch {
                statusMessage = error.userFacingMessage ?? LT("仍有图片上传失败，请先重试后再提交。", "Some images still failed to upload. Retry them before submitting.", "まだアップロードに失敗している画像があります。再試行してから送信してください。")
                return
            }
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

            let successSnapshot = organizerSuccessSnapshot(from: result)
            finalizeDraftCleanupAfterSubmit()
            let createdBrand = successSnapshot

            if let createdBrand {
                NotificationCenter.default.post(
                    name: .discoverOrganizerDidSave,
                    object: createdBrand.id,
                    userInfo: ["brand": createdBrand]
                )
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
                        "当前正在处理中，后续会通过通知更新为审核中或已入库。你可以在我的发布里查看状态。",
                        "The task is now processing. Later updates will arrive through notifications and My Posts.",
                        "現在処理中です。以降の更新は通知とマイ投稿で確認できます。"
                    )
                )
            case (.create, .created(_)):
                submitSuccess = OrganizerUploadSubmitSuccess(
                    title: LT("主办方已发布", "Organizer Published", "主催者を公開しました"),
                    message: LT(
                        "主办方资料已经生效，也可以在我的发布里继续管理。",
                        "The organizer profile is now live, and you can keep managing it from My Posts.",
                        "主催者プロフィールは公開されました。マイ投稿からも管理できます。"
                    )
                )
            case (.edit(_), .submittedForReview(_)):
                submitSuccess = OrganizerUploadSubmitSuccess(
                    title: LT("主办方编辑已提交", "Organizer Edit Submitted", "主催者編集を送信しました"),
                    message: LT(
                        "当前正在处理中，后续会通过通知更新为审核中或已入库。你可以在我的发布里查看状态。",
                        "The edit task is now processing. Later updates will arrive through notifications and My Posts.",
                        "編集タスクは現在処理中です。以降の更新は通知とマイ投稿で確認できます。"
                    ),
                    showsReviewPendingDiffNotice: true
                )
            case (.edit(_), .created(let brand)):
                submitSuccess = OrganizerUploadSubmitSuccess(
                    title: LT("主办方已更新", "Organizer Updated", "主催者を更新しました"),
                    message: LT(
                        "更新已保存。你可以返回主办方页面查看最新内容，也可以在我的发布里继续管理。",
                        "Your changes are saved. Return to the organizer page to view the latest content, or manage it from My Posts.",
                        "更新を保存しました。主催者ページで最新内容を確認するか、マイ投稿から管理できます。"
                    ),
                    change: brand.change
                )
            }
        } catch {
            statusMessage = error.userFacingMessage ?? LT("提交失败，请稍后重试。", "Submit failed. Please try again.", "送信に失敗しました。もう一度お試しください。")
        }
    }

    private func deleteDraftImages(in draft: OrganizerUploadDraft) async {
        for image in draft.allImages {
            store.deleteImageFileIfNeeded(image.localFileURL)
        }
        let urls = draft.allImages.compactMap { image -> String? in
            guard image.ownership != .persistedBrand else { return nil }
            return image.remoteURL?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfBlank
        }
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

    private func searchSimilarBrands(keyword: String) async {
        isSearchingSimilarBrands = true
        defer { isSearchingSimilarBrands = false }

        do {
            let items = try await webService.fetchLearnFestivals(search: keyword)
            guard !Task.isCancelled else { return }
            let currentEditID: String?
            if case .edit(let id) = draft.mode {
                currentEditID = id
            } else {
                currentEditID = nil
            }
            similarBrandResults = items
                .filter { item in
                    guard item.id != currentEditID else { return false }
                    return true
                }
                .prefix(5)
                .map { $0 }
            similarBrandFeedback = similarBrandResults.isEmpty
                ? .empty(message: LT("暂未发现已存在的相似主办方。", "No similar organizers found yet.", "類似する既存主催者はまだ見つかっていません。"))
                : .idle
        } catch {
            guard !Task.isCancelled else { return }
            similarBrandResults = []
            similarBrandFeedback = .failure(
                message: error.userFacingMessage ?? LT("相似主办方搜索失败，请稍后重试。", "Failed to search similar organizers. Please try again.", "類似主催者の検索に失敗しました。もう一度お試しください。")
            )
        }
    }

    private func finalizeDraftCleanupAfterSubmit() {
        draftSaveTask?.cancel()
        similarBrandSearchTask?.cancel()
        store.clear(mode: draft.mode, userID: userID)
        draft.dirty = false
        draft.lastSavedAt = nil
        shouldConfirmRestoredDraft = false
        statusMessage = nil
        eventSearchQuery = ""
        eventSearchResults = []
        eventSearchFeedback = .idle
        boundEventNameByID = [:]
        similarBrandResults = []
        similarBrandFeedback = .idle
        uploadingZones = []
        failedUploadZones = []
    }

    private func extractCreatedBrand(from result: CreateContentResult<WebLearnFestival>) -> WebLearnFestival? {
        guard case .created(let brand) = result else { return nil }
        return brand
    }

    private func organizerSuccessSnapshot(from result: CreateContentResult<WebLearnFestival>) -> WebLearnFestival? {
        guard var brand = extractCreatedBrand(from: result) else { return nil }

        let imageAssets = OrganizerUploadMappers.imageAssetsSnapshot(from: draft)
        if let avatar = draft.avatarImage?.remoteURL?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfBlank {
            brand.avatarUrl = avatar
        }
        if let background = draft.backgroundImage?.remoteURL?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfBlank {
            brand.backgroundUrl = background
        }
        brand.imageAssets = imageAssets.isEmpty ? brand.imageAssets : imageAssets
        brand.links = OrganizerUploadMappers.updateInput(from: draft).links ?? brand.links
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

    private func uploadPendingImagesIfNeeded() async throws {
        for zone in OrganizerUploadImageZone.allCases {
            for image in draft.images(for: zone) where image.remoteURL?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfBlank == nil {
                try await uploadStoredImage(imageID: image.id, zone: zone)
            }
        }
    }

    private func uploadStoredImage(imageID: UUID, zone: OrganizerUploadImageZone) async throws {
        guard let image = imageDraft(for: imageID, in: zone),
              let localFileURL = image.localFileURL else { return }

        failedUploadZones.remove(zone)
        uploadingZones.insert(zone)
        defer { uploadingZones.remove(zone) }

        try await webService.prepareAuthenticatedRequestForUserAction(source: "organizer-upload-image")
        let data = try Data(contentsOf: localFileURL)
        let response = try await wikiRepository.uploadWikiBrandImage(
            imageData: data,
            fileName: image.fileName,
            mimeType: image.mimeType,
            brandID: nil,
            draftID: draft.id.uuidString,
            usage: zone.backendUsage
        )

        guard let latest = imageDraft(for: imageID, in: zone) else {
            let cleanupURL = response.originalUrl ?? response.url
            try? await wikiRepository.deleteWikiBrandUploadedImages(
                brandID: nil,
                draftID: draft.id.uuidString,
                urls: [cleanupURL]
            )
            return
        }

        updateUploadedImage(
            latest.id,
            zone: zone,
            remoteURL: response.originalUrl ?? response.url,
            fileName: response.fileName,
            mimeType: response.mimeType,
            ownership: uploadedOwnership
        )
        reconcileUploadFailureState(for: zone)
    }

    private func cleanupRemovedImage(_ image: OrganizerUploadImageDraft) async {
        store.deleteImageFileIfNeeded(image.localFileURL)
        guard image.ownership != .persistedBrand,
              let remoteURL = image.remoteURL?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfBlank else {
            return
        }
        try? await wikiRepository.deleteWikiBrandUploadedImages(
            brandID: nil,
            draftID: draft.id.uuidString,
            urls: [remoteURL]
        )
    }

    private func imageDraft(for imageID: UUID, in zone: OrganizerUploadImageZone) -> OrganizerUploadImageDraft? {
        draft.images(for: zone).first(where: { $0.id == imageID })
    }

    private func updateUploadedImage(
        _ imageID: UUID,
        zone: OrganizerUploadImageZone,
        remoteURL: String,
        fileName: String,
        mimeType: String,
        ownership: OrganizerUploadImageDraft.Ownership
    ) {
        switch zone {
        case .avatar, .background, .poster:
            guard var image = draft.image(for: zone), image.id == imageID else { return }
            image.remoteURL = remoteURL
            image.fileName = fileName
            image.mimeType = mimeType
            image.ownership = ownership
            draft.setSingleImage(image, for: zone)
        case .proof, .other:
            var images = draft.images(for: zone)
            guard let index = images.firstIndex(where: { $0.id == imageID }) else { return }
            images[index].remoteURL = remoteURL
            images[index].fileName = fileName
            images[index].mimeType = mimeType
            images[index].ownership = ownership
            draft.setImages(images, for: zone)
        }
        draft.dirty = true
        saveDraft(immediate: true)
    }

    private var uploadedOwnership: OrganizerUploadImageDraft.Ownership {
        switch draft.mode {
        case .create:
            return .createDraftUploaded
        case .edit:
            return .editDraftUploaded
        }
    }

    private var hasPendingUploadFailure: Bool {
        OrganizerUploadImageZone.allCases.contains { zone in
            draft.images(for: zone).contains { image in
                image.remoteURL?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfBlank == nil
            }
        }
    }

    private func reconcileUploadFailureState(for zone: OrganizerUploadImageZone) {
        let hasUnuploadedImage = draft.images(for: zone).contains { image in
            image.remoteURL?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfBlank == nil
        }
        if hasUnuploadedImage {
            failedUploadZones.insert(zone)
        } else {
            failedUploadZones.remove(zone)
        }
    }

    private func matchesSingleImageZone(_ zone: OrganizerUploadImageZone) -> Bool {
        switch zone {
        case .avatar, .background, .poster:
            return true
        case .proof, .other:
            return false
        }
    }

    private func firstBlockingIssue(before step: OrganizerUploadStep) -> OrganizerUploadValidationIssue? {
        let targetIndex = stepIndex(for: step)
        for index in 0..<targetIndex {
            let candidate = OrganizerUploadStep.allCases[index]
            if let issue = validationIssues(for: candidate).first {
                return issue
            }
        }
        return nil
    }

    private func stepIndex(for step: OrganizerUploadStep) -> Int {
        OrganizerUploadStep.allCases.firstIndex(of: step) ?? 0
    }
}

struct OrganizerUploadSubmitSuccess: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let message: String
    var change: EntityChangeInlineResult? = nil
    var showsReviewPendingDiffNotice = false
}
