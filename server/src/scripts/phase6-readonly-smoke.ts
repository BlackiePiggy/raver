import 'dotenv/config';
import axios from 'axios';
import { PrismaClient } from '@prisma/client';

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

type SampleIds = {
  eventId: string;
  djId: string;
  postId: string;
  newsId: string;
  djSetId: string;
  ratingUnitId: string;
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

async function main(): Promise<void> {
  logStep('resolve sample ids');
  const sampleIds = await loadSampleIds();
  logStep('sample ids ready', sampleIds);

  const [health, eventDetail, djDetail, postDetail, newsDetail, djSetDetail, ratingUnitDetail, feed, newsFeed] = await Promise.all([
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

  const eventData = unwrapData<any>(eventDetail.data);
  const postData = unwrapData<any>(postDetail.data);
  const newsData = unwrapData<any>(newsDetail.data);
  const djSetData = unwrapData<any>(djSetDetail.data);
  const ratingUnitData = unwrapData<any>(ratingUnitDetail.data);
  const feedData = unwrapData<any>(feed.data);
  const newsFeedData = unwrapData<any>(newsFeed.data);
  const feedItems = extractList(feedData);
  const newsItems = extractList(newsFeedData);

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

  console.log('[phase6-readonly-smoke] all checks passed', sampleIds);
}

void main()
  .catch((error: unknown) => {
    console.error('[phase6-readonly-smoke] failed', error);
    process.exitCode = 1;
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
