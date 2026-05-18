async function deleteFestival(fest, deleteBtn) {
  const displayName = fest.info?.name || fest.name || fest.folder;

  const oldText = deleteBtn ? deleteBtn.textContent : '';
  if (deleteBtn) {
    deleteBtn.disabled = true;
    deleteBtn.textContent = '删除中...';
  }

  try {
    if (fest?.backendEventId) {
      const headers = getViewerAuthHeaders();
      if (!headers.Authorization) throw new Error('未登录，无法删除后端活动');
      await apiPost(`/api/raver/events/${encodeURIComponent(String(fest.backendEventId))}/delete`, {}, headers);
      releaseFestivalImageObjectUrls(fest);
      await removeEventCacheEventDir(fest.backendEventId);
      await rebuildLibraryIndex('活动已删除，正在刷新后端索引...', { preserveView: true });
      setImportStatus(`已删除后端活动：${displayName}`);
      return;
    }

    if (!fest?.yearHandle || !fest?.folder) {
      throw new Error('无法定位活动目录');
    }
    const granted = await verifyPermission(fest.yearHandle, true);
    if (!granted) throw new Error('没有获得删除权限');
    await fest.yearHandle.removeEntry(fest.folder, { recursive: true });
    await rebuildLibraryIndex('活动已删除，正在刷新索引...', { preserveView: true });
    setImportStatus(`已删除：${displayName}`);
  } catch (e) {
    setImportStatus(`删除失败：${e.message}`, true);
    alert(`删除失败：${e.message}`);
  } finally {
    if (deleteBtn) {
      deleteBtn.disabled = false;
      deleteBtn.textContent = oldText;
    }
  }
}

async function openFestivalFolder(fest, openBtn, statusEl) {
  let relPath = '';
  let scopeCandidates = ['brands'];
  let statusPrefix = '活动文件夹';
  try {
    if (rootDirHandle && fest?.dirHandle && typeof rootDirHandle.resolve === 'function') {
      const rel = await rootDirHandle.resolve(fest.dirHandle);
      if (Array.isArray(rel) && rel.length) relPath = rel.join('/');
    }
  } catch (_) {}

  if (!relPath && fest?.backendEventId) {
    const safeEventId = normalizeEventCacheEventId(fest.backendEventId);
    relPath = `${EVENT_IMAGE_CACHE_DIRNAME}/${EVENT_IMAGE_CACHE_EVENTS_DIRNAME}/${safeEventId}`;
    // Cache directory may live under brands root (preferred) or project root.
    scopeCandidates = ['brands', 'project'];
    statusPrefix = '本地缓存文件夹';
  }

  if (!relPath) {
    relPath = [String(fest?.year || ''), String(fest?.folder || '')].filter(Boolean).join('/');
  }
  if (!relPath) {
    if (statusEl) statusEl.textContent = '无法定位活动文件夹路径';
    return;
  }

  const oldText = openBtn?.textContent || '打开文件夹';
  if (openBtn) {
    openBtn.disabled = true;
    openBtn.textContent = '打开中...';
  }
  if (statusEl) statusEl.textContent = `正在打开${statusPrefix}：${relPath}`;
  try {
    let opened = false;
    let lastError = null;
    for (const scope of scopeCandidates) {
      try {
        await apiPost('/api/open-folder', { relative_path: relPath, scope });
        opened = true;
        break;
      } catch (error) {
        lastError = error;
      }
    }
    if (!opened) {
      throw (lastError || new Error(`无法打开路径：${relPath}`));
    }
    if (statusEl) statusEl.textContent = `已在系统中打开${statusPrefix}`;
  } catch (e) {
    if (statusEl) statusEl.textContent = `打开${statusPrefix}失败：${e.message}`;
  } finally {
    if (openBtn) {
      openBtn.disabled = false;
      openBtn.textContent = oldText;
    }
  }
}

