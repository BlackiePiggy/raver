ALTER TABLE "rating_units"
ADD COLUMN IF NOT EXISTS "dj_id" TEXT,
ADD COLUMN IF NOT EXISTS "dj_ids" TEXT[] NOT NULL DEFAULT ARRAY[]::TEXT[];

CREATE INDEX IF NOT EXISTS "rating_units_dj_id_idx"
ON "rating_units"("dj_id");

CREATE INDEX IF NOT EXISTS "rating_units_dj_ids_idx"
ON "rating_units" USING GIN ("dj_ids");

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'rating_units_dj_id_fkey'
  ) THEN
    ALTER TABLE "rating_units"
    ADD CONSTRAINT "rating_units_dj_id_fkey"
    FOREIGN KEY ("dj_id") REFERENCES "djs"("id")
    ON DELETE SET NULL ON UPDATE CASCADE;
  END IF;
END $$;
