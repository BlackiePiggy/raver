// Feature module extracted from monolith (timetable modal/render)
const ttModalState = (window.TimetableStateFacade && typeof window.TimetableStateFacade.modalState === 'function')
  ? window.TimetableStateFacade.modalState()
  : {
      get currentFest() { return ttCurrentFest; },
      set currentFest(value) { ttCurrentFest = value; },
      get currentRowEl() { return ttCurrentRowEl; },
      set currentRowEl(value) { ttCurrentRowEl = value; },
      get activeDateIdx() { return ttActiveDateIdx; },
      set activeDateIdx(value) { ttActiveDateIdx = Number(value) || 0; },
      get editMode() { return ttEditMode; },
      set editMode(value) { ttEditMode = !!value; },
      get draftLineup() { return ttDraftLineup; },
      set draftLineup(value) { ttDraftLineup = Array.isArray(value) ? value : []; },
      get draftRowSeed() { return ttDraftRowSeed; },
      set draftRowSeed(value) { ttDraftRowSeed = Number(value) || 1; },
      get saving() { return ttSaving; },
      set saving(value) { ttSaving = !!value; },
      get quickBindMode() { return ttQuickBindMode; },
      set quickBindMode(value) { ttQuickBindMode = !!value; },
    };

let ttOpenDayDropdownRid = null;

function ttGetBindStateForModal() {
  if (window.TimetableStateFacade && typeof window.TimetableStateFacade.bindState === 'function') {
    return window.TimetableStateFacade.bindState();
  }
  return ttDJBindState;
}

function setTtEditStatus(text, isError = false) {
  const el = document.getElementById('tt-edit-status');
  if (!el) return;
  el.textContent = String(text || '');
  el.style.color = isError ? 'var(--accent2)' : 'var(--text-dim)';
}

function syncTtModalActionState() {
  const editBtn = document.getElementById('tt-edit-btn');
  const saveBtn = document.getElementById('tt-save-btn');
  const cancelBtn = document.getElementById('tt-cancel-btn');
  if (!editBtn || !saveBtn || !cancelBtn) return;
  editBtn.style.display = ttModalState.editMode ? 'none' : '';
  saveBtn.style.display = ttModalState.editMode ? '' : 'none';
  cancelBtn.style.display = ttModalState.editMode ? '' : 'none';
  editBtn.disabled = ttModalState.saving;
  saveBtn.disabled = ttModalState.saving;
  cancelBtn.disabled = ttModalState.saving;
}

function toTtDraftRows(items) {
  return (Array.isArray(items) ? items : []).map((item) => {
    const x = normalizeLineupEntry(item || {});
    const dayIndex = ttResolveSlotDayIndex(x);
    return {
      ...x,
      date: dayIndex ? ttFormatDayLabel(dayIndex) : x.date,
      ...(dayIndex ? { festivalDayIndex: dayIndex } : {}),
      _rid: ttModalState.draftRowSeed++,
    };
  });
}

function getTtWorkingLineup() {
  if (ttModalState.editMode) return Array.isArray(ttModalState.draftLineup) ? ttModalState.draftLineup : [];
  return (ttModalState.currentFest?.info?.lineup || []).filter((s) => s && String(s.musician || '').trim());
}

function ttGetLineupArtistsForCurrentEvent() {
  const info = ttModalState.currentFest?.info || {};
  return buildEventLineupArtistsFromArchive(info.lineupArtists || [], info.lineup || []);
}

function ttArtistToDraftSlot(artist, activeDate) {
  const name = String(artist?.djName || artist?.name || artist?.musician || '').trim();
  return {
    musician: name,
    date: activeDate || ttFormatDayLabel(1),
    festivalDayIndex: ttResolveSlotDayIndex({ date: activeDate || ttFormatDayLabel(1) }) || 1,
    time: '',
    stage: '',
    djId: String(artist?.djId || '').trim() || undefined,
    djIds: Array.isArray(artist?.djIds) ? artist.djIds : [],
    _rid: ttModalState.draftRowSeed++,
  };
}

function ttRowDateValue(slot) {
  const explicitDayIndex = ttResolveSlotDayIndex(slot);
  if (explicitDayIndex) return ttFormatDayLabel(explicitDayIndex);
  return String(slot?.date || '').trim() || '未知';
}

function ttFormatDayLabel(dayIndex) {
  const numeric = Number(dayIndex);
  if (!Number.isInteger(numeric) || numeric <= 0) return 'Day 1';
  return `Day ${numeric}`;
}

function ttGetEventDateRange() {
  const info = ttModalState.currentFest?.info || {};
  const start = typeof parseArchiveDateOnlyForSync === 'function'
    ? parseArchiveDateOnlyForSync(info.startDate)
    : null;
  const end = typeof parseArchiveDateOnlyForSync === 'function'
    ? (parseArchiveDateOnlyForSync(info.endDate) || start)
    : start;
  return { start, end };
}

function ttGetEventDayCount() {
  const { start, end } = ttGetEventDateRange();
  if (!(start instanceof Date) || Number.isNaN(start.getTime())) return 1;
  if (!(end instanceof Date) || Number.isNaN(end.getTime())) return 1;
  const diffDays = Math.floor((end.getTime() - start.getTime()) / (24 * 60 * 60 * 1000));
  return Math.max(1, diffDays + 1);
}

function ttResolveSlotDayIndex(slot) {
  const explicit = Number(slot?.festivalDayIndex);
  if (Number.isInteger(explicit) && explicit > 0) return explicit;
  if (typeof parseLineupDayIndexForSync === 'function') {
    const parsedLabel = parseLineupDayIndexForSync(slot?.date);
    if (Number.isInteger(parsedLabel) && parsedLabel > 0) return parsedLabel;
  }
  const { start } = ttGetEventDateRange();
  const rowDate = typeof parseArchiveDateOnlyForSync === 'function'
    ? parseArchiveDateOnlyForSync(slot?.date)
    : null;
  if (start instanceof Date && !Number.isNaN(start.getTime()) && rowDate instanceof Date && !Number.isNaN(rowDate.getTime())) {
    const offset = Math.floor((rowDate.getTime() - start.getTime()) / (24 * 60 * 60 * 1000));
    if (Number.isInteger(offset) && offset >= 0) return offset + 1;
  }
  return null;
}

function ttBuildDayOptions() {
  const lineup = ttModalState.editMode ? ttModalState.draftLineup : (ttModalState.currentFest?.info?.lineup || []);
  const maxLineupDay = Math.max(
    1,
    ...(Array.isArray(lineup) ? lineup.map((slot) => ttResolveSlotDayIndex(slot) || 1) : [1])
  );
  const dayCount = Math.max(ttGetEventDayCount(), maxLineupDay);
  return Array.from({ length: dayCount }, (_item, index) => ({
    value: ttFormatDayLabel(index + 1),
    label: ttFormatDayLabel(index + 1),
  }));
}

function ttRenderDaySelectCell(slot) {
  const selectedValue = ttRowDateValue(slot);
  const options = ttBuildDayOptions();
  const isOpen = Number(slot?._rid) === Number(ttOpenDayDropdownRid);
  return `
    <div class="tt-day-select" data-open="${isOpen ? 'true' : 'false'}">
      <button
        type="button"
        class="tt-day-select-trigger"
        onclick="ttToggleDayDropdown(${slot._rid}, event)"
      >
        <span class="tt-day-select-value">${escapeHtml(selectedValue)}</span>
        <span class="tt-day-select-caret" aria-hidden="true"></span>
      </button>
      <div class="tt-day-select-menu" role="listbox" aria-hidden="${isOpen ? 'false' : 'true'}">
        ${options.map((option) => `
          <button
            type="button"
            class="tt-day-select-option${selectedValue === option.value ? ' is-selected' : ''}"
            onclick="ttSelectDayOption(${slot._rid}, '${escapeHtml(option.value)}', event)"
          >${escapeHtml(option.label)}</button>
        `).join('')}
      </div>
    </div>
  `;
}

function ttShouldUseScrollableStageLayout(stageCount) {
  const count = Number(stageCount) || 0;
  if (count <= 0) return false;
  const modal = document.getElementById('tt-modal');
  const body = modal?.querySelector('.tt-modal-body');
  const availableWidth = Math.max(0, Number(body?.clientWidth || modal?.clientWidth || 0) - 8);
  if (!availableWidth) return count >= 4;
  const minColumnWidth = 240;
  const gapWidth = 16;
  const totalMinWidth = (count * minColumnWidth) + (Math.max(0, count - 1) * gapWidth);
  return totalMinWidth > availableWidth;
}

function ttComputeDateOrder(lineup) {
  const order = [];
  const seen = new Set();
  for (const s of (Array.isArray(lineup) ? lineup : [])) {
    const d = ttRowDateValue(s);
    if (!seen.has(d)) {
      seen.add(d);
      order.push(d);
    }
  }
  if (!order.length && ttModalState.editMode) {
    order.push(ttFormatDayLabel(1));
  }
  return order;
}

function ttNormalizeStageOrder(value, fallback = []) {
  if (typeof normalizeStageOrderForSync === 'function') return normalizeStageOrderForSync(value, fallback);
  if (typeof normalizeStageOrderList === 'function') return normalizeStageOrderList(value, fallback);
  const source = Array.isArray(value) ? value : (Array.isArray(fallback) ? fallback : []);
  const seen = new Set();
  const result = [];
  for (const item of source) {
    const text = String(item || '').trim();
    if (!text) continue;
    const key = text.toLowerCase();
    if (seen.has(key)) continue;
    seen.add(key);
    result.push(text);
  }
  return result;
}

function ttDeriveStageOrderFromLineup(lineup) {
  return ttNormalizeStageOrder((Array.isArray(lineup) ? lineup : []).map((slot) => slot?.stage));
}

function ttGetCurrentStageOrder(lineup = null) {
  const current = ttModalState.currentFest?.info?.stageOrder;
  const derived = ttDeriveStageOrderFromLineup(lineup || getTtWorkingLineup());
  const configured = ttNormalizeStageOrder(current, derived);
  const configuredKeys = new Set(configured.map((item) => item.toLowerCase()));
  const missing = derived.filter((stage) => !configuredKeys.has(stage.toLowerCase()));
  return [...configured, ...missing];
}

function ttSortStageNames(stageNames, lineup = null) {
  const order = ttGetCurrentStageOrder(lineup);
  const orderIndex = new Map(order.map((name, index) => [String(name).toLowerCase(), index]));
  return [...ttNormalizeStageOrder(stageNames)].sort((a, b) => {
    const ia = orderIndex.has(String(a).toLowerCase()) ? orderIndex.get(String(a).toLowerCase()) : Number.MAX_SAFE_INTEGER;
    const ib = orderIndex.has(String(b).toLowerCase()) ? orderIndex.get(String(b).toLowerCase()) : Number.MAX_SAFE_INTEGER;
    if (ia !== ib) return ia - ib;
    return String(a).localeCompare(String(b), 'zh-Hans-CN', { sensitivity: 'base' });
  });
}

function ttTimeSortVal(timeText) {
  const m = String(timeText || '').match(/(\d{1,2}):(\d{2})/);
  if (!m) return 99999;
  return parseInt(m[1], 10) * 60 + parseInt(m[2], 10);
}

function ttTimelineSortVal(timeText, dayRolloverHour = 6) {
  const base = ttTimeSortVal(timeText);
  if (!Number.isFinite(base) || base >= 99999) return base;
  const safeRollover = Math.max(0, Math.min(23, Number(dayRolloverHour) || 6));
  const rolloverMinutes = safeRollover * 60;
  return base < rolloverMinutes ? base + 24 * 60 : base;
}

function openTtModal(fest, rowEl = null) {
  ttModalState.currentFest = fest;
  ttModalState.currentRowEl = rowEl || null;
  ttModalState.activeDateIdx = 0;
  ttModalState.editMode = false;
  ttModalState.quickBindMode = false;
  ttModalState.draftLineup = [];
  ttModalState.saving = false;
  setTtEditStatus('');
  syncTtModalActionState();
  const ttTitleBi = normalizeBiTextValue(fest.info.nameI18n ?? fest.info.name ?? fest.name ?? fest.folder, fest.folder);
  document.getElementById('tt-modal-title').innerHTML = renderBiTextHtml(ttTitleBi, { compact: true, fallback: fest.folder });
  document.getElementById('tt-modal-sub').textContent =
    [fest.info.location || fest.location, fest.year + '年' + fest.month + '月'].filter(Boolean).join('  ·  ');
  renderTtModalBody();
  const shouldLoadDJMatch = !ttDjMatchLoaded && !ttDjMatchLoading;
  if (shouldLoadDJMatch) setTtEditStatus('正在加载已绑定 DJ 头像...');
  void ensureTtDJMatchMapLoaded().then(() => {
    if (ttModalState.currentFest !== fest) return;
    if (shouldLoadDJMatch) setTtEditStatus('');
    if (!ttModalState.editMode) renderTtModalBody();
  }).catch(() => {
    if (ttModalState.currentFest !== fest) return;
    if (shouldLoadDJMatch) setTtEditStatus('');
  });
  document.getElementById('tt-modal-overlay').classList.add('open');
  document.body.style.overflow = 'hidden';
}

function closeTtModal() {
  if (ttModalState.saving) return;
  if (ttGetBindStateForModal()?.open) closeTtDJBindModal();
  document.getElementById('tt-modal-overlay').classList.remove('open');
  document.body.style.overflow = '';
  ttModalState.editMode = false;
  ttModalState.quickBindMode = false;
  ttModalState.draftLineup = [];
  ttModalState.saving = false;
  ttOpenDayDropdownRid = null;
  ttModalState.currentFest = null;
  ttModalState.currentRowEl = null;
  setTtEditStatus('');
}

function handleOverlayClick(e) {
  if (e.target === document.getElementById('tt-modal-overlay')) closeTtModal();
  else ttCloseDayDropdown();
}

function enterTtEditMode() {
  if (!ttModalState.currentFest || ttModalState.saving) return;
  ttModalState.editMode = true;
  ttModalState.quickBindMode = false;
  ttModalState.draftLineup = toTtDraftRows(ttModalState.currentFest.info.lineup || []);
  setTtEditStatus('已进入编辑模式，可修改/删除并保存。');
  syncTtModalActionState();
  renderTtModalBody();
}

function cancelTtEditMode() {
  if (ttModalState.saving) return;
  ttModalState.editMode = false;
  ttModalState.quickBindMode = false;
  ttModalState.draftLineup = [];
  ttOpenDayDropdownRid = null;
  setTtEditStatus('已取消编辑，未保存更改。');
  syncTtModalActionState();
  renderTtModalBody();
}

function ttAddRowForActiveDate() {
  if (!ttModalState.editMode || ttModalState.saving) return;
  const dateOrder = ttComputeDateOrder(ttModalState.draftLineup);
  const activeDate = dateOrder[ttModalState.activeDateIdx] || dateOrder[0] || ttFormatDayLabel(1);
  ttModalState.draftLineup.push({
    musician: '',
    date: activeDate,
    festivalDayIndex: ttResolveSlotDayIndex({ date: activeDate }) || 1,
    time: '',
    stage: '',
    _rid: ttModalState.draftRowSeed++
  });
  setTtEditStatus('已新增一条，可直接编辑。');
  renderTtModalBody();
}

function ttAddLineupArtistToTimetable(index) {
  if (!ttModalState.editMode || ttModalState.saving) return;
  const artist = ttGetLineupArtistsForCurrentEvent()[Number(index)];
  if (!artist) return;
  const dateOrder = ttComputeDateOrder(ttModalState.draftLineup);
  const activeDate = dateOrder[ttModalState.activeDateIdx] || dateOrder[0] || ttFormatDayLabel(1);
  ttModalState.draftLineup.push(ttArtistToDraftSlot(artist, activeDate));
  setTtEditStatus(`已从阵容添加 ${artist.djName || artist.name || 'DJ'}，请补充时间和舞台。`);
  renderTtModalBody();
}

function ttRenderLineupArtistPicker() {
  const artists = ttGetLineupArtistsForCurrentEvent();
  if (!artists.length || !ttModalState.editMode) return null;
  const scheduledKeys = new Set(
    (ttModalState.draftLineup || [])
      .map((row) => String(row?.djId || row?.musician || '').trim().toLowerCase())
      .filter(Boolean)
  );
  const panel = document.createElement('div');
  panel.className = 'tt-lineup-picker';
  panel.innerHTML = `
    <div class="tt-lineup-picker-head">
      <span>从 DJ 阵容添加到 timetable</span>
      <small>${artists.length} 个 DJ</small>
    </div>
    <div class="tt-lineup-picker-list">
      ${artists.map((artist, index) => {
        const key = String(artist?.djId || artist?.djName || '').trim().toLowerCase();
        const already = key && scheduledKeys.has(key);
        return `
          <button type="button" class="tt-lineup-picker-chip${already ? ' is-used' : ''}" onclick="ttAddLineupArtistToTimetable(${index})">
            <span>${escapeHtml(artist.djName || artist.name || 'Unknown DJ')}</span>
            ${already ? '<em>已在时间表</em>' : ''}
          </button>
        `;
      }).join('')}
    </div>
  `;
  return panel;
}

function ttClearAllRows() {
  if (!ttModalState.editMode || ttModalState.saving) return;
  const total = Array.isArray(ttModalState.draftLineup) ? ttModalState.draftLineup.length : 0;
  if (!total) {
    setTtEditStatus('当前没有可清空的 DJ 条目。');
    return;
  }
  const sure = window.confirm(`确认清空 timetable 中全部 ${total} 条已添加 DJ 吗？`);
  if (!sure) return;
  ttModalState.draftLineup = [];
  ttModalState.activeDateIdx = 0;
  setTtEditStatus('已清空全部 DJ 条目，请点击“保存”生效。');
  renderTtModalBody();
}

async function ttAutoMatchAllUnboundForCurrentEvent() {
  if (ttModalState.editMode || ttModalState.saving || !ttModalState.currentFest) return;
  ttModalState.saving = true;
  setTtEditStatus('正在自动匹配未绑定 DJ 并保存...');
  syncTtModalActionState();
  try {
    await ensureTtDJMatchMapLoaded();
    const source = Array.isArray(ttModalState.currentFest?.info?.lineup) ? ttModalState.currentFest.info.lineup : [];
    if (!source.length) {
      setTtEditStatus('当前活动没有可处理的 timetable 条目。');
      return;
    }
    const draft = toTtDraftRows(source);
    let touchedRows = 0;
    let appliedTotal = 0;
    for (const slot of draft) {
      const applied = ttApplyCandidateBindingsToSlot(slot);
      if (applied > 0) {
        touchedRows += 1;
        appliedTotal += applied;
      }
    }
    if (!appliedTotal) {
      setTtEditStatus('当前活动没有可自动匹配的未绑定 DJ。');
      return;
    }
    const cleaned = draft
      .filter((x) => {
        const m = String(x?.musician || '').trim();
        const d = String(x?.date || '').trim();
        const t = String(x?.time || '').trim();
        const s = String(x?.stage || '').trim();
        return m || d || t || s;
      })
      .map((x) => {
        const copy = { ...x };
        delete copy._rid;
        return normalizeLineupEntry(copy);
      });
    const payload = {
      ...ttModalState.currentFest.info,
      lineup: dedupeLineupEntries(cleaned),
      stageOrder: ttGetCurrentStageOrder(cleaned),
    };
    await persistFestivalPayload(ttModalState.currentFest, payload);
    if (ttModalState.currentRowEl) {
      refreshFestHeaderDisplay(ttModalState.currentRowEl, ttModalState.currentFest);
      const panel = ttModalState.currentRowEl.querySelector('.fest-info-panel');
      if (panel) {
        renderInfoView(panel, ttModalState.currentFest.info);
        if (panel.classList.contains('is-editing')) setEditInputs(panel, ttModalState.currentFest.info);
      }
    }
    setTtEditStatus(`自动匹配完成：${touchedRows} 条表演，已绑定 ${appliedTotal} 处`);
    renderTtModalBody();
  } catch (error) {
    setTtEditStatus(`自动匹配失败：${String(error?.message || '未知错误')}`, true);
  } finally {
    ttModalState.saving = false;
    syncTtModalActionState();
  }
}

async function ttRunAutoMatchForCurrentEventFromBindModal() {
  if (ttIsLibraryImportMode()) {
    ttSetBindStatus('当前入口仅用于导入 DJ，无法对 timetable 执行自动匹配。', 'err');
    return;
  }
  ttSetBindStatus('正在自动匹配当前 timetable 未绑定 DJ...', '');
  if (ttModalState.editMode) {
    await ttAutoMatchAllUnboundForCurrentDraft();
  } else {
    await ttAutoMatchAllUnboundForCurrentEvent();
  }
  const text = String(document.getElementById('tt-edit-status')?.textContent || '').trim();
  if (!text) {
    ttSetBindStatus('自动匹配已执行。', 'ok');
    return;
  }
  const isErr = /失败|error|未登录|无权限/i.test(text);
  ttSetBindStatus(text, isErr ? 'err' : 'ok');
}

function ttUpdateRowField(rid, field, value, rerender = false) {
  if (!ttModalState.editMode || ttModalState.saving) return;
  const row = ttModalState.draftLineup.find((x) => x._rid === rid);
  if (!row) return;
  const nextValue = String(value || '');
  row[field] = nextValue;
  if (field === 'date') {
    const nextDayIndex = ttResolveSlotDayIndex({ date: nextValue }) || 1;
    row.festivalDayIndex = nextDayIndex;
    row.date = ttFormatDayLabel(nextDayIndex);
    ttOpenDayDropdownRid = null;
  }
  if (rerender) {
    renderTtModalBody();
  }
}

function ttToggleDayDropdown(rid, event) {
  if (event && typeof event.stopPropagation === 'function') event.stopPropagation();
  if (!ttModalState.editMode || ttModalState.saving) return;
  ttOpenDayDropdownRid = Number(ttOpenDayDropdownRid) === Number(rid) ? null : Number(rid);
  renderTtModalBody();
}

function ttSelectDayOption(rid, value, event) {
  if (event && typeof event.stopPropagation === 'function') event.stopPropagation();
  ttUpdateRowField(rid, 'date', value, true);
}

function ttCloseDayDropdown() {
  if (ttOpenDayDropdownRid === null) return;
  ttOpenDayDropdownRid = null;
  if (ttModalState.editMode) renderTtModalBody();
}

function ttRemoveRow(rid) {
  if (!ttModalState.editMode || ttModalState.saving) return;
  ttModalState.draftLineup = ttModalState.draftLineup.filter((x) => x._rid !== rid);
  setTtEditStatus('已删除该条演出信息。');
  renderTtModalBody();
}

async function saveTtEditChanges() {
  if (!ttModalState.editMode || !ttModalState.currentFest || ttModalState.saving) return;
  ttModalState.saving = true;
  setTtEditStatus('正在保存时间表修改...');
  syncTtModalActionState();
  try {
    const preservedLineupArtists = buildEventLineupArtistsFromArchive(
      ttModalState.currentFest?.info?.lineupArtists || [],
      ttModalState.currentFest?.info?.lineup || []
    );
    const cleaned = (ttModalState.draftLineup || [])
      .filter((x) => {
        const m = String(x?.musician || '').trim();
        const d = String(x?.date || '').trim();
        const t = String(x?.time || '').trim();
        const s = String(x?.stage || '').trim();
        return m || d || t || s;
      })
      .map((x) => {
        const copy = { ...x };
        delete copy._rid;
        return normalizeLineupEntry(copy);
      });
    const payload = {
      ...ttModalState.currentFest.info,
      lineupArtists: preservedLineupArtists,
      lineup: dedupeLineupEntries(cleaned),
      stageOrder: ttGetCurrentStageOrder(cleaned),
    };
    await persistFestivalPayload(ttModalState.currentFest, payload);

    if (ttModalState.currentRowEl) {
      refreshFestHeaderDisplay(ttModalState.currentRowEl, ttModalState.currentFest);
      const panel = ttModalState.currentRowEl.querySelector('.fest-info-panel');
      if (panel) {
        renderInfoView(panel, ttModalState.currentFest.info);
        if (panel.classList.contains('is-editing')) setEditInputs(panel, ttModalState.currentFest.info);
      }
    }

    ttModalState.editMode = false;
    ttModalState.draftLineup = [];
    setTtEditStatus(`已保存 ${new Date().toLocaleTimeString()}`);
    syncTtModalActionState();
    renderTtModalBody();
  } catch (e) {
    setTtEditStatus(`保存失败：${e.message}`, true);
  } finally {
    ttModalState.saving = false;
    syncTtModalActionState();
  }
}

function renderTtStageOrderPanel(lineup, stages) {
  const panel = document.createElement('section');
  panel.className = 'tt-stage-order-panel';
  const orderedStages = ttGetCurrentStageOrder(lineup).filter((stage) => {
    if (!stages.length) return true;
    return stages.some((item) => String(item).toLowerCase() === String(stage).toLowerCase());
  });
  panel.innerHTML = `
    <div class="tt-stage-order-head">
      <div>
        <div class="tt-stage-order-title">舞台顺序</div>
        <div class="tt-stage-order-sub">拖动舞台标签调整展示顺序；保存后 iOS / Web 都会按这个顺序从左到右展示。</div>
      </div>
      <button class="tt-stage-order-save" type="button" onclick="void ttSaveStageOrderFromModal()">保存顺序</button>
    </div>
    <div id="tt-stage-order-list" class="tt-stage-order-list">
      ${orderedStages.map((stage, index) => `
        <button class="tt-stage-order-chip" type="button" draggable="true" data-stage="${escapeHtml(stage)}">
          <span class="tt-stage-order-grip">↕</span>
          <span class="tt-stage-order-index">${String(index + 1).padStart(2, '0')}</span>
          <span class="tt-stage-order-name">${renderBiTextHtml(stage, { compact: true })}</span>
        </button>
      `).join('')}
    </div>
  `;

  const list = panel.querySelector('#tt-stage-order-list');
  if (list) {
    list.querySelectorAll('.tt-stage-order-chip').forEach((chip) => {
      chip.addEventListener('dragstart', (event) => {
        chip.classList.add('dragging');
        event.dataTransfer.effectAllowed = 'move';
        event.dataTransfer.setData('text/plain', chip.dataset.stage || '');
      });
      chip.addEventListener('dragend', () => {
        chip.classList.remove('dragging');
        ttRefreshStageOrderChipIndexes(list);
      });
      chip.addEventListener('dragover', (event) => {
        event.preventDefault();
        const dragging = list.querySelector('.tt-stage-order-chip.dragging');
        if (!dragging || dragging === chip) return;
        const rect = chip.getBoundingClientRect();
        const before = event.clientX < rect.left + rect.width / 2;
        list.insertBefore(dragging, before ? chip : chip.nextSibling);
      });
      chip.addEventListener('click', () => {
        chip.classList.toggle('selected');
      });
    });
  }
  return panel;
}

function ttReadStageOrderFromModal() {
  const list = document.getElementById('tt-stage-order-list');
  if (!list) return ttGetCurrentStageOrder();
  return ttNormalizeStageOrder(
    [...list.querySelectorAll('.tt-stage-order-chip')].map((chip) => chip.dataset.stage || '')
  );
}

function ttRefreshStageOrderChipIndexes(list) {
  [...list.querySelectorAll('.tt-stage-order-chip')].forEach((chip, index) => {
    const indexEl = chip.querySelector('.tt-stage-order-index');
    if (indexEl) indexEl.textContent = String(index + 1).padStart(2, '0');
  });
}

async function ttSaveStageOrderFromModal() {
  if (!ttModalState.currentFest || ttModalState.saving) return;
  const stageOrder = ttReadStageOrderFromModal();
  ttModalState.saving = true;
  setTtEditStatus('正在保存舞台顺序...');
  syncTtModalActionState();
  try {
    const payload = {
      ...ttModalState.currentFest.info,
      stageOrder,
    };
    await persistFestivalPayload(ttModalState.currentFest, payload);
    if (ttModalState.currentRowEl) {
      refreshFestHeaderDisplay(ttModalState.currentRowEl, ttModalState.currentFest);
      const panel = ttModalState.currentRowEl.querySelector('.fest-info-panel');
      if (panel) {
        renderInfoView(panel, ttModalState.currentFest.info);
        if (panel.classList.contains('is-editing')) setEditInputs(panel, ttModalState.currentFest.info);
      }
    }
    setTtEditStatus(`舞台顺序已保存：${stageOrder.join(' → ') || '未配置'}`);
    renderTtModalBody();
  } catch (error) {
    setTtEditStatus(`保存舞台顺序失败：${String(error?.message || error)}`, true);
  } finally {
    ttModalState.saving = false;
    syncTtModalActionState();
  }
}

function renderTtModalBody() {
  const body = document.getElementById('tt-modal-body');
  body.innerHTML = '';
  const lineup = getTtWorkingLineup();

  if (!lineup.length && !ttModalState.editMode) {
    const artistCount = ttGetLineupArtistsForCurrentEvent().length;
    body.innerHTML = `<div class="tt-empty"><span class="tt-empty-icon">♪</span>${artistCount ? `已有 ${artistCount} 个 DJ 阵容，暂无 timetable` : '暂无 timetable 数据'}<br><span style="font-size:0.6rem;opacity:0.6">点击编辑后可从 DJ 阵容添加时间信息</span></div>`;
    return;
  }

  if (!lineup.length && ttModalState.editMode) {
    const tools = document.createElement('div');
    tools.className = 'tt-edit-toolbar';
    tools.innerHTML = `
      <button class="tt-edit-add-btn" onclick="ttAddRowForActiveDate()">+ 新增一条</button>
      <button class="tt-edit-add-btn tt-edit-clear-btn" onclick="ttClearAllRows()">清空全部DJ</button>
    `;
    body.appendChild(tools);
    const picker = ttRenderLineupArtistPicker();
    if (picker) body.appendChild(picker);
    const empty = document.createElement('div');
    empty.className = 'tt-empty';
    empty.style.padding = '2.5rem 1rem';
    empty.textContent = '当前没有 timetable 条目，可从 DJ 阵容添加或手动新增。';
    body.appendChild(empty);
    return;
  }

  const dateOrder = ttComputeDateOrder(lineup);
  if (ttModalState.activeDateIdx >= dateOrder.length) ttModalState.activeDateIdx = Math.max(0, dateOrder.length - 1);
  if (ttModalState.activeDateIdx < 0) ttModalState.activeDateIdx = 0;

  // Stats bar
  const stages = ttSortStageNames([...new Set(lineup.map(s => String(s.stage||'').trim()).filter(Boolean))], lineup);
  const statsEl = document.createElement('div');
  statsEl.className = 'tt-stats';
  statsEl.innerHTML = `
    <div class="tt-stat"><span>${lineup.length}</span>演出</div>
    <div class="tt-stat"><span>${dateOrder.length}</span>演出日</div>
    <div class="tt-stat"><span>${stages.length || 1}</span>舞台</div>
  `;
  body.appendChild(statsEl);
  if (stages.length > 1) {
    body.appendChild(renderTtStageOrderPanel(lineup, stages));
  }

  // Date tabs (only if >1 date)
  if (dateOrder.length > 1) {
    const navEl = document.createElement('div');
    navEl.className = 'tt-date-nav';
    dateOrder.forEach((d, i) => {
      const btn = document.createElement('button');
      btn.className = 'tt-date-tab' + (i === ttModalState.activeDateIdx ? ' active' : '');
      btn.textContent = d;
      btn.onclick = () => { ttModalState.activeDateIdx = i; renderTtDateContent(body, lineup, dateOrder, ttSortStageNames(stages, lineup)); updateDateTabs(navEl, ttModalState.activeDateIdx); };
      navEl.appendChild(btn);
    });
    body.appendChild(navEl);
  }

  if (ttModalState.editMode) {
    const tools = document.createElement('div');
    tools.className = 'tt-edit-toolbar';
    tools.innerHTML = `
      <button class="tt-edit-add-btn" onclick="ttAddRowForActiveDate()">+ 新增一条</button>
      <button class="tt-edit-add-btn tt-edit-candidate-btn" onclick="void ttAutoMatchAllUnboundForCurrentDraft()">批量自动匹配</button>
      <button class="tt-edit-add-btn tt-edit-clear-btn" onclick="ttClearAllRows()">清空全部DJ</button>
    `;
    body.appendChild(tools);
    const picker = ttRenderLineupArtistPicker();
    if (picker) body.appendChild(picker);
  } else {
    const tools = document.createElement('div');
    tools.className = 'tt-edit-toolbar';
    tools.innerHTML = `
      <button class="tt-edit-add-btn tt-edit-candidate-btn" onclick="ttAutoMatchAllUnboundForCurrentEvent()">自动匹配当前活动全部未绑定DJ</button>
    `;
    body.appendChild(tools);
  }

  renderTtDateContent(body, lineup, dateOrder, ttSortStageNames(stages, lineup));
}

function updateDateTabs(navEl, activeIdx) {
  navEl.querySelectorAll('.tt-date-tab').forEach((btn, i) => btn.classList.toggle('active', i === activeIdx));
}

function renderTtDateContent(body, lineup, dateOrder, stages) {
  // Remove previous content (but keep stats & nav)
  const existing = body.querySelector('.tt-content-area');
  if (existing) existing.remove();

  const contentArea = document.createElement('div');
  contentArea.className = 'tt-content-area';

  const activeDate = dateOrder[ttModalState.activeDateIdx] || dateOrder[0];
  const filtered = lineup.filter(s => ttRowDateValue(s) === activeDate);

  // Sort by time
  const dayRolloverHour = Number(ttModalState.currentFest?.info?.dayRolloverHour);
  filtered.sort((a, b) => {
    const aVal = ttTimelineSortVal(a.time, dayRolloverHour);
    const bVal = ttTimelineSortVal(b.time, dayRolloverHour);
    if (aVal !== bVal) return aVal - bVal;
    return String(a?.musician || '').localeCompare(String(b?.musician || ''), 'en', { sensitivity: 'base' });
  });

  if (ttModalState.editMode) {
    const wrap = document.createElement('div');
    wrap.className = 'tt-edit-stage-groups tt-content-area';
    if (!filtered.length) {
      wrap.innerHTML = `<div class="tt-empty" style="padding:2.5rem 1rem;">当前日期暂无条目，可点击上方“新增一条”。</div>`;
      body.appendChild(wrap);
      return;
    }

    const stageMap = new Map();
    for (const slot of filtered) {
      const stage = String(slot.stage || '').trim() || '主舞台';
      if (!stageMap.has(stage)) stageMap.set(stage, []);
      stageMap.get(stage).push(slot);
    }
    const stageNames = ttSortStageNames([...stageMap.keys()], lineup);

    wrap.innerHTML = stageNames.map((stageName) => {
      const stageSlots = stageMap.get(stageName) || [];
      return `
        <section class="tt-edit-stage-group">
          <div class="tt-edit-stage-group-head">
            <div class="tt-edit-stage-group-title">${renderBiTextHtml(stageName, { compact: true })}</div>
            <div class="tt-edit-stage-group-count">${stageSlots.length} 条</div>
          </div>
          <div class="tt-edit-table-wrap">
            <table class="tt-edit-table tt-edit-table-stage">
              <thead>
                <tr>
                  <th>Musician</th>
                  <th>Date</th>
                  <th>Time</th>
                  <th>Stage</th>
                  <th>绑定实体</th>
                  <th>DJ绑定</th>
                  <th>操作</th>
                </tr>
              </thead>
              <tbody>
                ${stageSlots.map((slot) => `
                  <tr>
                    <td><input type="text" value="${escapeHtml(slot.musician || '')}" oninput="ttUpdateRowField(${slot._rid}, 'musician', this.value)"></td>
                    <td>${ttRenderDaySelectCell(slot)}</td>
                    <td><input type="text" value="${escapeHtml(slot.time || '')}" oninput="ttUpdateRowField(${slot._rid}, 'time', this.value)"></td>
                    <td><input type="text" value="${escapeHtml(slot.stage || '')}" oninput="ttUpdateRowField(${slot._rid}, 'stage', this.value)" onchange="ttUpdateRowField(${slot._rid}, 'stage', this.value, true)"></td>
                    <td class="tt-dj-entity-cell">${ttRenderBoundEntitiesCellHtml(slot)}</td>
                    <td class="tt-dj-bind-cell">${ttRenderBindingCellHtml(slot)}</td>
                    <td><button class="tt-edit-del-btn" onclick="ttRemoveRow(${slot._rid})">删除</button></td>
                  </tr>
                `).join('')}
              </tbody>
            </table>
          </div>
        </section>
      `;
    }).join('');
    body.appendChild(wrap);
    return;
  }

  // Group by stage
  const stageMap = new Map();
  for (const slot of filtered) {
    const stage = String(slot.stage||'').trim() || '主舞台';
    if (!stageMap.has(stage)) stageMap.set(stage, []);
    stageMap.get(stage).push(slot);
  }

  const stageNames = ttSortStageNames([...stageMap.keys()], lineup);

  if (stageNames.length <= 1) {
    // Single stage or no stage info — flat grid
    const grid = document.createElement('div');
    grid.className = 'tt-flat-list';
    for (const slot of filtered) {
      const el = document.createElement('div');
      el.className = 'tt-flat-slot';
      const timeStr = String(slot.time||'').trim();
      const stageStr = stageNames.length === 1 && stageNames[0] !== '主舞台' ? stageNames[0] : '';
      el.appendChild(createTtMusicianNode(slot));

      const timeEl = document.createElement('div');
      timeEl.className = timeStr ? 'tt-slot-time' : 'tt-slot-time no-time';
      timeEl.textContent = timeStr || '时间未知';
      el.appendChild(timeEl);

      if (stageStr) {
        const stageEl = document.createElement('div');
        stageEl.className = 'stage-label';
        stageEl.innerHTML = renderBiTextHtml(stageStr, { compact: true });
        el.appendChild(stageEl);
      }
      grid.appendChild(el);
    }
    contentArea.appendChild(grid);
  } else {
    // Multi-stage column layout
    const wrap = document.createElement('div');
    const useScrollableLayout = ttShouldUseScrollableStageLayout(stageNames.length);
    wrap.className = 'tt-stages-wrap' + (useScrollableLayout ? ' is-scrollable' : '');
    wrap.style.setProperty('--tt-stage-count', String(Math.max(1, stageNames.length)));
    for (const stageName of stageNames) {
      const slots = stageMap.get(stageName) || [];
      const col = document.createElement('div');
      col.className = 'tt-stage-col';
      col.innerHTML = `<div class="tt-stage-col-header">${renderBiTextHtml(stageName, { compact: true })}</div>`;
      for (const slot of slots) {
        const timeStr = String(slot.time||'').trim();
        const el = document.createElement('div');
        el.className = 'tt-slot';
        el.appendChild(createTtMusicianNode(slot));

        const timeEl = document.createElement('div');
        timeEl.className = timeStr ? 'tt-slot-time' : 'tt-slot-time no-time';
        timeEl.textContent = timeStr || '时间未知';
        el.appendChild(timeEl);
        col.appendChild(el);
      }
      wrap.appendChild(col);
    }
    contentArea.appendChild(wrap);
  }

  body.appendChild(contentArea);
}

document.addEventListener('click', (event) => {
  const target = event.target;
  if (!(target instanceof Element)) {
    ttCloseDayDropdown();
    return;
  }
  if (target.closest('.tt-day-select')) return;
  ttCloseDayDropdown();
});

document.addEventListener('keydown', (event) => {
  if (event.key !== 'Escape') return;
  if (ttOpenDayDropdownRid !== null) {
    ttCloseDayDropdown();
    return;
  }
});
