const TT_DJ_IMPORT_FIELDS = [
  { key: 'name', label: '名称' },
  { key: 'aliases', label: '别名' },
  { key: 'genres', label: 'GENRES' },
  { key: 'bio', label: '简介' },
  { key: 'country', label: '国家' },
  { key: 'website', label: '官网链接' },
  { key: 'spotifyId', label: 'Spotify ID' },
  { key: 'spotifyFollowers', label: 'Spotify Followers' },
  { key: 'instagramUrl', label: 'Instagram URL' },
  { key: 'facebookUrl', label: 'Facebook URL' },
  { key: 'twitterUrl', label: 'X / Twitter URL' },
  { key: 'youtubeUrl', label: 'YouTube URL' },
  { key: 'soundcloudUrl', label: 'SoundCloud URL' },
  { key: 'soundcloudId', label: 'SoundCloud ID' },
  { key: 'trackCount', label: '发歌数量' },
  { key: 'playlistCount', label: '专辑数量' },
  { key: 'soundCloudFollowers', label: 'SoundCloud 粉丝数量' },
  { key: 'soundCloudFavorites', label: 'SoundCloud 点赞数量' },
];
const TT_DJ_IMPORT_SOURCE_KEYS = ['manual', 'spotify', 'discogs', 'soundcloud'];

let ttDJBindState = {
  open: false,
  mode: 'bind',
  rid: null,
  tab: 'existing',
  performerName: '',
  performerIndex: null,
  existingSearch: '',
  existingSelectedId: '',
  onImported: null,
  importState: null,
};

function ttIsLibraryImportMode() {
  return String(ttDJBindState.mode || 'bind') === 'library_import';
}

function ttCreateEmptyImportState(slot = null, preferredName = '') {
  const preferred = String(preferredName || '').trim();
  const slotName = String(slot?.musician || '').trim();
  const defaultName = preferred || (slotName && slotName !== '未知' ? slotName : '');
  return {
    query: defaultName,
    sourceEnabled: { spotify: true, discogs: true, soundcloud: true },
    sources: {
      spotify: { status: 'idle', message: '未抓取', items: [], selectedIndex: -1, fetchedAt: 0 },
      discogs: { status: 'idle', message: '未抓取', items: [], selectedIndex: -1, fetchedAt: 0 },
      soundcloud: { status: 'idle', message: '未抓取', items: [], selectedIndex: -1, fetchedAt: 0 },
    },
    fieldSource: Object.fromEntries(TT_DJ_IMPORT_FIELDS.map((field) => [field.key, 'manual'])),
    avatarSource: 'manual',
    saving: false,
    translating: false,
  };
}

function ttLineupSlotStableKey(slot) {
  const normalized = normalizeLineupEntry(slot || {});
  const djId = String(slot?.djId || '').trim();
  const djIds = Array.isArray(slot?.djIds)
    ? slot.djIds.map((id) => String(id || '').trim()).filter(Boolean).join(',')
    : '';
  return `${normalized.musician}|${normalized.date}|${normalized.time}|${normalized.stage}|${djId}|${djIds}`;
}

function ttGetDraftSlotByRid(rid) {
  if (!Array.isArray(ttDraftLineup) || !ttDraftLineup.length) return null;
  return ttDraftLineup.find((item) => item?._rid === rid) || null;
}

function ttPrepareQuickBindDraftRid(viewSlot) {
  const sourceLineup = Array.isArray(ttCurrentFest?.info?.lineup) ? ttCurrentFest.info.lineup : [];
  if (!sourceLineup.length) return null;
  const draft = toTtDraftRows(sourceLineup);
  const targetKey = ttLineupSlotStableKey(viewSlot);
  let target = draft.find((item) => ttLineupSlotStableKey(item) === targetKey) || null;

  if (!target) {
    const viewNorm = normalizeLineupEntry(viewSlot || {});
    target = draft.find((item) => {
      const rowNorm = normalizeLineupEntry(item || {});
      return (
        rowNorm.musician === viewNorm.musician &&
        rowNorm.date === viewNorm.date &&
        rowNorm.time === viewNorm.time &&
        rowNorm.stage === viewNorm.stage
      );
    }) || null;
  }

  if (!target) return null;
  ttDraftLineup = draft;
  return target._rid;
}

async function ttOpenDJBindModalForViewSlot(viewSlot, preferredTab = 'existing') {
  if (ttSaving || ttEditMode || !ttCurrentFest) return;
  const rid = ttPrepareQuickBindDraftRid(viewSlot);
  if (!rid) {
    setTtEditStatus('无法定位该演出条目，请进入编辑模式后手动绑定。', true);
    return;
  }
  ttQuickBindMode = true;
  setTtEditStatus('快速绑定模式：确认后会自动保存到时间表。');
  await ttOpenDJBindModal(rid, preferredTab, null);
}

async function ttOpenDJBindModalForViewPerformer(
  viewSlot,
  performerName,
  performerIndex,
  preferredTab = 'existing'
) {
  if (ttSaving || ttEditMode || !ttCurrentFest) return;
  const rid = ttPrepareQuickBindDraftRid(viewSlot);
  if (!rid) {
    setTtEditStatus('无法定位该演出条目，请进入编辑模式后手动绑定。', true);
    return;
  }
  ttQuickBindMode = true;
  setTtEditStatus('快速绑定模式：确认后会自动保存到时间表。');
  await ttOpenDJBindModal(rid, preferredTab, {
    performerName: String(performerName || '').trim(),
    performerIndex: Number.isInteger(performerIndex) ? performerIndex : null,
  });
}

function ttGetSlotBindingMeta(slot) {
  const performers = ttExtractCollaborativePerformers(slot?.musician || '');
  if (performers.length >= 2) {
    let boundCount = 0;
    performers.forEach((_performerName, performerIndex) => {
      const explicitId = ttGetExplicitPerformerDJId(slot, performerIndex);
      if (explicitId) {
        boundCount += 1;
      }
    });
    if (boundCount >= performers.length) {
      return { cls: 'ok', text: `已绑定：${performers.length}/${performers.length}` };
    }
    if (boundCount > 0) {
      return { cls: 'miss', text: `部分绑定：${boundCount}/${performers.length}` };
    }
    return { cls: '', text: `未绑定 DJ（${performers.length}位）` };
  }

  const rawDjId = ttGetExplicitSlotDJId(slot);
  if (rawDjId) {
    const linked = ttDjByIdMap.get(rawDjId) || null;
    if (linked) {
      return { cls: 'ok', text: `已绑定：${linked.name}` };
    }
    return { cls: 'miss', text: `已绑定 ID：${rawDjId}（库中未找到）` };
  }
  return { cls: '', text: '未绑定 DJ' };
}

function ttCollectCandidateBindingsForSlot(slot) {
  const out = [];
  const performers = ttExtractCollaborativePerformers(slot?.musician || '');
  if (performers.length >= 2) {
    performers.forEach((performerName, performerIndex) => {
      const explicitId = ttGetExplicitPerformerDJId(slot, performerIndex);
      if (explicitId) return;
      const candidate = ttFindCandidateDJForPerformerName(performerName);
      if (candidate?.id) {
        out.push({
          performerIndex,
          performerName,
          dj: candidate,
        });
      }
    });
    return out;
  }

  const explicitId = ttGetExplicitSlotDJId(slot);
  if (explicitId) return out;
  const musicianName = String(slot?.musician || '').trim();
  const candidate = ttFindCandidateDJForPerformerName(musicianName);
  if (candidate?.id) {
    out.push({
      performerIndex: null,
      performerName: musicianName,
      dj: candidate,
    });
  }
  return out;
}

function ttApplyCandidateBindingsToSlot(slot) {
  if (!slot) return 0;
  const candidates = ttCollectCandidateBindingsForSlot(slot);
  if (!candidates.length) return 0;

  const performers = ttExtractCollaborativePerformers(slot?.musician || '');
  if (performers.length >= 2) {
    const ids = ttBuildCollaborativeDjIds(slot);
    let applied = 0;
    for (const item of candidates) {
      const idx = Number(item?.performerIndex);
      const djId = ttNormalizeDJId(item?.dj?.id);
      if (!Number.isInteger(idx) || idx < 0 || !djId) continue;
      while (ids.length < idx) ids.push(LINEUP_DJ_ID_PLACEHOLDER);
      if (ttNormalizeDJId(ids[idx]) === djId) continue;
      ids[idx] = djId;
      applied += 1;
    }
    while (ids.length && !ttNormalizeDJId(ids[ids.length - 1])) ids.pop();
    if (ids.length) slot.djIds = ids;
    else delete slot.djIds;
    if (ttNormalizeDJId(ids[0])) slot.djId = ttNormalizeDJId(ids[0]);
    else delete slot.djId;
    return applied;
  }

  const first = candidates[0];
  const targetId = ttNormalizeDJId(first?.dj?.id);
  if (!targetId) return 0;
  if (ttNormalizeDJId(slot?.djId) === targetId) return 0;
  slot.djId = targetId;
  delete slot.djIds;
  return 1;
}

async function ttAutoMatchSlotBinding(rid) {
  if (!ttEditMode || ttSaving) return;
  await ensureTtDJMatchMapLoaded();
  const slot = ttGetDraftSlotByRid(rid);
  if (!slot) return;
  const appliedCount = ttApplyCandidateBindingsToSlot(slot);
  if (!appliedCount) {
    setTtEditStatus('当前条目没有可自动匹配的未绑定 DJ。', true);
    return;
  }
  setTtEditStatus(`当前条目自动匹配完成：已绑定 ${appliedCount} 处`);
  renderTtModalBody();
}

async function ttAutoMatchAllUnboundForCurrentDraft() {
  if (!ttEditMode || ttSaving) return;
  await ensureTtDJMatchMapLoaded();
  const source = Array.isArray(ttDraftLineup) ? ttDraftLineup : [];
  if (!source.length) {
    setTtEditStatus('当前没有可处理的时间表草稿。', true);
    return;
  }
  let touchedRows = 0;
  let appliedTotal = 0;
  for (const slot of source) {
    const applied = ttApplyCandidateBindingsToSlot(slot);
    if (applied > 0) {
      touchedRows += 1;
      appliedTotal += applied;
    }
  }
  if (!appliedTotal) {
    setTtEditStatus('没有发现可自动匹配的未绑定 DJ。');
    return;
  }
  setTtEditStatus(`批量自动匹配完成：${touchedRows} 条表演，已绑定 ${appliedTotal} 处`);
  renderTtModalBody();
}

function ttConfirmCandidateForSlot(rid) {
  void ttAutoMatchSlotBinding(rid);
}

function ttConfirmAllCandidatesForCurrentEvent() {
  void ttAutoMatchAllUnboundForCurrentDraft();
}

function ttRenderBindingCellHtml(slot) {
  const meta = ttGetSlotBindingMeta(slot);
  return `
    <div class="tt-dj-bind-status ${meta.cls}">${escapeHtml(meta.text)}</div>
    <div class="tt-dj-bind-actions">
      <button class="tt-dj-bind-btn" onclick="ttOpenDJBindModal(${slot._rid}, 'existing')">选现有DJ</button>
      <button class="tt-dj-bind-btn" onclick="ttOpenDJBindModal(${slot._rid}, 'import')">导入新DJ</button>
      <button class="tt-dj-bind-btn candidate" onclick="void ttAutoMatchSlotBinding(${slot._rid})">自动匹配</button>
      <button class="tt-dj-bind-btn clear" onclick="ttClearSlotDJBinding(${slot._rid})">清除绑定</button>
    </div>
  `;
}

