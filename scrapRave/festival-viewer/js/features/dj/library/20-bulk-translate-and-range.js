function clearDJBulkLogs() {
  const logsEl = document.getElementById('dj-batch-logs');
  if (logsEl) logsEl.innerHTML = '';
}

function appendDJBulkLog(text, level = 'info') {
  const logsEl = document.getElementById('dj-batch-logs');
  if (!logsEl) return;
  const line = document.createElement('div');
  let cls = 'dj-batch-log-item';
  if (level === 'ok') cls += ' ok';
  else if (level === 'err') cls += ' err';
  else if (level === 'warn') cls += ' warn';
  line.className = cls;
  const now = new Date();
  const hh = String(now.getHours()).padStart(2, '0');
  const mm = String(now.getMinutes()).padStart(2, '0');
  const ss = String(now.getSeconds()).padStart(2, '0');
  line.textContent = `[${hh}:${mm}:${ss}] ${String(text || '')}`;
  logsEl.appendChild(line);
  logsEl.scrollTop = logsEl.scrollHeight;
}

function maybeAppendDJBulkProgressLog(progress = null) {
  if (!progress || typeof progress !== 'object') return;
  const rawStatus = String(progress?.job_status || progress?.status || '').trim().toLowerCase();
  if (!rawStatus || ['completed', 'stopped', 'failed'].includes(rawStatus)) return;

  const total = Math.max(0, Number(progress?.total || 0));
  const processed = Math.max(0, Number(progress?.processed || 0));
  const currentIndex = Math.max(0, Number(progress?.current_index || 0));
  const currentName = String(progress?.current_dj_name || '').trim();
  const currentId = String(progress?.current_dj_id || '').trim();
  const message = String(progress?.message || '').trim();
  const currentLabel = currentName || currentId || '-';
  const statusText = rawStatus === 'stopping' ? '停止中' : '处理中';
  const logText = `${statusText} ${processed}/${total || '—'} · 当前 ${currentIndex || '—'}/${total || '—'} · ${currentLabel}${message ? ` · ${message}` : ''}`;
  const logKey = [
    rawStatus,
    processed,
    total,
    currentIndex,
    currentLabel,
    message,
  ].join('|');

  if (djBilingualJobState.lastProgressLogKey === logKey) return;
  djBilingualJobState.lastProgressLogKey = logKey;
  djBilingualJobState.lastProgressLogAt = Date.now();
  appendDJBulkLog(logText, rawStatus === 'stopping' ? 'warn' : 'info');
}

function updateDJBulkProgressUI(progress = null) {
  const summaryEl = document.getElementById('dj-batch-summary');
  const barFillEl = document.getElementById('dj-batch-bar-fill');
  if (!summaryEl || !barFillEl) return;

  const total = Number(progress?.total || 0);
  const processed = Number(progress?.processed || 0);
  const updated = Number(progress?.updated || 0);
  const failed = Number(progress?.failed || 0);
  const skipped = Number(progress?.skipped || 0);
  const status = String(progress?.status || (djLibraryState.translating ? 'running' : 'idle'));

  const ratio = total > 0 ? Math.min(1, Math.max(0, processed / total)) : 0;
  barFillEl.style.width = `${Math.round(ratio * 1000) / 10}%`;
  summaryEl.textContent = `状态 ${status} · 进度 ${processed}/${total || '—'} · 成功 ${updated} · 失败 ${failed} · 跳过 ${skipped}`;
}

function finishDJBulkJobAndReselect(rows) {
  const updatedIds = new Set();
  const unsuccessIds = new Set();
  const processedIds = new Set();
  const initialIds = Array.isArray(djBilingualJobState.initialSelectedIds) ? djBilingualJobState.initialSelectedIds : [];
  for (const row of (Array.isArray(rows) ? rows : [])) {
    const id = normalizeDJLibraryId(row?.djId);
    if (!id) continue;
    processedIds.add(id);
    const status = String(row?.status || '');
    if (status === 'updated') updatedIds.add(id);
    else unsuccessIds.add(id);
  }
  for (const id of initialIds) {
    const normalized = normalizeDJLibraryId(id);
    if (!normalized) continue;
    if (!processedIds.has(normalized)) {
      unsuccessIds.add(normalized);
    }
  }
  djLibraryState.selectedIds = unsuccessIds;
}

function stopDJBulkPolling() {
  if (djBilingualJobState.pollTimer) {
    clearInterval(djBilingualJobState.pollTimer);
    djBilingualJobState.pollTimer = null;
  }
  djBilingualJobState.polling = false;
  djBilingualJobState.running = false;
}

async function pollDJBulkBilingualizeProgress() {
  if (djBilingualJobState.polling) return;
  if (!djBilingualJobState.jobId) return;
  djBilingualJobState.polling = true;
  const authHeaders = getViewerAuthHeaders();
  if (!authHeaders.Authorization) {
    djBilingualJobState.polling = false;
    return;
  }
  try {
    const resp = await apiGet(
      `/api/raver/djs/translate-bilingual/progress?job_id=${encodeURIComponent(djBilingualJobState.jobId)}&since=${encodeURIComponent(String(djBilingualJobState.since))}`,
      authHeaders
    );
    const progress = (resp && typeof resp.progress === 'object') ? resp.progress : {};
    const newRows = Array.isArray(resp?.new_rows) ? resp.new_rows : [];
    const nextSince = Number(resp?.next_since);
    if (Number.isFinite(nextSince)) {
      djBilingualJobState.since = Math.max(0, nextSince);
    } else {
      const completedCount = Number(progress?.completed_row_count);
      if (Number.isFinite(completedCount)) {
        djBilingualJobState.since = Math.max(0, completedCount);
      }
    }

    maybeAppendDJBulkProgressLog(progress);

    if (newRows.length) {
      for (const row of newRows) {
        djBilingualJobState.rows.push(row);
        const status = String(row?.status || '');
        const djName = String(row?.djName || '').trim();
        const label = djName ? `${djName} (${row?.djId || ''})` : String(row?.djId || '');
        if (status === 'updated') {
          appendDJBulkLog(`UPDATED ${label}`, 'ok');
        } else if (status === 'error') {
          appendDJBulkLog(`ERROR ${label}: ${String(row?.reason || 'unknown')}`, 'err');
        } else if (status === 'skipped') {
          appendDJBulkLog(`SKIPPED ${label}: ${String(row?.reason || '-')}`, 'warn');
        } else {
          appendDJBulkLog(`${status.toUpperCase()} ${label}`, 'info');
        }
      }
    }

    updateDJBulkProgressUI(progress);
    updateDJBulkSelectionButtons();

    const status = String(progress?.job_status || progress?.status || '');
    if (status && !['running', 'stopping'].includes(status)) {
      stopDJBulkPolling();
      djLibraryState.translating = false;
      updateDJBulkSelectionButtons();

      let resultRows = djBilingualJobState.rows;
      try {
        const resultResp = await apiGet(
          `/api/raver/djs/translate-bilingual/result?job_id=${encodeURIComponent(djBilingualJobState.jobId)}`,
          authHeaders
        );
        const result = (resultResp && typeof resultResp.result === 'object') ? resultResp.result : {};
        if (Array.isArray(result?.rows)) resultRows = result.rows;
        const success = Number(result?.success || 0);
        const failed = Number(result?.failed || 0);
        const skipped = Number(result?.skipped || 0);
        const total = Number(result?.total || 0);
        const stopped = !!result?.stopped;
        const summary = `${stopped ? '任务已停止' : '任务完成'}：成功 ${success}，失败 ${failed}，跳过 ${skipped}，总计 ${total}`;
        setDJStatus(summary, failed > 0);
        appendDJBulkLog(summary, failed > 0 ? 'warn' : 'ok');
        if (String(result?.fatal_error || '').trim()) {
          appendDJBulkLog(`FATAL: ${String(result.fatal_error)}`, 'err');
        }
      } catch (error) {
        appendDJBulkLog(`读取结果失败：${String(error?.message || 'unknown')}`, 'err');
      }

      finishDJBulkJobAndReselect(resultRows);
      renderDJLibrary();
      await ensureDJLibraryLoaded(true);
      renderDJLibrary();
    }
  } catch (error) {
    appendDJBulkLog(`进度轮询失败：${String(error?.message || 'unknown')}`, 'err');
  } finally {
    djBilingualJobState.polling = false;
  }
}

async function stopDJBulkBilingualizeJob() {
  if (!djLibraryState.translating || !djBilingualJobState.jobId) return;
  const authHeaders = getViewerAuthHeaders();
  if (!authHeaders.Authorization) return;
  try {
    await apiPost(
      '/api/raver/djs/translate-bilingual/stop',
      { job_id: djBilingualJobState.jobId },
      authHeaders
    );
    appendDJBulkLog('已发送停止请求，等待当前条目处理完成...', 'warn');
    setDJStatus('停止请求已发送，处理中...', false);
  } catch (error) {
    appendDJBulkLog(`停止失败：${String(error?.message || 'unknown')}`, 'err');
    setDJStatus(`停止失败：${String(error?.message || '未知错误')}`, true);
  }
}

function reselectDJBulkUnsuccessful() {
  if (djLibraryState.translating) return;
  const unsuccessful = new Set();
  for (const row of djBilingualJobState.rows) {
    const id = normalizeDJLibraryId(row?.djId);
    if (!id) continue;
    if (String(row?.status || '') !== 'updated') unsuccessful.add(id);
  }
  djLibraryState.selectedIds = unsuccessful;
  renderDJLibrary();
  setDJStatus(`已重选未成功 DJ：${unsuccessful.size} 个。`, unsuccessful.size === 0);
}

function getDJCurrentOrderedItemsForSelection() {
  return (Array.isArray(djLibraryState.filteredItems) ? djLibraryState.filteredItems : [])
    .slice()
    .sort((a, b) => String(a?.name || '').localeCompare(String(b?.name || ''), 'en', { sensitivity: 'base' }));
}

function parseDJSelectionRange(totalCount) {
  const startInput = document.getElementById('dj-bilingual-range-start');
  const endInput = document.getElementById('dj-bilingual-range-end');
  const rawStart = String(startInput?.value || '').trim();
  const rawEnd = String(endInput?.value || '').trim();
  const total = Math.max(0, Number(totalCount || 0));
  if (!total) {
    return { ok: false, error: '当前没有可翻译的 DJ。', from: 0, to: 0 };
  }
  if (!rawStart && !rawEnd) {
    return { ok: true, from: 1, to: total, ranged: false };
  }
  let from = rawStart ? Number(rawStart) : 1;
  let to = rawEnd ? Number(rawEnd) : total;
  if (!Number.isInteger(from) || !Number.isInteger(to) || from <= 0 || to <= 0) {
    return { ok: false, error: '索引必须是大于 0 的整数。', from: 0, to: 0 };
  }
  if (from > to) {
    return { ok: false, error: '起始索引不能大于结束索引。', from: 0, to: 0 };
  }
  if (from > total) {
    return { ok: false, error: `起始索引超出范围（当前最多 ${total}）。`, from: 0, to: 0 };
  }
  if (to > total) to = total;
  return { ok: true, from, to, ranged: true };
}

function selectDJByRange() {
  if (!djLibraryState.selectionMode) {
    setDJStatus('请先进入选择模式。', true);
    return;
  }
  const ordered = getDJCurrentOrderedItemsForSelection();
  const range = parseDJSelectionRange(ordered.length);
  if (!range.ok) {
    setDJStatus(range.error || '索引范围无效。', true);
    return;
  }
  const ids = ordered
    .slice(range.from - 1, range.to)
    .map((item) => normalizeDJLibraryId(item?.id))
    .filter(Boolean);
  djLibraryState.selectedIds = new Set(ids);
  renderDJGrid();
  const scopeText = `（当前筛选结果第 ${range.from}~${range.to} 条）`;
  setDJStatus(`已按索引选中 ${ids.length} 个 DJ ${scopeText}`, false);
}

async function runDJBulkBilingualizeSelected() {
  if (djLibraryState.translating) return;
  if (!djLibraryState.selectionMode) {
    setDJStatus('请先进入选择模式并勾选 DJ。', true);
    return;
  }
  const selectedIds = djLibraryState.selectedIds instanceof Set ? [...djLibraryState.selectedIds] : [];
  if (!selectedIds.length) {
    setDJStatus('请先选择至少一个 DJ。', true);
    return;
  }

  const authHeaders = getViewerAuthHeaders();
  if (!authHeaders.Authorization) {
    openViewerLogin();
    setDJStatus('请先登录后再执行双语化。', true);
    return;
  }

  const confirmed = window.confirm(`确认对选中的 ${selectedIds.length} 个 DJ 执行 country/bio 双语化并回写数据库吗？`);
  if (!confirmed) return;

  try {
    const resp = await apiPost(
      '/api/raver/djs/translate-bilingual/start',
      { djIds: selectedIds },
      authHeaders
    );
    const jobId = String(resp?.job_id || '').trim();
    if (!jobId) throw new Error('启动失败：未返回 job_id');

    stopDJBulkPolling();
    djBilingualJobState.jobId = jobId;
    djBilingualJobState.since = 0;
    djBilingualJobState.polling = false;
    djBilingualJobState.running = true;
    djBilingualJobState.rows = [];
    djBilingualJobState.initialSelectedIds = [...selectedIds];
    djBilingualJobState.lastProgressLogKey = '';
    djBilingualJobState.lastProgressLogAt = 0;
    djLibraryState.translating = true;
    updateDJToolbarMeta();
    clearDJBulkLogs();
    appendDJBulkLog(`任务已启动 job=${jobId}，总计 ${selectedIds.length} 个 DJ`, 'ok');
    updateDJBulkProgressUI({
      status: 'running',
      total: selectedIds.length,
      processed: 0,
      updated: 0,
      failed: 0,
      skipped: 0,
    });
    setDJStatus(`双语化任务启动：0/${selectedIds.length}`);

    await pollDJBulkBilingualizeProgress();
    djBilingualJobState.pollTimer = setInterval(() => {
      pollDJBulkBilingualizeProgress();
    }, 1200);
  } catch (error) {
    setDJStatus(`双语化失败：${String(error?.message || '未知错误')}`, true);
  }
}

function djEnrichmentJobStatusLabel(status) {
  const key = String(status || '').trim().toLowerCase();
  if (key === 'pending') return '排队中';
  if (key === 'running') return '处理中';
  if (key === 'partially_completed') return '部分完成';
  if (key === 'completed') return '已完成';
  if (key === 'failed') return '失败';
  return key || '未知';
}

function setDJEnrichmentPanelCollapsed(collapsed) {
  const panel = document.getElementById('dj-enrichment-progress-panel');
  const btn = document.getElementById('dj-enrichment-collapse-btn');
  const next = collapsed !== false;
  if (panel) panel.classList.toggle('collapsed', next);
  if (btn) {
    btn.textContent = next ? '展开' : '收起';
    btn.setAttribute('aria-expanded', next ? 'false' : 'true');
  }
}

function toggleDJEnrichmentPanel() {
  const panel = document.getElementById('dj-enrichment-progress-panel');
  setDJEnrichmentPanelCollapsed(!panel?.classList.contains('collapsed'));
}

function renderDJEnrichmentJobList() {
  const wrap = document.getElementById('dj-enrichment-job-list');
  if (!wrap) return;
  const jobs = Array.isArray(djEnrichmentJobState.jobs) ? djEnrichmentJobState.jobs : [];
  if (!jobs.length) {
    wrap.innerHTML = '<div class="dj-enrichment-empty">暂无 Coze enrichment 历史任务。提交后会出现在这里，换设备登录也能看到。</div>';
    return;
  }
  const selectedJobId = String(djEnrichmentJobState.lastJobId || '').trim();
  wrap.innerHTML = jobs.map((job) => {
    const id = String(job?.id || '').trim();
    const active = id && id === selectedJobId;
    const total = Math.max(0, Number(job?.totalCount || job?._count?.results || 0));
    const queued = Math.max(0, Number(job?.queuedCount || 0));
    const running = Math.max(0, Number(job?.runningCount || 0));
    const success = Math.max(0, Number(job?.successCount || 0));
    const failed = Math.max(0, Number(job?.failedCount || 0));
    const processed = success + failed;
    const requestedBy = String(job?.requestedBy?.displayName || job?.requestedBy?.username || '').trim();
    const createdAt = String(job?.createdAt || '').trim();
    return `
      <button class="dj-enrichment-job-item ${active ? 'active' : ''}" type="button" onclick="selectDJEnrichmentJob('${escapeHtml(id)}')">
        <div class="dj-enrichment-job-top">
          <span class="dj-enrichment-job-status">${escapeHtml(djEnrichmentJobStatusLabel(job?.status))}</span>
          <span class="dj-enrichment-job-id">${escapeHtml(id.slice(0, 8) || '-')}</span>
        </div>
        <div class="dj-enrichment-job-progress">${escapeHtml(String(processed))}<span>/ ${escapeHtml(String(total || 0))}</span></div>
        <div class="dj-enrichment-job-meta">排队 ${escapeHtml(String(queued))} · 运行中 ${escapeHtml(String(running))} · 失败 ${escapeHtml(String(failed))}</div>
        <div class="dj-enrichment-job-meta">${escapeHtml(requestedBy || '未知提交人')}${createdAt ? ` · ${escapeHtml(createdAt.replace('T', ' ').slice(0, 16))}` : ''}</div>
      </button>
    `;
  }).join('');
}

function selectDJEnrichmentJob(jobId) {
  const id = String(jobId || '').trim();
  if (!id) return;
  djEnrichmentJobState.lastJobId = id;
  const jobs = Array.isArray(djEnrichmentJobState.jobs) ? djEnrichmentJobState.jobs : [];
  const selected = jobs.find((item) => String(item?.id || '').trim() === id) || null;
  if (selected) {
    djEnrichmentJobState.lastJob = selected;
    renderDJEnrichmentJobProgress(selected);
  }
  renderDJEnrichmentJobList();
  startDJEnrichmentJobPolling();
}

async function refreshDJEnrichmentJobs(force = false) {
  if (djEnrichmentJobState.loadingJobs && !force) return;
  const authHeaders = getViewerAuthHeaders();
  if (!authHeaders.Authorization) return;
  djEnrichmentJobState.loadingJobs = true;
  try {
    const resp = await apiGet('/api/admin/v1/dj-enrichment/jobs?limit=12', authHeaders);
    const items = Array.isArray(resp?.items) ? resp.items : [];
    djEnrichmentJobState.jobs = items;
    const currentId = String(djEnrichmentJobState.lastJobId || '').trim();
    const existing = currentId ? items.find((job) => String(job?.id || '').trim() === currentId) : null;
    if (existing) {
      djEnrichmentJobState.lastJob = existing;
    } else {
      const preferred = items.find((job) => ['pending', 'running', 'partially_completed'].includes(String(job?.status || '').trim().toLowerCase()))
        || items[0]
        || null;
      djEnrichmentJobState.lastJobId = String(preferred?.id || '').trim();
      djEnrichmentJobState.lastJob = preferred;
    }
    renderDJEnrichmentJobList();
    renderDJEnrichmentJobProgress(djEnrichmentJobState.lastJob);
    if (djEnrichmentJobState.lastJobId) {
      void refreshDJEnrichmentJobProgress(false);
    }
  } catch (error) {
    if (force) {
      setDJStatus(`刷新 Coze enrichment 任务失败：${String(error?.message || '未知错误')}`, true);
    }
  } finally {
    djEnrichmentJobState.loadingJobs = false;
  }
}

function stopDJEnrichmentJobPolling() {
  if (djEnrichmentJobState.pollTimer) {
    clearInterval(djEnrichmentJobState.pollTimer);
    djEnrichmentJobState.pollTimer = null;
  }
  djEnrichmentJobState.polling = false;
}

function renderDJEnrichmentJobProgress(job = null) {
  const summaryEl = document.getElementById('dj-enrichment-progress-summary');
  const barEl = document.getElementById('dj-enrichment-progress-bar-fill');
  const metaEl = document.getElementById('dj-enrichment-progress-meta');
  if (!summaryEl || !barEl || !metaEl) return;

  if (!job || typeof job !== 'object') {
    summaryEl.textContent = 'Coze enrichment 任务：未开始';
    barEl.style.width = '0%';
    metaEl.innerHTML = '<div class="dj-enrichment-empty">提交任务后，这里会显示排队、处理中、成功、失败、待审核进度。</div>';
    renderDJEnrichmentJobList();
    return;
  }

  const total = Math.max(0, Number(job.totalCount || 0));
  const queued = Math.max(0, Number(job.queuedCount || 0));
  const running = Math.max(0, Number(job.runningCount || 0));
  const success = Math.max(0, Number(job.successCount || 0));
  const failed = Math.max(0, Number(job.failedCount || 0));
  const reviewed = Math.max(0, Number(job.reviewedCount || 0));
  const processed = success + failed;
  const ratio = total > 0 ? Math.min(1, Math.max(0, processed / total)) : 0;
  const requestedBy = String(job?.requestedBy?.displayName || job?.requestedBy?.username || job?.requestedById || '').trim();

  summaryEl.textContent = `Coze enrichment 任务 ${djEnrichmentJobStatusLabel(job.status)} · ${processed}/${total || '—'} 已完成 · 运行中 ${running}`;
  barEl.style.width = `${Math.round(ratio * 1000) / 10}%`;
  metaEl.innerHTML = `
    <div class="dj-enrichment-stats-grid">
      <div class="dj-enrichment-stat"><span>jobId</span><strong>${escapeHtml(String(job.id || '-'))}</strong></div>
      <div class="dj-enrichment-stat"><span>提交人</span><strong>${escapeHtml(requestedBy || '—')}</strong></div>
      <div class="dj-enrichment-stat"><span>总数</span><strong>${escapeHtml(String(total))}</strong></div>
      <div class="dj-enrichment-stat"><span>排队中</span><strong>${escapeHtml(String(queued))}</strong></div>
      <div class="dj-enrichment-stat"><span>处理中</span><strong>${escapeHtml(String(running))}</strong></div>
      <div class="dj-enrichment-stat"><span>成功</span><strong>${escapeHtml(String(success))}</strong></div>
      <div class="dj-enrichment-stat"><span>失败</span><strong>${escapeHtml(String(failed))}</strong></div>
      <div class="dj-enrichment-stat"><span>已审核</span><strong>${escapeHtml(String(reviewed))}</strong></div>
      <div class="dj-enrichment-stat wide"><span>创建时间</span><strong>${escapeHtml(String(job.createdAt || '-'))}</strong></div>
      <div class="dj-enrichment-stat wide"><span>完成时间</span><strong>${escapeHtml(String(job.completedAt || '-'))}</strong></div>
    </div>
  `;
}

async function refreshDJEnrichmentJobProgress(force = false) {
  if (djEnrichmentJobState.polling && !force) return;
  const jobId = String(djEnrichmentJobState.lastJobId || '').trim();
  if (!jobId) {
    renderDJEnrichmentJobProgress(null);
    return;
  }
  const authHeaders = getViewerAuthHeaders();
  if (!authHeaders.Authorization) return;
  djEnrichmentJobState.polling = true;
  try {
    const resp = await apiGet(`/api/admin/v1/dj-enrichment/jobs/${encodeURIComponent(jobId)}`, authHeaders);
    const job = resp && typeof resp.job === 'object' ? resp.job : null;
    djEnrichmentJobState.lastJob = job;
    if (job && Array.isArray(djEnrichmentJobState.jobs)) {
      const idx = djEnrichmentJobState.jobs.findIndex((item) => String(item?.id || '').trim() === String(job.id || '').trim());
      if (idx >= 0) djEnrichmentJobState.jobs[idx] = { ...djEnrichmentJobState.jobs[idx], ...job };
    }
    renderDJEnrichmentJobList();
    renderDJEnrichmentJobProgress(job);
    const status = String(job?.status || '').trim().toLowerCase();
    if (['completed', 'failed'].includes(status)) {
      stopDJEnrichmentJobPolling();
    }
  } catch (error) {
    if (force) {
      setDJStatus(`刷新 Coze enrichment 进度失败：${String(error?.message || '未知错误')}`, true);
    }
  } finally {
    djEnrichmentJobState.polling = false;
  }
}

function startDJEnrichmentJobPolling() {
  setDJEnrichmentPanelCollapsed(false);
  stopDJEnrichmentJobPolling();
  void refreshDJEnrichmentJobs(false);
  void refreshDJEnrichmentJobProgress(true);
  djEnrichmentJobState.pollTimer = setInterval(() => {
    refreshDJEnrichmentJobProgress(false);
  }, 2500);
}

setDJEnrichmentPanelCollapsed(true);
window.setDJEnrichmentPanelCollapsed = setDJEnrichmentPanelCollapsed;
window.toggleDJEnrichmentPanel = toggleDJEnrichmentPanel;

async function submitDJEnrichmentSelected() {
  if (djEnrichmentJobState.submitting) return;
  const authHeaders = getViewerAuthHeaders();
  if (!authHeaders.Authorization) {
    setDJStatus('请先登录后再提交 Coze enrichment。', true);
    return;
  }
  const selectedIds = djLibraryState.selectedIds instanceof Set ? [...djLibraryState.selectedIds] : [];
  const concurrencyInput = document.getElementById('dj-enrichment-concurrency-input');
  const rawConcurrency = Number(concurrencyInput?.value || 10);
  const maxConcurrency = Number.isFinite(rawConcurrency)
    ? Math.max(1, Math.min(20, Math.floor(rawConcurrency)))
    : 10;
  if (!selectedIds.length) {
    setDJStatus('请先选中至少一个 DJ。', true);
    return;
  }
  const confirmed = window.confirm(
    `确认将选中的 ${selectedIds.length} 个 DJ 提交到 Coze enrichment 队列吗？\n最大并发请求数：${maxConcurrency}\n结果会异步进入 Review 审核区。`
  );
  if (!confirmed) return;

  djEnrichmentJobState.submitting = true;
  try {
    const resp = await apiPost(
      '/api/admin/v1/dj-enrichment/jobs',
      { djIds: selectedIds, maxConcurrency },
      authHeaders
    );
    const jobId = String(resp?.jobId || '').trim();
    const acceptedCount = Number(resp?.acceptedCount || 0);
    const effectiveConcurrency = Number(resp?.maxConcurrency || maxConcurrency);
    djEnrichmentJobState.lastJobId = jobId;
    djEnrichmentJobState.lastAcceptedCount = acceptedCount;
    djEnrichmentJobState.lastJob = null;
    void refreshDJEnrichmentJobs(true);
    startDJEnrichmentJobPolling();
    setDJStatus(
      `Coze enrichment 已入队：${acceptedCount} 个 DJ · 并发 ${effectiveConcurrency}${jobId ? ` · job ${jobId}` : ''}。可继续提交更多任务。`,
      false
    );
    appendDJBulkLog(
      `ENRICHMENT QUEUED ${acceptedCount} DJs · concurrency=${effectiveConcurrency}${jobId ? ` · job=${jobId}` : ''}`,
      'ok'
    );
  } catch (error) {
    const message = String(error?.message || 'unknown');
    setDJStatus(`Coze enrichment 提交失败：${message}`, true);
    appendDJBulkLog(`ENRICHMENT ERROR: ${message}`, 'err');
  } finally {
    djEnrichmentJobState.submitting = false;
  }
}
