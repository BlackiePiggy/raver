# Event Submission Task State Machine Plan

## Progress Tracker

- [x] Confirm current architecture fit between local event draft, content submissions, My Publishes, and content review inbox
- [x] Expand submission status model to support `processing`, `reviewing`, and `failed`
- [x] Extend backend content review inbox projection to surface intermediate task states
- [x] Extend backend notification publishing so every state transition emits an inbox item
- [x] Update iOS submission status mapping and display labels for new states
- [x] Update `My Publishes` filters and presentation for new task states
- [x] Ensure mobile event submit path always creates an async submission task instead of synchronous event creation
- [x] Convert mobile event edit path to async submission task flow
- [x] Move event lineup/timetable canonical ingestion into the submission approval pipeline
- [x] Verify approved-only visibility rule for event list/search/detail exposure
- [x] Add migration and rollout notes for old `pending` submissions
- [x] Convert admin event create/edit flow to async auto-approve instead of synchronous bypass
- [x] Update iOS review inbox cards to display all submission lifecycle states with distinct colors and labels

## Progress Notes

- 2026-05-23: Documented the target task-state design and confirmed the current codebase already has the right foundation in local draft storage, `contentSubmission`, `My Publishes`, and content review inbox.
- 2026-05-23: Expanded backend submission status handling from legacy `pending/approved/rejected` toward `processing/reviewing/approved/rejected/failed/cancelled`, with compatibility for old `pending`.
- 2026-05-23: Extended content review inbox projection to accept intermediate task states so notification-center can carry `processing`, `reviewing`, and `failed`.
- 2026-05-23: Updated iOS `My Publishes` and event upload success copy to show `处理中 / 审核中 / 已入库 / 处理失败` instead of the old three-state wording.
- 2026-05-23: Wired `processing` notifications on task creation/resubmission, and kept `approved/rejected` notifications on review completion.
- 2026-05-23: Added a shared submission-processing service that asynchronously advances tasks from `processing` to `reviewing`, or to `failed` on processor errors, and emits inbox notifications for both transitions.
- 2026-05-23: Closed the synchronous `/v1/events` create path in `bff.web.routes.ts` so new event submissions now always enter the async submission task flow instead of directly creating public events.
- 2026-05-23: Started converting the mobile event edit flow to the same async submission lifecycle so edit submits no longer depend on synchronous event writes.
- 2026-05-23: Converted the user-facing `/v1/events/:id` edit path to submit `contentSubmission` tasks for non-admin users, updated iOS edit success UX to task wording, and stopped edit-draft image removal from mutating the live event immediately.
- 2026-05-23: Identified the next backend gap after taskifying create/edit: lineup and timetable canonical ingestion still needs to be unified under the submission approval pipeline instead of remaining route-local logic.
- 2026-05-23: Started wiring canonical lineup/timetable ingestion into content-submission approval so approved event tasks can materialize event master data and performance data together.
- 2026-05-23: Completed canonical lineup/timetable ingestion for approved event submissions, so task approval now writes event master data, ticket tiers, stages, artists, and performances in one pipeline.
- 2026-05-23: Verified the approved-only visibility rule for new events: public event list/search/detail endpoints read from `event` records only, and submission tasks do not create those records until approval/ingestion completes.
- 2026-05-23: Added migration and rollout notes for legacy `pending` submissions, including compatibility mapping, release order, and operator-facing fallback guidance.
- 2026-05-23: Started removing the admin synchronous bypass for event create/edit so admin accounts also receive the same task notifications, with processing completion auto-approving instead of waiting for manual review.
- 2026-05-23: Converted admin event create/edit to the same async submission flow, and added automatic approval after processing so admin inbox now receives `处理中 -> 处理完成 -> 已入库` notifications without manual review.
- 2026-05-23: Identified and fixed the first large-payload ingestion bottleneck: event auto-ingest transactions now need an explicit longer timeout because canonical lineup/timetable rewrites can exceed Prisma's default 5-second interactive transaction window.
- 2026-05-23: Increased event submission ingest transaction limits to `maxWait=10s` and `timeout=30s` so large event lineup/timetable rewrites stay atomic without hitting Prisma's default 5-second interactive transaction expiry.
- 2026-05-23: Verified that content-review notifications were being persisted for admin submissions, then fixed the review inbox query path so `content_review` items are no longer filtered out by an outdated `community_interaction` type constraint.
- 2026-05-23: Extended the review inbox API to expose `statusLabel`, and updated iOS review notification cards to render `处理中 / 处理完成 / 已入库 / 处理失败 / 审核通过 / 审核未通过` as first-class review-chain states instead of collapsing everything into pass/fail.

## Goal

Transform iOS event upload into a task-based commercial flow:

- User taps submit and gets an immediate task result.
- The task appears in `Profile -> My Publishes`.
- No client polling is required from the upload screen.
- Status changes are delivered through the existing content review inbox.
- The event only appears in event list/search after it is fully ingested.

Target visible status flow:

`处理中 -> 审核中 -> 已入库`

With failure branches:

`处理中 -> 失败`

`审核中 -> 未通过`


## Fit With Current Implementation

### What already matches

1. There is already an edit draft mode on iOS.
   - `EventUploadDraftStore` stores local draft payloads and local image files.
   - `EventUploadFlowViewModel` saves draft changes very frequently.

2. Image upload already supports `draftId`.
   - Event images can already be uploaded against a draft owner on the server.
   - This is enough for "edit now, bind assets before final publish".

3. There is already a submission/task-like backend model.
   - `contentSubmission` already exists.
   - `My Publishes` already reads `contentSubmissions`.
   - The upload API already returns `submittedForReview(...)` in some flows.

4. There is already a dedicated inbox box for content review.
   - iOS already has `notification-center/content-reviews/*` endpoints.
   - Messages home already has a review box entry.

### What does not match yet

1. Current event draft is still mainly local draft, not a remote state machine.
   - It protects editing progress.
   - It is not yet the canonical source for task lifecycle.

2. Current submission statuses are too shallow.
   - Today the system is effectively `pending / approved / rejected`.
   - It cannot represent `处理中`.

3. Current content review inbox only projects `approved / rejected`.
   - It drops intermediate states.
   - It cannot notify "processing started" or "moved to review".

4. Current admin bypass path still writes event synchronously.
   - That is exactly the path that causes large lineup/timetable payload timeout risk.


## Recommended Direction

Use `contentSubmission` as the canonical user-facing task object instead of inventing a second parallel task model.

This is the best fit with the current codebase because:

- `My Publishes` already knows how to render it.
- Existing "submitted for review" response shape already exists.
- Existing content review inbox already exists.
- Existing admin review route already closes the loop into entity creation.

In short:

- Keep `EventUploadDraft` as the editing draft.
- Upgrade `contentSubmission` into the real submission task state machine.
- Route all event uploads through submission task creation, including large payloads.


## Canonical Lifecycle

### Phase 1: Editing Draft

Source of truth during editing:

- Local iOS `EventUploadDraft`
- Optional server-owned media via `draftId`

This phase is not shown as a task in `My Publishes`.

It is only an editable working state.

### Phase 2: Submission Task Created

When user taps submit:

1. Freeze current draft payload.
2. Create `contentSubmission`.
3. Return immediately with task ID and success message.
4. Show user:
   - "任务已提交，可在 个人主页 -> 我的发布 查看状态"

At this point user-visible status is:

- `processing`
- Display label: `处理中`

### Phase 3: Processing

Async backend work happens here:

- payload schema validation
- lineup/timetable normalization
- image asset validation
- stage normalization
- dedupe and consistency checks
- optional AI or rule-based enrichment
- optional anti-abuse / moderation precheck

If processing succeeds:

- move to `reviewing`

If processing fails:

- move to `failed`

### Phase 4: Reviewing

Submission has passed machine-side processing and is waiting human review or auto-review.

User-visible label:

- `审核中`

This stage is what current `pending` most closely means, but after this change it should be explicit as `reviewing`.

### Phase 5: Approved / Ingested

After approval:

1. Create canonical `event`
2. Persist lineup/timetable
3. Bind assets
4. Set `createdEntityId`
5. Mark submission status as `approved`

User-visible label:

- `已入库`

Only after this point should the event:

- appear in event list
- appear in search
- be available from detail deeplink

### Rejection / Failure

Two non-success endings should remain distinct:

- `rejected`
  - means human or policy review rejected it
  - display label: `未通过`

- `failed`
  - means system pipeline failed before review completion
  - display label: `处理失败`


## Status Model

### Backend canonical statuses

Recommended `contentSubmission.status` values:

- `processing`
- `reviewing`
- `approved`
- `rejected`
- `failed`
- `cancelled`

### Compatibility rule

During migration:

- old `pending` should be treated as `reviewing`

This avoids breaking current screens immediately.

### User-facing labels

- `processing` -> `处理中`
- `reviewing` -> `审核中`
- `approved` -> `已入库`
- `rejected` -> `未通过`
- `failed` -> `处理失败`
- `cancelled` -> `已取消`


## Migration And Rollout Notes

### Legacy `pending` compatibility

- Existing `contentSubmission.status = pending` records should continue to render as `审核中`.
- Admin review should continue accepting legacy `pending` records alongside new `processing` and `reviewing`.
- Inbox projection should treat legacy `pending` review messages as equivalent to `reviewing` instead of introducing a separate UI state.

### Recommended release order

1. Ship backend status expansion and inbox compatibility first.
2. Ship iOS `My Publishes` and submission success-copy updates second.
3. Ship event create/edit taskification after the UI can already render `processing / reviewing / failed`.
4. Enable operator review on top of the widened status set only after the above steps are live.

### Rollback and operator fallback

- If async processing has to be disabled temporarily, operators can still review legacy `pending` and new `reviewing` tasks from the same review endpoint.
- If a processor regression causes tasks to accumulate in `processing`, operators should use inbox notifications plus `My Publishes` to direct affected users, instead of exposing half-created public events.
- No migration should backfill public `event` rows from non-approved submissions. Visibility must continue to depend on approval completion, not on task creation.


## Inbox Notification Design

### Product decision

No polling is required from the upload screen.

Status changes are delivered by the existing content review inbox box.

This is reasonable and product-sound if:

- the submission action returns immediately
- `My Publishes` can always show latest status when user manually opens it
- inbox notifications are guaranteed for every significant transition

### Required notification transitions

Send one inbox item on each state change:

1. `processing`
   - title: `活动任务处理中`
   - body: `你提交的活动「X」已进入处理队列。`

2. `reviewing`
   - title: `活动进入审核`
   - body: `你提交的活动「X」已完成处理，正在审核中。`

3. `approved`
   - title: `活动已入库`
   - body: `你提交的活动「X」已审核通过并入库。`

4. `rejected`
   - title: `活动未通过审核`
   - body includes review reason

5. `failed`
   - title: `活动处理失败`
   - body includes retry/support guidance

### Important current gap

Current content review inbox projection only accepts:

- `approved`
- `rejected`

It must be extended to include:

- `processing`
- `reviewing`
- `failed`

Otherwise the new UX cannot work.


## My Publishes Behavior

### Current foundation

`MyPublishesView` already loads:

- real events
- real DJ sets
- `contentSubmissions`

This is the right place to host the task.

### Recommended behavior

For event submissions:

1. A newly submitted task appears immediately in `My Publishes`.
2. It stays there while `processing`.
3. It remains there while `reviewing`.
4. After `approved`, it should either:
   - continue to appear in submissions history with status `已入库`, or
   - appear in both submission history and actual event list item

Recommended choice:

- keep the submission record in submission history
- also allow navigation to the newly created event once approved

This gives auditability and better user trust.

### Recommended filters

Replace or extend current review filters:

- `全部`
- `处理中`
- `审核中`
- `已入库`
- `未通过`
- `处理失败`


## Event Visibility Rules

### Before approved

The submitted event must not:

- appear in event list
- appear in search
- be treated as public content

Only the task is visible.

### After approved

The event becomes visible only when:

- canonical event record is created successfully
- status is `approved`
- `createdEntityId` is written back to submission

This matches your desired behavior exactly.


## API and Backend Changes

### 1. Upgrade `contentSubmission` status enum

Current logic uses:

- `pending`
- `approved`
- `rejected`

Upgrade to:

- `processing`
- `reviewing`
- `approved`
- `rejected`
- `failed`
- `cancelled`

Migration rule:

- all old `pending` rows become logically `reviewing`

### 2. Change event submit API semantics

For mobile event upload:

- do not directly create `event` inside request path
- always create a `contentSubmission` task first
- return immediately

This should apply even for privileged users if the goal is consistency and timeout safety.

If you must preserve an internal fast path:

- keep synchronous direct create only for internal admin tools
- do not use it from mobile event upload

### 3. Add processing pipeline step

Introduce an async processor for event submissions:

`processing -> reviewing`

Responsibilities:

- normalize payload
- validate large lineup/timetable
- catch non-review failures early
- optionally rewrite payload snapshot into normalized form

### 4. Keep approval as the entity creation moment

Actual `event` creation should happen on approval:

- `reviewing -> approved`

This already fits the current admin review mental model.

### 5. Extend inbox payload schema

Current content review notification metadata should support:

- `submissionId`
- `entityType`
- `status`
- `reason`
- `createdEntityId`
- `transition`

Where `transition` examples are:

- `submitted_to_processing`
- `processing_to_reviewing`
- `reviewing_to_approved`
- `reviewing_to_rejected`
- `processing_to_failed`


## Data Model Recommendation

### Minimal-change option

Reuse `content_submissions` and add fields:

- `status`
- `processingStartedAt`
- `processingFinishedAt`
- `reviewQueuedAt`
- `approvedAt`
- `failedAt`
- `failureCode`
- `failureMessage`
- `sourceDraftId`
- `normalizedPayload`

This is the recommended first implementation because it reuses existing surfaces.

### Optional future-hardening

If processing grows complex, add:

- `content_submission_jobs`
- `content_submission_job_attempts`

But this is not required for the first commercialized rollout.


## State Transition Table

### Happy path

1. User submits event draft
2. `contentSubmission.status = processing`
3. inbox notification: `处理中`
4. async processor validates and normalizes payload
5. `contentSubmission.status = reviewing`
6. inbox notification: `审核中`
7. admin approves
8. create canonical event and related records
9. `contentSubmission.status = approved`
10. write `createdEntityId`
11. inbox notification: `已入库`

### Review rejection path

1. `reviewing`
2. admin rejects
3. `rejected`
4. inbox notification: `未通过`

### System failure path

1. `processing`
2. machine validation or ingestion prep fails
3. `failed`
4. inbox notification: `处理失败`


## Why This Design Is Reasonable

Yes, this design is reasonable.

It is especially reasonable for your current codebase because it:

- avoids giant synchronous create-event requests
- preserves current `My Publishes` mental model
- preserves current review box mental model
- removes the need for client polling
- gives users a clear task lifecycle
- keeps event visibility gated until actual ingestion

The only important caveat is:

- current inbox and status model are still too narrow

So the design is good, but it requires a deliberate status model upgrade, not just a UI text change.


## Implementation Order

### Step 1

Upgrade backend submission statuses and compatibility mapping:

- `pending -> reviewing`
- support `processing`, `failed`

### Step 2

Change event upload submit path:

- mobile submit always creates submission task immediately
- no synchronous event creation in mobile path

### Step 3

Add async event submission processor:

- `processing -> reviewing`
- emits inbox notification

### Step 4

Extend content review inbox projection:

- include `processing`
- include `reviewing`
- include `approved`
- include `rejected`
- include `failed`

### Step 5

Update `My Publishes` status labels and filters.

### Step 6

Ensure `approved` is the only state that exposes the event to:

- search
- event list
- public detail routing


## Non-Goals For This Iteration

- No requirement for upload-page live polling
- No requirement for a second task center separate from `My Publishes`
- No requirement to make remote draft the canonical editing store on day one


## Final Recommendation

Adopt this as the event upload V2 commercial flow:

- local draft for editing
- immediate submission task on submit
- async `processing -> reviewing -> approved`
- notifications through content review inbox
- `My Publishes` as the authoritative user task history
- public event visibility only after `approved / 已入库`

This is the closest long-term solution to your current architecture with the least conceptual waste.
