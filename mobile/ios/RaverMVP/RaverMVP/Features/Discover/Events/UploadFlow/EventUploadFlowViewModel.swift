import Foundation

@MainActor
final class EventUploadFlowViewModel: ObservableObject {
    @Published var draft: EventUploadDraft
    @Published var validationIssues: [EventUploadValidationIssue] = []
    @Published var statusMessage: String?
    @Published var submitSuccess: EventUploadSubmitSuccess?
    @Published var shouldConfirmRestoredCreateDraft = false
    @Published var timeZoneSearchResults: [EventTimezoneLookupItem] = []
    @Published var organizerSearchResults: [WebLearnFestival] = []
    @Published var djSearchResults: [String: [WebDJ]] = [:]
    @Published var searchingDJKeys: Set<String> = []
    @Published var isSearchingTimeZones = false
    @Published var isSearchingOrganizers = false
    @Published var isSubmitting = false

    private let draftStore: EventUploadDraftStore
    private let webService: WebFeatureService
    private let userID: String
    private let onSaved: () -> Void
    private var onDismiss: () -> Void
    private var draftSaveTask: Task<Void, Never>?

    init(
        mode: EventUploadMode = .create,
        event: WebEvent? = nil,
        userID: String = "current",
        webService: WebFeatureService = AppEnvironment.sharedWebService,
        draftStore: EventUploadDraftStore = .shared,
        onSaved: @escaping () -> Void = {},
        onDismiss: @escaping () -> Void = {}
    ) {
        self.userID = userID
        self.webService = webService
        self.draftStore = draftStore
        self.onSaved = onSaved
        self.onDismiss = onDismiss
        var restoredCreateDraft = false
        if let event {
            self.draft = .edit(event: event)
        } else if let saved = draftStore.load(mode: mode, userID: userID) {
            self.draft = saved
            if case .create = saved.mode {
                restoredCreateDraft = true
            }
        } else {
            self.draft = .create()
            self.draft.mode = mode
        }
        self.shouldConfirmRestoredCreateDraft = restoredCreateDraft
        EventUploadAnalytics.track("event_upload_v2_opened", properties: ["mode": draft.mode.storageKeyPart])
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
            draft.currentStep = next
            EventUploadAnalytics.track("event_upload_v2_step_viewed", properties: ["step": next.rawValue])
            saveDraft()
        }
    }

    func goBack() {
        guard let previous = draft.currentStep.previous else { return }
        draft.currentStep = previous
        EventUploadAnalytics.track("event_upload_v2_step_viewed", properties: ["step": previous.rawValue])
        saveDraft()
    }

    func saveDraft(immediate: Bool = false) {
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

    func discardDraftAndClose() {
        draftStore.clear(mode: draft.mode, userID: userID)
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

    func continueRestoredDraft() {
        shouldConfirmRestoredCreateDraft = false
    }

    func restartCreateDraft() {
        draftStore.clear(mode: .create, userID: userID)
        draft = .create()
        shouldConfirmRestoredCreateDraft = false
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
        draftStore.save(draft, userID: userID)
        EventUploadAnalytics.track("event_upload_v2_draft_saved", properties: ["mode": draft.mode.storageKeyPart])
    }

    func submit() async {
        guard !isSubmitting else { return }
        validationIssues = EventUploadValidation.issues(for: draft)
        if let firstIssue = validationIssues.first {
            draft.currentStep = firstIssue.step
            statusMessage = firstIssue.message
            return
        }

        isSubmitting = true
        defer { isSubmitting = false }
        EventUploadAnalytics.track("event_upload_v2_submit_tapped", properties: ["mode": draft.mode.storageKeyPart])

        do {
            try await uploadPendingImagesIfNeeded()
            switch draft.mode {
            case .create:
                let result = try await webService.createEvent(input: EventUploadMappers.createInput(from: draft))
                draftStore.clear(mode: draft.mode, userID: userID)
                switch result {
                case .created:
                    submitSuccess = EventUploadSubmitSuccess(
                        title: LT("活动已发布", "Event Published", "イベントを公開しました"),
                        message: LT("活动已经出现在活动页，也可以在我的发布里继续管理。", "The event is live on the events page. You can also manage it from My Posts.", "イベントページに公開されました。マイ投稿からも管理できます。")
                    )
                case .submittedForReview:
                    submitSuccess = EventUploadSubmitSuccess(
                        title: LT("已提交审核", "Submitted for Review", "審査に送信しました"),
                        message: LT("审核通过后会正式展示在活动页。你可以在我的发布里查看进度。", "It will appear on the events page after approval. You can track progress from My Posts.", "承認後にイベントページへ表示されます。進捗はマイ投稿で確認できます。")
                    )
                }
            case .edit(let eventID):
                _ = try await webService.updateEvent(id: eventID, input: EventUploadMappers.updateInput(from: draft))
                draftStore.clear(mode: draft.mode, userID: userID)
                submitSuccess = EventUploadSubmitSuccess(
                    title: LT("活动已更新", "Event Updated", "イベントを更新しました"),
                    message: LT("更新已保存。你可以返回活动页查看最新内容，也可以在我的发布里继续管理。", "Your changes are saved. Return to the events page to view the latest content, or manage it from My Posts.", "更新を保存しました。イベントページで最新内容を確認するか、マイ投稿から管理できます。")
                )
            }
            EventUploadAnalytics.track("event_upload_v2_submit_succeeded", properties: ["mode": draft.mode.storageKeyPart])
            onSaved()
        } catch {
            EventUploadAnalytics.track("event_upload_v2_submit_failed", properties: ["mode": draft.mode.storageKeyPart])
            statusMessage = error.userFacingMessage ?? LT("提交失败，请稍后重试。", "Submit failed. Please try again.", "送信に失敗しました。もう一度お試しください。")
        }
    }

    func updateLocalizedField(_ keyPath: WritableKeyPath<EventUploadDraft, EventUploadLocalizedFields>, value: String) {
        draft[keyPath: keyPath].setCurrentValue(value, preferredLanguage: draft.preferredLanguage)
        draft.dirty = true
        saveDraft()
    }

    func updateEventType(_ value: String) {
        draft.eventType = value
        draft.dirty = true
        saveDraft()
    }

    func updateOrganizerName(_ value: String) {
        draft.organizerName = value
        draft.organizerFestivalID = nil
        organizerSearchResults = []
        draft.dirty = true
        saveDraft()
    }

    func searchOrganizers() async {
        let trimmed = draft.organizerName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            statusMessage = LT("请先输入主办方名称。", "Enter an organizer name first.", "先に主催者名を入力してください。")
            return
        }
        isSearchingOrganizers = true
        defer { isSearchingOrganizers = false }
        do {
            organizerSearchResults = try await webService.fetchLearnFestivals(search: trimmed)
            if organizerSearchResults.isEmpty {
                statusMessage = LT("没有找到匹配主办方，当前会按手动名称保存。", "No matching organizer found. The current text will be saved as a manual name.", "一致する主催者が見つかりませんでした。現在のテキストを手入力名として保存します。")
            }
        } catch {
            organizerSearchResults = []
            statusMessage = error.userFacingMessage ?? LT("搜索主办方失败，请稍后重试。", "Failed to search organizers. Please try again.", "主催者検索に失敗しました。もう一度お試しください。")
        }
    }

    func applyOrganizer(_ festival: WebLearnFestival) {
        draft.organizerFestivalID = festival.id
        draft.organizerName = festival.nameI18n?.text(for: AppLanguagePreference.current.effectiveLanguage).trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            ? (festival.nameI18n?.text(for: AppLanguagePreference.current.effectiveLanguage) ?? festival.name)
            : festival.name
        organizerSearchResults = []
        draft.dirty = true
        saveDraft()
        EventUploadAnalytics.track("event_upload_v2_organizer_bound", properties: ["festivalID": festival.id])
    }

    func clearOrganizerBinding() {
        draft.organizerFestivalID = nil
        organizerSearchResults = []
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
        draft[keyPath: keyPath] = value
        syncWeekRangesWithEventDates()
        draft.dirty = true
        saveDraft()
    }

    func addWeekRange() {
        let anchor = draft.weekRanges.last?.endDate ?? draft.endDate
        let nextStart = Calendar.current.date(byAdding: .day, value: 1, to: anchor) ?? anchor
        let nextEnd = Calendar.current.date(byAdding: .day, value: 2, to: nextStart) ?? nextStart
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
            draft.weekRanges[index].startDate = startDate
        }
        if let endDate {
            draft.weekRanges[index].endDate = endDate
        }
        if draft.weekRanges[index].endDate < draft.weekRanges[index].startDate {
            draft.weekRanges[index].endDate = draft.weekRanges[index].startDate
        }
        recalculateEventDateBoundsFromWeeks()
        draft.dirty = true
        saveDraft()
    }

    func updateTimeZoneIdentifier(_ value: String) {
        draft.timeZoneIdentifier = value.trimmingCharacters(in: .whitespacesAndNewlines)
        draft.selectedTimeZoneLookup = nil
        draft.dirty = true
        saveDraft()
    }

    func updateTimeZoneSearchQuery(_ value: String) {
        draft.timeZoneSearchQuery = value
        draft.selectedTimeZoneLookup = nil
        draft.dirty = true
        saveDraft()
    }

    func searchEventTimeZones() async {
        let trimmed = draft.timeZoneSearchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            statusMessage = LT("请先输入城市名。", "Enter a city first.", "先に都市名を入力してください。")
            return
        }
        isSearchingTimeZones = true
        defer { isSearchingTimeZones = false }
        do {
            let results = try await webService.searchEventTimezones(query: trimmed, limit: 8)
            timeZoneSearchResults = results
            if results.isEmpty {
                statusMessage = LT("没有匹配结果，请尝试英文城市名、州缩写或国家名。", "No matches found. Try an English city name, state code, or country.", "一致する結果がありません。英語の都市名、州コード、または国名でお試しください。")
            }
        } catch {
            timeZoneSearchResults = []
            statusMessage = error.userFacingMessage ?? LT("搜索城市时区失败，请稍后重试。", "Failed to search event timezones. Please try again.", "都市タイムゾーンの検索に失敗しました。もう一度お試しください。")
        }
    }

    func applyTimeZoneSelection(_ item: EventTimezoneLookupItem) {
        draft.selectedTimeZoneLookup = item
        draft.timeZoneIdentifier = item.timezone
        draft.timeZoneSearchQuery = item.cityAscii.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? item.city : item.cityAscii
        timeZoneSearchResults = []

        if draft.city.primaryValue(preferredLanguage: draft.preferredLanguage).trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            draft.city.setCurrentValue(item.cityAscii.isEmpty ? item.city : item.cityAscii, preferredLanguage: draft.preferredLanguage)
        }
        if draft.country.primaryValue(preferredLanguage: draft.preferredLanguage).trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            draft.country.setCurrentValue(item.country, preferredLanguage: draft.preferredLanguage)
        }

        draft.dirty = true
        saveDraft()
        EventUploadAnalytics.track("event_upload_v2_timezone_selected", properties: ["timezone": item.timezone])
    }

    func clearTimeZoneSelection() {
        draft.selectedTimeZoneLookup = nil
        draft.timeZoneSearchQuery = ""
        timeZoneSearchResults = []
        draft.dirty = true
        saveDraft()
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
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return "\(formatter.string(from: draft.startDate)) - \(formatter.string(from: draft.endDate))"
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
        draft.stageEntries.remove(at: index)
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

    func tapLineupImportPlaceholder() {
        EventUploadAnalytics.track("event_upload_v2_lineup_import_placeholder_tapped", properties: ["step": draft.currentStep.rawValue])
        statusMessage = LT("阵容图识别会在后续接入。当前可以先维护舞台。", "Lineup image import will be wired later. You can set up stages for now.", "ラインナップ画像認識は後続で接続します。今はステージを設定できます。")
    }

    func addTimetableSlot() {
        ensureDefaultStageExistsIfNeeded()
        var slot = EventUploadLineupSlotDraft()
        slot.stageName = normalizedStageName(at: 0)
        slot.startTime = defaultLineupStartTime(dayIndex: 1)
        slot.endTime = defaultLineupEndTime(dayIndex: 1)
        draft.timetableSlots.append(slot)
        draft.dirty = true
        saveDraft()
        EventUploadAnalytics.track("event_upload_v2_lineup_slot_added", properties: ["count": "\(draft.timetableSlots.count)"])
    }

    func addTimetableSlot(stageName: String, dayIndex: Int) {
        ensureDefaultStageExistsIfNeeded()
        var slot = EventUploadLineupSlotDraft()
        let trimmedStage = stageName.trimmingCharacters(in: .whitespacesAndNewlines)
        slot.stageName = trimmedStage.isEmpty ? normalizedStageName(at: 0) : trimmedStage
        slot.dayIndex = max(dayIndex, 1)
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
            } else {
                slot.startTime = nil
                slot.endTime = nil
            }
        }
    }

    func addLineupOnlySlot() {
        var slot = EventUploadLineupOnlySlotDraft()
        slot.normalizePerformers()
        draft.lineupOnlySlots.append(slot)
        draft.dirty = true
        saveDraft()
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

    func searchTimetableDJ(slotID: UUID, performerIndex: Int) async {
        guard let slot = draft.timetableSlots.first(where: { $0.id == slotID }),
              slot.performerNames.indices.contains(performerIndex) else { return }
        let query = slot.performerNames[performerIndex].trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            statusMessage = LT("请先输入 DJ 名称。", "Enter a DJ name first.", "先にDJ名を入力してください。")
            return
        }
        let key = djSearchKey(slotID: slotID, performerIndex: performerIndex)
        searchingDJKeys.insert(key)
        defer { searchingDJKeys.remove(key) }
        do {
            let page = try await webService.fetchDJs(page: 1, limit: 8, search: query, sortBy: "relevance")
            djSearchResults[key] = page.items
            if page.items.isEmpty {
                statusMessage = LT("未找到匹配 DJ，可继续使用手动名称。", "No matching DJs found. You can keep the manual name.", "一致するDJが見つかりません。手入力名のまま続行できます。")
            }
        } catch {
            djSearchResults[key] = []
            statusMessage = error.userFacingMessage ?? LT("搜索 DJ 失败，请稍后重试。", "Failed to search DJs. Please try again.", "DJ検索に失敗しました。もう一度お試しください。")
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
    }

    func searchLineupOnlyDJ(slotID: UUID, performerIndex: Int) async {
        guard let slot = draft.lineupOnlySlots.first(where: { $0.id == slotID }),
              slot.performerNames.indices.contains(performerIndex) else { return }
        let query = slot.performerNames[performerIndex].trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            statusMessage = LT("请先输入 DJ 名称。", "Enter a DJ name first.", "先にDJ名を入力してください。")
            return
        }
        let key = djSearchKey(slotID: slotID, performerIndex: performerIndex)
        searchingDJKeys.insert(key)
        defer { searchingDJKeys.remove(key) }
        do {
            let page = try await webService.fetchDJs(page: 1, limit: 8, search: query, sortBy: "relevance")
            djSearchResults[key] = page.items
        } catch {
            djSearchResults[key] = []
            statusMessage = error.userFacingMessage ?? LT("搜索 DJ 失败，请稍后重试。", "Failed to search DJs. Please try again.", "DJ検索に失敗しました。もう一度お試しください。")
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
                        sortOrder: nextOrder
                    )
                )
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
            draft.imageZones[zone] = images
            draft.dirty = true
            saveDraft()
            EventUploadAnalytics.track("event_upload_v2_image_replaced", properties: ["zone": zone.rawValue])
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

    private func uploadPendingImagesIfNeeded() async throws {
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
                    usage: zone.rawValue
                )
                images[index].remoteURL = upload.url
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
            EventUploadWeekRangeDraft(id: range.id, startDate: min(range.startDate, range.endDate), endDate: max(range.startDate, range.endDate))
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
}

struct EventUploadSubmitSuccess: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let message: String
}
