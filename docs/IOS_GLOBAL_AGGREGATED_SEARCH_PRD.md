# iOS Global Aggregated Search PRD and Technical Breakdown

## 1. Background

Raver currently has several separate search capabilities inside Discover-related modules, including events, news, DJs, sets, labels, festivals, and rankings. These searches are mostly entered from their own modules and return results in domain-specific pages.

The next step is to build a global aggregated search entry on the iOS home tab bar. Users should be able to search one keyword and discover related content across the app, excluding chat message history. The feature should become the primary app-wide discovery entry for logged-in users.

## 2. Goals

1. Add a global search button in the bottom tab bar between Circle and Messages.
2. Show a blur overlay on the current screen when the user taps the search button.
3. Provide one search input that can search across multiple content domains.
4. Show recently searched keywords and searchable scope hints before search.
5. Show search results in a dedicated result page with tabs for different result types.
6. Use relevance-first ranking as the default sorting strategy.
7. Require login before using global search.
8. Do not include chat module message-history search.

## 3. Non-Goals

1. Do not search chat message history.
2. Do not search comments for posts, rating units, rating events, news, sets, or events.
3. Do not implement real-time search suggestions in the first version.
4. Do not implement a full search engine such as Elasticsearch or Meilisearch in the first version unless backend performance requires it.
5. Do not block the whole result page if one domain fails. Domain-level fallback is required.

## 4. Search Scope

The global search should include the following domains:

| Domain | Search Objects | Comment Search | Result Tab |
| --- | --- | --- | --- |
| Events | Events | No | Events |
| News | News articles / Raver news posts | No | News |
| DJs | DJ profiles | No | DJs |
| Sets | DJ sets | No | Sets |
| Rankings | Ranking boards and ranking entries if available | No | Rankings |
| Ratings | Rating events and rating units | No | Ratings |
| Circle Posts | Circle feed posts | No comments | Posts |
| Users | Public user profiles | No | People & Squads |
| Squads | Public squads | No messages | People & Squads |
| Festivals | Festival / brand wiki records | No | Festivals (Brand) |
| Labels | Label wiki records | No | Labels |
| Genre Tree | Genre taxonomy records | No | Genre Tree |

Recommended result tabs:

1. All
2. Events
3. DJs
4. User & Team
5. Posts
6. News
7. Sets
8. Rankings
9. Ratings
10. Festivals (Brand)
11. Labels
12. Genre Tree

The exact tab labels can be localized:

| Key | Chinese | English |
| --- | --- | --- |
| all | 全部 | All |
| events | 活动 | Events |
| djs | DJ | DJs |
| peopleSquads | 用户/小队 | User & Team |
| posts | 圈子 | Posts |
| news | 资讯 | News |
| sets | Sets | Sets |
| rankings | 榜单 | Rankings |
| ratings | 打分 | Ratings |
| festivals | 音乐节(品牌) | Festivals (Brand) |
| labels | 厂牌 | Labels |
| genreTree | 风格树 | Genre Tree |

## 5. User Entry

### 5.1 Bottom Tab Bar Button

Current tab bar:

```text
Discover | Circle | Messages | Me
```

Target tab bar:

```text
Discover | Circle | Search | Messages | Me
```

Search is not a real tab. It is an action button.

Placement and style:

1. Position: between Circle and Messages.
2. Shape: circular button.
3. Background: purple accent, consistent with Raver theme.
4. Icon: system `magnifyingglass`, white.
5. Size: recommended 56 x 56 pt.
6. Visual treatment: slightly raised above the capsule tab bar, with shadow and pressed animation.
7. Accessibility identifier: `mainTab.action.globalSearch`.
8. Accessibility label: `搜索` / `Search`.

Behavior:

1. If user is logged in, open global search overlay.
2. If user is logged out, route to login or show login-required prompt.
3. The selected tab does not change when tapping search.
4. The current tab content remains mounted behind the blur overlay.

## 6. Login Requirement

Global search requires login.

Recommended first-version behavior:

1. Tap Search while logged out.
2. Present a login-required sheet or route to existing login flow.
3. After successful login, return to the previous tab.
4. User taps Search again to open search overlay.

Optional later enhancement:

1. Store a pending action `openGlobalSearchAfterLogin`.
2. Automatically open search overlay after successful login.

Acceptance criteria:

1. Logged-out users cannot access global search overlay or result page.
2. Deep links to global search result page should also enforce login.
3. Unauthorized API responses should return a consistent auth error.

## 7. Search Overlay PRD

### 7.1 Trigger

User taps the global Search button in the bottom tab bar.

### 7.2 Visual Design

Overlay covers the current screen.

Recommended layout:

1. Full-screen dim layer with blur:
   - Use `.ultraThinMaterial` or custom blur.
   - Add dark opacity layer if needed for text contrast.
2. Search panel:
   - Appears from bottom or fades/scales in from the search button.
   - Top section contains search field.
   - Below search field shows recent searches and scope hints.
3. Dismiss:
   - Tap cancel button.
   - Tap outside panel.
   - Swipe down.
   - Escape/back if applicable.

The overlay should feel like a fast command palette, not a full page.

### 7.3 Search Field

Fields:

1. Placeholder:
   - Chinese: `搜索活动、资讯、DJ、Sets、榜单、打分、圈子内容`
   - English: `Search events, news, DJs, sets, rankings, ratings, posts`
2. Submit button:
   - Keyboard return key: Search.
   - Optional visible action button: `搜索`.
3. Minimum query:
   - Trim whitespace.
   - Minimum 1 non-whitespace character.
   - Recommended production rule: 2 characters for Latin-only input, 1 character for CJK.

No real-time suggestions in V1.

### 7.4 Recent Searches

Show recent searches before the user submits a query.

Rules:

1. Store locally on device.
2. Only store after a successful submit.
3. Max 10 recent keywords.
4. Most recent first.
5. De-duplicate case-insensitively after trimming.
6. Provide clear-all action.
7. Tapping a recent keyword submits search immediately.

Suggested storage:

1. `UserDefaults` for V1.
2. Key: `globalSearch.recentQueries.v1`.
3. Later migration to local database if search history grows richer.

### 7.5 Searchable Scope Hints

Show fixed chips explaining what can be searched:

1. 活动 / Events
2. 资讯 / News
3. DJ
4. Sets
5. 榜单 / Rankings
6. 打分 / Ratings
7. 圈子 / Posts
8. Wiki
9. 用户/小队 / People & Squads

These chips are informational in V1. They do not filter the first search unless the product later chooses to support scope preselection.

### 7.6 Future Hot Searches

Reserve a section for hot searches, but do not require backend implementation in V1.

Future behavior:

1. Backend returns trending queries.
2. Show 5-10 hot terms.
3. Tapping a term submits search.
4. Hot searches should be region/language-aware later.

## 8. Search Result Page PRD

### 8.1 Route

Recommended app-level route:

```swift
case globalSearchResults(query: String, initialTab: GlobalSearchTab?)
```

This should live under `AppRoute`, not `DiscoverRoute`, because the entry is global and includes Circle, users, and squads.

### 8.2 Layout

Top to bottom:

1. Navigation bar:
   - Title: `搜索` / `Search`.
   - Back button.
2. Sticky search field:
   - Shows current query.
   - Tapping field reopens the search overlay or edits inline.
   - Search submit refreshes result page with new query.
3. Tab row:
   - Horizontally scrollable.
   - Shows count badge where available.
4. Content area:
   - Uses selected tab.
   - Pull to refresh.
   - Domain-level loading, empty, and error states.

### 8.3 All Tab Design

The All tab is the most important design surface. It should help users quickly understand what exists across the app without forcing them to choose a category first.

Recommended All tab layout:

1. Result summary strip:
   - Text: `找到与 “{query}” 相关的内容`
   - Show total count if backend can provide it.
   - If partial failures exist, show a small warning banner: `部分结果暂时不可用`.

2. Top matches section:
   - Title: `最佳匹配` / `Top Matches`.
   - Show 3-5 mixed results across domains.
   - Ranking is relevance-first.
   - Each item must show domain badge.
   - Purpose: answer "what is probably the thing the user meant?"

3. Domain preview sections:
   - Show sections only when the domain has results.
   - Recommended order for V1:
     1. Events
     2. DJs
     3. News
     4. Sets
     5. Ratings
     6. Posts
     7. Rankings
     8. Wiki
     9. People & Squads
   - Each section shows max 3 items.
   - Each section has `查看全部` / `View All` when result count > 3.
   - Tapping `View All` switches to that tab.

4. Empty state:
   - If no domain has results:
     - Title: `没有找到相关内容`
     - Message: `换个关键词试试，比如 DJ 名称、活动城市、厂牌或榜单名称。`
   - Show searchable scope chips below empty state.

5. Partial failure state:
   - If at least one domain succeeded, keep showing successful sections.
   - Show compact domain error row at bottom:
     - `打分结果加载失败，点此重试`
   - Do not replace the whole All tab with a failure screen.

### 8.4 Domain Tabs

Each domain tab should provide full result browsing.

Common behavior:

1. Initial loading skeleton.
2. Empty state.
3. Error state with retry.
4. Pull to refresh.
5. Pagination if backend supports it.
6. Result count badge.

Tab-specific notes:

#### Events

Search fields:

1. Event name.
2. Description.
3. City.
4. Country.
5. Venue.
6. Lineup DJ names if backend can support it.

Card should show:

1. Cover image.
2. Event name.
3. Date.
4. City/venue.
5. Status badge.

Tap route:

```swift
.eventDetail(eventID: id)
```

#### News

Search fields:

1. Title.
2. Summary.
3. Source.
4. Bound event/DJ/festival names if available.

Card should show:

1. Cover image if available.
2. Headline.
3. Source.
4. Publish date.
5. Summary snippet.

Tap route:

```swift
.newsDetail(articleID: id)
```

#### DJs

Search fields:

1. Name.
2. Alias.
3. Bio.
4. Genres.
5. Country.

Card should show:

1. Avatar.
2. DJ name.
3. Genres.
4. Follower count or popularity signal if available.

Tap route:

```swift
.djDetail(djID: id)
```

#### Sets

Search fields:

1. Set title.
2. DJ name.
3. Event name.
4. Description if available.
5. Tracklist text later, not required in V1.

Card should show:

1. Thumbnail.
2. Set title.
3. DJ name.
4. Event name if available.
5. Duration/date if available.

Tap route:

```swift
.setDetail(setID: id)
```

#### Rankings

Search objects:

1. Ranking boards.
2. Ranking entries if backend can search entries.

Search fields:

1. Board title.
2. Board subtitle.
3. Entry DJ/festival name.
4. Year.

Card should show:

1. Board cover.
2. Board title.
3. Year.
4. Matched entry preview if result came from entry.

Tap route:

```swift
.rankingBoardDetail(board: board, year: year)
```

#### Ratings

Search objects:

1. Rating events.
2. Rating units.

Do not search rating comments.

Search fields:

1. Rating event name.
2. Rating event description.
3. Rating unit name.
4. Rating unit description.
5. Linked event/DJ name if available.

Card should show:

1. Type badge: `打分活动` or `打分单位`.
2. Title.
3. Linked event or parent rating event.
4. Average score / comment count if available.

Tap routes:

```swift
.ratingEventDetail(eventID: id)
.ratingUnitDetail(unitID: id)
```

#### Posts

Search objects:

1. Circle feed posts.

Do not search comments.

Search fields:

1. Post text.
2. Author display name.
3. Bound event/DJ/set/rating card metadata if available.

Card should show:

1. Author.
2. Text snippet.
3. First image/video thumbnail if available.
4. Like/comment/repost counts.
5. Domain badge: `圈子`.

Tap route:

```swift
.postDetail(postID: id)
```

#### Wiki

Search objects:

1. Labels.
2. Festivals.

Search fields:

1. Label name.
2. Label introduction.
3. Festival name.
4. Festival city/country.
5. Genre.

Tap routes:

```swift
.labelDetail(labelID: id)
.festivalDetail(festivalID: id)
```

#### People & Squads

Search objects:

1. Users.
2. Squads.

Search fields:

Users:

1. Display name.
2. Username.
3. Bio if available.

Squads:

1. Squad name.
2. Description.
3. Tags if available.

Card should show:

1. Separate subsections inside tab: `用户` and `小队`.
2. User row: avatar, display name, username.
3. Squad row: avatar/cover, name, member count, public/private badge if relevant.

Tap routes:

```swift
.userProfile(userID: id)
.squadProfile(squadID: id)
```

## 9. Relevance Ranking

V1 ranking should be simple, deterministic, and easy to change later.

### 9.1 Match Signals

Recommended scoring:

| Signal | Score |
| --- | --- |
| Exact title/name match | +100 |
| Title/name starts with query | +80 |
| Title/name contains query | +60 |
| Alias/username contains query | +45 |
| Description/summary contains query | +25 |
| Related entity name contains query | +35 |
| Recent content boost | +0-20 |
| Popularity boost | +0-20 |
| Followed/owned content boost for logged-in user | +0-15 |

Normalize score to a `relevanceScore` number in backend response.

### 9.2 Domain Weight

Default domain weights for All tab top matches:

| Domain | Weight |
| --- | --- |
| Events | 1.08 |
| DJs | 1.06 |
| News | 1.00 |
| Sets | 0.98 |
| Ratings | 0.96 |
| Posts | 0.94 |
| Rankings | 0.92 |
| Wiki | 0.90 |
| Users/Squads | 0.88 |

These are initial values only. They should be configurable in code, not hardcoded in multiple UI views.

### 9.3 Future Ranking Changes

The design should allow future changes:

1. Server-controlled ranking.
2. A/B ranking experiments.
3. Personalization based on follows, checkins, recent views.
4. Location-aware event ranking.
5. Trending searches and trending results.

## 10. API Design

### 10.1 Recommended Unified Endpoint

Add:

```http
GET /v1/search
```

Query parameters:

| Param | Required | Example | Notes |
| --- | --- | --- | --- |
| q | Yes | `martin` | Trimmed query |
| tab | No | `events` | Defaults to `all`; valid values are the result tab keys |
| limit | No | `30` | Max returned normalized items; backend clamps to 1-80 |

Auth:

1. Require logged-in user.
2. Use existing optional/auth middleware where appropriate, but reject unauthenticated requests.

### 10.2 Unified Response

Recommended response:

```json
{
  "data": {
    "query": "martin",
    "tab": "all",
    "limit": 30,
    "totalCount": 42,
    "items": [
      {
        "id": "dj:dj_123",
        "type": "dj",
        "entityID": "dj_123",
        "title": "Martin Garrix",
        "subtitle": "DJ · Progressive House",
        "summary": "Related events, sets, and rating units are available.",
        "imageUrl": "https://...",
        "badgeText": "Verified DJ",
        "deeplink": "raver://dj/dj_123",
        "relevanceScore": 96.2,
        "publishedAt": null,
        "updatedAt": "2026-05-08T08:30:00.000Z",
        "rankingYear": null
      }
    ],
    "countsByTab": {
      "all": 42,
      "events": 5,
      "news": 3,
      "djs": 8,
      "sets": 4,
      "rankings": 2,
      "ratings": 7,
      "posts": 6,
      "peopleSquads": 3,
      "festivals": 2,
      "labels": 1,
      "genreTree": 1
    },
    "partialErrors": [],
    "generatedAt": "2026-05-08T08:30:00.000Z"
  }
}
```

### 10.3 Result Item Contract

Use a normalized item for All tab and top matches:

```ts
type GlobalSearchItem = {
  id: string;
  type:
    | 'event'
    | 'news'
    | 'dj'
    | 'set'
    | 'ranking_board'
    | 'ranking_entry'
    | 'rating_event'
    | 'rating_unit'
    | 'post'
    | 'label'
    | 'festival'
    | 'user'
    | 'squad';
  title: string;
  entityID: string;
  subtitle?: string | null;
  summary?: string | null;
  imageUrl?: string | null;
  badgeText?: string | null;
  deeplink: string;
  relevanceScore: number;
  publishedAt?: string | null;
  updatedAt?: string | null;
  rankingYear?: number | null;
};
```

Phase 3 implementation uses normalized items for both All and domain tabs. Phase 4 iOS can filter the returned `items` by `type` and use `countsByTab` for tab badges. Full pagination and typed domain payloads remain a later optimization if result volume requires it.

### 10.4 Backend Search Source Mapping

Initial backend implementation can compose existing queries:

| Domain | Existing Data | Backend Work |
| --- | --- | --- |
| Events | Event table | Add relevance scoring around existing `search` |
| News | Feed posts with Raver news marker / news binding | Add server-side news search if missing |
| DJs | DJ table | Reuse existing search and pg_trgm where available |
| Sets | DJSet table | Add title/DJ/event search if not already supported |
| Rankings | Ranking board JSON/static/imported data | Search board title and entries |
| Ratings | RatingEvent/RatingUnit tables | Add search query support |
| Posts | Post table | Search post text and metadata, exclude comments |
| Users | User table | Reuse `/v1/users/search` behavior |
| Squads | Squad table | Reuse squad search behavior |
| Wiki | Labels/festivals | Reuse existing search |

### 10.5 API Performance Rules

1. V1 preview endpoint should return within 800 ms p95 on normal data.
2. Each domain query should have a timeout budget.
3. Backend should return partial results if one domain times out.
4. Limit preview items to 3-5 per domain.
5. Full tab endpoints should paginate.
6. Add indexes before shipping:
   - Events: name, city, country, venue, description.
   - DJs: name, aliases, bio, genres.
   - Posts: content text.
   - Rating events: name, description.
   - Rating units: name, description.
   - Squads: name, description.

If PostgreSQL is the current DB, prefer `pg_trgm` indexes for fuzzy-ish search where already used.

## 11. iOS Technical Design

### 11.1 Files to Modify

Likely files:

1. `mobile/ios/RaverMVP/RaverMVP/Features/MainTabView.swift`
   - Add global search action button.
   - Add overlay state.
   - Enforce login entry behavior.

2. `mobile/ios/RaverMVP/RaverMVP/Application/Coordinator/MainTabCoordinator.swift`
   - Add `AppRoute.globalSearchResults`.
   - Add route destination.
   - Add auth handling for global search route.

3. `mobile/ios/RaverMVP/RaverMVP/Core/WebFeatureService.swift`
   - Add global search API contract.

4. `mobile/ios/RaverMVP/RaverMVP/Core/LiveWebFeatureService.swift`
   - Implement `/v1/search` request.

5. `mobile/ios/RaverMVP/RaverMVP/Core/MockWebFeatureService.swift`
   - Add mock global search data.

6. New folder:

```text
mobile/ios/RaverMVP/RaverMVP/Features/Search/
  Models/GlobalSearchModels.swift
  ViewModels/GlobalSearchViewModel.swift
  Views/GlobalSearchOverlayView.swift
  Views/GlobalSearchResultsView.swift
  Views/GlobalSearchResultCards.swift
  Storage/RecentSearchStore.swift
```

### 11.2 iOS Models

Suggested Swift models:

```swift
enum GlobalSearchTab: String, CaseIterable, Codable, Hashable {
    case all
    case events
    case djs
    case peopleSquads
    case posts
    case news
    case sets
    case rankings
    case ratings
    case festivals
    case labels
    case genreTree
}

enum GlobalSearchItemType: String, Codable, Hashable {
    case event
    case news
    case dj
    case set
    case rankingBoard = "ranking_board"
    case rankingEntry = "ranking_entry"
    case ratingEvent = "rating_event"
    case ratingUnit = "rating_unit"
    case post
    case label
    case festival
    case user
    case squad
}

struct GlobalSearchItem: Identifiable, Codable, Hashable {
    let id: String
    let type: GlobalSearchItemType
    let title: String
    let subtitle: String?
    let summary: String?
    let imageUrl: String?
    let badgeText: String?
    let deeplink: String
    let relevanceScore: Double
    let publishedAt: Date?
    let updatedAt: Date?
}
```

### 11.3 View Models

Recommended view models:

1. `GlobalSearchOverlayViewModel`
   - Holds query.
   - Loads recent searches.
   - Handles submit.
   - Clears recent searches.

2. `GlobalSearchResultsViewModel`
   - Holds query and selected tab.
   - Loads all preview results.
   - Loads domain tab results.
   - Tracks per-tab `LoadPhase`.
   - Handles retry per tab.
   - Handles pull-to-refresh.

3. `RecentSearchStore`
   - Pure local storage.
   - Testable.

### 11.4 Navigation

Navigation should use existing `AppRoute` where possible.

If the backend provides deeplinks, use existing deep link mapper or a shared mapping helper:

```swift
func appRoute(for item: GlobalSearchItem) -> AppRoute?
```

Mapping:

| Item Type | AppRoute |
| --- | --- |
| event | `.eventDetail(eventID:)` |
| news | `.newsDetail(articleID:)` |
| dj | `.djDetail(djID:)` |
| set | `.setDetail(setID:)` |
| ranking_board | `.rankingBoardDetail(board:year:)` |
| rating_event | `.ratingEventDetail(eventID:)` |
| rating_unit | `.ratingUnitDetail(unitID:)` |
| post | `.postDetail(postID:)` |
| label | `.labelDetail(labelID:)` |
| festival | `.festivalDetail(festivalID:)` |
| user | `.userProfile(userID:)` |
| squad | `.squadProfile(squadID:)` |

### 11.5 Result Card UI

Use compact, scannable cards. Avoid nested cards.

Card requirements:

1. Stable height or predictable layout.
2. Domain badge.
3. Title with 1-2 lines.
4. Subtitle/metadata.
5. Optional image thumbnail.
6. No oversized hero styling inside result lists.

All tab should use a normalized mixed-result row for top matches, plus domain-specific preview rows when useful.

## 12. Backend Technical Breakdown

### 12.1 New Route

Add a standalone authenticated route:

```ts
app.use('/v1/search', searchRoutes);

router.get('/', authenticate, async (req, res) => {
  // parse q, tab, limit
  // call search service
  // return envelope
});
```

Suggested service:

```text
server/src/services/global-search.service.ts
```

Responsibilities:

1. Normalize query.
2. Validate login.
3. Fan out domain search tasks.
4. Score results.
5. Build top matches.
6. Return partial errors safely.

### 12.2 Domain Search Functions

Suggested functions:

```ts
searchEvents(query, options)
searchNews(query, options)
searchDJs(query, options)
searchSets(query, options)
searchRankings(query, options)
searchRatings(query, options)
searchPosts(query, options)
searchWiki(query, options)
searchUsersAndSquads(query, options)
```

Each function returns:

```ts
type DomainSearchResult = {
  total: number;
  items: GlobalSearchItem[];
  pagination?: Pagination;
};
```

### 12.3 Partial Failure Handling

Use `Promise.allSettled` for domain fan-out.

Rules:

1. A failed domain adds an item to `partialErrors`.
2. Successful domains still render.
3. Log domain errors server-side.
4. Return `partialErrors` for client display.

### 12.4 Auth

Use authenticated route. Return 401 if missing token.

Client behavior:

1. If API returns 401, show login-required state.
2. Do not silently show empty search results.

## 13. Analytics

Add analytics events:

| Event | Trigger |
| --- | --- |
| `global_search_button_tap` | User taps tab bar search button |
| `global_search_overlay_open` | Overlay appears |
| `global_search_submit` | User submits query |
| `global_search_result_view` | Result page loaded |
| `global_search_tab_select` | User switches result tab |
| `global_search_result_tap` | User taps a result |
| `global_search_recent_tap` | User taps recent keyword |
| `global_search_clear_recent` | User clears recent history |
| `global_search_partial_error` | One or more domains failed |

Important properties:

1. `query_length`
2. `tab`
3. `result_type`
4. `result_id`
5. `rank`
6. `has_results`
7. `total_count`
8. `duration_ms`

Do not log raw query if privacy policy does not allow it. If raw query logging is allowed later, gate it behind product/privacy approval.

## 14. Privacy and Safety

1. Search is login-only.
2. Do not search private chat messages.
3. Do not search squad messages.
4. Respect post visibility, hidden posts, blocked/muted users if those systems exist.
5. Respect private squad visibility rules.
6. Do not expose unpublished events/news/sets unless user has permission.
7. Local recent searches should be clearable.

## 15. Loading, Empty, and Error States

### 15.1 Overlay

1. Empty query: disable search button.
2. Invalid query: show inline message.
3. Logged out: login-required prompt.

### 15.2 Results Page

1. All tab initial loading: mixed skeleton sections.
2. Domain tab loading: domain-specific skeleton.
3. Empty all: global empty state with scope hints.
4. Empty domain: domain-specific empty state.
5. Full failure: full-page retry.
6. Partial failure: show available results plus compact error banner.

## 16. Acceptance Criteria

### 16.1 Entry

1. Search button appears between Circle and Messages.
2. Button does not change selected tab.
3. Logged-in tap opens blur overlay.
4. Logged-out tap triggers login-required behavior.
5. Existing tab unread badge still works.

### 16.2 Overlay

1. Current screen is blurred/dimmed behind overlay.
2. Search field auto-focuses.
3. Recent searches display.
4. Scope hints display.
5. Search does not run until submit.
6. Submitted query opens result page.
7. Submitted query is stored in recent searches.

### 16.3 Results

1. Results page has tabs: All, Events, News, DJs, Sets, Rankings, Ratings, Posts, Wiki, People & Squads.
2. All tab shows top matches and domain preview sections.
3. Each domain tab shows only that domain.
4. Rating results include rating events and rating units, excluding comments.
5. Post results include posts, excluding comments.
6. People & Squads tab includes users and squads in one page.
7. Tapping every supported result type navigates to the correct detail.
8. Partial failures do not blank successful domains.

### 16.4 Backend

1. `/v1/search` requires auth.
2. API returns normalized items with type, title, deeplink, relevance score.
3. API supports All preview.
4. API supports full tab pagination where needed.
5. API excludes chat history and comments.

## 17. Implementation Plan

Development must follow a clear checklist-driven process. Each phase should be closed before the next phase expands scope. If a new idea appears during development, record it in the development log as a future consideration unless it is required to complete the current acceptance criteria.

### Phase 1: iOS Entry and Overlay

Tasks:

- [x] Modify `MainTabView` tab bar layout to insert the search action button.
- [x] Add `GlobalSearchOverlayView`.
- [x] Add `RecentSearchStore`.
- [x] Add login guard.
- [x] Add overlay UI tests or basic manual test checklist.

Deliverable:

- [x] Search button opens overlay for logged-in user.
- [x] Recent searches and scope hints display.
- [x] Submit routes to placeholder results page.

Phase closeout:

- [x] No backend search work is mixed into this phase except route placeholder decisions.
- [x] No extra searchable domains are added beyond the PRD scope.
- [ ] Overlay behavior is reviewed and accepted before result-page work starts.

### Phase 2: iOS Result Page

Tasks:

- [x] Add `GlobalSearchResultsView`.
- [x] Add `GlobalSearchTab`.
- [x] Add All tab layout.
- [x] Add domain tab shell.
- [x] Add normalized result cards.
- [x] Add navigation mapping.

Deliverable:

- [x] Result page supports all tabs.
- [x] Mock data can render all domains.
- [x] Result taps navigate correctly.

Phase closeout:

- [x] All tab follows the PRD layout: top matches, domain previews, partial failure handling.
- [x] Every tab has loading, empty, error, and retry states.
- [x] No ranking algorithm tuning is done here beyond rendering backend/mock scores.

### Phase 3: Backend Unified Search

Tasks:

- [x] Add `global-search.service.ts`.
- [x] Add `/v1/search` route.
- [x] Implement events, DJs, labels, festivals using existing queries.
- [x] Implement rating event/unit search.
- [x] Implement post search excluding comments.
- [x] Implement users and squads search.
- [x] Implement sets search.
- [x] Implement rankings search.
- [x] Add relevance scoring.
- [x] Add partial failure handling.

Deliverable:

- [x] Authenticated `/v1/search` returns mixed results.
- [x] All expected domains are included.
- [x] Chat history and comments are excluded.

Phase closeout:

- [x] `/v1/search` rejects unauthenticated users.
- [x] Domain failures return partial errors instead of failing the whole response.
- [x] Result item contract is stable enough for iOS integration.
- [x] New backend search logic does not change existing domain APIs unless explicitly required.

### Phase 4: iOS API Integration

Tasks:

- [x] Extend `WebFeatureService`.
- [x] Implement `LiveWebFeatureService.search`.
- [x] Implement `MockWebFeatureService.search`.
- [x] Wire `GlobalSearchResultsViewModel` to live API.
- [x] Add per-tab retry and refresh.

Deliverable:

- [x] iOS displays real search data.
- [x] Result counts and partial errors render.

Phase closeout:

- [x] Mock and live services expose the same contract.
- [x] Every result type navigates through the agreed route map.
- [x] Route-level logged-out fallback is implemented.

### Phase 5: Quality and Polish

Tasks:

- [x] Add debug telemetry.
- [x] Add performance logging.
- [x] Add empty/error polish.
- [x] Add accessibility labels.
- [x] Check localization string coverage.
- [ ] Test dark/light mode.
- [ ] Test small phones and large phones.
- [ ] Test logged-out behavior manually.

Deliverable:

- [ ] Feature is ready for internal QA.

Phase closeout:

- [x] No new product scope is added during polish.
- [ ] All acceptance criteria are checked.
- [ ] Remaining non-blocking ideas are moved to Future Work.

## 17.1 Development Progress Tracker

Use this section as the single high-level progress tracker. Detailed daily notes should go in `docs/IOS_GLOBAL_AGGREGATED_SEARCH_DEV_LOG.md`.

### Phase Status

- [x] Phase 1: iOS Entry and Overlay implementation
- [x] Phase 2: iOS Result Page
- [x] Phase 3: Backend Unified Search
- [x] Phase 4: iOS API Integration
- [ ] Phase 5: Quality and Polish code complete, manual QA pending
- [ ] Final QA and handoff

### Cross-Phase Guardrails

- [x] Search remains login-only.
- [x] Chat message history remains excluded.
- [x] Comments remain excluded.
- [x] Users and squads remain grouped in one result tab.
- [x] All tab remains the primary aggregated result surface.
- [x] Scope changes are recorded in the development log before implementation.
- [x] Each phase has a closeout note before the next phase starts.

## 17.2 Scope Control Rules

The feature should stay on the core path: global entry, overlay, aggregated result page, unified search data, and reliable navigation. The following rules apply during development:

1. If a new idea is not required by the acceptance criteria, write it into the development log under `Future / Parking Lot`.
2. If a new idea changes API contract, tab structure, or searchable domains, stop and update the PRD before implementation.
3. If a domain is technically difficult, ship a controlled fallback instead of expanding the task. For example, return no ranking-entry matches but still search ranking boards.
4. At the end of each phase, close unresolved decisions explicitly:
   - Done now.
   - Deferred.
   - Removed from scope.
5. Do not introduce real-time suggestions, hot search backend, comment search, or chat search in V1.
6. Keep result cards compact and reusable; avoid rebuilding entire existing domain pages inside search.

## 17.3 Development Log Location

Development logs should be written in:

```text
docs/IOS_GLOBAL_AGGREGATED_SEARCH_DEV_LOG.md
```

The log should record:

1. Date and phase.
2. What changed.
3. Files touched.
4. Verification performed.
5. Decisions made.
6. Scope risks or drift warnings.
7. Phase closeout notes.

## 18. Test Plan

### 18.1 iOS Manual Tests

1. Logged-out user taps search.
2. Logged-in user taps search.
3. Overlay dismiss by cancel.
4. Overlay dismiss by outside tap.
5. Submit empty query.
6. Submit normal query.
7. Recent search appears.
8. Clear recent searches.
9. Open All tab.
10. Switch every result tab.
11. Tap result in every domain.
12. Pull to refresh.
13. Simulate partial API failure.
14. Simulate full API failure.
15. Test on small iPhone viewport.
16. Test on large iPhone viewport.
17. Test dark/light mode.

### 18.2 Backend Tests

1. Missing auth returns 401.
2. Empty query returns 400.
3. Events search returns matching events.
4. News search returns matching news.
5. DJs search returns matching DJs.
6. Sets search returns matching sets.
7. Rankings search returns matching boards/entries.
8. Ratings search returns rating events and rating units.
9. Ratings search does not search comments.
10. Posts search returns posts.
11. Posts search does not search comments.
12. Users and squads search returns both types.
13. Private/unavailable content is filtered.
14. Partial domain failure returns successful domains.

## 19. Open Questions

1. Should recent searches sync across devices later?
2. Should hot searches be global, region-based, or personalized?
3. Should All tab top matches include users/squads, or keep social identity lower unless exact match?
4. Should ranking entries deep link to ranking board with highlighted entry later?
5. Should posts include media OCR/search later? Not in V1.
6. Should event lineup DJ names be indexed as event search text? Recommended for V2 if not easy in V1.

## 20. Recommended V1 Cut

Recommended first releasable version:

1. Login-only global search button and overlay.
2. Recent searches and searchable scope hints.
3. Result tabs:
   - All
   - Events
   - News
   - DJs
   - Sets
   - Rankings
   - Ratings
   - Posts
   - Wiki
   - People & Squads
4. Unified backend `/v1/search`.
5. Relevance-first scoring.
6. No real-time suggestions.
7. No chat history search.
8. No comment search.
