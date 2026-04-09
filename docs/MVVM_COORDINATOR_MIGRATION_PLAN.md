# Raver iOS MVVM + Coordinator Migration Plan

Last Updated: 2026-04-09
Owner: Codex + project maintainers
Status: Active

## Purpose

This document is the single source of truth for migrating the iOS app from its current mixed architecture into a consistent `MVVM + Coordinator` architecture.

From this point on:

- All migration work should follow this document.
- Completed items must be marked as completed in this file.
- New findings, scope changes, and architectural decisions must be appended here instead of living only in chat history.
- A new agent should be able to continue the work by reading only this file plus the codebase.

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
      Domain/
      ViewModels/
      Views/
      Components/
    Circle/
      Coordinator/
      Domain/
      ViewModels/
      Views/
      Components/
    Messages/
      Coordinator/
      Domain/
      ViewModels/
      Views/
      Components/
    Profile/
      Coordinator/
      Domain/
      ViewModels/
      Views/
      Components/
```

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

- [ ] P3.1 Convert Discover search flows to ViewModel-driven screens.
- [ ] P3.2 Continue normalizing `EventsModuleView` under coordinator-driven composition.
- [ ] P3.3 Move direct service creation out of touched Discover views.
- [ ] P3.4 Define a repeatable Discover screen template for future migrations.

### Phase 4: Discover File Decomposition

Goal:

- Break `WebModulesView.swift` into feature-scoped files without changing user-facing behavior.

Deliverables:

- `EventsModule`, `NewsModule`, `DJsModule`, `SetsModule`, and `LearnModule` moved into separate files and folders.

Exit criteria:

- `WebModulesView.swift` no longer acts as a multi-feature dumping ground.
- Discover feature ownership is clearer for future work.

Status:

- [ ] P4.1 Extract Events feature files.
- [ ] P4.2 Extract News feature files.
- [ ] P4.3 Extract DJs feature files.
- [ ] P4.4 Extract Sets feature files.
- [ ] P4.5 Extract Learn feature files.

### Phase 5: Messages and Profile Migration

Goal:

- Apply the same Coordinator and MVVM rules to Messages and Profile.

Exit criteria:

- Messages and Profile route state is coordinator-owned.
- Touched screens no longer create services directly inside views.

Status:

- [ ] P5.1 Add `MessagesCoordinator`.
- [ ] P5.2 Add `ProfileCoordinator`.
- [ ] P5.3 Normalize Messages views and ViewModels.
- [ ] P5.4 Normalize Profile views and ViewModels.

### Phase 6: Circle Migration

Goal:

- Migrate Circle into `MVVM + Coordinator` after patterns are validated in Discover, Messages, and Profile.

Exit criteria:

- Circle routes are coordinator-owned.
- Large nested flows are decomposed into explicit subflows.

Status:

- [ ] P6.1 Add `CircleCoordinator`.
- [ ] P6.2 Migrate Circle root navigation.
- [ ] P6.3 Migrate nested Circle flows incrementally.

### Phase 7: Domain Layer Consolidation

Goal:

- Introduce repositories and use cases where service calls are still too close to screen logic.

Exit criteria:

- Core feature workflows are not tightly coupled to service APIs.
- Mocking and testing become easier at ViewModel boundaries.

Status:

- [ ] P7.1 Define repository boundaries for Discover.
- [ ] P7.2 Define repository boundaries for social features.
- [ ] P7.3 Introduce use cases where workflows span multiple service calls.

### Phase 8: AppState Reduction and Cleanup

Goal:

- Limit `AppState` to global concerns only.

Exit criteria:

- Feature-owned state is not stored globally.
- App-wide state is clearly separated from feature state.

Status:

- [ ] P8.1 Audit `AppState` responsibilities.
- [ ] P8.2 Move feature-owned state out of `AppState`.
- [ ] P8.3 Final cleanup of transitional architecture glue.

## Immediate Work Queue

These are the exact next items to execute unless priorities change.

- [x] Q1 Create `AppContainer`.
- [x] Q2 Create `AppCoordinator`.
- [x] Q3 Create `MainTabCoordinator`.
- [x] Q4 Update `RaverMVPApp.swift` to boot through coordinator.
- [x] Q5 Create `DiscoverCoordinator`.
- [x] Q6 Move Discover route ownership from `DiscoverHomeView` to coordinator.
- [x] Q7 Convert Discover event and news search results to coordinator-injected ViewModel screens.
- [ ] Q8 Convert remaining Discover search results screens (`DJs`, `Sets`, `Wiki`) to ViewModel-driven screens.
- [ ] Q9 Normalize `EventsModuleView` into coordinator-composed MVVM structure.
- [ ] Q10 Document and reuse a repeatable Discover screen migration template.

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
