// Feature module extracted from monolith (news model + list)
const NEWS_MARKER = '#RAVER_NEWS';
const NEWS_CONTENT_KEYS = {
  title: ['标题', 'title'],
  category: ['分类', 'category'],
  source: ['来源', 'source'],
  summary: ['摘要', 'summary'],
  body: ['正文', 'content', 'body'],
  bodyMD64: ['正文MD64', 'content_md64', 'body_md64'],
  link: ['链接', 'url', 'link'],
};
const newsBindSearchTimers = { dj: null, brand: null, event: null };
const newsBindSearchSeq = { dj: 0, brand: 0, event: 0 };

function setNewsStatus(text, level = '') {
  const el = document.getElementById('news-status');
  if (!el) return;
  el.textContent = String(text || '');
  el.classList.remove('error', 'ok');
  if (level === 'error') el.classList.add('error');
  if (level === 'ok') el.classList.add('ok');
}

function setNewsEditStatus(text, level = '') {
  const el = document.getElementById('news-edit-status');
  if (!el) return;
  el.textContent = String(text || '');
  el.classList.remove('err', 'ok');
  if (level) el.classList.add(level);
}

function normalizeNewsSearchText(value) {
  return String(value || '')
    .normalize('NFKD')
    .replace(/[\u0300-\u036f]/g, '')
    .toLowerCase()
    .replace(/\s+/g, ' ')
    .trim();
}

function newsSingleLine(value) {
  return String(value || '')
    .replace(/\r?\n/g, ' ')
    .trim();
}

function newsEncodeUtf8Base64(text) {
  const src = String(text || '');
  if (!src) return '';
  try {
    const bytes = new TextEncoder().encode(src);
    let binary = '';
    for (const b of bytes) binary += String.fromCharCode(b);
    return btoa(binary);
  } catch (_error) {
    return '';
  }
}

function newsDecodeUtf8Base64(encoded) {
  const src = String(encoded || '').trim();
  if (!src) return '';
  try {
    const binary = atob(src);
    const bytes = Uint8Array.from(binary, (char) => char.charCodeAt(0));
    return new TextDecoder().decode(bytes);
  } catch (_error) {
    return '';
  }
}

function newsDedupIDs(ids) {
  const out = [];
  const seen = new Set();
  const source = Array.isArray(ids) ? ids : [];
  for (const raw of source) {
    const id = String(raw || '').trim();
    if (!id || seen.has(id)) continue;
    seen.add(id);
    out.push(id);
  }
  return out;
}

function newsReadValueAfterPrefix(line, key) {
  const prefixes = [`${key}：`, `${key}:`, `${String(key).toUpperCase()}：`, `${String(key).toUpperCase()}:`];
  for (const prefix of prefixes) {
    if (!line.startsWith(prefix)) continue;
    const value = String(line.slice(prefix.length) || '').trim();
    if (value) return value;
  }
  return '';
}

function newsDecodeContent(content) {
  const lines = String(content || '')
    .split(/\r?\n/g)
    .map((line) => String(line || '').trim())
    .filter(Boolean);
  if (!lines.includes(NEWS_MARKER)) return null;
  const read = (keys) => {
    for (const line of lines) {
      for (const key of keys) {
        const value = newsReadValueAfterPrefix(line, key);
        if (value) return value;
      }
    }
    return '';
  };
  const bodyMD64Raw = read(NEWS_CONTENT_KEYS.bodyMD64);
  const decodedBody = newsDecodeUtf8Base64(bodyMD64Raw);
  return {
    title: read(NEWS_CONTENT_KEYS.title) || '未命名资讯',
    category: read(NEWS_CONTENT_KEYS.category) || '社区',
    source: read(NEWS_CONTENT_KEYS.source) || 'Community',
    summary: read(NEWS_CONTENT_KEYS.summary) || '暂无摘要',
    body: decodedBody || read(NEWS_CONTENT_KEYS.body) || '',
    link: read(NEWS_CONTENT_KEYS.link) || '',
  };
}

function newsEncodeContent(draft) {
  const rows = [
    NEWS_MARKER,
    `标题：${newsSingleLine(draft?.title)}`,
    `分类：${newsSingleLine(draft?.category)}`,
    `来源：${newsSingleLine(draft?.source)}`,
    `摘要：${newsSingleLine(draft?.summary)}`,
  ];
  const bodyRaw = String(draft?.body || '');
  const bodyMD64 = newsEncodeUtf8Base64(bodyRaw);
  const link = newsSingleLine(draft?.link);
  if (bodyMD64) rows.push(`正文MD64:${bodyMD64}`);
  if (link) rows.push(`链接：${link}`);
  return rows.join('\n');
}

function newsDisplayNameByBi(value, fallback = '') {
  const bi = normalizeBiTextValue(value, fallback);
  const zh = String(bi?.zh || '').trim();
  const en = String(bi?.en || '').trim();
  return zh || en || String(fallback || '').trim();
}

function newsBuildLookupMaps() {
  const brandLookup = {};
  for (const item of (Array.isArray(brandPageState.allItems) ? brandPageState.allItems : [])) {
    const id = String(item?.id || '').trim();
    if (!id) continue;
    brandLookup[id] = newsDisplayNameByBi(item?.nameI18n ?? item?.name, String(item?.name || id));
  }
  const djLookup = {};
  for (const item of (Array.isArray(djLibraryState.allItems) ? djLibraryState.allItems : [])) {
    const id = String(item?.id || '').trim();
    if (!id) continue;
    djLookup[id] = String(item?.name || id).trim() || id;
  }
  const eventLookup = {};
  for (const yearData of Object.values(allData || {})) {
    for (const list of Object.values(yearData || {})) {
      for (const fest of (Array.isArray(list) ? list : [])) {
        const eventId = String(fest?.backendEventId || fest?.info?.backendEventId || '').trim();
        if (!eventId) continue;
        eventLookup[eventId] = newsDisplayNameByBi(
          fest?.info?.nameI18n ?? fest?.info?.name ?? fest?.name,
          String(fest?.name || fest?.folder || eventId)
        );
      }
    }
  }
  newsPageState.brandLookupById = brandLookup;
  newsPageState.djLookupById = djLookup;
  newsPageState.eventLookupById = eventLookup;
}

function newsParsePost(post) {
  const parsed = newsDecodeContent(post?.content || '');
  if (!parsed) return null;
  const images = (Array.isArray(post?.images) ? post.images : [])
    .map((url) => String(url || '').trim())
    .filter(Boolean);
  const author = (post?.author && typeof post.author === 'object') ? post.author : {};
  const authorName = String(author.displayName || author.username || '').trim() || String(author.username || 'Unknown');
  const uniqueImages = Array.from(new Set(images));
  const coverImageURL = String(uniqueImages[0] || '').trim();
  const bodyImageURLs = uniqueImages.slice(1);
  const displayPublishedAt = String(
    post?.displayPublishedAt ??
    post?.display_published_at ??
    post?.publishedAt ??
    post?.published_at ??
    post?.createdAt ??
    post?.created_at ??
    ''
  ).trim();
  const firstPublishedAt = String(post?.firstPublishedAt ?? post?.first_published_at ?? post?.createdAt ?? post?.created_at ?? '').trim();
  const lastModifiedAt = String(post?.updatedAt ?? post?.updated_at ?? '').trim();
  return {
    id: String(post?.id || '').trim(),
    content: String(post?.content || ''),
    title: parsed.title,
    category: parsed.category,
    source: parsed.source,
    summary: parsed.summary,
    body: parsed.body,
    link: parsed.link || '',
    coverImageURL,
    bodyImageURLs,
    location: String(post?.location || '').trim(),
    displayPublishedAt,
    publishedAt: displayPublishedAt,
    firstPublishedAt,
    lastModifiedAt,
    commentCount: Number(post?.commentCount || 0) || 0,
    authorID: String(author.id || '').trim(),
    authorName,
    authorUsername: String(author.username || '').trim(),
    boundDjIDs: newsDedupIDs(post?.boundDjIDs),
    boundBrandIDs: newsDedupIDs(post?.boundBrandIDs),
    boundEventIDs: newsDedupIDs(post?.boundEventIDs),
    legacyEventID: String(post?.eventID || '').trim(),
  };
}

function newsFormatDateText(raw) {
  const src = String(raw || '').trim();
  if (!src) return '未知时间';
  const date = new Date(src);
  if (Number.isNaN(date.getTime())) return src;
  return date.toLocaleString('zh-CN', {
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
  });
}

function newsToDateTimeLocalInputValue(raw) {
  const src = String(raw || '').trim();
  if (!src) return '';
  const date = new Date(src);
  if (Number.isNaN(date.getTime())) return '';
  const pad2 = (num) => String(num).padStart(2, '0');
  const y = date.getFullYear();
  const m = pad2(date.getMonth() + 1);
  const d = pad2(date.getDate());
  const hh = pad2(date.getHours());
  const mm = pad2(date.getMinutes());
  return `${y}-${m}-${d}T${hh}:${mm}`;
}

function newsCategoryOptionsFromItems() {
  return Array.from(new Set((newsPageState.allItems || []).map((item) => String(item?.category || '').trim()).filter(Boolean)))
    .sort((a, b) => a.localeCompare(b, 'zh-Hans-CN'));
}

function newsSourceOptionsFromItems() {
  return Array.from(new Set((newsPageState.allItems || []).map((item) => String(item?.source || '').trim()).filter(Boolean)))
    .sort((a, b) => a.localeCompare(b, 'zh-Hans-CN'));
}

function newsBrandOptionsFromItems() {
  const ids = new Set();
  for (const item of (newsPageState.allItems || [])) {
    for (const id of (Array.isArray(item?.boundBrandIDs) ? item.boundBrandIDs : [])) {
      const v = String(id || '').trim();
      if (v) ids.add(v);
    }
  }
  return [...ids]
    .map((id) => ({ id, name: String(newsPageState.brandLookupById?.[id] || id) }))
    .sort((a, b) => a.name.localeCompare(b.name, 'zh-Hans-CN'));
}

function newsRefreshFilterSelects() {
  const categorySel = document.getElementById('news-category-filter-select');
  const sourceSel = document.getElementById('news-source-filter-select');
  const brandSel = document.getElementById('news-brand-filter-select');
  if (categorySel) {
    const selected = String(newsPageState.categoryFilter || 'all');
    const options = ['<option value="all">主题：全部</option>']
      .concat(newsCategoryOptionsFromItems().map((value) => `<option value="${escapeHtml(value)}">${escapeHtml(value)}</option>`));
    categorySel.innerHTML = options.join('');
    categorySel.value = selected;
    if (categorySel.value !== selected) {
      newsPageState.categoryFilter = 'all';
      categorySel.value = 'all';
    }
  }
  if (sourceSel) {
    const selected = String(newsPageState.sourceFilter || 'all');
    const options = ['<option value="all">发布方：全部</option>']
      .concat(newsSourceOptionsFromItems().map((value) => `<option value="${escapeHtml(value)}">${escapeHtml(value)}</option>`));
    sourceSel.innerHTML = options.join('');
    sourceSel.value = selected;
    if (sourceSel.value !== selected) {
      newsPageState.sourceFilter = 'all';
      sourceSel.value = 'all';
    }
  }
  if (brandSel) {
    const selected = String(newsPageState.brandFilter || 'all');
    const options = ['<option value="all">关联 Brand：全部</option>']
      .concat(newsBrandOptionsFromItems().map((row) => `<option value="${escapeHtml(row.id)}">${escapeHtml(row.name)}</option>`));
    brandSel.innerHTML = options.join('');
    brandSel.value = selected;
    if (brandSel.value !== selected) {
      newsPageState.brandFilter = 'all';
      brandSel.value = 'all';
    }
  }
}

function newsItemMatchesFilters(item) {
  const searchQuery = normalizeNewsSearchText(newsPageState.searchQuery);
  const categoryFilter = String(newsPageState.categoryFilter || 'all');
  const sourceFilter = String(newsPageState.sourceFilter || 'all');
  const brandFilter = String(newsPageState.brandFilter || 'all');
  const bindingFilter = String(newsPageState.bindingFilter || 'all');
  if (categoryFilter !== 'all' && String(item?.category || '') !== categoryFilter) return false;
  if (sourceFilter !== 'all' && String(item?.source || '') !== sourceFilter) return false;
  if (brandFilter !== 'all' && !(Array.isArray(item?.boundBrandIDs) && item.boundBrandIDs.includes(brandFilter))) return false;

  const hasBrand = Array.isArray(item?.boundBrandIDs) && item.boundBrandIDs.length > 0;
  const hasEvent = Array.isArray(item?.boundEventIDs) && item.boundEventIDs.length > 0;
  const hasDJ = Array.isArray(item?.boundDjIDs) && item.boundDjIDs.length > 0;
  if (bindingFilter === 'has_brand' && !hasBrand) return false;
  if (bindingFilter === 'has_event' && !hasEvent) return false;
  if (bindingFilter === 'has_dj' && !hasDJ) return false;
  if (bindingFilter === 'unbound' && (hasBrand || hasEvent || hasDJ)) return false;

  if (!searchQuery) return true;
  const blob = [
    item?.title,
    item?.category,
    item?.source,
    item?.summary,
    item?.body,
    item?.authorName,
    item?.authorUsername,
    item?.boundBrandIDs?.map((id) => newsPageState.brandLookupById?.[id] || id).join(' '),
    item?.boundDjIDs?.map((id) => newsPageState.djLookupById?.[id] || id).join(' '),
    item?.boundEventIDs?.map((id) => newsPageState.eventLookupById?.[id] || id).join(' '),
  ]
    .map((part) => String(part || ''))
    .join(' ');
  return normalizeNewsSearchText(blob).includes(searchQuery);
}

function newsSortItems(items) {
  const mode = String(newsPageState.sortMode || 'published_desc');
  const rows = Array.isArray(items) ? [...items] : [];
  rows.sort((a, b) => {
    const ad = new Date(a?.publishedAt || 0).getTime() || 0;
    const bd = new Date(b?.publishedAt || 0).getTime() || 0;
    if (mode === 'published_asc') return ad - bd;
    if (mode === 'title_asc') return String(a?.title || '').localeCompare(String(b?.title || ''), 'zh-Hans-CN');
    if (mode === 'source_asc') return String(a?.source || '').localeCompare(String(b?.source || ''), 'zh-Hans-CN');
    if (mode === 'category_asc') return String(a?.category || '').localeCompare(String(b?.category || ''), 'zh-Hans-CN');
    return bd - ad;
  });
  return rows;
}

function newsApplyFiltersSortAndRender() {
  const source = Array.isArray(newsPageState.allItems) ? newsPageState.allItems : [];
  const filtered = newsSortItems(source.filter((item) => newsItemMatchesFilters(item)));
  newsPageState.filteredItems = filtered;
  renderNewsList();
  updateNewsToolbarMeta();
  if (currentAppPage === 'news') setNewsHeaderCounter();
}

function updateNewsToolbarMeta() {
  const el = document.getElementById('news-toolbar-meta');
  if (!el) return;
  const total = Array.isArray(newsPageState.allItems) ? newsPageState.allItems.length : 0;
  const shown = Array.isArray(newsPageState.filteredItems) ? newsPageState.filteredItems.length : 0;
  el.textContent = `总计 ${total} · 当前 ${shown}`;
}

function newsBindingLabel(type, id) {
  const rawId = String(id || '').trim();
  if (!rawId) return '';
  if (type === 'brand') return String(newsPageState.brandLookupById?.[rawId] || rawId);
  if (type === 'event') return String(newsPageState.eventLookupById?.[rawId] || rawId);
  return String(newsPageState.djLookupById?.[rawId] || rawId);
}

function newsRenderBindingMeta(item) {
  const brands = (Array.isArray(item?.boundBrandIDs) ? item.boundBrandIDs : []).map((id) => newsBindingLabel('brand', id));
  const events = (Array.isArray(item?.boundEventIDs) ? item.boundEventIDs : []).map((id) => newsBindingLabel('event', id));
  const djs = (Array.isArray(item?.boundDjIDs) ? item.boundDjIDs : []).map((id) => newsBindingLabel('dj', id));
  const parts = [];
  if (brands.length) parts.push(`Brand ${brands.slice(0, 2).join(' / ')}${brands.length > 2 ? ` +${brands.length - 2}` : ''}`);
  if (events.length) parts.push(`Event ${events.slice(0, 2).join(' / ')}${events.length > 2 ? ` +${events.length - 2}` : ''}`);
  if (djs.length) parts.push(`DJ ${djs.slice(0, 2).join(' / ')}${djs.length > 2 ? ` +${djs.length - 2}` : ''}`);
  return parts.join(' · ') || '未关联对象';
}

function newsGroupKey(item) {
  const mode = String(newsPageState.groupMode || 'none');
  if (mode === 'category') return String(item?.category || '未分类');
  if (mode === 'source') return String(item?.source || '未知发布方');
  if (mode === 'brand') {
    const firstBrandId = Array.isArray(item?.boundBrandIDs) ? String(item.boundBrandIDs[0] || '').trim() : '';
    if (!firstBrandId) return '未关联 Brand';
    return newsBindingLabel('brand', firstBrandId);
  }
  return '';
}

function newsCreateRowElement(item) {
  const row = document.createElement('article');
  row.className = 'news-row';
  const coverUrl = ttToAbsoluteLocalUrl(item?.coverImageURL || '');
  const coverHtml = coverUrl
    ? `<div class="news-row-cover"><img src="${escapeHtml(coverUrl)}" alt="${escapeHtml(String(item?.title || 'news cover'))}" loading="lazy"></div>`
    : '<div class="news-row-cover"><div class="news-row-cover-fallback">NO COVER</div></div>';
  row.innerHTML = `
    ${coverHtml}
    <div class="news-row-main">
      <div class="news-row-title">${escapeHtml(item?.title || 'Untitled News')}</div>
      <div class="news-row-meta">${escapeHtml(String(item?.category || '未分类'))} · ${escapeHtml(String(item?.source || '未知来源'))}</div>
      <div class="news-row-meta">发布时间 ${escapeHtml(newsFormatDateText(item?.publishedAt))} · 评论 ${escapeHtml(String(Number(item?.commentCount || 0)))}</div>
      <div class="news-row-meta">发布者 ${escapeHtml(String(item?.authorName || item?.authorUsername || 'Unknown'))}</div>
      <div class="news-row-summary">${escapeHtml(String(item?.summary || '暂无摘要'))}</div>
      <div class="news-row-meta">${escapeHtml(newsRenderBindingMeta(item))}</div>
    </div>
    <div class="news-row-actions">
      <button class="news-row-btn" type="button">编辑</button>
      <button class="news-row-btn delete" type="button">删除</button>
    </div>
  `;
  const [editBtn, deleteBtn] = row.querySelectorAll('.news-row-btn');
  if (editBtn) {
    editBtn.addEventListener('click', () => openNewsEditorEdit(String(item?.id || '')));
  }
  if (deleteBtn) {
    deleteBtn.addEventListener('click', () => quickDeleteNewsById(String(item?.id || '')));
  }
  return row;
}

function renderNewsList() {
  const wrap = document.getElementById('news-list-wrap');
  if (!wrap) return;
  const rows = Array.isArray(newsPageState.filteredItems) ? newsPageState.filteredItems : [];
  if (!rows.length) {
    wrap.innerHTML = '<div class="news-empty">暂无匹配资讯，尝试调整筛选条件。</div>';
    return;
  }
  const mode = String(newsPageState.groupMode || 'none');
  wrap.innerHTML = '';
  if (mode === 'none') {
    const frag = document.createDocumentFragment();
    for (const item of rows) frag.appendChild(newsCreateRowElement(item));
    wrap.appendChild(frag);
    return;
  }
  const groups = new Map();
  for (const item of rows) {
    const key = newsGroupKey(item) || '其他';
    if (!groups.has(key)) groups.set(key, []);
    groups.get(key).push(item);
  }
  for (const [key, list] of groups.entries()) {
    const section = document.createElement('section');
    section.className = 'news-group';
    section.innerHTML = `
      <div class="news-group-head">
        <div class="news-group-title">${escapeHtml(String(key || '其他'))}</div>
        <div class="news-group-count">${escapeHtml(String(list.length))} 条</div>
      </div>
    `;
    for (const item of list) section.appendChild(newsCreateRowElement(item));
    wrap.appendChild(section);
  }
}
