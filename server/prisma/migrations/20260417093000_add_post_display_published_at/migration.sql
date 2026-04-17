ALTER TABLE "posts"
ADD COLUMN IF NOT EXISTS "display_published_at" TIMESTAMP(3);

UPDATE "posts"
SET "display_published_at" = "created_at"
WHERE "display_published_at" IS NULL;
