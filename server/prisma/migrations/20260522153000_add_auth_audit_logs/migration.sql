CREATE TABLE "auth_audit_logs" (
    "id" TEXT NOT NULL DEFAULT gen_random_uuid()::text,
    "trace_id" TEXT,
    "action" TEXT NOT NULL,
    "outcome" TEXT NOT NULL,
    "user_id" TEXT,
    "identifier_masked" TEXT,
    "error_code" TEXT,
    "refresh_token_id" TEXT,
    "client_type" TEXT,
    "platform" TEXT,
    "app_version" TEXT,
    "device_id" TEXT,
    "device_name" TEXT,
    "ip_address" TEXT,
    "user_agent" TEXT,
    "detail" JSONB,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "auth_audit_logs_pkey" PRIMARY KEY ("id")
);

CREATE INDEX "auth_audit_logs_user_id_created_at_idx" ON "auth_audit_logs"("user_id", "created_at");
CREATE INDEX "auth_audit_logs_action_outcome_created_at_idx" ON "auth_audit_logs"("action", "outcome", "created_at");
CREATE INDEX "auth_audit_logs_error_code_created_at_idx" ON "auth_audit_logs"("error_code", "created_at");
CREATE INDEX "auth_audit_logs_client_type_created_at_idx" ON "auth_audit_logs"("client_type", "created_at");

ALTER TABLE "auth_audit_logs"
ADD CONSTRAINT "auth_audit_logs_user_id_fkey"
FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;
