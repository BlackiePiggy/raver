import SwiftUI

enum ProfileRoute: Hashable {
    case followList(userID: String, kind: FollowListKind)
    case settings
    case myPublishes
    case myRoutes
    case editProfile
    case myCheckins(targetUserID: String?, title: String)
    case avatarFullscreen
    case publishEvent
    case uploadSet
    case editEvent(eventID: String)
    case editSet(setID: String)
    case editRatingEvent(eventID: String)
    case editRatingUnit(unitID: String)
}

private struct ProfilePushKey: EnvironmentKey {
    static let defaultValue: (ProfileRoute) -> Void = { _ in }
}

extension EnvironmentValues {
    var profilePush: (ProfileRoute) -> Void {
        get { self[ProfilePushKey.self] }
        set { self[ProfilePushKey.self] = newValue }
    }
}

extension Notification.Name {
    static let profileDidUpdate = Notification.Name("profileDidUpdate")
}

struct ProfileCoordinatorView: View {
    @StateObject private var profileViewModel: ProfileViewModel

    init(repository: ProfileSocialRepository) {
        _profileViewModel = StateObject(
            wrappedValue: ProfileViewModel(repository: repository)
        )
    }

    var body: some View {
        ProfileView(viewModel: profileViewModel)
        .background(RaverTheme.background)
        .onReceive(NotificationCenter.default.publisher(for: .profileDidUpdate)) { notification in
            guard let updated = notification.object as? UserProfile else { return }
            profileViewModel.applyUpdatedProfile(updated)
        }
    }
}
