import fs from 'node:fs';
import path from 'node:path';
import dotenv from 'dotenv';
import { Prisma, PrismaClient } from '@prisma/client';

dotenv.config();

const prisma = new PrismaClient();

type BackfillTarget = 'djs' | 'personality' | 'users' | 'all';

type GenreLite = {
  id: string;
  name: string;
  slug: string;
  path: string;
};

type GenreBindingCandidate = {
  genreId: string;
  label: string;
  path: string | null;
};

type LabelMatch = {
  input: string;
  normalized: string;
  genreId: string;
  genreName: string;
  genrePath: string;
  strategy: string;
};

type DJPlan = {
  djId: string;
  djName: string;
  labels: string[];
  matches: LabelMatch[];
  unmatched: string[];
  nextBindings: Array<{ genreId: string; sortOrder: number }>;
  skippedBecauseExisting: boolean;
};

type PersonalityPlan = {
  resultTypeId: string;
  code: string;
  title: string;
  labels: string[];
  matches: LabelMatch[];
  unmatched: string[];
  nextBindings: GenreBindingCandidate[];
  skippedBecauseExisting: boolean;
};

type UserPlan = {
  userId: string;
  beforeKeys: string[];
  nextKeys: string[];
  matches: LabelMatch[];
  unmatched: string[];
  changed: boolean;
};

type ReportPayload = {
  startedAt: string;
  finishedAt: string;
  apply: boolean;
  overwriteExisting: boolean;
  target: BackfillTarget;
  limit: number | null;
  summary: Record<string, unknown>;
  djs?: Record<string, unknown>;
  personality?: Record<string, unknown>;
  users?: Record<string, unknown>;
};

type GenreIndex = {
  byId: Map<string, GenreLite>;
  exactMap: Map<string, GenreLite>;
  looseMap: Map<string, GenreLite>;
  compactMap: Map<string, GenreLite>;
};

const argv = process.argv.slice(2);
const APPLY = argv.includes('--apply');
const OVERWRITE_EXISTING = argv.includes('--overwrite-existing');
const TARGET = (readArgValue('target') || 'all') as BackfillTarget;
const LIMIT = (() => {
  const raw = readArgValue('limit');
  if (!raw) return null;
  const parsed = Number.parseInt(raw, 10);
  return Number.isFinite(parsed) && parsed > 0 ? parsed : null;
})();
const REPORT_PATH = readArgValue('report') || path.join(
  process.cwd(),
  'prisma',
  '.cache',
  `genre-bindings-backfill-${new Date().toISOString().replace(/[:.]/g, '-')}.json`
);

function readArgValue(name: string): string | null {
  const prefix = `--${name}=`;
  const matched = argv.find((item) => item.startsWith(prefix));
  return matched ? matched.slice(prefix.length).trim() : null;
}

const splitSeparators = /[,\n，、/]+/g;

const normalizeText = (value: unknown): string =>
  String(value || '')
    .trim()
    .replace(/\s+/g, ' ');

const normalizeFolded = (value: string): string =>
  value
    .normalize('NFKD')
    .replace(/[\u0300-\u036f]/g, '')
    .toLowerCase();

const normalizeLooseKey = (value: string): string =>
  normalizeFolded(value)
    .replace(/&/g, ' and ')
    .replace(/[_/]+/g, ' ')
    .replace(/[-]+/g, ' ')
    .replace(/[()[\]{}'".:;!?+*#@`~|\\]/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();

const normalizeCompactKey = (value: string): string =>
  normalizeLooseKey(value).replace(/\s+/g, '');

const splitGenreLabels = (values: unknown): string[] => {
  const source = Array.isArray(values) ? values : [values];
  const result: string[] = [];
  const seen = new Set<string>();

  for (const rawValue of source) {
    const text = String(rawValue || '');
    const parts = text
      .split(splitSeparators)
      .map((item) => normalizeText(item))
      .filter(Boolean);

    for (const part of parts) {
      const key = normalizeLooseKey(part);
      if (!key || seen.has(key)) continue;
      seen.add(key);
      result.push(part);
    }
  }

  return result;
};

const buildGenreIndex = (genres: GenreLite[]): GenreIndex => {
  const byId = new Map<string, GenreLite>();
  const exactMap = new Map<string, GenreLite>();
  const looseMap = new Map<string, GenreLite>();
  const compactMap = new Map<string, GenreLite>();

  const remember = (map: Map<string, GenreLite>, key: string, genre: GenreLite) => {
    if (!key || map.has(key)) return;
    map.set(key, genre);
  };

  for (const genre of genres) {
    byId.set(genre.id, genre);
    const keys = [genre.id, genre.slug, genre.path, genre.name]
      .map((item) => normalizeText(item))
      .filter(Boolean);

    for (const key of keys) {
      remember(exactMap, normalizeFolded(key), genre);
      remember(looseMap, normalizeLooseKey(key), genre);
      remember(compactMap, normalizeCompactKey(key), genre);
    }
  }

  return { byId, exactMap, looseMap, compactMap };
};

const matchGenreLabel = (label: string, index: GenreIndex): LabelMatch | null => {
  const input = normalizeText(label);
  if (!input) return null;

  const exactKey = normalizeFolded(input);
  const looseKey = normalizeLooseKey(input);
  const compactKey = normalizeCompactKey(input);

  const matchedExact = index.byId.get(input)
    || index.exactMap.get(exactKey)
    || null;
  if (matchedExact) {
    const strategy =
      matchedExact.id === input
        ? 'id'
        : normalizeFolded(matchedExact.slug) === exactKey
          ? 'slug'
          : normalizeFolded(matchedExact.path) === exactKey
            ? 'path'
            : 'name_exact';
    return {
      input,
      normalized: looseKey,
      genreId: matchedExact.id,
      genreName: matchedExact.name,
      genrePath: matchedExact.path,
      strategy,
    };
  }

  const matchedLoose = index.looseMap.get(looseKey) || null;
  if (matchedLoose) {
    return {
      input,
      normalized: looseKey,
      genreId: matchedLoose.id,
      genreName: matchedLoose.name,
      genrePath: matchedLoose.path,
      strategy: 'name_loose',
    };
  }

  const matchedCompact = index.compactMap.get(compactKey) || null;
  if (matchedCompact) {
    return {
      input,
      normalized: looseKey,
      genreId: matchedCompact.id,
      genreName: matchedCompact.name,
      genrePath: matchedCompact.path,
      strategy: 'name_compact',
    };
  }

  return null;
};

const topCounts = (values: string[], take = 20): Array<{ value: string; count: number }> => {
  const counter = new Map<string, number>();
  for (const value of values) {
    counter.set(value, (counter.get(value) || 0) + 1);
  }
  return Array.from(counter.entries())
    .sort((a, b) => b[1] - a[1] || a[0].localeCompare(b[0]))
    .slice(0, take)
    .map(([value, count]) => ({ value, count }));
};

const normalizePersonalityBindings = (value: unknown): GenreBindingCandidate[] => {
  if (!Array.isArray(value)) return [];
  const result: GenreBindingCandidate[] = [];
  const seen = new Set<string>();

  for (const raw of value) {
    if (!raw || typeof raw !== 'object' || Array.isArray(raw)) continue;
    const row = raw as Record<string, unknown>;
    const label = normalizeText(row.label);
    const genreId = normalizeText(row.genreId);
    const pathText = normalizeText(row.path) || null;
    const normalizedLabel = label || (pathText ? pathText.split('/').map((part) => normalizeText(part)).filter(Boolean).at(-1) || '' : '');
    if (!normalizedLabel) continue;

    const key = genreId ? `genre:${genreId}` : `custom:${normalizeLooseKey(normalizedLabel)}`;
    if (seen.has(key)) continue;
    seen.add(key);
    result.push({
      genreId,
      label: normalizedLabel,
      path: pathText,
    });
  }

  return result;
};

async function buildDJPlans(index: GenreIndex): Promise<DJPlan[]> {
  const rows = await prisma.dJ.findMany({
    orderBy: [{ createdAt: 'asc' }, { id: 'asc' }],
    ...(LIMIT ? { take: LIMIT } : {}),
    select: {
      id: true,
      name: true,
      genres: true,
      genreBindings: {
        orderBy: [{ sortOrder: 'asc' }, { createdAt: 'asc' }],
        select: {
          genreId: true,
        },
      },
    },
  });

  return rows.map((row) => {
    const labels = splitGenreLabels(row.genres);
    const matches: LabelMatch[] = [];
    const unmatched: string[] = [];
    const matchedGenreIds = new Set<string>();

    for (const label of labels) {
      const matched = matchGenreLabel(label, index);
      if (!matched || matchedGenreIds.has(matched.genreId)) {
        if (!matched) unmatched.push(label);
        continue;
      }
      matchedGenreIds.add(matched.genreId);
      matches.push(matched);
    }

    return {
      djId: row.id,
      djName: row.name,
      labels,
      matches,
      unmatched,
      nextBindings: matches.map((match, indexValue) => ({
        genreId: match.genreId,
        sortOrder: indexValue + 1,
      })),
      skippedBecauseExisting: !OVERWRITE_EXISTING && row.genreBindings.length > 0,
    };
  });
}

async function applyDJPlans(plans: DJPlan[]) {
  for (const plan of plans) {
    if (plan.skippedBecauseExisting) continue;
    await prisma.$transaction(async (tx) => {
      await tx.dJGenreBinding.deleteMany({
        where: { djId: plan.djId },
      });
      if (plan.nextBindings.length > 0) {
        await tx.dJGenreBinding.createMany({
          data: plan.nextBindings.map((binding) => ({
            djId: plan.djId,
            genreId: binding.genreId,
            sortOrder: binding.sortOrder,
          })),
          skipDuplicates: true,
        });
      }
    });
  }
}

async function buildPersonalityPlans(index: GenreIndex): Promise<PersonalityPlan[]> {
  const rows = await prisma.personalityResultType.findMany({
    orderBy: [{ sortOrder: 'asc' }, { code: 'asc' }],
    ...(LIMIT ? { take: LIMIT } : {}),
    select: {
      id: true,
      code: true,
      title: true,
      genreMapping: true,
      genreBindings: true,
    },
  });

  return rows.map((row) => {
    const existingBindings = normalizePersonalityBindings(row.genreBindings);
    const sourceLabels = existingBindings.length > 0
      ? existingBindings.map((item) => item.label)
      : splitGenreLabels(row.genreMapping);

    const matches: LabelMatch[] = [];
    const unmatched: string[] = [];
    const nextBindings: GenreBindingCandidate[] = [];
    const seen = new Set<string>();

    for (const sourceLabel of sourceLabels) {
      const existing = existingBindings.find((item) => normalizeLooseKey(item.label) === normalizeLooseKey(sourceLabel)) || null;
      if (existing?.genreId && index.byId.has(existing.genreId)) {
        const boundGenre = index.byId.get(existing.genreId)!;
        const key = `genre:${boundGenre.id}`;
        if (!seen.has(key)) {
          seen.add(key);
          nextBindings.push({
            genreId: boundGenre.id,
            label: existing.label || boundGenre.name,
            path: boundGenre.path,
          });
        }
        continue;
      }

      const matched = matchGenreLabel(sourceLabel, index);
      if (matched) {
        const key = `genre:${matched.genreId}`;
        if (!seen.has(key)) {
          seen.add(key);
          matches.push(matched);
          nextBindings.push({
            genreId: matched.genreId,
            label: sourceLabel,
            path: matched.genrePath,
          });
        }
      } else {
        const key = `custom:${normalizeLooseKey(sourceLabel)}`;
        if (!seen.has(key)) {
          seen.add(key);
          unmatched.push(sourceLabel);
          nextBindings.push({
            genreId: '',
            label: sourceLabel,
            path: null,
          });
        }
      }
    }

    return {
      resultTypeId: row.id,
      code: row.code,
      title: row.title,
      labels: sourceLabels,
      matches,
      unmatched,
      nextBindings,
      skippedBecauseExisting: !OVERWRITE_EXISTING && existingBindings.some((item) => item.genreId),
    };
  });
}

async function applyPersonalityPlans(plans: PersonalityPlan[]) {
  for (const plan of plans) {
    if (plan.skippedBecauseExisting) continue;
    await prisma.personalityResultType.update({
      where: { id: plan.resultTypeId },
      data: {
        genreBindings: plan.nextBindings.map((binding) => ({
          label: binding.label,
          genreId: binding.genreId || null,
          path: binding.path,
        })) as Prisma.InputJsonValue,
      },
    });
  }
}

async function buildUserPlans(index: GenreIndex): Promise<UserPlan[]> {
  const rows = await prisma.userGenrePreference.findMany({
    orderBy: [{ userId: 'asc' }, { sortOrder: 'asc' }, { createdAt: 'asc' }, { id: 'asc' }],
    ...(LIMIT ? { take: LIMIT } : {}),
    select: {
      userId: true,
      genreKey: true,
    },
  });

  const grouped = new Map<string, string[]>();
  for (const row of rows) {
    const bucket = grouped.get(row.userId) ?? [];
    bucket.push(row.genreKey);
    grouped.set(row.userId, bucket);
  }

  return Array.from(grouped.entries()).map(([userId, beforeKeys]) => {
    const nextKeys: string[] = [];
    const matches: LabelMatch[] = [];
    const unmatched: string[] = [];
    const seen = new Set<string>();

    for (const rawKey of beforeKeys) {
      const matched = matchGenreLabel(rawKey, index);
      const nextKey = matched?.genreId || normalizeText(rawKey);
      if (!nextKey || seen.has(nextKey)) {
        if (!matched && rawKey) unmatched.push(rawKey);
        continue;
      }
      seen.add(nextKey);
      nextKeys.push(nextKey);
      if (matched) {
        matches.push(matched);
      } else {
        unmatched.push(rawKey);
      }
    }

    const changed =
      beforeKeys.length !== nextKeys.length ||
      beforeKeys.some((value, indexValue) => value !== nextKeys[indexValue]);

    return {
      userId,
      beforeKeys,
      nextKeys,
      matches,
      unmatched,
      changed,
    };
  });
}

async function applyUserPlans(plans: UserPlan[]) {
  for (const plan of plans) {
    if (!plan.changed) continue;
    await prisma.$transaction(async (tx) => {
      await tx.userGenrePreference.deleteMany({
        where: { userId: plan.userId },
      });
      if (plan.nextKeys.length > 0) {
        await tx.userGenrePreference.createMany({
          data: plan.nextKeys.map((genreKey, index) => ({
            userId: plan.userId,
            genreKey,
            sortOrder: index + 1,
          })),
          skipDuplicates: true,
        });
      }
    });
  }
}

async function writeReport(payload: ReportPayload) {
  await fs.promises.mkdir(path.dirname(REPORT_PATH), { recursive: true });
  await fs.promises.writeFile(REPORT_PATH, JSON.stringify(payload, null, 2), 'utf8');
}

async function main() {
  const startedAt = new Date().toISOString();
  console.log('[genre-bindings-backfill] start', {
    target: TARGET,
    apply: APPLY,
    overwriteExisting: OVERWRITE_EXISTING,
    limit: LIMIT,
    report: REPORT_PATH,
  });

  const genres = await prisma.genre.findMany({
    orderBy: [{ path: 'asc' }],
    select: {
      id: true,
      name: true,
      slug: true,
      path: true,
    },
  });
  const index = buildGenreIndex(genres);

  const report: ReportPayload = {
    startedAt,
    finishedAt: startedAt,
    apply: APPLY,
    overwriteExisting: OVERWRITE_EXISTING,
    target: TARGET,
    limit: LIMIT,
    summary: {
      genreCount: genres.length,
    },
  };

  if (TARGET === 'djs' || TARGET === 'all') {
    const plans = await buildDJPlans(index);
    const actionable = plans.filter((plan) => !plan.skippedBecauseExisting);
    const matchedCount = plans.reduce((sum, plan) => sum + plan.matches.length, 0);
    const unmatchedLabels = plans.flatMap((plan) => plan.unmatched);

    report.djs = {
      scanned: plans.length,
      actionable: actionable.length,
      skippedBecauseExisting: plans.filter((plan) => plan.skippedBecauseExisting).length,
      matchedCount,
      unmatchedCount: unmatchedLabels.length,
      topUnmatchedLabels: topCounts(unmatchedLabels),
      samples: plans.slice(0, 20),
    };

    console.log('[genre-bindings-backfill] djs', {
      scanned: plans.length,
      actionable: actionable.length,
      skippedBecauseExisting: plans.filter((plan) => plan.skippedBecauseExisting).length,
      matchedCount,
      unmatchedCount: unmatchedLabels.length,
    });

    if (APPLY) {
      await applyDJPlans(plans);
    }
  }

  if (TARGET === 'personality' || TARGET === 'all') {
    const plans = await buildPersonalityPlans(index);
    const actionable = plans.filter((plan) => !plan.skippedBecauseExisting);
    const matchedCount = plans.reduce((sum, plan) => sum + plan.matches.length, 0);
    const unmatchedLabels = plans.flatMap((plan) => plan.unmatched);

    report.personality = {
      scanned: plans.length,
      actionable: actionable.length,
      skippedBecauseExisting: plans.filter((plan) => plan.skippedBecauseExisting).length,
      matchedCount,
      unmatchedCount: unmatchedLabels.length,
      topUnmatchedLabels: topCounts(unmatchedLabels),
      samples: plans.slice(0, 20),
    };

    console.log('[genre-bindings-backfill] personality', {
      scanned: plans.length,
      actionable: actionable.length,
      skippedBecauseExisting: plans.filter((plan) => plan.skippedBecauseExisting).length,
      matchedCount,
      unmatchedCount: unmatchedLabels.length,
    });

    if (APPLY) {
      await applyPersonalityPlans(plans);
    }
  }

  if (TARGET === 'users' || TARGET === 'all') {
    const plans = await buildUserPlans(index);
    const changed = plans.filter((plan) => plan.changed);
    const matchedCount = plans.reduce((sum, plan) => sum + plan.matches.length, 0);
    const unmatchedLabels = plans.flatMap((plan) => plan.unmatched);

    report.users = {
      scanned: plans.length,
      changed: changed.length,
      matchedCount,
      unmatchedCount: unmatchedLabels.length,
      topUnmatchedLabels: topCounts(unmatchedLabels),
      samples: plans.slice(0, 20),
    };

    console.log('[genre-bindings-backfill] users', {
      scanned: plans.length,
      changed: changed.length,
      matchedCount,
      unmatchedCount: unmatchedLabels.length,
    });

    if (APPLY) {
      await applyUserPlans(plans);
    }
  }

  report.finishedAt = new Date().toISOString();
  await writeReport(report);
  console.log('[genre-bindings-backfill] done', {
    report: REPORT_PATH,
  });
}

main()
  .catch((error) => {
    console.error('[genre-bindings-backfill] failed', error);
    process.exitCode = 1;
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
