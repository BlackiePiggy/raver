CREATE TABLE "openim_image_moderation_jobs" (
    "id" TEXT NOT NULL,
    "webhook_event_id" TEXT,
    "message_id" TEXT,
    "conversation_id" TEXT,
    "image_url" TEXT NOT NULL,
    "status" TEXT NOT NULL DEFAULT 'pending',
    "reason" TEXT,
    "source" TEXT NOT NULL DEFAULT 'openim_webhook',
    "provider" TEXT NOT NULL DEFAULT 'manual_review',
    "decision_detail" JSONB,
    "reviewed_at" TIMESTAMP(3),
    "reviewed_by" TEXT,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "openim_image_moderation_jobs_pkey" PRIMARY KEY ("id")
);

CREATE INDEX "openim_image_moderation_jobs_status_created_at_idx"
ON "openim_image_moderation_jobs"("status", "created_at");

CREATE INDEX "openim_image_moderation_jobs_webhook_event_id_idx"
ON "openim_image_moderation_jobs"("webhook_event_id");

CREATE INDEX "openim_image_moderation_jobs_message_id_created_at_idx"
ON "openim_image_moderation_jobs"("message_id", "created_at");
