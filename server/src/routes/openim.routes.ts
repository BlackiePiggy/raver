import { Router, Request, Response } from 'express';
import { PrismaClient, Prisma } from '@prisma/client';
import { authenticate, authorize, AuthRequest } from '../middleware/auth';
import { openIMTokenService } from '../services/openim/openim-token.service';
import { openIMClient } from '../services/openim/openim-client';
import { openIMWebhookService } from '../services/openim/openim-webhook.service';
import { openIMModerationService } from '../services/openim/openim-moderation.service';
import { openIMMessageService } from '../services/openim/openim-message.service';
import { notificationCenterService } from '../services/notification-center';

const router: Router = Router();
const prisma = new PrismaClient();

type RawBodyRequest = Request & { rawBody?: Buffer };

const getFirstHeader = (value: string | string[] | undefined): string | null => {
  if (Array.isArray(value)) {
    return value.length > 0 ? String(value[0]) : null;
  }
  if (typeof value === 'string') {
    const trimmed = value.trim();
    return trimmed.length > 0 ? trimmed : null;
  }
  return null;
};

const resolveHeader = (req: Request, keys: string[]): string | null => {
  for (const key of keys) {
    const header = getFirstHeader(req.headers[key.toLowerCase()]);
    if (header) {
      return header;
    }
  }
  return null;
};

const readPayloadString = (payload: Record<string, unknown>, keys: string[]): string | null => {
  for (const key of keys) {
    const value = payload[key];
    if (typeof value === 'string') {
      const trimmed = value.trim();
      if (trimmed.length > 0) {
        return trimmed;
      }
    }
  }
  return null;
};

const readPayloadRecord = (payload: Record<string, unknown>, keys: string[]): Record<string, unknown> | null => {
  for (const key of keys) {
    const value = payload[key];
    if (value && typeof value === 'object' && !Array.isArray(value)) {
      return value as Record<string, unknown>;
    }
  }
  return null;
};

const normalizeText = (value: string, maxLength = 120): string => {
  const normalized = value.replace(/\s+/g, ' ').trim();
  if (!normalized) return '';
  if (normalized.length <= maxLength) return normalized;
  return `${normalized.slice(0, maxLength - 1)}…`;
};

const decodeOpenIMPrefixedID = (value: string | null, prefix: 'u' | 'g'): string | null => {
  if (!value) {
    return null;
  }
  const normalized = value.trim().toLowerCase();
  if (!normalized.startsWith(`${prefix}_`)) {
    return null;
  }

  const compactId = normalized.slice(2);
  if (!/^[0-9a-f]{32}$/.test(compactId)) {
    return null;
  }

  return [
    compactId.slice(0, 8),
    compactId.slice(8, 12),
    compactId.slice(12, 16),
    compactId.slice(16, 20),
    compactId.slice(20),
  ].join('-');
};

const resolveWebhookMessagePreview = (rawContent: string | null): string => {
  if (!rawContent) {
    return '你收到一条新消息';
  }

  const trimmed = rawContent.trim();
  if (!trimmed) {
    return '你收到一条新消息';
  }

  if (trimmed.startsWith('{') && trimmed.endsWith('}')) {
    try {
      const parsed = JSON.parse(trimmed) as Record<string, unknown>;
      const textContent = typeof parsed.content === 'string'
        ? parsed.content
        : typeof parsed.text === 'string'
          ? parsed.text
          : '';
      const normalized = normalizeText(textContent, 120);
      if (normalized) {
        return normalized;
      }
    } catch {
      // Ignore malformed JSON content and fallback to raw text.
    }
  }

  const normalized = normalizeText(trimmed, 120);
  return normalized || '你收到一条新消息';
};

const normalizeReason = (input: unknown): string | null => {
  if (typeof input !== 'string') {
    return null;
  }
  const value = input.trim().toLowerCase();
  if (!value) {
    return null;
  }
  const allowed = new Set([
    'spam',
    'abuse',
    'harassment',
    'fraud',
    'sexual',
    'violence',
    'hate_speech',
    'illegal',
    'other',
  ]);
  if (allowed.has(value)) {
    return value;
  }
  return 'other';
};

const normalizeResolutionStatus = (input: unknown): 'resolved' | 'rejected' => {
  const value = typeof input === 'string' ? input.trim().toLowerCase() : '';
  return value === 'rejected' ? 'rejected' : 'resolved';
};

const normalizeImageModerationReviewStatus = (input: unknown): 'approved' | 'rejected' | null => {
  const value = typeof input === 'string' ? input.trim().toLowerCase() : '';
  if (value === 'approved' || value === 'rejected') {
    return value;
  }
  return null;
};

const parseLimit = (raw: unknown, fallback = 20, max = 100): number => {
  const parsed = Number(raw);
  if (!Number.isFinite(parsed)) {
    return fallback;
  }
  const normalized = Math.floor(parsed);
  if (normalized < 1) {
    return fallback;
  }
  return Math.min(normalized, max);
};

const parseCursorDate = (cursor: unknown): Date | null => {
  if (typeof cursor !== 'string' || !cursor.trim()) {
    return null;
  }
  const parsed = new Date(cursor);
  return Number.isNaN(parsed.getTime()) ? null : parsed;
};

const writeAdminAuditLog = async (
  actorId: string,
  action: string,
  targetType: string,
  targetId: string,
  detail?: Prisma.InputJsonValue
): Promise<void> => {
  await prisma.adminAuditLog.create({
    data: {
      actorId,
      action,
      targetType,
      targetId,
      detail,
    },
    select: { id: true },
  });
};

router.post('/webhooks', async (req: RawBodyRequest, res: Response): Promise<void> => {
  try {
    const payloadUnknown = req.body ?? {};
    const payload: Record<string, unknown> =
      payloadUnknown && typeof payloadUnknown === 'object'
        ? (payloadUnknown as Record<string, unknown>)
        : { raw: payloadUnknown };
    const payloadJson = payload as Prisma.InputJsonValue;

    const rawBody = req.rawBody && req.rawBody.length > 0
      ? req.rawBody
      : Buffer.from(JSON.stringify(payload), 'utf8');

    const signature = resolveHeader(req, ['x-openim-signature', 'x-signature', 'signature']);
    const timestamp = resolveHeader(req, ['x-openim-timestamp', 'x-timestamp', 'timestamp']);
    const nonce = resolveHeader(req, ['x-openim-nonce', 'x-nonce', 'nonce']);
    const deliveryId = resolveHeader(req, ['x-openim-delivery-id', 'x-request-id']);

    const verify = openIMWebhookService.verifySignature({
      rawBody,
      signature,
      timestamp,
      nonce,
    });

    const callbackCommand = readPayloadString(payload, ['callbackCommand', 'event', 'eventType']);
    const operationId = readPayloadString(payload, ['operationID', 'operationId']);
    const eventId = readPayloadString(payload, ['eventID', 'eventId', 'messageID', 'messageId']);
    const messageId = readPayloadString(payload, ['messageID', 'messageId', 'clientMsgID', 'clientMsgId']);
    const conversationId = readPayloadString(payload, ['conversationID', 'conversationId']);
    const moderation = openIMModerationService.evaluatePayload(payload);
    const moderationSummary: string[] = [];
    if (moderation.matchedWords.length > 0) {
      moderationSummary.push(`sensitive-words:${moderation.matchedWords.slice(0, 3).join('|')}`);
    }
    if (moderation.matchedPatterns.length > 0) {
      moderationSummary.push(`sensitive-patterns:${moderation.matchedPatterns.length}`);
    }
    if (moderation.imageModeration.detectedCount > 0) {
      moderationSummary.push(
        `image-review:${moderation.imageModeration.detectedCount}/rejected:${moderation.imageModeration.rejectedCount}`
      );
    }

    const webhookEvent = await prisma.openIMWebhookEvent.create({
      data: {
        deliveryId,
        callbackCommand,
        operationId,
        eventId,
        sourceIp: req.ip,
        signatureValid: verify.valid,
        verifyReason: [verify.reason, ...moderationSummary].filter(Boolean).join(';'),
        payload: payloadJson,
      },
      select: { id: true },
    });

    if (!verify.valid) {
      res.status(401).json({ errCode: 401, errMsg: `invalid webhook signature: ${verify.reason}` });
      return;
    }

    if (moderation.imageModeration.enabled && moderation.imageModeration.jobs.length > 0) {
      await prisma.openIMImageModerationJob.createMany({
        data: moderation.imageModeration.jobs.map((job) => ({
          webhookEventId: webhookEvent.id,
          messageId,
          conversationId,
          imageUrl: job.imageUrl,
          source: callbackCommand || 'openim_webhook',
          status: job.status,
          reason: job.reason,
          provider: 'manual_review',
          decisionDetail: {
            host: job.host,
            matchedKeyword: job.matchedKeyword,
          } as Prisma.InputJsonValue,
          reviewedAt: job.status === 'rejected' ? new Date() : null,
        })),
      });
    }

    if (moderation.blocked) {
      res.status(200).json({
        errCode: 201,
        errMsg: `blocked by moderation: ${moderation.reason}`,
      });
      return;
    }

    const callbackLower = (callbackCommand || '').toLowerCase();
    const maybeMessageWebhook =
      callbackLower.includes('message') ||
      callbackLower.includes('msg') ||
      callbackLower.includes('send') ||
      Boolean(messageId);

    if (maybeMessageWebhook) {
      const firstLevelRecords = [
        readPayloadRecord(payload, ['data', 'msgData', 'message', 'body', 'detail']),
      ].filter((item): item is Record<string, unknown> => Boolean(item));
      const nestedRecords = firstLevelRecords
        .map((record) => readPayloadRecord(record, ['data', 'message', 'msgData', 'body', 'detail']))
        .filter((item): item is Record<string, unknown> => Boolean(item));
      const containers: Record<string, unknown>[] = [payload, ...firstLevelRecords, ...nestedRecords];

      const pickFromContainers = (keys: string[]): string | null => {
        for (const container of containers) {
          const value = readPayloadString(container, keys);
          if (value) {
            return value;
          }
        }
        return null;
      };

      const senderOpenIMID = pickFromContainers(['sendID', 'sendId', 'senderID', 'senderId', 'fromUserID', 'fromUserId']);
      const receiverOpenIMID = pickFromContainers(['recvID', 'recvId', 'toUserID', 'toUserId']);
      const groupOpenIMID = pickFromContainers(['groupID', 'groupId']);
      const rawContent = pickFromContainers(['content', 'text', 'message']);
      const parsedSenderUserID = decodeOpenIMPrefixedID(senderOpenIMID, 'u');
      const parsedReceiverUserID = decodeOpenIMPrefixedID(receiverOpenIMID, 'u');
      const parsedGroupID = decodeOpenIMPrefixedID(groupOpenIMID, 'g');

      const senderProfile = parsedSenderUserID
        ? await prisma.user.findUnique({
            where: { id: parsedSenderUserID },
            select: { id: true, username: true, displayName: true },
          })
        : null;
      const senderName = senderProfile?.displayName || senderProfile?.username || '新消息';
      const messagePreview = resolveWebhookMessagePreview(rawContent);

      if (parsedGroupID) {
        const [squad, targetMembers] = await Promise.all([
          prisma.squad.findUnique({
            where: { id: parsedGroupID },
            select: { id: true, name: true },
          }),
          prisma.squadMember.findMany({
            where: {
              squadId: parsedGroupID,
              notificationsEnabled: true,
              ...(parsedSenderUserID ? { userId: { not: parsedSenderUserID } } : {}),
            },
            select: { userId: true },
          }),
        ]);

        if (squad && targetMembers.length > 0) {
          void notificationCenterService
            .publish({
              category: 'chat_message',
              targets: targetMembers.map((item) => ({ userId: item.userId })),
              channels: ['in_app', 'apns'],
              payload: {
                title: squad.name,
                body: `${senderName}: ${messagePreview}`,
                deeplink: `raver://messages/conversation/${squad.id}`,
                metadata: {
                  source: 'openim_webhook',
                  scope: 'group',
                  openimMessageID: messageId || null,
                  openimCallbackCommand: callbackCommand || null,
                  squadID: squad.id,
                  senderUserID: parsedSenderUserID,
                },
              },
              dedupeKey: `chat:webhook:group:${messageId || webhookEvent.id}`,
            })
            .catch((error) => {
              const notifyError = error instanceof Error ? error.message : String(error);
              console.error(`[notification-center] openim webhook group publish failed: ${notifyError}`);
            });
        }
      } else if (parsedReceiverUserID && parsedReceiverUserID !== parsedSenderUserID) {
        void notificationCenterService
          .publish({
            category: 'chat_message',
            targets: [{ userId: parsedReceiverUserID }],
            channels: ['in_app', 'apns'],
            payload: {
              title: senderName,
              body: messagePreview,
              deeplink: conversationId ? `raver://messages/conversation/${conversationId}` : null,
              metadata: {
                source: 'openim_webhook',
                scope: 'direct',
                openimMessageID: messageId || null,
                openimCallbackCommand: callbackCommand || null,
                conversationID: conversationId || null,
                senderUserID: parsedSenderUserID,
                receiverUserID: parsedReceiverUserID,
              },
            },
            dedupeKey: `chat:webhook:direct:${messageId || webhookEvent.id}`,
          })
          .catch((error) => {
            const notifyError = error instanceof Error ? error.message : String(error);
            console.error(`[notification-center] openim webhook direct publish failed: ${notifyError}`);
          });
      }
    }

    res.status(200).json({ errCode: 0, errMsg: '' });
  } catch (error) {
    console.error('OpenIM webhook error:', error);
    res.status(500).json({ errCode: 500, errMsg: 'webhook internal error' });
  }
});

router.post('/messages/:messageId/report', authenticate, async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const userId = req.user?.userId;
    if (!userId) {
      res.status(401).json({ error: 'Unauthorized' });
      return;
    }

    const messageId = String(req.params.messageId || '').trim();
    if (!messageId) {
      res.status(400).json({ error: 'messageId is required' });
      return;
    }

    const body = (req.body ?? {}) as {
      reason?: unknown;
      detail?: unknown;
      conversationID?: unknown;
      conversationId?: unknown;
      metadata?: unknown;
    };

    const reason = normalizeReason(body.reason);
    if (!reason) {
      res.status(400).json({ error: 'reason is required' });
      return;
    }

    const detail = typeof body.detail === 'string' ? body.detail.trim().slice(0, 2000) : null;
    const conversationRaw = body.conversationID ?? body.conversationId;
    const conversationId = typeof conversationRaw === 'string' ? conversationRaw.trim().slice(0, 120) : null;
    const metadata =
      body.metadata && typeof body.metadata === 'object'
        ? (body.metadata as Prisma.InputJsonValue)
        : undefined;

    const report = await prisma.openIMMessageReport.upsert({
      where: {
        messageId_reportedByUserId: {
          messageId,
          reportedByUserId: userId,
        },
      },
      update: {
        reason,
        detail,
        conversationId,
        source: 'in_app',
        status: 'pending',
        metadata,
        resolvedAt: null,
        resolvedBy: null,
        resolutionNote: null,
      },
      create: {
        messageId,
        reportedByUserId: userId,
        reason,
        detail,
        conversationId,
        source: 'in_app',
        status: 'pending',
        metadata,
      },
      select: {
        id: true,
        messageId: true,
        status: true,
        reason: true,
        createdAt: true,
        updatedAt: true,
      },
    });

    res.status(201).json({
      id: report.id,
      messageID: report.messageId,
      status: report.status,
      reason: report.reason,
      createdAt: report.createdAt,
      updatedAt: report.updatedAt,
    });
  } catch (error) {
    console.error('OpenIM message report error:', error);
    res.status(500).json({ error: 'Failed to report message' });
  }
});

router.get('/admin/overview', authenticate, authorize('admin'), async (_req: AuthRequest, res: Response): Promise<void> => {
  try {
    const now = new Date();
    const last24h = new Date(now.getTime() - 24 * 60 * 60 * 1000);

    const [
      pendingReports,
      reports24h,
      webhooks24h,
      invalidWebhooks24h,
      pendingSyncJobs,
      pendingImageModerationJobs,
      rejectedImageModeration24h,
    ] = await Promise.all([
      prisma.openIMMessageReport.count({
        where: { status: 'pending' },
      }),
      prisma.openIMMessageReport.count({
        where: { createdAt: { gte: last24h } },
      }),
      prisma.openIMWebhookEvent.count({
        where: { createdAt: { gte: last24h } },
      }),
      prisma.openIMWebhookEvent.count({
        where: {
          createdAt: { gte: last24h },
          signatureValid: false,
        },
      }),
      prisma.openIMSyncJob.count({
        where: { status: { in: ['pending', 'retrying', 'processing'] } },
      }),
      prisma.openIMImageModerationJob.count({
        where: { status: 'pending' },
      }),
      prisma.openIMImageModerationJob.count({
        where: {
          status: 'rejected',
          createdAt: { gte: last24h },
        },
      }),
    ]);

    res.json({
      pendingReports,
      reports24h,
      webhooks24h,
      invalidWebhooks24h,
      pendingSyncJobs,
      pendingImageModerationJobs,
      rejectedImageModeration24h,
      timestamp: now.toISOString(),
    });
  } catch (error) {
    console.error('OpenIM admin overview error:', error);
    res.status(500).json({ error: 'Failed to load OpenIM admin overview' });
  }
});

router.get('/admin/reports', authenticate, authorize('admin'), async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const limit = parseLimit(req.query.limit, 20, 100);
    const cursor = parseCursorDate(req.query.cursor);
    const statusRaw = typeof req.query.status === 'string' ? req.query.status.trim().toLowerCase() : '';
    const statusFilter = statusRaw ? statusRaw : null;

    const rows = await prisma.openIMMessageReport.findMany({
      where: {
        ...(statusFilter ? { status: statusFilter } : {}),
        ...(cursor ? { createdAt: { lt: cursor } } : {}),
      },
      orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
      take: limit + 1,
      select: {
        id: true,
        messageId: true,
        conversationId: true,
        reportedByUserId: true,
        reason: true,
        detail: true,
        source: true,
        status: true,
        metadata: true,
        resolvedAt: true,
        resolvedBy: true,
        resolutionNote: true,
        createdAt: true,
        updatedAt: true,
      },
    });

    const hasMore = rows.length > limit;
    const pageRows = hasMore ? rows.slice(0, limit) : rows;
    const nextCursor = hasMore ? pageRows[pageRows.length - 1]?.createdAt.toISOString() ?? null : null;

    res.json({
      items: pageRows.map((row) => ({
        id: row.id,
        messageID: row.messageId,
        conversationID: row.conversationId,
        reportedByUserID: row.reportedByUserId,
        reason: row.reason,
        detail: row.detail,
        source: row.source,
        status: row.status,
        metadata: row.metadata,
        resolvedAt: row.resolvedAt,
        resolvedBy: row.resolvedBy,
        resolutionNote: row.resolutionNote,
        createdAt: row.createdAt,
        updatedAt: row.updatedAt,
      })),
      nextCursor,
    });
  } catch (error) {
    console.error('OpenIM admin report list error:', error);
    res.status(500).json({ error: 'Failed to load reports' });
  }
});

router.patch('/admin/reports/:id/resolve', authenticate, authorize('admin'), async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const adminUserId = req.user?.userId;
    if (!adminUserId) {
      res.status(401).json({ error: 'Unauthorized' });
      return;
    }

    const reportId = String(req.params.id || '').trim();
    if (!reportId) {
      res.status(400).json({ error: 'report id is required' });
      return;
    }

    const body = (req.body ?? {}) as {
      status?: unknown;
      resolutionNote?: unknown;
    };

    const status = normalizeResolutionStatus(body.status);
    const resolutionNote = typeof body.resolutionNote === 'string'
      ? body.resolutionNote.trim().slice(0, 2000)
      : null;

    const updated = await prisma.openIMMessageReport.update({
      where: { id: reportId },
      data: {
        status,
        resolvedAt: new Date(),
        resolvedBy: adminUserId,
        resolutionNote,
      },
      select: {
        id: true,
        status: true,
        resolvedAt: true,
        resolvedBy: true,
        resolutionNote: true,
        updatedAt: true,
      },
    });

    await writeAdminAuditLog(
      adminUserId,
      'openim.report.resolve',
      'openim_message_report',
      updated.id,
      {
        status,
        resolutionNote: resolutionNote || null,
      } as Prisma.InputJsonValue
    );

    res.json({
      id: updated.id,
      status: updated.status,
      resolvedAt: updated.resolvedAt,
      resolvedBy: updated.resolvedBy,
      resolutionNote: updated.resolutionNote,
      updatedAt: updated.updatedAt,
    });
  } catch (error) {
    console.error('OpenIM admin resolve report error:', error);
    if (error instanceof Prisma.PrismaClientKnownRequestError && error.code === 'P2025') {
      res.status(404).json({ error: 'Report not found' });
      return;
    }
    res.status(500).json({ error: 'Failed to resolve report' });
  }
});

router.get('/admin/webhooks', authenticate, authorize('admin'), async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const limit = parseLimit(req.query.limit, 20, 100);
    const cursor = parseCursorDate(req.query.cursor);
    const signatureValidRaw = typeof req.query.signatureValid === 'string' ? req.query.signatureValid.trim().toLowerCase() : '';
    const signatureValid =
      signatureValidRaw === 'true' ? true : signatureValidRaw === 'false' ? false : null;

    const rows = await prisma.openIMWebhookEvent.findMany({
      where: {
        ...(cursor ? { createdAt: { lt: cursor } } : {}),
        ...(signatureValid === null ? {} : { signatureValid }),
      },
      orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
      take: limit + 1,
      select: {
        id: true,
        deliveryId: true,
        callbackCommand: true,
        operationId: true,
        eventId: true,
        sourceIp: true,
        signatureValid: true,
        verifyReason: true,
        receivedAt: true,
        createdAt: true,
      },
    });

    const hasMore = rows.length > limit;
    const pageRows = hasMore ? rows.slice(0, limit) : rows;
    const nextCursor = hasMore ? pageRows[pageRows.length - 1]?.createdAt.toISOString() ?? null : null;

    res.json({
      items: pageRows.map((row) => ({
        id: row.id,
        deliveryID: row.deliveryId,
        callbackCommand: row.callbackCommand,
        operationID: row.operationId,
        eventID: row.eventId,
        sourceIP: row.sourceIp,
        signatureValid: row.signatureValid,
        verifyReason: row.verifyReason,
        receivedAt: row.receivedAt,
        createdAt: row.createdAt,
      })),
      nextCursor,
    });
  } catch (error) {
    console.error('OpenIM admin webhook list error:', error);
    res.status(500).json({ error: 'Failed to load webhook events' });
  }
});

router.get('/admin/image-moderation/jobs', authenticate, authorize('admin'), async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const limit = parseLimit(req.query.limit, 20, 100);
    const cursor = parseCursorDate(req.query.cursor);
    const statusRaw = typeof req.query.status === 'string' ? req.query.status.trim().toLowerCase() : '';
    const statusFilter = statusRaw ? statusRaw : null;

    const rows = await prisma.openIMImageModerationJob.findMany({
      where: {
        ...(cursor ? { createdAt: { lt: cursor } } : {}),
        ...(statusFilter ? { status: statusFilter } : {}),
      },
      orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
      take: limit + 1,
      select: {
        id: true,
        webhookEventId: true,
        messageId: true,
        conversationId: true,
        imageUrl: true,
        status: true,
        reason: true,
        source: true,
        provider: true,
        decisionDetail: true,
        reviewedAt: true,
        reviewedBy: true,
        createdAt: true,
        updatedAt: true,
      },
    });

    const hasMore = rows.length > limit;
    const pageRows = hasMore ? rows.slice(0, limit) : rows;
    const nextCursor = hasMore ? pageRows[pageRows.length - 1]?.createdAt.toISOString() ?? null : null;

    res.json({
      items: pageRows.map((row) => ({
        id: row.id,
        webhookEventID: row.webhookEventId,
        messageID: row.messageId,
        conversationID: row.conversationId,
        imageURL: row.imageUrl,
        status: row.status,
        reason: row.reason,
        source: row.source,
        provider: row.provider,
        decisionDetail: row.decisionDetail,
        reviewedAt: row.reviewedAt,
        reviewedBy: row.reviewedBy,
        createdAt: row.createdAt,
        updatedAt: row.updatedAt,
      })),
      nextCursor,
    });
  } catch (error) {
    console.error('OpenIM admin image moderation list error:', error);
    res.status(500).json({ error: 'Failed to load image moderation jobs' });
  }
});

router.patch('/admin/image-moderation/jobs/:id/review', authenticate, authorize('admin'), async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const adminUserId = req.user?.userId;
    if (!adminUserId) {
      res.status(401).json({ error: 'Unauthorized' });
      return;
    }

    const jobId = String(req.params.id || '').trim();
    if (!jobId) {
      res.status(400).json({ error: 'job id is required' });
      return;
    }

    const body = (req.body ?? {}) as {
      status?: unknown;
      reason?: unknown;
      detail?: unknown;
    };
    const status = normalizeImageModerationReviewStatus(body.status);
    if (!status) {
      res.status(400).json({ error: 'status must be approved or rejected' });
      return;
    }

    const reason = typeof body.reason === 'string' ? body.reason.trim().slice(0, 512) : '';
    const detail = typeof body.detail === 'string' ? body.detail.trim().slice(0, 2000) : '';
    const reviewedAt = new Date();

    const updated = await prisma.openIMImageModerationJob.update({
      where: { id: jobId },
      data: {
        status,
        reason: reason || null,
        reviewedAt,
        reviewedBy: adminUserId,
        decisionDetail: {
          ...(detail ? { note: detail } : {}),
          reviewedVia: 'admin_api',
        } as Prisma.InputJsonValue,
      },
      select: {
        id: true,
        status: true,
        reason: true,
        reviewedAt: true,
        reviewedBy: true,
        updatedAt: true,
      },
    });

    await writeAdminAuditLog(
      adminUserId,
      'openim.image_moderation.review',
      'openim_image_moderation_job',
      updated.id,
      {
        status,
        reason: reason || null,
      } as Prisma.InputJsonValue
    );

    res.json({
      id: updated.id,
      status: updated.status,
      reason: updated.reason,
      reviewedAt: updated.reviewedAt,
      reviewedBy: updated.reviewedBy,
      updatedAt: updated.updatedAt,
    });
  } catch (error) {
    console.error('OpenIM admin image moderation review error:', error);
    if (error instanceof Prisma.PrismaClientKnownRequestError && error.code === 'P2025') {
      res.status(404).json({ error: 'Image moderation job not found' });
      return;
    }
    res.status(500).json({ error: 'Failed to review image moderation job' });
  }
});

router.get('/admin/sync-jobs', authenticate, authorize('admin'), async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const limit = parseLimit(req.query.limit, 20, 100);
    const cursor = parseCursorDate(req.query.cursor);
    const statusRaw = typeof req.query.status === 'string' ? req.query.status.trim().toLowerCase() : '';
    const statusFilter = statusRaw ? statusRaw : null;

    const rows = await prisma.openIMSyncJob.findMany({
      where: {
        ...(cursor ? { createdAt: { lt: cursor } } : {}),
        ...(statusFilter ? { status: statusFilter } : {}),
      },
      orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
      take: limit + 1,
      select: {
        id: true,
        dedupeKey: true,
        jobType: true,
        entityType: true,
        entityId: true,
        status: true,
        attempts: true,
        maxAttempts: true,
        nextRunAt: true,
        lockedAt: true,
        lockedBy: true,
        lastError: true,
        createdAt: true,
        updatedAt: true,
      },
    });

    const hasMore = rows.length > limit;
    const pageRows = hasMore ? rows.slice(0, limit) : rows;
    const nextCursor = hasMore ? pageRows[pageRows.length - 1]?.createdAt.toISOString() ?? null : null;

    res.json({
      items: pageRows,
      nextCursor,
    });
  } catch (error) {
    console.error('OpenIM admin sync job list error:', error);
    res.status(500).json({ error: 'Failed to load sync jobs' });
  }
});

router.get('/admin/audit-logs', authenticate, authorize('admin'), async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const limit = parseLimit(req.query.limit, 20, 100);
    const cursor = parseCursorDate(req.query.cursor);
    const actionRaw = typeof req.query.action === 'string' ? req.query.action.trim() : '';
    const targetTypeRaw = typeof req.query.targetType === 'string' ? req.query.targetType.trim() : '';

    const rows = await prisma.adminAuditLog.findMany({
      where: {
        ...(cursor ? { createdAt: { lt: cursor } } : {}),
        ...(actionRaw ? { action: actionRaw } : {}),
        ...(targetTypeRaw ? { targetType: targetTypeRaw } : {}),
      },
      orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
      take: limit + 1,
      select: {
        id: true,
        actorId: true,
        action: true,
        targetType: true,
        targetId: true,
        detail: true,
        createdAt: true,
      },
    });

    const hasMore = rows.length > limit;
    const pageRows = hasMore ? rows.slice(0, limit) : rows;
    const nextCursor = hasMore ? pageRows[pageRows.length - 1]?.createdAt.toISOString() ?? null : null;

    res.json({
      items: pageRows.map((row) => ({
        id: row.id,
        actorID: row.actorId,
        action: row.action,
        targetType: row.targetType,
        targetID: row.targetId,
        detail: row.detail,
        createdAt: row.createdAt,
      })),
      nextCursor,
    });
  } catch (error) {
    console.error('OpenIM admin audit list error:', error);
    res.status(500).json({ error: 'Failed to load audit logs' });
  }
});

router.post('/admin/messages/:messageId/revoke', authenticate, authorize('admin'), async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const messageId = String(req.params.messageId || '').trim();
    if (!messageId) {
      res.status(400).json({ error: 'messageId is required' });
      return;
    }

    const body = (req.body ?? {}) as {
      conversationID?: unknown;
      conversationId?: unknown;
      groupID?: unknown;
      groupId?: unknown;
      userID?: unknown;
      userId?: unknown;
      reportID?: unknown;
      reportId?: unknown;
      resolutionNote?: unknown;
    };

    const conversationRaw = body.conversationID ?? body.conversationId;
    const groupRaw = body.groupID ?? body.groupId;
    const userRaw = body.userID ?? body.userId;

    await openIMMessageService.revokeMessage({
      messageId,
      conversationId: typeof conversationRaw === 'string' ? conversationRaw : null,
      groupId: typeof groupRaw === 'string' ? groupRaw : null,
      userId: typeof userRaw === 'string' ? userRaw : null,
    });

    const reportIdRaw = body.reportID ?? body.reportId;
    const reportId = typeof reportIdRaw === 'string' ? reportIdRaw.trim() : '';
    const adminUserId = req.user?.userId || null;
    const resolutionNoteRaw = typeof body.resolutionNote === 'string' ? body.resolutionNote.trim().slice(0, 2000) : '';
    if (reportId && adminUserId) {
      await prisma.openIMMessageReport.updateMany({
        where: { id: reportId },
        data: {
          status: 'resolved',
          resolvedAt: new Date(),
          resolvedBy: adminUserId,
          resolutionNote: resolutionNoteRaw || 'resolved by message revoke',
        },
      });
    }

    if (adminUserId) {
      await writeAdminAuditLog(
        adminUserId,
        'openim.message.revoke',
        'openim_message',
        messageId,
        {
          reportId: reportId || null,
        } as Prisma.InputJsonValue
      );
    }

    res.json({ success: true, messageID: messageId, action: 'revoke' });
  } catch (error) {
    console.error('OpenIM admin revoke message error:', error);
    res.status(500).json({ error: 'Failed to revoke message' });
  }
});

router.post('/admin/messages/:messageId/delete', authenticate, authorize('admin'), async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const messageId = String(req.params.messageId || '').trim();
    if (!messageId) {
      res.status(400).json({ error: 'messageId is required' });
      return;
    }

    const body = (req.body ?? {}) as {
      conversationID?: unknown;
      conversationId?: unknown;
      groupID?: unknown;
      groupId?: unknown;
      userID?: unknown;
      userId?: unknown;
      reportID?: unknown;
      reportId?: unknown;
      resolutionNote?: unknown;
    };

    const conversationRaw = body.conversationID ?? body.conversationId;
    const groupRaw = body.groupID ?? body.groupId;
    const userRaw = body.userID ?? body.userId;

    await openIMMessageService.deleteMessage({
      messageId,
      conversationId: typeof conversationRaw === 'string' ? conversationRaw : null,
      groupId: typeof groupRaw === 'string' ? groupRaw : null,
      userId: typeof userRaw === 'string' ? userRaw : null,
    });

    const reportIdRaw = body.reportID ?? body.reportId;
    const reportId = typeof reportIdRaw === 'string' ? reportIdRaw.trim() : '';
    const adminUserId = req.user?.userId || null;
    const resolutionNoteRaw = typeof body.resolutionNote === 'string' ? body.resolutionNote.trim().slice(0, 2000) : '';
    if (reportId && adminUserId) {
      await prisma.openIMMessageReport.updateMany({
        where: { id: reportId },
        data: {
          status: 'resolved',
          resolvedAt: new Date(),
          resolvedBy: adminUserId,
          resolutionNote: resolutionNoteRaw || 'resolved by message delete',
        },
      });
    }

    if (adminUserId) {
      await writeAdminAuditLog(
        adminUserId,
        'openim.message.delete',
        'openim_message',
        messageId,
        {
          reportId: reportId || null,
        } as Prisma.InputJsonValue
      );
    }

    res.json({ success: true, messageID: messageId, action: 'delete' });
  } catch (error) {
    console.error('OpenIM admin delete message error:', error);
    res.status(500).json({ error: 'Failed to delete message' });
  }
});

router.get('/bootstrap', authenticate, async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const userId = req.user?.userId;
    if (!userId) {
      res.status(401).json({ error: 'Unauthorized' });
      return;
    }

    const bootstrap = await openIMTokenService.bootstrapForUser(userId);
    res.json(bootstrap);
  } catch (error) {
    console.error('OpenIM bootstrap error:', error);
    res.status(500).json({ error: error instanceof Error ? error.message : 'OpenIM bootstrap failed' });
  }
});

router.get('/health', authenticate, async (_req: AuthRequest, res: Response): Promise<void> => {
  res.json({
    enabled: openIMClient.isEnabled(),
    timestamp: new Date().toISOString(),
  });
});

export default router;
