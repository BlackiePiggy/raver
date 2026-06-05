-- AlterTable
ALTER TABLE "labels"
ADD COLUMN "founder_dj_ids" TEXT[] NOT NULL DEFAULT '{}';

-- Backfill
UPDATE "labels"
SET "founder_dj_ids" = ARRAY["founder_dj_id"]
WHERE "founder_dj_id" IS NOT NULL
  AND array_length("founder_dj_ids", 1) IS NULL;
