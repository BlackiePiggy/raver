// ── FLOAT NAVIGATOR ──
function fnavTogglePin() {
  const nav = document.getElementById('float-nav');
  const btn = document.getElementById('fnav-pin-btn');
  const pinned = nav.classList.toggle('pinned');
  // PIN 时同时移除 open，由 pinned class 单独控制展开
  if (pinned) nav.classList.remove('open');
  btn.textContent = pinned ? 'UNPIN' : 'PIN';
}

let fnavLeaveTimer = null;

function fnavOpen() {
  clearTimeout(fnavLeaveTimer);
  const nav = document.getElementById('float-nav');
  if (!nav.classList.contains('pinned')) nav.classList.add('open');
}

function fnavClose() {
  fnavLeaveTimer = setTimeout(() => {
    const nav = document.getElementById('float-nav');
    if (!nav.classList.contains('pinned')) nav.classList.remove('open');
  }, 120); // 120ms 延迟，防止鼠标移动时闪烁
}

function fnavScrollToFest(fest) {
  const allRows = document.querySelectorAll('.festival-row');
  for (const row of allRows) {
    const nameEl = row.querySelector('.fest-name .bi-en');
    if (!nameEl) continue;
    const info = fest.info || {};
    const bi = normalizeBiTextValue(info.nameI18n ?? info.name ?? fest.name ?? fest.folder, fest.folder);
    if (nameEl.textContent.trim() === bi.en.trim()) {
      row.scrollIntoView({ behavior: 'smooth', block: 'start' });
      row.style.transition = 'border-color 0.3s';
      row.style.borderColor = 'rgba(0,245,200,0.45)';
      setTimeout(() => { row.style.borderColor = ''; }, 1200);
      return;
    }
  }
}

function fnavBuild() {
  const list = document.getElementById('float-nav-list');
  const badge = document.getElementById('fnav-year-badge');
  if (!list) return;
  list.innerHTML = '';

  const yearData = allData?.[activeYear];
  if (badge) badge.textContent = activeYear ? String(activeYear) : '—';

  if (!yearData || currentAppPage !== 'archive') {
    list.innerHTML = `<span class="fnav-item" style="opacity:0.3;cursor:default;pointer-events:none">— 暂无数据 —</span>`;
    return;
  }

  const months = Object.keys(yearData).map(Number).sort((a, b) => a - b);
  let totalItems = 0;

  months.forEach(month => {
    const fests = Array.isArray(yearData[month]) ? yearData[month] : [];
    if (!fests.length) return;

    const monthLabel = document.createElement('span');
    monthLabel.className = 'fnav-item-month';
    monthLabel.textContent = MONTHS_CN[month] || `${month}月`;
    list.appendChild(monthLabel);

    fests.forEach(fest => {
      const info = fest.info || {};
      const bi = normalizeBiTextValue(info.nameI18n ?? info.name ?? fest.name ?? fest.folder, fest.folder);
      const displayName = bi.en || bi.zh || fest.folder;

      const el = document.createElement('button');
      el.className = 'fnav-item';
      el.title = bi.zh !== bi.en ? bi.zh : '';
      el.textContent = displayName;
      el.onclick = () => {
        list.querySelectorAll('.fnav-item').forEach(x => x.classList.remove('active'));
        el.classList.add('active');
        fnavScrollToFest(fest);
      };
      list.appendChild(el);
      totalItems++;
    });
  });

  if (!totalItems) {
    list.innerHTML = `<span class="fnav-item" style="opacity:0.3;cursor:default;pointer-events:none">— 暂无数据 —</span>`;
  }
}

// 鼠标感应：触发区 + 面板本身都能触发开合
document.addEventListener('DOMContentLoaded', () => {
  const trigger = document.getElementById('float-nav-trigger');
  const panel = document.getElementById('float-nav-panel');
  if (trigger) {
    trigger.addEventListener('mouseenter', fnavOpen);
    trigger.addEventListener('mouseleave', fnavClose);
  }
  if (panel) {
    panel.addEventListener('mouseenter', fnavOpen);
    panel.addEventListener('mouseleave', fnavClose);
  }
});

// 拦截现有函数，数据变化时自动重建导航
const _fnavOrigBuildUI = buildUI;
buildUI = function(...args) {
  _fnavOrigBuildUI.apply(this, args);
  fnavBuild();
};

const _fnavOrigRenderYear = renderYear;
renderYear = function(...args) {
  _fnavOrigRenderYear.apply(this, args);
  fnavBuild();
};

const _fnavOrigSwitchAppPage = switchAppPage;
switchAppPage = function(...args) {
  _fnavOrigSwitchAppPage.apply(this, args);
  fnavBuild();
};
