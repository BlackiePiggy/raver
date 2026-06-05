# Entity Change Module

This module is the canonical source for content entity change tracking.

First-wave scope:

- `event`
- `dj`
- `brand`, mapped to `WikiFestival`

Second-phase scope:

- `djSet`

Third-phase scope:

- `news`
- `post`

Fourth-phase scope:

- `label`

Do not add other entities without updating
`docs/ENTITY_CHANGE_DIFF_DOMAIN_SERVICE_DESIGN.md` first.

## Runtime Flow

All supported update flows should use the same sequence:

```text
capture before snapshot
execute domain write
capture after snapshot
diff snapshots
persist entity_change_logs
bridge audit / notification metadata
```

The persisted log stores hashes, structured changes, summaries, and public
changes. It must not store full before/after snapshots.

## Short-Term Snapshot Archive

Phase 15 adds `entity_change_snapshot_archives` as a separate short-term
archive for before/after snapshots. This keeps `entity_change_logs` compact and
public-safe while preserving enough temporary state for audit investigation and
future rollback tooling.

Default retention is 30 days and can be overridden with
`ENTITY_CHANGE_SNAPSHOT_ARCHIVE_TTL_DAYS`. Expired rows can be inspected with
`pnpm entity-change:snapshot-archive:cleanup` and deleted with
`pnpm entity-change:snapshot-archive:cleanup:apply`.

## Revision Guard

Phase 16 adds revision compare-and-swap helpers. Supported write flows should
parse client-provided `expectedRevision` / `baseRevision` with
`parseExpectedEntityRevision`, compare it against the captured before snapshot,
and include the current revision in the actual Prisma update `where` clause
when the entity has a stable revision field.

Strong CAS is currently enabled for `event` and `brand(WikiFestival)`. Entities
without revision fields (`dj`, `djSet`, `news`, `post`, `label`) keep the hook
available but do not enforce optimistic locking until their schemas gain a
stable revision.

## Public Notifications

User-facing notifications may include old/new values only from `publicChanges`.
Private/operator fields must stay out of `publicChanges`.

## Tracking Discipline

Every code change to this module or its call sites must update:

```text
docs/ENTITY_CHANGE_DIFF_DOMAIN_SERVICE_DESIGN.md
```

Update the relevant checklist item and add a row to `23.3 变更流水`.

## Regression Scripts

```bash
pnpm entity-change:core:regression
pnpm entity-change:event:regression
pnpm entity-change:dj:regression
pnpm entity-change:brand:regression
pnpm entity-change:dj-set:regression
pnpm entity-change:news-post:regression
pnpm entity-change:label:regression
pnpm entity-change:snapshot-archive:regression
pnpm entity-change:revision-guard:regression
```
