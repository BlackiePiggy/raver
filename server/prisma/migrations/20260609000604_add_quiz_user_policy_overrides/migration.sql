-- Allow admin to override quiz attempt policy for specific users.
-- This supports default/global limit, a custom per-user daily limit,
-- and an unlimited mode for official testing and permission validation.

-- CreateEnum
CREATE TYPE "QuizAttemptMode" AS ENUM ('default', 'custom_limit', 'unlimited');

-- CreateTable
CREATE TABLE "quiz_user_policy_overrides" (
    "id" TEXT NOT NULL,
    "user_id" TEXT NOT NULL,
    "attempt_mode" "QuizAttemptMode" NOT NULL DEFAULT 'default',
    "daily_attempt_limit_override" INTEGER,
    "note" TEXT,
    "updated_by" TEXT,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "quiz_user_policy_overrides_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "quiz_user_policy_overrides_user_id_key" ON "quiz_user_policy_overrides"("user_id");

-- CreateIndex
CREATE INDEX "quiz_user_policy_overrides_attempt_mode_idx" ON "quiz_user_policy_overrides"("attempt_mode");

-- CreateIndex
CREATE INDEX "quiz_user_policy_overrides_updated_by_idx" ON "quiz_user_policy_overrides"("updated_by");

-- AddForeignKey
ALTER TABLE "quiz_user_policy_overrides" ADD CONSTRAINT "quiz_user_policy_overrides_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
