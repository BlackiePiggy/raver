-- Core schema for the iOS quiz system mainline.
-- This migration introduces the question bank, global config,
-- user exam sessions, and the minimal per-day ledger needed for
-- attempt limiting and permanent pass state.

-- CreateEnum
CREATE TYPE "QuizQuestionStatus" AS ENUM ('draft', 'active', 'archived');

-- CreateEnum
CREATE TYPE "QuizQuestionType" AS ENUM ('single_choice');

-- CreateEnum
CREATE TYPE "QuizSessionStatus" AS ENUM ('in_progress', 'submitted', 'expired', 'abandoned');

-- CreateTable
CREATE TABLE "quiz_questions" (
    "id" TEXT NOT NULL,
    "status" "QuizQuestionStatus" NOT NULL DEFAULT 'draft',
    "type" "QuizQuestionType" NOT NULL DEFAULT 'single_choice',
    "stem_text" TEXT NOT NULL,
    "stem_image_url" TEXT,
    "correct_option_id" TEXT,
    "time_limit_sec" INTEGER,
    "sort_order" INTEGER NOT NULL DEFAULT 0,
    "tags" TEXT[] DEFAULT ARRAY[]::TEXT[],
    "difficulty" TEXT,
    "explanation" TEXT,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "quiz_questions_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "quiz_question_options" (
    "id" TEXT NOT NULL,
    "question_id" TEXT NOT NULL,
    "text" TEXT,
    "image_url" TEXT,
    "sort_order" INTEGER NOT NULL DEFAULT 0,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "quiz_question_options_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "quiz_config" (
    "id" TEXT NOT NULL DEFAULT 'default',
    "is_enabled" BOOLEAN NOT NULL DEFAULT false,
    "question_count" INTEGER NOT NULL DEFAULT 20,
    "pass_correct_count" INTEGER NOT NULL DEFAULT 16,
    "daily_attempt_limit" INTEGER NOT NULL DEFAULT 3,
    "default_time_limit_sec" INTEGER NOT NULL DEFAULT 20,
    "daily_limit_time_zone" TEXT NOT NULL DEFAULT 'Asia/Shanghai',
    "allow_retake_after_pass" BOOLEAN NOT NULL DEFAULT true,
    "allow_restart_during_session" BOOLEAN NOT NULL DEFAULT true,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "quiz_config_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "quiz_sessions" (
    "id" TEXT NOT NULL,
    "user_id" TEXT NOT NULL,
    "status" "QuizSessionStatus" NOT NULL DEFAULT 'in_progress',
    "config_snapshot" JSONB NOT NULL,
    "question_snapshot" JSONB NOT NULL,
    "current_question_index" INTEGER NOT NULL DEFAULT 0,
    "started_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "expires_at" TIMESTAMP(3),
    "submitted_at" TIMESTAMP(3),
    "correct_count" INTEGER,
    "passed" BOOLEAN,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "quiz_sessions_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "quiz_attempt_ledgers" (
    "id" TEXT NOT NULL,
    "user_id" TEXT NOT NULL,
    "attempt_date_key" TEXT NOT NULL,
    "attempt_count" INTEGER NOT NULL DEFAULT 0,
    "passed" BOOLEAN NOT NULL DEFAULT false,
    "passed_at" TIMESTAMP(3),
    "last_session_id" TEXT,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "quiz_attempt_ledgers_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "quiz_questions_status_sort_order_idx" ON "quiz_questions"("status", "sort_order");

-- CreateIndex
CREATE INDEX "quiz_questions_type_idx" ON "quiz_questions"("type");

-- CreateIndex
CREATE INDEX "quiz_questions_difficulty_idx" ON "quiz_questions"("difficulty");

-- CreateIndex
CREATE INDEX "quiz_question_options_question_id_idx" ON "quiz_question_options"("question_id");

-- CreateIndex
CREATE UNIQUE INDEX "quiz_question_options_question_id_sort_order_key" ON "quiz_question_options"("question_id", "sort_order");

-- CreateIndex
CREATE INDEX "quiz_sessions_user_id_status_idx" ON "quiz_sessions"("user_id", "status");

-- CreateIndex
CREATE INDEX "quiz_sessions_user_id_started_at_idx" ON "quiz_sessions"("user_id", "started_at");

-- CreateIndex
CREATE INDEX "quiz_sessions_status_started_at_idx" ON "quiz_sessions"("status", "started_at");

-- CreateIndex
CREATE INDEX "quiz_attempt_ledgers_attempt_date_key_idx" ON "quiz_attempt_ledgers"("attempt_date_key");

-- CreateIndex
CREATE INDEX "quiz_attempt_ledgers_user_id_passed_idx" ON "quiz_attempt_ledgers"("user_id", "passed");

-- CreateIndex
CREATE INDEX "quiz_attempt_ledgers_last_session_id_idx" ON "quiz_attempt_ledgers"("last_session_id");

-- CreateIndex
CREATE UNIQUE INDEX "quiz_attempt_ledgers_user_id_attempt_date_key_key" ON "quiz_attempt_ledgers"("user_id", "attempt_date_key");

-- AddForeignKey
ALTER TABLE "quiz_question_options" ADD CONSTRAINT "quiz_question_options_question_id_fkey" FOREIGN KEY ("question_id") REFERENCES "quiz_questions"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "quiz_sessions" ADD CONSTRAINT "quiz_sessions_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "quiz_attempt_ledgers" ADD CONSTRAINT "quiz_attempt_ledgers_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "quiz_attempt_ledgers" ADD CONSTRAINT "quiz_attempt_ledgers_last_session_id_fkey" FOREIGN KEY ("last_session_id") REFERENCES "quiz_sessions"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- Seed the singleton config row so server logic can read/write it directly.
INSERT INTO "quiz_config" (
  "id",
  "is_enabled",
  "question_count",
  "pass_correct_count",
  "daily_attempt_limit",
  "default_time_limit_sec",
  "daily_limit_time_zone",
  "allow_retake_after_pass",
  "allow_restart_during_session"
) VALUES (
  'default',
  false,
  20,
  16,
  3,
  20,
  'Asia/Shanghai',
  true,
  true
);
