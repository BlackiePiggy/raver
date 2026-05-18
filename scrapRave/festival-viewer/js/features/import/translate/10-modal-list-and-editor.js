// Feature module extracted from 00-translate-batch (modal + list + editor)
const importTranslateStateModal = (function resolveImportTranslateStateForModal() {
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

function translateSetQuery(text) {
  const st = importTranslateStateModal.batch;
  if (!st) return;
  st.query = String(text || '').trim().toLowerCase();
  renderTranslateFestivalList();
}

function translateSetRequireConfirm(checked) {
  const st = importTranslateStateModal.batch;
  if (!st || st.running) return;
  st.requireConfirm = !!checked;
  translateSetModalStatus(st.requireConfirm ? '已开启：翻译后需确认才写入文件。' : '已关闭确认：翻译后将直接写入文件。');
  translateRefreshButtonState();
}

function translateSelectAllYears(checked) {
  const st = importTranslateStateModal.batch;
  if (!st || st.running) return;
  st.yearFilters = checked ? new Set(st.years || []) : new Set();
  renderTranslateYearFilters();
  renderTranslateFestivalList();
}

function getVisibleTranslateEntries(st) {
  const query = String(st.query || '').trim().toLowerCase();
  const yearFilters = st.yearFilters instanceof Set ? st.yearFilters : new Set();
  return (st.entries || []).filter((entry) => {
    const y = Number(entry.year || 0);
    if (yearFilters.size && !yearFilters.has(y)) return false;
    if (!query) return true;
    return String(entry.searchText || '').includes(query);
  });
}

function renderTranslateYearFilters() {
  const st = importTranslateStateModal.batch;
  const box = document.getElementById('translate-year-filters');
  if (!st || !box) return;
  if (!Array.isArray(st.years) || !st.years.length) {
    box.innerHTML = '<span class="translate-year-empty">无年份可选</span>';
    return;
  }
  box.innerHTML = st.years.map((year) => {
    const checked = st.yearFilters?.has(year) ? 'checked' : '';
    const count = st.entries.filter(x => Number(x.year || 0) === year).length;
    return `
      <label class="translate-year-chip">
        <input type="checkbox" ${checked} ${st.running ? 'disabled' : ''} onchange="translateToggleYearFilter(${year}, this.checked)">
        <span>${year} (${count})</span>
      </label>
    `;
  }).join('');
}

function renderTranslateFestivalList() {
  const st = importTranslateStateModal.batch;
  const box = document.getElementById('translate-fest-list');
  if (!box || !st) return;
  const visible = getVisibleTranslateEntries(st);
  if (!st.entries.length) {
    box.innerHTML = '<div class="translate-progress-empty">当前库中没有可翻译活动</div>';
    translateRefreshButtonState();
    return;
  }
  if (!visible.length) {
    box.innerHTML = '<div class="translate-progress-empty">没有匹配项，请调整搜索词或年份勾选。</div>';
    translateRefreshButtonState();
    return;
  }

  const groups = new Map();
  for (const entry of visible) {
    const y = Number(entry.year || 0);
    if (!groups.has(y)) groups.set(y, []);
    groups.get(y).push(entry);
  }

  const years = [...groups.keys()].sort((a, b) => b - a);
  const html = years.map((year) => {
    const list = groups.get(year) || [];
    const allSelected = list.length > 0 && list.every(x => x.selected);
    const groupRows = list.map((entry, idx) => {
      const meta = translateStatusMeta(entry);
      const nameBi = toPlainBiText(entry.fest?.info?.nameI18n ?? entry.fest?.info?.name, entry.fest?.name || entry.fest?.folder || '');
      const title = nameBi.en || nameBi.zh || entry.fest?.folder || `活动 ${idx + 1}`;
      const key = getFestivalTranslateKey(entry.fest);
      const dr = formatDateRange(entry.fest?.info?.startDate, entry.fest?.info?.endDate);
      return `
        <div class="translate-fest-item">
          <div class="translate-fest-top">
            <input type="checkbox" ${entry.selected ? 'checked' : ''} ${st.running ? 'disabled' : ''} onchange="translateToggleFestival(${entry.id}, this.checked)">
            <div>
              <div class="translate-fest-name">${escapeHtml(title)}</div>
              <div class="translate-fest-meta">${escapeHtml([entry.fest?.year, entry.fest?.month, dr, key].filter(Boolean).join(' · '))}</div>
            </div>
          </div>
          <div class="translate-fest-status ${meta.cls}">${escapeHtml(meta.text)}${entry.message ? `：${escapeHtml(entry.message)}` : ''}</div>
        </div>
      `;
    }).join('');
    return `
      <div class="translate-year-group">
        <div class="translate-year-group-head">
          <div class="translate-year-group-title">${year} · ${list.length} 个活动</div>
          <label class="translate-year-group-action">
            <input type="checkbox" ${allSelected ? 'checked' : ''} ${st.running ? 'disabled' : ''} onchange="translateToggleYearBatch(${year}, this.checked)">
            <span>全选该年</span>
          </label>
        </div>
        <div class="translate-year-group-list">${groupRows}</div>
      </div>
    `;
  }).join('');

  box.innerHTML = html;
  translateRefreshButtonState();
}

function renderTranslateDraftEditor(entry) {
  if (!entry?.draft || !entry?.original) return '';
  const disabled = String(entry?.status || '') === 'ready' ? '' : 'disabled';
  const fieldDefs = [
    { key: 'nameI18n', label: 'Festival Name' },
    { key: 'cityI18n', label: 'City' },
    { key: 'detailAddressI18n', label: 'Detail Address' },
    { key: 'countryI18n', label: 'Country' },
  ];
  const fieldsHtml = fieldDefs.map((f) => {
    const beforeSeed = entry.original?.[f.key];
    const afterSeed = entry.draft?.[f.key];
    const before = (f.key === 'countryI18n')
      ? normalizeCountryBiTextValue(beforeSeed, '')
      : normalizeBiTextValue(beforeSeed, '');
    const after = (f.key === 'countryI18n')
      ? normalizeCountryBiTextValue(parsePartialBiText(afterSeed), before)
      : parsePartialBiText(afterSeed);
    const enFullRows = f.key === 'countryI18n'
      ? `
        <div class="translate-edit-row">
          <span class="translate-edit-lang">EN FULL</span>
          <div class="translate-edit-preview">${translateDiffHtml(before.enFull, after.enFull)}</div>
        </div>
        <div class="translate-edit-row">
          <span class="translate-edit-lang"></span>
          <input class="translate-edit-input" type="text" value="${escapeHtml(after.enFull || '')}" ${disabled} oninput="translateUpdateDraft(${entry.id}, '${f.key}', 'enFull', this.value)">
        </div>
      `
      : '';
    return `
      <div class="translate-edit-field">
        <div class="translate-edit-title">${f.label}</div>
        <div class="translate-edit-row">
          <span class="translate-edit-lang">EN</span>
          <div class="translate-edit-preview">${translateDiffHtml(before.en, after.en)}</div>
        </div>
        <div class="translate-edit-row">
          <span class="translate-edit-lang"></span>
          <input class="translate-edit-input" type="text" value="${escapeHtml(after.en)}" ${disabled} oninput="translateUpdateDraft(${entry.id}, '${f.key}', 'en', this.value)">
        </div>
        <div class="translate-edit-row">
          <span class="translate-edit-lang">ZH</span>
          <div class="translate-edit-preview">${translateDiffHtml(before.zh, after.zh)}</div>
        </div>
        <div class="translate-edit-row">
          <span class="translate-edit-lang"></span>
          <input class="translate-edit-input" type="text" value="${escapeHtml(after.zh)}" ${disabled} oninput="translateUpdateDraft(${entry.id}, '${f.key}', 'zh', this.value)">
        </div>
        ${enFullRows}
      </div>
    `;
  }).join('');
  const applyChecked = entry.applySelected ? 'checked' : '';
  return `
    <div class="translate-edit-grid">${fieldsHtml}</div>
    <label class="translate-apply-row">
      <input type="checkbox" ${applyChecked} ${disabled} onchange="translateToggleApply(${entry.id}, this.checked)">
      <span>确认保存该活动翻译结果</span>
    </label>
  `;
}

function renderTranslateProgressList() {
  const st = importTranslateStateModal.batch;
  const box = document.getElementById('translate-progress-list');
  if (!box || !st) return;
  const items = st.entries.filter(x => x.status !== 'pending');
  if (!items.length) {
    box.innerHTML = '<div class="translate-progress-empty">还没有执行记录。请选择活动后点击「开始翻译」。</div>';
    return;
  }
  const readyCount = st.entries.filter(x => String(x.status || '') === 'ready').length;
  const savedCount = st.entries.filter(x => String(x.status || '') === 'saved').length;
  const modeText = st.requireConfirm ? `待确认 ${readyCount}，已保存 ${savedCount}` : `自动写入已保存 ${savedCount}`;
  const head = `<div class="translate-progress-head">总计 ${st.entries.length} 个，${modeText}，跳过 ${st.skippedCount || 0}，失败 ${st.failedCount || 0}</div>`;
  const listHtml = items.map((entry, idx) => {
    const meta = translateStatusMeta(entry);
    const nameBi = toPlainBiText(entry.fest?.info?.nameI18n ?? entry.fest?.info?.name, entry.fest?.name || entry.fest?.folder || '');
    const title = nameBi.en || nameBi.zh || entry.fest?.folder || `活动 ${idx + 1}`;
    const editingCls = String(entry.status || '') === 'ready' ? ' editing' : '';
    const editor = String(entry.status || '') === 'ready' ? renderTranslateDraftEditor(entry) : '';
    return `
      <div class="translate-progress-item${editingCls}">
        <div class="translate-fest-name">${escapeHtml(title)}</div>
        <div class="translate-progress-status ${meta.cls}">${escapeHtml(meta.text)}${entry.message ? `：${escapeHtml(entry.message)}` : ''}</div>
        ${editor}
      </div>
    `;
  }).join('');
  box.innerHTML = `${head}${listHtml}`;
}

function openTranslateBatchModal() {
  if (!rootDirHandle) {
    setImportStatus('请先选择 brands 文件夹。', true);
    return;
  }
  const festivals = listAllFestivalsInLibrary();
  const entries = festivals.map((fest, idx) => {
    const plan = buildFestivalTranslatePlan(fest);
    const nameBi = plan?.nameBi || toPlainBiText(fest?.info?.nameI18n ?? fest?.info?.name, fest?.name || fest?.folder || '');
    const cityBi = plan?.cityBi || toPlainBiText(fest?.info?.cityI18n ?? fest?.info?.city, fest?.info?.city || '');
    const detailAddressBi = plan?.detailAddressBi || toPlainBiText(
      fest?.info?.manualLocation?.detailAddressI18n ?? fest?.info?.detailAddressI18n,
      ''
    );
    const countryBi = plan?.countryBi || toPlainBiText(fest?.info?.countryI18n ?? fest?.info?.country, fest?.country || '');
    const searchText = [
      nameBi.en, nameBi.zh,
      cityBi.en, cityBi.zh,
      detailAddressBi.en, detailAddressBi.zh,
      countryBi.en, countryBi.zh,
      countryBi.enFull,
      String(fest?.folder || ''),
      String(fest?.year || ''),
    ].join(' ').toLowerCase();
    return {
      id: idx,
      fest,
      year: Number(fest?.year || 0),
      selected: true,
      applySelected: false,
      status: 'pending',
      message: '',
      original: null,
      draft: null,
      searchText,
    };
  });
  importTranslateStateModal.batch = {
    entries,
    years: [],
    yearFilters: new Set(), // default: none selected
    query: '',
    requireConfirm: true,
    running: false,
    updatedCount: 0,
    skippedCount: 0,
    failedCount: 0,
  };
  translateRefreshYearMeta(importTranslateStateModal.batch);
  const sub = document.getElementById('translate-modal-sub');
  if (sub) sub.textContent = `当前库活动数：${festivals.length}（支持全选后批量送入 Coze 翻译）`;
  const searchEl = document.getElementById('translate-search-input');
  if (searchEl) searchEl.value = '';
  const confirmEl = document.getElementById('translate-require-confirm');
  if (confirmEl) confirmEl.checked = true;
  renderTranslateYearFilters();
  translateSetModalStatus('');
  translateSetRunStatus('规则：默认年份全不选，请先勾选年份；可切换“翻译后先确认再写入”。');
  renderTranslateFestivalList();
  renderTranslateProgressList();
  translateRefreshButtonState();
  document.getElementById('translate-modal-overlay').classList.add('open');
}

function closeTranslateBatchModal() {
  const st = importTranslateStateModal.batch;
  if (st?.running) {
    translateSetModalStatus('翻译进行中，请等待当前任务完成后再关闭。', true);
    return;
  }
  document.getElementById('translate-modal-overlay').classList.remove('open');
  importTranslateStateModal.batch = null;
}

function handleTranslateOverlayClick(e) {
  if (e.target === document.getElementById('translate-modal-overlay')) closeTranslateBatchModal();
}

function translateToggleFestival(entryId, checked) {
  const st = importTranslateStateModal.batch;
  if (!st || st.running) return;
  const entry = getTranslateEntryById(entryId);
  if (!entry) return;
  entry.selected = !!checked;
  renderTranslateFestivalList();
}

function translateToggleYearFilter(year, checked) {
  const st = importTranslateStateModal.batch;
  if (!st || st.running) return;
  const y = Number(year || 0);
  if (!y) return;
  if (!(st.yearFilters instanceof Set)) st.yearFilters = new Set(st.years || []);
  if (checked) {
    st.yearFilters.add(y);
  } else {
    st.yearFilters.delete(y);
    st.entries.filter(x => Number(x.year || 0) === y).forEach((x) => { x.selected = false; });
  }
  renderTranslateYearFilters();
  renderTranslateFestivalList();
}

function translateToggleYearBatch(year, checked) {
  const st = importTranslateStateModal.batch;
  if (!st || st.running) return;
  const y = Number(year || 0);
  const visible = getVisibleTranslateEntries(st).filter(x => Number(x.year || 0) === y);
  visible.forEach((entry) => { entry.selected = !!checked; });
  translateRefreshButtonState();
  renderTranslateFestivalList();
}

function translateToggleApply(entryId, checked) {
  const st = importTranslateStateModal.batch;
  if (!st) return;
  const entry = getTranslateEntryById(entryId);
  if (!entry || String(entry.status || '') !== 'ready') return;
  entry.applySelected = !!checked;
  translateRefreshButtonState();
}

function translateUpdateDraft(entryId, fieldKey, lang, value) {
  const st = importTranslateStateModal.batch;
  if (!st) return;
  const entry = getTranslateEntryById(entryId);
  if (!entry || !entry.draft || String(entry.status || '') !== 'ready') return;
  if (!['nameI18n', 'cityI18n', 'detailAddressI18n', 'countryI18n'].includes(String(fieldKey || ''))) return;
  if (!['en', 'zh', 'enFull'].includes(String(lang || ''))) return;
  const cur = String(fieldKey || '') === 'countryI18n'
    ? normalizeCountryBiTextValue(entry.draft[fieldKey], '')
    : normalizeBiTextValue(entry.draft[fieldKey], '');
  cur[lang] = String(value ?? '');
  entry.draft[fieldKey] = String(fieldKey || '') === 'countryI18n'
    ? normalizeCountryBiTextValue(cur, cur.en || cur.zh || '')
    : normalizeBiTextValue(cur, cur.en || cur.zh || '');
  translateRefreshButtonState();
}

function translateSelectAllFestivals(checked) {
  const st = importTranslateStateModal.batch;
  if (!st || st.running) return;
  const visible = getVisibleTranslateEntries(st);
  visible.forEach((x) => { x.selected = !!checked; });
  renderTranslateFestivalList();
}

function translateSelectAllReady(checked) {
  const st = importTranslateStateModal.batch;
  if (!st || st.running) return;
  st.entries
    .filter(x => String(x.status || '') === 'ready')
    .forEach((x) => { x.applySelected = !!checked; });
  renderTranslateProgressList();
  translateRefreshButtonState();
}

function translateClearFinished() {
  const st = importTranslateStateModal.batch;
  if (!st || st.running) return;
  st.entries = st.entries.filter((x) => !['saved', 'skipped'].includes(String(x.status || '')));
  translateRefreshYearMeta(st);
  renderTranslateYearFilters();
  renderTranslateFestivalList();
  renderTranslateProgressList();
}
