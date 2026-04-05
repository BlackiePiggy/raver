import { Router, Request, Response, NextFunction } from 'express';
import { PrismaClient } from '@prisma/client';
import OSS from 'ali-oss';
import multer from 'multer';
import path from 'path';
import fs from 'fs';
import { comparePassword, generateToken, hashPassword, verifyToken, type JWTPayload } from '../utils/auth';

const router: Router = Router();
const prisma = new PrismaClient();
const avatarUploadDir = path.join(process.cwd(), 'uploads', 'avatars');
if (!fs.existsSync(avatarUploadDir)) {
  fs.mkdirSync(avatarUploadDir, { recursive: true });
}

const avatarStorage = multer.diskStorage({
  destination: (_req, _file, cb) => cb(null, avatarUploadDir),
  filename: (_req, file, cb) => {
    const ext = path.extname(file.originalname || '').toLowerCase();
    const safeExt = ext && ext.length <= 8 ? ext : '.jpg';
    cb(null, `${Date.now()}-${Math.random().toString(36).slice(2, 10)}${safeExt}`);
  },
});

const avatarUpload = multer({
  storage: avatarStorage,
  limits: { fileSize: 5 * 1024 * 1024 },
  fileFilter: (_req, file, cb) => {
    if (!file.mimetype.startsWith('image/')) {
      cb(new Error('Only image files are allowed'));
      return;
    }
    cb(null, true);
  },
});

const cleanEnv = (value: string | undefined): string | null => {
  if (!value) return null;
  const trimmed = value.trim();
  return trimmed.length > 0 ? trimmed : null;
};

const ossRegion = cleanEnv(process.env.OSS_REGION);
const ossAccessKeyId = cleanEnv(process.env.OSS_ACCESS_KEY_ID);
const ossAccessKeySecret = cleanEnv(process.env.OSS_ACCESS_KEY_SECRET);
const ossBucket = cleanEnv(process.env.OSS_BUCKET);
const ossEndpoint = cleanEnv(process.env.OSS_ENDPOINT);
const ossPostsPrefix = (cleanEnv(process.env.OSS_POSTS_PREFIX) || 'posts').replace(/^\/+|\/+$/g, '');

const postMediaOssClient =
  ossRegion && ossAccessKeyId && ossAccessKeySecret && ossBucket
    ? new OSS({
        region: ossRegion,
        accessKeyId: ossAccessKeyId,
        accessKeySecret: ossAccessKeySecret,
        bucket: ossBucket,
        endpoint: ossEndpoint || undefined,
      })
    : null;

const extractPostMediaOssKey = (raw: string): string | null => {
  const value = raw.trim();
  if (!value) return null;

  const normalizedPrefix = `${ossPostsPrefix}/`;
  if (value.startsWith('/')) {
    const relative = value.replace(/^\/+/, '');
    return relative.startsWith(normalizedPrefix) ? relative : null;
  }

  if (value.startsWith('http://') || value.startsWith('https://')) {
    try {
      const url = new URL(value);
      const pathname = decodeURIComponent(url.pathname || '').replace(/^\/+/, '');
      if (!pathname.startsWith(normalizedPrefix)) {
        return null;
      }
      if (!ossBucket) {
        return null;
      }
      const host = url.hostname.toLowerCase();
      const expectedBucket = ossBucket.toLowerCase();
      if (host === expectedBucket || host.startsWith(`${expectedBucket}.`)) {
        return pathname;
      }
      return null;
    } catch {
      return null;
    }
  }

  return value.startsWith(normalizedPrefix) ? value : null;
};

const deletePostMediaFromOss = async (imageUrls: string[]): Promise<{ deletedKeys: string[]; failedKeys: string[] }> => {
  if (!postMediaOssClient || imageUrls.length === 0) {
    return { deletedKeys: [], failedKeys: [] };
  }

  const uniqueKeys = Array.from(
    new Set(
      imageUrls
        .map((item) => extractPostMediaOssKey(item))
        .filter((item): item is string => Boolean(item))
    )
  );

  if (uniqueKeys.length === 0) {
    return { deletedKeys: [], failedKeys: [] };
  }

  const results = await Promise.allSettled(uniqueKeys.map((key) => postMediaOssClient.delete(key)));
  const deletedKeys: string[] = [];
  const failedKeys: string[] = [];
  results.forEach((result, index) => {
    const key = uniqueKeys[index];
    if (result.status === 'fulfilled') {
      deletedKeys.push(key);
    } else {
      failedKeys.push(key);
    }
  });
  return { deletedKeys, failedKeys };
};

interface BFFAuthRequest extends Request {
  user?: JWTPayload;
}

const optionalAuth = (req: Request, _res: Response, next: NextFunction): void => {
  const authHeader = req.headers.authorization;
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    next();
    return;
  }

  const token = authHeader.substring(7);
  try {
    const decoded = verifyToken(token);
    (req as BFFAuthRequest).user = decoded;
  } catch (_error) {
    // Ignore invalid token for public endpoints.
  }

  next();
};

const requireAuth = (req: BFFAuthRequest, res: Response): string | null => {
  const userId = req.user?.userId;
  if (!userId) {
    res.status(401).json({ error: 'Unauthorized' });
    return null;
  }
  return userId;
};

const normalizeLimit = (value: unknown, fallback = 20, max = 50): number => {
  const parsed = Number(value);
  if (!Number.isFinite(parsed)) return fallback;
  return Math.max(1, Math.min(max, Math.floor(parsed)));
};

const parseCursorDate = (cursor: unknown): Date | null => {
  if (typeof cursor !== 'string' || !cursor.trim()) return null;
  const date = new Date(cursor);
  return Number.isNaN(date.getTime()) ? null : date;
};

type BasicUser = {
  id: string;
  username: string;
  displayName: string | null;
  avatarUrl: string | null;
};

const toUserSummary = (user: BasicUser, isFollowing: boolean) => {
  return {
    id: user.id,
    username: user.username,
    displayName: user.displayName || user.username,
    avatarURL: user.avatarUrl,
    isFollowing,
  };
};

const toUserSummaryWithNickname = (
  user: BasicUser,
  isFollowing: boolean,
  nickname?: string | null
) => {
  const summary = toUserSummary(user, isFollowing);
  const normalizedNickname = typeof nickname === 'string' ? nickname.trim() : '';
  if (normalizedNickname) {
    summary.displayName = normalizedNickname;
  }
  return summary;
};

const canManageSquad = (role: string | null | undefined): boolean => {
  return role === 'leader' || role === 'admin';
};

const buildFollowingMap = async (viewerId: string | undefined, targetUserIds: string[]) => {
  if (!viewerId || targetUserIds.length === 0) {
    return new Set<string>();
  }

  const follows = await prisma.follow.findMany({
    where: {
      followerId: viewerId,
      type: 'user',
      followingId: { in: targetUserIds },
    },
    select: { followingId: true },
  });

  return new Set(follows.map((f) => f.followingId).filter((id): id is string => Boolean(id)));
};

const buildFriendUserIds = async (userId: string, candidateUserIds?: string[]) => {
  const outgoing = await prisma.follow.findMany({
    where: {
      followerId: userId,
      type: 'user',
      ...(candidateUserIds
        ? {
            followingId: {
              in: candidateUserIds,
            },
          }
        : {
            followingId: {
              not: null,
            },
          }),
    },
    select: { followingId: true },
  });

  const outgoingIds = outgoing
    .map((row) => row.followingId)
    .filter((id): id is string => Boolean(id));
  if (outgoingIds.length === 0) {
    return new Set<string>();
  }

  const incoming = await prisma.follow.findMany({
    where: {
      followerId: {
        in: outgoingIds,
      },
      followingId: userId,
      type: 'user',
    },
    select: { followerId: true },
  });

  return new Set(incoming.map((row) => row.followerId));
};

const mapPost = (
  post: {
    id: string;
    user: BasicUser;
    squad: { id: string; name: string; avatarUrl: string | null } | null;
    content: string;
    images: string[];
    location?: string | null;
    eventId?: string | null;
    boundDjIds?: string[] | null;
    boundBrandIds?: string[] | null;
    boundEventIds?: string[] | null;
    createdAt: Date;
    likeCount: number;
    repostCount: number;
    commentCount: number;
  },
  followingSet: Set<string>,
  likedPostIds: Set<string>,
  repostedPostIds: Set<string>
) => {
  return {
    id: post.id,
    author: toUserSummary(post.user, followingSet.has(post.user.id)),
    content: post.content,
    images: post.images,
    location: post.location ?? null,
    eventID: post.eventId ?? null,
    boundDjIDs: Array.isArray(post.boundDjIds) ? post.boundDjIds : [],
    boundBrandIDs: Array.isArray(post.boundBrandIds) ? post.boundBrandIds : [],
    boundEventIDs: Array.isArray(post.boundEventIds) ? post.boundEventIds : [],
    createdAt: post.createdAt,
    likeCount: post.likeCount,
    repostCount: post.repostCount,
    commentCount: post.commentCount,
    isLiked: likedPostIds.has(post.id),
    isReposted: repostedPostIds.has(post.id),
    squad: post.squad
      ? {
          id: post.squad.id,
          name: post.squad.name,
          avatarURL: post.squad.avatarUrl,
        }
      : null,
  };
};

const buildLikedPostMap = async (viewerId: string | undefined, postIds: string[]) => {
  if (!viewerId || postIds.length === 0) {
    return new Set<string>();
  }

  const rows = await prisma.postLike.findMany({
    where: {
      userId: viewerId,
      postId: { in: postIds },
    },
    select: { postId: true },
  });

  return new Set(rows.map((row) => row.postId));
};

const buildRepostedPostMap = async (viewerId: string | undefined, postIds: string[]) => {
  if (!viewerId || postIds.length === 0) {
    return new Set<string>();
  }

  const rows = await prisma.postRepost.findMany({
    where: {
      userId: viewerId,
      postId: { in: postIds },
    },
    select: { postId: true },
  });

  return new Set(rows.map((row) => row.postId));
};

const normalizeTags = (input: unknown): string[] => {
  if (Array.isArray(input)) {
    return Array.from(
      new Set(
        input
          .filter((item): item is string => typeof item === 'string')
          .map((item) => item.trim())
          .filter(Boolean)
          .slice(0, 20)
      )
    );
  }

  if (typeof input === 'string') {
    return Array.from(
      new Set(
        input
          .split(',')
          .map((item) => item.trim())
          .filter(Boolean)
          .slice(0, 20)
      )
    );
  }

  return [];
};

const normalizePostBindingIDs = (input: unknown, maxCount = 50): string[] => {
  if (!Array.isArray(input)) {
    return [];
  }

  const deduped = Array.from(
    new Set(
      input
        .filter((item): item is string => typeof item === 'string')
        .map((item) => item.trim())
        .filter((item) => item.length > 0)
    )
  );

  return deduped.slice(0, maxCount);
};

const normalizeDirectPair = (userOneId: string, userTwoId: string): [string, string] => {
  return userOneId <= userTwoId ? [userOneId, userTwoId] : [userTwoId, userOneId];
};

const mapDirectConversation = async (
  conversation: {
    id: string;
    userAId: string;
    userBId: string;
    userA: BasicUser;
    userB: BasicUser;
    updatedAt: Date;
    messages: Array<{ content: string; createdAt: Date; senderId: string; sender?: { username: string } }>;
  },
  viewerId: string,
  unreadCount = 0
) => {
  const targetUser = conversation.userAId === viewerId ? conversation.userB : conversation.userA;
  const followingSet = await buildFollowingMap(viewerId, [targetUser.id]);
  const last = conversation.messages[0];

  return {
    id: conversation.id,
    type: 'direct',
    title: targetUser.displayName || targetUser.username,
    avatarURL: targetUser.avatarUrl,
    lastMessage: last?.content || '开始聊天吧',
    lastMessageSenderID: last?.sender?.username || last?.senderId || null,
    unreadCount,
    updatedAt: last?.createdAt || conversation.updatedAt,
    peer: toUserSummary(targetUser, followingSet.has(targetUser.id)),
  };
};

const mapGroupConversation = (
  squad: {
    id: string;
    name: string;
    avatarUrl: string | null;
    updatedAt: Date;
    messages: Array<{ content: string; createdAt: Date; userId: string; user?: { username: string } }>;
  },
  unreadCount = 0
) => {
  const last = squad.messages[0];
  return {
    id: squad.id,
    type: 'group',
    title: squad.name,
    avatarURL: squad.avatarUrl,
    lastMessage: last?.content || '暂无消息',
    lastMessageSenderID: last?.user?.username || last?.userId || null,
    unreadCount,
    updatedAt: last?.createdAt || squad.updatedAt,
    peer: null,
  };
};

const truncateText = (value: string, maxLength = 28): string => {
  const normalized = value.replace(/\s+/g, ' ').trim();
  if (!normalized) return '';
  if (normalized.length <= maxLength) return normalized;
  return `${normalized.slice(0, maxLength - 1)}…`;
};

type NotificationType = 'follow' | 'like' | 'comment' | 'squad_invite';

type NotificationSourceIds = {
  follows: string[];
  likes: string[];
  comments: string[];
  squadInvites: string[];
};

type NotificationReadPayload = {
  type: NotificationType;
  sourceId: string;
};

const notificationReadKey = (type: NotificationType, sourceId: string): string => `${type}:${sourceId}`;

const parseNotificationReadPayload = (rawId: unknown): NotificationReadPayload | null => {
  if (typeof rawId !== 'string') return null;

  const trimmed = rawId.trim();
  if (!trimmed) return null;

  const separatorIndex = trimmed.indexOf('_');
  if (separatorIndex <= 0 || separatorIndex === trimmed.length - 1) {
    return null;
  }

  const prefix = trimmed.slice(0, separatorIndex);
  const sourceId = trimmed.slice(separatorIndex + 1).trim();
  if (!sourceId) return null;

  if (prefix === 'follow') return { type: 'follow', sourceId };
  if (prefix === 'like') return { type: 'like', sourceId };
  if (prefix === 'comment') return { type: 'comment', sourceId };
  if (prefix === 'invite') return { type: 'squad_invite', sourceId };
  return null;
};

const getNotificationSourceIds = async (userId: string, now: Date): Promise<NotificationSourceIds> => {
  const [follows, likes, comments, squadInvites] = await Promise.all([
    prisma.follow.findMany({
      where: {
        type: 'user',
        followingId: userId,
        followerId: { not: userId },
      },
      select: { id: true },
    }),
    prisma.postLike.findMany({
      where: {
        userId: { not: userId },
        post: { userId },
      },
      select: { id: true },
    }),
    prisma.postComment.findMany({
      where: {
        userId: { not: userId },
        post: { userId },
      },
      select: { id: true },
    }),
    prisma.squadInvite.findMany({
      where: {
        inviteeId: userId,
        status: 'pending',
        expiresAt: { gt: now },
      },
      select: { id: true },
    }),
  ]);

  return {
    follows: follows.map((row) => row.id),
    likes: likes.map((row) => row.id),
    comments: comments.map((row) => row.id),
    squadInvites: squadInvites.map((row) => row.id),
  };
};

const getNotificationReadSet = async (
  userId: string,
  sourceIds: NotificationSourceIds
): Promise<Set<string>> => {
  const filters: Array<{ type: NotificationType; sourceId: { in: string[] } }> = [];

  if (sourceIds.follows.length > 0) {
    filters.push({ type: 'follow', sourceId: { in: sourceIds.follows } });
  }
  if (sourceIds.likes.length > 0) {
    filters.push({ type: 'like', sourceId: { in: sourceIds.likes } });
  }
  if (sourceIds.comments.length > 0) {
    filters.push({ type: 'comment', sourceId: { in: sourceIds.comments } });
  }
  if (sourceIds.squadInvites.length > 0) {
    filters.push({ type: 'squad_invite', sourceId: { in: sourceIds.squadInvites } });
  }

  if (filters.length === 0) {
    return new Set<string>();
  }

  const readRows = await prisma.notificationRead.findMany({
    where: {
      userId,
      OR: filters,
    },
    select: {
      type: true,
      sourceId: true,
    },
  });

  return new Set(
    readRows.map((row) =>
      notificationReadKey(row.type as NotificationType, row.sourceId)
    )
  );
};

const getNotificationCounts = async (userId: string, now: Date) => {
  const sourceIds = await getNotificationSourceIds(userId, now);
  const readSet = await getNotificationReadSet(userId, sourceIds);

  const follows = sourceIds.follows.filter(
    (id) => !readSet.has(notificationReadKey('follow', id))
  ).length;
  const likes = sourceIds.likes.filter(
    (id) => !readSet.has(notificationReadKey('like', id))
  ).length;
  const comments = sourceIds.comments.filter(
    (id) => !readSet.has(notificationReadKey('comment', id))
  ).length;
  const squadInvites = sourceIds.squadInvites.filter(
    (id) => !readSet.has(notificationReadKey('squad_invite', id))
  ).length;

  return {
    follows,
    likes,
    comments,
    squadInvites,
    total: follows + likes + comments + squadInvites,
  };
};

router.get('/', (_req: Request, res: Response) => {
  res.json({
    name: 'Raver BFF',
    version: 'v1',
    endpoints: {
      authLogin: 'POST /v1/auth/login',
      authRegister: 'POST /v1/auth/register',
      feed: 'GET /v1/feed',
      feedSearch: 'GET /v1/feed/search',
      createPost: 'POST /v1/feed/posts',
      updatePost: 'PATCH /v1/feed/posts/:id',
      deletePost: 'DELETE /v1/feed/posts/:id',
      userSearch: 'GET /v1/users/search',
      userProfile: 'GET /v1/users/:id/profile',
      userPosts: 'GET /v1/users/:id/posts',
      userFollowers: 'GET /v1/users/:id/followers',
      userFollowing: 'GET /v1/users/:id/following',
      userFriends: 'GET /v1/users/:id/friends',
      notifications: 'GET /v1/notifications',
      notificationsUnreadCount: 'GET /v1/notifications/unread-count',
      notificationsRead: 'POST /v1/notifications/read',
      squadsRecommended: 'GET /v1/squads/recommended',
      squadsMine: 'GET /v1/squads/mine',
      squadProfile: 'GET /v1/squads/:id/profile',
      squadJoin: 'POST /v1/squads/:id/join',
      squadCreate: 'POST /v1/squads',
      squadAvatar: 'POST /v1/squads/:id/avatar',
      squadMySettings: 'PATCH /v1/squads/:id/my-settings',
      squadManage: 'PATCH /v1/squads/:id/manage',
      profileUpdate: 'PATCH /v1/profile/me',
      profileAvatar: 'POST /v1/profile/me/avatar',
      profileLikes: 'GET /v1/profile/me/likes',
      profileReposts: 'GET /v1/profile/me/reposts',
      conversations: 'GET /v1/chat/conversations',
      conversationRead: 'POST /v1/chat/conversations/:id/read',
      startDirect: 'POST /v1/chat/direct/start',
      repostPost: 'POST /v1/feed/posts/:id/repost',
      unrepostPost: 'DELETE /v1/feed/posts/:id/repost',
    },
  });
});

router.post('/auth/login', async (req: Request, res: Response): Promise<void> => {
  try {
    const { username, identifier, email, password } = req.body as {
      username?: string;
      identifier?: string;
      email?: string;
      password?: string;
    };

    const loginIdentifier = String(username || identifier || email || '').trim();

    if (!loginIdentifier || !password) {
      res.status(400).json({ error: 'username and password are required' });
      return;
    }

    const user = await prisma.user.findFirst({
      where: {
        isActive: true,
        OR: [
          { username: { equals: loginIdentifier, mode: 'insensitive' } },
          { email: { equals: loginIdentifier, mode: 'insensitive' } },
          { displayName: { equals: loginIdentifier, mode: 'insensitive' } },
        ],
      },
      orderBy: { createdAt: 'asc' },
    });

    if (!user) {
      res.status(401).json({ error: 'Invalid credentials' });
      return;
    }

    const valid = await comparePassword(password, user.passwordHash);
    if (!valid) {
      res.status(401).json({ error: 'Invalid credentials' });
      return;
    }

    await prisma.user.update({
      where: { id: user.id },
      data: { lastLoginAt: new Date() },
    });

    const token = generateToken({
      userId: user.id,
      email: user.email,
      role: user.role,
    });

    res.json({
      token,
      user: toUserSummary(
        {
          id: user.id,
          username: user.username,
          displayName: user.displayName,
          avatarUrl: user.avatarUrl,
        },
        false
      ),
    });
  } catch (error) {
    console.error('BFF login error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.post('/auth/register', async (req: Request, res: Response): Promise<void> => {
  try {
    const { username, email, password, displayName } = req.body as {
      username?: string;
      email?: string;
      password?: string;
      displayName?: string;
    };

    const normalizedUsername = String(username || '').trim().toLowerCase();
    const normalizedEmail = String(email || '').trim().toLowerCase();
    const normalizedDisplayName = String(displayName || normalizedUsername).trim();

    if (!normalizedUsername || !normalizedEmail || !password) {
      res.status(400).json({ error: 'username, email, and password are required' });
      return;
    }

    if (password.length < 6) {
      res.status(400).json({ error: 'Password must be at least 6 characters' });
      return;
    }

    const exists = await prisma.user.findFirst({
      where: {
        OR: [{ username: normalizedUsername }, { email: normalizedEmail }],
      },
      select: { id: true },
    });

    if (exists) {
      res.status(409).json({ error: 'User already exists' });
      return;
    }

    const user = await prisma.user.create({
      data: {
        username: normalizedUsername,
        email: normalizedEmail,
        passwordHash: await hashPassword(password),
        displayName: normalizedDisplayName || normalizedUsername,
      },
      select: {
        id: true,
        username: true,
        email: true,
        displayName: true,
        avatarUrl: true,
        role: true,
      },
    });

    const token = generateToken({
      userId: user.id,
      email: user.email,
      role: user.role,
    });

    res.status(201).json({
      token,
      user: toUserSummary(
        {
          id: user.id,
          username: user.username,
          displayName: user.displayName,
          avatarUrl: user.avatarUrl,
        },
        false
      ),
    });
  } catch (error) {
    console.error('BFF register error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.get('/feed', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const authReq = req as BFFAuthRequest;
    const viewerId = authReq.user?.userId;

    const limit = normalizeLimit(req.query.limit, 20, 50);
    const cursorDate = parseCursorDate(req.query.cursor);

    const posts = await prisma.post.findMany({
      where: {
        visibility: 'public',
        squadId: null,
        ...(cursorDate
          ? {
              createdAt: {
                lt: cursorDate,
              },
            }
          : {}),
      },
      include: {
        user: {
          select: {
            id: true,
            username: true,
            displayName: true,
            avatarUrl: true,
          },
        },
        squad: {
          select: {
            id: true,
            name: true,
            avatarUrl: true,
          },
        },
      },
      orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
      take: limit + 1,
    });

    const hasMore = posts.length > limit;
    const pagePosts = hasMore ? posts.slice(0, limit) : posts;

    const authorIds = Array.from(new Set(pagePosts.map((post) => post.user.id)));
    const postIds = pagePosts.map((post) => post.id);

    const [followingSet, likedPostIds, repostedPostIds] = await Promise.all([
      buildFollowingMap(viewerId, authorIds),
      buildLikedPostMap(viewerId, postIds),
      buildRepostedPostMap(viewerId, postIds),
    ]);

    const mappedPosts = pagePosts.map((post) => mapPost(post, followingSet, likedPostIds, repostedPostIds));

    res.json({
      posts: mappedPosts,
      nextCursor: hasMore ? pagePosts[pagePosts.length - 1]?.createdAt.toISOString() ?? null : null,
    });
  } catch (error) {
    console.error('BFF feed error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.get('/feed/search', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const authReq = req as BFFAuthRequest;
    const viewerId = authReq.user?.userId;
    const query = String(req.query.q || '').trim();
    const limit = normalizeLimit(req.query.limit, 20, 50);

    if (!query) {
      res.json({ posts: [], nextCursor: null });
      return;
    }

    const posts = await prisma.post.findMany({
      where: {
        visibility: 'public',
        squadId: null,
        OR: [
          { content: { contains: query, mode: 'insensitive' } },
          {
            user: {
              OR: [
                { username: { contains: query, mode: 'insensitive' } },
                { displayName: { contains: query, mode: 'insensitive' } },
              ],
            },
          },
        ],
      },
      include: {
        user: {
          select: {
            id: true,
            username: true,
            displayName: true,
            avatarUrl: true,
          },
        },
        squad: {
          select: {
            id: true,
            name: true,
            avatarUrl: true,
          },
        },
      },
      orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
      take: limit,
    });

    const authorIds = Array.from(new Set(posts.map((post) => post.user.id)));
    const postIds = posts.map((post) => post.id);
    const [followingSet, likedPostIds, repostedPostIds] = await Promise.all([
      buildFollowingMap(viewerId, authorIds),
      buildLikedPostMap(viewerId, postIds),
      buildRepostedPostMap(viewerId, postIds),
    ]);

    res.json({
      posts: posts.map((post) => mapPost(post, followingSet, likedPostIds, repostedPostIds)),
      nextCursor: null,
    });
  } catch (error) {
    console.error('BFF feed search error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.get('/users/search', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const userId = requireAuth(req as BFFAuthRequest, res);
    if (!userId) return;

    const query = String(req.query.q || '').trim();
    const limit = normalizeLimit(req.query.limit, 20, 50);
    if (!query) {
      res.json([]);
      return;
    }

    const users = await prisma.user.findMany({
      where: {
        isActive: true,
        id: { not: userId },
        OR: [
          { username: { contains: query, mode: 'insensitive' } },
          { displayName: { contains: query, mode: 'insensitive' } },
        ],
      },
      select: {
        id: true,
        username: true,
        displayName: true,
        avatarUrl: true,
      },
      orderBy: [{ username: 'asc' }],
      take: limit,
    });

    const followingSet = await buildFollowingMap(
      userId,
      users.map((user) => user.id)
    );

    res.json(users.map((user) => toUserSummary(user, followingSet.has(user.id))));
  } catch (error) {
    console.error('BFF user search error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.get('/users/:id/profile', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const viewerId = requireAuth(req as BFFAuthRequest, res);
    if (!viewerId) return;

    const targetUserId = req.params.id as string;
    const user = await prisma.user.findUnique({
      where: { id: targetUserId },
      select: {
        id: true,
        username: true,
        displayName: true,
        bio: true,
        avatarUrl: true,
        favoriteGenres: true,
        isFollowersListPublic: true,
        isFollowingListPublic: true,
        isActive: true,
      },
    });

    if (!user || !user.isActive) {
      res.status(404).json({ error: 'User not found' });
      return;
    }

    const [followersCount, followingCount, postsCount, followRow, friendIds] = await Promise.all([
      prisma.follow.count({
        where: {
          followingId: targetUserId,
          type: 'user',
        },
      }),
      prisma.follow.count({
        where: {
          followerId: targetUserId,
          type: 'user',
          followingId: { not: null },
        },
      }),
      prisma.post.count({
        where: {
          userId: targetUserId,
          visibility: 'public',
        },
      }),
      viewerId === targetUserId
        ? Promise.resolve(null)
        : prisma.follow.findUnique({
            where: {
              followerId_followingId: {
                followerId: viewerId,
                followingId: targetUserId,
              },
            },
            select: { id: true },
          }),
      buildFriendUserIds(targetUserId),
    ]);

    const canViewFollowersList = viewerId === targetUserId || user.isFollowersListPublic;
    const canViewFollowingList = viewerId === targetUserId || user.isFollowingListPublic;

    res.json({
      id: user.id,
      username: user.username,
      displayName: user.displayName || user.username,
      bio: user.bio || '',
      avatarURL: user.avatarUrl,
      tags: user.favoriteGenres,
      isFollowersListPublic: user.isFollowersListPublic,
      isFollowingListPublic: user.isFollowingListPublic,
      canViewFollowersList,
      canViewFollowingList,
      followersCount,
      followingCount,
      friendsCount: friendIds.size,
      postsCount,
      isFollowing: Boolean(followRow),
    });
  } catch (error) {
    console.error('BFF user profile error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.get('/users/:id/followers', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const viewerId = requireAuth(req as BFFAuthRequest, res);
    if (!viewerId) return;

    const targetUserId = req.params.id as string;
    const limit = normalizeLimit(req.query.limit, 20, 50);
    const cursorDate = parseCursorDate(req.query.cursor);

    const user = await prisma.user.findUnique({
      where: { id: targetUserId },
      select: { id: true, isActive: true, isFollowersListPublic: true },
    });
    if (!user || !user.isActive) {
      res.status(404).json({ error: 'User not found' });
      return;
    }

    const canView = viewerId === targetUserId || user.isFollowersListPublic;
    if (!canView) {
      res.status(403).json({ error: 'Followers list is private' });
      return;
    }

    const rows = await prisma.follow.findMany({
      where: {
        followingId: targetUserId,
        type: 'user',
        ...(cursorDate
          ? {
              createdAt: {
                lt: cursorDate,
              },
            }
          : {}),
      },
      include: {
        follower: {
          select: {
            id: true,
            username: true,
            displayName: true,
            avatarUrl: true,
          },
        },
      },
      orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
      take: limit + 1,
    });

    const hasMore = rows.length > limit;
    const pageRows = hasMore ? rows.slice(0, limit) : rows;
    const followingSet = await buildFollowingMap(
      viewerId,
      pageRows.map((row) => row.follower.id)
    );

    res.json({
      users: pageRows.map((row) => toUserSummary(row.follower, followingSet.has(row.follower.id))),
      nextCursor: hasMore ? pageRows[pageRows.length - 1]?.createdAt.toISOString() ?? null : null,
    });
  } catch (error) {
    console.error('BFF followers list error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.get('/users/:id/following', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const viewerId = requireAuth(req as BFFAuthRequest, res);
    if (!viewerId) return;

    const targetUserId = req.params.id as string;
    const limit = normalizeLimit(req.query.limit, 20, 50);
    const cursorDate = parseCursorDate(req.query.cursor);

    const user = await prisma.user.findUnique({
      where: { id: targetUserId },
      select: { id: true, isActive: true, isFollowingListPublic: true },
    });
    if (!user || !user.isActive) {
      res.status(404).json({ error: 'User not found' });
      return;
    }

    const canView = viewerId === targetUserId || user.isFollowingListPublic;
    if (!canView) {
      res.status(403).json({ error: 'Following list is private' });
      return;
    }

    const rows = await prisma.follow.findMany({
      where: {
        followerId: targetUserId,
        type: 'user',
        followingId: { not: null },
        ...(cursorDate
          ? {
              createdAt: {
                lt: cursorDate,
              },
            }
          : {}),
      },
      include: {
        following: {
          select: {
            id: true,
            username: true,
            displayName: true,
            avatarUrl: true,
            isActive: true,
          },
        },
      },
      orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
      take: limit + 1,
    });

    const hasMore = rows.length > limit;
    const pageRows = hasMore ? rows.slice(0, limit) : rows;
    const users = pageRows.map((row) => row.following).filter((target): target is BasicUser & { isActive: boolean } => Boolean(target && target.isActive));
    const followingSet = await buildFollowingMap(
      viewerId,
      users.map((target) => target.id)
    );

    res.json({
      users: users.map((target) => toUserSummary(target, followingSet.has(target.id))),
      nextCursor: hasMore ? pageRows[pageRows.length - 1]?.createdAt.toISOString() ?? null : null,
    });
  } catch (error) {
    console.error('BFF following list error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.get('/users/:id/friends', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const viewerId = requireAuth(req as BFFAuthRequest, res);
    if (!viewerId) return;

    const targetUserId = req.params.id as string;
    const user = await prisma.user.findUnique({
      where: { id: targetUserId },
      select: { id: true, isActive: true },
    });
    if (!user || !user.isActive) {
      res.status(404).json({ error: 'User not found' });
      return;
    }

    const friendIds = Array.from(await buildFriendUserIds(targetUserId));
    if (friendIds.length === 0) {
      res.json({ users: [], nextCursor: null });
      return;
    }

    const users = await prisma.user.findMany({
      where: {
        id: { in: friendIds },
        isActive: true,
      },
      select: {
        id: true,
        username: true,
        displayName: true,
        avatarUrl: true,
      },
      orderBy: [{ username: 'asc' }],
    });

    const followingSet = await buildFollowingMap(viewerId, users.map((item) => item.id));
    res.json({
      users: users.map((item) => toUserSummary(item, followingSet.has(item.id))),
      nextCursor: null,
    });
  } catch (error) {
    console.error('BFF friends list error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.get('/users/:id/posts', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const authReq = req as BFFAuthRequest;
    const viewerId = requireAuth(authReq, res);
    if (!viewerId) return;

    const targetUserId = req.params.id as string;
    const limit = normalizeLimit(req.query.limit, 20, 50);
    const cursorDate = parseCursorDate(req.query.cursor);

    const targetUser = await prisma.user.findUnique({
      where: { id: targetUserId },
      select: { id: true, isActive: true },
    });

    if (!targetUser || !targetUser.isActive) {
      res.status(404).json({ error: 'User not found' });
      return;
    }

    const posts = await prisma.post.findMany({
      where: {
        userId: targetUserId,
        visibility: 'public',
        squadId: null,
        ...(cursorDate
          ? {
              createdAt: {
                lt: cursorDate,
              },
            }
          : {}),
      },
      include: {
        user: {
          select: {
            id: true,
            username: true,
            displayName: true,
            avatarUrl: true,
          },
        },
        squad: {
          select: {
            id: true,
            name: true,
            avatarUrl: true,
          },
        },
      },
      orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
      take: limit + 1,
    });

    const hasMore = posts.length > limit;
    const pagePosts = hasMore ? posts.slice(0, limit) : posts;
    const postIds = pagePosts.map((post) => post.id);

    const [followingSet, likedPostIds, repostedPostIds] = await Promise.all([
      buildFollowingMap(viewerId, [targetUserId]),
      buildLikedPostMap(viewerId, postIds),
      buildRepostedPostMap(viewerId, postIds),
    ]);

    res.json({
      posts: pagePosts.map((post) => mapPost(post, followingSet, likedPostIds, repostedPostIds)),
      nextCursor: hasMore ? pagePosts[pagePosts.length - 1]?.createdAt.toISOString() ?? null : null,
    });
  } catch (error) {
    console.error('BFF user posts error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.get('/notifications/unread-count', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const userId = requireAuth(req as BFFAuthRequest, res);
    if (!userId) return;

    const now = new Date();
    const counts = await getNotificationCounts(userId, now);

    res.json({
      total: counts.total,
      follows: counts.follows,
      likes: counts.likes,
      comments: counts.comments,
      squadInvites: counts.squadInvites,
    });
  } catch (error) {
    console.error('BFF unread notifications error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.post('/notifications/read', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const userId = requireAuth(req as BFFAuthRequest, res);
    if (!userId) return;

    const body = req.body as { notificationId?: unknown; notificationIds?: unknown };
    const inputIds: unknown[] = [];
    if (typeof body.notificationId === 'string') {
      inputIds.push(body.notificationId);
    }
    if (Array.isArray(body.notificationIds)) {
      inputIds.push(...body.notificationIds);
    }

    const parsed = inputIds
      .map((value) => parseNotificationReadPayload(value))
      .filter((item): item is NotificationReadPayload => item !== null);

    if (parsed.length === 0) {
      res.status(400).json({ error: 'notificationId is required' });
      return;
    }

    const uniqueReadTargets = Array.from(
      new Map(
        parsed.map((item) => [notificationReadKey(item.type, item.sourceId), item] as const)
      ).values()
    );

    const now = new Date();
    await Promise.all(
      uniqueReadTargets.map((item) =>
        prisma.notificationRead.upsert({
          where: {
            userId_type_sourceId: {
              userId,
              type: item.type,
              sourceId: item.sourceId,
            },
          },
          create: {
            userId,
            type: item.type,
            sourceId: item.sourceId,
            readAt: now,
          },
          update: {
            readAt: now,
          },
        })
      )
    );

    res.json({ success: true, readCount: uniqueReadTargets.length, readAt: now });
  } catch (error) {
    console.error('BFF mark notification read error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.get('/notifications', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const userId = requireAuth(req as BFFAuthRequest, res);
    if (!userId) return;

    const limit = normalizeLimit(req.query.limit, 20, 50);
    const now = new Date();

    const [counts, follows, likes, comments, squadInvites] = await Promise.all([
      getNotificationCounts(userId, now),
      prisma.follow.findMany({
        where: {
          type: 'user',
          followingId: userId,
          followerId: { not: userId },
        },
        include: {
          follower: {
            select: {
              id: true,
              username: true,
              displayName: true,
              avatarUrl: true,
            },
          },
        },
        orderBy: { createdAt: 'desc' },
        take: limit,
      }),
      prisma.postLike.findMany({
        where: {
          userId: { not: userId },
          post: { userId },
        },
        include: {
          user: {
            select: {
              id: true,
              username: true,
              displayName: true,
              avatarUrl: true,
            },
          },
          post: {
            select: {
              id: true,
              content: true,
            },
          },
        },
        orderBy: { createdAt: 'desc' },
        take: limit,
      }),
      prisma.postComment.findMany({
        where: {
          userId: { not: userId },
          post: { userId },
        },
        include: {
          user: {
            select: {
              id: true,
              username: true,
              displayName: true,
              avatarUrl: true,
            },
          },
          post: {
            select: {
              id: true,
              content: true,
            },
          },
        },
        orderBy: { createdAt: 'desc' },
        take: limit,
      }),
      prisma.squadInvite.findMany({
        where: {
          inviteeId: userId,
          status: 'pending',
          expiresAt: { gt: now },
        },
        include: {
          squad: {
            select: {
              id: true,
              name: true,
              avatarUrl: true,
            },
          },
          inviter: {
            select: {
              id: true,
              username: true,
              displayName: true,
              avatarUrl: true,
            },
          },
        },
        orderBy: { createdAt: 'desc' },
        take: limit,
      }),
    ]);

    const actorIds = Array.from(
      new Set(
        [
          ...follows.map((item) => item.follower.id),
          ...likes.map((item) => item.user.id),
          ...comments.map((item) => item.user.id),
          ...squadInvites.map((item) => item.inviter.id),
        ].filter((id) => id !== userId)
      )
    );
    const followingSet = await buildFollowingMap(userId, actorIds);
    const readSet = await getNotificationReadSet(userId, {
      follows: follows.map((item) => item.id),
      likes: likes.map((item) => item.id),
      comments: comments.map((item) => item.id),
      squadInvites: squadInvites.map((item) => item.id),
    });

    const followItems = follows.map((item) => {
      const actor = toUserSummary(item.follower, followingSet.has(item.follower.id));
      return {
        id: `follow_${item.id}`,
        type: 'follow',
        createdAt: item.createdAt,
        isRead: readSet.has(notificationReadKey('follow', item.id)),
        actor,
        text: `${actor.displayName} 关注了你`,
        target: {
          type: 'user',
          id: actor.id,
          title: actor.displayName,
        },
      };
    });

    const likeItems = likes.map((item) => {
      const actor = toUserSummary(item.user, followingSet.has(item.user.id));
      const postPreview = truncateText(item.post.content);
      return {
        id: `like_${item.id}`,
        type: 'like',
        createdAt: item.createdAt,
        isRead: readSet.has(notificationReadKey('like', item.id)),
        actor,
        text: postPreview ? `${actor.displayName} 赞了你的动态：${postPreview}` : `${actor.displayName} 赞了你的动态`,
        target: {
          type: 'post',
          id: item.post.id,
          title: postPreview || null,
        },
      };
    });

    const commentItems = comments.map((item) => {
      const actor = toUserSummary(item.user, followingSet.has(item.user.id));
      const commentPreview = truncateText(item.content);
      return {
        id: `comment_${item.id}`,
        type: 'comment',
        createdAt: item.createdAt,
        isRead: readSet.has(notificationReadKey('comment', item.id)),
        actor,
        text: commentPreview
          ? `${actor.displayName} 评论了你：${commentPreview}`
          : `${actor.displayName} 评论了你的动态`,
        target: {
          type: 'post',
          id: item.post.id,
          title: truncateText(item.post.content) || null,
        },
      };
    });

    const inviteItems = squadInvites.map((item) => {
      const actor = toUserSummary(item.inviter, followingSet.has(item.inviter.id));
      return {
        id: `invite_${item.id}`,
        type: 'squad_invite',
        createdAt: item.createdAt,
        isRead: readSet.has(notificationReadKey('squad_invite', item.id)),
        actor,
        text: `${actor.displayName} 邀请你加入小队「${item.squad.name}」`,
        target: {
          type: 'squad',
          id: item.squad.id,
          title: item.squad.name,
        },
      };
    });

    const items = [...followItems, ...likeItems, ...commentItems, ...inviteItems]
      .sort((a, b) => b.createdAt.getTime() - a.createdAt.getTime())
      .slice(0, limit);

    res.json({
      unreadCount: counts.total,
      items,
    });
  } catch (error) {
    console.error('BFF notifications error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.get('/squads/recommended', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const userId = requireAuth(req as BFFAuthRequest, res);
    if (!userId) return;

    const limit = normalizeLimit(req.query.limit, 20, 50);
    const squads = await prisma.squad.findMany({
      where: {
        OR: [
          { isPublic: true },
          { members: { some: { userId } } },
        ],
      },
      include: {
        _count: {
          select: {
            members: true,
          },
        },
        messages: {
          orderBy: { createdAt: 'desc' },
          take: 1,
          select: {
            content: true,
            createdAt: true,
          },
        },
      },
      orderBy: [{ createdAt: 'desc' }],
      take: limit,
    });

    const squadIds = squads.map((squad) => squad.id);
    const memberships = await prisma.squadMember.findMany({
      where: {
        userId,
        squadId: { in: squadIds },
      },
      select: { squadId: true },
    });
    const memberSet = new Set(memberships.map((item) => item.squadId));

    res.json(
      squads.map((squad) => ({
        id: squad.id,
        name: squad.name,
        description: squad.description,
        avatarURL: squad.avatarUrl,
        bannerURL: squad.bannerUrl,
        isPublic: squad.isPublic,
        memberCount: squad._count.members,
        isMember: memberSet.has(squad.id),
        lastMessage: squad.messages[0]?.content ?? null,
        updatedAt: squad.messages[0]?.createdAt ?? squad.updatedAt,
      }))
    );
  } catch (error) {
    console.error('BFF recommended squads error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.get('/squads/mine', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const userId = requireAuth(req as BFFAuthRequest, res);
    if (!userId) return;

    const squads = await prisma.squad.findMany({
      where: {
        members: {
          some: { userId },
        },
      },
      include: {
        _count: {
          select: {
            members: true,
          },
        },
        messages: {
          orderBy: { createdAt: 'desc' },
          take: 1,
          select: {
            content: true,
            createdAt: true,
          },
        },
      },
      orderBy: [{ updatedAt: 'desc' }, { createdAt: 'desc' }],
    });

    res.json(
      squads.map((squad) => ({
        id: squad.id,
        name: squad.name,
        description: squad.description,
        avatarURL: squad.avatarUrl,
        bannerURL: squad.bannerUrl,
        isPublic: squad.isPublic,
        memberCount: squad._count.members,
        isMember: true,
        lastMessage: squad.messages[0]?.content ?? null,
        updatedAt: squad.messages[0]?.createdAt ?? squad.updatedAt,
      }))
    );
  } catch (error) {
    console.error('BFF my squads error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.get('/squads/:id/profile', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const userId = requireAuth(req as BFFAuthRequest, res);
    if (!userId) return;

    const squadId = req.params.id as string;
    const [squad, memberRow] = await Promise.all([
      prisma.squad.findUnique({
        where: { id: squadId },
        include: {
          leader: {
            select: {
              id: true,
              username: true,
              displayName: true,
              avatarUrl: true,
            },
          },
          members: {
            orderBy: { joinedAt: 'asc' },
            include: {
              user: {
                select: {
                  id: true,
                  username: true,
                  displayName: true,
                  avatarUrl: true,
                },
              },
            },
            take: 80,
          },
          messages: {
            orderBy: { createdAt: 'desc' },
            take: 20,
            include: {
              user: {
                select: {
                  id: true,
                  username: true,
                  displayName: true,
                  avatarUrl: true,
                },
              },
            },
          },
          activities: {
            orderBy: [{ date: 'desc' }, { createdAt: 'desc' }],
            take: 12,
            include: {
              createdBy: {
                select: {
                  id: true,
                  username: true,
                  displayName: true,
                  avatarUrl: true,
                },
              },
            },
          },
          _count: {
            select: {
              members: true,
            },
          },
        },
      }),
      prisma.squadMember.findUnique({
        where: {
          squadId_userId: {
            squadId,
            userId,
          },
        },
        select: { id: true, role: true, nickname: true, notificationsEnabled: true },
      }),
    ]);

    if (!squad) {
      res.status(404).json({ error: 'Squad not found' });
      return;
    }

    if (!squad.isPublic && !memberRow) {
      res.status(403).json({ error: 'Forbidden' });
      return;
    }

    const memberNicknameMap = new Map(squad.members.map((member) => [member.userId, member.nickname]));
    const memberIds = squad.members.map((member) => member.user.id);
    const followingSet = await buildFollowingMap(userId, [
      squad.leader.id,
      ...memberIds,
      ...squad.messages.map((message) => message.user.id),
      ...squad.activities.map((activity) => activity.createdBy.id),
    ]);

    const leaderNickname = memberNicknameMap.get(squad.leader.id);

    res.json({
      id: squad.id,
      name: squad.name,
      description: squad.description,
      avatarURL: squad.avatarUrl,
      bannerURL: squad.bannerUrl,
      notice: squad.notice || '',
      qrCodeURL: squad.qrCodeUrl,
      isPublic: squad.isPublic,
      maxMembers: squad.maxMembers,
      memberCount: squad._count.members,
      isMember: Boolean(memberRow),
      canEditGroup: Boolean(memberRow) && (canManageSquad(memberRow?.role) || squad.leaderId === userId),
      myRole: memberRow?.role ?? null,
      myNickname: memberRow?.nickname ?? null,
      myNotificationsEnabled: memberRow?.notificationsEnabled ?? null,
      leader: toUserSummaryWithNickname(
        squad.leader,
        followingSet.has(squad.leader.id),
        leaderNickname
      ),
      members: squad.members.map((member) => ({
        ...toUserSummaryWithNickname(member.user, followingSet.has(member.user.id), member.nickname),
        role: member.role,
        nickname: member.nickname,
        isCaptain: member.userId === squad.leaderId,
        isAdmin: canManageSquad(member.role),
      })),
      lastMessage: squad.messages[0]?.content ?? null,
      updatedAt: squad.messages[0]?.createdAt ?? squad.updatedAt,
      recentMessages: squad.messages.map((message) => ({
        id: message.id,
        content: message.content,
        createdAt: message.createdAt,
        sender: toUserSummaryWithNickname(
          message.user,
          followingSet.has(message.user.id),
          memberNicknameMap.get(message.user.id)
        ),
      })),
      activities: squad.activities.map((activity) => ({
        id: activity.id,
        title: activity.title,
        description: activity.description,
        location: activity.location,
        date: activity.date,
        createdBy: toUserSummary(activity.createdBy, followingSet.has(activity.createdBy.id)),
      })),
    });
  } catch (error) {
    console.error('BFF squad profile error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.post('/squads/:id/join', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const userId = requireAuth(req as BFFAuthRequest, res);
    if (!userId) return;

    const squadId = req.params.id as string;
    const squad = await prisma.squad.findUnique({
      where: { id: squadId },
      select: {
        id: true,
        isPublic: true,
        maxMembers: true,
      },
    });

    if (!squad) {
      res.status(404).json({ error: 'Squad not found' });
      return;
    }

    if (!squad.isPublic) {
      res.status(403).json({ error: 'This squad requires invitation' });
      return;
    }

    const existing = await prisma.squadMember.findUnique({
      where: {
        squadId_userId: {
          squadId,
          userId,
        },
      },
      select: { id: true },
    });

    if (existing) {
      res.json({ success: true, isMember: true });
      return;
    }

    const count = await prisma.squadMember.count({
      where: { squadId },
    });
    if (count >= squad.maxMembers) {
      res.status(400).json({ error: 'Squad is full' });
      return;
    }

    await prisma.squadMember.create({
      data: {
        squadId,
        userId,
        role: 'member',
        lastReadAt: new Date(),
      },
    });

    res.status(201).json({ success: true, isMember: true });
  } catch (error) {
    console.error('BFF join squad error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.post('/squads', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const userId = requireAuth(req as BFFAuthRequest, res);
    if (!userId) return;

    const body = req.body as {
      name?: unknown;
      description?: unknown;
      isPublic?: unknown;
      bannerURL?: unknown;
      memberIds?: unknown;
    };

    const normalizedMemberIds = Array.isArray(body.memberIds)
      ? Array.from(
          new Set(
            body.memberIds
              .filter((item): item is string => typeof item === 'string')
              .map((item) => item.trim())
              .filter((item) => item.length > 0 && item !== userId)
          )
        )
      : [];

    if (normalizedMemberIds.length > 0) {
      const friendIds = await buildFriendUserIds(userId, normalizedMemberIds);
      if (friendIds.size !== normalizedMemberIds.length) {
        res.status(403).json({ error: '只能从好友列表中选择小队成员' });
        return;
      }
    }

    const requestedName = typeof body.name === 'string' ? body.name.trim() : '';
    const requestedDescription = typeof body.description === 'string' ? body.description.trim() : '';
    const requestedIsPublic = typeof body.isPublic === 'boolean' ? body.isPublic : false;
    const requestedBannerURL = typeof body.bannerURL === 'string' ? body.bannerURL.trim() : '';
    const fallbackName = `${userId}+${Date.now()}创建的小队`;
    const finalName = requestedName || fallbackName;

    const created = await prisma.$transaction(async (tx) => {
      const squad = await tx.squad.create({
        data: {
          name: finalName,
          description: requestedDescription || null,
          bannerUrl: requestedBannerURL || null,
          leaderId: userId,
          isPublic: requestedIsPublic,
          maxMembers: 50,
        },
        select: {
          id: true,
          name: true,
          avatarUrl: true,
          updatedAt: true,
        },
      });

      await tx.squadMember.create({
        data: {
          squadId: squad.id,
          userId,
          role: 'leader',
          lastReadAt: new Date(),
        },
        select: { id: true },
      });

      if (normalizedMemberIds.length > 0) {
        await tx.squadMember.createMany({
          data: normalizedMemberIds.map((memberId) => ({
            squadId: squad.id,
            userId: memberId,
            role: 'member',
            lastReadAt: new Date(),
          })),
        });
      }

      return squad;
    });

    res.status(201).json({
      id: created.id,
      type: 'group',
      title: created.name,
      avatarURL: created.avatarUrl,
      lastMessage: '暂无消息',
      lastMessageSenderID: null,
      unreadCount: 0,
      updatedAt: created.updatedAt,
      peer: null,
    });
  } catch (error) {
    console.error('BFF create squad error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.post(
  '/squads/:id/avatar',
  optionalAuth,
  avatarUpload.single('avatar'),
  async (req: Request, res: Response): Promise<void> => {
    try {
      const userId = requireAuth(req as BFFAuthRequest, res);
      if (!userId) return;

      const squadId = req.params.id as string;
      const file = (req as Request & { file?: Express.Multer.File }).file;
      if (!file) {
        res.status(400).json({ error: 'No file uploaded' });
        return;
      }

      const membership = await prisma.squadMember.findUnique({
        where: {
          squadId_userId: {
            squadId,
            userId,
          },
        },
        select: {
          role: true,
        },
      });

      if (!membership || !canManageSquad(membership.role)) {
        res.status(403).json({ error: 'Only admin/captain can edit squad avatar' });
        return;
      }

      const avatarUrl = `/uploads/avatars/${file.filename}`;
      await prisma.squad.update({
        where: { id: squadId },
        data: { avatarUrl },
        select: { id: true },
      });

      res.status(201).json({ avatarURL: avatarUrl });
    } catch (error) {
      console.error('BFF upload squad avatar error:', error);
      res.status(500).json({ error: 'Internal server error' });
    }
  }
);

router.patch('/squads/:id/my-settings', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const userId = requireAuth(req as BFFAuthRequest, res);
    if (!userId) return;

    const squadId = req.params.id as string;
    const membership = await prisma.squadMember.findUnique({
      where: {
        squadId_userId: {
          squadId,
          userId,
        },
      },
      select: {
        id: true,
        nickname: true,
        notificationsEnabled: true,
      },
    });

    if (!membership) {
      res.status(403).json({ error: 'Forbidden' });
      return;
    }

    const body = req.body as { nickname?: unknown; notificationsEnabled?: unknown };
    const data: { nickname?: string | null; notificationsEnabled?: boolean } = {};

    if (typeof body.nickname === 'string') {
      const trimmed = body.nickname.trim();
      data.nickname = trimmed || null;
    }

    if (typeof body.notificationsEnabled === 'boolean') {
      data.notificationsEnabled = body.notificationsEnabled;
    }

    const updated =
      Object.keys(data).length === 0
        ? membership
        : await prisma.squadMember.update({
            where: {
              squadId_userId: {
                squadId,
                userId,
              },
            },
            data,
            select: {
              id: true,
              nickname: true,
              notificationsEnabled: true,
            },
          });

    res.json({
      success: true,
      nickname: updated.nickname,
      notificationsEnabled: updated.notificationsEnabled,
    });
  } catch (error) {
    console.error('BFF update squad my settings error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.patch('/squads/:id/manage', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const userId = requireAuth(req as BFFAuthRequest, res);
    if (!userId) return;

    const squadId = req.params.id as string;
    const [squad, membership] = await Promise.all([
      prisma.squad.findUnique({
        where: { id: squadId },
        select: { leaderId: true },
      }),
      prisma.squadMember.findUnique({
        where: {
          squadId_userId: {
            squadId,
            userId,
          },
        },
        select: {
          role: true,
        },
      }),
    ]);

    if (!squad) {
      res.status(404).json({ error: 'Squad not found' });
      return;
    }

    if (!membership || (!canManageSquad(membership.role) && squad.leaderId !== userId)) {
      res.status(403).json({ error: 'Only admin/captain can edit group settings' });
      return;
    }

    const body = req.body as {
      name?: unknown;
      description?: unknown;
      isPublic?: unknown;
      avatarURL?: unknown;
      bannerURL?: unknown;
      notice?: unknown;
      qrCodeURL?: unknown;
    };

    const data: {
      name?: string;
      description?: string | null;
      isPublic?: boolean;
      avatarUrl?: string | null;
      bannerUrl?: string | null;
      notice?: string | null;
      qrCodeUrl?: string | null;
    } = {};

    if (typeof body.name === 'string') {
      const trimmedName = body.name.trim();
      if (!trimmedName) {
        res.status(400).json({ error: 'name cannot be empty' });
        return;
      }
      data.name = trimmedName;
    }

    if (typeof body.description === 'string') {
      const trimmedDescription = body.description.trim();
      data.description = trimmedDescription || null;
    }

    if (typeof body.isPublic === 'boolean') {
      data.isPublic = body.isPublic;
    }

    if (typeof body.avatarURL === 'string') {
      const trimmedAvatar = body.avatarURL.trim();
      data.avatarUrl = trimmedAvatar || null;
    }

    if (typeof body.bannerURL === 'string') {
      const trimmedBanner = body.bannerURL.trim();
      data.bannerUrl = trimmedBanner || null;
    }

    if (typeof body.notice === 'string') {
      const trimmedNotice = body.notice.trim();
      data.notice = trimmedNotice || null;
    }

    if (typeof body.qrCodeURL === 'string') {
      const trimmedQrCode = body.qrCodeURL.trim();
      data.qrCodeUrl = trimmedQrCode || null;
    }

    if (Object.keys(data).length > 0) {
      await prisma.squad.update({
        where: { id: squadId },
        data,
        select: { id: true },
      });
    }

    res.json({ success: true });
  } catch (error) {
    console.error('BFF update squad manage error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.post('/feed/posts', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const userId = requireAuth(req as BFFAuthRequest, res);
    if (!userId) return;

    const body = (req.body ?? {}) as Record<string, unknown>;
    const { content, images, squadId, location } = body as {
      content?: string;
      images?: string[];
      squadId?: string;
      location?: string;
    };

    const normalizedImages = Array.isArray(images)
      ? images.filter((url): url is string => typeof url === 'string' && !!url.trim())
      : [];
    const normalizedLocation = typeof location === 'string' ? location.trim().slice(0, 160) : '';
    const normalizedBoundDjIDs = normalizePostBindingIDs(
      body.boundDjIDs ?? body.boundDjIds ?? body.boundDJIDs ?? body.bound_dj_ids
    );
    const normalizedBoundBrandIDs = normalizePostBindingIDs(
      body.boundBrandIDs ?? body.boundBrandIds ?? body.bound_brand_ids
    );
    const normalizedBoundEventIDs = normalizePostBindingIDs(
      body.boundEventIDs ?? body.boundEventIds ?? body.bound_event_ids
    );
    const trimmed = String(content || '').trim();
    if (!trimmed && normalizedImages.length === 0) {
      res.status(400).json({ error: 'content or images is required' });
      return;
    }

    let linkedSquadId: string | null = null;
    if (typeof squadId === 'string' && squadId.trim()) {
      const squad = await prisma.squad.findUnique({
        where: { id: squadId.trim() },
        select: { id: true },
      });
      if (!squad) {
        res.status(404).json({ error: 'Squad not found' });
        return;
      }

      const membership = await prisma.squadMember.findUnique({
        where: {
          squadId_userId: {
            squadId: squad.id,
            userId,
          },
        },
        select: { id: true },
      });

      if (!membership) {
        res.status(403).json({ error: 'Join squad before posting to it' });
        return;
      }
      linkedSquadId = squad.id;
    }

    const created = await prisma.post.create({
      data: {
        userId,
        squadId: linkedSquadId,
        content: trimmed,
        images: normalizedImages,
        location: normalizedLocation || null,
        type: linkedSquadId ? 'squad' : 'general',
        visibility: 'public',
        boundDjIds: normalizedBoundDjIDs,
        boundBrandIds: normalizedBoundBrandIDs,
        boundEventIds: normalizedBoundEventIDs,
      } as any,
      include: {
        user: {
          select: {
            id: true,
            username: true,
            displayName: true,
            avatarUrl: true,
          },
        },
        squad: {
          select: {
            id: true,
            name: true,
            avatarUrl: true,
          },
        },
      },
    });

    const followingSet = await buildFollowingMap(userId, [created.user.id]);
    const mapped = mapPost(created, followingSet, new Set<string>(), new Set<string>());
    res.status(201).json(mapped);
  } catch (error) {
    console.error('BFF create post error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.patch('/feed/posts/:id', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const authReq = req as BFFAuthRequest;
    const userId = requireAuth(authReq, res);
    if (!userId) return;

    const postId = req.params.id as string;
    const body = (req.body ?? {}) as Record<string, unknown>;
    const { content, images, location } = body as {
      content?: string;
      images?: string[];
      location?: string;
    };
    const boundDjIDs = body.boundDjIDs ?? body.boundDjIds ?? body.boundDJIDs ?? body.bound_dj_ids;
    const boundBrandIDs = body.boundBrandIDs ?? body.boundBrandIds ?? body.bound_brand_ids;
    const boundEventIDs = body.boundEventIDs ?? body.boundEventIds ?? body.bound_event_ids;

    const hasContent = typeof content === 'string';
    const hasImages = Array.isArray(images);
    const hasLocation = typeof location === 'string';
    const hasBoundDjIDs = Array.isArray(boundDjIDs);
    const hasBoundBrandIDs = Array.isArray(boundBrandIDs);
    const hasBoundEventIDs = Array.isArray(boundEventIDs);
    if (!hasContent && !hasImages && !hasLocation && !hasBoundDjIDs && !hasBoundBrandIDs && !hasBoundEventIDs) {
      res.status(400).json({ error: 'content, images, location or binding fields is required' });
      return;
    }

    const existing = await prisma.post.findUnique({
      where: { id: postId },
      include: {
        user: {
          select: {
            id: true,
            username: true,
            displayName: true,
            avatarUrl: true,
          },
        },
        squad: {
          select: {
            id: true,
            name: true,
            avatarUrl: true,
          },
        },
      },
    });

    if (!existing) {
      res.status(404).json({ error: 'Post not found' });
      return;
    }

    if (authReq.user?.role !== 'admin' && existing.userId !== userId) {
      res.status(403).json({ error: 'Forbidden' });
      return;
    }

    const nextContent = hasContent ? String(content || '').trim() : existing.content;
    const nextImages = hasImages
      ? (images as unknown[])
          .filter((url): url is string => typeof url === 'string')
          .map((url) => url.trim())
          .filter(Boolean)
      : existing.images;

    if (!nextContent && nextImages.length === 0) {
      res.status(400).json({ error: 'content or images is required' });
      return;
    }

    const updateData: {
      content?: string;
      images?: string[];
      location?: string | null;
      boundDjIds?: string[];
      boundBrandIds?: string[];
      boundEventIds?: string[];
    } = {};
    if (hasContent) {
      updateData.content = nextContent;
    }
    if (hasImages) {
      updateData.images = nextImages;
    }
    if (hasLocation) {
      const normalizedLocation = String(location || '').trim().slice(0, 160);
      updateData.location = normalizedLocation || null;
    }
    if (hasBoundDjIDs) {
      updateData.boundDjIds = normalizePostBindingIDs(boundDjIDs);
    }
    if (hasBoundBrandIDs) {
      updateData.boundBrandIds = normalizePostBindingIDs(boundBrandIDs);
    }
    if (hasBoundEventIDs) {
      updateData.boundEventIds = normalizePostBindingIDs(boundEventIDs);
    }

    const updated =
      Object.keys(updateData).length > 0
        ? await prisma.post.update({
            where: { id: postId },
            data: updateData as any,
            include: {
              user: {
                select: {
                  id: true,
                  username: true,
                  displayName: true,
                  avatarUrl: true,
                },
              },
              squad: {
                select: {
                  id: true,
                  name: true,
                  avatarUrl: true,
                },
              },
            },
          })
        : existing;

    if (hasImages) {
      const newImageSet = new Set(nextImages);
      const removedImages = existing.images.filter((url) => !newImageSet.has(url));
      if (removedImages.length > 0) {
        const { failedKeys } = await deletePostMediaFromOss(removedImages);
        if (failedKeys.length > 0) {
          console.warn('BFF update post OSS cleanup failed keys:', failedKeys);
        }
      }
    }

    const followingSet = await buildFollowingMap(userId, [updated.user.id]);
    const likedPostIds = await buildLikedPostMap(userId, [updated.id]);
    const repostedPostIds = await buildRepostedPostMap(userId, [updated.id]);
    const mapped = mapPost(updated, followingSet, likedPostIds, repostedPostIds);
    res.json(mapped);
  } catch (error) {
    console.error('BFF update post error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.delete('/feed/posts/:id', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const authReq = req as BFFAuthRequest;
    const userId = requireAuth(authReq, res);
    if (!userId) return;

    const postId = req.params.id as string;
    const post = await prisma.post.findUnique({
      where: { id: postId },
      select: { id: true, userId: true, images: true },
    });

    if (!post) {
      res.status(404).json({ error: 'Post not found' });
      return;
    }

    if (authReq.user?.role !== 'admin' && post.userId !== userId) {
      res.status(403).json({ error: 'Forbidden' });
      return;
    }

    await prisma.post.delete({ where: { id: postId } });

    const { deletedKeys, failedKeys } = await deletePostMediaFromOss(post.images);

    res.json({
      success: true,
      deletedPostId: postId,
      deletedMediaCount: deletedKeys.length,
      cleanupFailedCount: failedKeys.length,
      cleanupFailedKeys: failedKeys,
    });
  } catch (error) {
    console.error('BFF delete post error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.post('/feed/posts/:id/like', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const userId = requireAuth(req as BFFAuthRequest, res);
    if (!userId) return;

    const postId = req.params.id as string;
    const post = await prisma.post.findUnique({ where: { id: postId }, select: { id: true } });
    if (!post) {
      res.status(404).json({ error: 'Post not found' });
      return;
    }

    await prisma.$transaction(async (tx) => {
      const existing = await tx.postLike.findUnique({
        where: {
          postId_userId: {
            postId,
            userId,
          },
        },
      });

      if (!existing) {
        await tx.postLike.create({
          data: {
            postId,
            userId,
          },
        });

        await tx.post.update({
          where: { id: postId },
          data: { likeCount: { increment: 1 } },
        });
      }
    });

    const hydrated = await prisma.post.findUnique({
      where: { id: postId },
      include: {
        user: {
          select: {
            id: true,
            username: true,
            displayName: true,
            avatarUrl: true,
          },
        },
        squad: {
          select: {
            id: true,
            name: true,
            avatarUrl: true,
          },
        },
      },
    });

    if (!hydrated) {
      res.status(404).json({ error: 'Post not found' });
      return;
    }

    const [followingSet, repostedPostIds] = await Promise.all([
      buildFollowingMap(userId, [hydrated.user.id]),
      buildRepostedPostMap(userId, [postId]),
    ]);
    const mapped = mapPost(hydrated, followingSet, new Set([postId]), repostedPostIds);
    res.json(mapped);
  } catch (error) {
    console.error('BFF like post error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.delete('/feed/posts/:id/like', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const userId = requireAuth(req as BFFAuthRequest, res);
    if (!userId) return;

    const postId = req.params.id as string;

    await prisma.$transaction(async (tx) => {
      const existing = await tx.postLike.findUnique({
        where: {
          postId_userId: {
            postId,
            userId,
          },
        },
      });

      if (existing) {
        await tx.postLike.delete({ where: { id: existing.id } });
        await tx.post.update({
          where: { id: postId },
          data: {
            likeCount: {
              decrement: 1,
            },
          },
        });
      }
    });

    const hydrated = await prisma.post.findUnique({
      where: { id: postId },
      include: {
        user: {
          select: {
            id: true,
            username: true,
            displayName: true,
            avatarUrl: true,
          },
        },
        squad: {
          select: {
            id: true,
            name: true,
            avatarUrl: true,
          },
        },
      },
    });

    if (!hydrated) {
      res.status(404).json({ error: 'Post not found' });
      return;
    }

    const [followingSet, repostedPostIds] = await Promise.all([
      buildFollowingMap(userId, [hydrated.user.id]),
      buildRepostedPostMap(userId, [postId]),
    ]);
    const mapped = mapPost(hydrated, followingSet, new Set<string>(), repostedPostIds);
    res.json(mapped);
  } catch (error) {
    console.error('BFF unlike post error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.post('/feed/posts/:id/repost', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const userId = requireAuth(req as BFFAuthRequest, res);
    if (!userId) return;

    const postId = req.params.id as string;
    const post = await prisma.post.findUnique({ where: { id: postId }, select: { id: true } });
    if (!post) {
      res.status(404).json({ error: 'Post not found' });
      return;
    }

    await prisma.$transaction(async (tx) => {
      const existing = await tx.postRepost.findUnique({
        where: {
          postId_userId: {
            postId,
            userId,
          },
        },
      });

      if (!existing) {
        await tx.postRepost.create({
          data: {
            postId,
            userId,
          },
        });
        await tx.post.update({
          where: { id: postId },
          data: {
            repostCount: {
              increment: 1,
            },
          },
        });
      }
    });

    const hydrated = await prisma.post.findUnique({
      where: { id: postId },
      include: {
        user: {
          select: {
            id: true,
            username: true,
            displayName: true,
            avatarUrl: true,
          },
        },
        squad: {
          select: {
            id: true,
            name: true,
            avatarUrl: true,
          },
        },
      },
    });

    if (!hydrated) {
      res.status(404).json({ error: 'Post not found' });
      return;
    }

    const [followingSet, likedPostIds] = await Promise.all([
      buildFollowingMap(userId, [hydrated.user.id]),
      buildLikedPostMap(userId, [postId]),
    ]);
    const mapped = mapPost(hydrated, followingSet, likedPostIds, new Set([postId]));
    res.json(mapped);
  } catch (error) {
    console.error('BFF repost post error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.delete('/feed/posts/:id/repost', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const userId = requireAuth(req as BFFAuthRequest, res);
    if (!userId) return;

    const postId = req.params.id as string;

    await prisma.$transaction(async (tx) => {
      const existing = await tx.postRepost.findUnique({
        where: {
          postId_userId: {
            postId,
            userId,
          },
        },
      });

      if (existing) {
        await tx.postRepost.delete({
          where: {
            id: existing.id,
          },
        });
        await tx.post.updateMany({
          where: {
            id: postId,
            repostCount: { gt: 0 },
          },
          data: {
            repostCount: {
              decrement: 1,
            },
          },
        });
      }
    });

    const hydrated = await prisma.post.findUnique({
      where: { id: postId },
      include: {
        user: {
          select: {
            id: true,
            username: true,
            displayName: true,
            avatarUrl: true,
          },
        },
        squad: {
          select: {
            id: true,
            name: true,
            avatarUrl: true,
          },
        },
      },
    });

    if (!hydrated) {
      res.status(404).json({ error: 'Post not found' });
      return;
    }

    const [followingSet, likedPostIds] = await Promise.all([
      buildFollowingMap(userId, [hydrated.user.id]),
      buildLikedPostMap(userId, [postId]),
    ]);
    const mapped = mapPost(hydrated, followingSet, likedPostIds, new Set<string>());
    res.json(mapped);
  } catch (error) {
    console.error('BFF unrepost post error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.get('/feed/posts/:id/comments', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const viewerId = (req as BFFAuthRequest).user?.userId;
    const postId = req.params.id as string;

    const comments = await prisma.postComment.findMany({
      where: { postId },
      include: {
        user: {
          select: {
            id: true,
            username: true,
            displayName: true,
            avatarUrl: true,
          },
        },
      },
      orderBy: { createdAt: 'asc' },
    });

    const authorIds = Array.from(new Set(comments.map((comment) => comment.user.id)));
    const followingSet = await buildFollowingMap(viewerId, authorIds);

    res.json(
      comments.map((comment) => ({
        id: comment.id,
        postID: comment.postId,
        author: toUserSummary(comment.user, followingSet.has(comment.user.id)),
        content: comment.content,
        createdAt: comment.createdAt,
      }))
    );
  } catch (error) {
    console.error('BFF comments error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.post('/feed/posts/:id/comments', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const userId = requireAuth(req as BFFAuthRequest, res);
    if (!userId) return;

    const postId = req.params.id as string;
    const content = String((req.body as { content?: string }).content || '').trim();

    if (!content) {
      res.status(400).json({ error: 'content is required' });
      return;
    }

    const exists = await prisma.post.findUnique({ where: { id: postId }, select: { id: true } });
    if (!exists) {
      res.status(404).json({ error: 'Post not found' });
      return;
    }

    const comment = await prisma.$transaction(async (tx) => {
      const created = await tx.postComment.create({
        data: {
          postId,
          userId,
          content,
        },
        include: {
          user: {
            select: {
              id: true,
              username: true,
              displayName: true,
              avatarUrl: true,
            },
          },
        },
      });

      await tx.post.update({
        where: { id: postId },
        data: { commentCount: { increment: 1 } },
      });

      return created;
    });

    res.status(201).json({
      id: comment.id,
      postID: comment.postId,
      author: toUserSummary(comment.user, false),
      content: comment.content,
      createdAt: comment.createdAt,
    });
  } catch (error) {
    console.error('BFF add comment error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.get('/chat/conversations', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const userId = requireAuth(req as BFFAuthRequest, res);
    if (!userId) return;

    const type = String(req.query.type || 'group');
    const limit = normalizeLimit(req.query.limit, 50, 200);

    if (type === 'direct') {
      const directConversations = await prisma.directConversation.findMany({
        where: {
          OR: [{ userAId: userId }, { userBId: userId }],
        },
        include: {
          userA: {
            select: {
              id: true,
              username: true,
              displayName: true,
              avatarUrl: true,
            },
          },
          userB: {
            select: {
              id: true,
              username: true,
              displayName: true,
              avatarUrl: true,
            },
          },
          messages: {
            orderBy: { createdAt: 'desc' },
            take: 1,
            select: {
              content: true,
              createdAt: true,
              senderId: true,
              sender: {
                select: { username: true },
              },
            },
          },
        },
        orderBy: { updatedAt: 'desc' },
        take: limit,
      });

      const conversationIds = directConversations.map((conversation) => conversation.id);
      const readRows =
        conversationIds.length === 0
          ? []
          : await prisma.directConversationRead.findMany({
              where: {
                userId,
                conversationId: { in: conversationIds },
              },
              select: {
                conversationId: true,
                lastReadAt: true,
              },
            });

      const readMap = new Map(readRows.map((row) => [row.conversationId, row.lastReadAt]));
      const unreadPairs = await Promise.all(
        directConversations.map(async (conversation) => {
          const lastReadAt = readMap.get(conversation.id);
          const unreadCount = await prisma.directMessage.count({
            where: {
              conversationId: conversation.id,
              senderId: { not: userId },
              ...(lastReadAt ? { createdAt: { gt: lastReadAt } } : {}),
            },
          });
          return [conversation.id, unreadCount] as const;
        })
      );
      const unreadMap = new Map(unreadPairs);

      const mapped = await Promise.all(
        directConversations.map((conversation) =>
          mapDirectConversation(conversation, userId, unreadMap.get(conversation.id) ?? 0)
        )
      );

      res.json(mapped);
      return;
    }

    const memberships = await prisma.squadMember.findMany({
      where: { userId },
      select: {
        lastReadAt: true,
        squad: {
          select: {
            id: true,
            name: true,
            avatarUrl: true,
            updatedAt: true,
            messages: {
              orderBy: { createdAt: 'desc' },
              take: 1,
              select: {
                content: true,
                createdAt: true,
                userId: true,
                user: {
                  select: { username: true },
                },
              },
            },
          },
        },
      },
    });

    const unreadPairs = await Promise.all(
      memberships.map(async (membership) => {
        const unreadCount = await prisma.squadMessage.count({
          where: {
            squadId: membership.squad.id,
            userId: { not: userId },
            ...(membership.lastReadAt ? { createdAt: { gt: membership.lastReadAt } } : {}),
          },
        });
        return [membership.squad.id, unreadCount] as const;
      })
    );
    const unreadMap = new Map(unreadPairs);

    const conversations = memberships
      .map((membership) => mapGroupConversation(membership.squad, unreadMap.get(membership.squad.id) ?? 0))
      .sort((a, b) => b.updatedAt.getTime() - a.updatedAt.getTime());

    res.json(conversations);
  } catch (error) {
    console.error('BFF conversations error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.post('/chat/conversations/:id/read', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const userId = requireAuth(req as BFFAuthRequest, res);
    if (!userId) return;

    const conversationId = req.params.id as string;
    const readAt = new Date();

    const directConversation = await prisma.directConversation.findFirst({
      where: {
        id: conversationId,
        OR: [{ userAId: userId }, { userBId: userId }],
      },
      select: { id: true },
    });

    if (directConversation) {
      await prisma.directConversationRead.upsert({
        where: {
          conversationId_userId: {
            conversationId,
            userId,
          },
        },
        update: { lastReadAt: readAt },
        create: {
          conversationId,
          userId,
          lastReadAt: readAt,
        },
      });
      res.json({ success: true, readAt });
      return;
    }

    const membership = await prisma.squadMember.findUnique({
      where: {
        squadId_userId: {
          squadId: conversationId,
          userId,
        },
      },
      select: { id: true },
    });

    if (!membership) {
      res.status(404).json({ error: 'Conversation not found' });
      return;
    }

    await prisma.squadMember.update({
      where: {
        squadId_userId: {
          squadId: conversationId,
          userId,
        },
      },
      data: { lastReadAt: readAt },
    });

    res.json({ success: true, readAt });
  } catch (error) {
    console.error('BFF mark conversation read error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.post('/chat/direct/start', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const userId = requireAuth(req as BFFAuthRequest, res);
    if (!userId) return;

    const { identifier, userId: targetUserId, username } = req.body as {
      identifier?: string;
      userId?: string;
      username?: string;
    };

    const lookupIdentifier = String(targetUserId || identifier || username || '').trim();
    if (!lookupIdentifier) {
      res.status(400).json({ error: 'identifier is required' });
      return;
    }

    const target = await prisma.user.findFirst({
      where: {
        isActive: true,
        OR: [
          { id: lookupIdentifier },
          { username: { equals: lookupIdentifier, mode: 'insensitive' } },
          { email: { equals: lookupIdentifier, mode: 'insensitive' } },
        ],
      },
      select: {
        id: true,
        username: true,
        displayName: true,
        avatarUrl: true,
      },
    });

    if (!target) {
      res.status(404).json({ error: 'Target user not found' });
      return;
    }

    if (target.id === userId) {
      res.status(400).json({ error: 'Cannot start direct chat with yourself' });
      return;
    }

    const [userAId, userBId] = normalizeDirectPair(userId, target.id);

    const conversation = await prisma.directConversation.upsert({
      where: {
        userAId_userBId: { userAId, userBId },
      },
      update: {
        updatedAt: new Date(),
      },
      create: {
        userAId,
        userBId,
      },
      include: {
        userA: {
          select: {
            id: true,
            username: true,
            displayName: true,
            avatarUrl: true,
          },
        },
        userB: {
          select: {
            id: true,
            username: true,
            displayName: true,
            avatarUrl: true,
          },
        },
        messages: {
          orderBy: { createdAt: 'desc' },
          take: 1,
          select: {
            content: true,
            createdAt: true,
            senderId: true,
            sender: {
              select: { username: true },
            },
          },
        },
      },
    });

    await prisma.directConversationRead.upsert({
      where: {
        conversationId_userId: {
          conversationId: conversation.id,
          userId,
        },
      },
      update: { lastReadAt: new Date() },
      create: {
        conversationId: conversation.id,
        userId,
      },
    });

    const mapped = await mapDirectConversation(conversation, userId);
    res.status(201).json(mapped);
  } catch (error) {
    console.error('BFF start direct conversation error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.get('/chat/conversations/:id/messages', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const userId = requireAuth(req as BFFAuthRequest, res);
    if (!userId) return;

    const conversationId = req.params.id as string;
    const limit = normalizeLimit(req.query.limit, 50, 200);

    const directConversation = await prisma.directConversation.findFirst({
      where: {
        id: conversationId,
        OR: [{ userAId: userId }, { userBId: userId }],
      },
      select: { id: true },
    });

    if (directConversation) {
      const messages = await prisma.directMessage.findMany({
        where: { conversationId },
        include: {
          sender: {
            select: {
              id: true,
              username: true,
              displayName: true,
              avatarUrl: true,
            },
          },
        },
        orderBy: { createdAt: 'asc' },
        take: limit,
      });

      const senderIds = Array.from(new Set(messages.map((msg) => msg.sender.id)));
      const followingSet = await buildFollowingMap(userId, senderIds);

      await prisma.directConversationRead.upsert({
        where: {
          conversationId_userId: {
            conversationId,
            userId,
          },
        },
        update: { lastReadAt: new Date() },
        create: {
          conversationId,
          userId,
        },
      });

      res.json(
        messages.map((message) => ({
          id: message.id,
          conversationID: conversationId,
          sender: toUserSummary(message.sender, followingSet.has(message.sender.id)),
          content: message.content,
          createdAt: message.createdAt,
          isMine: message.senderId === userId,
        }))
      );
      return;
    }

    const membership = await prisma.squadMember.findUnique({
      where: {
        squadId_userId: {
          squadId: conversationId,
          userId,
        },
      },
      select: { id: true, nickname: true },
    });

    if (!membership) {
      res.status(403).json({ error: 'Forbidden' });
      return;
    }

    const messages = await prisma.squadMessage.findMany({
      where: { squadId: conversationId },
      include: {
        user: {
          select: {
            id: true,
            username: true,
            displayName: true,
            avatarUrl: true,
          },
        },
      },
      orderBy: { createdAt: 'asc' },
      take: limit,
    });

    const senderIds = Array.from(new Set(messages.map((msg) => msg.user.id)));
    const [followingSet, squadMembers] = await Promise.all([
      buildFollowingMap(userId, senderIds),
      prisma.squadMember.findMany({
        where: {
          squadId: conversationId,
          userId: {
            in: senderIds,
          },
        },
        select: {
          userId: true,
          nickname: true,
        },
      }),
    ]);
    const nicknameMap = new Map(squadMembers.map((item) => [item.userId, item.nickname]));

    await prisma.squadMember.update({
      where: {
        squadId_userId: {
          squadId: conversationId,
          userId,
        },
      },
      data: { lastReadAt: new Date() },
    });

    res.json(
      messages.map((message) => ({
        id: message.id,
        conversationID: conversationId,
        sender: toUserSummaryWithNickname(
          message.user,
          followingSet.has(message.user.id),
          nicknameMap.get(message.user.id)
        ),
        content: message.content,
        createdAt: message.createdAt,
        isMine: message.userId === userId,
      }))
    );
  } catch (error) {
    console.error('BFF messages error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.post('/chat/conversations/:id/messages', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const userId = requireAuth(req as BFFAuthRequest, res);
    if (!userId) return;

    const conversationId = req.params.id as string;
    const content = String((req.body as { content?: string }).content || '').trim();

    if (!content) {
      res.status(400).json({ error: 'content is required' });
      return;
    }

    const directConversation = await prisma.directConversation.findFirst({
      where: {
        id: conversationId,
        OR: [{ userAId: userId }, { userBId: userId }],
      },
      select: { id: true },
    });

    if (directConversation) {
      const created = await prisma.$transaction(async (tx) => {
        const message = await tx.directMessage.create({
          data: {
            conversationId,
            senderId: userId,
            content,
            type: 'text',
          },
          include: {
            sender: {
              select: {
                id: true,
                username: true,
                displayName: true,
                avatarUrl: true,
              },
            },
          },
        });

        await tx.directConversation.update({
          where: { id: conversationId },
          data: { updatedAt: new Date() },
        });

        await tx.directConversationRead.upsert({
          where: {
            conversationId_userId: {
              conversationId,
              userId,
            },
          },
          update: { lastReadAt: new Date() },
          create: {
            conversationId,
            userId,
          },
        });

        return message;
      });

      res.status(201).json({
        id: created.id,
        conversationID: conversationId,
        sender: toUserSummary(created.sender, false),
        content: created.content,
        createdAt: created.createdAt,
        isMine: true,
      });
      return;
    }

    const membership = await prisma.squadMember.findUnique({
      where: {
        squadId_userId: {
          squadId: conversationId,
          userId,
        },
      },
      select: { id: true, nickname: true },
    });

    if (!membership) {
      res.status(403).json({ error: 'Forbidden' });
      return;
    }

    const created = await prisma.squadMessage.create({
      data: {
        squadId: conversationId,
        userId,
        content,
        type: 'text',
      },
      include: {
        user: {
          select: {
            id: true,
            username: true,
            displayName: true,
            avatarUrl: true,
          },
        },
      },
    });

    await prisma.squadMember.update({
      where: {
        squadId_userId: {
          squadId: conversationId,
          userId,
        },
      },
      data: { lastReadAt: new Date() },
    });

    res.status(201).json({
      id: created.id,
      conversationID: conversationId,
      sender: toUserSummaryWithNickname(created.user, false, membership.nickname),
      content: created.content,
      createdAt: created.createdAt,
      isMine: true,
    });
  } catch (error) {
    console.error('BFF send message error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.get('/profile/me', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const userId = requireAuth(req as BFFAuthRequest, res);
    if (!userId) return;

    const [user, followersCount, followingCount, postsCount, friendIds] = await Promise.all([
      prisma.user.findUnique({
        where: { id: userId },
        select: {
          id: true,
          username: true,
          displayName: true,
          bio: true,
          avatarUrl: true,
          favoriteGenres: true,
          isFollowersListPublic: true,
          isFollowingListPublic: true,
        },
      }),
      prisma.follow.count({
        where: {
          followingId: userId,
          type: 'user',
        },
      }),
      prisma.follow.count({
        where: {
          followerId: userId,
          type: 'user',
          followingId: { not: null },
        },
      }),
      prisma.post.count({
        where: { userId },
      }),
      buildFriendUserIds(userId),
    ]);

    if (!user) {
      res.status(404).json({ error: 'User not found' });
      return;
    }

    res.json({
      id: user.id,
      username: user.username,
      displayName: user.displayName || user.username,
      bio: user.bio || '',
      avatarURL: user.avatarUrl,
      tags: user.favoriteGenres,
      isFollowersListPublic: user.isFollowersListPublic,
      isFollowingListPublic: user.isFollowingListPublic,
      canViewFollowersList: true,
      canViewFollowingList: true,
      followersCount,
      followingCount,
      friendsCount: friendIds.size,
      postsCount,
      isFollowing: false,
    });
  } catch (error) {
    console.error('BFF profile error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.patch('/profile/me', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const userId = requireAuth(req as BFFAuthRequest, res);
    if (!userId) return;

    const body = req.body as {
      displayName?: string;
      bio?: string;
      tags?: unknown;
      isFollowersListPublic?: boolean;
      isFollowingListPublic?: boolean;
    };

    const data: {
      displayName?: string;
      bio?: string;
      favoriteGenres?: string[];
      isFollowersListPublic?: boolean;
      isFollowingListPublic?: boolean;
    } = {};

    if (typeof body.displayName === 'string') {
      const trimmed = body.displayName.trim();
      if (!trimmed) {
        res.status(400).json({ error: 'displayName cannot be empty' });
        return;
      }
      data.displayName = trimmed;
    }

    if (typeof body.bio === 'string') {
      data.bio = body.bio.trim();
    }

    if (body.tags !== undefined) {
      data.favoriteGenres = normalizeTags(body.tags);
    }

    if (typeof body.isFollowersListPublic === 'boolean') {
      data.isFollowersListPublic = body.isFollowersListPublic;
    }

    if (typeof body.isFollowingListPublic === 'boolean') {
      data.isFollowingListPublic = body.isFollowingListPublic;
    }

    if (Object.keys(data).length > 0) {
      await prisma.user.update({
        where: { id: userId },
        data,
        select: { id: true },
      });
    }

    const [user, followersCount, followingCount, postsCount, friendIds] = await Promise.all([
      prisma.user.findUnique({
        where: { id: userId },
        select: {
          id: true,
          username: true,
          displayName: true,
          bio: true,
          avatarUrl: true,
          favoriteGenres: true,
          isFollowersListPublic: true,
          isFollowingListPublic: true,
        },
      }),
      prisma.follow.count({
        where: {
          followingId: userId,
          type: 'user',
        },
      }),
      prisma.follow.count({
        where: {
          followerId: userId,
          type: 'user',
          followingId: { not: null },
        },
      }),
      prisma.post.count({
        where: { userId },
      }),
      buildFriendUserIds(userId),
    ]);

    if (!user) {
      res.status(404).json({ error: 'User not found' });
      return;
    }

    res.json({
      id: user.id,
      username: user.username,
      displayName: user.displayName || user.username,
      bio: user.bio || '',
      avatarURL: user.avatarUrl,
      tags: user.favoriteGenres,
      isFollowersListPublic: user.isFollowersListPublic,
      isFollowingListPublic: user.isFollowingListPublic,
      canViewFollowersList: true,
      canViewFollowingList: true,
      followersCount,
      followingCount,
      friendsCount: friendIds.size,
      postsCount,
      isFollowing: false,
    });
  } catch (error) {
    console.error('BFF update profile error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.post(
  '/profile/me/avatar',
  optionalAuth,
  avatarUpload.single('avatar'),
  async (req: Request, res: Response): Promise<void> => {
    try {
      const userId = requireAuth(req as BFFAuthRequest, res);
      if (!userId) return;

      const file = (req as Request & { file?: Express.Multer.File }).file;
      if (!file) {
        res.status(400).json({ error: 'No file uploaded' });
        return;
      }

      const avatarUrl = `/uploads/avatars/${file.filename}`;
      await prisma.user.update({
        where: { id: userId },
        data: { avatarUrl },
        select: { id: true },
      });

      res.status(201).json({ avatarURL: avatarUrl });
    } catch (error) {
      console.error('BFF upload avatar error:', error);
      res.status(500).json({ error: 'Internal server error' });
    }
  }
);

router.get('/profile/me/likes', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const userId = requireAuth(req as BFFAuthRequest, res);
    if (!userId) return;

    const limit = normalizeLimit(req.query.limit, 20, 50);
    const cursorDate = parseCursorDate(req.query.cursor);

    const likes = await prisma.postLike.findMany({
      where: {
        userId,
        ...(cursorDate
          ? {
              createdAt: {
                lt: cursorDate,
              },
            }
          : {}),
      },
      include: {
        post: {
          include: {
            user: {
              select: {
                id: true,
                username: true,
                displayName: true,
                avatarUrl: true,
              },
            },
            squad: {
              select: {
                id: true,
                name: true,
                avatarUrl: true,
              },
            },
          },
        },
      },
      orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
      take: limit + 1,
    });

    const hasMore = likes.length > limit;
    const pageLikes = hasMore ? likes.slice(0, limit) : likes;
    const postIds = pageLikes.map((item) => item.postId);
    const authorIds = Array.from(new Set(pageLikes.map((item) => item.post.user.id)));
    const [followingSet, likedPostIds, repostedPostIds] = await Promise.all([
      buildFollowingMap(userId, authorIds),
      buildLikedPostMap(userId, postIds),
      buildRepostedPostMap(userId, postIds),
    ]);

    res.json({
      items: pageLikes.map((item) => ({
        actionAt: item.createdAt,
        post: mapPost(item.post, followingSet, likedPostIds, repostedPostIds),
      })),
      nextCursor: hasMore ? pageLikes[pageLikes.length - 1]?.createdAt.toISOString() ?? null : null,
    });
  } catch (error) {
    console.error('BFF like history error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.get('/profile/me/reposts', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const userId = requireAuth(req as BFFAuthRequest, res);
    if (!userId) return;

    const limit = normalizeLimit(req.query.limit, 20, 50);
    const cursorDate = parseCursorDate(req.query.cursor);

    const reposts = await prisma.postRepost.findMany({
      where: {
        userId,
        ...(cursorDate
          ? {
              createdAt: {
                lt: cursorDate,
              },
            }
          : {}),
      },
      include: {
        post: {
          include: {
            user: {
              select: {
                id: true,
                username: true,
                displayName: true,
                avatarUrl: true,
              },
            },
            squad: {
              select: {
                id: true,
                name: true,
                avatarUrl: true,
              },
            },
          },
        },
      },
      orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
      take: limit + 1,
    });

    const hasMore = reposts.length > limit;
    const pageReposts = hasMore ? reposts.slice(0, limit) : reposts;
    const postIds = pageReposts.map((item) => item.postId);
    const authorIds = Array.from(new Set(pageReposts.map((item) => item.post.user.id)));
    const [followingSet, likedPostIds, repostedPostIds] = await Promise.all([
      buildFollowingMap(userId, authorIds),
      buildLikedPostMap(userId, postIds),
      buildRepostedPostMap(userId, postIds),
    ]);

    res.json({
      items: pageReposts.map((item) => ({
        actionAt: item.createdAt,
        post: mapPost(item.post, followingSet, likedPostIds, repostedPostIds),
      })),
      nextCursor: hasMore ? pageReposts[pageReposts.length - 1]?.createdAt.toISOString() ?? null : null,
    });
  } catch (error) {
    console.error('BFF repost history error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.post('/social/users/:id/follow', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const userId = requireAuth(req as BFFAuthRequest, res);
    if (!userId) return;

    const targetUserId = req.params.id as string;
    if (targetUserId === userId) {
      res.status(400).json({ error: 'Cannot follow yourself' });
      return;
    }

    const target = await prisma.user.findUnique({
      where: { id: targetUserId },
      select: {
        id: true,
        username: true,
        displayName: true,
        avatarUrl: true,
        isActive: true,
      },
    });

    if (!target || !target.isActive) {
      res.status(404).json({ error: 'User not found' });
      return;
    }

    const existing = await prisma.follow.findUnique({
      where: {
        followerId_followingId: {
          followerId: userId,
          followingId: targetUserId,
        },
      },
    });

    if (!existing) {
      await prisma.follow.create({
        data: {
          followerId: userId,
          followingId: targetUserId,
          type: 'user',
        },
      });
    }

    res.json(toUserSummary(target, true));
  } catch (error) {
    console.error('BFF follow user error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.delete('/social/users/:id/follow', optionalAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const userId = requireAuth(req as BFFAuthRequest, res);
    if (!userId) return;

    const targetUserId = req.params.id as string;

    const target = await prisma.user.findUnique({
      where: { id: targetUserId },
      select: {
        id: true,
        username: true,
        displayName: true,
        avatarUrl: true,
      },
    });

    if (!target) {
      res.status(404).json({ error: 'User not found' });
      return;
    }

    await prisma.follow.deleteMany({
      where: {
        followerId: userId,
        followingId: targetUserId,
        type: 'user',
      },
    });

    res.json(toUserSummary(target, false));
  } catch (error) {
    console.error('BFF unfollow user error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

export default router;
