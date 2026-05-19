// ── SAVE ──
function collectFestivalPayloadFromPanel(panelEl, fest) {
  const get = key => panelEl.querySelector(`.fest-info-edit [data-field="${key}"]`);
  const getVal = key => String(get(key)?.value || '').trim();
  const lineupRaw = String(get('lineup')?.value || '').trim();
  const lineupArtistsRaw = String(get('lineupArtists')?.value || '').trim();
  const multiLangRaw = String(get('multiLangJson')?.value || '').trim();

  let lineup = fest?.info?.lineup || [];
  if (lineupRaw) {
    try {
      const parsed = JSON.parse(lineupRaw);
      if (Array.isArray(parsed)) lineup = parsed;
      else if (parsed && Array.isArray(parsed.lineup_info)) lineup = parsed.lineup_info;
      else if (parsed && typeof parsed === 'object') {
        // try top-level keys
        const key = Object.keys(parsed).find(k => Array.isArray(parsed[k]));
        if (key) lineup = parsed[key];
      }
    } catch (e) {
      return { error: `⚠ Lineup JSON 格式错误：${e.message}`, payload: null };
    }
  }
  let lineupArtists = fest?.info?.lineupArtists || [];
  if (lineupArtistsRaw) {
    try {
      const parsed = JSON.parse(lineupArtistsRaw);
      if (Array.isArray(parsed)) lineupArtists = parsed;
      else if (parsed && Array.isArray(parsed.lineup_artists)) lineupArtists = parsed.lineup_artists;
      else if (parsed && Array.isArray(parsed.artists)) lineupArtists = parsed.artists;
      else if (parsed && typeof parsed === 'object') {
        const key = Object.keys(parsed).find(k => Array.isArray(parsed[k]));
        if (key) lineupArtists = parsed[key];
      }
    } catch (e) {
      return { error: `⚠ DJ 阵容 JSON 格式错误：${e.message}`, payload: null };
    }
  }
  lineupArtists = buildEventLineupArtistsFromArchive(lineupArtists, lineup);

  let multiLangDraft = eventEditBuildMultiLangDraft(fest?.info || {});
  if (multiLangRaw) {
    const parsedMultiLang = eventEditReadMultiLangDraft(panelEl);
    if (!parsedMultiLang?.draft) {
      return { error: `⚠ 多语言 JSON 格式错误：${parsedMultiLang?.error || '未知错误'}`, payload: null };
    }
    multiLangDraft = parsedMultiLang.draft;
  }

  const nameEn = getVal('nameEn');
  const nameZh = getVal('nameZh');
  const nameJa = getVal('nameJa');
  const cityEn = getVal('cityEn');
  const cityZh = getVal('cityZh');
  const cityJa = getVal('cityJa');
  const countryEn = getVal('countryEn');
  const countryEnFull = getVal('countryEnFull');
  const countryZh = getVal('countryZh');
  const countryJa = getVal('countryJa');
  const detailAddressEn = getVal('detailAddressEn');
  const detailAddressZh = getVal('detailAddressZh');
  const detailAddressJa = getVal('detailAddressJa');
  const detailAddressI18n = normalizeBiTextValue({
    ...(multiLangDraft?.detailAddressI18n || {}),
    en: detailAddressEn,
    zh: detailAddressZh,
    ja: detailAddressJa,
  }, '');
  const descriptionI18n = normalizeBiTextValue(multiLangDraft?.descriptionI18n || {}, '');
  const detailAddressSeed = detailAddressZh || detailAddressEn || detailAddressI18n.ja || '';
  const citySeed = cityZh || cityEn || cityJa;
  const countrySeed = countryZh || countryEnFull || countryEn || countryJa;
  const wikiFestivalId = getVal('wikiFestivalId');
  const wikiFestivalName = getVal('wikiFestivalName');
  const statusValue = normalizeArchiveEventStatus(
    getVal('status'),
    normalizeArchiveEventStatus(fest?.info?.status || '')
  );
  let canceled = get('canceled')
    ? get('canceled').value === 'true'
    : normalizeBoolFlag(fest?.info?.canceled, false);
  if (statusValue === 'cancelled') canceled = true;
  const finalStatus = canceled ? 'cancelled' : (statusValue || '');

  const payload = {
    name: nameEn || nameZh || nameJa || multiLangDraft?.nameI18n?.ja || '',
    nameI18n: normalizeBiTextValue({ ...(multiLangDraft?.nameI18n || {}), en: nameEn, zh: nameZh, ja: nameJa }, ''),
    country: countrySeed,
    countryI18n: normalizeCountryBiTextValue(
      { ...(multiLangDraft?.countryI18n || {}), en: countryEn, zh: countryZh, ja: countryJa, enFull: countryEnFull || multiLangDraft?.countryI18n?.enFull || '' },
      ''
    ),
    city: citySeed || multiLangDraft?.cityI18n?.ja || '',
    cityI18n: normalizeBiTextValue({ ...(multiLangDraft?.cityI18n || {}), en: cityEn, zh: cityZh, ja: cityJa }, ''),
    canceled,
    status: finalStatus,
    eventType: String(get('eventType')?.value || fest?.info?.eventType || 'festival').trim() || 'festival',
    timeZone: String(get('timeZone')?.value || fest?.info?.timeZone || Intl.DateTimeFormat().resolvedOptions().timeZone || 'UTC').trim() || 'UTC',
    startDate: getVal('startDate'),
    endDate: getVal('endDate'),
    relatedLinks: String(get('relatedLinks')?.value || '').split(/\r?\n/).map(v=>v.trim()).filter(Boolean),
    socialLinks: normalizeSocialLinks(String(get('socialLinks')?.value || '')),
    lineupArtists,
    lineup,
    ticketPriceMin: getVal('ticketPriceMin'),
    ticketPriceMax: getVal('ticketPriceMax'),
    ticketCurrency: getVal('ticketCurrency'),
    ticketUrl: getVal('ticketUrl'),
    ticketNotes: String(get('ticketNotes')?.value || '').trim(),
    description: descriptionI18n.en || descriptionI18n.zh || descriptionI18n.ja || '',
    descriptionI18n,
    festivalId: String(fest?.info?.festivalId || '').trim(),
    source: mergeSourceMeta(fest?.info?.source)
  };
  const hasManualLocation = !!(detailAddressEn || detailAddressZh || detailAddressJa);
  if (hasManualLocation) {
    const countryDisplayEn = payload.countryI18n.enFull || countryEn || countryZh;
    const formattedZh = [countryZh || countryDisplayEn || countryEn, cityZh || cityEn, detailAddressZh || detailAddressEn].filter(Boolean).join(' · ');
    const formattedEn = [countryDisplayEn || countryEn || countryZh, cityEn || cityZh, detailAddressEn || detailAddressZh].filter(Boolean).join(' · ');
    payload.manualLocation = {
      detailAddressI18n,
      formattedAddressI18n: normalizeBiTextValue(
        { en: formattedEn, zh: formattedZh },
        formattedZh || formattedEn
      ),
      selectedAt: new Date().toISOString(),
    };
  } else {
    payload.manualLocation = null;
  }
  if (typeof collectEventLocationPointFromPanel === 'function') {
    payload.locationPoint = collectEventLocationPointFromPanel(panelEl);
  } else {
    const rawLocationPoint = String(get('locationPointJson')?.value || '').trim();
    if (rawLocationPoint) {
      try { payload.locationPoint = JSON.parse(rawLocationPoint); } catch (_error) {}
    }
  }

  if (wikiFestivalName && !wikiFestivalId) {
    return { error: '关联 Brand 需要人工从候选中明确选择，当前仅输入了文本未完成选择。', payload: null };
  }
  if (wikiFestivalId) {
    payload.wikiFestivalId = wikiFestivalId;
  } else if (!wikiFestivalName) {
    payload.wikiFestivalId = null;
  }

  payload.festivalId = buildFestivalId(
    payload.startDate,
    payload.nameI18n?.en || payload.name,
    payload.countryI18n?.en || payload.country
  )
    || payload.festivalId;

  const split = splitReferenceLinks(payload.relatedLinks, payload.socialLinks);
  payload.relatedLinks = split.refs;
  payload.socialLinks = split.social;
  return { error: '', payload };
}

async function saveFestivalInfo(fest, panelEl, saveBtn, statusEl) {
  const collected = collectFestivalPayloadFromPanel(panelEl, fest);
  if (!collected || !collected.payload) {
    statusEl.textContent = collected?.error || '表单数据校验失败';
    return;
  }
  const payload = collected.payload;

  const imageZoneDraft = collectEventImageDraftPayload(panelEl);
  const existingAssetDraft = collectExistingEventAssetDraftPayload(panelEl, fest);

  statusEl.textContent = '正在保存...';
  saveBtn.disabled = true;

  try {
    const syncResult = await persistFestivalPayload(fest, payload, { imageZoneDraft, existingAssetDraft });
    if (syncResult?.event) {
      patchFestivalFromBackendEvent(fest, syncResult.event);
    }
    clearEventImageDraftState(panelEl);
    clearExistingEventAssetDraft(panelEl);
    renderExistingEventAssetDrafts(panelEl, fest);
    renderEventImageZoneDrafts(panelEl, fest);

    refreshFestHeaderDisplay(panelEl.closest('.festival-row'), fest);
    renderInfoView(panelEl, fest.info);
    toggleInfoEdit(panelEl, false);
    const imageMsg = syncResult
      ? `（图片：上传 ${syncResult.uploadedImages || 0}，复用 ${syncResult.reusedImages || 0}${(syncResult.failedImages || 0) > 0 ? `，失败 ${syncResult.failedImages}` : ''}）`
      : '';
    statusEl.textContent = `已保存并同步数据库 ${new Date().toLocaleTimeString()}${imageMsg}`;
  } catch(e) {
    statusEl.textContent = `保存失败：${e.message}`;
  } finally {
    saveBtn.disabled = false;
  }
}

function eventEditReadBiFieldFromPanel(panelEl, enKey, zhKey, fallback = '') {
  if (!panelEl) return normalizeBiTextValue({ en: '', zh: '' }, fallback);
  const en = String(panelEl.querySelector(`.fest-info-edit [data-field="${enKey}"]`)?.value || '').trim();
  const zh = String(panelEl.querySelector(`.fest-info-edit [data-field="${zhKey}"]`)?.value || '').trim();
  return normalizeBiTextValue({ en, zh }, fallback);
}

function eventEditReadCountryFieldFromPanel(panelEl, fallback = '') {
  if (!panelEl) return normalizeCountryBiTextValue({ en: '', zh: '', enFull: '' }, fallback);
  const en = String(panelEl.querySelector('.fest-info-edit [data-field="countryEn"]')?.value || '').trim();
  const zh = String(panelEl.querySelector('.fest-info-edit [data-field="countryZh"]')?.value || '').trim();
  const enFull = String(panelEl.querySelector('.fest-info-edit [data-field="countryEnFull"]')?.value || '').trim();
  return normalizeCountryBiTextValue({ en, zh, enFull }, fallback);
}

function eventEditWriteBiFieldToPanel(panelEl, enKey, zhKey, value) {
  if (!panelEl) return;
  const bi = normalizeBiTextValue(value, '');
  const enInput = panelEl.querySelector(`.fest-info-edit [data-field="${enKey}"]`);
  const zhInput = panelEl.querySelector(`.fest-info-edit [data-field="${zhKey}"]`);
  if (enInput) enInput.value = String(bi.en || '').trim();
  if (zhInput) zhInput.value = String(bi.zh || '').trim();
}

function eventEditWriteCountryFieldToPanel(panelEl, value) {
  if (!panelEl) return;
  const country = normalizeCountryBiTextValue(value, '');
  const enInput = panelEl.querySelector('.fest-info-edit [data-field="countryEn"]');
  const zhInput = panelEl.querySelector('.fest-info-edit [data-field="countryZh"]');
  const enFullInput = panelEl.querySelector('.fest-info-edit [data-field="countryEnFull"]');
  if (enInput) enInput.value = String(country.en || '').trim();
  if (zhInput) zhInput.value = String(country.zh || '').trim();
  if (enFullInput) enFullInput.value = String(country.enFull || '').trim();
}

function eventEditParseCozeBiValue(value) {
  const safe = (input) => {
    if (input === null || input === undefined) return '';
    const type = typeof input;
    if (type !== 'string' && type !== 'number' && type !== 'boolean') return '';
    const text = String(input).trim();
    if (!text) return '';
    return /^\[object\s+object\]$/i.test(text) ? '' : text;
  };
  if (typeof value === 'string') {
    const text = safe(value);
    return { en: text, zh: text, enFull: '' };
  }
  if (!value || typeof value !== 'object' || Array.isArray(value)) return { en: '', zh: '', enFull: '' };
  return {
    en: safe(value.en ?? value.EN ?? value.english ?? value.name_en ?? ''),
    zh: safe(value.zh ?? value.ZH ?? value.chinese ?? value.name_zh ?? value.cn ?? ''),
    enFull: safe(value.enFull ?? value.en_full ?? value.englishFull ?? value.country_en_full ?? ''),
  };
}

function eventEditMergeTranslatedBiValue(original, translated) {
  const source = normalizeBiTextValue(original, '');
  const incoming = eventEditParseCozeBiValue(translated);
  const out = {
    en: source.en,
    zh: source.zh,
    enFull: String(source?.enFull || '').trim(),
  };
  if (incoming.en) out.en = incoming.en;
  if (incoming.zh) out.zh = incoming.zh;
  if (incoming.enFull) out.enFull = incoming.enFull;
  const normalized = normalizeBiTextValue(out, source.en || source.zh || '');
  const enriched = normalizeCountryBiTextValue(normalized, source.en || source.zh || '');
  if (String(enriched?.enFull || '').trim()) return enriched;
  return normalized;
}

function eventEditBuildDiffItems(label, before, after) {
  const items = [];
  const prev = normalizeBiTextValue(before, '');
  const next = normalizeBiTextValue(after, '');
  if (String(prev.en || '').trim() !== String(next.en || '').trim()) {
    items.push({
      field: label,
      lang: 'EN',
      before: prev.en || '（空）',
      after: next.en || '（空）',
    });
  }
  if (String(prev.zh || '').trim() !== String(next.zh || '').trim()) {
    items.push({
      field: label,
      lang: 'ZH',
      before: prev.zh || '（空）',
      after: next.zh || '（空）',
    });
  }
  return items;
}

function eventEditBuildCountryDiffItems(label, before, after) {
  const items = eventEditBuildDiffItems(label, before, after);
  const prev = normalizeCountryBiTextValue(before, '');
  const next = normalizeCountryBiTextValue(after, '');
  if (String(prev.enFull || '').trim() !== String(next.enFull || '').trim()) {
    items.push({
      field: label,
      lang: 'EN FULL',
      before: String(prev.enFull || '').trim() || '（空）',
      after: String(next.enFull || '').trim() || '（空）',
    });
  }
  return items;
}

function eventEditEscapeHtml(value) {
  return String(value ?? '')
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&#39;');
}

let eventEditTranslateConfirmModalState = null;
function eventEditEnsureTranslateConfirmModal() {
  if (eventEditTranslateConfirmModalState) return eventEditTranslateConfirmModalState;

  const overlay = document.createElement('div');
  overlay.id = 'event-translate-confirm-overlay';
  overlay.innerHTML = `
    <div id="event-translate-confirm-modal" role="dialog" aria-modal="true" aria-labelledby="event-translate-confirm-title">
      <div class="event-translate-confirm-head">
        <div>
          <div class="event-translate-confirm-title" id="event-translate-confirm-title">字段替换确认</div>
          <div class="event-translate-confirm-sub" id="event-translate-confirm-sub">以下字段将被写入当前编辑表单（不会自动保存到数据库）</div>
        </div>
        <div class="event-translate-confirm-tools">
          <button class="event-translate-confirm-btn" type="button" data-action="select-all">全选</button>
          <button class="event-translate-confirm-btn" type="button" data-action="select-none">全不选</button>
        </div>
      </div>
      <div class="event-translate-confirm-body">
        <div class="event-translate-confirm-summary" id="event-translate-confirm-summary"></div>
        <div class="event-translate-confirm-list" id="event-translate-confirm-list"></div>
      </div>
      <div class="event-translate-confirm-foot">
        <button class="event-translate-confirm-btn" type="button" data-action="cancel">取消</button>
        <button class="event-translate-confirm-btn primary" type="button" data-action="confirm">确认应用选中项</button>
      </div>
    </div>
  `;
  document.body.appendChild(overlay);

  const listEl = overlay.querySelector('#event-translate-confirm-list');
  const summaryEl = overlay.querySelector('#event-translate-confirm-summary');
  const titleEl = overlay.querySelector('#event-translate-confirm-title');
  const subEl = overlay.querySelector('#event-translate-confirm-sub');
  const collectFormItems = () => {
    const items = [];
    const rows = listEl?.querySelectorAll('.event-translate-confirm-item') || [];
    rows.forEach((row) => {
      const index = Number(row.getAttribute('data-index'));
      const selected = !!row.querySelector('.event-translate-confirm-apply')?.checked;
      const textarea = row.querySelector('.event-translate-confirm-input');
      const after = String(textarea?.value || '').trim();
      const field = String(row.getAttribute('data-field') || '').trim();
      const lang = String(row.getAttribute('data-lang') || '').trim();
      const beforeRaw = String(row.getAttribute('data-before-raw') || '').trim();
      const afterRaw = String(row.getAttribute('data-after-raw') || '').trim();
      items.push({
        index,
        selected,
        field,
        lang,
        beforeRaw,
        afterRaw: after,
        initialAfterRaw: afterRaw,
      });
    });
    return items;
  };
  const refreshSummary = () => {
    const items = collectFormItems();
    const changedFieldCount = new Set(items.map((item) => item.field)).size;
    const selectedCount = items.filter((item) => item.selected).length;
    summaryEl.textContent = `检测到 ${items.length} 条变更，涉及 ${changedFieldCount} 个字段；当前选中 ${selectedCount} 条。`;
  };
  const setAllSelected = (selected) => {
    const rows = listEl?.querySelectorAll('.event-translate-confirm-apply') || [];
    rows.forEach((checkbox) => {
      checkbox.checked = !!selected;
    });
    refreshSummary();
  };
  const close = (confirmed) => {
    const state = eventEditTranslateConfirmModalState;
    if (!state || !state.resolve) return;
    const resolve = state.resolve;
    state.resolve = null;
    overlay.classList.remove('open');
    resolve({
      confirmed: !!confirmed,
      items: collectFormItems(),
    });
  };

  overlay.addEventListener('click', (e) => {
    if (e.target === overlay) close(false);
  });
  overlay.querySelector('[data-action="cancel"]')?.addEventListener('click', () => close(false));
  overlay.querySelector('[data-action="confirm"]')?.addEventListener('click', () => close(true));
  overlay.querySelector('[data-action="select-all"]')?.addEventListener('click', () => setAllSelected(true));
  overlay.querySelector('[data-action="select-none"]')?.addEventListener('click', () => setAllSelected(false));
  listEl?.addEventListener('input', (e) => {
    if (e.target instanceof HTMLInputElement || e.target instanceof HTMLTextAreaElement) {
      refreshSummary();
    }
  });
  listEl?.addEventListener('change', (e) => {
    if (e.target instanceof HTMLInputElement || e.target instanceof HTMLTextAreaElement) {
      refreshSummary();
    }
  });

  const keydownHandler = (e) => {
    if (e.key !== 'Escape') return;
    if (!overlay.classList.contains('open')) return;
    close(false);
  };
  document.addEventListener('keydown', keydownHandler);

  eventEditTranslateConfirmModalState = {
    overlay,
    listEl,
    summaryEl,
    titleEl,
    subEl,
    refreshSummary,
    setAllSelected,
    resolve: null,
  };
  return eventEditTranslateConfirmModalState;
}

function eventEditNormalizeDiffItemText(value) {
  const text = String(value ?? '').trim();
  if (!text) return '';
  if (text === '（空）' || text === '(空)' || text === '（empty）' || text === '(empty)') return '';
  return text;
}

function eventEditShowTranslateConfirmModal(diffItems, options = {}) {
  const modal = eventEditEnsureTranslateConfirmModal();
  if (!modal) return Promise.resolve({ confirmed: false, items: [] });

  if (modal.resolve) {
    const prevResolve = modal.resolve;
    modal.resolve = null;
    prevResolve({ confirmed: false, items: [] });
  }

  const title = String(options?.title || '字段替换确认').trim();
  const subtitle = String(options?.subtitle || '以下字段将被写入当前编辑表单（不会自动保存到数据库）').trim();
  if (modal.titleEl) modal.titleEl.textContent = title;
  if (modal.subEl) modal.subEl.textContent = subtitle;

  const normalizedItems = (Array.isArray(diffItems) ? diffItems : []).map((item, index) => {
    const field = String(item?.field || '').trim() || `Field ${index + 1}`;
    const lang = String(item?.lang || '').trim() || '-';
    const beforeRaw = String(
      item?.beforeRaw !== undefined ? item.beforeRaw : eventEditNormalizeDiffItemText(item?.before)
    );
    const afterRaw = String(
      item?.afterRaw !== undefined ? item.afterRaw : eventEditNormalizeDiffItemText(item?.after)
    );
    const selected = item?.selected !== false;
    return {
      ...item,
      index,
      field,
      lang,
      beforeRaw,
      afterRaw,
      selected,
      beforeDisplay: beforeRaw || '（空）',
      afterDisplay: afterRaw,
    };
  });

  modal.listEl.innerHTML = normalizedItems.map((item) => `
    <div class="event-translate-confirm-item" data-index="${item.index}" data-field="${eventEditEscapeHtml(item.field)}" data-lang="${eventEditEscapeHtml(item.lang)}" data-before-raw="${eventEditEscapeHtml(item.beforeRaw)}" data-after-raw="${eventEditEscapeHtml(item.afterRaw)}">
      <div class="event-translate-confirm-item-head">
        <label class="event-translate-confirm-check">
          <input class="event-translate-confirm-apply" type="checkbox" ${item.selected ? 'checked' : ''}>
          <span>应用</span>
        </label>
        <span class="event-translate-confirm-tag">${eventEditEscapeHtml(item.field)}</span>
        <span class="event-translate-confirm-lang">${eventEditEscapeHtml(item.lang)}</span>
      </div>
      <div class="event-translate-confirm-compare">
        <div class="event-translate-confirm-col">
          <div class="event-translate-confirm-col-val">${eventEditEscapeHtml(item.beforeDisplay)}</div>
        </div>
        <div class="event-translate-confirm-col">
          <textarea class="event-translate-confirm-input event-translate-confirm-col-val next" rows="1">${eventEditEscapeHtml(item.afterDisplay)}</textarea>
        </div>
      </div>
    </div>
  `).join('');

  modal.refreshSummary?.();
  modal.overlay.classList.add('open');
  return new Promise((resolve) => {
    modal.resolve = resolve;
  });
}

async function runSingleFestivalTranslateWithCoze(fest, panelEl, triggerBtn, statusEl) {
  if (!fest || !panelEl || !statusEl) return;

  const originalBtnText = triggerBtn ? String(triggerBtn.textContent || '').trim() : '';
  if (triggerBtn) {
    triggerBtn.disabled = true;
    triggerBtn.textContent = '翻译中...';
  }
  statusEl.textContent = '正在调用 Coze 翻译...';

  try {
    const currentName = eventEditReadBiFieldFromPanel(panelEl, 'nameEn', 'nameZh', fest?.info?.name || '');
    const currentCity = eventEditReadBiFieldFromPanel(panelEl, 'cityEn', 'cityZh', fest?.info?.city || '');
    const currentDetailAddress = eventEditReadBiFieldFromPanel(
      panelEl,
      'detailAddressEn',
      'detailAddressZh',
      fest?.info?.manualLocation?.detailAddressI18n?.zh
        || fest?.info?.manualLocation?.detailAddressI18n?.en
        || ''
    );
    const currentCountry = normalizeCountryBiTextValue(
      eventEditReadCountryFieldFromPanel(panelEl, fest?.info?.country || ''),
      fest?.info?.countryI18n ?? fest?.info?.country ?? ''
    );

    const hasAnyInput = [currentName, currentCity, currentDetailAddress, currentCountry]
      .some((bi) => String(bi?.en || '').trim() || String(bi?.zh || '').trim());
    if (!hasAnyInput) {
      statusEl.textContent = '请先填写至少一个中英文字段，再执行单条翻译。';
      return;
    }

    const resp = await apiPost('/api/coze/translate-festival', {
      festival: {
        name_i18n: currentName,
        city_i18n: currentCity,
        detail_address_i18n: currentDetailAddress,
        country_i18n: {
          en: currentCountry.en || '',
          zh: currentCountry.zh || '',
          en_full: currentCountry.enFull || '',
        },
      },
    });
    const translated = (resp && typeof resp.translated === 'object') ? resp.translated : {};

    const nextName = eventEditMergeTranslatedBiValue(
      currentName,
      translated.nameI18n ?? translated.name_i18n ?? translated.name
    );
    const nextCity = eventEditMergeTranslatedBiValue(
      currentCity,
      translated.cityI18n ?? translated.city_i18n ?? translated.city
    );
    const nextDetailAddress = eventEditMergeTranslatedBiValue(
      currentDetailAddress,
      translated.detailAddressI18n
      ?? translated.detail_address_i18n
      ?? translated.manualLocation?.detailAddressI18n
      ?? translated.manual_location?.detail_address_i18n
    );
    const nextCountry = eventEditMergeTranslatedBiValue(
      currentCountry,
      translated.countryI18n ?? translated.country_i18n ?? translated.country
    );

    const diffItems = [
      ...eventEditBuildDiffItems('Festival Name', currentName, nextName),
      ...eventEditBuildDiffItems('City', currentCity, nextCity),
      ...eventEditBuildDiffItems('Detail Address', currentDetailAddress, nextDetailAddress),
      ...eventEditBuildCountryDiffItems('Country', currentCountry, nextCountry),
    ];

    if (!diffItems.length) {
      statusEl.textContent = '翻译完成：没有可应用的字段变化。';
      return;
    }

    const confirmResult = await eventEditShowTranslateConfirmModal(diffItems, {
      title: '翻译替换确认',
      subtitle: '勾选要应用的字段，并可直接编辑结果内容。',
    });
    if (!confirmResult?.confirmed) {
      statusEl.textContent = '已取消应用翻译结果。';
      return;
    }
    const selectedItems = (Array.isArray(confirmResult?.items) ? confirmResult.items : [])
      .filter((item) => item?.selected);
    if (!selectedItems.length) {
      statusEl.textContent = '未选择任何字段，未应用翻译结果。';
      return;
    }

    const appliedName = normalizeBiTextValue(currentName, '');
    const appliedCity = normalizeBiTextValue(currentCity, '');
    const appliedDetailAddress = normalizeBiTextValue(currentDetailAddress, '');
    const appliedCountry = normalizeCountryBiTextValue(currentCountry, '');

    const toText = (value) => String(value ?? '').trim();
    selectedItems.forEach((item) => {
      const field = toText(item?.field);
      const lang = toText(item?.lang).toUpperCase();
      const after = toText(item?.afterRaw);
      if (field === 'Festival Name') {
        if (lang === 'EN') appliedName.en = after;
        if (lang === 'ZH') appliedName.zh = after;
        return;
      }
      if (field === 'City') {
        if (lang === 'EN') appliedCity.en = after;
        if (lang === 'ZH') appliedCity.zh = after;
        return;
      }
      if (field === 'Detail Address') {
        if (lang === 'EN') appliedDetailAddress.en = after;
        if (lang === 'ZH') appliedDetailAddress.zh = after;
        return;
      }
      if (field === 'Country') {
        if (lang === 'EN') appliedCountry.en = after;
        if (lang === 'ZH') appliedCountry.zh = after;
        if (lang === 'EN FULL') appliedCountry.enFull = after;
      }
    });

    eventEditWriteBiFieldToPanel(panelEl, 'nameEn', 'nameZh', appliedName);
    eventEditWriteBiFieldToPanel(panelEl, 'cityEn', 'cityZh', appliedCity);
    eventEditWriteBiFieldToPanel(panelEl, 'detailAddressEn', 'detailAddressZh', appliedDetailAddress);
    eventEditWriteCountryFieldToPanel(panelEl, appliedCountry);
    statusEl.textContent = `已应用 ${selectedItems.length} 条翻译结果，请点击“保存并同步数据库”确认入库。`;
  } catch (error) {
    statusEl.textContent = `单条翻译失败：${error?.message || '未知错误'}`;
  } finally {
    if (triggerBtn) {
      triggerBtn.disabled = false;
      triggerBtn.textContent = originalBtnText || '单条翻译（先确认）';
    }
  }
}
