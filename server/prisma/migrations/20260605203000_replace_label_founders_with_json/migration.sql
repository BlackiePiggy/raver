ALTER TABLE "labels"
ADD COLUMN "founders" JSONB NOT NULL DEFAULT '[]'::jsonb;

UPDATE "labels"
SET "founders" = (
  CASE
    WHEN cardinality("founder_dj_ids") > 0 THEN (
      SELECT COALESCE(
        jsonb_agg(
          jsonb_build_object(
            'name', NULL,
            'djId', founder_id
          )
        ),
        '[]'::jsonb
      )
      FROM unnest("founder_dj_ids") AS founder_id
    )
    ELSE '[]'::jsonb
  END
) || (
  CASE
    WHEN NULLIF(BTRIM(COALESCE("founder_name", '')), '') IS NULL THEN '[]'::jsonb
    WHEN cardinality("founder_dj_ids") = 1 THEN jsonb_build_array(
      jsonb_build_object(
        'name', BTRIM("founder_name"),
        'djId', "founder_dj_ids"[1]
      )
    )
    ELSE jsonb_build_array(
      jsonb_build_object(
        'name', BTRIM("founder_name"),
        'djId', NULL
      )
    )
  END
);

ALTER TABLE "labels"
DROP COLUMN "founder_name",
DROP COLUMN "founder_dj_ids";
