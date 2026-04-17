-- Add normalized multi-map event location payload storage
ALTER TABLE "events"
  ADD COLUMN IF NOT EXISTS "location_point" JSONB;
