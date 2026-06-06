type JsonRecord = Record<string, unknown>;
import { getWebCozeRuntimeConfig } from '@/lib/server/runtime-coze-config';

const asRecord = (value: unknown): JsonRecord => {
  if (!value || typeof value !== 'object' || Array.isArray(value)) {
    return {};
  }
  return value as JsonRecord;
};

const cleanText = (value: unknown): string => (typeof value === 'string' ? value.trim() : '');

const cleanBiText = (value: unknown): { zh: string; en: string } => {
  if (typeof value === 'string') {
    const text = value.trim();
    return { zh: text, en: text };
  }
  const record = asRecord(value);
  const zh = cleanText(record.zh);
  const en = cleanText(record.en);
  const fallback = zh || en;
  return {
    zh: zh || fallback,
    en: en || fallback,
  };
};

const toNumberOrNull = (value: unknown): number | null => {
  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : null;
};

const parsePossibleJson = (rawText: string): unknown => {
  const trimmed = String(rawText || '').trim();
  if (!trimmed) return null;
  try {
    return JSON.parse(trimmed);
  } catch {
    const firstBrace = trimmed.indexOf('{');
    const lastBrace = trimmed.lastIndexOf('}');
    if (firstBrace >= 0 && lastBrace > firstBrace) {
      try {
        return JSON.parse(trimmed.slice(firstBrace, lastBrace + 1));
      } catch {
        return null;
      }
    }
    return null;
  }
};

const extractJsonFragment = (value: string): unknown => parsePossibleJson(value);

const normalizeCountryCode = (value: unknown): string => {
  const text = cleanText(value).toUpperCase();
  if (!text) return '';
  if (text.length === 2 || text.length === 3) return text;
  return text.slice(0, 3);
};

const normalizeTypes = (value: unknown): string[] => {
  if (Array.isArray(value)) {
    return value
      .map((item) => cleanText(item))
      .filter(Boolean)
      .slice(0, 20);
  }
  const text = cleanText(value);
  return text
    ? text
        .split(',')
        .map((item) => item.trim())
        .filter(Boolean)
        .slice(0, 20)
    : [];
};

const normalizeLocationPayloadForCoze = (
  locationPayload: JsonRecord,
  contextPayload: JsonRecord,
  rawPayload: JsonRecord
) => {
  const editableNode = asRecord(rawPayload.editable);
  const lockedNode = asRecord(rawPayload.locked);
  const hintsNode = asRecord(rawPayload.hints);
  const locationNode = asRecord(locationPayload.location);
  const eventCountryNode =
    asRecord(contextPayload.eventCountryI18n).zh || asRecord(contextPayload.eventCountryI18n).en
      ? asRecord(contextPayload.eventCountryI18n)
      : asRecord(contextPayload.countryI18n);

  return {
    editable: {
      nameI18n: cleanBiText(editableNode.nameI18n || locationPayload.nameI18n || locationPayload.name),
      addressI18n: cleanBiText(
        editableNode.addressI18n || locationPayload.addressI18n || locationPayload.address
      ),
      formattedAddressI18n: cleanBiText(
        editableNode.formattedAddressI18n ||
          locationPayload.formattedAddressI18n ||
          locationPayload.formattedAddress
      ),
      city: cleanText(editableNode.city || locationPayload.city),
      district: cleanText(editableNode.district || locationPayload.district),
      province: cleanText(editableNode.province || locationPayload.province),
      countryCode: normalizeCountryCode(editableNode.countryCode || locationPayload.countryCode),
    },
    locked: {
      provider: cleanText(lockedNode.provider || locationPayload.provider),
      sourceMode: cleanText(lockedNode.sourceMode || locationPayload.sourceMode),
      lng: toNumberOrNull(
        lockedNode.lng ?? locationNode.lng ?? locationPayload.lng ?? locationPayload.longitude
      ),
      lat: toNumberOrNull(
        lockedNode.lat ?? locationNode.lat ?? locationPayload.lat ?? locationPayload.latitude
      ),
      providerPlaceId: cleanText(lockedNode.providerPlaceId || locationPayload.providerPlaceId),
    },
    hints: {
      eventCountryI18n: {
        zh:
          cleanText(hintsNode.eventCountryI18n && asRecord(hintsNode.eventCountryI18n).zh) ||
          cleanText(eventCountryNode.zh),
        en:
          cleanText(hintsNode.eventCountryI18n && asRecord(hintsNode.eventCountryI18n).en) ||
          cleanText(eventCountryNode.en) ||
          cleanText(eventCountryNode.enFull),
      },
    },
  };
};

const pickLocationCandidate = (payload: unknown): JsonRecord => {
  const root = asRecord(payload);
  const queue: unknown[] = [root];
  while (queue.length > 0) {
    const current = queue.shift();
    const record = asRecord(current);
    if (record.provider || record.location || record.nameI18n || record.formattedAddressI18n) {
      return record;
    }
    for (const value of Object.values(record)) {
      if (typeof value === 'string') {
        const parsed = extractJsonFragment(value);
        if (parsed) queue.push(parsed);
      } else if (value && typeof value === 'object') {
        queue.push(value);
      }
    }
  }
  return root;
};

const extractLocationNormalizationInfo = (payload: unknown) => {
  const source = pickLocationCandidate(payload);
  const locationNode = asRecord(source.location);
  const providerMetaRaw = asRecord(source.providerMeta || source.provider_meta);
  const amapMeta = asRecord(providerMetaRaw.amap);
  const mapkitMeta = asRecord(providerMetaRaw.mapkit);
  const mapboxMeta = asRecord(providerMetaRaw.mapbox);
  const geoapifyMeta = asRecord(providerMetaRaw.geoapify);
  const googleMeta = asRecord(providerMetaRaw.google);

  const poiId = cleanText(source.poiId || source.poi_id || amapMeta.poiId);
  const adcode = cleanText(source.adcode || amapMeta.adcode);
  const mapkitId = cleanText(
    source.mapkitMapItemIdentifier || source.mapItemIdentifier || mapkitMeta.mapItemIdentifier
  );
  const mapboxPlaceId = cleanText(source.mapboxPlaceId || mapboxMeta.placeId);
  const mapboxFeatureType = cleanText(source.mapboxFeatureType || mapboxMeta.featureType);
  const geoapifyPlaceId = cleanText(source.geoapifyPlaceId || geoapifyMeta.placeId);
  const geoapifyFeatureType = cleanText(source.geoapifyFeatureType || geoapifyMeta.featureType);
  const googlePlaceId = cleanText(source.googlePlaceId || googleMeta.placeId);
  const googleTypes = normalizeTypes(source.googleTypes || googleMeta.types);

  return {
    provider: cleanText(source.provider),
    sourceMode: cleanText(source.sourceMode || source.source_mode),
    providerPlaceId:
      cleanText(
        source.providerPlaceId ||
          source.provider_place_id ||
          poiId ||
          mapkitId ||
          mapboxPlaceId ||
          geoapifyPlaceId ||
          googlePlaceId
      ) || '',
    poiId,
    adcode,
    location: {
      lng:
        toNumberOrNull(source.lng ?? source.longitude ?? locationNode.lng ?? locationNode.longitude) ??
        undefined,
      lat:
        toNumberOrNull(source.lat ?? source.latitude ?? locationNode.lat ?? locationNode.latitude) ??
        undefined,
    },
    nameI18n: cleanBiText(source.nameI18n || source.name_i18n || source.name),
    addressI18n: cleanBiText(source.addressI18n || source.address_i18n || source.address),
    formattedAddressI18n: cleanBiText(
      source.formattedAddressI18n || source.formatted_address_i18n || source.formattedAddress
    ),
    countryCode: normalizeCountryCode(source.countryCode || source.country_code),
    city: cleanText(source.city),
    district: cleanText(source.district),
    province: cleanText(source.province),
    providerMeta: {
      amap: {
        poiId,
        adcode,
      },
      mapkit: {
        mapItemIdentifier: mapkitId,
      },
      mapbox: {
        placeId: mapboxPlaceId,
        featureType: mapboxFeatureType,
      },
      geoapify: {
        placeId: geoapifyPlaceId,
        featureType: geoapifyFeatureType,
      },
      google: {
        placeId: googlePlaceId,
        types: googleTypes,
      },
    },
  };
};

const extractLocationNormalizationIssues = (payload: unknown): string[] => {
  const issues: string[] = [];
  const seen = new Set<string>();

  const push = (value: unknown) => {
    const text = cleanText(value).replace(/\s+/g, ' ');
    if (!text) return;
    const key = text.toLowerCase();
    if (seen.has(key)) return;
    seen.add(key);
    issues.push(text.length > 240 ? `${text.slice(0, 237)}...` : text);
  };

  const walk = (node: unknown) => {
    if (Array.isArray(node)) {
      node.forEach(walk);
      return;
    }
    const record = asRecord(node);
    for (const [key, value] of Object.entries(record)) {
      const normalizedKey = key.replace(/[^a-z0-9]/gi, '').toLowerCase();
      if (
        ['issues', 'warnings', 'warning', 'errors', 'error', 'problems', 'problem', 'notes', 'messages'].includes(
          normalizedKey
        )
      ) {
        if (Array.isArray(value)) {
          value.forEach((item) => {
            const itemRecord = asRecord(item);
            push(itemRecord.message || itemRecord.text || itemRecord.issue || item);
          });
        } else {
          const itemRecord = asRecord(value);
          push(itemRecord.message || itemRecord.text || itemRecord.issue || value);
        }
      }
      if (typeof value === 'string') {
        const parsed = extractJsonFragment(value);
        if (parsed) walk(parsed);
      } else if (value && typeof value === 'object') {
        walk(value);
      }
    }
  };

  walk(payload);
  return issues.slice(0, 20);
};

export const runCozeLocationNormalize = async (payload: unknown) => {
  const runtimeConfig = getWebCozeRuntimeConfig();
  const cozeLocationNormalizeRunUrl = runtimeConfig.locationNormalize.runUrl;
  const cozeLocationNormalizeToken = runtimeConfig.locationNormalize.token;
  const cozeLocationNormalizeTimeoutMs = runtimeConfig.locationNormalize.timeoutMs;
  if (!cozeLocationNormalizeRunUrl || !cozeLocationNormalizeToken) {
    throw new Error(
      'COZE_LOCATION_NORMALIZE_RUN_URL or COZE_LOCATION_NORMALIZE_TOKEN is not configured'
    );
  }

  const bodyRecord = asRecord(payload);
  const locationPayload = asRecord(
    bodyRecord.location || bodyRecord.locationPoint || bodyRecord.location_point
  );
  const editablePayload = asRecord(bodyRecord.editable);
  if (!Object.keys(locationPayload).length && !Object.keys(editablePayload).length) {
    throw new Error('location or editable object is required');
  }

  const requestPayload = normalizeLocationPayloadForCoze(
    locationPayload,
    asRecord(bodyRecord.context),
    bodyRecord
  );

  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), cozeLocationNormalizeTimeoutMs);

  let rawText = '';
  try {
    const response = await fetch(cozeLocationNormalizeRunUrl, {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${cozeLocationNormalizeToken}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(requestPayload),
      signal: controller.signal,
    });
    rawText = await response.text();
    if (!response.ok) {
      throw new Error(
        `Coze location normalize request failed (${response.status}): ${rawText.slice(0, 500)}`
      );
    }
  } catch (error) {
    if (error instanceof Error && error.name === 'AbortError') {
      throw new Error(`COZE_LOCATION_NORMALIZE_TIMEOUT after ${cozeLocationNormalizeTimeoutMs}ms`);
    }
    throw error;
  } finally {
    clearTimeout(timeout);
  }

  const raw = parsePossibleJson(rawText);
  if (!raw) {
    throw new Error('Coze location normalize returned non-JSON content');
  }

  return {
    raw,
    normalized: extractLocationNormalizationInfo(raw),
    issues: extractLocationNormalizationIssues(raw),
  };
};
