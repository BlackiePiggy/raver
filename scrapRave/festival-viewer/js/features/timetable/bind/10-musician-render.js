function ttCreateLinkedDJButton(displayName, matchedDJ) {
  const name = String(displayName || '').trim() || '未知';
  const btn = document.createElement('button');
  btn.type = 'button';
  btn.className = 'tt-slot-dj-link';
  btn.setAttribute('aria-label', `打开 ${name} 的 DJ 详情`);
  btn.addEventListener('click', (event) => {
    event.preventDefault();
    event.stopPropagation();
    openDJProfileById(matchedDJ.id);
  });

  const avatar = document.createElement('span');
  avatar.className = 'tt-slot-dj-avatar';
  const avatarUrl = String(matchedDJ.avatarUrl || '').trim();
  if (avatarUrl) {
    const img = document.createElement('img');
    img.src = avatarUrl;
    img.alt = name;
    img.loading = 'lazy';
    avatar.appendChild(img);
  } else {
    const fallback = document.createElement('span');
    fallback.className = 'tt-slot-dj-avatar-fallback';
    fallback.textContent = String(name.charAt(0) || '?').toUpperCase();
    avatar.appendChild(fallback);
  }

  const nameEl = document.createElement('span');
  nameEl.className = 'tt-slot-dj-name';
  nameEl.innerHTML = renderBiTextHtml(name, { compact: true, fallback: '未知' });
  btn.appendChild(avatar);
  btn.appendChild(nameEl);
  return btn;
}

function ttCreateUnlinkedMusicianNode(slot, displayName, performerIndex = null) {
  const name = String(displayName || '').trim() || '未知';
  const row = document.createElement('div');
  row.className = 'tt-slot-musician-unlinked';
  const nameEl = document.createElement('span');
  nameEl.className = 'tt-slot-unlinked-name';
  nameEl.innerHTML = renderBiTextHtml(name, { compact: true, fallback: '未知' });
  const addBtn = document.createElement('button');
  addBtn.type = 'button';
  addBtn.className = 'tt-slot-add-dj-btn';
  addBtn.textContent = '+';
  addBtn.setAttribute('aria-label', `为 ${name} 绑定 DJ`);
  addBtn.title = '绑定到 DJ 库';
  addBtn.addEventListener('click', (event) => {
    event.preventDefault();
    event.stopPropagation();
    if (performerIndex == null) {
      ttOpenDJBindModalForViewSlot(slot, 'existing');
    } else {
      ttOpenDJBindModalForViewPerformer(slot, name, performerIndex, 'existing');
    }
  });
  row.appendChild(nameEl);
  row.appendChild(addBtn);
  return row;
}

function ttCreateBoundIdOnlyMusicianNode(displayName, explicitId) {
  const name = String(displayName || '').trim() || '未知';
  const boundId = String(explicitId || '').trim();
  const wrapper = document.createElement('div');
  wrapper.className = 'tt-slot-bound-id-only';
  wrapper.innerHTML = `
    <div class="tt-slot-bound-id-name">${renderBiTextHtml(name, { compact: true, fallback: '未知' })}</div>
    <div class="tt-slot-bound-id-meta">已绑定 ID：${escapeHtml(boundId)}（库中未找到）</div>
  `;
  return wrapper;
}

function createTtMusicianNode(slot) {
  const rawName = String(slot?.musician || '').trim();
  const name = rawName || '未知';
  const wrapper = document.createElement('div');
  wrapper.className = 'tt-slot-musician';

  const performers = !ttEditMode ? ttExtractCollaborativePerformers(name) : [];
  if (performers.length >= 2) {
    const connectorLabel = ttExtractCollaborativeActLabel(name) || (performers.length >= 3 ? 'B3B' : 'B2B');
    wrapper.classList.add('tt-slot-act-list');
    performers.forEach((performerName, performerIndex) => {
      const row = document.createElement('div');
      row.className = 'tt-slot-act-row';
      const explicitPerformerId = ttGetExplicitPerformerDJId(slot, performerIndex);
      const boundDJ = ttFindBoundDJForPerformer(slot, performerIndex);
      if (boundDJ?.id) {
        row.appendChild(ttCreateLinkedDJButton(performerName, boundDJ));
      } else if (explicitPerformerId) {
        row.appendChild(ttCreateBoundIdOnlyMusicianNode(performerName, explicitPerformerId));
      } else {
        row.appendChild(ttCreateUnlinkedMusicianNode(slot, performerName, performerIndex));
      }
      wrapper.appendChild(row);
      if (performerIndex < performers.length - 1) {
        const connector = document.createElement('div');
        connector.className = 'tt-slot-act-connector';
        connector.textContent = connectorLabel;
        wrapper.appendChild(connector);
      }
    });
    return wrapper;
  }

  const matchedDJ = ttFindLinkedDJForSlot(slot);
  const explicitId = ttGetExplicitSlotDJId(slot);
  if (!matchedDJ || !matchedDJ.id) {
    if (explicitId) {
      wrapper.appendChild(ttCreateBoundIdOnlyMusicianNode(name, explicitId));
      return wrapper;
    }
    if (!ttEditMode) {
      wrapper.appendChild(ttCreateUnlinkedMusicianNode(slot, name, null));
      return wrapper;
    }
    wrapper.innerHTML = renderBiTextHtml(name, { compact: true, fallback: '未知' });
    return wrapper;
  }

  wrapper.classList.add('tt-slot-musician-linked');
  wrapper.appendChild(ttCreateLinkedDJButton(name, matchedDJ));
  return wrapper;
}

