import { normalizeText } from './localization';

type EventImageAssetPayload = {
  bucket?: string | null;
  zone?: string | null;
  type?: string | null;
  purpose?: string | null;
  kind?: string | null;
  label?: string | null;
  fileName?: string | null;
  url?: string | null;
  sort?: number | null;
  order?: number | null;
};

type EventImageBucket = 'cover' | 'poster' | 'lineup' | 'timetable' | 'other';

export const parseEventImageAssets = (value: unknown): EventImageAssetPayload[] => {
  if (!Array.isArray(value)) return [];
  return value.filter((item): item is EventImageAssetPayload => Boolean(item && typeof item === 'object'));
};

export const resolveEventImageAssetBucket = (asset: EventImageAssetPayload): EventImageBucket => {
  const type = normalizeText(asset.type)?.toLowerCase() || '';
  const purpose = normalizeText(asset.purpose)?.toLowerCase() || '';
  const kind = normalizeText(asset.kind)?.toLowerCase() || '';
  const bucket = normalizeText(asset.bucket)?.toLowerCase() || '';
  const zone = normalizeText(asset.zone)?.toLowerCase() || '';
  const label = normalizeText(asset.label)?.toLowerCase() || '';
  const fileName = normalizeText(asset.fileName)?.toLowerCase() || '';
  const raw = [type, purpose, kind, bucket, zone].find(Boolean) || '';

  if (
    raw === 'cover'
    || raw.includes('cover')
    || label.includes('cover')
    || fileName.startsWith('cover')
  ) {
    return 'cover';
  }
  if (
    raw === 'poster'
    || raw.includes('poster')
    || label.includes('poster')
    || fileName.startsWith('poster')
  ) {
    return 'poster';
  }
  if (
    raw === 'luall'
    || raw.includes('lineup')
    || label.includes('line-up')
    || label.includes('lineup')
  ) {
    return 'lineup';
  }
  if (raw === 'tt' || raw.includes('timetable') || label.includes('timetable')) {
    return 'timetable';
  }
  return 'other';
};

export const sortEventImageAssetsForDisplay = (assets: EventImageAssetPayload[]): EventImageAssetPayload[] =>
  [...assets].sort((a, b) => {
    const aOrder = typeof a.sort === 'number' ? a.sort : typeof a.order === 'number' ? a.order : Number.MAX_SAFE_INTEGER;
    const bOrder = typeof b.sort === 'number' ? b.sort : typeof b.order === 'number' ? b.order : Number.MAX_SAFE_INTEGER;
    return aOrder - bOrder;
  });

const resolveFirstAssetUrl = (
  assets: EventImageAssetPayload[],
  bucket: EventImageBucket
): string | null => normalizeText(assets.find((asset) => resolveEventImageAssetBucket(asset) === bucket)?.url);

export const resolveEventPosterBackgroundImageUrl = (row: {
  imageAssets?: unknown;
  coverImageUrl?: unknown;
  lineupImageUrl?: unknown;
}): string | null => {
  const assets = sortEventImageAssetsForDisplay(parseEventImageAssets(row.imageAssets ?? []));
  const coverAssetUrl = resolveFirstAssetUrl(assets, 'cover');
  const posterAssetUrl = resolveFirstAssetUrl(assets, 'poster');
  const lineupAssetUrl = resolveFirstAssetUrl(assets, 'lineup');

  return (
    normalizeText(row.coverImageUrl) ||
    coverAssetUrl ||
    posterAssetUrl ||
    normalizeText(row.lineupImageUrl) ||
    lineupAssetUrl ||
    null
  );
};
