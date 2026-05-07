import { PrismaClient } from '@prisma/client';
import { rebuildUserCheckinProjection } from './checkin-projection';

const DEFAULT_BATCH_SIZE = 50;
const MAX_RETRY_COUNT = 5;

export type CheckinProjectionWorkerReport = {
  scannedEvents: number;
  usersRebuilt: number;
  processedEvents: number;
  failedEvents: number;
  errors: string[];
};

const backoffMinutesForRetry = (retryCount: number): number => Math.min(60, Math.max(1, 2 ** retryCount));

export async function runCheckinProjectionWorkerOnce(
  prisma: PrismaClient,
  options: { batchSize?: number } = {}
): Promise<CheckinProjectionWorkerReport> {
  const batchSize = Math.max(1, Math.min(500, Math.floor(options.batchSize ?? DEFAULT_BATCH_SIZE)));
  const now = new Date();
  const events = await prisma.checkinOutboxEvent.findMany({
    where: {
      status: 'pending',
      availableAt: { lte: now },
    },
    orderBy: [{ createdAt: 'asc' }],
    take: batchSize,
    select: {
      id: true,
      userId: true,
      retryCount: true,
    },
  });

  const report: CheckinProjectionWorkerReport = {
    scannedEvents: events.length,
    usersRebuilt: 0,
    processedEvents: 0,
    failedEvents: 0,
    errors: [],
  };

  if (events.length === 0) {
    return report;
  }

  const eventIdsByUser = new Map<string, string[]>();
  for (const event of events) {
    const ids = eventIdsByUser.get(event.userId) ?? [];
    ids.push(event.id);
    eventIdsByUser.set(event.userId, ids);
  }

  for (const [userId, eventIds] of eventIdsByUser.entries()) {
    try {
      await rebuildUserCheckinProjection(prisma, userId);
      await prisma.checkinOutboxEvent.updateMany({
        where: { id: { in: eventIds } },
        data: {
          status: 'processed',
          processedAt: new Date(),
        },
      });
      report.usersRebuilt += 1;
      report.processedEvents += eventIds.length;
    } catch (error) {
      const message = error instanceof Error ? error.message : String(error);
      report.errors.push(`user=${userId}: ${message}`);

      const retryRows = events.filter((event) => eventIds.includes(event.id));
      for (const event of retryRows) {
        const nextRetryCount = event.retryCount + 1;
        const status = nextRetryCount >= MAX_RETRY_COUNT ? 'dead' : 'pending';
        const availableAt = new Date(Date.now() + backoffMinutesForRetry(nextRetryCount) * 60 * 1000);

        await prisma.checkinOutboxEvent.update({
          where: { id: event.id },
          data: {
            status,
            retryCount: nextRetryCount,
            availableAt,
          },
        });
      }

      report.failedEvents += eventIds.length;
    }
  }

  return report;
}
