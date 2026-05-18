// DJ profile editor module extracted from 00-edit-and-source (source modal lifecycle)
function initDJProfileSourceReplaceUI(detail = null) {
  const st = ensureDJProfileSourceReplaceState(detail);
  if (!st) return;
  const queryInput = document.getElementById('dj-source-query');
  if (queryInput) {
    queryInput.value = String(st.query || detail?.name || '');
    queryInput.onkeydown = (event) => {
      if (event.key === 'Enter') {
        event.preventDefault();
        djFetchProfileSourceCandidates();
      }
    };
  }
  const spotifyToggle = document.getElementById('dj-source-toggle-spotify');
  const discogsToggle = document.getElementById('dj-source-toggle-discogs');
  const soundcloudToggle = document.getElementById('dj-source-toggle-soundcloud');
  if (spotifyToggle) spotifyToggle.checked = !!st.sourceEnabled.spotify;
  if (discogsToggle) discogsToggle.checked = !!st.sourceEnabled.discogs;
  if (soundcloudToggle) soundcloudToggle.checked = !!st.sourceEnabled.soundcloud;

  setDJSourceReplaceStatus(st.statusText || '', st.statusType || '');
  renderDJProfileSourceGrid();
  renderDJProfileSourceCompareTable();
}

function djHandleProfileSourceToggleChange() {
  const st = djProfileState.sourceReplace;
  if (!st) return;
  st.sourceEnabled.spotify = !!document.getElementById('dj-source-toggle-spotify')?.checked;
  st.sourceEnabled.discogs = !!document.getElementById('dj-source-toggle-discogs')?.checked;
  st.sourceEnabled.soundcloud = !!document.getElementById('dj-source-toggle-soundcloud')?.checked;
  normalizeDJProfileSourceSelections();
  renderDJProfileSourceGrid();
  renderDJProfileSourceCompareTable();
}

function openDJSourceReplaceModal() {
  if (!djProfileState?.djId) return;
  const overlay = document.getElementById('dj-source-replace-overlay');
  if (!overlay) return;
  const subEl = document.getElementById('dj-source-replace-sub');
  if (subEl) {
    const name = String(djProfileState?.detail?.name || '').trim();
    subEl.textContent = name ? `当前 DJ · ${name}` : '按字段选择来源，支持头像替换';
  }
  initDJProfileSourceReplaceUI(djProfileState.detail || null);
  overlay.classList.add('open');
}

function closeDJSourceReplaceModal() {
  const overlay = document.getElementById('dj-source-replace-overlay');
  if (overlay) overlay.classList.remove('open');
}

function handleDJSourceReplaceOverlayClick(event) {
  if (event.target === event.currentTarget) {
    closeDJSourceReplaceModal();
  }
}

