-- Add threading fields to post comments for "main comment + second-level replies"
ALTER TABLE "post_comments"
  ADD COLUMN IF NOT EXISTS "parent_comment_id" TEXT,
  ADD COLUMN IF NOT EXISTS "root_comment_id" TEXT,
  ADD COLUMN IF NOT EXISTS "reply_to_user_id" TEXT,
  ADD COLUMN IF NOT EXISTS "depth" INTEGER NOT NULL DEFAULT 0;

-- FK constraints (idempotent-safe via DO blocks)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'post_comments_parent_comment_id_fkey'
  ) THEN
    ALTER TABLE "post_comments"
      ADD CONSTRAINT "post_comments_parent_comment_id_fkey"
      FOREIGN KEY ("parent_comment_id") REFERENCES "post_comments"("id")
      ON DELETE SET NULL ON UPDATE CASCADE;
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'post_comments_root_comment_id_fkey'
  ) THEN
    ALTER TABLE "post_comments"
      ADD CONSTRAINT "post_comments_root_comment_id_fkey"
      FOREIGN KEY ("root_comment_id") REFERENCES "post_comments"("id")
      ON DELETE SET NULL ON UPDATE CASCADE;
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'post_comments_reply_to_user_id_fkey'
  ) THEN
    ALTER TABLE "post_comments"
      ADD CONSTRAINT "post_comments_reply_to_user_id_fkey"
      FOREIGN KEY ("reply_to_user_id") REFERENCES "users"("id")
      ON DELETE SET NULL ON UPDATE CASCADE;
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS "post_comments_parent_comment_id_idx" ON "post_comments"("parent_comment_id");
CREATE INDEX IF NOT EXISTS "post_comments_root_comment_id_idx" ON "post_comments"("root_comment_id");
CREATE INDEX IF NOT EXISTS "post_comments_reply_to_user_id_idx" ON "post_comments"("reply_to_user_id");
CREATE INDEX IF NOT EXISTS "post_comments_post_id_created_at_idx" ON "post_comments"("post_id", "created_at");

