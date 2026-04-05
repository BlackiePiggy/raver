-- Add nullable event -> wiki festival binding
ALTER TABLE "events"
  ADD COLUMN IF NOT EXISTS "wiki_festival_id" TEXT;

-- Index for lookup/filtering
CREATE INDEX IF NOT EXISTS "events_wiki_festival_id_idx"
  ON "events"("wiki_festival_id");

-- FK with SetNull on brand delete
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'events_wiki_festival_id_fkey'
  ) THEN
    ALTER TABLE "events"
      ADD CONSTRAINT "events_wiki_festival_id_fkey"
      FOREIGN KEY ("wiki_festival_id") REFERENCES "wiki_festivals"("id")
      ON DELETE SET NULL ON UPDATE CASCADE;
  END IF;
END $$;
