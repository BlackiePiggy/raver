ALTER TABLE "users"
ADD COLUMN "favorite_dj_ids" TEXT[] DEFAULT ARRAY[]::TEXT[],
ADD COLUMN "favorite_genres" TEXT[] DEFAULT ARRAY[]::TEXT[];
