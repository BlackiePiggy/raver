ALTER TABLE "genres"
  ADD COLUMN IF NOT EXISTS "key_artist_bindings" JSONB;
