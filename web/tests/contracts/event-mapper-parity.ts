import assert from "node:assert/strict";

import {
  buildEventStudioScheduleStructure,
  createEmptyEventStudioTimetableSlotDraft,
  createEventStudioDraft,
  hydrateEventStudioDraftFromEvent,
  fillLineupArtistsFromTimetableSlots,
  syncEventStudioLineupState,
  syncEventStudioScheduleStructure,
} from "../../src/features/admin-content/event-studio/draft";
import {
  mapEventStudioDraftToCreateInput,
  mapEventStudioDraftToUpdateInput,
} from "../../src/features/admin-content/event-studio/mapper";
import {
  hydrateDJStudioDraftFromDJ,
} from "../../src/features/admin-content/dj-studio/draft";
import {
  mapDJStudioDraftToCreateInput,
  mapDJStudioDraftToUpdateInput,
} from "../../src/features/admin-content/dj-studio/mapper";
import {
  hydrateNewsStudioDraftFromArticle,
} from "../../src/features/admin-content/news-studio/draft";
import {
  mapNewsStudioDraftToCreateInput,
} from "../../src/features/admin-content/news-studio/mapper";
import {
  hydrateOrganizerStudioDraftFromOrganizer,
} from "../../src/features/admin-content/organizer-studio/draft";
import {
  mapOrganizerStudioDraftToCreateInput,
  mapOrganizerStudioDraftToUpdateInput,
} from "../../src/features/admin-content/organizer-studio/mapper";
import {
  hydrateLabelStudioDraftFromLabel,
} from "../../src/features/admin-content/label-studio/draft";
import {
  mapLabelStudioDraftToCreateInput,
} from "../../src/features/admin-content/label-studio/mapper";

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
      draft.venueName = "The Warehouse";
      draft.venueAddress = "88 Xuhui Riverside";
      draft.sourceEventUrl = "https://example.com/events/future-rave";
      draft.sourceProvider = "manual";
      draft.referenceLinksText = "https://example.com/a\nhttps://example.com/b";
      draft.socialLinksText = '[{"type":"instagram","url":"https://instagram.com/future-rave"}]';
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
      slot.actType = "b2b";
      slot.stageName = "";
      slot.sortOrder = 1;
      slot.startTime = "23:30";
      slot.endTime = "01:00";

      const lineupState = syncEventStudioLineupState(
        {
          ...draft,
          timetableSlots: [slot],
          lineupSyncMode: "exact_align",
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
      assert.equal(payload.venueName, "The Warehouse");
      assert.equal(payload.venueAddress, "88 Xuhui Riverside");
      assert.equal(payload.sourceProvider, "manual");
      assert.deepEqual(payload.referenceLinks, ["https://example.com/a", "https://example.com/b"]);
      assert.deepEqual(payload.socialLinks, [{ type: "instagram", url: "https://instagram.com/future-rave" }]);
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
      assert.equal(payload.lineupArtists?.[0]?.djName, "Anyma B2B MRAK");
      assert.equal(payload.lineupSlots?.[0]?.eventDayId, "d1");
      assert.equal(payload.lineupSlots?.[0]?.festivalDayIndex, null);
      assert.equal(payload.lineupSlots?.[0]?.stageName, "Main Stage");
      assert.equal(payload.lineupSlots?.[0]?.startTime, "2099-09-12T23:30:00");
      assert.equal(payload.lineupSlots?.[0]?.endTime, "2099-09-13T01:00:00");
      assert.equal(payload.lineupSlots?.[0]?.djName, "Anyma B2B MRAK");
      assert.equal((payload.lineupSlots?.[0] as { performerType?: string })?.performerType, "b2b");
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
  {
    name: "syncEventStudioScheduleStructure preserves existing lineup artists unless exact alignment is requested",
    run: () => {
      let draft = createEventStudioDraft();
      draft.startDate = "2099-09-12";
      draft.endDate = "2099-09-13";
      draft.timeZoneSelection = { ...timezoneSelection };
      draft = syncEventStudioScheduleStructure(draft);
      const firstEventDay = draft.eventDays[0];
      const slot = createEmptyEventStudioTimetableSlotDraft(firstEventDay, "Main Stage");
      slot.eventDayId = firstEventDay.eventDayId;
      slot.weekIndex = firstEventDay.weekIndex;
      slot.dayIndexInWeek = firstEventDay.dayIndexInWeek;
      slot.overallDayIndex = firstEventDay.overallDayIndex;
      slot.localDate = firstEventDay.date;
      slot.djId = "dj_anyma";
      slot.memberDjIds = ["dj_anyma"];
      slot.memberNamesText = "Anyma";
      draft.lineupArtists = [
        {
          id: "artist_1",
          canonicalArtistId: "artist_1",
          djId: "dj_manual",
          memberDjIds: ["dj_manual"],
          memberNamesText: "Manual Artist",
          sortOrder: 1,
        },
      ];
      draft.timetableSlots = [slot];

      const incremental = syncEventStudioScheduleStructure({
        ...draft,
        lineupSyncMode: "incremental_fill",
      });
      assert.equal(incremental.lineupArtists.length, 1);
      assert.equal(incremental.lineupArtists[0]?.djId, "dj_manual");

      const exact = syncEventStudioScheduleStructure({
        ...draft,
        lineupSyncMode: "exact_align",
      });
      assert.equal(exact.lineupArtists.length, 1);
      assert.equal(exact.lineupArtists[0]?.djId, "dj_anyma");
    },
  },
  {
    name: "fillLineupArtistsFromTimetableSlots appends only missing timetable artists",
    run: () => {
      const existing = [
        {
          id: "artist_1",
          canonicalArtistId: "artist_1",
          djId: "dj_manual",
          memberDjIds: ["dj_manual"],
          memberNamesText: "Manual Artist",
          sortOrder: 1,
        },
      ];
      const added = fillLineupArtistsFromTimetableSlots(existing, [
        {
          id: "slot_1",
          canonicalSlotId: null,
          lineupArtistId: null,
          eventDayId: "d1",
          weekIndex: 1,
          dayIndexInWeek: 1,
          overallDayIndex: 1,
          localDate: "2099-09-12",
          djId: "dj_manual",
          memberDjIds: ["dj_manual"],
          memberNamesText: "Manual Artist",
          stageName: "Main Stage",
          sortOrder: 1,
          startTime: "21:00",
          endTime: "22:00",
        },
        {
          id: "slot_2",
          canonicalSlotId: null,
          lineupArtistId: null,
          eventDayId: "d1",
          weekIndex: 1,
          dayIndexInWeek: 1,
          overallDayIndex: 1,
          localDate: "2099-09-12",
          djId: "dj_anyma",
          memberDjIds: ["dj_anyma"],
          memberNamesText: "Anyma",
          stageName: "Main Stage",
          sortOrder: 2,
          startTime: "22:00",
          endTime: "23:00",
        },
      ]);
      assert.equal(added.length, 2);
      assert.equal(added[0]?.djId, "dj_manual");
      assert.equal(added[1]?.djId, "dj_anyma");
    },
  },
  {
    name: "mapEventStudioDraftToCreateInput preserves explicit day offsets for cross-day timetable slots",
    run: () => {
      let draft = createEventStudioDraft();
      draft.name.zh = "跨天测试";
      draft.name.en = "Cross Day Test";
      draft.city.zh = "Shanghai";
      draft.country.en = "China";
      draft.timeZoneSelection = { ...timezoneSelection };
      draft.startDate = "2099-09-12";
      draft.endDate = "2099-09-13";
      draft = syncEventStudioScheduleStructure(draft);

      const firstEventDay = draft.eventDays[0];
      const slot = createEmptyEventStudioTimetableSlotDraft(firstEventDay, "Main Stage");
      slot.eventDayId = firstEventDay.eventDayId;
      slot.weekIndex = firstEventDay.weekIndex;
      slot.dayIndexInWeek = firstEventDay.dayIndexInWeek;
      slot.overallDayIndex = firstEventDay.overallDayIndex;
      slot.localDate = firstEventDay.date;
      slot.djId = "dj_anyma";
      slot.memberDjIds = ["dj_anyma"];
      slot.memberNamesText = "Anyma";
      slot.actType = "solo";
      slot.startTime = "23:30";
      slot.endTime = "01:00";
      slot.startDayOffset = 0;
      slot.endDayOffset = 1;
      draft.timetableSlots = [slot];
      draft.lineupArtists = fillLineupArtistsFromTimetableSlots([], [slot]);

      const payload = mapEventStudioDraftToCreateInput(draft);

      assert.equal(payload.lineupSlots?.[0]?.startTime, "2099-09-12T23:30:00");
      assert.equal(payload.lineupSlots?.[0]?.endTime, "2099-09-13T01:00:00");
    },
  },
  {
    name: "hydrateEventStudioDraftFromEvent reads lineup and timetable slots from EventDetail payload",
    run: () => {
      const event = {
        id: "event_1",
        name: "Hydration Test",
        slug: "hydration-test",
        startDate: "2099-09-12T00:00:00Z",
        endDate: "2099-09-13T00:00:00Z",
        venueName: "The Warehouse",
        venueAddress: "88 Xuhui Riverside",
        sourceProvider: "manual",
        referenceLinks: ["https://example.com/a"],
        socialLinks: [{ type: "instagram", url: "https://instagram.com/future-rave" }],
        eventDays: [
          {
            id: "day_1",
            eventDayId: "d1",
            weekIndex: 1,
            dayIndexInWeek: 1,
            overallDayIndex: 1,
            label: "Day 1",
            weekday: "sat",
            date: "2099-09-12",
            sortOrder: 1,
          },
        ],
        lineupArtists: [],
        lineupSlots: [
          {
            id: "slot_1",
            eventDayId: "d1",
            weekIndex: 1,
            dayIndexInWeek: 1,
            overallDayIndex: 1,
            localDate: "2099-09-12",
            djId: "dj_anyma",
            memberDjIds: ["dj_anyma", "dj_mrak"],
            memberNames: ["Anyma", "MRAK"],
            stageName: "Main Stage",
            sortOrder: 1,
            startTime: "2099-09-12T23:30:00",
            endTime: "2099-09-13T01:00:00",
            performerType: "b2b",
          },
        ],
      } as any;

      const draft = hydrateEventStudioDraftFromEvent(event);

      assert.equal(draft.eventDays.length, 1);
      assert.equal(draft.timetableSlots.length, 1);
      assert.equal(draft.timetableSlots[0]?.eventDayId, "d1");
      assert.equal(draft.timetableSlots[0]?.stageName, "Main Stage");
      assert.equal(draft.venueName, "The Warehouse");
      assert.equal(draft.venueAddress, "88 Xuhui Riverside");
      assert.equal(draft.sourceProvider, "manual");
      assert.equal(draft.referenceLinksText, "https://example.com/a");
      assert.equal(draft.socialLinksText, JSON.stringify([{ type: "instagram", url: "https://instagram.com/future-rave" }], null, 2));
      assert.equal(draft.lineupArtists.length, 1);
      assert.equal(draft.lineupArtists[0]?.djId, "dj_anyma");
      assert.deepEqual(draft.lineupArtists[0]?.memberDjIds, ["dj_anyma", "dj_mrak"]);
      assert.equal(draft.lineupArtists[0]?.memberNamesText, "Anyma / MRAK");
    },
  },
  {
    name: "hydrateDJStudioDraftFromDJ and mapper preserve platform links, images and stats",
    run: () => {
      const dj = {
        id: "dj_1",
        name: "Anyma",
        nameI18n: {
          zh: "Anyma",
          en: "Anyma",
          ja: "",
          enFull: "",
        },
        aliases: ["Matteo", "Anyma Project"],
        genres: ["techno", "melodic techno"],
        bio: "Melodic techno producer",
        bioI18n: {
          zh: "Melodic techno producer",
          en: "Melodic techno producer",
          ja: "",
          enFull: "",
        },
        avatarUrl: "https://cdn.example.com/dj/avatar.jpg",
        bannerUrl: "https://cdn.example.com/dj/banner.jpg",
        country: {
          zh: "Italy",
          en: "Italy",
          ja: "",
          enFull: "",
        },
        countryI18n: {
          zh: "Italy",
          en: "Italy",
          ja: "",
          enFull: "",
        },
        spotifyId: "spotify_anyma",
        spotifyUrl: "https://open.spotify.com/artist/anyma",
        spotifyFollowers: 123456,
        appleMusicId: "apple_anyma",
        soundcloudUrl: "https://soundcloud.com/anyma",
        soundcloudId: "soundcloud_anyma",
        instagramUrl: "https://instagram.com/anyma",
        facebookUrl: "https://facebook.com/anyma",
        twitterUrl: "https://twitter.com/anyma",
        youtubeUrl: "https://youtube.com/anyma",
        neteaseUrl: "https://music.163.com/#/artist?id=1",
        qqMusicUrl: "https://y.qq.com/n/ryqq/artist/1",
        website: "https://anyma.com",
        otherPlatformUrl: "https://bandcamp.com/anyma",
        isVerified: true,
        trackCount: 42,
        playlistCount: 7,
        soundCloudFollowers: 555,
        soundCloudFavorites: 99,
      } as any;

      const draft = hydrateDJStudioDraftFromDJ(dj);
      assert.equal(draft.name.zh, "Anyma");
      assert.equal(draft.aliasesText, "Matteo\nAnyma Project");
      assert.equal(draft.avatarImage?.remoteUrl, "https://cdn.example.com/dj/avatar.jpg");
      assert.equal(draft.bannerImage?.remoteUrl, "https://cdn.example.com/dj/banner.jpg");
      assert.equal(draft.spotifyId, "spotify_anyma");
      assert.equal(draft.spotifyUrl, "https://open.spotify.com/artist/anyma");
      assert.equal(draft.spotifyFollowers, "123456");
      assert.equal(draft.website, "https://anyma.com");
      assert.equal(draft.trackCount, "42");
      assert.equal(draft.soundCloudFollowers, "555");

      const createPayload = mapDJStudioDraftToCreateInput(draft);
      const updatePayload = mapDJStudioDraftToUpdateInput(draft);

      for (const payload of [createPayload, updatePayload]) {
        assert.deepEqual(payload.aliases, ["Matteo", "Anyma Project"]);
        assert.deepEqual(payload.genres, ["techno", "melodic techno"]);
        assert.equal(payload.avatarUrl, "https://cdn.example.com/dj/avatar.jpg");
        assert.equal(payload.bannerUrl, "https://cdn.example.com/dj/banner.jpg");
        assert.equal(payload.spotifyId, "spotify_anyma");
        assert.equal(payload.spotifyUrl, "https://open.spotify.com/artist/anyma");
        assert.equal(payload.spotifyFollowers, 123456);
        assert.equal(payload.appleMusicId, "apple_anyma");
        assert.equal(payload.soundcloudUrl, "https://soundcloud.com/anyma");
        assert.equal(payload.soundcloudId, "soundcloud_anyma");
        assert.equal(payload.instagramUrl, "https://instagram.com/anyma");
        assert.equal(payload.facebookUrl, "https://facebook.com/anyma");
        assert.equal(payload.twitterUrl, "https://twitter.com/anyma");
        assert.equal(payload.youtubeUrl, "https://youtube.com/anyma");
        assert.equal(payload.neteaseUrl, "https://music.163.com/#/artist?id=1");
        assert.equal(payload.qqMusicUrl, "https://y.qq.com/n/ryqq/artist/1");
        assert.equal(payload.website, "https://anyma.com");
        assert.equal(payload.otherPlatformUrl, "https://bandcamp.com/anyma");
        assert.equal(payload.trackCount, 42);
        assert.equal(payload.playlistCount, 7);
        assert.equal(payload.soundCloudFollowers, 555);
        assert.equal(payload.soundCloudFavorites, 99);
      }
    },
  },
  {
    name: "hydrateNewsStudioDraftFromArticle and mapper preserve bound entity ids",
    run: () => {
      const article = {
        id: "article_1",
        category: "community",
        source: "Raver",
        title: "Weekend update",
        summary: "Short summary",
        body: "Full body text",
        link: "https://example.com/news/weekend-update",
        coverImageURL: "https://cdn.example.com/news/cover.jpg",
        publishedAt: "2026-05-31T10:00:00.000Z",
        boundDjIDs: ["dj_1", "dj_2"],
        boundBrandIDs: ["brand_1"],
        boundEventIDs: ["event_1", "event_2"],
      } as any;

      const draft = hydrateNewsStudioDraftFromArticle(article);
      assert.equal(draft.title, "Weekend update");
      assert.equal(draft.boundDjIdsText, "dj_1, dj_2");
      assert.equal(draft.boundBrandIdsText, "brand_1");
      assert.equal(draft.boundEventIdsText, "event_1, event_2");

      const payload = mapNewsStudioDraftToCreateInput({
        ...draft,
        boundDjIdsText: "dj_1\ndj_2",
        boundBrandIdsText: "brand_1",
        boundEventIdsText: "event_1, event_2",
      });

      assert.deepEqual(payload.boundDjIDs, ["dj_1", "dj_2"]);
      assert.deepEqual(payload.boundBrandIDs, ["brand_1"]);
      assert.deepEqual(payload.boundEventIDs, ["event_1", "event_2"]);
      assert.equal(payload.coverImageURL, "https://cdn.example.com/news/cover.jpg");
      assert.equal(payload.link, "https://example.com/news/weekend-update");
    },
  },
  {
    name: "hydrateOrganizerStudioDraftFromOrganizer and mapper preserve links and image assets",
    run: () => {
      const organizer = {
        id: "org_1",
        name: "Raver Crew",
        nameI18n: {
          zh: "Raver Crew",
          en: "Raver Crew",
          ja: "",
          enFull: "",
        },
        revision: 12,
        abbreviation: "RC",
        aliases: ["Raver", "RC"],
        country: "China",
        countryI18n: {
          zh: "China",
          en: "China",
          ja: "",
          enFull: "",
        },
        city: "Shanghai",
        cityI18n: {
          zh: "Shanghai",
          en: "Shanghai",
          ja: "",
          enFull: "",
        },
        foundedYear: "2018",
        frequency: "annual",
        frequencyI18n: {
          zh: "annual",
          en: "annual",
          ja: "",
          enFull: "",
        },
        tagline: "Keep dancing",
        introduction: "Organizer introduction",
        descriptionI18n: {
          zh: "Organizer introduction",
          en: "Organizer introduction",
          ja: "",
          enFull: "",
        },
        officialWebsite: "https://raver.example.com",
        facebookUrl: "https://facebook.com/ravercrew",
        instagramUrl: "https://instagram.com/ravercrew",
        twitterUrl: "https://twitter.com/ravercrew",
        youtubeUrl: "https://youtube.com/ravercrew",
        tiktokUrl: "https://tiktok.com/@ravercrew",
        avatarUrl: "https://cdn.example.com/org/avatar.jpg",
        backgroundUrl: "https://cdn.example.com/org/background.jpg",
        imageAssets: [
          {
            url: "https://cdn.example.com/org/avatar.jpg",
            type: "avatar",
            fileName: "avatar.jpg",
          },
          {
            url: "https://cdn.example.com/org/background.jpg",
            type: "background",
            fileName: "background.jpg",
          },
          {
            url: "https://cdn.example.com/org/proof-1.jpg",
            type: "proof",
            fileName: "proof-1.jpg",
          },
        ],
        links: [
          {
            title: "Website",
            icon: "link",
            url: "https://raver.example.com",
          },
          {
            title: "Discord",
            icon: "message-circle",
            url: "https://discord.gg/ravercrew",
          },
        ],
        contributors: [
          {
            id: "user_1",
            username: "alice",
            displayName: "Alice",
            avatarUrl: "https://cdn.example.com/users/alice.jpg",
          },
        ],
        canEdit: true,
      } as any;

      const draft = hydrateOrganizerStudioDraftFromOrganizer(organizer);
      assert.equal(draft.name.zh, "Raver Crew");
      assert.equal(draft.avatarImage?.remoteUrl, "https://cdn.example.com/org/avatar.jpg");
      assert.equal(draft.backgroundImage?.remoteUrl, "https://cdn.example.com/org/background.jpg");
      assert.equal(draft.proofImages.length, 1);
      assert.equal(draft.extraLinks.length, 1);
      assert.equal(draft.extraLinks[0]?.title, "Discord");
      assert.equal(draft.baseBrandRevision, 12);

      const createPayload = mapOrganizerStudioDraftToCreateInput({
        ...draft,
        rightsConfirmed: true,
        identityConfirmed: true,
      });
      const updatePayload = mapOrganizerStudioDraftToUpdateInput({
        ...draft,
        rightsConfirmed: true,
        identityConfirmed: true,
      });

      for (const payload of [createPayload, updatePayload]) {
        assert.equal(payload.officialWebsite, "https://raver.example.com");
        assert.equal(payload.facebookUrl, "https://facebook.com/ravercrew");
        assert.equal(payload.instagramUrl, "https://instagram.com/ravercrew");
        assert.equal(payload.twitterUrl, "https://twitter.com/ravercrew");
        assert.equal(payload.youtubeUrl, "https://youtube.com/ravercrew");
        assert.equal(payload.tiktokUrl, "https://tiktok.com/@ravercrew");
        assert.equal(payload.avatarUrl, "https://cdn.example.com/org/avatar.jpg");
        assert.equal(payload.backgroundUrl, "https://cdn.example.com/org/background.jpg");
        assert.equal(payload.proofImageUrl, "https://cdn.example.com/org/proof-1.jpg");
        assert.deepEqual(payload.imageAssets?.map((item) => item.type), ["avatar", "background", "proof"]);
        assert.deepEqual(payload.links?.map((item) => item.url), ["https://discord.gg/ravercrew"]);
        assert.equal(payload.rightsConfirmed, true);
        assert.equal(payload.identityConfirmed, true);
      }

      assert.equal(updatePayload.baseBrandRevision, 12);
    },
  },
  {
    name: "hydrateLabelStudioDraftFromLabel and mapper preserve founder DJ and profile fields",
    run: () => {
      const label = {
        id: "label_1",
        name: "Afterlife",
        slug: "afterlife",
        profileUrl: "https://raver.example.com/labels/afterlife",
        profileSlug: "afterlife",
        logoUrl: "https://cdn.example.com/label/logo.jpg",
        avatarUrl: "https://cdn.example.com/label/avatar.jpg",
        backgroundUrl: "https://cdn.example.com/label/background.jpg",
        nation: "Italy",
        soundcloudFollowers: 12345,
        likes: 54321,
        genres: ["techno", "melodic techno"],
        genresPreview: "Techno / Melodic Techno",
        latestReleaseListing: "2026 releases",
        locationPeriod: "2010-2026",
        introductionPreview: "Intro preview",
        introduction: "Full intro",
        generalContactEmail: "contact@example.com",
        demoSubmissionUrl: "https://example.com/demo",
        demoSubmissionDisplay: "Demo portal",
        facebookUrl: "https://facebook.com/afterlife",
        soundcloudUrl: "https://soundcloud.com/afterlife",
        musicPurchaseUrl: "https://bandcamp.com/afterlife",
        officialWebsiteUrl: "https://after.life",
        founderName: "Tale Of Us",
        foundedAt: "2016",
        founderDjId: "dj_afterlife",
      } as any;

      const draft = hydrateLabelStudioDraftFromLabel(label);
      assert.equal(draft.founderDjId, "dj_afterlife");
      assert.equal(draft.logoUrl, "https://cdn.example.com/label/logo.jpg");
      assert.equal(draft.avatarUrl, "https://cdn.example.com/label/avatar.jpg");
      assert.equal(draft.backgroundUrl, "https://cdn.example.com/label/background.jpg");
      assert.equal(draft.soundcloudFollowers, "12345");
      assert.equal(draft.likes, "54321");
      assert.equal(draft.genresText, "techno, melodic techno");

      const payload = mapLabelStudioDraftToCreateInput({
        ...draft,
        founderDjId: "dj_afterlife",
      });

      assert.equal(payload.founderDjId, "dj_afterlife");
      assert.equal(payload.profileUrl, "https://raver.example.com/labels/afterlife");
      assert.equal(payload.profileSlug, "afterlife");
      assert.equal(payload.logoUrl, "https://cdn.example.com/label/logo.jpg");
      assert.equal(payload.avatarUrl, "https://cdn.example.com/label/avatar.jpg");
      assert.equal(payload.backgroundUrl, "https://cdn.example.com/label/background.jpg");
      assert.equal(payload.soundcloudFollowers, 12345);
      assert.equal(payload.likes, 54321);
      assert.deepEqual(payload.genres, ["techno", "melodic techno"]);
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
