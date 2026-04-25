CREATE TABLE IF NOT EXISTS "openim_sync_jobs" (
  "id" TEXT NOT NULL,
  "dedupe_key" TEXT NOT NULL,
  "job_type" TEXT NOT NULL,
  "entity_type" TEXT NOT NULL,
  "entity_id" TEXT NOT NULL,
  "payload" JSONB,
  "status" TEXT NOT NULL DEFAULT 'pending',
  "attempts" INTEGER NOT NULL DEFAULT 0,
  "max_attempts" INTEGER NOT NULL DEFAULT 5,
  "next_run_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "locked_at" TIMESTAMP(3),
  "locked_by" TEXT,
  "last_error" TEXT,
  "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "openim_sync_jobs_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX IF NOT EXISTS "openim_sync_jobs_dedupe_key_key"
  ON "openim_sync_jobs"("dedupe_key");

CREATE INDEX IF NOT EXISTS "openim_sync_jobs_status_next_run_at_idx"
  ON "openim_sync_jobs"("status", "next_run_at");

CREATE INDEX IF NOT EXISTS "openim_sync_jobs_entity_type_entity_id_idx"
  ON "openim_sync_jobs"("entity_type", "entity_id");

CREATE INDEX IF NOT EXISTS "openim_sync_jobs_created_at_idx"
  ON "openim_sync_jobs"("created_at");
