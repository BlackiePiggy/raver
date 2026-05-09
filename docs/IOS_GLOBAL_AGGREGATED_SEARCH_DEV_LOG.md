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
- [x] All tab implemented.
- [x] Domain tabs implemented.
- [x] Result cards implemented.
- [x] Navigation mapping implemented.
- [x] Mock data renders all domains.
- [x] Phase 2 closeout recorded.

### Phase 3: Backend Unified Search

- [x] `/v1/search` route added.
- [x] Global search service added.
- [x] Events search implemented.
- [x] News search implemented.
- [x] DJs search implemented.
- [x] Sets search implemented.
- [x] Rankings search implemented.
- [x] Ratings search implemented.
- [x] Posts search implemented.
- [x] Wiki search implemented.
- [x] Users and squads search implemented.
- [x] Relevance scoring implemented.
- [x] Partial failure handling implemented.
- [x] Phase 3 closeout recorded.

### Phase 4: iOS API Integration

- [x] `WebFeatureService` extended.
- [x] `LiveWebFeatureService` implemented.
- [x] `MockWebFeatureService` implemented.
- [x] View model wired to API.
- [x] Per-tab retry implemented.
- [x] Pull-to-refresh implemented.
- [x] Route-level logged-out fallback implemented.
- [x] Phase 4 closeout recorded.

### Phase 5: Quality and Polish

- [x] Debug telemetry added.
- [x] Performance logging added.
- [x] Accessibility labels added.
- [x] Localization code strings checked.
- [x] Empty/error states polished.
- [x] Legacy Discover content search entry points removed.
- [x] Legacy Discover search route and screens removed.
- [x] Legacy generic Search screen removed.
- [x] Legacy global chat search sheet removed.
- [ ] Dark/light mode checked.
- [ ] Small/large viewport checked.
- [ ] Logged-out/deep-link manual QA completed.
- [ ] Final QA completed.
- [x] Phase 5 code-polish closeout recorded.

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

### 2026-05-08 - Phase 2 - iOS Result Page

What changed:

- Promoted the placeholder result page into `GlobalSearchResultsView` while keeping a compatibility typealias for the existing route.
- Added normalized `GlobalSearchItem` and `GlobalSearchItemType` models.
- Added `GlobalSearchResultsViewModel` with mock search data, per-tab phases, refresh/retry hooks, counts, top matches, domain previews, and partial failure metadata.
- Added compact result cards with domain badges, thumbnails/fallback icons, title, subtitle, summary, and route opening behavior.
- Implemented the All tab with summary strip, top matches, domain preview sections, View All tab switching, empty state, and compact partial failure rows.
- Implemented domain tabs for all planned tabs with result lists, count badges, pull-to-refresh, empty, loading, and error state surfaces.

Files touched:

- `mobile/ios/RaverMVP/RaverMVP/Features/Search/Models/GlobalSearchModels.swift`
- `mobile/ios/RaverMVP/RaverMVP/Features/Search/ViewModels/GlobalSearchResultsViewModel.swift`
- `mobile/ios/RaverMVP/RaverMVP/Features/Search/Views/GlobalSearchResultCards.swift`
- `mobile/ios/RaverMVP/RaverMVP/Features/Search/Views/GlobalSearchResultsPlaceholderView.swift`
- `mobile/ios/RaverMVP/RaverMVP.xcodeproj/project.pbxproj`
- `docs/IOS_GLOBAL_AGGREGATED_SEARCH_PRD.md`
- `docs/IOS_GLOBAL_AGGREGATED_SEARCH_DEV_LOG.md`

Decisions:

- Mock data remains local to the iOS result view model for Phase 2. Backend search and live service contracts remain Phase 3/4 work.
- Ranking behavior is relevance-score rendering only; no real ranking algorithm tuning was introduced.
- Ranking entry mock taps open the parent ranking board detail because there is no separate ranking-entry route in the current app route map.

Verification:

- Ran `xcodegen generate`; project and Pods integration completed.
- Ran `xcodebuild -workspace RaverMVP.xcworkspace -scheme RaverMVP -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17' build`; build succeeded.

Scope risks:

- Result taps are wired to existing route types, but mock entity IDs may not resolve to real records until backend data is connected.
- The partial failure banner is mocked to exercise UI behavior. Real partial failure semantics belong to the backend/API phases.

### 2026-05-08 - Phase 3 - Backend Unified Search

What changed:

- Added a standalone authenticated `/v1/search` route mounted from `server/src/index.ts`.
- Added `global-search.service.ts` with domain fan-out, normalized result items, relevance-first sorting, counts by tab, and `Promise.allSettled` partial failure handling.
- Implemented search for events, news, DJs, sets, rankings, ratings, Circle posts, wiki labels/festivals, users, and public squads.
- Kept news search scoped to Raver news posts identified by `#RAVER_NEWS`.
- Kept Circle post search on `Post.content` and post metadata only; `PostComment` is not queried.
- Kept ratings search on `RatingEvent` and `RatingUnit` only; `RatingComment` content is not queried.
- Kept rankings as a read-only search over existing ranking manifest/files instead of adding a database model.

Files touched:

- `server/src/services/global-search.service.ts`
- `server/src/routes/search.routes.ts`
- `server/src/index.ts`
- `docs/IOS_GLOBAL_AGGREGATED_SEARCH_PRD.md`
- `docs/IOS_GLOBAL_AGGREGATED_SEARCH_DEV_LOG.md`

Decisions:

- `/v1/search` returns `{ data: { query, tab, limit, totalCount, items, countsByTab, partialErrors, generatedAt } }` to match existing BFF envelope style.
- Phase 3 returns normalized items for both All and domain tabs. Full pagination and typed domain payloads are deferred until result volume makes them necessary.
- The route requires `Authorization: Bearer <token>` through the existing `authenticate` middleware.
- Search scoring is intentionally simple and replaceable: exact/prefix/contains text scoring with small verified, popularity, and recency boosts.
- No migrations, no new search engine, no chat search, no comment search, no hot search, and no real-time suggestions were added.

Verification:

- Ran `npm run build` in `server`; TypeScript build succeeded.

Scope risks:

- Current text search uses Prisma `contains` queries and existing array exact-match filters. This is enough for V1 but should be revisited with indexes or a search engine before large-scale rollout.
- Single-domain result pagination is not implemented yet; Phase 4 should consume `limit` and tab filtering first, then add pagination only if real data volume requires it.

### 2026-05-08 - Phase 4 - iOS API Integration

What changed:

- Added `GlobalSearchResponse` and `GlobalSearchPartialError` models matching the `/v1/search` envelope.
- Extended `WebFeatureService` with `searchGlobal(query:tab:limit:)`.
- Implemented live `/v1/search` request in `LiveWebFeatureService`.
- Implemented the same contract in `MockWebFeatureService` using the existing mock global-search result set.
- Injected `appContainer.webService` into `GlobalSearchResultsView` from `MainTabCoordinator`.
- Reworked `GlobalSearchResultsViewModel` so initial load, re-search, tab retry, and pull-to-refresh call the service instead of local mock data.
- Removed the stale Phase 2 placeholder hint from the result-page header.

Files touched:

- `mobile/ios/RaverMVP/RaverMVP/Features/Search/Models/GlobalSearchModels.swift`
- `mobile/ios/RaverMVP/RaverMVP/Core/WebFeatureService.swift`
- `mobile/ios/RaverMVP/RaverMVP/Core/LiveWebFeatureService.swift`
- `mobile/ios/RaverMVP/RaverMVP/Core/MockWebFeatureService.swift`
- `mobile/ios/RaverMVP/RaverMVP/Features/Search/ViewModels/GlobalSearchResultsViewModel.swift`
- `mobile/ios/RaverMVP/RaverMVP/Features/Search/Views/GlobalSearchResultsPlaceholderView.swift`
- `mobile/ios/RaverMVP/RaverMVP/Application/Coordinator/MainTabCoordinator.swift`
- `docs/IOS_GLOBAL_AGGREGATED_SEARCH_DEV_LOG.md`

Decisions:

- Phase 4 uses normalized backend items directly for all tabs; no typed domain payload conversion was added.
- Per-tab retry and pull-to-refresh call `/v1/search` with the selected tab and replace that tab's items inside the current aggregate list.
- 401 handling uses the existing `LiveWebFeatureService` error path. The global search entry is already login-gated, so route-level unauthenticated access surfaces as a normal error state. Manual logged-out/deep-link verification is still pending.
- Pagination remains parked. The result page uses `limit=60` and tab-level refresh for V1.

Verification:

- Ran `xcodebuild -workspace RaverMVP.xcworkspace -scheme RaverMVP -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17' build`; build succeeded.

Scope risks:

- A direct deep link to a search result page while logged out will render the API error state rather than automatically opening login. A product polish pass can decide whether to redirect.
- Since pagination is parked, large domains may need follow-up work once real data volume is reviewed.

### 2026-05-08 - Phase 5 - Quality and Polish

What changed:

- Added lightweight global-search telemetry through `IMProbeLogger`.
- Logged overlay open, search submit, load start, load success, load failure, result open, and load duration.
- Kept telemetry privacy-conscious by logging query length instead of raw search text.
- Added accessibility identifiers, labels, and hints for the tab-bar search action, overlay controls, result-page search controls, result cards, loading state, summary state, empty state, error retry, and partial failure rows.
- Polished result empty/error/loading surfaces with explicit labels and retry affordances.
- Added a route-level logged-out fallback so direct navigation to global search results does not call the search API when the user is unauthenticated.
- Fixed per-tab refresh state so refreshing one result tab does not reset counts for unrelated tabs.
- Checked global-search UI strings use the existing `L(...)` bilingual string pattern.

Files touched:

- `mobile/ios/RaverMVP/RaverMVP/Features/MainTabView.swift`
- `mobile/ios/RaverMVP/RaverMVP/Features/Search/Telemetry/GlobalSearchTelemetry.swift`
- `mobile/ios/RaverMVP/RaverMVP/Features/Search/ViewModels/GlobalSearchResultsViewModel.swift`
- `mobile/ios/RaverMVP/RaverMVP/Application/Coordinator/MainTabCoordinator.swift`
- `mobile/ios/RaverMVP/RaverMVP/Features/Search/Views/GlobalSearchOverlayView.swift`
- `mobile/ios/RaverMVP/RaverMVP/Features/Search/Views/GlobalSearchResultsPlaceholderView.swift`
- `mobile/ios/RaverMVP/RaverMVP/Features/Search/Views/GlobalSearchResultCards.swift`
- `docs/IOS_GLOBAL_AGGREGATED_SEARCH_PRD.md`
- `docs/IOS_GLOBAL_AGGREGATED_SEARCH_DEV_LOG.md`

Decisions:

- Phase 5 uses debug telemetry only. No external analytics SDK or product event pipeline was introduced.
- Raw query text is not logged. The current logs use query length, tab, item counts, result type, entity id, score, errors, and duration.
- Manual visual QA remains separate from code polish. Dark/light mode, small/large viewport checks, and logged-out/deep-link interaction behavior are still open.

Verification:

- Ran `xcodegen generate`; project generation completed.
- Ran `npm run build` in `server`; TypeScript build succeeded.
- Ran `xcodebuild -workspace RaverMVP.xcworkspace -scheme RaverMVP -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17' build`; build succeeded.

Scope risks:

- Analytics is intentionally limited to local debug logging. A future production analytics pass should map these logs to approved event names and privacy rules before release.
- Manual QA is still needed before calling the whole feature ready for internal QA.

### 2026-05-08 - Result UI and Tab Contract Adjustment

What changed:

- Reduced the search-result page header search field height from 52 pt to 44 pt.
- Changed the result-page re-search button icon from a refresh arrow to a right arrow.
- Reduced the result tab bar font size.
- Removed result counts from tab titles so tab labels stay clean and stable.
- Reordered result tabs to: All, Events, DJ, User & Team, Posts, News, Sets, Rankings, Ratings, Festivals (Brand), Labels, Genre Tree.
- Split the previous Wiki grouping into Festivals, Labels, and Genre Tree tabs.
- Added backend tab support for `festivals`, `labels`, and `genreTree`, while keeping the old `wiki` tab key as a compatibility search bucket.
- Added genre search over the existing `Genre` table.

Files touched:

- `mobile/ios/RaverMVP/RaverMVP/Features/Search/Models/GlobalSearchModels.swift`
- `mobile/ios/RaverMVP/RaverMVP/Features/Search/ViewModels/GlobalSearchResultsViewModel.swift`
- `mobile/ios/RaverMVP/RaverMVP/Features/Search/Views/GlobalSearchResultsPlaceholderView.swift`
- `mobile/ios/RaverMVP/RaverMVP/Core/MockWebFeatureService.swift`
- `server/src/services/global-search.service.ts`
- `docs/IOS_GLOBAL_AGGREGATED_SEARCH_DEV_LOG.md`

Decisions:

- Tab counts remain available in the content header/count badge, but not in the tab bar label.
- `genre` results currently do not navigate to a detail page because no app-level genre detail route exists yet.
- The old `wiki` backend key remains accepted for compatibility, but the iOS global search UI no longer exposes a Wiki tab.

Verification:

- Ran `npm run build` in `server`; TypeScript build succeeded.
- Ran `xcodebuild -workspace RaverMVP.xcworkspace -scheme RaverMVP -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17' build`; build succeeded.

Scope risks:

- Genre Tree is now searchable, but result tapping is intentionally inert until a genre detail route exists.

## Phase Closeouts

### Phase 1 Closeout

Status: Implementation complete, pending product visual acceptance.

Notes:

- Completed the tab bar action, login guard, blur overlay, recent searches, scope hints, and placeholder results navigation.
- No backend search logic, real-time suggestions, hot search, chat search, or comment search was added.
- Build verification passed on the iPhone 17 simulator destination.
- Manual visual acceptance on a logged-in simulator session is still recommended before expanding into Phase 2.

### Phase 2 Closeout

Status: Complete for mock-data iOS UI.

Notes:

- Result page supports all tabs, mock rendering, All tab previews, domain lists, loading/empty/error/retry surfaces, pull-to-refresh, and route mapping.
- No backend, live API, analytics, hot search, real-time suggestions, chat search, or comment search was added.
- Next phase should move to backend unified search contract and service implementation.

### Phase 3 Closeout

Status: Complete for backend V1.

Notes:

- `/v1/search` is available behind login and returns normalized, relevance-sorted items across all planned domains.
- Chat message history, squad messages, direct messages, post comments, set comments, and rating comment content remain outside the search path.
- Existing domain APIs were not changed.
- Next phase should wire iOS `GlobalSearchResultsViewModel` to the live endpoint and replace the mock partial failure state with API-driven errors.

### Phase 4 Closeout

Status: Complete for live API V1.

Notes:

- iOS now uses the unified backend contract for initial search, re-search, tab retry, and pull-to-refresh.
- Mock and live services expose the same `searchGlobal` API.
- Existing route mapping is unchanged and continues to drive result-card navigation.
- Direct logged-out access to the result route now shows a login-required fallback instead of firing the search API.
- No analytics, hot search, real-time suggestions, pagination, chat search, or comment search was added.

### Phase 5 Closeout

Status: Code polish complete, manual QA pending.

Notes:

- Added debug telemetry, load-duration logging, accessibility metadata, and empty/error polish.
- Added code-level localization coverage check and route-level logged-out fallback.
- No hot search, real-time suggestions, pagination, chat search, comment search, or new search domains were added during polish.
- Remaining Phase 5 work is verification-only: dark/light mode, small/large viewport, logged-out/deep-link manual interaction behavior, and final QA.

## Future / Parking Lot

- Hot search backend.
- Real-time suggestions.
- Search history sync across devices.
- Personalized ranking experiments.
- Highlight matched ranking entries inside ranking detail.
- Event lineup text indexing if not included in V1.

## 2026-05-08 Legacy Search Entry Cleanup

Request:

- Remove old search entry points now that the global aggregated search entry exists.
- Keep UI layout reasonable after removing old buttons/search pills.

Changes:

- Removed old Discover user-facing content search entry points from recommended events, events, news, DJs, sets, and Learn/Wiki sections.
- Removed the old Discover search route cases, `DiscoverSearchDomain`, old full-screen Discover search input, and old per-domain Discover search result screens/view models.
- Removed the unused generic `SearchView` and `SearchViewModel`.
- Removed the old Messages global chat search sheet and related `MessagesViewModel` global chat-search state/methods.
- Preserved workflow-local search controls that are still required for creation, import, binding, sharing, location picking, and chat conversation-local search.

Scope Control:

- No new searchable domains or ranking strategy changes were added.
- Chat-history search remains outside the global aggregated search scope.
- Flow-local searches were intentionally kept because removing them would break compose/bind/import workflows.
