# Music Module

> Status: Current + Compat
> Owner: Backend / Music Content

This module is the backend boundary for DJs, DJ sets, tracklists, tracks, labels, genres, and external music metadata providers.

## Current Scope

- DJ controllers remain in `server/src/controllers/dj.controller.ts`.
- DJ set and tracklist behavior remains in `server/src/services/djset.service.ts`.
- Spotify, Discogs, SoundCloud, aggregator, and music search services remain under `server/src/services` during this migration.
- Label routes still contain inline Prisma logic and should be extracted in a later focused pass.

## Boundary Rules

- Routes and BFF compatibility endpoints should import music capabilities from `server/src/modules/music`.
- External provider implementation details should stay behind this module boundary.
- Feed comments are owned by the Feed module even when used by DJ set endpoints.
- Do not add recommendation, commercialization, moderation, or reporting expansion during Phase 5 closure.
- Any music schema migration, metadata backfill, index change, or destructive cleanup must be preceded by a database backup and tracker entry.

## Current Facade

```text
server/src/modules/music/index.ts
```

The facade re-exports existing controller/service implementations to stabilize imports before deeper repository extraction.
