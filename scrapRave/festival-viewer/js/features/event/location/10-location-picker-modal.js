// Event location picker modal (AMap)
let eventLocationMap = null;
let eventLocationPinMarker = null;
let eventLocationMyMarker = null;
let eventLocationPoiMarker = null;
let eventLocationAnchorMarker = null;
let eventLocationMoveTimer = null;
let eventLocationLastResolvedPointKey = '';
let eventLocationLastMapPickKey = '';
let eventLocationLastMapPickAt = 0;
let eventLocationPoiDetailToken = 0;
let eventLocationPoiPanelPhotos = [];
let eventLocationViewAnchorPoint = null;

function eventLocationModalEls() {
  return {
    overlay: document.getElementById('event-location-picker-overlay'),
    modal: document.getElementById('event-location-picker-modal'),
    title: document.getElementById('event-location-picker-title'),
    searchInput: document.getElementById('event-location-picker-search-input'),
    searchBtn: document.getElementById('event-location-picker-search-btn'),
    fillZhBtn: document.getElementById('event-location-picker-fill-zh-btn'),
    fillEnBtn: document.getElementById('event-location-picker-fill-en-btn'),
    myPosBtn: document.getElementById('event-location-picker-my-pos-btn'),
    status: document.getElementById('event-location-picker-status'),
    candidates: document.getElementById('event-location-picker-candidates'),
    confirmBtn: document.getElementById('event-location-picker-confirm-btn'),
    cancelBtn: document.getElementById('event-location-picker-cancel-btn'),
    mapWrap: document.getElementById('event-location-picker-map'),
    centerPin: document.getElementById('event-location-center-pin'),
    returnAnchorBtn: document.getElementById('event-location-return-anchor-btn'),
    poiPanel: document.getElementById('event-location-poi-panel'),
    poiPanelBody: document.getElementById('event-location-poi-panel-body'),
    poiPanelClose: document.getElementById('event-location-poi-panel-close'),
  };
}

function eventLocationSetStatus(text, isError = false) {
  const { status } = eventLocationModalEls();
  if (!status) return;
  status.textContent = String(text || '');
  status.classList.toggle('error', !!isError);
}

function eventLocationPointKey(point) {
  const p = normalizeEventLocationPoint(point);
  if (!p) return '';
  return `${Number(p.location.lng).toFixed(6)},${Number(p.location.lat).toFixed(6)}::${String(p.poiId || '').trim()}`;
}

function eventLocationBuildPoiMarkerHtml() {
  return `
    <div class="event-location-poi-marker" aria-hidden="true">
      <span class="event-location-poi-marker-pulse"></span>
      <span class="event-location-poi-marker-pin"></span>
      <span class="event-location-poi-marker-shadow"></span>
    </div>
  `;
}

function eventLocationBuildAnchorMarkerHtml() {
  return `
    <div class="event-location-anchor-marker" aria-hidden="true">
      <span class="event-location-anchor-marker-pin"></span>
      <span class="event-location-anchor-marker-shadow"></span>
    </div>
  `;
}

function eventLocationIsViewMode() {
  return String(eventLocationPickerState?.mode || '').trim() === 'view';
}

function eventLocationRemoveAnchorMarker() {
  if (!eventLocationMap || !eventLocationAnchorMarker) return;
  eventLocationMap.remove(eventLocationAnchorMarker);
  eventLocationAnchorMarker = null;
}

function eventLocationUpdateAnchorMarker(point) {
  const p = normalizeEventLocationPoint(point);
  if (!p || !eventLocationMap || !window.AMap) return;
  const pos = [p.location.lng, p.location.lat];
  if (!eventLocationAnchorMarker) {
    eventLocationAnchorMarker = new window.AMap.Marker({
      position: pos,
      bubble: false,
      anchor: 'bottom-center',
      draggable: false,
      content: eventLocationBuildAnchorMarkerHtml(),
      title: String(p.nameI18n?.zh || p.nameI18n?.en || '活动场地').trim() || '活动场地',
      zIndex: 125,
    });
    eventLocationMap.add(eventLocationAnchorMarker);
    return;
  }
  eventLocationAnchorMarker.setPosition(pos);
  eventLocationAnchorMarker.setTitle(String(p.nameI18n?.zh || p.nameI18n?.en || '活动场地').trim() || '活动场地');
}

function eventLocationSetViewAnchorPoint(point) {
  const p = normalizeEventLocationPoint(point);
  eventLocationViewAnchorPoint = p;
  if (!p) {
    eventLocationRemoveAnchorMarker();
    return null;
  }
  eventLocationUpdateAnchorMarker(p);
  return p;
}

function eventLocationSyncViewUi() {
  const { modal, centerPin, returnAnchorBtn, poiPanelClose } = eventLocationModalEls();
  const isView = eventLocationIsViewMode();
  const hasAnchor = !!normalizeEventLocationPoint(eventLocationViewAnchorPoint);
  if (modal) modal.classList.toggle('is-view-mode', isView);
  if (centerPin) centerPin.style.display = isView ? 'none' : '';
  if (returnAnchorBtn) {
    returnAnchorBtn.style.display = isView ? 'inline-flex' : 'none';
    returnAnchorBtn.disabled = isView && !hasAnchor;
  }
  if (poiPanelClose) {
    poiPanelClose.style.display = isView ? 'none' : '';
    poiPanelClose.disabled = isView;
  }
}

function eventLocationSyncPinMarkerMode() {
  if (!eventLocationPinMarker) return;
  if (eventLocationIsViewMode()) {
    if (typeof eventLocationPinMarker.setDraggable === 'function') {
      eventLocationPinMarker.setDraggable(false);
    }
    if (typeof eventLocationPinMarker.hide === 'function') {
      eventLocationPinMarker.hide();
    }
    return;
  }
  if (typeof eventLocationPinMarker.show === 'function') {
    eventLocationPinMarker.show();
  }
  if (typeof eventLocationPinMarker.setDraggable === 'function') {
    eventLocationPinMarker.setDraggable(true);
  }
}

function eventLocationSafeHttpUrl(url) {
  const value = String(url || '').trim();
  if (!value) return '';
  if (/^https?:\/\//i.test(value)) return value;
  return '';
}

function eventLocationBuildPoiPanelHtml(point, options = {}) {
  const p = normalizeEventLocationPoint(point);
  if (!p) return '<div class="event-location-poi-info"><div class="event-location-poi-info-tip">暂无 POI 信息</div></div>';
  const detail = options.detail && typeof options.detail === 'object' ? options.detail : null;
  const loading = !!options.loading;
  const detailError = String(options.detailError || '').trim();
  const title = escapeHtml(String(detail?.name || p.nameI18n?.zh || p.nameI18n?.en || '未命名地点').trim() || '未命名地点');
  const poiId = escapeHtml(String(detail?.id || p.poiId || '-'));
  const coord = `${Number(p.location.lng).toFixed(6)}, ${Number(p.location.lat).toFixed(6)}`;
  const address = escapeHtml(String(detail?.address || p.formattedAddressI18n?.zh || p.formattedAddressI18n?.en || '').trim());
  const tel = escapeHtml(String(detail?.tel || '').trim());
  const photos = Array.isArray(detail?.photos)
    ? detail.photos
      .map((item) => ({
        title: escapeHtml(String(item?.title || 'POI 图片').trim() || 'POI 图片'),
        url: eventLocationSafeHttpUrl(item?.url || ''),
      }))
      .filter((item) => !!item.url)
    : [];
  const photosHtml = photos.length
    ? `
      <div class="event-location-poi-photo-grid">
        ${photos.slice(0, 6).map((item, idx) => `
          <button type="button" class="event-location-poi-photo-card" data-poi-photo-idx="${idx}" title="${item.title}">
            <img src="${item.url}" alt="${item.title}" loading="lazy" />
          </button>
        `).join('')}
      </div>
    `
    : '';
  return `
    <div class="event-location-poi-info">
      <div class="event-location-poi-info-title">${title}</div>
      <div class="event-location-poi-info-meta">poiId: ${poiId}</div>
      <div class="event-location-poi-info-meta">lnglat: ${escapeHtml(coord)}</div>
      ${address ? `<div class="event-location-poi-info-meta">地址: ${address}</div>` : ''}
      ${tel ? `<div class="event-location-poi-info-meta">电话: ${tel}</div>` : ''}
      ${loading ? '<div class="event-location-poi-info-tip">正在加载 POI 详情与图片...</div>' : ''}
      ${detailError ? `<div class="event-location-poi-info-tip">${escapeHtml(detailError)}</div>` : ''}
      ${photosHtml || (!loading ? '<div class="event-location-poi-info-tip">暂无可用图片</div>' : '')}
    </div>
  `;
}

function eventLocationExtractPoiPhotos(detail) {
  const rows = Array.isArray(detail?.photos) ? detail.photos : [];
  return rows
    .map((item, idx) => {
      const url = eventLocationSafeHttpUrl(item?.url || '');
      if (!url) return null;
      const title = String(item?.title || `POI 图片 ${idx + 1}`).trim() || `POI 图片 ${idx + 1}`;
      return { url, title };
    })
    .filter(Boolean);
}

function eventLocationShowPoiPanel(point, options = {}) {
  const { poiPanel, poiPanelBody } = eventLocationModalEls();
  if (!poiPanel || !poiPanelBody) return;
  if (options.detail && typeof options.detail === 'object') {
    eventLocationPoiPanelPhotos = eventLocationExtractPoiPhotos(options.detail);
  } else if (options.loading || options.detailError) {
    eventLocationPoiPanelPhotos = [];
  }
  poiPanelBody.innerHTML = eventLocationBuildPoiPanelHtml(point, options);
  poiPanel.classList.add('visible');
}

function eventLocationHidePoiPanel() {
  const { poiPanel, poiPanelBody } = eventLocationModalEls();
  if (poiPanelBody) poiPanelBody.innerHTML = '';
  if (poiPanel) poiPanel.classList.remove('visible');
  eventLocationPoiPanelPhotos = [];
  eventLocationPoiDetailToken += 1;
}

function eventLocationOpenPoiPhotoLightbox(startIdx = 0) {
  const list = Array.isArray(eventLocationPoiPanelPhotos) ? eventLocationPoiPanelPhotos : [];
  if (!list.length || typeof openLightboxItems !== 'function') return;
  const items = list.map((item, idx) => ({
    url: String(item.url || '').trim(),
    label: String(item.title || `POI 图片 ${idx + 1}`).trim() || `POI 图片 ${idx + 1}`,
    type: 'other',
    downloadUrl: String(item.url || '').trim(),
    downloadName: `poi-photo-${idx + 1}${guessImageExtFromNameOrUrl(item.url || '') || '.jpg'}`,
  }));
  const idx = Math.max(0, Math.min(Number(startIdx || 0), items.length - 1));
  openLightboxItems(items, idx, 'POI 图片预览');
}

function eventLocationRemovePoiMarker() {
  if (!eventLocationMap || !eventLocationPoiMarker) return;
  eventLocationMap.remove(eventLocationPoiMarker);
  eventLocationPoiMarker = null;
}

function eventLocationUpdatePoiMarker(point) {
  const p = normalizeEventLocationPoint(point);
  if (!p || !eventLocationMap || !window.AMap) return;
  const pos = [p.location.lng, p.location.lat];
  if (!eventLocationPoiMarker) {
    eventLocationPoiMarker = new window.AMap.Marker({
      position: pos,
      bubble: false,
      anchor: 'bottom-center',
      content: eventLocationBuildPoiMarkerHtml(),
      title: String(p.nameI18n?.zh || p.nameI18n?.en || '选中的 POI').trim(),
    });
    eventLocationMap.add(eventLocationPoiMarker);
  } else {
    eventLocationPoiMarker.setPosition(pos);
    eventLocationPoiMarker.setTitle(String(p.nameI18n?.zh || p.nameI18n?.en || '选中的 POI').trim());
  }
}

async function eventLocationLoadViewAnchorDetailsIntoPanel() {
  const anchor = normalizeEventLocationPoint(eventLocationViewAnchorPoint);
  if (!anchor) {
    eventLocationHidePoiPanel();
    return;
  }
  eventLocationShowPoiPanel(anchor, { loading: true });
  if (!anchor.poiId || typeof amapGetPoiDetailsById !== 'function') {
    eventLocationShowPoiPanel(anchor, {});
    return;
  }
  const token = ++eventLocationPoiDetailToken;
  try {
    const detail = await amapGetPoiDetailsById(anchor.poiId);
    if (token !== eventLocationPoiDetailToken) return;
    if (detail) {
      const detailPoint = typeof normalizeAmapPoi === 'function'
        ? normalizeEventLocationPoint(normalizeAmapPoi(detail, anchor.sourceMode || 'map_poi_click'))
        : null;
      const enriched = eventLocationMergePoints(anchor, detailPoint || anchor);
      eventLocationSetViewAnchorPoint(enriched);
      eventLocationPickerState.selectedPoint = enriched;
      eventLocationPickerState.previewPoint = enriched;
      eventLocationShowPoiPanel(enriched, { detail });
      return;
    }
    eventLocationShowPoiPanel(anchor, {});
  } catch (_error) {
    if (token !== eventLocationPoiDetailToken) return;
    eventLocationShowPoiPanel(anchor, { detailError: '查询 POI 详情失败，请稍后重试。' });
  }
}

async function eventLocationLoadPoiDetailsIntoPanel(point) {
  if (eventLocationIsViewMode()) return;
  const p = normalizeEventLocationPoint(point);
  if (!p) return;
  eventLocationShowPoiPanel(p, { loading: true });
  if (!p.poiId || typeof amapGetPoiDetailsById !== 'function') {
    eventLocationShowPoiPanel(p, { detailError: '该热点没有可查询的 POI ID。' });
    return;
  }
  const token = ++eventLocationPoiDetailToken;
  try {
    const detail = await amapGetPoiDetailsById(p.poiId);
    if (token !== eventLocationPoiDetailToken) return;
    if (detail) {
      const detailPoint = typeof normalizeAmapPoi === 'function'
        ? normalizeEventLocationPoint(normalizeAmapPoi(detail, p.sourceMode || 'map_poi_click'))
        : null;
      const enriched = eventLocationMergePoints(p, detailPoint || p);
      eventLocationApplyPointUpdate(p, enriched);
      eventLocationRenderCandidates();
      eventLocationShowPoiPanel(enriched, { detail });
      return;
    }
    eventLocationShowPoiPanel(p, { detailError: '未查询到该 POI 的详情或图片。' });
  } catch (_error) {
    if (token !== eventLocationPoiDetailToken) return;
    eventLocationShowPoiPanel(p, { detailError: '查询 POI 详情失败，请稍后重试。' });
  }
}

function eventLocationCoordKey(point) {
  const p = normalizeEventLocationPoint(point);
  if (!p) return '';
  return `${Number(p.location.lng).toFixed(6)},${Number(p.location.lat).toFixed(6)}`;
}

function eventLocationIsSamePoint(left, right) {
  const l = normalizeEventLocationPoint(left);
  const r = normalizeEventLocationPoint(right);
  if (!l || !r) return false;
  if (eventLocationCoordKey(l) !== eventLocationCoordKey(r)) return false;
  const leftPoiId = String(l.poiId || '').trim();
  const rightPoiId = String(r.poiId || '').trim();
  if (leftPoiId && rightPoiId) return leftPoiId === rightPoiId;
  return true;
}

function eventLocationMergeText(primary, fallback) {
  const p = String(primary || '').trim();
  if (p) return p;
  return String(fallback || '').trim();
}

function eventLocationMergePoints(base, incoming) {
  const b = normalizeEventLocationPoint(base);
  const i = normalizeEventLocationPoint(incoming);
  if (!b) return i;
  if (!i) return b;
  return normalizeEventLocationPoint({
    ...b,
    provider: eventLocationMergeText(i.provider, b.provider),
    sourceMode: eventLocationMergeText(i.sourceMode, b.sourceMode),
    poiId: eventLocationMergeText(i.poiId, b.poiId),
    location: i.location || b.location,
    nameI18n: {
      zh: eventLocationMergeText(i?.nameI18n?.zh, b?.nameI18n?.zh),
      en: eventLocationMergeText(i?.nameI18n?.en, b?.nameI18n?.en),
    },
    addressI18n: {
      zh: eventLocationMergeText(i?.addressI18n?.zh, b?.addressI18n?.zh),
      en: eventLocationMergeText(i?.addressI18n?.en, b?.addressI18n?.en),
    },
    formattedAddressI18n: {
      zh: eventLocationMergeText(i?.formattedAddressI18n?.zh, b?.formattedAddressI18n?.zh),
      en: eventLocationMergeText(i?.formattedAddressI18n?.en, b?.formattedAddressI18n?.en),
    },
    adcode: eventLocationMergeText(i.adcode, b.adcode),
    city: eventLocationMergeText(i.city, b.city),
    district: eventLocationMergeText(i.district, b.district),
    province: eventLocationMergeText(i.province, b.province),
    i18nPending: !!(i.i18nPending && b.i18nPending),
    selectedAt: eventLocationMergeText(i.selectedAt, b.selectedAt),
  });
}

function eventLocationApplyPointUpdate(referencePoint, nextPoint) {
  const ref = normalizeEventLocationPoint(referencePoint);
  const next = normalizeEventLocationPoint(nextPoint);
  if (!ref || !next) return;
  const oldRows = Array.isArray(eventLocationPickerState.candidates) ? eventLocationPickerState.candidates : [];
  let hit = false;
  eventLocationPickerState.candidates = oldRows.map((row) => {
    if (!eventLocationIsSamePoint(row, ref)) return row;
    hit = true;
    return eventLocationMergePoints(row, next);
  });
  if (!hit) {
    eventLocationPickerState.candidates = [next, ...eventLocationPickerState.candidates].slice(0, 20);
  }
  if (eventLocationIsSamePoint(eventLocationPickerState.selectedPoint, ref)) {
    eventLocationPickerState.selectedPoint = eventLocationMergePoints(eventLocationPickerState.selectedPoint, next);
  }
  if (eventLocationIsSamePoint(eventLocationPickerState.previewPoint, ref)) {
    eventLocationPickerState.previewPoint = eventLocationMergePoints(eventLocationPickerState.previewPoint, next);
  }
}

function eventLocationUpsertCandidate(point, options = {}) {
  const p = normalizeEventLocationPoint(point);
  if (!p) return null;
  const prepend = !!options.prepend;
  const oldRows = Array.isArray(eventLocationPickerState.candidates) ? eventLocationPickerState.candidates : [];
  let mergedPoint = p;
  const kept = [];
  for (const row of oldRows) {
    if (!eventLocationIsSamePoint(row, p)) {
      kept.push(row);
      continue;
    }
    mergedPoint = eventLocationMergePoints(row, p);
  }
  const nextRows = prepend ? [mergedPoint, ...kept] : [...kept, mergedPoint];
  eventLocationPickerState.candidates = nextRows.slice(0, 20);
  return mergedPoint;
}

function eventLocationBuildRenderRows() {
  const selected = normalizeEventLocationPoint(eventLocationPickerState.selectedPoint);
  const preview = normalizeEventLocationPoint(eventLocationPickerState.previewPoint);
  const sourceRows = Array.isArray(eventLocationPickerState.candidates) ? eventLocationPickerState.candidates : [];
  const rows = [];
  const pushUnique = (item) => {
    const normalized = normalizeEventLocationPoint(item);
    if (!normalized) return;
    const existsIdx = rows.findIndex((row) => eventLocationIsSamePoint(row, normalized));
    if (existsIdx >= 0) {
      rows[existsIdx] = eventLocationMergePoints(rows[existsIdx], normalized);
      return;
    }
    rows.push(normalized);
  };
  if (selected) pushUnique(selected);
  if (preview && !eventLocationIsSamePoint(preview, selected)) pushUnique(preview);
  for (const item of sourceRows) {
    pushUnique(item);
    if (rows.length >= 20) break;
  }
  return rows.slice(0, 20);
}

async function eventLocationPreviewPoint(point, options = {}) {
  const p = normalizeEventLocationPoint(point);
  if (!p) return;
  const withPan = !!options.withPan;
  const loadDetail = options.loadDetail !== false;
  const prepend = options.prepend !== false;
  const merged = eventLocationUpsertCandidate(p, { prepend }) || p;
  eventLocationPickerState.previewPoint = merged;
  eventLocationRenderCandidates();
  eventLocationSetPin(merged, withPan);
  eventLocationUpdatePoiMarker(merged);
  if (loadDetail) {
    await eventLocationLoadPoiDetailsIntoPanel(merged);
  } else {
    eventLocationShowPoiPanel(merged, {});
  }
}

async function eventLocationSetSelectedPoint(point, options = {}) {
  const p = normalizeEventLocationPoint(point);
  if (!p) return;
  const merged = eventLocationUpsertCandidate(p, { prepend: true }) || p;
  eventLocationPickerState.selectedPoint = merged;
  if (options.syncPreview === false) {
    eventLocationRenderCandidates();
    return;
  }
  await eventLocationPreviewPoint(merged, {
    withPan: !!options.withPan,
    loadDetail: options.loadDetail !== false,
    prepend: true,
  });
}

function eventLocationRenderCandidates() {
  const { candidates } = eventLocationModalEls();
  if (!candidates) return;
  if (eventLocationIsViewMode()) {
    candidates.innerHTML = '';
    eventLocationPickerState.renderRows = [];
    eventLocationPickerState.selectedCandidateIdx = -1;
    return;
  }
  const rows = eventLocationBuildRenderRows();
  eventLocationPickerState.renderRows = rows;
  if (!rows.length) {
    candidates.innerHTML = '<div class="event-location-candidate-empty">暂无候选地点</div>';
    eventLocationPickerState.selectedCandidateIdx = -1;
    eventLocationHidePoiPanel();
    eventLocationRemovePoiMarker();
    return;
  }
  const selected = normalizeEventLocationPoint(eventLocationPickerState.selectedPoint);
  const preview = normalizeEventLocationPoint(eventLocationPickerState.previewPoint);
  const htmlRows = rows.map((item, idx) => {
    const isCurrent = !!(selected && eventLocationIsSamePoint(item, selected));
    const isActive = !!(preview && eventLocationIsSamePoint(item, preview));
    const classList = ['event-location-candidate'];
    if (isCurrent) classList.push('current');
    if (isActive) classList.push('active');
    const name = escapeHtml(String(item?.nameI18n?.zh || item?.nameI18n?.en || '').trim() || '-');
    const addr = escapeHtml(String(item?.formattedAddressI18n?.zh || item?.formattedAddressI18n?.en || '').trim() || '-');
    const coord = `${Number(item?.location?.lng || 0).toFixed(6)}, ${Number(item?.location?.lat || 0).toFixed(6)}`;
    return `
      <div class="${classList.join(' ')}" data-location-candidate-idx="${idx}">
        <div class="event-location-candidate-head">
          <span class="event-location-candidate-badge">${isCurrent ? '当前选定地址' : '候选地址'}</span>
          ${isCurrent ? '' : `<button type="button" class="event-location-candidate-set-btn" data-location-set-idx="${idx}">设为候选地址</button>`}
        </div>
        <span class="event-location-candidate-name">${name}</span>
        <span class="event-location-candidate-addr">${addr}</span>
        <span class="event-location-candidate-coord">${escapeHtml(coord)}</span>
      </div>
    `;
  });
  eventLocationPickerState.selectedCandidateIdx = rows.findIndex((item) => preview && eventLocationIsSamePoint(item, preview));
  candidates.innerHTML = htmlRows.join('');
}

function eventLocationCurrentPoint() {
  return normalizeEventLocationPoint(eventLocationPickerState.selectedPoint);
}

function eventLocationCurrentPreviewPoint() {
  const preview = normalizeEventLocationPoint(eventLocationPickerState.previewPoint);
  if (preview) return preview;
  const selected = normalizeEventLocationPoint(eventLocationPickerState.selectedPoint);
  if (selected) return selected;
  const rows = Array.isArray(eventLocationPickerState.renderRows) ? eventLocationPickerState.renderRows : [];
  return normalizeEventLocationPoint(rows[0] || null);
}

function eventLocationFormatAddressForSearchBox(point) {
  const p = normalizeEventLocationPoint(point);
  if (!p) return '';
  const name = String(p?.nameI18n?.zh || p?.nameI18n?.en || '').trim();
  const formatted = String(p?.formattedAddressI18n?.zh || p?.formattedAddressI18n?.en || '').trim();
  const address = String(p?.addressI18n?.zh || p?.addressI18n?.en || '').trim();
  const coord = `${Number(p.location.lng).toFixed(6)}, ${Number(p.location.lat).toFixed(6)}`;
  if (formatted && name) return `${name} · ${formatted}`;
  if (formatted) return formatted;
  if (address && name) return `${name} · ${address}`;
  if (address) return address;
  if (name) return name;
  return coord;
}

function eventLocationGetComposedQueryByLocale(locale = 'zh') {
  const lang = String(locale || '').toLowerCase() === 'en' ? 'en' : 'zh';
  const fromLocale = lang === 'en'
    ? eventLocationPickerState?.composedQueryEn
    : eventLocationPickerState?.composedQueryZh;
  return String(fromLocale || eventLocationPickerState?.composedQuery || '').trim();
}

function eventLocationMergeSearchRows(listRows) {
  const merged = [];
  const pushUnique = (item) => {
    const normalized = normalizeEventLocationPoint(item);
    if (!normalized) return;
    const idx = merged.findIndex((row) => eventLocationIsSamePoint(row, normalized));
    if (idx >= 0) {
      merged[idx] = eventLocationMergePoints(merged[idx], normalized);
      return;
    }
    merged.push(normalized);
  };
  for (const rows of listRows || []) {
    for (const item of (Array.isArray(rows) ? rows : [])) {
      pushUnique(item);
      if (merged.length >= 20) break;
    }
    if (merged.length >= 20) break;
  }
  return merged.slice(0, 20);
}

function eventLocationSetPin(point, withPan = false) {
  const p = normalizeEventLocationPoint(point);
  if (!p || !eventLocationMap) return;
  if (eventLocationPinMarker && !eventLocationIsViewMode()) {
    eventLocationPinMarker.setPosition([p.location.lng, p.location.lat]);
  }
  if (withPan) eventLocationMap.panTo([p.location.lng, p.location.lat]);
}

async function eventLocationResolveByPoint(point, sourceMode = 'pin_drag', options = {}) {
  if (eventLocationIsViewMode()) return;
  const p = normalizeEventLocationPoint(point);
  if (!p) return;
  const keepFirstPoint = !!options.keepFirstPoint;
  const key = `${p.location.lng.toFixed(6)},${p.location.lat.toFixed(6)}`;
  if (eventLocationLastResolvedPointKey === key && sourceMode === 'pin_drag') return;
  eventLocationLastResolvedPointKey = key;
  eventLocationSetStatus('正在解析当前位置...', false);
  const [regeo, nearby] = await Promise.all([
    amapReverseGeocodeByPoint(p.location).catch(() => null),
    amapSearchNearbyByPoint(p.location, { sourceMode }).catch(() => []),
  ]);
  const rows = [];
  const pushUnique = (item) => {
    const normalized = normalizeEventLocationPoint(item);
    if (!normalized) return;
    const existsIdx = rows.findIndex((x) => eventLocationIsSamePoint(x, normalized));
    if (existsIdx >= 0) {
      rows[existsIdx] = eventLocationMergePoints(rows[existsIdx], normalized);
      return;
    }
    rows.push(normalized);
  };
  if (keepFirstPoint) pushUnique({ ...p, sourceMode });
  if (regeo) pushUnique({ ...regeo, sourceMode });
  for (const item of (nearby || [])) {
    if (!item?.location) continue;
    pushUnique(item);
    if (rows.length >= 20) break;
  }
  eventLocationPickerState.candidates = rows;
  await eventLocationPreviewPoint(p, { withPan: false, loadDetail: true, prepend: true });
  eventLocationSetStatus(rows.length ? `已找到 ${rows.length} 个候选地点` : '未找到周边候选地点', false);
}

async function eventLocationSearchByKeyword(sourceMode = 'manual_search') {
  if (eventLocationIsViewMode()) return;
  const { searchInput } = eventLocationModalEls();
  const q = String(searchInput?.value || '').trim();
  if (!q) {
    eventLocationSetStatus('请输入地点关键词', true);
    return;
  }
  eventLocationSetStatus('正在搜索地点...', false);
  const rows = eventLocationMergeSearchRows([
    await amapSearchPlacesByKeyword(q, { sourceMode, citylimit: false, pageSize: 20 }).catch(() => []),
  ]);
  eventLocationPickerState.candidates = rows;
  eventLocationPickerState.selectedCandidateIdx = -1;
  eventLocationRenderCandidates();
  if (rows.length) {
    await eventLocationPreviewPoint(rows[0], { withPan: true, loadDetail: true, prepend: true });
    await eventLocationResolveByPoint(rows[0], sourceMode, { keepFirstPoint: true });
  } else {
    eventLocationSetStatus('未找到可用地点，请换关键词或拖动地图 Pin', true);
  }
}

async function eventLocationLocateMe() {
  eventLocationSetStatus('正在获取当前位置...', false);
  try {
    const current = await amapLocateCurrentPosition();
    eventLocationSetPin(current, true);
    if (eventLocationMap) {
      if (!eventLocationMyMarker) {
        eventLocationMyMarker = new window.AMap.Marker({
          position: [current.location.lng, current.location.lat],
          bubble: false,
          offset: new window.AMap.Pixel(-6, -6),
          content: '<div class="event-location-my-dot"></div>',
        });
        eventLocationMap.add(eventLocationMyMarker);
      } else {
        eventLocationMyMarker.setPosition([current.location.lng, current.location.lat]);
      }
    }
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

async function ensureEventLocationMapReady(initialPoint = null) {
  const { mapWrap } = eventLocationModalEls();
  if (!mapWrap) throw new Error('地图容器不存在');
  const AMap = await ensureAmapLoaded();
  if (!eventLocationMap) {
    eventLocationMap = new AMap.Map(mapWrap, {
      zoom: 13,
      viewMode: '2D',
      resizeEnable: true,
      isHotspot: true,
      center: [121.4737, 31.2304],
    });
    eventLocationPinMarker = new AMap.Marker({
      position: [121.4737, 31.2304],
      draggable: true,
      bubble: false,
    });
    eventLocationMap.add(eventLocationPinMarker);
    eventLocationMap.on('moveend', () => {
      if (!eventLocationPickerState.open) return;
      if (eventLocationIsViewMode()) return;
      if (eventLocationMoveTimer) clearTimeout(eventLocationMoveTimer);
      eventLocationMoveTimer = setTimeout(async () => {
        const center = eventLocationMap.getCenter();
        if (!center) return;
        const p = normalizeEventLocationPoint({
          provider: 'amap',
          sourceMode: 'pin_drag',
          location: { lng: center.lng, lat: center.lat },
          nameI18n: { zh: '', en: '' },
          addressI18n: { zh: '', en: '' },
          formattedAddressI18n: { zh: '', en: '' },
        });
        eventLocationSetPin(p, false);
        await eventLocationResolveByPoint(p, 'pin_drag');
      }, 260);
    });
    eventLocationPinMarker.on('dragend', async (evt) => {
      const lnglat = evt && evt.lnglat ? evt.lnglat : null;
      if (!lnglat) return;
      const p = normalizeEventLocationPoint({
        provider: 'amap',
        sourceMode: 'pin_drag',
        location: { lng: lnglat.lng, lat: lnglat.lat },
        nameI18n: { zh: '', en: '' },
        addressI18n: { zh: '', en: '' },
        formattedAddressI18n: { zh: '', en: '' },
      });
      if (!p) return;
      eventLocationMap.panTo([p.location.lng, p.location.lat]);
      if (eventLocationIsViewMode()) return;
      await eventLocationResolveByPoint(p, 'pin_drag');
    });
    const handleMapPick = async (evt, mode = 'map_poi_click') => {
      if (!eventLocationPickerState.open || eventLocationPickerState.mode === 'view') return;
      const hasPoiInfo = !!(
        (evt?.poi && typeof evt.poi === 'object')
        || (evt?.poiinfo && typeof evt.poiinfo === 'object')
        || String(evt?.id || '').trim()
        || String(evt?.name || '').trim()
      );
      if (!hasPoiInfo) return;
      const clicked = typeof amapLocationPointFromMapClickEvent === 'function'
        ? amapLocationPointFromMapClickEvent(evt, mode)
        : null;
      const point = normalizeEventLocationPoint(clicked);
      if (!point) {
        eventLocationSetStatus('当前点击位置未解析到有效坐标，请放大后重试', true);
        return;
      }
      const pointKey = `${point.location.lng.toFixed(6)},${point.location.lat.toFixed(6)}`;
      const now = Date.now();
      if (eventLocationLastMapPickKey === pointKey && (now - eventLocationLastMapPickAt) < 180) return;
      eventLocationLastMapPickKey = pointKey;
      eventLocationLastMapPickAt = now;
      eventLocationSetStatus('已选择地图地点，正在解析候选...', false);
      await eventLocationPreviewPoint(point, { withPan: false, loadDetail: true, prepend: true });
      await eventLocationResolveByPoint(point, mode, { keepFirstPoint: true });
    };
    eventLocationMap.on('hotspotclick', async (evt) => {
      await handleMapPick(evt, 'map_poi_click');
    });
    eventLocationMap.on('click', async (evt) => {
      await handleMapPick(evt, 'map_poi_click');
    });
  }
  eventLocationMap.resize();
  eventLocationSyncPinMarkerMode();
  if (initialPoint && initialPoint.location) {
    eventLocationSetPin(initialPoint, true);
  }
}

function closeEventLocationPickerModal() {
  const { overlay } = eventLocationModalEls();
  if (overlay) overlay.classList.remove('open');
  if (eventLocationMoveTimer) {
    clearTimeout(eventLocationMoveTimer);
    eventLocationMoveTimer = null;
  }
  eventLocationPickerState.mode = 'edit';
  eventLocationPickerState.provider = 'amap';
  eventLocationSetViewAnchorPoint(null);
  eventLocationSyncViewUi();
  eventLocationHidePoiPanel();
  eventLocationRemovePoiMarker();
  eventLocationPickerState.open = false;
  eventLocationSyncPinMarkerMode();
  eventLocationPickerState.onConfirm = null;
  eventLocationPickerState.panelEl = null;
  eventLocationPickerState.fest = null;
  eventLocationPickerState.composedQuery = '';
  eventLocationPickerState.composedQueryZh = '';
  eventLocationPickerState.composedQueryEn = '';
  eventLocationPickerState.selectedPoint = null;
  eventLocationPickerState.previewPoint = null;
  eventLocationPickerState.selectedCandidateIdx = -1;
  eventLocationPickerState.renderRows = [];
  eventLocationPickerState.candidates = [];
  eventLocationLastMapPickKey = '';
  eventLocationLastMapPickAt = 0;
}

function handleEventLocationPickerOverlayClick(event) {
  const { overlay } = eventLocationModalEls();
  if (!overlay) return;
  if (event?.target === overlay) closeEventLocationPickerModal();
}

function bindEventLocationModalActions() {
  const els = eventLocationModalEls();
  if (!els.overlay || els.overlay.dataset.bound === '1') return;
  els.overlay.dataset.bound = '1';
  if (els.searchBtn) {
    els.searchBtn.onclick = () => { eventLocationSearchByKeyword('manual_search'); };
  }
  if (els.searchInput) {
    els.searchInput.addEventListener('keydown', (e) => {
      if (e.key !== 'Enter') return;
      e.preventDefault();
      eventLocationSearchByKeyword('manual_search');
    });
  }
  if (els.fillZhBtn) {
    els.fillZhBtn.onclick = () => {
      const zhQuery = eventLocationGetComposedQueryByLocale('zh');
      if (!zhQuery) {
        eventLocationSetStatus('当前活动缺少可填入的中文地址信息', true);
        return;
      }
      if (els.searchInput) {
        els.searchInput.value = zhQuery;
        els.searchInput.focus();
      }
      eventLocationSetStatus('已填入中文地址，请手动点击搜索', false);
    };
  }
  if (els.fillEnBtn) {
    els.fillEnBtn.onclick = () => {
      const enQuery = eventLocationGetComposedQueryByLocale('en');
      if (!enQuery) {
        eventLocationSetStatus('当前活动缺少可填入的英文地址信息', true);
        return;
      }
      if (els.searchInput) {
        els.searchInput.value = enQuery;
        els.searchInput.focus();
      }
      eventLocationSetStatus('已填入英文地址，请手动点击搜索', false);
    };
  }
  if (els.myPosBtn) {
    els.myPosBtn.onclick = () => {
      eventLocationLocateMe();
    };
  }
  if (els.returnAnchorBtn) {
    els.returnAnchorBtn.onclick = () => {
      if (!eventLocationIsViewMode() || !eventLocationMap) return;
      const anchor = normalizeEventLocationPoint(eventLocationViewAnchorPoint);
      if (!anchor) {
        eventLocationSetStatus('当前活动尚未绑定活动场地', true);
        return;
      }
      eventLocationSetPin(anchor, true);
      eventLocationSetStatus('已回到活动场地', false);
    };
  }
  if (els.cancelBtn) {
    els.cancelBtn.onclick = () => closeEventLocationPickerModal();
  }
  if (els.poiPanelClose) {
    els.poiPanelClose.onclick = () => {
      if (eventLocationIsViewMode()) return;
      eventLocationHidePoiPanel();
    };
  }
  if (els.poiPanelBody) {
    els.poiPanelBody.addEventListener('click', (e) => {
      const photoBtn = e.target.closest('[data-poi-photo-idx]');
      if (!photoBtn) return;
      e.preventDefault();
      const idx = Number(photoBtn.getAttribute('data-poi-photo-idx'));
      if (!Number.isFinite(idx)) return;
      eventLocationOpenPoiPhotoLightbox(idx);
    });
  }
  if (els.confirmBtn) {
    els.confirmBtn.onclick = async () => {
      const point = eventLocationCurrentPoint();
      if (!point) {
        eventLocationSetStatus('请先在候选地点里点击“设为候选地址”再确认', true);
        return;
      }
      const prevText = String(els.confirmBtn.textContent || '');
      els.confirmBtn.disabled = true;
      eventLocationSetStatus('正在补齐地点信息（中英）...', false);
      try {
        let finalPoint = point;
        const provider = normalizeEventLocationProvider(point?.provider || eventLocationPickerState?.provider || 'amap');
        if (provider === 'mapkit' && typeof mapkitTryEnrichLocationPointEnglish === 'function') {
          try {
            finalPoint = await mapkitTryEnrichLocationPointEnglish(point);
          } catch (_error) {
            finalPoint = point;
          }
        } else if (provider === 'mapbox' && typeof mapboxTryEnrichLocationPointEnglish === 'function') {
          try {
            finalPoint = await mapboxTryEnrichLocationPointEnglish(point);
          } catch (_error) {
            finalPoint = point;
          }
        } else if (provider === 'geoapify' && typeof geoapifyTryEnrichLocationPointEnglish === 'function') {
          try {
            finalPoint = await geoapifyTryEnrichLocationPointEnglish(point);
          } catch (_error) {
            finalPoint = point;
          }
        } else if (typeof amapTryEnrichLocationPointEnglish === 'function') {
          try {
            finalPoint = await amapTryEnrichLocationPointEnglish(point);
          } catch (_error) {
            finalPoint = point;
          }
        }
        if (typeof eventLocationPickerState.onConfirm === 'function') {
          eventLocationPickerState.onConfirm(finalPoint);
        }
        closeEventLocationPickerModal();
      } catch (error) {
        eventLocationSetStatus(String(error?.message || '地点绑定失败，请重试'), true);
      } finally {
        els.confirmBtn.textContent = prevText || '确认绑定';
        els.confirmBtn.disabled = false;
      }
    };
  }
  if (els.candidates) {
    els.candidates.addEventListener('click', async (e) => {
      const btn = e.target.closest('[data-location-set-idx]');
      if (btn) {
        const idx = Number(btn.getAttribute('data-location-set-idx'));
        if (!Number.isFinite(idx)) return;
        const row = eventLocationPickerState.renderRows[idx];
        if (row) {
          await eventLocationSetSelectedPoint(row, { withPan: true, loadDetail: true, syncPreview: true });
          eventLocationSetStatus('已更新当前选定地址，可直接确认绑定', false);
        }
        return;
      }
      const card = e.target.closest('[data-location-candidate-idx]');
      if (!card) return;
      const idx = Number(card.getAttribute('data-location-candidate-idx'));
      if (!Number.isFinite(idx)) return;
      const row = eventLocationPickerState.renderRows[idx];
      if (!row) return;
      await eventLocationPreviewPoint(row, { withPan: true, loadDetail: true, prepend: true });
      eventLocationSetStatus('已切换 POI 预览；当前选定地址保持不变', false);
    });
  }
}

async function openEventLocationPickerModal(options = {}) {
  bindEventLocationModalActions();
  const els = eventLocationModalEls();
  if (!els.overlay) throw new Error('地图弹窗容器缺失');
  if (eventLocationMoveTimer) {
    clearTimeout(eventLocationMoveTimer);
    eventLocationMoveTimer = null;
  }
  const mode = String(options.mode || 'edit').trim() === 'view' ? 'view' : 'edit';
  const initialPoint = normalizeEventLocationPoint(options.initialPoint || null);
  const provider = normalizeEventLocationProvider(
    options.provider
    || initialPoint?.provider
    || eventLocationPickerState.provider
    || (typeof getPreferredEventLocationProvider === 'function' ? getPreferredEventLocationProvider() : 'amap')
    || 'amap'
  );
  eventLocationPickerState.open = true;
  eventLocationPickerState.mode = mode;
  eventLocationPickerState.provider = provider;
  eventLocationPickerState.panelEl = options.panelEl || null;
  eventLocationPickerState.fest = options.fest || null;
  eventLocationPickerState.onConfirm = typeof options.onConfirm === 'function' ? options.onConfirm : null;
  eventLocationPickerState.composedQuery = String(options.composedQuery || '').trim();
  eventLocationPickerState.composedQueryZh = String(options.composedQueryZh || '').trim();
  eventLocationPickerState.composedQueryEn = String(options.composedQueryEn || '').trim();
  eventLocationPickerState.selectedPoint = initialPoint;
  eventLocationPickerState.previewPoint = initialPoint;
  eventLocationPickerState.selectedCandidateIdx = -1;
  eventLocationPickerState.renderRows = [];
  eventLocationPickerState.candidates = mode === 'view' ? [] : (initialPoint ? [initialPoint] : []);
  eventLocationSetViewAnchorPoint(mode === 'view' ? initialPoint : null);
  eventLocationSyncViewUi();
  eventLocationSyncPinMarkerMode();
  if (els.title) {
    const providerLabel = typeof getEventLocationProviderLabel === 'function'
      ? getEventLocationProviderLabel(provider)
      : (provider === 'mapkit'
        ? 'Apple MapKit'
        : (provider === 'mapbox'
          ? 'Mapbox'
          : (provider === 'geoapify' ? 'Geoapify' : '高德地图')));
    els.title.textContent = mode === 'view' ? `活动地点查看（${providerLabel}）` : `活动地点绑定（${providerLabel}）`;
  }
  if (els.searchInput) {
    const viewAddressText = mode === 'view' ? eventLocationFormatAddressForSearchBox(initialPoint) : '';
    els.searchInput.value = mode === 'view'
      ? viewAddressText
      : String(options.initialQuery || '').trim();
    els.searchInput.disabled = mode === 'view';
    els.searchInput.readOnly = mode === 'view';
  }
  if (els.searchBtn) els.searchBtn.disabled = mode === 'view';
  if (els.fillZhBtn) els.fillZhBtn.style.display = mode === 'view' ? 'none' : '';
  if (els.fillEnBtn) els.fillEnBtn.style.display = mode === 'view' ? 'none' : '';
  if (els.confirmBtn) els.confirmBtn.style.display = mode === 'view' ? 'none' : '';
  if (els.candidates) els.candidates.style.display = mode === 'view' ? 'none' : '';
  els.overlay.classList.add('open');

  await ensureEventLocationMapReady(initialPoint);
  eventLocationSyncPinMarkerMode();
  if (mode !== 'view') eventLocationRenderCandidates();
  eventLocationSetStatus(mode === 'view' ? '可拖动地图浏览，并可随时回到活动场地' : '可搜索地点、拖动 Pin 并确认绑定', false);

  if (mode === 'view') {
    if (initialPoint) {
      eventLocationSetViewAnchorPoint(initialPoint);
      eventLocationSyncViewUi();
      eventLocationSetPin(initialPoint, true);
      eventLocationRemovePoiMarker();
      eventLocationPickerState.selectedPoint = initialPoint;
      eventLocationPickerState.previewPoint = initialPoint;
      await eventLocationLoadViewAnchorDetailsIntoPanel();
      return;
    }
    eventLocationSetViewAnchorPoint(null);
    eventLocationSyncViewUi();
    eventLocationHidePoiPanel();
    eventLocationRemovePoiMarker();
    eventLocationSetStatus('当前活动尚未绑定定位地点', true);
    return;
  }

  if (initialPoint) {
    await eventLocationResolveByPoint(initialPoint, initialPoint.sourceMode || 'manual_search', { keepFirstPoint: true });
    return;
  }
  const center = eventLocationMap?.getCenter?.();
  if (center) {
    await eventLocationResolveByPoint(
      {
        provider,
        sourceMode: 'pin_drag',
        location: { lng: center.lng, lat: center.lat },
        nameI18n: { zh: '', en: '' },
        addressI18n: { zh: '', en: '' },
        formattedAddressI18n: { zh: '', en: '' },
      },
      'pin_drag'
    );
  }
}
