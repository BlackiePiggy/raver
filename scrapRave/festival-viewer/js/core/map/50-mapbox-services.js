// Core map services (Mapbox wrappers)
function mapboxText(value) {
  return String(value || '').trim();
}

function toMapboxLngLatPoint(raw) {
  if (!raw) return null;
  if (Array.isArray(raw) && raw.length >= 2) {
    const lng = Number(raw[0]);
    const lat = Number(raw[1]);
    if (!Number.isFinite(lng) || !Number.isFinite(lat)) return null;
    return { lng, lat };
  }
  if (typeof raw === 'string') {
    const parts = String(raw).split(',');
    if (parts.length >= 2) {
      const lng = Number(parts[0]);
      const lat = Number(parts[1]);
      if (!Number.isFinite(lng) || !Number.isFinite(lat)) return null;
      return { lng, lat };
    }
  }
  if (typeof raw !== 'object') return null;
  const lng = Number(
    raw.lng
    ?? raw.lon
    ?? raw.longitude
    ?? raw?.center?.lng
    ?? raw?.center?.[0]
    ?? raw?.geometry?.coordinates?.[0]
  );
  const lat = Number(
    raw.lat
    ?? raw.latitude
    ?? raw?.center?.lat
    ?? raw?.center?.[1]
    ?? raw?.geometry?.coordinates?.[1]
  );
  if (!Number.isFinite(lng) || !Number.isFinite(lat)) return null;
  return { lng, lat };
}

function mapboxGetFeatureContextItem(feature, prefix) {
  const rows = Array.isArray(feature?.context) ? feature.context : [];
  const target = String(prefix || '').trim().toLowerCase();
  return rows.find((item) => String(item?.id || '').toLowerCase().startsWith(`${target}.`)) || null;
}

function mapboxBuildAddressFromFeature(feature) {
  const candidates = [
    feature?.place_name_zh,
    feature?.place_name,
    feature?.properties?.full_address,
    feature?.properties?.place_formatted,
    feature?.properties?.address,
  ];
  for (const item of candidates) {
    const text = mapboxText(item);
    if (text) return text;
  }
  const row = [
    mapboxText(feature?.properties?.address || ''),
    mapboxText(feature?.text_zh || feature?.text || feature?.properties?.name || ''),
    mapboxText(mapboxGetFeatureContextItem(feature, 'place')?.text || ''),
    mapboxText(mapboxGetFeatureContextItem(feature, 'region')?.text || ''),
    mapboxText(mapboxGetFeatureContextItem(feature, 'country')?.text || ''),
  ].filter(Boolean);
  return row.join(', ');
}

function mapboxResolveFeatureType(feature) {
  const placeType = Array.isArray(feature?.place_type) ? feature.place_type : [];
  const first = mapboxText(placeType[0] || '');
  if (first) return first;
  const propsType = mapboxText(feature?.properties?.feature_type || feature?.properties?.category || '');
  return propsType;
}

function mapboxResolvePlaceId(feature) {
  return mapboxText(
    feature?.properties?.mapbox_id
    || feature?.id
    || feature?.properties?.id
    || ''
  );
}

function mapboxResolveCountryCode(feature) {
  const fromProps = mapboxText(feature?.properties?.short_code || '').toUpperCase();
  if (fromProps) return fromProps;
  const country = mapboxGetFeatureContextItem(feature, 'country');
  const fromCtx = mapboxText(country?.short_code || country?.properties?.short_code || '').toUpperCase();
  return fromCtx;
}

function normalizeMapboxFeature(feature, sourceMode = 'manual_search', extra = {}) {
  const location = toMapboxLngLatPoint(feature);
  if (!location) return null;
  const placeId = mapboxResolvePlaceId(feature);
  const featureType = mapboxResolveFeatureType(feature);
  const nameZh = mapboxText(feature?.text_zh || feature?.text || feature?.properties?.name || extra?.nameZh || '');
  const nameEn = mapboxText(extra?.nameEn || feature?.text_en || feature?.text || feature?.properties?.name || nameZh);
  const addrZh = mapboxText(extra?.addressZh || mapboxBuildAddressFromFeature(feature));
  const addrEn = mapboxText(extra?.addressEn || feature?.place_name_en || feature?.place_name || addrZh);
  const formattedZh = mapboxText(extra?.formattedZh || addrZh);
  const formattedEn = mapboxText(extra?.formattedEn || addrEn || formattedZh);
  const city = mapboxText(
    feature?.properties?.city
    || mapboxGetFeatureContextItem(feature, 'place')?.text
    || mapboxGetFeatureContextItem(feature, 'locality')?.text
    || ''
  );
  const district = mapboxText(
    mapboxGetFeatureContextItem(feature, 'district')?.text
    || mapboxGetFeatureContextItem(feature, 'neighborhood')?.text
    || ''
  );
  const province = mapboxText(mapboxGetFeatureContextItem(feature, 'region')?.text || '');
  const countryCode = mapboxResolveCountryCode(feature);
  return {
    provider: 'mapbox',
    sourceMode,
    providerPlaceId: placeId,
    location,
    nameI18n: {
      zh: nameZh,
      en: nameEn,
    },
    addressI18n: {
      zh: addrZh,
      en: addrEn,
    },
    formattedAddressI18n: {
      zh: formattedZh,
      en: formattedEn,
    },
    city,
    district,
    province,
    countryCode,
    providerMeta: {
      mapbox: {
        placeId: placeId || '',
        featureType: featureType || '',
      },
    },
    i18nPending: !(mapboxText(nameEn) && mapboxText(formattedEn)),
    selectedAt: new Date().toISOString(),
  };
}

async function mapboxSearchOnce(query, options = {}) {
  const q = mapboxText(query);
  if (!q) return [];
  await ensureMapboxLoaded();
  const cfg = await getMapboxRuntimeConfig(false).catch(() => null);
  const token = mapboxText(cfg?.accessToken || window?.mapboxgl?.accessToken || '');
  if (!token) return [];
  const url = `https://api.mapbox.com/geocoding/v5/mapbox.places/${encodeURIComponent(q)}.json`;
  const params = new URLSearchParams({
    access_token: token,
    limit: String(Math.max(1, Math.min(20, Number(options.limit || 20) || 20))),
    autocomplete: options.autocomplete === false ? 'false' : 'true',
    language: mapboxText(options.language || 'zh-Hans'),
    types: mapboxText(options.types || 'poi,address,place,locality,district,region,country,neighborhood'),
  });
  const coordinate = toMapboxLngLatPoint(options.coordinate || null);
  if (coordinate) params.set('proximity', `${coordinate.lng},${coordinate.lat}`);
  if (mapboxText(options.country)) params.set('country', mapboxText(options.country));
  const resp = await fetch(`${url}?${params.toString()}`);
  if (!resp.ok) return [];
  const data = await resp.json().catch(() => ({}));
  return Array.isArray(data?.features) ? data.features : [];
}

function mapboxMergeSearchRows(primaryRows, enRows, sourceMode = 'manual_search') {
  const rows = [];
  const keyToIdx = new Map();
  const push = (feature, extra = {}) => {
    const normalized = normalizeMapboxFeature(feature, sourceMode, extra);
    if (!normalized) return;
    const key = `${normalized.location.lng.toFixed(6)},${normalized.location.lat.toFixed(6)}::${mapboxText(normalized.providerPlaceId)}`;
    const idx = keyToIdx.get(key);
    if (idx === undefined) {
      keyToIdx.set(key, rows.length);
      rows.push(normalized);
      return;
    }
    rows[idx] = normalizeEventLocationPoint(eventLocationMergePoints(rows[idx], normalized));
  };
  for (const row of primaryRows || []) push(row);
  for (const row of enRows || []) {
    push(row, {
      nameEn: mapboxText(row?.text_en || row?.text || row?.properties?.name || ''),
      addressEn: mapboxText(row?.place_name_en || row?.place_name || ''),
      formattedEn: mapboxText(row?.place_name_en || row?.place_name || ''),
    });
  }
  return rows.slice(0, 20);
}

async function mapboxSearchPlacesByKeyword(keyword, options = {}) {
  const q = mapboxText(keyword);
  if (!q) return [];
  const primaryRows = await mapboxSearchOnce(q, {
    language: mapboxText(options.language || 'zh-Hans'),
    coordinate: options.coordinate || null,
    limit: options.limit || 20,
  }).catch(() => []);
  const enRows = await mapboxSearchOnce(q, {
    language: 'en',
    coordinate: options.coordinate || null,
    limit: options.limit || 20,
  }).catch(() => []);
  return mapboxMergeSearchRows(primaryRows, enRows, mapboxText(options.sourceMode || 'manual_search') || 'manual_search');
}

async function mapboxReverseOnce(point, language = 'zh-Hans') {
  const target = toMapboxLngLatPoint(point);
  if (!target) return [];
  await ensureMapboxLoaded();
  const cfg = await getMapboxRuntimeConfig(false).catch(() => null);
  const token = mapboxText(cfg?.accessToken || window?.mapboxgl?.accessToken || '');
  if (!token) return [];
  const url = `https://api.mapbox.com/geocoding/v5/mapbox.places/${target.lng},${target.lat}.json`;
  const params = new URLSearchParams({
    access_token: token,
    language: mapboxText(language || 'zh-Hans'),
    limit: '10',
    types: 'poi,address,place,locality,district,region,country,neighborhood',
  });
  const resp = await fetch(`${url}?${params.toString()}`);
  if (!resp.ok) return [];
  const data = await resp.json().catch(() => ({}));
  return Array.isArray(data?.features) ? data.features : [];
}

async function mapboxReverseGeocodeByPoint(point, options = {}) {
  const target = toMapboxLngLatPoint(point);
  if (!target) return null;
  const zhRows = await mapboxReverseOnce(target, 'zh-Hans').catch(() => []);
  const enRows = await mapboxReverseOnce(target, 'en').catch(() => []);
  const zhTop = zhRows[0] || null;
  const enTop = enRows[0] || null;
  if (!zhTop && !enTop) {
    return normalizeEventLocationPoint({
      provider: 'mapbox',
      sourceMode: mapboxText(options.sourceMode || 'pin_drag') || 'pin_drag',
      providerPlaceId: '',
      location: target,
      nameI18n: { zh: `${target.lng.toFixed(6)},${target.lat.toFixed(6)}`, en: `${target.lng.toFixed(6)},${target.lat.toFixed(6)}` },
      addressI18n: { zh: '', en: '' },
      formattedAddressI18n: { zh: '', en: '' },
      city: '',
      district: '',
      province: '',
      countryCode: '',
      providerMeta: null,
      i18nPending: true,
      selectedAt: new Date().toISOString(),
    });
  }
  const base = normalizeMapboxFeature(
    zhTop || enTop,
    mapboxText(options.sourceMode || 'pin_drag') || 'pin_drag',
    {
      nameEn: mapboxText(enTop?.text_en || enTop?.text || enTop?.properties?.name || ''),
      addressEn: mapboxText(enTop?.place_name_en || enTop?.place_name || ''),
      formattedEn: mapboxText(enTop?.place_name_en || enTop?.place_name || ''),
    }
  );
  return normalizeEventLocationPoint(base);
}

function mapboxBuildNearbyQuery(point, regeo) {
  const p = normalizeEventLocationPoint(point);
  const r = normalizeEventLocationPoint(regeo);
  const parts = [
    mapboxText(r?.nameI18n?.zh || r?.nameI18n?.en || ''),
    mapboxText(r?.city || p?.city || ''),
    mapboxText(r?.province || p?.province || ''),
  ].filter(Boolean);
  return parts.join(' ').trim();
}

async function mapboxSearchNearbyByPoint(point, options = {}) {
  const target = toMapboxLngLatPoint(point);
  if (!target) return [];
  const regeo = await mapboxReverseGeocodeByPoint(target, { sourceMode: options.sourceMode || 'pin_drag' }).catch(() => null);
  const keyword = mapboxBuildNearbyQuery(point, regeo);
  if (!keyword) return [];
  return mapboxSearchPlacesByKeyword(keyword, {
    sourceMode: options.sourceMode || 'pin_drag',
    coordinate: target,
    limit: 20,
  }).catch(() => []);
}

function mapboxLocationPointFromMapClickEvent(evt, sourceMode = 'map_poi_click') {
  const feature = evt && typeof evt === 'object' ? (evt.feature || evt.poiFeature || null) : null;
  const lngLat = toMapboxLngLatPoint(evt?.lngLat || evt?.lnglat || evt?.location || null);
  if (feature) {
    const normalized = normalizeMapboxFeature(feature, sourceMode);
    if (normalized) return normalized;
  }
  if (!lngLat) return null;
  return normalizeEventLocationPoint({
    provider: 'mapbox',
    sourceMode,
    providerPlaceId: '',
    location: lngLat,
    nameI18n: { zh: '', en: '' },
    addressI18n: { zh: '', en: '' },
    formattedAddressI18n: { zh: '', en: '' },
    city: '',
    district: '',
    province: '',
    countryCode: '',
    providerMeta: null,
    i18nPending: true,
    selectedAt: new Date().toISOString(),
  });
}

async function mapboxLocateCurrentPosition() {
  if (!navigator?.geolocation) {
    throw new Error('当前浏览器不支持定位能力');
  }
  const point = await new Promise((resolve, reject) => {
    navigator.geolocation.getCurrentPosition(
      (pos) => {
        const lng = Number(pos?.coords?.longitude);
        const lat = Number(pos?.coords?.latitude);
        if (!Number.isFinite(lng) || !Number.isFinite(lat)) {
          reject(new Error('定位成功但坐标无效'));
          return;
        }
        resolve({ lng, lat });
      },
      (error) => {
        const msg = mapboxText(error?.message || '');
        reject(new Error(msg || '定位失败，请检查浏览器定位权限'));
      },
      { enableHighAccuracy: true, timeout: 12000, maximumAge: 30000 }
    );
  });
  const resolved = await mapboxReverseGeocodeByPoint(point, { sourceMode: 'my_location' }).catch(() => null);
  if (resolved) return resolved;
  return normalizeEventLocationPoint({
    provider: 'mapbox',
    sourceMode: 'my_location',
    providerPlaceId: '',
    location: point,
    nameI18n: { zh: '我的位置', en: 'My Location' },
    addressI18n: { zh: '我的位置', en: 'My Location' },
    formattedAddressI18n: { zh: '我的位置', en: 'My Location' },
    city: '',
    district: '',
    province: '',
    countryCode: '',
    providerMeta: null,
    i18nPending: false,
    selectedAt: new Date().toISOString(),
  });
}

async function mapboxTryEnrichLocationPointEnglish(point) {
  const src = point && typeof point === 'object' ? point : null;
  if (!src || !src.location) return src;
  const resolved = await mapboxReverseGeocodeByPoint(src.location, { sourceMode: src.sourceMode || 'manual_search' }).catch(() => null);
  if (!resolved) return src;
  const merged = normalizeEventLocationPoint({
    ...src,
    provider: 'mapbox',
    nameI18n: {
      zh: mapboxText(src?.nameI18n?.zh || resolved?.nameI18n?.zh),
      en: mapboxText(src?.nameI18n?.en || resolved?.nameI18n?.en),
    },
    addressI18n: {
      zh: mapboxText(src?.addressI18n?.zh || resolved?.addressI18n?.zh),
      en: mapboxText(src?.addressI18n?.en || resolved?.addressI18n?.en),
    },
    formattedAddressI18n: {
      zh: mapboxText(src?.formattedAddressI18n?.zh || resolved?.formattedAddressI18n?.zh),
      en: mapboxText(src?.formattedAddressI18n?.en || resolved?.formattedAddressI18n?.en),
    },
    city: mapboxText(src?.city || resolved?.city),
    district: mapboxText(src?.district || resolved?.district),
    province: mapboxText(src?.province || resolved?.province),
    countryCode: mapboxText(src?.countryCode || resolved?.countryCode),
    providerPlaceId: mapboxText(src?.providerPlaceId || resolved?.providerPlaceId),
    providerMeta: src?.providerMeta || resolved?.providerMeta || null,
    i18nPending: false,
  });
  return merged || src;
}
