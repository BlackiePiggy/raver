CREATE TABLE "content_submission_processing_jobs" (
  "id" TEXT NOT NULL,
  "submission_id" TEXT NOT NULL,
  "job_type" TEXT NOT NULL DEFAULT 'process_submission',
  "status" TEXT NOT NULL DEFAULT 'queued',
  "priority" INTEGER NOT NULL DEFAULT 0,
  "attempts" INTEGER NOT NULL DEFAULT 0,
  "max_attempts" INTEGER NOT NULL DEFAULT 3,
  "locked_by" TEXT,
  "locked_at" TIMESTAMP(3),
  "available_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "started_at" TIMESTAMP(3),
  "completed_at" TIMESTAMP(3),
  "failed_at" TIMESTAMP(3),
  "last_error" TEXT,
  "metadata" JSONB,
  "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" TIMESTAMP(3) NOT NULL,

  CONSTRAINT "content_submission_processing_jobs_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX "content_submission_processing_jobs_submission_id_job_type_key"
  ON "content_submission_processing_jobs"("submission_id", "job_type");

CREATE INDEX "content_submission_processing_jobs_status_available_at_priority_idx"
  ON "content_submission_processing_jobs"("status", "available_at", "priority");

CREATE INDEX "content_submission_processing_jobs_locked_at_idx"
  ON "content_submission_processing_jobs"("locked_at");

CREATE INDEX "content_submission_processing_jobs_submission_id_idx"
  ON "content_submission_processing_jobs"("submission_id");

ALTER TABLE "content_submission_processing_jobs"
  ADD CONSTRAINT "content_submission_processing_jobs_submission_id_fkey"
  FOREIGN KEY ("submission_id") REFERENCES "content_submissions"("id") ON DELETE CASCADE ON UPDATE CASCADE;
