import 'dotenv/config';
import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

type ExplainRow = {
  'QUERY PLAN': string;
};

type BenchmarkRow = {
  id: string;
  name: string;
  start_date: Date | string | null;
};

type BenchmarkTarget = {
  label: string;
  sql: string;
};

type Stats = {
  minMs: number;
  maxMs: number;
  averageMs: number;
  medianMs: number;
  p95Ms: number;
};

const assert = (condition: boolean, message: string): void => {
  if (!condition) {
    throw new Error(message);
  }
};

const log = (step: string, detail?: Record<string, unknown>): void => {
  console.log('[benchmark-dj-event-query]', step, detail || {});
};

const parseArgs = (argv: string[]): Record<string, string | boolean> => {
  const parsed: Record<string, string | boolean> = {};
  for (let index = 0; index < argv.length; index += 1) {
    const current = argv[index];
    if (!current.startsWith('--')) continue;
    const key = current.slice(2);
    const next = argv[index + 1];
    if (!next || next.startsWith('--')) {
      parsed[key] = true;
      continue;
    }
    parsed[key] = next;
    index += 1;
  }
  return parsed;
};

const escapeSqlLiteral = (value: string): string => `'${value.replace(/'/g, "''")}'`;

const percentile = (values: number[], rawPercentile: number): number => {
  if (values.length === 0) return 0;
  const sorted = [...values].sort((left, right) => left - right);
  const index = Math.min(sorted.length - 1, Math.max(0, Math.ceil(rawPercentile * sorted.length) - 1));
  return sorted[index];
};

const summarize = (durationsMs: number[]): Stats => {
  const sorted = [...durationsMs].sort((left, right) => left - right);
  const total = durationsMs.reduce((sum, value) => sum + value, 0);
  const middle = Math.floor(sorted.length / 2);
  const medianMs = sorted.length % 2 === 0
    ? (sorted[middle - 1] + sorted[middle]) / 2
    : sorted[middle];
  return {
    minMs: sorted[0] || 0,
    maxMs: sorted[sorted.length - 1] || 0,
    averageMs: durationsMs.length > 0 ? total / durationsMs.length : 0,
    medianMs,
    p95Ms: percentile(sorted, 0.95),
  };
};

const formatStats = (stats: Stats): Record<string, string> => ({
  minMs: stats.minMs.toFixed(2),
  avgMs: stats.averageMs.toFixed(2),
  medianMs: stats.medianMs.toFixed(2),
  p95Ms: stats.p95Ms.toFixed(2),
  maxMs: stats.maxMs.toFixed(2),
});

const runExplainAnalyze = async (sql: string): Promise<string> => {
  const rows = await prisma.$queryRawUnsafe<ExplainRow[]>(`EXPLAIN (ANALYZE, BUFFERS) ${sql}`);
  return rows.map((row) => row['QUERY PLAN']).join('\n');
};

const runQuery = async (sql: string): Promise<{ rows: BenchmarkRow[]; durationMs: number }> => {
  const startedAt = process.hrtime.bigint();
  const rows = await prisma.$queryRawUnsafe<BenchmarkRow[]>(sql);
  const endedAt = process.hrtime.bigint();
  return {
    rows,
    durationMs: Number(endedAt - startedAt) / 1_000_000,
  };
};

const resolveDj = async (djId: string | null, djName: string | null): Promise<{ id: string; name: string }> => {
  if (djId) {
    const byId = await prisma.dJ.findUnique({
      where: { id: djId },
      select: { id: true, name: true },
    });
    assert(Boolean(byId), `DJ not found for id ${djId}`);
    return byId as { id: string; name: string };
  }

  assert(Boolean(djName), 'Provide --dj-id or --dj-name');
  const matches = await prisma.dJ.findMany({
    where: {
      name: {
        contains: djName as string,
        mode: 'insensitive',
      },
    },
    orderBy: [{ followerCount: 'desc' }, { soundCloudFollowers: 'desc' }, { name: 'asc' }],
    take: 5,
    select: { id: true, name: true },
  });
  assert(matches.length > 0, `No DJ found for name ${djName}`);
  if (matches.length > 1) {
    log('multiple djs matched, using first result', { matches: matches.map((match) => `${match.name} (${match.id})`) });
  }
  return matches[0] as { id: string; name: string };
};

const buildQueries = (djId: string, scope: 'past' | 'all', limit: number): BenchmarkTarget[] => {
  const djLiteral = escapeSqlLiteral(djId);
  const scopeFilter = scope === 'past' ? 'AND e."start_date" < NOW()' : '';
  return [
    {
      label: 'canonical_event_artist_members',
      sql: `
SELECT DISTINCT e."id", e."name", e."start_date"
FROM "event_artist_members" eam
JOIN "event_artists" ea ON ea."id" = eam."event_artist_id"
JOIN "events" e ON e."id" = ea."event_id"
WHERE eam."dj_id" = ${djLiteral}
${scopeFilter}
ORDER BY e."start_date" DESC NULLS LAST, e."name" ASC
LIMIT ${limit}
      `.trim(),
    },
    {
      label: 'canonical_primary_dj',
      sql: `
SELECT DISTINCT e."id", e."name", e."start_date"
FROM "event_artists" ea
JOIN "events" e ON e."id" = ea."event_id"
WHERE ea."primary_dj_id" = ${djLiteral}
${scopeFilter}
ORDER BY e."start_date" DESC NULLS LAST, e."name" ASC
LIMIT ${limit}
      `.trim(),
    },
  ];
};

const compareIds = (leftRows: BenchmarkRow[], rightRows: BenchmarkRow[]): Record<string, unknown> => {
  const leftIds = new Set(leftRows.map((row) => row.id));
  const rightIds = new Set(rightRows.map((row) => row.id));
  const onlyLeft = [...leftIds].filter((id) => !rightIds.has(id));
  const onlyRight = [...rightIds].filter((id) => !leftIds.has(id));
  return {
    leftCount: leftRows.length,
    rightCount: rightRows.length,
    onlyLeftCount: onlyLeft.length,
    onlyRightCount: onlyRight.length,
    onlyLeftPreview: onlyLeft.slice(0, 10),
    onlyRightPreview: onlyRight.slice(0, 10),
  };
};

async function main(): Promise<void> {
  const args = parseArgs(process.argv.slice(2));
  const rounds = Number(args.rounds || process.env.DJ_EVENT_BENCHMARK_ROUNDS || 7);
  const warmupRounds = Number(args.warmup || process.env.DJ_EVENT_BENCHMARK_WARMUP_ROUNDS || 1);
  const limit = Number(args.limit || process.env.DJ_EVENT_BENCHMARK_LIMIT || 100);
  const scope = String(args.scope || process.env.DJ_EVENT_BENCHMARK_SCOPE || 'past').toLowerCase() === 'all' ? 'all' : 'past';
  const dj = await resolveDj(
    typeof args['dj-id'] === 'string' ? args['dj-id'] : null,
    typeof args['dj-name'] === 'string' ? args['dj-name'] : null
  );

  assert(Number.isFinite(rounds) && rounds > 0, 'rounds must be a positive number');
  assert(Number.isFinite(warmupRounds) && warmupRounds >= 0, 'warmup must be zero or a positive number');
  assert(Number.isFinite(limit) && limit > 0 && limit <= 5000, 'limit must be between 1 and 5000');

  log('resolved dj', { id: dj.id, name: dj.name, rounds, warmupRounds, limit, scope });

  const queries = buildQueries(dj.id, scope, limit);
  const results = new Map<string, BenchmarkRow[]>();

  for (const target of queries) {
    for (let warmupIndex = 0; warmupIndex < warmupRounds; warmupIndex += 1) {
      await runQuery(target.sql);
    }

    const durations: number[] = [];
    let rows: BenchmarkRow[] = [];
    for (let roundIndex = 0; roundIndex < rounds; roundIndex += 1) {
      const result = await runQuery(target.sql);
      rows = result.rows;
      durations.push(result.durationMs);
    }
    results.set(target.label, rows);
    log(`${target.label} timing`, {
      rowCount: rows.length,
      ...formatStats(summarize(durations)),
    });

    const explainPlan = await runExplainAnalyze(target.sql);
    console.log(`[benchmark-dj-event-query] explain ${target.label}`);
    console.log(explainPlan);
  }

  const memberRows = results.get('canonical_event_artist_members') || [];
  const primaryRows = results.get('canonical_primary_dj') || [];
  log('result-set comparison', compareIds(memberRows, primaryRows));
}

void main()
  .catch((error: unknown) => {
    console.error('[benchmark-dj-event-query] failed', error);
    process.exitCode = 1;
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
