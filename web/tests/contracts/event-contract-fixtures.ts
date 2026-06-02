import type { components } from "../../../contracts/generated/web/event-admin";

import createCrossMidnightFixture from "../../../contracts/fixtures/event/golden/create-cross-midnight.json";
import createMapPoiFixture from "../../../contracts/fixtures/event/golden/create-map-poi.json";
import updateClearLocationFixture from "../../../contracts/fixtures/event/golden/update-clear-location.json";
import updateClearI18nFixture from "../../../contracts/fixtures/event/golden/update-clear-i18n.json";
import updateLineupReplaceFixture from "../../../contracts/fixtures/event/golden/update-lineup-replace.json";
import updateScheduleMultiWeekFixture from "../../../contracts/fixtures/event/golden/update-schedule-multi-week.json";

type CreateEventInput = components["schemas"]["CreateEventInput"];
type UpdateEventInput = components["schemas"]["UpdateEventInput"];

type FixtureEntry =
  | { name: string; mode: "create"; payload: unknown }
  | { name: string; mode: "update"; payload: unknown };

const fixtures: FixtureEntry[] = [
  { name: "create-cross-midnight.json", mode: "create", payload: createCrossMidnightFixture },
  { name: "create-map-poi.json", mode: "create", payload: createMapPoiFixture },
  { name: "update-clear-location.json", mode: "update", payload: updateClearLocationFixture },
  { name: "update-clear-i18n.json", mode: "update", payload: updateClearI18nFixture },
  { name: "update-lineup-replace.json", mode: "update", payload: updateLineupReplaceFixture },
  { name: "update-schedule-multi-week.json", mode: "update", payload: updateScheduleMultiWeekFixture },
];

function assert(condition: unknown, message: string): asserts condition {
  if (!condition) {
    throw new Error(message);
  }
}

function assertLogicalDateTime(value: unknown, label: string): void {
  if (value == null) return;
  assert(typeof value === "string", `${label} must be a string when present`);
  assert(/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}$/.test(value), `${label} must be event-local logical datetime`);
  assert(!/[zZ]|[+-]\d{2}:\d{2}$/.test(value), `${label} must not carry timezone suffix`);
}

function assertCanonicalWeekAndDayIdentity(payload: CreateEventInput | UpdateEventInput, label: string): void {
  const weeks = payload.weeks ?? [];
  const eventDays = payload.eventDays ?? [];
  weeks.forEach((week, index) => {
    assert(week.weekIndex === index + 1, `${label} weeks must use 1-based contiguous weekIndex`);
    assert((week.sortOrder ?? index + 1) >= 1, `${label} week sortOrder must be positive`);
  });
  eventDays.forEach((day, index) => {
    assert(day.overallDayIndex === index + 1, `${label} eventDays must use 1-based contiguous overallDayIndex`);
    assert((day.sortOrder ?? index + 1) >= 1, `${label} eventDay sortOrder must be positive`);
    assert(typeof day.eventDayId === "string" && day.eventDayId.length > 0, `${label} eventDayId must be non-empty`);
  });
}

function assertCreateFixture(payloadValue: unknown, label: string): asserts payloadValue is CreateEventInput {
  assert(typeof payloadValue === "object" && payloadValue !== null, `${label} must be an object`);
  const payload = payloadValue as CreateEventInput;
  assert(typeof payload.name === "string" && payload.name.length > 0, `${label} must include name`);
  assert(typeof payload.startDate === "string", `${label} must include startDate`);
  assert(typeof payload.endDate === "string", `${label} must include endDate`);
  assert(payload.schedule?.timeZone, `${label} must include schedule.timeZone`);
  assertCanonicalWeekAndDayIdentity(payload, label);
  (payload.lineupSlots ?? []).forEach((slot, index) => {
    assertLogicalDateTime(slot.startTime, `${label} lineupSlots[${index}].startTime`);
    assertLogicalDateTime(slot.endTime, `${label} lineupSlots[${index}].endTime`);
  });
}

function assertUpdateFixture(payloadValue: unknown, label: string): asserts payloadValue is UpdateEventInput {
  assertCreateFixture(payloadValue, label);
  const payload = payloadValue as UpdateEventInput;
  assert(typeof payload.clearCityI18n === "boolean", `${label} must include clearCityI18n`);
  assert(typeof payload.clearCountryI18n === "boolean", `${label} must include clearCountryI18n`);
  assert(typeof payload.clearWikiFestivalId === "boolean", `${label} must include clearWikiFestivalId`);
  assert(typeof payload.clearManualLocation === "boolean", `${label} must include clearManualLocation`);
  assert(typeof payload.clearLocationPoint === "boolean", `${label} must include clearLocationPoint`);
  assert(typeof payload.clearLatitude === "boolean", `${label} must include clearLatitude`);
  assert(typeof payload.clearLongitude === "boolean", `${label} must include clearLongitude`);
  assert(typeof payload.clearSocialLinks === "boolean", `${label} must include clearSocialLinks`);
  assert(typeof payload.clearStageOrder === "boolean", `${label} must include clearStageOrder`);
  assert(typeof payload.clearLineupSlots === "boolean", `${label} must include clearLineupSlots`);

  if (payload.clearCityI18n) {
    assert(payload.cityI18n === undefined, `${label} must omit cityI18n when clearCityI18n=true`);
  }
  if (payload.clearCountryI18n) {
    assert(payload.countryI18n === undefined, `${label} must omit countryI18n when clearCountryI18n=true`);
  }
  if (payload.clearSocialLinks) {
    assert(payload.socialLinks === null, `${label} must carry socialLinks=null when clearSocialLinks=true`);
  }
}

fixtures.forEach((fixture) => {
  if (fixture.mode === "create") {
    assertCreateFixture(fixture.payload, fixture.name);
    const clearFlagKeys = Object.keys(fixture.payload).filter((key) => key.startsWith("clear"));
    assert(clearFlagKeys.length === 0, `${fixture.name} must not contain clear flags`);
    return;
  }
  assertUpdateFixture(fixture.payload, fixture.name);
});

if (fixtures.length !== 6) {
  throw new Error("Unexpected golden event fixture count");
}
