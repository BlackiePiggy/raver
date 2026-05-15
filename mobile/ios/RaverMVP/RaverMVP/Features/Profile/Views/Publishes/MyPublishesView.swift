import SwiftUI

@MainActor
final class MyPublishesViewModel: ObservableObject {
    @Published var publishes = MyPublishes(djSets: [], events: [], ratingEvents: [], ratingUnits: [])
    @Published var contentSubmissions: [ContentSubmissionSummary] = []
    @Published var newsPublishes: [Post] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let userRepository: ProfileUserRepository
    private let contentRepository: ProfileContentRepository

    init(
        userRepository: ProfileUserRepository,
        contentRepository: ProfileContentRepository
    ) {
        self.userRepository = userRepository
        self.contentRepository = contentRepository
    }

    func load() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            async let publishesTask = contentRepository.fetchMyPublishes()
            async let submissionsTask = contentRepository.fetchMyContentSubmissions()
            async let newsTask = loadMyNewsPublishes()
            publishes = try await publishesTask
            contentSubmissions = try await submissionsTask
            newsPublishes = try await newsTask
            errorMessage = nil
        } catch {
            errorMessage = error.userFacingMessage
        }
    }

    func deleteSet(id: String) async {
        do {
            try await contentRepository.deleteDJSet(id: id)
            publishes.djSets.removeAll { $0.id == id }
        } catch {
            errorMessage = error.userFacingMessage
        }
    }

    func deleteEvent(id: String) async {
        do {
            try await contentRepository.deleteEvent(id: id)
            publishes.events.removeAll { $0.id == id }
        } catch {
            errorMessage = error.userFacingMessage
        }
    }

    func deleteRatingEvent(id: String) async {
        do {
            try await contentRepository.deleteRatingEvent(id: id)
            publishes.ratingEvents.removeAll { $0.id == id }
            publishes.ratingUnits.removeAll { $0.eventId == id }
        } catch {
            errorMessage = error.userFacingMessage
        }
    }

    func deleteRatingUnit(id: String) async {
        do {
            try await contentRepository.deleteRatingUnit(id: id)
            publishes.ratingUnits.removeAll { $0.id == id }
        } catch {
            errorMessage = error.userFacingMessage
        }
    }

    private func loadMyNewsPublishes() async throws -> [Post] {
        let profile = try await userRepository.fetchMyProfile()
        var cursor: String?
        var rounds = 0
        var merged: [Post] = []
        var seen: Set<String> = []

        repeat {
            let page = try await contentRepository.fetchPostsByUser(userID: profile.id, cursor: cursor)
            for post in page.posts where post.isRaverNews && !seen.contains(post.id) {
                seen.insert(post.id)
                merged.append(post)
            }
            cursor = page.nextCursor
            rounds += 1
        } while cursor != nil && rounds < 6

        return merged.sorted { $0.createdAt > $1.createdAt }
    }
}

struct MyPublishesView: View {
    private enum ReviewFilter: String, CaseIterable, Identifiable {
        case all
        case approved
        case pending
        case rejected

        var id: String { rawValue }

        var title: String {
            switch self {
            case .all: return "ALL"
            case .approved: return LT("审核通过", "Approved", "承認済み")
            case .pending: return LT("审核中", "Pending", "審査中")
            case .rejected: return LT("未通过", "Rejected", "却下")
            }
        }
    }

    @Environment(\.appPush) private var appPush
    @Environment(\.profilePush) private var profilePush
    @StateObject private var viewModel: MyPublishesViewModel
    @State private var selectedTab = 0
    @State private var selectedReviewFilter: ReviewFilter = .all

    init(
        userRepository: ProfileUserRepository,
        contentRepository: ProfileContentRepository
    ) {
        _viewModel = StateObject(
            wrappedValue: MyPublishesViewModel(
                userRepository: userRepository,
                contentRepository: contentRepository
            )
        )
    }

    var body: some View {
        List {
            Picker(LT("发布类型", "Publish Type", "公開タイプ"), selection: $selectedTab) {
                Text(LT("Sets", "Sets", "Sets")).tag(0)
                Text(LT("活动", "Events", "イベント")).tag(1)
                Text(LT("打分", "Ratings", "評価")).tag(2)
                Text(LT("资讯", "News", "ニュース")).tag(3)
            }
            .pickerStyle(.segmented)

            Picker(LT("审核状态", "Review Status", "審査状態"), selection: $selectedReviewFilter) {
                ForEach(ReviewFilter.allCases) { filter in
                    Text(filter.title).tag(filter)
                }
            }
            .pickerStyle(.segmented)

            if selectedTab == 0 {
                if selectedReviewFilter != .approved {
                    reviewSubmissionSection(entityType: "set")
                } else if viewModel.publishes.djSets.isEmpty, !viewModel.isLoading {
                    ContentUnavailableView(LT("暂无发布 Set", "No published sets yet", "公開Setはまだありません"), systemImage: "waveform")
                        .listRowBackground(Color.clear)
                }

                if selectedReviewFilter == .approved {
                    ForEach(viewModel.publishes.djSets) { set in
                    Button {
                        appPush(.discover(.setDetail(setID: set.id)))
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(set.title)
                                .font(.headline)
                            Text(LT("\(set.trackCount) 首曲目", "\(set.trackCount) tracks", "\(set.trackCount)曲"))
                                .font(.caption)
                                .foregroundStyle(RaverTheme.secondaryText)
                            Text(set.createdAt.appLocalizedYMDHMText())
                                .font(.caption2)
                                .foregroundStyle(RaverTheme.secondaryText)
                        }
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(.plain)
                    .swipeActions {
                        Button {
                            profilePush(.editSet(setID: set.id))
                        } label: {
                            Label(LT("编辑", "Edit", "編集"), systemImage: "pencil")
                        }

                        Button(role: .destructive) {
                            Task { await viewModel.deleteSet(id: set.id) }
                        } label: {
                            Label(LT("删除", "Delete", "削除"), systemImage: "trash")
                        }
                    }
                    }
                }
            } else if selectedTab == 1 {
                if selectedReviewFilter != .approved {
                    reviewSubmissionSection(entityType: "event")
                } else if viewModel.publishes.events.isEmpty, !viewModel.isLoading {
                    ContentUnavailableView(LT("暂无发布活动", "No published events yet", "公開イベントはまだありません"), systemImage: "calendar")
                        .listRowBackground(Color.clear)
                }

                if selectedReviewFilter == .approved {
                    ForEach(viewModel.publishes.events) { event in
                    Button {
                        appPush(.eventDetail(eventID: event.id))
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(event.name)
                                .font(.headline)
                            Text(event.startDate.appLocalizedYMDText())
                                .font(.caption)
                                .foregroundStyle(RaverTheme.secondaryText)
                            let addressText = event.unifiedAddress.trimmingCharacters(in: .whitespacesAndNewlines)
                            Text(addressText.isEmpty ? LT("地点待补充", "Location pending", "場所は未設定") : addressText)
                                .font(.caption2)
                                .foregroundStyle(RaverTheme.secondaryText)
                            Text(event.createdAt.appLocalizedYMDHMText())
                                .font(.caption2)
                                .foregroundStyle(RaverTheme.secondaryText)
                        }
                        .padding(.vertical, 4)
                    }
                    .swipeActions {
                        Button {
                            profilePush(.editEvent(eventID: event.id))
                        } label: {
                            Label(LT("编辑", "Edit", "編集"), systemImage: "pencil")
                        }

                        Button(role: .destructive) {
                            Task { await viewModel.deleteEvent(id: event.id) }
                        } label: {
                            Label(LT("删除", "Delete", "削除"), systemImage: "trash")
                        }
                    }
                    }
                }
            } else if selectedTab == 2 {
                if selectedReviewFilter != .approved {
                    reviewSubmissionSection(entityType: "rating")
                } else if viewModel.publishes.ratingEvents.isEmpty, viewModel.publishes.ratingUnits.isEmpty, !viewModel.isLoading {
                    ContentUnavailableView(LT("暂无发布打分", "No published ratings yet", "公開評価はまだありません"), systemImage: "star.leadinghalf.filled")
                        .listRowBackground(Color.clear)
                }

                if selectedReviewFilter == .approved, !viewModel.publishes.ratingEvents.isEmpty {
                    Section(LT("我发布的打分事件", "My Rating Events", "自分が公開した評価イベント")) {
                        ForEach(viewModel.publishes.ratingEvents) { event in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(event.name)
                                    .font(.headline)
                                Text(LT("\(event.unitCount) 个打分单位", "\(event.unitCount) rating units", "\(event.unitCount)件の評価ユニット"))
                                    .font(.caption)
                                    .foregroundStyle(RaverTheme.secondaryText)
                                Text(event.createdAt.appLocalizedYMDHMText())
                                    .font(.caption2)
                                    .foregroundStyle(RaverTheme.secondaryText)
                            }
                            .padding(.vertical, 4)
                            .swipeActions {
                                Button {
                                    profilePush(.editRatingEvent(eventID: event.id))
                                } label: {
                                    Label(LT("编辑", "Edit", "編集"), systemImage: "pencil")
                                }

                                Button(role: .destructive) {
                                    Task { await viewModel.deleteRatingEvent(id: event.id) }
                                } label: {
                                    Label(LT("删除", "Delete", "削除"), systemImage: "trash")
                                }
                            }
                        }
                    }
                }

                if selectedReviewFilter == .approved, !viewModel.publishes.ratingUnits.isEmpty {
                    Section(LT("我发布的打分单位", "My Rating Units", "自分が公開した評価ユニット")) {
                        ForEach(viewModel.publishes.ratingUnits) { unit in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(unit.name)
                                    .font(.headline)
                                Text(LT("所属事件：\(unit.eventName)", "Event: \(unit.eventName)", "イベント: \(unit.eventName)"))
                                    .font(.caption)
                                    .foregroundStyle(RaverTheme.secondaryText)
                                Text(unit.createdAt.appLocalizedYMDHMText())
                                    .font(.caption2)
                                    .foregroundStyle(RaverTheme.secondaryText)
                            }
                            .padding(.vertical, 4)
                            .swipeActions {
                                Button {
                                    profilePush(.editRatingUnit(unitID: unit.id))
                                } label: {
                                    Label(LT("编辑", "Edit", "編集"), systemImage: "pencil")
                                }

                                Button(role: .destructive) {
                                    Task { await viewModel.deleteRatingUnit(id: unit.id) }
                                } label: {
                                    Label(LT("删除", "Delete", "削除"), systemImage: "trash")
                                }
                            }
                        }
                    }
                }
            } else {
                if selectedReviewFilter != .approved {
                    reviewSubmissionSection(entityType: "news")
                } else if viewModel.newsPublishes.isEmpty, !viewModel.isLoading {
                    ContentUnavailableView(LT("暂无发布资讯", "No published news yet", "公開ニュースはまだありません"), systemImage: "newspaper")
                        .listRowBackground(Color.clear)
                }

                if selectedReviewFilter == .approved {
                    ForEach(viewModel.newsPublishes) { post in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(post.raverNewsTitle)
                            .font(.headline)
                            .lineLimit(2)
                        Text(post.raverNewsSource)
                            .font(.caption)
                            .foregroundStyle(RaverTheme.secondaryText)
                        Text(post.createdAt.appLocalizedYMDHMText())
                            .font(.caption2)
                            .foregroundStyle(RaverTheme.secondaryText)
                    }
                    .padding(.vertical, 4)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .raverSystemNavigation(title: LT("我的发布", "My Posts", "自分の投稿"))
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        profilePush(.publishEvent)
                    } label: {
                        Label(LT("发布活动", "Publish Event", "イベントを公開"), systemImage: "calendar.badge.plus")
                    }

                    Button {
                        profilePush(.uploadSet)
                    } label: {
                        Label(LT("上传 Set", "Upload Set", "Setをアップロード"), systemImage: "square.and.arrow.up")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .task {
            await viewModel.load()
        }
        .refreshable {
            await viewModel.load()
        }
        .alert(LT("提示", "Notice", "お知らせ"), isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button(LT("确定", "OK", "OK"), role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    private func reviewSubmissionSection(entityType: String) -> some View {
        let items = viewModel.contentSubmissions.filter {
            $0.entityType == entityType && (selectedReviewFilter == .all || $0.status == selectedReviewFilter.rawValue)
        }
        .sorted {
            ($0.updatedAt ?? $0.createdAt ?? .distantPast) > ($1.updatedAt ?? $1.createdAt ?? .distantPast)
        }

        return Group {
            if items.isEmpty, !viewModel.isLoading {
                ContentUnavailableView(
                    LT("暂无\(selectedReviewFilter.title)内容", "No \(selectedReviewFilter.title) items", "\(selectedReviewFilter.title) の内容はまだありません"),
                    systemImage: selectedReviewFilter == .pending ? "clock" : "xmark.seal"
                )
                .listRowBackground(Color.clear)
            }

            ForEach(items) { item in
                Button {
                    profilePush(.contentSubmissionDetail(submissionID: item.id))
                } label: {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 8) {
                            Text(item.title)
                                .font(.headline)
                            Spacer(minLength: 8)
                            Text(statusTitle(item.status))
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(statusColor(item.status))
                        }

                        if let reason = item.reviewReason?.trimmingCharacters(in: .whitespacesAndNewlines), !reason.isEmpty {
                            Text(reason)
                                .font(.caption)
                                .foregroundStyle(RaverTheme.secondaryText)
                                .lineLimit(3)
                        } else if item.status == "rejected" {
                            Text(LT("请补充更准确的信息后重新提交", "Add more accurate information before resubmitting.", "より正確な情報を補足して再送信してください"))
                                .font(.caption)
                                .foregroundStyle(RaverTheme.secondaryText)
                        }

                        Text((item.updatedAt ?? item.createdAt ?? Date()).appLocalizedYMDHMText())
                            .font(.caption2)
                            .foregroundStyle(RaverTheme.secondaryText)
                    }
                    .padding(.vertical, 4)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func statusTitle(_ status: String) -> String {
        switch status {
        case "approved": return LT("审核通过", "Approved", "承認済み")
        case "pending": return LT("审核中", "Pending", "審査中")
        case "rejected": return LT("未通过", "Rejected", "却下")
        default: return status
        }
    }

    private func statusColor(_ status: String) -> Color {
        switch status {
        case "approved": return .green
        case "pending": return .orange
        case "rejected": return .red
        default: return RaverTheme.secondaryText
        }
    }
}

@MainActor
final class ContentSubmissionDetailViewModel: ObservableObject {
    @Published var submission: ContentSubmissionDetail?
    @Published var editablePayload: [String: ContentSubmissionJSONValue] = [:]
    @Published var changeNote = ""
    @Published var isEditing = false
    @Published var isLoading = false
    @Published var isSaving = false
    @Published var errorMessage: String?
    @Published var successMessage: String?

    private let submissionID: String
    private let repository: ProfileContentRepository

    init(submissionID: String, repository: ProfileContentRepository) {
        self.submissionID = submissionID
        self.repository = repository
    }

    func load() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let detail = try await repository.fetchMyContentSubmission(id: submissionID)
            submission = detail
            editablePayload = detail.payload
            isEditing = false
            errorMessage = nil
        } catch {
            errorMessage = error.userFacingMessage
        }
    }

    func resubmit() async {
        guard !isSaving else { return }
        do {
            let normalizedNote = changeNote.trimmingCharacters(in: .whitespacesAndNewlines)
            isSaving = true
            defer { isSaving = false }
            let updated = try await repository.resubmitMyContentSubmission(
                id: submissionID,
                payload: editablePayload,
                changeNote: normalizedNote.isEmpty ? nil : normalizedNote
            )
            submission = updated
            editablePayload = updated.payload
            isEditing = false
            changeNote = ""
            successMessage = LT("已重新提交审核", "Resubmitted for review", "再審査に送信しました")
            errorMessage = nil
        } catch {
            errorMessage = error.userFacingMessage
        }
    }

    func resetEdits() {
        guard let submission else { return }
        editablePayload = submission.payload
        changeNote = ""
        isEditing = false
    }

    func stringValue(_ key: String) -> String {
        editablePayload[key]?.editableStringValue ?? ""
    }

    func setStringValue(_ value: String, for key: String) {
        editablePayload[key] = .string(value)
    }

    func commaListValue(_ key: String) -> String {
        guard case .array(let values)? = editablePayload[key] else {
            return stringValue(key)
        }
        return values.compactMap(\.plainStringValue).joined(separator: ", ")
    }

    func setCommaListValue(_ value: String, for key: String) {
        let items = value
            .split(whereSeparator: { $0 == "," || $0 == "，" })
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        editablePayload[key] = .array(items.map { .string($0) })
    }
}

struct ContentSubmissionDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: ContentSubmissionDetailViewModel

    init(submissionID: String, repository: ProfileContentRepository) {
        _viewModel = StateObject(
            wrappedValue: ContentSubmissionDetailViewModel(
                submissionID: submissionID,
                repository: repository
            )
        )
    }

    var body: some View {
        Form {
            if let submission = viewModel.submission {
                Section(LT("提交信息", "Submission Info", "送信情報")) {
                    labeledRow(LT("标题", "Title", "タイトル"), submission.title)
                    labeledRow(LT("类型", "Type", "タイプ"), entityTitle(submission.entityType))
                    labeledRow(LT("状态", "Status", "状態"), statusTitle(submission.status))
                    if let createdAt = submission.createdAt {
                        labeledRow(LT("提交时间", "Submitted At", "送信時間"), createdAt.appLocalizedYMDHMText())
                    }
                    if let updatedAt = submission.updatedAt {
                        labeledRow(LT("更新时间", "Updated At", "更新時間"), updatedAt.appLocalizedYMDHMText())
                    }
                    if let reason = submission.reviewReason?.trimmingCharacters(in: .whitespacesAndNewlines), !reason.isEmpty {
                        labeledRow(LT("审核备注", "Review Notes", "審査メモ"), reason)
                    }
                }

                Section(LT("提交内容", "Submitted Content", "送信内容")) {
                    if submission.entityType == "event" {
                        eventSubmissionFields
                    } else if submission.entityType == "dj" {
                        djSubmissionFields
                    } else {
                        genericSubmissionFields(for: submission.entityType)
                    }
                }

                if viewModel.isEditing, submission.status != "approved" {
                    Section(LT("重新提交", "Resubmit", "再送信")) {
                        TextField(LT("修改说明（可选）", "Change note (optional)", "変更説明（任意）"), text: $viewModel.changeNote, axis: .vertical)
                        Button(viewModel.isSaving ? LT("提交中...", "Submitting...", "送信中...") : LT("重新提交审核", "Resubmit for review", "再審査に送信")) {
                            Task { await viewModel.resubmit() }
                        }
                        .disabled(viewModel.isSaving)
                        .buttonStyle(.borderedProminent)
                        .tint(Color(red: 0.95, green: 0.38, blue: 0.18))
                    }
                }

                if !submission.versions.isEmpty {
                    Section(LT("版本记录", "Version History", "バージョン履歴")) {
                        ForEach(submission.versions) { version in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(version.title)
                                    .font(.subheadline.weight(.semibold))
                                if let submittedAt = version.submittedAt {
                                    Text(submittedAt.appLocalizedYMDHMText())
                                        .font(.caption2)
                                        .foregroundStyle(RaverTheme.secondaryText)
                                }
                                if let note = version.changeNote?.trimmingCharacters(in: .whitespacesAndNewlines), !note.isEmpty {
                                    Text(note)
                                        .font(.caption2)
                                        .foregroundStyle(RaverTheme.secondaryText)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            } else if viewModel.isLoading {
                ProgressView()
            }
        }
        .raverSystemNavigation(title: LT("提交详情", "Submission Detail", "送信詳細"))
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if viewModel.submission?.status != "approved" {
                    Button(viewModel.isEditing ? LT("取消", "Cancel", "キャンセル") : LT("编辑", "Edit", "編集")) {
                        if viewModel.isEditing {
                            viewModel.resetEdits()
                        } else {
                            viewModel.isEditing = true
                        }
                    }
                }
            }
        }
        .task {
            await viewModel.load()
        }
        .alert(LT("提示", "Notice", "お知らせ"), isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button(LT("确定", "OK", "OK"), role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .alert(LT("提示", "Notice", "お知らせ"), isPresented: Binding(
            get: { viewModel.successMessage != nil },
            set: { if !$0 { viewModel.successMessage = nil } }
        )) {
            Button(LT("确定", "OK", "OK"), role: .cancel) {
                viewModel.successMessage = nil
                dismiss()
            }
        } message: {
            Text(viewModel.successMessage ?? "")
        }
    }

    private func labeledRow(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(RaverTheme.secondaryText)
            Text(value)
                .font(.body)
        }
    }

    @ViewBuilder
    private var eventSubmissionFields: some View {
        editableTextRow(LT("活动名称", "Event Name", "イベント名"), key: "name")
        editableLongTextRow(LT("简介", "Description", "概要"), key: "description")
        editableTextRow(LT("活动性质", "Event Type", "イベント種別"), key: "eventType")
        editableTextRow(LT("状态", "Status", "状態"), key: "status")
        editableTextRow(LT("开始日期", "Start Date", "開始日"), key: "startDate")
        editableTextRow(LT("结束日期", "End Date", "終了日"), key: "endDate")
        editableTextRow(LT("City (English)", "City (English)", "City (English)"), key: "city")
        editableTextRow(LT("Country (English)", "Country (English)", "Country (English)"), key: "country")
        editableNestedTextRow(LT("详细地址（中文）", "Detailed Address (Chinese)", "詳細住所（中国語）"), objectKey: "manualLocation", nestedKey: "detailAddressZh")
        editableNestedTextRow(LT("Detailed Address (English)", "Detailed Address (English)", "Detailed Address (English)"), objectKey: "manualLocation", nestedKey: "detailAddressEn")
        editableTextRow(LT("购票链接", "Ticket URL", "チケット購入リンク"), key: "ticketUrl")
        editableTextRow(LT("票务币种", "Ticket Currency", "チケット通貨"), key: "ticketCurrency")
        editableLongTextRow(LT("票务备注", "Ticket Notes", "チケット備考"), key: "ticketNotes")
        editableTextRow(LT("官网链接", "Official Website", "公式サイトリンク"), key: "officialWebsite")
        editableTextRow(LT("封面图", "Cover Image", "カバー画像"), key: "coverImageUrl")
        editableTextRow(LT("阵容图", "Lineup Image", "ラインナップ画像"), key: "lineupImageUrl")
        editableCommaListRow(LT("舞台", "Stages", "ステージ"), key: "stageOrder")
        summaryRow(LT("票档", "Ticket Tiers", "チケット区分"), value: payloadSummary("ticketTiers"))
        summaryRow(LT("阵容", "Lineup", "ラインナップ"), value: payloadSummary("lineupSlots"))
    }

    @ViewBuilder
    private var djSubmissionFields: some View {
        editableTextRow(LT("DJ 名称", "DJ Name", "DJ名"), key: "name")
        editableCommaListRow(LT("别名", "Aliases", "別名"), key: "aliases")
        editableLongTextRow(LT("简介", "Bio", "概要"), key: "bio")
        editableTextRow(LT("国家", "Country", "国"), key: "country")
        editableTextRow("Instagram", key: "instagramUrl")
        editableTextRow("SoundCloud", key: "soundcloudUrl")
        editableTextRow("X/Twitter", key: "twitterUrl")
        editableTextRow("Spotify ID", key: "spotifyId")
        editableTextRow(LT("头像", "Avatar", "アバター"), key: "avatarUrl")
        editableTextRow(LT("横幅", "Banner", "バナー"), key: "bannerUrl")
        summaryRow(LT("来源", "Source", "ソース"), value: payloadDisplayValue("importSource"))
    }

    @ViewBuilder
    private func genericSubmissionFields(for entityType: String) -> some View {
        switch entityType {
        case "news":
            editableTextRow(LT("标题", "Title", "タイトル"), key: "title")
            editableLongTextRow(LT("正文", "Body", "本文"), key: "content")
            editableLongTextRow(LT("摘要", "Summary", "概要"), key: "summary")
            editableTextRow(LT("来源", "Source", "ソース"), key: "source")
            editableTextRow(LT("封面图", "Cover Image", "カバー画像"), key: "coverImageURL")
            editableCommaListRow(LT("关联 DJ", "Linked DJs", "関連DJ"), key: "boundDjIDs")
            editableCommaListRow(LT("关联品牌", "Linked Brands", "関連ブランド"), key: "boundBrandIDs")
            editableCommaListRow(LT("关联活动", "Linked Events", "関連イベント"), key: "boundEventIDs")
        case "set":
            editableTextRow(LT("标题", "Title", "タイトル"), key: "title")
            editableLongTextRow(LT("简介", "Description", "概要"), key: "description")
            editableTextRow("DJ ID", key: "djId")
            editableCommaListRow(LT("共同 DJ", "Co-DJs", "共通DJ"), key: "djIds")
            editableCommaListRow(LT("自定义 DJ 名称", "Custom DJ Names", "カスタムDJ名"), key: "customDjNames")
            editableTextRow(LT("视频链接", "Video URL", "動画リンク"), key: "videoUrl")
            editableTextRow(LT("缩略图", "Thumbnail", "サムネイル"), key: "thumbnailUrl")
            editableTextRow(LT("录制日期", "Recorded At", "録音日"), key: "recordedAt")
            editableTextRow(LT("场地", "Venue", "会場"), key: "venue")
            editableTextRow(LT("活动名称", "Event Name", "イベント名"), key: "eventName")
        case "brand":
            editableTextRow(LT("品牌名称", "Brand Name", "ブランド名"), key: "name")
            editableTextRow(LT("简称", "Abbreviation", "略称"), key: "abbreviation")
            editableCommaListRow(LT("别名", "Aliases", "別名"), key: "aliases")
            editableTextRow(LT("国家", "Country", "国"), key: "country")
            editableTextRow(LT("城市", "City", "都市"), key: "city")
            editableTextRow(LT("创立年份", "Founded Year", "創立年"), key: "foundedYear")
            editableTextRow(LT("频率", "Frequency", "頻度"), key: "frequency")
            editableLongTextRow(LT("标语", "Tagline", "タグライン"), key: "tagline")
            editableLongTextRow(LT("介绍", "Introduction", "紹介"), key: "introduction")
            editableTextRow(LT("官网链接", "Official Website", "公式サイトリンク"), key: "officialWebsite")
            editableTextRow("Instagram", key: "instagramUrl")
            editableTextRow(LT("头像", "Avatar", "アバター"), key: "avatarUrl")
            editableTextRow(LT("背景图", "Background Image", "背景画像"), key: "backgroundUrl")
        case "label":
            editableTextRow(LT("厂牌名称", "Label Name", "レーベル名"), key: "name")
            editableCommaListRow(LT("风格", "Genres", "ジャンル"), key: "genres")
            editableLongTextRow(LT("介绍", "Introduction", "紹介"), key: "introduction")
            editableTextRow(LT("国家", "Country", "国"), key: "nation")
            editableTextRow(LT("官网链接", "Official Website", "公式サイトリンク"), key: "officialWebsiteUrl")
            editableTextRow("SoundCloud", key: "soundcloudUrl")
            editableTextRow("Facebook", key: "facebookUrl")
            editableTextRow(LT("Logo", "Logo", "Logo"), key: "logoUrl")
            editableTextRow(LT("投稿链接", "Demo Submission URL", "投稿リンク"), key: "demoSubmissionUrl")
        case "id":
            editableTextRow(LT("歌曲名称", "Track Name", "曲名"), key: "songName")
            editableTextRow(LT("艺人", "Artist", "アーティスト"), key: "artistName")
            editableLongTextRow(LT("描述", "Description", "説明"), key: "description")
            editableTextRow(LT("音频/视频链接", "Audio/Video URL", "音声/動画リンク"), key: "mediaUrl")
            editableCommaListRow(LT("关联 DJ", "Linked DJs", "関連DJ"), key: "boundDjIDs")
            editableCommaListRow(LT("关联活动", "Linked Events", "関連イベント"), key: "boundEventIDs")
            editableCommaListRow(LT("图片", "Images", "画像"), key: "images")
        case "rating":
            editableTextRow(LT("名称", "Name", "名称"), key: "name")
            editableLongTextRow(LT("简介", "Description", "概要"), key: "description")
            editableTextRow(LT("图片", "Image", "画像"), key: "imageUrl")
            editableTextRow(LT("打分事件 ID", "Rating Event ID", "評価イベントID"), key: "ratingEventId")
        default:
            ForEach(viewModel.editablePayload.keys.sorted(), id: \.self) { key in
                editableTextRow(key, key: key)
            }
        }
    }

    @ViewBuilder
    private func editableTextRow(_ title: String, key: String) -> some View {
        if viewModel.isEditing {
            TextField(title, text: Binding(
                get: { viewModel.stringValue(key) },
                set: { viewModel.setStringValue($0, for: key) }
            ))
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled(true)
        } else {
            labeledRow(title, payloadDisplayValue(key))
        }
    }

    @ViewBuilder
    private func editableLongTextRow(_ title: String, key: String) -> some View {
        if viewModel.isEditing {
            TextField(title, text: Binding(
                get: { viewModel.stringValue(key) },
                set: { viewModel.setStringValue($0, for: key) }
            ), axis: .vertical)
            .lineLimit(3...8)
        } else {
            labeledRow(title, payloadDisplayValue(key))
        }
    }

    @ViewBuilder
    private func editableCommaListRow(_ title: String, key: String) -> some View {
        if viewModel.isEditing {
            TextField(title, text: Binding(
                get: { viewModel.commaListValue(key) },
                set: { viewModel.setCommaListValue($0, for: key) }
            ), axis: .vertical)
            .lineLimit(1...4)
        } else {
            labeledRow(title, payloadDisplayValue(key))
        }
    }

    @ViewBuilder
    private func editableNestedTextRow(_ title: String, objectKey: String, nestedKey: String) -> some View {
        let value = nestedPayloadDisplayValue(objectKey: objectKey, nestedKey: nestedKey)
        if viewModel.isEditing {
            TextField(title, text: Binding(
                get: { nestedPayloadDisplayValue(objectKey: objectKey, nestedKey: nestedKey) },
                set: { setNestedStringValue($0, objectKey: objectKey, nestedKey: nestedKey) }
            ), axis: .vertical)
            .lineLimit(1...4)
        } else {
            labeledRow(title, value)
        }
    }

    private func summaryRow(_ title: String, value: String) -> some View {
        labeledRow(title, value)
    }

    private func entityTitle(_ entityType: String) -> String {
        switch entityType {
        case "event": return LT("活动", "Event", "イベント")
        case "dj": return "DJ"
        case "news": return LT("资讯", "News", "ニュース")
        case "set": return "Set"
        case "brand": return LT("品牌", "Brand", "ブランド")
        case "label": return LT("厂牌", "Label", "レーベル")
        case "id": return "ID"
        case "rating": return LT("打分", "Rating", "評価")
        default: return entityType
        }
    }

    private func payloadDisplayValue(_ key: String) -> String {
        viewModel.editablePayload[key]?.displayStringValue.nilIfBlank ?? LT("未填写", "Not provided", "未入力")
    }

    private func nestedPayloadDisplayValue(objectKey: String, nestedKey: String) -> String {
        guard case .object(let object)? = viewModel.editablePayload[objectKey] else {
            return ""
        }
        return object[nestedKey]?.displayStringValue ?? ""
    }

    private func setNestedStringValue(_ value: String, objectKey: String, nestedKey: String) {
        var object: [String: ContentSubmissionJSONValue]
        if case .object(let existing)? = viewModel.editablePayload[objectKey] {
            object = existing
        } else {
            object = [:]
        }
        object[nestedKey] = .string(value)
        viewModel.editablePayload[objectKey] = .object(object)
    }

    private func payloadSummary(_ key: String) -> String {
        guard let value = viewModel.editablePayload[key] else {
            return LT("未填写", "Not provided", "未入力")
        }
        switch value {
        case .array(let values):
            return values.isEmpty ? LT("未填写", "Not provided", "未入力") : LT("\(values.count) 项", "\(values.count) items", "\(values.count)項目")
        case .object(let object):
            return object.isEmpty ? LT("未填写", "Not provided", "未入力") : LT("\(object.count) 项", "\(object.count) items", "\(object.count)項目")
        default:
            return value.displayStringValue.nilIfBlank ?? LT("未填写", "Not provided", "未入力")
        }
    }

    private func statusTitle(_ status: String) -> String {
        switch status {
        case "approved": return LT("审核通过", "Approved", "承認済み")
        case "pending": return LT("审核中", "Pending", "審査中")
        case "rejected": return LT("未通过", "Rejected", "却下")
        default: return status
        }
    }
}

private extension ContentSubmissionJSONValue {
    var plainStringValue: String? {
        switch self {
        case .string(let value):
            return value
        case .number(let value):
            return value.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(value)) : String(value)
        case .bool(let value):
            return value ? "true" : "false"
        case .null:
            return nil
        case .object, .array:
            return nil
        }
    }

    var editableStringValue: String {
        plainStringValue ?? displayStringValue
    }

    var displayStringValue: String {
        switch self {
        case .string(let value):
            return value
        case .number(let value):
            return value.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(value)) : String(value)
        case .bool(let value):
            return value ? LT("是", "Yes", "はい") : LT("否", "No", "いいえ")
        case .array(let values):
            let strings = values.compactMap(\.plainStringValue)
            if strings.count == values.count {
                return strings.joined(separator: ", ")
            }
            return values.isEmpty ? "" : LT("\(values.count) 项", "\(values.count) items", "\(values.count)項目")
        case .object(let object):
            return object.isEmpty ? "" : LT("\(object.count) 项", "\(object.count) items", "\(object.count)項目")
        case .null:
            return ""
        }
    }
}
