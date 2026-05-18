// Event location shared state + helpers
const eventLocationPickerState = {
  open: false,
  mode: 'edit',
  provider: 'amap',
  panelEl: null,
  fest: null,
  onConfirm: null,
  composedQuery: '',
  composedQueryZh: '',
  composedQueryEn: '',
  selectedPoint: null,
  previewPoint: null,
  selectedCandidateIdx: -1,
  renderRows: [],
  candidates: [],
};

function normalizeEventLocationPoint(raw) {
  if (!raw || typeof raw !== 'object') return null;
  const lng = Number(raw?.location?.lng ?? raw?.lng ?? raw?.longitude);
  const lat = Number(raw?.location?.lat ?? raw?.lat ?? raw?.latitude);
  if (!Number.isFinite(lng) || !Number.isFinite(lat)) return null;
  const providerRaw = String(raw?.provider || 'amap').trim().toLowerCase() || 'amap';
  const provider = typeof normalizeEventLocationProvider === 'function'
    ? normalizeEventLocationProvider(providerRaw)
    : providerRaw;
  const providerMetaRaw = (raw?.providerMeta && typeof raw.providerMeta === 'object')
    ? raw.providerMeta
    : null;
  const providerMeta = {
    ...(providerMetaRaw && providerMetaRaw.amap && typeof providerMetaRaw.amap === 'object'
      ? {
          amap: {
            poiId: String(providerMetaRaw.amap?.poiId || '').trim(),
            adcode: String(providerMetaRaw.amap?.adcode || '').trim(),
          },
        }
      : {}),
    ...(providerMetaRaw && providerMetaRaw.google && typeof providerMetaRaw.google === 'object'
      ? {
          google: {
            placeId: String(providerMetaRaw.google?.placeId || '').trim(),
            types: Array.isArray(providerMetaRaw.google?.types)
              ? providerMetaRaw.google.types.map((item) => String(item || '').trim()).filter(Boolean).slice(0, 20)
              : [],
          },
        }
      : {}),
    ...(providerMetaRaw && providerMetaRaw.mapkit && typeof providerMetaRaw.mapkit === 'object'
      ? {
          mapkit: {
            mapItemIdentifier: String(providerMetaRaw.mapkit?.mapItemIdentifier || '').trim(),
          },
        }
      : {}),
    ...(providerMetaRaw && providerMetaRaw.mapbox && typeof providerMetaRaw.mapbox === 'object'
      ? {
          mapbox: {
            placeId: String(providerMetaRaw.mapbox?.placeId || '').trim(),
            featureType: String(providerMetaRaw.mapbox?.featureType || '').trim(),
          },
        }
      : {}),
    ...(providerMetaRaw && providerMetaRaw.geoapify && typeof providerMetaRaw.geoapify === 'object'
      ? {
          geoapify: {
            placeId: String(providerMetaRaw.geoapify?.placeId || '').trim(),
            featureType: String(providerMetaRaw.geoapify?.featureType || '').trim(),
          },
        }
      : {}),
  };
  const providerPlaceId = String(
    raw?.providerPlaceId
    || raw?.poiId
    || providerMeta.amap?.poiId
    || providerMeta.google?.placeId
    || providerMeta.mapkit?.mapItemIdentifier
    || providerMeta.mapbox?.placeId
    || providerMeta.geoapify?.placeId
    || ''
  ).trim();
  const poiId = String(raw?.poiId || providerMeta.amap?.poiId || (provider === 'amap' ? providerPlaceId : '') || '').trim();
  const adcode = String(raw?.adcode || providerMeta.amap?.adcode || '').trim();
  if (poiId || adcode) {
    providerMeta.amap = {
      poiId: poiId || '',
      adcode: adcode || '',
    };
  }
  const nameZh = String(raw?.nameI18n?.zh || raw?.name || '').trim();
  const nameEn = String(raw?.nameI18n?.en || nameZh).trim();
  const addrZh = String(raw?.addressI18n?.zh || raw?.address || '').trim();
  const addrEn = String(raw?.addressI18n?.en || addrZh).trim();
  const formattedZh = String(raw?.formattedAddressI18n?.zh || raw?.formattedAddress || addrZh).trim();
  const formattedEn = String(raw?.formattedAddressI18n?.en || formattedZh || addrEn).trim();
  const countryCode = String(raw?.countryCode || '').trim().toUpperCase();
  return {
    provider,
    sourceMode: String(raw?.sourceMode || 'manual_search').trim() || 'manual_search',
    providerPlaceId,
    // Legacy alias: retained to keep existing AMap behaviors working.
    poiId,
    location: { lng, lat },
    nameI18n: { zh: nameZh, en: nameEn },
    addressI18n: { zh: addrZh, en: addrEn },
    formattedAddressI18n: { zh: formattedZh, en: formattedEn },
    // Legacy alias: retained for existing AMap panel/details logic.
    adcode,
    city: String(raw?.city || '').trim(),
    district: String(raw?.district || '').trim(),
    province: String(raw?.province || '').trim(),
    countryCode,
    providerMeta: Object.keys(providerMeta).length ? providerMeta : null,
    i18nPending: !!raw?.i18nPending,
    selectedAt: String(raw?.selectedAt || new Date().toISOString()).trim(),
  };
}

function formatEventLocationPointBrief(point) {
  const p = normalizeEventLocationPoint(point);
  if (!p) return '未绑定定位地点';
  const addr = String(p.formattedAddressI18n?.zh || p.formattedAddressI18n?.en || '').trim();
  const coord = `${Number(p.location.lng).toFixed(6)}, ${Number(p.location.lat).toFixed(6)}`;
  return [addr || '-', coord].filter(Boolean).join(' · ');
}

function readEventLocationPointFromHiddenInput(panelEl) {
  if (!panelEl) return null;
  const input = panelEl.querySelector('.fest-info-edit [data-field="locationPointJson"]');
  const raw = String(input?.value || '').trim();
  if (!raw) return null;
  try {
    return normalizeEventLocationPoint(JSON.parse(raw));
  } catch (_error) {
    return null;
  }
}

function writeEventLocationPointToHiddenInput(panelEl, point) {
  if (!panelEl) return;
  const input = panelEl.querySelector('.fest-info-edit [data-field="locationPointJson"]');
  if (!input) return;
  const normalized = normalizeEventLocationPoint(point);
  input.value = normalized ? JSON.stringify(normalized) : '';
}
