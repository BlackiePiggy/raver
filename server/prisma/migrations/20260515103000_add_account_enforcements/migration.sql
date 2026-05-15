CREATE TABLE "account_enforcements" (
    "id" TEXT NOT NULL,
    "user_id" TEXT NOT NULL,
    "status" TEXT NOT NULL DEFAULT 'active',
    "type" TEXT NOT NULL,
    "scopes" TEXT[] NOT NULL DEFAULT ARRAY[]::TEXT[],
    "reason_code" TEXT NOT NULL,
    "user_message_i18n" JSONB,
    "internal_note" TEXT,
    "evidence" JSONB,
    "starts_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "ends_at" TIMESTAMP(3),
    "created_by" TEXT,
    "created_from_report_id" TEXT,
    "created_from_case_id" TEXT,
    "revoked_at" TIMESTAMP(3),
    "revoked_by" TEXT,
    "revocation_reason" TEXT,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "account_enforcements_pkey" PRIMARY KEY ("id")
);

CREATE TABLE "enforcement_appeals" (
    "id" TEXT NOT NULL,
    "enforcement_id" TEXT NOT NULL,
    "user_id" TEXT NOT NULL,
    "status" TEXT NOT NULL DEFAULT 'submitted',
    "appeal_reason" TEXT NOT NULL,
    "attachments" JSONB,
    "contact_email" TEXT,
    "reviewer_id" TEXT,
    "decision" TEXT,
    "decision_note" TEXT,
    "reviewed_at" TIMESTAMP(3),
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "enforcement_appeals_pkey" PRIMARY KEY ("id")
);

CREATE INDEX "account_enforcements_user_id_status_starts_at_idx" ON "account_enforcements"("user_id", "status", "starts_at");
CREATE INDEX "account_enforcements_type_status_starts_at_idx" ON "account_enforcements"("type", "status", "starts_at");
CREATE INDEX "account_enforcements_reason_code_status_starts_at_idx" ON "account_enforcements"("reason_code", "status", "starts_at");
CREATE INDEX "account_enforcements_created_by_created_at_idx" ON "account_enforcements"("created_by", "created_at");
CREATE INDEX "account_enforcements_created_from_report_id_idx" ON "account_enforcements"("created_from_report_id");

CREATE INDEX "enforcement_appeals_enforcement_id_created_at_idx" ON "enforcement_appeals"("enforcement_id", "created_at");
CREATE INDEX "enforcement_appeals_user_id_created_at_idx" ON "enforcement_appeals"("user_id", "created_at");
CREATE INDEX "enforcement_appeals_status_created_at_idx" ON "enforcement_appeals"("status", "created_at");
CREATE INDEX "enforcement_appeals_reviewer_id_reviewed_at_idx" ON "enforcement_appeals"("reviewer_id", "reviewed_at");

ALTER TABLE "account_enforcements" ADD CONSTRAINT "account_enforcements_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "enforcement_appeals" ADD CONSTRAINT "enforcement_appeals_enforcement_id_fkey" FOREIGN KEY ("enforcement_id") REFERENCES "account_enforcements"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "enforcement_appeals" ADD CONSTRAINT "enforcement_appeals_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
