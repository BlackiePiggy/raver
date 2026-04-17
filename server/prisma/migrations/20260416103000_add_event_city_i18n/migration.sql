ALTER TABLE "events"
ADD COLUMN IF NOT EXISTS "city_i18n" JSONB;

UPDATE "events"
SET "city_i18n" = jsonb_build_object(
  'zh', COALESCE(NULLIF(BTRIM("city"), ''), ''),
  'en', COALESCE(NULLIF(BTRIM("city"), ''), '')
)
WHERE (
  "city_i18n" IS NULL
  OR "city_i18n" = 'null'::jsonb
)
AND COALESCE(NULLIF(BTRIM("city"), ''), '') <> '';
