CREATE TABLE "account_deletion_requests" (
    "id" TEXT NOT NULL,
    "user_id" TEXT NOT NULL,
    "status" TEXT NOT NULL DEFAULT 'queued',
    "requested_by" TEXT NOT NULL DEFAULT 'user',
    "request_source" TEXT NOT NULL DEFAULT 'ios',
    "original_email_hash" TEXT,
    "original_phone_hash" TEXT,
    "previous_avatar_url" TEXT,
    "previous_profile_qr_url" TEXT,
    "im_user_id" TEXT,
    "im_status" TEXT NOT NULL DEFAULT 'pending',
    "im_attempts" INTEGER NOT NULL DEFAULT 0,
    "im_next_run_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "im_last_error" TEXT,
    "media_status" TEXT NOT NULL DEFAULT 'pending',
    "media_attempts" INTEGER NOT NULL DEFAULT 0,
    "media_next_run_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "media_last_error" TEXT,
    "media_targets" JSONB,
    "completed_at" TIMESTAMP(3),
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "account_deletion_requests_pkey" PRIMARY KEY ("id")
);

CREATE INDEX "account_deletion_requests_user_id_created_at_idx"
    ON "account_deletion_requests"("user_id", "created_at");

CREATE INDEX "account_deletion_requests_status_created_at_idx"
    ON "account_deletion_requests"("status", "created_at");

CREATE INDEX "account_deletion_requests_im_status_im_next_run_at_idx"
    ON "account_deletion_requests"("im_status", "im_next_run_at");

CREATE INDEX "account_deletion_requests_media_status_media_next_run_at_idx"
    ON "account_deletion_requests"("media_status", "media_next_run_at");

ALTER TABLE "account_deletion_requests"
ADD CONSTRAINT "account_deletion_requests_user_id_fkey"
FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
