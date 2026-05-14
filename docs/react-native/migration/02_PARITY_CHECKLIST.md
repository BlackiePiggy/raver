# Migration 02 - Parity Checklist

> 用于跟踪 RN 复现是否达到 iOS 主线行为。状态建议使用：`todo`、`in-progress`、`blocked`、`done`。

## 1. Foundation

| 项目 | 状态 | 验收 |
|---|---|---|
| RN app scaffold | todo | iOS/Android 模拟器可启动 |
| TypeScript strict | todo | typecheck 通过 |
| Navigation root | todo | Auth/MainTabs/Details/Modal 可用 |
| Theme tokens | todo | 基础页面风格一致 |
| HTTP client | todo | token、401、timeout、error model |
| Query client | todo | list/detail cache 可用 |
| Secure storage | todo | token 重启恢复 |
| MMKV preferences | todo | language/theme/runtime config |
| Deep link parser | todo | event/dj/set/post/user 可解析 |
| Error/loading/empty | todo | shared 状态组件完成 |

## 2. P0 Pages

| 页面 | 状态 | iOS 来源 | RN 目标 |
|---|---|---|---|
| Login | todo | `Features/Auth/LoginView.swift` | `features/auth/screens/LoginScreen.tsx` |
| Main Tabs | todo | `MainTabCoordinator.swift` | `navigation/MainTabs.tsx` |
| Discover Home | todo | `DiscoverHomeView.swift` | `features/discover/screens/DiscoverHomeScreen.tsx` |
| Events List | todo | `EventsModuleView.swift` | `features/events/screens/EventsListScreen.tsx` |
| Event Detail | todo | `EventDetailView.swift` | `features/events/screens/EventDetailScreen.tsx` |
| DJs List | todo | `DJsModuleView.swift` | `features/djs/screens/DjsListScreen.tsx` |
| DJ Detail | todo | iOS Discover/DJs detail route | `features/djs/screens/DjDetailScreen.tsx` |
| Circle Home | todo | `CircleCoordinator.swift` | `features/circle/screens/CircleHomeScreen.tsx` |
| Feed | todo | `FeedView.swift` | `features/feed/screens/FeedScreen.tsx` |
| Post Detail | todo | `PostDetailView.swift` | `features/feed/screens/PostDetailScreen.tsx` |
| Compose Post | todo | `ComposePostView.swift` | `features/feed/screens/ComposePostScreen.tsx` |
| Profile Me | todo | `ProfileView.swift` | `features/profile/screens/ProfileMeScreen.tsx` |
| Public Profile | todo | `UserProfileView.swift` | `features/profile/screens/UserProfileScreen.tsx` |

## 3. P1 Pages

| 页面 | 状态 | RN 目标 |
|---|---|---|
| Sets List | todo | `features/sets/screens/SetsListScreen.tsx` |
| Set Detail | todo | `features/sets/screens/SetDetailScreen.tsx` |
| Global Search | todo | `features/search/screens/GlobalSearchScreen.tsx` |
| Search Results | todo | `features/search/screens/SearchResultsScreen.tsx` |
| Notifications Inbox | todo | `features/notifications/screens/NotificationsScreen.tsx` |
| My Check-ins | todo | `features/checkins/screens/MyCheckinsScreen.tsx` |
| Rating Detail | todo | `features/ratings/screens/RatingDetailScreen.tsx` |

## 4. P2 Pages

| 页面 | 状态 | RN 目标 |
|---|---|---|
| Messages Home | todo | `features/messages/screens/MessagesHomeScreen.tsx` |
| Conversation | todo | `features/messages/screens/ConversationScreen.tsx` |
| Chat Settings | todo | `features/messages/screens/ChatSettingsScreen.tsx` |
| Squad Profile | todo | `features/squads/screens/SquadProfileScreen.tsx` |
| Squad Offline Activity | todo | `features/squads/screens/SquadOfflineActivityScreen.tsx` |
| Virtual Asset Center | todo | `features/virtualAssets/screens/VirtualAssetCenterScreen.tsx` |
| News Detail | todo | `features/news/screens/NewsDetailScreen.tsx` |
| Wiki/Learn | todo | `features/wiki/screens/WikiHomeScreen.tsx` |

## 5. API Parity

| 能力 | 状态 | 验收 |
|---|---|---|
| Auth | todo | login/refresh/logout/current user |
| Events | todo | list/detail/favorite/schedule |
| DJs | todo | list/detail/follow/linked content |
| Sets | todo | list/detail/tracklist |
| Feed | todo | list/detail/like/save/hide |
| Comments | todo | list/create/delete/pagination |
| Profile | todo | me/public/edit/follows |
| Notifications | todo | inbox/unread/mark read/register push |
| Search | todo | tabs/recent/debounce/cancel |
| Share | todo | short link/resolve/record open |
| Check-ins | todo | v2 projection read |
| Tencent IM | todo | bootstrap/conversations/messages |

## 6. Quality

| 门禁 | 状态 | 标准 |
|---|---|---|
| Typecheck | todo | CI 通过 |
| Unit tests | todo | mapper/repository/store |
| Component tests | todo | shared cards and states |
| E2E smoke | todo | login/discover/feed/profile |
| Crash monitoring | todo | Sentry 初始化 |
| Performance smoke | todo | Feed scroll stable |
| Deep link smoke | todo | event/dj/post/user |
| Push smoke | todo | notification click route |

