CREATE EXTENSION IF NOT EXISTS pg_trgm;

CREATE INDEX IF NOT EXISTS idx_djs_name_trgm
  ON "djs" USING GIN ("name" gin_trgm_ops);

CREATE INDEX IF NOT EXISTS idx_djs_bio_trgm
  ON "djs" USING GIN ("bio" gin_trgm_ops);

CREATE INDEX IF NOT EXISTS idx_djs_aliases_gin
  ON "djs" USING GIN ("aliases");
