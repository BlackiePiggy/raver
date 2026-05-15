import SwiftUI

enum OperationBannerStyle {
    case success
    case info
    case warning
    case error

    var screenStyle: ScreenStatusBannerStyle {
        switch self {
        case .success:
            return .success
        case .info:
            return .info
        case .warning:
            return .warning
        case .error:
            return .error
        }
    }
}

enum OperationBannerAction {
    case none
    case appRoute(AppRoute, title: String = LT("点击跳转", "Open", "開く"))
    case custom(title: String, action: () -> Void)
}

struct OperationBannerItem: Identifiable {
    let id = UUID()
    let message: String
    let style: OperationBannerStyle
    let action: OperationBannerAction
}

@MainActor
final class OperationBannerCenter: ObservableObject {
    static let shared = OperationBannerCenter()

    @Published private(set) var current: OperationBannerItem?
    private var dismissTask: Task<Void, Never>?

    private init() {}

    func show(
        _ message: String,
        style: OperationBannerStyle = .success,
        action: OperationBannerAction = .none,
        autoDismissAfter seconds: TimeInterval = 3.0
    ) {
        dismissTask?.cancel()
        let item = OperationBannerItem(message: message, style: style, action: action)
        current = item

        guard seconds > 0 else {
            dismissTask = nil
            return
        }

        dismissTask = Task { [weak self] in
            let nanoseconds = UInt64(seconds * 1_000_000_000)
            try? await Task.sleep(nanoseconds: nanoseconds)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                guard self?.current?.id == item.id else { return }
                self?.current = nil
                self?.dismissTask = nil
            }
        }
    }

    func success(_ message: String, action: OperationBannerAction = .none) {
        show(message, style: .success, action: action)
    }

    func info(_ message: String, action: OperationBannerAction = .none) {
        show(message, style: .info, action: action)
    }

    func warning(_ message: String, action: OperationBannerAction = .none) {
        show(message, style: .warning, action: action)
    }

    func error(_ message: String, action: OperationBannerAction = .none) {
        show(message, style: .error, action: action)
    }

    func dismiss() {
        dismissTask?.cancel()
        dismissTask = nil
        current = nil
    }
}

enum OperationBannerPlacement: Equatable {
    case top
    case bottom

    var alignment: Alignment {
        switch self {
        case .top:
            return .top
        case .bottom:
            return .bottom
        }
    }
}

private struct OperationBannerHostModifier: ViewModifier {
    @ObservedObject private var center = OperationBannerCenter.shared
    @Environment(\.appPush) private var appPush

    let placement: OperationBannerPlacement
    let topPadding: CGFloat
    let bottomPadding: CGFloat
    let horizontalPadding: CGFloat

    func body(content: Content) -> some View {
        content
            .overlay(alignment: placement.alignment) {
                if let item = center.current {
                    banner(item)
                        .padding(.horizontal, horizontalPadding)
                        .padding(.top, placement == .top ? topPadding : 0)
                        .padding(.bottom, placement == .bottom ? bottomPadding : 0)
                        .transition(.move(edge: placement == .top ? .top : .bottom).combined(with: .opacity))
                        .zIndex(1000)
                }
            }
            .animation(.easeOut(duration: 0.22), value: center.current?.id)
    }

    private func banner(_ item: OperationBannerItem) -> some View {
        let actionTitle: String?
        let action: (() -> Void)?

        switch item.action {
        case .none:
            actionTitle = nil
            action = nil
        case .appRoute(let route, let title):
            actionTitle = title
            action = {
                center.dismiss()
                appPush(route)
            }
        case .custom(let title, let customAction):
            actionTitle = title
            action = {
                center.dismiss()
                customAction()
            }
        }

        return ScreenStatusBanner(
            message: item.message,
            style: item.style.screenStyle,
            actionTitle: actionTitle,
            action: action,
            onDismiss: {
                center.dismiss()
            }
        )
    }
}

extension View {
    func operationBannerHost(
        placement: OperationBannerPlacement = .top,
        topPadding: CGFloat = 40,
        bottomPadding: CGFloat = 32,
        horizontalPadding: CGFloat = 16
    ) -> some View {
        modifier(
            OperationBannerHostModifier(
                placement: placement,
                topPadding: topPadding,
                bottomPadding: bottomPadding,
                horizontalPadding: horizontalPadding
            )
        )
    }
}
