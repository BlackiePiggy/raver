import 'dotenv/config';
import { Prisma } from '@prisma/client';
import { normalizeBrandSubmissionPayload } from '../services/content-submission-brand.service';

const assert = (condition: boolean, message: string): void => {
  if (!condition) throw new Error(message);
};

const mapOnlyPayload = {
  name: 'Brand Map Only',
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
  tagline: 'Map only',
  introduction: 'Map only intro',
  locationPoint: {
    provider: 'mapbox',
    sourceMode: 'manual_search',
    providerPlaceId: 'mapbox-map-only',
    poiId: 'poi-map-only',
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
        placeId: 'mapbox-map-only',
        featureType: 'poi',
      },
    },
  },
  rightsConfirmed: true,
  identityConfirmed: true,
} satisfies Prisma.InputJsonObject;

const manualAndMapPayload = {
  name: 'Brand Manual And Map',
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
  tagline: 'Manual and map',
  introduction: 'Manual and map intro',
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
    providerPlaceId: 'mapbox-manual-map',
    poiId: 'poi-manual-map',
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
        placeId: 'mapbox-manual-map',
        featureType: 'poi',
      },
    },
  },
  rightsConfirmed: true,
  identityConfirmed: true,
} satisfies Prisma.InputJsonObject;

function main(): void {
  const normalizedMapOnly = normalizeBrandSubmissionPayload(mapOnlyPayload);
  const mapOnlyManualLocation = normalizedMapOnly.manualLocation as Record<string, any> | null | undefined;
  const mapOnlyLocationPoint = normalizedMapOnly.locationPoint as Record<string, any> | null | undefined;

  assert(mapOnlyLocationPoint != null, 'map-only brand payload should preserve locationPoint');
  assert(
    mapOnlyLocationPoint?.formattedAddressI18n?.zh === '中国，上海市，徐汇区，徐汇滨江 88 号',
    'map-only brand payload should preserve map formatted address'
  );
  assert(
    mapOnlyManualLocation == null,
    'map-only brand payload should not invent manualLocation when detailAddress is absent'
  );

  const normalizedManualAndMap = normalizeBrandSubmissionPayload(manualAndMapPayload);
  const manualAndMapManualLocation = normalizedManualAndMap.manualLocation as Record<string, any> | null | undefined;
  const manualAndMapLocationPoint = normalizedManualAndMap.locationPoint as Record<string, any> | null | undefined;

  assert(manualAndMapManualLocation != null, 'manual+map brand payload should preserve manualLocation');
  assert(
    manualAndMapManualLocation?.formattedAddressI18n?.zh === '中国 · 上海 · 徐汇滨江 88 号',
    'manual+map brand payload should regenerate manualLocation.formattedAddressI18n.zh from detailAddress + city + country'
  );
  assert(
    manualAndMapManualLocation?.formattedAddressI18n?.en === 'China · Shanghai · 88 Xuhui Riverside',
    'manual+map brand payload should regenerate manualLocation.formattedAddressI18n.en from detailAddress + city + country'
  );
  assert(
    manualAndMapLocationPoint?.formattedAddressI18n?.zh === '中国，上海市，徐汇区，徐汇滨江 88 号',
    'manual+map brand payload should preserve provider formatted address instead of overwriting it'
  );
  assert(
    manualAndMapLocationPoint?.manualSetAddressI18n?.zh === '西岸艺术中心主入口',
    'manual+map brand payload should preserve explicit manualSetAddressI18n'
  );

  console.log('PASS brand address payload guardrails');
}

main();
