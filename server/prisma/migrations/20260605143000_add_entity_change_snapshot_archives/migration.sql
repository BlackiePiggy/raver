CREATE TABLE IF NOT EXISTS "entity_change_snapshot_archives" (
  "id" TEXT NOT NULL,
  "change_log_id" TEXT NOT NULL,
  "entity_type" TEXT NOT NULL,
  "entity_id" TEXT NOT NULL,
  "snapshot_role" TEXT NOT NULL,
  "snapshot_schema_version" INTEGER NOT NULL,
  "snapshot_hash" TEXT NOT NULL,
  "snapshot" JSONB NOT NULL,
  "expires_at" TIMESTAMP(3) NOT NULL,
  "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "entity_change_snapshot_archives_pkey" PRIMARY KEY ("id"),
  CONSTRAINT "entity_change_snapshot_archives_change_log_id_fkey"
    FOREIGN KEY ("change_log_id") REFERENCES "entity_change_logs"("id") ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE UNIQUE INDEX IF NOT EXISTS "entity_change_snapshot_archives_change_log_id_snapshot_role_key"
  ON "entity_change_snapshot_archives"("change_log_id", "snapshot_role");

CREATE INDEX IF NOT EXISTS "entity_change_snapshot_archives_entity_type_entity_id_created_at_idx"
  ON "entity_change_snapshot_archives"("entity_type", "entity_id", "created_at");

CREATE INDEX IF NOT EXISTS "entity_change_snapshot_archives_expires_at_idx"
  ON "entity_change_snapshot_archives"("expires_at");
