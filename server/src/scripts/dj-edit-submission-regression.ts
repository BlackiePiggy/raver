import 'dotenv/config';
import { Prisma, PrismaClient } from '@prisma/client';
import { processContentSubmission } from '../services/content-submission-processing.service';
import { createOrUpdateDJFromSubmission } from '../services/content-submission-dj.service';

const prisma = new PrismaClient();

const assert = (condition: boolean, message: string): void => {
  if (!condition) throw new Error(message);
};

const logStep = (step: string, detail?: Record<string, unknown>): void => {
  console.log('[dj-edit-submission-regression]', step, detail || {});
};

const createdUserIds = new Set<string>();
const createdDJIds = new Set<string>();
const createdSubmissionIds = new Set<string>();

const createRegressionUser = async (
  suffix: string,
  role: 'user' | 'admin' | 'operator' = 'user'
): Promise<string> => {
  const user = await prisma.user.create({
    data: {
      username: `dj_edit_submission_${role}_${suffix}`,
      email: `dj_edit_submission_${role}_${suffix}@example.com`,
      passwordHash: 'regression-only',
      displayName: `DJ Edit Submission ${role} ${suffix}`,
      displayNameNormalized: `dj edit submission ${role} ${suffix}`,
      role,
      isVerified: true,
      regionCode: 'US',
      birthYear: 1990,
      ageBand: 'adult',
      ageDeclaredAt: new Date(),
    },
    select: { id: true },
  });
  createdUserIds.add(user.id);
  return user.id;
};

const createSeedDJ = async (suffix: string, ownerUserId: string) => {
  const dj = await prisma.dJ.create({
    data: {
      name: `Regression DJ ${suffix}`,
      slug: `regression-dj-${suffix}`,
      aliases: ['Regression Alias'],
      genres: ['House'],
      bio: 'Original regression bio',
      avatarUrl: 'https://example.com/regression-dj-avatar.jpg',
      avatarSourceUrl: 'https://example.com/regression-dj-avatar.jpg',
      country: 'China',
      spotifyUrl: 'https://open.spotify.com/artist/regression-original',
      soundcloudUrl: 'https://soundcloud.com/regression-original',
      instagramUrl: 'https://instagram.com/regression-original',
      website: 'https://example.com/regression-original',
      trackCount: 12,
      playlistCount: 3,
      soundCloudFollowers: 500,
      soundCloudFavorites: 120,
      isVerified: true,
      contributors: {
        create: {
          userId: ownerUserId,
        },
      },
    } as Prisma.DJCreateInput,
    select: {
      id: true,
      name: true,
      slug: true,
      avatarUrl: true,
      soundcloudUrl: true,
      updatedAt: true,
    },
  });
  createdDJIds.add(dj.id);
  return dj;
};

const buildCreatePayload = (suffix: string): Prisma.InputJsonObject =>
  ({
    name: `Regression DJ Create ${suffix}`,
    nameI18n: {
      zh: `创建 DJ ${suffix}`,
      en: `Regression DJ Create ${suffix}`,
      ja: `回帰DJ作成 ${suffix}`,
      enFull: `Regression DJ Create ${suffix} Full`,
    },
    aliases: ['Regression Create Alias 1', 'Regression Create Alias 2'],
    genres: ['House', 'Trance'],
    bio: `Regression create bio ${suffix}`,
    bioI18n: {
      zh: `创建简介 ${suffix}`,
      en: `Regression create bio ${suffix}`,
      ja: `回帰DJ作成紹介 ${suffix}`,
      enFull: `Regression create bio full ${suffix}`,
    },
    country: 'Germany',
    countryI18n: {
      zh: '德国',
      en: 'Germany',
      ja: 'ドイツ',
      enFull: 'Germany',
    },
    avatarUrl: `https://example.com/regression-dj-create-avatar-${suffix}.jpg`,
    bannerUrl: `https://example.com/regression-dj-create-banner-${suffix}.jpg`,
    proofImageUrl: `https://example.com/regression-dj-create-proof-${suffix}.jpg`,
    spotifyId: `spotify-create-${suffix}`,
    spotifyUrl: `https://open.spotify.com/artist/regression-create-${suffix}`,
    spotifyFollowers: 4096,
    appleMusicId: `apple-create-${suffix}`,
    instagramUrl: `https://instagram.com/regression-create-${suffix}`,
    facebookUrl: `https://facebook.com/regression-create-${suffix}`,
    soundcloudUrl: `https://soundcloud.com/regression-create-${suffix}`,
    soundcloudId: `soundcloud-create-${suffix}`,
    twitterUrl: `https://x.com/regression-create-${suffix}`,
    youtubeUrl: `https://youtube.com/regression-create-${suffix}`,
    neteaseUrl: `https://music.163.com/artist?id=${suffix}`,
    qqMusicUrl: `https://y.qq.com/n/ryqq/singer/${suffix}`,
    website: `https://example.com/regression-create-${suffix}`,
    otherPlatformUrl: `https://linktr.ee/regression-create-${suffix}`,
    trackCount: 31,
    playlistCount: 9,
    soundCloudFollowers: 888,
    soundCloudFavorites: 222,
    isVerified: true,
  });

const createSubmissionWithVersion = async (input: {
  submitterId: string;
  title: string;
  payload: Prisma.InputJsonObject;
}) => {
  const submission = await prisma.contentSubmission.create({
    data: {
      submitterId: input.submitterId,
      entityType: 'dj',
      status: 'processing',
      title: input.title,
      payload: input.payload,
    },
    select: {
      id: true,
      payload: true,
      status: true,
      title: true,
      submitterId: true,
    },
  });

  await prisma.contentSubmissionVersion.create({
    data: {
      submissionId: submission.id,
      version: 1,
      title: input.title,
      payload: input.payload,
      submittedBy: input.submitterId,
      changeNote: 'Regression initial submission',
    },
  });

  createdSubmissionIds.add(submission.id);
  return submission;
};

const buildEditPayload = (
  dj: {
    id: string;
    avatarUrl: string | null;
    soundcloudUrl: string | null;
  },
  suffix: string
): Prisma.InputJsonObject =>
  ({
    targetDJId: dj.id,
    name: `Regression DJ ${suffix} Updated`,
    aliases: ['Regression Alias Updated', `Regression DJ ${suffix}`],
    genres: ['House', 'Techno'],
    bio: `Regression bio updated ${suffix}`,
    country: 'Japan',
    avatarUrl: dj.avatarUrl || 'https://example.com/regression-dj-avatar-updated.jpg',
    bannerUrl: `https://example.com/regression-dj-banner-${suffix}.jpg`,
    spotifyUrl: `https://open.spotify.com/artist/regression-${suffix}`,
    soundcloudUrl: dj.soundcloudUrl || `https://soundcloud.com/regression-${suffix}`,
    instagramUrl: `https://instagram.com/regression-${suffix}`,
    website: `https://example.com/regression-${suffix}`,
    trackCount: 24,
    playlistCount: 8,
    soundCloudFollowers: 2048,
    soundCloudFavorites: 512,
  });

const assertDJUpdated = async (djId: string, suffix: string, expectedContributorUserId: string): Promise<void> => {
  const dj = await prisma.dJ.findUniqueOrThrow({
    where: { id: djId },
    select: {
      id: true,
      name: true,
      aliases: true,
      genres: true,
      bio: true,
      country: true,
      bannerUrl: true,
      spotifyUrl: true,
      website: true,
      trackCount: true,
      playlistCount: true,
      soundCloudFollowers: true,
      soundCloudFavorites: true,
      contributors: {
        select: {
          userId: true,
        },
      },
    },
  });

  assert(dj.name === `Regression DJ ${suffix} Updated`, 'DJ name was not updated in place');
  assert(dj.aliases.includes('Regression Alias Updated'), 'DJ aliases were not updated');
  assert(dj.genres.includes('Techno'), 'DJ genres were not updated');
  assert(dj.bio === `Regression bio updated ${suffix}`, 'DJ bio was not updated');
  assert(dj.country === 'Japan', 'DJ country was not updated');
  assert(dj.bannerUrl === `https://example.com/regression-dj-banner-${suffix}.jpg`, 'DJ background image was not updated');
  assert(dj.spotifyUrl === `https://open.spotify.com/artist/regression-${suffix}`, 'DJ Spotify URL was not updated');
  assert(dj.website === `https://example.com/regression-${suffix}`, 'DJ website was not updated');
  assert(dj.trackCount === 24, 'DJ trackCount was not updated');
  assert(dj.playlistCount === 8, 'DJ playlistCount was not updated');
  assert(dj.soundCloudFollowers === 2048, 'DJ soundCloudFollowers was not updated');
  assert(dj.soundCloudFavorites === 512, 'DJ soundCloudFavorites was not updated');
  assert(
    dj.contributors.some((contributor: { userId: string }) => contributor.userId === expectedContributorUserId),
    'expected submitter to remain or become a DJ contributor'
  );
};

const runManualApprovalRegression = async (): Promise<void> => {
  const suffix = `manual_${Date.now().toString(36)}`;
  const submitterId = await createRegressionUser(suffix, 'user');
  const reviewerId = await createRegressionUser(`${suffix}_reviewer`, 'admin');
  const dj = await createSeedDJ(suffix, submitterId);
  const payload = buildEditPayload(dj, suffix);

  logStep('manual approval submission created', { suffix, djId: dj.id });
  const submission = await createSubmissionWithVersion({
    submitterId,
    title: `Regression DJ ${suffix} Updated`,
    payload,
  });

  const processResult = await processContentSubmission(submission.id, {
    db: prisma,
    markFailedOnError: false,
  });
  assert(processResult.status === 'succeeded', 'manual approval processing should succeed');
  assert(processResult.submissionStatus === 'reviewing', 'manual approval should stop at reviewing');
  assert(processResult.autoApproved === false, 'manual approval should not auto approve');

  const reviewing = await prisma.contentSubmission.findUniqueOrThrow({
    where: { id: submission.id },
    select: {
      status: true,
      payload: true,
    },
  });
  assert(reviewing.status === 'reviewing', 'submission status should be reviewing after processing');
  const reviewingPayload = reviewing.payload as Prisma.JsonObject;

  const approvedDJ = await createOrUpdateDJFromSubmission(prisma, reviewingPayload, submitterId);
  assert(approvedDJ.id === dj.id, 'manual approval created a duplicate DJ instead of updating original');

  const approvedSubmission = await prisma.contentSubmission.update({
    where: { id: submission.id },
    data: {
      status: 'approved',
      reviewedAt: new Date(),
      reviewedBy: reviewerId,
      createdEntityId: approvedDJ.id,
      reviewReason: null,
    },
    select: {
      status: true,
      createdEntityId: true,
    },
  });
  assert(approvedSubmission.status === 'approved', 'manual approval did not persist approved status');
  assert(approvedSubmission.createdEntityId === dj.id, 'manual approval stored wrong createdEntityId');

  await assertDJUpdated(dj.id, suffix, submitterId);
  const djCount = await prisma.dJ.count({
    where: {
      OR: [
        { id: dj.id },
        { name: `Regression DJ ${suffix} Updated` },
      ],
    },
  });
  assert(djCount === 1, 'manual approval path created duplicate DJ rows');
};

const assertDJCreated = async (
  createdEntityId: string,
  suffix: string,
  expectedContributorUserId: string
): Promise<void> => {
  const dj = await prisma.dJ.findUniqueOrThrow({
    where: { id: createdEntityId },
    select: {
      id: true,
      name: true,
      nameI18n: true,
      aliases: true,
      genres: true,
      bio: true,
      bioI18n: true,
      avatarUrl: true,
      avatarSourceUrl: true,
      bannerUrl: true,
      country: true,
      countryI18n: true,
      spotifyId: true,
      spotifyUrl: true,
      spotifyFollowers: true,
      appleMusicId: true,
      instagramUrl: true,
      facebookUrl: true,
      soundcloudUrl: true,
      soundcloudId: true,
      twitterUrl: true,
      youtubeUrl: true,
      neteaseUrl: true,
      qqMusicUrl: true,
      website: true,
      trackCount: true,
      playlistCount: true,
      soundCloudFollowers: true,
      soundCloudFavorites: true,
      isVerified: true,
      contributors: {
        select: {
          userId: true,
        },
      },
    },
  });

  const nameI18n = dj.nameI18n as Record<string, unknown> | null;
  const bioI18n = dj.bioI18n as Record<string, unknown> | null;
  const countryI18n = dj.countryI18n as Record<string, unknown> | null;

  assert(dj.name === `Regression DJ Create ${suffix}`, 'DJ create name mismatch');
  assert((nameI18n?.zh as string | undefined) === `创建 DJ ${suffix}`, 'DJ create nameI18n.zh mismatch');
  assert(dj.aliases.includes('Regression Create Alias 1'), 'DJ create aliases mismatch');
  assert(dj.genres.includes('Trance'), 'DJ create genres mismatch');
  assert(dj.bio === `Regression create bio ${suffix}`, 'DJ create bio mismatch');
  assert((bioI18n?.zh as string | undefined) === `创建简介 ${suffix}`, 'DJ create bioI18n.zh mismatch');
  assert(dj.avatarUrl === `https://example.com/regression-dj-create-avatar-${suffix}.jpg`, 'DJ create avatarUrl mismatch');
  assert(dj.avatarSourceUrl === `https://example.com/regression-dj-create-avatar-${suffix}.jpg`, 'DJ create avatarSourceUrl mismatch');
  assert(dj.bannerUrl === `https://example.com/regression-dj-create-banner-${suffix}.jpg`, 'DJ create bannerUrl mismatch');
  assert(dj.country === 'Germany', 'DJ create country mismatch');
  assert((countryI18n?.zh as string | undefined) === '德国', 'DJ create countryI18n.zh mismatch');
  assert(dj.spotifyId === `spotify-create-${suffix}`, 'DJ create spotifyId mismatch');
  assert(dj.spotifyUrl === `https://open.spotify.com/artist/regression-create-${suffix}`, 'DJ create spotifyUrl mismatch');
  assert(dj.spotifyFollowers === 4096, 'DJ create spotifyFollowers mismatch');
  assert(dj.appleMusicId === `apple-create-${suffix}`, 'DJ create appleMusicId mismatch');
  assert(dj.instagramUrl === `https://instagram.com/regression-create-${suffix}`, 'DJ create instagramUrl mismatch');
  assert(dj.facebookUrl === `https://facebook.com/regression-create-${suffix}`, 'DJ create facebookUrl mismatch');
  assert(dj.soundcloudUrl === `https://soundcloud.com/regression-create-${suffix}`, 'DJ create soundcloudUrl mismatch');
  assert(dj.soundcloudId === `soundcloud-create-${suffix}`, 'DJ create soundcloudId mismatch');
  assert(dj.twitterUrl === `https://x.com/regression-create-${suffix}`, 'DJ create twitterUrl mismatch');
  assert(dj.youtubeUrl === `https://youtube.com/regression-create-${suffix}`, 'DJ create youtubeUrl mismatch');
  assert(dj.neteaseUrl === `https://music.163.com/artist?id=${suffix}`, 'DJ create neteaseUrl mismatch');
  assert(dj.qqMusicUrl === `https://y.qq.com/n/ryqq/singer/${suffix}`, 'DJ create qqMusicUrl mismatch');
  assert(dj.website === `https://example.com/regression-create-${suffix}`, 'DJ create website mismatch');
  assert(dj.trackCount === 31, 'DJ create trackCount mismatch');
  assert(dj.playlistCount === 9, 'DJ create playlistCount mismatch');
  assert(dj.soundCloudFollowers === 888, 'DJ create soundCloudFollowers mismatch');
  assert(dj.soundCloudFavorites === 222, 'DJ create soundCloudFavorites mismatch');
  assert(dj.isVerified === true, 'DJ create isVerified mismatch');
  assert(
    dj.contributors.some((contributor: { userId: string }) => contributor.userId === expectedContributorUserId),
    'expected submitter to become a DJ contributor on create'
  );
};

const runManualCreateRegression = async (): Promise<void> => {
  const suffix = `manual_create_${Date.now().toString(36)}`;
  const submitterId = await createRegressionUser(suffix, 'user');
  const reviewerId = await createRegressionUser(`${suffix}_reviewer`, 'admin');
  const payload = buildCreatePayload(suffix);

  logStep('manual create submission created', { suffix });
  const submission = await createSubmissionWithVersion({
    submitterId,
    title: `Regression DJ Create ${suffix}`,
    payload,
  });

  const processResult = await processContentSubmission(submission.id, {
    db: prisma,
    markFailedOnError: false,
  });
  assert(processResult.status === 'succeeded', 'manual create processing should succeed');
  assert(processResult.submissionStatus === 'reviewing', 'manual create should stop at reviewing');
  assert(processResult.autoApproved === false, 'manual create should not auto approve');

  const reviewing = await prisma.contentSubmission.findUniqueOrThrow({
    where: { id: submission.id },
    select: {
      status: true,
      payload: true,
    },
  });
  assert(reviewing.status === 'reviewing', 'manual create submission should be reviewing after processing');
  const approvedDJ = await createOrUpdateDJFromSubmission(prisma, reviewing.payload as Prisma.JsonObject, submitterId);
  createdDJIds.add(approvedDJ.id);

  const approvedSubmission = await prisma.contentSubmission.update({
    where: { id: submission.id },
    data: {
      status: 'approved',
      reviewedAt: new Date(),
      reviewedBy: reviewerId,
      createdEntityId: approvedDJ.id,
      reviewReason: null,
    },
    select: {
      status: true,
      createdEntityId: true,
    },
  });
  assert(approvedSubmission.status === 'approved', 'manual create did not persist approved status');
  assert(approvedSubmission.createdEntityId === approvedDJ.id, 'manual create stored wrong createdEntityId');

  await assertDJCreated(approvedDJ.id, suffix, submitterId);
};

const runAutoCreateRegression = async (): Promise<void> => {
  const suffix = `auto_create_${Date.now().toString(36)}`;
  const submitterId = await createRegressionUser(suffix, 'admin');
  const payload = buildCreatePayload(suffix);

  logStep('auto create submission created', { suffix });
  const submission = await createSubmissionWithVersion({
    submitterId,
    title: `Regression DJ Create ${suffix}`,
    payload,
  });

  const processResult = await processContentSubmission(submission.id, {
    db: prisma,
    markFailedOnError: false,
  });
  assert(processResult.status === 'succeeded', 'auto create processing should succeed');
  assert(processResult.submissionStatus === 'approved', 'admin DJ create should auto approve');
  assert(processResult.autoApproved === true, 'admin DJ create should be marked auto approved');
  assert(Boolean(processResult.createdEntityId), 'auto create should return createdEntityId');

  const approved = await prisma.contentSubmission.findUniqueOrThrow({
    where: { id: submission.id },
    select: {
      status: true,
      createdEntityId: true,
      reviewedBy: true,
    },
  });
  assert(approved.status === 'approved', 'auto create did not persist approved status');
  assert(Boolean(approved.createdEntityId), 'auto create stored empty createdEntityId');
  assert(approved.reviewedBy === submitterId, 'auto create should set reviewedBy to submitter when no reviewer exists');
  if (!approved.createdEntityId) {
    throw new Error('auto create createdEntityId missing');
  }
  createdDJIds.add(approved.createdEntityId);

  await assertDJCreated(approved.createdEntityId, suffix, submitterId);
};

const runAutoApprovalRegression = async (): Promise<void> => {
  const suffix = `auto_${Date.now().toString(36)}`;
  const submitterId = await createRegressionUser(suffix, 'admin');
  const dj = await createSeedDJ(suffix, submitterId);
  const payload = buildEditPayload(dj, suffix);

  logStep('auto approval submission created', { suffix, djId: dj.id });
  const submission = await createSubmissionWithVersion({
    submitterId,
    title: `Regression DJ ${suffix} Updated`,
    payload,
  });

  const processResult = await processContentSubmission(submission.id, {
    db: prisma,
    markFailedOnError: false,
  });
  assert(processResult.status === 'succeeded', 'auto approval processing should succeed');
  assert(processResult.submissionStatus === 'approved', 'admin DJ edit should auto approve');
  assert(processResult.autoApproved === true, 'admin DJ edit should be marked auto approved');
  assert(processResult.createdEntityId === dj.id, 'auto approval should point createdEntityId to original DJ');

  const approved = await prisma.contentSubmission.findUniqueOrThrow({
    where: { id: submission.id },
    select: {
      status: true,
      createdEntityId: true,
      reviewedBy: true,
    },
  });
  assert(approved.status === 'approved', 'auto approval did not persist approved status');
  assert(approved.createdEntityId === dj.id, 'auto approval stored wrong createdEntityId');
  assert(approved.reviewedBy === submitterId, 'auto approval should set reviewedBy to submitter when no reviewer exists');

  await assertDJUpdated(dj.id, suffix, submitterId);
  const djCount = await prisma.dJ.count({
    where: {
      OR: [
        { id: dj.id },
        { name: `Regression DJ ${suffix} Updated` },
      ],
    },
  });
  assert(djCount === 1, 'auto approval path created duplicate DJ rows');
};

const cleanup = async (): Promise<void> => {
  if (createdSubmissionIds.size > 0) {
    await prisma.contentSubmission.deleteMany({
      where: {
        id: { in: Array.from(createdSubmissionIds) },
      },
    });
  }
  if (createdDJIds.size > 0) {
    await prisma.dJ.deleteMany({
      where: {
        id: { in: Array.from(createdDJIds) },
      },
    });
  }
  if (createdUserIds.size > 0) {
    await prisma.user.deleteMany({
      where: {
        id: { in: Array.from(createdUserIds) },
      },
    });
  }
};

async function main(): Promise<void> {
  try {
    await runManualCreateRegression();
    await runAutoCreateRegression();
    await runManualApprovalRegression();
    await runAutoApprovalRegression();
    logStep('all checks passed', {
      submissions: createdSubmissionIds.size,
      djs: createdDJIds.size,
      users: createdUserIds.size,
    });
  } finally {
    if (process.env.DJ_EDIT_SUBMISSION_REGRESSION_KEEP_DATA !== '1') {
      await cleanup();
    }
    await prisma.$disconnect();
  }
}

main().catch(async (error) => {
  console.error('[dj-edit-submission-regression] failed', error);
  process.exitCode = 1;
});
