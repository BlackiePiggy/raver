CREATE TABLE IF NOT EXISTS "virtual_asset_definitions" (
  "id" TEXT NOT NULL,
  "code" TEXT NOT NULL,
  "type" TEXT NOT NULL,
  "name" TEXT NOT NULL,
  "description" TEXT,
  "status" TEXT NOT NULL DEFAULT 'draft',
  "render_payload" JSONB NOT NULL,
  "preview_image_url" TEXT,
  "source" TEXT NOT NULL DEFAULT 'system',
  "theme_tags" TEXT[] NOT NULL DEFAULT ARRAY[]::TEXT[],
  "starts_at" TIMESTAMP(3),
  "ends_at" TIMESTAMP(3),
  "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "virtual_asset_definitions_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX IF NOT EXISTS "virtual_asset_definitions_code_key"
  ON "virtual_asset_definitions"("code");

CREATE INDEX IF NOT EXISTS "virtual_asset_definitions_type_status_idx"
  ON "virtual_asset_definitions"("type", "status");

CREATE INDEX IF NOT EXISTS "virtual_asset_definitions_source_idx"
  ON "virtual_asset_definitions"("source");

CREATE TABLE IF NOT EXISTS "user_virtual_assets" (
  "id" TEXT NOT NULL,
  "user_id" TEXT NOT NULL,
  "asset_id" TEXT NOT NULL,
  "acquisition_source" TEXT NOT NULL DEFAULT 'default',
  "status" TEXT NOT NULL DEFAULT 'active',
  "acquired_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "expires_at" TIMESTAMP(3),
  "metadata" JSONB,
  CONSTRAINT "user_virtual_assets_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX IF NOT EXISTS "user_virtual_assets_user_id_asset_id_key"
  ON "user_virtual_assets"("user_id", "asset_id");

CREATE INDEX IF NOT EXISTS "user_virtual_assets_user_id_status_idx"
  ON "user_virtual_assets"("user_id", "status");

CREATE INDEX IF NOT EXISTS "user_virtual_assets_asset_id_idx"
  ON "user_virtual_assets"("asset_id");

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'user_virtual_assets_user_id_fkey'
  ) THEN
    ALTER TABLE "user_virtual_assets"
      ADD CONSTRAINT "user_virtual_assets_user_id_fkey"
      FOREIGN KEY ("user_id") REFERENCES "users"("id")
      ON DELETE CASCADE ON UPDATE CASCADE;
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'user_virtual_assets_asset_id_fkey'
  ) THEN
    ALTER TABLE "user_virtual_assets"
      ADD CONSTRAINT "user_virtual_assets_asset_id_fkey"
      FOREIGN KEY ("asset_id") REFERENCES "virtual_asset_definitions"("id")
      ON DELETE CASCADE ON UPDATE CASCADE;
  END IF;
END $$;

CREATE TABLE IF NOT EXISTS "user_virtual_asset_equips" (
  "id" TEXT NOT NULL,
  "user_id" TEXT NOT NULL,
  "asset_type" TEXT NOT NULL,
  "asset_ids" TEXT[] NOT NULL DEFAULT ARRAY[]::TEXT[],
  "updated_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "user_virtual_asset_equips_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX IF NOT EXISTS "user_virtual_asset_equips_user_id_asset_type_key"
  ON "user_virtual_asset_equips"("user_id", "asset_type");

CREATE INDEX IF NOT EXISTS "user_virtual_asset_equips_user_id_idx"
  ON "user_virtual_asset_equips"("user_id");

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'user_virtual_asset_equips_user_id_fkey'
  ) THEN
    ALTER TABLE "user_virtual_asset_equips"
      ADD CONSTRAINT "user_virtual_asset_equips_user_id_fkey"
      FOREIGN KEY ("user_id") REFERENCES "users"("id")
      ON DELETE CASCADE ON UPDATE CASCADE;
  END IF;
END $$;
