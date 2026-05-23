# Event Incremental Lineup And Timetable Sync Plan

## Goal

Turn event create and edit into a commercially mature incremental write system so that:

- Creating a new event still works from a full payload.
- Editing an existing event does not rewrite all lineup/timetable rows when only one item changed.
- Admin review approval and user submission approval share the same incremental ingestion rules.
- Web per-item lineup/timetable editing endpoints also stop doing full rewrites.
- Event ingestion remains durable under the new async worker architecture.

This plan is specifically for the lineup, timetable, stage, performance, and event-artist write model.

## Why This Is Needed

Current canonical sync is still full-rewrite:

- `eventPerformance.deleteMany`
- `eventArtistMember.deleteMany`
- `eventArtist.deleteMany`
- `eventStage.deleteMany`
- then `createMany` for all rows

This means:

- add 1 artist to an event with 99 artists => 100% rewrite
- change 1 timetable slot time => full performance + artist/stage rewrite
- reorder lineup => full rewrite
- add 1 new stage => full rewrite

This is not commercially mature because it increases:

- transaction duration
- row churn
- lock contention
- deadlock risk
- index maintenance cost
- replication lag risk
- ID instability risk
- accidental downstream invalidation

## Scope

This plan covers:

- event submission create flow
- event submission edit flow
- admin auto-approval flow
- manual review approval flow
- direct Web lineup/timetable item APIs
- canonical lineup/timetable write engine

This plan does not yet implement:

- true multi-user collaborative editing
- user-visible version history UI
- full CRDT or operational transform editing

## Current State

### Current canonical sync behavior

Current `syncCanonicalEventLineupAndTimetable(...)`:

- loads incoming normalized artists/slots
- deletes all existing artists, members, stages, performances
- recreates everything

### Current editing entry points still affected

Even when the caller edits only one item, these paths still eventually trigger the full sync:

- content submission approval pipeline
- Web `POST /events/:id/lineup`
- Web `PATCH /events/:id/lineup/:artistId`
- Web `DELETE /events/:id/lineup/:artistId`
- Web `POST /events/:id/timetable`
- Web `PATCH /events/:id/timetable/:slotId`
- Web `DELETE /events/:id/timetable/:slotId`

So the fix must be at the canonical sync layer, not only at one route.

## Target Architecture

Use a two-step strategy:

1. Short-term production fix:
   - Keep full event payload submission shape.
   - Replace full-rewrite canonical sync with backend diff sync.
   - This immediately solves the "99 + 1 still full rewrite" problem.

2. Long-term mature model:
   - Add patch-based submission payloads for event edits.
   - Approval worker applies change sets directly.
   - Client sends only changed operations when possible.

## Design Principles

- Existing DB rows keep stable IDs whenever possible.
- Unchanged rows are not rewritten.
- Row identity comes from stable business keys first, random UUID only for new rows.
- Approval worker is still the only place where canonical event writes happen for submission flows.
- Direct Web item APIs should internally call the same diff engine.
- The diff engine must be idempotent.
- Writes should be minimal and deterministic.

## Canonical Identity Rules

### Artist identity

Preferred matching order:

1. `artist.id`
2. `djId`
3. normalized collaborative signature
4. normalized `djName`

Recommended collaborative signature:

```text
group:<sorted non-null memberDjIds>
fallback-group:<sorted normalized memberNames>
```

Rules:

- solo artist with stable `djId` matches by `djId`
- b2b/group with multiple `memberDjIds` matches by member set
- unbound artist with no `djId` matches by normalized name or normalized memberNames set

### Stage identity

Preferred matching order:

1. `stage.id`
2. normalized stage name

### Timetable slot / performance identity

Preferred matching order:

1. `slot.id`
2. stable semantic key:
   - `lineupArtistId`
   - normalized `stageName`
   - `festivalDayIndex`
   - `startTime`
   - `endTime`

For new slots created by the client before persistence, support `clientTempId` in future, but not required for the short-term diff engine.

## Data Contract Changes

### Short-term

No breaking client API changes required.

Keep sending:

- `lineupArtists`
- `lineupSlots`
- `timetableSlots`
- `stageOrder`

But require existing edit payloads to preserve returned stable IDs whenever available:

- `lineupArtist.id`
- `slot.id`
- future `stage.id` if exposed

### Long-term

Add support for edit patch payloads:

```json
{
  "editMode": "patch",
  "lineupChanges": [
    { "op": "add", "artist": { ... } },
    { "op": "update", "artistId": "artist-1", "patch": { "djName": "..." } },
    { "op": "delete", "artistId": "artist-2" },
    { "op": "reorder", "artistId": "artist-3", "sortOrder": 5 }
  ],
  "timetableChanges": [
    { "op": "add", "slot": { ... } },
    { "op": "update", "slotId": "slot-1", "patch": { "startTime": "...", "stageName": "..." } },
    { "op": "delete", "slotId": "slot-2" }
  ],
  "stageChanges": [
    { "op": "rename", "name": "Old Stage", "nextName": "New Stage" },
    { "op": "delete", "name": "Old Stage", "confirmDeleteLinkedPerformances": true }
  ]
}
```

Patch mode is a second phase. The first production fix is backend diff sync for full payloads.

Patch protocol is intentionally single-format, with no legacy compatibility aliases:

- `add` uses a full `artist` or `slot` object because the row has no stable server ID yet.
- `update` uses `artistId` or `slotId` plus `patch`.
- `delete` uses `artistId` or `slotId`; stage delete uses stage `name`.
- `reorder` uses `artistId` or `slotId` plus `sortOrder`.
- Stage rename uses `name` plus `nextName`; do not send `stageId`, `stageName`, or `newName`.

Decision:

- patch mode is required after backend diff sync is stable
- iOS edit flow should eventually submit change operations such as "add one artist" or "update one timetable slot" instead of always sending the full event payload

## Target Sync Engine

Replace the current full-delete behavior with:

```text
load current snapshot
normalize incoming snapshot
match existing rows by identity
compute create/update/delete sets
apply only changed rows
```

### New service structure

Recommended structure:

```text
server/src/services/event-lineup-canonical.service.ts
  - loadCanonicalEventLineupSnapshot(...)
  - normalizeCanonicalLineupArtists(...)
  - buildIncrementalCanonicalSyncPlan(...)
  - applyIncrementalCanonicalSyncPlan(...)
  - syncCanonicalEventLineupAndTimetable(...)
```

Where:

- `syncCanonicalEventLineupAndTimetable(...)` becomes an orchestrator
- full delete logic is removed
- the plan object can be logged and tested

## Incremental Sync Plan Shape

Recommended internal plan:

```ts
type IncrementalCanonicalSyncPlan = {
  artists: {
    create: ArtistCreateInput[];
    update: ArtistUpdateInput[];
    delete: string[];
  };
  members: {
    create: MemberCreateInput[];
    update: MemberUpdateInput[];
    delete: string[];
  };
  stages: {
    create: StageCreateInput[];
    update: StageUpdateInput[];
    delete: string[];
  };
  performances: {
    create: PerformanceCreateInput[];
    update: PerformanceUpdateInput[];
    delete: string[];
  };
};
```

This makes behavior observable and testable.

## Scenario Coverage

### Scenario A: Create new event

Input:

- full event payload
- no existing canonical rows

Expected behavior:

- all rows are creates
- no updates
- no deletes

### Scenario B: Edit event metadata only

Examples:

- name
- description
- cover image
- ticket URL
- city

Expected behavior:

- no lineup/timetable/stage/performance writes

### Scenario C: Add one lineup artist

Input:

- existing 99 artists
- new payload contains 100 artists
- only one new artist added

Expected behavior:

- `eventArtist.create` for 1 row
- `eventArtistMember.create` for that artist only
- no rewrite of the other 99 artists
- no performance writes unless timetable references that artist

### Scenario D: Rename one lineup artist

Expected behavior:

- `eventArtist.update` for 1 row
- member rows update only if member names changed
- no stage/performance rewrite unless display snapshot policy requires targeted updates

### Scenario E: Reorder lineup artists

Expected behavior:

- only changed `billingOrder` rows update
- no delete/recreate

### Scenario F: Delete one lineup artist with no timetable slot

Expected behavior:

- delete that artist’s members
- delete that artist row
- no effect on unrelated artists

### Scenario G: Delete one lineup artist that still has timetable slots

Expected behavior:

- strict reject
- require user to remove timetable slots first
- response should include linked timetable slot count and examples if possible

### Scenario H: Add one timetable slot for an existing artist

Expected behavior:

- create one `eventPerformance`
- no artist rewrite
- create stage only if stage is new

### Scenario I: Add one timetable slot for a new artist

Expected behavior:

- create one new artist
- create member rows for that artist
- create one performance
- create stage only if needed
- if timetable and lineup are no longer aligned, use timetable DJs as the source of truth and auto-rebuild lineup during submit

### Scenario J: Move one timetable slot to another stage

Expected behavior:

- update one performance `stageId`
- create new stage only if not already present
- possibly delete old stage if no rows reference it and stage deletion policy allows it

### Scenario K: Change one slot time

Expected behavior:

- update one performance `startAt/endAt/festivalDayIndex`
- no artist rewrite

### Scenario L: Reorder timetable slots only

Expected behavior:

- update only affected `sortOrder`

### Scenario M: Rename one stage

Expected behavior:

Recommended policy:

- stage rows are stable entities
- rename the stage row
- update only the stage record
- performances keep the same `stageId`

This is better than delete + recreate by stage name.

### Scenario N: Remove one stage that still has performances

Expected behavior:

- show a confirmation before the destructive action
- if user confirms, delete the stage and all linked performances
- if user does not confirm, reject the operation
- no unrelated stages or performances are rewritten

### Scenario O: Edit event with mixed changes

Examples:

- add 1 artist
- remove 1 slot
- rename 1 stage
- reorder 5 artists

Expected behavior:

- plan contains only those targeted writes
- unchanged rows stay untouched

### Scenario P: Admin auto-approval of edit submission

Expected behavior:

- worker processes submission
- canonical sync plan applies only changed rows
- admin still receives `处理中 -> 处理完成 -> 已入库`

### Scenario Q: Normal user review approval of edit submission

Expected behavior:

- submission enters `reviewing`
- approval worker applies only changed rows
- user receives `处理中 -> 审核中 -> 已入库`

### Scenario R: Repeated save of identical payload

Expected behavior:

- diff plan is empty
- no canonical row writes
- maybe only submission/job state updates

This is required for idempotency.

## Delete Policy

### Recommended short-term policy

- hard delete rows that are canonical-only and not referenced outside the canonical event domain
- deleting a lineup artist with linked timetable slots is strictly rejected
- deleting a stage with linked performances requires explicit confirmation, then cascades to delete those performances

### Recommended long-term policy

Add soft delete for:

- `eventArtist`
- `eventStage`
- `eventPerformance`

This is useful if these rows later gain stronger product-level references or audit requirements.

For now, soft delete is optional; diff sync is the first priority.

## Transaction Strategy

### Short-term

Keep one transaction for canonical event write, but reduce write volume through diff sync.

This alone should materially reduce:

- lock duration
- row churn
- transaction time

### Long-term

Split event master-data updates from heavy timetable mutation when safe.

Recommended direction:

- event core fields update transaction
- canonical sync transaction
- derived projection refresh after commit if needed

## Worker Interaction

The async submission worker stays responsible for:

- loading submission payload
- moving status
- calling canonical event write
- publishing notifications

What changes is the write engine:

- worker calls incremental sync instead of full rewrite sync

## Direct Web Editing APIs

Current Web lineup/timetable item APIs already work at item granularity semantically, but internally still full rewrite.

Required change:

- keep API contract as is
- make them use the same incremental canonical sync engine

This gives immediate business benefit even before patch-based submission payloads exist.

## Patch Submission Design

### Why patch mode matters

Even with backend diff sync, sending the full event payload on every edit is still heavier than necessary.

Patch mode improves:

- payload size
- approval review clarity
- conflict handling
- audit readability

### Recommended patch scope

Support patch mode first for:

- lineup add/update/delete/reorder
- timetable add/update/delete/reorder
- stage rename/reorder

Keep event metadata edits in snapshot mode initially if that simplifies rollout.

### Patch payload schema

Patch mode is enabled by:

```json
{
  "editMode": "patch",
  "targetEventId": "event-id",
  "baseEventUpdatedAt": "2026-05-23T06:00:00.000Z",
  "eventSnapshot": {
    "name": "Optional updated event name",
    "startDate": "2026-06-01",
    "endDate": "2026-06-02",
    "timeZone": "Asia/Shanghai"
  },
  "lineupChanges": [],
  "timetableChanges": [],
  "stageChanges": []
}
```

Rules:

- `targetEventId` is required.
- `baseEventUpdatedAt` is optional in the first rollout, but should become required for optimistic conflict detection later.
- `eventSnapshot` may contain normal event metadata fields and can continue to be applied with the existing event update path.
- canonical child rows are changed only through `lineupChanges`, `timetableChanges`, and `stageChanges`.
- all existing-row operations require stable backend row IDs from the edit draft.
- new rows may include a `clientTempId` so review UI can reference the item before it receives a backend ID.

Lineup change examples:

```json
[
  {
    "op": "add",
    "clientTempId": "lineup-temp-1",
    "artist": {
      "djId": "dj-id",
      "memberDjIds": ["dj-id"],
      "memberNames": ["Artist A"],
      "djName": "Artist A",
      "sortOrder": 100
    }
  },
  {
    "op": "update",
    "artistId": "event-artist-id",
    "patch": {
      "djName": "Artist A b2b Artist B",
      "memberDjIds": ["dj-a", "dj-b"],
      "memberNames": ["Artist A", "Artist B"]
    }
  },
  {
    "op": "reorder",
    "artistId": "event-artist-id",
    "sortOrder": 12
  },
  {
    "op": "delete",
    "artistId": "event-artist-id"
  }
]
```

Timetable change examples:

```json
[
  {
    "op": "add",
    "clientTempId": "slot-temp-1",
    "slot": {
      "lineupArtistId": "event-artist-id",
      "djId": "dj-id",
      "memberDjIds": ["dj-id"],
      "djName": "Artist A",
      "stageName": "Main Stage",
      "festivalDayIndex": 1,
      "startTime": "2026-06-01T20:00:00.000Z",
      "endTime": "2026-06-01T21:00:00.000Z",
      "sortOrder": 1
    }
  },
  {
    "op": "update",
    "slotId": "event-performance-id",
    "patch": {
      "stageName": "Main Stage",
      "startTime": "2026-06-01T21:00:00.000Z",
      "endTime": "2026-06-01T22:00:00.000Z"
    }
  },
  {
    "op": "reorder",
    "slotId": "event-performance-id",
    "sortOrder": 2
  },
  {
    "op": "delete",
    "slotId": "event-performance-id"
  }
]
```

Stage change examples:

```json
[
  {
    "op": "rename",
    "name": "Main Stage",
    "nextName": "Warehouse"
  },
  {
    "op": "delete",
    "name": "Warehouse",
    "confirmDeleteLinkedPerformances": true
  }
]
```

Patch validation rules:

- deleting a lineup artist with linked timetable slots is rejected.
- deleting a stage with linked performances requires `confirmDeleteLinkedPerformances: true`.
- timetable edits are the source of truth; patch apply should auto-rebuild lineup from timetable identities instead of rejecting mismatch.
- unknown IDs are rejected instead of silently creating new rows.
- duplicated operations for the same row in one payload are rejected unless the parser can safely coalesce them.
- patch apply must be idempotent for retry-safe worker behavior.

## Lineup And Timetable Alignment

### Product rule

Timetable DJs are the source of truth during event submit and approval.

When a user adds or edits timetable data:

- compare the normalized DJ set from timetable against the normalized DJ set from lineup
- auto-rebuild lineup from timetable before queueing the submission
- preserve existing lineup artist IDs when identities match
- allow diagnostics tooling to still show which DJs were missing or extra if needed

### One-click alignment

This remains available as a diagnostic or recovery action, but it is no longer required for submit:

```text
一键将阵容与时间表对齐
```

Behavior:

- derive lineup artists from timetable DJs
- preserve existing lineup artist IDs when identities match
- add missing lineup artists from timetable
- remove lineup-only artists when timetable source-of-truth submit runs
- keep explicit lineup sort order as much as possible, then append new artists by first timetable appearance

### Matching rules

Use the same identity rules as canonical sync:

- `djId`
- member DJ ID set
- normalized collaborative name set
- normalized display name

### UX requirements

If a diagnostic screen still shows mismatch, the message should be actionable:

```text
阵容和时间表未对齐：
时间表中缺少阵容绑定：Artist A, Artist B
阵容中没有对应时间表：Artist C
请选择一键对齐，或手动修改后再提交。
```

The backend must also enforce the timetable source-of-truth rule so old clients or admin tools cannot bypass it.

Implementation status:

- [x] Backend submission route auto-aligns lineup from timetable before queueing event submissions.
- [x] Worker ingestion auto-aligns lineup from timetable again before canonical writes.
- [x] BFF exposes `POST /v1/events/lineup-timetable-alignment/preview` to return mismatch details and aligned `lineupArtists`.
- [x] iOS upload flow no longer depends on the preview API before submit.
- [x] iOS submit no longer blocks on mismatch and instead relies on timetable source-of-truth submit behavior.
- [x] iOS can still apply backend aligned `lineupArtists` if a diagnostic alignment flow is opened manually later.
- [x] Persist canonical lineup/timetable row IDs in iOS draft models for later patch-mode edits.

## Conflict And Concurrency Policy

### Submission-level concurrency

Only one active approval ingestion job per `targetEventId`.

If an existing edit submission for the same event is still `processing` or `reviewing`:

- reject the new edit submission
- return a clear conflict message
- show the existing submission ID/status when possible

This means users cannot start a second edit task until the first edit task has completed as `approved`, `rejected`, `failed`, or `cancelled`.

### Direct edit concurrency

For direct Web item editing:

- last write wins at API level
- but preserve row IDs and minimal writes

### Future optimistic concurrency

Add optional `baseVersion` or `eventUpdatedAt` check:

- if client edits a stale event revision, reject with conflict

Recommended for phase 2, not phase 1.

## Testing Strategy

### Unit tests

- artist identity matching
- stage identity matching
- performance identity matching
- empty diff for unchanged snapshot
- one-create-only plan for 99 + 1 artist case
- one-update-only plan for rename case
- one-delete-only plan for safe delete case

### Integration tests

- create new event => all creates
- edit metadata only => no canonical row writes
- add artist => only one artist create
- add slot => only one performance create
- update slot => one performance update
- mixed edit => targeted plan only
- approval worker path => same results as direct route path

### Regression checks

- event public detail still reads correctly
- event lineup/timetable APIs still return same shape
- worker status transitions unchanged
- inbox notifications unchanged

## Rollout Plan

### Phase 1: Diff engine under existing payloads

- [x] Add new incremental sync plan builder
- [x] Add new incremental plan applier
- [x] Replace delete-all logic in canonical sync
- [x] Keep API payloads unchanged
- [x] Add focused tests for 99 + 1 and single-slot updates

### Phase 2: Web per-item APIs inherit incremental behavior

- [x] Verify lineup/timetable direct APIs no longer full rewrite
- [x] Add regression tests around add/update/delete item APIs

### Phase 3: Submission approval uses incremental sync

- [x] Verify create submission path
- [x] Verify edit submission path
- [x] Verify admin auto-approval path
- [x] Verify normal review approval path

### Phase 4: Patch submission mode

- [x] Confirm patch payload mode as required second-stage direction
- [x] Persist canonical lineup/timetable row IDs in iOS draft models
- [x] Design patch payload schema with stable lineup/timetable row IDs
- [x] Add backend patch parser
- [x] Add worker apply-patch path
- [x] Add iOS edit payload support
- [x] Add review/admin visibility for patch details

Implementation note:

- Backend patch mode is now handled when `editMode: "patch"` is submitted for an existing event. The worker loads the current canonical lineup/timetable snapshot, applies `lineupChanges`, `timetableChanges`, and guarded `stageChanges`, rejects unsafe missing-ID edits, rejects deleting lineup artists that are still linked by timetable slots, auto-rebuilds lineup from timetable whenever timetable content is present, then calls the same canonical incremental sync engine.
- iOS edit mode now stores a canonical lineup/timetable baseline while hydrating an event. On submit it compares the baseline to the current draft and sends `editMode: "patch"` with `lineupChanges`, `timetableChanges`, and guarded `stageChanges`; create mode continues to submit the full event payload.
- Patch submissions now receive a server-generated `changeSummary` such as "新增艺人 1 个，修改 time slot 1 个". The summary is persisted in the submission payload, appended to processing/review/approved/failed inbox notifications, and displayed in iOS My Posts list/detail.
- Added backend regression script `pnpm events:incremental-sync:regression`, covering direct canonical `99 + 1` artist/slot add, single-slot update, single artist/slot delete, manual-review-style patch apply, and normal review approval into storage. The script verifies existing artist/performance row IDs remain stable across non-destructive edits.
- Optimized canonical artist member rewrites from per-artist delete/create loops to batched member deletes and `createMany`, reducing transaction pressure on high-cardinality events and preventing transaction expiry during 99-row regression runs.
- Timetable is now the source of truth during submit and approval. BFF intake and worker ingestion auto-align lineup from timetable, and iOS submit no longer waits on a blocking alignment preview request.

## Recommended Order Of Implementation

1. Fix canonical sync engine first.
2. Keep client payloads unchanged at first.
3. Prove reduced write volume in create/edit/approve flows.
4. Then add patch mode for even smaller edit operations.

This sequence gives the fastest production win with the lowest migration risk.

## Acceptance Criteria

- Editing an event and adding 1 artist does not rewrite all existing artists.
- Editing an event and changing 1 timetable slot does not recreate all performances.
- Reordering lineup only updates order fields.
- Unchanged submissions produce empty or near-empty canonical plans.
- Approval worker and Web edit endpoints both use the same incremental sync engine.
- Existing row IDs remain stable across non-destructive edits.
- Event create still works from a full payload.
- Event edit latency and transaction duration materially decrease for large events.

## Questions To Confirm

- [x] Delete policy: deleting a lineup artist with linked timetable slots uses strict reject.
- [x] Delete policy: deleting a stage with linked performances requires confirmation, then cascades stage-linked performances.
- [x] Submission UX: while one edit task for an event is processing/reviewing, new edit submissions for the same event are rejected.
- [x] Long-term client direction: iOS edit flow should move to patch payloads after backend diff sync is stable.
- [x] Audit depth: review/admin should show human-readable change summaries like "新增 1 个艺人，修改 1 个时间段".
- [x] Alignment rule: timetable DJs are the source of truth during submit/approval, and lineup is auto-aligned from timetable.

## Progress Tracker

- [x] Confirm current full-rewrite bottleneck and affected write paths
- [x] Draft commercial incremental sync architecture covering create, edit, approval, and direct item APIs
- [x] Confirm delete and concurrency policies with product/ops
- [x] Add timetable-as-source-of-truth submit policy
- [x] Implement incremental canonical sync engine
- [x] Add backend lineup auto-alignment on submit/worker paths
- [x] Keep alignment preview available as a diagnostic helper
- [x] Remove iOS submit-time blocking alignment preview
- [x] Persist canonical lineup/timetable row IDs through iOS edit draft and submission payloads
- [x] Add tests for high-cardinality edit scenarios
- [x] Roll direct Web item APIs onto incremental engine
- [x] Roll submission approval worker onto incremental engine
- [x] Confirm patch-based event edit submission as second-stage direction
- [x] Design patch-based event edit submission phase
- [x] Add backend patch parser and worker apply-patch path
- [x] Add iOS patch payload generation for edit submissions
