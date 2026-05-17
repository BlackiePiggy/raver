CREATE TABLE "auth_email_codes" (
    "id" TEXT NOT NULL,
    "email" TEXT NOT NULL,
    "scene" TEXT NOT NULL DEFAULT 'login',
    "code_hash" TEXT NOT NULL,
    "send_ip" TEXT,
    "expires_at" TIMESTAMP(3) NOT NULL,
    "consumed_at" TIMESTAMP(3),
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "auth_email_codes_pkey" PRIMARY KEY ("id")
);

CREATE TABLE "auth_email_auth_states" (
    "email" TEXT NOT NULL,
    "failed_attempts" INTEGER NOT NULL DEFAULT 0,
    "blocked_until" TIMESTAMP(3),
    "last_failed_at" TIMESTAMP(3),
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "auth_email_auth_states_pkey" PRIMARY KEY ("email")
);

CREATE INDEX "auth_email_codes_email_scene_created_at_idx" ON "auth_email_codes"("email", "scene", "created_at");
CREATE INDEX "auth_email_codes_email_scene_expires_at_idx" ON "auth_email_codes"("email", "scene", "expires_at");
CREATE INDEX "auth_email_codes_send_ip_created_at_idx" ON "auth_email_codes"("send_ip", "created_at");
