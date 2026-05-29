const assert = (condition: boolean, message: string): void => {
  if (!condition) throw new Error(message);
};

type TimetableApiSlot = {
  id: string;
  eventId: string;
  lineupArtistId?: string | null;
  eventDayId?: string | null;
  weekIndex?: number | null;
  dayIndexInWeek?: number | null;
  overallDayIndex?: number | null;
  localDate?: string | Date | null;
  festivalDayIndex?: number | null;
  stageName?: string | null;
  sortOrder?: number | null;
  startTime?: string | Date | null;
  endTime?: string | Date | null;
};

const main = (): void => {
  const slot: TimetableApiSlot = {
    id: 'perf-1',
    eventId: 'event-1',
    lineupArtistId: 'artist-1',
    eventDayId: 'w1d1',
    weekIndex: 1,
    dayIndexInWeek: 1,
    overallDayIndex: 1,
    localDate: '2025-07-18T00:00:00.000Z',
    festivalDayIndex: null,
    stageName: 'ATMOSPHERE',
    sortOrder: 81,
    startTime: '2025-07-18T22:00:00.000Z',
    endTime: '2025-07-18T22:55:00.000Z',
  };

  assert(slot.eventDayId === 'w1d1', 'timetable api slot should include eventDayId');
  assert(slot.weekIndex === 1, 'timetable api slot should include weekIndex');
  assert(slot.dayIndexInWeek === 1, 'timetable api slot should include dayIndexInWeek');
  assert(slot.overallDayIndex === 1, 'timetable api slot should include overallDayIndex');
  assert(Boolean(slot.localDate), 'timetable api slot should include localDate');
  assert(slot.festivalDayIndex === null, 'timetable api slot should preserve null festivalDayIndex');

  console.log('[event-timetable-api-guardrails] ok');
};

main();
