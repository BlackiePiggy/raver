ALTER TABLE "events"
ADD COLUMN "abbreviation" TEXT;

CREATE INDEX "events_abbreviation_idx" ON "events"("abbreviation");
