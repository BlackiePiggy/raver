// Ranking entries: row normalization, summary, unmatched grouping, and table rendering.
const rankingEntriesRenderState = (typeof getRankingState === 'function')
  ? getRankingState()
  : rankingPageState;

function normalizeRankingEntriesEditorRows(rows) {
  const source = Array.isArray(rows) ? rows : [];
  const normalized = source
    .map((row, idx) => {
      const rank = Number(row?.rank);
      const name = String(row?.name || '').trim();
      const entityId = String(row?.entityId || '').trim();
      const rid = String(row?._rid || '').trim() || `rr-${rankingEntriesRowSeed++}`;
      return {
        _rid: rid,
        rank: Number.isFinite(rank) && rank > 0 ? Math.floor(rank) : idx + 1,
        name,
        entityId,
      };
    })
    .filter((row) => row.name || row.entityId || Number.isFinite(row.rank));
  normalized.sort((a, b) => a.rank - b.rank);
  return normalized;
}

function rankingEntriesMatchStats(rows) {
  const source = Array.isArray(rows) ? rows : [];
  let total = 0;
  let matched = 0;
  let unmatched = 0;
  for (const row of source) {
    const name = String(row?.name || '').trim();
    if (!name) continue;
    total += 1;
    if (String(row?.entityId || '').trim()) matched += 1;
    else unmatched += 1;
  }
  return { total, matched, unmatched };
}

function renderRankingEntriesEditorSummary(rows) {
  const el = document.getElementById('ranking-entry-match-summary');
  if (!el) return;
  const board = getActiveRankingBoard();
  if (!board || board.entityType !== 'dj') {
    el.innerHTML = '';
    return;
  }
  const stats = rankingEntriesMatchStats(rows);
  const rawMode = String(rankingEntriesRenderState.entriesEditorUnmatchedViewMode || 'all');
  const viewMode = rawMode === 'cluster' || rawMode === 'rank' || rawMode === 'all' ? rawMode : 'all';
  el.innerHTML = `
    <span class="ranking-entry-match-chip">总计 ${escapeHtml(String(stats.total))}</span>
    <span class="ranking-entry-match-chip ok">匹配成功 ${escapeHtml(String(stats.matched))}</span>
    <span class="ranking-entry-match-chip miss">匹配失败 ${escapeHtml(String(stats.unmatched))}</span>
    <div class="ranking-entry-unmatched-view-toggle">
      <button class="ranking-entry-view-btn ${viewMode === 'all' ? 'active' : ''}" type="button" onclick="setRankingUnmatchedViewMode('all')" ${rankingEntriesRenderState.entriesEditorSaving ? 'disabled' : ''}>完整榜单</button>
      <button class="ranking-entry-view-btn ${viewMode === 'cluster' ? 'active' : ''}" type="button" onclick="setRankingUnmatchedViewMode('cluster')" ${rankingEntriesRenderState.entriesEditorSaving ? 'disabled' : ''}>聚类展示</button>
      <button class="ranking-entry-view-btn ${viewMode === 'rank' ? 'active' : ''}" type="button" onclick="setRankingUnmatchedViewMode('rank')" ${rankingEntriesRenderState.entriesEditorSaving ? 'disabled' : ''}>按Rank</button>
    </div>
  `;
}

function renderRankingEntriesUnmatchedGroup(rows) {
  const wrap = document.getElementById('ranking-entry-unmatched-wrap');
  if (!wrap) return;
  const board = getActiveRankingBoard();
  if (!board || board.entityType !== 'dj') {
    wrap.style.display = 'none';
    wrap.innerHTML = '';
    return;
  }
  const source = Array.isArray(rows) ? rows : [];
  const unmatchedRows = source
    .map((row, idx) => ({ row, idx }))
    .filter((item) => String(item.row?.name || '').trim() && !String(item.row?.entityId || '').trim());
  if (!unmatchedRows.length) {
    wrap.style.display = 'none';
    wrap.innerHTML = '';
    return;
  }
  const rawMode = String(rankingEntriesRenderState.entriesEditorUnmatchedViewMode || 'all');
  const viewMode = rawMode === 'cluster' || rawMode === 'rank' || rawMode === 'all' ? rawMode : 'all';
  if (viewMode === 'all') {
    wrap.style.display = 'none';
    wrap.innerHTML = '';
    return;
  }
  const renderRankList = () => `
    <div class="ranking-entry-unmatched-list">
      ${unmatchedRows.map((item) => `
        <div class="ranking-entry-unmatched-item">
          <div class="ranking-entry-unmatched-name">#${escapeHtml(String(item.row.rank || item.idx + 1))} · ${escapeHtml(String(item.row.name || ''))}</div>
          <div class="ranking-entry-unmatched-actions">
            <button class="ranking-entry-row-autobind" type="button" onclick="autoBindSingleRankingEntryRow(${item.idx})" ${rankingEntriesRenderState.entriesEditorSaving ? 'disabled' : ''}>自动匹配</button>
            <button class="ranking-entry-row-import" type="button" onclick="openRankingEntryImportDJ(${item.idx})" ${rankingEntriesRenderState.entriesEditorSaving ? 'disabled' : ''}>导入DJ</button>
          </div>
        </div>
      `).join('')}
    </div>
  `;
  const renderClusterList = () => {
    const groupMap = new Map();
    for (const item of unmatchedRows) {
      const key = normalizeRankingEntitySearchKey(item?.row?.name || '') || String(item.row?.name || '').trim().toLowerCase();
      if (!groupMap.has(key)) {
        groupMap.set(key, {
          key,
          name: String(item.row?.name || '').trim(),
          items: [],
        });
      }
      groupMap.get(key).items.push(item);
    }
    const groups = Array.from(groupMap.values()).sort((lhs, rhs) => {
      const leftRank = Number(lhs?.items?.[0]?.row?.rank || 0) || 0;
      const rightRank = Number(rhs?.items?.[0]?.row?.rank || 0) || 0;
      return leftRank - rightRank;
    });
    return `
      <div class="ranking-entry-unmatched-list">
        ${groups.map((group) => `
          <div class="ranking-entry-unmatched-group">
            <div class="ranking-entry-unmatched-group-head">${escapeHtml(group.name || '未命名')} · ${escapeHtml(String(group.items.length))} 条</div>
            <div class="ranking-entry-unmatched-group-list">
              ${group.items.map((item) => `
                <div class="ranking-entry-unmatched-item">
                  <div class="ranking-entry-unmatched-name">#${escapeHtml(String(item.row.rank || item.idx + 1))} · ${escapeHtml(String(item.row.name || ''))}</div>
                  <div class="ranking-entry-unmatched-actions">
                    <button class="ranking-entry-row-autobind" type="button" onclick="autoBindSingleRankingEntryRow(${item.idx})" ${rankingEntriesRenderState.entriesEditorSaving ? 'disabled' : ''}>自动匹配</button>
                    <button class="ranking-entry-row-import" type="button" onclick="openRankingEntryImportDJ(${item.idx})" ${rankingEntriesRenderState.entriesEditorSaving ? 'disabled' : ''}>导入DJ</button>
                  </div>
                </div>
              `).join('')}
            </div>
          </div>
        `).join('')}
      </div>
    `;
  };
  wrap.style.display = '';
  wrap.innerHTML = `
    <div class="ranking-entry-unmatched-head">
      <div class="ranking-entry-unmatched-head-left">
        <span>未匹配 DJ 集中处理（${escapeHtml(String(unmatchedRows.length))}）</span>
      </div>
    </div>
    ${viewMode === 'cluster' ? renderClusterList() : renderRankList()}
  `;
}

function setRankingUnmatchedViewMode(mode) {
  const raw = String(mode || '').trim().toLowerCase();
  const next = raw === 'cluster' || raw === 'rank' ? raw : 'all';
  rankingEntriesRenderState.entriesEditorUnmatchedViewMode = next;
  const rows = normalizeRankingEntriesEditorRows(rankingEntriesRenderState.entriesEditorRows);
  rankingEntriesRenderState.entriesEditorRows = rows;
  renderRankingEntriesEditorSummary(rows);
  renderRankingEntriesUnmatchedGroup(rows);
}

function renderRankingEntriesEditorRows() {
  const tbody = document.getElementById('ranking-entries-editor-tbody');
  if (!tbody) return;
  const rows = normalizeRankingEntriesEditorRows(rankingEntriesRenderState.entriesEditorRows);
  rankingEntriesRenderState.entriesEditorRows = rows;
  renderRankingEntriesEditorSummary(rows);
  renderRankingEntriesUnmatchedGroup(rows);
  const catalog = Array.isArray(rankingEntriesRenderState.entriesEditorCatalog) ? rankingEntriesRenderState.entriesEditorCatalog : [];
  const disabled = !!rankingEntriesRenderState.entriesEditorSaving;
  if (!rows.length) {
    tbody.innerHTML = `<tr><td colspan="5" class="ranking-empty">暂无位次，点击“新增一行”或“文本导入”。</td></tr>`;
    return;
  }
  tbody.innerHTML = rows.map((row, idx) => {
    const entityDisplay = rankingEntityDisplayById(row.entityId, catalog);
    const bound = !!String(row.entityId || '').trim();
    const statusHtml = bound
      ? '<span class="ranking-entry-bind-status ok">已匹配</span>'
      : '<span class="ranking-entry-bind-status miss">未匹配</span>';
    const board = getActiveRankingBoard();
    const isDJBoard = board?.entityType === 'dj';
    return `
      <tr>
        <td><input data-rank-row="${idx}" type="number" min="1" step="1" value="${escapeHtml(String(row.rank || idx + 1))}" ${disabled ? 'disabled' : ''}></td>
        <td><input data-name-row="${idx}" type="text" value="${escapeHtml(row.name || '')}" placeholder="榜单名称" ${disabled ? 'disabled' : ''}></td>
        <td><input data-entity-row="${idx}" type="text" list="ranking-entity-datalist" value="${escapeHtml(entityDisplay)}" placeholder="输入名称或选择 Name | ID" onfocus="onRankingEntityInputFocus(${idx}, this.value)" oninput="onRankingEntityInputChanged(${idx}, this.value)" ${disabled ? 'disabled' : ''}></td>
        <td>${statusHtml}</td>
        <td>
          <button class="ranking-entry-row-autobind" type="button" onclick="autoBindSingleRankingEntryRow(${idx})" ${disabled ? 'disabled' : ''}>自动匹配</button>
          ${(!bound && isDJBoard) ? `<button class="ranking-entry-row-import" type="button" onclick="openRankingEntryImportDJ(${idx})" ${disabled ? 'disabled' : ''}>导入DJ</button>` : ''}
          <button class="ranking-entry-row-insert" type="button" onclick="insertRankingEntryRowAfter(${idx})" ${disabled ? 'disabled' : ''}>下方插入</button>
          <button class="ranking-entry-row-remove" type="button" onclick="removeRankingEntryRow(${idx})" ${disabled ? 'disabled' : ''}>删除</button>
        </td>
      </tr>
    `;
  }).join('');
}
