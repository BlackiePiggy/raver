ALTER TABLE "squad_offline_activity_participants"
ADD COLUMN "is_in_restroom" BOOLEAN NOT NULL DEFAULT false,
ADD COLUMN "is_buying_drink" BOOLEAN NOT NULL DEFAULT false;
