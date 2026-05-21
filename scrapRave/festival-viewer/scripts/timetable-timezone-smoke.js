#!/usr/bin/env node

const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');

const root = path.resolve(__dirname, '..');

const loadIntoContext = (context, relativePath) => {
  const filePath = path.join(root, relativePath);
  const source = fs.readFileSync(filePath, 'utf8');
  vm.runInContext(source, context, { filename: filePath });
};

const assert = (condition, message) => {
  if (!condition) throw new Error(message);
};

const assertIso = (actual, expected, label) => {
  assert(actual === expected, `${label}: expected ${expected}, got ${actual}`);
};

const context = vm.createContext({
  console,
  Date,
  Intl,
  Math,
  Number,
  String,
  Array,
  Object,
  Set,
  Map,
});

loadIntoContext(context, 'js/core/helpers/10-lineup-poster-review.js');
loadIntoContext(context, 'js/core/helpers/20-lineup-sync-and-payload.js');

const buildSlots = context.buildEventLineupSlotsFromArchive;
assert(typeof buildSlots === 'function', 'buildEventLineupSlotsFromArchive was not loaded');

const amsterdamSlots = buildSlots([
  { musician: 'Daytime DJ', date: 'Day 1', festivalDayIndex: 1, time: '17:00-18:00', stage: 'Main' },
  { musician: 'Midnight DJ', date: 'Day 1', festivalDayIndex: 1, time: '23:30-01:00', stage: 'Main' },
  { musician: 'Afterhours DJ', date: 'Day 1', festivalDayIndex: 1, time: '02:00-03:00', stage: 'Main' },
], '2026-06-01', '2026-06-02', 6, 'Europe/Amsterdam');

assert(amsterdamSlots.length === 3, 'expected three normalized Amsterdam slots');
assertIso(amsterdamSlots[0].startTime, '2026-06-01T15:00:00.000Z', 'Day 1 17:00 start uses event timezone');
assertIso(amsterdamSlots[0].endTime, '2026-06-01T16:00:00.000Z', 'Day 1 18:00 end uses event timezone');
assertIso(amsterdamSlots[1].startTime, '2026-06-01T21:30:00.000Z', 'Day 1 23:30 cross-midnight start');
assertIso(amsterdamSlots[1].endTime, '2026-06-01T23:00:00.000Z', 'Day 1 01:00 cross-midnight end is next local day');
assertIso(amsterdamSlots[2].startTime, '2026-06-02T00:00:00.000Z', 'Day 1 02:00 after rollover uses next real local date');
assertIso(amsterdamSlots[2].endTime, '2026-06-02T01:00:00.000Z', 'Day 1 03:00 after rollover uses next real local date');
assert(amsterdamSlots.every((slot) => slot.festivalDayIndex === 1), 'all test slots should remain grouped under festival Day 1');

const newYorkSlots = buildSlots([
  { musician: 'Daytime DJ', date: 'Day 1', festivalDayIndex: 1, time: '17:00-18:00', stage: 'Main' },
], '2026-06-01', '2026-06-02', 6, 'America/New_York');

assertIso(newYorkSlots[0].startTime, '2026-06-01T21:00:00.000Z', 'timezone change keeps 17:00 wall clock and recomputes UTC');
assertIso(newYorkSlots[0].endTime, '2026-06-01T22:00:00.000Z', 'timezone change keeps 18:00 wall clock and recomputes UTC');

console.log('[festival-viewer timetable-timezone-smoke] ok');
