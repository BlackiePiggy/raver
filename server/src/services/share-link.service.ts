import crypto from 'crypto';
import { Prisma, PrismaClient, ShareLink } from '@prisma/client';
import { tencentIMGroupService } from '../modules/im';

const SHARE_BASE_URL = 'https://raver.app';
const SHARE_CODE_ALPHABET = '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz';
const NEWS_MARKER = '#RAVER_NEWS';

const userCardType = 'user_card' as const;
const squadCardType = 'squad_card' as const;
const postType = 'post' as const;
const eventType = 'event' as const;
const newsType = 'news' as const;
const squadInviteType = 'squad_invite' as const;
const djType = 'dj' as const;
const setType = 'set' as const;
const labelType = 'label' as const;
const festivalType = 'festival' as const;
const rankingBoardType = 'ranking_board' as const;
const circleIdType = 'circle_id' as const;
const ratingEventType = 'rating_event' as const;
const ratingUnitType = 'rating_unit' as const;

export type ShareTargetType =
  | typeof userCardType
  | typeof squadCardType
  | typeof postType
  | typeof eventType
  | typeof newsType
  | typeof squadInviteType
  | typeof djType
  | typeof setType
  | typeof labelType
  | typeof festivalType
  | typeof rankingBoardType
  | typeof circleIdType
  | typeof ratingEventType
  | typeof ratingUnitType;

export type ShareEventType =
  | 'create'
  | 'copy'
  | 'open'
  | 'scan'
  | 'redirect'
  | 'app_open'
  | 'install_click'
  | 'invite_accept'
  | 'reward_grant'
  | 'revoke';

export class ShareLinkError extends Error {
  code: string;
  status: number;

  constructor(code: string, status: number, message: string) {
    super(message);
    this.code = code;
    this.status = status;
  }
}

type ResolveInput = {
  prisma: PrismaClient;
  targetType: string;
  targetId: string;
  userId?: string | null;
  channel?: string | null;
  campaign?: string | null;
  preferPermanent?: boolean;
  expiresInHours?: number | null;
  maxUses?: number | null;
  targetSeed?: ClientShareTargetSeedInput | null;
};

type ClientShareTargetSeedInput = {
  canonicalUrl?: string | null;
  deepLink?: string | null;
  fallbackUrl?: string | null;
  title?: string | null;
  subtitle?: string | null;
  imageUrl?: string | null;
  previewType?: string | null;
  visibility?: string | null;
};

type ShareEventInput = {
  prisma: PrismaClient;
  code: string;
  eventType: string;
  channel?: string | null;
  userId?: string | null;
  anonymousId?: string | null;
  platform?: string | null;
  userAgent?: string | null;
  ipHash?: string | null;
  referrer?: string | null;
  metadata?: Prisma.InputJsonValue;
};

type RedeemInviteInput = {
  prisma: PrismaClient;
  code: string;
  userId: string;
  channel?: string | null;
  platform?: string | null;
  userAgent?: string | null;
  referrer?: string | null;
};

type ShareTargetSeed = {
  targetType: ShareTargetType;
  targetId: string;
  canonicalUrl: string;
  deepLink: string;
  fallbackUrl: string;
  title: string;
  subtitle: string | null;
  imageUrl: string | null;
  previewType: string;
  visibility: string;
  preferredCode?: string | null;
};

export type ShareLinkPayloadDTO = {
  code: string;
  shortUrl: string;
  canonicalUrl: string;
  deepLink: string;
  fallbackUrl: string;
  qrCodeUrl: string;
  posterUrl: string | null;
  title: string;
  subtitle: string | null;
  imageUrl: string | null;
  previewType: string;
  visibility: string;
  status: string;
  expiresAt: string | null;
  maxUses: number | null;
  usedCount: number;
  metadata: Prisma.JsonValue | null;
};

export type RedeemInviteResultDTO = {
  success: true;
  squadId: string;
  code: string;
  isMember: true;
  alreadyMember: boolean;
  rewardStatus: string;
  rewardReason: string | null;
};

type RewardDecision = {
  status: 'granted' | 'rejected';
  reason: string;
  rewardType: string | null;
  grantedAt: Date | null;
  qualifiedAt: Date | null;
  payload?: Prisma.InputJsonValue | Prisma.NullableJsonNullValueInput;
};

const SHARE_TARGET_TYPES = new Set<ShareTargetType>([
  userCardType,
  squadCardType,
  postType,
  eventType,
  newsType,
  squadInviteType,
  djType,
  setType,
  labelType,
  festivalType,
  rankingBoardType,
  circleIdType,
  ratingEventType,
  ratingUnitType,
]);

const SHARE_EVENT_TYPES = new Set<ShareEventType>([
  'create',
  'copy',
  'open',
  'scan',
  'redirect',
  'app_open',
  'install_click',
  'invite_accept',
  'reward_grant',
  'revoke',
]);

const DEFAULT_INVITE_EXPIRES_IN_HOURS = 72;
const DEFAULT_INVITE_MAX_USES = 10;
const MAX_INVITE_EXPIRES_IN_HOURS = 24 * 30;
const MAX_INVITE_USES = 100;
const DEFAULT_INVITE_REWARD_TYPE = 'squad_invite_join_v1';

const normalizeTargetType = (value: string): ShareTargetType => {
  const normalized = String(value || '').trim() as ShareTargetType;
  if (!SHARE_TARGET_TYPES.has(normalized)) {
    throw new ShareLinkError('unsupported_target_type', 400, `Unsupported share target type: ${value}`);
  }
  return normalized;
};

const normalizeEventType = (value: string): ShareEventType => {
  const normalized = String(value || '').trim() as ShareEventType;
  if (!SHARE_EVENT_TYPES.has(normalized)) {
    throw new ShareLinkError('unsupported_event_type', 400, `Unsupported share event type: ${value}`);
  }
  return normalized;
};

const normalizeTargetId = (value: string): string => {
  const normalized = String(value || '').trim();
  if (!normalized) {
    throw new ShareLinkError('invalid_target_id', 400, 'targetId is required');
  }
  return normalized;
};

const normalizeOptionalPositiveInteger = (value: number | null | undefined): number | null => {
  if (value === null || value === undefined) return null;
  if (!Number.isFinite(value)) {
    throw new ShareLinkError('invalid_numeric_option', 400, 'Numeric share option is invalid');
  }
  const normalized = Math.floor(value);
  if (normalized <= 0) {
    throw new ShareLinkError('invalid_numeric_option', 400, 'Numeric share option must be greater than zero');
  }
  return normalized;
};

const singleLine = (value: string): string => String(value || '').replace(/\s+/g, ' ').trim();

const excerpt = (value: string, maxLength = 120): string => {
  const normalized = singleLine(value);
  if (!normalized) return '';
  if (normalized.length <= maxLength) return normalized;
  return `${normalized.slice(0, maxLength - 1)}…`;
};

const optionalHttpUrl = (value: string | null | undefined): string | null => {
  const normalized = singleLine(value || '');
  if (!normalized) return null;
  if (!/^https?:\/\//i.test(normalized)) return null;
  return normalized;
};

const joinUrl = (pathname: string): string => {
  const url = new URL(SHARE_BASE_URL);
  url.pathname = pathname.startsWith('/') ? pathname : `/${pathname}`;
  return url.toString();
};

export const buildShareShortUrl = (code: string): string => joinUrl(`/s/${encodeURIComponent(String(code || '').trim())}`);

export const buildShareQrCodeUrl = (code: string): string => joinUrl(`/qr/${encodeURIComponent(String(code || '').trim())}.png`);

export const buildSharePosterUrl = (code: string): string => joinUrl(`/poster/${encodeURIComponent(String(code || '').trim())}.png`);

const buildClientTargetSeed = (
  targetType: ShareTargetType,
  targetId: string,
  input?: ClientShareTargetSeedInput | null
): ShareTargetSeed | null => {
  const canonicalUrl = optionalHttpUrl(input?.canonicalUrl);
  const fallbackUrl = optionalHttpUrl(input?.fallbackUrl) || canonicalUrl;
  const title = singleLine(input?.title || '');
  const deepLink = singleLine(input?.deepLink || '');
  if (!canonicalUrl || !fallbackUrl || !title || !deepLink) {
    return null;
  }

  return {
    targetType,
    targetId,
    canonicalUrl,
    deepLink,
    fallbackUrl,
    title,
    subtitle: excerpt(input?.subtitle || '', 120) || null,
    imageUrl: optionalHttpUrl(input?.imageUrl),
    previewType: singleLine(input?.previewType || '') || 'content_card',
    visibility: singleLine(input?.visibility || '') || 'public',
  };
};

const buildRewardDecision = (
  status: RewardDecision['status'],
  reason: string,
  options?: {
    rewardType?: string | null;
    qualifiedAt?: Date | null;
    grantedAt?: Date | null;
    payload?: Prisma.InputJsonValue | Prisma.NullableJsonNullValueInput;
  }
): RewardDecision => ({
  status,
  reason,
  rewardType: options?.rewardType ?? null,
  qualifiedAt: options?.qualifiedAt ?? null,
  grantedAt: options?.grantedAt ?? null,
  payload: options?.payload,
});

const decideInviteReward = async (
  prisma: Prisma.TransactionClient,
  input: {
    inviterUserId: string | null;
    inviteeUserId: string;
    squadId: string;
    shareLinkId: string;
    alreadyMember: boolean;
  }
): Promise<RewardDecision> => {
  if (!input.inviterUserId) {
    return buildRewardDecision('rejected', 'missing_inviter');
  }

  if (input.inviterUserId === input.inviteeUserId) {
    return buildRewardDecision('rejected', 'self_invite');
  }

  if (input.alreadyMember) {
    return buildRewardDecision('rejected', 'already_member');
  }

  const existingGranted = await prisma.inviteReferral.findFirst({
    where: {
      inviteeUserId: input.inviteeUserId,
      rewardStatus: 'granted',
      NOT: {
        linkId: input.shareLinkId,
      },
    },
    select: {
      id: true,
      inviterUserId: true,
      squadId: true,
      grantedAt: true,
    },
  });

  if (existingGranted) {
    return buildRewardDecision('rejected', 'duplicate_rewarded_invitee', {
      payload: {
        previousReferralId: existingGranted.id,
        previousInviterUserId: existingGranted.inviterUserId,
        previousSquadId: existingGranted.squadId,
        previousGrantedAt: existingGranted.grantedAt?.toISOString() ?? null,
      },
    });
  }

  const now = new Date();
  return buildRewardDecision('granted', 'qualified_join', {
    rewardType: DEFAULT_INVITE_REWARD_TYPE,
    qualifiedAt: now,
    grantedAt: now,
    payload: {
      rule: 'phase1_first_successful_squad_invite_join',
      squadId: input.squadId,
    },
  });
};

const base62Code = (length = 8): string => {
  const bytes = crypto.randomBytes(length);
  let out = '';
  for (let i = 0; i < length; i += 1) {
    out += SHARE_CODE_ALPHABET[bytes[i] % SHARE_CODE_ALPHABET.length];
  }
  return out;
};

const readNewsValueAfterPrefix = (line: string, key: string): string => {
  const prefixes = [`${key}：`, `${key}:`, `${key.toUpperCase()}：`, `${key.toUpperCase()}:`];
  for (const prefix of prefixes) {
    if (!line.startsWith(prefix)) continue;
    const value = line.slice(prefix.length).trim();
    if (value) return value;
  }
  return '';
};

const decodeNewsBodyBase64 = (encoded: string): string => {
  const source = encoded.trim();
  if (!source) return '';
  try {
    return Buffer.from(source, 'base64').toString('utf8').trim();
  } catch {
    return '';
  }
};

const decodeRaverNewsDraft = (
  content: string
): { title: string; summary: string; body: string } | null => {
  const lines = String(content || '')
    .split(/\r?\n/g)
    .map((line) => line.trim())
    .filter(Boolean);
  if (!lines.includes(NEWS_MARKER)) {
    return null;
  }

  const read = (keys: string[]): string => {
    for (const line of lines) {
      for (const key of keys) {
        const value = readNewsValueAfterPrefix(line, key);
        if (value) return value;
      }
    }
    return '';
  };

  const title = read(['标题', 'title']) || '未命名资讯';
  const summary = read(['摘要', 'summary']) || '';
  const bodyEncoded = read(['正文MD64', 'content_md64', 'body_md64']);
  const body = decodeNewsBodyBase64(bodyEncoded) || read(['正文', 'content', 'body']) || '';

  return {
    title: singleLine(title) || '未命名资讯',
    summary: singleLine(summary),
    body,
  };
};

const ensureUniqueCode = async (prisma: PrismaClient, preferredCode?: string | null): Promise<string> => {
  const preferred = String(preferredCode || '').trim();
  if (preferred) {
    const existing = await prisma.shareLink.findUnique({ where: { code: preferred }, select: { id: true } });
    if (!existing) {
      return preferred;
    }
  }

  for (let attempt = 0; attempt < 20; attempt += 1) {
    const candidate = base62Code(8);
    const existing = await prisma.shareLink.findUnique({ where: { code: candidate }, select: { id: true } });
    if (!existing) {
      return candidate;
    }
  }

  throw new ShareLinkError('share_code_generation_failed', 500, 'Failed to generate unique share code');
};

const buildTargetSeed = async (
  prisma: PrismaClient,
  targetType: ShareTargetType,
  targetId: string
): Promise<ShareTargetSeed> => {
  if (targetType === userCardType) {
    const user = await prisma.user.findUnique({
      where: { id: targetId },
      select: {
        id: true,
        username: true,
        displayName: true,
        avatarUrl: true,
        bio: true,
        location: true,
        profileShareCode: true,
      },
    });
    if (!user) {
      throw new ShareLinkError('target_not_found', 404, 'User not found');
    }
    const handle = singleLine(user.username) || user.id;
    const subtitle = singleLine([user.bio, user.location].filter(Boolean).join(' · '));
    return {
      targetType,
      targetId: user.id,
      canonicalUrl: joinUrl(`/u/${encodeURIComponent(handle)}`),
      deepLink: `raver://profile/${encodeURIComponent(user.id)}`,
      fallbackUrl: joinUrl(`/u/${encodeURIComponent(handle)}`),
      title: singleLine(user.displayName || user.username || 'Raver 用户'),
      subtitle: subtitle || null,
      imageUrl: user.avatarUrl || null,
      previewType: 'profile_card',
      visibility: 'public',
      preferredCode: user.profileShareCode,
    };
  }

  if (targetType === squadCardType) {
    const squad = await prisma.squad.findUnique({
      where: { id: targetId },
      select: {
        id: true,
        name: true,
        description: true,
        avatarUrl: true,
        isPublic: true,
        shareCode: true,
      },
    });
    if (!squad) {
      throw new ShareLinkError('target_not_found', 404, 'Squad not found');
    }
    return {
      targetType,
      targetId: squad.id,
      canonicalUrl: joinUrl(`/g/${encodeURIComponent(squad.id)}`),
      deepLink: `raver://squad/${encodeURIComponent(squad.id)}`,
      fallbackUrl: joinUrl(`/g/${encodeURIComponent(squad.id)}`),
      title: singleLine(squad.name || 'Raver 小队'),
      subtitle: excerpt(squad.description || '', 120) || null,
      imageUrl: squad.avatarUrl || null,
      previewType: 'squad_card',
      visibility: squad.isPublic ? 'public' : 'members_only',
      preferredCode: squad.shareCode,
    };
  }

  if (targetType === postType) {
    const post = await prisma.post.findUnique({
      where: { id: targetId },
      select: {
        id: true,
        content: true,
        images: true,
        user: {
          select: {
            displayName: true,
            username: true,
          },
        },
      },
    });
    if (!post) {
      throw new ShareLinkError('target_not_found', 404, 'Post not found');
    }
    const authorName = singleLine(post.user.displayName || post.user.username || 'Raver 用户');
    return {
      targetType,
      targetId: post.id,
      canonicalUrl: joinUrl(`/p/${encodeURIComponent(post.id)}`),
      deepLink: `raver://community/post/${encodeURIComponent(post.id)}`,
      fallbackUrl: joinUrl(`/p/${encodeURIComponent(post.id)}`),
      title: `${authorName} 的动态`,
      subtitle: excerpt(post.content, 120) || null,
      imageUrl: post.images.find((item) => singleLine(item).length > 0) ?? null,
      previewType: 'content_card',
      visibility: 'public',
    };
  }

  if (targetType === eventType) {
    const event = await prisma.event.findUnique({
      where: { id: targetId },
      select: {
        id: true,
        slug: true,
        name: true,
        venueName: true,
        city: true,
        coverImageUrl: true,
      },
    });
    if (!event) {
      throw new ShareLinkError('target_not_found', 404, 'Event not found');
    }
    const subtitle = singleLine([event.venueName, event.city].filter(Boolean).join(' · '));
    return {
      targetType,
      targetId: event.id,
      canonicalUrl: joinUrl(`/e/${encodeURIComponent(singleLine(event.slug) || event.id)}`),
      deepLink: `raver://event/${encodeURIComponent(event.id)}`,
      fallbackUrl: joinUrl(`/e/${encodeURIComponent(singleLine(event.slug) || event.id)}`),
      title: singleLine(event.name || 'Raver 活动'),
      subtitle: subtitle || null,
      imageUrl: event.coverImageUrl || null,
      previewType: 'content_card',
      visibility: 'public',
    };
  }

  if (targetType === newsType) {
    const post = await prisma.post.findUnique({
      where: { id: targetId },
      select: {
        id: true,
        content: true,
        images: true,
      },
    });
    if (!post) {
      throw new ShareLinkError('target_not_found', 404, 'News article not found');
    }
    const decoded = decodeRaverNewsDraft(post.content);
    if (!decoded) {
      throw new ShareLinkError('unsupported_target_payload', 400, 'Target post is not a supported news article');
    }
    const subtitle = decoded.summary || excerpt(decoded.body, 120);
    return {
      targetType,
      targetId: post.id,
      canonicalUrl: joinUrl(`/n/${encodeURIComponent(post.id)}`),
      deepLink: `raver://news/${encodeURIComponent(post.id)}`,
      fallbackUrl: joinUrl(`/n/${encodeURIComponent(post.id)}`),
      title: singleLine(decoded.title || 'Raver 资讯'),
      subtitle: subtitle || null,
      imageUrl: post.images.find((item) => singleLine(item).length > 0) ?? null,
      previewType: 'content_card',
      visibility: 'public',
    };
  }

  throw new ShareLinkError('unsupported_target_type', 400, `Unsupported share target type: ${targetType}`);
};

const updatePermanentCodeIfNeeded = async (
  prisma: PrismaClient,
  targetType: ShareTargetType,
  targetId: string,
  code: string
): Promise<void> => {
  if (targetType === userCardType) {
    await prisma.user.updateMany({
      where: {
        id: targetId,
        profileShareCode: null,
      },
      data: {
        profileShareCode: code,
      },
    });
    return;
  }

  if (targetType === squadCardType) {
    await prisma.squad.updateMany({
      where: {
        id: targetId,
        shareCode: null,
      },
      data: {
        shareCode: code,
      },
    });
  }
};

const mapShareLink = (shareLink: ShareLink): ShareLinkPayloadDTO => ({
  code: shareLink.code,
  shortUrl: buildShareShortUrl(shareLink.code),
  canonicalUrl: shareLink.canonicalUrl,
  deepLink: shareLink.deepLink,
  fallbackUrl: shareLink.fallbackUrl,
  qrCodeUrl: buildShareQrCodeUrl(shareLink.code),
  posterUrl: shareLink.posterUrl || buildSharePosterUrl(shareLink.code),
  title: shareLink.title,
  subtitle: shareLink.subtitle,
  imageUrl: shareLink.imageUrl,
  previewType: shareLink.previewType,
  visibility: shareLink.visibility,
  status: shareLink.status,
  expiresAt: shareLink.expiresAt ? shareLink.expiresAt.toISOString() : null,
  maxUses: shareLink.maxUses,
  usedCount: shareLink.usedCount,
  metadata: shareLink.metadata,
});

export const resolveOrCreateShareLink = async (input: ResolveInput): Promise<ShareLinkPayloadDTO> => {
  const targetType = normalizeTargetType(input.targetType);
  const targetId = normalizeTargetId(input.targetId);
  const preferPermanent = input.preferPermanent !== false;
  const expiresInHours = normalizeOptionalPositiveInteger(input.expiresInHours);
  const maxUses = normalizeOptionalPositiveInteger(input.maxUses);
  const clientSeed = buildClientTargetSeed(targetType, targetId, input.targetSeed);

  if (expiresInHours !== null && expiresInHours > MAX_INVITE_EXPIRES_IN_HOURS) {
    throw new ShareLinkError(
      'invite_expiry_too_large',
      400,
      `Invite expiry cannot exceed ${MAX_INVITE_EXPIRES_IN_HOURS} hours`
    );
  }

  if (maxUses !== null && maxUses > MAX_INVITE_USES) {
    throw new ShareLinkError('invite_max_uses_too_large', 400, `Invite max uses cannot exceed ${MAX_INVITE_USES}`);
  }

  if (targetType === squadInviteType) {
    if (!input.userId) {
      throw new ShareLinkError('unauthorized', 401, 'Login is required to create squad invite links');
    }

    const squad = await input.prisma.squad.findUnique({
      where: { id: targetId },
      select: {
        id: true,
        name: true,
        description: true,
        avatarUrl: true,
        isPublic: true,
        maxMembers: true,
        members: {
          where: { userId: input.userId },
          select: { id: true },
          take: 1,
        },
      },
    });

    if (!squad) {
      throw new ShareLinkError('target_not_found', 404, 'Squad not found');
    }

    if (squad.members.length === 0) {
      throw new ShareLinkError('forbidden', 403, 'Only squad members can create invite links');
    }

    const inviteExpiresAt = new Date(
      Date.now() + (expiresInHours ?? DEFAULT_INVITE_EXPIRES_IN_HOURS) * 60 * 60 * 1000
    );
    const inviteMaxUses = maxUses ?? DEFAULT_INVITE_MAX_USES;
    const existing = await input.prisma.shareLink.findFirst({
      where: {
        targetType,
        targetId: squad.id,
        status: 'active',
        createdBy: input.userId,
        expiresAt: {
          gt: new Date(),
        },
      },
      orderBy: {
        createdAt: 'desc',
      },
    });

    const metadata: Prisma.InputJsonValue = {
      channel: input.channel || null,
      campaign: input.campaign || null,
      source: 'ios_share_system',
      inviterUserId: input.userId,
      squadId: squad.id,
      inviteMode: squad.isPublic ? 'share_invite_public_squad' : 'share_invite_private_squad',
    };

    if (existing && existing.usedCount < (existing.maxUses ?? inviteMaxUses)) {
      const updated = await input.prisma.shareLink.update({
        where: { id: existing.id },
        data: {
          canonicalUrl: joinUrl(`/g/${encodeURIComponent(squad.id)}?inviteCode=${encodeURIComponent(existing.code)}`),
          deepLink: `raver://squad/${encodeURIComponent(squad.id)}?inviteCode=${encodeURIComponent(existing.code)}`,
          fallbackUrl: joinUrl(`/g/${encodeURIComponent(squad.id)}?inviteCode=${encodeURIComponent(existing.code)}`),
          title: `加入「${singleLine(squad.name || 'Raver 小队')}」`,
          subtitle: excerpt(squad.description || '', 120) || '来自小队成员的邀请',
          imageUrl: squad.avatarUrl || null,
          previewType: 'invite_card',
          visibility: 'private_invite',
          expiresAt: inviteExpiresAt,
          maxUses: inviteMaxUses,
          metadata,
        },
      });
      return mapShareLink(updated);
    }

    const code = await ensureUniqueCode(input.prisma);
    const created = await input.prisma.shareLink.create({
      data: {
        code,
        targetType,
        targetId: squad.id,
        canonicalUrl: joinUrl(`/g/${encodeURIComponent(squad.id)}?inviteCode=${encodeURIComponent(code)}`),
        deepLink: `raver://squad/${encodeURIComponent(squad.id)}?inviteCode=${encodeURIComponent(code)}`,
        fallbackUrl: joinUrl(`/g/${encodeURIComponent(squad.id)}?inviteCode=${encodeURIComponent(code)}`),
        title: `加入「${singleLine(squad.name || 'Raver 小队')}」`,
        subtitle: excerpt(squad.description || '', 120) || '来自小队成员的邀请',
        imageUrl: squad.avatarUrl || null,
        previewType: 'invite_card',
        visibility: 'private_invite',
        createdBy: input.userId,
        expiresAt: inviteExpiresAt,
        maxUses: inviteMaxUses,
        metadata,
      },
    });

    await input.prisma.shareLinkEvent.create({
      data: {
        linkId: created.id,
        eventType: 'create',
        channel: input.channel || null,
        userId: input.userId,
        platform: 'iOS',
        metadata,
      },
    });

    return mapShareLink(created);
  }

  let seed: ShareTargetSeed;
  try {
    seed = await buildTargetSeed(input.prisma, targetType, targetId);
  } catch (error) {
    if (!clientSeed) {
      throw error;
    }
    seed = clientSeed;
  }

  const existing = await input.prisma.shareLink.findFirst({
    where: {
      targetType,
      targetId: seed.targetId,
      status: 'active',
      ...(preferPermanent ? { expiresAt: null } : {}),
    },
    orderBy: {
      createdAt: 'asc',
    },
  });

  const metadata: Prisma.InputJsonValue = {
    channel: input.channel || null,
    campaign: input.campaign || null,
    source: 'ios_share_system',
  };

  if (existing) {
    const updated = await input.prisma.shareLink.update({
      where: { id: existing.id },
      data: {
        canonicalUrl: seed.canonicalUrl,
        deepLink: seed.deepLink,
        fallbackUrl: seed.fallbackUrl,
        title: seed.title,
        subtitle: seed.subtitle,
        imageUrl: seed.imageUrl,
        previewType: seed.previewType,
        visibility: seed.visibility,
        metadata,
      },
    });
    return mapShareLink(updated);
  }

  const code = await ensureUniqueCode(input.prisma, seed.preferredCode);
  await updatePermanentCodeIfNeeded(input.prisma, targetType, seed.targetId, code);

  const created = await input.prisma.shareLink.create({
    data: {
      code,
      targetType,
      targetId: seed.targetId,
      canonicalUrl: seed.canonicalUrl,
      deepLink: seed.deepLink,
      fallbackUrl: seed.fallbackUrl,
      title: seed.title,
      subtitle: seed.subtitle,
      imageUrl: seed.imageUrl,
      previewType: seed.previewType,
      visibility: seed.visibility,
      createdBy: input.userId || null,
      metadata,
    },
  });

  await input.prisma.shareLinkEvent.create({
    data: {
      linkId: created.id,
      eventType: 'create',
      channel: input.channel || null,
      userId: input.userId || null,
      platform: 'iOS',
      metadata,
    },
  });

  return mapShareLink(created);
};

export const redeemShareLinkInvite = async (input: RedeemInviteInput): Promise<RedeemInviteResultDTO> => {
  const code = String(input.code || '').trim();
  const userId = String(input.userId || '').trim();
  if (!code) {
    throw new ShareLinkError('invalid_code', 400, 'Share code is required');
  }
  if (!userId) {
    throw new ShareLinkError('unauthorized', 401, 'Login is required to redeem invite links');
  }

  const shareLink = await input.prisma.shareLink.findUnique({
    where: { code },
  });
  if (!shareLink) {
    throw new ShareLinkError('not_found', 404, 'Share link not found');
  }
  if (shareLink.targetType !== squadInviteType) {
    throw new ShareLinkError('unsupported_target_type', 400, 'This share link is not a squad invite');
  }
  if (shareLink.status !== 'active') {
    throw new ShareLinkError('revoked', 410, 'This invite link is no longer active');
  }
  if (shareLink.createdBy && shareLink.createdBy === userId) {
    throw new ShareLinkError('self_invite_not_allowed', 400, 'You cannot redeem your own squad invite');
  }
  if (shareLink.createdBy) {
    const block = await input.prisma.userBlock.findFirst({
      where: {
        OR: [
          { blockerUserId: shareLink.createdBy, blockedUserId: userId },
          { blockerUserId: userId, blockedUserId: shareLink.createdBy },
        ],
      },
      select: { id: true },
    });
    if (block) {
      throw new ShareLinkError('blocked_relationship', 403, 'This invite cannot be used because of a blocking relationship');
    }
  }
  if (shareLink.expiresAt && shareLink.expiresAt.getTime() <= Date.now()) {
    throw new ShareLinkError('expired', 410, 'This invite link has expired');
  }
  if (shareLink.maxUses !== null && shareLink.usedCount >= shareLink.maxUses) {
    throw new ShareLinkError('invite_exhausted', 410, 'This invite link has reached its maximum uses');
  }

  const squad = await input.prisma.squad.findUnique({
    where: { id: shareLink.targetId },
    select: {
      id: true,
      maxMembers: true,
    },
  });
  if (!squad) {
    throw new ShareLinkError('target_not_found', 404, 'Squad not found');
  }

  const existingMember = await input.prisma.squadMember.findUnique({
    where: {
      squadId_userId: {
        squadId: squad.id,
        userId,
      },
    },
    select: { id: true },
  });

  if (existingMember) {
    const settledReferral = await input.prisma.$transaction(async (tx) => {
      const rewardDecision = await decideInviteReward(tx, {
        inviterUserId: shareLink.createdBy,
        inviteeUserId: userId,
        squadId: squad.id,
        shareLinkId: shareLink.id,
        alreadyMember: true,
      });

      const existingReferral = await tx.inviteReferral.findFirst({
        where: {
          linkId: shareLink.id,
          inviteeUserId: userId,
        },
        select: { id: true },
      });

      let referralId: string;
      if (existingReferral) {
        referralId = existingReferral.id;
        await tx.inviteReferral.update({
          where: { id: existingReferral.id },
          data: {
            squadId: squad.id,
            rewardStatus: rewardDecision.status,
            rewardType: rewardDecision.rewardType,
            rewardPayload: rewardDecision.payload,
            qualifiedAt: rewardDecision.qualifiedAt,
            grantedAt: rewardDecision.grantedAt,
            metadata: {
              source: 'share_link_redeem',
              rewardReason: rewardDecision.reason,
              alreadyMember: true,
            },
          },
        });
      } else {
        const referral = await tx.inviteReferral.create({
          data: {
            linkId: shareLink.id,
            inviterUserId: shareLink.createdBy || userId,
            inviteeUserId: userId,
            squadId: squad.id,
            rewardStatus: rewardDecision.status,
            rewardType: rewardDecision.rewardType,
            rewardPayload: rewardDecision.payload,
            qualifiedAt: rewardDecision.qualifiedAt,
            grantedAt: rewardDecision.grantedAt,
            metadata: {
              source: 'share_link_redeem',
              rewardReason: rewardDecision.reason,
              alreadyMember: true,
            },
          },
          select: { id: true },
        });
        referralId = referral.id;
      }

      await tx.shareLinkEvent.create({
        data: {
          linkId: shareLink.id,
          eventType: 'invite_accept',
          channel: input.channel || 'invite_redeem',
          userId,
          platform: input.platform || 'iOS',
          userAgent: input.userAgent || null,
          referrer: input.referrer || null,
          metadata: {
            squadId: squad.id,
            alreadyMember: true,
            referralId,
            rewardStatus: rewardDecision.status,
            rewardReason: rewardDecision.reason,
          },
        },
      });

      if (rewardDecision.status === 'granted') {
        await tx.shareLinkEvent.create({
          data: {
            linkId: shareLink.id,
            eventType: 'reward_grant',
            channel: input.channel || 'invite_redeem',
            userId: shareLink.createdBy || null,
            platform: input.platform || 'iOS',
            userAgent: input.userAgent || null,
            referrer: input.referrer || null,
            metadata: {
              squadId: squad.id,
              inviteeUserId: userId,
              referralId,
              rewardType: rewardDecision.rewardType,
              rewardReason: rewardDecision.reason,
            },
          },
        });
      }

      return {
        rewardStatus: rewardDecision.status,
        rewardReason: rewardDecision.reason,
      };
    });

    return {
      success: true,
      squadId: squad.id,
      code,
      isMember: true,
      alreadyMember: true,
      rewardStatus: settledReferral.rewardStatus,
      rewardReason: settledReferral.rewardReason,
    };
  }

  const memberCount = await input.prisma.squadMember.count({
    where: { squadId: squad.id },
  });
  if (memberCount >= squad.maxMembers) {
    throw new ShareLinkError('squad_full', 400, 'Squad is full');
  }

  try {
    const membership = await input.prisma.squadMember.create({
      data: {
        squadId: squad.id,
        userId,
        role: 'member',
        lastReadAt: new Date(),
      },
      select: { id: true },
    });

    try {
      await tencentIMGroupService.addGroupMembers(squad.id, [userId], 'share link invite redeem');
    } catch (error) {
      await input.prisma.squadMember.deleteMany({
        where: { id: membership.id },
      });
      throw error;
    }

    const settledReferral = await input.prisma.$transaction(async (tx) => {
      const rewardDecision = await decideInviteReward(tx, {
        inviterUserId: shareLink.createdBy,
        inviteeUserId: userId,
        squadId: squad.id,
        shareLinkId: shareLink.id,
        alreadyMember: false,
      });

      const existingReferral = await tx.inviteReferral.findFirst({
        where: {
          linkId: shareLink.id,
          inviteeUserId: userId,
        },
        select: { id: true },
      });

      let referralId: string;
      if (existingReferral) {
        referralId = existingReferral.id;
        await tx.inviteReferral.update({
          where: { id: existingReferral.id },
          data: {
            squadId: squad.id,
            rewardStatus: rewardDecision.status,
            rewardType: rewardDecision.rewardType,
            rewardPayload: rewardDecision.payload,
            qualifiedAt: rewardDecision.qualifiedAt,
            grantedAt: rewardDecision.grantedAt,
            metadata: {
              source: 'share_link_redeem',
              rewardReason: rewardDecision.reason,
            },
          },
        });
      } else {
        const referral = await tx.inviteReferral.create({
          data: {
            linkId: shareLink.id,
            inviterUserId: shareLink.createdBy || userId,
            inviteeUserId: userId,
            squadId: squad.id,
            rewardStatus: rewardDecision.status,
            rewardType: rewardDecision.rewardType,
            rewardPayload: rewardDecision.payload,
            qualifiedAt: rewardDecision.qualifiedAt,
            grantedAt: rewardDecision.grantedAt,
            metadata: {
              source: 'share_link_redeem',
              rewardReason: rewardDecision.reason,
            },
          },
          select: { id: true },
        });
        referralId = referral.id;
      }

      await tx.shareLinkEvent.create({
        data: {
          linkId: shareLink.id,
          eventType: 'invite_accept',
          channel: input.channel || 'invite_redeem',
          userId,
          platform: input.platform || 'iOS',
          userAgent: input.userAgent || null,
          referrer: input.referrer || null,
          metadata: {
            squadId: squad.id,
            referralId,
            rewardStatus: rewardDecision.status,
            rewardReason: rewardDecision.reason,
          },
        },
      });

      if (rewardDecision.status === 'granted') {
        await tx.shareLinkEvent.create({
          data: {
            linkId: shareLink.id,
            eventType: 'reward_grant',
            channel: input.channel || 'invite_redeem',
            userId: shareLink.createdBy || null,
            platform: input.platform || 'iOS',
            userAgent: input.userAgent || null,
            referrer: input.referrer || null,
            metadata: {
              squadId: squad.id,
              inviteeUserId: userId,
              referralId,
              rewardType: rewardDecision.rewardType,
              rewardReason: rewardDecision.reason,
            },
          },
        });
      }

      await tx.shareLink.update({
        where: { id: shareLink.id },
        data: {
          usedCount: {
            increment: 1,
          },
          clickCount: {
            increment: 1,
          },
        },
      });

      return {
        rewardStatus: rewardDecision.status,
        rewardReason: rewardDecision.reason,
      };
    });

    return {
      success: true,
      squadId: squad.id,
      code,
      isMember: true,
      alreadyMember: false,
      rewardStatus: settledReferral.rewardStatus,
      rewardReason: settledReferral.rewardReason,
    };
  } catch (error) {
    throw error;
  }
};

export const resetShareLinkInvite = async (
  prisma: PrismaClient,
  code: string,
  userId: string
): Promise<ShareLinkPayloadDTO> => {
  const normalizedCode = String(code || '').trim();
  if (!normalizedCode) {
    throw new ShareLinkError('invalid_code', 400, 'Share code is required');
  }
  if (!userId) {
    throw new ShareLinkError('unauthorized', 401, 'Login is required to reset invite links');
  }

  const shareLink = await prisma.shareLink.findUnique({
    where: { code: normalizedCode },
  });
  if (!shareLink) {
    throw new ShareLinkError('not_found', 404, 'Share link not found');
  }
  if (shareLink.targetType !== squadInviteType) {
    throw new ShareLinkError('unsupported_target_type', 400, 'Only squad invite links can be reset');
  }
  if (shareLink.createdBy !== userId) {
    throw new ShareLinkError('forbidden', 403, 'Only the invite creator can reset this invite');
  }

  await prisma.$transaction(async (tx) => {
    await tx.shareLink.update({
      where: { id: shareLink.id },
      data: {
        status: 'revoked',
      },
    });

    await tx.shareLinkEvent.create({
      data: {
        linkId: shareLink.id,
        eventType: 'revoke',
        channel: 'invite_reset',
        userId,
        platform: 'iOS',
        metadata: {
          source: 'share_link_reset',
        },
      },
    });
  });

  return resolveOrCreateShareLink({
    prisma,
    targetType: squadInviteType,
    targetId: shareLink.targetId,
    userId,
    channel: 'invite_reset',
    preferPermanent: false,
    expiresInHours: DEFAULT_INVITE_EXPIRES_IN_HOURS,
    maxUses: DEFAULT_INVITE_MAX_USES,
  });
};

export const getShareLinkByCode = async (
  prisma: PrismaClient,
  code: string
): Promise<ShareLinkPayloadDTO> => {
  const normalizedCode = String(code || '').trim();
  if (!normalizedCode) {
    throw new ShareLinkError('invalid_code', 400, 'Share code is required');
  }

  const shareLink = await prisma.shareLink.findUnique({
    where: { code: normalizedCode },
  });
  if (!shareLink) {
    throw new ShareLinkError('not_found', 404, 'Share link not found');
  }
  return mapShareLink(shareLink);
};

export const getRawShareLinkByCode = async (prisma: PrismaClient, code: string): Promise<ShareLink> => {
  const normalizedCode = String(code || '').trim();
  if (!normalizedCode) {
    throw new ShareLinkError('invalid_code', 400, 'Share code is required');
  }

  const shareLink = await prisma.shareLink.findUnique({
    where: { code: normalizedCode },
  });
  if (!shareLink) {
    throw new ShareLinkError('not_found', 404, 'Share link not found');
  }
  return shareLink;
};

export const recordShareLinkEvent = async (input: ShareEventInput): Promise<ShareLinkPayloadDTO> => {
  const normalizedCode = String(input.code || '').trim();
  if (!normalizedCode) {
    throw new ShareLinkError('invalid_code', 400, 'Share code is required');
  }
  const eventType = normalizeEventType(input.eventType);

  const shareLink = await input.prisma.shareLink.findUnique({
    where: { code: normalizedCode },
  });
  if (!shareLink) {
    throw new ShareLinkError('not_found', 404, 'Share link not found');
  }

  const updateData: Prisma.ShareLinkUpdateInput = {};
  if (eventType === 'scan') {
    updateData.scanCount = { increment: 1 };
  }
  if (eventType === 'open' || eventType === 'redirect' || eventType === 'app_open') {
    updateData.clickCount = { increment: 1 };
  }

  const updated = await input.prisma.$transaction(async (tx) => {
    await tx.shareLinkEvent.create({
      data: {
        linkId: shareLink.id,
        eventType,
        channel: input.channel || null,
        userId: input.userId || null,
        anonymousId: input.anonymousId || null,
        platform: input.platform || 'iOS',
        userAgent: input.userAgent || null,
        ipHash: input.ipHash || null,
        referrer: input.referrer || null,
        metadata: input.metadata,
      },
    });

    if (Object.keys(updateData).length === 0) {
      return shareLink;
    }

    return tx.shareLink.update({
      where: { id: shareLink.id },
      data: updateData,
    });
  });

  return mapShareLink(updated);
};
