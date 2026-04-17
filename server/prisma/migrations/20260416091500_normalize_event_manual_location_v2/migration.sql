-- Normalize event address payload into unified manual_location schema:
-- country/city shared fields + detailAddressI18n/formattedAddressI18n.
WITH source_rows AS (
  SELECT
    e.id,
    NULLIF(BTRIM(COALESCE(
      e.manual_location -> 'detailAddressI18n' ->> 'zh',
      e.manual_location -> 'addressI18n' ->> 'zh',
      e.manual_location ->> 'address',
      e.manual_location ->> 'name',
      e.location_i18n ->> 'zh',
      e.location_i18n ->> 'en',
      e.venue_address,
      e.city,
      ''
    )), '') AS detail_zh,
    NULLIF(BTRIM(COALESCE(
      e.manual_location -> 'detailAddressI18n' ->> 'en',
      e.manual_location -> 'addressI18n' ->> 'en',
      e.manual_location ->> 'address',
      e.manual_location ->> 'name',
      e.location_i18n ->> 'en',
      e.location_i18n ->> 'zh',
      e.venue_address,
      e.city,
      ''
    )), '') AS detail_en,
    NULLIF(BTRIM(COALESCE(e.city, '')), '') AS city_text,
    NULLIF(BTRIM(COALESCE(e.country, '')), '') AS country_text,
    NULLIF(BTRIM(COALESCE(e.manual_location ->> 'selectedAt', '')), '') AS selected_at_raw
  FROM "events" AS e
),
prepared AS (
  SELECT
    id,
    COALESCE(detail_zh, detail_en, '') AS detail_zh,
    COALESCE(detail_en, detail_zh, '') AS detail_en,
    city_text,
    country_text,
    COALESCE(
      CASE WHEN selected_at_raw ~ '^\d{4}-\d{2}-\d{2}T' THEN selected_at_raw END,
      to_char(now() AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"')
    ) AS selected_at_iso
  FROM source_rows
),
normalized AS (
  SELECT
    id,
    detail_zh,
    detail_en,
    NULLIF(CONCAT_WS(' · ', country_text, city_text, NULLIF(detail_zh, '')), '') AS formatted_zh,
    NULLIF(CONCAT_WS(' · ', country_text, city_text, NULLIF(detail_en, '')), '') AS formatted_en,
    selected_at_iso
  FROM prepared
  WHERE detail_zh <> '' OR detail_en <> ''
)
UPDATE "events" AS e
SET
  manual_location = jsonb_build_object(
    'detailAddressI18n',
      jsonb_build_object(
        'zh', n.detail_zh,
        'en', n.detail_en
      ),
    'formattedAddressI18n',
      jsonb_build_object(
        'zh', COALESCE(n.formatted_zh, n.detail_zh),
        'en', COALESCE(n.formatted_en, n.detail_en)
      ),
    'selectedAt', n.selected_at_iso
  ),
  -- Keep compatibility columns in sync, but stop using legacy venue_name semantics.
  venue_name = NULL,
  venue_address = COALESCE(NULLIF(n.detail_en, ''), NULLIF(n.detail_zh, ''), e.venue_address),
  location_i18n = jsonb_build_object(
    'zh', n.detail_zh,
    'en', n.detail_en
  ),
  country_i18n = CASE
    WHEN (e.country_i18n IS NULL OR e.country_i18n = 'null'::jsonb)
         AND COALESCE(NULLIF(BTRIM(e.country), ''), '') <> ''
      THEN jsonb_build_object('zh', e.country, 'en', e.country)
    ELSE e.country_i18n
  END
FROM normalized AS n
WHERE e.id = n.id;
