// Feature module extracted from monolith (news editor render + media)
const NEWS_EDITOR_DRAFT_STORAGE_KEY = 'raver.viewer.newsEditorDraft.v1';

function cloneNewsEditorDraft(item, isNew = false) {
  const source = (item && typeof item === 'object') ? item : {};
  const defaultDisplayPublishedAt = newsToDateTimeLocalInputValue(new Date().toISOString());
  const normalizedDisplayPublishedAt = String(
    source.displayPublishedAt ??
    source.publishedAt ??
    source.display_published_at ??
    ''
  ).trim();
  return {
    isNew: !!isNew,
    id: String(source.id || '').trim(),
    title: String(source.title || '').trim(),
    category: String(source.category || '').trim() || '电音节',
    source: String(source.source || '').trim() || 'Community',
    summary: String(source.summary || '').trim(),
    body: String(source.body || '').trim(),
    link: String(source.link || '').trim(),
    coverImageURL: String(source.coverImageURL || '').trim(),
    bodyImageURLs: Array.from(new Set((Array.isArray(source.bodyImageURLs) ? source.bodyImageURLs : []).map((x) => String(x || '').trim()).filter(Boolean))),
    location: String(source.location || '').trim(),
    displayPublishedAt: newsToDateTimeLocalInputValue(normalizedDisplayPublishedAt) || (isNew ? defaultDisplayPublishedAt : ''),
    firstPublishedAt: String(source.firstPublishedAt ?? source.createdAt ?? '').trim(),
    lastModifiedAt: String(source.lastModifiedAt ?? source.updatedAt ?? '').trim(),
    importWechatUrl: String(source.importWechatUrl || '').trim(),
    boundDjIDs: newsDedupIDs(source.boundDjIDs),
    boundBrandIDs: newsDedupIDs(source.boundBrandIDs),
    boundEventIDs: newsDedupIDs(source.boundEventIDs),
    uploadNewsKey: String(source.uploadNewsKey || '').trim(),
    sessionUploadedResources: Array.from(new Set(
      (Array.isArray(source.sessionUploadedResources) ? source.sessionUploadedResources : [])
        .map((x) => String(x || '').trim())
        .filter(Boolean)
    )),
  };
}

function newsClearEditorDraftSnapshot() {
  try {
    window.localStorage?.removeItem(NEWS_EDITOR_DRAFT_STORAGE_KEY);
  } catch (_error) {}
}

function newsSaveEditorDraftSnapshot() {
  const draft = newsPageState.editorDraft;
  if (!draft || !newsPageState.editorOpen) return;
  try {
    const payload = {
      version: 1,
      savedAt: Date.now(),
      draft: cloneNewsEditorDraft(draft, !!draft.isNew),
    };
    window.localStorage?.setItem(NEWS_EDITOR_DRAFT_STORAGE_KEY, JSON.stringify(payload));
  } catch (_error) {}
}

function newsLoadEditorDraftSnapshot() {
  try {
    const raw = String(window.localStorage?.getItem(NEWS_EDITOR_DRAFT_STORAGE_KEY) || '').trim();
    if (!raw) return null;
    const parsed = JSON.parse(raw);
    if (!parsed || typeof parsed !== 'object') return null;
    const draftPayload = parsed.draft;
    if (!draftPayload || typeof draftPayload !== 'object' || Array.isArray(draftPayload)) return null;
    return {
      savedAt: Number(parsed.savedAt || 0) || 0,
      draft: cloneNewsEditorDraft(draftPayload, !!draftPayload.isNew),
    };
  } catch (_error) {
    return null;
  }
}

function newsRecoverEditorDraftForOpen(targetId = '') {
  const snapshot = newsLoadEditorDraftSnapshot();
  if (!snapshot || !snapshot.draft) return null;
  const draft = snapshot.draft;
  const expectedId = String(targetId || '').trim();
  if (expectedId) {
    if (String(draft.id || '').trim() !== expectedId) return null;
  } else if (!draft.isNew) {
    return null;
  }
  return draft;
}

function newsCreateUploadDraftKey() {
  return `news-${Date.now().toString(36)}-${Math.random().toString(36).slice(2, 10)}`;
}

function newsInferUploadScopeFromCoverUrl(rawUrl) {
  const src = String(rawUrl || '').trim();
  if (!src) return { postId: '', newsKey: '' };
  const normalized = src.replace(/\\/g, '/');
  const match = normalized.match(/\/news\/([A-Za-z0-9_-]{2,128})\//);
  if (!match) return { postId: '', newsKey: '' };
  const scope = String(match[1] || '').trim();
  if (!scope) return { postId: '', newsKey: '' };
  if (scope.startsWith('post-') && scope.length > 5) {
    return { postId: scope.slice(5), newsKey: '' };
  }
  if (scope.startsWith('draft-') && scope.length > 6) {
    return { postId: '', newsKey: scope.slice(6) };
  }
  return { postId: '', newsKey: scope };
}

function newsDraftAllImageResources(draft) {
  if (!draft || typeof draft !== 'object') return [];
  const urls = [];
  const cover = String(draft.coverImageURL || '').trim();
  if (cover) urls.push(cover);
  const extras = Array.isArray(draft.bodyImageURLs) ? draft.bodyImageURLs : [];
  for (const raw of extras) {
    const url = String(raw || '').trim();
    if (!url) continue;
    urls.push(url);
  }
  return Array.from(new Set(urls));
}

function newsSetDraftImageResources(draft, urls) {
  if (!draft || typeof draft !== 'object') return;
  const normalized = Array.from(new Set((Array.isArray(urls) ? urls : []).map((x) => String(x || '').trim()).filter(Boolean)));
  draft.coverImageURL = normalized[0] || '';
  draft.bodyImageURLs = normalized.slice(1);
}

function newsNormalizeHttpUrl(raw) {
  const text = String(raw || '').trim();
  if (!/^https?:\/\//i.test(text)) return '';
  return text;
}

function newsRenderMarkdownInline(rawText) {
  let text = escapeHtml(String(rawText || ''));
  text = text.replace(/!\[([^\]]*)\]\((https?:\/\/[^\s)]+)\)/g, (_m, alt, url) => {
    const safe = newsNormalizeHttpUrl(url);
    if (!safe) return '';
    return `<img src="${escapeHtml(safe)}" alt="${escapeHtml(alt || '')}" loading="lazy">`;
  });
  text = text.replace(/\[([^\]]+)\]\((https?:\/\/[^\s)]+)\)/g, (_m, label, url) => {
    const safe = newsNormalizeHttpUrl(url);
    if (!safe) return escapeHtml(label || '');
    return `<a href="${escapeHtml(safe)}" target="_blank" rel="noopener noreferrer">${escapeHtml(label || safe)}</a>`;
  });
  text = text.replace(/`([^`]+)`/g, '<code>$1</code>');
  text = text.replace(/\*\*([^*]+)\*\*/g, '<strong>$1</strong>');
  text = text.replace(/\*([^*]+)\*/g, '<em>$1</em>');
  return text;
}

function newsRenderMarkdownHtml(markdownText) {
  const src = String(markdownText || '').replace(/\r\n/g, '\n');
  if (!src.trim()) return '<p style="color:var(--text-dim);">暂无正文</p>';
  const lines = src.split('\n');
  const out = [];
  let inCode = false;
  let codeLines = [];
  let listType = '';
  let paragraph = [];

  const flushParagraph = () => {
    if (!paragraph.length) return;
    out.push(`<p>${newsRenderMarkdownInline(paragraph.join(' '))}</p>`);
    paragraph = [];
  };
  const flushList = () => {
    if (!listType) return;
    out.push(`</${listType}>`);
    listType = '';
  };

  for (const rawLine of lines) {
    const line = String(rawLine || '');
    const trimmed = line.trim();

    if (trimmed.startsWith('```')) {
      flushParagraph();
      flushList();
      if (!inCode) {
        inCode = true;
        codeLines = [];
      } else {
        out.push(`<pre><code>${escapeHtml(codeLines.join('\n'))}</code></pre>`);
        inCode = false;
        codeLines = [];
      }
      continue;
    }
    if (inCode) {
      codeLines.push(line);
      continue;
    }

    if (!trimmed) {
      flushParagraph();
      flushList();
      continue;
    }

    const heading = trimmed.match(/^(#{1,6})\s+(.+)$/);
    if (heading) {
      flushParagraph();
      flushList();
      const level = Math.min(6, Math.max(1, heading[1].length));
      out.push(`<h${level}>${newsRenderMarkdownInline(heading[2])}</h${level}>`);
      continue;
    }

    if (/^---+$/.test(trimmed)) {
      flushParagraph();
      flushList();
      out.push('<hr>');
      continue;
    }

    const quote = trimmed.match(/^>\s?(.*)$/);
    if (quote) {
      flushParagraph();
      flushList();
      out.push(`<blockquote>${newsRenderMarkdownInline(quote[1] || '')}</blockquote>`);
      continue;
    }

    const ul = trimmed.match(/^[-*]\s+(.+)$/);
    if (ul) {
      flushParagraph();
      if (!listType) {
        listType = 'ul';
        out.push('<ul>');
      } else if (listType !== 'ul') {
        flushList();
        listType = 'ul';
        out.push('<ul>');
      }
      out.push(`<li>${newsRenderMarkdownInline(ul[1])}</li>`);
      continue;
    }

    const ol = trimmed.match(/^\d+\.\s+(.+)$/);
    if (ol) {
      flushParagraph();
      if (!listType) {
        listType = 'ol';
        out.push('<ol>');
      } else if (listType !== 'ol') {
        flushList();
        listType = 'ol';
        out.push('<ol>');
      }
      out.push(`<li>${newsRenderMarkdownInline(ol[1])}</li>`);
      continue;
    }

    flushList();
    paragraph.push(trimmed);
  }

  if (inCode) {
    out.push(`<pre><code>${escapeHtml(codeLines.join('\n'))}</code></pre>`);
  }
  flushParagraph();
  flushList();
  return out.join('');
}

function newsRenderMarkdownPreview() {
  const draft = newsPageState.editorDraft;
  const target = document.getElementById('news-md-preview');
  if (!target) return;
  target.innerHTML = newsRenderMarkdownHtml(draft?.body || '');
}

function newsInsertTextAtCursor(inputEl, text) {
  if (!inputEl) return;
  const value = String(inputEl.value || '');
  const start = Number.isFinite(inputEl.selectionStart) ? inputEl.selectionStart : value.length;
  const end = Number.isFinite(inputEl.selectionEnd) ? inputEl.selectionEnd : value.length;
  const before = value.slice(0, start);
  const after = value.slice(end);
  inputEl.value = `${before}${text}${after}`;
  const cursor = before.length + text.length;
  inputEl.setSelectionRange(cursor, cursor);
}

function newsInsertResourceIntoBody(url) {
  const draft = newsPageState.editorDraft;
  const safe = String(url || '').trim();
  if (!draft || !safe) return;
  const editor = document.getElementById('news-edit-body-input');
  if (editor) {
    const snippet = `\n![image](${safe})\n`;
    newsInsertTextAtCursor(editor, snippet);
    draft.body = String(editor.value || '');
  } else {
    draft.body = `${String(draft.body || '').trim()}\n![image](${safe})\n`.trim();
  }
  newsRenderMarkdownPreview();
  newsSaveEditorDraftSnapshot();
  setNewsEditStatus('已插入图片 Markdown');
}

function newsSetCoverFromResource(url) {
  const draft = newsPageState.editorDraft;
  const safe = String(url || '').trim();
  if (!draft || !safe) return;
  const all = newsDraftAllImageResources(draft).filter((item) => item !== safe);
  newsSetDraftImageResources(draft, [safe, ...all]);
  const coverInput = document.getElementById('news-edit-cover-input');
  if (coverInput) coverInput.value = draft.coverImageURL;
  newsRenderNewsResourceList();
  newsSaveEditorDraftSnapshot();
  setNewsEditStatus('已设为封面图', 'ok');
}

function newsRemoveResource(url) {
  const draft = newsPageState.editorDraft;
  const safe = String(url || '').trim();
  if (!draft || !safe) return;
  const next = newsDraftAllImageResources(draft).filter((item) => item !== safe);
  newsSetDraftImageResources(draft, next);
  const coverInput = document.getElementById('news-edit-cover-input');
  if (coverInput) coverInput.value = draft.coverImageURL;
  newsRenderNewsResourceList();
  newsSaveEditorDraftSnapshot();
  setNewsEditStatus('已移除资源');
}

function newsRenderNewsResourceList() {
  const draft = newsPageState.editorDraft;
  const wrap = document.getElementById('news-resource-list');
  if (!wrap || !draft) return;
  const resources = newsDraftAllImageResources(draft);
  if (!resources.length) {
    wrap.innerHTML = '<div class="news-cover-upload-hint">暂无图片资源。上传后可在这里插入正文或设为封面。</div>';
    return;
  }
  wrap.innerHTML = resources.map((url) => {
    const isCover = String(draft.coverImageURL || '').trim() === url;
    const thumb = `<div class="news-resource-thumb"><img src="${escapeHtml(url)}" alt="news-resource" loading="lazy"></div>`;
    return `
      <div class="news-resource-item">
        ${thumb}
        <div class="news-resource-meta">
          ${isCover ? '<span class="news-resource-badge">cover</span>' : ''}
          <div class="news-resource-url">${escapeHtml(url)}</div>
        </div>
        <div class="news-resource-actions">
          <button class="news-resource-btn" type="button" onclick="newsInsertResourceIntoBody('${escapeHtml(String(url).replace(/'/g, "\\'"))}')">插入正文</button>
          ${isCover ? '' : `<button class="news-resource-btn" type="button" onclick="newsSetCoverFromResource('${escapeHtml(String(url).replace(/'/g, "\\'"))}')">设为封面</button>`}
          <button class="news-resource-btn danger" type="button" onclick="newsRemoveResource('${escapeHtml(String(url).replace(/'/g, "\\'"))}')">移除</button>
        </div>
      </div>
    `;
  }).join('');
}
