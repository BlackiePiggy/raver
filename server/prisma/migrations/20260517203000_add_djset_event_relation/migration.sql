-- Add a strong optional event binding for DJ sets.
-- Existing rows intentionally remain NULL; event IDs can be populated manually later.
ALTER TABLE "dj_sets" ADD COLUMN IF NOT EXISTS "event_id" TEXT;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'dj_sets_event_id_fkey'
  ) THEN
    ALTER TABLE "dj_sets"
      ADD CONSTRAINT "dj_sets_event_id_fkey"
      FOREIGN KEY ("event_id") REFERENCES "events"("id")
      ON DELETE SET NULL ON UPDATE CASCADE;
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS "dj_sets_event_id_idx" ON "dj_sets"("event_id");
