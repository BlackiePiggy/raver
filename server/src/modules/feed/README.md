# Feed Module

> Status: Current + Compat
> Owner: Backend / Content

This module is the backend boundary for feed posts, post interactions, post comments, and feed event telemetry.

## Current Scope

- Feed post stream and post detail are still implemented inside `server/src/routes/bff.routes.ts`.
- DJ set comments currently reuse the existing comment service.
- FeedEvent telemetry normalization and persistence live in `feed-event.service.ts`.
- Post interaction writes and counter maintenance live in `post-interaction.service.ts`.
- Post comment reads, parent validation, creation, and `commentCount` maintenance live in `post-comment.service.ts`.
- BFF routes still own response hydration, DTO mapping, and notification orchestration during this phase.

## Boundary Rules

- New feed/post/comment behavior should enter `server/src/modules/feed` first, then be wired from routes.
- Existing public BFF endpoints remain stable during this migration.
- Do not move recommendation experiments, moderation, reporting, or commercialization into this module during Phase 5 closure.
- Any feed data backfill, projection rebuild, index change, or destructive cleanup must be preceded by a database backup and tracker entry.

## Current Facade

```text
server/src/modules/feed/index.ts
```

The facade currently re-exports the existing comment implementation, FeedEvent telemetry service, feed ranking experiment config, post interaction service, and post comment service. Large BFF feed/post handlers remain compat until they can be extracted as focused service/repository slices.
