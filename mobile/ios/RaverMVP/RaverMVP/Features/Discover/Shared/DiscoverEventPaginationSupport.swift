import SwiftUI

struct DiscoverPagedEventSection<Item: Identifiable, RowContent: View>: View {
    let items: [Item]
    let hasMore: Bool
    let isLoadingMore: Bool
    let onLoadMore: () async -> Void
    @ViewBuilder let rowContent: (Item) -> RowContent

    private var triggerItemID: Item.ID? {
        guard hasMore, !isLoadingMore, !items.isEmpty else { return nil }
        let triggerIndex = max(0, items.count - 5)
        return items[triggerIndex].id
    }

    var body: some View {
        ForEach(items) { item in
            rowContent(item)
                .onAppear {
                    guard hasMore, !isLoadingMore else { return }
                    guard item.id == triggerItemID else { return }
                    Task { await onLoadMore() }
                }
        }

        if isLoadingMore {
            HStack {
                Spacer()
                ProgressView()
                    .padding(.top, 8)
                Spacer()
            }
        }
    }
}

struct DiscoverSectionLoadMoreButton: View {
    let hasMore: Bool
    let isLoadingMore: Bool
    let title: String
    let action: () -> Void

    var body: some View {
        if hasMore || isLoadingMore {
            Button(action: action) {
                Group {
                    if isLoadingMore {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Text(title)
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(.vertical, 10)
            }
            .buttonStyle(.bordered)
            .disabled(isLoadingMore)
            .padding(.top, 8)
        }
    }
}

struct DiscoverEventFeedSectionConfig {
    let title: String
    let events: [WebEvent]
    let hasMore: Bool
    let isLoadingMore: Bool
    let onLoadMore: () async -> Void
}

struct DiscoverStandardEventFeedTab: View {
    let primaryActionTitle: String?
    let primaryActionAction: (() -> Void)?
    let isLoading: Bool
    let didLoad: Bool
    let didFail: Bool
    let loadingTitle: String
    let emptyTitle: String
    let retry: () async -> Void
    let sections: [DiscoverEventFeedSectionConfig]
    let onOpenEvent: (WebEvent) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let primaryActionTitle, let primaryActionAction {
                Button(action: primaryActionAction) {
                    HStack(spacing: 8) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 16, weight: .bold))
                        Text(primaryActionTitle)
                            .font(.subheadline.weight(.semibold))
                    }
                    .foregroundStyle(Color.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(RaverTheme.accent)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)
            }

            if isLoading && sections.allSatisfy({ $0.events.isEmpty }) {
                ProgressView(loadingTitle)
                    .padding(.vertical, 8)
            } else if sections.allSatisfy({ $0.events.isEmpty }) && !didLoad {
                DiscoverEventFeedPlaceholder(
                    title: loadingTitle,
                    didFail: didFail,
                    retry: retry
                )
            } else if sections.allSatisfy({ $0.events.isEmpty }) {
                Text(emptyTitle)
                    .foregroundStyle(RaverTheme.secondaryText)
                    .padding(.vertical, 8)
            } else {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(sections.enumerated()), id: \.offset) { _, section in
                        if !section.events.isEmpty {
                            DiscoverStandardEventSectionHeader(section.title)
                            DiscoverPagedEventSection(
                                items: section.events,
                                hasMore: section.hasMore,
                                isLoadingMore: section.isLoadingMore,
                                onLoadMore: section.onLoadMore
                            ) { event in
                                Button {
                                    onOpenEvent(event)
                                } label: {
                                    DiscoverStandardEventRow(event: event)
                                }
                                .buttonStyle(.plain)
                            }
                            DiscoverSectionLoadMoreButton(
                                hasMore: section.hasMore,
                                isLoadingMore: section.isLoadingMore,
                                title: LT("加载更多活动", "Load More Events", "イベントをさらに表示")
                            ) {
                                Task { await section.onLoadMore() }
                            }
                        }
                    }
                }
            }
        }
    }
}

private struct DiscoverEventFeedPlaceholder: View {
    let title: String
    let didFail: Bool
    let retry: () async -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if didFail {
                Text(LT("加载失败，请重试", "Failed to load. Please retry.", "読み込みに失敗しました。再試行してください。"))
                    .font(.subheadline)
                    .foregroundStyle(RaverTheme.secondaryText)

                Button(LT("重新加载", "Retry", "再読み込み")) {
                    Task { await retry() }
                }
                .buttonStyle(.borderedProminent)
            } else {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text(title)
                        .font(.subheadline)
                        .foregroundStyle(RaverTheme.secondaryText)
                }
            }
        }
        .padding(.vertical, 8)
    }
}

private struct DiscoverStandardEventSectionHeader: View {
    let title: String

    init(_ title: String) {
        self.title = title
    }

    var body: some View {
        Text(title)
            .font(.headline)
            .foregroundStyle(RaverTheme.primaryText)
            .padding(.top, 6)
            .padding(.bottom, 2)
    }
}

private struct DiscoverStandardEventRow: View {
    let event: WebEvent

    var body: some View {
        let locationText = event.unifiedAddress.trimmingCharacters(in: .whitespacesAndNewlines)

        HStack(alignment: .top, spacing: 10) {
            DiscoverStandardEventCoverImage(event: event)
                .frame(width: 72, height: 72)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(event.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(RaverTheme.primaryText)
                    .lineLimit(2)

                Text(event.startDate.appLocalizedDateRangeText(to: event.endDate, timeZone: event.eventTimeZone))
                    .font(.caption)
                    .foregroundStyle(RaverTheme.secondaryText)
                    .lineLimit(1)

                Text(locationText.isEmpty ? LT("地点待补充", "Location pending", "場所は未設定") : locationText)
                    .font(.caption)
                    .foregroundStyle(RaverTheme.secondaryText)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 8)
        .overlay(alignment: .bottom) {
            Divider().opacity(0.45)
        }
    }
}

private struct DiscoverStandardEventCoverImage: View {
    let event: WebEvent

    var body: some View {
        if let cover = AppConfig.resolvedURLString(event.cardImageURL) {
            ImageLoaderView(urlString: cover)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(RaverTheme.card)
                )
#if DEBUG
                .onAppear {
                    debugLogCardSelection(surface: "discover-standard-row")
                }
#endif
        } else {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [RaverTheme.accent.opacity(0.35), RaverTheme.card],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    Image(systemName: "ticket.fill")
                        .font(.title3)
                        .foregroundStyle(RaverTheme.secondaryText)
                )
        }
    }

#if DEBUG
    private func debugLogCardSelection(surface: String) {
        guard event.id == "e87c26d3-a3eb-4ae5-a221-49e074ce905d" else { return }
        print(
            "[EventCardDebug] surface=\(surface) eventId=\(event.id) " +
            "card=\(event.cardImageURL ?? "nil") cover=\(event.coverImageUrl ?? "nil") " +
            "lineup=\(event.lineupImageUrl ?? "nil") posterCandidates=\(event.posterAssetURLs.count) " +
            "lineupAssets=\(event.lineupAssetURLs.count)"
        )
    }
#endif
}
