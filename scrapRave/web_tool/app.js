const keywordEl = document.getElementById('keyword');
const localeEl = document.getElementById('locale');
const searchBtn = document.getElementById('searchBtn');
const searchStatus = document.getElementById('searchStatus');
const eventsList = document.getElementById('eventsList');
const selectAllBtn = document.getElementById('selectAllBtn');
const clearAllBtn = document.getElementById('clearAllBtn');
const scrapeBtn = document.getElementById('scrapeBtn');
const scrapeStatus = document.getElementById('scrapeStatus');
const progressBoard = document.getElementById('progressBoard');
const summary = document.getElementById('summary');
const jsonOutput = document.getElementById('jsonOutput');
const downloadBtn = document.getElementById('downloadBtn');

let currentEvents = [];
let lastResult = null;
let currentJobId = null;
let pollTimer = null;

function escapeHTML(s) {
  return String(s ?? '')
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&#39;');
}

function setSearchStatus(text) {
  searchStatus.textContent = text || '';
}

function setScrapeStatus(text) {
  scrapeStatus.textContent = text || '';
}

function renderEvents(events) {
  currentEvents = events || [];
  eventsList.innerHTML = '';

  if (!currentEvents.length) {
    eventsList.innerHTML = '<p class="meta">未找到活动。</p>';
    return;
  }

  const frag = document.createDocumentFragment();
  currentEvents.forEach((e, idx) => {
    const row = document.createElement('label');
    row.className = 'event-item';
    row.innerHTML = `
      <div class="row">
        <input type="checkbox" class="event-check" data-idx="${idx}" />
        <div>
          <div class="title">${e.label || e.slug}</div>
          <div class="url">${e.url}</div>
        </div>
      </div>
    `;
    frag.appendChild(row);
  });
  eventsList.appendChild(frag);
}

function selectedEventUrls() {
  const checks = [...document.querySelectorAll('.event-check:checked')];
  return checks
    .map((c) => Number(c.dataset.idx))
    .filter((n) => Number.isInteger(n) && currentEvents[n])
    .map((n) => currentEvents[n].url);
}

async function postJSON(url, body) {
  const resp = await fetch(url, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(body),
  });

  const data = await resp.json().catch(() => ({}));
  if (!resp.ok) {
    throw new Error(data.error || `Request failed: ${resp.status}`);
  }
  return data;
}

async function getJSON(url) {
  const resp = await fetch(url);
  const data = await resp.json().catch(() => ({}));
  if (!resp.ok) {
    throw new Error(data.error || `Request failed: ${resp.status}`);
  }
  return data;
}

function stopPolling() {
  if (pollTimer) {
    clearInterval(pollTimer);
    pollTimer = null;
  }
}

function renderProgress(progress) {
  progressBoard.innerHTML = '';
  if (!progress) return;

  const total = document.createElement('div');
  total.className = 'progress-total';
  total.textContent = `总进度：${progress.completed_events || 0}/${progress.total_events || 0}，状态：${progress.status || '-'}`;
  progressBoard.appendChild(total);

  (progress.events || []).forEach((e) => {
    const item = document.createElement('div');
    item.className = 'progress-item';
    item.innerHTML = `
      <div class="name">${escapeHTML(e.title || e.slug || e.url)}</div>
      <div class="meta">
        状态：${escapeHTML(e.status || '-')}<br>
        内部进度：${Number(e.completed_timetables || 0)}/${Number(e.total_timetables || 0)} timetable<br>
        ${escapeHTML(e.message || '')}
      </div>
    `;
    progressBoard.appendChild(item);
  });
}

function renderSummary(result) {
  summary.innerHTML = '';
  if (!result || !result.events) return;

  const top = document.createElement('div');
  top.className = 'meta';
  top.textContent = `抓取完成：${result.count} 个活动，错误 ${result.errors.length}，耗时 ${result.elapsed_ms}ms`;
  summary.appendChild(top);

  result.events.forEach((e) => {
    const card = document.createElement('article');
    card.className = 'summary-card';

    const timetableCount = (e.timetable || []).length;
    const detailCount = (e.timetable_details || []).length;
    const photosCount = (e.photos || []).length;

    card.innerHTML = `
      <h3>${e.title || e.slug}</h3>
      <div class="meta">
        日期：${e.date_text_start || '-'} -> ${e.date_text_end || '-'}<br>
        Timetable：${timetableCount}，详细页：${detailCount}，Photos：${photosCount}
      </div>
    `;

    if (photosCount > 0) {
      const grid = document.createElement('div');
      grid.className = 'photo-grid';
      e.photos.forEach((p) => {
        const a = document.createElement('a');
        a.href = p.image_url;
        a.target = '_blank';
        a.rel = 'noreferrer';
        a.innerHTML = `
          <img src="${p.thumbnail_url || p.image_url}" alt="${p.label || ''}" loading="lazy" />
          <div>${p.label || 'photo'}</div>
        `;
        grid.appendChild(a);
      });
      card.appendChild(grid);
    }

    const details = e.timetable_details || [];
    if (details.length > 0) {
      const board = document.createElement('div');
      board.className = 'tt-board';

      details.forEach((day) => {
        const dayBox = document.createElement('div');
        dayBox.className = 'tt-day';
        dayBox.innerHTML = `<div class="tt-day-title">${escapeHTML(day.timetable_name || '-')} (${escapeHTML(day.date_text || '-')})</div>`;

        (day.stages || []).forEach((stage) => {
          const stageBox = document.createElement('div');
          stageBox.className = 'tt-stage';
          stageBox.innerHTML = `<div class="tt-stage-name">${escapeHTML(stage.stage_name || 'Unknown Stage')}</div>`;

          (stage.sets || []).forEach((set) => {
            const row = document.createElement('div');
            row.className = 'tt-set';
            const avatar = set.artist_image_url
              ? `<img class="tt-avatar" src="${escapeHTML(set.artist_image_url)}" alt="${escapeHTML(set.artist || '')}" loading="lazy" />`
              : `<div class="tt-avatar"></div>`;
            row.innerHTML = `
              <div class="tt-time">${escapeHTML(set.start_time || '--:--')} - ${escapeHTML(set.end_time || '--:--')}</div>
              <div class="tt-artist">${escapeHTML(set.artist || 'Unknown Artist')}</div>
              <div>${avatar}</div>
            `;
            stageBox.appendChild(row);
          });

          dayBox.appendChild(stageBox);
        });

        board.appendChild(dayBox);
      });

      card.appendChild(board);
    }

    summary.appendChild(card);
  });
}

searchBtn.addEventListener('click', async () => {
  const keyword = keywordEl.value.trim();
  const locale = localeEl.value.trim() || 'en-GB';

  if (!keyword) {
    setSearchStatus('请输入关键词。');
    return;
  }

  setSearchStatus('正在搜索活动...');
  searchBtn.disabled = true;

  try {
    const data = await postJSON('/api/search', { keyword, locale });
    renderEvents(data.events || []);
    setSearchStatus(`找到 ${data.count} 个活动。`);
  } catch (err) {
    setSearchStatus(`搜索失败：${err.message}`);
    renderEvents([]);
  } finally {
    searchBtn.disabled = false;
  }
});

selectAllBtn.addEventListener('click', () => {
  document.querySelectorAll('.event-check').forEach((c) => {
    c.checked = true;
  });
});

clearAllBtn.addEventListener('click', () => {
  document.querySelectorAll('.event-check').forEach((c) => {
    c.checked = false;
  });
});

scrapeBtn.addEventListener('click', async () => {
  const urls = selectedEventUrls();
  if (!urls.length) {
    setScrapeStatus('请先勾选至少一个活动。');
    return;
  }

  setScrapeStatus(`正在抓取 ${urls.length} 个活动，请稍候...`);
  scrapeBtn.disabled = true;
  downloadBtn.disabled = true;
  stopPolling();
  renderProgress(null);

  try {
    const started = await postJSON('/api/scrape/start', { event_urls: urls });
    currentJobId = started.job_id;
    setScrapeStatus(`任务已创建：${currentJobId}，正在抓取...`);

    pollTimer = setInterval(async () => {
      if (!currentJobId) return;
      try {
        const p = await getJSON(`/api/scrape/progress?job_id=${encodeURIComponent(currentJobId)}`);
        renderProgress(p.progress);

        if (p.progress && (p.progress.status === 'completed' || p.progress.status === 'failed')) {
          stopPolling();
          if (p.progress.status === 'completed') {
            const resultResp = await getJSON(`/api/scrape/result?job_id=${encodeURIComponent(currentJobId)}`);
            const result = resultResp.result;
            lastResult = result;
            renderSummary(result);
            jsonOutput.textContent = JSON.stringify(result, null, 2);
            downloadBtn.disabled = false;
            setScrapeStatus(`抓取成功：${result.count} 个活动。`);
          } else {
            const fatal = p.progress.fatal_error ? `，错误：${p.progress.fatal_error}` : '';
            setScrapeStatus(`任务失败${fatal}`);
          }
          currentJobId = null;
          scrapeBtn.disabled = false;
        }
      } catch (err) {
        stopPolling();
        setScrapeStatus(`进度查询失败：${err.message}`);
        scrapeBtn.disabled = false;
      }
    }, 1000);
  } catch (err) {
    setScrapeStatus(`抓取失败：${err.message}`);
    scrapeBtn.disabled = false;
  }
});

downloadBtn.addEventListener('click', () => {
  if (!lastResult) return;
  const blob = new Blob([JSON.stringify(lastResult, null, 2)], { type: 'application/json;charset=utf-8' });
  const url = URL.createObjectURL(blob);
  const a = document.createElement('a');
  const ts = new Date().toISOString().replace(/[:.]/g, '-');
  a.href = url;
  a.download = `festtimetable-scrape-${ts}.json`;
  a.click();
  URL.revokeObjectURL(url);
});
