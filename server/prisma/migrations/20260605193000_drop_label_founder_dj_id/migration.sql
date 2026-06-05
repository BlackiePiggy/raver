-- Backfill from legacy column before dropping
UPDATE "labels"
SET "founder_dj_ids" = ARRAY["founder_dj_id"]
WHERE COALESCE(array_length("founder_dj_ids", 1), 0) = 0
  AND "founder_dj_id" IS NOT NULL;

-- DropForeignKey
ALTER TABLE "labels"
DROP CONSTRAINT IF EXISTS "labels_founder_dj_id_fkey";

-- DropIndex
DROP INDEX IF EXISTS "labels_founder_dj_id_idx";

-- AlterTable
ALTER TABLE "labels"
DROP COLUMN IF EXISTS "founder_dj_id";
