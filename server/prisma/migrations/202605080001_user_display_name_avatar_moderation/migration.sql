ALTER TABLE "users"
  ADD COLUMN IF NOT EXISTS "display_name_normalized" TEXT,
  ADD COLUMN IF NOT EXISTS "display_name_status" TEXT NOT NULL DEFAULT 'pending',
  ADD COLUMN IF NOT EXISTS "display_name_review_note" TEXT,
  ADD COLUMN IF NOT EXISTS "avatar_status" TEXT NOT NULL DEFAULT 'none',
  ADD COLUMN IF NOT EXISTS "avatar_review_note" TEXT;

UPDATE "users"
SET "display_name_normalized" = ranked.normalized
FROM (
  SELECT
    "id",
    lower(trim("display_name")) AS normalized,
    row_number() OVER (PARTITION BY lower(trim("display_name")) ORDER BY "created_at" ASC, "id" ASC) AS rn
  FROM "users"
  WHERE "display_name" IS NOT NULL
    AND trim("display_name") <> ''
) AS ranked
WHERE "users"."id" = ranked."id"
  AND ranked.rn = 1
  AND "users"."display_name_normalized" IS NULL;

CREATE UNIQUE INDEX IF NOT EXISTS "users_display_name_normalized_key"
  ON "users" ("display_name_normalized");

CREATE TABLE IF NOT EXISTS "user_profile_moderation_jobs" (
  "id" TEXT NOT NULL,
  "user_id" TEXT NOT NULL,
  "target_type" TEXT NOT NULL,
  "target_value" TEXT NOT NULL,
  "normalized_value" TEXT,
  "status" TEXT NOT NULL DEFAULT 'pending',
  "reason" TEXT,
  "provider" TEXT NOT NULL DEFAULT 'manual_review',
  "decision_detail" JSONB,
  "reviewed_at" TIMESTAMP(3),
  "reviewed_by" TEXT,
  "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "user_profile_moderation_jobs_pkey" PRIMARY KEY ("id")
);

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'user_profile_moderation_jobs_user_id_fkey'
  ) THEN
    ALTER TABLE "user_profile_moderation_jobs"
      ADD CONSTRAINT "user_profile_moderation_jobs_user_id_fkey"
      FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS "user_profile_moderation_jobs_user_id_target_type_created_at_idx"
  ON "user_profile_moderation_jobs" ("user_id", "target_type", "created_at");

CREATE INDEX IF NOT EXISTS "user_profile_moderation_jobs_status_created_at_idx"
  ON "user_profile_moderation_jobs" ("status", "created_at");
