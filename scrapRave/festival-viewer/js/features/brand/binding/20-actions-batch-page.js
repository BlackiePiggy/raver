// Event-brand binding module extracted from 10-event-brand-binding (actions + batch + page lifecycle)
function findEventBrandRowByEventId(eventId) {
  const target = String(eventId || '').trim();
  if (!target) return null;
  return (Array.isArray(eventBrandBindingState.allRows) ? eventBrandBindingState.allRows : [])
    .find((row) => String(row?.eventId || '').trim() === target) || null;
}

function updateLocalEventBrandBinding(row, brandCandidate) {
  const brand = (brandCandidate && typeof brandCandidate === 'object') ? (brandCandidate.raw || brandCandidate) : null;
  const brandId = String(brandCandidate?.id || '').trim();
  const brandName = brand ? eventBrandDisplayName(brand) : '';
  row.wikiFestivalId = brandId;
  row.wikiFestivalName = brandName;
  row.wikiFestival = brand || null;
  if (row.fest?.info) {
    row.fest.info.wikiFestivalId = brandId;
    row.fest.info.wikiFestival = brand || null;
  }
}

async function saveSingleEventBrandBinding(row, brandCandidate) {
  const eventId = String(row?.eventId || '').trim();
  if (!eventId) {
    setEventBrandStatus('该活动缺少后端 eventId，无法绑定。', 'error');
    return;
  }
  const authHeaders = getViewerAuthHeaders();
  if (!authHeaders.Authorization) {
    openViewerLogin();
    setEventBrandStatus('请先登录后再操作绑定。', 'error');
    return;
  }
  eventBrandBindingState.saving = true;
  const brandId = String(brandCandidate?.id || '').trim();
  try {
    setEventBrandStatus(`正在更新：${row.nameDisplay}`);
    await apiPost(`/api/raver/events/${encodeURIComponent(eventId)}/update`, {
      wikiFestivalId: brandId || null,
    }, authHeaders);
    updateLocalEventBrandBinding(row, brandId ? brandCandidate : null);
    renderEventBrandBindingTable();
    setEventBrandStatus(
      brandId ? `已绑定 ${row.nameDisplay} -> ${row.wikiFestivalName || brandId}` : `已解绑 ${row.nameDisplay}`,
      'ok'
    );
  } catch (error) {
    setEventBrandStatus(`更新失败：${String(error?.message || '未知错误')}`, 'error');
  } finally {
    eventBrandBindingState.saving = false;
  }
}

function selectAllEventBrandVisible() {
  recomputeEventBrandFilteredRows();
  const rows = Array.isArray(eventBrandBindingState.filteredRows) ? eventBrandBindingState.filteredRows : [];
  for (const row of rows) {
    const key = eventBrandRowKey(row);
    if (!key || !row.eventId) continue;
    eventBrandBindingState.selectedEventIds.add(key);
  }
  renderEventBrandBindingTable();
}

function clearEventBrandSelection() {
  eventBrandBindingState.selectedEventIds.clear();
  renderEventBrandBindingTable();
}

async function applyBatchBrandBinding() {
  const authHeaders = getViewerAuthHeaders();
  if (!authHeaders.Authorization) {
    openViewerLogin();
    setEventBrandStatus('请先登录后再批量绑定。', 'error');
    return;
  }
  if (eventBrandBindingState.saving) return;
  const selectedRows = (Array.isArray(eventBrandBindingState.allRows) ? eventBrandBindingState.allRows : [])
    .filter((row) => {
      const key = eventBrandRowKey(row);
      return key && row.eventId && eventBrandBindingState.selectedEventIds.has(key);
    });
  if (!selectedRows.length) {
    setEventBrandStatus('请先勾选至少一个活动。', 'error');
    return;
  }

  const batchInput = document.getElementById('event-brand-batch-brand-input');
  const candidate = resolveEventBrandCandidateByText(batchInput?.value || '');
  if (!candidate?.id) {
    setEventBrandStatus('请先在“批量绑定到同一 Brand”输入并选择一个存在的 Brand。', 'error');
    return;
  }

  eventBrandBindingState.saving = true;
  let success = 0;
  let failed = 0;
  for (let i = 0; i < selectedRows.length; i += 1) {
    const row = selectedRows[i];
    setEventBrandStatus(`批量绑定进行中 ${i + 1}/${selectedRows.length}：${row.nameDisplay}`);
    try {
      await apiPost(`/api/raver/events/${encodeURIComponent(row.eventId)}/update`, {
        wikiFestivalId: candidate.id,
      }, authHeaders);
      updateLocalEventBrandBinding(row, candidate);
      success += 1;
    } catch (_error) {
      failed += 1;
    }
  }
  eventBrandBindingState.saving = false;
  renderEventBrandBindingTable();
  if (failed > 0) {
    setEventBrandStatus(`批量绑定完成：成功 ${success}，失败 ${failed}。`, 'error');
  } else {
    setEventBrandStatus(`批量绑定完成：成功 ${success}。`, 'ok');
  }
}

async function clearBatchBrandBinding() {
  const authHeaders = getViewerAuthHeaders();
  if (!authHeaders.Authorization) {
    openViewerLogin();
    setEventBrandStatus('请先登录后再批量解绑。', 'error');
    return;
  }
  if (eventBrandBindingState.saving) return;
  const selectedRows = (Array.isArray(eventBrandBindingState.allRows) ? eventBrandBindingState.allRows : [])
    .filter((row) => {
      const key = eventBrandRowKey(row);
      return key && row.eventId && eventBrandBindingState.selectedEventIds.has(key);
    });
  if (!selectedRows.length) {
    setEventBrandStatus('请先勾选至少一个活动。', 'error');
    return;
  }

  eventBrandBindingState.saving = true;
  let success = 0;
  let failed = 0;
  for (let i = 0; i < selectedRows.length; i += 1) {
    const row = selectedRows[i];
    setEventBrandStatus(`批量解绑进行中 ${i + 1}/${selectedRows.length}：${row.nameDisplay}`);
    try {
      await apiPost(`/api/raver/events/${encodeURIComponent(row.eventId)}/update`, {
        wikiFestivalId: null,
      }, authHeaders);
      updateLocalEventBrandBinding(row, null);
      success += 1;
    } catch (_error) {
      failed += 1;
    }
  }
  eventBrandBindingState.saving = false;
  renderEventBrandBindingTable();
  if (failed > 0) {
    setEventBrandStatus(`批量解绑完成：成功 ${success}，失败 ${failed}。`, 'error');
  } else {
    setEventBrandStatus(`批量解绑完成：成功 ${success}。`, 'ok');
  }
}

function bindEventBrandBatchInputBehavior() {
  const batchInput = document.getElementById('event-brand-batch-brand-input');
  const batchBrandIdInput = document.getElementById('event-brand-batch-brand-id');
  if (!batchInput || batchInput.dataset.bound === '1') return;
  batchInput.dataset.bound = '1';
  batchInput.setAttribute('list', ensureEventBrandBindingDatalist(batchInput.value || ''));
  batchInput.addEventListener('focus', () => {
    batchInput.setAttribute('list', ensureEventBrandBindingDatalist(batchInput.value || ''));
  });
  batchInput.addEventListener('input', () => {
    batchInput.setAttribute('list', ensureEventBrandBindingDatalist(batchInput.value || ''));
    if (batchBrandIdInput) batchBrandIdInput.value = '';
  });
  batchInput.addEventListener('change', () => {
    const hit = resolveEventBrandCandidateByText(batchInput.value);
    if (hit) {
      batchInput.value = hit.name;
      if (batchBrandIdInput) batchBrandIdInput.value = hit.id;
    } else if (batchBrandIdInput) {
      batchBrandIdInput.value = '';
    }
  });
}

function renderEventBrandBindingPage() {
  refreshEventBrandRowsFromSource();
  renderEventBrandBindingTable();
}

async function ensureEventBrandBindingPageLoaded(force = false) {
  if (eventBrandBindingState.loading) return;
  if (eventBrandBindingState.initialized && !force) {
    renderEventBrandBindingPage();
    setEventBrandStatus('');
    return;
  }
  eventBrandBindingState.loading = true;
  setEventBrandStatus('正在加载 Event / Brand 绑定数据...');
  try {
    await ensureBrandPageLoaded(false);
    bindEventBrandBatchInputBehavior();
    refreshEventBrandRowsFromSource();
    eventBrandBindingState.initialized = true;
    renderEventBrandBindingTable();
    setEventBrandStatus(`已加载 ${eventBrandBindingState.allRows.length} 个活动。`);
  } catch (error) {
    setEventBrandStatus(`加载失败：${String(error?.message || '未知错误')}`, 'error');
  } finally {
    eventBrandBindingState.loading = false;
  }
}

async function refreshEventBrandBindingPage(force = false) {
  if (force) {
    eventBrandBindingState.initialized = false;
  }
  await ensureEventBrandBindingPageLoaded(!!force);
}
