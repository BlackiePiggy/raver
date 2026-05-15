ALTER TABLE "dj_sets"
ADD COLUMN "title_i18n" JSONB,
ADD COLUMN "description_i18n" JSONB;

ALTER TABLE "posts"
ADD COLUMN "title_i18n" JSONB,
ADD COLUMN "summary_i18n" JSONB,
ADD COLUMN "body_i18n" JSONB;

ALTER TABLE "labels"
ADD COLUMN "name_i18n" JSONB,
ADD COLUMN "description_i18n" JSONB;
