// Feature module extracted from monolith (ranking admin)
const rankingBoardState = (typeof getRankingState === "function")
  ? getRankingState()
  : rankingPageState;

function onRankingBoardChanged(boardId) {
  const id = String(boardId || '').trim();
  if (!id || rankingBoardState.activeBoardId === id) return;
  rankingBoardState.activeBoardId = id;
  rankingBoardState.activeYear = null;
  loadRankingEntries();
}

function onRankingYearChanged(yearValue = null) {
  const select = document.getElementById('ranking-year-select');
  const raw = yearValue !== null && yearValue !== undefined ? yearValue : (select ? select.value : '');
  const year = Number(raw);
  if (!Number.isFinite(year)) return;
  if (select && String(select.value) !== String(year)) {
    select.value = String(year);
  }
  rankingBoardState.activeYear = year;
  loadRankingEntries();
}

function setRankingBoardEditStatus(text, level = '') {
  const el = document.getElementById('ranking-board-edit-status');
  if (!el) return;
  el.textContent = String(text || '');
  el.classList.remove('err', 'ok');
  if (level) el.classList.add(level);
}

function setRankingEntriesEditStatus(text, level = '') {
  const el = document.getElementById('ranking-entries-edit-status');
  if (!el) return;
  el.textContent = String(text || '');
  el.classList.remove('err', 'ok');
  if (level) el.classList.add(level);
}

function parseRankingYearsInput(raw) {
  const text = String(raw || '').trim();
  if (!text) return [];
  return Array.from(new Set(
    text
      .split(/[,\uFF0C\s]+/g)
      .map((x) => Number(x))
      .filter((x) => Number.isFinite(x) && x >= 1900 && x <= 2200)
      .map((x) => Math.floor(x))
  )).sort((a, b) => a - b);
}

function cloneRankingBoardDraft(item, isNew = false) {
  const board = item && typeof item === 'object' ? item : {};
  const nowYear = new Date().getFullYear();
  return {
    isNew: !!isNew,
    id: String(board.id || '').trim(),
    title: String(board.title || '').trim(),
    subtitle: String(board.subtitle || '').trim(),
    description: String(board.description || '').trim(),
    coverImageUrl: String(board.coverImageUrl || '').trim(),
    entityType: String(board.entityType || '').trim() === 'festival' ? 'festival' : 'dj',
    years: Array.isArray(board.years)
      ? board.years.map((x) => Number(x)).filter((x) => Number.isFinite(x)).map((x) => Math.floor(x)).sort((a, b) => a - b)
      : [nowYear],
  };
}

function renderRankingBoardEditorFromDraft() {
  const draft = rankingBoardState.boardEditorDraft;
  const overlay = document.getElementById('ranking-board-editor-overlay');
  if (!overlay || !draft) return;
  const isBusy = !!rankingBoardState.boardEditorSaving || !!rankingBoardState.boardEditorUploading;
  const bindInput = (id, value) => {
    const el = document.getElementById(id);
    if (el && el.value !== String(value ?? '')) el.value = String(value ?? '');
  };
  bindInput('ranking-board-edit-id', draft.id);
  bindInput('ranking-board-edit-title', draft.title);
  bindInput('ranking-board-edit-subtitle', draft.subtitle);
  bindInput('ranking-board-edit-description', draft.description);
  bindInput('ranking-board-edit-years', (Array.isArray(draft.years) ? draft.years : []).join(', '));
  const typeSelect = document.getElementById('ranking-board-edit-entity-type');
  if (typeSelect && typeSelect.value !== draft.entityType) {
    typeSelect.value = draft.entityType;
  }
  const titleEl = document.getElementById('ranking-board-editor-title');
  const subEl = document.getElementById('ranking-board-editor-sub');
  if (titleEl) titleEl.textContent = draft.isNew ? '新增榜单' : `编辑榜单 · ${draft.title || draft.id || '-'}`;
  if (subEl) subEl.textContent = draft.isNew ? '创建榜单信息，后续可导入位次' : '修改榜单名称、描述、封面与年份';
  renderBrandImagePreview('ranking-board-cover-preview', draft.coverImageUrl, 'NO COVER');

  const idInput = document.getElementById('ranking-board-edit-id');
  const saveBtn = document.getElementById('ranking-board-save-btn');
  const deleteBtn = document.getElementById('ranking-board-delete-btn');
  const uploadBtn = document.getElementById('ranking-board-cover-upload-btn');
  const fileInput = document.getElementById('ranking-board-cover-file');

  if (idInput) idInput.disabled = !draft.isNew || isBusy;
  const toggleIds = [
    'ranking-board-edit-title',
    'ranking-board-edit-subtitle',
    'ranking-board-edit-description',
    'ranking-board-edit-years',
    'ranking-board-edit-entity-type',
  ];
  toggleIds.forEach((id) => {
    const el = document.getElementById(id);
    if (el) el.disabled = isBusy;
  });
  if (saveBtn) saveBtn.disabled = isBusy;
  if (uploadBtn) uploadBtn.disabled = isBusy;
  if (fileInput) fileInput.disabled = isBusy;
  if (deleteBtn) {
    deleteBtn.style.display = draft.isNew ? 'none' : 'inline-block';
    deleteBtn.disabled = isBusy;
  }
}

function openRankingBoardEditorCreate() {
  rankingBoardState.boardEditorDraft = cloneRankingBoardDraft({}, true);
  rankingBoardState.boardEditorSaving = false;
  rankingBoardState.boardEditorUploading = false;
  rankingBoardState.boardEditorOpen = true;
  setRankingBoardEditStatus('');
  const overlay = document.getElementById('ranking-board-editor-overlay');
  if (overlay) overlay.classList.add('open');
  document.body.style.overflow = 'hidden';
  renderRankingBoardEditorFromDraft();
}

function openRankingBoardEditorEdit() {
  const board = getActiveRankingBoard();
  if (!board) {
    setRankingStatus('请先选择一个榜单', true);
    return;
  }
  rankingBoardState.boardEditorDraft = cloneRankingBoardDraft(board, false);
  rankingBoardState.boardEditorSaving = false;
  rankingBoardState.boardEditorUploading = false;
  rankingBoardState.boardEditorOpen = true;
  setRankingBoardEditStatus('');
  const overlay = document.getElementById('ranking-board-editor-overlay');
  if (overlay) overlay.classList.add('open');
  document.body.style.overflow = 'hidden';
  renderRankingBoardEditorFromDraft();
}

function closeRankingBoardEditor() {
  const overlay = document.getElementById('ranking-board-editor-overlay');
  if (overlay) overlay.classList.remove('open');
  rankingBoardState.boardEditorOpen = false;
  rankingBoardState.boardEditorSaving = false;
  rankingBoardState.boardEditorUploading = false;
  rankingBoardState.boardEditorDraft = null;
  setRankingBoardEditStatus('');
  document.body.style.overflow = '';
}

function handleRankingBoardEditorOverlayClick(event) {
  if (event.target === event.currentTarget) closeRankingBoardEditor();
}

function clearRankingBoardCover() {
  const draft = rankingBoardState.boardEditorDraft;
  if (!draft) return;
  draft.coverImageUrl = '';
  const input = document.getElementById('ranking-board-cover-file');
  if (input) input.value = '';
  renderRankingBoardEditorFromDraft();
}

function sanitizeRankingBoardIdInput(value) {
  const normalized = String(value || '')
    .trim()
    .toLowerCase()
    .replace(/[^a-z0-9_-]+/g, '-')
    .replace(/^-+|-+$/g, '')
    .replace(/^_+|_+$/g, '');
  return normalized;
}

async function uploadRankingBoardCover() {
  const draft = rankingBoardState.boardEditorDraft;
  if (!draft) return;
  const headers = getViewerAuthHeaders();
  if (!headers.Authorization) {
    openViewerLogin();
    setRankingBoardEditStatus('请先登录后再上传封面', 'err');
    return;
  }
  const input = document.getElementById('ranking-board-cover-file');
  const file = input?.files?.[0];
  if (!file) {
    setRankingBoardEditStatus('请先选择封面图片', 'err');
    return;
  }
  rankingBoardState.boardEditorUploading = true;
  renderRankingBoardEditorFromDraft();
  setRankingBoardEditStatus('正在上传封面...');
  try {
    const form = new FormData();
    form.append('image', file);
    form.append('boardId', String(draft.id || draft.title || `ranking-${Date.now()}`));
    const resp = await apiPostForm('/api/raver/learn/rankings/upload-image', form, headers);
    const payload = (resp && typeof resp === 'object' && resp.data && typeof resp.data === 'object') ? resp.data : resp;
    const url = String(payload?.url || '').trim();
    if (!url) throw new Error('上传成功但未返回 URL');
    draft.coverImageUrl = url;
    if (input) input.value = '';
    setRankingBoardEditStatus('封面上传成功', 'ok');
  } catch (error) {
    setRankingBoardEditStatus(`封面上传失败：${String(error?.message || '未知错误')}`, 'err');
  } finally {
    rankingBoardState.boardEditorUploading = false;
    renderRankingBoardEditorFromDraft();
  }
}

function collectRankingBoardPayload() {
  const draft = rankingBoardState.boardEditorDraft;
  if (!draft) throw new Error('编辑器未初始化');
  const get = (id) => String(document.getElementById(id)?.value || '').trim();
  const id = sanitizeRankingBoardIdInput(get('ranking-board-edit-id') || draft.id || get('ranking-board-edit-title'));
  const title = get('ranking-board-edit-title');
  if (!title) throw new Error('榜单名称为必填项');
  if (draft.isNew && !id) throw new Error('榜单 ID 为必填项');
  const entityType = String(document.getElementById('ranking-board-edit-entity-type')?.value || draft.entityType || 'festival').trim() === 'festival'
    ? 'festival'
    : 'dj';
  const years = parseRankingYearsInput(get('ranking-board-edit-years'));
  return {
    id,
    title,
    subtitle: get('ranking-board-edit-subtitle'),
    description: get('ranking-board-edit-description'),
    entityType,
    years,
    coverImageUrl: String(draft.coverImageUrl || '').trim(),
  };
}

async function saveRankingBoardEditor() {
  const draft = rankingBoardState.boardEditorDraft;
  if (!draft) return;
  const headers = getViewerAuthHeaders();
  if (!headers.Authorization) {
    openViewerLogin();
    setRankingBoardEditStatus('请先登录后再保存', 'err');
    return;
  }
  let payload;
  try {
    payload = collectRankingBoardPayload();
  } catch (error) {
    setRankingBoardEditStatus(String(error?.message || '参数错误'), 'err');
    return;
  }
  rankingBoardState.boardEditorSaving = true;
  renderRankingBoardEditorFromDraft();
  setRankingBoardEditStatus('正在保存榜单...');
  try {
    if (draft.isNew) {
      await apiPost('/api/raver/learn/rankings', payload, headers);
      rankingBoardState.activeBoardId = payload.id;
    } else {
      await apiPost(`/api/raver/learn/rankings/${encodeURIComponent(String(draft.id))}/update`, payload, headers);
      rankingBoardState.activeBoardId = draft.id;
    }
    setRankingBoardEditStatus('保存成功', 'ok');
    await refreshRankingPage(true);
    closeRankingBoardEditor();
  } catch (error) {
    setRankingBoardEditStatus(`保存失败：${String(error?.message || '未知错误')}`, 'err');
  } finally {
    rankingBoardState.boardEditorSaving = false;
    renderRankingBoardEditorFromDraft();
  }
}

async function deleteRankingBoardEditor() {
  const draft = rankingBoardState.boardEditorDraft;
  if (!draft || draft.isNew) return;
  const headers = getViewerAuthHeaders();
  if (!headers.Authorization) {
    openViewerLogin();
    setRankingBoardEditStatus('请先登录后再删除', 'err');
    return;
  }
  if (!window.confirm(`确认删除榜单「${draft.title || draft.id}」吗？此操作不可恢复。`)) return;
  rankingBoardState.boardEditorSaving = true;
  renderRankingBoardEditorFromDraft();
  setRankingBoardEditStatus('正在删除榜单...');
  try {
    await apiPost(`/api/raver/learn/rankings/${encodeURIComponent(String(draft.id))}/delete`, {}, headers);
    setRankingBoardEditStatus('删除成功', 'ok');
    closeRankingBoardEditor();
    await refreshRankingPage(true);
  } catch (error) {
    setRankingBoardEditStatus(`删除失败：${String(error?.message || '未知错误')}`, 'err');
  } finally {
    rankingBoardState.boardEditorSaving = false;
    renderRankingBoardEditorFromDraft();
  }
}
