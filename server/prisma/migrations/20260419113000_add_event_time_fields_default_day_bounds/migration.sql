ALTER TABLE "events"
  ADD COLUMN IF NOT EXISTS "start_time" TEXT NOT NULL DEFAULT '00:00:00',
  ADD COLUMN IF NOT EXISTS "end_time" TEXT NOT NULL DEFAULT '23:59:59';

UPDATE "events"
SET
  "start_date" = date_trunc('day', "start_date"),
  "end_date" = date_trunc('day', "end_date") + interval '1 day' - interval '1 second',
  "start_time" = COALESCE(NULLIF("start_time", ''), '00:00:00'),
  "end_time" = COALESCE(NULLIF("end_time", ''), '23:59:59');
