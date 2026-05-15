CREATE TABLE "dj_enrichment_jobs" (
    "id" TEXT NOT NULL,
    "requested_by_id" TEXT NOT NULL,
    "status" TEXT NOT NULL DEFAULT 'pending',
    "apply_mode" TEXT NOT NULL DEFAULT 'review_required',
    "total_count" INTEGER NOT NULL DEFAULT 0,
    "queued_count" INTEGER NOT NULL DEFAULT 0,
    "running_count" INTEGER NOT NULL DEFAULT 0,
    "success_count" INTEGER NOT NULL DEFAULT 0,
    "failed_count" INTEGER NOT NULL DEFAULT 0,
    "reviewed_count" INTEGER NOT NULL DEFAULT 0,
    "started_at" TIMESTAMP(3),
    "completed_at" TIMESTAMP(3),
    "last_error" TEXT,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,
    CONSTRAINT "dj_enrichment_jobs_pkey" PRIMARY KEY ("id")
);

CREATE TABLE "dj_enrichment_results" (
    "id" TEXT NOT NULL,
    "job_id" TEXT NOT NULL,
    "dj_id" TEXT,
    "input_name" TEXT NOT NULL,
    "status" TEXT NOT NULL DEFAULT 'queued',
    "apply_status" TEXT NOT NULL DEFAULT 'pending_review',
    "input_payload" JSONB NOT NULL,
    "normalized_result" JSONB,
    "coze_raw_response" JSONB,
    "match_confidence" DOUBLE PRECISION,
    "is_match_confident" BOOLEAN NOT NULL DEFAULT false,
    "electronic_confidence" DOUBLE PRECISION,
    "is_electronic_dj_confident" BOOLEAN NOT NULL DEFAULT false,
    "genre_confidence" DOUBLE PRECISION,
    "should_apply_genres" BOOLEAN NOT NULL DEFAULT false,
    "review_reason" TEXT,
    "review_notes" JSONB,
    "reviewed_at" TIMESTAMP(3),
    "reviewed_by_id" TEXT,
    "applied_at" TIMESTAMP(3),
    "apply_summary" JSONB,
    "error_message" TEXT,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,
    CONSTRAINT "dj_enrichment_results_pkey" PRIMARY KEY ("id")
);

CREATE INDEX "dj_enrichment_jobs_requested_by_id_created_at_idx" ON "dj_enrichment_jobs"("requested_by_id", "created_at");
CREATE INDEX "dj_enrichment_jobs_status_created_at_idx" ON "dj_enrichment_jobs"("status", "created_at");
CREATE INDEX "dj_enrichment_results_job_id_created_at_idx" ON "dj_enrichment_results"("job_id", "created_at");
CREATE INDEX "dj_enrichment_results_dj_id_created_at_idx" ON "dj_enrichment_results"("dj_id", "created_at");
CREATE INDEX "dj_enrichment_results_status_apply_status_created_at_idx" ON "dj_enrichment_results"("status", "apply_status", "created_at");
CREATE INDEX "dj_enrichment_results_reviewed_by_id_reviewed_at_idx" ON "dj_enrichment_results"("reviewed_by_id", "reviewed_at");

ALTER TABLE "dj_enrichment_jobs"
ADD CONSTRAINT "dj_enrichment_jobs_requested_by_id_fkey"
FOREIGN KEY ("requested_by_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "dj_enrichment_results"
ADD CONSTRAINT "dj_enrichment_results_job_id_fkey"
FOREIGN KEY ("job_id") REFERENCES "dj_enrichment_jobs"("id") ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "dj_enrichment_results"
ADD CONSTRAINT "dj_enrichment_results_dj_id_fkey"
FOREIGN KEY ("dj_id") REFERENCES "djs"("id") ON DELETE SET NULL ON UPDATE CASCADE;

ALTER TABLE "dj_enrichment_results"
ADD CONSTRAINT "dj_enrichment_results_reviewed_by_id_fkey"
FOREIGN KEY ("reviewed_by_id") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;
