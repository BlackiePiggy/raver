import SwiftUI
import UIKit

enum ContributionModuleTelemetry {
    static func track(_ name: String, properties: [String: String] = [:]) {
        #if DEBUG
        print("[ContributionModuleTelemetry] \(name) \(properties)")
        #endif
    }

    static func contributorSummaryTapped(entityType: String, entityID: String, totalCount: Int) {
        track("contributor_summary_tapped", properties: [
            "entityType": entityType,
            "entityId": entityID,
            "totalCount": "\(max(0, totalCount))"
        ])
    }

    static func contributorListProfileTapped(entityType: String, entityID: String, targetUserID: String) {
        track("contributor_list_profile_tapped", properties: [
            "entityType": entityType,
            "entityId": entityID,
            "targetUserId": targetUserID
        ])
    }

    static func contributionCenterExposure(filter: String) {
        track("contribution_center_exposure", properties: [
            "filter": filter
        ])
    }

    static func contributionCenterFilterTapped(filter: String) {
        track("contribution_center_filter_tapped", properties: [
            "filter": filter
        ])
    }

    static func contributionCenterEntryTapped() {
        track("contribution_center_entry_tapped")
    }
}

private final class HorizontalAxisLockedUIScrollView: UIScrollView {
    override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard
            gestureRecognizer === panGestureRecognizer,
            let pan = gestureRecognizer as? UIPanGestureRecognizer
        else {
            return super.gestureRecognizerShouldBegin(gestureRecognizer)
        }

        let velocity = pan.velocity(in: self)
        if abs(velocity.y) > abs(velocity.x) {
            return false
        }

        return super.gestureRecognizerShouldBegin(gestureRecognizer)
    }
}

struct HorizontalAxisLockedScrollView<Content: View>: UIViewRepresentable {
    let showsIndicators: Bool
    let contentOffsetX: Binding<CGFloat>?
    let onDraggingChanged: ((Bool) -> Void)?
    let content: Content

    init(
        showsIndicators: Bool = false,
        contentOffsetX: Binding<CGFloat>? = nil,
        onDraggingChanged: ((Bool) -> Void)? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.showsIndicators = showsIndicators
        self.contentOffsetX = contentOffsetX
        self.onDraggingChanged = onDraggingChanged
        self.content = content()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(
            content: content,
            contentOffsetX: contentOffsetX,
            onDraggingChanged: onDraggingChanged
        )
    }

    func makeUIView(context: Context) -> UIScrollView {
        let scrollView = HorizontalAxisLockedUIScrollView()
        scrollView.backgroundColor = .clear
        scrollView.showsHorizontalScrollIndicator = showsIndicators
        scrollView.showsVerticalScrollIndicator = false
        scrollView.bounces = true
        scrollView.alwaysBounceHorizontal = true
        scrollView.alwaysBounceVertical = false
        scrollView.delaysContentTouches = true
        scrollView.canCancelContentTouches = true
        scrollView.isDirectionalLockEnabled = true
        scrollView.clipsToBounds = true
        scrollView.delegate = context.coordinator

        let hostedView = context.coordinator.hostingController.view
        hostedView?.backgroundColor = .clear
        hostedView?.translatesAutoresizingMaskIntoConstraints = false

        if let hostedView {
            scrollView.addSubview(hostedView)
            NSLayoutConstraint.activate([
                hostedView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
                hostedView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
                hostedView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
                hostedView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
                hostedView.heightAnchor.constraint(equalTo: scrollView.frameLayoutGuide.heightAnchor)
            ])
        }

        return scrollView
    }

    func updateUIView(_ uiView: UIScrollView, context: Context) {
        uiView.showsHorizontalScrollIndicator = showsIndicators
        context.coordinator.hostingController.rootView = content
        context.coordinator.contentOffsetX = contentOffsetX
        context.coordinator.onDraggingChanged = onDraggingChanged

        if let storedOffsetX = contentOffsetX?.wrappedValue,
           !uiView.isDragging,
           !uiView.isDecelerating,
           uiView.bounds.width > 0 {
            let minOffsetX = -uiView.adjustedContentInset.left
            let maxOffsetX = max(
                minOffsetX,
                uiView.contentSize.width - uiView.bounds.width + uiView.adjustedContentInset.right
            )
            let clampedOffsetX = min(max(storedOffsetX, minOffsetX), maxOffsetX)

            if abs(uiView.contentOffset.x - clampedOffsetX) > 0.5 {
                uiView.setContentOffset(CGPoint(x: clampedOffsetX, y: uiView.contentOffset.y), animated: false)
            }
        }
    }

    final class Coordinator: NSObject, UIScrollViewDelegate {
        let hostingController: UIHostingController<Content>
        var contentOffsetX: Binding<CGFloat>?
        var onDraggingChanged: ((Bool) -> Void)?
        private var isDraggingNotified = false

        init(
            content: Content,
            contentOffsetX: Binding<CGFloat>?,
            onDraggingChanged: ((Bool) -> Void)?
        ) {
            hostingController = UIHostingController(rootView: content)
            hostingController.view.backgroundColor = .clear
            self.contentOffsetX = contentOffsetX
            self.onDraggingChanged = onDraggingChanged
        }

        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            contentOffsetX?.wrappedValue = scrollView.contentOffset.x
        }

        func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
            guard !isDraggingNotified else { return }
            isDraggingNotified = true
            onDraggingChanged?(true)
        }

        func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
            guard !decelerate else { return }
            finishDragging()
        }

        func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
            finishDragging()
        }

        private func finishDragging() {
            guard isDraggingNotified else { return }
            isDraggingNotified = false
            onDraggingChanged?(false)
        }
    }
}

func topSafeAreaInset() -> CGFloat {
    UIApplication.shared.connectedScenes
        .compactMap { $0 as? UIWindowScene }
        .flatMap { $0.windows }
        .first(where: { $0.isKeyWindow })?
        .safeAreaInsets.top ?? 0
}

private enum ContributionEntityKind: String {
    case event
    case dj

    var iconName: String {
        switch self {
        case .event:
            return "calendar"
        case .dj:
            return "music.mic"
        }
    }
}

private enum ContributorAvatarLayoutStyle {
    case solo
    case b2b
    case b3b

    static func resolve(for count: Int) -> ContributorAvatarLayoutStyle {
        if count <= 1 { return .solo }
        if count == 2 { return .b2b }
        return .b3b
    }

    var visibleCount: Int {
        switch self {
        case .solo: return 1
        case .b2b: return 2
        case .b3b: return 3
        }
    }

    var avatarSize: CGFloat {
        switch self {
        case .solo: return 34
        case .b2b: return 30
        case .b3b: return 28
        }
    }

    var overlapOffset: CGFloat {
        switch self {
        case .solo: return 0
        case .b2b: return 16
        case .b3b: return 14
        }
    }
}

struct ContributorAvatarStack: View {
    let users: [WebUserLite]

    var body: some View {
        let visibleUsers = Array(users.prefix(3))
        let style = ContributorAvatarLayoutStyle.resolve(for: visibleUsers.count)
        let avatarSize = style.avatarSize
        let overlapOffset = style.overlapOffset
        let width = avatarSize + CGFloat(max(0, visibleUsers.count - 1)) * overlapOffset

        ZStack(alignment: .leading) {
            ForEach(Array(visibleUsers.enumerated()), id: \.element.id) { index, user in
                contributorAvatar(user, size: avatarSize)
                    .offset(x: CGFloat(index) * overlapOffset)
                    .zIndex(Double(visibleUsers.count - index))
            }
        }
        .frame(width: width, height: avatarSize, alignment: .leading)
    }

    @ViewBuilder
    private func contributorAvatar(_ user: WebUserLite, size: CGFloat) -> some View {
        if let avatar = AppConfig.resolvedURLString(user.avatarUrl), !avatar.isEmpty {
            ImageLoaderView(urlString: avatar, resizingMode: .fill, showsIndicator: false)
                .frame(width: size, height: size)
                .clipShape(Circle())
                .overlay(Circle().stroke(RaverTheme.background, lineWidth: 2))
                .background(
                    Circle()
                        .fill(RaverTheme.card)
                        .frame(width: size, height: size)
                )
        } else {
            Circle()
                .fill(RaverTheme.card)
                .frame(width: size, height: size)
                .overlay(
                    Text(initials(of: user.shownName))
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(RaverTheme.secondaryText)
                )
                .overlay(Circle().stroke(RaverTheme.background, lineWidth: 2))
        }
    }
}

struct ContributorSummaryRow: View {
    let summary: WebContributorSummary?
    let fallbackUsers: [WebUserLite]
    let action: () -> Void

    private var previewUsers: [WebUserLite] {
        let users = summary?.previewUsers ?? []
        if !users.isEmpty { return users }
        return fallbackUsers
    }

    private var creator: WebUserLite? {
        summary?.creator ?? previewUsers.first
    }

    private var totalCount: Int {
        max(summary?.totalCount ?? 0, previewUsers.count)
    }

    private var displayText: String {
        guard let creator else {
            return LT("贡献者", "Contributors", "貢献者")
        }
        if totalCount <= 1 {
            return creator.shownName
        }
        return LT(
            "\(creator.shownName) 等\(totalCount)人",
            "\(creator.shownName) and \(max(1, totalCount - 1)) others",
            "\(creator.shownName) ほか\(max(1, totalCount - 1))名"
        )
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                if totalCount <= 1, let creator {
                    ContributorAvatarStack(users: [creator])
                } else {
                    ContributorAvatarStack(users: previewUsers)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(LT("贡献者", "Contributors", "貢献者"))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(RaverTheme.secondaryText)
                    Text(displayText)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(RaverTheme.primaryText)
                        .lineLimit(2)
                }

                Spacer(minLength: 8)

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(RaverTheme.secondaryText)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

struct EntityContributorListView: View {
    @EnvironmentObject private var appContainer: AppContainer

    let entityType: String
    let entityID: String
    let entityTitle: String?

    @State private var page: WebEntityContributorPage?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var selectedProfileUserID: String?

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                if let summary = page?.summary {
                    GlassCard {
                        HStack(spacing: 12) {
                            ContributorAvatarStack(users: summary.previewUsers.isEmpty ? [summary.creator].compactMap { $0 } : summary.previewUsers)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(LT("贡献者总览", "Contributor Summary", "貢献サマリー"))
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(RaverTheme.secondaryText)
                                Text(summaryText(summary))
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(RaverTheme.primaryText)
                            }

                            Spacer(minLength: 0)
                        }
                    }
                }

                contentSection
            }
            .padding(16)
        }
        .background {
            NavigationLink(
                destination: selectedProfileDestination,
                isActive: Binding(
                    get: { selectedProfileUserID != nil },
                    set: { isActive in
                        if !isActive {
                            selectedProfileUserID = nil
                        }
                    }
                )
            ) {
                EmptyView()
            }
            .hidden()
        }
        .background(RaverTheme.background.ignoresSafeArea())
        .raverSystemNavigation(title: LT("贡献者", "Contributors", "貢献者"))
        .task {
            await loadIfNeeded()
        }
        .refreshable {
            await load(force: true)
        }
        .alert(LT("提示", "Notice", "お知らせ"), isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button(LT("确定", "OK", "OK"), role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    @ViewBuilder
    private var contentSection: some View {
        if isLoading && page == nil {
            ProgressView()
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
        } else if let items = sortedItems, items.isEmpty {
            ContentUnavailableView(
                LT("暂无贡献者", "No contributors yet", "貢献者はまだいません"),
                systemImage: "person.3.sequence.fill",
                description: Text(LT(
                    "当前对象还没有公开展示的贡献者记录。",
                    "This item does not have any public contributor records yet.",
                    "この項目にはまだ公開された貢献者履歴がありません。"
                ))
            )
        } else if let items = sortedItems {
            LazyVStack(spacing: 12) {
                ForEach(items) { item in
                    Button {
                        ContributionModuleTelemetry.contributorListProfileTapped(
                            entityType: entityType,
                            entityID: entityID,
                            targetUserID: item.user.id
                        )
                        openUserProfile(item.user.id)
                    } label: {
                        contributorRow(item)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var sortedItems: [WebEntityContributorItem]? {
        page?.items.sorted {
            if $0.lastContributedAt != $1.lastContributedAt {
                return $0.lastContributedAt > $1.lastContributedAt
            }
            if $0.updatedAt != $1.updatedAt {
                return $0.updatedAt > $1.updatedAt
            }
            return $0.user.id > $1.user.id
        }
    }

    private func contributorRow(_ item: WebEntityContributorItem) -> some View {
        GlassCard {
            HStack(alignment: .top, spacing: 12) {
                ContributorAvatarStack(users: [item.user])

                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .center, spacing: 8) {
                        Text(item.user.shownName)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(RaverTheme.primaryText)
                        Text(roleText(item.role))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(RaverTheme.accent)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(RaverTheme.accent.opacity(0.12))
                            )
                    }

                    Text(LT(
                        "\(item.contributionCount) 次贡献",
                        "\(item.contributionCount) contributions",
                        "\(item.contributionCount) 回の貢献"
                    ))
                    .font(.footnote)
                    .foregroundStyle(RaverTheme.secondaryText)
                }

                Spacer(minLength: 8)

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(RaverTheme.secondaryText)
                    .padding(.top, 4)
            }
            .contentShape(Rectangle())
        }
    }

    @ViewBuilder
    private var selectedProfileDestination: some View {
        if let selectedProfileUserID {
            UserProfileView(
                userID: TencentIMIdentity.normalizePlatformUserIDForProfile(selectedProfileUserID)
            )
        } else {
            EmptyView()
        }
    }

    private func openUserProfile(_ userID: String) {
        selectedProfileUserID = userID
    }

    @MainActor
    private func loadIfNeeded() async {
        guard page == nil else { return }
        await load(force: false)
    }

    @MainActor
    private func load(force: Bool) async {
        if isLoading { return }
        if !force, page != nil { return }
        isLoading = true
        defer { isLoading = false }

        do {
            if ContributionEntityKind(rawValue: entityType) == .event {
                page = try await appContainer.webService.fetchEventContributors(eventID: entityID)
            } else {
                page = try await appContainer.webService.fetchDJContributors(djID: entityID)
            }
            errorMessage = nil
        } catch {
            errorMessage = error.userFacingMessage ?? LT(
                "贡献者列表加载失败，请稍后重试。",
                "Failed to load contributors. Please try again later.",
                "貢献者一覧を読み込めませんでした。時間をおいて再試行してください。"
            )
        }
    }

    private func roleText(_ role: String) -> String {
        role == "creator"
            ? LT("创建者", "Creator", "作成者")
            : LT("贡献者", "Contributor", "貢献者")
    }

    private func summaryText(_ summary: WebContributorSummary) -> String {
        guard let creator = summary.creator else {
            return LT(
                "共 \(summary.totalCount) 位贡献者",
                "\(summary.totalCount) contributors",
                "貢献者 \(summary.totalCount) 名"
            )
        }
        if summary.totalCount <= 1 {
            return creator.shownName
        }
        return LT(
            "\(creator.shownName) 等\(summary.totalCount)人",
            "\(creator.shownName) and \(max(1, summary.totalCount - 1)) others",
            "\(creator.shownName) ほか\(max(1, summary.totalCount - 1))名"
        )
    }

    private func utcTimestampText(_ date: Date) -> String {
        Self.utcFormatter.string(from: date)
    }

    private static let utcFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss 'UTC'"
        return formatter
    }()
}
