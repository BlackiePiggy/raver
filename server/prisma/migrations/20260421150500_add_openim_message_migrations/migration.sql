CREATE TABLE "openim_message_migrations" (
    "id" TEXT NOT NULL,
    "source_type" TEXT NOT NULL,
    "source_id" TEXT NOT NULL,
    "target_message_id" TEXT,
    "conversation_key" TEXT NOT NULL,
    "status" TEXT NOT NULL DEFAULT 'pending',
    "error" TEXT,
    "migrated_at" TIMESTAMP(3),
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "openim_message_migrations_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX "openim_message_migrations_source_type_source_id_key"
ON "openim_message_migrations"("source_type", "source_id");

CREATE INDEX "openim_message_migrations_status_created_at_idx"
ON "openim_message_migrations"("status", "created_at");

CREATE INDEX "openim_message_migrations_conversation_key_idx"
ON "openim_message_migrations"("conversation_key");
