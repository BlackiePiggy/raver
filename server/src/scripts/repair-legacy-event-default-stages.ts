import 'dotenv/config';
import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();
const dryRun = process.env.EVENT_DEFAULT_STAGE_REPAIR_DRY_RUN === '1';
const defaultStageName = process.env.EVENT_DEFAULT_STAGE_NAME?.trim() || 'Main Stage';
const defaultStageNormalizedName = defaultStageName.toLowerCase().replace(/\s+/g, ' ');

const logStep = (step: string, detail?: Record<string, unknown>): void => {
  console.log('[repair-legacy-event-default-stages]', step, detail || {});
};

type RepairSummary = {
  affected_events: bigint | number;
  null_stage_performances: bigint | number;
  existing_default_stages: bigint | number;
};

const normalizeCount = (value: bigint | number): number =>
  typeof value === 'bigint' ? Number(value) : value;

async function summarize(): Promise<RepairSummary> {
  const rows = await prisma.$queryRaw<RepairSummary[]>`
    WITH affected_events AS (
      SELECT DISTINCT performance."event_id"
      FROM "event_performances" performance
      WHERE performance."stage_id" IS NULL
    )
    SELECT
      (SELECT COUNT(*) FROM affected_events) AS affected_events,
      (SELECT COUNT(*) FROM "event_performances" performance WHERE performance."stage_id" IS NULL) AS null_stage_performances,
      (
        SELECT COUNT(*)
        FROM "event_stages" stage
        JOIN affected_events
          ON affected_events."event_id" = stage."event_id"
        WHERE stage."normalized_name" = ${defaultStageNormalizedName}
      ) AS existing_default_stages
  `;
  return rows[0] || {
    affected_events: 0,
    null_stage_performances: 0,
    existing_default_stages: 0,
  };
}

async function sampleAffectedEvents(): Promise<Array<{ id: string; name: string; null_stage_performances: bigint | number }>> {
  return prisma.$queryRaw`
    SELECT
      event."id",
      event."name",
      COUNT(performance."id") AS null_stage_performances
    FROM "events" event
    JOIN "event_performances" performance
      ON performance."event_id" = event."id"
    WHERE performance."stage_id" IS NULL
    GROUP BY event."id", event."name"
    ORDER BY null_stage_performances DESC, event."name" ASC
    LIMIT 20
  `;
}

async function repair(): Promise<void> {
  await prisma.$executeRaw`
    WITH affected_events AS (
      SELECT DISTINCT performance."event_id"
      FROM "event_performances" performance
      WHERE performance."stage_id" IS NULL
    ),
    inserted_stages AS (
      INSERT INTO "event_stages" (
        "id",
        "event_id",
        "name",
        "normalized_name",
        "sort_order",
        "created_at",
        "updated_at"
      )
      SELECT
        gen_random_uuid()::TEXT,
        affected_events."event_id",
        ${defaultStageName},
        ${defaultStageNormalizedName},
        1,
        CURRENT_TIMESTAMP,
        CURRENT_TIMESTAMP
      FROM affected_events
      WHERE NOT EXISTS (
        SELECT 1
        FROM "event_stages" existing_stage
        WHERE existing_stage."event_id" = affected_events."event_id"
          AND existing_stage."normalized_name" = ${defaultStageNormalizedName}
      )
      ON CONFLICT ("event_id", "normalized_name") DO NOTHING
      RETURNING "id", "event_id"
    ),
    default_stages AS (
      SELECT "id", "event_id"
      FROM inserted_stages

      UNION ALL

      SELECT existing_stage."id", existing_stage."event_id"
      FROM "event_stages" existing_stage
      JOIN affected_events
        ON affected_events."event_id" = existing_stage."event_id"
      WHERE existing_stage."normalized_name" = ${defaultStageNormalizedName}
    )
    UPDATE "event_performances" performance
    SET
      "stage_id" = default_stages."id",
      "updated_at" = CURRENT_TIMESTAMP
    FROM default_stages
    WHERE performance."event_id" = default_stages."event_id"
      AND performance."stage_id" IS NULL
  `;
}

async function main(): Promise<void> {
  logStep('scan start', { dryRun, defaultStageName });
  const before = await summarize();
  const samples = await sampleAffectedEvents();
  logStep('scan done', {
    affectedEvents: normalizeCount(before.affected_events),
    nullStagePerformances: normalizeCount(before.null_stage_performances),
    existingDefaultStages: normalizeCount(before.existing_default_stages),
    samples: samples.map((sample) => ({
      id: sample.id,
      name: sample.name,
      nullStagePerformances: normalizeCount(sample.null_stage_performances),
    })),
  });

  if (!dryRun && normalizeCount(before.null_stage_performances) > 0) {
    await repair();
  }

  const after = await summarize();
  logStep(dryRun ? 'dry run complete' : 'repair complete', {
    beforeNullStagePerformances: normalizeCount(before.null_stage_performances),
    afterNullStagePerformances: normalizeCount(after.null_stage_performances),
  });
}

void main()
  .catch((error: unknown) => {
    console.error('[repair-legacy-event-default-stages] failed', error);
    process.exitCode = 1;
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
