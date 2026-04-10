import SwiftUI

enum ProfileRoute: Hashable {
    case followList(userID: String, kind: FollowListKind)
    case userProfile(String)
    case squadProfile(String)
    case settings
    case myPublishes
    case conversation(Conversation)
    case editProfile
    case myCheckins(targetUserID: String?, title: String)
    case postDetail(Post)
    case avatarFullscreen
    case publishEvent
    case uploadSet
    case eventDetail(String)
    case djDetail(String)
    case editEvent(WebEvent)
    case editSet(WebDJSet)
    case editRatingEvent(WebRatingEvent)
    case editRatingUnit(WebRatingUnit)
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

struct ProfileCoordinatorView: View {
    @EnvironmentObject private var appContainer: AppContainer
    @EnvironmentObject private var appState: AppState
    @StateObject private var profileViewModel: ProfileViewModel
    @State private var navPath: [ProfileRoute] = []

    init(repository: ProfileSocialRepository) {
        _profileViewModel = StateObject(
            wrappedValue: ProfileViewModel(repository: repository)
        )
    }

    var body: some View {
        NavigationStack(path: $navPath) {
            ProfileView(viewModel: profileViewModel)
                .navigationDestination(for: ProfileRoute.self) { route in
                    routeDestination(for: route)
                }
        }
        .environment(\.profilePush) { route in
            navPath.append(route)
        }
        .background(RaverTheme.background)
    }

    @ViewBuilder
    private func routeDestination(for route: ProfileRoute) -> some View {
        switch route {
        case let .followList(userID, kind):
            FollowListView(
                userID: userID,
                kind: kind,
                repository: appContainer.profileSocialRepository
            )
        case let .userProfile(userID):
            UserProfileView(userID: userID)
        case let .squadProfile(squadID):
            SquadProfileView(squadID: squadID, service: appContainer.socialService)
        case .settings:
            SettingsView()
        case .myPublishes:
            MyPublishesView(
                service: appContainer.webService,
                socialService: appContainer.socialService
            )
        case let .conversation(conversation):
            ChatView(conversation: conversation, service: appContainer.socialService)
        case .editProfile:
            if let profile = profileViewModel.profile {
                EditProfileView(profile: profile, repository: appContainer.profileSocialRepository) { updated in
                    profileViewModel.applyUpdatedProfile(updated)
                }
            } else {
                EmptyView()
            }
        case let .myCheckins(targetUserID, title):
            MyCheckinsView(
                targetUserID: targetUserID,
                title: title
            )
        case let .postDetail(post):
            PostDetailView(post: post, service: appContainer.socialService)
                .environmentObject(appState)
        case .avatarFullscreen:
            if let profile = profileViewModel.profile {
                AvatarFullscreenView(profile: profile)
                    .toolbar(.hidden, for: .navigationBar)
            } else {
                EmptyView()
            }
        case .publishEvent:
            EventEditorView(mode: .create) {
                Task { await profileViewModel.load() }
            }
        case .uploadSet:
            DJSetEditorView(mode: .create) {}
        case let .eventDetail(eventID):
            EventDetailView(eventID: eventID)
        case let .djDetail(djID):
            DJDetailView(djID: djID)
        case let .editEvent(event):
            EventEditorView(mode: .edit(event)) {}
        case let .editSet(set):
            DJSetEditorView(mode: .edit(set)) {}
        case let .editRatingEvent(event):
            RatingEventEditorSheet(event: event) {}
        case let .editRatingUnit(unit):
            RatingUnitEditorSheet(unit: unit) {}
        }
    }
}
