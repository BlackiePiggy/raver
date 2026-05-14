# Events Module

> Status: Current + Compat
> Owner: Backend / Events

This module is the backend boundary for events, lineups, timetables, ticket tiers, event media, and live event discussion.

## Current Scope

- Event CRUD controllers remain in `server/src/controllers/event.controller.ts`.
- Lineup and timetable controllers remain in `server/src/controllers/lineup.controller.ts` and `server/src/controllers/timetable.controller.ts`.
- Routes should import event capabilities from `server/src/modules/events` instead of directly reaching into controller files.

## Boundary Rules

- New event behavior should enter the Events module boundary first.
- Keep route behavior stable while migrating from controller files into module services/repositories.
- Do not fold rating, feed, squad activity, or notification orchestration into the Events module. Cross-domain flows should be composed by routes/use cases.
- Any event schema migration, index change, backfill, or destructive cleanup must be preceded by a database backup and tracker entry.

## Current Facade

```text
server/src/modules/events/index.ts
```

The facade re-exports existing controllers to establish a stable module import path before deeper service/repository extraction.
