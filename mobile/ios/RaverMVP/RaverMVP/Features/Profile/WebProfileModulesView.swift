import SwiftUI
import PhotosUI
import UIKit

struct MyCheckinsView: View {
    @Environment(\.dismiss) private var dismiss

    private struct TimelineDJEntry: Identifiable {
        let id: String
        let attendedAt: Date
        let dj: CheckinDJLite
    }

    private struct TimelineNode: Identifiable {
        let id: String
        var anchorDate: Date
        let day: Date
        let event: CheckinEventLite?
        var eventCheckin: WebCheckin?
        var djs: [TimelineDJEntry]
        var manualEventName: String?

        var isStandaloneDJNode: Bool {
            event == nil
        }
    }

    private enum DisplayMode: String, CaseIterable {
        case timeline
        case gallery
    }

    private enum GalleryMode: String, CaseIterable {
        case event
        case dj
    }

    private let targetUserID: String?
    private let navigationTitleText: String
    private let service = AppEnvironment.makeWebService()

    @State private var displayMode: DisplayMode = .timeline
    @State private var galleryMode: GalleryMode = .event
    @State private var page = 1
    @State private var totalPages = 1
    @State private var items: [WebCheckin] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var selectedEventIDForDetail: String?
    @State private var selectedDJIDForDetail: String?

    init(targetUserID: String? = nil, title: String = "我的打卡") {
        self.targetUserID = targetUserID
        self.navigationTitleText = title
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Picker("视图", selection: $displayMode) {
                    Text("时间轴视图").tag(DisplayMode.timeline)
                    Text("Gallery视图").tag(DisplayMode.gallery)
                }
                .pickerStyle(.segmented)

                if displayMode == .gallery {
                    Picker("Gallery 类型", selection: $galleryMode) {
                        Text("活动").tag(GalleryMode.event)
                        Text("DJ").tag(GalleryMode.dj)
                    }
                    .pickerStyle(.segmented)
                }

                if isLoading && isCurrentViewEmpty {
                    ProgressView("加载打卡记录...")
                        .frame(maxWidth: .infinity, minHeight: 220)
                } else if isCurrentViewEmpty {
                    VStack(spacing: 12) {
                        ContentUnavailableView("还没有观演记录", systemImage: "sparkles.tv")
                        Text("去发现页完成活动或 DJ 打卡，记录会按你选择的观演时间展示。")
                            .font(.caption)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(RaverTheme.secondaryText)
                    }
                    .frame(maxWidth: .infinity, minHeight: 280)
                } else {
                    if displayMode == .timeline {
                        timelineView
                    } else {
                        galleryView
                    }

                    if page < totalPages {
                        Button("加载更多") {
                            Task { await loadMore() }
                        }
                        .buttonStyle(.bordered)
                        .padding(.top, 4)
                    }
                }
            }
        }
        .background(RaverTheme.background)
        .scrollIndicators(.hidden)
        .toolbar(.hidden, for: .navigationBar)
        .safeAreaInset(edge: .top) {
            HStack {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(width: 34, height: 34)
                        .background(Color.black.opacity(0.36))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)

                Spacer()

                Text(navigationTitleText)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(RaverTheme.primaryText)

                Spacer()

                Color.clear
                    .frame(width: 34, height: 34)
            }
            .padding(.horizontal, 14)
            .padding(.top, 4)
            .padding(.bottom, 6)
        }
        .task {
            await reload()
        }
        .refreshable {
            await reload()
        }
        .fullScreenCover(
            isPresented: Binding(
                get: { selectedEventIDForDetail != nil },
                set: { if !$0 { selectedEventIDForDetail = nil } }
            )
        ) {
            if let eventID = selectedEventIDForDetail {
                NavigationStack {
                    EventDetailView(eventID: eventID)
                }
            }
        }
        .fullScreenCover(
            isPresented: Binding(
                get: { selectedDJIDForDetail != nil },
                set: { if !$0 { selectedDJIDForDetail = nil } }
            )
        ) {
            if let djID = selectedDJIDForDetail {
                NavigationStack {
                    DJDetailView(djID: djID)
                }
            }
        }
        .alert("提示", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("确定", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func reload() async {
        page = 1
        totalPages = 1
        items = []
        await loadMore(reset: true)
    }

    private var rawVisibleItems: [WebCheckin] {
        items
            .filter { item in
                let normalizedNote = item.note?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                // `planned` means wish-list style intent, not an attended record.
                // Keep `marked` because historical data may use it for attended checkins.
                return normalizedNote != "planned"
            }
            .sorted { lhs, rhs in
                lhs.attendedAt > rhs.attendedAt
            }
    }

    private var timelineNodes: [TimelineNode] {
        buildTimelineNodes(from: rawVisibleItems)
    }

    private var galleryEventNodes: [TimelineNode] {
        timelineNodes.filter { $0.event != nil }
    }

    private var galleryDJEntries: [TimelineDJEntry] {
        timelineNodes
            .flatMap { $0.djs }
            .sorted { $0.attendedAt > $1.attendedAt }
    }

    private var isCurrentViewEmpty: Bool {
        switch displayMode {
        case .timeline:
            return timelineNodes.isEmpty
        case .gallery:
            return galleryMode == .event ? galleryEventNodes.isEmpty : galleryDJEntries.isEmpty
        }
    }

    private var timelineView: some View {
        ZStack(alignment: .topLeading) {
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.98, green: 0.78, blue: 0.69),
                            Color(red: 0.99, green: 0.91, blue: 0.84),
                            Color.white.opacity(0.12)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 2)
                .padding(.leading, 11)
                .padding(.top, 10)

            VStack(spacing: 26) {
                ForEach(timelineNodes) { node in
                    timelineNodeRow(node)
                }
            }
            .padding(.leading, 6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }

    private var galleryView: some View {
        Group {
            if galleryMode == .event {
                galleryEventView
            } else {
                galleryDJView
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }

    private var galleryEventView: some View {
        let columns = [
            GridItem(.flexible(), spacing: 12),
            GridItem(.flexible(), spacing: 12)
        ]

        return LazyVGrid(columns: columns, spacing: 14) {
            ForEach(galleryEventNodes) { node in
                if let event = node.event {
                    VStack(alignment: .leading, spacing: 8) {
                        Button {
                            selectedEventIDForDetail = event.id
                        } label: {
                            eventHero(for: event)
                                .frame(height: 124)
                                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
                        .buttonStyle(.plain)

                        Text(eventNodeTitle(for: node))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(RaverTheme.primaryText)
                            .lineLimit(2)
                    }
                }
            }
        }
    }

    private var galleryDJView: some View {
        let columns = [
            GridItem(.flexible(minimum: 0), spacing: 8, alignment: .top),
            GridItem(.flexible(minimum: 0), spacing: 8, alignment: .top),
            GridItem(.flexible(minimum: 0), spacing: 8, alignment: .top),
            GridItem(.flexible(minimum: 0), spacing: 8, alignment: .top)
        ]

        return LazyVGrid(columns: columns, spacing: 12) {
            ForEach(galleryDJEntries) { entry in
                Button {
                    selectedDJIDForDetail = entry.dj.id
                } label: {
                    VStack(spacing: 8) {
                        djAvatar(for: entry.dj)
                            .frame(width: 72, height: 72)
                        Text(entry.dj.name)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(RaverTheme.primaryText)
                            .lineLimit(2)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func timelineNodeRow(_ node: TimelineNode) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Circle()
                .fill(Color(red: 0.98, green: 0.45, blue: 0.27))
                .frame(width: 12, height: 12)
                .background(
                    Circle()
                        .fill(RaverTheme.background)
                        .frame(width: 28, height: 28)
                )
                .padding(.top, 42)

            VStack(alignment: .leading, spacing: 12) {
                timelineTimestamp(for: node)
                timelineExperienceCard(node)
            }
        }
    }

    private func timelineTimestamp(for node: TimelineNode) -> some View {
        Text(node.day.formatted(.dateTime.year().month().day().weekday(.abbreviated)))
            .font(.headline.weight(.bold))
            .foregroundStyle(RaverTheme.primaryText)
    }

    private func timelineExperienceCard(_ node: TimelineNode) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            if let event = node.event {
                VStack(alignment: .leading, spacing: 0) {
                    Button {
                        selectedEventIDForDetail = event.id
                    } label: {
                        eventHero(for: event)
                            .frame(height: 188)
                            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .contentShape(Rectangle())

                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .top, spacing: 10) {
                            VStack(alignment: .leading, spacing: 4) {
                                if let seriesName = eventSeriesName(for: node) {
                                    Text(seriesName)
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(Color(red: 0.84, green: 0.42, blue: 0.28))
                                }

                                Text(eventNodeTitle(for: node))
                                    .font(.title3.weight(.bold))
                                    .foregroundStyle(RaverTheme.primaryText)
                                    .multilineTextAlignment(.leading)
                                    .lineLimit(2)
                            }
                            Spacer(minLength: 8)
                        }

                        Text(eventTimelineSubtitle(event))
                            .font(.subheadline)
                            .foregroundStyle(RaverTheme.secondaryText)
                            .lineLimit(2)
                    }
                    .padding(.top, 14)
                }
            } else {
                standaloneDJHeader(manualEventName: node.manualEventName)
            }

            if !node.djs.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text(node.isStandaloneDJNode ? "这次打卡的 DJ" : "这场打卡的 DJ")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(RaverTheme.primaryText)

                        Spacer()

                        Text("\(node.djs.count) 位")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color(red: 0.82, green: 0.39, blue: 0.20))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color(red: 1.00, green: 0.94, blue: 0.90), in: Capsule())
                    }

                    LazyVGrid(
                        columns: [
                            GridItem(.flexible(minimum: 0), spacing: 8, alignment: .top),
                            GridItem(.flexible(minimum: 0), spacing: 8, alignment: .top),
                            GridItem(.flexible(minimum: 0), spacing: 8, alignment: .top),
                            GridItem(.flexible(minimum: 0), spacing: 8, alignment: .top)
                        ],
                        alignment: .leading,
                        spacing: 10
                    ) {
                        ForEach(node.djs) { entry in
                            timelineDJButton(entry)
                        }
                    }
                }
                .padding(.top, node.event == nil ? 0 : 4)
            }
        }
        .padding(.trailing, 4)
    }

    @ViewBuilder
    private func eventHero(for event: CheckinEventLite) -> some View {
        if let cover = AppConfig.resolvedURLString(event.coverImageUrl), let url = URL(string: cover) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .empty:
                    ZStack {
                        Color(red: 0.99, green: 0.94, blue: 0.90)
                        ProgressView()
                    }
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                case .failure:
                    eventTimelineFallback
                @unknown default:
                    eventTimelineFallback
                }
            }
        } else {
            eventTimelineFallback
        }
    }

    private var eventTimelineFallback: some View {
        LinearGradient(
            colors: [
                Color(red: 0.99, green: 0.70, blue: 0.54),
                Color(red: 0.84, green: 0.42, blue: 0.28)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay(
            VStack(spacing: 10) {
                Image(systemName: "music.note.house.fill")
                    .font(.title)
                Text("Festival Memory")
                    .font(.headline.weight(.semibold))
            }
            .foregroundStyle(Color.white.opacity(0.92))
        )
    }

    private func standaloneDJHeader(manualEventName: String?) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.99, green: 0.74, blue: 0.66),
                            Color(red: 0.96, green: 0.55, blue: 0.42)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(height: 144)
                .overlay(
                    VStack(spacing: 10) {
                        Image(systemName: "waveform.path.ecg.rectangle.fill")
                            .font(.title2)
                        Text(manualEventName ?? "独立 DJ 打卡")
                            .font(.headline.weight(.bold))
                    }
                    .foregroundStyle(Color.white.opacity(0.95))
                )

            Text(
                manualEventName == nil
                    ? "这条记录附近没有匹配到活动打卡，所以先单独展示。"
                    : "未在活动库中匹配到该活动，已按你手动填写的信息记录。"
            )
                .font(.subheadline)
                .foregroundStyle(RaverTheme.secondaryText)
        }
    }

    private func timelineDJButton(_ entry: TimelineDJEntry) -> some View {
        Button {
            selectedDJIDForDetail = entry.dj.id
        } label: {
            VStack(spacing: 6) {
                djAvatar(for: entry.dj)
                    .frame(width: 54, height: 54)

                Text(entry.dj.name)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(RaverTheme.primaryText)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 4)
            .frame(maxWidth: .infinity, minHeight: 80, alignment: .top)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func djAvatar(for dj: CheckinDJLite) -> some View {
        if let avatar = AppConfig.resolvedURLString(dj.avatarUrl), let url = URL(string: avatar) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .empty:
                    Circle().fill(RaverTheme.card)
                case .success(let image):
                    image.resizable().scaledToFill()
                case .failure:
                    djAvatarFallback(for: dj)
                @unknown default:
                    djAvatarFallback(for: dj)
                }
            }
            .clipShape(Circle())
        } else {
            djAvatarFallback(for: dj)
        }
    }

    private func djAvatarFallback(for dj: CheckinDJLite) -> some View {
        Circle()
            .fill(
                LinearGradient(
                    colors: [Color(red: 0.30, green: 0.67, blue: 0.97), Color(red: 0.42, green: 0.22, blue: 0.78)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                Text(String(dj.name.prefix(1)).uppercased())
                    .font(.title2.weight(.bold))
                    .foregroundStyle(Color.white)
            )
    }

    private func eventNodeTitle(for node: TimelineNode) -> String {
        guard let event = node.event else {
            return "独立 DJ 打卡"
        }

        guard let startDate = event.startDate else {
            return event.name
        }

        let calendar = Calendar.current
        let startDay = calendar.startOfDay(for: startDate)
        let currentDay = calendar.startOfDay(for: node.day)
        let dayOffset = calendar.dateComponents([.day], from: startDay, to: currentDay).day ?? 0
        let totalDaySpan = event.endDate.map {
            max(1, (calendar.dateComponents([.day], from: startDay, to: calendar.startOfDay(for: $0)).day ?? 0) + 1)
        } ?? 1

        guard totalDaySpan > 1, dayOffset >= 0 else {
            return event.name
        }

        return "\(event.name) Day\(dayOffset + 1)"
    }

    private func eventSeriesName(for node: TimelineNode) -> String? {
        guard let event = node.event else { return nil }
        let titledName = eventNodeTitle(for: node)
        return titledName == event.name ? nil : event.name
    }

    private func eventTimelineSubtitle(_ event: CheckinEventLite) -> String {
        let location = [event.city, event.country]
            .compactMap { value in
                guard let value, !value.isEmpty else { return nil }
                return value
            }
            .joined(separator: " · ")
        return location.isEmpty ? "当日观演记录" : location
    }

    private func buildTimelineNodes(from items: [WebCheckin]) -> [TimelineNode] {
        var nodesByKey: [String: TimelineNode] = [:]

        for item in items where item.type == "event" {
            guard let event = item.event else { continue }
            let day = Calendar.current.startOfDay(for: item.attendedAt)
            let key = "\(event.id)|\(Int(day.timeIntervalSince1970))"

            if var existing = nodesByKey[key] {
                if item.attendedAt > existing.anchorDate {
                    existing.anchorDate = item.attendedAt
                    existing.eventCheckin = item
                }
                nodesByKey[key] = existing
            } else {
                nodesByKey[key] = TimelineNode(
                    id: key,
                    anchorDate: item.attendedAt,
                    day: day,
                    event: event,
                    eventCheckin: item,
                    djs: [],
                    manualEventName: nil
                )
            }
        }

        for item in items where item.type == "dj" {
            guard let dj = item.dj else { continue }
            let day = Calendar.current.startOfDay(for: item.attendedAt)
            let manualEventName = manualEventName(from: item.note)
            let candidateKeys = nodesByKey.keys.filter { key in
                guard let node = nodesByKey[key], node.day == day else { return false }
                if let eventID = item.eventId {
                    return node.event?.id == eventID
                }
                if let manualEventName {
                    guard node.event == nil else { return false }
                    return node.manualEventName?.caseInsensitiveCompare(manualEventName) == .orderedSame
                }
                return node.event == nil
            }

            let selectedKey = candidateKeys.min { lhs, rhs in
                guard let leftNode = nodesByKey[lhs], let rightNode = nodesByKey[rhs] else { return false }
                let leftDistance = abs(leftNode.anchorDate.timeIntervalSince(item.attendedAt))
                let rightDistance = abs(rightNode.anchorDate.timeIntervalSince(item.attendedAt))
                return leftDistance < rightDistance
            }

            let entry = TimelineDJEntry(id: item.id, attendedAt: item.attendedAt, dj: dj)

            if let selectedKey, var node = nodesByKey[selectedKey] {
                if let existingIndex = node.djs.firstIndex(where: { $0.dj.id == dj.id }) {
                    if item.attendedAt > node.djs[existingIndex].attendedAt {
                        node.djs[existingIndex] = entry
                    }
                } else {
                    node.djs.append(entry)
                }
                if item.attendedAt > node.anchorDate {
                    node.anchorDate = item.attendedAt
                }
                if node.manualEventName == nil, let manualEventName {
                    node.manualEventName = manualEventName
                }
                node.djs.sort { $0.attendedAt < $1.attendedAt }
                nodesByKey[selectedKey] = node
            } else {
                let standaloneKey: String = {
                    if let eventID = item.eventId, !eventID.isEmpty {
                        return "dj|\(eventID)|\(Int(day.timeIntervalSince1970))"
                    }
                    if let manualEventName {
                        return "dj|manual|\(normalizedStandaloneEventKey(manualEventName))|\(Int(day.timeIntervalSince1970))"
                    }
                    return "dj|none|\(Int(day.timeIntervalSince1970))"
                }()
                if var existing = nodesByKey[standaloneKey] {
                    if let existingIndex = existing.djs.firstIndex(where: { $0.dj.id == dj.id }) {
                        if item.attendedAt > existing.djs[existingIndex].attendedAt {
                            existing.djs[existingIndex] = entry
                        }
                    } else {
                        existing.djs.append(entry)
                    }
                    if item.attendedAt > existing.anchorDate {
                        existing.anchorDate = item.attendedAt
                    }
                    if existing.manualEventName == nil, let manualEventName {
                        existing.manualEventName = manualEventName
                    }
                    existing.djs.sort { $0.attendedAt < $1.attendedAt }
                    nodesByKey[standaloneKey] = existing
                } else {
                    nodesByKey[standaloneKey] = TimelineNode(
                        id: standaloneKey,
                        anchorDate: item.attendedAt,
                        day: day,
                        event: nil,
                        eventCheckin: nil,
                        djs: [entry],
                        manualEventName: manualEventName
                    )
                }
            }
        }

        return nodesByKey.values.sorted { lhs, rhs in
            lhs.anchorDate > rhs.anchorDate
        }
    }

    private func manualEventName(from note: String?) -> String? {
        guard let note else { return nil }
        let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.lowercased().hasPrefix("manual_event:") else { return nil }
        let rawName = String(trimmed.dropFirst("manual_event:".count)).trimmingCharacters(in: .whitespacesAndNewlines)
        return rawName.isEmpty ? nil : rawName
    }

    private func normalizedStandaloneEventKey(_ name: String) -> String {
        name
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "\\s+", with: "-", options: .regularExpression)
            .replacingOccurrences(of: "[^a-z0-9\\u4e00-\\u9fa5-]", with: "", options: .regularExpression)
    }

    private func loadMore(reset: Bool = false) async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            let result: CheckinListPage
            if let targetUserID {
                result = try await service.fetchUserCheckins(userID: targetUserID, page: page, limit: 20, type: nil)
            } else {
                result = try await service.fetchMyCheckins(page: page, limit: 20, type: nil)
            }

            let eventOnlyResult: CheckinListPage?
            if reset {
                // Timeline/gallery event nodes should not be buried by numerous DJ checkins.
                if let targetUserID {
                    eventOnlyResult = try? await service.fetchUserCheckins(userID: targetUserID, page: 1, limit: 200, type: "event")
                } else {
                    eventOnlyResult = try? await service.fetchMyCheckins(page: 1, limit: 200, type: "event")
                }
            } else {
                eventOnlyResult = nil
            }

            if reset {
                items = mergeUniqueCheckins(result.items, with: eventOnlyResult?.items ?? [])
            } else {
                items = mergeUniqueCheckins(items + result.items, with: [])
            }
            totalPages = result.pagination?.totalPages ?? 1
            page += 1
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func mergeUniqueCheckins(_ base: [WebCheckin], with extras: [WebCheckin]) -> [WebCheckin] {
        var mergedByID: [String: WebCheckin] = [:]
        for item in base + extras {
            if let existing = mergedByID[item.id] {
                if item.attendedAt > existing.attendedAt {
                    mergedByID[item.id] = item
                }
            } else {
                mergedByID[item.id] = item
            }
        }
        return mergedByID.values.sorted { lhs, rhs in
            if lhs.attendedAt == rhs.attendedAt {
                return lhs.createdAt > rhs.createdAt
            }
            return lhs.attendedAt > rhs.attendedAt
        }
    }

    private func delete(_ id: String) async {
        do {
            try await service.deleteCheckin(id: id)
            items.removeAll { $0.id == id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct MyPublishesView: View {
    private let service = AppEnvironment.makeWebService()
    private let socialService = AppEnvironment.makeService()

    @State private var selectedTab = 0
    @State private var publishes = MyPublishes(djSets: [], events: [], ratingEvents: [], ratingUnits: [])
    @State private var newsPublishes: [Post] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    @State private var editingEvent: WebEvent?
    @State private var editingSet: WebDJSet?
    @State private var editingRatingEvent: WebRatingEvent?
    @State private var editingRatingUnit: WebRatingUnit?
    @State private var selectedEventIDForDetail: String?

    var body: some View {
        List {
            Picker("发布类型", selection: $selectedTab) {
                Text("Sets").tag(0)
                Text("活动").tag(1)
                Text("打分").tag(2)
                Text("资讯").tag(3)
            }
            .pickerStyle(.segmented)

            if selectedTab == 0 {
                if publishes.djSets.isEmpty, !isLoading {
                    ContentUnavailableView("暂无发布 Set", systemImage: "waveform")
                        .listRowBackground(Color.clear)
                }

                ForEach(publishes.djSets) { set in
                    NavigationLink {
                        DJSetDetailView(setID: set.id)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(set.title)
                                .font(.headline)
                            Text("\(set.trackCount) tracks")
                                .font(.caption)
                                .foregroundStyle(RaverTheme.secondaryText)
                            Text(set.createdAt.formatted(date: .abbreviated, time: .shortened))
                                .font(.caption2)
                                .foregroundStyle(RaverTheme.secondaryText)
                        }
                        .padding(.vertical, 4)
                    }
                    .swipeActions {
                        Button {
                            Task { await prepareEditSet(id: set.id) }
                        } label: {
                            Label("编辑", systemImage: "pencil")
                        }

                        Button(role: .destructive) {
                            Task { await deleteSet(id: set.id) }
                        } label: {
                            Label("删除", systemImage: "trash")
                        }
                    }
                }
            } else if selectedTab == 1 {
                if publishes.events.isEmpty, !isLoading {
                    ContentUnavailableView("暂无发布活动", systemImage: "calendar")
                        .listRowBackground(Color.clear)
                }

                ForEach(publishes.events) { event in
                    Button {
                        selectedEventIDForDetail = event.id
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(event.name)
                                .font(.headline)
                            Text(event.startDate.formatted(date: .abbreviated, time: .omitted))
                                .font(.caption)
                                .foregroundStyle(RaverTheme.secondaryText)
                            Text([event.city, event.country].compactMap { $0 }.joined(separator: ", "))
                                .font(.caption2)
                                .foregroundStyle(RaverTheme.secondaryText)
                            Text(event.createdAt.formatted(date: .abbreviated, time: .shortened))
                                .font(.caption2)
                                .foregroundStyle(RaverTheme.secondaryText)
                        }
                        .padding(.vertical, 4)
                    }
                    .swipeActions {
                        Button {
                            Task { await prepareEditEvent(id: event.id) }
                        } label: {
                            Label("编辑", systemImage: "pencil")
                        }

                        Button(role: .destructive) {
                            Task { await deleteEvent(id: event.id) }
                        } label: {
                            Label("删除", systemImage: "trash")
                        }
                    }
                }
            } else if selectedTab == 2 {
                if publishes.ratingEvents.isEmpty, publishes.ratingUnits.isEmpty, !isLoading {
                    ContentUnavailableView("暂无发布打分", systemImage: "star.leadinghalf.filled")
                        .listRowBackground(Color.clear)
                }

                if !publishes.ratingEvents.isEmpty {
                    Section("我发布的打分事件") {
                        ForEach(publishes.ratingEvents) { event in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(event.name)
                                    .font(.headline)
                                Text("\(event.unitCount) 个打分单位")
                                    .font(.caption)
                                    .foregroundStyle(RaverTheme.secondaryText)
                                Text(event.createdAt.formatted(date: .abbreviated, time: .shortened))
                                    .font(.caption2)
                                    .foregroundStyle(RaverTheme.secondaryText)
                            }
                            .padding(.vertical, 4)
                            .swipeActions {
                                Button {
                                    Task { await prepareEditRatingEvent(id: event.id) }
                                } label: {
                                    Label("编辑", systemImage: "pencil")
                                }

                                Button(role: .destructive) {
                                    Task { await deleteRatingEvent(id: event.id) }
                                } label: {
                                    Label("删除", systemImage: "trash")
                                }
                            }
                        }
                    }
                }

                if !publishes.ratingUnits.isEmpty {
                    Section("我发布的打分单位") {
                        ForEach(publishes.ratingUnits) { unit in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(unit.name)
                                    .font(.headline)
                                Text("所属事件：\(unit.eventName)")
                                    .font(.caption)
                                    .foregroundStyle(RaverTheme.secondaryText)
                                Text(unit.createdAt.formatted(date: .abbreviated, time: .shortened))
                                    .font(.caption2)
                                    .foregroundStyle(RaverTheme.secondaryText)
                            }
                            .padding(.vertical, 4)
                            .swipeActions {
                                Button {
                                    Task { await prepareEditRatingUnit(id: unit.id) }
                                } label: {
                                    Label("编辑", systemImage: "pencil")
                                }

                                Button(role: .destructive) {
                                    Task { await deleteRatingUnit(id: unit.id) }
                                } label: {
                                    Label("删除", systemImage: "trash")
                                }
                            }
                        }
                    }
                }
            } else {
                if newsPublishes.isEmpty, !isLoading {
                    ContentUnavailableView("暂无发布资讯", systemImage: "newspaper")
                        .listRowBackground(Color.clear)
                }

                ForEach(newsPublishes) { post in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(post.raverNewsTitle)
                            .font(.headline)
                            .lineLimit(2)
                        Text(post.raverNewsSource)
                            .font(.caption)
                            .foregroundStyle(RaverTheme.secondaryText)
                        Text(post.createdAt.formatted(date: .abbreviated, time: .shortened))
                            .font(.caption2)
                            .foregroundStyle(RaverTheme.secondaryText)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("我的发布")
        .task {
            await load()
        }
        .refreshable {
            await load()
        }
        .sheet(item: $editingEvent) { event in
            EventEditorView(mode: .edit(event)) {
                Task { await load() }
            }
        }
        .sheet(item: $editingSet) { set in
            DJSetEditorView(mode: .edit(set)) {
                Task { await load() }
            }
        }
        .sheet(item: $editingRatingEvent) { event in
            RatingEventEditorSheet(event: event) {
                Task { await load() }
            }
        }
        .sheet(item: $editingRatingUnit) { unit in
            RatingUnitEditorSheet(unit: unit) {
                Task { await load() }
            }
        }
        .fullScreenCover(
            isPresented: Binding(
                get: { selectedEventIDForDetail != nil },
                set: { if !$0 { selectedEventIDForDetail = nil } }
            )
        ) {
            if let eventID = selectedEventIDForDetail {
                NavigationStack {
                    EventDetailView(eventID: eventID)
                }
            }
        }
        .alert("提示", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("确定", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }

        do {
            async let publishesTask = service.fetchMyPublishes()
            async let newsTask = loadMyNewsPublishes()
            publishes = try await publishesTask
            newsPublishes = try await newsTask
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func loadMyNewsPublishes() async throws -> [Post] {
        let profile = try await socialService.fetchMyProfile()
        var cursor: String?
        var rounds = 0
        var merged: [Post] = []
        var seen: Set<String> = []

        repeat {
            let page = try await socialService.fetchPostsByUser(userID: profile.id, cursor: cursor)
            for post in page.posts where post.isRaverNews && !seen.contains(post.id) {
                seen.insert(post.id)
                merged.append(post)
            }
            cursor = page.nextCursor
            rounds += 1
        } while cursor != nil && rounds < 6

        return merged.sorted { $0.createdAt > $1.createdAt }
    }

    private func prepareEditEvent(id: String) async {
        do {
            editingEvent = try await service.fetchEvent(id: id)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func prepareEditSet(id: String) async {
        do {
            editingSet = try await service.fetchDJSet(id: id)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func prepareEditRatingEvent(id: String) async {
        do {
            editingRatingEvent = try await service.fetchRatingEvent(id: id)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func prepareEditRatingUnit(id: String) async {
        do {
            editingRatingUnit = try await service.fetchRatingUnit(id: id)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func deleteSet(id: String) async {
        do {
            try await service.deleteDJSet(id: id)
            publishes.djSets.removeAll { $0.id == id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func deleteEvent(id: String) async {
        do {
            try await service.deleteEvent(id: id)
            publishes.events.removeAll { $0.id == id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func deleteRatingEvent(id: String) async {
        do {
            try await service.deleteRatingEvent(id: id)
            publishes.ratingEvents.removeAll { $0.id == id }
            publishes.ratingUnits.removeAll { $0.eventId == id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func deleteRatingUnit(id: String) async {
        do {
            try await service.deleteRatingUnit(id: id)
            publishes.ratingUnits.removeAll { $0.id == id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct RatingEventEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    private let service = AppEnvironment.makeWebService()

    let event: WebRatingEvent
    let onSaved: () -> Void

    @State private var name: String
    @State private var description: String
    @State private var imageUrl: String
    @State private var selectedCoverPhoto: PhotosPickerItem?
    @State private var selectedCoverData: Data?
    @State private var isSaving = false
    @State private var isUploadingCover = false
    @State private var errorMessage: String?

    init(event: WebRatingEvent, onSaved: @escaping () -> Void) {
        self.event = event
        self.onSaved = onSaved
        _name = State(initialValue: event.name)
        _description = State(initialValue: event.description ?? "")
        _imageUrl = State(initialValue: event.imageUrl ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("编辑打分事件") {
                    TextField("名称", text: $name)
                    TextField("描述（选填）", text: $description, axis: .vertical)
                        .lineLimit(2...4)
                    TextField("封面 URL（选填）", text: $imageUrl)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    PhotosPicker(selection: $selectedCoverPhoto, matching: .images) {
                        Label(selectedCoverData == nil ? "从相册上传封面图" : "更换封面图", systemImage: "photo")
                    }
                    if let selectedCoverData,
                       let preview = UIImage(data: selectedCoverData) {
                        Image(uiImage: preview)
                            .resizable()
                            .scaledToFill()
                            .frame(height: 140)
                            .frame(maxWidth: .infinity)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    if selectedCoverData != nil {
                        Text("已选择本地封面图，保存时会自动上传并使用该图片。")
                            .font(.caption)
                            .foregroundStyle(RaverTheme.secondaryText)
                    }
                }
            }
            .navigationTitle("编辑打分事件")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(isSaving ? "保存中..." : "保存") {
                        Task { await save() }
                    }
                    .disabled(isSaving || isUploadingCover)
                }
            }
            .onChange(of: selectedCoverPhoto) { _, newValue in
                Task { await loadSelectedCoverPhoto(newValue) }
            }
            .alert("提示", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("确定", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    @MainActor
    private func save() async {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            errorMessage = "名称不能为空"
            return
        }
        isSaving = true
        defer { isSaving = false }
        do {
            var finalImageURL = imageUrl.trimmingCharacters(in: .whitespacesAndNewlines)
            if let selectedCoverData {
                isUploadingCover = true
                defer { isUploadingCover = false }
                let upload = try await service.uploadEventImage(
                    imageData: jpegData(from: selectedCoverData),
                    fileName: "rating-event-edit-\(UUID().uuidString).jpg",
                    mimeType: "image/jpeg"
                )
                finalImageURL = upload.url
            }
            _ = try await service.updateRatingEvent(
                id: event.id,
                input: UpdateRatingEventInput(
                    name: trimmedName,
                    description: description.trimmingCharacters(in: .whitespacesAndNewlines),
                    imageUrl: finalImageURL
                )
            )
            onSaved()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func loadSelectedCoverPhoto(_ item: PhotosPickerItem?) async {
        guard let item else {
            selectedCoverData = nil
            return
        }
        do {
            selectedCoverData = try await item.loadTransferable(type: Data.self)
        } catch {
            selectedCoverData = nil
            errorMessage = "读取图片失败，请重试"
        }
    }

    private func jpegData(from data: Data) -> Data {
        guard let image = UIImage(data: data),
              let jpeg = image.jpegData(compressionQuality: 0.9) else {
            return data
        }
        return jpeg
    }
}

private struct RatingUnitEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    private let service = AppEnvironment.makeWebService()

    let unit: WebRatingUnit
    let onSaved: () -> Void

    @State private var name: String
    @State private var description: String
    @State private var imageUrl: String
    @State private var selectedCoverPhoto: PhotosPickerItem?
    @State private var selectedCoverData: Data?
    @State private var isSaving = false
    @State private var isUploadingCover = false
    @State private var errorMessage: String?

    init(unit: WebRatingUnit, onSaved: @escaping () -> Void) {
        self.unit = unit
        self.onSaved = onSaved
        _name = State(initialValue: unit.name)
        _description = State(initialValue: unit.description ?? "")
        _imageUrl = State(initialValue: unit.imageUrl ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("编辑打分单位") {
                    TextField("名称", text: $name)
                    TextField("描述（选填）", text: $description, axis: .vertical)
                        .lineLimit(2...4)
                    TextField("封面 URL（选填）", text: $imageUrl)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    PhotosPicker(selection: $selectedCoverPhoto, matching: .images) {
                        Label(selectedCoverData == nil ? "从相册上传单位图" : "更换单位图片", systemImage: "photo")
                    }
                    if let selectedCoverData,
                       let preview = UIImage(data: selectedCoverData) {
                        Image(uiImage: preview)
                            .resizable()
                            .scaledToFill()
                            .frame(height: 140)
                            .frame(maxWidth: .infinity)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    if selectedCoverData != nil {
                        Text("已选择本地单位图，保存时会自动上传并使用该图片。")
                            .font(.caption)
                            .foregroundStyle(RaverTheme.secondaryText)
                    }
                }
            }
            .navigationTitle("编辑打分单位")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(isSaving ? "保存中..." : "保存") {
                        Task { await save() }
                    }
                    .disabled(isSaving || isUploadingCover)
                }
            }
            .onChange(of: selectedCoverPhoto) { _, newValue in
                Task { await loadSelectedCoverPhoto(newValue) }
            }
            .alert("提示", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("确定", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    @MainActor
    private func save() async {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            errorMessage = "名称不能为空"
            return
        }
        isSaving = true
        defer { isSaving = false }
        do {
            var finalImageURL = imageUrl.trimmingCharacters(in: .whitespacesAndNewlines)
            if let selectedCoverData {
                isUploadingCover = true
                defer { isUploadingCover = false }
                let upload = try await service.uploadEventImage(
                    imageData: jpegData(from: selectedCoverData),
                    fileName: "rating-unit-edit-\(UUID().uuidString).jpg",
                    mimeType: "image/jpeg"
                )
                finalImageURL = upload.url
            }
            _ = try await service.updateRatingUnit(
                id: unit.id,
                input: UpdateRatingUnitInput(
                    name: trimmedName,
                    description: description.trimmingCharacters(in: .whitespacesAndNewlines),
                    imageUrl: finalImageURL
                )
            )
            onSaved()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func loadSelectedCoverPhoto(_ item: PhotosPickerItem?) async {
        guard let item else {
            selectedCoverData = nil
            return
        }
        do {
            selectedCoverData = try await item.loadTransferable(type: Data.self)
        } catch {
            selectedCoverData = nil
            errorMessage = "读取图片失败，请重试"
        }
    }

    private func jpegData(from data: Data) -> Data {
        guard let image = UIImage(data: data),
              let jpeg = image.jpegData(compressionQuality: 0.9) else {
            return data
        }
        return jpeg
    }
}
