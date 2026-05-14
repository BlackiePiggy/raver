# Feature 02 - Discover Events Music

## 1. 范围

包括：

- Discover Home
- Recommend
- Events list/detail/favorite/schedule/live discussion
- DJs list/detail/follow/ranking
- Sets list/detail/player/tracklist
- News
- Wiki/Learn

## 2. iOS 来源

```text
Features/Discover/DiscoverHomeView.swift
Features/Discover/Recommend/*
Features/Discover/Events/*
Features/Discover/DJs/*
Features/Discover/Sets/*
Features/Discover/News/*
Features/Discover/Learn/*
Features/Discover/Shared/DiscoverRepositories.swift
```

## 3. RN 目标目录

```text
features/discover/
features/events/
features/djs/
features/sets/
features/news/
features/wiki/
shared/components/EventCard.tsx
shared/components/DjCard.tsx
shared/components/SetCard.tsx
```

## 4. 路由

```text
DiscoverHome
EventDetail(eventId)
EventSchedule(eventId)
EventLiveDiscussion(eventId, eventName)
EventRoute(eventId, selectedDayId?, selectedSlotIds?)
DjDetail(djId)
LabelDetail(labelId)
FestivalDetail(festivalId)
SetDetail(setId)
NewsDetail(articleId)
RankingBoardDetail(board, year?)
```

## 5. API

优先沿用：

```text
/api/events
/api/djs
/api/dj-sets
/api/music
/v1 search / recommend / BFF 聚合
```

Repository：

```text
eventRepository
djRepository
setRepository
discoverRepository
musicRepository
```

## 6. 复现策略

### Discover Home

先复刻信息架构：

- 推荐入口。
- 活动入口。
- DJ 入口。
- Sets 入口。
- Search 入口。
- News/Wiki 后置。

### Event

优先完成：

- list。
- detail。
- favorite。
- schedule read-only。
- share entry。

后置：

- editor。
- route planner complex。
- live discussion 高级能力。

### DJ

优先完成：

- list。
- detail。
- follow。
- linked events/sets。

后置：

- import/editor。
- advanced ranking。

### Set

优先完成：

- list。
- detail。
- tracklist read-only。
- external link/player basic。

后置：

- editor。
- full media player。

## 7. 验收

- Discover 首屏可加载。
- 活动、DJ、Set 详情从列表和 deep link 都可达。
- favorite/follow mutation 后列表和详情状态一致。
- 大图加载失败有 fallback。
- 长列表滚动稳定。

