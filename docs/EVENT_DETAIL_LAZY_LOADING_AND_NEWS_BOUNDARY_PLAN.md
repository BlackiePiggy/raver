# Event Detail Lazy Loading and News Boundary Plan

## Goal

Reduce event detail page latency by loading only first-screen essentials on entry, lazy-loading each subtab on demand, and separating user posts from Raver News so event discussion and festival/news viewers use the correct data source.

## Current Findings

- [x] Confirmed `/v1/events/:id` is the public event-detail payload.
- [x] Confirmed `/v1/events/:id/favorite` is per-user state keyed by authenticated `userId + eventId`, not public mutable event data.
- [x] Confirmed event detail currently starts several parallel requests on entry: event detail, favorite status, checkins, rating events, related DJ sets, and related news.
- [x] Confirmed related news currently calls `fetchDiscoverNewsArticles(maxPages: 8)`, which pulls global `/v1/feed?mode=latest` pages and filters client-side.
- [x] Confirmed this client-side news lookup causes repeated global feed requests such as `/v1/feed?limit=12&cursor=...&mode=latest`.
- [x] Confirmed festival viewer news can miss articles because it only scans the first `maxPages` of global feed before filtering by `boundBrandIDs`.
- [x] Confirmed event discussion should contain user-created posts tagged/bound to that event, not Raver News posts.

## Target Behavior

- [x] Entering an event detail page loads only first-screen essentials.
- [x] Each event detail subtab loads its own data only when the user opens that tab.
- [x] Event discussion tab loads only user posts bound/tagged to the current event.
- [x] Event discussion tab excludes Raver News posts.
- [x] Event discussion pagination loads one page at a time and only after the user explicitly requests more.
- [x] News tab loads Raver News through a dedicated news-bound query, not by scanning global feed.
- [x] Festival viewer loads relevant bound news through the same dedicated news-bound query.
- [x] Related DJ sets for an event are loaded only when the Sets tab is opened.
- [x] Rating events for an event are loaded only when the Ratings tab is opened.

## Request Classification

### Required On Entry

- [x] `GET /v1/events/:id`
  - Purpose: load event title, time, venue, media, lineup, schedule, and base detail data.
  - Keep on entry.

- [x] `GET /v1/events/:id/favorite`
  - Purpose: load current user's favorite status for this event.
  - Keep on entry only when user is logged in.
  - Must continue to use authenticated user from token, never a frontend-provided `userId`.

### Optional On Entry

- [x] `GET /v1/checkins?page=1&limit=100&eventId=:id`
  - Purpose: load current user's checkins related to this event.
  - Decide whether this is needed in the first visible tab.
  - If not visible on first screen, move to lazy loading.
  - Reduce `limit=100` if first screen needs only a compact status.

### Lazy-Load By Tab

- [x] `GET /v1/events/:id/rating-events`
  - Purpose: load rating events/scorecards for this event.
  - Load only when Ratings tab opens.

- [x] `GET /v1/dj-sets?...&eventName=...`
  - Purpose: load related DJ sets.
  - Load only when Sets tab opens.
  - Replace event-name matching with event-id binding if backend data supports it.

- [x] `GET /v1/feed?limit=12&mode=latest&eventID=:id`
  - Purpose: load event discussion posts.
  - Load only when Posts/Discussion tab opens.
  - Backend must exclude Raver News from this event discussion result.

- [x] Dedicated news-bound endpoint
  - Purpose: load news bound to an event, DJ, or festival.
  - Load only when News tab opens or festival viewer news section opens.

### Should Not Happen On Event Entry

- [x] `GET /v1/feed?limit=12&mode=latest`
  - This is global latest feed and should not run because an event detail page opened.

- [x] `GET /v1/feed?limit=12&cursor=...&mode=latest`
  - This is global feed pagination and should not be used to discover event/festival news.

- [x] Notification summary refreshes
  - Examples:
    - `/v1/notification-center/inbox/unread-count`
    - `/v1/notification-center/followed-djs/summary`
    - `/v1/notification-center/followed-events/summary`
    - `/v1/notification-center/followed-brands/summary`
  - These should not be triggered solely by opening event detail.

- [x] Push token upload
  - `/v1/notification-center/push-tokens`
  - Should run on login, token change, app launch, or foreground refresh policy, not event page entry.

## Backend Work

### Feed Boundary

- [x] Audit `/v1/feed` event filter behavior.
- [x] Ensure `eventID` filter returns posts with `eventId == eventID` or `boundEventIds has eventID`.
- [x] Ensure event discussion feed excludes Raver News posts.
- [x] Add an explicit query option if needed, for example `includeNews=false` or `contentKind=post`.
- [x] Confirm `mapPost` still returns enough fields for normal user post rendering after news exclusion.
- [x] Add/verify indexes for event-bound post lookup:
  - [x] `Post.eventId`
  - [x] `Post.boundEventIds` strategy if array queries are used.
  - [x] `Post.createdAt` ordering.

### Dedicated News-Bound Query

- [x] Add a backend endpoint for bound news lookup.
- [x] Proposed endpoint:

```text
GET /v1/news/bound?eventID=:id
GET /v1/news/bound?djID=:id
GET /v1/news/bound?festivalID=:id
```

- [x] Endpoint must query dedicated `news_articles`, not global feed pages or encoded post content.
- [x] Endpoint must support pagination:
  - [x] `limit`
  - [x] `cursor`
- [x] Endpoint must return only News articles.
- [x] Endpoint must filter by:
  - [x] `boundEventIds` for event news.
  - [x] `boundDjIDs` for DJ news.
  - [x] `boundBrandIDs` for festival/brand news.
- [x] Add response shape usable by iOS `DiscoverNewsArticle`.
- [x] Add server-side limit bounds to avoid oversized responses.
- [ ] Add tests or smoke checks for event, DJ, and festival news queries.

### News Content Type Boundary

- [x] Treat `Post` and `News` as different backend content types.
- [x] Add dedicated Prisma model/table for News: `NewsArticle` / `news_articles`.
- [x] Add `User.newsArticles` relation instead of storing news under `User.posts`.
- [x] Add dedicated News endpoints:
  - [x] `GET /v1/news`
  - [x] `GET /v1/news/search`
  - [x] `GET /v1/news/bound`
  - [x] `GET /v1/news/:id`
  - [x] `POST /v1/news`
- [x] Update approved news submissions to create `NewsArticle`, not `Post`.
- [x] Update global search news results to query `NewsArticle`, not `Post + #RAVER_NEWS`.
- [x] Reject new `#RAVER_NEWS` submissions through `/v1/feed/posts`; news must use `/v1/news`.
- [x] Update iOS Discover News repository to load/search/publish News through dedicated news APIs.
- [x] Keep legacy `#RAVER_NEWS` decoder only for local mock/compatibility seed data, not production backend news flow.
- [x] Add dedicated News comments/replies model and API before re-enabling commenting on News detail.
  - Implemented `NewsComment` / `news_comments`.
  - Added dedicated `GET /v1/news/:id/comments` and `POST /v1/news/:id/comments`.
  - iOS News detail comments now call News comment APIs instead of Post comment APIs.

### Related DJ Sets

- [x] Audit current event-related DJ set lookup by `eventName`.
- [x] Prefer event-id based binding if schema has a relation.
  - Result: added nullable `DJSet.eventId` relation to `Event`; existing rows intentionally remain empty until manually populated.
- [x] If schema does not have a relation, create a separate plan item before changing data model.
  - Follow-up plan: manually populate `DJSet.eventId` for existing rows as needed. Legacy `eventName` fallback remains available during transition.
- [x] Keep Sets tab lazy-loaded regardless of lookup strategy.

### Observability

- [x] Add temporary timing logs around event detail related data loaders if needed.
- [ ] Log endpoint, user id, event id, and duration without logging tokens.
- [ ] Remove or lower verbosity after optimization is verified.

## iOS Work

### Event Detail Entry Load

- [x] Update `EventDetailView.load()` to load only:
  - [x] event detail.
  - [x] favorite status when logged in.
  - [x] checkin status used by the first info/checkin controls.
- [x] Remove eager `ratingEventsTask` from entry load.
- [x] Remove eager `relatedArticlesTask` from entry load.
- [x] Remove eager `fetchEventDJSets` from entry load.
- [x] Keep offline/manual cache behavior working after lazy-loading changes.

### Per-Tab Lazy Loading

- [x] Add per-tab loaded/loading state flags:
  - [x] Posts/discussion loaded.
  - [x] News loaded.
  - [x] Ratings loaded.
  - [x] Sets loaded.
  - [x] Checkins loaded if moved off entry.
- [x] Trigger tab data load when `selectedTab` changes.
- [x] Ensure initial tab can load its own data if the deep link opens a non-info tab.
- [x] Avoid duplicate loads while a request is in flight.
- [x] Keep pull-to-refresh scoped to the current tab where possible.

### Event Discussion Posts

- [x] Ensure discussion tab calls `fetchFeed(cursor:mode:eventID:)` with the current `eventID`.
- [x] Ensure the final request URL includes `eventID`.
- [x] Filter out `post.isRaverNews` on iOS as a defensive fallback.
- [x] Stop automatic multi-page pagination on first render.
- [x] Replace `onAppear` last-row pagination with a safer threshold or explicit guard:
  - [x] Do not load more while the tab is not selected.
  - [x] Do not load more until first page has visibly rendered.
  - [x] Do not load more when content height is shorter than viewport unless user explicitly requests more.

### News Loading

- [x] Replace `fetchDiscoverNewsArticles(maxPages:)` usage for bound news with backend dedicated endpoint.
- [x] Update `fetchArticlesBoundToEvent`.
- [x] Update `fetchArticlesBoundToDJ`.
- [x] Update `fetchArticlesBoundToFestival`.
- [x] Keep global news feed page behavior separate from bound news behavior.
- [x] Ensure festival viewer can page through bound news instead of seeing only the first few found in global feed.

### Global Refresh Containment

- [x] Audit `refreshUnreadMessages()` callers.
- [x] Audit `uploadPushTokenIfPossible()` callers.
- [x] Ensure opening event detail does not trigger notification summary refresh unless explicitly required.
- [x] Ensure opening event detail does not trigger push token upload.

## Verification Plan

### Local API Checks

- [x] Event entry should not call global feed:

```text
/v1/feed?limit=12&mode=latest
```

- [x] Event entry should not call global feed pagination:

```text
/v1/feed?limit=12&cursor=...&mode=latest
```

- [x] Discussion tab should call event-scoped feed:

```text
/v1/feed?limit=12&mode=latest&eventID=:id
```

- [x] News tab should call dedicated news-bound endpoint.
- [x] Ratings tab should call `/v1/events/:id/rating-events` only when opened.
- [x] Sets tab should call related sets only when opened.

### iOS Behavior Checks

- [ ] Open event detail on default Info tab.
- [ ] Confirm first screen appears after event detail and favorite status load.
- [ ] Confirm no global feed pagination happens during initial entry.
- [ ] Swipe to Posts tab and confirm one event-scoped page loads.
- [ ] Scroll Posts tab and confirm next page loads only once near the end.
- [ ] Confirm Posts tab contains user posts only, not Raver News.
- [ ] Swipe to News tab and confirm bound news loads.
- [ ] Open festival viewer and confirm more than the previously visible two news items can appear when data exists.

### Performance Checks

- [ ] Compare server logs before/after event detail entry.
- [x] Target initial event detail entry request count:
  - [ ] 2 required requests.
  - [x] 3 if checkin status remains first-screen.
- [x] Target no global feed requests on event entry.
- [x] Target no multi-page feed cascade on event entry.
- [ ] Record representative timings from server logs after change.

## Open Questions

- [x] Should event checkin status appear in the first Info tab, or can it move to a later section?
- [x] Is there an existing event-id relation for DJ sets, or do we need to add one?
  - Answer: no relation existed originally; `DJSet.eventId` nullable FK is now added with no automatic backfill.
- [x] Should News be a distinct backend content type long-term instead of encoded Raver News posts?
  - Answer: yes. `Post` is post, `News` is news; production backend news flow now uses `news_articles`.
- [ ] Should notification summaries be consolidated into a single endpoint separately from this event-detail work?

## Progress Log

- [x] 2026-05-17: Identified event detail request fan-out and global feed pagination cascade.
- [x] 2026-05-17: Identified client-side news lookup via global feed scan as root cause for both slow event detail entry and incomplete festival viewer news.
- [x] 2026-05-17: Added `/v1/news/bound` for event/DJ/festival-bound Raver News with cursor pagination.
- [x] 2026-05-17: Updated event-scoped `/v1/feed` to exclude `#RAVER_NEWS`.
- [x] 2026-05-17: Updated iOS event detail to lazy-load Posts, News, Ratings, and Sets by selected tab.
- [x] 2026-05-17: Replaced bound-news global feed scans with dedicated backend calls for event, DJ, and festival contexts.
- [x] 2026-05-17: Replaced first-render discussion auto-pagination with explicit load-more behavior.
- [x] 2026-05-17: Added post binding indexes for event discussion and bound-news queries.
- [x] 2026-05-17: Verified with `pnpm prisma validate`, `pnpm build`, and iOS simulator Debug `xcodebuild`.
- [x] 2026-05-17: Audited related DJ set lookup. Current schema uses `DJSet.eventName`; event-id binding requires a separate data-model migration/backfill plan.
- [x] 2026-05-17: Added nullable strong `DJSet.eventId -> Event.id` relation, exposed it through DJ set APIs and iOS models, and switched event detail set lookup to send `eventID` with `eventName` fallback. Existing rows stay NULL for manual assignment.
- [x] 2026-05-17: Verified DJ set event relation changes with `pnpm prisma generate`, `pnpm prisma validate`, `pnpm build`, and iOS simulator Debug `xcodebuild`.
- [x] 2026-05-17: Added dedicated `NewsArticle` backend content type, migration, `/v1/news*` BFF endpoints, content-submission creation path, and global-search news query.
- [x] 2026-05-17: Updated iOS Discover News to use dedicated news APIs instead of encoding Raver News into `Post` content.
- [x] 2026-05-17: Verified News content-type separation with `pnpm prisma generate`, `pnpm prisma validate`, `pnpm build`, and iOS simulator Debug `xcodebuild`.
- [x] 2026-05-17: Added dedicated `NewsComment` backend content type and `/v1/news/:id/comments` APIs, then reconnected iOS News detail comments to those dedicated endpoints.
- [x] 2026-05-17: Verified News comment separation with `pnpm prisma generate`, `pnpm prisma validate`, `pnpm build`, and iOS simulator Debug `xcodebuild`.
