// DJ profile editor module extracted from 00-edit-and-source (basic fields + avatar uploader)
function renderDJAliasChips(aliases) {
  const list = Array.isArray(aliases) ? aliases.filter(Boolean) : [];
  if (!list.length) return '<div class="dj-mini-meta">暂无别名</div>';
  return `<div class="dj-alias-chips">${list.map((name) => `<span class="dj-alias-chip">${escapeHtml(name)}</span>`).join('')}</div>`;
}

function renderDJGenreChips(genres) {
  const list = Array.isArray(genres) ? genres.filter(Boolean) : [];
  if (!list.length) return '<div class="dj-mini-meta">暂无风格</div>';
  return `<div class="dj-alias-chips">${list.map((name) => `<span class="dj-alias-chip">${escapeHtml(name)}</span>`).join('')}</div>`;
}

function splitDJAliasesInput(value) {
  return String(value || '')
    .split(/[,\n/，、]+/g)
    .map((item) => item.trim())
    .filter(Boolean);
}

function splitDJGenresInput(value) {
  return String(value || '')
    .split(/[,\n/，、|;]+/g)
    .map((item) => item.trim())
    .filter(Boolean);
}

function parseOptionalNonNegativeInt(value) {
  const trimmed = String(value ?? '').trim();
  if (!trimmed) return null;
  if (!/^\d+$/.test(trimmed)) return null;
  return Math.max(0, Math.floor(Number(trimmed)));
}

function nullableTrimmed(value) {
  const trimmed = String(value ?? '').trim();
  return trimmed ? trimmed : null;
}

function setDJEditStatus(text, type = '') {
  const el = document.getElementById('dj-edit-status');
  if (!el) return;
  el.textContent = String(text || '');
  el.classList.remove('err', 'ok');
  if (type) el.classList.add(type);
}

function refreshDJEditAvatarUploaderUI() {
  const detail = djProfileState?.detail || {};
  const name = String(detail?.name || 'Unknown DJ').trim() || 'Unknown DJ';
  const initial = escapeHtml(name.charAt(0).toUpperCase() || '?');
  const previewUrl = String(djProfileState?.avatarPreviewUrl || detail?.avatarUrl || '').trim();
  const queuedFile = djProfileState?.avatarFile instanceof File ? djProfileState.avatarFile : null;

  const previewEl = document.getElementById('dj-edit-avatar-preview');
  if (previewEl) {
    previewEl.innerHTML = previewUrl
      ? `<img src="${escapeHtml(previewUrl)}" alt="${escapeHtml(name)}">`
      : `<div class="dj-profile-avatar-fallback">${initial}</div>`;
  }

  const hintEl = document.getElementById('dj-edit-avatar-file-hint');
  if (hintEl) {
    if (queuedFile) {
      const sizeKB = Math.max(1, Math.round(Number(queuedFile.size || 0) / 1024));
      hintEl.textContent = `已选择新头像：${queuedFile.name}（${sizeKB} KB）`;
    } else {
      hintEl.textContent = '未选择新头像，保存时保持当前头像。';
    }
  }

  const clearBtn = document.getElementById('dj-edit-avatar-clear-btn');
  if (clearBtn) {
    clearBtn.disabled = !queuedFile;
  }
}

function clearDJEditAvatarSelection(options = {}) {
  const clearInput = !!(options && options.clearInput);
  const silent = !!(options && options.silent);
  const currentPreviewUrl = String(djProfileState?.avatarPreviewUrl || '').trim();
  if (currentPreviewUrl.startsWith('blob:')) {
    try {
      URL.revokeObjectURL(currentPreviewUrl);
    } catch (_error) {
      // ignore
    }
  }
  djProfileState.avatarFile = null;
  djProfileState.avatarPreviewUrl = '';
  if (clearInput) {
    const fileInput = document.getElementById('dj-edit-avatar-file');
    if (fileInput) fileInput.value = '';
  }
  refreshDJEditAvatarUploaderUI();
  if (!silent) {
    setDJEditStatus('已清空待替换头像。', '');
  }
}

function handleDJEditAvatarFileChange(event) {
  const input = event?.target || document.getElementById('dj-edit-avatar-file');
  const file = input?.files?.[0] || null;
  if (!(file instanceof File)) {
    clearDJEditAvatarSelection({ clearInput: false, silent: true });
    return;
  }
  const previousPreview = String(djProfileState?.avatarPreviewUrl || '').trim();
  if (previousPreview.startsWith('blob:')) {
    try {
      URL.revokeObjectURL(previousPreview);
    } catch (_error) {
      // ignore
    }
  }
  djProfileState.avatarFile = file;
  djProfileState.avatarPreviewUrl = URL.createObjectURL(file);
  refreshDJEditAvatarUploaderUI();
  setDJEditStatus('已选择新头像，点击“保存到数据库”后将上传并替换旧 OSS 头像。', '');
}

