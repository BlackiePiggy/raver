ALTER TABLE "posts"
  ADD COLUMN IF NOT EXISTS "save_count" INTEGER NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS "share_count" INTEGER NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS "hide_count" INTEGER NOT NULL DEFAULT 0;

CREATE TABLE IF NOT EXISTS "post_saves" (
  "id" TEXT NOT NULL,
  "post_id" TEXT NOT NULL,
  "user_id" TEXT NOT NULL,
  "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "post_saves_pkey" PRIMARY KEY ("id")
);

CREATE TABLE IF NOT EXISTS "post_shares" (
  "id" TEXT NOT NULL,
  "post_id" TEXT NOT NULL,
  "user_id" TEXT,
  "channel" TEXT,
  "status" TEXT NOT NULL DEFAULT 'completed',
  "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "post_shares_pkey" PRIMARY KEY ("id")
);

CREATE TABLE IF NOT EXISTS "post_hides" (
  "id" TEXT NOT NULL,
  "post_id" TEXT NOT NULL,
  "user_id" TEXT NOT NULL,
  "reason" TEXT,
  "note" TEXT,
  "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "post_hides_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX IF NOT EXISTS "post_saves_post_id_user_id_key" ON "post_saves"("post_id", "user_id");
CREATE INDEX IF NOT EXISTS "post_saves_post_id_idx" ON "post_saves"("post_id");
CREATE INDEX IF NOT EXISTS "post_saves_user_id_idx" ON "post_saves"("user_id");
CREATE INDEX IF NOT EXISTS "post_saves_created_at_idx" ON "post_saves"("created_at");

CREATE INDEX IF NOT EXISTS "post_shares_post_id_idx" ON "post_shares"("post_id");
CREATE INDEX IF NOT EXISTS "post_shares_user_id_idx" ON "post_shares"("user_id");
CREATE INDEX IF NOT EXISTS "post_shares_created_at_idx" ON "post_shares"("created_at");

CREATE UNIQUE INDEX IF NOT EXISTS "post_hides_post_id_user_id_key" ON "post_hides"("post_id", "user_id");
CREATE INDEX IF NOT EXISTS "post_hides_post_id_idx" ON "post_hides"("post_id");
CREATE INDEX IF NOT EXISTS "post_hides_user_id_idx" ON "post_hides"("user_id");
CREATE INDEX IF NOT EXISTS "post_hides_reason_idx" ON "post_hides"("reason");
CREATE INDEX IF NOT EXISTS "post_hides_created_at_idx" ON "post_hides"("created_at");

ALTER TABLE "post_saves"
  ADD CONSTRAINT "post_saves_post_id_fkey" FOREIGN KEY ("post_id") REFERENCES "posts"("id") ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "post_saves"
  ADD CONSTRAINT "post_saves_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "post_shares"
  ADD CONSTRAINT "post_shares_post_id_fkey" FOREIGN KEY ("post_id") REFERENCES "posts"("id") ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "post_shares"
  ADD CONSTRAINT "post_shares_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;

ALTER TABLE "post_hides"
  ADD CONSTRAINT "post_hides_post_id_fkey" FOREIGN KEY ("post_id") REFERENCES "posts"("id") ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "post_hides"
  ADD CONSTRAINT "post_hides_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
