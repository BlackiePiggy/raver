-- CreateTable
CREATE TABLE "rating_events" (
    "id" TEXT NOT NULL,
    "created_by_id" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "description" TEXT,
    "image_url" TEXT,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "rating_events_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "rating_units" (
    "id" TEXT NOT NULL,
    "event_id" TEXT NOT NULL,
    "created_by_id" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "description" TEXT,
    "image_url" TEXT,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "rating_units_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "rating_comments" (
    "id" TEXT NOT NULL,
    "unit_id" TEXT NOT NULL,
    "user_id" TEXT NOT NULL,
    "score" INTEGER NOT NULL,
    "content" TEXT NOT NULL,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "rating_comments_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "rating_events_created_by_id_idx" ON "rating_events"("created_by_id");

-- CreateIndex
CREATE INDEX "rating_events_created_at_idx" ON "rating_events"("created_at");

-- CreateIndex
CREATE INDEX "rating_units_event_id_idx" ON "rating_units"("event_id");

-- CreateIndex
CREATE INDEX "rating_units_created_by_id_idx" ON "rating_units"("created_by_id");

-- CreateIndex
CREATE INDEX "rating_units_created_at_idx" ON "rating_units"("created_at");

-- CreateIndex
CREATE INDEX "rating_comments_unit_id_idx" ON "rating_comments"("unit_id");

-- CreateIndex
CREATE INDEX "rating_comments_user_id_idx" ON "rating_comments"("user_id");

-- CreateIndex
CREATE INDEX "rating_comments_created_at_idx" ON "rating_comments"("created_at");

-- AddForeignKey
ALTER TABLE "rating_events" ADD CONSTRAINT "rating_events_created_by_id_fkey" FOREIGN KEY ("created_by_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "rating_units" ADD CONSTRAINT "rating_units_event_id_fkey" FOREIGN KEY ("event_id") REFERENCES "rating_events"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "rating_units" ADD CONSTRAINT "rating_units_created_by_id_fkey" FOREIGN KEY ("created_by_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "rating_comments" ADD CONSTRAINT "rating_comments_unit_id_fkey" FOREIGN KEY ("unit_id") REFERENCES "rating_units"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "rating_comments" ADD CONSTRAINT "rating_comments_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
