-- AlterTable
ALTER TABLE "users"
  ADD COLUMN "is_followers_list_public" BOOLEAN NOT NULL DEFAULT true,
  ADD COLUMN "is_following_list_public" BOOLEAN NOT NULL DEFAULT true;

-- AlterTable
ALTER TABLE "posts"
  ADD COLUMN "repost_count" INTEGER NOT NULL DEFAULT 0;

-- CreateTable
CREATE TABLE "post_reposts" (
  "id" TEXT NOT NULL,
  "post_id" TEXT NOT NULL,
  "user_id" TEXT NOT NULL,
  "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

  CONSTRAINT "post_reposts_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "post_reposts_post_id_user_id_key" ON "post_reposts"("post_id", "user_id");

-- CreateIndex
CREATE INDEX "post_reposts_post_id_idx" ON "post_reposts"("post_id");

-- CreateIndex
CREATE INDEX "post_reposts_user_id_idx" ON "post_reposts"("user_id");

-- CreateIndex
CREATE INDEX "post_reposts_created_at_idx" ON "post_reposts"("created_at");

-- AddForeignKey
ALTER TABLE "post_reposts"
  ADD CONSTRAINT "post_reposts_post_id_fkey" FOREIGN KEY ("post_id") REFERENCES "posts"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "post_reposts"
  ADD CONSTRAINT "post_reposts_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
