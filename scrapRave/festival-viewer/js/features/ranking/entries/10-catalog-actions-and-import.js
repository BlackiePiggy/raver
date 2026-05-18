// Ranking entries: catalog sync, row actions, auto-bind, and text import workflow.
const rankingEntriesActionState = (typeof getRankingState === 'function')
  ? getRankingState()
  : rankingPageState;

function upsertRankingEntriesEditorCatalogWithDJ(dj) {
  const id = String(dj?.id || '').trim();
  const name = String(dj?.name || '').trim();
  if (!id || !name) return;
  const aliases = Array.isArray(dj?.aliases)
    ? dj.aliases.map((item) => String(item || '').trim()).filter(Boolean)
    : [];
  const rows = Array.isArray(rankingEntriesActionState.entriesEditorCatalog) ? [...rankingEntriesActionState.entriesEditorCatalog] : [];
  const idx = rows.findIndex((item) => String(item?.id || '') === id);
  const nextItem = { id, name, aliases };
  if (idx >= 0) rows[idx] = nextItem;
  else rows.push(nextItem);
  rankingEntriesActionState.entriesEditorCatalog = rows
    .filter((item) => String(item?.id || '').trim() && String(item?.name || '').trim())
    .sort((a, b) => String(a.name || '').localeCompare(String(b.name || ''), 'en', { sensitivity: 'base' }));
  refreshRankingEntityDatalist(rankingEntriesActionState.entriesEditorCatalog);
}

async function openRankingEntryImportDJ(index) {
  if (rankingEntriesActionState.entriesEditorSaving) return;
  const board = getActiveRankingBoard();
  if (!board || board.entityType !== 'dj') return;
  const rows = normalizeRankingEntriesEditorRows(rankingEntriesActionState.entriesEditorRows);
  rankingEntriesActionState.entriesEditorRows = rows;
  const row = rows[index];
  if (!row) return;
  const rowRid = String(row._rid || '').trim();
  const preferredName = String(row.name || '').trim();
  await openDJLibraryImportModalWithOptions({
    initialName: preferredName,
    onImported: async (dj) => {
      const targetRows = normalizeRankingEntriesEditorRows(rankingEntriesActionState.entriesEditorRows);
      const targetIndex = targetRows.findIndex((item) => String(item?._rid || '') === rowRid);
      if (targetIndex < 0) return;
      targetRows[targetIndex] = {
        ...targetRows[targetIndex],
        entityId: String(dj?.id || '').trim(),
      };
      rankingEntriesActionState.entriesEditorRows = targetRows;
      upsertRankingEntriesEditorCatalogWithDJ(dj);
      renderRankingEntriesEditorRows();
      const djName = String(dj?.name || '').trim() || String(dj?.id || '').trim() || 'DJ';
      setRankingEntriesEditStatus(`已为 #${targetRows[targetIndex].rank} ${targetRows[targetIndex].name} 导入并绑定 ${djName}。`, 'ok');
    },
  });
}

function appendRankingEntryRow() {
  const rows = Array.isArray(rankingEntriesActionState.entriesEditorRows) ? rankingEntriesActionState.entriesEditorRows : [];
  const nextRank = rows.length ? Math.max(...rows.map((x) => Number(x.rank) || 0)) + 1 : 1;
  rows.push({ rank: nextRank, name: '', entityId: '' });
  rankingEntriesActionState.entriesEditorRows = rows;
  renderRankingEntriesEditorRows();
}

function removeRankingEntryRow(index) {
  if (rankingEntriesActionState.entriesEditorSaving) return;
  const rows = Array.isArray(rankingEntriesActionState.entriesEditorRows) ? rankingEntriesActionState.entriesEditorRows : [];
  rows.splice(index, 1);
  rankingEntriesActionState.entriesEditorRows = rows;
  renderRankingEntriesEditorRows();
}

function autoBindSingleRankingEntryRow(index) {
  if (rankingEntriesActionState.entriesEditorSaving) return;
  const rows = Array.isArray(rankingEntriesActionState.entriesEditorRows) ? rankingEntriesActionState.entriesEditorRows : [];
  const row = rows[index];
  if (!row) return;
  const catalog = Array.isArray(rankingEntriesActionState.entriesEditorCatalog) ? rankingEntriesActionState.entriesEditorCatalog : [];
  const result = autoBindRankingRowsByName([row], catalog);
  rows[index] = result.rows[0] || row;
  rankingEntriesActionState.entriesEditorRows = rows;
  renderRankingEntriesEditorRows();
}

function autoBindAllRankingEntryRows() {
  if (rankingEntriesActionState.entriesEditorSaving) return;
  const rows = Array.isArray(rankingEntriesActionState.entriesEditorRows) ? rankingEntriesActionState.entriesEditorRows : [];
  const catalog = Array.isArray(rankingEntriesActionState.entriesEditorCatalog) ? rankingEntriesActionState.entriesEditorCatalog : [];
  const result = autoBindRankingRowsByName(rows, catalog);
  rankingEntriesActionState.entriesEditorRows = result.rows;
  renderRankingEntriesEditorRows();
  setRankingEntriesEditStatus(`自动匹配完成：已匹配 ${result.matched} 条，未匹配 ${result.unmatched} 条。请确认后保存。`, result.unmatched > 0 ? 'err' : 'ok');
}

function insertRankingEntryRowAfter(index) {
  if (rankingEntriesActionState.entriesEditorSaving) return;
  const rows = normalizeRankingEntriesEditorRows(rankingEntriesActionState.entriesEditorRows);
  if (!rows.length) {
    appendRankingEntryRow();
    return;
  }
  const safeIndex = Math.max(0, Math.min(rows.length - 1, Number(index) || 0));
  const baseRank = Number(rows[safeIndex]?.rank || safeIndex + 1);
  const insertRank = Number.isFinite(baseRank) && baseRank > 0 ? baseRank + 1 : safeIndex + 2;

  const shifted = rows.map((row, idx) => {
    if (idx <= safeIndex) return { ...row };
    const rank = Number(row.rank);
    return {
      ...row,
      rank: Number.isFinite(rank) ? rank + 1 : (insertRank + (idx - safeIndex)),
    };
  });

  shifted.splice(safeIndex + 1, 0, {
    rank: insertRank,
    name: '',
    entityId: '',
  });
  rankingEntriesActionState.entriesEditorRows = shifted;
  renderRankingEntriesEditorRows();
}

function applyRankingImportText() {
  const text = String(document.getElementById('ranking-entries-import-text')?.value || '').trim();
  if (!text) {
    setRankingEntriesEditStatus('请先粘贴导入文本', 'err');
    return;
  }
  const parsed = text
    .split(/\r?\n/g)
    .map((line) => String(line || '').trim())
    .filter(Boolean);
  const invalidLines = parsed.filter((line) => !/^(\d+)\.\s+(.+)$/.test(line));
  if (invalidLines.length > 0) {
    setRankingEntriesEditStatus(`导入格式错误：每行必须是“位次. 空格 名称”，例如“1. Martin Garrix”。`, 'err');
    return;
  }
  const parsedRows = parsed
    .map((line) => {
      const m = line.match(/^(\d+)\.\s+(.+)$/);
      if (!m) return null;
      return { rank: Number(m[1]), name: String(m[2] || '').trim(), entityId: '' };
    })
    .filter((row) => !!row && Number.isFinite(row.rank) && row.rank > 0 && row.name);
  const catalog = Array.isArray(rankingEntriesActionState.entriesEditorCatalog) ? rankingEntriesActionState.entriesEditorCatalog : [];
  const autoBound = autoBindRankingRowsByName(parsedRows, catalog);
  rankingEntriesActionState.entriesEditorRows = autoBound.rows;
  renderRankingEntriesEditorRows();
  setRankingEntriesEditStatus(
    `已导入 ${parsedRows.length} 条位次，自动匹配成功 ${autoBound.matched} 条，未匹配 ${autoBound.unmatched} 条。请确认后保存。`,
    autoBound.unmatched > 0 ? 'err' : 'ok'
  );
}
