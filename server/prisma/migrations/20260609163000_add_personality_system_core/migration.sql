-- Core schema for the EDM personality / EDMTI system.

CREATE TABLE "personality_config" (
    "id" TEXT NOT NULL,
    "is_enabled" BOOLEAN NOT NULL DEFAULT false,
    "question_count" INTEGER NOT NULL DEFAULT 16,
    "axis_threshold" INTEGER NOT NULL DEFAULT 9,
    "result_type_capacity" INTEGER NOT NULL DEFAULT 32,
    "standard_question_ids" TEXT[] NOT NULL DEFAULT ARRAY[]::TEXT[],
    "debug_question_ids" TEXT[] NOT NULL DEFAULT ARRAY[]::TEXT[],
    "easter_egg_question_id" TEXT,
    "hidden_result_priority" TEXT[] NOT NULL DEFAULT ARRAY['PHOENIX', 'CPDD', 'DRUNK', 'HHHH']::TEXT[],
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,
    CONSTRAINT "personality_config_pkey" PRIMARY KEY ("id")
);

CREATE TABLE "personality_questions" (
    "id" TEXT NOT NULL,
    "status" "QuizQuestionStatus" NOT NULL DEFAULT 'draft',
    "stem_text" TEXT NOT NULL,
    "stem_image_url" TEXT,
    "sort_order" INTEGER NOT NULL DEFAULT 0,
    "is_easter_egg" BOOLEAN NOT NULL DEFAULT false,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,
    CONSTRAINT "personality_questions_pkey" PRIMARY KEY ("id")
);

CREATE TABLE "personality_question_options" (
    "id" TEXT NOT NULL,
    "question_id" TEXT NOT NULL,
    "text" TEXT,
    "image_url" TEXT,
    "sort_order" INTEGER NOT NULL DEFAULT 0,
    "score_payload" JSONB,
    "direct_result_code" TEXT,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,
    CONSTRAINT "personality_question_options_pkey" PRIMARY KEY ("id")
);

CREATE TABLE "personality_result_types" (
    "id" TEXT NOT NULL,
    "code" TEXT NOT NULL,
    "title" TEXT NOT NULL,
    "subtitle" TEXT,
    "slang_tagline" TEXT,
    "genre_mapping" TEXT,
    "description" TEXT NOT NULL,
    "image_url" TEXT,
    "sort_order" INTEGER NOT NULL DEFAULT 0,
    "is_active" BOOLEAN NOT NULL DEFAULT true,
    "is_hidden" BOOLEAN NOT NULL DEFAULT false,
    "mbti_code" TEXT,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,
    CONSTRAINT "personality_result_types_pkey" PRIMARY KEY ("id")
);

CREATE TABLE "personality_sessions" (
    "id" TEXT NOT NULL,
    "user_id" TEXT NOT NULL,
    "mode" TEXT NOT NULL,
    "status" "QuizSessionStatus" NOT NULL DEFAULT 'in_progress',
    "config_snapshot" JSONB NOT NULL,
    "question_snapshot" JSONB NOT NULL,
    "answers_snapshot" JSONB,
    "current_question_index" INTEGER NOT NULL DEFAULT 0,
    "started_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "submitted_at" TIMESTAMP(3),
    "result_code" TEXT,
    "result_snapshot" JSONB,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,
    CONSTRAINT "personality_sessions_pkey" PRIMARY KEY ("id")
);

CREATE TABLE "personality_user_records" (
    "id" TEXT NOT NULL,
    "user_id" TEXT NOT NULL,
    "has_completed" BOOLEAN NOT NULL DEFAULT false,
    "completed_at" TIMESTAMP(3),
    "result_code" TEXT,
    "result_snapshot" JSONB,
    "last_session_id" TEXT,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,
    CONSTRAINT "personality_user_records_pkey" PRIMARY KEY ("id")
);

CREATE INDEX "personality_questions_status_sort_order_idx" ON "personality_questions"("status", "sort_order");
CREATE INDEX "personality_questions_is_easter_egg_idx" ON "personality_questions"("is_easter_egg");
CREATE INDEX "personality_question_options_question_id_idx" ON "personality_question_options"("question_id");
CREATE UNIQUE INDEX "personality_question_options_question_id_sort_order_key" ON "personality_question_options"("question_id", "sort_order");
CREATE INDEX "personality_question_options_direct_result_code_idx" ON "personality_question_options"("direct_result_code");
CREATE UNIQUE INDEX "personality_result_types_code_key" ON "personality_result_types"("code");
CREATE INDEX "personality_result_types_is_active_sort_order_idx" ON "personality_result_types"("is_active", "sort_order");
CREATE INDEX "personality_result_types_is_hidden_idx" ON "personality_result_types"("is_hidden");
CREATE INDEX "personality_sessions_user_id_status_idx" ON "personality_sessions"("user_id", "status");
CREATE INDEX "personality_sessions_user_id_started_at_idx" ON "personality_sessions"("user_id", "started_at");
CREATE INDEX "personality_sessions_mode_status_idx" ON "personality_sessions"("mode", "status");
CREATE UNIQUE INDEX "personality_user_records_user_id_key" ON "personality_user_records"("user_id");
CREATE INDEX "personality_user_records_has_completed_idx" ON "personality_user_records"("has_completed");
CREATE INDEX "personality_user_records_result_code_idx" ON "personality_user_records"("result_code");
CREATE INDEX "personality_user_records_last_session_id_idx" ON "personality_user_records"("last_session_id");

ALTER TABLE "personality_question_options"
ADD CONSTRAINT "personality_question_options_question_id_fkey"
FOREIGN KEY ("question_id") REFERENCES "personality_questions"("id") ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "personality_sessions"
ADD CONSTRAINT "personality_sessions_user_id_fkey"
FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "personality_user_records"
ADD CONSTRAINT "personality_user_records_user_id_fkey"
FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "personality_user_records"
ADD CONSTRAINT "personality_user_records_last_session_id_fkey"
FOREIGN KEY ("last_session_id") REFERENCES "personality_sessions"("id") ON DELETE SET NULL ON UPDATE CASCADE;

INSERT INTO "personality_config" (
    "id",
    "is_enabled",
    "question_count",
    "axis_threshold",
    "result_type_capacity",
    "standard_question_ids",
    "debug_question_ids",
    "hidden_result_priority",
    "created_at",
    "updated_at"
) VALUES (
    'default',
    false,
    16,
    9,
    32,
    ARRAY[]::TEXT[],
    ARRAY[]::TEXT[],
    ARRAY['PHOENIX', 'CPDD', 'DRUNK', 'HHHH']::TEXT[],
    CURRENT_TIMESTAMP,
    CURRENT_TIMESTAMP
);
