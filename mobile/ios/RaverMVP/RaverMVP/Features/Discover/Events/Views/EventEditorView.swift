import SwiftUI
import PhotosUI
import AVKit
import AVFoundation
import UIKit
import Photos
import CoreImage.CIFilterBuiltins
import MapKit
import CoreLocation
import CoreText

private struct UIKitInlineTextField: UIViewRepresentable {
    @Binding var text: String

    var placeholder: String = ""
    var keyboardType: UIKeyboardType = .default
    var textAlignment: NSTextAlignment = .natural
    var font: UIFont = .systemFont(ofSize: 13)
    var textColor: UIColor = .label
    var tintColor: UIColor = .label
    var maxLength: Int? = nil

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, maxLength: maxLength)
    }

    func makeUIView(context: Context) -> UITextField {
        let textField = UITextField()
        textField.borderStyle = .none
        textField.backgroundColor = .clear
        textField.placeholder = placeholder
        textField.keyboardType = keyboardType
        textField.textAlignment = textAlignment
        textField.font = font
        textField.textColor = textColor
        textField.tintColor = tintColor
        textField.autocorrectionType = .no
        textField.autocapitalizationType = .none
        textField.spellCheckingType = .no
        textField.delegate = context.coordinator
        textField.addTarget(context.coordinator, action: #selector(Coordinator.textDidChange(_:)), for: .editingChanged)
        return textField
    }

    func updateUIView(_ uiView: UITextField, context: Context) {
        uiView.placeholder = placeholder
        uiView.keyboardType = keyboardType
        uiView.textAlignment = textAlignment
        uiView.font = font
        uiView.textColor = textColor
        uiView.tintColor = tintColor
        if uiView.text != text {
            uiView.text = text
        }
        context.coordinator.maxLength = maxLength
    }

    final class Coordinator: NSObject, UITextFieldDelegate {
        @Binding var text: String
        var maxLength: Int?

        init(text: Binding<String>, maxLength: Int?) {
            _text = text
            self.maxLength = maxLength
        }

        @objc func textDidChange(_ textField: UITextField) {
            var next = textField.text ?? ""
            if let maxLength {
                next = String(next.prefix(maxLength))
                if textField.text != next {
                    textField.text = next
                }
            }
            if text != next {
                text = next
            }
        }
    }
}

private struct TimeAutoColonTextField: UIViewRepresentable {
    @Binding var text: String
    var placeholder: String = ""
    var onCommit: (() -> Void)? = nil

    func makeUIView(context: Context) -> UITextField {
        let textField = UITextField()
        textField.keyboardType = .numberPad
        textField.placeholder = placeholder
        textField.delegate = context.coordinator
        textField.font = .systemFont(ofSize: 12)
        textField.textAlignment = .center
        textField.textColor = .secondaryLabel
        textField.tintColor = .secondaryLabel
        return textField
    }

    func updateUIView(_ uiView: UITextField, context: Context) {
        if uiView.text != text {
            uiView.text = text
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    final class Coordinator: NSObject, UITextFieldDelegate {
        var parent: TimeAutoColonTextField

        init(_ parent: TimeAutoColonTextField) {
            self.parent = parent
        }

        func textField(
            _ textField: UITextField,
            shouldChangeCharactersIn range: NSRange,
            replacementString string: String
        ) -> Bool {
            let current = textField.text ?? ""

            if string.isEmpty {
                var digits = current.filter(\.isNumber)
                guard !digits.isEmpty else {
                    parent.text = ""
                    textField.text = ""
                    return false
                }
                digits.removeLast()
                let formatted = formatDigits(digits)
                textField.text = formatted
                parent.text = formatted
                return false
            }

            guard string.allSatisfy(\.isNumber) else { return false }

            var digits = current.filter(\.isNumber) + string
            if digits.count > 4 {
                digits = String(digits.prefix(4))
            }

            let formatted = formatDigits(digits)
            textField.text = formatted
            parent.text = formatted
            return false
        }

        private func formatDigits(_ digits: String) -> String {
            switch digits.count {
            case 0:
                return ""
            case 1, 2:
                return digits
            default:
                let hour = String(digits.prefix(2))
                let minute = String(digits.suffix(from: digits.index(digits.startIndex, offsetBy: 2)))
                return "\(hour):\(minute)"
            }
        }

        func textFieldDidEndEditing(_ textField: UITextField) {
            parent.onCommit?()
        }
    }
}

struct EventCheckinSelectionSheet: View {
    @Environment(\.dismiss) private var dismiss

    let eventName: String
    let options: [EventCheckinDayOption]
    let djOptionsByDayID: [String: [EventCheckinDJOption]]
    let initialSelectedDayIDs: Set<String>
    let initialSelectedDJIDsByDayID: [String: Set<String>]
    let confirmButtonTitle: String
    let destructiveButtonTitle: String?
    let onDelete: (() -> Void)?
    let onConfirm: ([String: Set<String>]) -> Void

    @State private var selectedDayIDs: Set<String>
    @State private var selectedDJIDsByDayID: [String: Set<String>]
    @State private var expandedDayIDs: Set<String>

    private var columns: [GridItem] {
        [
            GridItem(.flexible(minimum: 0), spacing: 10),
            GridItem(.flexible(minimum: 0), spacing: 10),
            GridItem(.flexible(minimum: 0), spacing: 10),
            GridItem(.flexible(minimum: 0), spacing: 10)
        ]
    }

    private var b2bColumns: [GridItem] {
        [
            GridItem(.flexible(minimum: 0), spacing: 10),
            GridItem(.flexible(minimum: 0), spacing: 10)
        ]
    }

    private var dayUnitLabel: String {
        options.contains(where: \.usesWeekLabel) ? L("Week/Day", "Week/Day") : L("Day", "Day")
    }

    init(
        eventName: String,
        options: [EventCheckinDayOption],
        djOptionsByDayID: [String: [EventCheckinDJOption]],
        initialSelectedDayIDs: Set<String> = [],
        initialSelectedDJIDsByDayID: [String: Set<String>] = [:],
        confirmButtonTitle: String = "",
        destructiveButtonTitle: String? = nil,
        onDelete: (() -> Void)? = nil,
        onConfirm: @escaping ([String: Set<String>]) -> Void
    ) {
        self.eventName = eventName
        self.options = options
        self.djOptionsByDayID = djOptionsByDayID
        self.initialSelectedDayIDs = initialSelectedDayIDs
        self.initialSelectedDJIDsByDayID = initialSelectedDJIDsByDayID
        self.confirmButtonTitle = confirmButtonTitle.isEmpty ? L("确认打卡", "Confirm Check-in") : confirmButtonTitle
        self.destructiveButtonTitle = destructiveButtonTitle
        self.onDelete = onDelete
        self.onConfirm = onConfirm
        _selectedDayIDs = State(initialValue: initialSelectedDayIDs)
        _selectedDJIDsByDayID = State(initialValue: initialSelectedDJIDsByDayID)
        _expandedDayIDs = State(initialValue: initialSelectedDayIDs)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text(eventName)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(RaverTheme.primaryText)
                        .lineLimit(2)

                    Text(L("勾选参加的\(dayUnitLabel)，展开后直接选择当天看过的 DJ", "Select attended \(dayUnitLabel), then expand to choose DJs you watched that day."))
                        .font(.subheadline)
                        .foregroundStyle(RaverTheme.secondaryText)

                    if !selectedDayIDs.isEmpty {
                        Text(L("已选 \(selectedDayIDs.count) 天 · \(selectedDJCount) 个演出", "Selected \(selectedDayIDs.count) days · \(selectedDJCount) acts"))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color(red: 0.82, green: 0.39, blue: 0.20))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color(red: 1.00, green: 0.94, blue: 0.90), in: Capsule())
                    }

                    VStack(spacing: 12) {
                        ForEach(options) { option in
                            daySelectionCard(option)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
            }
            .raverSystemNavigation(title: L("活动打卡", "Event Check-in"))
            .toolbar {
                if let destructiveButtonTitle, let onDelete {
                    ToolbarItem(placement: .bottomBar) {
                        Button(destructiveButtonTitle, role: .destructive) {
                            onDelete()
                            dismiss()
                        }
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(confirmButtonTitle) {
                        onConfirm(normalizedSelections())
                        dismiss()
                    }
                    .disabled(selectedDayIDs.isEmpty)
                }
            }
            .onAppear {
                applyInitialSelections()
            }
        }
        .raverEnableCustomSwipeBack(edgeRatio: 0.2)
    }

    private var selectedDJCount: Int {
        normalizedSelections().values.reduce(0) { $0 + $1.count }
    }

    private func daySelectionCard(_ option: EventCheckinDayOption) -> some View {
        let isSelected = selectedDayIDs.contains(option.id)
        let isExpanded = expandedDayIDs.contains(option.id)
        let djOptions = djOptionsByDayID[option.id] ?? []
        let selectedDJIDs = selectedDJIDsByDayID[option.id] ?? []

        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Button {
                    toggleDaySelection(option.id)
                } label: {
                    Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                        .font(.title3)
                        .foregroundStyle(isSelected ? RaverTheme.accent : RaverTheme.secondaryText)
                }
                .buttonStyle(.plain)

                Button {
                    toggleDayExpansion(option.id)
                } label: {
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(option.title)
                                .font(.headline)
                                .foregroundStyle(RaverTheme.primaryText)
                            Text(option.subtitle)
                                .font(.caption)
                                .foregroundStyle(RaverTheme.secondaryText)
                        }

                        Spacer(minLength: 8)

                        if isSelected || !selectedDJIDs.isEmpty {
                            Text(L("\(selectedDJIDs.count) 个演出", "\(selectedDJIDs.count) acts"))
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(RaverTheme.accent)
                        }

                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(RaverTheme.secondaryText)
                    }
                }
                .buttonStyle(.plain)
            }

            if isExpanded {
                if djOptions.isEmpty {
                    Text(L("这一天暂未配置可选 DJ，确认后会只记录该\(dayUnitLabel)的活动打卡。", "No DJ options are configured for this day. Confirming will record only this \(dayUnitLabel) event check-in."))
                        .font(.caption)
                        .foregroundStyle(RaverTheme.secondaryText)
                        .padding(.leading, 2)
                } else {
                    let grouped = groupedCheckinOptions(djOptions)

                    VStack(alignment: .leading, spacing: 12) {
                        if !grouped.b3b.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("B3B")
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(RaverTheme.secondaryText)
                                ForEach(grouped.b3b) { dj in
                                    checkinDJOptionButton(
                                        dj,
                                        dayID: option.id,
                                        selectedDJIDs: selectedDJIDs,
                                        avatarSize: .large
                                    )
                                }
                            }
                        }

                        if !grouped.b2b.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("B2B")
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(RaverTheme.secondaryText)
                                LazyVGrid(columns: b2bColumns, alignment: .leading, spacing: 12) {
                                    ForEach(grouped.b2b) { dj in
                                        checkinDJOptionButton(
                                            dj,
                                            dayID: option.id,
                                            selectedDJIDs: selectedDJIDs,
                                            avatarSize: .medium
                                        )
                                    }
                                }
                            }
                        }

                        if !grouped.others.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                if !grouped.b2b.isEmpty || !grouped.b3b.isEmpty {
                                    Text(LL("其他演出"))
                                        .font(.caption2.weight(.semibold))
                                        .foregroundStyle(RaverTheme.secondaryText)
                                }
                                LazyVGrid(columns: columns, alignment: .leading, spacing: 12) {
                                    ForEach(grouped.others) { dj in
                                        checkinDJOptionButton(
                                            dj,
                                            dayID: option.id,
                                            selectedDJIDs: selectedDJIDs,
                                            avatarSize: .small
                                        )
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RaverTheme.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(isSelected ? RaverTheme.accent.opacity(0.4) : Color.white.opacity(0.06), lineWidth: 1)
        )
    }

    private func toggleDaySelection(_ dayID: String) {
        if selectedDayIDs.contains(dayID) {
            selectedDayIDs.remove(dayID)
            selectedDJIDsByDayID[dayID] = nil
            expandedDayIDs.remove(dayID)
        } else {
            selectedDayIDs.insert(dayID)
            selectedDJIDsByDayID[dayID] = selectedDJIDsByDayID[dayID] ?? []
            expandedDayIDs.insert(dayID)
        }
    }

    private func toggleDayExpansion(_ dayID: String) {
        if expandedDayIDs.contains(dayID) {
            expandedDayIDs.remove(dayID)
        } else {
            selectedDJIDsByDayID[dayID] = selectedDJIDsByDayID[dayID] ?? []
            expandedDayIDs.insert(dayID)
        }
    }

    private func toggleDJSelection(dayID: String, djID: String) {
        if !selectedDayIDs.contains(dayID) {
            selectedDayIDs.insert(dayID)
        }
        var selected = selectedDJIDsByDayID[dayID] ?? []
        if selected.contains(djID) {
            selected.remove(djID)
        } else {
            selected.insert(djID)
        }
        selectedDJIDsByDayID[dayID] = selected
    }

    private func applyInitialSelections() {
        selectedDayIDs = initialSelectedDayIDs
        selectedDJIDsByDayID = initialSelectedDJIDsByDayID
        expandedDayIDs = initialSelectedDayIDs
    }

    private func normalizedSelections() -> [String: Set<String>] {
        var normalized: [String: Set<String>] = [:]
        for dayID in selectedDayIDs {
            normalized[dayID] = selectedDJIDsByDayID[dayID] ?? []
        }
        return normalized
    }

    private enum CheckinAvatarSize {
        case small
        case medium
        case large

        var frameWidth: CGFloat {
            switch self {
            case .small: return 56
            case .medium: return 132
            case .large: return 206
            }
        }

        var frameHeight: CGFloat {
            56
        }
    }

    private func groupedCheckinOptions(_ options: [EventCheckinDJOption]) -> (b3b: [EventCheckinDJOption], b2b: [EventCheckinDJOption], others: [EventCheckinDJOption]) {
        (
            b3b: options.filter { $0.actType == .b3b },
            b2b: options.filter { $0.actType == .b2b },
            others: options.filter { $0.actType != .b3b && $0.actType != .b2b }
        )
    }

    private func checkinDJOptionButton(
        _ option: EventCheckinDJOption,
        dayID: String,
        selectedDJIDs: Set<String>,
        avatarSize: CheckinAvatarSize
    ) -> some View {
        let djIsSelected = selectedDJIDs.contains(option.djID)

        return Button {
            toggleDJSelection(dayID: dayID, djID: option.djID)
        } label: {
            VStack(spacing: 7) {
                djAvatar(option, size: avatarSize)
                    .frame(width: avatarSize.frameWidth, height: avatarSize.frameHeight)
                    .shadow(
                        color: djIsSelected ? RaverTheme.accent.opacity(0.92) : .clear,
                        radius: djIsSelected ? 14 : 0,
                        x: 0,
                        y: djIsSelected ? 1 : 0
                    )
                    .shadow(
                        color: djIsSelected ? Color.black.opacity(0.28) : .clear,
                        radius: djIsSelected ? 6 : 0,
                        x: 0,
                        y: djIsSelected ? 3 : 0
                    )

                Text(option.name)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(RaverTheme.primaryText)
                    .lineLimit(3)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }

    private func performerAvatar(_ performer: EventLineupPerformer?, fallbackName: String, size: CGFloat) -> some View {
        let performerName = performer?.name.trimmingCharacters(in: .whitespacesAndNewlines) ?? fallbackName
        return Group {
            if let avatar = AppConfig.resolvedDJAvatarURLString(performer?.avatarUrl, size: .small) {
                ImageLoaderView(urlString: avatar)
                    .background(Circle().fill(RaverTheme.card))
            } else {
                Circle()
                    .fill(RaverTheme.card)
                    .overlay(
                        Text(String((performerName.isEmpty ? "?" : performerName).prefix(1)).uppercased())
                            .font(.system(size: max(9, size * 0.33), weight: .bold))
                            .foregroundStyle(RaverTheme.secondaryText)
                    )
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }

    private func actConnectorLabel(text: String, color: Color, vertical: Bool) -> some View {
        Text("B")
            .font(.system(size: vertical ? 8.5 : 7.5, weight: .bold, design: .rounded))
            .foregroundStyle(color)
            .frame(width: vertical ? 10 : 12, height: vertical ? 10 : 12)
            .background(color.opacity(0.14), in: Circle())
            .scaleEffect(vertical ? 1.2 : 1.12)
            .frame(width: vertical ? 10 : 16, height: vertical ? 24 : 14)
    }

    @ViewBuilder
    private func djAvatar(_ option: EventCheckinDJOption, size: CheckinAvatarSize) -> some View {
        if option.actType == .solo {
            performerAvatar(option.performers.first, fallbackName: option.name, size: min(size.frameWidth, size.frameHeight))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            let performers = Array(option.performers.prefix(option.actType.performerCount))
            let b2bColor = Color(red: 0.98, green: 0.52, blue: 0.20)
            let b3bColor = Color(red: 0.18, green: 0.74, blue: 0.92)
            let avatarSize = min(size.frameWidth, size.frameHeight)

            HStack(spacing: 10) {
                ForEach(Array(performers.enumerated()), id: \.offset) { index, performer in
                    performerAvatar(performer, fallbackName: performer.name, size: avatarSize)
                    if index < performers.count - 1 {
                        actConnectorLabel(
                            text: option.actType == .b2b ? "B2B" : "B3B",
                            color: option.actType == .b2b ? b2bColor : b3bColor,
                            vertical: true
                        )
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
    }
}

private enum DJCheckinSubmission {
    case eventBinding(eventID: String, attendedAt: Date)
    case manual(eventName: String, attendedAt: Date)
}

private struct DJCheckinEventBindingOption: Identifiable, Hashable {
    let id: String
    let name: String
    let city: String?
    let country: String?
    let attendedAt: Date?
    let startDate: Date?
}

private struct DJCheckinBindingSheet: View {
    private enum Mode: String, CaseIterable, Identifiable {
        case bindEvent
        case manual

        var id: String { rawValue }
        var title: String {
            switch self {
            case .bindEvent: return L("绑定活动", "Bind Event")
            case .manual: return L("手动填写", "Manual Input")
            }
        }
    }

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appContainer: AppContainer

    private var eventsRepository: DiscoverEventsRepository {
        appContainer.discoverEventsRepository
    }

    let djName: String
    let onConfirm: (DJCheckinSubmission) -> Void

    @State private var mode: Mode = .bindEvent
    @State private var eventSearchText = ""
    @State private var historyOptions: [DJCheckinEventBindingOption] = []
    @State private var remoteOptions: [DJCheckinEventBindingOption] = []
    @State private var selectedEventID: String?
    @State private var manualEventName = ""
    @State private var manualAttendedAt = Date()
    @State private var isLoadingHistory = false
    @State private var isSearchingEvents = false
    @State private var searchTask: Task<Void, Never>?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker(LL("打卡方式"), selection: $mode) {
                        ForEach(Mode.allCases) { item in
                            Text(item.title).tag(item)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                if mode == .bindEvent {
                    Section(LL("绑定到活动（优先）")) {
                        TextField(L("搜索活动名称", "Search event name"), text: $eventSearchText)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled(true)

                        if isLoadingHistory && historyOptions.isEmpty {
                            ProgressView(LL("读取你的活动历史..."))
                        }

                        if !filteredHistoryOptions.isEmpty {
                            Text(LL("我的活动历史"))
                                .font(.caption)
                                .foregroundStyle(RaverTheme.secondaryText)

                            ForEach(filteredHistoryOptions) { option in
                                eventOptionRow(option)
                            }
                        }

                        if !eventSearchKeyword.isEmpty {
                            Text(LL("搜索结果"))
                                .font(.caption)
                                .foregroundStyle(RaverTheme.secondaryText)

                            if isSearchingEvents {
                                ProgressView(LL("搜索活动中..."))
                            } else if remoteOptions.isEmpty {
                                Text(LL("没有更多匹配活动"))
                                    .font(.caption)
                                    .foregroundStyle(RaverTheme.secondaryText)
                            } else {
                                ForEach(remoteOptions) { option in
                                    eventOptionRow(option)
                                }
                            }
                        }

                        if let selectedOption {
                            Text(L("将自动按活动时间记录打卡：\(autoAttendedAt(for: selectedOption).appLocalizedYMDHMText())", "Check-in time will follow event schedule automatically: \(autoAttendedAt(for: selectedOption).appLocalizedYMDHMText())"))
                                .font(.caption)
                                .foregroundStyle(RaverTheme.secondaryText)
                        } else {
                            Text(LL("请在搜索或历史中选择一场活动。"))
                                .font(.caption)
                                .foregroundStyle(RaverTheme.secondaryText)
                        }
                    }
                } else {
                    Section(LL("手动填写")) {
                        TextField(LL("活动名称"), text: $manualEventName)
                        DatePicker(
                            L("观演时间", "Attended Time"),
                            selection: $manualAttendedAt,
                            in: ...Date(),
                            displayedComponents: [.date, .hourAndMinute]
                        )
                    }
                }
            }
            .raverSystemNavigation(title: L("\(djName) 打卡", "\(djName) Check-in"))
            .task {
                await loadHistory()
            }
            .onChange(of: eventSearchText) { _, _ in
                guard mode == .bindEvent else { return }
                searchTask?.cancel()
                searchTask = Task {
                    try? await Task.sleep(nanoseconds: 280_000_000)
                    guard !Task.isCancelled else { return }
                    await searchEvents()
                }
            }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L("确认打卡", "Confirm Check-in")) {
                        switch mode {
                        case .bindEvent:
                            guard let selectedOption else { return }
                            onConfirm(
                                .eventBinding(
                                    eventID: selectedOption.id,
                                    attendedAt: autoAttendedAt(for: selectedOption)
                                )
                            )
                        case .manual:
                            let trimmed = manualEventName.trimmingCharacters(in: .whitespacesAndNewlines)
                            guard !trimmed.isEmpty else { return }
                            onConfirm(.manual(eventName: trimmed, attendedAt: manualAttendedAt))
                        }
                        dismiss()
                    }
                    .disabled(!canConfirm)
                }
            }
        }
        .raverEnableCustomSwipeBack(edgeRatio: 0.2)
    }

    @ViewBuilder
    private func eventOptionRow(_ option: DJCheckinEventBindingOption) -> some View {
        Button {
            selectedEventID = option.id
        } label: {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(option.name)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(RaverTheme.primaryText)
                        .lineLimit(1)

                    Text(eventOptionSubtitle(option))
                        .font(.caption)
                        .foregroundStyle(RaverTheme.secondaryText)
                        .lineLimit(1)
                }
                Spacer()
                if selectedEventID == option.id {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(RaverTheme.accent)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private var canConfirm: Bool {
        switch mode {
        case .bindEvent:
            return selectedOption != nil
        case .manual:
            return !manualEventName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    private var eventSearchKeyword: String {
        eventSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var filteredHistoryOptions: [DJCheckinEventBindingOption] {
        guard !eventSearchKeyword.isEmpty else { return historyOptions }
        let keyword = eventSearchKeyword.lowercased()
        return historyOptions.filter { option in
            option.name.lowercased().contains(keyword)
                || (option.city?.lowercased().contains(keyword) ?? false)
                || (option.country?.lowercased().contains(keyword) ?? false)
        }
    }

    private var selectedOption: DJCheckinEventBindingOption? {
        guard let selectedEventID else { return nil }
        return (historyOptions + remoteOptions).first(where: { $0.id == selectedEventID })
    }

    private func autoAttendedAt(for option: DJCheckinEventBindingOption) -> Date {
        if let attendedAt = option.attendedAt {
            return min(attendedAt, Date())
        }
        if let startDate = option.startDate {
            return min(startDate, Date())
        }
        return Date()
    }

    private func eventOptionSubtitle(_ option: DJCheckinEventBindingOption) -> String {
        let location = [option.city, option.country]
            .compactMap { value in
                guard let value, !value.isEmpty else { return nil }
                return value
            }
            .joined(separator: " · ")

        if let attendedAt = option.attendedAt {
            let attendedText = attendedAt.appLocalizedYMDHMText()
            return location.isEmpty
                ? L("我参加于 \(attendedText)", "I attended at \(attendedText)")
                : L("\(location) · 我参加于 \(attendedText)", "\(location) · I attended at \(attendedText)")
        }

        if let startDate = option.startDate {
            let startText = startDate.appLocalizedYMDHMText()
            return location.isEmpty
                ? L("开始于 \(startText)", "Starts at \(startText)")
                : L("\(location) · 开始于 \(startText)", "\(location) · Starts at \(startText)")
        }

        return location.isEmpty ? L("活动信息", "Event info") : location
    }

    private func loadHistory() async {
        guard !isLoadingHistory else { return }
        isLoadingHistory = true
        defer { isLoadingHistory = false }

        do {
            let page = try await eventsRepository.fetchMyCheckins(page: 1, limit: 200, type: nil)
            var latestByEventID: [String: DJCheckinEventBindingOption] = [:]

            for item in page.items {
                guard let event = item.event else { continue }
                let candidate = DJCheckinEventBindingOption(
                    id: event.id,
                    name: event.name,
                    city: event.city,
                    country: event.country,
                    attendedAt: item.attendedAt,
                    startDate: event.startDate
                )

                if let existing = latestByEventID[event.id] {
                    if item.attendedAt > (existing.attendedAt ?? .distantPast) {
                        latestByEventID[event.id] = candidate
                    }
                } else {
                    latestByEventID[event.id] = candidate
                }
            }

            historyOptions = latestByEventID.values.sorted {
                ($0.attendedAt ?? $0.startDate ?? .distantPast) > ($1.attendedAt ?? $1.startDate ?? .distantPast)
            }

            if selectedEventID == nil {
                selectedEventID = historyOptions.first?.id
            }
        } catch {
            // Keep sheet usable even if history loading fails.
            historyOptions = []
        }
    }

    private func searchEvents() async {
        let keyword = eventSearchKeyword
        guard !keyword.isEmpty else {
            remoteOptions = []
            isSearchingEvents = false
            return
        }

        isSearchingEvents = true
        defer { isSearchingEvents = false }

        do {
            let page = try await eventsRepository.fetchEvents(
                request: DiscoverEventsPageRequest(
                    page: 1,
                    limit: 20,
                    search: keyword,
                    eventType: nil,
                    status: "all"
                )
            )

            if Task.isCancelled || keyword != eventSearchKeyword {
                return
            }

            let historyIDs = Set(historyOptions.map(\.id))
            remoteOptions = page.items
                .filter { !historyIDs.contains($0.id) }
                .map {
                    DJCheckinEventBindingOption(
                        id: $0.id,
                        name: $0.name,
                        city: $0.city,
                        country: $0.country,
                        attendedAt: nil,
                        startDate: $0.startDate
                    )
                }
        } catch {
            if keyword == eventSearchKeyword {
                remoteOptions = []
            }
        }
    }
}


struct EventEditorView: View {
    enum Mode {
        case create
        case edit(WebEvent)

        var title: String {
            switch self {
            case .create: return L("发布活动", "Create Event")
            case .edit: return L("编辑活动", "Edit Event")
            }
        }
    }

    private static let eventTypeOptionKeys = EventTypeOption.allCases.map(\.rawValue)
    private static func normalizedStartOfDay(_ date: Date) -> Date {
        Calendar.current.startOfDay(for: date)
    }

    private static func normalizedEndOfDay(_ date: Date) -> Date {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: date)
        return calendar.date(byAdding: DateComponents(day: 1, second: -1), to: start) ?? start
    }

    private struct EditableLineupPerformer: Identifiable, Hashable {
        let id: UUID
        var djId: String?
        var djName: String

        init(id: UUID = UUID(), djId: String? = nil, djName: String = "") {
            self.id = id
            self.djId = djId
            self.djName = djName
        }
    }

    private struct EditableLineupSlot: Identifiable, Hashable {
        let id: UUID
        var actType: EventLineupActType
        var performers: [EditableLineupPerformer]
        var stageName: String
        var dayID: String?
        var startTime: Date?
        var endTime: Date?
        var isEditing: Bool

        init(
            id: UUID = UUID(),
            actType: EventLineupActType = .solo,
            performers: [EditableLineupPerformer],
            stageName: String = "",
            dayID: String? = nil,
            startTime: Date? = nil,
            endTime: Date? = nil,
            isEditing: Bool = false
        ) {
            self.id = id
            self.actType = actType
            self.performers = performers
            self.stageName = stageName
            self.dayID = dayID
            self.startTime = startTime
            self.endTime = endTime
            self.isEditing = isEditing
        }

        var displayName: String {
            EventLineupActCodec.composeName(type: actType, performerNames: performers.map(\.djName))
        }
    }

    private struct EditorDayOption: Identifiable, Hashable {
        let id: String
        let dayIndex: Int
        let date: Date
        let weekIndex: Int?
        let dayInWeek: Int?

        var title: String { "Day\(dayIndex)" }

        var weekDayTitle: String {
            if let weekIndex, let dayInWeek {
                return EventWeekScheduleMode.weekDayTitle(week: weekIndex, day: dayInWeek)
            }
            return title
        }
    }

    private struct LineupTimeDraft: Hashable {
        var startText: String
        var endText: String
        var durationText: String
        var endNextDay: Bool
    }

    private enum LineupTimeApplySource {
        case startOrEndText
        case durationText
        case endDayToggle
    }

    private struct TicketTierDraft: Identifiable, Hashable {
        let id: UUID
        var name: String
        var price: String
        var currency: String

        init(id: UUID = UUID(), name: String = "", price: String = "", currency: String = "CNY") {
            self.id = id
            self.name = name
            self.price = price
            self.currency = currency
        }
    }

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appContainer: AppContainer

    private var eventsRepository: DiscoverEventsRepository {
        appContainer.discoverEventsRepository
    }

    private var djsRepository: DiscoverDJsRepository {
        appContainer.discoverDJsRepository
    }

    let mode: Mode
    let onSaved: () -> Void

    @State private var name = ""
    @State private var description = ""
    @State private var eventType = ""
    @State private var cityEn = ""
    @State private var cityZh = ""
    @State private var countryEn = ""
    @State private var countryEnFull = ""
    @State private var countryZh = ""
    @State private var detailAddressZh = ""
    @State private var detailAddressEn = ""
    @State private var ticketUrl = ""
    @State private var officialWebsite = ""
    @State private var ticketCurrency = "CNY"
    @State private var ticketNotes = ""
    @State private var ticketTierDrafts: [TicketTierDraft] = []
    @State private var pickedLatitude: Double?
    @State private var pickedLongitude: Double?
    @State private var pickedMapAddress = ""
    @State private var pickedPlaceName = ""
    @State private var showLocationPicker = false
    @State private var startDate = EventEditorView.normalizedStartOfDay(Date())
    @State private var endDate = EventEditorView.normalizedStartOfDay(Date())
    @State private var isWeekScheduleEnabled = false
    @State private var coverImageUrl = ""
    @State private var lineupImageUrl = ""
    @State private var selectedCoverPhoto: PhotosPickerItem?
    @State private var selectedLineupPhoto: PhotosPickerItem?
    @State private var selectedLineupImportPhoto: PhotosPickerItem?
    @State private var selectedCoverData: Data?
    @State private var selectedLineupData: Data?
    @State private var lineupImportDraftEntries: [EditableLineupSlot] = []
    @State private var lineupImportRawText = ""
    @State private var isImportingLineupImage = false
    @State private var isApplyingLineupImport = false
    @State private var isParsingLineupImportJSON = false
    @State private var lineupImportShouldReplaceExistingEntries = false
    @State private var showLineupImportEditor = false
    @State private var lineupEntries: [EditableLineupSlot] = []
    @State private var pendingLineupEntry: EditableLineupSlot?
    @State private var stageEntries: [String] = [""]
    @State private var lineupTimeDraftBySlotID: [UUID: LineupTimeDraft] = [:]
    @State private var djQueryByPerformerID: [UUID: String] = [:]
    @State private var djCandidatesByPerformerID: [UUID: [WebDJ]] = [:]
    @State private var isSearchingDJPerformerIDs: Set<UUID> = []
    @State private var djSearchTaskByPerformerID: [UUID: Task<Void, Never>] = [:]
    @State private var prefillHydrationTask: Task<Void, Never>?
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var importSuccessMessage: String?

    var body: some View {
        Form {
                Section(LL("基础信息")) {
                    TextField(LL("活动名称"), text: $name)
                    TextField(LL("简介"), text: $description, axis: .vertical)
                    Picker(LL("活动性质"), selection: $eventType) {
                        Text(EventTypeOption.pickerPrompt).tag("")
                        ForEach(Self.eventTypeOptionKeys, id: \.self) { key in
                            Text(EventTypeOption.displayTitle(for: key)).tag(key)
                        }
                    }
                    TextField(L("City (English)", "City (English)"), text: $cityEn)
                    TextField(LL("城市（中文）"), text: $cityZh)
                    TextField(L("Country (English)", "Country (English)"), text: $countryEn)
                    TextField(L("Country (English Full)", "Country (English Full)"), text: $countryEnFull)
                    TextField(LL("国家（中文）"), text: $countryZh)
                    TextField(LL("详细地址（中文）"), text: $detailAddressZh, axis: .vertical)
                    TextField(L("Detailed Address (English)", "Detailed Address (English)"), text: $detailAddressEn, axis: .vertical)
                    TextField(LL("购票链接（可选）"), text: $ticketUrl)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)
                }

                Section(LL("场地定位")) {
                    Button {
                        showLocationPicker = true
                    } label: {
                        Label(LL("地图选点"), systemImage: "map")
                    }

                    if let lat = pickedLatitude, let lng = pickedLongitude {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(LL("已选定位"))
                                .font(.caption)
                                .foregroundStyle(RaverTheme.secondaryText)
                            Text("\(lat), \(lng)")
                                .font(.caption2)
                                .foregroundStyle(RaverTheme.secondaryText)
                            if !pickedMapAddress.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                Text(L("定位地址：\(pickedMapAddress)", "Address: \(pickedMapAddress)"))
                                    .font(.caption2)
                                    .foregroundStyle(RaverTheme.secondaryText)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    } else {
                        Text(LL("尚未在地图选择定位，仍可仅使用手动输入地址。"))
                            .font(.caption)
                            .foregroundStyle(RaverTheme.secondaryText)
                    }
                }

                Section(LL("票务信息")) {
                    TextField(LL("官网链接（可选）"), text: $officialWebsite)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)

                    TextField(LL("默认币种（例如 CNY / USD）"), text: $ticketCurrency)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled(true)

                    TextField(LL("票务备注（可选）"), text: $ticketNotes, axis: .vertical)

                    if ticketTierDrafts.isEmpty {
                        Text(LL("暂无票档，点击下方按钮添加。"))
                            .font(.caption)
                            .foregroundStyle(RaverTheme.secondaryText)
                    } else {
                        ForEach(ticketTierDrafts.indices, id: \.self) { index in
                            VStack(alignment: .leading, spacing: 8) {
                                HStack(spacing: 8) {
                                    TextField(LL("票档名称（如 Early Bird）"), text: Binding(
                                        get: { ticketTierDrafts[index].name },
                                        set: { ticketTierDrafts[index].name = $0 }
                                    ))
                                    Button(role: .destructive) {
                                        ticketTierDrafts.remove(at: index)
                                    } label: {
                                        Image(systemName: "trash")
                                    }
                                }

                                HStack(spacing: 8) {
                                    TextField(LL("价格"), text: Binding(
                                        get: { ticketTierDrafts[index].price },
                                        set: { ticketTierDrafts[index].price = $0 }
                                    ))
                                    .keyboardType(.decimalPad)

                                    TextField(LL("币种"), text: Binding(
                                        get: { ticketTierDrafts[index].currency },
                                        set: { ticketTierDrafts[index].currency = $0 }
                                    ))
                                    .textInputAutocapitalization(.characters)
                                    .autocorrectionDisabled(true)
                                    .frame(width: 88)
                                }
                            }
                            .padding(.vertical, 2)
                        }
                    }

                    Button {
                        let fallbackCurrency = ticketCurrency.trimmingCharacters(in: .whitespacesAndNewlines)
                        ticketTierDrafts.append(
                            TicketTierDraft(currency: fallbackCurrency.isEmpty ? "CNY" : fallbackCurrency)
                        )
                    } label: {
                        Label(LL("添加票档"), systemImage: "plus")
                    }
                }

                Section(LL("时间")) {
                    DatePicker(
                        L("开始日期", "Start Date"),
                        selection: Binding(
                            get: { startDate },
                            set: { newValue in
                                let normalized = Self.normalizedStartOfDay(newValue)
                                startDate = normalized
                                endDate = normalized
                            }
                        ),
                        displayedComponents: [.date]
                    )
                    DatePicker(
                        L("结束日期", "End Date"),
                        selection: Binding(
                            get: { endDate },
                            set: { newValue in
                                endDate = Self.normalizedStartOfDay(newValue)
                            }
                        ),
                        in: startDate...,
                        displayedComponents: [.date]
                    )

                    Toggle(LL("启用多 Week 时间表"), isOn: $isWeekScheduleEnabled)
                    if isWeekScheduleEnabled {
                        Text(LL("已启用后，DJ 时间可按 WeekN · DayN 选择；未启用则按 DayN 选择。"))
                            .font(.caption)
                            .foregroundStyle(RaverTheme.secondaryText)
                    }
                }

                Section(LL("图片")) {
                    VStack(alignment: .leading, spacing: 8) {
                        PhotosPicker(selection: $selectedCoverPhoto, matching: .images) {
                            Label(LL("上传活动封面图"), systemImage: "photo")
                        }
                        eventImagePreview(selectedData: selectedCoverData, remoteURL: coverImageUrl)
                        if selectedCoverData != nil || !coverImageUrl.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Button(role: .destructive) {
                                selectedCoverPhoto = nil
                                selectedCoverData = nil
                                coverImageUrl = ""
                            } label: {
                                Label(LL("移除封面图"), systemImage: "trash")
                            }
                            .buttonStyle(.borderless)
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        PhotosPicker(selection: $selectedLineupPhoto, matching: .images) {
                            Label(LL("上传活动阵容图"), systemImage: "photo.on.rectangle")
                        }
                        eventImagePreview(selectedData: selectedLineupData, remoteURL: lineupImageUrl)
                        if selectedLineupData != nil || !lineupImageUrl.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Button(role: .destructive) {
                                selectedLineupPhoto = nil
                                selectedLineupData = nil
                                lineupImageUrl = ""
                            } label: {
                                Label(LL("移除阵容图"), systemImage: "trash")
                            }
                            .buttonStyle(.borderless)
                        }
                    }

                    Text(LL("仅支持从系统相册选择图片；保存后将上传并绑定到该活动。"))
                        .font(.caption)
                        .foregroundStyle(RaverTheme.secondaryText)
                }

                Section(LL("舞台信息")) {
                    Text(L("已配置 \(normalizedStageEntries.count) 个舞台", "\(normalizedStageEntries.count) stages configured"))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(RaverTheme.secondaryText)

                    ForEach(stageEntries.indices, id: \.self) { index in
                        HStack(spacing: 10) {
                            TextField(L("舞台\(index + 1)", "Stage \(index + 1)"), text: Binding(
                                get: { stageEntries[index] },
                                set: { stageEntries[index] = $0 }
                            ))
                            .textInputAutocapitalization(.words)

                            Button {
                                moveStageEntry(from: index, to: index - 1)
                            } label: {
                                Image(systemName: "arrow.up")
                            }
                            .disabled(index == 0)

                            Button {
                                moveStageEntry(from: index, to: index + 1)
                            } label: {
                                Image(systemName: "arrow.down")
                            }
                            .disabled(index >= stageEntries.count - 1)

                            Button(role: .destructive) {
                                stageEntries.remove(at: index)
                            } label: {
                                Image(systemName: "trash")
                            }
                            .disabled(stageEntries.count == 1)
                        }
                    }

                    Button {
                        stageEntries.append("")
                    } label: {
                        Label(LL("新增舞台"), systemImage: "plus")
                    }
                }

                Section(LL("已添加阵容")) {
                    PhotosPicker(selection: $selectedLineupImportPhoto, matching: .images) {
                        Label(
                            isImportingLineupImage ? L("阵容图识别中...", "Recognizing lineup image...") : L("从阵容图识别并导入", "Recognize from lineup image"),
                            systemImage: "text.viewfinder"
                        )
                    }
                    .disabled(isImportingLineupImage || isSaving)

                    if isImportingLineupImage {
                        HStack(spacing: 8) {
                            ProgressView()
                                .controlSize(.small)
                            Text(LL("正在识别图片并生成导入草稿..."))
                                .font(.caption)
                                .foregroundStyle(RaverTheme.secondaryText)
                        }
                    }

                    Button {
                        openLineupImportEditorForJSON()
                    } label: {
                        Label(LL("通过 JSON 文本导入"), systemImage: "curlybraces.square")
                    }
                    .disabled(isImportingLineupImage || isSaving)

                    Button {
                        addEmptyLineupSlot()
                    } label: {
                        Label(LL("添加 DJ"), systemImage: "plus")
                    }
                    .disabled(pendingLineupEntry != nil)

                    Button(role: .destructive) {
                        clearAllLineupEntries()
                    } label: {
                        Label(LL("一键清空已添加 DJ"), systemImage: "trash")
                    }
                    .disabled(lineupEntries.isEmpty && pendingLineupEntry == nil)

                    if let pendingBinding = pendingLineupSlotBinding {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(LL("新增 DJ（点击右侧勾勾后并入下方列表）"))
                                .font(.caption)
                                .foregroundStyle(RaverTheme.secondaryText)
                            lineupEntryEditor(pendingBinding, isPending: true)
                                .padding(.vertical, 2)
                        }
                    }

                    if lineupEntries.isEmpty {
                        Text(LL("尚未添加 DJ，点击上方按钮新增。"))
                            .font(.subheadline)
                            .foregroundStyle(RaverTheme.secondaryText)
                    } else {
                        ForEach(groupedLineupSlotGroups, id: \.stageName) { group in
                            VStack(alignment: .leading, spacing: 6) {
                                Text(group.stageName)
                                    .font(.subheadline.weight(.bold))
                                    .foregroundStyle(Color.white)
                                    .frame(maxWidth: .infinity, alignment: .center)
                                    .padding(.vertical, 2)
                                ForEach(Array(group.slotIDs.enumerated()), id: \.element) { index, slotID in
                                    lineupEntryRow(for: slotID)
                                    if index < group.slotIDs.count - 1 {
                                        lineupItemDivider
                                            .padding(.vertical, 0)
                                    }
                                }
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .raverSystemNavigation(title: mode.title)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(isSaving ? L("保存中...", "Saving...") : L("保存", "Save")) {
                        Task { await save() }
                    }
                    .disabled(isSaving)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button(L("收起", "Collapse")) {
                        dismissKeyboard()
                    }
                }
            }
            .task {
                prefillIfNeeded()
            }
            .onChange(of: selectedCoverPhoto) { _, newValue in
                Task { await loadSelectedEventImage(newValue, target: .cover) }
            }
            .onChange(of: selectedLineupPhoto) { _, newValue in
                Task { await loadSelectedEventImage(newValue, target: .lineup) }
            }
            .onChange(of: selectedLineupImportPhoto) { _, newValue in
                Task { await importLineupFromImage(newValue) }
            }
            .alert(L("提示", "Notice"), isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button(L("确定", "OK"), role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
            .overlay(alignment: .top) {
                if let importSuccessMessage {
                    Text(importSuccessMessage)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(Color.green.opacity(0.9))
                        )
                        .padding(.top, 10)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .navigationDestination(isPresented: $showLineupImportEditor) {
                lineupImportEditorSheet()
            }
            .navigationDestination(isPresented: $showLocationPicker) {
                EventLocationPickerSheet(
                    initialLatitude: pickedLatitude,
                    initialLongitude: pickedLongitude,
                    initialAddress: pickedMapAddress
                ) { result in
                    pickedLatitude = result.latitude
                    pickedLongitude = result.longitude
                    pickedMapAddress = result.displayAddress
                    pickedPlaceName = result.placeName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

                    if !result.displayAddress.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        if detailAddressZh.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            detailAddressZh = result.displayAddress
                        }
                        if detailAddressEn.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            detailAddressEn = result.displayAddress
                        }
                    }
                    if let city = result.city, !city.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        if cityZh.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            cityZh = city
                        }
                        if cityEn.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            cityEn = city
                        }
                    }
                    if let country = result.country, !country.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        if countryZh.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            countryZh = country
                        }
                        if countryEn.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            countryEn = country
                        }
                        if countryEnFull.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            countryEnFull = country
                        }
                    }
                }
            }
            .onChange(of: showLineupImportEditor) { _, isPresented in
                if !isPresented {
                    resetLineupImportDrafts()
                }
            }
    }

    private var normalizedStageEntries: [String] {
        let trimmed = stageEntries
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return Array(NSOrderedSet(array: trimmed)) as? [String] ?? trimmed
    }

    private struct StageLineupGroup: Identifiable, Hashable {
        var id: String { stageName }
        let stageName: String
        let slotIDs: [UUID]
    }

    private var dayOptions: [EditorDayOption] {
        let calendar = Calendar.current
        let startDay = calendar.startOfDay(for: startDate)
        let candidateDates = editorDayDates()
        var allDates = Set(candidateDates.map { calendar.startOfDay(for: $0) })

        // Preserve already selected lineup dates so toggling Week mode won't drop existing mappings.
        for dayID in lineupReferencedDayIDs {
            if let date = Self.editorDayKeyFormatter.date(from: dayID) {
                allDates.insert(calendar.startOfDay(for: date))
            }
        }

        let sortedDates = allDates.sorted()
        if sortedDates.isEmpty {
            let weekDay = isWeekScheduleEnabled
                ? EventWeekScheduleMode.weekDayIndex(for: startDay, anchorDate: startDay)
                : nil
            return [
                EditorDayOption(
                    id: Self.editorDayKey(for: startDay),
                    dayIndex: 1,
                    date: startDay,
                    weekIndex: weekDay?.week,
                    dayInWeek: weekDay?.day
                )
            ]
        }

        return sortedDates.enumerated().map { index, date in
            let weekDay = isWeekScheduleEnabled
                ? EventWeekScheduleMode.weekDayIndex(for: date, anchorDate: startDay)
                : nil
            return EditorDayOption(
                id: Self.editorDayKey(for: date),
                dayIndex: index + 1,
                date: date,
                weekIndex: weekDay?.week,
                dayInWeek: weekDay?.day
            )
        }
    }

    private var lineupReferencedDayIDs: Set<String> {
        var ids = Set<String>()
        let mergedSlots = lineupEntries + [pendingLineupEntry].compactMap { $0 }
        for slot in mergedSlots {
            if let dayID = slot.dayID?.trimmingCharacters(in: .whitespacesAndNewlines), !dayID.isEmpty {
                ids.insert(dayID)
            }
            if let start = slot.startTime {
                ids.insert(Self.editorDayKey(for: start))
            }
            if let end = slot.endTime {
                ids.insert(Self.editorDayKey(for: end))
            }
        }
        return ids
    }

    private func editorDayDates() -> [Date] {
        let calendar = Calendar.current
        let startDay = calendar.startOfDay(for: startDate)
        let effectiveEnd = max(endDate, startDate)
        let endDay = calendar.startOfDay(for: effectiveEnd)
        if !isWeekScheduleEnabled {
            var dates: [Date] = []
            var cursor = startDay
            while cursor <= endDay {
                dates.append(cursor)
                guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
                cursor = next
            }
            return dates.isEmpty ? [startDay] : dates
        }

        let daySpan = max((calendar.dateComponents([.day], from: startDay, to: endDay).day ?? 0) + 1, 1)
        let weekCount = max(1, Int(ceil(Double(daySpan) / 7.0)))
        var dates: [Date] = []

        for weekOffset in 0..<weekCount {
            for dayOffset in 0..<EventWeekScheduleMode.editorDaysPerWeek {
                let absoluteOffset = weekOffset * 7 + dayOffset
                guard let candidate = calendar.date(byAdding: .day, value: absoluteOffset, to: startDay) else { continue }
                if candidate > endDay { continue }
                dates.append(candidate)
            }
        }

        return dates.isEmpty ? [startDay] : dates
    }

    private var groupedLineupSlotGroups: [StageLineupGroup] {
        makeGroupedLineupSlotGroups(for: lineupEntries)
    }

    private var groupedImportLineupSlotGroups: [StageLineupGroup] {
        makeGroupedLineupSlotGroups(for: lineupImportDraftEntries)
    }

    private func makeGroupedLineupSlotGroups(for slots: [EditableLineupSlot]) -> [StageLineupGroup] {
        var map: [String: [EditableLineupSlot]] = [:]
        for slot in slots {
            map[stageBucketName(for: slot), default: []].append(slot)
        }
        let originalOrderByID = Dictionary(uniqueKeysWithValues: slots.enumerated().map { ($0.element.id, $0.offset) })

        let stageOrder = normalizedStageEntries
        let sortedStages = map.keys.sorted { lhs, rhs in
            let leftIndex = stageOrder.firstIndex(of: lhs) ?? Int.max
            let rightIndex = stageOrder.firstIndex(of: rhs) ?? Int.max
            if leftIndex != rightIndex { return leftIndex < rightIndex }
            return lhs.localizedCaseInsensitiveCompare(rhs) == .orderedAscending
        }

        return sortedStages.map { stage in
            let sortedSlots = (map[stage] ?? []).sorted { lhs, rhs in
                // Keep the row stable while editing; apply time-based sorting after confirming edit.
                if lhs.isEditing || rhs.isEditing {
                    let lhsIndex = originalOrderByID[lhs.id] ?? Int.max
                    let rhsIndex = originalOrderByID[rhs.id] ?? Int.max
                    if lhsIndex != rhsIndex { return lhsIndex < rhsIndex }
                }
                return lineupSlotSort(lhs, rhs)
            }
            return StageLineupGroup(stageName: stage, slotIDs: sortedSlots.map(\.id))
        }
    }

    private var pendingLineupSlotBinding: Binding<EditableLineupSlot>? {
        guard pendingLineupEntry != nil else { return nil }
        return Binding(
            get: {
                pendingLineupEntry ?? EditableLineupSlot(
                    actType: .solo,
                    performers: [EditableLineupPerformer()],
                    stageName: normalizedStageEntries.first ?? "",
                    dayID: dayOptions.first?.id,
                    startTime: nil,
                    endTime: nil,
                    isEditing: true
                )
            },
            set: { pendingLineupEntry = $0 }
        )
    }

    private var lineupItemDivider: some View {
        Rectangle()
            .fill(Color(uiColor: .separator))
            .frame(height: 1)
    }

    @ViewBuilder
    private func lineupEntryRow(for slotID: UUID) -> some View {
        if let index = lineupEntries.firstIndex(where: { $0.id == slotID }) {
            lineupEntryEditor($lineupEntries[index], isPending: false)
                .padding(.vertical, 2)
        }
    }

    @ViewBuilder
    private func lineupImportEntryRow(for slotID: UUID) -> some View {
        if let index = lineupImportDraftEntries.firstIndex(where: { $0.id == slotID }) {
            lineupEntryEditor(
                $lineupImportDraftEntries[index],
                isPending: false,
                onDelete: { removeLineupImportDraft(slotID) }
            )
            .padding(.vertical, 2)
        }
    }

    @ViewBuilder
    private func lineupEntryEditor(
        _ slot: Binding<EditableLineupSlot>,
        isPending: Bool = false,
        onDelete: (() -> Void)? = nil
    ) -> some View {
        let stageChoices = stageChoices(for: slot.wrappedValue)
        let hasSchedule = (slot.wrappedValue.startTime != nil) || (slot.wrappedValue.endTime != nil)
        let isEditing = slot.wrappedValue.isEditing
        let isSoloReadonlyCompact = !isEditing && slot.wrappedValue.actType == .solo
        let soloPerformer = slot.wrappedValue.performers.first

        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                if isEditing {
                    Picker(LL("演出形式"), selection: actTypeBinding(for: slot)) {
                        ForEach(EventLineupActType.allCases) { type in
                            Text(type.title).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .controlSize(.small)
                    .frame(width: 172)
                } else {
                    HStack(spacing: 6) {
                        Text(slotDisplayTitle(slot.wrappedValue))
                            .font(.footnote.weight(.semibold))
                            .lineLimit(2)
                        if slot.wrappedValue.actType == .solo,
                           let soloPerformer,
                           soloPerformer.djId != nil {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.caption2)
                                .foregroundStyle(Color.green)
                        }
                        if slot.wrappedValue.actType != .solo {
                            editorActTag(slot.wrappedValue.actType)
                        }
                    }
                }

                if isEditing {
                    Menu {
                        Button(LL("未选择舞台")) {
                            slot.wrappedValue.stageName = ""
                        }
                        ForEach(stageChoices, id: \.self) { stage in
                            Button(stage) {
                                slot.wrappedValue.stageName = stage
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "square.grid.2x2")
                                .font(.caption2)
                            Text(stageMenuTitle(for: slot.wrappedValue))
                                .font(.caption)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }
                        .foregroundStyle(RaverTheme.primaryText)
                        .frame(width: 98, alignment: .leading)
                    }
                } else {
                    Text(stageMenuTitle(for: slot.wrappedValue))
                        .font(.caption)
                        .foregroundStyle(RaverTheme.secondaryText)
                        .lineLimit(1)
                        .frame(width: 98, alignment: .leading)
                }

                Spacer(minLength: 0)

                Button {
                    if isPending {
                        if slot.wrappedValue.isEditing {
                            var committed = slot.wrappedValue
                            committed.isEditing = false
                            lineupEntries.append(committed)
                            sortLineupEntriesForDisplay()
                            pendingLineupEntry = nil
                            clearSearchState(for: committed.performers.map(\.id))
                        } else {
                            slot.wrappedValue.isEditing = true
                            syncTimeDraft(with: slot.wrappedValue)
                        }
                    } else {
                        slot.wrappedValue.isEditing.toggle()
                        if slot.wrappedValue.isEditing {
                            slot.wrappedValue.performers = normalizedPerformers(
                                for: slot.wrappedValue.actType,
                                from: slot.wrappedValue.performers
                            )
                            syncTimeDraft(with: slot.wrappedValue)
                        } else {
                            let performerIDs = slot.wrappedValue.performers.map(\.id)
                            clearSearchState(for: performerIDs)
                            sortLineupEntriesForDisplay()
                        }
                    }
                } label: {
                    Image(systemName: slot.wrappedValue.isEditing ? "checkmark.circle.fill" : "pencil")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(slot.wrappedValue.isEditing ? Color.green : RaverTheme.secondaryText)
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.borderless)

                Button {
                    if isPending {
                        let pending = slot.wrappedValue
                        pendingLineupEntry = nil
                        lineupTimeDraftBySlotID[pending.id] = nil
                        clearSearchState(for: pending.performers.map(\.id))
                    } else {
                        if let onDelete {
                            onDelete()
                        } else {
                            removeLineupSlot(slot.wrappedValue.id)
                        }
                    }
                } label: {
                    Image(systemName: "trash")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.red)
                        .frame(width: 24, height: 24)
                        .contentShape(Circle())
                }
                .buttonStyle(.borderless)
            }

            if isEditing {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(Array(slot.wrappedValue.performers.enumerated()), id: \.element.id) { index, _ in
                        lineupPerformerEditor(slot: slot, performerIndex: index)
                    }
                }
            } else if !isSoloReadonlyCompact {
                if slot.wrappedValue.performers.count <= 1, let performer = slot.wrappedValue.performers.first {
                    HStack(spacing: 6) {
                        Text(performer.djName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? L("未填写 DJ 名称", "Unnamed DJ") : performer.djName)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(RaverTheme.primaryText)
                            .lineLimit(1)
                        if performer.djId != nil {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.caption2)
                                .foregroundStyle(Color.green)
                        }
                        Spacer(minLength: 0)
                    }
                } else {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(Array(slot.wrappedValue.performers.enumerated()), id: \.element.id) { index, performer in
                            HStack(spacing: 6) {
                                Text("DJ\(index + 1)")
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(RaverTheme.secondaryText)
                                Text(performer.djName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? L("未填写 DJ 名称", "Unnamed DJ") : performer.djName)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(RaverTheme.primaryText)
                                    .lineLimit(1)
                                if performer.djId != nil {
                                    Image(systemName: "checkmark.seal.fill")
                                        .font(.caption2)
                                        .foregroundStyle(Color.green)
                                }
                                Spacer(minLength: 0)
                            }
                        }
                    }
                }
            }

            HStack(spacing: 4) {
                if isEditing {
                    Menu {
                        ForEach(dayOptions) { option in
                            Button(dayDisplayTitle(for: option)) {
                                daySelectionBinding(for: slot).wrappedValue = option.id
                            }
                        }
                    } label: {
                        Text(dayMenuTitle(for: slot.wrappedValue))
                            .font(.caption.weight(.semibold))
                            .lineLimit(1)
                            .frame(width: isWeekScheduleEnabled ? 94 : 54, alignment: .leading)
                    }

                    lineupTimeRangeInput(
                        startTimeText: startTimeTextBinding(for: slot),
                        endTimeText: endTimeTextBinding(for: slot)
                    )

                    Button(endNextDayBinding(for: slot).wrappedValue ? L("次日", "Next Day") : L("当日", "Same Day")) {
                        endNextDayBinding(for: slot).wrappedValue.toggle()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.mini)
                    .font(.caption2)
                    .frame(width: 46)

                    UIKitInlineTextField(
                        text: durationMinutesBinding(for: slot),
                        placeholder: L("分钟", "Min"),
                        keyboardType: .numberPad,
                        textAlignment: .right,
                        font: .systemFont(ofSize: 12),
                        textColor: .secondaryLabel,
                        tintColor: .secondaryLabel
                    )
                        .frame(width: 42)

                    Text(LL("分"))
                        .font(.caption2)
                        .foregroundStyle(RaverTheme.secondaryText)

                    if hasSchedule {
                        Button {
                            clearSchedule(for: slot)
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.caption)
                                .frame(width: 18, height: 18)
                        }
                        .buttonStyle(.borderless)
                    }
                } else {
                    Text(readonlyScheduleSummary(for: slot.wrappedValue))
                        .font(.caption)
                        .foregroundStyle(RaverTheme.secondaryText)
                        .lineLimit(1)
                }
            }
        }
        .onAppear {
            slot.wrappedValue.performers = normalizedPerformers(
                for: slot.wrappedValue.actType,
                from: slot.wrappedValue.performers
            )
            syncTimeDraft(with: slot.wrappedValue)
        }
    }

    @ViewBuilder
    private func lineupTimeRangeInput(
        startTimeText: Binding<String>,
        endTimeText: Binding<String>
    ) -> some View {
        HStack(spacing: 4) {
            TimeAutoColonTextField(
                text: startTimeText,
                placeholder: "00:00"
            )
            .frame(width: 52)
            .padding(.vertical, 4)
            .background(RoundedRectangle(cornerRadius: 6).fill(RaverTheme.card))

            Rectangle()
                .fill(RaverTheme.secondaryText.opacity(0.75))
                .frame(width: 9, height: 1)

            TimeAutoColonTextField(
                text: endTimeText,
                placeholder: "00:00"
            )
            .frame(width: 52)
            .padding(.vertical, 4)
            .background(RoundedRectangle(cornerRadius: 6).fill(RaverTheme.card))
        }
    }

    @ViewBuilder
    private func lineupPerformerEditor(slot: Binding<EditableLineupSlot>, performerIndex: Int) -> some View {
        if slot.wrappedValue.performers.indices.contains(performerIndex) {
            let performer = slot.wrappedValue.performers[performerIndex]
            let performerID = performer.id
            let isSearching = isSearchingDJPerformerIDs.contains(performerID)
            let candidates = djCandidatesByPerformerID[performerID] ?? []

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Text("DJ\(performerIndex + 1)")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(RaverTheme.secondaryText)
                        .frame(width: 24, alignment: .leading)

                    TextField(LL("输入 DJ 名称"), text: performerNameBinding(for: slot, performerIndex: performerIndex))
                        .font(.footnote.weight(.semibold))
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled(true)
                        .lineLimit(1)
                        .frame(width: 144, alignment: .leading)

                    if performer.djId != nil {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.caption)
                            .foregroundStyle(Color.green)
                    }
                }

                if isSearching {
                    HStack(spacing: 6) {
                        ProgressView()
                            .controlSize(.small)
                        Text(LL("搜索 DJ 中..."))
                            .font(.caption)
                            .foregroundStyle(RaverTheme.secondaryText)
                    }
                } else if !candidates.isEmpty {
                    VStack(spacing: 6) {
                        ForEach(candidates.prefix(6)) { dj in
                            Button {
                                applyDJSelection(dj, to: slot, performerIndex: performerIndex)
                            } label: {
                                HStack(spacing: 8) {
                                    djCandidateAvatar(dj)
                                    Text(dj.name)
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(RaverTheme.primaryText)
                                        .lineLimit(1)
                                    Spacer(minLength: 0)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    private func slotDisplayTitle(_ slot: EditableLineupSlot) -> String {
        let name = slot.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? L("未命名 DJ", "Unnamed DJ") : name
    }

    private func normalizedPerformers(
        for type: EventLineupActType,
        from performers: [EditableLineupPerformer]
    ) -> [EditableLineupPerformer] {
        let expectedCount = type.performerCount
        var normalized = Array(performers.prefix(expectedCount))
        while normalized.count < expectedCount {
            normalized.append(EditableLineupPerformer())
        }
        return normalized
    }

    private func actTypeBinding(for slot: Binding<EditableLineupSlot>) -> Binding<EventLineupActType> {
        Binding(
            get: { slot.wrappedValue.actType },
            set: { newType in
                slot.wrappedValue.actType = newType
                let existingIDs = Set(slot.wrappedValue.performers.map(\.id))
                slot.wrappedValue.performers = normalizedPerformers(for: newType, from: slot.wrappedValue.performers)
                let activeIDs = Set(slot.wrappedValue.performers.map(\.id))
                let removedIDs = existingIDs.subtracting(activeIDs)
                clearSearchState(for: Array(removedIDs))
            }
        )
    }

    private func performerNameBinding(
        for slot: Binding<EditableLineupSlot>,
        performerIndex: Int
    ) -> Binding<String> {
        Binding(
            get: {
                guard slot.wrappedValue.performers.indices.contains(performerIndex) else { return "" }
                return slot.wrappedValue.performers[performerIndex].djName
            },
            set: { newValue in
                guard slot.wrappedValue.performers.indices.contains(performerIndex) else { return }
                let performerID = slot.wrappedValue.performers[performerIndex].id
                let oldName = slot.wrappedValue.performers[performerIndex].djName
                slot.wrappedValue.performers[performerIndex].djName = newValue
                if newValue != oldName {
                    slot.wrappedValue.performers[performerIndex].djId = nil
                }
                djQueryByPerformerID[performerID] = newValue
                scheduleDJSearch(for: performerID, keyword: newValue)
            }
        )
    }

    private func clearSearchState(for performerIDs: [UUID]) {
        for performerID in performerIDs {
            djQueryByPerformerID[performerID] = nil
            djCandidatesByPerformerID[performerID] = nil
            isSearchingDJPerformerIDs.remove(performerID)
            djSearchTaskByPerformerID[performerID]?.cancel()
            djSearchTaskByPerformerID[performerID] = nil
        }
    }

    private func editorActTag(_ type: EventLineupActType) -> some View {
        Text(type.title)
            .font(.caption2.weight(.bold))
            .foregroundStyle(RaverTheme.accent)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(RaverTheme.accent.opacity(0.14), in: Capsule())
    }

    private func stageMenuTitle(for slot: EditableLineupSlot) -> String {
        let trimmed = slot.stageName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? L("舞台", "Stage") : trimmed
    }

    private func stageBucketName(for slot: EditableLineupSlot) -> String {
        let trimmed = slot.stageName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? L("未设置舞台", "Unassigned Stage") : trimmed
    }

    private func dayMenuTitle(for slot: EditableLineupSlot) -> String {
        guard let dayID = resolveDayID(for: slot),
              let option = dayOptions.first(where: { $0.id == dayID }) else {
            return isWeekScheduleEnabled ? L("Week1·Day1", "Week1·Day1") : L("Day1", "Day1")
        }
        return dayDisplayTitle(for: option)
    }

    private func dayDisplayTitle(for option: EditorDayOption) -> String {
        isWeekScheduleEnabled ? option.weekDayTitle : option.title
    }

    private func stageChoices(for slot: EditableLineupSlot) -> [String] {
        let current = slot.stageName.trimmingCharacters(in: .whitespacesAndNewlines)
        if current.isEmpty || normalizedStageEntries.contains(current) {
            return normalizedStageEntries
        }
        return normalizedStageEntries + [current]
    }

    private func lineupSlotSort(_ lhs: EditableLineupSlot, _ rhs: EditableLineupSlot) -> Bool {
        let lhsStart = lhs.startTime ?? .distantFuture
        let rhsStart = rhs.startTime ?? .distantFuture
        if lhsStart != rhsStart { return lhsStart < rhsStart }
        let lhsEnd = lhs.endTime ?? .distantFuture
        let rhsEnd = rhs.endTime ?? .distantFuture
        if lhsEnd != rhsEnd { return lhsEnd < rhsEnd }
        return lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
    }

    private func readonlyScheduleSummary(for slot: EditableLineupSlot) -> String {
        if slot.startTime == nil && slot.endTime == nil {
            return L("未填写时间（不展示在时间表）", "Time not set (hidden from timetable)")
        }
        let draft = makeTimeDraft(from: slot)
        let start = draft.startText.isEmpty ? "--:--" : draft.startText
        let end = draft.endText.isEmpty ? "--:--" : draft.endText
        let daySuffix = draft.endNextDay ? L(" 次日", " +1d") : ""
        let duration = draft.durationText.isEmpty ? "--" : draft.durationText
        return L("\(dayMenuTitle(for: slot)) · \(start)-\(end)\(daySuffix) · \(duration)分", "\(dayMenuTitle(for: slot)) · \(start)-\(end)\(daySuffix) · \(duration) min")
    }

    private func daySelectionBinding(for slot: Binding<EditableLineupSlot>) -> Binding<String> {
        Binding(
            get: {
                if let current = resolveDayID(for: slot.wrappedValue) {
                    return current
                }
                return dayOptions.first?.id ?? ""
            },
            set: { newDayID in
                let dayOffset = dayOffsetBetweenStartAndEnd(slot.wrappedValue)
                slot.wrappedValue.dayID = newDayID
                if let start = slot.wrappedValue.startTime {
                    slot.wrappedValue.startTime = applyDay(newDayID, to: start)
                }
                if let end = slot.wrappedValue.endTime {
                    let aligned = applyDay(newDayID, to: end)
                    if dayOffset > 0 {
                        slot.wrappedValue.endTime = Calendar.current.date(byAdding: .day, value: dayOffset, to: aligned) ?? aligned
                    } else {
                        slot.wrappedValue.endTime = aligned
                    }
                }
                syncTimeDraft(with: slot.wrappedValue)
            }
        )
    }

    private func sanitizeTimePart(_ raw: String) -> String {
        String(raw.filter(\.isNumber).prefix(2))
    }

    private func timeComponents(from value: String) -> (hour: String, minute: String) {
        let normalized = value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "：", with: ":")
        guard !normalized.isEmpty else { return ("", "") }

        if normalized.contains(":") {
            let pieces = normalized.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
            let hour = pieces.indices.contains(0) ? sanitizeTimePart(String(pieces[0])) : ""
            let minute = pieces.indices.contains(1) ? sanitizeTimePart(String(pieces[1])) : ""
            return (hour, minute)
        }

        let digits = normalized.filter(\.isNumber)
        if digits.count == 3 || digits.count == 4 {
            let minute = String(digits.suffix(2))
            let hour = String(digits.dropLast(2))
            return (sanitizeTimePart(hour), sanitizeTimePart(minute))
        }

        let hourOnly = sanitizeTimePart(digits)
        return (hourOnly, "")
    }

    private func composeTimeText(hour: String, minute: String) -> String {
        let h = sanitizeTimePart(hour)
        let m = sanitizeTimePart(minute)
        if h.isEmpty && m.isEmpty { return "" }
        return "\(h):\(m)"
    }

    private func startTimeTextBinding(for slot: Binding<EditableLineupSlot>) -> Binding<String> {
        Binding(
            get: {
                let draft = timeDraft(for: slot.wrappedValue)
                return draft.startText
            },
            set: { newText in
                var draft = timeDraft(for: slot.wrappedValue)
                draft.startText = normalizeTimeInput(newText)
                lineupTimeDraftBySlotID[slot.wrappedValue.id] = draft
                applyTimeDraft(for: slot, source: .startOrEndText)
            }
        )
    }

    private func endTimeTextBinding(for slot: Binding<EditableLineupSlot>) -> Binding<String> {
        Binding(
            get: {
                let draft = timeDraft(for: slot.wrappedValue)
                return draft.endText
            },
            set: { newText in
                var draft = timeDraft(for: slot.wrappedValue)
                draft.endText = normalizeTimeInput(newText)
                lineupTimeDraftBySlotID[slot.wrappedValue.id] = draft
                applyTimeDraft(for: slot, source: .startOrEndText)
            }
        )
    }

    private func durationMinutesBinding(for slot: Binding<EditableLineupSlot>) -> Binding<String> {
        Binding(
            get: {
                let draft = timeDraft(for: slot.wrappedValue)
                return draft.durationText
            },
            set: { newText in
                var draft = timeDraft(for: slot.wrappedValue)
                draft.durationText = newText.filter(\.isNumber)
                lineupTimeDraftBySlotID[slot.wrappedValue.id] = draft
                applyTimeDraft(for: slot, source: .durationText)
            }
        )
    }

    private func endNextDayBinding(for slot: Binding<EditableLineupSlot>) -> Binding<Bool> {
        Binding(
            get: {
                let draft = timeDraft(for: slot.wrappedValue)
                return draft.endNextDay
            },
            set: { isNextDay in
                var draft = timeDraft(for: slot.wrappedValue)
                draft.endNextDay = isNextDay
                lineupTimeDraftBySlotID[slot.wrappedValue.id] = draft
                applyTimeDraft(for: slot, source: .endDayToggle)
            }
        )
    }

    private func clearSchedule(for slot: Binding<EditableLineupSlot>) {
        slot.wrappedValue.startTime = nil
        slot.wrappedValue.endTime = nil
        var draft = timeDraft(for: slot.wrappedValue)
        draft.startText = ""
        draft.endText = ""
        draft.durationText = ""
        draft.endNextDay = false
        lineupTimeDraftBySlotID[slot.wrappedValue.id] = draft
    }

    private func timeDraft(for slot: EditableLineupSlot) -> LineupTimeDraft {
        if let existing = lineupTimeDraftBySlotID[slot.id] {
            return existing
        }
        return makeTimeDraft(from: slot)
    }

    private func makeTimeDraft(from slot: EditableLineupSlot) -> LineupTimeDraft {
        let startText = slot.startTime.map { Self.editorHourMinuteFormatter.string(from: $0) } ?? ""
        var endText = slot.endTime.map { Self.editorHourMinuteFormatter.string(from: $0) } ?? ""
        var endNextDay = false
        var durationText = ""

        if let start = slot.startTime, let end = slot.endTime {
            let offset = dayOffset(start: start, end: end)
            endNextDay = offset > 0
            if endNextDay, let normalized = Calendar.current.date(byAdding: .day, value: -offset, to: end) {
                endText = Self.editorHourMinuteFormatter.string(from: normalized)
            }
            if end >= start {
                durationText = String(Int(end.timeIntervalSince(start) / 60))
            }
        }

        return LineupTimeDraft(
            startText: startText,
            endText: endText,
            durationText: durationText,
            endNextDay: endNextDay
        )
    }

    private func syncTimeDraft(with slot: EditableLineupSlot) {
        lineupTimeDraftBySlotID[slot.id] = makeTimeDraft(from: slot)
    }

    private func applyTimeDraft(
        for slot: Binding<EditableLineupSlot>,
        source: LineupTimeApplySource = .startOrEndText
    ) {
        var draft = timeDraft(for: slot.wrappedValue)
        let resolvedDayID = resolveDayID(for: slot.wrappedValue) ?? dayOptions.first?.id ?? Self.editorDayKey(for: startDate)
        slot.wrappedValue.dayID = resolvedDayID

        let parsedStart = dateFrom(dayID: resolvedDayID, timeText: draft.startText, extraDays: 0)
        slot.wrappedValue.startTime = parsedStart

        if source == .durationText,
           let start = parsedStart,
           let duration = Int(draft.durationText), !draft.durationText.isEmpty {
            let safeDuration = max(duration, 0)
            let computedEnd = Calendar.current.date(byAdding: .minute, value: safeDuration, to: start) ?? start
            slot.wrappedValue.endTime = computedEnd
            draft.endText = Self.editorHourMinuteFormatter.string(from: computedEnd)
            draft.endNextDay = dayOffset(start: start, end: computedEnd) > 0
            lineupTimeDraftBySlotID[slot.wrappedValue.id] = draft
            return
        }

        var parsedEnd = dateFrom(
            dayID: resolvedDayID,
            timeText: draft.endText,
            extraDays: draft.endNextDay ? 1 : 0
        )

        // Default behavior: when editing start/end text, if end clock time is earlier
        // than start on the same day, treat end as next day (e.g. 23:00 -> 00:30).
        if source == .startOrEndText,
           let start = parsedStart,
           let end = parsedEnd,
           !draft.endNextDay,
           end < start {
            parsedEnd = Calendar.current.date(byAdding: .day, value: 1, to: end)
            draft.endNextDay = true
        }

        slot.wrappedValue.endTime = parsedEnd

        if let start = parsedStart, let end = parsedEnd, end >= start {
            draft.durationText = String(Int(end.timeIntervalSince(start) / 60))
        } else {
            draft.durationText = ""
        }

        lineupTimeDraftBySlotID[slot.wrappedValue.id] = draft
    }

    private func normalizeTimeInput(_ input: String) -> String {
        let trimmed = input
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "：", with: ":")
        guard !trimmed.isEmpty else { return "" }

        let digits = trimmed.filter(\.isNumber)
        if !trimmed.contains(":"), (digits.count == 3 || digits.count == 4) {
            let hour = digits.dropLast(2)
            let minute = digits.suffix(2)
            return "\(hour):\(minute)"
        }
        return trimmed
    }

    private func buildTicketTierInputs(defaultCurrency: String?) -> [EventTicketTierInput]? {
        let fallbackCurrency = defaultCurrency?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        var result: [EventTicketTierInput] = []

        for (index, draft) in ticketTierDrafts.enumerated() {
            let name = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
            let priceText = draft.price.trimmingCharacters(in: .whitespacesAndNewlines)
            let currency = draft.currency.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty ?? fallbackCurrency

            if name.isEmpty && priceText.isEmpty {
                continue
            }
            guard !name.isEmpty, !priceText.isEmpty else {
                errorMessage = L("请完整填写票档名称和价格，或删除空票档", "Please complete ticket tier name and price, or remove empty tiers.")
                return nil
            }
            guard let price = Double(priceText.replacingOccurrences(of: ",", with: ".")), price >= 0 else {
                errorMessage = L("票档价格格式不正确，请输入数字", "Invalid ticket price format. Please enter a number.")
                return nil
            }

            result.append(
                EventTicketTierInput(
                    name: name,
                    price: price,
                    currency: currency,
                    sortOrder: index + 1
                )
            )
        }

        return result
    }

    private func dateFrom(dayID: String, timeText: String, extraDays: Int) -> Date? {
        let normalized = normalizeTimeInput(timeText)
        guard let (hour, minute) = parseHourMinute(normalized),
              let baseDay = dayDate(for: dayID) else {
            return nil
        }

        let calendar = Calendar.current
        var parts = calendar.dateComponents([.year, .month, .day], from: baseDay)
        parts.hour = hour
        parts.minute = minute
        parts.second = 0
        guard let baseDate = calendar.date(from: parts) else { return nil }
        if extraDays == 0 { return baseDate }
        return calendar.date(byAdding: .day, value: extraDays, to: baseDate) ?? baseDate
    }

    private func parseHourMinute(_ value: String) -> (Int, Int)? {
        let parts = value.split(separator: ":", omittingEmptySubsequences: false)
        guard parts.count == 2,
              let hour = Int(parts[0]),
              let minute = Int(parts[1]),
              (0...23).contains(hour),
              (0...59).contains(minute) else {
            return nil
        }
        return (hour, minute)
    }

    private func dayOffsetBetweenStartAndEnd(_ slot: EditableLineupSlot) -> Int {
        guard let start = slot.startTime, let end = slot.endTime else { return 0 }
        return max(dayOffset(start: start, end: end), 0)
    }

    private func dayOffset(start: Date, end: Date) -> Int {
        let calendar = Calendar.current
        let startDay = calendar.startOfDay(for: start)
        let endDay = calendar.startOfDay(for: end)
        return calendar.dateComponents([.day], from: startDay, to: endDay).day ?? 0
    }

    private func resolveDayID(for slot: EditableLineupSlot) -> String? {
        if let dayID = slot.dayID, isKnownDay(dayID) {
            return dayID
        }
        if let start = slot.startTime {
            let candidate = Self.editorDayKey(for: start)
            if isKnownDay(candidate) { return candidate }
        }
        if let end = slot.endTime {
            let candidate = Self.editorDayKey(for: end)
            if isKnownDay(candidate) { return candidate }
        }
        return dayOptions.first?.id
    }

    private func isKnownDay(_ dayID: String) -> Bool {
        dayOptions.contains { $0.id == dayID }
    }

    private func dayDate(for dayID: String) -> Date? {
        dayOptions.first(where: { $0.id == dayID })?.date
    }

    private func festivalDayIndex(for dayID: String?) -> Int? {
        let normalizedDayID = dayID?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !normalizedDayID.isEmpty else { return nil }

        if let option = dayOptions.first(where: { $0.id == normalizedDayID }) {
            return option.dayIndex
        }

        guard let parsedDate = Self.editorDayKeyFormatter.date(from: normalizedDayID) else { return nil }
        let calendar = Calendar.current
        let baseDay = calendar.startOfDay(for: startDate)
        let targetDay = calendar.startOfDay(for: parsedDate)
        let offset = calendar.dateComponents([.day], from: baseDay, to: targetDay).day ?? 0
        guard offset >= 0 else { return nil }
        return offset + 1
    }

    private func applyDay(_ dayID: String, to date: Date) -> Date {
        guard let targetDay = dayDate(for: dayID) else { return date }
        let calendar = Calendar.current
        let timeParts = calendar.dateComponents([.hour, .minute, .second], from: date)
        var dayParts = calendar.dateComponents([.year, .month, .day], from: targetDay)
        dayParts.hour = timeParts.hour
        dayParts.minute = timeParts.minute
        dayParts.second = timeParts.second
        return calendar.date(from: dayParts) ?? date
    }

    private func prefillIfNeeded() {
        guard case .edit(let event) = mode else { return }
        if !name.isEmpty { return }

        name = event.name
        description = EventWeekScheduleMode.stripMarker(from: event.description)
        isWeekScheduleEnabled = EventWeekScheduleMode.isEnabled(in: event.description)
        if let rawType = event.eventType?.trimmingCharacters(in: .whitespacesAndNewlines), !rawType.isEmpty {
            let normalizedKey = EventTypeOption.key(for: rawType)
            eventType = EventTypeOption(rawValue: normalizedKey) == nil ? EventTypeOption.other.rawValue : normalizedKey
        } else {
            eventType = ""
        }
        cityEn = event.cityI18n?.en ?? event.city ?? ""
        cityZh = event.cityI18n?.zh ?? event.city ?? ""
        countryEn = event.countryI18n?.en ?? event.country ?? ""
        countryEnFull = event.countryI18n?.enFull ?? event.countryI18n?.en ?? event.country ?? ""
        countryZh = event.countryI18n?.zh ?? event.country ?? ""
        let language = AppLanguagePreference.current.effectiveLanguage
        let manualFormatted = event.manualLocation?.formattedAddressI18n?.text(for: language)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .nilIfEmpty
        let pointFormatted = event.locationPoint?.formattedAddressI18n?.text(for: language)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .nilIfEmpty
        let manualAddressZh = event.manualLocation?.detailAddressI18n?.zh
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .nilIfEmpty
        let manualAddressEn = event.manualLocation?.detailAddressI18n?.en
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .nilIfEmpty
        let resolvedAddressZh = manualAddressZh
            ?? manualFormatted
            ?? pointFormatted
            ?? ""
        let resolvedAddressEn = manualAddressEn
            ?? manualFormatted
            ?? pointFormatted
            ?? ""
        detailAddressZh = resolvedAddressZh
        detailAddressEn = resolvedAddressEn
        ticketUrl = event.ticketUrl ?? ""
        officialWebsite = event.officialWebsite ?? ""
        ticketCurrency = event.ticketCurrency?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty ?? "CNY"
        ticketNotes = event.ticketNotes ?? ""
        ticketTierDrafts = event.ticketTiers
            .sorted { $0.sortOrder < $1.sortOrder }
            .map { tier in
                let value = tier.price ?? 0
                let priceText = value.rounded(.towardZero) == value ? String(Int(value)) : String(value)
                return TicketTierDraft(
                    name: tier.name,
                    price: priceText,
                    currency: tier.currency?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty ?? ticketCurrency
                )
            }
        pickedLatitude = event.locationPoint?.location?.lat ?? event.latitude
        pickedLongitude = event.locationPoint?.location?.lng ?? event.longitude
        pickedMapAddress = pointFormatted ?? resolvedAddressZh
        pickedPlaceName = event.locationPoint?.nameI18n?.text(for: language)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .nilIfEmpty ?? ""
        startDate = Self.normalizedStartOfDay(event.startDate)
        endDate = Self.normalizedStartOfDay(event.endDate)
        coverImageUrl = event.coverImageUrl ?? ""
        lineupImageUrl = event.lineupImageUrl ?? ""
        selectedCoverPhoto = nil
        selectedLineupPhoto = nil
        selectedLineupImportPhoto = nil
        selectedCoverData = nil
        selectedLineupData = nil
        lineupImportDraftEntries = []
        lineupImportRawText = ""
        showLineupImportEditor = false
        isImportingLineupImage = false
        isApplyingLineupImport = false
        let stageOrderFromEvent = event.stageOrder?
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty } ?? []
        let stagesFromLineup = Array(NSOrderedSet(array: event.lineupSlots.compactMap { slot in
            slot.stageName?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        })) as? [String] ?? []
        let stageOrderKeys = Set(stageOrderFromEvent.map { $0.localizedLowercase })
        let prefilledStageEntries = stageOrderFromEvent + stagesFromLineup.filter { !stageOrderKeys.contains($0.localizedLowercase) }
        stageEntries = prefilledStageEntries.isEmpty ? [""] : prefilledStageEntries
        lineupTimeDraftBySlotID = [:]
        pendingLineupEntry = nil
        djQueryByPerformerID = [:]
        djCandidatesByPerformerID = [:]
        isSearchingDJPerformerIDs = []
        for task in djSearchTaskByPerformerID.values { task.cancel() }
        djSearchTaskByPerformerID = [:]
        lineupEntries = event.lineupSlots
            .sorted {
                if $0.sortOrder == $1.sortOrder {
                    return $0.startTime < $1.startTime
                }
                return $0.sortOrder < $1.sortOrder
            }
            .map { slot in
                let act = EventLineupActCodec.parse(slot: slot)
                let editablePerformers = normalizedPerformers(
                    for: act.type,
                    from: act.performers.map {
                        EditableLineupPerformer(djId: $0.djID, djName: $0.name)
                    }
                )
                let shouldTreatAsUnscheduled = isSyntheticUnscheduledLineupTime(
                    slot: slot,
                    eventStartDate: event.startDate
                )
                return EditableLineupSlot(
                    actType: act.type,
                    performers: editablePerformers,
                    stageName: slot.stageName ?? "",
                    dayID: {
                        if let dayIndex = slot.festivalDayIndex, dayIndex > 0 {
                            let logicalDay = Calendar.current.date(
                                byAdding: .day,
                                value: dayIndex - 1,
                                to: Self.normalizedStartOfDay(event.startDate)
                            ) ?? slot.startTime
                            return Self.editorDayKey(for: logicalDay)
                        }
                        return Self.editorDayKey(for: slot.startTime)
                    }(),
                    startTime: shouldTreatAsUnscheduled ? nil : slot.startTime,
                    endTime: shouldTreatAsUnscheduled ? nil : slot.endTime,
                    isEditing: false
                )
            }

        prefillHydrationTask?.cancel()
        prefillHydrationTask = Task {
            await hydratePrefilledLineupDJIdentity()
        }
    }

    private func isSyntheticUnscheduledLineupTime(
        slot: WebEventLineupSlot,
        eventStartDate: Date
    ) -> Bool {
        guard slot.startTime == slot.endTime else { return false }

        let slotOrder = max(slot.sortOrder, 1)
        let expectedFallback = eventStartDate.addingTimeInterval(Double(slotOrder - 1) * 60)
        let drift = abs(slot.startTime.timeIntervalSince(expectedFallback))

        // Backend fills empty lineup times as eventStart + (sortOrder-1) minutes.
        return drift < 1
    }

    @MainActor
    private func hydratePrefilledLineupDJIdentity() async {
        let unresolvedNames = lineupEntries
            .flatMap(\.performers)
            .filter { ($0.djId?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true) }
            .map(\.djName)

        let resolved = await fetchExactDJMatches(names: unresolvedNames) { keyword in
            let page = try await djsRepository.fetchDJs(
                page: 1,
                limit: 20,
                search: keyword,
                sortBy: "name"
            )
            return page.items
        }
        if Task.isCancelled { return }

        guard !resolved.isEmpty else { return }
        var next = lineupEntries
        for slotIndex in next.indices {
            for performerIndex in next[slotIndex].performers.indices {
                let nameKey = normalizedDJLookupKey(next[slotIndex].performers[performerIndex].djName)
                guard let matched = resolved[nameKey] else { continue }
                if next[slotIndex].performers[performerIndex].djId == nil {
                    next[slotIndex].performers[performerIndex].djId = matched.id
                }
            }
        }
        lineupEntries = next
    }

    private func save() async {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            errorMessage = L("请输入活动名称", "Please enter an event name.")
            return
        }

        let normalizedStartDate = Self.normalizedStartOfDay(startDate)
        let normalizedEndDate = Self.normalizedEndOfDay(max(endDate, startDate))
        let resolvedCityEn = cityEn.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        let resolvedCityZh = cityZh.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        let resolvedCountryEn = countryEn.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        let resolvedCountryEnFull = countryEnFull.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        let resolvedCountryZh = countryZh.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        let resolvedCityPrimary = resolvedCityZh ?? resolvedCityEn
        let resolvedCountryPrimary = resolvedCountryZh ?? resolvedCountryEnFull ?? resolvedCountryEn
        let resolvedCityI18n = (resolvedCityEn != nil || resolvedCityZh != nil)
            ? WebBiText(en: resolvedCityEn ?? resolvedCityZh ?? "", zh: resolvedCityZh ?? resolvedCityEn ?? "")
            : nil
        let resolvedCountryI18n = (resolvedCountryEn != nil || resolvedCountryZh != nil || resolvedCountryEnFull != nil)
            ? WebBiText(
                en: resolvedCountryEn ?? resolvedCountryZh ?? "",
                zh: resolvedCountryZh ?? resolvedCountryEn ?? "",
                enFull: resolvedCountryEnFull
            )
            : nil
        let shouldClearCityI18n = resolvedCityEn == nil && resolvedCityZh == nil
        let shouldClearCountryI18n = resolvedCountryEn == nil && resolvedCountryZh == nil && resolvedCountryEnFull == nil
        let resolvedDetailAddressZh = detailAddressZh.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        let resolvedDetailAddressEn = detailAddressEn.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        let resolvedPrimaryAddress = resolvedDetailAddressZh ?? resolvedDetailAddressEn
        let resolvedTicketUrl = ticketUrl.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        let resolvedOfficialWebsite = officialWebsite.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        let resolvedTicketCurrency = ticketCurrency.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        let resolvedTicketNotes = ticketNotes.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        let encodedDescription = EventWeekScheduleMode.embedMarker(into: description, enabled: isWeekScheduleEnabled)
        let resolvedManualLocation = buildManualLocationPayload(
            detailAddressZh: resolvedDetailAddressZh,
            detailAddressEn: resolvedDetailAddressEn,
            cityZh: resolvedCityZh,
            cityEn: resolvedCityEn,
            countryZh: resolvedCountryZh,
            countryEn: resolvedCountryEn,
            countryEnFull: resolvedCountryEnFull
        )
        let shouldClearManualLocation = resolvedManualLocation == nil
        let resolvedLocationPoint = buildLocationPointPayload(
            latitude: pickedLatitude,
            longitude: pickedLongitude,
            displayAddress: pickedMapAddress.nilIfEmpty ?? resolvedPrimaryAddress,
            city: resolvedCityPrimary,
            country: resolvedCountryPrimary,
            placeName: pickedPlaceName.nilIfEmpty
        )

        if normalizedEndDate < normalizedStartDate {
            errorMessage = L("结束时间不能早于开始时间", "End time cannot be earlier than start time.")
            return
        }

        if pendingLineupEntry != nil {
            errorMessage = L("请先确认或删除上方新增 DJ 条目后再保存", "Please confirm or remove the newly added DJ entry before saving.")
            return
        }

        guard let lineupSlotsInput = buildLineupSlotsInput() else {
            return
        }
        guard let ticketTierInputs = buildTicketTierInputs(defaultCurrency: resolvedTicketCurrency) else {
            return
        }

        let resolvedEventType = EventTypeOption.submissionValue(for: eventType)
        let resolvedStatus = EventVisualStatus.resolve(startDate: normalizedStartDate, endDate: normalizedEndDate).apiValue

        isSaving = true
        defer { isSaving = false }

        do {
            switch mode {
            case .create:
                let created = try await eventsRepository.createEvent(
                    input: CreateEventInput(
                        name: trimmedName,
                        description: encodedDescription,
                        eventType: resolvedEventType,
                        city: resolvedCityPrimary,
                        cityI18n: resolvedCityI18n,
                        country: resolvedCountryPrimary,
                        countryI18n: resolvedCountryI18n,
                        manualLocation: resolvedManualLocation,
                        locationPoint: resolvedLocationPoint,
                        latitude: pickedLatitude,
                        longitude: pickedLongitude,
                        ticketUrl: resolvedTicketUrl,
                        ticketCurrency: resolvedTicketCurrency,
                        ticketNotes: resolvedTicketNotes,
                        officialWebsite: resolvedOfficialWebsite,
                        startDate: normalizedStartDate,
                        endDate: normalizedEndDate,
                        stageOrder: normalizedStageEntries,
                        coverImageUrl: nil,
                        lineupImageUrl: nil,
                        ticketTiers: ticketTierInputs,
                        lineupSlots: lineupSlotsInput,
                        status: resolvedStatus
                    )
                )

                var uploadedCoverURL: String?
                var uploadedLineupURL: String?

                if let selectedCoverData {
                    let upload = try await eventsRepository.uploadEventImage(
                        imageData: jpegData(from: selectedCoverData),
                        fileName: "event-cover-\(UUID().uuidString).jpg",
                        mimeType: "image/jpeg",
                        eventID: created.id,
                        usage: "cover"
                    )
                    uploadedCoverURL = upload.url
                }

                if let selectedLineupData {
                    let upload = try await eventsRepository.uploadEventImage(
                        imageData: jpegData(from: selectedLineupData),
                        fileName: "event-lineup-\(UUID().uuidString).jpg",
                        mimeType: "image/jpeg",
                        eventID: created.id,
                        usage: "lineup"
                    )
                    uploadedLineupURL = upload.url
                }

                if uploadedCoverURL != nil || uploadedLineupURL != nil {
                    _ = try await eventsRepository.updateEvent(
                        id: created.id,
                        input: UpdateEventInput(
                            coverImageUrl: uploadedCoverURL,
                            lineupImageUrl: uploadedLineupURL
                        )
                    )
                }
            case .edit(let event):
                var finalCover = coverImageUrl.trimmingCharacters(in: .whitespacesAndNewlines)
                var finalLineup = lineupImageUrl.trimmingCharacters(in: .whitespacesAndNewlines)

                if let selectedCoverData {
                    let upload = try await eventsRepository.uploadEventImage(
                        imageData: jpegData(from: selectedCoverData),
                        fileName: "event-cover-\(UUID().uuidString).jpg",
                        mimeType: "image/jpeg",
                        eventID: event.id,
                        usage: "cover"
                    )
                    finalCover = upload.url
                }

                if let selectedLineupData {
                    let upload = try await eventsRepository.uploadEventImage(
                        imageData: jpegData(from: selectedLineupData),
                        fileName: "event-lineup-\(UUID().uuidString).jpg",
                        mimeType: "image/jpeg",
                        eventID: event.id,
                        usage: "lineup"
                    )
                    finalLineup = upload.url
                }

                _ = try await eventsRepository.updateEvent(
                    id: event.id,
                        input: UpdateEventInput(
                            name: trimmedName,
                            description: encodedDescription,
                            eventType: resolvedEventType,
                            city: resolvedCityPrimary,
                            cityI18n: resolvedCityI18n,
                            country: resolvedCountryPrimary,
                            countryI18n: resolvedCountryI18n,
                            manualLocation: resolvedManualLocation,
                            locationPoint: resolvedLocationPoint,
                        latitude: pickedLatitude,
                        longitude: pickedLongitude,
                        ticketUrl: resolvedTicketUrl ?? "",
                        ticketCurrency: resolvedTicketCurrency ?? "",
                        ticketNotes: resolvedTicketNotes ?? "",
                        officialWebsite: resolvedOfficialWebsite ?? "",
                        startDate: normalizedStartDate,
                        endDate: normalizedEndDate,
                        stageOrder: normalizedStageEntries,
                        coverImageUrl: finalCover.nilIfEmpty ?? "",
                        lineupImageUrl: finalLineup.nilIfEmpty ?? "",
                        ticketTiers: ticketTierInputs,
                        lineupSlots: lineupSlotsInput,
                        status: resolvedStatus,
                        clearCityI18n: shouldClearCityI18n,
                        clearCountryI18n: shouldClearCountryI18n,
                        clearManualLocation: shouldClearManualLocation
                    )
                )
            }

            onSaved()
            dismiss()
        } catch {
            errorMessage = error.userFacingMessage
        }
    }

    private func buildManualLocationPayload(
        detailAddressZh: String?,
        detailAddressEn: String?,
        cityZh: String?,
        cityEn: String?,
        countryZh: String?,
        countryEn: String?,
        countryEnFull: String?
    ) -> WebEventManualLocation? {
        let resolvedZh = detailAddressZh?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        let resolvedEn = detailAddressEn?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        let detailBi = WebBiText(
            en: resolvedEn ?? resolvedZh ?? "",
            zh: resolvedZh ?? resolvedEn ?? ""
        )
        let hasDetail = !detailBi.en.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !detailBi.zh.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        guard hasDetail else {
            return nil
        }
        let formattedZh = [countryZh ?? countryEn, cityZh ?? cityEn, detailBi.zh]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty }
            .joined(separator: " · ")
            .nilIfEmpty
        let formattedEn = [countryEnFull ?? countryEn ?? countryZh, cityEn ?? cityZh, detailBi.en]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty }
            .joined(separator: " · ")
            .nilIfEmpty
        return WebEventManualLocation(
            detailAddressI18n: detailBi,
            formattedAddressI18n: WebBiText(
                en: formattedEn ?? detailBi.en,
                zh: formattedZh ?? detailBi.zh
            ),
            selectedAt: Date()
        )
    }

    private func buildLocationPointPayload(
        latitude: Double?,
        longitude: Double?,
        displayAddress: String?,
        city: String?,
        country: String?,
        placeName: String?
    ) -> WebEventLocationPoint? {
        guard let lat = latitude, let lng = longitude else {
            return nil
        }
        let resolvedAddress = displayAddress?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        let resolvedPlaceName = placeName?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        let formatted = [country, city, resolvedAddress ?? resolvedPlaceName]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty }
            .joined(separator: " · ")
            .nilIfEmpty
        return WebEventLocationPoint(
            provider: "apple_mapkit",
            sourceMode: "manual_pin",
            providerPlaceId: nil,
            poiId: nil,
            location: WebEventLocationCoordinate(lng: lng, lat: lat),
            nameI18n: resolvedPlaceName.map { WebBiText(en: $0, zh: $0) },
            addressI18n: resolvedAddress.map { WebBiText(en: $0, zh: $0) },
            formattedAddressI18n: formatted.map { WebBiText(en: $0, zh: $0) },
            city: city?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
            district: nil,
            province: nil,
            countryCode: country?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        )
    }

    private enum EventImageTarget {
        case cover
        case lineup
    }

    @MainActor
    private func loadSelectedEventImage(_ item: PhotosPickerItem?, target: EventImageTarget) async {
        guard let item else {
            switch target {
            case .cover:
                selectedCoverData = nil
            case .lineup:
                selectedLineupData = nil
            }
            return
        }

        do {
            let loaded = try await item.loadTransferable(type: Data.self)
            switch target {
            case .cover:
                selectedCoverData = loaded
            case .lineup:
                selectedLineupData = loaded
            }
        } catch {
            switch target {
            case .cover:
                selectedCoverData = nil
            case .lineup:
                selectedLineupData = nil
            }
            errorMessage = L("读取图片失败，请重试", "Failed to read image. Please try again.")
        }
    }

    @MainActor
    private func importLineupFromImage(_ item: PhotosPickerItem?) async {
        guard let item else { return }

        isImportingLineupImage = true
        defer {
            isImportingLineupImage = false
            selectedLineupImportPhoto = nil
        }

        do {
            guard let loaded = try await item.loadTransferable(type: Data.self) else {
                errorMessage = L("读取阵容图失败，请重试", "Failed to read lineup image. Please try again.")
                return
            }

            let preview = try await eventsRepository.importEventLineupFromImage(
                imageData: jpegData(from: loaded),
                fileName: "lineup-import-\(UUID().uuidString).jpg",
                mimeType: "image/jpeg",
                startDate: Self.normalizedStartOfDay(startDate),
                endDate: Self.normalizedEndOfDay(max(endDate, startDate))
            )

            guard !preview.lineupInfo.isEmpty else {
                errorMessage = L("未识别到可导入的阵容信息，请尝试更清晰的时间表图片", "No importable lineup found. Please try a clearer timetable image.")
                return
            }

            var importedDrafts = buildImportedLineupSlots(from: preview.lineupInfo, isEditing: false)
            guard !importedDrafts.isEmpty else {
                errorMessage = L("识别结果中没有可导入的有效阵容信息", "Recognition result has no valid lineup entries to import.")
                return
            }

            importedDrafts = await autoMatchImportedLineupSlots(importedDrafts)
            lineupImportDraftEntries = importedDrafts
            lineupImportRawText = buildLineupImportJSONText(
                normalizedText: preview.normalizedText,
                lineupInfo: preview.lineupInfo
            )
            lineupImportShouldReplaceExistingEntries = false
            showLineupImportEditor = true
        } catch {
            errorMessage = L("阵容识别失败：\(error.userFacingMessage ?? "")", "Lineup recognition failed: \(error.userFacingMessage ?? "")")
        }
    }

    private struct LineupImportJSONPayload: Codable {
        var normalizedText: String
        var lineupInfo: [EventLineupImageImportItem]

        enum CodingKeys: String, CodingKey {
            case normalizedText = "normalized_text"
            case lineupInfo = "lineup_info"
        }
    }

    private enum LineupImportJSONError: LocalizedError {
        case emptyInput
        case invalidJSON
        case missingLineupInfo

        var errorDescription: String? {
            switch self {
            case .emptyInput:
                return L("请输入 JSON 内容后再解析", "Please enter JSON content before parsing.")
            case .invalidJSON:
                return L("JSON 格式不正确，请检查后重试", "Invalid JSON format. Please check and try again.")
            case .missingLineupInfo:
                return L("未找到 lineup_info，可用 Coze 返回格式或直接传数组", "No lineup_info found. Use Coze format or pass an array directly.")
            }
        }
    }

    private func openLineupImportEditorForJSON() {
        if lineupImportDraftEntries.isEmpty {
            if !lineupEntries.isEmpty {
                lineupImportShouldReplaceExistingEntries = true
                lineupImportDraftEntries = lineupEntries.map { slot in
                    var copied = slot
                    copied.isEditing = false
                    return copied
                }
            } else {
                lineupImportShouldReplaceExistingEntries = false
            }
        }

        if lineupImportRawText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let seedItems = lineupImportItemsFromDrafts(lineupImportDraftEntries)
            lineupImportRawText = seedItems.isEmpty
                ? defaultLineupImportJSONTemplate()
                : buildLineupImportJSONText(normalizedText: "", lineupInfo: seedItems)
        }
        showLineupImportEditor = true
    }

    @MainActor
    private func applyJSONToLineupImportDrafts() async {
        guard !isParsingLineupImportJSON else { return }
        isParsingLineupImportJSON = true
        defer { isParsingLineupImportJSON = false }

        do {
            let parsed = try parseLineupImportJSON(lineupImportRawText)
            var importedDrafts = buildImportedLineupSlots(from: parsed.lineupInfo, isEditing: false)
            guard !importedDrafts.isEmpty else {
                errorMessage = L("JSON 中没有可导入的有效阵容信息", "No valid lineup entries found in JSON.")
                return
            }
            importedDrafts = await autoMatchImportedLineupSlots(importedDrafts)
            lineupImportDraftEntries = importedDrafts
            lineupImportRawText = buildLineupImportJSONText(
                normalizedText: parsed.normalizedText,
                lineupInfo: parsed.lineupInfo
            )
        } catch {
            errorMessage = error.userFacingMessage
        }
    }

    private func parseLineupImportJSON(_ raw: String) throws -> (normalizedText: String, lineupInfo: [EventLineupImageImportItem]) {
        let cleaned = stripLineupImportCodeFence(raw).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else {
            throw LineupImportJSONError.emptyInput
        }
        guard let data = cleaned.data(using: .utf8) else {
            throw LineupImportJSONError.invalidJSON
        }

        let root: Any
        do {
            root = try JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
        } catch {
            throw LineupImportJSONError.invalidJSON
        }
        var normalizedText = ""
        var rawItems: [Any] = []

        if let dict = root as? [String: Any] {
            normalizedText =
                firstNonEmptyString(in: dict, keys: ["normalized_text", "normalizedText", "normalized_text_raw"]) ?? ""
            if let lineup = dict["lineup_info"] as? [Any] {
                rawItems = lineup
            } else if let lineup = dict["lineupInfo"] as? [Any] {
                rawItems = lineup
            } else if let lineup = dict["items"] as? [Any] {
                rawItems = lineup
            } else if dict["musician"] != nil || dict["artist"] != nil || dict["name"] != nil {
                rawItems = [dict]
            } else {
                throw LineupImportJSONError.missingLineupInfo
            }
        } else if let array = root as? [Any] {
            rawItems = array
        } else {
            throw LineupImportJSONError.invalidJSON
        }

        let lineupInfo = rawItems.enumerated().compactMap { index, rawItem -> EventLineupImageImportItem? in
            guard let dict = rawItem as? [String: Any] else { return nil }
            let musician = firstNonEmptyString(in: dict, keys: ["musician", "artist", "name", "dj", "dj_name"]) ?? ""
            let time = firstNonEmptyString(in: dict, keys: ["time", "set_time", "time_range"])
            let stage = firstNonEmptyString(in: dict, keys: ["stage", "stage_name"])
            let date = firstNonEmptyString(in: dict, keys: ["date", "day", "day_label"])
            let id = firstNonEmptyString(in: dict, keys: ["id", "slot_id", "slotId", "uid"]) ?? "json-\(index + 1)"
            return EventLineupImageImportItem(
                id: id,
                musician: musician,
                time: time,
                stage: stage,
                date: date
            )
        }

        guard !lineupInfo.isEmpty else {
            throw LineupImportJSONError.missingLineupInfo
        }
        return (normalizedText, lineupInfo)
    }

    private func stripLineupImportCodeFence(_ raw: String) -> String {
        var value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.hasPrefix("```") {
            value = value.replacingOccurrences(
                of: #"^```[a-zA-Z0-9_-]*\s*"#,
                with: "",
                options: .regularExpression
            )
            value = value.replacingOccurrences(
                of: #"\s*```$"#,
                with: "",
                options: .regularExpression
            )
        }
        return value
    }

    private func firstNonEmptyString(in dict: [String: Any], keys: [String]) -> String? {
        for key in keys {
            if let value = dict[key] as? String {
                let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    return trimmed
                }
            }
        }
        return nil
    }

    private func buildLineupImportJSONText(normalizedText: String, lineupInfo: [EventLineupImageImportItem]) -> String {
        let payload = LineupImportJSONPayload(
            normalizedText: normalizedText,
            lineupInfo: lineupInfo
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        if let data = try? encoder.encode(payload),
           let text = String(data: data, encoding: .utf8) {
            return text
        }
        return defaultLineupImportJSONTemplate()
    }

    private func defaultLineupImportJSONTemplate() -> String {
        let example = [
            EventLineupImageImportItem(
                id: "sample-1",
                musician: "DJ A",
                time: "23:00-00:30",
                stage: "Main Stage",
                date: isWeekScheduleEnabled ? "Week1 Day1" : "Day1"
            )
        ]
        return buildLineupImportJSONText(normalizedText: "", lineupInfo: example)
    }

    private func lineupImportItemsFromDrafts(_ drafts: [EditableLineupSlot]) -> [EventLineupImageImportItem] {
        drafts.enumerated().compactMap { index, slot in
            let musician = slot.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !musician.isEmpty else { return nil }
            let stage = slot.stageName.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
            let date: String? = {
                guard let dayID = resolveDayID(for: slot),
                      let option = dayOptions.first(where: { $0.id == dayID }) else {
                    return nil
                }
                return dayDisplayTitle(for: option)
            }()
            let time: String? = {
                guard let start = slot.startTime, let end = slot.endTime else { return nil }
                let startText = Self.editorHourMinuteFormatter.string(from: start)
                let endText = Self.editorHourMinuteFormatter.string(from: end)
                return "\(startText)-\(endText)"
            }()
            return EventLineupImageImportItem(
                id: "draft-\(index + 1)",
                musician: musician,
                time: time,
                stage: stage,
                date: date
            )
        }
    }

    @MainActor
    private func commitLineupImportDrafts() async {
        guard !isApplyingLineupImport else { return }
        if pendingLineupEntry != nil {
            errorMessage = L("请先确认或删除上方新增 DJ 条目后再导入", "Please confirm or remove the newly added DJ entry before importing.")
            return
        }

        var importedSlots = lineupImportDraftEntries.map { slot in
            var copied = slot
            copied.performers = normalizedPerformers(for: copied.actType, from: copied.performers)
            copied.isEditing = false
            return copied
        }

        guard !importedSlots.isEmpty else {
            errorMessage = L("暂无可导入的阵容，请先识别图片或粘贴 JSON", "No lineup to import yet. Recognize an image or paste JSON first.")
            return
        }

        isApplyingLineupImport = true
        defer { isApplyingLineupImport = false }

        let unresolvedNames = importedSlots.flatMap { slot in
            slot.performers
                .filter { ($0.djId?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true) }
                .map(\.djName)
        }
        let resolved = await fetchExactDJMatches(names: unresolvedNames) { keyword in
            let page = try await djsRepository.fetchDJs(
                page: 1,
                limit: 20,
                search: keyword,
                sortBy: "name"
            )
            return page.items
        }

        for slotIndex in importedSlots.indices {
            for performerIndex in importedSlots[slotIndex].performers.indices {
                if importedSlots[slotIndex].performers[performerIndex].djId != nil { continue }
                let key = normalizedDJLookupKey(importedSlots[slotIndex].performers[performerIndex].djName)
                if let matched = resolved[key] {
                    importedSlots[slotIndex].performers[performerIndex].djId = matched.id
                }
            }
        }

        mergeImportedStages(importedSlots)
        if lineupImportShouldReplaceExistingEntries {
            let existingPerformerIDs = lineupEntries.flatMap { $0.performers.map(\.id) }
            clearSearchState(for: existingPerformerIDs)
            lineupEntries = importedSlots
        } else {
            lineupEntries.append(contentsOf: importedSlots)
        }
        sortLineupEntriesForDisplay()
        showLineupImportEditor = false
        showLineupImportSuccessToast(count: importedSlots.count)
    }

    private func buildImportedLineupSlots(
        from items: [EventLineupImageImportItem],
        isEditing: Bool = false
    ) -> [EditableLineupSlot] {
        items.compactMap { item in
            let musician = item.musician.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !musician.isEmpty, !isUnknownImportValue(musician) else {
                return nil
            }

            let parsedAct = EventLineupActCodec.parse(name: musician, performerIDPrefix: "import-\(item.id)-p")
            let performers = normalizedPerformers(
                for: parsedAct.type,
                from: parsedAct.performers.map {
                    EditableLineupPerformer(djId: $0.djID, djName: $0.name)
                }
            )

            let stageName = normalizedImportedStage(item.stage) ?? ""
            let timeRange = parseImportedTimeRange(item.time)
            let singleTimePoint = timeRange == nil ? parseImportedSingleTime(item.time) : nil
            let baseDay = resolveImportedBaseDay(
                item.date,
                preferDefaultDay: (timeRange != nil || singleTimePoint != nil)
            )

            var start: Date?
            var end: Date?
            if let baseDay, let timeRange {
                start = combine(day: baseDay, hour: timeRange.startHour, minute: timeRange.startMinute)
                end = combine(day: baseDay, hour: timeRange.endHour, minute: timeRange.endMinute)
                if let startValue = start, let endValue = end, endValue < startValue {
                    end = Calendar.current.date(byAdding: .day, value: 1, to: endValue) ?? endValue
                }
            } else if let baseDay, let singleTimePoint {
                start = combine(day: baseDay, hour: singleTimePoint.hour, minute: singleTimePoint.minute)
                end = start
            }

            let resolvedDayID: String?
            if let baseDay {
                let candidate = Self.editorDayKey(for: baseDay)
                resolvedDayID = isKnownDay(candidate) ? candidate : nil
            } else {
                resolvedDayID = nil
            }

            return EditableLineupSlot(
                actType: parsedAct.type,
                performers: performers,
                stageName: stageName,
                dayID: resolvedDayID,
                startTime: start,
                endTime: end,
                isEditing: isEditing
            )
        }
    }

    private func mergeImportedStages(_ imported: [EditableLineupSlot]) {
        for stage in imported.map(\.stageName) {
            let trimmed = stage.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            let exists = stageEntries.contains {
                $0.trimmingCharacters(in: .whitespacesAndNewlines).localizedCaseInsensitiveCompare(trimmed) == .orderedSame
            }
            if !exists {
                stageEntries.append(trimmed)
            }
        }
    }

    private func autoMatchImportedLineupSlots(_ slots: [EditableLineupSlot]) async -> [EditableLineupSlot] {
        var matchedSlots = slots
        let unresolvedNames = matchedSlots.flatMap { slot in
            slot.performers
                .filter { ($0.djId?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true) }
                .map(\.djName)
        }
        guard !unresolvedNames.isEmpty else { return matchedSlots }

        let resolved = await fetchExactDJMatches(names: unresolvedNames) { keyword in
            let page = try await djsRepository.fetchDJs(
                page: 1,
                limit: 20,
                search: keyword,
                sortBy: "name"
            )
            return page.items
        }
        guard !resolved.isEmpty else { return matchedSlots }

        for slotIndex in matchedSlots.indices {
            for performerIndex in matchedSlots[slotIndex].performers.indices {
                if matchedSlots[slotIndex].performers[performerIndex].djId != nil { continue }
                let key = normalizedDJLookupKey(matchedSlots[slotIndex].performers[performerIndex].djName)
                guard let candidate = resolved[key] else { continue }
                matchedSlots[slotIndex].performers[performerIndex].djId = candidate.id
                matchedSlots[slotIndex].performers[performerIndex].djName = candidate.name
            }
        }
        return matchedSlots
    }

    private func removeLineupImportDraft(_ slotID: UUID) {
        guard let existing = lineupImportDraftEntries.first(where: { $0.id == slotID }) else { return }
        lineupImportDraftEntries.removeAll { $0.id == slotID }
        clearSearchState(for: existing.performers.map(\.id))
    }

    private func resetLineupImportDrafts() {
        let performerIDs = lineupImportDraftEntries.flatMap { $0.performers.map(\.id) }
        clearSearchState(for: performerIDs)
        lineupImportDraftEntries = []
        lineupImportRawText = ""
        isApplyingLineupImport = false
        isParsingLineupImportJSON = false
        lineupImportShouldReplaceExistingEntries = false
    }

    private func showLineupImportSuccessToast(count: Int) {
        let successText = L("已导入 \(count) 条阵容", "Imported \(count) lineup entries")
        importSuccessMessage = successText
        Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            if importSuccessMessage == successText {
                importSuccessMessage = nil
            }
        }
    }

    @ViewBuilder
    private func lineupImportEditorSheet() -> some View {
        NavigationStack {
            Form {
                Section(LL("导入草稿（可编辑）")) {
                    if lineupImportDraftEntries.isEmpty {
                        Text(LL("暂无可导入条目，请先识别阵容图或粘贴 JSON 后解析。"))
                            .font(.subheadline)
                            .foregroundStyle(RaverTheme.secondaryText)
                    } else {
                        if !lineupImportRawText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Text(LL("识别完成，可直接修改后一键导入。"))
                                .font(.caption)
                                .foregroundStyle(RaverTheme.secondaryText)
                        }

                        ForEach(groupedImportLineupSlotGroups, id: \.stageName) { group in
                            VStack(alignment: .leading, spacing: 6) {
                                Text(group.stageName)
                                    .font(.subheadline.weight(.bold))
                                    .foregroundStyle(Color.white)
                                    .frame(maxWidth: .infinity, alignment: .center)
                                    .padding(.vertical, 2)

                                ForEach(Array(group.slotIDs.enumerated()), id: \.element) { index, slotID in
                                    lineupImportEntryRow(for: slotID)
                                    if index < group.slotIDs.count - 1 {
                                        lineupItemDivider
                                            .padding(.vertical, 0)
                                    }
                                }
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }

                Section(LL("JSON 导入文本（Coze 格式）")) {
                    Text(LL("支持 Coze 返回格式：`normalized_text + lineup_info`，也支持直接粘贴数组。"))
                        .font(.caption)
                        .foregroundStyle(RaverTheme.secondaryText)

                    TextEditor(text: $lineupImportRawText)
                        .font(.system(.caption, design: .monospaced))
                        .frame(minHeight: 150, maxHeight: 260)

                    Button(isParsingLineupImportJSON ? L("解析中...", "Parsing...") : L("解析 JSON 更新草稿", "Parse JSON to Update Draft")) {
                        Task { await applyJSONToLineupImportDrafts() }
                    }
                    .disabled(isParsingLineupImportJSON)
                }
            }
            .raverSystemNavigation(title: LL("阵容导入"))
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(isApplyingLineupImport ? L("导入中...", "Importing...") : L("一键导入", "Import All")) {
                        Task { await commitLineupImportDrafts() }
                    }
                    .disabled(isApplyingLineupImport || isParsingLineupImportJSON || lineupImportDraftEntries.isEmpty)
                }
            }
        }
        .raverEnableCustomSwipeBack(edgeRatio: 0.2)
    }

    private func isUnknownImportValue(_ raw: String?) -> Bool {
        let value = raw?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
        guard !value.isEmpty else { return true }
        return value == "unknown" || value == "未知" || value == "n/a" || value == "na" || value == "-"
    }

    private func normalizedImportedStage(_ raw: String?) -> String? {
        guard let raw else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isUnknownImportValue(trimmed) else { return nil }
        return trimmed
    }

    private func parseImportedTimeRange(_ raw: String?) -> (startHour: Int, startMinute: Int, endHour: Int, endMinute: Int)? {
        guard let raw else { return nil }
        let trimmed = raw
            .replacingOccurrences(of: "：", with: ":")
            .replacingOccurrences(of: "—", with: "-")
            .replacingOccurrences(of: "–", with: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isUnknownImportValue(trimmed) else { return nil }

        let pattern = #"^\s*(\d{1,2}):([0-5]\d)\s*-\s*(\d{1,2}):([0-5]\d)\s*$"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(trimmed.startIndex..<trimmed.endIndex, in: trimmed)
        guard let match = regex.firstMatch(in: trimmed, range: range), match.numberOfRanges == 5 else { return nil }

        func groupInt(_ index: Int) -> Int? {
            let ns = match.range(at: index)
            guard let swiftRange = Range(ns, in: trimmed) else { return nil }
            return Int(trimmed[swiftRange])
        }

        guard let sh = groupInt(1), let sm = groupInt(2), let eh = groupInt(3), let em = groupInt(4) else {
            return nil
        }
        guard (0...23).contains(sh), (0...59).contains(sm), (0...23).contains(eh), (0...59).contains(em) else {
            return nil
        }
        return (sh, sm, eh, em)
    }

    private func parseImportedSingleTime(_ raw: String?) -> (hour: Int, minute: Int)? {
        guard let raw else { return nil }
        let trimmed = raw
            .replacingOccurrences(of: "：", with: ":")
            .replacingOccurrences(of: "—", with: "-")
            .replacingOccurrences(of: "–", with: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isUnknownImportValue(trimmed), !trimmed.contains("-") else {
            return nil
        }

        let pattern = #"^\s*(\d{1,2}):([0-5]\d)\s*$"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(trimmed.startIndex..<trimmed.endIndex, in: trimmed)
        guard let match = regex.firstMatch(in: trimmed, range: range), match.numberOfRanges == 3 else {
            return nil
        }

        func groupInt(_ index: Int) -> Int? {
            let ns = match.range(at: index)
            guard let swiftRange = Range(ns, in: trimmed) else { return nil }
            return Int(trimmed[swiftRange])
        }

        guard let hour = groupInt(1), let minute = groupInt(2),
              (0...23).contains(hour), (0...59).contains(minute) else {
            return nil
        }
        return (hour, minute)
    }

    private func resolveImportedBaseDay(_ raw: String?, preferDefaultDay: Bool = false) -> Date? {
        if let raw {
            let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                if isUnknownImportValue(trimmed) {
                    return dayOptions.first?.date
                }

                if isWeekScheduleEnabled,
                   let (week, day) = parseWeekDay(trimmed),
                   let option = dayOptions.first(where: { $0.weekIndex == week && $0.dayInWeek == day }) {
                    return option.date
                }

                if let dayIndex = parseDayIndex(trimmed),
                   dayIndex >= 1, dayIndex <= dayOptions.count {
                    return dayOptions[dayIndex - 1].date
                }

                if let exactDate = parseAbsoluteImportedDate(trimmed),
                   let option = dayOptionMatchingImportedDate(exactDate) {
                    return option.date
                }
            }
        }

        if preferDefaultDay {
            return dayOptions.first?.date
        }

        if dayOptions.count == 1 {
            return dayOptions[0].date
        }
        return nil
    }

    private func parseWeekDay(_ raw: String) -> (Int, Int)? {
        guard let regex = try? NSRegularExpression(pattern: #"(?i)\bweek\s*([0-9]{1,2})\b.*?\bday\s*([0-9]{1,2})\b"#) else {
            return nil
        }
        let range = NSRange(raw.startIndex..<raw.endIndex, in: raw)
        guard let match = regex.firstMatch(in: raw, range: range),
              match.numberOfRanges == 3,
              let weekRange = Range(match.range(at: 1), in: raw),
              let dayRange = Range(match.range(at: 2), in: raw),
              let week = Int(raw[weekRange]),
              let day = Int(raw[dayRange]),
              week >= 1,
              day >= 1 else {
            return nil
        }
        return (week, day)
    }

    private func dayOptionMatchingImportedDate(_ parsedDate: Date) -> EditorDayOption? {
        let key = Self.editorDayKey(for: parsedDate)
        if let exact = dayOptions.first(where: { $0.id == key }) {
            return exact
        }

        let calendar = Calendar.current
        let parsedParts = calendar.dateComponents([.month, .day], from: parsedDate)
        guard let parsedMonth = parsedParts.month, let parsedDay = parsedParts.day else {
            return nil
        }

        return dayOptions.first(where: { option in
            let optionParts = calendar.dateComponents([.month, .day], from: option.date)
            return optionParts.month == parsedMonth && optionParts.day == parsedDay
        })
    }

    private func parseDayIndex(_ raw: String) -> Int? {
        guard let regex = try? NSRegularExpression(pattern: #"(?i)\bday\s*([0-9]{1,2})\b"#) else {
            return nil
        }
        let range = NSRange(raw.startIndex..<raw.endIndex, in: raw)
        guard let match = regex.firstMatch(in: raw, range: range),
              match.numberOfRanges == 2,
              let valueRange = Range(match.range(at: 1), in: raw) else {
            return nil
        }
        return Int(raw[valueRange])
    }

    private func parseAbsoluteImportedDate(_ raw: String) -> Date? {
        var normalized = raw
            .replacingOccurrences(of: "年", with: "-")
            .replacingOccurrences(of: "月", with: "-")
            .replacingOccurrences(of: "日", with: "")
            .replacingOccurrences(of: ",", with: " ")
            .replacingOccurrences(of: ".", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        normalized = normalized.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
        normalized = normalized.replacingOccurrences(
            of: #"([A-Za-z])([0-9])"#,
            with: "$1 $2",
            options: .regularExpression
        )
        normalized = normalized.replacingOccurrences(
            of: #"([0-9])([A-Za-z])"#,
            with: "$1 $2",
            options: .regularExpression
        )
        normalized = normalized.trimmingCharacters(in: .whitespacesAndNewlines)

        let calendar = Calendar.current
        let selectedYear = calendar.component(.year, from: startDate)

        let fullDateFormats = [
            "yyyy-M-d", "yyyy/M/d", "yyyy M d",
            "d-M-yyyy", "d/M/yyyy", "d M yyyy"
        ]
        for format in fullDateFormats {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = TimeZone.current
            formatter.dateFormat = format
            if let parsed = formatter.date(from: normalized) {
                return calendar.startOfDay(for: parsed)
            }
        }

        let monthDayFormats = [
            "MMM d", "MMMM d", "d MMM", "d MMMM",
            "M/d", "M-d", "M d", "d/M", "d-M", "d M"
        ]
        for format in monthDayFormats {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = TimeZone.current
            formatter.dateFormat = format
            if let parsed = formatter.date(from: normalized) {
                let components = calendar.dateComponents([.month, .day], from: parsed)
                guard let month = components.month, let day = components.day else { continue }
                var target = DateComponents()
                target.year = selectedYear
                target.month = month
                target.day = day
                if let combined = calendar.date(from: target) {
                    return calendar.startOfDay(for: combined)
                }
            }
        }
        return nil
    }

    private func combine(day: Date, hour: Int, minute: Int) -> Date? {
        var parts = Calendar.current.dateComponents([.year, .month, .day], from: day)
        parts.hour = hour
        parts.minute = minute
        parts.second = 0
        return Calendar.current.date(from: parts)
    }

    private func dismissKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }

    @ViewBuilder
    private func eventImagePreview(selectedData: Data?, remoteURL: String) -> some View {
        if let selectedData,
           let image = UIImage(data: selectedData) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(height: 150)
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        } else if let resolved = AppConfig.resolvedURLString(remoteURL),
                  URL(string: resolved) != nil {
            ImageLoaderView(urlString: resolved)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(RaverTheme.card)
                )
            .frame(height: 150)
            .frame(maxWidth: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    private func jpegData(from data: Data) -> Data {
        guard let image = UIImage(data: data),
              let jpeg = image.jpegData(compressionQuality: 0.9) else {
            return data
        }
        return jpeg
    }

    private func addEmptyLineupSlot() {
        if pendingLineupEntry != nil {
            return
        }
        let defaultDayID = dayOptions.first?.id ?? Self.editorDayKey(for: startDate)
        let newSlot = EditableLineupSlot(
            actType: .solo,
            performers: [EditableLineupPerformer()],
            stageName: normalizedStageEntries.first ?? "",
            dayID: defaultDayID,
            startTime: nil,
            endTime: nil,
            isEditing: true
        )
        pendingLineupEntry = newSlot
        syncTimeDraft(with: newSlot)
    }

    private func moveStageEntry(from source: Int, to destination: Int) {
        guard stageEntries.indices.contains(source), stageEntries.indices.contains(destination) else { return }
        guard source != destination else { return }
        let value = stageEntries.remove(at: source)
        stageEntries.insert(value, at: destination)
    }

    private func clearAllLineupEntries() {
        let existingPerformerIDs = lineupEntries.flatMap { $0.performers.map(\.id) }
        let pendingPerformerIDs = pendingLineupEntry?.performers.map(\.id) ?? []
        lineupEntries.removeAll()
        pendingLineupEntry = nil
        lineupTimeDraftBySlotID.removeAll()
        clearSearchState(for: existingPerformerIDs + pendingPerformerIDs)
    }

    private func scheduleDJSearch(for performerID: UUID, keyword: String) {
        djSearchTaskByPerformerID[performerID]?.cancel()

        let trimmed = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            djCandidatesByPerformerID[performerID] = []
            _ = isSearchingDJPerformerIDs.remove(performerID)
            return
        }

        let task = Task {
            await MainActor.run {
                _ = isSearchingDJPerformerIDs.insert(performerID)
            }
            do {
                try await Task.sleep(nanoseconds: 250_000_000)
                if Task.isCancelled { return }
                let page = try await djsRepository.fetchDJs(
                    page: 1,
                    limit: 20,
                    search: trimmed,
                    sortBy: "name"
                )
                if Task.isCancelled { return }
                let filtered = page.items.filter {
                    $0.name.localizedCaseInsensitiveContains(trimmed)
                }
                await MainActor.run {
                    if djQueryByPerformerID[performerID]?.trimmingCharacters(in: .whitespacesAndNewlines) == trimmed {
                        djCandidatesByPerformerID[performerID] = filtered
                    }
                    _ = isSearchingDJPerformerIDs.remove(performerID)
                }
            } catch is CancellationError {
                await MainActor.run {
                    _ = isSearchingDJPerformerIDs.remove(performerID)
                }
            } catch {
                await MainActor.run {
                    _ = isSearchingDJPerformerIDs.remove(performerID)
                    if djQueryByPerformerID[performerID]?.trimmingCharacters(in: .whitespacesAndNewlines) == trimmed {
                        errorMessage = L("DJ 搜索失败：\(error.userFacingMessage ?? "")", "DJ search failed: \(error.userFacingMessage ?? "")")
                    }
                }
            }
        }
        djSearchTaskByPerformerID[performerID] = task
    }

    private func applyDJSelection(_ dj: WebDJ, to slot: Binding<EditableLineupSlot>, performerIndex: Int) {
        guard slot.wrappedValue.performers.indices.contains(performerIndex) else { return }
        let performerID = slot.wrappedValue.performers[performerIndex].id
        slot.wrappedValue.performers[performerIndex].djId = dj.id
        slot.wrappedValue.performers[performerIndex].djName = dj.name
        djQueryByPerformerID[performerID] = dj.name
        djCandidatesByPerformerID[performerID] = []
        isSearchingDJPerformerIDs.remove(performerID)
        djSearchTaskByPerformerID[performerID]?.cancel()
    }

    @ViewBuilder
    private func djCandidateAvatar(_ dj: WebDJ) -> some View {
        if let urlString = AppConfig.resolvedDJAvatarURLString(dj.avatarSmallUrl ?? dj.avatarUrl, size: .small),
           URL(string: urlString) != nil {
            ImageLoaderView(urlString: urlString)
                .background(
                    Circle()
                        .fill(RaverTheme.card)
                        .overlay(
                            Text(String(dj.name.prefix(1)).uppercased())
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(RaverTheme.secondaryText)
                        )
                )
            .frame(width: 22, height: 22)
            .clipShape(Circle())
        } else {
            Circle()
                .fill(RaverTheme.card)
                .overlay(
                    Text(String(dj.name.prefix(1)).uppercased())
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(RaverTheme.secondaryText)
                )
                .frame(width: 22, height: 22)
        }
    }

    private func removeLineupSlot(_ id: UUID) {
        let performerIDs = lineupEntries.first(where: { $0.id == id })?.performers.map(\.id) ?? []
        lineupEntries.removeAll { $0.id == id }
        lineupTimeDraftBySlotID[id] = nil
        clearSearchState(for: performerIDs)
    }

    private func sortLineupEntriesForDisplay() {
        let stageOrder = normalizedStageEntries
        lineupEntries.sort { lhs, rhs in
            let lhsStage = stageBucketName(for: lhs)
            let rhsStage = stageBucketName(for: rhs)
            let lhsStageIndex = stageOrder.firstIndex(of: lhsStage) ?? Int.max
            let rhsStageIndex = stageOrder.firstIndex(of: rhsStage) ?? Int.max

            if lhsStageIndex != rhsStageIndex {
                return lhsStageIndex < rhsStageIndex
            }

            if lhsStage != rhsStage {
                return lhsStage.localizedCaseInsensitiveCompare(rhsStage) == .orderedAscending
            }

            return lineupSlotSort(lhs, rhs)
        }
    }

    private func buildLineupSlotsInput() -> [EventLineupSlotInput]? {
        var result: [EventLineupSlotInput] = []
        let sortedEntries = groupedLineupSlotGroups
            .flatMap(\.slotIDs)
            .compactMap { id in
                lineupEntries.first(where: { $0.id == id })
            }

        for (index, item) in sortedEntries.enumerated() {
            let expectedCount = item.actType.performerCount
            let trimmedNames = item.performers
                .prefix(expectedCount)
                .map { $0.djName.trimmingCharacters(in: .whitespacesAndNewlines) }

            guard trimmedNames.count == expectedCount else {
                errorMessage = L("第 \(index + 1) 条阵容数据异常，请重新编辑该条目", "Lineup item #\(index + 1) is invalid. Please edit it again.")
                return nil
            }

            guard !trimmedNames.contains(where: { $0.isEmpty }) else {
                errorMessage = item.actType == .solo
                    ? L("第 \(index + 1) 个 DJ 名称为空，请补全或删除后再保存", "DJ name #\(index + 1) is empty. Please complete or remove it before saving.")
                    : L("第 \(index + 1) 个 \(item.actType.title) 条目有未填写的 DJ，请补全后再保存", "Act #\(index + 1) (\(item.actType.title)) has empty DJ names. Please complete before saving.")
                return nil
            }

            let normalizedStage = item.stageName.trimmingCharacters(in: .whitespacesAndNewlines)
            if !normalizedStageEntries.isEmpty && normalizedStage.isEmpty {
                errorMessage = L("第 \(index + 1) 个 DJ 请选择舞台", "Please choose a stage for DJ #\(index + 1).")
                return nil
            }

            if (item.startTime == nil) != (item.endTime == nil) {
                errorMessage = L("第 \(index + 1) 个 DJ 的开始和结束时间需要同时填写", "Start and end time for DJ #\(index + 1) must be filled together.")
                return nil
            }

            if let start = item.startTime, let end = item.endTime, end < start {
                errorMessage = L("第 \(index + 1) 个 DJ 的结束时间不能早于开始时间", "End time for DJ #\(index + 1) cannot be earlier than start time.")
                return nil
            }

            let composedName = EventLineupActCodec.composeName(type: item.actType, performerNames: trimmedNames)
            guard !composedName.isEmpty else {
                errorMessage = L("第 \(index + 1) 个 DJ 名称为空，请补全后再保存", "DJ name #\(index + 1) is empty. Please complete before saving.")
                return nil
            }

            let primaryDJID: String? = {
                let candidate = item.performers.first?.djId?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                return candidate.isEmpty ? nil : candidate
            }()
            let resolvedDayID = resolveDayID(for: item)
            let resolvedFestivalDayIndex = festivalDayIndex(for: resolvedDayID)

            result.append(
                EventLineupSlotInput(
                    djId: primaryDJID,
                    festivalDayIndex: resolvedFestivalDayIndex,
                    djName: composedName,
                    stageName: normalizedStage.nilIfEmpty,
                    sortOrder: index + 1,
                    startTime: item.startTime,
                    endTime: item.endTime
                )
            )
        }

        return result
    }

    private static func editorDayKey(for date: Date) -> String {
        editorDayKeyFormatter.string(from: date)
    }

    private static let editorDayKeyFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private static let editorDayLabelFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = AppLanguagePreference.current.effectiveLanguage == .en
            ? Locale(identifier: "en_US_POSIX")
            : Locale(identifier: "zh_CN")
        formatter.timeZone = .current
        formatter.dateFormat = AppLanguagePreference.current.effectiveLanguage == .en ? "MMM d" : "M月d日"
        return formatter
    }()

    private static let editorHourMinuteFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

}

private struct EventLocationPickerResult {
    let latitude: Double
    let longitude: Double
    let displayAddress: String
    let city: String?
    let country: String?
    let placeName: String?
}

private final class EventPickerCurrentLocationProvider: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published private(set) var coordinate: CLLocationCoordinate2D?
    @Published private(set) var authorizationStatus: CLAuthorizationStatus

    private let manager = CLLocationManager()

    override init() {
        authorizationStatus = manager.authorizationStatus
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
    }

    func requestCurrentLocation() {
        authorizationStatus = manager.authorizationStatus
        switch authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            manager.requestLocation()
        case .denied, .restricted:
            break
        @unknown default:
            break
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        if authorizationStatus == .authorizedAlways || authorizationStatus == .authorizedWhenInUse {
            manager.requestLocation()
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        coordinate = locations.last?.coordinate
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Event picker location error: \(error.userFacingMessage ?? "")")
    }
}

private struct EventLocationSearchCandidate: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let coordinate: CLLocationCoordinate2D?

    var displayLabel: String {
        let merged = [title, subtitle]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        return merged.isEmpty ? title : merged
    }
}

private final class EventLocationSearchModel: NSObject, ObservableObject, MKLocalSearchCompleterDelegate {
    @Published var query: String = ""
    @Published var queryCandidates: [EventLocationSearchCandidate] = []
    @Published var nearbyCandidates: [EventLocationSearchCandidate] = []
    @Published var isLoadingNearby = false

    private let completer = MKLocalSearchCompleter()

    override init() {
        super.init()
        completer.delegate = self
        completer.resultTypes = [.address, .pointOfInterest]
    }

    func updateQuery(_ value: String) {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        query = trimmed
        if trimmed.isEmpty {
            queryCandidates = []
            completer.queryFragment = ""
            return
        }
        completer.queryFragment = trimmed
    }

    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        guard !query.isEmpty else {
            queryCandidates = []
            return
        }
        queryCandidates = completer.results.map { item in
            EventLocationSearchCandidate(
                id: "\(item.title)|\(item.subtitle)",
                title: item.title,
                subtitle: item.subtitle,
                coordinate: nil
            )
        }
    }

    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        print("Event location completer error: \(error.userFacingMessage ?? "")")
        queryCandidates = []
    }

    @MainActor
    func searchNearby(around coordinate: CLLocationCoordinate2D) async {
        isLoadingNearby = true
        defer { isLoadingNearby = false }

        let request = MKLocalSearch.Request()
        request.resultTypes = [.pointOfInterest, .address]
        request.region = MKCoordinateRegion(
            center: coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        )

        do {
            let response = try await MKLocalSearch(request: request).start()
            var dedup = Set<String>()
            var result: [EventLocationSearchCandidate] = []
            for item in response.mapItems {
                let coordinate = item.placemark.coordinate
                let title = item.name?
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .nilIfEmpty
                    ?? item.placemark.thoroughfare?.trimmingCharacters(in: .whitespacesAndNewlines)
                    ?? item.placemark.locality?.trimmingCharacters(in: .whitespacesAndNewlines)
                    ?? ""
                let subtitleParts = [
                    item.placemark.locality,
                    item.placemark.subLocality,
                    item.placemark.thoroughfare
                ]
                    .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty }
                let subtitle = subtitleParts.joined(separator: " ")
                let key = "\(title)|\(subtitle)|\(String(format: "%.5f", coordinate.latitude)),\(String(format: "%.5f", coordinate.longitude))"
                guard !title.isEmpty || !subtitle.isEmpty, !dedup.contains(key) else { continue }
                dedup.insert(key)
                result.append(
                    EventLocationSearchCandidate(
                        id: key,
                        title: title.isEmpty ? L("附近地点", "Nearby place") : title,
                        subtitle: subtitle,
                        coordinate: coordinate
                    )
                )
                if result.count >= 20 { break }
            }
            nearbyCandidates = result
        } catch {
            nearbyCandidates = []
        }
    }
}

private struct EventLocationPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var searchModel = EventLocationSearchModel()
    @StateObject private var locationProvider = EventPickerCurrentLocationProvider()

    private enum CandidateListMode {
        case nearby
        case query
    }

    let initialLatitude: Double?
    let initialLongitude: Double?
    let initialAddress: String
    let onConfirm: (EventLocationPickerResult) -> Void

    @State private var query: String
    @State private var mapPosition: MapCameraPosition
    @State private var pinCoordinate: CLLocationCoordinate2D
    @State private var selectedCandidate: EventLocationSearchCandidate?
    @State private var isResolving = false
    @State private var errorMessage: String?
    @State private var listMode: CandidateListMode = .nearby
    @State private var nearbySearchTask: Task<Void, Never>?
    @FocusState private var isSearchFieldFocused: Bool
    @State private var hasAppliedInitialDeviceLocation = false

    init(
        initialLatitude: Double?,
        initialLongitude: Double?,
        initialAddress: String,
        onConfirm: @escaping (EventLocationPickerResult) -> Void
    ) {
        self.initialLatitude = initialLatitude
        self.initialLongitude = initialLongitude
        self.initialAddress = initialAddress
        self.onConfirm = onConfirm

        let fallbackCenter = CLLocationCoordinate2D(latitude: 31.2304, longitude: 121.4737)
        let center = CLLocationCoordinate2D(
            latitude: initialLatitude ?? fallbackCenter.latitude,
            longitude: initialLongitude ?? fallbackCenter.longitude
        )
        _query = State(initialValue: initialAddress)
        _pinCoordinate = State(initialValue: center)
        _mapPosition = State(
            initialValue: .region(
                MKCoordinateRegion(
                    center: center,
                    span: MKCoordinateSpan(latitudeDelta: 0.015, longitudeDelta: 0.015)
                )
            )
        )
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                mapArea
                Divider().overlay(Color.white.opacity(0.08))
                locationListArea
            }
            .background(RaverTheme.background)
            .raverSystemNavigation(title: LL("选择活动定位"))
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(L("确认", "Confirm")) {
                        Task { await confirmCurrentLocation() }
                    }
                    .disabled(isResolving)
                }
            }
            .safeAreaInset(edge: .top) {
                VStack(spacing: 10) {
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(RaverTheme.secondaryText)
                        TextField(LL("搜索地点"), text: $query)
                            .textInputAutocapitalization(.never)
                            .disableAutocorrection(true)
                            .focused($isSearchFieldFocused)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(RaverTheme.card)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .padding(.horizontal, 14)
                    .padding(.top, 8)
                    .padding(.bottom, 6)
                }
                .background(.ultraThinMaterial)
            }
            .onAppear {
                searchModel.updateQuery(query)
                scheduleNearbySearch(for: pinCoordinate)
                locationProvider.requestCurrentLocation()
            }
            .onReceive(locationProvider.$coordinate) { coordinate in
                guard let coordinate else { return }
                guard !hasAppliedInitialDeviceLocation else { return }
                hasAppliedInitialDeviceLocation = true
                pinCoordinate = coordinate
                mapPosition = .region(
                    MKCoordinateRegion(
                        center: coordinate,
                        span: MKCoordinateSpan(latitudeDelta: 0.015, longitudeDelta: 0.015)
                    )
                )
                listMode = .nearby
                scheduleNearbySearch(for: coordinate)
            }
            .onChange(of: query) { _, newValue in
                searchModel.updateQuery(newValue)
                if !newValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    listMode = .query
                } else if !isSearchFieldFocused {
                    listMode = .nearby
                }
            }
            .onChange(of: isSearchFieldFocused) { _, isFocused in
                if isFocused {
                    listMode = .query
                } else if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    listMode = .nearby
                }
            }
            .onDisappear {
                nearbySearchTask?.cancel()
            }
            .alert(L("提示", "Notice"), isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button(L("确定", "OK"), role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
        }
        .raverEnableCustomSwipeBack(edgeRatio: 0.2)
    }

    private var mapArea: some View {
        ZStack {
            Map(position: $mapPosition, interactionModes: .all) {}
                .mapStyle(.standard(elevation: .realistic))
                .frame(maxWidth: .infinity, minHeight: 280, maxHeight: 360)
                .onMapCameraChange(frequency: .onEnd) { context in
                    pinCoordinate = context.region.center
                    listMode = .nearby
                    scheduleNearbySearch(for: context.region.center)
                }

            VStack(spacing: 0) {
                Image(systemName: "mappin.circle.fill")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(RaverTheme.accent)
                    .shadow(color: Color.black.opacity(0.3), radius: 10, x: 0, y: 4)
                    .offset(y: -17)
                Circle()
                    .fill(RaverTheme.accent.opacity(0.9))
                    .frame(width: 6, height: 6)
                    .offset(y: -17)
            }
            .allowsHitTesting(false)

            if isResolving {
                ProgressView()
                    .padding(10)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }

            VStack {
                HStack {
                    Spacer()
                    Button {
                        centerOnCurrentLocation(forceRequest: true)
                    } label: {
                        Image(systemName: "location.fill")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 34, height: 34)
                            .background(.ultraThinMaterial, in: Circle())
                            .overlay(
                                Circle()
                                    .stroke(Color.white.opacity(0.2), lineWidth: 0.5)
                            )
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 10)
                    .padding(.trailing, 12)
                }
                Spacer()
            }
        }
    }

    private var locationListArea: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 6) {
                    Image(systemName: listMode == .query ? "magnifyingglass" : "scope")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(RaverTheme.secondaryText)
                    Text(listMode == .query ? L("搜索候选地点", "Search candidates") : L("附近推荐地点", "Nearby recommendations"))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(RaverTheme.secondaryText)
                    Spacer(minLength: 0)
                    if listMode == .nearby, searchModel.isLoadingNearby {
                        ProgressView()
                            .controlSize(.mini)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 10)
                .padding(.bottom, 8)

                if displayedCandidates.isEmpty {
                    Text(emptyHintText)
                        .font(.subheadline)
                        .foregroundStyle(RaverTheme.secondaryText)
                        .padding(.horizontal, 16)
                        .padding(.top, 6)
                        .padding(.bottom, 22)
                } else {
                    ForEach(displayedCandidates) { candidate in
                        Button {
                            Task { await chooseCandidate(candidate) }
                        } label: {
                            HStack(alignment: .top, spacing: 10) {
                                Image(systemName: "mappin.and.ellipse")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(RaverTheme.accent)
                                    .padding(.top, 1)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(candidate.title)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(RaverTheme.primaryText)
                                        .lineLimit(1)
                                    if !candidate.subtitle.isEmpty {
                                        Text(candidate.subtitle)
                                            .font(.caption)
                                            .foregroundStyle(RaverTheme.secondaryText)
                                            .lineLimit(2)
                                    }
                                }
                                Spacer()
                                if selectedCandidate?.id == candidate.id {
                                    Image(systemName: "scope")
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(RaverTheme.accent)
                                        .padding(.top, 2)
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        Divider().overlay(Color.white.opacity(0.06))
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @MainActor
    private func chooseCandidate(_ candidate: EventLocationSearchCandidate) async {
        guard !isResolving else { return }
        selectedCandidate = candidate

        if let coordinate = candidate.coordinate {
            pinCoordinate = coordinate
            mapPosition = .region(
                MKCoordinateRegion(
                    center: coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.015, longitudeDelta: 0.015)
                )
            )
            return
        }

        isResolving = true
        defer { isResolving = false }

        do {
            let request = MKLocalSearch.Request()
            request.naturalLanguageQuery = candidate.displayLabel
            request.resultTypes = [.address, .pointOfInterest]
            let response = try await MKLocalSearch(request: request).start()
            if let coordinate = response.mapItems.first?.placemark.coordinate {
                pinCoordinate = coordinate
                mapPosition = .region(
                    MKCoordinateRegion(
                        center: coordinate,
                        span: MKCoordinateSpan(latitudeDelta: 0.015, longitudeDelta: 0.015)
                    )
                )
            }
        } catch {
            errorMessage = L("地点解析失败，请重试", "Failed to resolve location. Please try again.")
        }
    }

    @MainActor
    private func confirmCurrentLocation() async {
        guard !isResolving else { return }
        isResolving = true
        defer { isResolving = false }

        let coordinate = pinCoordinate
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        var resolvedAddress = selectedCandidate?.displayLabel.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        var city: String?
        var country: String?
        var placeName: String?

        do {
            if let placemark = try await reverseGeocode(coordinate: coordinate) {
                placeName = placemark.name?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
                city = (placemark.locality ?? placemark.subAdministrativeArea)?
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .nilIfEmpty
                country = placemark.country?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty

                let components = [
                    placemark.country,
                    placemark.administrativeArea,
                    placemark.locality,
                    placemark.subLocality,
                    placemark.thoroughfare,
                    placemark.subThoroughfare,
                    placemark.name
                ]
                let merged = components
                    .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty }
                if !merged.isEmpty {
                    let unique = Array(NSOrderedSet(array: merged)) as? [String] ?? merged
                    resolvedAddress = unique.joined(separator: " ")
                }
            }
        } catch {
            // Keep coordinate-only selection available even if reverse geocoding fails.
        }

        if resolvedAddress.isEmpty, !trimmedQuery.isEmpty {
            resolvedAddress = trimmedQuery
        }
        let finalAddress = resolvedAddress.isEmpty
            ? "\(coordinate.latitude), \(coordinate.longitude)"
            : resolvedAddress

        onConfirm(
            EventLocationPickerResult(
                latitude: coordinate.latitude,
                longitude: coordinate.longitude,
                displayAddress: finalAddress,
                city: city,
                country: country,
                placeName: placeName
            )
        )
        dismiss()
    }

    private var displayedCandidates: [EventLocationSearchCandidate] {
        switch listMode {
        case .query:
            return searchModel.queryCandidates
        case .nearby:
            return searchModel.nearbyCandidates
        }
    }

    private var emptyHintText: String {
        switch listMode {
        case .query:
            return query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? L("输入关键词搜索地点", "Enter keywords to search places")
                : L("未找到匹配地点", "No matching places found")
        case .nearby:
            return L("拖动地图后，将在这里展示 pin 附近地点", "After dragging the map, nearby places around the pin will appear here.")
        }
    }

    private func scheduleNearbySearch(for coordinate: CLLocationCoordinate2D) {
        nearbySearchTask?.cancel()
        nearbySearchTask = Task {
            try? await Task.sleep(nanoseconds: 220_000_000)
            guard !Task.isCancelled else { return }
            await searchModel.searchNearby(around: coordinate)
        }
    }

    private func centerOnCurrentLocation(forceRequest: Bool) {
        if let coordinate = locationProvider.coordinate {
            pinCoordinate = coordinate
            mapPosition = .region(
                MKCoordinateRegion(
                    center: coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.015, longitudeDelta: 0.015)
                )
            )
            listMode = .nearby
            scheduleNearbySearch(for: coordinate)
            return
        }

        if forceRequest {
            locationProvider.requestCurrentLocation()
        }

        switch locationProvider.authorizationStatus {
        case .denied, .restricted:
            errorMessage = L("定位权限未开启，请在系统设置中允许定位后重试", "Location permission is disabled. Please enable it in Settings and try again.")
        default:
            errorMessage = L("正在获取当前位置，请稍后再试", "Getting current location. Please try again shortly.")
        }
    }

    private func reverseGeocode(coordinate: CLLocationCoordinate2D) async throws -> CLPlacemark? {
        try await withCheckedThrowingContinuation { continuation in
            CLGeocoder().reverseGeocodeLocation(
                CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude),
                preferredLocale: Locale(identifier: "zh_CN")
            ) { placemarks, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                continuation.resume(returning: placemarks?.first)
            }
        }
    }
}
