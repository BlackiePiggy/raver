-- AlterTable
ALTER TABLE "quiz_config"
ADD COLUMN "debug_question_ids" TEXT[] DEFAULT ARRAY[]::TEXT[];
