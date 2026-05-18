// Feature module extracted from monolith (import runtime)
const importRuntimeState = (function resolveImportRuntimeState() {
  const facade = window.ImportStateFacade;
  if (facade && typeof facade.runtimeState === 'function') return facade.runtimeState();
  return {
    get searchResults() {
      return importSearchResults;
    },
    set searchResults(value) {
      importSearchResults = Array.isArray(value) ? value : [];
    },
    get jobId() {
      return importJobId;
    },
    set jobId(value) {
      importJobId = value ? String(value) : null;
    },
    get pollTimer() {
      return importPollTimer;
    },
    set pollTimer(value) {
      importPollTimer = value || null;
    },
    get progressSince() {
      return importProgressSince;
    },
    set progressSince(value) {
      importProgressSince = Number(value) || 0;
    },
    get liveImportedKeys() {
      return importLiveImportedKeys;
    },
    set liveImportedKeys(value) {
      importLiveImportedKeys = value instanceof Set ? value : new Set();
    },
    get liveQueue() {
      return importLiveQueue;
    },
    set liveQueue(value) {
      importLiveQueue = Array.isArray(value) ? value : [];
    },
    get liveImporting() {
      return importLiveImporting;
    },
    set liveImporting(value) {
      importLiveImporting = !!value;
    },
    get liveInRunIndex() {
      return importLiveInRunIndex;
    },
    set liveInRunIndex(value) {
      importLiveInRunIndex = value instanceof Map ? value : new Map();
    },
    get liveWrittenCount() {
      return importLiveWrittenCount;
    },
    set liveWrittenCount(value) {
      importLiveWrittenCount = Number(value) || 0;
    },
    get liveSkippedCount() {
      return importLiveSkippedCount;
    },
    set liveSkippedCount(value) {
      importLiveSkippedCount = Number(value) || 0;
    },
    get livePhotoCount() {
      return importLivePhotoCount;
    },
    set livePhotoCount(value) {
      importLivePhotoCount = Number(value) || 0;
    },
    get livePhotoFailedCount() {
      return importLivePhotoFailedCount;
    },
    set livePhotoFailedCount(value) {
      importLivePhotoFailedCount = Number(value) || 0;
    },
    get persistStatusByKey() {
      return importPersistStatusByKey;
    },
    set persistStatusByKey(value) {
      importPersistStatusByKey = value instanceof Map ? value : new Map();
    },
    get photoFailureDetails() {
      return importPhotoFailureDetails;
    },
    set photoFailureDetails(value) {
      importPhotoFailureDetails = Array.isArray(value) ? value : [];
    },
    get lastProgress() {
      return importLastProgress;
    },
    set lastProgress(value) {
      importLastProgress = value || null;
    },
  };
})();

function renderImportResults() {
  const box = document.getElementById('import-results');
  if (!box) return;
  box.innerHTML = '';

  if (!importRuntimeState.searchResults.length) {
    box.innerHTML = '<div class="import-progress-item">未检索到可导入活动</div>';
    updateImportSelectAllButton();
    return;
  }

  importRuntimeState.searchResults.forEach((evt, idx) => {
    const row = document.createElement('label');
    row.className = 'import-item';
    row.innerHTML = `
      <input type="checkbox" data-import-idx="${idx}">
      <div>
        <div class="t">${escapeHtml(evt.label || evt.slug || 'Unknown Event')}</div>
        <div class="u">${escapeHtml(evt.url || '')}</div>
      </div>
    `;
    box.appendChild(row);
  });
  updateImportSelectAllButton();
}

function selectedImportUrls() {
  const checks = [...document.querySelectorAll('#import-results input[type="checkbox"]:checked')];
  return checks
    .map(c => Number(c.dataset.importIdx))
    .filter(n => Number.isInteger(n) && importRuntimeState.searchResults[n])
    .map(n => importRuntimeState.searchResults[n].url)
    .filter(Boolean);
}

function collectExistingFestivalIds() {
  const ids = new Set();
  for (const yearData of Object.values(allData || {})) {
    for (const list of Object.values(yearData || {})) {
      for (const fest of (Array.isArray(list) ? list : [])) {
        const info = fest?.info || {};
        let id = String(info.festivalId || '').trim();
        if (!id) {
          const nameBi = normalizeBiTextValue(info.nameI18n ?? info.name ?? fest?.name ?? '', String(info.name || fest?.name || '').trim());
          const countryBi = normalizeBiTextValue(info.countryI18n ?? info.country ?? '', String(info.country || '').trim());
          const name = String(nameBi.en || nameBi.zh || '').trim();
          const startDate = String(info.startDate || '').trim();
          const country = String(countryBi.en || countryBi.zh || '').trim();
          id = buildFestivalId(startDate, name, country);
        }
        if (id) ids.add(id);
      }
    }
  }
  return [...ids];
}

function stopImportPolling() {
  if (importRuntimeState.pollTimer) {
    clearInterval(importRuntimeState.pollTimer);
    importRuntimeState.pollTimer = null;
  }
}

function getImportEventKey(event) {
  return String(
    event?.event_url ||
    event?.eventUrl ||
    event?.source?.eventUrl ||
    event?.festivalId ||
    event?.slug ||
    event?.title ||
    ''
  ).trim().toLowerCase();
}

function setImportPersistStatus(eventLike, status, message = '') {
  const key = getImportEventKey(eventLike);
  if (!key) return;
  importRuntimeState.persistStatusByKey.set(key, { status, message, at: Date.now() });
}

function textForPersistStatus(scrapeStatus, persistStatus) {
  if (persistStatus?.status === 'saved') return `入库：已写入${persistStatus.message ? `（${persistStatus.message}）` : ''}`;
  if (persistStatus?.status === 'skipped') return `入库：已跳过${persistStatus.message ? `（${persistStatus.message}）` : ''}`;
  if (persistStatus?.status === 'failed') return `入库：失败${persistStatus.message ? `（${persistStatus.message}）` : ''}`;
  if (persistStatus?.status === 'writing') return '入库：进行中';
  if (scrapeStatus === 'skipped') return '入库：后端预检查已跳过（slug 重复）';
  return '入库：等待处理';
}

function appendPhotoFailureDetails(eventLike, failures) {
  if (!Array.isArray(failures) || !failures.length) return;
  const eventName = String(eventLike?.title || eventLike?.name || eventLike?.slug || eventLike?.event_url || '').trim();
  const festivalId = String(eventLike?.festivalId || eventLike?.festival_id || '').trim();
  const eventUrl = String(eventLike?.event_url || eventLike?.eventUrl || '').trim();
  for (const f of failures) {
    importRuntimeState.photoFailureDetails.push({
      eventName,
      festivalId,
      eventUrl,
      label: String(f?.label || f?.alt || '').trim(),
      imageUrl: String(f?.image_url || f?.url || '').trim(),
      error: String(f?.error || '').trim(),
    });
  }
}

function renderPhotoFailureSection(box) {
  const total = importRuntimeState.photoFailureDetails.length;
  if (!total) return;

  const head = document.createElement('div');
  head.className = 'import-progress-total';
  head.textContent = `图片下载失败明细：${total} 条`;
  box.appendChild(head);

  const max = 120;
  const list = total > max ? importRuntimeState.photoFailureDetails.slice(0, max) : importRuntimeState.photoFailureDetails;
  list.forEach((it, idx) => {
    const line = document.createElement('div');
    line.className = 'import-progress-item';
    line.innerHTML = `
      <div>#${idx + 1} ${escapeHtml(it.eventName || it.festivalId || it.eventUrl || '-')}</div>
      <div>label：${escapeHtml(it.label || '-')}</div>
      <div>url：${escapeHtml(it.imageUrl || '-')}</div>
      <div>错误：${escapeHtml(it.error || '下载失败')}</div>
    `;
    box.appendChild(line);
  });
  if (total > max) {
    const tail = document.createElement('div');
    tail.className = 'import-progress-item';
    tail.textContent = `仅展示前 ${max} 条，剩余 ${total - max} 条未展开。`;
    box.appendChild(tail);
  }
}

function queueLiveImportedEvents(events) {
  if (!Array.isArray(events) || !events.length) return;
  for (const event of events) {
    const key = getImportEventKey(event);
    if (!key) continue;
    if (importRuntimeState.liveImportedKeys.has(key)) continue;
    if (importRuntimeState.liveQueue.some(x => getImportEventKey(x) === key)) continue;
    importRuntimeState.liveQueue.push(event);
  }
  void processLiveImportQueue();
}

async function processLiveImportQueue() {
  if (importRuntimeState.liveImporting) return;
  importRuntimeState.liveImporting = true;
  try {
    while (importRuntimeState.liveQueue.length) {
      const event = importRuntimeState.liveQueue.shift();
      const key = getImportEventKey(event);
      if (!key || importRuntimeState.liveImportedKeys.has(key)) continue;
      setImportPersistStatus(event, 'writing', '');
      let res;
      try {
        res = await writeImportedFestival(event, importRuntimeState.liveInRunIndex);
      } catch (err) {
        setImportPersistStatus(event, 'failed', err?.message || '未知错误');
        setImportStatus(`实时入库失败：${err?.message || '未知错误'}`, true);
        continue;
      }
      importRuntimeState.liveImportedKeys.add(key);
      if (res.skipped) {
        importRuntimeState.liveSkippedCount += 1;
        setImportPersistStatus(event, 'skipped', res.festivalId || 'slug 重复');
        setImportStatus(`实时入库中：已写入 ${importRuntimeState.liveWrittenCount}，重复 slug 跳过 ${importRuntimeState.liveSkippedCount}（最新跳过：${res.festivalId || res.name || key}）`);
        renderImportProgress(importRuntimeState.lastProgress);
        continue;
      }
      importRuntimeState.liveWrittenCount += 1;
      importRuntimeState.livePhotoCount += Number(res.photosSaved || 0);
      importRuntimeState.livePhotoFailedCount += Number(res.photosFailed || 0);
      appendPhotoFailureDetails(event, res.photoFailures || []);
      const photoFailMsg = Number(res.photosFailed || 0) > 0 ? `图片失败 ${res.photosFailed} 张` : (res.folder || '');
      setImportPersistStatus(event, 'saved', photoFailMsg);
      await rebuildLibraryIndex('实时写入新活动...', { preserveView: true });
      setImportStatus(`实时入库中：已写入 ${importRuntimeState.liveWrittenCount}，重复 slug 跳过 ${importRuntimeState.liveSkippedCount}（最新：${res.name || key}）`);
      renderImportProgress(importRuntimeState.lastProgress);
    }
  } catch (e) {
    setImportStatus(`实时入库失败：${e.message}`, true);
  } finally {
    importRuntimeState.liveImporting = false;
  }
}

async function waitForLiveImportQueue() {
  let guard = 0;
  while (importRuntimeState.liveImporting || importRuntimeState.liveQueue.length) {
    await new Promise(r => setTimeout(r, 120));
    guard += 1;
    if (guard > 600) break;
  }
}

async function searchImportEvents() {
  if (!rootDirHandle) {
    setImportStatus('请先选择 brands 文件夹。', true);
    return;
  }
  const keyword = (document.getElementById('import-keyword').value || '').trim();
  const locale = (document.getElementById('import-locale').value || 'en-GB').trim();
  if (!keyword) {
    setImportStatus('请输入关键词，例如 tomorrowland。', true);
    return;
  }

  setImportStatus('正在搜索活动...');
  try {
    const data = await apiPost('/api/search', { keyword, locale });
    importRuntimeState.searchResults = data.events || [];
    renderImportResults();
    setImportStatus(`搜索完成：${importRuntimeState.searchResults.length} 个活动`);
  } catch (e) {
    importRuntimeState.searchResults = [];
    renderImportResults();
    setImportStatus(`搜索失败：${e.message}（请确认本地爬虫服务已启动）`, true);
  }
}

function renderImportProgress(progress) {
  const box = document.getElementById('import-progress');
  if (!box) return;
  importRuntimeState.lastProgress = progress || null;
  box.innerHTML = '';
  if (!progress) {
    renderPhotoFailureSection(box);
    return;
  }

  const total = document.createElement('div');
  total.className = 'import-progress-total';
  total.textContent = `总进度：${progress.completed_events || 0}/${progress.total_events || 0}，跳过：${progress.skipped_events || 0}，状态：${progress.status || '-'}`;
  box.appendChild(total);

  (progress.events || []).forEach((e) => {
    const persist = importRuntimeState.persistStatusByKey.get(getImportEventKey({ url: e.url, event_url: e.url, slug: e.slug, title: e.title }));
    const line = document.createElement('div');
    line.className = 'import-progress-item';
    line.innerHTML = `
      <div>${escapeHtml(e.title || e.slug || e.url || '')}</div>
      <div>状态：${escapeHtml(e.status || '-')} | timetable：${Number(e.completed_timetables || 0)}/${Number(e.total_timetables || 0)}</div>
      <div>${escapeHtml(e.message || '')}</div>
      <div>${escapeHtml(textForPersistStatus(e.status, persist))}</div>
    `;
    box.appendChild(line);
  });
  renderPhotoFailureSection(box);
}

async function runImportSelected() {
  if (!rootDirHandle) {
    setImportStatus('请先选择 brands 文件夹。', true);
    return;
  }
  const urls = selectedImportUrls();
  if (!urls.length) {
    setImportStatus('请先勾选至少一个活动。', true);
    return;
  }

  stopImportPolling();
  importRuntimeState.progressSince = 0;
  importRuntimeState.liveImportedKeys = new Set();
  importRuntimeState.liveQueue = [];
  importRuntimeState.liveImporting = false;
  importRuntimeState.liveInRunIndex = new Map();
  importRuntimeState.liveWrittenCount = 0;
  importRuntimeState.liveSkippedCount = 0;
  importRuntimeState.livePhotoCount = 0;
  importRuntimeState.livePhotoFailedCount = 0;
  importRuntimeState.persistStatusByKey = new Map();
  importRuntimeState.photoFailureDetails = [];
  importRuntimeState.lastProgress = null;
  const existingIds = collectExistingFestivalIds();
  renderImportProgress(null);
  setImportStatus(`准备抓取 ${urls.length} 个活动（库内 slug 基线 ${existingIds.length}）...`);

  try {
    const started = await apiPost('/api/scrape/start', { event_urls: urls, skip_festival_ids: existingIds });
    importRuntimeState.jobId = started.job_id;
    setImportStatus(`抓取任务已创建：${importRuntimeState.jobId}`);
  } catch (e) {
    setImportStatus(`启动抓取失败：${e.message}`, true);
    return;
  }

  importRuntimeState.pollTimer = setInterval(async () => {
    if (!importRuntimeState.jobId) return;
    try {
      const data = await apiGet(`/api/scrape/progress?job_id=${encodeURIComponent(importRuntimeState.jobId)}&since=${encodeURIComponent(importRuntimeState.progressSince)}`);
      const progress = data.progress || {};
      const nextSince = Number(data.next_since || importRuntimeState.progressSince);
      const newEvents = Array.isArray(data.new_events) ? data.new_events : [];
      importRuntimeState.progressSince = Number.isFinite(nextSince) ? nextSince : importRuntimeState.progressSince;
      renderImportProgress(progress);
      if (newEvents.length) queueLiveImportedEvents(newEvents);

      if (progress.status === 'completed') {
        stopImportPolling();
        await waitForLiveImportQueue();
        const resultResp = await apiGet(`/api/scrape/result?job_id=${encodeURIComponent(importRuntimeState.jobId)}`);
        const result = resultResp.result || { events: [] };
        const backendSkipped = Array.isArray(result.skipped) ? result.skipped : [];
        backendSkipped.forEach((x) => {
          setImportPersistStatus(
            { event_url: x.event_url, title: x.title },
            'skipped',
            x.festival_id || 'slug 重复'
          );
        });
        renderImportProgress(progress);
        const events = Array.isArray(result.events) ? result.events : [];
        const remained = events.filter(e => {
          const key = getImportEventKey(e);
          return !key || !importRuntimeState.liveImportedKeys.has(key);
        });
        await importScrapedEventsToLibrary(remained, { preserveView: true, serverSkippedCount: backendSkipped.length });
        importRuntimeState.jobId = null;
      } else if (progress.status === 'failed') {
        stopImportPolling();
        setImportStatus(`抓取任务失败：${progress.fatal_error || '未知错误'}`, true);
        importRuntimeState.jobId = null;
      }
    } catch (e) {
      stopImportPolling();
      setImportStatus(`进度查询失败：${e.message}`, true);
      importRuntimeState.jobId = null;
    }
  }, 1000);
}
