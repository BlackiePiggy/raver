// UI archive module extracted from 50-ui-render (month chips + year rendering)
let archiveRowsExpanded = false;

function setArchiveRowsExpanded(mainEl, expanded) {
  if (!mainEl) return;
  const rows = mainEl.querySelectorAll('.festival-row');
  rows.forEach((row) => {
    if (typeof row._setExpanded === 'function') {
      row._setExpanded(expanded);
      return;
    }
    row.classList.toggle('expanded', !!expanded);
    const btn = row.querySelector('.fest-expand-btn');
    if (btn) {
      btn.setAttribute('aria-expanded', expanded ? 'true' : 'false');
      btn.textContent = expanded ? '收起详情 ▴' : '展开详情 ▾';
    }
  });
}

function buildArchiveExpandToolbar(mainEl) {
  const toolbar = document.createElement('div');
  toolbar.className = 'archive-expand-toolbar';
  const btn = document.createElement('button');
  btn.className = 'archive-expand-all-btn';
  btn.type = 'button';
  const sync = () => {
    btn.textContent = archiveRowsExpanded ? '一键收起所有活动' : '一键展开所有活动';
  };
  btn.onclick = () => {
    archiveRowsExpanded = !archiveRowsExpanded;
    setArchiveRowsExpanded(mainEl, archiveRowsExpanded);
    sync();
  };
  sync();
  toolbar.appendChild(btn);
  return { toolbar, sync };
}

function buildMonthChips(preservedMonths = null, globalMode = false) {
  const monthSet = new Set();
  if (globalMode) {
    for (const yearData of Object.values(allData || {})) {
      for (const month of Object.keys(yearData || {})) {
        const monthNum = Number(month);
        if (Number.isInteger(monthNum)) monthSet.add(monthNum);
      }
    }
  } else {
    for (const month of Object.keys(allData[activeYear] || {})) {
      const monthNum = Number(month);
      if (Number.isInteger(monthNum)) monthSet.add(monthNum);
    }
  }
  const months = Array.from(monthSet).sort((a, b) => a - b);
  const chips = document.getElementById('month-chips');
  const availableMonthSet = new Set(months);
  if (Array.isArray(preservedMonths)) {
    activeMonths = new Set(
      preservedMonths
        .map(v => Number(v))
        .filter(v => Number.isInteger(v) && availableMonthSet.has(v))
    );
  } else {
    activeMonths = new Set([...activeMonths].filter(v => availableMonthSet.has(v)));
  }
  chips.innerHTML = '';
  for (const m of months) {
    const btn = document.createElement('button');
    btn.className = 'chip' + (activeMonths.has(m) ? ' active' : '');
    btn.textContent = m + '月';
    btn.onclick = () => {
      if (activeMonths.has(m)) activeMonths.delete(m); else activeMonths.add(m);
      btn.classList.toggle('active', activeMonths.has(m)); renderYear();
    };
    chips.appendChild(btn);
  }
}

function bindArchiveLazySentinel(mainEl) {
  if (archiveLazyObserver) {
    archiveLazyObserver.disconnect();
    archiveLazyObserver = null;
  }
  const sentinel = mainEl?.querySelector('[data-archive-lazy-sentinel]');
  if (!sentinel) return;
  archiveLazyObserver = new IntersectionObserver((entries) => {
    if (!entries.some((entry) => entry.isIntersecting)) return;
    if (archiveLazyLoading) return;
    void loadMoreArchiveYearEvents();
  }, { rootMargin: '480px 0px' });
  archiveLazyObserver.observe(sentinel);
}

function buildArchiveLazyFooter() {
  const state = getArchiveYearLoadState(activeYear);
  const footer = document.createElement('div');
  footer.className = 'archive-lazy-footer';
  footer.setAttribute('data-archive-lazy-sentinel', 'true');
  if (state.loaded) {
    footer.textContent = state.total ? `已加载 ${activeYear} 年全部 ${state.total} 个活动` : '该年份暂无活动';
  } else {
    footer.textContent = `继续滚动加载更多 ${activeYear} 年活动...`;
  }
  return footer;
}

function renderYear(preservedMonths = null) {
  renderCountryFilterOptions();
  renderEventTypeFilterOptions();
  const globalMode = !!String(globalSearchQuery || '').trim();
  buildMonthChips(preservedMonths, globalMode);
  const yearsToRender = globalMode
    ? Object.keys(allData).map(Number).sort((a, b) => b - a)
    : [activeYear];
  const main = document.getElementById('main');
  main.innerHTML = '';
  const { toolbar, sync } = buildArchiveExpandToolbar(main);
  main.appendChild(toolbar);
  let visible = 0;

  const buildMonthSection = (month, fests) => {
    const section = document.createElement('div');
    section.className = 'month-section';
    section.innerHTML = `
      <div class="month-header">
        <div class="month-num">${String(month).padStart(2,'0')}</div>
        <div><div class="month-name">${MONTHS_CN[month]}</div></div>
        <div class="month-line"></div>
        <div class="month-count">${fests.length} events</div>
      </div>
    `;
    for (const fest of fests) section.appendChild(buildRow(fest));
    return section;
  };

  for (const year of yearsToRender) {
    const yearData = allData[year] || {};
    const months = Object.keys(yearData).map(Number).sort((a, b) => a - b);
    let yearVisible = 0;
    const yearSection = document.createElement('section');
    yearSection.className = 'global-year-section';
    const yearHeader = document.createElement('div');
    yearHeader.className = 'global-year-header';
    yearHeader.textContent = String(year || '');

    for (const month of months) {
      if (activeMonths.size > 0 && !activeMonths.has(month)) continue;
      const sourceList = Array.isArray(yearData[month]) ? yearData[month] : [];
      const fests = sourceList.filter((fest) => festivalMatchesArchiveFilters(fest));
      if (!fests.length) continue;
      visible += fests.length;
      yearVisible += fests.length;
      const monthSection = buildMonthSection(month, fests);
      if (globalMode) yearSection.appendChild(monthSection);
      else main.appendChild(monthSection);
    }

    if (globalMode && yearVisible > 0) {
      yearHeader.textContent = `${year} · ${yearVisible} events`;
      yearSection.prepend(yearHeader);
      main.appendChild(yearSection);
    }
  }

  if (!visible) {
    main.innerHTML = '<div id="empty-state">NO FESTIVALS MATCH YOUR FILTER</div>';
    main.appendChild(buildArchiveLazyFooter());
    bindArchiveLazySentinel(main);
    return;
  }
  if (!globalMode) main.appendChild(buildArchiveLazyFooter());
  setArchiveRowsExpanded(main, archiveRowsExpanded);
  sync();
  bindArchiveLazySentinel(main);
}
