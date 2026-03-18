ALTER TABLE "dj_sets"
ADD COLUMN "uploaded_by_id" TEXT;

CREATE INDEX "dj_sets_uploaded_by_id_idx" ON "dj_sets"("uploaded_by_id");

ALTER TABLE "dj_sets"
ADD CONSTRAINT "dj_sets_uploaded_by_id_fkey"
FOREIGN KEY ("uploaded_by_id") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;
