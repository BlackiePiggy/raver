import SwiftUI

struct OrganizerUploadProgressHeader: View {
    let currentStep: OrganizerUploadStep
    let hasIssue: (OrganizerUploadStep) -> Bool
    let isCompleted: (OrganizerUploadStep) -> Bool
    let canNavigate: (OrganizerUploadStep) -> Bool
    let onSelect: (OrganizerUploadStep) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("\(currentIndex + 1)/\(OrganizerUploadStep.allCases.count) · \(currentStep.title)")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(RaverTheme.secondaryText)
            HStack(spacing: 6) {
                ForEach(OrganizerUploadStep.allCases) { step in
                    Button {
                        onSelect(step)
                    } label: {
                        VStack(spacing: 8) {
                            Capsule()
                                .fill(fillColor(for: step))
                                .frame(height: 6)
                            Text(step.title)
                                .font(.caption2.weight(step == currentStep ? .bold : .semibold))
                                .foregroundStyle(labelColor(for: step))
                                .lineLimit(1)
                        }
                    }
                    .buttonStyle(.plain)
                    .disabled(step == currentStep || !canNavigate(step))
                    .opacity(step == currentStep || canNavigate(step) ? 1 : 0.72)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
        .padding(.bottom, 14)
        .background(RaverTheme.background)
    }

    private var currentIndex: Int {
        OrganizerUploadStep.allCases.firstIndex(of: currentStep) ?? 0
    }

    private func fillColor(for step: OrganizerUploadStep) -> Color {
        if hasIssue(step) {
            return .orange
        }
        if step == currentStep || isCompleted(step) {
            return RaverTheme.accent
        }
        return RaverTheme.cardBorder
    }

    private func labelColor(for step: OrganizerUploadStep) -> Color {
        if hasIssue(step) {
            return .orange
        }
        if step == currentStep {
            return RaverTheme.primaryText
        }
        if isCompleted(step) {
            return RaverTheme.accent
        }
        return RaverTheme.secondaryText
    }
}
