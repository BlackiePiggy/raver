function triggerNewsMediaFileSelect() {
  const input = document.getElementById('news-media-file-input');
  if (input) input.click();
}

function onNewsMediaDragOver(event) {
  event.preventDefault();
  event.stopPropagation();
  const zone = document.getElementById('news-media-dropzone');
  if (zone) zone.classList.add('dragover');
}

function onNewsMediaDragLeave(event) {
  event.preventDefault();
  event.stopPropagation();
  const zone = document.getElementById('news-media-dropzone');
  if (zone) zone.classList.remove('dragover');
}

async function onNewsMediaDrop(event) {
  event.preventDefault();
  event.stopPropagation();
  const zone = document.getElementById('news-media-dropzone');
  if (zone) zone.classList.remove('dragover');
  const files = event.dataTransfer?.files;
  if (!files || !files.length) return;
  await uploadNewsMediaFromFileList(files);
}

async function uploadNewsMediaFromFileList(fileList) {
  const draft = newsPageState.editorDraft;
  if (!draft || newsPageState.editorUploading || newsPageState.editorSaving || newsPageState.editorDeleting) {
    return { uploadedItems: [], successCount: 0, total: 0 };
  }
  const files = Array.from(fileList || []).filter((file) => file instanceof File && /^image\//i.test(String(file.type || '')));
  if (!files.length) {
    setNewsEditStatus('未检测到可上传的图片文件', 'err');
    return { uploadedItems: [], successCount: 0, total: 0 };
  }
  const headers = getViewerAuthHeaders();
  if (!headers.Authorization) {
    openViewerLogin();
    setNewsEditStatus('请先登录后再上传图片', 'err');
    return { uploadedItems: [], successCount: 0, total: files.length };
  }

  const inferredScope = newsInferUploadScopeFromCoverUrl(draft.coverImageURL);
  const postId = String(inferredScope.postId || draft.id || '').trim();
  const inferredNewsKey = String(inferredScope.newsKey || '').trim();
  const nextNewsKey = inferredNewsKey || String(draft.uploadNewsKey || '').trim() || newsCreateUploadDraftKey();
  if (!postId) draft.uploadNewsKey = nextNewsKey;

  newsPageState.editorUploading = true;
  renderNewsEditorFromDraft();
  let successCount = 0;
  const uploadedItems = [];
  try {
    for (const file of files) {
      const form = new FormData();
      form.append('image', file);
      if (postId) {
        form.append('postId', postId);
      } else {
        form.append('newsKey', nextNewsKey);
      }
      setNewsEditStatus(`正在上传图片 ${successCount + 1}/${files.length}...`);
      const resp = await apiPostForm('/api/raver/feed/upload-image', form, headers);
      const payload = (resp && typeof resp === 'object' && resp.data && typeof resp.data === 'object') ? resp.data : resp;
      const nextUrl = String(payload?.url || '').trim();
      if (!nextUrl) continue;
      const resources = newsDraftAllImageResources(draft);
      if (!resources.length) {
        newsSetDraftImageResources(draft, [nextUrl]);
      } else {
        newsSetDraftImageResources(draft, [...resources, nextUrl]);
      }
      draft.sessionUploadedResources = Array.from(
        new Set(
          (Array.isArray(draft.sessionUploadedResources) ? draft.sessionUploadedResources : [])
            .concat([nextUrl])
            .map((x) => String(x || '').trim())
            .filter(Boolean)
        )
      );
      uploadedItems.push({
        fileName: String(file?.name || '').trim(),
        mimeType: String(file?.type || payload?.mimeType || '').trim(),
        url: nextUrl,
      });
      successCount += 1;
    }
    if (successCount > 0) {
      setNewsEditStatus(`图片上传完成：成功 ${successCount}/${files.length}`, 'ok');
    } else {
      setNewsEditStatus('图片上传失败：未返回可用 URL', 'err');
    }
  } catch (error) {
    setNewsEditStatus(`图片上传失败：${String(error?.message || '未知错误')}`, 'err');
  } finally {
    newsPageState.editorUploading = false;
    newsSaveEditorDraftSnapshot();
    renderNewsEditorFromDraft();
  }
  return {
    uploadedItems,
    successCount,
    total: files.length,
  };
}

async function uploadNewsMediaFiles() {
  const fileInput = document.getElementById('news-media-file-input');
  const files = fileInput?.files;
  if (!files || !files.length) {
    setNewsEditStatus('请先选择图片文件', 'err');
    return;
  }
  await uploadNewsMediaFromFileList(files);
  if (fileInput) fileInput.value = '';
}

async function cleanupNewsDraftMediaResources(draft) {
  const currentDraft = (draft && typeof draft === 'object') ? draft : null;
  if (!currentDraft) return { deleted: 0 };
  const newsKey = String(currentDraft.uploadNewsKey || '').trim();
  const urls = Array.from(
    new Set(
      (Array.isArray(currentDraft.sessionUploadedResources) ? currentDraft.sessionUploadedResources : [])
        .map((x) => String(x || '').trim())
        .filter(Boolean)
    )
  );
  if (!newsKey && !urls.length) return { deleted: 0 };
  const headers = getViewerAuthHeaders();
  if (!headers.Authorization) return { deleted: 0 };
  const payload = {
    newsKey,
    urls,
  };
  const resp = await apiPost('/api/raver/feed/draft-media/cleanup', payload, headers);
  const data = (resp && typeof resp === 'object' && resp.data && typeof resp.data === 'object') ? resp.data : resp;
  return {
    deleted: Number(data?.deleted || 0) || 0,
  };
}
