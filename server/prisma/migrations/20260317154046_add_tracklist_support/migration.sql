-- CreateTable
CREATE TABLE "tracklists" (
    "id" TEXT NOT NULL,
    "set_id" TEXT NOT NULL,
    "uploaded_by_id" TEXT NOT NULL,
    "title" TEXT,
    "is_default" BOOLEAN NOT NULL DEFAULT false,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "tracklists_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "tracklist_tracks" (
    "id" TEXT NOT NULL,
    "tracklist_id" TEXT NOT NULL,
    "position" INTEGER NOT NULL,
    "start_time" INTEGER NOT NULL,
    "end_time" INTEGER,
    "title" TEXT NOT NULL,
    "artist" TEXT NOT NULL,
    "status" TEXT NOT NULL DEFAULT 'released',
    "label" TEXT,
    "release_year" INTEGER,
    "spotify_url" TEXT,
    "spotify_id" TEXT,
    "spotify_uri" TEXT,
    "apple_music_url" TEXT,
    "youtube_music_url" TEXT,
    "soundcloud_url" TEXT,
    "beatport_url" TEXT,
    "netease_url" TEXT,
    "netease_id" TEXT,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "tracklist_tracks_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "tracklists_set_id_idx" ON "tracklists"("set_id");

-- CreateIndex
CREATE INDEX "tracklists_uploaded_by_id_idx" ON "tracklists"("uploaded_by_id");

-- CreateIndex
CREATE INDEX "tracklist_tracks_tracklist_id_idx" ON "tracklist_tracks"("tracklist_id");

-- CreateIndex
CREATE INDEX "tracklist_tracks_status_idx" ON "tracklist_tracks"("status");

-- AddForeignKey
ALTER TABLE "tracklists" ADD CONSTRAINT "tracklists_set_id_fkey" FOREIGN KEY ("set_id") REFERENCES "dj_sets"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "tracklists" ADD CONSTRAINT "tracklists_uploaded_by_id_fkey" FOREIGN KEY ("uploaded_by_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "tracklist_tracks" ADD CONSTRAINT "tracklist_tracks_tracklist_id_fkey" FOREIGN KEY ("tracklist_id") REFERENCES "tracklists"("id") ON DELETE CASCADE ON UPDATE CASCADE;
