-- Add optional address structures to brands (WikiFestival) so Organizer Studio
-- can persist the same manualLocation/locationPoint model used by events.
ALTER TABLE "wiki_festivals"
  ADD COLUMN "manual_location" JSONB,
  ADD COLUMN "location_point" JSONB;
