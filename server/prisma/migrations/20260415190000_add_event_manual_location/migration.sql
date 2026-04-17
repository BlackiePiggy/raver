-- Add manual location payload storage for event address fallback / display
ALTER TABLE "events"
  ADD COLUMN IF NOT EXISTS "manual_location" JSONB;
