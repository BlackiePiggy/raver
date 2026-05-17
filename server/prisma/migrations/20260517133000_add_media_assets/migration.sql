CREATE TABLE IF NOT EXISTS "media_assets" (
  "id" TEXT NOT NULL DEFAULT gen_random_uuid()::text,
  "owner_type" TEXT NOT NULL,
  "owner_id" TEXT,
  "purpose" TEXT NOT NULL,
  "provider" TEXT NOT NULL,
  "bucket" TEXT,
  "object_key" TEXT,
  "url" TEXT NOT NULL,
  "mime_type" TEXT,
  "size_bytes" INTEGER,
  "width" INTEGER,
  "height" INTEGER,
  "status" TEXT NOT NULL DEFAULT 'active',
  "metadata" JSONB,
  "uploaded_by_id" TEXT,
  "deleted_at" TIMESTAMP(3),
  "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "media_assets_pkey" PRIMARY KEY ("id")
);

CREATE INDEX IF NOT EXISTS "media_assets_owner_type_owner_id_purpose_idx"
  ON "media_assets"("owner_type", "owner_id", "purpose");

CREATE INDEX IF NOT EXISTS "media_assets_uploaded_by_id_created_at_idx"
  ON "media_assets"("uploaded_by_id", "created_at");

CREATE INDEX IF NOT EXISTS "media_assets_provider_object_key_idx"
  ON "media_assets"("provider", "object_key");

CREATE INDEX IF NOT EXISTS "media_assets_status_created_at_idx"
  ON "media_assets"("status", "created_at");

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'media_assets_uploaded_by_id_fkey'
  ) THEN
    ALTER TABLE "media_assets"
      ADD CONSTRAINT "media_assets_uploaded_by_id_fkey"
      FOREIGN KEY ("uploaded_by_id")
      REFERENCES "users"("id")
      ON DELETE SET NULL
      ON UPDATE CASCADE;
  END IF;
END $$;
