CREATE TABLE IF NOT EXISTS "openim_webhook_events" (
  "id" TEXT NOT NULL,
  "delivery_id" TEXT,
  "callback_command" TEXT,
  "operation_id" TEXT,
  "event_id" TEXT,
  "source_ip" TEXT,
  "signature_valid" BOOLEAN NOT NULL DEFAULT false,
  "verify_reason" TEXT,
  "payload" JSONB NOT NULL,
  "received_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "openim_webhook_events_pkey" PRIMARY KEY ("id")
);

CREATE INDEX IF NOT EXISTS "openim_webhook_events_delivery_id_idx"
  ON "openim_webhook_events"("delivery_id");

CREATE INDEX IF NOT EXISTS "openim_webhook_events_callback_command_idx"
  ON "openim_webhook_events"("callback_command");

CREATE INDEX IF NOT EXISTS "openim_webhook_events_signature_valid_created_at_idx"
  ON "openim_webhook_events"("signature_valid", "created_at");

CREATE INDEX IF NOT EXISTS "openim_webhook_events_created_at_idx"
  ON "openim_webhook_events"("created_at");
