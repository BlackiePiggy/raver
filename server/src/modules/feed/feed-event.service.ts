import { Prisma, PrismaClient } from '@prisma/client';
import {
  FEED_RANKING_WEIGHTS_VERSION,
  resolveFeedExperimentBucket,
} from './feed-ranking.config';

const prisma = new PrismaClient();

type FeedMode = 'recommended' | 'following' | 'latest';
type FeedEventType =
  | 'feed_impression'
  | 'feed_open_post'
  | 'feed_like'
  | 'feed_save'
  | 'feed_share'
  | 'feed_hide';

export type RecordFeedEventInput = {
  viewerId?: string;
  sessionId?: unknown;
  sessionID?: unknown;
  eventType?: unknown;
  postID?: unknown;
  postId?: unknown;
  feedMode?: unknown;
  position?: unknown;
  metadata?: unknown;
  experimentBucketOverride?: unknown;
};

export class FeedEventValidationError extends Error {
  readonly status: number;

  constructor(message: string, status = 400) {
    super(message);
    this.name = 'FeedEventValidationError';
    this.status = status;
  }
}

const feedEventTypeSet = new Set<FeedEventType>([
  'feed_impression',
  'feed_open_post',
  'feed_like',
  'feed_save',
  'feed_share',
  'feed_hide',
]);

const normalizeFeedEventSessionID = (value: unknown): string | null => {
  if (typeof value !== 'string') return null;
  const normalized = value.trim();
  if (!normalized) return null;
  return normalized.slice(0, 128);
};

const normalizeFeedEventType = (value: unknown): FeedEventType | null => {
  const normalized = typeof value === 'string' ? value.trim().toLowerCase() : '';
  return feedEventTypeSet.has(normalized as FeedEventType) ? (normalized as FeedEventType) : null;
};

const normalizeOptionalFeedMode = (value: unknown): FeedMode | null | 'invalid' => {
  if (value === null || value === undefined) return null;
  const normalized = String(value || '')
    .trim()
    .toLowerCase();
  if (!normalized) return null;
  if (normalized === 'recommended') return 'recommended';
  if (normalized === 'following') return 'following';
  if (normalized === 'latest') return 'latest';
  return 'invalid';
};

const normalizeFeedEventPosition = (value: unknown): number | null | 'invalid' => {
  if (value === null || value === undefined || value === '') return null;
  const parsed = Number(value);
  if (!Number.isFinite(parsed)) return 'invalid';
  const rounded = Math.floor(parsed);
  if (rounded < 0 || rounded > 10_000) return 'invalid';
  return rounded;
};

const normalizeFeedEventMetadata = (value: unknown): Prisma.InputJsonValue | null | 'invalid' => {
  if (value === null || value === undefined) return null;
  if (typeof value !== 'object') return 'invalid';
  try {
    const serialized = JSON.stringify(value);
    if (!serialized) return null;
    if (serialized.length > 8_000) return 'invalid';
    return JSON.parse(serialized) as Prisma.InputJsonValue;
  } catch {
    return 'invalid';
  }
};

const normalizeFeedEventPostId = (postID: unknown, postId: unknown): string | null => {
  const rawPostId =
    typeof postID === 'string'
      ? postID.trim()
      : typeof postId === 'string'
        ? postId.trim()
        : '';
  return rawPostId || null;
};

export const recordFeedEvent = async (input: RecordFeedEventInput): Promise<void> => {
  const sessionId = normalizeFeedEventSessionID(input.sessionId ?? input.sessionID);
  if (!sessionId) {
    throw new FeedEventValidationError('sessionId is required');
  }

  const eventType = normalizeFeedEventType(input.eventType);
  if (!eventType) {
    throw new FeedEventValidationError('eventType is invalid');
  }

  const feedMode = normalizeOptionalFeedMode(input.feedMode);
  if (feedMode === 'invalid') {
    throw new FeedEventValidationError('feedMode is invalid');
  }

  const position = normalizeFeedEventPosition(input.position);
  if (position === 'invalid') {
    throw new FeedEventValidationError('position is invalid');
  }

  const metadata = normalizeFeedEventMetadata(input.metadata);
  if (metadata === 'invalid') {
    throw new FeedEventValidationError('metadata is invalid');
  }

  let persistedMetadata: Prisma.InputJsonValue | undefined = metadata ?? undefined;
  if (feedMode === 'recommended') {
    const eventBucket = resolveFeedExperimentBucket(input.experimentBucketOverride, input.viewerId);
    const metadataObject: Prisma.JsonObject =
      metadata && typeof metadata === 'object' && !Array.isArray(metadata)
        ? { ...(metadata as Prisma.JsonObject) }
        : {};
    metadataObject.experimentBucket = eventBucket;
    metadataObject.weightsVersion = FEED_RANKING_WEIGHTS_VERSION;
    persistedMetadata = metadataObject;
  }

  const postId = normalizeFeedEventPostId(input.postID, input.postId);
  if (postId) {
    const exists = await prisma.post.findUnique({
      where: { id: postId },
      select: { id: true },
    });
    if (!exists) {
      throw new FeedEventValidationError('Post not found', 404);
    }
  }

  await prisma.feedEvent.create({
    data: {
      userId: input.viewerId ?? null,
      sessionId,
      eventType,
      postId,
      feedMode,
      position,
      metadata: persistedMetadata,
    },
  });
};
