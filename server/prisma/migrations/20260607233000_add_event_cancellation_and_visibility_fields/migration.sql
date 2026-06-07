-- Historical one-time backfill from the removed event status column into the
-- final truth fields. Keep as migration history/reference only; new production
-- writes must set is_cancelled + visibility directly.
ALTER TABLE "events"
ADD COLUMN "is_cancelled" BOOLEAN NOT NULL DEFAULT false,
ADD COLUMN "visibility" TEXT NOT NULL DEFAULT 'visible';

UPDATE "events"
SET
  "is_cancelled" = CASE
    WHEN lower(coalesce("status", '')) IN ('cancelled', 'canceled') THEN true
    ELSE false
  END,
  "visibility" = CASE
    WHEN lower(coalesce("status", '')) = 'hidden' THEN 'hidden'
    ELSE 'visible'
  END;
