function normalizeWikiFestivalSearchToken(value) {
  return String(value || '').trim().toLowerCase();
}

function eventBrandDisplayName(brand) {
  if (!brand || typeof brand !== 'object') return '';
  const bi = normalizeBiTextValue(brand.nameI18n ?? brand.name, String(brand.name || '').trim());
  return String(bi.zh || bi.en || brand.name || '').trim();
}

function eventBrandCandidatesByQuery(query) {
  const token = normalizeWikiFestivalSearchToken(query);
  const source = Array.isArray(brandPageState.allItems) ? brandPageState.allItems : [];
  const rows = source.filter((item) => {
    if (!item || typeof item !== 'object') return false;
    if (!token) return true;
    const nameBi = normalizeBiTextValue(item.nameI18n ?? item.name, String(item.name || '').trim());
    const pool = [
      String(item.id || '').trim(),
      String(nameBi.en || '').trim(),
      String(nameBi.zh || '').trim(),
      ...(Array.isArray(item.aliases) ? item.aliases.map((x) => String(x || '').trim()) : []),
      String(item.country || '').trim(),
      String(item.city || '').trim(),
    ]
      .join(' ')
      .toLowerCase();
    return pool.includes(token);
  });
  return rows
    .slice(0, 50)
    .map((item) => ({
      id: String(item.id || '').trim(),
      name: eventBrandDisplayName(item),
      aliases: Array.isArray(item.aliases) ? item.aliases.map((x) => String(x || '').trim()).filter(Boolean) : [],
      raw: item,
    }))
    .filter((item) => item.id && item.name);
}

async function ensureEventBrandBindingUI(panelEl, presetInfo = null) {
  if (!panelEl) return;
  const nameInput = panelEl.querySelector('.fest-info-edit [data-field="wikiFestivalName"]');
  const idInput = panelEl.querySelector('.fest-info-edit [data-field="wikiFestivalId"]');
  if (!nameInput || !idInput) return;

  try { await ensureBrandPageLoaded(false); } catch (_error) {}
  const existingListId = String(nameInput.getAttribute('list') || '').trim();
  const listId = existingListId || `wiki-brand-bind-list-${Math.random().toString(36).slice(2)}`;
  let dataList = document.getElementById(listId);
  if (!dataList) {
    dataList = document.createElement('datalist');
    dataList.id = listId;
    document.body.appendChild(dataList);
  }
  nameInput.setAttribute('list', listId);

  const syncList = () => {
    const rows = eventBrandCandidatesByQuery(nameInput.value || '');
    dataList.innerHTML = rows
      .map((row) => `<option value="${escapeHtml(row.name)}" label="${escapeHtml(`${row.id}${row.aliases.length ? ` · ${row.aliases.slice(0, 2).join(' / ')}` : ''}`)}"></option>`)
      .join('');
  };

  if (presetInfo && typeof presetInfo === 'object') {
    const brand = presetInfo.wikiFestival && typeof presetInfo.wikiFestival === 'object' ? presetInfo.wikiFestival : null;
    const brandId = String(presetInfo.wikiFestivalId || brand?.id || '').trim();
    const brandName = brand ? eventBrandDisplayName(brand) : '';
    idInput.value = brandId;
    nameInput.value = brandName || nameInput.value || '';
  }

  if (!nameInput.dataset.brandBindBound) {
    nameInput.dataset.brandBindBound = '1';
    nameInput.addEventListener('input', () => {
      syncList();
      idInput.value = '';
    });
    nameInput.addEventListener('change', () => {
      // Manual selection only: only resolve on explicit change (datalist pick / exact value).
      const typed = String(nameInput.value || '').trim();
      const token = normalizeWikiFestivalSearchToken(typed);
      const candidates = eventBrandCandidatesByQuery(typed);
      const hit = candidates.find((item) => {
        if (normalizeWikiFestivalSearchToken(item.id) === token) return true;
        if (normalizeWikiFestivalSearchToken(item.name) === token) return true;
        return item.aliases.some((alias) => normalizeWikiFestivalSearchToken(alias) === token);
      });
      if (hit) {
        idInput.value = hit.id;
        nameInput.value = hit.name;
      } else {
        idInput.value = '';
      }
      syncList();
    });
  }
  syncList();
}

function eventLineupEditorParseArtistsFromJson(panelEl) {
  const textarea = panelEl?.querySelector('.fest-info-edit [data-field="lineupArtists"]');
  const raw = String(textarea?.value || '').trim();
  if (!raw) return [];
  try {
    const parsed = JSON.parse(raw);
    if (Array.isArray(parsed)) return buildEventLineupArtistsFromArchive(parsed, []);
    if (parsed && Array.isArray(parsed.lineup_artists)) return buildEventLineupArtistsFromArchive(parsed.lineup_artists, []);
    if (parsed && Array.isArray(parsed.artists)) return buildEventLineupArtistsFromArchive(parsed.artists, []);
    if (parsed && typeof parsed === 'object') {
      const key = Object.keys(parsed).find((k) => Array.isArray(parsed[k]));
      if (key) return buildEventLineupArtistsFromArchive(parsed[key], []);
    }
  } catch (_error) {}
  return [];
}

function eventLineupEditorWriteArtists(panelEl, artists) {
  const normalized = (typeof sortEventLineupArtistsByName === 'function')
    ? sortEventLineupArtistsByName(buildEventLineupArtistsFromArchive(artists || [], []))
    : buildEventLineupArtistsFromArchive(artists || [], []);
  const textarea = panelEl?.querySelector('.fest-info-edit [data-field="lineupArtists"]');
  if (textarea) textarea.value = normalized.length ? JSON.stringify({ lineup_artists: normalized }, null, 2) : '';
  renderEventLineupArtistEditor(panelEl, normalized);
  if (typeof refreshEventLineupModalIfCurrent === 'function') refreshEventLineupModalIfCurrent();
}

function eventLineupEditorCurrentArtists(panelEl) {
  return eventLineupEditorParseArtistsFromJson(panelEl);
}

function eventLineupEditorAddArtist(panelEl, artist) {
  const djName = String(artist?.djName || artist?.name || '').trim();
  if (!djName) return false;
  const current = eventLineupEditorCurrentArtists(panelEl);
  const next = buildEventLineupArtistsFromArchive([...current, {
    djId: String(artist?.djId || artist?.id || '').trim() || undefined,
    djIds: Array.isArray(artist?.djIds) ? artist.djIds : (artist?.id ? [String(artist.id)] : []),
    djName,
    sortOrder: current.length + 1,
  }], []);
  eventLineupEditorWriteArtists(panelEl, next);
  return true;
}

function eventLineupEditorRemoveArtist(panelEl, index) {
  const current = eventLineupEditorCurrentArtists(panelEl);
  const next = current.filter((_item, idx) => idx !== Number(index)).map((item, idx) => ({ ...item, sortOrder: idx + 1 }));
  eventLineupEditorWriteArtists(panelEl, next);
}

function renderEventLineupArtistEditor(panelEl, artists = null) {
  if (!panelEl) return;
  const listEl = panelEl.querySelector('[data-lineup-artist-list]');
  if (!listEl) return;
  const rows = (typeof sortEventLineupArtistsByName === 'function')
    ? sortEventLineupArtistsByName(artists || eventLineupEditorCurrentArtists(panelEl))
    : (artists || eventLineupEditorCurrentArtists(panelEl));
  if (!rows.length) {
    listEl.innerHTML = '<div class="event-lineup-empty">暂无 DJ 阵容，可搜索 DJ 库或只添加名字。</div>';
    return;
  }
  const summaryHtml = `
    <div class="event-lineup-chip-summary">
      <span class="event-lineup-chip-summary-count">${rows.length}</span>
      <span class="event-lineup-chip-summary-label">位 DJ</span>
    </div>
  `;
  listEl.innerHTML = rows.map((artist, index) => {
    const hasBinding = !!String(artist?.djId || '').trim();
    const idText = hasBinding ? String(artist.djId).trim() : '未绑定';
    const name = String(artist?.djName || 'Unknown DJ').trim() || 'Unknown DJ';
    const avatarHtml = typeof eventLineupRenderAvatar === 'function'
      ? eventLineupRenderAvatar(name, typeof eventLineupResolveAvatarUrl === 'function' ? eventLineupResolveAvatarUrl(artist) : '', 'event-lineup-avatar')
      : '';
    return `
      <div class="event-lineup-artist-chip${hasBinding ? '' : ' is-unbound'}">
        <button class="event-lineup-artist-chip-link" type="button" data-action="${hasBinding ? 'lineup-open-profile' : 'lineup-bind-artist'}" data-index="${index}">
          ${avatarHtml}
          <div class="event-lineup-artist-chip-body">
            <span class="event-lineup-artist-name">${escapeHtml(name)}</span>
            <span class="event-lineup-artist-meta${hasBinding ? '' : ' is-unbound'}">${escapeHtml(idText)}</span>
          </div>
        </button>
        <button class="event-lineup-chip-remove" type="button" aria-label="删除 ${escapeHtml(artist.djName || 'DJ')}" data-action="lineup-remove-artist" data-index="${index}">×</button>
      </div>
    `;
  }).join('');
  listEl.innerHTML = summaryHtml + listEl.innerHTML;
}

function renderEventLineupSearchResults(panelEl, rows, query) {
  const resultsEl = panelEl?.querySelector('[data-lineup-search-results]');
  if (!resultsEl) return;
  const q = String(query || '').trim();
  if (!q) {
    resultsEl.innerHTML = '';
    return;
  }
  if (!Array.isArray(rows) || !rows.length) {
    resultsEl.innerHTML = `<div class="event-lineup-empty">DJ 库里没有找到 “${escapeHtml(q)}”，可以用右侧名字输入直接添加。</div>`;
    return;
  }
  resultsEl.innerHTML = rows.map((row, index) => `
    <button class="event-lineup-result" type="button" data-action="lineup-add-search-result" data-index="${index}">
      <span>${escapeHtml(row.name || row.id)}</span>
      <small>${escapeHtml(row.id || '')}</small>
    </button>
  `).join('');
  resultsEl._lineupSearchRows = rows;
}

async function eventLineupEditorSearchDj(panelEl) {
  const input = panelEl?.querySelector('[data-lineup-dj-search]');
  const query = String(input?.value || '').trim();
  const resultsEl = panelEl?.querySelector('[data-lineup-search-results]');
  if (!query) {
    if (resultsEl) resultsEl.innerHTML = '<div class="event-lineup-empty">请输入 DJ 名称再搜索。</div>';
    return;
  }
  if (resultsEl) resultsEl.innerHTML = '<div class="event-lineup-empty">正在搜索 DJ 库...</div>';
  try {
    const rows = await fetchEntityAssociationCandidates('dj', query, { limit: 12, headers: getViewerAuthHeaders() });
    renderEventLineupSearchResults(panelEl, rows, query);
  } catch (error) {
    if (resultsEl) resultsEl.innerHTML = `<div class="event-lineup-empty">搜索失败：${escapeHtml(String(error?.message || error))}</div>`;
  }
}

function bindEventLineupArtistEditor(panelEl, info = null) {
  if (!panelEl || panelEl.dataset.lineupEditorBound === '1') {
    renderEventLineupArtistEditor(panelEl);
    return;
  }
  panelEl.dataset.lineupEditorBound = '1';
  const textarea = panelEl.querySelector('.fest-info-edit [data-field="lineupArtists"]');
  if (textarea) {
    textarea.addEventListener('change', () => renderEventLineupArtistEditor(panelEl));
    textarea.addEventListener('blur', () => renderEventLineupArtistEditor(panelEl));
  }
  panelEl.addEventListener('click', (event) => {
    const target = event.target instanceof Element ? event.target.closest('[data-action]') : null;
    if (!target) return;
    const action = String(target.getAttribute('data-action') || '');
    if (action === 'lineup-search-dj') {
      event.preventDefault();
      void eventLineupEditorSearchDj(panelEl);
    } else if (action === 'lineup-add-name') {
      event.preventDefault();
      const input = panelEl.querySelector('[data-lineup-manual-name]');
      const name = String(input?.value || '').trim();
      if (!name) return;
      if (eventLineupEditorAddArtist(panelEl, { djName: name })) input.value = '';
    } else if (action === 'lineup-add-search-result') {
      event.preventDefault();
      const rows = panelEl.querySelector('[data-lineup-search-results]')?._lineupSearchRows || [];
      const row = rows[Number(target.getAttribute('data-index'))];
      if (row && eventLineupEditorAddArtist(panelEl, { id: row.id, djId: row.id, djName: row.name })) {
        const resultsEl = panelEl.querySelector('[data-lineup-search-results]');
        if (resultsEl) resultsEl.innerHTML = '';
      }
    } else if (action === 'lineup-open-profile') {
      event.preventDefault();
      const rows = eventLineupEditorCurrentArtists(panelEl);
      const artist = rows[Number(target.getAttribute('data-index'))];
      const djId = String(artist?.djId || '').trim();
      if (djId) void openDJProfileById(djId);
    } else if (action === 'lineup-bind-artist') {
      event.preventDefault();
      const rows = eventLineupEditorCurrentArtists(panelEl);
      const artist = rows[Number(target.getAttribute('data-index'))];
      const name = String(artist?.djName || '').trim();
      if (!name) return;
      void openDJLibraryImportModalWithOptions({
        initialName: name,
        onImported: async (dj) => {
          const current = eventLineupEditorCurrentArtists(panelEl);
          const targetName = String(artist?.djName || '').trim().toLowerCase();
          const next = current.map((item) => {
            const itemName = String(item?.djName || '').trim().toLowerCase();
            if (itemName !== targetName || String(item?.djId || '').trim()) return item;
            return {
              ...item,
              djId: String(dj?.id || '').trim() || item.djId,
              djIds: dj?.id ? [String(dj.id)] : (Array.isArray(item?.djIds) ? item.djIds : []),
              djName: String(dj?.name || item?.djName || '').trim() || item.djName,
              avatarUrl: String(dj?.avatarUrl || '').trim() || item.avatarUrl,
            };
          });
          eventLineupEditorWriteArtists(panelEl, next);
        },
      });
    } else if (action === 'lineup-remove-artist') {
      event.preventDefault();
      eventLineupEditorRemoveArtist(panelEl, target.getAttribute('data-index'));
    }
  });
  panelEl.addEventListener('keydown', (event) => {
    if (event.key !== 'Enter') return;
    const target = event.target;
    if (!(target instanceof Element)) return;
    if (target.matches('[data-lineup-dj-search]')) {
      event.preventDefault();
      void eventLineupEditorSearchDj(panelEl);
    } else if (target.matches('[data-lineup-manual-name]')) {
      event.preventDefault();
      const name = String(target.value || '').trim();
      if (name && eventLineupEditorAddArtist(panelEl, { djName: name })) target.value = '';
    }
  });
  renderEventLineupArtistEditor(panelEl, buildEventLineupArtistsFromArchive(info?.lineupArtists || [], info?.lineup || []));
}

function eventEditExtractTriTextDraft(value, options = {}) {
  const row = (value && typeof value === 'object' && !Array.isArray(value)) ? value : null;
  const draft = {
    zh: normalizeScalarText(row?.zh ?? row?.ZH ?? row?.cn ?? row?.zh_CN ?? row?.chinese ?? row?.name_zh ?? ''),
    en: normalizeScalarText(row?.en ?? row?.EN ?? row?.english ?? row?.name_en ?? row?.en_US ?? ''),
    ja: normalizeScalarText(row?.ja ?? row?.JA ?? row?.jp ?? row?.japanese ?? ''),
  };
  if (!row && typeof value === 'string') {
    draft.en = normalizeScalarText(value);
  }
  if (options.includeEnFull) {
    const enFull = normalizeScalarText(
      row?.enFull
      ?? row?.en_full
      ?? row?.englishFull
      ?? row?.country_en_full
      ?? ''
    );
    if (enFull) draft.enFull = enFull;
  }
  return draft;
}

const EVENT_MULTILANG_AI_PROMPT_STORAGE_KEY = 'festivalViewer.eventMultiLangAiPrompt';
const EVENT_MULTILANG_AI_PROMPT_DEFAULT = [
  '请严格按原 JSON 结构返回翻译结果，只输出合法 JSON，不要添加解释。',
  '把现有活动多语言字段补充为中文、英文、日文三个版本。',
  '已经有内容的语言请在原意基础上润色；空字符串表示原数据缺失，除非能从其他语言准确翻译，否则保持空字符串。',
  '不要新增字段，不要删除字段，保留 enFull。'
].join('\n');

function eventEditGetAiPromptTemplate() {
  try {
    const cached = String(window.localStorage?.getItem(EVENT_MULTILANG_AI_PROMPT_STORAGE_KEY) || '').trim();
    return cached || EVENT_MULTILANG_AI_PROMPT_DEFAULT;
  } catch (_error) {
    return EVENT_MULTILANG_AI_PROMPT_DEFAULT;
  }
}

function eventEditSetAiPromptTemplate(value) {
  const text = String(value || '').trim();
  try {
    if (text) window.localStorage?.setItem(EVENT_MULTILANG_AI_PROMPT_STORAGE_KEY, text);
    else window.localStorage?.removeItem(EVENT_MULTILANG_AI_PROMPT_STORAGE_KEY);
  } catch (_error) {}
  return text || EVENT_MULTILANG_AI_PROMPT_DEFAULT;
}

function eventEditSetMultiLangCopyStatus(panelEl, message, isError = false) {
  const statusEl = panelEl?.querySelector('[data-multilang-copy-status]');
  if (!statusEl) return;
  statusEl.textContent = String(message || '').trim();
  statusEl.style.color = isError ? '#ff8cae' : 'var(--accent3)';
}

function ensureEventAiPromptModal() {
  let overlay = document.getElementById('event-ai-prompt-overlay');
  if (overlay) return overlay;
  overlay = document.createElement('div');
  overlay.id = 'event-ai-prompt-overlay';
  overlay.innerHTML = `
    <div id="event-ai-prompt-modal" role="dialog" aria-modal="true" aria-labelledby="event-ai-prompt-title">
      <div class="event-ai-prompt-header">
        <div>
          <div id="event-ai-prompt-title" class="event-ai-prompt-title">AI Prompt Template</div>
          <div class="event-ai-prompt-sub">编辑复制多语言 JSON 时附带的提示词</div>
        </div>
        <div class="event-ai-prompt-actions">
          <button class="edit-btn" type="button" data-ai-prompt-action="reset">恢复默认</button>
          <button class="edit-btn" type="button" data-ai-prompt-action="cancel">取消</button>
          <button class="edit-btn save" type="button" data-ai-prompt-action="save">保存</button>
        </div>
      </div>
      <div class="event-ai-prompt-body">
        <textarea class="event-ai-prompt-textarea" data-ai-prompt-textarea spellcheck="false"></textarea>
      </div>
    </div>
  `;
  document.body.appendChild(overlay);
  overlay.addEventListener('click', (event) => {
    if (event.target === overlay) {
      overlay.classList.remove('open');
      document.body.style.overflow = '';
    }
  });
  return overlay;
}

function openEventAiPromptModal(initialValue, panelEl) {
  const overlay = ensureEventAiPromptModal();
  const textarea = overlay.querySelector('[data-ai-prompt-textarea]');
  const saveBtn = overlay.querySelector('[data-ai-prompt-action="save"]');
  const cancelBtn = overlay.querySelector('[data-ai-prompt-action="cancel"]');
  const resetBtn = overlay.querySelector('[data-ai-prompt-action="reset"]');
  if (!(textarea instanceof HTMLTextAreaElement) || !(saveBtn instanceof HTMLButtonElement) || !(cancelBtn instanceof HTMLButtonElement) || !(resetBtn instanceof HTMLButtonElement)) {
    return;
  }
  textarea.value = String(initialValue || '').trim();
  overlay.classList.add('open');
  document.body.style.overflow = 'hidden';
  setTimeout(() => {
    textarea.focus();
    textarea.setSelectionRange(textarea.value.length, textarea.value.length);
  }, 0);

  const close = () => {
    overlay.classList.remove('open');
    document.body.style.overflow = '';
    saveBtn.onclick = null;
    cancelBtn.onclick = null;
    resetBtn.onclick = null;
  };

  saveBtn.onclick = () => {
    eventEditSetAiPromptTemplate(textarea.value);
    eventEditSetMultiLangCopyStatus(panelEl, '提示词已更新');
    close();
  };
  cancelBtn.onclick = () => close();
  resetBtn.onclick = () => {
    textarea.value = EVENT_MULTILANG_AI_PROMPT_DEFAULT;
    textarea.focus();
  };
}

async function eventEditCopyMultiLangJsonForAi(panelEl) {
  const textarea = panelEl?.querySelector('.fest-info-edit [data-field="multiLangJson"]');
  const jsonText = String(textarea?.value || '').trim();
  if (!jsonText) {
    eventEditSetMultiLangCopyStatus(panelEl, '没有可复制的 JSON', true);
    return;
  }
  const promptText = eventEditGetAiPromptTemplate();
  const composed = `${promptText}\n\n待翻译 JSON:\n${jsonText}`;
  try {
    if (navigator?.clipboard?.writeText) {
      await navigator.clipboard.writeText(composed);
    } else {
      const temp = document.createElement('textarea');
      temp.value = composed;
      temp.setAttribute('readonly', 'readonly');
      temp.style.position = 'fixed';
      temp.style.opacity = '0';
      document.body.appendChild(temp);
      temp.select();
      document.execCommand('copy');
      document.body.removeChild(temp);
    }
    eventEditSetMultiLangCopyStatus(panelEl, '已复制提示词 + JSON');
  } catch (error) {
    eventEditSetMultiLangCopyStatus(panelEl, `复制失败：${String(error?.message || error)}`, true);
  }
}

function eventEditOpenAiPromptEditor(panelEl) {
  const current = eventEditGetAiPromptTemplate();
  openEventAiPromptModal(current, panelEl);
}

function eventEditBuildMultiLangDraft(info) {
  const manualLocation = (typeof normalizeFestivalManualLocation === 'function')
    ? normalizeFestivalManualLocation(info?.manualLocation || info?.manual_location || null, null)
    : (info?.manualLocation || null);
  return {
    nameI18n: eventEditExtractTriTextDraft(info?.nameI18n ?? info?.name ?? ''),
    cityI18n: eventEditExtractTriTextDraft(info?.cityI18n ?? info?.city ?? ''),
    countryI18n: eventEditExtractTriTextDraft(info?.countryI18n ?? info?.country ?? '', { includeEnFull: true }),
    detailAddressI18n: eventEditExtractTriTextDraft(manualLocation?.detailAddressI18n ?? ''),
    descriptionI18n: eventEditExtractTriTextDraft(info?.descriptionI18n ?? info?.description ?? ''),
  };
}

function eventEditWriteMultiLangDraft(panelEl, draft) {
  const textarea = panelEl?.querySelector('.fest-info-edit [data-field="multiLangJson"]');
  if (!textarea) return;
  textarea.value = JSON.stringify(draft || {}, null, 2);
}

function eventEditReadMultiLangDraft(panelEl) {
  const textarea = panelEl?.querySelector('.fest-info-edit [data-field="multiLangJson"]');
  const raw = String(textarea?.value || '').trim();
  if (!raw) return { draft: eventEditBuildMultiLangDraft({}), error: '' };
  try {
    const parsed = JSON.parse(raw);
    if (!parsed || typeof parsed !== 'object' || Array.isArray(parsed)) {
      return { draft: null, error: '多语言 JSON 顶层必须是对象' };
    }
    return {
      draft: {
        nameI18n: eventEditExtractTriTextDraft(parsed.nameI18n ?? ''),
        cityI18n: eventEditExtractTriTextDraft(parsed.cityI18n ?? ''),
        countryI18n: eventEditExtractTriTextDraft(parsed.countryI18n ?? '', { includeEnFull: true }),
        detailAddressI18n: eventEditExtractTriTextDraft(parsed.detailAddressI18n ?? ''),
        descriptionI18n: eventEditExtractTriTextDraft(parsed.descriptionI18n ?? ''),
      },
      error: '',
    };
  } catch (error) {
    return { draft: null, error: String(error?.message || error) };
  }
}

function eventEditSyncMultiLangDraftFromInputs(panelEl) {
  if (!panelEl) return;
  const current = eventEditReadMultiLangDraft(panelEl);
  const draft = current?.draft || eventEditBuildMultiLangDraft({});
  const read = (key) => String(panelEl.querySelector(`.fest-info-edit [data-field="${key}"]`)?.value || '').trim();
  draft.nameI18n = { ...(draft.nameI18n || {}), en: read('nameEn'), zh: read('nameZh'), ja: read('nameJa') };
  draft.cityI18n = { ...(draft.cityI18n || {}), en: read('cityEn'), zh: read('cityZh'), ja: read('cityJa') };
  draft.countryI18n = {
    ...(draft.countryI18n || {}),
    en: read('countryEn'),
    zh: read('countryZh'),
    ja: read('countryJa'),
    enFull: read('countryEnFull'),
  };
  draft.detailAddressI18n = {
    ...(draft.detailAddressI18n || {}),
    en: read('detailAddressEn'),
    zh: read('detailAddressZh'),
    ja: read('detailAddressJa'),
  };
  eventEditWriteMultiLangDraft(panelEl, draft);
}

function eventEditApplyMultiLangDraftToInputs(panelEl, draft) {
  if (!panelEl || !draft || typeof draft !== 'object') return;
  const set = (key, val) => {
    const el = panelEl.querySelector(`.fest-info-edit [data-field="${key}"]`);
    if (el) el.value = val || '';
  };
  set('nameEn', draft?.nameI18n?.en || '');
  set('nameZh', draft?.nameI18n?.zh || '');
  set('nameJa', draft?.nameI18n?.ja || '');
  set('cityEn', draft?.cityI18n?.en || '');
  set('cityZh', draft?.cityI18n?.zh || '');
  set('cityJa', draft?.cityI18n?.ja || '');
  set('countryEn', draft?.countryI18n?.en || '');
  set('countryZh', draft?.countryI18n?.zh || '');
  set('countryJa', draft?.countryI18n?.ja || '');
  set('countryEnFull', draft?.countryI18n?.enFull || '');
  set('detailAddressEn', draft?.detailAddressI18n?.en || '');
  set('detailAddressZh', draft?.detailAddressI18n?.zh || '');
  set('detailAddressJa', draft?.detailAddressI18n?.ja || '');
}

function bindEventMultiLangJsonEditor(panelEl, info = null) {
  if (!panelEl) return;
  if (info) {
    eventEditWriteMultiLangDraft(panelEl, eventEditBuildMultiLangDraft(info));
  }
  if (panelEl.dataset.multiLangEditorBound === '1') return;
  panelEl.dataset.multiLangEditorBound = '1';
  const trackedFields = [
    'nameEn',
    'nameZh',
    'nameJa',
    'cityEn',
    'cityZh',
    'cityJa',
    'countryEn',
    'countryZh',
    'countryJa',
    'countryEnFull',
    'detailAddressEn',
    'detailAddressZh',
    'detailAddressJa',
  ];
  trackedFields.forEach((field) => {
    const el = panelEl.querySelector(`.fest-info-edit [data-field="${field}"]`);
    if (!el) return;
    el.addEventListener('change', () => eventEditSyncMultiLangDraftFromInputs(panelEl));
    el.addEventListener('blur', () => eventEditSyncMultiLangDraftFromInputs(panelEl));
  });
  const textarea = panelEl.querySelector('.fest-info-edit [data-field="multiLangJson"]');
  if (textarea) {
    textarea.addEventListener('change', () => {
      const parsed = eventEditReadMultiLangDraft(panelEl);
      if (parsed?.draft) eventEditApplyMultiLangDraftToInputs(panelEl, parsed.draft);
    });
    textarea.addEventListener('blur', () => {
      const parsed = eventEditReadMultiLangDraft(panelEl);
      if (parsed?.draft) eventEditApplyMultiLangDraftToInputs(panelEl, parsed.draft);
    });
  }
  panelEl.addEventListener('click', (event) => {
    const target = event.target instanceof Element ? event.target.closest('[data-action]') : null;
    if (!target) return;
    const action = String(target.getAttribute('data-action') || '');
    if (action === 'multilang-copy-ai') {
      event.preventDefault();
      void eventEditCopyMultiLangJsonForAi(panelEl);
    } else if (action === 'multilang-edit-prompt') {
      event.preventDefault();
      eventEditOpenAiPromptEditor(panelEl);
    }
  });
}

function setEditInputs(panelEl, info) {
  const set = (key, val) => {
    const el = panelEl.querySelector(`.fest-info-edit [data-field="${key}"]`);
    if (el) el.value = val || '';
  };
  const ensureSelectHasOption = (key, value) => {
    const selectEl = panelEl.querySelector(`.fest-info-edit [data-field="${key}"]`);
    if (!selectEl || !String(value || '').trim()) return;
    const normalizedValue = String(value).trim();
    const hasOption = Array.from(selectEl.options || []).some((opt) => String(opt.value || '').trim() === normalizedValue);
    if (hasOption) return;
    const option = document.createElement('option');
    option.value = normalizedValue;
    option.textContent = normalizedValue;
    selectEl.appendChild(option);
  };
  const nameBi = normalizeBiTextValue(info.nameI18n ?? info.name, info.name);
  const multiLangDraft = eventEditBuildMultiLangDraft(info);
  const cityBi = normalizeBiTextValue(info.cityI18n ?? info.city, info.city);
  const countryBi = normalizeCountryBiTextValue(info.countryI18n ?? info.country, info.country);
  const manualLocation = (typeof normalizeFestivalManualLocation === 'function')
    ? normalizeFestivalManualLocation(info?.manualLocation || info?.manual_location || null, null)
    : (info?.manualLocation || null);
  const cityRaw = (typeof normalizeScalarText === 'function') ? normalizeScalarText(info?.city) : String(info?.city || '').trim();
  const countryRaw = (typeof normalizeScalarText === 'function') ? normalizeScalarText(info?.country) : String(info?.country || '').trim();
  const cityEn = String(multiLangDraft?.cityI18n?.en || (!info?.cityI18n ? (cityBi.en || cityRaw || '') : '')).trim();
  const cityZh = String(multiLangDraft?.cityI18n?.zh || (!info?.cityI18n ? (cityBi.zh || cityRaw || '') : '')).trim();
  const cityJa = String(multiLangDraft?.cityI18n?.ja || '').trim();
  const countryEn = String(multiLangDraft?.countryI18n?.en || (!info?.countryI18n ? (countryBi.en || countryRaw || '') : '')).trim();
  const countryEnFull = String(multiLangDraft?.countryI18n?.enFull || (!info?.countryI18n ? (countryBi.enFull || countryEn || countryRaw || '') : '')).trim();
  const countryZh = String(multiLangDraft?.countryI18n?.zh || (!info?.countryI18n ? (countryBi.zh || countryRaw || '') : '')).trim();
  const countryJa = String(multiLangDraft?.countryI18n?.ja || '').trim();
  const detailAddressEn = String(
    multiLangDraft?.detailAddressI18n?.en
    || (!manualLocation?.detailAddressI18n ? (manualLocation?.formattedAddressI18n?.en || '') : '')
    || ''
  ).trim();
  const detailAddressZh = String(
    multiLangDraft?.detailAddressI18n?.zh
    || (!manualLocation?.detailAddressI18n ? (manualLocation?.formattedAddressI18n?.zh || '') : '')
  ).trim();
  const detailAddressJa = String(multiLangDraft?.detailAddressI18n?.ja || '').trim();
  set('nameEn', nameBi.en);
  set('nameZh', nameBi.zh);
  set('nameJa', multiLangDraft?.nameI18n?.ja || '');
  set('cityEn', cityEn);
  set('cityZh', cityZh);
  set('cityJa', cityJa);
  set('countryEn', countryEn);
  set('countryEnFull', countryEnFull);
  set('countryZh', countryZh);
  set('countryJa', countryJa);
  set('detailAddressEn', detailAddressEn);
  set('detailAddressZh', detailAddressZh);
  set('detailAddressJa', detailAddressJa);
  set('wikiFestivalId', info.wikiFestivalId || info?.wikiFestival?.id || '');
  set('wikiFestivalName', eventBrandDisplayName(info.wikiFestival || null));
  set('canceled', info.canceled ? 'true' : 'false');
  const statusValue = normalizeArchiveEventStatus(info.status, info.canceled ? 'cancelled' : 'upcoming') || (info.canceled ? 'cancelled' : 'upcoming');
  ensureSelectHasOption('status', statusValue);
  set('status', statusValue);
  const eventTypeValue = String(info.eventType || 'festival').trim() || 'festival';
  ensureSelectHasOption('eventType', eventTypeValue);
  set('eventType', eventTypeValue);
  const timeZoneValue = String(info.timeZone || info.timezone || Intl.DateTimeFormat().resolvedOptions().timeZone || 'UTC').trim() || 'UTC';
  ensureSelectHasOption('timeZone', timeZoneValue);
  set('timeZone', timeZoneValue);
  set('startDate', info.startDate);
  set('endDate', info.endDate);
  set('ticketPriceMin', info.ticketPriceMin === null || info.ticketPriceMin === undefined ? '' : String(info.ticketPriceMin));
  set('ticketPriceMax', info.ticketPriceMax === null || info.ticketPriceMax === undefined ? '' : String(info.ticketPriceMax));
  set('ticketCurrency', info.ticketCurrency || '');
  set('ticketUrl', info.ticketUrl || '');
  set('ticketNotes', info.ticketNotes || '');
  set('socialLinks', normalizeSocialLinks(info.socialLinks || []).map(x => x.url).join('\n'));
  set('relatedLinks', (info.relatedLinks||[]).join('\n'));
  const artists = buildEventLineupArtistsFromArchive(info.lineupArtists || [], info.lineup || []);
  set('lineupArtists', artists.length ? JSON.stringify({ lineup_artists: artists }, null, 2) : '');
  renderEventLineupArtistEditor(panelEl, artists);
  // Lineup: show pretty JSON if has data
  const lu = Array.isArray(info.lineup) && info.lineup.length ? info.lineup : null;
  set('lineup', lu ? JSON.stringify({ lineup_info: lu }, null, 2) : '');
  if (typeof setEventLocationDraftFromInfo === 'function') {
    setEventLocationDraftFromInfo(panelEl, info);
  } else {
    set('locationPointJson', info?.locationPoint ? JSON.stringify(info.locationPoint) : '');
  }
  ensureEventBrandBindingUI(panelEl, info);
  bindEventLineupArtistEditor(panelEl, info);
  bindEventMultiLangJsonEditor(panelEl, info);
}
