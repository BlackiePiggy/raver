ALTER TABLE "users"
  ADD COLUMN IF NOT EXISTS "phone_number" TEXT;

CREATE UNIQUE INDEX IF NOT EXISTS "users_phone_number_key"
  ON "users"("phone_number");

CREATE TABLE IF NOT EXISTS "auth_refresh_tokens" (
  "id" TEXT NOT NULL,
  "user_id" TEXT NOT NULL,
  "token_hash" TEXT NOT NULL,
  "user_agent" TEXT,
  "ip_address" TEXT,
  "expires_at" TIMESTAMP(3) NOT NULL,
  "last_used_at" TIMESTAMP(3),
  "revoked_at" TIMESTAMP(3),
  "replaced_by_token_id" TEXT,
  "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "auth_refresh_tokens_pkey" PRIMARY KEY ("id"),
  CONSTRAINT "auth_refresh_tokens_user_id_fkey"
    FOREIGN KEY ("user_id") REFERENCES "users"("id")
    ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT "auth_refresh_tokens_replaced_by_token_id_fkey"
    FOREIGN KEY ("replaced_by_token_id") REFERENCES "auth_refresh_tokens"("id")
    ON DELETE SET NULL ON UPDATE CASCADE
);

CREATE UNIQUE INDEX IF NOT EXISTS "auth_refresh_tokens_token_hash_key"
  ON "auth_refresh_tokens"("token_hash");

CREATE INDEX IF NOT EXISTS "auth_refresh_tokens_user_id_revoked_at_expires_at_idx"
  ON "auth_refresh_tokens"("user_id", "revoked_at", "expires_at");

CREATE INDEX IF NOT EXISTS "auth_refresh_tokens_expires_at_idx"
  ON "auth_refresh_tokens"("expires_at");

CREATE TABLE IF NOT EXISTS "auth_sms_codes" (
  "id" TEXT NOT NULL,
  "phone_number" TEXT NOT NULL,
  "scene" TEXT NOT NULL DEFAULT 'login',
  "code_hash" TEXT NOT NULL,
  "send_ip" TEXT,
  "expires_at" TIMESTAMP(3) NOT NULL,
  "consumed_at" TIMESTAMP(3),
  "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "auth_sms_codes_pkey" PRIMARY KEY ("id")
);

CREATE INDEX IF NOT EXISTS "auth_sms_codes_phone_number_scene_created_at_idx"
  ON "auth_sms_codes"("phone_number", "scene", "created_at");

CREATE INDEX IF NOT EXISTS "auth_sms_codes_phone_number_scene_expires_at_idx"
  ON "auth_sms_codes"("phone_number", "scene", "expires_at");

CREATE INDEX IF NOT EXISTS "auth_sms_codes_send_ip_created_at_idx"
  ON "auth_sms_codes"("send_ip", "created_at");

CREATE TABLE IF NOT EXISTS "auth_phone_auth_states" (
  "phone_number" TEXT NOT NULL,
  "failed_attempts" INTEGER NOT NULL DEFAULT 0,
  "blocked_until" TIMESTAMP(3),
  "last_failed_at" TIMESTAMP(3),
  "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "auth_phone_auth_states_pkey" PRIMARY KEY ("phone_number")
);
