CREATE TABLE "notification_admin_content_history" (
    "id" TEXT NOT NULL,
    "entity_type" TEXT NOT NULL,
    "entity_id" TEXT,
    "task_type" TEXT,
    "operation_type" TEXT NOT NULL,
    "result_status" TEXT NOT NULL,
    "push_status" TEXT NOT NULL,
    "title" TEXT NOT NULL,
    "summary" TEXT,
    "payload" JSONB NOT NULL,
    "decision" JSONB,
    "error_message" TEXT,
    "source_route" TEXT,
    "created_by" TEXT,
    "decided_by" TEXT,
    "decided_at" TIMESTAMP(3),
    "linked_task_id" TEXT,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "notification_admin_content_history_pkey" PRIMARY KEY ("id")
);

CREATE INDEX "notification_admin_content_history_entity_type_created_at_idx"
ON "notification_admin_content_history"("entity_type", "created_at");

CREATE INDEX "notification_admin_content_history_result_status_push_status__idx"
ON "notification_admin_content_history"("result_status", "push_status", "created_at");

CREATE INDEX "notification_admin_content_history_task_type_push_status_update_idx"
ON "notification_admin_content_history"("task_type", "push_status", "updated_at");

CREATE INDEX "notification_admin_content_history_linked_task_id_idx"
ON "notification_admin_content_history"("linked_task_id");
