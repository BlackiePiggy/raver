// Core map services (Geoapify wrappers)
function geoapifyText(value) {
  return String(value || '').trim();
}

function toGeoapifyLngLatPoint(raw) {
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
    ?? raw?.properties?.lon
  );
  const lat = Number(
    raw.lat
    ?? raw.latitude
    ?? raw?.center?.lat
    ?? raw?.center?.[1]
    ?? raw?.geometry?.coordinates?.[1]
    ?? raw?.properties?.lat
  );
  if (!Number.isFinite(lng) || !Number.isFinite(lat)) return null;
  return { lng, lat };
}

function geoapifyCountryCode3(value) {
  const text = geoapifyText(value).toUpperCase();
  if (text.length === 3) return text;
  if (text.length === 2) {
    if (text === 'CN') return 'CHN';
    if (text === 'US') return 'USA';
    if (text === 'GB') return 'GBR';
    return text;
  }
  return '';
}

function geoapifyBuildAddressFromFeature(feature) {
  const props = feature?.properties || {};
  const candidates = [
    props.formatted,
    props.address_line1,
    [props.address_line1, props.address_line2].filter(Boolean).join(', '),
    props.address_line2,
    feature?.place_name,
  ];
  for (const item of candidates) {
    const text = geoapifyText(item);
    if (text) return text;
  }
  return '';
}

function geoapifyResolvePlaceId(feature) {
  const props = feature?.properties || {};
  const raw = props.place_id
    || props.datasource?.raw?.place_id
    || props.datasource?.raw?.osm_id
    || feature?.id
    || '';
  return geoapifyText(raw);
}

function geoapifyResolveFeatureType(feature) {
  const props = feature?.properties || {};
  return geoapifyText(props.result_type || props.datasource?.sourcename || '');
}

function normalizeGeoapifyFeature(feature, sourceMode = 'manual_search', extra = {}) {
  const location = toGeoapifyLngLatPoint(feature);
  if (!location) return null;
  const props = feature?.properties || {};
  const placeId = geoapifyResolvePlaceId(feature);
  const featureType = geoapifyResolveFeatureType(feature);
  const nameSeed = geoapifyText(
    props.name
    || props.address_line1
    || props.formatted
    || extra.nameZh
    || ''
  );
  const nameZh = geoapifyText(extra.nameZh || nameSeed);
  const nameEn = geoapifyText(extra.nameEn || props.name || nameZh);
  const addrSeed = geoapifyBuildAddressFromFeature(feature);
  const addrZh = geoapifyText(extra.addressZh || addrSeed);
  const addrEn = geoapifyText(extra.addressEn || props.formatted || addrZh);
  const formattedZh = geoapifyText(extra.formattedZh || props.formatted || addrZh);
  const formattedEn = geoapifyText(extra.formattedEn || props.formatted || addrEn || formattedZh);
  const city = geoapifyText(props.city || props.county || props.state_district || '');
  const district = geoapifyText(props.district || props.suburb || props.neighbourhood || '');
  const province = geoapifyText(props.state || props.region || '');
  const countryCode = geoapifyCountryCode3(props.country_code || props.countryCode || props.country_code_iso3 || '');
  return {
    provider: 'geoapify',
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
      geoapify: {
        placeId: placeId || '',
        featureType: featureType || '',
      },
    },
    i18nPending: !(geoapifyText(nameEn) && geoapifyText(formattedEn)),
    selectedAt: new Date().toISOString(),
  };
}

async function geoapifySearchOnce(query, options = {}) {
  const q = geoapifyText(query);
  if (!q) return [];
  await ensureGeoapifyLoaded();
  const cfg = await getGeoapifyRuntimeConfig(false).catch(() => null);
  const apiKey = geoapifyText(cfg?.apiKey || '');
  if (!apiKey) return [];
  const params = new URLSearchParams({
    text: q,
    apiKey,
    format: 'geojson',
    limit: String(Math.max(1, Math.min(20, Number(options.limit || 20) || 20))),
    lang: geoapifyText(options.language || 'zh'),
  });
  const coordinate = toGeoapifyLngLatPoint(options.coordinate || null);
  if (coordinate) params.set('bias', `proximity:${coordinate.lng},${coordinate.lat}`);
  const country = geoapifyText(options.country || '').toLowerCase();
  if (country) params.set('filter', `countrycode:${country.slice(0, 2)}`);
  const resp = await fetch(`https://api.geoapify.com/v1/geocode/search?${params.toString()}`);
  if (!resp.ok) return [];
  const data = await resp.json().catch(() => ({}));
  return Array.isArray(data?.features) ? data.features : [];
}

function geoapifyMergeSearchRows(primaryRows, enRows, sourceMode = 'manual_search') {
  const rows = [];
  const keyToIdx = new Map();
  const push = (feature, extra = {}) => {
    const normalized = normalizeGeoapifyFeature(feature, sourceMode, extra);
    if (!normalized) return;
    const key = `${normalized.location.lng.toFixed(6)},${normalized.location.lat.toFixed(6)}::${geoapifyText(normalized.providerPlaceId)}`;
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
      nameEn: geoapifyText(row?.properties?.name || ''),
      addressEn: geoapifyText(row?.properties?.formatted || ''),
      formattedEn: geoapifyText(row?.properties?.formatted || ''),
    });
  }
  return rows.slice(0, 20);
}

async function geoapifySearchPlacesByKeyword(keyword, options = {}) {
  const q = geoapifyText(keyword);
  if (!q) return [];
  const primaryRows = await geoapifySearchOnce(q, {
    language: geoapifyText(options.language || 'zh'),
    coordinate: options.coordinate || null,
    limit: options.limit || 20,
  }).catch(() => []);
  const enRows = await geoapifySearchOnce(q, {
    language: 'en',
    coordinate: options.coordinate || null,
    limit: options.limit || 20,
  }).catch(() => []);
  return geoapifyMergeSearchRows(primaryRows, enRows, geoapifyText(options.sourceMode || 'manual_search') || 'manual_search');
}

async function geoapifyReverseOnce(point, language = 'zh') {
  const target = toGeoapifyLngLatPoint(point);
  if (!target) return [];
  await ensureGeoapifyLoaded();
  const cfg = await getGeoapifyRuntimeConfig(false).catch(() => null);
  const apiKey = geoapifyText(cfg?.apiKey || '');
  if (!apiKey) return [];
  const params = new URLSearchParams({
    lat: String(target.lat),
    lon: String(target.lng),
    apiKey,
    format: 'geojson',
    lang: geoapifyText(language || 'zh'),
  });
  const resp = await fetch(`https://api.geoapify.com/v1/geocode/reverse?${params.toString()}`);
  if (!resp.ok) return [];
  const data = await resp.json().catch(() => ({}));
  return Array.isArray(data?.features) ? data.features : [];
}

async function geoapifyReverseGeocodeByPoint(point, options = {}) {
  const target = toGeoapifyLngLatPoint(point);
  if (!target) return null;
  const zhRows = await geoapifyReverseOnce(target, 'zh').catch(() => []);
  const enRows = await geoapifyReverseOnce(target, 'en').catch(() => []);
  const zhTop = zhRows[0] || null;
  const enTop = enRows[0] || null;
  if (!zhTop && !enTop) {
    return normalizeEventLocationPoint({
      provider: 'geoapify',
      sourceMode: geoapifyText(options.sourceMode || 'pin_drag') || 'pin_drag',
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
  const base = normalizeGeoapifyFeature(
    zhTop || enTop,
    geoapifyText(options.sourceMode || 'pin_drag') || 'pin_drag',
    {
      nameEn: geoapifyText(enTop?.properties?.name || ''),
      addressEn: geoapifyText(enTop?.properties?.formatted || ''),
      formattedEn: geoapifyText(enTop?.properties?.formatted || ''),
    }
  );
  return normalizeEventLocationPoint(base);
}

function geoapifyBuildNearbyQuery(point, regeo) {
  const p = normalizeEventLocationPoint(point);
  const r = normalizeEventLocationPoint(regeo);
  const parts = [
    geoapifyText(r?.nameI18n?.zh || r?.nameI18n?.en || ''),
    geoapifyText(r?.city || p?.city || ''),
    geoapifyText(r?.province || p?.province || ''),
  ].filter(Boolean);
  return parts.join(' ').trim();
}

async function geoapifySearchNearbyByPoint(point, options = {}) {
  const target = toGeoapifyLngLatPoint(point);
  if (!target) return [];
  await ensureGeoapifyLoaded();
  const cfg = await getGeoapifyRuntimeConfig(false).catch(() => null);
  const apiKey = geoapifyText(cfg?.apiKey || '');
  if (!apiKey) return [];
  const params = new URLSearchParams({
    apiKey,
    format: 'geojson',
    limit: String(Math.max(1, Math.min(20, Number(options.limit || 20) || 20))),
    filter: `circle:${target.lng},${target.lat},900`,
    bias: `proximity:${target.lng},${target.lat}`,
    categories: 'commercial,entertainment,catering,accommodation,tourism,sport,service,healthcare,education,public_transport',
  });
  const resp = await fetch(`https://api.geoapify.com/v2/places?${params.toString()}`);
  if (!resp.ok) return [];
  const data = await resp.json().catch(() => ({}));
  const rows = Array.isArray(data?.features) ? data.features : [];
  const out = [];
  for (const row of rows) {
    const normalized = normalizeGeoapifyFeature(row, geoapifyText(options.sourceMode || 'pin_drag') || 'pin_drag');
    if (!normalized) continue;
    out.push(normalized);
    if (out.length >= 20) break;
  }
  return out;
}

function geoapifyLocationPointFromMapClickEvent(evt, sourceMode = 'map_poi_click') {
  const feature = evt && typeof evt === 'object' ? (evt.feature || evt.poiFeature || null) : null;
  const lngLat = toGeoapifyLngLatPoint(evt?.lngLat || evt?.lnglat || evt?.location || null);
  if (feature) {
    const normalized = normalizeGeoapifyFeature(feature, sourceMode);
    if (normalized) return normalized;
  }
  if (!lngLat) return null;
  return normalizeEventLocationPoint({
    provider: 'geoapify',
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

async function geoapifyLocateCurrentPosition() {
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
        const msg = geoapifyText(error?.message || '');
        reject(new Error(msg || '定位失败，请检查浏览器定位权限'));
      },
      { enableHighAccuracy: true, timeout: 12000, maximumAge: 30000 }
    );
  });
  const resolved = await geoapifyReverseGeocodeByPoint(point, { sourceMode: 'my_location' }).catch(() => null);
  if (resolved) return resolved;
  return normalizeEventLocationPoint({
    provider: 'geoapify',
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

async function geoapifyTryEnrichLocationPointEnglish(point) {
  const src = point && typeof point === 'object' ? point : null;
  if (!src || !src.location) return src;
  const resolved = await geoapifyReverseGeocodeByPoint(src.location, { sourceMode: src.sourceMode || 'manual_search' }).catch(() => null);
  if (!resolved) return src;
  const merged = normalizeEventLocationPoint({
    ...src,
    provider: 'geoapify',
    nameI18n: {
      zh: geoapifyText(src?.nameI18n?.zh || resolved?.nameI18n?.zh),
      en: geoapifyText(src?.nameI18n?.en || resolved?.nameI18n?.en),
    },
    addressI18n: {
      zh: geoapifyText(src?.addressI18n?.zh || resolved?.addressI18n?.zh),
      en: geoapifyText(src?.addressI18n?.en || resolved?.addressI18n?.en),
    },
    formattedAddressI18n: {
      zh: geoapifyText(src?.formattedAddressI18n?.zh || resolved?.formattedAddressI18n?.zh),
      en: geoapifyText(src?.formattedAddressI18n?.en || resolved?.formattedAddressI18n?.en),
    },
    city: geoapifyText(src?.city || resolved?.city),
    district: geoapifyText(src?.district || resolved?.district),
    province: geoapifyText(src?.province || resolved?.province),
    countryCode: geoapifyText(src?.countryCode || resolved?.countryCode),
    providerPlaceId: geoapifyText(src?.providerPlaceId || resolved?.providerPlaceId),
    providerMeta: src?.providerMeta || resolved?.providerMeta || null,
    i18nPending: false,
  });
  return merged || src;
}
