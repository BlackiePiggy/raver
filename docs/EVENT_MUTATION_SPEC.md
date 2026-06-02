# Event Mutation Spec

Authoritative contract for event create and update payloads shared by web, iOS, server, and BFF.

## Scope

This spec defines the canonical write semantics for:

- `CreateEventInput`
- `UpdateEventInput`
- schedule foundation fields
- location authoring fields
- lineup and timetable fields
- destructive clear-flag behavior

If runtime behavior, client mappers, tests, or examples disagree with this document, this document wins and the code must be updated.

## Canonical Principles

1. Event writes are full-state mutations, not per-field patch diffs.
2. HTTP `PATCH` is transport only. `UpdateEventInput` still carries full editing state for destructive fields.
3. Logical event dates and lineup slot times are event-local values, not UTC instants.
4. `weeks` and `eventDays` use canonical semantic identities on write.
5. `ticketTiers`, `stageOrder`, and `lineupSlots` are replace-all collections.
6. `clearCityI18n` and `clearCountryI18n` are destructive-only actions that may only be emitted from explicit UI intent.

## Create vs Update

### Create

- `CreateEventInput` never carries `clear*` flags.
- Omitted optional fields mean "not set on create".
- Clients may omit `cityI18n` / `countryI18n` on create when the user explicitly wants plain-string-only authoring.

### Update

- `UpdateEventInput` uses full-state semantics for destructive fields.
- The following clear flags are required on every update:
  - `clearCityI18n`
  - `clearCountryI18n`
  - `clearWikiFestivalId`
  - `clearManualLocation`
  - `clearLocationPoint`
  - `clearLatitude`
  - `clearLongitude`
  - `clearSocialLinks`
  - `clearStageOrder`
  - `clearLineupSlots`
- Field-or-clear pairs:
  - `wikiFestivalId` or `clearWikiFestivalId`
  - `manualLocation` or `clearManualLocation`
  - `locationPoint` or `clearLocationPoint`
  - `latitude` or `clearLatitude`
  - `longitude` or `clearLongitude`
  - `socialLinks` or `clearSocialLinks`
  - `stageOrder` or `clearStageOrder`
  - `lineupSlots` or `clearLineupSlots`
- Conflict rule:
  - If `clearX = true`, the corresponding payload field must be omitted or `null`, never populated.

## Timezone and Logical Time

- `startDate` and `endDate` are logical event dates in the event timezone.
- `schedule.timeZone` is the canonical event timezone.
- `dayRolloverHour` is event-local and participates in schedule interpretation.
- `lineupSlots[].startTime` and `lineupSlots[].endTime` must be event-local logical datetime strings:
  - format: `YYYY-MM-DDTHH:mm:ss`
  - no trailing `Z`
  - no numeric UTC offset

## Schedule Foundation

- `schedule.mode` enum:
  - `single_day`
  - `multi_day`
  - `multi_week`
- `weeks[].weekIndex` is 1-based and is the canonical week identity on write.
- `eventDays[].eventDayId` is the canonical event-day identity on write.
- `eventDays[].overallDayIndex` is 1-based and monotonic across the full event.
- `EventWeek.id` and `EventDay.id` are hydration-only and ignored on write.

## Collections

### Ticket Tiers

- `ticketTiers` are replace-all.
- `ticketTiers[].id` is ignored on write and must not be treated as a patch key.

### Stage Order

- `stageOrder` is replace-all.
- If omitted on update, `clearStageOrder` must be `true`.

### Lineup Slots

- `lineupSlots` are replace-all.
- If omitted on update, `clearLineupSlots` must be `true`.

## Stage Fallback

When a lineup slot does not carry a usable `stageName`:

1. Use the first explicit `stageOrder` entry, if present.
2. Otherwise use `Main Stage`.

Never fabricate labels like `Stage 2` or `Stage 3`.

## Location Contract

Canonical event location write fields:

- `city`
- `cityI18n`
- `country`
- `countryI18n`
- `manualLocation`
- `locationPoint`
- `latitude`
- `longitude`
- `venueName`
- `venueAddress`

Plain `city` / `country` strings should prefer canonical English values when available, while localized variants stay in
`cityI18n` / `countryI18n`.

### `locationPoint`

- `provider` is canonical and must come from the shared enum.
- `sourceMode` is canonical and must come from the shared enum.
- `adcode` is part of the write contract.
- `providerMeta` is part of the write contract.
- `manualLocation` and `locationPoint` may coexist when the authored event keeps both a display address and a provider-backed point.

### Explicit i18n removal

- `clearCityI18n` and `clearCountryI18n` are only valid after an explicit user action like "Remove i18n".
- Blank form state alone must never imply these flags.
- When clearing city/country i18n:
  - preserve plain `city` / `country`
  - omit `cityI18n` / `countryI18n`
  - emit the matching clear flag as `true` on update

## AI / Import Boundary

Canonical event mutation payloads must contain only durable event write state.

The following are not canonical event write fields and must stay outside the mutation contract:

- unresolved import warnings
- AI extraction confidence
- import provenance and raw model responses
- transient draft-only UI bookkeeping

## Golden Fixtures

Canonical examples live under `contracts/fixtures/event/golden/`:

- `create-cross-midnight.json`
- `create-map-poi.json`
- `update-clear-location.json`
- `update-clear-i18n.json`
- `update-lineup-replace.json`
- `update-schedule-multi-week.json`

These fixtures are the shared reference payloads for:

- web mapper conformance
- server contract guardrails
- iOS parity tests

## Acceptance Criteria

The contract is considered aligned when:

1. web and iOS emit payloads matching the relevant golden fixtures
2. server guardrails accept every golden fixture
3. destructive update behavior is explicit and never inferred from blank UI state
