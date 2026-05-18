const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');

const LINEUP_SYNC_PATH = path.resolve(__dirname, '../js/core/helpers/20-lineup-sync-and-payload.js');

function loadLineupSyncHelpers() {
  const code = fs.readFileSync(LINEUP_SYNC_PATH, 'utf8');
  const context = {
    console,
    setTimeout,
    clearTimeout,
    window: {},
    normalizeLineupEntry(entry) {
      return {
        musician: String(entry?.musician || '').trim(),
        stage: String(entry?.stage || '').trim(),
        date: String(entry?.date || '').trim(),
        time: String(entry?.time || '').trim(),
        djId: String(entry?.djId || '').trim(),
        djIds: Array.isArray(entry?.djIds) ? entry.djIds : [],
      };
    },
    isLineupDjIdPlaceholder(id) {
      return /^pending:/i.test(String(id || '').trim());
    },
    normalizeBoolFlag(value, fallback = false) {
      if (value === undefined || value === null || value === '') return Boolean(fallback);
      if (typeof value === 'boolean') return value;
      const normalized = String(value).trim().toLowerCase();
      if (['1', 'true', 'yes', 'y'].includes(normalized)) return true;
      if (['0', 'false', 'no', 'n'].includes(normalized)) return false;
      return Boolean(fallback);
    },
    dedupeStrings(list) {
      const out = [];
      const seen = new Set();
      (Array.isArray(list) ? list : []).forEach((item) => {
        const text = String(item || '').trim();
        if (!text) return;
        if (seen.has(text)) return;
        seen.add(text);
        out.push(text);
      });
      return out;
    },
    normalizeSocialLinks(list) {
      return (Array.isArray(list) ? list : []).map((item) => ({
        type: String(item?.type || '').trim().toLowerCase(),
        url: String(item?.url || '').trim(),
      })).filter((item) => item.type && item.url);
    },
    normalizeTicketPriceValue(value) {
      if (value === undefined || value === null || value === '') return null;
      const parsed = Number(value);
      return Number.isFinite(parsed) ? parsed : null;
    },
    mergeSourceMeta(next, fallback) {
      const src = next && typeof next === 'object' ? next : (fallback && typeof fallback === 'object' ? fallback : {});
      return {
        provider: String(src.provider || '').trim().toLowerCase(),
        eventUrl: String(src.eventUrl || '').trim(),
        slug: String(src.slug || '').trim(),
      };
    },
    normalizeBiTextValue(value, fallback = '') {
      if (value && typeof value === 'object' && !Array.isArray(value)) {
        const en = String(value.en || '').trim();
        const zh = String(value.zh || '').trim();
        return {
          en: en || zh || String(fallback || '').trim(),
          zh: zh || en || String(fallback || '').trim(),
        };
      }
      const text = String(value || fallback || '').trim();
      return { en: text, zh: text };
    },
  };
  context.globalThis = context;
  vm.createContext(context);
  vm.runInContext(code, context, { filename: LINEUP_SYNC_PATH });
  return context;
}

function ymd(date) {
  return `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, '0')}-${String(date.getDate()).padStart(2, '0')}`;
}

function toPlain(value) {
  return JSON.parse(JSON.stringify(value));
}

test('lineup sync helpers parse archive date formats and detect explicit year', () => {
  const ctx = loadLineupSyncHelpers();
  assert.equal(ctx.hasExplicitYearInDateTextForSync('２０２６年 10月2日'), true);
  assert.equal(ctx.hasExplicitYearInDateTextForSync('Oct 2'), false);

  assert.equal(ctx.normalizeArchiveDateTextForSync('2026/7/2'), '2026-07-02');
  assert.equal(ctx.normalizeArchiveDateTextForSync('2026年7月2日'), '2026-07-02');
  assert.equal(ctx.normalizeArchiveDateTextForSync('2026-07-02T16:00:00Z'), '2026-07-02');
});

test('lineup sync helpers parse month/day candidates and resolve event day', () => {
  const ctx = loadLineupSyncHelpers();
  assert.deepEqual(
    toPlain(ctx.parseLineupMonthDayCandidatesForSync('Oct.2 Main Stage')),
    [{ month: 10, day: 2 }]
  );
  assert.deepEqual(
    toPlain(ctx.parseLineupMonthDayCandidatesForSync('2/10 afterparty')),
    [{ month: 2, day: 10 }, { month: 10, day: 2 }]
  );

  const start = ctx.parseArchiveDateOnlyForSync('2026-07-01');
  const end = ctx.parseArchiveDateOnlyForSync('2026-07-03');
  const day2 = ctx.resolveLineupDateForSync('Day 2', start, end);
  assert.equal(ymd(day2), '2026-07-02');

  const cnDate = ctx.resolveLineupDateForSync('7月3日', start, end);
  assert.equal(ymd(cnDate), '2026-07-03');
});

test('lineup sync helpers parse time range and build lineup slots with rollover', () => {
  const ctx = loadLineupSyncHelpers();
  assert.deepEqual(toPlain(ctx.parseLineupTimeRangeForSync('21:00-23:30')), {
    startHM: '21:00',
    endHM: '23:30',
  });
  assert.deepEqual(toPlain(ctx.parseLineupTimeRangeForSync('21:00')), {
    startHM: '21:00',
    endHM: null,
  });

  const slots = toPlain(ctx.buildEventLineupSlotsFromArchive([
    {
      musician: 'DJ A',
      stage: 'Main',
      date: 'Day 2',
      time: '02:30-04:00',
      djId: 'pending:1',
      djIds: ['pending:1', 'dj_123'],
    },
    {
      musician: 'DJ B',
      stage: 'Second',
      date: '2026-07-03',
      time: '23:00-01:00',
      djId: 'dj_456',
    },
  ], '2026-07-01', '2026-07-03', 6));

  assert.equal(slots.length, 2);
  assert.equal(slots[0].festivalDayIndex, 1);
  assert.equal(slots[0].djId, 'dj_123');
  assert.equal(slots[0].stageName, 'Main');
  assert.equal(slots[1].festivalDayIndex, 3);
  assert.equal(slots[1].djId, 'dj_456');

  const start = new Date(slots[1].startTime);
  const end = new Date(slots[1].endTime);
  assert.ok(end.getTime() > start.getTime());
  assert.equal(Math.round((end.getTime() - start.getTime()) / (60 * 60 * 1000)), 2);
});

test('lineup sync helpers normalize backend event image assets and pick primary urls', () => {
  const ctx = loadLineupSyncHelpers();
  const assets = toPlain(ctx.parseBackendEventImageAssets([
    { type: 'poster', url: 'https://cdn/img-3.jpg', order: 3 },
    { type: 'lineup', url: 'https://cdn/img-2.jpg', order: 2, sort: 1 },
    { type: 'cover', url: 'https://cdn/img-1.jpg', order: 0 },
    { type: 'timetable', url: 'https://cdn/img-4.jpg', order: 2, sort: 2 },
  ]));

  assert.deepEqual(assets.map((item) => item.type), ['cover', 'luall', 'tt', 'other']);
  const primary = toPlain(ctx.pickPrimaryEventImageUrls(assets));
  assert.equal(primary.coverImageUrl, 'https://cdn/img-1.jpg');
  assert.equal(primary.lineupImageUrl, 'https://cdn/img-2.jpg');
});

test('lineup sync helpers normalize locationPoint for backend payload', () => {
  const ctx = loadLineupSyncHelpers();
  const point = toPlain(ctx.normalizeLocationPointForSync({
    provider: 'amap',
    sourceMode: 'pin_drag',
    poiId: 'B0AMAP01',
    location: { lng: 120.1551, lat: 30.2741 },
    nameI18n: { zh: '杭州奥体中心', en: '' },
    formattedAddressI18n: { zh: '杭州市滨江区博奥路', en: '' },
  }));
  assert.equal(point.provider, 'amap');
  assert.equal(point.poiId, 'B0AMAP01');
  assert.equal(point.location.lng, 120.1551);
  assert.equal(point.location.lat, 30.2741);
  assert.equal(point.nameI18n.en, '杭州奥体中心');
  assert.equal(point.formattedAddressI18n.en, '杭州市滨江区博奥路');
});
