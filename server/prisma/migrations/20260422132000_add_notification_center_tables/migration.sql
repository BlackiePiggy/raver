-- Notification center core tables

CREATE TABLE IF NOT EXISTS "notification_subscriptions" (
  "id" TEXT NOT NULL,
  "user_id" TEXT NOT NULL,
  "category" TEXT NOT NULL,
  "enabled" BOOLEAN NOT NULL DEFAULT true,
  "quiet_hours" JSONB,
  "frequency_config" JSONB,
  "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" TIMESTAMP(3) NOT NULL,
  CONSTRAINT "notification_subscriptions_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX IF NOT EXISTS "notification_subscriptions_user_id_category_key"
  ON "notification_subscriptions"("user_id", "category");
CREATE INDEX IF NOT EXISTS "notification_subscriptions_user_id_enabled_idx"
  ON "notification_subscriptions"("user_id", "enabled");

ALTER TABLE "notification_subscriptions"
  ADD CONSTRAINT "notification_subscriptions_user_id_fkey"
  FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

CREATE TABLE IF NOT EXISTS "device_push_tokens" (
  "id" TEXT NOT NULL,
  "user_id" TEXT NOT NULL,
  "device_id" TEXT NOT NULL,
  "platform" TEXT NOT NULL,
  "push_token" TEXT NOT NULL,
  "is_active" BOOLEAN NOT NULL DEFAULT true,
  "app_version" TEXT,
  "locale" TEXT,
  "last_seen_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" TIMESTAMP(3) NOT NULL,
  CONSTRAINT "device_push_tokens_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX IF NOT EXISTS "device_push_tokens_user_id_device_id_platform_key"
  ON "device_push_tokens"("user_id", "device_id", "platform");
CREATE INDEX IF NOT EXISTS "device_push_tokens_user_id_is_active_idx"
  ON "device_push_tokens"("user_id", "is_active");
CREATE INDEX IF NOT EXISTS "device_push_tokens_push_token_idx"
  ON "device_push_tokens"("push_token");

ALTER TABLE "device_push_tokens"
  ADD CONSTRAINT "device_push_tokens_user_id_fkey"
  FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

CREATE TABLE IF NOT EXISTS "notification_events" (
  "id" TEXT NOT NULL,
  "category" TEXT NOT NULL,
  "payload" JSONB NOT NULL,
  "dedupe_key" TEXT,
  "status" TEXT NOT NULL DEFAULT 'queued',
  "scheduled_at" TIMESTAMP(3),
  "dispatched_at" TIMESTAMP(3),
  "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" TIMESTAMP(3) NOT NULL,
  CONSTRAINT "notification_events_pkey" PRIMARY KEY ("id")
);

CREATE INDEX IF NOT EXISTS "notification_events_category_created_at_idx"
  ON "notification_events"("category", "created_at");
CREATE INDEX IF NOT EXISTS "notification_events_status_scheduled_at_idx"
  ON "notification_events"("status", "scheduled_at");
CREATE INDEX IF NOT EXISTS "notification_events_dedupe_key_idx"
  ON "notification_events"("dedupe_key");

CREATE TABLE IF NOT EXISTS "notification_inbox" (
  "id" TEXT NOT NULL,
  "user_id" TEXT NOT NULL,
  "type" TEXT NOT NULL,
  "title" TEXT NOT NULL,
  "body" TEXT NOT NULL,
  "deeplink" TEXT,
  "metadata" JSONB,
  "source_event_id" TEXT,
  "is_read" BOOLEAN NOT NULL DEFAULT false,
  "read_at" TIMESTAMP(3),
  "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" TIMESTAMP(3) NOT NULL,
  CONSTRAINT "notification_inbox_pkey" PRIMARY KEY ("id")
);

CREATE INDEX IF NOT EXISTS "notification_inbox_user_id_is_read_created_at_idx"
  ON "notification_inbox"("user_id", "is_read", "created_at");
CREATE INDEX IF NOT EXISTS "notification_inbox_source_event_id_idx"
  ON "notification_inbox"("source_event_id");

ALTER TABLE "notification_inbox"
  ADD CONSTRAINT "notification_inbox_user_id_fkey"
  FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

CREATE TABLE IF NOT EXISTS "notification_deliveries" (
  "id" TEXT NOT NULL,
  "event_id" TEXT NOT NULL,
  "user_id" TEXT NOT NULL,
  "channel" TEXT NOT NULL,
  "status" TEXT NOT NULL DEFAULT 'queued',
  "error" TEXT,
  "attempts" INTEGER NOT NULL DEFAULT 0,
  "delivered_at" TIMESTAMP(3),
  "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" TIMESTAMP(3) NOT NULL,
  CONSTRAINT "notification_deliveries_pkey" PRIMARY KEY ("id")
);

CREATE INDEX IF NOT EXISTS "notification_deliveries_event_id_channel_idx"
  ON "notification_deliveries"("event_id", "channel");
CREATE INDEX IF NOT EXISTS "notification_deliveries_user_id_created_at_idx"
  ON "notification_deliveries"("user_id", "created_at");
CREATE INDEX IF NOT EXISTS "notification_deliveries_status_created_at_idx"
  ON "notification_deliveries"("status", "created_at");

ALTER TABLE "notification_deliveries"
  ADD CONSTRAINT "notification_deliveries_event_id_fkey"
  FOREIGN KEY ("event_id") REFERENCES "notification_events"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "notification_deliveries"
  ADD CONSTRAINT "notification_deliveries_user_id_fkey"
  FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
