-- AlterTable
ALTER TABLE "squad_members" ADD COLUMN     "last_read_at" TIMESTAMP(3);

-- CreateTable
CREATE TABLE "direct_conversation_reads" (
    "id" TEXT NOT NULL,
    "conversation_id" TEXT NOT NULL,
    "user_id" TEXT NOT NULL,
    "last_read_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "direct_conversation_reads_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "direct_conversation_reads_conversation_id_idx" ON "direct_conversation_reads"("conversation_id");

-- CreateIndex
CREATE INDEX "direct_conversation_reads_user_id_idx" ON "direct_conversation_reads"("user_id");

-- CreateIndex
CREATE UNIQUE INDEX "direct_conversation_reads_conversation_id_user_id_key" ON "direct_conversation_reads"("conversation_id", "user_id");

-- AddForeignKey
ALTER TABLE "direct_conversation_reads" ADD CONSTRAINT "direct_conversation_reads_conversation_id_fkey" FOREIGN KEY ("conversation_id") REFERENCES "direct_conversations"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "direct_conversation_reads" ADD CONSTRAINT "direct_conversation_reads_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
