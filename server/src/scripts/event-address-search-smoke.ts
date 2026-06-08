import 'dotenv/config';
import crypto from 'node:crypto';
import { PrismaClient } from '@prisma/client';
import { globalSearchService } from '../services/global-search.service';

const prisma = new PrismaClient();

const assert = (condition: boolean, message: string): void => {
  if (!condition) throw new Error(message);
};

type SearchFixture = {
  eventId: string;
  organizerId: string;
  searchUserId: string;
};

const createFixture = async (): Promise<SearchFixture> => {
  const suffix = `${Date.now()}_${crypto.randomInt(1000, 9999)}`;
  const organizer = await prisma.user.create({
    data: {
      username: `event_address_search_owner_${suffix}`,
      email: `event_address_search_owner_${suffix}@example.com`,
      passwordHash: 'event-address-search',
      displayName: `Event Address Search Owner ${suffix}`,
      displayNameNormalized: `event address search owner ${suffix}`,
      role: 'admin',
      isVerified: true,
      regionCode: 'CN',
      birthYear: 1990,
      ageBand: 'adult',
      ageDeclaredAt: new Date(),
    },
    select: { id: true },
  });

  const searchUser = await prisma.user.create({
    data: {
      username: `event_address_search_user_${suffix}`,
      email: `event_address_search_user_${suffix}@example.com`,
      passwordHash: 'event-address-search',
      displayName: `Event Address Search User ${suffix}`,
      displayNameNormalized: `event address search user ${suffix}`,
      role: 'user',
      isVerified: true,
      regionCode: 'CN',
      birthYear: 1992,
      ageBand: 'adult',
      ageDeclaredAt: new Date(),
    },
    select: { id: true },
  });

  const event = await prisma.event.create({
    data: {
      organizerId: organizer.id,
      slug: `event-address-search-${suffix}`,
      name: `Event Address Search ${suffix}`,
      city: 'Shanghai',
      country: 'China',
      startDate: new Date('2099-10-19T00:00:00.000Z'),
      endDate: new Date('2099-10-19T23:59:59.000Z'),
      timeZone: 'Asia/Shanghai',
      isCancelled: false,
      visibility: 'visible',
      isVerified: true,
      manualLocation: {
        detailAddressI18n: {
          zh: '徐汇滨江 88 号',
          en: '88 Xuhui Riverside',
        },
        formattedAddressI18n: {
          zh: '中国 · 上海 · 徐汇滨江 88 号',
          en: 'China · Shanghai · 88 Xuhui Riverside',
        },
      },
      locationPoint: {
        provider: 'amap',
        sourceMode: 'map_poi_click',
        poiId: 'B0FFG1AMPLE',
        adcode: '310104',
        location: {
          lng: 121.4542,
          lat: 31.1891,
        },
        nameI18n: {
          zh: '滨江仓库',
          en: 'Riverside Warehouse',
        },
        addressI18n: {
          zh: '徐汇滨江 88 号',
          en: '88 Xuhui Riverside',
        },
        formattedAddressI18n: {
          zh: '中国 · 上海 · 滨江仓库',
          en: 'China · Shanghai · Riverside Warehouse',
        },
        manualSetAddressI18n: {
          zh: '中国 · 上海 · 徐汇滨江 88 号',
          en: 'China · Shanghai · 88 Xuhui Riverside',
        },
        city: 'Shanghai',
        province: 'Shanghai',
        countryCode: 'CN',
      },
    },
    select: { id: true },
  });

  return {
    eventId: event.id,
    organizerId: organizer.id,
    searchUserId: searchUser.id,
  };
};

const cleanupFixture = async (fixture: SearchFixture | null): Promise<void> => {
  if (!fixture) return;
  await prisma.event.deleteMany({ where: { id: fixture.eventId } });
  await prisma.user.deleteMany({ where: { id: { in: [fixture.organizerId, fixture.searchUserId] } } });
};

const main = async (): Promise<void> => {
  let fixture: SearchFixture | null = null;
  try {
    fixture = await createFixture();
    const queries = [
      '徐汇滨江 88 号',
      '中国 · 上海 · 徐汇滨江 88 号',
      '中国 · 上海 · 滨江仓库',
      '滨江仓库',
    ];

    for (const query of queries) {
      const result = await globalSearchService.search({
        query,
        tab: 'events',
        limit: 10,
        userId: fixture.searchUserId,
        locale: 'zh',
      });
      const match = result.items.find((item) => item.type === 'event' && item.entityID === fixture?.eventId);
      assert(Boolean(match), `expected event search hit for query: ${query}`);
    }

    console.log('[event-address-search-smoke] ok', {
      eventId: fixture.eventId,
      queries,
    });
  } finally {
    await cleanupFixture(fixture);
  }
};

main()
  .catch((error) => {
    console.error('[event-address-search-smoke] failed', error);
    process.exitCode = 1;
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
