import { Router, Request, Response } from 'express';
import { Prisma, PrismaClient } from '@prisma/client';
import { authenticate, authorize, AuthRequest } from '../middleware/auth';
import { getNotificationCenterAPNSStatus, notificationCenterService } from '../services/notification-center';

const router: Router = Router();
const prisma = new PrismaClient();

type LegacyNotificationType = 'follow' | 'like' | 'comment' | 'squad_invite';
type CommunityNotificationSource = 'user_follow' | 'post_like' | 'post_comment' | 'post_comment_reply' | 'squad_invite';

const LEGACY_NOTIFICATION_TYPE_SOURCES: Record<LegacyNotificationType, CommunityNotificationSource[]> = {
  follow: ['user_follow'],
  like: ['post_like'],
  comment: ['post_comment', 'post_comment_reply'],
  squad_invite: ['squad_invite'],
};

const parseLimit = (raw: unknown, fallback = 20, max = 100): number => {
  const numeric = Number(raw);
  if (!Number.isFinite(numeric)) {
    return fallback;
  }
  const value = Math.floor(numeric);
  if (value < 1) {
    return fallback;
  }
  return Math.min(value, max);
};

const parseWindowHours = (raw: unknown, fallback = 24, max = 24 * 30): number => {
  const numeric = Number(raw);
  if (!Number.isFinite(numeric)) {
    return fallback;
  }
  const value = Math.floor(numeric);
  if (value < 1) {
    return fallback;
  }
  return Math.min(value, max);
};

const parseBoolean = (raw: unknown): boolean | undefined => {
  if (typeof raw === 'boolean') {
    return raw;
  }
  if (typeof raw !== 'string') {
    return undefined;
  }
  const value = raw.trim().toLowerCase();
  if (value === '1' || value === 'true' || value === 'yes') {
    return true;
  }
  if (value === '0' || value === 'false' || value === 'no') {
    return false;
  }
  return undefined;
};

const parseLegacyNotificationType = (rawType: unknown): LegacyNotificationType | null => {
  if (typeof rawType !== 'string') return null;
  const normalized = rawType.trim().toLowerCase();
  if (!normalized) return null;
  if (normalized === 'follow') return 'follow';
  if (normalized === 'like') return 'like';
  if (normalized === 'comment') return 'comment';
  if (normalized === 'squad_invite' || normalized === 'squadinvite') return 'squad_invite';
  return null;
};

const toPositiveSafeInteger = (value: unknown): number => {
  if (typeof value === 'number' && Number.isFinite(value)) {
    return Math.max(0, Math.floor(value));
  }
  if (typeof value === 'bigint') {
    return Number(value > 0n ? value : 0n);
  }
  if (typeof value === 'string') {
    const parsed = Number(value);
    return Number.isFinite(parsed) ? Math.max(0, Math.floor(parsed)) : 0;
  }
  return 0;
};

const fetchCommunityUnreadBreakdown = async (
  userId: string
): Promise<{ follows: number; likes: number; comments: number; squadInvites: number; total: number }> => {
  const rows = await prisma.$queryRaw<Array<{ source: string | null; count: bigint | number }>>`
    SELECT
      metadata ->> 'source' AS source,
      COUNT(*)::bigint AS count
    FROM notification_inbox
    WHERE user_id = ${userId}
      AND is_read = false
      AND type = 'community_interaction'
    GROUP BY metadata ->> 'source'
  `;

  const bySource = new Map<string, number>();
  for (const row of rows) {
    const source = typeof row.source === 'string' ? row.source.trim() : '';
    if (!source) continue;
    bySource.set(source, toPositiveSafeInteger(row.count));
  }

  const follows = LEGACY_NOTIFICATION_TYPE_SOURCES.follow.reduce((sum, source) => sum + (bySource.get(source) ?? 0), 0);
  const likes = LEGACY_NOTIFICATION_TYPE_SOURCES.like.reduce((sum, source) => sum + (bySource.get(source) ?? 0), 0);
  const comments = LEGACY_NOTIFICATION_TYPE_SOURCES.comment.reduce((sum, source) => sum + (bySource.get(source) ?? 0), 0);
  const squadInvites = LEGACY_NOTIFICATION_TYPE_SOURCES.squad_invite.reduce(
    (sum, source) => sum + (bySource.get(source) ?? 0),
    0
  );

  return {
    follows,
    likes,
    comments,
    squadInvites,
    total: follows + likes + comments + squadInvites,
  };
};

router.post('/push-tokens', authenticate, async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const userId = req.user?.userId;
    if (!userId) {
      res.status(401).json({ error: 'Unauthorized' });
      return;
    }

    const body = (req.body ?? {}) as {
      deviceId?: unknown;
      platform?: unknown;
      pushToken?: unknown;
      appVersion?: unknown;
      locale?: unknown;
    };

    const deviceId = typeof body.deviceId === 'string' ? body.deviceId.trim() : '';
    const platform = typeof body.platform === 'string' ? body.platform.trim() : '';
    const pushToken = typeof body.pushToken === 'string' ? body.pushToken.trim() : '';
    if (!deviceId || !platform || !pushToken) {
      res.status(400).json({ error: 'deviceId/platform/pushToken are required' });
      return;
    }

    await notificationCenterService.registerDevicePushToken({
      userId,
      deviceId,
      platform,
      pushToken,
      appVersion: typeof body.appVersion === 'string' ? body.appVersion.trim() : undefined,
      locale: typeof body.locale === 'string' ? body.locale.trim() : undefined,
    });

    res.json({ success: true });
  } catch (error) {
    console.error('Register device push token error:', error);
    res.status(500).json({ error: 'Failed to register device token' });
  }
});

router.delete('/push-tokens', authenticate, async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const userId = req.user?.userId;
    if (!userId) {
      res.status(401).json({ error: 'Unauthorized' });
      return;
    }

    const body = (req.body ?? {}) as {
      deviceId?: unknown;
      platform?: unknown;
    };
    const deviceId = typeof body.deviceId === 'string' ? body.deviceId.trim() : '';
    const platform = typeof body.platform === 'string' ? body.platform.trim() : '';
    if (!deviceId || !platform) {
      res.status(400).json({ error: 'deviceId/platform are required' });
      return;
    }

    const count = await notificationCenterService.deactivateDevicePushToken(userId, deviceId, platform);
    res.json({ success: true, updated: count });
  } catch (error) {
    console.error('Deactivate device push token error:', error);
    res.status(500).json({ error: 'Failed to deactivate device token' });
  }
});

router.get('/inbox', authenticate, async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const userId = req.user?.userId;
    if (!userId) {
      res.status(401).json({ error: 'Unauthorized' });
      return;
    }

    const limit = parseLimit((req.query as Request['query']).limit, 20, 100);
    const items = await notificationCenterService.fetchInbox(userId, limit);
    res.json({ success: true, items });
  } catch (error) {
    console.error('Fetch notification inbox error:', error);
    res.status(500).json({ error: 'Failed to fetch notification inbox' });
  }
});

router.get('/inbox/unread-count', authenticate, async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const userId = req.user?.userId;
    if (!userId) {
      res.status(401).json({ error: 'Unauthorized' });
      return;
    }

    const [total, legacy] = await Promise.all([
      notificationCenterService.fetchInboxUnreadCount(userId),
      fetchCommunityUnreadBreakdown(userId),
    ]);
    res.json({
      success: true,
      total,
      follows: legacy.follows,
      likes: legacy.likes,
      comments: legacy.comments,
      squadInvites: legacy.squadInvites,
      communityTotal: legacy.total,
    });
  } catch (error) {
    console.error('Fetch notification inbox unread count error:', error);
    res.status(500).json({ error: 'Failed to fetch notification unread count' });
  }
});

router.post('/inbox/read', authenticate, async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const userId = req.user?.userId;
    if (!userId) {
      res.status(401).json({ error: 'Unauthorized' });
      return;
    }

    const body = (req.body ?? {}) as {
      inboxIds?: unknown;
      inboxId?: unknown;
      notificationType?: unknown;
    };
    const inboxIds: string[] = [];
    if (typeof body.inboxId === 'string') {
      inboxIds.push(body.inboxId);
    }
    if (Array.isArray(body.inboxIds)) {
      for (const item of body.inboxIds) {
        if (typeof item === 'string') {
          inboxIds.push(item);
        }
      }
    }

    const notificationType = parseLegacyNotificationType(body.notificationType);
    if (inboxIds.length === 0 && !notificationType) {
      res.status(400).json({ error: 'inboxId/inboxIds or notificationType is required' });
      return;
    }

    let updatedByInboxIds = 0;
    if (inboxIds.length > 0) {
      updatedByInboxIds = await notificationCenterService.markInboxRead(userId, inboxIds);
    }

    let updatedByType = 0;
    if (notificationType) {
      const sources = LEGACY_NOTIFICATION_TYPE_SOURCES[notificationType];
      if (sources.length > 0) {
        updatedByType = await prisma.$executeRaw`
          UPDATE notification_inbox
          SET is_read = TRUE,
              read_at = NOW(),
              updated_at = NOW()
          WHERE user_id = ${userId}
            AND is_read = FALSE
            AND type = 'community_interaction'
            AND (metadata ->> 'source') IN (${Prisma.join(sources)})
        `;
      }
    }

    res.json({ success: true, updated: updatedByInboxIds + toPositiveSafeInteger(updatedByType) });
  } catch (error) {
    console.error('Mark notification inbox read error:', error);
    res.status(500).json({ error: 'Failed to mark notification read' });
  }
});

router.get('/preferences/event-countdown', authenticate, async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const userId = req.user?.userId;
    if (!userId) {
      res.status(401).json({ error: 'Unauthorized' });
      return;
    }

    const preference = await notificationCenterService.fetchEventCountdownPreference(userId);
    res.json({ success: true, preference });
  } catch (error) {
    console.error('Fetch event countdown preference error:', error);
    res.status(500).json({ error: 'Failed to fetch event countdown preference' });
  }
});

router.put('/preferences/event-countdown', authenticate, async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const userId = req.user?.userId;
    if (!userId) {
      res.status(401).json({ error: 'Unauthorized' });
      return;
    }

    const body = (req.body ?? {}) as {
      enabled?: unknown;
      daysBeforeStart?: unknown;
      reminderHours?: unknown;
      timezone?: unknown;
      channels?: unknown;
    };

    const preference = await notificationCenterService.updateEventCountdownPreference(userId, {
      enabled: typeof body.enabled === 'boolean' ? body.enabled : undefined,
      daysBeforeStart: typeof body.daysBeforeStart === 'number' ? body.daysBeforeStart : undefined,
      reminderHours: Array.isArray(body.reminderHours) ? body.reminderHours : undefined,
      timezone: typeof body.timezone === 'string' ? body.timezone.trim() : undefined,
      channels: Array.isArray(body.channels) ? body.channels : undefined,
    });
    res.json({ success: true, preference });
  } catch (error) {
    console.error('Update event countdown preference error:', error);
    res.status(500).json({ error: error instanceof Error ? error.message : 'Failed to update event countdown preference' });
  }
});

router.get('/preferences/event-daily-digest', authenticate, async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const userId = req.user?.userId;
    if (!userId) {
      res.status(401).json({ error: 'Unauthorized' });
      return;
    }

    const preference = await notificationCenterService.fetchEventDailyDigestPreference(userId);
    res.json({ success: true, preference });
  } catch (error) {
    console.error('Fetch event daily digest preference error:', error);
    res.status(500).json({ error: 'Failed to fetch event daily digest preference' });
  }
});

router.put('/preferences/event-daily-digest', authenticate, async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const userId = req.user?.userId;
    if (!userId) {
      res.status(401).json({ error: 'Unauthorized' });
      return;
    }

    const body = (req.body ?? {}) as {
      enabled?: unknown;
      reminderHours?: unknown;
      timezone?: unknown;
      channels?: unknown;
      includeNews?: unknown;
      includeRatings?: unknown;
      includeCheckinReminder?: unknown;
    };

    const preference = await notificationCenterService.updateEventDailyDigestPreference(userId, {
      enabled: typeof body.enabled === 'boolean' ? body.enabled : undefined,
      reminderHours: Array.isArray(body.reminderHours) ? body.reminderHours : undefined,
      timezone: typeof body.timezone === 'string' ? body.timezone.trim() : undefined,
      channels: Array.isArray(body.channels) ? body.channels : undefined,
      includeNews: typeof body.includeNews === 'boolean' ? body.includeNews : undefined,
      includeRatings: typeof body.includeRatings === 'boolean' ? body.includeRatings : undefined,
      includeCheckinReminder:
        typeof body.includeCheckinReminder === 'boolean' ? body.includeCheckinReminder : undefined,
    });
    res.json({ success: true, preference });
  } catch (error) {
    console.error('Update event daily digest preference error:', error);
    res.status(500).json({ error: error instanceof Error ? error.message : 'Failed to update event daily digest preference' });
  }
});

router.get('/preferences/route-dj-reminder', authenticate, async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const userId = req.user?.userId;
    if (!userId) {
      res.status(401).json({ error: 'Unauthorized' });
      return;
    }

    const preference = await notificationCenterService.fetchRouteDJReminderPreference(userId);
    res.json({ success: true, preference });
  } catch (error) {
    console.error('Fetch route dj reminder preference error:', error);
    res.status(500).json({ error: 'Failed to fetch route dj reminder preference' });
  }
});

router.put('/preferences/route-dj-reminder', authenticate, async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const userId = req.user?.userId;
    if (!userId) {
      res.status(401).json({ error: 'Unauthorized' });
      return;
    }

    const body = (req.body ?? {}) as {
      enabled?: unknown;
      timezone?: unknown;
      channels?: unknown;
      defaultReminderMinutesBefore?: unknown;
      watchedSlots?: unknown;
    };

    const preference = await notificationCenterService.updateRouteDJReminderPreference(userId, {
      enabled: typeof body.enabled === 'boolean' ? body.enabled : undefined,
      timezone: typeof body.timezone === 'string' ? body.timezone.trim() : undefined,
      channels: Array.isArray(body.channels) ? body.channels : undefined,
      defaultReminderMinutesBefore:
        typeof body.defaultReminderMinutesBefore === 'number' ? body.defaultReminderMinutesBefore : undefined,
      watchedSlots: Array.isArray(body.watchedSlots) ? body.watchedSlots : undefined,
    });
    res.json({ success: true, preference });
  } catch (error) {
    console.error('Update route dj reminder preference error:', error);
    res.status(500).json({ error: error instanceof Error ? error.message : 'Failed to update route dj reminder preference' });
  }
});

router.get('/preferences/followed-dj-update', authenticate, async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const userId = req.user?.userId;
    if (!userId) {
      res.status(401).json({ error: 'Unauthorized' });
      return;
    }

    const preference = await notificationCenterService.fetchFollowedDJUpdatePreference(userId);
    res.json({ success: true, preference });
  } catch (error) {
    console.error('Fetch followed dj update preference error:', error);
    res.status(500).json({ error: 'Failed to fetch followed dj update preference' });
  }
});

router.put('/preferences/followed-dj-update', authenticate, async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const userId = req.user?.userId;
    if (!userId) {
      res.status(401).json({ error: 'Unauthorized' });
      return;
    }

    const body = (req.body ?? {}) as {
      enabled?: unknown;
      reminderHours?: unknown;
      timezone?: unknown;
      channels?: unknown;
      includeInfos?: unknown;
      includeSets?: unknown;
      includeRatings?: unknown;
    };

    const preference = await notificationCenterService.updateFollowedDJUpdatePreference(userId, {
      enabled: typeof body.enabled === 'boolean' ? body.enabled : undefined,
      reminderHours: Array.isArray(body.reminderHours) ? body.reminderHours : undefined,
      timezone: typeof body.timezone === 'string' ? body.timezone.trim() : undefined,
      channels: Array.isArray(body.channels) ? body.channels : undefined,
      includeInfos: typeof body.includeInfos === 'boolean' ? body.includeInfos : undefined,
      includeSets: typeof body.includeSets === 'boolean' ? body.includeSets : undefined,
      includeRatings: typeof body.includeRatings === 'boolean' ? body.includeRatings : undefined,
    });
    res.json({ success: true, preference });
  } catch (error) {
    console.error('Update followed dj update preference error:', error);
    res.status(500).json({ error: error instanceof Error ? error.message : 'Failed to update followed dj update preference' });
  }
});

router.get('/preferences/followed-brand-update', authenticate, async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const userId = req.user?.userId;
    if (!userId) {
      res.status(401).json({ error: 'Unauthorized' });
      return;
    }

    const preference = await notificationCenterService.fetchFollowedBrandUpdatePreference(userId);
    res.json({ success: true, preference });
  } catch (error) {
    console.error('Fetch followed brand update preference error:', error);
    res.status(500).json({ error: 'Failed to fetch followed brand update preference' });
  }
});

router.put('/preferences/followed-brand-update', authenticate, async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const userId = req.user?.userId;
    if (!userId) {
      res.status(401).json({ error: 'Unauthorized' });
      return;
    }

    const body = (req.body ?? {}) as {
      enabled?: unknown;
      reminderHours?: unknown;
      timezone?: unknown;
      channels?: unknown;
      watchedBrandIds?: unknown;
      includeInfos?: unknown;
      includeEvents?: unknown;
    };

    const preference = await notificationCenterService.updateFollowedBrandUpdatePreference(userId, {
      enabled: typeof body.enabled === 'boolean' ? body.enabled : undefined,
      reminderHours: Array.isArray(body.reminderHours) ? body.reminderHours : undefined,
      timezone: typeof body.timezone === 'string' ? body.timezone.trim() : undefined,
      channels: Array.isArray(body.channels) ? body.channels : undefined,
      watchedBrandIds: Array.isArray(body.watchedBrandIds) ? body.watchedBrandIds : undefined,
      includeInfos: typeof body.includeInfos === 'boolean' ? body.includeInfos : undefined,
      includeEvents: typeof body.includeEvents === 'boolean' ? body.includeEvents : undefined,
    });
    res.json({ success: true, preference });
  } catch (error) {
    console.error('Update followed brand update preference error:', error);
    res.status(500).json({ error: error instanceof Error ? error.message : 'Failed to update followed brand update preference' });
  }
});

router.post('/admin/major-news/publish', authenticate, authorize('admin'), async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const actorUserId = req.user?.userId;
    if (!actorUserId) {
      res.status(401).json({ error: 'Unauthorized' });
      return;
    }

    const body = (req.body ?? {}) as {
      headline?: unknown;
      summary?: unknown;
      deeplink?: unknown;
      channels?: unknown;
      targetUserIds?: unknown;
      userLimit?: unknown;
      dedupeKey?: unknown;
    };

    const headline = typeof body.headline === 'string' ? body.headline.trim() : '';
    const summary = typeof body.summary === 'string' ? body.summary.trim() : '';
    if (!headline || !summary) {
      res.status(400).json({ error: 'headline/summary are required' });
      return;
    }

    const channelsRaw = Array.isArray(body.channels)
      ? body.channels.filter((item): item is string => typeof item === 'string').map((item) => item.trim().toLowerCase())
      : [];
    const channels = (channelsRaw.length > 0 ? channelsRaw : ['in_app', 'apns']).filter(
      (channel): channel is 'in_app' | 'apns' => channel === 'in_app' || channel === 'apns'
    );
    if (channels.length === 0) {
      res.status(400).json({ error: 'channels are invalid' });
      return;
    }

    const targetUserIds = Array.isArray(body.targetUserIds)
      ? Array.from(
          new Set(
            body.targetUserIds
              .filter((item): item is string => typeof item === 'string')
              .map((item) => item.trim())
              .filter(Boolean)
          )
        )
      : [];
    const userLimit = parseLimit(body.userLimit, 2000, 10000);
    const audienceUserIds =
      targetUserIds.length > 0
        ? targetUserIds
        : (
            await prisma.user.findMany({
              where: {
                isActive: true,
              },
              select: {
                id: true,
              },
              take: userLimit,
              orderBy: {
                createdAt: 'desc',
              },
            })
          ).map((item) => item.id);

    if (audienceUserIds.length === 0) {
      res.status(400).json({ error: 'No audience users found' });
      return;
    }

    const dedupeKeyRaw = typeof body.dedupeKey === 'string' ? body.dedupeKey.trim() : '';
    const dedupeKey = dedupeKeyRaw || `major_news:${headline}:${new Date().toISOString().slice(0, 13)}`;
    const results = await notificationCenterService.publish({
      category: 'major_news',
      targets: audienceUserIds.map((userId) => ({ userId })),
      channels,
      dedupeKey,
      payload: {
        title: headline,
        body: summary,
        deeplink: typeof body.deeplink === 'string' ? body.deeplink.trim() : null,
        metadata: {
          source: 'major_news_admin_publish',
          actorUserId,
          audienceCount: audienceUserIds.length,
        },
      },
    });

    res.json({
      success: true,
      audienceCount: audienceUserIds.length,
      dedupeKey,
      results,
    });
  } catch (error) {
    console.error('Publish major news error:', error);
    res.status(500).json({ error: error instanceof Error ? error.message : 'Failed to publish major news' });
  }
});

router.post('/admin/publish-test', authenticate, authorize('admin'), async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const actorUserId = req.user?.userId;
    if (!actorUserId) {
      res.status(401).json({ error: 'Unauthorized' });
      return;
    }

    const body = (req.body ?? {}) as {
      category?: unknown;
      title?: unknown;
      message?: unknown;
      deeplink?: unknown;
      targetUserIds?: unknown;
      channels?: unknown;
    };

    const category = typeof body.category === 'string' ? body.category.trim() : 'major_news';
    const title = typeof body.title === 'string' ? body.title.trim() : '';
    const message = typeof body.message === 'string' ? body.message.trim() : '';
    if (!title || !message) {
      res.status(400).json({ error: 'title/message are required' });
      return;
    }

    const targetUserIds = Array.isArray(body.targetUserIds)
      ? body.targetUserIds.filter((item): item is string => typeof item === 'string').map((item) => item.trim()).filter(Boolean)
      : [];
    const channelsRaw = Array.isArray(body.channels)
      ? body.channels.filter((item): item is string => typeof item === 'string').map((item) => item.trim().toLowerCase())
      : [];
    const channels = channelsRaw.length > 0 ? channelsRaw : ['in_app'];

    const results = await notificationCenterService.publish({
      category: category as
        | 'chat_message'
        | 'community_interaction'
        | 'event_countdown'
        | 'event_daily_digest'
        | 'route_dj_reminder'
        | 'followed_dj_update'
        | 'followed_brand_update'
        | 'major_news',
      targets: (targetUserIds.length > 0 ? targetUserIds : [actorUserId]).map((userId) => ({ userId })),
      channels: channels as Array<'in_app' | 'apns'>,
      payload: {
        title,
        body: message,
        deeplink: typeof body.deeplink === 'string' ? body.deeplink.trim() : null,
      },
    });

    res.json({ success: true, results });
  } catch (error) {
    console.error('Notification publish test error:', error);
    res.status(500).json({ error: 'Failed to publish notification' });
  }
});

router.get('/admin/status', authenticate, authorize('admin'), async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const windowHours = parseWindowHours((req.query as Request['query']).windowHours, 24, 24 * 30);
    const stats = await notificationCenterService.fetchDeliveryStats(windowHours);
    const config = await notificationCenterService.fetchAdminGlobalConfig();
    res.json({
      success: true,
      status: {
        apns: getNotificationCenterAPNSStatus(),
        delivery: stats,
        config,
      },
    });
  } catch (error) {
    console.error('Fetch notification center status error:', error);
    res.status(500).json({ error: 'Failed to fetch notification center status' });
  }
});

router.get('/admin/deliveries', authenticate, authorize('admin'), async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const query = req.query as Request['query'];
    const channelRaw = typeof query.channel === 'string' ? query.channel.trim().toLowerCase() : '';
    const channel = channelRaw === 'in_app' || channelRaw === 'apns' ? channelRaw : undefined;
    const status = typeof query.status === 'string' ? query.status.trim() : undefined;
    const userId = typeof query.userId === 'string' ? query.userId.trim() : undefined;
    const eventId = typeof query.eventId === 'string' ? query.eventId.trim() : undefined;
    const limit = parseLimit(query.limit, 50, 200);

    const items = await notificationCenterService.fetchRecentDeliveries({
      limit,
      channel,
      status,
      userId,
      eventId,
    });

    res.json({ success: true, items });
  } catch (error) {
    console.error('Fetch notification center deliveries error:', error);
    res.status(500).json({ error: 'Failed to fetch notification deliveries' });
  }
});

router.get('/admin/config', authenticate, authorize('admin'), async (_req: AuthRequest, res: Response): Promise<void> => {
  try {
    const config = await notificationCenterService.fetchAdminGlobalConfig();
    res.json({ success: true, config });
  } catch (error) {
    console.error('Fetch notification center config error:', error);
    res.status(500).json({ error: 'Failed to fetch notification center config' });
  }
});

router.put('/admin/config', authenticate, authorize('admin'), async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const userId = req.user?.userId;
    if (!userId) {
      res.status(401).json({ error: 'Unauthorized' });
      return;
    }
    const body = (req.body ?? {}) as { config?: unknown };
    const config = await notificationCenterService.updateAdminGlobalConfig(body.config ?? {}, userId);
    res.json({ success: true, config });
  } catch (error) {
    console.error('Update notification center config error:', error);
    res.status(500).json({ error: error instanceof Error ? error.message : 'Failed to update notification center config' });
  }
});

router.get('/admin/templates', authenticate, authorize('admin'), async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const query = req.query as Request['query'];
    const channelRaw = typeof query.channel === 'string' ? query.channel.trim().toLowerCase() : '';
    const channel = channelRaw === 'in_app' || channelRaw === 'apns' ? channelRaw : undefined;
    const items = await notificationCenterService.fetchAdminTemplates({
      limit: parseLimit(query.limit, 50, 200),
      category: typeof query.category === 'string' ? query.category.trim() : undefined,
      locale: typeof query.locale === 'string' ? query.locale.trim() : undefined,
      channel,
      isActive: parseBoolean(query.isActive),
    });
    res.json({ success: true, items });
  } catch (error) {
    console.error('Fetch notification templates error:', error);
    res.status(500).json({ error: 'Failed to fetch notification templates' });
  }
});

router.put('/admin/templates', authenticate, authorize('admin'), async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const body = (req.body ?? {}) as {
      category?: unknown;
      locale?: unknown;
      channel?: unknown;
      titleTemplate?: unknown;
      bodyTemplate?: unknown;
      deeplinkTemplate?: unknown;
      variables?: unknown;
      isActive?: unknown;
    };

    const category = typeof body.category === 'string' ? body.category.trim() : '';
    const locale = typeof body.locale === 'string' ? body.locale.trim() : 'zh-CN';
    const channelRaw = typeof body.channel === 'string' ? body.channel.trim().toLowerCase() : '';
    const titleTemplate = typeof body.titleTemplate === 'string' ? body.titleTemplate.trim() : '';
    const bodyTemplate = typeof body.bodyTemplate === 'string' ? body.bodyTemplate.trim() : '';
    if (!category || !titleTemplate || !bodyTemplate) {
      res.status(400).json({ error: 'category/titleTemplate/bodyTemplate are required' });
      return;
    }
    if (channelRaw !== 'in_app' && channelRaw !== 'apns') {
      res.status(400).json({ error: 'channel must be one of in_app/apns' });
      return;
    }

    const item = await notificationCenterService.upsertAdminTemplate({
      category,
      locale,
      channel: channelRaw as 'in_app' | 'apns',
      titleTemplate,
      bodyTemplate,
      deeplinkTemplate: typeof body.deeplinkTemplate === 'string' ? body.deeplinkTemplate.trim() : null,
      variables: Array.isArray(body.variables) ? body.variables : [],
      isActive: parseBoolean(body.isActive),
    });
    res.json({ success: true, item });
  } catch (error) {
    console.error('Upsert notification template error:', error);
    res.status(500).json({ error: error instanceof Error ? error.message : 'Failed to upsert notification template' });
  }
});

export default router;
