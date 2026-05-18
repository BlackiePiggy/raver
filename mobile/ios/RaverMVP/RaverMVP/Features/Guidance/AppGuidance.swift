import SwiftUI

enum AppGuidanceID: String, Hashable {
    case recommendEventsFirstRun
    case djSpotlightFirstRun
    case eventDetailTabsFirstRun
    case eventRoutePlannerFirstRun
    case eventDetailWidgetFirstRun
    case mainGlobalSearchFirstRun
    case eventsListTabsFirstRun
}

enum AppGuidanceJourney: String, CaseIterable {
    case eventDiscovery
    case eventDetailMastery
    case eventListBrowsing
    case djDiscovery
    case historicalSearch

    var steps: [AppGuidanceID] {
        switch self {
        case .eventDiscovery:
            return [.recommendEventsFirstRun]
        case .eventDetailMastery:
            return [
                .eventDetailWidgetFirstRun,
                .eventDetailTabsFirstRun,
                .eventRoutePlannerFirstRun
            ]
        case .eventListBrowsing:
            return [.eventsListTabsFirstRun]
        case .djDiscovery:
            return [.djSpotlightFirstRun]
        case .historicalSearch:
            return [.mainGlobalSearchFirstRun]
        }
    }
}

enum AppGuidancePresentationPolicy {
    case everyAppLaunchDuringDevelopment
    case oncePerUser
}

enum AppGuidanceDisplayMode {
    case centeredGlass
}

enum AppGuidanceRuntime {
    static let recommendEventsFirstRunPolicy: AppGuidancePresentationPolicy = .everyAppLaunchDuringDevelopment
    static let djSpotlightFirstRunPolicy: AppGuidancePresentationPolicy = .everyAppLaunchDuringDevelopment
    static let eventDetailTabsFirstRunPolicy: AppGuidancePresentationPolicy = .everyAppLaunchDuringDevelopment
    static let eventRoutePlannerFirstRunPolicy: AppGuidancePresentationPolicy = .everyAppLaunchDuringDevelopment
    static let eventDetailWidgetFirstRunPolicy: AppGuidancePresentationPolicy = .everyAppLaunchDuringDevelopment
    static let mainGlobalSearchFirstRunPolicy: AppGuidancePresentationPolicy = .everyAppLaunchDuringDevelopment
    static let eventsListTabsFirstRunPolicy: AppGuidancePresentationPolicy = .everyAppLaunchDuringDevelopment

    static let journeyOrder: [AppGuidanceJourney] = [
        .eventDiscovery,
        .eventDetailMastery,
        .eventListBrowsing,
        .djDiscovery,
        .historicalSearch
    ]

    static func policy(for id: AppGuidanceID) -> AppGuidancePresentationPolicy {
        switch id {
        case .recommendEventsFirstRun:
            return recommendEventsFirstRunPolicy
        case .djSpotlightFirstRun:
            return djSpotlightFirstRunPolicy
        case .eventDetailTabsFirstRun:
            return eventDetailTabsFirstRunPolicy
        case .eventRoutePlannerFirstRun:
            return eventRoutePlannerFirstRunPolicy
        case .eventDetailWidgetFirstRun:
            return eventDetailWidgetFirstRunPolicy
        case .mainGlobalSearchFirstRun:
            return mainGlobalSearchFirstRunPolicy
        case .eventsListTabsFirstRun:
            return eventsListTabsFirstRunPolicy
        }
    }
}

struct AppGuidanceStep: Equatable {
    let title: String
    let message: String
    let buttonTitle: String
    let iconName: String
    let buttonIconName: String
    let visualKind: AppGuidanceVisualKind
}

enum AppGuidanceVisualKind: Equatable {
    case tap
    case swipeLeft
    case swipeHorizontal
}

enum AppGuidanceSpotlightTextPlacement {
    case below
    case above
    case center
}

struct AppGuidanceSpotlightStep: Equatable {
    let title: String
    let message: String
    let buttonTitle: String
    let targetFrame: CGRect
    var cornerRadius: CGFloat = 14
    var placement: AppGuidanceSpotlightTextPlacement = .below
}

@MainActor
final class AppGuidanceCenter: ObservableObject {
    static let shared = AppGuidanceCenter()

    private let defaults: UserDefaults
    private var presentedThisLaunch: Set<AppGuidanceID> = []

    private init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func shouldPresent(
        _ id: AppGuidanceID,
        policy: AppGuidancePresentationPolicy,
        userID: String?
    ) -> Bool {
        guard isNextScriptedStep(id, userID: userID) else { return false }

        switch policy {
        case .everyAppLaunchDuringDevelopment:
            return !presentedThisLaunch.contains(id)
        case .oncePerUser:
            guard let userID else { return false }
            return !defaults.bool(forKey: persistentKey(for: id, userID: userID))
        }
    }

    func markPresented(
        _ id: AppGuidanceID,
        policy: AppGuidancePresentationPolicy,
        userID: String?
    ) {
        switch policy {
        case .everyAppLaunchDuringDevelopment:
            presentedThisLaunch.insert(id)
        case .oncePerUser:
            guard let userID else { return }
            defaults.set(true, forKey: persistentKey(for: id, userID: userID))
        }
    }

    private func persistentKey(for id: AppGuidanceID, userID: String) -> String {
        "guidance.seen.\(userID).\(id.rawValue)"
    }

    private func isNextScriptedStep(_ id: AppGuidanceID, userID: String?) -> Bool {
        let orderedSteps = AppGuidanceRuntime.journeyOrder.flatMap(\.steps)
        guard orderedSteps.contains(id) else { return true }

        return orderedSteps.first { !isCompleted($0, userID: userID) } == id
    }

    private func isCompleted(_ id: AppGuidanceID, userID: String?) -> Bool {
        switch AppGuidanceRuntime.policy(for: id) {
        case .everyAppLaunchDuringDevelopment:
            return presentedThisLaunch.contains(id)
        case .oncePerUser:
            guard let userID else { return false }
            return defaults.bool(forKey: persistentKey(for: id, userID: userID))
        }
    }
}

struct AppGuidanceOverlay: View {
    let step: AppGuidanceStep
    let handOffset: CGFloat
    var displayMode: AppGuidanceDisplayMode = .centeredGlass
    let onPrimary: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color.black.opacity(0.48),
                    Color.black.opacity(0.66),
                    Color.black.opacity(0.54)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            .onTapGesture(perform: onDismiss)

            VStack(spacing: 20) {
                guideVisual

                VStack(spacing: 8) {
                    Text(step.title)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)

                    Text(step.message)
                        .font(.system(size: 14, weight: .medium))
                        .lineSpacing(2)
                        .foregroundStyle(.white.opacity(0.76))
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Button(action: onPrimary) {
                    HStack(spacing: 8) {
                        Text(step.buttonTitle)
                        Image(systemName: step.buttonIconName)
                            .font(.system(size: 13, weight: .bold))
                    }
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.black.opacity(0.88))
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(
                        Capsule()
                            .fill(Color.white.opacity(0.92))
                            .shadow(color: Color.white.opacity(0.18), radius: 14, x: 0, y: 0)
                    )
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 26)
            .frame(maxWidth: 330)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
            .background(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(Color.black.opacity(0.26))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.30),
                                Color.white.opacity(0.08)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(color: Color.black.opacity(0.42), radius: 34, x: 0, y: 18)
            .padding(.horizontal, 24)
        }
    }

    private var guideVisual: some View {
        ZStack {
            switch step.visualKind {
            case .tap:
                Circle()
                    .stroke(Color.white.opacity(0.46), lineWidth: 1.5)
                    .frame(width: 50, height: 50)
                    .overlay(
                        Circle()
                            .stroke(Color(red: 0.16, green: 0.95, blue: 0.92).opacity(0.48), lineWidth: 1)
                            .frame(width: 66, height: 66)
                    )
                    .opacity(0.82)
            case .swipeLeft:
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                    Image(systemName: "chevron.left")
                }
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(Color(red: 0.16, green: 0.95, blue: 0.92).opacity(0.88))
                .offset(x: -42)
            case .swipeHorizontal:
                HStack(spacing: 44) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Image(systemName: "chevron.left")
                    }
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.right")
                        Image(systemName: "chevron.right")
                    }
                }
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(Color(red: 0.16, green: 0.95, blue: 0.92).opacity(0.88))
            }

            Image(systemName: step.iconName)
                .font(.system(size: 30, weight: .semibold))
                .foregroundStyle(.white)
                .offset(x: step.visualKind == .tap ? 0 : handOffset, y: 22)
                .shadow(color: Color(red: 0.16, green: 0.95, blue: 0.92).opacity(0.38), radius: 14, x: 0, y: 0)
                .shadow(color: Color.black.opacity(0.30), radius: 10, x: 0, y: 5)
        }
        .frame(width: 154, height: 102)
    }
}

struct AppGuidanceSpotlightOverlay: View {
    let step: AppGuidanceSpotlightStep
    let onPrimary: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        GeometryReader { proxy in
            let bounds = CGRect(origin: .zero, size: proxy.size)
            let target = normalizedTarget(in: bounds)

            ZStack {
                AppGuidanceSpotlightScrim(targetFrame: target, cornerRadius: step.cornerRadius)
                    .ignoresSafeArea()
                    .onTapGesture(perform: onDismiss)

                RoundedRectangle(cornerRadius: step.cornerRadius, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.94),
                                Color(red: 0.16, green: 0.95, blue: 0.92).opacity(0.88)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 2
                    )
                    .shadow(color: Color(red: 0.16, green: 0.95, blue: 0.92).opacity(0.58), radius: 16, x: 0, y: 0)
                    .shadow(color: Color.black.opacity(0.34), radius: 20, x: 0, y: 10)
                    .frame(width: target.width, height: target.height)
                    .position(x: target.midX, y: target.midY)
                    .allowsHitTesting(false)

                instructionCard(in: bounds, target: target)
            }
            .animation(.easeInOut(duration: 0.22), value: step.targetFrame)
        }
    }

    private func normalizedTarget(in bounds: CGRect) -> CGRect {
        let expanded = step.targetFrame.insetBy(dx: -8, dy: -7)
        let width = min(max(expanded.width, 48), bounds.width - 24)
        let height = min(max(expanded.height, 38), bounds.height - 24)
        let minX = min(max(expanded.midX - width / 2, 12), bounds.width - width - 12)
        let minY = min(max(expanded.midY - height / 2, 12), bounds.height - height - 12)
        return CGRect(x: minX, y: minY, width: width, height: height)
    }

    private func instructionCard(in bounds: CGRect, target: CGRect) -> some View {
        let cardWidth = min(bounds.width - 44, 340)
        let cardHeight: CGFloat = 178
        let cardY = cardCenterY(bounds: bounds, target: target, cardHeight: cardHeight)

        return VStack(alignment: .leading, spacing: 12) {
            Text(step.title)
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(.white)

            Text(step.message)
                .font(.system(size: 14, weight: .medium))
                .lineSpacing(2)
                .foregroundStyle(.white.opacity(0.78))
                .fixedSize(horizontal: false, vertical: true)

            Button(action: onPrimary) {
                HStack(spacing: 8) {
                    Text(step.buttonTitle)
                    Image(systemName: "arrow.right")
                        .font(.system(size: 13, weight: .bold))
                }
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.black.opacity(0.88))
                .frame(maxWidth: .infinity)
                .frame(height: 46)
                .background(Capsule().fill(Color.white.opacity(0.92)))
            }
            .buttonStyle(.plain)
        }
        .padding(20)
        .frame(width: cardWidth, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(Color.black.opacity(0.28))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(Color.white.opacity(0.20), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.38), radius: 26, x: 0, y: 14)
        .position(x: bounds.midX, y: cardY)
    }

    private func cardCenterY(bounds: CGRect, target: CGRect, cardHeight: CGFloat) -> CGFloat {
        switch step.placement {
        case .below:
            let desired = target.maxY + 24 + cardHeight / 2
            if desired + cardHeight / 2 <= bounds.maxY - 24 {
                return desired
            }
            return max(24 + cardHeight / 2, target.minY - 24 - cardHeight / 2)
        case .above:
            let desired = target.minY - 24 - cardHeight / 2
            if desired - cardHeight / 2 >= bounds.minY + 24 {
                return desired
            }
            return min(bounds.maxY - 24 - cardHeight / 2, target.maxY + 24 + cardHeight / 2)
        case .center:
            return bounds.midY
        }
    }
}

private struct AppGuidanceSpotlightScrim: View {
    let targetFrame: CGRect
    let cornerRadius: CGFloat

    var body: some View {
        Canvas { context, size in
            let bounds = CGRect(origin: .zero, size: size)
            var path = Path(bounds)
            path.addPath(Path(roundedRect: targetFrame, cornerRadius: cornerRadius))
            context.fill(path, with: .color(Color.black.opacity(0.58)), style: FillStyle(eoFill: true))

            let foldHeight: CGFloat = 22
            for index in 0..<7 {
                let y = CGFloat(index) * (size.height / 6)
                var fold = Path()
                fold.move(to: CGPoint(x: 0, y: y))
                fold.addCurve(
                    to: CGPoint(x: size.width, y: y + CGFloat(index.isMultiple(of: 2) ? 10 : -8)),
                    control1: CGPoint(x: size.width * 0.28, y: y + foldHeight),
                    control2: CGPoint(x: size.width * 0.70, y: y - foldHeight)
                )
                context.stroke(fold, with: .color(Color.white.opacity(0.035)), lineWidth: 1)
            }
        }
        .background(
            LinearGradient(
                colors: [
                    Color.black.opacity(0.18),
                    Color.black.opacity(0.34),
                    Color.black.opacity(0.22)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }
}
