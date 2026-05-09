CREATE TABLE IF NOT EXISTS "event_lineup_artists" (
  "id" TEXT NOT NULL,
  "event_id" TEXT NOT NULL,
  "dj_id" TEXT,
  "dj_ids" TEXT[] NOT NULL DEFAULT ARRAY[]::TEXT[],
  "dj_name" TEXT NOT NULL,
  "sort_order" INTEGER NOT NULL DEFAULT 0,
  "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "event_lineup_artists_pkey" PRIMARY KEY ("id"),
  CONSTRAINT "event_lineup_artists_event_id_fkey" FOREIGN KEY ("event_id") REFERENCES "events"("id") ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT "event_lineup_artists_dj_id_fkey" FOREIGN KEY ("dj_id") REFERENCES "djs"("id") ON DELETE SET NULL ON UPDATE CASCADE
);

CREATE TABLE IF NOT EXISTS "event_timetable_slots" (
  "id" TEXT NOT NULL,
  "event_id" TEXT NOT NULL,
  "lineup_artist_id" TEXT,
  "dj_id" TEXT,
  "dj_ids" TEXT[] NOT NULL DEFAULT ARRAY[]::TEXT[],
  "dj_name_snapshot" TEXT NOT NULL,
  "stage_name" TEXT,
  "festival_day_index" INTEGER,
  "start_time" TIMESTAMP(3) NOT NULL,
  "end_time" TIMESTAMP(3) NOT NULL,
  "sort_order" INTEGER NOT NULL DEFAULT 0,
  "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "event_timetable_slots_pkey" PRIMARY KEY ("id"),
  CONSTRAINT "event_timetable_slots_event_id_fkey" FOREIGN KEY ("event_id") REFERENCES "events"("id") ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT "event_timetable_slots_lineup_artist_id_fkey" FOREIGN KEY ("lineup_artist_id") REFERENCES "event_lineup_artists"("id") ON DELETE SET NULL ON UPDATE CASCADE,
  CONSTRAINT "event_timetable_slots_dj_id_fkey" FOREIGN KEY ("dj_id") REFERENCES "djs"("id") ON DELETE SET NULL ON UPDATE CASCADE
);

CREATE INDEX IF NOT EXISTS "event_lineup_artists_event_id_idx" ON "event_lineup_artists" ("event_id");
CREATE INDEX IF NOT EXISTS "event_lineup_artists_dj_id_idx" ON "event_lineup_artists" ("dj_id");
CREATE INDEX IF NOT EXISTS "event_timetable_slots_event_id_idx" ON "event_timetable_slots" ("event_id");
CREATE INDEX IF NOT EXISTS "event_timetable_slots_lineup_artist_id_idx" ON "event_timetable_slots" ("lineup_artist_id");
CREATE INDEX IF NOT EXISTS "event_timetable_slots_dj_id_idx" ON "event_timetable_slots" ("dj_id");
CREATE INDEX IF NOT EXISTS "event_timetable_slots_start_time_idx" ON "event_timetable_slots" ("start_time");

INSERT INTO "event_lineup_artists" ("id", "event_id", "dj_id", "dj_ids", "dj_name", "sort_order", "created_at", "updated_at")
SELECT gen_random_uuid()::TEXT, ranked."event_id", ranked."dj_id", ranked."dj_ids", ranked."dj_name", ranked."sort_order", NOW(), NOW()
FROM (
  SELECT
    slot."event_id",
    MIN(slot."dj_id") FILTER (WHERE slot."dj_id" IS NOT NULL) AS "dj_id",
    COALESCE(
      ARRAY_REMOVE(ARRAY_AGG(DISTINCT unnest_ids."dj_id") FILTER (WHERE unnest_ids."dj_id" IS NOT NULL AND unnest_ids."dj_id" <> ''), NULL),
      ARRAY[]::TEXT[]
    ) AS "dj_ids",
    slot."dj_name",
    MIN(slot."sort_order") AS "sort_order",
    ROW_NUMBER() OVER (
      PARTITION BY slot."event_id", LOWER(TRIM(slot."dj_name"))
      ORDER BY MIN(slot."sort_order"), MIN(slot."start_time")
    ) AS "name_rank"
  FROM "event_lineup_slots" slot
  LEFT JOIN LATERAL (
    SELECT UNNEST(
      CASE
        WHEN COALESCE(array_length(slot."dj_ids", 1), 0) > 0 THEN slot."dj_ids"
        WHEN slot."dj_id" IS NOT NULL THEN ARRAY[slot."dj_id"]::TEXT[]
        ELSE ARRAY[]::TEXT[]
      END
    ) AS "dj_id"
  ) AS unnest_ids ON TRUE
  GROUP BY slot."event_id", slot."dj_name", LOWER(TRIM(slot."dj_name"))
) ranked
WHERE ranked."name_rank" = 1
  AND NOT EXISTS (
    SELECT 1
    FROM "event_lineup_artists" existing
    WHERE existing."event_id" = ranked."event_id"
      AND LOWER(TRIM(existing."dj_name")) = LOWER(TRIM(ranked."dj_name"))
  );

INSERT INTO "event_timetable_slots" (
  "id",
  "event_id",
  "lineup_artist_id",
  "dj_id",
  "dj_ids",
  "dj_name_snapshot",
  "stage_name",
  "festival_day_index",
  "start_time",
  "end_time",
  "sort_order",
  "created_at",
  "updated_at"
)
SELECT
  slot."id",
  slot."event_id",
  artist."id",
  slot."dj_id",
  CASE
    WHEN COALESCE(array_length(slot."dj_ids", 1), 0) > 0 THEN slot."dj_ids"
    WHEN slot."dj_id" IS NOT NULL THEN ARRAY[slot."dj_id"]::TEXT[]
    ELSE ARRAY[]::TEXT[]
  END,
  slot."dj_name",
  slot."stage_name",
  slot."festival_day_index",
  slot."start_time",
  slot."end_time",
  slot."sort_order",
  slot."created_at",
  slot."updated_at"
FROM "event_lineup_slots" slot
LEFT JOIN "event_lineup_artists" artist
  ON artist."event_id" = slot."event_id"
  AND LOWER(TRIM(artist."dj_name")) = LOWER(TRIM(slot."dj_name"))
WHERE NOT EXISTS (
  SELECT 1
  FROM "event_timetable_slots" existing
  WHERE existing."id" = slot."id"
);
