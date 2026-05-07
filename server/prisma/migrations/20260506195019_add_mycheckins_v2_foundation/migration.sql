ALTER TABLE "checkins"
  ADD COLUMN IF NOT EXISTS "projection_version" INTEGER NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS "schema_version" INTEGER NOT NULL DEFAULT 1,
  ADD COLUMN IF NOT EXISTS "source" TEXT NOT NULL DEFAULT 'ios',
  ADD COLUMN IF NOT EXISTS "status" TEXT NOT NULL DEFAULT 'active',
  ADD COLUMN IF NOT EXISTS "visibility" TEXT NOT NULL DEFAULT 'private';

ALTER TABLE "checkins"
  ADD COLUMN IF NOT EXISTS "updated_at" TIMESTAMP(3);

UPDATE "checkins"
SET "updated_at" = COALESCE("updated_at", "created_at", CURRENT_TIMESTAMP)
WHERE "updated_at" IS NULL;

ALTER TABLE "checkins"
  ALTER COLUMN "updated_at" SET NOT NULL;

CREATE TABLE IF NOT EXISTS "checkin_snapshots" (
  "checkin_id" TEXT NOT NULL,
  "user_display_name" TEXT,
  "event_name" TEXT,
  "event_name_i18n" JSONB,
  "event_cover_url" TEXT,
  "event_city" TEXT,
  "event_country" TEXT,
  "event_address" TEXT,
  "event_start_at" TIMESTAMP(3),
  "event_end_at" TIMESTAMP(3),
  "primary_dj_name" TEXT,
  "primary_dj_name_i18n" JSONB,
  "primary_dj_avatar_url" TEXT,
  "primary_dj_country" TEXT,
  "selection_summary" JSONB,
  "visibility_resolved" TEXT NOT NULL DEFAULT 'private',
  "snapshot_version" INTEGER NOT NULL DEFAULT 1,
  "generated_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

  CONSTRAINT "checkin_snapshots_pkey" PRIMARY KEY ("checkin_id"),
  CONSTRAINT "checkin_snapshots_checkin_id_fkey"
    FOREIGN KEY ("checkin_id") REFERENCES "checkins"("id")
    ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE TABLE IF NOT EXISTS "checkin_selections" (
  "id" TEXT NOT NULL,
  "checkin_id" TEXT NOT NULL,
  "day_id" TEXT NOT NULL,
  "day_index" INTEGER NOT NULL,
  "sort_order" INTEGER NOT NULL DEFAULT 0,
  "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

  CONSTRAINT "checkin_selections_pkey" PRIMARY KEY ("id"),
  CONSTRAINT "checkin_selections_checkin_id_fkey"
    FOREIGN KEY ("checkin_id") REFERENCES "checkins"("id")
    ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE TABLE IF NOT EXISTS "checkin_selection_djs" (
  "id" TEXT NOT NULL,
  "selection_id" TEXT NOT NULL,
  "dj_id" TEXT,
  "act_group_id" TEXT,
  "raw_name" TEXT NOT NULL,
  "display_name" TEXT NOT NULL,
  "avatar_url" TEXT,
  "country" TEXT,
  "act_type" TEXT,
  "performer_index" INTEGER NOT NULL DEFAULT 0,
  "sort_order" INTEGER NOT NULL DEFAULT 0,
  "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

  CONSTRAINT "checkin_selection_djs_pkey" PRIMARY KEY ("id"),
  CONSTRAINT "checkin_selection_djs_selection_id_fkey"
    FOREIGN KEY ("selection_id") REFERENCES "checkin_selections"("id")
    ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE TABLE IF NOT EXISTS "user_checkin_timeline_entries" (
  "id" TEXT NOT NULL,
  "user_id" TEXT NOT NULL,
  "timeline_date" DATE NOT NULL,
  "anchor_at" TIMESTAMP(3) NOT NULL,
  "node_type" TEXT NOT NULL,
  "primary_checkin_id" TEXT NOT NULL,
  "event_id" TEXT,
  "event_name" TEXT,
  "event_cover_url" TEXT,
  "event_address" TEXT,
  "payload" JSONB NOT NULL,
  "stats_dj_count" INTEGER NOT NULL DEFAULT 0,
  "stats_performance_count" INTEGER NOT NULL DEFAULT 0,
  "stats_selection_count" INTEGER NOT NULL DEFAULT 0,
  "visibility_resolved" TEXT NOT NULL DEFAULT 'private',
  "projection_version" INTEGER NOT NULL DEFAULT 1,
  "updated_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

  CONSTRAINT "user_checkin_timeline_entries_pkey" PRIMARY KEY ("id")
);

CREATE TABLE IF NOT EXISTS "user_checkin_stats" (
  "id" TEXT NOT NULL,
  "user_id" TEXT NOT NULL,
  "scope" TEXT NOT NULL DEFAULT 'all',
  "event_count" INTEGER NOT NULL DEFAULT 0,
  "artist_count" INTEGER NOT NULL DEFAULT 0,
  "event_checkin_count" INTEGER NOT NULL DEFAULT 0,
  "dj_checkin_count" INTEGER NOT NULL DEFAULT 0,
  "performance_count" INTEGER NOT NULL DEFAULT 0,
  "latest_checkin_at" TIMESTAMP(3),
  "visibility_resolved" TEXT NOT NULL DEFAULT 'private',
  "projection_version" INTEGER NOT NULL DEFAULT 1,
  "updated_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

  CONSTRAINT "user_checkin_stats_pkey" PRIMARY KEY ("id")
);

ALTER TABLE "user_checkin_stats"
  ADD COLUMN IF NOT EXISTS "id" TEXT,
  ADD COLUMN IF NOT EXISTS "scope" TEXT NOT NULL DEFAULT 'all';

UPDATE "user_checkin_stats"
SET "id" = gen_random_uuid()::text
WHERE "id" IS NULL;

ALTER TABLE "user_checkin_stats"
  ALTER COLUMN "id" SET NOT NULL;

DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'user_checkin_stats_pkey'
      AND conrelid = 'user_checkin_stats'::regclass
      AND pg_get_constraintdef(oid) = 'PRIMARY KEY (user_id)'
  ) THEN
    ALTER TABLE "user_checkin_stats" DROP CONSTRAINT "user_checkin_stats_pkey";
    ALTER TABLE "user_checkin_stats" ADD CONSTRAINT "user_checkin_stats_pkey" PRIMARY KEY ("id");
  END IF;
END $$;

CREATE TABLE IF NOT EXISTS "user_checkin_gallery_dj_aggregates" (
  "id" TEXT NOT NULL,
  "user_id" TEXT NOT NULL,
  "scope" TEXT NOT NULL DEFAULT 'all',
  "dj_id" TEXT,
  "display_name" TEXT NOT NULL,
  "avatar_url" TEXT,
  "country" TEXT,
  "count" INTEGER NOT NULL DEFAULT 0,
  "latest_attended_at" TIMESTAMP(3),
  "visibility_resolved" TEXT NOT NULL DEFAULT 'private',
  "projection_version" INTEGER NOT NULL DEFAULT 1,
  "updated_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

  CONSTRAINT "user_checkin_gallery_dj_aggregates_pkey" PRIMARY KEY ("id")
);

ALTER TABLE "user_checkin_gallery_dj_aggregates"
  ADD COLUMN IF NOT EXISTS "scope" TEXT NOT NULL DEFAULT 'all';

CREATE TABLE IF NOT EXISTS "user_checkin_gallery_event_aggregates" (
  "id" TEXT NOT NULL,
  "user_id" TEXT NOT NULL,
  "scope" TEXT NOT NULL DEFAULT 'all',
  "event_id" TEXT,
  "event_name" TEXT NOT NULL,
  "event_cover_url" TEXT,
  "event_address" TEXT,
  "artist_count" INTEGER NOT NULL DEFAULT 0,
  "performance_count" INTEGER NOT NULL DEFAULT 0,
  "count" INTEGER NOT NULL DEFAULT 0,
  "latest_attended_at" TIMESTAMP(3),
  "visibility_resolved" TEXT NOT NULL DEFAULT 'private',
  "projection_version" INTEGER NOT NULL DEFAULT 1,
  "updated_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

  CONSTRAINT "user_checkin_gallery_event_aggregates_pkey" PRIMARY KEY ("id")
);

ALTER TABLE "user_checkin_gallery_event_aggregates"
  ADD COLUMN IF NOT EXISTS "scope" TEXT NOT NULL DEFAULT 'all',
  ADD COLUMN IF NOT EXISTS "artist_count" INTEGER NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS "performance_count" INTEGER NOT NULL DEFAULT 0;

CREATE TABLE IF NOT EXISTS "user_checkin_derived_signals" (
  "id" TEXT NOT NULL,
  "user_id" TEXT NOT NULL,
  "signal_type" TEXT NOT NULL,
  "signal_key" TEXT NOT NULL,
  "signal_value" JSONB NOT NULL,
  "score" DECIMAL(12,4),
  "projection_version" INTEGER NOT NULL DEFAULT 1,
  "updated_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

  CONSTRAINT "user_checkin_derived_signals_pkey" PRIMARY KEY ("id")
);

CREATE TABLE IF NOT EXISTS "checkin_outbox_events" (
  "id" TEXT NOT NULL,
  "event_type" TEXT NOT NULL,
  "aggregate_type" TEXT NOT NULL,
  "aggregate_id" TEXT NOT NULL,
  "user_id" TEXT NOT NULL,
  "payload" JSONB NOT NULL,
  "status" TEXT NOT NULL DEFAULT 'pending',
  "retry_count" INTEGER NOT NULL DEFAULT 0,
  "available_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "processed_at" TIMESTAMP(3),
  "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

  CONSTRAINT "checkin_outbox_events_pkey" PRIMARY KEY ("id")
);

CREATE INDEX IF NOT EXISTS "checkins_user_id_visibility_attended_at_idx"
  ON "checkins" ("user_id", "visibility", "attended_at");

CREATE INDEX IF NOT EXISTS "checkins_user_id_event_id_type_status_idx"
  ON "checkins" ("user_id", "event_id", "type", "status");

CREATE INDEX IF NOT EXISTS "checkin_selections_checkin_id_day_index_idx"
  ON "checkin_selections" ("checkin_id", "day_index");

CREATE INDEX IF NOT EXISTS "checkin_selection_djs_selection_id_sort_order_idx"
  ON "checkin_selection_djs" ("selection_id", "sort_order");

CREATE INDEX IF NOT EXISTS "checkin_selection_djs_dj_id_idx"
  ON "checkin_selection_djs" ("dj_id");

CREATE INDEX IF NOT EXISTS "user_checkin_timeline_entries_user_id_timeline_date_anchor_at_idx"
  ON "user_checkin_timeline_entries" ("user_id", "timeline_date", "anchor_at");

CREATE INDEX IF NOT EXISTS "user_checkin_timeline_entries_user_id_visibility_anchor_at_idx"
  ON "user_checkin_timeline_entries" ("user_id", "visibility_resolved", "anchor_at");

CREATE INDEX IF NOT EXISTS "user_checkin_timeline_entries_primary_checkin_id_idx"
  ON "user_checkin_timeline_entries" ("primary_checkin_id");

CREATE INDEX IF NOT EXISTS "user_checkin_stats_visibility_latest_checkin_at_idx"
  ON "user_checkin_stats" ("scope", "visibility_resolved", "latest_checkin_at");

CREATE UNIQUE INDEX IF NOT EXISTS "user_checkin_stats_user_id_scope_key"
  ON "user_checkin_stats" ("user_id", "scope");

CREATE INDEX IF NOT EXISTS "user_checkin_gallery_dj_aggregates_user_id_count_latest_idx"
  ON "user_checkin_gallery_dj_aggregates" ("user_id", "scope", "count", "latest_attended_at");

CREATE INDEX IF NOT EXISTS "user_checkin_gallery_dj_aggregates_user_id_visibility_count_idx"
  ON "user_checkin_gallery_dj_aggregates" ("user_id", "scope", "visibility_resolved", "count");

CREATE INDEX IF NOT EXISTS "user_checkin_gallery_dj_aggregates_dj_id_idx"
  ON "user_checkin_gallery_dj_aggregates" ("dj_id");

CREATE INDEX IF NOT EXISTS "user_checkin_gallery_event_aggregates_user_id_count_latest_idx"
  ON "user_checkin_gallery_event_aggregates" ("user_id", "scope", "count", "latest_attended_at");

CREATE INDEX IF NOT EXISTS "user_checkin_gallery_event_aggregates_user_id_visibility_count_idx"
  ON "user_checkin_gallery_event_aggregates" ("user_id", "scope", "visibility_resolved", "count");

CREATE INDEX IF NOT EXISTS "user_checkin_gallery_event_aggregates_event_id_idx"
  ON "user_checkin_gallery_event_aggregates" ("event_id");

CREATE UNIQUE INDEX IF NOT EXISTS "user_checkin_derived_signals_user_id_signal_type_signal_key_key"
  ON "user_checkin_derived_signals" ("user_id", "signal_type", "signal_key");

CREATE INDEX IF NOT EXISTS "user_checkin_derived_signals_user_id_signal_type_idx"
  ON "user_checkin_derived_signals" ("user_id", "signal_type");

CREATE INDEX IF NOT EXISTS "checkin_outbox_events_status_available_at_idx"
  ON "checkin_outbox_events" ("status", "available_at");

CREATE INDEX IF NOT EXISTS "checkin_outbox_events_aggregate_type_aggregate_id_idx"
  ON "checkin_outbox_events" ("aggregate_type", "aggregate_id");

CREATE INDEX IF NOT EXISTS "checkin_outbox_events_user_id_created_at_idx"
  ON "checkin_outbox_events" ("user_id", "created_at");
