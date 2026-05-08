import SwiftUI

struct GlobalSearchOverlayView: View {
    @ObservedObject var recentStore: RecentSearchStore
    let onDismiss: () -> Void
    let onSearch: (String) -> Void

    @State private var query = ""
    @FocusState private var isInputFocused: Bool

    private var trimmedQuery: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        ZStack {
            Rectangle()
                .fill(Color.black.opacity(0.18))
                .background(.ultraThinMaterial)
                .ignoresSafeArea()
                .onTapGesture {
                    dismiss()
                }

            searchPanel
                .frame(maxWidth: 420)
                .padding(.horizontal, 18)
                .transition(.scale(scale: 0.96).combined(with: .opacity))
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                isInputFocused = true
            }
        }
    }

    private var searchPanel: some View {
        VStack(alignment: .leading, spacing: 16) {
            panelHeader
            searchField
            recentSearches
            scopeHints
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(RaverTheme.card.opacity(0.92))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(RaverTheme.cardBorder, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.20), radius: 24, x: 0, y: 14)
    }

    private var panelHeader: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 7) {
                    Image(systemName: "sparkles")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(RaverTheme.accent)
                    Text(L("全局聚合搜索", "Global Search"))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(RaverTheme.secondaryText)
                }

                Text(L("搜索 Raver 里的内容", "Search across Raver"))
                    .font(.title3.weight(.bold))
                    .foregroundStyle(RaverTheme.primaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
            }

            Spacer(minLength: 8)

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(RaverTheme.secondaryText)
                    .frame(width: 34, height: 34)
                    .background(RaverTheme.cardBorder.opacity(0.5), in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(L("关闭搜索", "Close search"))
        }
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.headline.weight(.semibold))
                .foregroundStyle(RaverTheme.secondaryText)

            TextField(
                L("搜索活动、资讯、DJ、Sets、榜单、打分、圈子内容", "Search events, news, DJs, sets, rankings, ratings, posts"),
                text: $query
            )
            .font(.headline)
            .foregroundStyle(RaverTheme.primaryText)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled(true)
            .submitLabel(.search)
            .focused($isInputFocused)
            .onSubmit {
                submit()
            }

            if !trimmedQuery.isEmpty {
                Button {
                    query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(RaverTheme.secondaryText.opacity(0.8))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(L("清空关键词", "Clear query"))
            }

            Button {
                submit()
            } label: {
                Image(systemName: "arrow.right")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(width: 34, height: 34)
                    .background(
                        RaverTheme.accent.opacity(trimmedQuery.isEmpty ? 0.42 : 1),
                        in: Circle()
                    )
            }
            .buttonStyle(.plain)
            .disabled(trimmedQuery.isEmpty)
            .accessibilityLabel(L("搜索", "Search"))
        }
        .padding(.horizontal, 13)
        .frame(height: 54)
        .background(RaverTheme.background.opacity(0.62), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(RaverTheme.cardBorder, lineWidth: 1)
        )
    }

    @ViewBuilder
    private var recentSearches: some View {
        if !recentStore.queries.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(L("最近搜索", "Recent Searches"))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(RaverTheme.primaryText)
                    Spacer()
                    Button(L("清空", "Clear")) {
                        recentStore.clear()
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(RaverTheme.secondaryText)
                    .buttonStyle(.plain)
                }

                FlowLayout(spacing: 8, rowSpacing: 8) {
                    ForEach(recentStore.queries, id: \.self) { item in
                        Button {
                            submit(item)
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "clock")
                                    .font(.caption2.weight(.semibold))
                                Text(item)
                                    .font(.caption.weight(.semibold))
                                    .lineLimit(1)
                            }
                            .foregroundStyle(RaverTheme.primaryText)
                            .padding(.horizontal, 10)
                            .frame(height: 30)
                            .background(RaverTheme.background.opacity(0.64), in: Capsule())
                            .overlay(
                                Capsule()
                                    .strokeBorder(RaverTheme.cardBorder, lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var scopeHints: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L("可以搜索", "Searchable Content"))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(RaverTheme.primaryText)

            FlowLayout(spacing: 8, rowSpacing: 8) {
                ForEach(GlobalSearchScopeHint.all) { item in
                    HStack(spacing: 6) {
                        Image(systemName: item.systemImage)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(item.tint)
                            .frame(width: 14)
                        Text(item.title)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(RaverTheme.primaryText)
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 10)
                    .frame(height: 30)
                    .background(item.tint.opacity(0.12), in: Capsule())
                    .overlay(
                        Capsule()
                            .strokeBorder(item.tint.opacity(0.18), lineWidth: 1)
                    )
                }
            }
        }
    }

    private func submit() {
        submit(trimmedQuery)
    }

    private func submit(_ rawQuery: String) {
        let keyword = rawQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !keyword.isEmpty else { return }
        recentStore.record(keyword)
        isInputFocused = false
        onSearch(keyword)
    }

    private func dismiss() {
        isInputFocused = false
        onDismiss()
    }
}

private struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    var rowSpacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? 0
        let height = arrangedHeight(maxWidth: maxWidth, subviews: subviews)
        return CGSize(width: maxWidth, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0
        let maxX = bounds.maxX

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > bounds.minX, x + size.width > maxX {
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
