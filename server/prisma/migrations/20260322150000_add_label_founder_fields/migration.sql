-- AlterTable
ALTER TABLE "labels"
ADD COLUMN "founder_name" TEXT,
ADD COLUMN "founded_at" TEXT,
ADD COLUMN "founder_dj_id" TEXT;

-- CreateIndex
CREATE INDEX "labels_founder_dj_id_idx" ON "labels"("founder_dj_id");

-- AddForeignKey
ALTER TABLE "labels"
ADD CONSTRAINT "labels_founder_dj_id_fkey"
FOREIGN KEY ("founder_dj_id") REFERENCES "djs"("id") ON DELETE SET NULL ON UPDATE CASCADE;
