import fs from 'node:fs';
import path from 'node:path';
import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

type CheckResult = {
  name: string;
  passed: boolean;
  detail: string;
};

type ScalarRow = {
  count: bigint | number;
};

const nowTag = new Date().toISOString().replace(/[:.]/g, '-');
const logDir = path.join(process.cwd(), 'prisma', '.cache');
const logPath = path.join(logDir, `canonical-relationships-validation-${nowTag}.json`);

const toNumber = (value: bigint | number): number => Number(value);

const runCheck = async (
  name: string,
  query: string,
  successDetail: string,
  failureDetailFactory: (count: number) => string
): Promise<CheckResult> => {
  const rows = await prisma.$queryRawUnsafe<Array<ScalarRow>>(query);
  const count = toNumber(rows[0]?.count ?? 0);
  return {
    name,
    passed: count === 0,
    detail: count === 0 ? successDetail : failureDetailFactory(count),
  };
};

async function validateCanonicalCounts(): Promise<CheckResult[]> {
  const [eventArtists, eventArtistMembers, eventStages, eventPerformances] = await Promise.all([
    prisma.eventArtist.count(),
    prisma.eventArtistMember.count(),
    prisma.eventStage.count(),
    prisma.eventPerformance.count(),
  ]);

  return [
    {
      name: 'canonical_event_artists_present',
      passed: eventArtists > 0,
      detail: `event_artists=${eventArtists}`,
    },
    {
      name: 'canonical_event_artist_members_present',
      passed: eventArtistMembers > 0,
      detail: `event_artist_members=${eventArtistMembers}`,
    },
    {
      name: 'canonical_event_stages_present',
      passed: eventStages > 0,
      detail: `event_stages=${eventStages}`,
    },
    {
      name: 'canonical_event_performances_present',
      passed: eventPerformances > 0,
      detail: `event_performances=${eventPerformances}`,
    },
  ];
}

async function validateCanonicalIntegrity(): Promise<CheckResult[]> {
  return Promise.all([
    runCheck(
      'event_artists_without_members',
      `
        SELECT COUNT(*) AS count
        FROM "event_artists" artist
        WHERE NOT EXISTS (
          SELECT 1
          FROM "event_artist_members" member
          WHERE member."event_artist_id" = artist."id"
        )
      `,
      'all event_artists have at least one member snapshot row',
      (count) => `${count} event_artists are missing event_artist_members rows`
    ),
    runCheck(
      'event_performances_missing_display_name',
      `
        SELECT COUNT(*) AS count
        FROM "event_performances"
        WHERE TRIM(COALESCE("display_name_snapshot", '')) = ''
      `,
      'all event_performances have display_name_snapshot',
      (count) => `${count} event_performances have empty display_name_snapshot`
    ),
    runCheck(
      'event_stages_missing_normalized_name',
      `
        SELECT COUNT(*) AS count
        FROM "event_stages"
        WHERE TRIM(COALESCE("normalized_name", '')) = ''
      `,
      'all event_stages have normalized_name',
      (count) => `${count} event_stages have empty normalized_name`
    ),
    runCheck(
      'rating_units_missing_primary_binding',
      `
        SELECT COUNT(*) AS count
        FROM "rating_units" unit
        WHERE unit."dj_id" IS NOT NULL
          AND NOT EXISTS (
            SELECT 1
            FROM "rating_unit_dj_bindings" binding
            WHERE binding."unit_id" = unit."id"
              AND binding."dj_id" = unit."dj_id"
          )
      `,
      'all rating_units primary dj references are covered by rating_unit_dj_bindings',
      (count) => `${count} rating_units have dj_id without matching rating_unit_dj_bindings row`
    ),
    runCheck(
      'dj_sets_missing_primary_artist',
      `
        SELECT COUNT(*) AS count
        FROM "dj_sets" set_row
        WHERE set_row."dj_id" IS NOT NULL
          AND NOT EXISTS (
            SELECT 1
            FROM "dj_set_artists" artist
            WHERE artist."set_id" = set_row."id"
              AND artist."dj_id" = set_row."dj_id"
              AND artist."role" = 'primary'
          )
      `,
      'all dj_sets primary dj references are covered by dj_set_artists',
      (count) => `${count} dj_sets have dj_id without matching primary dj_set_artists row`
    ),
    runCheck(
      'posts_missing_bindings_for_event_posts',
      `
        SELECT COUNT(*) AS count
        FROM "posts" post
        WHERE post."event_id" IS NOT NULL
          AND NOT EXISTS (
            SELECT 1
            FROM "post_event_bindings" binding
            WHERE binding."post_id" = post."id"
              AND binding."event_id" = post."event_id"
          )
      `,
      'all posts.event_id references are covered by post_event_bindings',
      (count) => `${count} posts have event_id without matching post_event_bindings row`
    ),
  ]);
}

async function validateLegacyStructuresRemoved(): Promise<CheckResult[]> {
  return Promise.all([
    runCheck(
      'legacy_event_tables_removed',
      `
        SELECT COUNT(*) AS count
        FROM pg_tables
        WHERE schemaname = 'public'
          AND tablename IN ('event_lineup_slots', 'event_lineup_artists', 'event_timetable_slots')
      `,
      'legacy event tables are removed',
      (count) => `${count} legacy event tables still exist`
    ),
    runCheck(
      'legacy_stage_order_removed',
      `
        SELECT COUNT(*) AS count
        FROM information_schema.columns
        WHERE table_schema = 'public'
          AND table_name = 'events'
          AND column_name = 'stage_order'
      `,
      'events.stage_order is removed',
      (count) => `${count} legacy events.stage_order columns still exist`
    ),
    runCheck(
      'legacy_follow_tables_removed',
      `
        SELECT COUNT(*) AS count
        FROM pg_tables
        WHERE schemaname = 'public'
          AND tablename IN ('follows', 'event_favorites')
      `,
      'legacy follow/favorite tables are removed',
      (count) => `${count} legacy follow/favorite tables still exist`
    ),
  ]);
}

async function main() {
  await fs.promises.mkdir(logDir, { recursive: true });

  const checks = [
    ...(await validateCanonicalCounts()),
    ...(await validateCanonicalIntegrity()),
    ...(await validateLegacyStructuresRemoved()),
  ];

  const result = {
    startedAt: new Date().toISOString(),
    passed: checks.every((check) => check.passed),
    checks,
  };

  await fs.promises.writeFile(logPath, JSON.stringify(result, null, 2));

  for (const check of checks) {
    console.log(`[canonical-validate] ${check.passed ? 'ok' : 'fail'} ${check.name}: ${check.detail}`);
  }
  console.log(`[canonical-validate] wrote ${logPath}`);

  if (!result.passed) {
    process.exitCode = 1;
  }
}

void main()
  .catch((error: unknown) => {
    console.error(error);
    process.exitCode = 1;
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
