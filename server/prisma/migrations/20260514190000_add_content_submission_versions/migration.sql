CREATE TABLE "content_submission_versions" (
    "id" TEXT NOT NULL,
    "submission_id" TEXT NOT NULL,
    "version" INTEGER NOT NULL,
    "title" TEXT NOT NULL,
    "payload" JSONB NOT NULL,
    "submitted_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "submitted_by" TEXT,
    "change_note" TEXT,

    CONSTRAINT "content_submission_versions_pkey" PRIMARY KEY ("id")
);

ALTER TABLE "content_submission_versions"
ADD CONSTRAINT "content_submission_versions_submission_id_fkey"
FOREIGN KEY ("submission_id") REFERENCES "content_submissions"("id") ON DELETE CASCADE ON UPDATE CASCADE;

CREATE UNIQUE INDEX "content_submission_versions_submission_id_version_key"
ON "content_submission_versions"("submission_id", "version");

CREATE INDEX "content_submission_versions_submission_id_submitted_at_idx"
ON "content_submission_versions"("submission_id", "submitted_at");

INSERT INTO "content_submission_versions" (
    "id",
    "submission_id",
    "version",
    "title",
    "payload",
    "submitted_at",
    "submitted_by",
    "change_note"
)
SELECT
    gen_random_uuid()::text,
    "id",
    1,
    "title",
    "payload",
    "created_at",
    "submitter_id",
    'Initial submission'
FROM "content_submissions"
WHERE NOT EXISTS (
    SELECT 1
    FROM "content_submission_versions"
    WHERE "content_submission_versions"."submission_id" = "content_submissions"."id"
);
