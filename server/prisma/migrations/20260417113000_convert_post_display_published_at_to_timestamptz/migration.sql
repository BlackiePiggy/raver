ALTER TABLE "posts"
ALTER COLUMN "display_published_at" TYPE TIMESTAMPTZ(3)
USING CASE
  WHEN "display_published_at" IS NULL THEN NULL
  ELSE "display_published_at" AT TIME ZONE 'UTC'
END;
