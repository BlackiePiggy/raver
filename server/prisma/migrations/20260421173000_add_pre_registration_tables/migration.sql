CREATE TABLE IF NOT EXISTS "pre_registrations" (
  "id" TEXT NOT NULL,
  "email" TEXT NOT NULL,
  "phone_country_code" TEXT,
  "phone_number" TEXT,
  "wechat_id" TEXT,
  "salutation" TEXT NOT NULL,
  "expectation_message" TEXT,
  "status" TEXT NOT NULL DEFAULT 'SUBMITTED',
  "source" TEXT,
  "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" TIMESTAMP(3) NOT NULL,
  CONSTRAINT "pre_registrations_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX IF NOT EXISTS "pre_registrations_email_key"
  ON "pre_registrations"("email");

CREATE INDEX IF NOT EXISTS "pre_registrations_status_created_at_idx"
  ON "pre_registrations"("status", "created_at");

CREATE INDEX IF NOT EXISTS "pre_registrations_source_created_at_idx"
  ON "pre_registrations"("source", "created_at");

CREATE TABLE IF NOT EXISTS "pre_registration_batches" (
  "id" TEXT NOT NULL,
  "batch_name" TEXT NOT NULL,
  "planned_slots" INTEGER,
  "note" TEXT,
  "status" TEXT NOT NULL DEFAULT 'OPEN',
  "created_by" TEXT,
  "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" TIMESTAMP(3) NOT NULL,
  CONSTRAINT "pre_registration_batches_pkey" PRIMARY KEY ("id")
);

CREATE INDEX IF NOT EXISTS "pre_registration_batches_created_at_idx"
  ON "pre_registration_batches"("created_at");

CREATE TABLE IF NOT EXISTS "pre_registration_decisions" (
  "id" TEXT NOT NULL,
  "batch_id" TEXT NOT NULL,
  "registration_id" TEXT NOT NULL,
  "decision" TEXT NOT NULL,
  "decision_by" TEXT,
  "decision_reason" TEXT,
  "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" TIMESTAMP(3) NOT NULL,
  CONSTRAINT "pre_registration_decisions_pkey" PRIMARY KEY ("id"),
  CONSTRAINT "pre_registration_decisions_batch_id_fkey"
    FOREIGN KEY ("batch_id")
    REFERENCES "pre_registration_batches"("id")
    ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT "pre_registration_decisions_registration_id_fkey"
    FOREIGN KEY ("registration_id")
    REFERENCES "pre_registrations"("id")
    ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE UNIQUE INDEX IF NOT EXISTS "pre_registration_decisions_batch_id_registration_id_key"
  ON "pre_registration_decisions"("batch_id", "registration_id");

CREATE INDEX IF NOT EXISTS "pre_registration_decisions_batch_id_decision_idx"
  ON "pre_registration_decisions"("batch_id", "decision");

CREATE INDEX IF NOT EXISTS "pre_registration_decisions_registration_id_decision_idx"
  ON "pre_registration_decisions"("registration_id", "decision");

CREATE TABLE IF NOT EXISTS "pre_registration_notifications" (
  "id" TEXT NOT NULL,
  "registration_id" TEXT NOT NULL,
  "batch_id" TEXT,
  "channel" TEXT NOT NULL,
  "template_key" TEXT NOT NULL,
  "send_status" TEXT NOT NULL DEFAULT 'PENDING',
  "provider_message_id" TEXT,
  "error_message" TEXT,
  "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" TIMESTAMP(3) NOT NULL,
  CONSTRAINT "pre_registration_notifications_pkey" PRIMARY KEY ("id"),
  CONSTRAINT "pre_registration_notifications_registration_id_fkey"
    FOREIGN KEY ("registration_id")
    REFERENCES "pre_registrations"("id")
    ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT "pre_registration_notifications_batch_id_fkey"
    FOREIGN KEY ("batch_id")
    REFERENCES "pre_registration_batches"("id")
    ON DELETE SET NULL ON UPDATE CASCADE
);

CREATE INDEX IF NOT EXISTS "pre_registration_notifications_batch_id_channel_created_at_idx"
  ON "pre_registration_notifications"("batch_id", "channel", "created_at");

CREATE INDEX IF NOT EXISTS "pre_registration_notifications_registration_id_channel_created_at_idx"
  ON "pre_registration_notifications"("registration_id", "channel", "created_at");

CREATE INDEX IF NOT EXISTS "pre_registration_notifications_send_status_created_at_idx"
  ON "pre_registration_notifications"("send_status", "created_at");
