function newsEditorDraftById(newsId) {
  const target = String(newsId || '').trim();
  if (!target) return null;
  const hit = (Array.isArray(newsPageState.allItems) ? newsPageState.allItems : []).find((item) => String(item?.id || '').trim() === target);
  return hit ? cloneNewsEditorDraft(hit, false) : null;
}

function newsEnsureCategoryOption(selectEl, value) {
  if (!selectEl || selectEl.tagName !== 'SELECT') return;
  const category = String(value || '').trim();
  if (!category) return;
  const hasOption = Array.from(selectEl.options || []).some((option) => String(option?.value || '').trim() === category);
  if (hasOption) return;
  const dynamic = document.createElement('option');
  dynamic.value = category;
  dynamic.textContent = `${category}（历史值）`;
  dynamic.dataset.dynamic = '1';
  selectEl.appendChild(dynamic);
}

function renderNewsBindingChips(type) {
  const draft = newsPageState.editorDraft;
  const wrap = document.getElementById(`news-bind-${type}-chip-wrap`);
  if (!wrap) return;
  const key = type === 'brand' ? 'boundBrandIDs' : (type === 'event' ? 'boundEventIDs' : 'boundDjIDs');
  const rows = Array.isArray(draft?.[key]) ? draft[key] : [];
  if (!rows.length) {
    wrap.innerHTML = '<span class="news-edit-hint">暂无关联</span>';
    return;
  }
  wrap.innerHTML = rows.map((id) => `
    <span class="news-bind-chip">
      <span>${escapeHtml(newsBindingLabel(type, id))}</span>
      <button type="button" onclick="newsRemoveBinding('${type}', '${escapeHtml(String(id).replace(/'/g, "\\'"))}')">×</button>
    </span>
  `).join('');
}

function renderNewsEditorFromDraft() {
  const draft = newsPageState.editorDraft;
  const overlay = document.getElementById('news-editor-overlay');
  if (!overlay || !draft) return;
  const setVal = (id, value) => {
    const el = document.getElementById(id);
    if (el && el.value !== String(value ?? '')) el.value = String(value ?? '');
  };
  setVal('news-edit-title-input', draft.title);
  const categoryEl = document.getElementById('news-edit-category-input');
  if (categoryEl) {
    newsEnsureCategoryOption(categoryEl, draft.category);
    categoryEl.value = String(draft.category || '电音节').trim() || '电音节';
  }
  setVal('news-edit-source-input', draft.source);
  setVal('news-edit-summary-input', draft.summary);
  setVal('news-edit-body-input', draft.body);
  setVal('news-edit-link-input', draft.link);
  setVal('news-edit-cover-input', draft.coverImageURL);
  setVal('news-edit-location-input', draft.location);
  setVal('news-edit-display-published-at-input', draft.displayPublishedAt);
  setVal('news-wechat-link-input', draft.importWechatUrl);
  const systemTimeMetaEl = document.getElementById('news-edit-system-time-meta');
  if (systemTimeMetaEl) {
    systemTimeMetaEl.innerHTML = [
      `首次发布时间：${escapeHtml(newsFormatDateText(draft.firstPublishedAt))}`,
      `最后修改时间：${escapeHtml(newsFormatDateText(draft.lastModifiedAt))}`,
    ].join('<br>');
  }

  const titleEl = document.getElementById('news-editor-title');
  const subEl = document.getElementById('news-editor-sub');
  if (titleEl) titleEl.textContent = draft.isNew ? '新增资讯' : `编辑资讯 · ${draft.title || draft.id || '-'}`;
  if (subEl) subEl.textContent = draft.isNew ? '创建新的资讯对象并保存到数据库' : '编辑资讯字段并保存回数据库';

  const busy = !!newsPageState.editorSaving || !!newsPageState.editorDeleting || !!newsPageState.editorUploading;
  const fieldIds = [
    'news-edit-title-input',
    'news-edit-category-input',
    'news-edit-source-input',
    'news-edit-summary-input',
    'news-edit-body-input',
    'news-edit-link-input',
    'news-edit-cover-input',
    'news-edit-location-input',
    'news-edit-display-published-at-input',
    'news-wechat-link-input',
    'news-bind-dj-input',
    'news-bind-brand-input',
    'news-bind-event-input',
  ];
  for (const id of fieldIds) {
    const el = document.getElementById(id);
    if (el) el.disabled = busy;
  }
  const saveBtn = document.getElementById('news-save-btn');
  const deleteBtn = document.getElementById('news-delete-btn');
  const coverSelectBtn = document.getElementById('news-media-select-btn');
  const coverUploadBtn = document.getElementById('news-media-upload-btn');
  const wechatImportBtn = document.getElementById('news-wechat-import-btn');
  const wechatImportRunBtn = document.getElementById('news-wechat-import-run-btn');
  const coverClearBtn = document.getElementById('news-cover-clear-btn');
  const coverFileInput = document.getElementById('news-media-file-input');
  const coverHint = document.getElementById('news-cover-upload-hint');
  const mediaDropZone = document.getElementById('news-media-dropzone');
  if (saveBtn) saveBtn.disabled = busy;
  if (deleteBtn) {
    deleteBtn.disabled = busy || !!draft.isNew;
    deleteBtn.style.display = draft.isNew ? 'none' : 'inline-block';
  }
  if (coverSelectBtn) coverSelectBtn.disabled = busy;
  if (coverUploadBtn) coverUploadBtn.disabled = busy;
  if (wechatImportBtn) wechatImportBtn.disabled = busy;
  if (wechatImportRunBtn) wechatImportRunBtn.disabled = busy;
  if (coverClearBtn) coverClearBtn.disabled = busy;
  if (coverFileInput) coverFileInput.disabled = busy;
  if (mediaDropZone) mediaDropZone.style.pointerEvents = busy ? 'none' : 'auto';
  if (coverHint) {
    const fileCount = Number(coverFileInput?.files?.length || 0);
    if (newsPageState.editorUploading) {
      coverHint.textContent = '正在上传到 OSS...';
    } else if (fileCount > 0) {
      coverHint.textContent = `已选择 ${fileCount} 个文件，点击“上传到 OSS”完成上传。`;
    } else {
      coverHint.textContent = '支持 jpg/png/webp，封面和正文图片统一上传并进入资源库。';
    }
  }

  newsRenderNewsResourceList();
  renderNewsBindingChips('dj');
  renderNewsBindingChips('brand');
  renderNewsBindingChips('event');
  newsRenderMarkdownPreview();
  newsSaveEditorDraftSnapshot();
}

function openNewsEditorCreate() {
  const recovered = newsRecoverEditorDraftForOpen('');
  newsPageState.editorDraft = recovered || cloneNewsEditorDraft({}, true);
  newsPageState.editorOpen = true;
  newsPageState.editorSaving = false;
  newsPageState.editorUploading = false;
  newsPageState.editorDeleting = false;
  setNewsEditStatus(recovered ? '已恢复未完成草稿，可继续编辑。' : '');
  const overlay = document.getElementById('news-editor-overlay');
  if (overlay) overlay.classList.add('open');
  document.body.style.overflow = 'hidden';
  renderNewsEditorFromDraft();
}

function openNewsEditorEdit(newsId) {
  const draft = newsEditorDraftById(newsId);
  if (!draft) {
    setNewsStatus('未找到要编辑的资讯对象', 'error');
    return;
  }
  const recovered = newsRecoverEditorDraftForOpen(String(draft.id || ''));
  newsPageState.editorDraft = recovered || draft;
  newsPageState.editorOpen = true;
  newsPageState.editorSaving = false;
  newsPageState.editorUploading = false;
  newsPageState.editorDeleting = false;
  setNewsEditStatus(recovered ? '已恢复此资讯的未保存草稿。' : '');
  const overlay = document.getElementById('news-editor-overlay');
  if (overlay) overlay.classList.add('open');
  document.body.style.overflow = 'hidden';
  renderNewsEditorFromDraft();
}

async function closeNewsEditor(options = {}) {
  const opts = (options && typeof options === 'object') ? options : {};
  const shouldCleanupMedia = opts.cleanupMedia !== false;
  const shouldClearSnapshot = opts.clearSnapshot !== false;
  const closingDraft = newsPageState.editorDraft ? cloneNewsEditorDraft(newsPageState.editorDraft, !!newsPageState.editorDraft.isNew) : null;
  if (shouldCleanupMedia && closingDraft) {
    try {
      const cleanup = await cleanupNewsDraftMediaResources(closingDraft);
      if ((Number(cleanup?.deleted || 0) || 0) > 0) {
        setNewsStatus(`已清理未保存草稿资源 ${cleanup.deleted} 个`, 'ok');
      }
    } catch (_error) {
      setNewsStatus('草稿资源清理失败，可稍后重试。', 'error');
    }
  }
  const overlay = document.getElementById('news-editor-overlay');
  if (overlay) overlay.classList.remove('open');
  newsPageState.editorOpen = false;
  newsPageState.editorSaving = false;
  newsPageState.editorUploading = false;
  newsPageState.editorDeleting = false;
  newsPageState.editorDraft = null;
  const coverFileInput = document.getElementById('news-media-file-input');
  if (coverFileInput) coverFileInput.value = '';
  const wechatLinkInput = document.getElementById('news-wechat-link-input');
  if (wechatLinkInput) wechatLinkInput.value = '';
  setNewsEditStatus('');
  if (shouldClearSnapshot) {
    newsClearEditorDraftSnapshot();
  }
  document.body.style.overflow = '';
}

function handleNewsEditorOverlayClick(event) {
  if (event.target === event.currentTarget) closeNewsEditor();
}

function onNewsEditorInputChanged(field, value) {
  const draft = newsPageState.editorDraft;
  if (!draft) return;
  draft[field] = String(value ?? '');
  if (field === 'importWechatUrl') {
    const input = document.getElementById('news-wechat-link-input');
    if (input && input.value !== String(draft.importWechatUrl || '')) {
      input.value = String(draft.importWechatUrl || '');
    }
  }
  if (field === 'coverImageURL') {
    newsRenderNewsResourceList();
  }
  if (field === 'body') {
    newsRenderMarkdownPreview();
  }
  newsSaveEditorDraftSnapshot();
}

function clearNewsCoverUrl() {
  const draft = newsPageState.editorDraft;
  if (!draft) return;
  const currentCover = String(draft.coverImageURL || '').trim();
  if (currentCover) {
    draft.bodyImageURLs = Array.from(
      new Set(
        [currentCover].concat(Array.isArray(draft.bodyImageURLs) ? draft.bodyImageURLs : [])
          .map((x) => String(x || '').trim())
          .filter(Boolean)
      )
    );
  }
  draft.coverImageURL = '';
  const coverInput = document.getElementById('news-edit-cover-input');
  if (coverInput) coverInput.value = '';
  const fileInput = document.getElementById('news-media-file-input');
  if (fileInput) fileInput.value = '';
  draft.sessionUploadedResources = [];
  setNewsEditStatus('已清空封面 URL');
  newsSaveEditorDraftSnapshot();
  newsRenderNewsResourceList();
  renderNewsEditorFromDraft();
}
