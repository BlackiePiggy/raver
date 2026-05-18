// Event location picker provider bridge (AMap + MapKit + Mapbox + Geoapify)
(function initEventLocationProviderBridge() {
  if (typeof window.openEventLocationPickerModal !== 'function') return;
  if (window.__EVENT_LOCATION_PROVIDER_BRIDGE_READY__) return;
  window.__EVENT_LOCATION_PROVIDER_BRIDGE_READY__ = true;

  const original = {
    open: window.openEventLocationPickerModal,
    close: window.closeEventLocationPickerModal,
    ensureMapReady: window.ensureEventLocationMapReady,
    resolveByPoint: window.eventLocationResolveByPoint,
    searchByKeyword: window.eventLocationSearchByKeyword,
    locateMe: window.eventLocationLocateMe,
    setPin: window.eventLocationSetPin,
    syncPinMode: window.eventLocationSyncPinMarkerMode,
    updatePoiMarker: window.eventLocationUpdatePoiMarker,
    removePoiMarker: window.eventLocationRemovePoiMarker,
    updateAnchorMarker: window.eventLocationUpdateAnchorMarker,
    removeAnchorMarker: window.eventLocationRemoveAnchorMarker,
    loadPoiDetail: window.eventLocationLoadPoiDetailsIntoPanel,
    loadViewAnchorDetail: window.eventLocationLoadViewAnchorDetailsIntoPanel,
  };

  const mapkitState = {
    provider: 'amap',
    map: null,
    wrapperMap: null,
    pinAnnotation: null,
    poiAnnotation: null,
    anchorAnnotation: null,
    myAnnotation: null,
    moveTimer: null,
    boundEvents: false,
  };

  const mapboxState = {
    provider: 'amap',
    map: null,
    wrapperMap: null,
    pinMarker: null,
    poiMarker: null,
    anchorMarker: null,
    myMarker: null,
    moveTimer: null,
  };

  const geoapifyState = {
    provider: 'amap',
    map: null,
    wrapperMap: null,
    pinMarker: null,
    poiMarker: null,
    anchorMarker: null,
    myMarker: null,
    moveTimer: null,
    suspendMoveResolveUntil: 0,
  };

  function mapkitSafeText(value) {
    return String(value || '').trim();
  }

  function mapboxSafeText(value) {
    return String(value || '').trim();
  }

  function geoapifySafeText(value) {
    return String(value || '').trim();
  }

  function mapkitGetCenter() {
    const center = mapkitState.map?.center;
    const lat = Number(center?.latitude);
    const lng = Number(center?.longitude);
    if (!Number.isFinite(lat) || !Number.isFinite(lng)) return null;
    return { lng, lat };
  }

  function mapkitPanTo(point, animated = true) {
    const target = toMapkitLngLatPoint(point);
    if (!target || !mapkitState.map || !window.mapkit) return;
    const coord = new window.mapkit.Coordinate(target.lat, target.lng);
    if (animated && typeof mapkitState.map.setCenterAnimated === 'function') {
      mapkitState.map.setCenterAnimated(coord);
      return;
    }
    mapkitState.map.center = coord;
  }

  function mapkitSetRegionIfNeeded(point) {
    const target = toMapkitLngLatPoint(point);
    if (!target || !mapkitState.map || !window.mapkit) return;
    const coord = new window.mapkit.Coordinate(target.lat, target.lng);
    if (window.mapkit.CoordinateRegion && window.mapkit.CoordinateSpan) {
      mapkitState.map.region = new window.mapkit.CoordinateRegion(
        coord,
        new window.mapkit.CoordinateSpan(0.18, 0.18)
      );
      return;
    }
    mapkitState.map.center = coord;
  }

  function mapkitExtractEventCoordinate(evt) {
    if (!evt || !mapkitState.map) return null;
    const direct = mapkitCoordinateToObj(evt.coordinate || evt.pointOnMap || evt.coordinatePoint || null);
    if (direct) return direct;

    const onPage = evt.pointOnPage;
    if (!onPage || typeof mapkitState.map.convertPointOnPageToCoordinate !== 'function') return null;

    try {
      const maybe = mapkitState.map.convertPointOnPageToCoordinate(onPage);
      const converted = mapkitCoordinateToObj(maybe);
      if (converted) return converted;
    } catch (_error) {
      // ignore
    }

    if (typeof DOMPoint === 'function') {
      try {
        const dp = new DOMPoint(Number(onPage.x || 0), Number(onPage.y || 0));
        const maybe = mapkitState.map.convertPointOnPageToCoordinate(dp);
        const converted = mapkitCoordinateToObj(maybe);
        if (converted) return converted;
      } catch (_error) {
        // ignore
      }
    }
    return null;
  }

  function mapkitRemoveAnnotation(refKey) {
    const ann = mapkitState[refKey];
    if (!ann || !mapkitState.map) return;
    try {
      mapkitState.map.removeAnnotation(ann);
    } catch (_error) {
      // ignore
    }
    mapkitState[refKey] = null;
  }

  function mapkitCreateAnnotation(point, options = {}) {
    const p = normalizeEventLocationPoint(point);
    if (!p || !window.mapkit) return null;
    const coordinate = new window.mapkit.Coordinate(p.location.lat, p.location.lng);
    return new window.mapkit.MarkerAnnotation(coordinate, {
      title: mapkitSafeText(options.title || p.nameI18n?.zh || p.nameI18n?.en || ''),
      subtitle: mapkitSafeText(options.subtitle || p.formattedAddressI18n?.zh || p.formattedAddressI18n?.en || ''),
      color: mapkitSafeText(options.color || '#3b82f6') || '#3b82f6',
      glyphText: mapkitSafeText(options.glyphText || ''),
    });
  }

  function mapkitSetAnnotation(refKey, point, options = {}) {
    mapkitRemoveAnnotation(refKey);
    const ann = mapkitCreateAnnotation(point, options);
    if (!ann || !mapkitState.map) return;
    mapkitState.map.addAnnotation(ann);
    mapkitState[refKey] = ann;
  }

  function mapkitMergeUniqueRows(rows) {
    const out = [];
    const pushUnique = (item) => {
      const normalized = normalizeEventLocationPoint(item);
      if (!normalized) return;
      const existsIdx = out.findIndex((row) => eventLocationIsSamePoint(row, normalized));
      if (existsIdx >= 0) {
        out[existsIdx] = eventLocationMergePoints(out[existsIdx], normalized);
        return;
      }
      out.push(normalized);
    };
    for (const item of rows || []) {
      pushUnique(item);
      if (out.length >= 20) break;
    }
    return out.slice(0, 20);
  }

  function mapkitBuildNearbyQuery(point, regeo) {
    const p = normalizeEventLocationPoint(point);
    const r = normalizeEventLocationPoint(regeo);
    const parts = [
      mapkitSafeText(r?.nameI18n?.zh || r?.nameI18n?.en || ''),
      mapkitSafeText(r?.city || p?.city || ''),
      mapkitSafeText(r?.province || p?.province || ''),
    ].filter(Boolean);
    if (!parts.length) return '';
    return parts.join(' ');
  }

  async function mapkitEnsureMapReady(initialPoint = null) {
    const { mapWrap } = eventLocationModalEls();
    if (!mapWrap) throw new Error('地图容器不存在');
    await ensureMapkitLoaded();
    if (!window.mapkit || !window.mapkit.Map) {
      throw new Error('Apple MapKit 未正确初始化');
    }

    if (!mapkitState.map) {
      mapWrap.innerHTML = '';
      mapkitState.map = new window.mapkit.Map(mapWrap);
      mapkitSetRegionIfNeeded({ lng: 121.4737, lat: 31.2304 });

      mapkitState.map.addEventListener('single-tap', async (evt) => {
        if (!eventLocationPickerState.open || eventLocationIsViewMode()) return;
        const coord = mapkitExtractEventCoordinate(evt);
        if (!coord) return;
        const point = normalizeEventLocationPoint(
          mapkitLocationPointFromMapCoordinate(coord, 'map_poi_click')
        );
        if (!point) return;
        const pointKey = `${point.location.lng.toFixed(6)},${point.location.lat.toFixed(6)}`;
        const now = Date.now();
        if (eventLocationLastMapPickKey === pointKey && (now - eventLocationLastMapPickAt) < 180) return;
        eventLocationLastMapPickKey = pointKey;
        eventLocationLastMapPickAt = now;
        eventLocationSetStatus('已选择地图地点，正在解析候选...', false);
        await eventLocationPreviewPoint(point, { withPan: false, loadDetail: true, prepend: true });
        await eventLocationResolveByPoint(point, 'map_poi_click', { keepFirstPoint: true });
      });

      mapkitState.map.addEventListener('region-change-end', async () => {
        if (!eventLocationPickerState.open || eventLocationIsViewMode()) return;
        if (mapkitState.moveTimer) clearTimeout(mapkitState.moveTimer);
        mapkitState.moveTimer = setTimeout(async () => {
          const center = mapkitGetCenter();
          if (!center) return;
          const point = normalizeEventLocationPoint(
            mapkitLocationPointFromMapCoordinate(center, 'pin_drag')
          );
          if (!point) return;
          eventLocationSetPin(point, false);
          await eventLocationResolveByPoint(point, 'pin_drag');
        }, 260);
      });
    }

    mapkitState.wrapperMap = {
      getCenter() {
        return mapkitGetCenter();
      },
      panTo(position) {
        const p = Array.isArray(position)
          ? { lng: Number(position[0]), lat: Number(position[1]) }
          : toMapkitLngLatPoint(position);
        if (!p) return;
        mapkitPanTo(p, true);
      },
      resize() {
        // MapKit JS auto-resizes with container; no-op for compatibility.
      },
    };
    eventLocationMap = mapkitState.wrapperMap;
    eventLocationPinMarker = null;
    if (initialPoint?.location) {
      mapkitPanTo(initialPoint.location, true);
      eventLocationSetPin(initialPoint, true);
    }
  }

  function mapkitSyncPinMode() {
    if (eventLocationIsViewMode()) {
      mapkitRemoveAnnotation('pinAnnotation');
      return;
    }
    const preview = normalizeEventLocationPoint(eventLocationPickerState.previewPoint || eventLocationPickerState.selectedPoint);
    if (preview) {
      mapkitSetAnnotation('pinAnnotation', preview, { color: '#f97316', glyphText: 'P' });
    }
  }

  function mapkitSetPin(point, withPan = false) {
    const p = normalizeEventLocationPoint(point);
    if (!p || !mapkitState.map) return;
    if (!eventLocationIsViewMode()) {
      mapkitSetAnnotation('pinAnnotation', p, { color: '#f97316', glyphText: 'P' });
    }
    if (withPan) mapkitPanTo(p.location, true);
  }

  function mapkitUpdatePoiMarker(point) {
    const p = normalizeEventLocationPoint(point);
    if (!p || !mapkitState.map || eventLocationIsViewMode()) return;
    mapkitSetAnnotation('poiAnnotation', p, { color: '#3b82f6', glyphText: 'POI' });
  }

  function mapkitRemovePoiMarker() {
    mapkitRemoveAnnotation('poiAnnotation');
  }

  function mapkitUpdateAnchorMarker(point) {
    const p = normalizeEventLocationPoint(point);
    if (!p || !mapkitState.map) return;
    mapkitSetAnnotation('anchorAnnotation', p, { color: '#00f5c8', glyphText: 'A' });
  }

  function mapkitRemoveAnchorMarker() {
    mapkitRemoveAnnotation('anchorAnnotation');
  }

  async function mapkitResolveByPoint(point, sourceMode = 'pin_drag', options = {}) {
    if (eventLocationIsViewMode()) return;
    const p = normalizeEventLocationPoint(point);
    if (!p) return;
    const keepFirstPoint = !!options.keepFirstPoint;
    const key = `${p.location.lng.toFixed(6)},${p.location.lat.toFixed(6)}`;
    if (eventLocationLastResolvedPointKey === key && sourceMode === 'pin_drag') return;
    eventLocationLastResolvedPointKey = key;
    eventLocationSetStatus('正在解析当前位置...', false);

    const regeo = await mapkitReverseGeocodeByPoint(p.location, { sourceMode }).catch(() => null);
    const nearbyKeyword = mapkitBuildNearbyQuery(p, regeo);
    const nearby = nearbyKeyword
      ? await mapkitSearchPlacesByKeyword(nearbyKeyword, {
          sourceMode,
          coordinate: p.location,
        }).catch(() => [])
      : [];

    const rows = [];
    if (keepFirstPoint) rows.push({ ...p, sourceMode });
    if (regeo) rows.push({ ...regeo, sourceMode });
    for (const item of nearby) {
      rows.push(item);
      if (rows.length >= 20) break;
    }
    eventLocationPickerState.candidates = mapkitMergeUniqueRows(rows);
    await eventLocationPreviewPoint(p, { withPan: false, loadDetail: true, prepend: true });
    eventLocationSetStatus(
      eventLocationPickerState.candidates.length
        ? `已找到 ${eventLocationPickerState.candidates.length} 个候选地点`
        : '未找到周边候选地点',
      false
    );
  }

  async function mapkitSearchByKeyword(sourceMode = 'manual_search') {
    if (eventLocationIsViewMode()) return;
    const { searchInput } = eventLocationModalEls();
    const q = mapkitSafeText(searchInput?.value || '');
    if (!q) {
      eventLocationSetStatus('请输入地点关键词', true);
      return;
    }
    eventLocationSetStatus('正在搜索地点...', false);
    const rows = mapkitMergeUniqueRows(
      await mapkitSearchPlacesByKeyword(q, {
        sourceMode,
        coordinate: mapkitGetCenter(),
      }).catch(() => [])
    );
    eventLocationPickerState.candidates = rows;
    eventLocationPickerState.selectedCandidateIdx = -1;
    eventLocationRenderCandidates();
    if (!rows.length) {
      eventLocationSetStatus('未找到可用地点，请换关键词或拖动地图', true);
      return;
    }
    await eventLocationPreviewPoint(rows[0], { withPan: true, loadDetail: true, prepend: true });
    await eventLocationResolveByPoint(rows[0], sourceMode, { keepFirstPoint: true });
  }

  async function mapkitLocateMeAction() {
    eventLocationSetStatus('正在获取当前位置...', false);
    try {
      const current = await mapkitLocateCurrentPosition();
      mapkitSetPin(current, true);
      mapkitSetAnnotation('myAnnotation', current, { color: '#22c55e', glyphText: 'ME' });
      if (eventLocationIsViewMode()) {
        eventLocationSetStatus('已定位到你当前所在位置', false);
        return;
      }
      eventLocationUpsertCandidate(current, { prepend: true });
      eventLocationPickerState.previewPoint = current;
      await eventLocationPreviewPoint(current, { withPan: true, loadDetail: true, prepend: true });
      await eventLocationResolveByPoint(current, 'my_location', { keepFirstPoint: true });
    } catch (error) {
      eventLocationSetStatus(String(error?.message || '定位失败'), true);
    }
  }

  function mapkitPointToPanelDetail(point) {
    const p = normalizeEventLocationPoint(point);
    if (!p) return null;
    return {
      id: mapkitSafeText(p.providerPlaceId || p.poiId || ''),
      name: mapkitSafeText(p.nameI18n?.zh || p.nameI18n?.en || ''),
      address: mapkitSafeText(p.formattedAddressI18n?.zh || p.formattedAddressI18n?.en || p.addressI18n?.zh || p.addressI18n?.en || ''),
      photos: [],
    };
  }

  async function mapkitLoadPoiDetail(point) {
    if (eventLocationIsViewMode()) return;
    const p = normalizeEventLocationPoint(point);
    if (!p) return;
    eventLocationShowPoiPanel(p, { detail: mapkitPointToPanelDetail(p) });
  }

  async function mapkitLoadViewAnchorDetail() {
    const anchor = normalizeEventLocationPoint(eventLocationViewAnchorPoint);
    if (!anchor) {
      eventLocationHidePoiPanel();
      return;
    }
    eventLocationShowPoiPanel(anchor, { detail: mapkitPointToPanelDetail(anchor) });
  }

  function mapkitDestroy() {
    if (mapkitState.moveTimer) {
      clearTimeout(mapkitState.moveTimer);
      mapkitState.moveTimer = null;
    }
    mapkitRemoveAnnotation('pinAnnotation');
    mapkitRemoveAnnotation('poiAnnotation');
    mapkitRemoveAnnotation('anchorAnnotation');
    mapkitRemoveAnnotation('myAnnotation');
    if (mapkitState.map && typeof mapkitState.map.destroy === 'function') {
      try {
        mapkitState.map.destroy();
      } catch (_error) {
        // ignore
      }
    }
    mapkitState.map = null;
    mapkitState.wrapperMap = null;
  }

  function mapboxGetCenter() {
    const center = mapboxState.map?.getCenter?.();
    const lng = Number(center?.lng);
    const lat = Number(center?.lat);
    if (!Number.isFinite(lng) || !Number.isFinite(lat)) return null;
    return { lng, lat };
  }

  function mapboxPanTo(point, animated = true) {
    const target = toMapboxLngLatPoint(point);
    if (!target || !mapboxState.map) return;
    if (animated && typeof mapboxState.map.easeTo === 'function') {
      mapboxState.map.easeTo({ center: [target.lng, target.lat], duration: 360 });
      return;
    }
    if (typeof mapboxState.map.jumpTo === 'function') {
      mapboxState.map.jumpTo({ center: [target.lng, target.lat] });
    }
  }

  function mapboxRemoveMarker(refKey) {
    const marker = mapboxState[refKey];
    if (!marker) return;
    try {
      marker.remove();
    } catch (_error) {
      // ignore
    }
    mapboxState[refKey] = null;
  }

  function mapboxSetMarker(refKey, point, options = {}) {
    const p = normalizeEventLocationPoint(point);
    if (!p || !mapboxState.map || !window.mapboxgl) return;
    mapboxRemoveMarker(refKey);
    const marker = new window.mapboxgl.Marker({
      color: mapboxSafeText(options.color || '#3b82f6') || '#3b82f6',
      draggable: false,
    });
    marker.setLngLat([p.location.lng, p.location.lat]).addTo(mapboxState.map);
    mapboxState[refKey] = marker;
  }

  function mapboxMergeUniqueRows(rows) {
    const out = [];
    const pushUnique = (item) => {
      const normalized = normalizeEventLocationPoint(item);
      if (!normalized) return;
      const existsIdx = out.findIndex((row) => eventLocationIsSamePoint(row, normalized));
      if (existsIdx >= 0) {
        out[existsIdx] = eventLocationMergePoints(out[existsIdx], normalized);
        return;
      }
      out.push(normalized);
    };
    for (const item of rows || []) {
      pushUnique(item);
      if (out.length >= 20) break;
    }
    return out.slice(0, 20);
  }

  function mapboxBuildNearbyQuery(point, regeo) {
    const p = normalizeEventLocationPoint(point);
    const r = normalizeEventLocationPoint(regeo);
    const parts = [
      mapboxSafeText(r?.nameI18n?.zh || r?.nameI18n?.en || ''),
      mapboxSafeText(r?.city || p?.city || ''),
      mapboxSafeText(r?.province || p?.province || ''),
    ].filter(Boolean);
    if (!parts.length) return '';
    return parts.join(' ');
  }

  function mapboxFeatureName(feature) {
    const props = feature?.properties || {};
    return mapboxSafeText(
      props?.name_zh
      || props?.name_en
      || props?.name
      || feature?.text_zh
      || feature?.text
      || ''
    );
  }

  function mapboxPickHotspotFeature(evt) {
    if (!mapboxState.map || !evt?.point || typeof mapboxState.map.queryRenderedFeatures !== 'function') return null;
    let rows = [];
    try {
      rows = mapboxState.map.queryRenderedFeatures(evt.point) || [];
    } catch (_error) {
      rows = [];
    }
    if (!Array.isArray(rows) || !rows.length) return null;
    for (const feature of rows) {
      const layerId = mapboxSafeText(feature?.layer?.id || '').toLowerCase();
      const layerType = mapboxSafeText(feature?.layer?.type || '').toLowerCase();
      const name = mapboxFeatureName(feature);
      if (!name) continue;
      if (layerType !== 'symbol') continue;
      if (!/(poi|place|settlement|neighbour|neighborhood|locality|district|airport|transit|station|label)/i.test(layerId)) {
        continue;
      }
      return feature;
    }
    return null;
  }

  async function mapboxWaitLoaded() {
    if (!mapboxState.map) return;
    if (typeof mapboxState.map.loaded === 'function' && mapboxState.map.loaded()) return;
    await new Promise((resolve) => {
      mapboxState.map.once('load', () => resolve());
    });
  }

  async function mapboxEnsureMapReady(initialPoint = null) {
    const { mapWrap } = eventLocationModalEls();
    if (!mapWrap) throw new Error('地图容器不存在');
    await ensureMapboxLoaded();
    if (!window.mapboxgl || !window.mapboxgl.Map) {
      throw new Error('Mapbox 未正确初始化');
    }

    if (!mapboxState.map) {
      mapWrap.innerHTML = '';
      mapboxState.map = new window.mapboxgl.Map({
        container: mapWrap,
        style: 'mapbox://styles/mapbox/streets-v12',
        center: [121.4737, 31.2304],
        zoom: 13,
        attributionControl: false,
      });
      if (typeof mapboxState.map.addControl === 'function' && window.mapboxgl.NavigationControl) {
        mapboxState.map.addControl(new window.mapboxgl.NavigationControl({ showCompass: false }), 'top-left');
      }

      mapboxState.map.on('click', async (evt) => {
        if (!eventLocationPickerState.open || eventLocationIsViewMode()) return;
        const feature = mapboxPickHotspotFeature(evt);
        if (!feature) return;
        const point = normalizeEventLocationPoint(
          mapboxLocationPointFromMapClickEvent(
            { feature, lngLat: evt.lngLat },
            'map_poi_click'
          )
        );
        if (!point) return;
        const pointKey = `${point.location.lng.toFixed(6)},${point.location.lat.toFixed(6)}`;
        const now = Date.now();
        if (eventLocationLastMapPickKey === pointKey && (now - eventLocationLastMapPickAt) < 180) return;
        eventLocationLastMapPickKey = pointKey;
        eventLocationLastMapPickAt = now;
        eventLocationSetStatus('已选择地图地点，正在解析候选...', false);
        await eventLocationPreviewPoint(point, { withPan: false, loadDetail: true, prepend: true });
        await eventLocationResolveByPoint(point, 'map_poi_click', { keepFirstPoint: true });
      });

      mapboxState.map.on('moveend', async () => {
        if (!eventLocationPickerState.open || eventLocationIsViewMode()) return;
        if (mapboxState.moveTimer) clearTimeout(mapboxState.moveTimer);
        mapboxState.moveTimer = setTimeout(async () => {
          const center = mapboxGetCenter();
          if (!center) return;
          const point = normalizeEventLocationPoint(
            mapboxLocationPointFromMapClickEvent({ lngLat: center }, 'pin_drag')
          );
          if (!point) return;
          eventLocationSetPin(point, false);
          await eventLocationResolveByPoint(point, 'pin_drag');
        }, 260);
      });
    }

    await mapboxWaitLoaded();
    mapboxState.wrapperMap = {
      getCenter() {
        return mapboxGetCenter();
      },
      panTo(position) {
        const p = Array.isArray(position)
          ? { lng: Number(position[0]), lat: Number(position[1]) }
          : toMapboxLngLatPoint(position);
        if (!p) return;
        mapboxPanTo(p, true);
      },
      resize() {
        if (mapboxState.map && typeof mapboxState.map.resize === 'function') {
          mapboxState.map.resize();
        }
      },
    };
    eventLocationMap = mapboxState.wrapperMap;
    eventLocationPinMarker = null;
    if (initialPoint?.location) {
      mapboxPanTo(initialPoint.location, true);
      eventLocationSetPin(initialPoint, true);
    }
  }

  function mapboxSyncPinMode() {
    if (eventLocationIsViewMode()) {
      mapboxRemoveMarker('pinMarker');
      return;
    }
    const preview = normalizeEventLocationPoint(eventLocationPickerState.previewPoint || eventLocationPickerState.selectedPoint);
    if (preview) {
      mapboxSetMarker('pinMarker', preview, { color: '#f97316' });
    }
  }

  function mapboxSetPin(point, withPan = false) {
    const p = normalizeEventLocationPoint(point);
    if (!p || !mapboxState.map) return;
    if (!eventLocationIsViewMode()) {
      mapboxSetMarker('pinMarker', p, { color: '#f97316' });
    }
    if (withPan) mapboxPanTo(p.location, true);
  }

  function mapboxUpdatePoiMarker(point) {
    const p = normalizeEventLocationPoint(point);
    if (!p || !mapboxState.map || eventLocationIsViewMode()) return;
    mapboxSetMarker('poiMarker', p, { color: '#3b82f6' });
  }

  function mapboxRemovePoiMarker() {
    mapboxRemoveMarker('poiMarker');
  }

  function mapboxUpdateAnchorMarker(point) {
    const p = normalizeEventLocationPoint(point);
    if (!p || !mapboxState.map) return;
    mapboxSetMarker('anchorMarker', p, { color: '#00f5c8' });
  }

  function mapboxRemoveAnchorMarker() {
    mapboxRemoveMarker('anchorMarker');
  }

  async function mapboxResolveByPoint(point, sourceMode = 'pin_drag', options = {}) {
    if (eventLocationIsViewMode()) return;
    const p = normalizeEventLocationPoint(point);
    if (!p) return;
    const keepFirstPoint = !!options.keepFirstPoint;
    const key = `${p.location.lng.toFixed(6)},${p.location.lat.toFixed(6)}`;
    if (eventLocationLastResolvedPointKey === key && sourceMode === 'pin_drag') return;
    eventLocationLastResolvedPointKey = key;
    eventLocationSetStatus('正在解析当前位置...', false);

    const regeo = await mapboxReverseGeocodeByPoint(p.location, { sourceMode }).catch(() => null);
    const nearbyKeyword = mapboxBuildNearbyQuery(p, regeo);
    const nearby = nearbyKeyword
      ? await mapboxSearchPlacesByKeyword(nearbyKeyword, {
          sourceMode,
          coordinate: p.location,
        }).catch(() => [])
      : await mapboxSearchNearbyByPoint(p.location, { sourceMode }).catch(() => []);

    const rows = [];
    if (keepFirstPoint) rows.push({ ...p, sourceMode });
    if (regeo) rows.push({ ...regeo, sourceMode });
    for (const item of nearby) {
      rows.push(item);
      if (rows.length >= 20) break;
    }
    eventLocationPickerState.candidates = mapboxMergeUniqueRows(rows);
    await eventLocationPreviewPoint(p, { withPan: false, loadDetail: true, prepend: true });
    eventLocationSetStatus(
      eventLocationPickerState.candidates.length
        ? `已找到 ${eventLocationPickerState.candidates.length} 个候选地点`
        : '未找到周边候选地点',
      false
    );
  }

  async function mapboxSearchByKeyword(sourceMode = 'manual_search') {
    if (eventLocationIsViewMode()) return;
    const { searchInput } = eventLocationModalEls();
    const q = mapboxSafeText(searchInput?.value || '');
    if (!q) {
      eventLocationSetStatus('请输入地点关键词', true);
      return;
    }
    eventLocationSetStatus('正在搜索地点...', false);
    const rows = mapboxMergeUniqueRows(
      await mapboxSearchPlacesByKeyword(q, {
        sourceMode,
        coordinate: mapboxGetCenter(),
      }).catch(() => [])
    );
    eventLocationPickerState.candidates = rows;
    eventLocationPickerState.selectedCandidateIdx = -1;
    eventLocationRenderCandidates();
    if (!rows.length) {
      eventLocationSetStatus('未找到可用地点，请换关键词或拖动地图', true);
      return;
    }
    await eventLocationPreviewPoint(rows[0], { withPan: true, loadDetail: true, prepend: true });
    await eventLocationResolveByPoint(rows[0], sourceMode, { keepFirstPoint: true });
  }

  async function mapboxLocateMeAction() {
    eventLocationSetStatus('正在获取当前位置...', false);
    try {
      const current = await mapboxLocateCurrentPosition();
      mapboxSetPin(current, true);
      mapboxSetMarker('myMarker', current, { color: '#22c55e' });
      if (eventLocationIsViewMode()) {
        eventLocationSetStatus('已定位到你当前所在位置', false);
        return;
      }
      eventLocationUpsertCandidate(current, { prepend: true });
      eventLocationPickerState.previewPoint = current;
      await eventLocationPreviewPoint(current, { withPan: true, loadDetail: true, prepend: true });
      await eventLocationResolveByPoint(current, 'my_location', { keepFirstPoint: true });
    } catch (error) {
      eventLocationSetStatus(String(error?.message || '定位失败'), true);
    }
  }

  function mapboxPointToPanelDetail(point) {
    const p = normalizeEventLocationPoint(point);
    if (!p) return null;
    return {
      id: mapboxSafeText(p.providerPlaceId || p.poiId || ''),
      name: mapboxSafeText(p.nameI18n?.zh || p.nameI18n?.en || ''),
      address: mapboxSafeText(
        p.formattedAddressI18n?.zh
        || p.formattedAddressI18n?.en
        || p.addressI18n?.zh
        || p.addressI18n?.en
        || ''
      ),
      photos: [],
    };
  }

  async function mapboxLoadPoiDetail(point) {
    if (eventLocationIsViewMode()) return;
    const p = normalizeEventLocationPoint(point);
    if (!p) return;
    const resolved = await mapboxReverseGeocodeByPoint(p.location, { sourceMode: p.sourceMode || 'map_poi_click' }).catch(() => null);
    const enriched = eventLocationMergePoints(p, resolved || p);
    eventLocationApplyPointUpdate(p, enriched);
    eventLocationRenderCandidates();
    eventLocationShowPoiPanel(enriched, { detail: mapboxPointToPanelDetail(enriched) });
  }

  async function mapboxLoadViewAnchorDetail() {
    const anchor = normalizeEventLocationPoint(eventLocationViewAnchorPoint);
    if (!anchor) {
      eventLocationHidePoiPanel();
      return;
    }
    const resolved = await mapboxReverseGeocodeByPoint(anchor.location, { sourceMode: anchor.sourceMode || 'manual_search' }).catch(() => null);
    const enriched = eventLocationMergePoints(anchor, resolved || anchor);
    eventLocationSetViewAnchorPoint(enriched);
    eventLocationPickerState.selectedPoint = enriched;
    eventLocationPickerState.previewPoint = enriched;
    eventLocationShowPoiPanel(enriched, { detail: mapboxPointToPanelDetail(enriched) });
  }

  function mapboxDestroy() {
    if (mapboxState.moveTimer) {
      clearTimeout(mapboxState.moveTimer);
      mapboxState.moveTimer = null;
    }
    mapboxRemoveMarker('pinMarker');
    mapboxRemoveMarker('poiMarker');
    mapboxRemoveMarker('anchorMarker');
    mapboxRemoveMarker('myMarker');
    if (mapboxState.map && typeof mapboxState.map.remove === 'function') {
      try {
        mapboxState.map.remove();
      } catch (_error) {
        // ignore
      }
    }
    mapboxState.map = null;
    mapboxState.wrapperMap = null;
  }

  function geoapifyGetCenter() {
    const center = geoapifyState.map?.getCenter?.();
    const lng = Number(center?.lng);
    const lat = Number(center?.lat);
    if (!Number.isFinite(lng) || !Number.isFinite(lat)) return null;
    return { lng, lat };
  }

  function geoapifyPanTo(point, animated = true) {
    const target = toGeoapifyLngLatPoint(point);
    if (!target || !geoapifyState.map) return;
    geoapifyState.suspendMoveResolveUntil = Date.now() + 900;
    if (animated && typeof geoapifyState.map.easeTo === 'function') {
      geoapifyState.map.easeTo({ center: [target.lng, target.lat], duration: 360 });
      return;
    }
    if (typeof geoapifyState.map.jumpTo === 'function') {
      geoapifyState.map.jumpTo({ center: [target.lng, target.lat] });
    }
  }

  function geoapifyRemoveMarker(refKey) {
    const marker = geoapifyState[refKey];
    if (!marker) return;
    try {
      marker.remove();
    } catch (_error) {
      // ignore
    }
    geoapifyState[refKey] = null;
  }

  function geoapifySetMarker(refKey, point, options = {}) {
    const p = normalizeEventLocationPoint(point);
    if (!p || !geoapifyState.map || !window.maplibregl) return;
    geoapifyRemoveMarker(refKey);
    const marker = new window.maplibregl.Marker({
      color: geoapifySafeText(options.color || '#3b82f6') || '#3b82f6',
      draggable: false,
    });
    marker.setLngLat([p.location.lng, p.location.lat]).addTo(geoapifyState.map);
    geoapifyState[refKey] = marker;
  }

  function geoapifyMergeUniqueRows(rows) {
    const out = [];
    const pushUnique = (item) => {
      const normalized = normalizeEventLocationPoint(item);
      if (!normalized) return;
      const existsIdx = out.findIndex((row) => eventLocationIsSamePoint(row, normalized));
      if (existsIdx >= 0) {
        out[existsIdx] = eventLocationMergePoints(out[existsIdx], normalized);
        return;
      }
      out.push(normalized);
    };
    for (const item of rows || []) {
      pushUnique(item);
      if (out.length >= 20) break;
    }
    return out.slice(0, 20);
  }

  function geoapifyBuildNearbyQuery(point, regeo) {
    const p = normalizeEventLocationPoint(point);
    const r = normalizeEventLocationPoint(regeo);
    const parts = [
      geoapifySafeText(r?.nameI18n?.zh || r?.nameI18n?.en || ''),
      geoapifySafeText(r?.city || p?.city || ''),
      geoapifySafeText(r?.province || p?.province || ''),
    ].filter(Boolean);
    if (!parts.length) return '';
    return parts.join(' ');
  }

  function geoapifyFeatureName(feature) {
    const props = feature?.properties || {};
    return geoapifySafeText(
      props?.name_zh
      || props?.name_en
      || props?.name
      || props?.address_line1
      || props?.formatted
      || feature?.text_zh
      || feature?.text
      || ''
    );
  }

  function geoapifyPickHotspotFeature(evt) {
    if (!geoapifyState.map || !evt?.point || typeof geoapifyState.map.queryRenderedFeatures !== 'function') return null;
    let rows = [];
    try {
      rows = geoapifyState.map.queryRenderedFeatures(evt.point) || [];
    } catch (_error) {
      rows = [];
    }
    if (!Array.isArray(rows) || !rows.length) return null;
    for (const feature of rows) {
      const layerId = geoapifySafeText(feature?.layer?.id || '').toLowerCase();
      const layerType = geoapifySafeText(feature?.layer?.type || '').toLowerCase();
      const name = geoapifyFeatureName(feature);
      if (!name) continue;
      if (layerType !== 'symbol') continue;
      if (!/(poi|place|settlement|neighbour|neighborhood|locality|district|airport|transit|station|label)/i.test(layerId)) {
        continue;
      }
      return feature;
    }
    return null;
  }

  async function geoapifyWaitLoaded() {
    if (!geoapifyState.map) return;
    if (typeof geoapifyState.map.loaded === 'function' && geoapifyState.map.loaded()) return;
    await new Promise((resolve) => {
      geoapifyState.map.once('load', () => resolve());
    });
  }

  async function geoapifyEnsureMapReady(initialPoint = null) {
    const { mapWrap } = eventLocationModalEls();
    if (!mapWrap) throw new Error('地图容器不存在');
    await ensureGeoapifyLoaded();
    if (!window.maplibregl || !window.maplibregl.Map) {
      throw new Error('Geoapify 未正确初始化');
    }
    const cfg = await getGeoapifyRuntimeConfig(false).catch(() => null);
    const apiKey = geoapifySafeText(cfg?.apiKey || '');
    if (!apiKey) {
      throw new Error('未获取到 Geoapify API Key');
    }

    if (!geoapifyState.map) {
      mapWrap.innerHTML = '';
      geoapifyState.map = new window.maplibregl.Map({
        container: mapWrap,
        style: `https://maps.geoapify.com/v1/styles/osm-bright/style.json?apiKey=${encodeURIComponent(apiKey)}`,
        center: [121.4737, 31.2304],
        zoom: 13,
        attributionControl: false,
      });
      if (typeof geoapifyState.map.addControl === 'function' && window.maplibregl.NavigationControl) {
        geoapifyState.map.addControl(new window.maplibregl.NavigationControl({ showCompass: false }), 'top-left');
      }

      geoapifyState.map.on('click', async (evt) => {
        if (!eventLocationPickerState.open || eventLocationIsViewMode()) return;
        const feature = geoapifyPickHotspotFeature(evt);
        if (!feature) return;
        const point = normalizeEventLocationPoint(
          geoapifyLocationPointFromMapClickEvent(
            { feature, lngLat: evt.lngLat },
            'map_poi_click'
          )
        );
        if (!point) return;
        const pointKey = `${point.location.lng.toFixed(6)},${point.location.lat.toFixed(6)}`;
        const now = Date.now();
        if (eventLocationLastMapPickKey === pointKey && (now - eventLocationLastMapPickAt) < 180) return;
        eventLocationLastMapPickKey = pointKey;
        eventLocationLastMapPickAt = now;
        eventLocationSetStatus('已选择地图地点（Geoapify：未触发逆向解析）', false);
        await eventLocationPreviewPoint(point, { withPan: false, loadDetail: true, prepend: true });
        eventLocationUpsertCandidate(point, { prepend: true });
        eventLocationRenderCandidates();
      });

      geoapifyState.map.on('moveend', async (evt) => {
        if (!eventLocationPickerState.open || eventLocationIsViewMode()) return;
        if (Date.now() < Number(geoapifyState.suspendMoveResolveUntil || 0)) return;
        // Geoapify: only treat user-initiated map move as pin drag resolve trigger.
        if (!evt?.originalEvent) return;
        if (geoapifyState.moveTimer) clearTimeout(geoapifyState.moveTimer);
        geoapifyState.moveTimer = setTimeout(async () => {
          const center = geoapifyGetCenter();
          if (!center) return;
          const point = normalizeEventLocationPoint(
            geoapifyLocationPointFromMapClickEvent({ lngLat: center }, 'pin_drag')
          );
          if (!point) return;
          eventLocationSetPin(point, false);
          await eventLocationResolveByPoint(point, 'pin_drag');
        }, 260);
      });
    }

    await geoapifyWaitLoaded();
    geoapifyState.wrapperMap = {
      getCenter() {
        return geoapifyGetCenter();
      },
      panTo(position) {
        const p = Array.isArray(position)
          ? { lng: Number(position[0]), lat: Number(position[1]) }
          : toGeoapifyLngLatPoint(position);
        if (!p) return;
        geoapifyPanTo(p, true);
      },
      resize() {
        if (geoapifyState.map && typeof geoapifyState.map.resize === 'function') {
          geoapifyState.map.resize();
        }
      },
    };
    eventLocationMap = geoapifyState.wrapperMap;
    eventLocationPinMarker = null;
    if (initialPoint?.location) {
      geoapifyPanTo(initialPoint.location, true);
      eventLocationSetPin(initialPoint, true);
    }
  }

  function geoapifySyncPinMode() {
    if (eventLocationIsViewMode()) {
      geoapifyRemoveMarker('pinMarker');
      return;
    }
    const preview = normalizeEventLocationPoint(eventLocationPickerState.previewPoint || eventLocationPickerState.selectedPoint);
    if (preview) {
      geoapifySetMarker('pinMarker', preview, { color: '#f97316' });
    }
  }

  function geoapifySetPin(point, withPan = false) {
    const p = normalizeEventLocationPoint(point);
    if (!p || !geoapifyState.map) return;
    if (!eventLocationIsViewMode()) {
      geoapifySetMarker('pinMarker', p, { color: '#f97316' });
    }
    if (withPan) geoapifyPanTo(p.location, true);
  }

  function geoapifyUpdatePoiMarker(point) {
    const p = normalizeEventLocationPoint(point);
    if (!p || !geoapifyState.map || eventLocationIsViewMode()) return;
    geoapifySetMarker('poiMarker', p, { color: '#3b82f6' });
  }

  function geoapifyRemovePoiMarker() {
    geoapifyRemoveMarker('poiMarker');
  }

  function geoapifyUpdateAnchorMarker(point) {
    const p = normalizeEventLocationPoint(point);
    if (!p || !geoapifyState.map) return;
    geoapifySetMarker('anchorMarker', p, { color: '#00f5c8' });
  }

  function geoapifyRemoveAnchorMarker() {
    geoapifyRemoveMarker('anchorMarker');
  }

  async function geoapifyResolveByPoint(point, sourceMode = 'pin_drag', options = {}) {
    if (eventLocationIsViewMode()) return;
    const p = normalizeEventLocationPoint(point);
    if (!p) return;
    if (sourceMode !== 'pin_drag') {
      const rows = [];
      if (options.keepFirstPoint) rows.push({ ...p, sourceMode });
      rows.push({ ...p, sourceMode });
      eventLocationPickerState.candidates = geoapifyMergeUniqueRows(rows);
      await eventLocationPreviewPoint(p, { withPan: false, loadDetail: true, prepend: true });
      eventLocationSetStatus('已更新候选地点（Geoapify：仅手动拖动 Pin 时触发逆向解析）', false);
      return;
    }
    const keepFirstPoint = !!options.keepFirstPoint;
    const key = `${p.location.lng.toFixed(6)},${p.location.lat.toFixed(6)}`;
    if (eventLocationLastResolvedPointKey === key && sourceMode === 'pin_drag') return;
    eventLocationLastResolvedPointKey = key;
    eventLocationSetStatus('正在解析当前位置...', false);

    const regeo = await geoapifyReverseGeocodeByPoint(p.location, { sourceMode }).catch(() => null);
    const nearbyKeyword = geoapifyBuildNearbyQuery(p, regeo);
    const nearby = nearbyKeyword
      ? await geoapifySearchPlacesByKeyword(nearbyKeyword, {
          sourceMode,
          coordinate: p.location,
        }).catch(() => [])
      : await geoapifySearchNearbyByPoint(p.location, { sourceMode }).catch(() => []);

    const rows = [];
    if (keepFirstPoint) rows.push({ ...p, sourceMode });
    if (regeo) rows.push({ ...regeo, sourceMode });
    for (const item of nearby) {
      rows.push(item);
      if (rows.length >= 20) break;
    }
    eventLocationPickerState.candidates = geoapifyMergeUniqueRows(rows);
    await eventLocationPreviewPoint(p, { withPan: false, loadDetail: true, prepend: true });
    eventLocationSetStatus(
      eventLocationPickerState.candidates.length
        ? `已找到 ${eventLocationPickerState.candidates.length} 个候选地点`
        : '未找到周边候选地点',
      false
    );
  }

  async function geoapifySearchByKeyword(sourceMode = 'manual_search') {
    if (eventLocationIsViewMode()) return;
    const { searchInput } = eventLocationModalEls();
    const q = geoapifySafeText(searchInput?.value || '');
    if (!q) {
      eventLocationSetStatus('请输入地点关键词', true);
      return;
    }
    eventLocationSetStatus('正在搜索地点...', false);
    const rows = geoapifyMergeUniqueRows(
      await geoapifySearchPlacesByKeyword(q, {
        sourceMode,
        coordinate: geoapifyGetCenter(),
      }).catch(() => [])
    );
    eventLocationPickerState.candidates = rows;
    eventLocationPickerState.selectedCandidateIdx = -1;
    eventLocationRenderCandidates();
    if (!rows.length) {
      eventLocationSetStatus('未找到可用地点，请换关键词或拖动地图', true);
      return;
    }
    await eventLocationPreviewPoint(rows[0], { withPan: true, loadDetail: true, prepend: true });
    eventLocationSetStatus(`已找到 ${rows.length} 个候选地点（Geoapify：未触发逆向解析）`, false);
  }

  async function geoapifyLocateMeAction() {
    eventLocationSetStatus('正在获取当前位置...', false);
    try {
      const current = await geoapifyLocateCurrentPosition();
      geoapifySetPin(current, true);
      geoapifySetMarker('myMarker', current, { color: '#22c55e' });
      if (eventLocationIsViewMode()) {
        eventLocationSetStatus('已定位到你当前所在位置', false);
        return;
      }
      eventLocationUpsertCandidate(current, { prepend: true });
      eventLocationPickerState.previewPoint = current;
      await eventLocationPreviewPoint(current, { withPan: true, loadDetail: true, prepend: true });
      eventLocationSetStatus('已定位当前位置（Geoapify：未触发逆向解析）', false);
    } catch (error) {
      eventLocationSetStatus(String(error?.message || '定位失败'), true);
    }
  }

  function geoapifyPointToPanelDetail(point) {
    const p = normalizeEventLocationPoint(point);
    if (!p) return null;
    return {
      id: geoapifySafeText(p.providerPlaceId || p.poiId || ''),
      name: geoapifySafeText(p.nameI18n?.zh || p.nameI18n?.en || ''),
      address: geoapifySafeText(
        p.formattedAddressI18n?.zh
        || p.formattedAddressI18n?.en
        || p.addressI18n?.zh
        || p.addressI18n?.en
        || ''
      ),
      photos: [],
    };
  }

  async function geoapifyLoadPoiDetail(point) {
    if (eventLocationIsViewMode()) return;
    const p = normalizeEventLocationPoint(point);
    if (!p) return;
    eventLocationShowPoiPanel(p, { detail: geoapifyPointToPanelDetail(p) });
  }

  async function geoapifyLoadViewAnchorDetail() {
    const anchor = normalizeEventLocationPoint(eventLocationViewAnchorPoint);
    if (!anchor) {
      eventLocationHidePoiPanel();
      return;
    }
    const resolved = await geoapifyReverseGeocodeByPoint(anchor.location, { sourceMode: anchor.sourceMode || 'manual_search' }).catch(() => null);
    const enriched = eventLocationMergePoints(anchor, resolved || anchor);
    eventLocationSetViewAnchorPoint(enriched);
    eventLocationPickerState.selectedPoint = enriched;
    eventLocationPickerState.previewPoint = enriched;
    eventLocationShowPoiPanel(enriched, { detail: geoapifyPointToPanelDetail(enriched) });
  }

  function geoapifyDestroy() {
    if (geoapifyState.moveTimer) {
      clearTimeout(geoapifyState.moveTimer);
      geoapifyState.moveTimer = null;
    }
    geoapifyRemoveMarker('pinMarker');
    geoapifyRemoveMarker('poiMarker');
    geoapifyRemoveMarker('anchorMarker');
    geoapifyRemoveMarker('myMarker');
    if (geoapifyState.map && typeof geoapifyState.map.remove === 'function') {
      try {
        geoapifyState.map.remove();
      } catch (_error) {
        // ignore
      }
    }
    geoapifyState.map = null;
    geoapifyState.wrapperMap = null;
  }

  function applyProvider(provider) {
    const normalized = normalizeEventLocationProvider(provider || 'amap');
    mapkitState.provider = normalized;
    mapboxState.provider = normalized;
    geoapifyState.provider = normalized;
    if (eventLocationPickerState && typeof eventLocationPickerState === 'object') {
      eventLocationPickerState.provider = normalized;
    }

    if (normalized === 'mapkit') {
      mapboxDestroy();
      geoapifyDestroy();
      window.ensureEventLocationMapReady = mapkitEnsureMapReady;
      window.eventLocationResolveByPoint = mapkitResolveByPoint;
      window.eventLocationSearchByKeyword = mapkitSearchByKeyword;
      window.eventLocationLocateMe = mapkitLocateMeAction;
      window.eventLocationSetPin = mapkitSetPin;
      window.eventLocationSyncPinMarkerMode = mapkitSyncPinMode;
      window.eventLocationUpdatePoiMarker = mapkitUpdatePoiMarker;
      window.eventLocationRemovePoiMarker = mapkitRemovePoiMarker;
      window.eventLocationUpdateAnchorMarker = mapkitUpdateAnchorMarker;
      window.eventLocationRemoveAnchorMarker = mapkitRemoveAnchorMarker;
      window.eventLocationLoadPoiDetailsIntoPanel = mapkitLoadPoiDetail;
      window.eventLocationLoadViewAnchorDetailsIntoPanel = mapkitLoadViewAnchorDetail;
      return;
    }

    if (normalized === 'mapbox') {
      mapkitDestroy();
      geoapifyDestroy();
      window.ensureEventLocationMapReady = mapboxEnsureMapReady;
      window.eventLocationResolveByPoint = mapboxResolveByPoint;
      window.eventLocationSearchByKeyword = mapboxSearchByKeyword;
      window.eventLocationLocateMe = mapboxLocateMeAction;
      window.eventLocationSetPin = mapboxSetPin;
      window.eventLocationSyncPinMarkerMode = mapboxSyncPinMode;
      window.eventLocationUpdatePoiMarker = mapboxUpdatePoiMarker;
      window.eventLocationRemovePoiMarker = mapboxRemovePoiMarker;
      window.eventLocationUpdateAnchorMarker = mapboxUpdateAnchorMarker;
      window.eventLocationRemoveAnchorMarker = mapboxRemoveAnchorMarker;
      window.eventLocationLoadPoiDetailsIntoPanel = mapboxLoadPoiDetail;
      window.eventLocationLoadViewAnchorDetailsIntoPanel = mapboxLoadViewAnchorDetail;
      return;
    }

    if (normalized === 'geoapify') {
      mapkitDestroy();
      mapboxDestroy();
      window.ensureEventLocationMapReady = geoapifyEnsureMapReady;
      window.eventLocationResolveByPoint = geoapifyResolveByPoint;
      window.eventLocationSearchByKeyword = geoapifySearchByKeyword;
      window.eventLocationLocateMe = geoapifyLocateMeAction;
      window.eventLocationSetPin = geoapifySetPin;
      window.eventLocationSyncPinMarkerMode = geoapifySyncPinMode;
      window.eventLocationUpdatePoiMarker = geoapifyUpdatePoiMarker;
      window.eventLocationRemovePoiMarker = geoapifyRemovePoiMarker;
      window.eventLocationUpdateAnchorMarker = geoapifyUpdateAnchorMarker;
      window.eventLocationRemoveAnchorMarker = geoapifyRemoveAnchorMarker;
      window.eventLocationLoadPoiDetailsIntoPanel = geoapifyLoadPoiDetail;
      window.eventLocationLoadViewAnchorDetailsIntoPanel = geoapifyLoadViewAnchorDetail;
      return;
    }

    mapkitDestroy();
    mapboxDestroy();
    geoapifyDestroy();
    window.ensureEventLocationMapReady = original.ensureMapReady;
    window.eventLocationResolveByPoint = original.resolveByPoint;
    window.eventLocationSearchByKeyword = original.searchByKeyword;
    window.eventLocationLocateMe = original.locateMe;
    window.eventLocationSetPin = original.setPin;
    window.eventLocationSyncPinMarkerMode = original.syncPinMode;
    window.eventLocationUpdatePoiMarker = original.updatePoiMarker;
    window.eventLocationRemovePoiMarker = original.removePoiMarker;
    window.eventLocationUpdateAnchorMarker = original.updateAnchorMarker;
    window.eventLocationRemoveAnchorMarker = original.removeAnchorMarker;
    window.eventLocationLoadPoiDetailsIntoPanel = original.loadPoiDetail;
    window.eventLocationLoadViewAnchorDetailsIntoPanel = original.loadViewAnchorDetail;
  }

  function resolveProvider(options = {}) {
    const initialPoint = normalizeEventLocationPoint(options.initialPoint || null);
    const fromOption = mapkitSafeText(options.provider || options.mapProvider || '');
    const fromPoint = mapkitSafeText(initialPoint?.provider || '');
    const preferred = (typeof getPreferredEventLocationProvider === 'function')
      ? getPreferredEventLocationProvider()
      : 'amap';
    return normalizeEventLocationProvider(fromOption || fromPoint || preferred || 'amap');
  }

  window.openEventLocationPickerModal = async function openEventLocationPickerModalByProvider(options = {}) {
    const provider = resolveProvider(options);
    if (typeof setPreferredEventLocationProvider === 'function') {
      setPreferredEventLocationProvider(provider);
    }
    applyProvider(provider);
    try {
      await original.open({
        ...options,
        provider,
      });
    } catch (error) {
      applyProvider('amap');
      throw error;
    }
  };

  window.closeEventLocationPickerModal = function closeEventLocationPickerModalByProvider() {
    try {
      original.close();
    } finally {
      applyProvider('amap');
    }
  };
})();
