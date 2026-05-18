function cozeRowKey(row) {
  const x = normalizeLineupEntry(row || {});
  return `${x.musician}|${x.date}|${x.time}|${x.stage}`;
}

function formatCozeDateAsYmdDot(value) {
  if (!(value instanceof Date) || Number.isNaN(value.getTime())) return '';
  return `${value.getFullYear()}.${value.getMonth() + 1}.${value.getDate()}`;
}

function cozeShouldNormalizeDateText(value) {
  const raw = String(value || '').trim();
  if (!raw) return false;
  const lowered = raw.toLowerCase();
  if (raw === '未知' || lowered === 'unknown' || lowered === 'n/a') return false;
  if (parseArchiveDateOnlyForSync(raw)) return true;
  if (parseLineupDayIndexForSync(raw)) return true;
  return parseLineupMonthDayCandidatesForSync(raw).length > 0;
}

function cozeNormalizeRecognizedDateForFest(rawDate, fest) {
  const text = String(rawDate || '').trim();
  if (!cozeShouldNormalizeDateText(text)) return text;
  const start = parseArchiveDateOnlyForSync(fest?.info?.startDate);
  const end = parseArchiveDateOnlyForSync(fest?.info?.endDate) || start;
  const resolved = resolveLineupDateForSync(text, start, end);
  const formatted = formatCozeDateAsYmdDot(resolved);
  return formatted || text;
}

function makeCozeRow(item, source = '') {
  const x = normalizeLineupEntry(item || {});
  return {
    id: cozeRowIdSeed++,
    selected: true,
    musician: x.musician,
    date: x.date,
    time: x.time,
    stage: x.stage,
    source: String(source || '').trim() || '未知来源'
  };
}

function cozeSetModalStatus(text) {
  const el = document.getElementById('coze-modal-status');
  if (el) el.textContent = String(text || '');
}

function cozeSetRunStatus(text) {
  const el = document.getElementById('coze-run-status');
  if (el) el.textContent = String(text || '');
}

function cozeRefreshButtonState() {
  const runBtn = document.getElementById('coze-run-btn');
  const saveBtn = document.getElementById('coze-save-btn');
  if (!runBtn || !saveBtn) return;
  const st = cozeReviewState;
  if (!st) {
    runBtn.disabled = true;
    saveBtn.disabled = true;
    return;
  }
  runBtn.disabled = !!st.running;
  saveBtn.disabled = !!st.running || !st.rows.some(r => r.selected);
}

function cozeUpdateModalHeader() {
  const st = cozeReviewState;
  if (!st) return;
  const titleEl = document.getElementById('coze-modal-title');
  const subEl = document.getElementById('coze-modal-sub');
  const nameBi = normalizeBiTextValue(st.fest.info.nameI18n ?? st.fest.info.name ?? st.fest.name ?? st.fest.folder, st.fest.folder);
  titleEl.innerHTML = `时间表识别确认 · ${renderBiTextHtml(nameBi, { compact: true, fallback: st.fest.folder })}`;
  subEl.textContent = [
    st.fest.info.location || st.fest.location || '',
    `${st.images.length} 张候选图片`,
    `当前已入库 ${Array.isArray(st.fest.info.lineup) ? st.fest.info.lineup.length : 0} 条`
  ].filter(Boolean).join('  ·  ');
}

function renderCozeImageList() {
  const st = cozeReviewState;
  const listEl = document.getElementById('coze-image-list');
  if (!st || !listEl) return;
  if (!st.images.length) {
    listEl.innerHTML = '<div class="coze-result-empty">没有可识别图片</div>';
    return;
  }
  listEl.innerHTML = st.images.map((img, i) => {
    const selected = st.imageSelected[i] ? 'checked' : '';
    const status = st.imageStates[i] || { state: 'idle', message: '待识别' };
    const statusClass = status.state === 'done' ? 'ok' : (status.state === 'error' ? 'err' : (status.state === 'running' ? 'run' : ''));
    const stateText = status.message || '待识别';
    return `
      <div class="coze-image-item">
        <div class="coze-image-top">
          <input type="checkbox" ${selected} ${st.running ? 'disabled' : ''} onchange="cozeToggleImage(${i}, this.checked)">
          <div>
            <div class="coze-image-name">${escapeHtml(img.filename || `图片${i + 1}`)}</div>
            <div class="coze-image-type">${escapeHtml(img.classified?.label || 'UNKNOWN')}</div>
          </div>
        </div>
        <div class="coze-image-status ${statusClass}">${escapeHtml(stateText)}</div>
      </div>
    `;
  }).join('');
}

function renderCozeResultRows() {
  const st = cozeReviewState;
  const tbody = document.getElementById('coze-result-tbody');
  const summaryEl = document.getElementById('coze-result-summary');
  const emptyEl = document.getElementById('coze-result-empty');
  const tableWrap = document.getElementById('coze-table-wrap');
  if (!st || !tbody || !summaryEl || !emptyEl || !tableWrap) return;

  const selectedCount = st.rows.filter(r => r.selected).length;
  summaryEl.textContent = `识别结果 ${st.rows.length} 条，已勾选 ${selectedCount} 条待保存`;

  if (!st.rows.length) {
    tbody.innerHTML = '';
    emptyEl.style.display = '';
    tableWrap.style.display = 'none';
    cozeRefreshButtonState();
    return;
  }

  emptyEl.style.display = 'none';
  tableWrap.style.display = '';
  tbody.innerHTML = st.rows.map((row) => `
    <tr>
      <td><input type="checkbox" ${row.selected ? 'checked' : ''} onchange="cozeToggleRow(${row.id}, this.checked)"></td>
      <td><input type="text" value="${escapeHtml(row.musician)}" oninput="cozeUpdateRowField(${row.id}, 'musician', this.value)"></td>
      <td><input type="text" value="${escapeHtml(row.date)}" oninput="cozeUpdateRowField(${row.id}, 'date', this.value)"></td>
      <td><input type="text" value="${escapeHtml(row.time)}" oninput="cozeUpdateRowField(${row.id}, 'time', this.value)"></td>
      <td><input type="text" value="${escapeHtml(row.stage)}" oninput="cozeUpdateRowField(${row.id}, 'stage', this.value)"></td>
      <td>${escapeHtml(row.source || '未知来源')}</td>
      <td><button class="del-btn" onclick="cozeRemoveRow(${row.id})">删除</button></td>
    </tr>
  `).join('');
  cozeRefreshButtonState();
}

function cozeToggleImage(idx, checked) {
  const st = cozeReviewState;
  if (!st || st.running) return;
  st.imageSelected[idx] = !!checked;
}

function cozeSelectAllImages(checked) {
  const st = cozeReviewState;
  if (!st || st.running) return;
  st.imageSelected = st.images.map(() => !!checked);
  renderCozeImageList();
}

function cozeSelectedImageIndexes() {
  const st = cozeReviewState;
  if (!st) return [];
  const out = [];
  for (let i = 0; i < st.images.length; i += 1) {
    if (st.imageSelected[i]) out.push(i);
  }
  return out;
}

function cozeSetImageState(idx, state, message) {
  const st = cozeReviewState;
  if (!st) return;
  st.imageStates[idx] = { state, message };
  renderCozeImageList();
}

function cozeAppendRows(items, sourceName) {
  const st = cozeReviewState;
  if (!st) return 0;
  const seen = new Set(st.rows.map(r => cozeRowKey(r)));
  let added = 0;
  for (const raw of (Array.isArray(items) ? items : [])) {
    const row = makeCozeRow(raw, sourceName);
    row.date = cozeNormalizeRecognizedDateForFest(row.date, st.fest);
    const key = cozeRowKey(row);
    if (seen.has(key)) continue;
    seen.add(key);
    st.rows.push(row);
    added += 1;
  }
  return added;
}

function cozeToggleRow(id, checked) {
  const st = cozeReviewState;
  if (!st) return;
  const row = st.rows.find(r => r.id === id);
  if (!row) return;
  row.selected = !!checked;
  renderCozeResultRows();
}

function cozeSelectAllRows(checked) {
  const st = cozeReviewState;
  if (!st) return;
  st.rows.forEach(r => { r.selected = !!checked; });
  renderCozeResultRows();
}

function cozeUpdateRowField(id, field, value) {
  const st = cozeReviewState;
  if (!st) return;
  const row = st.rows.find(r => r.id === id);
  if (!row) return;
  row[field] = String(value || '');
}

function cozeRemoveRow(id) {
  const st = cozeReviewState;
  if (!st) return;
  st.rows = st.rows.filter(r => r.id !== id);
  renderCozeResultRows();
}

function cozeAddManualRow() {
  const st = cozeReviewState;
  if (!st) return;
  st.rows.push(makeCozeRow({ musician: '未知', date: '未知', time: '未知', stage: '' }, '手动添加'));
  renderCozeResultRows();
}

function cozeClearAllStages() {
  const st = cozeReviewState;
  if (!st) return;
  st.rows.forEach((r) => { r.stage = ''; });
  renderCozeResultRows();
  cozeSetModalStatus('已清空全部舞台名称。舞台为空时将按单舞台处理。');
}

function openCozeReviewModal(fest, panelEl, btnEl, statusEl, imgs, options = {}) {
  cozeReviewState = {
    fest,
    panelEl,
    statusEl,
    originBtn: btnEl,
    images: imgs,
    imageSelected: imgs.map(() => true),
    imageStates: imgs.map(() => ({ state: 'idle', message: '待识别' })),
    rows: [],
    running: false,
    applyMode: options?.applyMode === 'form' ? 'form' : 'persist',
  };
  btnEl.disabled = true;
  cozeUpdateModalHeader();
  cozeSetModalStatus('');
  cozeSetRunStatus('请选择要识别的图片，然后点击「开始识别」。识别完成后可在右侧手动修改并确认保存。');
  renderCozeImageList();
  renderCozeResultRows();
  document.getElementById('coze-modal-overlay').classList.add('open');
  document.body.style.overflow = 'hidden';
  cozeRefreshButtonState();
}

function closeCozeReviewModal() {
  const st = cozeReviewState;
  if (st?.running) {
    cozeSetModalStatus('识别进行中，请等待当前任务完成后再关闭。');
    return;
  }
  document.getElementById('coze-modal-overlay').classList.remove('open');
  document.body.style.overflow = '';
  if (st?.originBtn) st.originBtn.disabled = false;
  cozeReviewState = null;
}

function handleCozeOverlayClick(e) {
  if (e.target === document.getElementById('coze-modal-overlay')) closeCozeReviewModal();
}

function runCozeLineupRecognition(fest, panelEl, btnEl, statusEl, options = {}) {
  const customImages = Array.isArray(options?.images) ? options.images : null;
  const imgs = customImages || pickFestivalAiImages(fest, panelEl);
  if (!imgs.length) {
    statusEl.textContent = '未找到可识别的 lineup/timetable 图片';
    return;
  }
  openCozeReviewModal(fest, panelEl, btnEl, statusEl, imgs, options);
}

function cozeParseLineupFieldValue(rawValue) {
  const raw = String(rawValue || '').trim();
  if (!raw) return [];
  try {
    const parsed = JSON.parse(raw);
    if (Array.isArray(parsed)) return dedupeLineupEntries(parsed);
    if (parsed && Array.isArray(parsed.lineup_info)) return dedupeLineupEntries(parsed.lineup_info);
  } catch (_error) {
    return [];
  }
  return [];
}

function cozeReadLineupFromPanel(panelEl, fest) {
  if (!panelEl) return Array.isArray(fest?.info?.lineup) ? fest.info.lineup : [];
  const input = panelEl.querySelector('.fest-info-edit [data-field="lineup"]');
  if (!input) return Array.isArray(fest?.info?.lineup) ? fest.info.lineup : [];
  const parsed = cozeParseLineupFieldValue(input.value);
  if (parsed.length) return parsed;
  return Array.isArray(fest?.info?.lineup) ? fest.info.lineup : [];
}

function cozeWriteLineupToPanel(panelEl, lineup) {
  if (!panelEl) return false;
  const input = panelEl.querySelector('.fest-info-edit [data-field="lineup"]');
  if (!input) return false;
  input.value = lineup.length ? JSON.stringify({ lineup_info: lineup }, null, 2) : '';
  return true;
}

async function cozeRecognizeSelectedImages() {
  const st = cozeReviewState;
  if (!st || st.running) return;
  const indexes = cozeSelectedImageIndexes();
  if (!indexes.length) {
    cozeSetModalStatus('请先至少勾选一张图片。');
    return;
  }

  st.running = true;
  cozeSetModalStatus('');
  cozeRefreshButtonState();
  renderCozeImageList();

  let okCount = 0;
  let failCount = 0;
  let addedCount = 0;

  try {
    for (let i = 0; i < indexes.length; i += 1) {
      const idx = indexes[i];
      const img = st.images[idx];
      cozeSetImageState(idx, 'running', `识别中 ${i + 1}/${indexes.length}...`);
      cozeSetRunStatus(`识别中 ${i + 1}/${indexes.length}: ${img.filename}`);
      try {
        const festivalImage = await imageToCozeInput(img);
        const resp = await apiPost('/api/coze/recognize', { festival_image: festivalImage });
        const lineupInfo = dedupeLineupEntries(resp?.lineup_info || []);
        if (!lineupInfo.length) {
          cozeSetImageState(idx, 'error', '未识别到有效结果');
          failCount += 1;
          continue;
        }
        const newly = cozeAppendRows(lineupInfo, img.filename);
        addedCount += newly;
        okCount += 1;
        cozeSetImageState(idx, 'done', `识别 ${lineupInfo.length} 条，新增 ${newly} 条`);
      } catch (err) {
        failCount += 1;
        cozeSetImageState(idx, 'error', `失败：${err.message}`);
      }
      renderCozeResultRows();
    }
  } finally {
    st.running = false;
    renderCozeImageList();
    renderCozeResultRows();
    cozeRefreshButtonState();
  }

  cozeSetRunStatus(`识别完成：成功 ${okCount} 张，失败 ${failCount} 张，新增候选 ${addedCount} 条。请在右侧确认/修改后再保存。`);
}

async function cozeConfirmSave() {
  const st = cozeReviewState;
  if (!st || st.running) return;

  const chosen = st.rows
    .filter(r => r.selected)
    .map((r) => {
      const normalizedDate = cozeNormalizeRecognizedDateForFest(r.date, st.fest);
      return normalizeLineupEntry({ musician: r.musician, date: normalizedDate, time: r.time, stage: r.stage });
    });

  if (!chosen.length) {
    cozeSetModalStatus('请至少勾选一条结果再保存。');
    return;
  }

  const saveBtn = document.getElementById('coze-save-btn');
  const runBtn = document.getElementById('coze-run-btn');
  const beforeCount = Array.isArray(st.fest.info?.lineup) ? st.fest.info.lineup.length : 0;
  saveBtn.disabled = true;
  runBtn.disabled = true;
  cozeSetModalStatus(st.applyMode === 'form' ? '正在回填到表单 ...' : '正在保存到 JSON ...');

  try {
    if (st.applyMode === 'form') {
      const existing = cozeReadLineupFromPanel(st.panelEl, st.fest);
      const merged = mergeLineupEntries(existing, chosen);
      cozeWriteLineupToPanel(st.panelEl, merged);
      if (typeof setPanelEditStatus === 'function') {
        setPanelEditStatus(st.panelEl, `Timetable 识别结果已回填：新增 ${Math.max(0, merged.length - existing.length)} 条，当前共 ${merged.length} 条。`);
      }
      if (st.statusEl) {
        st.statusEl.textContent = `Timetable 识别结果已回填到表单：新增 ${Math.max(0, merged.length - existing.length)} 条，当前共 ${merged.length} 条`;
      }
    } else {
      const merged = mergeLineupEntries(st.fest.info.lineup || [], chosen);
      const payload = {
        ...st.fest.info,
        lineup: merged
      };
      await persistFestivalPayload(st.fest, payload);
      refreshFestHeaderDisplay(st.panelEl.closest('.festival-row'), st.fest);
      renderInfoView(st.panelEl, st.fest.info);
      if (st.panelEl.classList.contains('is-editing')) setEditInputs(st.panelEl, st.fest.info);

      if (st.statusEl) {
        st.statusEl.textContent = `AI识别已保存：新增 ${Math.max(0, merged.length - beforeCount)} 条，当前共 ${merged.length} 条`;
      }
    }
    closeCozeReviewModal();
  } catch (e) {
    cozeSetModalStatus(`${st.applyMode === 'form' ? '回填失败' : '保存失败'}：${e.message}`);
  } finally {
    cozeRefreshButtonState();
  }
}
