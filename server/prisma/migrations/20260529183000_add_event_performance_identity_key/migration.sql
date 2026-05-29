SET statement_timeout = 0;

ALTER TABLE "event_performances"
ADD COLUMN IF NOT EXISTS "identity_key" TEXT;

UPDATE "event_performances"
SET "identity_key" = md5(
  concat_ws(
    '|',
    coalesce("event_id", ''),
    coalesce("event_artist_id", ''),
    coalesce("stage_id", ''),
    coalesce("event_day_id", ''),
    coalesce(extract(epoch from "start_at")::bigint::text, ''),
    coalesce(extract(epoch from "end_at")::bigint::text, '')
  )
)
WHERE "identity_key" IS NULL;

ALTER TABLE "event_performances"
ALTER COLUMN "identity_key" SET NOT NULL;

CREATE UNIQUE INDEX IF NOT EXISTS "event_performances_event_identity_key_key"
ON "event_performances"("event_id", "identity_key");
