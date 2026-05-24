import Foundation

@MainActor
final class EventUploadFlowViewModel: ObservableObject {
    struct LineupTimetableAlignmentPrompt: Identifiable, Hashable {
        var id = UUID()
        var message: String
        var alignedLineupArtists: [EventLineupArtistInput]
    }

    enum AIRecognitionKind: String {
        case poster
        case lineup
        case timetable
    }

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

    @Published var draft: EventUploadDraft
    @Published var validationIssues: [EventUploadValidationIssue] = []
    @Published var statusMessage: String?
    @Published var submitSuccess: EventUploadSubmitSuccess?
    @Published var lineupTimetableAlignmentPrompt: LineupTimetableAlignmentPrompt?
    @Published var shouldConfirmRestoredDraft = false
    @Published var timeZoneSearchResults: [EventTimezoneLookupItem] = []
    @Published var organizerSearchResults: [WebLearnFestival] = []
    @Published var djSearchResults: [String: [WebDJ]] = [:]
    @Published var searchingDJKeys: Set<String> = []
    @Published var aiImportDJSearchResults: [String: [WebDJ]] = [:]
    @Published var aiImportSearchingDJKeys: Set<String> = []
    @Published var aiImportDJSearchFeedbacks: [String: InlineSearchFeedback] = [:]
    @Published var isSearchingTimeZones = false
    @Published var isSearchingOrganizers = false
    @Published var timeZoneSearchFeedback: InlineSearchFeedback = .idle
    @Published var organizerSearchFeedback: InlineSearchFeedback = .idle
    @Published var djSearchFeedbacks: [String: InlineSearchFeedback] = [:]
    @Published var isSubmitting = false
    @Published private(set) var runningAIRecognitionKinds: Set<AIRecognitionKind> = []
    @Published private(set) var uploadingImageIDs: Set<UUID> = []
    @Published private(set) var failedImageIDs: Set<UUID> = []

    private let draftStore: EventUploadDraftStore
    private let webService: WebFeatureService
    private let userID: String
    private let seedEvent: WebEvent?
    private let onSaved: (EventUploadSaveOutcome) -> Void
    private var onDismiss: () -> Void
    private var draftSaveTask: Task<Void, Never>?
    private var timeZoneSearchTask: Task<Void, Never>?
    private var organizerSearchTask: Task<Void, Never>?
    private var djSearchTasks: [String: Task<Void, Never>] = [:]
    private var aiRecognitionTasks: [AIRecognitionKind: Task<Void, Never>] = [:]
    private var imageUploadTasks: [UUID: Task<Void, Never>] = [:]
    private var aiRecognitionJobIDs: [AIRecognitionKind: String] = [:]
    private var didDiscardDraft = false

    init(
        mode: EventUploadMode = .create,
        event: WebEvent? = nil,
        userID: String = "current",
        webService: WebFeatureService = AppEnvironment.sharedWebService,
        draftStore: EventUploadDraftStore = .shared,
        onSaved: @escaping (EventUploadSaveOutcome) -> Void = { _ in },
        onDismiss: @escaping () -> Void = {}
    ) {
        self.userID = userID
        self.webService = webService
        self.draftStore = draftStore
        self.seedEvent = event
        self.onSaved = onSaved
        self.onDismiss = onDismiss
        var restoredDraft = false
        if let saved = draftStore.load(mode: mode, userID: userID) {
            if let event, case .edit = mode, !Self.canRestoreEditDraft(saved, for: event) {
                draftStore.clear(mode: mode, userID: userID)
                self.draft = .edit(event: event)
                EventUploadAnalytics.track(
                    "event_upload_v2_stale_edit_draft_discarded",
                    properties: [
                        "mode": mode.storageKeyPart,
                        "draftRevision": saved.incrementalBaseline?.eventRevision.map(String.init) ?? "nil",
                        "eventRevision": event.revision.map(String.init) ?? "nil",
                    ]
                )
            } else {
                self.draft = saved
                restoredDraft = true
            }
        } else if let event {
            self.draft = .edit(event: event)
        } else {
            self.draft = .create()
            self.draft.mode = mode
        }
        self.shouldConfirmRestoredDraft = restoredDraft
        EventUploadAnalytics.track("event_upload_v2_opened", properties: ["mode": draft.mode.storageKeyPart])
    }

    private static func canRestoreEditDraft(_ draft: EventUploadDraft, for event: WebEvent) -> Bool {
        guard let baseline = draft.incrementalBaseline,
              let draftRevision = baseline.eventRevision,
              let eventRevision = event.revision else {
            return false
        }
        guard draftRevision == eventRevision else { return false }

        let baselineStages = normalizedRestoreStages(baseline.stageOrder, hasSlots: !baseline.lineupSlots.isEmpty)
        let eventStages = normalizedRestoreStages(event.stageOrder ?? [], hasSlots: !event.lineupSlots.isEmpty)
        guard baselineStages == eventStages else { return false }

        let baselineSlotIDs = baseline.lineupSlots.compactMap {
            $0.id?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfBlank
        }
        let eventSlotIDs = event.lineupSlots.compactMap {
            $0.id.trimmingCharacters(in: .whitespacesAndNewlines).nilIfBlank
        }
        guard baselineSlotIDs == eventSlotIDs else { return false }

        let baselineArtistIDs = baseline.lineupArtists.compactMap {
            $0.id?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfBlank
        }
        let eventArtistIDs = (event.lineupArtists ?? []).compactMap {
            $0.id.trimmingCharacters(in: .whitespacesAndNewlines).nilIfBlank
        }
        return baselineArtistIDs == eventArtistIDs
    }

    private static func normalizedRestoreStages(_ stages: [String], hasSlots: Bool) -> [String] {
        let normalized = stages.map {
            $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        }
        if normalized.isEmpty, hasSlots {
            return [""]
        }
        return normalized
    }

    func advance() {
        validationIssues = EventUploadValidation.issues(for: draft)
        if draft.currentStep == .review {
            if let firstIssue = validationIssues.first {
                statusMessage = firstIssue.message
                draft.currentStep = firstIssue.step
                return
            }
            Task { await submit() }
            return
        }
        guard EventUploadValidation.canAdvance(from: draft.currentStep, draft: draft) else {
            statusMessage = validationIssues.first(where: { $0.step == draft.currentStep })?.message
            return
        }
        if let next = draft.currentStep.next {
            EventUploadAnalytics.track("event_upload_v2_step_completed", properties: ["step": draft.currentStep.rawValue])
            saveDraft(immediate: true)
            draft.currentStep = next
            EventUploadAnalytics.track("event_upload_v2_step_viewed", properties: ["step": next.rawValue])
            saveDraft(immediate: true)
        }
    }

    func goBack() {
        guard let previous = draft.currentStep.previous else { return }
        draft.currentStep = previous
        EventUploadAnalytics.track("event_upload_v2_step_viewed", properties: ["step": previous.rawValue])
        saveDraft()
    }

    func saveDraft(immediate: Bool = false) {
        guard !didDiscardDraft else { return }
        if !isSubmitting {
            draft.pendingSubmissionIdempotencyKey = nil
        }
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

    func setDismissAction(_ action: @escaping () -> Void) {
        onDismiss = action
    }

    func closeAfterSuccess() {
        onDismiss()
    }

    func saveDraftAndClose() {
        saveDraft(immediate: true)
        onDismiss()
    }

    func discardDraftAndClose() async {
        didDiscardDraft = true
        draftSaveTask?.cancel()
        cancelOutstandingImageUploads()
        await cleanupOwnedRemoteImages()
        draftStore.clear(mode: draft.mode, userID: userID)
        draft.dirty = false
        shouldConfirmRestoredDraft = false
        EventUploadAnalytics.track(
            "event_upload_v2_abandoned",
            properties: [
                "mode": draft.mode.storageKeyPart,
                "currentStep": draft.currentStep.rawValue,
                "hasDraft": "false",
                "discarded": "true",
            ]
        )
        onDismiss()
    }

    func handleDisappear() {
        guard !didDiscardDraft else { return }
        if submitSuccess == nil {
            saveDraft(immediate: true)
        }
        markAbandonedIfNeeded()
    }

    func continueRestoredDraft() {
        shouldConfirmRestoredDraft = false
    }

    func restartCreateDraft() async {
        cancelOutstandingImageUploads()
        await cleanupOwnedRemoteImages()
        let mode = draft.mode
        draftStore.clear(mode: mode, userID: userID)
        if case .edit = mode, let seedEvent {
            draft = .edit(event: seedEvent)
        } else {
            draft = .create()
        }
        draft.mode = mode
        shouldConfirmRestoredDraft = false
        uploadingImageIDs = []
        failedImageIDs = []
        EventUploadAnalytics.track("event_upload_v2_draft_restarted", properties: ["mode": draft.mode.storageKeyPart])
    }

    func markAbandonedIfNeeded() {
        guard submitSuccess == nil, draft.dirty else { return }
        EventUploadAnalytics.track(
            "event_upload_v2_abandoned",
            properties: [
                "mode": draft.mode.storageKeyPart,
                "currentStep": draft.currentStep.rawValue,
                "hasDraft": "true",
            ]
        )
    }

    private func persistDraftNow() {
        guard !didDiscardDraft else { return }
        draftStore.save(draft, userID: userID)
        EventUploadAnalytics.track("event_upload_v2_draft_saved", properties: ["mode": draft.mode.storageKeyPart])
    }

    func submit() async {
        await submit(skipLineupAlignmentPreview: false)
    }

    private func submit(skipLineupAlignmentPreview: Bool) async {
        guard !isSubmitting else { return }
        validationIssues = EventUploadValidation.issues(for: draft)
        if let firstIssue = validationIssues.first {
            draft.currentStep = firstIssue.step
            statusMessage = firstIssue.message
            return
        }

        isSubmitting = true
        defer { isSubmitting = false }
        let idempotencyKey = draft.pendingSubmissionIdempotencyKey ?? UUID().uuidString
        draft.pendingSubmissionIdempotencyKey = idempotencyKey
        saveDraft(immediate: true)
        EventUploadAnalytics.track("event_upload_v2_submit_tapped", properties: ["mode": draft.mode.storageKeyPart])

        do {
            try await webService.prepareAuthenticatedRequestForUserAction(source: "event-upload-submit")
            await waitForOutstandingImageUploads()
            try await uploadPendingImagesIfNeeded()
            switch draft.mode {
            case .create:
                var input = EventUploadMappers.createInput(from: draft)
                input.idempotencyKey = idempotencyKey
                let result = try await webService.createEvent(input: input)
                draftStore.clear(mode: draft.mode, userID: userID)
                switch result {
                case .created:
                    submitSuccess = EventUploadSubmitSuccess(
                        title: LT("活动已发布", "Event Published", "イベントを公開しました"),
                        message: LT("活动已经出现在活动页，也可以在我的发布里继续管理。", "The event is live on the events page. You can also manage it from My Posts.", "イベントページに公開されました。マイ投稿からも管理できます。")
                    )
                    onSaved(.eventMutated(eventID: nil))
                case .submittedForReview:
                    submitSuccess = EventUploadSubmitSuccess(
                        title: LT("任务已提交", "Task Submitted", "タスクを送信しました"),
                        message: LT("当前正在处理中，后续会通过通知更新为审核中或已入库。你可以在我的发布里查看状态。", "The task is now processing. Later updates will arrive through notifications and My Posts.", "現在処理中です。以降の更新は通知とマイ投稿で確認できます。")
                    )
                    onSaved(.submissionQueued(eventID: nil))
                }
            case .edit(let eventID):
                var input = EventUploadMappers.updateInput(from: draft)
                input.idempotencyKey = idempotencyKey
                let result = try await webService.updateEvent(id: eventID, input: input)
                draftStore.clear(mode: draft.mode, userID: userID)
                switch result {
                case .created:
                    submitSuccess = EventUploadSubmitSuccess(
                        title: LT("活动已更新", "Event Updated", "イベントを更新しました"),
                        message: LT("更新已保存。你可以返回活动页查看最新内容，也可以在我的发布里继续管理。", "Your changes are saved. Return to the events page to view the latest content, or manage it from My Posts.", "更新を保存しました。イベントページで最新内容を確認するか、マイ投稿から管理できます。")
                    )
                    onSaved(.eventMutated(eventID: eventID))
                case .submittedForReview:
                    submitSuccess = EventUploadSubmitSuccess(
                        title: LT("编辑任务已提交", "Edit Task Submitted", "編集タスクを送信しました"),
                        message: LT("当前正在处理中，后续会通过通知更新为审核中或已入库。你可以在我的发布里查看状态。", "The edit task is now processing. Later updates will arrive through notifications and My Posts.", "編集タスクは現在処理中です。以降の更新は通知とマイ投稿で確認できます。")
                    )
                    onSaved(.submissionQueued(eventID: eventID))
                }
            }
            EventUploadAnalytics.track("event_upload_v2_submit_succeeded", properties: ["mode": draft.mode.storageKeyPart])
        } catch {
            EventUploadAnalytics.track("event_upload_v2_submit_failed", properties: ["mode": draft.mode.storageKeyPart])
            statusMessage = error.userFacingMessage ?? LT("提交失败，请稍后重试。", "Submit failed. Please try again.", "送信に失敗しました。もう一度お試しください。")
        }
    }

    func applyLineupTimetableAlignmentAndSubmit() {
        guard let prompt = lineupTimetableAlignmentPrompt else { return }
        applyAlignedLineupArtists(prompt.alignedLineupArtists)
        lineupTimetableAlignmentPrompt = nil
        draft.dirty = true
        saveDraft(immediate: true)
        Task { await submit(skipLineupAlignmentPreview: true) }
    }

    func dismissLineupTimetableAlignmentPrompt() {
        lineupTimetableAlignmentPrompt = nil
        statusMessage = LT("请先让阵容和时间表中的 DJ 完全一致，再提交活动。", "Make the lineup and timetable DJs match before submitting.", "送信前にラインナップとタイムテーブルのDJを一致させてください。")
    }

    private func applyAlignedLineupArtists(_ artists: [EventLineupArtistInput]) {
        draft.lineupOnlySlots = artists
            .sorted { lhs, rhs in
                (lhs.sortOrder ?? 0) == (rhs.sortOrder ?? 0)
                    ? lhs.djName < rhs.djName
                    : (lhs.sortOrder ?? 0) < (rhs.sortOrder ?? 0)
            }
            .map { artist in
                let performerNames = (artist.memberNames ?? [])
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
                let actType = alignmentActType(performerCount: max(performerNames.count, 1))
                var slot = EventUploadLineupOnlySlotDraft(
                    canonicalArtistId: artist.id,
                    actType: actType,
                    performerNames: performerNames.isEmpty ? [artist.djName] : performerNames,
                    performerDJIDs: normalizedAlignmentMemberDJIDs(from: artist, performerCount: actType.performerCount),
                    performerAvatarURLs: Array(repeating: nil, count: actType.performerCount)
                )
                slot.normalizePerformers()
                return slot
            }
    }

    private func normalizedAlignmentMemberDJIDs(from artist: EventLineupArtistInput, performerCount: Int) -> [String?] {
        var ids = artist.memberDjIds ?? []
        if ids.isEmpty {
            ids = [artist.djId]
        }
        let normalized = ids.prefix(performerCount).map { id in
            let trimmed = id?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return trimmed.isEmpty ? nil : trimmed
        }
        if normalized.count >= performerCount {
            return Array(normalized)
        }
        return normalized + Array(repeating: nil, count: performerCount - normalized.count)
    }

    private func alignmentActType(performerCount: Int) -> EventLineupActType {
        if performerCount >= 3 { return .b3b }
        if performerCount == 2 { return .b2b }
        return .solo
    }

    func updateLocalizedField(_ keyPath: WritableKeyPath<EventUploadDraft, EventUploadLocalizedFields>, value: String) {
        draft[keyPath: keyPath].setCurrentValue(value, preferredLanguage: draft.preferredLanguage)
        draft.dirty = true
        saveDraft()
    }

    func updateLocalizedField(
        _ keyPath: WritableKeyPath<EventUploadDraft, EventUploadLocalizedFields>,
        language: EventUploadPreferredLanguage,
        value: String
    ) {
        draft[keyPath: keyPath].setValue(value, for: language)
        draft.dirty = true
        saveDraft()
    }

    func updateLocalizedEnglishFullField(
        _ keyPath: WritableKeyPath<EventUploadDraft, EventUploadLocalizedFields>,
        value: String
    ) {
        draft[keyPath: keyPath].enFull = value
        draft.dirty = true
        saveDraft()
    }

    func updateEventType(_ value: String) {
        draft.eventType = value
        draft.dirty = true
        saveDraft()
    }

    func updateAbbreviation(_ value: String) {
        draft.abbreviation = value
        draft.dirty = true
        saveDraft()
    }

    func updateOrganizerName(_ value: String) {
        guard draft.organizerFestivalID == nil else { return }
        draft.organizerName = value
        organizerSearchResults = []
        organizerSearchFeedback = .idle
        draft.dirty = true
        saveDraft()
        scheduleOrganizerSearch()
    }

    func searchOrganizers(showEmptyMessage: Bool = true, useInlineFeedback: Bool = false) async {
        let trimmed = draft.organizerName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            organizerSearchResults = []
            organizerSearchFeedback = .idle
            if showEmptyMessage {
                statusMessage = LT("请先输入主办方名称。", "Enter an organizer name first.", "先に主催者名を入力してください。")
            }
            return
        }
        isSearchingOrganizers = true
        defer { isSearchingOrganizers = false }
        do {
            organizerSearchResults = try await webService.fetchLearnFestivals(search: trimmed)
            if organizerSearchResults.isEmpty {
                let message = LT("没有找到匹配主办方，当前会按手动名称保存。", "No matching organizer found. The current text will be saved as a manual name.", "一致する主催者が見つかりませんでした。現在のテキストを手入力名として保存します。")
                organizerSearchFeedback = .empty(message: message)
                if showEmptyMessage && !useInlineFeedback {
                    statusMessage = message
                }
            } else {
                organizerSearchFeedback = .idle
            }
        } catch {
            organizerSearchResults = []
            let message = error.userFacingMessage ?? LT("搜索主办方失败，请稍后重试。", "Failed to search organizers. Please try again.", "主催者検索に失敗しました。もう一度お試しください。")
            organizerSearchFeedback = .failure(message: message)
            if !useInlineFeedback {
                statusMessage = message
            }
        }
    }

    func applyOrganizer(_ festival: WebLearnFestival) {
        draft.organizerFestivalID = festival.id
        draft.organizerName = festival.nameI18n?.text(for: AppLanguagePreference.current.effectiveLanguage).trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            ? (festival.nameI18n?.text(for: AppLanguagePreference.current.effectiveLanguage) ?? festival.name)
            : festival.name
        organizerSearchResults = []
        organizerSearchFeedback = .idle
        draft.dirty = true
        saveDraft()
        EventUploadAnalytics.track("event_upload_v2_organizer_bound", properties: ["festivalID": festival.id])
    }

    func clearOrganizerBinding() {
        draft.organizerFestivalID = nil
        organizerSearchResults = []
        organizerSearchFeedback = .idle
        draft.dirty = true
        saveDraft()
    }

    func updateSourceURL(_ value: String) {
        draft.sourceURL = value
        draft.dirty = true
        saveDraft()
    }

    func updateScheduleMode(_ mode: EventUploadScheduleMode) {
        draft.scheduleMode = mode
        normalizeWeekRanges(for: mode)
        draft.dirty = true
        saveDraft()
        EventUploadAnalytics.track("event_upload_v2_schedule_mode_changed", properties: ["mode": mode.rawValue])
    }

    func updateDate(_ keyPath: WritableKeyPath<EventUploadDraft, Date>, value: Date) {
        draft[keyPath: keyPath] = normalizedEventDate(value)
        syncWeekRangesWithEventDates()
        draft.dirty = true
        saveDraft()
    }

    func addWeekRange() {
        let anchor = draft.weekRanges.last?.endDate ?? draft.endDate
        let nextStart = normalizedEventDate(addingDays: 1, to: anchor) ?? anchor
        let nextEnd = normalizedEventDate(addingDays: 1, to: nextStart) ?? nextStart
        draft.weekRanges.append(EventUploadWeekRangeDraft(startDate: nextStart, endDate: nextEnd))
        recalculateEventDateBoundsFromWeeks()
        draft.dirty = true
        saveDraft()
    }

    func removeWeekRange(id: UUID) {
        guard draft.weekRanges.count > 1 else { return }
        draft.weekRanges.removeAll { $0.id == id }
        recalculateEventDateBoundsFromWeeks()
        draft.dirty = true
        saveDraft()
    }

    func updateWeekRange(id: UUID, startDate: Date? = nil, endDate: Date? = nil) {
        guard let index = draft.weekRanges.firstIndex(where: { $0.id == id }) else { return }
        if let startDate {
            draft.weekRanges[index].startDate = normalizedEventDate(startDate)
        }
        if let endDate {
            draft.weekRanges[index].endDate = normalizedEventDate(endDate)
        }
        if draft.weekRanges[index].endDate < draft.weekRanges[index].startDate {
            draft.weekRanges[index].endDate = draft.weekRanges[index].startDate
        }
        recalculateEventDateBoundsFromWeeks()
        draft.dirty = true
        saveDraft()
    }

    func updateTimeZoneIdentifier(_ value: String) {
        guard draft.selectedTimeZoneLookup == nil else { return }
        draft.timeZoneIdentifier = value.trimmingCharacters(in: .whitespacesAndNewlines)
        draft.selectedTimeZoneLookup = nil
        timeZoneSearchFeedback = .idle
        draft.dirty = true
        saveDraft()
    }

    func updateTimeZoneSearchQuery(_ value: String) {
        guard draft.selectedTimeZoneLookup == nil else { return }
        draft.timeZoneSearchQuery = value
        draft.selectedTimeZoneLookup = nil
        timeZoneSearchFeedback = .idle
        draft.dirty = true
        saveDraft()
        scheduleTimeZoneSearch()
    }

    func searchEventTimeZones(showEmptyMessage: Bool = true, useInlineFeedback: Bool = false) async {
        let trimmed = draft.timeZoneSearchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            timeZoneSearchResults = []
            timeZoneSearchFeedback = .idle
            if showEmptyMessage {
                statusMessage = LT("请先输入城市名。", "Enter a city first.", "先に都市名を入力してください。")
            }
            return
        }
        isSearchingTimeZones = true
        defer { isSearchingTimeZones = false }
        do {
            let results = try await webService.searchEventTimezones(query: trimmed, limit: 8)
            timeZoneSearchResults = results
            if results.isEmpty {
                let message = LT("没有匹配结果，请尝试英文城市名、州缩写或国家名。", "No matches found. Try an English city name, state code, or country.", "一致する結果がありません。英語の都市名、州コード、または国名でお試しください。")
                timeZoneSearchFeedback = .empty(message: message)
                if showEmptyMessage && !useInlineFeedback {
                    statusMessage = message
                }
            } else {
                timeZoneSearchFeedback = .idle
            }
        } catch {
            timeZoneSearchResults = []
            let message = error.userFacingMessage ?? LT("搜索城市时区失败，请稍后重试。", "Failed to search event timezones. Please try again.", "都市タイムゾーンの検索に失敗しました。もう一度お試しください。")
            timeZoneSearchFeedback = .failure(message: message)
            if !useInlineFeedback {
                statusMessage = message
            }
        }
    }

    func applyTimeZoneSelection(_ item: EventTimezoneLookupItem) {
        rebaseDraftDatesPreservingWallDate(to: item.timezone)
        draft.selectedTimeZoneLookup = item
        draft.timeZoneIdentifier = item.timezone
        draft.timeZoneSearchQuery = item.cityAscii.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? item.city : item.cityAscii
        timeZoneSearchResults = []

        timeZoneSearchFeedback = .idle
        draft.dirty = true
        saveDraft()
        EventUploadAnalytics.track("event_upload_v2_timezone_selected", properties: ["timezone": item.timezone])
    }

    func clearTimeZoneSelection() {
        draft.selectedTimeZoneLookup = nil
        draft.timeZoneSearchQuery = ""
        timeZoneSearchResults = []
        timeZoneSearchFeedback = .idle
        draft.dirty = true
        saveDraft()
    }

    func setTimeZoneSearchSession(
        query: String,
        selectedLookup: EventTimezoneLookupItem?,
        results: [EventTimezoneLookupItem] = [],
        feedback: InlineSearchFeedback = .idle
    ) {
        draft.timeZoneSearchQuery = query
        draft.selectedTimeZoneLookup = selectedLookup
        timeZoneSearchResults = results
        timeZoneSearchFeedback = feedback
    }

    func updateDayRolloverHour(_ value: Int) {
        draft.dayRolloverHour = min(max(value, 0), 12)
        draft.dirty = true
        saveDraft()
    }

    func tapAIPlaceholder() {
        EventUploadAnalytics.track("event_upload_v2_ai_placeholder_tapped", properties: ["step": draft.currentStep.rawValue])
        statusMessage = LT("AI 识别即将支持。", "AI recognition is coming soon.", "AI認識は近日対応予定です。")
    }

    var timetableAIImageCandidates: [EventUploadImageDraft] {
        EventUploadImageZone.allCases.flatMap { zone in
            (draft.imageZones[zone] ?? [])
                .sorted { $0.sortOrder < $1.sortOrder }
        }
    }

    func recognizeTimetableFromImage(_ image: EventUploadImageDraft) async throws -> EventUploadTimetableAIImportResult {
        EventUploadAnalytics.track("event_upload_v2_timetable_ai_started", properties: ["zone": image.zone.rawValue])
        let result = try await withAIRecognitionTask(.timetable) { [self] in
            let job = try await self.createTimetableAIImportJob(for: image)
            self.aiRecognitionJobIDs[.timetable] = job.jobId
            let response = try await self.waitForTimetableAIImportJob(job.jobId)
            let result = self.editableTimetableImportResult(from: response)
            EventUploadAnalytics.track(
                "event_upload_v2_timetable_ai_succeeded",
                properties: ["slotCount": "\(result.slots.count)", "warningCount": "\(result.warnings.count)"]
            )
            return result
        }
        return result
    }

    func recognizeLineupFromImage(_ image: EventUploadImageDraft) async throws -> EventUploadLineupAIImportResult {
        EventUploadAnalytics.track("event_upload_v2_lineup_ai_started", properties: ["zone": image.zone.rawValue])
        let result = try await withAIRecognitionTask(.lineup) { [self] in
            let job = try await self.createLineupAIImportJob(for: image)
            self.aiRecognitionJobIDs[.lineup] = job.jobId
            let response = try await self.waitForLineupAIImportJob(job.jobId)
            let result = self.editableLineupImportResult(from: response)
            EventUploadAnalytics.track(
                "event_upload_v2_lineup_ai_succeeded",
                properties: ["itemCount": "\(result.items.count)", "warningCount": "\(result.warnings.count)"]
            )
            return result
        }
        return result
    }

    func recognizePosterFromImage(_ image: EventUploadImageDraft) async throws -> EventUploadPosterAIImportResult {
        EventUploadAnalytics.track("event_upload_v2_poster_ai_started", properties: ["zone": image.zone.rawValue])
        let result = try await withAIRecognitionTask(.poster) { [self] in
            let remoteURL = try await self.remoteURLForAIImage(image)
            let request = EventPosterAIImportRequest(
                imageUrl: remoteURL,
                fileType: image.mimeType
            )
            let job = try await self.webService.createEventPosterImageImportJob(input: request)
            self.aiRecognitionJobIDs[.poster] = job.jobId
            let response = try await self.waitForPosterAIImportJob(job.jobId)
            let result = self.editablePosterImportResult(from: response.rawJson)
            EventUploadAnalytics.track(
                "event_upload_v2_poster_ai_succeeded",
                properties: ["warningCount": "\(result.warnings.count)"]
            )
            return result
        }
        return result
    }

    func isAIRecognitionRunning(_ kind: AIRecognitionKind) -> Bool {
        runningAIRecognitionKinds.contains(kind)
    }

    func cancelAIRecognition(_ kind: AIRecognitionKind) async {
        aiRecognitionTasks[kind]?.cancel()
        aiRecognitionTasks[kind] = nil
        let jobID = aiRecognitionJobIDs[kind]
        aiRecognitionJobIDs[kind] = nil
        runningAIRecognitionKinds.remove(kind)
        guard let jobID else { return }
        do {
            switch kind {
            case .poster:
                _ = try await webService.cancelEventPosterImageImportJob(id: jobID)
            case .lineup:
                _ = try await webService.cancelEventLineupImageImportJob(id: jobID)
            case .timetable:
                _ = try await webService.cancelEventTimetableImageImportJob(id: jobID)
            }
        } catch {
            statusMessage = error.userFacingMessage ?? LT("取消识别失败，请稍后重试。", "Failed to cancel recognition. Please try again.", "認識のキャンセルに失敗しました。もう一度お試しください。")
        }
    }

    func applyLineupAIImportItems(_ items: [EventUploadLineupAIEditableItem]) {
        guard !items.isEmpty else { return }

        for imported in items {
            let performerNames = lineupAIPerformerNames(from: imported)
            let actType = normalizedActType(imported.actType, performerCount: performerNames.count)
            var slot = EventUploadLineupOnlySlotDraft()
            slot.actType = actType
            slot.performerNames = Array(performerNames.prefix(actType.performerCount))
            while slot.performerNames.count < actType.performerCount {
                slot.performerNames.append("")
            }
            slot.performerDJIDs = lineupAIPerformerDJIDs(from: imported, count: actType.performerCount)
            slot.performerAvatarURLs = lineupAIPerformerAvatarURLs(from: imported, count: actType.performerCount)
            slot.normalizePerformers()
            draft.lineupOnlySlots.append(slot)
        }

        draft.dirty = true
        saveDraft()
        EventUploadAnalytics.track("event_upload_v2_lineup_ai_applied", properties: ["itemCount": "\(items.count)"])
    }

    func applyPosterAIImportResult(_ result: EventUploadPosterAIImportResult) {
        draft.name = result.name
        draft.city = result.city
        draft.detailAddress = result.detailAddress
        draft.country = result.country
        if let timeZoneIdentifier = result.timeZoneIdentifier?.trimmingCharacters(in: .whitespacesAndNewlines), !timeZoneIdentifier.isEmpty {
            draft.timeZoneIdentifier = timeZoneIdentifier
        }
        draft.scheduleMode = result.scheduleMode
        if let startDate = result.startDate {
            draft.startDate = startDate
        }
        if let endDate = result.endDate {
            draft.endDate = endDate
        }
        if !result.weekRanges.isEmpty {
            draft.weekRanges = result.weekRanges
        } else {
            draft.weekRanges = [EventUploadWeekRangeDraft(startDate: draft.startDate, endDate: draft.endDate)]
        }
        draft.ticket.ticketURL = result.ticketURL
        if !result.ticketCurrency.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            draft.ticket.currency = result.ticketCurrency
        }
        draft.ticket.tiers = result.ticketTiers
        draft.dirty = true
        saveDraft()
        EventUploadAnalytics.track("event_upload_v2_poster_ai_applied", properties: ["warningCount": "\(result.warnings.count)"])
    }

    func applyPosterAIEditableResult(_ result: EventUploadPosterAIEditableResult) {
        applyPosterAIImportResult(
            EventUploadPosterAIImportResult(
                name: result.name,
                city: result.city,
                detailAddress: result.detailAddress,
                country: result.country,
                timeZoneIdentifier: result.timeZoneIdentifier,
                timeZoneDisplayName: result.timeZoneDisplayName,
                scheduleMode: result.scheduleMode,
                startDate: result.startDate,
                endDate: result.endDate,
                weekRanges: result.weekRanges,
                ticketURL: result.ticketURL,
                ticketCurrency: result.ticketCurrency,
                ticketTiers: result.ticketTiers,
                warnings: result.warnings,
                unparsedTexts: result.unparsedTexts
            )
        )
        draft.selectedTimeZoneLookup = result.selectedTimeZoneLookup
        draft.timeZoneSearchQuery = result.timeZoneSearchQuery
        draft.dirty = true
        saveDraft()
    }

    func autoMatchLineupAIImportItems(_ items: [EventUploadLineupAIEditableItem]) async -> [EventUploadLineupAIEditableItem] {
        var nextItems = items
        let unresolvedNames = nextItems.flatMap { item in
            lineupAIPerformerNames(from: item)
                .enumerated()
                .compactMap { index, name in
                    let bound = item.performerDJIDs.indices.contains(index)
                        ? item.performerDJIDs[index]?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
                        : false
                    return bound ? nil : name
                }
        }
        guard !unresolvedNames.isEmpty else { return nextItems }

        let resolved = await fetchBatchExactDJMatches(names: unresolvedNames)
        guard !resolved.isEmpty else { return nextItems }

        for itemIndex in nextItems.indices {
            let performerNames = lineupAIPerformerNames(from: nextItems[itemIndex])
            let performerCount = max(performerNames.count, nextItems[itemIndex].actType.performerCount)
            ensureLineupAIImportCapacity(&nextItems[itemIndex], count: performerCount)
            for performerIndex in performerNames.indices {
                let bound = nextItems[itemIndex].performerDJIDs.indices.contains(performerIndex)
                    ? nextItems[itemIndex].performerDJIDs[performerIndex]?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
                    : false
                guard !bound else { continue }
                let key = normalizedDJLookupKey(performerNames[performerIndex])
                guard let candidate = resolved[key] else { continue }
                nextItems[itemIndex].performerDJIDs[performerIndex] = candidate.djId
                nextItems[itemIndex].performerAvatarURLs[performerIndex] = candidate.avatarSmallUrl ?? candidate.avatarMediumUrl ?? candidate.avatarUrl ?? candidate.avatarOriginalUrl
            }
        }

        return nextItems
    }

    func applyTimetableAIImportSlots(_ slots: [EventUploadTimetableAIEditableSlot]) {
        let importSlots = slots
        guard !importSlots.isEmpty else { return }

        var knownStages = draft.stageEntries.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        for stage in importSlots.map(\.stageName) {
            let trimmed = stage.trimmingCharacters(in: .whitespacesAndNewlines)
            let comparable = trimmed.isEmpty ? LT("主舞台", "Main Stage", "メインステージ") : trimmed
            let exists = knownStages.contains { existing in
                let normalizedExisting = existing.isEmpty ? LT("主舞台", "Main Stage", "メインステージ") : existing
                return normalizedExisting.caseInsensitiveCompare(comparable) == .orderedSame
            }
            if !exists {
                draft.stageEntries.append(trimmed)
                knownStages.append(trimmed)
            }
        }

        for imported in importSlots {
            let performerNames = timetableAIPerformerNames(from: imported)
            let actType = normalizedActType(imported.actType, performerCount: performerNames.count)
            var slot = EventUploadLineupSlotDraft()
            slot.actType = actType
            slot.performerNames = Array(performerNames.prefix(actType.performerCount))
            while slot.performerNames.count < actType.performerCount {
                slot.performerNames.append("")
            }
            slot.performerDJIDs = timetableAIPerformerDJIDs(from: imported, count: actType.performerCount)
            slot.performerAvatarURLs = timetableAIPerformerAvatarURLs(from: imported, count: actType.performerCount)
            slot.stageName = imported.stageName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? LT("主舞台", "Main Stage", "メインステージ")
                : imported.stageName.trimmingCharacters(in: .whitespacesAndNewlines)
            slot.dayIndex = max(1, imported.dayIndex)
            slot.startDayOffset = imported.startDayOffset
            slot.endDayOffset = imported.endDayOffset
            slot.startTime = timetableAIClockDate(imported.startTimeText, dayIndex: slot.dayIndex, dayOffset: imported.startDayOffset)
            slot.endTime = timetableAIClockDate(imported.endTimeText, dayIndex: slot.dayIndex, dayOffset: imported.endDayOffset)
            slot.normalizePerformers()
            draft.timetableSlots.append(slot)
        }

        draft.dirty = true
        saveDraft()
        EventUploadAnalytics.track("event_upload_v2_timetable_ai_applied", properties: ["slotCount": "\(importSlots.count)"])
    }

    func autoMatchTimetableAIImportSlots(_ slots: [EventUploadTimetableAIEditableSlot]) async -> [EventUploadTimetableAIEditableSlot] {
        var nextSlots = slots
        let unresolvedNames = nextSlots.flatMap { slot in
            timetableAIPerformerNames(from: slot)
                .enumerated()
                .compactMap { index, name in
                    let bound = slot.performerDJIDs.indices.contains(index)
                        ? slot.performerDJIDs[index]?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
                        : false
                    return bound ? nil : name
                }
        }
        guard !unresolvedNames.isEmpty else { return nextSlots }

        let resolved = await fetchBatchExactDJMatches(names: unresolvedNames)
        guard !resolved.isEmpty else { return nextSlots }

        for slotIndex in nextSlots.indices {
            let performerNames = timetableAIPerformerNames(from: nextSlots[slotIndex])
            let performerCount = max(performerNames.count, nextSlots[slotIndex].actType.performerCount)
            ensureTimetableAIImportCapacity(&nextSlots[slotIndex], count: performerCount)
            for performerIndex in performerNames.indices {
                let bound = nextSlots[slotIndex].performerDJIDs.indices.contains(performerIndex)
                    ? nextSlots[slotIndex].performerDJIDs[performerIndex]?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
                    : false
                guard !bound else { continue }
                let key = normalizedDJLookupKey(performerNames[performerIndex])
                guard let candidate = resolved[key] else { continue }
                nextSlots[slotIndex].performerDJIDs[performerIndex] = candidate.djId
                nextSlots[slotIndex].performerAvatarURLs[performerIndex] = candidate.avatarSmallUrl ?? candidate.avatarMediumUrl ?? candidate.avatarUrl ?? candidate.avatarOriginalUrl
            }
        }

        return nextSlots
    }

    func createTimetableAIImportJob(for image: EventUploadImageDraft) async throws -> EventTimetableImageImportJobResponse {
        let remoteURL = try await remoteURLForAIImage(image)
        let request = EventTimetableImageImportRequest(
            imageUrl: remoteURL,
            fileType: image.mimeType,
            context: timetableAIContext()
        )
        return try await webService.createEventTimetableImageImportJob(input: request)
    }

    func fetchTimetableAIImportJob(id: String) async throws -> EventTimetableImageImportJobResponse {
        try await webService.fetchEventTimetableImageImportJob(id: id)
    }

    func cancelTimetableAIImportJob(id: String) async throws {
        _ = try await webService.cancelEventTimetableImageImportJob(id: id)
    }

    func createLineupAIImportJob(for image: EventUploadImageDraft) async throws -> EventLineupAIImportJobResponse {
        let remoteURL = try await remoteURLForAIImage(image)
        let request = EventLineupAIImportRequest(
            imageUrl: remoteURL,
            fileType: image.mimeType,
            context: lineupAIContext()
        )
        return try await webService.createEventLineupImageImportJob(input: request)
    }

    func fetchLineupAIImportJob(id: String) async throws -> EventLineupAIImportJobResponse {
        try await webService.fetchEventLineupImageImportJob(id: id)
    }

    func cancelLineupAIImportJob(id: String) async throws {
        _ = try await webService.cancelEventLineupImageImportJob(id: id)
    }

    func editableTimetableImportResult(from response: EventTimetableImageImportResponse) -> EventUploadTimetableAIImportResult {
        editableTimetableImportResult(from: response.rawJson)
    }

    func editableLineupImportResult(from response: EventLineupAIImportResponse) -> EventUploadLineupAIImportResult {
        editableLineupImportResult(from: response.rawJson)
    }

    private func waitForTimetableAIImportJob(_ jobId: String) async throws -> EventTimetableImageImportResponse {
        let deadline = Date().addingTimeInterval(10 * 60)
        while Date() < deadline {
            try Task.checkCancellation()
            let job = try await webService.fetchEventTimetableImageImportJob(id: jobId)
            switch job.status {
            case "succeeded":
                if let result = job.result {
                    return result
                }
                throw ServiceError.message(LT("时间表识别结果为空，请稍后重试。", "Timetable recognition returned an empty result. Please try again.", "タイムテーブル認識結果が空です。もう一度お試しください。"))
            case "failed":
                throw ServiceError.message(job.error ?? LT("时间表识别失败，请稍后重试。", "Timetable recognition failed. Please try again later.", "タイムテーブル認識に失敗しました。しばらくしてから再試行してください。"))
            case "cancelled":
                throw CancellationError()
            default:
                try await Task.sleep(nanoseconds: 2_000_000_000)
            }
        }
        throw ServiceError.message(LT("时间表识别等待超时，请稍后在网络稳定时重试。", "Timed out waiting for timetable recognition. Please try again on a stable network.", "タイムテーブル認識の待機がタイムアウトしました。安定したネットワークで再試行してください。"))
    }

    private func waitForLineupAIImportJob(_ jobId: String) async throws -> EventLineupAIImportResponse {
        let deadline = Date().addingTimeInterval(10 * 60)
        while Date() < deadline {
            try Task.checkCancellation()
            let job = try await webService.fetchEventLineupImageImportJob(id: jobId)
            switch job.status {
            case "succeeded":
                if let result = job.result {
                    return result
                }
                throw ServiceError.message(LT("阵容识别结果为空，请稍后重试。", "Lineup recognition returned an empty result. Please try again.", "ラインナップ認識結果が空です。もう一度お試しください。"))
            case "failed":
                throw ServiceError.message(job.error ?? LT("阵容识别失败，请稍后重试。", "Lineup recognition failed. Please try again later.", "ラインナップ認識に失敗しました。しばらくしてから再試行してください。"))
            case "cancelled":
                throw CancellationError()
            default:
                try await Task.sleep(nanoseconds: 2_000_000_000)
            }
        }
        throw ServiceError.message(LT("阵容识别等待超时，请稍后在网络稳定时重试。", "Timed out waiting for lineup recognition. Please try again on a stable network.", "ラインナップ認識の待機がタイムアウトしました。安定したネットワークで再試行してください。"))
    }

    private func waitForPosterAIImportJob(_ jobId: String) async throws -> EventPosterAIImportResponse {
        let deadline = Date().addingTimeInterval(10 * 60)
        var attempt = 0
        while Date() < deadline {
            try Task.checkCancellation()
            attempt += 1
            let job: EventPosterAIImportJobResponse
            do {
                job = try await webService.fetchEventPosterImageImportJob(id: jobId)
            } catch {
                AuthSessionBreadcrumbStore.shared.record(
                    "poster_ai_job.poll_failed",
                    source: "event_upload",
                    path: "/v1/events/poster/import-image/jobs/\(jobId)",
                    error: error,
                    metadata: [
                        "jobId": jobId,
                        "attempt": "\(attempt)"
                    ]
                )
                throw error
            }
            AuthSessionBreadcrumbStore.shared.record(
                "poster_ai_job.polled",
                source: "event_upload",
                path: "/v1/events/poster/import-image/jobs/\(jobId)",
                metadata: [
                    "jobId": jobId,
                    "attempt": "\(attempt)",
                    "status": job.status,
                    "hasResult": job.result == nil ? "false" : "true",
                    "hasError": (job.error?.isEmpty == false) ? "true" : "false"
                ]
            )
            switch job.status {
            case "succeeded":
                if let result = job.result {
                    AuthSessionBreadcrumbStore.shared.record(
                        "poster_ai_job.completed",
                        source: "event_upload",
                        path: "/v1/events/poster/import-image/jobs/\(jobId)",
                        metadata: [
                            "jobId": jobId,
                            "attempt": "\(attempt)",
                            "status": job.status
                        ]
                    )
                    return result
                }
                throw ServiceError.message(LT("活动信息识别结果为空，请稍后重试。", "Poster recognition returned an empty result. Please try again.", "イベント情報認識結果が空です。もう一度お試しください。"))
            case "failed":
                AuthSessionBreadcrumbStore.shared.record(
                    "poster_ai_job.failed",
                    source: "event_upload",
                    path: "/v1/events/poster/import-image/jobs/\(jobId)",
                    metadata: [
                        "jobId": jobId,
                        "attempt": "\(attempt)",
                        "status": job.status,
                        "message": job.error ?? ""
                    ]
                )
                throw ServiceError.message(job.error ?? LT("活动信息识别失败，请稍后重试。", "Poster recognition failed. Please try again later.", "イベント情報認識に失敗しました。しばらくしてから再試行してください。"))
            case "cancelled":
                throw CancellationError()
            default:
                try await Task.sleep(nanoseconds: 2_000_000_000)
            }
        }
        AuthSessionBreadcrumbStore.shared.record(
            "poster_ai_job.timeout",
            source: "event_upload",
            path: "/v1/events/poster/import-image/jobs/\(jobId)",
            metadata: [
                "jobId": jobId,
            ]
        )
        throw ServiceError.message(LT("活动信息识别等待超时，请稍后在网络稳定时重试。", "Timed out waiting for poster recognition. Please try again on a stable network.", "イベント情報認識の待機がタイムアウトしました。安定したネットワークで再試行してください。"))
    }

    private func fetchBatchExactDJMatches(names: [String]) async -> [String: DJExactMatchItem] {
        do {
            let matches = try await webService.matchExactDJs(names: names)
            var resolved: [String: DJExactMatchItem] = [:]
            for match in matches {
                resolved[normalizedDJLookupKey(match.query)] = match
                resolved[normalizedDJLookupKey(match.name)] = match
                for alias in match.aliases ?? [] {
                    resolved[normalizedDJLookupKey(alias)] = match
                }
            }
            return resolved
        } catch {
            return [:]
        }
    }

    private func withAIRecognitionTask<T>(
        _ kind: AIRecognitionKind,
        operation: @escaping @MainActor () async throws -> T
    ) async throws -> T {
        aiRecognitionTasks[kind]?.cancel()
        aiRecognitionJobIDs[kind] = nil
        runningAIRecognitionKinds.insert(kind)

        let task = Task<T, Error> {
            try await operation()
        }
        aiRecognitionTasks[kind] = Task<Void, Never> {
            _ = try? await task.value
        }

        do {
            let value = try await task.value
            aiRecognitionTasks[kind] = nil
            aiRecognitionJobIDs[kind] = nil
            runningAIRecognitionKinds.remove(kind)
            return value
        } catch is CancellationError {
            aiRecognitionTasks[kind] = nil
            aiRecognitionJobIDs[kind] = nil
            runningAIRecognitionKinds.remove(kind)
            throw ServiceError.message(LT("已取消当前识别任务。", "Current recognition task cancelled.", "現在の認識タスクをキャンセルしました。"))
        } catch {
            aiRecognitionTasks[kind] = nil
            aiRecognitionJobIDs[kind] = nil
            runningAIRecognitionKinds.remove(kind)
            throw error
        }
    }

    func searchTimetableAIImportDJ(query: String, key: String, useInlineFeedback: Bool = false) async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            aiImportDJSearchResults[key] = []
            aiImportDJSearchFeedbacks[key] = .idle
            return
        }
        aiImportSearchingDJKeys.insert(key)
        defer { aiImportSearchingDJKeys.remove(key) }
        do {
            let page = try await webService.fetchDJs(page: 1, limit: 8, search: trimmed, sortBy: "relevance")
            aiImportDJSearchResults[key] = page.items
            if page.items.isEmpty {
                let message = LT("未找到匹配 DJ，可继续使用手动名称。", "No matching DJs found. You can keep the manual name.", "一致するDJが見つかりません。手入力名のまま続行できます。")
                aiImportDJSearchFeedbacks[key] = .empty(message: message)
                if !useInlineFeedback {
                    statusMessage = message
                }
            } else {
                aiImportDJSearchFeedbacks[key] = .idle
            }
        } catch {
            aiImportDJSearchResults[key] = []
            let message = error.userFacingMessage ?? LT("搜索 DJ 失败，请稍后重试。", "Failed to search DJs. Please try again.", "DJ検索に失敗しました。もう一度お試しください。")
            aiImportDJSearchFeedbacks[key] = .failure(message: message)
            if !useInlineFeedback {
                statusMessage = message
            }
        }
    }

    var locationSummary: String {
        let language = draft.preferredLanguage
        let address = draft.detailAddress.primaryValue(preferredLanguage: language)
        let city = draft.city.primaryValue(preferredLanguage: language)
        let country = draft.country.primaryValue(preferredLanguage: language)
        let parts = [address, city, country]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return parts.isEmpty ? LT("尚未填写地址", "No address yet", "住所未入力") : parts.joined(separator: " · ")
    }

    var coordinateSummary: String? {
        guard let latitude = draft.latitude, let longitude = draft.longitude else { return nil }
        return String(format: "%.6f, %.6f", latitude, longitude)
    }

    var reviewDateRange: String {
        draft.startDate.appLocalizedDateRangeText(to: draft.endDate, timeZone: eventTimeZone)
    }

    func tapLocationPickerPlaceholder() {
        EventUploadAnalytics.track("event_upload_v2_location_picker_placeholder_tapped", properties: ["step": draft.currentStep.rawValue])
        statusMessage = LT("地图选点会在下一步接入。当前可先保存手动地址。", "Map picking will be wired next. Manual address is saved for now.", "地図選択は次に接続します。今は手入力住所を保存できます。")
    }

    func applyLocationPickerResult(_ result: EventLocationPickerResult) {
        draft.latitude = result.latitude
        draft.longitude = result.longitude
        draft.pickedMapAddress = result.displayAddress
        draft.pickedPlaceName = result.placeName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        let language = draft.preferredLanguage
        if let city = result.city?.trimmingCharacters(in: .whitespacesAndNewlines), !city.isEmpty,
           draft.city.primaryValue(preferredLanguage: language).trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            draft.city.setCurrentValue(city, preferredLanguage: language)
        }
        if let country = result.country?.trimmingCharacters(in: .whitespacesAndNewlines), !country.isEmpty,
           draft.country.primaryValue(preferredLanguage: language).trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            draft.country.setCurrentValue(country, preferredLanguage: language)
        }

        draft.dirty = true
        saveDraft()
        EventUploadAnalytics.track("event_upload_v2_location_picked", properties: ["hasCoordinate": "true"])
    }

    func clearLocationBinding() {
        draft.latitude = nil
        draft.longitude = nil
        draft.pickedMapAddress = ""
        draft.pickedPlaceName = ""
        draft.dirty = true
        saveDraft()
    }

    func updateCoordinate(_ keyPath: WritableKeyPath<EventUploadDraft, Double?>, rawValue: String) {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        draft[keyPath: keyPath] = trimmed.isEmpty ? nil : Double(trimmed)
        draft.dirty = true
        saveDraft()
    }

    func updateTicketField(_ keyPath: WritableKeyPath<EventUploadTicketDraft, String>, value: String) {
        var next = value
        if keyPath == \EventUploadTicketDraft.currency {
            next = value.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        }
        draft.ticket[keyPath: keyPath] = next
        draft.dirty = true
        saveDraft()
    }

    @discardableResult
    func addTicketTier() -> UUID {
        let tier = EventUploadTicketTierDraft()
        draft.ticket.tiers.append(tier)
        draft.dirty = true
        saveDraft()
        return tier.id
    }

    func removeTicketTier(id: UUID) {
        draft.ticket.tiers.removeAll { $0.id == id }
        draft.dirty = true
        saveDraft()
    }

    func updateTicketTier(id: UUID, mutate: (inout EventUploadTicketTierDraft) -> Void) {
        guard let index = draft.ticket.tiers.firstIndex(where: { $0.id == id }) else { return }
        mutate(&draft.ticket.tiers[index])
        draft.dirty = true
        saveDraft()
    }

    func addStage() {
        draft.stageEntries.append("")
        draft.dirty = true
        saveDraft()
        EventUploadAnalytics.track("event_upload_v2_stage_added", properties: ["count": "\(draft.stageEntries.count)"])
    }

    func updateStage(at index: Int, value: String) {
        guard draft.stageEntries.indices.contains(index) else { return }
        draft.stageEntries[index] = value
        draft.dirty = true
        saveDraft()
    }

    func normalizedStageName(at index: Int) -> String {
        guard draft.stageEntries.indices.contains(index) else {
            return LT("主舞台", "Main Stage", "メインステージ")
        }
        let trimmed = draft.stageEntries[index].trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? LT("主舞台", "Main Stage", "メインステージ") : trimmed
    }

    func removeStage(at index: Int) {
        guard draft.stageEntries.indices.contains(index) else { return }
        let removedStage = normalizedStageName(at: index)
        draft.stageEntries.remove(at: index)
        if draft.stageEntries.isEmpty {
            draft.timetableSlots.removeAll()
        } else {
            draft.timetableSlots.removeAll { slot in
                let stage = slot.stageName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    ? LT("主舞台", "Main Stage", "メインステージ")
                    : slot.stageName
                return stage == removedStage
            }
        }
        draft.dirty = true
        saveDraft()
        EventUploadAnalytics.track("event_upload_v2_stage_removed", properties: ["count": "\(draft.stageEntries.count)"])
    }

    func moveStage(at index: Int, direction: Int) {
        let target = index + direction
        guard draft.stageEntries.indices.contains(index),
              draft.stageEntries.indices.contains(target),
              index != target else { return }
        draft.stageEntries.swapAt(index, target)
        draft.dirty = true
        saveDraft()
        EventUploadAnalytics.track("event_upload_v2_stage_reordered", properties: ["count": "\(draft.stageEntries.count)"])
    }

    var stageNameValidationMessage: String? {
        let normalized = draft.stageEntries.enumerated().map { index, value in
            normalizedStageName(at: index).trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        }
        let unique = Set(normalized)
        guard unique.count == normalized.count else {
            return LT("不同舞台不能使用相同名称；空舞台名都会视为主舞台。", "Stage names must be unique. Empty stage names all count as Main Stage.", "ステージ名は重複できません。空欄はすべてメインステージ扱いです。")
        }
        return nil
    }

    var canOpenTimetableWeekEditor: Bool {
        stageNameValidationMessage == nil
    }

    func tapLineupImportPlaceholder() {
        EventUploadAnalytics.track("event_upload_v2_lineup_import_placeholder_tapped", properties: ["step": draft.currentStep.rawValue])
        statusMessage = LT("阵容图识别会在后续接入。当前可以先维护舞台。", "Lineup image import will be wired later. You can set up stages for now.", "ラインナップ画像認識は後続で接続します。今はステージを設定できます。")
    }

    @discardableResult
    func addTimetableSlot() -> UUID {
        ensureDefaultStageExistsIfNeeded()
        var slot = EventUploadLineupSlotDraft()
        slot.stageName = normalizedStageName(at: 0)
        slot.startDayOffset = .sameDay
        slot.endDayOffset = .sameDay
        slot.startTime = defaultLineupStartTime(dayIndex: 1)
        slot.endTime = defaultLineupEndTime(dayIndex: 1)
        draft.timetableSlots.append(slot)
        draft.dirty = true
        saveDraft()
        EventUploadAnalytics.track("event_upload_v2_lineup_slot_added", properties: ["count": "\(draft.timetableSlots.count)"])
        return slot.id
    }

    @discardableResult
    func addTimetableSlot(stageName: String, dayIndex: Int) -> UUID {
        ensureDefaultStageExistsIfNeeded()
        var slot = EventUploadLineupSlotDraft()
        let trimmedStage = stageName.trimmingCharacters(in: .whitespacesAndNewlines)
        slot.stageName = trimmedStage.isEmpty ? normalizedStageName(at: 0) : trimmedStage
        slot.dayIndex = max(dayIndex, 1)
        slot.startDayOffset = .sameDay
        slot.endDayOffset = .sameDay
        slot.startTime = defaultLineupStartTime(dayIndex: slot.dayIndex)
        slot.endTime = defaultLineupEndTime(dayIndex: slot.dayIndex)
        draft.timetableSlots.append(slot)
        draft.dirty = true
        saveDraft()
        EventUploadAnalytics.track(
            "event_upload_v2_lineup_slot_added",
            properties: [
                "count": "\(draft.timetableSlots.count)",
                "stage": slot.stageName,
                "dayIndex": "\(slot.dayIndex)",
            ]
        )
        return slot.id
    }

    func removeTimetableSlot(id: UUID) {
        draft.timetableSlots.removeAll { $0.id == id }
        draft.dirty = true
        saveDraft()
        EventUploadAnalytics.track("event_upload_v2_lineup_slot_removed", properties: ["count": "\(draft.timetableSlots.count)"])
    }

    func updateTimetableSlot(id: UUID, mutate: (inout EventUploadLineupSlotDraft) -> Void) {
        guard let index = draft.timetableSlots.firstIndex(where: { $0.id == id }) else { return }
        mutate(&draft.timetableSlots[index])
        draft.timetableSlots[index].normalizePerformers()
        draft.dirty = true
        saveDraft()
    }

    func setTimetableSlotTimed(id: UUID, isTimed: Bool) {
        updateTimetableSlot(id: id) { slot in
            if isTimed {
                slot.startTime = defaultLineupStartTime(dayIndex: slot.dayIndex)
                slot.endTime = defaultLineupEndTime(dayIndex: slot.dayIndex)
                slot.startDayOffset = .sameDay
                slot.endDayOffset = .sameDay
            } else {
                slot.startTime = nil
                slot.endTime = nil
                slot.startDayOffset = .sameDay
                slot.endDayOffset = .sameDay
            }
        }
    }

    @discardableResult
    func addLineupOnlySlot() -> UUID {
        var slot = EventUploadLineupOnlySlotDraft()
        slot.normalizePerformers()
        draft.lineupOnlySlots.append(slot)
        draft.dirty = true
        saveDraft()
        return slot.id
    }

    func removeLineupOnlySlot(id: UUID) {
        draft.lineupOnlySlots.removeAll { $0.id == id }
        draft.dirty = true
        saveDraft()
    }

    func updateLineupOnlySlot(id: UUID, mutate: (inout EventUploadLineupOnlySlotDraft) -> Void) {
        guard let index = draft.lineupOnlySlots.firstIndex(where: { $0.id == id }) else { return }
        mutate(&draft.lineupOnlySlots[index])
        draft.lineupOnlySlots[index].normalizePerformers()
        draft.dirty = true
        saveDraft()
    }

    func searchTimetableDJ(slotID: UUID, performerIndex: Int, useInlineFeedback: Bool = false) async {
        guard let slot = draft.timetableSlots.first(where: { $0.id == slotID }),
              slot.performerNames.indices.contains(performerIndex) else { return }
        let query = slot.performerNames[performerIndex].trimmingCharacters(in: .whitespacesAndNewlines)
        let key = djSearchKey(slotID: slotID, performerIndex: performerIndex)
        guard !query.isEmpty else {
            djSearchResults[key] = []
            djSearchFeedbacks[key] = .idle
            if !useInlineFeedback {
                statusMessage = LT("请先输入 DJ 名称。", "Enter a DJ name first.", "先にDJ名を入力してください。")
            }
            return
        }
        searchingDJKeys.insert(key)
        defer { searchingDJKeys.remove(key) }
        do {
            let page = try await webService.fetchDJs(page: 1, limit: 8, search: query, sortBy: "relevance")
            djSearchResults[key] = page.items
            if page.items.isEmpty {
                let message = LT("未找到匹配 DJ，可继续使用手动名称。", "No matching DJs found. You can keep the manual name.", "一致するDJが見つかりません。手入力名のまま続行できます。")
                djSearchFeedbacks[key] = .empty(message: message)
                if !useInlineFeedback {
                    statusMessage = message
                }
            } else {
                djSearchFeedbacks[key] = .idle
            }
        } catch {
            djSearchResults[key] = []
            let message = error.userFacingMessage ?? LT("搜索 DJ 失败，请稍后重试。", "Failed to search DJs. Please try again.", "DJ検索に失敗しました。もう一度お試しください。")
            djSearchFeedbacks[key] = .failure(message: message)
            if !useInlineFeedback {
                statusMessage = message
            }
        }
    }

    func scheduleTimetableDJSearch(slotID: UUID, performerIndex: Int) {
        let key = djSearchKey(slotID: slotID, performerIndex: performerIndex)
        djSearchTasks[key]?.cancel()
        guard let slot = draft.timetableSlots.first(where: { $0.id == slotID }),
              slot.performerNames.indices.contains(performerIndex),
              !slot.performerNames[performerIndex].trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            djSearchResults[key] = []
            djSearchFeedbacks[key] = .idle
            return
        }
        djSearchTasks[key] = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 350_000_000)
            guard !Task.isCancelled else { return }
            await self?.searchTimetableDJ(slotID: slotID, performerIndex: performerIndex, useInlineFeedback: true)
        }
    }

    func applyTimetableDJ(_ dj: WebDJ, slotID: UUID, performerIndex: Int) {
        updateTimetableSlot(id: slotID) { slot in
            while slot.performerNames.count <= performerIndex {
                slot.performerNames.append("")
            }
            while slot.performerDJIDs.count <= performerIndex {
                slot.performerDJIDs.append(nil)
            }
            while slot.performerAvatarURLs.count <= performerIndex {
                slot.performerAvatarURLs.append(nil)
            }
            slot.performerNames[performerIndex] = dj.name
            slot.performerDJIDs[performerIndex] = dj.id
            slot.performerAvatarURLs[performerIndex] = dj.avatarSmallUrl ?? dj.avatarMediumUrl ?? dj.avatarUrl ?? dj.avatarOriginalUrl
        }
        djSearchResults[djSearchKey(slotID: slotID, performerIndex: performerIndex)] = []
        djSearchFeedbacks[djSearchKey(slotID: slotID, performerIndex: performerIndex)] = .idle
        EventUploadAnalytics.track("event_upload_v2_lineup_dj_bound", properties: ["slotID": slotID.uuidString])
    }

    func clearTimetableDJBinding(slotID: UUID, performerIndex: Int) {
        updateTimetableSlot(id: slotID) { slot in
            while slot.performerDJIDs.count <= performerIndex {
                slot.performerDJIDs.append(nil)
            }
            while slot.performerAvatarURLs.count <= performerIndex {
                slot.performerAvatarURLs.append(nil)
            }
            slot.performerDJIDs[performerIndex] = nil
            slot.performerAvatarURLs[performerIndex] = nil
        }
        djSearchFeedbacks[djSearchKey(slotID: slotID, performerIndex: performerIndex)] = .idle
    }

    func searchLineupOnlyDJ(slotID: UUID, performerIndex: Int, useInlineFeedback: Bool = false) async {
        guard let slot = draft.lineupOnlySlots.first(where: { $0.id == slotID }),
              slot.performerNames.indices.contains(performerIndex) else { return }
        let query = slot.performerNames[performerIndex].trimmingCharacters(in: .whitespacesAndNewlines)
        let key = djSearchKey(slotID: slotID, performerIndex: performerIndex)
        guard !query.isEmpty else {
            djSearchResults[key] = []
            djSearchFeedbacks[key] = .idle
            if !useInlineFeedback {
                statusMessage = LT("请先输入 DJ 名称。", "Enter a DJ name first.", "先にDJ名を入力してください。")
            }
            return
        }
        searchingDJKeys.insert(key)
        defer { searchingDJKeys.remove(key) }
        do {
            let page = try await webService.fetchDJs(page: 1, limit: 8, search: query, sortBy: "relevance")
            djSearchResults[key] = page.items
            if page.items.isEmpty {
                let message = LT("未找到匹配 DJ，可继续使用手动名称。", "No matching DJs found. You can keep the manual name.", "一致するDJが見つかりません。手入力名のまま続行できます。")
                djSearchFeedbacks[key] = .empty(message: message)
                if !useInlineFeedback {
                    statusMessage = message
                }
            } else {
                djSearchFeedbacks[key] = .idle
            }
        } catch {
            djSearchResults[key] = []
            let message = error.userFacingMessage ?? LT("搜索 DJ 失败，请稍后重试。", "Failed to search DJs. Please try again.", "DJ検索に失敗しました。もう一度お試しください。")
            djSearchFeedbacks[key] = .failure(message: message)
            if !useInlineFeedback {
                statusMessage = message
            }
        }
    }

    func scheduleLineupOnlyDJSearch(slotID: UUID, performerIndex: Int) {
        let key = djSearchKey(slotID: slotID, performerIndex: performerIndex)
        djSearchTasks[key]?.cancel()
        guard let slot = draft.lineupOnlySlots.first(where: { $0.id == slotID }),
              slot.performerNames.indices.contains(performerIndex),
              !slot.performerNames[performerIndex].trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            djSearchResults[key] = []
            djSearchFeedbacks[key] = .idle
            return
        }
        djSearchTasks[key] = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 350_000_000)
            guard !Task.isCancelled else { return }
            await self?.searchLineupOnlyDJ(slotID: slotID, performerIndex: performerIndex, useInlineFeedback: true)
        }
    }

    func applyLineupOnlyDJ(_ dj: WebDJ, slotID: UUID, performerIndex: Int) {
        updateLineupOnlySlot(id: slotID) { slot in
            while slot.performerNames.count <= performerIndex {
                slot.performerNames.append("")
            }
            while slot.performerDJIDs.count <= performerIndex {
                slot.performerDJIDs.append(nil)
            }
            while slot.performerAvatarURLs.count <= performerIndex {
                slot.performerAvatarURLs.append(nil)
            }
            slot.performerNames[performerIndex] = dj.name
            slot.performerDJIDs[performerIndex] = dj.id
            slot.performerAvatarURLs[performerIndex] = dj.avatarSmallUrl ?? dj.avatarMediumUrl ?? dj.avatarUrl ?? dj.avatarOriginalUrl
        }
        djSearchResults[djSearchKey(slotID: slotID, performerIndex: performerIndex)] = []
        djSearchFeedbacks[djSearchKey(slotID: slotID, performerIndex: performerIndex)] = .idle
    }

    func clearLineupOnlyDJBinding(slotID: UUID, performerIndex: Int) {
        updateLineupOnlySlot(id: slotID) { slot in
            while slot.performerDJIDs.count <= performerIndex {
                slot.performerDJIDs.append(nil)
            }
            while slot.performerAvatarURLs.count <= performerIndex {
                slot.performerAvatarURLs.append(nil)
            }
            slot.performerDJIDs[performerIndex] = nil
            slot.performerAvatarURLs[performerIndex] = nil
        }
        djSearchFeedbacks[djSearchKey(slotID: slotID, performerIndex: performerIndex)] = .idle
    }

    func djSearchKey(slotID: UUID, performerIndex: Int) -> String {
        "\(slotID.uuidString).\(performerIndex)"
    }

    func addPickedImages(zone: EventUploadImageZone, items: [EventUploadPickedImageData]) async {
        guard !items.isEmpty else { return }
        var addedCount = 0
        for item in items {
            do {
                let localURL = try draftStore.saveImageData(
                    item.data,
                    draftID: draft.id,
                    zone: zone,
                    fileExtension: item.fileExtension
                )
                let nextOrder = (draft.imageZones[zone] ?? []).count + 1
                draft.appendImage(
                    EventUploadImageDraft(
                        zone: zone,
                        localFileURL: localURL,
                        fileName: localURL.lastPathComponent,
                        mimeType: item.mimeType,
                        sortOrder: nextOrder,
                        ownership: .pendingLocal
                    )
                )
                startImmediateUpload(for: zone, imageID: draft.imageZones[zone]?.last?.id)
                addedCount += 1
            } catch {
                statusMessage = LT("部分图片保存失败，请重试。", "Some images could not be saved. Please try again.", "一部の画像を保存できませんでした。再試行してください。")
            }
        }
        if addedCount > 0 {
            saveDraft()
            EventUploadAnalytics.track(
                "event_upload_v2_images_added",
                properties: ["zone": zone.rawValue, "count": "\(addedCount)"]
            )
        }
    }

    func removeImage(zone: EventUploadImageZone, imageID: UUID) {
        let removedImage = (draft.imageZones[zone] ?? []).first(where: { $0.id == imageID })
        imageUploadTasks[imageID]?.cancel()
        imageUploadTasks[imageID] = nil
        uploadingImageIDs.remove(imageID)
        failedImageIDs.remove(imageID)
        var images = draft.imageZones[zone] ?? []
        images.removeAll { $0.id == imageID }
        draft.imageZones[zone] = images.enumerated().map { index, image in
            var next = image
            next.sortOrder = index + 1
            return next
        }
        draft.dirty = true
        saveDraft()
        EventUploadAnalytics.track("event_upload_v2_image_removed", properties: ["zone": zone.rawValue])
        if let removedImage {
            Task {
                if removedImage.ownership != .persistedEvent {
                    await self.deleteUploadedImageIfNeeded(removedImage)
                }
            }
        }
    }

    func replaceImage(zone: EventUploadImageZone, imageID: UUID, item: EventUploadPickedImageData) async {
        var images = draft.imageZones[zone] ?? []
        guard let index = images.firstIndex(where: { $0.id == imageID }) else { return }
        do {
            let localURL = try draftStore.saveImageData(
                item.data,
                draftID: draft.id,
                zone: zone,
                fileExtension: item.fileExtension
            )
            images[index].localFileURL = localURL
            images[index].remoteURL = nil
            images[index].fileName = localURL.lastPathComponent
            images[index].mimeType = item.mimeType
            images[index].ownership = .pendingLocal
            draft.imageZones[zone] = images
            draft.dirty = true
            saveDraft()
            EventUploadAnalytics.track("event_upload_v2_image_replaced", properties: ["zone": zone.rawValue])
            startImmediateUpload(for: zone, imageID: imageID)
        } catch {
            statusMessage = LT("图片替换失败，请重试。", "Image replacement failed. Please try again.", "画像の置き換えに失敗しました。再試行してください。")
        }
    }

    func moveImage(zone: EventUploadImageZone, imageID: UUID, direction: Int) {
        var images = draft.imageZones[zone] ?? []
        guard let index = images.firstIndex(where: { $0.id == imageID }) else { return }
        let target = index + direction
        guard images.indices.contains(target), index != target else { return }
        images.swapAt(index, target)
        draft.imageZones[zone] = images.enumerated().map { index, image in
            var next = image
            next.sortOrder = index + 1
            return next
        }
        draft.dirty = true
        saveDraft()
        EventUploadAnalytics.track("event_upload_v2_image_reordered", properties: ["zone": zone.rawValue])
    }

    private func remoteURLForAIImage(_ image: EventUploadImageDraft) async throws -> String {
        await waitForImageUploadIfNeeded(image.id)
        if let latest = imageDraft(for: image.id, in: image.zone),
           let remoteURL = latest.remoteURL?.trimmingCharacters(in: .whitespacesAndNewlines),
           !remoteURL.isEmpty {
            return remoteURL
        }
        if let remoteURL = image.remoteURL?.trimmingCharacters(in: .whitespacesAndNewlines), !remoteURL.isEmpty {
            return remoteURL
        }
        guard let localFileURL = image.localFileURL else {
            throw ServiceError.message(LT("这张图片还没有可识别的远程地址，请重新选择图片。", "This image is not available for recognition yet. Please choose another image.", "この画像はまだ認識に使えるURLがありません。別の画像を選択してください。"))
        }
        let data = try Data(contentsOf: localFileURL)
        let upload = try await webService.uploadEventImage(
            imageData: data,
            fileName: image.fileName,
            mimeType: image.mimeType,
            eventID: eventIDForUpload,
            draftID: draftIDForUpload,
            usage: image.zone.rawValue
        )
        updateRemoteURL(upload.url, ownership: uploadedOwnership, for: image)
        return upload.url
    }

    private func updateRemoteURL(_ remoteURL: String, ownership: EventUploadImageDraft.Ownership, for image: EventUploadImageDraft) {
        var images = draft.imageZones[image.zone] ?? []
        guard let index = images.firstIndex(where: { $0.id == image.id }) else { return }
        images[index].remoteURL = remoteURL
        images[index].ownership = ownership
        draft.imageZones[image.zone] = images
        draft.dirty = true
        saveDraft()
    }

    private func timetableAIContext() -> EventTimetableImageImportContext {
        let timeZone = TimeZone(identifier: draft.timeZoneIdentifier) ?? .current
        return EventTimetableImageImportContext(
            eventStartDate: eventUploadDateString(draft.startDate, timeZone: timeZone),
            eventEndDate: eventUploadDateString(draft.endDate, timeZone: timeZone),
            eventTimeZone: draft.timeZoneIdentifier,
            dayRolloverHour: draft.dayRolloverHour,
            weekRanges: timetableAIWeekRanges(timeZone: timeZone),
            knownStageNames: draft.stageEntries
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        )
    }

    private func lineupAIContext() -> EventLineupAIImportContext {
        EventLineupAIImportContext(
            preferredLanguage: lineupAIPreferredLanguageCode(),
            knownDJNames: []
        )
    }

    private func lineupAIPreferredLanguageCode() -> String {
        switch draft.preferredLanguage {
        case .zh:
            return "zh-Hans"
        case .ja:
            return "ja"
        case .en:
            return "en"
        }
    }

    private func timetableAIWeekRanges(timeZone: TimeZone) -> [EventTimetableImageImportWeekRange] {
        let ranges: [EventUploadWeekRangeDraft] = draft.scheduleMode == .multiWeek
            ? draft.weekRanges
            : [EventUploadWeekRangeDraft(startDate: draft.startDate, endDate: draft.endDate)]
        return ranges.enumerated().map { index, range in
            EventTimetableImageImportWeekRange(
                weekIndex: index + 1,
                startDate: eventUploadDateString(range.startDate, timeZone: timeZone),
                endDate: eventUploadDateString(range.endDate, timeZone: timeZone)
            )
        }
    }

    private func eventUploadDateString(_ date: Date, timeZone: TimeZone) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = timeZone
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    private func editableTimetableImportResult(from raw: EventTimetableAIResult) -> EventUploadTimetableAIImportResult {
        var slots: [EventUploadTimetableAIEditableSlot] = []
        for week in raw.weeks.sorted(by: { $0.weekIndex < $1.weekIndex }) {
            for day in week.days.sorted(by: { $0.festivalDayIndex < $1.festivalDayIndex }) {
                for stage in day.stages.sorted(by: { $0.order < $1.order }) {
                    for slot in stage.slots.sorted(by: { ($0.orderInStage ?? 0) < ($1.orderInStage ?? 0) }) {
                        let names = slot.performerNames
                            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                            .filter { !$0.isEmpty }
                        let type = EventLineupActType(rawValue: slot.performerType) ?? normalizedActType(.solo, performerCount: names.count)
                        slots.append(
                            EventUploadTimetableAIEditableSlot(
                                weekIndex: week.weekIndex,
                                dayIndex: max(1, day.festivalDayIndex),
                                dayLabel: "Day \(max(1, day.festivalDayIndex))",
                                stageName: stage.stageName,
                                actType: normalizedActType(type, performerCount: names.count),
                                performerNamesText: names.joined(separator: ", "),
                                performerDJIDs: Array(repeating: nil, count: max(1, names.count)),
                                performerAvatarURLs: Array(repeating: nil, count: max(1, names.count)),
                                startTimeText: timetableAIEditableClockText(slot.normalizedStartTime ?? slot.startTimeText),
                                endTimeText: timetableAIEditableClockText(slot.normalizedEndTime ?? slot.endTimeText),
                                startDayOffset: timetableAISlotDayOffset(slot.normalizedStartTime ?? slot.startTimeText),
                                endDayOffset: timetableAISlotDayOffset(slot.normalizedEndTime ?? slot.endTimeText),
                                confidence: slot.confidence,
                                notes: slot.notes ?? []
                            )
                        )
                    }
                }
            }
        }
        return EventUploadTimetableAIImportResult(
            slots: slots,
            warnings: raw.warnings ?? [],
            unparsedTexts: raw.unparsedTexts ?? []
        )
    }

    private func editableLineupImportResult(from raw: EventLineupAIResult) -> EventUploadLineupAIImportResult {
        let items = raw.items
            .sorted { $0.order < $1.order }
            .compactMap { item -> EventUploadLineupAIEditableItem? in
                let names = item.performerNames
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
                let fallbackNames = item.displayName
                    .split(separator: ",")
                    .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
                let finalNames = names.isEmpty ? fallbackNames : names
                guard !finalNames.isEmpty else { return nil }
                let type = EventLineupActType(rawValue: item.performerType) ?? normalizedActType(.solo, performerCount: finalNames.count)
                return EventUploadLineupAIEditableItem(
                    actType: normalizedActType(type, performerCount: finalNames.count),
                    performerNamesText: finalNames.joined(separator: ", "),
                    performerDJIDs: Array(repeating: nil, count: max(1, finalNames.count)),
                    performerAvatarURLs: Array(repeating: nil, count: max(1, finalNames.count)),
                    confidence: item.confidence,
                    notes: item.notes ?? []
                )
            }
        return EventUploadLineupAIImportResult(
            items: items,
            warnings: raw.warnings ?? [],
            unparsedTexts: raw.unparsedTexts ?? []
        )
    }

    private func editablePosterImportResult(from raw: EventPosterAIResult) -> EventUploadPosterAIImportResult {
        let timeZone = TimeZone(identifier: raw.timeZone.ianaName ?? draft.timeZoneIdentifier) ?? .current
        let startDate = raw.schedule.startDate.flatMap { posterAIDate($0, timeZone: timeZone) }
        let endDate = raw.schedule.endDate.flatMap { posterAIDate($0, timeZone: timeZone) }
        let weekRanges = raw.schedule.weekRanges.compactMap { range -> EventUploadWeekRangeDraft? in
            guard let start = posterAIDate(range.startDate, timeZone: timeZone),
                  let end = posterAIDate(range.endDate, timeZone: timeZone) else {
                return nil
            }
            return EventUploadWeekRangeDraft(startDate: start, endDate: end)
        }
        let ticketTiers = raw.ticketInfo.tiers.map { tier in
            EventUploadTicketTierDraft(name: tier.name, price: tier.price > 0 ? String(format: "%.0f", tier.price) : tier.priceText)
        }
        return EventUploadPosterAIImportResult(
            name: localizedFields(from: raw.nameI18n),
            city: localizedFields(from: raw.cityI18n),
            detailAddress: localizedFields(from: raw.detailAddressI18n),
            country: localizedFields(from: raw.countryI18n),
            timeZoneIdentifier: raw.timeZone.ianaName,
            timeZoneDisplayName: raw.timeZone.displayName,
            scheduleMode: posterAIScheduleMode(raw.schedule.scheduleMode),
            startDate: startDate,
            endDate: endDate,
            weekRanges: weekRanges,
            ticketURL: raw.ticketInfo.ticketUrl,
            ticketCurrency: raw.ticketInfo.currency,
            ticketTiers: ticketTiers,
            warnings: raw.warnings ?? [],
            unparsedTexts: raw.unparsedTexts ?? []
        )
    }

    private func localizedFields(from text: WebBiText) -> EventUploadLocalizedFields {
        EventUploadLocalizedFields(
            zh: text.zh,
            en: text.en,
            ja: text.ja ?? "",
            enFull: text.enFull ?? ""
        )
    }

    private func posterAIScheduleMode(_ raw: String) -> EventUploadScheduleMode {
        switch raw {
        case "multiWeek":
            return .multiWeek
        case "multiDay":
            return .multiDay
        default:
            return .singleDay
        }
    }

    private func posterAIDate(_ raw: String, timeZone: TimeZone) -> Date? {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = timeZone
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: raw)
    }

    private func normalizedActType(_ type: EventLineupActType, performerCount: Int) -> EventLineupActType {
        if performerCount >= 3 { return .b3b }
        if performerCount == 2 { return .b2b }
        return type == .solo ? .solo : type
    }

    private func timetableAISlotDayOffset(_ raw: String?) -> EventUploadSlotDayOffset {
        guard let raw,
              let (hour, _) = parseTimetableAIClock(raw)
        else { return .sameDay }
        return hour >= 24 ? .nextDay : .sameDay
    }

    private func timetableAIEditableClockText(_ raw: String?) -> String {
        guard let raw,
              let (hour, minute) = parseTimetableAIClock(raw)
        else { return raw ?? "" }
        return String(format: "%02d:%02d", hour % 24, minute)
    }

    private func parseTimetableAIClock(_ raw: String) -> (Int, Int)? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = trimmed.split(separator: ":", maxSplits: 1).map(String.init)
        guard parts.count == 2,
              let hour = Int(parts[0]),
              let minute = Int(parts[1]),
              minute >= 0,
              minute < 60
        else { return nil }
        return (hour, minute)
    }

    private func timetableAIPerformerNames(from imported: EventUploadTimetableAIEditableSlot) -> [String] {
        imported.performerNamesText
            .split(separator: ",")
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private func lineupAIPerformerNames(from imported: EventUploadLineupAIEditableItem) -> [String] {
        imported.performerNamesText
            .split(separator: ",")
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private func lineupAIPerformerDJIDs(from imported: EventUploadLineupAIEditableItem, count: Int) -> [String?] {
        var values = Array(imported.performerDJIDs.prefix(count))
        while values.count < count {
            values.append(nil)
        }
        return values
    }

    private func lineupAIPerformerAvatarURLs(from imported: EventUploadLineupAIEditableItem, count: Int) -> [String?] {
        var values = Array(imported.performerAvatarURLs.prefix(count))
        while values.count < count {
            values.append(nil)
        }
        return values
    }

    private func timetableAIPerformerDJIDs(from imported: EventUploadTimetableAIEditableSlot, count: Int) -> [String?] {
        var values = Array(imported.performerDJIDs.prefix(count))
        while values.count < count {
            values.append(nil)
        }
        return values
    }

    private func timetableAIPerformerAvatarURLs(from imported: EventUploadTimetableAIEditableSlot, count: Int) -> [String?] {
        var values = Array(imported.performerAvatarURLs.prefix(count))
        while values.count < count {
            values.append(nil)
        }
        return values
    }

    private func ensureTimetableAIImportCapacity(_ slot: inout EventUploadTimetableAIEditableSlot, count: Int) {
        if slot.performerDJIDs.count < count {
            slot.performerDJIDs.append(contentsOf: Array(repeating: nil, count: count - slot.performerDJIDs.count))
        }
        if slot.performerAvatarURLs.count < count {
            slot.performerAvatarURLs.append(contentsOf: Array(repeating: nil, count: count - slot.performerAvatarURLs.count))
        }
    }

    private func ensureLineupAIImportCapacity(_ item: inout EventUploadLineupAIEditableItem, count: Int) {
        if item.performerDJIDs.count < count {
            item.performerDJIDs.append(contentsOf: Array(repeating: nil, count: count - item.performerDJIDs.count))
        }
        if item.performerAvatarURLs.count < count {
            item.performerAvatarURLs.append(contentsOf: Array(repeating: nil, count: count - item.performerAvatarURLs.count))
        }
    }

    private func timetableAIClockDate(_ timeText: String, dayIndex: Int, dayOffset: EventUploadSlotDayOffset) -> Date? {
        let trimmed = timeText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let parts = trimmed.split(separator: ":", maxSplits: 1).map(String.init)
        guard parts.count == 2,
              let rawHour = Int(parts[0]),
              let minute = Int(parts[1]),
              minute >= 0,
              minute < 60 else {
            return nil
        }

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: draft.timeZoneIdentifier) ?? .current
        let dayOffsetValue = max(dayIndex - 1, 0) + dayOffset.rawValue + rawHour / 24
        let hour = rawHour % 24
        let baseDay = calendar.date(byAdding: .day, value: dayOffsetValue, to: calendar.startOfDay(for: draft.startDate)) ?? draft.startDate
        return calendar.date(bySettingHour: hour, minute: minute, second: 0, of: baseDay)
    }

    private func uploadPendingImagesIfNeeded() async throws {
        await waitForOutstandingImageUploads()
        for zone in EventUploadImageZone.allCases {
            var images = draft.imageZones[zone] ?? []
            var changed = false
            for index in images.indices {
                if images[index].remoteURL?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
                    continue
                }
                guard let localFileURL = images[index].localFileURL else { continue }
                let data = try Data(contentsOf: localFileURL)
                let upload = try await webService.uploadEventImage(
                    imageData: data,
                    fileName: images[index].fileName,
                    mimeType: images[index].mimeType,
                    eventID: eventIDForUpload,
                    draftID: draftIDForUpload,
                    usage: zone.rawValue
                )
                images[index].remoteURL = upload.url
                images[index].ownership = uploadedOwnership
                changed = true
            }
            if changed {
                draft.imageZones[zone] = images
                saveDraft()
            }
        }
    }

    private var eventIDForUpload: String? {
        if case .edit(let eventID) = draft.mode {
            return eventID
        }
        return nil
    }

    private var draftIDForUpload: String? {
        if case .create = draft.mode {
            return draft.id.uuidString
        }
        return nil
    }

    private var uploadedOwnership: EventUploadImageDraft.Ownership {
        switch draft.mode {
        case .create:
            return .createDraftUploaded
        case .edit:
            return .editDraftUploaded
        }
    }

    private func imageDraft(for imageID: UUID, in zone: EventUploadImageZone) -> EventUploadImageDraft? {
        (draft.imageZones[zone] ?? []).first(where: { $0.id == imageID })
    }

    private func startImmediateUpload(for zone: EventUploadImageZone, imageID: UUID?) {
        guard let imageID,
              let image = imageDraft(for: imageID, in: zone),
              image.remoteURL?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty != false,
              let localFileURL = image.localFileURL
        else { return }

        imageUploadTasks[imageID]?.cancel()
        uploadingImageIDs.insert(imageID)
        failedImageIDs.remove(imageID)
        let imageSnapshot = image
        let uploadEventID = eventIDForUpload
        let uploadDraftID = draftIDForUpload
        let uploadOwnership = uploadedOwnership

        imageUploadTasks[imageID] = Task { [weak self] in
            guard let self else { return }
            do {
                try await self.webService.prepareAuthenticatedRequestForUserAction(source: "event-upload-image")
                let data = try Data(contentsOf: localFileURL)
                let upload = try await self.webService.uploadEventImage(
                    imageData: data,
                    fileName: imageSnapshot.fileName,
                    mimeType: imageSnapshot.mimeType,
                    eventID: uploadEventID,
                    draftID: uploadDraftID,
                    usage: zone.rawValue
                )
                await MainActor.run {
                    self.imageUploadTasks[imageID] = nil
                    self.uploadingImageIDs.remove(imageID)
                    if self.imageDraft(for: imageID, in: zone) != nil {
                        self.updateRemoteURL(upload.url, ownership: uploadOwnership, for: imageSnapshot)
                    } else {
                        Task {
                            await self.deleteUploadedImageIfNeeded(
                                EventUploadImageDraft(
                                    id: imageSnapshot.id,
                                    zone: imageSnapshot.zone,
                                    localFileURL: nil,
                                    remoteURL: upload.url,
                                    fileName: imageSnapshot.fileName,
                                    mimeType: imageSnapshot.mimeType,
                                    sortOrder: imageSnapshot.sortOrder,
                                    ownership: uploadOwnership
                                ),
                                eventID: uploadEventID,
                                draftID: uploadDraftID
                            )
                        }
                    }
                }
            } catch {
                await MainActor.run {
                    self.imageUploadTasks[imageID] = nil
                    self.uploadingImageIDs.remove(imageID)
                    guard !(error is CancellationError) else { return }
                    self.failedImageIDs.insert(imageID)
                    self.statusMessage = error.userFacingMessage ?? LT("图片上传失败，请稍后重试。", "Image upload failed. Please try again.", "画像のアップロードに失敗しました。もう一度お試しください。")
                }
            }
        }
    }

    private func waitForOutstandingImageUploads() async {
        let tasks = imageUploadTasks.values
        for task in tasks {
            await task.value
        }
    }

    private func waitForImageUploadIfNeeded(_ imageID: UUID) async {
        guard let task = imageUploadTasks[imageID] else { return }
        await task.value
    }

    private func cancelOutstandingImageUploads() {
        for task in imageUploadTasks.values {
            task.cancel()
        }
        imageUploadTasks.removeAll()
        uploadingImageIDs.removeAll()
    }

    private func cleanupOwnedRemoteImages() async {
        let currentEventID = eventIDForUpload
        let currentDraftID = draftIDForUpload
        let images = EventUploadImageZone.allCases.flatMap { draft.imageZones[$0] ?? [] }
        for image in images {
            await deleteUploadedImageIfNeeded(image, eventID: currentEventID, draftID: currentDraftID)
        }
    }

    private func deleteUploadedImageIfNeeded(
        _ image: EventUploadImageDraft,
        eventID: String? = nil,
        draftID: String? = nil
    ) async {
        guard let remoteURL = image.remoteURL?.trimmingCharacters(in: .whitespacesAndNewlines), !remoteURL.isEmpty else {
            return
        }
        do {
            switch image.ownership {
            case .createDraftUploaded:
                try await webService.deleteEventUploadedImages(
                    eventID: nil,
                    draftID: draftID ?? self.draftIDForUpload ?? draft.id.uuidString,
                    urls: [remoteURL]
                )
            case .editDraftUploaded:
                guard let eventID = eventID ?? eventIDForUpload else { return }
                try await webService.deleteEventUploadedImages(
                    eventID: eventID,
                    draftID: nil,
                    urls: [remoteURL]
                )
            case .persistedEvent:
                guard let eventID = eventID ?? eventIDForUpload else { return }
                try await webService.deleteEventUploadedImages(
                    eventID: eventID,
                    draftID: nil,
                    urls: [remoteURL]
                )
            case .pendingLocal:
                return
            }
        } catch {
            // Keep cleanup best-effort so draft UX is never blocked on remote cleanup.
        }
    }

    private func scheduleTimeZoneSearch() {
        timeZoneSearchTask?.cancel()
        let query = draft.timeZoneSearchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard query.count >= 2 else {
            timeZoneSearchResults = []
            timeZoneSearchFeedback = .idle
            return
        }
        timeZoneSearchTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 350_000_000)
            guard !Task.isCancelled else { return }
            await self?.searchEventTimeZones(showEmptyMessage: false, useInlineFeedback: true)
        }
    }

    private func scheduleOrganizerSearch() {
        organizerSearchTask?.cancel()
        let query = draft.organizerName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard query.count >= 2 else {
            organizerSearchResults = []
            organizerSearchFeedback = .idle
            return
        }
        organizerSearchTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 350_000_000)
            guard !Task.isCancelled else { return }
            await self?.searchOrganizers(showEmptyMessage: false, useInlineFeedback: true)
        }
    }

    private func ensureDefaultStageExistsIfNeeded() {
        guard draft.stageEntries.isEmpty else { return }
        draft.stageEntries = [""]
    }

    private func normalizeWeekRanges(for mode: EventUploadScheduleMode) {
        switch mode {
        case .singleDay, .multiDay:
            draft.weekRanges = [EventUploadWeekRangeDraft(startDate: draft.startDate, endDate: draft.endDate)]
        case .multiWeek:
            if draft.weekRanges.isEmpty {
                draft.weekRanges = [EventUploadWeekRangeDraft(startDate: draft.startDate, endDate: draft.endDate)]
            }
            recalculateEventDateBoundsFromWeeks()
        }
    }

    private func syncWeekRangesWithEventDates() {
        if draft.scheduleMode == .multiWeek {
            if draft.weekRanges.isEmpty {
                draft.weekRanges = [EventUploadWeekRangeDraft(startDate: draft.startDate, endDate: draft.endDate)]
            } else {
                draft.weekRanges[0].startDate = draft.startDate
                if let lastIndex = draft.weekRanges.indices.last {
                    draft.weekRanges[lastIndex].endDate = max(draft.weekRanges[lastIndex].endDate, draft.endDate)
                }
                recalculateEventDateBoundsFromWeeks()
            }
        } else {
            draft.weekRanges = [EventUploadWeekRangeDraft(startDate: draft.startDate, endDate: draft.endDate)]
        }
    }

    private func recalculateEventDateBoundsFromWeeks() {
        guard !draft.weekRanges.isEmpty else { return }
        let normalized = draft.weekRanges.map { range in
            EventUploadWeekRangeDraft(
                id: range.id,
                startDate: normalizedEventDate(min(range.startDate, range.endDate)),
                endDate: normalizedEventDate(max(range.startDate, range.endDate))
            )
        }
        draft.weekRanges = normalized.sorted { $0.startDate < $1.startDate }
        if let first = draft.weekRanges.first {
            draft.startDate = first.startDate
        }
        if let last = draft.weekRanges.last {
            draft.endDate = last.endDate
        }
    }

    private func defaultLineupStartTime(dayIndex: Int) -> Date {
        lineupDate(dayIndex: dayIndex, hour: 20, minute: 0)
    }

    private func defaultLineupEndTime(dayIndex: Int) -> Date {
        lineupDate(dayIndex: dayIndex, hour: 21, minute: 0)
    }

    private func lineupDate(dayIndex: Int, hour: Int, minute: Int) -> Date {
        var calendar = Calendar.current
        calendar.timeZone = TimeZone(identifier: draft.timeZoneIdentifier) ?? .current
        let startDay = calendar.startOfDay(for: draft.startDate)
        let day = calendar.date(byAdding: .day, value: max(dayIndex - 1, 0), to: startDay) ?? startDay
        return calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day) ?? day
    }

    private var eventTimeZone: TimeZone {
        TimeZone(identifier: draft.timeZoneIdentifier) ?? .current
    }

    private func normalizedEventDate(_ value: Date) -> Date {
        value.normalizedEventArchiveDate(in: eventTimeZone)
    }

    private func normalizedEventDate(addingDays days: Int, to value: Date) -> Date? {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = eventTimeZone
        guard let next = calendar.date(byAdding: .day, value: days, to: value) else { return nil }
        return next.normalizedEventArchiveDate(in: eventTimeZone)
    }

    private func rebaseDraftDatesPreservingWallDate(to nextTimeZoneIdentifier: String) {
        let previousTimeZone = eventTimeZone
        let nextTimeZone = TimeZone(identifier: nextTimeZoneIdentifier) ?? previousTimeZone
        let startText = draft.startDate.eventArchiveDateText(in: previousTimeZone)
        let endText = draft.endDate.eventArchiveDateText(in: previousTimeZone)
        draft.startDate = Date.eventArchiveDate(from: startText, timeZone: nextTimeZone) ?? draft.startDate.normalizedEventArchiveDate(in: nextTimeZone)
        draft.endDate = Date.eventArchiveDate(from: endText, timeZone: nextTimeZone) ?? draft.endDate.normalizedEventArchiveDate(in: nextTimeZone)
        draft.weekRanges = draft.weekRanges.map { range in
            let start = range.startDate.eventArchiveDateText(in: previousTimeZone)
            let end = range.endDate.eventArchiveDateText(in: previousTimeZone)
            return EventUploadWeekRangeDraft(
                id: range.id,
                startDate: Date.eventArchiveDate(from: start, timeZone: nextTimeZone) ?? range.startDate.normalizedEventArchiveDate(in: nextTimeZone),
                endDate: Date.eventArchiveDate(from: end, timeZone: nextTimeZone) ?? range.endDate.normalizedEventArchiveDate(in: nextTimeZone)
            )
        }
    }
}

struct EventUploadSubmitSuccess: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let message: String
}

enum EventUploadSaveOutcome: Equatable {
    case eventMutated(eventID: String?)
    case submissionQueued(eventID: String?)
}
