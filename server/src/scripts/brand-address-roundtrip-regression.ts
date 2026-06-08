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

const createdUserIds = new Set<string>();
const createdBrandIds = new Set<string>();

const assert = (condition: boolean, message: string): void => {
  if (!condition) throw new Error(message);
};

const logStep = (step: string, detail?: Record<string, unknown>): void => {
  console.log('[brand-address-roundtrip-regression]', step, detail || {});
};

const asRecord = (value: Prisma.JsonValue | null): Record<string, any> | null =>
  value && typeof value === 'object' && !Array.isArray(value)
    ? (value as Record<string, any>)
    : null;

const createRegressionUser = async (suffix: string): Promise<string> => {
  const user = await prisma.user.create({
    data: {
      username: `brand_address_roundtrip_${suffix}`,
      email: `brand_address_roundtrip_${suffix}@example.com`,
      passwordHash: 'regression-only',
      displayName: `Brand Address Roundtrip ${suffix}`,
      displayNameNormalized: `brand address roundtrip ${suffix}`,
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

const createMapOnlyPayload = (suffix: string): Prisma.JsonObject => ({
  name: `Brand Map Only ${suffix}`,
  nameI18n: {
    zh: `仅地图主办方 ${suffix}`,
    en: `Brand Map Only ${suffix}`,
    ja: '',
    enFull: `Brand Map Only ${suffix}`,
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
  tagline: `Map only ${suffix}`,
  introduction: `Map only intro ${suffix}`,
  locationPoint: {
    provider: 'mapbox',
    sourceMode: 'manual_search',
    providerPlaceId: `mapbox-map-only-${suffix}`,
    poiId: `poi-map-only-${suffix}`,
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
    city: 'Shanghai',
    district: 'Xuhui',
    province: 'Shanghai',
    countryCode: 'CN',
    providerMeta: {
      mapbox: {
        placeId: `mapbox-map-only-${suffix}`,
        featureType: 'poi',
      },
    },
  },
  rightsConfirmed: true,
  identityConfirmed: true,
});

const createManualAndMapPayload = (suffix: string): Prisma.JsonObject => ({
  name: `Brand Manual And Map ${suffix}`,
  nameI18n: {
    zh: `手填加地图主办方 ${suffix}`,
    en: `Brand Manual And Map ${suffix}`,
    ja: '',
    enFull: `Brand Manual And Map ${suffix}`,
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
  tagline: `Manual and map ${suffix}`,
  introduction: `Manual and map intro ${suffix}`,
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
    providerPlaceId: `mapbox-manual-map-${suffix}`,
    poiId: `poi-manual-map-${suffix}`,
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
        placeId: `mapbox-manual-map-${suffix}`,
        featureType: 'poi',
      },
    },
  },
  rightsConfirmed: true,
  identityConfirmed: true,
});

const cleanup = async (): Promise<void> => {
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

    const mapOnlyBrand = await createOrUpdateBrandFromSubmission(
      prisma,
      createMapOnlyPayload(suffix),
      userId
    );
    createdBrandIds.add(mapOnlyBrand.id);

    const persistedMapOnlyBrand = await prisma.wikiFestival.findUniqueOrThrow({
      where: { id: mapOnlyBrand.id },
      select: {
        manualLocation: true,
        locationPoint: true,
      },
    });
    const mapOnlyManualLocation = asRecord(persistedMapOnlyBrand.manualLocation);
    const mapOnlyLocationPoint = asRecord(persistedMapOnlyBrand.locationPoint);
    assert(
      mapOnlyManualLocation == null,
      'map-only brand roundtrip should not persist manualLocation'
    );
    assert(
      mapOnlyLocationPoint?.formattedAddressI18n?.zh === '中国，上海市，徐汇区，徐汇滨江 88 号',
      'map-only brand roundtrip should persist provider formatted address'
    );
    assert(
      mapOnlyLocationPoint?.manualSetAddressI18n == null,
      'map-only brand roundtrip should keep manualSetAddressI18n empty'
    );

    const manualAndMapBrand = await createOrUpdateBrandFromSubmission(
      prisma,
      createManualAndMapPayload(suffix),
      userId
    );
    createdBrandIds.add(manualAndMapBrand.id);

    const persistedManualAndMapBrand = await prisma.wikiFestival.findUniqueOrThrow({
      where: { id: manualAndMapBrand.id },
      select: {
        manualLocation: true,
        locationPoint: true,
      },
    });
    const manualAndMapManualLocation = asRecord(persistedManualAndMapBrand.manualLocation);
    const manualAndMapLocationPoint = asRecord(persistedManualAndMapBrand.locationPoint);
    assert(
      manualAndMapManualLocation?.detailAddressI18n?.zh === '徐汇滨江 88 号',
      'manual+map brand roundtrip should persist detailAddressI18n'
    );
    assert(
      manualAndMapManualLocation?.formattedAddressI18n?.zh === '中国 · 上海 · 徐汇滨江 88 号',
      'manual+map brand roundtrip should regenerate manualLocation.formattedAddressI18n.zh'
    );
    assert(
      manualAndMapManualLocation?.formattedAddressI18n?.en === 'China · Shanghai · 88 Xuhui Riverside',
      'manual+map brand roundtrip should regenerate manualLocation.formattedAddressI18n.en'
    );
    assert(
      manualAndMapLocationPoint?.formattedAddressI18n?.zh === '中国，上海市，徐汇区，徐汇滨江 88 号',
      'manual+map brand roundtrip should preserve provider formatted address'
    );
    assert(
      manualAndMapLocationPoint?.manualSetAddressI18n?.zh === '西岸艺术中心主入口',
      'manual+map brand roundtrip should persist explicit manualSetAddressI18n'
    );

    logStep('passed', {
      mapOnlyBrandId: mapOnlyBrand.id,
      manualAndMapBrandId: manualAndMapBrand.id,
    });
  } finally {
    await cleanup();
    await prisma.$disconnect();
  }
}

main().catch(async (error) => {
  console.error('[brand-address-roundtrip-regression] failed', error);
  try {
    await cleanup();
  } finally {
    await prisma.$disconnect();
  }
  process.exit(1);
});
