# Feature 00 - Migration Matrix

## 1. 当前 iOS 到 RN Feature 映射

| iOS 范围 | RN Feature | 优先级 | 备注 |
|---|---|---:|---|
| `Application/Coordinator` | `navigation` | P0 | App Shell、Tab、详情、Deep Link |
| `Application/DI/AppContainer.swift` | `app/providers` + repositories | P0 | 对齐依赖注入边界 |
| `Core/AppState.swift` | `store/sessionStore` | P0 | 登录态、语言、全局错误、deep link event |
| `Features/Auth/LoginView.swift` | `features/auth` | P0 | 登录注册、token |
| `Features/Discover` | `features/discover` | P0 | 主入口 |
| `Features/Discover/Events` | `features/events` | P0 | 活动列表、详情、收藏、日程 |
| `Features/Discover/DJs` | `features/djs` | P0 | DJ 列表、详情、关注 |
| `Features/Discover/Sets` | `features/sets` | P1 | Set、Tracklist、播放器 |
| `Features/Discover/News` | `features/news` | P2 | 资讯列表/详情 |
| `Features/Discover/Learn` | `features/wiki` | P2 | Wiki、厂牌、音乐知识 |
| `Features/Search` | `features/search` | P1 | 全局聚合搜索 |
| `Features/Circle` | `features/circle` | P0 | 社区 Tab |
| `Features/Feed` | `features/feed` + `features/comments` | P0 | Feed、帖子、评论、发布 |
| `Shared/PostCardView.swift` | `shared/components/PostCard.tsx` | P0 | 多处复用 |
| `Features/Profile` | `features/profile` | P0 | 我的、公开主页、编辑、关注 |
| `Features/Notifications` | `features/notifications` | P1 | inbox/unread/push route |
| `Features/Messages` | `features/messages` | P2 | Tencent IM，风险高 |
| `Features/Squads` | `features/squads` | P2 | 小队和线下活动 |
| `Features/VirtualAssets` | `features/virtualAssets` | P2 | 身份视觉资产 |
| `Core/Widget` | `native/widget` | P3 | 原生 target，后置 |
| `Infrastructure/TencentIM` | `services/im` + native module | P2 | 先 bootstrap，再 chat |
| `Infrastructure/LegacyOpenIM` | none / legacy docs | 不迁移 | OpenIM 非当前主线 |

## 2. 首期页面清单

P0：

- Login
- Main Tabs
- Discover Home
- Events List
- Event Detail
- DJs List
- DJ Detail
- Circle Home
- Feed
- Post Detail
- Compose Post basic
- Profile Me
- Public User Profile

P1：

- Sets List
- Set Detail
- Comments full interaction
- Search Results
- Notifications Inbox
- Check-ins read-only
- Ratings read-only

P2：

- Messages Home
- Conversation
- Squads
- Virtual Assets
- News/Wiki
- Editors

P3：

- Widget
- Advanced offline
- Advanced media player
- Full chat media/search/settings parity

## 3. 迁移判断

每个功能迁移前先回答：

- iOS 来源文件是什么？
- RN 目标 feature 是什么？
- API 是 current、compat 还是 legacy？
- 是否依赖 native SDK？
- 是否需要离线？
- 是否需要 deep link？
- 是否进入首期 MVP？

