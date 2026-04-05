import Foundation

@MainActor
final class NotificationsViewModel: ObservableObject {
    @Published var notifications: [AppNotification] = []
    @Published var unreadCount = 0
    @Published var isLoading = false
    @Published var error: String?

    private let service: SocialService

    init(service: SocialService) {
        self.service = service
    }

    func load() async {
        if isLoading { return }
        isLoading = true
        defer { isLoading = false }

        do {
            let inbox = try await service.fetchNotifications(limit: 30)
            notifications = inbox.items
            unreadCount = inbox.unreadCount
            error = nil
        } catch {
            self.error = error.userFacingMessage
        }
    }
}

