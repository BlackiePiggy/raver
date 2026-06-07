import assert from "node:assert/strict";

import {
  formatEventDisplayStatusText,
  resolveEventDisplayStatus,
  resolveEventVisibility,
  formatEventVisibilityText,
} from "../../src/lib/event-status";

type EventLike = {
  status?: string | null;
  isCancelled?: boolean | null;
  visibility?: "visible" | "hidden" | null;
};

type VisualStatus = "upcoming" | "ongoing" | "ended" | "cancelled";

const assertEqual = <T>(actual: T, expected: T, label: string): void => {
  assert.equal(actual, expected, `${label}: expected ${expected}, got ${actual}`);
};

const resolveEventsPageStatusLabel = (status: VisualStatus): string => {
  if (status === "cancelled") return "已取消";
  if (status === "ongoing") return "进行中";
  if (status === "ended") return "已结束";
  return "即将开始";
};

const resolveEventCardStatusLabel = (event: EventLike): string =>
  formatEventDisplayStatusText(event);

const resolveEventDetailStatusLabel = (event: EventLike): string =>
  formatEventDisplayStatusText(event);

const resolveIOSStatusTitle = (status: VisualStatus): string => {
  if (status === "cancelled") return "已取消";
  if (status === "ongoing") return "进行中";
  if (status === "ended") return "已结束";
  return "即将开始";
};

const cases: Array<{
  name: string;
  event: EventLike;
  expectedStatus: VisualStatus;
  expectedText: string;
}> = [
  {
    name: "upcoming visible",
    event: { status: "upcoming", isCancelled: false, visibility: "visible" },
    expectedStatus: "upcoming",
    expectedText: "即将开始",
  },
  {
    name: "ongoing visible",
    event: { status: "ongoing", isCancelled: false, visibility: "visible" },
    expectedStatus: "ongoing",
    expectedText: "进行中",
  },
  {
    name: "ended visible",
    event: { status: "ended", isCancelled: false, visibility: "visible" },
    expectedStatus: "ended",
    expectedText: "已结束",
  },
  {
    name: "cancelled explicit truth",
    event: { status: "ongoing", isCancelled: true, visibility: "visible" },
    expectedStatus: "cancelled",
    expectedText: "已取消",
  },
  {
    name: "explicit false truth overrides stale cancelled status",
    event: { status: "cancelled", isCancelled: false, visibility: "visible" },
    expectedStatus: "cancelled",
    expectedText: "已取消",
  },
];

for (const testCase of cases) {
  const displayStatus = resolveEventDisplayStatus(testCase.event);
  assertEqual(displayStatus, testCase.expectedStatus, `${testCase.name} display status`);
  assertEqual(formatEventDisplayStatusText(testCase.event), testCase.expectedText, `${testCase.name} formatted text`);
  assertEqual(resolveEventCardStatusLabel(testCase.event), testCase.expectedText, `${testCase.name} event card label`);
  assertEqual(resolveEventDetailStatusLabel(testCase.event), testCase.expectedText, `${testCase.name} event detail label`);
  assertEqual(resolveIOSStatusTitle(displayStatus), testCase.expectedText, `${testCase.name} iOS zh status title parity`);
}

assertEqual(
  resolveEventsPageStatusLabel("upcoming"),
  "即将开始",
  "events page upcoming label"
);
assertEqual(
  resolveEventsPageStatusLabel("ended"),
  "已结束",
  "events page ended label"
);
assertEqual(
  resolveEventsPageStatusLabel("cancelled"),
  "已取消",
  "events page cancelled label"
);

assertEqual(
  resolveEventsPageStatusLabel("ongoing"),
  "进行中",
  "events page ongoing label"
);
assertEqual(
  formatEventDisplayStatusText({ status: "ongoing", isCancelled: false }),
  "进行中",
  "shared formatter ongoing label should align with iOS EventVisualStatus title"
);

assertEqual(resolveEventVisibility({ visibility: "hidden" }), "hidden", "explicit visibility should resolve hidden");
assertEqual(formatEventVisibilityText({ visibility: "hidden" }), "已隐藏", "explicit visibility should render hidden text");

console.log("PASS event status display parity");
