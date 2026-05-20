-- Phase 1: drop legacy relationship columns/tables that are already removed from
-- Prisma schema and no longer used by the main runtime.
-- Event / Lineup / Timetable legacy structures stay for a later phase because
-- some import/repair utilities still reference them.

-- Post / News legacy binding arrays
DROP INDEX IF EXISTS "posts_bound_dj_ids_idx";
DROP INDEX IF EXISTS "posts_bound_brand_ids_idx";
DROP INDEX IF EXISTS "posts_bound_event_ids_idx";
DROP INDEX IF EXISTS "news_articles_bound_dj_ids_idx";
DROP INDEX IF EXISTS "news_articles_bound_brand_ids_idx";
DROP INDEX IF EXISTS "news_articles_bound_event_ids_idx";

ALTER TABLE "posts"
  DROP COLUMN IF EXISTS "bound_dj_ids",
  DROP COLUMN IF EXISTS "bound_brand_ids",
  DROP COLUMN IF EXISTS "bound_event_ids";

ALTER TABLE "news_articles"
  DROP COLUMN IF EXISTS "bound_dj_ids",
  DROP COLUMN IF EXISTS "bound_brand_ids",
  DROP COLUMN IF EXISTS "bound_event_ids";

-- RatingUnit / DJSet legacy relationship arrays
DROP INDEX IF EXISTS "rating_units_dj_ids_idx";

ALTER TABLE "rating_units"
  DROP COLUMN IF EXISTS "dj_ids";

ALTER TABLE "dj_sets"
  DROP COLUMN IF EXISTS "co_dj_ids";

-- User preference legacy arrays
ALTER TABLE "users"
  DROP COLUMN IF EXISTS "favorite_dj_ids",
  DROP COLUMN IF EXISTS "favorite_genres";

-- Follow / favorite legacy tables
DROP TABLE IF EXISTS "event_favorites";
DROP TABLE IF EXISTS "follows";
