function newsNormalizeRemoteImageUrl(rawUrl) {
  let target = String(rawUrl || '').trim();
  if (!target) return '';
  if (
    (target.startsWith('<') && target.endsWith('>'))
    || (target.startsWith('"') && target.endsWith('"'))
    || (target.startsWith("'") && target.endsWith("'"))
  ) {
    target = target.slice(1, -1).trim();
  }
  return target.replace(/&amp;/gi, '&');
}

function newsNormalizeRemoteImageUrlWithoutQuery(rawUrl) {
  const target = newsNormalizeRemoteImageUrl(rawUrl);
  if (!target) return '';
  return String(target.split('#')[0] || '').split('?')[0] || '';
}

function newsGuessImageExtFromRemoteUrl(rawUrl, mimeType = '') {
  const mime = String(mimeType || '').toLowerCase();
  if (mime.includes('jpeg') || mime.includes('jpg')) return 'jpg';
  if (mime.includes('png')) return 'png';
  if (mime.includes('webp')) return 'webp';
  if (mime.includes('gif')) return 'gif';
  if (mime.includes('bmp')) return 'bmp';
  if (mime.includes('svg')) return 'svg';
  if (mime.includes('avif')) return 'avif';
  const normalized = newsNormalizeRemoteImageUrlWithoutQuery(rawUrl).toLowerCase();
  const extMatch = normalized.match(/\.([a-z0-9]{2,8})$/i);
  if (!extMatch) return 'jpg';
  const ext = String(extMatch[1] || '').toLowerCase();
  const allow = ['jpg', 'jpeg', 'png', 'webp', 'gif', 'bmp', 'svg', 'avif', 'heic', 'heif'];
  if (!allow.includes(ext)) return 'jpg';
  return ext === 'jpeg' ? 'jpg' : ext;
}

function newsGuessImageMimeType(fileName) {
  const lower = String(fileName || '').toLowerCase();
  if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
  if (lower.endsWith('.png')) return 'image/png';
  if (lower.endsWith('.webp')) return 'image/webp';
  if (lower.endsWith('.gif')) return 'image/gif';
  if (lower.endsWith('.bmp')) return 'image/bmp';
  if (lower.endsWith('.svg')) return 'image/svg+xml';
  if (lower.endsWith('.avif')) return 'image/avif';
  if (lower.endsWith('.heic')) return 'image/heic';
  if (lower.endsWith('.heif')) return 'image/heif';
  return 'application/octet-stream';
}

function newsNormalizeWechatPublishTime(rawValue) {
  const src = String(rawValue || '').trim();
  if (!src) return '';

  if (/^\d{10,13}$/.test(src)) {
    const numeric = Number(src);
    if (Number.isFinite(numeric) && numeric > 0) {
      const millis = src.length === 10 ? numeric * 1000 : numeric;
      const byEpoch = new Date(millis);
      if (!Number.isNaN(byEpoch.getTime())) {
        return newsToDateTimeLocalInputValue(byEpoch.toISOString());
      }
    }
  }

  const normalized = src
    .replace(/[年/.]/g, '-')
    .replace(/月/g, '-')
    .replace(/日/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();
  const candidates = [src, normalized];
  for (const candidate of candidates) {
    const parsed = new Date(candidate);
    if (!Number.isNaN(parsed.getTime())) {
      return newsToDateTimeLocalInputValue(parsed.toISOString());
    }
  }
  return '';
}

function newsResolveWechatValueByPath(payload, path) {
  if (!payload || typeof payload !== 'object' || !path) return '';
  const segments = String(path).split('.').map((item) => item.trim()).filter(Boolean);
  if (!segments.length) return '';
  let cursor = payload;
  for (const segment of segments) {
    if (!cursor || typeof cursor !== 'object' || Array.isArray(cursor)) return '';
    cursor = cursor[segment];
  }
  return String(cursor == null ? '' : cursor).trim();
}

function newsResolveWechatAuthor(payload) {
  const keys = [
    'author',
    'authorName',
    'author_name',
    'source',
    'sourceName',
    'mediaName',
    'media_name',
    'accountName',
    'account_name',
    'nickname',
    'bizName',
    'biz_name',
    'meta.author',
    'meta.source',
  ];
  for (const key of keys) {
    const value = newsResolveWechatValueByPath(payload, key);
    if (value) return value;
  }
  return '';
}

function newsResolveWechatPublishTime(payload, sourceUrl = '') {
  const keys = [
    'publishTime',
    'publish_time',
    'publishedAt',
    'published_at',
    'publishAt',
    'publish_at',
    'publishDate',
    'publish_date',
    'date',
    'datetime',
    'createTime',
    'create_time',
    'ctime',
    'meta.publishTime',
    'meta.publish_time',
    'meta.publishedAt',
    'meta.date',
  ];
  for (const key of keys) {
    const raw = newsResolveWechatValueByPath(payload, key);
    const normalized = newsNormalizeWechatPublishTime(raw);
    if (normalized) return normalized;
  }

  try {
    const parsedUrl = new URL(String(sourceUrl || '').trim());
    const queryKeys = ['publish_time', 'publishTime', 'published_at', 'publishedAt', 'create_time', 'createTime', 't'];
    for (const key of queryKeys) {
      const raw = String(parsedUrl.searchParams.get(key) || '').trim();
      const normalized = newsNormalizeWechatPublishTime(raw);
      if (normalized) return normalized;
    }
  } catch (_error) {}

  return '';
}

async function newsBuildUploadFilesFromRemoteImages(imageUrls) {
  const base = getScraperApiBase();
  const rows = [];
  const urls = Array.from(
    new Set(
      (Array.isArray(imageUrls) ? imageUrls : [])
        .map((x) => newsNormalizeRemoteImageUrl(x))
        .filter(Boolean)
    )
  );
  for (let idx = 0; idx < urls.length; idx += 1) {
    const sourceUrl = urls[idx];
    try {
      const proxied = `${base}/api/proxy-image?url=${encodeURIComponent(sourceUrl)}`;
      const response = await fetch(proxied);
      if (!response.ok) continue;
      const blob = await response.blob();
      const ext = newsGuessImageExtFromRemoteUrl(sourceUrl, blob?.type || '');
      const fileName = `wechat-${String(idx + 1).padStart(3, '0')}.${ext}`;
      const fileType = String(blob?.type || newsGuessImageMimeType(`dummy.${ext}`)).trim() || 'application/octet-stream';
      rows.push({
        sourceUrl,
        fileName,
        file: new File([blob], fileName, { type: fileType }),
      });
    } catch (_error) {}
  }
  return rows;
}

function newsRewriteMarkdownRemoteImageUrls(markdownText, remoteToUploadedMap) {
  const src = String(markdownText || '');
  if (!src) return '';
  const map = remoteToUploadedMap instanceof Map ? remoteToUploadedMap : new Map();
  if (!map.size) return src;
  return src.replace(/!\[([^\]]*)\]\(([^)]+)\)/g, (full, alt, rawUrl) => {
    const normalized = newsNormalizeRemoteImageUrl(rawUrl);
    const normalizedNoQuery = newsNormalizeRemoteImageUrlWithoutQuery(rawUrl);
    const replaced = String(
      map.get(normalized)
      || map.get(normalizedNoQuery)
      || ''
    ).trim();
    if (!replaced) return full;
    return `![${String(alt || '')}](${replaced})`;
  });
}

async function importNewsFromWechatLink() {
  const draft = newsPageState.editorDraft;
  if (!draft) {
    setNewsEditStatus('请先打开资讯编辑器再导入链接。', 'err');
    return;
  }
  if (newsPageState.editorUploading || newsPageState.editorSaving || newsPageState.editorDeleting) {
    setNewsEditStatus('当前有进行中的操作，请稍后再导入链接。', 'err');
    return;
  }
  const headers = getViewerAuthHeaders();
  if (!headers.Authorization) {
    openViewerLogin();
    setNewsEditStatus('请先登录后再导入公众号链接。', 'err');
    return;
  }
  const linkInput = document.getElementById('news-wechat-link-input');
  const sourceUrl = String(linkInput?.value || draft.importWechatUrl || '').trim();
  if (!sourceUrl) {
    setNewsEditStatus('请先输入公众号文章链接。', 'err');
    return;
  }
  draft.importWechatUrl = sourceUrl;
  newsSaveEditorDraftSnapshot();
  try {
    setNewsEditStatus('正在抓取公众号文章并解析 Markdown...');
    const importedResp = await apiPost('/api/viewer/news/import-wechat', { url: sourceUrl });
    const importedData = (importedResp && typeof importedResp === 'object' && importedResp.data && typeof importedResp.data === 'object')
      ? importedResp.data
      : importedResp;
    const title = String(importedData?.title || '').trim();
    const author = newsResolveWechatAuthor(importedData);
    const publishTime = newsResolveWechatPublishTime(importedData, sourceUrl);
    const markdown = String(importedData?.markdown || '').trim();
    const imageUrls = Array.isArray(importedData?.imageUrls) ? importedData.imageUrls : [];
    if (!markdown) {
      throw new Error('未解析到正文内容');
    }

    const remoteImageRows = await newsBuildUploadFilesFromRemoteImages(imageUrls);
    const uploadFiles = remoteImageRows.map((row) => row.file);
    const remoteUrlByFileName = new Map(
      remoteImageRows.map((row) => [String(row.fileName || ''), String(row.sourceUrl || '')])
    );
    const remoteToUploadedMap = new Map();
    if (uploadFiles.length) {
      setNewsEditStatus(`公众号正文解析完成，正在上传图片 0/${uploadFiles.length}...`);
      const uploadResult = await uploadNewsMediaFromFileList(uploadFiles);
      const uploadedItems = Array.isArray(uploadResult?.uploadedItems) ? uploadResult.uploadedItems : [];
      for (const item of uploadedItems) {
        const localName = String(item?.fileName || '').trim();
        const uploadedUrl = String(item?.url || '').trim();
        const sourceImgUrl = String(remoteUrlByFileName.get(localName) || '').trim();
        if (!uploadedUrl || !sourceImgUrl) continue;
        remoteToUploadedMap.set(newsNormalizeRemoteImageUrl(sourceImgUrl), uploadedUrl);
        remoteToUploadedMap.set(newsNormalizeRemoteImageUrlWithoutQuery(sourceImgUrl), uploadedUrl);
      }
    }

    const nextBody = newsRewriteMarkdownRemoteImageUrls(markdown, remoteToUploadedMap);
    if (title) draft.title = title;
    if (!String(draft.category || '').trim()) draft.category = '电音节';
    draft.link = sourceUrl;
    draft.body = nextBody;
    if (author) {
      draft.source = author;
    } else if (!String(draft.source || '').trim() || String(draft.source || '').trim() === 'Community') {
      draft.source = '微信公众号';
    }
    if (publishTime) {
      draft.displayPublishedAt = publishTime;
    }
    if (!String(draft.summary || '').trim()) {
      draft.summary = String(importedData?.summary || '').trim();
    }

    renderNewsEditorFromDraft();
    const uploadedCount = Array.from(new Set(Array.from(remoteToUploadedMap.values()))).length;
    const totalCount = remoteImageRows.length;
    const publishTimeHint = publishTime ? `，发布时间：${publishTime}` : '，发布时间未识别，保留当前展示发布时间';
    setNewsEditStatus(
      `链接导入完成：标题/正文已回填，图片 ${uploadedCount}/${totalCount} 已上传并替换为 OSS${publishTimeHint}`,
      'ok'
    );
  } catch (error) {
    setNewsEditStatus(`链接导入失败：${String(error?.message || '未知错误')}`, 'err');
  }
}
