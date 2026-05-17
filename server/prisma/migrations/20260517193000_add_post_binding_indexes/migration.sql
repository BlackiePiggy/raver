-- Speed up event discussion and dedicated bound-news lookups.
CREATE INDEX IF NOT EXISTS "posts_event_id_created_at_idx" ON "posts"("event_id", "created_at");
CREATE INDEX IF NOT EXISTS "posts_bound_dj_ids_idx" ON "posts" USING GIN ("bound_dj_ids");
CREATE INDEX IF NOT EXISTS "posts_bound_brand_ids_idx" ON "posts" USING GIN ("bound_brand_ids");
CREATE INDEX IF NOT EXISTS "posts_bound_event_ids_idx" ON "posts" USING GIN ("bound_event_ids");
