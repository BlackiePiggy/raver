ALTER TABLE "dj_contributors"
ADD COLUMN "role" TEXT NOT NULL DEFAULT 'editor',
ADD COLUMN "first_contributed_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
ADD COLUMN "last_contributed_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
ADD COLUMN "contribution_count" INTEGER NOT NULL DEFAULT 1,
ADD COLUMN "first_submission_id" TEXT,
ADD COLUMN "last_submission_id" TEXT,
ADD COLUMN "last_contribution_source" TEXT;

UPDATE "dj_contributors"
SET
  "first_contributed_at" = COALESCE("created_at", CURRENT_TIMESTAMP),
  "last_contributed_at" = COALESCE("updated_at", "created_at", CURRENT_TIMESTAMP),
  "contribution_count" = 1,
  "role" = 'editor'
WHERE TRUE;

CREATE INDEX "dj_contributors_dj_id_last_contributed_at_idx"
ON "dj_contributors"("dj_id", "last_contributed_at");

CREATE TABLE "event_contributors" (
  "id" TEXT NOT NULL,
  "event_id" TEXT NOT NULL,
  "user_id" TEXT NOT NULL,
  "role" TEXT NOT NULL DEFAULT 'editor',
  "first_contributed_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "last_contributed_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "contribution_count" INTEGER NOT NULL DEFAULT 1,
  "first_submission_id" TEXT,
  "last_submission_id" TEXT,
  "last_contribution_source" TEXT,
  "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

  CONSTRAINT "event_contributors_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX "event_contributors_event_id_user_id_key"
ON "event_contributors"("event_id", "user_id");

CREATE INDEX "event_contributors_event_id_idx"
ON "event_contributors"("event_id");

CREATE INDEX "event_contributors_user_id_idx"
ON "event_contributors"("user_id");

CREATE INDEX "event_contributors_event_id_last_contributed_at_idx"
ON "event_contributors"("event_id", "last_contributed_at");

ALTER TABLE "event_contributors"
ADD CONSTRAINT "event_contributors_event_id_fkey"
FOREIGN KEY ("event_id") REFERENCES "events"("id") ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "event_contributors"
ADD CONSTRAINT "event_contributors_user_id_fkey"
FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

CREATE TABLE "contribution_history_entries" (
  "id" TEXT NOT NULL,
  "user_id" TEXT NOT NULL,
  "entity_type" TEXT NOT NULL,
  "entity_id" TEXT NOT NULL,
  "entity_title_snapshot" TEXT,
  "entity_cover_snapshot" TEXT,
  "role_snapshot" TEXT NOT NULL,
  "action_type" TEXT NOT NULL,
  "source" TEXT NOT NULL,
  "submission_id" TEXT,
  "occurred_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "approved_at" TIMESTAMP(3),
  "version_after" INTEGER,
  "change_summary" TEXT,
  "metadata" JSONB,
  "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

  CONSTRAINT "contribution_history_entries_pkey" PRIMARY KEY ("id")
);

CREATE INDEX "contribution_history_entries_user_id_occurred_at_idx"
ON "contribution_history_entries"("user_id", "occurred_at");

CREATE INDEX "contribution_history_entries_entity_type_entity_id_occurred_idx"
ON "contribution_history_entries"("entity_type", "entity_id", "occurred_at");

CREATE INDEX "contribution_history_entries_submission_id_idx"
ON "contribution_history_entries"("submission_id");

ALTER TABLE "contribution_history_entries"
ADD CONSTRAINT "contribution_history_entries_user_id_fkey"
FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
