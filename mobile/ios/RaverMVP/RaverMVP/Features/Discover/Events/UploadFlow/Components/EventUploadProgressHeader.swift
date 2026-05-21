import SwiftUI

struct EventUploadProgressHeader: View {
    let currentStep: EventUploadStep

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("\(currentIndex + 1)/\(EventUploadStep.allCases.count) · \(currentStep.title)")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(RaverTheme.secondaryText)
            HStack(spacing: 6) {
                ForEach(EventUploadStep.allCases) { step in
                    Capsule()
                        .fill(fillColor(for: step))
                        .frame(height: 6)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
        .padding(.bottom, 14)
        .background(RaverTheme.background)
    }

    private var currentIndex: Int {
        EventUploadStep.allCases.firstIndex(of: currentStep) ?? 0
    }

    private func fillColor(for step: EventUploadStep) -> Color {
        let index = EventUploadStep.allCases.firstIndex(of: step) ?? 0
        return index <= currentIndex ? RaverTheme.accent : RaverTheme.cardBorder
    }
}
