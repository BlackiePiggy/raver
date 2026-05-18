// Event-brand binding module extracted from 10-event-brand-binding (table render + selection)
function createEventBrandRowElement(row) {
  const wrapper = document.createElement('div');
  wrapper.className = 'event-brand-row';
  const rowKey = eventBrandRowKey(row);
  if (rowKey && eventBrandBindingState.selectedEventIds.has(rowKey)) {
    wrapper.classList.add('selected');
  }

  const selectedCell = document.createElement('div');
  const checkbox = document.createElement('input');
  checkbox.type = 'checkbox';
  checkbox.checked = !!(rowKey && eventBrandBindingState.selectedEventIds.has(rowKey));
  checkbox.disabled = !row.eventId;
  checkbox.addEventListener('change', () => {
    updateEventBrandRowSelection(row, checkbox.checked);
    wrapper.classList.toggle('selected', checkbox.checked);
  });
  selectedCell.appendChild(checkbox);

  const nameCell = document.createElement('div');
  nameCell.className = 'event-brand-event-name';
  nameCell.innerHTML = renderBiTextHtml(row.nameBi, { compact: true, fallback: row.nameDisplay || row.festivalId || 'Unknown Event' });

  const bindCell = document.createElement('div');
  bindCell.className = 'event-brand-row-bind';
  const brandInput = document.createElement('input');
  brandInput.className = 'event-brand-row-bind-input';
  brandInput.type = 'text';
  brandInput.placeholder = row.eventId ? '搜索并选择 Brand' : '无后端 eventId，无法绑定';
  brandInput.value = String(row.wikiFestivalName || '').trim();
  brandInput.disabled = !row.eventId || eventBrandBindingState.saving;
  brandInput.setAttribute('list', ensureEventBrandBindingDatalist(brandInput.value || ''));
  brandInput.addEventListener('focus', () => {
    brandInput.setAttribute('list', ensureEventBrandBindingDatalist(brandInput.value || ''));
  });
  brandInput.addEventListener('input', () => {
    brandInput.setAttribute('list', ensureEventBrandBindingDatalist(brandInput.value || ''));
  });
  brandInput.addEventListener('change', () => {
    // Manual bind only: do not auto-save on change.
    const hit = resolveEventBrandCandidateByText(brandInput.value);
    if (hit) {
      brandInput.value = hit.name;
    }
  });

  const bindBtn = document.createElement('button');
  bindBtn.type = 'button';
  bindBtn.className = 'event-brand-row-btn';
  bindBtn.textContent = '绑定';
  bindBtn.disabled = !row.eventId || eventBrandBindingState.saving;
  bindBtn.addEventListener('click', async () => {
    if (!row.eventId) return;
    const hit = resolveEventBrandCandidateByText(brandInput.value);
    if (!hit) {
      setEventBrandStatus('请先在右侧输入并选择一个存在的 Brand。', 'error');
      return;
    }
    brandInput.value = hit.name;
    await saveSingleEventBrandBinding(row, hit);
  });

  const clearBtn = document.createElement('button');
  clearBtn.type = 'button';
  clearBtn.className = 'event-brand-row-btn clear';
  clearBtn.textContent = '解绑';
  clearBtn.disabled = !row.eventId || eventBrandBindingState.saving;
  clearBtn.addEventListener('click', async () => {
    if (!row.eventId) return;
    brandInput.value = '';
    await saveSingleEventBrandBinding(row, null);
  });

  bindCell.appendChild(brandInput);
  bindCell.appendChild(bindBtn);
  bindCell.appendChild(clearBtn);

  wrapper.appendChild(selectedCell);
  wrapper.appendChild(nameCell);
  wrapper.appendChild(bindCell);
  return wrapper;
}

function renderEventBrandRowsInto(parentEl, rows) {
  const frag = document.createDocumentFragment();
  for (const row of rows) {
    frag.appendChild(createEventBrandRowElement(row));
  }
  parentEl.appendChild(frag);
}

function renderEventBrandBindingTable() {
  const wrap = document.getElementById('event-brand-table-wrap');
  if (!wrap) return;
  recomputeEventBrandFilteredRows();
  const rows = Array.isArray(eventBrandBindingState.filteredRows) ? eventBrandBindingState.filteredRows : [];
  updateEventBrandToolbarMeta();
  setEventBrandHeaderCounter();

  if (!rows.length) {
    wrap.innerHTML = '<div class="event-brand-empty">没有匹配活动。调整搜索或筛选后重试。</div>';
    return;
  }

  wrap.innerHTML = '';
  const head = document.createElement('div');
  head.className = 'event-brand-table-head';
  head.innerHTML = `
    <div class="event-brand-head-cell"></div>
    <div class="event-brand-head-cell">活动名称</div>
    <div class="event-brand-head-cell bind">绑定 Brand</div>
  `;
  wrap.appendChild(head);

  if (eventBrandBindingState.viewMode === 'cluster') {
    const unmatched = rows.filter((row) => !String(row?.wikiFestivalId || '').trim());
    const matched = rows.filter((row) => !!String(row?.wikiFestivalId || '').trim());
    const clusterSpec = [
      { key: 'unmatched', title: '未匹配 Event', rows: unmatched },
      { key: 'matched', title: '已匹配 Event', rows: matched },
    ];
    for (const spec of clusterSpec) {
      const section = document.createElement('section');
      section.className = 'event-brand-cluster';
      section.innerHTML = `
        <div class="event-brand-cluster-head">
          <div class="event-brand-cluster-title">${escapeHtml(spec.title)}</div>
          <div class="event-brand-cluster-count">${escapeHtml(String(spec.rows.length))} 条</div>
        </div>
      `;
      if (spec.rows.length) {
        renderEventBrandRowsInto(section, spec.rows);
      } else {
        const empty = document.createElement('div');
        empty.className = 'event-brand-empty';
        empty.textContent = '当前分组为空';
        section.appendChild(empty);
      }
      wrap.appendChild(section);
    }
    return;
  }

  renderEventBrandRowsInto(wrap, rows);
}

function refreshEventBrandRowsFromSource() {
  const prevSelected = eventBrandBindingState.selectedEventIds instanceof Set
    ? new Set(eventBrandBindingState.selectedEventIds)
    : new Set();
  eventBrandBindingState.allRows = buildEventBrandBindingRows();
  const nextSelected = new Set();
  for (const row of eventBrandBindingState.allRows) {
    const key = eventBrandRowKey(row);
    if (key && prevSelected.has(key)) nextSelected.add(key);
  }
  eventBrandBindingState.selectedEventIds = nextSelected;
}

function onEventBrandSearchInputChanged(value) {
  eventBrandBindingState.searchQuery = String(value || '');
  renderEventBrandBindingTable();
}

function onEventBrandFilterModeChanged(value) {
  const mode = String(value || 'all').trim();
  eventBrandBindingState.filterMode = ['all', 'matched', 'unmatched'].includes(mode) ? mode : 'all';
  renderEventBrandBindingTable();
}
