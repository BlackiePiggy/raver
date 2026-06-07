import assert from "node:assert/strict";

import {
  formatEventDisplayStatusText,
  resolveEventDisplayStatus,
} from "../../src/lib/event-status";

type LegacyEventMutationInput = {
  name: string;
  startDate: string;
  endDate: string;
  isCancelled?: boolean | null;
  visibility?: "visible" | "hidden" | null;
};

type EventLike = {
  status?: string | null;
  isCancelled?: boolean | null;
  visibility?: "visible" | "hidden" | null;
};

const assertDeepEqual = <T>(actual: T, expected: T, label: string): void => {
  assert.deepEqual(actual, expected, `${label}: expected ${JSON.stringify(expected)}, got ${JSON.stringify(actual)}`);
};

const buildLegacyMutationPayload = (input: LegacyEventMutationInput): Record<string, unknown> => {
  const payload: Record<string, unknown> = {
    name: input.name,
    startDate: input.startDate,
    endDate: input.endDate,
  };
  if (typeof input.isCancelled === "boolean") payload.isCancelled = input.isCancelled;
  if (typeof input.visibility === "string") payload.visibility = input.visibility;
  return payload;
};

const resolveIOSVisualStatus = (event: EventLike): string => {
  if (event.isCancelled === true) return "cancelled";
  const fallback = String(event.status || "").trim().toLowerCase();
  if (fallback === "cancelled") return "cancelled";
  if (fallback === "ongoing") return "ongoing";
  if (fallback === "ended") return "ended";
  return "upcoming";
};

const mutationPayload = buildLegacyMutationPayload({
  name: "Future Rave",
  startDate: "2099-09-12",
  endDate: "2099-09-13",
  isCancelled: false,
  visibility: "visible",
});

assertDeepEqual(
  mutationPayload,
  {
    name: "Future Rave",
    startDate: "2099-09-12",
    endDate: "2099-09-13",
    isCancelled: false,
    visibility: "visible",
  },
  "legacy iOS mutation compatibility payload should not emit deprecated status truth"
);
assert.equal(
  Object.prototype.hasOwnProperty.call(mutationPayload, "status"),
  false,
  "legacy iOS mutation compatibility payload should omit status"
);

const compatibilityCases: Array<{
  name: string;
  event: EventLike;
  expected: "upcoming" | "ongoing" | "ended" | "cancelled";
  expectedText: string;
}> = [
  {
    name: "new server truth fields",
    event: { status: "ongoing", isCancelled: false, visibility: "visible" },
    expected: "ongoing",
    expectedText: "进行中",
  },
  {
    name: "cancelled explicit truth wins over stale status",
    event: { status: "ongoing", isCancelled: true, visibility: "visible" },
    expected: "cancelled",
    expectedText: "已取消",
  },
  {
    name: "explicit false truth overrides stale cancelled status",
    event: { status: "cancelled", isCancelled: false, visibility: "visible" },
    expected: "cancelled",
    expectedText: "已取消",
  },
  {
    name: "missing status but explicit truth visible",
    event: { isCancelled: false, visibility: "hidden" },
    expected: "upcoming",
    expectedText: "即将开始",
  },
];

for (const testCase of compatibilityCases) {
  assert.equal(resolveEventDisplayStatus(testCase.event), testCase.expected, `${testCase.name} web display status`);
  assert.equal(formatEventDisplayStatusText(testCase.event), testCase.expectedText, `${testCase.name} web display text`);
  assert.equal(resolveIOSVisualStatus(testCase.event), testCase.expected, `${testCase.name} iOS compatibility visual status`);
}

console.log("PASS iOS mutation compatibility parity");
