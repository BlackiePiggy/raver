import test from 'node:test';
import assert from 'node:assert/strict';

import {
  parseFolderName,
  classifyImage,
  normalizeBiTextValue,
  splitEventRange,
  resolveCountryAlpha3,
  buildFestivalId,
  resolveFestivalId,
  mergeSourceMeta,
} from '../js/esm/core/helpers/festival-core-utils.mjs';

test('ESM parseFolderName parses valid folder and rejects invalid folder', () => {
  assert.deepEqual(parseFolderName('7-Tomorrowland-Belgium'), {
    month: 7,
    festName: 'Tomorrowland',
    location: 'Belgium',
  });
  assert.equal(parseFolderName('13-Tomorrowland-Belgium'), null);
});

test('ESM classifyImage classifies cover/lineup/timetable/other', () => {
  assert.deepEqual(classifyImage('COVER.jpg'), {
    type: 'cover', label: 'COVER', order: 0, sort: 0,
  });
  assert.deepEqual(classifyImage('LUALL2.png'), {
    type: 'luall', label: 'LINE-UP ALL 2', order: 1, sort: 2,
  });
  assert.deepEqual(classifyImage('TIMETABLE-3.webp'), {
    type: 'tt', label: 'TIMETABLE 3', order: 2, sort: 3,
  });
});

test('ESM normalizeBiTextValue fills missing values', () => {
  assert.deepEqual(
    normalizeBiTextValue({ en: 'Tomorrowland', zh: '' }, 'fallback'),
    { en: 'Tomorrowland', zh: 'Tomorrowland' }
  );
  assert.deepEqual(
    normalizeBiTextValue({ en: { nested: true }, zh: '' }, { bad: true }),
    { en: '', zh: '' }
  );
});

test('ESM splitEventRange parses separators safely', () => {
  assert.deepEqual(
    splitEventRange('2026-07-01 ~ 2026-07-03'),
    { startDate: '2026-07-01', endDate: '2026-07-03' }
  );
  assert.deepEqual(
    splitEventRange('2026-09-01 - 2026-09-02'),
    { startDate: '2026-09-01', endDate: '2026-09-02' }
  );
});

test('ESM buildFestivalId and resolveFestivalId', () => {
  const lookup = { BELGIUM: 'BEL', JAPAN: 'JPN' };
  assert.equal(
    buildFestivalId('2026-07-05', 'Tomorrowland', 'Belgium', lookup),
    '20260705-Tomorrowland-BEL'
  );
  assert.equal(
    resolveFestivalId({ startDate: '2026-09-10', name: 'Ultra Japan', country: 'Japan' }, {}, {}, { lookup }),
    '20260910-UltraJapan-JPN'
  );
  assert.equal(resolveFestivalId({ id: 'evt_manual_001' }, {}), 'evt_manual_001');
});

test('ESM resolveCountryAlpha3 and mergeSourceMeta', () => {
  assert.equal(resolveCountryAlpha3('UK', {}), 'GBR');
  assert.equal(resolveCountryAlpha3('China', { CHINA: 'CHN' }), 'CHN');
  assert.deepEqual(
    mergeSourceMeta(
      { provider: '  FESTTIMETABLE ', slug: ' abc ', eventUrl: ' https://example.com/a ' },
      { provider: 'archive-manual' }
    ),
    { provider: 'festtimetable', slug: 'abc', eventUrl: 'https://example.com/a' }
  );
});
