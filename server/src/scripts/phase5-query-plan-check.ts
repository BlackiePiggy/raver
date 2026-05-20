import 'dotenv/config';
import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

type ExplainRow = {
  'QUERY PLAN': string;
};

const assert = (condition: boolean, message: string): void => {
  if (!condition) {
    throw new Error(message);
  }
};

const explain = async (sql: string): Promise<string> => {
  const rows = await prisma.$queryRawUnsafe<ExplainRow[]>(`EXPLAIN ${sql}`);
  return rows.map((row) => row['QUERY PLAN']).join('\n');
};

const includesIndexedScan = (plan: string): boolean =>
  /Index Scan|Index Only Scan|Bitmap Index Scan|Bitmap Heap Scan/i.test(plan);

const logPlan = (name: string, plan: string): void => {
  console.log(`[phase5-query-plan-check] ${name}`);
  console.log(plan);
};

async function main(): Promise<void> {
  const [postBinding, newsBinding, followRow, eventArtistMemberRow, eventPerformanceRow, ratingBindingRow, djSetArtistRow] = await Promise.all([
    prisma.postDJBinding.findFirst({ select: { djId: true } }),
    prisma.newsEventBinding.findFirst({ select: { eventId: true } }),
    prisma.userEntityFollow.findFirst({
      where: { relationType: 'follow', targetType: 'dj' },
      select: { userId: true, targetId: true },
    }),
    prisma.eventArtistMember.findFirst({ where: { djId: { not: null } }, select: { djId: true } }),
    prisma.eventPerformance.findFirst({ where: { startAt: { not: null } }, select: { eventId: true, startAt: true } }),
    prisma.ratingUnitDJBinding.findFirst({ select: { djId: true } }),
    prisma.dJSetArtist.findFirst({ where: { djId: { not: null } }, select: { djId: true } }),
  ]);

  const checks: Array<{ name: string; sql: string; optional?: boolean }> = [
    postBinding
      ? {
          name: 'post_dj_bindings by dj_id',
          sql: `SELECT * FROM "post_dj_bindings" WHERE "dj_id" = '${postBinding.djId}' ORDER BY "created_at" DESC LIMIT 20`,
        }
      : { name: 'post_dj_bindings by dj_id', sql: '', optional: true },
    newsBinding
      ? {
          name: 'news_event_bindings by event_id',
          sql: `SELECT * FROM "news_event_bindings" WHERE "event_id" = '${newsBinding.eventId}' ORDER BY "created_at" DESC LIMIT 20`,
        }
      : { name: 'news_event_bindings by event_id', sql: '', optional: true },
    followRow
      ? {
          name: 'user_entity_follows unique lookup',
          sql: `SELECT * FROM "user_entity_follows" WHERE "user_id" = '${followRow.userId}' AND "relation_type" = 'follow' AND "target_type" = 'dj' AND "target_id" = '${followRow.targetId}'`,
        }
      : { name: 'user_entity_follows unique lookup', sql: '', optional: true },
    eventArtistMemberRow
      ? {
          name: 'event_artist_members by dj_id',
          sql: `SELECT * FROM "event_artist_members" WHERE "dj_id" = '${eventArtistMemberRow.djId}' ORDER BY "event_artist_id" LIMIT 20`,
        }
      : { name: 'event_artist_members by dj_id', sql: '', optional: true },
    eventPerformanceRow
      ? {
          name: 'event_performances by event_id and start_at',
          sql: `SELECT * FROM "event_performances" WHERE "event_id" = '${eventPerformanceRow.eventId}' AND "start_at" >= '${eventPerformanceRow.startAt?.toISOString()}'::timestamptz ORDER BY "start_at" ASC LIMIT 20`,
        }
      : { name: 'event_performances by event_id and start_at', sql: '', optional: true },
    ratingBindingRow
      ? {
          name: 'rating_unit_dj_bindings by dj_id',
          sql: `SELECT * FROM "rating_unit_dj_bindings" WHERE "dj_id" = '${ratingBindingRow.djId}' ORDER BY "created_at" DESC LIMIT 20`,
          optional: true,
        }
      : { name: 'rating_unit_dj_bindings by dj_id', sql: '', optional: true },
    djSetArtistRow
      ? {
          name: 'dj_set_artists by dj_id',
          sql: `SELECT * FROM "dj_set_artists" WHERE "dj_id" = '${djSetArtistRow.djId}' ORDER BY "created_at" DESC LIMIT 20`,
        }
      : { name: 'dj_set_artists by dj_id', sql: '', optional: true },
  ];

  for (const check of checks) {
    if (!check.sql) {
      console.log(`[phase5-query-plan-check] skip ${check.name} (no fixture row)`);
      continue;
    }
    const plan = await explain(check.sql);
    logPlan(check.name, plan);
    if (!check.optional) {
      assert(includesIndexedScan(plan), `${check.name} did not use index access path`);
    }
  }

  console.log('[phase5-query-plan-check] all required checks passed');
}

void main()
  .catch((error: unknown) => {
    console.error('[phase5-query-plan-check] failed', error);
    process.exitCode = 1;
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
