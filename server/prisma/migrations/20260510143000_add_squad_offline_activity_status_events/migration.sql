CREATE TABLE "squad_offline_activity_status_events" (
    "id" TEXT NOT NULL,
    "activity_id" TEXT NOT NULL,
    "user_id" TEXT NOT NULL,
    "status_type" TEXT NOT NULL,
    "is_active" BOOLEAN NOT NULL,
    "captured_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "squad_offline_activity_status_events_pkey" PRIMARY KEY ("id")
);

CREATE INDEX "squad_offline_activity_status_events_activity_id_user_id_captured_at_idx" ON "squad_offline_activity_status_events"("activity_id", "user_id", "captured_at");
CREATE INDEX "squad_offline_activity_status_events_activity_id_status_type_is_active_idx" ON "squad_offline_activity_status_events"("activity_id", "status_type", "is_active");

ALTER TABLE "squad_offline_activity_status_events" ADD CONSTRAINT "squad_offline_activity_status_events_activity_id_fkey" FOREIGN KEY ("activity_id") REFERENCES "squad_offline_activities"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "squad_offline_activity_status_events" ADD CONSTRAINT "squad_offline_activity_status_events_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
