-- AlterTable
ALTER TABLE "djs" ADD COLUMN     "beatport_id" TEXT,
ADD COLUMN     "discogs_id" TEXT,
ADD COLUMN     "last_synced_at" TIMESTAMP(3),
ADD COLUMN     "ra_id" TEXT;

-- CreateTable
CREATE TABLE "dj_sets" (
    "id" TEXT NOT NULL,
    "dj_id" TEXT NOT NULL,
    "title" TEXT NOT NULL,
    "slug" TEXT NOT NULL,
    "description" TEXT,
    "thumbnail_url" TEXT,
    "video_url" TEXT NOT NULL,
    "platform" TEXT NOT NULL,
    "video_id" TEXT NOT NULL,
    "duration" INTEGER,
    "recorded_at" TIMESTAMP(3),
    "venue" TEXT,
    "event_name" TEXT,
    "view_count" INTEGER NOT NULL DEFAULT 0,
    "like_count" INTEGER NOT NULL DEFAULT 0,
    "is_verified" BOOLEAN NOT NULL DEFAULT false,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "dj_sets_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "tracks" (
    "id" TEXT NOT NULL,
    "set_id" TEXT NOT NULL,
    "position" INTEGER NOT NULL,
    "start_time" INTEGER NOT NULL,
    "end_time" INTEGER,
    "title" TEXT NOT NULL,
    "artist" TEXT NOT NULL,
    "status" TEXT NOT NULL DEFAULT 'released',
    "label" TEXT,
    "release_year" INTEGER,
    "spotify_url" TEXT,
    "apple_music_url" TEXT,
    "youtube_music_url" TEXT,
    "soundcloud_url" TEXT,
    "beatport_url" TEXT,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "tracks_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "dj_sets_slug_key" ON "dj_sets"("slug");

-- CreateIndex
CREATE INDEX "dj_sets_dj_id_idx" ON "dj_sets"("dj_id");

-- CreateIndex
CREATE INDEX "tracks_set_id_idx" ON "tracks"("set_id");

-- CreateIndex
CREATE INDEX "tracks_status_idx" ON "tracks"("status");

-- AddForeignKey
ALTER TABLE "dj_sets" ADD CONSTRAINT "dj_sets_dj_id_fkey" FOREIGN KEY ("dj_id") REFERENCES "djs"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "tracks" ADD CONSTRAINT "tracks_set_id_fkey" FOREIGN KEY ("set_id") REFERENCES "dj_sets"("id") ON DELETE CASCADE ON UPDATE CASCADE;
