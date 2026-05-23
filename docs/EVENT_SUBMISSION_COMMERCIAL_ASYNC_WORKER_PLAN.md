# Event Submission Commercial Async Worker Plan

## Purpose

This document defines the commercial-grade architecture for event submission processing.

## Implementation Progress

- [x] 2026-05-23: Created the durable `content_submission_processing_jobs` table and Prisma model.
- [x] 2026-05-23: Replaced in-process `setImmediate` processing with idempotent durable enqueue.
- [x] 2026-05-23: Added standalone content submission worker entrypoints and package scripts.
- [x] 2026-05-23: Applied the migration to the current database.
- [x] 2026-05-23: Verified `pnpm build` and `pnpm content-submissions:worker:once`.
- [x] 2026-05-23: Added queue health status reporting through the admin status aggregation and `pnpm content-submissions:status`.
- [x] 2026-05-23: Updated `deploy-update.sh` to start/restart the long-running PM2 content submission worker.
- [ ] Start one long-running worker process in the target deployment environment.
- [ ] Run a large event submission smoke test while browsing unrelated app pages.

The immediate problem is that event upload tasks are currently only "pseudo async":

- The API returns quickly.
- The heavy task is still scheduled by `setImmediate` inside the same API process.
- Event ingestion still runs large lineup/timetable writes in the online service process.
- Other app pages can become slow or unavailable while a large event task is running.

The target is to make event upload processing a real background workload:

- API requests stay fast and predictable.
- Heavy event processing runs in isolated worker processes.
- The app receives state changes through `My Publishes` and review inbox notifications.
- Admin submissions also use the same task system, with auto-approval handled by workers.
- Failed tasks are retryable, observable, and recoverable without blocking normal app traffic.

## Current Problem

### Current Flow

The current submission path is roughly:

1. Client submits event payload.
2. API creates `contentSubmission`.
3. API publishes `processing` notification.
4. API calls `scheduleContentSubmissionProcessingBestEffort(submission.id)`.
5. `setImmediate` runs `processContentSubmission` inside the same API process.
6. Admin/operator submissions call `createOrUpdateEventFromSubmission` directly during processing.
7. Large lineup/timetable ingestion runs inside Prisma transactions.

### Why Other Pages Are Blocked

The online API process is doing two jobs at once:

- Serving normal app requests such as feeds, event list, search, profile, inbox.
- Running CPU, DB, and transaction-heavy event ingestion.

This creates several production risks:

- Prisma connection pool contention.
- Database lock contention from large write transactions.
- Node event loop pressure in the API process.
- Higher latency for unrelated pages.
- API instance memory and CPU spikes.
- No durable retry if the process restarts after `setImmediate` is scheduled.
- No clean way to throttle event ingestion independently from app traffic.

In production terms, the issue is not only that event processing is slow. The issue is that slow work is running in the online request serving tier.

## Architecture Decision

Use a durable database-backed job table first, and run content submission processors in independent worker processes.

This is the recommended first commercial step because the codebase already has:

- PostgreSQL and Prisma as core dependencies.
- `contentSubmission` as the canonical user-facing task model.
- `server/src/jobs` as the target home for workers.
- Existing examples of database-backed worker patterns, such as Check-in projection outbox.
- Existing notification center and review inbox state delivery.

Redis/BullMQ can be introduced later if throughput grows, but it is not required for the first commercial-grade isolation step.

## Target Runtime Topology

```text
iOS App / Admin / Web
        |
        v
Express API/BFF process
        |
        | 1. create contentSubmission
        | 2. enqueue contentSubmissionProcessingJob
        | 3. return immediately
        v
PostgreSQL
        ^
        |
Content Submission Worker process
        |
        | 1. claim queued jobs
        | 2. run processing/ingestion
        | 3. update submission status
        | 4. emit inbox/APNs notifications
        v
Notification Center
```

The API process must not execute event ingestion directly.

## Design Goals

- Keep event submission API p95 low even for very large lineup/timetable payloads.
- Make task processing durable across API restarts.
- Isolate worker CPU, memory, database pool, and concurrency from online traffic.
- Preserve existing user-facing states:
  - `processing`
  - `reviewing`
  - `approved`
  - `rejected`
  - `failed`
- Preserve admin auto-approval semantics.
- Ensure public event list/search/detail only show events after successful ingestion.
- Make failures visible in `My Publishes` and review inbox.
- Make operators able to inspect, retry, and pause workers.

## Non-Goals

- Do not introduce a separate user-facing task model.
- Do not require client polling from the upload screen.
- Do not make iOS responsible for retrying processing.
- Do not put heavy task execution behind request-time API routes.
- Do not rewrite the whole submission/review system.

## Core Data Model

### Existing `ContentSubmission`

Continue using `content_submissions` as the user-facing task record.

Recommended status semantics:

| Status | Meaning | User Label |
| --- | --- | --- |
| `processing` | Worker has accepted or is preparing the submission | 处理中 |
| `reviewing` | Machine processing succeeded; waiting review or auto-ingest | 审核中 / 处理完成 |
| `approved` | Canonical content has been created/updated | 已入库 |
| `rejected` | Human or policy review rejected the submission | 审核未通过 |
| `failed` | System processing failed | 处理失败 |
| `cancelled` | User/operator cancelled before completion | 已取消 |

### New `ContentSubmissionProcessingJob`

Add a dedicated durable job table.

Recommended Prisma model:

```prisma
model ContentSubmissionProcessingJob {
  id             String    @id @default(uuid())
  submissionId   String    @map("submission_id")
  jobType        String    @default("process_submission") @map("job_type")
  status         String    @default("queued")
  priority       Int       @default(0)
  attempts       Int       @default(0)
  maxAttempts    Int       @default(3) @map("max_attempts")
  lockedBy       String?   @map("locked_by")
  lockedAt       DateTime? @map("locked_at")
  availableAt    DateTime  @default(now()) @map("available_at")
  startedAt      DateTime? @map("started_at")
  completedAt    DateTime? @map("completed_at")
  failedAt       DateTime? @map("failed_at")
  lastError      String?   @map("last_error") @db.Text
  metadata       Json?
  createdAt      DateTime  @default(now()) @map("created_at")
  updatedAt      DateTime  @updatedAt @map("updated_at")

  submission ContentSubmission @relation(fields: [submissionId], references: [id], onDelete: Cascade)

  @@unique([submissionId, jobType])
  @@index([status, availableAt, priority])
  @@index([lockedAt])
  @@index([submissionId])
  @@map("content_submission_processing_jobs")
}
```

Recommended job statuses:

| Status | Meaning |
| --- | --- |
| `queued` | Ready to be picked up |
| `running` | Claimed by one worker |
| `retrying` | Failed but scheduled for retry |
| `succeeded` | Finished successfully |
| `failed` | Exhausted retries or non-retryable failure |
| `cancelled` | Cancelled by operator or superseded submission |

### Optional Submission Columns

Add these only if operator UX needs them:

```prisma
processingStartedAt DateTime? @map("processing_started_at")
processingEndedAt   DateTime? @map("processing_ended_at")
lastProcessingJobId String?   @map("last_processing_job_id")
```

The job table alone is enough for the first implementation.

## API Contract

### Submit Event

The API should only:

1. Validate required request shape.
2. Create or update `contentSubmission`.
3. Create `ContentSubmissionProcessingJob`.
4. Publish `processing` notification.
5. Return immediately.

The API should not call `processContentSubmission` or `createOrUpdateEventFromSubmission`.

Recommended response:

```json
{
  "message": "任务已提交，当前正在处理中",
  "submission": {
    "id": "submission-id",
    "status": "processing"
  },
  "job": {
    "id": "job-id",
    "status": "queued"
  }
}
```

### Resubmit / Edit Event

For edit submissions:

- Create a new `ContentSubmissionVersion`.
- Set submission status back to `processing`.
- Cancel any queued/running obsolete job when safe.
- Enqueue a new job or reuse the unique `submissionId + jobType` job by resetting it to `queued`.

If an older job is already running, it must become stale-safe:

- Worker reads the latest submission version before executing.
- Worker checks job status before committing final result.
- Worker should avoid writing results if the submission was superseded.

## Worker Design

### Worker Entrypoints

Add:

```text
server/src/jobs/content-submission/processing-worker.job.ts
server/src/scripts/content-submission-processing-worker-run.ts
```

Recommended package scripts:

```json
{
  "content-submissions:worker:once": "ts-node src/scripts/content-submission-processing-worker-run.ts",
  "content-submissions:worker": "CONTENT_SUBMISSION_WORKER_LOOP=1 ts-node src/scripts/content-submission-processing-worker-run.ts"
}
```

### Claiming Jobs

Worker should claim jobs with a short transaction:

1. Find jobs where:
   - `status in ('queued', 'retrying')`
   - `availableAt <= now`
2. Order by:
   - `priority desc`
   - `availableAt asc`
   - `createdAt asc`
3. Claim with `updateMany` guard:
   - `where id = job.id`
   - `status in ('queued', 'retrying')`
4. Set:
   - `status = 'running'`
   - `lockedBy = workerId`
   - `lockedAt = now`
   - `startedAt = now` if null
   - `attempts += 1`

This prevents two workers from processing the same job.

### Concurrency

Recommended defaults:

```text
CONTENT_SUBMISSION_WORKER_CONCURRENCY=1
CONTENT_SUBMISSION_WORKER_BATCH_SIZE=1
CONTENT_SUBMISSION_WORKER_INTERVAL_MS=2000
CONTENT_SUBMISSION_WORKER_STALE_LOCK_MS=900000
CONTENT_SUBMISSION_WORKER_MAX_ATTEMPTS=3
```

For event ingestion, start with concurrency `1`.

Raise to `2` only after observing DB locks, p95 API latency, worker duration, and queue depth.

### Worker Flow

For each claimed job:

1. Load `ContentSubmission`.
2. If missing, mark job `failed`.
3. If submission is no longer `processing` or legacy `pending`, mark job `cancelled` or `succeeded` as no-op.
4. Validate payload shape.
5. Run machine processing.
6. Move submission to `reviewing`.
7. Publish `reviewing` notification.
8. If admin/operator event submission:
   - publish `处理完成` label for review inbox.
   - run auto-ingest.
   - mark submission `approved`.
   - publish `已入库` notification.
9. If normal user:
   - stop at `reviewing`.
   - wait for human/admin review.
10. Mark job `succeeded`.

### Failure Handling

Classify errors into retryable and non-retryable.

Retryable examples:

- transient DB timeout
- network timeout to third-party enrichment
- temporary object storage failure

Non-retryable examples:

- invalid payload
- missing required image
- target event does not exist
- unsupported entity type

Retry policy:

```text
attempt 1: retry after 1 minute
attempt 2: retry after 5 minutes
attempt 3: mark failed
```

When final failure occurs:

- Set job `failed`.
- Set submission `failed`.
- Store `reviewReason`.
- Publish `处理失败` notification.

## Transaction Strategy

The current event ingestion transaction can hold locks for too long.

Recommended refactor:

1. Keep submission status updates in short transactions.
2. Keep job claim/finish in short transactions.
3. Keep event canonical writes in a dedicated ingestion transaction.
4. Reduce ingestion transaction scope over time.

### First Implementation

Move existing `createOrUpdateEventFromSubmission` into worker execution without changing its internals.

This immediately isolates API traffic from heavy work.

### Second Implementation

Optimize event ingestion:

- Use `createMany` for bulk stages/artists/members/performances.
- Diff lineup/timetable instead of always full `deleteMany`.
- Avoid deleting and recreating unchanged rows.
- Add indexes needed by delete/update filters.
- Consider chunked writes for very large timetables.

### Lock Safety

For editing an existing event:

- Only one active ingestion job per target event should run at a time.
- Add worker-level advisory lock or DB guard by `targetEventId`.
- If a newer submission exists for the same target event, older queued jobs should be cancelled.

## API and Worker Resource Isolation

### Process Separation

Run at least two process types:

```text
api:
  command: pnpm start
  replicas: 2+

content-submission-worker:
  command: pnpm content-submissions:worker
  replicas: 1 initially
```

### Prisma Connection Pools

Use different `DATABASE_URL` connection limits:

```text
API_DATABASE_URL=postgresql://...?connection_limit=10&pool_timeout=10
WORKER_DATABASE_URL=postgresql://...?connection_limit=2&pool_timeout=30
```

If the app currently uses a single `DATABASE_URL`, introduce:

```text
DATABASE_URL
WORKER_DATABASE_URL
```

Workers should create PrismaClient from `WORKER_DATABASE_URL` when present.

### Database Priority

Normal app traffic must win over worker traffic.

Recommended guardrails:

- Keep worker concurrency low.
- Use a smaller worker DB pool than API pool.
- Add queue depth alerts instead of raising concurrency blindly.
- Prefer horizontal API replicas before increasing worker parallelism.

## Notification Semantics

Continue using the review inbox as the user-facing state stream.

Required notifications:

| Transition | Inbox Label | Color |
| --- | --- | --- |
| task created | 处理中 | yellow |
| worker processing succeeded | 审核中 | green |
| admin processing succeeded | 处理完成 | green |
| ingest approved | 已入库 | green |
| processor failed | 处理失败 | red |
| human rejected | 审核未通过 | red |

The worker must be the only place that emits processing completion/failure notifications.

The API should only emit task-created `processing` notification.

## Admin Auto-Approval

Admin/operator event submissions follow the same job flow:

```text
processing -> reviewing(label: 处理完成) -> approved
```

They do not bypass the queue.

They do not require human review.

They still send all review inbox notifications to the submitting admin account.

## Human Review Flow

Normal user submissions follow:

```text
processing -> reviewing -> approved/rejected
```

Admin approval route should:

1. Validate submission is `reviewing`.
2. Enqueue an `ingest_approved_submission` job or run a dedicated approval worker job.
3. Return quickly to admin UI.
4. Worker creates/updates canonical event.
5. Worker marks submission `approved`.
6. Worker publishes `已入库`.

For the first version, approval can enqueue the same job table with `jobType = 'ingest_approved_submission'`.

This avoids moving the heavy canonical event write back into the admin API request.

## Observability

### Metrics

Track:

- `content_submission_jobs_queued`
- `content_submission_jobs_running`
- `content_submission_jobs_failed`
- `content_submission_oldest_queued_age_seconds`
- `content_submission_job_duration_ms`
- `content_submission_job_attempts`
- `content_submission_worker_last_heartbeat_at`
- API p95/p99 latency for unrelated pages during worker activity
- DB pool wait time
- DB lock wait time if available

### Logs

Every job log line should include:

- `jobId`
- `submissionId`
- `entityType`
- `targetEventId` when available
- `attempt`
- `workerId`
- `durationMs`
- `status`
- `errorCode` when failed

### Admin Status

Extend existing admin status page to show:

- worker enabled/disabled
- queue depth
- oldest queued age
- running jobs
- failed jobs in last 24h
- stale locks
- last worker heartbeat

No admin status endpoint should execute jobs directly.

## Operations

### Pause Worker

Set:

```text
CONTENT_SUBMISSION_WORKER_ENABLED=false
```

API can continue accepting submissions. Jobs accumulate in `queued`.

### Drain Queue

Run worker with:

```text
CONTENT_SUBMISSION_WORKER_CONCURRENCY=1
pnpm content-submissions:worker
```

Monitor oldest queued age and failed count.

### Retry Failed Job

Operator action:

1. Check `lastError`.
2. Fix data/code/config.
3. Reset job:
   - `status = 'queued'`
   - `availableAt = now`
   - optionally `attempts = 0`
4. Set submission back to `processing` if it was marked `failed`.
5. Publish or rely on worker to publish updated state.

### Clear Stale Running Job

If `lockedAt` is older than `CONTENT_SUBMISSION_WORKER_STALE_LOCK_MS`:

- reset `running` to `retrying`
- clear `lockedBy`
- set `availableAt = now`
- append stale lock note to metadata

## Deployment Plan

### Phase 0: Preparation

- [x] Add this design document.
- [ ] Confirm production has capacity for one worker process.
- [ ] Confirm DB connection budget for API and worker pools.
- [ ] Decide whether `WORKER_DATABASE_URL` will be a separate env var.

### Phase 1: Durable Job Table

- [x] Add Prisma model `ContentSubmissionProcessingJob`.
- [x] Generate and apply migration.
- [x] Add enqueue service.
- [x] Add idempotent enqueue by `submissionId + jobType`.
- [x] Add job query indexes.

### Phase 2: Worker Skeleton

- [x] Add `server/src/jobs/content-submission/processing-worker.job.ts`.
- [x] Add `server/src/scripts/content-submission-processing-worker-run.ts`.
- [x] Add package scripts.
- [x] Implement claim, run, finish, retry, stale lock handling.
- [x] Keep worker disabled in production until smoke tested.

### Phase 3: Remove API In-Process Processing

- [x] Replace `scheduleContentSubmissionProcessingBestEffort` calls with durable enqueue.
- [x] Keep `scheduleContentSubmissionProcessingBestEffort` as a temporary compatibility wrapper that only enqueues.
- [x] Ensure API never calls `processContentSubmission` directly.
- [x] Ensure event create/edit routes return immediately after enqueue.

### Phase 4: Move Admin Auto-Approval Into Worker

- [ ] Admin create/edit uses same queued job path.
- [ ] Worker handles admin `处理完成 -> 已入库`.
- [ ] Admin review approval route enqueues ingestion job instead of running ingestion inline.

### Phase 5: Production Rollout

- [x] Deploy DB migration.
- [x] Deploy API with enqueue path.
- [x] Start one worker replica.
- [ ] Set worker concurrency to `1`.
- [ ] Submit a small event as admin.
- [ ] Submit a large lineup/timetable event as admin.
- [ ] Verify unrelated app pages load normally during worker execution.
- [ ] Submit a normal user event and verify it stops at `reviewing`.
- [ ] Approve normal user event and verify ingestion happens via worker.

### Phase 6: Optimization

- [ ] Add bulk `createMany` where missing.
- [ ] Diff lineup/timetable writes.
- [ ] Add target event serialization.
- [ ] Add admin retry controls.
- [ ] Add queue metrics to admin status.
- [ ] Add alerting for oldest queued age and failed jobs.

## Rollback Plan

If worker rollout has problems:

1. Stop worker process.
2. API continues accepting submissions into `queued`.
3. Users see tasks in `processing`.
4. Fix worker and restart.

If enqueue path itself has problems:

1. Temporarily disable event submission endpoint or gate event submit.
2. Do not restore in-process processing as the default.
3. For emergency operator-only ingestion, run a one-off worker script against a specific submission ID.

## Acceptance Criteria

The implementation is commercially acceptable when:

- Submitting a large event returns in under 1 second after payload upload reaches the API.
- Other app pages remain loadable while a large event task is processing.
- API process CPU and DB pool usage remain stable during worker execution.
- Worker can restart without losing queued jobs.
- A failed processing task becomes visible as `处理失败` in inbox and `My Publishes`.
- Admin event task emits `处理中 -> 处理完成 -> 已入库`.
- Normal user event task emits `处理中 -> 审核中`, then `已入库` or `审核未通过`.
- Public event list/search/detail only show the event after `approved`.
- Queue depth, oldest queued age, running jobs, and failed jobs are observable.

## Recommended First Implementation Shape

Keep the first implementation deliberately small:

1. Add a DB-backed job table.
2. Move current `processContentSubmission` execution into a worker.
3. Replace `setImmediate` scheduling with durable enqueue.
4. Start one worker process with concurrency `1`.
5. Keep existing event ingestion logic initially.
6. Optimize ingestion transaction size after isolation is proven.

This gives the biggest production reliability gain with the smallest code risk.

## Open Decisions

These can be decided during implementation:

| Decision | Recommended Default |
| --- | --- |
| Queue backend | PostgreSQL job table first |
| Worker concurrency | `1` for event ingestion |
| Retry max attempts | `3` |
| Retry schedule | `1m`, `5m`, final failure |
| API fallback if enqueue fails | Return error; do not run heavy work inline |
| Worker deployment | Separate process/container |
| Admin approval ingestion | Enqueue worker job |
| Redis/BullMQ | Later, only if queue throughput requires it |
