# Canonical Relationships Production Cutover Runbook

This runbook is the executable companion for Phase 6 in
[database-standardization-plan.md](/Users/blackie/Projects/raver/server/docs/database-standardization-plan.md).
It covers the production cutover from legacy array-backed relationship reads/writes
to canonical relationship tables.

## Scope

The cutover covers these canonical sources:

- Event lineup and timetable: `event_artists`, `event_artist_members`, `event_performances`
- Post and News bindings: `post_*_bindings`, `news_*_bindings`
- Follow and Favorite: `user_entity_follows`
- DJSet lineup: `dj_set_artists`
- Rating lineup: `rating_unit_dj_bindings`
- Genre preference: `user_genre_preferences`

## Preconditions

Before opening the cutover window:

1. `pnpm exec tsc --noEmit`
2. `pnpm run auth:integration`
3. `pnpm run phase5:canonical:regression`
4. `pnpm run phase5:query-plan-check`
5. Confirm the current production build already contains:
   - new Prisma schema
   - canonical migration script
   - canonical validation script
   - Phase 4 business code switches

## Required environment

Load production env before every command:

```sh
set -a && source .env && set +a
```

If migration traffic uses a direct DB URL, keep this pattern:

```sh
DIRECT_URL="${DIRECT_URL:-$DATABASE_URL}"
```

## Freeze scope

During the data migration window, freeze write entrypoints that can still mutate
legacy-compatible facts or user-facing counters.

At minimum freeze:

- Event create/edit, lineup edit, timetable edit
- Post create/edit/delete
- News create/edit
- DJ follow / unfollow
- Event favorite / unfavorite
- Profile favorite DJ update
- DJSet create/edit
- Rating event/unit create/edit
- Content submission approval publishing

Recommended practice:

- keep read traffic open
- gate write APIs behind maintenance/config switch or temporary ingress rule
- announce a short write freeze to operations/support

## Production sequence

### 1. Deploy code package

Deploy the version that includes:

- new schema
- migration scripts
- validation scripts
- canonical-read business code
- readonly smoke script

Do not reopen writes yet.

### 2. Production backup

Take a full DB backup before schema or data migration.

Example PostgreSQL command:

```sh
pg_dump "$DATABASE_URL" \
  --format=custom \
  --file "./backups/raver-pre-canonical-cutover-$(date +%Y%m%d-%H%M%S).dump"
```

Record:

- backup file path
- backup start/end time
- operator

### 3. Confirm write freeze

Before mutating schema/data:

- verify app instances serving writes are disabled or write endpoints are blocked
- verify no admin/import job is still running
- verify no manual content operation is in progress

### 4. Apply schema migration

```sh
pnpm prisma:generate
DIRECT_URL="${DIRECT_URL:-$DATABASE_URL}" pnpm prisma migrate deploy
```

Success criteria:

- migration exits `0`
- no pending failed migration in `_prisma_migrations`

### 5. Run canonical data migration

```sh
pnpm canonical:migrate
```

If you need a precheck before the window:

```sh
pnpm canonical:migrate:dry-run
```

Success criteria:

- command exits `0`
- migration report shows no fatal error buckets

### 6. Run consistency validation

```sh
pnpm canonical:validate
```

Success criteria:

- command exits `0`
- count mismatches are `0`
- field mismatches are `0`
- sample mismatches are `0`

Preserve the emitted log file from `server/prisma/.cache/`.

### 7. Publish business code cutover

If schema/data migration ran on a maintenance instance first, now switch traffic to
the canonical-enabled application version.

Only proceed when:

- migration succeeded
- validation succeeded
- health check is green

### 8. Reopen necessary writes

Re-enable user/admin writes after the canonical version is live.

Recommended order:

1. Profile and community interactions
2. Follow / favorite
3. Post / news
4. Event and admin editing

## Readonly smoke after cutover

Use the readonly smoke script against production or a production replica-routed app:

```sh
PHASE6_READONLY_BASE_URL="https://<prod-host>/v1" \
PHASE6_READONLY_ACCESS_TOKEN="<optional token>" \
pnpm run phase6:readonly:smoke
```

Optional fixed samples:

```sh
PHASE6_EVENT_ID=...
PHASE6_DJ_ID=...
PHASE6_POST_ID=...
PHASE6_NEWS_ID=...
PHASE6_DJ_SET_ID=...
PHASE6_RATING_UNIT_ID=...
pnpm run phase6:readonly:smoke
```

The script checks:

- `/health`
- `GET /v1/events/:id`
- `GET /v1/djs/:id`
- `GET /v1/feed/posts/:id`
- `GET /v1/news/:id`
- `GET /v1/dj-sets/:id`
- `GET /v1/rating-units/:id`
- `GET /v1/feed`
- `GET /v1/news`

## Observation window

During the first observation window after reopening writes, watch:

- Event detail response shape and lineup/timetable completeness
- DJ detail and DJ events list
- Post feed, post detail, news list, news detail
- Follow status, favorite status, follower/following counts
- DJSet detail and rating unit detail
- app error logs
- 5xx rate
- p95/p99 latency
- database slow query logs
- result count regressions on core list endpoints

Suggested DB checks:

```sql
select count(*) from user_entity_follows;
select count(*) from post_dj_bindings;
select count(*) from news_event_bindings;
select count(*) from event_performances;
```

## Rollback posture

If validation fails before traffic switch:

- keep writes frozen
- do not switch app traffic
- investigate mismatch bucket

If traffic has already switched and core read paths regress:

- freeze writes again
- roll back application traffic first
- keep backup and validation logs attached to the incident
- do not drop legacy structures during the same window

## Explicit non-goals in Phase 6

Do not do these in the cutover window:

- delete old columns or old tables
- rename legacy tables
- remove rollback-compatible legacy data structures from the database
- bundle unrelated schema changes
