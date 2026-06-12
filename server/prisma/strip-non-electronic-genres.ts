/**
 * 从 DJ 记录的 genres 数组中删除非电子音乐标签
 * 运行方式: npx tsx prisma/strip-non-electronic-genres.ts [--dry-run] [--apply]
 *
 * --dry-run (默认): 只输出将被修改的 DJ 列表，不实际写入
 * --apply: 实际执行删除操作
 */
import dotenv from 'dotenv';
import { PrismaClient } from '@prisma/client';

dotenv.config();

const prisma = new PrismaClient();
const APPLY = process.argv.includes('--apply');

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

const NON_ELECTRONIC_EXCLUSIONS = new Set([
  'hip hop', 'funk', 'r and b', 'dancehall', 'reggae', 'soul',
  'afrobeats', 'afrobeat', 'jazz', 'pop', 'punk', 'indie pop', 'samba',
  'salsa', 'cumbia', 'pop rap', 'alternative', 'indie', 'korean hip hop',
  'nu soul', 'contemporary r and b', 'latin alternative rock', 'hip hop rap',
  'hip hop dance', 'soulful pop', 'alternative pop', 'drill',
  '70s funk', '70 s funk', 'k pop electronic remix', 'k pop remix', 'dream pop',
  'emo rock', 'french indie pop', 'dark pop', 'emotional pop',
  'worldbeat', 'reggaeton mexicano', 'latin urbano', 'perreo',
  'latin urban', 'urban', 'urban dance',
]);

function isNonElectronic(label: string): boolean {
  return NON_ELECTRONIC_EXCLUSIONS.has(normalizeLooseKey(normalizeText(label)));
}

async function main() {
  console.log(`[strip-non-electronic] 模式: ${APPLY ? '实际执行' : 'DRY-RUN（预览）'}`);
  console.log(`[strip-non-electronic] 排除名单: ${NON_ELECTRONIC_EXCLUSIONS.size} 条\n`);

  const djs = await prisma.dJ.findMany({
    orderBy: [{ createdAt: 'asc' }],
    select: { id: true, name: true, genres: true },
  });
  console.log(`[strip-non-electronic] DJ 总数: ${djs.length}\n`);

  let affectedCount = 0;
  let removedTotal = 0;

  for (const dj of djs) {
    if (!dj.genres || dj.genres.length === 0) continue;

    const kept: string[] = [];
    const removed: string[] = [];

    for (const label of dj.genres) {
      if (isNonElectronic(label)) {
        removed.push(label);
      } else {
        kept.push(label);
      }
    }

    if (removed.length === 0) continue;

    affectedCount++;
    removedTotal += removed.length;
    console.log(`  ${dj.name} (${dj.id})`);
    console.log(`    删除: ${removed.join(', ')}`);
    console.log(`    保留: ${kept.length > 0 ? kept.join(', ') : '(空)'}`);

    if (APPLY) {
      await prisma.dJ.update({
        where: { id: dj.id },
        data: { genres: kept },
      });
    }
  }

  console.log(`\n[strip-non-electronic] 汇总:`);
  console.log(`  受影响 DJ: ${affectedCount}`);
  console.log(`  删除标签总数: ${removedTotal}`);
  if (!APPLY) {
    console.log(`\n  ⚠️  这是 dry-run，未实际写入。添加 --apply 参数执行实际删除。`);
  } else {
    console.log(`\n  ✅  已完成实际删除。`);
  }
}

main()
  .catch((error) => {
    console.error('[strip-non-electronic] 失败', error);
    process.exitCode = 1;
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
