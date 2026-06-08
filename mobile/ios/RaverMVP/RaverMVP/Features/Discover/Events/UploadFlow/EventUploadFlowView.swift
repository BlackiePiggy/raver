import SwiftUI
import UIKit

private enum EventUploadTimeDisplay {
    static func clockRange(start: String, end: String) -> String? {
        let startText = start.trimmingCharacters(in: .whitespacesAndNewlines)
        let endText = end.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !startText.isEmpty, !endText.isEmpty else { return nil }
        guard let startClock = clockParts(from: startText),
              let endClock = clockParts(from: endText) else {
            return "\(startText)-\(endText)"
        }
        return clockRangeText(
            startText: String(format: "%02d:%02d", startClock.hour % 24, startClock.minute),
            startDayOffset: startClock.hour / 24,
            endText: String(format: "%02d:%02d", endClock.hour % 24, endClock.minute),
            endDayOffset: endClock.hour / 24
        )
    }

    static func clockRange(start: Date, end: Date, logicalDay: Date, timeZone: TimeZone) -> String {
        let startDayOffset = dayOffset(for: start, logicalDay: logicalDay, timeZone: timeZone)
        let endDayOffset = dayOffset(for: end, logicalDay: logicalDay, timeZone: timeZone)
        return clockRangeText(
            startText: hhmmFormatter(timeZone: timeZone).string(from: start),
            startDayOffset: startDayOffset,
            endText: hhmmFormatter(timeZone: timeZone).string(from: end),
            endDayOffset: endDayOffset
        )
    }

    static func clockText(for date: Date, logicalDay: Date, timeZone: TimeZone) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let logicalStart = calendar.startOfDay(for: logicalDay)
        let dateStart = calendar.startOfDay(for: date)
        let dayOffset = max(0, calendar.dateComponents([.day], from: logicalStart, to: dateStart).day ?? 0)
        let text = hhmmFormatter(timeZone: timeZone).string(from: date)
        return prefix(dayOffset: dayOffset, text: text)
    }

    private static func dayOffset(for date: Date, logicalDay: Date, timeZone: TimeZone) -> Int {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let logicalStart = calendar.startOfDay(for: logicalDay)
        let dateStart = calendar.startOfDay(for: date)
        return max(0, calendar.dateComponents([.day], from: logicalStart, to: dateStart).day ?? 0)
    }

    private static func clockRangeText(startText: String, startDayOffset: Int, endText: String, endDayOffset: Int) -> String {
        if startDayOffset == endDayOffset {
            let start = startDayOffset > 0 ? prefix(dayOffset: startDayOffset, text: startText) : startText
            return "\(start)-\(endText)"
        }
        return "\(prefix(dayOffset: startDayOffset, text: startText))-\(prefix(dayOffset: endDayOffset, text: endText))"
    }

    private static func prefix(dayOffset: Int, text: String) -> String {
        guard dayOffset > 0 else { return text }
        return LT("次日\(text)", "Next day \(text)", "翌日\(text)")
    }

    private static func clockParts(from raw: String) -> (hour: Int, minute: Int)? {
        let parts = raw.split(separator: ":", maxSplits: 1).map(String.init)
        guard parts.count == 2,
              let hour = Int(parts[0].trimmingCharacters(in: .whitespacesAndNewlines)),
              let minute = Int(parts[1].trimmingCharacters(in: .whitespacesAndNewlines)),
              hour >= 0,
              minute >= 0,
              minute < 60
        else { return nil }
        return (hour, minute)
    }

    private static func hhmmFormatter(timeZone: TimeZone) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.timeZone = timeZone
        formatter.dateFormat = "HH:mm"
        return formatter
    }
}

struct EventUploadFlowView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.discoverPush) private var discoverPush
    @Environment(\.appPush) private var appPush
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var viewModel: EventUploadFlowViewModel
    @State private var showLocationPicker = false
    @State private var showPosterAIImportSheet = false
    @State private var showTimetableAIImportSheet = false
    @State private var showLineupAIImportSheet = false
    @State private var showExitConfirmation = false
    @State private var selectedWeekForEditing: EventUploadWeekSelection?
    @State private var expandedTimetableSlots: Set<UUID> = []
    @State private var expandedLineupOnlySlots: Set<UUID> = []
    @State private var expandedLocalizedFieldKeys: Set<String> = []
    @State private var showAdvancedRollover = false
    @State private var keyboardCandidateSpacing: CGFloat = 0
    @State private var stageIndexPendingDeletion: Int?
    @State private var showClearAllTimetableConfirmation = false
    @State private var organizerCreateContextID: String?
    @State private var activeDatePicker: DatePickerPresentation?

    init(
        mode: EventUploadMode = .create,
        event: WebEvent? = nil,
        userID: String = "current",
        webService: WebFeatureService = AppEnvironment.sharedWebService,
        onSaved: @escaping (EventUploadSaveOutcome) -> Void = { _ in }
    ) {
        _viewModel = StateObject(wrappedValue: EventUploadFlowViewModel(
            mode: mode,
            event: event,
            userID: userID,
            webService: webService,
            onSaved: onSaved
        ))
    }

    var body: some View {
        rootContent
        .background(RaverTheme.background.ignoresSafeArea())
        .raverSystemNavigation(title: LT("上传活动", "Upload Event", "イベントをアップロード"))
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    if viewModel.draft.dirty && viewModel.submitSuccess == nil {
                        showExitConfirmation = true
                    } else {
                        dismiss()
                    }
                } label: {
                    Image(systemName: "xmark")
                }
            }
        }
        .onAppear {
            viewModel.setDismissAction { dismiss() }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background || phase == .inactive {
                viewModel.saveDraft(immediate: true)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
            withAnimation(.easeOut(duration: 0.22)) {
                keyboardCandidateSpacing = 132
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            withAnimation(.easeOut(duration: 0.18)) {
                keyboardCandidateSpacing = 0
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .discoverOrganizerDidCreate)) { notification in
            guard let expectedContextID = organizerCreateContextID,
                  let actualContextID = notification.userInfo?["sourceContextID"] as? String,
                  actualContextID == expectedContextID,
                  let organizer = notification.object as? WebLearnFestival else {
                return
            }
            viewModel.applyOrganizer(organizer)
            organizerCreateContextID = nil
        }
        .onReceive(NotificationCenter.default.publisher(for: .discoverOrganizerSubmissionQueued)) { notification in
            guard let expectedContextID = organizerCreateContextID,
                  let actualContextID = notification.userInfo?["sourceContextID"] as? String,
                  actualContextID == expectedContextID else {
                return
            }
            viewModel.handleOrganizerCreationQueued()
            organizerCreateContextID = nil
        }
        .onDisappear {
            viewModel.handleDisappear()
        }
        .sheet(isPresented: $showLocationPicker) {
            EventLocationPickerSheet(
                initialLatitude: viewModel.draft.latitude,
                initialLongitude: viewModel.draft.longitude,
                initialAddress: viewModel.draft.pickedMapAddress
            ) { result in
                viewModel.applyLocationPickerResult(result)
            }
        }
        .sheet(isPresented: $showPosterAIImportSheet) {
            EventUploadPosterAIImportSheet(viewModel: viewModel)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showTimetableAIImportSheet) {
            EventUploadTimetableAIImportSheet(viewModel: viewModel)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showLineupAIImportSheet) {
            EventUploadLineupAIImportSheet(viewModel: viewModel)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .sheet(item: $selectedWeekForEditing) { selection in
            weekEditorSheet(for: selection)
        }
        .sheet(item: $activeDatePicker) { presentation in
            EventUploadDatePickerSheet(
                title: presentation.title,
                selection: presentation.selection,
                timeZone: eventTimeZone
            )
        }
        .confirmationDialog(
            LT("保留草稿？", "Keep Draft?", "下書きを残しますか？"),
            isPresented: $showExitConfirmation,
            titleVisibility: .visible
        ) {
            Button(LT("保存草稿并离开", "Save Draft & Leave", "下書きを保存して離れる")) {
                viewModel.saveDraftAndClose()
            }
            Button(LT("放弃草稿", "Discard Draft", "下書きを破棄"), role: .destructive) {
                Task { await viewModel.discardDraftAndClose() }
            }
            Button(LT("继续编辑", "Keep Editing", "編集を続ける"), role: .cancel) {}
        } message: {
            Text(LT("未提交的内容会保存在本地草稿中。", "Unsubmitted changes can be kept as a local draft.", "未送信の内容はローカル下書きとして保存できます。"))
        }
        .confirmationDialog(
            LT("删除这个舞台？", "Delete this stage?", "このステージを削除しますか？"),
            isPresented: Binding(
                get: { stageIndexPendingDeletion != nil },
                set: { if !$0 { stageIndexPendingDeletion = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button(LT("删除舞台和对应时间表", "Delete stage and its timetable", "ステージと関連タイムテーブルを削除"), role: .destructive) {
                if let index = stageIndexPendingDeletion {
                    viewModel.removeStage(at: index)
                }
                stageIndexPendingDeletion = nil
            }
            Button(LT("取消", "Cancel", "キャンセル"), role: .cancel) {
                stageIndexPendingDeletion = nil
            }
        } message: {
            Text(LT("这个舞台下的所有时间表节目都会一起删除，但阵容页里已有的艺人会保留，不会自动删除。", "All timetable sets under this stage will be deleted, but lineup artists already listed on the lineup page will be kept.", "このステージ配下のタイムテーブル出演はすべて削除されますが、ラインナップページ上の出演者は自動削除されません。"))
        }
        .confirmationDialog(
            LT("清空全部时间表？", "Clear all timetable data?", "タイムテーブルをすべて削除しますか？"),
            isPresented: $showClearAllTimetableConfirmation,
            titleVisibility: .visible
        ) {
            Button(LT("删除全部舞台和时间表", "Delete all stages and timetable", "全ステージとタイムテーブルを削除"), role: .destructive) {
                viewModel.clearAllTimetableData()
            }
            Button(LT("取消", "Cancel", "キャンセル"), role: .cancel) {}
        } message: {
            Text(LT("会一次性清空当前草稿里的全部舞台信息和全部时间表信息；阵容页中已有艺人不会自动删除。", "This removes every stage and every timetable item from the current draft; existing lineup artists will not be deleted automatically.", "現在の下書きにある全ステージ情報と全タイムテーブル情報をまとめて削除します。ラインナップ側の出演者は自動削除されません。"))
        }
    }

    private var restoredDraftMessage: String {
        if case .edit = viewModel.draft.mode {
            return LT("已恢复上次未提交的活动编辑草稿。", "Your previous unsaved event edit draft was restored.", "前回の未保存イベント編集下書きを復元しました。")
        }
        return LT("已恢复上次未提交的新建活动草稿。", "Your previous unsent event draft was restored.", "未送信のイベント下書きを復元しました。")
    }

    private var content: AnyView {
        switch viewModel.draft.currentStep {
        case .media:
            return AnyView(mediaStep)
        case .basic:
            return AnyView(basicStep)
        case .time:
            return AnyView(timeStep)
        case .timetable:
            return AnyView(timetableStep)
        case .lineup:
            return AnyView(lineupStep)
        case .tickets:
            return AnyView(ticketsStep)
        case .review:
            return AnyView(reviewStep)
        }
    }

    private var rootContent: some View {
        VStack(spacing: 0) {
            if let success = viewModel.submitSuccess {
                successView(success)
            } else {
                editorContent
            }
        }
    }

    private var editorContent: some View {
        VStack(spacing: 0) {
            EventUploadProgressHeader(currentStep: viewModel.draft.currentStep)
            inlineUploadNoticeStack
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    content
                }
                .padding(20)
                .padding(.bottom, 56 + keyboardCandidateSpacing)
            }
            .safeAreaInset(edge: .bottom) {
                Color.clear
                    .frame(height: keyboardCandidateSpacing)
                    .allowsHitTesting(false)
            }
            .scrollDismissesKeyboard(.interactively)
            .contentShape(Rectangle())
            .onTapGesture {
                hideKeyboard()
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            EventUploadBottomBar(
                canGoBack: viewModel.draft.currentStep.previous != nil,
                isFinalStep: viewModel.draft.currentStep == .review,
                isBusy: viewModel.isSubmitting,
                onBack: viewModel.goBack,
                onNext: viewModel.advance
            )
        }
    }

    @ViewBuilder
    private var inlineUploadNoticeStack: some View {
        VStack(spacing: 8) {
            if viewModel.shouldConfirmRestoredDraft {
                inlineActionNoticeCard(
                    title: LT("继续上次草稿？", "Continue Draft?", "前回の下書きを続けますか？"),
                    message: restoredDraftMessage,
                    systemImage: "doc.badge.clock",
                    tint: RaverTheme.accent,
                    primaryTitle: LT("继续草稿", "Continue", "続ける"),
                    primaryAction: {
                        viewModel.continueRestoredDraft()
                    },
                    secondaryTitle: LT("重新开始", "Start Over", "最初から"),
                    secondaryRole: .destructive,
                    secondaryAction: {
                        Task { await viewModel.restartCreateDraft() }
                    }
                )
            }

            if let message = viewModel.statusMessage {
                inlineDismissibleNoticeCard(
                    title: LT("提示", "Notice", "お知らせ"),
                    message: message,
                    systemImage: "info.circle.fill",
                    tint: RaverTheme.accent
                ) {
                    viewModel.statusMessage = nil
                }
            }

            if let prompt = viewModel.lineupTimetableAlignmentPrompt {
                inlineActionNoticeCard(
                    title: prompt.title,
                    message: prompt.message,
                    systemImage: "arrow.triangle.2.circlepath",
                    tint: .orange,
                    primaryTitle: LT("确认对齐", "Confirm Align", "同期する"),
                    primaryAction: {
                        viewModel.confirmExactLineupAlignment()
                    },
                    secondaryTitle: LT("取消", "Cancel", "キャンセル"),
                    secondaryRole: nil,
                    secondaryAction: {
                        viewModel.dismissLineupTimetableAlignmentPrompt()
                    }
                )
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
    }

    private var mediaStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionTitle(
                LT("活动图片", "Event Images", "イベント画像"),
                subtitle: LT("Poster、阵容图、Cover 至少上传 1 张即可，其余图片可选。图片上传仅支持从相册选择。", "Upload at least one Poster, Lineup, or Cover image. Other images are optional. Uploads currently use photo library only.", "Poster、ラインナップ、Cover のいずれか1枚以上を追加してください。他の画像は任意です。アップロードは写真ライブラリ選択のみ対応します。")
            )

            LazyVGrid(columns: [GridItem(.flexible())], spacing: 12) {
                ForEach(EventUploadImageZone.allCases) { zone in
                    EventUploadImageZoneCard(
                        zone: zone,
                        images: viewModel.draft.imageZones[zone] ?? [],
                        isRequired: false,
                        uploadingImageIDs: viewModel.uploadingImageIDs,
                        failedImageIDs: viewModel.failedImageIDs,
                        onPicked: { items in
                            await viewModel.addPickedImages(zone: zone, items: items)
                        },
                        onDelete: { imageID in
                            viewModel.removeImage(zone: zone, imageID: imageID)
                        },
                        onMove: { imageID, direction in
                            viewModel.moveImage(zone: zone, imageID: imageID, direction: direction)
                        }
                    )
                }
            }
        }
    }

    private var basicStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            aiActionButton(title: LT("AI 一键补充", "AI Autofill", "AI自動補完")) {
                showPosterAIImportSheet = true
            }

            sectionTitle(
                LT("基础信息", "Basics", "基本情報"),
                subtitle: LT("先把活动名称、地点、时区和发布来源补清楚。", "Fill in the core event details, location, timezone, and source info first.", "イベント名、場所、タイムゾーン、出典情報を先に入力します。")
            )

            LocalizedExpandableFieldSection(
                title: LT("活动名称", "Event Name", "イベント名"),
                isRequired: true,
                axis: .horizontal,
                includeEnglishFull: false,
                expanded: localizedExpansionBinding(for: "name"),
                primaryPlaceholder: localizedPrimaryFieldPlaceholder(for: LT("活动名称", "Event Name", "イベント名")),
                primaryBinding: localizedBinding(\.name),
                zhBinding: localizedBinding(\.name, language: .zh),
                enBinding: localizedBinding(\.name, language: .en),
                jaBinding: localizedBinding(\.name, language: .ja),
                englishFullBinding: nil,
                extraCount: viewModel.draft.name.secondaryValueCount(excluding: viewModel.draft.preferredLanguage),
                preferredLanguage: viewModel.draft.preferredLanguage
            )

            uploadTextField(
                title: LT("活动简称", "Event Abbreviation", "イベント略称"),
                text: abbreviationBinding
            )

            uploadTextField(
                title: LT("活动简介", "Event Description", "イベント紹介"),
                text: descriptionBinding,
                axis: .vertical
            )

            VStack(alignment: .leading, spacing: 8) {
                fieldTitle(LT("活动类型", "Event Type", "イベント種別"), isRequired: false)
                Picker(EventTypeOption.pickerPrompt, selection: eventTypeBinding) {
                    Text(EventTypeOption.pickerPrompt).tag("")
                    ForEach(EventTypeOption.allCases, id: \.rawValue) { option in
                        Text(EventTypeOption.displayTitle(for: option.rawValue)).tag(option.rawValue)
                    }
                }
                .pickerStyle(.menu)
                .tint(RaverTheme.accent)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(fieldBackground)
            }

            LocalizedExpandableFieldSection(
                title: LT("城市", "City", "都市"),
                isRequired: true,
                axis: .horizontal,
                includeEnglishFull: false,
                showClearI18nAction: true,
                expanded: localizedExpansionBinding(for: "city"),
                primaryPlaceholder: localizedPrimaryFieldPlaceholder(for: LT("城市", "City", "都市")),
                primaryBinding: localizedBinding(\.city),
                zhBinding: localizedBinding(\.city, language: .zh),
                enBinding: localizedBinding(\.city, language: .en),
                jaBinding: localizedBinding(\.city, language: .ja),
                englishFullBinding: nil,
                extraCount: viewModel.draft.city.secondaryValueCount(excluding: viewModel.draft.preferredLanguage),
                preferredLanguage: viewModel.draft.preferredLanguage,
                onClearI18n: { viewModel.clearLocalizedI18n(\.city) }
            )

            LocalizedExpandableFieldSection(
                title: LT("国家", "Country", "国"),
                isRequired: true,
                axis: .horizontal,
                includeEnglishFull: true,
                showClearI18nAction: true,
                expanded: localizedExpansionBinding(for: "country"),
                primaryPlaceholder: localizedPrimaryFieldPlaceholder(for: LT("国家", "Country", "国")),
                primaryBinding: localizedBinding(\.country),
                zhBinding: localizedBinding(\.country, language: .zh),
                enBinding: localizedBinding(\.country, language: .en),
                jaBinding: localizedBinding(\.country, language: .ja),
                englishFullBinding: localizedEnglishFullBinding(\.country),
                extraCount: viewModel.draft.country.secondaryValueCount(excluding: viewModel.draft.preferredLanguage, includeEnglishFull: true),
                preferredLanguage: viewModel.draft.preferredLanguage,
                onClearI18n: { viewModel.clearLocalizedI18n(\.country, includeEnglishFull: true) }
            )

            LocalizedExpandableFieldSection(
                title: LT("详细地址", "Detailed Address", "詳細住所"),
                isRequired: true,
                axis: .vertical,
                includeEnglishFull: false,
                expanded: localizedExpansionBinding(for: "detailAddress"),
                primaryPlaceholder: localizedPrimaryFieldPlaceholder(for: LT("详细地址", "Detailed Address", "詳細住所")),
                primaryBinding: localizedBinding(\.detailAddress),
                zhBinding: localizedBinding(\.detailAddress, language: .zh),
                enBinding: localizedBinding(\.detailAddress, language: .en),
                jaBinding: localizedBinding(\.detailAddress, language: .ja),
                englishFullBinding: nil,
                extraCount: viewModel.draft.detailAddress.secondaryValueCount(excluding: viewModel.draft.preferredLanguage),
                preferredLanguage: viewModel.draft.preferredLanguage
            )

            LocalizedExpandableFieldSection(
                title: LT("场地展示地址", "Venue Display Address", "会場表示住所"),
                isRequired: false,
                axis: .vertical,
                includeEnglishFull: false,
                expanded: localizedExpansionBinding(for: "manualSetAddress"),
                primaryPlaceholder: LT(
                    "可选填写；留空时自动回退到地图格式化地址",
                    "Optional; falls back to the map formatted address when empty",
                    "任意入力。未入力時は地図の整形住所にフォールバック"
                ),
                primaryBinding: localizedBinding(\.manualSetAddress),
                zhBinding: localizedBinding(\.manualSetAddress, language: .zh),
                enBinding: localizedBinding(\.manualSetAddress, language: .en),
                jaBinding: localizedBinding(\.manualSetAddress, language: .ja),
                englishFullBinding: nil,
                extraCount: viewModel.draft.manualSetAddress.secondaryValueCount(excluding: viewModel.draft.preferredLanguage),
                preferredLanguage: viewModel.draft.preferredLanguage
            )

            VStack(alignment: .leading, spacing: 10) {
                readonlyAddressPreviewCard(
                    title: LT("最终活动地址", "Final Activity Address", "最終イベント住所"),
                    value: viewModel.manualLocationFormattedAddressSummary,
                    emptyText: LT(
                        "填写详细地址、城市、国家后，这里会展示 manualLocation.formattedAddressI18n。",
                        "manualLocation.formattedAddressI18n appears here after detailed address, city, and country are filled.",
                        "詳細住所・都市・国を入力すると、ここに manualLocation.formattedAddressI18n が表示されます。"
                    ),
                    hint: LT(
                        "只读预览：最终写入 manualLocation.formattedAddressI18n",
                        "Read-only preview of manualLocation.formattedAddressI18n",
                        "読み取り専用プレビュー: manualLocation.formattedAddressI18n"
                    )
                )
                readonlyAddressPreviewCard(
                    title: LT("最终地图格式化地址", "Final Map Formatted Address", "最終地図整形住所"),
                    value: viewModel.locationPointFormattedAddressSummary,
                    emptyText: LT(
                        "完成地图选点后，这里会展示 locationPoint.formattedAddressI18n。",
                        "locationPoint.formattedAddressI18n appears here after map selection.",
                        "地図選択後、ここに locationPoint.formattedAddressI18n が表示されます。"
                    ),
                    hint: LT(
                        "只读预览：优先保留地图 provider 返回的格式化地址",
                        "Read-only preview that preserves the provider formatted address first",
                        "読み取り専用プレビュー: 地図 provider の整形住所を優先保持"
                    )
                )
                readonlyAddressPreviewCard(
                    title: LT("最终场地展示地址", "Final Venue Display Address", "最終会場表示住所"),
                    value: viewModel.locationPointManualSetAddressSummary,
                    emptyText: LT(
                        "未填写时不会写入 manualSetAddressI18n，展示层会回退到地图格式化地址。",
                        "When empty, manualSetAddressI18n is not written and display falls back to the map formatted address.",
                        "未入力時は manualSetAddressI18n は保存されず、表示は地図の整形住所にフォールバックします。"
                    ),
                    hint: LT(
                        "只读预览：最终写入 locationPoint.manualSetAddressI18n",
                        "Read-only preview of locationPoint.manualSetAddressI18n",
                        "読み取り専用プレビュー: locationPoint.manualSetAddressI18n"
                    )
                )
            }

            VStack(alignment: .leading, spacing: 8) {
                fieldTitle(LT("地图选点", "Map Location", "地図選択"), isRequired: false)
                HStack(spacing: 10) {
                    Button {
                        showLocationPicker = true
                    } label: {
                        Label(
                            viewModel.coordinateSummary == nil ? LT("选择位置", "Choose", "選択") : LT("重新选择", "Change", "変更"),
                            systemImage: "map"
                        )
                        .font(.caption.weight(.bold))
                    }
                    .buttonStyle(.bordered)

                    if viewModel.coordinateSummary != nil {
                        Label(LT("已绑定", "Bound", "紐付け済み"), systemImage: "checkmark.seal.fill")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.green)
                        Button {
                            viewModel.clearLocationBinding()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(RaverTheme.secondaryText)
                        }
                        .buttonStyle(.plain)
                    }
                    Spacer()
                }

                if let coordinateSummary = viewModel.coordinateSummary {
                    VStack(alignment: .leading, spacing: 4) {
                        if !viewModel.draft.pickedPlaceName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Text(viewModel.draft.pickedPlaceName)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(RaverTheme.primaryText)
                        }
                        if let venueDisplaySummary = viewModel.venueDisplaySummary {
                            Text(venueDisplaySummary)
                                .font(.caption)
                                .foregroundStyle(RaverTheme.secondaryText)
                                .fixedSize(horizontal: false, vertical: true)
                        } else if !viewModel.draft.pickedMapAddress.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Text(viewModel.draft.pickedMapAddress)
                                .font(.caption)
                                .foregroundStyle(RaverTheme.secondaryText)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Text(coordinateSummary)
                            .font(.caption2)
                            .foregroundStyle(RaverTheme.secondaryText)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(RaverTheme.card, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(RaverTheme.cardBorder, lineWidth: 1)
                    )
                }
            }

            timeZoneSearchSection

            organizerSearchSection

            uploadTextField(
                title: LT("原文链接", "Source URL", "原文リンク"),
                text: sourceURLBinding
            )

            uploadTextField(
                title: LT("官网链接", "Official Website", "公式サイト"),
                text: officialWebsiteBinding
            )

            uploadTextField(
                title: LT("来源平台", "Source Provider", "ソース元"),
                text: sourceProviderBinding
            )

            uploadTextField(
                title: LT("Reference Links (one per line)", "Reference Links (one per line)", "Reference Links (one per line)"),
                text: referenceLinksTextBinding,
                axis: .vertical
            )

            uploadTextField(
                title: LT("Social Links JSON", "Social Links JSON", "Social Links JSON"),
                text: socialLinksTextBinding,
                axis: .vertical
            )

        }
    }

    private var timeStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionTitle(
                LT("活动周期", "Schedule", "開催期間"),
                subtitle: ""
            )

            VStack(alignment: .leading, spacing: 8) {
                fieldTitle(LT("活动跨度", "Schedule Mode", "開催期間"), isRequired: false)
                HStack(spacing: 8) {
                    ForEach(EventUploadScheduleMode.allCases) { mode in
                        scheduleModeCard(mode)
                    }
                }
            }

            if viewModel.draft.isSingleDaySchedule {
                centeredDateSection {
                    scheduleDateCard(
                        title: LT("活动日期", "Event Date", "開催日"),
                        selection: singleDayDateBinding
                    )
                }
            } else {
                HStack(spacing: 12) {
                    scheduleDateCard(
                        title: LT("开始日期", "Start Date", "開始日"),
                        selection: dateBinding(\.startDate)
                    )
                    scheduleDateCard(
                        title: LT("结束日期", "End Date", "終了日"),
                        selection: dateBinding(\.endDate)
                    )
                }
            }

            eventTimeZoneContextCard

            if viewModel.draft.isMultiWeekSchedule {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text(LT("每周的日期", "Weekly ranges", "週ごとの日付"))
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(RaverTheme.primaryText)
                        Spacer()
                        Text(LT("\(viewModel.draft.editableWeekRanges.count) 个 Week", "\(viewModel.draft.editableWeekRanges.count) weeks", "\(viewModel.draft.editableWeekRanges.count)個のWeek"))
                            .font(.caption)
                            .foregroundStyle(RaverTheme.secondaryText)
                    }

                    ForEach(Array(viewModel.draft.editableWeekRanges.enumerated()), id: \.element.id) { index, week in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(alignment: .top) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Week \(index + 1)")
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(RaverTheme.primaryText)
                                    Text(weekDateDurationSummary(week))
                                        .font(.caption)
                                        .foregroundStyle(RaverTheme.secondaryText)
                                }
                                Spacer()
                                if viewModel.draft.editableWeekRanges.count > 1 {
                                    Button {
                                        viewModel.removeWeekRange(id: week.id)
                                    } label: {
                                        Image(systemName: "trash")
                                            .font(.caption.weight(.bold))
                                            .foregroundStyle(.red)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }

                            HStack(spacing: 6) {
                                compactWeekDatePicker(
                                    title: LT("开始", "Start", "開始"),
                                    selection: weekDateBinding(id: week.id, field: .start)
                                )
                                .layoutPriority(1)

                                Image(systemName: "arrow.right")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(RaverTheme.secondaryText)
                                    .frame(width: 12)

                                compactWeekDatePicker(
                                    title: LT("结束", "End", "終了"),
                                    selection: weekDateBinding(id: week.id, field: .end)
                                )
                                .layoutPriority(1)
                            }
                        }
                        .padding(14)
                        .background(RaverTheme.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(RaverTheme.cardBorder, lineWidth: 1)
                        )
                    }

                    Button {
                        viewModel.addWeekRange()
                    } label: {
                        HStack(spacing: 10) {
                            Label(LT("添加一周", "Add Week", "週を追加"), systemImage: "plus.circle.fill")
                                .font(.subheadline.weight(.semibold))
                            Spacer()
                            Text(LT("继续拆分活动周期", "Split the schedule further", "さらに期間を分割"))
                                .font(.caption)
                                .foregroundStyle(RaverTheme.secondaryText)
                                .lineLimit(1)
                                .minimumScaleFactor(0.75)
                        }
                        .foregroundStyle(RaverTheme.accent)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .background(RaverTheme.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(RaverTheme.cardBorder, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }

            VStack(alignment: .leading, spacing: 12) {
                Text(LT("高级选项", "Advanced", "詳細設定"))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(RaverTheme.secondaryText)

                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showAdvancedRollover.toggle()
                    }
                } label: {
                    HStack(spacing: 10) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(LT("跨天切日时间", "Overnight Rollover", "日付切替時刻"))
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(RaverTheme.primaryText)
                                .multilineTextAlignment(.leading)
                            Text(LT("凌晨几点前的表演属于前一天", "Performances before this hour count as the previous day", "この時刻前の公演は前日扱い"))
                                .font(.caption2)
                                .foregroundStyle(RaverTheme.secondaryText)
                            Text("\(viewModel.draft.dayRolloverHour):00")
                                .font(.caption)
                                .foregroundStyle(RaverTheme.secondaryText)
                        }
                        Spacer()
                        Image(systemName: showAdvancedRollover ? "chevron.up" : "chevron.down")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(RaverTheme.secondaryText)
                    }
                    .padding(14)
                    .background(RaverTheme.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(RaverTheme.cardBorder, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)

                if showAdvancedRollover {
                    HStack(spacing: 18) {
                        Button {
                            dayRolloverBinding.wrappedValue = max(dayRolloverBinding.wrappedValue - 1, 0)
                        } label: {
                            Image(systemName: "minus")
                                .font(.headline.weight(.bold))
                                .foregroundStyle(RaverTheme.primaryText)
                                .frame(width: 34, height: 34)
                                .background(RaverTheme.background, in: Circle())
                        }
                        .buttonStyle(.plain)

                        VStack(spacing: 4) {
                            Text("\(viewModel.draft.dayRolloverHour):00")
                                .font(.system(size: 26, weight: .bold))
                                .foregroundStyle(RaverTheme.primaryText)
                            Text(LT("凌晨前仍归前一日", "Before this still counts as previous day", "この時刻前は前日扱い"))
                                .font(.caption)
                                .foregroundStyle(RaverTheme.secondaryText)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)

                        Button {
                            dayRolloverBinding.wrappedValue = min(dayRolloverBinding.wrappedValue + 1, 12)
                        } label: {
                            Image(systemName: "plus")
                                .font(.headline.weight(.bold))
                                .foregroundStyle(.white)
                                .frame(width: 34, height: 34)
                                .background(RaverTheme.accent, in: Circle())
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.vertical, 10)
                    .padding(.horizontal, 12)
                    .background(RaverTheme.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }

            if viewModel.draft.endDate < viewModel.draft.startDate {
                Text(LT("结束日期不能早于开始日期。", "End date cannot be earlier than start date.", "終了日は開始日より前にできません。"))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.red)
            }
        }
    }

    private var timetableStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionTitle(
                LT("时间表", "Timetable", "タイムテーブル"),
                subtitle: LT("这一页可以完全跳过。只有当你要补充演出时间表时，才需要添加舞台并按 Week 编辑。", "This step is optional. Add stages and edit by week only if you want to provide a timetable.", "このステップは任意です。タイムテーブルを補足したい場合のみ、ステージ追加とWeek編集を行ってください。")
            )

            aiActionButton(title: LT("AI 识别活动时间表", "AI Timetable Import", "AIタイムテーブル認識")) {
                showTimetableAIImportSheet = true
            }

            inlineInfoCard(
                LT("如果暂时没有时间表信息，可以直接跳过这一页。", "You can skip this page if you do not have timetable details yet.", "タイムテーブル情報がまだなければ、このページはそのままスキップできます。")
            )

            timetableIssueCenter(
                issues: timetableIssues,
                title: LT("时间表待处理", "Timetable Needs Attention", "タイムテーブル要確認"),
                emptyMessage: LT("当前没有会阻塞下一步的时间表问题。", "No timetable issues are blocking the next step.", "次へ進むのを妨げるタイムテーブル問題はありません。")
            )

            Button {
                viewModel.addStage()
            } label: {
                Label(LT("添加舞台", "Add Stage", "ステージを追加"), systemImage: "plus")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(RaverTheme.accent, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)

            if !viewModel.draft.stageEntries.isEmpty || !viewModel.draft.timetableSlots.isEmpty {
                Button {
                    showClearAllTimetableConfirmation = true
                } label: {
                    Label(LT("一键删除全部时间表", "Clear All Timetable", "タイムテーブルを全削除"), systemImage: "trash.fill")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.red, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
            }

            if viewModel.draft.stageEntries.isEmpty {
                Text(LT("如果这一场没有时间表，可以直接跳过这一页。需要填写时间表时，再添加舞台即可；名称留空会默认显示为主舞台。", "You can skip this step if there is no timetable yet. Add a stage only when you want to fill schedule details; empty names default to Main Stage.", "タイムテーブルが未定ならこのページはそのままスキップできます。入力したいときだけステージを追加してください。空欄名はメインステージとして扱われます。"))
                    .font(.subheadline)
                    .foregroundStyle(RaverTheme.secondaryText)
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RaverTheme.card, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            } else {
                VStack(spacing: 10) {
                    ForEach(Array(viewModel.draft.stageEntries.enumerated()), id: \.offset) { index, _ in
                        HStack(spacing: 10) {
                            Text("Stage \(index + 1)")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(RaverTheme.secondaryText)
                                .frame(width: 58, alignment: .leading)

                            TextField(
                                LT("舞台名称（可选）", "Stage name (optional)", "ステージ名（任意）"),
                                text: stageBinding(index)
                            )
                            .font(.body)
                            .foregroundStyle(RaverTheme.primaryText)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 11)
                            .background(fieldBackground)

                            Button {
                                viewModel.moveStage(at: index, direction: -1)
                            } label: {
                                Image(systemName: "chevron.up")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(RaverTheme.secondaryText)
                                    .frame(width: 28, height: 28)
                                    .background(RaverTheme.background.opacity(index == 0 ? 0.55 : 1), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                            }
                            .buttonStyle(.plain)
                            .disabled(index == 0)

                            Button {
                                viewModel.moveStage(at: index, direction: 1)
                            } label: {
                                Image(systemName: "chevron.down")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(RaverTheme.secondaryText)
                                    .frame(width: 28, height: 28)
                                    .background(RaverTheme.background.opacity(index == viewModel.draft.stageEntries.count - 1 ? 0.55 : 1), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                            }
                            .buttonStyle(.plain)
                            .disabled(index == viewModel.draft.stageEntries.count - 1)

                            Button {
                                stageIndexPendingDeletion = index
                            } label: {
                                Image(systemName: "trash")
                                    .font(.subheadline.weight(.bold))
                                    .foregroundStyle(.red)
                                    .frame(width: 32, height: 32)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                if let message = viewModel.stageNameValidationMessage {
                    Text(message)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.red)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.red.opacity(0.1), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                Text(LT("按 Week 编辑时间表", "Edit timetable by week", "Weekごとに編集"))
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(RaverTheme.primaryText)

                if viewModel.draft.stageEntries.isEmpty {
                    Text(LT("还没有舞台，所以这里暂时不会生成 Week 时间表入口。", "There are no stages yet, so week timetable entry cards are hidden for now.", "ステージ未追加のため、Weekタイムテーブル入口はまだ表示されません。"))
                        .font(.caption)
                        .foregroundStyle(RaverTheme.secondaryText)
                } else {
                        ForEach(Array(displayWeekRanges.enumerated()), id: \.element.id) { index, week in
                            Button {
                                if viewModel.canOpenTimetableWeekEditor {
                                    selectedWeekForEditing = EventUploadWeekSelection(index: index, week: week)
                                } else {
                                    viewModel.statusMessage = viewModel.stageNameValidationMessage
                                }
                            } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text("Week \(index + 1)")
                                        .font(.subheadline.weight(.bold))
                                        .foregroundStyle(RaverTheme.primaryText)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(RaverTheme.secondaryText)
                                }
                                Text(weekRangeSummary(week))
                                    .font(.caption)
                                    .foregroundStyle(RaverTheme.secondaryText)
                                Text(weekTimetableSummary(for: index, week: week))
                                    .font(.caption)
                                    .foregroundStyle(RaverTheme.accent)
                                Text(LT("点击进入编辑这一周的节目单", "Tap to edit this week's schedule", "この週のタイムテーブルを編集"))
                                    .font(.caption2)
                                    .foregroundStyle(RaverTheme.secondaryText)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(14)
                            .background(RaverTheme.card, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(RaverTheme.cardBorder, lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var timetableIssues: [String] {
        EventUploadValidation.issues(for: viewModel.draft)
            .filter { $0.step == .timetable }
            .map(\.message)
    }

    @ViewBuilder
    private func timetableIssueCenter(
        issues: [String],
        title: String,
        emptyMessage: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: issues.isEmpty ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(issues.isEmpty ? .green : .orange)
                Text(title)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(RaverTheme.primaryText)
                Spacer(minLength: 0)
                Text(issues.isEmpty ? LT("OK", "OK", "OK") : "\(issues.count)")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(issues.isEmpty ? .green : .orange)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background((issues.isEmpty ? Color.green : Color.orange).opacity(0.12), in: Capsule())
            }

            if issues.isEmpty {
                Text(emptyMessage)
                    .font(.caption)
                    .foregroundStyle(RaverTheme.secondaryText)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(issues.prefix(6).enumerated()), id: \.offset) { index, issue in
                        HStack(alignment: .top, spacing: 8) {
                            Text("\(index + 1)")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(.white)
                                .frame(width: 18, height: 18)
                                .background(Color.orange, in: Circle())
                            Text(issue)
                                .font(.caption)
                                .foregroundStyle(RaverTheme.primaryText)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    if issues.count > 6 {
                        Text(LT("还有 \(issues.count - 6) 个问题，请继续检查下方条目。", "\(issues.count - 6) more issues. Continue reviewing the entries below.", "他に \(issues.count - 6) 件あります。下の項目を続けて確認してください。"))
                            .font(.caption)
                            .foregroundStyle(RaverTheme.secondaryText)
                    }
                }
            }
        }
        .padding(14)
        .background(RaverTheme.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke((issues.isEmpty ? Color.green : Color.orange).opacity(0.32), lineWidth: 1)
        )
    }

    private var ticketsStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionTitle(
                LT("票务信息", "Tickets", "チケット"),
                subtitle: LT("票务可以留空。支持按实际情况手动添加多个票档。", "Ticket info is optional. Add as many tiers as you need.", "チケット情報は任意です。必要に応じて複数の券種を追加できます。")
            )

            HStack(spacing: 12) {
                ticketFieldCard(title: LT("币种", "Currency", "通貨"), text: ticketBinding(\.currency))
                ticketFieldCard(title: LT("购票链接", "Ticket URL", "チケットURL"), text: ticketBinding(\.ticketURL))
            }

            uploadTextField(
                title: LT("票务备注", "Ticket Notes", "チケット備考"),
                text: ticketNotesBinding,
                axis: .vertical
            )

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(LT("票档", "Ticket Tiers", "券種"))
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(RaverTheme.primaryText)
                    Spacer()
                    Text(LT("\(viewModel.draft.ticket.tiers.count) 个", "\(viewModel.draft.ticket.tiers.count)", "\(viewModel.draft.ticket.tiers.count)件"))
                        .font(.caption)
                        .foregroundStyle(RaverTheme.secondaryText)
                }

                if viewModel.draft.ticket.tiers.isEmpty {
                    Text(LT("可以不填写票务信息；如果已知价格，可以添加多个票档。", "You can skip tickets, or add tiers if pricing is known.", "チケット情報は未入力でも構いません。価格が分かる場合は券種を追加できます。"))
                        .font(.caption)
                        .foregroundStyle(RaverTheme.secondaryText)
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(RaverTheme.card, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                } else {
                    VStack(spacing: 10) {
                        ForEach(Array(viewModel.draft.ticket.tiers.enumerated()), id: \.element.id) { index, tier in
                            ticketTierCard(tier, order: index + 1)
                        }
                    }
                }

                Button {
                    _ = viewModel.addTicketTier()
                } label: {
                    HStack {
                        Label(LT("添加票档", "Add Ticket Tier", "券種を追加"), systemImage: "plus.circle.fill")
                            .font(.subheadline.weight(.bold))
                        Spacer()
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 13)
                    .background(
                        LinearGradient(
                            colors: [RaverTheme.accent, RaverTheme.accent.opacity(0.78)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var reviewStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionTitle(
                LT("提交前检查", "Review", "確認"),
                subtitle: LT("这里汇总媒体、信息、时间、阵容和票务，确认无误后再提交。", "Review media, details, schedule, lineup, and tickets before submitting.", "メディア、情報、日程、ラインナップ、チケットを確認してから送信します。")
            )

            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(LT("提交前检查", "Pre-submit Check", "送信前チェック"))
                            .font(.headline)
                            .foregroundStyle(RaverTheme.primaryText)
                        Text(LT("这里汇总票务、基础信息和阵容状态，提交前再扫一眼。", "Review tickets, basics, and lineup status here before submitting.", "ここでチケット、基本情報、ラインナップ状態をまとめて確認できます。"))
                            .font(.caption)
                            .foregroundStyle(RaverTheme.secondaryText)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(reviewCompletionValue)
                            .font(.title3.weight(.bold))
                            .foregroundStyle(RaverTheme.accent)
                        Text(LT("项已就绪", "items ready", "項目準備完了"))
                            .font(.caption2)
                            .foregroundStyle(RaverTheme.secondaryText)
                    }
                }

                HStack(spacing: 10) {
                    reviewSummaryChip(title: LT("时间表节目", "Timetable Sets", "タイムテーブル"), value: "\(viewModel.draft.timetableSlots.count)")
                    reviewSummaryChip(title: LT("仅阵容条目", "Lineup Only", "ラインナップのみ"), value: "\(viewModel.draft.lineupOnlySlots.count)")
                    reviewSummaryChip(title: LT("待补齐", "Missing", "補完待ち"), value: "\(viewModel.lineupArtistsMissingFromLineup.count)")
                    reviewSummaryChip(title: LT("图片数量", "Images", "画像"), value: "\(uploadedImageCount)")
                }
            }
            .padding(16)
            .background(RaverTheme.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(RaverTheme.cardBorder, lineWidth: 1)
            )

            reviewCard(
                title: LT("媒体", "Media", "メディア"),
                rows: EventUploadImageZone.allCases.map { zone in
                    "\(zone.title): \(viewModel.draft.imageZones[zone]?.count ?? 0)"
                }
            )

            reviewCard(
                title: LT("基础", "Basics", "基本"),
                rows: [
                    viewModel.draft.name.primaryValue(preferredLanguage: viewModel.draft.preferredLanguage),
                    EventTypeOption.displayText(for: viewModel.draft.eventType, fallbackWhenEmpty: false),
                    viewModel.draft.description.trimmingCharacters(in: .whitespacesAndNewlines),
                    viewModel.locationSummary,
                    viewModel.draft.sourceURL.trimmingCharacters(in: .whitespacesAndNewlines),
                    viewModel.draft.officialWebsite.trimmingCharacters(in: .whitespacesAndNewlines),
                ].filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            )

            reviewCard(
                title: LT("时间", "Time", "時間"),
                rows: [
                    viewModel.draft.effectiveScheduleMode.title,
                    viewModel.reviewDateRange,
                    viewModel.draft.timeZoneIdentifier,
                    LT("跨天切日：\(viewModel.draft.dayRolloverHour):00", "Rollover: \(viewModel.draft.dayRolloverHour):00", "日付切替：\(viewModel.draft.dayRolloverHour):00"),
                ]
            )

            reviewCard(
                title: LT("票务", "Tickets", "チケット"),
                rows: reviewTicketRows
            )

            reviewCard(
                title: LT("阵容", "Lineup", "ラインナップ"),
                rows: (viewModel.draft.timetableSlots.map { slot in
                    let name = EventLineupActCodec.composeName(type: slot.actType, performerNames: slot.performerNames)
                    let stage = slot.stageName.trimmingCharacters(in: .whitespacesAndNewlines)
                    return stage.isEmpty ? name : "\(name) · \(stage)"
                } + viewModel.draft.lineupOnlySlots.map { slot in
                    EventLineupActCodec.composeName(type: slot.actType, performerNames: slot.performerNames)
                })
            )

            if viewModel.lineupNeedsIncrementalFill || !viewModel.lineupArtistsOnlyInLineup.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text(LT("阵容与时间表差异", "Lineup vs Timetable", "ラインナップ差分"))
                        .font(.headline)
                        .foregroundStyle(RaverTheme.primaryText)
                    if viewModel.lineupNeedsIncrementalFill {
                        inlineInfoCard(
                            LT(
                                "时间表里有 \(viewModel.lineupArtistsMissingFromLineup.count) 位 DJ 还没进入阵容，可以先补齐后再提交。",
                                "\(viewModel.lineupArtistsMissingFromLineup.count) timetable DJs are not yet in the lineup. You can fill them into the lineup before submitting.",
                                "タイムテーブル内の \(viewModel.lineupArtistsMissingFromLineup.count) 件のDJがまだラインナップに入っていません。送信前に補完できます。"
                            )
                        )
                    }
                    if !viewModel.lineupArtistsOnlyInLineup.isEmpty {
                        inlineInfoCard(
                            LT(
                                "当前有 \(viewModel.lineupArtistsOnlyInLineup.count) 位艺人只存在于阵容中，默认提交会保留他们。",
                                "\(viewModel.lineupArtistsOnlyInLineup.count) artists exist only in the lineup right now. Default submit will keep them.",
                                "現在 \(viewModel.lineupArtistsOnlyInLineup.count) 件の出演者がラインナップのみに存在しています。通常送信では保持されます。"
                            )
                        )
                    }
                    HStack(spacing: 10) {
                        Button {
                            _ = viewModel.applyTimetableIncrementalFillToLineup()
                        } label: {
                            compactActionButtonLabel(
                                title: LT("补齐阵容", "Fill Lineup", "ラインナップ補完"),
                                systemImage: "plus.circle.fill",
                                filled: true
                            )
                        }
                        .buttonStyle(.plain)
                        .disabled(!viewModel.lineupNeedsIncrementalFill)

                        Button {
                            Task { await viewModel.prepareExactLineupAlignment() }
                        } label: {
                            compactActionButtonLabel(
                                title: LT("精确对齐", "Exact Align", "完全同期"),
                                systemImage: "arrow.triangle.2.circlepath",
                                filled: false
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var lineupStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionTitle(
                LT("仅阵容信息", "Lineup Only", "ラインナップのみ"),
                subtitle: ""
            )

            aiActionButton(title: LT("AI 识别阵容图", "AI Lineup Import", "AIラインナップ認識")) {
                showLineupAIImportSheet = true
            }

            inlineInfoCard(
                LT("如果暂时没有阵容信息，也可以直接跳过这一页。", "You can also skip this page if you do not have lineup details yet.", "ラインナップ情報がまだなければ、このページもそのままスキップできます。")
            )

            if viewModel.lineupNeedsIncrementalFill || !viewModel.lineupArtistsOnlyInLineup.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    if viewModel.lineupNeedsIncrementalFill {
                        inlineInfoCard(
                            LT(
                                "时间表中有 \(viewModel.lineupArtistsMissingFromLineup.count) 位 DJ 尚未加入阵容。默认提交不会自动删阵容，但你可以先一键补齐。",
                                "\(viewModel.lineupArtistsMissingFromLineup.count) timetable DJs are not yet in the lineup. Default submit will not remove lineup artists, but you can fill the lineup first.",
                                "タイムテーブル内の \(viewModel.lineupArtistsMissingFromLineup.count) 件のDJがまだラインナップに入っていません。通常送信ではラインナップを削除しませんが、先に補完できます。"
                            )
                        )
                    }
                    if !viewModel.lineupArtistsOnlyInLineup.isEmpty {
                        inlineInfoCard(
                            LT(
                                "阵容中有 \(viewModel.lineupArtistsOnlyInLineup.count) 位艺人目前不在时间表里，这些艺人默认会保留。",
                                "\(viewModel.lineupArtistsOnlyInLineup.count) lineup artists are not currently in the timetable. They will be kept by default.",
                                "ラインナップ内の \(viewModel.lineupArtistsOnlyInLineup.count) 件の出演者は現在タイムテーブルにありませんが、通常は保持されます。"
                            )
                        )
                    }
                    HStack(spacing: 10) {
                        Button {
                            _ = viewModel.applyTimetableIncrementalFillToLineup()
                        } label: {
                            compactActionButtonLabel(
                                title: LT("用时间表补齐阵容", "Fill from Timetable", "タイムテーブルで補完"),
                                systemImage: "plus.circle.fill",
                                filled: true
                            )
                        }
                        .buttonStyle(.plain)
                        .disabled(!viewModel.lineupNeedsIncrementalFill)

                        Button {
                            Task { await viewModel.prepareExactLineupAlignment() }
                        } label: {
                            compactActionButtonLabel(
                                title: LT("按时间表精确对齐", "Exact Align to Timetable", "タイムテーブルに完全同期"),
                                systemImage: "exclamationmark.arrow.triangle.2.circlepath",
                                filled: false
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            HStack(spacing: 8) {
                Image(systemName: "music.mic")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(RaverTheme.accent)
                Text(
                    LT(
                        "已添加 \(viewModel.draft.lineupOnlySlots.count) 个，已绑定 \(lineupBoundDJCount) 位",
                        "\(viewModel.draft.lineupOnlySlots.count) added, \(lineupBoundDJCount) bound",
                        "\(viewModel.draft.lineupOnlySlots.count)件追加、\(lineupBoundDJCount)件紐付け"
                    )
                )
                .font(.caption.weight(.semibold))
                .foregroundStyle(RaverTheme.secondaryText)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(RaverTheme.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(RaverTheme.cardBorder, lineWidth: 1)
            )

            if !viewModel.draft.lineupOnlySlots.isEmpty {
                VStack(spacing: 10) {
                    ForEach(Array(viewModel.draft.lineupOnlySlots.enumerated()), id: \.element.id) { index, slot in
                        lineupOnlySlotEditor(slot, order: index + 1)
                    }
                }
            }

            Button {
                let id = viewModel.addLineupOnlySlot()
                expandedLineupOnlySlots.insert(id)
            } label: {
                HStack {
                    Label(LT("添加阵容", "Add Lineup", "ラインナップを追加"), systemImage: "plus.circle.fill")
                        .font(.subheadline.weight(.bold))
                    Spacer()
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 13)
                .background(
                    LinearGradient(
                        colors: [RaverTheme.accent, RaverTheme.accent.opacity(0.78)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                )
            }
            .buttonStyle(.plain)
        }
    }

    private func lineupOnlySlotEditor(_ slot: EventUploadLineupOnlySlotDraft, order: Int) -> some View {
        let expanded = expandedLineupOnlySlots.contains(slot.id) || !isLineupOnlyCollapsedEligible(slot)
        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Text("\(order)")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(RaverTheme.secondaryText)
                    .frame(width: 18, alignment: .leading)

                lineupOnlyPerformerAvatarStack(slot)

                Text(lineupOnlyDisplayName(slot))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(RaverTheme.primaryText)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Button {
                    if expanded, isLineupOnlyCollapsedEligible(slot) {
                        expandedLineupOnlySlots.remove(slot.id)
                    } else {
                        expandedLineupOnlySlots.insert(slot.id)
                    }
                } label: {
                    Image(systemName: expanded ? "chevron.up" : "square.and.pencil")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(expanded ? RaverTheme.accent : RaverTheme.secondaryText)
                        .frame(width: 30, height: 30)
                        .background(RaverTheme.background, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(.plain)

                Button {
                    viewModel.removeLineupOnlySlot(id: slot.id)
                    expandedLineupOnlySlots.remove(slot.id)
                } label: {
                    Image(systemName: "trash")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.red)
                        .frame(width: 28, height: 28)
                        .background(RaverTheme.background, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(.plain)
            }

            if expanded {
                Picker(LT("演出形式", "Act Type", "出演形式"), selection: lineupActTypeBinding(slot.id)) {
                    ForEach(EventLineupActType.allCases) { type in
                        Text(type.title).tag(type)
                    }
                }
                .pickerStyle(.segmented)

                ForEach(0..<slot.actType.performerCount, id: \.self) { index in
                    VStack(alignment: .leading, spacing: 10) {
                        let djKey = viewModel.djSearchKey(slotID: slot.id, performerIndex: index)
                        let performerName = slot.performerNames.indices.contains(index) ? slot.performerNames[index] : ""
                        let canClear = !performerName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || lineupOnlyIsBound(slot, index: index)
                        HStack(spacing: 10) {
                            lineupOnlyPerformerAvatar(slot, index: index)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(slot.actType == .solo ? LT("DJ / 艺人名称", "Artist / DJ Name", "DJ / アーティスト名") : LT("成员 \(index + 1)", "Member \(index + 1)", "メンバー \(index + 1)"))
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(RaverTheme.secondaryText)
                                Text(lineupOnlyBindingState(slot, index: index))
                                    .font(.caption2)
                                    .foregroundStyle(RaverTheme.secondaryText)
                            }
                            Spacer()
                            if lineupOnlyIsBound(slot, index: index) {
                                Image(systemName: "checkmark.seal.fill")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(.green)
                            }
                        }

                        djSearchTextField(
                            title: slot.actType == .solo ? LT("输入 DJ / 艺人名称", "Enter artist / DJ name", "DJ / アーティスト名を入力") : LT("输入成员名称", "Enter member name", "メンバー名を入力"),
                            text: lineupOnlyPerformerBinding(slot.id, performerIndex: index),
                            isRequired: true,
                            isSearching: viewModel.searchingDJKeys.contains(djKey),
                            canClear: canClear,
                            clearAction: {
                                viewModel.clearLineupOnlyDJBinding(slotID: slot.id, performerIndex: index)
                                viewModel.updateLineupOnlySlot(id: slot.id) { draftSlot in
                                    while draftSlot.performerNames.count <= index {
                                        draftSlot.performerNames.append("")
                                    }
                                    draftSlot.performerNames[index] = ""
                                }
                            }
                        ) {
                            Task { await viewModel.searchLineupOnlyDJ(slotID: slot.id, performerIndex: index) }
                        }

                        lineupOnlyDJSearchSection(slot, performerIndex: index)
                    }
                    .padding(12)
                    .background(RaverTheme.background, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }

                if isLineupOnlyCollapsedEligible(slot) {
                    HStack {
                        Spacer()
                        Button {
                            expandedLineupOnlySlots.remove(slot.id)
                        } label: {
                            Label(LT("确定", "Done", "確定"), systemImage: "checkmark")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 9)
                                .background(RaverTheme.accent, in: Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(14)
        .background(RaverTheme.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(RaverTheme.cardBorder, lineWidth: 1)
        )
    }

    private var lineupBoundDJCount: Int {
        viewModel.draft.lineupOnlySlots.reduce(into: 0) { partial, slot in
            partial += slot.performerDJIDs.compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }.count
        }
    }

    private func lineupBindingSummary(_ slot: EventUploadLineupOnlySlotDraft) -> String {
        let boundCount = slot.performerDJIDs.compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }.count
        return LT("已绑定 \(boundCount) / \(slot.actType.performerCount)", "\(boundCount) / \(slot.actType.performerCount) bound", "\(slot.actType.performerCount)人中 \(boundCount) 人を紐付け")
    }

    private func lineupOnlyDisplayName(_ slot: EventUploadLineupOnlySlotDraft) -> String {
        let name = EventLineupActCodec.composeName(type: slot.actType, performerNames: slot.performerNames)
        return name.isEmpty ? LT("未命名阵容", "Untitled Lineup", "未命名ラインナップ") : name
    }

    private func isLineupOnlyCollapsedEligible(_ slot: EventUploadLineupOnlySlotDraft) -> Bool {
        let names = slot.performerNames
            .prefix(slot.actType.performerCount)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        return names.count == slot.actType.performerCount && !names.contains(where: { $0.isEmpty })
    }

    private func lineupOnlyIsBound(_ slot: EventUploadLineupOnlySlotDraft, index: Int) -> Bool {
        slot.performerDJIDs.indices.contains(index)
            ? slot.performerDJIDs[index]?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            : false
    }

    private func lineupOnlyBindingState(_ slot: EventUploadLineupOnlySlotDraft, index: Int) -> String {
        let bound = slot.performerDJIDs.indices.contains(index)
            ? slot.performerDJIDs[index]?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            : false
        return bound ? LT("已绑定 DJ 词条", "Bound to DJ entry", "DJエントリ紐付け済み") : LT("可手填，也可绑定 DJ 库", "Manual or DJ binding", "手入力またはDJ紐付け")
    }

    private func lineupOnlyPerformerAvatar(_ slot: EventUploadLineupOnlySlotDraft, index: Int) -> some View {
        let name = slot.performerNames.indices.contains(index) ? slot.performerNames[index] : ""
        let avatarURL = slot.performerAvatarURLs.indices.contains(index) ? slot.performerAvatarURLs[index] : nil
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)

        return Group {
            if let avatarURL,
               let resolved = AppConfig.resolvedDJAvatarURLString(avatarURL, size: .small),
               !resolved.isEmpty {
                AsyncImage(url: URL(string: resolved)) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    default:
                        lineupAvatarFallback(trimmed: trimmed)
                    }
                }
            } else {
                lineupAvatarFallback(trimmed: trimmed)
            }
        }
        .frame(width: 34, height: 34)
        .clipShape(Circle())
        .overlay(
            Circle()
                .stroke(RaverTheme.cardBorder, lineWidth: 1)
        )
    }

    private func lineupOnlyPerformerAvatarStack(_ slot: EventUploadLineupOnlySlotDraft) -> some View {
        HStack(spacing: -10) {
            ForEach(Array(slot.performerNames.prefix(slot.actType.performerCount).enumerated()), id: \.offset) { index, _ in
                lineupOnlyPerformerAvatar(slot, index: index)
            }
        }
        .padding(.trailing, 4)
    }

    private func lineupAvatarFallback(trimmed: String) -> some View {
        ZStack {
            Circle()
                .fill(RaverTheme.background)
            Text(String(trimmed.prefix(1)).uppercased())
                .font(.caption.weight(.bold))
                .foregroundStyle(RaverTheme.accent)
        }
    }

    private func metaTag(_ title: String, tint: Color, foreground: Color) -> some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(foreground)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(tint, in: Capsule())
    }

    private func scheduleModeCard(_ mode: EventUploadScheduleMode) -> some View {
        let isSelected = viewModel.draft.effectiveScheduleMode == mode
        return Button {
            viewModel.updateScheduleMode(mode)
        } label: {
            HStack(alignment: .center, spacing: 8) {
                Text(mode.title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Spacer(minLength: 0)
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.subheadline)
                }
            }
            .foregroundStyle(isSelected ? .white : RaverTheme.primaryText)
            .frame(maxWidth: .infinity, minHeight: 36, alignment: .leading)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                isSelected
                    ? AnyShapeStyle(
                        LinearGradient(
                            colors: [RaverTheme.accent, RaverTheme.accent.opacity(0.78)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    : AnyShapeStyle(RaverTheme.card),
                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(isSelected ? RaverTheme.accent.opacity(0.15) : RaverTheme.cardBorder, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func scheduleDateCard(title: String, selection: Binding<Date>) -> some View {
        VStack(alignment: .center, spacing: 8) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(RaverTheme.secondaryText)
            formattedCompactDatePicker(title: title, selection: selection)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(14)
        .background(RaverTheme.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(RaverTheme.cardBorder, lineWidth: 1)
        )
    }

    private func centeredDateSection<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        HStack {
            Spacer(minLength: 20)
            content()
                .frame(maxWidth: 260)
            Spacer(minLength: 20)
        }
    }

    private var eventTimeZoneContextCard: some View {
        HStack(spacing: 10) {
            Image(systemName: "globe.asia.australia.fill")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(RaverTheme.accent)
            VStack(alignment: .leading, spacing: 2) {
                Text(LT("活动日期按这个时区保存", "Event dates use this timezone", "イベント日付はこのタイムゾーンで保存"))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(RaverTheme.secondaryText)
                Text(eventTimeZoneLabel)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(RaverTheme.primaryText)
                    .lineLimit(1)
            }
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(RaverTheme.card, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(RaverTheme.cardBorder, lineWidth: 1)
        )
    }

    private var eventTimeZoneLabel: String {
        if let item = viewModel.draft.selectedTimeZoneLookup {
            return "\(item.cityAscii.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? item.city : item.cityAscii) · \(item.timezone)"
        }
        return viewModel.draft.timeZoneIdentifier
    }

    private func weekDateField(title: String, value: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(RaverTheme.secondaryText)
                HStack(spacing: 8) {
                    Text(value)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(RaverTheme.primaryText)
                        .lineLimit(1)
                    Spacer()
                    Image(systemName: "calendar")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(RaverTheme.secondaryText)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(10)
            .background(RaverTheme.background, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func weekDateDurationSummary(_ week: EventUploadWeekRangeDraft) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = eventTimeZone
        let days = max((
            calendar.dateComponents(
                [.day],
                from: calendar.startOfDay(for: week.startDate),
                to: calendar.startOfDay(for: max(week.endDate, week.startDate))
            ).day ?? 0
        ) + 1, 1)
        return LT("\(days) 天", "\(days) days", "\(days)日")
    }

    private var uploadedImageCount: Int {
        EventUploadImageZone.allCases.reduce(into: 0) { partial, zone in
            partial += viewModel.draft.imageZones[zone]?.count ?? 0
        }
    }

    private var reviewCompletionValue: String {
        let filled = [
            viewModel.draft.hasRequiredEntryImage,
            !viewModel.draft.name.primaryValue(preferredLanguage: viewModel.draft.preferredLanguage).trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
            !viewModel.locationSummary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
            !viewModel.draft.timeZoneIdentifier.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
            viewModel.draft.ticket.hasTicketInfo
        ].filter { $0 }.count
        return "\(filled)"
    }

    private func reviewSummaryChip(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(RaverTheme.secondaryText)
            Text(value)
                .font(.caption.weight(.semibold))
                .foregroundStyle(RaverTheme.primaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(RaverTheme.background, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func compactActionButtonLabel(title: String, systemImage: String, filled: Bool) -> some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.caption.weight(.bold))
            Text(title)
                .font(.caption.weight(.bold))
                .lineLimit(1)
        }
        .foregroundStyle(filled ? .white : RaverTheme.primaryText)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 12)
        .padding(.vertical, 11)
        .background(
            Group {
                if filled {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [RaverTheme.accent, RaverTheme.accent.opacity(0.78)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                } else {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(RaverTheme.card)
                }
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(filled ? RaverTheme.accent.opacity(0.15) : RaverTheme.cardBorder, lineWidth: 1)
        )
    }

    private func ticketFieldCard(title: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(RaverTheme.secondaryText)
            TextField(title, text: text)
                .font(.body)
                .foregroundStyle(RaverTheme.primaryText)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .padding(.horizontal, 12)
                .padding(.vertical, 11)
                .background(RaverTheme.background, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(RaverTheme.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(RaverTheme.cardBorder, lineWidth: 1)
        )
    }

    private func ticketTierCard(_ tier: EventUploadTicketTierDraft, order: Int) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(LT("票档 \(order)", "Tier \(order)", "券種 \(order)"))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(RaverTheme.secondaryText)
                Spacer()
                Button {
                    viewModel.removeTicketTier(id: tier.id)
                } label: {
                    Image(systemName: "trash")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.red)
                        .frame(width: 28, height: 28)
                        .background(RaverTheme.background, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 10) {
                TextField(LT("名称（可选）", "Name (optional)", "名称（任意）"), text: ticketTierNameBinding(tier.id))
                    .font(.body)
                    .foregroundStyle(RaverTheme.primaryText)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 11)
                    .background(RaverTheme.background, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                TextField(LT("价格", "Price", "価格"), text: ticketTierPriceBinding(tier.id))
                    .keyboardType(.decimalPad)
                    .font(.body)
                    .foregroundStyle(RaverTheme.primaryText)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 11)
                    .frame(maxWidth: 120)
                    .background(RaverTheme.background, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
        .padding(14)
        .background(RaverTheme.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(RaverTheme.cardBorder, lineWidth: 1)
        )
    }

    private var reviewTicketRows: [String] {
        var rows: [String] = []
        let url = viewModel.draft.ticket.ticketURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if !url.isEmpty {
            rows.append(url)
        }
        let notes = viewModel.draft.ticketNotes.trimmingCharacters(in: .whitespacesAndNewlines)
        if !notes.isEmpty {
            rows.append(notes)
        }
        rows.append(contentsOf: viewModel.draft.ticket.tiers.enumerated().compactMap { index, tier in
            let price = tier.price.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !price.isEmpty else { return nil }
            let name = tier.name.trimmingCharacters(in: .whitespacesAndNewlines)
            let label = name.isEmpty ? LT("票档 \(index + 1)", "Tier \(index + 1)", "券種 \(index + 1)") : name
            return "\(label): \(price) \(viewModel.draft.ticket.currency)"
        })
        return rows
    }

    private func timetableSlotEditor(_ slot: EventUploadLineupSlotDraft) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(EventLineupActCodec.composeName(type: slot.actType, performerNames: slot.performerNames).isEmpty ? LT("未命名演出", "Untitled Act", "未命名の出演") : EventLineupActCodec.composeName(type: slot.actType, performerNames: slot.performerNames))
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(RaverTheme.primaryText)
                    .lineLimit(1)
                Spacer()
                Button {
                    viewModel.removeTimetableSlot(id: slot.id)
                } label: {
                    Image(systemName: "trash")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.red)
                        .frame(width: 34, height: 34)
                }
                .buttonStyle(.plain)
            }

            Picker(LT("演出形式", "Act Type", "出演形式"), selection: timetableActTypeBinding(slot.id)) {
                ForEach(EventLineupActType.allCases) { type in
                    Text(type.title).tag(type)
                }
            }
            .pickerStyle(.segmented)

            ForEach(0..<slot.actType.performerCount, id: \.self) { index in
                djSearchTextField(
                    title: slot.actType == .solo ? LT("DJ 名称", "DJ Name", "DJ名") : LT("DJ \(index + 1)", "DJ \(index + 1)", "DJ \(index + 1)"),
                    text: timetablePerformerBinding(slot.id, performerIndex: index),
                    isRequired: true,
                    isSearching: viewModel.searchingDJKeys.contains(viewModel.djSearchKey(slotID: slot.id, performerIndex: index)),
                    canClear: (slot.performerNames.indices.contains(index) ? !slot.performerNames[index].trimmingCharacters(in: .whitespacesAndNewlines).isEmpty : false) || (slot.performerDJIDs.indices.contains(index) ? slot.performerDJIDs[index]?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false : false),
                    clearAction: {
                        viewModel.clearTimetableDJBinding(slotID: slot.id, performerIndex: index)
                        viewModel.updateTimetableSlot(id: slot.id) { draftSlot in
                            while draftSlot.performerNames.count <= index {
                                draftSlot.performerNames.append("")
                            }
                            draftSlot.performerNames[index] = ""
                        }
                    }
                ) {
                    Task { await viewModel.searchTimetableDJ(slotID: slot.id, performerIndex: index) }
                }
                timetableDJSearchSection(slot, performerIndex: index)
            }

            if !viewModel.draft.stageEntries.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    fieldTitle(LT("舞台", "Stage", "ステージ"), isRequired: true)
                    Picker(LT("舞台", "Stage", "ステージ"), selection: timetableStageBinding(slot.id)) {
                        Text(LT("选择舞台", "Choose Stage", "ステージを選択")).tag("")
                        ForEach(viewModel.draft.stageEntries, id: \.self) { stage in
                            Text(stage).tag(stage)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(RaverTheme.accent)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(fieldBackground)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                fieldTitle(LT("演出日", "Event Day", "出演日"), isRequired: false)
                Picker(LT("演出日", "Event Day", "出演日"), selection: timetableDayBinding(slot.id)) {
                    ForEach(lineupDayOptions) { option in
                        Text(option.title).tag(option.dayIndex)
                    }
                }
                .pickerStyle(.menu)
                .tint(RaverTheme.accent)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(fieldBackground)
            }

            HStack(spacing: 12) {
                DatePicker(
                    LT("开始", "Start", "開始"),
                    selection: timetableTimeBinding(slot.id, keyPath: \.startTime),
                    displayedComponents: [.hourAndMinute]
                )
                .datePickerStyle(.compact)
                .tint(RaverTheme.accent)
                .environment(\.timeZone, eventTimeZone)

                DatePicker(
                    LT("结束", "End", "終了"),
                    selection: timetableTimeBinding(slot.id, keyPath: \.endTime),
                    displayedComponents: [.hourAndMinute]
                )
                .datePickerStyle(.compact)
                .tint(RaverTheme.accent)
                .environment(\.timeZone, eventTimeZone)
            }
            Text(LT("这里填写的是时间表，演出时间必填。结束时间不晚于开始时间时，会按次日结束保存。", "Timetable entries require start and end time. If the end time is not later than the start time, it is saved as ending the next day.", "ここはタイムテーブル入力のため、開始・終了時刻は必須です。終了時刻が開始時刻以前の場合、翌日終了として保存します。"))
                .font(.caption)
                .foregroundStyle(RaverTheme.secondaryText)
        }
        .padding(14)
        .background(RaverTheme.card, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(RaverTheme.cardBorder, lineWidth: 1)
        )
    }

    private func timetableDJSearchSection(_ slot: EventUploadLineupSlotDraft, performerIndex: Int) -> some View {
        let key = viewModel.djSearchKey(slotID: slot.id, performerIndex: performerIndex)
        let isSearching = viewModel.searchingDJKeys.contains(key)
        let results = viewModel.djSearchResults[key] ?? []
        let feedback = viewModel.djSearchFeedbacks[key] ?? .idle

        return VStack(alignment: .leading, spacing: 8) {
            djSearchResultsList(results: results, feedback: feedback, isSearching: isSearching) { dj in
                viewModel.applyTimetableDJ(dj, slotID: slot.id, performerIndex: performerIndex)
            }
        }
    }

    private func reviewCard(title: String, rows: [String]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(RaverTheme.primaryText)
                Spacer()
                Text("\(rows.isEmpty ? 1 : rows.count)")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(RaverTheme.secondaryText)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(RaverTheme.background, in: Capsule())
            }
            ForEach(rows.isEmpty ? [LT("未填写", "Not set", "未入力")] : rows, id: \.self) { row in
                Text(row)
                    .font(.caption)
                    .foregroundStyle(RaverTheme.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(RaverTheme.background, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
        }
        .padding(16)
        .background(RaverTheme.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(RaverTheme.cardBorder, lineWidth: 1)
        )
    }

    private func lineupOnlyDJSearchSection(_ slot: EventUploadLineupOnlySlotDraft, performerIndex: Int) -> some View {
        let key = viewModel.djSearchKey(slotID: slot.id, performerIndex: performerIndex)
        let isSearching = viewModel.searchingDJKeys.contains(key)
        let results = viewModel.djSearchResults[key] ?? []
        let feedback = viewModel.djSearchFeedbacks[key] ?? .idle

        return VStack(alignment: .leading, spacing: 8) {
            djSearchResultsList(results: results, feedback: feedback, isSearching: isSearching) { dj in
                viewModel.applyLineupOnlyDJ(dj, slotID: slot.id, performerIndex: performerIndex)
            }
        }
    }

    @ViewBuilder
    private func djSearchResultsList(
        results: [WebDJ],
        feedback: EventUploadFlowViewModel.InlineSearchFeedback,
        isSearching: Bool,
        onSelect: @escaping (WebDJ) -> Void
    ) -> some View {
        if !results.isEmpty {
            VStack(spacing: 6) {
                ForEach(results.prefix(8)) { dj in
                    Button {
                        onSelect(dj)
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "music.mic.circle.fill")
                                .font(.title3)
                                .foregroundStyle(RaverTheme.accent)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(dj.name)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(RaverTheme.primaryText)
                                Text(dj.country ?? dj.slug ?? dj.id)
                                    .font(.caption2)
                                    .foregroundStyle(RaverTheme.secondaryText)
                                    .lineLimit(1)
                            }
                            Spacer()
                            Image(systemName: "plus.circle")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(RaverTheme.secondaryText)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(RaverTheme.background, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
        } else if isSearching {
            inlineSearchFeedbackRow(
                message: LT("正在搜索 DJ 库…", "Searching DJ library...", "DJライブラリを検索中..."),
                systemImage: "clock.arrow.circlepath",
                tint: RaverTheme.secondaryText
            )
        } else if let message = feedback.message {
            inlineSearchFeedbackRow(
                message: message,
                systemImage: feedback.isFailure ? "exclamationmark.triangle.fill" : "info.circle.fill",
                tint: feedback.isFailure ? .orange : RaverTheme.secondaryText
            )
        }
    }

    private func sectionTitle(_ title: String, subtitle: String) -> some View {
        Text(title)
            .font(.title3.weight(.bold))
            .foregroundStyle(RaverTheme.primaryText)
    }

    private func aiActionButton(title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: "sparkles")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background(
                    LinearGradient(
                        colors: [.pink, .orange, .blue, .cyan],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.white.opacity(0.45), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    private func inlineInfoCard(_ message: String) -> some View {
        Text(message)
            .font(.caption)
            .foregroundStyle(RaverTheme.secondaryText)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(RaverTheme.card, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(RaverTheme.cardBorder, lineWidth: 1)
            )
    }

    private func inlineDismissibleNoticeCard(
        title: String,
        message: String,
        systemImage: String,
        tint: Color,
        onDismiss: @escaping () -> Void
    ) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: systemImage)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(tint)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(RaverTheme.primaryText)
                Text(message)
                    .font(.caption)
                    .foregroundStyle(RaverTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(RaverTheme.secondaryText)
                    .frame(width: 24, height: 24)
                    .background(RaverTheme.background, in: Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(RaverTheme.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(tint.opacity(0.35), lineWidth: 1)
        )
    }

    private func inlineActionNoticeCard(
        title: String,
        message: String,
        systemImage: String,
        tint: Color,
        primaryTitle: String,
        primaryAction: @escaping () -> Void,
        secondaryTitle: String,
        secondaryRole: ButtonRole?,
        secondaryAction: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: systemImage)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(tint)
                    .frame(width: 20)
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(RaverTheme.primaryText)
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(RaverTheme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }

            HStack(spacing: 8) {
                Button(action: primaryAction) {
                    Text(primaryTitle)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(tint, in: Capsule())
                }
                .buttonStyle(.plain)

                Button(role: secondaryRole, action: secondaryAction) {
                    Text(secondaryTitle)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(secondaryRole == .destructive ? .red : RaverTheme.primaryText)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(RaverTheme.background, in: Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .background(RaverTheme.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(tint.opacity(0.35), lineWidth: 1)
        )
    }

    private func successView(_ success: EventUploadSubmitSuccess) -> some View {
        VStack(spacing: 22) {
            Spacer(minLength: 40)

            ZStack {
                Circle()
                    .fill(RaverTheme.accent.opacity(0.14))
                    .frame(width: 92, height: 92)
                Image(systemName: "checkmark")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 58, height: 58)
                    .background(RaverTheme.accent, in: Circle())
            }

            VStack(spacing: 10) {
                Text(success.title)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(RaverTheme.primaryText)
                    .multilineTextAlignment(.center)
                Text(success.message)
                    .font(.subheadline)
                    .foregroundStyle(RaverTheme.secondaryText)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 24)

            EntityChangeResultPreviewCard(
                change: success.change,
                showsReviewPendingNotice: success.showsReviewPendingDiffNotice
            ) { changeLogID in
                appPush(.entityChangeDetail(changeLogID: changeLogID))
            }

            VStack(spacing: 10) {
                Button {
                    viewModel.closeAfterSuccess()
                } label: {
                    HStack {
                        Text(LT("返回活动页", "Back to Events", "イベントページへ戻る"))
                            .font(.headline.weight(.semibold))
                        Spacer()
                        Image(systemName: "arrow.right")
                            .font(.subheadline.weight(.bold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(
                        LinearGradient(
                            colors: [RaverTheme.accent, RaverTheme.accent.opacity(0.78)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                    )
                }
                .buttonStyle(.plain)

                Text(LT("之后也可以在我的发布里查看和管理。", "You can review and manage this later from My Posts.", "後からマイ投稿で確認・管理できます。"))
                    .font(.caption)
                    .foregroundStyle(RaverTheme.secondaryText)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 20)

            Spacer(minLength: 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 24)
    }

    private var timeZoneSearchSection: some View {
        let isLocked = viewModel.draft.selectedTimeZoneLookup != nil
        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                fieldTitle(LT("城市时区", "City Time Zone", "都市タイムゾーン"), isRequired: true)
                Text(
                    LT(
                        "用城市英文搜索，例如 Hong Kong",
                        "Search with the English city name, e.g. Hong Kong",
                        "都市名は英語で検索。例: Hong Kong"
                    )
                )
                .font(.caption2)
                .foregroundStyle(RaverTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
            }
            lockedSearchField(
                title: LT("输入城市或城市+州/国家", "Enter city or city + state/country", "都市または都市+州/国を入力"),
                text: timeZoneSearchBinding,
                isLocked: isLocked,
                lockedLabel: LT("已绑定", "Bound", "紐付け済み"),
                actionTitle: viewModel.isSearchingTimeZones ? LT("搜索中", "Searching", "検索中") : LT("搜索", "Search", "検索"),
                actionSystemImage: "magnifyingglass",
                isActionBusy: viewModel.isSearchingTimeZones,
                clearTitle: LT("清空", "Clear", "クリア"),
                canClear: viewModel.draft.selectedTimeZoneLookup != nil || !viewModel.draft.timeZoneSearchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                clearAction: viewModel.clearTimeZoneSelection
            ) {
                Task { await viewModel.searchEventTimeZones(showEmptyMessage: true) }
            }

            Text(timeZoneSummary)
                .font(.caption)
                .foregroundStyle(isLocked ? .green : RaverTheme.secondaryText)

            if viewModel.isSearchingTimeZones && !isLocked {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text(LT("正在匹配城市时区…", "Matching timezones...", "都市タイムゾーンを検索中..."))
                        .font(.caption2)
                        .foregroundStyle(RaverTheme.secondaryText)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(RaverTheme.card, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }

            if let item = viewModel.draft.selectedTimeZoneLookup {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(.green)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.label)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(RaverTheme.primaryText)
                        Text(item.timezone)
                            .font(.caption2)
                            .foregroundStyle(RaverTheme.secondaryText)
                    }
                    Spacer()
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(RaverTheme.card, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }

            if !viewModel.timeZoneSearchResults.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(viewModel.timeZoneSearchResults.prefix(8)) { item in
                        Button {
                            viewModel.applyTimeZoneSelection(item)
                        } label: {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(item.label)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(RaverTheme.primaryText)
                                Text(item.timezone)
                                    .font(.caption2)
                                    .foregroundStyle(RaverTheme.secondaryText)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .background(RaverTheme.card, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
            } else if !isLocked, let message = viewModel.timeZoneSearchFeedback.message, !viewModel.isSearchingTimeZones {
                inlineSearchFeedbackRow(
                    message: message,
                    systemImage: viewModel.timeZoneSearchFeedback.isFailure ? "exclamationmark.triangle.fill" : "mappin.and.ellipse",
                    tint: viewModel.timeZoneSearchFeedback.isFailure ? .orange : RaverTheme.secondaryText
                )
            }
        }
    }

    private var timeZonePreviewSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            fieldTitle(LT("时区预览", "Time Zone Preview", "タイムゾーンプレビュー"), isRequired: false)
            VStack(alignment: .leading, spacing: 6) {
                Text(LT("活动城市", "Event City", "イベント都市"))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(RaverTheme.secondaryText)
                Text(formattedDateRange(timeZone: TimeZone(identifier: viewModel.draft.timeZoneIdentifier) ?? .current))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(RaverTheme.primaryText)
                    .fixedSize(horizontal: false, vertical: true)

                Text(LT("当前设备", "Current Device", "現在の端末"))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(RaverTheme.secondaryText)
                    .padding(.top, 2)
                Text(formattedDateRange(timeZone: .current))
                    .font(.caption)
                    .foregroundStyle(RaverTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(fieldBackground)
        }
    }

    private func formattedDateRange(timeZone: TimeZone) -> String {
        viewModel.draft.discreteDateSummaryText(in: timeZone)
    }

    private func uploadTextField(
        title: String,
        text: Binding<String>,
        isRequired: Bool = false,
        axis: Axis = .horizontal,
        showTitle: Bool = true
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if showTitle {
                fieldTitle(title, isRequired: isRequired)
            }
            TextField(title, text: text, axis: axis)
                .font(.body)
                .foregroundStyle(RaverTheme.primaryText)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .lineLimit(axis == .vertical ? 5 : 1)
                .padding(.horizontal, 12)
                .padding(.vertical, 11)
                .background(fieldBackground)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func fieldTitle(_ title: String, isRequired: Bool) -> some View {
        HStack(spacing: 4) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(RaverTheme.secondaryText)
            if isRequired {
                Text("*")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.red)
            }
        }
    }

    private func readonlyAddressPreviewCard(
        title: String,
        value: String?,
        emptyText: String,
        hint: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(RaverTheme.secondaryText)
            VStack(alignment: .leading, spacing: 6) {
                if let value, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(value)
                        .font(.caption)
                        .foregroundStyle(RaverTheme.primaryText)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    Text(emptyText)
                        .font(.caption)
                        .foregroundStyle(RaverTheme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Text(hint)
                    .font(.caption2)
                    .foregroundStyle(RaverTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(RaverTheme.background.opacity(0.72), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(RaverTheme.cardBorder, lineWidth: 1)
            )
        }
    }

    private var fieldBackground: some ShapeStyle {
        RaverTheme.card
    }

    private func localizedBinding(_ keyPath: WritableKeyPath<EventUploadDraft, EventUploadLocalizedFields>) -> Binding<String> {
        Binding {
            viewModel.draft[keyPath: keyPath].currentValue(preferredLanguage: viewModel.draft.preferredLanguage)
        } set: { value in
            viewModel.updateLocalizedField(keyPath, value: value)
        }
    }

    private func localizedBinding(
        _ keyPath: WritableKeyPath<EventUploadDraft, EventUploadLocalizedFields>,
        language: EventUploadPreferredLanguage
    ) -> Binding<String> {
        Binding {
            viewModel.draft[keyPath: keyPath].value(for: language)
        } set: { value in
            viewModel.updateLocalizedField(keyPath, language: language, value: value)
        }
    }

    private func localizedEnglishFullBinding(
        _ keyPath: WritableKeyPath<EventUploadDraft, EventUploadLocalizedFields>
    ) -> Binding<String> {
        Binding {
            viewModel.draft[keyPath: keyPath].enFull
        } set: { value in
            viewModel.updateLocalizedEnglishFullField(keyPath, value: value)
        }
    }

    private func localizedPrimaryFieldPlaceholder(for title: String) -> String {
        switch viewModel.draft.preferredLanguage {
        case .zh:
            return "\(title) · 中文"
        case .en:
            return "\(title) · English"
        case .ja:
            return "\(title) · 日本語"
        }
    }

    private func localizedExpansionBinding(for key: String) -> Binding<Bool> {
        Binding {
            expandedLocalizedFieldKeys.contains(key)
        } set: { isExpanded in
            if isExpanded {
                expandedLocalizedFieldKeys.insert(key)
            } else {
                expandedLocalizedFieldKeys.remove(key)
            }
        }
    }

    private var abbreviationBinding: Binding<String> {
        Binding {
            viewModel.draft.abbreviation
        } set: { value in
            viewModel.updateAbbreviation(value)
        }
    }

    private var descriptionBinding: Binding<String> {
        Binding {
            viewModel.draft.description
        } set: { value in
            viewModel.updateDescription(value)
        }
    }

    private var eventTypeBinding: Binding<String> {
        Binding {
            viewModel.draft.eventType
        } set: { value in
            viewModel.updateEventType(value)
        }
    }

    private var organizerBinding: Binding<String> {
        Binding {
            viewModel.draft.organizerName
        } set: { value in
            viewModel.updateOrganizerName(value)
        }
    }

    private var organizerSearchSection: some View {
        let isLocked = viewModel.draft.organizerFestivalID != nil
        return VStack(alignment: .leading, spacing: 10) {
            fieldTitle(LT("主办方", "Organizer", "主催者"), isRequired: false)
            lockedSearchField(
                title: LT("输入主办方名称", "Enter organizer name", "主催者名を入力"),
                text: organizerBinding,
                isLocked: isLocked,
                lockedLabel: LT("已绑定", "Bound", "紐付け済み"),
                actionTitle: viewModel.isSearchingOrganizers ? LT("搜索中", "Searching", "検索中") : LT("绑定", "Bind", "紐付け"),
                actionSystemImage: "magnifyingglass",
                isActionBusy: viewModel.isSearchingOrganizers,
                clearTitle: LT("清空", "Clear", "クリア"),
                canClear: viewModel.draft.organizerFestivalID != nil || !viewModel.draft.organizerName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                clearAction: viewModel.clearOrganizerBinding
            ) {
                Task { await viewModel.searchOrganizers(showEmptyMessage: true) }
            }

            if viewModel.isSearchingOrganizers && !isLocked {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text(LT("正在匹配主办方…", "Matching organizers...", "主催者を検索中..."))
                        .font(.caption2)
                        .foregroundStyle(RaverTheme.secondaryText)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(RaverTheme.card, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }

            if viewModel.draft.organizerFestivalID != nil {
                Text(LT("已绑定主办方词条，提交时会同步携带主办方 ID。", "Organizer entry is bound and its ID will be submitted.", "主催者エントリが紐付け済みで、送信時にIDも保存されます。"))
                    .font(.caption)
                    .foregroundStyle(.green)

                HStack(spacing: 8) {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(.green)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(viewModel.draft.organizerName)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(RaverTheme.primaryText)
                        Text(viewModel.draft.organizerFestivalID ?? "")
                            .font(.caption2)
                            .foregroundStyle(RaverTheme.secondaryText)
                    }
                    Spacer()
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(RaverTheme.card, in: RoundedRectangle(cornerRadius: 10, style: .continuous))

                Button {
                    Task { await viewModel.applyBoundOrganizerAddress() }
                } label: {
                    HStack(spacing: 8) {
                        if viewModel.isApplyingOrganizerAddress {
                            ProgressView()
                                .controlSize(.small)
                                .tint(.white)
                        } else {
                            Image(systemName: "arrow.down.circle.fill")
                                .font(.caption.weight(.bold))
                        }
                        Text(LT("使用主办方地址", "Use Organizer Address", "主催者住所を使う"))
                            .font(.caption.weight(.semibold))
                        Spacer(minLength: 0)
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(
                        LinearGradient(
                            colors: [RaverTheme.accent, RaverTheme.accent.opacity(0.78)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                    )
                }
                .buttonStyle(.plain)
                .disabled(viewModel.isApplyingOrganizerAddress)
            }

            if !viewModel.organizerSearchResults.isEmpty {
                VStack(spacing: 6) {
                    ForEach(viewModel.organizerSearchResults.prefix(8)) { festival in
                        Button {
                            viewModel.applyOrganizer(festival)
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "building.2.crop.circle")
                                    .font(.title3)
                                    .foregroundStyle(RaverTheme.accent)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(festival.nameI18n?.text(for: AppLanguagePreference.current.effectiveLanguage) ?? festival.name)
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(RaverTheme.primaryText)
                                    Text([festival.city, festival.country].compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ? $0 : nil }.joined(separator: " · "))
                                        .font(.caption2)
                                        .foregroundStyle(RaverTheme.secondaryText)
                                        .lineLimit(1)
                                }
                                Spacer()
                                Image(systemName: "plus.circle")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(RaverTheme.secondaryText)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .background(RaverTheme.background, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
            } else if !isLocked, let message = viewModel.organizerSearchFeedback.message, !viewModel.isSearchingOrganizers {
                VStack(alignment: .leading, spacing: 8) {
                    inlineSearchFeedbackRow(
                        message: message,
                        systemImage: viewModel.organizerSearchFeedback.isFailure ? "exclamationmark.triangle.fill" : "building.2.crop.circle",
                        tint: viewModel.organizerSearchFeedback.isFailure ? .orange : RaverTheme.secondaryText
                    )

                    if case .empty = viewModel.organizerSearchFeedback {
                        Button {
                            let seededName = viewModel.draft.organizerName.trimmingCharacters(in: .whitespacesAndNewlines)
                            let contextID = UUID().uuidString
                            organizerCreateContextID = contextID
                            viewModel.saveDraft(immediate: true)
                            discoverPush(.organizerCreate(initialName: seededName.nilIfBlank, sourceContextID: contextID))
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.caption.weight(.bold))
                                Text(LT("直接创建这个主办方", "Create this organizer", "この主催者を作成"))
                                    .font(.caption.weight(.semibold))
                                Spacer(minLength: 0)
                                Image(systemName: "arrow.right")
                                    .font(.caption.weight(.bold))
                            }
                            .foregroundStyle(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(
                                LinearGradient(
                                    colors: [RaverTheme.accent, RaverTheme.accent.opacity(0.78)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func inlineSearchFeedbackRow(message: String, systemImage: String, tint: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.caption.weight(.semibold))
                .foregroundStyle(tint)
            Text(message)
                .font(.caption2)
                .foregroundStyle(RaverTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(RaverTheme.card, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var sourceURLBinding: Binding<String> {
        Binding {
            viewModel.draft.sourceURL
        } set: { value in
            viewModel.updateSourceURL(value)
        }
    }

    private var officialWebsiteBinding: Binding<String> {
        Binding {
            viewModel.draft.officialWebsite
        } set: { value in
            viewModel.updateOfficialWebsite(value)
        }
    }

    private var sourceProviderBinding: Binding<String> {
        Binding {
            viewModel.draft.sourceProvider
        } set: { value in
            viewModel.updateSourceProvider(value)
        }
    }

    private var referenceLinksTextBinding: Binding<String> {
        Binding {
            viewModel.draft.referenceLinksText
        } set: { value in
            viewModel.updateReferenceLinksText(value)
        }
    }

    private var socialLinksTextBinding: Binding<String> {
        Binding {
            viewModel.draft.socialLinksText
        } set: { value in
            viewModel.updateSocialLinksText(value)
        }
    }

    private var ticketNotesBinding: Binding<String> {
        Binding {
            viewModel.draft.ticketNotes
        } set: { value in
            viewModel.updateTicketNotes(value)
        }
    }

    private func dateBinding(_ keyPath: WritableKeyPath<EventUploadDraft, Date>) -> Binding<Date> {
        Binding {
            viewModel.draft[keyPath: keyPath]
        } set: { value in
            viewModel.updateDate(keyPath, value: value)
        }
    }

    private var timeZoneSearchBinding: Binding<String> {
        Binding {
            viewModel.draft.timeZoneSearchQuery
        } set: { value in
            viewModel.updateTimeZoneSearchQuery(value)
        }
    }

    private var timeZoneSummary: String {
        if let item = viewModel.draft.selectedTimeZoneLookup {
            return LT("已确认：\(item.label)", "Confirmed: \(item.label)", "確認済み：\(item.label)")
        }
        if !viewModel.draft.timeZoneIdentifier.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           case .edit = viewModel.draft.mode {
            return LT("当前活动时区：\(viewModel.draft.timeZoneIdentifier)。如需修改，请搜索城市并确认。", "Current event timezone: \(viewModel.draft.timeZoneIdentifier). Search a city to change it.", "現在のタイムゾーン：\(viewModel.draft.timeZoneIdentifier)。変更するには都市を検索してください。")
        }
        return LT("未确认活动城市时区", "No city timezone confirmed", "都市タイムゾーン未確認")
    }

    private func lockedSearchField(
        title: String,
        text: Binding<String>,
        isLocked: Bool,
        lockedLabel: String,
        actionTitle: String,
        actionSystemImage: String,
        isActionBusy: Bool,
        clearTitle: String,
        canClear: Bool,
        clearAction: @escaping () -> Void,
        action: @escaping () -> Void
    ) -> some View {
        ZStack(alignment: .trailing) {
            TextField(title, text: text)
                .font(.body)
                .foregroundStyle(isLocked ? RaverTheme.secondaryText : RaverTheme.primaryText)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .disabled(isLocked)
                .padding(.trailing, canClear ? 166 : 92)

            HStack(spacing: 6) {
                if canClear {
                    Button(action: clearAction) {
                        Label(clearTitle, systemImage: "xmark.circle")
                            .font(.caption.weight(.bold))
                            .labelStyle(.titleAndIcon)
                            .lineLimit(1)
                            .foregroundStyle(RaverTheme.primaryText)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 7)
                            .background(RaverTheme.background, in: Capsule())
                            .overlay(
                                Capsule()
                                    .stroke(RaverTheme.cardBorder, lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                } else if isLocked {
                    HStack(spacing: 5) {
                        Image(systemName: "lock.fill")
                            .font(.caption2.weight(.bold))
                        Text(lockedLabel)
                            .font(.caption2.weight(.bold))
                    }
                    .foregroundStyle(.green)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(Color.green.opacity(0.12), in: Capsule())
                }

                Button(action: action) {
                    Label(actionTitle, systemImage: actionSystemImage)
                        .font(.caption.weight(.bold))
                        .labelStyle(.titleAndIcon)
                        .lineLimit(1)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(RaverTheme.accent, in: Capsule())
                }
                .buttonStyle(.plain)
                .disabled(isActionBusy || isLocked)
                .opacity((isActionBusy || isLocked) ? 0.56 : 1)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 11)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(isLocked ? RaverTheme.card.opacity(0.72) : RaverTheme.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(isLocked ? Color.green.opacity(0.35) : RaverTheme.cardBorder, lineWidth: 1)
        )
    }

    private func djSearchTextField(
        title: String,
        text: Binding<String>,
        isRequired: Bool,
        isSearching: Bool,
        canClear: Bool,
        clearAction: @escaping () -> Void,
        action: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            fieldTitle(title, isRequired: isRequired)
            ZStack(alignment: .trailing) {
                TextField(title, text: text)
                    .font(.body)
                    .foregroundStyle(RaverTheme.primaryText)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .padding(.trailing, canClear ? 168 : 104)

                HStack(spacing: 6) {
                    if canClear {
                        Button(action: clearAction) {
                            Label(LT("清空", "Clear", "クリア"), systemImage: "xmark.circle")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(RaverTheme.primaryText)
                                .padding(.horizontal, 9)
                                .padding(.vertical, 7)
                                .background(RaverTheme.background, in: Capsule())
                                .overlay(
                                    Capsule()
                                        .stroke(RaverTheme.cardBorder, lineWidth: 1)
                                )
                        }
                        .buttonStyle(.plain)
                    }

                    Button(action: action) {
                        Label(isSearching ? LT("搜索中", "Searching", "検索中") : LT("绑定", "Bind", "紐付け"), systemImage: "magnifyingglass")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .background(RaverTheme.accent, in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .disabled(isSearching)
                    .opacity(isSearching ? 0.72 : 1)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 11)
            .background(fieldBackground)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func shortDateString(_ date: Date, in timeZone: TimeZone = .current) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        formatter.dateFormat = "yyyy/M/d"
        return formatter.string(from: date)
    }

    private enum WeekDateField {
        case start
        case end
    }

    private func weekDateBinding(id: UUID, field: WeekDateField) -> Binding<Date> {
        Binding {
            guard let week = viewModel.draft.editableWeekRanges.first(where: { $0.id == id }) else {
                return viewModel.draft.startDate
            }
            return field == .start ? week.startDate : week.endDate
        } set: { value in
            if field == .start {
                viewModel.updateWeekRange(id: id, startDate: value)
            } else {
                viewModel.updateWeekRange(id: id, endDate: value)
            }
        }
    }

    private func compactWeekDatePicker(title: String, selection: Binding<Date>) -> some View {
        VStack(alignment: .center, spacing: 6) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(RaverTheme.secondaryText)
            formattedCompactDatePicker(title: title, selection: selection)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.horizontal, 8)
        .padding(.vertical, 10)
        .background(RaverTheme.background, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(RaverTheme.cardBorder, lineWidth: 1)
        )
    }

    private func formattedCompactDatePicker(title: String, selection: Binding<Date>) -> some View {
        Button {
            activeDatePicker = DatePickerPresentation(title: title, selection: selection)
        } label: {
            HStack(spacing: 6) {
                Text(shortDateString(selection.wrappedValue, in: eventTimeZone))
                    .font(.body.weight(.medium))
                    .foregroundStyle(RaverTheme.primaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                Image(systemName: "calendar")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(RaverTheme.accent)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var singleDayDateBinding: Binding<Date> {
        Binding {
            viewModel.draft.startDate
        } set: { value in
            viewModel.updateDate(\.startDate, value: value)
            viewModel.updateDate(\.endDate, value: value)
        }
    }

    private var dayRolloverBinding: Binding<Int> {
        Binding {
            viewModel.draft.dayRolloverHour
        } set: { value in
            viewModel.updateDayRolloverHour(value)
        }
    }

    private func coordinateBinding(_ keyPath: WritableKeyPath<EventUploadDraft, Double?>) -> Binding<String> {
        Binding {
            viewModel.draft[keyPath: keyPath].map { String($0) } ?? ""
        } set: { value in
            viewModel.updateCoordinate(keyPath, rawValue: value)
        }
    }

    private func ticketBinding(_ keyPath: WritableKeyPath<EventUploadTicketDraft, String>) -> Binding<String> {
        Binding {
            viewModel.draft.ticket[keyPath: keyPath]
        } set: { value in
            viewModel.updateTicketField(keyPath, value: value)
        }
    }

    private func ticketTierNameBinding(_ tierID: UUID) -> Binding<String> {
        Binding {
            viewModel.draft.ticket.tiers.first(where: { $0.id == tierID })?.name ?? ""
        } set: { value in
            viewModel.updateTicketTier(id: tierID) { tier in
                tier.name = value
            }
        }
    }

    private func ticketTierPriceBinding(_ tierID: UUID) -> Binding<String> {
        Binding {
            viewModel.draft.ticket.tiers.first(where: { $0.id == tierID })?.price ?? ""
        } set: { value in
            viewModel.updateTicketTier(id: tierID) { tier in
                tier.price = value
            }
        }
    }

    private func stageBinding(_ index: Int) -> Binding<String> {
        Binding {
            guard viewModel.draft.stageEntries.indices.contains(index) else { return "" }
            return viewModel.draft.stageEntries[index]
        } set: { value in
            viewModel.updateStage(at: index, value: value)
        }
    }

    private func lineupActTypeBinding(_ slotID: UUID) -> Binding<EventLineupActType> {
        Binding {
            viewModel.draft.lineupOnlySlots.first(where: { $0.id == slotID })?.actType ?? .solo
        } set: { value in
            viewModel.updateLineupOnlySlot(id: slotID) { slot in
                slot.actType = value
            }
        }
    }

    private func lineupOnlyPerformerBinding(_ slotID: UUID, performerIndex: Int) -> Binding<String> {
        Binding {
            guard let slot = viewModel.draft.lineupOnlySlots.first(where: { $0.id == slotID }),
                  slot.performerNames.indices.contains(performerIndex) else { return "" }
            return slot.performerNames[performerIndex]
        } set: { value in
            viewModel.updateLineupOnlySlot(id: slotID) { slot in
                while slot.performerNames.count <= performerIndex {
                    slot.performerNames.append("")
                }
                slot.performerNames[performerIndex] = value
            }
            viewModel.scheduleLineupOnlyDJSearch(slotID: slotID, performerIndex: performerIndex)
        }
    }

    private func timetableActTypeBinding(_ slotID: UUID) -> Binding<EventLineupActType> {
        Binding {
            viewModel.draft.timetableSlots.first(where: { $0.id == slotID })?.actType ?? .solo
        } set: { value in
            viewModel.updateTimetableSlot(id: slotID) { slot in
                slot.actType = value
            }
        }
    }

    private func timetablePerformerBinding(_ slotID: UUID, performerIndex: Int) -> Binding<String> {
        Binding {
            guard let slot = viewModel.draft.timetableSlots.first(where: { $0.id == slotID }),
                  slot.performerNames.indices.contains(performerIndex) else { return "" }
            return slot.performerNames[performerIndex]
        } set: { value in
            viewModel.updateTimetableSlot(id: slotID) { slot in
                while slot.performerNames.count <= performerIndex {
                    slot.performerNames.append("")
                }
                slot.performerNames[performerIndex] = value
            }
            viewModel.scheduleTimetableDJSearch(slotID: slotID, performerIndex: performerIndex)
        }
    }

    private func timetableStageBinding(_ slotID: UUID) -> Binding<String> {
        Binding {
            viewModel.draft.timetableSlots.first(where: { $0.id == slotID })?.stageName ?? ""
        } set: { value in
            viewModel.updateTimetableSlot(id: slotID) { slot in
                slot.stageName = value
            }
        }
    }

    private func timetableDayBinding(_ slotID: UUID) -> Binding<Int> {
        Binding {
            viewModel.draft.timetableSlots.first(where: { $0.id == slotID })?.dayIndex ?? 1
        } set: { value in
            viewModel.updateTimetableSlot(id: slotID) { slot in
                slot.dayIndex = value
                slot.startTime = alignLineupDate(slot.startTime, toDayIndex: value, dayOffset: slot.startDayOffset)
                slot.endTime = alignLineupDate(slot.endTime, toDayIndex: value, dayOffset: slot.endDayOffset)
            }
        }
    }

    private func timetableTimeBinding(_ slotID: UUID, keyPath: WritableKeyPath<EventUploadLineupSlotDraft, Date?>) -> Binding<Date> {
        Binding {
            viewModel.draft.timetableSlots.first(where: { $0.id == slotID })?[keyPath: keyPath]
                ?? alignLineupClock(Date(), toDayIndex: viewModel.draft.timetableSlots.first(where: { $0.id == slotID })?.dayIndex ?? 1)
        } set: { value in
            viewModel.updateTimetableSlot(id: slotID) { slot in
                let dayOffset = keyPath == \EventUploadLineupSlotDraft.startTime ? slot.startDayOffset : slot.endDayOffset
                slot[keyPath: keyPath] = alignLineupClock(value, toDayIndex: slot.dayIndex, dayOffset: dayOffset)
            }
        }
    }

    private func timetableDayOffsetBinding(_ slotID: UUID, keyPath: WritableKeyPath<EventUploadLineupSlotDraft, EventUploadSlotDayOffset>) -> Binding<EventUploadSlotDayOffset> {
        Binding {
            viewModel.draft.timetableSlots.first(where: { $0.id == slotID })?[keyPath: keyPath] ?? .sameDay
        } set: { value in
            viewModel.updateTimetableSlot(id: slotID) { slot in
                slot[keyPath: keyPath] = value
                if keyPath == \EventUploadLineupSlotDraft.startDayOffset {
                    slot.startTime = alignLineupDate(slot.startTime, toDayIndex: slot.dayIndex, dayOffset: value)
                } else {
                    slot.endTime = alignLineupDate(slot.endTime, toDayIndex: slot.dayIndex, dayOffset: value)
                }
            }
        }
    }

    private var lineupDayOptions: [EventUploadDayOption] {
        let structuredDays = viewModel.draft.structuredEventDays
        if !structuredDays.isEmpty {
            return structuredDays.map { day in
                EventUploadDayOption(
                    dayIndex: day.overallDayIndex,
                    title: eventDayOptionTitle(day),
                    date: day.date
                )
            }
        }
        return [
            EventUploadDayOption(
                dayIndex: 1,
                title: LT("Selected date", "Selected date", "選択日"),
                date: viewModel.draft.startDate
            )
        ]
    }

    private func alignLineupClock(_ value: Date, toDayIndex dayIndex: Int, dayOffset: EventUploadSlotDayOffset = .sameDay) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: viewModel.draft.timeZoneIdentifier) ?? .current
        let components = calendar.dateComponents([.hour, .minute], from: value)
        let logicalDate = lineupDayOptions.first(where: { $0.dayIndex == dayIndex })?.date ?? viewModel.draft.startDate
        let logicalStart = calendar.startOfDay(for: logicalDate)
        let baseDay = calendar.date(byAdding: .day, value: dayOffset.rawValue, to: logicalStart) ?? logicalStart
        return calendar.date(bySettingHour: components.hour ?? 0, minute: components.minute ?? 0, second: 0, of: baseDay) ?? value
    }

    private func alignLineupDate(_ value: Date?, toDayIndex dayIndex: Int, dayOffset: EventUploadSlotDayOffset = .sameDay) -> Date? {
        guard let value else { return nil }
        return alignLineupClock(value, toDayIndex: dayIndex, dayOffset: dayOffset)
    }

    private var displayWeekRanges: [EventUploadWeekRangeDraft] {
        if viewModel.draft.isMultiWeekSchedule {
            return viewModel.draft.editableWeekRanges
        }
        return [EventUploadWeekRangeDraft(startDate: viewModel.draft.startDate, endDate: viewModel.draft.endDate)]
    }

    private var normalizedStageEntries: [String] {
        if viewModel.draft.stageEntries.isEmpty {
            return [LT("主舞台", "Main Stage", "メインステージ")]
        }
        return viewModel.draft.stageEntries.enumerated().map { index, _ in
            viewModel.normalizedStageName(at: index)
        }
    }

    private var eventTimeZone: TimeZone {
        TimeZone(identifier: viewModel.draft.timeZoneIdentifier) ?? .current
    }

    private func weekRangeSummary(_ week: EventUploadWeekRangeDraft) -> String {
        return "\(shortDateString(week.startDate, in: eventTimeZone)) - \(shortDateString(week.endDate, in: eventTimeZone))"
    }

    private func eventDayOptionTitle(_ day: WebEventDay) -> String {
        if let label = day.label?.trimmingCharacters(in: .whitespacesAndNewlines), !label.isEmpty {
            return label
        }
        if viewModel.draft.isMultiWeekSchedule {
            return EventWeekScheduleMode.weekDayTitle(week: day.weekIndex, day: day.dayIndexInWeek)
        }
        let dateText = shortDateString(day.date, in: eventTimeZone)
        return LT("Day \(day.overallDayIndex) · \(dateText)", "Day \(day.overallDayIndex) · \(dateText)", "Day \(day.overallDayIndex) · \(dateText)")
    }

    private func weekTimetableSummary(for weekIndex: Int, week: EventUploadWeekRangeDraft) -> String {
        let dayIndexes = Set(weekDayOptions(for: EventUploadWeekSelection(index: weekIndex, week: week)).map(\.dayIndex))
        let count = viewModel.draft.timetableSlots.filter { dayIndexes.contains($0.dayIndex) }.count
        return LT("已安排 \(count) 个节目", "\(count) sets scheduled", "\(count) 件のセットを登録済み")
    }

    private func weekDayOptions(for selection: EventUploadWeekSelection) -> [EventUploadDayOption] {
        lineupDayOptions.filter { option in
            option.date >= startOfDay(selection.week.startDate) && option.date <= endOfDay(selection.week.endDate)
        }
    }

    private func startOfDay(_ date: Date) -> Date {
        var calendar = Calendar.current
        calendar.timeZone = TimeZone(identifier: viewModel.draft.timeZoneIdentifier) ?? .current
        return calendar.startOfDay(for: date)
    }

    private func endOfDay(_ date: Date) -> Date {
        var calendar = Calendar.current
        calendar.timeZone = TimeZone(identifier: viewModel.draft.timeZoneIdentifier) ?? .current
        let start = calendar.startOfDay(for: date)
        return calendar.date(byAdding: DateComponents(day: 1, second: -1), to: start) ?? date
    }

    private func weekEditorSheet(for selection: EventUploadWeekSelection) -> some View {
        EventUploadWeekTimetableEditorSheet(
            selection: selection,
            stageNames: normalizedStageEntries,
            slots: viewModel.draft.timetableSlots,
            dayOptions: weekDayOptions(for: selection),
            weekSummaryText: weekRangeSummary(selection.week),
            eventTimeZone: eventTimeZone,
            isExpanded: { expandedTimetableSlots.contains($0) },
            onToggleExpanded: toggleTimetableSlotExpansion,
            onAddSlot: { stageName, dayIndex in
                let id = viewModel.addTimetableSlot(stageName: stageName, dayIndex: dayIndex)
                expandedTimetableSlots.insert(id)
            },
            actTypeBinding: timetableActTypeBinding,
            performerBinding: timetablePerformerBinding,
            stageBinding: timetableStageBinding,
            dayBinding: timetableDayBinding,
            timeBinding: timetableTimeBinding,
            dayOffsetBinding: timetableDayOffsetBinding,
            isSearchingPerformer: { slot, index in
                viewModel.searchingDJKeys.contains(viewModel.djSearchKey(slotID: slot.id, performerIndex: index))
            },
            onSearchPerformer: { slot, index in
                Task { await viewModel.searchTimetableDJ(slotID: slot.id, performerIndex: index) }
            },
            onClearPerformer: { slot, index in
                viewModel.clearTimetableDJBinding(slotID: slot.id, performerIndex: index)
                viewModel.updateTimetableSlot(id: slot.id) { draftSlot in
                    while draftSlot.performerNames.count <= index {
                        draftSlot.performerNames.append("")
                    }
                    draftSlot.performerNames[index] = ""
                }
            },
            searchSection: { slot, index in
                AnyView(timetableDJSearchSection(slot, performerIndex: index))
            },
            onReplaceSlot: { slot in
                viewModel.updateTimetableSlot(id: slot.id) { draftSlot in
                    draftSlot.actType = slot.actType
                    draftSlot.performerNames = slot.performerNames
                    draftSlot.performerDJIDs = slot.performerDJIDs
                    draftSlot.performerAvatarURLs = slot.performerAvatarURLs
                }
            },
            onDelete: deleteTimetableSlotFromWeekEditor
        )
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private func toggleTimetableSlotExpansion(_ slotID: UUID) {
        if expandedTimetableSlots.contains(slotID) {
            expandedTimetableSlots.remove(slotID)
        } else {
            expandedTimetableSlots.insert(slotID)
        }
    }

    private func deleteTimetableSlotFromWeekEditor(_ slotID: UUID) {
        viewModel.removeTimetableSlot(id: slotID)
        expandedTimetableSlots.remove(slotID)
    }

    private func placeholderStep(title: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.title3.weight(.bold))
                .foregroundStyle(RaverTheme.primaryText)
            Text(LT("这一页的详细控件会在后续实现中接入。", "Detailed controls for this step will be wired up next.", "このステップの詳細コントロールは次に実装します。"))
                .font(.subheadline)
                .foregroundStyle(RaverTheme.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(RaverTheme.card, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(RaverTheme.cardBorder, lineWidth: 1)
        )
    }
}

private struct AIRecognitionPreviewPresentation: Identifiable {
    let id = UUID()
    let items: [FullscreenMediaItem]
    let initialIndex: Int
}

private struct AIRecognitionRunButton: View {
    let idleTitle: String
    let isRunning: Bool
    let isDisabled: Bool
    let action: () -> Void

    @State private var shineOffset: CGFloat = -1.4

    private let capsuleGradient = LinearGradient(
        colors: [.pink, .orange, .blue, .cyan],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: isRunning ? "sparkles.rectangle.stack" : "sparkles")
                    .font(.caption.weight(.bold))
                Text(isRunning ? LT("AI识别中", "AI Recognizing", "AI認識中") : idleTitle)
                    .font(.caption.weight(.bold))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background {
                Capsule()
                    .fill(capsuleGradient)
                    .overlay {
                        if isRunning {
                            GeometryReader { proxy in
                                let width = max(proxy.size.width, 1)
                                Rectangle()
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                .white.opacity(0.0),
                                                .white.opacity(0.14),
                                                .white.opacity(0.72),
                                                .white.opacity(0.14),
                                                .white.opacity(0.0),
                                            ],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .frame(width: width * 0.4)
                                    .rotationEffect(.degrees(18))
                                    .offset(x: shineOffset * width)
                                    .clipShape(Capsule())
                            }
                            .clipShape(Capsule())
                            .allowsHitTesting(false)
                        }
                    }
            }
            .opacity(isDisabled ? 0.55 : 1)
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .onAppear {
            guard isRunning else { return }
            startShine()
        }
        .onChange(of: isRunning) { _, running in
            if running {
                startShine()
            } else {
                shineOffset = -1.4
            }
        }
    }

    private func startShine() {
        shineOffset = -1.4
        withAnimation(.linear(duration: 1.15).repeatForever(autoreverses: false)) {
            shineOffset = 1.4
        }
    }
}

private func aiRecognitionPreviewPresentation(
    images: [EventUploadImageDraft],
    focusedImageID: UUID
) -> AIRecognitionPreviewPresentation? {
    var items: [FullscreenMediaItem] = []
    var initialIndex: Int?

    for image in images {
        let rawURL: String?
        if let localFileURL = image.localFileURL {
            rawURL = localFileURL.absoluteString
        } else if let remoteURL = image.remoteURL?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !remoteURL.isEmpty {
            rawURL = remoteURL
        } else {
            rawURL = nil
        }

        guard let rawURL else { continue }
        let itemIndex = items.count
        items.append(FullscreenMediaItem(rawURL: rawURL, index: itemIndex))
        if image.id == focusedImageID {
            initialIndex = itemIndex
        }
    }

    guard let initialIndex, !items.isEmpty else { return nil }
    return AIRecognitionPreviewPresentation(items: items, initialIndex: initialIndex)
}

private func aiRecognitionPreviewOverlayButton(action: @escaping () -> Void) -> some View {
    MediaPreviewOverlayButton(action: action)
        .padding(8)
}

private func aiRecognitionCanPreview(_ image: EventUploadImageDraft) -> Bool {
    image.localFileURL != nil || image.remoteURL != nil
}

@ViewBuilder
private func aiRecognitionThumbnailImage(_ image: EventUploadImageDraft) -> some View {
    if let localFileURL = image.localFileURL,
       let uiImage = UIImage(contentsOfFile: localFileURL.path) {
        Image(uiImage: uiImage)
            .resizable()
            .scaledToFill()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .allowsHitTesting(false)
    } else if let remoteURL = image.remoteURL,
              let url = URL(string: remoteURL) {
        AsyncImage(url: url) { phase in
            switch phase {
            case .success(let loaded):
                loaded
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .allowsHitTesting(false)
            default:
                Image(systemName: "photo")
                    .foregroundStyle(RaverTheme.secondaryText)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .allowsHitTesting(false)
            }
        }
    } else {
        Image(systemName: "photo")
            .foregroundStyle(RaverTheme.secondaryText)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .allowsHitTesting(false)
    }
}

private func aiRecognitionThumbnail(_ image: EventUploadImageDraft, cornerRadius: CGFloat = 10) -> some View {
    let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
    return GeometryReader { proxy in
        ZStack {
            shape
                .fill(RaverTheme.background)
                .allowsHitTesting(false)
            aiRecognitionThumbnailImage(image)
                .frame(width: proxy.size.width, height: proxy.size.height)
                .clipped()
        }
        .frame(width: proxy.size.width, height: proxy.size.height)
        .clipShape(shape)
        .contentShape(shape)
    }
}

private struct EventUploadPosterAIImportSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: EventUploadFlowViewModel
    @State private var selectedImageID: UUID?
    @State private var isRunning = false
    @State private var recognitionStartedAt: Date?
    @State private var statusMessage = LT("请选择一张已经上传到当前草稿里的活动海报或相关图片。", "Choose one uploaded poster or related image from this draft.", "この下書きに追加済みのポスターまたは関連画像を1枚選んでください。")
    @State private var statusIsError = false
    @State private var result: EventUploadPosterAIEditableResult?
    @State private var expandedLocalizedFieldKeys: Set<String> = []
    @State private var previewPresentation: AIRecognitionPreviewPresentation?

    private var images: [EventUploadImageDraft] {
        viewModel.timetableAIImageCandidates
    }

    private var selectedImage: EventUploadImageDraft? {
        guard let selectedImageID else { return nil }
        return images.first { $0.id == selectedImageID }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    imagePickerSection
                    statusSection
                    if let result {
                        resultSection(result)
                    }
                }
                .padding(16)
            }
            .background(RaverTheme.background.ignoresSafeArea())
            .navigationTitle(LT("AI 补充活动信息", "AI Event Autofill", "AIイベント補完"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(LT("关闭", "Close", "閉じる")) {
                        Task {
                            if isRunning {
                                await viewModel.cancelAIRecognition(.poster)
                            }
                            dismiss()
                        }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(LT("应用结果", "Apply", "適用")) {
                        guard let result else { return }
                        viewModel.applyPosterAIEditableResult(result)
                        dismiss()
                    }
                    .disabled(isRunning || result == nil)
                }
            }
            .onAppear {
                if selectedImageID == nil {
                    selectedImageID = images.first(where: { $0.zone == .poster })?.id ?? images.first?.id
                }
            }
            .fullScreenCover(item: $previewPresentation) { presentation in
                FullscreenMediaViewer(items: presentation.items, initialIndex: presentation.initialIndex)
            }
        }
    }

    private var imagePickerSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(LT("选择识别图片", "Recognition Image", "認識する画像"))
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(RaverTheme.primaryText)
                Spacer()
                AIRecognitionRunButton(
                    idleTitle: LT("确认并开始识别", "Run", "認識開始"),
                    isRunning: isRunning,
                    isDisabled: isRunning || selectedImage == nil
                ) {
                    Task { await runRecognition() }
                }
            }

            if images.isEmpty {
                Text(LT("当前草稿还没有图片。请先回到第一页上传活动海报或相关图片。", "No images are available in this draft. Upload a poster or related image first.", "この下書きには画像がありません。先にポスターや関連画像を追加してください。"))
                    .font(.caption)
                    .foregroundStyle(RaverTheme.secondaryText)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RaverTheme.card, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            } else {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    ForEach(images) { image in
                        let shape = RoundedRectangle(cornerRadius: 12, style: .continuous)
                        VStack(alignment: .leading, spacing: 8) {
                            posterAIImagePreview(image)
                                .frame(maxWidth: .infinity)
                                .frame(height: 104)
                            Text(image.zone.title)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(RaverTheme.primaryText)
                                .lineLimit(1)
                            Text(image.fileName)
                                .font(.caption2)
                                .foregroundStyle(RaverTheme.secondaryText)
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(8)
                        .background(RaverTheme.card, in: shape)
                        .overlay(
                            shape
                                .stroke(selectedImageID == image.id ? RaverTheme.accent : RaverTheme.cardBorder, lineWidth: selectedImageID == image.id ? 2 : 1)
                        )
                        .overlay(alignment: .topTrailing) {
                            if aiRecognitionCanPreview(image) {
                                aiRecognitionPreviewOverlayButton {
                                    previewPresentation = aiRecognitionPreviewPresentation(images: images, focusedImageID: image.id)
                                }
                            }
                        }
                        .clipShape(shape)
                        .contentShape(shape)
                        .onTapGesture {
                            guard !isRunning else { return }
                            selectedImageID = image.id
                        }
                    }
                }
            }
        }
    }

    private var statusSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            if isRunning {
                TimelineView(.periodic(from: Date(), by: 1)) { timeline in
                    HStack(spacing: 10) {
                        AIThinkingIndicator()
                        Spacer()
                        Text(elapsedText(since: recognitionStartedAt, now: timeline.date))
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(RaverTheme.secondaryText)
                    }
                }
                HStack {
                    Spacer()
                    Button {
                        Task {
                            await viewModel.cancelAIRecognition(.poster)
                            isRunning = false
                            recognitionStartedAt = nil
                            statusIsError = false
                            statusMessage = LT("已取消当前识别任务。", "Current recognition task cancelled.", "現在の認識タスクをキャンセルしました。")
                        }
                    } label: {
                        Label(LT("取消识别", "Cancel", "キャンセル"), systemImage: "xmark.circle")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.red)
                    }
                    .buttonStyle(.plain)
                }
            }
            Text(statusMessage)
                .font(.caption.weight(.semibold))
                .foregroundStyle(statusIsError ? Color.red : RaverTheme.secondaryText)
                .frame(maxWidth: .infinity, alignment: .leading)
            if let result {
                ForEach(result.warnings, id: \.self) { warning in
                    Text(warning)
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }
                if !result.unparsedTexts.isEmpty {
                    Text(LT("未解析文本：", "Unparsed text:", "未解析テキスト：") + result.unparsedTexts.prefix(4).joined(separator: " / "))
                        .font(.caption2)
                        .foregroundStyle(RaverTheme.secondaryText)
                }
            }
        }
        .padding(12)
        .background(RaverTheme.card, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(statusIsError ? Color.red.opacity(0.45) : RaverTheme.cardBorder, lineWidth: 1)
        )
    }

    private func resultSection(_ result: EventUploadPosterAIEditableResult) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(LT("识别结果", "Results", "認識結果"))
                .font(.subheadline.weight(.bold))
                .foregroundStyle(RaverTheme.primaryText)

            posterLocalizedFieldCard(
                title: LT("活动名称", "Event Name", "イベント名"),
                field: \.name,
                fieldKey: "poster-ai-name",
                includeEnglishFull: false,
                axis: .horizontal
            )
            posterLocalizedFieldCard(
                title: LT("城市", "City", "都市"),
                field: \.city,
                fieldKey: "poster-ai-city",
                includeEnglishFull: false,
                axis: .horizontal
            )
            posterTimeZoneCard
            posterLocalizedFieldCard(
                title: LT("详细地址", "Detail Address", "詳細住所"),
                field: \.detailAddress,
                fieldKey: "poster-ai-detail-address",
                includeEnglishFull: false,
                axis: .vertical
            )
            posterLocalizedFieldCard(
                title: LT("国家", "Country", "国"),
                field: \.country,
                fieldKey: "poster-ai-country",
                includeEnglishFull: true,
                axis: .horizontal
            )
            posterScheduleCard
            if !result.ticketURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !result.ticketTiers.isEmpty {
                posterTicketCard
            }
        }
    }

    private func runRecognition() async {
        guard let selectedImage else { return }
        isRunning = true
        recognitionStartedAt = Date()
        statusIsError = false
        statusMessage = LT("已提交识别任务，AI 正在补充活动基础信息。", "Recognition task submitted. AI is filling the event basics.", "認識タスクを送信しました。AIがイベント基本情報を補完しています。")
        do {
            let recognized = try await viewModel.recognizePosterFromImage(selectedImage)
            result = EventUploadPosterAIEditableResult(
                name: recognized.name,
                city: recognized.city,
                detailAddress: recognized.detailAddress,
                country: recognized.country,
                timeZoneIdentifier: recognized.timeZoneIdentifier,
                timeZoneDisplayName: recognized.timeZoneDisplayName,
                selectedTimeZoneLookup: nil,
                timeZoneSearchQuery: primaryText(recognized.city),
                scheduleMode: recognized.scheduleMode,
                startDate: recognized.startDate,
                endDate: recognized.endDate,
                weekRanges: recognized.weekRanges,
                ticketURL: recognized.ticketURL,
                ticketCurrency: recognized.ticketCurrency,
                ticketTiers: recognized.ticketTiers,
                warnings: recognized.warnings,
                unparsedTexts: recognized.unparsedTexts
            )
            syncPosterTimeZoneSession()
            statusIsError = false
            statusMessage = LT("识别完成。请检查结果，确认后会回填到第二页表单。", "Recognition finished. Review the result, then apply it to the basics form.", "認識が完了しました。結果を確認してから基本情報フォームへ反映してください。")
        } catch {
            result = nil
            statusIsError = true
            statusMessage = error.userFacingMessage ?? LT("活动信息识别失败，请稍后重试。", "Event info recognition failed. Please try again later.", "イベント情報認識に失敗しました。しばらくしてから再試行してください。")
        }
        isRunning = false
        recognitionStartedAt = nil
    }

    @ViewBuilder
    private func posterAIImagePreview(_ image: EventUploadImageDraft) -> some View {
        aiRecognitionThumbnail(image)
    }

    private func primaryText(_ fields: EventUploadLocalizedFields, fallback: String = "") -> String {
        let current = fields.primaryValue(preferredLanguage: viewModel.draft.preferredLanguage).trimmingCharacters(in: .whitespacesAndNewlines)
        if !current.isEmpty { return current }
        return fallback
    }

    private func posterScheduleText(_ result: EventUploadPosterAIEditableResult) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = TimeZone(identifier: result.timeZoneIdentifier ?? viewModel.draft.timeZoneIdentifier) ?? .current
        formatter.locale = Locale.current
        formatter.dateStyle = .medium
        guard let startDate = result.startDate else {
            return LT("未识别到明确日期", "No clear date recognized", "明確な日付を認識できませんでした")
        }
        guard let endDate = result.endDate else {
            return formatter.string(from: startDate)
        }
        return startDate.appLocalizedDateRangeText(to: endDate, timeZone: formatter.timeZone)
    }

    private func posterModeText(_ mode: EventUploadScheduleMode) -> String {
        switch mode {
        case .singleDay:
            return LT("单日活动", "Single-day event", "単日イベント")
        case .multiDay:
            return LT("多日活动", "Multi-day event", "複数日イベント")
        case .multiWeek:
            return LT("多 Week 活动", "Multi-week event", "複数Weekイベント")
        }
    }

    private func posterTicketText(_ result: EventUploadPosterAIEditableResult) -> String {
        let tierNames = result.ticketTiers.compactMap { tier -> String? in
            let name = tier.name.trimmingCharacters(in: .whitespacesAndNewlines)
            let price = tier.price.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty || !price.isEmpty else { return nil }
            return [name, price].filter { !$0.isEmpty }.joined(separator: " · ")
        }
        let suffix = result.ticketCurrency.trimmingCharacters(in: .whitespacesAndNewlines)
        return ([suffix] + tierNames).filter { !$0.isEmpty }.joined(separator: " / ")
    }

    private func elapsedText(since start: Date?, now: Date) -> String {
        guard let start else { return "00:00" }
        let seconds = max(0, Int(now.timeIntervalSince(start)))
        return String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }

    private func posterLocalizedFieldCard(
        title: String,
        field: WritableKeyPath<EventUploadPosterAIEditableResult, EventUploadLocalizedFields>,
        fieldKey: String,
        includeEnglishFull: Bool,
        axis: Axis
    ) -> some View {
        let fields = result?[keyPath: field] ?? EventUploadLocalizedFields()
        return LocalizedExpandableFieldSection(
            title: title,
            isRequired: false,
            axis: axis,
            includeEnglishFull: includeEnglishFull,
            expanded: posterLocalizedExpansionBinding(for: fieldKey),
            primaryPlaceholder: title,
            primaryBinding: Binding {
                primaryText(fields, fallback: includeEnglishFull ? fields.enFull : "")
            } set: { newValue in
                guard var fields = result?[keyPath: field] else { return }
                fields.setCurrentValue(newValue, preferredLanguage: viewModel.draft.preferredLanguage)
                result?[keyPath: field] = fields
            },
            zhBinding: posterLocalizedValueBinding(field: field, language: .zh),
            enBinding: posterLocalizedValueBinding(field: field, language: .en),
            jaBinding: posterLocalizedValueBinding(field: field, language: .ja),
            englishFullBinding: includeEnglishFull ? posterLocalizedEnglishFullBinding(field: field) : nil,
            extraCount: fields.secondaryValueCount(excluding: viewModel.draft.preferredLanguage, includeEnglishFull: includeEnglishFull),
            preferredLanguage: viewModel.draft.preferredLanguage
        )
    }

    private func posterLocalizedValueBinding(
        field: WritableKeyPath<EventUploadPosterAIEditableResult, EventUploadLocalizedFields>,
        language: EventUploadPreferredLanguage
    ) -> Binding<String> {
        Binding {
            result?[keyPath: field].value(for: language) ?? ""
        } set: { newValue in
            guard var fields = result?[keyPath: field] else { return }
            fields.setValue(newValue, for: language)
            result?[keyPath: field] = fields
        }
    }

    private func posterLocalizedEnglishFullBinding(
        field: WritableKeyPath<EventUploadPosterAIEditableResult, EventUploadLocalizedFields>
    ) -> Binding<String> {
        Binding {
            result?[keyPath: field].enFull ?? ""
        } set: { newValue in
            guard var fields = result?[keyPath: field] else { return }
            fields.enFull = newValue
            result?[keyPath: field] = fields
        }
    }

    private func posterLocalizedExpansionBinding(for key: String) -> Binding<Bool> {
        Binding {
            expandedLocalizedFieldKeys.contains(key)
        } set: { isExpanded in
            if isExpanded {
                expandedLocalizedFieldKeys.insert(key)
            } else {
                expandedLocalizedFieldKeys.remove(key)
            }
        }
    }

    private var posterTimeZoneCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(LT("城市时区", "City Time Zone", "都市タイムゾーン"))
                .font(.caption.weight(.semibold))
                .foregroundStyle(RaverTheme.secondaryText)

            posterLockedSearchField(
                title: LT("输入城市或城市+州/国家", "Enter city or city + state/country", "都市または都市+州/国を入力"),
                text: posterTimeZoneQueryBinding,
                isLocked: result?.selectedTimeZoneLookup != nil,
                lockedLabel: LT("已绑定", "Bound", "紐付け済み"),
                actionTitle: viewModel.isSearchingTimeZones ? LT("搜索中", "Searching", "検索中") : LT("搜索", "Search", "検索"),
                actionSystemImage: "magnifyingglass",
                isActionBusy: viewModel.isSearchingTimeZones,
                clearTitle: LT("清空", "Clear", "クリア"),
                canClear: result?.selectedTimeZoneLookup != nil || !(result?.timeZoneSearchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true),
                clearAction: clearPosterTimeZoneSelection
            ) {
                syncPosterTimeZoneSession()
                Task { await searchPosterTimeZones() }
            }

            Text(posterTimeZoneSummary)
                .font(.caption)
                .foregroundStyle(result?.selectedTimeZoneLookup != nil ? .green : RaverTheme.secondaryText)

            if let item = result?.selectedTimeZoneLookup {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(.green)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.label)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(RaverTheme.primaryText)
                        Text(item.timezone)
                            .font(.caption2)
                            .foregroundStyle(RaverTheme.secondaryText)
                    }
                    Spacer()
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(RaverTheme.background, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }

            if !viewModel.timeZoneSearchResults.isEmpty, result?.selectedTimeZoneLookup == nil {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(viewModel.timeZoneSearchResults.prefix(8)) { item in
                        Button {
                            applyPosterTimeZoneSelection(item)
                        } label: {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(item.label)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(RaverTheme.primaryText)
                                Text(item.timezone)
                                    .font(.caption2)
                                    .foregroundStyle(RaverTheme.secondaryText)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .background(RaverTheme.background, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
            } else if result?.selectedTimeZoneLookup == nil,
                      let message = viewModel.timeZoneSearchFeedback.message,
                      !viewModel.isSearchingTimeZones {
                posterInlineSearchFeedbackRow(
                    message: message,
                    systemImage: viewModel.timeZoneSearchFeedback.isFailure ? "exclamationmark.triangle.fill" : "mappin.and.ellipse",
                    tint: viewModel.timeZoneSearchFeedback.isFailure ? .orange : RaverTheme.secondaryText
                )
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RaverTheme.card, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(RaverTheme.cardBorder, lineWidth: 1)
        )
    }

    private var posterScheduleCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(LT("活动日期", "Schedule", "日程"))
                .font(.caption.weight(.semibold))
                .foregroundStyle(RaverTheme.secondaryText)

            Picker(LT("活动模式", "Schedule Mode", "日程モード"), selection: posterScheduleModeBinding) {
                ForEach(EventUploadScheduleMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            HStack(spacing: 10) {
                DatePicker("", selection: posterStartDateBinding, displayedComponents: [.date])
                    .labelsHidden()
                    .datePickerStyle(.compact)
                DatePicker("", selection: posterEndDateBinding, displayedComponents: [.date])
                    .labelsHidden()
                    .datePickerStyle(.compact)
            }

            if let result {
                Text("\(posterModeText(result.scheduleMode)) · \(posterScheduleText(result))")
                    .font(.caption2)
                    .foregroundStyle(RaverTheme.secondaryText)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RaverTheme.card, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(RaverTheme.cardBorder, lineWidth: 1)
        )
    }

    private var posterTicketCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(LT("票务信息", "Ticket Info", "チケット情報"))
                .font(.caption.weight(.semibold))
                .foregroundStyle(RaverTheme.secondaryText)

            TextField(
                LT("购票链接", "Ticket URL", "チケットURL"),
                text: Binding {
                    result?.ticketURL ?? ""
                } set: { newValue in
                    result?.ticketURL = newValue
                }
            )
            .font(.body)
            .foregroundStyle(RaverTheme.primaryText)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .padding(.horizontal, 12)
            .padding(.vertical, 11)
            .background(RaverTheme.background, in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            TextField(
                LT("币种", "Currency", "通貨"),
                text: Binding {
                    result?.ticketCurrency ?? ""
                } set: { newValue in
                    result?.ticketCurrency = newValue.uppercased()
                }
            )
            .font(.body)
            .foregroundStyle(RaverTheme.primaryText)
            .textInputAutocapitalization(.characters)
            .autocorrectionDisabled()
            .padding(.horizontal, 12)
            .padding(.vertical, 11)
            .background(RaverTheme.background, in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            if let result, !result.ticketTiers.isEmpty {
                VStack(spacing: 8) {
                    ForEach(Array(result.ticketTiers.enumerated()), id: \.element.id) { _, tier in
                        HStack(spacing: 10) {
                            TextField(
                                LT("票档名称", "Tier Name", "券種名"),
                                text: posterTicketTierNameBinding(tier.id)
                            )
                            .font(.body)
                            .foregroundStyle(RaverTheme.primaryText)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 11)
                            .background(RaverTheme.background, in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                            TextField(
                                LT("价格", "Price", "価格"),
                                text: posterTicketTierPriceBinding(tier.id)
                            )
                            .font(.body)
                            .foregroundStyle(RaverTheme.primaryText)
                            .keyboardType(.decimalPad)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 11)
                            .frame(width: 110)
                            .background(RaverTheme.background, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                    }
                }
                Text(posterTicketText(result))
                    .font(.caption2)
                    .foregroundStyle(RaverTheme.secondaryText)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RaverTheme.card, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(RaverTheme.cardBorder, lineWidth: 1)
        )
    }

    private var posterTimeZoneQueryBinding: Binding<String> {
        Binding {
            result?.timeZoneSearchQuery ?? ""
        } set: { newValue in
            result?.timeZoneSearchQuery = newValue
            result?.selectedTimeZoneLookup = nil
            result?.timeZoneIdentifier = nil
            result?.timeZoneDisplayName = ""
            viewModel.setTimeZoneSearchSession(query: newValue, selectedLookup: nil)
        }
    }

    private var posterScheduleModeBinding: Binding<EventUploadScheduleMode> {
        Binding {
            result?.scheduleMode ?? .singleDay
        } set: { newValue in
            result?.scheduleMode = newValue
        }
    }

    private var posterStartDateBinding: Binding<Date> {
        Binding {
            result?.startDate ?? Date()
        } set: { newValue in
            result?.startDate = newValue
            if let endDate = result?.endDate, endDate < newValue {
                result?.endDate = newValue
            }
        }
    }

    private var posterEndDateBinding: Binding<Date> {
        Binding {
            result?.endDate ?? result?.startDate ?? Date()
        } set: { newValue in
            let start = result?.startDate ?? newValue
            result?.endDate = max(newValue, start)
        }
    }

    private var posterTimeZoneSummary: String {
        if let item = result?.selectedTimeZoneLookup {
            return "\(item.label) · \(item.timezone)"
        }
        if let identifier = result?.timeZoneIdentifier?.trimmingCharacters(in: .whitespacesAndNewlines), !identifier.isEmpty {
            let displayName = result?.timeZoneDisplayName.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return displayName.isEmpty ? identifier : "\(displayName) · \(identifier)"
        }
        return LT("请搜索城市并确认活动时区。", "Search a city and confirm the event timezone.", "都市を検索してイベントのタイムゾーンを確認してください。")
    }

    private func searchPosterTimeZones() async {
        syncPosterTimeZoneSession()
        await viewModel.searchEventTimeZones(showEmptyMessage: false, useInlineFeedback: true)
    }

    private func syncPosterTimeZoneSession() {
        viewModel.setTimeZoneSearchSession(
            query: result?.timeZoneSearchQuery ?? "",
            selectedLookup: result?.selectedTimeZoneLookup
        )
    }

    private func applyPosterTimeZoneSelection(_ item: EventTimezoneLookupItem) {
        result?.selectedTimeZoneLookup = item
        result?.timeZoneIdentifier = item.timezone
        result?.timeZoneDisplayName = item.label
        result?.timeZoneSearchQuery = item.cityAscii.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? item.city : item.cityAscii
        viewModel.setTimeZoneSearchSession(query: result?.timeZoneSearchQuery ?? "", selectedLookup: item)
    }

    private func clearPosterTimeZoneSelection() {
        result?.selectedTimeZoneLookup = nil
        result?.timeZoneIdentifier = nil
        result?.timeZoneDisplayName = ""
        result?.timeZoneSearchQuery = ""
        viewModel.setTimeZoneSearchSession(query: "", selectedLookup: nil)
    }

    private func posterTicketTierNameBinding(_ tierID: UUID) -> Binding<String> {
        Binding {
            result?.ticketTiers.first(where: { $0.id == tierID })?.name ?? ""
        } set: { newValue in
            guard let index = result?.ticketTiers.firstIndex(where: { $0.id == tierID }) else { return }
            result?.ticketTiers[index].name = newValue
        }
    }

    private func posterTicketTierPriceBinding(_ tierID: UUID) -> Binding<String> {
        Binding {
            result?.ticketTiers.first(where: { $0.id == tierID })?.price ?? ""
        } set: { newValue in
            guard let index = result?.ticketTiers.firstIndex(where: { $0.id == tierID }) else { return }
            result?.ticketTiers[index].price = newValue
        }
    }

    private func posterLockedSearchField(
        title: String,
        text: Binding<String>,
        isLocked: Bool,
        lockedLabel: String,
        actionTitle: String,
        actionSystemImage: String,
        isActionBusy: Bool,
        clearTitle: String,
        canClear: Bool,
        clearAction: @escaping () -> Void,
        action: @escaping () -> Void
    ) -> some View {
        ZStack(alignment: .trailing) {
            TextField(title, text: text)
                .font(.body)
                .foregroundStyle(isLocked ? RaverTheme.secondaryText : RaverTheme.primaryText)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .disabled(isLocked)
                .padding(.trailing, canClear ? 166 : 92)

            HStack(spacing: 6) {
                if canClear {
                    Button(action: clearAction) {
                        Label(clearTitle, systemImage: "xmark.circle")
                            .font(.caption.weight(.bold))
                            .labelStyle(.titleAndIcon)
                            .lineLimit(1)
                            .foregroundStyle(RaverTheme.primaryText)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 7)
                            .background(RaverTheme.background, in: Capsule())
                            .overlay(
                                Capsule()
                                    .stroke(RaverTheme.cardBorder, lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                } else if isLocked {
                    HStack(spacing: 5) {
                        Image(systemName: "lock.fill")
                            .font(.caption2.weight(.bold))
                        Text(lockedLabel)
                            .font(.caption2.weight(.bold))
                    }
                    .foregroundStyle(.green)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(Color.green.opacity(0.12), in: Capsule())
                }

                Button(action: action) {
                    Label(actionTitle, systemImage: actionSystemImage)
                        .font(.caption.weight(.bold))
                        .labelStyle(.titleAndIcon)
                        .lineLimit(1)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(RaverTheme.accent, in: Capsule())
                }
                .buttonStyle(.plain)
                .disabled(isActionBusy || isLocked)
                .opacity((isActionBusy || isLocked) ? 0.56 : 1)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 11)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(isLocked ? RaverTheme.card.opacity(0.72) : RaverTheme.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(isLocked ? Color.green.opacity(0.35) : RaverTheme.cardBorder, lineWidth: 1)
        )
    }

    private func posterInlineSearchFeedbackRow(message: String, systemImage: String, tint: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.caption.weight(.semibold))
                .foregroundStyle(tint)
            Text(message)
                .font(.caption2)
                .foregroundStyle(RaverTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(RaverTheme.card, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

private struct EventUploadLineupAIImportSheet: View {
    private struct RecognitionTaskEntry: Identifiable {
        enum Phase {
            case preparing
            case polling(String)
            case autoMatching
            case succeeded
            case failed
            case cancelled

            var isTerminal: Bool {
                switch self {
                case .succeeded, .failed, .cancelled:
                    return true
                default:
                    return false
                }
            }
        }

        let id: UUID
        let image: EventUploadImageDraft
        var jobId: String?
        var phase: Phase
        var startedAt: Date
        var updatedAt: Date
        var itemCount: Int
        var warningCount: Int
        var message: String
    }

    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: EventUploadFlowViewModel
    @State private var selectedImageIDs: Set<UUID> = []
    @State private var isAutoMatching = false
    @State private var autoMatchStartedAt: Date?
    @State private var statusMessage = LT("请选择一张已经上传到当前草稿里的阵容图。", "Choose one image from this draft for lineup recognition.", "この下書きに追加済みの画像からラインナップ認識に使う1枚を選んでください。")
    @State private var statusIsError = false
    @State private var resultItems: [EventUploadLineupAIEditableItem] = []
    @State private var warnings: [String] = []
    @State private var unparsedTexts: [String] = []
    @State private var expandedItemIDs: Set<UUID> = []
    @State private var taskEntries: [RecognitionTaskEntry] = []
    @State private var taskHandles: [UUID: Task<Void, Never>] = [:]
    @State private var previewPresentation: AIRecognitionPreviewPresentation?

    private var images: [EventUploadImageDraft] {
        viewModel.timetableAIImageCandidates
    }

    private var selectedImages: [EventUploadImageDraft] {
        images.filter { selectedImageIDs.contains($0.id) }
    }

    private var hasActiveRecognitionTasks: Bool {
        taskEntries.contains { !$0.phase.isTerminal }
    }

    private var statusElapsedStart: Date? {
        if isAutoMatching {
            return autoMatchStartedAt
        }
        return taskEntries.first(where: { !$0.phase.isTerminal })?.startedAt
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    imagePickerSection
                    statusSection
                    if !taskEntries.isEmpty {
                        taskStatusSection
                    }
                    if !resultItems.isEmpty {
                        resultSection
                    }
                }
                .padding(16)
            }
            .background(RaverTheme.background.ignoresSafeArea())
            .navigationTitle(LT("AI 识别阵容图", "AI Lineup Import", "AIラインナップ認識"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(LT("关闭", "Close", "閉じる")) {
                        Task {
                            await cancelAllRecognitionTasks()
                            dismiss()
                        }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 10) {
                        Button {
                            Task { await autoMatchCurrentItems() }
                        } label: {
                            Label(LT("一键匹配", "Auto Match", "一括紐付け"), systemImage: "wand.and.stars")
                        }
                        .disabled(hasActiveRecognitionTasks || isAutoMatching || resultItems.isEmpty)

                        Button(LT("确认添加", "Apply", "追加")) {
                            viewModel.applyLineupAIImportItems(resultItems)
                            dismiss()
                        }
                        .disabled(hasActiveRecognitionTasks || isAutoMatching || resultItems.isEmpty)
                    }
                }
            }
            .onAppear {
                if selectedImageIDs.isEmpty, let firstID = images.first(where: { $0.zone == .lineup })?.id ?? images.first?.id {
                    selectedImageIDs = [firstID]
                }
            }
            .onDisappear {
                let handles = taskHandles.values
                taskHandles.removeAll()
                for handle in handles {
                    handle.cancel()
                }
            }
            .fullScreenCover(item: $previewPresentation) { presentation in
                FullscreenMediaViewer(items: presentation.items, initialIndex: presentation.initialIndex)
            }
        }
    }

    private var imagePickerSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(LT("选择识别图片", "Recognition Image", "認識する画像"))
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(RaverTheme.primaryText)
                Spacer()
                AIRecognitionRunButton(
                    idleTitle: selectedImages.count > 1
                        ? LT("识别 \(selectedImages.count) 张", "Run \(selectedImages.count)", "\(selectedImages.count)枚を認識")
                        : LT("确认并开始识别", "Run", "認識開始"),
                    isRunning: hasActiveRecognitionTasks,
                    isDisabled: selectedImages.isEmpty
                ) {
                    Task { await runRecognition() }
                }
            }

            if images.isEmpty {
                Text(LT("当前草稿还没有图片。请先回到第一页上传阵容图或相关图片。", "No images are available in this draft. Upload a lineup or related image first.", "この下書きには画像がありません。先に画像を追加してください。"))
                    .font(.caption)
                    .foregroundStyle(RaverTheme.secondaryText)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RaverTheme.card, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            } else {
                Text(
                    selectedImageIDs.isEmpty
                        ? LT("可一次勾选多张图，系统会并发创建多个识别任务，并把结果增量加入下方结果区。", "Select multiple images to launch concurrent recognition jobs and append each result below.", "複数画像を選ぶと、認識ジョブを並行実行し、結果を下に順次追加します。")
                        : LT("已选择 \(selectedImageIDs.count) 张。可以继续勾选更多图片，或随时再次开始新任务。", "\(selectedImageIDs.count) selected. You can keep adding images and start more jobs anytime.", "\(selectedImageIDs.count)枚選択中。さらに選択していつでも新しいジョブを開始できます。")
                )
                .font(.caption2)
                .foregroundStyle(RaverTheme.secondaryText)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    ForEach(images) { image in
                        let shape = RoundedRectangle(cornerRadius: 12, style: .continuous)
                        VStack(alignment: .leading, spacing: 8) {
                            imagePreview(image)
                                .frame(maxWidth: .infinity)
                                .frame(height: 104)
                            HStack(alignment: .top, spacing: 6) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(image.zone.title)
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(RaverTheme.primaryText)
                                        .lineLimit(1)
                                    Text(image.fileName)
                                        .font(.caption2)
                                        .foregroundStyle(RaverTheme.secondaryText)
                                        .lineLimit(1)
                                }
                                Spacer(minLength: 0)
                                Image(systemName: selectedImageIDs.contains(image.id) ? "checkmark.circle.fill" : "circle")
                                    .font(.headline)
                                    .foregroundStyle(selectedImageIDs.contains(image.id) ? RaverTheme.accent : RaverTheme.secondaryText)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(8)
                        .background(RaverTheme.card, in: shape)
                        .overlay(
                            shape
                                .stroke(selectedImageIDs.contains(image.id) ? RaverTheme.accent : RaverTheme.cardBorder, lineWidth: selectedImageIDs.contains(image.id) ? 2 : 1)
                        )
                        .overlay(alignment: .topTrailing) {
                            if aiRecognitionCanPreview(image) {
                                aiRecognitionPreviewOverlayButton {
                                    previewPresentation = aiRecognitionPreviewPresentation(images: images, focusedImageID: image.id)
                                }
                            }
                        }
                        .clipShape(shape)
                        .contentShape(shape)
                        .onTapGesture {
                            toggleImageSelection(image.id)
                        }
                    }
                }
            }
        }
    }

    private var statusSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            if hasActiveRecognitionTasks || isAutoMatching {
                TimelineView(.periodic(from: Date(), by: 1)) { timeline in
                    HStack(spacing: 10) {
                        AIThinkingIndicator()
                        Spacer()
                        Text(elapsedText(since: statusElapsedStart, now: timeline.date))
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(RaverTheme.secondaryText)
                    }
                }
            }
            Text(statusMessage)
                .font(.caption.weight(.semibold))
                .foregroundStyle(statusIsError ? Color.red : RaverTheme.secondaryText)
                .frame(maxWidth: .infinity, alignment: .leading)
            ForEach(warnings, id: \.self) { warning in
                Text(warning)
                    .font(.caption2)
                    .foregroundStyle(.orange)
            }
            if !unparsedTexts.isEmpty {
                Text(LT("未解析文本：", "Unparsed text:", "未解析テキスト：") + unparsedTexts.prefix(4).joined(separator: " / "))
                    .font(.caption2)
                    .foregroundStyle(RaverTheme.secondaryText)
            }
        }
        .padding(12)
        .background(RaverTheme.card, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(statusIsError ? Color.red.opacity(0.45) : RaverTheme.cardBorder, lineWidth: 1)
        )
    }

    private var taskStatusSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(LT("任务状态", "Task Status", "タスク状態"))
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(RaverTheme.primaryText)
                Spacer()
                if hasActiveRecognitionTasks {
                    Button {
                        Task { await cancelAllRecognitionTasks() }
                    } label: {
                        Label(LT("取消全部", "Cancel All", "すべてキャンセル"), systemImage: "xmark.circle")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.red)
                    }
                    .buttonStyle(.plain)
                }
            }

            ForEach(taskEntries) { entry in
                taskCard(entry)
            }
        }
    }

    private func taskCard(_ entry: RecognitionTaskEntry) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                imagePreview(entry.image)
                    .overlay(alignment: .topTrailing) {
                        if aiRecognitionCanPreview(entry.image) {
                            aiRecognitionPreviewOverlayButton {
                                previewPresentation = aiRecognitionPreviewPresentation(images: images, focusedImageID: entry.image.id)
                            }
                        }
                    }
                    .frame(width: 88, height: 72)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .clipped()

                VStack(alignment: .leading, spacing: 4) {
                    Text(entry.image.fileName)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(RaverTheme.primaryText)
                        .lineLimit(1)
                    Text(taskPhaseText(entry.phase))
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(taskPhaseTint(entry.phase))
                    Text(entry.message)
                        .font(.caption2)
                        .foregroundStyle(RaverTheme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)

                VStack(alignment: .trailing, spacing: 6) {
                    TimelineView(.periodic(from: Date(), by: 1)) { timeline in
                        Text(elapsedText(since: entry.startedAt, now: timeline.date))
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(RaverTheme.secondaryText)
                    }
                    if !entry.phase.isTerminal {
                        Button {
                            Task { await cancelRecognitionTask(entry.id) }
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.headline)
                                .foregroundStyle(.red)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            HStack(spacing: 10) {
                if let jobId = entry.jobId, !jobId.isEmpty {
                    infoChip(title: "Job", value: String(jobId.prefix(8)))
                }
                if entry.itemCount > 0 {
                    infoChip(title: LT("结果", "Result", "結果"), value: "\(entry.itemCount)")
                }
                if entry.warningCount > 0 {
                    infoChip(title: LT("警告", "Warnings", "警告"), value: "\(entry.warningCount)")
                }
            }
        }
        .padding(12)
        .background(RaverTheme.card, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(taskPhaseTint(entry.phase).opacity(0.28), lineWidth: 1)
        )
    }

    private func infoChip(title: String, value: String) -> some View {
        HStack(spacing: 4) {
            Text(title)
            Text(value)
        }
        .font(.caption2.weight(.semibold))
        .foregroundStyle(RaverTheme.secondaryText)
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(RaverTheme.background, in: Capsule())
    }

    private func toggleImageSelection(_ imageID: UUID) {
        if selectedImageIDs.contains(imageID) {
            selectedImageIDs.remove(imageID)
        } else {
            selectedImageIDs.insert(imageID)
        }
    }

    private var resultSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(LT("识别结果", "Results", "認識結果"))
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(RaverTheme.primaryText)
                Spacer()
                Text(LT("共 \(resultItems.count) 个", "\(resultItems.count) items", "\(resultItems.count)件"))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(RaverTheme.secondaryText)
            }

            Button {
                Task { await autoMatchCurrentItems() }
            } label: {
                Label(LT("一键匹配当前列表中的 DJ", "Auto match DJs in current list", "現在のリストのDJを一括紐付け"), systemImage: "wand.and.stars")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        LinearGradient(colors: [.cyan, .blue, .purple, .pink], startPoint: .leading, endPoint: .trailing),
                        in: Capsule()
                    )
            }
            .buttonStyle(.plain)
            .disabled(hasActiveRecognitionTasks || isAutoMatching || resultItems.isEmpty)

            VStack(spacing: 12) {
                ForEach(Array(resultItems.enumerated()), id: \.element.id) { index, item in
                    resultCard(item, order: index + 1)
                }
            }
        }
    }

    private func resultCard(_ item: EventUploadLineupAIEditableItem, order: Int) -> some View {
        let expanded = expandedItemIDs.contains(item.id)
        let names = performerNames(for: item)
        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Text("\(order)")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(RaverTheme.secondaryText)
                    .frame(width: 18, alignment: .leading)

                avatarStack(item: item, performerNames: names)

                Text(displayName(for: item))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(RaverTheme.primaryText)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Button {
                    expandedItemIDs.formSymmetricDifference([item.id])
                } label: {
                    Image(systemName: expanded ? "chevron.up" : "square.and.pencil")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(expanded ? RaverTheme.accent : RaverTheme.secondaryText)
                        .frame(width: 30, height: 30)
                        .background(RaverTheme.background, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(.plain)

                Button {
                    resultItems.removeAll { $0.id == item.id }
                    expandedItemIDs.remove(item.id)
                } label: {
                    Image(systemName: "trash")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.red)
                        .frame(width: 28, height: 28)
                        .background(RaverTheme.background, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(.plain)
            }

            if expanded {
                Picker(LT("演出形式", "Act Type", "出演形式"), selection: binding(for: item.id, keyPath: \.actType, default: .solo)) {
                    ForEach(EventLineupActType.allCases) { type in
                        Text(type.title).tag(type)
                    }
                }
                .pickerStyle(.segmented)

                ForEach(0..<item.actType.performerCount, id: \.self) { index in
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 10) {
                            performerAvatar(name: performerName(for: item, performerIndex: index), avatarURL: performerAvatarURL(for: item, performerIndex: index), index: index)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(item.actType == .solo ? LT("DJ / 艺人名称", "Artist / DJ Name", "DJ / アーティスト名") : LT("成员 \(index + 1)", "Member \(index + 1)", "メンバー \(index + 1)"))
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(RaverTheme.secondaryText)
                                Text(isBound(item, performerIndex: index) ? LT("已绑定 DJ 词条", "Bound to DJ entry", "DJエントリ紐付け済み") : LT("可手填，也可绑定 DJ 库", "Manual or DJ binding", "手入力またはDJ紐付け"))
                                    .font(.caption2)
                                    .foregroundStyle(RaverTheme.secondaryText)
                            }
                            Spacer()
                            if isBound(item, performerIndex: index) {
                                Image(systemName: "checkmark.seal.fill")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(.green)
                            }
                        }

                        aiImportDJSearchTextField(
                            title: item.actType == .solo ? LT("输入 DJ / 艺人名称", "Enter artist / DJ name", "DJ / アーティスト名を入力") : LT("输入成员名称", "Enter member name", "メンバー名を入力"),
                            text: performerNameBinding(itemID: item.id, performerIndex: index),
                            isSearching: viewModel.aiImportSearchingDJKeys.contains(searchKey(itemID: item.id, performerIndex: index)),
                            canClear: canClear(item, performerIndex: index),
                            clearAction: { clearDJBinding(itemID: item.id, performerIndex: index) },
                            action: {
                                Task {
                                    await viewModel.searchTimetableAIImportDJ(
                                        query: performerName(for: item, performerIndex: index),
                                        key: searchKey(itemID: item.id, performerIndex: index),
                                        useInlineFeedback: true
                                    )
                                }
                            }
                        )

                        djSearchSection(itemID: item.id, performerIndex: index)
                    }
                    .padding(12)
                    .background(RaverTheme.background, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }

                HStack {
                    Spacer()
                    Button {
                        expandedItemIDs.remove(item.id)
                    } label: {
                        Label(LT("确认", "Confirm", "確認"), systemImage: "checkmark")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 9)
                            .background(RaverTheme.accent, in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(14)
        .background(RaverTheme.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(RaverTheme.cardBorder, lineWidth: 1)
        )
    }

    @ViewBuilder
    private func imagePreview(_ image: EventUploadImageDraft) -> some View {
        aiRecognitionThumbnail(image)
    }

    private func runRecognition() async {
        let activeImageIDs = Set(taskEntries.filter { !$0.phase.isTerminal }.map(\.image.id))
        let launchImages = selectedImages.filter { !activeImageIDs.contains($0.id) }
        guard !launchImages.isEmpty else {
            statusIsError = true
            statusMessage = LT("请选择至少一张未在识别中的图片。", "Select at least one image that is not already running.", "まだ認識中ではない画像を1枚以上選択してください。")
            return
        }

        statusIsError = false
        statusMessage = launchImages.count > 1
            ? LT("已开始 \(launchImages.count) 个阵容识别任务，结果会逐个追加到下方。", "Started \(launchImages.count) lineup jobs. Results will be appended one by one.", "\(launchImages.count)件のラインナップ認識を開始しました。結果は順次追加されます。")
            : LT("已提交识别任务，AI 正在分析阵容图。结果返回后会自动匹配 DJ 并追加到下方。", "Recognition task submitted. The result will auto-match DJs and append below.", "認識タスクを送信しました。結果はDJ自動紐付け後に下へ追加されます。")

        for image in launchImages {
            startRecognitionTask(for: image)
        }
    }

    private func startRecognitionTask(for image: EventUploadImageDraft) {
        let entryID = UUID()
        taskEntries.insert(
            RecognitionTaskEntry(
                id: entryID,
                image: image,
                jobId: nil,
                phase: .preparing,
                startedAt: Date(),
                updatedAt: Date(),
                itemCount: 0,
                warningCount: 0,
                message: LT("准备上传并创建识别任务。", "Preparing image upload and job creation.", "画像アップロードとジョブ作成を準備しています。")
            ),
            at: 0
        )

        let handle = Task {
            do {
                let createdJob = try await viewModel.createLineupAIImportJob(for: image)
                await MainActor.run {
                    updateTask(
                        entryID,
                        phase: .polling(createdJob.status),
                        jobId: createdJob.jobId,
                        message: LT("识别任务已创建，正在轮询 Coze 状态。", "Job created. Polling Coze status now.", "認識ジョブを作成しました。Coze状態をポーリングしています。")
                    )
                }

                let response = try await waitForLineupTask(entryID: entryID, jobId: createdJob.jobId)
                await MainActor.run {
                    updateTask(
                        entryID,
                        phase: .autoMatching,
                        message: LT("识别完成，正在自动匹配 DJ 库。", "Recognition finished. Auto-matching DJs now.", "認識完了。DJライブラリを自動紐付けしています。")
                    )
                }

                let parsed = viewModel.editableLineupImportResult(from: response)
                let matched = await viewModel.autoMatchLineupAIImportItems(parsed.items)

                await MainActor.run {
                    appendRecognitionResult(items: matched, warnings: parsed.warnings, unparsedTexts: parsed.unparsedTexts)
                    updateTask(
                        entryID,
                        phase: .succeeded,
                        itemCount: matched.count,
                        warningCount: parsed.warnings.count,
                        message: matched.isEmpty
                            ? LT("任务完成，但没有可用阵容结果。", "Task completed but returned no usable lineup items.", "タスクは完了しましたが、有効なラインナップ結果はありませんでした。")
                            : LT("任务完成，\(matched.count) 条结果已追加到下方。", "Task completed. \(matched.count) results appended below.", "タスク完了。\(matched.count)件の結果を下に追加しました。")
                    )
                    statusIsError = false
                    statusMessage = LT("新结果已追加到当前阵容识别列表。你可以继续选择更多图片再跑新任务。", "New results were appended. You can keep selecting more images and launch more jobs.", "新しい結果を追加しました。さらに画像を選んで新しいジョブを続けて開始できます。")
                }
            } catch is CancellationError {
                await MainActor.run {
                    updateTask(
                        entryID,
                        phase: .cancelled,
                        message: LT("已取消该识别任务。", "This recognition task was cancelled.", "この認識タスクをキャンセルしました。")
                    )
                    statusIsError = false
                    statusMessage = LT("已取消一个识别任务。", "Cancelled one recognition task.", "認識タスクを1件キャンセルしました。")
                }
            } catch {
                await MainActor.run {
                    updateTask(
                        entryID,
                        phase: .failed,
                        message: error.userFacingMessage ?? LT("阵容识别失败，请稍后重试。", "Lineup recognition failed. Please try again later.", "ラインナップ認識に失敗しました。しばらくしてから再試行してください。")
                    )
                    statusIsError = true
                    statusMessage = error.userFacingMessage ?? LT("有一个阵容识别任务失败了，请检查任务状态后重试。", "One lineup task failed. Check the task status and retry.", "ラインナップ認識タスクが1件失敗しました。状態を確認して再試行してください。")
                }
            }

            await MainActor.run {
                taskHandles[entryID] = nil
            }
        }

        taskHandles[entryID] = handle
    }

    private func waitForLineupTask(entryID: UUID, jobId: String) async throws -> EventLineupAIImportResponse {
        let deadline = Date().addingTimeInterval(10 * 60)
        while Date() < deadline {
            try Task.checkCancellation()
            let job = try await viewModel.fetchLineupAIImportJob(id: jobId)
            await MainActor.run {
                updateTask(
                    entryID,
                    phase: .polling(job.status),
                    message: taskPollingMessage(for: job.status)
                )
            }

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

    private func cancelRecognitionTask(_ entryID: UUID) async {
        let handle = taskHandles[entryID]
        let jobId = taskEntries.first(where: { $0.id == entryID })?.jobId
        handle?.cancel()
        if let jobId, !jobId.isEmpty {
            try? await viewModel.cancelLineupAIImportJob(id: jobId)
        }
        await MainActor.run {
            updateTask(
                entryID,
                phase: .cancelled,
                message: LT("已取消该识别任务。", "This recognition task was cancelled.", "この認識タスクをキャンセルしました。")
            )
            taskHandles[entryID] = nil
        }
    }

    private func cancelAllRecognitionTasks() async {
        let activeIDs = taskEntries.filter { !$0.phase.isTerminal }.map(\.id)
        for id in activeIDs {
            await cancelRecognitionTask(id)
        }
    }

    private func updateTask(
        _ entryID: UUID,
        phase: RecognitionTaskEntry.Phase,
        jobId: String? = nil,
        itemCount: Int? = nil,
        warningCount: Int? = nil,
        message: String
    ) {
        guard let index = taskEntries.firstIndex(where: { $0.id == entryID }) else { return }
        taskEntries[index].phase = phase
        taskEntries[index].updatedAt = Date()
        if let jobId {
            taskEntries[index].jobId = jobId
        }
        if let itemCount {
            taskEntries[index].itemCount = itemCount
        }
        if let warningCount {
            taskEntries[index].warningCount = warningCount
        }
        taskEntries[index].message = message
    }

    private func taskPollingMessage(for status: String) -> String {
        switch status.lowercased() {
        case "queued", "pending":
            return LT("任务已排队，等待 Coze 开始处理。", "Queued and waiting for Coze to start processing.", "ジョブはキュー待ちで、Cozeの処理開始を待っています。")
        case "running", "processing":
            return LT("AI 正在识别这张阵容图。", "AI is actively recognizing this lineup image.", "AIがこのラインナップ画像を認識中です。")
        case "succeeded":
            return LT("识别完成，正在整理结果。", "Recognition finished. Preparing the result.", "認識が完了し、結果を整理しています。")
        case "failed":
            return LT("识别失败。", "Recognition failed.", "認識に失敗しました。")
        case "cancelled":
            return LT("识别已取消。", "Recognition was cancelled.", "認識はキャンセルされました。")
        default:
            return LT("正在轮询识别状态。", "Polling recognition status.", "認識状態をポーリングしています。")
        }
    }

    private func taskPhaseText(_ phase: RecognitionTaskEntry.Phase) -> String {
        switch phase {
        case .preparing:
            return LT("准备中", "Preparing", "準備中")
        case .polling(let status):
            switch status.lowercased() {
            case "queued", "pending":
                return LT("排队中", "Queued", "待機中")
            case "running", "processing":
                return LT("识别中", "Recognizing", "認識中")
            case "succeeded":
                return LT("整理结果", "Finalizing", "結果整理中")
            default:
                return LT("轮询中", "Polling", "ポーリング中")
            }
        case .autoMatching:
            return LT("自动匹配 DJ", "Auto Matching DJs", "DJ自動紐付け")
        case .succeeded:
            return LT("已完成", "Completed", "完了")
        case .failed:
            return LT("失败", "Failed", "失敗")
        case .cancelled:
            return LT("已取消", "Cancelled", "キャンセル済み")
        }
    }

    private func taskPhaseTint(_ phase: RecognitionTaskEntry.Phase) -> Color {
        switch phase {
        case .succeeded:
            return .green
        case .failed, .cancelled:
            return .red
        case .autoMatching:
            return .orange
        default:
            return RaverTheme.accent
        }
    }

    private func appendRecognitionResult(
        items: [EventUploadLineupAIEditableItem],
        warnings nextWarnings: [String],
        unparsedTexts nextUnparsedTexts: [String]
    ) {
        guard !items.isEmpty || !nextWarnings.isEmpty || !nextUnparsedTexts.isEmpty else { return }
        resultItems.append(contentsOf: items)
        for warning in nextWarnings where !warnings.contains(warning) {
            warnings.append(warning)
        }
        for text in nextUnparsedTexts where !unparsedTexts.contains(text) {
            unparsedTexts.append(text)
        }
        expandedItemIDs = expandedItemIDs.intersection(Set(resultItems.map(\.id)))
    }

    private func autoMatchCurrentItems() async {
        guard !isAutoMatching else { return }
        isAutoMatching = true
        autoMatchStartedAt = Date()
        statusIsError = false
        statusMessage = LT("正在匹配当前列表中的 DJ 词条。", "Matching DJs in the current list.", "現在のリストのDJを紐付けています。")
        resultItems = await viewModel.autoMatchLineupAIImportItems(resultItems)
        statusMessage = LT("已完成自动匹配，可继续确认导入。", "Auto match finished. You can continue and apply.", "自動紐付けが完了しました。続けて適用できます。")
        isAutoMatching = false
        autoMatchStartedAt = nil
    }

    private func performerNames(for item: EventUploadLineupAIEditableItem) -> [String] {
        item.performerNamesText
            .split(separator: ",")
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private func displayName(for item: EventUploadLineupAIEditableItem) -> String {
        let composed = EventLineupActCodec.composeName(type: item.actType, performerNames: performerNames(for: item))
        return composed.isEmpty ? LT("未命名阵容", "Untitled Lineup", "未命名ラインナップ") : composed
    }

    private func performerName(for item: EventUploadLineupAIEditableItem, performerIndex: Int) -> String {
        let names = performerNames(for: item)
        return names.indices.contains(performerIndex) ? names[performerIndex] : ""
    }

    private func performerAvatarURL(for item: EventUploadLineupAIEditableItem, performerIndex: Int) -> String? {
        item.performerAvatarURLs.indices.contains(performerIndex) ? item.performerAvatarURLs[performerIndex] : nil
    }

    private func avatarStack(item: EventUploadLineupAIEditableItem, performerNames: [String]) -> some View {
        HStack(spacing: -10) {
            ForEach(Array(performerNames.prefix(item.actType.performerCount).enumerated()), id: \.offset) { index, name in
                performerAvatar(name: name, avatarURL: item.performerAvatarURLs.indices.contains(index) ? item.performerAvatarURLs[index] : nil, index: index)
            }
        }
        .padding(.trailing, 8)
    }

    private func performerAvatar(name: String, avatarURL: String?, index: Int) -> some View {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return Group {
            if let avatarURL,
               let resolved = AppConfig.resolvedDJAvatarURLString(avatarURL, size: .small),
               !resolved.isEmpty {
                AsyncImage(url: URL(string: resolved)) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    default:
                        avatarFallback(trimmed: trimmed, index: index)
                    }
                }
            } else {
                avatarFallback(trimmed: trimmed, index: index)
            }
        }
        .frame(width: 32, height: 32)
        .clipShape(Circle())
        .overlay(Circle().stroke(RaverTheme.card, lineWidth: 2))
    }

    private func avatarFallback(trimmed: String, index: Int) -> some View {
        ZStack {
            Circle().fill(index == 0 ? RaverTheme.accent.opacity(0.22) : RaverTheme.background)
            Text(String(trimmed.prefix(1)).uppercased())
                .font(.caption.weight(.bold))
                .foregroundStyle(index == 0 ? RaverTheme.accent : RaverTheme.secondaryText)
        }
    }

    private func isBound(_ item: EventUploadLineupAIEditableItem, performerIndex: Int) -> Bool {
        item.performerDJIDs.indices.contains(performerIndex)
            ? item.performerDJIDs[performerIndex]?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            : false
    }

    private func canClear(_ item: EventUploadLineupAIEditableItem, performerIndex: Int) -> Bool {
        !performerName(for: item, performerIndex: performerIndex).trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isBound(item, performerIndex: performerIndex)
    }

    private func searchKey(itemID: UUID, performerIndex: Int) -> String {
        "lineup-ai-\(itemID.uuidString)-\(performerIndex)"
    }

    private func performerNameBinding(itemID: UUID, performerIndex: Int) -> Binding<String> {
        Binding {
            guard let item = resultItems.first(where: { $0.id == itemID }) else { return "" }
            return performerName(for: item, performerIndex: performerIndex)
        } set: { newValue in
            guard let index = resultItems.firstIndex(where: { $0.id == itemID }) else { return }
            var names = performerNames(for: resultItems[index])
            while names.count <= performerIndex {
                names.append("")
            }
            names[performerIndex] = newValue
            resultItems[index].performerNamesText = names.joined(separator: ", ")
            while resultItems[index].performerDJIDs.count <= performerIndex {
                resultItems[index].performerDJIDs.append(nil)
            }
            while resultItems[index].performerAvatarURLs.count <= performerIndex {
                resultItems[index].performerAvatarURLs.append(nil)
            }
            resultItems[index].performerDJIDs[performerIndex] = nil
            resultItems[index].performerAvatarURLs[performerIndex] = nil
            Task {
                await viewModel.searchTimetableAIImportDJ(
                    query: newValue,
                    key: searchKey(itemID: itemID, performerIndex: performerIndex),
                    useInlineFeedback: true
                )
            }
        }
    }

    private func applyDJBinding(_ dj: WebDJ, itemID: UUID, performerIndex: Int) {
        guard let index = resultItems.firstIndex(where: { $0.id == itemID }) else { return }
        var names = performerNames(for: resultItems[index])
        while names.count <= performerIndex {
            names.append("")
        }
        names[performerIndex] = dj.name
        resultItems[index].performerNamesText = names.joined(separator: ", ")
        while resultItems[index].performerDJIDs.count <= performerIndex {
            resultItems[index].performerDJIDs.append(nil)
        }
        while resultItems[index].performerAvatarURLs.count <= performerIndex {
            resultItems[index].performerAvatarURLs.append(nil)
        }
        resultItems[index].performerDJIDs[performerIndex] = dj.id
        resultItems[index].performerAvatarURLs[performerIndex] = dj.avatarSmallUrl ?? dj.avatarMediumUrl ?? dj.avatarUrl ?? dj.avatarOriginalUrl
    }

    private func clearDJBinding(itemID: UUID, performerIndex: Int) {
        guard let index = resultItems.firstIndex(where: { $0.id == itemID }) else { return }
        var names = performerNames(for: resultItems[index])
        while names.count <= performerIndex {
            names.append("")
        }
        names[performerIndex] = ""
        resultItems[index].performerNamesText = names.joined(separator: ", ")
        while resultItems[index].performerDJIDs.count <= performerIndex {
            resultItems[index].performerDJIDs.append(nil)
        }
        while resultItems[index].performerAvatarURLs.count <= performerIndex {
            resultItems[index].performerAvatarURLs.append(nil)
        }
        resultItems[index].performerDJIDs[performerIndex] = nil
        resultItems[index].performerAvatarURLs[performerIndex] = nil
        viewModel.aiImportDJSearchFeedbacks[searchKey(itemID: itemID, performerIndex: performerIndex)] = .idle
        viewModel.aiImportDJSearchResults[searchKey(itemID: itemID, performerIndex: performerIndex)] = []
    }

    private func djSearchSection(itemID: UUID, performerIndex: Int) -> some View {
        let key = searchKey(itemID: itemID, performerIndex: performerIndex)
        let results = viewModel.aiImportDJSearchResults[key] ?? []
        let feedback = viewModel.aiImportDJSearchFeedbacks[key] ?? .idle
        let isSearching = viewModel.aiImportSearchingDJKeys.contains(key)
        return aiImportDJSearchResultsList(results: results, feedback: feedback, isSearching: isSearching) { dj in
            applyDJBinding(dj, itemID: itemID, performerIndex: performerIndex)
        }
    }

    private func aiImportDJSearchTextField(
        title: String,
        text: Binding<String>,
        isSearching: Bool,
        canClear: Bool,
        clearAction: @escaping () -> Void,
        action: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(RaverTheme.secondaryText)
            ZStack(alignment: .trailing) {
                TextField(title, text: text)
                    .font(.body)
                    .foregroundStyle(RaverTheme.primaryText)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .padding(.trailing, canClear ? 168 : 104)

                HStack(spacing: 6) {
                    if canClear {
                        Button(action: clearAction) {
                            Label(LT("清空", "Clear", "クリア"), systemImage: "xmark.circle")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(RaverTheme.primaryText)
                                .padding(.horizontal, 9)
                                .padding(.vertical, 7)
                                .background(RaverTheme.card, in: Capsule())
                                .overlay(Capsule().stroke(RaverTheme.cardBorder, lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                    }

                    Button(action: action) {
                        Label(isSearching ? LT("搜索中", "Searching", "検索中") : LT("绑定", "Bind", "紐付け"), systemImage: "magnifyingglass")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .background(RaverTheme.accent, in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .disabled(isSearching)
                    .opacity(isSearching ? 0.72 : 1)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 11)
            .background(RaverTheme.background, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func aiImportDJSearchResultsList(
        results: [WebDJ],
        feedback: EventUploadFlowViewModel.InlineSearchFeedback,
        isSearching: Bool,
        onSelect: @escaping (WebDJ) -> Void
    ) -> some View {
        if !results.isEmpty {
            VStack(spacing: 6) {
                ForEach(results.prefix(8)) { dj in
                    Button {
                        onSelect(dj)
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "music.mic.circle.fill")
                                .font(.title3)
                                .foregroundStyle(RaverTheme.accent)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(dj.name)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(RaverTheme.primaryText)
                                Text(dj.country ?? dj.slug ?? dj.id)
                                    .font(.caption2)
                                    .foregroundStyle(RaverTheme.secondaryText)
                                    .lineLimit(1)
                            }
                            Spacer()
                            Image(systemName: "plus.circle")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(RaverTheme.secondaryText)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(RaverTheme.card, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
        } else if isSearching {
            inlineSearchFeedbackRow(message: LT("正在搜索 DJ 库…", "Searching DJ library...", "DJライブラリを検索中..."), systemImage: "clock.arrow.circlepath", tint: RaverTheme.secondaryText)
        } else if let message = feedback.message {
            inlineSearchFeedbackRow(message: message, systemImage: feedback.isFailure ? "exclamationmark.triangle.fill" : "info.circle.fill", tint: feedback.isFailure ? .red : RaverTheme.secondaryText)
        }
    }

    private func inlineSearchFeedbackRow(message: String, systemImage: String, tint: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.caption)
                .foregroundStyle(tint)
            Text(message)
                .font(.caption2)
                .foregroundStyle(tint)
            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(RaverTheme.background, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func elapsedText(since start: Date?, now: Date) -> String {
        guard let start else { return "00:00" }
        let seconds = max(0, Int(now.timeIntervalSince(start)))
        return String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }

    private func binding<T>(for itemID: UUID, keyPath: WritableKeyPath<EventUploadLineupAIEditableItem, T>, default defaultValue: @autoclosure @escaping () -> T) -> Binding<T> {
        Binding {
            resultItems.first(where: { $0.id == itemID })?[keyPath: keyPath] ?? defaultValue()
        } set: { newValue in
            guard let index = resultItems.firstIndex(where: { $0.id == itemID }) else { return }
            resultItems[index][keyPath: keyPath] = newValue
        }
    }
}

private struct EventUploadTimetableAIImportSheet: View {
    private struct RecognitionTaskEntry: Identifiable {
        enum Phase {
            case preparing
            case submitted
            case polling(String)
            case autoMatching
            case succeeded
            case failed
            case cancelled

            var isTerminal: Bool {
                switch self {
                case .succeeded, .failed, .cancelled:
                    return true
                default:
                    return false
                }
            }
        }

        let id: UUID
        let image: EventUploadImageDraft
        var jobId: String?
        var phase: Phase
        var startedAt: Date
        var updatedAt: Date
        var slotCount: Int
        var warningCount: Int
        var message: String
    }

    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: EventUploadFlowViewModel
    @State private var selectedImageIDs: Set<UUID> = []
    @State private var statusMessage = LT("请选择一张已经上传到当前草稿里的时间表图片。", "Choose one image from this draft for timetable recognition.", "この下書きに追加済みの画像からタイムテーブル認識に使う1枚を選んでください。")
    @State private var statusIsError = false
    @State private var resultSlots: [EventUploadTimetableAIEditableSlot] = []
    @State private var warnings: [String] = []
    @State private var unparsedTexts: [String] = []
    @State private var selectedWeekIndex: Int?
    @State private var selectedEventDayIdentity: String?
    @State private var selectedStageName: String?
    @State private var expandedSlotIDs: Set<UUID> = []
    @State private var warningsExpanded = false
    @State private var isAutoMatching = false
    @State private var autoMatchStartedAt: Date?
    @State private var taskEntries: [RecognitionTaskEntry] = []
    @State private var taskHandles: [UUID: Task<Void, Never>] = [:]
    @State private var previewPresentation: AIRecognitionPreviewPresentation?
    @State private var isResultSelectionMode = false
    @State private var selectedResultSlotIDs: Set<UUID> = []
    @State private var moveResultDayDialogPresented = false
    @State private var moveResultStageDialogPresented = false

    private var images: [EventUploadImageDraft] {
        viewModel.timetableAIImageCandidates
    }

    private var selectedImages: [EventUploadImageDraft] {
        images.filter { selectedImageIDs.contains($0.id) }
    }

    private var hasActiveRecognitionTasks: Bool {
        taskEntries.contains { !$0.phase.isTerminal }
    }

    private var statusElapsedStart: Date? {
        if isAutoMatching {
            return autoMatchStartedAt
        }
        return taskEntries.first(where: { !$0.phase.isTerminal })?.startedAt
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    imagePickerSection
                    statusSection
                    if !taskEntries.isEmpty {
                        taskStatusSection
                    }
                    if !resultSlots.isEmpty {
                        filterSection
                        resultSection
                    }
                }
                .padding(16)
            }
            .scrollDismissesKeyboard(.interactively)
            .simultaneousGesture(TapGesture().onEnded { self.dismissKeyboard() })
            .background(RaverTheme.background.ignoresSafeArea())
            .navigationTitle(LT("AI 识别时间表", "AI Timetable Import", "AIタイムテーブル認識"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(LT("关闭", "Close", "閉じる")) {
                        Task {
                            await cancelAllRecognitionTasks()
                            dismiss()
                        }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 10) {
                        Button {
                            Task { await autoMatchCurrentSlots() }
                        } label: {
                            Label(LT("一键匹配", "Auto Match", "一括紐付け"), systemImage: "wand.and.stars")
                        }
                        .disabled(hasActiveRecognitionTasks || isAutoMatching || resultSlots.isEmpty)

                        Button(LT("确认添加", "Apply", "追加")) {
                            viewModel.applyTimetableAIImportSlots(resultSlots)
                            dismiss()
                        }
                        .disabled(hasActiveRecognitionTasks || isAutoMatching || resultSlots.isEmpty || hasUnresolvedEventDayResults)
                    }
                }
            }
            .onAppear {
                if selectedImageIDs.isEmpty, let firstID = images.first(where: { $0.zone == .timetable })?.id ?? images.first?.id {
                    selectedImageIDs = [firstID]
                }
            }
            .onDisappear {
                let handles = taskHandles.values
                taskHandles.removeAll()
                for handle in handles {
                    handle.cancel()
                }
            }
            .fullScreenCover(item: $previewPresentation) { presentation in
                FullscreenMediaViewer(items: presentation.items, initialIndex: presentation.initialIndex)
            }
            .confirmationDialog(
                LT("更换到哪一天？", "Move to which day?", "どの日に移動しますか？"),
                isPresented: $moveResultDayDialogPresented,
                titleVisibility: .visible
            ) {
                ForEach(availableMoveDays, id: \.self) { day in
                    Button(dayFilterLabel(for: day)) {
                        moveSelectedResultSlots(to: day)
                    }
                }
                Button(LT("取消", "Cancel", "キャンセル"), role: .cancel) {}
            } message: {
                Text(LT("会把已选中的节目移动到目标日期。", "Selected sets will be moved to the target day.", "選択した出演を指定の日に移動します。"))
            }
            .confirmationDialog(
                LT("更换到哪个舞台？", "Move to which stage?", "どのステージに移動しますか？"),
                isPresented: $moveResultStageDialogPresented,
                titleVisibility: .visible
            ) {
                ForEach(availableStageMoveOptions, id: \.self) { stage in
                    Button(stage) {
                        moveSelectedResultSlots(toStage: stage)
                    }
                }
                Button(LT("取消", "Cancel", "キャンセル"), role: .cancel) {}
            } message: {
                Text(LT("会把已选中的节目移动到目标舞台。", "Selected sets will be moved to the target stage.", "選択した出演を指定のステージに移動します。"))
            }
        }
    }

    private var imagePickerSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(LT("选择识别图片", "Recognition Image", "認識する画像"))
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(RaverTheme.primaryText)
                Spacer()
                AIRecognitionRunButton(
                    idleTitle: selectedImages.count > 1
                        ? LT("识别 \(selectedImages.count) 张", "Run \(selectedImages.count)", "\(selectedImages.count)枚を認識")
                        : LT("确认并开始识别", "Run", "認識開始"),
                    isRunning: hasActiveRecognitionTasks,
                    isDisabled: selectedImages.isEmpty
                ) {
                    Task { await runRecognition() }
                }
            }

            if images.isEmpty {
                Text(LT("当前草稿还没有图片。请先回到第一页上传时间表图或相关图片。", "No images are available in this draft. Upload a timetable or related image first.", "この下書きには画像がありません。先に画像を追加してください。"))
                    .font(.caption)
                    .foregroundStyle(RaverTheme.secondaryText)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RaverTheme.card, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            } else {
                Text(
                    selectedImageIDs.isEmpty
                        ? LT("可一次勾选多张图，系统会并发创建多个识别任务，并把结果增量加入下方结果区。", "Select multiple images to launch concurrent recognition jobs and append each result below.", "複数画像を選ぶと、認識ジョブを並行実行し、結果を下に順次追加します。")
                        : LT("已选择 \(selectedImageIDs.count) 张。可以继续勾选更多图片，或随时再次开始新任务。", "\(selectedImageIDs.count) selected. You can keep adding images and start more jobs anytime.", "\(selectedImageIDs.count)枚選択中。さらに選択していつでも新しいジョブを開始できます。")
                )
                .font(.caption2)
                .foregroundStyle(RaverTheme.secondaryText)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    ForEach(images) { image in
                        let shape = RoundedRectangle(cornerRadius: 12, style: .continuous)
                        VStack(alignment: .leading, spacing: 8) {
                            timetableAIImagePreview(image)
                                .frame(maxWidth: .infinity)
                                .frame(height: 104)
                            HStack(alignment: .top, spacing: 6) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(image.zone.title)
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(RaverTheme.primaryText)
                                        .lineLimit(1)
                                    Text(image.fileName)
                                        .font(.caption2)
                                        .foregroundStyle(RaverTheme.secondaryText)
                                        .lineLimit(1)
                                }
                                Spacer(minLength: 0)
                                Image(systemName: selectedImageIDs.contains(image.id) ? "checkmark.circle.fill" : "circle")
                                    .font(.headline)
                                    .foregroundStyle(selectedImageIDs.contains(image.id) ? RaverTheme.accent : RaverTheme.secondaryText)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(8)
                        .background(RaverTheme.card, in: shape)
                        .overlay(
                            shape
                                .stroke(selectedImageIDs.contains(image.id) ? RaverTheme.accent : RaverTheme.cardBorder, lineWidth: selectedImageIDs.contains(image.id) ? 2 : 1)
                        )
                        .overlay(alignment: .topTrailing) {
                            if aiRecognitionCanPreview(image) {
                                aiRecognitionPreviewOverlayButton {
                                    previewPresentation = aiRecognitionPreviewPresentation(images: images, focusedImageID: image.id)
                                }
                            }
                        }
                        .clipShape(shape)
                        .contentShape(shape)
                        .onTapGesture {
                            toggleImageSelection(image.id)
                        }
                    }
                }
            }
        }
    }

    private var statusSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            if hasActiveRecognitionTasks || isAutoMatching {
                TimelineView(.periodic(from: Date(), by: 1)) { timeline in
                    HStack(spacing: 10) {
                        AIThinkingIndicator()
                        Spacer()
                        Text(elapsedText(since: statusElapsedStart, now: timeline.date))
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(RaverTheme.secondaryText)
                    }
                }
            }
            Text(statusMessage)
                .font(.caption.weight(.semibold))
                .foregroundStyle(statusIsError ? Color.red : RaverTheme.secondaryText)
                .frame(maxWidth: .infinity, alignment: .leading)
            if hasUnresolvedEventDayResults {
                Text(
                    LT(
                        "有 \(unresolvedEventDayResultCount) 条结果的日期仍有歧义。请先用“更换日期”或结果卡片里的日期信息确认到具体 event day，再执行确认添加。",
                        "\(unresolvedEventDayResultCount) results still have ambiguous dates. Confirm each one against a concrete event day before applying.",
                        "\(unresolvedEventDayResultCount)件の結果で日付がまだ曖昧です。適用前に具体的な event day へ確認してください。"
                    )
                )
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.orange)
            }
            if !warnings.isEmpty || !unparsedTexts.isEmpty {
                recognitionNoticeSection
            }
        }
        .padding(12)
        .background(RaverTheme.card, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(statusIsError ? Color.red.opacity(0.45) : RaverTheme.cardBorder, lineWidth: 1)
        )
    }

    private var recognitionNoticeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.bubble.fill")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.orange)
                Text(LT("识别提示", "Recognition Notes", "認識メモ"))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(RaverTheme.primaryText)
                Spacer()
                if canExpandRecognitionNotices {
                    Button {
                        warningsExpanded.toggle()
                    } label: {
                        Text(
                            warningsExpanded
                                ? LT("收起", "Collapse", "折りたたむ")
                                : LT("展开", "Expand", "展開")
                        )
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(RaverTheme.accent)
                    }
                    .buttonStyle(.plain)
                }
            }

            ForEach(displayedRecognitionWarnings, id: \.self) { warning in
                Text(warning)
                    .font(.caption2)
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if !displayedUnparsedTexts.isEmpty {
                Text(LT("未解析文本：", "Unparsed text:", "未解析テキスト：") + displayedUnparsedTexts.joined(separator: " / "))
                    .font(.caption2)
                    .foregroundStyle(RaverTheme.secondaryText)
                    .lineLimit(warningsExpanded ? nil : 2)
            }

            if !warningsExpanded && hiddenRecognitionNoticeCount > 0 {
                Text(
                    LT(
                        "还有 \(hiddenRecognitionNoticeCount) 条内容，点击展开查看。",
                        "\(hiddenRecognitionNoticeCount) more items. Tap expand to view.",
                        "あと\(hiddenRecognitionNoticeCount)件あります。展開して確認してください。"
                    )
                )
                .font(.caption2.weight(.semibold))
                .foregroundStyle(RaverTheme.secondaryText)
            }
        }
        .padding(10)
        .background(RaverTheme.background, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var taskStatusSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(LT("任务状态", "Task Status", "タスク状態"))
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(RaverTheme.primaryText)
                Spacer()
                if hasActiveRecognitionTasks {
                    Button {
                        Task { await cancelAllRecognitionTasks() }
                    } label: {
                        Label(LT("取消全部", "Cancel All", "すべてキャンセル"), systemImage: "xmark.circle")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.red)
                    }
                    .buttonStyle(.plain)
                }
            }

            ForEach(taskEntries) { entry in
                taskCard(entry)
            }
        }
    }

    private func taskCard(_ entry: RecognitionTaskEntry) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                timetableAIImagePreview(entry.image)
                    .overlay(alignment: .topTrailing) {
                        if aiRecognitionCanPreview(entry.image) {
                            aiRecognitionPreviewOverlayButton {
                                previewPresentation = aiRecognitionPreviewPresentation(images: images, focusedImageID: entry.image.id)
                            }
                        }
                    }
                    .frame(width: 88, height: 72)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .clipped()

                VStack(alignment: .leading, spacing: 4) {
                    Text(entry.image.fileName)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(RaverTheme.primaryText)
                        .lineLimit(1)
                    Text(taskPhaseText(entry.phase))
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(taskPhaseTint(entry.phase))
                    Text(entry.message)
                        .font(.caption2)
                        .foregroundStyle(RaverTheme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)

                VStack(alignment: .trailing, spacing: 6) {
                    TimelineView(.periodic(from: Date(), by: 1)) { timeline in
                        Text(elapsedText(since: entry.startedAt, now: timeline.date))
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(RaverTheme.secondaryText)
                    }
                    if !entry.phase.isTerminal {
                        Button {
                            Task { await cancelRecognitionTask(entry.id) }
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.headline)
                                .foregroundStyle(.red)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            HStack(spacing: 10) {
                if let jobId = entry.jobId, !jobId.isEmpty {
                    infoChip(title: "Job", value: String(jobId.prefix(8)))
                }
                if entry.slotCount > 0 {
                    infoChip(title: LT("结果", "Result", "結果"), value: "\(entry.slotCount)")
                }
                if entry.warningCount > 0 {
                    infoChip(title: LT("警告", "Warnings", "警告"), value: "\(entry.warningCount)")
                }
            }
        }
        .padding(12)
        .background(RaverTheme.card, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(taskPhaseTint(entry.phase).opacity(0.28), lineWidth: 1)
        )
    }

    private func infoChip(title: String, value: String) -> some View {
        HStack(spacing: 4) {
            Text(title)
            Text(value)
        }
        .font(.caption2.weight(.semibold))
        .foregroundStyle(RaverTheme.secondaryText)
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(RaverTheme.background, in: Capsule())
    }

    private func toggleImageSelection(_ imageID: UUID) {
        if selectedImageIDs.contains(imageID) {
            selectedImageIDs.remove(imageID)
        } else {
            selectedImageIDs.insert(imageID)
        }
    }

    private func runRecognition() async {
        let activeImageIDs = Set(taskEntries.filter { !$0.phase.isTerminal }.map(\.image.id))
        let launchImages = selectedImages.filter { !activeImageIDs.contains($0.id) }
        guard !launchImages.isEmpty else {
            statusIsError = true
            statusMessage = LT("请选择至少一张未在识别中的图片。", "Select at least one image that is not already running.", "まだ認識中ではない画像を1枚以上選択してください。")
            return
        }

        statusIsError = false
        statusMessage = launchImages.count > 1
            ? LT("已开始 \(launchImages.count) 个时间表识别任务，结果会逐个追加到下方。", "Started \(launchImages.count) timetable jobs. Results will be appended one by one.", "\(launchImages.count)件のタイムテーブル認識を開始しました。結果は順次追加されます。")
            : LT("已提交识别任务，AI 正在分析时间表。结果返回后会自动匹配 DJ 并追加到下方。", "Recognition task submitted. The result will auto-match DJs and append below.", "認識タスクを送信しました。結果はDJ自動紐付け後に下へ追加されます。")

        for image in launchImages {
            startRecognitionTask(for: image)
        }
    }

    private func startRecognitionTask(for image: EventUploadImageDraft) {
        let entryID = UUID()
        taskEntries.insert(
            RecognitionTaskEntry(
                id: entryID,
                image: image,
                jobId: nil,
                phase: .preparing,
                startedAt: Date(),
                updatedAt: Date(),
                slotCount: 0,
                warningCount: 0,
                message: LT("准备上传并创建识别任务。", "Preparing image upload and job creation.", "画像アップロードとジョブ作成を準備しています。")
            ),
            at: 0
        )

        let handle = Task {
            do {
                let createdJob = try await viewModel.createTimetableAIImportJob(for: image)
                await MainActor.run {
                    updateTask(
                        entryID,
                        phase: .polling(createdJob.status),
                        jobId: createdJob.jobId,
                        message: LT("识别任务已创建，正在轮询 Coze 状态。", "Job created. Polling Coze status now.", "認識ジョブを作成しました。Coze状態をポーリングしています。")
                    )
                }

                let response = try await waitForTimetableTask(entryID: entryID, jobId: createdJob.jobId)
                await MainActor.run {
                    updateTask(
                        entryID,
                        phase: .autoMatching,
                        message: LT("识别完成，正在自动匹配 DJ 库。", "Recognition finished. Auto-matching DJs now.", "認識完了。DJライブラリを自動紐付けしています。")
                    )
                }

                let parsed = viewModel.editableTimetableImportResult(from: response)
                let matched = await viewModel.autoMatchTimetableAIImportSlots(parsed.slots)

                await MainActor.run {
                    appendRecognitionResult(slots: matched, warnings: parsed.warnings, unparsedTexts: parsed.unparsedTexts)
                    updateTask(
                        entryID,
                        phase: .succeeded,
                        slotCount: matched.count,
                        warningCount: parsed.warnings.count,
                        message: matched.isEmpty
                            ? LT("任务完成，但没有可用节目结果。", "Task completed but returned no usable slots.", "タスクは完了しましたが、有効な出演結果はありませんでした。")
                            : LT("任务完成，\(matched.count) 条结果已追加到下方。", "Task completed. \(matched.count) results appended below.", "タスク完了。\(matched.count)件の結果を下に追加しました。")
                    )
                    statusIsError = false
                    statusMessage = LT("新结果已追加到当前时间表识别列表。你可以继续选择更多图片再跑新任务。", "New results were appended. You can keep selecting more images and launch more jobs.", "新しい結果を追加しました。さらに画像を選んで新しいジョブを続けて開始できます。")
                }
            } catch is CancellationError {
                await MainActor.run {
                    updateTask(
                        entryID,
                        phase: .cancelled,
                        message: LT("已取消该识别任务。", "This recognition task was cancelled.", "この認識タスクをキャンセルしました。")
                    )
                    statusIsError = false
                    statusMessage = LT("已取消一个识别任务。", "Cancelled one recognition task.", "認識タスクを1件キャンセルしました。")
                }
            } catch {
                await MainActor.run {
                    updateTask(
                        entryID,
                        phase: .failed,
                        message: error.userFacingMessage ?? LT("时间表识别失败，请稍后重试。", "Timetable recognition failed. Please try again later.", "タイムテーブル認識に失敗しました。しばらくしてから再試行してください。")
                    )
                    statusIsError = true
                    statusMessage = error.userFacingMessage ?? LT("有一个时间表识别任务失败了，请检查任务状态后重试。", "One timetable task failed. Check the task status and retry.", "タイムテーブル認識タスクが1件失敗しました。状態を確認して再試行してください。")
                }
            }

            await MainActor.run {
                taskHandles[entryID] = nil
            }
        }

        taskHandles[entryID] = handle
    }

    private func waitForTimetableTask(entryID: UUID, jobId: String) async throws -> EventTimetableImageImportResponse {
        let deadline = Date().addingTimeInterval(10 * 60)
        while Date() < deadline {
            try Task.checkCancellation()
            let job = try await viewModel.fetchTimetableAIImportJob(id: jobId)
            await MainActor.run {
                updateTask(
                    entryID,
                    phase: .polling(job.status),
                    message: taskPollingMessage(for: job.status)
                )
            }

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

    private func cancelRecognitionTask(_ entryID: UUID) async {
        let handle = taskHandles[entryID]
        let jobId = taskEntries.first(where: { $0.id == entryID })?.jobId
        handle?.cancel()
        if let jobId, !jobId.isEmpty {
            try? await viewModel.cancelTimetableAIImportJob(id: jobId)
        }
        await MainActor.run {
            updateTask(
                entryID,
                phase: .cancelled,
                message: LT("已取消该识别任务。", "This recognition task was cancelled.", "この認識タスクをキャンセルしました。")
            )
            taskHandles[entryID] = nil
        }
    }

    private func cancelAllRecognitionTasks() async {
        let activeIDs = taskEntries.filter { !$0.phase.isTerminal }.map(\.id)
        for id in activeIDs {
            await cancelRecognitionTask(id)
        }
    }

    private func updateTask(
        _ entryID: UUID,
        phase: RecognitionTaskEntry.Phase,
        jobId: String? = nil,
        slotCount: Int? = nil,
        warningCount: Int? = nil,
        message: String
    ) {
        guard let index = taskEntries.firstIndex(where: { $0.id == entryID }) else { return }
        taskEntries[index].phase = phase
        taskEntries[index].updatedAt = Date()
        if let jobId {
            taskEntries[index].jobId = jobId
        }
        if let slotCount {
            taskEntries[index].slotCount = slotCount
        }
        if let warningCount {
            taskEntries[index].warningCount = warningCount
        }
        taskEntries[index].message = message
    }

    private func taskPollingMessage(for status: String) -> String {
        switch status.lowercased() {
        case "queued", "pending":
            return LT("任务已排队，等待 Coze 开始处理。", "Queued and waiting for Coze to start processing.", "ジョブはキュー待ちで、Cozeの処理開始を待っています。")
        case "running", "processing":
            return LT("AI 正在识别这张时间表。", "AI is actively recognizing this timetable image.", "AIがこのタイムテーブル画像を認識中です。")
        case "succeeded":
            return LT("识别完成，正在整理结果。", "Recognition finished. Preparing the result.", "認識が完了し、結果を整理しています。")
        case "failed":
            return LT("识别失败。", "Recognition failed.", "認識に失敗しました。")
        case "cancelled":
            return LT("识别已取消。", "Recognition was cancelled.", "認識はキャンセルされました。")
        default:
            return LT("正在轮询识别状态。", "Polling recognition status.", "認識状態をポーリングしています。")
        }
    }

    private func taskPhaseText(_ phase: RecognitionTaskEntry.Phase) -> String {
        switch phase {
        case .preparing:
            return LT("准备中", "Preparing", "準備中")
        case .submitted:
            return LT("已提交", "Submitted", "送信済み")
        case .polling(let status):
            switch status.lowercased() {
            case "queued", "pending":
                return LT("排队中", "Queued", "待機中")
            case "running", "processing":
                return LT("识别中", "Recognizing", "認識中")
            case "succeeded":
                return LT("整理结果", "Finalizing", "結果整理中")
            default:
                return LT("轮询中", "Polling", "ポーリング中")
            }
        case .autoMatching:
            return LT("自动匹配 DJ", "Auto Matching DJs", "DJ自動紐付け")
        case .succeeded:
            return LT("已完成", "Completed", "完了")
        case .failed:
            return LT("失败", "Failed", "失敗")
        case .cancelled:
            return LT("已取消", "Cancelled", "キャンセル済み")
        }
    }

    private func taskPhaseTint(_ phase: RecognitionTaskEntry.Phase) -> Color {
        switch phase {
        case .succeeded:
            return .green
        case .failed, .cancelled:
            return .red
        case .autoMatching:
            return .orange
        default:
            return RaverTheme.accent
        }
    }

    private func appendRecognitionResult(
        slots: [EventUploadTimetableAIEditableSlot],
        warnings nextWarnings: [String],
        unparsedTexts nextUnparsedTexts: [String]
    ) {
        guard !slots.isEmpty || !nextWarnings.isEmpty || !nextUnparsedTexts.isEmpty else { return }
        resultSlots.append(contentsOf: slots)
        for warning in nextWarnings where !warnings.contains(warning) {
            warnings.append(warning)
        }
        for text in nextUnparsedTexts where !unparsedTexts.contains(text) {
            unparsedTexts.append(text)
        }
        refreshResultFilters(preserveSelection: true)
    }

    private var filterSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            filterRow(
                title: "Week",
                values: availableWeeks,
                selectedValue: Binding(
                    get: { selectedWeekIndex },
                    set: { value in
                        selectedWeekIndex = value
                        syncAIResultScope()
                    }
                ),
                label: { "Week \($0)" },
                value: { $0 }
            )

            filterRow(
                title: LT("Day", "Day", "Day"),
                values: availableDays,
                selectedValue: Binding(
                    get: { selectedEventDayIdentity },
                    set: { value in
                        selectedEventDayIdentity = value
                        syncAIResultScope()
                    }
                ),
                label: { dayFilterLabel(for: $0) },
                value: { eventDayIdentity(for: $0) }
            )

            filterRow(
                title: LT("舞台", "Stage", "ステージ"),
                values: availableStages,
                selectedValue: Binding(
                    get: { selectedStageName },
                    set: { value in
                        selectedStageName = value
                        syncAIResultScope()
                    }
                ),
                label: { $0 },
                value: { $0 }
            )
        }
        .padding(12)
        .background(RaverTheme.card, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(RaverTheme.cardBorder, lineWidth: 1)
        )
    }

    @ViewBuilder
    private func timetableAIImagePreview(_ image: EventUploadImageDraft) -> some View {
        aiRecognitionThumbnail(image)
    }

    private var availableWeeks: [Int] {
        Array(Set(resultSlots.map(\.weekIndex))).sorted()
    }

    private var availableDays: [EventUploadTimetableAIEditableSlot] {
        filteredByWeek
            .reduce(into: [String: EventUploadTimetableAIEditableSlot]()) { dict, slot in
                let identity = eventDayIdentity(for: slot)
                if dict[identity] == nil {
                    dict[identity] = slot
                }
            }
            .values
            .sorted {
                if $0.overallDayIndex != $1.overallDayIndex { return $0.overallDayIndex < $1.overallDayIndex }
                return dayFilterLabel(for: $0) < dayFilterLabel(for: $1)
            }
    }

    private var availableMoveDays: [EventUploadTimetableAIEditableSlot] {
        let timeZone = TimeZone(identifier: viewModel.draft.timeZoneIdentifier) ?? .current
        let baseDays = viewModel.draft.structuredEventDays
            .filter { selectedWeekIndex == nil || $0.weekIndex == selectedWeekIndex }
            .map { eventDay in
                EventUploadTimetableAIEditableSlot(
                    eventDayId: eventDay.eventDayId,
                    weekIndex: eventDay.weekIndex,
                    dayIndexInWeek: eventDay.dayIndexInWeek,
                    overallDayIndex: eventDay.overallDayIndex,
                    localDate: eventDay.date.eventArchiveDateText(in: timeZone),
                    dayLabel: eventDay.label?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
                        ? (eventDay.label ?? "")
                        : eventDay.date.eventArchiveDateText(in: timeZone),
                    stageName: "",
                    actType: .solo,
                    performerNamesText: "",
                    startTimeText: "",
                    endTimeText: "",
                    notes: []
                )
            }
        return baseDays.isEmpty ? availableDays : baseDays
    }

    private var availableStages: [String] {
        let values = filteredByWeekAndDay.map { $0.stageName.trimmingCharacters(in: .whitespacesAndNewlines) }
        return Array(Set(values.filter { !$0.isEmpty })).sorted()
    }

    private var availableStageMoveOptions: [String] {
        let values = filteredByWeek.map { $0.stageName.trimmingCharacters(in: .whitespacesAndNewlines) }
        return Array(Set(values.filter { !$0.isEmpty })).sorted()
    }

    private var filteredByWeek: [EventUploadTimetableAIEditableSlot] {
        guard let selectedWeekIndex else { return resultSlots }
        return resultSlots.filter { $0.weekIndex == selectedWeekIndex }
    }

    private var filteredByWeekAndDay: [EventUploadTimetableAIEditableSlot] {
        filteredByWeek.filter { selectedEventDayIdentity == nil || eventDayIdentity(for: $0) == selectedEventDayIdentity }
    }

    private var visibleSlots: [EventUploadTimetableAIEditableSlot] {
        filteredByWeekAndDay.filter { slot in
            guard let selectedStageName else { return true }
            return slot.stageName.trimmingCharacters(in: .whitespacesAndNewlines) == selectedStageName
        }
    }

    private var unresolvedEventDayResultCount: Int {
        resultSlots.filter { slot in
            let eventDayId = slot.eventDayId?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard !eventDayId.isEmpty else { return true }
            return viewModel.draft.eventDay(forID: eventDayId) == nil
        }.count
    }

    private var hasUnresolvedEventDayResults: Bool {
        unresolvedEventDayResultCount > 0
    }

    private var visibleResultCleanupCandidateCount: Int {
        visibleSlots.reduce(into: 0) { count, slot in
            let cleaned = cleanedAIImportSlot(slot)
            if cleaned == nil || cleaned! != slot {
                count += 1
            }
        }
    }

    private var displayedRecognitionWarnings: [String] {
        warningsExpanded ? warnings : Array(warnings.prefix(3))
    }

    private var displayedUnparsedTexts: [String] {
        warningsExpanded ? unparsedTexts : Array(unparsedTexts.prefix(2))
    }

    private var hiddenRecognitionNoticeCount: Int {
        let hiddenWarnings = max(0, warnings.count - displayedRecognitionWarnings.count)
        let hiddenUnparsed = max(0, unparsedTexts.count - displayedUnparsedTexts.count)
        return hiddenWarnings + hiddenUnparsed
    }

    private var canExpandRecognitionNotices: Bool {
        hiddenRecognitionNoticeCount > 0 || warningsExpanded
    }

    private func configureResultFilters() {
        refreshResultFilters(preserveSelection: false)
    }

    private func refreshResultFilters(preserveSelection: Bool) {
        if !preserveSelection || selectedWeekIndex == nil {
            selectedWeekIndex = availableWeeks.first
        }
        syncAIResultScope()
        if !preserveSelection || selectedEventDayIdentity == nil {
            selectedEventDayIdentity = availableDays.first.map(eventDayIdentity(for:))
        }
        syncAIResultScope()
        if !preserveSelection || selectedStageName == nil {
            selectedStageName = availableStages.first
        }
        syncAIResultScope()
        expandedSlotIDs = expandedSlotIDs.intersection(Set(resultSlots.map(\.id)))
    }

    private func syncAIResultScope() {
        if let selectedWeekIndex, !availableWeeks.contains(selectedWeekIndex) {
            self.selectedWeekIndex = availableWeeks.first
        }
        if let selectedEventDayIdentity,
           !availableDays.contains(where: { eventDayIdentity(for: $0) == selectedEventDayIdentity }) {
            self.selectedEventDayIdentity = availableDays.first.map(eventDayIdentity(for:))
        }
        if let selectedStageName, !availableStages.contains(selectedStageName) {
            self.selectedStageName = availableStages.first
        }
        selectedResultSlotIDs = selectedResultSlotIDs.intersection(Set(resultSlots.map(\.id)))
        if selectedResultSlotIDs.isEmpty {
            moveResultDayDialogPresented = false
            moveResultStageDialogPresented = false
        }
    }

    private func dayLabel(for slot: EventUploadTimetableAIEditableSlot) -> String {
        if let eventDay = resolvedDisplayEventDay(for: slot) {
            let trimmed = eventDay.label?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if !trimmed.isEmpty {
                return trimmed
            }
            return EventWeekScheduleMode.weekDayTitle(week: eventDay.weekIndex, day: eventDay.dayIndexInWeek)
        }
        let trimmed = slot.dayLabel.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            return trimmed
        }
        return EventWeekScheduleMode.weekDayTitle(week: slot.weekIndex, day: slot.dayIndexInWeek)
    }

    private func eventDayIdentity(for slot: EventUploadTimetableAIEditableSlot) -> String {
        let eventDayId = slot.eventDayId?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !eventDayId.isEmpty {
            return eventDayId
        }
        return "\(slot.weekIndex)-\(slot.dayIndexInWeek)-\(normalizedLocalDateText(for: slot) ?? "")"
    }

    private func normalizedLocalDateText(for slot: EventUploadTimetableAIEditableSlot) -> String? {
        if let eventDay = resolvedDisplayEventDay(for: slot) {
            let timeZone = TimeZone(identifier: viewModel.draft.timeZoneIdentifier) ?? .current
            return eventDay.date.eventArchiveDateText(in: timeZone)
        }
        let trimmed = slot.localDate?.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed?.isEmpty == false ? trimmed : nil
    }

    private func dayFilterLabel(for slot: EventUploadTimetableAIEditableSlot) -> String {
        let base = dayLabel(for: slot)
        guard let localDate = normalizedLocalDateText(for: slot), !base.contains(localDate) else {
            return base
        }
        return "\(base) · \(localDate)"
    }

    private func resolvedDisplayEventDay(for slot: EventUploadTimetableAIEditableSlot) -> WebEventDay? {
        if let eventDay = viewModel.draft.eventDay(forID: slot.eventDayId) {
            return eventDay
        }
        return viewModel.draft.eventDay(forOverallDayIndex: max(slot.overallDayIndex, 1))
    }

    private func filterRow<Item: Hashable, Selection: Hashable>(
        title: String,
        values: [Item],
        selectedValue: Binding<Selection?>,
        label: @escaping (Item) -> String,
        value: @escaping (Item) -> Selection
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(RaverTheme.secondaryText)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(values, id: \.self) { item in
                        let itemValue = value(item)
                        Button {
                            selectedValue.wrappedValue = itemValue
                        } label: {
                            Text(label(item))
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(selectedValue.wrappedValue == itemValue ? .white : RaverTheme.primaryText)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                .background(
                                    selectedValue.wrappedValue == itemValue ? RaverTheme.accent : RaverTheme.card,
                                    in: Capsule()
                                )
                                .overlay(
                                    Capsule()
                                        .stroke(selectedValue.wrappedValue == itemValue ? Color.clear : RaverTheme.cardBorder, lineWidth: 1)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var resultSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(LT("节目列表", "Set List", "セット一覧"))
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(RaverTheme.primaryText)
                Spacer()
	                if isResultSelectionMode {
	                    Button {
	                        moveResultDayDialogPresented = true
                    } label: {
                        Text(LT("更换日期", "Change Day", "日付変更"))
                            .font(.caption.weight(.bold))
                            .foregroundStyle(selectedResultSlotIDs.isEmpty ? RaverTheme.secondaryText : .white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(selectedResultSlotIDs.isEmpty ? RaverTheme.card : RaverTheme.accent, in: Capsule())
	                    }
	                    .buttonStyle(.plain)
	                    .disabled(selectedResultSlotIDs.isEmpty)
	                    if !availableStageMoveOptions.isEmpty {
	                        Button {
	                            moveResultStageDialogPresented = true
	                        } label: {
	                            Text(LT("更换舞台", "Change Stage", "ステージ変更"))
	                                .font(.caption.weight(.bold))
	                                .foregroundStyle(selectedResultSlotIDs.isEmpty ? RaverTheme.secondaryText : .white)
	                                .padding(.horizontal, 10)
	                                .padding(.vertical, 6)
	                                .background(selectedResultSlotIDs.isEmpty ? RaverTheme.card : RaverTheme.accent, in: Capsule())
	                        }
	                        .buttonStyle(.plain)
	                        .disabled(selectedResultSlotIDs.isEmpty)
	                    }
	                }
                Button {
                    toggleResultSelectionMode()
                } label: {
                    Text(isResultSelectionMode ? LT("完成", "Done", "完了") : LT("多选", "Select", "複数選択"))
                        .font(.caption.weight(.bold))
                        .foregroundStyle(isResultSelectionMode ? .white : RaverTheme.primaryText)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(isResultSelectionMode ? RaverTheme.accent : RaverTheme.card, in: Capsule())
                }
                .buttonStyle(.plain)
                Text(LT("共 \(resultSlots.count) 条", "\(resultSlots.count) items", "\(resultSlots.count)件"))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(RaverTheme.secondaryText)
            }

            HStack(spacing: 10) {
                Button {
                    Task { await autoMatchCurrentSlots() }
                } label: {
                    Label(LT("一键匹配当前列表中的 DJ", "Auto match DJs in current list", "現在のリストのDJを一括紐付け"), systemImage: "wand.and.stars")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            LinearGradient(
                                colors: [.cyan, .blue, .purple, .pink],
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            in: Capsule()
                        )
                }
                .buttonStyle(.plain)
                .disabled(hasActiveRecognitionTasks || isAutoMatching || resultSlots.isEmpty)

                if visibleResultCleanupCandidateCount > 0 {
                    Button {
                        cleanupVisibleResultSlots()
                    } label: {
                        Label(
                            LT("一键清理空值", "Clean Empty Names", "空欄を一括整理"),
                            systemImage: "sparkles"
                        )
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.orange)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.orange.opacity(0.12), in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }

            if visibleSlots.isEmpty {
                Text(LT("当前筛选下没有结果。", "No results in the current filter.", "現在の絞り込み条件では結果がありません。"))
                    .font(.caption)
                    .foregroundStyle(RaverTheme.secondaryText)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RaverTheme.background, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            } else {
                VStack(spacing: 12) {
                    ForEach(Array(visibleSlots.enumerated()), id: \.element.id) { index, slot in
                        timetableAIResultCard(slot, order: index + 1)
                    }
                }
            }
        }
    }

    private func timetableAIResultCard(_ slot: EventUploadTimetableAIEditableSlot, order: Int) -> some View {
        let expanded = !isResultSelectionMode && expandedSlotIDs.contains(slot.id)
        let performerNames = timetableAIPerformerNames(for: slot)
        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                if isResultSelectionMode {
                    Image(systemName: selectedResultSlotIDs.contains(slot.id) ? "checkmark.circle.fill" : "circle")
                        .font(.headline)
                        .foregroundStyle(selectedResultSlotIDs.contains(slot.id) ? RaverTheme.accent : RaverTheme.secondaryText)
                }

                Text("\(order)")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(RaverTheme.secondaryText)
                    .frame(width: 18, alignment: .leading)

                performerAvatarStack(slot: slot, performerNames: performerNames)

                VStack(alignment: .leading, spacing: 3) {
                    Text(displayName(for: slot))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(RaverTheme.primaryText)
                        .lineLimit(1)
                    Text(timeSummary(for: slot))
                        .font(.caption2)
                        .foregroundStyle(RaverTheme.accent)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if !isResultSelectionMode {
                    Button {
                        expandedSlotIDs.formSymmetricDifference([slot.id])
                    } label: {
                        Image(systemName: expanded ? "chevron.up" : "square.and.pencil")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(expanded ? RaverTheme.accent : RaverTheme.secondaryText)
                            .frame(width: 30, height: 30)
                            .background(RaverTheme.background, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                    .buttonStyle(.plain)

                    Button {
                        resultSlots.removeAll { $0.id == slot.id }
                        refreshResultFilters(preserveSelection: true)
                    } label: {
                        Image(systemName: "trash")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.red)
                            .frame(width: 28, height: 28)
                            .background(RaverTheme.background, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }

            if expanded {
                Picker(LT("演出形式", "Act Type", "出演形式"), selection: binding(for: slot.id, keyPath: \.actType, default: .solo)) {
                    ForEach(EventLineupActType.allCases) { type in
                        Text(type.title).tag(type)
                    }
                }
                .pickerStyle(.segmented)

                ForEach(0..<slot.actType.performerCount, id: \.self) { index in
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 10) {
                            performerAvatar(
                                name: aiImportPerformerName(for: slot, performerIndex: index),
                                avatarURL: aiImportPerformerAvatarURL(for: slot, performerIndex: index),
                                index: index
                            )
                            VStack(alignment: .leading, spacing: 3) {
                                Text(slot.actType == .solo ? LT("DJ / 艺人名称", "Artist / DJ Name", "DJ / アーティスト名") : LT("成员 \(index + 1)", "Member \(index + 1)", "メンバー \(index + 1)"))
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(RaverTheme.secondaryText)
                                Text(aiImportBindingState(for: slot, performerIndex: index))
                                    .font(.caption2)
                                    .foregroundStyle(RaverTheme.secondaryText)
                            }
                            Spacer()
                            if aiImportIsBound(slot, performerIndex: index) {
                                Image(systemName: "checkmark.seal.fill")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(.green)
                            }
                        }

                        aiImportDJSearchTextField(
                            title: slot.actType == .solo ? LT("输入 DJ / 艺人名称", "Enter artist / DJ name", "DJ / アーティスト名を入力") : LT("输入成员名称", "Enter member name", "メンバー名を入力"),
                            text: aiImportPerformerNameBinding(slotID: slot.id, performerIndex: index),
                            isSearching: viewModel.aiImportSearchingDJKeys.contains(aiImportSearchKey(slotID: slot.id, performerIndex: index)),
                            canClear: aiImportCanClear(slot, performerIndex: index),
                            clearAction: {
                                aiImportClearDJBinding(slotID: slot.id, performerIndex: index)
                            },
                            action: {
                                Task {
                                    await viewModel.searchTimetableAIImportDJ(
                                        query: aiImportPerformerName(for: slot, performerIndex: index),
                                        key: aiImportSearchKey(slotID: slot.id, performerIndex: index),
                                        useInlineFeedback: true
                                    )
                                }
                            }
                        )

                        aiImportDJSearchSection(slotID: slot.id, performerIndex: index)
                    }
                    .padding(12)
                    .background(RaverTheme.background, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }

                HStack(spacing: 8) {
                    aiImportTimeColumn(
                        title: LT("开始", "Start", "開始"),
                        dayOffset: binding(for: slot.id, keyPath: \.startDayOffset, default: .sameDay),
                        text: binding(for: slot.id, keyPath: \.startTimeText, default: "")
                    )
                    aiImportTimeColumn(
                        title: LT("结束", "End", "終了"),
                        dayOffset: binding(for: slot.id, keyPath: \.endDayOffset, default: .sameDay),
                        text: binding(for: slot.id, keyPath: \.endTimeText, default: "")
                    )
                }

                HStack {
                    Text(dayFilterLabel(for: slot))
                    Spacer()
                    if let confidence = slot.confidence {
                        Text("\(Int(confidence * 100))%")
                    }
                }
                .font(.caption2)
                .foregroundStyle(RaverTheme.secondaryText)

                HStack {
                    Spacer()
                    Button {
                        expandedSlotIDs.remove(slot.id)
                    } label: {
                        Label(LT("确认", "Confirm", "確認"), systemImage: "checkmark")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 9)
                            .background(RaverTheme.accent, in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(14)
        .background(RaverTheme.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(selectedResultSlotIDs.contains(slot.id) ? RaverTheme.accent : RaverTheme.cardBorder, lineWidth: selectedResultSlotIDs.contains(slot.id) ? 2 : 1)
        )
        .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .onTapGesture {
            if isResultSelectionMode {
                toggleResultSlotSelection(slot.id)
            }
        }
    }

    private func toggleResultSelectionMode() {
        isResultSelectionMode.toggle()
        if !isResultSelectionMode {
            selectedResultSlotIDs.removeAll()
        }
    }

    private func toggleResultSlotSelection(_ slotID: UUID) {
        if selectedResultSlotIDs.contains(slotID) {
            selectedResultSlotIDs.remove(slotID)
        } else {
            selectedResultSlotIDs.insert(slotID)
        }
    }

    private func moveSelectedResultSlots(to day: EventUploadTimetableAIEditableSlot) {
        guard !selectedResultSlotIDs.isEmpty else { return }
        for index in resultSlots.indices where selectedResultSlotIDs.contains(resultSlots[index].id) {
            resultSlots[index].eventDayId = day.eventDayId
            resultSlots[index].weekIndex = day.weekIndex
            resultSlots[index].dayIndexInWeek = day.dayIndexInWeek
            resultSlots[index].overallDayIndex = day.overallDayIndex
            resultSlots[index].localDate = day.localDate
            resultSlots[index].dayLabel = day.dayLabel
        }
        selectedEventDayIdentity = eventDayIdentity(for: day)
        selectedResultSlotIDs.removeAll()
        isResultSelectionMode = false
        refreshResultFilters(preserveSelection: true)
    }

    private func moveSelectedResultSlots(toStage stage: String) {
        let normalizedStage = stage.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !selectedResultSlotIDs.isEmpty, !normalizedStage.isEmpty else { return }
        for index in resultSlots.indices where selectedResultSlotIDs.contains(resultSlots[index].id) {
            resultSlots[index].stageName = normalizedStage
        }
        selectedStageName = normalizedStage
        selectedResultSlotIDs.removeAll()
        isResultSelectionMode = false
        refreshResultFilters(preserveSelection: true)
    }

    private func dismissKeyboard() {
#if canImport(UIKit)
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
#endif
    }

    private func performerAvatarStack(slot: EventUploadTimetableAIEditableSlot, performerNames: [String]) -> some View {
        HStack(spacing: -10) {
            ForEach(Array(performerNames.prefix(slot.actType.performerCount).enumerated()), id: \.offset) { index, name in
                performerAvatar(
                    name: name,
                    avatarURL: slot.performerAvatarURLs.indices.contains(index) ? slot.performerAvatarURLs[index] : nil,
                    index: index
                )
            }
        }
        .padding(.trailing, 8)
    }

    private func performerAvatar(name: String, avatarURL: String?, index: Int) -> some View {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return Group {
            if let avatarURL,
               let resolved = AppConfig.resolvedDJAvatarURLString(avatarURL, size: .small),
               !resolved.isEmpty {
                AsyncImage(url: URL(string: resolved)) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    default:
                        avatarFallback(trimmed: trimmed, index: index)
                    }
                }
            } else {
                avatarFallback(trimmed: trimmed, index: index)
            }
        }
        .frame(width: 32, height: 32)
        .clipShape(Circle())
        .overlay(
            Circle()
                .stroke(RaverTheme.card, lineWidth: 2)
        )
    }

    private func avatarFallback(trimmed: String, index: Int) -> some View {
        ZStack {
            Circle()
                .fill(index == 0 ? RaverTheme.accent.opacity(0.22) : RaverTheme.background)
            Text(String(trimmed.prefix(1)).uppercased())
                .font(.caption.weight(.bold))
                .foregroundStyle(index == 0 ? RaverTheme.accent : RaverTheme.secondaryText)
        }
    }

    private func timeSummary(start: String, end: String) -> String {
        guard let range = EventUploadTimeDisplay.clockRange(start: start, end: end) else {
            return LT("请填写演出时间", "Set start and end time", "出演時間を入力してください")
        }
        return range
    }

    private func timeSummary(for slot: EventUploadTimetableAIEditableSlot) -> String {
        let startText = slot.startTimeText.trimmingCharacters(in: .whitespacesAndNewlines)
        let endText = slot.endTimeText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !startText.isEmpty, !endText.isEmpty else {
            return LT("请填写演出时间", "Set start and end time", "出演時間を入力してください")
        }
        let start = slot.startDayOffset == .nextDay ? "\(24 + aiImportClockHour(startText)):\(aiImportClockMinuteText(startText))" : startText
        let end = slot.endDayOffset == .nextDay ? "\(24 + aiImportClockHour(endText)):\(aiImportClockMinuteText(endText))" : endText
        return timeSummary(start: start, end: end)
    }

    private func displayName(for slot: EventUploadTimetableAIEditableSlot) -> String {
        let names = timetableAIPerformerNames(for: slot)
        let composed = EventLineupActCodec.composeName(type: slot.actType, performerNames: names)
        return composed.isEmpty ? LT("未命名演出", "Untitled Act", "未命名の出演") : composed
    }

    private func timetableAIPerformerNames(for slot: EventUploadTimetableAIEditableSlot) -> [String] {
        slot.performerNamesText
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private func rawTimetableAIPerformerNames(for slot: EventUploadTimetableAIEditableSlot) -> [String] {
        slot.performerNamesText
            .split(separator: ",", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
    }

    private func aiImportPerformerName(for slot: EventUploadTimetableAIEditableSlot, performerIndex: Int) -> String {
        let names = timetableAIPerformerNames(for: slot)
        return names.indices.contains(performerIndex) ? names[performerIndex] : ""
    }

    private func aiImportPerformerAvatarURL(for slot: EventUploadTimetableAIEditableSlot, performerIndex: Int) -> String? {
        slot.performerAvatarURLs.indices.contains(performerIndex) ? slot.performerAvatarURLs[performerIndex] : nil
    }

    private func aiImportClockHour(_ text: String) -> Int {
        let parts = text.split(separator: ":", maxSplits: 1).map(String.init)
        return parts.first.flatMap { Int($0.trimmingCharacters(in: .whitespacesAndNewlines)) } ?? 0
    }

    private func aiImportClockMinuteText(_ text: String) -> String {
        let parts = text.split(separator: ":", maxSplits: 1).map(String.init)
        guard parts.count == 2,
              let minute = Int(parts[1].trimmingCharacters(in: .whitespacesAndNewlines))
        else { return "00" }
        return String(format: "%02d", min(max(minute, 0), 59))
    }

    private func aiImportTimeColumn(
        title: String,
        dayOffset: Binding<EventUploadSlotDayOffset>,
        text: Binding<String>
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(RaverTheme.secondaryText)

            Picker(title, selection: dayOffset) {
                ForEach(EventUploadSlotDayOffset.allCases) { option in
                    Text(option.title).tag(option)
                }
            }
            .pickerStyle(.segmented)

            TextField("HH:mm", text: text)
                .font(.body.monospacedDigit())
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(RaverTheme.background, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func aiImportSearchKey(slotID: UUID, performerIndex: Int) -> String {
        "ai-\(slotID.uuidString)-\(performerIndex)"
    }

    private func aiImportIsBound(_ slot: EventUploadTimetableAIEditableSlot, performerIndex: Int) -> Bool {
        slot.performerDJIDs.indices.contains(performerIndex)
            ? slot.performerDJIDs[performerIndex]?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            : false
    }

    private func aiImportBindingState(for slot: EventUploadTimetableAIEditableSlot, performerIndex: Int) -> String {
        aiImportIsBound(slot, performerIndex: performerIndex)
            ? LT("已绑定 DJ 词条", "Bound to DJ entry", "DJエントリ紐付け済み")
            : LT("可手填，也可绑定 DJ 库", "Manual or DJ binding", "手入力またはDJ紐付け")
    }

    private func aiImportCanClear(_ slot: EventUploadTimetableAIEditableSlot, performerIndex: Int) -> Bool {
        let nameFilled = !aiImportPerformerName(for: slot, performerIndex: performerIndex).trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return nameFilled || aiImportIsBound(slot, performerIndex: performerIndex)
    }

    private func aiImportPerformerNameBinding(slotID: UUID, performerIndex: Int) -> Binding<String> {
        Binding {
            guard let slot = resultSlots.first(where: { $0.id == slotID }) else { return "" }
            return aiImportPerformerName(for: slot, performerIndex: performerIndex)
        } set: { newValue in
            guard let index = resultSlots.firstIndex(where: { $0.id == slotID }) else { return }
            var names = timetableAIPerformerNames(for: resultSlots[index])
            while names.count <= performerIndex {
                names.append("")
            }
            names[performerIndex] = newValue
            resultSlots[index].performerNamesText = names.joined(separator: ", ")
            while resultSlots[index].performerDJIDs.count <= performerIndex {
                resultSlots[index].performerDJIDs.append(nil)
            }
            while resultSlots[index].performerAvatarURLs.count <= performerIndex {
                resultSlots[index].performerAvatarURLs.append(nil)
            }
            resultSlots[index].performerDJIDs[performerIndex] = nil
            resultSlots[index].performerAvatarURLs[performerIndex] = nil
            Task {
                await viewModel.searchTimetableAIImportDJ(
                    query: newValue,
                    key: aiImportSearchKey(slotID: slotID, performerIndex: performerIndex),
                    useInlineFeedback: true
                )
            }
        }
    }

    private func aiImportApplyDJBinding(_ dj: WebDJ, slotID: UUID, performerIndex: Int) {
        guard let index = resultSlots.firstIndex(where: { $0.id == slotID }) else { return }
        while resultSlots[index].performerDJIDs.count <= performerIndex {
            resultSlots[index].performerDJIDs.append(nil)
        }
        while resultSlots[index].performerAvatarURLs.count <= performerIndex {
            resultSlots[index].performerAvatarURLs.append(nil)
        }
        resultSlots[index].performerDJIDs[performerIndex] = dj.id
        resultSlots[index].performerAvatarURLs[performerIndex] = dj.avatarSmallUrl ?? dj.avatarMediumUrl ?? dj.avatarUrl ?? dj.avatarOriginalUrl
    }

    private func aiImportClearDJBinding(slotID: UUID, performerIndex: Int) {
        guard let index = resultSlots.firstIndex(where: { $0.id == slotID }) else { return }
        while resultSlots[index].performerDJIDs.count <= performerIndex {
            resultSlots[index].performerDJIDs.append(nil)
        }
        while resultSlots[index].performerAvatarURLs.count <= performerIndex {
            resultSlots[index].performerAvatarURLs.append(nil)
        }
        resultSlots[index].performerDJIDs[performerIndex] = nil
        resultSlots[index].performerAvatarURLs[performerIndex] = nil
    }

    private func aiImportDJSearchSection(slotID: UUID, performerIndex: Int) -> some View {
        let key = aiImportSearchKey(slotID: slotID, performerIndex: performerIndex)
        let results = viewModel.aiImportDJSearchResults[key] ?? []
        let feedback = viewModel.aiImportDJSearchFeedbacks[key] ?? .idle
        let isSearching = viewModel.aiImportSearchingDJKeys.contains(key)
        return aiImportDJSearchResultsList(results: results, feedback: feedback, isSearching: isSearching) { dj in
            aiImportApplyDJBinding(dj, slotID: slotID, performerIndex: performerIndex)
        }
    }

    private func aiImportDJSearchTextField(
        title: String,
        text: Binding<String>,
        isSearching: Bool,
        canClear: Bool,
        clearAction: @escaping () -> Void,
        action: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(RaverTheme.secondaryText)
            ZStack(alignment: .trailing) {
                TextField(title, text: text)
                    .font(.body)
                    .foregroundStyle(RaverTheme.primaryText)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .padding(.trailing, canClear ? 168 : 104)

                HStack(spacing: 6) {
                    if canClear {
                        Button(action: clearAction) {
                            Label(LT("清空", "Clear", "クリア"), systemImage: "xmark.circle")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(RaverTheme.primaryText)
                                .padding(.horizontal, 9)
                                .padding(.vertical, 7)
                                .background(RaverTheme.card, in: Capsule())
                                .overlay(
                                    Capsule()
                                        .stroke(RaverTheme.cardBorder, lineWidth: 1)
                                )
                        }
                        .buttonStyle(.plain)
                    }

                    Button(action: action) {
                        Label(isSearching ? LT("搜索中", "Searching", "検索中") : LT("绑定", "Bind", "紐付け"), systemImage: "magnifyingglass")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .background(RaverTheme.accent, in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .disabled(isSearching)
                    .opacity(isSearching ? 0.72 : 1)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 11)
            .background(RaverTheme.background, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func aiImportDJSearchResultsList(
        results: [WebDJ],
        feedback: EventUploadFlowViewModel.InlineSearchFeedback,
        isSearching: Bool,
        onSelect: @escaping (WebDJ) -> Void
    ) -> some View {
        if !results.isEmpty {
            VStack(spacing: 6) {
                ForEach(results.prefix(8)) { dj in
                    Button {
                        onSelect(dj)
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "music.mic.circle.fill")
                                .font(.title3)
                                .foregroundStyle(RaverTheme.accent)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(dj.name)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(RaverTheme.primaryText)
                                Text(dj.country ?? dj.slug ?? dj.id)
                                    .font(.caption2)
                                    .foregroundStyle(RaverTheme.secondaryText)
                                    .lineLimit(1)
                            }
                            Spacer()
                            Image(systemName: "plus.circle")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(RaverTheme.secondaryText)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(RaverTheme.card, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
        } else if isSearching {
            aiImportInlineSearchFeedbackRow(
                message: LT("正在搜索 DJ 库…", "Searching DJ library...", "DJライブラリを検索中..."),
                systemImage: "clock.arrow.circlepath",
                tint: RaverTheme.secondaryText
            )
        } else if let message = feedback.message {
            aiImportInlineSearchFeedbackRow(
                message: message,
                systemImage: feedback.isFailure ? "exclamationmark.triangle.fill" : "info.circle.fill",
                tint: feedback.isFailure ? .red : RaverTheme.secondaryText
            )
        }
    }

    private func aiImportInlineSearchFeedbackRow(message: String, systemImage: String, tint: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.caption)
                .foregroundStyle(tint)
            Text(message)
                .font(.caption2)
                .foregroundStyle(tint)
            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(RaverTheme.background, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func autoMatchCurrentSlots() async {
        guard !isAutoMatching else { return }
        isAutoMatching = true
        autoMatchStartedAt = Date()
        statusIsError = false
        statusMessage = LT("正在匹配当前列表中的 DJ 词条。", "Matching DJs in the current list.", "現在のリストのDJを紐付けています。")
        let matched = await viewModel.autoMatchTimetableAIImportSlots(resultSlots)
        resultSlots = matched
        refreshResultFilters(preserveSelection: true)
        statusMessage = LT("已完成自动匹配，可继续确认导入。", "Auto match finished. You can continue and apply.", "自動紐付けが完了しました。続けて適用できます。")
        isAutoMatching = false
        autoMatchStartedAt = nil
    }

    private func cleanupVisibleResultSlots() {
        let visibleIDs = Set(visibleSlots.map(\.id))
        guard !visibleIDs.isEmpty else { return }

        var cleanedCount = 0
        resultSlots = resultSlots.compactMap { slot in
            guard visibleIDs.contains(slot.id) else { return slot }
            let cleaned = cleanedAIImportSlot(slot)
            if cleaned == nil || cleaned! != slot {
                cleanedCount += 1
            }
            return cleaned
        }

        refreshResultFilters(preserveSelection: true)
        statusIsError = false
        statusMessage = cleanedCount > 0
            ? LT("已清理 \(cleanedCount) 条空值/未命名结果，剩余条目已自动收敛为更合理的演出形式。", "Cleaned \(cleanedCount) empty or unnamed results and compacted the remaining acts automatically.", "\(cleanedCount)件の空欄・未命名結果を整理し、残りの出演形式も自動で整えました。")
            : LT("当前筛选下没有需要清理的空值条目。", "There are no empty entries to clean in the current filter.", "現在の絞り込みには整理が必要な空欄項目はありません。")
    }

    private func elapsedText(since start: Date?, now: Date) -> String {
        guard let start else { return "00:00" }
        let seconds = max(0, Int(now.timeIntervalSince(start)))
        return String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }

    private func binding<T>(for slotID: UUID, keyPath: WritableKeyPath<EventUploadTimetableAIEditableSlot, T>, default defaultValue: @autoclosure @escaping () -> T) -> Binding<T> {
        Binding {
            resultSlots.first(where: { $0.id == slotID })?[keyPath: keyPath] ?? defaultValue()
        } set: { newValue in
            guard let index = resultSlots.firstIndex(where: { $0.id == slotID }) else { return }
            resultSlots[index][keyPath: keyPath] = newValue
        }
    }

    private func cleanedAIImportSlot(_ slot: EventUploadTimetableAIEditableSlot) -> EventUploadTimetableAIEditableSlot? {
        let cleaned = cleanedPerformerState(
            actType: slot.actType,
            performerNames: rawTimetableAIPerformerNames(for: slot),
            performerDJIDs: slot.performerDJIDs,
            performerAvatarURLs: slot.performerAvatarURLs
        )

        guard !cleaned.names.isEmpty else { return nil }

        var next = slot
        next.actType = cleaned.actType
        next.performerNamesText = cleaned.names.joined(separator: ", ")
        next.performerDJIDs = cleaned.djIDs
        next.performerAvatarURLs = cleaned.avatarURLs
        return next
    }
}

private func cleanedTimetableSlot(_ slot: EventUploadLineupSlotDraft) -> EventUploadLineupSlotDraft? {
    let cleaned = cleanedPerformerState(
        actType: slot.actType,
        performerNames: slot.performerNames,
        performerDJIDs: slot.performerDJIDs,
        performerAvatarURLs: slot.performerAvatarURLs
    )

    guard !cleaned.names.isEmpty else { return nil }

    var next = slot
    next.actType = cleaned.actType
    next.performerNames = cleaned.names
    next.performerDJIDs = cleaned.djIDs
    next.performerAvatarURLs = cleaned.avatarURLs
    next.normalizePerformers()
    return next
}

private func cleanedPerformerState(
    actType: EventLineupActType,
    performerNames: [String],
    performerDJIDs: [String?],
    performerAvatarURLs: [String?]
) -> (actType: EventLineupActType, names: [String], djIDs: [String?], avatarURLs: [String?]) {
    let entries = Array(0..<actType.performerCount).compactMap { index -> (String, String?, String?)? in
        let rawName = performerNames.indices.contains(index) ? performerNames[index] : ""
        let name = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return nil }
        let djID = performerDJIDs.indices.contains(index) ? performerDJIDs[index] : nil
        let avatarURL = performerAvatarURLs.indices.contains(index) ? performerAvatarURLs[index] : nil
        return (name, djID, avatarURL)
    }

    switch entries.count {
    case 0:
        return (.solo, [], [], [])
    case 1:
        return (.solo, [entries[0].0], [entries[0].1], [entries[0].2])
    case 2:
        return (.b2b, entries.map(\.0), entries.map(\.1), entries.map(\.2))
    default:
        let firstThree = Array(entries.prefix(3))
        return (.b3b, firstThree.map(\.0), firstThree.map(\.1), firstThree.map(\.2))
    }
}

private struct AIThinkingIndicator: View {
    @State private var pulse = false
    @State private var spin = false

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .stroke(
                        AngularGradient(
                            colors: [.cyan, .blue, .purple, .pink, .cyan],
                            center: .center
                        ),
                        lineWidth: 2.2
                    )
                    .frame(width: 34, height: 34)
                    .rotationEffect(.degrees(spin ? 360 : 0))
                Image(systemName: "sparkles")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
            }
            .onAppear {
                withAnimation(.linear(duration: 1.6).repeatForever(autoreverses: false)) {
                    spin = true
                }
                withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                    pulse = true
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(LT("AI 正在思考", "AI is thinking", "AIが考え中"))
                    .font(.caption.weight(.bold))
                    .foregroundStyle(RaverTheme.primaryText)
                HStack(spacing: 4) {
                    ForEach(0..<3, id: \.self) { index in
                        Circle()
                            .fill(index == 1 ? Color.cyan : Color.purple)
                            .frame(width: 5, height: 5)
                            .opacity(pulse ? 0.35 : 1)
                            .scaleEffect(pulse ? 1.2 : 0.8)
                    }
                }
            }
            Spacer()
        }
        .padding(12)
        .background(RaverTheme.card, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [.cyan.opacity(0.7), .blue.opacity(0.7), .purple.opacity(0.7)],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    lineWidth: 1
                )
        )
    }
}

private extension EventUploadFlowView {
    func hideKeyboard() {
#if canImport(UIKit)
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
#endif
    }
}

private struct EventUploadDayOption: Identifiable, Hashable {
    var id: Int { dayIndex }
    let dayIndex: Int
    let title: String
    let date: Date
}

private struct LocalizedExpandableFieldSection: View {
    let title: String
    let isRequired: Bool
    let axis: Axis
    let includeEnglishFull: Bool
    let showClearI18nAction: Bool
    @Binding var expanded: Bool
    let primaryPlaceholder: String
    let primaryBinding: Binding<String>
    let zhBinding: Binding<String>
    let enBinding: Binding<String>
    let jaBinding: Binding<String>
    let englishFullBinding: Binding<String>?
    let extraCount: Int
    let preferredLanguage: EventUploadPreferredLanguage
    let onClearI18n: (() -> Void)?

    init(
        title: String,
        isRequired: Bool,
        axis: Axis,
        includeEnglishFull: Bool,
        showClearI18nAction: Bool = false,
        expanded: Binding<Bool>,
        primaryPlaceholder: String,
        primaryBinding: Binding<String>,
        zhBinding: Binding<String>,
        enBinding: Binding<String>,
        jaBinding: Binding<String>,
        englishFullBinding: Binding<String>?,
        extraCount: Int,
        preferredLanguage: EventUploadPreferredLanguage,
        onClearI18n: (() -> Void)? = nil
    ) {
        self.title = title
        self.isRequired = isRequired
        self.axis = axis
        self.includeEnglishFull = includeEnglishFull
        self.showClearI18nAction = showClearI18nAction
        self._expanded = expanded
        self.primaryPlaceholder = primaryPlaceholder
        self.primaryBinding = primaryBinding
        self.zhBinding = zhBinding
        self.enBinding = enBinding
        self.jaBinding = jaBinding
        self.englishFullBinding = englishFullBinding
        self.extraCount = extraCount
        self.preferredLanguage = preferredLanguage
        self.onClearI18n = onClearI18n
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 8) {
                headerTitle
                Spacer(minLength: 8)
                Button {
                    expanded.toggle()
                } label: {
                    HStack(spacing: 6) {
                        Text(expanded ? LT("收起", "Collapse", "閉じる") : LT("多语言", "Languages", "多言語"))
                            .font(.caption.weight(.semibold))
                        if extraCount > 0 {
                            Text("\(extraCount)")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(RaverTheme.accent, in: Capsule())
                        }
                        Image(systemName: expanded ? "chevron.up" : "chevron.down")
                            .font(.caption2.weight(.bold))
                    }
                    .foregroundStyle(extraCount > 0 ? RaverTheme.accent : RaverTheme.secondaryText)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(RaverTheme.card, in: Capsule())
                    .overlay(
                        Capsule()
                            .stroke(extraCount > 0 ? RaverTheme.accent.opacity(0.28) : RaverTheme.cardBorder, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                if showClearI18nAction, let onClearI18n {
                    Button(role: .destructive) {
                        onClearI18n()
                    } label: {
                        Text("Remove i18n")
                            .font(.caption.weight(.semibold))
                    }
                    .buttonStyle(.plain)
                }
            }

            TextField(primaryPlaceholder, text: primaryBinding, axis: axis)
                .font(.body)
                .foregroundStyle(RaverTheme.primaryText)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .lineLimit(axis == .vertical ? 5 : 1)
                .padding(.horizontal, 12)
                .padding(.vertical, 11)
                .background(RaverTheme.card)

            if expanded {
                VStack(spacing: 10) {
                    languageRow(title: LT("中文", "Chinese", "中国語"), binding: zhBinding, isPrimary: preferredLanguage == .zh)
                    languageRow(title: "English", binding: enBinding, isPrimary: preferredLanguage == .en)
                    languageRow(title: LT("日文", "Japanese", "日本語"), binding: jaBinding, isPrimary: preferredLanguage == .ja)
                    if includeEnglishFull, let englishFullBinding {
                        languageRow(title: LT("国家英文全称", "Country Full Name", "国名フル英語"), binding: englishFullBinding, isPrimary: false)
                    }
                }
                .padding(12)
                .background(RaverTheme.card, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(RaverTheme.cardBorder, lineWidth: 1)
                )
            }
        }
    }

    private var headerTitle: some View {
        HStack(spacing: 4) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(RaverTheme.secondaryText)
            if isRequired {
                Text("*")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.red)
            }
        }
    }

    private func languageRow(title: String, binding: Binding<String>, isPrimary: Bool) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(RaverTheme.secondaryText)
                if isPrimary {
                    Text(LT("当前默认", "Default", "既定"))
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(RaverTheme.accent)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(RaverTheme.accent.opacity(0.12), in: Capsule())
                }
            }

            TextField(title, text: binding, axis: axis)
                .font(.body)
                .foregroundStyle(RaverTheme.primaryText)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .lineLimit(axis == .vertical ? 4 : 1)
                .padding(.horizontal, 12)
                .padding(.vertical, 11)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(RaverTheme.card)
                )
        }
    }
}

private struct EventUploadWeekSelection: Identifiable, Hashable {
    var id: UUID { week.id }
    let index: Int
    let week: EventUploadWeekRangeDraft
}

private struct DatePickerPresentation: Identifiable {
    let id = UUID()
    let title: String
    let selection: Binding<Date>
}

private struct EventUploadDatePickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    let title: String
    let selection: Binding<Date>
    let timeZone: TimeZone

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                DatePicker(
                    title,
                    selection: selection,
                    displayedComponents: [.date]
                )
                .datePickerStyle(.graphical)
                .environment(\.timeZone, timeZone)
                .tint(RaverTheme.accent)
                .padding(.horizontal, 16)

                Spacer(minLength: 0)
            }
            .padding(.top, 12)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(LT("完成", "Done", "完了")) {
                        dismiss()
                    }
                    .font(.headline)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

private struct EventUploadWeekTimetableEditorSheet: View {
    let selection: EventUploadWeekSelection
    let stageNames: [String]
    let slots: [EventUploadLineupSlotDraft]
    let dayOptions: [EventUploadDayOption]
    let weekSummaryText: String
    let eventTimeZone: TimeZone
    let isExpanded: (UUID) -> Bool
    let onToggleExpanded: (UUID) -> Void
    let onAddSlot: (String, Int) -> Void
    let actTypeBinding: (UUID) -> Binding<EventLineupActType>
    let performerBinding: (UUID, Int) -> Binding<String>
    let stageBinding: (UUID) -> Binding<String>
    let dayBinding: (UUID) -> Binding<Int>
    let timeBinding: (UUID, WritableKeyPath<EventUploadLineupSlotDraft, Date?>) -> Binding<Date>
    let dayOffsetBinding: (UUID, WritableKeyPath<EventUploadLineupSlotDraft, EventUploadSlotDayOffset>) -> Binding<EventUploadSlotDayOffset>
    let isSearchingPerformer: (EventUploadLineupSlotDraft, Int) -> Bool
    let onSearchPerformer: (EventUploadLineupSlotDraft, Int) -> Void
    let onClearPerformer: (EventUploadLineupSlotDraft, Int) -> Void
    let searchSection: (EventUploadLineupSlotDraft, Int) -> AnyView
    let onReplaceSlot: (EventUploadLineupSlotDraft) -> Void
    let onDelete: (UUID) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selectedStage: String = ""
    @State private var selectedDayIndex: Int = 1
    @State private var keyboardCandidateSpacing: CGFloat = 0
    @State private var isSelectionMode = false
    @State private var selectedSlotIDs: Set<UUID> = []
    @State private var moveDayDialogPresented = false
    @State private var moveStageDialogPresented = false

    private var autoCleanableFilteredSlotCount: Int {
        filteredSlots.reduce(into: 0) { count, slot in
            if cleanedTimetableSlot(slot) != slot {
                count += 1
            }
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
	                    VStack(alignment: .leading, spacing: 16) {
	                    VStack(alignment: .leading, spacing: 12) {
	                        HStack {
	                            Text("Week \(selection.index + 1)")
	                                .font(.title3.weight(.bold))
	                                .foregroundStyle(RaverTheme.primaryText)
	                            Spacer()
	                            Text(weekSummaryText)
	                                .font(.caption.weight(.semibold))
	                                .foregroundStyle(RaverTheme.secondaryText)
	                        }
	                    }
	                    .padding(16)
	                    .background(Color.clear, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
	                    .overlay(
	                        RoundedRectangle(cornerRadius: 16, style: .continuous)
	                            .stroke(RaverTheme.cardBorder, lineWidth: 1)
	                    )

                    if !dayOptions.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(LT("Week 日期", "Week Days", "Weekの日付"))
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(RaverTheme.secondaryText)
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(dayOptions) { option in
                                        Button {
                                            selectedDayIndex = option.dayIndex
                                        } label: {
                                            VStack(spacing: 2) {
                                                Text(option.title)
                                                    .font(.caption.weight(.semibold))
                                                Text(shortDate(option.date))
                                                    .font(.caption2)
                                            }
                                            .foregroundStyle(selectedDayIndex == option.dayIndex ? .white : RaverTheme.primaryText)
                                            .padding(.horizontal, 14)
                                            .padding(.vertical, 10)
                                            .background(
                                                selectedDayIndex == option.dayIndex ? RaverTheme.accent : RaverTheme.card,
                                                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            )
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                    .stroke(selectedDayIndex == option.dayIndex ? Color.clear : RaverTheme.cardBorder, lineWidth: 1)
                                            )
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }
                    }

                    if !stageNames.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(LT("舞台顺序", "Stage Order", "ステージ順"))
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(RaverTheme.secondaryText)
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(Array(stageNames.enumerated()), id: \.offset) { index, stage in
                                        Button {
                                            selectedStage = stage
                                        } label: {
                                            HStack(spacing: 8) {
                                                Text("\(index + 1)")
                                                    .font(.caption2.weight(.bold))
                                                    .foregroundStyle(selectedStage == stage ? .white.opacity(0.82) : RaverTheme.secondaryText)
                                                Text(stage)
                                                    .font(.caption.weight(.semibold))
                                            }
                                            .foregroundStyle(selectedStage == stage ? .white : RaverTheme.primaryText)
                                            .padding(.horizontal, 14)
                                            .padding(.vertical, 10)
                                            .background(
                                                selectedStage == stage ? RaverTheme.accent : RaverTheme.card,
                                                in: Capsule()
                                            )
                                            .overlay(
                                                Capsule()
                                                    .stroke(selectedStage == stage ? Color.clear : RaverTheme.cardBorder, lineWidth: 1)
                                            )
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }
                    }

                    sheetIssueCenter

	                    VStack(alignment: .leading, spacing: 8) {
	                        HStack {
	                            Text(LT("节目列表", "Set List", "セット一覧"))
	                                .font(.headline)
	                                .foregroundStyle(RaverTheme.primaryText)
	                            Spacer()
		                            if isSelectionMode {
		                                Button {
		                                    moveDayDialogPresented = true
	                                } label: {
	                                    Text(LT("更换日期", "Change Day", "日付変更"))
	                                        .font(.caption.weight(.bold))
	                                        .foregroundStyle(selectedSlotIDs.isEmpty ? RaverTheme.secondaryText : .white)
	                                        .padding(.horizontal, 10)
	                                        .padding(.vertical, 6)
	                                        .background(selectedSlotIDs.isEmpty ? RaverTheme.card : RaverTheme.accent, in: Capsule())
		                                }
		                                .buttonStyle(.plain)
		                                .disabled(selectedSlotIDs.isEmpty)
		                                if !stageNames.isEmpty {
		                                    Button {
		                                        moveStageDialogPresented = true
		                                    } label: {
		                                        Text(LT("更换舞台", "Change Stage", "ステージ変更"))
		                                            .font(.caption.weight(.bold))
		                                            .foregroundStyle(selectedSlotIDs.isEmpty ? RaverTheme.secondaryText : .white)
		                                            .padding(.horizontal, 10)
		                                            .padding(.vertical, 6)
		                                            .background(selectedSlotIDs.isEmpty ? RaverTheme.card : RaverTheme.accent, in: Capsule())
		                                    }
		                                    .buttonStyle(.plain)
		                                    .disabled(selectedSlotIDs.isEmpty)
		                                }
		                            }
	                            Button {
	                                toggleSelectionMode()
	                            } label: {
	                                Text(isSelectionMode ? LT("完成", "Done", "完了") : LT("多选", "Select", "複数選択"))
	                                    .font(.caption.weight(.bold))
	                                    .foregroundStyle(isSelectionMode ? .white : RaverTheme.primaryText)
	                                    .padding(.horizontal, 10)
	                                    .padding(.vertical, 6)
	                                    .background(isSelectionMode ? RaverTheme.accent : RaverTheme.card, in: Capsule())
	                            }
	                            .buttonStyle(.plain)
	                            Text("\(filteredSlots.count)")
	                                .font(.caption.weight(.semibold))
	                                .foregroundStyle(RaverTheme.secondaryText)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(RaverTheme.card, in: Capsule())
                        }

                    }

                    if filteredSlots.isEmpty {
                        Text(LT("这个 Week 这一舞台下还没有节目。", "No sets yet for this week and stage.", "このWeekとステージにはまだセットがありません。"))
                            .font(.subheadline)
                            .foregroundStyle(RaverTheme.secondaryText)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(16)
                            .background(RaverTheme.card, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
	                    } else {
	                        VStack(spacing: 12) {
	                            ForEach(Array(filteredSlots.enumerated()), id: \.element.id) { index, slot in
	                                slotCard(slot, order: index + 1)
	                            }
	                        }
	                    }

	                    Button {
	                        onAddSlot(selectedStage, selectedDayIndex)
	                    } label: {
	                        HStack {
	                            Label(LT("在当前 Week 添加节目", "Add Set in This Week", "このWeekにセットを追加"), systemImage: "plus.circle.fill")
	                                .font(.subheadline.weight(.bold))
	                            Spacer()
	                            Text(selectedDayLabel)
	                                .font(.caption.weight(.semibold))
	                                .foregroundStyle(.white.opacity(0.76))
	                        }
	                        .foregroundStyle(.white)
	                        .padding(.horizontal, 14)
	                        .padding(.vertical, 14)
	                        .background(
	                            LinearGradient(
	                                colors: [RaverTheme.accent, RaverTheme.accent.opacity(0.78)],
	                                startPoint: .topLeading,
	                                endPoint: .bottomTrailing
	                            ),
	                            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
	                        )
	                    }
	                    .buttonStyle(.plain)
	                }
	                .padding(20)
	                .padding(.bottom, 84 + keyboardCandidateSpacing)
	            }
	            .scrollDismissesKeyboard(.interactively)
	            .simultaneousGesture(TapGesture().onEnded { self.dismissKeyboard() })
	            .safeAreaInset(edge: .bottom) {
	                Color.clear
	                    .frame(height: keyboardCandidateSpacing)
                    .allowsHitTesting(false)
            }
            .background(RaverTheme.background.ignoresSafeArea())
            .navigationTitle(LT("编辑时间表", "Edit Timetable", "タイムテーブル編集"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(LT("完成", "Done", "完了")) {
                        dismiss()
                    }
                }
            }
            .onAppear {
                if selectedStage.isEmpty {
                    selectedStage = stageNames.first ?? ""
                }
                if let firstDay = dayOptions.first {
                    selectedDayIndex = firstDay.dayIndex
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
                withAnimation(.easeOut(duration: 0.22)) {
                    keyboardCandidateSpacing = 132
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
                withAnimation(.easeOut(duration: 0.18)) {
                    keyboardCandidateSpacing = 0
                }
            }
	            .confirmationDialog(
	                LT("更换到哪一天？", "Move to which day?", "どの日に移動しますか？"),
	                isPresented: $moveDayDialogPresented,
                titleVisibility: .visible
            ) {
                ForEach(dayOptions) { option in
                    Button("\(option.title) · \(shortDate(option.date))") {
                        moveSelectedSlots(to: option)
                    }
                }
                Button(LT("取消", "Cancel", "キャンセル"), role: .cancel) {}
	            } message: {
	                Text(LT("会把已选中的节目移动到目标日期。", "Selected sets will be moved to the target day.", "選択した出演を指定の日に移動します。"))
	            }
	            .confirmationDialog(
	                LT("更换到哪个舞台？", "Move to which stage?", "どのステージに移動しますか？"),
	                isPresented: $moveStageDialogPresented,
	                titleVisibility: .visible
	            ) {
	                ForEach(stageNames, id: \.self) { stage in
	                    Button(stage) {
	                        moveSelectedSlots(toStage: stage)
	                    }
	                }
	                Button(LT("取消", "Cancel", "キャンセル"), role: .cancel) {}
	            } message: {
	                Text(LT("会把已选中的节目移动到目标舞台。", "Selected sets will be moved to the target stage.", "選択した出演を指定のステージに移動します。"))
	            }
	        }
	    }

    private var filteredSlots: [EventUploadLineupSlotDraft] {
        slots.filter { slot in
            let normalizedStage = slot.stageName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? LT("主舞台", "Main Stage", "メインステージ")
                : slot.stageName
            return normalizedStage == selectedStage && slot.dayIndex == selectedDayIndex
        }
        .sorted { lhs, rhs in
            (lhs.startTime ?? .distantPast) < (rhs.startTime ?? .distantPast)
        }
    }

    private var selectedDayLabel: String {
        dayOptions.first(where: { $0.dayIndex == selectedDayIndex })?.title ?? LT("未选择日期", "No day selected", "日付未選択")
    }

    private var visibleSlotIssues: [String] {
        filteredSlots.enumerated().flatMap { index, slot -> [String] in
            var issues: [String] = []
            let order = index + 1
            let name = displayName(slot)
            let names = slot.performerNames
                .prefix(slot.actType.performerCount)
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }

            if names.count != slot.actType.performerCount || names.contains(where: { $0.isEmpty }) {
                issues.append(
                    LT(
                        "#\(order)「\(name)」有未命名 DJ，请补全或删除。",
                        "#\(order) \"\(name)\" has unnamed DJs. Complete or delete it.",
                        "#\(order)「\(name)」に未入力のDJがあります。入力または削除してください。"
                    )
                )
            }
            if slot.startTime == nil || slot.endTime == nil {
                issues.append(
                    LT(
                        "#\(order)「\(name)」缺少开始或结束时间。",
                        "#\(order) \"\(name)\" is missing start or end time.",
                        "#\(order)「\(name)」は開始または終了時刻が未入力です。"
                    )
                )
            }
            if dayOptions.first(where: { $0.dayIndex == slot.dayIndex }) == nil {
                issues.append(
                    LT(
                        "#\(order)「\(name)」没有绑定到当前 Week 的有效日期。",
                        "#\(order) \"\(name)\" is not bound to a valid day in this week.",
                        "#\(order)「\(name)」はこのWeekの有効な日付に紐付いていません。"
                    )
                )
            }
            return issues
        }
    }

    @ViewBuilder
    private var sheetIssueCenter: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: visibleSlotIssues.isEmpty ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(visibleSlotIssues.isEmpty ? .green : .orange)
                Text(LT("当前筛选待处理", "Current View Issues", "現在表示中の要確認"))
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(RaverTheme.primaryText)
                Spacer(minLength: 0)
                Text(visibleSlotIssues.isEmpty ? LT("OK", "OK", "OK") : "\(visibleSlotIssues.count)")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(visibleSlotIssues.isEmpty ? .green : .orange)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background((visibleSlotIssues.isEmpty ? Color.green : Color.orange).opacity(0.12), in: Capsule())
            }

            if visibleSlotIssues.isEmpty {
                Text(LT("当前日期和舞台下没有会阻塞下一步的节目。", "No blocking set issues for this day and stage.", "現在の日付とステージには進行を妨げる出演問題はありません。"))
                    .font(.caption)
                    .foregroundStyle(RaverTheme.secondaryText)
            } else {
                ForEach(Array(visibleSlotIssues.prefix(5).enumerated()), id: \.offset) { _, issue in
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "smallcircle.filled.circle.fill")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                            .padding(.top, 2)
                        Text(issue)
                            .font(.caption)
                            .foregroundStyle(RaverTheme.primaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                if autoCleanableFilteredSlotCount > 0 {
                    Button {
                        cleanupCurrentFilteredSlots()
                    } label: {
                        Label(
                            LT("一键清理空值 / 未命名 DJ", "Clean Empty / Unnamed DJs", "空欄・未命名DJを一括整理"),
                            systemImage: "sparkles"
                        )
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.orange)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 9)
                        .background(Color.orange.opacity(0.12), in: Capsule())
                    }
                    .buttonStyle(.plain)

                    Text(LT("会删除全空条目，并把人数不足的 B2B / B3B 自动收敛成 Solo 或 B2B。", "This removes fully empty entries and compacts partial B2B / B3B acts automatically.", "空の項目を削除し、人数が不足したB2B / B3Bを自動でSoloまたはB2Bへ整理します。"))
                        .font(.caption2)
                        .foregroundStyle(RaverTheme.secondaryText)
                }
            }
        }
        .padding(14)
        .background(RaverTheme.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke((visibleSlotIssues.isEmpty ? Color.green : Color.orange).opacity(0.32), lineWidth: 1)
        )
    }

    private func shortDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.timeZone = eventTimeZone
        formatter.dateFormat = "M/d"
        return formatter.string(from: date)
    }

    private func slotCard(_ slot: EventUploadLineupSlotDraft, order: Int) -> some View {
        let expanded = !isSelectionMode && (isExpanded(slot.id) || !isCollapsedEligible(slot))
        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                if isSelectionMode {
                    Image(systemName: selectedSlotIDs.contains(slot.id) ? "checkmark.circle.fill" : "circle")
                        .font(.headline)
                        .foregroundStyle(selectedSlotIDs.contains(slot.id) ? RaverTheme.accent : RaverTheme.secondaryText)
                }

                Text("\(order)")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(RaverTheme.secondaryText)
                    .frame(width: 18, alignment: .leading)

                performerAvatarStack(slot)

                VStack(alignment: .leading, spacing: 3) {
                    Text(displayName(slot))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(RaverTheme.primaryText)
                        .lineLimit(1)
                    Text(timeSummary(slot))
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(RaverTheme.accent)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if !isSelectionMode {
                    Button {
                        if expanded, isCollapsedEligible(slot) {
                            onToggleExpanded(slot.id)
                        } else if !expanded {
                            onToggleExpanded(slot.id)
                        }
                    } label: {
                        Image(systemName: expanded ? "chevron.up" : "square.and.pencil")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(expanded ? RaverTheme.accent : RaverTheme.secondaryText)
                            .frame(width: 30, height: 30)
                            .background(RaverTheme.background, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                    .buttonStyle(.plain)

                    Button {
                        onDelete(slot.id)
                    } label: {
                        Image(systemName: "trash")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.red)
                            .frame(width: 28, height: 28)
                            .background(RaverTheme.background, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }

            if expanded {
                Picker(LT("演出形式", "Act Type", "出演形式"), selection: actTypeBinding(slot.id)) {
                    ForEach(EventLineupActType.allCases) { type in
                        Text(type.title).tag(type)
                    }
                }
                .pickerStyle(.segmented)

                ForEach(0..<slot.actType.performerCount, id: \.self) { index in
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 10) {
                            performerAvatar(name: slot.performerNames.indices.contains(index) ? slot.performerNames[index] : "", avatarURL: slot.performerAvatarURLs.indices.contains(index) ? slot.performerAvatarURLs[index] : nil, index: index)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(slot.actType == .solo ? LT("DJ / 艺人名称", "Artist / DJ Name", "DJ / アーティスト名") : LT("成员 \(index + 1)", "Member \(index + 1)", "メンバー \(index + 1)"))
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(RaverTheme.secondaryText)
                                Text(timetableBindingState(slot, index: index))
                                    .font(.caption2)
                                    .foregroundStyle(RaverTheme.secondaryText)
                            }
                            Spacer()
                            if timetableIsBound(slot, index: index) {
                                Image(systemName: "checkmark.seal.fill")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(.green)
                            }
                        }

                        djSearchTextField(
                            title: slot.actType == .solo ? LT("输入 DJ / 艺人名称", "Enter artist / DJ name", "DJ / アーティスト名を入力") : LT("输入成员名称", "Enter member name", "メンバー名を入力"),
                            text: performerBinding(slot.id, index),
                            isSearching: isSearchingPerformer(slot, index),
                            canClear: timetableCanClear(slot, index: index),
                            clearAction: {
                                onClearPerformer(slot, index)
                            },
                            action: {
                                onSearchPerformer(slot, index)
                            }
                        )

                        searchSection(slot, index)
                    }
                    .padding(12)
                    .background(RaverTheme.background, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }

                HStack(spacing: 12) {
                    timetableDatePickerColumn(
                        title: LT("开始", "Start", "開始"),
                        dayOffset: dayOffsetBinding(slot.id, \.startDayOffset),
                        selection: timeBinding(slot.id, \.startTime)
                    )

                    timetableDatePickerColumn(
                        title: LT("结束", "End", "終了"),
                        dayOffset: dayOffsetBinding(slot.id, \.endDayOffset),
                        selection: timeBinding(slot.id, \.endTime)
                    )
                }

                if isCollapsedEligible(slot) {
                    HStack {
                        Spacer()
                        Button {
                            onToggleExpanded(slot.id)
                        } label: {
                            Label(LT("确定", "Done", "確定"), systemImage: "checkmark")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 9)
                                .background(RaverTheme.accent, in: Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(14)
        .background(RaverTheme.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(selectedSlotIDs.contains(slot.id) ? RaverTheme.accent : RaverTheme.cardBorder, lineWidth: selectedSlotIDs.contains(slot.id) ? 2 : 1)
        )
        .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .onTapGesture {
            if isSelectionMode {
                toggleSlotSelection(slot.id)
            }
        }
    }

    private func toggleSelectionMode() {
        isSelectionMode.toggle()
        if !isSelectionMode {
            selectedSlotIDs.removeAll()
        }
    }

    private func toggleSlotSelection(_ slotID: UUID) {
        if selectedSlotIDs.contains(slotID) {
            selectedSlotIDs.remove(slotID)
        } else {
            selectedSlotIDs.insert(slotID)
        }
    }

    private func moveSelectedSlots(to day: EventUploadDayOption) {
        guard !selectedSlotIDs.isEmpty else { return }
        for slotID in selectedSlotIDs {
            dayBinding(slotID).wrappedValue = day.dayIndex
        }
        selectedDayIndex = day.dayIndex
        selectedSlotIDs.removeAll()
        isSelectionMode = false
    }

    private func moveSelectedSlots(toStage stage: String) {
        let normalizedStage = stage.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !selectedSlotIDs.isEmpty, !normalizedStage.isEmpty else { return }
        for slotID in selectedSlotIDs {
            stageBinding(slotID).wrappedValue = normalizedStage
        }
        selectedStage = normalizedStage
        selectedSlotIDs.removeAll()
        isSelectionMode = false
    }

    private func cleanupCurrentFilteredSlots() {
        for slot in filteredSlots {
            guard let cleaned = cleanedTimetableSlot(slot) else {
                onDelete(slot.id)
                selectedSlotIDs.remove(slot.id)
                continue
            }
            if cleaned != slot {
                onReplaceSlot(cleaned)
            }
        }
    }

    private func dismissKeyboard() {
#if canImport(UIKit)
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
#endif
    }

    private func timetableIsBound(_ slot: EventUploadLineupSlotDraft, index: Int) -> Bool {
        slot.performerDJIDs.indices.contains(index)
            ? slot.performerDJIDs[index]?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            : false
    }

    private func timetableBindingState(_ slot: EventUploadLineupSlotDraft, index: Int) -> String {
        timetableIsBound(slot, index: index)
            ? LT("已绑定 DJ 词条", "Bound to DJ entry", "DJエントリ紐付け済み")
            : LT("可手填，也可绑定 DJ 库", "Manual or DJ binding", "手入力またはDJ紐付け")
    }

    private func timetableCanClear(_ slot: EventUploadLineupSlotDraft, index: Int) -> Bool {
        let nameFilled = slot.performerNames.indices.contains(index)
            ? !slot.performerNames[index].trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            : false
        return nameFilled || timetableIsBound(slot, index: index)
    }

    private func djSearchTextField(
        title: String,
        text: Binding<String>,
        isSearching: Bool,
        canClear: Bool,
        clearAction: @escaping () -> Void,
        action: @escaping () -> Void
    ) -> some View {
        ZStack(alignment: .trailing) {
            TextField(title, text: text)
                .font(.body)
                .foregroundStyle(RaverTheme.primaryText)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .padding(.trailing, canClear ? 168 : 104)

            HStack(spacing: 6) {
                if canClear {
                    Button(action: clearAction) {
                        Label(LT("清空", "Clear", "クリア"), systemImage: "xmark.circle")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(RaverTheme.primaryText)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 7)
                            .background(RaverTheme.card, in: Capsule())
                            .overlay(
                                Capsule()
                                    .stroke(RaverTheme.cardBorder, lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }

                Button(action: action) {
                    Label(isSearching ? LT("搜索中", "Searching", "検索中") : LT("绑定", "Bind", "紐付け"), systemImage: "magnifyingglass")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(RaverTheme.accent, in: Capsule())
                }
                .buttonStyle(.plain)
                .disabled(isSearching)
                .opacity(isSearching ? 0.72 : 1)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 11)
        .background(RaverTheme.background, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func isCollapsedEligible(_ slot: EventUploadLineupSlotDraft) -> Bool {
        let names = slot.performerNames
            .prefix(slot.actType.performerCount)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        return !names.contains(where: { $0.isEmpty }) && slot.startTime != nil && slot.endTime != nil
    }

    private func displayName(_ slot: EventUploadLineupSlotDraft) -> String {
        let name = EventLineupActCodec.composeName(type: slot.actType, performerNames: slot.performerNames)
        return name.isEmpty ? LT("未命名演出", "Untitled Act", "未命名の出演") : name
    }

    private func timetableDatePickerColumn(
        title: String,
        dayOffset: Binding<EventUploadSlotDayOffset>,
        selection: Binding<Date>
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(RaverTheme.secondaryText)

            Picker(title, selection: dayOffset) {
                ForEach(EventUploadSlotDayOffset.allCases) { option in
                    Text(option.title).tag(option)
                }
            }
            .pickerStyle(.segmented)

            DatePicker(
                title,
                selection: selection,
                displayedComponents: [.hourAndMinute]
            )
            .labelsHidden()
            .datePickerStyle(.compact)
            .tint(RaverTheme.accent)
            .environment(\.timeZone, eventTimeZone)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func secondarySummary(_ slot: EventUploadLineupSlotDraft) -> String {
        let members = slot.performerNames
            .prefix(slot.actType.performerCount)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard members.count > 1 else {
            return LT("已添加 DJ", "DJ added", "DJ追加済み")
        }
        return members.joined(separator: " · ")
    }

    private func stageSummary(_ slot: EventUploadLineupSlotDraft) -> String {
        let stage = slot.stageName.trimmingCharacters(in: .whitespacesAndNewlines)
        return stage.isEmpty ? LT("主舞台", "Main Stage", "メインステージ") : stage
    }

    private func timeSummary(_ slot: EventUploadLineupSlotDraft) -> String {
        guard let start = slot.startTime,
              let end = slot.endTime,
              let logicalDay = dayOptions.first(where: { $0.dayIndex == slot.dayIndex })?.date else {
            return LT("请填写演出时间", "Set start and end time", "出演時間を入力してください")
        }
        return EventUploadTimeDisplay.clockRange(start: start, end: end, logicalDay: logicalDay, timeZone: eventTimeZone)
    }

    private func timeBadgePrimary(_ slot: EventUploadLineupSlotDraft) -> String {
        guard let start = slot.startTime else { return "--:--" }
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.timeZone = eventTimeZone
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: start)
    }

    private func timeBadgeSecondary(_ slot: EventUploadLineupSlotDraft) -> String {
        guard let end = slot.endTime else { return "--:--" }
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.timeZone = eventTimeZone
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: end)
    }

    private func timeBadge(_ slot: EventUploadLineupSlotDraft) -> some View {
        VStack(spacing: 1) {
            Text(timeBadgePrimary(slot))
                .font(.caption.weight(.bold))
                .foregroundStyle(.white)
            Text(timeBadgeSecondary(slot))
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.8))
        }
        .frame(width: 60, height: 56)
        .background(
            LinearGradient(
                colors: [RaverTheme.accent, RaverTheme.accent.opacity(0.74)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
        )
    }

    private func performerAvatarStack(_ slot: EventUploadLineupSlotDraft) -> some View {
        HStack(spacing: -10) {
            ForEach(Array(slot.performerNames.prefix(slot.actType.performerCount).enumerated()), id: \.offset) { index, name in
                performerAvatar(name: name, avatarURL: slot.performerAvatarURLs.indices.contains(index) ? slot.performerAvatarURLs[index] : nil, index: index)
            }
        }
        .padding(.trailing, 8)
    }

    private func performerAvatar(name: String, avatarURL: String?, index: Int) -> some View {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return Group {
            if let avatarURL,
               let resolved = AppConfig.resolvedDJAvatarURLString(avatarURL, size: .small),
               !resolved.isEmpty {
                AsyncImage(url: URL(string: resolved)) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    default:
                        avatarFallback(trimmed: trimmed, index: index)
                    }
                }
            } else {
                avatarFallback(trimmed: trimmed, index: index)
            }
        }
        .frame(width: 32, height: 32)
        .clipShape(Circle())
        .overlay(
            Circle()
                .stroke(RaverTheme.card, lineWidth: 2)
        )
    }

    private func metaChip(_ title: String, tint: Color, foreground: Color) -> some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(foreground)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(tint, in: Capsule())
    }

    private func avatarFallback(trimmed: String, index: Int) -> some View {
        ZStack {
            Circle()
                .fill(index == 0 ? RaverTheme.accent.opacity(0.22) : RaverTheme.background)
            Text(String(trimmed.prefix(1)).uppercased())
                .font(.caption.weight(.bold))
                .foregroundStyle(index == 0 ? RaverTheme.accent : RaverTheme.secondaryText)
        }
    }
}
