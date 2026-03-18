ALTER TABLE "events"
ADD COLUMN "organizer_id" TEXT,
ADD COLUMN "lineup_image_url" TEXT,
ADD COLUMN "event_type" TEXT,
ADD COLUMN "organizer_name" TEXT,
ADD COLUMN "ticket_price_min" DECIMAL(10,2),
ADD COLUMN "ticket_price_max" DECIMAL(10,2),
ADD COLUMN "ticket_currency" TEXT,
ADD COLUMN "ticket_notes" TEXT;

CREATE INDEX "events_organizer_id_idx" ON "events"("organizer_id");

ALTER TABLE "events"
ADD CONSTRAINT "events_organizer_id_fkey"
FOREIGN KEY ("organizer_id") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;

CREATE TABLE "event_lineup_slots" (
    "id" TEXT NOT NULL,
    "event_id" TEXT NOT NULL,
    "dj_id" TEXT,
    "dj_name" TEXT NOT NULL,
    "stage_name" TEXT,
    "sort_order" INTEGER NOT NULL DEFAULT 0,
    "start_time" TIMESTAMP(3) NOT NULL,
    "end_time" TIMESTAMP(3) NOT NULL,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "event_lineup_slots_pkey" PRIMARY KEY ("id")
);

CREATE INDEX "event_lineup_slots_event_id_idx" ON "event_lineup_slots"("event_id");
CREATE INDEX "event_lineup_slots_dj_id_idx" ON "event_lineup_slots"("dj_id");
CREATE INDEX "event_lineup_slots_start_time_idx" ON "event_lineup_slots"("start_time");

ALTER TABLE "event_lineup_slots"
ADD CONSTRAINT "event_lineup_slots_event_id_fkey"
FOREIGN KEY ("event_id") REFERENCES "events"("id") ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "event_lineup_slots"
ADD CONSTRAINT "event_lineup_slots_dj_id_fkey"
FOREIGN KEY ("dj_id") REFERENCES "djs"("id") ON DELETE SET NULL ON UPDATE CASCADE;
