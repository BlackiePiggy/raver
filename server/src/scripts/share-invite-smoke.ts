import 'dotenv/config';
import axios, { type Method } from 'axios';
import crypto from 'crypto';
import { PrismaClient } from '@prisma/client';

type ApiResponse<T> = {
  status: number;
  data: T;
  headers: Record<string, unknown>;
};

type AuthSuccessBody = {
  accessToken?: string;
  token?: string;
  user?: {
    id?: string;
  };
};

type ShareLinkBody = {
  code?: string;
  shortUrl?: string;
  deepLink?: string;
  status?: string;
  expiresAt?: string | null;
  maxUses?: number | null;
  usedCount?: number;
};

type RedeemBody = {
  success?: boolean;
  squadId?: string;
  code?: string;
  isMember?: boolean;
  alreadyMember?: boolean;
  rewardStatus?: string;
  rewardReason?: string | null;
  error?: string;
  message?: string;
};

const prisma = new PrismaClient();
const apiBaseUrl = (process.env.SHARE_INVITE_SMOKE_API_BASE_URL || 'http://127.0.0.1:3901/v1').replace(/\/+$/, '');
const publicBaseUrl = (process.env.SHARE_INVITE_SMOKE_PUBLIC_BASE_URL || 'http://127.0.0.1:3901').replace(/\/+$/, '');

const assert = (condition: boolean, message: string): void => {
  if (!condition) throw new Error(message);
};

const apiUrl = (path: string): string => `${apiBaseUrl}${path.startsWith('/') ? path : `/${path}`}`;
const publicUrl = (path: string): string => `${publicBaseUrl}${path.startsWith('/') ? path : `/${path}`}`;

const request = async <T>(
  method: Method,
  url: string,
  body?: unknown,
  token?: string,
  options?: { redirects?: number; responseType?: 'json' | 'text' }
): Promise<ApiResponse<T>> => {
  const response = await axios.request<T>({
    method,
    url,
    data: body,
    maxRedirects: options?.redirects ?? 0,
    responseType: options?.responseType,
    headers: {
      'Content-Type': 'application/json',
      'User-Agent': 'RaverShareInviteSmoke/1.0',
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
    },
    validateStatus: () => true,
  });
  return {
    status: response.status,
    data: response.data,
    headers: response.headers as Record<string, unknown>,
  };
};

const uniqueIdentity = (prefix: string): { username: string; email: string; password: string; displayName: string } => {
  const suffix = `${Date.now()}_${crypto.randomInt(1000, 9999)}`;
  const username = `${prefix}_${suffix}`;
  return {
    username,
    email: `${username}@example.com`,
    password: 'Passw0rd!',
    displayName: username,
  };
};

const registerUser = async (prefix: string): Promise<{ userId: string; token: string }> => {
  const identity = uniqueIdentity(prefix);
  const response = await request<AuthSuccessBody>('POST', apiUrl('/auth/register'), identity, undefined, {
    redirects: 0,
    responseType: 'json',
  });
  assert(response.status === 201, `register ${prefix} expected 201 but got ${response.status}`);
  const token = response.data.accessToken || response.data.token || '';
  const userId = response.data.user?.id || '';
  assert(Boolean(token), `register ${prefix} response missing token`);
  assert(Boolean(userId), `register ${prefix} response missing user.id`);
  return { userId, token };
};

const prepareSquad = async (leaderUserId: string): Promise<string> => {
  const squad = await prisma.squad.create({
    data: {
      name: `Share Invite Smoke ${Date.now()}`,
      description: 'Smoke test private invite squad',
      leaderId: leaderUserId,
      isPublic: false,
      maxMembers: 10,
      members: {
        create: {
          userId: leaderUserId,
          role: 'leader',
          lastReadAt: new Date(),
        },
      },
    },
    select: { id: true },
  });
  return squad.id;
};

const createInviteLink = async (
  squadId: string,
  token: string,
  options?: { maxUses?: number; expiresInHours?: number; channel?: string }
): Promise<ShareLinkBody & { code: string }> => {
  const resolve = await request<ShareLinkBody>(
    'POST',
    apiUrl('/share-links/resolve'),
    {
      targetType: 'squad_invite',
      targetId: squadId,
      channel: options?.channel || 'invite_smoke',
      campaign: 'share_invite_smoke',
      preferPermanent: false,
      expiresInHours: options?.expiresInHours ?? 1,
      maxUses: options?.maxUses ?? 2,
    },
    token,
    { redirects: 0, responseType: 'json' }
  );
  assert(resolve.status === 200, `invite resolve expected 200 but got ${resolve.status}`);
  const code = resolve.data.code || '';
  assert(Boolean(code), 'invite resolve missing code');
  return { ...resolve.data, code };
};

const assertLandingStatus = async (code: string, status: number, expectedText: string): Promise<void> => {
  const response = await request<string>('GET', publicUrl(`/s/${encodeURIComponent(code)}`), undefined, undefined, {
    redirects: 0,
    responseType: 'text',
  });
  assert(response.status === status, `landing ${code} expected ${status} but got ${response.status}`);
  assert(String(response.data).includes(expectedText), `landing ${code} missing ${expectedText}`);
};

const assertRedeemError = async (
  code: string,
  token: string,
  expectedStatus: number,
  expectedError: string
): Promise<void> => {
  const response = await request<RedeemBody>(
    'POST',
    apiUrl(`/share-links/${encodeURIComponent(code)}/redeem`),
    { channel: 'invite_smoke_error', platform: 'iOS' },
    token,
    { redirects: 0, responseType: 'json' }
  );
  assert(response.status === expectedStatus, `redeem ${code} expected ${expectedStatus} but got ${response.status}`);
  assert(
    response.data.error === expectedError,
    `redeem ${code} expected error ${expectedError} but got ${String(response.data.error)}`
  );
};

const main = async (): Promise<void> => {
  console.log('[share-invite-smoke] start', { apiBaseUrl, publicBaseUrl });

  const inviter = await registerUser('invite_smoke_inviter');
  const invitee = await registerUser('invite_smoke_invitee');
  const squadId = await prepareSquad(inviter.userId);
  console.log('[share-invite-smoke] fixture ok', {
    inviterUserId: inviter.userId,
    inviteeUserId: invitee.userId,
    squadId,
  });

  const resolve = await createInviteLink(squadId, inviter.token, { maxUses: 2 });
  const code = resolve.code;
  assert(resolve.maxUses === 2, `invite maxUses expected 2 but got ${String(resolve.maxUses)}`);
  assert(Boolean(resolve.deepLink?.includes('inviteCode=')), 'invite deepLink missing inviteCode');
  console.log('[share-invite-smoke] resolve ok', {
    code,
    shortUrl: resolve.shortUrl,
    expiresAt: resolve.expiresAt,
  });

  const landing = await request<string>('GET', publicUrl(`/s/${encodeURIComponent(code)}`), undefined, undefined, {
    redirects: 0,
    responseType: 'text',
  });
  assert(landing.status === 200, `landing expected 200 but got ${landing.status}`);
  assert(String(landing.data).includes('私密小队邀请'), 'landing missing private invite copy');
  console.log('[share-invite-smoke] landing ok', { status: landing.status });

  const open = await request<string>('GET', publicUrl(`/s/${encodeURIComponent(code)}/open`), undefined, undefined, {
    redirects: 0,
    responseType: 'text',
  });
  assert(open.status >= 300 && open.status < 400, `open expected redirect but got ${open.status}`);
  const location = String(open.headers.location || '');
  assert(location.includes('raver://squad/'), 'open redirect missing squad deep link');
  assert(location.includes(`inviteCode=${code}`), 'open redirect missing inviteCode');
  assert(location.includes(`shareCode=${code}`), 'open redirect missing shareCode');
  console.log('[share-invite-smoke] open redirect ok', { status: open.status, location });

  const redeem = await request<RedeemBody>(
    'POST',
    apiUrl(`/share-links/${encodeURIComponent(code)}/redeem`),
    { channel: 'invite_smoke', platform: 'iOS' },
    invitee.token,
    { redirects: 0, responseType: 'json' }
  );
  assert(redeem.status === 200, `redeem expected 200 but got ${redeem.status}: ${redeem.data.error || ''} ${redeem.data.message || ''}`);
  assert(redeem.data.success === true, 'redeem response missing success=true');
  assert(redeem.data.squadId === squadId, `redeem squadId expected ${squadId} but got ${String(redeem.data.squadId)}`);
  assert(redeem.data.rewardStatus === 'granted', `redeem rewardStatus expected granted but got ${String(redeem.data.rewardStatus)}`);
  console.log('[share-invite-smoke] redeem ok', {
    rewardStatus: redeem.data.rewardStatus,
    rewardReason: redeem.data.rewardReason,
  });

  const selfRedeem = await request<RedeemBody>(
    'POST',
    apiUrl(`/share-links/${encodeURIComponent(code)}/redeem`),
    { channel: 'invite_smoke_self', platform: 'iOS' },
    inviter.token,
    { redirects: 0, responseType: 'json' }
  );
  assert(selfRedeem.status === 400, `self redeem expected 400 but got ${selfRedeem.status}`);
  assert(selfRedeem.data.error === 'self_invite_not_allowed', `self redeem expected self_invite_not_allowed but got ${String(selfRedeem.data.error)}`);
  console.log('[share-invite-smoke] self redeem rejection ok', { status: selfRedeem.status });

  const link = await prisma.shareLink.findUnique({
    where: { code },
    select: { id: true, usedCount: true },
  });
  assert(Boolean(link), 'share link missing after redeem');
  assert(link?.usedCount === 1, `usedCount expected 1 but got ${String(link?.usedCount)}`);

  const events = link
    ? await prisma.shareLinkEvent.findMany({
        where: { linkId: link.id },
        select: { eventType: true },
      })
    : [];
  const eventTypes = new Set(events.map((event) => event.eventType));
  assert(eventTypes.has('create'), 'events missing create');
  assert(eventTypes.has('open'), 'events missing open');
  assert(eventTypes.has('redirect'), 'events missing redirect');
  assert(eventTypes.has('invite_accept'), 'events missing invite_accept');
  assert(eventTypes.has('reward_grant'), 'events missing reward_grant');

  const referral = await prisma.inviteReferral.findFirst({
    where: {
      linkId: link?.id,
      inviteeUserId: invitee.userId,
    },
    select: {
      rewardStatus: true,
      grantedAt: true,
    },
  });
  assert(referral?.rewardStatus === 'granted', `referral rewardStatus expected granted but got ${String(referral?.rewardStatus)}`);
  assert(Boolean(referral?.grantedAt), 'referral missing grantedAt');
  console.log('[share-invite-smoke] event/referral audit ok', {
    usedCount: link?.usedCount,
    eventTypes: Array.from(eventTypes).sort(),
    rewardStatus: referral?.rewardStatus,
  });

  const alreadyMember = await registerUser('invite_smoke_already_member');
  await prisma.squadMember.create({
    data: {
      squadId,
      userId: alreadyMember.userId,
      role: 'member',
      lastReadAt: new Date(),
    },
  });
  const alreadyMemberRedeem = await request<RedeemBody>(
    'POST',
    apiUrl(`/share-links/${encodeURIComponent(code)}/redeem`),
    { channel: 'invite_smoke_already_member', platform: 'iOS' },
    alreadyMember.token,
    { redirects: 0, responseType: 'json' }
  );
  assert(alreadyMemberRedeem.status === 200, `already member redeem expected 200 but got ${alreadyMemberRedeem.status}`);
  assert(alreadyMemberRedeem.data.alreadyMember === true, 'already member redeem missing alreadyMember=true');
  assert(
    alreadyMemberRedeem.data.rewardStatus === 'rejected',
    `already member rewardStatus expected rejected but got ${String(alreadyMemberRedeem.data.rewardStatus)}`
  );
  assert(
    alreadyMemberRedeem.data.rewardReason === 'already_member',
    `already member rewardReason expected already_member but got ${String(alreadyMemberRedeem.data.rewardReason)}`
  );
  console.log('[share-invite-smoke] already member rejection ok');

  const duplicateInviter = await registerUser('invite_smoke_duplicate_inviter');
  const duplicateSquadId = await prepareSquad(duplicateInviter.userId);
  const duplicateCode = (await createInviteLink(duplicateSquadId, duplicateInviter.token, {
    maxUses: 2,
    channel: 'invite_smoke_duplicate',
  })).code;
  const duplicateRedeem = await request<RedeemBody>(
    'POST',
    apiUrl(`/share-links/${encodeURIComponent(duplicateCode)}/redeem`),
    { channel: 'invite_smoke_duplicate', platform: 'iOS' },
    invitee.token,
    { redirects: 0, responseType: 'json' }
  );
  assert(duplicateRedeem.status === 200, `duplicate redeem expected 200 but got ${duplicateRedeem.status}`);
  assert(
    duplicateRedeem.data.rewardStatus === 'rejected',
    `duplicate rewardStatus expected rejected but got ${String(duplicateRedeem.data.rewardStatus)}`
  );
  assert(
    duplicateRedeem.data.rewardReason === 'duplicate_rewarded_invitee',
    `duplicate rewardReason expected duplicate_rewarded_invitee but got ${String(duplicateRedeem.data.rewardReason)}`
  );
  console.log('[share-invite-smoke] duplicate reward rejection ok');

  const revokedCode = (await createInviteLink(squadId, inviter.token, { channel: 'invite_smoke_revoked' })).code;
  await prisma.shareLink.update({
    where: { code: revokedCode },
    data: { status: 'revoked' },
  });
  await assertLandingStatus(revokedCode, 410, '链接已失效');
  await assertRedeemError(revokedCode, invitee.token, 410, 'revoked');
  console.log('[share-invite-smoke] revoked link rejection ok');

  const expiredCode = (await createInviteLink(squadId, inviter.token, { channel: 'invite_smoke_expired' })).code;
  await prisma.shareLink.update({
    where: { code: expiredCode },
    data: { expiresAt: new Date(Date.now() - 60_000) },
  });
  await assertLandingStatus(expiredCode, 410, '邀请已过期');
  await assertRedeemError(expiredCode, invitee.token, 410, 'expired');
  console.log('[share-invite-smoke] expired link rejection ok');

  const exhaustedCode = (await createInviteLink(squadId, inviter.token, {
    maxUses: 1,
    channel: 'invite_smoke_exhausted',
  })).code;
  await prisma.shareLink.update({
    where: { code: exhaustedCode },
    data: { usedCount: 1 },
  });
  await assertLandingStatus(exhaustedCode, 410, '邀请已用完');
  await assertRedeemError(exhaustedCode, invitee.token, 410, 'invite_exhausted');
  console.log('[share-invite-smoke] exhausted link rejection ok');

  console.log('[share-invite-smoke] all checks passed');
};

main()
  .catch((error) => {
    console.error('[share-invite-smoke] failed', error);
    process.exitCode = 1;
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
