-- Notification center admin templates and global configs

CREATE TABLE IF NOT EXISTS "notification_templates" (
  "id" TEXT NOT NULL,
  "category" TEXT NOT NULL,
  "locale" TEXT NOT NULL DEFAULT 'zh-CN',
  "channel" TEXT NOT NULL DEFAULT 'in_app',
  "title_template" TEXT NOT NULL,
  "body_template" TEXT NOT NULL,
  "deeplink_template" TEXT,
  "variables" JSONB,
  "is_active" BOOLEAN NOT NULL DEFAULT true,
  "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" TIMESTAMP(3) NOT NULL,
  CONSTRAINT "notification_templates_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX IF NOT EXISTS "notification_templates_category_locale_channel_key"
  ON "notification_templates"("category", "locale", "channel");
CREATE INDEX IF NOT EXISTS "notification_templates_category_is_active_idx"
  ON "notification_templates"("category", "is_active");
CREATE INDEX IF NOT EXISTS "notification_templates_updated_at_idx"
  ON "notification_templates"("updated_at");

CREATE TABLE IF NOT EXISTS "notification_admin_configs" (
  "id" TEXT NOT NULL,
  "config_key" TEXT NOT NULL,
  "config" JSONB NOT NULL,
  "updated_by" TEXT,
  "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" TIMESTAMP(3) NOT NULL,
  CONSTRAINT "notification_admin_configs_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX IF NOT EXISTS "notification_admin_configs_config_key_key"
  ON "notification_admin_configs"("config_key");
CREATE INDEX IF NOT EXISTS "notification_admin_configs_updated_at_idx"
  ON "notification_admin_configs"("updated_at");
