/**
 * 导出所有 DJ 页面中未能匹配到流派库的标签
 * 运行方式: npx tsx prisma/export-unmatched-genre-labels.ts [--output=path/to/file.json]
 *
 * 输出: JSON 文件，包含每个未匹配标签、出现次数、以及使用该标签的 DJ 列表
 */
import fs from 'node:fs';
import path from 'node:path';
import dotenv from 'dotenv';
import { PrismaClient } from '@prisma/client';

dotenv.config();

const prisma = new PrismaClient();

const argv = process.argv.slice(2);
const OUTPUT_PATH =
  readArgValue('output') ||
  path.join(process.cwd(), 'prisma', '.cache', `unmatched-genre-labels-${new Date().toISOString().slice(0, 10)}.json`);

function readArgValue(name: string): string | null {
  const prefix = `--${name}=`;
  const matched = argv.find((item) => item.startsWith(prefix));
  return matched ? matched.slice(prefix.length).trim() : null;
}

// ---------- 与 backfill 脚本相同的匹配核心 ----------

type GenreLite = { id: string; name: string; slug: string; path: string };
type GenreIndex = {
  byId: Map<string, GenreLite>;
  exactMap: Map<string, GenreLite>;
  looseMap: Map<string, GenreLite>;
  compactMap: Map<string, GenreLite>;
};

const PRIMARY_SPLIT_SEPARATORS = new Set([',', '\n', '\r', '，', '、', ';', '；']);
const PARENS_OPEN = new Set(['(', '[', '{', '（', '【']);
const PARENS_CLOSE = new Set([')', ']', '}', '）', '】']);

const CONSERVATIVE_GENRE_ALIASES = new Map<string, string[]>([
  ['big room', ['Big Room House']],
  ['big room bounce', ['Big Room House']],
  ['big room edm', ['Big Room House']],
  ['bigroom', ['Big Room House']],
  ['bigroom house', ['Big Room House']],
  ['trap', ['Trap (EDM)']],
  ['house music', ['House']],
  ['peak time techno', ['Peak Time / Driving Techno']],
  ['peak-time techno', ['Peak Time / Driving Techno']],
  ['peaktime / driving techno', ['Peak Time / Driving Techno']],
  ['driving techno', ['Peak Time / Driving Techno']],
  ['peak time driving', ['Peak Time / Driving Techno']],
  ['techno peak time driving', ['Peak Time / Driving Techno']],
  ['techno (peak time / driving)', ['Peak Time / Driving Techno']],
  ['techno (peak time)', ['Peak Time / Driving Techno']],
  ['techno (raw / deep / hypnotic)', ['Techno']],
  ['trance (main floor)', ['Trance']],
  ['trance (raw / deep / hypnotic)', ['Trance']],
  ['afro-house', ['Afro House']],
  ['afrohouse', ['Afro House']],
  ['chill out', ['Chill-out']],
  ['chillout', ['Chill-out']],
  ['dance pop', ['Dance-pop']],
  ['dark wave', ['Darkwave']],
  ['drum & bass', ['Drum and Bass']],
  ['liquid drum & bass', ['Liquid Drum and Bass']],
  ['melodic drum & bass', ['Liquid Drum and Bass']],
  ['melodic drum and bass', ['Liquid Drum and Bass']],
  ['rolling drum & bass', ['Drum and Bass']],
  ['soulful drum & bass', ['Drum and Bass']],
  ['euro dance', ['Eurodance']],
  ['eurodisco', ['Euro disco']],
  ['electro-funk', ['Electrofunk']],
  ['full on psy-trance', ['Full-on Psytrance']],
  ['fullon psytrance', ['Full-on Psytrance']],
  ['glitch-hop', ['Glitch Hop']],
  ['hard groove', ['Hardgroove']],
  ['hard wave', ['Hardwave']],
  ['hardhouse', ['Hard House']],
  ['hardtechno', ['Hard Techno']],
  ['hardtrance', ['Hard Trance']],
  ['hip-house', ['Hip House']],
  ['idm', ['IDM (Intelligent Dance Music)']],
  ['jacking house', ["Jackin' House"]],
  ['jazzy house', ['Jazz House']],
  ['nu disco', ['Nu-disco']],
  ['nu-skool breaks', ['Nu skool breaks']],
  ['progressive psy trance', ['Progressive Psytrance']],
  ['psy trance', ['Psytrance']],
  ['psy-trance', ['Psytrance']],
  ['psychedelic trance', ['Psytrance']],
  ['synth pop', ['Synth-pop']],
  ['synthpop', ['Synth-pop']],
  ['techfunk', ['Tech Funk']],
  ['trip-hop', ['Trip hop']],
  ['balearic', ['Balearic Beat']],
  ['deep tech', ['Deep Techno']],
  ['disco house', ['Disco']],
  ['industrial hard techno', ['Industrial Techno']],
  ['riddim dubstep', ['Riddim']],
  ['uk garage / bassline', ['UK Garage']],
  ['edm', ['Trap (EDM)']],
  ['electronic dance music', ['House']],
  ['breaks', ['Breakbeat']],
  ['garage', ['UK Garage']],
  ['minimal', ['Minimal Techno']],
  ['deep dub house', ['Dub House']],
  ["deep jackin' house", ["Jackin' House"]],
  ['tribal house', ['Tribal Tech House']],
  ['electro rock', ['Electronic Rock']],
]);

const NON_ELECTRONIC_EXCLUSIONS = new Set([
  'hip hop', 'funk', 'r and b', 'dancehall', 'reggae', 'soul',
  'afrobeats', 'afrobeat', 'jazz', 'pop', 'punk', 'indie pop', 'samba',
  'salsa', 'cumbia', 'pop rap', 'alternative', 'indie', 'korean hip hop',
  'nu soul', 'contemporary r and b', 'latin alternative rock', 'hip hop rap',
  'hip hop dance', 'soulful pop', 'alternative pop', 'drill',
  '70s funk', 'k pop electronic remix', 'k pop remix', 'dream pop',
  'emo rock', 'french indie pop', 'dark pop', 'emotional pop',
  'worldbeat', 'reggaeton mexicano', 'latin urbano', 'perreo',
  'latin urban', 'urban', 'urban dance', '70 s funk',
]);

const normalizeText = (value: unknown): string =>
  String(value || '').trim().replace(/\s+/g, ' ');

const normalizeFolded = (value: string): string =>
  value.normalize('NFKD').replace(/[\u0300-\u036f]/g, '').toLowerCase();

const normalizeLooseKey = (value: string): string =>
  normalizeFolded(value)
    .replace(/&/g, ' and ')
    .replace(/[_/]+/g, ' ')
    .replace(/[-\u2010-\u2015\u2212]+/g, ' ')
    .replace(/[()[\]{}''""'".:;!?+*#@`~|\\]/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();

const normalizeCompactKey = (value: string): string =>
  normalizeLooseKey(value).replace(/\s+/g, '');

const splitTopLevel = (value: string, separators: Set<string>): string[] => {
  const result: string[] = [];
  let depth = 0;
  let current = '';
  for (const char of value) {
    if (PARENS_OPEN.has(char)) { depth += 1; current += char; continue; }
    if (PARENS_CLOSE.has(char)) { depth = Math.max(0, depth - 1); current += char; continue; }
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
      .map((item) => normalizeText(item)).filter(Boolean);
    for (const key of keys) {
      remember(exactMap, normalizeFolded(key), genre);
      remember(looseMap, normalizeLooseKey(key), genre);
      remember(compactMap, normalizeCompactKey(key), genre);
    }
  }
  return { byId, exactMap, looseMap, compactMap };
};

const matchGenreLabel = (label: string, index: GenreIndex): boolean => {
  const input = normalizeText(label);
  if (!input) return false;
  if (index.byId.get(input) || index.exactMap.get(normalizeFolded(input))) return true;
  if (index.looseMap.get(normalizeLooseKey(input))) return true;
  if (index.compactMap.get(normalizeCompactKey(input))) return true;
  return false;
};

type MatchCandidate = { label: string };

const buildMatchCandidates = (label: string): MatchCandidate[] => {
  const normalizedInput = normalizeText(label);
  const normalizedKey = normalizeLooseKey(normalizedInput);
  const candidates: MatchCandidate[] = [];
  const seen = new Set<string>();

  const remember = (candidateLabel: string) => {
    const k = normalizeLooseKey(normalizeText(candidateLabel));
    if (!k || seen.has(k)) return;
    seen.add(k);
    candidates.push({ label: normalizeText(candidateLabel) });
  };

  remember(normalizedInput);
  for (const alias of CONSERVATIVE_GENRE_ALIASES.get(normalizedKey) ?? []) remember(alias);

  const parentheticalMatch = normalizedInput.match(/^(.+?)\s*[\(（]\s*(.+?)\s*[\)）]\s*$/);
  if (parentheticalMatch) {
    const prefix = normalizeText(parentheticalMatch[1]);
    const inside = normalizeText(parentheticalMatch[2]);
    if (inside) {
      remember(inside);
      if (prefix) { remember(`${inside} ${prefix}`); remember(`${prefix} ${inside}`); }
    }
  }
  return candidates;
};

const isMatched = (label: string, index: GenreIndex): boolean => {
  if (NON_ELECTRONIC_EXCLUSIONS.has(normalizeLooseKey(normalizeText(label)))) return true;
  for (const candidate of buildMatchCandidates(label)) {
    if (matchGenreLabel(candidate.label, index)) return true;
  }
  // Also try splitting on slash
  const slashParts = splitTopLevel(label, new Set(['/']));
  if (slashParts.length > 1) {
    for (const part of slashParts) {
      for (const candidate of buildMatchCandidates(part)) {
        if (matchGenreLabel(candidate.label, index)) return true;
      }
    }
  }
  return false;
};

// ---------- 主逻辑 ----------

type UnmatchedEntry = {
  label: string;
  occurrences: number;
  djs: Array<{ id: string; name: string }>;
};

async function main() {
  console.log('[export-unmatched] 加载流派库...');
  const genres = await prisma.genre.findMany({
    orderBy: [{ path: 'asc' }],
    select: { id: true, name: true, slug: true, path: true },
  });
  const index = buildGenreIndex(genres);
  console.log(`[export-unmatched] 流派库共 ${genres.length} 条`);

  console.log('[export-unmatched] 加载所有 DJ...');
  const djs = await prisma.dJ.findMany({
    orderBy: [{ createdAt: 'asc' }],
    select: { id: true, name: true, genres: true },
  });
  console.log(`[export-unmatched] DJ 共 ${djs.length} 条`);

  // label → { dj list, count }
  const unmatchedMap = new Map<string, { djs: Array<{ id: string; name: string }>; normalizedKey: string }>();

  for (const dj of djs) {
    const labels = splitGenreLabels(dj.genres);
    for (const label of labels) {
      if (isMatched(label, index)) continue;

      const key = normalizeLooseKey(label);
      const existing = unmatchedMap.get(key);
      if (existing) {
        if (!existing.djs.some((d) => d.id === dj.id)) {
          existing.djs.push({ id: dj.id, name: dj.name });
        }
      } else {
        unmatchedMap.set(key, {
          djs: [{ id: dj.id, name: dj.name }],
          normalizedKey: key,
        });
      }
    }
  }

  const entries: UnmatchedEntry[] = Array.from(unmatchedMap.entries())
    .map(([, value]) => ({
      label: value.djs[0] ? (() => {
        // Recover the original-cased label from DJ genres
        const firstDj = djs.find((d) => d.id === value.djs[0].id);
        if (!firstDj) return value.normalizedKey;
        const labels = splitGenreLabels(firstDj.genres);
        return labels.find((l) => normalizeLooseKey(l) === value.normalizedKey) ?? value.normalizedKey;
      })() : value.normalizedKey,
      occurrences: value.djs.length,
      djs: value.djs,
    }))
    .sort((a, b) => b.occurrences - a.occurrences || a.label.localeCompare(b.label));

  const output = {
    generatedAt: new Date().toISOString(),
    genreLibraryCount: genres.length,
    djCount: djs.length,
    unmatchedLabelCount: entries.length,
    entries,
  };

  await fs.promises.mkdir(path.dirname(OUTPUT_PATH), { recursive: true });
  await fs.promises.writeFile(OUTPUT_PATH, JSON.stringify(output, null, 2), 'utf8');

  console.log(`[export-unmatched] 完成，共 ${entries.length} 个未匹配标签`);
  console.log(`[export-unmatched] 输出文件: ${OUTPUT_PATH}`);
  console.log('\nTop 20 未匹配标签（按出现次数排序）:');
  for (const entry of entries.slice(0, 20)) {
    console.log(`  ${entry.occurrences.toString().padStart(3)}x  ${entry.label}`);
  }
}

main()
  .catch((error) => {
    console.error('[export-unmatched] 失败', error);
    process.exitCode = 1;
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
