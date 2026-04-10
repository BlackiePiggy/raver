# Raver iOS MVVM + Coordinator Migration Plan

Last Updated: 2026-04-10
Owner: Codex + project maintainers
Status: Active

## Purpose

This document is the single source of truth for migrating the iOS app from its current mixed architecture into a consistent `MVVM + Coordinator` architecture.

From this point on:

- All migration work should follow this document.
- Completed items must be marked as completed in this file.
- New findings, scope changes, and architectural decisions must be appended here instead of living only in chat history.
- A new agent should be able to continue the work by reading only this file plus the codebase.

## Companion Development Guide

For day-to-day incremental feature implementation after migration stabilization, follow:

- `docs/IOS_INCREMENTAL_FEATURE_DEVELOPMENT_GUIDE.md`

## Current Assessment

The project is not a strict MVVM app today. It is a mixed architecture with:

- Some clean `View + ViewModel + Service` modules, such as Feed.
- Many SwiftUI views that directly create services and perform networking.
- Navigation spread across `NavigationStack`, `sheet`, `fullScreenCover`, `TabView`, environment closures, and UIKit controllers.
- Large feature files, especially `mobile/ios/RaverMVP/RaverMVP/Features/Discover/WebModulesView.swift`, containing multiple feature responsibilities.

## Target Architecture

The target architecture is:

- `View`: renders UI and forwards user intent only.
- `ViewModel`: owns screen state, state transitions, async tasks, and presentation-ready data.
- `Coordinator`: owns navigation state and screen composition.
- `UseCase` or `Repository`: owns business workflows and data orchestration.
- `Service`: owns raw API and persistence calls.

Navigation target shape:

- `AppCoordinator`
- `MainTabCoordinator`
- `DiscoverCoordinator`
- `CircleCoordinator`
- `MessagesCoordinator`
- `ProfileCoordinator`

Dependency target shape:

- `AppContainer` or equivalent dependency container creates shared services and repositories.
- Views do not call `AppEnvironment.makeService()` or `AppEnvironment.makeWebService()` directly.
- Coordinators compose screens and inject dependencies into ViewModels.

## Architectural Rules

These rules apply to all future migration work:

- New screen state must go into a ViewModel, not directly into a View unless it is purely ephemeral UI state.
- New navigation must go through a Coordinator.
- Views must not directly create services.
- Views must not own `NavigationPath` unless that path is explicitly coordinator-owned and injected.
- `AppState` should only hold truly global state such as session, language, unread badges, and app-wide alerts.
- UIKit wrappers may remain, but their presentation must be initiated by a Coordinator.

## Non-Goals

These are not required in the first migration passes:

- Rewriting the visual design.
- Rewriting all UIKit bridge code immediately.
- Replacing every service with repositories on day one.
- Splitting every large file before navigation is stabilized.

## Migration Strategy

Use an incremental migration strategy. Do not try to rewrite the full app in one pass.

Priority order:

1. Establish app-level Coordinator and DI skeleton.
2. Move root and tab navigation under Coordinator control.
3. Migrate Discover first because it is the highest-risk module and currently the most complex.
4. Migrate Messages and Profile next.
5. Migrate Circle last because it contains many nested flows and will benefit from established patterns.
6. Only after feature flows stabilize, introduce repositories and use cases more broadly.

## Target Folder Layout

This is the desired end state. It does not need to be created all at once.

```text
mobile/ios/RaverMVP/RaverMVP/
  Application/
    DI/
    Coordinator/
  Core/
    Networking/
    Persistence/
    UI/
  Features/
    Discover/
      Coordinator/
      Shared/
      Search/
        Views/
        ViewModels/
      Events/
        Views/
        ViewModels/
      News/
        Views/
        Models/
      DJs/
        Views/
      Sets/
        Views/
      Learn/
        Views/
    Circle/
      Coordinator/
      Views/
      ViewModels/
      Components/
    Messages/
      Coordinator/
      Views/
      ViewModels/
      Components/
    Profile/
      Coordinator/
      Views/
      ViewModels/
      Components/
```

Notes:

- Discover has already converged to domain-first folders (`Search/Events/News/DJs/Sets/Learn`) and this is the current source-of-truth structure.
- Circle/Messages/Profile can use the same domain-first pattern when decomposition work starts; the layout above is the minimum expected baseline.

## Phase Plan

### Phase 0: Baseline and Planning

Goal:

- Assess the current architecture.
- Define the migration path and working agreement.

Exit criteria:

- This Markdown plan exists and is committed.
- The project has a documented target architecture and migration order.

Status:

- [x] P0.1 Assess current architecture and identify migration constraints.
- [x] P0.2 Produce a durable migration plan that future agents can follow.

### Phase 1: Application Skeleton

Goal:

- Introduce dependency injection and app-level coordinators without changing feature behavior.

Deliverables:

- `Application/DI/AppContainer.swift`
- `Application/Coordinator/AppCoordinator.swift`
- `Application/Coordinator/MainTabCoordinator.swift`
- App entry updated to render `AppCoordinatorView`

Exit criteria:

- Root app flow no longer directly chooses screens inside `RootView`.
- Main tab structure is coordinator-owned.
- Existing tabs still render and behave the same.

Status:

- [x] P1.1 Add `AppContainer`.
- [x] P1.2 Add `AppCoordinator`.
- [x] P1.3 Add `MainTabCoordinator`.
- [x] P1.4 Update `RaverMVPApp.swift` to use the new coordinator root.
- [x] P1.5 Keep current app behavior stable after coordinator bootstrap.

### Phase 2: Discover Navigation Migration

Goal:

- Move Discover navigation and route ownership into a Coordinator while preserving current feature behavior.

Deliverables:

- `Features/Discover/Coordinator/DiscoverCoordinator.swift`
- `Features/Discover/Coordinator/DiscoverRoute.swift`
- `DiscoverHomeView` simplified to a view driven by coordinator state

Exit criteria:

- Discover push, modal, and search flows are coordinator-owned.
- Discover views no longer own route stacks directly.

Status:

- [x] P2.1 Create `DiscoverCoordinator`.
- [x] P2.2 Move `DiscoverRoute` ownership out of `DiscoverHomeView`.
- [x] P2.3 Route search input, search results, and event detail through coordinator.
- [x] P2.4 Preserve current Discover UI behavior after navigation migration.

### Phase 3: Discover MVVM Normalization

Goal:

- Remove direct service creation from Discover views and move screen state into ViewModels.

Deliverables:

- ViewModels for Discover entry points and search flows.
- Service injection via container or coordinator.

Exit criteria:

- New or touched Discover screens do not call `AppEnvironment.makeService()` directly inside views.
- Discover business state is ViewModel-owned.

Status:

- [x] P3.1 Convert Discover search flows to ViewModel-driven screens.
- [x] P3.2 Continue normalizing `EventsModuleView` under coordinator-driven composition.
- [x] P3.3 Move direct service creation out of touched Discover views.
- [x] P3.4 Define a repeatable Discover screen template for future migrations.

### Phase 4: Discover File Decomposition

Goal:

- Break `WebModulesView.swift` into feature-scoped files without changing user-facing behavior.
- Use a domain-first extraction path so file splitting and MVVM migration reinforce each other instead of creating a second temporary structure.

Deliverables:

- `Search` is used as the pilot extraction slice so future moves follow a proven folder and dependency pattern.
- `EventsModule`, `NewsModule`, `DJsModule`, `SetsModule`, and `LearnModule` moved into separate files and folders.

Execution strategy:

- Extract by business domain rather than by generic screen type.
- Start with `Search` because it is relatively self-contained and already on the Phase 3 MVVM path.
- Prefer low-risk mechanical moves first, then continue ViewModel and coordinator cleanup inside the extracted domain.
- Leave deeply coupled Learn/Wiki detail implementations in place until their shared types are safe to expose across files.

Exit criteria:

- `WebModulesView.swift` no longer acts as a multi-feature dumping ground.
- Discover feature ownership is clearer for future work.

Status:

- [x] P4.0 Establish the domain-first Discover decomposition path by extracting `Search` as the pilot slice.
- [x] P4.1 Extract Events feature files.
- [x] P4.2 Extract News feature files.
- [x] P4.3 Extract DJs feature files.
- [x] P4.4 Extract Sets feature files.
- [x] P4.5 Extract Learn feature files.

### Phase 5: Messages and Profile Migration

Goal:

- Apply the same Coordinator and MVVM rules to Messages and Profile.

Exit criteria:

- Messages and Profile route state is coordinator-owned.
- Touched screens no longer create services directly inside views.

Status:

- [x] P5.1 Add `MessagesCoordinator`.
- [x] P5.2 Add `ProfileCoordinator`.
- [x] P5.3 Normalize Messages views and ViewModels.
- [x] P5.4 Normalize Profile views and ViewModels.

P5.4 scope tracker:

- Completed scope:
- Coordinator owns Profile route stack and push routing (`ProfileRoute`, `profilePush`) with push-only presentation.
- `ProfileCoordinator` owns shared `ProfileViewModel`.
- `ProfileView`, `UserProfileView`, and `FollowListView` have migrated high-frequency route hops to coordinator-owned routes.
- Direct service factory usage (`AppEnvironment.makeService/makeWebService`) has been removed from touched Profile surfaces, including `WebProfileModulesView`.
- `MyPublishesView` has started MVVM normalization with a dedicated `MyPublishesViewModel`.
- `MyCheckinsView` has started MVVM normalization with a dedicated `MyCheckinsViewModel` for reload/pagination/hydration flows.
- `RatingEventEditorSheet` and `RatingUnitEditorSheet` have migrated save/upload/error business logic into dedicated editor ViewModels.
- Profile split-domain ViewModels now explicitly use `@MainActor` (`MyCheckinsViewModel`, `MyPublishesViewModel`, `RatingEventEditorViewModel`) to prevent background-thread `@Published` updates.
- `WebProfileModulesView.swift` has been decomposed into Profile domain files (`Views/Checkins/MyCheckinsView.swift`, `Views/Publishes/MyPublishesView.swift`, `Views/RatingEditors/RatingEditors.swift`) and the original file is now a shim.
- Remaining scope:
- None. Profile smoke checks have passed and `P5.4` is closed.

### Phase 6: Circle Migration

Goal:

- Migrate Circle into `MVVM + Coordinator` after patterns are validated in Discover, Messages, and Profile.

Exit criteria:

- Circle routes are coordinator-owned.
- Large nested flows are decomposed into explicit subflows.

Status:

- [x] P6.1 Add `CircleCoordinator`.
- [x] P6.2 Migrate Circle root navigation.
- [x] P6.3 Migrate nested Circle flows incrementally.

### Phase 7: Domain Layer Consolidation

Goal:

- Introduce repositories and use cases where service calls are still too close to screen logic.

Exit criteria:

- Core feature workflows are not tightly coupled to service APIs.
- Mocking and testing become easier at ViewModel boundaries.

Status:

- [x] P7.1 Define repository boundaries for Discover.
- [x] P7.2 Define repository boundaries for social features.
- [x] P7.3 Introduce use cases where workflows span multiple service calls.

P7.2 scope tracker:

- Completed scope:
- Added `MessagesRepository` boundary and migrated `MessagesViewModel` + `MessageNotificationsViewModel`.
- Added `ProfileSocialRepository` boundary and migrated `ProfileViewModel`, `FollowListViewModel`, and `UserProfileViewModel`.
- Migrated Profile edit/profile-mutation workflow (`EditProfileView`) to repository-backed ViewModel save/upload path.
- Added `CircleFeedRepository` boundary and migrated `FeedViewModel` (Circle feed) off direct `SocialService`, with `AppContainer` injection in `FeedView`.
- Remaining scope:
- None. Social-feature smoke checks have passed and `P7.2` is closed.

P7.3 scope tracker:

- Completed scope:
- Added first social use-case pilot `SaveProfileUseCase` and moved the multi-step profile save workflow (`upload avatar` + `update profile`) out of `EditProfileViewModel`.
- Added second social use-case pilot `LoadMyProfileDashboardUseCase` and moved Profile home multi-call bootstrap workflow out of `ProfileViewModel.load()`.
- Added third social use-case pilot `LoadSquadHallDataUseCase` and moved Circle squad hall multi-call loading/hydration workflow (`recommended squads` + `my squads` + `squad profile hydration`) out of `SquadHallView.loadSquads()`.
- Remaining scope:
- None. Automated compile verification passed and targeted smoke checks passed for all three social use-case pilots (`SaveProfileUseCase`, `LoadMyProfileDashboardUseCase`, `LoadSquadHallDataUseCase`); `P7.3` is closed.

P7.1 scope tracker:

- Completed scope:
- Added `DiscoverEventsRepository` boundary and `DiscoverEventsRepositoryAdapter` (wrapping `WebFeatureService`) for the Discover Events domain.
- Extracted first pilot use cases for Discover Events:
`FetchDiscoverEventsPageUseCase`, `FetchMarkedEventCheckinsUseCase`, `ToggleMarkedEventUseCase`.
- Migrated first pilot flow to the new boundary:
`EventsModuleViewModel`, `RecommendEventsViewModel`, and `EventsSearchResultsViewModel` now depend on Discover Events repository/use cases instead of direct `WebFeatureService`.
- Added coordinator/container injection path:
`AppContainer.discoverEventsRepository`, wired through `DiscoverEventsRootView`, `DiscoverRecommendEventsRootView`, and `DiscoverRoute` event-search destination.
- Added Discover News boundary as second pilot:
`DiscoverNewsRepository` + `SearchDiscoverNewsUseCase`, with `NewsSearchResultsViewModel` migrated off direct `SocialService` usage.
- Added Discover DJs boundary as third pilot:
`DiscoverDJsRepository` + `SearchDiscoverDJsUseCase`, with `DJsSearchResultsViewModel` migrated off direct `WebFeatureService` usage.
- Added Discover Sets boundary as fourth pilot:
`DiscoverSetsRepository` + `SearchDiscoverSetsUseCase`, with `SetsSearchResultsViewModel` migrated off direct `WebFeatureService` usage.
- Added Discover Wiki boundary as fifth pilot:
`DiscoverWikiRepository` + `SearchDiscoverWikiUseCase`, with `WikiSearchResultsViewModel` migrated off direct `WebFeatureService` usage.
- Expanded Discover News boundary from search into module screen flows:
`NewsModuleView` feed pagination and publish mutations now use `DiscoverNewsRepository` with `AppContainer` injection (removed local `AppEnvironment.makeService()` coupling).
- Expanded Discover News boundary into detail interaction flows:
`DiscoverNewsDetailView` comment read/write now use `DiscoverNewsRepository` with `AppContainer` injection instead of local social service construction.
- Expanded Discover News boundary into detail bound-entity hydration:
`DiscoverNewsDetailView` DJ/Event/Festival hydration now uses `DiscoverNewsRepository` methods instead of local `WebFeatureService`.
- Expanded Discover News boundary into publish-sheet flows:
`DiscoverNewsPublishSheet` cover upload and DJ/Event/Festival binding search now use `DiscoverNewsRepository` with `AppContainer` injection.
- Expanded Discover Events boundary into detail workflows:
`EventDetailView` event loading, check-in create/update/delete, rating/set reload, and event deletion now use `DiscoverEventsRepository` with `AppContainer` injection; related news hydration now uses `DiscoverNewsRepository`.
- Expanded Discover DJs boundary into module workflows:
`DJsModuleView` hot/rankings loading, Spotify/Discogs search, import flows, and DJ image uploads now use `DiscoverDJsRepository` with `AppContainer` injection instead of local `AppEnvironment.makeWebService()`.
- Expanded Discover DJs boundary into detail workflows:
`DJDetailView` detail loading, follow toggling, rating reload, Spotify import, profile edit/save, and related-news hydration now use `DiscoverDJsRepository` + `DiscoverNewsRepository` with `AppContainer` injection.
- Expanded Discover Sets boundary into module/detail workflows:
`SetsModuleView` list loading and `DJSetDetailView` detail/comments/tracklist/event-link/delete flows now use `DiscoverSetsRepository` with `AppContainer` injection instead of local service factories.
- Expanded Discover Sets boundary into editor/support workflows:
`DJSetEditorView`, `SetEventBindingSheet`, `UploadTracklistSheet`, and `TracklistEditorView` now use `DiscoverSetsRepository` with `AppContainer` injection instead of local service factories.
- Expanded Discover Learn boundary into module/detail/ranking web workflows:
`LearnModuleView`, `LearnFestivalDetailView`, and `RankingBoardDetailView` now use `DiscoverWikiRepository` + `DiscoverEventsRepository` + `DiscoverDJsRepository` with `AppContainer` injection instead of local `AppEnvironment.makeWebService()` factories.
- Expanded Discover Learn boundary into social workflows:
`LearnFestivalDetailView` related-post loading and contributor profile/search hydration now use `DiscoverNewsRepository` with `AppContainer` injection instead of local `AppEnvironment.makeService()` factory usage.
- Expanded Discover Events boundary into editor/check-in workflows:
`EventEditorView` and `DJCheckinBindingSheet` now use `DiscoverEventsRepository` + `DiscoverDJsRepository` with `AppContainer` injection (event create/update, media upload, lineup import, DJ/event lookup), and no longer construct local `WebFeatureService`.
- Remaining scope:
- None. Discover feature folder no longer contains local `AppEnvironment.makeService/makeWebService` factories.

### Phase 8: AppState Reduction and Cleanup

Goal:

- Limit `AppState` to global concerns only.

Exit criteria:

- Feature-owned state is not stored globally.
- App-wide state is clearly separated from feature state.

Status:

- [x] P8.1 Audit `AppState` responsibilities.
- [x] P8.2 Move feature-owned state out of `AppState`.
- [x] P8.3 Final cleanup of transitional architecture glue.

P8.1 scope tracker:

- Completed scope:
- Audited `AppState` surface in `Core/AppState.swift` (`session`, `errorMessage`, `unreadMessagesCount`, `preferredLanguage`, `service`, and auth/badge methods) and mapped concrete usage sites across app/coordinators/features.
- Confirmed global state that should stay in app-level ownership:
- `session` / auth flow state (`login/register/logout` entry points).
- `preferredLanguage` and locale wiring.
- app-wide alert channel (`errorMessage`) and tab badge source of truth (`unreadMessagesCount`).
- Identified extraction candidates for Phase 8.2 (responsibility bleed, not new global state):
- Remove `AppState` service-locator responsibility by migrating remaining `appState.service` callers to injected dependencies (`SearchView`, `ComposePostView`, `MainTabView` squad flows, `SquadProfileView`, `UserProfileView` DM entry).
- Normalize unread badge write-path to a single owner (currently written from both `MessagesCoordinator` and `MessagesHomeView`).
- Reduce broad feature coupling to `@EnvironmentObject AppState` where reads are only `currentUserID`/`isLoggedIn`, introducing a narrower session-context dependency over time.
- Remaining scope:
- None. `P8.1` audit is complete.

P8.2 scope tracker:

- Completed scope:
- Removed remaining `appState.service` call sites and switched to injected dependencies (`AppContainer.socialService` or explicit `SocialService` constructor injection) across touched flows:
- `SearchView` post-detail presentation.
- `ComposePostView` create/update/delete mutations and `FeedView` compose entry points.
- `SquadHallView` create-squad sheet + squad-hall load use case wiring.
- `SquadProfileView` conversation navigation.
- `UserProfileView` direct-message conversation bootstrap.
- Remaining scope:
- None. Unread badge write path is now consolidated under `AppState` ownership (`refreshUnreadMessages` / auth/session handlers), with duplicate feature-side direct assignments removed.

P8.3 scope tracker:

- Completed scope:
- Audited residual transitional glue after `P8.2` closure and identified low-risk cleanup targets.
- Removed direct view-level service factory construction from legacy entry views by switching them to `AppContainer`-injected root composition:
- `SearchView` now composes `SearchViewModel(service: appContainer.socialService)` via a container-backed root/screen split.
- `NotificationsView` now composes `NotificationsViewModel(service: appContainer.socialService)` via a container-backed root/screen split.
- Removed remaining feature-level fallback service factory defaults in touched social surfaces and tightened DI-only entry paths:
- `ComposePostView` now requires injected `SocialService` + `WebFeatureService`; `FeedView` passes both from `AppContainer`.
- `SquadProfileView` now requires injected `SocialService`; `SearchView` / `NotificationsView` / coordinator call sites now pass `appContainer.socialService`.
- `SquadManageSheet` now receives injected `SocialService` + `WebFeatureService` from `SquadProfileView` instead of constructing local factories.
- Residual Circle rating/picker surfaces inside `MainTabView` (`CircleIDEventPickerSheet`, `CircleIDDJPickerSheet`, `CircleRatingHubView`, `CircleRatingEventDetailView`, `CircleRatingUnitDetailView`, `CreateRatingEventSheet`, `CreateRatingEventFromEventSheet`, `CreateRatingUnitSheet`) now source services from `AppContainer` environment injection.
- Remaining scope:
- None. Targeted smoke checks for touched social DI-entry paths passed and `P8.3` is closed.

### Phase 9: Navigation Presentation Normalization (Push-First)

Goal:

- Normalize navigation channels to reduce route fragmentation and gesture/state bugs.
- Move business-flow navigation from local `sheet/fullScreenCover` into coordinator-owned `NavigationStack` push routes.
- Keep only intentionally modal interactions as a strict allowlist.

Presentation policy:

- Push-first (must prefer coordinator push):
- Entity detail pages (`Event`, `DJ`, `Festival`, `News`, `Post`, `User`, `Ranking`).
- Full-screen create/edit workflows (event/set/news/post/festival/rating editors).
- Cross-feature hops initiated from `Search`, `Notifications`, and tab home surfaces.
- Modal allowlist (should stay modal unless explicit product change):
- System share flows (`ActivityShareSheet` and platform share UIs).
- Short-lived utility pickers/tool panels (country/event/DJ quick pickers, detent-based utility panels).
- Immersive preview/player surfaces where modal semantics are intentional.

Exit criteria:

- High-frequency business flows in Discover/Circle/Messages/Profile use coordinator-owned push routes.
- Remaining modal flows are documented and justified by the allowlist.
- New routing work follows this policy by default.

Status:

- [x] P9.1 Discover push normalization.
- [x] P9.2 Circle push normalization.
- [x] P9.3 Shared entry points normalization (`Search`/`Notifications`/cross-tab hops).
- [x] P9.4 Modal allowlist freeze and regression checks.

P9.2 decision note:

- Additional cross-feature normalization completed in Q122: previously deferred `MainTabView` utility routes (`showEventPicker` / `showDJPicker` / `showCreateSquad`), `MessagesCoordinator` squad profile route, `SquadProfileView` manage panel route, and `CircleIDHubView` ID detail route are now push-based (`navigationDestination` / coordinator push channel).

P9.1 scope tracker:

- Completed scope:
- `EventsModuleView` create flow is coordinator push (`DiscoverRoute.eventCreate`).
- `EventDetailView` edit flow is coordinator push (`DiscoverRoute.eventEdit`).
- `NewsModuleView` publish flow is coordinator push (`DiscoverRoute.newsPublish`).
- `SetsModuleView` list/detail opening plus create/edit flows are coordinator push (`DiscoverRoute.setDetail`/`setCreate`/`setEdit`).
- `LearnModuleView` create + `LearnFestivalDetailView` edit flows are coordinator push (`DiscoverRoute.learnFestivalCreate`/`learnFestivalEdit`).
- Save/publish refresh signals are wired (`discoverEventDidSave`, `discoverNewsDidPublish`, `discoverSetDidSave`).
- Festival save refresh signal is wired (`discoverFestivalDidSave`).
- Remaining scope:
- Discover business-flow modals are removed from this wave; remaining Discover modals are utility/immersive allowlist only (`EventDetailView` check-in/map/share tools, `EventsModuleView` filters, `SetsModuleView` audio-only playback).

P9.1 decision note:

- Deferred Discover overlays were normalized to push in Q122 (`LearnFestivalRankingDetailView` drill-down, Learn image previews, `EventDetailView` rating detail + route planner, `DJsModuleView` import/edit routes, `SetsModuleView` tracklist/event-binding routes, `EventEditorView` lineup/location routes) to reduce presentation-channel fragmentation and edge-gesture conflicts.

P9.4 modal allowlist (frozen):

- Guard source of truth:
- `scripts/modal-allowlist-signatures.txt` (counted modal signature allowlist).
- Guard script:
- `scripts/check-modal-allowlist.sh`.
- CI + contributor preflight integration:
- `.github/workflows/mvvm-coordinator-guard.yml` and `scripts/run-coordinator-hardening-preflight.sh`.
- Allowed modal groups with rationale:
- `Features/Discover/Events/Views/EventsModuleView.swift`: event calendar/country filter sheets are short-lived utility filters.
- `Features/Discover/Events/Views/EventDetailView.swift`: check-in selector, venue map, and share sheet are in-context utility/system surfaces.
- `Features/Discover/Sets/Views/SetsModuleView.swift`: audio-only set playback remains an immersive full-screen surface.
- `Features/Feed/ComposePostView.swift` + `Shared/PostCardView.swift`: media preview and map preview are immersive preview surfaces; `ComposePostView` location picker full-screen route and `PostCardView` media/location full-screen preview routes remain modal as in-context utility/preview flows.

P9.4 enforcement notes:

- Any new `sheet`/`fullScreenCover` call site must either:
1. be migrated to coordinator push routing, or
2. be intentionally added to `scripts/modal-allowlist-signatures.txt` with product rationale documented in this section.
- Q115 Discover audit result:
- Current Discover modal call sites are fully accounted for as intentional utility/immersive surfaces (`EventDetailView` check-in/map/share, `EventsModuleView` filters, `SetsModuleView` audio-only playback); no residual Discover entity/detail-hop modal remains outside push routing.
- Post-Phase-9 cleanup wave status:
- Reopened by Q122 and re-closed after additional push conversion sweep; remaining modal routes are explicitly documented as intentional allowlist flows.

## Immediate Work Queue

These are the exact next items to execute unless priorities change.

- [x] Q1 Create `AppContainer`.
- [x] Q2 Create `AppCoordinator`.
- [x] Q3 Create `MainTabCoordinator`.
- [x] Q4 Update `RaverMVPApp.swift` to boot through coordinator.
- [x] Q5 Create `DiscoverCoordinator`.
- [x] Q6 Move Discover route ownership from `DiscoverHomeView` to coordinator.
- [x] Q7 Convert Discover event and news search results to coordinator-injected ViewModel screens.
- [x] Q8 Convert remaining Discover search results screens (`DJs`, `Sets`, `Wiki`) to ViewModel-driven screens.
- [x] Q9 Normalize `EventsModuleView` into coordinator-composed MVVM structure.
- [x] Q10 Document and reuse a repeatable Discover screen migration template.
- [x] Q11 Start Phase 4 extraction for the Discover `Events` domain using the `Search` pilot structure as the template.
- [x] Q12 Extract the Discover recommendation events screen and shared event presentation helpers from `WebModulesView.swift`.
- [x] Q13 Continue Events extraction by moving the event detail screen and related helpers into the `Events` domain.
- [x] Q14 Continue Events extraction by moving remaining event editor and creation surfaces into the `Events` domain.
- [x] Q15 Continue Events extraction by moving event calendar and event filter support (`EventCalendarSheet`, `EventCalendarViewFilter`, `EventTypeOption`) into the `Events` domain.
- [x] Q16 Start Phase 4.2 by extracting Discover news list/detail surfaces into a dedicated `News` domain folder.
- [x] Q17 Start Phase 4.3 by extracting Discover DJ list/detail surfaces into a dedicated `DJs` domain folder.
- [x] Q18 Start Phase 4.4 by extracting Discover Sets list/detail surfaces into a dedicated `Sets` domain folder.
- [x] Q19 Start Phase 4.5 by extracting Discover Learn list/detail surfaces into a dedicated `Learn` domain folder.
- [x] Q20 Start Phase 5.1 by adding a `MessagesCoordinator` and moving Messages root `NavigationStack` ownership to the coordinator.
- [x] Q21 Start Phase 5.2 by adding a `ProfileCoordinator` and moving Profile root `NavigationStack` ownership to the coordinator.
- [x] Q22 Start Phase 5.3 by injecting `MessagesHomeView` ViewModels from `AppContainer` via a root container view.
- [x] Q23 Start Phase 5.4 by injecting `ProfileView` ViewModel from `AppContainer` via a root container view.
- [x] Q24 Continue Phase 5 normalization by removing direct service factory calls from `CreateSquadView`, `FollowListView`, and `EditProfileView`.
- [x] Q25 Continue Phase 5.4 by removing remaining direct service factory calls from `WebProfileModulesView` and switching those surfaces to `AppContainer` injection.
- [x] Q26 Continue Phase 5.3 by moving conversation push routing from `MessagesHomeView` into `MessagesCoordinator` via `MessagesRoute`.
- [x] Q27 Continue Phase 5.3 by moving user-profile and squad-profile routing from `ChatView` and message alert detail into `MessagesCoordinator` (push + modal).
- [x] Q28 Continue Phase 5.3 by moving alert-category detail routing into `MessagesCoordinator` and centralizing shared `MessagesViewModel`/`MessageNotificationsViewModel` ownership in the coordinator.
- [x] Q29 Continue Phase 5.4 by introducing `ProfileRoute` push routing in `ProfileCoordinator` and migrating `ProfileView` follow-list, user-profile, and settings pushes to coordinator-owned routing.
- [x] Q30 Continue Phase 5.4 by extending `ProfileCoordinator` with modal routing (`profilePresent`) and migrating Profile push/modal subflows (`myPublishes`, `myCheckins`, `postDetail`, `avatar fullscreen`, user-profile direct-message conversation) out of local view state.
- [x] Q31 Continue Phase 5.4 by making `ProfileCoordinator` own shared `ProfileViewModel` and migrating remaining Profile local route bindings (`edit profile`, `publish event`, `upload set`) to coordinator-owned push/sheet channels.
- [x] Q32 Continue Phase 5.4 by removing Profile sheet/full-screen route channels and unifying migrated Profile flows under `NavigationStack` push routing only.
- [x] Q33 Continue Phase 5.4 by replacing remaining `WebProfileModulesView` `sheet/fullScreenCover` flows with `navigationDestination` push routing.
- [x] Q34 Continue Phase 5.4 by moving `WebProfileModulesView` event/DJ detail hops (`MyCheckinsView`, `MyPublishesView`) from local route state to coordinator-owned `profilePush` routes.
- [x] Q35 Continue Phase 5.4 by extracting `MyPublishesView` network/state mutations into a dedicated `MyPublishesViewModel` and injecting dependencies from `ProfileCoordinator`.
- [x] Q36 Continue Phase 5.4 by extracting `MyCheckinsView` loading/pagination/hydration flows into `MyCheckinsViewModel` while keeping existing UI behavior.
- [x] Q37 Continue Phase 5.4 by normalizing remaining Profile editor/detail surfaces in `WebProfileModulesView` to ViewModel-owned business state.
- [x] Q38 Continue Phase 5.4 by decomposing `WebProfileModulesView.swift` into Profile domain files (`Checkins`, `Publishes`, `RatingEditors`) after Q36-Q37 stabilize behavior.
- [x] Q39a Fix Profile check-ins detail navigation thread-safety warning by enforcing main-actor ViewModel updates in split Profile domain files.
- [x] Q39 Close Phase 5.4 by running Profile smoke checks (profile home, follow list, user profile, checkins timeline/gallery, publishes edit/delete, post detail) and marking `P5.4` complete.
- [x] Q40 Start Phase 6.1 by adding `CircleCoordinator` and moving Circle root `NavigationStack` ownership to coordinator.
- [x] Q41 Continue Phase 6.2 by migrating Circle root routes into `CircleRoute` + coordinator-owned push channel.
- [x] Q42 Continue Phase 6.3 by migrating first nested Circle subflow into coordinator-owned routing without behavior regressions.
- [x] Q43 Continue Phase 6.3 by migrating `CircleIDHubView` detail hops (event/DJ/user) from local full-screen state to coordinator-owned push routes.
- [x] Q44 Continue Phase 6.3 by migrating `CircleRatingEventDetailView` linked source-event opening from local full-screen presentation to coordinator-owned route handling.
- [x] Q45 Continue Phase 6.3 by removing redundant local `NavigationStack` wrappers inside Circle root subviews after route ownership stabilizes.
- [x] Q46 Continue Phase 6.3 by migrating `FeedView` author-profile hop to coordinator-owned `circlePush` and removing its redundant root `NavigationStack`.
- [x] Q47 Continue Phase 6.3 by migrating `CircleIDDetailView` linked event/DJ/user hops from local full-screen state to coordinator-owned routing with preserved UX semantics.
- [x] Q48 Close Phase 6.3 by running Circle smoke checks (Feed/Squads/ID/Rating) after residual route cleanup, then marking `P6.3` complete.
- [x] Q49 Start Phase 7.1 by defining Discover repository boundaries and selecting first pilot flow for use-case extraction.
- [x] Q50 Continue Phase 7.1 by extending repository boundaries to Discover `News` and migrating `NewsSearchResultsViewModel` as the second pilot.
- [x] Q51 Continue Phase 7.1 by extending repository boundaries to Discover `DJs` and migrating `DJsSearchResultsViewModel` as the third pilot.
- [x] Q52 Continue Phase 7.1 by extending repository boundaries to Discover `Sets` and migrating `SetsSearchResultsViewModel` as the fourth pilot.
- [x] Q53 Continue Phase 7.1 by extending repository boundaries to Discover `Wiki` and migrating `WikiSearchResultsViewModel` as the fifth pilot.
- [x] Q54 Continue Phase 7.1 by migrating `NewsModuleView` feed/publish loading flows to `DiscoverNewsRepository` boundaries and `AppContainer` injection.
- [x] Q55 Continue Phase 7.1 by migrating `DiscoverNewsDetailView` comment read/write flows to `DiscoverNewsRepository` boundaries and `AppContainer` injection.
- [x] Q56 Continue Phase 7.1 by migrating `DiscoverNewsDetailView` bound-entity hydration (`DJ/Event/Festival`) from local `WebFeatureService` access to repository boundaries.
- [x] Q57 Continue Phase 7.1 by migrating `DiscoverNewsPublishSheet` cover upload and binding-search flows (`DJ/Event/Festival`) from local `WebFeatureService` access to repository boundaries.
- [x] Q58 Continue Phase 7.1 by migrating `EventDetailView` web workflows (event load/check-in/rating/set/delete + related news hydration) from direct services to repository boundaries.
- [x] Q59 Continue Phase 7.1 by migrating `DJsModuleView` module workflows (hot/rankings load, Spotify/Discogs search/import, image upload) from direct services to repository boundaries.
- [x] Q60 Continue Phase 7.1 by migrating `DJDetailView` detail workflows (detail load, follow, ratings/events/sets reload, import/edit mutations) from direct services to repository boundaries.
- [x] Q61 Continue Phase 7.1 by migrating `SetsModuleView` module/detail workflows from direct services to repository boundaries.
- [x] Q62 Continue Phase 7.1 by migrating Discover Sets editor/support workflows (`DJSetEditorView`, `SetEventBindingSheet`, `UploadTracklistSheet`, `TracklistEditorView`) from direct services to repository boundaries.
- [x] Q63 Continue Phase 7.1 by migrating `LearnModuleView` workflows from direct services to repository boundaries.
- [x] Q64 Continue Phase 7.1 by removing remaining Discover Learn social-service coupling (`LearnFestivalDetailView` related-post/contributor workflows) behind repository boundaries.
- [x] Q65 Continue Phase 7.1 by migrating Discover `EventEditorView` workflows from direct services to repository boundaries.
- [x] Q66 Start Phase 7.2 by auditing social-feature direct service coupling (`Messages`, `Profile`, `Circle`) and selecting the first repository boundary pilot.
- [x] Q67 Continue Phase 7.2 by introducing a `MessagesRepository` boundary and migrating `MessagesViewModel` + `MessageNotificationsViewModel` off direct `SocialService`.
- [x] Q68 Continue Phase 7.2 by introducing a `ProfileSocialRepository` pilot boundary and migrating `ProfileViewModel` + `FollowListViewModel` off direct services.
- [x] Q69 Continue Phase 7.2 by extending `ProfileSocialRepository` and migrating `UserProfileViewModel` off direct `SocialService`/`WebFeatureService`.
- [x] Q70 Continue Phase 7.2 by migrating Profile edit-profile mutation workflows to a repository boundary (`EditProfileView` + save/upload path).
- [x] Q71 Continue Phase 7.2 by defining a `Circle` social repository pilot and migrating one high-traffic Circle ViewModel off direct service dependencies.
- [x] Q72 Close Phase 7.2 by running social-feature smoke checks (`Messages`, `Profile`, `Circle`) and marking `P7.2` complete if all pass.
- [x] Q73 Start Phase 7.3 by extracting the first social multi-call use case (`SaveProfileUseCase`) from `EditProfileViewModel`.
- [x] Q74 Continue Phase 7.3 by extracting the next high-traffic social multi-call workflow into a dedicated use case (candidate: feed loading/pagination or squad hydration path).
- [x] Q75 Continue Phase 7.3 by extracting one Circle-side multi-call workflow into a dedicated use case (recommended: squad list/profile hydration path).
- [x] Q76 Close Phase 7.3 by running targeted smoke checks for migrated social use-case pilots and marking `P7.3` complete if all pass.
- [x] Q77 Start Phase 8.1 by auditing `AppState` responsibilities and listing feature-owned state candidates for extraction.
- [x] Q78 Start Phase 8.2 by removing remaining `appState.service` call sites via coordinator/container dependency injection.
- [x] Q79 Continue Phase 8.2 by consolidating unread badge writes under a single owner and removing duplicate cross-feature writes.
- [x] Q80 Start Phase 8.3 by auditing/removing residual transitional architecture glue after `P8.2` closure.
- [x] Q81 Continue Phase 8.3 by removing remaining feature-level fallback service factories and tightening DI-only entry paths in touched social surfaces.
- [x] Q82 Close Phase 8.3 by running targeted smoke checks for touched social DI-entry paths and marking `P8.3` complete if all pass.
- [x] Q83 Start migration hardening by defining post-migration regression checklist automation and CI guards for coordinator/DI boundaries (`scripts/check-mvvm-coordinator-boundaries.sh`).
- [x] Q84 Integrate migration boundary guard script into CI and add a lightweight manual smoke runbook for release checks.
- [x] Q85 Extend CI hardening with optional simulator build lane and required-check recommendation in branch protection.
- [x] Q86 Add focused coordinator-routing regression tests (route serialization and destination mapping) for high-traffic features.
- [x] Q87 Add coordinator deep-link and route round-trip tests for critical entry paths (event detail, user profile, squad profile).
- [x] Q88 Add route-state snapshot fixture tests for selected coordinator flows to catch enum case churn and destination drift.
- [x] Q89 Add contributor guide section for updating route fixtures and validating guard scripts before PR submission.
- [x] Q90 Add helper script to run all coordinator hardening guards in one command for contributor ergonomics.
- [x] Q91 Add a tiny PR template snippet that reminds contributors to run coordinator hardening preflight when touching route enums.
- [x] Q92 Start Phase 9.1 by migrating Discover `EventsModuleView` event-creation entry from local `sheet` to coordinator-owned push route (`DiscoverRoute.eventCreate`) with post-save list refresh signal.
- [x] Q93 Continue Phase 9.1 by migrating `EventDetailView` event-edit entry from local `sheet` to coordinator-owned push route.
- [x] Q94 Continue Phase 9.1 by migrating `NewsModuleView` publish flow from local `sheet` to coordinator-owned push route.
- [x] Q95 Continue Phase 9.1 by migrating `SetsModuleView` create/edit flows from local `sheet` to coordinator-owned push routes (keep short utility selectors modal).
- [x] Q96 Continue Phase 9.1 by migrating `LearnModuleView` create/edit flows from local `sheet` to coordinator-owned push routes.
- [x] Q97 Continue Phase 9.2 by migrating `FeedView` compose/edit post flows from local `sheet` to coordinator-owned push routes in `CircleCoordinator`.
- [x] Q98 Continue Phase 9.2 by migrating `MainTabView` long-form create flows (`ID publish`, `rating create`) to coordinator-owned push routes while retaining utility pickers as modal allowlist.
- [x] Q99 Continue Phase 9.2 by evaluating `SquadProfileView` manage flow against modal allowlist and migrate to push only if product behavior requires.
- [x] Q100 Continue Phase 9.3 by unifying `SearchView` and `NotificationsView` entity hops onto feature coordinator push routes where applicable.
- [x] Q101 Continue Phase 9.4 by documenting remaining modal allowlist with per-screen rationale and adding guard checks for newly introduced non-allowlist modals.
- [x] Q102 Start post-Phase-9 cleanup by converting one approved high-value modal detail flow (from the allowlist) to coordinator push as the next pilot.
- [x] Q103 Continue post-Phase-9 cleanup by migrating `DiscoverSearchViews` DJ detail opening from local `fullScreenCover` to coordinator-owned push routing.
- [x] Q104 Continue post-Phase-9 cleanup by migrating `DiscoverSearchViews` set playback detail opening from local `fullScreenCover` to coordinator-owned push routing.
- [x] Q105 Continue post-Phase-9 cleanup by migrating `DiscoverSearchViews` wiki label/festival detail openings from local `fullScreenCover` to coordinator-owned push routing.
- [x] Q106 Continue post-Phase-9 cleanup by migrating `DiscoverNewsDetailView` DJ/Festival bound-detail openings from local `fullScreenCover` to coordinator-owned push routing.
- [x] Q107 Continue post-Phase-9 cleanup by migrating `NewsModuleView` article-detail opening from local `fullScreenCover` to coordinator-owned push routing.
- [x] Q108 Continue post-Phase-9 cleanup by migrating `DJsModuleView` DJ-detail opening from local `fullScreenCover` to coordinator-owned push routing.
- [x] Q109 Continue post-Phase-9 cleanup by migrating `DJDetailView` related-news opening from local `fullScreenCover` to coordinator-owned push routing.
- [x] Q110 Continue post-Phase-9 cleanup by migrating Learn-domain detail hops (`LearnModuleView` label/festival, `LearnLabelDetailView` founder DJ, `LearnFestivalDetailView` related news, `RankingBoardDetailView` DJ/festival) from local `fullScreenCover` to coordinator-owned push routing.
- [x] Q111 Continue post-Phase-9 cleanup by migrating `EventDetailView` related-news opening from local `fullScreenCover` to coordinator-owned push routing (`DiscoverRoute.newsDetail`), while keeping route planner/rating overlays in modal allowlist.
- [x] Q112 Continue post-Phase-9 cleanup by evaluating Learn ranking-context festival drill-down (`LearnFestivalRankingDetailView`) and keep modal presentation because coordinator push would break ranking-context return semantics.
- [x] Q113 Continue post-Phase-9 cleanup by migrating `SetsModuleView` normal set-detail opening (`selectedSetForPlayback`) to coordinator push (`DiscoverRoute.setDetail`) and keeping `audioListenSetID` as intentional immersive modal.
- [x] Q114 Continue post-Phase-9 cleanup by evaluating `EventDetailView` rating detail overlay (`selectedRatingEventID`) and route planner overlay (`showRoutePlanner`) for final keep-modal vs push decision with explicit rationale.
- [x] Q115 Close current Discover post-Phase-9 cleanup wave by consolidating residual modal rationale wording in `P9.4` and verifying no additional Discover detail-hops remain outside coordinator push or explicit allowlist.
- [x] Q116 Start cross-feature post-Phase-9 cleanup by evaluating `MainTabView` `selectedDetailRoute` full-screen channel (ID detail route), and keep modal with explicit rationale.
- [x] Q117 Continue cross-feature post-Phase-9 cleanup by evaluating `MessagesCoordinator` modal route `MessagesModalRoute.squadProfile` for keep-modal vs push decision with explicit rationale.
- [x] Q118 Continue cross-feature post-Phase-9 cleanup by evaluating `SquadProfileView` manage panel (`SquadManageSheet`) in relation to the updated modal policy and confirming keep-modal rationale remains valid.
- [x] Q119 Continue cross-feature post-Phase-9 cleanup by evaluating `ComposePostView` media/location preview `fullScreenCover` routes for keep-modal vs push decision with explicit rationale.
- [x] Q120 Continue cross-feature post-Phase-9 cleanup by evaluating `Shared/PostCardView` media/location preview `fullScreenCover` routes for keep-modal vs push decision with explicit rationale.
- [x] Q121 Continue cross-feature post-Phase-9 cleanup by evaluating `MainTabView` utility sheet routes (`showEventPicker` / `showDJPicker` / `showCreateSquad`) and confirming keep-modal rationale remains valid.
- [x] Q122 Re-open post-wave cleanup and convert previously deferred modal routes to push across Messages/MainTab/Squad/Discover detail workflows; refresh modal allowlist and rebuild.
- [ ] Q123 Publish a concise migration-complete checklist + residual risk list for handoff/release tracking.

## Migration Hardening Guard

- Boundary guard script:
`scripts/check-mvvm-coordinator-boundaries.sh`
- Modal allowlist guard:
`scripts/check-modal-allowlist.sh`
- Coordinator routing regression guard:
`scripts/check-coordinator-routing-regression.sh`
- Coordinator deep-link round-trip regression guard:
`scripts/check-coordinator-deeplink-roundtrip.sh`
- Coordinator route snapshot guard:
`scripts/check-coordinator-route-snapshots.sh`
- One-command contributor preflight:
`scripts/run-coordinator-hardening-preflight.sh`
- GitHub Actions workflow:
`.github/workflows/mvvm-coordinator-guard.yml`
- Manual release smoke runbook:
`docs/IOS_RELEASE_SMOKE_RUNBOOK.md`
- Branch protection recommendation:
Require `Architecture Boundary Guard`; keep `Optional iOS Simulator Build` as manual/non-required.
- Contributor preflight guide:
`docs/IOS_RELEASE_SMOKE_RUNBOOK.md` section `Contributor PR Preflight`
- Current assertions:
1. Feature layer cannot call `AppEnvironment.makeService/makeWebService`.
2. `appState.service` service-locator access is forbidden.
3. `AppEnvironment.makeService/makeWebService` is only allowed in `RaverMVPApp.swift` and `Application/DI/AppContainer.swift`.
4. High-traffic coordinator route enums keep `Hashable` conformance and case-to-destination mapping parity (`Discover`, `Circle`, `Messages`, `Profile`).
5. Critical deep-link entry paths (`event detail`, `user profile`, `squad profile`) keep route-case presence and URL/token round-trip integrity.
6. Coordinator route-case snapshots are fixture-locked (`DiscoverRoute`, `CircleRoute`, `MessagesRoute`, `MessagesModalRoute`, `ProfileRoute`) to detect unreviewed enum churn.
7. `sheet/fullScreenCover` usage is frozen by `scripts/modal-allowlist-signatures.txt`; any new modal route requires explicit allowlist update plus rationale.

## Discover Migration Template

Use this template for each new Discover extraction or MVVM conversion.

Folder layout:

- `Features/Discover/<Domain>/Views/`
- `Features/Discover/<Domain>/ViewModels/`
- Add `Components/` only when UI pieces are reused by more than one screen in that domain.

Composition pattern:

1. Create a lightweight root container view that reads `AppContainer` from the environment.
2. Instantiate the domain `ViewModel` from that container view.
3. Pass the `ViewModel` into the screen view via `StateObject`.
4. Keep navigation in `DiscoverCoordinator` or `discoverPush`.
5. Do not call `AppEnvironment.makeService()` directly inside the moved screen view.

View skeleton:

- Root container:
  `Discover<Domain>RootView`
- Screen:
  `<Domain>...View(viewModel: ...)`
- ViewModel:
  `<Domain>...ViewModel(service: ...)`

When moving code out of `WebModulesView.swift`:

1. Move the screen first with minimal logic change.
2. Extract any nested `ViewModel` into `Features/Discover/<Domain>/ViewModels/`.
3. Expose only the helpers that must cross file boundaries.
4. Prefer widening from `private` to module-internal only, not to `public`.
5. Delete the old in-file copy after the new file is wired up.

Access-control checklist:

- Shared enums used across files should be module-internal.
- Shared cards, rows, or helper extensions used across files should be module-internal.
- Domain-only helper sheets can stay `private` inside the new domain file.

Project wiring checklist:

1. Add new files to `project.pbxproj`.
2. Add new domain groups under `Features/Discover/`.
3. Compile immediately after wiring.

Verification checklist:

1. `xcodebuild` Debug simulator build succeeds.
2. Moved screen no longer creates services directly.
3. Existing navigation and user-facing behavior remain intact.
4. Update this migration document in the same turn.

## Feature Coordinator Migration Template

Use this template for non-Discover features (Messages/Profile/Circle) when moving from mixed routing to `MVVM + Coordinator`.

Route ownership pattern:

1. Define feature route enum in `Features/<Feature>/Coordinator/`.
2. Make coordinator own `NavigationStack` path state.
3. Expose an environment push closure (for example `featurePush`) for child views.
4. Keep modal channels only when behavior requires them; prefer push routing to reduce presentation-channel fragmentation.
5. Build all route destinations in the coordinator and inject dependencies there.

Dependency and ViewModel composition pattern:

1. Read shared dependencies from `AppContainer` in coordinator/root container views.
2. Prefer coordinator-owned shared ViewModels when multiple destinations rely on the same state tree.
3. Keep View-owned state limited to ephemeral UI state (selection, local toggles, transient text input).
4. Move networking/pagination/mutation workflows into ViewModels.
5. Remove `AppEnvironment.makeService/makeWebService` usage from touched feature views.

Incremental rollout checklist:

1. Migrate high-frequency route hops first.
2. Migrate deep subflows second.
3. Convert large stateful screens to ViewModel-driven state after route ownership is stable.
4. Decompose oversized files only after routing/state boundaries are clear.
5. Compile and smoke test at each step; update this document in the same turn.

## Definition of Done Per Migration Step

Each migration step is considered done only if:

- Code compiles successfully.
- Existing user-facing behavior for the migrated scope still works.
- Navigation state has moved to the intended coordinator.
- Direct service creation is removed from newly migrated views.
- This Markdown file is updated with status changes and any scope changes.

## Working Agreement For Future Agents

Before starting work:

- Read this file first.
- Pick the highest-priority unchecked item unless the user explicitly reprioritizes.
- If scope changes, update this file before or together with the code change.

While working:

- If you complete an item, mark it `[x]`.
- If you partially complete an item, leave it unchecked and add a note in the progress log.
- If you discover a blocker, add it to the blockers section with date and impact.

After finishing work:

- Update the relevant phase status.
- Add a short progress log entry with date, scope, and key files changed.

## Blockers

- None currently recorded.

## Decision Log

- 2026-04-09: Migration will be incremental rather than a big-bang rewrite.
- 2026-04-09: Discover is the first feature migration target because it is the most complex and bug-prone module.
- 2026-04-09: Root and tab navigation must be coordinator-owned before broad feature MVVM cleanup.
- 2026-04-09: The iOS Xcode project uses manual `PBXGroup` and `PBXBuildFile` entries, so new migration files must be added to `project.pbxproj` explicitly.
- 2026-04-09: `AppCoordinator` will first mirror the existing root login-vs-main branching before `RaverMVPApp.swift` is rewired, keeping Q2 and Q4 as separate low-risk steps.
- 2026-04-09: `MainTabCoordinator` initially owns only top-level tab selection, while existing tab content remains inside `MainTabView` to avoid broad feature churn during Phase 1.
- 2026-04-09: App bootstrapping now creates shared `SocialService` and `WebFeatureService` instances once in `RaverMVPApp` and injects both `AppState` and `AppContainer` from the root.
- 2026-04-09: `DiscoverCoordinator` is introduced as a reusable navigation container first; actual route ownership migration from `DiscoverHomeView` remains a separate Q6 step.
- 2026-04-09: `DiscoverHomeView` is now a pure content view embedded by `DiscoverCoordinatorView`; search route ownership has moved to the coordinator, while event-detail routing still remains outside Phase 2's completed scope.
- 2026-04-09: Discover event detail openings now route through `DiscoverCoordinator` via `DiscoverRoute.eventDetail`, replacing local full-screen presentation state inside Discover subviews.
- 2026-04-09: Discover-owned detail presentations that can recursively open other Discover routes should be wrapped in `DiscoverCoordinatorView` so nested event-detail pushes stay on the visible navigation stack and preserve right-edge push animation.
- 2026-04-09: Phase 3 starts with Discover search results screens; coordinators should create those screens with injected ViewModels so route destinations do not instantiate services inside views.
- 2026-04-09: Discover file decomposition will proceed by business domain, not by generic screen type; `Search` is the first pilot slice because it is already under active MVVM migration.
- 2026-04-09: `WikiSearchResultsView` can move out of `WebModulesView.swift` during the search pilot, but Learn detail implementations should stay put until their shared types and dependencies are safely exposed across files.
- 2026-04-09: Discover root feature modules can use lightweight environment-backed container views, such as `DiscoverEventsRootView`, to inject services into `StateObject`-owned MVVM screens without reintroducing service creation inside views.
- 2026-04-09: The reusable Discover migration template is now: `Domain Root Container -> StateObject Screen -> Injected ViewModel`, with domain folders under `Features/Discover/<Domain>/`.
- 2026-04-09: Shared event presentation types such as `EventVisualStatus`, `EventRow`, and `WebEvent` presentation extensions should live in the `Events` domain as soon as they are reused by extracted screens, even if some remaining callers still reside in `WebModulesView.swift`.
- 2026-04-09: `EventDetailView` should use `AppContainer` environment injection after extraction so Discover detail surfaces do not regress to direct service factory calls inside views.
- 2026-04-09: Event lineup and check-in model helpers can be extracted to `Features/Discover/Events/Views/EventLineupSupport.swift` with module-level visibility while dependent editor surfaces remain in `WebModulesView.swift`.
- 2026-04-09: Event editor extraction should include dependent inline UIKit text fields (`UIKitInlineTextField`, `TimeAutoColonTextField`) so the editor file no longer relies on helper definitions in `WebModulesView.swift`.
- 2026-04-09: When `EventCalendarSheet` moves out of `WebModulesView.swift`, shared date helpers such as `Calendar.startOfMonth(for:)` must be module-visible instead of file-private.
- 2026-04-09: News extraction should continue inside the domain by splitting `NewsModuleView.swift` into focused files (`Models`, `Codec`, `Detail`, `Publish`) while preserving UI behavior and keeping cross-file symbols module-internal.
- 2026-04-09: DJ extraction can move as a single mechanical block first (`DJsModuleView` + `DJDetailView` and nested helpers), then expose only the minimum shared helpers (`RankingBoard` metadata accessors, avatar/initials helpers) to satisfy remaining callers in `WebModulesView.swift`.
- 2026-04-09: Sets extraction can follow the same mechanical-first strategy as DJs, with Xcode project wiring completed in the same step and compile checks used to catch any cross-file helper visibility issues.
- 2026-04-09: Learn extraction can move as one mechanical block (`LearnModuleView` plus detail/ranking surfaces) and leave `WebModulesView.swift` with only shared infrastructure helpers; shared safe-area helpers should be module-visible when consumed across files.
- 2026-04-09: Phase 5 starts with a low-risk `MessagesCoordinator` container that owns the root `NavigationStack`, while existing Messages route state remains in `MessagesHomeView` until the later ViewModel normalization step.
- 2026-04-09: `ProfileCoordinator` follows the same low-risk pattern as Messages: coordinator owns the root `NavigationStack`, while existing Profile route and view-model/service patterns remain unchanged until Phase 5 normalization steps.
- 2026-04-09: Phase 5.3 normalization for Messages will proceed incrementally, starting with root-screen ViewModel injection from `AppContainer` before touching deeper message creation/editor subflows.
- 2026-04-09: Phase 5.4 normalization for Profile will mirror Messages by first moving root-screen ViewModel creation to a container view, then iterating through profile subflows that still instantiate services directly.
- 2026-04-09: For shared screens reused across tabs (e.g., follow list and profile editor), prefer explicit `service` injection from caller context over hidden defaults, to keep flow ownership visible during migration.
- 2026-04-09: Profile module normalization should remove `AppEnvironment.makeService/makeWebService` usage from large nested module files (`WebProfileModulesView`) by using `AppContainer` environment injection, even for nested editor sheets, to keep dependency sourcing consistent and testable.
- 2026-04-09: Messages route migration should proceed incrementally; first move conversation push routing into `MessagesCoordinator` using an environment push closure (`messagesPush`) while keeping alert-detail subflows local until a later step.
- 2026-04-09: Messages coordinator should support both push and full-screen modal route channels (`messagesPush`, `messagesPresent`) so existing squad-detail full-screen behavior can be preserved while route ownership moves out of feature views.
- 2026-04-09: For Messages normalization, coordinator-level shared ViewModel ownership is preferred once multiple destinations depend on the same unread/notification state, so route migration does not create duplicate view-model state trees.
- 2026-04-09: Profile route migration should follow the same incremental pattern as Discover/Messages: start with a lightweight `profilePush` channel for high-frequency push targets (follow list, user profile, settings) before moving deeper modal flows.
- 2026-04-09: Profile route migration now uses dual channels (`profilePush` + `profilePresent`) so deep Profile/Feed overlays (`postDetail`, `checkins`, `avatar fullscreen`) can remain behaviorally full-screen while route ownership moves to the coordinator.
- 2026-04-09: `ProfileCoordinator` now owns a shared `ProfileViewModel` (similar to Messages), enabling edit/profile-update callbacks and the remaining profile entry routes (`edit`, `publish`, `upload`) to migrate without local view-owned route state.
- 2026-04-09: For Profile migration, coordinator-driven routes should prefer `NavigationStack` push presentation over `sheet/fullScreenCover` when behavior allows, to reduce presentation-channel fragmentation.
- 2026-04-09: `WebProfileModulesView` subflows should also follow push-only routing (`navigationDestination`) to keep Profile presentation behavior consistent and avoid mixed modal channels.
- 2026-04-09: For deep Profile subviews (e.g., `MyCheckinsView` / `MyPublishesView`), detail hops should prefer coordinator-owned `profilePush` routes over local selected-ID route state when destination payloads are simple IDs.
- 2026-04-09: `P5.4` now uses an explicit scope tracker (`completed scope` + `remaining scope`) and queued closure items (`Q36-Q39`) so future agents can resume Profile normalization without inferring hidden work.
- 2026-04-09: A generic `Feature Coordinator Migration Template` is now part of this document to reuse Messages/Profile migration patterns when Phase 6 (`Circle`) begins.
- 2026-04-09: Circle migration starts with the same low-risk pattern used by Messages/Profile: add a root coordinator that owns the tab's `NavigationStack` first, then migrate Circle routes incrementally in subsequent steps.
- 2026-04-09: Circle route migration now follows a push-first channel (`CircleRoute` + `circlePush`) from coordinator-owned root navigation; start with stable root destinations before migrating deeper modal/detail subflows.
- 2026-04-09: For Circle nested-flow migration, prioritize moving one subflow at a time to coordinator-owned routes and preserve UI behavior by keeping existing sheet state until each replacement path is verified.
- 2026-04-09: `P8` should treat AppState cleanup as responsibility isolation first: keep truly global state in `AppState`, but remove its service-locator role (`appState.service` call sites) and duplicate feature-side writes before considering deeper field reshaping.

## Progress Log

- 2026-04-09: Completed architecture assessment and created the long-lived migration plan document.
- 2026-04-09: Completed Q1 by adding `Application/DI/AppContainer.swift` and wiring it into the Xcode project for compilation.
- 2026-04-09: Verified Q1 with a successful `xcodebuild` Debug simulator build for the `RaverMVP` scheme.
- 2026-04-09: Completed Q2 by adding `Application/Coordinator/AppCoordinator.swift` as the new root flow coordinator view and wiring it into the Xcode project.
- 2026-04-09: Verified Q2 with a successful `xcodebuild` Debug simulator build for the `RaverMVP` scheme.
- 2026-04-09: Completed Q3 by adding `Application/Coordinator/MainTabCoordinator.swift`, moving top-level tab selection ownership into the coordinator, and updating existing entry points to render it.
- 2026-04-09: Verified Q3 with a successful `xcodebuild` Debug simulator build for the `RaverMVP` scheme.
- 2026-04-09: Completed Q4 by updating `RaverMVPApp.swift` to boot through `AppCoordinatorView`, injecting `AppContainer` and `AppState` from the app root, and removing the old `RootView`.
- 2026-04-09: Verified Q4 with a successful `xcodebuild` Debug simulator build for the `RaverMVP` scheme.
- 2026-04-09: Completed Q5 by adding `Features/Discover/Coordinator/DiscoverCoordinator.swift`, extracting `DiscoverRoute` and related search routing types into `DiscoverRoute.swift`, and wiring both files into the Xcode project.
- 2026-04-09: Verified Q5 with a successful `xcodebuild` Debug simulator build for the `RaverMVP` scheme.
- 2026-04-09: Completed Q6 by embedding `DiscoverHomeView` inside `DiscoverCoordinatorView`, removing `NavigationStack` and `navPath` ownership from `DiscoverHomeView`, and making the coordinator the owner of Discover search route state.
- 2026-04-09: Verified Q6 with a successful `xcodebuild` Debug simulator build for the `RaverMVP` scheme.
- 2026-04-09: Completed P2.3 by adding `DiscoverRoute.eventDetail` and routing Discover event-detail entry points through `discoverPush`, removing local event-detail full-screen presentation state from Discover modules and detail descendants.
- 2026-04-09: Verified P2.3 with a successful `xcodebuild` Debug simulator build for the `RaverMVP` scheme.
- 2026-04-09: Completed P2.4 by wrapping local Discover detail full-screen presentations in `DiscoverCoordinatorView`, preserving nested Discover navigation behavior after the coordinator migration.
- 2026-04-09: Verified P2.4 with a successful `xcodebuild` Debug simulator build and manual simulator smoke testing for news-related events, festival-related events, and DJ-related event transitions.
- 2026-04-09: Completed Q7 by adding `DiscoverSearchResultsViewModels.swift`, converting event/news search result screens to ViewModel-owned state, and injecting services from `AppContainer` through Discover route destination construction.
- 2026-04-09: Verified Q7 with a successful `xcodebuild` Debug simulator build for the `RaverMVP` scheme.
- 2026-04-09: Completed Q8 by converting `DJs`, `Sets`, and `Wiki` search result screens to coordinator-injected ViewModel screens, removing direct service creation from those touched Discover views.
- 2026-04-09: Established `Search` as the pilot Discover decomposition slice by moving search views into `Features/Discover/Search/Views` and colocating their ViewModels in `Features/Discover/Search/ViewModels`.
- 2026-04-09: Verified Q8 and the Search pilot extraction with a successful `xcodebuild` Debug simulator build for the `RaverMVP` scheme.
- 2026-04-09: Completed Q9 by moving `EventsModuleView` to `Features/Discover/Events/Views`, extracting `EventsModuleViewModel` to `Features/Discover/Events/ViewModels`, and composing the screen through `DiscoverEventsRootView` with `AppContainer`-injected `webService`.
- 2026-04-09: Completed Q11 by starting the Discover `Events` domain extraction with dedicated `Events/Views` and `Events/ViewModels` folders, reducing `WebModulesView.swift` to 23,840 lines while preserving buildable behavior.
- 2026-04-09: Verified Q9 and Q11 with a successful `xcodebuild` Debug simulator build for the `RaverMVP` scheme.
- 2026-04-09: Completed Q10 by documenting a reusable Discover migration template in this plan, based on the now-proven `Search` and `Events` extraction patterns.
- 2026-04-09: Completed Q12 by moving `RecommendEventsModuleView`, `RecommendEventsViewModel`, `EventVisualStatus`, `EventRow`, `OngoingStatusBars`, and `WebEvent` event-presentation helpers into `Features/Discover/Events/...`, and rewiring `DiscoverHomeView` through `DiscoverRecommendEventsRootView`.
- 2026-04-09: Verified Q12 with a successful `xcodebuild` Debug simulator build for the `RaverMVP` scheme; `WebModulesView.swift` is now down to 22,847 lines.
- 2026-04-09: Completed Q13 by extracting `EventDetailView` and related event-detail helpers into `Features/Discover/Events/Views/EventDetailView.swift`, and moving lineup/check-in support models into `Features/Discover/Events/Views/EventLineupSupport.swift`.
- 2026-04-09: Verified Q13 with a successful `xcodebuild` Debug simulator build for the `RaverMVP` scheme; `WebModulesView.swift` is now down to 19,066 lines.
- 2026-04-09: Completed Q14 by extracting `EventEditorView`, `EventCheckinSelectionSheet`, location-picker helpers, and dependent inline text-field wrappers into `Features/Discover/Events/Views/EventEditorView.swift`.
- 2026-04-09: Verified Q14 with a successful `xcodebuild` Debug simulator build for the `RaverMVP` scheme; `WebModulesView.swift` is now down to 14,595 lines.
- 2026-04-09: Completed Q15 by extracting `EventCalendarSheet`, `EventCalendarViewFilter`, and `EventTypeOption` into `Features/Discover/Events/Views/EventCalendarSupport.swift`, and wiring the file into the Xcode project sources.
- 2026-04-09: Verified Q15 with a successful `xcodebuild` Debug simulator build for the `RaverMVP` scheme after promoting `Calendar.startOfMonth(for:)` to module visibility; `WebModulesView.swift` is now down to 14,116 lines.
- 2026-04-09: Completed Q16/P4.2 by extracting Discover News into a dedicated domain folder and splitting it into `News/Models/DiscoverNewsModels.swift`, `News/Models/DiscoverNewsCodec.swift`, `News/Views/NewsModuleView.swift`, `News/Views/DiscoverNewsDetailView.swift`, and `News/Views/DiscoverNewsPublishSheet.swift`, with explicit Xcode project wiring.
- 2026-04-09: Verified Q16/P4.2 with a successful `xcodebuild` Debug simulator build for the `RaverMVP` scheme; `NewsModuleView.swift` is now reduced to 322 lines.
- 2026-04-09: Completed Q17/P4.3 by extracting `DJsModuleView`, `DJDetailView`, and associated DJ domain helpers into `Features/Discover/DJs/Views/DJsModuleView.swift`, wiring a new `DJs` group into `project.pbxproj`, and removing the DJ block from `WebModulesView.swift`.
- 2026-04-09: Verified Q17/P4.3 with a successful `xcodebuild` Debug simulator build for the `RaverMVP` scheme after promoting shared DJ helpers (`initials(of:)`, `highResAvatarURL(_:)`) and `RankingBoard` extension visibility for cross-file use; `WebModulesView.swift` is now down to 8,526 lines.
- 2026-04-09: Completed Q18/P4.4 by extracting `SetsModuleView` and related Sets domain surfaces into `Features/Discover/Sets/Views/SetsModuleView.swift`, adding a new `Sets` group in `project.pbxproj`, and removing the Sets block from `WebModulesView.swift`.
- 2026-04-09: Verified Q18/P4.4 with a successful `xcodebuild` Debug simulator build for the `RaverMVP` scheme; `WebModulesView.swift` is now down to 4,290 lines.
- 2026-04-09: Completed Q19/P4.5 by extracting Learn domain screens (`LearnModuleView`, `LearnLabelDetailView`, `LearnFestivalDetailView`, `RankingBoardDetailView`, and related Learn helpers/extensions) into `Features/Discover/Learn/Views/LearnModuleView.swift`, wiring a new `Learn` group in `project.pbxproj`, and removing the Learn block from `WebModulesView.swift`.
- 2026-04-09: Verified Q19/P4.5 with a successful `xcodebuild` Debug simulator build for the `RaverMVP` scheme after promoting `topSafeAreaInset()` to module visibility for cross-file use; `WebModulesView.swift` is now down to 211 lines.
- 2026-04-09: Completed Q20/P5.1 by adding `Features/Messages/Coordinator/MessagesCoordinator.swift`, wiring it into `project.pbxproj`, updating `MainTabView` to host Messages through the coordinator, and removing root `NavigationStack` ownership from `MessagesHomeView`.
- 2026-04-09: Verified Q20/P5.1 with a successful `xcodebuild` Debug simulator build for the `RaverMVP` scheme.
- 2026-04-09: Completed Q21/P5.2 by adding `Features/Profile/Coordinator/ProfileCoordinator.swift`, wiring it into `project.pbxproj`, updating `MainTabView` to host Profile through the coordinator, and removing root `NavigationStack` ownership from `ProfileView`.
- 2026-04-09: Verified Q21/P5.2 with a successful `xcodebuild` Debug simulator build for the `RaverMVP` scheme.
- 2026-04-09: Completed Q22 (P5.3 partial) by adding `MessagesRootView` in `Features/Messages/Coordinator/MessagesCoordinator.swift`, changing `MessagesHomeView` to accept injected `MessagesViewModel` and `MessageNotificationsViewModel`, and updating `MainTabView` to route Messages through the root container.
- 2026-04-09: Verified Q22 with a successful `xcodebuild` Debug simulator build for the `RaverMVP` scheme.
- 2026-04-09: Completed Q23 (P5.4 partial) by adding `ProfileRootView` in `Features/Profile/Coordinator/ProfileCoordinator.swift`, changing `ProfileView` to accept injected `ProfileViewModel`, and updating `MainTabView` to route Profile through the root container.
- 2026-04-09: Verified Q23 with a successful `xcodebuild` Debug simulator build for the `RaverMVP` scheme.
- 2026-04-09: Completed Q24 (P5.3/P5.4 partial) by switching `CreateSquadView` to use `AppContainer.webService`, changing `FollowListView` and `EditProfileView` to accept injected `SocialService`, updating Profile call sites to pass `appState.service`, and removing the default `AppEnvironment.makeWebService()` from `ProfileViewModel`.
- 2026-04-09: Verified Q24 with a successful `xcodebuild` Debug simulator build for the `RaverMVP` scheme.
- 2026-04-09: Completed Q25 (P5.4 partial) by removing the remaining direct service factories from `Features/Profile/WebProfileModulesView.swift` (`MyCheckinsView`, `MyPublishesView`, `RatingEventEditorSheet`, `RatingUnitEditorSheet`) and switching them to `AppContainer`-injected `socialService`/`webService`.
- 2026-04-09: Verified Q25 with a successful `xcodebuild` Debug simulator build for the `RaverMVP` scheme.
- 2026-04-09: Completed Q26 (P5.3 partial) by adding `MessagesRoute` and `messagesPush` environment routing in `Features/Messages/Coordinator/MessagesCoordinator.swift`, then changing `MessagesHomeView` conversation selection to coordinator-owned push routing.
- 2026-04-09: Verified Q26 with a successful `xcodebuild` Debug simulator build for the `RaverMVP` scheme.
- 2026-04-09: Completed Q27 (P5.3 partial) by extending `MessagesCoordinator` with `userProfile` push routing and coordinator-owned full-screen `squadProfile` modal routing, then migrating `ChatView` and `MessageAlertDetailView` to call coordinator routes instead of local `navigationDestination/fullScreenCover` state.
- 2026-04-09: Verified Q27 with a successful `xcodebuild` Debug simulator build for the `RaverMVP` scheme.
- 2026-04-09: Completed Q28 (P5.3 partial) by refactoring `MessagesCoordinatorView` to own shared `MessagesViewModel` and `MessageNotificationsViewModel`, routing alert-category detail through `MessagesRoute.alertCategory`, and removing local alert-category navigation state from `MessagesHomeView`.
- 2026-04-09: Verified Q28 with a successful `xcodebuild` Debug simulator build for the `RaverMVP` scheme.
- 2026-04-09: Completed Q29 (P5.4 partial) by adding `ProfileRoute` and `profilePush` in `Features/Profile/Coordinator/ProfileCoordinator.swift`, then migrating `ProfileView` follow-list, author-profile, and settings push navigation away from local state bindings to coordinator-owned routes.
- 2026-04-09: Verified Q29 with a successful `xcodebuild` Debug simulator build for the `RaverMVP` scheme.
- 2026-04-09: Completed Q30 (P5.4 partial) by adding `ProfileModalRoute` and `profilePresent` in `Features/Profile/Coordinator/ProfileCoordinator.swift`, then migrating `ProfileView` and `UserProfileView` local route state (`myPublishes`, `myCheckins`, `postDetail`, avatar fullscreen, direct-message conversation) into coordinator-owned routing, and updating `FollowListView` user taps to use `profilePush`.
- 2026-04-09: Verified Q30 with a successful `xcodebuild` Debug simulator build for the `RaverMVP` scheme.
- 2026-04-09: Completed Q31 (P5.4 partial) by refactoring `ProfileCoordinatorView` to own shared `ProfileViewModel`, introducing `ProfileSheetRoute` (`profileSheet`) in addition to `profilePush/profilePresent`, migrating `ProfileView` local edit/publish/upload route state to coordinator channels, and updating `MainTabView` to instantiate the coordinator with `AppContainer` services.
- 2026-04-09: Verified Q31 with a successful `xcodebuild` Debug simulator build for the `RaverMVP` scheme.
- 2026-04-09: Completed Q32 (P5.4 partial) by removing `ProfileModalRoute`/`ProfileSheetRoute` channels, expanding `ProfileRoute` to cover migrated Profile subflows (`myCheckins`, `postDetail`, `avatarFullscreen`, `publishEvent`, `uploadSet`), and routing `ProfileView`/`UserProfileView` exclusively through `profilePush` + `NavigationStack` destinations.
- 2026-04-09: Verified Q32 with a successful `xcodebuild` Debug simulator build for the `RaverMVP` scheme.
- 2026-04-09: Completed Q33 (P5.4 partial) by replacing `MyCheckinsView` and `MyPublishesView` local `sheet/fullScreenCover` routes in `Features/Profile/WebProfileModulesView.swift` with `navigationDestination` push routes (event detail, DJ detail, event/set/rating editors).
- 2026-04-09: Verified Q33 with a successful `xcodebuild` Debug simulator build for the `RaverMVP` scheme.
- 2026-04-09: Completed Q34 (P5.4 partial) by adding `ProfileRoute.eventDetail` / `ProfileRoute.djDetail` and switching `MyCheckinsView` / `MyPublishesView` detail jumps from local `selectedEventIDForDetail`/`selectedDJIDForDetail` state to coordinator-driven `profilePush`.
- 2026-04-09: Verified Q34 with a successful `xcodebuild` Debug simulator build for the `RaverMVP` scheme.
- 2026-04-09: Completed Q35 (P5.4 partial) by introducing `MyPublishesViewModel` inside `Features/Profile/WebProfileModulesView.swift`, migrating `MyPublishesView` data loading/edit fetch/delete mutations out of the view, and updating `ProfileCoordinator` to inject `webService` + `socialService` into `MyPublishesView`.
- 2026-04-09: Verified Q35 with a successful `xcodebuild` Debug simulator build for the `RaverMVP` scheme.
- 2026-04-09: Completed Q36 (P5.4 partial) by introducing `MyCheckinsViewModel` in `Features/Profile/WebProfileModulesView.swift`, migrating check-ins reload/pagination/delete and identity hydration flows out of `MyCheckinsView`, and switching the screen to `StateObject`-driven loading state.
- 2026-04-09: Verified Q36 with a successful `xcodebuild` Debug simulator build for the `RaverMVP` scheme.
- 2026-04-09: Completed Q37 (P5.4 partial) by introducing `RatingEventEditorViewModel` and `RatingUnitEditorViewModel` in `Features/Profile/WebProfileModulesView.swift`, and migrating rating editor save/upload/error business logic out of `RatingEventEditorSheet` / `RatingUnitEditorSheet`.
- 2026-04-09: Verified Q37 with a successful `xcodebuild` Debug simulator build for the `RaverMVP` scheme.
- 2026-04-09: Completed Q38 (P5.4 partial) by decomposing `Features/Profile/WebProfileModulesView.swift` into `Features/Profile/Views/Checkins/MyCheckinsView.swift`, `Features/Profile/Views/Publishes/MyPublishesView.swift`, and `Features/Profile/Views/RatingEditors/RatingEditors.swift`, wiring those files into `project.pbxproj`, and keeping `WebProfileModulesView.swift` as a migration shim.
- 2026-04-09: Verified Q38 with a successful `xcodebuild` Debug simulator build for the `RaverMVP` scheme.
- 2026-04-09: Completed Q39a (P5.4 hardening) by adding `@MainActor` to `MyCheckinsViewModel`, `MyPublishesViewModel`, and `RatingEventEditorViewModel` after reproducing Profile check-ins detail-route warning (`Publishing changes from background threads is not allowed`), and verified with a successful `xcodebuild` Debug simulator build.
- 2026-04-09: Completed Q39 by running Profile smoke checks (profile home, follow list, user profile, checkins timeline/gallery, publishes edit/delete, post detail) with all checks passing; marked `P5.4` as complete.
- 2026-04-09: Completed Q40/P6.1 by adding `Features/Circle/Coordinator/CircleCoordinator.swift`, wiring it into `project.pbxproj`, and routing the Circle tab in `MainTabView` through `CircleCoordinatorView` so root `NavigationStack` ownership now lives in the coordinator.
- 2026-04-09: Verified Q40/P6.1 with a successful `xcodebuild` Debug simulator build for the `RaverMVP` scheme.
- 2026-04-09: Completed Q41 (P6.2 partial) by introducing `CircleRoute` + `circlePush` in `Features/Circle/Coordinator/CircleCoordinator.swift`, adding coordinator-owned `navigationDestination` handling, and migrating `SquadHallView` squad openings (card tap + create flow) from local `fullScreenCover` state to coordinator push routing.
- 2026-04-09: Verified Q41 with a successful `xcodebuild` Debug simulator build for the `RaverMVP` scheme.
- 2026-04-09: Completed Q42 (P6.3 partial) by migrating the first nested Circle subflow (`CircleRatingHubView` -> `CircleRatingEventDetailView`) from local `fullScreenCover` state to coordinator-owned `CircleRoute.ratingEventDetail` push routing, and updating detail close behavior to support push-stack dismissal.
- 2026-04-09: Verified Q42 with a successful `xcodebuild` Debug simulator build for the `RaverMVP` scheme.
- 2026-04-09: Completed Q43 (P6.3 partial) by extending `CircleRoute`/`CircleCoordinator` with `eventDetail`, `djDetail`, and `userProfile` destinations, then migrating `CircleIDHubView` event/DJ/contributor detail hops from local `fullScreenCover` state to coordinator-owned `circlePush` routing.
- 2026-04-09: Verified Q43 with a successful `xcodebuild` Debug simulator build for the `RaverMVP` scheme.
- 2026-04-09: Completed Q44 (P6.3 partial) by replacing `CircleRatingEventDetailView` source-event local `selectedSourceEventIDForDetail` + `fullScreenCover` flow with coordinator-owned `circlePush(.eventDetail(...))` routing.
- 2026-04-09: Verified Q44 with a successful `xcodebuild` Debug simulator build for the `RaverMVP` scheme.
- 2026-04-09: Completed Q45 (P6.3 partial) by removing redundant root `NavigationStack` wrappers from `CircleIDHubView` and `SquadHallView` while keeping modal-local stacks (sheet/full-screen) unchanged.
- 2026-04-09: Verified Q45 with a successful `xcodebuild` Debug simulator build for the `RaverMVP` scheme.
- 2026-04-09: Completed Q46 (P6.3 partial) by migrating `FeedView` author-profile navigation from local `navigationDestination` state to coordinator-owned `circlePush(.userProfile(...))`, and removing the now-redundant root `NavigationStack` from `FeedView`.
- 2026-04-09: Verified Q46 with a successful `xcodebuild` Debug simulator build for the `RaverMVP` scheme.
- 2026-04-09: Completed Q47 (P6.3 partial) by removing `CircleIDDetailView` local event/DJ/user `fullScreenCover` state and routing those taps through coordinator-owned `circlePush` via a dismiss-then-push handoff.
- 2026-04-09: Verified Q47 with a successful `xcodebuild` Debug simulator build for the `RaverMVP` scheme.
- 2026-04-09: Completed additional P6.3 residual route cleanup by extending `CircleRoute` with `postDetail(Post)` and migrating `FeedView` post-detail opening from local `fullScreenCover` to coordinator-owned push routing.
- 2026-04-09: Verified the additional P6.3 route cleanup with a successful `xcodebuild` Debug simulator build for the `RaverMVP` scheme.
- 2026-04-09: Completed Q48 and closed `P6.3` after Circle smoke checks passed for Feed, Squads, ID, and Rating routes (user-verified PASS on all checkpoints).
- 2026-04-09: Clarified migration governance by updating `P5.4` with explicit completed/remaining scope, extending the immediate queue with `Q36-Q45`, aligning `Target Folder Layout` with current domain-first Discover structure, and adding a reusable `Feature Coordinator Migration Template` for Phase 6 onward.
- 2026-04-09: Completed Q49 (P7.1 partial) by introducing a Discover Events repository boundary (`DiscoverEventsRepository` + adapter), extracting first pilot use cases (`FetchDiscoverEventsPage`, `FetchMarkedEventCheckins`, `ToggleMarkedEvent`), and migrating Discover Events list/recommend/search ViewModels plus coordinator/container injection to the new boundary.
- 2026-04-09: Verified Q49 with a successful `xcodebuild` Debug simulator build for the `RaverMVP` scheme.
- 2026-04-09: Completed Q50 (P7.1 partial) by introducing Discover News repository/use-case boundaries (`DiscoverNewsRepository`, `SearchDiscoverNewsUseCase`), migrating `NewsSearchResultsViewModel` off direct `SocialService`, and wiring `AppContainer` + `DiscoverRoute` to inject the new boundary.
- 2026-04-09: Verified Q50 with a successful `xcodebuild` Debug simulator build for the `RaverMVP` scheme.
- 2026-04-09: Completed Q51 (P7.1 partial) by introducing Discover DJs repository/use-case boundaries (`DiscoverDJsRepository`, `SearchDiscoverDJsUseCase`), migrating `DJsSearchResultsViewModel` off direct `WebFeatureService`, and wiring `AppContainer` + `DiscoverRoute` to inject the new boundary.
- 2026-04-09: Verified Q51 with a successful `xcodebuild` Debug simulator build for the `RaverMVP` scheme.
- 2026-04-09: Completed Q52 (P7.1 partial) by introducing Discover Sets repository/use-case boundaries (`DiscoverSetsRepository`, `SearchDiscoverSetsUseCase`), migrating `SetsSearchResultsViewModel` off direct `WebFeatureService`, and wiring `AppContainer` + `DiscoverRoute` to inject the new boundary.
- 2026-04-09: Verified Q52 with a successful `xcodebuild` Debug simulator build for the `RaverMVP` scheme.
- 2026-04-09: Completed Q53 (P7.1 partial) by introducing Discover Wiki repository/use-case boundaries (`DiscoverWikiRepository`, `SearchDiscoverWikiUseCase`), migrating `WikiSearchResultsViewModel` off direct `WebFeatureService`, and wiring `AppContainer` + `DiscoverRoute` to inject the new boundary.
- 2026-04-09: Verified Q53 with a successful `xcodebuild` Debug simulator build for the `RaverMVP` scheme.
- 2026-04-09: Completed Q54 (P7.1 partial) by extending `DiscoverNewsRepository` with feed-page/publish capabilities and migrating `NewsModuleView` load-more and publish flows from local `AppEnvironment.makeService()` usage to `AppContainer`-injected repository boundaries.
- 2026-04-09: Verified Q54 with a successful `xcodebuild` Debug simulator build for the `RaverMVP` scheme.
- 2026-04-09: Completed Q55 (P7.1 partial) by extending `DiscoverNewsRepository` with comment read/write capabilities and migrating `DiscoverNewsDetailView` comment loading/submission flows from local social-service construction to `AppContainer`-injected repository boundaries.
- 2026-04-09: Verified Q55 with a successful `xcodebuild` Debug simulator build for the `RaverMVP` scheme.
- 2026-04-09: Completed Q56 (P7.1 partial) by extending `DiscoverNewsRepository` with bound-entity hydration methods (`fetchDJ`, `fetchEvent`, `fetchLearnFestivals`) and migrating `DiscoverNewsDetailView` DJ/Event/Festival hydration flows off local `WebFeatureService` usage.
- 2026-04-09: Verified Q56 with a successful `xcodebuild` Debug simulator build for the `RaverMVP` scheme.
- 2026-04-09: Completed Q57 (P7.1 partial) by extending `DiscoverNewsRepository` with publish-sheet helpers (`searchDJs`, `searchEvents`, `uploadNewsCoverImage`) and migrating `DiscoverNewsPublishSheet` cover upload and binding search flows off local `AppEnvironment.makeWebService()` usage.
- 2026-04-09: Verified Q57 with a successful `xcodebuild` Debug simulator build for the `RaverMVP` scheme.
- 2026-04-09: Completed Q58 (P7.1 partial) by expanding `DiscoverEventsRepository` (check-in scoped query/update, rating/set/event deletion methods) and migrating `EventDetailView` service-heavy workflows to `DiscoverEventsRepository` + `DiscoverNewsRepository` boundaries.
- 2026-04-09: Verified Q58 with a successful `xcodebuild` Debug simulator build for the `RaverMVP` scheme.
- 2026-04-09: Completed Q59 (P7.1 partial) by expanding `DiscoverDJsRepository` (Spotify/Discogs search + import and DJ image upload methods) and migrating `DJsModuleView` module-level workflows off local `AppEnvironment.makeWebService()` usage.
- 2026-04-09: Verified Q59 with a successful `xcodebuild` Debug simulator build for the `RaverMVP` scheme.
- 2026-04-09: Completed Q60 (P7.1 partial) by expanding `DiscoverDJsRepository` (detail/follow/edit methods) and migrating `DJDetailView` detail workflows plus DJ-bound news hydration off local `AppEnvironment.makeService/makeWebService()` usage.
- 2026-04-09: Verified Q60 with a successful `xcodebuild` Debug simulator build for the `RaverMVP` scheme.
- 2026-04-09: Completed Q61 (P7.1 partial) by expanding `DiscoverSetsRepository` (set detail/comments/tracklist/detail-event query/delete methods) and migrating `SetsModuleView` + `DJSetDetailView` module/detail workflows off local direct service usage.
- 2026-04-09: Verified Q61 with a successful `xcodebuild` Debug simulator build for the `RaverMVP` scheme.
- 2026-04-09: Completed Q62 (P7.1 partial) by expanding `DiscoverSetsRepository` (create/update set, media upload, tracklist write/auto-link, video preview) and migrating Discover Sets editor/support surfaces (`DJSetEditorView`, `SetEventBindingSheet`, `UploadTracklistSheet`, `TracklistEditorView`) off local direct service usage.
- 2026-04-09: Verified Q62 with a successful `xcodebuild` Debug simulator build for the `RaverMVP` scheme.
- 2026-04-09: Completed Q63 (P7.1 partial) by expanding Discover repository boundaries for Learn workflows (`DiscoverWikiRepository` for genre/label/festival CRUD/media, `DiscoverDJsRepository` for ranking detail) and migrating `LearnModuleView`, `LearnFestivalDetailView`, and `RankingBoardDetailView` off local `AppEnvironment.makeWebService()` usage.
- 2026-04-09: Verified Q63 with a successful `xcodebuild` Debug simulator build for the `RaverMVP` scheme.
- 2026-04-09: Completed Q64 (P7.1 partial) by expanding `DiscoverNewsRepository` (festival-bound article query + contributor user search/profile methods) and migrating `LearnFestivalDetailView` related-post and contributor hydration flows off local `AppEnvironment.makeService()` usage.
- 2026-04-09: Verified Q64 with a successful `xcodebuild` Debug simulator build for the `RaverMVP` scheme.
- 2026-04-09: Completed Q65 (P7.1 closure) by expanding `DiscoverEventsRepository` (event create/update, event image upload, lineup OCR import) and migrating `EventEditorView` + `DJCheckinBindingSheet` event workflows, plus `EventLineupSupport`/`EventEditorView` DJ lookup flows, to `DiscoverEventsRepository` + `DiscoverDJsRepository` via `AppContainer` injection.
- 2026-04-09: Verified Q65 with a successful `xcodebuild` Debug simulator build for the `RaverMVP` scheme.
- 2026-04-09: Completed Q66 (P7.2 partial) by auditing social-feature service coupling in `Messages`, `Profile`, and `Circle`: local service factories are already removed, but ViewModels still depend directly on `SocialService`/`WebFeatureService`; selected `Messages` inbox/notification flows as the first social repository pilot.
- 2026-04-09: Completed Q67 (P7.2 partial) by introducing `MessagesRepository` + `MessagesRepositoryAdapter`, wiring `AppContainer.messagesRepository`, and migrating `MessagesViewModel` + `MessageNotificationsViewModel` plus `MessagesCoordinatorView`/`MainTabView` injection from direct `SocialService` to repository boundaries.
- 2026-04-09: Verified Q67 with a successful `xcodebuild` Debug simulator build for the `RaverMVP` scheme.
- 2026-04-09: Completed Q68 (P7.2 partial) by introducing `ProfileSocialRepository` + `ProfileSocialRepositoryAdapter`, wiring `AppContainer.profileSocialRepository`, and migrating `ProfileViewModel` + `FollowListViewModel` plus Profile coordinator/root injection off direct service dependencies.
- 2026-04-09: Completed Q69 (P7.2 partial) by extending `ProfileSocialRepository` with `fetchUserProfile(userID:)` and migrating `UserProfileViewModel` + `UserProfileView` construction off direct `SocialService`/`WebFeatureService` dependencies.
- 2026-04-09: Verified Q68 and Q69 with a successful `xcodebuild` Debug simulator build for the `RaverMVP` scheme.
- 2026-04-09: Completed Q70 (P7.2 partial) by extending `ProfileSocialRepository` with profile-mutation methods (`uploadMyAvatar`, `updateMyProfile`), introducing `EditProfileViewModel`, and migrating `EditProfileView` + `ProfileCoordinator` edit-profile injection to repository-backed save/upload flows.
- 2026-04-09: Verified Q70 with a successful `xcodebuild` Debug simulator build for the `RaverMVP` scheme.
- 2026-04-09: Completed Q71 (P7.2 partial) by introducing `CircleFeedRepository` + `CircleFeedRepositoryAdapter`, wiring `AppContainer.circleFeedRepository`, and migrating Circle high-traffic feed flow (`FeedViewModel` + `FeedView` injection) off direct `SocialService` construction.
- 2026-04-09: Verified Q71 with a successful `xcodebuild` Debug simulator build for the `RaverMVP` scheme.
- 2026-04-09: Completed Q72 and closed `P7.2` after social-feature smoke checks passed for `Messages`, `Profile`, and `Circle` (user-verified PASS on all checkpoints).
- 2026-04-09: Completed Q73 (P7.3 partial) by introducing `SaveProfileUseCase` and moving the multi-call profile-save workflow (`uploadMyAvatar` + `updateMyProfile`) out of `EditProfileViewModel`.
- 2026-04-09: Completed Q74 (P7.3 partial) by introducing `LoadMyProfileDashboardUseCase` and moving Profile home multi-call bootstrap workflow (`fetchMyProfile` + posts/likes/reposts/checkins) out of `ProfileViewModel.load()`.
- 2026-04-09: Verified Q73 and Q74 with a successful `xcodebuild` Debug simulator build for the `RaverMVP` scheme.
- 2026-04-09: Completed Q75 (P7.3 partial) by introducing `LoadSquadHallDataUseCase` and moving Circle squad hall multi-call loading/hydration workflow (`fetchRecommendedSquads` + `fetchMySquads` + `fetchSquadProfile`) out of `SquadHallView.loadSquads()`.
- 2026-04-09: Verified Q75 with a successful `xcodebuild` Debug simulator build for the `RaverMVP` scheme.
- 2026-04-09: Started Q76 (P7.3 closure) by finishing automated validation (successful simulator build) and defining the targeted manual smoke checklist for the three migrated social use-case pilots.
- 2026-04-09: Completed Q76 and closed `P7.3` after targeted smoke checks passed for all migrated social use-case pilots (`SaveProfileUseCase`, `LoadMyProfileDashboardUseCase`, `LoadSquadHallDataUseCase`) with user-verified PASS.
- 2026-04-09: Completed Q77 and closed `P8.1` by auditing `AppState` responsibilities/call sites, confirming truly global state to retain (`session`, `preferredLanguage`, app-wide alert, unread badge), and defining `P8.2` extraction targets for remaining `appState.service` call sites plus duplicate unread-badge write paths.
- 2026-04-09: Completed Q78 (P8.2 partial) by removing all remaining `appState.service` call sites through dependency injection (`AppContainer.socialService` / explicit `SocialService` injection) in Search, Feed compose, Circle squad hall, Squad profile, and User profile DM flows.
- 2026-04-09: Verified Q78 with a successful `xcodebuild` Debug simulator build for the `RaverMVP` scheme.
- 2026-04-09: Completed Q79 and closed `P8.2` by consolidating unread badge updates under `AppState` ownership, removing duplicate `appState.unreadMessagesCount` assignments from Messages feature surfaces (`MessagesHomeView` / `MessagesCoordinator`), and switching those paths to refresh requests.
- 2026-04-09: Verified Q79 with a successful `xcodebuild` Debug simulator build for the `RaverMVP` scheme.
- 2026-04-09: Completed Q80 (P8.3 partial) by auditing residual transitional glue and removing direct service-factory construction from `SearchView` and `NotificationsView` via `AppContainer`-injected root composition.
- 2026-04-09: Verified Q80 with a successful `xcodebuild` Debug simulator build for the `RaverMVP` scheme.
- 2026-04-09: Completed Q81 (P8.3 partial) by removing remaining feature-level fallback factory defaults in touched social surfaces (`ComposePostView`, `SquadProfileView` + `SquadManageSheet`, Search/Notifications squad-profile call sites, and residual Circle rating/picker surfaces in `MainTabView`) and tightening those paths to DI-only entry via `AppContainer` or explicit constructor injection.
- 2026-04-09: Verified Q81 with a successful `xcodebuild` Debug simulator build for the `RaverMVP` scheme (destination `iPhone 17`).
- 2026-04-09: Completed Q82 and closed `P8.3` after targeted smoke checks for touched social DI-entry paths: constructor/call-site injection integrity checks (`ComposePostView`, `SquadProfileView`), feature-level `AppEnvironment.makeService/makeWebService` scan (none), and Circle rating/picker DI chain validation in `MainTabView`.
- 2026-04-09: Verified Q82 with a successful `xcodebuild` Debug simulator build for the `RaverMVP` scheme (destination `iPhone 17`).
- 2026-04-09: Completed Q83 (hardening start) by adding migration boundary guard script `scripts/check-mvvm-coordinator-boundaries.sh` to enforce DI/coordinator architecture invariants (no feature-level service factories, no `appState.service`, and bootstrap-only `AppEnvironment` factory usage).
- 2026-04-09: Verified Q83 by running `scripts/check-mvvm-coordinator-boundaries.sh` with all checks passing.
- 2026-04-09: Completed Q84 by integrating the migration boundary guard into CI with GitHub Actions workflow `.github/workflows/mvvm-coordinator-guard.yml` and adding release manual smoke runbook `docs/IOS_RELEASE_SMOKE_RUNBOOK.md`.
- 2026-04-09: Verified Q84 by running `scripts/check-mvvm-coordinator-boundaries.sh` locally and confirming the workflow/runbook files are wired and discoverable in the migration hardening section.
- 2026-04-09: Completed Q85 by extending CI hardening with an optional simulator build lane (`workflow_dispatch` input `run_ios_build`) in `.github/workflows/mvvm-coordinator-guard.yml` and documenting branch protection recommendations in `docs/IOS_RELEASE_SMOKE_RUNBOOK.md`.
- 2026-04-09: Verified Q85 by running `scripts/check-mvvm-coordinator-boundaries.sh` and local simulator build command `xcodebuild -project mobile/ios/RaverMVP/RaverMVP.xcodeproj -scheme RaverMVP -destination 'generic/platform=iOS Simulator' build`.
- 2026-04-09: Completed Q86 by adding focused coordinator-routing regression guard script `scripts/check-coordinator-routing-regression.sh` (Route Hashable conformance + case-to-destination parity checks for Discover/Circle/Messages/Profile) and wiring it into `.github/workflows/mvvm-coordinator-guard.yml`.
- 2026-04-09: Verified Q86 by running `scripts/check-coordinator-routing-regression.sh` and `scripts/check-mvvm-coordinator-boundaries.sh` locally with all checks passing.
- 2026-04-09: Completed Q87 by adding coordinator deep-link round-trip regression guard `scripts/check-coordinator-deeplink-roundtrip.sh` for critical entry paths (`event detail`, `user profile`, `squad profile`) and wiring it into `.github/workflows/mvvm-coordinator-guard.yml`.
- 2026-04-09: Verified Q87 by running `scripts/check-coordinator-deeplink-roundtrip.sh` plus existing coordinator guard scripts locally with all checks passing.
- 2026-04-09: Completed Q88 by adding route-state snapshot fixture guard (`scripts/fixtures/coordinator-route-snapshots.sh` + `scripts/check-coordinator-route-snapshots.sh`) and wiring it into `.github/workflows/mvvm-coordinator-guard.yml`.
- 2026-04-09: Verified Q88 by running all coordinator hardening scripts locally (`check-mvvm-coordinator-boundaries`, `check-coordinator-routing-regression`, `check-coordinator-deeplink-roundtrip`, `check-coordinator-route-snapshots`) with all checks passing.
- 2026-04-09: Completed Q89 by adding contributor-focused PR preflight guidance to `docs/IOS_RELEASE_SMOKE_RUNBOOK.md` (route fixture update policy + full guard command chain for route-related changes).
- 2026-04-09: Verified Q89 by re-running all hardening guard scripts locally and confirming the runbook + migration plan references are aligned.
- 2026-04-09: Completed Q90 by adding one-command coordinator hardening preflight helper `scripts/run-coordinator-hardening-preflight.sh` and updating `docs/IOS_RELEASE_SMOKE_RUNBOOK.md` to use that command as the canonical contributor preflight entrypoint.
- 2026-04-09: Verified Q90 by running `scripts/run-coordinator-hardening-preflight.sh` locally with all underlying guard checks passing.
- 2026-04-10: Completed Q91 by adding `.github/pull_request_template.md` with a route-change reminder checklist that requires contributors to run `scripts/run-coordinator-hardening-preflight.sh` and update route snapshots when enum cases change.
- 2026-04-10: Verified Q91 by running `scripts/run-coordinator-hardening-preflight.sh` locally with all checks passing after the PR template addition.
- 2026-04-10: Completed post-Q91 structure cleanup by moving Discover cross-domain shared UI helpers into `Features/Discover/Shared/DiscoverSharedUI.swift`, and removing legacy shim/leftover files `Features/Discover/WebModulesView.swift`, `Features/Profile/WebProfileModulesView.swift`, and `Features/Discover/test.swift`.
- 2026-04-10: Verified post-Q91 structure cleanup with successful `xcodebuild -project mobile/ios/RaverMVP/RaverMVP.xcodeproj -scheme RaverMVP -destination 'generic/platform=iOS Simulator' build` and `scripts/run-coordinator-hardening-preflight.sh`.
- 2026-04-10: Added Phase 9 (`Navigation Presentation Normalization`) with push-first policy, modal allowlist, and execution queue `Q92-Q101` so long-line routing cleanup can be resumed deterministically by any new agent.
- 2026-04-10: Completed Q92 by adding `DiscoverRoute.eventCreate`, migrating `EventsModuleView` create-entry from local `sheet` to coordinator-owned `discoverPush(.eventCreate)`, and wiring a save-notification refresh signal (`Notification.Name.discoverEventDidSave`) so the events list reload behavior remains intact after returning.
- 2026-04-10: Completed Q93 by adding `DiscoverRoute.eventEdit(event:)`, migrating `EventDetailView` edit-entry from local `sheet` to coordinator-owned push (`discoverPush(.eventEdit(event:))`), and adding event-save notification handling so detail content reloads after edit-save return.
- 2026-04-10: Completed Q94 by adding `DiscoverRoute.newsPublish`, migrating `NewsModuleView` publish-entry from local `sheet` to coordinator-owned push (`discoverPush(.newsPublish)`), and wiring publish-complete list refresh through `Notification.Name.discoverNewsDidPublish`.
- 2026-04-10: Completed Q95 by adding `DiscoverRoute.setCreate` and `DiscoverRoute.setEdit(set:)`, migrating `SetsModuleView` create-entry and `DJSetDetailView` edit-entry from local `sheet` to coordinator-owned push routes, and wiring set-save refresh through `Notification.Name.discoverSetDidSave` (tracklist selector/upload/editor sheets remain modal per allowlist).
- 2026-04-10: Completed Q96 by adding `DiscoverRoute.learnFestivalCreate` and `DiscoverRoute.learnFestivalEdit(festival:)`, migrating Learn festival create/edit entries to coordinator-owned push routes, and wiring festival-save refresh through `Notification.Name.discoverFestivalDidSave`.
- 2026-04-10: Verified Q96 with successful simulator build command `xcodebuild -project mobile/ios/RaverMVP/RaverMVP.xcodeproj -scheme RaverMVP -destination 'generic/platform=iOS Simulator' build`.
- 2026-04-10: Completed Q97 by adding `CircleRoute.postCreate` and `CircleRoute.postEdit(Post)` in `CircleCoordinator`, migrating `FeedView` compose/edit entries from local `sheet` to coordinator-owned push routes, and wiring post create/update/delete refresh signals via `Notification.Name.circlePostDidCreate/.circlePostDidUpdate/.circlePostDidDelete`.
- 2026-04-10: Verified Q97 with successful simulator build command `xcodebuild -project mobile/ios/RaverMVP/RaverMVP.xcodeproj -scheme RaverMVP -destination 'generic/platform=iOS Simulator' build`.
- 2026-04-10: Completed Q98 by adding Circle long-form creation routes (`CircleRoute.idCreate`, `ratingEventCreate`, `ratingEventImportFromEvent`, `ratingUnitCreate(eventID:)`) in `CircleCoordinator`, migrating `MainTabView` ID publish + rating create/create-from-event/create-unit flows from local `sheet` to coordinator-owned push routes, and wiring result notifications (`circleIDDidCreate`, `circleRatingEventDidCreate`, `circleRatingUnitDidCreate`) for local list/detail refresh.
- 2026-04-10: Verified Q98 with successful simulator build command `xcodebuild -project mobile/ios/RaverMVP/RaverMVP.xcodeproj -scheme RaverMVP -destination 'generic/platform=iOS Simulator' build`.
- 2026-04-10: Completed Q99 by evaluating `SquadProfileView` manage flow and deciding to keep `SquadManageSheet` modal (no push migration), because it is an in-context management panel rather than a cross-feature navigation flow; documented this decision under `P9.2 decision note`.
- 2026-04-10: Completed Q100 by unifying `SearchView` and `NotificationsView` entity hops (`user`, `squad`, `post`) onto coordinator-owned `profilePush` routes, removing their local `NavigationStack`/modal detail presentation paths, and extending `ProfileRoute` with `squadProfile(String)` to keep squad profile navigation inside coordinator ownership.
- 2026-04-10: Verified Q100 with successful simulator build command `xcodebuild -project mobile/ios/RaverMVP/RaverMVP.xcodeproj -scheme RaverMVP -destination 'generic/platform=iOS Simulator' build`.
- 2026-04-10: Completed Q101 by freezing the modal allowlist in `scripts/modal-allowlist-signatures.txt`, adding `scripts/check-modal-allowlist.sh`, integrating it into CI (`.github/workflows/mvvm-coordinator-guard.yml`) and preflight (`scripts/run-coordinator-hardening-preflight.sh`), and documenting per-screen allowlist rationale under `P9.4`.
- 2026-04-10: Verified Q101 by running `scripts/check-modal-allowlist.sh` and `scripts/run-coordinator-hardening-preflight.sh` locally with all checks passing.
- 2026-04-10: Completed Q102 by adding `DiscoverRoute.newsDetail(article:)` and migrating `NewsSearchResultsView` from local `fullScreenCover` article detail presentation to coordinator-owned push routing (`discoverPush(.newsDetail(article:))`) in `DiscoverSearchViews.swift`.
- 2026-04-10: Verified Q102 with successful `scripts/run-coordinator-hardening-preflight.sh` and simulator build command `xcodebuild -project mobile/ios/RaverMVP/RaverMVP.xcodeproj -scheme RaverMVP -destination 'generic/platform=iOS Simulator' build`.
- 2026-04-10: Completed Q103 by adding `DiscoverRoute.djDetail(djID:)` and migrating `DJsSearchResultsView` from local `fullScreenCover` DJ detail presentation to coordinator-owned push routing (`discoverPush(.djDetail(djID:))`) in `DiscoverSearchViews.swift`.
- 2026-04-10: Verified Q103 with successful `scripts/run-coordinator-hardening-preflight.sh` and simulator build command `xcodebuild -project mobile/ios/RaverMVP/RaverMVP.xcodeproj -scheme RaverMVP -destination 'generic/platform=iOS Simulator' build`.
- 2026-04-10: Completed Q104 by adding `DiscoverRoute.setDetail(setID:)` and migrating `SetsSearchResultsView` from local `fullScreenCover` set playback opening to coordinator-owned push routing (`discoverPush(.setDetail(setID:))`) in `DiscoverSearchViews.swift`.
- 2026-04-10: Verified Q104 with successful `scripts/run-coordinator-hardening-preflight.sh` and simulator build command `xcodebuild -project mobile/ios/RaverMVP/RaverMVP.xcodeproj -scheme RaverMVP -destination 'generic/platform=iOS Simulator' build`.
- 2026-04-10: Completed Q105 by adding `DiscoverRoute.labelDetail(label:)` and `DiscoverRoute.festivalDetail(festival:)`, then migrating `WikiSearchResultsView` label/festival openings from local `fullScreenCover` to coordinator-owned push routing (`discoverPush(.labelDetail)` / `.festivalDetail`) in `DiscoverSearchViews.swift`.
- 2026-04-10: Verified Q105 with successful `scripts/run-coordinator-hardening-preflight.sh` and simulator build command `xcodebuild -project mobile/ios/RaverMVP/RaverMVP.xcodeproj -scheme RaverMVP -destination 'generic/platform=iOS Simulator' build`.
- 2026-04-10: Completed Q106 by migrating `DiscoverNewsDetailView` related DJ/Festival openings from local `fullScreenCover` state to coordinator-owned push routing (`discoverPush(.djDetail)` / `.festivalDetail`), removing local modal-selection state in `DiscoverNewsDetailView.swift`.
- 2026-04-10: Verified Q106 with successful `scripts/run-coordinator-hardening-preflight.sh` and simulator build command `xcodebuild -project mobile/ios/RaverMVP/RaverMVP.xcodeproj -scheme RaverMVP -destination 'generic/platform=iOS Simulator' build`.
- 2026-04-10: Completed Q107 by migrating `NewsModuleView` article-detail opening from local `fullScreenCover` to coordinator-owned push routing (`discoverPush(.newsDetail(article:))`) and removing local `selectedArticleForDetail` state in `NewsModuleView.swift`.
- 2026-04-10: Verified Q107 with successful `scripts/run-coordinator-hardening-preflight.sh` and simulator build command `xcodebuild -project mobile/ios/RaverMVP/RaverMVP.xcodeproj -scheme RaverMVP -destination 'generic/platform=iOS Simulator' build`.
- 2026-04-10: Completed Q108 by migrating `DJsModuleView` hot-list DJ opening from local `fullScreenCover` to coordinator-owned push routing (`discoverPush(.djDetail(djID:))`) and removing local `selectedDJForDetail` state in `DJsModuleView.swift`.
- 2026-04-10: Verified Q108 with successful `scripts/run-coordinator-hardening-preflight.sh` and simulator build command `xcodebuild -project mobile/ios/RaverMVP/RaverMVP.xcodeproj -scheme RaverMVP -destination 'generic/platform=iOS Simulator' build`.
- 2026-04-10: Completed Q109 by migrating `DJDetailView` related-news opening from local `fullScreenCover` to coordinator-owned push routing (`discoverPush(.newsDetail(article:))`) in `DJsModuleView.swift` and removing local `selectedArticleForDetail` modal state.
- 2026-04-10: Verified Q109 with successful `scripts/run-coordinator-hardening-preflight.sh` and simulator build command `xcodebuild -project mobile/ios/RaverMVP/RaverMVP.xcodeproj -scheme RaverMVP -destination 'generic/platform=iOS Simulator' build`.
- 2026-04-10: Completed Q110 by migrating Learn-domain detail hops from local modal state to coordinator-owned push routing in `LearnModuleView.swift` (`LearnModuleView` label/festival, `LearnLabelDetailView` founder DJ, `LearnFestivalDetailView` related news, `RankingBoardDetailView` DJ/festival); retained image preview and ranking-context overlays as intentional modal surfaces.
- 2026-04-10: Verified Q110 by refreshing `scripts/modal-allowlist-signatures.txt` via `scripts/check-modal-allowlist.sh --write-allowlist`, then running `scripts/run-coordinator-hardening-preflight.sh` and simulator build command `xcodebuild -project mobile/ios/RaverMVP/RaverMVP.xcodeproj -scheme RaverMVP -destination 'generic/platform=iOS Simulator' build` successfully.
- 2026-04-10: Completed Q111 by migrating `EventDetailView` related-news opening from local `fullScreenCover` state to coordinator-owned push routing (`discoverPush(.newsDetail(article:))`), while keeping rating detail and route planner overlays modal per allowlist.
- 2026-04-10: Verified Q111 by refreshing `scripts/modal-allowlist-signatures.txt` via `scripts/check-modal-allowlist.sh --write-allowlist`, then running `scripts/run-coordinator-hardening-preflight.sh` and simulator build command `xcodebuild -project mobile/ios/RaverMVP/RaverMVP.xcodeproj -scheme RaverMVP -destination 'generic/platform=iOS Simulator' build` successfully.
- 2026-04-10: Completed Q112 by evaluating `LearnFestivalRankingDetailView` drill-down behavior and intentionally keeping its local modal transition (`fullScreenCover`) to preserve ranking-context return semantics; documented this under `P9.1 decision note` and updated the immediate queue to `Q113`.
- 2026-04-10: Completed Q113 by migrating `SetsModuleView` normal set-detail opening from local `fullScreenCover(item: $selectedSetForPlayback)` to coordinator-owned push routing (`discoverPush(.setDetail(setID:))`), while keeping `audioListenSetID` full-screen presentation as an intentional immersive modal playback surface.
- 2026-04-10: Verified Q113 by refreshing `scripts/modal-allowlist-signatures.txt` via `scripts/check-modal-allowlist.sh --write-allowlist`, then running `scripts/run-coordinator-hardening-preflight.sh` and simulator build command `xcodebuild -project mobile/ios/RaverMVP/RaverMVP.xcodeproj -scheme RaverMVP -destination 'generic/platform=iOS Simulator' build` successfully.
- 2026-04-10: Completed Q114 by evaluating `EventDetailView` rating detail + route planner overlays and intentionally keeping both modal (`fullScreenCover`) as immersive in-context subflows; documented explicit rationale under `P9.1 decision note` and moved queue forward to `Q115`.
- 2026-04-10: Completed Q115 by consolidating Discover residual modal rationale under `P9.4` and auditing all Discover `fullScreenCover` call sites; confirmed no additional Discover detail-hop modal remains outside coordinator push or explicit allowlist.
- 2026-04-10: Verified Q115 with a successful `scripts/run-coordinator-hardening-preflight.sh` pass after the Discover modal audit note update.
- 2026-04-10: Completed Q116 by evaluating `MainTabView` `selectedDetailRoute` (`CircleIDDetailView`) and intentionally keeping its full-screen modal presentation because the flow relies on binding-backed hub-local state mutation (`@Binding entry`) and dismiss-then-push handoff (`pendingRouteAfterDismiss`); documented rationale in `P9.4` and moved queue forward to `Q117`.
- 2026-04-10: Completed Q117 by evaluating `MessagesModalRoute.squadProfile` and intentionally keeping full-screen modal presentation in `MessagesCoordinator`, because message-context squad inspection should return directly to the same conversation/alert stack without additional push-stack rewiring.
- 2026-04-10: Completed Q118 by re-evaluating `SquadManageSheet` in `SquadProfileView` and confirming keep-modal policy remains correct: it is an in-context management panel with reload-on-dismiss coupling and does not represent a cross-feature entity navigation flow.
- 2026-04-10: Completed Q119 by evaluating `ComposePostView` media and location preview full-screen routes and intentionally keeping them modal, because both are compose-context immersive/utility subflows and do not represent cross-feature entity navigation.
- 2026-04-10: Completed Q120 by evaluating `Shared/PostCardView` media and location full-screen routes (`selectedMedia`, `isShowingLocationMap`) and intentionally keeping them modal, because they are post-context immersive preview flows rather than coordinator-owned entity navigation.
- 2026-04-10: Completed Q121 by evaluating `MainTabView` utility sheets (`showEventPicker`, `showDJPicker`, `showCreateSquad`) and confirming keep-modal policy remains valid because they are short-lived input/creation tools; marked post-Phase-9 cleanup wave (`Q102`–`Q121`) as closed with allowlist-backed rationale.
- 2026-04-10: Completed Q122 by re-opening post-wave cleanup and converting previously deferred modal routes to push: `MessagesCoordinator` squad profile route, `MainTabView` (`selectedDetailRoute`, event picker, DJ picker, create squad), `SquadProfileView` manage panel, `EventDetailView` rating detail + route planner, `DJsModuleView` import/edit/spotify routes, `SetsModuleView` tracklist/editor/event-binding routes, `LearnModuleView` ranking/image/full-screen detail routes, and `EventEditorView` lineup/location routes.
- 2026-04-10: Q122 follow-up guard update: refreshed `scripts/modal-allowlist-signatures.txt` via `scripts/check-modal-allowlist.sh --write-allowlist` after modal-count reduction.
- 2026-04-10: Q122 verification: simulator build passed (`xcodebuild -project mobile/ios/RaverMVP/RaverMVP.xcodeproj -scheme RaverMVP -destination 'generic/platform=iOS Simulator' build`) and modal allowlist check passed (`scripts/check-modal-allowlist.sh`).
- 2026-04-10: Added `docs/IOS_INCREMENTAL_FEATURE_DEVELOPMENT_GUIDE.md` as the default playbook for all future incremental feature delivery under MVVM+Coordinator, and linked it from this plan via `Companion Development Guide`.
