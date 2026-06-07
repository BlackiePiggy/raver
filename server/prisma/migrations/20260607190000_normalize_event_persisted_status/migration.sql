-- Historical one-time normalization step for the removed event status column.
-- Keep as migration history/reference only; do not reuse this shape for new
-- production writes now that Event truth is is_cancelled + visibility.
UPDATE "events"
SET "status" = CASE
  WHEN lower(coalesce("status", '')) IN ('cancelled', 'canceled') THEN 'cancelled'
  WHEN lower(coalesce("status", '')) = 'hidden' THEN 'hidden'
  ELSE 'active'
END;

ALTER TABLE "events"
ALTER COLUMN "status" SET DEFAULT 'active';
