ALTER TABLE "entity_change_logs"
  ADD COLUMN IF NOT EXISTS "private_summary_ja" TEXT,
  ADD COLUMN IF NOT EXISTS "operator_summary_ja" TEXT,
  ADD COLUMN IF NOT EXISTS "public_summary_ja" TEXT;
