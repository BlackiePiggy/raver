CREATE TABLE "squad_offline_activities" (
    "id" TEXT NOT NULL,
    "squad_id" TEXT NOT NULL,
    "event_id" TEXT,
    "created_by_id" TEXT NOT NULL,
    "title" TEXT,
    "status" TEXT NOT NULL DEFAULT 'active',
    "started_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "ended_at" TIMESTAMP(3),
    "summary" JSONB,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "squad_offline_activities_pkey" PRIMARY KEY ("id")
);

CREATE TABLE "squad_offline_activity_participants" (
    "id" TEXT NOT NULL,
    "activity_id" TEXT NOT NULL,
    "user_id" TEXT NOT NULL,
    "joined_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "left_at" TIMESTAMP(3),
    "last_location_at" TIMESTAMP(3),

    CONSTRAINT "squad_offline_activity_participants_pkey" PRIMARY KEY ("id")
);

CREATE TABLE "squad_offline_activity_locations" (
    "id" TEXT NOT NULL,
    "activity_id" TEXT NOT NULL,
    "user_id" TEXT NOT NULL,
    "latitude" DECIMAL(10,8) NOT NULL,
    "longitude" DECIMAL(11,8) NOT NULL,
    "accuracy" DOUBLE PRECISION,
    "altitude" DOUBLE PRECISION,
    "speed" DOUBLE PRECISION,
    "heading" DOUBLE PRECISION,
    "captured_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "squad_offline_activity_locations_pkey" PRIMARY KEY ("id")
);

CREATE INDEX "squad_offline_activities_squad_id_status_idx" ON "squad_offline_activities"("squad_id", "status");
CREATE INDEX "squad_offline_activities_event_id_idx" ON "squad_offline_activities"("event_id");
CREATE INDEX "squad_offline_activities_started_at_idx" ON "squad_offline_activities"("started_at");

CREATE UNIQUE INDEX "squad_offline_activity_participants_activity_id_user_id_key" ON "squad_offline_activity_participants"("activity_id", "user_id");
CREATE INDEX "squad_offline_activity_participants_user_id_idx" ON "squad_offline_activity_participants"("user_id");
CREATE INDEX "squad_offline_activity_participants_activity_id_left_at_idx" ON "squad_offline_activity_participants"("activity_id", "left_at");

CREATE INDEX "squad_offline_activity_locations_activity_id_captured_at_idx" ON "squad_offline_activity_locations"("activity_id", "captured_at");
CREATE INDEX "squad_offline_activity_locations_activity_id_user_id_captured_at_idx" ON "squad_offline_activity_locations"("activity_id", "user_id", "captured_at");

ALTER TABLE "squad_offline_activities" ADD CONSTRAINT "squad_offline_activities_squad_id_fkey" FOREIGN KEY ("squad_id") REFERENCES "squads"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "squad_offline_activities" ADD CONSTRAINT "squad_offline_activities_event_id_fkey" FOREIGN KEY ("event_id") REFERENCES "events"("id") ON DELETE SET NULL ON UPDATE CASCADE;
ALTER TABLE "squad_offline_activities" ADD CONSTRAINT "squad_offline_activities_created_by_id_fkey" FOREIGN KEY ("created_by_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "squad_offline_activity_participants" ADD CONSTRAINT "squad_offline_activity_participants_activity_id_fkey" FOREIGN KEY ("activity_id") REFERENCES "squad_offline_activities"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "squad_offline_activity_participants" ADD CONSTRAINT "squad_offline_activity_participants_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "squad_offline_activity_locations" ADD CONSTRAINT "squad_offline_activity_locations_activity_id_fkey" FOREIGN KEY ("activity_id") REFERENCES "squad_offline_activities"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "squad_offline_activity_locations" ADD CONSTRAINT "squad_offline_activity_locations_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
