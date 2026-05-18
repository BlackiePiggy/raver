// Event location bind + payload sync helpers
function buildEventComposedLocationQueryPayload(panelEl, fest) {
  const read = (key) => String(panelEl?.querySelector(`.fest-info-edit [data-field="${key}"]`)?.value || '').trim();
  const uniq = (rows) => {
    const out = [];
    const seen = new Set();
    for (const raw of rows || []) {
      const text = String(raw || '').trim();
      if (!text) continue;
      const key = text.toLowerCase();
      if (seen.has(key)) continue;
      seen.add(key);
      out.push(text);
    }
    return out;
  };

  const countryZh = read('countryZh') || String(fest?.info?.countryI18n?.zh || '').trim();
  const countryEn = read('countryEnFull')
    || read('countryEn')
    || String(fest?.info?.countryI18n?.enFull || fest?.info?.countryI18n?.en || fest?.info?.country || '').trim();
  const cityZh = read('cityZh') || String(fest?.info?.cityI18n?.zh || '').trim();
  const cityEn = read('cityEn') || String(fest?.info?.cityI18n?.en || fest?.info?.city || '').trim();
  const detailZh = read('detailAddressZh') || String(fest?.info?.manualLocation?.detailAddressI18n?.zh || '').trim();
  const detailEn = read('detailAddressEn') || String(fest?.info?.manualLocation?.detailAddressI18n?.en || '').trim();

  const zhQuery = [countryZh, cityZh, detailZh].filter(Boolean).join(' ').trim();
  const enQuery = [detailEn, cityEn, countryEn].filter(Boolean).join(', ').trim();
  const queries = uniq([zhQuery, enQuery]);
  return {
    composedQuery: queries[0] || '',
    composedQueryZh: zhQuery,
    composedQueryEn: enQuery,
  };
}

function resolveEventLocationProviderForPanel(panelEl, fest, point = null) {
  const fromField = String(panelEl?.querySelector('.fest-info-edit [data-field="locationProvider"]')?.value || '').trim();
  const fromPoint = String(point?.provider || fest?.info?.locationPoint?.provider || '').trim();
  const fromPreferred = typeof getPreferredEventLocationProvider === 'function'
    ? getPreferredEventLocationProvider()
    : 'amap';
  const provider = normalizeEventLocationProvider(fromField || fromPoint || fromPreferred || 'amap');
  if (typeof setPreferredEventLocationProvider === 'function') {
    setPreferredEventLocationProvider(provider);
  }
  return provider;
}

function syncEventLocationProviderField(panelEl, provider) {
  const select = panelEl?.querySelector('.fest-info-edit [data-field="locationProvider"]');
  if (!select) return;
  const normalized = normalizeEventLocationProvider(provider || select.value || 'amap');
  select.value = normalized;
}

function renderEventLocationPreview(panelEl, point) {
  const preview = panelEl?.querySelector('.fest-info-edit [data-location-preview]');
  if (!preview) return;
  const normalized = normalizeEventLocationPoint(point);
  if (!normalized) {
    preview.textContent = '未绑定定位地点';
    preview.classList.add('empty');
    return;
  }
  preview.classList.remove('empty');
  preview.textContent = formatEventLocationPointBrief(normalized);
}

function setEventLocationDraftFromInfo(panelEl, info) {
  const point = normalizeEventLocationPoint(info?.locationPoint || null);
  const provider = normalizeEventLocationProvider(point?.provider || info?.locationPoint?.provider || getPreferredEventLocationProvider?.() || 'amap');
  writeEventLocationPointToHiddenInput(panelEl, point);
  syncEventLocationProviderField(panelEl, provider);
  renderEventLocationPreview(panelEl, point);
}

function collectEventLocationPointFromPanel(panelEl) {
  return normalizeEventLocationPoint(readEventLocationPointFromHiddenInput(panelEl));
}

function renderEventLocationInfoView(panelEl, info) {
  const el = panelEl?.querySelector('[data-view="locationPoint"]');
  const viewBtn = panelEl?.querySelector('.info-map-btn');
  if (!el) return;
  const point = normalizeEventLocationPoint(info?.locationPoint || null);
  if (!point) {
    el.innerHTML = '<span class="empty">—</span>';
    if (viewBtn) viewBtn.style.display = 'none';
    return;
  }
  const unifiedAddress = typeof formatFestivalUnifiedAddress === 'function'
    ? formatFestivalUnifiedAddress({
        ...info,
        locationPoint: point,
      })
    : String(point.formattedAddressI18n?.zh || point.formattedAddressI18n?.en || '').trim();
  const coord = `${Number(point.location.lng).toFixed(6)}, ${Number(point.location.lat).toFixed(6)}`;
  const provider = escapeHtml(String(point.provider || '').trim() || '-');
  const poiId = escapeHtml(String(point.poiId || '-'));
  el.innerHTML = `
    <div class="event-location-view">
      <div>${escapeHtml(String(unifiedAddress || '').trim() || '-')}</div>
      <div class="event-location-view-meta">Provider: ${provider} · POI: ${poiId} · ${escapeHtml(coord)}</div>
    </div>
  `;
  el.classList.remove('empty');
  if (viewBtn) viewBtn.style.display = '';
}

function bindEventLocationEditorActions(panelEl, fest) {
  if (!panelEl) return;
  if (panelEl.dataset.locationBindReady === '1') {
    const point = readEventLocationPointFromHiddenInput(panelEl);
    syncEventLocationProviderField(panelEl, point?.provider || fest?.info?.locationPoint?.provider || getPreferredEventLocationProvider?.() || 'amap');
    renderEventLocationPreview(panelEl, readEventLocationPointFromHiddenInput(panelEl));
    const viewBtn = panelEl.querySelector('.info-map-btn');
    if (viewBtn) viewBtn.style.display = point ? '' : 'none';
    return;
  }
  panelEl.dataset.locationBindReady = '1';
  const providerSelect = panelEl.querySelector('.fest-info-edit [data-field="locationProvider"]');
  if (providerSelect) {
    providerSelect.addEventListener('change', () => {
      const normalized = normalizeEventLocationProvider(providerSelect.value || 'amap');
      providerSelect.value = normalized;
      if (typeof setPreferredEventLocationProvider === 'function') {
        setPreferredEventLocationProvider(normalized);
      }
    });
  }

  const viewBtn = panelEl.querySelector('.info-map-btn');
  const syncViewMapButton = () => {
    if (!viewBtn) return;
    const point = normalizeEventLocationPoint(
      readEventLocationPointFromHiddenInput(panelEl)
      || fest?.info?.locationPoint
      || null
    );
    viewBtn.style.display = point ? '' : 'none';
  };

  const onApplyPoint = (point) => {
    const normalized = normalizeEventLocationPoint(point);
    writeEventLocationPointToHiddenInput(panelEl, normalized);
    syncEventLocationProviderField(panelEl, normalized?.provider || providerSelect?.value || 'amap');
    renderEventLocationPreview(panelEl, normalized);
    syncViewMapButton();
  };

  const composedBtn = panelEl.querySelector('.fest-info-edit [data-action="location-composed-search"]');
  if (composedBtn) {
    composedBtn.onclick = async () => {
      const initial = readEventLocationPointFromHiddenInput(panelEl);
      const provider = resolveEventLocationProviderForPanel(panelEl, fest, initial);
      const composed = buildEventComposedLocationQueryPayload(panelEl, fest);
      await openEventLocationPickerModal({
        mode: 'edit',
        panelEl,
        fest,
        initialPoint: initial,
        provider,
        composedQuery: composed.composedQuery,
        composedQueryZh: composed.composedQueryZh,
        composedQueryEn: composed.composedQueryEn,
        onConfirm: onApplyPoint,
      });
    };
  }
  const manualBtn = panelEl.querySelector('.fest-info-edit [data-action="location-manual-search"]');
  if (manualBtn) {
    manualBtn.onclick = async () => {
      const initial = readEventLocationPointFromHiddenInput(panelEl);
      const provider = resolveEventLocationProviderForPanel(panelEl, fest, initial);
      await openEventLocationPickerModal({
        mode: 'edit',
        panelEl,
        fest,
        initialPoint: initial,
        provider,
        onConfirm: onApplyPoint,
      });
    };
  }
  const manualEntryBtn = panelEl.querySelector('.fest-info-edit [data-action="location-manual-entry"]');
  if (manualEntryBtn) {
    manualEntryBtn.onclick = () => {
      const initial = readEventLocationPointFromHiddenInput(panelEl);
      const provider = resolveEventLocationProviderForPanel(panelEl, fest, initial);
      if (typeof openEventLocationManualEntryModal !== 'function') return;
      openEventLocationManualEntryModal({
        panelEl,
        fest,
        initialPoint: initial,
        provider,
        onConfirm: onApplyPoint,
      });
    };
  }
  const reuseBtn = panelEl.querySelector('.fest-info-edit [data-action="location-reuse-from-event"]');
  if (reuseBtn) {
    reuseBtn.onclick = () => {
      if (typeof openEventLocationReuseModal !== 'function') return;
      openEventLocationReuseModal({
        panelEl,
        fest,
        onApplyCurrent: onApplyPoint,
      });
    };
  }
  const myPosBtn = panelEl.querySelector('.fest-info-edit [data-action="location-use-my-pos"]');
  if (myPosBtn) {
    myPosBtn.onclick = async () => {
      const initial = readEventLocationPointFromHiddenInput(panelEl);
      const provider = resolveEventLocationProviderForPanel(panelEl, fest, initial);
      await openEventLocationPickerModal({
        mode: 'edit',
        panelEl,
        fest,
        initialPoint: initial,
        provider,
        onConfirm: onApplyPoint,
      });
      setTimeout(() => {
        const btn = document.getElementById('event-location-picker-my-pos-btn');
        if (btn) btn.click();
      }, 80);
    };
  }
  const clearBtn = panelEl.querySelector('.fest-info-edit [data-action="location-clear"]');
  if (clearBtn) {
    clearBtn.onclick = () => {
      writeEventLocationPointToHiddenInput(panelEl, null);
      renderEventLocationPreview(panelEl, null);
      syncViewMapButton();
    };
  }
  if (viewBtn) {
    viewBtn.onclick = async () => {
      const point = normalizeEventLocationPoint(fest?.info?.locationPoint || readEventLocationPointFromHiddenInput(panelEl));
      if (!point) return;
      const provider = resolveEventLocationProviderForPanel(panelEl, fest, point);
      const composed = buildEventComposedLocationQueryPayload(panelEl, fest);
      await openEventLocationPickerModal({
        mode: 'view',
        panelEl,
        fest,
        initialPoint: point,
        provider: point?.provider || provider,
        composedQuery: composed.composedQuery,
        composedQueryZh: composed.composedQueryZh,
        composedQueryEn: composed.composedQueryEn,
      });
    };
  }
  syncEventLocationProviderField(
    panelEl,
    readEventLocationPointFromHiddenInput(panelEl)?.provider || fest?.info?.locationPoint?.provider || getPreferredEventLocationProvider?.() || 'amap'
  );
  renderEventLocationPreview(panelEl, readEventLocationPointFromHiddenInput(panelEl));
  syncViewMapButton();
}
