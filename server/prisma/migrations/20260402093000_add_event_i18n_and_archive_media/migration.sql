ALTER TABLE "events"
ADD COLUMN IF NOT EXISTS "archive_festival_id" TEXT,
ADD COLUMN IF NOT EXISTS "name_i18n" JSONB,
ADD COLUMN IF NOT EXISTS "description_i18n" JSONB,
ADD COLUMN IF NOT EXISTS "location_i18n" JSONB,
ADD COLUMN IF NOT EXISTS "country_i18n" JSONB,
ADD COLUMN IF NOT EXISTS "image_assets" JSONB,
ADD COLUMN IF NOT EXISTS "reference_links" TEXT[] DEFAULT ARRAY[]::TEXT[],
ADD COLUMN IF NOT EXISTS "social_links" JSONB,
ADD COLUMN IF NOT EXISTS "source_provider" TEXT,
ADD COLUMN IF NOT EXISTS "source_event_url" TEXT;

CREATE UNIQUE INDEX IF NOT EXISTS "events_archive_festival_id_key"
ON "events"("archive_festival_id");
