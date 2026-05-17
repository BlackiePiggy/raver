CREATE TABLE "news_articles" (
    "id" TEXT NOT NULL,
    "author_id" TEXT,
    "category" TEXT NOT NULL DEFAULT 'community',
    "source" TEXT NOT NULL DEFAULT 'Raver',
    "title" TEXT NOT NULL,
    "summary" TEXT NOT NULL DEFAULT '',
    "body" TEXT NOT NULL DEFAULT '',
    "link" TEXT,
    "cover_image_url" TEXT,
    "visibility" TEXT NOT NULL DEFAULT 'public',
    "bound_dj_ids" TEXT[] NOT NULL DEFAULT ARRAY[]::TEXT[],
    "bound_brand_ids" TEXT[] NOT NULL DEFAULT ARRAY[]::TEXT[],
    "bound_event_ids" TEXT[] NOT NULL DEFAULT ARRAY[]::TEXT[],
    "comment_count" INTEGER NOT NULL DEFAULT 0,
    "published_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "news_articles_pkey" PRIMARY KEY ("id")
);

CREATE INDEX "news_articles_author_id_published_at_idx" ON "news_articles"("author_id", "published_at");
CREATE INDEX "news_articles_visibility_published_at_idx" ON "news_articles"("visibility", "published_at");
CREATE INDEX "news_articles_published_at_idx" ON "news_articles"("published_at");
CREATE INDEX "news_articles_bound_dj_ids_idx" ON "news_articles" USING GIN ("bound_dj_ids");
CREATE INDEX "news_articles_bound_brand_ids_idx" ON "news_articles" USING GIN ("bound_brand_ids");
CREATE INDEX "news_articles_bound_event_ids_idx" ON "news_articles" USING GIN ("bound_event_ids");

ALTER TABLE "news_articles" ADD CONSTRAINT "news_articles_author_id_fkey"
FOREIGN KEY ("author_id") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;

CREATE TABLE "news_comments" (
    "id" TEXT NOT NULL,
    "article_id" TEXT NOT NULL,
    "user_id" TEXT NOT NULL,
    "parent_comment_id" TEXT,
    "root_comment_id" TEXT,
    "reply_to_user_id" TEXT,
    "depth" INTEGER NOT NULL DEFAULT 0,
    "content" TEXT NOT NULL,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "news_comments_pkey" PRIMARY KEY ("id")
);

CREATE INDEX "news_comments_article_id_idx" ON "news_comments"("article_id");
CREATE INDEX "news_comments_user_id_idx" ON "news_comments"("user_id");
CREATE INDEX "news_comments_parent_comment_id_idx" ON "news_comments"("parent_comment_id");
CREATE INDEX "news_comments_root_comment_id_idx" ON "news_comments"("root_comment_id");
CREATE INDEX "news_comments_reply_to_user_id_idx" ON "news_comments"("reply_to_user_id");
CREATE INDEX "news_comments_article_id_created_at_idx" ON "news_comments"("article_id", "created_at");

ALTER TABLE "news_comments" ADD CONSTRAINT "news_comments_article_id_fkey"
FOREIGN KEY ("article_id") REFERENCES "news_articles"("id") ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "news_comments" ADD CONSTRAINT "news_comments_user_id_fkey"
FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "news_comments" ADD CONSTRAINT "news_comments_parent_comment_id_fkey"
FOREIGN KEY ("parent_comment_id") REFERENCES "news_comments"("id") ON DELETE SET NULL ON UPDATE CASCADE;

ALTER TABLE "news_comments" ADD CONSTRAINT "news_comments_root_comment_id_fkey"
FOREIGN KEY ("root_comment_id") REFERENCES "news_comments"("id") ON DELETE SET NULL ON UPDATE CASCADE;

ALTER TABLE "news_comments" ADD CONSTRAINT "news_comments_reply_to_user_id_fkey"
FOREIGN KEY ("reply_to_user_id") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;
