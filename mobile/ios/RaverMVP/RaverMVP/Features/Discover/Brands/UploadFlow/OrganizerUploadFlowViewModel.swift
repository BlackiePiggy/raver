import Foundation

@MainActor
final class OrganizerUploadFlowViewModel: ObservableObject {
    @Published var draft: OrganizerUploadDraft
    @Published var shouldConfirmRestoredDraft = false
    @Published var statusMessage: String?
    @Published var submitSuccess: OrganizerUploadSubmitSuccess?
    @Published var isSubmitting = false

    private let store: OrganizerUploadDraftStore
    private let userID: String
    private let seedBrand: WebLearnFestival?
    private var onDismiss: () -> Void = {}
    private var didDiscardDraft = false

    init(
        mode: OrganizerUploadMode,
        initialBrand: WebLearnFestival? = nil,
        userID: String,
        store: OrganizerUploadDraftStore = .shared
    ) {
        self.store = store
        self.userID = userID
        self.seedBrand = initialBrand

        let baseline: OrganizerUploadDraft
        if let initialBrand {
            baseline = .edit(from: initialBrand)
        } else {
            baseline = .create()
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
        _ = immediate
        store.save(draft, userID: userID)
    }

    func saveDraftAndClose() {
        saveDraft()
        onDismiss()
    }

    func discardDraftAndClose() async {
        didDiscardDraft = true
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
        guard OrganizerUploadValidation.canAdvance(from: draft.currentStep, draft: draft) else {
            statusMessage = OrganizerUploadValidation
                .issues(for: draft)
                .first(where: { $0.step == draft.currentStep })?
                .message
            return
        }
        saveDraft()
        if draft.currentStep == .review {
            submit()
            return
        }
        if let next = draft.currentStep.next {
            draft.currentStep = next
            saveDraft()
        }
    }

    func goBack() {
        guard let previous = draft.currentStep.previous else { return }
        draft.currentStep = previous
        saveDraft()
    }

    private func submit() {
        let issues = OrganizerUploadValidation.issues(for: draft)
        guard issues.isEmpty else {
            if let firstIssue = issues.first {
                draft.currentStep = firstIssue.step
                statusMessage = firstIssue.message
            }
            return
        }

        isSubmitting = true
        defer { isSubmitting = false }

        store.clear(mode: draft.mode, userID: userID)
        draft.dirty = false
        submitSuccess = OrganizerUploadSubmitSuccess(
            title: draft.isCreate
                ? LT("主办方任务已提交", "Organizer Task Submitted", "主催者タスクを送信しました")
                : LT("主办方编辑已提交", "Organizer Edit Submitted", "主催者編集を送信しました"),
            message: LT(
                "当前骨架已打通本地草稿、步骤切换和成功态。下一阶段会接入真实图片上传、审核提交和我的发布状态回写。",
                "The first skeleton now covers local drafts, step switching, and success state. The next phase will connect real media upload, review submission, and My Posts status sync.",
                "この初期骨格でローカル下書き、ステップ切替、成功状態まで通りました。次の段階で画像アップロード、審査送信、マイ投稿状態同期を接続します。"
            )
        )
    }
}

struct OrganizerUploadSubmitSuccess: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let message: String
}
