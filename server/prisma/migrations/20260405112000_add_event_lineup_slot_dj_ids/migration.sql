ALTER TABLE "event_lineup_slots"
ADD COLUMN IF NOT EXISTS "dj_ids" TEXT[] NOT NULL DEFAULT ARRAY[]::TEXT[];

UPDATE "event_lineup_slots"
SET "dj_ids" = ARRAY["dj_id"]::TEXT[]
WHERE "dj_id" IS NOT NULL
  AND COALESCE(array_length("dj_ids", 1), 0) = 0;
