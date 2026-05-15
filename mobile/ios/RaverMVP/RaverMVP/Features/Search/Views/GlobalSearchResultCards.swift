import SwiftUI

struct GlobalSearchResultCard: View {
    let item: GlobalSearchItem
    let onOpen: (GlobalSearchItem) -> Void

    var body: some View {
        Button {
            onOpen(item)
        } label: {
            HStack(spacing: 12) {
                thumbnail

                VStack(alignment: .leading, spacing: 7) {
                    HStack(spacing: 7) {
                        GlobalSearchDomainBadge(item: item)
                        if let badge = item.badgeText, !badge.isEmpty {
                            Text(badge)
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(RaverTheme.secondaryText)
                                .lineLimit(1)
                        }
                    }

                    Text(item.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(RaverTheme.primaryText)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    if let subtitle = item.subtitle, !subtitle.isEmpty {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(RaverTheme.secondaryText)
                            .lineLimit(1)
                    }

                    if let summary = item.summary, !summary.isEmpty {
                        Text(summary)
                            .font(.caption)
                            .foregroundStyle(RaverTheme.secondaryText.opacity(0.88))
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                    }
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(RaverTheme.secondaryText.opacity(0.7))
            }
            .padding(12)
            .background(RaverTheme.card, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(RaverTheme.cardBorder, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityText)
        .accessibilityHint(LT("打开搜索结果详情", "Opens the search result detail", "検索結果詳細を開きます"))
        .accessibilityIdentifier("globalSearch.result.\(item.type.rawValue).\(item.entityID)")
    }

    private var thumbnail: some View {
        ZStack {
            if let imageUrl = item.imageUrl {
                ImageLoaderView(urlString: imageUrl, resizingMode: .fill)
            } else {
                LinearGradient(
                    colors: [
                        item.tab.themeColor.opacity(0.34),
                        RaverTheme.background
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                Image(systemName: item.type.systemImage)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(item.tab.themeColor)
            }
        }
        .frame(width: 58, height: 58)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var accessibilityText: String {
        [item.type.title, item.title, item.subtitle, item.summary]
            .compactMap { value in
                let trimmed = (value ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                return trimmed.isEmpty ? nil : trimmed
            }
            .joined(separator: ", ")
    }
}

struct GlobalSearchDomainBadge: View {
    let item: GlobalSearchItem

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: item.type.systemImage)
                .font(.caption2.weight(.bold))
            Text(item.type.title)
                .font(.caption2.weight(.bold))
                .lineLimit(1)
        }
        .foregroundStyle(item.tab.themeColor)
        .padding(.horizontal, 7)
        .frame(height: 22)
        .background(item.tab.themeColor.opacity(0.12), in: Capsule())
        .overlay(
            Capsule()
                .strokeBorder(item.tab.themeColor.opacity(0.18), lineWidth: 1)
        )
    }
}

struct GlobalSearchSummaryStrip: View {
    let query: String
    let totalCount: Int
    let hasPartialFailures: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(RaverTheme.accent)
                Text(LT("找到与 “\(query)” 相关的内容", "Results related to \"\(query)\"", "「\(query)」に関連する内容"))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(RaverTheme.primaryText)
                    .lineLimit(1)
                Spacer(minLength: 0)
                Text("\(totalCount)")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .frame(height: 24)
                    .background(RaverTheme.accent, in: Capsule())
            }

            if hasPartialFailures {
                HStack(spacing: 7) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.caption2.weight(.bold))
                    Text(LT("部分结果暂时不可用", "Some results are temporarily unavailable", "一部の結果は一時的に利用できません"))
                        .font(.caption.weight(.semibold))
                }
                .foregroundStyle(Color.orange)
            }
        }
        .padding(12)
        .background(RaverTheme.card, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(RaverTheme.cardBorder, lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(LT("找到与 \(query) 相关的 \(totalCount) 条内容", "\(totalCount) results related to \(query)", "\(query) に関連する結果 \(totalCount)件"))
    }
}

struct GlobalSearchEmptyState: View {
    let query: String

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(RaverTheme.accent)
                .frame(width: 70, height: 70)
                .background(RaverTheme.accent.opacity(0.12), in: Circle())

            Text(LT("没有找到相关内容", "No Results Found", "関連内容が見つかりません"))
                .font(.title3.weight(.bold))
                .foregroundStyle(RaverTheme.primaryText)

            Text(LT("换个关键词试试，也可以从这些内容开始探索。", "Try another keyword, or start exploring from these content areas.", "別のキーワードを試すか、これらの内容から探索を始めてください。"))
                .font(.subheadline)
                .foregroundStyle(RaverTheme.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            GlobalSearchFlowLayout(spacing: 8, rowSpacing: 8) {
                ForEach(GlobalSearchPlatformStatHint.all) { hint in
                    HStack(spacing: 6) {
                        Image(systemName: hint.systemImage)
                            .font(.caption2.weight(.bold))
                        Text(hint.title)
                            .lineLimit(1)
                            .minimumScaleFactor(0.86)
                    }
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(hint.tint)
                        .padding(.horizontal, 10)
                        .frame(height: 30)
                        .background(hint.tint.opacity(0.12), in: Capsule())
                }
            }
            .padding(.top, 2)
            .padding(.horizontal, 16)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 44)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(LT("没有找到与 \(query) 相关的内容", "No results found for \(query)", "\(query) に関連する内容は見つかりません"))
    }
}

private struct GlobalSearchFlowLayout: Layout {
    var spacing: CGFloat = 8
    var rowSpacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? 0
        return CGSize(width: maxWidth, height: arrangedHeight(maxWidth: maxWidth, subviews: subviews))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > bounds.minX, x + size.width > bounds.maxX {
                x = bounds.minX
                y += rowHeight + rowSpacing
                rowHeight = 0
            }

            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }

    private func arrangedHeight(maxWidth: CGFloat, subviews: Subviews) -> CGFloat {
        guard !subviews.isEmpty else { return 0 }
        var x: CGFloat = 0
        var height: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0, x + size.width > maxWidth {
                height += rowHeight + rowSpacing
                x = 0
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }

        return height + rowHeight
    }
}

struct GlobalSearchErrorState: View {
    let message: String
    let onRetry: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 32, weight: .semibold))
                .foregroundStyle(Color.orange)
                .frame(width: 64, height: 64)
                .background(Color.orange.opacity(0.12), in: Circle())

            Text(message)
                .font(.subheadline)
                .foregroundStyle(RaverTheme.secondaryText)
                .multilineTextAlignment(.center)

            Button {
                onRetry()
            } label: {
                Label(LT("重试", "Retry", "再試行"), systemImage: "arrow.clockwise")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .frame(height: 38)
                    .background(RaverTheme.accent, in: Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("globalSearch.error.retry")
            .accessibilityLabel(LT("重试搜索", "Retry search", "検索を再試行"))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 24)
        .accessibilityElement(children: .contain)
    }
}

struct GlobalSearchLoadingState: View {
    var body: some View {
        VStack(spacing: 10) {
            ForEach(0..<6, id: \.self) { _ in
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(RaverTheme.card)
                    .frame(height: 82)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(RaverTheme.cardBorder, lineWidth: 1)
                    )
            }
        }
        .padding(16)
        .redacted(reason: .placeholder)
        .accessibilityLabel(LT("搜索结果加载中", "Search results loading", "検索結果を読み込み中"))
    }
}

struct GlobalSearchLoginRequiredView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "lock.fill")
                .font(.system(size: 30, weight: .bold))
                .foregroundStyle(RaverTheme.accent)
                .frame(width: 58, height: 58)
                .background(RaverTheme.accent.opacity(0.12), in: Circle())

            Text(LT("请先登录", "Login Required", "ログインが必要です"))
                .font(.headline.weight(.bold))
                .foregroundStyle(RaverTheme.primaryText)

            Text(LT("登录后才能使用全局聚合搜索。", "Log in to use global search.", "グローバル検索を使うにはログインしてください。"))
                .font(.subheadline)
                .foregroundStyle(RaverTheme.secondaryText)
                .multilineTextAlignment(.center)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(RaverTheme.background)
        .raverSystemNavigation(title: LT("搜索", "Search", "検索"))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("globalSearch.loginRequired")
    }
}
