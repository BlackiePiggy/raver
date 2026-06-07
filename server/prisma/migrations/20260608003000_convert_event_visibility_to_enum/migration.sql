CREATE TYPE "EventVisibility" AS ENUM ('visible', 'hidden');

ALTER TABLE "events"
ALTER COLUMN "visibility" DROP DEFAULT,
ALTER COLUMN "visibility" TYPE "EventVisibility"
USING (
  CASE
    WHEN lower(coalesce("visibility"::text, '')) = 'hidden' THEN 'hidden'
    ELSE 'visible'
  END
)::"EventVisibility",
ALTER COLUMN "visibility" SET DEFAULT 'visible';
