UPDATE "events"
SET "manual_location" = jsonb_set(
  CASE
    WHEN "manual_location" IS NULL THEN '{}'::jsonb
    WHEN jsonb_typeof("manual_location"::jsonb) = 'object' THEN "manual_location"::jsonb
    ELSE '{}'::jsonb
  END,
  '{detailAddressI18n}',
  COALESCE(
    "manual_location"::jsonb -> 'detailAddressI18n',
    CASE
      WHEN NULLIF(BTRIM("venue_address"), '') IS NOT NULL
      THEN jsonb_build_object(
        'zh', BTRIM("venue_address"),
        'en', BTRIM("venue_address")
      )
      ELSE NULL
    END
  ),
  true
)
WHERE NULLIF(BTRIM("venue_address"), '') IS NOT NULL
  AND (
    "manual_location" IS NULL
    OR ("manual_location"::jsonb -> 'detailAddressI18n') IS NULL
  );

UPDATE "events"
SET "manual_location" = jsonb_set(
  CASE
    WHEN "manual_location" IS NULL THEN '{}'::jsonb
    WHEN jsonb_typeof("manual_location"::jsonb) = 'object' THEN "manual_location"::jsonb
    ELSE '{}'::jsonb
  END,
  '{formattedAddressI18n}',
  jsonb_strip_nulls(
    jsonb_build_object(
      'zh', NULLIF(CONCAT_WS(
        ' · ',
        NULLIF(BTRIM("country"), ''),
        NULLIF(BTRIM("city"), ''),
        COALESCE(
          NULLIF(BTRIM("manual_location"::jsonb #>> '{detailAddressI18n,zh}'), ''),
          NULLIF(BTRIM("manual_location"::jsonb #>> '{detailAddressI18n,en}'), '')
        )
      ), ''),
      'en', NULLIF(CONCAT_WS(
        ' · ',
        NULLIF(BTRIM("country"), ''),
        NULLIF(BTRIM("city"), ''),
        COALESCE(
          NULLIF(BTRIM("manual_location"::jsonb #>> '{detailAddressI18n,en}'), ''),
          NULLIF(BTRIM("manual_location"::jsonb #>> '{detailAddressI18n,zh}'), '')
        )
      ), '')
    )
  ),
  true
)
WHERE "manual_location" IS NOT NULL
  AND (
    ("manual_location"::jsonb -> 'formattedAddressI18n') IS NULL
    OR jsonb_typeof("manual_location"::jsonb -> 'formattedAddressI18n') = 'null'
  )
  AND (
    NULLIF(BTRIM("manual_location"::jsonb #>> '{detailAddressI18n,zh}'), '') IS NOT NULL
    OR NULLIF(BTRIM("manual_location"::jsonb #>> '{detailAddressI18n,en}'), '') IS NOT NULL
  );

UPDATE "events"
SET "location_point" = jsonb_set(
  CASE
    WHEN "location_point" IS NULL THEN '{}'::jsonb
    WHEN jsonb_typeof("location_point"::jsonb) = 'object' THEN "location_point"::jsonb
    ELSE '{}'::jsonb
  END,
  '{nameI18n}',
  COALESCE(
    "location_point"::jsonb -> 'nameI18n',
    CASE
      WHEN NULLIF(BTRIM("venue_name"), '') IS NOT NULL
      THEN jsonb_build_object(
        'zh', BTRIM("venue_name"),
        'en', BTRIM("venue_name")
      )
      ELSE NULL
    END
  ),
  true
)
WHERE "location_point" IS NOT NULL
  AND NULLIF(BTRIM("venue_name"), '') IS NOT NULL
  AND (
    ("location_point"::jsonb -> 'nameI18n') IS NULL
    OR jsonb_typeof("location_point"::jsonb -> 'nameI18n') = 'null'
  );

UPDATE "events"
SET "location_point" = jsonb_set(
  CASE
    WHEN "location_point" IS NULL THEN '{}'::jsonb
    WHEN jsonb_typeof("location_point"::jsonb) = 'object' THEN "location_point"::jsonb
    ELSE '{}'::jsonb
  END,
  '{manualSetAddressI18n}',
  COALESCE(
    "location_point"::jsonb -> 'manualSetAddressI18n',
    CASE
      WHEN "manual_location" IS NOT NULL
        AND (
          ("manual_location"::jsonb -> 'formattedAddressI18n') IS NOT NULL
          OR ("manual_location"::jsonb -> 'detailAddressI18n') IS NOT NULL
        )
      THEN COALESCE(
        "manual_location"::jsonb -> 'formattedAddressI18n',
        "manual_location"::jsonb -> 'detailAddressI18n'
      )
      ELSE "location_point"::jsonb -> 'formattedAddressI18n'
    END,
    '{}'::jsonb
  ),
  true
)
WHERE "location_point" IS NOT NULL;

ALTER TABLE "events"
DROP COLUMN IF EXISTS "venue_name",
DROP COLUMN IF EXISTS "venue_address";
