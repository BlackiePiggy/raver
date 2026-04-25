CREATE TABLE IF NOT EXISTS "feed_events" (
  "id" TEXT NOT NULL,
  "user_id" TEXT,
  "session_id" TEXT NOT NULL,
  "event_type" TEXT NOT NULL,
  "post_id" TEXT,
  "feed_mode" TEXT,
  "position" INTEGER,
  "metadata" JSONB,
  "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "feed_events_pkey" PRIMARY KEY ("id")
);

CREATE INDEX IF NOT EXISTS "feed_events_user_id_created_at_idx" ON "feed_events"("user_id", "created_at");
CREATE INDEX IF NOT EXISTS "feed_events_post_id_created_at_idx" ON "feed_events"("post_id", "created_at");
CREATE INDEX IF NOT EXISTS "feed_events_event_type_created_at_idx" ON "feed_events"("event_type", "created_at");
CREATE INDEX IF NOT EXISTS "feed_events_session_id_created_at_idx" ON "feed_events"("session_id", "created_at");

ALTER TABLE "feed_events"
  ADD CONSTRAINT "feed_events_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;

ALTER TABLE "feed_events"
  ADD CONSTRAINT "feed_events_post_id_fkey" FOREIGN KEY ("post_id") REFERENCES "posts"("id") ON DELETE SET NULL ON UPDATE CASCADE;
