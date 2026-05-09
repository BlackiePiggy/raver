CREATE TABLE "event_live_comments" (
  "id" TEXT NOT NULL,
  "event_id" TEXT NOT NULL,
  "user_id" TEXT NOT NULL,
  "content" TEXT NOT NULL,
  "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" TIMESTAMP(3) NOT NULL,
  CONSTRAINT "event_live_comments_pkey" PRIMARY KEY ("id")
);

CREATE INDEX "event_live_comments_event_id_created_at_idx" ON "event_live_comments"("event_id", "created_at");
CREATE INDEX "event_live_comments_user_id_created_at_idx" ON "event_live_comments"("user_id", "created_at");

ALTER TABLE "event_live_comments" ADD CONSTRAINT "event_live_comments_event_id_fkey" FOREIGN KEY ("event_id") REFERENCES "events"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "event_live_comments" ADD CONSTRAINT "event_live_comments_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
