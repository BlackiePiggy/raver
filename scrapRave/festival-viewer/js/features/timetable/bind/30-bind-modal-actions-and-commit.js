function ttOpenDJBindModalFromEntityCell(rid, performerIndex = null) {
  const slot = ttGetDraftSlotByRid(rid);
  if (!slot) return;
  const index = Number.isInteger(performerIndex) ? performerIndex : null;
  if (index == null) {
    ttOpenDJBindModal(rid, 'existing');
    return;
  }
  const performers = ttExtractCollaborativePerformers(slot?.musician || '');
  const performerName = String(performers[index] || '').trim();
  ttOpenDJBindModal(rid, 'existing', {
    performerName,
    performerIndex: index,
  });
}

function ttRenderBoundEntityItemHtml(label, explicitId, boundDJ, rid, performerIndex = null) {
  const isBound = !!String(explicitId || '').trim();
  const entityText = isBound
    ? (boundDJ?.name ? `${String(boundDJ.name).trim()} (${String(explicitId).trim()})` : `ID: ${String(explicitId).trim()}`)
    : '未绑定';
  const indexArg = Number.isInteger(performerIndex) ? performerIndex : 'null';
  return `
    <div class="tt-dj-entity-item">
      <div class="tt-dj-entity-main">
        <div class="tt-dj-entity-label">${escapeHtml(label)}</div>
        <div class="tt-dj-entity-value">${escapeHtml(entityText)}</div>
      </div>
      <button class="tt-dj-bind-btn" onclick="ttOpenDJBindModalFromEntityCell(${rid}, ${indexArg})">搜索更改</button>
    </div>
  `;
}

function ttRenderBoundEntitiesCellHtml(slot) {
  const rid = Number(slot?._rid);
  const performers = ttExtractCollaborativePerformers(slot?.musician || '');
  if (performers.length >= 2) {
    const rows = performers.map((performerName, performerIndex) => {
      const explicitId = ttGetExplicitPerformerDJId(slot, performerIndex);
      const boundDJ = ttFindBoundDJById(explicitId);
      return ttRenderBoundEntityItemHtml(
        performerName || `成员${performerIndex + 1}`,
        explicitId,
        boundDJ,
        rid,
        performerIndex
      );
    }).join('');
    return `<div class="tt-dj-entity-list">${rows}</div>`;
  }

  const explicitId = ttGetExplicitSlotDJId(slot);
  const boundDJ = ttFindBoundDJById(explicitId);
  const musicianName = String(slot?.musician || '').trim() || '该表演';
  return `
    <div class="tt-dj-entity-list">
      ${ttRenderBoundEntityItemHtml(musicianName, explicitId, boundDJ, rid, null)}
    </div>
  `;
}

function ttSetBindStatus(text, type = '') {
  const el = document.getElementById('tt-dj-bind-status');
  if (!el) return;
  el.textContent = String(text || '');
  el.classList.remove('err', 'ok');
  if (type) el.classList.add(type);
}

function ttClearSlotDJBinding(rid) {
  if (!ttEditMode || ttSaving) return;
  const slot = ttGetDraftSlotByRid(rid);
  if (!slot) return;
  delete slot.djId;
  delete slot.djIds;
  setTtEditStatus('已清除该条表演的 DJ 绑定。');
  renderTtModalBody();
}

function ttCloseBindStatus() {
  ttSetBindStatus('');
}

async function ttCommitQuickBindChanges() {
  if (!ttQuickBindMode || ttSaving || !ttCurrentFest) return;
  ttSaving = true;
  setTtEditStatus('正在保存 DJ 绑定...');
  syncTtModalActionState();
  try {
    const cleaned = (ttDraftLineup || [])
      .filter((x) => {
        const m = String(x?.musician || '').trim();
        const d = String(x?.date || '').trim();
        const t = String(x?.time || '').trim();
        const s = String(x?.stage || '').trim();
        return m || d || t || s;
      })
      .map((x) => {
        const copy = { ...x };
        delete copy._rid;
        return normalizeLineupEntry(copy);
      });
    const payload = {
      ...ttCurrentFest.info,
      lineup: dedupeLineupEntries(cleaned),
    };
    await persistFestivalPayload(ttCurrentFest, payload);

    if (ttCurrentRowEl) {
      refreshFestHeaderDisplay(ttCurrentRowEl, ttCurrentFest);
      const panel = ttCurrentRowEl.querySelector('.fest-info-panel');
      if (panel) {
        renderInfoView(panel, ttCurrentFest.info);
        if (panel.classList.contains('is-editing')) setEditInputs(panel, ttCurrentFest.info);
      }
    }

    ttDraftLineup = [];
    ttQuickBindMode = false;
    setTtEditStatus(`已保存 DJ 绑定 ${new Date().toLocaleTimeString()}`);
    renderTtModalBody();
  } catch (error) {
    ttQuickBindMode = false;
    ttDraftLineup = [];
    setTtEditStatus(`DJ 绑定保存失败：${String(error?.message || '未知错误')}`, true);
  } finally {
    ttSaving = false;
    syncTtModalActionState();
  }
}

function ttBindSlotToDJ(slot, dj) {
  if (!slot || !dj?.id) return;
  const bindDjId = String(dj.id).trim();
  const hasPerformerBindingTarget =
    Number.isInteger(ttDJBindState.performerIndex) &&
    ttDJBindState.performerIndex >= 0;
  if (hasPerformerBindingTarget) {
    const performerIndex = ttDJBindState.performerIndex;
    const ids = ttBuildCollaborativeDjIds(slot);
    while (ids.length < performerIndex) ids.push(LINEUP_DJ_ID_PLACEHOLDER);
    ids[performerIndex] = bindDjId;
    while (ids.length && !ttNormalizeDJId(ids[ids.length - 1])) ids.pop();
    if (ids.length) slot.djIds = ids;
    else delete slot.djIds;
    if (ttNormalizeDJId(ids[0])) slot.djId = ttNormalizeDJId(ids[0]);
    else delete slot.djId;
  } else {
    slot.djId = bindDjId;
    delete slot.djIds;
  }
  const label = String(dj.name || dj.id);
  const performerName = String(ttDJBindState.performerName || '').trim();
  if (ttQuickBindMode) {
    if (hasPerformerBindingTarget) {
      setTtEditStatus(`已为 ${performerName || '该成员'} 绑定 DJ：${label}，正在自动保存...`);
    } else {
      setTtEditStatus(`已选择 DJ：${label}，正在自动保存...`);
    }
    void ttCommitQuickBindChanges();
    return;
  }
  if (hasPerformerBindingTarget) {
    setTtEditStatus(`已为 ${performerName || '该成员'} 绑定 DJ：${label}`);
  } else {
    setTtEditStatus(`已将该表演绑定到 DJ：${label}`);
  }
  renderTtModalBody();
}

