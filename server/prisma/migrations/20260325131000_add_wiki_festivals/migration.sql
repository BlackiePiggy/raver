CREATE TABLE "wiki_festivals" (
  "id" TEXT NOT NULL,
  "name" TEXT NOT NULL,
  "aliases" TEXT[] DEFAULT ARRAY[]::TEXT[],
  "country" TEXT NOT NULL,
  "city" TEXT NOT NULL,
  "founded_year" TEXT NOT NULL,
  "frequency" TEXT NOT NULL,
  "tagline" TEXT NOT NULL,
  "introduction" TEXT NOT NULL,
  "avatar_url" TEXT,
  "background_url" TEXT,
  "links" JSONB,
  "is_active" BOOLEAN NOT NULL DEFAULT true,
  "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" TIMESTAMP(3) NOT NULL,

  CONSTRAINT "wiki_festivals_pkey" PRIMARY KEY ("id")
);

CREATE TABLE "wiki_festival_contributors" (
  "id" TEXT NOT NULL,
  "festival_id" TEXT NOT NULL,
  "user_id" TEXT NOT NULL,
  "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" TIMESTAMP(3) NOT NULL,

  CONSTRAINT "wiki_festival_contributors_pkey" PRIMARY KEY ("id")
);

CREATE INDEX "wiki_festivals_name_idx" ON "wiki_festivals"("name");
CREATE INDEX "wiki_festivals_country_idx" ON "wiki_festivals"("country");

CREATE UNIQUE INDEX "wiki_festival_contributors_festival_id_user_id_key"
  ON "wiki_festival_contributors"("festival_id", "user_id");
CREATE INDEX "wiki_festival_contributors_festival_id_idx"
  ON "wiki_festival_contributors"("festival_id");
CREATE INDEX "wiki_festival_contributors_user_id_idx"
  ON "wiki_festival_contributors"("user_id");

ALTER TABLE "wiki_festival_contributors"
ADD CONSTRAINT "wiki_festival_contributors_festival_id_fkey"
FOREIGN KEY ("festival_id") REFERENCES "wiki_festivals"("id") ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "wiki_festival_contributors"
ADD CONSTRAINT "wiki_festival_contributors_user_id_fkey"
FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
