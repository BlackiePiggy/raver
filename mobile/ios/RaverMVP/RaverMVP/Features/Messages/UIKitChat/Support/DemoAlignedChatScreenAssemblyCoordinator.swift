import Foundation

@MainActor
final class DemoAlignedChatScreenAssemblyCoordinator {
    struct Step {
        let id: String
        let action: () -> Void
    }

    private let steps: [Step]
    private let expectedOrder: [String]?
    private let onAssembled: (() -> Void)?

    init(
        steps: [Step],
        expectedOrder: [String]? = nil,
        onAssembled: (() -> Void)? = nil
    ) {
        self.steps = steps
        self.expectedOrder = expectedOrder
        self.onAssembled = onAssembled
    }

    func assemble() {
        #if DEBUG
        let actualOrder = steps.map(\.id)
        if let expectedOrder, actualOrder != expectedOrder {
            assertionFailure(
                "Chat screen assembly order mismatch.\nexpected=\(expectedOrder)\nactual=\(actualOrder)"
            )
        }

        let duplicates = Dictionary(grouping: actualOrder, by: { $0 })
            .filter { $1.count > 1 }
            .keys
            .sorted()
        if !duplicates.isEmpty {
            assertionFailure("Chat screen assembly contains duplicate step ids: \(duplicates)")
        }
        #endif

        steps.forEach { $0.action() }
        onAssembled?()
    }
}
