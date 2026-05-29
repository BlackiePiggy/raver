# Event Edit Mixed Update Full Flow

## Scope

This document explains the full end-to-end flow for this specific scenario:

- Existing event
- iOS edit flow
- Mixed changes in one submit
- Includes `schedule`, `weeks`, `eventDays`, `timetable`, `stage`, and `lineup`

The goal is to answer:

- What happens after the user taps submit
- Which data structures are involved at each step
- How the backend decides whether to accept, queue, review, patch, or fully rewrite data
- How `timetable` is validated and stored
- What strategy is used for create vs edit, and full replace vs patch
- What the current strengths and weaknesses are

## High-Level Summary

For iOS event editing, the app does not directly update the `events` table.

Instead, it uses this layered flow:

1. iOS builds an edit payload from local draft state.
2. iOS sends `PATCH /v1/events/:id` to the BFF layer.
3. BFF validates the payload synchronously.
4. BFF creates a `content_submissions` row and returns "submitted/processing".
5. Background worker processes the submission.
6. Worker calls `createOrUpdateEventFromSubmission(...)`.
7. A database transaction updates:
   - `events`
   - `event_weeks`
   - `event_days`
   - canonical lineup/stage/performance tables
8. If all steps succeed, submission becomes `approved`.
9. If any step fails, the whole transaction rolls back and submission is marked failed.

For mixed edits, the most important fact is:

- `schedule` and `timetable` are not independent.
- `timetable slot -> eventDayId -> eventDays -> weeks` must remain fully consistent.

## Primary Data Structures

### iOS Draft Layer

The iOS edit flow is centered around `EventUploadDraft`.

Important draft fields:

- Basic event metadata
  - `name`
  - `description`
  - `city`
  - `country`
  - `manualLocation`
  - `locationPoint`
  - `ticket`
  - `officialWebsite`
- Time structure
  - `startDate`
  - `endDate`
  - `scheduleMode`
  - `timeZoneIdentifier`
  - `dayRolloverHour`
  - `weekRanges`
  - `canonicalWeeks`
- Timetable structure
  - `timetableSlots`
  - each slot contains:
    - `canonicalSlotId`
    - `eventDayId`
    - `weekIndex`
    - `dayIndexInWeek`
    - `overallDayIndex`
    - `localDate`
    - `stageName`
    - `startTime`
    - `endTime`
    - performer identity fields
- Lineup structure
  - `lineupOnlySlots`
- Edit baseline
  - `incrementalBaseline`
  - `eventRevision`
  - baseline lineup slots
  - baseline lineup artists
  - baseline stage order
  - baseline schedule fingerprint

### iOS Network Payload

The app maps draft state into:

- `UpdateEventInput`

Important fields:

- Full event metadata
- `schedule`
- `weeks`
- `eventDays`
- `lineupArtists`
- `lineupSlots`
- `stageOrder`
- `lineupSyncMode`
- `baseEventRevision`
- optional patch fields:
  - `editMode`
  - `lineupChanges`
  - `timetableChanges`
  - `stageChanges`

### Submission Layer

The BFF stores the edit request in:

- `content_submissions`
- `content_submission_versions`
- `content_submission_processing_jobs`

Important submission fields:

- `entityType = "event"`
- `status`
- `payload`
- `createdEntityId`
- `idempotencyKey`

### Final Canonical Storage Layer

Final event-related data is stored across:

- `events`
- `event_weeks`
- `event_days`
- `event_stages`
- `event_artists`
- `event_artist_members`
- `event_performances`
- `event_ticket_tiers`

This means `timetable` does not live as a single simple JSON blob after approval.
It is normalized into canonical relational tables.

## Step 1: iOS Hydrates Edit Draft

When iOS opens an existing event for editing:

1. `WebEvent` is loaded.
2. `EventUploadDraft.edit(event:)` hydrates:
   - `startDate/endDate`
   - `scheduleMode`
   - `canonicalSchedule`
   - `weekRanges`
   - `canonicalWeeks`
   - `dayRolloverHour`
   - `timetableSlots`
   - `lineupOnlySlots`
3. It also stores `incrementalBaseline`.

This baseline is critical for later edit behavior because it decides:

- whether a patch strategy can be used
- whether the event revision is still current

## Step 2: User Makes Mixed Changes

In the scenario covered by this document, the user may change all of the following in one session:

- event basic info
- date range
- multi-week structure
- event day mapping
- stage names/order
- lineup artists
- timetable slots

As these values change on iOS:

- `structuredWeeks` are rebuilt
- `structuredEventDays` are rebuilt
- `timetableSlots` are re-bound to structured `eventDayId`

Key local strategy:

- schedule changes are treated as structure changes
- timetable slots are not free-floating
- after a date/week change, the app tries to remap slot day metadata

## Step 3: iOS Builds the Edit Payload

On submit, `EventUploadMappers.updateInput(from:)` builds `UpdateEventInput`.

This always includes full structural schedule data:

- `schedule`
- `weeks`
- `eventDays`
- top-level `startDate`
- top-level `endDate`

For lineup/timetable/stage, there are two strategies.

### Strategy A: Full Payload

If no incremental patch path is used:

- send `lineupArtists`
- send `lineupSlots`
- send `stageOrder`

This acts like a full canonical re-sync request for lineup/timetable/stages.

### Strategy B: Patch Payload

If `incrementalBaseline` exists, the mapper computes diffs:

- `lineupChanges`
- `timetableChanges`
- `stageChanges`

Then it sets:

- `editMode = "patch"`

In patch mode:

- schedule structure is still sent in full
- lineup/timetable/stage are expressed as deltas

This mixed semantic is one of the main complexity points of the current design.

## Step 4: iOS Sends `PATCH /v1/events/:id`

The live iOS service sends:

- path: `/v1/events/:id`
- method: `PATCH`
- body: `UpdateEventInput`

This is not the legacy direct event controller path used for a simple synchronous update.
For the iOS mainline flow, this goes to the BFF submission route.

## Step 5: BFF Synchronous Validation

Before the submission is queued, the BFF validates synchronously.

Main checks:

1. User authentication and permission.
2. Event exists.
3. Event has required primary image asset:
   - poster, lineup, or cover at least one
4. Schedule payload can be normalized:
   - `normalizeSubmittedEventScheduleContext(body)`
5. Lineup/timetable payload is normalized:
   - `normalizeSubmittedEventLineupToTimetable(...)`
6. Event base revision must match current DB revision:
   - `assertEventSubmissionBaseRevision(...)`
7. No active edit submission already exists for the same target event:
   - `assertNoActiveEventEditSubmission(...)`

If any of these fail, the request fails immediately and no submission job is created.

## Step 6: Submission Record Creation

If synchronous validation passes:

1. BFF creates `content_submissions`
2. BFF creates version row in `content_submission_versions`
3. BFF creates processing job in `content_submission_processing_jobs`
4. BFF returns accepted response

At this point:

- user has not yet updated the real event rows
- only the submission system has accepted the task

## Step 7: Background Worker Processes the Submission

Worker logic:

1. Load submission
2. Move it from `processing/pending` to `reviewing`
3. Notify submitter
4. If auto-approval applies, call `createOrUpdateEventFromSubmission(...)`
5. If success, mark submission `approved`
6. If failure, mark submission failed

This means the edit is asynchronous from the user's perspective.

## Step 8: `createOrUpdateEventFromSubmission(...)`

This function is the true event canonicalization and DB write entry point.

It does these major operations:

1. Parse and normalize payload
2. Normalize schedule into `scheduleContext`
3. Validate image assets
4. Build normalized event metadata object
5. If edit:
   - verify target event still exists
   - validate `baseEventRevision`
6. Open a DB transaction
7. Update `events`
8. Sync `event_weeks` and `event_days`
9. Sync lineup/timetable/stage canonical tables
10. Increment event revision

## Step 9: Transaction Semantics

The edit apply phase uses a single DB transaction with:

- `timeout = 120_000`
- `maxWait = 30_000`

Meaning:

- it may wait up to 30 seconds to obtain transactional execution resources
- once started, it must finish within 120 seconds
- if it fails midway, the whole write rolls back

This gives strong atomicity, but it also means very large mixed updates may fail as one unit.

## Step 10: Event Table Update

Within the transaction, the `events` row is updated first.

Fields written include:

- `name`
- `nameI18n`
- `wikiFestivalId`
- `description`
- `descriptionI18n`
- `coverImageUrl`
- `lineupImageUrl`
- `imageAssets`
- `eventType`
- `organizerName`
- `sourceEventUrl`
- `city`
- `country`
- `cityI18n`
- `countryI18n`
- `manualLocation`
- `locationPoint`
- `latitude`
- `longitude`
- `startDate`
- `endDate`
- `scheduleMode`
- `timeZone`
- `startTime`
- `endTime`
- `dayRolloverHour`
- `ticketUrl`
- `ticketPriceMin`
- `ticketPriceMax`
- `ticketCurrency`
- `ticketNotes`
- `officialWebsite`
- `status`
- `revision = revision + 1`

Important:

- the final event start/end date comes from normalized `eventDays`, not just arbitrary top-level values

## Step 11: Sync Structured Schedule

`syncStructuredEventSchedule(...)` reconciles:

- `event_weeks`
- `event_days`

### Input Strategy

The source of truth is `scheduleContext`:

- `weeks`
- `eventDays`

### Rules

- delete removed event days first
- null out linked performance day pointers for deleted days
- upsert weeks by `weekIndex`
- upsert days by `eventDayId`
- rewrite `eventWeekId`
- preserve uniqueness constraints:
  - `(eventId, weekIndex)`
  - `(eventId, eventDayId)`
  - `(eventId, overallDayIndex)`

### Why This Matters for Timetable

Every timetable performance depends on valid:

- `eventDayId`
- `weekIndex`
- `dayIndexInWeek`
- `overallDayIndex`
- `localDate`

So schedule sync is a prerequisite for correct timetable sync.

## Step 12: Timetable Normalization Rules

Before canonical storage, timetable slots are normalized by `normalizeSubmissionLineupSlots(...)`.

Each slot must satisfy:

- `eventDayId` must exist
- that `eventDayId` must exist in submitted `eventDays`
- if slot also carries:
  - `weekIndex`
  - `dayIndexInWeek`
  - `overallDayIndex`
  - `localDate`
  they must match the referenced event day exactly
- `startTime` and `endTime` must be parseable
- if end is earlier than start, it is shifted to the next day
- slot identity must be non-empty:
  - `djName`
  - or `djId`
  - or member DJ ids

The normalized slot becomes:

- `CanonicalLineupSlotInput`

With these final fields:

- `id`
- `lineupArtistId`
- `eventDayId`
- `weekIndex`
- `dayIndexInWeek`
- `overallDayIndex`
- `localDate`
- `djId`
- `memberDjIds`
- `djName`
- `stageName`
- `startTime`
- `endTime`
- `sortOrder`

## Step 13: Full Sync vs Patch Sync for Timetable/Lineup/Stage

`syncSubmissionEventLineupAndTimetable(...)` chooses strategy based on payload.

### Full Sync Path

Used when `editMode !== "patch"`.

Behavior:

- normalize submitted `lineupSlots`
- normalize submitted `lineupArtists`
- normalize and derive timetable artists
- merge lineup according to `lineupSyncMode`
- relink slots to artists
- normalize `stageOrder`
- fully sync canonical tables

This is a full desired-state rewrite strategy.

### Patch Path

Used when `editMode === "patch"`.

Behavior:

1. Load current canonical snapshot from DB:
   - artists
   - slots
   - stageOrder
2. Apply:
   - `lineupChanges`
   - `timetableChanges`
   - `stageChanges`
3. Re-align resulting slots to the new submitted `scheduleContext`
4. Rebuild final canonical desired state
5. Sync canonical tables

This is not a tiny in-place mutation.
It is:

- load snapshot
- apply semantic patch
- normalize against new schedule
- then canonical reconcile

## Step 14: Patch Semantics in Detail

### Timetable Patch Ops

Supported:

- `add`
- `update`
- `delete`
- `reorder`

For `update/add`:

- slot payload is re-run through full slot normalization
- slot must still satisfy event day consistency

### Stage Patch Ops

Supported:

- `rename`
- `delete`

`delete` requires:

- `confirmDeleteLinkedPerformances = true`

Deleting a stage also deletes linked timetable performances from the desired state.

### Lineup Patch Ops

Supported:

- `add`
- `update`
- `delete`
- `reorder`

Deletion is blocked if the artist is still referenced by timetable slots.

## Step 15: Canonical Reconciliation

After normalization, the final desired state is applied into canonical tables through:

- `syncCanonicalEventLineupAndTimetable(...)`

This function reconciles:

- `event_artists`
- `event_artist_members`
- `event_stages`
- `event_performances`

### Reconciliation Strategy

1. Load existing canonical rows.
2. Build target rows from final desired slots/artists/stages.
3. Try to match target artists/stages/performances to existing rows by stable identity.
4. Delete rows no longer desired.
5. Create missing rows with `createMany`.
6. Update changed rows in batches.

### Performance Storage

Each timetable slot finally lands in `event_performances`.

Relevant fields:

- `eventArtistId`
- `stageId`
- `eventDayId`
- `weekIndex`
- `dayIndexInWeek`
- `overallDayIndex`
- `localDate`
- `startAt`
- `endAt`
- `sortOrder`

This is the final persisted timetable model.

## Step 16: Large Timetable Strategy

For many timetable rows, the system uses:

- single transaction
- `createMany` for inserts
- batch artist updates
- batch stage updates
- raw SQL bulk performance updates

This is materially better than naive one-row-at-a-time writes.

However, the flow is still complex because the write path includes:

- submission queue
- schedule normalization
- event day validation
- lineup merge logic
- canonical reconciliation

So "many timetable rows" is not only a database throughput problem.
It is also a structural consistency problem.

## Step 17: Data Strategy by Section

### Schedule

Data structure:

- `schedule`
- `weeks`
- `eventDays`

Strategy:

- full structural truth
- validated synchronously and again in processing path

### Timetable

Data structure:

- `lineupSlots` in payload
- `event_performances` in DB

Strategy:

- every slot must attach to a valid `eventDayId`
- slots are normalized, aligned, then canonicalized

### Stage

Data structure:

- `stageOrder`
- `event_stages`

Strategy:

- stage names normalized by semantic name
- patch supports rename/delete
- full sync supports complete reorder/rebuild

### Lineup

Data structure:

- `lineupArtists`
- `event_artists`
- `event_artist_members`

Strategy:

- may be explicitly submitted
- may also be derived from timetable
- merge mode:
  - `incremental_fill`
  - `exact_align`

## Step 18: Why Mixed Edit Is High Risk

Mixed edit is the most failure-prone path because it combines:

- structural schedule rewrite
- timetable day rebinding
- stage reconciliation
- lineup reconciliation
- revision protection
- active submission protection
- asynchronous processing

The main risk is not only write volume.
It is semantic coupling between:

- `weeks`
- `eventDays`
- `eventDayId`
- slot day metadata
- stage names
- lineup identity

Any mismatch can reject the whole edit.

## Step 19: Current Strengths

- Strong atomicity
- No partial DB corruption on mid-transaction failure
- Timetable is normalized into proper relational schema
- Supports large create/update sets better than naive row-by-row logic
- Has revision guard and active-submission guard

## Step 20: Current Weaknesses

- Edit path is operationally complex
- Patch and full structural payload coexist in one request
- Timetable strongly depends on event day consistency
- Mixed schedule+timetable edits have many failure surfaces
- Asynchronous submission processing can make user perception confusing
- Large mixed edits are not the simplest or most robust possible design

## Practical Interpretation for Mixed Edit

When an old event is edited and the user changes timetable, stage, lineup, and schedule together:

1. The app submits the full schedule structure.
2. The app may submit timetable/lineup/stage as patch deltas.
3. Backend validates structural schedule correctness first.
4. Backend loads current canonical snapshot.
5. Backend applies deltas to that snapshot.
6. Backend re-aligns the resulting slots to the newly submitted schedule.
7. Backend reconciles final desired canonical rows.
8. Backend writes all related tables in one transaction.
9. Any inconsistency or timeout causes total rollback.

That is the exact reason this path is powerful but fragile.

## Files Involved

Main iOS:

- `mobile/ios/RaverMVP/RaverMVP/Features/Discover/Events/UploadFlow/EventUploadDraft.swift`
- `mobile/ios/RaverMVP/RaverMVP/Features/Discover/Events/UploadFlow/EventUploadMappers.swift`
- `mobile/ios/RaverMVP/RaverMVP/Features/Discover/Events/UploadFlow/EventUploadFlowViewModel.swift`
- `mobile/ios/RaverMVP/RaverMVP/Core/WebFeatureModels.swift`

Main backend:

- `server/src/routes/bff.web.routes.ts`
- `server/src/services/content-submission-processing.service.ts`
- `server/src/services/content-submission-event.service.ts`
- `server/src/services/event-lineup-canonical.service.ts`
- `server/prisma/schema.prisma`

## Bottom-Line Judgment

For mixed edit of an existing event:

- the system is designed to preserve consistency, not simplicity
- the final DB write model is relational and reasonably disciplined
- timetable handling is strict and deeply coupled to schedule structure
- the current solution is workable, but not the lowest-risk design for large mixed edits

If the product goal is "high success rate under very large mixed timetable edits", the current architecture is not ideal.
If the goal is "strong consistency and canonical relational storage", the current architecture does achieve that reasonably well.
