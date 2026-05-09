ALTER TABLE "event_live_comments"
ADD COLUMN "parent_comment_id" TEXT,
ADD COLUMN "root_comment_id" TEXT,
ADD COLUMN "reply_to_user_id" TEXT,
ADD COLUMN "depth" INTEGER NOT NULL DEFAULT 0,
ADD COLUMN "image_urls" TEXT[] NOT NULL DEFAULT ARRAY[]::TEXT[],
ADD COLUMN "like_count" INTEGER NOT NULL DEFAULT 0;

CREATE TABLE "event_live_comment_likes" (
  "id" TEXT NOT NULL,
  "comment_id" TEXT NOT NULL,
  "user_id" TEXT NOT NULL,
  "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "event_live_comment_likes_pkey" PRIMARY KEY ("id")
);

CREATE INDEX "event_live_comments_event_id_like_count_created_at_idx" ON "event_live_comments"("event_id", "like_count", "created_at");
CREATE INDEX "event_live_comments_parent_comment_id_idx" ON "event_live_comments"("parent_comment_id");
CREATE INDEX "event_live_comments_root_comment_id_idx" ON "event_live_comments"("root_comment_id");
CREATE INDEX "event_live_comments_reply_to_user_id_idx" ON "event_live_comments"("reply_to_user_id");

CREATE UNIQUE INDEX "event_live_comment_likes_comment_id_user_id_key" ON "event_live_comment_likes"("comment_id", "user_id");
CREATE INDEX "event_live_comment_likes_comment_id_idx" ON "event_live_comment_likes"("comment_id");
CREATE INDEX "event_live_comment_likes_user_id_idx" ON "event_live_comment_likes"("user_id");

ALTER TABLE "event_live_comments" ADD CONSTRAINT "event_live_comments_parent_comment_id_fkey" FOREIGN KEY ("parent_comment_id") REFERENCES "event_live_comments"("id") ON DELETE SET NULL ON UPDATE CASCADE;
ALTER TABLE "event_live_comments" ADD CONSTRAINT "event_live_comments_root_comment_id_fkey" FOREIGN KEY ("root_comment_id") REFERENCES "event_live_comments"("id") ON DELETE SET NULL ON UPDATE CASCADE;
ALTER TABLE "event_live_comments" ADD CONSTRAINT "event_live_comments_reply_to_user_id_fkey" FOREIGN KEY ("reply_to_user_id") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;
ALTER TABLE "event_live_comment_likes" ADD CONSTRAINT "event_live_comment_likes_comment_id_fkey" FOREIGN KEY ("comment_id") REFERENCES "event_live_comments"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "event_live_comment_likes" ADD CONSTRAINT "event_live_comment_likes_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
