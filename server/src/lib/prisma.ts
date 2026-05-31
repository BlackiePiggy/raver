import { PrismaClient } from '@prisma/client';

const globalForPrisma = globalThis as unknown as {
  __raverPrisma?: PrismaClient;
};

export const prisma =
  globalForPrisma.__raverPrisma ??
  new PrismaClient({
    log:
      process.env.PRISMA_QUERY_LOG === 'true'
        ? ['query', 'warn', 'error']
        : ['warn', 'error'],
  });

if (process.env.NODE_ENV !== 'production') {
  globalForPrisma.__raverPrisma = prisma;
}
