# iOS / Flutter Android Parity Checklist

Last updated: 2026-04-19

Use this file after generating the Flutter app to track whether Android matches the iOS behavior closely enough.

Status values: `Todo`, `In Progress`, `Done`, `Deferred`.

## Foundation

| Area | iOS Source | Android Target | Status |
|---|---|---|---|
| App bootstrap | `RaverMVPApp.swift` | `lib/app/bootstrap.dart` | Todo |
| DI container | `AppContainer.swift` | Riverpod provider graph | Todo |
| Global state | `AppState.swift` | `AppStateNotifier` / providers | Todo |
| Runtime config | `AppConfig.swift` | `core/config/app_config.dart` | Todo |
| Token storage | `SessionTokenStore.swift` | `flutter_secure_storage` | Todo |
| Theme | `Theme.swift` | `RaverThemeExtension` | Todo |
| Image cache | `ImageCacheBootstrap.swift` | `cached_network_image` config | Todo |

## Navigation

| Area | iOS Source | Android Target | Status |
|---|---|---|---|
| Root auth switch | `AppCoordinatorView` | `GoRouter` redirect/bootstrap | Todo |
| Main route bus | `AppRouter` / `AppRoute` | typed route definitions | Todo |
| Sheet routes | `AppSheetRoute` | presentation helper | Todo |
| Fullscreen routes | `AppFullScreenRoute` | fullscreen presentation helper | Todo |
| Tab shell | `MainTabView` | `RaverShellScaffold` | Todo |
| Tab hiding | `AppRoute.hidesTabBar` | route metadata | Todo |
| Android back | iOS swipe-back equivalent | system back + pop scope | Todo |

## Main Features

| Feature | iOS Source | Android Target | Status |
|---|---|---|---|
| Auth | `Features/Auth` | `features/auth` | Todo |
| Discover shell | `DiscoverHomeView.swift` | `features/discover` | Todo |
| Recommended events | `RecommendEventsModuleView` | `discover/recommend` | Todo |
| Events | `EventsModuleView` | `discover/events` | Todo |
| Event detail | `EventDetailView` | `events/detail` | Todo |
| DJs | `DJsModuleView` | `discover/djs` | Todo |
| DJ detail | `DJDetailView` | `djs/detail` | Todo |
| Sets | `SetsModuleView` | `discover/sets` | Todo |
| Set detail | `DJSetDetailView` | `sets/detail` | Todo |
| Wiki/Learn | `LearnModuleView` | `discover/learn` | Todo |
| Search | `DiscoverSearchViews` | `discover/search` | Todo |
| Circle feed | `FeedView` / `CircleHomeView` | `features/circle/feed` | Todo |
| Squads | `SquadProfileView` | `features/circle/squads` | Todo |
| Ratings | Rating event/unit views | `features/circle/ratings` | Todo |
| Messages | `MessagesHomeView` / `ChatView` | `features/messages` | Todo |
| Profile | `ProfileView` / `UserProfileView` | `features/profile` | Todo |
| Checkins | `MyCheckinsView` | `features/profile/checkins` | Todo |
| Publishes | `MyPublishesView` | `features/profile/publishes` | Todo |
| Notifications | `NotificationsView` | `features/notifications` | Todo |

## Page Documents

| Page Doc | Status |
|---|---|
| `pages/00_APP_SHELL_AND_TABS.md` | Todo |
| `pages/01_AUTH_LOGIN_REGISTER.md` | Todo |
| `pages/02_DISCOVER_HOME_AND_SEARCH.md` | Todo |
| `pages/03_DISCOVER_RECOMMEND.md` | Todo |
| `pages/04_EVENTS_LIST_AND_FAVORITES.md` | Todo |
| `pages/05_EVENT_DETAIL.md` | Todo |
| `pages/06_EVENT_EDITOR_AND_LINEUP_IMPORT.md` | Todo |
| `pages/07_DJS_LIST.md` | Todo |
| `pages/08_DJ_DETAIL.md` | Todo |
| `pages/09_DJ_IMPORT_AND_EDITOR.md` | Todo |
| `pages/10_SETS_LIST.md` | Todo |
| `pages/11_SET_DETAIL_PLAYER_TRACKLIST.md` | Todo |
| `pages/12_SET_EDITOR_TRACKLIST_EDITOR.md` | Todo |
| `pages/13_NEWS_LIST_DETAIL_PUBLISH.md` | Todo |
| `pages/14_WIKI_LEARN_LABELS_FESTIVALS_RANKINGS.md` | Todo |
| `pages/15_CIRCLE_HOME.md` | Todo |
| `pages/16_FEED_POST_DETAIL_COMPOSE.md` | Todo |
| `pages/17_SQUADS.md` | Todo |
| `pages/18_RATINGS.md` | Todo |
| `pages/19_MESSAGES_CHAT_NOTIFICATIONS.md` | Todo |
| `pages/20_PROFILE_ME_PUBLIC_EDIT_SETTINGS.md` | Todo |
| `pages/21_CHECKINS_PUBLISHES_FOLLOWS.md` | Todo |
| `pages/22_NOTIFICATIONS_DEEPLINKS_EXTERNAL_ACTIONS.md` | Todo |

## BFF Contracts

| Contract Group | Android Client | Status |
|---|---|---|
| Auth/session | `AuthApiClient` | Todo |
| Feed/social | `SocialApiClient` | Todo |
| Events | `DiscoverApiClient` | Todo |
| DJs | `DiscoverApiClient` | Todo |
| DJ sets | `DiscoverApiClient` | Todo |
| Checkins | `DiscoverApiClient` | Todo |
| Ratings | `DiscoverApiClient` | Todo |
| Learn/wiki | `DiscoverApiClient` | Todo |
| Uploads | `UploadApiClient` | Todo |

## Test Gates

| Gate | Command | Status |
|---|---|---|
| Static analysis | `flutter analyze` | Todo |
| Unit/widget tests | `flutter test` | Todo |
| Code generation | `dart run build_runner build --delete-conflicting-outputs` | Todo |
| Android debug run | `flutter run -d emulator` | Todo |
| Android release bundle | `flutter build appbundle --release` | Todo |
