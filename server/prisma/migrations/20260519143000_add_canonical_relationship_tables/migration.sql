CREATE EXTENSION IF NOT EXISTS "pgcrypto";

CREATE TABLE IF NOT EXISTS "user_entity_follows" (
  "id" TEXT NOT NULL DEFAULT gen_random_uuid()::TEXT,
  "user_id" TEXT NOT NULL,
  "target_type" TEXT NOT NULL,
  "target_id" TEXT NOT NULL,
  "relation_type" TEXT NOT NULL,
  "sort_order" INTEGER NOT NULL DEFAULT 0,
  "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "user_entity_follows_pkey" PRIMARY KEY ("id"),
  CONSTRAINT "user_entity_follows_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE UNIQUE INDEX IF NOT EXISTS "user_entity_follows_user_relation_target_key"
ON "user_entity_follows"("user_id", "relation_type", "target_type", "target_id");

CREATE INDEX IF NOT EXISTS "user_entity_follows_user_relation_created_idx"
ON "user_entity_follows"("user_id", "relation_type", "target_type", "created_at");

CREATE INDEX IF NOT EXISTS "user_entity_follows_target_relation_created_idx"
ON "user_entity_follows"("target_type", "target_id", "relation_type", "created_at");

CREATE TABLE IF NOT EXISTS "event_artists" (
  "id" TEXT NOT NULL DEFAULT gen_random_uuid()::TEXT,
  "event_id" TEXT NOT NULL,
  "display_name" TEXT NOT NULL,
  "normalized_name" TEXT,
  "act_type" TEXT NOT NULL DEFAULT 'unknown',
  "primary_dj_id" TEXT,
  "billing_order" INTEGER NOT NULL DEFAULT 0,
  "poster_tier" TEXT,
  "source_type" TEXT NOT NULL DEFAULT 'migration',
  "is_timetable_only" BOOLEAN NOT NULL DEFAULT false,
  "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "event_artists_pkey" PRIMARY KEY ("id"),
  CONSTRAINT "event_artists_event_id_fkey" FOREIGN KEY ("event_id") REFERENCES "events"("id") ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT "event_artists_primary_dj_id_fkey" FOREIGN KEY ("primary_dj_id") REFERENCES "djs"("id") ON DELETE SET NULL ON UPDATE CASCADE
);

CREATE INDEX IF NOT EXISTS "event_artists_event_billing_order_idx" ON "event_artists"("event_id", "billing_order");
CREATE INDEX IF NOT EXISTS "event_artists_event_normalized_name_idx" ON "event_artists"("event_id", "normalized_name");
CREATE INDEX IF NOT EXISTS "event_artists_primary_dj_id_idx" ON "event_artists"("primary_dj_id");

CREATE TABLE IF NOT EXISTS "event_artist_members" (
  "id" TEXT NOT NULL DEFAULT gen_random_uuid()::TEXT,
  "event_artist_id" TEXT NOT NULL,
  "dj_id" TEXT,
  "member_name_snapshot" TEXT NOT NULL,
  "member_order" INTEGER NOT NULL DEFAULT 0,
  "role" TEXT NOT NULL DEFAULT 'performer',
  "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "event_artist_members_pkey" PRIMARY KEY ("id"),
  CONSTRAINT "event_artist_members_event_artist_id_fkey" FOREIGN KEY ("event_artist_id") REFERENCES "event_artists"("id") ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT "event_artist_members_dj_id_fkey" FOREIGN KEY ("dj_id") REFERENCES "djs"("id") ON DELETE SET NULL ON UPDATE CASCADE
);

CREATE UNIQUE INDEX IF NOT EXISTS "event_artist_members_artist_order_key" ON "event_artist_members"("event_artist_id", "member_order");
CREATE INDEX IF NOT EXISTS "event_artist_members_artist_order_idx" ON "event_artist_members"("event_artist_id", "member_order");
CREATE INDEX IF NOT EXISTS "event_artist_members_dj_artist_idx" ON "event_artist_members"("dj_id", "event_artist_id");

CREATE TABLE IF NOT EXISTS "event_stages" (
  "id" TEXT NOT NULL DEFAULT gen_random_uuid()::TEXT,
  "event_id" TEXT NOT NULL,
  "name" TEXT NOT NULL,
  "normalized_name" TEXT NOT NULL,
  "sort_order" INTEGER NOT NULL DEFAULT 0,
  "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "event_stages_pkey" PRIMARY KEY ("id"),
  CONSTRAINT "event_stages_event_id_fkey" FOREIGN KEY ("event_id") REFERENCES "events"("id") ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE UNIQUE INDEX IF NOT EXISTS "event_stages_event_normalized_name_key" ON "event_stages"("event_id", "normalized_name");
CREATE INDEX IF NOT EXISTS "event_stages_event_sort_order_idx" ON "event_stages"("event_id", "sort_order");

CREATE TABLE IF NOT EXISTS "event_performances" (
  "id" TEXT NOT NULL DEFAULT gen_random_uuid()::TEXT,
  "event_id" TEXT NOT NULL,
  "event_artist_id" TEXT NOT NULL,
  "stage_id" TEXT,
  "display_name_snapshot" TEXT NOT NULL,
  "festival_day_index" INTEGER,
  "start_at" TIMESTAMP(3),
  "end_at" TIMESTAMP(3),
  "sort_order" INTEGER NOT NULL DEFAULT 0,
  "status" TEXT NOT NULL DEFAULT 'scheduled',
  "source_type" TEXT NOT NULL DEFAULT 'migration',
  "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "event_performances_pkey" PRIMARY KEY ("id"),
  CONSTRAINT "event_performances_event_id_fkey" FOREIGN KEY ("event_id") REFERENCES "events"("id") ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT "event_performances_event_artist_id_fkey" FOREIGN KEY ("event_artist_id") REFERENCES "event_artists"("id") ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT "event_performances_stage_id_fkey" FOREIGN KEY ("stage_id") REFERENCES "event_stages"("id") ON DELETE SET NULL ON UPDATE CASCADE
);

CREATE INDEX IF NOT EXISTS "event_performances_event_start_idx" ON "event_performances"("event_id", "start_at");
CREATE INDEX IF NOT EXISTS "event_performances_event_day_start_idx" ON "event_performances"("event_id", "festival_day_index", "start_at");
CREATE INDEX IF NOT EXISTS "event_performances_stage_start_idx" ON "event_performances"("stage_id", "start_at");
CREATE INDEX IF NOT EXISTS "event_performances_artist_start_idx" ON "event_performances"("event_artist_id", "start_at");

CREATE TABLE IF NOT EXISTS "post_dj_bindings" (
  "id" TEXT NOT NULL DEFAULT gen_random_uuid()::TEXT,
  "post_id" TEXT NOT NULL,
  "dj_id" TEXT NOT NULL,
  "binding_type" TEXT NOT NULL DEFAULT 'related',
  "sort_order" INTEGER NOT NULL DEFAULT 0,
  "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "post_dj_bindings_pkey" PRIMARY KEY ("id"),
  CONSTRAINT "post_dj_bindings_post_id_fkey" FOREIGN KEY ("post_id") REFERENCES "posts"("id") ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT "post_dj_bindings_dj_id_fkey" FOREIGN KEY ("dj_id") REFERENCES "djs"("id") ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE UNIQUE INDEX IF NOT EXISTS "post_dj_bindings_post_dj_key" ON "post_dj_bindings"("post_id", "dj_id");
CREATE INDEX IF NOT EXISTS "post_dj_bindings_post_sort_created_idx" ON "post_dj_bindings"("post_id", "sort_order", "created_at");
CREATE INDEX IF NOT EXISTS "post_dj_bindings_dj_created_idx" ON "post_dj_bindings"("dj_id", "created_at");

CREATE TABLE IF NOT EXISTS "post_event_bindings" (
  "id" TEXT NOT NULL DEFAULT gen_random_uuid()::TEXT,
  "post_id" TEXT NOT NULL,
  "event_id" TEXT NOT NULL,
  "binding_type" TEXT NOT NULL DEFAULT 'related',
  "sort_order" INTEGER NOT NULL DEFAULT 0,
  "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "post_event_bindings_pkey" PRIMARY KEY ("id"),
  CONSTRAINT "post_event_bindings_post_id_fkey" FOREIGN KEY ("post_id") REFERENCES "posts"("id") ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT "post_event_bindings_event_id_fkey" FOREIGN KEY ("event_id") REFERENCES "events"("id") ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE UNIQUE INDEX IF NOT EXISTS "post_event_bindings_post_event_key" ON "post_event_bindings"("post_id", "event_id");
CREATE INDEX IF NOT EXISTS "post_event_bindings_post_sort_created_idx" ON "post_event_bindings"("post_id", "sort_order", "created_at");
CREATE INDEX IF NOT EXISTS "post_event_bindings_event_created_idx" ON "post_event_bindings"("event_id", "created_at");

CREATE TABLE IF NOT EXISTS "post_festival_brand_bindings" (
  "id" TEXT NOT NULL DEFAULT gen_random_uuid()::TEXT,
  "post_id" TEXT NOT NULL,
  "festival_brand_id" TEXT NOT NULL,
  "binding_type" TEXT NOT NULL DEFAULT 'related',
  "sort_order" INTEGER NOT NULL DEFAULT 0,
  "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "post_festival_brand_bindings_pkey" PRIMARY KEY ("id"),
  CONSTRAINT "post_festival_brand_bindings_post_id_fkey" FOREIGN KEY ("post_id") REFERENCES "posts"("id") ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT "post_festival_brand_bindings_brand_id_fkey" FOREIGN KEY ("festival_brand_id") REFERENCES "wiki_festivals"("id") ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE UNIQUE INDEX IF NOT EXISTS "post_festival_brand_bindings_post_brand_key" ON "post_festival_brand_bindings"("post_id", "festival_brand_id");
CREATE INDEX IF NOT EXISTS "post_festival_brand_bindings_post_sort_created_idx" ON "post_festival_brand_bindings"("post_id", "sort_order", "created_at");
CREATE INDEX IF NOT EXISTS "post_festival_brand_bindings_brand_created_idx" ON "post_festival_brand_bindings"("festival_brand_id", "created_at");

CREATE TABLE IF NOT EXISTS "news_dj_bindings" (
  "id" TEXT NOT NULL DEFAULT gen_random_uuid()::TEXT,
  "article_id" TEXT NOT NULL,
  "dj_id" TEXT NOT NULL,
  "binding_type" TEXT NOT NULL DEFAULT 'related',
  "sort_order" INTEGER NOT NULL DEFAULT 0,
  "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "news_dj_bindings_pkey" PRIMARY KEY ("id"),
  CONSTRAINT "news_dj_bindings_article_id_fkey" FOREIGN KEY ("article_id") REFERENCES "news_articles"("id") ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT "news_dj_bindings_dj_id_fkey" FOREIGN KEY ("dj_id") REFERENCES "djs"("id") ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE UNIQUE INDEX IF NOT EXISTS "news_dj_bindings_article_dj_key" ON "news_dj_bindings"("article_id", "dj_id");
CREATE INDEX IF NOT EXISTS "news_dj_bindings_article_sort_created_idx" ON "news_dj_bindings"("article_id", "sort_order", "created_at");
CREATE INDEX IF NOT EXISTS "news_dj_bindings_dj_created_idx" ON "news_dj_bindings"("dj_id", "created_at");

CREATE TABLE IF NOT EXISTS "news_event_bindings" (
  "id" TEXT NOT NULL DEFAULT gen_random_uuid()::TEXT,
  "article_id" TEXT NOT NULL,
  "event_id" TEXT NOT NULL,
  "binding_type" TEXT NOT NULL DEFAULT 'related',
  "sort_order" INTEGER NOT NULL DEFAULT 0,
  "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "news_event_bindings_pkey" PRIMARY KEY ("id"),
  CONSTRAINT "news_event_bindings_article_id_fkey" FOREIGN KEY ("article_id") REFERENCES "news_articles"("id") ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT "news_event_bindings_event_id_fkey" FOREIGN KEY ("event_id") REFERENCES "events"("id") ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE UNIQUE INDEX IF NOT EXISTS "news_event_bindings_article_event_key" ON "news_event_bindings"("article_id", "event_id");
CREATE INDEX IF NOT EXISTS "news_event_bindings_article_sort_created_idx" ON "news_event_bindings"("article_id", "sort_order", "created_at");
CREATE INDEX IF NOT EXISTS "news_event_bindings_event_created_idx" ON "news_event_bindings"("event_id", "created_at");

CREATE TABLE IF NOT EXISTS "news_festival_brand_bindings" (
  "id" TEXT NOT NULL DEFAULT gen_random_uuid()::TEXT,
  "article_id" TEXT NOT NULL,
  "festival_brand_id" TEXT NOT NULL,
  "binding_type" TEXT NOT NULL DEFAULT 'related',
  "sort_order" INTEGER NOT NULL DEFAULT 0,
  "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "news_festival_brand_bindings_pkey" PRIMARY KEY ("id"),
  CONSTRAINT "news_festival_brand_bindings_article_id_fkey" FOREIGN KEY ("article_id") REFERENCES "news_articles"("id") ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT "news_festival_brand_bindings_brand_id_fkey" FOREIGN KEY ("festival_brand_id") REFERENCES "wiki_festivals"("id") ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE UNIQUE INDEX IF NOT EXISTS "news_festival_brand_bindings_article_brand_key" ON "news_festival_brand_bindings"("article_id", "festival_brand_id");
CREATE INDEX IF NOT EXISTS "news_festival_brand_bindings_article_sort_created_idx" ON "news_festival_brand_bindings"("article_id", "sort_order", "created_at");
CREATE INDEX IF NOT EXISTS "news_festival_brand_bindings_brand_created_idx" ON "news_festival_brand_bindings"("festival_brand_id", "created_at");

CREATE TABLE IF NOT EXISTS "dj_set_artists" (
  "id" TEXT NOT NULL DEFAULT gen_random_uuid()::TEXT,
  "set_id" TEXT NOT NULL,
  "dj_id" TEXT,
  "artist_name_snapshot" TEXT NOT NULL,
  "artist_order" INTEGER NOT NULL DEFAULT 0,
  "role" TEXT NOT NULL DEFAULT 'primary',
  "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "dj_set_artists_pkey" PRIMARY KEY ("id"),
  CONSTRAINT "dj_set_artists_set_id_fkey" FOREIGN KEY ("set_id") REFERENCES "dj_sets"("id") ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT "dj_set_artists_dj_id_fkey" FOREIGN KEY ("dj_id") REFERENCES "djs"("id") ON DELETE SET NULL ON UPDATE CASCADE
);

CREATE UNIQUE INDEX IF NOT EXISTS "dj_set_artists_set_order_key" ON "dj_set_artists"("set_id", "artist_order");
CREATE INDEX IF NOT EXISTS "dj_set_artists_set_order_idx" ON "dj_set_artists"("set_id", "artist_order");
CREATE INDEX IF NOT EXISTS "dj_set_artists_dj_created_idx" ON "dj_set_artists"("dj_id", "created_at");

CREATE TABLE IF NOT EXISTS "rating_unit_dj_bindings" (
  "id" TEXT NOT NULL DEFAULT gen_random_uuid()::TEXT,
  "unit_id" TEXT NOT NULL,
  "dj_id" TEXT NOT NULL,
  "sort_order" INTEGER NOT NULL DEFAULT 0,
  "binding_type" TEXT NOT NULL DEFAULT 'rated',
  "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "rating_unit_dj_bindings_pkey" PRIMARY KEY ("id"),
  CONSTRAINT "rating_unit_dj_bindings_unit_id_fkey" FOREIGN KEY ("unit_id") REFERENCES "rating_units"("id") ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT "rating_unit_dj_bindings_dj_id_fkey" FOREIGN KEY ("dj_id") REFERENCES "djs"("id") ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE UNIQUE INDEX IF NOT EXISTS "rating_unit_dj_bindings_unit_dj_key" ON "rating_unit_dj_bindings"("unit_id", "dj_id");
CREATE INDEX IF NOT EXISTS "rating_unit_dj_bindings_unit_sort_idx" ON "rating_unit_dj_bindings"("unit_id", "sort_order");
CREATE INDEX IF NOT EXISTS "rating_unit_dj_bindings_dj_created_idx" ON "rating_unit_dj_bindings"("dj_id", "created_at");

CREATE TABLE IF NOT EXISTS "dj_genre_bindings" (
  "id" TEXT NOT NULL DEFAULT gen_random_uuid()::TEXT,
  "dj_id" TEXT NOT NULL,
  "genre_id" TEXT NOT NULL,
  "binding_type" TEXT NOT NULL DEFAULT 'style',
  "sort_order" INTEGER NOT NULL DEFAULT 0,
  "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "dj_genre_bindings_pkey" PRIMARY KEY ("id"),
  CONSTRAINT "dj_genre_bindings_dj_id_fkey" FOREIGN KEY ("dj_id") REFERENCES "djs"("id") ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT "dj_genre_bindings_genre_id_fkey" FOREIGN KEY ("genre_id") REFERENCES "genres"("id") ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE UNIQUE INDEX IF NOT EXISTS "dj_genre_bindings_dj_genre_key" ON "dj_genre_bindings"("dj_id", "genre_id");
CREATE INDEX IF NOT EXISTS "dj_genre_bindings_dj_sort_idx" ON "dj_genre_bindings"("dj_id", "sort_order");
CREATE INDEX IF NOT EXISTS "dj_genre_bindings_genre_created_idx" ON "dj_genre_bindings"("genre_id", "created_at");
