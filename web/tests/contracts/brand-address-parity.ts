import assert from "node:assert/strict";

import {
  applyOrganizerAddressToEventDraft,
  createEventStudioDraft,
} from "../../src/features/admin-content/event-studio/draft";
import {
  createOrganizerStudioDraft,
  hydrateOrganizerStudioDraftFromOrganizer,
} from "../../src/features/admin-content/organizer-studio/draft";
import {
  mapOrganizerStudioDraftToCreateInput,
  mapOrganizerStudioDraftToUpdateInput,
} from "../../src/features/admin-content/organizer-studio/mapper";
import type {
  OrganizerStudioLoadedOrganizer,
} from "../../src/features/admin-content/organizer-studio/types";

const organizerFixture: OrganizerStudioLoadedOrganizer = {
  id: "brand-tomorrowland",
  name: "Tomorrowland",
  nameI18n: {
    zh: "明日世界",
    en: "Tomorrowland",
    ja: "",
    enFull: "Tomorrowland",
  },
  country: "Belgium",
  countryI18n: {
    zh: "比利时",
    en: "Belgium",
    ja: "",
    enFull: "Belgium",
  },
  city: "Boom",
  cityI18n: {
    zh: "Boom",
    en: "Boom",
    ja: "",
    enFull: "Boom",
  },
  manualLocation: {
    detailAddressI18n: {
      zh: "De Schorre",
      en: "De Schorre",
      ja: "",
      enFull: "De Schorre",
    },
    formattedAddressI18n: {
      zh: "比利时 · Boom · De Schorre",
      en: "Belgium · Boom · De Schorre",
      ja: "",
      enFull: "",
    },
  },
  locationPoint: {
    provider: "mapbox",
    sourceMode: "manual_search",
    providerPlaceId: "mapbox-place-001",
    poiId: null,
    adcode: null,
    location: {
      lng: 4.3854,
      lat: 51.0891,
    },
    nameI18n: {
      zh: "De Schorre",
      en: "De Schorre",
      ja: "",
      enFull: "",
    },
    addressI18n: {
      zh: "Schommelei 1, 2850 Boom",
      en: "Schommelei 1, 2850 Boom",
      ja: "",
      enFull: "",
    },
    formattedAddressI18n: {
      zh: "比利时，安特卫普省，Boom，Schommelei 1",
      en: "Schommelei 1, 2850 Boom, Antwerp, Belgium",
      ja: "",
      enFull: "",
    },
    manualSetAddressI18n: {
      zh: "Tomorrowland Main Entrance",
      en: "Tomorrowland Main Entrance",
      ja: "",
      enFull: "",
    },
    city: "Boom",
    district: null,
    province: "Antwerp",
    countryCode: "BE",
    providerMeta: {
      mapbox: {
        placeId: "mapbox-place-001",
        featureType: "poi",
      },
    },
    selectedAt: "2026-06-08T12:00:00.000Z",
  },
  revision: 7,
};

const mapOnlyOrganizerFixture: OrganizerStudioLoadedOrganizer = {
  id: "brand-map-only",
  name: "Map Only Brand",
  nameI18n: {
    zh: "仅地图主办方",
    en: "Map Only Brand",
    ja: "",
    enFull: "Map Only Brand",
  },
  country: "China",
  countryI18n: {
    zh: "中国",
    en: "China",
    ja: "",
    enFull: "China",
  },
  city: "Shanghai",
  cityI18n: {
    zh: "上海",
    en: "Shanghai",
    ja: "",
    enFull: "Shanghai",
  },
  manualLocation: null,
  locationPoint: {
    provider: "mapbox",
    sourceMode: "manual_search",
    providerPlaceId: "mapbox-place-map-only",
    poiId: "poi-map-only",
    adcode: null,
    location: {
      lng: 121.4547,
      lat: 31.1786,
    },
    nameI18n: {
      zh: "西岸艺术中心",
      en: "West Bund Art Center",
      ja: "",
      enFull: "",
    },
    addressI18n: {
      zh: "徐汇滨江 88 号",
      en: "88 Xuhui Riverside",
      ja: "",
      enFull: "",
    },
    formattedAddressI18n: {
      zh: "中国，上海市，徐汇区，徐汇滨江 88 号",
      en: "88 Xuhui Riverside, Xuhui, Shanghai, China",
      ja: "",
      enFull: "",
    },
    manualSetAddressI18n: undefined,
    city: "Shanghai",
    district: "Xuhui",
    province: "Shanghai",
    countryCode: "CN",
    providerMeta: {
      mapbox: {
        placeId: "mapbox-place-map-only",
        featureType: "poi",
      },
    },
    selectedAt: "2026-06-08T12:30:00.000Z",
  },
  revision: 3,
};

{
  const draft = hydrateOrganizerStudioDraftFromOrganizer(organizerFixture);
  assert.equal(draft.detailAddress.zh, "De Schorre");
  assert.equal(draft.manualSetAddress.zh, "Tomorrowland Main Entrance");
  assert.equal(draft.pickedPlaceName, "De Schorre");
  assert.equal(draft.pickedMapAddress, "Tomorrowland Main Entrance");
  assert.equal(draft.latitude, "51.0891");
  assert.equal(draft.longitude, "4.3854");
}

{
  const draft = createOrganizerStudioDraft("Tomorrowland");
  draft.country = {
    zh: "比利时",
    en: "Belgium",
    ja: "",
    enFull: "Belgium",
  };
  draft.city = {
    zh: "Boom",
    en: "Boom",
    ja: "",
    enFull: "Boom",
  };
  draft.detailAddress = {
    zh: "De Schorre",
    en: "De Schorre",
    ja: "",
    enFull: "De Schorre",
  };
  draft.manualSetAddress = {
    zh: "Tomorrowland Main Entrance",
    en: "Tomorrowland Main Entrance",
    ja: "",
    enFull: "",
  };
  draft.pickedPlaceName = "De Schorre";
  draft.pickedMapAddress = "Schommelei 1, 2850 Boom";
  draft.latitude = "51.0891";
  draft.longitude = "4.3854";
  draft.locationPoint = organizerFixture.locationPoint ?? null;
  draft.rightsConfirmed = true;
  draft.identityConfirmed = true;

  const createPayload = mapOrganizerStudioDraftToCreateInput(draft);
  assert.equal(createPayload.manualLocation?.detailAddressI18n?.zh, "De Schorre");
  assert.equal(createPayload.manualLocation?.formattedAddressI18n?.zh, "比利时 · Boom · De Schorre");
  assert.equal(
    createPayload.locationPoint?.manualSetAddressI18n?.zh,
    "Tomorrowland Main Entrance"
  );
  assert.equal(createPayload.locationPoint?.location.lat, 51.0891);
  assert.equal(createPayload.locationPoint?.location.lng, 4.3854);

  const updatePayload = mapOrganizerStudioDraftToUpdateInput({
    ...draft,
    baseBrandRevision: 7,
  });
  assert.equal(updatePayload.baseBrandRevision, 7);
  assert.equal(
    updatePayload.locationPoint?.manualSetAddressI18n?.en,
    "Tomorrowland Main Entrance"
  );
}

{
  const eventDraft = createEventStudioDraft();
  const applied = applyOrganizerAddressToEventDraft(eventDraft, organizerFixture);
  assert.equal(applied.country.zh, "比利时");
  assert.equal(applied.city.zh, "Boom");
  assert.equal(applied.detailAddress.zh, "De Schorre");
  assert.equal(applied.manualSetAddress.zh, "Tomorrowland Main Entrance");
  assert.equal(applied.latitude, "51.0891");
  assert.equal(applied.longitude, "4.3854");
  assert.equal(applied.pickedPlaceName, "De Schorre");
  assert.equal(
    applied.pickedMapAddress,
    "比利时，安特卫普省，Boom，Schommelei 1"
  );
  assert.notEqual(applied.locationPoint, organizerFixture.locationPoint);
  assert.deepEqual(applied.locationPoint?.providerMeta, organizerFixture.locationPoint?.providerMeta);
}

{
  const draft = hydrateOrganizerStudioDraftFromOrganizer(mapOnlyOrganizerFixture);
  assert.equal(draft.detailAddress.zh, "徐汇滨江 88 号");
  assert.equal(draft.manualSetAddress.zh, "");
  assert.equal(draft.pickedPlaceName, "西岸艺术中心");
  assert.equal(draft.pickedMapAddress, "中国，上海市，徐汇区，徐汇滨江 88 号");
  assert.equal(draft.latitude, "31.1786");
  assert.equal(draft.longitude, "121.4547");

  const createPayload = mapOrganizerStudioDraftToCreateInput(draft);
  assert.equal(createPayload.manualLocation?.detailAddressI18n?.zh, "徐汇滨江 88 号");
  assert.equal(
    createPayload.manualLocation?.formattedAddressI18n?.zh,
    "中国 · 上海 · 徐汇滨江 88 号"
  );
  assert.equal(createPayload.locationPoint?.formattedAddressI18n?.zh, "中国，上海市，徐汇区，徐汇滨江 88 号");
  assert.equal(createPayload.locationPoint?.manualSetAddressI18n, undefined);
  assert.equal(createPayload.locationPoint?.location.lat, 31.1786);
  assert.equal(createPayload.locationPoint?.location.lng, 121.4547);
}

console.log("PASS brand address parity");
