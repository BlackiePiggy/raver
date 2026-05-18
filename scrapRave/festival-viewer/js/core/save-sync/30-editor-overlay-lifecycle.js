function toggleInfoEdit(panelEl, editing) {
  if (!panelEl) return;
  const overlay = document.getElementById('event-editor-overlay');
  if (editing) {
    if (activeEventEditPanel && activeEventEditPanel !== panelEl) {
      const prevCancel = activeEventEditPanel._cancelEventEdit;
      if (typeof prevCancel === 'function') prevCancel();
      else activeEventEditPanel.classList.remove('is-editing');
    }
    activeEventEditPanel = panelEl;
    panelEl.classList.add('is-editing');
    if (overlay) overlay.classList.add('open');
    document.body.classList.add('event-editor-open');
    setTimeout(() => {
      if (activeEventEditPanel !== panelEl) return;
      const focusEl = panelEl.querySelector('.fest-info-edit input, .fest-info-edit textarea, .fest-info-edit select');
      if (focusEl) focusEl.focus();
    }, 0);
    return;
  }

  panelEl.classList.remove('is-editing');
  if (activeEventEditPanel === panelEl) activeEventEditPanel = null;
  const stillEditing = !!document.querySelector('.fest-info-panel.is-editing');
  if (!stillEditing) {
    if (overlay) overlay.classList.remove('open');
    document.body.classList.remove('event-editor-open');
  }
}

function closeActiveEventEditorByCancel() {
  const panel = activeEventEditPanel;
  if (!panel) return;
  const cancelFn = panel._cancelEventEdit;
  if (typeof cancelFn === 'function') {
    cancelFn();
    return;
  }
  toggleInfoEdit(panel, false);
}

function handleEventEditorOverlayClick(event) {
  const overlay = document.getElementById('event-editor-overlay');
  if (!overlay || event?.target !== overlay) return;
  closeActiveEventEditorByCancel();
}

