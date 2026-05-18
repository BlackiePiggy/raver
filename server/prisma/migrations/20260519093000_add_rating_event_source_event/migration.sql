ALTER TABLE "rating_events"
ADD COLUMN IF NOT EXISTS "source_event_id" TEXT;

CREATE INDEX IF NOT EXISTS "rating_events_source_event_id_idx"
ON "rating_events"("source_event_id");

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'rating_events_source_event_id_fkey'
  ) THEN
    ALTER TABLE "rating_events"
    ADD CONSTRAINT "rating_events_source_event_id_fkey"
    FOREIGN KEY ("source_event_id") REFERENCES "events"("id")
    ON DELETE SET NULL ON UPDATE CASCADE;
  END IF;
END $$;

UPDATE "rating_events"
SET "source_event_id" = '981b09d7-e8b3-417e-a5d5-6a4c4a70c076'
WHERE "id" = 'b3322d49-bc5a-4db2-9cae-6c683977905a'
  AND EXISTS (
    SELECT 1
    FROM "events"
    WHERE "id" = '981b09d7-e8b3-417e-a5d5-6a4c4a70c076'
  );
