ALTER TABLE "dj_sets"
  ALTER COLUMN "dj_id" DROP NOT NULL;

ALTER TABLE "dj_sets"
  DROP CONSTRAINT IF EXISTS "dj_sets_dj_id_fkey";

ALTER TABLE "dj_sets"
  ADD CONSTRAINT "dj_sets_dj_id_fkey"
  FOREIGN KEY ("dj_id") REFERENCES "djs"("id")
  ON DELETE SET NULL
  ON UPDATE CASCADE;
