// Event location: manual point entry + location reuse modal
const eventLocationManualModalState = {
  open: false,
  panelEl: null,
  fest: null,
  onConfirm: null,
  bound: false,
};

const eventLocationReuseModalState = {
  open: false,
  panelEl: null,
  fest: null,
  onApplyCurrent: null,
  sourceEventId: '',
  targetEventIds: new Set(),
  sourceQuery: '',
  targetQuery: '',
  bound: false,
  applying: false,
};

function eventLocationManualEls() {
  return {
    overlay: document.getElementById('event-location-manual-overlay'),
    provider: document.getElementById('event-location-manual-provider'),
    sourceMode: document.getElementById('event-location-manual-source-mode'),
    lng: document.getElementById('event-location-manual-lng'),
    lat: document.getElementById('event-location-manual-lat'),
    nameZh: document.getElementById('event-location-manual-name-zh'),
    nameEn: document.getElementById('event-location-manual-name-en'),
    addrZh: document.getElementById('event-location-manual-address-zh'),
    addrEn: document.getElementById('event-location-manual-address-en'),
    formattedZh: document.getElementById('event-location-manual-formatted-zh'),
    formattedEn: document.getElementById('event-location-manual-formatted-en'),
    countryCode: document.getElementById('event-location-manual-country-code'),
    city: document.getElementById('event-location-manual-city'),
    district: document.getElementById('event-location-manual-district'),
    province: document.getElementById('event-location-manual-province'),
    providerPlaceId: document.getElementById('event-location-manual-provider-place-id'),
    poiId: document.getElementById('event-location-manual-poi-id'),
    adcode: document.getElementById('event-location-manual-adcode'),
    mapkitId: document.getElementById('event-location-manual-mapkit-id'),
    mapboxId: document.getElementById('event-location-manual-mapbox-id'),
    mapboxType: document.getElementById('event-location-manual-mapbox-type'),
    geoapifyId: document.getElementById('event-location-manual-geoapify-id'),
    geoapifyType: document.getElementById('event-location-manual-geoapify-type'),
    googleId: document.getElementById('event-location-manual-google-id'),
    googleTypes: document.getElementById('event-location-manual-google-types'),
    status: document.getElementById('event-location-manual-status'),
    normalizeBtn: document.getElementById('event-location-manual-normalize-btn'),
    cancelBtn: document.getElementById('event-location-manual-cancel-btn'),
    confirmBtn: document.getElementById('event-location-manual-confirm-btn'),
  };
}

function eventLocationReuseEls() {
  return {
    overlay: document.getElementById('event-location-reuse-overlay'),
    sourceSearch: document.getElementById('event-location-reuse-source-search'),
    targetSearch: document.getElementById('event-location-reuse-target-search'),
    sourceList: document.getElementById('event-location-reuse-source-list'),
    targetList: document.getElementById('event-location-reuse-target-list'),
    status: document.getElementById('event-location-reuse-status'),
    applyCurrentBtn: document.getElementById('event-location-reuse-apply-current-btn'),
    applyBatchBtn: document.getElementById('event-location-reuse-apply-batch-btn'),
  };
}

function eventLocationManualSetStatus(text, isError = false) {
  const { status } = eventLocationManualEls();
  if (!status) return;
  status.textContent = String(text || '');
  status.classList.toggle('error', !!isError);
}

function eventLocationReuseSetStatus(text, isError = false) {
  const { status } = eventLocationReuseEls();
  if (!status) return;
  status.textContent = String(text || '');
  status.classList.toggle('error', !!isError);
}

function eventLocationReadFormFieldValue(field) {
  return String(field?.value || '').trim();
}

function eventLocationReadPanelFieldValue(panelEl, key) {
  return String(panelEl?.querySelector(`.fest-info-edit [data-field="${key}"]`)?.value || '').trim();
}

function eventLocationManualFillForm(point, options = {}) {
  const els = eventLocationManualEls();
  const p = normalizeEventLocationPoint(point);
  const provider = normalizeEventLocationProvider(
    String(options.provider || p?.provider || 'amap').trim() || 'amap'
  );
  const sourceMode = String(options.sourceMode || p?.sourceMode || 'manual_input').trim() || 'manual_input';
  const panelEl = options.panelEl || null;

  const countryZh = eventLocationReadPanelFieldValue(panelEl, 'countryZh');
  const countryEn = eventLocationReadPanelFieldValue(panelEl, 'countryEn');
  const cityZh = eventLocationReadPanelFieldValue(panelEl, 'cityZh');
  const cityEn = eventLocationReadPanelFieldValue(panelEl, 'cityEn');
  const detailZh = eventLocationReadPanelFieldValue(panelEl, 'detailAddressZh');
  const detailEn = eventLocationReadPanelFieldValue(panelEl, 'detailAddressEn');

  const fallbackFormattedZh = [countryZh, cityZh, detailZh].filter(Boolean).join(' · ');
  const fallbackFormattedEn = [countryEn, cityEn, detailEn].filter(Boolean).join(' · ');

  if (els.provider) els.provider.value = provider;
  if (els.sourceMode) els.sourceMode.value = sourceMode;
  if (els.lng) els.lng.value = p ? String(Number(p.location.lng)) : '';
  if (els.lat) els.lat.value = p ? String(Number(p.location.lat)) : '';
  if (els.nameZh) els.nameZh.value = p?.nameI18n?.zh || '';
  if (els.nameEn) els.nameEn.value = p?.nameI18n?.en || '';
  if (els.addrZh) els.addrZh.value = p?.addressI18n?.zh || '';
  if (els.addrEn) els.addrEn.value = p?.addressI18n?.en || '';
  if (els.formattedZh) els.formattedZh.value = p?.formattedAddressI18n?.zh || fallbackFormattedZh || '';
  if (els.formattedEn) els.formattedEn.value = p?.formattedAddressI18n?.en || fallbackFormattedEn || '';
  if (els.countryCode) els.countryCode.value = p?.countryCode || '';
  if (els.city) els.city.value = p?.city || cityEn || cityZh || '';
  if (els.district) els.district.value = p?.district || '';
  if (els.province) els.province.value = p?.province || '';
  if (els.providerPlaceId) els.providerPlaceId.value = p?.providerPlaceId || '';
  if (els.poiId) els.poiId.value = p?.poiId || '';
  if (els.adcode) els.adcode.value = p?.adcode || '';
  if (els.mapkitId) els.mapkitId.value = p?.providerMeta?.mapkit?.mapItemIdentifier || '';
  if (els.mapboxId) els.mapboxId.value = p?.providerMeta?.mapbox?.placeId || '';
  if (els.mapboxType) els.mapboxType.value = p?.providerMeta?.mapbox?.featureType || '';
  if (els.geoapifyId) els.geoapifyId.value = p?.providerMeta?.geoapify?.placeId || '';
  if (els.geoapifyType) els.geoapifyType.value = p?.providerMeta?.geoapify?.featureType || '';
  if (els.googleId) els.googleId.value = p?.providerMeta?.google?.placeId || '';
  if (els.googleTypes) els.googleTypes.value = Array.isArray(p?.providerMeta?.google?.types)
    ? p.providerMeta.google.types.join(',')
    : '';
}

function eventLocationParseManualFormToPoint() {
  const els = eventLocationManualEls();
  const lng = Number(eventLocationReadFormFieldValue(els.lng));
  const lat = Number(eventLocationReadFormFieldValue(els.lat));
  if (!Number.isFinite(lng) || !Number.isFinite(lat)) {
    return { point: null, error: '经纬度必须是有效数字。' };
  }

  const provider = normalizeEventLocationProvider(eventLocationReadFormFieldValue(els.provider) || 'amap');
  const sourceMode = eventLocationReadFormFieldValue(els.sourceMode) || 'manual_input';
  const providerPlaceId = eventLocationReadFormFieldValue(els.providerPlaceId);
  const poiId = eventLocationReadFormFieldValue(els.poiId);
  const adcode = eventLocationReadFormFieldValue(els.adcode);
  const mapkitId = eventLocationReadFormFieldValue(els.mapkitId);
  const mapboxId = eventLocationReadFormFieldValue(els.mapboxId);
  const mapboxType = eventLocationReadFormFieldValue(els.mapboxType);
  const geoapifyId = eventLocationReadFormFieldValue(els.geoapifyId);
  const geoapifyType = eventLocationReadFormFieldValue(els.geoapifyType);
  const googleId = eventLocationReadFormFieldValue(els.googleId);
  const googleTypes = eventLocationReadFormFieldValue(els.googleTypes)
    .split(',')
    .map((item) => String(item || '').trim())
    .filter(Boolean)
    .slice(0, 20);

  const providerMeta = {};
  if (poiId || adcode) {
    providerMeta.amap = {
      poiId: poiId || '',
      adcode: adcode || '',
    };
  }
  if (mapkitId) {
    providerMeta.mapkit = { mapItemIdentifier: mapkitId };
  }
  if (mapboxId || mapboxType) {
    providerMeta.mapbox = { placeId: mapboxId || '', featureType: mapboxType || '' };
  }
  if (geoapifyId || geoapifyType) {
    providerMeta.geoapify = { placeId: geoapifyId || '', featureType: geoapifyType || '' };
  }
  if (googleId || googleTypes.length) {
    providerMeta.google = { placeId: googleId || '', types: googleTypes };
  }

  const raw = {
    provider,
    sourceMode,
    providerPlaceId: providerPlaceId || '',
    poiId: poiId || '',
    adcode: adcode || '',
    location: {
      lng,
      lat,
    },
    nameI18n: {
      zh: eventLocationReadFormFieldValue(els.nameZh),
      en: eventLocationReadFormFieldValue(els.nameEn),
    },
    addressI18n: {
      zh: eventLocationReadFormFieldValue(els.addrZh),
      en: eventLocationReadFormFieldValue(els.addrEn),
    },
    formattedAddressI18n: {
      zh: eventLocationReadFormFieldValue(els.formattedZh),
      en: eventLocationReadFormFieldValue(els.formattedEn),
    },
    countryCode: eventLocationReadFormFieldValue(els.countryCode).toUpperCase(),
    city: eventLocationReadFormFieldValue(els.city),
    district: eventLocationReadFormFieldValue(els.district),
    province: eventLocationReadFormFieldValue(els.province),
    providerMeta: Object.keys(providerMeta).length ? providerMeta : null,
    selectedAt: new Date().toISOString(),
  };

  const point = normalizeEventLocationPoint(raw);
  if (!point) return { point: null, error: '定位信息格式不完整，请检查经纬度与字段内容。' };
  return { point, error: '' };
}

function eventLocationManualReadPanelBiField(panelEl, keyEn, keyZh, fallback = '') {
  const en = eventLocationReadPanelFieldValue(panelEl, keyEn);
  const zh = eventLocationReadPanelFieldValue(panelEl, keyZh);
  const seed = String(fallback || '').trim();
  const bi = typeof normalizeBiTextValue === 'function'
    ? normalizeBiTextValue({ en, zh }, seed)
    : { en: en || seed, zh: zh || en || seed };
  return {
    en: String(bi?.en || '').trim(),
    zh: String(bi?.zh || '').trim(),
  };
}

function eventLocationManualBuildNormalizeContext(point) {
  const panelEl = eventLocationManualModalState.panelEl || null;
  const fest = eventLocationManualModalState.fest || null;
  const info = (fest && typeof fest.info === 'object') ? fest.info : {};
  const nameFallback = (typeof normalizeBiTextValue === 'function')
    ? normalizeBiTextValue(info?.nameI18n ?? info?.name ?? fest?.name ?? '', fest?.name || '')
    : {
        en: String(info?.nameI18n?.en || info?.name || fest?.name || '').trim(),
        zh: String(info?.nameI18n?.zh || info?.name || fest?.name || '').trim(),
      };
  const cityFallback = (typeof normalizeBiTextValue === 'function')
    ? normalizeBiTextValue(info?.cityI18n ?? info?.city ?? '', info?.city || '')
    : {
        en: String(info?.cityI18n?.en || info?.city || '').trim(),
        zh: String(info?.cityI18n?.zh || info?.city || '').trim(),
      };
  const countryFallback = (typeof normalizeCountryBiTextValue === 'function')
    ? normalizeCountryBiTextValue(info?.countryI18n ?? info?.country ?? '', info?.country || '')
    : {
        en: String(info?.countryI18n?.en || info?.country || '').trim(),
        zh: String(info?.countryI18n?.zh || info?.country || '').trim(),
        enFull: String(info?.countryI18n?.enFull || info?.country || '').trim(),
      };
  const detailFallback = (typeof normalizeBiTextValue === 'function')
    ? normalizeBiTextValue(info?.manualLocation?.detailAddressI18n ?? '', '')
    : {
        en: String(info?.manualLocation?.detailAddressI18n?.en || '').trim(),
        zh: String(info?.manualLocation?.detailAddressI18n?.zh || '').trim(),
      };

  return {
    eventId: String(fest?.backendEventId || info?.backendEventId || '').trim(),
    eventNameI18n: eventLocationManualReadPanelBiField(
      panelEl,
      'nameEn',
      'nameZh',
      String(nameFallback?.zh || nameFallback?.en || '').trim()
    ),
    cityI18n: eventLocationManualReadPanelBiField(
      panelEl,
      'cityEn',
      'cityZh',
      String(cityFallback?.zh || cityFallback?.en || '').trim()
    ),
    detailAddressI18n: eventLocationManualReadPanelBiField(
      panelEl,
      'detailAddressEn',
      'detailAddressZh',
      String(detailFallback?.zh || detailFallback?.en || '').trim()
    ),
    countryI18n: {
      en: eventLocationReadPanelFieldValue(panelEl, 'countryEn')
        || String(countryFallback?.en || '').trim(),
      zh: eventLocationReadPanelFieldValue(panelEl, 'countryZh')
        || String(countryFallback?.zh || '').trim(),
      enFull: eventLocationReadPanelFieldValue(panelEl, 'countryEnFull')
        || String(countryFallback?.enFull || '').trim(),
    },
    currentLocationPoint: point,
  };
}

function eventLocationManualPickFirstNonEmpty(...values) {
  for (const raw of values) {
    const text = String(raw || '').trim();
    if (text) return text;
  }
  return '';
}

function eventLocationManualMergeNormalizedPoint(currentPoint, normalizedPoint) {
  const current = normalizeEventLocationPoint(currentPoint);
  if (!current) return null;
  const normalized = (normalizedPoint && typeof normalizedPoint === 'object') ? normalizedPoint : {};
  const merged = normalizeEventLocationPoint({
    ...current,
    nameI18n: {
      zh: eventLocationManualPickFirstNonEmpty(normalized?.nameI18n?.zh, current?.nameI18n?.zh),
      en: eventLocationManualPickFirstNonEmpty(normalized?.nameI18n?.en, current?.nameI18n?.en),
    },
    addressI18n: {
      zh: eventLocationManualPickFirstNonEmpty(normalized?.addressI18n?.zh, current?.addressI18n?.zh),
      en: eventLocationManualPickFirstNonEmpty(normalized?.addressI18n?.en, current?.addressI18n?.en),
    },
    formattedAddressI18n: {
      zh: eventLocationManualPickFirstNonEmpty(
        normalized?.formattedAddressI18n?.zh,
        current?.formattedAddressI18n?.zh
      ),
      en: eventLocationManualPickFirstNonEmpty(
        normalized?.formattedAddressI18n?.en,
        current?.formattedAddressI18n?.en
      ),
    },
    countryCode: eventLocationManualPickFirstNonEmpty(
      String(normalized?.countryCode || '').toUpperCase(),
      String(current?.countryCode || '').toUpperCase()
    ),
    city: eventLocationManualPickFirstNonEmpty(normalized?.city, current?.city),
    district: eventLocationManualPickFirstNonEmpty(normalized?.district, current?.district),
    province: eventLocationManualPickFirstNonEmpty(normalized?.province, current?.province),
  });
  return merged || current;
}

function eventLocationManualBuildDiffRows(beforePoint, afterPoint) {
  const before = normalizeEventLocationPoint(beforePoint);
  const after = normalizeEventLocationPoint(afterPoint);
  if (!before || !after) return [];
  const fields = [
    ['nameI18n.zh', before?.nameI18n?.zh, after?.nameI18n?.zh],
    ['nameI18n.en', before?.nameI18n?.en, after?.nameI18n?.en],
    ['addressI18n.zh', before?.addressI18n?.zh, after?.addressI18n?.zh],
    ['addressI18n.en', before?.addressI18n?.en, after?.addressI18n?.en],
    ['formattedAddressI18n.zh', before?.formattedAddressI18n?.zh, after?.formattedAddressI18n?.zh],
    ['formattedAddressI18n.en', before?.formattedAddressI18n?.en, after?.formattedAddressI18n?.en],
    ['countryCode', before?.countryCode, after?.countryCode],
    ['city', before?.city, after?.city],
    ['district', before?.district, after?.district],
    ['province', before?.province, after?.province],
  ];
  const rows = [];
  for (const [field, prev, next] of fields) {
    const prevText = String(prev || '').trim();
    const nextText = String(next || '').trim();
    if (prevText === nextText) continue;
    rows.push({
      field: String(field),
      before: prevText || '(空)',
      after: nextText || '(空)',
    });
  }
  return rows;
}

function eventLocationManualApplyDiffRows(basePoint, diffRows, pickedItems = []) {
  const point = normalizeEventLocationPoint(basePoint);
  if (!point) return null;
  const selectedMap = new Map();
  for (const item of (Array.isArray(pickedItems) ? pickedItems : [])) {
    const field = String(item?.field || '').trim();
    if (!field) continue;
    selectedMap.set(field, String(item?.afterRaw ?? '').trim());
  }
  const sourceRows = (Array.isArray(diffRows) ? diffRows : []).filter(Boolean);
  const rowsToApply = selectedMap.size
    ? sourceRows.filter((row) => selectedMap.has(String(row?.field || '').trim()))
    : sourceRows;
  if (!rowsToApply.length) return point;

  const out = JSON.parse(JSON.stringify(point));
  const pickAfter = (row) => {
    const field = String(row?.field || '').trim();
    if (!field) return '';
    if (selectedMap.has(field)) return String(selectedMap.get(field) || '').trim();
    const text = String(row?.afterRaw ?? row?.after ?? '').trim();
    if (text === '(空)' || text === '（空）') return '';
    return text;
  };

  rowsToApply.forEach((row) => {
    const field = String(row?.field || '').trim();
    const value = pickAfter(row);
    if (!field) return;
    if (field === 'nameI18n.zh') out.nameI18n.zh = value;
    else if (field === 'nameI18n.en') out.nameI18n.en = value;
    else if (field === 'addressI18n.zh') out.addressI18n.zh = value;
    else if (field === 'addressI18n.en') out.addressI18n.en = value;
    else if (field === 'formattedAddressI18n.zh') out.formattedAddressI18n.zh = value;
    else if (field === 'formattedAddressI18n.en') out.formattedAddressI18n.en = value;
    else if (field === 'countryCode') out.countryCode = value.toUpperCase();
    else if (field === 'city') out.city = value;
    else if (field === 'district') out.district = value;
    else if (field === 'province') out.province = value;
  });

  return normalizeEventLocationPoint(out) || point;
}

async function eventLocationManualNormalizeWithCoze() {
  const { normalizeBtn } = eventLocationManualEls();
  const parsed = eventLocationParseManualFormToPoint();
  if (!parsed.point) {
    eventLocationManualSetStatus(parsed.error || '请先填写有效经纬度后再执行 Coze 规范化。', true);
    return;
  }
  const context = eventLocationManualBuildNormalizeContext(parsed.point);

  const originalText = normalizeBtn ? String(normalizeBtn.textContent || '').trim() : '';
  if (normalizeBtn) {
    normalizeBtn.disabled = true;
    normalizeBtn.textContent = '处理中...';
  }
  eventLocationManualSetStatus('正在调用 Coze 规范化定位字段...');

  try {
    const resp = await apiPost('/api/coze/normalize-event-location', {
      location: parsed.point,
      context,
    });
    const normalized = (resp && typeof resp.normalized === 'object') ? resp.normalized : {};
    const mergedPoint = eventLocationManualMergeNormalizedPoint(parsed.point, normalized);
    if (!mergedPoint) {
      eventLocationManualSetStatus('Coze 返回格式不可用，未应用修改。', true);
      return;
    }
    const diffRows = eventLocationManualBuildDiffRows(parsed.point, mergedPoint);
    if (!diffRows.length) {
      eventLocationManualSetStatus('Coze 返回成功：字段无变更。');
      return;
    }

    let confirmed = true;
    let pickedItems = [];
    if (typeof eventEditShowTranslateConfirmModal === 'function') {
      const confirmResult = await eventEditShowTranslateConfirmModal(
        diffRows.map((item) => ({
          field: item.field,
          lang: 'location',
          before: item.before,
          after: item.after,
          beforeRaw: String(item?.before || '').trim() === '(空)' ? '' : String(item?.before || '').trim(),
          afterRaw: String(item?.after || '').trim() === '(空)' ? '' : String(item?.after || '').trim(),
        }))
      , {
        title: '定位字段规范化确认',
        subtitle: '可勾选要应用的字段，并直接编辑每条结果内容。',
      }
      );
      confirmed = !!confirmResult?.confirmed;
      pickedItems = (Array.isArray(confirmResult?.items) ? confirmResult.items : []).filter((item) => item?.selected);
    } else {
      const preview = diffRows.slice(0, 8).map((row) => `${row.field}: ${row.before} -> ${row.after}`).join('\n');
      confirmed = window.confirm(`检测到 ${diffRows.length} 处变化，是否应用？\n\n${preview}`);
      pickedItems = diffRows.map((row) => ({
        field: row.field,
        afterRaw: String(row?.after || '').trim() === '(空)' ? '' : String(row?.after || '').trim(),
      }));
    }

    if (!confirmed) {
      eventLocationManualSetStatus('已取消应用 Coze 规范化结果。');
      return;
    }
    if (!pickedItems.length) {
      eventLocationManualSetStatus('未选择任何字段，未应用 Coze 规范化结果。');
      return;
    }

    const appliedPoint = eventLocationManualApplyDiffRows(mergedPoint, diffRows, pickedItems);
    if (!appliedPoint) {
      eventLocationManualSetStatus('应用结果失败，定位字段未更新。', true);
      return;
    }

    eventLocationManualFillForm(appliedPoint, {
      provider: parsed.point.provider,
      sourceMode: parsed.point.sourceMode,
      panelEl: eventLocationManualModalState.panelEl,
    });
    const issues = Array.isArray(resp?.issues) ? resp.issues.filter(Boolean) : [];
    const issueText = issues.length ? `（提示：${String(issues[0]).trim()}）` : '';
    eventLocationManualSetStatus(`已应用定位字段规范化结果，共更新 ${pickedItems.length} 个字段${issueText}`);
  } catch (error) {
    eventLocationManualSetStatus(`定位字段规范化失败：${error?.message || '未知错误'}`, true);
  } finally {
    if (normalizeBtn) {
      normalizeBtn.disabled = false;
      normalizeBtn.textContent = originalText || '规范化定位字段';
    }
  }
}

function eventLocationEnsureManualModalBound() {
  if (eventLocationManualModalState.bound) return;
  const els = eventLocationManualEls();
  if (!els.overlay) return;
  if (els.normalizeBtn) {
    els.normalizeBtn.onclick = () => {
      eventLocationManualNormalizeWithCoze();
    };
  }
  if (els.cancelBtn) {
    els.cancelBtn.onclick = () => closeEventLocationManualModal();
  }
  if (els.confirmBtn) {
    els.confirmBtn.onclick = () => {
      const parsed = eventLocationParseManualFormToPoint();
      if (!parsed.point) {
        eventLocationManualSetStatus(parsed.error || '填写内容无效。', true);
        return;
      }
      if (typeof eventLocationManualModalState.onConfirm === 'function') {
        eventLocationManualModalState.onConfirm(parsed.point);
      }
      closeEventLocationManualModal();
    };
  }
  eventLocationManualModalState.bound = true;
}

function openEventLocationManualEntryModal(options = {}) {
  eventLocationEnsureManualModalBound();
  const { overlay } = eventLocationManualEls();
  if (!overlay) return;
  eventLocationManualModalState.open = true;
  eventLocationManualModalState.panelEl = options.panelEl || null;
  eventLocationManualModalState.fest = options.fest || null;
  eventLocationManualModalState.onConfirm = (typeof options.onConfirm === 'function') ? options.onConfirm : null;
  eventLocationManualFillForm(options.initialPoint || null, {
    provider: options.provider || '',
    panelEl: options.panelEl || null,
  });
  eventLocationManualSetStatus('可手动填写来源、经纬度、地点名称等字段，确认后写入当前活动。');
  overlay.classList.add('open');
}

function closeEventLocationManualModal() {
  const { overlay } = eventLocationManualEls();
  if (overlay) overlay.classList.remove('open');
  eventLocationManualModalState.open = false;
  eventLocationManualModalState.panelEl = null;
  eventLocationManualModalState.fest = null;
  eventLocationManualModalState.onConfirm = null;
}

function handleEventLocationManualOverlayClick(event) {
  const { overlay } = eventLocationManualEls();
  if (event?.target === overlay) closeEventLocationManualModal();
}

function eventLocationFlattenFestRows() {
  const rows = [];
  for (const yearData of Object.values(allData || {})) {
    for (const monthRows of Object.values(yearData || {})) {
      if (!Array.isArray(monthRows)) continue;
      for (const fest of monthRows) {
        const eventId = String(fest?.backendEventId || fest?.info?.backendEventId || '').trim();
        if (!eventId) continue;
        const info = (fest && typeof fest.info === 'object') ? fest.info : {};
        const nameBi = normalizeBiTextValue(info.nameI18n ?? info.name ?? fest?.name ?? '', fest?.name || '');
        const name = String(nameBi.zh || nameBi.en || fest?.name || '').trim() || '(Unnamed Event)';
        const addrZh = typeof formatFestivalUnifiedAddress === 'function'
          ? formatFestivalUnifiedAddress({ ...info, addressLang: 'zh' })
          : '';
        const addrEn = typeof formatFestivalUnifiedAddress === 'function'
          ? formatFestivalUnifiedAddress({ ...info, addressLang: 'en' })
          : '';
        const date = formatDateRange(info?.startDate, info?.endDate);
        const locationPoint = normalizeEventLocationPoint(info?.locationPoint || null);
        const provider = String(locationPoint?.provider || '').trim();
        const searchText = [
          eventId,
          name,
          String(nameBi.en || '').trim(),
          String(nameBi.zh || '').trim(),
          String(addrZh || '').trim(),
          String(addrEn || '').trim(),
          String(info?.city || '').trim(),
          String(info?.country || '').trim(),
          String(info?.cityI18n?.en || '').trim(),
          String(info?.cityI18n?.zh || '').trim(),
          String(info?.countryI18n?.en || '').trim(),
          String(info?.countryI18n?.zh || '').trim(),
        ].join(' ').toLowerCase();
        rows.push({
          eventId,
          fest,
          name,
          date,
          addrZh: String(addrZh || '').trim(),
          addrEn: String(addrEn || '').trim(),
          locationPoint,
          hasLocationPoint: !!locationPoint,
          provider,
          searchText,
        });
      }
    }
  }
  rows.sort((a, b) => {
    if (a.date && b.date && a.date !== b.date) return b.date.localeCompare(a.date);
    return a.name.localeCompare(b.name, 'en');
  });
  return rows;
}

function eventLocationReuseGetSourceRow() {
  const sourceId = String(eventLocationReuseModalState.sourceEventId || '').trim();
  if (!sourceId) return null;
  return eventLocationFlattenFestRows().find((row) => row.eventId === sourceId && row.hasLocationPoint) || null;
}

function eventLocationReuseRenderEmpty(el, text) {
  if (!el) return;
  el.innerHTML = `<div class="event-location-reuse-empty">${escapeHtml(String(text || '暂无数据'))}</div>`;
}

function eventLocationReuseRenderSourceList() {
  const { sourceList } = eventLocationReuseEls();
  if (!sourceList) return;
  const query = String(eventLocationReuseModalState.sourceQuery || '').trim().toLowerCase();
  const rows = eventLocationFlattenFestRows().filter((row) => row.hasLocationPoint);
  const filtered = query ? rows.filter((row) => row.searchText.includes(query)) : rows;
  if (!filtered.length) {
    eventLocationReuseRenderEmpty(sourceList, query ? '未找到符合条件的来源活动' : '暂无带定位信息的活动');
    return;
  }
  sourceList.innerHTML = filtered.map((row) => {
    const selected = row.eventId === eventLocationReuseModalState.sourceEventId;
    const point = normalizeEventLocationPoint(row.locationPoint);
    const provider = String(point?.provider || row.provider || '').trim() || '-';
    const pointName = String(point?.nameI18n?.zh || point?.nameI18n?.en || '').trim() || '无地点名';
    return `
      <div class="event-location-reuse-item ${selected ? 'selected' : ''}" data-reuse-source-id="${escapeHtml(row.eventId)}">
        <div class="event-location-reuse-item-title">${escapeHtml(row.name)}</div>
        <div class="event-location-reuse-item-meta">${escapeHtml(row.date || '日期未知')} · ${escapeHtml(pointName)}</div>
        <div class="event-location-reuse-item-meta">${escapeHtml(row.addrZh || row.addrEn || '-')}</div>
        <div class="event-location-reuse-item-badges">
          <span class="event-location-reuse-badge">${escapeHtml(provider)}</span>
          <span class="event-location-reuse-badge">${escapeHtml(row.eventId)}</span>
        </div>
      </div>
    `;
  }).join('');
}

function eventLocationReuseRenderTargetList() {
  const { targetList } = eventLocationReuseEls();
  if (!targetList) return;
  const query = String(eventLocationReuseModalState.targetQuery || '').trim().toLowerCase();
  const rows = eventLocationFlattenFestRows();
  const filtered = query ? rows.filter((row) => row.searchText.includes(query)) : rows;
  if (!filtered.length) {
    eventLocationReuseRenderEmpty(targetList, query ? '未找到符合条件的目标活动' : '暂无活动数据');
    return;
  }
  targetList.innerHTML = filtered.map((row) => {
    const selected = eventLocationReuseModalState.targetEventIds.has(row.eventId);
    const pointName = row.hasLocationPoint
      ? String(row.locationPoint?.nameI18n?.zh || row.locationPoint?.nameI18n?.en || '').trim() || '已绑定'
      : '未绑定';
    return `
      <div class="event-location-reuse-item ${selected ? 'selected' : ''}" data-reuse-target-id="${escapeHtml(row.eventId)}">
        <div class="event-location-reuse-item-title">${escapeHtml(row.name)}</div>
        <div class="event-location-reuse-item-meta">${escapeHtml(row.date || '日期未知')} · ${escapeHtml(pointName)}</div>
        <div class="event-location-reuse-item-meta">${escapeHtml(row.addrZh || row.addrEn || '-')}</div>
        <div class="event-location-reuse-item-badges">
          <span class="event-location-reuse-badge">${escapeHtml(row.eventId)}</span>
          <span class="event-location-reuse-badge ${row.hasLocationPoint ? '' : 'empty'}">${row.hasLocationPoint ? 'HAS_POINT' : 'NO_POINT'}</span>
        </div>
      </div>
    `;
  }).join('');
}

function eventLocationReuseSyncActionButtons() {
  const { applyCurrentBtn, applyBatchBtn } = eventLocationReuseEls();
  const hasSource = !!eventLocationReuseGetSourceRow();
  const hasTargets = eventLocationReuseModalState.targetEventIds.size > 0;
  if (applyCurrentBtn) applyCurrentBtn.disabled = eventLocationReuseModalState.applying || !hasSource;
  if (applyBatchBtn) applyBatchBtn.disabled = eventLocationReuseModalState.applying || !hasSource || !hasTargets;
}

function eventLocationReuseRenderAll() {
  eventLocationReuseRenderSourceList();
  eventLocationReuseRenderTargetList();
  eventLocationReuseSyncActionButtons();
  const hasSource = !!eventLocationReuseGetSourceRow();
  const targetCount = eventLocationReuseModalState.targetEventIds.size;
  if (!hasSource) {
    eventLocationReuseSetStatus('请先在左侧选择 1 个定位来源活动。');
    return;
  }
  eventLocationReuseSetStatus(`已选择来源，可批量覆盖 ${targetCount} 个目标活动。`);
}

function eventLocationFindFestByEventId(eventId) {
  const id = String(eventId || '').trim();
  if (!id) return null;
  for (const yearData of Object.values(allData || {})) {
    for (const monthRows of Object.values(yearData || {})) {
      if (!Array.isArray(monthRows)) continue;
      for (const fest of monthRows) {
        const backendId = String(fest?.backendEventId || fest?.info?.backendEventId || '').trim();
        if (backendId && backendId === id) return fest;
      }
    }
  }
  return null;
}

async function eventLocationReuseApplyToTargets() {
  if (eventLocationReuseModalState.applying) return;
  const sourceRow = eventLocationReuseGetSourceRow();
  if (!sourceRow?.locationPoint) {
    eventLocationReuseSetStatus('请先选择有效的来源活动。', true);
    return;
  }
  const targetIds = [...eventLocationReuseModalState.targetEventIds]
    .map((item) => String(item || '').trim())
    .filter(Boolean);
  if (!targetIds.length) {
    eventLocationReuseSetStatus('请在右侧至少选择 1 个目标活动。', true);
    return;
  }

  const authHeaders = getViewerAuthHeaders();
  if (!authHeaders.Authorization) {
    eventLocationReuseSetStatus('请先登录后再执行批量复用。', true);
    openViewerLogin();
    return;
  }

  const sure = window.confirm(`将来源活动定位信息覆盖到 ${targetIds.length} 个目标活动，是否继续？`);
  if (!sure) return;

  eventLocationReuseModalState.applying = true;
  eventLocationReuseSyncActionButtons();
  eventLocationReuseSetStatus('正在批量写入定位信息...');

  let success = 0;
  let failed = 0;
  const sourcePoint = normalizeEventLocationPoint(sourceRow.locationPoint);
  for (const eventId of targetIds) {
    try {
      const resp = await apiPost(
        `/api/raver/events/${encodeURIComponent(eventId)}/update`,
        {
          locationPoint: sourcePoint,
          latitude: sourcePoint.location.lat,
          longitude: sourcePoint.location.lng,
        },
        authHeaders
      );
      const updated = resp?.data || resp || null;
      const targetFest = eventLocationFindFestByEventId(eventId);
      if (targetFest && updated && typeof patchFestivalFromBackendEvent === 'function') {
        patchFestivalFromBackendEvent(targetFest, updated);
      } else if (targetFest) {
        targetFest.info = normalizeFestivalInfo({
          ...(targetFest.info || {}),
          locationPoint: sourcePoint,
          latitude: sourcePoint.location.lat,
          longitude: sourcePoint.location.lng,
        }, targetFest.info || {});
      }
      success += 1;
    } catch (_error) {
      failed += 1;
    }
  }

  const currentFestId = String(eventLocationReuseModalState.fest?.backendEventId || '').trim();
  if (
    currentFestId
    && eventLocationReuseModalState.targetEventIds.has(currentFestId)
    && typeof eventLocationReuseModalState.onApplyCurrent === 'function'
  ) {
    eventLocationReuseModalState.onApplyCurrent(sourcePoint);
  }

  eventLocationReuseModalState.applying = false;
  eventLocationReuseSyncActionButtons();
  if (failed > 0) {
    eventLocationReuseSetStatus(`批量复用完成：成功 ${success}，失败 ${failed}。`, true);
  } else {
    eventLocationReuseSetStatus(`批量复用完成：成功 ${success}。`);
  }
  eventLocationReuseRenderSourceList();
  eventLocationReuseRenderTargetList();
}

function eventLocationReuseApplyToCurrentPanel() {
  const sourceRow = eventLocationReuseGetSourceRow();
  if (!sourceRow?.locationPoint) {
    eventLocationReuseSetStatus('请先在左侧选择来源活动。', true);
    return;
  }
  if (typeof eventLocationReuseModalState.onApplyCurrent !== 'function') {
    eventLocationReuseSetStatus('当前没有可写入的编辑表单。', true);
    return;
  }
  const point = normalizeEventLocationPoint(sourceRow.locationPoint);
  eventLocationReuseModalState.onApplyCurrent(point);
  eventLocationReuseSetStatus('已写入当前编辑活动（仅当前表单，未自动保存数据库）。');
}

function eventLocationEnsureReuseModalBound() {
  if (eventLocationReuseModalState.bound) return;
  const els = eventLocationReuseEls();
  if (!els.overlay) return;

  if (els.sourceSearch) {
    els.sourceSearch.addEventListener('input', () => {
      eventLocationReuseModalState.sourceQuery = String(els.sourceSearch.value || '').trim();
      eventLocationReuseRenderSourceList();
    });
  }
  if (els.targetSearch) {
    els.targetSearch.addEventListener('input', () => {
      eventLocationReuseModalState.targetQuery = String(els.targetSearch.value || '').trim();
      eventLocationReuseRenderTargetList();
    });
  }
  if (els.sourceList) {
    els.sourceList.addEventListener('click', (event) => {
      const item = event.target.closest('[data-reuse-source-id]');
      if (!item) return;
      const eventId = String(item.getAttribute('data-reuse-source-id') || '').trim();
      if (!eventId) return;
      eventLocationReuseModalState.sourceEventId = eventId;
      eventLocationReuseRenderAll();
    });
  }
  if (els.targetList) {
    els.targetList.addEventListener('click', (event) => {
      const item = event.target.closest('[data-reuse-target-id]');
      if (!item) return;
      const eventId = String(item.getAttribute('data-reuse-target-id') || '').trim();
      if (!eventId) return;
      if (eventLocationReuseModalState.targetEventIds.has(eventId)) {
        eventLocationReuseModalState.targetEventIds.delete(eventId);
      } else {
        eventLocationReuseModalState.targetEventIds.add(eventId);
      }
      eventLocationReuseRenderAll();
    });
  }
  if (els.applyCurrentBtn) {
    els.applyCurrentBtn.onclick = () => eventLocationReuseApplyToCurrentPanel();
  }
  if (els.applyBatchBtn) {
    els.applyBatchBtn.onclick = () => eventLocationReuseApplyToTargets();
  }
  eventLocationReuseModalState.bound = true;
}

function openEventLocationReuseModal(options = {}) {
  eventLocationEnsureReuseModalBound();
  const els = eventLocationReuseEls();
  if (!els.overlay) return;
  eventLocationReuseModalState.open = true;
  eventLocationReuseModalState.panelEl = options.panelEl || null;
  eventLocationReuseModalState.fest = options.fest || null;
  eventLocationReuseModalState.onApplyCurrent = (typeof options.onApplyCurrent === 'function')
    ? options.onApplyCurrent
    : null;
  eventLocationReuseModalState.sourceEventId = '';
  eventLocationReuseModalState.targetEventIds = new Set();
  eventLocationReuseModalState.sourceQuery = '';
  eventLocationReuseModalState.targetQuery = '';
  eventLocationReuseModalState.applying = false;

  if (els.sourceSearch) els.sourceSearch.value = '';
  if (els.targetSearch) els.targetSearch.value = '';

  const currentFestId = String(options?.fest?.backendEventId || '').trim();
  if (currentFestId) {
    eventLocationReuseModalState.targetEventIds.add(currentFestId);
  }

  eventLocationReuseRenderAll();
  els.overlay.classList.add('open');
}

function closeEventLocationReuseModal() {
  const { overlay } = eventLocationReuseEls();
  if (overlay) overlay.classList.remove('open');
  eventLocationReuseModalState.open = false;
  eventLocationReuseModalState.panelEl = null;
  eventLocationReuseModalState.fest = null;
  eventLocationReuseModalState.onApplyCurrent = null;
  eventLocationReuseModalState.sourceEventId = '';
  eventLocationReuseModalState.targetEventIds = new Set();
  eventLocationReuseModalState.sourceQuery = '';
  eventLocationReuseModalState.targetQuery = '';
  eventLocationReuseModalState.applying = false;
}

function handleEventLocationReuseOverlayClick(event) {
  const { overlay } = eventLocationReuseEls();
  if (event?.target === overlay) closeEventLocationReuseModal();
}
