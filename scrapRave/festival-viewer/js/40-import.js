// ── FESTTIMETABLE IMPORT ──
function initImportPanel() {
  const panel = document.getElementById('import-bar');
  if (!panel || panel.dataset.bound === '1') return;
  panel.dataset.bound = '1';

  document.getElementById('import-search-btn').onclick = () => searchImportEvents();
  document.getElementById('import-select-all-btn').onclick = () => toggleImportSelectAll();
  document.getElementById('import-run-btn').onclick = () => runImportSelected();
  document.getElementById('tt-dj-prefetch-btn').onclick = () => ttToggleDJSourcePrefetch();
  document.getElementById('import-results').addEventListener('change', (e) => {
    if (e.target && e.target.matches('input[data-import-idx]')) updateImportSelectAllButton();
  });
  updateImportSelectAllButton();
  ttSetDJPrefetchStatus('DJ 候选缓存任务：未开始');
  ttSyncDJPrefetchButton();
}

function setImportStatus(text, isError = false) {
  const el = document.getElementById('import-status');
  if (!el) return;
  el.textContent = text || '';
  el.style.color = isError ? 'var(--accent2)' : 'var(--text-dim)';
}

function ttSetDJPrefetchStatus(text, kind = '') {
  const el = document.getElementById('tt-dj-prefetch-status');
  if (!el) return;
  el.textContent = String(text || '');
  el.classList.remove('ok', 'err');
  if (kind === 'ok') el.classList.add('ok');
  if (kind === 'err') el.classList.add('err');
}

function ttSyncDJPrefetchButton() {
  const btn = document.getElementById('tt-dj-prefetch-btn');
  if (!btn) return;
  btn.textContent = ttDJSourceCacheState.running ? '停止预抓取' : '预抓取未绑定DJ候选';
  btn.classList.toggle('primary', !!ttDJSourceCacheState.running);
}

function updateImportSelectAllButton() {
  const btn = document.getElementById('import-select-all-btn');
  if (!btn) return;
  const checks = [...document.querySelectorAll('#import-results input[data-import-idx]')];
  if (!checks.length) {
    btn.textContent = '全选';
    btn.disabled = true;
    return;
  }
  btn.disabled = false;
  const allChecked = checks.every(c => c.checked);
  btn.textContent = allChecked ? '取消全选' : '全选';
}

function toggleImportSelectAll() {
  const checks = [...document.querySelectorAll('#import-results input[data-import-idx]')];
  if (!checks.length) return;
  const allChecked = checks.every(c => c.checked);
  checks.forEach(c => { c.checked = !allChecked; });
  updateImportSelectAllButton();
}

