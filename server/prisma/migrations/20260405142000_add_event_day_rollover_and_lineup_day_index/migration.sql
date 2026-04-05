-- Add event-level rollover hour for logical festival day grouping
ALTER TABLE "events"
  ADD COLUMN IF NOT EXISTS "day_rollover_hour" INTEGER NOT NULL DEFAULT 6;

-- Add lineup slot logical day index (Day1/Day2...) independent from calendar date
ALTER TABLE "event_lineup_slots"
  ADD COLUMN IF NOT EXISTS "festival_day_index" INTEGER;

CREATE INDEX IF NOT EXISTS "event_lineup_slots_event_id_festival_day_index_idx"
  ON "event_lineup_slots" ("event_id", "festival_day_index");

-- Backfill festival_day_index using slot start_time + event start_date + rollover rule
UPDATE "event_lineup_slots" AS slot
SET "festival_day_index" = GREATEST(
  1,
  (
    (
      DATE_PART(
        'day',
        DATE_TRUNC('day', slot."start_time") - DATE_TRUNC('day', evt."start_date")
      )::int
      + 1
    )
    - CASE
        WHEN DATE_TRUNC('day', slot."start_time") > DATE_TRUNC('day', evt."start_date")
         AND EXTRACT(HOUR FROM slot."start_time") < evt."day_rollover_hour"
          THEN 1
        ELSE 0
      END
  )
)
FROM "events" AS evt
WHERE slot."event_id" = evt."id"
  AND slot."festival_day_index" IS NULL;
