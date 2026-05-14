CREATE TABLE "event_favorites" (
    "id" TEXT NOT NULL,
    "user_id" TEXT NOT NULL,
    "event_id" TEXT NOT NULL,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "event_favorites_pkey" PRIMARY KEY ("id")
);

INSERT INTO "event_favorites" ("id", "user_id", "event_id", "created_at", "updated_at")
SELECT gen_random_uuid()::text, c."user_id", c."event_id", MIN(c."created_at"), MAX(c."updated_at")
FROM "checkins" c
WHERE c."type" = 'event'
  AND c."note" = 'marked'
  AND c."status" = 'active'
  AND c."event_id" IS NOT NULL
GROUP BY c."user_id", c."event_id"
ON CONFLICT DO NOTHING;

CREATE UNIQUE INDEX "event_favorites_user_id_event_id_key" ON "event_favorites"("user_id", "event_id");
CREATE INDEX "event_favorites_user_id_created_at_idx" ON "event_favorites"("user_id", "created_at");
CREATE INDEX "event_favorites_event_id_created_at_idx" ON "event_favorites"("event_id", "created_at");

ALTER TABLE "event_favorites" ADD CONSTRAINT "event_favorites_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "event_favorites" ADD CONSTRAINT "event_favorites_event_id_fkey" FOREIGN KEY ("event_id") REFERENCES "events"("id") ON DELETE CASCADE ON UPDATE CASCADE;
