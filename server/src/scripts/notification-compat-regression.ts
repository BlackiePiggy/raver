import assert from 'node:assert/strict';
import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

const BASE_URL = (process.env.NOTIFICATION_COMPAT_BASE_URL || 'http://localhost:3901').replace(/\/+$/, '');
const PASSWORD = process.env.NOTIFICATION_COMPAT_PASSWORD || '123456';

const nowStamp = () => new Date().toISOString();

type RegisterResponse = {
  token?: string;
  accessToken?: string;
  user?: {
    id: string;
    username?: string;
  };
  error?: string;
};

type OldUnreadResponse = {
  total: number;
  follows: number;
  likes: number;
  comments: number;
  squadInvites: number;
};

type OldListResponse = {
  unreadCount: number;
  items: Array<{
    id: string;
    type: string;
    isRead: boolean;
  }>;
};

type ReadResponse = {
  success: boolean;
  readCount?: number;
  updated?: number;
};

type NewUnreadResponse = {
  success: boolean;
  total: number;
  follows: number;
  likes: number;
  comments: number;
  squadInvites: number;
  communityTotal: number;
};

const requestJSON = async <T>(input: {
  path: string;
  method?: string;
  token?: string;
  body?: Record<string, unknown>;
}): Promise<{ status: number; data: T }> => {
  const response = await fetch(`${BASE_URL}${input.path}`, {
    method: input.method || 'GET',
    headers: {
      'Content-Type': 'application/json',
      ...(input.token ? { Authorization: `Bearer ${input.token}` } : {}),
    },
    body: input.body ? JSON.stringify(input.body) : undefined,
  });

  const raw = await response.text();
  let parsed: unknown = null;
  try {
    parsed = raw ? JSON.parse(raw) : null;
  } catch {
    parsed = raw;
  }

  if (!response.ok) {
    throw new Error(`[${input.method || 'GET'} ${input.path}] status=${response.status} body=${JSON.stringify(parsed)}`);
  }

  return { status: response.status, data: parsed as T };
};

const main = async (): Promise<void> => {
  const runId = `notifreg_${Date.now()}`;
  const username = runId;
  const email = `${runId}@example.com`;
  const displayName = `Notification Regression ${runId.slice(-6)}`;

  let createdUserId: string | null = null;
  const createdInboxIds: string[] = [];

  try {
    console.log(`[${nowStamp()}] register user ${username}`);
    const registerResult = await requestJSON<RegisterResponse>({
      path: '/v1/auth/register',
      method: 'POST',
      body: {
        username,
        email,
        password: PASSWORD,
        displayName,
      },
    });

    const token = registerResult.data.token || registerResult.data.accessToken;
    const userId = registerResult.data.user?.id;
    assert.ok(token, 'register did not return token/accessToken');
    assert.ok(userId, 'register did not return user.id');

    createdUserId = userId;

    console.log(`[${nowStamp()}] seed notification_inbox test rows`);
    const makeRow = async (input: {
      source: string;
      body: string;
      title?: string;
      metadata?: Record<string, unknown>;
    }): Promise<string> => {
      const row = await prisma.notificationInboxItem.create({
        data: {
          userId,
          type: 'community_interaction',
          title: input.title || '社区互动',
          body: input.body,
          metadata: {
            source: input.source,
            ...(input.metadata || {}),
          },
          isRead: false,
        },
        select: { id: true },
      });
      createdInboxIds.push(row.id);
      return row.id;
    };

    const followInboxId = await makeRow({
      source: 'user_follow',
      body: '有人关注了你',
      metadata: { actorUserID: userId },
    });

    await makeRow({
      source: 'post_like',
      body: '有人赞了你的动态',
      metadata: { actorUserID: userId, postID: `post_${runId}_like`, postPreview: 'like preview' },
    });

    await makeRow({
      source: 'post_comment',
      body: '有人评论了你的动态',
      metadata: { actorUserID: userId, postID: `post_${runId}_comment`, commentPreview: 'comment preview' },
    });

    await makeRow({
      source: 'squad_invite',
      body: '你收到了小队邀请',
      metadata: { inviterUserID: userId, squadID: `squad_${runId}`, squadName: 'Regression Squad' },
    });

    console.log(`[${nowStamp()}] verify old unread-count`);
    const oldUnread1 = await requestJSON<OldUnreadResponse>({
      path: '/v1/notifications/unread-count',
      token,
    });
    assert.equal(oldUnread1.data.total, 4, `old unread total expected 4, got ${oldUnread1.data.total}`);
    assert.equal(oldUnread1.data.follows, 1, `old unread follows expected 1, got ${oldUnread1.data.follows}`);
    assert.equal(oldUnread1.data.likes, 1, `old unread likes expected 1, got ${oldUnread1.data.likes}`);
    assert.equal(oldUnread1.data.comments, 1, `old unread comments expected 1, got ${oldUnread1.data.comments}`);
    assert.equal(oldUnread1.data.squadInvites, 1, `old unread squadInvites expected 1, got ${oldUnread1.data.squadInvites}`);

    console.log(`[${nowStamp()}] verify old list mapping`);
    const oldList = await requestJSON<OldListResponse>({
      path: '/v1/notifications?limit=10',
      token,
    });
    assert.equal(oldList.data.unreadCount, 4, `old list unreadCount expected 4, got ${oldList.data.unreadCount}`);
    assert.equal(oldList.data.items.length, 4, `old list item count expected 4, got ${oldList.data.items.length}`);

    console.log(`[${nowStamp()}] old read by notificationType=comment`);
    const oldReadComment = await requestJSON<ReadResponse>({
      path: '/v1/notifications/read',
      method: 'POST',
      token,
      body: { notificationType: 'comment' },
    });
    assert.equal(oldReadComment.data.success, true, 'old read comment should succeed');
    assert.equal(oldReadComment.data.readCount, 1, `old read comment expected readCount=1, got ${oldReadComment.data.readCount}`);

    const oldUnread2 = await requestJSON<OldUnreadResponse>({
      path: '/v1/notifications/unread-count',
      token,
    });
    assert.equal(oldUnread2.data.total, 3, `old unread total after comment read expected 3, got ${oldUnread2.data.total}`);
    assert.equal(oldUnread2.data.comments, 0, `old unread comments after read expected 0, got ${oldUnread2.data.comments}`);

    console.log(`[${nowStamp()}] new read by inboxId`);
    const newReadById = await requestJSON<ReadResponse>({
      path: '/v1/notification-center/inbox/read',
      method: 'POST',
      token,
      body: { inboxId: followInboxId },
    });
    assert.equal(newReadById.data.success, true, 'new inbox read by id should succeed');
    assert.equal(newReadById.data.updated, 1, `new inbox read by id expected updated=1, got ${newReadById.data.updated}`);

    const oldUnread3 = await requestJSON<OldUnreadResponse>({
      path: '/v1/notifications/unread-count',
      token,
    });
    assert.equal(oldUnread3.data.total, 2, `old unread total after follow read expected 2, got ${oldUnread3.data.total}`);
    assert.equal(oldUnread3.data.follows, 0, `old unread follows after read expected 0, got ${oldUnread3.data.follows}`);

    console.log(`[${nowStamp()}] verify new unread-count compatibility fields`);
    const newUnread = await requestJSON<NewUnreadResponse>({
      path: '/v1/notification-center/inbox/unread-count',
      token,
    });
    assert.equal(newUnread.data.success, true, 'new unread-count success expected true');
    assert.equal(newUnread.data.communityTotal, 2, `new unread communityTotal expected 2, got ${newUnread.data.communityTotal}`);
    assert.equal(newUnread.data.comments, 0, `new unread comments expected 0, got ${newUnread.data.comments}`);

    console.log(`[${nowStamp()}] notification compatibility regression passed`);
  } finally {
    if (createdInboxIds.length > 0) {
      await prisma.notificationInboxItem.deleteMany({
        where: { id: { in: createdInboxIds } },
      });
    }

    if (createdUserId) {
      try {
        await prisma.user.delete({ where: { id: createdUserId } });
      } catch (error) {
        const message = error instanceof Error ? error.message : String(error);
        console.warn(`[cleanup] failed to delete test user ${createdUserId}: ${message}`);
      }
    }

    await prisma.$disconnect();
  }
};

main().catch(async (error) => {
  console.error(error);
  await prisma.$disconnect();
  process.exit(1);
});
