ALTER TABLE "checkins"
ADD COLUMN "attended_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP;

UPDATE "checkins"
SET "attended_at" = "created_at"
WHERE "attended_at" IS NULL;

CREATE INDEX "checkins_user_id_attended_at_idx" ON "checkins"("user_id", "attended_at");
