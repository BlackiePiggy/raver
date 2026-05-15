ALTER TABLE "users"
  ADD COLUMN "region_code" TEXT NOT NULL DEFAULT 'JP',
  ADD COLUMN "birth_year" INTEGER,
  ADD COLUMN "age_band" TEXT NOT NULL DEFAULT 'unknown',
  ADD COLUMN "guardian_contact_email" TEXT,
  ADD COLUMN "age_declared_at" TIMESTAMP(3);

CREATE INDEX "users_region_code_idx" ON "users"("region_code");
CREATE INDEX "users_age_band_idx" ON "users"("age_band");
