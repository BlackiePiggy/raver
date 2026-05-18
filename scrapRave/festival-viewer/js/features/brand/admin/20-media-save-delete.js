// Brand admin module extracted from 00-brand-admin (media upload + save + delete)
async function uploadBrandImageAsset(kind) {
  const draft = brandPageState.editorDraft;
  if (!draft) return;
  if (draft.canEdit === false || brandPageState.editorDeleting) return;
  syncBrandDraftFromForm();
  const fileInputId = kind === 'avatar' ? 'brand-avatar-file' : 'brand-cover-file';
  const usage = kind === 'avatar' ? 'avatar' : 'background';
  const input = document.getElementById(fileInputId);
  const file = input?.files?.[0];
  if (!file) {
    setBrandEditStatus(`请先选择${kind === 'avatar' ? '头像' : '封面'}图片`, 'err');
    return;
  }
  const authHeaders = getViewerAuthHeaders();
  if (!authHeaders.Authorization) {
    openViewerLogin();
    setBrandEditStatus('请先登录后再上传图片', 'err');
    return;
  }

  brandPageState.editorUploading = true;
  renderBrandEditorFromDraft();
  setBrandEditStatus(`正在上传${kind === 'avatar' ? '头像' : '封面'}...`);
  try {
    const form = new FormData();
    form.append('image', file);
    form.append('usage', usage);
    if (draft.id) form.append('brandId', String(draft.id));
    const resp = await apiPostForm('/api/raver/wiki/brands/upload-image', form, authHeaders);
    const payload = (resp && typeof resp === 'object' && resp.data && typeof resp.data === 'object') ? resp.data : resp;
    const url = String(payload?.url || '').trim();
    if (!url) throw new Error('上传成功但未返回 URL');
    if (kind === 'avatar') draft.avatarUrl = url;
    else draft.backgroundUrl = url;
    if (input) input.value = '';
    renderBrandEditorFromDraft();
    setBrandEditStatus(`已上传${kind === 'avatar' ? '头像' : '封面'}`, 'ok');
  } catch (error) {
    setBrandEditStatus(`上传失败：${String(error?.message || '未知错误')}`, 'err');
  } finally {
    brandPageState.editorUploading = false;
    renderBrandEditorFromDraft();
  }
}

async function saveBrandEditor() {
  const draft = brandPageState.editorDraft;
  if (!draft) return;
  if (brandPageState.editorDeleting) return;
  if (draft.canEdit === false) {
    setBrandEditStatus('当前账号无编辑权限', 'err');
    return;
  }
  const authHeaders = getViewerAuthHeaders();
  if (!authHeaders.Authorization) {
    openViewerLogin();
    setBrandEditStatus('请先登录后再保存', 'err');
    return;
  }

  let payload;
  try {
    payload = collectBrandEditorPayload();
  } catch (error) {
    setBrandEditStatus(String(error?.message || 'links 格式错误'), 'err');
    return;
  }
  if (!payload.name) {
    setBrandEditStatus('名称为必填项', 'err');
    return;
  }

  brandPageState.editorSaving = true;
  renderBrandEditorFromDraft();
  setBrandEditStatus('正在保存...');
  try {
    if (draft.id) {
      await apiPost(`/api/raver/learn/festivals/${encodeURIComponent(draft.id)}/update`, payload, authHeaders);
    } else {
      await apiPost('/api/raver/learn/festivals', payload, authHeaders);
    }
    setBrandEditStatus('保存成功', 'ok');
    await ensureBrandPageLoaded(true);
    closeBrandEditor();
    setBrandStatus('Brand 保存成功');
  } catch (error) {
    setBrandEditStatus(`保存失败：${String(error?.message || '未知错误')}`, 'err');
  } finally {
    brandPageState.editorSaving = false;
    renderBrandEditorFromDraft();
  }
}

async function deleteBrandEditor() {
  const draft = brandPageState.editorDraft;
  if (!draft || !draft.id) return;
  if (brandPageState.editorSaving || brandPageState.editorUploading || brandPageState.editorDeleting) return;
  if (draft.canEdit === false) {
    setBrandEditStatus('当前账号无删除权限', 'err');
    return;
  }

  const brandName = String(draft.name || draft.id).trim() || String(draft.id);
  const sure = window.confirm(
    `确认删除 Brand「${brandName}」吗？\n\n此操作会删除数据库记录，并清理该 Brand 在 OSS 上的资源，无法撤销。`
  );
  if (!sure) return;

  const authHeaders = getViewerAuthHeaders();
  if (!authHeaders.Authorization) {
    openViewerLogin();
    setBrandEditStatus('请先登录后再删除', 'err');
    return;
  }

  brandPageState.editorDeleting = true;
  renderBrandEditorFromDraft();
  setBrandEditStatus('正在删除...');
  try {
    await apiPost(`/api/raver/learn/festivals/${encodeURIComponent(String(draft.id))}/delete`, {}, authHeaders);
    await ensureBrandPageLoaded(true);
    closeBrandEditor();
    setBrandStatus(`已删除 Brand：${brandName}`);
  } catch (error) {
    const msg = String(error?.message || '未知错误');
    if (msg.includes('Unauthorized') || msg.includes('401')) {
      openViewerLogin();
      setBrandEditStatus('删除失败：登录已失效，请重新登录', 'err');
    } else if (msg.includes('403')) {
      setBrandEditStatus('删除失败：当前账号无删除权限', 'err');
    } else {
      setBrandEditStatus(`删除失败：${msg}`, 'err');
    }
  } finally {
    brandPageState.editorDeleting = false;
    if (brandPageState.editorOpen) {
      renderBrandEditorFromDraft();
    }
  }
}
