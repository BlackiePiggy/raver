const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');

const CORE_UTILS_PATH = path.resolve(__dirname, '../js/core/helpers/00-festival-core-utils.js');

function loadCoreUtils(options = {}) {
  const lookup = options.lookup || {};
  const code = fs.readFileSync(CORE_UTILS_PATH, 'utf8');
  const context = {
    console,
    setTimeout,
    clearTimeout,
    window: {
      ISO3166_COUNTRY_DATA: { lookup },
    },
  };
  context.globalThis = context;
  vm.createContext(context);
  vm.runInContext(code, context, { filename: CORE_UTILS_PATH });
  return context;
}

function toPlain(value) {
  return JSON.parse(JSON.stringify(value));
}

test('parseFolderName parses valid folder and rejects invalid folder', () => {
  const ctx = loadCoreUtils();
  const parsed = toPlain(ctx.parseFolderName('7-Tomorrowland-Belgium'));
  assert.deepEqual(parsed, { month: 7, festName: 'Tomorrowland', location: 'Belgium' });

  assert.equal(ctx.parseFolderName('13-Tomorrowland-Belgium'), null);
  assert.equal(ctx.parseFolderName('invalid-folder'), null);
});

test('classifyImage classifies cover/lineup/timetable/other', () => {
  const ctx = loadCoreUtils();
  assert.deepEqual(toPlain(ctx.classifyImage('COVER.jpg')), {
    type: 'cover', label: 'COVER', order: 0, sort: 0,
  });
  assert.deepEqual(toPlain(ctx.classifyImage('LUALL2.png')), {
    type: 'luall', label: 'LINE-UP ALL 2', order: 1, sort: 2,
  });
  assert.deepEqual(toPlain(ctx.classifyImage('TIMETABLE-3.webp')), {
    type: 'tt', label: 'TIMETABLE 3', order: 2, sort: 3,
  });
  assert.deepEqual(toPlain(ctx.classifyImage('custom-banner.jpeg')), {
    type: 'other', label: 'custom-banner', order: 3, sort: 99,
  });
});

test('normalizeBiTextValue fills missing language by fallback', () => {
  const ctx = loadCoreUtils();
  assert.deepEqual(
    toPlain(ctx.normalizeBiTextValue({ en: 'Tomorrowland', zh: '' }, 'fallback')),
    { en: 'Tomorrowland', zh: 'Tomorrowland' }
  );
  assert.deepEqual(
    toPlain(ctx.normalizeBiTextValue('明日世界', '')),
    { en: '明日世界', zh: '明日世界' }
  );
});

test('splitEventRange supports symbols and CJK separators', () => {
  const ctx = loadCoreUtils();
  assert.deepEqual(
    toPlain(ctx.splitEventRange('2026-07-01 ~ 2026-07-03')),
    { startDate: '2026-07-01', endDate: '2026-07-03' }
  );
  assert.deepEqual(
    toPlain(ctx.splitEventRange('2026-08-01到2026-08-02')),
    { startDate: '2026-08-01', endDate: '2026-08-02' }
  );
  assert.deepEqual(
    toPlain(ctx.splitEventRange('2026-09-01 - 2026-09-02')),
    { startDate: '2026-09-01', endDate: '2026-09-02' }
  );
});

test('resolveCountryAlpha3 supports lookup and UK alias', () => {
  const ctx = loadCoreUtils({
    lookup: {
      CHINA: 'CHN',
      中国: 'CHN',
    },
  });
  assert.equal(ctx.resolveCountryAlpha3('China'), 'CHN');
  assert.equal(ctx.resolveCountryAlpha3('中国'), 'CHN');
  assert.equal(ctx.resolveCountryAlpha3('UK'), 'GBR');
});

test('buildFestivalId generates canonical id', () => {
  const ctx = loadCoreUtils({
    lookup: {
      BELGIUM: 'BEL',
    },
  });
  assert.equal(
    ctx.buildFestivalId('2026-07-05', 'Tomorrowland', 'Belgium'),
    '20260705-Tomorrowland-BEL'
  );
  assert.equal(ctx.buildFestivalId('', 'Tomorrowland', 'Belgium'), '');
});

test('resolveFestivalId falls back to explicit id and local id', () => {
  const ctx = loadCoreUtils({
    lookup: {
      JAPAN: 'JPN',
    },
  });
  assert.equal(
    ctx.resolveFestivalId(
      { startDate: '2026-09-10', name: 'Ultra Japan', country: 'Japan' },
      {}
    ),
    '20260910-UltraJapan-JPN'
  );
  assert.equal(
    ctx.resolveFestivalId({ id: 'evt_manual_001' }, {}),
    'evt_manual_001'
  );
  assert.equal(
    ctx.resolveFestivalId({}, { year: 2027, folder: 'my-new-fest' }),
    '20270101-MyNewFest'
  );
});

test('mergeSourceMeta normalizes provider and trims values', () => {
  const ctx = loadCoreUtils();
  assert.deepEqual(
    toPlain(ctx.mergeSourceMeta(
      { provider: '  FESTTIMETABLE ', slug: ' abc ', eventUrl: ' https://example.com/a ' },
      { provider: 'archive-manual' }
    )),
    { provider: 'festtimetable', slug: 'abc', eventUrl: 'https://example.com/a' }
  );
});

test('normalizeFestivalLocationPoint keeps lng/lat and i18n fallback', () => {
  const ctx = loadCoreUtils();
  const normalized = toPlain(ctx.normalizeFestivalLocationPoint({
    provider: 'amap',
    sourceMode: 'manual_search',
    poiId: 'B0TEST',
    location: { lng: 121.4737, lat: 31.2304 },
    nameI18n: { zh: '上海梅赛德斯-奔驰文化中心', en: '' },
    addressI18n: { zh: '世博大道1200号', en: '' },
    formattedAddressI18n: { zh: '上海市浦东新区世博大道1200号', en: '' },
  }));
  assert.equal(normalized.location.lng, 121.4737);
  assert.equal(normalized.location.lat, 31.2304);
  assert.equal(normalized.nameI18n.zh, '上海梅赛德斯-奔驰文化中心');
  assert.equal(normalized.nameI18n.en, '上海梅赛德斯-奔驰文化中心');
  assert.equal(normalized.formattedAddressI18n.en, '上海市浦东新区世博大道1200号');
});
