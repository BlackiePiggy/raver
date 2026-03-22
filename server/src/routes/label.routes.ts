import { PrismaClient, Prisma } from '@prisma/client';
import { Router, Request, Response } from 'express';

const router: Router = Router();
const prisma = new PrismaClient();

const normalizePage = (value: unknown, fallback = 1): number => {
  const parsed = Number(value);
  if (!Number.isFinite(parsed)) return fallback;
  return Math.max(1, Math.floor(parsed));
};

const normalizeLimit = (value: unknown, fallback = 20, max = 100): number => {
  const parsed = Number(value);
  if (!Number.isFinite(parsed)) return fallback;
  return Math.max(1, Math.min(max, Math.floor(parsed)));
};

type LabelSortBy = 'soundcloudFollowers' | 'likes' | 'name' | 'nation' | 'latestRelease' | 'createdAt';

const parseSortBy = (value: unknown): LabelSortBy => {
  if (value === 'likes') return 'likes';
  if (value === 'name') return 'name';
  if (value === 'nation') return 'nation';
  if (value === 'latestRelease') return 'latestRelease';
  if (value === 'createdAt') return 'createdAt';
  return 'soundcloudFollowers';
};

const parseSortOrder = (value: unknown, fallback: Prisma.SortOrder): Prisma.SortOrder => {
  if (value === 'asc' || value === 'desc') {
    return value;
  }
  return fallback;
};

const parseMultiFilterValues = (value: unknown): string[] => {
  const normalized = Array.isArray(value) ? value : [value];
  return normalized
    .flatMap((item) => (typeof item === 'string' ? item.split(',') : []))
    .map((item) => item.trim())
    .filter((item) => item.length > 0);
};

router.get('/', async (req: Request, res: Response): Promise<void> => {
  try {
    const page = normalizePage(req.query.page);
    const limit = normalizeLimit(req.query.limit, 20, 100);
    const sortBy = parseSortBy(req.query.sortBy);

    const defaultOrder: Prisma.SortOrder = sortBy === 'name' || sortBy === 'nation' ? 'asc' : 'desc';
    const order = parseSortOrder(req.query.order, defaultOrder);

    const search = typeof req.query.search === 'string' ? req.query.search.trim() : '';
    const nationFilters = Array.from(
      new Set([
        ...parseMultiFilterValues(req.query.nation),
        ...parseMultiFilterValues(req.query.nations),
      ])
    );
    const genreFilters = Array.from(
      new Set([
        ...parseMultiFilterValues(req.query.genre),
        ...parseMultiFilterValues(req.query.genres),
      ])
    );

    const andConditions: Prisma.LabelWhereInput[] = [];
    if (search) {
      andConditions.push({
        OR: [
          { name: { contains: search, mode: 'insensitive' } },
          { introduction: { contains: search, mode: 'insensitive' } },
          { genresPreview: { contains: search, mode: 'insensitive' } },
        ],
      });
    }

    if (nationFilters.length > 0) {
      andConditions.push({
        OR: nationFilters.map((nation) => ({
          nation: { equals: nation, mode: 'insensitive' },
        })),
      });
    }

    if (genreFilters.length > 0) {
      for (const genre of genreFilters) {
        andConditions.push({ genres: { has: genre } });
      }
    }

    const where: Prisma.LabelWhereInput =
      andConditions.length > 0
        ? { AND: andConditions }
        : {};

    const orderBy: Prisma.LabelOrderByWithRelationInput =
      sortBy === 'soundcloudFollowers'
        ? { soundcloudFollowers: order }
        : sortBy === 'likes'
          ? { likes: order }
          : sortBy === 'nation'
            ? { nation: order }
            : sortBy === 'latestRelease'
              ? { latestReleaseListing: order }
              : sortBy === 'createdAt'
                ? { createdAt: order }
                : { name: order };

    const [rows, total] = await Promise.all([
      prisma.label.findMany({
        where,
        orderBy,
        skip: (page - 1) * limit,
        take: limit,
      }),
      prisma.label.count({ where }),
    ]);

    const founderDjIds = Array.from(
      new Set(
        rows
          .map((item) => item.founderDjId)
          .filter((id): id is string => Boolean(id))
      )
    );
    const founderDjs = founderDjIds.length > 0
      ? await prisma.dJ.findMany({
          where: { id: { in: founderDjIds } },
        })
      : [];
    const founderDjById = new Map(founderDjs.map((item: { id: string }) => [item.id, item]));
    const hydratedRows = rows.map((item) => ({
      ...item,
      founderDj: item.founderDjId ? founderDjById.get(item.founderDjId) ?? null : null,
    }));

    res.json({
      labels: hydratedRows,
      pagination: {
        page,
        limit,
        total,
        totalPages: Math.max(1, Math.ceil(total / limit)),
      },
    });
  } catch (error) {
    console.error('Get labels error:', error);
    res.status(500).json({ error: 'Failed to fetch labels' });
  }
});

router.get('/:id', async (req: Request, res: Response): Promise<void> => {
  try {
    const rawId = req.params.id;
    const id = Array.isArray(rawId) ? rawId[0] : rawId;
    if (!id) {
      res.status(400).json({ error: 'Invalid label id' });
      return;
    }

    const label = await prisma.label.findFirst({
      where: {
        OR: [
          { id },
          { slug: id },
          { profileSlug: id },
        ],
      },
    });

    if (!label) {
      res.status(404).json({ error: 'Label not found' });
      return;
    }

    let founderDj = null;
    if (label.founderDjId) {
      founderDj = await prisma.dJ.findUnique({
        where: { id: label.founderDjId },
      });
    }

    res.json({
      ...label,
      founderDj,
    });
  } catch (error) {
    console.error('Get label detail error:', error);
    res.status(500).json({ error: 'Failed to fetch label detail' });
  }
});

export default router;
