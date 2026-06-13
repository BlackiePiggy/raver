/**
 * 将 DJ.genres 收敛到已存在的 genreBindings 对应 canonical genre name。
 *
 * 设计目标：
 * 1. 避免 iOS 详情页把 raw genres 作为额外不可点击标签继续展示。
 * 2. 让 DJ.genres 与已写入的 DJGenreBinding 保持一致。
 *
 * 注意：
 * - 该脚本假定 genreBindings 已经先通过 backfill 脚本写入数据库。
 * - 没有任何 genreBindings 的 DJ 不会被自动改写，只会进入报告，便于先执行 backfill 再复跑。
 */
import fs from 'node:fs';
import path from 'node:path';
import dotenv from 'dotenv';
import { PrismaClient } from '@prisma/client';

dotenv.config();

const prisma = new PrismaClient();

const argv = process.argv.slice(2);
const APPLY = argv.includes('--apply');
const LIMIT = (() => {
  const raw = readArgValue('limit');
  if (!raw) return null;
  const parsed = Number.parseInt(raw, 10);
  return Number.isFinite(parsed) && parsed > 0 ? parsed : null;
})();
const REPORT_PATH =
  readArgValue('report') ||
  path.join(
    process.cwd(),
    'prisma',
    '.cache',
    `cleanup-dj-genres-for-clickable-tags-${new Date().toISOString().replace(/[:.]/g, '-')}.json`
  );

function readArgValue(name: string): string | null {
  const prefix = `--${name}=`;
  const matched = argv.find((item) => item.startsWith(prefix));
  return matched ? matched.slice(prefix.length).trim() : null;
}

const PRIMARY_SPLIT_SEPARATORS = new Set([',', '\n', '\r', '，', '、', ';', '；']);
const PARENS_OPEN = new Set(['(', '[', '{', '（', '【']);
const PARENS_CLOSE = new Set([')', ']', '}', '）', '】']);

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
    .replace(/[-\u2010-\u2015\u2212]+/g, ' ')
    .replace(/[()[\]{}\u2018\u2019\u201c\u201d'".:;!?+*#@`~|\\]/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();

const splitTopLevel = (value: string, separators: Set<string>): string[] => {
  const result: string[] = [];
  let depth = 0;
  let current = '';

  for (const char of value) {
    if (PARENS_OPEN.has(char)) {
      depth += 1;
      current += char;
      continue;
    }

    if (PARENS_CLOSE.has(char)) {
      depth = Math.max(0, depth - 1);
      current += char;
      continue;
    }

    if (depth === 0 && separators.has(char)) {
      const normalized = normalizeText(current);
      if (normalized) result.push(normalized);
      current = '';
      continue;
    }

    current += char;
  }

  const tail = normalizeText(current);
  if (tail) result.push(tail);
  return result;
};

const splitGenreLabels = (values: unknown): string[] => {
  const source = Array.isArray(values) ? values : [values];
  const result: string[] = [];
  const seen = new Set<string>();

  for (const rawValue of source) {
    const text = String(rawValue || '');
    const parts = splitTopLevel(text, PRIMARY_SPLIT_SEPARATORS);

    for (const part of parts) {
      const key = normalizeLooseKey(part);
      if (!key || seen.has(key)) continue;
      seen.add(key);
      result.push(normalizeText(part));
    }
  }

  return result;
};

type DJCleanupPlan = {
  djId: string;
  djName: string;
  beforeGenres: string[];
  afterGenres: string[];
  removedLabels: string[];
  changed: boolean;
  hasBindings: boolean;
};

async function main() {
  const rows = await prisma.dJ.findMany({
    orderBy: [{ createdAt: 'asc' }, { id: 'asc' }],
    ...(LIMIT ? { take: LIMIT } : {}),
    select: {
      id: true,
      name: true,
      genres: true,
      genreBindings: {
        orderBy: [{ sortOrder: 'asc' }, { createdAt: 'asc' }, { id: 'asc' }],
        select: {
          genre: {
            select: {
              name: true,
            },
          },
        },
      },
    },
  });

  const plans: DJCleanupPlan[] = rows.map((row) => {
    const beforeGenres = splitGenreLabels(row.genres);
    const afterGenres = row.genreBindings
      .map((binding) => normalizeText(binding.genre.name))
      .filter(Boolean);
    const afterSet = new Set(afterGenres.map((label) => normalizeLooseKey(label)));
    const removedLabels = beforeGenres.filter((label) => !afterSet.has(normalizeLooseKey(label)));
    const changed =
      beforeGenres.length !== afterGenres.length ||
      beforeGenres.some((label, index) => normalizeLooseKey(label) !== normalizeLooseKey(afterGenres[index] || ''));

    return {
      djId: row.id,
      djName: row.name,
      beforeGenres,
      afterGenres,
      removedLabels,
      changed,
      hasBindings: row.genreBindings.length > 0,
    };
  });

  const changedPlans = plans.filter((plan) => plan.changed && plan.hasBindings);
  const bindinglessChangedPlans = plans.filter((plan) => plan.changed && !plan.hasBindings);

  if (APPLY) {
    for (const plan of changedPlans) {
      await prisma.dJ.update({
        where: { id: plan.djId },
        data: { genres: plan.afterGenres },
      });
    }
  }

  const report = {
    generatedAt: new Date().toISOString(),
    apply: APPLY,
    limit: LIMIT,
    totalDjs: rows.length,
    changedWithBindings: changedPlans.length,
    changedWithoutBindings: bindinglessChangedPlans.length,
    examples: changedPlans.slice(0, 100),
    skippedWithoutBindings: bindinglessChangedPlans.slice(0, 100),
  };

  fs.mkdirSync(path.dirname(REPORT_PATH), { recursive: true });
  fs.writeFileSync(REPORT_PATH, `${JSON.stringify(report, null, 2)}\n`, 'utf8');

  console.log(`[cleanup-dj-genres] mode: ${APPLY ? 'apply' : 'dry-run'}`);
  console.log(`[cleanup-dj-genres] total DJs: ${rows.length}`);
  console.log(`[cleanup-dj-genres] changed with bindings: ${changedPlans.length}`);
  console.log(`[cleanup-dj-genres] changed without bindings: ${bindinglessChangedPlans.length}`);
  console.log(`[cleanup-dj-genres] report: ${REPORT_PATH}`);

  if (!APPLY) {
    console.log('[cleanup-dj-genres] dry-run only, no data written');
  }
}

main()
  .catch((error) => {
    console.error('[cleanup-dj-genres] failed', error);
    process.exitCode = 1;
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
