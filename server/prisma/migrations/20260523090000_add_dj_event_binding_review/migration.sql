CREATE TABLE "dj_event_binding_review_jobs" (
  "id" TEXT NOT NULL,
  "dj_id" TEXT NOT NULL,
  "dj_name_snapshot" TEXT NOT NULL,
  "trigger_source" TEXT NOT NULL,
  "status" TEXT NOT NULL DEFAULT 'pending',
  "exact_count" INTEGER NOT NULL DEFAULT 0,
  "fuzzy_count" INTEGER NOT NULL DEFAULT 0,
  "applied_count" INTEGER NOT NULL DEFAULT 0,
  "created_by_id" TEXT,
  "completed_at" TIMESTAMP(3),
  "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" TIMESTAMP(3) NOT NULL,

  CONSTRAINT "dj_event_binding_review_jobs_pkey" PRIMARY KEY ("id")
);

CREATE TABLE "dj_event_binding_review_candidates" (
  "id" TEXT NOT NULL,
  "job_id" TEXT NOT NULL,
  "dj_id" TEXT NOT NULL,
  "event_id" TEXT NOT NULL,
  "event_artist_id" TEXT,
  "event_artist_member_id" TEXT,
  "event_performance_id" TEXT,
  "source_type" TEXT NOT NULL,
  "match_tier" TEXT NOT NULL,
  "match_score" INTEGER NOT NULL DEFAULT 0,
  "match_reason" TEXT NOT NULL,
  "raw_name" TEXT NOT NULL,
  "normalized_key" TEXT NOT NULL,
  "compact_key" TEXT NOT NULL,
  "event_name_snapshot" TEXT NOT NULL,
  "stage_name_snapshot" TEXT,
  "start_at_snapshot" TIMESTAMP(3),
  "needs_split" BOOLEAN NOT NULL DEFAULT false,
  "status" TEXT NOT NULL DEFAULT 'pending',
  "applied_at" TIMESTAMP(3),
  "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" TIMESTAMP(3) NOT NULL,

  CONSTRAINT "dj_event_binding_review_candidates_pkey" PRIMARY KEY ("id")
);

CREATE INDEX "dj_event_binding_review_jobs_dj_id_created_at_idx"
  ON "dj_event_binding_review_jobs"("dj_id", "created_at");

CREATE INDEX "dj_event_binding_review_jobs_status_created_at_idx"
  ON "dj_event_binding_review_jobs"("status", "created_at");

CREATE UNIQUE INDEX "dj_event_binding_review_candidates_job_id_event_artist_id_event_artist_member_id_event_performance_id_raw_name_key"
  ON "dj_event_binding_review_candidates"("job_id", "event_artist_id", "event_artist_member_id", "event_performance_id", "raw_name");

CREATE INDEX "dj_event_binding_review_candidates_job_id_match_tier_status_idx"
  ON "dj_event_binding_review_candidates"("job_id", "match_tier", "status");

CREATE INDEX "dj_event_binding_review_candidates_dj_id_status_created_at_idx"
  ON "dj_event_binding_review_candidates"("dj_id", "status", "created_at");

CREATE INDEX "dj_event_binding_review_candidates_event_id_idx"
  ON "dj_event_binding_review_candidates"("event_id");

ALTER TABLE "dj_event_binding_review_jobs"
  ADD CONSTRAINT "dj_event_binding_review_jobs_dj_id_fkey"
  FOREIGN KEY ("dj_id") REFERENCES "djs"("id") ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "dj_event_binding_review_candidates"
  ADD CONSTRAINT "dj_event_binding_review_candidates_job_id_fkey"
  FOREIGN KEY ("job_id") REFERENCES "dj_event_binding_review_jobs"("id") ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "dj_event_binding_review_candidates"
  ADD CONSTRAINT "dj_event_binding_review_candidates_dj_id_fkey"
  FOREIGN KEY ("dj_id") REFERENCES "djs"("id") ON DELETE CASCADE ON UPDATE CASCADE;
