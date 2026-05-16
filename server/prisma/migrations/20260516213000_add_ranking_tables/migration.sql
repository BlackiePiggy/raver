CREATE TABLE "ranking_boards" (
    "id" TEXT NOT NULL,
    "title" TEXT NOT NULL,
    "subtitle" TEXT NOT NULL DEFAULT '',
    "description" TEXT NOT NULL DEFAULT '',
    "cover_image_url" TEXT,
    "entity_type" TEXT NOT NULL DEFAULT 'dj',
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "ranking_boards_pkey" PRIMARY KEY ("id")
);

CREATE TABLE "ranking_years" (
    "id" TEXT NOT NULL,
    "board_id" TEXT NOT NULL,
    "year" INTEGER NOT NULL,
    "source" TEXT,
    "updated_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "ranking_years_pkey" PRIMARY KEY ("id")
);

CREATE TABLE "ranking_entries" (
    "id" TEXT NOT NULL,
    "ranking_year_id" TEXT NOT NULL,
    "rank" INTEGER NOT NULL,
    "name" TEXT NOT NULL,
    "entity_id" TEXT,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "ranking_entries_pkey" PRIMARY KEY ("id")
);

CREATE INDEX "ranking_boards_entity_type_idx" ON "ranking_boards"("entity_type");
CREATE UNIQUE INDEX "ranking_years_board_id_year_key" ON "ranking_years"("board_id", "year");
CREATE INDEX "ranking_years_year_idx" ON "ranking_years"("year");
CREATE UNIQUE INDEX "ranking_entries_ranking_year_id_rank_key" ON "ranking_entries"("ranking_year_id", "rank");
CREATE INDEX "ranking_entries_entity_id_idx" ON "ranking_entries"("entity_id");
CREATE INDEX "ranking_entries_name_idx" ON "ranking_entries"("name");

ALTER TABLE "ranking_years" ADD CONSTRAINT "ranking_years_board_id_fkey"
FOREIGN KEY ("board_id") REFERENCES "ranking_boards"("id") ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "ranking_entries" ADD CONSTRAINT "ranking_entries_ranking_year_id_fkey"
FOREIGN KEY ("ranking_year_id") REFERENCES "ranking_years"("id") ON DELETE CASCADE ON UPDATE CASCADE;
