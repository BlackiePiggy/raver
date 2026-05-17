CREATE OR REPLACE FUNCTION try_decode_raver_base64_utf8(input text)
RETURNS text AS $$
BEGIN
  IF input IS NULL OR btrim(input) = '' THEN
    RETURN NULL;
  END IF;
  RETURN NULLIF(btrim(convert_from(decode(btrim(input), 'base64'), 'UTF8')), '');
EXCEPTION WHEN others THEN
  RETURN NULL;
END;
$$ LANGUAGE plpgsql;

WITH legacy_news AS (
  SELECT
    p.*,
    NULLIF(substring(p.content from '(?:标题|title)[：:]\s*([^\r\n]+)'), '') AS parsed_title,
    NULLIF(substring(p.content from '(?:摘要|summary)[：:]\s*([^\r\n]+)'), '') AS parsed_summary,
    NULLIF(substring(p.content from '(?:分类|category)[：:]\s*([^\r\n]+)'), '') AS parsed_category,
    NULLIF(substring(p.content from '(?:来源|source)[：:]\s*([^\r\n]+)'), '') AS parsed_source,
    NULLIF(substring(p.content from '(?:链接|link|url)[：:]\s*([^\r\n]+)'), '') AS parsed_link,
    try_decode_raver_base64_utf8(substring(p.content from '(?:正文MD64|content_md64|body_md64)[：:]\s*([^\r\n]+)')) AS parsed_body
  FROM "posts" p
  WHERE p."content" LIKE '%#RAVER_NEWS%'
)
INSERT INTO "news_articles" (
  "id",
  "author_id",
  "category",
  "source",
  "title",
  "summary",
  "body",
  "link",
  "cover_image_url",
  "visibility",
  "bound_dj_ids",
  "bound_brand_ids",
  "bound_event_ids",
  "comment_count",
  "published_at",
  "created_at",
  "updated_at"
)
SELECT
  n."id",
  n."user_id",
  CASE
    WHEN lower(COALESCE(n.parsed_category, '')) LIKE '%festival%' OR COALESCE(n.parsed_category, '') LIKE '%电音%' OR COALESCE(n.parsed_category, '') LIKE '%活动%' THEN 'festival'
    WHEN lower(COALESCE(n.parsed_category, '')) LIKE '%scene%' OR COALESCE(n.parsed_category, '') LIKE '%现场%' OR COALESCE(n.parsed_category, '') LIKE '%演出%' THEN 'scene'
    WHEN lower(COALESCE(n.parsed_category, '')) LIKE '%gear%' OR COALESCE(n.parsed_category, '') LIKE '%设备%' OR COALESCE(n.parsed_category, '') LIKE '%插件%' THEN 'gear'
    WHEN lower(COALESCE(n.parsed_category, '')) LIKE '%industry%' OR COALESCE(n.parsed_category, '') LIKE '%行业%' OR COALESCE(n.parsed_category, '') LIKE '%厂牌%' THEN 'industry'
    ELSE 'community'
  END,
  COALESCE(n.parsed_source, 'Raver'),
  COALESCE(NULLIF(n."title_i18n"->>'zh', ''), NULLIF(n."title_i18n"->>'en', ''), n.parsed_title, '未命名资讯'),
  COALESCE(NULLIF(n."summary_i18n"->>'zh', ''), NULLIF(n."summary_i18n"->>'en', ''), n.parsed_summary, ''),
  COALESCE(NULLIF(n."body_i18n"->>'zh', ''), NULLIF(n."body_i18n"->>'en', ''), n.parsed_body, n."content"),
  n.parsed_link,
  n."images"[1],
  n."visibility",
  n."bound_dj_ids",
  n."bound_brand_ids",
  n."bound_event_ids",
  0,
  COALESCE(n."display_published_at", n."created_at"),
  n."created_at",
  n."updated_at"
FROM legacy_news n
ON CONFLICT ("id") DO NOTHING;

INSERT INTO "news_comments" (
  "id",
  "article_id",
  "user_id",
  "parent_comment_id",
  "root_comment_id",
  "reply_to_user_id",
  "depth",
  "content",
  "created_at",
  "updated_at"
)
SELECT
  pc."id",
  pc."post_id",
  pc."user_id",
  NULL,
  NULL,
  pc."reply_to_user_id",
  pc."depth",
  pc."content",
  pc."created_at",
  pc."updated_at"
FROM "post_comments" pc
JOIN "posts" p ON p."id" = pc."post_id"
WHERE p."content" LIKE '%#RAVER_NEWS%'
ON CONFLICT ("id") DO NOTHING;

UPDATE "news_comments" nc
SET "parent_comment_id" = pc."parent_comment_id"
FROM "post_comments" pc
WHERE nc."id" = pc."id"
  AND pc."parent_comment_id" IS NOT NULL
  AND EXISTS (SELECT 1 FROM "news_comments" parent WHERE parent."id" = pc."parent_comment_id");

UPDATE "news_comments" nc
SET "root_comment_id" = pc."root_comment_id"
FROM "post_comments" pc
WHERE nc."id" = pc."id"
  AND pc."root_comment_id" IS NOT NULL
  AND EXISTS (SELECT 1 FROM "news_comments" root WHERE root."id" = pc."root_comment_id");

UPDATE "news_articles" article
SET "comment_count" = counts.comment_count
FROM (
  SELECT "article_id", COUNT(*)::integer AS comment_count
  FROM "news_comments"
  GROUP BY "article_id"
) counts
WHERE article."id" = counts."article_id";

DROP FUNCTION IF EXISTS try_decode_raver_base64_utf8(text);
