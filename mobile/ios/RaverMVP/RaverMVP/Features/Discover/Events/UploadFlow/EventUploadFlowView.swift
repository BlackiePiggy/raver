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
    private struct WeekDatePickerTarget: Identifiable {
        enum Field {
            case start
            case end
        }

        let weekID: UUID
        let field: Field

        var id: String {
            "\(weekID.uuidString)-\(field == .start ? "start" : "end")"
        }
    }

    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var viewModel: EventUploadFlowViewModel
    @State private var showLocationPicker = false
    @State private var showTimetableAIImportSheet = false
    @State private var showLineupAIImportSheet = false
    @State private var showExitConfirmation = false
    @State private var selectedWeekForEditing: EventUploadWeekSelection?
    @State private var expandedTimetableSlots: Set<UUID> = []
    @State private var expandedLineupOnlySlots: Set<UUID> = []
    @State private var expandedLocalizedFieldKeys: Set<String> = []
    @State private var showAdvancedRollover = false
    @State private var activeWeekDatePicker: WeekDatePickerTarget?
    @State private var keyboardCandidateSpacing: CGFloat = 0

    init(
        mode: EventUploadMode = .create,
        event: WebEvent? = nil,
        userID: String = "current",
        webService: WebFeatureService = AppEnvironment.sharedWebService,
        onSaved: @escaping () -> Void = {}
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
        .sheet(item: $activeWeekDatePicker) { target in
            weekDatePickerSheet(target: target)
        }
        .alert(LT("继续上次草稿？", "Continue Draft?", "前回の下書きを続けますか？"), isPresented: $viewModel.shouldConfirmRestoredCreateDraft) {
            Button(LT("重新开始", "Start Over", "最初から"), role: .destructive) {
                viewModel.restartCreateDraft()
            }
            Button(LT("继续草稿", "Continue", "続ける"), role: .cancel) {
                viewModel.continueRestoredDraft()
            }
        } message: {
            Text(LT("已恢复上次未提交的新建活动草稿。", "Your previous unsent event draft was restored.", "未送信のイベント下書きを復元しました。"))
        }
        .alert(LT("提示", "Notice", "お知らせ"), isPresented: Binding(
            get: { viewModel.statusMessage != nil },
            set: { if !$0 { viewModel.statusMessage = nil } }
        )) {
            Button(LT("确定", "OK", "OK"), role: .cancel) {}
        } message: {
            Text(viewModel.statusMessage ?? "")
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
                viewModel.discardDraftAndClose()
            }
            Button(LT("继续编辑", "Keep Editing", "編集を続ける"), role: .cancel) {}
        } message: {
            Text(LT("未提交的内容会保存在本地草稿中。", "Unsubmitted changes can be kept as a local draft.", "未送信の内容はローカル下書きとして保存できます。"))
        }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.draft.currentStep {
        case .media:
            mediaStep
        case .basic:
            basicStep
        case .time:
            timeStep
        case .timetable:
            timetableStep
        case .lineup:
            lineupStep
        case .tickets:
            ticketsStep
        case .review:
            reviewStep
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
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    content
                }
                .padding(20)
                .padding(.bottom, 84 + keyboardCandidateSpacing)
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
            EventUploadBottomBar(
                canGoBack: viewModel.draft.currentStep.previous != nil,
                isFinalStep: viewModel.draft.currentStep == .review,
                isBusy: viewModel.isSubmitting,
                onBack: viewModel.goBack,
                onNext: viewModel.advance
            )
        }
    }

    private var mediaStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionTitle(
                LT("活动图片", "Event Images", "イベント画像"),
                subtitle: LT("海报为必填，其余图片可选。图片上传仅支持从相册选择。", "Poster is required. Other images are optional. Uploads currently use photo library only.", "ポスターは必須です。他の画像は任意です。アップロードは写真ライブラリ選択のみ対応します。")
            )

            LazyVGrid(columns: [GridItem(.flexible())], spacing: 12) {
                ForEach(EventUploadImageZone.allCases) { zone in
                    EventUploadImageZoneCard(
                        zone: zone,
                        images: viewModel.draft.imageZones[zone] ?? [],
                        isRequired: zone == .poster,
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
                viewModel.tapAIPlaceholder()
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
                expanded: localizedExpansionBinding(for: "city"),
                primaryPlaceholder: localizedPrimaryFieldPlaceholder(for: LT("城市", "City", "都市")),
                primaryBinding: localizedBinding(\.city),
                zhBinding: localizedBinding(\.city, language: .zh),
                enBinding: localizedBinding(\.city, language: .en),
                jaBinding: localizedBinding(\.city, language: .ja),
                englishFullBinding: nil,
                extraCount: viewModel.draft.city.secondaryValueCount(excluding: viewModel.draft.preferredLanguage),
                preferredLanguage: viewModel.draft.preferredLanguage
            )

            LocalizedExpandableFieldSection(
                title: LT("国家", "Country", "国"),
                isRequired: true,
                axis: .horizontal,
                includeEnglishFull: true,
                expanded: localizedExpansionBinding(for: "country"),
                primaryPlaceholder: localizedPrimaryFieldPlaceholder(for: LT("国家", "Country", "国")),
                primaryBinding: localizedBinding(\.country),
                zhBinding: localizedBinding(\.country, language: .zh),
                enBinding: localizedBinding(\.country, language: .en),
                jaBinding: localizedBinding(\.country, language: .ja),
                englishFullBinding: localizedEnglishFullBinding(\.country),
                extraCount: viewModel.draft.country.secondaryValueCount(excluding: viewModel.draft.preferredLanguage, includeEnglishFull: true),
                preferredLanguage: viewModel.draft.preferredLanguage
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
                        if !viewModel.draft.pickedMapAddress.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
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

            if viewModel.draft.scheduleMode == .singleDay {
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

            if viewModel.draft.scheduleMode == .multiWeek {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text(LT("每周的日期", "Weekly ranges", "週ごとの日付"))
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(RaverTheme.primaryText)
                        Spacer()
                        Text(LT("\(viewModel.draft.weekRanges.count) 个 Week", "\(viewModel.draft.weekRanges.count) weeks", "\(viewModel.draft.weekRanges.count)個のWeek"))
                            .font(.caption)
                            .foregroundStyle(RaverTheme.secondaryText)
                    }

                    ForEach(Array(viewModel.draft.weekRanges.enumerated()), id: \.element.id) { index, week in
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
                                if viewModel.draft.weekRanges.count > 1 {
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

                            HStack(spacing: 10) {
                                weekDateField(
                                    title: LT("开始", "Start", "開始"),
                                    value: shortDateString(week.startDate),
                                    action: {
                                        activeWeekDatePicker = WeekDatePickerTarget(weekID: week.id, field: .start)
                                    }
                                )

                                Image(systemName: "arrow.right")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(RaverTheme.secondaryText)

                                weekDateField(
                                    title: LT("结束", "End", "終了"),
                                    value: shortDateString(week.endDate),
                                    action: {
                                        activeWeekDatePicker = WeekDatePickerTarget(weekID: week.id, field: .end)
                                    }
                                )
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
                        HStack {
                            Label(LT("添加一周", "Add Week", "週を追加"), systemImage: "plus.circle.fill")
                                .font(.subheadline.weight(.semibold))
                            Spacer()
                            Text(LT("继续拆分活动周期", "Split the schedule further", "さらに期間を分割"))
                                .font(.caption)
                                .foregroundStyle(RaverTheme.secondaryText)
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
                                viewModel.removeStage(at: index)
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
                    viewModel.locationSummary,
                ].filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            )

            reviewCard(
                title: LT("时间", "Time", "時間"),
                rows: [
                    viewModel.draft.scheduleMode.title,
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
        let isSelected = viewModel.draft.scheduleMode == mode
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
            DatePicker(
                title,
                selection: selection,
                displayedComponents: [.date]
            )
            .labelsHidden()
            .datePickerStyle(.compact)
            .tint(RaverTheme.accent)
            .environment(\.timeZone, eventTimeZone)
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
        let days = max((Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: week.startDate), to: Calendar.current.startOfDay(for: max(week.endDate, week.startDate))).day ?? 0) + 1, 1)
        return LT("\(days) 天", "\(days) days", "\(days)日")
    }

    private var uploadedImageCount: Int {
        EventUploadImageZone.allCases.reduce(into: 0) { partial, zone in
            partial += viewModel.draft.imageZones[zone]?.count ?? 0
        }
    }

    private var reviewCompletionValue: String {
        let filled = [
            !viewModel.draft.posterImages.isEmpty,
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

                Text(LT("当前设备", "Current Device", "現在の端末"))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(RaverTheme.secondaryText)
                    .padding(.top, 2)
                Text(formattedDateRange(timeZone: .current))
                    .font(.caption)
                    .foregroundStyle(RaverTheme.secondaryText)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(fieldBackground)
        }
    }

    private func formattedDateRange(timeZone: TimeZone) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.timeZone = timeZone
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return "\(formatter.string(from: viewModel.draft.startDate)) - \(formatter.string(from: viewModel.draft.endDate)) · \(timeZone.identifier)"
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
                inlineSearchFeedbackRow(
                    message: message,
                    systemImage: viewModel.organizerSearchFeedback.isFailure ? "exclamationmark.triangle.fill" : "building.2.crop.circle",
                    tint: viewModel.organizerSearchFeedback.isFailure ? .orange : RaverTheme.secondaryText
                )
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

    @ViewBuilder
    private func weekDatePickerSheet(target: WeekDatePickerTarget) -> some View {
        NavigationStack {
            VStack(spacing: 20) {
                DatePicker(
                    "",
                    selection: weekDateBinding(target: target),
                    displayedComponents: [.date]
                )
                .datePickerStyle(.graphical)
                .labelsHidden()
                .tint(RaverTheme.accent)
                .environment(\.timeZone, eventTimeZone)

                HStack {
                    Text(LT("当前选择", "Selected", "選択中"))
                        .font(.caption)
                        .foregroundStyle(RaverTheme.secondaryText)
                    Spacer()
                    Text(shortDateString(weekDateBinding(target: target).wrappedValue, in: eventTimeZone))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(RaverTheme.primaryText)
                }
                .padding(.horizontal, 4)

                Spacer()
            }
            .padding(20)
            .background(RaverTheme.background.ignoresSafeArea())
            .navigationTitle(LT("选择日期", "Select Date", "日付を選択"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(LT("完成", "Done", "完了")) {
                        activeWeekDatePicker = nil
                    }
                }
            }
        }
    }

    private func weekDateBinding(target: WeekDatePickerTarget) -> Binding<Date> {
        Binding {
            guard let week = viewModel.draft.weekRanges.first(where: { $0.id == target.weekID }) else {
                return Date()
            }
            return target.field == .start ? week.startDate : week.endDate
        } set: { value in
            if target.field == .start {
                viewModel.updateWeekRange(id: target.weekID, startDate: value)
            } else {
                viewModel.updateWeekRange(id: target.weekID, endDate: value)
            }
        }
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
        var calendar = Calendar.current
        calendar.timeZone = TimeZone(identifier: viewModel.draft.timeZoneIdentifier) ?? .current
        let startDay = calendar.startOfDay(for: viewModel.draft.startDate)
        let endDay = max(viewModel.draft.endDate, viewModel.draft.startDate)
        let dayCount = min(max((calendar.dateComponents([.day], from: startDay, to: calendar.startOfDay(for: endDay)).day ?? 0) + 1, 1), 60)
        return (0..<dayCount).map { offset in
            let date = calendar.date(byAdding: .day, value: offset, to: startDay) ?? startDay
            let title: String
            if viewModel.draft.scheduleMode == .multiWeek {
                title = LT("Week \(offset / 7 + 1) · Day \(offset % 7 + 1)", "Week \(offset / 7 + 1) · Day \(offset % 7 + 1)", "Week \(offset / 7 + 1) · Day \(offset % 7 + 1)")
            } else {
                title = LT("Day \(offset + 1)", "Day \(offset + 1)", "Day \(offset + 1)")
            }
            return EventUploadDayOption(dayIndex: offset + 1, title: title, date: date)
        }
    }

    private func alignLineupClock(_ value: Date, toDayIndex dayIndex: Int, dayOffset: EventUploadSlotDayOffset = .sameDay) -> Date {
        var calendar = Calendar.current
        calendar.timeZone = TimeZone(identifier: viewModel.draft.timeZoneIdentifier) ?? .current
        let components = calendar.dateComponents([.hour, .minute], from: value)
        let baseDay = calendar.date(byAdding: .day, value: max(dayIndex - 1, 0) + dayOffset.rawValue, to: calendar.startOfDay(for: viewModel.draft.startDate)) ?? viewModel.draft.startDate
        return calendar.date(bySettingHour: components.hour ?? 0, minute: components.minute ?? 0, second: 0, of: baseDay) ?? value
    }

    private func alignLineupDate(_ value: Date?, toDayIndex dayIndex: Int, dayOffset: EventUploadSlotDayOffset = .sameDay) -> Date? {
        guard let value else { return nil }
        return alignLineupClock(value, toDayIndex: dayIndex, dayOffset: dayOffset)
    }

    private var displayWeekRanges: [EventUploadWeekRangeDraft] {
        if viewModel.draft.scheduleMode == .multiWeek {
            return viewModel.draft.weekRanges
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

private struct EventUploadLineupAIImportSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: EventUploadFlowViewModel
    @State private var selectedImageID: UUID?
    @State private var isRunning = false
    @State private var isAutoMatching = false
    @State private var recognitionStartedAt: Date?
    @State private var autoMatchStartedAt: Date?
    @State private var statusMessage = LT("请选择一张已经上传到当前草稿里的阵容图。", "Choose one image from this draft for lineup recognition.", "この下書きに追加済みの画像からラインナップ認識に使う1枚を選んでください。")
    @State private var statusIsError = false
    @State private var resultItems: [EventUploadLineupAIEditableItem] = []
    @State private var warnings: [String] = []
    @State private var unparsedTexts: [String] = []
    @State private var expandedItemIDs: Set<UUID> = []

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
                    Button(LT("关闭", "Close", "閉じる")) { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 10) {
                        Button {
                            Task { await autoMatchCurrentItems() }
                        } label: {
                            Label(LT("一键匹配", "Auto Match", "一括紐付け"), systemImage: "wand.and.stars")
                        }
                        .disabled(isRunning || isAutoMatching || resultItems.isEmpty)

                        Button(LT("确认添加", "Apply", "追加")) {
                            viewModel.applyLineupAIImportItems(resultItems)
                            dismiss()
                        }
                        .disabled(isRunning || isAutoMatching || resultItems.isEmpty)
                    }
                }
            }
            .onAppear {
                if selectedImageID == nil {
                    selectedImageID = images.first(where: { $0.zone == .lineup })?.id ?? images.first?.id
                }
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
                Button {
                    Task { await runRecognition() }
                } label: {
                    Label(LT("确认并开始识别", "Run", "認識開始"), systemImage: "sparkles")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            LinearGradient(colors: [.pink, .orange, .blue, .cyan], startPoint: .topLeading, endPoint: .bottomTrailing),
                            in: Capsule()
                        )
                }
                .buttonStyle(.plain)
                .disabled(isRunning || selectedImage == nil)
            }

            if images.isEmpty {
                Text(LT("当前草稿还没有图片。请先回到第一页上传阵容图或相关图片。", "No images are available in this draft. Upload a lineup or related image first.", "この下書きには画像がありません。先に画像を追加してください。"))
                    .font(.caption)
                    .foregroundStyle(RaverTheme.secondaryText)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RaverTheme.card, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            } else {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    ForEach(images) { image in
                        Button {
                            guard !isRunning else { return }
                            selectedImageID = image.id
                        } label: {
                            VStack(alignment: .leading, spacing: 8) {
                                imagePreview(image)
                                Text(image.zone.title)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(RaverTheme.primaryText)
                                    .lineLimit(1)
                                Text(image.fileName)
                                    .font(.caption2)
                                    .foregroundStyle(RaverTheme.secondaryText)
                                    .lineLimit(1)
                            }
                            .padding(8)
                            .background(RaverTheme.card, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(selectedImageID == image.id ? RaverTheme.accent : RaverTheme.cardBorder, lineWidth: selectedImageID == image.id ? 2 : 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var statusSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            if isRunning || isAutoMatching {
                TimelineView(.periodic(from: Date(), by: 1)) { timeline in
                    HStack(spacing: 10) {
                        AIThinkingIndicator()
                        Spacer()
                        Text(elapsedText(since: isRunning ? recognitionStartedAt : autoMatchStartedAt, now: timeline.date))
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
            .disabled(isRunning || isAutoMatching || resultItems.isEmpty)

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
        ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(RaverTheme.background)
            if let localFileURL = image.localFileURL,
               let uiImage = UIImage(contentsOfFile: localFileURL.path) {
                Image(uiImage: uiImage).resizable().scaledToFill()
            } else if let remoteURL = image.remoteURL,
                      let url = URL(string: remoteURL) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let loaded):
                        loaded.resizable().scaledToFill()
                    default:
                        Image(systemName: "photo").foregroundStyle(RaverTheme.secondaryText)
                    }
                }
            } else {
                Image(systemName: "photo").foregroundStyle(RaverTheme.secondaryText)
            }
        }
        .frame(height: 104)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func runRecognition() async {
        guard let selectedImage else { return }
        isRunning = true
        recognitionStartedAt = Date()
        statusIsError = false
        statusMessage = LT("已提交识别任务，AI 正在分析阵容图。", "Recognition task submitted. AI is analyzing the lineup image.", "認識タスクを送信しました。AIがラインナップ画像を解析しています。")
        do {
            let result = try await viewModel.recognizeLineupFromImage(selectedImage)
            resultItems = result.items
            warnings = result.warnings
            unparsedTexts = result.unparsedTexts
            expandedItemIDs = []
            statusIsError = result.items.isEmpty
            statusMessage = result.items.isEmpty
                ? LT("没有识别到可用阵容。可以换一张更清晰的阵容图再试。", "No usable lineup items were recognized. Try a clearer lineup image.", "有効なラインナップを認識できませんでした。より鮮明な画像で再試行してください。")
                : LT("识别完成。请检查并修正结果，确认后会增量添加到仅阵容信息。", "Recognition finished. Review and edit the results, then apply them to lineup only.", "認識が完了しました。結果を確認・修正してからラインナップのみに追加してください。")
        } catch {
            statusIsError = true
            statusMessage = error.userFacingMessage ?? LT("阵容识别失败，请稍后重试。", "Lineup recognition failed. Please try again later.", "ラインナップ認識に失敗しました。しばらくしてから再試行してください。")
        }
        isRunning = false
        recognitionStartedAt = nil
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
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: EventUploadFlowViewModel
    @State private var selectedImageID: UUID?
    @State private var isRunning = false
    @State private var statusMessage = LT("请选择一张已经上传到当前草稿里的时间表图片。", "Choose one image from this draft for timetable recognition.", "この下書きに追加済みの画像からタイムテーブル認識に使う1枚を選んでください。")
    @State private var statusIsError = false
    @State private var resultSlots: [EventUploadTimetableAIEditableSlot] = []
    @State private var warnings: [String] = []
    @State private var unparsedTexts: [String] = []
    @State private var selectedWeekIndex: Int?
    @State private var selectedDayIndex: Int?
    @State private var selectedStageName: String?
    @State private var expandedSlotIDs: Set<UUID> = []
    @State private var isAutoMatching = false
    @State private var recognitionStartedAt: Date?
    @State private var autoMatchStartedAt: Date?

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
                    if !resultSlots.isEmpty {
                        filterSection
                        resultSection
                    }
                }
                .padding(16)
            }
            .background(RaverTheme.background.ignoresSafeArea())
            .navigationTitle(LT("AI 识别时间表", "AI Timetable Import", "AIタイムテーブル認識"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(LT("关闭", "Close", "閉じる")) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 10) {
                        Button {
                            Task { await autoMatchCurrentSlots() }
                        } label: {
                            Label(LT("一键匹配", "Auto Match", "一括紐付け"), systemImage: "wand.and.stars")
                        }
                        .disabled(isRunning || isAutoMatching || resultSlots.isEmpty)

                        Button(LT("确认添加", "Apply", "追加")) {
                            viewModel.applyTimetableAIImportSlots(resultSlots)
                            dismiss()
                        }
                        .disabled(isRunning || isAutoMatching || resultSlots.isEmpty)
                    }
                }
            }
            .onAppear {
                if selectedImageID == nil {
                    selectedImageID = images.first(where: { $0.zone == .timetable })?.id ?? images.first?.id
                }
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
                Button {
                    Task { await runRecognition() }
                } label: {
                    Label(LT("确认并开始识别", "Run", "認識開始"), systemImage: "sparkles")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            LinearGradient(
                                colors: [.pink, .orange, .blue, .cyan],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            in: Capsule()
                        )
                }
                .buttonStyle(.plain)
                .disabled(isRunning || selectedImage == nil)
            }

            if images.isEmpty {
                Text(LT("当前草稿还没有图片。请先回到第一页上传时间表图或相关图片。", "No images are available in this draft. Upload a timetable or related image first.", "この下書きには画像がありません。先に画像を追加してください。"))
                    .font(.caption)
                    .foregroundStyle(RaverTheme.secondaryText)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RaverTheme.card, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            } else {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    ForEach(images) { image in
                        Button {
                            guard !isRunning else { return }
                            selectedImageID = image.id
                        } label: {
                            VStack(alignment: .leading, spacing: 8) {
                                timetableAIImagePreview(image)
                                Text(image.zone.title)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(RaverTheme.primaryText)
                                    .lineLimit(1)
                                Text(image.fileName)
                                    .font(.caption2)
                                    .foregroundStyle(RaverTheme.secondaryText)
                                    .lineLimit(1)
                            }
                            .padding(8)
                            .background(RaverTheme.card, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(selectedImageID == image.id ? RaverTheme.accent : RaverTheme.cardBorder, lineWidth: selectedImageID == image.id ? 2 : 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var statusSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            if isRunning || isAutoMatching {
                TimelineView(.periodic(from: Date(), by: 1)) { timeline in
                    HStack(spacing: 10) {
                        AIThinkingIndicator()
                        Spacer()
                        Text(elapsedText(since: isRunning ? recognitionStartedAt : autoMatchStartedAt, now: timeline.date))
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

    private func runRecognition() async {
        guard let selectedImage else { return }
        isRunning = true
        recognitionStartedAt = Date()
        statusIsError = false
        statusMessage = LT("已提交识别任务，AI 正在分析时间表。这个过程可以稍等一会儿。", "Recognition task submitted. AI is analyzing the timetable.", "認識タスクを送信しました。AIがタイムテーブルを解析しています。")
        do {
                let result = try await viewModel.recognizeTimetableFromImage(selectedImage)
            resultSlots = result.slots
            warnings = result.warnings
            unparsedTexts = result.unparsedTexts
            configureResultFilters()
            statusIsError = result.slots.isEmpty
            statusMessage = result.slots.isEmpty
                ? LT("没有识别到可用节目。可以换一张更清晰的时间表图再试。", "No usable timetable sets were recognized. Try a clearer timetable image.", "有効なタイムテーブル項目を認識できませんでした。より鮮明な画像で再試行してください。")
                : LT("识别完成。请检查并修正结果，确认后会增量添加到当前时间表。", "Recognition finished. Review and edit the results, then apply them to the current timetable.", "認識が完了しました。結果を確認・修正してから現在のタイムテーブルに追加してください。")
        } catch {
            statusIsError = true
            statusMessage = error.userFacingMessage ?? LT("时间表识别失败，请稍后重试。", "Timetable recognition failed. Please try again later.", "タイムテーブル認識に失敗しました。しばらくしてから再試行してください。")
        }
        isRunning = false
        recognitionStartedAt = nil
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
                    get: { selectedDayIndex },
                    set: { value in
                        selectedDayIndex = value
                        syncAIResultScope()
                    }
                ),
                label: { dayLabel(for: $0) },
                value: { $0.dayIndex }
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
        ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(RaverTheme.background)
            if let localFileURL = image.localFileURL,
               let uiImage = UIImage(contentsOfFile: localFileURL.path) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
            } else if let remoteURL = image.remoteURL,
                      let url = URL(string: remoteURL) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let loaded):
                        loaded.resizable().scaledToFill()
                    default:
                        Image(systemName: "photo")
                            .foregroundStyle(RaverTheme.secondaryText)
                    }
                }
            } else {
                Image(systemName: "photo")
                    .foregroundStyle(RaverTheme.secondaryText)
            }
        }
        .frame(height: 104)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var availableWeeks: [Int] {
        Array(Set(resultSlots.map(\.weekIndex))).sorted()
    }

    private var availableDays: [EventUploadTimetableAIEditableSlot] {
        filteredByWeek
            .reduce(into: [Int: EventUploadTimetableAIEditableSlot]()) { dict, slot in
                if dict[slot.dayIndex] == nil {
                    dict[slot.dayIndex] = slot
                }
            }
            .values
            .sorted {
                if $0.dayIndex != $1.dayIndex { return $0.dayIndex < $1.dayIndex }
                return $0.dayLabel < $1.dayLabel
            }
    }

    private var availableStages: [String] {
        let values = filteredByWeekAndDay.map { $0.stageName.trimmingCharacters(in: .whitespacesAndNewlines) }
        return Array(Set(values.filter { !$0.isEmpty })).sorted()
    }

    private var filteredByWeek: [EventUploadTimetableAIEditableSlot] {
        guard let selectedWeekIndex else { return resultSlots }
        return resultSlots.filter { $0.weekIndex == selectedWeekIndex }
    }

    private var filteredByWeekAndDay: [EventUploadTimetableAIEditableSlot] {
        filteredByWeek.filter { selectedDayIndex == nil || $0.dayIndex == selectedDayIndex }
    }

    private var visibleSlots: [EventUploadTimetableAIEditableSlot] {
        filteredByWeekAndDay.filter { slot in
            guard let selectedStageName else { return true }
            return slot.stageName.trimmingCharacters(in: .whitespacesAndNewlines) == selectedStageName
        }
    }

    private func configureResultFilters() {
        selectedWeekIndex = availableWeeks.first
        selectedDayIndex = availableDays.first?.dayIndex
        selectedStageName = availableStages.first
        expandedSlotIDs = []
    }

    private func syncAIResultScope() {
        if let selectedWeekIndex, !availableWeeks.contains(selectedWeekIndex) {
            self.selectedWeekIndex = availableWeeks.first
        }
        if let selectedDayIndex, !availableDays.contains(where: { $0.dayIndex == selectedDayIndex }) {
            self.selectedDayIndex = availableDays.first?.dayIndex
        }
        if let selectedStageName, !availableStages.contains(selectedStageName) {
            self.selectedStageName = availableStages.first
        }
    }

    private func dayLabel(for slot: EventUploadTimetableAIEditableSlot) -> String {
        "Day \(slot.dayIndex)"
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
                Text(LT("识别结果", "Results", "認識結果"))
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(RaverTheme.primaryText)
                Spacer()
                Text(LT("共 \(resultSlots.count) 条", "\(resultSlots.count) items", "\(resultSlots.count)件"))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(RaverTheme.secondaryText)
            }

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
            .disabled(isRunning || isAutoMatching || resultSlots.isEmpty)

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
        let expanded = expandedSlotIDs.contains(slot.id)
        let performerNames = timetableAIPerformerNames(for: slot)
        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
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
                    Text("Week \(slot.weekIndex) · \(slot.dayLabel)")
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
                .stroke(RaverTheme.cardBorder, lineWidth: 1)
        )
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
        configureResultFilters()
        statusMessage = LT("已完成自动匹配，可继续确认导入。", "Auto match finished. You can continue and apply.", "自動紐付けが完了しました。続けて適用できます。")
        isAutoMatching = false
        autoMatchStartedAt = nil
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
    @Binding var expanded: Bool
    let primaryPlaceholder: String
    let primaryBinding: Binding<String>
    let zhBinding: Binding<String>
    let enBinding: Binding<String>
    let jaBinding: Binding<String>
    let englishFullBinding: Binding<String>?
    let extraCount: Int
    let preferredLanguage: EventUploadPreferredLanguage

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
    let onDelete: (UUID) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selectedStage: String = ""
    @State private var selectedDayIndex: Int = 1
    @State private var keyboardCandidateSpacing: CGFloat = 0

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

	                    VStack(alignment: .leading, spacing: 8) {
	                        HStack {
	                            Text(LT("节目列表", "Set List", "セット一覧"))
                                .font(.headline)
                                .foregroundStyle(RaverTheme.primaryText)
                            Spacer()
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

    private func shortDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.timeZone = eventTimeZone
        formatter.dateFormat = "M/d"
        return formatter.string(from: date)
    }

    private func slotCard(_ slot: EventUploadLineupSlotDraft, order: Int) -> some View {
        let expanded = isExpanded(slot.id) || !isCollapsedEligible(slot)
        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
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
                .stroke(RaverTheme.cardBorder, lineWidth: 1)
        )
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
