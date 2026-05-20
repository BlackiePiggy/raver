import 'dotenv/config';
import crypto from 'crypto';
import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

const BENCHMARK_TAG = 'benchmark-dj-events';
const DEFAULT_COUNT = 200;

const assert = (condition: boolean, message: string): void => {
  if (!condition) throw new Error(message);
};

const log = (step: string, detail?: Record<string, unknown>): void => {
  console.log('[seed-dj-event-benchmark]', step, detail || {});
};

const parseArgs = (argv: string[]): Record<string, string | boolean> => {
  const parsed: Record<string, string | boolean> = {};
  for (let index = 0; index < argv.length; index += 1) {
    const current = argv[index];
    if (!current.startsWith('--')) continue;
    const key = current.slice(2);
    const next = argv[index + 1];
    if (!next || next.startsWith('--')) {
      parsed[key] = true;
      continue;
    }
    parsed[key] = next;
    index += 1;
  }
  return parsed;
};

const slugify = (value: string): string =>
  value
    .trim()
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '')
    .slice(0, 80);

const chunk = <T>(items: T[], size: number): T[][] => {
  const groups: T[][] = [];
  for (let index = 0; index < items.length; index += size) {
    groups.push(items.slice(index, index + size));
  }
  return groups;
};

async function main(): Promise<void> {
  const args = parseArgs(process.argv.slice(2));
  const count = Number(args.count || DEFAULT_COUNT);
  const djName = String(args.name || `Benchmark DJ ${count}`);
  const djSlug = String(args.slug || slugify(djName));
  const city = String(args.city || 'Benchmark City');
  const country = String(args.country || 'Benchmark Land');
  const timeZone = String(args.timezone || 'UTC');
  const baseDate = new Date(String(args['base-date'] || '2023-01-01T20:00:00.000Z'));

  assert(Number.isFinite(count) && count > 0 && count <= 5000, 'count must be between 1 and 5000');
  assert(!Number.isNaN(baseDate.getTime()), 'base-date must be a valid ISO datetime');

  log('start', { count, djName, djSlug, city, country, timeZone, baseDate: baseDate.toISOString() });

  const dj = await prisma.dJ.upsert({
    where: { slug: djSlug },
    update: {
      name: djName,
      country,
      isVerified: false,
    },
    create: {
      id: crypto.randomUUID(),
      name: djName,
      slug: djSlug,
      country,
      isVerified: false,
      aliases: [],
      genres: [],
    },
    select: { id: true, name: true, slug: true },
  });

  const eventSlugPrefix = `${djSlug}-benchmark-event-`;
  const existingEvents = await prisma.event.findMany({
    where: {
      slug: {
        startsWith: eventSlugPrefix,
      },
    },
    select: { id: true },
  });

  if (existingEvents.length > 0) {
    log('cleanup existing benchmark events', { count: existingEvents.length });
    await prisma.event.deleteMany({
      where: {
        id: { in: existingEvents.map((event) => event.id) },
      },
    });
  }

  const now = new Date();
  const events = Array.from({ length: count }, (_, index) => {
    const eventId = crypto.randomUUID();
    const canonicalArtistId = crypto.randomUUID();
    const startDate = new Date(baseDate.getTime() - index * 24 * 60 * 60 * 1000);
    const endDate = new Date(startDate.getTime() + 4 * 60 * 60 * 1000);
    const eventNumber = String(index + 1).padStart(3, '0');
    return {
      event: {
        id: eventId,
        name: `${djName} Benchmark Event ${eventNumber}`,
        slug: `${eventSlugPrefix}${eventNumber}`,
        description: `${BENCHMARK_TAG} generated event ${eventNumber}`,
        city,
        country,
        timeZone,
        startDate,
        endDate,
        startTime: '20:00:00',
        endTime: '23:59:59',
        status: endDate < now ? 'completed' : 'upcoming',
        organizerName: BENCHMARK_TAG,
      },
      canonicalArtist: {
        id: canonicalArtistId,
        eventId,
        displayName: djName,
        normalizedName: djName.trim().toLowerCase(),
        actType: 'solo',
        primaryDjId: dj.id,
        billingOrder: 1,
        sourceType: BENCHMARK_TAG,
        isTimetableOnly: false,
      },
      canonicalMember: {
        id: crypto.randomUUID(),
        eventArtistId: canonicalArtistId,
        djId: dj.id,
        memberNameSnapshot: djName,
        memberOrder: 1,
        role: 'performer',
      },
    };
  });

  for (const eventChunk of chunk(events.map((item) => item.event), 200)) {
    await prisma.event.createMany({ data: eventChunk });
  }
  for (const artistChunk of chunk(events.map((item) => item.canonicalArtist), 500)) {
    await prisma.eventArtist.createMany({ data: artistChunk });
  }
  for (const memberChunk of chunk(events.map((item) => item.canonicalMember), 500)) {
    await prisma.eventArtistMember.createMany({ data: memberChunk });
  }

  log('done', {
    djId: dj.id,
    eventCount: events.length,
    eventSlugPrefix,
  });
}

void main()
  .catch((error: unknown) => {
    console.error('[seed-dj-event-benchmark] failed', error);
    process.exitCode = 1;
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
