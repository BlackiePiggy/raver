ALTER TABLE "djs"
  ADD COLUMN IF NOT EXISTS "soundcloud_id" TEXT,
  ADD COLUMN IF NOT EXISTS "website" TEXT,
  ADD COLUMN IF NOT EXISTS "track_count" INTEGER,
  ADD COLUMN IF NOT EXISTS "playlist_count" INTEGER,
  ADD COLUMN IF NOT EXISTS "soundcloud_followers" INTEGER,
  ADD COLUMN IF NOT EXISTS "soundcloud_favorites" INTEGER;

