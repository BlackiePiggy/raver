import SwiftUI

struct EntityChangeDetailView: View {
    @StateObject private var viewModel: EntityChangeDetailViewModel

    init(changeLogID: String, repository: NotificationRepository) {
        _viewModel = StateObject(wrappedValue: EntityChangeDetailViewModel(
            changeLogID: changeLogID,
            repository: repository
        ))
    }

    var body: some View {
        Group {
            switch viewModel.phase {
            case .idle, .initialLoading:
                VStack(spacing: 12) {
                    ProgressView()
                    Text(LT("正在加载修改详情", "Loading change details", "変更詳細を読み込み中"))
                        .font(.subheadline)
                        .foregroundStyle(RaverTheme.secondaryText)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(RaverTheme.background)
            case .failure(let message), .offline(let message):
                ScreenErrorCard(message: message) {
                    Task { await viewModel.load() }
                }
                .padding(16)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(RaverTheme.background)
            case .empty:
                ContentUnavailableView(
                    LT("暂无公开修改", "No Public Changes", "公開変更はありません"),
                    systemImage: "doc.text.magnifyingglass",
                    description: Text(LT("这次更新没有可公开展示的字段。", "This update has no public-safe fields to show.", "この更新には公開可能な項目がありません。"))
                )
                .background(RaverTheme.background)
            case .success:
                if let detail = viewModel.detail {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            summaryCard(detail)
                            ForEach(detail.publicChanges) { change in
                                changeCard(change)
                            }
                        }
                        .padding(16)
                    }
                    .background(RaverTheme.background)
                }
            }
        }
        .navigationTitle(LT("修改详情", "Change Details", "変更詳細"))
        .task {
            await viewModel.load()
        }
    }

    private func summaryCard(_ detail: EntityChangePublicDetail) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(entityTitle(detail.entityType))
                .font(.caption.weight(.semibold))
                .foregroundStyle(RaverTheme.secondaryText)
            Text(detail.summaries.localizedText ?? LT("本次更新包含公开变更。", "This update contains public changes.", "この更新には公開変更が含まれます。"))
                .font(.headline)
                .foregroundStyle(RaverTheme.primaryText)
                .fixedSize(horizontal: false, vertical: true)
            Text(detail.createdAt.feedTimeText)
                .font(.caption)
                .foregroundStyle(RaverTheme.secondaryText)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RaverTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func changeCard(_ change: EntityChangePublicChange) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(change.localizedLabel)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(RaverTheme.primaryText)
                Spacer()
                Text(kindText(change.kind))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(RaverTheme.accent)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(RaverTheme.accent.opacity(0.14))
                    .clipShape(Capsule())
            }

            HStack(alignment: .top, spacing: 10) {
                valueColumn(title: LT("修改前", "Before", "変更前"), value: change.localizedBefore)
                Image(systemName: "arrow.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(RaverTheme.secondaryText)
                    .padding(.top, 27)
                valueColumn(title: LT("修改后", "After", "変更後"), value: change.localizedAfter)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RaverTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func valueColumn(title: String, value: String?) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(RaverTheme.secondaryText)
            Text((value?.isEmpty == false ? value : nil) ?? LT("未设置", "Not set", "未設定"))
                .font(.subheadline)
                .foregroundStyle(RaverTheme.primaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func entityTitle(_ entityType: String) -> String {
        switch entityType {
        case "event":
            return LT("活动更新", "Event Update", "イベント更新")
        case "dj":
            return LT("DJ 更新", "DJ Update", "DJ更新")
        case "brand":
            return LT("主办方更新", "Brand Update", "ブランド更新")
        case "djSet":
            return LT("DJ Set 更新", "DJ Set Update", "DJ Set更新")
        default:
            return LT("内容更新", "Content Update", "コンテンツ更新")
        }
    }

    private func kindText(_ kind: String) -> String {
        switch kind {
        case "added":
            return LT("新增", "Added", "追加")
        case "removed":
            return LT("移除", "Removed", "削除")
        case "reordered":
            return LT("顺序调整", "Reordered", "並び替え")
        default:
            return LT("修改", "Updated", "変更")
        }
    }
}

struct EntityChangeResultPreviewCard: View {
    var change: EntityChangeInlineResult?
    var showsReviewPendingNotice = false
    var onOpenDetail: ((String) -> Void)?

    var body: some View {
        if let change {
            changePreview(change)
        } else if showsReviewPendingNotice {
            reviewPendingNotice
        }
    }

    private func changePreview(_ change: EntityChangeInlineResult) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(RaverTheme.accent)
                VStack(alignment: .leading, spacing: 2) {
                    Text(LT("本次修改", "Changes Made", "今回の変更"))
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(RaverTheme.primaryText)
                    Text(changeCountText(change))
                        .font(.caption)
                        .foregroundStyle(RaverTheme.secondaryText)
                }
                Spacer()
            }

            if let summary = change.localizedSummary {
                Text(summary)
                    .font(.subheadline)
                    .foregroundStyle(RaverTheme.primaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if change.publicChanges.isEmpty {
                Text(change.changed
                     ? LT("这次更新没有可公开展示的字段。", "This update has no public-safe fields to show.", "この更新には公開可能な項目がありません。")
                     : LT("没有检测到实际字段变化。", "No actual field changes were detected.", "実際の項目変更は検出されませんでした。"))
                    .font(.caption)
                    .foregroundStyle(RaverTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                VStack(spacing: 10) {
                    ForEach(Array(change.publicChanges.prefix(4))) { item in
                        EntityChangeInlineRow(change: item)
                    }
                }

                if change.publicChanges.count > 4 {
                    Text(LT("还有 \(change.publicChanges.count - 4) 项修改，可查看完整详情。", "\(change.publicChanges.count - 4) more changes are available in the full detail view.", "ほか \(change.publicChanges.count - 4) 件の変更は詳細で確認できます。"))
                        .font(.caption)
                        .foregroundStyle(RaverTheme.secondaryText)
                }
            }

            if let changeLogID = change.changeLogId?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfBlank,
               let onOpenDetail {
                Button {
                    onOpenDetail(changeLogID)
                } label: {
                    HStack(spacing: 8) {
                        Text(LT("查看完整修改详情", "View Full Change Details", "変更詳細をすべて見る"))
                            .font(.subheadline.weight(.semibold))
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.bold))
                    }
                    .foregroundStyle(RaverTheme.accent)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RaverTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(RaverTheme.cardBorder, lineWidth: 1)
        )
        .padding(.horizontal, 20)
    }

    private var reviewPendingNotice: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "hourglass")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(RaverTheme.accent)
                Text(LT("修改详情将在审核通过后生成", "Change details will appear after review approval", "変更詳細は審査承認後に生成されます"))
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(RaverTheme.primaryText)
            }
            Text(LT(
                "这次编辑还没有实际写入内容库，因此暂时没有最终 diff。审核通过后，你可以在通知中心或我的发布里查看具体旧值/新值。",
                "This edit has not been written to the content library yet, so the final diff is not available. After approval, you can view exact before/after values from notifications or My Posts.",
                "この編集はまだコンテンツDBへ反映されていないため、最終差分はありません。承認後、通知またはマイ投稿から変更前後の値を確認できます。"
            ))
            .font(.subheadline)
            .foregroundStyle(RaverTheme.secondaryText)
            .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RaverTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(RaverTheme.cardBorder, lineWidth: 1)
        )
        .padding(.horizontal, 20)
    }

    private func changeCountText(_ change: EntityChangeInlineResult) -> String {
        guard change.changed else {
            return LT("未检测到实际变化", "No actual changes detected", "実際の変更はありません")
        }
        return LT("\(change.changeCount) 项字段变化", "\(change.changeCount) field changes", "\(change.changeCount) 件の項目変更")
    }
}

private struct EntityChangeInlineRow: View {
    var change: EntityChangePublicChange

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text(change.localizedLabel)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(RaverTheme.primaryText)
                Spacer()
                Text(kindText(change.kind))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(RaverTheme.accent)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(RaverTheme.accent.opacity(0.12), in: Capsule())
            }

            HStack(alignment: .top, spacing: 8) {
                valuePill(title: LT("修改前", "Before", "変更前"), value: change.localizedBefore)
                Image(systemName: "arrow.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(RaverTheme.secondaryText)
                    .padding(.top, 24)
                valuePill(title: LT("修改后", "After", "変更後"), value: change.localizedAfter)
            }
        }
        .padding(12)
        .background(RaverTheme.background.opacity(0.62))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func valuePill(title: String, value: String?) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(RaverTheme.secondaryText)
            Text(value?.nilIfBlank ?? LT("未设置", "Not set", "未設定"))
                .font(.caption)
                .foregroundStyle(RaverTheme.primaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func kindText(_ kind: String) -> String {
        switch kind {
        case "added":
            return LT("新增", "Added", "追加")
        case "removed":
            return LT("移除", "Removed", "削除")
        case "reordered":
            return LT("顺序调整", "Reordered", "並び替え")
        default:
            return LT("修改", "Updated", "変更")
        }
    }
}

@MainActor
private final class EntityChangeDetailViewModel: ObservableObject {
    @Published var phase: LoadPhase = .idle
    @Published var detail: EntityChangePublicDetail?

    private let changeLogID: String
    private let repository: NotificationRepository

    init(changeLogID: String, repository: NotificationRepository) {
        self.changeLogID = changeLogID
        self.repository = repository
    }

    func load() async {
        if case .initialLoading = phase { return }
        phase = .initialLoading
        do {
            let loaded = try await repository.fetchEntityChangePublicDetail(changeLogID: changeLogID)
            detail = loaded
            phase = loaded.publicChanges.isEmpty ? .empty : .success
        } catch {
            phase = .failure(message: error.userFacingMessage ?? LT("修改详情加载失败", "Failed to load change details", "変更詳細の読み込みに失敗しました"))
        }
    }
}

#if DEBUG
#Preview("Entity Change Detail") {
    NavigationStack {
        EntityChangeDetailView(
            changeLogID: "preview-change-log",
            repository: MockNotificationRepository()
        )
    }
}
#endif
