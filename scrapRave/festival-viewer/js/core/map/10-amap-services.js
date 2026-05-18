// Core map services (search/regeo/geolocation wrappers)
function toAmapLngLatPoint(raw) {
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
    raw.lng ?? raw.lon ?? raw.longitude ?? (typeof raw.getLng === 'function' ? raw.getLng() : undefined)
  );
  const lat = Number(
    raw.lat ?? raw.latitude ?? (typeof raw.getLat === 'function' ? raw.getLat() : undefined)
  );
  if (!Number.isFinite(lng) || !Number.isFinite(lat)) return null;
  return { lng, lat };
}

function amapText(value) {
  return String(value || '').trim();
}

function normalizeAmapPoi(poi, sourceMode = 'manual_search') {
  const location = toAmapLngLatPoint(poi?.location || { lng: poi?.lng, lat: poi?.lat }) || null;
  if (!location) return null;
  const poiId = amapText(poi?.id || poi?.uid);
  const adcode = amapText(poi?.adcode);
  const nameZh = amapText(poi?.name);
  const addrZh = amapText(poi?.address || poi?.addr);
  const formattedZh = amapText(poi?.pname) || amapText(poi?.cityname) || amapText(poi?.adname)
    ? [amapText(poi?.pname), amapText(poi?.cityname), amapText(poi?.adname), addrZh].filter(Boolean).join('')
    : addrZh;
  return {
    provider: 'amap',
    sourceMode,
    providerPlaceId: poiId || '',
    // Legacy alias: retained for existing AMap modal/detail code.
    poiId,
    location,
    nameI18n: { zh: nameZh, en: nameZh },
    addressI18n: { zh: addrZh, en: addrZh },
    formattedAddressI18n: { zh: formattedZh || addrZh, en: formattedZh || addrZh },
    // Legacy alias: retained for existing AMap modal/detail code.
    adcode,
    city: amapText(poi?.cityname || poi?.city || ''),
    district: amapText(poi?.adname || ''),
    province: amapText(poi?.pname || ''),
    countryCode: 'CHN',
    providerMeta: {
      amap: {
        poiId: poiId || '',
        adcode: adcode || '',
      },
    },
    i18nPending: true,
    selectedAt: new Date().toISOString(),
  };
}

function normalizeAmapRegeo(result, point, sourceMode = 'pin_drag') {
  const location = toAmapLngLatPoint(point) || null;
  if (!location) return null;
  const regeocode = result && typeof result === 'object' ? (result.regeocode || {}) : {};
  const comp = regeocode.addressComponent || {};
  const formatted = amapText(regeocode.formattedAddress);
  const district = amapText(comp.district || '');
  const township = amapText(comp.township || '');
  const city = amapText(Array.isArray(comp.city) ? comp.city[0] : comp.city || '');
  const province = amapText(comp.province || '');
  const detailZh = [district, township].filter(Boolean).join('');
  return {
    provider: 'amap',
    sourceMode,
    providerPlaceId: '',
    poiId: '',
    location,
    nameI18n: { zh: formatted || detailZh || `${location.lng},${location.lat}`, en: formatted || detailZh || `${location.lng},${location.lat}` },
    addressI18n: { zh: detailZh || formatted, en: detailZh || formatted },
    formattedAddressI18n: { zh: formatted || detailZh, en: formatted || detailZh },
    adcode: amapText(comp.adcode || ''),
    city,
    district,
    province,
    countryCode: 'CHN',
    providerMeta: {
      amap: {
        poiId: '',
        adcode: amapText(comp.adcode || ''),
      },
    },
    i18nPending: true,
    selectedAt: new Date().toISOString(),
  };
}

function amapLocationPointFromMapClickEvent(clickEvent, sourceMode = 'map_click') {
  const evt = clickEvent && typeof clickEvent === 'object' ? clickEvent : {};
  const point = toAmapLngLatPoint(evt?.lnglat || evt?.location || evt?.position || evt?.lngLat || null) || null;
  const poiFromObject = (evt?.poi && typeof evt.poi === 'object')
    ? evt.poi
    : ((evt?.poiinfo && typeof evt.poiinfo === 'object') ? evt.poiinfo : null);
  const hasTopLevelPoi = !!(
    String(evt?.id || '').trim()
    || String(evt?.name || '').trim()
    || String(evt?.address || '').trim()
  );
  const poiFromTopLevel = hasTopLevelPoi
    ? {
      id: String(evt?.id || '').trim(),
      name: String(evt?.name || '').trim(),
      address: String(evt?.address || '').trim(),
      location: point || null,
    }
    : null;
  const poiRaw = poiFromObject || poiFromTopLevel;
  if (poiRaw) {
    const poi = { ...poiRaw };
    if (!poi.id && poi.uid) poi.id = poi.uid;
    if (!poi.name && poi.poiname) poi.name = poi.poiname;
    if (!poi.address && poi.address2) poi.address = poi.address2;
    if (!poi.location && point) {
      poi.location = point;
    }
    const normalizedPoi = normalizeAmapPoi(poi, sourceMode);
    if (normalizedPoi) return normalizedPoi;
  }
  if (!point) return null;
  return {
    provider: 'amap',
    sourceMode,
    providerPlaceId: '',
    poiId: '',
    location: point,
    nameI18n: { zh: '', en: '' },
    addressI18n: { zh: '', en: '' },
    formattedAddressI18n: { zh: '', en: '' },
    adcode: '',
    city: '',
    district: '',
    province: '',
    countryCode: '',
    providerMeta: null,
    i18nPending: true,
    selectedAt: new Date().toISOString(),
  };
}

async function amapSearchPlacesByKeyword(keyword, options = {}) {
  const q = amapText(keyword);
  if (!q) return [];
  const AMap = await ensureAmapPlugins(['AMap.PlaceSearch']);
  const city = amapText(options.city || '');
  const citylimit = !!options.citylimit;
  const pageSize = Number.isFinite(Number(options.pageSize)) ? Number(options.pageSize) : 20;
  return await new Promise((resolve) => {
    const placeSearch = new AMap.PlaceSearch({
      city: city || '全国',
      citylimit,
      pageSize: Math.max(1, Math.min(50, pageSize)),
      extensions: 'all',
    });
    placeSearch.search(q, (status, result) => {
      if (status !== 'complete') {
        resolve([]);
        return;
      }
      const list = Array.isArray(result?.poiList?.pois) ? result.poiList.pois : [];
      const rows = list.map((poi) => normalizeAmapPoi(poi, options.sourceMode || 'manual_search')).filter(Boolean);
      resolve(rows);
    });
  });
}

async function amapSearchNearbyByPoint(point, options = {}) {
  const target = toAmapLngLatPoint(point);
  if (!target) return [];
  const AMap = await ensureAmapPlugins(['AMap.PlaceSearch']);
  const keyword = amapText(options.keyword || '');
  const radius = Number.isFinite(Number(options.radius)) ? Number(options.radius) : 800;
  return await new Promise((resolve) => {
    const placeSearch = new AMap.PlaceSearch({
      city: amapText(options.city || '全国'),
      citylimit: false,
      pageSize: 20,
      extensions: 'all',
    });
    placeSearch.searchNearBy(keyword || '', [target.lng, target.lat], Math.max(50, Math.min(5000, radius)), (status, result) => {
      if (status !== 'complete') {
        resolve([]);
        return;
      }
      const list = Array.isArray(result?.poiList?.pois) ? result.poiList.pois : [];
      const rows = list.map((poi) => normalizeAmapPoi(poi, options.sourceMode || 'pin_drag')).filter(Boolean);
      resolve(rows);
    });
  });
}

async function amapGetPoiDetailsById(poiId) {
  const id = amapText(poiId);
  if (!id) return null;
  const AMap = await ensureAmapPlugins(['AMap.PlaceSearch']);
  return await new Promise((resolve) => {
    const placeSearch = new AMap.PlaceSearch({
      pageSize: 1,
      extensions: 'all',
    });
    placeSearch.getDetails(id, (status, result) => {
      if (status !== 'complete') {
        resolve(null);
        return;
      }
      const list = Array.isArray(result?.poiList?.pois) ? result.poiList.pois : [];
      resolve(list[0] || null);
    });
  });
}

async function amapReverseGeocodeByPoint(point) {
  const target = toAmapLngLatPoint(point);
  if (!target) return null;
  const AMap = await ensureAmapPlugins(['AMap.Geocoder']);
  return await new Promise((resolve) => {
    const geocoder = new AMap.Geocoder({
      radius: 1000,
      extensions: 'all',
    });
    geocoder.getAddress([target.lng, target.lat], (status, result) => {
      if (status !== 'complete') {
        resolve(null);
        return;
      }
      resolve(normalizeAmapRegeo(result, target, 'pin_drag'));
    });
  });
}

async function amapLocateCurrentPosition() {
  const AMap = await ensureAmapPlugins(['AMap.Geolocation']);
  return await new Promise((resolve, reject) => {
    const geolocation = new AMap.Geolocation({
      enableHighAccuracy: true,
      timeout: 12000,
      convert: true,
      showButton: false,
      showMarker: false,
      showCircle: false,
    });
    geolocation.getCurrentPosition((status, result) => {
      if (status !== 'complete') {
        reject(new Error('定位失败，请检查浏览器定位权限'));
        return;
      }
      const point = toAmapLngLatPoint(result?.position || { lng: result?.lng, lat: result?.lat });
      if (!point) {
        reject(new Error('定位成功但未返回有效坐标'));
        return;
      }
      resolve({
        provider: 'amap',
        sourceMode: 'my_location',
        providerPlaceId: '',
        poiId: '',
        location: point,
        nameI18n: { zh: '我的位置', en: 'My Location' },
        addressI18n: { zh: amapText(result?.formattedAddress || '我的位置'), en: amapText(result?.formattedAddress || 'My Location') },
        formattedAddressI18n: { zh: amapText(result?.formattedAddress || '我的位置'), en: amapText(result?.formattedAddress || 'My Location') },
        adcode: amapText(result?.addressComponent?.adcode || ''),
        city: amapText(result?.addressComponent?.city || ''),
        district: amapText(result?.addressComponent?.district || ''),
        province: amapText(result?.addressComponent?.province || ''),
        countryCode: 'CHN',
        providerMeta: {
          amap: {
            poiId: '',
            adcode: amapText(result?.addressComponent?.adcode || ''),
          },
        },
        i18nPending: true,
        selectedAt: new Date().toISOString(),
      });
    });
  });
}

async function amapTryEnrichLocationPointEnglish(point) {
  const src = point && typeof point === 'object' ? point : null;
  if (!src || !src.location) return src;
  const cfg = await getAmapRuntimeConfig(false).catch(() => null);
  const key = String(cfg?.jsApiKey || '').trim();
  if (!key) return src;
  const lng = Number(src?.location?.lng);
  const lat = Number(src?.location?.lat);
  if (!Number.isFinite(lng) || !Number.isFinite(lat)) return src;
  const base = JSON.parse(JSON.stringify(src));
  try {
    const qs = new URLSearchParams({
      key,
      location: `${lng},${lat}`,
      extensions: 'base',
      radius: '1000',
      language: 'en',
      output: 'json',
    });
    const resp = await fetch(`https://restapi.amap.com/v3/geocode/regeo?${qs.toString()}`);
    const data = await resp.json().catch(() => ({}));
    const addrEn = amapText(data?.regeocode?.formatted_address || '');
    const poiNameEn = amapText((Array.isArray(data?.regeocode?.pois) ? data.regeocode.pois[0]?.name : '') || '');
    if (!addrEn && !poiNameEn) return base;
    base.nameI18n = base.nameI18n || {};
    base.addressI18n = base.addressI18n || {};
    base.formattedAddressI18n = base.formattedAddressI18n || {};
    if (poiNameEn && !amapText(base.nameI18n.en)) base.nameI18n.en = poiNameEn;
    if (!amapText(base.addressI18n.en)) base.addressI18n.en = addrEn;
    if (!amapText(base.formattedAddressI18n.en)) base.formattedAddressI18n.en = addrEn;
    if (amapText(base.nameI18n.en) || amapText(base.addressI18n.en) || amapText(base.formattedAddressI18n.en)) {
      base.i18nPending = false;
    }
    return base;
  } catch (_error) {
    return base;
  }
}
