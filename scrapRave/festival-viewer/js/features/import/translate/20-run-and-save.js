// Feature module extracted from 00-translate-batch (run + save)
const importTranslateStateRun = (function resolveImportTranslateStateForRun() {
  const facade = window.ImportStateFacade;
  if (facade && typeof facade.translateState === 'function') return facade.translateState();
  return {
    get batch() {
      return translateBatchState;
    },
    set batch(value) {
      translateBatchState = (value && typeof value === 'object') ? value : null;
    },
  };
})();

async function runTranslateBatch() {
  const st = importTranslateStateRun.batch;
  if (!st || st.running) return;
  const selected = getVisibleTranslateEntries(st).filter(x => x.selected);
  if (!selected.length) {
    translateSetModalStatus('当前筛选范围内请至少勾选一个活动。', true);
    return;
  }

  st.running = true;
  st.updatedCount = 0;
  st.skippedCount = 0;
  st.failedCount = 0;
  translateSetModalStatus('');
  translateRefreshButtonState();
  renderTranslateFestivalList();
  renderTranslateProgressList();

  try {
    for (let i = 0; i < selected.length; i += 1) {
      const entry = selected[i];
      entry.status = 'running';
      entry.message = `进度 ${i + 1}/${selected.length}`;
      entry.original = null;
      entry.draft = null;
      entry.applySelected = false;
      translateSetRunStatus(`翻译中 ${i + 1}/${selected.length}：${entry.fest?.name || entry.fest?.folder || ''}`);
      renderTranslateFestivalList();
      renderTranslateProgressList();

      try {
        const res = await translateSingleFestivalWithCoze(entry.fest);
        if (res.skipped) {
          entry.status = 'skipped';
          entry.message = res.reason || '已跳过';
          st.skippedCount += 1;
        } else {
          entry.original = res.original || null;
          entry.draft = res.draft || null;
          if (st.requireConfirm) {
            entry.status = 'ready';
            entry.message = `请确认：${(res.changedFields || []).join('、') || '字段'}`;
            entry.applySelected = true;
            st.updatedCount += 1;
          } else {
            await applyTranslateDraftEntry(entry);
            entry.status = 'saved';
            entry.message = `已自动保存：${(res.changedFields || []).join('、') || '字段'}`;
            entry.applySelected = false;
            st.updatedCount += 1;
          }
        }
      } catch (err) {
        entry.status = 'error';
        entry.message = err?.message || '未知错误';
        st.failedCount += 1;
      }
      renderTranslateFestivalList();
      renderTranslateProgressList();
    }
  } catch (err) {
    translateSetModalStatus(`批量翻译中断：${err?.message || '未知错误'}`, true);
  } finally {
    st.running = false;
    translateRefreshButtonState();
  }

  const savedCount = st.entries.filter(x => String(x.status || '') === 'saved').length;
  const readyCount = st.entries.filter(x => String(x.status || '') === 'ready').length;
  if (st.requireConfirm) {
    translateSetRunStatus(`翻译完成：待确认 ${readyCount}，已跳过 ${st.skippedCount}，失败 ${st.failedCount}`);
    translateSetModalStatus(
      st.failedCount > 0
        ? `批量翻译完成（失败 ${st.failedCount} 个，详见右侧进度）`
        : `批量翻译完成（待确认 ${readyCount} 个，跳过 ${st.skippedCount} 个）`,
      st.failedCount > 0
    );
  } else {
    if (savedCount > 0) {
      await rebuildLibraryIndex('翻译结果已自动保存，正在刷新索引...', { preserveView: true });
    }
    translateSetRunStatus(`翻译完成：自动保存 ${savedCount}，跳过 ${st.skippedCount}，失败 ${st.failedCount}`);
    translateSetModalStatus(
      st.failedCount > 0
        ? `自动保存完成：成功 ${savedCount}，失败 ${st.failedCount}`
        : `自动保存完成：已写入 ${savedCount} 个活动`,
      st.failedCount > 0
    );
  }
}

async function confirmTranslateBatchSave() {
  const st = importTranslateStateRun.batch;
  if (!st || st.running) return;
  if (!st.requireConfirm) {
    translateSetModalStatus('当前为自动写入模式，无需手动确认保存。');
    return;
  }
  const targets = st.entries.filter(x => String(x.status || '') === 'ready' && x.applySelected && x.draft);
  if (!targets.length) {
    translateSetModalStatus('请先勾选至少一个待确认结果。', true);
    return;
  }

  st.running = true;
  translateRefreshButtonState();
  translateSetModalStatus('正在写入 JSON ...');
  let saved = 0;
  let failed = 0;

  try {
    for (let i = 0; i < targets.length; i += 1) {
      const entry = targets[i];
      entry.status = 'running';
      entry.message = `保存 ${i + 1}/${targets.length}`;
      translateSetRunStatus(`保存中 ${i + 1}/${targets.length}：${entry.fest?.name || entry.fest?.folder || ''}`);
      renderTranslateProgressList();

      try {
        await applyTranslateDraftEntry(entry);
        entry.status = 'saved';
        entry.message = '已保存';
        entry.applySelected = false;
        saved += 1;
      } catch (err) {
        entry.status = 'error';
        entry.message = err?.message || '保存失败';
        failed += 1;
      }
      renderTranslateProgressList();
    }

    await rebuildLibraryIndex('翻译结果已保存，正在刷新索引...', { preserveView: true });
    translateSetRunStatus(`保存完成：成功 ${saved}，失败 ${failed}`);
    translateSetModalStatus(
      failed > 0 ? `保存完成：成功 ${saved}，失败 ${failed}` : `保存完成：已写入 ${saved} 个活动`,
      failed > 0
    );
  } finally {
    st.running = false;
    translateRefreshButtonState();
  }
}
