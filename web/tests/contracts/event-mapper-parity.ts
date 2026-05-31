import assert from "node:assert/strict";

import {
  buildEventStudioScheduleStructure,
  createEmptyEventStudioTimetableSlotDraft,
  createEventStudioDraft,
  syncEventStudioLineupState,
  syncEventStudioScheduleStructure,
} from "../../src/features/admin-content/event-studio/draft";
import {
  mapEventStudioDraftToCreateInput,
  mapEventStudioDraftToUpdateInput,
} from "../../src/features/admin-content/event-studio/mapper";

type TestCase = {
  name: string;
  run: () => void;
};

const timezoneSelection = {
  city: "Shanghai",
  cityAscii: "Shanghai",
  province: "Shanghai",
  exactProvince: "Shanghai",
  stateAnsi: "SH",
  country: "China",
  iso2: "CN",
  iso3: "CHN",
  timezone: "Asia/Shanghai",
  lat: 31.2304,
  lng: 121.4737,
  population: 24870895,
  label: "Shanghai, China · Asia/Shanghai",
  matchSource: "contract-parity",
} as const;

const tests: TestCase[] = [
  {
    name: "buildEventStudioScheduleStructure uses iOS-compatible identifiers and 1-based indexes",
    run: () => {
      const singleDay = buildEventStudioScheduleStructure("single_day", "2099-09-12", "2099-09-12");
      assert.deepEqual(singleDay.weeks.map((week) => week.weekIndex), [1]);
      assert.deepEqual(singleDay.eventDays.map((day) => day.eventDayId), ["d1"]);
      assert.deepEqual(singleDay.eventDays.map((day) => day.sortOrder), [1]);

      const multiWeek = buildEventStudioScheduleStructure("multi_week", "2099-07-17", "2099-07-26");
      assert.deepEqual(multiWeek.weeks.map((week) => week.weekIndex), [1, 2]);
      assert.deepEqual(
        multiWeek.eventDays.map((day) => day.eventDayId),
        ["w1d1", "w1d2", "w1d3", "w1d4", "w1d5", "w1d6", "w1d7", "w2d1", "w2d2", "w2d3"]
      );
      assert.equal(multiWeek.eventDays[7]?.weekIndex, 2);
      assert.equal(multiWeek.eventDays[7]?.dayIndexInWeek, 1);
      assert.equal(multiWeek.eventDays[7]?.overallDayIndex, 8);
    },
  },
  {
    name: "mapEventStudioDraftToCreateInput matches EventUploadFlow schedule, address, lineup and clearless payload semantics",
    run: () => {
      let draft = createEventStudioDraft();
      draft.name = {
        zh: "未来电音派对",
        en: "Future Rave",
        ja: "",
        enFull: "",
      };
      draft.description = "Warehouse night with cross-midnight closing set.";
      draft.abbreviation = "FR2099";
      draft.eventType = "festival";
      draft.organizerFestivalId = "fest_future_rave";
      draft.organizerName = "Raver Crew";
      draft.sourceEventUrl = "https://example.com/events/future-rave";
      draft.city = {
        zh: "上海",
        en: "Shanghai",
        ja: "",
        enFull: "",
      };
      draft.country = {
        zh: "中国",
        en: "China",
        ja: "",
        enFull: "China",
      };
      draft.detailAddress = {
        zh: "徐汇滨江 88 号",
        en: "88 Xuhui Riverside",
        ja: "",
        enFull: "",
      };
      draft.latitude = "31.1891";
      draft.longitude = "121.4542";
      draft.pickedPlaceName = "Riverside Warehouse";
      draft.pickedMapAddress = "88 Xuhui Riverside";
      draft.timeZoneSelection = { ...timezoneSelection };
      draft.startDate = "2099-09-12";
      draft.endDate = "2099-09-13";
      draft.scheduleMode = "multi_day";
      draft.dayRolloverHour = "7";
      draft.ticketUrl = "https://tickets.example.com/future-rave";
      draft.ticketCurrency = "cny";
      draft.ticketNotes = "Early bird before 23:00.";
      draft.officialWebsite = "https://example.com/future-rave";
      draft.imageZones.cover = [
        {
          id: "cover_1",
          remoteUrl: "https://cdn.example.com/events/future-rave/cover.jpg",
          fileName: "cover.jpg",
          usage: "cover",
          origin: "persisted",
          sortOrder: 1,
        },
      ];
      draft.imageZones.lineup = [
        {
          id: "lineup_1",
          remoteUrl: "https://cdn.example.com/events/future-rave/lineup.jpg",
          fileName: "lineup.jpg",
          usage: "lineup",
          origin: "persisted",
          sortOrder: 1,
        },
      ];
      draft.ticketTiers = [
        { id: "tier_1", name: "Early Bird", price: "199", currency: "cny" },
        { id: "tier_2", name: "Final Release", price: "299", currency: "cny" },
      ];

      draft = syncEventStudioScheduleStructure(draft);
      const firstEventDay = draft.eventDays[0];
      assert.ok(firstEventDay);

      const slot = createEmptyEventStudioTimetableSlotDraft(firstEventDay, "");
      slot.eventDayId = firstEventDay.eventDayId;
      slot.weekIndex = firstEventDay.weekIndex;
      slot.dayIndexInWeek = firstEventDay.dayIndexInWeek;
      slot.overallDayIndex = firstEventDay.overallDayIndex;
      slot.localDate = firstEventDay.date;
      slot.djId = "dj_anyma";
      slot.memberDjIds = ["dj_anyma", "dj_mrak"];
      slot.memberNamesText = "Anyma / MRAK";
      slot.stageName = "";
      slot.sortOrder = 1;
      slot.startTime = "23:30";
      slot.endTime = "01:00";

      const lineupState = syncEventStudioLineupState(
        {
          ...draft,
          timetableSlots: [slot],
        },
        draft.eventDays
      );
      draft = {
        ...draft,
        ...lineupState,
        lineupSyncMode: "exact_align",
      };

      const payload = mapEventStudioDraftToCreateInput(draft);

      assert.deepEqual(payload.weeks?.map((week) => week.weekIndex), [1]);
      assert.deepEqual(payload.eventDays?.map((day) => day.eventDayId), ["d1", "d2"]);
      assert.equal(payload.manualLocation?.formattedAddressI18n?.zh, "中国 · 上海 · 徐汇滨江 88 号");
      assert.equal(payload.manualLocation?.formattedAddressI18n?.en, "China · Shanghai · 88 Xuhui Riverside");
      assert.equal(payload.locationPoint?.formattedAddressI18n?.zh, "中国 · 上海 · 徐汇滨江 88 号");
      assert.equal(payload.locationPoint?.formattedAddressI18n?.en, "China · Shanghai · 88 Xuhui Riverside");
      assert.deepEqual(
        payload.ticketTiers?.map(({ name, price, currency, sortOrder }) => ({ name, price, currency, sortOrder })),
        [
          { name: "Early Bird", price: 199, currency: "CNY", sortOrder: 1 },
          { name: "Final Release", price: 299, currency: "CNY", sortOrder: 2 },
        ]
      );
      assert.deepEqual(payload.stageOrder, ["Main Stage"]);
      assert.equal(payload.lineupArtists?.[0]?.djId, "dj_anyma");
      assert.deepEqual(payload.lineupArtists?.[0]?.memberDjIds, ["dj_anyma", "dj_mrak"]);
      assert.deepEqual(payload.lineupArtists?.[0]?.memberNames, ["Anyma", "MRAK"]);
      assert.equal(payload.lineupArtists?.[0]?.djName, "Anyma / MRAK");
      assert.equal(payload.lineupSlots?.[0]?.eventDayId, "d1");
      assert.equal(payload.lineupSlots?.[0]?.festivalDayIndex, null);
      assert.equal(payload.lineupSlots?.[0]?.stageName, "Main Stage");
      assert.equal(payload.lineupSlots?.[0]?.startTime, "2099-09-12T23:30:00");
      assert.equal(payload.lineupSlots?.[0]?.endTime, "2099-09-13T01:00:00");
      assert.equal(payload.lineupSyncMode, "exact_align");
      assert.equal(payload.status, "upcoming");
    },
  },
  {
    name: "mapEventStudioDraftToUpdateInput sets explicit clear semantics for location and emptied collections",
    run: () => {
      let draft = createEventStudioDraft();
      draft.name = {
        zh: "活动清空测试",
        en: "Clear Semantics Event",
        ja: "",
        enFull: "",
      };
      draft.city = {
        zh: "上海",
        en: "Shanghai",
        ja: "",
        enFull: "",
      };
      draft.country = {
        zh: "中国",
        en: "China",
        ja: "",
        enFull: "China",
      };
      draft.timeZoneSelection = { ...timezoneSelection };
      draft.startDate = "2099-10-03";
      draft.endDate = "2099-10-03";

      draft = syncEventStudioScheduleStructure(draft);

      const payload = mapEventStudioDraftToUpdateInput(draft);

      assert.equal(payload.clearWikiFestivalId, true);
      assert.equal(payload.clearManualLocation, true);
      assert.equal(payload.clearLocationPoint, true);
      assert.equal(payload.clearLatitude, true);
      assert.equal(payload.clearLongitude, true);
      assert.equal(payload.clearStageOrder, true);
      assert.equal(payload.clearLineupSlots, true);
      assert.equal(payload.coverImageUrl, null);
      assert.equal(payload.lineupImageUrl, null);
      assert.equal(payload.timeZoneProvince, "Shanghai");
    },
  },
];

let failures = 0;

for (const test of tests) {
  try {
    test.run();
    console.log(`PASS ${test.name}`);
  } catch (error) {
    failures += 1;
    console.error(`FAIL ${test.name}`);
    console.error(error);
  }
}

if (failures > 0) {
  process.exit(1);
}
