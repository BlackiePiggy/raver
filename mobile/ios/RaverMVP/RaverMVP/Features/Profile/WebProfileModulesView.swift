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
        var day: Date
        let event: CheckinEventLite?
        var eventCheckin: WebCheckin?
        var djs: [TimelineDJEntry]
        var manualEventName: String?
        var structuredSelections: [EventAttendanceDaySelectionPayload]

        var isStandaloneDJNode: Bool {
            event == nil
        }
    }

    private struct TimelineAttendanceSection: Identifiable {
        let id: String
        let title: String
        let djs: [TimelineDJEntry]
        var structuredDJSelections: [EventAttendanceDJSelection]?
    }

    private enum TimelineActType {
        case solo
        case b2b
        case b3b

        var performerCount: Int {
            switch self {
            case .solo: return 1
            case .b2b: return 2
            case .b3b: return 3
            }
        }
    }

    private enum TimelineCheckinAvatarSize {
        case small
        case medium
        case large

        var frameWidth: CGFloat {
            switch self {
            case .small:
                return TimelineAvatarLayout.performerSize
            case .medium:
                return TimelineAvatarLayout.contentWidth(for: 2) + TimelineAvatarLayout.mediumHorizontalInset * 2
            case .large:
                return TimelineAvatarLayout.contentWidth(for: 3) + TimelineAvatarLayout.largeHorizontalInset * 2
            }
        }

        var frameHeight: CGFloat { TimelineAvatarLayout.performerSize }
        var performerSize: CGFloat { TimelineAvatarLayout.performerSize }
    }

    private enum TimelineAvatarLayout {
        static let performerSize: CGFloat = 56
        static let performerCenterDistance: CGFloat = 68
        static let connectorSize: CGFloat = 12
        static let groupSpacing: CGFloat = 12
        static let sectionSpacing: CGFloat = 8
        static let gridSpacing: CGFloat = performerCenterDistance - performerSize
        static let mediumHorizontalInset: CGFloat = 4
        static let largeHorizontalInset: CGFloat = 7

        static func contentWidth(for performerCount: Int) -> CGFloat {
            guard performerCount > 0 else { return 0 }
            return performerSize + CGFloat(max(0, performerCount - 1)) * performerCenterDistance
        }
    }

    private struct TimelineActPerformer: Identifiable {
        let id: String
        let name: String
        let djID: String?
        let avatarUrl: String?
    }

    private struct TimelineActEntry: Identifiable {
        let id: String
        let title: String
        let type: TimelineActType
        let performers: [TimelineActPerformer]
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
    @State private var timelineDJIdentityByName: [String: CheckinDJLite] = [:]

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
        .safeAreaInset(edge: .top, spacing: 0) {
            VStack(spacing: 0) {
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
                .background(RaverTheme.background.opacity(0.98))

                LinearGradient(
                    colors: [
                        RaverTheme.background.opacity(0.96),
                        RaverTheme.background.opacity(0.72),
                        RaverTheme.background.opacity(0.34),
                        .clear
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 28)
                .allowsHitTesting(false)
            }
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
                .padding(.top, 6)

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
                    VStack(alignment: .leading, spacing: 8) {
                        timelineEventHeadline(for: node, event: event)
                            .font(.title3.weight(.bold))
                            .foregroundStyle(RaverTheme.primaryText)
                            .multilineTextAlignment(.leading)
                            .lineLimit(2)
                    }
                    .padding(.bottom, 12)

                    Button {
                        selectedEventIDForDetail = event.id
                    } label: {
                        eventHero(for: event)
                            .frame(height: 188)
                            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .contentShape(Rectangle())
                }
            } else {
                standaloneDJHeader(manualEventName: node.manualEventName)
            }

            let attendanceSections = attendanceSections(for: node)
            if !attendanceSections.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    if node.isStandaloneDJNode {
                        HStack {
                            Text("这次打卡的 DJ")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(RaverTheme.primaryText)

                            Spacer()

                            checkinCountBadge(attendanceSections.reduce(0) { total, section in
                                total + attendanceSectionDJCount(section)
                            })
                        }
                    }

                    ForEach(attendanceSections) { section in
                        VStack(alignment: .leading, spacing: 10) {
                            if node.isStandaloneDJNode {
                                Text(section.title)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(Color(red: 0.84, green: 0.42, blue: 0.28))
                            } else {
                                HStack(alignment: .center, spacing: 10) {
                                    Text(section.title)
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(Color(red: 0.84, green: 0.42, blue: 0.28))

                                    Spacer()

                                    checkinCountBadge(attendanceSectionDJCount(section))
                                }
                            }

                            if section.djs.isEmpty {
                                Text("未选择 DJ")
                                    .font(.caption)
                                    .foregroundStyle(RaverTheme.secondaryText)
                            } else {
                                if let structured = section.structuredDJSelections {
                                    timelineStructuredDJGrid(structured, sectionID: section.id)
                                } else {
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
                                        ForEach(section.djs) { entry in
                                            timelineDJButton(entry)
                                        }
                                    }
                                }
                            }
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
            Text(manualEventName ?? "单独 DJ 打卡")
                .font(.title3.weight(.bold))
                .foregroundStyle(RaverTheme.primaryText)

            Text(
                manualEventName == nil
                    ? "这次是单独的 DJ 打卡，暂无匹配活动。"
                    : "这次是单独的 DJ 打卡，暂无匹配活动，已按你填写的活动信息记录。"
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

    private func timelineStructuredDJGrid(_ selections: [EventAttendanceDJSelection], sectionID: String) -> some View {
        let acts = timelineActs(from: selections, sectionID: sectionID)
        let b3bActs = acts.filter { $0.type == .b3b }
        let b2bActs = acts.filter { $0.type == .b2b }
        let otherActs = acts.filter { $0.type == .solo }

        return VStack(alignment: .leading, spacing: TimelineAvatarLayout.groupSpacing) {
            if !b3bActs.isEmpty {
                VStack(alignment: .leading, spacing: TimelineAvatarLayout.sectionSpacing) {
                    Text("B3B")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(RaverTheme.secondaryText)
                    ForEach(b3bActs) { act in
                        timelineActItem(act, avatarSize: .large)
                    }
                }
            }

            if !b2bActs.isEmpty {
                VStack(alignment: .leading, spacing: TimelineAvatarLayout.sectionSpacing) {
                    Text("B2B")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(RaverTheme.secondaryText)
                    LazyVGrid(
                        columns: [
                            GridItem(.flexible(minimum: 0), spacing: TimelineAvatarLayout.gridSpacing, alignment: .top),
                            GridItem(.flexible(minimum: 0), spacing: TimelineAvatarLayout.gridSpacing, alignment: .top)
                        ],
                        alignment: .leading,
                        spacing: TimelineAvatarLayout.groupSpacing
                    ) {
                        ForEach(b2bActs) { act in
                            timelineActItem(act, avatarSize: .medium)
                        }
                    }
                }
            }

            if !otherActs.isEmpty {
                VStack(alignment: .leading, spacing: TimelineAvatarLayout.sectionSpacing) {
                    if !b2bActs.isEmpty || !b3bActs.isEmpty {
                        Text("其他演出")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(RaverTheme.secondaryText)
                    }
                    LazyVGrid(
                        columns: [
                            GridItem(.flexible(minimum: 0), spacing: TimelineAvatarLayout.gridSpacing, alignment: .top),
                            GridItem(.flexible(minimum: 0), spacing: TimelineAvatarLayout.gridSpacing, alignment: .top),
                            GridItem(.flexible(minimum: 0), spacing: TimelineAvatarLayout.gridSpacing, alignment: .top),
                            GridItem(.flexible(minimum: 0), spacing: TimelineAvatarLayout.gridSpacing, alignment: .top)
                        ],
                        alignment: .leading,
                        spacing: TimelineAvatarLayout.groupSpacing
                    ) {
                        ForEach(otherActs) { act in
                            timelineActItem(act, avatarSize: .small)
                        }
                    }
                }
            }
        }
    }

    private func timelineActItem(_ act: TimelineActEntry, avatarSize: TimelineCheckinAvatarSize) -> some View {
        VStack(spacing: 7) {
            timelineActAvatars(act, size: avatarSize)

            Text(act.title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(RaverTheme.primaryText)
                .lineLimit(3)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func timelineActAvatars(_ act: TimelineActEntry, size: TimelineCheckinAvatarSize) -> some View {
        let avatarSize = size.performerSize
        Group {
            if act.type == .solo {
                timelineSoloActAvatar(act, avatarSize: avatarSize)
            } else {
                timelineCollaborativeActAvatars(act, avatarSize: avatarSize)
            }
        }
        .frame(width: size.frameWidth, height: size.frameHeight)
    }

    private func timelineSoloActAvatar(_ act: TimelineActEntry, avatarSize: CGFloat) -> some View {
        timelinePerformerAvatarButton(act.performers.first, size: avatarSize)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }

    private func timelineCollaborativeActAvatars(_ act: TimelineActEntry, avatarSize: CGFloat) -> some View {
        let performers = Array(act.performers.prefix(act.type.performerCount))
        let centerDistance = TimelineAvatarLayout.performerCenterDistance
        let connectorSize = TimelineAvatarLayout.connectorSize
        let contentWidth = TimelineAvatarLayout.contentWidth(for: performers.count)
        let connectorText = act.type == .b2b ? "B2B" : "B3B"
        let connectorColor = timelineConnectorColor(for: act.type)

        return ZStack(alignment: .topLeading) {
            ForEach(performers.indices, id: \.self) { index in
                timelinePerformerAvatarButton(performers[index], size: avatarSize)
                    .offset(x: CGFloat(index) * centerDistance)
            }

            ForEach(0..<max(0, performers.count - 1), id: \.self) { index in
                timelineActConnectorLabel(text: connectorText, color: connectorColor)
                    .frame(width: connectorSize, height: connectorSize)
                    .offset(
                        x: CGFloat(index) * centerDistance + (avatarSize + centerDistance - connectorSize) / 2,
                        y: (avatarSize - connectorSize) / 2
                    )
            }
        }
        .frame(width: contentWidth, height: avatarSize, alignment: .center)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }

    private func timelineConnectorColor(for type: TimelineActType) -> Color {
        switch type {
        case .solo:
            return Color(red: 0.98, green: 0.52, blue: 0.20)
        case .b2b:
            return Color(red: 0.98, green: 0.52, blue: 0.20)
        case .b3b:
            return Color(red: 0.98, green: 0.52, blue: 0.20)
        }
    }

    @ViewBuilder
    private func timelinePerformerAvatarButton(_ performer: TimelineActPerformer?, size: CGFloat) -> some View {
        if let performer,
           let djID = performer.djID,
           !djID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            Button {
                selectedDJIDForDetail = djID
            } label: {
                timelinePerformerAvatar(performer, size: size)
            }
            .buttonStyle(.plain)
        } else {
            timelinePerformerAvatar(performer, size: size)
        }
    }

    private func timelinePerformerAvatar(_ performer: TimelineActPerformer?, size: CGFloat) -> some View {
        Group {
            if let avatar = AppConfig.resolvedURLString(performer?.avatarUrl),
               let url = URL(string: avatar) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        Circle().fill(RaverTheme.card)
                    case .success(let image):
                        image.resizable().scaledToFill()
                    case .failure:
                        timelinePerformerFallback(performer)
                    @unknown default:
                        timelinePerformerFallback(performer)
                    }
                }
            } else {
                timelinePerformerFallback(performer)
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }

    private func timelinePerformerFallback(_ performer: TimelineActPerformer?) -> some View {
        let initial = String((performer?.name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(1) ?? "?")).uppercased()
        return Circle()
            .fill(
                LinearGradient(
                    colors: [Color(red: 0.30, green: 0.67, blue: 0.97), Color(red: 0.42, green: 0.22, blue: 0.78)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                Text(initial)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(Color.white)
            )
    }

    private func timelineActConnectorLabel(text: String, color: Color) -> some View {
        Circle()
            .fill(color.opacity(0.24))
            .overlay(
                Text(text)
                    .font(.system(size: 4.4, weight: .black, design: .rounded))
                    .foregroundStyle(color)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
            )
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
        return event.name
    }

    private func timelineEventHeadline(for node: TimelineNode, event: CheckinEventLite) -> Text {
        let title = Text(eventNodeTitle(for: node))
        let location = eventTimelineSubtitle(event)
        guard !location.isEmpty else { return title }
        return title + Text(" · \(location)")
    }

    private func eventTimelineSubtitle(_ event: CheckinEventLite) -> String {
        let location = [event.city, event.country]
            .compactMap { value in
                guard let value, !value.isEmpty else { return nil }
                return value
            }
            .joined(separator: " · ")
        return location
    }

    private func checkinCountBadge(_ count: Int) -> some View {
        Text("\(count) 位")
            .font(.caption.weight(.semibold))
            .foregroundStyle(Color(red: 0.82, green: 0.39, blue: 0.20))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Color(red: 1.00, green: 0.94, blue: 0.90), in: Capsule())
    }

    private func attendanceSectionDJCount(_ section: TimelineAttendanceSection) -> Int {
        guard let structured = section.structuredDJSelections else {
            return section.djs.count
        }

        return structured.reduce(0) { total, selection in
            let rawName = selection.name.trimmingCharacters(in: .whitespacesAndNewlines)
            if let names = splitActNames(rawName, keyword: "B3B"), names.count >= 3 {
                return total + 3
            }
            if let names = splitActNames(rawName, keyword: "B2B"), names.count >= 2 {
                return total + 2
            }
            return total + 1
        }
    }

    private func buildTimelineNodes(from items: [WebCheckin]) -> [TimelineNode] {
        var nodesByKey: [String: TimelineNode] = [:]

        for item in items where item.type == "event" {
            guard let event = item.event else { continue }
            let day = Calendar.current.startOfDay(for: item.attendedAt)
            let key = "event|\(event.id)"
            let structuredSelections = item.eventAttendanceSelections
            let structuredDJs = timelineDJEntries(from: structuredSelections, attendedAt: item.attendedAt)

            if var existing = nodesByKey[key] {
                if item.attendedAt > existing.anchorDate {
                    existing.anchorDate = item.attendedAt
                    existing.day = day
                    existing.eventCheckin = item
                    existing.structuredSelections = structuredSelections
                    if !structuredDJs.isEmpty {
                        existing.djs = structuredDJs
                    }
                }
                nodesByKey[key] = existing
            } else {
                nodesByKey[key] = TimelineNode(
                    id: key,
                    anchorDate: item.attendedAt,
                    day: day,
                    event: event,
                    eventCheckin: item,
                    djs: structuredDJs,
                    manualEventName: nil,
                    structuredSelections: structuredSelections
                )
            }
        }

        for item in items where item.type == "dj" {
            guard let dj = item.dj else { continue }
            let day = Calendar.current.startOfDay(for: item.attendedAt)
            let manualEventName = manualEventName(from: item.note)
            if let eventID = item.eventId,
               nodesByKey.values.contains(where: { $0.event?.id == eventID && !$0.structuredSelections.isEmpty }) {
                continue
            }
            let candidateKeys = nodesByKey.keys.filter { key in
                guard let node = nodesByKey[key], node.day == day else { return false }
                if let eventID = item.eventId {
                    guard node.structuredSelections.isEmpty else { return false }
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
                        manualEventName: manualEventName,
                        structuredSelections: []
                    )
                }
            }
        }

        return nodesByKey.values.sorted { lhs, rhs in
            lhs.anchorDate > rhs.anchorDate
        }
    }

    private func timelineDJEntries(from selections: [EventAttendanceDaySelectionPayload], attendedAt: Date) -> [TimelineDJEntry] {
        selections
            .sorted { $0.dayIndex < $1.dayIndex }
            .enumerated()
            .flatMap { sectionIndex, payload in
                payload.djSelections.enumerated().map { index, selection in
                    TimelineDJEntry(
                        id: "structured-\(payload.dayID)-\(selection.id)",
                        attendedAt: attendedAt.addingTimeInterval(TimeInterval(sectionIndex * 100 + index)),
                        dj: CheckinDJLite(
                            id: selection.id,
                            name: selection.name,
                            avatarUrl: selection.avatarUrl,
                            country: selection.country
                        )
                    )
                }
            }
    }

    private func timelineActs(from selections: [EventAttendanceDJSelection], sectionID: String) -> [TimelineActEntry] {
        selections.enumerated().compactMap { index, selection in
            timelineAct(from: selection, entryID: "\(sectionID)-\(index)")
        }
    }

    private func timelineAct(from selection: EventAttendanceDJSelection, entryID: String) -> TimelineActEntry? {
        let rawName = selection.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !rawName.isEmpty else { return nil }

        if let names = splitActNames(rawName, keyword: "B3B"), names.count >= 3 {
            let performers = Array(names.prefix(3).enumerated()).map { offset, name in
                timelineActPerformer(name: name, fallbackID: "\(entryID)-b3b-\(offset)")
            }
            return TimelineActEntry(id: "\(entryID)-b3b", title: rawName, type: .b3b, performers: performers)
        }

        if let names = splitActNames(rawName, keyword: "B2B"), names.count >= 2 {
            let performers = Array(names.prefix(2).enumerated()).map { offset, name in
                timelineActPerformer(name: name, fallbackID: "\(entryID)-b2b-\(offset)")
            }
            return TimelineActEntry(id: "\(entryID)-b2b", title: rawName, type: .b2b, performers: performers)
        }

        let explicitID = normalizedTimelineDJID(selection.id)
        let performer = timelineActPerformer(
            name: rawName,
            fallbackID: "\(entryID)-solo",
            explicitDJID: explicitID,
            explicitAvatarURL: selection.avatarUrl
        )
        return TimelineActEntry(id: "\(entryID)-solo", title: rawName, type: .solo, performers: [performer])
    }

    private func timelineActPerformer(
        name: String,
        fallbackID: String,
        explicitDJID: String? = nil,
        explicitAvatarURL: String? = nil
    ) -> TimelineActPerformer {
        let normalizedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let lookupKey = normalizedTimelineNameKey(normalizedName)
        let resolved = timelineDJIdentityByName[lookupKey]
        let resolvedID = resolved?.id
        let resolvedAvatar = resolved?.avatarUrl
        let djID = (explicitDJID?.isEmpty == false) ? explicitDJID : resolvedID
        let avatar = (explicitAvatarURL?.isEmpty == false) ? explicitAvatarURL : resolvedAvatar

        return TimelineActPerformer(
            id: fallbackID,
            name: normalizedName,
            djID: djID,
            avatarUrl: avatar
        )
    }

    private func splitActNames(_ raw: String, keyword: String) -> [String]? {
        guard !raw.isEmpty else { return nil }
        let token = "__CHECKIN_SPLIT_TOKEN__"
        let pattern = "(?i)\\s*\(keyword)\\s*"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(raw.startIndex..<raw.endIndex, in: raw)
        let replaced = regex.stringByReplacingMatches(in: raw, options: [], range: range, withTemplate: token)
        let parts = replaced
            .components(separatedBy: token)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return parts.isEmpty ? nil : parts
    }

    private func normalizedTimelineDJID(_ raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let lowered = trimmed.lowercased()
        if lowered.hasPrefix("act-") || lowered.hasPrefix("solo-") {
            return nil
        }
        return trimmed
    }

    private func normalizedTimelineNameKey(_ name: String) -> String {
        name
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
    }

    private func hydrateTimelineDJIdentityMap(from checkins: [WebCheckin]) async {
        let names = unresolvedTimelinePerformerNames(from: checkins)
        guard !names.isEmpty else { return }

        var resolved: [String: CheckinDJLite] = [:]
        for name in names {
            let lookupKey = normalizedTimelineNameKey(name)
            guard !lookupKey.isEmpty, timelineDJIdentityByName[lookupKey] == nil else { continue }
            do {
                let page = try await service.fetchDJs(page: 1, limit: 20, search: name, sortBy: "name")
                if let match = page.items.first(where: { normalizedTimelineNameKey($0.name) == lookupKey }) {
                    resolved[lookupKey] = CheckinDJLite(
                        id: match.id,
                        name: match.name,
                        avatarUrl: match.avatarUrl,
                        country: match.country
                    )
                }
            } catch {
                continue
            }
        }

        guard !resolved.isEmpty else { return }
        for (key, value) in resolved where timelineDJIdentityByName[key] == nil {
            timelineDJIdentityByName[key] = value
        }
    }

    private func unresolvedTimelinePerformerNames(from checkins: [WebCheckin]) -> [String] {
        var names = Set<String>()
        for checkin in checkins {
            let selections = checkin.eventAttendanceSelections
            guard !selections.isEmpty else { continue }
            for day in selections {
                for selection in day.djSelections {
                    let rawName = selection.name.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !rawName.isEmpty else { continue }

                    if let split = splitActNames(rawName, keyword: "B3B"), split.count >= 3 {
                        for name in split.prefix(3) {
                            let key = normalizedTimelineNameKey(name)
                            if timelineDJIdentityByName[key] == nil {
                                names.insert(name)
                            }
                        }
                        continue
                    }

                    if let split = splitActNames(rawName, keyword: "B2B"), split.count >= 2 {
                        for name in split.prefix(2) {
                            let key = normalizedTimelineNameKey(name)
                            if timelineDJIdentityByName[key] == nil {
                                names.insert(name)
                            }
                        }
                        continue
                    }

                    if normalizedTimelineDJID(selection.id) == nil {
                        let key = normalizedTimelineNameKey(rawName)
                        if timelineDJIdentityByName[key] == nil {
                            names.insert(rawName)
                        }
                    }
                }
            }
        }

        return names.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    private func attendanceSections(for node: TimelineNode) -> [TimelineAttendanceSection] {
        if node.isStandaloneDJNode {
            guard !node.djs.isEmpty else { return [] }
            return [
                    TimelineAttendanceSection(
                        id: "standalone-\(node.id)",
                        title: "单独 DJ 打卡",
                        djs: node.djs,
                        structuredDJSelections: nil
                    )
                ]
        }

        if !node.structuredSelections.isEmpty {
            return node.structuredSelections
                .sorted { $0.dayIndex < $1.dayIndex }
                .map { selection in
                    TimelineAttendanceSection(
                        id: selection.dayID,
                        title: "Day\(selection.dayIndex)",
                        djs: timelineDJEntries(from: [selection], attendedAt: node.anchorDate),
                        structuredDJSelections: selection.djSelections
                    )
                }
        }

        guard let title = fallbackDayLabel(for: node) else { return [] }
        return [
            TimelineAttendanceSection(
                id: "fallback-\(node.id)",
                title: title,
                djs: node.djs,
                structuredDJSelections: nil
            )
        ]
    }

    private func fallbackDayLabel(for node: TimelineNode) -> String? {
        guard let event = node.event, let startDate = event.startDate else { return nil }
        let calendar = Calendar.current
        let startDay = calendar.startOfDay(for: startDate)
        let currentDay = calendar.startOfDay(for: node.day)
        let dayOffset = calendar.dateComponents([.day], from: startDay, to: currentDay).day ?? 0
        let totalDaySpan = event.endDate.map {
            max(1, (calendar.dateComponents([.day], from: startDay, to: calendar.startOfDay(for: $0)).day ?? 0) + 1)
        } ?? 1
        guard totalDaySpan > 1, dayOffset >= 0 else { return nil }
        return "Day\(dayOffset + 1)"
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
            await hydrateTimelineDJIdentityMap(from: items)
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
                let upload = try await service.uploadRatingImage(
                    imageData: jpegData(from: selectedCoverData),
                    fileName: "rating-event-edit-\(UUID().uuidString).jpg",
                    mimeType: "image/jpeg",
                    ratingEventID: event.id,
                    ratingUnitID: nil,
                    usage: "event-cover"
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
                let upload = try await service.uploadRatingImage(
                    imageData: jpegData(from: selectedCoverData),
                    fileName: "rating-unit-edit-\(UUID().uuidString).jpg",
                    mimeType: "image/jpeg",
                    ratingEventID: nil,
                    ratingUnitID: unit.id,
                    usage: "unit-cover"
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
