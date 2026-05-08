# iOS Global Aggregated Search Development Log

This log tracks implementation progress, decisions, verification, and scope control for the iOS global aggregated search feature.

Core route:

1. Global search button in bottom tab bar.
2. Login-only search overlay.
3. Search result page with All and domain tabs.
4. Unified search API and iOS integration.
5. QA, analytics, and polish.

Do not add new product scope during implementation unless the PRD is updated first.

## Progress Checklist

### Phase 1: iOS Entry and Overlay

- [x] Search action button added between Circle and Messages.
- [x] Login guard added.
- [x] Blur overlay implemented.
- [x] Search input implemented.
- [x] Recent searches implemented.
- [x] Searchable scope hints implemented.
- [x] Submit routes to result page.
- [x] Phase 1 closeout recorded.

### Phase 2: iOS Result Page

- [x] Result route added.
- [x] Result page shell implemented.
- [ ] All tab implemented.
- [ ] Domain tabs implemented.
- [ ] Result cards implemented.
- [ ] Navigation mapping implemented.
- [ ] Mock data renders all domains.
- [ ] Phase 2 closeout recorded.

### Phase 3: Backend Unified Search

- [ ] `/v1/search` route added.
- [ ] Global search service added.
- [ ] Events search implemented.
- [ ] News search implemented.
- [ ] DJs search implemented.
- [ ] Sets search implemented.
- [ ] Rankings search implemented.
- [ ] Ratings search implemented.
- [ ] Posts search implemented.
- [ ] Wiki search implemented.
- [ ] Users and squads search implemented.
- [ ] Relevance scoring implemented.
- [ ] Partial failure handling implemented.
- [ ] Phase 3 closeout recorded.

### Phase 4: iOS API Integration

- [ ] `WebFeatureService` extended.
- [ ] `LiveWebFeatureService` implemented.
- [ ] `MockWebFeatureService` implemented.
- [ ] View model wired to API.
- [ ] Per-tab retry implemented.
- [ ] Pull-to-refresh implemented.
- [ ] 401 behavior verified.
- [ ] Phase 4 closeout recorded.

### Phase 5: Quality and Polish

- [ ] Analytics added.
- [ ] Performance logging added.
- [ ] Accessibility labels added.
- [ ] Localization checked.
- [ ] Empty/error states polished.
- [ ] Dark/light mode checked.
- [ ] Small/large viewport checked.
- [ ] Final QA completed.
- [ ] Phase 5 closeout recorded.

## Guardrails

- [x] Search remains login-only.
- [x] Chat message history remains excluded.
- [x] Comments remain excluded.
- [x] Users and squads remain grouped in one result tab.
- [x] All tab remains the primary aggregated result surface.
- [x] No real-time suggestions in V1.
- [x] No hot search backend in V1.
- [x] Scope changes are recorded before implementation.

## Log Entries

### 2026-05-08 - Planning - Documentation Setup

What changed:

- Created the PRD and technical breakdown in `docs/IOS_GLOBAL_AGGREGATED_SEARCH_PRD.md`.
- Added this development log for progress tracking and scope control.

Files touched:

- `docs/IOS_GLOBAL_AGGREGATED_SEARCH_PRD.md`
- `docs/IOS_GLOBAL_AGGREGATED_SEARCH_DEV_LOG.md`

Decisions:

- Development will be tracked with phase-level and task-level checkboxes.
- New ideas that are not required for V1 should be parked instead of implemented immediately.
- Each phase needs a closeout note before the next phase expands scope.

Verification:

- Documentation-only change.

Scope risks:

- Aggregated search touches many domains, so drift risk is high. Keep implementation anchored to the PRD acceptance criteria.

### 2026-05-08 - Phase 1 - iOS Entry and Overlay

What changed:

- Added the purple circular global search action between Circle and Messages in the bottom tab bar.
- Added login guard messaging before opening global search.
- Added a blurred search overlay with focused input, dismiss handling, recent search chips, clear history, and searchable scope hints.
- Added local recent-search persistence through `UserDefaults` with trim and case-insensitive dedupe.
- Added the app-level `globalSearchResults` route and a placeholder result page with the planned tabs.
- Updated `project.yml` so XcodeGen preserves existing photo-library usage descriptions and Tencent APNS business id.

Files touched:

- `mobile/ios/RaverMVP/RaverMVP/Features/MainTabView.swift`
- `mobile/ios/RaverMVP/RaverMVP/Application/Coordinator/MainTabCoordinator.swift`
- `mobile/ios/RaverMVP/RaverMVP/Features/Search/Models/GlobalSearchModels.swift`
- `mobile/ios/RaverMVP/RaverMVP/Features/Search/Storage/RecentSearchStore.swift`
- `mobile/ios/RaverMVP/RaverMVP/Features/Search/Views/GlobalSearchOverlayView.swift`
- `mobile/ios/RaverMVP/RaverMVP/Features/Search/Views/GlobalSearchResultsPlaceholderView.swift`
- `mobile/ios/RaverMVP/project.yml`
- `mobile/ios/RaverMVP/RaverMVP.xcodeproj/project.pbxproj`
- `docs/IOS_GLOBAL_AGGREGATED_SEARCH_PRD.md`
- `docs/IOS_GLOBAL_AGGREGATED_SEARCH_DEV_LOG.md`

Decisions:

- The search entry is an action button, not a fifth tab.
- The result route lives in `AppRoute` because the feature crosses Discover, Circle, Messages-adjacent people/squads, and profile-adjacent user content.
- Phase 1 stops at a routeable placeholder page. Real result cards, API integration, backend search, analytics, and ranking tuning remain out of scope.

Verification:

- Ran `xcodegen generate`; project and Pods integration completed.
- Ran `xcodebuild -workspace RaverMVP.xcworkspace -scheme RaverMVP -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17' build`; build succeeded.

Scope risks:

- The placeholder result page can make the feature feel more complete than it is. Before Phase 2 starts, keep work limited to result UI shell and mock rendering, not backend/API changes.

### 2026-05-08 - UI Adjustment - Entry, Overlay, and Result Tabs

What changed:

- Centered the global search button vertically inside the bottom tab bar so the icon-only action no longer floats outside the tab bar area.
- Changed the search overlay from a bottom sheet to a centered modal panel over the blurred current screen.
- Reworked the placeholder search results page to use the existing `RaverScrollableTabPager` style used by Discover and Circle.
- Made the result-page search field editable so users can change the keyword and submit again from the results page.

Files touched:

- `mobile/ios/RaverMVP/RaverMVP/Features/MainTabView.swift`
- `mobile/ios/RaverMVP/RaverMVP/Features/Search/Views/GlobalSearchOverlayView.swift`
- `mobile/ios/RaverMVP/RaverMVP/Features/Search/Views/GlobalSearchResultsPlaceholderView.swift`
- `docs/IOS_GLOBAL_AGGREGATED_SEARCH_DEV_LOG.md`

Decisions:

- Result-page tab switching should reuse the shared scrollable tab component instead of inventing a separate segmented style.
- Re-search on the placeholder page updates the local submitted query only. Real API refresh remains a Phase 4 integration task.

Verification:

- Ran `xcodebuild -workspace RaverMVP.xcworkspace -scheme RaverMVP -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17' build`; build succeeded.

Scope risks:

- The editable result search box is currently UI/state only. Do not wire network behavior until the API integration phase.

## Phase Closeouts

### Phase 1 Closeout

Status: Implementation complete, pending product visual acceptance.

Notes:

- Completed the tab bar action, login guard, blur overlay, recent searches, scope hints, and placeholder results navigation.
- No backend search logic, real-time suggestions, hot search, chat search, or comment search was added.
- Build verification passed on the iPhone 17 simulator destination.
- Manual visual acceptance on a logged-in simulator session is still recommended before expanding into Phase 2.

### Phase 2 Closeout

Status: Not started.

Notes:

- TBD.

### Phase 3 Closeout

Status: Not started.

Notes:

- TBD.

### Phase 4 Closeout

Status: Not started.

Notes:

- TBD.

### Phase 5 Closeout

Status: Not started.

Notes:

- TBD.

## Future / Parking Lot

- Hot search backend.
- Real-time suggestions.
- Search history sync across devices.
- Personalized ranking experiments.
- Highlight matched ranking entries inside ranking detail.
- Event lineup text indexing if not included in V1.
