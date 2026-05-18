// Core state facade for ranking domain.
(function initRankingStateFacade() {
  function state() {
    return rankingPageState;
  }

  function mutate(updater) {
    if (typeof updater === 'function') updater(state());
    return state();
  }

  function resetEntriesEditorTransient() {
    const st = state();
    if (st.entriesEditorSearchTimer) {
      clearTimeout(st.entriesEditorSearchTimer);
      st.entriesEditorSearchTimer = null;
    }
    st.entriesEditorSearchSeq = 0;
    st.entriesEditorSearchResults = [];
    st.entriesEditorSearchQuery = '';
    st.entriesEditorRows = [];
    st.entriesEditorCatalog = [];
    st.entriesEditorYear = null;
    st.entriesEditorUnmatchedViewMode = 'all';
  }

  const facade = {
    state,
    mutate,
    resetEntriesEditorTransient,
  };

  window.RankingStateFacade = facade;
  window.getRankingState = function getRankingState() {
    return facade.state();
  };
})();
