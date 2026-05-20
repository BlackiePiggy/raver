import { Prisma } from '@prisma/client';

const normalizeGenreKey = (value: unknown): string => String(value || '').trim().toLowerCase();

export const normalizeGenrePreferenceKeys = (values: unknown): string[] => {
  if (!Array.isArray(values)) return [];
  const seen = new Set<string>();
  const result: string[] = [];
  for (const value of values) {
    const key = normalizeGenreKey(value);
    if (!key || seen.has(key)) continue;
    seen.add(key);
    result.push(key);
  }
  return result;
};

export const syncUserGenrePreferences = async (
  tx: Prisma.TransactionClient,
  userId: string,
  genreKeys: string[]
): Promise<void> => {
  await tx.userGenrePreference.deleteMany({
    where: { userId },
  });
  const normalized = normalizeGenrePreferenceKeys(genreKeys);
  if (normalized.length === 0) return;
  await tx.userGenrePreference.createMany({
    data: normalized.map((genreKey, index) => ({
      userId,
      genreKey,
      sortOrder: index + 1,
    })),
    skipDuplicates: true,
  });
};

export const resolveUserGenrePreferences = async (
  db: Prisma.TransactionClient | Prisma.DefaultPrismaClient,
  userId: string
): Promise<string[]> => {
  const rows = await db.userGenrePreference.findMany({
    where: { userId },
    orderBy: [{ sortOrder: 'asc' }, { createdAt: 'asc' }, { id: 'asc' }],
    select: { genreKey: true },
  });
  return rows.map((row) => row.genreKey);
};

export const resolveUserGenrePreferenceMap = async (
  db: Prisma.TransactionClient | Prisma.DefaultPrismaClient,
  userIds: string[]
): Promise<Map<string, string[]>> => {
  const uniqueUserIds = Array.from(new Set(userIds.map((id) => id.trim()).filter(Boolean)));
  if (uniqueUserIds.length === 0) return new Map();

  const rows = await db.userGenrePreference.findMany({
    where: { userId: { in: uniqueUserIds } },
    orderBy: [{ sortOrder: 'asc' }, { createdAt: 'asc' }, { id: 'asc' }],
    select: { userId: true, genreKey: true },
  });

  const result = new Map<string, string[]>();
  for (const userId of uniqueUserIds) {
    result.set(userId, []);
  }
  for (const row of rows) {
    const bucket = result.get(row.userId) || [];
    bucket.push(row.genreKey);
    result.set(row.userId, bucket);
  }
  return result;
};
