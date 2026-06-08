import 'dotenv/config';
import crypto from 'node:crypto';
import { Prisma, PrismaClient } from '@prisma/client';
import { createOrUpdateBrandFromSubmission } from '../services/content-submission-brand.service';
import { entityChangeService } from '../modules/entity-change';
import { notificationCenterService } from '../modules/notifications';

const prisma = new PrismaClient(
  process.env.DIRECT_URL
    ? {
        datasources: {
          db: {
            url: process.env.DIRECT_URL,
          },
        },
      }
    : undefined
);

notificationCenterService.publish = async () => [];
entityChangeService.persistChange = async () => null;

const assert = (condition: boolean, message: string): void => {
  if (!condition) throw new Error(message);
};

const logStep = (step: string, detail?: Record<string, unknown>): void => {
  console.log('[brand-address-reuse-regression]', step, detail || {});
};

const createdUserIds = new Set<string>();
const createdBrandIds = new Set<string>();
const createdEventIds = new Set<string>();

const createRegressionUser = async (suffix: string): Promise<string> => {
  const user = await prisma.user.create({
    data: {
      username: `brand_address_reuse_${suffix}`,
      email: `brand_address_reuse_${suffix}@example.com`,
      passwordHash: 'regression-only',
      displayName: `Brand Address Reuse ${suffix}`,
      displayNameNormalized: `brand address reuse ${suffix}`,
      role: 'admin',
      isVerified: true,
      regionCode: 'CN',
      birthYear: 1990,
      ageBand: 'adult',
      ageDeclaredAt: new Date(),
    },
    select: { id: true },
  });
  createdUserIds.add(user.id);
  return user.id;
};

const createBrandPayload = (suffix: string): Prisma.JsonObject => ({
  name: `Brand Address Reuse ${suffix}`,
  nameI18n: {
    zh: `地址复用主办方 ${suffix}`,
    en: `Brand Address Reuse ${suffix}`,
    ja: '',
    enFull: `Brand Address Reuse ${suffix}`,
  },
  country: 'China',
  countryI18n: {
    zh: '中国',
    en: 'China',
    ja: '',
    enFull: 'China',
  },
  city: 'Shanghai',
  cityI18n: {
    zh: '上海',
    en: 'Shanghai',
    ja: '',
    enFull: 'Shanghai',
  },
  foundedYear: '2026',
  frequency: 'Annual',
  frequencyI18n: {
    zh: '每年',
    en: 'Annual',
    ja: '',
    enFull: 'Annual',
  },
  tagline: `Brand tagline ${suffix}`,
  introduction: `Brand intro ${suffix}`,
  descriptionI18n: {
    zh: `品牌介绍 ${suffix}`,
    en: `Brand intro ${suffix}`,
    ja: '',
    enFull: `Brand intro ${suffix}`,
  },
  manualLocation: {
    detailAddressI18n: {
      zh: '徐汇滨江 88 号',
      en: '88 Xuhui Riverside',
      ja: '',
      enFull: '88 Xuhui Riverside',
    },
  },
  locationPoint: {
    provider: 'mapbox',
    sourceMode: 'manual_search',
    providerPlaceId: `mapbox-place-${suffix}`,
    poiId: `poi-${suffix}`,
    location: {
      lng: 121.4547,
      lat: 31.1786,
    },
    nameI18n: {
      zh: '西岸艺术中心',
      en: 'West Bund Art Center',
      ja: '',
      enFull: '',
    },
    addressI18n: {
      zh: '徐汇滨江 88 号',
      en: '88 Xuhui Riverside',
      ja: '',
      enFull: '',
    },
    formattedAddressI18n: {
      zh: '中国，上海市，徐汇区，徐汇滨江 88 号',
      en: '88 Xuhui Riverside, Xuhui, Shanghai, China',
      ja: '',
      enFull: '',
    },
    manualSetAddressI18n: {
      zh: '西岸艺术中心主入口',
      en: 'West Bund Art Center Main Gate',
      ja: '',
      enFull: '',
    },
    city: 'Shanghai',
    district: 'Xuhui',
    province: 'Shanghai',
    countryCode: 'CN',
    providerMeta: {
      mapbox: {
        placeId: `mapbox-place-${suffix}`,
        featureType: 'poi',
      },
    },
  },
  rightsConfirmed: true,
  identityConfirmed: true,
});

const buildEventCreateDataFromBrand = (input: {
  suffix: string;
  organizerId: string;
  organizerName: string;
  manualLocation: Prisma.JsonValue;
  locationPoint: Prisma.JsonValue;
  userId: string;
}): Prisma.EventUncheckedCreateInput => ({
  organizerId: input.userId,
  wikiFestivalId: input.organizerId,
  name: `Event Address Copy ${input.suffix}`,
  slug: `event-address-copy-${input.suffix}`.toLowerCase(),
  nameI18n: {
    zh: `活动地址复制 ${input.suffix}`,
    en: `Event Address Copy ${input.suffix}`,
    ja: '',
    enFull: `Event Address Copy ${input.suffix}`,
  },
  organizerName: input.organizerName,
  eventType: 'festival',
  city: 'Shanghai',
  cityI18n: {
    zh: '上海',
    en: 'Shanghai',
    ja: '',
    enFull: 'Shanghai',
  },
  country: 'China',
  countryI18n: {
    zh: '中国',
    en: 'China',
    ja: '',
    enFull: 'China',
  },
  manualLocation: input.manualLocation as Prisma.InputJsonValue,
  locationPoint: input.locationPoint as Prisma.InputJsonValue,
  latitude: new Prisma.Decimal('31.17860000'),
  longitude: new Prisma.Decimal('121.45470000'),
  imageAssets: [
    {
      type: 'poster',
      label: 'POSTER',
      url: `https://example.com/event-address-copy-${input.suffix}.jpg`,
    },
  ] as Prisma.InputJsonValue,
  isCancelled: false,
  visibility: 'visible',
  startDate: new Date('2026-10-18T00:00:00.000+08:00'),
  endDate: new Date('2026-10-18T23:59:59.999+08:00'),
  scheduleMode: 'single_day',
  timeZone: 'Asia/Shanghai',
  startTime: '18:00:00',
  endTime: '23:00:00',
  dayRolloverHour: 6,
  isVerified: true,
});

const buildEventEditedAddressPatch = (
  baseLocationPoint: Prisma.JsonValue
): Prisma.EventUncheckedUpdateInput => ({
  manualLocation: {
    detailAddressI18n: {
      zh: '南京西路 1 号',
      en: '1 Nanjing West Road',
      ja: '',
      enFull: '1 Nanjing West Road',
    },
    formattedAddressI18n: {
      zh: '中国 · 上海 · 南京西路 1 号',
      en: 'China · Shanghai · 1 Nanjing West Road',
      ja: '',
      enFull: 'China · Shanghai · 1 Nanjing West Road',
    },
  } as Prisma.InputJsonValue,
  locationPoint: {
    ...(baseLocationPoint as Record<string, unknown>),
    manualSetAddressI18n: {
      zh: '活动独立场地入口',
      en: 'Event-specific gate',
      ja: '',
      enFull: '',
    },
  } as Prisma.InputJsonValue,
  city: 'Shanghai',
  cityI18n: {
    zh: '上海',
    en: 'Shanghai',
    ja: '',
    enFull: 'Shanghai',
  },
  country: 'China',
  countryI18n: {
    zh: '中国',
    en: 'China',
    ja: '',
    enFull: 'China',
  },
  latitude: new Prisma.Decimal('31.23040000'),
  longitude: new Prisma.Decimal('121.47370000'),
  revision: { increment: 1 },
});

const buildBrandUpdatePayload = (input: {
  suffix: string;
  brandId: string;
  brandName: string;
  baseBrandRevision: number;
  baseLocationPoint: Prisma.JsonValue;
}): Prisma.JsonObject => ({
  targetBrandId: input.brandId,
  baseBrandRevision: input.baseBrandRevision,
  name: input.brandName,
  country: 'China',
  countryI18n: {
    zh: '中国',
    en: 'China',
    ja: '',
    enFull: 'China',
  },
  city: 'Shanghai',
  cityI18n: {
    zh: '上海',
    en: 'Shanghai',
    ja: '',
    enFull: 'Shanghai',
  },
  foundedYear: '2026',
  frequency: 'Annual',
  frequencyI18n: {
    zh: '每年',
    en: 'Annual',
    ja: '',
    enFull: 'Annual',
  },
  tagline: `Brand tagline changed ${input.suffix}`,
  introduction: `Brand intro changed ${input.suffix}`,
  descriptionI18n: {
    zh: `品牌介绍 changed ${input.suffix}`,
    en: `Brand intro changed ${input.suffix}`,
    ja: '',
    enFull: `Brand intro changed ${input.suffix}`,
  },
  manualLocation: {
    detailAddressI18n: {
      zh: '北京东路 9 号',
      en: '9 Beijing East Road',
      ja: '',
      enFull: '9 Beijing East Road',
    },
  },
  locationPoint: {
    ...(input.baseLocationPoint as Record<string, unknown>),
    manualSetAddressI18n: {
      zh: '主办方更新后的场地入口',
      en: 'Updated organizer gate',
      ja: '',
      enFull: '',
    },
  },
  rightsConfirmed: true,
  identityConfirmed: true,
});

const asRecord = (value: Prisma.JsonValue | null): Record<string, any> | null =>
  value && typeof value === 'object' && !Array.isArray(value)
    ? (value as Record<string, any>)
    : null;

const asStableJson = (value: Prisma.JsonValue | null): string => JSON.stringify(value);

const cleanup = async (): Promise<void> => {
  if (createdEventIds.size > 0) {
    await prisma.event.deleteMany({
      where: { id: { in: Array.from(createdEventIds) } },
    });
  }
  if (createdBrandIds.size > 0) {
    await prisma.wikiFestival.deleteMany({
      where: { id: { in: Array.from(createdBrandIds) } },
    });
  }
  if (createdUserIds.size > 0) {
    await prisma.user.deleteMany({
      where: { id: { in: Array.from(createdUserIds) } },
    });
  }
};

async function main(): Promise<void> {
  const suffix = `${Date.now()}_${crypto.randomInt(1000, 9999)}`;
  logStep('start', { suffix });

  try {
    const userId = await createRegressionUser(suffix);
    const brand = await createOrUpdateBrandFromSubmission(
      prisma,
      createBrandPayload(suffix),
      userId
    );
    createdBrandIds.add(brand.id);

    const persistedBrand = await prisma.wikiFestival.findUniqueOrThrow({
      where: { id: brand.id },
      select: {
        id: true,
        name: true,
        revision: true,
        manualLocation: true,
        locationPoint: true,
      },
    });
    const initialBrandManualLocation = asStableJson(persistedBrand.manualLocation);
    const initialBrandLocationPoint = asStableJson(persistedBrand.locationPoint);

    const event = await prisma.event.create({
      data: buildEventCreateDataFromBrand({
        suffix,
        organizerId: persistedBrand.id,
        organizerName: persistedBrand.name,
        manualLocation: persistedBrand.manualLocation as Prisma.JsonValue,
        locationPoint: persistedBrand.locationPoint as Prisma.JsonValue,
        userId,
      }),
    });
    createdEventIds.add(event.id);

    const updatedEvent = await prisma.event.update({
      where: { id: event.id },
      data: buildEventEditedAddressPatch(persistedBrand.locationPoint as Prisma.JsonValue),
      select: { id: true },
    });

    const persistedBrandAfterEventEdit = await prisma.wikiFestival.findUniqueOrThrow({
      where: { id: persistedBrand.id },
      select: {
        manualLocation: true,
        locationPoint: true,
        revision: true,
      },
    });

    assert(
      asStableJson(persistedBrandAfterEventEdit.manualLocation) === initialBrandManualLocation,
      'event edit should not mutate brand manualLocation'
    );
    assert(
      asStableJson(persistedBrandAfterEventEdit.locationPoint) === initialBrandLocationPoint,
      'event edit should not mutate brand locationPoint'
    );

    const eventAfterEdit = await prisma.event.findUniqueOrThrow({
      where: { id: updatedEvent.id },
      select: {
        manualLocation: true,
        locationPoint: true,
      },
    });
    const eventManualLocation = asRecord(eventAfterEdit.manualLocation);
    const eventLocationPoint = asRecord(eventAfterEdit.locationPoint);
    assert(
      eventManualLocation?.detailAddressI18n?.zh === '南京西路 1 号',
      'event edit should persist its own manualLocation after copying from brand'
    );
    assert(
      eventLocationPoint?.manualSetAddressI18n?.zh === '活动独立场地入口',
      'event edit should persist its own manualSetAddress after copying from brand'
    );

    await createOrUpdateBrandFromSubmission(
      prisma,
      buildBrandUpdatePayload({
        suffix,
        brandId: persistedBrand.id,
        brandName: persistedBrand.name,
        baseBrandRevision: persistedBrandAfterEventEdit.revision,
        baseLocationPoint: persistedBrand.locationPoint as Prisma.JsonValue,
      }),
      userId
    );

    const eventAfterBrandEdit = await prisma.event.findUniqueOrThrow({
      where: { id: updatedEvent.id },
      select: {
        manualLocation: true,
        locationPoint: true,
      },
    });
    const eventManualLocationAfterBrandEdit = asRecord(eventAfterBrandEdit.manualLocation);
    const eventLocationPointAfterBrandEdit = asRecord(eventAfterBrandEdit.locationPoint);
    assert(
      eventManualLocationAfterBrandEdit?.detailAddressI18n?.zh === '南京西路 1 号',
      'brand update should not retroactively mutate existing event manualLocation'
    );
    assert(
      eventLocationPointAfterBrandEdit?.manualSetAddressI18n?.zh === '活动独立场地入口',
      'brand update should not retroactively mutate existing event manualSetAddress'
    );

    logStep('passed', {
      brandId: persistedBrand.id,
      eventId: updatedEvent.id,
    });
  } finally {
    await cleanup();
    await prisma.$disconnect();
  }
}

main().catch(async (error) => {
  console.error('[brand-address-reuse-regression] failed', error);
  try {
    await cleanup();
  } finally {
    await prisma.$disconnect();
  }
  process.exit(1);
});
