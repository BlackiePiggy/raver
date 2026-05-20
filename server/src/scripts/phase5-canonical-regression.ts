import 'dotenv/config';
import axios, { type Method } from 'axios';
import crypto from 'crypto';
import { PrismaClient } from '@prisma/client';
import { generateToken, hashPassword } from '../utils/auth';

const prisma = new PrismaClient();

const baseUrl = (process.env.PHASE5_REGRESSION_BASE_URL || 'http://127.0.0.1:3901').replace(/\/+$/, '');
const requestTimeoutMs = Number(process.env.PHASE5_REGRESSION_TIMEOUT_MS || '15000');

const assert = (condition: boolean, message: string): void => {
  if (!condition) throw new Error(message);
};

const logStep = (step: string, detail?: Record<string, unknown>): void => {
  console.log('[phase5-canonical-regression]', step, detail || {});
};

const request = async <T>(
  method: Method,
  path: string,
  body: unknown,
  accessToken?: string
): Promise<{ status: number; data: T }> => {
  const hasBody = body !== null && body !== undefined && method.toUpperCase() !== 'GET';
  const response = await axios.request<T>({
    method,
    url: `${baseUrl}${path.startsWith('/') ? path : `/${path}`}`,
    ...(hasBody ? { data: body } : {}),
    timeout: requestTimeoutMs,
    headers: {
      Connection: 'close',
      ...(hasBody ? { 'Content-Type': 'application/json' } : {}),
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

const main = async (): Promise<void> => {
  const suffix = `${Date.now()}_${crypto.randomInt(1000, 9999)}`;
  const username = `phase5_admin_${suffix}`;
  const email = `${username}@example.com`;
  const passwordHash = await hashPassword('Passw0rd!');
  const createdIds: Record<string, string[]> = {
    users: [],
    djs: [],
    events: [],
    posts: [],
    news: [],
    djSets: [],
    ratingEvents: [],
    ratingUnits: [],
  };

  try {
    logStep('seed admin user');
    const adminUser = await prisma.user.create({
      data: {
        username,
        email,
        passwordHash,
        displayName: username,
        displayNameNormalized: username.toLowerCase(),
        role: 'admin',
        isVerified: true,
        regionCode: 'JP',
        birthYear: 1990,
        ageBand: 'adult',
        ageDeclaredAt: new Date(),
      },
      select: { id: true, email: true, role: true },
    });
    createdIds.users.push(adminUser.id);
    const token = generateToken({ userId: adminUser.id, email: adminUser.email, role: adminUser.role });

    logStep('create djs');
    const dj1Slug = `phase5-dj-1-${suffix}`;
    const dj2Slug = `phase5-dj-2-${suffix}`;
    const dj1 = await request<{ id: string }>('POST', '/api/djs', {
      name: `Phase5 DJ One ${suffix}`,
      slug: dj1Slug,
      country: 'JP',
    }, token);
    assert(dj1.status === 201, `create dj1 expected 201 got ${dj1.status}`);
    createdIds.djs.push((dj1.data as any).id);

    const dj2 = await request<{ id: string }>('POST', '/api/djs', {
      name: `Phase5 DJ Two ${suffix}`,
      slug: dj2Slug,
      country: 'JP',
    }, token);
    assert(dj2.status === 201, `create dj2 expected 201 got ${dj2.status}`);
    createdIds.djs.push((dj2.data as any).id);

    logStep('event create/detail/lineup/timetable');
    const eventCreate = await request<any>('POST', '/api/events', {
      name: `Phase5 Event ${suffix}`,
      slug: `phase5-event-${suffix}`,
      description: 'phase5 regression event',
      city: 'Tokyo',
      country: 'Japan',
      startDate: '2026-06-01',
      endDate: '2026-06-02',
      timeZone: 'Asia/Tokyo',
      lineupArtists: [
        {
          djId: (dj1.data as any).id,
          djIds: [(dj1.data as any).id],
          djName: `Phase5 DJ One ${suffix}`,
          sortOrder: 1,
        },
      ],
      lineupSlots: [
        {
          djId: (dj1.data as any).id,
          djIds: [(dj1.data as any).id],
          djName: `Phase5 DJ One ${suffix}`,
          stageName: 'Main Stage',
          sortOrder: 1,
          festivalDayIndex: 1,
          startTime: '2026-06-01T18:00:00+09:00',
          endTime: '2026-06-01T19:00:00+09:00',
        },
      ],
    }, token);
    assert(eventCreate.status === 201, `create event expected 201 got ${eventCreate.status}`);
    const createdEvent = unwrapData<any>(eventCreate.data);
    const eventId = createdEvent.id;
    createdIds.events.push(eventId);

    const eventDetail = await request<any>('GET', `/v1/events/${eventId}`, null, token);
    assert(eventDetail.status === 200, `event detail expected 200 got ${eventDetail.status}`);
    const eventDetailData = unwrapData<any>(eventDetail.data);
    assert(Array.isArray(eventDetailData.lineupArtists), 'event detail lineupArtists missing');
    assert(Array.isArray(eventDetailData.timetableSlots), 'event detail timetableSlots missing');

    const lineupAdd = await request<any>('POST', `/api/events/${eventId}/lineup`, {
      djId: (dj2.data as any).id,
      djIds: [(dj2.data as any).id],
      djName: `Phase5 DJ Two ${suffix}`,
      sortOrder: 2,
    }, token);
    assert(lineupAdd.status === 201, `lineup add expected 201 got ${lineupAdd.status}`);

    const timetableAdd = await request<any>('POST', `/api/events/${eventId}/timetable`, {
      djId: (dj2.data as any).id,
      djIds: [(dj2.data as any).id],
      djName: `Phase5 DJ Two ${suffix}`,
      stageName: 'Second Stage',
      sortOrder: 2,
      festivalDayIndex: 1,
      startTime: '2026-06-01T19:00:00+09:00',
      endTime: '2026-06-01T20:00:00+09:00',
    }, token);
    assert(timetableAdd.status === 201, `timetable add expected 201 got ${timetableAdd.status}`);

    const lineupGet = await request<any>('GET', `/v1/events/${eventId}/lineup`, null, token);
    const timetableGet = await request<any>('GET', `/v1/events/${eventId}/timetable`, null, token);
    assert(lineupGet.status === 200, `lineup get expected 200 got ${lineupGet.status}`);
    assert(timetableGet.status === 200, `timetable get expected 200 got ${timetableGet.status}`);
    assert((unwrapData<any>(lineupGet.data).items || []).length >= 2, 'lineup canonical items not updated');
    assert((unwrapData<any>(timetableGet.data).items || []).length >= 2, 'timetable canonical items not updated');

    logStep('dj detail/events');
    const djDetail = await request<any>('GET', `/v1/djs/${(dj1.data as any).id}`, null, token);
    const djEvents = await request<any>('GET', `/v1/djs/${(dj1.data as any).id}/events`, null, token);
    assert(djDetail.status === 200, `dj detail expected 200 got ${djDetail.status}`);
    assert(djEvents.status === 200, `dj events expected 200 got ${djEvents.status}`);

    logStep('post create/update/detail/list/feed');
    const postCreate = await request<any>('POST', '/v1/feed/posts', {
      content: `phase5 post ${suffix}`,
      boundDjIDs: [(dj1.data as any).id, (dj2.data as any).id],
      boundEventIDs: [eventId],
    }, token);
    assert(postCreate.status === 201, `post create expected 201 got ${postCreate.status}`);
    const postId = (postCreate.data as any).id;
    createdIds.posts.push(postId);

    const postPatch = await request<any>('PATCH', `/v1/feed/posts/${postId}`, {
      content: `phase5 post updated ${suffix}`,
      boundDjIDs: [(dj2.data as any).id],
      boundEventIDs: [eventId],
    }, token);
    assert(postPatch.status === 200, `post patch expected 200 got ${postPatch.status}`);

    const postDetail = await request<any>('GET', `/v1/feed/posts/${postId}`, null, token);
    const userPosts = await request<any>('GET', `/v1/users/${adminUser.id}/posts?limit=20`, null, token);
    const feed = await request<any>('GET', '/v1/feed?limit=20', null, token);
    assert(postDetail.status === 200, `post detail expected 200 got ${postDetail.status}`);
    assert(userPosts.status === 200, `user posts expected 200 got ${userPosts.status}`);
    assert(feed.status === 200, `feed expected 200 got ${feed.status}`);

    const postDetailData = unwrapData<any>(postDetail.data);
    assert(
      Array.isArray(postDetailData.boundDjIDs) && postDetailData.boundDjIDs.includes((dj2.data as any).id),
      'post detail binding ids not derived from bindings'
    );
    assert(
      Array.isArray(postDetailData.boundEventIDs) && postDetailData.boundEventIDs.includes(eventId),
      'post detail bound event ids not derived from bindings'
    );

    const userPostsData = unwrapData<any>(userPosts.data);
    const userPost = (userPostsData.posts || []).find((item: any) => item.id === postId);
    assert(userPost, 'created post not found in user posts');
    assert(
      Array.isArray(userPost.boundDjIDs) && userPost.boundDjIDs.includes((dj2.data as any).id),
      'user posts binding ids not derived from bindings'
    );

    logStep('news create/detail/feed');
    const newsCreate = await request<any>('POST', '/v1/news', {
      title: `phase5 news ${suffix}`,
      body: 'phase5 news body',
      source: 'phase5',
      category: 'community',
      boundDjIDs: [(dj1.data as any).id],
      boundEventIDs: [eventId],
    }, token);
    assert(newsCreate.status === 201, `news create expected 201 got ${newsCreate.status}`);
    const newsId = (newsCreate.data as any).id;
    createdIds.news.push(newsId);

    const newsDetail = await request<any>('GET', `/v1/news/${newsId}`, null, token);
    const newsFeed = await request<any>('GET', '/v1/news?limit=20', null, token);
    assert(newsDetail.status === 200, `news detail expected 200 got ${newsDetail.status}`);
    assert(newsFeed.status === 200, `news feed expected 200 got ${newsFeed.status}`);
    assert(Array.isArray(unwrapData<any>(newsDetail.data).boundDjIDs), 'news detail binding ids missing');

    logStep('favorite and follow');
    const favoriteCreate = await request<any>('POST', `/v1/events/${eventId}/favorite`, {}, token);
    const favoriteStatus = await request<any>('GET', `/v1/events/${eventId}/favorite`, null, token);
    const favoriteDelete = await request<any>('DELETE', `/v1/events/${eventId}/favorite`, null, token);
    assert(favoriteCreate.status === 200, `event favorite create expected 200 got ${favoriteCreate.status}`);
    assert(favoriteStatus.status === 200 && Boolean(unwrapData<any>(favoriteStatus.data).isFavorited), 'event favorite status did not update');
    assert(favoriteDelete.status === 200, `event favorite delete expected 200 got ${favoriteDelete.status}`);

    const followCreate = await request<any>('POST', `/v1/djs/${(dj1.data as any).id}/follow`, {}, token);
    const followStatus = await request<any>('GET', `/v1/djs/${(dj1.data as any).id}/follow-status`, null, token);
    const followDelete = await request<any>('DELETE', `/v1/djs/${(dj1.data as any).id}/follow`, null, token);
    assert(followCreate.status === 200, `dj follow create expected 200 got ${followCreate.status}`);
    assert(followStatus.status === 200 && Boolean(unwrapData<any>(followStatus.data).isFollowing), 'dj follow status did not update');
    assert(followDelete.status === 200, `dj follow delete expected 200 got ${followDelete.status}`);

    logStep('dj set');
    const djSetCreate = await request<any>('POST', '/api/dj-sets', {
      djId: (dj1.data as any).id,
      djIds: [(dj1.data as any).id, (dj2.data as any).id],
      customDjNames: ['Phase5 Guest'],
      title: `Phase5 Set ${suffix}`,
      videoUrl: 'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
      eventId,
      eventName: `Phase5 Event ${suffix}`,
    }, token);
    assert(djSetCreate.status === 201, `dj set create expected 201 got ${djSetCreate.status}`);
    const createdDjSet = unwrapData<any>(djSetCreate.data);
    const djSetId = createdDjSet.id;
    createdIds.djSets.push(djSetId);

    const djSetDetail = await request<any>('GET', `/v1/dj-sets/${djSetId}`, null, token);
    assert(djSetDetail.status === 200, `dj set detail expected 200 got ${djSetDetail.status}`);
    assert(Array.isArray(unwrapData<any>(djSetDetail.data).lineupDjs), 'dj set canonical lineup missing');

    logStep('rating event/unit');
    const ratingEventCreate = await request<any>('POST', '/v1/rating-events', {
      name: `Phase5 Rating ${suffix}`,
      sourceEventId: eventId,
    }, token);
    assert(ratingEventCreate.status === 200, `rating event create expected 200 got ${ratingEventCreate.status}`);
    const ratingEventId = unwrapData<any>(ratingEventCreate.data).id;
    createdIds.ratingEvents.push(ratingEventId);

    const ratingUnitCreate = await request<any>('POST', `/v1/rating-events/${ratingEventId}/units`, {
      name: `Phase5 Unit ${suffix}`,
      djIds: [(dj1.data as any).id, (dj2.data as any).id],
    }, token);
    assert(ratingUnitCreate.status === 200, `rating unit create expected 200 got ${ratingUnitCreate.status}`);
    const ratingUnitId = unwrapData<any>(ratingUnitCreate.data).id;
    createdIds.ratingUnits.push(ratingUnitId);

    const ratingUnitDetail = await request<any>('GET', `/v1/rating-units/${ratingUnitId}`, null, token);
    assert(ratingUnitDetail.status === 200, `rating unit detail expected 200 got ${ratingUnitDetail.status}`);
    assert(Array.isArray(unwrapData<any>(ratingUnitDetail.data).linkedDJs), 'rating unit linked DJs missing');

    const ratingUnitPatch = await request<any>('PATCH', `/v1/rating-units/${ratingUnitId}`, {
      djIds: [(dj2.data as any).id],
      name: `Phase5 Unit Updated ${suffix}`,
    }, token);
    assert(ratingUnitPatch.status === 200, `rating unit patch expected 200 got ${ratingUnitPatch.status}`);
    assert((unwrapData<any>(ratingUnitPatch.data).linkedDJs || []).length === 1, 'rating unit bindings did not update');

    console.log('[phase5-canonical-regression] all checks passed', {
      eventId,
      djIds: createdIds.djs,
      postId,
      newsId,
      djSetId,
      ratingEventId,
      ratingUnitId,
    });
  } finally {
    try {
      logStep('cleanup start', createdIds);
      if (createdIds.ratingEvents.length > 0) {
        await prisma.ratingEvent.deleteMany({ where: { id: { in: createdIds.ratingEvents } } });
      }
      if (createdIds.djSets.length > 0) {
        await prisma.dJSet.deleteMany({ where: { id: { in: createdIds.djSets } } });
      }
      if (createdIds.news.length > 0) {
        await prisma.newsArticle.deleteMany({ where: { id: { in: createdIds.news } } });
      }
      if (createdIds.posts.length > 0) {
        await prisma.post.deleteMany({ where: { id: { in: createdIds.posts } } });
      }
      if (createdIds.events.length > 0) {
        await prisma.event.deleteMany({ where: { id: { in: createdIds.events } } });
      }
      if (createdIds.djs.length > 0) {
        await prisma.dJ.deleteMany({ where: { id: { in: createdIds.djs } } });
      }
      if (createdIds.users.length > 0) {
        await prisma.user.deleteMany({ where: { id: { in: createdIds.users } } });
      }
      logStep('cleanup done');
    } finally {
      await prisma.$disconnect();
    }
  }
};

void main().catch((error: unknown) => {
  console.error('[phase5-canonical-regression] failed', error);
  process.exitCode = 1;
});
