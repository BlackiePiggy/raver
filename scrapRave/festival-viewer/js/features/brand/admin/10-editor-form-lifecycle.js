// Brand admin module extracted from 00-brand-admin (editor + form lifecycle)
function renderBrandImagePreview(targetId, imageUrl, fallbackText) {
  const el = document.getElementById(targetId);
  if (!el) return;
  const safeUrl = ttToAbsoluteLocalUrl(String(imageUrl || '').trim());
  if (safeUrl) {
    el.innerHTML = `<img src="${escapeHtml(safeUrl)}" alt="preview">`;
    return;
  }
  el.textContent = String(fallbackText || 'NO IMAGE');
}

function renderBrandEditorFromDraft() {
  const draft = brandPageState.editorDraft;
  if (!draft) return;
  const canEdit = !!draft.canEdit;

  const titleEl = document.getElementById('brand-editor-title');
  const subEl = document.getElementById('brand-editor-sub');
  if (titleEl) titleEl.textContent = draft.id ? `编辑 Brand · ${draft.name || draft.id}` : '新增 Brand';
  if (subEl) {
    if (!canEdit && draft.id) {
      subEl.textContent = '当前账号无编辑权限（只读）';
    } else {
      subEl.textContent = draft.id ? '修改后保存会直接更新数据库' : '填写品牌信息并保存到数据库';
    }
  }

  const bind = (id, value) => {
    const el = document.getElementById(id);
    if (el) el.value = String(value || '');
  };
  const nameBi = normalizeBiTextValue(draft.nameI18n ?? draft.name, draft.name || '');
  const countryBi = normalizeBiTextValue(draft.countryI18n ?? draft.country, draft.country || '');
  const cityBi = normalizeBiTextValue(draft.cityI18n ?? draft.city, draft.city || '');
  const frequencyBi = normalizeBiTextValue(draft.frequencyI18n ?? draft.frequency, draft.frequency || '');
  const descriptionBi = normalizeBiTextValue(draft.descriptionI18n ?? draft.introduction, draft.introduction || '');
  bind('brand-edit-name-en', nameBi.en);
  bind('brand-edit-name-zh', nameBi.zh);
  bind('brand-edit-aliases', (Array.isArray(draft.aliases) ? draft.aliases : []).join(', '));
  bind('brand-edit-country-en', countryBi.en);
  bind('brand-edit-country-zh', countryBi.zh);
  bind('brand-edit-city-en', cityBi.en);
  bind('brand-edit-city-zh', cityBi.zh);
  bind('brand-edit-founded-year', draft.foundedYear);
  bind('brand-edit-frequency-en', frequencyBi.en);
  bind('brand-edit-frequency-zh', frequencyBi.zh);
  bind('brand-edit-tagline', draft.tagline);
  bind('brand-edit-introduction-en', descriptionBi.en);
  bind('brand-edit-introduction-zh', descriptionBi.zh);
  bind('brand-edit-links', stringifyBrandLinks(draft.links));

  renderBrandImagePreview(
    'brand-avatar-preview',
    draft.avatarUrl,
    String(draft.name || '?').trim().charAt(0).toUpperCase() || '?'
  );
  renderBrandImagePreview('brand-cover-preview', draft.backgroundUrl, 'NO COVER');

  const formIds = [
    'brand-edit-name-en',
    'brand-edit-name-zh',
    'brand-edit-aliases',
    'brand-edit-country-en',
    'brand-edit-country-zh',
    'brand-edit-city-en',
    'brand-edit-city-zh',
    'brand-edit-founded-year',
    'brand-edit-frequency-en',
    'brand-edit-frequency-zh',
    'brand-edit-tagline',
    'brand-edit-introduction-en',
    'brand-edit-introduction-zh',
    'brand-edit-links',
    'brand-avatar-file',
    'brand-cover-file',
  ];
  const isBusy = !!(brandPageState.editorSaving || brandPageState.editorUploading || brandPageState.editorDeleting);
  for (const id of formIds) {
    const el = document.getElementById(id);
    if (el) el.disabled = !canEdit || isBusy;
  }
  const uploadAvatarBtn = document.getElementById('brand-avatar-upload-btn');
  const uploadCoverBtn = document.getElementById('brand-cover-upload-btn');
  const saveBtn = document.querySelector('#brand-editor-modal .brand-edit-save-btn');
  const deleteBtn = document.getElementById('brand-delete-btn');
  if (uploadAvatarBtn) uploadAvatarBtn.disabled = !canEdit || isBusy;
  if (uploadCoverBtn) uploadCoverBtn.disabled = !canEdit || isBusy;
  if (saveBtn) saveBtn.disabled = !canEdit || isBusy;
  if (deleteBtn) {
    deleteBtn.style.display = draft.id ? '' : 'none';
    deleteBtn.disabled = !canEdit || !draft.id || isBusy;
  }
}

function collectBrandEditorPayload() {
  const getValue = (id) => String(document.getElementById(id)?.value || '').trim();
  const draft = brandPageState.editorDraft || {};
  const links = parseBrandLinksTextarea(getValue('brand-edit-links'));
  const buildBi = (enId, zhId, fallback = '') => normalizeBiTextValue(
    { en: getValue(enId), zh: getValue(zhId) },
    String(fallback || '').trim()
  );
  const nameI18n = buildBi('brand-edit-name-en', 'brand-edit-name-zh', draft.name || '');
  const countryI18n = buildBi('brand-edit-country-en', 'brand-edit-country-zh', draft.country || '');
  const cityI18n = buildBi('brand-edit-city-en', 'brand-edit-city-zh', draft.city || '');
  const frequencyI18n = buildBi('brand-edit-frequency-en', 'brand-edit-frequency-zh', draft.frequency || '');
  const descriptionI18n = buildBi('brand-edit-introduction-en', 'brand-edit-introduction-zh', draft.introduction || '');
  const name = String(nameI18n.zh || nameI18n.en || '').trim();
  const country = String(countryI18n.zh || countryI18n.en || '').trim();
  const city = String(cityI18n.zh || cityI18n.en || '').trim();
  const frequency = String(frequencyI18n.zh || frequencyI18n.en || '').trim();
  const introduction = String(descriptionI18n.zh || descriptionI18n.en || '').trim();
  return {
    name,
    nameI18n,
    aliases: normalizeBrandAliasesInput(getValue('brand-edit-aliases')),
    country,
    countryI18n,
    city,
    cityI18n,
    foundedYear: getValue('brand-edit-founded-year'),
    frequency,
    frequencyI18n,
    tagline: getValue('brand-edit-tagline'),
    introduction,
    descriptionI18n,
    avatarUrl: String(draft.avatarUrl || '').trim(),
    backgroundUrl: String(draft.backgroundUrl || '').trim(),
    links,
  };
}

function openBrandEditorCreate() {
  brandPageState.editorDraft = {
    id: '',
    name: '',
    nameI18n: { en: '', zh: '' },
    aliases: [],
    country: '',
    countryI18n: { en: '', zh: '' },
    city: '',
    cityI18n: { en: '', zh: '' },
    foundedYear: '',
    frequency: '',
    frequencyI18n: { en: '', zh: '' },
    tagline: '',
    introduction: '',
    descriptionI18n: { en: '', zh: '' },
    avatarUrl: '',
    backgroundUrl: '',
    links: [],
    canEdit: true,
  };
  brandPageState.editorOpen = true;
  brandPageState.editorSaving = false;
  brandPageState.editorUploading = false;
  brandPageState.editorDeleting = false;
  setBrandEditStatus('');
  const overlay = document.getElementById('brand-editor-overlay');
  if (overlay) overlay.classList.add('open');
  document.body.style.overflow = 'hidden';
  renderBrandEditorFromDraft();
}

function openBrandEditorEdit(brandId) {
  const id = String(brandId || '').trim();
  if (!id) return;
  const item = (Array.isArray(brandPageState.allItems) ? brandPageState.allItems : [])
    .find((x) => String(x?.id || '').trim() === id);
  if (!item) return;
  brandPageState.editorDraft = {
    ...cloneBrandItem(item),
    canEdit: item.canEdit !== false,
  };
  brandPageState.editorOpen = true;
  brandPageState.editorSaving = false;
  brandPageState.editorUploading = false;
  brandPageState.editorDeleting = false;
  setBrandEditStatus(item.canEdit === false ? '当前账号无编辑权限（只读）' : '');
  const overlay = document.getElementById('brand-editor-overlay');
  if (overlay) overlay.classList.add('open');
  document.body.style.overflow = 'hidden';
  renderBrandEditorFromDraft();
}

function closeBrandEditor() {
  const overlay = document.getElementById('brand-editor-overlay');
  if (overlay) overlay.classList.remove('open');
  if (brandPageState.editorOpen) {
    brandPageState.editorOpen = false;
    brandPageState.editorSaving = false;
    brandPageState.editorUploading = false;
    brandPageState.editorDeleting = false;
    brandPageState.editorDraft = null;
    setBrandEditStatus('');
  }
  document.body.style.overflow = '';
}

function handleBrandEditorOverlayClick(event) {
  if (event.target === event.currentTarget) {
    closeBrandEditor();
  }
}

function clearBrandImageAsset(kind) {
  const draft = brandPageState.editorDraft;
  if (!draft) return;
  syncBrandDraftFromForm();
  if (kind === 'avatar') draft.avatarUrl = '';
  if (kind === 'cover') draft.backgroundUrl = '';
  const fileInput = document.getElementById(kind === 'avatar' ? 'brand-avatar-file' : 'brand-cover-file');
  if (fileInput) fileInput.value = '';
  renderBrandEditorFromDraft();
}

function syncBrandDraftFromForm() {
  const draft = brandPageState.editorDraft;
  if (!draft) return;
  const read = (id) => String(document.getElementById(id)?.value || '').trim();
  const safeParseLinks = (raw) => {
    const text = String(raw || '').trim();
    if (!text) return [];
    try {
      return parseBrandLinksTextarea(text);
    } catch (_error) {
      return Array.isArray(draft.links) ? draft.links : [];
    }
  };

  const nameI18n = normalizeBiTextValue(
    { en: read('brand-edit-name-en'), zh: read('brand-edit-name-zh') },
    draft.name || ''
  );
  const countryI18n = normalizeBiTextValue(
    { en: read('brand-edit-country-en'), zh: read('brand-edit-country-zh') },
    draft.country || ''
  );
  const cityI18n = normalizeBiTextValue(
    { en: read('brand-edit-city-en'), zh: read('brand-edit-city-zh') },
    draft.city || ''
  );
  const frequencyI18n = normalizeBiTextValue(
    { en: read('brand-edit-frequency-en'), zh: read('brand-edit-frequency-zh') },
    draft.frequency || ''
  );
  const descriptionI18n = normalizeBiTextValue(
    { en: read('brand-edit-introduction-en'), zh: read('brand-edit-introduction-zh') },
    draft.introduction || ''
  );

  draft.nameI18n = nameI18n;
  draft.countryI18n = countryI18n;
  draft.cityI18n = cityI18n;
  draft.frequencyI18n = frequencyI18n;
  draft.descriptionI18n = descriptionI18n;
  draft.name = String(nameI18n.zh || nameI18n.en || '').trim();
  draft.aliases = normalizeBrandAliasesInput(read('brand-edit-aliases'));
  draft.country = String(countryI18n.zh || countryI18n.en || '').trim();
  draft.city = String(cityI18n.zh || cityI18n.en || '').trim();
  draft.foundedYear = read('brand-edit-founded-year');
  draft.frequency = String(frequencyI18n.zh || frequencyI18n.en || '').trim();
  draft.tagline = read('brand-edit-tagline');
  draft.introduction = String(descriptionI18n.zh || descriptionI18n.en || '').trim();
  draft.links = safeParseLinks(read('brand-edit-links'));
}

