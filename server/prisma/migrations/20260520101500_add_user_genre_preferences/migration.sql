CREATE TABLE "user_genre_preferences" (
  "id" TEXT NOT NULL,
  "user_id" TEXT NOT NULL,
  "genre_key" TEXT NOT NULL,
  "sort_order" INTEGER NOT NULL DEFAULT 0,
  "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

  CONSTRAINT "user_genre_preferences_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX "user_genre_preferences_user_id_genre_key_key"
  ON "user_genre_preferences"("user_id", "genre_key");

CREATE INDEX "user_genre_preferences_user_id_sort_order_idx"
  ON "user_genre_preferences"("user_id", "sort_order");

CREATE INDEX "user_genre_preferences_genre_key_created_at_idx"
  ON "user_genre_preferences"("genre_key", "created_at");

ALTER TABLE "user_genre_preferences"
  ADD CONSTRAINT "user_genre_preferences_user_id_fkey"
  FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
