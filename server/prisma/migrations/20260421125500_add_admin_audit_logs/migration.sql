CREATE TABLE IF NOT EXISTS "admin_audit_logs" (
  "id" TEXT NOT NULL,
  "actor_id" TEXT NOT NULL,
  "action" TEXT NOT NULL,
  "target_type" TEXT NOT NULL,
  "target_id" TEXT NOT NULL,
  "detail" JSONB,
  "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "admin_audit_logs_pkey" PRIMARY KEY ("id")
);

CREATE INDEX IF NOT EXISTS "admin_audit_logs_actor_id_created_at_idx"
  ON "admin_audit_logs"("actor_id", "created_at");

CREATE INDEX IF NOT EXISTS "admin_audit_logs_action_created_at_idx"
  ON "admin_audit_logs"("action", "created_at");

CREATE INDEX IF NOT EXISTS "admin_audit_logs_target_type_target_id_idx"
  ON "admin_audit_logs"("target_type", "target_id");
