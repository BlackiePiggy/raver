-- Add structured evidence attachment support for in-app reports.
ALTER TABLE "content_reports"
ADD COLUMN IF NOT EXISTS "attachments" JSONB;

-- Configurable, versioned, tri-lingual moderation decision templates.
CREATE TABLE IF NOT EXISTS "moderation_decision_templates" (
  "id" TEXT NOT NULL,
  "template_key" TEXT NOT NULL,
  "locale" TEXT NOT NULL,
  "title" TEXT NOT NULL,
  "body" TEXT NOT NULL,
  "status" TEXT NOT NULL DEFAULT 'draft',
  "version" INTEGER NOT NULL DEFAULT 1,
  "published_at" TIMESTAMP(3),
  "published_by" TEXT,
  "created_by" TEXT,
  "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "moderation_decision_templates_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX IF NOT EXISTS "moderation_decision_templates_template_key_locale_version_key"
ON "moderation_decision_templates"("template_key", "locale", "version");

CREATE INDEX IF NOT EXISTS "moderation_decision_templates_template_key_locale_status_idx"
ON "moderation_decision_templates"("template_key", "locale", "status");

CREATE INDEX IF NOT EXISTS "moderation_decision_templates_status_updated_at_idx"
ON "moderation_decision_templates"("status", "updated_at");
