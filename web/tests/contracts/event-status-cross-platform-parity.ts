import assert from "node:assert/strict";

import {
  resolveEventDisplayStatus,
} from "../../src/lib/event-status";

type VisualStatus = "upcoming" | "ongoing" | "ended" | "cancelled";

type EventFixture = {
  id: string;
  startDate: Date;
  endDate: Date;
  status?: string | null;
  isCancelled?: boolean | null;
  visibility?: "visible" | "hidden" | null;
};

const assertDeepEqual = <T>(actual: T, expected: T, label: string): void => {
  assert.deepEqual(actual, expected, `${label}: expected ${JSON.stringify(expected)}, got ${JSON.stringify(actual)}`);
};

const fromRawStatus = (value?: string | null): VisualStatus | null => {
  const normalized = String(value || "").trim().toLowerCase();
  if (normalized === "upcoming") return "upcoming";
  if (normalized === "ongoing") return "ongoing";
  if (normalized === "ended") return "ended";
  if (normalized === "cancelled") return "cancelled";
  return null;
};

const resolveIOSVisualStatus = (event: EventFixture, now: Date): VisualStatus => {
  if (event.isCancelled === true) return "cancelled";
  const fallback = fromRawStatus(event.status);

  if (event.endDate.getTime() < event.startDate.getTime()) {
    return fallback ?? (now < event.startDate ? "upcoming" : "ended");
  }
  if (now < event.startDate) return "upcoming";
  if (now > event.endDate) return "ended";
  return "ongoing";
};

const toServerLikeEvent = (event: EventFixture, now: Date): EventFixture => ({
  ...event,
  status: resolveIOSVisualStatus(event, now),
});

const loadRecommendationsLegacyIOS = (events: EventFixture[], now: Date): string[] => {
  const statuses: VisualStatus[] = ["ongoing", "upcoming", "ended"];
  const candidatesByStatus = new Map<VisualStatus, EventFixture[]>();

  for (const status of statuses) {
    const bucket = events.filter((event) => {
      const resolved = resolveIOSVisualStatus(event, now);
      return resolved === status && resolved !== "cancelled";
    });
    candidatesByStatus.set(status, bucket);
  }

  const selected: EventFixture[] = [];
  const seen = new Set<string>();
  for (const status of statuses) {
    const bucket = candidatesByStatus.get(status) ?? [];
    const picked = bucket.find((event) => !seen.has(event.id));
    if (!picked) continue;
    selected.push(picked);
    seen.add(picked.id);
    if (selected.length >= 10) break;
  }

  const pool = statuses.flatMap((status) => candidatesByStatus.get(status) ?? []);
  for (const event of pool) {
    if (seen.has(event.id)) continue;
    selected.push(event);
    seen.add(event.id);
    if (selected.length >= 10) break;
  }

  return selected.map((event) => event.id);
};

const loadRecommendationsLegacyWeb = (events: EventFixture[], now: Date): string[] => {
  const statuses: VisualStatus[] = ["ongoing", "upcoming", "ended"];
  const candidatesByStatus = new Map<VisualStatus, EventFixture[]>();
  const serverLikeEvents = events.map((event) => toServerLikeEvent(event, now));

  for (const status of statuses) {
    const bucket = serverLikeEvents.filter((event) => {
      const resolved = resolveEventDisplayStatus(event);
      return resolved === status && resolved !== "cancelled";
    });
    candidatesByStatus.set(status, bucket);
  }

  const selected: EventFixture[] = [];
  const seen = new Set<string>();
  for (const status of statuses) {
    const bucket = candidatesByStatus.get(status) ?? [];
    const picked = bucket.find((event) => !seen.has(event.id));
    if (!picked) continue;
    selected.push(picked);
    seen.add(picked.id);
    if (selected.length >= 10) break;
  }

  const pool = statuses.flatMap((status) => candidatesByStatus.get(status) ?? []);
  for (const event of pool) {
    if (seen.has(event.id)) continue;
    selected.push(event);
    seen.add(event.id);
    if (selected.length >= 10) break;
  }

  return selected.map((event) => event.id);
};

const splitDJEventsIOS = (events: EventFixture[], now: Date): { upcoming: string[]; ended: string[] } => {
  const unique = Array.from(new Map(events.map((event) => [event.id, event])).values());
  const upcoming = unique
    .filter((event) => {
      const status = resolveIOSVisualStatus(event, now);
      return status === "ongoing" || status === "upcoming";
    })
    .sort((left, right) => left.startDate.getTime() - right.startDate.getTime())
    .map((event) => event.id);
  const ended = unique
    .filter((event) => {
      const status = resolveIOSVisualStatus(event, now);
      return status === "ended" || status === "cancelled";
    })
    .sort((left, right) => right.startDate.getTime() - left.startDate.getTime())
    .map((event) => event.id);
  return { upcoming, ended };
};

const splitDJEventsWeb = (events: EventFixture[], now: Date): { upcoming: string[]; ended: string[] } => {
  const unique = Array.from(new Map(events.map((event) => [event.id, toServerLikeEvent(event, now)])).values());
  const upcoming = unique
    .filter((event) => {
      const status = resolveEventDisplayStatus(event);
      return status === "ongoing" || status === "upcoming";
    })
    .sort((left, right) => left.startDate.getTime() - right.startDate.getTime())
    .map((event) => event.id);
  const ended = unique
    .filter((event) => {
      const status = resolveEventDisplayStatus(event);
      return status === "ended" || status === "cancelled";
    })
    .sort((left, right) => right.startDate.getTime() - left.startDate.getTime())
    .map((event) => event.id);
  return { upcoming, ended };
};

const now = new Date("2026-08-10T13:00:00.000Z");
const sampleEvents: EventFixture[] = [
  {
    id: "upcoming-a",
    startDate: new Date("2026-08-10T15:00:00.000Z"),
    endDate: new Date("2026-08-10T17:00:00.000Z"),
    isCancelled: false,
    visibility: "visible",
  },
  {
    id: "upcoming-b",
    startDate: new Date("2026-08-10T18:00:00.000Z"),
    endDate: new Date("2026-08-10T20:00:00.000Z"),
    isCancelled: false,
    visibility: "visible",
  },
  {
    id: "ongoing-a",
    startDate: new Date("2026-08-10T11:00:00.000Z"),
    endDate: new Date("2026-08-10T14:00:00.000Z"),
    isCancelled: false,
    visibility: "visible",
  },
  {
    id: "ended-a",
    startDate: new Date("2026-08-10T08:00:00.000Z"),
    endDate: new Date("2026-08-10T10:00:00.000Z"),
    isCancelled: false,
    visibility: "visible",
  },
  {
    id: "cancelled-a",
    startDate: new Date("2026-08-10T09:00:00.000Z"),
    endDate: new Date("2026-08-10T16:00:00.000Z"),
    isCancelled: true,
    visibility: "visible",
  },
  {
    id: "mixed-stale-cancelled",
    startDate: new Date("2026-08-10T15:00:00.000Z"),
    endDate: new Date("2026-08-10T17:00:00.000Z"),
    status: "cancelled",
    isCancelled: false,
    visibility: "visible",
  },
];

for (const event of sampleEvents) {
  const serverLikeEvent = toServerLikeEvent(event, now);
  const iosStatus = resolveIOSVisualStatus(event, now);
  const webStatus = resolveEventDisplayStatus(serverLikeEvent);
  assert.equal(webStatus, iosStatus, `cross-platform status parity for ${event.id}`);
}

assertDeepEqual(
  loadRecommendationsLegacyIOS(sampleEvents, now),
  loadRecommendationsLegacyWeb(sampleEvents, now),
  "legacy recommendations bucket parity"
);

assertDeepEqual(
  splitDJEventsIOS(sampleEvents, now),
  splitDJEventsWeb(sampleEvents, now),
  "DJ related event section parity"
);

console.log("PASS event status cross-platform parity");
