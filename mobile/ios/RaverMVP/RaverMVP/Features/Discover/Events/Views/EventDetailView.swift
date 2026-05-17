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
import SDWebImageSwiftUI
import SDWebImage

private struct EventDetailTabFramePreferenceKey: PreferenceKey {
    static var defaultValue: [EventDetailView.EventDetailTab: CGRect] = [:]

    static func reduce(value: inout [EventDetailView.EventDetailTab: CGRect], nextValue: () -> [EventDetailView.EventDetailTab: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}

private struct EventCardSharePresentation: Identifiable {
    let id = UUID()
    let payload: EventShareCardPayload
}

private enum EventTimeZoneDisplay {
    static func eventTimeZone(for event: WebEvent) -> TimeZone? {
        guard let raw = event.timeZone?.trimmingCharacters(in: .whitespacesAndNewlines),
              !raw.isEmpty else {
            return nil
        }
        return TimeZone(identifier: raw)
    }

    static func slotTimeRange(_ slot: WebEventLineupSlot, event: WebEvent) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "HH:mm"
        formatter.timeZone = .current
        let deviceText = "\(formatter.string(from: slot.startTime)) - \(formatter.string(from: slot.endTime))"
        guard let zone = eventTimeZone(for: event),
              zone.identifier != TimeZone.current.identifier else {
            return "\(deviceText) · \(Date.appLocalizedTimeZoneLabel())"
        }
        formatter.timeZone = zone
        let eventText = "\(formatter.string(from: slot.startTime)) - \(formatter.string(from: slot.endTime))"
        return "\(deviceText) · \(Date.appLocalizedTimeZoneLabel()) / \(eventText) · \(Date.appLocalizedTimeZoneLabel(zone))"
    }
}

struct EventLiveDiscussionView: View {
    @Environment(\.appPush) private var appPush
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState
    @Environment(\.colorScheme) private var colorScheme

    let eventID: String
    let eventName: String
    let eventReadRepository: EventReadRepository
    let discussionRepository: EventLiveDiscussionRepository
    let discussionMediaRepository: EventDiscussionMediaRepository

    @State private var comments: [EventLiveComment] = []
    @State private var event: WebEvent?
    @State private var phase: LoadPhase = .idle
    @State private var sortMode: EventLiveCommentSortMode = .oldest
    @State private var draft = ""
    @State private var replyTarget: EventLiveComment?
    @State private var selectedImageItems: [PhotosPickerItem] = []
    @State private var imageURLs: [String] = []
    @State private var isUploadingImage = false
    @State private var isSending = false
    @State private var errorMessage: String?
    @State private var showLiveStageOverlay = false
    @State private var isLiveStagePanelCollapsed = false

    private struct EventStageTimelineEntry: Identifiable, Hashable {
        let id: String
        let act: EventLineupResolvedAct
        let timeText: String
        let startTime: Date
        let endTime: Date

        var actName: String {
            let name = act.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
            return name.isEmpty ? LT("待公布 DJ", "待公布 DJ", "DJ発表待ち") : name
        }
    }

    private struct EventStageLiveSnapshot: Identifiable, Hashable {
        let stageKey: String
        let stageName: String
        let sortIndex: Int
        let firstStartTime: Date
        let currentAct: EventStageTimelineEntry?
        let nextAct: EventStageTimelineEntry?

        var id: String { stageKey }
    }

    private enum LiveStageProgressState {
        case active(Double)
        case upcoming
        case idle
    }

    private var trimmedDraft: String {
        draft.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canSend: Bool {
        (!trimmedDraft.isEmpty || !imageURLs.isEmpty) && !isSending && !isUploadingImage
    }

    private var liveDiscussionHeaderHeight: CGFloat {
         44
    }

    init(
        eventID: String,
        eventName: String,
        eventReadRepository: EventReadRepository,
        discussionRepository: EventLiveDiscussionRepository,
        discussionMediaRepository: EventDiscussionMediaRepository
    ) {
        self.eventID = eventID
        self.eventName = eventName
        self.eventReadRepository = eventReadRepository
        self.discussionRepository = discussionRepository
        self.discussionMediaRepository = discussionMediaRepository
    }

    var body: some View {
        VStack(spacing: 0) {
            sortBar

            Divider()

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 10) {
                        contentView
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                }
                .scrollDismissesKeyboard(.interactively)
                .refreshable {
                    await loadComments()
                }
                .onChange(of: comments.count) { _, _ in
                    guard sortMode == .oldest, let lastID = comments.last?.id else { return }
                    withAnimation(.easeOut(duration: 0.2)) {
                        proxy.scrollTo(lastID, anchor: .bottom)
                    }
                }
            }

            composer
        }
        .background(RaverTheme.background)
        .safeAreaInset(edge: .top, spacing: 0) {
            Color.clear
                .frame(height: liveDiscussionHeaderHeight)
        }
        .overlay(alignment: .top) {
            liveDiscussionHeaderBar
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .raverEnableCustomSwipeBack()
        .task {
            if phase == .idle {
                await loadComments()
            }
            if event == nil {
                await loadEvent()
            }
        }
        .onChange(of: sortMode) { _, _ in
            Task { await loadComments() }
        }
        .onChange(of: selectedImageItems) { _, newValue in
            guard !newValue.isEmpty else { return }
            Task { await uploadImages(from: newValue) }
        }
        .alert(LT("提示", "Notice", "お知らせ"), isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button(LT("知道了", "OK", "OK"), role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
        .overlay {
            if let event, showLiveStageOverlay {
                liveStageOverlay(for: event)
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 0.96, anchor: .center)),
                        removal: .opacity
                    ))
            }
        }
        .animation(.spring(response: 0.36, dampingFraction: 0.88), value: showLiveStageOverlay)
    }

    private var sortBar: some View {
        VStack(alignment: .center, spacing: 9) {
            if let event, !liveStageSnapshots(for: event).isEmpty {
                liveStageCollapsiblePanel(event)
            }

            Picker("", selection: $sortMode) {
                ForEach(EventLiveCommentSortMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 260)
        }
        .padding(.horizontal, 14)
        .padding(.top, 10)
        .padding(.bottom, 8)
        .background(RaverTheme.background)
        .animation(.interactiveSpring(response: 0.28, dampingFraction: 0.88), value: isLiveStagePanelCollapsed)
    }

    private func liveStageCollapsiblePanel(_ event: WebEvent) -> some View {
        VStack(spacing: 5) {
            if !isLiveStagePanelCollapsed {
                liveStageSummaryScroller(event)
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .top)),
                        removal: .opacity.combined(with: .move(edge: .top))
                    ))
            }

            liveStagePanelToggleHandle
        }
        .frame(maxWidth: .infinity)
    }

    private var liveStagePanelToggleHandle: some View {
        Button {
            withAnimation(.interactiveSpring(response: 0.28, dampingFraction: 0.88)) {
                isLiveStagePanelCollapsed.toggle()
            }
        } label: {
            Image(systemName: isLiveStagePanelCollapsed ? "chevron.compact.down" : "chevron.compact.up")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(RaverTheme.secondaryText.opacity(colorScheme == .dark ? 0.82 : 0.68))
                .frame(width: 58, height: 12)
                .contentShape(Rectangle())
                .background(
                    Capsule()
                        .fill(RaverTheme.card.opacity(colorScheme == .dark ? 0.52 : 0.70))
                )
                .overlay(
                    Capsule()
                        .stroke(RaverTheme.cardBorder.opacity(0.72), lineWidth: 0.6)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isLiveStagePanelCollapsed ? LT("展开正在表演", "Expand now playing", "現在出演中を展開") : LT("收起正在表演", "Collapse now playing", "現在出演中を閉じる"))
    }

    private var liveDiscussionHeaderBar: some View {
        let safeTop = topSafeAreaInset()

        return VStack(spacing: 0) {
            Rectangle()
                .fill(colorScheme == .dark ? Color.black : RaverTheme.background)
                .frame(height: safeTop)

            ZStack {
                HStack(spacing: 6) {
                    LiveActivityBarsView(color: Color(red: 0.18, green: 0.88, blue: 0.42))
                        .frame(width: 15, height: 14)
                    Text(eventName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(RaverTheme.primaryText)
                        .lineLimit(1)
                }
                .padding(.horizontal, 56)

                HStack {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(RaverTheme.primaryText)
                            .frame(width: 28, height: 28)
                    }
                    .buttonStyle(.plain)

                    Spacer()
                }
            }
            .frame(height: 44)
            .padding(.horizontal, 14)
            .background(colorScheme == .dark ? Color.black : RaverTheme.background)
            .overlay(alignment: .bottom) {
                Divider()
            }
        }
        .ignoresSafeArea(edges: .top)
    }

    @ViewBuilder
    private var contentView: some View {
        switch phase {
        case .idle, .initialLoading:
            CommentSectionSkeletonView(count: 5)
        case .failure(let message), .offline(let message):
            ScreenErrorCard(
                title: LT("讨论区加载失败", "Discussion Failed to Load", "ディスカッションの読み込みに失敗しました"),
                message: message
            ) {
                Task { await loadComments() }
            }
        case .empty:
            ContentUnavailableView(
                LT("还没有现场讨论", "No Live Discussion Yet", "ライブディスカッションはまだありません"),
                systemImage: "bubble.left.and.bubble.right",
                description: Text(LT("发一条评论，和现场的人一起聊。", "Post a comment and chat with people at the event.", "コメントを投稿して現地の人と話しましょう。"))
            )
            .padding(.top, 44)
        case .success:
            ForEach(displayComments) { comment in
                liveCommentRow(comment)
                    .id(comment.id)
            }
        }
    }

    private var displayComments: [EventLiveComment] {
        switch sortMode {
        case .oldest:
            return comments.sorted { $0.createdAt < $1.createdAt }
        case .newest:
            return comments.sorted { $0.createdAt > $1.createdAt }
        case .hot:
            return comments.sorted {
                if $0.likeCount == $1.likeCount { return $0.createdAt > $1.createdAt }
                return $0.likeCount > $1.likeCount
            }
        }
    }

    private func liveCommentRow(_ comment: EventLiveComment) -> some View {
        let isMine = comment.author.id == appState.session?.user.id
        return HStack(alignment: .top, spacing: 8) {
            if isMine { Spacer(minLength: 42) }

            if !isMine {
                avatar(comment.author, size: 32)
            }

            VStack(alignment: isMine ? .trailing : .leading, spacing: 4) {
                HStack(spacing: 6) {
                    if !isMine {
                        Text(comment.author.displayName)
                    }
                    Text(liveCommentTimeText(for: comment.createdAt))
                    if isMine {
                        Text(comment.author.displayName)
                    }
                }
                .font(.caption2)
                .foregroundStyle(RaverTheme.secondaryText)

                VStack(alignment: .leading, spacing: 7) {
                    if let reply = comment.replyToAuthor {
                        Text(LT("回复 \(reply.displayName)", "Reply to \(reply.displayName)", "\(reply.displayName) に返信"))
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(RaverTheme.secondaryText)
                    }

                    if !comment.content.isEmpty {
                        Text(comment.content)
                            .font(.subheadline)
                            .foregroundStyle(isMine ? Color.white : RaverTheme.primaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    ForEach(comment.imageURLs, id: \.self) { imageURL in
                        ImageLoaderView(urlString: AppConfig.resolvedURLString(imageURL) ?? imageURL)
                            .frame(width: 168, height: 168)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(isMine ? RaverTheme.accent : RaverTheme.card)
                )

                HStack(spacing: 14) {
                    Button {
                        replyTarget = comment
                    } label: {
                        Text(LT("回复", "Reply", "返信"))
                    }
                    .buttonStyle(.plain)

                    Button {
                        Task { await toggleLike(comment) }
                    } label: {
                        Label("\(comment.likeCount)", systemImage: comment.isLiked ? "heart.fill" : "heart")
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(comment.isLiked ? Color(red: 0.95, green: 0.30, blue: 0.38) : RaverTheme.secondaryText)
                }
                .font(.caption2.weight(.semibold))
                .foregroundStyle(RaverTheme.secondaryText)
            }
            .frame(maxWidth: 250, alignment: isMine ? .trailing : .leading)

            if isMine {
                avatar(comment.author, size: 32)
            } else {
                Spacer(minLength: 42)
            }
        }
    }

    private var composer: some View {
        VStack(spacing: 8) {
            if let replyTarget {
                HStack(spacing: 8) {
                    Text(LT("回复 \(replyTarget.author.displayName)", "Reply to \(replyTarget.author.displayName)", "\(replyTarget.author.displayName) に返信"))
                        .font(.caption)
                        .foregroundStyle(RaverTheme.secondaryText)
                        .lineLimit(1)
                    Spacer()
                    Button {
                        self.replyTarget = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(RaverTheme.secondaryText)
                }
            }

            if !imageURLs.isEmpty || isUploadingImage {
                HStack(spacing: 8) {
                    ForEach(imageURLs, id: \.self) { imageURL in
                        ZStack(alignment: .topTrailing) {
                            ImageLoaderView(urlString: AppConfig.resolvedURLString(imageURL) ?? imageURL)
                                .frame(width: 54, height: 54)
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            Button {
                                imageURLs.removeAll { $0 == imageURL }
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(Color.white, Color.black.opacity(0.65))
                            }
                            .buttonStyle(.plain)
                            .offset(x: 6, y: -6)
                        }
                    }

                    if isUploadingImage {
                        ProgressView()
                            .frame(width: 54, height: 54)
                    }
                    Spacer()
                }
            }

            HStack(spacing: 8) {
                PhotosPicker(selection: $selectedImageItems, maxSelectionCount: max(0, 3 - imageURLs.count), matching: .images) {
                    Image(systemName: "photo")
                        .font(.system(size: 18, weight: .semibold))
                        .frame(width: 36, height: 36)
                        .background(RaverTheme.card, in: Circle())
                }
                .buttonStyle(.plain)
                .disabled(isUploadingImage || imageURLs.count >= 3)

                TextField(LT("发送现场评论...", "Send a live comment...", "現地コメントを送信..."), text: $draft, axis: .vertical)
                    .lineLimit(1...4)
                    .submitLabel(.send)
                    .onSubmit {
                        Task { await sendComment() }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(RaverTheme.card)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                Button {
                    Task { await sendComment() }
                } label: {
                    if isSending {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Image(systemName: "paperplane.fill")
                            .font(.system(size: 16, weight: .semibold))
                    }
                }
                .frame(width: 38, height: 38)
                .background(canSend ? RaverTheme.accent : RaverTheme.cardBorder, in: Circle())
                .foregroundStyle(.white)
                .disabled(!canSend)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(RaverTheme.background)
        .overlay(Divider(), alignment: .top)
    }

    private func avatar(_ user: UserSummary, size: CGFloat) -> some View {
        Button {
            appPush(.userProfile(userID: user.id))
        } label: {
            avatarContent(user, size: size)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func avatarContent(_ user: UserSummary, size: CGFloat) -> some View {
        if let resolved = AppConfig.resolvedURLString(user.avatarURL),
           resolved.hasPrefix("http://") || resolved.hasPrefix("https://"),
           URL(string: resolved) != nil {
            ImageLoaderView(urlString: resolved, resizingMode: .fill)
                .background(avatarFallback(user, size: size))
                .frame(width: size, height: size)
                .clipShape(Circle())
        } else {
            avatarFallback(user, size: size)
        }
    }

    private func avatarFallback(_ user: UserSummary, size: CGFloat) -> some View {
        AvatarPlaceholderView(size: size)
    }

    private func liveCommentTimeText(for date: Date) -> String {
        let seconds = max(0, Date().timeIntervalSince(date))
        if seconds < 60 {
            return LT("刚刚", "Just now", "たった今")
        }

        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        formatter.locale = Locale(identifier: AppLanguagePreference.current.effectiveLanguage.localeIdentifier)
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    @MainActor
    private func loadEvent() async {
        do {
            event = try await eventReadRepository.fetchEvent(id: eventID)
        } catch {
            // Keep discussion usable even if event detail fails.
        }
    }

    @ViewBuilder
    private func liveStageSummaryScroller(_ event: WebEvent) -> some View {
        let snapshots = liveStageSnapshots(for: event)
        if !snapshots.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Text(LT("正在表演", "正在表演", "出演中"))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(RaverTheme.secondaryText)
                    Spacer(minLength: 0)
                    Button {
                        showLiveStageOverlay = true
                    } label: {
                        HStack(spacing: 4) {
                            Text(LT("全部舞台", "All stages", "すべてのステージ"))
                            Image(systemName: "chevron.right")
                        }
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(RaverTheme.accent)
                    }
                    .buttonStyle(.plain)
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(snapshots) { snapshot in
                            liveStageSummaryCard(snapshot)
                        }
                    }
                    .padding(.horizontal, 1)
                    .padding(.vertical, 1)
                }
            }
        }
    }

    private func liveStageSummaryCard(_ snapshot: EventStageLiveSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            liveStageProgressBar(snapshot)

            liveStageHeader(snapshot, titleFont: .caption.weight(.bold), titleColor: RaverTheme.accent)

            if let current = snapshot.currentAct {
                liveActIdentityArea(
                    current.act,
                    timeText: current.timeText,
                    avatarSize: 36,
                    font: .subheadline.weight(.semibold),
                    emphasizeAvatar: true
                )
            } else if let next = snapshot.nextAct {
                liveActIdentityArea(
                    next.act,
                    timeText: LT("下一场 \(next.timeText)", "Next \(next.timeText)", "次は \(next.timeText)"),
                    avatarSize: 36,
                    font: .subheadline.weight(.semibold)
                )
            } else {
                Text(LT("当前暂无演出", "当前暂无演出", "現在の出演はありません"))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(RaverTheme.primaryText)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(width: 246, alignment: .leading)
        .background(liveStageCardBackground(cornerRadius: 16, elevated: false))
    }

    private func liveStageProgressState(_ snapshot: EventStageLiveSnapshot) -> LiveStageProgressState {
        guard let current = snapshot.currentAct else {
            return snapshot.nextAct == nil ? .idle : .upcoming
        }
        let duration = current.endTime.timeIntervalSince(current.startTime)
        guard duration > 0 else { return .active(1) }
        let progress = Date().timeIntervalSince(current.startTime) / duration
        return .active(min(max(progress, 0), 1))
    }

    private func liveStageProgressBar(_ snapshot: EventStageLiveSnapshot) -> some View {
        let state = liveStageProgressState(snapshot)
        let progress: Double = {
            switch state {
            case .active(let value): return value
            case .upcoming: return 0.08
            case .idle: return 0
            }
        }()
        let opacity: Double = {
            switch state {
            case .active: return 1
            case .upcoming: return 0.36
            case .idle: return 0.18
            }
        }()

        return GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(RaverTheme.accent.opacity(colorScheme == .dark ? 0.12 : 0.08))
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [
                                RaverTheme.accent.opacity(min(opacity, 0.96)),
                                RaverTheme.accent.opacity(max(0.22, opacity * 0.34))
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: max(6, proxy.size.width * progress))
                if progress > 0 {
                    Circle()
                        .fill(RaverTheme.accent.opacity(max(opacity, 0.48)))
                        .frame(width: 6, height: 6)
                        .shadow(color: RaverTheme.accent.opacity(colorScheme == .dark ? 0.42 : 0.24), radius: 4, y: 0)
                        .offset(x: max(0, proxy.size.width * progress - 3))
                }
            }
        }
        .frame(height: 7)
        .accessibilityHidden(true)
    }

    private func livePill(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 9, weight: .bold))
            .foregroundStyle(liveStatusColor)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(
                Capsule()
                    .fill(liveStatusColor.opacity(colorScheme == .dark ? 0.18 : 0.10))
            )
            .overlay(
                Capsule()
                    .stroke(liveStatusColor.opacity(colorScheme == .dark ? 0.34 : 0.20), lineWidth: 0.8)
            )
    }

    private var liveStatusColor: Color {
        Color(red: 0.27, green: 0.92, blue: 0.50)
    }

    private var liveAvatarGlowColor: Color {
        Color(red: 0.66, green: 0.42, blue: 0.98)
    }

    private func liveStageHeader(_ snapshot: EventStageLiveSnapshot, titleFont: Font, titleColor: Color) -> some View {
        HStack(spacing: 8) {
            Text(snapshot.stageName)
                .font(titleFont)
                .foregroundStyle(titleColor)
                .lineLimit(1)
            Spacer(minLength: 0)
            if snapshot.currentAct != nil {
                livePill(LT("LIVE", "LIVE", "LIVE"))
            }
        }
    }

    private func liveStageCardBackground(cornerRadius: CGFloat, elevated: Bool) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(RaverTheme.card)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(RaverTheme.accent.opacity(colorScheme == .dark ? 0.07 : 0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(RaverTheme.cardBorder, lineWidth: 1)
            )
            .shadow(
                color: elevated ? Color.black.opacity(colorScheme == .dark ? 0.22 : 0.08) : .clear,
                radius: elevated ? 16 : 0,
                y: elevated ? 10 : 0
            )
    }

    private func stageSortIndex(_ stageName: String?, event: WebEvent) -> Int {
        let normalized = stageName?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
        guard let order = event.stageOrder, !normalized.isEmpty else { return Int.max }
        return order.firstIndex { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == normalized } ?? Int.max
    }

    private func liveStageSnapshots(for event: WebEvent) -> [EventStageLiveSnapshot] {
        let now = Date()
        let stageBuckets = Dictionary(grouping: event.lineupSlots.filter { $0.endTime > $0.startTime }) { slot in
            let trimmed = slot.stageName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return trimmed.isEmpty ? "__unknown_stage__" : trimmed.lowercased()
        }

        return stageBuckets.compactMap { stageKey, slots in
            let sortedSlots = slots.sorted { lhs, rhs in
                if lhs.startTime == rhs.startTime { return lhs.endTime < rhs.endTime }
                return lhs.startTime < rhs.startTime
            }
            guard let firstSlot = sortedSlots.first else { return nil }

            let displayStageName: String = {
                let raw = firstSlot.stageName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                return raw.isEmpty ? LT("未知舞台", "未知舞台", "不明なステージ") : raw
            }()

            let currentSlot = sortedSlots.first { $0.startTime <= now && now <= $0.endTime }
            let anchorTime = currentSlot?.endTime ?? now
            let currentDayIndex = EventLogicalDayResolver.dayIndex(
                for: anchorTime,
                eventStartDate: event.startDate,
                dayRolloverHour: event.dayRolloverHour
            )
            let nextSlot = sortedSlots.first { slot in
                guard slot.startTime > anchorTime else { return false }
                return EventLogicalDayResolver.dayIndex(
                    for: slot,
                    eventStartDate: event.startDate,
                    dayRolloverHour: event.dayRolloverHour
                ) == currentDayIndex
            }

            return EventStageLiveSnapshot(
                stageKey: stageKey,
                stageName: displayStageName,
                sortIndex: stageSortIndex(firstSlot.stageName, event: event),
                firstStartTime: firstSlot.startTime,
                currentAct: currentSlot.map { makeStageTimelineEntry(from: $0, event: event) },
                nextAct: nextSlot.map { makeStageTimelineEntry(from: $0, event: event) }
            )
        }
        .sorted { lhs, rhs in
            if lhs.sortIndex != rhs.sortIndex { return lhs.sortIndex < rhs.sortIndex }
            if lhs.firstStartTime != rhs.firstStartTime { return lhs.firstStartTime < rhs.firstStartTime }
            return lhs.stageName.localizedCaseInsensitiveCompare(rhs.stageName) == .orderedAscending
        }
    }

    private func makeStageTimelineEntry(from slot: WebEventLineupSlot, event: WebEvent) -> EventStageTimelineEntry {
        EventStageTimelineEntry(
            id: slot.id,
            act: EventLineupActCodec.parse(slot: slot),
            timeText: EventTimeZoneDisplay.slotTimeRange(slot, event: event),
            startTime: slot.startTime,
            endTime: slot.endTime
        )
    }

    @ViewBuilder
    private func liveActAvatarStack(_ act: EventLineupResolvedAct, primarySize: CGFloat, secondarySize: CGFloat) -> some View {
        if act.type == .solo {
            lineupPerformerAvatar(act.performers.first, size: primarySize)
        } else {
            HStack(spacing: -secondarySize * 0.22) {
                ForEach(Array(act.performers.prefix(3).enumerated()), id: \.offset) { _, performer in
                    lineupPerformerAvatar(performer, size: secondarySize)
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(0.72), lineWidth: 1.2)
                        )
                }
            }
            .frame(height: secondarySize)
        }
    }

    private func liveActIdentityArea(
        _ act: EventLineupResolvedAct,
        timeText: String,
        avatarSize: CGFloat,
        font: Font,
        emphasizeAvatar: Bool = false
    ) -> some View {
        VStack(alignment: .leading, spacing: act.isCollaborative ? 6 : 0) {
            ForEach(Array(act.performers.enumerated()), id: \.element.id) { _, performer in
                livePerformerIdentityRow(
                    performer,
                    timeText: timeText,
                    avatarSize: avatarSize,
                    font: font,
                    emphasizeAvatar: emphasizeAvatar
                )
            }
        }
    }

    @ViewBuilder
    private func livePerformerIdentityRow(
        _ performer: EventLineupPerformer,
        timeText: String,
        avatarSize: CGFloat,
        font: Font,
        emphasizeAvatar: Bool = false
    ) -> some View {
        let content = HStack(alignment: .center, spacing: 8) {
            lineupPerformerAvatar(performer, size: avatarSize, emphasize: emphasizeAvatar)
            VStack(alignment: .leading, spacing: 2) {
                Text(performer.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? LT("待公布 DJ", "待公布 DJ", "DJ発表待ち") : performer.name)
                    .font(font)
                    .foregroundStyle(RaverTheme.primaryText)
                    .lineLimit(1)
                Text(timeText)
                    .font(.caption2)
                    .foregroundStyle(RaverTheme.secondaryText)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())

        if let djID = performer.djID?.trimmingCharacters(in: .whitespacesAndNewlines), !djID.isEmpty {
            Button {
                appPush(.djDetail(djID: djID))
            } label: {
                content
            }
            .buttonStyle(.plain)
        } else {
            content
        }
    }

    @ViewBuilder
    private func lineupPerformerAvatar(_ performer: EventLineupPerformer?, size: CGFloat, emphasize: Bool = false) -> some View {
        let resolvedAvatar = AppConfig.resolvedDJAvatarURLString(performer?.avatarUrl, size: .small)
        if let resolvedAvatar, !resolvedAvatar.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            ImageLoaderView(urlString: resolvedAvatar, resizingMode: .fill)
                .background(djAvatarPlaceholder(size: size))
                .frame(width: size, height: size)
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(
                            RaverTheme.accent.opacity(
                                emphasize
                                ? (colorScheme == .dark ? 0.62 : 0.48)
                                : (colorScheme == .dark ? 0.26 : 0.20)
                            ),
                            lineWidth: emphasize ? 1.4 : 1
                        )
                )
                .overlay {
                    if emphasize {
                        liveAvatarGlowHalo(size: size)
                    }
                }
                .shadow(
                    color: emphasize
                    ? liveAvatarGlowColor.opacity(colorScheme == .dark ? 0.34 : 0.22)
                    : .clear,
                    radius: emphasize ? 8 : 0
                )
        } else {
            djAvatarPlaceholder(size: size, emphasize: emphasize)
        }
    }

    private func djAvatarPlaceholder(size: CGFloat, emphasize: Bool = false) -> some View {
        DefaultDJAvatarPlaceholderView(
            size: size,
            backgroundColor: RaverTheme.accent.opacity(colorScheme == .dark ? 0.22 : 0.12),
            imageScale: 0.9
        )
            .overlay(
                Circle()
                    .stroke(
                        RaverTheme.accent.opacity(
                            emphasize
                            ? (colorScheme == .dark ? 0.62 : 0.46)
                            : (colorScheme == .dark ? 0.28 : 0.22)
                        ),
                        lineWidth: emphasize ? 1.4 : 1
                    )
            )
            .overlay {
                if emphasize {
                    liveAvatarGlowHalo(size: size)
                }
            }
            .shadow(
                color: emphasize
                ? liveAvatarGlowColor.opacity(colorScheme == .dark ? 0.34 : 0.22)
                : .clear,
                radius: emphasize ? 8 : 0
            )
            .frame(width: size, height: size)
    }

    private func liveAvatarGlowHalo(size: CGFloat) -> some View {
        Circle()
            .stroke(liveAvatarGlowColor.opacity(colorScheme == .dark ? 0.22 : 0.16), lineWidth: 0.8)
            .padding(-2)
            .blur(radius: 1.6)
            .frame(width: size, height: size)
            .allowsHitTesting(false)
    }

    private func liveStageOverlay(for event: WebEvent) -> some View {
        let snapshots = liveStageSnapshots(for: event)
        return ZStack {
            Rectangle()
                .fill(colorScheme == .dark ? Color.black.opacity(0.46) : Color.black.opacity(0.18))
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.spring(response: 0.36, dampingFraction: 0.88)) {
                        showLiveStageOverlay = false
                    }
                }

            VStack(spacing: 0) {
                Spacer(minLength: 24)

                VStack(alignment: .leading, spacing: 18) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(LT("舞台实时演出", "舞台实时演出", "ステージライブ出演"))
                                .font(.title3.weight(.bold))
                                .foregroundStyle(RaverTheme.primaryText)
                            Text(event.name)
                                .font(.footnote)
                                .foregroundStyle(RaverTheme.secondaryText)
                                .lineLimit(2)
                        }

                        Spacer(minLength: 12)

                        Button {
                            withAnimation(.spring(response: 0.36, dampingFraction: 0.88)) {
                                showLiveStageOverlay = false
                            }
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(RaverTheme.secondaryText)
                                .frame(width: 30, height: 30)
                                .background(
                                    Circle()
                                        .fill(RaverTheme.cardBorder.opacity(colorScheme == .dark ? 0.7 : 0.55))
                                )
                        }
                        .buttonStyle(.plain)
                    }

                    if snapshots.isEmpty {
                        Text(LT("当前还没有可展示的舞台时间表。", "当前还没有可展示的舞台时间表。", "表示できるステージタイムテーブルはまだありません。"))
                            .font(.subheadline)
                            .foregroundStyle(RaverTheme.secondaryText)
                            .padding(.vertical, 18)
                    } else {
                        ScrollView(showsIndicators: false) {
                            VStack(spacing: 14) {
                                ForEach(snapshots) { snapshot in
                                    liveStageOverlayCard(snapshot)
                                }
                            }
                            .padding(.bottom, 6)
                        }
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 18)
                .padding(.bottom, 18)
                .frame(maxWidth: 520)
                .background(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .fill(RaverTheme.card)
                        .overlay(
                            RoundedRectangle(cornerRadius: 28, style: .continuous)
                                .stroke(RaverTheme.cardBorder, lineWidth: 1)
                        )
                )
                .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.42 : 0.14), radius: 24, y: 14)
                .padding(.horizontal, 20)
                .padding(.bottom, 30)

                Spacer(minLength: 24)
            }
        }
        .zIndex(40)
    }

    private func liveStageOverlayCard(_ snapshot: EventStageLiveSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            liveStageProgressBar(snapshot)

            liveStageHeader(snapshot, titleFont: .headline.weight(.bold), titleColor: RaverTheme.primaryText)

            if let current = snapshot.currentAct {
                liveStageOverlayTimelineRow(
                    title: LT("现在", "Now", "現在"),
                    titleColor: RaverTheme.accent,
                    entry: current,
                    emphasizeAvatar: true
                )
            } else {
                Text(LT("当前暂无正在演出的 DJ", "当前暂无正在演出的 DJ", "現在出演中のDJはいません"))
                    .font(.subheadline)
                    .foregroundStyle(RaverTheme.secondaryText)
            }

            if let next = snapshot.nextAct {
                liveStageOverlayTimelineRow(
                    title: LT("接下来", "Next", "次へ"),
                    titleColor: RaverTheme.secondaryText,
                    entry: next
                )
            }
        }
        .padding(16)
        .background(liveStageCardBackground(cornerRadius: 22, elevated: true))
    }

    private func liveStageOverlayTimelineRow(
        title: String,
        titleColor: Color,
        entry: EventStageTimelineEntry,
        emphasizeAvatar: Bool = false
    ) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(title)
                .font(.caption.weight(.bold))
                .foregroundStyle(titleColor)
                .frame(width: 42, alignment: .leading)
                .padding(.top, 10)

            VStack(alignment: .leading, spacing: 4) {
                liveActIdentityArea(
                    entry.act,
                    timeText: entry.timeText,
                    avatarSize: 42,
                    font: .subheadline.weight(.semibold),
                    emphasizeAvatar: emphasizeAvatar
                )
            }

            Spacer(minLength: 0)
        }
    }

    @MainActor
    private func loadComments() async {
        if comments.isEmpty {
            phase = .initialLoading
        }
        do {
            let page = try await discussionRepository.fetchEventLiveComments(eventID: eventID, cursor: nil, sort: sortMode)
            comments = page.comments
            phase = page.comments.isEmpty ? .empty : .success
        } catch {
            phase = .failure(message: error.userFacingMessage ?? LT("讨论区加载失败，请稍后重试", "Failed to load discussion. Please try again later.", "ディスカッションを読み込めませんでした。時間をおいて再試行してください。"))
        }
    }

    @MainActor
    private func sendComment() async {
        guard canSend else { return }
        isSending = true
        defer { isSending = false }

        do {
            let created = try await discussionRepository.addEventLiveComment(
                eventID: eventID,
                content: trimmedDraft,
                imageURLs: imageURLs,
                parentCommentID: replyTarget?.id
            )
            draft = ""
            imageURLs = []
            selectedImageItems = []
            replyTarget = nil
            mergeComment(created)
        } catch {
            errorMessage = error.userFacingMessage
        }
    }

    @MainActor
    private func toggleLike(_ comment: EventLiveComment) async {
        do {
            let updated = try await discussionRepository.toggleEventLiveCommentLike(commentID: comment.id, shouldLike: !comment.isLiked)
            mergeComment(updated)
        } catch {
            errorMessage = error.userFacingMessage
        }
    }

    @MainActor
    private func uploadImages(from items: [PhotosPickerItem]) async {
        guard !isUploadingImage else { return }
        isUploadingImage = true
        defer {
            isUploadingImage = false
            selectedImageItems = []
        }

        for item in items where imageURLs.count < 3 {
            do {
                guard let data = try await item.loadTransferable(type: Data.self) else { continue }
                let upload = try await discussionMediaRepository.uploadPostImage(
                    imageData: normalizedImageData(from: data),
                    fileName: "event-live-comment-\(UUID().uuidString).jpg",
                    mimeType: "image/jpeg"
                )
                imageURLs.append(upload.url)
            } catch {
            errorMessage = error.userFacingMessage ?? LT("图片上传失败", "Image upload failed.", "画像のアップロードに失敗しました。")
        }
    }
    }

    private func mergeComment(_ comment: EventLiveComment) {
        comments.removeAll { $0.id == comment.id }
        comments.append(comment)
        phase = .success
    }

    private func normalizedImageData(from rawData: Data) -> Data {
        if let image = UIImage(data: rawData),
           let jpeg = image.jpegData(compressionQuality: 0.9) {
            return jpeg
        }
        return rawData
    }
}

private struct EventSharePreviewCard: View {
    let payload: EventShareCardPayload

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            previewImage
                .frame(width: 72, height: 72)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 6) {
                if let badge = payload.badgeText?.nilIfBlank {
                    Text(badge)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(RaverTheme.accent)
                }

                Text(payload.eventName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(RaverTheme.primaryText)
                    .lineLimit(2)

                if let venue = payload.venueName?.nilIfBlank {
                    Text(venue)
                        .font(.caption)
                        .foregroundStyle(RaverTheme.secondaryText)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(12)
        .background(RaverTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    @ViewBuilder
    private var previewImage: some View {
        if let raw = payload.coverImageURL,
           let url = URL(string: raw),
           !raw.isEmpty {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().scaledToFill()
                default:
                    fallbackImage
                }
            }
        } else {
            fallbackImage
        }
    }

    private var fallbackImage: some View {
        LinearGradient(
            colors: [RaverTheme.accent.opacity(0.95), Color(red: 0.19, green: 0.18, blue: 0.26)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay(
            Image(systemName: "ticket.fill")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.92))
        )
    }
}

struct EventDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(\.discoverPush) private var discoverPush
    @Environment(\.appPush) private var appPush
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var appContainer: AppContainer

    private var eventReadRepository: EventReadRepository { appContainer.eventReadRepository }
    private var ratingRepository: RatingRepository { appContainer.ratingRepository }
    private var eventCheckinRepository: EventCheckinRepository { appContainer.eventCheckinRepository }
    private var eventRelatedContentRepository: EventRelatedContentRepository { appContainer.eventRelatedContentRepository }
    private var eventCommandRepository: EventCommandRepository { appContainer.eventCommandRepository }
    private var feedStreamRepository: FeedStreamRepository { appContainer.feedStreamRepository }
    private var postInteractionRepository: PostInteractionRepository { appContainer.postInteractionRepository }
    private var newsRepository: DiscoverNewsRepository { appContainer.discoverNewsRepository }
    private var shareMessageRepository: ShareMessageRepository { appContainer.shareMessageRepository }
    private var shareLinkCoordinator: ShareLinkCoordinator { ShareLinkCoordinator(repository: AppEnvironment.makeShareLinkRepository()) }

    let eventID: String

    private struct EventLineupDJEntry: Identifiable, Hashable {
        let id: String
        let act: EventLineupResolvedAct

        var name: String { act.displayName }
        var avatarUrl: String? { act.type == .solo ? act.performers.first?.avatarUrl : nil }
        var djID: String? { act.type == .solo ? act.performers.first?.djID : nil }
    }

    private enum LineupSortMode: String {
        case alphabetical
        case popularity

        var toggleTitle: String {
            switch self {
            case .alphabetical:
                return LT("按热度", "By popularity", "人気順")
            case .popularity:
                return LT("按字母", "A-Z", "アルファベット順")
            }
        }

        var activeTitle: String {
            switch self {
            case .alphabetical:
                return "A-Z"
            case .popularity:
                return LT("热度", "Hot", "人気")
            }
        }

        var iconName: String {
            switch self {
            case .alphabetical:
                return "chart.line.uptrend.xyaxis"
            case .popularity:
                return "arrow.up.arrow.down"
            }
        }
    }

    @State private var event: WebEvent?
    @State private var phase: LoadPhase = .idle
    @State private var isLoading = false
    @State private var isRefreshing = false
    @State private var showEventCheckinSheet = false
    @State private var selectedEventCheckinDayIDs: Set<String> = []
    @State private var selectedEventCheckinDJIDsByDayID: [String: Set<String>] = [:]
    @State private var relatedEventCheckins: [WebCheckin] = []
    @State private var bannerMessage: String?
    @State private var errorMessage: String?
    @State private var pendingUnboundDJName: String?
    @State private var pendingCollaborativeLineupEntry: EventLineupDJEntry?
    @State private var selectedTab: EventDetailTab = .info
    @State private var pageProgress: CGFloat = 0
    @State private var isTabSwitchingByTap = false
    @State private var tabSwitchUnlockWorkItem: DispatchWorkItem?
    @State private var tabFrames: [EventDetailTab: CGRect] = [:]
    @State private var pagerWidth: CGFloat = 1
    @State private var isPreparingEventCheckinSheet = false
    @State private var relatedRatingEvents: [WebRatingEvent] = []
    @State private var relatedEventSets: [WebDJSet] = []
    @State private var relatedArticles: [DiscoverNewsArticle] = []
    @State private var isLoadingRelatedArticles = false
    @State private var selectedRatingEventID: String?
    @State private var showExpandedLineupList = false
    @State private var lineupSortMode: LineupSortMode = .alphabetical
    @State private var expandedLineupPage = 0
    @State private var venueMapContext: EventVenueMapContext?
    @State private var selectedLineupMedia: FullscreenMediaSelection?
    @State private var isCachingManualSnapshot = false
    @State private var manualCachedAt: Date?
    @State private var bannerDismissToken = UUID()
    @State private var isInWidgetCountdownPool = false
    @State private var eventFavoriteID: String?
    @State private var isTogglingMarkedEvent = false
    @State private var shareMorePresentation: EventCardSharePresentation?
    @State private var isShareMorePanelVisible = false
    @State private var fullChatSharePresentation: EventCardSharePresentation?
    @State private var reportTarget: ReportSheetTarget?
    @State private var eventDiscussionPosts: [Post] = []
    @State private var eventDiscussionPhase: LoadPhase = .idle
    @State private var isLoadingEventDiscussion = false
    @State private var eventDiscussionNextCursor: String?

    fileprivate enum EventDetailTab: String, CaseIterable, Identifiable {
        case info
        case posts
        case news
        case lineup
        case schedule
        case ratings
        case sets

        var id: String { rawValue }

        var title: String {
            switch self {
            case .info: return LT("信息", "Info", "情報")
            case .posts: return LT("动态", "Posts", "投稿")
            case .news: return "News"
            case .lineup: return LT("阵容", "Lineup", "ラインナップ")
            case .schedule: return LT("时间表", "Timetable", "タイムテーブル")
            case .ratings: return LT("打分", "Ratings", "評価")
            case .sets: return "Sets"
            }
        }

        var themeColor: Color {
            switch self {
            case .info: return Color(red: 0.27, green: 0.85, blue: 0.82)
            case .posts: return Color(red: 0.95, green: 0.30, blue: 0.38)
            case .news: return Color(red: 0.97, green: 0.55, blue: 0.25)
            case .lineup: return Color(red: 0.30, green: 0.67, blue: 0.97)
            case .schedule: return Color(red: 0.56, green: 0.78, blue: 0.30)
            case .ratings: return Color(red: 0.98, green: 0.71, blue: 0.22)
            case .sets: return Color(red: 0.58, green: 0.43, blue: 0.95)
            }
        }
    }

    private struct EventLiveStageAct: Identifiable, Hashable {
        let id: String
        let stageName: String
        let actName: String
        let timeText: String
        let act: EventLineupResolvedAct
    }

    private struct EventStageTimelineEntry: Identifiable, Hashable {
        let id: String
        let act: EventLineupResolvedAct
        let timeText: String
        let startTime: Date
        let endTime: Date

        var actName: String {
            let name = act.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
            return name.isEmpty ? LT("待公布 DJ", "待公布 DJ", "DJ発表待ち") : name
        }
    }

    private struct EventStageLiveSnapshot: Identifiable, Hashable {
        let stageKey: String
        let stageName: String
        let sortIndex: Int
        let firstStartTime: Date
        let currentAct: EventStageTimelineEntry?
        let nextAct: EventStageTimelineEntry?

        var id: String { stageKey }
    }

    init(eventID: String, initialTabRawValue: String? = nil) {
        self.eventID = eventID
        let initialTab = initialTabRawValue.flatMap(EventDetailTab.init(rawValue:)) ?? .info
        _selectedTab = State(initialValue: initialTab)
    }

    private struct EventVenueMapContext: Identifiable {
        let id = UUID()
        let eventName: String
        let venueDisplayText: String
        let summaryLocation: String
        let coordinate: CLLocationCoordinate2D?
        let queryText: String
        let mapURL: URL?
    }

    private struct EventVenueMapSheet: View {
        @Environment(\.dismiss) private var dismiss
        @Environment(\.openURL) private var openURL

        let context: EventVenueMapContext

        @State private var mapPosition: MapCameraPosition
        @State private var currentRegion: MKCoordinateRegion
        @State private var resolvedCoordinate: CLLocationCoordinate2D?
        @State private var isGeocoding = false
        @State private var availableMapApps: [ExternalMapApp] = []
        @State private var showMapAppPicker = false

        private enum ExternalMapApp: String, CaseIterable, Identifiable {
            case apple = "Apple Maps"
            case amap = "Amap"
            case baidu = "Baidu Maps"
            case tencent = "Tencent Maps"

            var id: String { rawValue }
        }

        init(context: EventVenueMapContext) {
            self.context = context
            let fallbackCenter = CLLocationCoordinate2D(latitude: 31.2304, longitude: 121.4737)
            let center = context.coordinate ?? fallbackCenter
            let initialRegion = MKCoordinateRegion(
                center: center,
                span: MKCoordinateSpan(latitudeDelta: 0.012, longitudeDelta: 0.012)
            )
            _mapPosition = State(
                initialValue: .region(initialRegion)
            )
            _currentRegion = State(initialValue: initialRegion)
            _resolvedCoordinate = State(initialValue: context.coordinate)
        }

        var body: some View {
            NavigationStack {
                ZStack(alignment: .top) {
                    Map(position: $mapPosition, interactionModes: .all) {
                        if let markerCoordinate = resolvedCoordinate {
                            Marker(context.venueDisplayText, coordinate: markerCoordinate)
                                .tint(RaverTheme.accent)
                        }
                    }
                    .ignoresSafeArea(edges: .bottom)
                    .onMapCameraChange(frequency: .continuous) { camera in
                        currentRegion = camera.region
                    }

                    if isGeocoding {
                        HStack(spacing: 8) {
                            ProgressView()
                                .controlSize(.small)
                            Text(LT("正在定位场地...", "正在定位场地...", "会場を特定中..."))
                                .font(.caption)
                                .foregroundStyle(.white)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(Color.black.opacity(0.58))
                        )
                        .padding(.top, 12)
                    }

                    VStack(spacing: 10) {
                        mapZoomButton(systemName: "plus") {
                            adjustZoom(multiplier: 0.72)
                        }
                        mapZoomButton(systemName: "minus") {
                            adjustZoom(multiplier: 1.38)
                        }
                    }
                    .padding(.trailing, 14)
                    .padding(.top, 12)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                }
                .raverSystemNavigation(title: LT("活动场地", "Event Venue", "イベント会場"))
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 15, weight: .semibold))
                        }
                    }
                }
                .safeAreaInset(edge: .bottom) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(context.eventName)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(RaverTheme.primaryText)
                            .lineLimit(2)

                        Text(context.venueDisplayText)
                            .font(.subheadline)
                            .foregroundStyle(RaverTheme.primaryText)
                            .fixedSize(horizontal: false, vertical: true)

                        if !context.summaryLocation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Text(context.summaryLocation)
                                .font(.caption)
                                .foregroundStyle(RaverTheme.secondaryText)
                                .lineLimit(1)
                        }

                        if let coordinate = resolvedCoordinate {
                            Text(String(format: LT("纬度 %.6f，经度 %.6f", "Lat %.6f, Lng %.6f", "緯度 %.6f、経度 %.6f"), coordinate.latitude, coordinate.longitude))
                                .font(.caption2)
                                .foregroundStyle(RaverTheme.secondaryText)
                        }

                        HStack(spacing: 12) {
                            Button {
                                UIPasteboard.general.string = context.venueDisplayText
                            } label: {
                                Label(LT("复制地址", "复制地址", "住所をコピー"), systemImage: "doc.on.doc")
                                    .font(.caption.weight(.semibold))
                            }
                            .buttonStyle(.bordered)

                            Button {
                                refreshAvailableMapApps()
                                if !availableMapApps.isEmpty {
                                    showMapAppPicker = true
                                }
                            } label: {
                                Label(LT("打开地图App", "打开地图App", "地図アプリを開く"), systemImage: "arrow.up.right.square")
                                    .font(.caption.weight(.semibold))
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(RaverTheme.accent)
                            .disabled(availableMapApps.isEmpty)
                            .opacity(availableMapApps.isEmpty ? 0.65 : 1)
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.top, 12)
                    .padding(.bottom, 12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.ultraThinMaterial)
                    .overlay(alignment: .top) {
                        Divider().opacity(0.25)
                    }
                }
                .confirmationDialog(LT("选择地图应用", "Choose Map App", "地図アプリを選択"), isPresented: $showMapAppPicker, titleVisibility: .visible) {
                    ForEach(availableMapApps) { app in
                        Button(app.rawValue) {
                            openExternalMap(app)
                        }
                    }
                    Button(LT("取消", "Cancel", "キャンセル"), role: .cancel) {}
                }
                .task {
                    refreshAvailableMapApps()
                    await geocodeIfNeeded()
                }
            }
            .raverEnableCustomSwipeBack(edgeRatio: 0.2)
        }

        @MainActor
        private func geocodeIfNeeded() async {
            guard resolvedCoordinate == nil else { return }
            let query = context.queryText.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !query.isEmpty else { return }

            isGeocoding = true
            defer { isGeocoding = false }
            do {
                guard let placemark = try await geocodeAddress(query) else { return }
                guard let location = placemark.location else { return }
                let coordinate = location.coordinate
                resolvedCoordinate = coordinate
                let geocodedRegion = MKCoordinateRegion(
                    center: coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.012, longitudeDelta: 0.012)
                )
                currentRegion = geocodedRegion
                mapPosition = .region(geocodedRegion)
            } catch {
                // Keep interactive map usable even if geocoding fails.
            }
        }

        private func mapZoomButton(systemName: String, action: @escaping () -> Void) -> some View {
            Button(action: action) {
                Image(systemName: systemName)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(RaverTheme.primaryText)
                    .frame(width: 38, height: 38)
                    .background(
                        Circle()
                            .fill(.ultraThinMaterial)
                    )
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.18), lineWidth: 0.6)
                    )
            }
            .buttonStyle(.plain)
        }

        private func adjustZoom(multiplier: Double) {
            var next = currentRegion
            let minDelta = 0.0004
            let maxDelta = 170.0
            next.span.latitudeDelta = min(max(next.span.latitudeDelta * multiplier, minDelta), maxDelta)
            next.span.longitudeDelta = min(max(next.span.longitudeDelta * multiplier, minDelta), maxDelta)
            currentRegion = next
            mapPosition = .region(next)
        }

        private func geocodeAddress(_ address: String) async throws -> CLPlacemark? {
            try await withCheckedThrowingContinuation { continuation in
                CLGeocoder().geocodeAddressString(address, in: nil, preferredLocale: Locale(identifier: AppLanguagePreference.current.effectiveLanguage.localeIdentifier)) { placemarks, error in
                    if let error {
                        continuation.resume(throwing: error)
                        return
                    }
                    continuation.resume(returning: placemarks?.first)
                }
            }
        }

        private func refreshAvailableMapApps() {
            let app = UIApplication.shared
            var result: [ExternalMapApp] = []
            if context.mapURL != nil {
                result.append(.apple)
            }
            if app.canOpenURL(URL(string: "iosamap://")!) {
                result.append(.amap)
            }
            if app.canOpenURL(URL(string: "baidumap://")!) {
                result.append(.baidu)
            }
            if app.canOpenURL(URL(string: "qqmap://")!) {
                result.append(.tencent)
            }
            availableMapApps = result
        }

        private func openExternalMap(_ app: ExternalMapApp) {
            guard let url = externalMapURL(for: app) else { return }
            openURL(url)
        }

        private func externalMapURL(for app: ExternalMapApp) -> URL? {
            let coordinate = resolvedCoordinate ?? context.coordinate
            let name = context.venueDisplayText
            let query = context.queryText.trimmingCharacters(in: .whitespacesAndNewlines)

            switch app {
            case .apple:
                return context.mapURL
            case .amap:
                if let coordinate {
                    var components = URLComponents()
                    components.scheme = "iosamap"
                    components.host = "viewMap"
                    components.queryItems = [
                        URLQueryItem(name: "sourceApplication", value: "RaveHub"),
                        URLQueryItem(name: "poiname", value: name),
                        URLQueryItem(name: "lat", value: "\(coordinate.latitude)"),
                        URLQueryItem(name: "lon", value: "\(coordinate.longitude)"),
                        URLQueryItem(name: "dev", value: "0"),
                        URLQueryItem(name: "zoom", value: "17")
                    ]
                    return components.url
                }
                guard !query.isEmpty else { return nil }
                var components = URLComponents()
                components.scheme = "iosamap"
                components.host = "poi"
                components.queryItems = [
                    URLQueryItem(name: "sourceApplication", value: "RaveHub"),
                    URLQueryItem(name: "keywords", value: query)
                ]
                return components.url
            case .baidu:
                if let coordinate {
                    var components = URLComponents()
                    components.scheme = "baidumap"
                    components.host = "map"
                    components.path = "/marker"
                    components.queryItems = [
                        URLQueryItem(name: "location", value: "\(coordinate.latitude),\(coordinate.longitude)"),
                        URLQueryItem(name: "title", value: name),
                        URLQueryItem(name: "content", value: query.isEmpty ? name : query),
                        URLQueryItem(name: "src", value: "RaveHub")
                    ]
                    return components.url
                }
                guard !query.isEmpty else { return nil }
                var components = URLComponents()
                components.scheme = "baidumap"
                components.host = "map"
                components.path = "/search"
                components.queryItems = [
                    URLQueryItem(name: "query", value: query),
                    URLQueryItem(name: "src", value: "RaveHub")
                ]
                return components.url
            case .tencent:
                var components = URLComponents()
                components.scheme = "qqmap"
                components.host = "map"
                components.path = "/search"
                var items: [URLQueryItem] = [
                    URLQueryItem(name: "referer", value: "RaveHub")
                ]
                if !query.isEmpty {
                    items.append(URLQueryItem(name: "keyword", value: query))
                } else {
                    items.append(URLQueryItem(name: "keyword", value: name))
                }
                if let coordinate {
                    items.append(URLQueryItem(name: "center", value: "\(coordinate.latitude),\(coordinate.longitude)"))
                }
                components.queryItems = items
                return components.url
            }
        }
    }

    private struct EventVenueInlineMapPreview: View {
        let initialCoordinate: CLLocationCoordinate2D?
        let queryText: String
        let venueDisplayText: String

        @State private var resolvedCoordinate: CLLocationCoordinate2D?
        @State private var isResolving = false

        init(initialCoordinate: CLLocationCoordinate2D?, queryText: String, venueDisplayText: String) {
            self.initialCoordinate = initialCoordinate
            self.queryText = queryText
            self.venueDisplayText = venueDisplayText
            _resolvedCoordinate = State(initialValue: initialCoordinate)
        }

        var body: some View {
            Group {
                if let coordinate = resolvedCoordinate {
                    let camera = MapCameraPosition.region(
                        MKCoordinateRegion(
                            center: coordinate,
                            span: MKCoordinateSpan(latitudeDelta: 0.008, longitudeDelta: 0.008)
                        )
                    )
                    Map(initialPosition: camera, interactionModes: []) {
                        Marker(venueDisplayText, coordinate: coordinate)
                            .tint(RaverTheme.accent)
                    }
                    .allowsHitTesting(false)
                } else {
                    ZStack {
                        LinearGradient(
                            colors: [
                                Color(red: 0.10, green: 0.12, blue: 0.18),
                                Color(red: 0.08, green: 0.10, blue: 0.15)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        if isResolving {
                            VStack(spacing: 8) {
                                ProgressView()
                                    .controlSize(.small)
                                    .tint(.white)
                                Text(LT("加载地图中...", "Loading map...", "地図を読み込み中..."))
                                    .font(.caption2)
                                    .foregroundStyle(Color.white.opacity(0.82))
                            }
                        } else {
                            Image(systemName: "map")
                                .font(.system(size: 30, weight: .semibold))
                                .foregroundStyle(Color.white.opacity(0.42))
                        }
                    }
                }
            }
            .task {
                await geocodeIfNeeded()
            }
        }

        @MainActor
        private func geocodeIfNeeded() async {
            guard resolvedCoordinate == nil else { return }
            let query = queryText.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !query.isEmpty else { return }

            isResolving = true
            defer { isResolving = false }
            do {
                guard let placemark = try await geocodeAddress(query) else { return }
                guard let location = placemark.location else { return }
                resolvedCoordinate = location.coordinate
            } catch {
                // Keep placeholder visible if geocode fails.
            }
        }

        private func geocodeAddress(_ address: String) async throws -> CLPlacemark? {
            try await withCheckedThrowingContinuation { continuation in
                CLGeocoder().geocodeAddressString(address, in: nil, preferredLocale: Locale(identifier: AppLanguagePreference.current.effectiveLanguage.localeIdentifier)) { placemarks, error in
                    if let error {
                        continuation.resume(throwing: error)
                        return
                    }
                    continuation.resume(returning: placemarks?.first)
                }
            }
        }
    }

    var body: some View {
        Group {
            switch phase {
            case .idle, .initialLoading:
                EventDetailSkeletonView()
            case .failure(let message), .offline(let message):
                ScrollView {
                    ScreenErrorCard(message: message) {
                        Task { await load() }
                    }
                }
                .padding(16)
                .padding(.top, 96)
            case .empty:
                ContentUnavailableView(LT("活动不存在", "活动不存在", "イベントが存在しません"), systemImage: "calendar.badge.exclamationmark")
            case .success:
                if let event {
                    ZStack(alignment: .top) {
                        GeometryReader { proxy in
                            let cardWidth = max(proxy.size.width - 32, 0)
                            RaverImmersiveDetailPagerChrome(
                                title: event.name,
                                tabs: EventDetailTab.allCases,
                                selectedTab: selectedTab,
                                pageProgress: $pageProgress,
                                namespace: "event-detail",
                                configuration: detailChromeConfiguration
                            ) {
                                heroSection(event)
                            } tabBar: {
                                tabBar
                            } content: { chrome in
                                tabPager(event: event, cardWidth: cardWidth, chrome: chrome)
                            }
                        }

                        if isRefreshing || bannerMessage != nil {
                            VStack(alignment: .leading, spacing: 10) {
                                if isRefreshing {
                                    InlineLoadingBadge(title: LT("正在更新活动详情", "Updating event details", "イベント詳細を更新中"))
                                }
                                if let bannerMessage {
                                    ScreenStatusBanner(
                                        message: bannerMessage,
                                        style: .error,
                                        actionTitle: LT("重试", "Retry", "再試行")
                                    ) {
                                        Task { await load() }
                                    }
                                    .transition(.opacity)
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 100)
                            .animation(.easeOut(duration: 0.25), value: bannerMessage != nil)
                        }
                    }
                    .ignoresSafeArea(edges: .top)
                    .sheet(isPresented: $showEventCheckinSheet) {
                        EventCheckinSelectionSheet(
                            eventName: event.name,
                            options: eventCheckinDayOptions(for: event),
                            djOptionsByDayID: Dictionary(
                                uniqueKeysWithValues: eventCheckinDayOptions(for: event).map { day in
                                    (day.id, eventCheckinDJOptions(for: event, selectedDayIDs: [day.id]))
                                }
                            ),
                            initialSelectedDayIDs: selectedEventCheckinDayIDs,
                            initialSelectedDJIDsByDayID: selectedEventCheckinDJIDsByDayID,
                            confirmButtonTitle: activeAttendanceCheckin == nil ? LT("确认打卡", "Confirm Check-in", "チェックインを確認") : LT("保存修改", "Save Changes", "変更を保存"),
                            destructiveButtonTitle: activeAttendanceCheckin == nil ? nil : LT("取消打卡", "Cancel Check-in", "チェックインを取消"),
                            onDelete: activeAttendanceCheckin == nil ? nil : {
                                try await cancelEventCheckin()
                            }
                        ) { selectionsByDayID in
                            selectedEventCheckinDayIDs = Set(selectionsByDayID.keys)
                            selectedEventCheckinDJIDsByDayID = selectionsByDayID
                            try await submitEventCheckinSelections(selectedDJIDsByDayID: selectionsByDayID)
                        }
                        .presentationDetents([.fraction(0.78), .large])
                    }
                    .sheet(item: $venueMapContext) { context in
                        EventVenueMapSheet(context: context)
                    }
                } else {
                    ContentUnavailableView(LT("活动不存在", "活动不存在", "イベントが存在しません"), systemImage: "calendar.badge.exclamationmark")
                }
            }
        }
        .ignoresSafeArea(edges: .top)
        .background(RaverTheme.background)
        .raverImmersiveFloatingNavigationChrome(
            trailing: immersiveTrailingAction
        ) {
            dismiss()
        }
        .operationBannerHost()
        .navigationDestination(
            isPresented: Binding(
                get: { selectedRatingEventID != nil },
                set: { if !$0 { selectedRatingEventID = nil } }
            )
        ) {
            if let ratingEventID = selectedRatingEventID {
                CircleRatingEventDetailView(
                    eventID: ratingEventID,
                    onClose: {
                        selectedRatingEventID = nil
                    },
                    onUpdated: {
                        Task { await reloadEventRatings() }
                    }
                )
            }
        }
        .sheet(item: $fullChatSharePresentation) { presentation in
            ChatShareSheet(
                loadConversations: {
                    try await loadSharePanelConversations()
                },
                onShareToConversation: { conversation in
                    try await sendSharePayload(
                        presentation.payload,
                        to: conversation,
                        note: nil
                    )
                }
            ) { conversation in
                showWidgetStatusBanner(
                    message: LT("已分享到 \(conversation.title)", "Shared to \(conversation.title)", "\(conversation.title) に共有しました"),
                    conversation: conversation
                )
            } preview: {
                EventSharePreviewCard(payload: presentation.payload)
            }
            .presentationDetents([.fraction(0.76), .large])
        }
        .sheet(item: $reportTarget) { target in
            ReportSheet(target: target) { _, _ in
                showWidgetStatusBanner(message: LT("举报已提交", "Report submitted", "報告を送信しました"))
            }
            .environmentObject(appState)
            .presentationDetents([.large])
        }
        .task {
            await refreshManualCacheState()
            await refreshWidgetCountdownState()
            if event == nil {
                await load()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .discoverEventDidSave)) { notification in
            let savedEventID = notification.object as? String
            guard savedEventID == nil || savedEventID == eventID else { return }
            Task { await load() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .circlePostDidCreate)) { notification in
            guard let created = notification.object as? Post,
                  created.boundEventIDs.contains(eventID) || created.eventID == eventID else { return }
            mergeEventDiscussionPost(created)
        }
        .alert(LT("提示", "Notice", "お知らせ"), isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button(LT("确定", "OK", "OK"), role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
        .confirmationDialog(
            pendingCollaborativeLineupEntry?.name ?? LT("选择 DJ", "Choose DJ", "DJを選択"),
            isPresented: Binding(
                get: { pendingCollaborativeLineupEntry != nil },
                set: { if !$0 { pendingCollaborativeLineupEntry = nil } }
            ),
            titleVisibility: .visible
        ) {
            if let entry = pendingCollaborativeLineupEntry {
                ForEach(entry.act.performers.prefix(entry.act.type.performerCount)) { performer in
                    Button(performer.name.trimmingCharacters(in: .whitespacesAndNewlines).nilIfBlank ?? LT("待补充 DJ", "DJ info needed", "DJ情報未入力")) {
                        selectLineupPerformer(performer)
                    }
                }
            }
            Button(LT("取消", "Cancel", "キャンセル"), role: .cancel) {
                pendingCollaborativeLineupEntry = nil
            }
        } message: {
            Text(LT("选择要查看的 DJ 主页。", "Choose which DJ profile to open.", "表示するDJプロフィールを選択してください。"))
        }
        .alert(LT("DJ 信息待补充", "DJ Info Needed", "DJ情報が不足しています"), isPresented: Binding(
            get: { pendingUnboundDJName != nil },
            set: { if !$0 { pendingUnboundDJName = nil } }
        )) {
            Button(LT("关闭", "Close", "閉じる"), role: .cancel) {
                pendingUnboundDJName = nil
            }
            Button(LT("去补充", "Add Info", "情報を追加")) {
                let name = pendingUnboundDJName
                pendingUnboundDJName = nil
                appPush(.discover(.djImport(initialName: name)))
            }
        } message: {
            Text(LT("这个 DJ 暂未建立唯一档案，补充资料后就可以跳转到详情页。", "This DJ does not have a unique profile yet. Add the info to enable detail navigation.", "このDJにはまだ固有プロフィールがありません。情報を追加すると詳細ページへ移動できます。"))
        }
        .overlay {
            if let presentation = shareMorePresentation {
                    SharePanelOverlay(
                        isVisible: isShareMorePanelVisible,
                        onBackdropTap: { dismissShareMorePanel() }
                    ) {
                        ShareActionPanel(
                            primaryActions: sharePrimaryActions(),
                            quickActions: shareMoreQuickActions(for: event),
                            loadConversations: {
                                try await loadSharePanelConversations()
                            },
                            onSendToConversation: { conversation, note in
                                try await sendSharePayload(
                                    presentation.payload,
                                    to: conversation,
                                    note: note
                                )
                            },
                            onDismiss: {
                                dismissShareMorePanel()
                            }
                        ) { conversation in
                            showWidgetStatusBanner(
                                message: LT("已分享到 \(conversation.title)", "Shared to \(conversation.title)", "\(conversation.title) に共有しました"),
                                conversation: conversation
                            )
                        } onMoreChats: {
                            dismissShareMorePanel {
                                fullChatSharePresentation = presentation
                            }
                        }
                    }
                    .onAppear {
                        withAnimation(.sharePanelPresentSpring) {
                            isShareMorePanelVisible = true
                        }
                    }
            }
        }
        .animation(.sharePanelPresentSpring, value: isShareMorePanelVisible)
    }

    private func isMine(_ event: WebEvent) -> Bool {
        event.organizer?.id == appState.session?.user.id
    }

    @ViewBuilder
    private var tabBar: some View {
        RaverScrollableTabBar(
            items: eventDetailTabItems,
            selection: $selectedTab,
            progress: pageProgress,
            onSelect: { tab in
                withAnimation(.snappy(duration: 0.28, extraBounce: 0.06)) {
                    selectedTab = tab
                }
            },
            tabSpacing: 24,
            tabHorizontalPadding: 16,
            dividerColor: .gray.opacity(0.26),
            indicatorColorProvider: { $0.themeColor },
            activeTextColor: RaverTheme.primaryText,
            inactiveTextColor: RaverTheme.secondaryText,
            showsDivider: false,
            indicatorHeight: 2.6,
            tabFont: .system(size: 17, weight: .regular)
        )
        .frame(maxWidth: .infinity)
        .frame(height: 40)
        .padding(.top, 8)
        .padding(.bottom, 4)
        .background(RaverTheme.background)
    }

    private var eventDetailTabItems: [RaverScrollableTabItem<EventDetailTab>] {
        EventDetailTab.allCases.map { tab in
            RaverScrollableTabItem(id: tab, title: tab.title)
        }
    }

    @ViewBuilder
    private func tabPager(
        event: WebEvent,
        cardWidth: CGFloat,
        chrome: RaverImmersiveDetailPagerContext<EventDetailTab>
    ) -> some View {
        RaverScrollableTabPager(
            items: eventDetailTabItems,
            selection: $selectedTab,
            tabSpacing: 24,
            tabHorizontalPadding: 16,
            dividerColor: .gray.opacity(0.26),
            indicatorColorProvider: { $0.themeColor },
            showsTabBar: false,
            showsDivider: false,
            indicatorHeight: 2.6,
            tabFont: .system(size: 17, weight: .regular),
            progress: $pageProgress
        ) { tab in
            eventTabPage(event, cardWidth: cardWidth, tab: tab, chrome: chrome)
                .background(RaverTheme.background)
        }
    }

    @ViewBuilder
    private func eventTabPage(
        _ event: WebEvent,
        cardWidth: CGFloat,
        tab: EventDetailTab,
        chrome: RaverImmersiveDetailPagerContext<EventDetailTab>
    ) -> some View {
        ScrollView {
            VStack(spacing: 0) {
                RaverImmersiveDetailOffsetMarker(
                    tabID: tab,
                    coordinateSpaceName: chrome.coordinateSpaceName(tab)
                )
                Color.clear
                    .frame(height: chrome.detailTopInset)

                VStack(alignment: .leading, spacing: 14) {
                    eventTabContent(event, cardWidth: cardWidth, tab: tab)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 20)
            }
        }
        .coordinateSpace(name: chrome.coordinateSpaceName(tab))
        .scrollBounceBehavior(.always)
        .contentShape(Rectangle())
    }

    private var detailChromeConfiguration: RaverImmersiveDetailPagerConfiguration {
        RaverImmersiveDetailPagerConfiguration(
            heroHeight: 360,
            tabBarOverlayHeight: 52,
            pinnedTopBarHeight: 44,
            titleRevealLead: 8,
            titleRevealDistance: 20,
            backgroundColor: RaverTheme.background
        )
    }

    @ViewBuilder
    private func eventTabContent(_ event: WebEvent, cardWidth: CGFloat, tab: EventDetailTab) -> some View {
        switch tab {
        case .info:
            eventInfoTabContent(event, cardWidth: cardWidth)
        case .posts:
            eventPostsTabContent(event)
        case .news:
            eventNewsTabContent
        case .lineup:
            eventLineupTabContent(event, cardWidth: cardWidth)
        case .schedule:
            eventScheduleTabContent(event)
        case .ratings:
            eventRatingsTabContent()
        case .sets:
            eventSetsTabContent()
        }
    }

    @ViewBuilder
    private func eventPostsTabContent(_ event: WebEvent) -> some View {
        eventDiscussionComposerCard(event)

        switch eventDiscussionPhase {
        case .idle, .initialLoading:
            FeedSkeletonView()
                .task { await loadEventDiscussionPosts(force: false) }
        case .failure(let message), .offline(let message):
            ScreenErrorCard(
                title: LT("讨论区加载失败", "Discussion Failed to Load", "ディスカッションの読み込みに失敗しました"),
                message: message
            ) {
                Task { await loadEventDiscussionPosts(force: true) }
            }
        case .empty:
            ContentUnavailableView(
                LT("还没有讨论", "No Discussion Yet", "ディスカッションはまだありません"),
                systemImage: "bubble.left.and.bubble.right",
                description: Text(LT("发布带活动标签的动态，会自动出现在这里。", "发布带活动标签的动态，会自动出现在这里。", "イベントタグ付きの投稿はここに自動表示されます。"))
            )
            .padding(.vertical, 10)
        case .success:
            ForEach(Array(eventDiscussionPosts.enumerated()), id: \.element.id) { index, post in
                PostCardView(
                    post: post,
                    currentUserId: appState.session?.user.id,
                    showsFollowButton: false,
                    showsMoreButton: false,
                    onLikeTap: {
                        Task { await toggleEventDiscussionLike(post: post) }
                    },
                    onRepostTap: {
                        Task { await toggleEventDiscussionRepost(post: post) }
                    },
                    onSaveTap: {
                        Task { await toggleEventDiscussionSave(post: post) }
                    },
                    onHideTap: nil,
                    onFollowTap: nil,
                    onMessageTap: nil,
                    onAuthorTap: {
                        appPush(.userProfile(userID: post.author.id))
                    },
                    onSquadTap: nil,
                    onEditTap: nil
                )
                .foregroundStyle(RaverTheme.primaryText)
                .contentShape(Rectangle())
                .onTapGesture {
                    appPush(.postDetail(postID: post.id))
                }
                .onAppear {
                    if index == eventDiscussionPosts.count - 1 {
                        Task { await loadMoreEventDiscussionPostsIfNeeded() }
                    }
                }
            }

            if isLoadingEventDiscussion {
                HStack {
                    Spacer()
                    ProgressView(LT("加载更多...", "Loading more...", "さらに読み込み中..."))
                    Spacer()
                }
                .padding(.vertical, 8)
            }
        }
    }

    @ViewBuilder
    private var eventNewsTabContent: some View {
        if isLoadingRelatedArticles && relatedArticles.isEmpty {
            ProgressView(LT("正在加载相关资讯...", "正在加载相关资讯...", "関連ニュースを読み込み中..."))
                .padding(.vertical, 8)
        } else if relatedArticles.isEmpty {
            Text(LT("暂无相关资讯", "暂无相关资讯", "関連ニュースはありません"))
                .font(.subheadline)
                .foregroundStyle(RaverTheme.secondaryText)
                .padding(.vertical, 8)
        } else {
            ForEach(Array(relatedArticles.enumerated()), id: \.element.id) { index, article in
                Button {
                    discoverPush(.newsDetail(articleID: article.id))
                } label: {
                    DiscoverNewsRow(article: article, showsSummary: false)
                }
                .buttonStyle(.plain)
                .contentShape(Rectangle())

                if index < relatedArticles.count - 1 {
                    Divider()
                        .padding(.leading, 16)
                }
            }
        }
    }

    private func eventDiscussionComposerCard(_ event: WebEvent) -> some View {
        Button {
            appPush(.circle(.eventPostCreate(eventID: event.id, eventName: event.name)))
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "square.and.pencil")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(RaverTheme.accent)
                    .frame(width: 34, height: 34)
                    .background(RaverTheme.accent.opacity(0.14), in: Circle())

                VStack(alignment: .leading, spacing: 3) {
                    Text(LT("发布活动讨论", "Post to Event Discussion", "イベントディスカッションに投稿"))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(RaverTheme.primaryText)
                    Text(LT("自动带上 \(event.name) 标签", "Tagged with \(event.name) automatically", "\(event.name) タグが自動で付きます"))
                        .font(.caption)
                        .foregroundStyle(RaverTheme.secondaryText)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(RaverTheme.secondaryText)
            }
            .padding(12)
            .background(RaverTheme.card)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func eventLiveHeroEntry(_ event: WebEvent) -> some View {
        Button {
            appPush(.eventLiveDiscussion(eventID: event.id, eventName: event.name))
        } label: {
            HStack(spacing: 6) {
                LiveActivityBarsView(color: Color(red: 0.18, green: 0.88, blue: 0.42))
                    .frame(width: 15, height: 14)

                Text(LT("现场讨论区", "现场讨论区", "ライブディスカッション"))
                    .font(.caption.weight(.bold))

                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.bold))
                    .accessibilityLabel(LT("进入现场讨论区", "进入现场讨论区", "ライブディスカッションへ"))
            }
            .foregroundStyle(Color.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                Capsule()
                    .fill(Color(red: 0.05, green: 0.42, blue: 0.20).opacity(0.82))
            )
            .overlay(
                Capsule()
                    .stroke(Color(red: 0.32, green: 1.0, blue: 0.55).opacity(0.58), lineWidth: 0.8)
            )
        }
        .buttonStyle(.plain)
    }

    private func liveStageList(for event: WebEvent) -> some View {
        let acts = currentLiveStageActs(for: event)
        return GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "dot.radiowaves.left.and.right")
                        .foregroundStyle(RaverTheme.accent)
                    Text(LT("正在表演", "正在表演", "出演中"))
                        .font(.headline)
                    Spacer()
                    Text(LT("\(acts.count) 个舞台", "\(acts.count) stages", "\(acts.count) ステージ"))
                        .font(.caption)
                        .foregroundStyle(RaverTheme.secondaryText)
                }

                if acts.isEmpty {
                    Text(LT("当前没有匹配到正在演出的时间表。", "当前没有匹配到正在演出的时间表。", "現在出演中のタイムテーブルは見つかりません。"))
                        .font(.subheadline)
                        .foregroundStyle(RaverTheme.secondaryText)
                } else {
                    ForEach(acts) { act in
                        HStack(alignment: .top, spacing: 10) {
                            Text(act.stageName)
                                .font(.caption.weight(.bold))
                                .foregroundStyle(RaverTheme.accent)
                                .frame(width: 82, alignment: .leading)
                            VStack(alignment: .leading, spacing: 3) {
                                HStack(spacing: 8) {
                                    liveActAvatarStack(act.act, primarySize: 28, secondarySize: 18)
                                    Text(act.actName)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(RaverTheme.primaryText)
                                }
                                Text(act.timeText)
                                    .font(.caption)
                                    .foregroundStyle(RaverTheme.secondaryText)
                            }
                            Spacer(minLength: 0)
                        }
                    }
                }
            }
        }
    }

    private func isEventLiveDiscussionActive(_ event: WebEvent) -> Bool {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: event.startDate)
        guard let end = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: event.endDate) else {
            return false
        }
        let now = Date()
        return now >= start && now <= end
    }

    private func currentLiveStageActs(for event: WebEvent) -> [EventLiveStageAct] {
        liveStageSnapshots(for: event).compactMap { snapshot in
            guard let current = snapshot.currentAct else { return nil }
            return EventLiveStageAct(
                id: current.id,
                stageName: snapshot.stageName,
                actName: current.actName,
                timeText: current.timeText,
                act: current.act
            )
        }
    }

    private func stageSortIndex(_ stageName: String?, event: WebEvent) -> Int {
        let normalized = stageName?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
        guard let order = event.stageOrder, !normalized.isEmpty else { return Int.max }
        return order.firstIndex { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == normalized } ?? Int.max
    }

    private func liveStageSnapshots(for event: WebEvent) -> [EventStageLiveSnapshot] {
        let now = Date()
        let stageBuckets = Dictionary(grouping: event.lineupSlots.filter { $0.endTime > $0.startTime }) { slot in
            let trimmed = slot.stageName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return trimmed.isEmpty ? "__unknown_stage__" : trimmed.lowercased()
        }

        return stageBuckets.compactMap { stageKey, slots in
            let sortedSlots = slots.sorted { lhs, rhs in
                if lhs.startTime == rhs.startTime { return lhs.endTime < rhs.endTime }
                return lhs.startTime < rhs.startTime
            }
            guard let firstSlot = sortedSlots.first else { return nil }

            let displayStageName: String = {
                let raw = firstSlot.stageName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                return raw.isEmpty ? LT("未知舞台", "未知舞台", "不明なステージ") : raw
            }()

            let currentSlot = sortedSlots.first { $0.startTime <= now && now <= $0.endTime }
            let anchorTime = currentSlot?.endTime ?? now
            let nextSlot = sortedSlots.first { $0.startTime > anchorTime }

            return EventStageLiveSnapshot(
                stageKey: stageKey,
                stageName: displayStageName,
                sortIndex: stageSortIndex(firstSlot.stageName, event: event),
                firstStartTime: firstSlot.startTime,
                currentAct: currentSlot.map { makeStageTimelineEntry(from: $0, event: event) },
                nextAct: nextSlot.map { makeStageTimelineEntry(from: $0, event: event) }
            )
        }
        .sorted { lhs, rhs in
            if lhs.sortIndex != rhs.sortIndex { return lhs.sortIndex < rhs.sortIndex }
            if lhs.firstStartTime != rhs.firstStartTime { return lhs.firstStartTime < rhs.firstStartTime }
            return lhs.stageName.localizedCaseInsensitiveCompare(rhs.stageName) == .orderedAscending
        }
    }

    private func makeStageTimelineEntry(from slot: WebEventLineupSlot, event: WebEvent) -> EventStageTimelineEntry {
        EventStageTimelineEntry(
            id: slot.id,
            act: EventLineupActCodec.parse(slot: slot),
            timeText: EventTimeZoneDisplay.slotTimeRange(slot, event: event),
            startTime: slot.startTime,
            endTime: slot.endTime
        )
    }

    @ViewBuilder
    private func liveActAvatarStack(_ act: EventLineupResolvedAct, primarySize: CGFloat, secondarySize: CGFloat) -> some View {
        if act.type == .solo {
            lineupPerformerAvatar(act.performers.first, size: primarySize)
        } else {
            HStack(spacing: -secondarySize * 0.22) {
                ForEach(Array(act.performers.prefix(3).enumerated()), id: \.offset) { _, performer in
                    lineupPerformerAvatar(performer, size: secondarySize)
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(0.72), lineWidth: 1.2)
                        )
                }
            }
            .frame(height: secondarySize)
        }
    }

    @MainActor
    private func loadEventDiscussionPosts(force: Bool) async {
        guard !isLoadingEventDiscussion else { return }
        if !force, eventDiscussionPhase == .success || eventDiscussionPhase == .empty {
            return
        }

        isLoadingEventDiscussion = true
        if eventDiscussionPosts.isEmpty {
            eventDiscussionPhase = .initialLoading
        }
        defer { isLoadingEventDiscussion = false }

        do {
            let page = try await feedStreamRepository.fetchFeed(cursor: nil, mode: .latest, eventID: eventID)
            eventDiscussionPosts = page.posts
            eventDiscussionNextCursor = page.nextCursor
            eventDiscussionPhase = page.posts.isEmpty ? .empty : .success
        } catch {
            eventDiscussionPhase = .failure(message: error.userFacingMessage ?? LT("讨论区加载失败，请稍后重试", "Failed to load discussion. Please try again later.", "ディスカッションを読み込めませんでした。時間をおいて再試行してください。"))
        }
    }

    @MainActor
    private func loadMoreEventDiscussionPostsIfNeeded() async {
        guard let cursor = eventDiscussionNextCursor, !isLoadingEventDiscussion else { return }
        isLoadingEventDiscussion = true
        defer { isLoadingEventDiscussion = false }

        do {
            let page = try await feedStreamRepository.fetchFeed(cursor: cursor, mode: .latest, eventID: eventID)
            let existing = Set(eventDiscussionPosts.map(\.id))
            eventDiscussionPosts.append(contentsOf: page.posts.filter { !existing.contains($0.id) })
            eventDiscussionNextCursor = page.nextCursor
            eventDiscussionPhase = eventDiscussionPosts.isEmpty ? .empty : .success
        } catch {
            showBannerMessageAutoDismiss(error.userFacingMessage ?? LT("加载更多讨论失败", "Failed to load more discussion.", "ディスカッションの追加読み込みに失敗しました。"))
        }
    }

    @MainActor
    private func mergeEventDiscussionPost(_ post: Post) {
        eventDiscussionPosts.removeAll { $0.id == post.id }
        eventDiscussionPosts.insert(post, at: 0)
        eventDiscussionPhase = .success
    }

    @MainActor
    private func replaceEventDiscussionPost(_ post: Post) {
        guard let index = eventDiscussionPosts.firstIndex(where: { $0.id == post.id }) else { return }
        eventDiscussionPosts[index] = post
    }

    @MainActor
    private func toggleEventDiscussionLike(post: Post) async {
        do {
            let updated = try await postInteractionRepository.toggleLike(postID: post.id, shouldLike: !post.isLiked)
            replaceEventDiscussionPost(updated)
        } catch {
            errorMessage = error.userFacingMessage
        }
    }

    @MainActor
    private func toggleEventDiscussionRepost(post: Post) async {
        do {
            let updated = try await postInteractionRepository.toggleRepost(postID: post.id, shouldRepost: !post.isReposted)
            replaceEventDiscussionPost(updated)
        } catch {
            errorMessage = error.userFacingMessage
        }
    }

    @MainActor
    private func toggleEventDiscussionSave(post: Post) async {
        do {
            let updated = try await postInteractionRepository.toggleSave(postID: post.id, shouldSave: !post.isSaved)
            replaceEventDiscussionPost(updated)
        } catch {
            errorMessage = error.userFacingMessage
        }
    }

    @ViewBuilder
    private func eventInfoTabContent(_ event: WebEvent, cardWidth: CGFloat) -> some View {
        let status = EventVisualStatus.resolve(event: event)
        let eventType = EventTypeOption.displayText(for: event.eventType, fallbackWhenEmpty: false)
        let unifiedAddress = event.unifiedAddress.trimmingCharacters(in: .whitespacesAndNewlines)

        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    eventStatusPill(status.title, color: status.badgeBorder)
                    if !eventType.isEmpty {
                        eventStatusPill(eventType, color: RaverTheme.accent)
                    }
                }

                eventInfoRow(
                    icon: "calendar",
                    title: LT("开始时间", "Start Time", "開始時間"),
                    value: eventInfoDateText(event.startDate, event: event)
                )
                eventInfoRow(
                    icon: "clock",
                    title: LT("结束时间", "End Time", "終了時間"),
                    value: eventInfoDateText(event.endDate, event: event)
                )
                if !unifiedAddress.isEmpty {
                    eventInfoRow(icon: "mappin.and.ellipse", title: LT("活动地址", "Address", "住所"), value: unifiedAddress)
                }
                if hasEventVenueContent(event) {
                    eventVenueActionRow(event)
                    eventVenueInlineMapCard(event)
                }
                if let website = event.officialWebsite, !website.isEmpty {
                    if let websiteURL = normalizedEventURL(website) {
                        Link(destination: websiteURL) {
                            eventInfoRow(icon: "globe", title: LT("官网", "Website", "公式サイト"), value: website, linkStyle: true)
                        }
                        .buttonStyle(.plain)
                    } else {
                        eventInfoRow(icon: "globe", title: LT("官网", "Website", "公式サイト"), value: website)
                    }
                }
                if let festival = event.wikiFestival {
                    eventBrandInfoRow(festival)
                }
            }
        }
        .frame(width: cardWidth, alignment: .leading)

        let displayDescription = EventWeekScheduleMode.stripMarker(from: event.description)
        if !displayDescription.isEmpty {
            GlassCard {
                VStack(alignment: .leading, spacing: 8) {
                    Text(LT("活动介绍", "活动介绍", "イベント紹介"))
                        .font(.headline)
                        .foregroundStyle(RaverTheme.primaryText)
                    Text(displayDescription)
                        .font(.subheadline)
                        .foregroundStyle(RaverTheme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(width: cardWidth, alignment: .leading)
        }

        let ticketLinkURL = event.ticketUrl.flatMap { normalizedEventURL($0) }
        if !event.ticketTiers.isEmpty || ((event.ticketNotes ?? "").isEmpty == false) || ticketLinkURL != nil {
            GlassCard {
                VStack(alignment: .leading, spacing: 10) {
                    Text(LT("票档信息", "票档信息", "チケット情報"))
                        .font(.headline)
                        .foregroundStyle(RaverTheme.primaryText)
                    ForEach(event.ticketTiers) { tier in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(tier.name)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(RaverTheme.primaryText)
                            }
                            Spacer()
                            Text((tier.price ?? 0).appLocalizedCurrencyText(currencyCode: tier.currency ?? event.ticketCurrency))
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(RaverTheme.accent)
                        }
                        .padding(.vertical, 4)
                        .overlay(alignment: .bottom) {
                            Divider().opacity(0.28)
                        }
                    }
                    if let notes = event.ticketNotes, !notes.isEmpty {
                        Text(notes)
                        .font(.subheadline)
                        .foregroundStyle(RaverTheme.secondaryText)
                    }
                    if let ticketLinkURL {
                        Link(destination: ticketLinkURL) {
                            eventInfoRow(
                                icon: "ticket.fill",
                                title: LT("票务外链", "Ticket Link", "チケット外部リンク"),
                                value: LT("打开外部链接", "Open Link", "外部リンクを開く"),
                                linkStyle: true
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .frame(width: cardWidth, alignment: .leading)
        }

        if let organizer = event.organizer {
            GlassCard {
                Button {
                    appPush(.userProfile(userID: organizer.id))
                } label: {
                    HStack(spacing: 10) {
                        ImageLoaderView(urlString: organizer.avatarUrl, resizingMode: .fill)
                            .background(organizerAvatarFallback(organizer))
                            .frame(width: 38, height: 38)
                            .clipShape(Circle())
                        VStack(alignment: .leading, spacing: 3) {
                            Text(LT("发布方", "发布方", "公開元"))
                                .font(.caption)
                                .foregroundStyle(RaverTheme.secondaryText)
                            Text(organizer.displayName ?? organizer.username)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(RaverTheme.primaryText)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(RaverTheme.secondaryText)
                    }
                }
                .buttonStyle(.plain)
            }
            .frame(width: cardWidth, alignment: .leading)
        } else if let organizerName = event.organizerName, !organizerName.isEmpty {
            GlassCard {
                eventInfoRow(icon: "person.2", title: LT("发布方", "Publisher", "公開元"), value: organizerName)
            }
            .frame(width: cardWidth, alignment: .leading)
        }

    }

    @ViewBuilder
    private func eventLineupTabContent(_ event: WebEvent, cardWidth: CGFloat) -> some View {
        let lineupImageURLs = event.lineupAssetURLs
        let timetableImageURLs = event.timetableAssetURLs
        let allLineupMediaURLs = lineupImageURLs + timetableImageURLs
        let lineupImageWidth = cardWidth + 2
        let lineupImageCornerRadius: CGFloat = 8
        let lineupPreviewItems: [FullscreenMediaItem] = allLineupMediaURLs.enumerated().map { index, raw in
            FullscreenMediaItem(rawURL: raw.trimmingCharacters(in: .whitespacesAndNewlines), index: index)
        }
        let hasLineupDJs = !lineupDJEntries(for: event, sortMode: lineupSortMode).isEmpty

        lineupDJsStrip(for: event)

        if !allLineupMediaURLs.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text(LT("活动阵容图", "活动阵容图", "イベントラインナップ画像"))
                    .font(.headline)

                ForEach(Array(allLineupMediaURLs.enumerated()), id: \.offset) { index, rawURL in
                    if allLineupMediaURLs.count > 1 {
                        if index < lineupImageURLs.count {
                            Text(lineupImageURLs.count > 1 ? "Lineup \(index + 1)" : "Lineup")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(RaverTheme.secondaryText)
                        } else {
                            Text(timetableImageURLs.count > 1 ? "Timetable \(index - lineupImageURLs.count + 1)" : "Timetable")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(RaverTheme.secondaryText)
                        }
                    }

                    if let resolved = AppConfig.resolvedURLString(rawURL),
                       let url = URL(string: resolved) {
                        Button {
                            selectedLineupMedia = FullscreenMediaSelection(id: index)
                        } label: {
                            WebImage(url: url) { image in
                                image
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: lineupImageWidth)
                            } placeholder: {
                                RoundedRectangle(cornerRadius: lineupImageCornerRadius, style: .continuous)
                                    .fill(RaverTheme.card)
                                    .frame(width: lineupImageWidth, height: lineupImageWidth * 0.75)
                                    .overlay {
                                        ProgressView()
                                    }
                            }
                            .clipShape(
                                RoundedRectangle(cornerRadius: lineupImageCornerRadius, style: .continuous)
                            )
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, -1)
                    } else {
                        RoundedRectangle(cornerRadius: lineupImageCornerRadius, style: .continuous)
                            .fill(RaverTheme.card)
                            .frame(width: lineupImageWidth)
                            .frame(minHeight: 180)
                            .padding(.horizontal, -1)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .fullScreenCover(item: $selectedLineupMedia) { selection in
                FullscreenMediaViewer(items: lineupPreviewItems, initialIndex: selection.id)
            }
        }

        if allLineupMediaURLs.isEmpty && !hasLineupDJs {
            Text(LT("暂无阵容信息", "暂无阵容信息", "ラインナップ情報はまだありません"))
                .font(.subheadline)
                .foregroundStyle(RaverTheme.secondaryText)
                .padding(.vertical, 8)
        }
    }

    @ViewBuilder
    private func eventScheduleTabContent(_ event: WebEvent) -> some View {
        let scheduledSlots = event.lineupSlots
            .filter { $0.endTime > $0.startTime }
            .sorted(by: { $0.startTime < $1.startTime })

        if scheduledSlots.isEmpty {
            Text(LT("等待时间表发布", "等待时间表发布", "タイムテーブル公開待ち"))
                .font(.subheadline)
                .foregroundStyle(RaverTheme.secondaryText)
                .padding(.vertical, 8)
        } else {
            EventRoutineView(
                event: event,
                scheduledSlots: scheduledSlots,
                presentationStyle: .embedded
            )
        }
    }

    @ViewBuilder
    private func eventRatingsTabContent() -> some View {
        if relatedRatingEvents.isEmpty {
            Text(LT("暂无对应打分事件", "暂无对应打分事件", "対応する評価イベントはありません"))
                .font(.subheadline)
                .foregroundStyle(RaverTheme.secondaryText)
                .padding(.vertical, 8)
        } else {
            ForEach(relatedRatingEvents) { ratingEvent in
                Button {
                    selectedRatingEventID = ratingEvent.id
                } label: {
                    HStack(spacing: 10) {
                        eventRatingThumb(urlString: ratingEvent.imageUrl, size: 52)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(ratingEvent.name)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(RaverTheme.primaryText)
                                .lineLimit(2)
                            Text(LT("\(ratingEvent.units.count) 个打分对象", "\(ratingEvent.units.count) rating targets", "\(ratingEvent.units.count) 件の評価対象"))
                                .font(.caption)
                                .foregroundStyle(RaverTheme.secondaryText)
                                .lineLimit(1)
                        }

                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(RaverTheme.secondaryText)
                    }
                    .padding(10)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(RaverTheme.card)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder
    private func eventSetsTabContent() -> some View {
        if relatedEventSets.isEmpty {
            Text(LT("暂无对应 Sets", "暂无对应 Sets", "対応するSetはありません"))
                .font(.subheadline)
                .foregroundStyle(RaverTheme.secondaryText)
                .padding(.vertical, 8)
        } else {
            ForEach(relatedEventSets) { set in
                Button {
                    discoverPush(.setDetail(setID: set.id))
                } label: {
                    HStack(spacing: 10) {
                        eventRatingThumb(urlString: set.thumbnailUrl, size: 52)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(set.title)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(RaverTheme.primaryText)
                                .lineLimit(2)
                            Text(set.dj?.name ?? set.customDjNames.first ?? set.djId ?? LT("未关联 DJ", "No DJ Linked", "DJ未関連"))
                                .font(.caption)
                                .foregroundStyle(RaverTheme.secondaryText)
                                .lineLimit(1)
                            if let recordedAt = set.recordedAt {
                                Text(recordedAt.appLocalizedYMDText())
                                    .font(.caption2)
                                    .foregroundStyle(RaverTheme.secondaryText)
                                    .lineLimit(1)
                            }
                        }

                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(RaverTheme.secondaryText)
                    }
                    .padding(10)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(RaverTheme.card)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder
    private func eventRatingThumb(urlString: String?, size: CGFloat) -> some View {
        ImageLoaderView(urlString: urlString, resizingMode: .fill)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(RaverTheme.card)
                    .overlay(
                        Image(systemName: "star.leadinghalf.filled")
                            .font(.system(size: size * 0.32, weight: .semibold))
                            .foregroundStyle(Color.white.opacity(0.9))
                    )
            )
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func eventSchedulePreviewRow(_ slot: WebEventLineupSlot, event: WebEvent) -> some View {
        let act = EventLineupActCodec.parse(slot: slot)
        let stageName = slot.stageName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        return HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(act.displayName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(RaverTheme.primaryText)
                        .lineLimit(2)
                    if act.type != .solo {
                        lineupActTag(act.type)
                    }
                }

                if !stageName.isEmpty {
                    Text(stageName)
                        .font(.caption)
                        .foregroundStyle(RaverTheme.secondaryText)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 8)

            Text(EventTimeZoneDisplay.slotTimeRange(slot, event: event))
                .font(.caption)
                .foregroundStyle(RaverTheme.secondaryText)
                .lineLimit(1)
        }
        .padding(.vertical, 8)
        .overlay(alignment: .bottom) {
            Divider().opacity(0.45)
        }
    }

    private func lineupActTag(_ type: EventLineupActType) -> some View {
        Text(type.title)
            .font(.caption2.weight(.bold))
            .foregroundStyle(RaverTheme.accent)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(RaverTheme.accent.opacity(0.14), in: Capsule())
    }

    private func selectEventDetailTab(_ tab: EventDetailTab) {
        let targetProgress = CGFloat(selectedIndex(for: tab))
        if selectedTab == tab, abs(pageProgress - targetProgress) < 0.001 {
            return
        }

        isTabSwitchingByTap = true
        tabSwitchUnlockWorkItem?.cancel()

        withAnimation(.interactiveSpring(response: 0.26, dampingFraction: 0.84)) {
            selectedTab = tab
            pageProgress = targetProgress
        }

        let unlockWorkItem = DispatchWorkItem {
            isTabSwitchingByTap = false
            tabSwitchUnlockWorkItem = nil
        }
        tabSwitchUnlockWorkItem = unlockWorkItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45, execute: unlockWorkItem)
    }

    private var indicatorRect: CGRect? {
        guard !tabFrames.isEmpty else { return nil }
        let count = EventDetailTab.allCases.count
        guard count > 0 else { return nil }

        let clamped = min(max(pageProgress, 0), CGFloat(count - 1))
        let leftIndex = Int(floor(clamped))
        let rightIndex = min(leftIndex + 1, count - 1)
        let t = clamped - CGFloat(leftIndex)

        let leftTab = EventDetailTab.allCases[leftIndex]
        let rightTab = EventDetailTab.allCases[rightIndex]
        guard let leftFrame = tabFrames[leftTab], let rightFrame = tabFrames[rightTab] else {
            return nil
        }

        let baseX = leftFrame.minX + (rightFrame.minX - leftFrame.minX) * t
        let baseWidth = leftFrame.width + (rightFrame.width - leftFrame.width) * t
        let elastic = (1 - abs(0.5 - t) * 2) * 16
        return CGRect(x: baseX - elastic * 0.2, y: 0, width: baseWidth + elastic, height: 3)
    }

    private func selectedIndex(for tab: EventDetailTab) -> Int {
        EventDetailTab.allCases.firstIndex(of: tab) ?? 0
    }

    private func tabVisualState(for tab: EventDetailTab) -> Bool {
        let index = CGFloat(selectedIndex(for: tab))
        return abs(pageProgress - index) < 0.5
    }

    private func updatePageProgress(with offsets: [EventDetailTab: CGFloat]) {
        guard pagerWidth > 1 else { return }
        let progressCandidates: [(progress: CGFloat, distance: CGFloat)] = EventDetailTab.allCases.enumerated().compactMap { index, item in
            guard let minX = offsets[item] else { return nil }
            let progress = CGFloat(index) - (minX / pagerWidth)
            return (progress, abs(minX))
        }

        guard let best = progressCandidates.min(by: { $0.distance < $1.distance }) else { return }
        let clamped = min(max(best.progress, 0), CGFloat(max(0, EventDetailTab.allCases.count - 1)))
        pageProgress = clamped
    }

    private func heroSection(_ event: WebEvent) -> some View {
        ZStack(alignment: .top) {
            GeometryReader { geo in
                ZStack {
                    RaverTheme.card
                    if let cover = AppConfig.resolvedURLString(event.coverAssetURL) {
                        ImageLoaderView(urlString: cover)
                            .frame(width: geo.size.width, height: geo.size.height, alignment: .top)
                            .background(RaverTheme.card)
                    } else {
                        LinearGradient(
                            colors: [RaverTheme.accent.opacity(0.35), RaverTheme.card],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    }
                }
                .frame(width: geo.size.width, height: geo.size.height)
                .clipped()
            }

            LinearGradient(
                colors: [
                    .clear,
                    Color.black.opacity(0.42),
                    Color.black.opacity(0.78),
                    Color.black.opacity(0.94)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack(spacing: 0) {
            Spacer()   // 把内容推到底
                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 8) {
                        if isEventLiveDiscussionActive(event) {
                            eventLiveHeroEntry(event)
                        }

                        Spacer(minLength: 0)

                        Button {
                            Task { await beginEventCheckinFlow(for: event) }
                        } label: {
                            eventHeroActionButton(
                                title: activeAttendanceCheckin == nil ? LT("打卡", "Check-in", "チェックイン") : LT("编辑打卡", "Edit Check-in", "チェックインを編集"),
                                icon: "postage.stamp.fill",
                                fill: RaverTheme.accent
                            )
                        }
                        .buttonStyle(.plain)
                        .disabled(isPreparingEventCheckinSheet)

                    }
                    .padding(.bottom, 6)

                    Text(event.name)
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(Color.white)
                        .lineLimit(2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.bottom, 14)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 360)
        .clipped()
        .zIndex(1)
    }

    private func eventHeroActionButton(title: String, icon: String, fill: Color) -> some View {
        Label(title, systemImage: icon)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Color.white)
            .lineLimit(1)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(
                Capsule()
                    .fill(fill)
            )
    }

    private func eventBoundLocationPoint(_ event: WebEvent) -> WebEventLocationPoint? {
        guard let point = event.locationPoint,
              let location = point.location,
              location.lat.isFinite,
              location.lng.isFinite else {
            return nil
        }
        return point
    }

    private func localizedPointText(_ value: WebBiText?) -> String {
        let language = AppLanguagePreference.current.effectiveLanguage
        let localized = value?.text(for: language).trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !localized.isEmpty { return localized }
        let zh = value?.zh.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !zh.isEmpty { return zh }
        let en = value?.en.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return en
    }

    private func hasEventVenueContent(_ event: WebEvent) -> Bool {
        return eventBoundLocationPoint(event) != nil
    }

    private func eventVenueDisplayText(_ event: WebEvent) -> String {
        guard let point = eventBoundLocationPoint(event) else {
            return LT("未填写场地信息", "Venue not provided", "会場情報未入力")
        }
        let formatted = localizedPointText(point.formattedAddressI18n).trimmingCharacters(in: .whitespacesAndNewlines)
        if !formatted.isEmpty { return formatted }
        let unified = event.unifiedAddress.trimmingCharacters(in: .whitespacesAndNewlines)
        if !unified.isEmpty { return unified }
        return LT("未填写场地信息", "Venue not provided", "会場情報未入力")
    }

    private func eventMapURL(for event: WebEvent) -> URL? {
        guard let coordinate = eventVenueCoordinate(event) else { return nil }
        let queryText = eventVenueDisplayText(event)
        var components = URLComponents(string: "http://maps.apple.com/")
        components?.queryItems = [
            URLQueryItem(name: "ll", value: "\(coordinate.latitude),\(coordinate.longitude)"),
            URLQueryItem(name: "q", value: queryText)
        ]
        return components?.url
    }

    private func makeEventShareCardPayload(from event: WebEvent) -> EventShareCardPayload {
        let cityText = localizedPointText(event.cityI18n).nilIfBlank ?? event.city?.nilIfBlank
        let venueText = hasEventVenueContent(event) ? eventVenueDisplayText(event).nilIfBlank : nil
        let coverURL = AppConfig.resolvedURLString(event.coverAssetURL)

        return EventShareCardPayload(
            eventID: event.id,
            eventName: event.name,
            venueName: venueText,
            city: cityText,
            startAtISO8601: Self.eventCardISO8601Formatter.string(from: event.startDate),
            coverImageURL: coverURL,
            badgeText: LT("活动", "Event", "イベント")
        )
    }

    private static let eventCardISO8601Formatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private func eventVenueCoordinate(_ event: WebEvent) -> CLLocationCoordinate2D? {
        guard let point = eventBoundLocationPoint(event),
              let location = point.location else {
            return nil
        }
        return CLLocationCoordinate2D(latitude: location.lat, longitude: location.lng)
    }

    private func copyEventVenueText(_ event: WebEvent) {
        UIPasteboard.general.string = eventVenueDisplayText(event)
        errorMessage = LT("场地信息已复制", "Venue information copied.", "会場情報をコピーしました。")
    }

    private func openEventVenueInMap(_ event: WebEvent) {
        let venueText = eventVenueDisplayText(event)
        let fallbackQuery = eventVenueFallbackQuery(event)
        let coordinate = eventVenueCoordinate(event)
        guard coordinate != nil || !fallbackQuery.isEmpty else {
            errorMessage = LT("暂无场地定位信息", "No venue location information available.", "会場の位置情報がありません。")
            return
        }

        venueMapContext = EventVenueMapContext(
            eventName: event.name,
            venueDisplayText: venueText,
            summaryLocation: venueText,
            coordinate: coordinate,
            queryText: fallbackQuery,
            mapURL: eventMapURL(for: event)
        )
    }

    private func eventVenueActionRow(_ event: WebEvent) -> some View {
        HStack(alignment: .top, spacing: 10) {
            ZStack {
                Circle()
                    .fill(RaverTheme.card.opacity(1))
                    .frame(width: 28, height: 28)
                Image(systemName: "mappin.and.ellipse")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(RaverTheme.secondaryText)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(LT("场地", "场地", "会場"))
                    .font(.caption)
                    .foregroundStyle(RaverTheme.secondaryText.opacity(0.88))
                Text(eventVenueDisplayText(event))
                    .font(.subheadline)
                    .foregroundStyle(RaverTheme.primaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    @ViewBuilder
    private func eventVenueInlineMapCard(_ event: WebEvent) -> some View {
        let queryText = eventVenueFallbackQuery(event)
        Button {
            openEventVenueInMap(event)
        } label: {
            ZStack(alignment: .bottomLeading) {
                EventVenueInlineMapPreview(
                    initialCoordinate: eventVenueCoordinate(event),
                    queryText: queryText,
                    venueDisplayText: eventVenueDisplayText(event)
                )
                .allowsHitTesting(false)

                HStack(spacing: 6) {
                    Image(systemName: "location.viewfinder")
                    Text(LT("查看地图", "查看地图", "地図を見る"))
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(RaverTheme.primaryText)
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(
                    Capsule()
                        .fill(.ultraThinMaterial)
                )
                .padding(10)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 146)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.white.opacity(0.1), lineWidth: 0.8)
            )
        }
        .buttonStyle(.plain)
        .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .padding(.top, 2)
    }

    private func eventVenueFallbackQuery(_ event: WebEvent) -> String {
        let text = eventVenueDisplayText(event).trimmingCharacters(in: .whitespacesAndNewlines)
        if !text.isEmpty { return text }
        guard let point = eventBoundLocationPoint(event) else { return "" }
        let fallback = [
            localizedPointText(point.nameI18n),
            localizedPointText(point.addressI18n),
            (point.city ?? "").trimmingCharacters(in: .whitespacesAndNewlines),
        ]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " · ")
        return fallback
    }

    private func normalizedEventURL(_ raw: String) -> URL? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if let absolute = URL(string: trimmed), absolute.scheme != nil {
            return absolute
        }
        return URL(string: "https://\(trimmed)")
    }

    private var immersiveTrailingAction: AnyView? {
        guard event != nil else { return nil }
        return AnyView(
            Button {
                if let event {
                    shareMorePresentation = EventCardSharePresentation(
                        payload: makeEventShareCardPayload(from: event)
                    )
                    isShareMorePanelVisible = false
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
        )
    }

    private func dismissShareMorePanel(after: (() -> Void)? = nil) {
        withAnimation(.sharePanelDismissSpring) {
            isShareMorePanelVisible = false
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.34) {
            guard !isShareMorePanelVisible else { return }
            shareMorePresentation = nil
            after?()
        }
    }

    private func showWidgetStatusBanner(message: String, conversation: Conversation? = nil) {
        OperationBannerCenter.shared.success(
            message,
            action: conversation.map { .appRoute(.conversation(target: .fromConversation($0))) } ?? .none
        )
    }

    private func showBannerMessageAutoDismiss(_ message: String) {
        bannerMessage = message
        let token = UUID()
        bannerDismissToken = token
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            guard bannerDismissToken == token else { return }
            withAnimation(.easeOut(duration: 0.25)) {
                bannerMessage = nil
            }
        }
    }

    private func loadSharePanelConversations() async throws -> [Conversation] {
        async let directs = shareMessageRepository.fetchConversations(type: .direct)
        async let groups = shareMessageRepository.fetchConversations(type: .group)
        let merged = try await directs + groups
        let deduped = merged.reduce(into: [String: Conversation]()) { partialResult, conversation in
            partialResult[conversation.id] = conversation
        }
        return deduped.values.sorted {
            if $0.isPinned != $1.isPinned { return $0.isPinned && !$1.isPinned }
            return $0.updatedAt > $1.updatedAt
        }
    }

    private func sendSharePayload(
        _ payload: EventShareCardPayload,
        to conversation: Conversation,
        note: String?
    ) async throws {
        _ = try await shareMessageRepository.sendEventCardMessage(
            conversationID: conversation.id,
            payload: payload
        )

        let trimmedNote = note?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !trimmedNote.isEmpty {
            _ = try await shareMessageRepository.sendMessage(
                conversationID: conversation.id,
                content: trimmedNote
            )
        }
    }

    private func sharePrimaryActions() -> [SharePanelPrimaryAction] {
        [
            SharePanelPrimaryAction(
                title: "微信",
                systemImage: "message.circle.fill",
                accentColor: Color(red: 0.18, green: 0.76, blue: 0.35)
            ) {
                errorMessage = LT("微信分享接口待接入。", "WeChat share hook is not connected yet.", "WeChat共有連携は未接続です。")
            },
            SharePanelPrimaryAction(
                title: "QQ",
                systemImage: "paperplane.circle.fill",
                accentColor: Color(red: 0.21, green: 0.58, blue: 0.98)
            ) {
                errorMessage = LT("QQ 分享接口待接入。", "QQ share hook is not connected yet.", "QQ共有連携は未接続です。")
            }
        ]
    }

    private func shareMoreQuickActions(for event: WebEvent?) -> [SharePanelQuickAction] {
        var actions: [SharePanelQuickAction] = []

        if let event, isMine(event) {
            actions.append(
                SharePanelQuickAction(
                    title: LT("编辑", "Edit", "編集"),
                    systemImage: "square.and.pencil",
                    accentColor: Color(red: 0.99, green: 0.65, blue: 0.20)
                ) {
                    discoverPush(.eventEdit(eventID: event.id))
                }
            )
            actions.append(
                SharePanelQuickAction(
                    title: LT("删除活动", "删除活动", "イベントを削除"),
                    systemImage: "trash",
                    accentColor: Color(red: 0.91, green: 0.29, blue: 0.32)
                ) {
                    Task { await deleteEvent() }
                }
            )
        }

        let isMarked = eventFavoriteID != nil
        actions.append(
            SharePanelQuickAction(
                title: isTogglingMarkedEvent
                    ? LT("处理中", "Working", "処理中")
                    : (isMarked ? LT("取消收藏", "Unfavorite", "お気に入り解除") : LT("收藏活动", "Favorite", "お気に入り")),
                systemImage: isMarked ? "star.fill" : "star",
                accentColor: Color(red: 0.99, green: 0.82, blue: 0.22)
            ) {
                guard let event else { return }
                Task { await toggleMarkedEvent(event) }
            }
        )
        actions.append(
            SharePanelQuickAction(
                title: LT("复制链接", "Copy Link", "リンクをコピー"),
                systemImage: "link",
                accentColor: Color(red: 0.30, green: 0.67, blue: 0.97)
            ) {
                guard let event else { return }
                Task { await copyEventShareLink(event) }
            }
        )
        actions.append(
            SharePanelQuickAction(
                title: LT("查看二维码", "View QR", "QRを見る"),
                systemImage: "qrcode",
                accentColor: Color(red: 0.46, green: 0.35, blue: 0.96)
            ) {
                guard let event else { return }
                Task { await openEventQRCode(event) }
            }
        )
        actions.append(
            SharePanelQuickAction(
                title: LT("查看海报", "View Poster", "海報を見る"),
                systemImage: "photo.on.rectangle",
                accentColor: Color(red: 0.98, green: 0.71, blue: 0.22)
            ) {
                guard let event else { return }
                Task { await openEventPoster(event) }
            }
        )
        actions.append(
            SharePanelQuickAction(
                title: LT("保存海报", "Save Poster", "海報を保存"),
                systemImage: "photo.badge.arrow.down",
                accentColor: Color(red: 0.21, green: 0.58, blue: 0.98)
            ) {
                guard let event else { return }
                Task { await saveEventPoster(event) }
            }
        )

        actions.append(
            SharePanelQuickAction(
                title: isCachingManualSnapshot ? LT("缓存中", "Caching", "キャッシュ中") : LT("缓存", "Cache", "キャッシュ"),
                systemImage: "arrow.down.circle",
                accentColor: Color(red: 0.33, green: 0.73, blue: 0.95)
            ) {
                Task { await cacheEventManually() }
            }
        )

        if let event {
            actions.append(
                SharePanelQuickAction(
                    title: isInWidgetCountdownPool ? LT("移出倒计时", "Remove Countdown", "カウントダウンから削除") : LT("桌面倒计时", "Widget Countdown", "ウィジェットカウントダウン"),
                    systemImage: isInWidgetCountdownPool ? "minus.circle" : "apps.iphone",
                    accentColor: Color(red: 0.46, green: 0.35, blue: 0.96)
                ) {
                    Task { await toggleSelectedEventInWidgetPool(event) }
                }
            )
        }

        actions.append(
            SharePanelQuickAction(
                title: LT("贡献信息", "Incorrect Info", "情報を修正"),
                systemImage: "info.circle",
                accentColor: Color(red: 0.96, green: 0.47, blue: 0.26)
            ) {
                openEventFeedbackEntry()
            }
        )
        actions.append(
            SharePanelQuickAction(
                title: LT("举报", "Report", "報告"),
                systemImage: "flag",
                accentColor: Color(red: 0.91, green: 0.29, blue: 0.32)
            ) {
                openEventReportEntry()
            }
        )

        return actions
    }

    @MainActor
    private func copyEventShareLink(_ event: WebEvent) async {
        do {
            let subtitle = [event.city, event.organizerName].compactMap { value in
                value?.trimmingCharacters(in: .whitespacesAndNewlines)
            }.filter { !$0.isEmpty }.joined(separator: " · ")

            let result = try await shareLinkCoordinator.copyLink(
                target: ShareTarget(
                    type: .event,
                    id: event.id,
                    title: event.name,
                    subtitle: subtitle.isEmpty ? nil : subtitle,
                    imageURL: event.coverImageUrl
                )
            )

            if result.usedDeepLinkFallback {
                showWidgetStatusBanner(message: LT("已复制 App 内链接", "Copied app-only link.", "アプリ内リンクをコピーしました"))
            } else {
                showWidgetStatusBanner(message: LT("已复制链接", "Link copied", "リンクをコピーしました"))
            }
        } catch {
            errorMessage = error.userFacingMessage ?? LT("复制链接失败，请稍后重试。", "Failed to copy link. Please try again.", "リンクをコピーできませんでした。もう一度お試しください。")
        }
    }

    @MainActor
    private func openEventQRCode(_ event: WebEvent) async {
        do {
            let subtitle = [event.city, event.organizerName].compactMap { value in
                value?.trimmingCharacters(in: .whitespacesAndNewlines)
            }.filter { !$0.isEmpty }.joined(separator: " · ")

            let resolved = try await shareLinkCoordinator.resolveLink(
                target: ShareTarget(
                    type: .event,
                    id: event.id,
                    title: event.name,
                    subtitle: subtitle.isEmpty ? nil : subtitle,
                    imageURL: event.coverImageUrl
                ),
                channel: "view_qr"
            )
            appPush(
                .profile(
                    .shareQRCode(
                        title: resolved.payload.title,
                        subtitle: resolved.payload.subtitle,
                        imageURL: resolved.payload.imageURL,
                        shortURL: resolved.payload.shortURL,
                        qrCodeURL: resolved.payload.qrCodeURL
                    )
                )
            )
        } catch {
            errorMessage = error.userFacingMessage ?? LT("打开二维码失败，请稍后重试。", "Failed to open QR code. Please try again later.", "QRコードを開けませんでした。時間をおいて再試行してください。")
        }
    }

    @MainActor
    private func openEventPoster(_ event: WebEvent) async {
        do {
            let subtitle = [event.city, event.organizerName].compactMap { value in
                value?.trimmingCharacters(in: .whitespacesAndNewlines)
            }.filter { !$0.isEmpty }.joined(separator: " · ")

            let resolved = try await shareLinkCoordinator.resolveLink(
                target: ShareTarget(
                    type: .event,
                    id: event.id,
                    title: event.name,
                    subtitle: subtitle.isEmpty ? nil : subtitle,
                    imageURL: event.coverImageUrl
                ),
                channel: "view_poster"
            )
            appPush(
                .profile(
                    .shareAsset(
                        navigationTitle: LT("分享海报", "Share Poster", "海報を共有"),
                        title: resolved.payload.title,
                        subtitle: resolved.payload.subtitle,
                        imageURL: resolved.payload.imageURL,
                        assetURL: resolved.payload.posterURL,
                        emptyTitle: LT("海报暂未生成", "Poster Unavailable", "海報はまだ生成されていません"),
                        emptyMessage: LT("当前分享海报还没有准备好，请稍后再试。", "The share poster is not ready yet. Please try again later.", "共有海報はまだ準備できていません。時間をおいて再試行してください。"),
                        hintText: LT("活动海报由分享系统统一生成，活动标题、摘要和二维码都会跟随短链保持一致。", "Event posters are generated by the share system, so the title, summary, and QR code stay aligned with the short link.", "イベント海報は共有システムで生成され、タイトル、概要、QRコードは短縮リンクと同期されます。"),
                        saveButtonTitle: LT("保存海报", "Save Poster", "海報を保存")
                    )
                )
            )
        } catch {
            errorMessage = error.userFacingMessage ?? LT("打开分享海报失败，请稍后重试。", "Failed to open share poster. Please try again later.", "共有海報を開けませんでした。時間をおいて再試行してください。")
        }
    }

    @MainActor
    private func saveEventPoster(_ event: WebEvent) async {
        do {
            let subtitle = [event.city, event.organizerName].compactMap { value in
                value?.trimmingCharacters(in: .whitespacesAndNewlines)
            }.filter { !$0.isEmpty }.joined(separator: " · ")

            let resolved = try await shareLinkCoordinator.resolveLink(
                target: ShareTarget(
                    type: .event,
                    id: event.id,
                    title: event.name,
                    subtitle: subtitle.isEmpty ? nil : subtitle,
                    imageURL: event.coverImageUrl
                ),
                channel: "poster_save"
            )
            try await ShareAssetPhotoSaver.saveRemoteImage(from: resolved.payload.posterURL)
            showWidgetStatusBanner(message: LT("海报已保存到相册", "Poster saved to Photos", "海報を写真に保存しました"))
        } catch {
            errorMessage = error.userFacingMessage ?? LT("保存海报失败，请稍后重试。", "Failed to save poster. Please try again later.", "海報を保存できませんでした。時間をおいて再試行してください。")
        }
    }

    private func openEventFeedbackEntry() {
        // TODO: Wire to dedicated feedback route/page when available.
        errorMessage = LT("贡献信息入口即将开放，当前已记录该需求。", "Incorrect info entry is coming soon. We have recorded this request.", "情報修正の入口は近日公開予定です。この要望は記録しました。")
    }

    @MainActor
    private func toggleSelectedEventInWidgetPool(_ event: WebEvent) async {
        do {
            if isInWidgetCountdownPool {
                let result = try WidgetSelectableEventsSyncService.shared.remove(eventID: event.id)
                switch result {
                case .removed:
                    isInWidgetCountdownPool = false
                    showWidgetStatusBanner(message: LT("已从桌面倒计时候选活动移除。", "Removed from widget countdown candidates.", "ウィジェットカウントダウン候補から削除しました。"))
                case .notFound:
                    isInWidgetCountdownPool = false
                    showWidgetStatusBanner(message: LT("该活动已不在桌面倒计时候选列表中。", "This event is no longer in widget countdown candidates.", "このイベントはウィジェットカウントダウン候補ではありません。"))
                }
            } else {
                let result = try await WidgetSelectableEventsSyncService.shared.add(event: event)
                isInWidgetCountdownPool = true
                switch result {
                case .added:
                    showWidgetStatusBanner(message: LT("已加入桌面倒计时候选活动，长按组件即可选择。", "Added to widget countdown candidates. Long-press the widget to choose it.", "ウィジェットカウントダウン候補に追加しました。ウィジェットを長押しして選択できます。"))
                case .refreshed:
                    showWidgetStatusBanner(message: LT("已更新桌面倒计时候选活动。", "Updated in widget countdown candidates.", "ウィジェットカウントダウン候補を更新しました。"))
                }
            }
        } catch {
            errorMessage = error.userFacingMessage ?? LT("加入桌面倒计时失败，请稍后重试。", "Failed to add to widget countdown. Please try again later.", "ウィジェットカウントダウンに追加できませんでした。時間をおいて再試行してください。")
        }
    }

    @MainActor
    private func refreshWidgetCountdownState() async {
        isInWidgetCountdownPool = WidgetSelectableEventsSyncService.shared.contains(eventID: eventID)
    }

    private func openEventReportEntry() {
        guard let event else {
            errorMessage = LT("活动信息尚未加载完成。", "Event details are still loading.", "イベント情報はまだ読み込み中です。")
            return
        }
        reportTarget = ReportSheetTarget(
            id: event.id,
            type: .event,
            title: event.name,
            preview: event.description?.nilIfBlank ?? [event.city, event.organizerName].compactMap { $0?.nilIfBlank }.joined(separator: " · "),
            targetUserID: event.organizer?.id,
            targetUserDisplayName: event.organizer?.displayName ?? event.organizerName
        )
    }

    @ViewBuilder
    private func lineupDJsStrip(for event: WebEvent) -> some View {
        let djs = lineupDJEntries(for: event, sortMode: lineupSortMode)
        let canExpand = djs.count > 8
        if !djs.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Text(LT("参演 DJ", "参演 DJ", "出演DJ"))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(RaverTheme.primaryText)
                    Text(lineupSortMode.activeTitle)
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(RaverTheme.accent)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(RaverTheme.accent.opacity(0.12), in: Capsule())
                    Spacer(minLength: 0)
                    Button {
                        withAnimation(.interactiveSpring(response: 0.24, dampingFraction: 0.86)) {
                            lineupSortMode = lineupSortMode == .alphabetical ? .popularity : .alphabetical
                            expandedLineupPage = 0
                        }
                    } label: {
                        Label(lineupSortMode.toggleTitle, systemImage: lineupSortMode.iconName)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(lineupSortMode == .alphabetical ? Color(red: 0.98, green: 0.45, blue: 0.27) : RaverTheme.accent)
                    }
                    .buttonStyle(.plain)
                    if canExpand {
                        Button {
                            withAnimation(.interactiveSpring(response: 0.26, dampingFraction: 0.85)) {
                                showExpandedLineupList.toggle()
                                expandedLineupPage = 0
                            }
                        } label: {
                            Label(
                                showExpandedLineupList ? LT("收起名单", "Collapse lineup", "ラインナップを閉じる") : LT("下拉完整名单", "Expand full lineup", "全ラインナップを表示"),
                                systemImage: showExpandedLineupList ? "chevron.up" : "chevron.down"
                            )
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(RaverTheme.accent)
                        }
                        .buttonStyle(.plain)
                    }
                }

                HorizontalAxisLockedScrollView(showsIndicators: false) {
                    HStack(alignment: .top, spacing: 7) {
                        ForEach(djs) { dj in
                            lineupDJAvatarItem(dj)
                        }
                    }
                    .padding(.vertical, 2)
                }
                .frame(height: 82)

                if showExpandedLineupList {
                    lineupExpandedPager(djs)
                }
            }
            .animation(.spring(response: 0.34, dampingFraction: 0.86), value: showExpandedLineupList)
            .animation(.spring(response: 0.26, dampingFraction: 0.88), value: lineupSortMode)
        }
    }

    private func lineupExpandedPager(_ djs: [EventLineupDJEntry]) -> some View {
        let pages = lineupDJPages(djs)
        let pageCount = max(pages.count, 1)

        return VStack(spacing: 10) {
            TabView(selection: $expandedLineupPage) {
                ForEach(Array(pages.enumerated()), id: \.offset) { pageIndex, pageItems in
                    lineupExpandedGrid(pageItems)
                        .tag(pageIndex)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: 368)

            HStack(spacing: 12) {
                Button {
                    withAnimation(.spring(response: 0.24, dampingFraction: 0.9)) {
                        expandedLineupPage = max(0, expandedLineupPage - 1)
                    }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.caption.weight(.bold))
                        .frame(width: 32, height: 28)
                }
                .buttonStyle(.plain)
                .foregroundStyle(expandedLineupPage <= 0 ? RaverTheme.secondaryText.opacity(0.35) : RaverTheme.accent)
                .disabled(expandedLineupPage <= 0)

                Spacer(minLength: 0)

                Text("\(min(expandedLineupPage + 1, pageCount)) / \(pageCount)")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(RaverTheme.primaryText)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(RaverTheme.background.opacity(0.42), in: Capsule())

                Spacer(minLength: 0)

                Button {
                    withAnimation(.spring(response: 0.24, dampingFraction: 0.9)) {
                        expandedLineupPage = min(pageCount - 1, expandedLineupPage + 1)
                    }
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                        .frame(width: 32, height: 28)
                }
                .buttonStyle(.plain)
                .foregroundStyle(expandedLineupPage >= pageCount - 1 ? RaverTheme.secondaryText.opacity(0.35) : RaverTheme.accent)
                .disabled(expandedLineupPage >= pageCount - 1)
            }
            .padding(.horizontal, 6)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(RaverTheme.card.opacity(0.86))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(0.10), lineWidth: 0.8)
        )
        .padding(.top, 4)
        .transition(
            .asymmetric(
                insertion: .opacity.combined(with: .move(edge: .top)),
                removal: .opacity.combined(with: .scale(scale: 0.98, anchor: .top))
            )
        )
    }

    private func lineupExpandedGrid(_ djs: [EventLineupDJEntry]) -> some View {
        let columns = [
            GridItem(.flexible(minimum: 0), spacing: 12, alignment: .top),
            GridItem(.flexible(minimum: 0), spacing: 12, alignment: .top),
            GridItem(.flexible(minimum: 0), spacing: 12, alignment: .top),
            GridItem(.flexible(minimum: 0), spacing: 12, alignment: .top)
        ]

        return LazyVGrid(columns: columns, alignment: .center, spacing: 12) {
            ForEach(djs) { dj in
                lineupDJAvatarItem(dj)
                    .frame(maxWidth: .infinity, minHeight: 80, alignment: .top)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 356, maxHeight: 356, alignment: .top)
        .padding(.top, 2)
    }

    private func lineupDJPages(_ djs: [EventLineupDJEntry]) -> [[EventLineupDJEntry]] {
        let pageSize = 16
        guard !djs.isEmpty else { return [[]] }
        return stride(from: 0, to: djs.count, by: pageSize).map { start in
            Array(djs[start..<min(start + pageSize, djs.count)])
        }
    }

    @ViewBuilder
    private func lineupDJAvatarItem(_ dj: EventLineupDJEntry) -> some View {
        let itemWidth = lineupActItemWidth(dj.act)
        let content = VStack(spacing: 6) {
            lineupActAvatars(dj.act)

            Text(dj.name)
                .font(.caption2)
                .foregroundStyle(RaverTheme.secondaryText)
                .lineLimit(2)
                .truncationMode(.tail)
                .multilineTextAlignment(.center)
                .frame(width: itemWidth, height: 30, alignment: .center)
        }
        .frame(width: itemWidth, alignment: .top)

        if dj.act.type == .solo,
           let primaryPerformer = dj.act.performers.first {
            Button {
                selectLineupPerformer(primaryPerformer)
            } label: {
                content
            }
            .buttonStyle(.plain)
        } else {
            Button {
                pendingCollaborativeLineupEntry = dj
            } label: {
                content
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private func lineupActAvatars(_ act: EventLineupResolvedAct) -> some View {
        let contentWidth = lineupActItemWidth(act)
        if act.type == .solo {
            lineupPerformerAvatar(act.performers.first, size: 44)
                .frame(width: contentWidth, height: 44, alignment: .center)
        } else {
            let performers = Array(act.performers.prefix(act.type.performerCount))
            let avatarSize: CGFloat = 44
            let overlapOffset = avatarSize * 0.5
            let stackWidth = avatarSize + CGFloat(max(0, performers.count - 1)) * overlapOffset

            ZStack(alignment: .leading) {
                ForEach(Array(performers.enumerated()), id: \.offset) { index, performer in
                    lineupPerformerAvatar(performer, size: avatarSize)
                        .overlay(
                            Circle()
                                .stroke(RaverTheme.background.opacity(0.86), lineWidth: 2)
                        )
                        .offset(x: CGFloat(index) * overlapOffset)
                        .zIndex(Double(index))
                }
            }
            .frame(width: stackWidth, height: 44, alignment: .leading)
            .frame(width: contentWidth, height: 44, alignment: .center)
        }
    }

    private func lineupActItemWidth(_ act: EventLineupResolvedAct) -> CGFloat {
        guard act.type != .solo else { return 74 }
        let performerCount = CGFloat(max(1, min(act.performers.count, act.type.performerCount)))
        let avatarSize: CGFloat = 44
        let overlapOffset = avatarSize * 0.5
        let width = avatarSize + (performerCount - 1) * overlapOffset
        return max(74, width)
    }

    private func resolvedPerformerDJID(_ performer: EventLineupPerformer) -> String? {
        let inlineID = performer.djID?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return inlineID.isEmpty ? nil : inlineID
    }

    private func selectLineupPerformer(_ performer: EventLineupPerformer) {
        pendingCollaborativeLineupEntry = nil
        if let djID = resolvedPerformerDJID(performer) {
            appPush(.djDetail(djID: djID))
        } else {
            presentUnboundDJPrompt(name: performer.name)
        }
    }

    private func presentUnboundDJPrompt(name: String) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        pendingUnboundDJName = trimmedName.isEmpty ? nil : trimmedName
    }

    private func lineupDJEntries(for event: WebEvent, sortMode: LineupSortMode) -> [EventLineupDJEntry] {
        var seen = Set<String>()
        var result: [EventLineupDJEntry] = []

        for slot in event.lineupSlots.sorted(by: { $0.startTime < $1.startTime }) {
            let act = EventLineupActCodec.parse(slot: slot)
            let displayName = act.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !displayName.isEmpty else { continue }

            let key: String
            if act.type == .solo, let djID = act.performers.first?.djID, !djID.isEmpty {
                key = "dj-\(djID)"
            } else {
                key = "act-\(EventLineupActCodec.canonicalKey(for: act))"
            }
            guard !seen.contains(key) else { continue }
            seen.insert(key)
            result.append(EventLineupDJEntry(id: key, act: act))
        }

        if sortMode == .alphabetical {
            return result
                .enumerated()
                .sorted { lhs, rhs in
                    shouldOrderLineupActAlphabetically(lhs.element.act, before: rhs.element.act, lhsIndex: lhs.offset, rhsIndex: rhs.offset)
                }
                .map(\.element)
        }

        let followerByID = lineupFollowerMapByID(from: event)
        return result
            .enumerated()
            .sorted { lhs, rhs in
                shouldOrderLineupAct(
                    lhs.element.act,
                    before: rhs.element.act,
                    lhsIndex: lhs.offset,
                    rhsIndex: rhs.offset,
                    followerByID: followerByID,
                    followerByName: [:]
                )
            }
            .map(\.element)
    }

    private func lineupFollowerMapByID(from event: WebEvent) -> [String: Int] {
        var map: [String: Int] = [:]
        for slot in event.lineupSlots {
            for dj in slot.djs ?? [] {
                guard let followers = dj.soundCloudFollowers else { continue }
                map[dj.id] = max(map[dj.id] ?? 0, followers)
            }
            if let dj = slot.dj,
               let followers = dj.soundCloudFollowers {
                map[dj.id] = max(map[dj.id] ?? 0, followers)
            }
        }

        return map
    }

    private func lineupFollowers(
        for performer: EventLineupPerformer,
        followerByID: [String: Int],
        followerByName: [String: Int]
    ) -> Int? {
        if let djID = resolvedPerformerDJID(performer),
           let followers = followerByID[djID] {
            return followers
        }
        return nil
    }

    private func lineupMaxFollowers(
        for act: EventLineupResolvedAct,
        followerByID: [String: Int],
        followerByName: [String: Int]
    ) -> Int? {
        act.performers
            .compactMap { lineupFollowers(for: $0, followerByID: followerByID, followerByName: followerByName) }
            .max()
    }

    private func lineupSortName(for act: EventLineupResolvedAct) -> String {
        let raw = act.type == .solo ? (act.performers.first?.name ?? act.displayName) : act.displayName
        return normalizedPerformerNameKey(raw)
    }

    private func shouldOrderLineupAct(
        _ lhs: EventLineupResolvedAct,
        before rhs: EventLineupResolvedAct,
        lhsIndex: Int,
        rhsIndex: Int,
        followerByID: [String: Int],
        followerByName: [String: Int]
    ) -> Bool {
        let leftFollowers = lineupMaxFollowers(for: lhs, followerByID: followerByID, followerByName: followerByName)
        let rightFollowers = lineupMaxFollowers(for: rhs, followerByID: followerByID, followerByName: followerByName)

        switch (leftFollowers, rightFollowers) {
        case let (left?, right?):
            if left != right { return left > right }
        case (_?, nil):
            return true
        case (nil, _?):
            return false
        case (nil, nil):
            break
        }

        let leftName = lineupSortName(for: lhs)
        let rightName = lineupSortName(for: rhs)
        let nameCompare = leftName.localizedCaseInsensitiveCompare(rightName)
        if nameCompare != .orderedSame {
            return nameCompare == .orderedAscending
        }
        return lhsIndex < rhsIndex
    }

    private func shouldOrderLineupActAlphabetically(
        _ lhs: EventLineupResolvedAct,
        before rhs: EventLineupResolvedAct,
        lhsIndex: Int,
        rhsIndex: Int
    ) -> Bool {
        let leftName = lineupSortName(for: lhs)
        let rightName = lineupSortName(for: rhs)
        let nameCompare = leftName.localizedCaseInsensitiveCompare(rightName)
        if nameCompare != .orderedSame {
            return nameCompare == .orderedAscending
        }
        return lhsIndex < rhsIndex
    }

    private func normalizedPerformerNameKey(_ raw: String) -> String {
        normalizedDJLookupKey(raw)
    }

    @ViewBuilder
    private func lineupPerformerAvatar(_ performer: EventLineupPerformer?, size: CGFloat) -> some View {
        if let avatar = AppConfig.resolvedDJAvatarURLString(performer?.avatarUrl, size: .small),
           !avatar.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            ImageLoaderView(
                urlString: avatar,
                resizingMode: .fill
            )
            .background(
                DefaultDJAvatarPlaceholderView(size: size, backgroundColor: RaverTheme.card)
            )
            .frame(width: size, height: size)
            .clipShape(Circle())
        } else {
            DefaultDJAvatarPlaceholderView(size: size, backgroundColor: RaverTheme.card)
        }
    }

    private func eventStatusPill(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                Capsule()
                    .fill(color.opacity(0.15))
            )
    }

    private func eventInfoRow(icon: String, title: String, value: String, linkStyle: Bool = false) -> some View {
        HStack(alignment: .top, spacing: 10) {
            ZStack {
                Circle()
                    .fill((linkStyle ? RaverTheme.accent : RaverTheme.card).opacity(linkStyle ? 0.18 : 1))
                    .frame(width: 28, height: 28)
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(linkStyle ? RaverTheme.accent : RaverTheme.secondaryText)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(RaverTheme.secondaryText.opacity(0.88))
                Text(value)
                    .font(.subheadline.weight(linkStyle ? .semibold : .regular))
                    .foregroundStyle(linkStyle ? RaverTheme.accent : RaverTheme.primaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
            if linkStyle {
                Image(systemName: "arrow.up.right")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(RaverTheme.accent)
                    .padding(.top, 3)
            }
        }
    }

    private func eventBrandInfoRow(_ brand: WebEventFestivalLite) -> some View {
        Button {
            appPush(.festivalDetail(festivalID: brand.id))
        } label: {
            HStack(alignment: .center, spacing: 10) {
                eventBrandAvatar(brand)

                Text(brand.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(RaverTheme.primaryText)
                    .lineLimit(1)

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(RaverTheme.secondaryText)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func eventBrandAvatar(_ brand: WebEventFestivalLite) -> some View {
        if let resolved = AppConfig.resolvedURLString(brand.avatarUrl),
           URL(string: resolved) != nil {
            ImageLoaderView(urlString: resolved, resizingMode: .fill)
                .background(eventBrandAvatarFallback(brand))
                .frame(width: 38, height: 38)
                .clipShape(Circle())
        } else {
            eventBrandAvatarFallback(brand)
        }
    }

    private func eventBrandAvatarFallback(_ brand: WebEventFestivalLite) -> some View {
        ZStack {
            Circle()
                .fill(RaverTheme.card)
                .frame(width: 38, height: 38)
            Image(systemName: "sparkles")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(RaverTheme.accent)
        }
    }

    private func eventInfoDateText(_ date: Date, event: WebEvent) -> String {
        let deviceText = date.appLocalizedYMDText()
        guard let zone = EventTimeZoneDisplay.eventTimeZone(for: event),
              zone.identifier != TimeZone.current.identifier else {
            return deviceText
        }
        return "\(deviceText)\n\(date.appLocalizedYMDText(in: zone))"
    }

    private func eventSlotTimeRangeText(_ slot: WebEventLineupSlot, event: WebEvent) -> String {
        EventTimeZoneDisplay.slotTimeRange(slot, event: event)
    }

    private func organizerAvatarFallback(_ organizer: WebUserLite) -> some View {
        AvatarPlaceholderView(size: 32, backgroundColor: RaverTheme.card)
    }

    @ViewBuilder
    private func eventStatusLine(_ status: EventVisualStatus) -> some View {
        HStack(spacing: 8) {
            if status == .ongoing {
                OngoingStatusBars()
            } else {
                Circle()
                    .fill(status.badgeBorder.opacity(0.95))
                    .frame(width: 7, height: 7)
            }
            Text(LT("状态：\(status.title)", "Status: \(status.title)", "状態: \(status.title)"))
                .foregroundStyle(RaverTheme.secondaryText)
                .font(.subheadline)
        }
    }

    private var activeAttendanceCheckin: WebCheckin? {
        relatedEventCheckins
            .filter(\.isEventAttendanceCheckin)
            .sorted {
                if $0.attendedAt == $1.attendedAt {
                    return $0.createdAt > $1.createdAt
                }
                return $0.attendedAt > $1.attendedAt
            }
            .first
    }

    private var legacyRelatedDJCheckins: [WebCheckin] {
        relatedEventCheckins
            .filter { $0.type == "dj" && $0.eventId == eventID }
            .sorted {
                if $0.attendedAt == $1.attendedAt {
                    return $0.createdAt > $1.createdAt
                }
                return $0.attendedAt > $1.attendedAt
            }
    }

    private func load() async {
        guard !isLoading else { return }

        let hadContent = event != nil
        isLoading = true
        if hadContent {
            isRefreshing = true
        } else {
            phase = .initialLoading
        }
        defer { isLoading = false }
        defer { isRefreshing = false }

        do {
            let hasSession = await MainActor.run { appState.session != nil }
            await MainActor.run {
                isLoadingRelatedArticles = true
            }
            async let eventTask = eventReadRepository.fetchEvent(id: eventID)
            async let favoriteStatusTask: EventFavoriteStatus? = {
                guard hasSession else { return nil }
                return try? await eventCheckinRepository.fetchEventFavoriteStatus(eventID: eventID)
            }()
            async let checkinsTask: [WebCheckin] = {
                guard hasSession else { return [] }
                let page = try? await eventCheckinRepository.fetchMyCheckins(
                    page: 1,
                    limit: 200,
                    type: nil,
                    eventID: eventID,
                    djID: nil
                )
                return page?.items ?? []
            }()
            async let ratingEventsTask = ratingRepository.fetchEventRatingEvents(eventID: eventID)
            async let relatedArticlesTask = fetchRelatedNewsArticlesForEvent(eventID: eventID)

            let loadedEvent = try await eventTask
            let loadedFavoriteStatus = await favoriteStatusTask
            let loadedCheckins = await checkinsTask
            let loadedRatingEvents = (try? await ratingEventsTask) ?? []
            let loadedEventSets = (try? await eventRelatedContentRepository.fetchEventDJSets(eventName: loadedEvent.name)) ?? []
            let loadedArticles = (try? await relatedArticlesTask) ?? []

            event = loadedEvent
            relatedEventCheckins = loadedCheckins
            eventFavoriteID = loadedFavoriteStatus?.id ?? loadedEvent.favoriteId
            relatedRatingEvents = loadedRatingEvents
            relatedEventSets = loadedEventSets
            relatedArticles = loadedArticles
            isLoadingRelatedArticles = false
            phase = .success
            bannerMessage = nil

            let snapshot = makeManualCacheSnapshot(
                event: loadedEvent,
                relatedRatingEvents: loadedRatingEvents,
                relatedEventSets: loadedEventSets,
                relatedArticles: loadedArticles
            )
            await persistManualCacheSnapshot(snapshot, prefetchImages: false)
        } catch {
            let canFallback = isOfflineRecoverableError(error) || event == nil
            if canFallback, let snapshot = await EventManualCacheStore.shared.loadSnapshot(eventID: eventID) {
                applyManualCacheSnapshot(snapshot)
                phase = .success
                if isRequestTimeoutError(error) {
                    showBannerMessageAutoDismiss(LT("请求超时，已展示最新离线缓存版本。", "Request timed out. Showing latest offline cache version.", "リクエストがタイムアウトしました。最新のオフラインキャッシュを表示しています。"))
                } else {
                    showBannerMessageAutoDismiss(LT("网络较弱，已展示活动缓存数据。", "Network is weak. Showing cached event data.", "ネットワークが弱いため、イベントのキャッシュデータを表示しています。"))
                }
            } else if hadContent {
                isLoadingRelatedArticles = false
                showBannerMessageAutoDismiss(error.userFacingMessage ?? LT("活动详情更新失败，请稍后重试", "Failed to refresh event details. Please try again later.", "イベント詳細を更新できませんでした。時間をおいて再試行してください。"))
                phase = .success
            } else {
                isLoadingRelatedArticles = false
                let message = error.userFacingMessage ?? LT("活动详情加载失败，请稍后重试", "Failed to load event details. Please try again later.", "イベント詳細を読み込めませんでした。時間をおいて再試行してください。")
                phase = isOfflineRecoverableError(error)
                    ? .offline(message: message)
                    : .failure(message: message)
            }
        }
    }

    private func fetchRelatedNewsArticlesForEvent(eventID: String) async throws -> [DiscoverNewsArticle] {
        try await newsRepository.fetchArticlesBoundToEvent(eventID: eventID, maxPages: 8)
    }

    private func reloadEventRatings() async {
        relatedRatingEvents = (try? await ratingRepository.fetchEventRatingEvents(eventID: eventID)) ?? []
        await persistCurrentManualCacheSnapshotIfPossible()
    }

    private func reloadEventSets() async {
        guard let event else {
            relatedEventSets = []
            return
        }
        relatedEventSets = (try? await eventRelatedContentRepository.fetchEventDJSets(eventName: event.name)) ?? []
        await persistCurrentManualCacheSnapshotIfPossible()
    }

    @MainActor
    private func refreshManualCacheState() async {
        try? await EventManualCacheStore.shared.clearExpiredSnapshots()
        manualCachedAt = await EventManualCacheStore.shared.loadSnapshot(eventID: eventID)?.cachedAt
    }

    @MainActor
    private func cacheEventManually() async {
        guard !isCachingManualSnapshot else { return }

        isCachingManualSnapshot = true
        defer { isCachingManualSnapshot = false }

        do {
            let eventForCache = try await resolveEventForManualCache()
            async let ratingsTask = ratingRepository.fetchEventRatingEvents(eventID: eventID)
            async let setsTask = eventRelatedContentRepository.fetchEventDJSets(eventName: eventForCache.name)
            async let articlesTask = fetchRelatedNewsArticlesForEvent(eventID: eventID)

            let snapshot = EventManualCacheSnapshot(
                eventID: eventID,
                event: eventForCache,
                relatedRatingEvents: (try? await ratingsTask) ?? relatedRatingEvents,
                relatedEventSets: (try? await setsTask) ?? relatedEventSets,
                relatedArticles: ((try? await articlesTask) ?? relatedArticles).map(CachedDiscoverNewsArticle.init),
                cachedAt: Date()
            )

            await persistManualCacheSnapshot(snapshot, prefetchImages: true)
            applyManualCacheSnapshot(snapshot)
            errorMessage = LT("活动已缓存，弱网环境也可查看。", "Event cached. You can view it in weak-network conditions.", "イベントをキャッシュしました。弱いネットワークでも確認できます。")
        } catch {
            errorMessage = LT("缓存失败，请稍后重试。", "Caching failed. Please try again later.", "キャッシュに失敗しました。時間をおいて再試行してください。")
        }
    }

    @MainActor
    private func applyManualCacheSnapshot(_ snapshot: EventManualCacheSnapshot) {
        event = snapshot.event
        relatedRatingEvents = snapshot.relatedRatingEvents
        relatedEventSets = snapshot.relatedEventSets
        relatedArticles = snapshot.relatedNewsArticles
        isLoadingRelatedArticles = false
        manualCachedAt = snapshot.cachedAt
    }

    @MainActor
    private func resolveEventForManualCache() async throws -> WebEvent {
        if let latest = try? await eventReadRepository.fetchEvent(id: eventID) {
            return latest
        }
        if let event {
            return event
        }
        throw ServiceError.message(LT("活动详情加载失败，请稍后重试。", "Failed to load event details. Please try again later.", "イベント詳細を読み込めませんでした。時間をおいて再試行してください。"))
    }

    private func prefetchManualCacheImages(from snapshot: EventManualCacheSnapshot) {
        let event = snapshot.event
        let rawURLs = [event.coverAssetURL]
            + event.lineupAssetURLs
            + event.timetableAssetURLs
            + snapshot.relatedEventSets.compactMap(\.thumbnailUrl)
            + snapshot.relatedArticles.compactMap(\.coverImageURL)

        let urls = rawURLs
            .compactMap(AppConfig.resolvedURLString)
            .compactMap(URL.init(string:))

        guard !urls.isEmpty else { return }
        SDWebImagePrefetcher.shared.prefetchURLs(urls)
    }

    private func makeManualCacheSnapshot(
        event: WebEvent,
        relatedRatingEvents: [WebRatingEvent],
        relatedEventSets: [WebDJSet],
        relatedArticles: [DiscoverNewsArticle]
    ) -> EventManualCacheSnapshot {
        EventManualCacheSnapshot(
            eventID: event.id,
            event: event,
            relatedRatingEvents: relatedRatingEvents,
            relatedEventSets: relatedEventSets,
            relatedArticles: relatedArticles.map(CachedDiscoverNewsArticle.init),
            cachedAt: Date()
        )
    }

    @MainActor
    private func persistManualCacheSnapshot(_ snapshot: EventManualCacheSnapshot, prefetchImages: Bool) async {
        await EventManualCacheStore.shared.saveSnapshot(snapshot)
        manualCachedAt = snapshot.cachedAt
        if prefetchImages {
            prefetchManualCacheImages(from: snapshot)
        }
    }

    @MainActor
    private func persistCurrentManualCacheSnapshotIfPossible() async {
        guard let event else { return }
        let snapshot = makeManualCacheSnapshot(
            event: event,
            relatedRatingEvents: relatedRatingEvents,
            relatedEventSets: relatedEventSets,
            relatedArticles: relatedArticles
        )
        await persistManualCacheSnapshot(snapshot, prefetchImages: false)
    }

    private func isRequestTimeoutError(_ error: Error) -> Bool {
        if let urlError = error as? URLError {
            return urlError.code == .timedOut
        }
        let nsError = error as NSError
        return nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorTimedOut
    }

    private func isOfflineRecoverableError(_ error: Error) -> Bool {
        if let urlError = error as? URLError {
            switch urlError.code {
            case .timedOut,
                 .notConnectedToInternet,
                 .networkConnectionLost,
                 .cannotFindHost,
                 .cannotConnectToHost,
                 .dnsLookupFailed,
                 .internationalRoamingOff,
                 .callIsActive,
                 .dataNotAllowed:
                return true
            default:
                break
            }
        }

        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain {
            let recoverableCodes: Set<Int> = [
                NSURLErrorTimedOut,
                NSURLErrorNotConnectedToInternet,
                NSURLErrorNetworkConnectionLost,
                NSURLErrorCannotFindHost,
                NSURLErrorCannotConnectToHost,
                NSURLErrorDNSLookupFailed,
            ]
            if recoverableCodes.contains(nsError.code) {
                return true
            }
        }

        return false
    }

    @MainActor
    private func beginEventCheckinFlow(for event: WebEvent) async {
        let dayOptions = eventCheckinDayOptions(for: event)
        guard !dayOptions.isEmpty else { return }

        guard !isPreparingEventCheckinSheet else { return }
        isPreparingEventCheckinSheet = true
        defer { isPreparingEventCheckinSheet = false }

        do {
            let page = try await eventCheckinRepository.fetchMyCheckins(
                page: 1,
                limit: 200,
                type: nil,
                eventID: eventID,
                djID: nil
            )
            relatedEventCheckins = page.items
        } catch {
            if relatedEventCheckins.isEmpty {
                errorMessage = LT("打卡记录加载失败，请稍后重试", "Failed to load check-in records. Please try again later.", "チェックイン記録を読み込めませんでした。時間をおいて再試行してください。")
                return
            }
        }

        if let activeAttendanceCheckin {
            let selections = preselectedDaySelections(for: activeAttendanceCheckin, in: event)
            selectedEventCheckinDayIDs = Set(selections.map(\.dayID))
            selectedEventCheckinDJIDsByDayID = Dictionary(
                uniqueKeysWithValues: selections.map { selection in
                    (selection.dayID, selectedCheckinOptionIDs(from: selection))
                }
            )
        } else {
            selectedEventCheckinDayIDs = []
            selectedEventCheckinDJIDsByDayID = [:]
        }

        showEventCheckinSheet = true
    }

    private func eventCheckinDayOptions(for event: WebEvent) -> [EventCheckinDayOption] {
        let calendar = Calendar.current
        let usesWeekMode = EventWeekScheduleMode.isEnabled(in: event.description)
        let dayIndexes: [Int] = {
            let lineupDayIndexes = Array(
                Set(event.lineupSlots.map { slot in
                    EventLogicalDayResolver.dayIndex(
                        for: slot,
                        eventStartDate: event.startDate,
                        dayRolloverHour: event.dayRolloverHour
                    )
                })
            ).sorted()
            if !lineupDayIndexes.isEmpty {
                return lineupDayIndexes
            }

            let startDay = calendar.startOfDay(for: event.startDate)
            let normalizedEnd = max(event.endDate, event.startDate)
            let endDay = calendar.startOfDay(for: normalizedEnd)
            let span = max((calendar.dateComponents([.day], from: startDay, to: endDay).day ?? 0) + 1, 1)
            return Array(1...span)
        }()

        return dayIndexes.map { dayIndex in
            let dayDate = EventLogicalDayResolver.dayDate(for: dayIndex, anchorDate: event.startDate)
            let slotsOnDay = event.lineupSlots.filter { slot in
                EventLogicalDayResolver.dayIndex(
                    for: slot,
                    eventStartDate: event.startDate,
                    dayRolloverHour: event.dayRolloverHour
                ) == dayIndex
            }
            let fallback = calendar.date(bySettingHour: 20, minute: 0, second: 0, of: dayDate) ?? dayDate
            let baseAttendedAt = slotsOnDay.map(\.startTime).min() ?? (dayIndex == 1 ? event.startDate : fallback)
            let attendedAt = min(baseAttendedAt, Date())
            let weekDay = usesWeekMode ? EventWeekScheduleMode.weekDayIndex(for: dayDate, anchorDate: event.startDate) : nil

            return EventCheckinDayOption(
                id: Self.eventCheckinDayKey(for: dayDate),
                dayIndex: dayIndex,
                dayDate: dayDate,
                attendedAt: attendedAt,
                weekIndex: weekDay?.week,
                dayInWeek: weekDay?.day
            )
        }
    }

    private func eventCheckinDJOptions(for event: WebEvent, selectedDayIDs: Set<String>) -> [EventCheckinDJOption] {
        guard !selectedDayIDs.isEmpty else { return [] }

        var firstStartByOptionID: [String: Date] = [:]
        var optionByOptionID: [String: EventCheckinDJOption] = [:]

        for slot in event.lineupSlots.sorted(by: { $0.startTime < $1.startTime }) {
            let dayIndex = EventLogicalDayResolver.dayIndex(
                for: slot,
                eventStartDate: event.startDate,
                dayRolloverHour: event.dayRolloverHour
            )
            let key = Self.eventCheckinDayKey(
                for: EventLogicalDayResolver.dayDate(for: dayIndex, anchorDate: event.startDate)
            )
            guard selectedDayIDs.contains(key) else { continue }

            let act = EventLineupActCodec.parse(slot: slot)
            let displayName = act.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !displayName.isEmpty else { continue }

            let optionID: String = {
                if act.type == .solo,
                   let performer = act.performers.first,
                   let djID = performer.djID,
                   !djID.isEmpty {
                    return djID
                }
                let canonical = EventLineupActCodec.canonicalKey(for: act)
                if act.type == .solo {
                    return "solo-\(key)-\(canonical)"
                }
                return "act-\(key)-\(canonical)"
            }()

            let shouldReplace: Bool
            if let existingStart = firstStartByOptionID[optionID] {
                shouldReplace = slot.startTime < existingStart
            } else {
                shouldReplace = true
            }

            if shouldReplace {
                firstStartByOptionID[optionID] = slot.startTime
                optionByOptionID[optionID] = EventCheckinDJOption(
                    id: optionID,
                    djID: optionID,
                    name: displayName,
                    avatarUrl: act.type == .solo ? act.performers.first?.avatarUrl : nil,
                    actType: act.type,
                    performers: act.performers
                )
            }
        }

        return optionByOptionID.values.sorted {
            let lhsDate = firstStartByOptionID[$0.djID] ?? .distantFuture
            let rhsDate = firstStartByOptionID[$1.djID] ?? .distantFuture
            return lhsDate < rhsDate
        }
    }

    private func submitEventCheckinSelections(selectedDJIDsByDayID: [String: Set<String>]) async throws {
        guard let event else { return }
        let selectedDays = eventCheckinDayOptions(for: event)
            .filter { selectedEventCheckinDayIDs.contains($0.id) }
            .sorted { $0.dayIndex < $1.dayIndex }

        guard !selectedDays.isEmpty else {
            throw ServiceError.message(LT("请至少选择一个参加日", "Please select at least one attended day.", "参加日を少なくとも1つ選択してください。"))
        }

        let payloads = selectedDays.map { day in
            makeAttendanceSelectionPayload(
                for: event,
                day: day,
                selectedDJIDs: selectedDJIDsByDayID[day.id] ?? []
            )
        }
        guard let note = WebCheckin.makeEventAttendanceNote(selections: payloads) else {
            throw ServiceError.message(LT("打卡信息生成失败，请重试", "Failed to generate check-in payload. Please try again.", "チェックイン情報を生成できませんでした。もう一度お試しください。"))
        }
        let attendedAt = selectedDays.map(\.attendedAt).max() ?? Date()

        let primaryCheckin: WebCheckin
        let didUpdateExisting: Bool
        if let activeAttendanceCheckin {
            do {
                primaryCheckin = try await eventCheckinRepository.updateCheckin(
                    id: activeAttendanceCheckin.id,
                    input: UpdateCheckinInput(
                        eventId: eventID,
                        djId: nil,
                        note: note,
                        rating: nil,
                        attendedAt: attendedAt,
                        visibility: "private",
                        selections: makeCheckinSelectionInputs(from: payloads)
                    )
                )
                didUpdateExisting = true
            } catch {
                if isInactiveCheckinError(error) {
                    try await refreshRelatedEventCheckins()
                    primaryCheckin = try await createEventAttendanceCheckin(
                        note: note,
                        attendedAt: attendedAt,
                        payloads: payloads
                    )
                    didUpdateExisting = false
                } else {
                    throw error
                }
            }
        } else {
            primaryCheckin = try await createEventAttendanceCheckin(
                note: note,
                attendedAt: attendedAt,
                payloads: payloads
            )
            didUpdateExisting = false
        }

        await cleanupLegacyEventCheckins(keeping: primaryCheckin.id)
        try await refreshRelatedEventCheckins()
        relatedEventCheckins = ([primaryCheckin] + relatedEventCheckins.filter { $0.id != primaryCheckin.id })
            .filter { $0.id == primaryCheckin.id || !shouldCleanupEventCheckin($0, keeping: primaryCheckin.id) }

        showCheckinOperationSuccessBanner(
            message: didUpdateExisting ? LT("打卡信息已更新", "Check-in updated.", "チェックイン情報を更新しました。") : LT("活动打卡成功", "Event check-in successful.", "イベントチェックインに成功しました。")
        )
    }

    private func createEventAttendanceCheckin(
        note: String,
        attendedAt: Date,
        payloads: [EventAttendanceDaySelectionPayload]
    ) async throws -> WebCheckin {
        try await eventCheckinRepository.createCheckin(
            input: CreateCheckinInput(
                type: "event",
                eventId: eventID,
                djId: nil,
                note: note,
                rating: nil,
                attendedAt: attendedAt,
                visibility: "private",
                selections: makeCheckinSelectionInputs(from: payloads)
            )
        )
    }

    private func cancelEventCheckin() async throws {
        guard let activeAttendanceCheckin else {
            try await refreshRelatedEventCheckins()
            return
        }

        do {
            try await eventCheckinRepository.deleteCheckin(id: activeAttendanceCheckin.id)
        } catch {
            guard isInactiveCheckinError(error) else { throw error }
        }

        await cleanupLegacyEventCheckins(keeping: activeAttendanceCheckin.id)
        try await refreshRelatedEventCheckins()
        relatedEventCheckins.removeAll { checkin in
            checkin.id == activeAttendanceCheckin.id || shouldCleanupEventCheckin(checkin, keeping: nil)
        }
        selectedEventCheckinDayIDs = []
        selectedEventCheckinDJIDsByDayID = [:]
        showCheckinOperationSuccessBanner(message: LT("已取消活动打卡", "Event check-in canceled.", "イベントチェックインを取消しました。"))
    }

    private func refreshRelatedEventCheckins() async throws {
        let page = try await eventCheckinRepository.fetchMyCheckins(
            page: 1,
            limit: 200,
            type: nil,
            eventID: eventID,
            djID: nil
        )
        relatedEventCheckins = page.items
    }

    @MainActor
    private func toggleMarkedEvent(_ event: WebEvent) async {
        guard appState.session != nil else {
            errorMessage = LT("请先登录再收藏活动", "Please log in before saving events.", "イベントを保存するにはログインしてください。")
            return
        }
        guard !isTogglingMarkedEvent else { return }

        isTogglingMarkedEvent = true
        defer { isTogglingMarkedEvent = false }

        do {
            if eventFavoriteID != nil {
                try await eventCheckinRepository.unfavoriteEvent(eventID: event.id)
                eventFavoriteID = nil
                showEventFavoriteSuccessBanner(message: LT("已取消收藏活动", "Event removed from favorites.", "イベントのお気に入りを解除しました。"))
            } else {
                let favorite = try await eventCheckinRepository.favoriteEvent(eventID: event.id)
                eventFavoriteID = favorite.id ?? event.id
                showEventFavoriteSuccessBanner(message: LT("已收藏活动", "Event added to favorites.", "イベントをお気に入りに追加しました。"))
            }

            NotificationCenter.default.post(name: .discoverEventDidSave, object: event.id)
        } catch {
            errorMessage = error.userFacingMessage ?? LT("收藏活动失败，请稍后重试", "Failed to update favorite. Please try again later.", "お気に入りを更新できませんでした。時間をおいて再試行してください。")
        }
    }

    private func isInactiveCheckinError(_ error: Error) -> Bool {
        let message = (error.userFacingMessage ?? error.localizedDescription).lowercased()
        return message.contains("checkin is no longer active")
            || message.contains("check-in is no longer active")
            || message.contains("no longer active")
    }

    private func showCheckinOperationSuccessBanner(message: String) {
        OperationBannerCenter.shared.success(
            message,
            action: .appRoute(
                .profile(.myCheckins(targetUserID: nil, title: "", ownerDisplayName: nil)),
                title: LT("查看我的打卡", "View My Check-ins", "自分のチェックインを見る")
            )
        )
    }

    private func showEventFavoriteSuccessBanner(message: String) {
        OperationBannerCenter.shared.success(message)
    }

    private func preselectedDaySelections(for checkin: WebCheckin, in event: WebEvent) -> [EventAttendanceDaySelectionPayload] {
        let existingSelections = checkin.eventAttendanceSelections.sorted { $0.dayIndex < $1.dayIndex }
        if !existingSelections.isEmpty {
            return existingSelections
        }

        guard let selectedDayID = dayID(for: checkin.attendedAt, in: event),
              let selectedDay = eventCheckinDayOptions(for: event).first(where: { $0.id == selectedDayID }) else {
            return []
        }

        let calendar = Calendar.current
        let selectedDJIDs = Set<String>(
            legacyRelatedDJCheckins.compactMap { item in
                guard let djID = item.djId, !djID.isEmpty else { return nil }
                let itemDay = dayID(for: item.attendedAt, in: event)
                guard itemDay == selectedDayID || calendar.isDate(item.attendedAt, inSameDayAs: checkin.attendedAt) else {
                    return nil
                }
                return djID
            }
        )
        return [makeAttendanceSelectionPayload(for: event, day: selectedDay, selectedDJIDs: selectedDJIDs)]
    }

    private func selectedCheckinOptionIDs(from selection: EventAttendanceDaySelectionPayload) -> Set<String> {
        Set(
            selection.djSelections.compactMap { item in
                let actGroupID = item.actGroupId?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                if !actGroupID.isEmpty {
                    return actGroupID
                }
                let itemID = item.id.trimmingCharacters(in: .whitespacesAndNewlines)
                return itemID.isEmpty ? nil : itemID
            }
        )
    }

    private func dayID(for date: Date, in event: WebEvent) -> String? {
        let options = eventCheckinDayOptions(for: event)
        guard !options.isEmpty else { return nil }

        let targetDayIndex = EventLogicalDayResolver.dayIndex(
            for: date,
            eventStartDate: event.startDate,
            dayRolloverHour: event.dayRolloverHour
        )
        if let exact = options.first(where: { $0.dayIndex == targetDayIndex }) {
            return exact.id
        }
        return options.first { Calendar.current.isDate($0.dayDate, inSameDayAs: date) }?.id
    }

    private func makeAttendanceSelectionPayload(
        for event: WebEvent,
        day: EventCheckinDayOption,
        selectedDJIDs: Set<String>
    ) -> EventAttendanceDaySelectionPayload {
        var snapshots: [EventAttendanceDJSelection] = []
        for option in eventCheckinDJOptions(for: event, selectedDayIDs: [day.id]) where selectedDJIDs.contains(option.djID) {
            for (index, performer) in option.performers.enumerated() {
                let djID = resolvedPerformerDJID(performer)
                let selectionID = djID ?? "\(option.id)-performer-\(index)"
                snapshots.append(
                    EventAttendanceDJSelection(
                        id: selectionID,
                        djId: djID,
                        name: performer.name,
                        avatarUrl: performer.avatarUrl,
                        country: nil,
                        actGroupId: option.id,
                        actType: option.actType.rawValue,
                        performerIndex: index
                    )
                )
            }
        }
        snapshots = snapshots
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }

        return EventAttendanceDaySelectionPayload(
            dayID: day.id,
            dayIndex: day.dayIndex,
            djSelections: snapshots
        )
    }

    private func makeCheckinSelectionInputs(
        from payloads: [EventAttendanceDaySelectionPayload]
    ) -> [CheckinSelectionInput] {
        payloads.map { payload in
            CheckinSelectionInput(
                dayId: payload.dayID,
                dayIndex: payload.dayIndex,
                djs: payload.djSelections.compactMap { selection in
                    let djID = selection.djId?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                    let displayName = selection.name.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !displayName.isEmpty else { return nil }
                    return CheckinSelectionDJInput(
                        djId: djID.isEmpty ? nil : djID,
                        displayName: displayName,
                        actGroupId: selection.actGroupId ?? (djID.isEmpty ? selection.id : djID),
                        actType: selection.actType ?? "solo",
                        performerIndex: selection.performerIndex ?? 0
                    )
                }
            )
        }
    }

    private func cleanupLegacyEventCheckins(keeping keptID: String?) async {
        let cleanupTargets = relatedEventCheckins.filter { shouldCleanupEventCheckin($0, keeping: keptID) }
        for item in cleanupTargets {
            try? await eventCheckinRepository.deleteCheckin(id: item.id)
        }
    }

    private func shouldCleanupEventCheckin(_ checkin: WebCheckin, keeping keptID: String?) -> Bool {
        if let keptID, checkin.id == keptID {
            return false
        }
        if checkin.type == "dj" && checkin.eventId == eventID {
            return true
        }
        return checkin.isEventAttendanceCheckin
    }

    private static func eventCheckinDayKey(for date: Date) -> String {
        eventCheckinDayFormatter.string(from: date)
    }

    private static let eventCheckinDayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private func deleteEvent() async {
        do {
            try await eventCommandRepository.deleteEvent(id: eventID)
            errorMessage = LT("活动已删除，请返回列表刷新", "Event deleted. Please return to the list and refresh.", "イベントは削除されました。リストに戻って更新してください。")
        } catch {
            errorMessage = error.userFacingMessage
        }
    }
}

private struct ActivityShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    let activities: [UIActivity]? = nil
    let completion: UIActivityViewController.CompletionWithItemsHandler?

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: activities)
        controller.completionWithItemsHandler = completion
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

private enum EventLogicalDayResolver {
    static func normalizeDayRolloverHour(_ raw: Int?) -> Int {
        guard let raw, (0...23).contains(raw) else { return 6 }
        return raw
    }

    static func dayDate(for dayIndex: Int, anchorDate: Date) -> Date {
        let calendar = Calendar.current
        let anchorDay = calendar.startOfDay(for: anchorDate)
        guard dayIndex > 1 else { return anchorDay }
        return calendar.date(byAdding: .day, value: dayIndex - 1, to: anchorDay) ?? anchorDay
    }

    static func dayIndex(
        for date: Date,
        eventStartDate: Date,
        dayRolloverHour: Int?
    ) -> Int {
        let calendar = Calendar.current
        let rolloverHour = normalizeDayRolloverHour(dayRolloverHour)
        let anchorDay = calendar.startOfDay(for: eventStartDate)
        let targetDay = calendar.startOfDay(for: date)
        var dayOffset = calendar.dateComponents([.day], from: anchorDay, to: targetDay).day ?? 0
        if dayOffset > 0 && calendar.component(.hour, from: date) < rolloverHour {
            dayOffset -= 1
        }
        return max(1, dayOffset + 1)
    }

    static func dayIndex(
        for slot: WebEventLineupSlot,
        eventStartDate: Date,
        dayRolloverHour: Int?
    ) -> Int {
        if let explicitDayIndex = slot.festivalDayIndex, explicitDayIndex > 0 {
            return explicitDayIndex
        }
        return dayIndex(for: slot.startTime, eventStartDate: eventStartDate, dayRolloverHour: dayRolloverHour)
    }
}

private struct EventScheduleDay: Identifiable, Hashable {
    let id: String
    let index: Int
    let weekIndex: Int?
    let dayInWeek: Int?
    let date: Date
    let slots: [WebEventLineupSlot]

    var title: String {
        if let weekIndex, let dayInWeek {
            return EventWeekScheduleMode.weekDayTitle(week: weekIndex, day: dayInWeek)
        }
        return "Day\(index)"
    }

    var subtitle: String { "\(title) · \(date.appLocalizedYMDText())" }

    static func build(
        from slots: [WebEventLineupSlot],
        anchorDate: Date,
        useWeekMode: Bool,
        dayRolloverHour: Int? = nil
    ) -> [EventScheduleDay] {
        guard !slots.isEmpty else { return [] }

        var grouped: [Int: [WebEventLineupSlot]] = [:]
        for slot in slots {
            let dayIndex = EventLogicalDayResolver.dayIndex(
                for: slot,
                eventStartDate: anchorDate,
                dayRolloverHour: dayRolloverHour
            )
            grouped[dayIndex, default: []].append(slot)
        }

        return grouped
            .keys
            .sorted()
            .map { dayIndex in
                let dayDate = EventLogicalDayResolver.dayDate(for: dayIndex, anchorDate: anchorDate)
                let items = (grouped[dayIndex] ?? [])
                    .sorted {
                        if $0.startTime == $1.startTime {
                            return $0.sortOrder < $1.sortOrder
                        }
                        return $0.startTime < $1.startTime
                    }
                let weekDay = useWeekMode
                    ? EventWeekScheduleMode.weekDayIndex(for: dayDate, anchorDate: anchorDate)
                    : nil
                return EventScheduleDay(
                    id: Self.dayKey(for: dayDate),
                    index: dayIndex,
                    weekIndex: weekDay?.week,
                    dayInWeek: weekDay?.day,
                    date: dayDate,
                    slots: items
                )
            }
    }

    private static func dayKey(for date: Date) -> String {
        dayKeyFormatter.string(from: date)
    }

    private static let dayKeyFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

}

private struct EventTimelineCardFrame: Identifiable {
    let id: String
    let slot: WebEventLineupSlot
    let top: CGFloat
    let height: CGFloat
}

private enum EventScheduleTypography {
    static func heavy(_ size: CGFloat) -> Font {
        font(primary: "AvenirNext-Bold", fallbackWeight: .bold, size: size)
    }

    static func semibold(_ size: CGFloat) -> Font {
        font(primary: "AvenirNext-DemiBold", fallbackWeight: .semibold, size: size)
    }

    static func medium(_ size: CGFloat) -> Font {
        font(primary: "AvenirNext-Medium", fallbackWeight: .medium, size: size)
    }

    private static func font(primary: String, fallbackWeight: Font.Weight, size: CGFloat) -> Font {
        if UIFont(name: primary, size: size) != nil {
            return .custom(primary, size: size)
        }
        return .system(size: size, weight: fallbackWeight, design: .rounded)
    }
}

private struct EventTimelineLayout {
    static let axisWidth: CGFloat = 54
    static let stageHeaderHeight: CGFloat = 74
    static let stageHeaderFadeHeight: CGFloat = 20
    static let stageGap: CGFloat = 4
    static let timelineTopInset: CGFloat = 50
    static let timelineBottomInset: CGFloat = 40
    static let maxVisibleStageCount = 5
    static let minStageWidth: CGFloat = 92
    static let pixelsPerHour: CGFloat = 75

    let stageNames: [String]
    let slotsByStage: [String: [WebEventLineupSlot]]
    let stageColorByName: [String: Color]
    let stageWidth: CGFloat
    let stageViewportWidth: CGFloat
    let stageContentWidth: CGFloat
    let requiresHorizontalScroll: Bool
    let rangeStart: Date
    let rangeEnd: Date
    let timelineSpanHeight: CGFloat
    let bodyHeight: CGFloat
    let tickDates: [Date]

    init(
        slots: [WebEventLineupSlot],
        stageOrder: [String] = [],
        availableWidth: CGFloat,
        maxVisibleStages: Int = Self.maxVisibleStageCount
    ) {
        let normalizedSlots = slots.sorted {
            if $0.startTime == $1.startTime {
                return $0.sortOrder < $1.sortOrder
            }
            return $0.startTime < $1.startTime
        }
        let grouped = Dictionary(grouping: normalizedSlots) { slot in
            let trimmed = slot.stageName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return trimmed.isEmpty ? "MAIN STAGE" : trimmed
        }
        var groupedStageByKey: [String: String] = [:]
        for stage in grouped.keys {
            groupedStageByKey[stage.localizedLowercase] = stage
        }
        let slotsOrderedBySort = normalizedSlots.sorted {
            if $0.sortOrder == $1.sortOrder {
                return $0.startTime < $1.startTime
            }
            return $0.sortOrder < $1.sortOrder
        }
        let configuredStageOrder = Self.normalizedStageOrder(stageOrder)
        var orderedStages: [String] = []
        var seenStages = Set<String>()
        for stage in configuredStageOrder {
            guard let canonicalStage = groupedStageByKey[stage.localizedLowercase] else { continue }
            if seenStages.insert(canonicalStage).inserted {
                orderedStages.append(canonicalStage)
            }
        }
        for slot in slotsOrderedBySort {
            let trimmed = slot.stageName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let stage = trimmed.isEmpty ? "MAIN STAGE" : trimmed
            if seenStages.insert(stage).inserted {
                orderedStages.append(stage)
            }
        }
        for stage in grouped.keys where !seenStages.contains(stage) {
            orderedStages.append(stage)
        }

        var colorMap: [String: Color] = [:]
        for (idx, stage) in orderedStages.enumerated() {
            colorMap[stage] = Self.palette[idx % Self.palette.count]
        }

        let bounds = Self.timeBounds(for: normalizedSlots)
        rangeStart = bounds.start
        rangeEnd = bounds.end
        let totalHours = max(bounds.end.timeIntervalSince(bounds.start) / 3600, 1)
        timelineSpanHeight = max(760, CGFloat(totalHours) * Self.pixelsPerHour)
        bodyHeight = Self.timelineTopInset + timelineSpanHeight + Self.timelineBottomInset
        tickDates = Self.hourTicks(from: bounds.start, to: bounds.end)

        let stageCount = max(1, orderedStages.count)
        let stageViewport = max(availableWidth - Self.axisWidth, Self.minStageWidth)
        let resolvedVisibleCap = max(1, maxVisibleStages)
        let visibleCount = min(resolvedVisibleCap, stageCount)
        let visibleGapTotal = CGFloat(max(visibleCount - 1, 0)) * Self.stageGap
        let computedStageWidth = max((stageViewport - visibleGapTotal) / CGFloat(visibleCount), Self.minStageWidth)
        stageWidth = computedStageWidth
        stageViewportWidth = stageViewport
        stageContentWidth = CGFloat(stageCount) * computedStageWidth + CGFloat(max(stageCount - 1, 0)) * Self.stageGap
        requiresHorizontalScroll = stageCount > visibleCount

        stageNames = orderedStages
        slotsByStage = grouped
        stageColorByName = colorMap
    }

    func yPosition(for date: Date) -> CGFloat {
        let total = max(rangeEnd.timeIntervalSince(rangeStart), 1)
        let clamped = min(max(date.timeIntervalSince(rangeStart), 0), total)
        let progress = clamped / total
        return Self.timelineTopInset + CGFloat(progress) * timelineSpanHeight
    }

    func color(for stageName: String) -> Color {
        stageColorByName[stageName] ?? Self.palette[0]
    }

    static func estimatedHeight(for slots: [WebEventLineupSlot]) -> CGFloat {
        let bounds = timeBounds(for: slots)
        let totalHours = max(bounds.end.timeIntervalSince(bounds.start) / 3600, 1)
        let span = max(760, CGFloat(totalHours) * pixelsPerHour)
        return stageHeaderHeight + timelineTopInset + span + timelineBottomInset
    }

    static func stageCount(for slots: [WebEventLineupSlot]) -> Int {
        let names = Set(slots.map { slot -> String in
            let trimmed = slot.stageName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return trimmed.isEmpty ? "MAIN STAGE" : trimmed
        })
        return max(1, names.count)
    }

    private static func normalizedStageOrder(_ stageOrder: [String]) -> [String] {
        var result: [String] = []
        var seen = Set<String>()
        for raw in stageOrder {
            let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { continue }
            let key = text.localizedLowercase
            guard seen.insert(key).inserted else { continue }
            result.append(text)
        }
        return result
    }

    private static func timeBounds(for slots: [WebEventLineupSlot]) -> (start: Date, end: Date) {
        let reference = slots.map(\.startTime).min() ?? Date()
        let earliest = slots.map(\.startTime).min() ?? reference
        let latest = slots.map(\.endTime).max() ?? earliest.addingTimeInterval(3600)
        let roundedStart = floorToHour(earliest)
        var roundedEnd = ceilToHour(latest)
        if roundedEnd <= roundedStart {
            roundedEnd = roundedStart.addingTimeInterval(3600)
        }
        return (roundedStart, roundedEnd)
    }

    private static func hourTicks(from start: Date, to end: Date) -> [Date] {
        var result: [Date] = []
        var cursor = start
        while cursor <= end {
            result.append(cursor)
            guard let next = Calendar.current.date(byAdding: .hour, value: 1, to: cursor) else { break }
            cursor = next
        }
        if result.isEmpty {
            result = [start, end]
        }
        return result
    }

    private static func floorToHour(_ date: Date) -> Date {
        let calendar = Calendar.current
        let parts = calendar.dateComponents([.year, .month, .day, .hour], from: date)
        return calendar.date(from: parts) ?? date
    }

    private static func ceilToHour(_ date: Date) -> Date {
        let start = floorToHour(date)
        if start == date { return start }
        return Calendar.current.date(byAdding: .hour, value: 1, to: start) ?? date
    }

    private static let palette: [Color] = [
        Color(red: 0.97, green: 0.54, blue: 0.89),
        Color(red: 0.50, green: 0.87, blue: 0.98),
        Color(red: 0.54, green: 0.95, blue: 0.62),
        Color(red: 0.99, green: 0.73, blue: 0.42),
        Color(red: 0.90, green: 0.96, blue: 0.50),
        Color(red: 0.56, green: 0.67, blue: 0.99),
        Color(red: 0.98, green: 0.57, blue: 0.63),
        Color(red: 0.93, green: 0.56, blue: 0.79),
        Color(red: 0.56, green: 0.86, blue: 0.94)
    ]
}

private struct EventTimelineBoardView: View {
    @Environment(\.colorScheme) private var colorScheme

    let event: WebEvent
    let day: EventScheduleDay
    let selectedSlotIDs: Set<String>
    let selectable: Bool
    let onToggleSlot: ((WebEventLineupSlot) -> Void)?
    var onSelectSlot: ((WebEventLineupSlot) -> Void)? = nil
    var maxVisibleStages: Int = EventTimelineLayout.maxVisibleStageCount
    var stickyTopInset: CGFloat = 0

    private var boardHeight: CGFloat {
        EventTimelineLayout.estimatedHeight(for: day.slots)
    }

    private var isDarkMode: Bool {
        colorScheme == .dark
    }

    private var boardGradientColors: [Color] {
        if isDarkMode {
            return [
                Color(red: 0.09, green: 0.10, blue: 0.14),
                Color(red: 0.06, green: 0.06, blue: 0.09)
            ]
        }
        return [
            Color.white,
            Color(red: 0.94, green: 0.94, blue: 0.985)
        ]
    }

    private var boardStrokeColor: Color {
        isDarkMode ? Color.white.opacity(0.12) : Color.black.opacity(0.08)
    }

    private var headerBackdropColor: Color {
        isDarkMode ? Color(red: 0.08, green: 0.09, blue: 0.13) : Color(red: 0.965, green: 0.965, blue: 0.99)
    }

    private var axisHeaderTextColor: Color {
        isDarkMode ? Color.white.opacity(0.72) : Color.black.opacity(0.54)
    }

    private var axisTextColor: Color {
        isDarkMode ? Color.white.opacity(0.92) : Color.black.opacity(0.62)
    }

    private var stageHeaderStrokeColor: Color {
        isDarkMode ? Color.white.opacity(0.36) : Color.white.opacity(0.72)
    }

    private var stageHeaderTextColor: Color {
        Color.black.opacity(0.78)
    }

    private var columnFillColor: Color {
        isDarkMode ? Color.white.opacity(0.04) : Color.black.opacity(0.035)
    }

    private var gridLineColor: Color {
        isDarkMode ? Color.white.opacity(0.10) : Color.black.opacity(0.08)
    }

    private var normalCardTextColor: Color {
        Color.black.opacity(isDarkMode ? 0.84 : 0.78)
    }

    private var selectedCardFillColor: Color {
        isDarkMode ? Color.black.opacity(0.88) : Color.white.opacity(0.94)
    }

    var body: some View {
        GeometryReader { geo in
            let layout = EventTimelineLayout(
                slots: day.slots,
                stageOrder: event.stageOrder ?? [],
                availableWidth: max(geo.size.width, EventTimelineLayout.axisWidth + EventTimelineLayout.minStageWidth),
                maxVisibleStages: maxVisibleStages
            )
            let stickyHeaderOffset = stickyHeaderOffset(containerMinY: geo.frame(in: .global).minY, layout: layout)

            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: boardGradientColors,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(boardStrokeColor, lineWidth: 1)
                    )

                HStack(spacing: 0) {
                    timelineAxis(layout: layout, stickyHeaderOffset: stickyHeaderOffset)
                    stageMatrix(layout: layout, stickyHeaderOffset: stickyHeaderOffset)
                }
                .padding(.vertical, 10)
            }
        }
        .frame(height: boardHeight)
    }

    private func stickyHeaderOffset(containerMinY: CGFloat, layout: EventTimelineLayout) -> CGFloat {
        let rawOffset = max(0, stickyTopInset - containerMinY)
        return min(rawOffset, max(0, layout.bodyHeight - 1))
    }

    @ViewBuilder
    private func stageMatrix(layout: EventTimelineLayout, stickyHeaderOffset: CGFloat) -> some View {
        let stageContent = VStack(spacing: 0) {
            stageHeaderRow(layout: layout, stickyHeaderOffset: stickyHeaderOffset)
                .offset(y: stickyHeaderOffset)
                .zIndex(3)
            stageColumnsRow(layout: layout)
        }

        ScrollView(.horizontal, showsIndicators: false) {
            stageContent
                .frame(width: layout.stageContentWidth, alignment: .leading)
        }
        .frame(width: layout.stageViewportWidth, alignment: .leading)
    }

    private func timelineAxis(layout: EventTimelineLayout, stickyHeaderOffset: CGFloat) -> some View {
        VStack(spacing: 0) {
            ZStack(alignment: .top) {
                headerBackdrop(width: EventTimelineLayout.axisWidth, topExtension: stickyHeaderOffset)

                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(headerBackdropColor.opacity(stickyHeaderOffset > 0 ? 1.0 : 0.0))
                    .overlay(
                        Text("TIME")
                            .font(EventScheduleTypography.semibold(12))
                            .tracking(1.2)
                            .foregroundStyle(axisHeaderTextColor.opacity(stickyHeaderOffset > 0 ? 1.0 : 0.0))
                    )
                    .frame(width: EventTimelineLayout.axisWidth, height: EventTimelineLayout.stageHeaderHeight)
            }
            .frame(width: EventTimelineLayout.axisWidth, height: EventTimelineLayout.stageHeaderHeight, alignment: .top)
            .offset(y: stickyHeaderOffset)
            .zIndex(3)

            ZStack(alignment: .topTrailing) {
                ForEach(layout.tickDates, id: \.timeIntervalSinceReferenceDate) { tick in
                    Text(Self.axisTimeFormatter.string(from: tick))
                        .font(EventScheduleTypography.heavy(12))
                        .foregroundStyle(axisTextColor)
                        .frame(width: EventTimelineLayout.axisWidth - 8, alignment: .trailing)
                        .offset(y: layout.yPosition(for: tick) - 12)
                }
            }
            .frame(width: EventTimelineLayout.axisWidth, height: layout.bodyHeight, alignment: .topTrailing)
        }
        .frame(width: EventTimelineLayout.axisWidth)
    }

    private func stageHeaderRow(layout: EventTimelineLayout, stickyHeaderOffset: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            headerBackdrop(width: layout.stageContentWidth, topExtension: stickyHeaderOffset)

            HStack(spacing: EventTimelineLayout.stageGap) {
                ForEach(layout.stageNames, id: \.self) { stageName in
                    let stageColor = layout.color(for: stageName)
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    stageColor.opacity(0.98),
                                    stageColor.opacity(0.93),
                                    stageColor.opacity(0.86)
                                ],
                                startPoint: .top,
                                endPoint: .bottomTrailing
                            )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 11, style: .continuous)
                                .stroke(Color.white.opacity(0.92), lineWidth: 1.4)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 9.5, style: .continuous)
                                .inset(by: 2)
                                .stroke(Color.white.opacity(0.22), lineWidth: 0.8)
                        )
                        .overlay(
                            Text(stageName)
                                .font(EventScheduleTypography.heavy(26))
                                .minimumScaleFactor(0.24)
                                .lineLimit(2)
                                .multilineTextAlignment(.center)
                                .foregroundStyle(stageHeaderTextColor)
                                .padding(.horizontal, 4)
                        )
                        .shadow(color: stageColor.opacity(0.72), radius: 14, x: 0, y: 0)
                        .shadow(color: stageColor.opacity(0.34), radius: 28, x: 0, y: 0)
                        .frame(width: layout.stageWidth, height: EventTimelineLayout.stageHeaderHeight)
                }
            }
        }
        .frame(width: layout.stageContentWidth, height: EventTimelineLayout.stageHeaderHeight, alignment: .topLeading)
    }

    private func headerBackdrop(width: CGFloat, topExtension: CGFloat = 0) -> some View {
        let resolvedTopExtension = max(0, topExtension)

        return VStack(spacing: 0) {
            if resolvedTopExtension > 0 {
                headerBackdropColor
                    .frame(
                        width: width,
                        height: resolvedTopExtension + EventTimelineLayout.stageHeaderHeight
                    )
                    .offset(y: -resolvedTopExtension)

                LinearGradient(
                    colors: [
                        headerBackdropColor.opacity(isDarkMode ? 0.86 : 0.92),
                        headerBackdropColor.opacity(isDarkMode ? 0.34 : 0.46),
                        headerBackdropColor.opacity(0.0)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(width: width, height: EventTimelineLayout.stageHeaderFadeHeight)
                .offset(y: -resolvedTopExtension)
            }
        }
        .allowsHitTesting(false)
    }

    private func stageColumnsRow(layout: EventTimelineLayout) -> some View {
        HStack(spacing: EventTimelineLayout.stageGap) {
            ForEach(layout.stageNames, id: \.self) { stageName in
                stageColumn(stageName: stageName, layout: layout)
            }
        }
        .frame(height: layout.bodyHeight)
    }

    private func stageColumn(stageName: String, layout: EventTimelineLayout) -> some View {
        let stageColor = layout.color(for: stageName)
        let frames = cardFrames(for: stageName, layout: layout)

        return ZStack(alignment: .top) {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(columnFillColor)

            ForEach(layout.tickDates, id: \.timeIntervalSinceReferenceDate) { tick in
                Rectangle()
                    .fill(gridLineColor)
                    .frame(height: 1)
                    .offset(y: layout.yPosition(for: tick))
            }

            ForEach(frames) { frame in
                timelineCard(frame: frame, stageColor: stageColor)
                    .frame(width: layout.stageWidth, height: frame.height, alignment: .top)
                    .offset(y: frame.top)
            }
        }
        .frame(width: layout.stageWidth, height: layout.bodyHeight)
    }

    private func timelineCard(frame: EventTimelineCardFrame, stageColor: Color) -> some View {
        let isSelected = selectedSlotIDs.contains(frame.slot.id)
        let displayAct = EventLineupActCodec.parse(slot: frame.slot)
        let cardFill = isSelected ? selectedCardFillColor : stageColor.opacity(0.95)
        let textColor = isSelected ? stageColor.opacity(0.98) : normalCardTextColor
        let nameTimeSpacing: CGFloat = 0.2

        let content = RoundedRectangle(cornerRadius: 9, style: .continuous)
            .fill(
                LinearGradient(
                    colors: isSelected
                        ? [
                            Color.black.opacity(0.92),
                            stageColor.opacity(0.10),
                            Color.black.opacity(0.95)
                        ]
                        : [
                            cardFill,
                            stageColor.opacity(0.90),
                            stageColor.opacity(0.82)
                        ],
                    startPoint: .top,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .stroke(
                        isSelected ? stageColor.opacity(0.98) : Color.white.opacity(0.92),
                        lineWidth: isSelected ? 2.2 : 1.4
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 7.5, style: .continuous)
                    .inset(by: 2)
                    .stroke(
                        isSelected
                            ? Color.white.opacity(0.10)
                            : Color.white.opacity(0.24),
                        lineWidth: 0.8
                    )
            )
            .shadow(color: stageColor.opacity(isSelected ? 0.82 : 0.58), radius: isSelected ? 16 : 13, x: 0, y: 0)
            .shadow(color: stageColor.opacity(isSelected ? 0.36 : 0.24), radius: isSelected ? 28 : 22, x: 0, y: 0)
            .overlay(alignment: .bottomTrailing) {
                VStack(alignment: .trailing, spacing: nameTimeSpacing) {
                    Text(displayAct.displayName)
                        .font(EventScheduleTypography.heavy(28))
                        .lineSpacing(-4)
                        .minimumScaleFactor(0.21)
                        .lineLimit(3)
                        .multilineTextAlignment(.trailing)
                        .foregroundStyle(textColor)
                        .frame(maxWidth: .infinity, alignment: .trailing)

                    Text(Self.cardTimeRangeText(for: frame.slot))
                        .font(EventScheduleTypography.heavy(12))
                        .monospacedDigit()
                        .foregroundStyle(isSelected ? stageColor.opacity(0.88) : textColor.opacity(0.95))
                        .lineLimit(1)
                }
                .padding(.horizontal, 3)
                .padding(.top, 3)
                .padding(.bottom, 3)
            }

        return Group {
            if selectable, let onToggleSlot {
                Button {
                    onToggleSlot(frame.slot)
                } label: {
                    content
                }
                .buttonStyle(.plain)
            } else if let onSelectSlot {
                Button {
                    onSelectSlot(frame.slot)
                } label: {
                    content
                }
                .buttonStyle(.plain)
            } else {
                content
            }
        }
    }

    private func cardFrames(for stageName: String, layout: EventTimelineLayout) -> [EventTimelineCardFrame] {
        let stageSlots = (layout.slotsByStage[stageName] ?? []).sorted {
            if $0.startTime == $1.startTime {
                return $0.sortOrder < $1.sortOrder
            }
            return $0.startTime < $1.startTime
        }

        var result: [EventTimelineCardFrame] = []

        for slot in stageSlots {
            let startY = layout.yPosition(for: slot.startTime)
            let endY = layout.yPosition(for: slot.endTime)
            let resolvedHeight = max(44, endY - startY)
            let frame = EventTimelineCardFrame(
                id: slot.id,
                slot: slot,
                top: startY,
                height: resolvedHeight
            )
            result.append(frame)
        }

        return result
    }

    private static func cardTimeRangeText(for slot: WebEventLineupSlot) -> String {
        "\(cardTimeFormatter.string(from: slot.startTime))-\(cardTimeFormatter.string(from: slot.endTime))"
    }

    private static let axisTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "h a"
        return formatter
    }()

    private static let cardTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "HH:mm"
        return formatter
    }()
}

private struct EventRouteSharePresentation: Identifiable {
    let id = UUID()
    let payload: EventRouteShareCardPayload
}

private struct EventRouteSharePreviewCard: View {
    let payload: EventRouteShareCardPayload

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let coverImageURL = payload.coverImageURL?.nilIfBlank {
                ZStack(alignment: .bottomLeading) {
                    ImageLoaderView(urlString: coverImageURL)
                        .frame(height: 142)
                        .clipped()

                    LinearGradient(
                        colors: [Color.black.opacity(0.06), Color.black.opacity(0.48)],
                        startPoint: .top,
                        endPoint: .bottom
                    )

                    if let badgeText = payload.badgeText?.nilIfBlank {
                        Text(badgeText)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color.black.opacity(0.24), in: Capsule())
                            .padding(12)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                if payload.coverImageURL?.nilIfBlank == nil,
                   let badgeText = payload.badgeText?.nilIfBlank {
                    Text(badgeText)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(RaverTheme.accent)
                }

                Text(payload.title)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(RaverTheme.primaryText)
                    .lineLimit(2)

                if let subtitle = payload.subtitle?.nilIfBlank {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(RaverTheme.secondaryText)
                        .lineLimit(2)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RaverTheme.card)
        }
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(RaverTheme.cardBorder.opacity(0.45), lineWidth: 1)
        )
    }
}

struct EventRoutePlannerLoaderView: View {
    let eventID: String
    let eventReadRepository: EventReadRepository
    let ownerUserID: String?
    let ownerDisplayName: String?
    let selectedDayID: String?
    let selectedSlotIDs: [String]?

    @State private var event: WebEvent?
    @State private var phase: LoadPhase = .idle

    init(
        eventID: String,
        eventReadRepository: EventReadRepository,
        ownerUserID: String?,
        ownerDisplayName: String?,
        selectedDayID: String?,
        selectedSlotIDs: [String]?
    ) {
        self.eventID = eventID
        self.eventReadRepository = eventReadRepository
        self.ownerUserID = ownerUserID
        self.ownerDisplayName = ownerDisplayName
        self.selectedDayID = selectedDayID
        self.selectedSlotIDs = selectedSlotIDs
    }

    var body: some View {
        Group {
            switch phase {
            case .idle, .initialLoading:
                EventDetailSkeletonView()
            case .failure(let message), .offline(let message):
                ScrollView {
                    ScreenErrorCard(message: message) {
                        Task { await load(force: true) }
                    }
                    .padding(16)
                    .padding(.top, 96)
                }
                .background(RaverTheme.background)
            case .empty:
                ContentUnavailableView(LT("活动不存在", "活动不存在", "イベントが存在しません"), systemImage: "music.note.house")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(RaverTheme.background)
            case .success:
                if let event {
                    EventRoutePlannerView(
                        event: event,
                        days: EventScheduleDay.build(
                            from: event.lineupSlots,
                            anchorDate: event.startDate,
                            useWeekMode: EventWeekScheduleMode.isEnabled(in: event.description),
                            dayRolloverHour: event.dayRolloverHour
                        ),
                        initialDayID: selectedDayID,
                        initialSelectedSlotIDs: selectedSlotIDs.map(Set.init),
                        routeOwnerUserID: ownerUserID,
                        routeOwnerDisplayName: ownerDisplayName
                    )
                } else {
                    ContentUnavailableView(LT("活动不存在", "活动不存在", "イベントが存在しません"), systemImage: "music.note.house")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(RaverTheme.background)
                }
            }
        }
        .task {
            guard phase == .idle else { return }
            await load()
        }
    }

    @MainActor
    private func load(force: Bool = false) async {
        if !force, phase == .success, event != nil { return }
        phase = .initialLoading
        do {
            event = try await eventReadRepository.fetchEvent(id: eventID)
            phase = event == nil ? .empty : .success
        } catch {
            phase = .failure(
                message: error.userFacingMessage
                    ?? LT("路线加载失败，请稍后重试", "Failed to load route. Please try again later.", "ルートを読み込めませんでした。時間をおいて再試行してください。")
            )
        }
    }
}

private struct EventRoutePlannerShareSnapshotView: View {
    let title: String
    let event: WebEvent
    let days: [EventScheduleDay]
    let selectedDayID: String
    let selectedSlotIDs: Set<String>
    let contentWidth: CGFloat

    private var selectedDay: EventScheduleDay? {
        days.first(where: { $0.id == selectedDayID }) ?? days.first
    }

    @Environment(\.colorScheme) private var colorScheme

    private var selectedDayTextColor: Color {
        colorScheme == .dark ? Color.black.opacity(0.85) : Color.white.opacity(0.97)
    }

    private var selectedDayBackgroundColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.92) : RaverTheme.accent.opacity(0.92)
    }

    private var unselectedDayTextColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.88) : RaverTheme.primaryText.opacity(0.86)
    }

    private var unselectedDayBackgroundColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.13) : Color.black.opacity(0.08)
    }

    private var unselectedDayStrokeColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.18) : Color.black.opacity(0.10)
    }

    private var plannerBackgroundGradientColors: [Color] {
        if colorScheme == .dark {
            return [
                Color(red: 0.05, green: 0.06, blue: 0.11),
                Color(red: 0.03, green: 0.03, blue: 0.04)
            ]
        }
        return [
            Color.white,
            RaverTheme.background
        ]
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: plannerBackgroundGradientColors,
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 14) {
                if let trimmedTitle = title.nilIfBlank {
                    Text(trimmedTitle)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(RaverTheme.primaryText)
                        .lineLimit(2)
                }

                if let eventName = event.name.nilIfBlank {
                    Text(eventName)
                        .font(.caption)
                        .foregroundStyle(RaverTheme.secondaryText)
                        .lineLimit(2)
                }

                if days.count > 1 {
                    daySelector
                }

                if let selectedDay {
                    EventTimelineBoardView(
                        event: event,
                        day: selectedDay,
                        selectedSlotIDs: selectedSlotIDs,
                        selectable: false,
                        onToggleSlot: nil,
                        maxVisibleStages: Int.max,
                        stickyTopInset: 0
                    )
                    .frame(width: contentWidth, height: EventTimelineLayout.estimatedHeight(for: selectedDay.slots), alignment: .leading)
                } else {
                    ContentUnavailableView(LT("等待时间表发布", "等待时间表发布", "タイムテーブル公開待ち"), systemImage: "calendar.badge.exclamationmark")
                        .frame(width: contentWidth, alignment: .leading)
                }
            }
            .padding(.horizontal, 10)
            .padding(.top, 12)
            .padding(.bottom, 24)
            .frame(width: contentWidth + 20, alignment: .leading)
        }
        .frame(width: contentWidth + 20)
    }

    private var daySelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(days) { day in
                    let selected = day.id == selectedDayID
                    Text(day.subtitle)
                        .font(EventScheduleTypography.semibold(15))
                        .foregroundStyle(selected ? selectedDayTextColor : unselectedDayTextColor)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(
                            Capsule()
                                .fill(selected ? selectedDayBackgroundColor : unselectedDayBackgroundColor)
                                .overlay(
                                    Capsule()
                                        .stroke(unselectedDayStrokeColor, lineWidth: selected ? 0 : 1)
                                )
                        )
                }
            }
            .padding(.horizontal, 2)
        }
        .frame(width: contentWidth, alignment: .leading)
    }
}

private struct EventRoutePlannerView: View {
    let event: WebEvent
    let days: [EventScheduleDay]
    let initialDayID: String?
    let routeOwnerUserID: String?
    let routeOwnerDisplayName: String?

    @Environment(\.appPush) private var appPush
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var appContainer: AppContainer
    @EnvironmentObject private var appState: AppState
    @ObservedObject private var routeStore = EventRouteStore.shared
    private var shareMessageRepository: ShareMessageRepository { appContainer.shareMessageRepository }

    @State private var selectedDayID: String
    @State private var selectedSlotIDs: Set<String> = []
    @State private var isGeneratingShare = false
    @State private var feedbackMessage: String?
    @State private var showRouteSavedToast = false
    @State private var isSharePanelMounted = false
    @State private var isShareMorePanelVisible = false
    @State private var fullChatSharePresentation: EventRouteSharePresentation?

    init(
        event: WebEvent,
        days: [EventScheduleDay],
        initialDayID: String? = nil,
        initialSelectedSlotIDs: Set<String>? = nil,
        routeOwnerUserID: String? = nil,
        routeOwnerDisplayName: String? = nil
    ) {
        self.event = event
        self.days = days
        self.initialDayID = initialDayID
        self.routeOwnerUserID = routeOwnerUserID
        self.routeOwnerDisplayName = routeOwnerDisplayName

        let trimmedOwnerUserID = routeOwnerUserID?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let trimmedOwnerDisplayName = routeOwnerDisplayName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let isSharedContext = !trimmedOwnerUserID.isEmpty || !trimmedOwnerDisplayName.isEmpty
        let defaultSelectedSlotIDs = isSharedContext
            ? Set<String>()
            : (EventRouteStore.shared.route(for: event.id)?.selectedSlotIDSet ?? [])

        _selectedDayID = State(initialValue: initialDayID ?? "")
        _selectedSlotIDs = State(initialValue: initialSelectedSlotIDs ?? defaultSelectedSlotIDs)
    }

    private var selectedDay: EventScheduleDay? {
        days.first(where: { $0.id == selectedDayID }) ?? days.first
    }

    private var currentUserID: String? {
        let trimmed = appState.session?.user.id.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }

    private var currentUserDisplayName: String {
        let trimmed = appState.session?.user.displayName.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? LT("我", "Me", "自分") : trimmed
    }

    private var normalizedRouteOwnerUserID: String? {
        let trimmed = routeOwnerUserID?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }

    private var normalizedRouteOwnerDisplayName: String? {
        let trimmed = routeOwnerDisplayName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }

    private var isViewingOwnRoute: Bool {
        if let normalizedRouteOwnerUserID, let currentUserID {
            return normalizedRouteOwnerUserID == currentUserID
        }
        return normalizedRouteOwnerUserID == nil && normalizedRouteOwnerDisplayName == nil
    }

    private var routeOwnerName: String {
        if isViewingOwnRoute {
            return currentUserDisplayName
        }
        return normalizedRouteOwnerDisplayName ?? LT("Ta", "They", "相手")
    }

    private var navigationTitleText: String {
        isViewingOwnRoute
            ? LT("我的路线", "My Route", "自分のルート")
            : LT("\(routeOwnerName)的路线", "\(routeOwnerName)'s Route", "\(routeOwnerName) のルート")
    }

    private var shareCardTitleText: String {
        LT("\(routeOwnerName)的路线", "\(routeOwnerName)'s Route", "\(routeOwnerName) のルート")
    }

    private var routePlannerTimelineStickyTopInset: CGFloat {
        topSafeAreaInset() + 44
    }

    private var selectedDayTextColor: Color {
        colorScheme == .dark ? Color.black.opacity(0.85) : Color.white.opacity(0.97)
    }

    private var selectedDayBackgroundColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.92) : RaverTheme.accent.opacity(0.92)
    }

    private var unselectedDayTextColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.88) : RaverTheme.primaryText.opacity(0.86)
    }

    private var unselectedDayBackgroundColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.13) : Color.black.opacity(0.08)
    }

    private var unselectedDayStrokeColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.18) : Color.black.opacity(0.10)
    }

    private var plannerBackgroundGradientColors: [Color] {
        return [
            RaverTheme.background,
            RaverTheme.background
        ]
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: plannerBackgroundGradientColors,
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 14) {
                    if let eventName = event.name.nilIfBlank {
                        Text(eventName)
                            .font(.headline)
                            .foregroundStyle(RaverTheme.secondaryText)
                            .lineLimit(2)
                    }

                    if days.count > 1 {
                        daySelector
                    }

                    if let selectedDay {
                        EventTimelineBoardView(
                            event: event,
                            day: selectedDay,
                            selectedSlotIDs: selectedSlotIDs,
                            selectable: isViewingOwnRoute,
                            onToggleSlot: isViewingOwnRoute ? { slot in
                                if selectedSlotIDs.contains(slot.id) {
                                    selectedSlotIDs.remove(slot.id)
                                } else {
                                    selectedSlotIDs.insert(slot.id)
                                }
                            } : nil,
                            stickyTopInset: routePlannerTimelineStickyTopInset
                        )
                        .frame(height: EventTimelineLayout.estimatedHeight(for: selectedDay.slots))
                    } else {
                        ContentUnavailableView(LT("等待时间表发布", "等待时间表发布", "タイムテーブル公開待ち"), systemImage: "calendar.badge.exclamationmark")
                    }
                }
                .padding(.horizontal, 10)
                .padding(.top, 12)
                .padding(.bottom, 24)
            }
        }
        .overlay {
            if showRouteSavedToast {
                Text(LT("在个人主页-我的行程可以快速查看路线", "在个人主页-我的行程可以快速查看路线", "プロフィールの「マイ旅程」からルートをすばやく確認できます"))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 12)
                    .background(
                        Capsule()
                            .fill(Color.black.opacity(0.82))
                            .overlay(
                                Capsule()
                                    .stroke(RaverTheme.accent.opacity(0.55), lineWidth: 1)
                            )
                    )
                    .shadow(color: Color.black.opacity(0.28), radius: 18, x: 0, y: 8)
                    .transition(.scale(scale: 0.94).combined(with: .opacity))
                    .zIndex(10)
            }
        }
        .overlay {
            if isSharePanelMounted {
                SharePanelOverlay(
                    isVisible: isShareMorePanelVisible,
                    onBackdropTap: { dismissShareMorePanel() }
                ) {
                    ShareActionPanel(
                        primaryActions: sharePrimaryActions(),
                        quickActions: shareMoreQuickActions(),
                        loadConversations: {
                            try await loadSharePanelConversations()
                        },
                        onSendToConversation: { conversation, note in
                            guard let payload = makeSharePayload() else {
                                throw ServiceError.message(
                                    LT("当前路线还没有可分享的演出内容。", "This route has no selected sets to share yet.", "現在のルートには共有できる出演内容がありません。")
                                )
                            }
                            try await sendSharePayload(
                                payload,
                                to: conversation,
                                note: note
                            )
                        },
                        onDismiss: {
                            dismissShareMorePanel()
                        }
                    ) { conversation in
                        showWidgetStatusBanner(
                            message: LT("已分享到 \(conversation.title)", "Shared to \(conversation.title)", "\(conversation.title) に共有しました"),
                            conversation: conversation
                        )
                    } onMoreChats: {
                        guard let payload = makeSharePayload() else {
                            feedbackMessage = LT("当前路线还没有可分享的演出内容。", "This route has no selected sets to share yet.", "現在のルートには共有できる出演内容がありません。")
                            dismissShareMorePanel()
                            return
                        }
                        dismissShareMorePanel {
                            fullChatSharePresentation = EventRouteSharePresentation(payload: payload)
                        }
                    }
                }
                .onAppear {
                    withAnimation(.sharePanelPresentSpring) {
                        isShareMorePanelVisible = true
                    }
                }
            }
        }
        .animation(.spring(response: 0.30, dampingFraction: 0.86), value: showRouteSavedToast)
        .raverSystemNavigation(title: navigationTitleText, backgroundColor: RaverTheme.background)
        .operationBannerHost()
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    presentShareMorePanel()
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(RaverTheme.primaryText)
                        .frame(width: 36, height: 36)
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
            }
        }
        .onAppear {
            if selectedDayID.isEmpty {
                selectedDayID = days.first?.id ?? ""
            }
        }
        .sheet(item: $fullChatSharePresentation) { presentation in
            ChatShareSheet(
                loadConversations: {
                    try await loadSharePanelConversations()
                },
                onShareToConversation: { conversation in
                    try await sendSharePayload(
                        presentation.payload,
                        to: conversation,
                        note: nil
                    )
                }
            ) { conversation in
                showWidgetStatusBanner(
                    message: LT("已分享到 \(conversation.title)", "Shared to \(conversation.title)", "\(conversation.title) に共有しました"),
                    conversation: conversation
                )
            } preview: {
                EventRouteSharePreviewCard(payload: presentation.payload)
            }
            .presentationDetents([.fraction(0.76), .large])
        }
        .alert(LT("提示", "Notice", "お知らせ"), isPresented: Binding(
            get: { feedbackMessage != nil },
            set: { if !$0 { feedbackMessage = nil } }
        )) {
            Button(LT("确定", "OK", "OK"), role: .cancel) {}
        } message: {
            Text(feedbackMessage ?? "")
        }
    }

    private func dismissShareMorePanel(after completion: (() -> Void)? = nil) {
        withAnimation(.sharePanelDismissSpring) {
            isShareMorePanelVisible = false
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.34) {
            guard !isShareMorePanelVisible else { return }
            isSharePanelMounted = false
            completion?()
        }
    }

    private func presentShareMorePanel() {
        isSharePanelMounted = true
        isShareMorePanelVisible = false
    }

    private func showWidgetStatusBanner(message: String, conversation: Conversation? = nil) {
        OperationBannerCenter.shared.success(
            message,
            action: conversation.map { .appRoute(.conversation(target: .fromConversation($0))) } ?? .none
        )
    }

    private func saveCurrentRoute() {
        routeStore.save(event: event, selectedSlotIDs: selectedSlotIDs)
        showRouteSavedToast = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.1) {
            showRouteSavedToast = false
        }
    }

    private func savePosterImage() {
        Task {
            guard let image = await generatePosterImage() else { return }
            await savePosterToPhotos(image)
        }
    }

    private func shareMoreQuickActions() -> [SharePanelQuickAction] {
        if isViewingOwnRoute {
            return [
                SharePanelQuickAction(
                    title: LT("保存图片", "Save Image", "画像を保存"),
                    systemImage: "photo.badge.arrow.down",
                    accentColor: Color(red: 0.33, green: 0.73, blue: 0.95)
                ) {
                    savePosterImage()
                },
                SharePanelQuickAction(
                    title: LT("保存路线", "Save Route", "ルートを保存"),
                    systemImage: "square.and.arrow.down",
                    accentColor: Color(red: 0.98, green: 0.71, blue: 0.22)
                ) {
                    saveCurrentRoute()
                }
            ]
        }

        return [
            SharePanelQuickAction(
                title: LT("定制我的路线", "Customize Mine", "自分のルートを作る"),
                systemImage: "point.topleft.down.curvedto.point.bottomright.up",
                accentColor: RaverTheme.accent
            ) {
                appPush(
                    .eventRoute(
                        eventID: event.id,
                        ownerUserID: nil,
                        ownerDisplayName: nil,
                        selectedDayID: selectedDayID,
                        selectedSlotIDs: nil
                    )
                )
            },
            SharePanelQuickAction(
                title: LT("保存图片", "Save Image", "画像を保存"),
                systemImage: "photo.badge.arrow.down",
                accentColor: Color(red: 0.33, green: 0.73, blue: 0.95)
            ) {
                savePosterImage()
            }
        ]
    }

    private func sharePrimaryActions() -> [SharePanelPrimaryAction] {
        [
            SharePanelPrimaryAction(
                title: "微信",
                systemImage: "message.circle.fill",
                accentColor: Color(red: 0.18, green: 0.76, blue: 0.35)
            ) {
                feedbackMessage = LT("微信分享接口待接入。", "WeChat share hook is not connected yet.", "WeChat共有連携は未接続です。")
            },
            SharePanelPrimaryAction(
                title: "QQ",
                systemImage: "paperplane.circle.fill",
                accentColor: Color(red: 0.21, green: 0.58, blue: 0.98)
            ) {
                feedbackMessage = LT("QQ 分享接口待接入。", "QQ share hook is not connected yet.", "QQ共有連携は未接続です。")
            }
        ]
    }

    private func loadSharePanelConversations() async throws -> [Conversation] {
        async let directs = shareMessageRepository.fetchConversations(type: .direct)
        async let groups = shareMessageRepository.fetchConversations(type: .group)
        let merged = try await directs + groups
        let deduped = merged.reduce(into: [String: Conversation]()) { partialResult, conversation in
            partialResult[conversation.id] = conversation
        }
        return deduped.values.sorted {
            if $0.isPinned != $1.isPinned { return $0.isPinned && !$1.isPinned }
            return $0.updatedAt > $1.updatedAt
        }
    }

    private func sendSharePayload(
        _ payload: EventRouteShareCardPayload,
        to conversation: Conversation,
        note: String?
    ) async throws {
        _ = try await shareMessageRepository.sendEventRouteCardMessage(
            conversationID: conversation.id,
            payload: payload
        )

        let trimmedNote = note?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !trimmedNote.isEmpty {
            _ = try await shareMessageRepository.sendMessage(
                conversationID: conversation.id,
                content: trimmedNote
            )
        }
    }

    private func makeSharePayload() -> EventRouteShareCardPayload? {
        guard !selectedSlotIDs.isEmpty else { return nil }

        return EventRouteShareCardPayload(
            eventID: event.id,
            eventName: event.name,
            ownerUserID: isViewingOwnRoute ? currentUserID : normalizedRouteOwnerUserID,
            ownerDisplayName: routeOwnerName,
            title: shareCardTitleText,
            subtitle: event.name,
            coverImageURL: event.coverAssetURL,
            badgeText: LT("路线", "Route", "ルート"),
            selectedDayID: selectedDayID.nilIfBlank,
            selectedSlotIDs: selectedSlotIDs.sorted()
        )
    }

    private var daySelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(days) { day in
                    let selected = day.id == selectedDayID
                    Button {
                        selectedDayID = day.id
                    } label: {
                        Text(day.subtitle)
                            .font(EventScheduleTypography.semibold(15))
                            .foregroundStyle(selected ? selectedDayTextColor : unselectedDayTextColor)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(
                                Capsule()
                                    .fill(selected ? selectedDayBackgroundColor : unselectedDayBackgroundColor)
                                    .overlay(
                                        Capsule()
                                            .stroke(unselectedDayStrokeColor, lineWidth: selected ? 0 : 1)
                                    )
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 2)
        }
    }

    @MainActor
    private func generatePosterImage() async -> UIImage? {
        guard !isGeneratingShare else { return nil }
        guard let selectedDay else {
            feedbackMessage = LT("暂无可保存的路线图片", "No route image is available to save.", "保存できるルート画像がありません。")
            return nil
        }

        isGeneratingShare = true
        defer { isGeneratingShare = false }

        let stageCount = EventTimelineLayout.stageCount(for: selectedDay.slots)
        let stageRegionWidth =
            CGFloat(stageCount) * EventTimelineLayout.minStageWidth +
            CGFloat(max(stageCount - 1, 0)) * EventTimelineLayout.stageGap
        let fullBoardWidth = EventTimelineLayout.axisWidth + stageRegionWidth
        let viewportContentWidth = max(
            UIScreen.main.bounds.width - 20,
            EventTimelineLayout.axisWidth + EventTimelineLayout.minStageWidth
        )
        let snapshotContentWidth = max(fullBoardWidth, viewportContentWidth)

        let snapshotView = EventRoutePlannerShareSnapshotView(
            title: navigationTitleText,
            event: event,
            days: days,
            selectedDayID: selectedDay.id,
            selectedSlotIDs: selectedSlotIDs,
            contentWidth: snapshotContentWidth
        )
        .environment(\.colorScheme, colorScheme)

        let renderer = ImageRenderer(content: snapshotView)
        renderer.scale = UIScreen.main.scale
        renderer.proposedSize = ProposedViewSize(width: snapshotContentWidth + 20, height: nil)

        guard let image = renderer.uiImage else {
            feedbackMessage = LT("路线图生成失败，请重试", "Failed to generate route image. Please try again.", "ルート画像を生成できませんでした。もう一度お試しください。")
            return nil
        }
        return image
    }

    @MainActor
    private func savePosterToPhotos(_ image: UIImage) async {
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else {
            feedbackMessage = LT("未获得相册权限，可稍后重新授权后再试。", "Photo permission denied. Please grant access and try again.", "写真へのアクセスが拒否されています。許可してからもう一度お試しください。")
            return
        }

        await withCheckedContinuation { continuation in
            PHPhotoLibrary.shared().performChanges({
                PHAssetChangeRequest.creationRequestForAsset(from: image)
            }) { success, error in
                DispatchQueue.main.async {
                    if success {
                        feedbackMessage = LT("已保存到相册", "Saved to Photos.", "写真に保存しました。")
                    } else if let error {
                        feedbackMessage = LT(
                            "保存失败：\(error.userFacingMessage ?? "")",
                            "Save failed: \(error.userFacingMessage ?? "")",
                            "保存に失敗しました: \(error.userFacingMessage ?? "")"
                        )
                    } else {
                        feedbackMessage = LT("保存失败，请重试", "Save failed. Please try again.", "保存に失敗しました。もう一度お試しください。")
                    }
                    continuation.resume()
                }
            }
        }
    }
}

private struct EventRoutineView: View {
    enum PresentationStyle {
        case pushed
        case embedded
    }

    private struct EventScheduleDJSelectionOption: Identifiable, Hashable {
        let id: String
        let name: String
        let djID: String?
    }

    let event: WebEvent
    let scheduledSlots: [WebEventLineupSlot]
    var presentationStyle: PresentationStyle = .pushed

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.appPush) private var appPush
    @ObservedObject private var routeStore = EventRouteStore.shared
    @State private var selectedDayID: String = ""
    @State private var showRoutePlanner = false
    @State private var showsSavedRouteOverlay = true
    @State private var pendingDJSelectionOptions: [EventScheduleDJSelectionOption] = []
    @State private var showDJSelectionDialog = false
    @State private var pendingUnboundDJName: String?

    private var isEmbedded: Bool {
        presentationStyle == .embedded
    }

    private var days: [EventScheduleDay] {
        EventScheduleDay.build(
            from: scheduledSlots,
            anchorDate: event.startDate,
            useWeekMode: EventWeekScheduleMode.isEnabled(in: event.description),
            dayRolloverHour: event.dayRolloverHour
        )
    }

    private var selectedDay: EventScheduleDay? {
        days.first(where: { $0.id == selectedDayID }) ?? days.first
    }

    private var savedRoute: SavedEventRoute? {
        routeStore.route(for: event.id)
    }

    private var displayedRouteSlotIDs: Set<String> {
        guard showsSavedRouteOverlay else { return [] }
        return savedRoute?.selectedSlotIDSet ?? []
    }

    private var selectedDayTextColor: Color {
        colorScheme == .dark ? Color.black.opacity(0.85) : Color.white.opacity(0.97)
    }

    private var selectedDayBackgroundColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.92) : RaverTheme.accent.opacity(0.92)
    }

    private var unselectedDayTextColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.88) : RaverTheme.primaryText.opacity(0.86)
    }

    private var unselectedDayBackgroundColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.13) : Color.black.opacity(0.06)
    }

    private var unselectedDayStrokeColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.18) : Color.black.opacity(0.10)
    }

    private var scheduleBackgroundGradientColors: [Color] {
        if colorScheme == .dark {
            return [
                Color(red: 0.05, green: 0.06, blue: 0.11),
                RaverTheme.background
            ]
        }
        return [
            Color.white,
            RaverTheme.background
        ]
    }

    private var routeActionIdleFillColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.06) : Color.black.opacity(0.035)
    }

    private var routeActionIdleStrokeColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.12) : Color.black.opacity(0.08)
    }

    private var timelineStickyTopInset: CGFloat {
        switch presentationStyle {
        case .embedded:
            return topSafeAreaInset() + 44 + 52
        case .pushed:
            return topSafeAreaInset() + 44
        }
    }

    var body: some View {
        Group {
            if days.isEmpty {
                ContentUnavailableView(LT("等待时间表发布", "等待时间表发布", "タイムテーブル公開待ち"), systemImage: "calendar.badge.exclamationmark")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
            } else if isEmbedded {
                embeddedContent
            } else {
                standaloneContent
            }
        }
        .onAppear {
            if selectedDayID.isEmpty {
                selectedDayID = days.first?.id ?? ""
            }
        }
        .navigationDestination(isPresented: $showRoutePlanner) {
            EventRoutePlannerView(
                event: event,
                days: days,
                initialDayID: selectedDayID
            )
        }
        .confirmationDialog(
            "",
            isPresented: $showDJSelectionDialog,
            titleVisibility: .hidden
        ) {
            ForEach(pendingDJSelectionOptions) { option in
                Button(option.name) {
                    if let djID = option.djID {
                        appPush(.djDetail(djID: djID))
                    } else {
                        presentUnboundDJPrompt(name: option.name)
                    }
                    clearPendingDJSelection()
                }
            }
            Button(LT("取消", "Cancel", "キャンセル"), role: .cancel) {
                clearPendingDJSelection()
            }
        }
        .alert(LT("DJ 信息待补充", "DJ Info Needed", "DJ情報が不足しています"), isPresented: Binding(
            get: { pendingUnboundDJName != nil },
            set: { if !$0 { pendingUnboundDJName = nil } }
        )) {
            Button(LT("关闭", "Close", "閉じる"), role: .cancel) {
                pendingUnboundDJName = nil
            }
            Button(LT("去补充", "Add Info", "情報を追加")) {
                let name = pendingUnboundDJName
                pendingUnboundDJName = nil
                appPush(.discover(.djImport(initialName: name)))
            }
        } message: {
            Text(LT("这个 DJ 暂未建立唯一档案，补充资料后就可以跳转到详情页。", "This DJ does not have a unique profile yet. Add the info to enable detail navigation.", "このDJにはまだ固有プロフィールがありません。情報を追加すると詳細ページへ移動できます。"))
        }
    }

    private var embeddedContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            routeControlRow

            if days.count > 1 {
                daySelector
            }

            timelineBoard
        }
    }

    private var standaloneContent: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                routeControlRow

                if days.count > 1 {
                    daySelector
                }

                timelineBoard
            }
            .padding(.horizontal, 10)
            .padding(.top, 12)
            .padding(.bottom, 24)
        }
        .background(
            LinearGradient(
                colors: scheduleBackgroundGradientColors,
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .raverSystemNavigation(title: LT("活动日程", "Event Schedule", "イベント日程"))
    }

    private var routeControlRow: some View {
        HStack(spacing: 10) {
            Spacer()

            if savedRoute != nil {
                Button {
                    showsSavedRouteOverlay.toggle()
                } label: {
                    Label(
                        showsSavedRouteOverlay ? LT("隐藏路线", "隐藏路线", "ルートを非表示") : LT("显示路线", "显示路线", "ルートを表示"),
                        systemImage: showsSavedRouteOverlay ? "eye.slash.fill" : "eye.fill"
                    )
                }
                .buttonStyle(.plain)
                .font(.caption.weight(.semibold))
                .foregroundStyle(showsSavedRouteOverlay ? RaverTheme.accent : RaverTheme.secondaryText)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(routeActionBackground(isHighlighted: showsSavedRouteOverlay))
            }

            Button {
                showRoutePlanner = true
            } label: {
                Label(LT("定制路线", "定制路线", "ルートを作成"), systemImage: "point.topleft.down.curvedto.point.bottomright.up")
            }
            .buttonStyle(.plain)
            .font(.caption.weight(.semibold))
            .foregroundStyle(RaverTheme.accent)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(routeActionBackground(isHighlighted: true))
        }
    }

    private func routeActionBackground(isHighlighted: Bool) -> some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(isHighlighted ? RaverTheme.accent.opacity(0.13) : routeActionIdleFillColor)
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(isHighlighted ? RaverTheme.accent.opacity(0.42) : routeActionIdleStrokeColor, lineWidth: 1)
            )
    }

    @ViewBuilder
    private var timelineBoard: some View {
        if let selectedDay {
            EventTimelineBoardView(
                event: event,
                day: selectedDay,
                selectedSlotIDs: displayedRouteSlotIDs,
                selectable: false,
                onToggleSlot: nil,
                onSelectSlot: { slot in
                    handleTimelineSlotTap(slot)
                },
                stickyTopInset: timelineStickyTopInset
            )
            .frame(height: EventTimelineLayout.estimatedHeight(for: selectedDay.slots))
        } else {
            ContentUnavailableView(LT("等待时间表发布", "等待时间表发布", "タイムテーブル公開待ち"), systemImage: "calendar.badge.exclamationmark")
        }
    }

    private func handleTimelineSlotTap(_ slot: WebEventLineupSlot) {
        let act = EventLineupActCodec.parse(slot: slot)
        let options = djSelectionOptions(for: slot, act: act)
        if act.isCollaborative, options.count > 1 {
            pendingDJSelectionOptions = options
            showDJSelectionDialog = true
            return
        }

        if let option = options.first {
            if let djID = option.djID {
                appPush(.djDetail(djID: djID))
            } else {
                presentUnboundDJPrompt(name: option.name)
            }
            return
        }

        if let djID = preferredDJID(for: slot) {
            appPush(.djDetail(djID: djID))
        } else {
            presentUnboundDJPrompt(name: act.displayName)
        }
    }

    private func djSelectionOptions(
        for slot: WebEventLineupSlot,
        act: EventLineupResolvedAct
    ) -> [EventScheduleDJSelectionOption] {
        var options: [EventScheduleDJSelectionOption] = []
        var seenIDs = Set<String>()

        let appendOption: (_ djID: String?, _ name: String, _ fallbackID: String) -> Void = { djID, name, fallbackID in
            let normalizedID = djID?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let optionID = normalizedID.isEmpty ? fallbackID : normalizedID
            guard seenIDs.insert(optionID).inserted else { return }
            let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
            let resolvedName = trimmedName.isEmpty ? (normalizedID.isEmpty ? LT("待补充 DJ", "DJ info needed", "DJ情報未入力") : normalizedID) : trimmedName
            options.append(
                EventScheduleDJSelectionOption(
                    id: optionID,
                    name: resolvedName,
                    djID: normalizedID.isEmpty ? nil : normalizedID
                )
            )
        }

        for (index, performer) in act.performers.enumerated() {
            let djID = performer.djID?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            appendOption(djID, performer.name, "unbound-\(slot.id)-\(index)")
        }

        let fallbackIDs = (slot.djIds ?? [])
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        for (index, djID) in fallbackIDs.enumerated() {
            let fallbackName: String
            if index < act.performers.count {
                fallbackName = act.performers[index].name
            } else {
                fallbackName = "DJ \(index + 1)"
            }
            appendOption(djID, fallbackName, "fallback-\(slot.id)-\(index)")
        }

        let primaryID = slot.djId?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !primaryID.isEmpty {
            appendOption(primaryID, act.performers.first?.name ?? "", "primary-\(slot.id)")
        }

        return options
    }

    private func preferredDJID(for slot: WebEventLineupSlot) -> String? {
        let primary = slot.djId?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !primary.isEmpty { return primary }

        if let fallback = (slot.djIds ?? [])
            .map({ $0.trimmingCharacters(in: .whitespacesAndNewlines) })
            .first(where: { !$0.isEmpty }) {
            return fallback
        }

        let act = EventLineupActCodec.parse(slot: slot)
        for performer in act.performers {
            let inline = performer.djID?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if !inline.isEmpty { return inline }
        }

        return nil
    }

    private func clearPendingDJSelection() {
        pendingDJSelectionOptions = []
    }

    private func presentUnboundDJPrompt(name: String) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        pendingUnboundDJName = trimmedName.isEmpty ? LT("待补充 DJ", "DJ info needed", "DJ情報未入力") : trimmedName
    }

    private var daySelector: some View {
        //HorizontalAxisLockedScrollView(showsIndicators: false) {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                // ForEach(Array(days.enumerated()), id: \.offset) { _, day in
                ForEach(days) { day in
                    let selected = day.id == selectedDayID
                    Button {
                        selectedDayID = day.id
                    } label: {
                        Text(day.subtitle)
                            .font(EventScheduleTypography.semibold(15))
                            .foregroundStyle(selected ? selectedDayTextColor : unselectedDayTextColor)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(
                                Capsule()
                                    .fill(selected ? selectedDayBackgroundColor : unselectedDayBackgroundColor)
                                    .overlay(
                                        Capsule()
                                            .stroke(unselectedDayStrokeColor, lineWidth: selected ? 0 : 1)
                                    )
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 2)
        }
    }
}
