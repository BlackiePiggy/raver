-- AlterTable
ALTER TABLE "squads"
  ADD COLUMN "notice" TEXT,
  ADD COLUMN "qr_code_url" TEXT;

-- AlterTable
ALTER TABLE "squad_members"
  ADD COLUMN "nickname" TEXT,
  ADD COLUMN "notifications_enabled" BOOLEAN NOT NULL DEFAULT true;
