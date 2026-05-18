// Feature module extracted from monolith (dj library + bulk)
function normalizeDJSearchText(value) {
  return String(value || '')
    .normalize('NFKD')
    .replace(/[\u0300-\u036f]/g, '')
    .toLowerCase();
}

function djLeadingLetter(name) {
  const up = String(name || '').trim().toUpperCase();
  const m = up.match(/[A-Z]/);
  return m ? m[0] : '#';
}

function setDJStatus(text, isError = false) {
  const el = document.getElementById('dj-status');
  if (!el) return;
  el.textContent = String(text || '');
  el.classList.toggle('error', !!isError);
}

function normalizeDJLibraryId(value) {
  return String(value || '').trim();
}

function isDJSelected(djId) {
  const id = normalizeDJLibraryId(djId);
  if (!id) return false;
  return djLibraryState.selectedIds instanceof Set && djLibraryState.selectedIds.has(id);
}

function getDJVisibleItemIds() {
  const visible = Array.isArray(djLibraryState.filteredItems) ? djLibraryState.filteredItems : [];
  return visible
    .map((item) => normalizeDJLibraryId(item?.id))
    .filter(Boolean);
}

function syncDJSelectedIdsWithLibrary() {
  if (!(djLibraryState.selectedIds instanceof Set)) {
    djLibraryState.selectedIds = new Set();
    return;
  }
  if (Number(djLibraryState.totalItems || 0) > (Array.isArray(djLibraryState.allItems) ? djLibraryState.allItems.length : 0)) {
    return;
  }
  const valid = new Set(
    (Array.isArray(djLibraryState.allItems) ? djLibraryState.allItems : [])
      .map((item) => normalizeDJLibraryId(item?.id))
      .filter(Boolean)
  );
  djLibraryState.selectedIds = new Set(
    [...djLibraryState.selectedIds].filter((id) => valid.has(id))
  );
}

function updateDJBulkSelectionButtons() {
  const modeBtn = document.getElementById('dj-selection-mode-btn');
  const selectVisibleBtn = document.getElementById('dj-select-visible-btn');
  const clearBtn = document.getElementById('dj-clear-selection-btn');
  const bilingualBtn = document.getElementById('dj-bilingualize-btn');
  const enrichmentBtn = document.getElementById('dj-enrichment-btn');
  const stopBtn = document.getElementById('dj-bilingual-stop-btn');
  const concurrencyInput = document.getElementById('dj-enrichment-concurrency-input');
  const reselectBtn = document.getElementById('dj-batch-reselect-btn');
  const selectRangeBtn = document.getElementById('dj-select-range-btn');
  const rangeStartInput = document.getElementById('dj-bilingual-range-start');
  const rangeEndInput = document.getElementById('dj-bilingual-range-end');
  const visibleIds = getDJVisibleItemIds();
  const selectedCount = djLibraryState.selectedIds instanceof Set ? djLibraryState.selectedIds.size : 0;
  const selectedVisibleCount = visibleIds.filter((id) => isDJSelected(id)).length;
  const allVisibleSelected = visibleIds.length > 0 && selectedVisibleCount === visibleIds.length;
  const translating = !!djLibraryState.translating;
  const selectionMode = !!djLibraryState.selectionMode;
  const hasUnsuccessful = djBilingualJobState.rows.some((row) => {
    const status = String(row?.status || '');
    return status !== 'updated';
  });

  if (modeBtn) {
    modeBtn.textContent = selectionMode ? '退出选择模式' : '进入选择模式';
    modeBtn.classList.toggle('active', selectionMode);
    modeBtn.disabled = translating;
  }
  if (selectVisibleBtn) {
    selectVisibleBtn.textContent = allVisibleSelected ? '取消全选当前结果' : '全选当前结果';
    selectVisibleBtn.disabled = translating || !selectionMode || visibleIds.length === 0;
  }
  if (clearBtn) {
    clearBtn.disabled = translating || !selectionMode || selectedCount === 0;
  }
  if (bilingualBtn) {
    bilingualBtn.disabled = translating || !selectionMode || selectedCount === 0;
    bilingualBtn.textContent = translating ? '双语化处理中...' : '选中DJ一键双语化';
  }
  if (enrichmentBtn) {
    enrichmentBtn.disabled = !selectionMode || selectedCount === 0;
  }
  if (stopBtn) {
    stopBtn.disabled = !translating;
  }
  if (concurrencyInput) {
    concurrencyInput.disabled = false;
  }
  if (reselectBtn) {
    reselectBtn.disabled = translating || !selectionMode || !hasUnsuccessful;
  }
  if (selectRangeBtn) selectRangeBtn.disabled = translating || !selectionMode || visibleIds.length === 0;
  if (rangeStartInput) rangeStartInput.disabled = translating || !selectionMode;
  if (rangeEndInput) rangeEndInput.disabled = translating || !selectionMode;
}

function setDJSelectionMode(enabled) {
  const next = !!enabled;
  if (djLibraryState.translating) return;
  if (next === !!djLibraryState.selectionMode) return;
  djLibraryState.selectionMode = next;
  if (!next) {
    clearDJSelection(false);
  }
  renderDJGrid();
  updateDJToolbarMeta();
  if (next) {
    setDJStatus('已进入选择模式：可用索引区间或复选框批量选择 DJ。');
  } else {
    setDJStatus('已退出选择模式。');
  }
}

function toggleDJSelectionMode() {
  setDJSelectionMode(!djLibraryState.selectionMode);
}

function updateDJToolbarMeta() {
  const el = document.getElementById('dj-toolbar-meta');
  if (!el) {
    updateDJBulkSelectionButtons();
    return;
  }
  const total = djLibraryState.allItems.length;
  const visible = Number(djLibraryState.totalItems || djLibraryState.filteredItems.length || 0);
  const pageItems = Array.isArray(djLibraryState.pageItems) ? djLibraryState.pageItems.length : 0;
  const page = Math.max(1, Number(djLibraryState.page || 1));
  const totalPages = Math.max(1, Number(djLibraryState.totalPages || 1));
  const letter = djLibraryState.activeLetter === 'ALL' ? '全部' : djLibraryState.activeLetter;
  const selected = djLibraryState.selectedIds instanceof Set ? djLibraryState.selectedIds.size : 0;
  const totalLabel = Number(djLibraryState.totalItems || 0) > total ? djLibraryState.totalItems : total;
  el.textContent = `总计 ${totalLabel} · 当前 ${visible} · 本页 ${pageItems} · ${page}/${totalPages} · 已选 ${selected} · 字母 ${letter}`;
  updateDJBulkSelectionButtons();
}

function setDJSelected(djId, selected) {
  const id = normalizeDJLibraryId(djId);
  if (!id) return;
  if (!(djLibraryState.selectedIds instanceof Set)) {
    djLibraryState.selectedIds = new Set();
  }
  if (selected) {
    djLibraryState.selectedIds.add(id);
  } else {
    djLibraryState.selectedIds.delete(id);
  }
  updateDJToolbarMeta();
}

function clearDJSelection(shouldRender = true) {
  djLibraryState.selectedIds = new Set();
  updateDJToolbarMeta();
  if (shouldRender) renderDJGrid();
}

function toggleDJSelectVisible() {
  if (!djLibraryState.selectionMode) {
    setDJStatus('请先进入选择模式。', true);
    return;
  }
  const visibleIds = getDJVisibleItemIds();
  if (!visibleIds.length || djLibraryState.translating) return;
  const allSelected = visibleIds.every((id) => isDJSelected(id));
  visibleIds.forEach((id) => setDJSelected(id, !allSelected));
  renderDJGrid();
}
