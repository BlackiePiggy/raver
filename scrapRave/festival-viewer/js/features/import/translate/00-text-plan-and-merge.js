// Feature module extracted from 00-translate-batch (text + plan + merge)
const importTranslateStatePlan = (function resolveImportTranslateStateForPlan() {
  const facade = window.ImportStateFacade;
  if (facade && typeof facade.translateState === 'function') return facade.translateState();
  return {
    get batch() {
      return translateBatchState;
    },
    set batch(value) {
      translateBatchState = (value && typeof value === 'object') ? value : null;
    },
  };
})();

function hasCjkChar(text) {
  return /[\u3400-\u9fff]/.test(String(text || ''));
}

function hasLatinChar(text) {
  return /[A-Za-z]/.test(String(text || ''));
}

function isEnglishFieldReady(text) {
  const src = String(text || '').trim();
  if (!src) return false;
  if (hasCjkChar(src)) return false;
  return hasLatinChar(src) || /^[A-Z]{2,3}$/.test(src.toUpperCase());
}

function isChineseFieldReady(text) {
  const src = String(text || '').trim();
  if (!src) return false;
  return hasCjkChar(src);
}

function toPlainBiText(value, fallback = '') {
  const bi = normalizeBiTextValue(value, fallback);
  const out = {
    en: String(bi.en || '').trim(),
    zh: String(bi.zh || '').trim(),
  };
  const enFull = String(bi.enFull || '').trim();
  if (enFull) out.enFull = enFull;
  return out;
}

function parsePartialBiText(value) {
  const safe = (input) => {
    if (input === null || input === undefined) return '';
    const type = typeof input;
    if (type !== 'string' && type !== 'number' && type !== 'boolean') return '';
    const text = String(input).trim();
    if (!text) return '';
    return /^\[object\s+object\]$/i.test(text) ? '' : text;
  };
  if (!value || typeof value !== 'object' || Array.isArray(value)) return { en: '', zh: '', enFull: '' };
  return {
    en: safe(value.en ?? value.EN ?? value.english ?? value.name_en ?? ''),
    zh: safe(value.zh ?? value.ZH ?? value.chinese ?? value.name_zh ?? value.cn ?? ''),
    enFull: safe(value.enFull ?? value.en_full ?? value.englishFull ?? value.country_en_full ?? ''),
  };
}

function mergeTranslatedBiText(original, translated, needs) {
  const out = {
    en: String(original?.en || '').trim(),
    zh: String(original?.zh || '').trim(),
    enFull: String(original?.enFull || '').trim(),
  };
  if (needs?.en && translated?.en) out.en = String(translated.en).trim();
  if (needs?.zh && translated?.zh) out.zh = String(translated.zh).trim();
  if (translated?.enFull) out.enFull = String(translated.enFull).trim();
  if (!out.en) out.en = out.zh;
  if (!out.zh) out.zh = out.en;
  return normalizeBiTextValue(out, original?.en || original?.zh || '');
}

function listAllFestivalsInLibrary() {
  const out = [];
  const years = Object.keys(allData || {}).map(Number).sort((a, b) => b - a);
  for (const year of years) {
    const byMonth = allData[year] || {};
    const months = Object.keys(byMonth || {}).map(Number).sort((a, b) => a - b);
    for (const month of months) {
      const list = Array.isArray(byMonth[month]) ? byMonth[month] : [];
      for (const fest of list) out.push(fest);
    }
  }
  return out;
}

function getFestivalTranslateKey(fest) {
  const id = String(fest?.info?.festivalId || '').trim();
  if (id) return id;
  return `${String(fest?.year || '')}/${String(fest?.folder || '')}`;
}

function buildDerivedFormattedAddressBi(detailBi, cityBi, countryBi) {
  const zh = [countryBi?.zh || countryBi?.enFull || countryBi?.en, cityBi?.zh || cityBi?.en, detailBi?.zh || detailBi?.en]
    .map((part) => String(part || '').trim())
    .filter(Boolean)
    .join(' · ');
  const en = [countryBi?.enFull || countryBi?.en || countryBi?.zh, cityBi?.en || cityBi?.zh, detailBi?.en || detailBi?.zh]
    .map((part) => String(part || '').trim())
    .filter(Boolean)
    .join(' · ');
  return toPlainBiText({ en, zh }, zh || en);
}

function resolveFestivalAddressBiForTranslate(info, fest) {
  const manual = (typeof normalizeFestivalManualLocation === 'function')
    ? normalizeFestivalManualLocation(info?.manualLocation ?? info?.manual_location ?? null, null)
    : (info?.manualLocation ?? info?.manual_location ?? null);
  const cityBi = toPlainBiText(
    info?.cityI18n ?? info?.city_i18n ?? info?.city,
    info?.city || ''
  );
  const detailSeed =
    manual?.detailAddressI18n
    ?? info?.detailAddressI18n
    ?? info?.detail_address_i18n
    ?? '';
  const detailAddressBi = toPlainBiText(detailSeed, typeof detailSeed === 'string' ? detailSeed : '');
  const countryBi = normalizeCountryBiTextValue(info?.countryI18n ?? info?.country, info?.country || '');
  const formattedAddressBi = toPlainBiText(
    manual?.formattedAddressI18n ?? manual?.formattedAddress ?? buildDerivedFormattedAddressBi(detailAddressBi, cityBi, countryBi),
    ''
  );
  return {
    cityBi,
    detailAddressBi,
    countryBi,
    formattedAddressBi,
  };
}

function buildFestivalTranslatePlan(fest) {
  const info = fest?.info || {};
  const nameBi = toPlainBiText(info.nameI18n ?? info.name, info.name || fest?.name || fest?.folder || '');
  const address = resolveFestivalAddressBiForTranslate(info, fest);
  const cityBi = address.cityBi;
  const detailAddressBi = address.detailAddressBi;
  const countryBi = address.countryBi;
  const formattedAddressBi = address.formattedAddressBi;

  const requestFestival = {
    name_i18n: nameBi,
    city_i18n: cityBi,
    detail_address_i18n: detailAddressBi,
    formatted_address_i18n: formattedAddressBi,
    manual_location: {
      detail_address_i18n: detailAddressBi,
      formatted_address_i18n: formattedAddressBi,
    },
    country_i18n: {
      en: String(countryBi.en || '').trim(),
      zh: String(countryBi.zh || '').trim(),
      en_full: String(countryBi.enFull || '').trim(),
    },
  };

  return {
    nameBi,
    cityBi,
    detailAddressBi,
    formattedAddressBi,
    countryBi,
    requestFestival
  };
}

async function translateSingleFestivalWithCoze(fest) {
  const plan = buildFestivalTranslatePlan(fest);
  const resp = await apiPost('/api/coze/translate-festival', { festival: plan.requestFestival });
  const translated = resp?.translated || {};
  const mergedName = parsePartialBiText(translated.nameI18n ?? translated.name_i18n ?? translated.name);
  const mergedCity = parsePartialBiText(
    translated.cityI18n
    ?? translated.city_i18n
    ?? translated.city
  );
  const mergedDetailAddress = parsePartialBiText(
    translated.detailAddressI18n
    ?? translated.detail_address_i18n
    ?? translated.manualLocation?.detailAddressI18n
    ?? translated.manual_location?.detail_address_i18n
  );
  const mergedCountry = normalizeCountryBiTextValue(
    parsePartialBiText(translated.countryI18n ?? translated.country_i18n ?? translated.country),
    plan.countryBi
  );

  const changedFields = [];
  if ((plan.nameBi.en || '') !== (mergedName.en || '') || (plan.nameBi.zh || '') !== (mergedName.zh || '')) changedFields.push('名称');
  if ((plan.cityBi.en || '') !== (mergedCity.en || '') || (plan.cityBi.zh || '') !== (mergedCity.zh || '')) changedFields.push('城市');
  if (
    (plan.detailAddressBi.en || '') !== (mergedDetailAddress.en || '')
    || (plan.detailAddressBi.zh || '') !== (mergedDetailAddress.zh || '')
  ) {
    changedFields.push('详细地址');
  }
  if (
    (plan.countryBi.en || '') !== (mergedCountry.en || '')
    || (plan.countryBi.zh || '') !== (mergedCountry.zh || '')
    || (plan.countryBi.enFull || '') !== (mergedCountry.enFull || '')
  ) {
    changedFields.push('国家');
  }

  return {
    skipped: false,
    changed: changedFields.length > 0,
    changedFields,
    original: {
      nameI18n: normalizeBiTextValue(plan.nameBi, fest?.info?.name || ''),
      cityI18n: normalizeBiTextValue(plan.cityBi, fest?.info?.city || ''),
      detailAddressI18n: normalizeBiTextValue(plan.detailAddressBi, ''),
      countryI18n: normalizeCountryBiTextValue(plan.countryBi, fest?.info?.country || ''),
    },
    draft: {
      nameI18n: mergedName,
      cityI18n: mergedCity,
      detailAddressI18n: mergedDetailAddress,
      countryI18n: mergedCountry,
    },
    rawResponse: resp?.raw_response || null,
  };
}

function translateSetModalStatus(text, isError = false) {
  const el = document.getElementById('translate-modal-status');
  if (!el) return;
  el.textContent = String(text || '');
  el.style.color = isError ? 'var(--accent2)' : 'var(--text-dim)';
}

function translateSetRunStatus(text) {
  const el = document.getElementById('translate-run-status');
  if (el) el.textContent = String(text || '');
}

function translateRefreshButtonState() {
  const st = importTranslateStatePlan.batch;
  const runBtn = document.getElementById('translate-run-btn');
  const saveBtn = document.getElementById('translate-save-btn');
  if (!st) return;
  const selectedCount = getVisibleTranslateEntries(st).filter(x => x.selected).length;
  if (runBtn) {
    runBtn.disabled = st.running || selectedCount === 0;
    runBtn.textContent = st.running ? '翻译中...' : '开始翻译';
  }
  const saveReady = (st.entries || []).some(x => String(x.status || '') === 'ready' && x.applySelected);
  if (saveBtn) {
    if (!st.requireConfirm) {
      saveBtn.disabled = true;
      saveBtn.textContent = '自动写入模式';
      saveBtn.style.opacity = '0.55';
    } else {
      saveBtn.disabled = st.running || !saveReady;
      saveBtn.textContent = st.running ? '处理中...' : '确认保存修改';
      saveBtn.style.opacity = '';
    }
  }
}

function translateStatusMeta(entry) {
  const status = String(entry?.status || 'pending');
  if (status === 'running') return { text: '翻译中...', cls: 'run' };
  if (status === 'ready') return { text: '待确认', cls: 'ok' };
  if (status === 'saved') return { text: '已保存', cls: 'ok' };
  if (status === 'skipped') return { text: '已跳过', cls: '' };
  if (status === 'error') return { text: '失败', cls: 'err' };
  return { text: '待执行', cls: '' };
}

function getTranslateEntryById(entryId) {
  const st = importTranslateStatePlan.batch;
  if (!st) return null;
  const id = Number(entryId);
  if (!Number.isInteger(id)) return null;
  return st.entries.find(x => Number(x.id) === id) || null;
}

function translateDiffHtml(fromText, toText) {
  const from = String(fromText || '');
  const to = String(toText || '');
  if (!to) return '<span class="empty">—</span>';
  if (from === to) return escapeHtml(to);

  let start = 0;
  while (start < from.length && start < to.length && from[start] === to[start]) start += 1;
  let fromEnd = from.length - 1;
  let toEnd = to.length - 1;
  while (fromEnd >= start && toEnd >= start && from[fromEnd] === to[toEnd]) {
    fromEnd -= 1;
    toEnd -= 1;
  }

  const prefix = to.slice(0, start);
  const added = to.slice(start, toEnd + 1);
  const suffix = to.slice(toEnd + 1);
  if (!added) return escapeHtml(to);
  return `${escapeHtml(prefix)}<span class="translate-added">${escapeHtml(added)}</span>${escapeHtml(suffix)}`;
}

function buildTranslateDraftPayload(entry) {
  const nextName = normalizeBiTextValue(entry?.draft?.nameI18n, entry?.fest?.info?.name || '');
  const nextCity = normalizeBiTextValue(
    entry?.draft?.cityI18n,
    entry?.fest?.info?.cityI18n ?? entry?.fest?.info?.city ?? ''
  );
  const nextDetailAddress = normalizeBiTextValue(
    entry?.draft?.detailAddressI18n,
    entry?.fest?.info?.manualLocation?.detailAddressI18n ?? entry?.fest?.info?.detailAddressI18n ?? ''
  );
  const nextCountry = normalizeCountryBiTextValue(entry?.draft?.countryI18n, entry?.fest?.info?.country || '');
  const existingManual = (typeof normalizeFestivalManualLocation === 'function')
    ? normalizeFestivalManualLocation(entry?.fest?.info?.manualLocation ?? entry?.fest?.info?.manual_location ?? null, null)
    : (entry?.fest?.info?.manualLocation ?? entry?.fest?.info?.manual_location ?? null);
  const hasDetailAddress = !!(String(nextDetailAddress?.en || '').trim() || String(nextDetailAddress?.zh || '').trim());
  const formattedAddressBi = buildDerivedFormattedAddressBi(nextDetailAddress, nextCity, nextCountry);
  const nextManual = hasDetailAddress
    ? {
        ...(existingManual && typeof existingManual === 'object' ? existingManual : {}),
        detailAddressI18n: nextDetailAddress,
        formattedAddressI18n: normalizeBiTextValue(
          existingManual?.formattedAddressI18n ?? formattedAddressBi,
          formattedAddressBi.zh || formattedAddressBi.en || ''
        ),
        selectedAt: String(existingManual?.selectedAt || new Date().toISOString()).trim(),
      }
    : existingManual;
  return {
    ...entry.fest.info,
    name: nextName.en || nextName.zh,
    nameI18n: nextName,
    city: nextCity.zh || nextCity.en,
    cityI18n: nextCity,
    detailAddressI18n: nextDetailAddress,
    manualLocation: nextManual || null,
    country: nextCountry.en || nextCountry.zh,
    countryI18n: nextCountry,
  };
}

async function applyTranslateDraftEntry(entry) {
  const payload = buildTranslateDraftPayload(entry);
  await persistFestivalPayload(entry.fest, payload);
}

function translateRefreshYearMeta(st) {
  const years = [...new Set((st.entries || []).map(x => Number(x.year || 0)).filter(y => y > 0))].sort((a, b) => b - a);
  st.years = years;
  if (!(st.yearFilters instanceof Set)) {
    st.yearFilters = new Set();
    return;
  }
  const next = new Set();
  for (const y of years) {
    if (st.yearFilters.has(y)) next.add(y);
  }
  st.yearFilters = next;
}
