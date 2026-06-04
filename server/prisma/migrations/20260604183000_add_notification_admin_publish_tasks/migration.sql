SET statement_timeout = 0;

CREATE TABLE IF NOT EXISTS "notification_admin_publish_tasks" (
  "id" TEXT NOT NULL,
  "task_type" TEXT NOT NULL,
  "entity_type" TEXT NOT NULL,
  "entity_id" TEXT NOT NULL,
  "status" TEXT NOT NULL DEFAULT 'pending',
  "title" TEXT NOT NULL,
  "summary" TEXT,
  "payload" JSONB NOT NULL,
  "decision" JSONB,
  "created_by" TEXT,
  "decided_by" TEXT,
  "decided_at" TIMESTAMP(3),
  "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

  CONSTRAINT "notification_admin_publish_tasks_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX IF NOT EXISTS "notification_admin_publish_tasks_task_type_entity_type_entity_key"
ON "notification_admin_publish_tasks"("task_type", "entity_type", "entity_id");

CREATE INDEX IF NOT EXISTS "notification_admin_publish_tasks_status_created_at_idx"
ON "notification_admin_publish_tasks"("status", "created_at");

CREATE INDEX IF NOT EXISTS "notification_admin_publish_tasks_task_type_status_updated_at_idx"
ON "notification_admin_publish_tasks"("task_type", "status", "updated_at");
