ALTER TABLE "content_submissions"
ADD COLUMN "idempotency_key" TEXT;

CREATE UNIQUE INDEX "content_submissions_submitter_id_idempotency_key_key"
ON "content_submissions"("submitter_id", "idempotency_key");
