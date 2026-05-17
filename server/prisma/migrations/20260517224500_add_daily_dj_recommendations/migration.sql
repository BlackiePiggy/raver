CREATE TABLE "user_daily_dj_recommendations" (
    "id" TEXT NOT NULL,
    "user_id" TEXT NOT NULL,
    "recommendation_date" DATE NOT NULL,
    "dj_ids" TEXT[] NOT NULL DEFAULT ARRAY[]::TEXT[],
    "algorithm_version" TEXT NOT NULL,
    "candidate_source" TEXT NOT NULL,
    "candidate_limit" INTEGER NOT NULL DEFAULT 500,
    "generated_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "user_daily_dj_recommendations_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX "user_daily_dj_recommendations_user_id_recommendation_date_key" ON "user_daily_dj_recommendations"("user_id", "recommendation_date");
CREATE INDEX "user_daily_dj_recommendations_recommendation_date_generated_at_idx" ON "user_daily_dj_recommendations"("recommendation_date", "generated_at");

ALTER TABLE "user_daily_dj_recommendations" ADD CONSTRAINT "user_daily_dj_recommendations_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
