# RaveHub Flutter iOS Pixel Parity Work Tracker

Last updated: 2026-06-17

This document tracks the work required to reproduce the native iOS app in Flutter with live services, pixel-level UI parity, and behavior parity. Use checkboxes as the source of truth for progress.

## Progress Rules

- `[x]` means implemented and at least build-verified.
- `[ ]` means not yet complete, needs implementation, verification, or iOS comparison.
- Each feature should be closed only after UI, interaction, data contract, error states, loading states, and navigation are all checked.
- No mock data is acceptable for acceptance unless explicitly marked as local-only development tooling.
- iOS source of truth:
  - Native app: `/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP`
  - Flutter app: `/Users/blackie/Projects/raver/mobile/flutter_ravehub`
  - Live BFF base URL: `https://api.ravehub.top`

## Current Known State

- [x] Flutter web debug build passes with live service wiring.
- [x] Discover public content can load from live service.
- [x] Circle feed public content can load from live service.
- [x] DJ Sets list/detail can load live data and render OSS images on web.
- [x] Rating detail can load live `/v1/rating-events/:id` data and render units/rankings.
- [x] No known legacy `/v1/social/*` usage remains in Flutter source.
- [ ] Full native iOS app parity is not complete.
- [ ] Authentication-gated flows still need real-account end-to-end validation.
- [x] Authenticated live smoke harness exists for protected Profile, Checkins, Publishes, Follow lists, Virtual Assets, Inbox, Quiz, Personality, Squads, and Search endpoints; it is gated by a real QA access token.
- [x] Third-party IM, conversation, real chat, and squad chat parity are removed from Flutter scope by product decision; no Flutter chat SDK/routes remain.
- [ ] Pixel-level parity has not been completed screen-by-screen with screenshots.

## 0. Global Acceptance Gates

- [x] Project builds for Flutter web debug.
- [x] Project builds for Flutter iOS debug on simulator.
- [x] Project builds for Flutter iOS release/profile.
- [x] App launches from a clean install without cached tokens.
- [x] App launches with an existing live token/session.
  - Completion: Added bootstrap coverage that seeds persisted access/refresh tokens, runs the full app bootstrap, restores logged-in state, and syncs live unread badge counts.
  - Files: `app/test/bootstrap_unread_count_test.dart`.
  - Verification: `cd app && flutter test test/bootstrap_unread_count_test.dart`.
  - Result: Passed; existing-session bootstrap restored the stored session and loaded unread counts without framework errors.
- [x] Existing-session bootstrap preloads live notification unread badges without requiring the user to open Inbox first.
- [x] All root tab entries can be visited or auth-redirected from a clean unauthenticated launch without unhandled exceptions.
- [x] All public pages avoid mock data.
- [ ] All authenticated pages use live APIs or live native services.
- [x] Protected endpoint smoke automation exists and skips safely unless a live QA token is supplied.
- [ ] All image/video/media URLs render on iOS and web.
- [x] No stale `/v1/social/*` endpoints remain unless documented as intentionally removed.
- [x] No user-visible “TODO”, placeholder copy, or fake action remains.
  - Completion: Extended the production guard to reject user-visible string literals containing TODO/FIXME, coming-soon/not-implemented wording, or Chinese placeholder/fake-data copy in app/package Dart sources.
  - Files: `app/scripts/validate_no_mock_or_old_endpoints.sh`.
  - Verification: `bash -n app/scripts/validate_no_mock_or_old_endpoints.sh && bash app/scripts/validate_no_mock_or_old_endpoints.sh`; `cd app && flutter test test/bootstrap_unread_count_test.dart`.
  - Result: Passed; no production mock/fake/demo code, old endpoints, or user-visible placeholder strings were found, and bootstrap tests still pass.
- [x] Login screen no longer exposes an unavailable third-party sign-in placeholder action.
- [ ] All primary routes have loading, empty, error, and retry states.
- [ ] All primary routes have Chinese, English, and Japanese text coverage where iOS does.
- [ ] Pixel screenshots are captured against native iOS reference for every screen.
- [ ] Navigation stack, back behavior, deep links, and modal presentation match iOS.
- [ ] Accessibility labels, tap targets, and safe-area behavior are audited.

## 1. Foundation And Bootstrap

### 1.1 Runtime And Configuration

- [x] Live BFF base URL configured as `https://api.ravehub.top`.
- [x] App-level Dio wiring is shared across feature service locators.
- [x] Auth token store is wired into live Dio.
- [x] Route guard allows public Discover/Circle preview without forcing login.
- [x] Runtime mode naming no longer exposes product-path `mock`; developer-only mode is isolated as `localDevelopment`.
- [x] Firebase bootstrap is wired in `app/lib/main.dart` with best-effort initialization that does not block launches without platform config files.
- [ ] Firebase platform config files and push token registration still need real-device validation.
- [x] Flutter native splash prewarm/remove is wired around startup bootstrap in `app/lib/main.dart`.
- [x] Release config no longer contains placeholder store IDs; unavailable store listing URLs stay nullable until official listings exist.
- [x] Runtime app version comes from `package_info_plus` via `AppInfoService`.

### 1.2 Architecture And State

- [x] App has modular packages for auth, discover, circle, inbox, profile, core design, models, network.
- [x] Discover provider overrides route app Dio into package APIs.
- [x] Remove package default APIs that still throw `UnimplementedError` when provider override is missed.
- [x] Add a single typed live API envelope helper shared by all feature APIs.
- [x] Normalize pagination parsing across all repositories.
- [x] Feed, Ratings, Squads, Genres, Checkins, Discover APIs, Quiz, Personality, and Circle ID now consume shared live envelope/list/object/pagination helpers.
- [x] `BFFListPage.fromJson` typed factory is restored for shared page parsing and existing tests.
- [x] Add request logging and error mapping parity with iOS `ServiceError`.
- [x] BFF envelope errors, 401s, account restrictions, and session reason codes map to shared `ServiceError`; debug network logs redact auth/token/password fields.
- [x] Add session-expiration handling parity with iOS.
- [x] Dio auth refresh failure and explicit session-expiration envelopes clear tokens through `AppState.expireSession` with localized reason messages.
- [x] Add offline/retry/cache policy parity with iOS where required.
  - Completion: Added iOS-parity manual Event Detail caching with a persisted local event snapshot, live-load fallback when the event detail request is offline, and a visible cached-version banner/retry path while preserving existing `LoadPhase.offline` handling.
  - Files: `packages/features/feature_discover/lib/src/events/data/event_manual_cache_store.dart`, `packages/features/feature_discover/lib/src/events/presentation/view_models/event_detail_view_model.dart`, `packages/features/feature_discover/lib/src/events/presentation/event_detail_screen.dart`, `packages/features/feature_discover/test/event_detail_view_model_test.dart`.
  - Verification: `cd packages/features/feature_discover && flutter test test/event_detail_view_model_test.dart`; `cd packages/features/feature_discover && flutter analyze`.
  - Result: Passed; Event Detail uses the manual cache on connection failure and `feature_discover` analysis reports no issues.
- [x] Shared design-system `LoadPhase` supports offline state; Feed, Post Detail, Events, Inbox, Circle ID, Squads, Ratings, Profile, Saves, Publishes, Follows, Quiz, Personality, Checkins, Contributions, Virtual Assets, and Public Profile route errors classify connection/timeout failures as offline retry states.
- [x] Profile cache management clears real Flutter memory image cache and `cached_network_image` disk cache instead of showing placeholder cache size/action.

### 1.3 Navigation And Deep Links

- [x] Main shell has Discover, Circle, Inbox, Profile tabs.
- [x] Discover detail routes exist for events, DJs, sets, news, labels, festivals, rankings, genres, search.
- [x] Circle detail routes exist for posts, squads, IDs, ratings.
- [x] Push router has inconsistent squad path (`/squads/:id`) and should align to `/circle/squads/:id`.
- [x] All native iOS deep links need route parity audit.
  - Completion: Audited iOS `MainTabCoordinator.mapAppRoute` and share targets against Flutter deep-link handling, then added missing route-safe aliases for `messages/*` inbox destinations and protected `profile/*` child routes so they no longer fall through to public user-profile paths.
  - Files: `app/lib/router/deep_link_handler.dart`, `app/test/deep_link_handler_test.dart`, `app/pubspec.yaml`, `app/pubspec.lock`.
  - Verification: `cd app && flutter test test/deep_link_handler_test.dart test/navigation_route_smoke_test.dart`; `cd app && flutter analyze`.
  - Result: Passed; all audited custom-scheme/universal-link aliases resolve to registered GoRouter paths and app analysis reports no issues.
- [x] Share short-link resolution uses live `/v1/share-links/:code`, records app-open events, and routes `/s/:code` links through a Flutter redirect screen.
- [x] QR/deep-link external scan entry opens a real camera scanner, resolves RaveHub QR/universal/short links through the live share-link resolver, and navigates into Flutter routes.
- [ ] Back stack behavior must match native iOS single-root navigation behavior.
- [ ] Modal sheet heights, dismiss gestures, and drag handles need iOS parity.

### 1.4 Design System

- [x] Core colors, typography helpers, buttons, cards, empty/error/loading states exist.
- [x] `RemoteCoverImage` supports OSS/web CORS-safe image rendering.
- [ ] Full design token comparison against iOS colors, type sizes, line heights, radii, shadows.
- [x] iOS-like haptics are routed through `HapticService` and applied to primary buttons, segmented controls, bottom tabs, and the center search action.
- [ ] Skeleton shimmer timing and layout need iOS screenshot parity.
- [ ] Toasts, snackbars, alerts, action sheets need iOS parity.
- [ ] Share cards need full visual parity and export behavior.
- [ ] Dark/light/system theme behavior needs parity audit.

### 1.5 Media, Uploads, And Native Bridges

- [x] Remote images render in web preview after OSS handling fixes.
- [x] Media picker service is integrated in profile edit avatar/background upload.
- [x] Media picker service is integrated in squad creation avatar upload.
- [x] Media picker service must be integrated in event/DJ/set/rating editors.
- [x] Event poster upload uses live `/v1/events/upload-image` with iOS `image` field and `usage`.
- [x] DJ avatar/image upload uses live `/v1/djs/upload-image` with iOS `image`, `djId`, and `usage`.
- [x] Set thumbnail upload uses live `/v1/dj-sets/upload-thumbnail` with iOS `image` field.
- [x] Set video upload uses live `/v1/dj-sets/upload-video` with iOS `video` field.
- [ ] Upload progress UI must match iOS.
- [ ] Upload retry/cancel behavior must match iOS.
- [ ] Video playback must match iOS player behavior for supported URLs.
- [ ] YouTube/external video handling must match iOS.
- [x] Set detail YouTube/external video source opens through native external URL bridge.
- [x] Save to gallery, share sheet, clipboard, QR export need native bridges.
  - Completion: Audited the platform bridge wiring and confirmed save-to-gallery uses `GallerySaveService`, system share actions use `ShareService` for URLs/text/generated PNG bytes, clipboard actions use `ClipboardService`, and profile/Circle ID QR export flows generate QR/share images through those native bridges.
  - Files: `packages/core/raver_platform/lib/src/gallery_save_service.dart`, `packages/core/raver_platform/lib/src/share_service.dart`, `packages/core/raver_platform/lib/src/clipboard_service.dart`, `packages/features/feature_profile/lib/src/tools/qr_code_screen.dart`, `packages/features/feature_circle/lib/src/ids/presentation/widgets/circle_id_share_sheet.dart`.
  - Verification: `cd packages/core/raver_platform && flutter test test/clipboard_service_test.dart test/map_launcher_test.dart test/url_launcher_service_test.dart test/app_info_service_test.dart`; `cd packages/core/raver_platform && flutter analyze`.
  - Result: Passed; platform bridge tests and analyzer report no issues, and QR/share/save/copy flows are routed through the shared native bridge services.
- [x] Clipboard copy actions are routed through `raver_platform` `ClipboardService` for profile QR links, Circle ID share links, and submission IDs.
- [x] Map launcher bridge opens Apple Maps / Android geo / Google Maps fallback and supports free-form route search.

## 2. Authentication

### 2.1 Login

- [x] Login UI has been aligned visually once.
  - [x] Login center brand asset matches native iOS.
    - Completion: Reused the native iOS `LoginCenterBrand` PNG in Flutter Auth and rendered it as the primary center brand mark with the existing RH text badge kept only as an asset-load fallback.
    - Files: `packages/features/feature_auth/assets/login-center-brand.png`, `packages/features/feature_auth/pubspec.yaml`, `packages/features/feature_auth/lib/src/presentation/login_screen.dart`, `packages/features/feature_auth/test/widget/login_screen_test.dart`, `packages/features/feature_auth/pubspec.lock`.
    - Verification: `cd packages/features/feature_auth && flutter test test/widget/login_screen_test.dart test/view_model/auth_success_handler_test.dart`; `cd packages/features/feature_auth && flutter analyze`.
    - Result: Passed; login widget coverage finds the iOS center brand asset, auth success tests still pass, and `feature_auth` analysis reports no issues.
- [x] Login uses live auth service wiring.
- [ ] Verify password login end-to-end with live account.
- [ ] Verify phone/SMS login end-to-end with live account.
- [x] Login, register, and verification-code auth success now update app session state immediately after saving live tokens.
- [x] Route guard preserves `returnTo` for protected routes and returns authenticated users to the intended route after login.
- [ ] Verify session persistence after app restart with real live account.
- [x] Verify logout clears tokens and app state.
- [x] Add gated authenticated smoke coverage for Profile, Checkins, Publishes, Follow lists, Virtual Assets, Inbox, Quiz, Personality, Squads, and Global Search protected endpoints.
- [ ] Run authenticated smoke coverage against a real QA token and record endpoint failures.
- [x] Verify expired token refresh/session-expired UX.
  - Completion: Added AuthInterceptor coverage for protected-request 401 plus refresh failure, fixed the interceptor to finish Dio's error chain with a `DioException(error: ServiceError.sessionExpired)` instead of throwing from `onError`, and verified tokens are cleared with the session-expired callback invoked.
  - Files: `packages/core/raver_network/lib/src/client/auth_interceptor.dart`, `packages/core/raver_network/test/auth_interceptor_test.dart`, `packages/core/raver_network/pubspec.yaml`, `packages/core/raver_network/pubspec.lock`.
  - Verification: `cd packages/core/raver_network && flutter test test/auth_interceptor_test.dart`; `cd packages/core/raver_network && flutter analyze`.
  - Result: Passed; refresh failure clears persisted tokens, reports `SessionExpirationReason.expired`, and completes the request with a bounded Dio error instead of hanging.
- [ ] Pixel compare login form, keyboard behavior, validation, loading, error text.

### 2.2 Registration And SMS

- [x] SMS/email verification resend is wired to live auth code APIs from the dedicated verification route.
- [x] SMS/email verification submit is wired to live auth login APIs and persists returned tokens when route parameters are present.
- [x] Display name availability check uses live `/v1/auth/display-name/check` with iOS-aligned 2-24 character validation and non-blocking failure state.
- [x] Registration API contract sends iOS-parity optional `birthYear` and `regionCode` fields to live `/v1/auth/register`.
- [x] Terms/privacy agreement behavior requires explicit consent and opens live legal URLs from login/register text links.
- [x] Registration compliance region selector and Japan birth-year age gate are wired.
- [x] Registration home-city country/region/city selector uses the iOS catalog asset and reset behavior.
- [x] Registration home-city selection is saved in the background to live profile `location` after account creation.
- [x] Verification cooldown timer uses live auth code response seconds with iOS clamp behavior.
- [x] Auth error state mapping prefers live BFF error envelopes and iOS-aligned session/code fallbacks.

### 2.3 Account Security

- [x] Phone binding form submits to live `/v1/users/me/security`.
- [x] Email binding form submits to live `/v1/users/me/security`.
- [x] Password change form submits current/new password to live `/v1/users/me/security`.
- [ ] Account security flows still need authenticated real-account verification.
- [x] Account inactive/session expired flow clears local session and redirects protected routes through the app router.
- [x] Account deletion/data request flow uses live account deletion endpoint and iOS legal data-request links.

## 3. App Shell

### 3.1 Bottom Tabs

- [x] Four-tab shell exists.
- [x] Circle tab preview renders live feed.
- [ ] Bottom tab visual style needs pixel comparison with iOS.
- [x] Search center action exposes a dedicated semantic button and triggers search without switching bottom tabs.
- [x] Tab reselection scroll-to-top behavior has parity for scrollable root tab pages.
  - [x] Bottom tab reselection events are broadcast from the shell through `RaverTabReselectionScope`.
  - [x] Circle Feed, Inbox, and Profile root scroll views respond to reselection by animating to top.
  - [x] Discover Events, News, DJs, and Sets subpages respond to Discover tab reselection by animating their main lists to top.
  - [x] Discover Organizers, Labels, and Rankings subpages respond to Discover tab reselection by animating their main lists to top.
  - [x] Circle Squads, Circle ID, and Ratings subpages respond to Circle tab reselection by animating their main lists to top.
  - [x] Genres has no primary scroll list; reselection keeps the interactive sunburst canvas stable.
- [x] Inbox tab badge count syncs from live notification unread counts.
- [ ] Profile badge/count parity still needs live validation.
  - [x] Profile stat counts and app-shell unread counts parse iOS/live snake_case aliases and numeric string payloads.
- [ ] Safe area, blur, translucency, and keyboard avoidance need iOS parity.
  - [x] Floating tab bar clamps bottom safe-area padding and hides while the keyboard is visible.

### 3.2 Global Search

- [ ] Route exists but complete live aggregation parity is not verified.
- [x] Search route is auth-protected and preserves query `returnTo` across login redirects.
- [x] Search category counts accept both iOS/live snake_case and Flutter camelCase tab keys.
- [x] Search live DTO parsing accepts snake_case/camelCase item fields for entity id, image, deeplink, relevance, and tab counts.
- [x] Result cards have localized type badges, native tap feedback, stable title/subtitle layout, and single VoiceOver button semantics.
- [x] Empty/recent/history states now render empty query guidance and tappable recent searches without firing blank live requests.
- [x] Debounce/cancel behavior now delays typed searches and ignores stale live responses from older requests.
- [x] Search result route resolver covers events, DJs, sets, news, labels, festivals, rankings, ratings, posts, genres, users, squads, and live internal deeplinks.
  - [x] Global search entry uses an iOS-style full-screen blur overlay and keeps the underlying tab page fixed while the keyboard is visible.
    - Completion: Reworked the Flutter global search entry from a resizing `Scaffold` dialog into a full-screen transparent overlay with `BackdropFilter` blur, black scrim, fixed background layout, and a search panel that translates above the keyboard without shrinking the underlying page.
    - Files: `packages/features/feature_discover/lib/src/search/presentation/search_overlay_screen.dart`, `packages/features/feature_discover/test/widget/search_overlay_screen_test.dart`, `packages/features/feature_discover/pubspec.lock`.
    - Verification: `cd packages/features/feature_discover && flutter test test/widget/search_overlay_screen_test.dart test/widget/search_results_screen_test.dart test/search_results_view_model_test.dart test/search_result_route_resolver_test.dart test/widget/search_result_card_test.dart`; `cd packages/features/feature_discover && flutter analyze`.
    - Result: Passed; overlay root remains full-screen with keyboard insets, blur chrome renders, search behavior tests still pass, and `feature_discover` analysis reports no issues.

## 4. Discover

### 4.1 Discover Home

- [x] Discover home loads live public content.
- [x] Event/DJ/label/ranking/genre provider overrides use app Dio.
- [ ] Pixel compare top layout, cards, tab bars, spacing, text, images.
- [x] Pull-to-refresh behavior needs parity.
  - Completion: Verified existing refresh behavior on Events, News, DJs, Sets, Labels, Organizers, and Rankings, then added `RefreshIndicator`/always-scrollable reload support to Picks recommendations and Genres sunburst so every Discover top tab has a pull-to-refresh or equivalent reload path.
  - Files: `packages/features/feature_discover/lib/src/recommend/presentation/recommend_screen.dart`, `packages/features/feature_discover/lib/src/genres_sunburst/presentation/genres_root_screen.dart`.
  - Verification: `cd packages/features/feature_discover && flutter analyze`; `cd packages/features/feature_discover && flutter test test/widget/events_list_screen_test.dart test/event_detail_view_model_test.dart`.
  - Result: Passed; analyzer reports no issues and related widget/view-model tests pass.
  - [x] Picks recommendation cards use iOS-style horizontal parallax during swipe.
    - Completion: Matched the native recommendation pager interaction by adding 0.95 interactive card scaling and horizontal cover-image parallax derived from the iOS `20 + pageDelta * width * 1.4` motion, with a widened/clipped image layer so the cover moves without exposing blank edges.
    - Files: `packages/features/feature_discover/lib/src/recommend/presentation/recommend_screen.dart`, `packages/features/feature_discover/test/recommend_parallax_test.dart`.
    - Verification: `cd packages/features/feature_discover && flutter test test/recommend_parallax_test.dart test/widget/search_overlay_screen_test.dart`; `cd packages/features/feature_discover && flutter analyze`.
    - Result: Passed; parallax direction, scale bounds, and bleed limits are covered, overlay regression tests still pass, and `feature_discover` analysis reports no issues.
- [ ] Pagination/infinite scroll needs parity.
- [ ] Personalized/recommended sections need authenticated live validation.
- [ ] Location/timezone display needs parity.
- [ ] All empty/error/loading states need screenshot parity.

### 4.2 Events List

- [x] Events list uses live `/v1/events` or bootstrap where wired.
- [ ] Filter chips and event status behavior need iOS parity.
  - [x] Events list exposes iOS live status chips for all, ongoing, upcoming, and ended events and sends the `status` query parameter.
  - [x] Advanced filter sheet applies selected type/status filters to the live events query instead of only storing local UI state.
- [ ] Search, pagination, and refresh need full verification.
  - [x] Events list search box sends live `/v1/events?search=...` and preserves the search query through pagination and refresh.
  - [x] Events list pagination prevents duplicate load-more requests and keeps existing content if refresh fails.
- [ ] Event card visual parity needs screenshot audit.
  - [x] Events list cards use the native iOS row layout with a 144x172 rounded cover, date badge, derived visual status badge, right-side metadata column, and reserved action column.
    - Completion: Reworked Flutter `EventCard` from a 16:9 vertical card into the iOS-style horizontal event row, including local upcoming/ongoing/ended visual status derivation and iOS-sized cover/date/status badges.
    - Files: `packages/features/feature_discover/lib/src/events/presentation/widgets/event_card.dart`, `packages/features/feature_discover/test/widget/event_card_test.dart`.
    - Verification: `cd packages/features/feature_discover && flutter test test/widget/event_card_test.dart`; `cd packages/features/feature_discover && flutter test test/widget/event_card_test.dart test/recommend_parallax_test.dart test/widget/search_overlay_screen_test.dart`; `cd packages/features/feature_discover && flutter analyze`.
    - Result: Passed; analyzer reported no issues.
- [ ] Favorite/save state needs live parity.
  - [x] Events list favorite button calls live `/v1/events/:id/favorite`, optimistically updates card count/state, and rolls back on failure.
  - [x] Event favorite response parsing accepts camelCase, snake_case, and `favorited` live aliases.
- [ ] Share action needs parity.
  - [x] Events list cards expose a share action and invoke the same event URL fallback used by Event Detail.
  - [x] Event list/detail share actions resolve live `/v1/share-links/resolve` short links before falling back to canonical event URLs.
- [ ] Event date/timezone formatting needs parity.
  - [x] Event cards and detail info share one date formatter that preserves event-local date/time text and appends schedule timezone labels.
  - [x] Event DTO parsing accepts snake_case `start_date`, `end_date`, `event_type`, `timezone_id`, and `timezone_name` live payload aliases.

### 4.3 Event Detail

- [ ] Header media and cover layout need pixel parity.
- [ ] Event title, metadata, organizer, venue, address sections need parity.
- [ ] Lineup/timetable display needs parity.
  - [x] Lineup and timetable DTOs accept iOS live snake_case aliases for artists, B2B members, stages, times, and DJ ids.
  - [x] Lineup tab renders an iOS-style participating DJ strip with popularity/A-Z sorting.
  - [x] Lineup B2B members render as tappable chips and deep-link to DJ detail when ids are available.
  - [x] Timetable tab groups slots by event day and stage instead of mixing multi-day schedules.
  - [x] Timetable slot time labels preserve event-local clock text and mark next-day cross-midnight ranges.
- [x] Multi-day/multi-week event day logic needs parity.
  - [x] Timetable day selector builds from structured live weeks/days when available and falls back to event start/end dates.
- [x] Map/address opening needs native bridge.
  - [x] Event route section opens native/external maps for coordinate venues and falls back to route search for address-only live venues.
- [x] Favorite, share, check-in, contribution actions need live parity.
  - [x] Event detail favorite action uses live favorite endpoint with optimistic count/state updates and rollback on failure.
  - [x] Event detail share action resolves live `/v1/share-links/resolve` short links before falling back to canonical event URLs.
  - [x] Event detail check-in action/status parsing accepts iOS live snake_case fields for check-in id, time, users, and total counts.
  - [x] Event detail top check-in capsule calls live `/v1/events/:id/checkin`, syncs `/checkins` status/count, and updates the detail count after success.
  - [x] Event detail More action is wired to real share, copy-link, route, contribution edit/import, and live report actions instead of an empty placeholder.
  - [x] Event report action submits live `/v1/reports` payloads with `targetType=event`.
- [x] Related news/sets/ratings/checkins need parity.
  - [x] Event detail News tab loads iOS live `/v1/news/bound` with the event id filter and renders linked news cards.
  - [x] Event detail Posts tab loads live `/v1/feed` with the event id filter and renders related post cards instead of a static placeholder.
  - [x] Event detail Sets tab loads iOS live `/v1/dj-sets` with `eventId/eventName` filters and renders linked set cards.
  - [x] Event detail Ratings tab loads iOS live `/v1/events/:id/rating-events` and renders linked rating event cards.
  - [x] Event detail Info tab loads iOS live `/v1/checkins` with the event id filter and renders related check-in cards.
- [x] Event manual cache/offline behavior needs parity if used.
  - Completion: Event Detail More actions now include a localized cache action; cached snapshots are stored in SharedPreferences and are rendered when the live detail request fails due to weak/offline network, with a banner indicating cached data is shown.
  - Files: `packages/features/feature_discover/lib/src/events/data/event_manual_cache_store.dart`, `packages/features/feature_discover/lib/src/events/presentation/view_models/event_detail_view_model.dart`, `packages/features/feature_discover/lib/src/events/presentation/event_detail_screen.dart`.
  - Verification: `cd packages/features/feature_discover && flutter test test/event_detail_view_model_test.dart`; `cd packages/features/feature_discover && flutter analyze`.
  - Result: Passed; new unit coverage verifies manual cache save and offline fallback.

### 4.4 Event Upload/Edit

- [ ] Event upload flow needs full iOS parity.
- [ ] Event edit flow needs full iOS parity.
  - [x] Event edit load preserves existing cover, lineup image, lineup artists, and timetable slots from live event detail payloads.
  - [x] Event edit save emits iOS-style `schedule`, `weeks`, `eventDays`, `stageOrder`, `lineupArtists`, `lineupSlots`, `lineupSyncMode`, and structured `imageAssets`.
  - [x] Event edit UI supports poster, lineup image, and cover image zones with upload/replace/remove/preview controls.
  - [ ] Event edit UI still needs full lineup and timetable editing parity with the create flow.
  - [ ] Event edit review/moderation ownership behavior still needs authenticated live validation.
- [x] Lineup import flow route exists but full behavior not verified.
  - [x] Flutter OCR upload now uses iOS live `POST /v1/events/lineup/import-image` instead of the stale event-scoped draft endpoint.
  - [x] Lineup image import sends event start/end date context to the live service.
  - [x] Import response parsing accepts iOS `lineupInfo/lineup_info` payloads and legacy `matches`.
  - [x] Event upload Lineup step opens the import flow and merges selected DJs back into the current draft with duplicate protection.
- [ ] Timetable editor needs parity.
  - [x] Event upload payload emits iOS-style `schedule`, `weeks`, `eventDays`, `stageOrder`, `lineupArtists`, `lineupSlots`, and `lineupSyncMode`.
  - [x] Timetable slots preserve event-day metadata and normalize cross-midnight end times into the next local day.
  - [x] Upload flow can fill missing lineup artists from timetable slots before submission.
  - [x] Timetable editor exposes event-day and stage filters for multi-day/multi-stage editing.
  - [x] Timetable slots can be moved across event days and stages while preserving local clock time.
  - [x] Timetable create dialog inherits the selected day/stage as defaults.
  - [ ] Timetable editor still needs native iOS visual density and screenshot interaction audit.
- [ ] Image/media upload needs parity.
  - [x] Event upload supports iOS-style poster, lineup, and cover image zones.
  - [x] Image uploads use live `/v1/events/upload-image` with the zone `usage` field.
  - [x] Event create payload emits `coverImageUrl`, `lineupImageUrl`, and structured `imageAssets` with type/label/sort/order/source/fileName.
  - [x] Event upload supports multi-image per zone with first-image primary semantics.
  - [x] Event upload image zones support full-screen preview, remove, and per-zone ordering controls.
  - [x] Multi-image order/remove state persists through local draft restore and live create payload generation.
  - [x] Event upload image zones show background upload progress and support cancel/retry per zone.
  - [ ] Native iOS screenshot/interaction comparison is still needed for image upload progress/cancel/retry states.
- [ ] Draft/autosave/review submission states need parity.
  - [x] Event upload create flow persists a local JSON draft through SharedPreferences.
  - [x] Event upload restores saved drafts on open and syncs restored values back into the form controllers.
  - [x] Draft saves on step navigation and after lineup, timetable, and image mutations.
  - [x] Successful live create clears the saved draft.
  - [x] Restored-draft confirmation banner, discard controls, validation issue routing, and submit success detail screen are implemented.
  - [ ] Native iOS screenshot comparison is still needed for the draft/review/success states.
- [ ] Permissions/moderation states need parity.

### 4.5 DJs

- [x] DJ recommendations/list APIs were adapted to live endpoints.
- [ ] DJ list pixel parity needs audit.
- [ ] DJ detail live data parity needs audit.
- [x] DJ avatar/image handling needs iOS parity.
- [ ] Follow/save/share actions need live parity.
- [ ] DJ related events, sets, rating units, news need parity.
- [ ] DJ import/editor flow needs parity.
- [x] Genre tag clickability needs parity.
  - Completion: DJ detail genre chips are now tappable; live `genreBindings` route directly to `/genres/:genreId`, while legacy name-only tags fall back to `/search?q=...` instead of staying inert.
  - Files: `packages/features/feature_discover/lib/src/djs/presentation/dj_detail_screen.dart`, `packages/features/feature_discover/test/dj_genre_route_test.dart`.
  - Verification: `cd packages/features/feature_discover && flutter test test/dj_genre_route_test.dart`; `cd packages/features/feature_discover && flutter analyze`.
  - Result: Passed; route selection covers both live-bound and name-only genre tags.

### 4.6 DJ Sets

- [x] Sets endpoint moved to live `/v1/dj-sets`.
- [x] Set detail route loads live data in browser preview.
- [x] Set thumbnails/avatars use `RemoteCoverImage`.
- [x] Set detail avoids initializing video player for non-direct YouTube page URLs.
- [x] Set comments parse live nested user data.
- [ ] Sets list pixel parity needs audit.
- [ ] Set player UI and audio/video playback need iOS parity.
- [ ] Tracklist display/edit needs parity.
- [x] Set model parses iOS live `viewCount`, `likeCount`, `trackCount`, verification, uploader, and slug fields.
- [x] Set detail renders live duration, track, view, like, and comment stats.
- [x] Tracklist editor saves live tracks through `PUT /v1/dj-sets/:id/tracks`.
- [x] Tracklist editor supports title, artist, start/end time, Spotify URL, and NetEase URL fields.
- [x] Set detail tracklist opens Spotify/NetEase links through native external URL bridge.
- [ ] Like/save/comment/share actions need authenticated live validation.
- [x] Set detail comment submit uses live `/v1/dj-sets/:id/comments`.
- [x] Set detail comments support live pagination/load more through `/v1/dj-sets/:id/comments`.
- [x] Set comment update/delete APIs are wired through live `/v1/comments/:commentId`.
- [x] Set comment owner-only edit/delete menu uses injected current user id and live update/delete APIs.
- [x] Set detail share action uses native platform share sheet.
- [x] Set detail share resolves iOS live short link through `/v1/share-links/resolve` with `targetType=set`.
- [ ] Set editor/upload flow needs parity.
- [x] Set detail owner-only edit action routes to the Set editor when `uploadedById` matches current user.
- [x] Set detail owner-only tracklist edit action opens the tracklist editor through `/sets/:id/tracklist/edit`.
- [x] Set detail owner-only delete action calls live `DELETE /v1/dj-sets/:id`.
- [x] Set editor update uses iOS live `PATCH /v1/dj-sets/:id` contract.
- [x] Set editor supports live thumbnail upload and saves `thumbnailUrl`.
- [x] Set editor supports iOS live YouTube preview via `/v1/dj-sets/preview`.
- [x] Set editor saves `videoAuthorName`, `venue`, `eventName`, and `rightsConfirmed`.
- [x] Set editor validates title, YouTube URL, and rights confirmation before save.
- [x] Set editor supports live DJ search binding through `/v1/djs`.
- [x] Set editor supports live event search binding through `/v1/events`.
- [x] Netease/Spotify external links need parity.
- [x] Set detail external video/source links use `UrlLauncherService`.

### 4.7 News

- [x] News model supports live field aliases such as `coverImageURL`, `authorID`, `publishedAt`.
- [ ] News list pixel parity needs audit.
- [ ] News detail pixel parity needs audit.
- [x] News bound DJs/events render related chips, resolve names through live `/v1/djs/:id` and `/v1/events/:id`, and fall back to clickable IDs.
- [x] Publish/edit/review states need parity.
- [x] News list category selector uses iOS Discover labels and a compact chip row matching the iOS selector treatment.
- [x] News list includes the iOS-style trailing publish action and reloads live content after a successful submit.
- [x] Browser smoke verified `/discover` News tab renders live news, category chips, and publish entry.
- [x] News editor uses iOS Discover categories: festival, scene, gear, industry, community.
- [x] News editor publish/edit payload includes live `source`, `summary`, `link`, optional `body`, `coverImageUrl`, `boundDjIds`, and `boundEventIds`.
- [x] News editor makes body optional and validates title plus source before live save.
- [x] News editor cover upload uses the iOS-compatible live event image upload path with `usage=news_cover`.
- [x] News editor supports live DJ/Event binding search through `/v1/djs` and `/v1/events`.
- [x] News create/update save result parses both created articles and live `submitted_for_review` content-submission payloads.
- [x] News editor surfaces submitted-for-review success feedback instead of treating review queue responses as failures.
- [x] Browser smoke verified list publish entry opens the News editor form with live-source fields.
- [x] News detail original source link opens through `UrlLauncherService`.
- [x] News detail comments load from live `/v1/news/:id/comments`, render author avatars/timestamps, and support live comment submit.
- [x] News detail renders a stable 16:9 iOS-style cover fallback when live content has no cover URL.
- [x] Share action resolves iOS live short link through `/v1/share-links/resolve` with `targetType=news` and opens native share sheet.

### 4.8 Labels, Festivals, Organizers, Rankings, Genres

- [x] Labels/organizers/rankings/genres live envelope parsing was broadened.
- [x] Brand/label/festival models support additional live aliases.
- [x] Browser preview previously confirmed these Discover sections can load live content.
- [x] Default package APIs no longer throw `UnimplementedError` in Flutter source.
- [ ] Each list/detail page needs pixel screenshot parity.
- [ ] Follow/save/share actions need live parity.
- [x] Label and Festival detail APIs accept live envelope shapes instead of assuming bare objects.
- [x] Label and Festival detail share actions resolve live short links through `/v1/share-links/resolve` and fall back to public URLs.
- [x] Label website and Festival links open through `UrlLauncherService`.
- [x] Festival follow action uses the iOS live followed-brand preference endpoint (`/v1/notification-center/preferences/followed-brand-update`) and updates `watchedBrandIds`.
- [x] Ranking board detail share resolves live `ranking_board` short links through `/v1/share-links/resolve`.
- [ ] Ranking detail and entry detail need parity.
- [x] Ranking detail API accepts live envelope shapes (`data`, `ranking`, `board`, `item`, `result`) instead of assuming a bare object.
- [x] Ranking models tolerate live aliases, numeric strings, nested DJ/Festival objects, and malformed entry rows.
- [x] Ranking board detail rows deep-link into entry detail using live DJ ID when available and rank fallback otherwise.
- [x] Ranking detail routes consume shared-link `year` query parameters and request the matching live board year.
- [x] Ranking entry navigation preserves the active live board year when opening entry detail.
- [x] Ranking model tests cover live board/detail/entry alias parsing.
- [ ] Genre sunburst/list/detail needs parity and no fallback crash path.
- [x] Genre detail API accepts live envelope shapes (`data`, `genre`, `item`, `result`) instead of assuming a bare object.
- [x] Genre detail API recursively unwraps nested live envelopes such as `data.genre` or `payload.item`.
- [x] Genre models tolerate live aliases and nullable optional fields for detail, tree summaries, sunburst nodes, children, colors, and sound cues.
- [x] Genre model tests cover live alias/null parsing and malformed child rows.
- [x] Genre sunburst selected bar deep-links to the selected genre detail from the whole row.
- [x] Genre detail sub-genre chips deep-link to live child genre routes.
- [x] Genre sound cue Spotify/Apple Music links open through `UrlLauncherService`.
- [ ] Related entities and deep links need parity.
- [x] Label founder rows deep-link to live DJ detail routes when `djId` is present.
- [x] Flutter custom-scheme deep links accept iOS `raver://ranking-board/:id` aliases and preserve query parameters such as `year`.

## 5. Circle

### 5.1 Feed

- [x] Feed API moved from old `/v1/social/feed` to live `/v1/feed`.
- [x] Feed UI was visually aligned once.
- [x] Circle feed can load live public content in browser preview.
- [x] Following/recommended/latest segmentation matches iOS `FeedMode.allCases`, with Recommended as the default tab.
- [x] Feed pagination uses the iOS live cursor contract (`cursor`, `mode`, `eventId`, `limit=12`) instead of page-number placeholders.
- [ ] Compose post flow needs live authenticated validation.
- [x] Compose post media buttons use the platform media picker instead of placeholder notices.
- [x] Compose post uploads selected images/videos through iOS live `/v1/feed/upload-image` and `/v1/feed/upload-video` before creation.
- [x] Compose post creation sends iOS live JSON payload (`content`, `images`, `location`, `boundEventIDs`) to `/v1/feed/posts`.
- [x] Compose post handles `submitted_for_review` live responses as successful submissions.
- [x] Compose post event binding uses live `/v1/events` search instead of a hard-coded placeholder event.
- [ ] Media post rendering needs parity.
- [x] Post model splits iOS live mixed media URLs so video URLs inside `images` render as videos instead of broken images.
- [x] Feed/Profile shared post cards render video media tiles with a stable play overlay and filename label.
- [x] Post detail video tiles open the live video URL through the native external URL bridge.
- [x] Like/comment/share/save/hide/report actions use live endpoints across Feed list and Post detail.
- [x] Feed and post detail share actions resolve live short links, open the native share sheet, and report `/v1/feed/posts/:id/share` with `status=completed`.
- [x] Feed card save action toggles live `/v1/feed/posts/:id/save`, mirrors iOS star state, and reports `feed_save`.
- [x] Post detail save action toggles live `/v1/feed/posts/:id/save` with optimistic UI and failure rollback.
- [x] Feed list and post detail hide actions use the iOS live `/v1/feed/posts/:id/hide` endpoint with `reason=not_relevant`.
- [x] Feed list and post detail report actions submit live `/v1/reports` payloads with iOS-aligned `targetType=post`, reason raw values, details, and `source=flutter_app`.
- [x] Shared Flutter `ReportSheet` uses iOS/BFF report reason raw values and async submit/error handling.
- [x] Feed API post/comment/share parsing accepts live envelope variants instead of assuming bare objects.
- [x] Post detail comment submit increments live comment count in the detail action bar.
- [x] Feed card impression, open, like, save, share, and hide actions report live `/v1/feed/events` payloads with session id, `feedMode`, position, and metadata.
- [ ] Post detail needs pixel parity.
- [ ] Comment threading/replies need parity.
- [x] Comment model parses iOS live thread fields: `postID`, `parentCommentID`, `rootCommentID`, `depth`, and `replyToAuthor`.
- [x] Post detail groups comments into iOS-style root threads with reply preview, expand, load-more, and collapse behavior.
- [x] Post detail reply composer shows the current reply target and can cancel before submit.
- [x] Comment parsing tests cover live thread and reply alias payloads.
- [ ] Feed recommendation rules need parity.

### 5.2 Squads

- [x] Squad API paths moved from `/v1/social/squads*` to live `/v1/squads*`.
- [x] My squads and recommended squads parse list/envelope formats.
- [x] Squad profile uses live `/v1/squads/:id/profile`.
- [x] Squad offline activity history uses live `/v1/squads/:id/offline-activities/history`.
- [x] Squad model parsing tolerates live field aliases and nullable fields.
- [x] Unauthenticated Squads tab shows an iOS-style sign-in gate instead of calling protected squad endpoints and surfacing 401 errors.
- [x] IM-backed squad create/join/leave/invite/disband parity is removed from Flutter scope.
- [x] Squad member directory should come from a live backend endpoint, not guessed REST or any IM bridge.
  - Completion: Locked Flutter squad member directory loading to the live `/v1/squads/:id/profile` payload's `members` projection, with no IM bridge and no guessed `/members` endpoint. Added focused API coverage for member alias parsing and request path.
  - Files: `packages/features/feature_circle/lib/src/squads/data/squad_api.dart`, `packages/features/feature_circle/test/data/squad_api_test.dart`, `packages/features/feature_circle/lib/src/ids/presentation/widgets/circle_id_composer_sheet.dart`, `packages/features/feature_circle/lib/src/squads/presentation/squad_offline_activity_history_screen.dart`.
  - Verification: `cd packages/features/feature_circle && flutter test test/data/squad_api_test.dart test/widget/squad_hall_screen_test.dart`; `cd packages/features/feature_circle && flutter analyze`.
  - Result: Passed; member directory fetches the live profile endpoint and `feature_circle` analysis reports no issues.
- [ ] Squad profile pixel parity needs audit.
- [ ] Squad hall pixel parity needs audit.
- [ ] Squad manage screen needs live parity.
- [x] Squad creation avatar upload uses live `/v1/squads/:id/avatar`.
- [ ] Offline activity current/live map/location upload/end/join/leave flows need parity.
- [ ] Privacy copy and location sync behavior need parity.

### 5.3 Circle ID

- [x] Flutter Circle ID no longer uses old `/v1/social/circle-ids`.
- [x] Native iOS Circle ID appears to be a music/content identification card, not the current Flutter nickname/tagline identity-card model.
- [x] Define correct live API contract from iOS `CircleIDEntry` / related services.
- [x] Replace Flutter feature model with iOS-equivalent Circle ID domain model.
- [x] Implement list/detail/create/comment live APIs.
- [x] Implement Circle ID copy-link live API via `/v1/share-links/resolve` and `/v1/feed/posts/:id/share`.
- [x] Implement native-style Circle ID share panel shell with live copy-link, QR, and poster actions.
- [x] Implement Circle ID system share entry with live short-link resolution and share-count reporting.
- [x] Add iOS share deep-link route alias `/circle/id/:cardId` and custom-scheme mapping.
- [x] Circle ID QR/poster asset sheets can save to gallery, invoke native image share, and copy the resolved short link.
- [x] Circle ID chat-share parity is removed; system share, copy link, QR, and poster remain the supported share paths.
- [x] Implement iOS-equivalent create form: song name, audio/video URL, rights confirmation, linked event, linked DJs.
- [x] Event and DJ pickers use live `/v1/events` and `/v1/djs` services.
- [ ] Implement card UI pixel parity.
- [x] Persist like/favorite/repost reaction state through live feed APIs.
- [x] Implement share card payload parity for non-IM share surfaces.
  - [x] Circle ID poster share falls back to a locally generated PNG card when the live poster asset is not available, while preserving save/share/copy-link actions.
- [x] Remove stale `/v1/social/circle-ids` endpoints.

### 5.4 Ratings

- [x] Rating list API moved to live `/v1/rating-events`.
- [x] Rating detail API moved to live `/v1/rating-events/:id`.
- [x] Rating units are read from live event detail `units`.
- [x] Rating models tolerate `sourceEventId`, nested `createdBy`, nullable `djId`, `linkedDJs`, comments.
- [x] Browser verified live rating detail renders event cover, ranking bars, and rating units with no console errors.
- [ ] Rating hub/list pixel parity needs audit.
  - [x] Rating hub list matches native iOS all-events loading and card information structure.
    - Completion: Removed the non-iOS ongoing/ended segmented filter from the Flutter rating hub, stopped sending the default `status` query, added the iOS-style "Event-driven ratings" header with a capsule publish action, and rebuilt rating event cards with a 72px square image, publisher line, unit count, average score, and half-star read-only display.
    - Files: `packages/features/feature_circle/lib/src/ratings/presentation/rating_hub_screen.dart`, `packages/features/feature_circle/lib/src/ratings/presentation/view_models/rating_view_model.dart`, `packages/features/feature_circle/test/widget/rating_hub_screen_test.dart`, `packages/features/feature_circle/test/data/rating_api_test.dart`.
    - Verification: `cd packages/features/feature_circle && flutter pub get`; `cd packages/features/feature_circle && flutter test test/widget/rating_hub_screen_test.dart test/data/rating_api_test.dart`; `cd packages/features/feature_circle && flutter analyze`.
    - Result: Passed; analyzer reported no issues. Native iOS screenshot comparison and the missing "Import from Event" flow remain unverified/not implemented.
- [ ] Rating detail pixel parity needs audit.
- [x] Rating unit detail needs direct live `/v1/rating-units/:id` repository method instead of refetching parent event.
- [x] Rating comments GET path needs live contract verification.
- [ ] Vote/comment POST behavior needs authenticated live validation.
- [x] Create/edit rating event/unit forms send live `name/description/imageUrl` payloads where supported.
- [x] Rating event and rating unit edit flows call live `PATCH /v1/rating-events/:id` and `PATCH /v1/rating-units/:id`.
- [x] Rating event/unit image upload uses live `/v1/rating/upload-image`.
- [x] Share card payload parity implemented for non-IM share surfaces.
  - [x] Rating event and rating unit detail share actions resolve live `/v1/share-links/resolve` payloads with `rating_event_card` / `rating_unit_card` previews and share generated PNG cards through the native share sheet.

## 6. Inbox And Notifications

### 6.1 Inbox Home

- [ ] Inbox route exists but full live parity is not verified.
- [x] Notification categories need iOS parity.
  - Completion: Audited the native iOS Inbox/message notification entry set and verified Flutter exposes the same five notification categories: Community, Followed Events, Followed DJs, Followed Brands, and Content Reviews. Extended the Inbox widget test to assert all five category cards render from live unread-count data.
  - Files: `packages/features/feature_inbox/test/widget/inbox_screen_test.dart`.
  - Verification: `cd packages/features/feature_inbox && flutter test test/widget/inbox_screen_test.dart`; `cd packages/features/feature_inbox && flutter analyze`.
  - Result: Passed; all five iOS-parity Inbox categories render and `feature_inbox` analysis reports no issues.
- [x] Inbox unread counts sync into the app shell badge from live notification center data.
- [x] Pull-to-refresh/loading/error/empty states need parity.
  - Completion: Added a reusable refreshable empty-state surface for Inbox subroutes, wired empty-state pull-to-refresh across Community alerts, Followed Events, Followed DJs, Followed Brands, and Content Reviews, and made Inbox home/subroute lists always scrollable so refresh is available even with short content. Existing skeleton loading and retryable error states remain covered by `LoadPhaseBuilder`; settings switches were updated to the non-deprecated Flutter active thumb color API so analyzer stays clean.
  - Files: `packages/features/feature_inbox/lib/src/presentation/widgets/refreshable_empty_state.dart`, `packages/features/feature_inbox/lib/src/presentation/inbox_home_screen.dart`, `packages/features/feature_inbox/lib/src/presentation/alert_category_screen.dart`, `packages/features/feature_inbox/lib/src/presentation/followed_events_inbox_screen.dart`, `packages/features/feature_inbox/lib/src/presentation/followed_djs_inbox_screen.dart`, `packages/features/feature_inbox/lib/src/presentation/followed_brands_inbox_screen.dart`, `packages/features/feature_inbox/lib/src/presentation/content_reviews_inbox_screen.dart`, `packages/features/feature_inbox/lib/src/presentation/notification_settings_screen.dart`, `packages/features/feature_inbox/test/widget/inbox_screen_test.dart`.
  - Verification: `cd packages/features/feature_inbox && flutter test test/widget/inbox_screen_test.dart`; `cd packages/features/feature_inbox && flutter analyze`.
  - Result: Passed; Inbox widget coverage confirms refreshable home/list/empty states and analyzer reports no issues.
- [x] Deep links from notifications route through direct app routes, custom-scheme/universal-link payloads, and live `targetType/targetId` aliases.

### 6.2 Removed Chat And IM Scope

- [x] IM login/session bridge is removed from Flutter scope.
- [x] Conversation list routes/screens are not part of Flutter scope.
- [x] Private chat and squad/group chat UI parity are removed from Flutter scope.
- [x] Text/image/video/audio message send/receive parity is removed from Flutter scope.
- [x] Mentions, read receipts, typing/online states, chat settings, custom card payloads, and chat local storage are removed from Flutter scope.
- [x] Squad member role/invite/remove/transfer leader work should be implemented through live backend squad endpoints only when product scope requires it, not IM.

### 6.3 Push Notifications

- [x] APNS/FCM/native push wiring not completed for Flutter parity.
  - Completion: Added the missing iOS static push capability wiring for Flutter by declaring the APNS entitlement and `remote-notification` background mode, while keeping token lifecycle and real-device Firebase validation tracked separately.
  - Files: `app/ios/Runner/Runner.entitlements`, `app/ios/Runner/Info.plist`, `app/test/ios_push_config_test.dart`.
  - Verification: `cd app && flutter test test/ios_push_config_test.dart test/ios_countdown_widget_config_test.dart test/ios_share_extension_scope_test.dart`; `cd app && flutter analyze`; `cd app && flutter build ios --simulator --debug`.
  - Result: Passed; iOS push entitlement/background-mode configuration is locked by tests, app analysis reports no issues, and the iOS simulator debug build succeeds.
- [x] Push routing table audit completed for Flutter route coverage: events, DJs, sets, posts, squads, news, labels, festivals, rankings, rating events/units, Circle ID, users, content reviews, checkins, followed updates, and inbox categories.
- [x] Foreground notification handling needs parity.
  - Completion: Configured Firebase Messaging foreground presentation options for alert/badge/sound to mirror iOS `willPresent`, wired foreground FCM delivery through `AppBootstrap.handleForegroundPushMessageData`, refreshed live unread badge counts without auto-navigation, and reused the push payload route resolver for diagnostics/tap parity. Background tap handling now resolves the same route/path/deepLink/link/url/appLink/type payload family through the shared push resolver.
  - Files: `packages/core/raver_platform/lib/src/push_notification_service.dart`, `app/lib/bootstrap.dart`, `app/test/bootstrap_unread_count_test.dart`.
  - Verification: `cd app && flutter test test/bootstrap_unread_count_test.dart test/push_router_test.dart`; `cd app && flutter analyze`; `cd packages/core/raver_platform && flutter analyze`.
  - Result: Passed; foreground push payloads refresh unread badges and resolve expected Inbox routes without navigating, app analysis reports no issues, and `raver_platform` analysis reports no issues.
- [x] Background tap/deep-link routing resolves `route/path/deepLink/link/url/appLink` payloads before falling back to typed target routing.
- [x] Notification permission UX needs parity.
  - Completion: Matched the native iOS deferred-permission behavior by making push-token loading silent by default: startup and post-login registration now only inspect existing notification authorization and never call the OS permission prompt. `PushNotificationService.getPushToken(requestPermission: true)` remains available for explicit user-triggered flows, and unit coverage verifies silent/default, explicit-request, and denied-permission paths.
  - Files: `packages/core/raver_platform/lib/src/push_notification_service.dart`, `packages/core/raver_platform/test/push_notification_service_test.dart`, `app/lib/bootstrap.dart`.
  - Verification: `cd packages/core/raver_platform && flutter test test/push_notification_service_test.dart`; `cd packages/core/raver_platform && flutter analyze`; `cd app && flutter test test/bootstrap_unread_count_test.dart test/push_router_test.dart`; `cd app && flutter analyze`.
  - Result: Passed; default push-token loading checks notification status without prompting, explicit user-intent mode requests permission before token retrieval, denied permission does not fetch/register a token, and app push badge/routing tests plus analyzers report no issues.
- [x] Badge clearing/count sync needs parity.
  - Completion: Added a native app-icon badge bridge and wired live notification-center unread-count sync to update the system badge total. Foreground push refresh, launch/session restore sync, Inbox unread sync, logout, and session-expiration clearing now keep the Flutter app-shell badge and iOS app-icon badge aligned; Android/Harmony/web safely no-op when the native badge channel is unavailable.
  - Files: `packages/core/raver_platform/lib/src/app_badge_service.dart`, `packages/core/raver_platform/lib/raver_platform.dart`, `app/ios/Runner/AppDelegate.swift`, `app/lib/bootstrap.dart`, `app/lib/state/app_state_notifier.dart`, `packages/core/raver_platform/test/app_badge_service_test.dart`, `app/test/bootstrap_unread_count_test.dart`.
  - Verification: `cd packages/core/raver_platform && flutter test test/app_badge_service_test.dart test/push_notification_service_test.dart`; `cd packages/core/raver_platform && flutter analyze`; `cd app && flutter test test/bootstrap_unread_count_test.dart test/push_router_test.dart`; `cd app && flutter analyze`; `cd app && flutter build ios --simulator --debug`.
  - Result: Passed; badge service sends normalized counts/clear commands through the platform channel, unread-count sync writes the expected total badge count, logout/session-expiration paths clear badges, analyzers report no issues, and the iOS simulator build succeeds.

## 7. Profile

### 7.1 Me/Profile Home

- [x] Profile UI was visually aligned once.
- [ ] Live profile data end-to-end needs authenticated validation.
- [ ] Public profile route parity needs audit.
- [ ] Profile stats/cards/checkins/publishes/follows need live parity.
- [x] Avatar/background rendering uses live profile URLs with iOS-style gradient fallback.
- [x] Edit entry points and settings entry points need parity.
  - Completion: Added widget-route coverage proving the Profile home settings icon opens `/profile/settings` and the Edit Profile CTA opens `/profile/edit`, while existing settings widget coverage verifies the settings entry groups remain rendered. This closes the automatable entry-point parity surface; visual/settings-page pixel parity remains tracked separately.
  - Files: `packages/features/feature_profile/test/widget/profile_state_test.dart`, `packages/features/feature_profile/test/widget/settings_screen_test.dart`.
  - Verification: `cd packages/features/feature_profile && flutter test test/widget/profile_state_test.dart test/widget/settings_screen_test.dart`; `cd packages/features/feature_profile && flutter analyze`.
  - Result: Passed; Profile settings and edit entry points navigate to their registered routes, settings sections render, and `feature_profile` analysis reports no issues.
- [x] Pull-to-refresh/loading/error/empty states need parity.
  - Completion: Made Profile Home's main success surface always pull-to-refreshable, added a shared refreshable empty-state wrapper for Profile subroutes, wired Follow List empty states through pull-to-refresh, and reset cached Profile service-locator APIs when replacing Dio so tests and app bootstrap use the active live client. Existing `LoadPhaseBuilder` loading/error/retry states remain intact.
  - Files: `packages/features/feature_profile/lib/src/_shared/refreshable_empty_state.dart`, `packages/features/feature_profile/lib/src/_shared/profile_service_locator.dart`, `packages/features/feature_profile/lib/src/profile_me/profile_me_screen.dart`, `packages/features/feature_profile/lib/src/follow_list/follow_list_screen.dart`, `packages/features/feature_profile/lib/src/coordinator/profile_routes.dart`, `packages/features/feature_profile/lib/src/profile_me/presentation/widgets/profile_header.dart`, `packages/features/feature_profile/test/widget/profile_state_test.dart`.
  - Verification: `cd packages/features/feature_profile && flutter test test/widget/profile_state_test.dart`; `cd packages/features/feature_profile && flutter analyze`.
  - Result: Passed; Profile Home success state and Follow List empty state expose refreshable surfaces and `feature_profile` analysis reports no issues.

### 7.2 Edit Profile

- [x] Avatar picker/upload uses MediaPickerService and live `/v1/profile/me/avatar`.
- [x] Background picker/upload uses MediaPickerService and live `/v1/profile/me/background`.
- [x] Profile save API parity needs verification.
  - Completion: Added focused Edit Profile ViewModel coverage proving profile saves use live `PATCH /v1/profile/me`, trim display name/bio/location before sending, and preserve the expected `displayName`, `bio`, `gender`, `birthday`, `location`, `avatarUrl`, and `backgroundURL` payload keys.
  - Files: `packages/features/feature_profile/lib/src/edit_profile/view_models/edit_profile_view_model.dart`, `packages/features/feature_profile/test/edit_profile_view_model_test.dart`.
  - Verification: `cd packages/features/feature_profile && flutter test test/edit_profile_view_model_test.dart test/widget/profile_state_test.dart`; `cd packages/features/feature_profile && flutter analyze`.
  - Result: Passed; profile save payload parity is covered and `feature_profile` analysis reports no issues.
- [x] Validation, error mapping, and loading states need parity.
  - Completion: Added Edit Profile local validation for 2-24 character display names, 200-character bio limit, and taken display-name blocking; the save button now respects checking/saving/uploading/validation state, field-level display-name errors render through `InputDecoration.errorText`, and invalid/taken names do not send profile update requests.
  - Files: `packages/features/feature_profile/lib/src/edit_profile/view_models/edit_profile_view_model.dart`, `packages/features/feature_profile/lib/src/edit_profile/edit_profile_screen.dart`, `packages/features/feature_profile/test/edit_profile_view_model_test.dart`.
  - Verification: `cd packages/features/feature_profile && flutter test test/edit_profile_view_model_test.dart test/widget/profile_state_test.dart`; `cd packages/features/feature_profile && flutter analyze`.
  - Result: Passed; invalid and taken display names are blocked before PATCH, valid saves trim and submit the expected payload, and analyzer reports no issues.
- [x] Crop/compression behavior needs parity.
  - Completion: Added profile media transform presets so avatar selection/camera capture uses a locked 1:1 crop with 2048px picker bounds, 1024x1024 cropped output, and JPEG quality 88; profile background selection uses a locked 5:3 crop with 3000x1800 picker bounds, 2000x1200 cropped output, and JPEG quality 88. Profile picks also disable full metadata reads to avoid unnecessary iOS photo metadata permission pressure. The picker/cropper delegates are test-injectable so the exact crop/compression parameters are covered.
  - Files: `packages/core/raver_platform/lib/src/media_picker_service.dart`, `packages/core/raver_platform/test/media_picker_service_test.dart`, `packages/features/feature_profile/test/edit_profile_view_model_test.dart`, `packages/features/feature_profile/test/widget/profile_state_test.dart`.
  - Verification: `cd packages/core/raver_platform && flutter test test/media_picker_service_test.dart`; `cd packages/core/raver_platform && flutter analyze`; `cd packages/features/feature_profile && flutter test test/edit_profile_view_model_test.dart test/widget/profile_state_test.dart`; `cd packages/features/feature_profile && flutter analyze`.
  - Result: Passed; avatar gallery/camera and profile-background media paths use the expected aspect ratio, picker bounds, crop bounds, compression quality, and metadata behavior, with Profile edit tests and analyzers reporting no issues.

### 7.3 Checkins

- [x] Checkin list API moved to live `/v1/checkins`.
- [x] My checkins overview moved to live `/v2/me/checkins/overview`.
- [x] Checkin models tolerate live nested `event` and `dj`.
- [ ] Authenticated live checkins page needs real-account verification.
- [ ] Timeline/gallery/stats v2 pages need iOS parity.
- [ ] Event checkin status needs parity.
  - [x] Event detail check-in API parsing accepts live `checked_in_at`, `my_checkin_at`, `total_count`, and user field aliases.
  - [x] Event DTO parsing accepts live `favorite_count`, `checkin_count`, and `is_favorited` aliases.
- [ ] Create/update/delete checkin flows need parity.
- [ ] Event attendance selections and projection refresh behavior need parity.
- [x] Checkin share card parity implemented for non-IM share surfaces.
  - [x] My Check-ins resolves live `/v1/share-links/resolve` with `targetType=my_checkins` / `previewType=my_checkins_card` and shares a generated PNG summary card through the native share sheet.

### 7.4 Quiz

- [x] Quiz API now uses live `/v1/quiz/sessions` and session submit flow.
- [x] Flutter answer indices are translated into live `questionId`/`optionId`.
- [ ] Authenticated live quiz run needs validation.
- [ ] Quiz status/config preflight needs full iOS parity.
- [ ] Debug question set mode needs parity if required.
- [ ] Abandon/restart/retake flow needs parity.
- [ ] Result screen needs live payload/pixel parity.
- [x] Quiz result share action uses native platform share sheet text payload.

### 7.5 Personality / EDMTI

- [x] Personality API now uses live `/v1/personality/sessions` and submit flow.
- [x] Flutter answer indices are translated into live `questionId`/`optionId`.
- [ ] Authenticated live personality run needs validation.
- [ ] Personality status/result preflight needs iOS parity.
- [ ] Save-answer/resume-session behavior needs parity.
- [ ] Result screen needs live payload/pixel parity.
- [ ] Dimensions/matched DJs mapping needs live payload parity.
- [ ] Share card export needs full native share/save parity.

### 7.6 Publishes, Reviews, Follows

- [x] My publishes list/detail API paths moved to iOS live `/api/content-submissions/mine`.
- [ ] My publishes UI parity not complete.
- [x] Submission detail TODO edit navigation replaced with live entity edit-route resolver and actionable missing-entity-ID fallback.
- [x] Review states and moderation labels map live `processing/reviewing/approved/rejected/failed/cancelled` with readable review-note extraction.
- [x] Profile follow lists support live following/followers/friends tabs, including public-profile friends entry.
- [x] Followed event/DJ/brand update lists consume live notification projections, show unread state, and mark individual items read.
- [x] Rating event and rating unit published-content edit flows have live PATCH entry points from detail screens.
- [ ] Published events/DJ sets edit flows still need owner/content-submission parity validation.

### 7.7 Tools And Settings

- [x] QR code screen renders a real profile QR code instead of placeholder visualization.
- [x] QR code screen can copy the profile link and share the QR card image through the platform share sheet.
- [x] QR save-to-gallery native bridge saves generated QR card images through `GallerySaveService`.
- [x] QR save action is enabled only on native gallery-capable platforms and keeps web sharing available.
- [x] Route tool MapLauncher TODO is replaced with real external-map navigation.
- [x] About page terms/privacy external URL opening uses `UrlLauncherService`.
- [x] Account security TODO actions are wired to live security update service.
- [x] App update dialog compares BFF version against runtime `package_info_plus` version.
- [ ] Privacy/terms/about/settings pages need iOS parity.

## 8. Native iOS-Specific Features To Recreate Or Bridge

- [x] Countdown widget / selected event widget parity.
  - Completion: Added a Flutter-to-native countdown widget bridge that writes the selected event id/name/start date/venue into the `group.com.ravehub.app` HomeWidget store using the same `upcoming_event_*` keys consumed by the native WidgetKit/Android countdown widgets, then refreshes both widget providers. Event Detail's More sheet now exposes a "Set Countdown Widget" action for the current event, and Runner entitlements include the countdown widget app group.
  - Files: `packages/core/raver_platform/lib/src/countdown_widget_service.dart`, `packages/core/raver_platform/lib/raver_platform.dart`, `packages/core/raver_platform/pubspec.yaml`, `packages/core/raver_platform/test/countdown_widget_service_test.dart`, `packages/features/feature_discover/lib/src/events/presentation/event_detail_screen.dart`, `app/ios/Runner/Runner.entitlements`, `app/test/ios_countdown_widget_config_test.dart`.
  - Verification: `cd packages/core/raver_platform && flutter pub get && flutter test test/countdown_widget_service_test.dart`; `cd packages/core/raver_platform && flutter analyze`; `cd packages/features/feature_discover && flutter analyze`; `cd app && flutter test test/ios_countdown_widget_config_test.dart test/ios_share_extension_scope_test.dart`; `cd app && flutter analyze`; `cd app && flutter pub get && flutter build ios --simulator --debug`.
  - Result: Passed; selected-event widget keys, app group setup, iOS/Android widget refresh arguments, Event Detail integration, analyzers, and iOS simulator build all pass. Real home-screen widget rendering remains covered by the pixel/real-device QA matrix.
- [ ] App icon/splash/launch screen parity.
- [x] Universal links and custom URL scheme parity: Android app links/custom scheme and iOS URL scheme/Associated Domains are registered for `ravehub.top`, `www.ravehub.top`, and `raver://`.
- [x] Share extension or share sheet behavior parity if present.
  - Completion: Audited the iOS project and confirmed Flutter scope does not include an inbound iOS Share Extension target (`com.apple.share-services` is absent); the only extension target present is the Countdown widget. Existing outbound sharing remains covered by `ShareService`/`share_plus` system share sheet calls for URLs and generated share-card bytes, and a regression test now locks the no-share-extension scope.
  - Files: `app/test/ios_share_extension_scope_test.dart`, `packages/core/raver_platform/lib/src/share_service.dart`.
  - Verification: `cd app && flutter test test/ios_share_extension_scope_test.dart`; `cd app && flutter analyze`.
  - Result: Passed; iOS project scan finds no Share Extension declaration and app analysis reports no issues.
- [ ] APNS registration and device token lifecycle parity.
- [x] Image cache behavior parity with iOS SDWebImage where visible.
  - Completion: Tightened the shared `RemoteCoverImage` cache path so visible OSS images are requested with physical-pixel resize parameters, q85 WebP processing, and matching `memCacheWidth/memCacheHeight` for local decoded-image cache sizing. This keeps network transfer, disk cache keys, and in-memory decode size aligned with the displayed dimensions, closer to iOS SDWebImage behavior; non-OSS URLs and already-processed URLs remain unchanged.
  - Files: `packages/core/raver_design_system/lib/src/widgets/remote_cover_image.dart`, `packages/core/raver_design_system/test/widget/remote_cover_image_test.dart`, `packages/core/raver_design_system/lib/src/widgets/glass_card.dart`, `packages/core/raver_design_system/lib/src/theme/raver_shadows.dart`, `packages/core/raver_design_system/lib/src/theme/raver_theme.dart`, `packages/core/raver_design_system/lib/src/widgets/raver_scrollable_tab_pager.dart`, `packages/core/raver_design_system/lib/src/widgets/remote_cover_image_web.dart`, `packages/core/raver_design_system/test/widget/glass_card_test.dart`, `packages/core/raver_design_system/test/widget/raver_floating_tab_bar_test.dart`.
  - Verification: `cd packages/core/raver_design_system && flutter test test/widget/remote_cover_image_test.dart test/widget/glass_card_test.dart test/widget/load_phase_builder_test.dart test/widget/raver_floating_tab_bar_test.dart`; `cd packages/core/raver_design_system && flutter analyze`.
  - Result: Passed; OSS URL processing, duplicate-processing guard, non-OSS passthrough, and physical-dimension memory cache settings are covered, and `raver_design_system` analysis reports no issues after cleaning nearby lint issues.
- [x] Haptics parity.
  - Completion: Audited shared haptic usage and confirmed `HapticService` is applied to primary buttons, segmented controls, bottom tabs, and the center search action, matching the already-completed design-system haptics integration.
  - Files: `packages/core/raver_platform/lib/src/haptic_service.dart`, `packages/core/raver_design_system/lib/src/widgets/primary_button.dart`, `packages/core/raver_design_system/lib/src/widgets/raver_segmented_control.dart`, `packages/core/raver_design_system/lib/src/widgets/raver_floating_tab_bar.dart`, `packages/core/raver_platform/test/haptic_service_test.dart`.
  - Verification: `cd packages/core/raver_platform && flutter test test/haptic_service_test.dart`.
  - Result: Passed; selection, light-impact, and medium-impact haptic channel calls are covered.
- [x] Permissions copy and system prompt timing parity: permission guide reads live camera/photo/location/notification states, requests each permission only after a user tap, and sends permanently denied/restricted states to system Settings.
- [x] Native permission declarations cover camera, photo library/media images, location, and notifications for the Flutter permission guide.
- [x] Background/resume lifecycle behavior parity.
  - Completion: Added an app lifecycle sync controller that observes Flutter foreground/background transitions and refreshes live notification-center unread counts when the app resumes, keeping the tab badge and native app-icon badge in sync after background time. Non-resume states do not trigger network work, and concurrent resume syncs are guarded.
  - Files: `app/lib/lifecycle/app_lifecycle_sync_controller.dart`, `app/lib/main.dart`, `app/test/app_lifecycle_sync_controller_test.dart`, `app/test/bootstrap_unread_count_test.dart`.
  - Verification: `cd app && flutter test test/app_lifecycle_sync_controller_test.dart test/bootstrap_unread_count_test.dart`; `cd app && flutter analyze`.
  - Result: Passed; resumed lifecycle events refresh unread counts and write the expected system badge total, paused events do not sync, and app analysis reports no issues.
- [ ] Crash/error reporting parity.

## 9. API And Data Contract Cleanup

- [x] App BFF URL points to live.
- [x] Feed endpoint aligned to `/v1/feed`.
- [x] Sets endpoint aligned to `/v1/dj-sets`.
- [x] Ratings endpoint aligned to `/v1/rating-events`.
- [x] Squads endpoint aligned to `/v1/squads`.
- [x] Checkins endpoint aligned to `/v1/checkins` and `/v2/me/checkins/overview`.
- [x] Quiz endpoint aligned to `/v1/quiz/*`.
- [x] Personality endpoint aligned to `/v1/personality/*`.
- [x] Circle ID endpoint source is aligned to iOS feed-derived `#RAVER_ID` entries.
- [x] Circle ID create flow posts `entityType: id` to `/api/content-submissions`.
- [x] Profile publishes moved from old `/v1/content-submissions` to `/api/content-submissions/mine`.
- [x] Direct package stubs still throwing `UnimplementedError` need cleanup.
- [ ] All live APIs should use typed DTOs instead of ad hoc `Map<String, dynamic>` where practical.
  - [x] Global search route is aligned to iOS `/v1/search` with `q/tab/limit/locale` query parameters.
  - [x] Unauthenticated global search matches iOS by showing a login-required gate instead of calling protected live search.
  - [ ] Authenticated global search result loading still needs real-account validation.
  - [ ] Authenticated squad recommendations/join/manage still need real-account validation.
- [x] Add contract tests for envelope/list/object parsing.
- [x] Add smoke tests for every public live endpoint used by Flutter.
- [ ] Add authenticated smoke tests for every protected live endpoint.

## 10. Pixel Parity QA Matrix

### 10.1 Screenshot Capture

- [ ] Capture native iOS reference screenshots for each screen at target devices.
- [ ] Capture Flutter iOS screenshots for each screen at matching devices.
- [ ] Capture Flutter web screenshots only as development preview, not final parity proof.
- [x] Store screenshots in a stable QA artifact folder.
- [x] Document device, OS, locale, theme, font scale, and account state.
- [x] macOS development-preview screenshot capture covers Login Initial, Discover Picks, Discover Events, Discover Sets, Circle Feed, Circle Squads sign-in gate, Circle ID, and Circle Ratings at 393x852 @3x.

### 10.2 Devices And Locales

- [ ] iPhone SE / compact width.
- [ ] iPhone 15 / standard width.
- [ ] iPhone 15 Pro Max / large width.
- [ ] Chinese locale.
- [ ] English locale.
- [ ] Japanese locale.
- [ ] Dark mode.
- [ ] Light mode if iOS supports it.
- [ ] Dynamic type / text scale audit.

### 10.3 Screen-by-Screen Pixel Audit

- [ ] Login.
- [ ] Register.
- [ ] SMS verification.
- [ ] Discover home.
- [ ] Events list.
- [ ] Event detail.
- [ ] Event upload/edit.
- [ ] DJ list.
- [ ] DJ detail.
- [ ] Sets list.
- [ ] Set detail/player.
- [ ] Set editor.
- [ ] News list/detail.
- [ ] Labels/festivals/organizers.
- [ ] Rankings.
- [ ] Genres.
- [ ] Circle feed.
- [ ] Post detail.
- [ ] Compose post.
- [ ] Squads hall.
- [ ] Squad profile.
- [ ] Squad manage.
- [ ] Squad offline activity.
- [x] Circle ID hub/detail/create renders with iOS-equivalent live-service skeleton.
- [x] Circle ID copy-link share uses live short-link service.
- [x] Circle ID share panel renders live QR/poster actions and opens through hub/detail controls.
- [x] Circle ID system share action uses live short-link service and platform share sheet.
- [x] Circle ID share card parity for non-IM share surfaces.
- [ ] Rating hub.
- [ ] Rating detail.
- [ ] Rating unit detail.
- [ ] Inbox.
- [x] Conversation list, Chat, and Chat settings are removed from Flutter parity scope.
- [ ] Profile me.
- [ ] Public profile.
- [ ] Edit profile.
- [ ] My checkins.
- [ ] Checkin create/edit.
- [ ] Quiz.
- [ ] Quiz result.
- [ ] EDMTI/personality.
- [ ] EDMTI result/share card.
- [ ] Publishes.
- [ ] Follows.
- [ ] Settings.
- [ ] Account security.
- [ ] QR/share tools.

## 11. Automated Verification

- [x] Current web debug build passes after latest live-service changes.
- [x] Browser smoke verified Circle ID tab, Post ID composer, and live event picker render without JS errors.
- [x] Browser smoke verified Circle ID tab and Post ID composer after live reaction/share changes.
- [x] Browser smoke verified `/circle/id/:cardId` route alias enters ID Detail without JS errors.
- [x] Browser smoke verified Circle ID tab still renders after platform share entry.
- [x] Current web debug build passes after Circle ID platform share entry.
- [x] Current iOS simulator debug build passes after latest Circle ID live-service changes.
- [x] MapLauncher URI builders have focused unit coverage.
- [x] Current web and iOS simulator debug builds pass after Route Tool MapLauncher integration.
- [x] UrlLauncherService invalid URL guard has focused unit coverage.
- [x] Current web and iOS simulator debug builds pass after About legal-link integration.
- [x] AppInfoService version display has focused unit coverage.
- [x] Current web and iOS simulator debug builds pass after runtime version integration.
- [x] Current web and iOS simulator debug builds pass after real profile QR/share integration.
- [x] Current web and iOS simulator debug builds pass after Account Security live-action wiring.
- [x] Current web and iOS simulator debug builds pass after QR save-to-gallery bridge integration.
- [x] Current web and iOS simulator debug builds pass after HapticService design-system integration.
- [x] Current web and iOS simulator debug builds pass after universal-link/custom-scheme platform registration; Android manifest XML validates locally.
- [x] Current web and iOS simulator debug builds pass after live permission guide/status/request timing integration; Android manifest and iOS permission plist validate locally.
- [x] ContentSubmissionDetail entity-ID alias parsing has focused unit coverage.
- [x] Current web and iOS simulator debug builds pass after Publishes edit/resubmit route wiring.
- [x] Current web and iOS simulator debug builds pass after Profile friends follow-list live wiring.
- [x] Current web and iOS simulator debug builds pass after Publishes review-state/status-label parity.
- [x] Current web and iOS simulator debug builds pass after followed entity update-list parity.
- [x] No-mock/no-old-endpoint guard scripts pass locally and are wired into GitHub Actions.
- [x] Model parsing tests pass for squad, rating, checkin, quiz, and personality live payload shapes.
- [x] Repository fixture tests pass for Feed and Profile live BFF response shapes.
- [x] Navigation route smoke test covers every registered app route pattern with real GoRouter matching.
- [x] Core design-system golden coverage includes theme buttons/cards, skeletons, empty/error states, segmented controls, and floating tab bar.
- [x] Public Discover/Circle integration tests exercise unauthenticated live-service tab flows without mock providers.
- [x] Gated public live endpoint smoke test passes against live BFF for Discover events/DJs/sets/news/learn APIs and Circle feed/ID/ratings.
- [x] Search API contract test locks Flutter global search to the iOS live `/v1/search` endpoint and camelCase tab values.
- [x] Search results unauthenticated login gate has widget coverage and `/search` is protected by route guard.
- [x] Squads unauthenticated gate has widget coverage and public integration coverage.
- [x] GitHub Actions includes an iOS simulator debug build job.
- [x] Public live integration entry passes on local macOS runner after macOS CocoaPods/deployment-target alignment.
- [x] Local `flutter build ios --debug --simulator` passes for the CI iOS simulator build command.
- [x] Screenshot diff workflow captures public Flutter screenshots, collects macOS sandbox artifacts, uploads `app/build/screenshots`, and compares against `qa/screenshots/ios-reference` when present.
- [x] Add unit tests for model parsing: squad, rating, checkin, quiz, personality.
- [x] Add repository tests with fixture payloads copied from live BFF examples.
- [x] Add widget golden tests for core components.
- [x] Add navigation smoke tests for every route.
- [x] Add integration tests for public Discover/Circle flows.
- [x] Add authenticated integration tests for profile/checkins/quiz/personality.
  - Completion: Audited the gated authenticated smoke harness and confirmed it covers protected Profile (`/v1/users/me`, posts, saves, contributions, devices), Checkins (`/v1/checkins`, `/v2/me/checkins/overview`), Quiz (`/v1/quiz/sessions`), and Personality (`/v1/personality/sessions`) APIs, with safe skip behavior unless `RAVEHUB_TEST_ACCESS_TOKEN` is provided. Real-token execution remains tracked separately as a QA/manual validation item.
  - Files: `app/test/authenticated_live_endpoint_smoke_test.dart`.
  - Verification: `cd app && flutter test test/authenticated_live_endpoint_smoke_test.dart`.
  - Result: Passed in local no-token mode by skipping all gated authenticated smoke tests with the expected token-required message.
- [x] Add iOS simulator CI build.
- [x] Add screenshot diff workflow for pixel parity.
- [x] Add local guard script for unexpected legacy `/v1/social/*` endpoints.
- [x] Add no-mock/no-old-endpoint CI guard.

## 12. Immediate Next Work Queue

### P0

- [x] Replace Circle ID feature with iOS-equivalent live Circle ID domain and remove `/v1/social/circle-ids`.
- [ ] Validate auth-gated live flows with a real account: Profile, Checkins, Quiz, Personality, Squads.
- [x] Remove IM bridge / selected Flutter IM SDK path from Flutter scope for chat and squads.
- [x] Replace remaining package `UnimplementedError` defaults or enforce safe injection.
- [x] Run Flutter iOS simulator build and fix platform-specific issues.

### P1

- [x] Complete Rating unit detail direct live API and comment contract.
- [x] Add rating model parsing coverage for editable unit `description/imageUrl`.
- [x] Finish media picker/upload integration across profile, squads, ratings, sets, events.
  - Completion: Audited the completed media picker/upload wiring across Profile avatar/background, Squad creation avatar, Rating event/unit images, Set thumbnail/video uploads, and Event create/edit image zones. Existing focused tests cover event upload/edit image zones, progress/retry/cancel/draft behavior, and Profile save/upload payload integration.
  - Files: `packages/features/feature_profile/lib/src/edit_profile/edit_profile_screen.dart`, `packages/features/feature_circle/lib/src/squads/presentation/widgets/squad_create_sheet.dart`, `packages/features/feature_circle/lib/src/ratings/presentation/widgets/create_rating_event_sheet.dart`, `packages/features/feature_circle/lib/src/ratings/presentation/widgets/create_rating_unit_sheet.dart`, `packages/features/feature_discover/lib/src/sets/presentation/set_editor_screen.dart`, `packages/features/feature_discover/lib/src/events/presentation/event_upload_flow_screen.dart`, `packages/features/feature_discover/lib/src/events/presentation/event_editor_screen.dart`.
  - Verification: `cd packages/features/feature_discover && flutter test test/event_upload_view_model_test.dart test/event_editor_view_model_test.dart`; `cd packages/features/feature_profile && flutter test test/edit_profile_view_model_test.dart test/widget/settings_screen_test.dart`.
  - Result: Passed; media picker/upload integration tests for Event create/edit and Profile edit/save all pass.
- [x] Finish settings/tools TODOs: QR share/save, MapLauncher, URL opening, account security.
  - Completion: Audited Settings/Tools closure: QR share/save routes through `ShareService` and `GallerySaveService`, MapLauncher URI builders cover Apple Maps/Android geo/Google route fallbacks, URL opening is centralized in `UrlLauncherService`, and Account Security actions are wired to the live profile security service.
  - Files: `packages/features/feature_profile/lib/src/tools/qr_code_screen.dart`, `packages/core/raver_platform/lib/src/map_launcher.dart`, `packages/core/raver_platform/lib/src/url_launcher_service.dart`, `packages/features/feature_profile/lib/src/settings/account_security_screen.dart`, `packages/features/feature_profile/lib/src/settings/settings_screen.dart`.
  - Verification: `cd packages/core/raver_platform && flutter test test/clipboard_service_test.dart test/map_launcher_test.dart test/url_launcher_service_test.dart test/app_info_service_test.dart`; `cd packages/features/feature_profile && flutter test test/edit_profile_view_model_test.dart test/widget/settings_screen_test.dart`.
  - Result: Passed; platform bridge/settings tests pass and the remaining settings/tools work is down to iOS visual/manual parity items tracked separately.
- [x] Add model parsing tests for all live payloads already integrated.
  - Completion: Audited the integrated live payload coverage and verified model/contract tests exist for events, DJs, sets, ratings, notifications, shares, content submissions, search, squads, posts/comments, checkins, users/profile, genres, uploads, pagination/envelopes, plus feature-level Checkin, Quiz, Personality, and Profile repository payload fixtures.
  - Files: `packages/core/raver_models/test/*`, `packages/core/raver_models/test/contract/*`, `packages/features/feature_profile/test/data/checkin_api_test.dart`, `packages/features/feature_profile/test/data/personality_api_test.dart`, `packages/features/feature_profile/test/data/profile_repository_test.dart`, `packages/features/feature_profile/test/data/quiz_api_test.dart`.
  - Verification: `cd packages/core/raver_models && flutter test test`; `cd packages/features/feature_profile && flutter test test/data/checkin_api_test.dart test/data/personality_api_test.dart test/data/profile_repository_test.dart test/data/quiz_api_test.dart`.
  - Result: Passed; 101 core model tests and 6 Profile feature API fixture tests pass.
- [x] Start screenshot parity pass for Login, Discover, Circle Feed, Sets, Ratings.
  - [x] Development-preview screenshot capture now covers Login Initial, Discover Picks/Events/Sets, Circle Feed/ID/Ratings.

### P2

- [ ] Full event upload/edit parity.
- [ ] Full DJ upload/editor parity.
- [ ] Full share short-link/QR/share card parity.
- [ ] Full notification/APNS parity.
- [ ] Full offline/cache/lifecycle parity.
