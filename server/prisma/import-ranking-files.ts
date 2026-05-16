import { PrismaClient, Prisma } from '@prisma/client';
import fs from 'fs';
import path from 'path';

type RankingEntityType = 'dj' | 'festival';

type RankingEntryRecord = {
  rank: number;
  name: string;
  entityId?: string | null;
};

type RankingBoardRecord = {
  id: string;
  title: string;
  subtitle: string;
  description: string;
  coverImageUrl: string | null;
  entityType: RankingEntityType;
  years: number[];
  createdAt: string;
  updatedAt: string;
};

const prisma = new PrismaClient();

const rankingRootCandidates = [
  path.join(process.cwd(), '..', 'web', 'public', 'rankings'),
  path.join(process.cwd(), 'web', 'public', 'rankings'),
];

const LEGACY_RANKING_BOARDS: Record<string, Omit<RankingBoardRecord, 'id' | 'description' | 'coverImageUrl' | 'createdAt' | 'updatedAt'>> = {
  djmag: {
    title: 'DJ MAG TOP 100',
    subtitle: '全球电子音乐最有影响力榜单之一',
    years: [2022, 2023, 2024, 2025],
    entityType: 'dj',
  },
  dongye: {
    title: '东野 DJ 榜',
    subtitle: '中文圈 DJ 热度与影响力榜单',
    years: [2024, 2025],
    entityType: 'dj',
  },
  djmag_festival: {
    title: 'DJ MAG TOP 100 Festivals',
    subtitle: '全球电音节品牌百大榜单',
    years: [2025],
    entityType: 'festival',
  },
};

const sanitizeRankingBoardId = (value: string): string => {
  const normalized = String(value || '')
    .trim()
    .toLowerCase()
    .replace(/[^a-z0-9_-]+/g, '-')
    .replace(/^-+|-+$/g, '')
    .replace(/^_+|_+$/g, '');
  return normalized || `ranking-${Date.now()}`;
};

const resolveRankingRootDir = (): string => {
  for (const dir of rankingRootCandidates) {
    if (fs.existsSync(dir)) return dir;
  }
  throw new Error('ranking root not found');
};

const normalizeRankingYears = (value: unknown): number[] => {
  if (!Array.isArray(value)) return [];
  return Array.from(
    new Set(
      value
        .map((item) => Number(item))
        .filter((item) => Number.isFinite(item))
        .map((item) => Math.max(1900, Math.min(2200, Math.floor(item))))
    )
  ).sort((a, b) => a - b);
};

const normalizeRankingBoard = (input: unknown, fallbackId = ''): RankingBoardRecord | null => {
  if (!input || typeof input !== 'object' || Array.isArray(input)) return null;
  const row = input as Record<string, unknown>;
  const id = sanitizeRankingBoardId(String(row.id || fallbackId || ''));
  const title = String(row.title || '').trim() || id;
  const entityType: RankingEntityType = String(row.entityType || '').trim() === 'festival' ? 'festival' : 'dj';
  const nowIso = new Date().toISOString();
  return {
    id,
    title,
    subtitle: String(row.subtitle || '').trim(),
    description: String(row.description || '').trim(),
    coverImageUrl: String(row.coverImageUrl || '').trim() || null,
    entityType,
    years: normalizeRankingYears(row.years),
    createdAt: String(row.createdAt || '').trim() || nowIso,
    updatedAt: String(row.updatedAt || '').trim() || nowIso,
  };
};

const parseRankingText = (text: string): RankingEntryRecord[] =>
  text
    .split('\n')
    .map((line) => line.trim())
    .filter(Boolean)
    .map((line) => {
      const match = line.match(/^(\d+)\.\s+(.+)$/);
      if (!match) return null;
      return { rank: Number(match[1]), name: String(match[2]).trim() };
    })
    .filter((item): item is RankingEntryRecord => item !== null)
    .sort((a, b) => a.rank - b.rank);

const parseRankingEntries = (value: unknown): RankingEntryRecord[] => {
  if (!Array.isArray(value)) return [];
  const rows = value
    .map((item): RankingEntryRecord | null => {
      if (!item || typeof item !== 'object' || Array.isArray(item)) return null;
      const row = item as Record<string, unknown>;
      const rank = Number(row.rank);
      const name = String(row.name || '').trim();
      if (!Number.isFinite(rank) || rank <= 0 || !name) return null;
      const entityIdRaw = String(row.entityId || '').trim();
      return {
        rank: Math.floor(rank),
        name,
        ...(entityIdRaw ? { entityId: entityIdRaw } : {}),
      };
    })
    .filter((item): item is RankingEntryRecord => item !== null);
  const deduped = new Map<number, RankingEntryRecord>();
  for (const item of rows) deduped.set(item.rank, item);
  return Array.from(deduped.values()).sort((a, b) => a.rank - b.rank);
};

const collectRankingBoardYearsFromFiles = (rootDir: string, boardId: string): number[] => {
  const dirPath = path.join(rootDir, sanitizeRankingBoardId(boardId));
  if (!fs.existsSync(dirPath)) return [];
  const yearSet = new Set<number>();
  for (const file of fs.readdirSync(dirPath)) {
    const match = file.match(/^(\d{4})\.(json|txt)$/i);
    if (match) yearSet.add(Number(match[1]));
  }
  return Array.from(yearSet).filter(Number.isFinite).sort((a, b) => a - b);
};

const loadRankingBoards = (rootDir: string): RankingBoardRecord[] => {
  let boards: RankingBoardRecord[] = Object.entries(LEGACY_RANKING_BOARDS).map(([id, board]) => ({
    id,
    title: board.title,
    subtitle: board.subtitle,
    description: '',
    coverImageUrl: null,
    entityType: board.entityType,
    years: board.years,
    createdAt: new Date().toISOString(),
    updatedAt: new Date().toISOString(),
  }));
  const manifestPath = path.join(rootDir, '_boards.json');
  if (fs.existsSync(manifestPath)) {
    const payload = JSON.parse(fs.readFileSync(manifestPath, 'utf8'));
    const rows: unknown[] = Array.isArray(payload?.boards) ? payload.boards : [];
    const normalizedRows = rows
      .map((item: unknown) => normalizeRankingBoard(item))
      .filter((item): item is RankingBoardRecord => item !== null);
    if (normalizedRows.length > 0) boards = normalizedRows;
  }

  return boards.map((board) => ({
    ...board,
    years: Array.from(new Set([...board.years, ...collectRankingBoardYearsFromFiles(rootDir, board.id)])).sort((a, b) => a - b),
  }));
};

const loadRankingYearData = (rootDir: string, boardId: string, year: number): { source: string; entries: RankingEntryRecord[] } | null => {
  const boardDir = path.join(rootDir, sanitizeRankingBoardId(boardId));
  const jsonPath = path.join(boardDir, `${year}.json`);
  if (fs.existsSync(jsonPath)) {
    const payload = JSON.parse(fs.readFileSync(jsonPath, 'utf8'));
    return {
      source: String(payload?.source || '').trim() || 'file_json',
      entries: parseRankingEntries(payload?.entries),
    };
  }
  const txtPath = path.join(boardDir, `${year}.txt`);
  if (!fs.existsSync(txtPath)) return null;
  return {
    source: 'legacy_txt',
    entries: parseRankingText(fs.readFileSync(txtPath, 'utf8')),
  };
};

const buildDJHonorsForDJ = async (djId: string): Promise<Prisma.InputJsonValue[]> => {
  const rows = await prisma.rankingEntry.findMany({
    where: {
      entityId: djId,
      rankingYear: {
        board: {
          entityType: 'dj',
        },
      },
    },
    include: {
      rankingYear: {
        include: {
          board: true,
        },
      },
    },
    orderBy: [
      { rankingYear: { year: 'desc' } },
      { rank: 'asc' },
    ],
  });
  return rows.map((row) => ({
    id: `ranking-${row.rankingYear.board.id}-${row.rankingYear.year}-${row.rank}`,
    category: 'ranking',
    title: row.rankingYear.board.title,
    subtitle: row.rankingYear.board.subtitle
      ? `${row.rankingYear.year} · ${row.rankingYear.board.subtitle}`
      : `${row.rankingYear.year} Ranking`,
    source: row.rankingYear.board.id,
    year: row.rankingYear.year,
    rank: row.rank,
    url: null,
  }));
};

async function main() {
  const rootDir = resolveRankingRootDir();
  const boards = loadRankingBoards(rootDir);
  const affectedDJIds = new Set<string>();

  for (const board of boards) {
    await prisma.rankingBoard.upsert({
      where: { id: board.id },
      update: {
        title: board.title,
        subtitle: board.subtitle,
        description: board.description,
        coverImageUrl: board.coverImageUrl,
        entityType: board.entityType,
        updatedAt: new Date(board.updatedAt),
      },
      create: {
        id: board.id,
        title: board.title,
        subtitle: board.subtitle,
        description: board.description,
        coverImageUrl: board.coverImageUrl,
        entityType: board.entityType,
        createdAt: new Date(board.createdAt),
        updatedAt: new Date(board.updatedAt),
      },
    });

    for (const year of board.years) {
      const yearData = loadRankingYearData(rootDir, board.id, year);
      if (!yearData) continue;
      const rankingYear = await prisma.rankingYear.upsert({
        where: {
          boardId_year: {
            boardId: board.id,
            year,
          },
        },
        update: {
          source: yearData.source,
          updatedAt: new Date(),
        },
        create: {
          boardId: board.id,
          year,
          source: yearData.source,
          updatedAt: new Date(),
        },
      });
      await prisma.rankingEntry.deleteMany({
        where: { rankingYearId: rankingYear.id },
      });
      if (yearData.entries.length > 0) {
        await prisma.rankingEntry.createMany({
          data: yearData.entries.map((entry) => ({
            rankingYearId: rankingYear.id,
            rank: entry.rank,
            name: entry.name,
            entityId: entry.entityId || null,
          })),
        });
      }
      if (board.entityType === 'dj') {
        for (const entry of yearData.entries) {
          if (entry.entityId) affectedDJIds.add(entry.entityId);
        }
      }
      console.log(`[ranking-import] ${board.id}/${year}: ${yearData.entries.length} entries`);
    }
  }

  for (const djId of affectedDJIds) {
    await prisma.dJ.update({
      where: { id: djId },
      data: {
        honors: await buildDJHonorsForDJ(djId),
      },
    });
  }
  console.log(`[ranking-import] boards=${boards.length}, affected_djs=${affectedDJIds.size}`);
}

main()
  .catch((error) => {
    console.error(error);
    process.exitCode = 1;
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
