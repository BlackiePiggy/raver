// Core map services (Apple MapKit JS wrappers)
function mapkitText(value) {
  return String(value || '').trim();
}

function toMapkitLngLatPoint(raw) {
  if (!raw) return null;
  if (Array.isArray(raw) && raw.length >= 2) {
    const lng = Number(raw[0]);
    const lat = Number(raw[1]);
    if (!Number.isFinite(lng) || !Number.isFinite(lat)) return null;
    return { lng, lat };
  }
  const lng = Number(raw.lng ?? raw.longitude ?? raw.lon ?? raw?.coordinate?.longitude);
  const lat = Number(raw.lat ?? raw.latitude ?? raw?.coordinate?.latitude);
  if (!Number.isFinite(lng) || !Number.isFinite(lat)) return null;
  return { lng, lat };
}

function mapkitResolvePlaceId(place) {
  const id = mapkitText(
    place?.id
    || place?.placeId
    || place?._id
    || place?.mapItemIdentifier
    || place?.identifier
    || place?.resultId
    || ''
  );
  return id;
}

function mapkitBuildAddressFromPlace(place) {
  const explicit = mapkitText(place?.formattedAddress || place?.address || place?.displayName || '');
  if (explicit) return explicit;
  const row = [
    mapkitText(place?.subThoroughfare || ''),
    mapkitText(place?.thoroughfare || ''),
    mapkitText(place?.subLocality || ''),
    mapkitText(place?.locality || place?.city || ''),
    mapkitText(place?.administrativeArea || place?.state || ''),
    mapkitText(place?.country || place?.countryName || ''),
  ].filter(Boolean);
  return row.join(', ');
}

function normalizeMapkitPlace(place, sourceMode = 'manual_search', extra = {}) {
  const location = toMapkitLngLatPoint(place?.location || place?.coordinate || place);
  if (!location) return null;
  const nameZh = mapkitText(place?.name || place?.title || place?.displayName || '');
  const addrZh = mapkitBuildAddressFromPlace(place);
  const city = mapkitText(place?.locality || place?.city || '');
  const district = mapkitText(place?.subLocality || place?.subAdministrativeArea || '');
  const province = mapkitText(place?.administrativeArea || place?.state || '');
  const countryCode = mapkitText(place?.countryCode || '').toUpperCase();
  const mapItemIdentifier = mapkitResolvePlaceId(place);
  return {
    provider: 'mapkit',
    sourceMode,
    providerPlaceId: mapItemIdentifier,
    location,
    nameI18n: {
      zh: nameZh,
      en: mapkitText(extra.nameEn || nameZh),
    },
    addressI18n: {
      zh: addrZh,
      en: mapkitText(extra.addressEn || addrZh),
    },
    formattedAddressI18n: {
      zh: addrZh,
      en: mapkitText(extra.formattedEn || extra.addressEn || addrZh),
    },
    city,
    district,
    province,
    countryCode,
    providerMeta: {
      mapkit: {
        mapItemIdentifier: mapItemIdentifier || '',
      },
    },
    i18nPending: !mapkitText(extra.formattedEn || extra.addressEn || ''),
    selectedAt: new Date().toISOString(),
  };
}

function mapkitCoordinateToObj(coord) {
  if (!coord) return null;
  const lat = Number(coord.latitude);
  const lng = Number(coord.longitude);
  if (!Number.isFinite(lat) || !Number.isFinite(lng)) return null;
  return { lng, lat };
}

function mapkitToCoordinate(point) {
  const p = toMapkitLngLatPoint(point);
  if (!p) return null;
  if (!window.mapkit || !window.mapkit.Coordinate) return null;
  return new window.mapkit.Coordinate(p.lat, p.lng);
}

function mapkitSearchOnce(query, options = {}) {
  const q = mapkitText(query);
  if (!q) return Promise.resolve([]);
  return ensureMapkitLoaded().then((mapkit) => new Promise((resolve) => {
    const searchOptions = {
      language: mapkitText(options.language || ''),
      includePointsOfInterest: true,
      includeAddresses: true,
    };
    if (searchOptions.language === '') delete searchOptions.language;
    if (options.coordinate) {
      const center = mapkitToCoordinate(options.coordinate);
      if (center && mapkit.CoordinateSpan && mapkit.CoordinateRegion) {
        searchOptions.region = new mapkit.CoordinateRegion(center, new mapkit.CoordinateSpan(0.2, 0.2));
      }
    }
    const search = new mapkit.Search(searchOptions);
    search.search(q, (error, data) => {
      if (error) {
        resolve([]);
        return;
      }
      const places = Array.isArray(data?.places)
        ? data.places
        : (Array.isArray(data?.results) ? data.results : []);
      resolve(places);
    });
  }));
}

function mergeMapkitSearchRows(primaryRows, enRows, sourceMode) {
  const byCoordKey = new Map();
  const rows = [];
  const pushRow = (row) => {
    const normalized = normalizeMapkitPlace(row, sourceMode);
    if (!normalized) return;
    const key = `${normalized.location.lng.toFixed(6)},${normalized.location.lat.toFixed(6)}`;
    if (byCoordKey.has(key)) return;
    byCoordKey.set(key, normalized);
    rows.push(normalized);
  };
  for (const row of primaryRows || []) pushRow(row);
  for (const row of enRows || []) {
    const enPoint = normalizeMapkitPlace(row, sourceMode);
    if (!enPoint) continue;
    const key = `${enPoint.location.lng.toFixed(6)},${enPoint.location.lat.toFixed(6)}`;
    if (!byCoordKey.has(key)) continue;
    const base = byCoordKey.get(key);
    base.nameI18n = base.nameI18n || {};
    base.addressI18n = base.addressI18n || {};
    base.formattedAddressI18n = base.formattedAddressI18n || {};
    if (mapkitText(enPoint.nameI18n?.en)) base.nameI18n.en = enPoint.nameI18n.en;
    if (mapkitText(enPoint.addressI18n?.en)) base.addressI18n.en = enPoint.addressI18n.en;
    if (mapkitText(enPoint.formattedAddressI18n?.en)) base.formattedAddressI18n.en = enPoint.formattedAddressI18n.en;
    if (mapkitText(base.nameI18n?.en) || mapkitText(base.addressI18n?.en) || mapkitText(base.formattedAddressI18n?.en)) {
      base.i18nPending = false;
    }
  }
  return rows;
}

async function mapkitSearchPlacesByKeyword(keyword, options = {}) {
  const q = mapkitText(keyword);
  if (!q) return [];
  const primaryRows = await mapkitSearchOnce(q, {
    language: mapkitText(options.language || 'zh-CN'),
    coordinate: options.coordinate || null,
  });
  const enRows = await mapkitSearchOnce(q, {
    language: 'en-US',
    coordinate: options.coordinate || null,
  }).catch(() => []);
  const sourceMode = mapkitText(options.sourceMode || 'manual_search') || 'manual_search';
  return mergeMapkitSearchRows(primaryRows, enRows, sourceMode).slice(0, 20);
}

function mapkitReverseLookupOnce(point, language = 'zh-CN') {
  const target = toMapkitLngLatPoint(point);
  if (!target) return Promise.resolve(null);
  return ensureMapkitLoaded().then((mapkit) => new Promise((resolve) => {
    const geocoder = new mapkit.Geocoder({ language });
    geocoder.reverseLookup(new mapkit.Coordinate(target.lat, target.lng), (error, data) => {
      if (error) {
        resolve(null);
        return;
      }
      const places = Array.isArray(data?.results)
        ? data.results
        : (Array.isArray(data?.places) ? data.places : []);
      resolve(places[0] || null);
    });
  }));
}

async function mapkitReverseGeocodeByPoint(point, options = {}) {
  const target = toMapkitLngLatPoint(point);
  if (!target) return null;
  const zhPlace = await mapkitReverseLookupOnce(target, 'zh-CN');
  const enPlace = await mapkitReverseLookupOnce(target, 'en-US').catch(() => null);
  const sourceMode = mapkitText(options.sourceMode || 'pin_drag') || 'pin_drag';
  const normalized = normalizeMapkitPlace(
    zhPlace || target,
    sourceMode,
    {
      nameEn: mapkitText(enPlace?.name || enPlace?.title || ''),
      addressEn: mapkitBuildAddressFromPlace(enPlace || {}),
      formattedEn: mapkitBuildAddressFromPlace(enPlace || {}),
    }
  );
  if (!normalized) return null;
  if (!zhPlace) {
    normalized.nameI18n = normalized.nameI18n || { zh: '', en: '' };
    normalized.addressI18n = normalized.addressI18n || { zh: '', en: '' };
    normalized.formattedAddressI18n = normalized.formattedAddressI18n || { zh: '', en: '' };
    const fallback = `${target.lng.toFixed(6)},${target.lat.toFixed(6)}`;
    if (!mapkitText(normalized.nameI18n.zh)) normalized.nameI18n.zh = fallback;
    if (!mapkitText(normalized.addressI18n.zh)) normalized.addressI18n.zh = fallback;
    if (!mapkitText(normalized.formattedAddressI18n.zh)) normalized.formattedAddressI18n.zh = fallback;
  }
  return normalized;
}

function mapkitLocationPointFromMapCoordinate(raw, sourceMode = 'map_poi_click') {
  const point = toMapkitLngLatPoint(raw);
  if (!point) return null;
  return {
    provider: 'mapkit',
    sourceMode,
    providerPlaceId: '',
    location: point,
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
  };
}

async function mapkitLocateCurrentPosition() {
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
        const msg = String(error?.message || '').trim();
        reject(new Error(msg || '定位失败，请检查浏览器定位权限'));
      },
      { enableHighAccuracy: true, timeout: 12000, maximumAge: 30000 }
    );
  });
  const resolved = await mapkitReverseGeocodeByPoint(point, { sourceMode: 'my_location' });
  if (resolved) return resolved;
  return {
    provider: 'mapkit',
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
  };
}

async function mapkitTryEnrichLocationPointEnglish(point) {
  const src = point && typeof point === 'object' ? point : null;
  if (!src || !src.location) return src;
  const resolved = await mapkitReverseGeocodeByPoint(src.location, { sourceMode: src.sourceMode || 'manual_search' });
  if (!resolved) return src;
  const merged = normalizeEventLocationPoint({
    ...src,
    nameI18n: {
      zh: mapkitText(src?.nameI18n?.zh || resolved?.nameI18n?.zh),
      en: mapkitText(src?.nameI18n?.en || resolved?.nameI18n?.en),
    },
    addressI18n: {
      zh: mapkitText(src?.addressI18n?.zh || resolved?.addressI18n?.zh),
      en: mapkitText(src?.addressI18n?.en || resolved?.addressI18n?.en),
    },
    formattedAddressI18n: {
      zh: mapkitText(src?.formattedAddressI18n?.zh || resolved?.formattedAddressI18n?.zh),
      en: mapkitText(src?.formattedAddressI18n?.en || resolved?.formattedAddressI18n?.en),
    },
    city: mapkitText(src?.city || resolved?.city),
    district: mapkitText(src?.district || resolved?.district),
    province: mapkitText(src?.province || resolved?.province),
    countryCode: mapkitText(src?.countryCode || resolved?.countryCode),
    providerPlaceId: mapkitText(src?.providerPlaceId || resolved?.providerPlaceId),
    providerMeta: src?.providerMeta || resolved?.providerMeta || null,
    i18nPending: false,
  });
  return merged || src;
}
