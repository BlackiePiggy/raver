const REVIEW_BINDING_JOB_STATUS_LABELS = {
  pending: '待处理',
  partially_applied: '部分已绑定',
  applied: '已完成',
  dismissed: '已忽略',
};

const REVIEW_BINDING_MATCH_TIER_LABELS = {
  exact: '完全匹配',
  fuzzy: '模糊匹配',
};

const REVIEW_BINDING_MATCH_REASON_LABELS = {
  normalized_equal: '标准化后完全一致',
  compact_equal: '去分隔符后完全一致',
  contains: '标准化后包含关系',
  similarity: '相似度命中',
};

const REVIEW_BINDING_SOURCE_TYPE_LABELS = {
  lineup_artist: 'Lineup Artist',
  lineup_member: 'Lineup Member',
  timetable_slot: 'Timetable Slot',
};

function isDjBindingReviewSource() {
  return reviewPageState.sourceFilter === 'dj_binding_review';
}

function ensureDjBindingCandidateSelectionState() {
  if (!(reviewPageState.bindingCandidateIds instanceof Set)) {
    reviewPageState.bindingCandidateIds = new Set();
  }
}

function resetDjBindingCandidateSelection() {
  reviewPageState.bindingCandidateIds = new Set();
}

function getDjBindingReviewListResponsePayload(data) {
  if (data && typeof data === 'object' && data.data && typeof data.data === 'object') return data.data;
  return data && typeof data === 'object' ? data : {};
}

function normalizeDjBindingReviewJob(job) {
  const row = job && typeof job === 'object' ? job : {};
  return {
    ...row,
    entityType: 'dj_binding_review',
    title: String(row.djNameSnapshot || row?.dj?.name || 'DJ Binding Review').trim() || 'DJ Binding Review',
    status: String(row.status || 'pending').trim() || 'pending',
  };
}

function getDjBindingReviewPendingCandidates(job, tier = '') {
  const items = Array.isArray(job?.candidates) ? job.candidates : [];
  return items.filter((item) => {
    if (!item || item.status !== 'pending') return false;
    if (tier && item.matchTier !== tier) return false;
    return true;
  });
}

function getDjBindingReviewCandidatesByTier(job, tier) {
  const items = Array.isArray(job?.candidates) ? job.candidates : [];
  return items.filter((item) => item?.matchTier === tier);
}

function isDjBindingCandidateSelected(candidateId) {
  ensureDjBindingCandidateSelectionState();
  return reviewPageState.bindingCandidateIds.has(String(candidateId || ''));
}

function toggleDjBindingCandidateSelection(candidateId, checked) {
  const normalizedId = String(candidateId || '').trim();
  if (!normalizedId) return;
  ensureDjBindingCandidateSelectionState();
  if (checked) reviewPageState.bindingCandidateIds.add(normalizedId);
  else reviewPageState.bindingCandidateIds.delete(normalizedId);
  renderReviewDetail();
}

function toggleDjBindingCandidateSelectionByToken(candidateIdToken, checked) {
  toggleDjBindingCandidateSelection(decodeURIComponent(String(candidateIdToken || '')), checked);
}

function selectDjBindingCandidatesByTier(tier, checked, includeNeedsSplit = true) {
  const job = reviewPageState.selectedDetail;
  const rows = getDjBindingReviewCandidatesByTier(job, tier);
  ensureDjBindingCandidateSelectionState();
  for (const row of rows) {
    if (!row || row.status !== 'pending') continue;
    if (!includeNeedsSplit && row.needsSplit) continue;
    const normalizedId = String(row.id || '').trim();
    if (!normalizedId) continue;
    if (checked) reviewPageState.bindingCandidateIds.add(normalizedId);
    else reviewPageState.bindingCandidateIds.delete(normalizedId);
  }
  renderReviewDetail();
}

function getDjBindingSelectedPendingCandidateIds() {
  const selectedIds = reviewPageState.bindingCandidateIds instanceof Set
    ? Array.from(reviewPageState.bindingCandidateIds)
    : [];
  const pendingIds = new Set(
    getDjBindingReviewPendingCandidates(reviewPageState.selectedDetail).map((item) => String(item.id || '').trim())
  );
  return selectedIds.filter((id) => pendingIds.has(String(id || '').trim()));
}

function findFestivalByBackendEventId(eventId) {
  const normalizedId = String(eventId || '').trim();
  if (!normalizedId) return null;
  for (const yearData of Object.values(allData || {})) {
    for (const monthData of Object.values(yearData || {})) {
      const source = Array.isArray(monthData) ? monthData : [];
      const match = source.find((fest) => String(fest?.backendEventId || fest?.info?.backendEventId || '').trim() === normalizedId);
      if (match) return match;
    }
  }
  return null;
}

async function refreshFestivalBindingReviewEventCache(eventId) {
  const normalizedId = String(eventId || '').trim();
  if (!normalizedId) return null;
  try {
    const detailResp = await apiGet(`/api/raver/events/${encodeURIComponent(normalizedId)}`, getViewerAuthHeaders());
    const event = detailResp?.data || detailResp || null;
    if (!event || typeof event !== 'object' || typeof mapBackendEventToFestival !== 'function') return null;
    const mapped = mapBackendEventToFestival(event);
    const fest = findFestivalByBackendEventId(normalizedId);
    const nextFest = fest || mapped;
    if (fest) {
      fest.folder = mapped.folder;
      fest.year = mapped.year;
      fest.month = mapped.month;
      fest.name = mapped.name;
      fest.location = mapped.location;
      fest.images = Array.isArray(mapped.images) ? mapped.images : [];
      fest.backendEventId = mapped.backendEventId;
      fest.info = { ...(fest.info || {}), ...(mapped.info || {}) };
      fest.backendDetailLoaded = true;
    }

    const rowEl = document.querySelector(`.festival-row[data-backend-event-id="${CSS.escape(normalizedId)}"]`);
    if (rowEl && fest && typeof refreshFestHeaderDisplay === 'function') {
      refreshFestHeaderDisplay(rowEl, fest);
      const panel = rowEl.querySelector('.fest-info-panel');
      if (panel && typeof renderInfoView === 'function') renderInfoView(panel, fest.info);
      if (panel && panel.classList.contains('is-editing') && typeof setEditInputs === 'function') {
        setEditInputs(panel, fest.info);
      }
    }

    if (
      typeof eventLineupModalState !== 'undefined'
      && eventLineupModalState?.currentFest
      && String(eventLineupModalState.currentFest?.backendEventId || eventLineupModalState.currentFest?.info?.backendEventId || '').trim() === normalizedId
    ) {
      eventLineupModalState.currentFest = nextFest;
      if (typeof renderEventLineupModalBody === 'function') renderEventLineupModalBody();
    }

    if (
      typeof ttModalState !== 'undefined'
      && ttModalState?.currentFest
      && String(ttModalState.currentFest?.backendEventId || ttModalState.currentFest?.info?.backendEventId || '').trim() === normalizedId
    ) {
      ttModalState.currentFest = nextFest;
      if (typeof renderTtModalBody === 'function') renderTtModalBody();
    }

    return nextFest;
  } catch (_error) {
    return null;
  }
}

async function refreshDjBindingReviewDjCache(djId) {
  const normalizedId = String(djId || '').trim();
  if (!normalizedId) return null;
  try {
    const [detailResp, setsResp, eventsResp] = await Promise.all([
      apiGet(`/api/raver/djs/${encodeURIComponent(normalizedId)}`, getViewerAuthHeaders()),
      apiGet(`/api/raver/djs/${encodeURIComponent(normalizedId)}/sets`, getViewerAuthHeaders()),
      apiGet(`/api/raver/djs/${encodeURIComponent(normalizedId)}/events`, getViewerAuthHeaders()),
    ]);
    const detail = detailResp?.data || detailResp || null;
    if (detail && typeof syncDJListItem === 'function') {
      syncDJListItem(detail);
    }
    if (
      detail
      && djProfileState?.djId
      && String(djProfileState.djId || '').trim() === normalizedId
    ) {
      const sets = setsResp?.data?.items || setsResp?.items || [];
      const events = eventsResp?.data?.items || eventsResp?.items || [];
      djProfileState.detail = detail;
      djProfileState.sets = Array.isArray(sets) ? sets : [];
      djProfileState.events = Array.isArray(events) ? events : [];
      const titleEl = document.getElementById('dj-profile-title');
      const subEl = document.getElementById('dj-profile-sub');
      const bodyEl = document.getElementById('dj-profile-body');
      if (titleEl) titleEl.textContent = String(detail?.name || 'Unknown DJ').trim().toUpperCase() || 'DJ PROFILE';
      if (subEl) subEl.textContent = detail?.id ? `ID · ${detail.id}` : 'DJ DETAIL';
      if (bodyEl && typeof renderDJProfileContent === 'function') {
        bodyEl.innerHTML = renderDJProfileContent(detail, djProfileState.sets, djProfileState.events);
      }
      if (typeof initDJProfileSourceReplaceUI === 'function') initDJProfileSourceReplaceUI(detail);
      if (typeof refreshDJEditAvatarUploaderUI === 'function') refreshDJEditAvatarUploaderUI();
      if (typeof bindDJProfileActionButtons === 'function') bindDJProfileActionButtons(normalizedId);
    }
    if (typeof renderDJLibrary === 'function') {
      renderDJLibrary();
    }
    return detail;
  } catch (_error) {
    return null;
  }
}

async function refreshDjBindingReviewAffectedCaches(job, candidates) {
  const djId = String(job?.dj?.id || job?.djId || '').trim();
  const eventIds = Array.from(new Set(
    (Array.isArray(candidates) ? candidates : [])
      .map((item) => String(item?.eventId || '').trim())
      .filter(Boolean)
  ));
  await Promise.all([
    djId ? refreshDjBindingReviewDjCache(djId) : Promise.resolve(null),
    ...eventIds.map((eventId) => refreshFestivalBindingReviewEventCache(eventId)),
  ]);
}

function reviewBindingFormatReason(candidate) {
  const reason = String(candidate?.matchReason || '').trim();
  const score = Math.max(0, Number(candidate?.matchScore || 0) || 0);
  const reasonLabel = REVIEW_BINDING_MATCH_REASON_LABELS[reason] || reason || '—';
  return `${reasonLabel} · ${score}分`;
}

function reviewBindingFormatCandidateMeta(candidate) {
  const parts = [
    REVIEW_BINDING_SOURCE_TYPE_LABELS[candidate?.sourceType] || candidate?.sourceType || '—',
    reviewBindingFormatReason(candidate),
    candidate?.stageNameSnapshot ? `Stage ${candidate.stageNameSnapshot}` : '',
    candidate?.startAtSnapshot ? reviewFormatDate(candidate.startAtSnapshot) : '',
    candidate?.status ? `状态 ${candidate.status}` : '',
  ].filter(Boolean);
  return parts.join(' · ');
}

function reviewBindingStatusTone(status) {
  if (status === 'applied') return 'applied';
  if (status === 'dismissed') return 'dismissed';
  if (status === 'skipped_already_bound') return 'skipped';
  return 'pending';
}

function renderDjBindingReviewCandidateCard(candidate) {
  const candidateId = String(candidate?.id || '').trim();
  const canSelect = candidate?.status === 'pending';
  const fieldToken = encodeURIComponent(candidateId);
  return `
    <article class="review-binding-candidate ${candidate?.needsSplit ? 'needs-split' : ''} ${reviewBindingStatusTone(candidate?.status)}">
      <div class="review-binding-candidate-head">
        <label class="review-select-page review-binding-candidate-check">
          <input
            type="checkbox"
            ${isDjBindingCandidateSelected(candidateId) ? 'checked' : ''}
            ${canSelect ? '' : 'disabled'}
            onchange="toggleDjBindingCandidateSelectionByToken('${fieldToken}', this.checked)"
          >
          <span>${escapeHtml(REVIEW_BINDING_MATCH_TIER_LABELS[candidate?.matchTier] || candidate?.matchTier || 'Candidate')}</span>
        </label>
        <div class="review-binding-candidate-status ${reviewBindingStatusTone(candidate?.status)}">
          ${escapeHtml(candidate?.status || 'pending')}
        </div>
      </div>
      <div class="review-binding-candidate-name">${escapeHtml(candidate?.rawName || '—')}</div>
      <div class="review-binding-candidate-meta">${escapeHtml(reviewBindingFormatCandidateMeta(candidate))}</div>
      <div class="review-binding-candidate-context">
        <div><span>Event</span><strong>${escapeHtml(candidate?.eventNameSnapshot || '—')}</strong></div>
        <div><span>Normalized</span><strong>${escapeHtml(candidate?.normalizedKey || '—')}</strong></div>
        <div><span>Compact</span><strong>${escapeHtml(candidate?.compactKey || '—')}</strong></div>
        <div><span>Match</span><strong>${escapeHtml(reviewBindingFormatReason(candidate))}</strong></div>
      </div>
      ${candidate?.needsSplit ? '<div class="review-binding-warning">需要先拆成员或人工确认，不能直接作为“完全匹配”一键绑定。</div>' : ''}
    </article>
  `;
}

function renderDjBindingReviewCandidateSection(job, tier) {
  const rows = getDjBindingReviewCandidatesByTier(job, tier);
  const pendingRows = rows.filter((item) => item?.status === 'pending');
  const actionableRows = pendingRows.filter((item) => !item?.needsSplit);
  const tierLabel = REVIEW_BINDING_MATCH_TIER_LABELS[tier] || tier;
  const subtitle = tier === 'exact'
    ? '高置信候选，可一键全量绑定。'
    : '模糊匹配候选，建议人工勾选后再绑定。';
  return `
    <section class="review-group-card ${tier === 'exact' ? 'review-group-resolution' : 'review-group-candidates'}">
      <div class="review-group-head">
        <div>
          <div class="review-group-title">${escapeHtml(tierLabel)}</div>
          <div class="review-group-sub">${escapeHtml(subtitle)}</div>
        </div>
        <div class="review-binding-section-meta">
          <span>共 ${escapeHtml(String(rows.length))} 条</span>
          <span>待处理 ${escapeHtml(String(pendingRows.length))} 条</span>
          ${tier === 'exact' ? `<span>可一键 ${escapeHtml(String(actionableRows.length))} 条</span>` : ''}
        </div>
      </div>
      <div class="review-binding-section-actions">
        <button class="review-tool-btn" type="button" ${pendingRows.length ? '' : 'disabled'} onclick="selectDjBindingCandidatesByTier('${escapeHtml(tier)}', true, ${tier === 'exact' ? 'false' : 'true'})">全选待处理</button>
        <button class="review-tool-btn" type="button" ${pendingRows.length ? '' : 'disabled'} onclick="selectDjBindingCandidatesByTier('${escapeHtml(tier)}', false, true)">清空本区选择</button>
      </div>
      <div class="review-binding-candidate-list">
        ${rows.length ? rows.map(renderDjBindingReviewCandidateCard).join('') : '<div class="review-list-empty">当前分组没有候选。</div>'}
      </div>
    </section>
  `;
}

function renderDjBindingReviewPreview(job) {
  const exactPending = getDjBindingReviewPendingCandidates(job, 'exact').filter((item) => !item?.needsSplit).length;
  const fuzzyPending = getDjBindingReviewPendingCandidates(job, 'fuzzy').length;
  const selectedCount = getDjBindingSelectedPendingCandidateIds().length;
  return `
    <article class="review-rendered-card review-rendered-dj-binding">
      <div class="review-rendered-head">
        <div class="review-rendered-kicker">DJ Binding Review Job</div>
        <h2>${escapeHtml(job?.djNameSnapshot || job?.dj?.name || 'Unnamed DJ')}</h2>
        <div class="review-rendered-meta">
          <span>状态：${escapeHtml(REVIEW_BINDING_JOB_STATUS_LABELS[job?.status] || job?.status || '—')}</span>
          <span>来源：${escapeHtml(job?.triggerSource || '—')}</span>
          <span>Exact：${escapeHtml(String(job?.exactCount || 0))}</span>
          <span>Fuzzy：${escapeHtml(String(job?.fuzzyCount || 0))}</span>
          <span>Applied：${escapeHtml(String(job?.appliedCount || 0))}</span>
          <span>创建时间：${escapeHtml(reviewFormatDate(job?.createdAt))}</span>
        </div>
      </div>
      <section class="review-group-card review-group-input">
        <div class="review-group-head">
          <div>
            <div class="review-group-title">操作区</div>
            <div class="review-group-sub">完全匹配支持一键绑定；模糊匹配请勾选后手动绑定。</div>
          </div>
          <div class="review-binding-section-meta">
            <span>已选 ${escapeHtml(String(selectedCount))} 条</span>
            <span>可一键 ${escapeHtml(String(exactPending))} 条</span>
            <span>模糊待确认 ${escapeHtml(String(fuzzyPending))} 条</span>
          </div>
        </div>
        <div class="review-binding-action-row">
          <button class="review-tool-btn review-bulk-approve" type="button" ${exactPending ? '' : 'disabled'} onclick="applyExactDjBindingReviewCandidates()">一键绑定完全匹配</button>
          <button class="review-tool-btn review-bulk-approve" type="button" ${selectedCount ? '' : 'disabled'} onclick="applySelectedDjBindingReviewCandidates()">绑定选中候选</button>
          <button class="review-tool-btn review-bulk-reject" type="button" ${selectedCount ? '' : 'disabled'} onclick="dismissSelectedDjBindingReviewCandidates()">忽略选中候选</button>
          <button class="review-tool-btn" type="button" ${getDjBindingReviewPendingCandidates(job).length ? '' : 'disabled'} onclick="dismissAllDjBindingReviewCandidates()">忽略全部剩余候选</button>
        </div>
      </section>
      <div class="review-group-stack">
        ${renderDjBindingReviewCandidateSection(job, 'exact')}
        ${renderDjBindingReviewCandidateSection(job, 'fuzzy')}
      </div>
    </article>
  `;
}

function getDjBindingReviewJobListApiPath() {
  const qs = new URLSearchParams();
  if (reviewPageState.statusFilter) qs.set('status', reviewPageState.statusFilter);
  qs.set('page', String(Math.max(1, Number(reviewPageState.page || 1) || 1)));
  qs.set('limit', String(Math.max(1, Number(reviewPageState.pageSize || 50) || 50)));
  return `/api/admin/v1/dj-event-binding-review/jobs?${qs.toString()}`;
}

async function fetchDjBindingReviewJobs() {
  const data = await reviewApiGet(getDjBindingReviewJobListApiPath());
  const payload = getDjBindingReviewListResponsePayload(data);
  const items = Array.isArray(payload.items)
    ? payload.items.map(normalizeDjBindingReviewJob)
    : [];
  const pagination = data?.pagination && typeof data.pagination === 'object' ? data.pagination : {};
  return {
    items,
    total: Math.max(0, Number(pagination.total ?? items.length) || 0),
    page: Math.max(1, Number(pagination.page ?? reviewPageState.page ?? 1) || 1),
    totalPages: Math.max(1, Number(pagination.totalPages ?? 1) || 1),
  };
}

async function fetchDjBindingReviewJobDetail(jobId) {
  const data = await reviewApiGet(`/api/admin/v1/dj-event-binding-review/jobs/${encodeURIComponent(jobId)}`);
  const payload = getDjBindingReviewListResponsePayload(data);
  return normalizeDjBindingReviewJob(payload);
}

async function runDjBindingReviewAction(action, body = null, confirmText = '') {
  const jobId = String(reviewPageState?.selectedId || '').trim();
  const job = reviewPageState.selectedDetail;
  if (!jobId || reviewPageState.bindingActionBusy) return;
  if (confirmText && !window.confirm(confirmText)) return;
  reviewPageState.bindingActionBusy = true;
  setReviewStatus('正在处理 DJ 绑定审核任务...');
  renderReviewDetail();
  try {
    let affectedCandidates = [];
    if (action === 'apply-exact') {
      affectedCandidates = getDjBindingReviewPendingCandidates(job, 'exact').filter((item) => !item?.needsSplit);
    } else if (action === 'apply') {
      const ids = new Set(Array.isArray(body?.candidateIds) ? body.candidateIds.map((item) => String(item || '').trim()) : []);
      affectedCandidates = getDjBindingReviewPendingCandidates(job).filter((item) => ids.has(String(item?.id || '').trim()));
    }
    const path = action === 'apply-exact'
      ? `/api/admin/v1/dj-event-binding-review/jobs/${encodeURIComponent(jobId)}/apply-exact`
      : action === 'apply'
        ? `/api/admin/v1/dj-event-binding-review/jobs/${encodeURIComponent(jobId)}/apply`
        : `/api/admin/v1/dj-event-binding-review/jobs/${encodeURIComponent(jobId)}/dismiss`;
    await reviewApiPost(path, body || {});
    if (action === 'apply' || action === 'apply-exact') {
      await refreshDjBindingReviewAffectedCaches(job, affectedCandidates);
    }
    resetDjBindingCandidateSelection();
    await refreshReviewPendingCount();
    await refreshReviewPage(true);
    setReviewStatus('DJ 绑定审核任务已更新。', 'ok');
  } catch (error) {
    setReviewStatus(error instanceof Error ? error.message : 'DJ 绑定审核更新失败', 'error');
  } finally {
    reviewPageState.bindingActionBusy = false;
    renderReviewPage();
  }
}

async function applyExactDjBindingReviewCandidates() {
  const job = reviewPageState.selectedDetail;
  const exactPending = getDjBindingReviewPendingCandidates(job, 'exact').filter((item) => !item?.needsSplit);
  if (!exactPending.length) {
    setReviewStatus('当前没有可一键绑定的完全匹配候选。', 'error');
    return;
  }
  await runDjBindingReviewAction('apply-exact', {}, `确认一键绑定这 ${exactPending.length} 条完全匹配候选吗？`);
}

async function applySelectedDjBindingReviewCandidates() {
  const candidateIds = getDjBindingSelectedPendingCandidateIds();
  if (!candidateIds.length) {
    setReviewStatus('请先勾选要绑定的候选。', 'error');
    return;
  }
  await runDjBindingReviewAction('apply', { candidateIds }, `确认绑定选中的 ${candidateIds.length} 条候选吗？`);
}

async function dismissSelectedDjBindingReviewCandidates() {
  const candidateIds = getDjBindingSelectedPendingCandidateIds();
  if (!candidateIds.length) {
    setReviewStatus('请先勾选要忽略的候选。', 'error');
    return;
  }
  await runDjBindingReviewAction('dismiss', { candidateIds }, `确认忽略选中的 ${candidateIds.length} 条候选吗？`);
}

async function dismissAllDjBindingReviewCandidates() {
  const job = reviewPageState.selectedDetail;
  const pendingCount = getDjBindingReviewPendingCandidates(job).length;
  if (!pendingCount) {
    setReviewStatus('当前没有待处理候选。', 'error');
    return;
  }
  await runDjBindingReviewAction('dismiss', { dismissAll: true }, `确认忽略当前任务剩余的 ${pendingCount} 条候选吗？`);
}
