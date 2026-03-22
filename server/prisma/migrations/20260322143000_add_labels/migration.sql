-- CreateTable
CREATE TABLE "labels" (
    "id" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "slug" TEXT NOT NULL,
    "profile_url" TEXT NOT NULL,
    "profile_slug" TEXT,
    "source_page" INTEGER,
    "source_listing_url" TEXT,
    "card_id" TEXT,
    "logo_url" TEXT,
    "avatar_source_url" TEXT,
    "background_source_url" TEXT,
    "avatar_url" TEXT,
    "background_url" TEXT,
    "soundcloud_followers" INTEGER,
    "likes" INTEGER,
    "nation" TEXT,
    "genres_preview" TEXT,
    "latest_release_listing" TEXT,
    "introduction_preview" TEXT,
    "location_period" TEXT,
    "introduction" TEXT,
    "genres" TEXT[] DEFAULT ARRAY[]::TEXT[],
    "contacts" JSONB,
    "links_in_web" JSONB,
    "general_contact_email" TEXT,
    "demo_submission_url" TEXT,
    "demo_submission_display" TEXT,
    "facebook_url" TEXT,
    "soundcloud_url" TEXT,
    "music_purchase_url" TEXT,
    "official_website_url" TEXT,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "labels_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "labels_slug_key" ON "labels"("slug");

-- CreateIndex
CREATE UNIQUE INDEX "labels_profile_url_key" ON "labels"("profile_url");

-- CreateIndex
CREATE INDEX "labels_name_idx" ON "labels"("name");

-- CreateIndex
CREATE INDEX "labels_nation_idx" ON "labels"("nation");

-- CreateIndex
CREATE INDEX "labels_soundcloud_followers_idx" ON "labels"("soundcloud_followers");

-- CreateIndex
CREATE INDEX "labels_likes_idx" ON "labels"("likes");
