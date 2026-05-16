ALTER TABLE "genres" DROP CONSTRAINT IF EXISTS "genres_name_key";

ALTER TABLE "genres"
  ADD COLUMN IF NOT EXISTS "path" TEXT,
  ADD COLUMN IF NOT EXISTS "example" TEXT,
  ADD COLUMN IF NOT EXISTS "spotify_track_url" TEXT,
  ADD COLUMN IF NOT EXISTS "wikipedia_url" TEXT,
  ADD COLUMN IF NOT EXISTS "key_artists" TEXT[] NOT NULL DEFAULT ARRAY[]::TEXT[],
  ADD COLUMN IF NOT EXISTS "sort_order" INTEGER NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS "updated_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP;

UPDATE "genres"
SET "path" = COALESCE("path", "slug");

ALTER TABLE "genres"
  ALTER COLUMN "path" SET NOT NULL,
  ALTER COLUMN "description" TYPE TEXT;

CREATE UNIQUE INDEX IF NOT EXISTS "genres_path_key" ON "genres"("path");
CREATE INDEX IF NOT EXISTS "genres_parent_id_sort_order_idx" ON "genres"("parent_id", "sort_order");
