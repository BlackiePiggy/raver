CREATE TABLE IF NOT EXISTS "entity_change_logs" (
  "id" TEXT NOT NULL,
  "entity_type" TEXT NOT NULL,
  "entity_id" TEXT NOT NULL,
  "operation_type" TEXT NOT NULL,
  "actor_id" TEXT,
  "actor_role" TEXT,
  "source" TEXT,
  "source_route" TEXT,
  "request_id" TEXT,
  "snapshot_schema_version" INTEGER NOT NULL,
  "diff_schema_version" INTEGER NOT NULL,
  "revision_before" INTEGER,
  "revision_after" INTEGER,
  "before_hash" TEXT,
  "after_hash" TEXT,
  "changed" BOOLEAN NOT NULL DEFAULT true,
  "change_count" INTEGER NOT NULL DEFAULT 0,
  "private_summary_zh" TEXT,
  "operator_summary_zh" TEXT,
  "public_summary_zh" TEXT,
  "private_summary_en" TEXT,
  "operator_summary_en" TEXT,
  "public_summary_en" TEXT,
  "changes" JSONB NOT NULL,
  "public_changes" JSONB NOT NULL,
  "metadata" JSONB,
  "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "entity_change_logs_pkey" PRIMARY KEY ("id")
);

CREATE INDEX IF NOT EXISTS "entity_change_logs_entity_type_entity_id_created_at_idx"
  ON "entity_change_logs"("entity_type", "entity_id", "created_at");

CREATE INDEX IF NOT EXISTS "entity_change_logs_actor_id_created_at_idx"
  ON "entity_change_logs"("actor_id", "created_at");

CREATE INDEX IF NOT EXISTS "entity_change_logs_operation_type_created_at_idx"
  ON "entity_change_logs"("operation_type", "created_at");

CREATE INDEX IF NOT EXISTS "entity_change_logs_changed_created_at_idx"
  ON "entity_change_logs"("changed", "created_at");
