import { Prisma, PrismaClient } from '@prisma/client';
import fs from 'fs';
import path from 'path';

const prisma = new PrismaClient();

export type GlobalSearchTab =
  | 'all'
  | 'events'
  | 'djs'
  | 'peopleSquads'
  | 'posts'
  | 'news'
  | 'sets'
  | 'rankings'
  | 'ratings'
  | 'festivals'
  | 'labels'
  | 'genreTree'
  | 'wiki';

export type GlobalSearchItemType =
  | 'event'
  | 'news'
  | 'dj'
  | 'set'
  | 'ranking_board'
  | 'ranking_entry'
  | 'rating_event'
  | 'rating_unit'
  | 'post'
  | 'label'
  | 'festival'
  | 'genre'
  | 'user'
  | 'squad';

export type GlobalSearchItem = {
  id: string;
  type: GlobalSearchItemType;
  entityID: string;
  title: string;
  subtitle: string | null;
  summary: string | null;
  imageUrl: string | null;
  badgeText: string | null;
  deeplink: string;
  relevanceScore: number;
  publishedAt: Date | null;
  updatedAt: Date | null;
  rankingYear: number | null;
};

export type GlobalSearchPartialError = {
  tab: GlobalSearchTab;
  message: string;
};

export type GlobalSearchResponse = {
  query: string;
  tab: GlobalSearchTab;
  limit: number;
  totalCount: number;
  items: GlobalSearchItem[];
  countsByTab: Record<GlobalSearchTab, number>;
  partialErrors: GlobalSearchPartialError[];
  generatedAt: string;
};

type SearchParams = {
  query: string;
  tab: GlobalSearchTab;
  limit: number;
  userId: string;
};

type SearchTask = {
  tab: GlobalSearchTab;
  run: () => Promise<GlobalSearchItem[]>;
};

type RankingEntityType = 'dj' | 'festival';

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

type RankingEntryRecord = {
  rank: number;
  name: string;
  entityId?: string;
};

const SEARCH_TABS: GlobalSearchTab[] = [
  'all',
  'events',
  'djs',
  'peopleSquads',
  'posts',
  'news',
  'sets',
  'rankings',
  'ratings',
  'festivals',
  'labels',
  'genreTree',
  'wiki',
];

const NEWS_MARKER = '#RAVER_NEWS';

const LEGACY_RANKING_BOARDS: Record<
  string,
  {
    title: string;
    subtitle: string;
    years: number[];
    coverImageUrl?: string;
    entityType: RankingEntityType;
  }
> = {
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

const rankingRootCandidates = [
  path.join(process.cwd(), '..', 'web', 'public', 'rankings'),
  path.join(process.cwd(), 'web', 'public', 'rankings'),
];

const containsInsensitive = (query: string) => ({
  contains: query,
  mode: 'insensitive' as const,
});

const fetchFestivalIDsByAliasContains = async (query: string, options: { excludeIDs?: string[]; limit?: number } = {}) => {
  const rows = await prisma.$queryRaw<Array<{ id: string }>>(Prisma.sql`
    SELECT "id"
    FROM "wiki_festivals"
    WHERE "is_active" = true
      AND cardinality("aliases") > 0
      AND EXISTS (
        SELECT 1
        FROM unnest("aliases") AS alias
        WHERE alias ILIKE ${`%${query}%`}
      )
      ${options.excludeIDs?.length ? Prisma.sql`AND "id" NOT IN (${Prisma.join(options.excludeIDs)})` : Prisma.empty}
    ORDER BY "name" ASC
    LIMIT ${options.limit ?? 50}
  `);
  return rows.map((row) => row.id);
};

const normalizeQuery = (value: string): string => value.trim().replace(/\s+/g, ' ');

const normalizeText = (value: string | null | undefined): string =>
  String(value || '').trim().toLowerCase();

const compact = (values: Array<string | null | undefined>, separator = ' · '): string | null => {
  const result = values.map((item) => String(item || '').trim()).filter(Boolean).join(separator);
  return result.length > 0 ? result : null;
};

const truncate = (value: string | null | undefined, maxLength = 120): string | null => {
  const singleLine = String(value || '').replace(/\s+/g, ' ').trim();
  if (!singleLine) return null;
  if (singleLine.length <= maxLength) return singleLine;
  return `${singleLine.slice(0, maxLength - 1)}…`;
};

const scoreText = (query: string, value: string | null | undefined, weights = { exact: 100, prefix: 86, contains: 68 }): number => {
  const needle = normalizeText(query);
  const haystack = normalizeText(value);
  if (!needle || !haystack) return 0;
  if (haystack === needle) return weights.exact;
  if (haystack.startsWith(needle)) return weights.prefix;
  if (haystack.includes(needle)) return weights.contains;
  return 0;
};

const scoreTexts = (query: string, values: Array<string | null | undefined>, weights?: { exact: number; prefix: number; contains: number }): number =>
  values.reduce((best, value) => Math.max(best, scoreText(query, value, weights)), 0);

const arrayScore = (query: string, values: string[] | null | undefined): number =>
  scoreTexts(query, Array.isArray(values) ? values : [], { exact: 88, prefix: 76, contains: 54 });

const recencyBoost = (date: Date | null | undefined, maxBoost = 4): number => {
  if (!date) return 0;
  const ageDays = Math.max(0, (Date.now() - date.getTime()) / 86_400_000);
  return Math.max(0, maxBoost - Math.min(maxBoost, ageDays / 30));
};

const finalizeScore = (score: number): number => Math.round(Math.max(0, Math.min(100, score)) * 100) / 100;

const formatSecondsLabel = (value: number | null | undefined): string | null => {
  if (!Number.isFinite(value)) return null;
  const seconds = Math.max(0, Math.floor(Number(value)));
  const mins = Math.floor(seconds / 60);
  const secs = seconds % 60;
  return `${mins}:${secs.toString().padStart(2, '0')}`;
};

const buildSetDeeplink = (setId: string, options?: { tracklistId?: string | null; startTime?: number | null }): string => {
  const params = new URLSearchParams();
  if (options?.tracklistId) {
    params.set('tracklistId', options.tracklistId);
  }
  if (Number.isFinite(options?.startTime)) {
    params.set('t', String(Math.max(0, Math.floor(Number(options?.startTime)))));
  }
  const query = params.toString();
  return `raver://set/${setId}${query ? `?${query}` : ''}`;
};

const isTabRequested = (requested: GlobalSearchTab, tab: GlobalSearchTab): boolean =>
  requested === 'all' || requested === tab;

const emptyCounts = (): Record<GlobalSearchTab, number> =>
  SEARCH_TABS.reduce((result, tab) => ({ ...result, [tab]: 0 }), {} as Record<GlobalSearchTab, number>);

const itemTab = (type: GlobalSearchItemType): GlobalSearchTab => {
  switch (type) {
    case 'event':
      return 'events';
    case 'news':
      return 'news';
    case 'dj':
      return 'djs';
    case 'set':
      return 'sets';
    case 'ranking_board':
    case 'ranking_entry':
      return 'rankings';
    case 'rating_event':
    case 'rating_unit':
      return 'ratings';
    case 'post':
      return 'posts';
    case 'label':
      return 'labels';
    case 'festival':
      return 'festivals';
    case 'genre':
      return 'genreTree';
    case 'user':
    case 'squad':
      return 'peopleSquads';
  }
};

const sortItems = (items: GlobalSearchItem[]): GlobalSearchItem[] =>
  items.slice().sort((a, b) => {
    if (b.relevanceScore !== a.relevanceScore) return b.relevanceScore - a.relevanceScore;
    const bDate = b.publishedAt || b.updatedAt;
    const aDate = a.publishedAt || a.updatedAt;
    return (bDate?.getTime() ?? 0) - (aDate?.getTime() ?? 0);
  });

const sanitizeRankingBoardId = (value: string): string => {
  const normalized = String(value || '')
    .trim()
    .toLowerCase()
    .replace(/[^a-z0-9_-]+/g, '-')
    .replace(/^-+|-+$/g, '')
    .replace(/^_+|_+$/g, '');
  return normalized || 'ranking';
};

const resolveRankingRootDir = (): string | null => {
  for (const dir of rankingRootCandidates) {
    if (fs.existsSync(dir)) return dir;
  }
  return null;
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
  const subtitle = String(row.subtitle || '').trim();
  const description = String(row.description || '').trim();
  const coverImageUrlRaw = String(row.coverImageUrl || '').trim();
  const entityType: RankingEntityType = String(row.entityType || '').trim() === 'festival' ? 'festival' : 'dj';
  const createdAt = String(row.createdAt || '').trim() || new Date().toISOString();
  const updatedAt = String(row.updatedAt || '').trim() || createdAt;
  return {
    id,
    title,
    subtitle,
    description,
    coverImageUrl: coverImageUrlRaw || null,
    entityType,
    years: normalizeRankingYears(row.years),
    createdAt,
    updatedAt,
  };
};

const collectRankingBoardYearsFromFiles = (rootDir: string, boardId: string): number[] => {
  const dirPath = path.join(rootDir, sanitizeRankingBoardId(boardId));
  if (!fs.existsSync(dirPath)) return [];
  const yearSet = new Set<number>();
  for (const file of fs.readdirSync(dirPath)) {
    const match = file.match(/^(\d{4})\.(json|txt)$/i);
    if (!match) continue;
    const year = Number(match[1]);
    if (Number.isFinite(year)) yearSet.add(year);
  }
  return Array.from(yearSet).sort((a, b) => a - b);
};

const parseRankingEntries = (value: unknown): RankingEntryRecord[] => {
  if (!Array.isArray(value)) return [];
  return value
    .map((item) => {
      if (!item || typeof item !== 'object' || Array.isArray(item)) return null;
      const row = item as Record<string, unknown>;
      const rank = Number(row.rank);
      const name = String(row.name || '').trim();
      if (!Number.isFinite(rank) || rank <= 0 || !name) return null;
      const entityId = String(row.entityId || '').trim();
      return {
        rank: Math.floor(rank),
        name,
        ...(entityId ? { entityId } : {}),
      };
    })
    .filter((item): item is RankingEntryRecord => item !== null)
    .sort((a, b) => a.rank - b.rank);
};

const parseRankingText = (value: string): RankingEntryRecord[] =>
  value
    .split(/\r?\n/g)
    .map((line) => line.trim())
    .filter(Boolean)
    .map((line) => {
      const match = line.match(/^(\d+)[\s.)、-]+(.+)$/);
      if (!match) return null;
      return { rank: Number(match[1]), name: match[2].trim() };
    })
    .filter((item): item is RankingEntryRecord => item !== null);

const loadRankingBoards = (): RankingBoardRecord[] => {
  const rootDir = resolveRankingRootDir();
  let boards = Object.entries(LEGACY_RANKING_BOARDS).map(([id, board]) => ({
    id,
    title: board.title,
    subtitle: board.subtitle,
    description: '',
    coverImageUrl: board.coverImageUrl || null,
    entityType: board.entityType,
    years: board.years.slice(),
    createdAt: new Date().toISOString(),
    updatedAt: new Date().toISOString(),
  }));

  if (rootDir) {
    const manifestPath = path.join(rootDir, '_boards.json');
    if (fs.existsSync(manifestPath)) {
      try {
        const payload = JSON.parse(fs.readFileSync(manifestPath, 'utf8'));
        const rows = Array.isArray(payload?.boards) ? payload.boards : [];
        const normalizedRows = rows
          .map((item: unknown) => normalizeRankingBoard(item))
          .filter((item: RankingBoardRecord | null): item is RankingBoardRecord => item !== null);
        if (normalizedRows.length > 0) boards = normalizedRows;
      } catch {
        // Keep legacy fallback if the manifest cannot be parsed.
      }
    }
  }

  return boards.map((board) => {
    const fileYears = rootDir ? collectRankingBoardYearsFromFiles(rootDir, board.id) : [];
    const years = Array.from(new Set([...board.years, ...fileYears])).sort((a, b) => a - b);
    return { ...board, years };
  });
};

const loadRankingYearEntries = (boardId: string, year: number): RankingEntryRecord[] => {
  const rootDir = resolveRankingRootDir();
  if (!rootDir) return [];
  const boardDir = path.join(rootDir, sanitizeRankingBoardId(boardId));
  const jsonPath = path.join(boardDir, `${year}.json`);
  if (fs.existsSync(jsonPath)) {
    try {
      const payload = JSON.parse(fs.readFileSync(jsonPath, 'utf8'));
      return parseRankingEntries(payload?.entries);
    } catch {
      return [];
    }
  }

  const txtPath = path.join(boardDir, `${year}.txt`);
  if (!fs.existsSync(txtPath)) return [];
  return parseRankingText(fs.readFileSync(txtPath, 'utf8'));
};

const decodeBase64Utf8 = (encoded: string): string => {
  const source = encoded.trim();
  if (!source) return '';
  try {
    return Buffer.from(source, 'base64').toString('utf8').trim();
  } catch {
    return '';
  }
};

const readValueAfterPrefix = (line: string, key: string): string => {
  const prefixes = [`${key}：`, `${key}:`, `${key.toUpperCase()}：`, `${key.toUpperCase()}:`];
  for (const prefix of prefixes) {
    if (!line.startsWith(prefix)) continue;
    const value = line.slice(prefix.length).trim();
    if (value) return value;
  }
  return '';
};

const decodeRaverNews = (content: string): { title: string; summary: string; body: string } | null => {
  const lines = String(content || '')
    .split(/\r?\n/g)
    .map((line) => line.trim())
    .filter(Boolean);
  if (!lines.includes(NEWS_MARKER)) return null;

  const read = (keys: string[]): string => {
    for (const line of lines) {
      for (const key of keys) {
        const value = readValueAfterPrefix(line, key);
        if (value) return value;
      }
    }
    return '';
  };

  const title = read(['标题', 'title']) || '未命名资讯';
  const summary = read(['摘要', 'summary']) || '';
  const bodyEncoded = read(['正文MD64', 'content_md64', 'body_md64']);
  const body = decodeBase64Utf8(bodyEncoded) || read(['正文', 'content', 'body']) || '';
  return {
    title: title.replace(/\s+/g, ' ').trim() || '未命名资讯',
    summary: summary.replace(/\s+/g, ' ').trim(),
    body,
  };
};

const searchEvents = async (query: string, limit: number): Promise<GlobalSearchItem[]> => {
  const brandAliasIDs = await fetchFestivalIDsByAliasContains(query);

  const rows = await prisma.event.findMany({
    where: {
      OR: [
        { name: containsInsensitive(query) },
        { description: containsInsensitive(query) },
        { city: containsInsensitive(query) },
        { country: containsInsensitive(query) },
        { venueName: containsInsensitive(query) },
        { organizerName: containsInsensitive(query) },
        { lineupSlots: { some: { djName: containsInsensitive(query) } } },
        {
          wikiFestival: {
            is: {
              OR: [
                { name: containsInsensitive(query) },
                { abbreviation: containsInsensitive(query) },
                { aliases: { has: query } },
              ],
            },
          },
        },
        ...(brandAliasIDs.length > 0 ? [{ wikiFestivalId: { in: brandAliasIDs } }] : []),
      ],
    },
    select: {
      id: true,
      name: true,
      description: true,
      coverImageUrl: true,
      city: true,
      country: true,
      venueName: true,
      organizerName: true,
      startDate: true,
      endDate: true,
      status: true,
      isVerified: true,
      updatedAt: true,
      wikiFestival: {
        select: {
          name: true,
          abbreviation: true,
          aliases: true,
        },
      },
      lineupSlots: {
        select: { djName: true, stageName: true },
        take: 8,
      },
    },
    orderBy: [{ startDate: 'desc' }],
    take: Math.max(limit * 3, 20),
  });

  return sortItems(
    rows.map((row) => {
      const lineupNames = row.lineupSlots.map((slot) => slot.djName);
      const brandNames = row.wikiFestival
        ? [row.wikiFestival.name, row.wikiFestival.abbreviation, ...(row.wikiFestival.aliases || [])]
        : [];
      const score = Math.max(
        scoreText(query, row.name),
        scoreTexts(query, [row.venueName, row.city, row.country, row.organizerName], { exact: 78, prefix: 66, contains: 48 }),
        scoreTexts(query, brandNames, { exact: 86, prefix: 74, contains: 56 }),
        scoreTexts(query, lineupNames, { exact: 82, prefix: 70, contains: 52 }),
        scoreText(query, row.description, { exact: 54, prefix: 44, contains: 34 })
      ) + (row.isVerified ? 4 : 0) + recencyBoost(row.updatedAt, 2);
      return {
        id: `event:${row.id}`,
        type: 'event',
        entityID: row.id,
        title: row.name,
        subtitle: compact([compact([row.city, row.country], ', '), row.venueName, row.startDate.toISOString().slice(0, 10)]),
        summary: truncate(row.description || lineupNames.join(', ')),
        imageUrl: row.coverImageUrl,
        badgeText: row.status,
        deeplink: `raver://event/${row.id}`,
        relevanceScore: finalizeScore(score),
        publishedAt: row.startDate,
        updatedAt: row.updatedAt,
        rankingYear: null,
      } satisfies GlobalSearchItem;
    })
  ).slice(0, limit);
};

const searchNews = async (query: string, limit: number): Promise<GlobalSearchItem[]> => {
  const rows = await prisma.post.findMany({
    where: {
      visibility: 'public',
      content: { contains: NEWS_MARKER },
    },
    select: {
      id: true,
      content: true,
      images: true,
      displayPublishedAt: true,
      createdAt: true,
      updatedAt: true,
      user: {
        select: { username: true, displayName: true },
      },
    },
    orderBy: [{ displayPublishedAt: 'desc' }, { createdAt: 'desc' }],
    take: Math.max(limit * 12, 120),
  });

  const items: GlobalSearchItem[] = rows
    .map((row): GlobalSearchItem | null => {
      const decoded = decodeRaverNews(row.content);
      if (!decoded) return null;
      const score = Math.max(
        scoreText(query, decoded.title),
        scoreText(query, decoded.summary, { exact: 82, prefix: 70, contains: 54 }),
        scoreText(query, decoded.body, { exact: 58, prefix: 46, contains: 34 })
      ) + recencyBoost(row.displayPublishedAt || row.createdAt, 5);
      if (score <= 0) return null;
      return {
        id: `news:${row.id}`,
        type: 'news',
        entityID: row.id,
        title: decoded.title,
        subtitle: compact(['Raver News', row.user.displayName || row.user.username]),
        summary: truncate(decoded.summary || decoded.body),
        imageUrl: row.images[0] || null,
        badgeText: 'News',
        deeplink: `raver://news/${row.id}`,
        relevanceScore: finalizeScore(score),
        publishedAt: row.displayPublishedAt || row.createdAt,
        updatedAt: row.updatedAt,
        rankingYear: null,
      };
    })
    .filter((item): item is GlobalSearchItem => item !== null);

  return sortItems(items).slice(0, limit);
};

const searchDJs = async (query: string, limit: number): Promise<GlobalSearchItem[]> => {
  const rows = await prisma.dJ.findMany({
    where: {
      OR: [
        { name: containsInsensitive(query) },
        { bio: containsInsensitive(query) },
        { country: containsInsensitive(query) },
        { sourceRealName: containsInsensitive(query) },
        { aliases: { has: query } },
        { genres: { has: query } },
      ],
    },
    select: {
      id: true,
      name: true,
      aliases: true,
      genres: true,
      bio: true,
      avatarUrl: true,
      bannerUrl: true,
      country: true,
      isVerified: true,
      followerCount: true,
      updatedAt: true,
    },
    orderBy: [{ followerCount: 'desc' }, { name: 'asc' }],
    take: Math.max(limit * 3, 20),
  });

  return sortItems(
    rows.map((row) => {
      const score = Math.max(
        scoreText(query, row.name),
        arrayScore(query, row.aliases),
        arrayScore(query, row.genres),
        scoreTexts(query, [row.country, row.bio], { exact: 60, prefix: 50, contains: 36 })
      ) + (row.isVerified ? 5 : 0) + Math.min(5, Math.log10(Math.max(1, row.followerCount + 1)));
      return {
        id: `dj:${row.id}`,
        type: 'dj',
        entityID: row.id,
        title: row.name,
        subtitle: compact([row.genres.slice(0, 3).join(', '), row.country]),
        summary: truncate(row.bio),
        imageUrl: row.avatarUrl || row.bannerUrl,
        badgeText: row.isVerified ? 'Verified DJ' : 'DJ',
        deeplink: `raver://dj/${row.id}`,
        relevanceScore: finalizeScore(score),
        publishedAt: null,
        updatedAt: row.updatedAt,
        rankingYear: null,
      } satisfies GlobalSearchItem;
    })
  ).slice(0, limit);
};

const searchSets = async (query: string, limit: number): Promise<GlobalSearchItem[]> => {
  const [setRows, trackRows] = await Promise.all([
    prisma.dJSet.findMany({
      where: {
        OR: [
          { title: containsInsensitive(query) },
          { description: containsInsensitive(query) },
          { venue: containsInsensitive(query) },
          { eventName: containsInsensitive(query) },
          { customDjNames: { has: query } },
          { dj: { name: containsInsensitive(query) } },
        ],
      },
      select: {
        id: true,
        title: true,
        description: true,
        thumbnailUrl: true,
        platform: true,
        duration: true,
        recordedAt: true,
        venue: true,
        eventName: true,
        viewCount: true,
        likeCount: true,
        isVerified: true,
        createdAt: true,
        updatedAt: true,
        customDjNames: true,
        dj: {
          select: { name: true, avatarUrl: true },
        },
      },
      orderBy: [{ recordedAt: 'desc' }, { createdAt: 'desc' }],
      take: Math.max(limit * 3, 20),
    }),
    prisma.tracklistTrack.findMany({
      where: {
        OR: [{ title: containsInsensitive(query) }, { artist: containsInsensitive(query) }],
      },
      select: {
        id: true,
        title: true,
        artist: true,
        startTime: true,
        status: true,
        position: true,
        updatedAt: true,
        createdAt: true,
        tracklist: {
          select: {
            id: true,
            title: true,
            set: {
              select: {
                id: true,
                title: true,
                description: true,
                thumbnailUrl: true,
                platform: true,
                duration: true,
                recordedAt: true,
                venue: true,
                eventName: true,
                viewCount: true,
                likeCount: true,
                isVerified: true,
                createdAt: true,
                updatedAt: true,
                customDjNames: true,
                dj: {
                  select: { name: true, avatarUrl: true },
                },
              },
            },
          },
        },
      },
      orderBy: [{ updatedAt: 'desc' }, { createdAt: 'desc' }],
      take: Math.max(limit * 4, 40),
    }),
  ]);

  const setItems = setRows.map((row) => {
    const performerNames = [row.dj.name, ...row.customDjNames];
    const durationMinutes = row.duration ? `${Math.round(row.duration / 60)} min` : null;
    const score = Math.max(
      scoreText(query, row.title),
      scoreTexts(query, performerNames, { exact: 84, prefix: 72, contains: 56 }),
      scoreTexts(query, [row.eventName, row.venue], { exact: 72, prefix: 60, contains: 44 }),
      scoreText(query, row.description, { exact: 56, prefix: 46, contains: 34 })
    ) + (row.isVerified ? 3 : 0) + Math.min(4, Math.log10(Math.max(1, row.viewCount + row.likeCount + 1)));
    return {
      id: `set:${row.id}`,
      type: 'set',
      entityID: row.id,
      title: row.title,
      subtitle: compact([performerNames.join(', '), row.eventName, durationMinutes]),
      summary: truncate(row.description || row.venue),
      imageUrl: row.thumbnailUrl || row.dj.avatarUrl,
      badgeText: row.platform,
      deeplink: buildSetDeeplink(row.id),
      relevanceScore: finalizeScore(score),
      publishedAt: row.recordedAt || row.createdAt,
      updatedAt: row.updatedAt,
      rankingYear: null,
    } satisfies GlobalSearchItem;
  });

  const trackItems = trackRows.map((row) => {
    const set = row.tracklist.set;
    const performerNames = [set.dj.name, ...set.customDjNames];
    const timeLabel = formatSecondsLabel(row.startTime);
    const score = Math.max(
      scoreText(query, row.title, { exact: 100, prefix: 88, contains: 74 }),
      scoreText(query, row.artist, { exact: 96, prefix: 84, contains: 70 }),
      scoreText(query, set.title, { exact: 72, prefix: 60, contains: 48 }),
      scoreTexts(query, performerNames, { exact: 68, prefix: 56, contains: 42 })
    ) + (set.isVerified ? 2 : 0) + Math.min(4, Math.log10(Math.max(1, set.viewCount + set.likeCount + 1)));

    return {
      id: `set_track:${row.id}`,
      type: 'set',
      entityID: set.id,
      title: row.title,
      subtitle: compact([row.artist, set.title, performerNames.join(', ')]),
      summary: truncate(
        compact(
          [
            row.tracklist.title ? `Tracklist: ${row.tracklist.title}` : 'Tracklist 命中',
            set.eventName,
            set.venue,
            timeLabel ? `跳转到 ${timeLabel}` : null,
          ],
          ' · '
        ),
        140
      ),
      imageUrl: set.thumbnailUrl || set.dj.avatarUrl,
      badgeText: timeLabel ? `Tracklist ${timeLabel}` : 'Tracklist',
      deeplink: buildSetDeeplink(set.id, {
        tracklistId: row.tracklist.id,
        startTime: row.startTime,
      }),
      relevanceScore: finalizeScore(score),
      publishedAt: set.recordedAt || set.createdAt,
      updatedAt: set.updatedAt,
      rankingYear: null,
    } satisfies GlobalSearchItem;
  });

  return sortItems([...setItems, ...trackItems]).slice(0, limit);
};

const searchRankings = async (query: string, limit: number): Promise<GlobalSearchItem[]> => {
  const boards = loadRankingBoards();
  const items: GlobalSearchItem[] = [];

  for (const board of boards) {
    const latestYear = board.years[board.years.length - 1] || null;
    const boardScore = Math.max(
      scoreText(query, board.title),
      scoreText(query, board.subtitle, { exact: 82, prefix: 68, contains: 50 }),
      scoreText(query, board.description, { exact: 58, prefix: 46, contains: 34 })
    );
    if (boardScore > 0) {
      items.push({
        id: `ranking_board:${board.id}`,
        type: 'ranking_board',
        entityID: board.id,
        title: board.title,
        subtitle: compact([board.subtitle, latestYear ? String(latestYear) : null]),
        summary: truncate(board.description || `${board.years.length} years`),
        imageUrl: board.coverImageUrl,
        badgeText: 'Ranking',
        deeplink: `raver://ranking-board/${board.id}${latestYear ? `?year=${latestYear}` : ''}`,
        relevanceScore: finalizeScore(boardScore + 2),
        publishedAt: null,
        updatedAt: new Date(board.updatedAt),
        rankingYear: latestYear,
      });
    }

    for (const year of board.years.slice().sort((a, b) => b - a)) {
      const entries = loadRankingYearEntries(board.id, year);
      for (const entry of entries) {
        const entryScore = scoreText(query, entry.name, { exact: 90, prefix: 78, contains: 62 });
        if (entryScore <= 0) continue;
        items.push({
          id: `ranking_entry:${board.id}:${year}:${entry.rank}`,
          type: 'ranking_entry',
          entityID: board.id,
          title: `#${entry.rank} ${entry.name}`,
          subtitle: compact([board.title, String(year)]),
          summary: entry.entityId ? 'Linked ranking entry' : null,
          imageUrl: board.coverImageUrl,
          badgeText: 'Ranking Entry',
          deeplink: `raver://ranking-board/${board.id}?year=${year}`,
          relevanceScore: finalizeScore(entryScore - Math.min(8, entry.rank / 20)),
          publishedAt: null,
          updatedAt: new Date(board.updatedAt),
          rankingYear: year,
        });
      }
    }
  }

  return sortItems(items).slice(0, limit);
};

const searchRatings = async (query: string, limit: number): Promise<GlobalSearchItem[]> => {
  const [events, units] = await Promise.all([
    prisma.ratingEvent.findMany({
      where: {
        OR: [{ name: containsInsensitive(query) }, { description: containsInsensitive(query) }],
      },
      select: {
        id: true,
        name: true,
        description: true,
        imageUrl: true,
        createdAt: true,
        updatedAt: true,
        units: { select: { id: true } },
      },
      orderBy: [{ createdAt: 'desc' }],
      take: Math.max(limit * 2, 12),
    }),
    prisma.ratingUnit.findMany({
      where: {
        OR: [
          { name: containsInsensitive(query) },
          { description: containsInsensitive(query) },
          { event: { name: containsInsensitive(query) } },
        ],
      },
      select: {
        id: true,
        eventId: true,
        name: true,
        description: true,
        imageUrl: true,
        createdAt: true,
        updatedAt: true,
        event: { select: { name: true, imageUrl: true } },
      },
      orderBy: [{ createdAt: 'desc' }],
      take: Math.max(limit * 2, 12),
    }),
  ]);

  const eventItems = events.map((row) => {
    const score = Math.max(scoreText(query, row.name), scoreText(query, row.description, { exact: 62, prefix: 50, contains: 36 })) + recencyBoost(row.createdAt, 2);
    return {
      id: `rating_event:${row.id}`,
      type: 'rating_event',
      entityID: row.id,
      title: row.name,
      subtitle: `${row.units.length} rating units`,
      summary: truncate(row.description),
      imageUrl: row.imageUrl,
      badgeText: 'Rating Event',
      deeplink: `raver://circle/rating-event/${row.id}`,
      relevanceScore: finalizeScore(score),
      publishedAt: row.createdAt,
      updatedAt: row.updatedAt,
      rankingYear: null,
    } satisfies GlobalSearchItem;
  });

  const unitItems = units.map((row) => {
    const score = Math.max(
      scoreText(query, row.name),
      scoreText(query, row.event.name, { exact: 78, prefix: 64, contains: 48 }),
      scoreText(query, row.description, { exact: 58, prefix: 46, contains: 34 })
    ) + recencyBoost(row.createdAt, 2);
    return {
      id: `rating_unit:${row.id}`,
      type: 'rating_unit',
      entityID: row.id,
      title: row.name,
      subtitle: row.event.name,
      summary: truncate(row.description),
      imageUrl: row.imageUrl || row.event.imageUrl,
      badgeText: 'Rating Unit',
      deeplink: `raver://rating-unit/${row.id}`,
      relevanceScore: finalizeScore(score),
      publishedAt: row.createdAt,
      updatedAt: row.updatedAt,
      rankingYear: null,
    } satisfies GlobalSearchItem;
  });

  return sortItems([...eventItems, ...unitItems]).slice(0, limit);
};

const searchPosts = async (query: string, limit: number, userId: string): Promise<GlobalSearchItem[]> => {
  const rows = await prisma.post.findMany({
    where: {
      visibility: 'public',
      NOT: { content: { contains: NEWS_MARKER } },
      hides: { none: { userId } },
      OR: [
        { content: containsInsensitive(query) },
        {
          user: {
            OR: [{ username: containsInsensitive(query) }, { displayName: containsInsensitive(query) }],
          },
        },
        { squad: { name: containsInsensitive(query) } },
      ],
    },
    select: {
      id: true,
      content: true,
      images: true,
      type: true,
      location: true,
      likeCount: true,
      repostCount: true,
      saveCount: true,
      commentCount: true,
      displayPublishedAt: true,
      createdAt: true,
      updatedAt: true,
      user: { select: { username: true, displayName: true, avatarUrl: true } },
      squad: { select: { name: true, avatarUrl: true } },
    },
    orderBy: [{ displayPublishedAt: 'desc' }, { createdAt: 'desc' }],
    take: Math.max(limit * 3, 20),
  });

  return sortItems(
    rows.map((row) => {
      const authorName = row.user.displayName || row.user.username;
      const score = Math.max(
        scoreText(query, row.content, { exact: 72, prefix: 62, contains: 48 }),
        scoreText(query, authorName, { exact: 72, prefix: 60, contains: 44 }),
        scoreText(query, row.squad?.name, { exact: 72, prefix: 60, contains: 44 })
      ) + Math.min(5, Math.log10(Math.max(1, row.likeCount + row.repostCount + row.saveCount + 1))) + recencyBoost(row.displayPublishedAt || row.createdAt, 4);
      return {
        id: `post:${row.id}`,
        type: 'post',
        entityID: row.id,
        title: truncate(row.content, 48) || 'Circle Post',
        subtitle: compact([row.squad?.name || 'Circle', authorName, row.location]),
        summary: truncate(row.content, 140),
        imageUrl: row.images[0] || row.squad?.avatarUrl || row.user.avatarUrl,
        badgeText: row.type,
        deeplink: `raver://community/post/${row.id}`,
        relevanceScore: finalizeScore(score),
        publishedAt: row.displayPublishedAt || row.createdAt,
        updatedAt: row.updatedAt,
        rankingYear: null,
      } satisfies GlobalSearchItem;
    })
  ).slice(0, limit);
};

const searchLabels = async (query: string, limit: number): Promise<GlobalSearchItem[]> => {
  const labels = await prisma.label.findMany({
    where: {
      OR: [
        { name: containsInsensitive(query) },
        { nation: containsInsensitive(query) },
        { genresPreview: containsInsensitive(query) },
        { introductionPreview: containsInsensitive(query) },
        { introduction: containsInsensitive(query) },
        { founderName: containsInsensitive(query) },
        { genres: { has: query } },
      ],
    },
    select: {
      id: true,
      name: true,
      nation: true,
      genres: true,
      genresPreview: true,
      introductionPreview: true,
      introduction: true,
      logoUrl: true,
      avatarUrl: true,
      likes: true,
      soundcloudFollowers: true,
      updatedAt: true,
    },
    orderBy: [{ likes: 'desc' }, { name: 'asc' }],
    take: Math.max(limit * 2, 12),
  });

  return sortItems(labels.map((row) => {
    const score = Math.max(
      scoreText(query, row.name),
      arrayScore(query, row.genres),
      scoreTexts(query, [row.nation, row.genresPreview, row.introductionPreview, row.introduction], { exact: 62, prefix: 50, contains: 36 })
    ) + Math.min(4, Math.log10(Math.max(1, (row.likes || 0) + (row.soundcloudFollowers || 0) + 1)));
    return {
      id: `label:${row.id}`,
      type: 'label',
      entityID: row.id,
      title: row.name,
      subtitle: compact(['Label', row.nation, row.genres.slice(0, 2).join(', ')]),
      summary: truncate(row.introductionPreview || row.introduction),
      imageUrl: row.avatarUrl || row.logoUrl,
      badgeText: 'Label',
      deeplink: `raver://label/${row.id}`,
      relevanceScore: finalizeScore(score),
      publishedAt: null,
      updatedAt: row.updatedAt,
      rankingYear: null,
    } satisfies GlobalSearchItem;
  })).slice(0, limit);
};

const searchFestivals = async (query: string, limit: number): Promise<GlobalSearchItem[]> => {
  const festivals = await prisma.wikiFestival.findMany({
    where: {
      isActive: true,
      AND: [
        {
          OR: [
            { name: containsInsensitive(query) },
            { abbreviation: containsInsensitive(query) },
            { aliases: { has: query } },
            { country: containsInsensitive(query) },
            { city: containsInsensitive(query) },
            { tagline: containsInsensitive(query) },
            { introduction: containsInsensitive(query) },
          ],
        },
      ],
    },
    select: {
      id: true,
      name: true,
      abbreviation: true,
      aliases: true,
      country: true,
      city: true,
      tagline: true,
      introduction: true,
      avatarUrl: true,
      backgroundUrl: true,
      updatedAt: true,
    },
    orderBy: [{ name: 'asc' }],
    take: Math.max(limit * 2, 12),
  });

  let aliasPartialFestivals: typeof festivals = [];
  if (festivals.length < limit) {
    const aliasPartialIDs = await fetchFestivalIDsByAliasContains(query, {
      excludeIDs: festivals.map((row) => row.id),
      limit: Math.max(limit * 2, 12),
    });
    aliasPartialFestivals = await prisma.wikiFestival.findMany({
      where: {
        isActive: true,
        id: {
          in: aliasPartialIDs,
        },
      },
      select: {
        id: true,
        name: true,
        abbreviation: true,
        aliases: true,
        country: true,
        city: true,
        tagline: true,
        introduction: true,
        avatarUrl: true,
        backgroundUrl: true,
        updatedAt: true,
      },
      orderBy: [{ name: 'asc' }],
      take: Math.max(limit * 2, 12),
    });
  }

  const festivalRows = [...festivals, ...aliasPartialFestivals];

  return sortItems(festivalRows.map((row) => {
    const score = Math.max(
      scoreText(query, row.name),
      scoreText(query, row.abbreviation, { exact: 90, prefix: 78, contains: 62 }),
      arrayScore(query, row.aliases),
      scoreTexts(query, [row.country, row.city, row.tagline, row.introduction], { exact: 64, prefix: 52, contains: 38 })
    );
    return {
      id: `festival:${row.id}`,
      type: 'festival',
      entityID: row.id,
      title: row.name,
      subtitle: compact(['Festival', compact([row.city, row.country], ', ')]),
      summary: truncate(row.tagline || row.introduction),
      imageUrl: row.avatarUrl || row.backgroundUrl,
      badgeText: 'Festival',
      deeplink: `raver://festival/${row.id}`,
      relevanceScore: finalizeScore(score),
      publishedAt: null,
      updatedAt: row.updatedAt,
      rankingYear: null,
    } satisfies GlobalSearchItem;
  })).slice(0, limit);
};

const searchGenreTree = async (query: string, limit: number): Promise<GlobalSearchItem[]> => {
  const genres = await prisma.genre.findMany({
    where: {
      OR: [
        { name: containsInsensitive(query) },
        { slug: containsInsensitive(query) },
        { description: containsInsensitive(query) },
      ],
    },
    select: {
      id: true,
      name: true,
      slug: true,
      description: true,
      color: true,
      iconUrl: true,
      createdAt: true,
    },
    orderBy: [{ name: 'asc' }],
    take: Math.max(limit * 2, 12),
  });

  return sortItems(genres.map((row) => {
    const score = Math.max(
      scoreText(query, row.name),
      scoreText(query, row.slug, { exact: 86, prefix: 74, contains: 58 }),
      scoreText(query, row.description, { exact: 58, prefix: 46, contains: 34 })
    );
    return {
      id: `genre:${row.id}`,
      type: 'genre',
      entityID: row.id,
      title: row.name,
      subtitle: compact(['Genre Tree', row.slug]),
      summary: truncate(row.description),
      imageUrl: row.iconUrl,
      badgeText: 'Genre',
      deeplink: `raver://genre/${row.id}`,
      relevanceScore: finalizeScore(score),
      publishedAt: null,
      updatedAt: row.createdAt,
      rankingYear: null,
    } satisfies GlobalSearchItem;
  })).slice(0, limit);
};

const searchWiki = async (query: string, limit: number): Promise<GlobalSearchItem[]> => {
  const [labels, festivals, genres] = await Promise.all([
    searchLabels(query, limit),
    searchFestivals(query, limit),
    searchGenreTree(query, limit),
  ]);
  return sortItems([...labels, ...festivals, ...genres]).slice(0, limit);
};

const searchPeopleSquads = async (query: string, limit: number, userId: string): Promise<GlobalSearchItem[]> => {
  const [users, squads] = await Promise.all([
    prisma.user.findMany({
      where: {
        isActive: true,
        id: { not: userId },
        OR: [
          { username: containsInsensitive(query) },
          { displayName: containsInsensitive(query) },
          { bio: containsInsensitive(query) },
          { location: containsInsensitive(query) },
        ],
      },
      select: {
        id: true,
        username: true,
        displayName: true,
        avatarUrl: true,
        bio: true,
        location: true,
        favoriteGenres: true,
        isVerified: true,
        updatedAt: true,
      },
      orderBy: [{ username: 'asc' }],
      take: Math.max(limit * 2, 12),
    }),
    prisma.squad.findMany({
      where: {
        isPublic: true,
        OR: [{ name: containsInsensitive(query) }, { description: containsInsensitive(query) }, { notice: containsInsensitive(query) }],
      },
      select: {
        id: true,
        name: true,
        description: true,
        notice: true,
        avatarUrl: true,
        bannerUrl: true,
        isPublic: true,
        updatedAt: true,
        _count: { select: { members: true } },
      },
      orderBy: [{ updatedAt: 'desc' }],
      take: Math.max(limit * 2, 12),
    }),
  ]);

  const userItems = users.map((row) => {
    const score = Math.max(
      scoreText(query, row.displayName),
      arrayScore(query, row.favoriteGenres),
      scoreTexts(query, [row.bio, row.location], { exact: 58, prefix: 46, contains: 34 })
    ) + (row.isVerified ? 4 : 0);
    return {
      id: `user:${row.id}`,
      type: 'user',
      entityID: row.id,
      title: row.displayName || row.username,
      subtitle: compact([row.location]),
      summary: truncate(row.bio || row.favoriteGenres.join(', ')),
      imageUrl: row.avatarUrl,
      badgeText: row.isVerified ? 'Verified User' : 'User',
      deeplink: `raver://profile/${row.id}`,
      relevanceScore: finalizeScore(score),
      publishedAt: null,
      updatedAt: row.updatedAt,
      rankingYear: null,
    } satisfies GlobalSearchItem;
  });

  const squadItems = squads.map((row) => {
    const score = Math.max(
      scoreText(query, row.name),
      scoreText(query, row.description, { exact: 62, prefix: 50, contains: 36 }),
      scoreText(query, row.notice, { exact: 52, prefix: 42, contains: 30 })
    ) + Math.min(4, Math.log10(Math.max(1, row._count.members + 1)));
    return {
      id: `squad:${row.id}`,
      type: 'squad',
      entityID: row.id,
      title: row.name,
      subtitle: `${row._count.members} members · Public squad`,
      summary: truncate(row.description || row.notice),
      imageUrl: row.avatarUrl || row.bannerUrl,
      badgeText: 'Squad',
      deeplink: `raver://squad/${row.id}`,
      relevanceScore: finalizeScore(score),
      publishedAt: null,
      updatedAt: row.updatedAt,
      rankingYear: null,
    } satisfies GlobalSearchItem;
  });

  return sortItems([...userItems, ...squadItems]).slice(0, limit);
};

export const isGlobalSearchTab = (value: string): value is GlobalSearchTab =>
  SEARCH_TABS.includes(value as GlobalSearchTab);

export const globalSearchService = {
  async search(params: SearchParams): Promise<GlobalSearchResponse> {
    const query = normalizeQuery(params.query);
    const taskLimit = params.tab === 'all' ? params.limit : Math.max(params.limit, 20);
    const tasks: SearchTask[] = [
      ...(isTabRequested(params.tab, 'events') ? [{ tab: 'events' as const, run: () => searchEvents(query, taskLimit) }] : []),
      ...(isTabRequested(params.tab, 'news') ? [{ tab: 'news' as const, run: () => searchNews(query, taskLimit) }] : []),
      ...(isTabRequested(params.tab, 'djs') ? [{ tab: 'djs' as const, run: () => searchDJs(query, taskLimit) }] : []),
      ...(isTabRequested(params.tab, 'sets') ? [{ tab: 'sets' as const, run: () => searchSets(query, taskLimit) }] : []),
      ...(isTabRequested(params.tab, 'rankings') ? [{ tab: 'rankings' as const, run: () => searchRankings(query, taskLimit) }] : []),
      ...(isTabRequested(params.tab, 'ratings') ? [{ tab: 'ratings' as const, run: () => searchRatings(query, taskLimit) }] : []),
      ...(isTabRequested(params.tab, 'posts') ? [{ tab: 'posts' as const, run: () => searchPosts(query, taskLimit, params.userId) }] : []),
      ...(isTabRequested(params.tab, 'festivals') ? [{ tab: 'festivals' as const, run: () => searchFestivals(query, taskLimit) }] : []),
      ...(isTabRequested(params.tab, 'labels') ? [{ tab: 'labels' as const, run: () => searchLabels(query, taskLimit) }] : []),
      ...(isTabRequested(params.tab, 'genreTree') ? [{ tab: 'genreTree' as const, run: () => searchGenreTree(query, taskLimit) }] : []),
      ...(isTabRequested(params.tab, 'wiki') ? [{ tab: 'wiki' as const, run: () => searchWiki(query, taskLimit) }] : []),
      ...(isTabRequested(params.tab, 'peopleSquads')
        ? [{ tab: 'peopleSquads' as const, run: () => searchPeopleSquads(query, taskLimit, params.userId) }]
        : []),
    ];

    const settled = await Promise.allSettled(tasks.map((task) => task.run()));
    const partialErrors: GlobalSearchPartialError[] = [];
    const items: GlobalSearchItem[] = [];

    settled.forEach((result, index) => {
      const task = tasks[index];
      if (result.status === 'fulfilled') {
        items.push(...result.value);
        return;
      }
      partialErrors.push({
        tab: task.tab,
        message: result.reason instanceof Error ? result.reason.message : 'Search domain failed',
      });
    });

    const sortedItems = sortItems(items).slice(0, params.limit);
    const countsByTab = emptyCounts();
    for (const item of items) {
      countsByTab[itemTab(item.type)] += 1;
    }
    countsByTab.all = items.length;

    return {
      query,
      tab: params.tab,
      limit: params.limit,
      totalCount: items.length,
      items: sortedItems,
      countsByTab,
      partialErrors,
      generatedAt: new Date().toISOString(),
    };
  },
};
