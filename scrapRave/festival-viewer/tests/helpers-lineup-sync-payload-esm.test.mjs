import test from 'node:test';
import assert from 'node:assert/strict';

import {
  hasExplicitYearInDateTextForSync,
  normalizeArchiveDateTextForSync,
  parseLineupMonthDayCandidatesForSync,
  resolveLineupDateForSync,
  parseLineupTimeRangeForSync,
  buildEventLineupSlotsFromArchive,
  parseBackendEventImageAssets,
  pickPrimaryEventImageUrls,
} from '../js/esm/core/helpers/lineup-sync-payload-utils.mjs';

function ymd(date) {
  return `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, '0')}-${String(date.getDate()).padStart(2, '0')}`;
}

test('ESM lineup sync helper normalizes date text and explicit year', () => {
  assert.equal(hasExplicitYearInDateTextForSync('２０２６年 10月2日'), true);
  assert.equal(hasExplicitYearInDateTextForSync('Oct 2'), false);

  assert.equal(normalizeArchiveDateTextForSync('2026/7/2'), '2026-07-02');
  assert.equal(normalizeArchiveDateTextForSync('2026年7月2日'), '2026-07-02');
  assert.equal(normalizeArchiveDateTextForSync('2026-07-02T16:00:00Z'), '2026-07-02');
});

test('ESM lineup sync helper resolves date by day-index and month/day candidates', () => {
  assert.deepEqual(parseLineupMonthDayCandidatesForSync('Oct.2 Main Stage'), [{ month: 10, day: 2 }]);
  assert.deepEqual(parseLineupMonthDayCandidatesForSync('2/10 afterparty'), [{ month: 2, day: 10 }, { month: 10, day: 2 }]);

  const start = new Date('2026-07-01T00:00:00');
  const end = new Date('2026-07-03T00:00:00');
  assert.equal(ymd(resolveLineupDateForSync('Day 2', start, end)), '2026-07-02');
  assert.equal(ymd(resolveLineupDateForSync('7月3日', start, end)), '2026-07-03');
});

test('ESM lineup sync helper builds slots with day rollover', () => {
  assert.deepEqual(parseLineupTimeRangeForSync('21:00-23:30'), { startHM: '21:00', endHM: '23:30' });
  assert.deepEqual(parseLineupTimeRangeForSync('21:00'), { startHM: '21:00', endHM: null });

  const slots = buildEventLineupSlotsFromArchive(
    [
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
    ],
    '2026-07-01',
    '2026-07-03',
    6
  );

  assert.equal(slots.length, 2);
  assert.equal(slots[0].festivalDayIndex, 1);
  assert.equal(slots[0].djId, 'dj_123');
  assert.equal(slots[1].festivalDayIndex, 3);
  assert.equal(slots[1].djId, 'dj_456');
});

test('ESM lineup sync helper normalizes event image assets and picks primary urls', () => {
  const assets = parseBackendEventImageAssets([
    { type: 'poster', url: 'https://cdn/img-3.jpg', order: 3 },
    { type: 'lineup', url: 'https://cdn/img-2.jpg', order: 2, sort: 1 },
    { type: 'cover', url: 'https://cdn/img-1.jpg', order: 0 },
    { type: 'timetable', url: 'https://cdn/img-4.jpg', order: 2, sort: 2 },
  ]);

  assert.deepEqual(assets.map((item) => item.type), ['cover', 'luall', 'tt', 'other']);
  const primary = pickPrimaryEventImageUrls(assets);
  assert.equal(primary.coverImageUrl, 'https://cdn/img-1.jpg');
  assert.equal(primary.lineupImageUrl, 'https://cdn/img-2.jpg');
});
