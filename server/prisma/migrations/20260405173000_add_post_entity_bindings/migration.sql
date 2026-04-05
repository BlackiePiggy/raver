-- Add explicit post-entity bindings for news/article relation
ALTER TABLE "posts"
  ADD COLUMN IF NOT EXISTS "bound_dj_ids" TEXT[] NOT NULL DEFAULT ARRAY[]::TEXT[],
  ADD COLUMN IF NOT EXISTS "bound_brand_ids" TEXT[] NOT NULL DEFAULT ARRAY[]::TEXT[],
  ADD COLUMN IF NOT EXISTS "bound_event_ids" TEXT[] NOT NULL DEFAULT ARRAY[]::TEXT[];
