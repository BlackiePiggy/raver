import SwiftUI

enum ProfileRoute: Hashable {
    case followList(userID: String, kind: FollowListKind)
    case settings
    case tools
    case virtualAssetCenter
    case widgetManager
    case movieBanner
    case myPublishes
    case mySaves
    case myRoutes
    case editProfile
    case myCheckins(targetUserID: String?, title: String, ownerDisplayName: String?)
    case avatarFullscreen
    case publishEvent
    case uploadSet
    case editEvent(eventID: String)
    case editSet(setID: String)
    case editRatingEvent(eventID: String)
    case editRatingUnit(unitID: String)
    case shareQRCode(
        title: String,
        subtitle: String?,
        imageURL: String?,
        shortURL: String?,
        qrCodeURL: String?
    )
    case shareAsset(
        navigationTitle: String,
        title: String,
        subtitle: String?,
        imageURL: String?,
        assetURL: String?,
        emptyTitle: String,
        emptyMessage: String,
        hintText: String,
        saveButtonTitle: String?
    )
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
    static let virtualAssetAppearanceDidUpdate = Notification.Name("virtualAssetAppearanceDidUpdate")
}

struct ProfileCoordinatorView: View {
    @StateObject private var profileViewModel: ProfileViewModel

    init(
        userRepository: ProfileUserRepository,
        contentRepository: ProfileContentRepository,
        checkinRepository: ProfileCheckinRepository,
        virtualAssetRepository: VirtualAssetRepository = AppEnvironment.makeVirtualAssetRepository()
    ) {
        _profileViewModel = StateObject(
            wrappedValue: ProfileViewModel(
                userRepository: userRepository,
                contentRepository: contentRepository,
                checkinRepository: checkinRepository,
                virtualAssetRepository: virtualAssetRepository
            )
        )
    }

    var body: some View {
        ProfileView(viewModel: profileViewModel)
        .background(RaverTheme.background)
        .onReceive(NotificationCenter.default.publisher(for: .profileDidUpdate)) { notification in
            guard let updated = notification.object as? UserProfile else { return }
            profileViewModel.applyUpdatedProfile(updated)
        }
        .onReceive(NotificationCenter.default.publisher(for: .virtualAssetAppearanceDidUpdate)) { _ in
            Task { await profileViewModel.refreshAppearance() }
        }
    }
}
