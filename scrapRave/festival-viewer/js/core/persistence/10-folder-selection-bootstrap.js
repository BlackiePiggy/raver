function updateCurrentFolderPath(name = '', remembered = false) {
  const el = document.getElementById('current-folder-path');
  if (!el) return;
  const n = String(name || '').trim();
  if (!n) {
    el.textContent = '当前目录：未选择';
    return;
  }
  el.textContent = remembered ? `当前目录：${n}（已记住）` : `当前目录：${n}`;
}

function resetUnselectedState() {
  allData = {};
  activeYear = null;
  archiveYearMeta = [];
  archiveYearLoadState = {};
  if (archiveLazyObserver) {
    archiveLazyObserver.disconnect();
    archiveLazyObserver = null;
  }
  archiveLazyLoading = false;
  activeMonths = new Set();
  searchQuery = '';
  globalSearchQuery = '';
  activeCountryFilterKeys = new Set();
  activeEventTypeFilterKeys = new Set();
  document.getElementById('pick-zone').style.display = 'block';
  document.getElementById('loading').style.display = 'none';
  document.getElementById('year-nav').style.display = 'none';
  document.getElementById('filter-bar').style.display = 'none';
  document.getElementById('import-bar').style.display = 'none';
  document.getElementById('main').innerHTML = '';
  const searchEl = document.getElementById('search-input');
  if (searchEl) searchEl.value = '';
  const globalSearchEl = document.getElementById('global-search-input');
  if (globalSearchEl) globalSearchEl.value = '';
  setArchiveHeaderCounter();
  applyAppPageVisibility();
}

async function loadFromRootHandle(rootHandle, options = {}) {
  const remember = options.remember !== false;
  const rememberedLabel = !!options.rememberedLabel;
  rootDirHandle = rootHandle;
  if (remember) {
    try { await saveRememberedRootHandle(rootHandle); } catch (e) { console.warn('保存目录句柄失败', e); }
  }
  updateCurrentFolderPath(rootHandle?.name || '', rememberedLabel);

  try {
    await loadArchiveEventsFromBackend({
      preserveView: !!options.preserveView,
      prevView: options.prevView || null,
      detail: '正在读取后端活动数据并同步本地图片缓存...',
    });
  } catch (e) {
    console.error(e);
    alert('读取后端活动失败：' + e.message);
    document.getElementById('loading').style.display = 'none';
    document.getElementById('pick-zone').style.display = 'block';
    return false;
  }

  const total = countTotalFestivals();
  if (total === 0) {
    const st = document.getElementById('import-status');
    if (st) st.textContent = '当前后端 events 暂无电音节数据。';
  }
  return true;
}

async function pickFolder() {
  if (!('showDirectoryPicker' in window)) {
    alert('您的浏览器不支持 File System Access API。\n请使用 Chrome 或 Edge 浏览器打开此页面。');
    return;
  }
  let rootHandle;
  try {
    rootHandle = await window.showDirectoryPicker({ mode: 'readwrite' });
  } catch (e) { return; }
  await loadFromRootHandle(rootHandle, { remember: true, rememberedLabel: false });
}

async function clearRememberedFolder() {
  try {
    await clearRememberedRootHandle();
  } catch (e) {
    console.warn('清除目录记忆失败', e);
  }
  rootDirHandle = null;
  updateCurrentFolderPath('');
  resetUnselectedState();
}

async function bootstrapFolderSelection() {
  updateCurrentFolderPath('');
  if (!supportsFolderPersistence()) return;
  try {
    const { handle, meta } = await loadRememberedRootHandle();
    if (!handle) return;
    const rememberedName = String(meta?.name || handle?.name || '').trim();
    updateCurrentFolderPath(rememberedName || handle.name || '', true);
    let granted = await ensureDirPermission(handle, true, false);
    if (!granted) granted = await ensureDirPermission(handle, true, true);
    if (!granted) return;
    await loadFromRootHandle(handle, { remember: false, rememberedLabel: true });
  } catch (e) {
    console.warn('恢复上次目录失败', e);
  }
}
