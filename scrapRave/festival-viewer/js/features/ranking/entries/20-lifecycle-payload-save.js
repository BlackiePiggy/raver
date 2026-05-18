// Ranking entries: editor lifecycle, payload collection, and save submission.
const rankingEntriesLifecycleState = (typeof getRankingState === 'function')
  ? getRankingState()
  : rankingPageState;

async function openRankingEntriesEditor() {
  const board = getActiveRankingBoard();
  if (!board) {
    setRankingStatus('请先选择一个榜单', true);
    return;
  }
  if (!Number.isFinite(Number(rankingEntriesLifecycleState.activeYear))) {
    setRankingStatus('请先选择榜单年份', true);
    return;
  }
  const year = Number(rankingEntriesLifecycleState.activeYear);
  const catalog = await buildRankingEntityCatalog(board.entityType);
  rankingEntriesLifecycleState.entriesEditorCatalog = catalog;
  rankingEntriesLifecycleState.entriesEditorSearchResults = [];
  rankingEntriesLifecycleState.entriesEditorSearchQuery = '';
  rankingEntriesLifecycleState.entriesEditorSearchSeq = 0;
  refreshRankingEntityDatalist(catalog);
  rankingEntriesLifecycleState.entriesEditorRows = (Array.isArray(rankingEntriesLifecycleState.entries) ? rankingEntriesLifecycleState.entries : []).map((entry) => ({
    rank: Number(entry?.rank || 0) || 0,
    name: String(entry?.name || '').trim(),
    entityId: String(entry?.entityId || entry?.festival?.id || entry?.dj?.id || '').trim(),
  }));
  rankingEntriesLifecycleState.entriesEditorYear = year;
  const yearInput = document.getElementById('ranking-entries-edit-year');
  if (yearInput) yearInput.value = String(year);
  const importInput = document.getElementById('ranking-entries-import-text');
  if (importInput) importInput.value = '';
  const titleEl = document.getElementById('ranking-entries-editor-title');
  const subEl = document.getElementById('ranking-entries-editor-sub');
  if (titleEl) titleEl.textContent = `编辑位次 · ${board.title} · ${year}`;
  if (subEl) subEl.textContent = board.entityType === 'festival'
    ? '每个位次可绑定现有 Brand（用于图片和点击跳转）'
    : '每个位次可绑定现有 DJ（用于图片和点击跳转）';
  rankingEntriesLifecycleState.entriesEditorSaving = false;
  rankingEntriesLifecycleState.entriesEditorOpen = true;
  setRankingEntriesEditStatus('');
  const overlay = document.getElementById('ranking-entries-editor-overlay');
  if (overlay) overlay.classList.add('open');
  document.body.style.overflow = 'hidden';
  renderRankingEntriesEditorRows();
}

function closeRankingEntriesEditor() {
  const overlay = document.getElementById('ranking-entries-editor-overlay');
  if (overlay) overlay.classList.remove('open');
  if (rankingEntriesLifecycleState.entriesEditorSearchTimer) {
    clearTimeout(rankingEntriesLifecycleState.entriesEditorSearchTimer);
    rankingEntriesLifecycleState.entriesEditorSearchTimer = null;
  }
  rankingEntriesLifecycleState.entriesEditorSearchSeq = 0;
  rankingEntriesLifecycleState.entriesEditorSearchResults = [];
  rankingEntriesLifecycleState.entriesEditorSearchQuery = '';
  rankingEntriesLifecycleState.entriesEditorOpen = false;
  rankingEntriesLifecycleState.entriesEditorSaving = false;
  rankingEntriesLifecycleState.entriesEditorRows = [];
  rankingEntriesLifecycleState.entriesEditorCatalog = [];
  rankingEntriesLifecycleState.entriesEditorYear = null;
  rankingEntriesLifecycleState.entriesEditorUnmatchedViewMode = 'all';
  const summaryEl = document.getElementById('ranking-entry-match-summary');
  if (summaryEl) summaryEl.innerHTML = '';
  const unmatchedWrap = document.getElementById('ranking-entry-unmatched-wrap');
  if (unmatchedWrap) {
    unmatchedWrap.style.display = 'none';
    unmatchedWrap.innerHTML = '';
  }
  setRankingEntriesEditStatus('');
  document.body.style.overflow = '';
}

function handleRankingEntriesEditorOverlayClick(event) {
  if (event.target === event.currentTarget) closeRankingEntriesEditor();
}

function collectRankingEntriesPayload() {
  const board = getActiveRankingBoard();
  if (!board) throw new Error('未选择榜单');
  const year = Number(document.getElementById('ranking-entries-edit-year')?.value || rankingEntriesLifecycleState.entriesEditorYear || 0);
  if (!Number.isFinite(year) || year < 1900 || year > 2200) {
    throw new Error('年份无效');
  }
  const catalog = Array.isArray(rankingEntriesLifecycleState.entriesEditorCatalog) ? rankingEntriesLifecycleState.entriesEditorCatalog : [];
  const rankInputs = Array.from(document.querySelectorAll('input[data-rank-row]'));
  const nameInputs = Array.from(document.querySelectorAll('input[data-name-row]'));
  const entityInputs = Array.from(document.querySelectorAll('input[data-entity-row]'));
  const rowCount = Math.max(rankInputs.length, nameInputs.length, entityInputs.length);
  const rows = [];
  for (let i = 0; i < rowCount; i += 1) {
    const rank = Number(rankInputs[i]?.value || i + 1);
    const name = String(nameInputs[i]?.value || '').trim();
    const entityRaw = String(entityInputs[i]?.value || '').trim();
    if (!name) continue;
    if (!Number.isFinite(rank) || rank <= 0) continue;
    const entityId = parseRankingEntityInputToId(entityRaw, catalog);
    rows.push({
      rank: Math.floor(rank),
      name,
      ...(entityId ? { entityId } : {}),
    });
  }
  if (!rows.length) {
    throw new Error('至少保留一条位次数据');
  }
  rows.sort((a, b) => a.rank - b.rank);
  return {
    boardId: board.id,
    year: Math.floor(year),
    entries: rows,
  };
}

async function saveRankingEntriesEditor() {
  const headers = getViewerAuthHeaders();
  if (!headers.Authorization) {
    openViewerLogin();
    setRankingEntriesEditStatus('请先登录后再保存', 'err');
    return;
  }
  let payload;
  try {
    payload = collectRankingEntriesPayload();
  } catch (error) {
    setRankingEntriesEditStatus(String(error?.message || '参数错误'), 'err');
    return;
  }
  rankingEntriesLifecycleState.entriesEditorSaving = true;
  renderRankingEntriesEditorRows();
  setRankingEntriesEditStatus('正在保存位次...');
  try {
    await apiPost(
      `/api/raver/learn/rankings/${encodeURIComponent(payload.boardId)}/years/${encodeURIComponent(String(payload.year))}/upsert`,
      { entries: payload.entries },
      headers
    );
    rankingEntriesLifecycleState.activeBoardId = payload.boardId;
    rankingEntriesLifecycleState.activeYear = payload.year;
    setRankingEntriesEditStatus('位次保存成功', 'ok');
    await refreshRankingPage(true);
    closeRankingEntriesEditor();
  } catch (error) {
    setRankingEntriesEditStatus(`保存失败：${String(error?.message || '未知错误')}`, 'err');
  } finally {
    rankingEntriesLifecycleState.entriesEditorSaving = false;
    renderRankingEntriesEditorRows();
  }
}
