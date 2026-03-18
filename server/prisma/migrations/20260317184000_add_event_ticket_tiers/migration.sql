CREATE TABLE "event_ticket_tiers" (
  "id" TEXT NOT NULL,
  "event_id" TEXT NOT NULL,
  "name" TEXT NOT NULL,
  "price" DECIMAL(10,2) NOT NULL,
  "currency" TEXT,
  "sort_order" INTEGER NOT NULL DEFAULT 0,
  "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" TIMESTAMP(3) NOT NULL,
  CONSTRAINT "event_ticket_tiers_pkey" PRIMARY KEY ("id")
);

CREATE INDEX "event_ticket_tiers_event_id_idx" ON "event_ticket_tiers"("event_id");
CREATE INDEX "event_ticket_tiers_sort_order_idx" ON "event_ticket_tiers"("sort_order");

ALTER TABLE "event_ticket_tiers"
ADD CONSTRAINT "event_ticket_tiers_event_id_fkey"
FOREIGN KEY ("event_id") REFERENCES "events"("id") ON DELETE CASCADE ON UPDATE CASCADE;
