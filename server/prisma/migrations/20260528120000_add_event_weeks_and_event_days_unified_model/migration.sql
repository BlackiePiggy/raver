ALTER TABLE "events"
ADD COLUMN IF NOT EXISTS "schedule_mode" TEXT NOT NULL DEFAULT 'single_day';

CREATE TABLE IF NOT EXISTS "event_weeks" (
  "id" TEXT NOT NULL DEFAULT gen_random_uuid()::TEXT,
  "event_id" TEXT NOT NULL,
  "week_index" INTEGER NOT NULL,
  "label" TEXT,
  "start_date" DATE NOT NULL,
  "end_date" DATE NOT NULL,
  "sort_order" INTEGER NOT NULL DEFAULT 0,
  "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "event_weeks_pkey" PRIMARY KEY ("id"),
  CONSTRAINT "event_weeks_event_id_fkey" FOREIGN KEY ("event_id") REFERENCES "events"("id") ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE UNIQUE INDEX IF NOT EXISTS "event_weeks_event_week_index_key"
ON "event_weeks"("event_id", "week_index");

CREATE INDEX IF NOT EXISTS "event_weeks_event_sort_order_idx"
ON "event_weeks"("event_id", "sort_order");

CREATE TABLE IF NOT EXISTS "event_days" (
  "id" TEXT NOT NULL DEFAULT gen_random_uuid()::TEXT,
  "event_id" TEXT NOT NULL,
  "event_week_id" TEXT,
  "event_day_id" TEXT NOT NULL,
  "week_index" INTEGER NOT NULL,
  "day_index_in_week" INTEGER NOT NULL,
  "overall_day_index" INTEGER NOT NULL,
  "label" TEXT,
  "weekday" TEXT,
  "date" DATE NOT NULL,
  "sort_order" INTEGER NOT NULL DEFAULT 0,
  "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "event_days_pkey" PRIMARY KEY ("id"),
  CONSTRAINT "event_days_event_id_fkey" FOREIGN KEY ("event_id") REFERENCES "events"("id") ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT "event_days_event_week_id_fkey" FOREIGN KEY ("event_week_id") REFERENCES "event_weeks"("id") ON DELETE SET NULL ON UPDATE CASCADE
);

CREATE UNIQUE INDEX IF NOT EXISTS "event_days_event_event_day_id_key"
ON "event_days"("event_id", "event_day_id");

CREATE UNIQUE INDEX IF NOT EXISTS "event_days_event_overall_day_index_key"
ON "event_days"("event_id", "overall_day_index");

CREATE INDEX IF NOT EXISTS "event_days_event_week_day_idx"
ON "event_days"("event_id", "week_index", "day_index_in_week");

CREATE INDEX IF NOT EXISTS "event_days_event_week_sort_order_idx"
ON "event_days"("event_week_id", "sort_order");

ALTER TABLE "event_performances"
ADD COLUMN IF NOT EXISTS "event_day_id" TEXT,
ADD COLUMN IF NOT EXISTS "week_index" INTEGER,
ADD COLUMN IF NOT EXISTS "day_index_in_week" INTEGER,
ADD COLUMN IF NOT EXISTS "overall_day_index" INTEGER,
ADD COLUMN IF NOT EXISTS "local_date" DATE;

DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM information_schema.table_constraints
    WHERE constraint_name = 'event_performances_event_day_id_fkey'
      AND table_name = 'event_performances'
  ) THEN
    ALTER TABLE "event_performances"
    DROP CONSTRAINT "event_performances_event_day_id_fkey";
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM information_schema.table_constraints
    WHERE constraint_name = 'event_performances_event_id_event_day_id_fkey'
      AND table_name = 'event_performances'
  ) THEN
    ALTER TABLE "event_performances"
    ADD CONSTRAINT "event_performances_event_id_event_day_id_fkey"
    FOREIGN KEY ("event_id", "event_day_id") REFERENCES "event_days"("event_id", "event_day_id") ON DELETE SET NULL ON UPDATE CASCADE;
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS "event_performances_event_event_day_start_idx"
ON "event_performances"("event_id", "event_day_id", "start_at");

WITH inserted_weeks AS (
  INSERT INTO "event_weeks" (
    "event_id",
    "week_index",
    "label",
    "start_date",
    "end_date",
    "sort_order"
  )
  SELECT
    e."id",
    1,
    NULL,
    e."start_date"::date,
    e."end_date"::date,
    1
  FROM "events" e
  WHERE NOT EXISTS (
    SELECT 1
    FROM "event_weeks" ew
    WHERE ew."event_id" = e."id"
  )
  RETURNING "id", "event_id", "start_date", "end_date"
)
INSERT INTO "event_days" (
  "event_id",
  "event_week_id",
  "event_day_id",
  "week_index",
  "day_index_in_week",
  "overall_day_index",
  "label",
  "weekday",
  "date",
  "sort_order"
)
SELECT
  iw."event_id",
  iw."id",
  'w1d' || (gs.day_offset + 1),
  1,
  gs.day_offset + 1,
  gs.day_offset + 1,
  NULL,
  LOWER(TRIM(TO_CHAR((iw."start_date" + gs.day_offset), 'Day'))),
  (iw."start_date" + gs.day_offset)::date,
  gs.day_offset + 1
FROM inserted_weeks iw
JOIN LATERAL generate_series(
  0,
  GREATEST(0, (iw."end_date"::date - iw."start_date"::date))
) AS gs(day_offset) ON TRUE;

WITH existing_week AS (
  SELECT
    ew."id" AS event_week_id,
    ew."event_id",
    ew."start_date"::date AS start_date
  FROM "event_weeks" ew
  WHERE ew."week_index" = 1
),
missing_days AS (
  SELECT
    ew."event_week_id",
    ew."event_id",
    1 AS week_index,
    GREATEST(COALESCE(ep."festival_day_index", 1), 1) AS overall_day_index
  FROM existing_week ew
  JOIN "event_performances" ep
    ON ep."event_id" = ew."event_id"
  WHERE NOT EXISTS (
    SELECT 1
    FROM "event_days" ed
    WHERE ed."event_id" = ew."event_id"
      AND ed."overall_day_index" = GREATEST(COALESCE(ep."festival_day_index", 1), 1)
  )
  GROUP BY ew."event_week_id", ew."event_id", GREATEST(COALESCE(ep."festival_day_index", 1), 1)
)
INSERT INTO "event_days" (
  "event_id",
  "event_week_id",
  "event_day_id",
  "week_index",
  "day_index_in_week",
  "overall_day_index",
  "label",
  "weekday",
  "date",
  "sort_order"
)
SELECT
  md."event_id",
  md."event_week_id",
  'w1d' || md."overall_day_index",
  md."week_index",
  md."overall_day_index",
  md."overall_day_index",
  NULL,
  LOWER(TRIM(TO_CHAR((ew."start_date" + (md."overall_day_index" - 1)), 'Day'))),
  (ew."start_date" + (md."overall_day_index" - 1))::date,
  md."overall_day_index"
FROM missing_days md
JOIN existing_week ew
  ON ew."event_id" = md."event_id";

UPDATE "event_performances" ep
SET
  "week_index" = ed."week_index",
  "day_index_in_week" = ed."day_index_in_week",
  "overall_day_index" = ed."overall_day_index",
  "local_date" = ed."date",
  "event_day_id" = ed."event_day_id"
FROM "event_days" ed
WHERE ed."event_id" = ep."event_id"
  AND ed."overall_day_index" = GREATEST(COALESCE(ep."festival_day_index", 1), 1)
  AND ep."event_day_id" IS NULL;
