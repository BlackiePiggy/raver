import 'dotenv/config';
import { Prisma, PrismaClient } from '@prisma/client';
import { processContentSubmission } from '../services/content-submission-processing.service';
import { createOrUpdateBrandFromSubmission } from '../services/content-submission-brand.service';
import { notificationCenterService } from '../modules/notifications';
import { entityChangeService } from '../modules/entity-change';

const prisma = new PrismaClient();

notificationCenterService.publish = async () => [];
entityChangeService.persistChange = async () => null;

const assert = (condition: boolean, message: string): void => {
  if (!condition) throw new Error(message);
};

const logStep = (step: string, detail?: Record<string, unknown>): void => {
  console.log('[brand-submission-regression]', step, detail || {});
};

const createdUserIds = new Set<string>();
const createdBrandIds = new Set<string>();
const createdSubmissionIds = new Set<string>();
const createdEventIds = new Set<string>();

const withTimeout = async <T>(
  label: string,
  run: () => Promise<T>,
  timeoutMs = 20_000
): Promise<T> => {
  const startedAt = Date.now();
  const timeout = new Promise<never>((_, reject) => {
    setTimeout(() => {
      reject(new Error(`${label} timed out after ${timeoutMs}ms`));
    }, timeoutMs);
  });

  try {
    const result = await Promise.race([run(), timeout]);
    logStep(`${label} finished`, { durationMs: Date.now() - startedAt });
    return result;
  } catch (error) {
    logStep(`${label} failed`, {
      durationMs: Date.now() - startedAt,
      error: error instanceof Error ? error.message : String(error),
    });
    throw error;
  }
};

const createRegressionUser = async (
  suffix: string,
  role: 'user' | 'admin' | 'operator' = 'user'
): Promise<string> => {
  const user = await prisma.user.create({
    data: {
      username: `brand_submission_${role}_${suffix}`,
      email: `brand_submission_${role}_${suffix}@example.com`,
      passwordHash: 'regression-only',
      displayName: `Brand Submission ${role} ${suffix}`,
      displayNameNormalized: `brand submission ${role} ${suffix}`,
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

const createSeedEvent = async (suffix: string) => {
  const event = await prisma.event.create({
    data: {
      name: `Brand Regression Event ${suffix}`,
      slug: `brand-regression-event-${suffix}`,
      coverImageUrl: 'https://example.com/brand-regression-event.jpg',
      city: 'Macau',
      country: 'China',
      venueName: 'Regression Venue',
      venueAddress: 'Regression Address',
      startDate: new Date('2026-08-01T12:00:00.000Z'),
      endDate: new Date('2026-08-02T12:00:00.000Z'),
      isCancelled: false,
      visibility: 'visible',
      organizerName: 'Regression Organizer',
    } as Prisma.EventCreateInput,
    select: { id: true },
  });
  createdEventIds.add(event.id);
  return event;
};

const createSeedBrand = async (suffix: string, ownerUserId: string) => {
  const brand = await prisma.wikiFestival.create({
    data: {
      id: `brand-regression-${suffix}`,
      name: `Regression Brand ${suffix}`,
      nameI18n: {
        zh: `回归主办方 ${suffix}`,
        en: `Regression Brand ${suffix}`,
        ja: '',
        enFull: '',
      } as Prisma.InputJsonValue,
      abbreviation: 'RB',
      aliases: ['Regression Brand Alias'],
      country: 'China',
      countryI18n: {
        zh: '中国',
        en: 'China',
        ja: '',
        enFull: '',
      } as Prisma.InputJsonValue,
      city: 'Shanghai',
      cityI18n: {
        zh: '上海',
        en: 'Shanghai',
        ja: '',
        enFull: '',
      } as Prisma.InputJsonValue,
      foundedYear: '2014',
      frequency: 'Annual',
      frequencyI18n: {
        zh: '每年',
        en: 'Annual',
        ja: '',
        enFull: '',
      } as Prisma.InputJsonValue,
      tagline: 'Original tagline',
      introduction: 'Original introduction',
      descriptionI18n: {
        zh: '原始介绍',
        en: 'Original introduction',
        ja: '',
        enFull: '',
      } as Prisma.InputJsonValue,
      officialWebsite: 'https://example.com/original-brand',
      facebookUrl: 'https://facebook.com/original-brand',
      instagramUrl: 'https://instagram.com/original-brand',
      twitterUrl: 'https://x.com/original-brand',
      youtubeUrl: 'https://youtube.com/original-brand',
      tiktokUrl: 'https://tiktok.com/@original-brand',
      avatarUrl: 'https://example.com/original-brand-avatar.jpg',
      backgroundUrl: 'https://example.com/original-brand-background.jpg',
      links: [
        { title: 'Original Ticket', icon: 'ticket', url: 'https://tickets.example.com/original-brand' },
      ] as Prisma.InputJsonValue,
      contributors: {
        create: {
          userId: ownerUserId,
        },
      },
    } as Prisma.WikiFestivalCreateInput,
    select: {
      id: true,
      name: true,
      revision: true,
    },
  });
  createdBrandIds.add(brand.id);
  return brand;
};

const createSubmissionWithVersion = async (input: {
  submitterId: string;
  title: string;
  payload: Prisma.InputJsonObject;
}) => {
  const submission = await prisma.contentSubmission.create({
    data: {
      submitterId: input.submitterId,
      entityType: 'brand',
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

const buildCreatePayload = (
  suffix: string,
  eventId: string
): Prisma.InputJsonObject => ({
  name: `Regression Brand Create ${suffix}`,
  nameI18n: {
    zh: `创建主办方 ${suffix}`,
    en: `Regression Brand Create ${suffix}`,
    ja: `回帰ブランド作成 ${suffix}`,
    enFull: `Regression Brand Create ${suffix} Full`,
  },
  abbreviation: 'RBC',
  aliases: ['Regression Create Alias 1', 'Regression Create Alias 2'],
  country: 'Japan',
  countryI18n: {
    zh: '日本',
    en: 'Japan',
    ja: '日本',
    enFull: 'Japan',
  },
  city: 'Tokyo',
  cityI18n: {
    zh: '东京',
    en: 'Tokyo',
    ja: '東京',
    enFull: 'Tokyo',
  },
  foundedYear: '2018',
  frequency: 'Quarterly',
  frequencyI18n: {
    zh: '每季度',
    en: 'Quarterly',
    ja: '四半期ごと',
    enFull: 'Quarterly',
  },
  tagline: `Create tagline ${suffix}`,
  introduction: `Create introduction ${suffix}`,
  descriptionI18n: {
    zh: `创建介绍 ${suffix}`,
    en: `Create intro ${suffix}`,
    ja: `作成紹介 ${suffix}`,
    enFull: `Create intro full ${suffix}`,
  },
  officialWebsite: `https://example.com/brand-create-${suffix}`,
  facebookUrl: `https://facebook.com/brand-create-${suffix}`,
  instagramUrl: `https://instagram.com/brand-create-${suffix}`,
  twitterUrl: `https://x.com/brand-create-${suffix}`,
  youtubeUrl: `https://youtube.com/brand-create-${suffix}`,
  tiktokUrl: `https://tiktok.com/@brand-create-${suffix}`,
  avatarUrl: `https://example.com/brand-create-avatar-${suffix}.jpg`,
  backgroundUrl: `https://example.com/brand-create-background-${suffix}.jpg`,
  proofImageUrl: `https://example.com/brand-create-proof-${suffix}.jpg`,
  imageAssets: [
    {
      url: `https://example.com/brand-create-avatar-${suffix}.jpg`,
      type: 'avatar',
      label: 'Avatar',
      sort: 0,
      order: 1,
      source: 'brand-submission-regression',
      fileName: `avatar-${suffix}.jpg`,
    },
    {
      url: `https://example.com/brand-create-background-${suffix}.jpg`,
      type: 'background',
      label: 'Background',
      sort: 1,
      order: 2,
      source: 'brand-submission-regression',
      fileName: `background-${suffix}.jpg`,
    },
    {
      url: `https://example.com/brand-create-proof-${suffix}.jpg`,
      type: 'proof',
      label: 'Proof',
      sort: 2,
      order: 3,
      source: 'brand-submission-regression',
      fileName: `proof-${suffix}.jpg`,
    },
  ],
  links: [
    { title: 'Ticket', icon: 'ticket', url: `https://tickets.example.com/brand-create-${suffix}` },
    { title: 'Discord', icon: 'message', url: `https://discord.gg/brand-create-${suffix}` },
  ],
  rightsConfirmed: true,
  identityConfirmed: true,
  boundEventIds: [eventId],
});

const buildEditPayload = (
  brand: {
    id: string;
    revision: number;
  },
  suffix: string,
  eventId: string
): Prisma.InputJsonObject => ({
  targetBrandId: brand.id,
  baseBrandRevision: brand.revision,
  name: `Regression Brand ${suffix} Updated`,
  nameI18n: {
    zh: `更新主办方 ${suffix}`,
    en: `Regression Brand ${suffix} Updated`,
    ja: `回帰ブランド更新 ${suffix}`,
    enFull: `Regression Brand ${suffix} Updated Full`,
  },
  abbreviation: 'RBU',
  aliases: ['Regression Brand Alias Updated', `Regression Brand ${suffix}`],
  country: 'Singapore',
  countryI18n: {
    zh: '新加坡',
    en: 'Singapore',
    ja: 'シンガポール',
    enFull: 'Singapore',
  },
  city: 'Singapore',
  cityI18n: {
    zh: '新加坡',
    en: 'Singapore',
    ja: 'シンガポール',
    enFull: 'Singapore',
  },
  foundedYear: '2020',
  frequency: 'Monthly',
  frequencyI18n: {
    zh: '每月',
    en: 'Monthly',
    ja: '毎月',
    enFull: 'Monthly',
  },
  tagline: `Updated tagline ${suffix}`,
  introduction: `Updated introduction ${suffix}`,
  descriptionI18n: {
    zh: `更新介绍 ${suffix}`,
    en: `Updated intro ${suffix}`,
    ja: `更新紹介 ${suffix}`,
    enFull: `Updated intro full ${suffix}`,
  },
  officialWebsite: `https://example.com/brand-updated-${suffix}`,
  facebookUrl: `https://facebook.com/brand-updated-${suffix}`,
  instagramUrl: `https://instagram.com/brand-updated-${suffix}`,
  twitterUrl: `https://x.com/brand-updated-${suffix}`,
  youtubeUrl: `https://youtube.com/brand-updated-${suffix}`,
  tiktokUrl: `https://tiktok.com/@brand-updated-${suffix}`,
  avatarUrl: `https://example.com/brand-updated-avatar-${suffix}.jpg`,
  backgroundUrl: `https://example.com/brand-updated-background-${suffix}.jpg`,
  proofImageUrl: `https://example.com/brand-updated-proof-${suffix}.jpg`,
  imageAssets: [
    {
      url: `https://example.com/brand-updated-avatar-${suffix}.jpg`,
      type: 'avatar',
      label: 'Avatar',
      sort: 0,
      order: 1,
      source: 'brand-submission-regression',
      fileName: `avatar-updated-${suffix}.jpg`,
    },
    {
      url: `https://example.com/brand-updated-background-${suffix}.jpg`,
      type: 'background',
      label: 'Background',
      sort: 1,
      order: 2,
      source: 'brand-submission-regression',
      fileName: `background-updated-${suffix}.jpg`,
    },
    {
      url: `https://example.com/brand-updated-proof-${suffix}.jpg`,
      type: 'proof',
      label: 'Proof',
      sort: 2,
      order: 3,
      source: 'brand-submission-regression',
      fileName: `proof-updated-${suffix}.jpg`,
    },
  ],
  links: [
    { title: 'Ticket', icon: 'ticket', url: `https://tickets.example.com/brand-updated-${suffix}` },
    { title: 'Discord', icon: 'message', url: `https://discord.gg/brand-updated-${suffix}` },
    { title: 'Media', icon: 'link', url: `https://media.example.com/brand-updated-${suffix}` },
  ],
  rightsConfirmed: true,
  identityConfirmed: true,
  boundEventIds: [eventId],
});

const assertBrandMatchesPayload = async (
  brandId: string,
  payload: Prisma.InputJsonObject,
  expectedContributorUserId: string
): Promise<void> => {
  const brand = await prisma.wikiFestival.findUniqueOrThrow({
    where: { id: brandId },
    include: {
      contributors: {
        select: { userId: true },
      },
      events: {
        select: { id: true },
      },
    },
  });

  const nameI18n = brand.nameI18n as Record<string, unknown> | null;
  const countryI18n = brand.countryI18n as Record<string, unknown> | null;
  const cityI18n = brand.cityI18n as Record<string, unknown> | null;
  const frequencyI18n = brand.frequencyI18n as Record<string, unknown> | null;
  const descriptionI18n = brand.descriptionI18n as Record<string, unknown> | null;
  const links = Array.isArray(brand.links) ? (brand.links as Array<Record<string, unknown>>) : [];
  const boundEventIds = Array.isArray(payload.boundEventIds) ? (payload.boundEventIds as string[]) : [];
  const expectedLinks = Array.isArray(payload.links) ? (payload.links as Array<Record<string, unknown>>) : [];

  assert(brand.name === payload.name, 'brand name mismatch');
  assert((nameI18n?.zh as string | undefined) === (payload.nameI18n as Record<string, unknown>).zh, 'brand nameI18n.zh mismatch');
  assert(brand.abbreviation === payload.abbreviation, 'brand abbreviation mismatch');
  assert(JSON.stringify(brand.aliases) === JSON.stringify(payload.aliases), 'brand aliases mismatch');
  assert(brand.country === payload.country, 'brand country mismatch');
  assert((countryI18n?.zh as string | undefined) === (payload.countryI18n as Record<string, unknown>).zh, 'brand countryI18n.zh mismatch');
  assert(brand.city === payload.city, 'brand city mismatch');
  assert((cityI18n?.zh as string | undefined) === (payload.cityI18n as Record<string, unknown>).zh, 'brand cityI18n.zh mismatch');
  assert(brand.foundedYear === payload.foundedYear, 'brand foundedYear mismatch');
  assert(brand.frequency === payload.frequency, 'brand frequency mismatch');
  assert((frequencyI18n?.zh as string | undefined) === (payload.frequencyI18n as Record<string, unknown>).zh, 'brand frequencyI18n.zh mismatch');
  assert(brand.tagline === payload.tagline, 'brand tagline mismatch');
  assert(brand.introduction === payload.introduction, 'brand introduction mismatch');
  assert((descriptionI18n?.zh as string | undefined) === (payload.descriptionI18n as Record<string, unknown>).zh, 'brand descriptionI18n.zh mismatch');
  assert(brand.officialWebsite === payload.officialWebsite, 'brand officialWebsite mismatch');
  assert(brand.facebookUrl === payload.facebookUrl, 'brand facebookUrl mismatch');
  assert(brand.instagramUrl === payload.instagramUrl, 'brand instagramUrl mismatch');
  assert(brand.twitterUrl === payload.twitterUrl, 'brand twitterUrl mismatch');
  assert(brand.youtubeUrl === payload.youtubeUrl, 'brand youtubeUrl mismatch');
  assert(brand.tiktokUrl === payload.tiktokUrl, 'brand tiktokUrl mismatch');
  assert(brand.avatarUrl === payload.avatarUrl, 'brand avatarUrl mismatch');
  assert(brand.backgroundUrl === payload.backgroundUrl, 'brand backgroundUrl mismatch');
  assert(links.some((item) => item.url === (payload.officialWebsite as string)), 'brand links should contain officialWebsite');
  for (const expectedLink of expectedLinks) {
    assert(links.some((item) => item.url === expectedLink.url), `brand links missing ${String(expectedLink.url)}`);
  }
  for (const expectedEventId of boundEventIds) {
    assert(brand.events.some((event) => event.id === expectedEventId), 'brand event binding mismatch');
  }
  assert(
    brand.contributors.some((contributor) => contributor.userId === expectedContributorUserId),
    'expected submitter to remain or become a brand contributor'
  );
};

const runManualApprovalCreateRegression = async (): Promise<void> => {
  const suffix = `manual_create_${Date.now().toString(36)}`;
  logStep('manual create start', { suffix });
  const submitterId = await createRegressionUser(suffix, 'user');
  const reviewerId = await createRegressionUser(`${suffix}_reviewer`, 'admin');
  const event = await createSeedEvent(suffix);
  const payload = buildCreatePayload(suffix, event.id);

  const submission = await withTimeout('manual create submission insert', () => createSubmissionWithVersion({
    submitterId,
    title: String(payload.name),
    payload,
  }));

  const processResult = await withTimeout('manual create processing', () => processContentSubmission(submission.id, {
    db: prisma,
    markFailedOnError: false,
  }));
  assert(processResult.status === 'succeeded', 'manual brand create processing should succeed');
  assert(processResult.submissionStatus === 'reviewing', 'manual brand create should stop at reviewing');
  assert(processResult.autoApproved === false, 'manual brand create should not auto approve');

  const reviewing = await withTimeout('manual create reload reviewing submission', () => prisma.contentSubmission.findUniqueOrThrow({
    where: { id: submission.id },
    select: {
      status: true,
      payload: true,
    },
  }));
  assert(reviewing.status === 'reviewing', 'brand create submission should be reviewing after processing');
  const approvedBrand = await withTimeout('manual create apply brand', () =>
    createOrUpdateBrandFromSubmission(prisma, reviewing.payload as Prisma.JsonObject, submitterId, {
      submissionId: submission.id,
    })
  );
  createdBrandIds.add(approvedBrand.id);

  const approvedSubmission = await withTimeout('manual create finalize submission', () => prisma.contentSubmission.update({
    where: { id: submission.id },
    data: {
      status: 'approved',
      reviewedAt: new Date(),
      reviewedBy: reviewerId,
      createdEntityId: approvedBrand.id,
      reviewReason: null,
    },
    select: {
      status: true,
      createdEntityId: true,
    },
  }));
  assert(approvedSubmission.status === 'approved', 'manual brand create did not persist approved status');
  assert(approvedSubmission.createdEntityId === approvedBrand.id, 'manual brand create stored wrong createdEntityId');

  await withTimeout('manual create assertions', () => assertBrandMatchesPayload(approvedBrand.id, payload, submitterId));
  logStep('manual create passed', { brandId: approvedBrand.id, submissionId: submission.id });
};

const runManualApprovalEditRegression = async (): Promise<void> => {
  const suffix = `manual_edit_${Date.now().toString(36)}`;
  logStep('manual edit start', { suffix });
  const submitterId = await createRegressionUser(suffix, 'user');
  const reviewerId = await createRegressionUser(`${suffix}_reviewer`, 'admin');
  const event = await createSeedEvent(suffix);
  const brand = await createSeedBrand(suffix, submitterId);
  const payload = buildEditPayload(brand, suffix, event.id);

  const submission = await withTimeout('manual edit submission insert', () => createSubmissionWithVersion({
    submitterId,
    title: String(payload.name),
    payload,
  }));

  const processResult = await withTimeout('manual edit processing', () => processContentSubmission(submission.id, {
    db: prisma,
    markFailedOnError: false,
  }));
  assert(processResult.status === 'succeeded', 'manual brand edit processing should succeed');
  assert(processResult.submissionStatus === 'reviewing', 'manual brand edit should stop at reviewing');
  assert(processResult.autoApproved === false, 'manual brand edit should not auto approve');

  const reviewing = await withTimeout('manual edit reload reviewing submission', () => prisma.contentSubmission.findUniqueOrThrow({
    where: { id: submission.id },
    select: {
      status: true,
      payload: true,
    },
  }));
  assert(reviewing.status === 'reviewing', 'brand edit submission should be reviewing after processing');
  const approvedBrand = await withTimeout('manual edit apply brand', () =>
    createOrUpdateBrandFromSubmission(prisma, reviewing.payload as Prisma.JsonObject, submitterId, {
      submissionId: submission.id,
    })
  );

  const approvedSubmission = await withTimeout('manual edit finalize submission', () => prisma.contentSubmission.update({
    where: { id: submission.id },
    data: {
      status: 'approved',
      reviewedAt: new Date(),
      reviewedBy: reviewerId,
      createdEntityId: approvedBrand.id,
      reviewReason: null,
    },
    select: {
      status: true,
      createdEntityId: true,
    },
  }));
  assert(approvedSubmission.status === 'approved', 'manual brand edit did not persist approved status');
  assert(approvedSubmission.createdEntityId === brand.id, 'manual brand edit stored wrong createdEntityId');

  await withTimeout('manual edit assertions', () => assertBrandMatchesPayload(brand.id, payload, submitterId));
  logStep('manual edit passed', { brandId: brand.id, submissionId: submission.id });
};

const runAutoApprovalEditRegression = async (): Promise<void> => {
  const suffix = `auto_edit_${Date.now().toString(36)}`;
  logStep('auto edit start', { suffix });
  const submitterId = await createRegressionUser(suffix, 'admin');
  const event = await createSeedEvent(suffix);
  const brand = await createSeedBrand(suffix, submitterId);
  const payload = buildEditPayload(brand, suffix, event.id);

  const submission = await withTimeout('auto edit submission insert', () => createSubmissionWithVersion({
    submitterId,
    title: String(payload.name),
    payload,
  }));

  const processResult = await withTimeout('auto edit processing', () => processContentSubmission(submission.id, {
    db: prisma,
    markFailedOnError: false,
  }));
  assert(processResult.status === 'succeeded', 'auto brand edit processing should succeed');
  assert(processResult.submissionStatus === 'approved', 'admin brand edit should auto approve');
  assert(processResult.autoApproved === true, 'admin brand edit should be marked auto approved');
  assert(processResult.createdEntityId === brand.id, 'auto brand edit should point createdEntityId to original brand');

  const approved = await withTimeout('auto edit reload approved submission', () => prisma.contentSubmission.findUniqueOrThrow({
    where: { id: submission.id },
    select: {
      status: true,
      createdEntityId: true,
      reviewedBy: true,
    },
  }));
  assert(approved.status === 'approved', 'auto brand edit did not persist approved status');
  assert(approved.createdEntityId === brand.id, 'auto brand edit stored wrong createdEntityId');
  assert(approved.reviewedBy === submitterId, 'auto brand edit should set reviewedBy to submitter');

  await withTimeout('auto edit assertions', () => assertBrandMatchesPayload(brand.id, payload, submitterId));
  logStep('auto edit passed', { brandId: brand.id, submissionId: submission.id });
};

const cleanup = async (): Promise<void> => {
  if (createdSubmissionIds.size > 0) {
    await prisma.contentSubmission.deleteMany({
      where: {
        id: { in: Array.from(createdSubmissionIds) },
      },
    });
  }
  if (createdEventIds.size > 0) {
    await prisma.event.updateMany({
      where: {
        id: { in: Array.from(createdEventIds) },
      },
      data: {
        wikiFestivalId: null,
      },
    });
    await prisma.event.deleteMany({
      where: {
        id: { in: Array.from(createdEventIds) },
      },
    });
  }
  if (createdBrandIds.size > 0) {
    await prisma.wikiFestival.deleteMany({
      where: {
        id: { in: Array.from(createdBrandIds) },
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
    await runManualApprovalCreateRegression();
    await runManualApprovalEditRegression();
    await runAutoApprovalEditRegression();
    logStep('all checks passed', {
      submissions: createdSubmissionIds.size,
      brands: createdBrandIds.size,
      events: createdEventIds.size,
      users: createdUserIds.size,
    });
  } finally {
    if (process.env.BRAND_SUBMISSION_REGRESSION_KEEP_DATA !== '1') {
      await cleanup();
    }
    await prisma.$disconnect();
  }
}

void main().catch((error) => {
  console.error('[brand-submission-regression] failed:', error);
  process.exit(1);
});
