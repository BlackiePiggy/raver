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
