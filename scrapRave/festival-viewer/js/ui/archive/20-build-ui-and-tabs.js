// UI archive module extracted from 50-ui-render (buildUI shell + year tabs)
function buildUI(options = {}) {
  const preserveView = !!options.preserveView;
  const prevView = options.prevView || {};
  const years = (Array.isArray(archiveYearMeta) && archiveYearMeta.length)
    ? archiveYearMeta.map((item) => Number(item.year)).filter(Number.isInteger)
    : Object.keys(allData).map(Number).sort((a,b)=>b-a);
  const prevYear = Number(prevView.year);
  if (preserveView && years.includes(prevYear)) activeYear = prevYear;
  else if (!years.includes(Number(activeYear))) activeYear = years[0] ?? new Date().getFullYear();

  const nav = document.getElementById('year-nav');
  nav.innerHTML = '';
  if (years.length) {
    nav.style.display = 'flex';
    for (const y of years) {
      const btn = document.createElement('button');
      btn.className = 'year-tab' + (y === activeYear ? ' active' : '');
      btn.textContent = y;
      btn.onclick = async () => {
        activeYear = y;
        activeMonths = new Set();
        setActiveYearTab();
        const state = getArchiveYearLoadState(y);
        if (!state.page) await loadArchiveYearPage(y, { reset: true });
        renderYear();
      };
      nav.appendChild(btn);
    }
  } else {
    nav.style.display = 'none';
  }
  document.getElementById('filter-bar').style.display = 'flex';
  document.getElementById('import-bar').style.display = 'block';
  const searchInputEl = document.getElementById('search-input');
  const globalSearchInputEl = document.getElementById('global-search-input');
  if (preserveView && typeof prevView.searchText === 'string') {
    searchInputEl.value = prevView.searchText;
    searchQuery = prevView.searchText.toLowerCase();
  } else {
    searchQuery = (searchInputEl.value || '').toLowerCase();
  }
  if (preserveView && typeof prevView.globalSearchText === 'string') {
    globalSearchInputEl.value = prevView.globalSearchText;
    globalSearchQuery = prevView.globalSearchText.toLowerCase();
  } else {
    globalSearchQuery = (globalSearchInputEl.value || '').toLowerCase();
  }
  if (preserveView && Array.isArray(prevView.countryFilterKeys)) {
    activeCountryFilterKeys = new Set(
      prevView.countryFilterKeys
        .map((value) => normalizeCountryFilterKey(value))
        .filter(Boolean)
    );
  } else {
    activeCountryFilterKeys = new Set(
      [...activeCountryFilterKeys].map((value) => normalizeCountryFilterKey(value)).filter(Boolean)
    );
  }
  if (preserveView && Array.isArray(prevView.eventTypeFilterKeys)) {
    activeEventTypeFilterKeys = new Set(
      prevView.eventTypeFilterKeys
        .map((value) => normalizeEventTypeFilterKey(value))
        .filter(Boolean)
    );
  } else {
    activeEventTypeFilterKeys = new Set(
      [...activeEventTypeFilterKeys].map((value) => normalizeEventTypeFilterKey(value)).filter(Boolean)
    );
  }
  searchInputEl.oninput = e => { searchQuery = e.target.value.toLowerCase(); renderYear(); };
  globalSearchInputEl.oninput = e => { globalSearchQuery = e.target.value.toLowerCase(); renderYear(); };
  bindCountryFilterHandlers();
  bindEventTypeFilterHandlers();
  renderCountryFilterOptions();
  renderEventTypeFilterOptions();
  initImportPanel();
  renderYear(preserveView ? prevView.months : null);
}

function setActiveYearTab() {
  document.querySelectorAll('.year-tab').forEach(t => t.classList.toggle('active', parseInt(t.textContent) === activeYear));
}
