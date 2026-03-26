import SwiftUI
import UIKit

struct EventDetailRepresentable: UIViewControllerRepresentable {
    let heroView: AnyView
    let eventTitle: String
    let tabTitles: [String]
    let tabBarView: AnyView
    let tabPageViews: [AnyView]
    let selectedIndex: Int
    let pageProgress: CGFloat
    let onTabChange: (Int) -> Void
    let onPageProgress: (CGFloat) -> Void

    @EnvironmentObject private var appState: AppState

    func makeUIViewController(context: Context) -> EventDetailScrollViewController {
        let controller = EventDetailScrollViewController()
        controller.onTabIndexChange = { [weak coordinator = context.coordinator] index in
            coordinator?.relayTabChange(index)
        }
        controller.onPageProgressChange = { [weak coordinator = context.coordinator] progress in
            coordinator?.relayPageProgress(progress)
        }

        context.coordinator.scrollController = controller
        context.coordinator.onTabChange = onTabChange
        context.coordinator.onPageProgress = onPageProgress

        controller.update(
            heroView: wrapped(heroView),
            eventTitle: eventTitle,
            tabTitles: tabTitles,
            tabBarView: wrapped(tabBarView),
            tabPageViews: tabPageViews.map(wrapped),
            selectedIndex: selectedIndex,
            pageProgress: pageProgress,
            animatedSelection: false
        )
        return controller
    }

    func updateUIViewController(_ uiViewController: EventDetailScrollViewController, context: Context) {
        context.coordinator.scrollController = uiViewController
        context.coordinator.onTabChange = onTabChange
        context.coordinator.onPageProgress = onPageProgress

        uiViewController.onTabIndexChange = { [weak coordinator = context.coordinator] index in
            coordinator?.relayTabChange(index)
        }
        uiViewController.onPageProgressChange = { [weak coordinator = context.coordinator] progress in
            coordinator?.relayPageProgress(progress)
        }

        uiViewController.update(
            heroView: wrapped(heroView),
            eventTitle: eventTitle,
            tabTitles: tabTitles,
            tabBarView: wrapped(tabBarView),
            tabPageViews: tabPageViews.map(wrapped),
            selectedIndex: selectedIndex,
            pageProgress: pageProgress,
            animatedSelection: true
        )
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    private func wrapped(_ view: AnyView) -> AnyView {
        AnyView(view.environmentObject(appState))
    }

    final class Coordinator {
        weak var scrollController: EventDetailScrollViewController?
        var onTabChange: ((Int) -> Void)?
        var onPageProgress: ((CGFloat) -> Void)?

        func relayTabChange(_ index: Int) {
            onTabChange?(index)
        }

        func relayPageProgress(_ progress: CGFloat) {
            onPageProgress?(progress)
        }
    }
}
