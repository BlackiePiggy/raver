CREATE EXTENSION IF NOT EXISTS "pgcrypto";

WITH affected_events AS (
  SELECT DISTINCT performance."event_id"
  FROM "event_performances" performance
  WHERE performance."stage_id" IS NULL
),
inserted_stages AS (
  INSERT INTO "event_stages" (
    "id",
    "event_id",
    "name",
    "normalized_name",
    "sort_order",
    "created_at",
    "updated_at"
  )
  SELECT
    gen_random_uuid()::TEXT,
    affected_events."event_id",
    'Main Stage',
    'main stage',
    1,
    CURRENT_TIMESTAMP,
    CURRENT_TIMESTAMP
  FROM affected_events
  WHERE NOT EXISTS (
    SELECT 1
    FROM "event_stages" existing_stage
    WHERE existing_stage."event_id" = affected_events."event_id"
      AND existing_stage."normalized_name" = 'main stage'
  )
  ON CONFLICT ("event_id", "normalized_name") DO NOTHING
  RETURNING "id", "event_id"
),
default_stages AS (
  SELECT "id", "event_id"
  FROM inserted_stages

  UNION ALL

  SELECT existing_stage."id", existing_stage."event_id"
  FROM "event_stages" existing_stage
  JOIN affected_events
    ON affected_events."event_id" = existing_stage."event_id"
  WHERE existing_stage."normalized_name" = 'main stage'
)
UPDATE "event_performances" performance
SET
  "stage_id" = default_stages."id",
  "updated_at" = CURRENT_TIMESTAMP
FROM default_stages
WHERE performance."event_id" = default_stages."event_id"
  AND performance."stage_id" IS NULL;
