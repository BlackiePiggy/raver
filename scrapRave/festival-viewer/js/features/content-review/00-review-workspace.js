const REVIEW_ENTITY_LABELS = {
  event: 'Event',
  dj: 'DJ',
  news: 'News',
  set: 'Set',
  brand: 'Brand',
  label: 'Label',
  id: 'ID',
  rating: 'Rating',
  dj_enrichment: 'DJ Enrichment',
  dj_binding_review: 'DJ Binding Review',
};

const REVIEW_STATUS_LABELS = {
  pending: '待审核',
  processing: '处理中',
  reviewing: '审核中',
  approved: '已通过',
  rejected: '未通过',
  partially_applied: '部分已处理',
  applied: '已完成',
  dismissed: '已忽略',
};

const CONTENT_SUBMISSION_REVIEWABLE_STATUSES = ['pending', 'processing', 'reviewing'];

const REVIEW_PROCESSING_STATUS_LABELS = {
  queued: '排队中',
  running: '处理中',
  completed: '处理成功',
  failed: '处理失败',
};

const REVIEW_ENTITY_ORDER = ['event', 'dj', 'news', 'set', 'brand', 'label', 'id', 'rating'];
const REVIEW_SYSTEM_NOTE_KEYS = new Set([
  'source',
  'submittedAt',
  'reviewDecision',
  'brandScreening',
  'i18n',
  'compliance',
]);
const BRAND_REJECT_REASON_CODES = [
  { code: 'identity_unverified', label: '主体真实性不足' },
  { code: 'missing_official_link', label: '缺少可核验的官方链接' },
  { code: 'missing_proof', label: '缺少有效证明材料' },
  { code: 'copyright_risk', label: '图片或资料存在版权风险' },
  { code: 'duplicate_brand', label: '疑似重复主办方' },
  { code: 'event_conflict', label: '与现有活动命名或归属冲突' },
  { code: 'incomplete_profile', label: '资料不完整，无法独立审核' },
  { code: 'other', label: '其他原因' },
];

function reviewText(value) {
  if (value === null || value === undefined) return '';
  if (typeof value === 'string') return value.trim();
  if (typeof value === 'number' || typeof value === 'boolean') return String(value);
  try {
    return JSON.stringify(value);
  } catch (_error) {
    return String(value);
  }
}

function reviewArray(value) {
  if (Array.isArray(value)) return value.map(reviewText).filter(Boolean);
  const text = reviewText(value);
  if (!text) return [];
  return text.split(',').map((item) => item.trim()).filter(Boolean);
}

function isContentSubmissionReviewableStatus(status) {
  return CONTENT_SUBMISSION_REVIEWABLE_STATUSES.includes(String(status || '').trim());
}

function mergeReviewItemsById(groups) {
  const map = new Map();
  for (const group of groups) {
    for (const item of Array.isArray(group) ? group : []) {
      const id = String(item?.id || '').trim();
      if (!id || map.has(id)) continue;
      map.set(id, item);
    }
  }
  return Array.from(map.values()).sort((a, b) => {
    const bTime = new Date(b?.createdAt || b?.updatedAt || 0).getTime() || 0;
    const aTime = new Date(a?.createdAt || a?.updatedAt || 0).getTime() || 0;
    return bTime - aTime;
  });
}

function reviewFormatDate(value) {
  const text = reviewText(value);
  if (!text) return '—';
  const date = new Date(text);
  if (Number.isNaN(date.getTime())) return text;
  return date.toLocaleString();
}

function reviewFormatDateOnly(value) {
  const text = reviewText(value);
  if (!text) return '';
  const date = new Date(text);
  if (Number.isNaN(date.getTime())) return text;
  try {
    return new Intl.DateTimeFormat('zh-CN', {
      year: 'numeric',
      month: '2-digit',
      day: '2-digit',
    }).format(date);
  } catch (_error) {
    return text;
  }
}

function reviewFormatDateInZone(date, timeZone) {
  try {
    return new Intl.DateTimeFormat('zh-CN', {
      timeZone,
      year: 'numeric',
      month: '2-digit',
      day: '2-digit',
      hour: '2-digit',
      minute: '2-digit',
      second: '2-digit',
      hour12: false,
    }).format(date);
  } catch (_error) {
    return '';
  }
}

function reviewEventDateRanges(payload) {
  const rawWeeks = Array.isArray(payload?.weeks) ? payload.weeks : [];
  const rawEventDays = Array.isArray(payload?.eventDays) ? payload.eventDays : [];
  const weeks = rawWeeks
    .map((item) => ({
      weekIndex: Number(item?.weekIndex),
      label: reviewText(item?.label),
      startDate: reviewText(item?.startDate),
      endDate: reviewText(item?.endDate),
    }))
    .filter((item) => Number.isFinite(item.weekIndex) && item.startDate && item.endDate)
    .sort((left, right) => left.weekIndex - right.weekIndex || left.startDate.localeCompare(right.startDate));
  if (weeks.length) {
    return weeks.map((item) => ({
      weekIndex: item.weekIndex,
      label: item.label,
      startDate: item.startDate,
      endDate: item.endDate,
    }));
  }

  const groupedDays = new Map();
  rawEventDays.forEach((item) => {
    const weekIndex = Number(item?.weekIndex);
    const date = reviewText(item?.date);
    if (!Number.isFinite(weekIndex) || !date) return;
    const current = groupedDays.get(weekIndex) || [];
    current.push({
      label: reviewText(item?.label),
      date,
    });
    groupedDays.set(weekIndex, current);
  });
  if (!groupedDays.size) return [];
  return Array.from(groupedDays.entries())
    .sort((left, right) => left[0] - right[0])
    .map(([weekIndex, rows]) => {
      const sortedRows = rows.slice().sort((left, right) => left.date.localeCompare(right.date));
      return {
        weekIndex,
        label: sortedRows.find((item) => item.label)?.label || '',
        startDate: sortedRows[0]?.date || '',
        endDate: sortedRows[sortedRows.length - 1]?.date || '',
      };
    })
    .filter((item) => item.startDate && item.endDate);
}

function reviewEventDateSummary(payload) {
  const ranges = reviewEventDateRanges(payload);
  if (ranges.length) {
    return ranges.map((item) => {
      const prefix = ranges.length > 1
        ? (item.label || `第 ${item.weekIndex} 周`)
        : '';
      const bodyStart = reviewFormatDateOnly(item.startDate);
      const bodyEnd = reviewFormatDateOnly(item.endDate);
      const body = bodyStart && bodyEnd && bodyStart !== bodyEnd
        ? `${bodyStart} - ${bodyEnd}`
        : (bodyStart || bodyEnd);
      return [prefix, body].filter(Boolean).join(' ');
    }).filter(Boolean).join(' · ');
  }
  return reviewText(payload?.startDate || payload?.displayPublishedAt || '');
}

function reviewIsDateField(fieldKey) {
  return /(date|time|at)$/i.test(String(fieldKey || ''))
    || ['startDate', 'endDate', 'displayPublishedAt', 'publishedAt', 'recordedAt'].includes(String(fieldKey || ''));
}

function setReviewStatus(text, level = '') {
  const el = document.getElementById('review-status');
  if (!el) return;
  el.textContent = String(text || '');
  el.classList.remove('error', 'ok');
  if (level === 'error') el.classList.add('error');
  if (level === 'ok') el.classList.add('ok');
}

function getReviewAuthHeaders(json = false) {
  const headers = typeof getViewerAuthHeaders === 'function' ? { ...getViewerAuthHeaders() } : {};
  if (json) headers['Content-Type'] = 'application/json';
  return headers;
}

async function reviewApiGet(path) {
  const url = `${getRaverBffBase()}${path}`;
  const resp = await fetch(url, { headers: getReviewAuthHeaders(false) });
  const data = await resp.json().catch(() => ({}));
  if (!resp.ok) throw new Error(data.error || data.message || `请求失败 (${resp.status})`);
  return data;
}

async function reviewApiPost(path, body) {
  const url = `${getRaverBffBase()}${path}`;
  const resp = await fetch(url, {
    method: 'POST',
    headers: getReviewAuthHeaders(true),
    body: JSON.stringify(body || {}),
  });
  const data = await resp.json().catch(() => ({}));
  if (!resp.ok) throw new Error(data.error || data.message || `请求失败 (${resp.status})`);
  return data;
}

function reviewNormalizeNotes(raw) {
  if (!raw || typeof raw !== 'object' || Array.isArray(raw)) return {};
  const fields = raw.fields && typeof raw.fields === 'object' && !Array.isArray(raw.fields) ? raw.fields : null;
  const source = fields || raw;
  const out = {};
  for (const [key, value] of Object.entries(source)) {
    if (!fields && REVIEW_SYSTEM_NOTE_KEYS.has(String(key || '').trim())) continue;
    if (!fields && value && typeof value === 'object') continue;
    const note = reviewText(value);
    if (note) out[key] = note;
  }
  return out;
}

function reviewDecisionMeta(raw) {
  if (!raw || typeof raw !== 'object' || Array.isArray(raw)) return {};
  const value = raw.reviewDecision;
  if (!value || typeof value !== 'object' || Array.isArray(value)) return {};
  return value;
}

function reviewReasonCodeOptions(entityType) {
  if (String(entityType || '').trim() === 'brand') {
    return BRAND_REJECT_REASON_CODES.slice();
  }
  return [];
}

function reviewReasonCodeLabel(entityType, code) {
  const normalized = String(code || '').trim();
  if (!normalized) return '';
  const matched = reviewReasonCodeOptions(entityType).find((item) => item.code === normalized);
  return matched ? matched.label : normalized;
}

function reviewSelectedReasonCode() {
  return String(reviewPageState.reasonCode || '').trim();
}

function setReviewReasonCode(value) {
  reviewPageState.reasonCode = String(value || '').trim();
  const current = document.getElementById('review-current-reason-code');
  if (!current) return;
  const submission = reviewPageState.selectedDetail || reviewPageState.items.find((item) => item.id === reviewPageState.selectedId);
  const entityType = String(submission?.entityType || '').trim();
  const code = reviewSelectedReasonCode();
  if (!code) {
    current.style.display = 'none';
    current.textContent = '';
    return;
  }
  current.style.display = '';
  current.textContent = `当前 reason code：${reviewReasonCodeLabel(entityType, code) || code} (${code})`;
}

function reviewBuildDecisionReason(decision, submission, rawReasonText) {
  const normalizedDecision = decision === 'approved' ? 'approved' : 'rejected';
  const entityType = String(submission?.entityType || '').trim();
  const reasonText = String(rawReasonText || '').trim();
  if (normalizedDecision !== 'rejected') {
    return reasonText;
  }

  const reasonCode = reviewSelectedReasonCode();
  const codeLabel = reviewReasonCodeLabel(entityType, reasonCode);
  const codeText = reasonCode ? `[${reasonCode}] ${codeLabel || reasonCode}` : '';
  const notesSummary = buildReviewNotesSummary();
  const pieces = [codeText, reasonText, notesSummary].filter((item) => String(item || '').trim());
  return pieces.join('\n\n').trim();
}

function reviewSubmissionImageAssets(payload) {
  const rawAssets = Array.isArray(payload?.imageAssets) ? payload.imageAssets : [];
  const assets = rawAssets
    .map((item, index) => {
      if (!item || typeof item !== 'object' || Array.isArray(item)) return null;
      const url = reviewText(item.url);
      if (!/^https?:\/\//i.test(url)) return null;
      const type = reviewText(item.type || 'other').toLowerCase() || 'other';
      return {
        url,
        type,
        label: reviewText(item.label) || type.toUpperCase(),
        visibility: reviewText(item.visibility) || (type === 'proof' ? 'review_only' : 'public'),
        fileName: reviewText(item.fileName),
        mimeType: reviewText(item.mimeType),
        sort: Number.isFinite(Number(item.sort)) ? Number(item.sort) : index,
      };
    })
    .filter(Boolean);

  const seededSingles = [
    { type: 'avatar', url: reviewText(payload?.avatarUrl), label: 'Avatar', visibility: 'public' },
    { type: 'background', url: reviewText(payload?.backgroundUrl), label: 'Background', visibility: 'public' },
    { type: 'proof', url: reviewText(payload?.proofImageUrl), label: 'Proof', visibility: 'review_only' },
  ].filter((item) => /^https?:\/\//i.test(item.url));

  const deduped = new Map();
  [...assets, ...seededSingles].forEach((item, index) => {
    const key = String(item.url || '').trim().toLowerCase();
    if (!key || deduped.has(key)) return;
    deduped.set(key, {
      ...item,
      sort: Number.isFinite(Number(item.sort)) ? Number(item.sort) : index,
    });
  });
  return Array.from(deduped.values()).sort((left, right) => left.sort - right.sort);
}

function reviewSubmissionMediaGroups(submission) {
  const payload = submission?.payload && typeof submission.payload === 'object' ? submission.payload : {};
  const imageAssets = reviewSubmissionImageAssets(payload);
  const proof = imageAssets.filter((item) => item.type === 'proof' || item.visibility === 'review_only');
  const publicAssets = imageAssets.filter((item) => !proof.includes(item));
  return { imageAssets, proof, publicAssets };
}

function renderReviewMediaGallery(items, groupName, emptyText = '暂无图片') {
  if (!Array.isArray(items) || !items.length) {
    return `<div class="review-empty">${escapeHtml(emptyText)}</div>`;
  }
  return `
    <div class="review-media-grid">
      ${items.map((item, index) => `
        <button class="review-media-card" type="button" onclick="openReviewMediaLightbox('${escapeHtml(groupName)}', ${index})">
          <img class="review-media-image" src="${escapeHtml(item.url)}" alt="${escapeHtml(item.label || item.type || 'image')}">
          <div class="review-media-meta">
            <strong>${escapeHtml(item.label || item.type || 'IMAGE')}</strong>
            <span>${escapeHtml(item.visibility === 'review_only' ? '仅审核可见' : '公开素材')}</span>
          </div>
        </button>
      `).join('')}
    </div>
  `;
}

function openReviewMediaLightbox(groupName, startIdx) {
  const submission = reviewPageState.selectedDetail || reviewPageState.items.find((item) => item.id === reviewPageState.selectedId);
  if (!submission || typeof openLightboxItems !== 'function') return;
  const mediaGroups = reviewSubmissionMediaGroups(submission);
  const key = String(groupName || '').trim() === 'proof' ? 'proof' : 'publicAssets';
  const items = Array.isArray(mediaGroups[key]) ? mediaGroups[key] : [];
  if (!items.length) return;
  openLightboxItems(
    items.map((item) => ({
      url: item.url,
      label: item.label || item.type || 'IMAGE',
      type: item.type || 'other',
      downloadUrl: item.url,
      downloadName: item.fileName || '',
    })),
    startIdx,
    key === 'proof' ? 'BRAND PROOF PREVIEW' : 'BRAND MEDIA PREVIEW'
  );
}

function reviewChangeSummaryText(submission) {
  const payload = submission?.payload && typeof submission.payload === 'object' ? submission.payload : {};
  const summary = payload.changeSummary;
  if (!summary || typeof summary !== 'object' || Array.isArray(summary)) {
    return '';
  }
  return reviewText(summary.zh || summary.en || summary.ja || '');
}

function renderBrandScreeningCard(submission) {
  const reviewNotes = submission?.reviewNotes && typeof submission.reviewNotes === 'object' ? submission.reviewNotes : {};
  const screening = reviewNotes.brandScreening && typeof reviewNotes.brandScreening === 'object' && !Array.isArray(reviewNotes.brandScreening)
    ? reviewNotes.brandScreening
    : null;
  if (!screening) return '';

  const duplicateBrands = Array.isArray(screening.duplicateBrands) ? screening.duplicateBrands : [];
  const similarEvents = Array.isArray(screening.similarEvents) ? screening.similarEvents : [];
  const duplicateWarning = Boolean(screening.duplicateBrandWarning);
  const eventConflictWarning = Boolean(screening.eventNameConflictWarning);
  if (!duplicateWarning && !eventConflictWarning && !duplicateBrands.length && !similarEvents.length) {
    return '';
  }

  return `
    <section class="review-group-card review-group-warning">
      <div class="review-group-head">
        <div class="review-group-title">Brand Screening</div>
        <div class="review-group-sub">重复品牌与活动命名冲突预警</div>
      </div>
      ${duplicateWarning ? `
        <div class="review-warning-block">
          <div class="review-warning-title">疑似重复主办方</div>
          ${duplicateBrands.length ? `
            <div class="review-warning-list">
              ${duplicateBrands.map((item) => `
                <div class="review-warning-item">
                  <strong>${escapeHtml(reviewText(item.name) || reviewText(item.id) || '未命名品牌')}</strong>
                  <span>${escapeHtml([reviewText(item.city), reviewText(item.country), item.revision !== undefined && item.revision !== null ? `rev ${reviewText(item.revision)}` : ''].filter(Boolean).join(' · '))}</span>
                </div>
              `).join('')}
            </div>
          ` : '<div class="review-empty">系统检测到重复风险，但当前没有返回候选列表。</div>'}
        </div>
      ` : ''}
      ${eventConflictWarning ? `
        <div class="review-warning-block">
          <div class="review-warning-title">活动命名 / 主办方冲突预警</div>
          ${similarEvents.length ? `
            <div class="review-warning-list">
              ${similarEvents.map((item) => `
                <div class="review-warning-item">
                  <strong>${escapeHtml(reviewText(item.name) || reviewText(item.id) || '未命名活动')}</strong>
                  <span>${escapeHtml([reviewText(item.city), reviewText(item.country), reviewFormatDate(reviewText(item.startDate))].filter(Boolean).join(' · '))}</span>
                </div>
              `).join('')}
            </div>
          ` : '<div class="review-empty">系统检测到活动冲突风险，但当前没有返回候选活动。</div>'}
        </div>
      ` : ''}
    </section>
  `;
}

function renderBrandReviewInsights(submission, payload) {
  const mediaGroups = reviewSubmissionMediaGroups(submission);
  const changeSummary = reviewChangeSummaryText(submission);
  const links = Array.isArray(payload?.links) ? payload.links : [];
  return `
    <div class="review-group-stack review-group-stack-brand">
      ${changeSummary ? `
        <section class="review-group-card review-group-highlight">
          <div class="review-group-head">
            <div class="review-group-title">Change Summary</div>
            <div class="review-group-sub">提交时生成的变更摘要</div>
          </div>
          <div class="review-value-text">${escapeHtml(changeSummary)}</div>
        </section>
      ` : ''}
      ${renderBrandScreeningCard(submission)}
      <section class="review-group-card review-group-proof">
        <div class="review-group-head">
          <div class="review-group-title">Review Proof</div>
          <div class="review-group-sub">proof 图片仅在审核端可见</div>
        </div>
        ${renderReviewMediaGallery(mediaGroups.proof, 'proof', '当前没有 proof 图片')}
      </section>
      <section class="review-group-card review-group-media">
        <div class="review-group-head">
          <div class="review-group-title">Public Media</div>
          <div class="review-group-sub">头像 / 背景 / 海报 / 公开补充图</div>
        </div>
        ${renderReviewMediaGallery(mediaGroups.publicAssets, 'public', '当前没有公开素材')}
      </section>
      <section class="review-group-card review-group-links">
        <div class="review-group-head">
          <div class="review-group-title">Official Links Snapshot</div>
          <div class="review-group-sub">帮助审核员快速核验来源</div>
        </div>
        <div class="review-field-grid review-field-grid-single">
          ${renderReviewField('officialWebsite', '官网', payload?.officialWebsite)}
          ${renderReviewField('links', '补充链接', links)}
          ${renderReviewField('rightsConfirmed', '版权声明确认', payload?.rightsConfirmed)}
          ${renderReviewField('identityConfirmed', '主体声明确认', payload?.identityConfirmed)}
        </div>
      </section>
    </div>
  `;
}

function setReviewPendingCount(count, countsByType = {}) {
  reviewPageState.pendingCount = Math.max(0, Number(count || 0) || 0);
  reviewPageState.pendingCountsByType = countsByType && typeof countsByType === 'object' ? countsByType : {};
  syncReviewPendingBadge();
  renderReviewSourceStats();
}

function syncReviewPendingBadge() {
  const badge = document.getElementById('review-pending-badge');
  if (!badge) return;
  const count = Math.max(0, Number(reviewPageState.pendingCount || 0) || 0);
  badge.textContent = count > 99 ? '99+' : String(count);
  badge.style.display = count > 0 ? 'inline-flex' : 'none';
  badge.setAttribute('aria-label', `${count} 条待审核`);
}

function renderReviewSourceStats() {
  const wrap = document.getElementById('review-source-stats');
  if (!wrap) return;
  const countsByType = reviewPageState.pendingCountsByType && typeof reviewPageState.pendingCountsByType === 'object'
    ? reviewPageState.pendingCountsByType
    : {};
  const djEnrichmentCount = Math.max(0, Number(countsByType.dj_enrichment || 0) || 0);
  const djBindingReviewCount = Math.max(0, Number(countsByType.dj_binding_review || 0) || 0);
  let contentSubmissionCount = 0;
  for (const [key, value] of Object.entries(countsByType)) {
    if (key === 'dj_enrichment' || key === 'dj_binding_review') continue;
    contentSubmissionCount += Math.max(0, Number(value || 0) || 0);
  }
  wrap.innerHTML = [
    { label: 'Content Submission', source: 'content_submission', count: contentSubmissionCount, active: reviewPageState.sourceFilter === 'content_submission' },
    { label: 'DJ Enrichment', source: 'dj_enrichment', count: djEnrichmentCount, active: reviewPageState.sourceFilter === 'dj_enrichment' },
    { label: 'DJ Binding Review', source: 'dj_binding_review', count: djBindingReviewCount, active: reviewPageState.sourceFilter === 'dj_binding_review' },
  ].map((item) => `
    <button class="review-type-item review-source-chip ${item.active ? 'active' : ''}" type="button" onclick="setReviewSourceFilter('${escapeHtml(item.source)}')">
      <span>${escapeHtml(item.label)}</span>
      <b>${escapeHtml(item.count > 99 ? '99+' : String(item.count || 0))}</b>
    </button>
  `).join('');
}

async function refreshReviewPendingCount() {
  const headers = getReviewAuthHeaders(false);
  if (!headers.Authorization) {
    setReviewPendingCount(0, {});
    return;
  }
  try {
    const [pendingSubmissionData, processingSubmissionData, reviewingSubmissionData, enrichmentData, bindingReviewData] = await Promise.all([
      reviewApiGet('/api/admin/v1/content-submissions?status=pending&limit=200'),
      reviewApiGet('/api/admin/v1/content-submissions?status=processing&limit=200'),
      reviewApiGet('/api/admin/v1/content-submissions?status=reviewing&limit=200'),
      reviewApiGet('/api/admin/v1/dj-enrichment/results?applyStatus=pending_review&limit=1'),
      reviewApiGet('/api/admin/v1/dj-event-binding-review/jobs?status=pending&page=1&limit=1'),
    ]);
    const items = mergeReviewItemsById([
      pendingSubmissionData.items,
      processingSubmissionData.items,
      reviewingSubmissionData.items,
    ]);
    const countsByType = {};
    for (const item of items) {
      const type = String(item?.entityType || '').trim();
      if (!type) continue;
      countsByType[type] = (countsByType[type] || 0) + 1;
    }
    countsByType.dj_enrichment = Math.max(0, Number(enrichmentData.total ?? 0) || 0);
    countsByType.dj_binding_review = Math.max(0, Number(bindingReviewData?.pagination?.total ?? 0) || 0);
    const total = items.length
      + Math.max(0, Number(enrichmentData.total ?? 0) || 0)
      + Math.max(0, Number(bindingReviewData?.pagination?.total ?? 0) || 0);
    setReviewPendingCount(total, countsByType);
  } catch (_error) {
    syncReviewPendingBadge();
  }
}

function reviewCountByType(type) {
  if (reviewPageState.sourceFilter === 'dj_binding_review') {
    const items = Array.isArray(reviewPageState.items) ? reviewPageState.items : [];
    if (!type || type === 'dj_binding_review') return items.length;
    return 0;
  }
  if (reviewPageState.sourceFilter === 'dj_enrichment') {
    const items = Array.isArray(reviewPageState.items) ? reviewPageState.items : [];
    if (!type) return items.length;
    return items.filter((item) => (item.entityType || 'dj_enrichment') === type).length;
  }
  if (reviewPageState.statusFilter === 'pending') {
    return type ? (reviewPageState.pendingCountsByType[type] || 0) : reviewPageState.pendingCount;
  }
  const items = Array.isArray(reviewPageState.items) ? reviewPageState.items : [];
  if (!type) return items.length;
  return items.filter((item) => item.entityType === type).length;
}

function getReviewPageSize() {
  const value = Math.max(1, Number(reviewPageState.pageSize || 50) || 50);
  return Math.min(value, 200);
}

function getReviewTotal() {
  const total = Number(reviewPageState.total);
  return Number.isFinite(total) && total >= 0 ? Math.floor(total) : (Array.isArray(reviewPageState.items) ? reviewPageState.items.length : 0);
}

function getReviewPageCount() {
  return Math.max(1, Math.ceil(getReviewTotal() / getReviewPageSize()));
}

function getActionableMatchingCount(mode) {
  const selectedItems = selectedReviewItems();
  if (reviewPageState.selectedAllMatching) {
    return selectedItems.length;
  }
  if (mode === 'approve') return selectedItems.filter(canApproveReviewItem).length;
  if (mode === 'retry') return selectedItems.filter(canRetryReviewItem).length;
  return selectedItems.length;
}

function resetReviewSelection() {
  reviewPageState.selectedIds = new Set();
  reviewPageState.selectedAllMatching = false;
  reviewPageState.selectedAllMatchingMode = '';
  if (typeof resetDjBindingCandidateSelection === 'function') {
    resetDjBindingCandidateSelection();
  }
}

function selectedReviewIds() {
  return reviewPageState.selectedIds instanceof Set ? Array.from(reviewPageState.selectedIds) : [];
}

function selectedReviewItems() {
  if (reviewPageState.selectedAllMatching) {
    const items = selectableReviewItems();
    if (reviewPageState.selectedAllMatchingMode === 'approve') return items.filter(canApproveReviewItem);
    if (reviewPageState.selectedAllMatchingMode === 'retry') return items.filter(canRetryReviewItem);
    return items;
  }
  const ids = new Set(selectedReviewIds());
  const items = Array.isArray(reviewPageState.items) ? reviewPageState.items : [];
  return items.filter((item) => ids.has(String(item?.id || '')));
}

function isReviewItemSelectable(item) {
  if (!item) return false;
  if (reviewPageState.sourceFilter === 'dj_binding_review') return false;
  if (reviewPageState.sourceFilter === 'dj_enrichment') return item.applyStatus === 'pending_review';
  return isContentSubmissionReviewableStatus(item.status);
}

function canApproveReviewItem(item) {
  if (reviewPageState.sourceFilter === 'dj_binding_review') return false;
  if (!isReviewItemSelectable(item)) return false;
  if (reviewPageState.sourceFilter === 'dj_enrichment') {
    return (item.processingStatus || item.status) === 'completed';
  }
  return true;
}

function canRetryReviewItem(item) {
  if (reviewPageState.sourceFilter !== 'dj_enrichment') return false;
  return (item.processingStatus || item.status) === 'failed' && !!String(item?.djId || '').trim();
}

function selectableReviewItems() {
  const items = Array.isArray(reviewPageState.items) ? reviewPageState.items : [];
  return items.filter(isReviewItemSelectable);
}

function isReviewItemSelected(id) {
  return reviewPageState.selectedIds instanceof Set && reviewPageState.selectedIds.has(String(id || ''));
}

function toggleReviewSelection(id, checked) {
  const normalizedId = String(id || '').trim();
  if (!normalizedId) return;
  if (!(reviewPageState.selectedIds instanceof Set)) reviewPageState.selectedIds = new Set();
  reviewPageState.selectedAllMatching = false;
  reviewPageState.selectedAllMatchingMode = '';
  if (checked) reviewPageState.selectedIds.add(normalizedId);
  else reviewPageState.selectedIds.delete(normalizedId);
  renderReviewPage();
}

function toggleReviewSelectionByToken(idToken, checked) {
  toggleReviewSelection(decodeURIComponent(String(idToken || '')), checked);
}

function toggleReviewSelectCurrentPage(checked) {
  if (!(reviewPageState.selectedIds instanceof Set)) reviewPageState.selectedIds = new Set();
  reviewPageState.selectedAllMatching = false;
  reviewPageState.selectedAllMatchingMode = '';
  for (const item of selectableReviewItems()) {
    const id = String(item?.id || '').trim();
    if (!id) continue;
    if (checked) reviewPageState.selectedIds.add(id);
    else reviewPageState.selectedIds.delete(id);
  }
  renderReviewPage();
}

function selectAllMatchingReviewItems(mode = '') {
  reviewPageState.selectedAllMatching = true;
  reviewPageState.selectedAllMatchingMode = String(mode || '').trim();
  reviewPageState.selectedIds = new Set();
  renderReviewPage();
}

function reviewFieldDefinitions(entityType, payload) {
  const common = {
    event: [
      ['name', '活动名称'], ['nameI18n', '活动名称双语'], ['startDate', '开始日期'], ['endDate', '结束日期'],
      ['country', '国家'], ['countryI18n', '国家双语'], ['city', '城市'], ['cityI18n', '城市双语'],
      ['detailAddressZh', '中文地址'], ['detailAddressEn', '英文地址'], ['locationPoint', '地图定位'],
      ['eventType', '活动类型'], ['lineup', 'Lineup'], ['timetable', 'Timetable'], ['images', '图片资源'],
      ['ticketUrl', '票务链接'], ['officialWebsite', '官网'], ['description', '介绍'],
    ],
    dj: [
      ['name', 'DJ 名称'], ['aliases', '别名'], ['genres', '风格'], ['country', '国家'], ['countryI18n', '国家双语'],
      ['bio', '简介'], ['avatarUrl', '头像'], ['website', '官网'], ['spotifyId', 'Spotify ID'],
      ['instagramUrl', 'Instagram'], ['soundcloudUrl', 'SoundCloud'], ['youtubeUrl', 'YouTube'],
    ],
    news: [
      ['title', '标题'], ['category', '分类'], ['source', '来源'], ['summary', '摘要'], ['content', '正文'],
      ['images', '图片'], ['link', '外链'], ['boundDjIDs', '关联 DJ'], ['boundBrandIDs', '关联 Brand'], ['boundEventIDs', '关联 Event'],
      ['displayPublishedAt', '展示发布时间'],
    ],
    set: [
      ['title', 'Set 标题'], ['djId', '关联 DJ'], ['videoUrl', '视频链接'], ['thumbnailUrl', '封面'],
      ['description', '介绍'], ['recordedAt', '录制时间'], ['eventId', '关联 Event'], ['tracklist', 'Tracklist'],
    ],
    brand: [
      ['name', '品牌名称'], ['nameI18n', '品牌名称双语'], ['aliases', '别名'], ['country', '国家'], ['city', '城市'],
      ['foundedYear', '创立年份'], ['tagline', '标语'], ['introduction', '介绍'], ['avatarUrl', '头像'],
      ['backgroundUrl', '背景图'], ['officialWebsite', '官网'], ['links', '外链'],
    ],
    label: [
      ['name', '厂牌名称'], ['slug', 'Slug'], ['profileUrl', '主页 URL'], ['nation', '国家/地区'], ['genres', '风格'],
      ['genresPreview', '风格预览'], ['introduction', '介绍'], ['avatarUrl', '头像'], ['backgroundUrl', '背景图'],
      ['officialWebsiteUrl', '官网'], ['soundcloudUrl', 'SoundCloud'],
    ],
    id: [
      ['songName', 'ID 名称'], ['title', '标题'], ['artistName', '艺人'], ['audioUrl', '音频'], ['videoUrl', '视频'],
      ['eventName', '关联活动名'], ['eventId', '关联 Event'], ['djNames', '关联 DJ 名称'], ['djIds', '关联 DJ'],
      ['content', '原始内容'], ['images', '图片'],
    ],
    rating: [
      ['name', '打分名称'], ['title', '标题'], ['ratingEventId', '打分事件'], ['eventId', '关联 Event'],
      ['unitName', '项目名称'], ['category', '分类'], ['description', '介绍'], ['coverImageUrl', '封面'],
      ['minScore', '最低分'], ['maxScore', '最高分'],
    ],
  };
  const rows = [...(common[entityType] || [])];
  for (const key of Object.keys(payload || {})) {
    if (!rows.some(([field]) => field === key)) rows.push([key, key]);
  }
  return rows;
}

function reviewRenderValue(value, fieldKey = '') {
  if (value === null || value === undefined || value === '') return '<span class="review-empty">未填写</span>';
  if (reviewIsDateField(fieldKey)) {
    const text = reviewText(value);
    const date = new Date(text);
    if (!Number.isNaN(date.getTime())) {
      return `
        <div class="review-date-value">
          <div class="review-date-primary">${escapeHtml(text)}</div>
          <div class="review-date-row"><span>UTC</span><strong>${escapeHtml(reviewFormatDateInZone(date, 'UTC'))}</strong></div>
          <div class="review-date-row"><span>北京时间</span><strong>${escapeHtml(reviewFormatDateInZone(date, 'Asia/Shanghai'))}</strong></div>
        </div>
      `;
    }
  }
  if (Array.isArray(value)) {
    if (!value.length) return '<span class="review-empty">空列表</span>';
    const primitive = value.every((item) => item === null || ['string', 'number', 'boolean'].includes(typeof item));
    if (primitive) {
      return `<div class="review-chip-row">${value.map((item) => `<span class="review-chip">${escapeHtml(reviewText(item))}</span>`).join('')}</div>`;
    }
  }
  if (typeof value === 'object') {
    return `<pre class="review-object">${escapeHtml(JSON.stringify(value, null, 2))}</pre>`;
  }
  const text = reviewText(value);
  if (/^https?:\/\//i.test(text)) {
    const isImage = /\.(png|jpe?g|webp|gif|avif)(\?|#|$)/i.test(text);
    return `${isImage ? `<img class="review-field-image" src="${escapeHtml(text)}" alt="">` : ''}<a class="review-link" href="${escapeHtml(text)}" target="_blank" rel="noreferrer">${escapeHtml(text)}</a>`;
  }
  return `<div class="review-value-text">${escapeHtml(text)}</div>`;
}

function reviewFieldNote(fieldKey) {
  return reviewPageState.reviewNotes[fieldKey] || '';
}

function isReviewFieldExpanded(fieldKey) {
  return reviewPageState.expandedNoteFields instanceof Set && reviewPageState.expandedNoteFields.has(fieldKey);
}

function renderReviewField(fieldKey, label, value) {
  const note = reviewFieldNote(fieldKey);
  const fieldToken = encodeURIComponent(fieldKey);
  const expanded = isReviewFieldExpanded(fieldKey) || !!note;
  return `
    <section class="review-field ${expanded ? 'note-open' : ''} ${note ? 'has-note' : ''}" data-field="${escapeHtml(fieldKey)}">
      <div class="review-field-head">
        <div>
          <div class="review-field-label">${escapeHtml(label)}</div>
          <div class="review-field-key">${escapeHtml(fieldKey)}</div>
        </div>
        <button class="review-field-note-btn" type="button" onclick="quoteReviewFieldByToken('${fieldToken}')">${note ? '已引用' : '引用'}</button>
      </div>
      <div class="review-field-body">${reviewRenderValue(value, fieldKey)}</div>
      ${expanded ? `
        <textarea
          class="review-field-note"
          data-review-note-field="${escapeHtml(fieldKey)}"
          placeholder="写这个字段的修改意见，例如：城市中文名建议补成「上海」"
          oninput="updateReviewFieldNoteByToken('${fieldToken}', this.value)"
        >${escapeHtml(note)}</textarea>
      ` : ''}
    </section>
  `;
}

function renderReviewPreview(submission) {
  if (reviewPageState.sourceFilter === 'dj_binding_review' && typeof renderDjBindingReviewPreview === 'function') {
    return renderDjBindingReviewPreview(submission);
  }
  if (reviewPageState.sourceFilter === 'dj_enrichment') {
    return renderDjEnrichmentPreview(submission);
  }
  const payload = submission?.payload && typeof submission.payload === 'object' ? submission.payload : {};
  const entityType = String(submission?.entityType || '');
  const fields = reviewFieldDefinitions(entityType, payload);
  const imageKeys = ['coverImageUrl', 'coverImageURL', 'avatarUrl', 'backgroundUrl', 'thumbnailUrl', 'imageUrl'];
  const heroUrl = imageKeys.map((key) => reviewText(payload[key])).find((url) => /^https?:\/\//i.test(url))
    || reviewArray(payload.images)[0]
    || '';
  const title = reviewText(submission?.title) || reviewText(payload.name) || reviewText(payload.title) || '未命名内容';
  const eventDateSummary = entityType === 'event' ? reviewEventDateSummary(payload) : '';
  const subtitle = [
    REVIEW_ENTITY_LABELS[entityType] || entityType,
    reviewText(payload.city || payload.country || payload.source || payload.category),
    eventDateSummary || reviewText(payload.startDate || payload.displayPublishedAt),
  ].filter(Boolean).join(' · ');
  return `
    <article class="review-rendered-card review-rendered-${escapeHtml(entityType)}">
      ${heroUrl ? `<div class="review-hero"><img src="${escapeHtml(heroUrl)}" alt=""></div>` : ''}
      <div class="review-rendered-head">
        <div class="review-rendered-kicker">${escapeHtml(subtitle || '用户共建提交')}</div>
        <h2>${escapeHtml(title)}</h2>
        <div class="review-rendered-meta">
          <span>提交人：${escapeHtml(submission?.submitter?.displayName || submission?.submitter?.username || submission?.submitterId || '—')}</span>
          <span>提交时间：${escapeHtml(reviewFormatDate(submission?.createdAt))}</span>
          <span>状态：${escapeHtml(REVIEW_STATUS_LABELS[submission?.status] || submission?.status || '—')}</span>
        </div>
      </div>
      ${entityType === 'brand' ? renderBrandReviewInsights(submission, payload) : ''}
      <div class="review-field-grid">
        ${fields.map(([field, label]) => renderReviewField(field, label, payload[field])).join('')}
      </div>
    </article>
  `;
}

function renderDjEnrichmentPreview(result) {
  const normalized = result?.normalizedResult && typeof result.normalizedResult === 'object' ? result.normalizedResult : {};
  const input = normalized?.input && typeof normalized.input === 'object' ? normalized.input : {};
  const resolution = normalized?.resolution && typeof normalized.resolution === 'object' ? normalized.resolution : {};
  const texts = normalized?.texts && typeof normalized.texts === 'object' ? normalized.texts : {};
  const links = normalized?.links && typeof normalized.links === 'object' ? normalized.links : {};
  const provenance = normalized?.provenance && typeof normalized.provenance === 'object' ? normalized.provenance : {};
  const styles = Array.isArray(texts?.styles) ? texts.styles : [];
  const sourceRows = Array.isArray(provenance?.sourcesUsed) ? provenance.sourcesUsed : [];
  const currentDj = result?.dj && typeof result.dj === 'object' ? result.dj : null;
  const applySummary = result?.applySummary && typeof result.applySummary === 'object' ? result.applySummary : null;
  const inputFields = [
    ['input.name', '输入 DJ 名称', input?.name],
    ['input.bio', '输入简介', input?.bio],
    ['input.country', '输入国家', input?.country],
    ['input.spotifyUrl', '输入 Spotify', input?.spotifyUrl],
    ['input.source', '输入来源链接', input?.source],
  ];
  const resolutionFields = [
    ['resolution.matchedName', '匹配结果', resolution?.matchedName],
    ['resolution.isSamePersonConfident', '是否确认同人', resolution?.isSamePersonConfident],
    ['resolution.samePersonConfidence', '同人置信度', resolution?.samePersonConfidence],
    ['resolution.isElectronicDjConfident', '是否确认电子音乐 DJ', resolution?.isElectronicDjConfident],
    ['resolution.electronicDjConfidence', '电子音乐置信度', resolution?.electronicDjConfidence],
    ['resolution.shouldApplyGenres', '是否建议写入风格', resolution?.shouldApplyGenres],
    ['resolution.reasoningShort', '简短结论', resolution?.reasoningShort],
  ];
  const candidateFields = [
    ['texts.bio.zh', '候选简介(中文)', texts?.bio?.zh],
    ['texts.bio.en', '候选简介(英文)', texts?.bio?.en],
    ['texts.bio.ja', '候选简介(日文)', texts?.bio?.ja],
    ['texts.country.zh', '候选国家(中文)', texts?.country?.zh],
    ['texts.country.en', '候选国家(英文)', texts?.country?.en],
    ['texts.country.ja', '候选国家(日文)', texts?.country?.ja],
    ['texts.chineseAlias', '候选中文别名', texts?.chineseAlias],
    ['texts.styles', '候选风格列表', styles],
    ['links.officialWebsite', '官网候选', links?.officialWebsite],
    ['links.soundcloud', 'SoundCloud 候选', links?.soundcloud],
    ['links.instagram', 'Instagram 候选', links?.instagram],
    ['links.facebook', 'Facebook 候选', links?.facebook],
    ['links.twitter', 'Twitter 候选', links?.twitter],
    ['links.youtube', 'YouTube 候选', links?.youtube],
    ['links.spotify', 'Spotify 候选', links?.spotify],
    ['links.netease', '网易云候选', links?.netease],
    ['links.qqMusic', 'QQ 音乐候选', links?.qqMusic],
    ['links.wikipedia', 'Wikipedia 候选', links?.wikipedia],
    ['provenance.genrePrimarySource', '风格主来源', provenance?.genrePrimarySource],
    ['provenance.sourcesUsed', '引用来源', sourceRows],
    ['result.errorMessage', '处理错误', result?.errorMessage],
    ['result.reviewReason', '审核理由', result?.reviewReason],
    ['result.applySummary', '应用结果摘要', applySummary],
    ['currentDj', '当前数据库 DJ', currentDj],
  ];
  const rawSections = [
    ['normalizedResult', 'Normalized Result JSON', result?.normalizedResult],
    ['cozeRawResponse', 'Coze Raw Response JSON', result?.cozeRawResponse],
  ];

  const renderFieldGroup = (title, subtitle, rows, extraClass = '') => `
    <section class="review-group-card ${extraClass}">
      <div class="review-group-head">
        <div class="review-group-title">${escapeHtml(title)}</div>
        ${subtitle ? `<div class="review-group-sub">${escapeHtml(subtitle)}</div>` : ''}
      </div>
      <div class="review-field-grid">
        ${rows.map(([fieldKey, label, value]) => renderReviewField(fieldKey, label, value)).join('')}
      </div>
    </section>
  `;

  return `
    <article class="review-rendered-card review-rendered-dj">
      <div class="review-rendered-head">
        <div class="review-rendered-kicker">DJ Enrichment Result</div>
        <h2>${escapeHtml(result?.inputName || input?.name || 'Unnamed DJ')}</h2>
        <div class="review-rendered-meta">
          <span>任务：${escapeHtml(result?.job?.id || '—')}</span>
          <span>处理状态：${escapeHtml(result?.status || '—')}</span>
          <span>审核状态：${escapeHtml(REVIEW_STATUS_LABELS[result?.applyStatus === 'approved' ? 'approved' : result?.applyStatus === 'rejected' ? 'rejected' : 'pending'] || result?.applyStatus || 'pending')}</span>
          <span>生成时间：${escapeHtml(reviewFormatDate(result?.createdAt))}</span>
        </div>
      </div>
      <div class="review-group-stack">
        ${renderFieldGroup('输入信息', '提交到 enrichment 的原始输入', inputFields, 'review-group-input')}
        ${renderFieldGroup('判断结论', '匹配和判定相关的核心结论', resolutionFields, 'review-group-resolution')}
        ${renderFieldGroup('候选输出与上下文', '候选简介、链接、来源、当前 DJ 与应用摘要', candidateFields, 'review-group-candidates')}
        ${renderFieldGroup('原始 JSON', '保留结构化返回原文，便于排查与复核', rawSections, 'review-group-raw')}
      </div>
    </article>
  `;
}

function renderReviewList() {
  const wrap = document.getElementById('review-list');
  if (!wrap) return;
  const items = Array.isArray(reviewPageState.items) ? reviewPageState.items : [];
  if (!items.length) {
    wrap.innerHTML = '<div class="review-list-empty">暂无审核提交</div>';
    return;
  }
  wrap.innerHTML = items.map((item) => `
    <div class="review-list-row ${item.id === reviewPageState.selectedId ? 'active' : ''} ${isReviewItemSelected(item.id) ? 'selected' : ''}">
      <label class="review-list-check" title="${isReviewItemSelectable(item) ? '选择此条' : '当前状态不可批量审核'}">
        <input
          type="checkbox"
          ${isReviewItemSelected(item.id) ? 'checked' : ''}
          ${isReviewItemSelectable(item) ? '' : 'disabled'}
          onchange="toggleReviewSelectionByToken('${encodeURIComponent(item.id)}', this.checked)"
        >
      </label>
      <button class="review-list-item" type="button" onclick="selectReviewSubmission('${escapeHtml(item.id)}')">
        <span class="review-list-type">${escapeHtml(REVIEW_ENTITY_LABELS[item.entityType || 'dj_enrichment'] || item.entityType || 'dj_enrichment')}</span>
        <strong>${escapeHtml(item.title || item.inputName || '未命名内容')}</strong>
        <span>${escapeHtml([
          item.submitter?.displayName || item.submitter?.username || item.submitterId || item.job?.requestedById || '—',
          item.entityType === 'event'
            ? reviewEventDateSummary(item?.payload && typeof item.payload === 'object' ? item.payload : {})
            : '',
        ].filter(Boolean).join(' · '))}</span>
        <small>
          ${reviewPageState.sourceFilter === 'dj_enrichment' ? `<b>${escapeHtml(REVIEW_PROCESSING_STATUS_LABELS[item.processingStatus || item.status] || item.processingStatus || item.status || '—')}</b> · ` : ''}
          ${escapeHtml(reviewFormatDate(item.createdAt))}
        </small>
      </button>
    </div>
  `).join('');
}

function renderReviewBulkBar() {
  const wrap = document.getElementById('review-bulk-bar');
  if (!wrap) return;
  if (reviewPageState.sourceFilter === 'dj_binding_review') {
    const total = getReviewTotal();
    wrap.innerHTML = `
      <div class="review-bulk-meta">当前共有 ${escapeHtml(String(total))} 个 DJ 绑定审核任务，请在右侧处理选中的任务。</div>
    `;
    return;
  }
  const selectable = selectableReviewItems();
  const selectedIds = selectedReviewIds();
  const selectedOnPage = selectable.filter((item) => isReviewItemSelected(item.id)).length;
  const selectedItems = selectedReviewItems();
  const allChecked = selectable.length > 0 && selectedOnPage === selectable.length;
  const selectedCount = reviewPageState.selectedAllMatching
    ? getActionableMatchingCount(reviewPageState.selectedAllMatchingMode)
    : selectedIds.length;
  const disabled = selectedCount === 0 || reviewPageState.bulkSaving || reviewPageState.saving;
  const approveDisabled = disabled || selectedItems.some((item) => !canApproveReviewItem(item));
  const retryDisabled = disabled || selectedItems.some((item) => !canRetryReviewItem(item));
  wrap.innerHTML = `
    <label class="review-select-page">
      <input type="checkbox" ${allChecked ? 'checked' : ''} ${selectable.length ? '' : 'disabled'} onchange="toggleReviewSelectCurrentPage(this.checked)">
      <span>本页全选</span>
    </label>
    ${reviewPageState.sourceFilter === 'dj_enrichment' && reviewPageState.statusFilter === 'pending'
      ? `
        <button class="review-tool-btn" type="button" ${reviewPageState.bulkSaving || reviewPageState.saving ? 'disabled' : ''} onclick="selectAllMatchingReviewItems('approve')">全选全部可通过结果</button>
        <button class="review-tool-btn" type="button" ${reviewPageState.bulkSaving || reviewPageState.saving ? 'disabled' : ''} onclick="selectAllMatchingReviewItems('retry')">全选全部可重跑结果</button>
      `
      : ''}
    <div class="review-bulk-meta">${escapeHtml(String(selectedCount))}${reviewPageState.selectedAllMatching ? ` selected(all ${escapeHtml(reviewPageState.selectedAllMatchingMode || 'matching')})` : ' selected'}</div>
    ${reviewPageState.sourceFilter === 'dj_enrichment' ? `<button class="review-tool-btn review-bulk-retry" type="button" ${retryDisabled ? 'disabled' : ''} onclick="retrySelectedDjEnrichment()">重跑 Coze</button>` : ''}
    <button class="review-tool-btn review-bulk-approve" type="button" ${approveDisabled ? 'disabled' : ''} onclick="submitBulkReviewDecision('approved')">批量通过</button>
    <button class="review-tool-btn review-bulk-reject" type="button" ${disabled ? 'disabled' : ''} onclick="submitBulkReviewDecision('rejected')">批量不通过</button>
  `;
}

function renderReviewPagination() {
  const wrap = document.getElementById('review-pagination');
  if (!wrap) return;
  const total = getReviewTotal();
  const pageSize = getReviewPageSize();
  const pageCount = getReviewPageCount();
  const page = Math.min(Math.max(1, Number(reviewPageState.page || 1) || 1), pageCount);
  const from = total ? (page - 1) * pageSize + 1 : 0;
  const to = total ? Math.min(total, page * pageSize) : 0;
  wrap.innerHTML = `
    <button class="review-tool-btn" type="button" ${page <= 1 ? 'disabled' : ''} onclick="setReviewPage(${page - 1})">上一页</button>
    <span>${escapeHtml(String(from))}-${escapeHtml(String(to))} / ${escapeHtml(String(total))} · ${escapeHtml(String(page))}/${escapeHtml(String(pageCount))}</span>
    <button class="review-tool-btn" type="button" ${page >= pageCount ? 'disabled' : ''} onclick="setReviewPage(${page + 1})">下一页</button>
  `;
}

function renderReviewTypeNav() {
  const wrap = document.getElementById('review-type-nav');
  if (!wrap) return;
  if (reviewPageState.sourceFilter === 'dj_binding_review') {
    const total = reviewCountByType('dj_binding_review');
    wrap.innerHTML = `
      <button class="review-type-item active" type="button">
        <span>全部任务</span>
        <b>${escapeHtml(total > 99 ? '99+' : String(total || 0))}</b>
      </button>
    `;
    return;
  }
  const active = reviewPageState.entityFilter || '';
  const allCount = reviewCountByType('');
  const rows = [
    { type: '', label: '全部', count: allCount },
    ...REVIEW_ENTITY_ORDER.map((type) => ({
      type,
      label: REVIEW_ENTITY_LABELS[type] || type,
      count: reviewCountByType(type),
    })),
  ];
  wrap.innerHTML = rows.map((item) => `
    <button class="review-type-item ${active === item.type ? 'active' : ''}" type="button" onclick="setReviewEntityFilter('${escapeHtml(item.type)}')">
      <span>${escapeHtml(item.label)}</span>
      <b>${escapeHtml(item.count > 99 ? '99+' : String(item.count || 0))}</b>
    </button>
  `).join('');
}

function renderReviewDetail() {
  const wrap = document.getElementById('review-detail');
  if (!wrap) return;
  const submission = reviewPageState.selectedDetail || reviewPageState.items.find((item) => item.id === reviewPageState.selectedId);
  if (!submission) {
    wrap.innerHTML = reviewPageState.sourceFilter === 'dj_binding_review'
      ? '<div class="review-detail-empty">从左侧选择一个 DJ 绑定审核任务开始处理。</div>'
      : '<div class="review-detail-empty">从左侧选择一条用户提交内容开始审核。</div>';
    return;
  }
  if (reviewPageState.sourceFilter === 'dj_binding_review') {
    wrap.innerHTML = renderReviewPreview(submission);
    return;
  }
  const isPending = reviewPageState.sourceFilter === 'dj_enrichment'
    ? submission.applyStatus === 'pending_review'
    : isContentSubmissionReviewableStatus(submission.status);
  const canApprove = canApproveReviewItem(submission);
  const entityType = String(submission?.entityType || '').trim();
  const reasonCodeOptions = reviewReasonCodeOptions(entityType);
  const existingDecisionMeta = reviewDecisionMeta(submission?.reviewNotes);
  const selectedReasonCode = reviewSelectedReasonCode() || reviewText(existingDecisionMeta.reasonCode);
  wrap.innerHTML = `
    ${renderReviewPreview(submission)}
    <section class="review-decision-panel">
      <div class="review-decision-head">
        <div>
          <div class="review-decision-title">审核结论</div>
          <div class="review-decision-sub">字段意见会跟随最终原因一起保存并反馈给用户。</div>
        </div>
        <button class="review-tool-btn" type="button" onclick="copyReviewNotesToReason()">汇总字段意见</button>
      </div>
      ${reasonCodeOptions.length ? `
        <label class="review-decision-select-wrap">
          <span class="review-decision-select-label">驳回 Reason Code</span>
          <select
            class="review-select review-decision-select"
            id="review-reason-code-select"
            onchange="setReviewReasonCode(this.value)"
            ${isPending ? '' : 'disabled'}
          >
            <option value="">请选择 reason code</option>
            ${reasonCodeOptions.map((item) => `
              <option value="${escapeHtml(item.code)}" ${selectedReasonCode === item.code ? 'selected' : ''}>${escapeHtml(item.label)} (${escapeHtml(item.code)})</option>
            `).join('')}
          </select>
        </label>
      ` : ''}
      <textarea
        class="review-reason-input"
        id="review-reason-input"
        placeholder="填写审核通过/不通过原因。拒绝时建议说明需要修改的字段。"
        oninput="reviewPageState.reason = this.value"
      >${escapeHtml(reviewPageState.reason || submission.reviewReason || '')}</textarea>
      <div class="review-decision-actions">
        <button class="review-approve-btn" type="button" ${canApprove ? '' : 'disabled'} onclick="submitReviewDecision('approved')">审核通过并入库</button>
        <button class="review-reject-btn" type="button" ${isPending ? '' : 'disabled'} onclick="submitReviewDecision('rejected')">审核不通过</button>
      </div>
      ${submission.createdEntityId ? `<div class="review-created-id">正式内容 ID：${escapeHtml(submission.createdEntityId)}</div>` : ''}
      <div class="review-created-id" id="review-current-reason-code" ${selectedReasonCode ? '' : 'style="display:none"'}>
        ${selectedReasonCode ? `当前 reason code：${escapeHtml(reviewReasonCodeLabel(entityType, selectedReasonCode) || selectedReasonCode)} (${escapeHtml(selectedReasonCode)})` : ''}
      </div>
      ${!isPending ? `<div class="review-final-reason">最终原因：${escapeHtml(submission.reviewReason || '未填写')}</div>` : ''}
    </section>
  `;
}

function renderReviewPage() {
  const processingSelect = document.getElementById('review-processing-status-select');
  const statusSelect = document.getElementById('review-status-select');
  if (statusSelect) {
    if (reviewPageState.sourceFilter === 'dj_binding_review') {
      const rows = [
        ['pending', '待处理'],
        ['partially_applied', '部分已绑定'],
        ['applied', '已完成'],
        ['dismissed', '已忽略'],
        ['', '全部状态'],
      ];
      statusSelect.innerHTML = rows.map(([value, label]) => `<option value="${escapeHtml(value)}">${escapeHtml(label)}</option>`).join('');
      statusSelect.value = reviewPageState.statusFilter || 'pending';
    } else {
      const rows = reviewPageState.sourceFilter === 'dj_enrichment'
        ? [
          ['pending', '待审核'],
          ['approved', '已通过'],
          ['rejected', '未通过'],
          ['', '全部状态'],
        ]
        : [
          ['pending', '待审核/处理中'],
          ['reviewing', '仅审核中'],
          ['processing', '仅处理中'],
          ['approved', '已通过'],
          ['rejected', '未通过'],
          ['', '全部状态'],
        ];
      statusSelect.innerHTML = rows.map(([value, label]) => `<option value="${escapeHtml(value)}">${escapeHtml(label)}</option>`).join('');
      statusSelect.value = reviewPageState.statusFilter || 'pending';
    }
  }
  if (processingSelect) {
    processingSelect.style.display = reviewPageState.sourceFilter === 'dj_enrichment' ? '' : 'none';
    processingSelect.value = reviewPageState.processingStatusFilter || '';
  }
  renderReviewTypeNav();
  renderReviewBulkBar();
  renderReviewList();
  renderReviewPagination();
  renderReviewDetail();
  setReviewHeaderCounter();
  syncReviewPendingBadge();
  renderReviewSourceStats();
  const meta = document.getElementById('review-toolbar-meta');
  if (meta) {
    const total = getReviewTotal();
    const page = Math.min(Math.max(1, Number(reviewPageState.page || 1) || 1), getReviewPageCount());
    meta.textContent = reviewPageState.loading
      ? '加载中...'
      : reviewPageState.sourceFilter === 'dj_binding_review'
        ? `第 ${page} 页 · ${reviewPageState.items.length}/${total} 个任务`
        : `第 ${page} 页 · ${reviewPageState.items.length}/${total} 条`;
  }
}

function onReviewFilterChanged() {
  const statusEl = document.getElementById('review-status-select');
  reviewPageState.statusFilter = statusEl ? statusEl.value : 'pending';
  reviewPageState.page = 1;
  resetReviewSelection();
  void refreshReviewPage(true);
}

function onReviewProcessingStatusChanged() {
  const statusEl = document.getElementById('review-processing-status-select');
  reviewPageState.processingStatusFilter = statusEl ? statusEl.value : '';
  reviewPageState.page = 1;
  resetReviewSelection();
  void refreshReviewPage(true);
}

function onReviewSourceChanged() {
  const sourceEl = document.getElementById('review-source-select');
  reviewPageState.sourceFilter = sourceEl ? sourceEl.value : 'content_submission';
  reviewPageState.statusFilter = 'pending';
  reviewPageState.entityFilter = '';
  reviewPageState.processingStatusFilter = '';
  reviewPageState.page = 1;
  reviewPageState.selectedId = '';
  reviewPageState.selectedDetail = null;
  reviewPageState.reasonCode = '';
  resetReviewSelection();
  void refreshReviewPage(true);
}

function setReviewSourceFilter(source) {
  const normalized = ['content_submission', 'dj_enrichment', 'dj_binding_review'].includes(String(source || ''))
    ? String(source)
    : 'content_submission';
  const sourceEl = document.getElementById('review-source-select');
  if (sourceEl) sourceEl.value = normalized;
  reviewPageState.sourceFilter = normalized;
  reviewPageState.statusFilter = 'pending';
  reviewPageState.processingStatusFilter = '';
  reviewPageState.entityFilter = '';
  reviewPageState.page = 1;
  reviewPageState.selectedId = '';
  reviewPageState.selectedDetail = null;
  reviewPageState.reasonCode = '';
  resetReviewSelection();
  if (currentAppPage !== 'review') {
    switchAppPage('review');
    return;
  }
  void refreshReviewPage(true);
}

function setReviewEntityFilter(entityType) {
  reviewPageState.entityFilter = String(entityType || '').trim();
  reviewPageState.page = 1;
  resetReviewSelection();
  void refreshReviewPage(true);
}

function setReviewPage(page) {
  reviewPageState.page = Math.min(Math.max(1, Number(page || 1) || 1), getReviewPageCount());
  reviewPageState.selectedId = '';
  reviewPageState.selectedDetail = null;
  resetReviewSelection();
  void refreshReviewPage(true);
}

async function ensureReviewPageLoaded() {
  if (reviewPageState.loaded || reviewPageState.loading) {
    renderReviewPage();
    return;
  }
  await refreshReviewPage(false);
}

async function refreshReviewPage(force = false) {
  if (reviewPageState.loading && !force) return;
  const headers = getReviewAuthHeaders(false);
  if (!headers.Authorization) {
    setReviewStatus('请先登录后查看共建审核。', 'error');
    return;
  }
  reviewPageState.loading = true;
  reviewPageState.loadError = '';
  renderReviewPage();
  try {
    if (reviewPageState.sourceFilter === 'dj_binding_review') {
      const result = typeof fetchDjBindingReviewJobs === 'function'
        ? await fetchDjBindingReviewJobs()
        : { items: [], total: 0 };
      reviewPageState.items = Array.isArray(result.items) ? result.items : [];
      reviewPageState.total = Math.max(0, Number(result.total ?? reviewPageState.items.length) || 0);
      if (reviewPageState.statusFilter === 'pending') {
        const existingCounts = reviewPageState.pendingCountsByType && typeof reviewPageState.pendingCountsByType === 'object'
          ? { ...reviewPageState.pendingCountsByType }
          : {};
        existingCounts.dj_binding_review = reviewPageState.total;
        const mergedTotal = Object.values(existingCounts)
          .reduce((sum, value) => sum + Math.max(0, Number(value || 0) || 0), 0);
        setReviewPendingCount(mergedTotal, existingCounts);
      } else {
        void refreshReviewPendingCount();
      }
    } else if (reviewPageState.sourceFilter === 'dj_enrichment') {
      const qs = new URLSearchParams();
      if (reviewPageState.statusFilter === 'pending') qs.set('applyStatus', 'pending_review');
      else if (reviewPageState.statusFilter === 'approved') qs.set('applyStatus', 'approved');
      else if (reviewPageState.statusFilter === 'rejected') qs.set('applyStatus', 'rejected');
      if (reviewPageState.processingStatusFilter) qs.set('reviewStatus', reviewPageState.processingStatusFilter);
      const pageSize = getReviewPageSize();
      const page = Math.max(1, Number(reviewPageState.page || 1) || 1);
      qs.set('limit', String(pageSize));
      qs.set('offset', String((page - 1) * pageSize));
      const data = await reviewApiGet(`/api/admin/v1/dj-enrichment/results?${qs.toString()}`);
      reviewPageState.items = (Array.isArray(data.items) ? data.items : []).map((item) => ({
        ...item,
        entityType: 'dj_enrichment',
        title: item.inputName || item?.dj?.name || 'DJ Enrichment',
        processingStatus: item.status,
        status: item.applyStatus === 'pending_review' ? 'pending' : item.applyStatus,
      }));
      reviewPageState.total = Math.max(0, Number(data.total ?? reviewPageState.items.length) || 0);
      const maxPage = getReviewPageCount();
      if (reviewPageState.page > maxPage) reviewPageState.page = maxPage;
      const pendingCount = reviewPageState.statusFilter === 'pending' && !reviewPageState.processingStatusFilter
        ? reviewPageState.total
        : reviewPageState.items.filter((item) => item.applyStatus === 'pending_review').length;
      const existingCounts = reviewPageState.pendingCountsByType && typeof reviewPageState.pendingCountsByType === 'object'
        ? { ...reviewPageState.pendingCountsByType }
        : {};
      existingCounts.dj_enrichment = pendingCount;
      const mergedTotal = Object.values(existingCounts)
        .reduce((sum, value) => sum + Math.max(0, Number(value || 0) || 0), 0);
      setReviewPendingCount(mergedTotal, existingCounts);
    } else {
      const qs = new URLSearchParams();
      if (reviewPageState.entityFilter) qs.set('entityType', reviewPageState.entityFilter);
      qs.set('limit', '200');
      let data = null;
      if (reviewPageState.statusFilter === 'pending') {
        const results = await Promise.all(CONTENT_SUBMISSION_REVIEWABLE_STATUSES.map((status) => {
          const statusQs = new URLSearchParams(qs);
          statusQs.set('status', status);
          return reviewApiGet(`/api/admin/v1/content-submissions?${statusQs.toString()}`);
        }));
        reviewPageState.items = mergeReviewItemsById(results.map((result) => result.items));
        reviewPageState.total = reviewPageState.items.length;
        data = { items: reviewPageState.items, total: reviewPageState.total };
      } else {
        if (reviewPageState.statusFilter) qs.set('status', reviewPageState.statusFilter);
        data = await reviewApiGet(`/api/admin/v1/content-submissions?${qs.toString()}`);
        reviewPageState.items = Array.isArray(data.items) ? data.items : [];
        reviewPageState.total = Math.max(0, Number(data.total ?? reviewPageState.items.length) || 0);
      }
      if (reviewPageState.statusFilter === 'pending' && !reviewPageState.entityFilter) {
        const countsByType = {};
        for (const item of reviewPageState.items) {
          const type = String(item?.entityType || '').trim();
          if (!type) continue;
          countsByType[type] = (countsByType[type] || 0) + 1;
        }
        const existingCounts = reviewPageState.pendingCountsByType && typeof reviewPageState.pendingCountsByType === 'object'
          ? { ...reviewPageState.pendingCountsByType }
          : {};
        const mergedCounts = { ...existingCounts, ...countsByType };
        const mergedTotal = Object.values(mergedCounts)
          .reduce((sum, value) => sum + Math.max(0, Number(value || 0) || 0), 0);
        setReviewPendingCount(mergedTotal || (data.total ?? reviewPageState.items.length), mergedCounts);
      } else {
        void refreshReviewPendingCount();
      }
    }
    reviewPageState.loaded = true;
    const selectedStillExists = reviewPageState.items.some((item) => item.id === reviewPageState.selectedId);
    reviewPageState.selectedId = selectedStillExists ? reviewPageState.selectedId : (reviewPageState.items[0]?.id || '');
    reviewPageState.selectedDetail = null;
    reviewPageState.reviewNotes = {};
    reviewPageState.expandedNoteFields = new Set();
    reviewPageState.reason = '';
    reviewPageState.reasonCode = '';
    resetReviewSelection();
    setReviewStatus(reviewPageState.items.length ? '审核列表已刷新。' : '当前筛选下暂无提交。', 'ok');
    renderReviewPage();
    if (reviewPageState.selectedId) await selectReviewSubmission(reviewPageState.selectedId);
  } catch (error) {
    reviewPageState.loadError = error instanceof Error ? error.message : '加载失败';
    setReviewStatus(reviewPageState.loadError, 'error');
  } finally {
    reviewPageState.loading = false;
    renderReviewPage();
  }
}

async function selectReviewSubmission(id) {
  const submissionId = String(id || '').trim();
  if (!submissionId) return;
  reviewPageState.selectedId = submissionId;
  reviewPageState.selectedDetail = reviewPageState.items.find((item) => item.id === submissionId) || null;
  reviewPageState.reviewNotes = reviewNormalizeNotes(reviewPageState.selectedDetail?.reviewNotes);
  reviewPageState.expandedNoteFields = new Set(Object.keys(reviewPageState.reviewNotes));
  reviewPageState.reason = reviewPageState.selectedDetail?.reviewReason || '';
  reviewPageState.reasonCode = reviewText(reviewDecisionMeta(reviewPageState.selectedDetail?.reviewNotes).reasonCode);
  renderReviewPage();
  try {
    if (reviewPageState.sourceFilter === 'dj_binding_review' && typeof fetchDjBindingReviewJobDetail === 'function') {
      reviewPageState.selectedDetail = await fetchDjBindingReviewJobDetail(submissionId);
      if (typeof resetDjBindingCandidateSelection === 'function') {
        resetDjBindingCandidateSelection();
      }
    } else {
      const data = reviewPageState.sourceFilter === 'dj_enrichment'
        ? await reviewApiGet(`/api/admin/v1/dj-enrichment/results/${encodeURIComponent(submissionId)}`)
        : await reviewApiGet(`/api/admin/v1/content-submissions/${encodeURIComponent(submissionId)}`);
      reviewPageState.selectedDetail = data.submission || data.result || reviewPageState.selectedDetail;
      reviewPageState.reviewNotes = reviewNormalizeNotes(reviewPageState.selectedDetail?.reviewNotes);
      reviewPageState.expandedNoteFields = new Set(Object.keys(reviewPageState.reviewNotes));
      reviewPageState.reason = reviewPageState.selectedDetail?.reviewReason || '';
      reviewPageState.reasonCode = reviewText(reviewDecisionMeta(reviewPageState.selectedDetail?.reviewNotes).reasonCode);
    }
    renderReviewPage();
  } catch (error) {
    setReviewStatus(error instanceof Error ? error.message : '加载详情失败', 'error');
  }
}

function focusReviewFieldNote(fieldKey) {
  const selector = `[data-review-note-field="${CSS.escape(String(fieldKey || ''))}"]`;
  const el = document.querySelector(selector);
  if (!el) return;
  el.focus();
  el.scrollIntoView({ behavior: 'smooth', block: 'center' });
}

function focusReviewFieldNoteByToken(fieldToken) {
  focusReviewFieldNote(decodeURIComponent(String(fieldToken || '')));
}

function quoteReviewField(fieldKey) {
  const key = String(fieldKey || '').trim();
  if (!key) return;
  if (!(reviewPageState.expandedNoteFields instanceof Set)) {
    reviewPageState.expandedNoteFields = new Set();
  }
  reviewPageState.expandedNoteFields.add(key);
  renderReviewDetail();
  setTimeout(() => focusReviewFieldNote(key), 0);
}

function quoteReviewFieldByToken(fieldToken) {
  quoteReviewField(decodeURIComponent(String(fieldToken || '')));
}

function updateReviewFieldNote(fieldKey, value) {
  const key = String(fieldKey || '').trim();
  if (!key) return;
  const text = String(value || '').trim();
  if (text) reviewPageState.reviewNotes[key] = text;
  else delete reviewPageState.reviewNotes[key];
  syncReviewReasonFromNotes();
}

function updateReviewFieldNoteByToken(fieldToken, value) {
  updateReviewFieldNote(decodeURIComponent(String(fieldToken || '')), value);
}

function buildReviewNotesSummary() {
  const rows = Object.entries(reviewPageState.reviewNotes)
    .map(([field, note]) => `${field}: ${note}`)
    .filter(Boolean);
  return rows.length ? `字段修改意见：\n${rows.join('\n')}` : '';
}

function buildDjEnrichmentResultsQuery({ pageSize = null, offset = null } = {}) {
  const qs = new URLSearchParams();
  if (reviewPageState.statusFilter === 'pending') qs.set('applyStatus', 'pending_review');
  else if (reviewPageState.statusFilter === 'approved') qs.set('applyStatus', 'approved');
  else if (reviewPageState.statusFilter === 'rejected') qs.set('applyStatus', 'rejected');
  if (reviewPageState.processingStatusFilter) qs.set('reviewStatus', reviewPageState.processingStatusFilter);
  if (pageSize !== null && pageSize !== undefined) qs.set('limit', String(pageSize));
  if (offset !== null && offset !== undefined) qs.set('offset', String(offset));
  return qs;
}

async function fetchAllMatchingDjEnrichmentResultIds(mode = '') {
  const pageSize = 200;
  let offset = 0;
  let total = null;
  const ids = [];
  while (total === null || offset < total) {
    const qs = buildDjEnrichmentResultsQuery({ pageSize, offset });
    const data = await reviewApiGet(`/api/admin/v1/dj-enrichment/results?${qs.toString()}`);
    const items = Array.isArray(data.items) ? data.items : [];
    total = Math.max(0, Number(data.total ?? items.length) || 0);
    const filtered = items.filter((item) => {
      const enriched = {
        ...item,
        processingStatus: item?.status,
        status: item?.applyStatus === 'pending_review' ? 'pending' : item?.applyStatus,
      };
      if (mode === 'approve') return canApproveReviewItem(enriched);
      if (mode === 'retry') return canRetryReviewItem(enriched);
      return isReviewItemSelectable(enriched);
    });
    ids.push(...filtered.map((item) => String(item?.id || '').trim()).filter(Boolean));
    offset += pageSize;
    if (!items.length) break;
  }
  return Array.from(new Set(ids));
}

function syncReviewReasonFromNotes() {
  const text = buildReviewNotesSummary();
  const el = document.getElementById('review-reason-input');
  const current = String(el?.value || reviewPageState.reason || '').trim();
  if (current || !text) return;
  reviewPageState.reason = text;
  if (el) el.value = text;
}

function copyReviewNotesToReason() {
  const text = buildReviewNotesSummary();
  if (!text) return;
  const el = document.getElementById('review-reason-input');
  const current = String(el?.value || reviewPageState.reason || '').trim();
  const next = !current
    ? text
    : current.includes(text)
      ? current
      : `${current}\n\n${text}`;
  reviewPageState.reason = next;
  if (el) el.value = next;
}

async function submitReviewDecision(decision) {
  const submission = reviewPageState.selectedDetail;
  if (!submission || reviewPageState.saving) return;
  const normalizedDecision = decision === 'approved' ? 'approved' : 'rejected';
  const reasonEl = document.getElementById('review-reason-input');
  const rawReason = String(reasonEl?.value || reviewPageState.reason || '').trim();
  const reason = reviewBuildDecisionReason(normalizedDecision, submission, rawReason);
  const reasonCode = normalizedDecision === 'rejected' ? reviewSelectedReasonCode() : '';
  if (normalizedDecision === 'rejected' && !reason) {
    setReviewStatus('审核不通过时请填写原因或字段意见。', 'error');
    return;
  }
  if (normalizedDecision === 'rejected' && reviewReasonCodeOptions(submission?.entityType).length && !reasonCode) {
    setReviewStatus('品牌审核不通过时请选择一个 reason code。', 'error');
    return;
  }
  reviewPageState.saving = true;
  setReviewStatus('正在提交审核结论...');
  try {
    const existingReviewNotes = submission?.reviewNotes && typeof submission.reviewNotes === 'object' && !Array.isArray(submission.reviewNotes)
      ? submission.reviewNotes
      : {};
    const reviewNotes = {
      ...existingReviewNotes,
      fields: { ...reviewPageState.reviewNotes },
      source: 'festival_viewer',
      submittedAt: new Date().toISOString(),
      reviewDecision: {
        decision: normalizedDecision,
        reasonCode: reasonCode || null,
        reasonCodeLabel: reasonCode ? (reviewReasonCodeLabel(submission?.entityType, reasonCode) || reasonCode) : null,
      },
    };
    const path = reviewPageState.sourceFilter === 'dj_enrichment'
      ? `/api/admin/v1/dj-enrichment/results/${encodeURIComponent(submission.id)}/review`
      : `/api/admin/v1/content-submissions/${encodeURIComponent(submission.id)}/review`;
    const data = await reviewApiPost(path, {
      decision: normalizedDecision,
      reason,
      reviewNotes,
    });
    setReviewStatus(data.message || '审核已提交', 'ok');
    await refreshReviewPendingCount();
    await refreshReviewPage(true);
  } catch (error) {
    setReviewStatus(error instanceof Error ? error.message : '审核提交失败', 'error');
  } finally {
    reviewPageState.saving = false;
    renderReviewPage();
  }
}

async function submitBulkReviewDecision(decision) {
  let ids = selectedReviewIds();
  if ((!ids.length && !reviewPageState.selectedAllMatching) || reviewPageState.bulkSaving) return;
  const normalizedDecision = decision === 'approved' ? 'approved' : 'rejected';
  let reason = '';
  if (normalizedDecision === 'rejected') {
    const promptCount = reviewPageState.selectedAllMatching ? getReviewTotal() : ids.length;
    reason = window.prompt(`将选中的 ${promptCount} 条批量审核不通过，请填写原因：`, '批量审核不通过') || '';
    reason = String(reason || '').trim();
    if (!reason) {
      setReviewStatus('批量审核不通过时请填写原因。', 'error');
      return;
    }
  } else {
    const selectedItems = selectedReviewItems();
    if (selectedItems.some((item) => !canApproveReviewItem(item))) {
      setReviewStatus('只有处理成功且待审核的 DJ Enrichment 结果可以批量通过。', 'error');
      return;
    }
    const confirmCount = reviewPageState.selectedAllMatching ? getReviewTotal() : ids.length;
    if (!window.confirm(`确认将选中的 ${confirmCount} 条批量审核通过并入库吗？`)) {
      return;
    }
  }

  reviewPageState.bulkSaving = true;
  setReviewStatus(`正在批量提交审核结论...`);
  try {
    if (reviewPageState.selectedAllMatching) {
      ids = await fetchAllMatchingDjEnrichmentResultIds();
    }
    if (!ids.length) {
      setReviewStatus('当前筛选下没有可批量审核的结果。', 'error');
      return;
    }
    const reviewNotes = {
      fields: {},
      source: 'festival_viewer_bulk',
      submittedAt: new Date().toISOString(),
    };
    const data = reviewPageState.sourceFilter === 'dj_enrichment'
      ? await reviewApiPost('/api/admin/v1/dj-enrichment/results/review-bulk', {
        resultIds: ids,
        decision: normalizedDecision,
        reason,
        reviewNotes,
        batchSize: 100,
      })
      : await (async () => {
        let succeeded = 0;
        const failures = [];
        for (const id of ids) {
          try {
            await reviewApiPost(`/api/admin/v1/content-submissions/${encodeURIComponent(id)}/review`, {
              decision: normalizedDecision,
              reason,
              reviewNotes,
            });
            succeeded += 1;
          } catch (error) {
            failures.push(`${id.slice(0, 8)}: ${error instanceof Error ? error.message : '提交失败'}`);
          }
        }
        return { requested: ids.length, succeeded, failed: failures.length, failures, message: `内容审核完成：${succeeded}/${ids.length}` };
      })();
    resetReviewSelection();
    await refreshReviewPendingCount();
    await refreshReviewPage(true);
    const failures = Array.isArray(data.failures) ? data.failures : [];
    const failedCount = Math.max(0, Number(data.failed ?? failures.length) || 0);
    const successCount = Math.max(0, Number(data.succeeded ?? 0) || 0);
    if (failedCount > 0) {
      const previews = failures.slice(0, 3).map((item) => typeof item === 'string' ? item : `${String(item?.id || '').slice(0, 8)}: ${String(item?.message || '失败')}`);
      setReviewStatus(`批量审核完成：成功 ${successCount} 条，失败 ${failedCount} 条。${previews.join('；')}`, 'error');
    } else {
      setReviewStatus(data.message || `批量审核完成：成功 ${successCount} 条。`, 'ok');
    }
  } finally {
    reviewPageState.bulkSaving = false;
    renderReviewPage();
  }
}

async function retrySelectedDjEnrichment() {
  if (reviewPageState.bulkSaving) return;
  reviewPageState.bulkSaving = true;
  setReviewStatus(`正在重新提交失败结果到 Coze...`);
  try {
    let selectedItems = selectedReviewItems();
    if (reviewPageState.selectedAllMatching) {
      const ids = await fetchAllMatchingDjEnrichmentResultIds();
      const pageSize = 200;
      const details = [];
      for (let index = 0; index < ids.length; index += pageSize) {
        const chunkIds = new Set(ids.slice(index, index + pageSize));
        const qs = buildDjEnrichmentResultsQuery({ pageSize, offset: index });
        const data = await reviewApiGet(`/api/admin/v1/dj-enrichment/results?${qs.toString()}`);
        const items = Array.isArray(data.items) ? data.items : [];
        details.push(...items.filter((item) => chunkIds.has(String(item?.id || '').trim())).map((item) => ({
          ...item,
          processingStatus: item.status,
        })));
      }
      selectedItems = details;
    }
    const retryable = selectedItems.filter(canRetryReviewItem);
    if (retryable.length !== selectedItems.length) {
      setReviewStatus('只有处理失败且已绑定 DJ 的 enrichment 结果可以重跑 Coze。', 'error');
      return;
    }
    const djIds = retryable.map((item) => String(item.djId || '').trim()).filter(Boolean);
    if (!djIds.length) {
      setReviewStatus('没有可重跑的 DJ。', 'error');
      return;
    }
    if (!window.confirm(`确认将选中的 ${djIds.length} 个失败结果重新提交到 Coze enrichment 队列吗？`)) {
      return;
    }
    const data = await reviewApiPost('/api/admin/v1/dj-enrichment/jobs', {
      djIds,
      maxConcurrency: 10,
    });
    resetReviewSelection();
    await refreshReviewPendingCount();
    await refreshReviewPage(true);
    setReviewStatus(data.message || `已重新提交 ${djIds.length} 个 DJ 到 Coze enrichment 队列。`, 'ok');
  } catch (error) {
    setReviewStatus(error instanceof Error ? error.message : '重跑 Coze 失败', 'error');
  } finally {
    reviewPageState.bulkSaving = false;
    renderReviewPage();
  }
}
