CREATE TABLE "dj_contributors" (
  "id" TEXT NOT NULL,
  "dj_id" TEXT NOT NULL,
  "user_id" TEXT NOT NULL,
  "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" TIMESTAMP(3) NOT NULL,

  CONSTRAINT "dj_contributors_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX "dj_contributors_dj_id_user_id_key" ON "dj_contributors"("dj_id", "user_id");
CREATE INDEX "dj_contributors_dj_id_idx" ON "dj_contributors"("dj_id");
CREATE INDEX "dj_contributors_user_id_idx" ON "dj_contributors"("user_id");

ALTER TABLE "dj_contributors"
ADD CONSTRAINT "dj_contributors_dj_id_fkey"
FOREIGN KEY ("dj_id") REFERENCES "djs"("id") ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "dj_contributors"
ADD CONSTRAINT "dj_contributors_user_id_fkey"
FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
