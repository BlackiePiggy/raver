import type { components } from "../../../contracts/generated/web/event-admin";

import createBasicFixture from "../../../contracts/fixtures/event/create-basic.json";
import updateBasicFixture from "../../../contracts/fixtures/event/update-basic.json";
import updateClearLocationFixture from "../../../contracts/fixtures/event/update-clear-location.json";
import updateLineupReplaceFixture from "../../../contracts/fixtures/event/update-lineup-replace.json";
import updateScheduleMultiWeekFixture from "../../../contracts/fixtures/event/update-schedule-multi-week.json";

type CreateEventInput = components["schemas"]["CreateEventInput"];
type UpdateEventInput = components["schemas"]["UpdateEventInput"];
type EventScheduleMode = NonNullable<NonNullable<CreateEventInput["schedule"]>["mode"]>;
type EventLineupSyncMode = Exclude<CreateEventInput["lineupSyncMode"], undefined>;
type EventMutationStatus = Exclude<CreateEventInput["status"], undefined>;

const scheduleModes: EventScheduleMode[] = ["single_day", "multi_day", "multi_week"];
const lineupSyncModes: EventLineupSyncMode[] = ["incremental_fill", "exact_align", null];
const mutationStatuses: EventMutationStatus[] = [
  "draft",
  "upcoming",
  "ongoing",
  "ended",
  "cancelled",
  "canceled",
  null,
];

function assert(condition: unknown, message: string): asserts condition {
  if (!condition) {
    throw new Error(message);
  }
}

function assertScheduleMode(value: unknown, label: string): asserts value is EventScheduleMode {
  assert(scheduleModes.includes(value as EventScheduleMode), `${label} has invalid schedule.mode`);
}

function assertLineupSyncMode(value: unknown, label: string): asserts value is EventLineupSyncMode {
  assert(lineupSyncModes.includes(value as EventLineupSyncMode), `${label} has invalid lineupSyncMode`);
}

function assertMutationStatus(value: unknown, label: string): asserts value is EventMutationStatus {
  assert(mutationStatuses.includes(value as EventMutationStatus), `${label} has invalid status`);
}

function assertCreateEventInput(value: unknown, label: string): asserts value is CreateEventInput {
  assert(typeof value === "object" && value !== null, `${label} must be an object`);

  const input = value as Record<string, unknown>;
  assert(typeof input.name === "string" && input.name.length > 0, `${label} is missing name`);
  assert(typeof input.startDate === "string", `${label} is missing startDate`);
  assert(typeof input.endDate === "string", `${label} is missing endDate`);

  if (input.schedule !== undefined && input.schedule !== null) {
    assert(typeof input.schedule === "object", `${label} schedule must be an object`);
    const schedule = input.schedule as Record<string, unknown>;
    assertScheduleMode(schedule.mode, label);
  }

  if (input.lineupSyncMode !== undefined) {
    assertLineupSyncMode(input.lineupSyncMode, label);
  }

  if (input.status !== undefined) {
    assertMutationStatus(input.status, label);
  }
}

function assertUpdateEventInput(value: unknown, label: string): asserts value is UpdateEventInput {
  assertCreateEventInput(value, label);
}

assertCreateEventInput(createBasicFixture, "create-basic.json");
assertUpdateEventInput(updateBasicFixture, "update-basic.json");
assertUpdateEventInput(updateClearLocationFixture, "update-clear-location.json");
assertUpdateEventInput(updateLineupReplaceFixture, "update-lineup-replace.json");
assertUpdateEventInput(updateScheduleMultiWeekFixture, "update-schedule-multi-week.json");

const createBasic: CreateEventInput = createBasicFixture;
const updateBasic: UpdateEventInput = updateBasicFixture;
const updateClearLocation: UpdateEventInput = updateClearLocationFixture;
const updateLineupReplace: UpdateEventInput = updateLineupReplaceFixture;
const updateScheduleMultiWeek: UpdateEventInput = updateScheduleMultiWeekFixture;

const fixtures = [
  createBasic,
  updateBasic,
  updateClearLocation,
  updateLineupReplace,
  updateScheduleMultiWeek,
];

if (fixtures.length !== 5) {
  throw new Error("Unexpected event contract fixture count");
}
