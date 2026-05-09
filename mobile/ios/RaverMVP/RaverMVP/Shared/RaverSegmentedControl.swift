import SwiftUI

struct RaverSegmentedControl<ID: Hashable>: View {
    let items: [ID]
    @Binding var selection: ID
    let title: (ID) -> String
    var iconName: ((ID) -> String?)? = nil

    @Namespace private var namespace

    var body: some View {
        HStack(spacing: 6) {
            ForEach(items, id: \.self) { item in
                Button {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.84)) {
                        selection = item
                    }
                } label: {
                    segmentContent(for: item)
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selection == item ? .isSelected : [])
            }
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(RaverTheme.card.opacity(0.94))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(RaverTheme.cardBorder.opacity(0.78), lineWidth: 1)
        )
    }

    private func segmentContent(for item: ID) -> some View {
        let isSelected = selection == item
        return HStack(spacing: 6) {
            if let icon = iconName?(item) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)
            }

            Text(title(item))
                .font(.caption.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.76)
        }
        .foregroundStyle(isSelected ? Color.white : RaverTheme.secondaryText)
        .frame(maxWidth: .infinity, minHeight: 34)
        .padding(.horizontal, 8)
        .background {
            if isSelected {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                RaverTheme.tabBarSelectionStart,
                                RaverTheme.accent,
                                RaverTheme.tabBarSelectionEnd
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(RaverTheme.tabBarSelectionStroke, lineWidth: 1)
                    )
                    .matchedGeometryEffect(id: "raver-segment-\(String(describing: ID.self))", in: namespace)
            }
        }
        .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}
