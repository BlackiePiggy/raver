CREATE TABLE "content_submissions" (
    "id" TEXT NOT NULL,
    "submitter_id" TEXT NOT NULL,
    "entity_type" TEXT NOT NULL,
    "status" TEXT NOT NULL DEFAULT 'pending',
    "title" TEXT NOT NULL,
    "payload" JSONB NOT NULL,
    "review_reason" TEXT,
    "reviewed_at" TIMESTAMP(3),
    "reviewed_by" TEXT,
    "created_entity_id" TEXT,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "content_submissions_pkey" PRIMARY KEY ("id")
);

ALTER TABLE "content_submissions"
ADD CONSTRAINT "content_submissions_submitter_id_fkey"
FOREIGN KEY ("submitter_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

CREATE INDEX "content_submissions_submitter_id_created_at_idx"
ON "content_submissions"("submitter_id", "created_at");

CREATE INDEX "content_submissions_entity_type_status_created_at_idx"
ON "content_submissions"("entity_type", "status", "created_at");

CREATE INDEX "content_submissions_status_created_at_idx"
ON "content_submissions"("status", "created_at");
