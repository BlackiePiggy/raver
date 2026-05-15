CREATE TABLE "content_reports" (
    "id" TEXT NOT NULL,
    "reporter_user_id" TEXT NOT NULL,
    "target_type" TEXT NOT NULL,
    "target_id" TEXT NOT NULL,
    "target_user_id" TEXT,
    "reason" TEXT NOT NULL,
    "detail" TEXT,
    "source" TEXT NOT NULL DEFAULT 'in_app',
    "status" TEXT NOT NULL DEFAULT 'pending',
    "metadata" JSONB,
    "resolved_at" TIMESTAMP(3),
    "resolved_by" TEXT,
    "resolution_note" TEXT,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "content_reports_pkey" PRIMARY KEY ("id")
);

CREATE TABLE "user_blocks" (
    "id" TEXT NOT NULL,
    "blocker_user_id" TEXT NOT NULL,
    "blocked_user_id" TEXT NOT NULL,
    "reason" TEXT,
    "note" TEXT,
    "source" TEXT NOT NULL DEFAULT 'in_app',
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "user_blocks_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX "content_reports_reporter_user_id_target_type_target_id_key"
    ON "content_reports"("reporter_user_id", "target_type", "target_id");

CREATE INDEX "content_reports_reporter_user_id_created_at_idx"
    ON "content_reports"("reporter_user_id", "created_at");

CREATE INDEX "content_reports_target_type_target_id_idx"
    ON "content_reports"("target_type", "target_id");

CREATE INDEX "content_reports_status_created_at_idx"
    ON "content_reports"("status", "created_at");

CREATE INDEX "content_reports_target_user_id_created_at_idx"
    ON "content_reports"("target_user_id", "created_at");

CREATE UNIQUE INDEX "user_blocks_blocker_user_id_blocked_user_id_key"
    ON "user_blocks"("blocker_user_id", "blocked_user_id");

CREATE INDEX "user_blocks_blocker_user_id_created_at_idx"
    ON "user_blocks"("blocker_user_id", "created_at");

CREATE INDEX "user_blocks_blocked_user_id_created_at_idx"
    ON "user_blocks"("blocked_user_id", "created_at");

