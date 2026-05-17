ALTER TABLE "media_assets"
  ADD COLUMN IF NOT EXISTS "purge_attempts" INTEGER NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS "purge_next_run_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  ADD COLUMN IF NOT EXISTS "purge_last_error" TEXT,
  ADD COLUMN IF NOT EXISTS "purged_at" TIMESTAMP(3);

CREATE INDEX IF NOT EXISTS "media_assets_status_purge_next_run_at_idx"
  ON "media_assets"("status", "purge_next_run_at");
