import 'dotenv/config';
import axios from 'axios';
import crypto from 'node:crypto';
import { Prisma, PrismaClient } from '@prisma/client';
import { globalSearchService } from '../services/global-search.service';

const prisma = new PrismaClient();

const baseUrl = (process.env.PHASE6_READONLY_BASE_URL || 'http://127.0.0.1:3901/v1').replace(/\/+$/, '');
const requestTimeoutMs = Number(process.env.PHASE6_READONLY_TIMEOUT_MS || '15000');
const accessToken = String(process.env.PHASE6_READONLY_ACCESS_TOKEN || '').trim();

const assert = (condition: boolean, message: string): void => {
  if (!condition) throw new Error(message);
};

const logStep = (step: string, detail?: Record<string, unknown>): void => {
  console.log('[phase6-event-address-smoke]', step, detail || {});
};

const request = async <T>(
  method: 'GET' | 'POST',
  path: string,
  body?: unknown
): Promise<{ status: number; data: T; headers: Record<string, unknown> }> => {
  const response = await axios.request<T>({
    method,
    url: `${baseUrl}${path.startsWith('/') ? path : `/${path}`}`,
    timeout: requestTimeoutMs,
    data: body,
    headers: {
      Connection: 'close',
      'Content-Type': 'application/json',
      ...(accessToken ? { Authorization: `Bearer ${accessToken}` } : {}),
    },
    maxRedirects: 0,
    validateStatus: () => true,
  });
  return {
    status: response.status,
    data: response.data,
    headers: response.headers as Record<string, unknown>,
  };
};

const unwrapData = <T>(payload: T | { data?: T } | null | undefined): T => {
  if (payload && typeof payload === 'object' && 'data' in payload) {
    return (payload as { data: T }).data;
  }
  return payload as T;
};

const extractList = (payload: unknown): unknown[] | null => {
  if (Array.isArray(payload)) return payload;
  if (!payload || typeof payload !== 'object') return null;
  const record = payload as Record<string, unknown>;
  if (Array.isArray(record.items)) return record.items;
  return null;
};

const readDataEnvelope = (payload: unknown): unknown => {
  if (!payload || typeof payload !== 'object' || Array.isArray(payload)) return payload;
  const record = payload as Record<string, unknown>;
  return record.data ?? payload;
};

type AddressFixture = {
  eventId: string;
  organizerId: string;
  searchUserId: string;
  slug: string;
  activityAddress: string;
  venueDisplayAddress: string;
  venueDisplayAddressWithoutLocationPoint: string;
};

type ShareLinkResolveBody = {
  code?: string;
  shortUrl?: string;
};

const createAddressFixture = async (): Promise<AddressFixture> => {
  const suffix = `${Date.now()}_${crypto.randomInt(1000, 9999)}`;
  const organizer = await prisma.user.create({
    data: {
      username: `phase6_event_address_${suffix}`,
      email: `phase6_event_address_${suffix}@example.com`,
      passwordHash: 'phase6-event-address',
      displayName: `Phase6 Event Address ${suffix}`,
      displayNameNormalized: `phase6 event address ${suffix}`,
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
      username: `phase6_event_search_${suffix}`,
      email: `phase6_event_search_${suffix}@example.com`,
      passwordHash: 'phase6-event-address',
      displayName: `Phase6 Event Search ${suffix}`,
      displayNameNormalized: `phase6 event search ${suffix}`,
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
      slug: `phase6-event-address-${suffix}`,
      name: `Phase6 Event Address ${suffix}`,
      city: 'Shanghai',
      country: 'China',
      startDate: new Date('2099-09-19T00:00:00.000Z'),
      endDate: new Date('2099-09-19T23:59:59.000Z'),
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
        selectedAt: new Date('2099-09-01T00:00:00.000Z').toISOString(),
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
    select: {
      id: true,
      slug: true,
    },
  });

  return {
    eventId: event.id,
    organizerId: organizer.id,
    searchUserId: searchUser.id,
    slug: event.slug,
    activityAddress: '中国 · 上海 · 徐汇滨江 88 号',
    venueDisplayAddress: '中国 · 上海 · 徐汇滨江 88 号',
    venueDisplayAddressWithoutLocationPoint: '中国 · 上海 · 徐汇滨江 88 号',
  };
};

const cleanupAddressFixture = async (fixture: AddressFixture | null): Promise<void> => {
  if (!fixture) return;
  await prisma.event.deleteMany({
    where: { id: fixture.eventId },
  });
  await prisma.user.deleteMany({
    where: { id: { in: [fixture.organizerId, fixture.searchUserId] } },
  });
};

async function main(): Promise<void> {
  let fixture: AddressFixture | null = null;

  try {
    fixture = await createAddressFixture();
    const ensuredFixture = fixture;
    logStep('address fixture ready', ensuredFixture);

    const health = await axios.get(`${baseUrl.replace(/\/v1$/, '')}/health`, {
      timeout: requestTimeoutMs,
      headers: { Connection: 'close' },
      validateStatus: () => true,
    });
    assert(health.status === 200, `health expected 200 got ${health.status}`);

    const eventDetail = await request<any>('GET', `/events/${ensuredFixture.eventId}`);
    assert(eventDetail.status === 200, `event detail expected 200 got ${eventDetail.status}`);
    const eventData = unwrapData<any>(eventDetail.data);
    assert(eventData.activityAddress === ensuredFixture.activityAddress, 'event detail activityAddress should come from manualLocation.formattedAddressI18n');
    assert(eventData.venueDisplayAddress === ensuredFixture.venueDisplayAddress, 'event detail venueDisplayAddress should prefer locationPoint.manualSetAddressI18n');

    const eventList = await request<any>('GET', `/events?search=${encodeURIComponent(ensuredFixture.slug)}&status=upcoming&limit=20`);
    assert(eventList.status === 200, `event list expected 200 got ${eventList.status}`);
    const eventListItems = extractList(readDataEnvelope(eventList.data));
    assert(Array.isArray(eventListItems), 'event list items missing');
    const ensuredEventListItems = Array.isArray(eventListItems) ? eventListItems : [];
    const listMatch = ensuredEventListItems.find((item) => (
      item
      && typeof item === 'object'
      && (item as { id?: string }).id === ensuredFixture.eventId
    )) as Record<string, unknown> | undefined;
    assert(listMatch?.activityAddress === ensuredFixture.activityAddress, 'event list activityAddress should come from manualLocation.formattedAddressI18n');
    assert(listMatch?.venueDisplayAddress === ensuredFixture.venueDisplayAddress, 'event list venueDisplayAddress should prefer locationPoint.manualSetAddressI18n');

    const catalogSummary = await request<any>('GET', `/events/catalog-summary?search=${encodeURIComponent(ensuredFixture.slug)}&status=all&limit=20&refresh=1`);
    assert(catalogSummary.status === 200, `catalog summary expected 200 got ${catalogSummary.status}`);
    const catalogItems = extractList(readDataEnvelope(catalogSummary.data));
    assert(Array.isArray(catalogItems), 'catalog summary items missing');
    const ensuredCatalogItems = Array.isArray(catalogItems) ? catalogItems : [];
    const catalogMatch = ensuredCatalogItems.find((item) => (
      item
      && typeof item === 'object'
      && (item as { id?: string }).id === ensuredFixture.eventId
    )) as Record<string, unknown> | undefined;
    assert(catalogMatch?.activityAddress === ensuredFixture.activityAddress, 'catalog summary activityAddress should come from manualLocation.formattedAddressI18n');
    assert(catalogMatch?.venueDisplayAddress === ensuredFixture.venueDisplayAddress, 'catalog summary venueDisplayAddress should prefer locationPoint.manualSetAddressI18n');

    const searchQueries = [
      '徐汇滨江 88 号',
      '中国 · 上海 · 徐汇滨江 88 号',
      '中国 · 上海 · 滨江仓库',
      '滨江仓库',
    ];
    for (const query of searchQueries) {
      const searchResult = await globalSearchService.search({
        query,
        tab: 'events',
        limit: 10,
        userId: ensuredFixture.searchUserId,
        locale: 'zh',
      });
      const searchMatch = searchResult.items.find((item) => (
        item.type === 'event' && item.entityID === ensuredFixture.eventId
      ));
      assert(Boolean(searchMatch), `global search should return fixture event for query: ${query}`);
    }

    const shareResolve = await request<ShareLinkResolveBody>('POST', '/share-links/resolve', {
      targetType: 'event',
      targetId: ensuredFixture.eventId,
      channel: 'smoke',
      campaign: 'event_address_smoke',
      preferPermanent: true,
    });
    assert(shareResolve.status === 200, `share resolve expected 200 got ${shareResolve.status}`);
    assert(Boolean(shareResolve.data.code), 'share resolve should return code');
    assert(Boolean(shareResolve.data.shortUrl?.includes('/s/')), 'share resolve should return shortUrl');

    await prisma.event.update({
      where: { id: ensuredFixture.eventId },
      data: {
        locationPoint: Prisma.JsonNull,
      },
    });

    const fallbackDetail = await request<any>('GET', `/events/${ensuredFixture.eventId}`);
    assert(fallbackDetail.status === 200, `fallback detail expected 200 got ${fallbackDetail.status}`);
    const fallbackEventData = unwrapData<any>(fallbackDetail.data);
    assert(
      fallbackEventData.venueDisplayAddress === ensuredFixture.venueDisplayAddressWithoutLocationPoint,
      'event detail venueDisplayAddress should fall back to manualLocation when locationPoint is absent'
    );

    console.log('[phase6-event-address-smoke] all checks passed', {
      eventId: ensuredFixture.eventId,
      shareCode: shareResolve.data.code,
    });
  } finally {
    await cleanupAddressFixture(fixture);
  }
}

void main()
  .catch((error: unknown) => {
    console.error('[phase6-event-address-smoke] failed', error);
    process.exitCode = 1;
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
