ALTER TABLE "auth_refresh_tokens"
  ADD COLUMN IF NOT EXISTS "client_type" TEXT,
  ADD COLUMN IF NOT EXISTS "device_id" TEXT,
  ADD COLUMN IF NOT EXISTS "device_name" TEXT,
  ADD COLUMN IF NOT EXISTS "platform" TEXT,
  ADD COLUMN IF NOT EXISTS "app_version" TEXT,
  ADD COLUMN IF NOT EXISTS "idle_expires_at" TIMESTAMP(3),
  ADD COLUMN IF NOT EXISTS "absolute_expires_at" TIMESTAMP(3),
  ADD COLUMN IF NOT EXISTS "risk_level" TEXT;

CREATE INDEX IF NOT EXISTS "auth_refresh_tokens_user_id_client_type_revoked_at_expires_at_idx"
  ON "auth_refresh_tokens"("user_id", "client_type", "revoked_at", "expires_at");

CREATE INDEX IF NOT EXISTS "auth_refresh_tokens_device_id_idx"
  ON "auth_refresh_tokens"("device_id");
