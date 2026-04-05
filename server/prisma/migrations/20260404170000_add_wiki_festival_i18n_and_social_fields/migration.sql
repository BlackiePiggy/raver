ALTER TABLE "wiki_festivals"
ADD COLUMN IF NOT EXISTS "source_row_id" INTEGER,
ADD COLUMN IF NOT EXISTS "name_i18n" JSONB,
ADD COLUMN IF NOT EXISTS "abbreviation" TEXT DEFAULT '',
ADD COLUMN IF NOT EXISTS "country_i18n" JSONB,
ADD COLUMN IF NOT EXISTS "city_i18n" JSONB,
ADD COLUMN IF NOT EXISTS "frequency_i18n" JSONB,
ADD COLUMN IF NOT EXISTS "description_i18n" JSONB,
ADD COLUMN IF NOT EXISTS "official_website" TEXT,
ADD COLUMN IF NOT EXISTS "facebook_url" TEXT,
ADD COLUMN IF NOT EXISTS "instagram_url" TEXT,
ADD COLUMN IF NOT EXISTS "twitter_url" TEXT,
ADD COLUMN IF NOT EXISTS "youtube_url" TEXT,
ADD COLUMN IF NOT EXISTS "tiktok_url" TEXT;

CREATE UNIQUE INDEX IF NOT EXISTS "wiki_festivals_source_row_id_key"
ON "wiki_festivals"("source_row_id");
