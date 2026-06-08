import 'dotenv/config';
import axios from 'axios';
import crypto from 'node:crypto';
import { Prisma, PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

const baseUrl = (process.env.PHASE6_READONLY_BASE_URL || 'http://127.0.0.1:3901/v1').replace(/\/+$/, '');
const requestTimeoutMs = Number(process.env.PHASE6_READONLY_TIMEOUT_MS || '15000');
const accessToken = String(process.env.PHASE6_READONLY_ACCESS_TOKEN || '').trim();

const assert = (condition: boolean, message: string): void => {
  if (!condition) throw new Error(message);
};

const logStep = (step: string, detail?: Record<string, unknown>): void => {
  console.log('[phase6-readonly-smoke]', step, detail || {});
};

const request = async <T>(path: string): Promise<{ status: number; data: T }> => {
  const response = await axios.request<T>({
    method: 'GET',
    url: `${baseUrl}${path.startsWith('/') ? path : `/${path}`}`,
    timeout: requestTimeoutMs,
    headers: {
      Connection: 'close',
      ...(accessToken ? { Authorization: `Bearer ${accessToken}` } : {}),
    },
    validateStatus: () => true,
  });
  return { status: response.status, data: response.data };
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
  if (Array.isArray(record.posts)) return record.posts;
  if (Array.isArray(record.news)) return record.news;
  return null;
};

const readDataEnvelope = (payload: unknown): unknown => {
  if (!payload || typeof payload !== 'object' || Array.isArray(payload)) return payload;
  const record = payload as Record<string, unknown>;
  return record.data ?? payload;
};

type SampleIds = {
  eventId: string;
  djId: string;
  postId: string;
  newsId: string;
  djSetId: string;
  ratingUnitId: string;
};

type AddressFixture = {
  eventId: string;
  organizerId: string;
  slug: string;
  activityAddress: string;
  venueDisplayAddress: string;
  venueDisplayAddressWithoutLocationPoint: string;
};

const loadSampleIds = async (): Promise<SampleIds> => {
  const [eventRow, djRow, postRow, newsRow, djSetRow, ratingUnitRow] = await Promise.all([
    process.env.PHASE6_EVENT_ID
      ? Promise.resolve({ id: String(process.env.PHASE6_EVENT_ID) })
      : prisma.event.findFirst({
          orderBy: [{ startDate: 'desc' }, { createdAt: 'desc' }],
          select: { id: true },
        }),
    process.env.PHASE6_DJ_ID
      ? Promise.resolve({ id: String(process.env.PHASE6_DJ_ID) })
      : prisma.dJ.findFirst({
          orderBy: [{ followerCount: 'desc' }, { createdAt: 'desc' }],
          select: { id: true },
        }),
    process.env.PHASE6_POST_ID
      ? Promise.resolve({ id: String(process.env.PHASE6_POST_ID) })
      : prisma.post.findFirst({
          where: { visibility: 'public', squadId: null },
          orderBy: [{ createdAt: 'desc' }],
          select: { id: true },
        }),
    process.env.PHASE6_NEWS_ID
      ? Promise.resolve({ id: String(process.env.PHASE6_NEWS_ID) })
      : prisma.newsArticle.findFirst({
          orderBy: [{ publishedAt: 'desc' }, { createdAt: 'desc' }],
          select: { id: true },
        }),
    process.env.PHASE6_DJ_SET_ID
      ? Promise.resolve({ id: String(process.env.PHASE6_DJ_SET_ID) })
      : prisma.dJSet.findFirst({
          orderBy: [{ createdAt: 'desc' }],
          select: { id: true },
        }),
    process.env.PHASE6_RATING_UNIT_ID
      ? Promise.resolve({ id: String(process.env.PHASE6_RATING_UNIT_ID) })
      : prisma.ratingUnit.findFirst({
          orderBy: [{ createdAt: 'desc' }],
          select: { id: true },
        }),
  ]);

  assert(Boolean(eventRow?.id), 'missing sample event id');
  assert(Boolean(djRow?.id), 'missing sample dj id');
  assert(Boolean(postRow?.id), 'missing sample post id');
  assert(Boolean(newsRow?.id), 'missing sample news id');
  assert(Boolean(djSetRow?.id), 'missing sample dj set id');
  assert(Boolean(ratingUnitRow?.id), 'missing sample rating unit id');

  return {
    eventId: eventRow!.id,
    djId: djRow!.id,
    postId: postRow!.id,
    newsId: newsRow!.id,
    djSetId: djSetRow!.id,
    ratingUnitId: ratingUnitRow!.id,
  };
};

const createAddressFixture = async (): Promise<AddressFixture> => {
  const suffix = `${Date.now()}_${crypto.randomInt(1000, 9999)}`;
  const organizer = await prisma.user.create({
    data: {
      username: `phase6_address_${suffix}`,
      email: `phase6_address_${suffix}@example.com`,
      passwordHash: 'phase6-readonly',
      displayName: `Phase6 Address ${suffix}`,
      displayNameNormalized: `phase6 address ${suffix}`,
      role: 'admin',
      isVerified: true,
      regionCode: 'CN',
      birthYear: 1990,
      ageBand: 'adult',
      ageDeclaredAt: new Date(),
    },
    select: { id: true },
  });

  const event = await prisma.event.create({
    data: {
      organizerId: organizer.id,
      slug: `phase6-address-${suffix}`,
      name: `Phase6 Address Event ${suffix}`,
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
    where: { id: fixture.organizerId },
  });
};

async function main(): Promise<void> {
  logStep('resolve sample ids');
  const sampleIds = await loadSampleIds();
  logStep('sample ids ready', sampleIds);
  let addressFixture: AddressFixture | null = null;

  try {
    addressFixture = await createAddressFixture();
    const ensuredAddressFixture = addressFixture;
    logStep('address fixture ready', addressFixture);

    const [
      health,
      eventDetail,
      djDetail,
      postDetail,
      newsDetail,
      djSetDetail,
      ratingUnitDetail,
      feed,
      newsFeed,
      addressEventDetail,
      addressEventList,
      addressCatalogSummary,
    ] = await Promise.all([
      axios.get(`${baseUrl.replace(/\/v1$/, '')}/health`, {
        timeout: requestTimeoutMs,
        headers: {
          Connection: 'close',
        },
        validateStatus: () => true,
      }),
      request<any>(`/events/${sampleIds.eventId}`),
      request<any>(`/djs/${sampleIds.djId}`),
      request<any>(`/feed/posts/${sampleIds.postId}`),
      request<any>(`/news/${sampleIds.newsId}`),
      request<any>(`/dj-sets/${sampleIds.djSetId}`),
      request<any>(`/rating-units/${sampleIds.ratingUnitId}`),
      request<any>('/feed?limit=20'),
      request<any>('/news?limit=20'),
      request<any>(`/events/${addressFixture.eventId}`),
      request<any>(`/events?search=${encodeURIComponent(addressFixture.slug)}&status=upcoming&limit=20`),
      request<any>(`/events/catalog-summary?search=${encodeURIComponent(addressFixture.slug)}&status=all&limit=20&refresh=1`),
    ]);

    assert(health.status === 200, `health expected 200 got ${health.status}`);
    assert(eventDetail.status === 200, `event detail expected 200 got ${eventDetail.status}`);
    assert(djDetail.status === 200, `dj detail expected 200 got ${djDetail.status}`);
    assert(postDetail.status === 200, `post detail expected 200 got ${postDetail.status}`);
    assert(newsDetail.status === 200, `news detail expected 200 got ${newsDetail.status}`);
    assert(djSetDetail.status === 200, `dj set detail expected 200 got ${djSetDetail.status}`);
    assert(ratingUnitDetail.status === 200, `rating unit detail expected 200 got ${ratingUnitDetail.status}`);
    assert(feed.status === 200, `feed expected 200 got ${feed.status}`);
    assert(newsFeed.status === 200, `news feed expected 200 got ${newsFeed.status}`);
    assert(addressEventDetail.status === 200, `address event detail expected 200 got ${addressEventDetail.status}`);
    assert(addressEventList.status === 200, `address event list expected 200 got ${addressEventList.status}`);
    assert(addressCatalogSummary.status === 200, `address catalog summary expected 200 got ${addressCatalogSummary.status}`);

    const eventData = unwrapData<any>(eventDetail.data);
    const postData = unwrapData<any>(postDetail.data);
    const newsData = unwrapData<any>(newsDetail.data);
    const djSetData = unwrapData<any>(djSetDetail.data);
    const ratingUnitData = unwrapData<any>(ratingUnitDetail.data);
    const feedData = unwrapData<any>(feed.data);
    const newsFeedData = unwrapData<any>(newsFeed.data);
    const feedItems = extractList(feedData);
    const newsItems = extractList(newsFeedData);
    const addressEventData = unwrapData<any>(addressEventDetail.data);
    const addressEventListData = readDataEnvelope(addressEventList.data);
    const addressEventListItems = extractList(addressEventListData);
    const addressCatalogSummaryData = readDataEnvelope(addressCatalogSummary.data);
    const addressCatalogSummaryItems = extractList(addressCatalogSummaryData);

    assert(Array.isArray(eventData.lineupArtists), 'event detail lineupArtists missing');
    assert(Array.isArray(eventData.timetableSlots), 'event detail timetableSlots missing');
    assert(Array.isArray(postData.boundDjIDs), 'post detail boundDjIDs missing');
    assert(Array.isArray(postData.boundEventIDs), 'post detail boundEventIDs missing');
    assert(Array.isArray(newsData.boundDjIDs), 'news detail boundDjIDs missing');
    assert(Array.isArray(newsData.boundEventIDs), 'news detail boundEventIDs missing');
    assert(Array.isArray(djSetData.lineupDjs), 'dj set detail lineupDjs missing');
    assert(Array.isArray(ratingUnitData.linkedDJs), 'rating unit detail linkedDJs missing');
    assert(Array.isArray(feedItems), 'feed items missing');
    assert(Array.isArray(newsItems), 'news feed items missing');
    assert(Array.isArray(addressEventListItems), 'address event list items missing');
    assert(Array.isArray(addressCatalogSummaryItems), 'address catalog summary items missing');
    const ensuredAddressEventListItems = Array.isArray(addressEventListItems) ? addressEventListItems : [];
    const ensuredAddressCatalogSummaryItems = Array.isArray(addressCatalogSummaryItems) ? addressCatalogSummaryItems : [];

    const addressListMatch = ensuredAddressEventListItems.find((item) => (
      item
      && typeof item === 'object'
      && (item as { id?: string }).id === ensuredAddressFixture.eventId
    )) as Record<string, unknown> | undefined;
    const addressCatalogMatch = ensuredAddressCatalogSummaryItems.find((item) => (
      item
      && typeof item === 'object'
      && (item as { id?: string }).id === ensuredAddressFixture.eventId
    )) as Record<string, unknown> | undefined;

    assert(addressEventData.activityAddress === ensuredAddressFixture.activityAddress, 'event detail activityAddress should come from manualLocation.formattedAddressI18n');
    assert(addressEventData.venueDisplayAddress === ensuredAddressFixture.venueDisplayAddress, 'event detail venueDisplayAddress should prefer locationPoint.manualSetAddressI18n');
    assert(addressListMatch?.activityAddress === ensuredAddressFixture.activityAddress, 'event list activityAddress should come from manualLocation.formattedAddressI18n');
    assert(addressListMatch?.venueDisplayAddress === ensuredAddressFixture.venueDisplayAddress, 'event list venueDisplayAddress should prefer locationPoint.manualSetAddressI18n');
    assert(addressCatalogMatch?.activityAddress === ensuredAddressFixture.activityAddress, 'catalog summary activityAddress should come from manualLocation.formattedAddressI18n');
    assert(addressCatalogMatch?.venueDisplayAddress === ensuredAddressFixture.venueDisplayAddress, 'catalog summary venueDisplayAddress should prefer locationPoint.manualSetAddressI18n');

    await prisma.event.update({
      where: { id: ensuredAddressFixture.eventId },
      data: {
        locationPoint: Prisma.JsonNull,
      },
    });

    const fallbackDetail = await request<any>(`/events/${ensuredAddressFixture.eventId}`);
    assert(fallbackDetail.status === 200, `address fallback detail expected 200 got ${fallbackDetail.status}`);
    const fallbackEventData = unwrapData<any>(fallbackDetail.data);
    assert(
      fallbackEventData.venueDisplayAddress === ensuredAddressFixture.venueDisplayAddressWithoutLocationPoint,
      'event detail venueDisplayAddress should fall back to manualLocation when locationPoint is absent'
    );

    console.log('[phase6-readonly-smoke] all checks passed', sampleIds);
  } finally {
    await cleanupAddressFixture(addressFixture);
  }
}

void main()
  .catch((error: unknown) => {
    console.error('[phase6-readonly-smoke] failed', error);
    process.exitCode = 1;
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
