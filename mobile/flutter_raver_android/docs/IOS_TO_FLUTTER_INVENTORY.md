# Raver iOS -> Flutter Android Inventory

Last updated: 2026-04-19

This is a working inventory for the Android Flutter port. The authoritative implementation plan is `RAVER_FLUTTER_ANDROID_TECHNICAL_PLAN.md`.

## iOS Architecture Snapshot

Current iOS app shape:

- Entry: `RaverMVPApp` creates `AppContainer` and `AppState`, then renders `AppCoordinatorView`.
- Flow split: authenticated users enter `MainTabCoordinatorView`; unauthenticated users see `LoginView`.
- Navigation: root `NavigationStack` with `AppRouter`, `AppRoute`, `AppSheetRoute`, `AppFullScreenRoute`.
- Tabs: `discover`, `circle`, `messages`, `profile`.
- Dependency injection: `AppContainer` owns `SocialService`, `WebFeatureService`, and feature repositories.
- Runtime mode: `AppConfig.runtimeMode` supports `mock` and `live`; default BFF base URL is `http://localhost:8787`.

## Feature Mapping

| iOS Area | Flutter Feature Module | Notes |
|---|---|---|
| `Features/Auth` | `features/auth` | Login/register/session bootstrap |
| `Features/Discover` | `features/discover` | Highest priority; contains recommend/events/news/DJ/Sets/Wiki |
| `Features/Circle` + `Features/Feed` | `features/circle` | Feed, squads, IDs, ratings |
| `Features/Messages` | `features/messages` | Direct/group conversations, notification categories |
| `Features/Profile` | `features/profile` | Me, public profile, follows, check-ins, publishes, settings |
| `Shared` | `core/widgets` + `core/design_system` | Navigation chrome, cards, image loader, common controls |
| `Core` | `core/*` | Models, networking, config, persistence, theme, platform APIs |

## Critical iOS Files To Mirror

- `/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Core/Theme.swift`
- `/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Core/AppConfig.swift`
- `/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Core/AppState.swift`
- `/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Application/DI/AppContainer.swift`
- `/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Application/Coordinator/MainTabCoordinator.swift`
- `/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/MainTabView.swift`
- `/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Shared/RaverNavigationChrome.swift`
- `/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Core/LiveSocialService.swift`
- `/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Core/LiveWebFeatureService.swift`

## BFF API Groups

Base path used by iOS live mode:

```text
http://localhost:8787/v1
```

Primary API groups:

- Auth and social: `/auth`, `/feed`, `/users`, `/notifications`, `/squads`, `/chat`, `/profile`, `/social`.
- Discover web features: `/events`, `/djs`, `/dj-sets`, `/checkins`, `/rating-events`, `/rating-units`, `/learn`, `/publishes`.
- Upload endpoints: event images, feed images/videos, DJ images, set thumbnails/videos, rating images, wiki brand/ranking images.

## Migration Priority

1. App shell, config, theme, router, auth session.
2. Discover home with mock repositories.
3. Events list/detail/check-in.
4. DJs list/detail/follow/check-in.
5. Sets list/detail/video/tracklists/comments.
6. Circle feed and post compose.
7. Messages and profile.
8. Editors/admin-like flows.

