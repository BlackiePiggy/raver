CREATE TABLE IF NOT EXISTS "openim_message_reports" (
  "id" TEXT NOT NULL,
  "message_id" TEXT NOT NULL,
  "conversation_id" TEXT,
  "reported_by_user_id" TEXT NOT NULL,
  "reason" TEXT NOT NULL,
  "detail" TEXT,
  "source" TEXT NOT NULL DEFAULT 'in_app',
  "status" TEXT NOT NULL DEFAULT 'pending',
  "metadata" JSONB,
  "resolved_at" TIMESTAMP(3),
  "resolved_by" TEXT,
  "resolution_note" TEXT,
  "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "openim_message_reports_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX IF NOT EXISTS "openim_message_reports_message_id_reported_by_user_id_key"
  ON "openim_message_reports"("message_id", "reported_by_user_id");

CREATE INDEX IF NOT EXISTS "openim_message_reports_status_created_at_idx"
  ON "openim_message_reports"("status", "created_at");

CREATE INDEX IF NOT EXISTS "openim_message_reports_reported_by_user_id_created_at_idx"
  ON "openim_message_reports"("reported_by_user_id", "created_at");
