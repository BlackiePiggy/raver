# Event Timetable Timezone Implementation Plan

## Purpose

This document is the main execution tracker for event timetable timezone behavior across festival-viewer, the BFF/backend, iOS, and future notification/runtime features.

Every timetable-related code change must update this document in the same patch or follow-up patch. The goal is to keep product rules, engineering progress, and verification status aligned instead of letting each client interpret timetable time independently.

## Core Contract

- [x] Editing contract defined: timetable input is always interpreted as the event local wall time.
- [x] Display contract defined: festival-viewer and iOS must display timetable time in the event timezone, not the user's device timezone.
- [x] Storage contract defined: backend stores real UTC instants for `startAt/startTime` and `endAt/endTime`.
- [x] Runtime contract defined: live/current DJ calculations compare real instants, while UI labels and day grouping use event local time.
- [x] Day grouping contract defined: `festivalDayIndex` is a festival day, not a calendar day.
- [x] Timezone input contract defined: users select/confirm an event city or city-region match; clients do not ask users to manually type IANA timezone names or fixed UTC offsets.

## Product Rules

### Timezone Selection

- [x] Event creation/editing UI must collect an event city/search term, not a raw timezone name or manual offset.
- [x] The selected city result resolves to one authoritative IANA timezone string stored as `event.timeZone`, for example `America/Chicago`.
- [x] `event.timeZone` remains the canonical data contract used by backend, iOS, Web, and festival-viewer for conversion/display.
- [x] Fixed offsets such as `UTC+1`, `GMT-0500`, or manually entered offset fields are not valid event timezone inputs.
- [x] Ambiguous city names must show a disambiguation list with city, province/state, country, and timezone before save.
- [x] Existing events that already have `event.timeZone` remain valid; editors should display the resolved city selector when enough location data exists, and fall back to showing the stored timezone as read-only/legacy metadata until the user chooses a city.

Implementation direction:

- Use the `city-timezones` package as the city-to-IANA-timezone lookup source.
- Prefer a shared backend/BFF lookup endpoint so Web, festival-viewer, and iOS receive the same search results and ranking behavior.
- Store the selected city metadata separately when useful, for example `timeZoneCity`, `timeZoneCountry`, `timeZoneProvince`, `timeZoneLat`, `timeZoneLng`; do not derive future timezone behavior from fixed coordinates or offsets.
- For exact city search use `lookupViaCity(city)`. For user search boxes and ambiguous terms use `findFromCityStateProvince(searchString)`.
- If multiple matches are returned, the user must choose one. Do not silently pick the first result except when there is exactly one high-confidence exact match.
- If no city match is found, show a validation error and allow editing the city/search text; do not expose raw offset entry as fallback.

DST note:

- `city-timezones` does not calculate daylight-saving transitions for a timetable slot. It maps a city to an IANA timezone identifier.
- DST correctness comes from using that IANA timezone identifier with IANA-aware conversion APIs such as backend timezone utilities, JavaScript `Intl`, and Swift `TimeZone`/`Calendar`.
- Therefore the package is acceptable for timezone discovery, but all real date/time conversion must continue to use IANA timezone-aware libraries and tests.

### Timetable Editing

- [x] `Day 1 17:00-18:00` means 17:00-18:00 in `event.timeZone`.
- [x] `event.startDate = 2026-06-01` means local `2026-06-01 00:00:00` in `event.timeZone`.
- [x] Day 1 entries may occur at any local time on the event start date.
- [x] Multi-timezone events are out of scope for now; one event has one authoritative `event.timeZone`.
- [x] Editors must always show and edit timetable rows as `Day N + HH:mm-HH:mm`.
- [x] Editors must not expose UTC ISO strings as the primary editing surface.

### Cross-Midnight Ranges

- [x] `23:30-01:00` means the end time is on the next local calendar day.
- [x] A performance whose local clock time is after midnight can still belong to the previous festival day.
- [x] `dayRolloverHour` is the configurable boundary for festival-day grouping.
- [x] Default `dayRolloverHour` remains `6` unless a future product decision changes it.

### One-Song / Invalid Ranges

- [x] Define behavior for `10:00-10:00`.
- [x] Define behavior for `10:00-09:00`.
- [x] Define behavior for missing day/date.
- [x] Define behavior for malformed clock values such as `30:00`.
- [x] Add validation/error UI instead of silently producing surprising times.

Final behavior:

- `10:00-10:00`: reject with a validation message unless explicitly modeled as an instant-only appearance.
- `10:00-09:00`: allow as an explicit cross-midnight range; end is on the next local calendar day.
- Missing day/date: reject in the structured editor; imported raw JSON may normalize to Day 1 only if the user accepts the preview.
- Malformed clocks: reject before save.

### Festival Day Versus Real Date

- [x] Preserve both concepts:
  - `festivalDayIndex`: display/grouping day.
  - `startAt/endAt` or `startTime/endTime`: real UTC instants.
- [x] Ensure display grouping never relies only on raw date text.
- [x] Ensure event date/timezone edits can rebase timetable slots from `festivalDayIndex + wall clock`.

### Event Timezone Changes

- [x] Product rule confirmed: when `event.timeZone` changes, keep local wall-clock timetable values unchanged and recompute UTC instants.
- [x] Product rule updated: changing the event city can change `event.timeZone`; this is treated the same as a timezone change.
- [x] festival-viewer edit save must preserve wall clock and recompute UTC after timezone change.
- [x] BFF update path must preserve wall clock and recompute UTC after timezone change when timetable is submitted.
- [x] iOS edit flow must preserve wall clock and recompute UTC after timezone change.

### Event Start Date Changes

- [x] Product rule confirmed: when event start date changes, Day 1 timetable entries move with the event.
- [x] festival-viewer edit save must rebase timetable UTC instants from `festivalDayIndex + wall clock`.
- [x] BFF update path must rebase existing canonical timetable slots when start date changes.
- [x] iOS edit flow must rebase timetable rows using `festivalDayIndex + wall clock`.

### Display

- [x] festival-viewer detail and edit views display timetable time in `event.timeZone`.
- [x] iOS Event detail timetable displays timetable time in `event.timeZone`.
- [x] iOS live discussion / routine views display timetable time in `event.timeZone`.
- [x] Web event detail displays timetable time in `event.timeZone`.
- [x] UI should show the event timezone near the timetable or event date.

### Live / Runtime Current DJ

- [x] Current DJ detection should use real instants: `slot.startAt <= now < slot.endAt`.
- [x] Current DJ display should format clocks using `event.timeZone`.
- [x] Current festival day grouping should use `event.timeZone + dayRolloverHour`.
- [x] iOS realtime discussion capsule / live room uses UTC instant comparison for active performers.
- [x] festival-viewer realtime/debug current-performer views are not present today; any future current-performer view must use UTC instant comparison before display.
- [x] Future reminders/countdowns trigger by UTC instant.
- [x] Future reminder/countdown copy displays event local time, optionally with user's local time as secondary text.

Reminder/copy rule:

- Reminder scheduling and countdown comparisons must use stored UTC instants only.
- User-facing reminder copy should show event-local time first, for example `Day 1 17:00 (Europe/Amsterdam)`.
- User-local time can be secondary text for convenience, but it must not replace the event-local timetable label.

### DST

- [x] DST must be considered.
- [x] Add tests for nonexistent local times during spring-forward transitions.
- [x] Add tests for ambiguous local times during fall-back transitions.
- [x] Define UI behavior for nonexistent local times.
- [x] Define UI behavior for ambiguous local times.
- [x] Ensure backend timezone utilities convert local wall time with IANA timezone data, not fixed offsets.
- [x] Ensure city lookup only supplies IANA timezone identifiers and never replaces DST-aware conversion logic with fixed offsets.

Proposed DST behavior:

- Nonexistent local time: reject with a clear validation message.
- Ambiguous local time: choose the earlier occurrence by default and expose a future escape hatch only if real data needs it.

UI behavior:

- Editors should block saving a nonexistent local time and explain that this clock time does not exist in the event timezone because of daylight-saving time.
- Editors do not need to expose a disambiguation picker for fall-back duplicated clock times yet; backend conversion chooses the earlier occurrence consistently.
- If future real event data requires the later occurrence, add an advanced per-slot disambiguation field instead of changing the default.

## Existing Implementation Notes

### festival-viewer

- [x] Current sync path reads `event.timeZone` when building backend payload.
- [x] Current sync path converts local timetable wall time to UTC ISO before submitting.
- [x] Current modal/editor direction is moving toward `Day N + HH:mm-HH:mm`.
- [x] Backend UTC lineup slots are mapped back to archive/editor rows using `event.timeZone`, not the viewer device timezone.
- [x] Validate cross-midnight and invalid time ranges consistently in the structured timetable editor.
- [x] Replace raw timezone selector/input with city search and city-timezone confirmation.
- [x] Call the shared city-timezone lookup endpoint or equivalent shared resolver instead of maintaining a separate timezone list.
- [x] Persist enough wall-clock metadata in form state so timezone/start-date changes can rebase correctly.
- [x] Ensure imported timetable JSON normalizes to the same internal shape as structured editor rows.

Relevant files:

- [20-lineup-sync-and-payload.js](/Users/blackie/Projects/raver/scrapRave/festival-viewer/js/core/helpers/20-lineup-sync-and-payload.js)
- [20-modal-and-render.js](/Users/blackie/Projects/raver/scrapRave/festival-viewer/js/features/timetable/20-modal-and-render.js)
- [10-archive-row-render.js](/Users/blackie/Projects/raver/scrapRave/festival-viewer/js/features/event/10-archive-row-render.js)
- [20-add-event-modal.js](/Users/blackie/Projects/raver/scrapRave/festival-viewer/js/features/import/20-add-event-modal.js)

### Backend / BFF

- [x] Backend timezone utility has IANA timezone normalization.
- [x] Event create/update paths parse local date inputs in the event timezone.
- [x] Canonical performance storage uses UTC instants.
- [x] Add shared city-timezone lookup using `city-timezones`.
- [x] Add API endpoint for city timezone search returning city, province/state, country, coordinates, and IANA timezone.
- [x] Validate submitted event timezone against the selected city result when city metadata is present.
- [x] Add or verify tests for DST conversion.
- [x] Add or verify tests for timezone change preserving wall clock.
- [x] Add or verify tests for event start-date change rebasing Day N slots.
- [x] Add validation for malformed timetable clock values at API boundary.

Relevant files:

- [event-timezone.ts](/Users/blackie/Projects/raver/server/src/utils/event-timezone.ts)
- [bff.web.routes.ts](/Users/blackie/Projects/raver/server/src/routes/bff.web.routes.ts)
- [event-lineup-canonical.service.ts](/Users/blackie/Projects/raver/server/src/services/event-lineup-canonical.service.ts)

### iOS

- [x] Event detail timetable must format with `event.eventTimeZone`, not device timezone.
- [x] Event editor must treat `Day N + HH:mm-HH:mm` as event local wall time.
- [x] Event editor must replace manual timezone selection with city search/selection.
- [x] Event editor should call the shared city-timezone lookup endpoint; iOS should not maintain an independent hardcoded timezone/offset list.
- [x] Event editor timezone changes must recompute UTC while preserving wall clock.
- [x] Event editor start-date changes must move Day N entries with the event.
- [x] Live discussion / current DJ detection must compare real instants and display event local time.
- [x] Add regression checks for user device timezone differing from event timezone.

Relevant files to inspect during implementation:

- [WebFeatureModels.swift](/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Core/WebFeatureModels.swift)
- [EventDetailView.swift](/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Discover/Events/Views/EventDetailView.swift)
- [EventEditorView.swift](/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Discover/Events/Views/EventEditorView.swift)
- [LiveWebFeatureService.swift](/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Core/LiveWebFeatureService.swift)

### Web

- [x] Event detail timetable display must format with `event.timeZone`.
- [x] Any live/current performance UI must compare real instants and display event local time.
- [x] Publish/edit forms must replace manual timezone selection with city search/selection.
- [x] Publish/edit forms must store selected IANA timezone from the city lookup result, not a fixed offset.

Relevant files to inspect during implementation:

- [event.ts](/Users/blackie/Projects/raver/web/src/lib/api/event.ts)
- [page.tsx](/Users/blackie/Projects/raver/web/src/app/events/[id]/page.tsx)
- [routine page.tsx](/Users/blackie/Projects/raver/web/src/app/events/[id]/routine/page.tsx)

## Implementation Phases

### Phase 1: Contract And Validation

- [x] Create this master implementation document.
- [x] Audit festival-viewer timetable parse/save/display behavior against this contract.
- [x] Audit BFF/backend timetable parse/save/rebase behavior against this contract.
- [x] Audit iOS timetable display/editor/live behavior against this contract.
- [x] Audit Web timetable display/live behavior against this contract.
- [x] Decide final behavior for one-song and invalid ranges.

### Phase 2: Backend Guardrails

- [x] Add `city-timezones` dependency in the backend/BFF package.
- [x] Add city timezone search endpoint backed by `lookupViaCity` / `findFromCityStateProvince`.
- [x] Add tests for ambiguous city lookup, no-result lookup, and exact city lookup.
- [x] Add DST utility tests for `parseEventDateInput` / `zonedTimeToUtc`.
- [x] Add cross-midnight tests for timetable normalization.
- [x] Add timezone-change rebasing tests.
- [x] Add start-date-change rebasing tests.
- [x] Add API validation for malformed timetable ranges.

### Phase 3: festival-viewer

- [x] Replace timezone select/manual entry with city timezone lookup UI.
- [x] Display selected city/province/country plus resolved `event.timeZone` as confirmation text.
- [x] Ensure structured timetable editor always works in `Day N + HH:mm-HH:mm`.
- [x] Add validation for invalid ranges before save.
- [x] Keep wall-clock timetable rows stable when timezone changes.
- [x] Rebase Day N timetable rows when start date changes.
- [x] Display event timezone near timetable/date surfaces.
- [x] Add targeted JS tests or smoke checks for timezone conversion.

### Phase 4: iOS

- [x] Replace timezone picker/manual identifier UI with city search/selection.
- [x] Use backend/BFF city timezone lookup results on iOS.
- [x] Ensure all timetable formatting uses `event.eventTimeZone`.
- [x] Ensure live discussion current-DJ detection uses instant comparison.
- [x] Ensure editor preserves wall-clock rows across timezone/start-date changes.
- [x] Add tests or debug assertions for event timezone different from device timezone.

### Phase 5: Web And Future Notifications

- [x] Replace Web publish/edit timezone input with city search/selection.
- [x] Use backend/BFF city timezone lookup results on Web.
- [x] Ensure Web event detail/routine pages use event timezone for timetable display.
- [x] Document notification/reminder trigger semantics as UTC instant based.
- [x] Add future reminder copy rule: event local time first, user local time optional.

## Acceptance Scenarios

- [x] Event in `Europe/Amsterdam`, device in `Asia/Shanghai`: Day 1 `17:00-18:00` displays as `17:00-18:00` in all event timetable UIs; covered by backend guardrail, festival-viewer smoke, Web formatting audit, and iOS DEBUG guardrail.
- [x] Event in `Europe/Amsterdam`, Day 1 `23:30-01:00`: stored end instant is next local calendar day and display remains `23:30-01:00`; covered by backend guardrail, festival-viewer smoke, and iOS DEBUG guardrail.
- [x] Event in `Europe/Amsterdam`, Day 1 `02:00-03:00` after a late-night program: grouped under Day 1 when `dayRolloverHour = 6`; covered by festival-viewer smoke and iOS/Web logical-day resolver audit.
- [x] Same event viewed on iOS in a different device timezone: timetable display remains event local time; covered by iOS `event.eventTimeZone` formatting audit and DEBUG guardrail.
- [x] Live room current DJ detection works when user's phone timezone differs from event timezone; covered by iOS `EventLiveSlotResolver` DEBUG guardrail using UTC instants.
- [x] Change event timezone: local timetable clock labels stay the same, UTC instants change; covered by backend guardrail, festival-viewer smoke, and iOS DEBUG guardrail.
- [x] Change event start date: Day N timetable rows move with the event; covered by backend guardrail and iOS/festival-viewer rebase implementations.
- [x] DST spring-forward nonexistent local time is rejected or handled by the documented rule; covered by backend guardrail.
- [x] DST fall-back ambiguous local time follows the documented rule; covered by backend guardrail.
- [x] Creating an event by searching `Chicago` stores `event.timeZone = America/Chicago` and displays Chicago/Illinois/United States as the selected timezone source; covered by shared city lookup flow and backend guardrail.
- [x] Searching an ambiguous city such as `Springfield` requires choosing the intended city/province/country before save; covered by shared city lookup flow and backend guardrail.
- [x] Web, festival-viewer, and iOS receive consistent city lookup results from the same backend/BFF resolver.

## Progress Log

- [x] 2026-05-21: Captured product rules and created the master implementation tracker.
- [x] 2026-05-21: Fixed festival-viewer backend slot mapping so UTC `startTime/endTime` are displayed and edited as event-local `HH:mm` values using `event.timeZone`; date fallback now also formats from the event timezone when `festivalDayIndex` is absent.
- [x] 2026-05-21: Added festival-viewer structured timetable validation: rows require DJ, Day N, and strict `HH:mm-HH:mm`; equal start/end and malformed clocks are rejected, while `end < start` remains the documented cross-midnight case.
- [x] 2026-05-21: Updated the plan for city-based timezone selection: users choose a city result resolved by `city-timezones`; IANA `event.timeZone` remains canonical, fixed offsets/manual timezone entry are removed, and DST remains handled by IANA-aware conversion utilities.
- [x] 2026-05-21: Added shared backend/BFF city-timezone lookup powered by `city-timezones`, proxied it through `web_tool`, and replaced festival-viewer add/edit timezone dropdowns with city search + explicit match confirmation that writes back canonical `event.timeZone`.
- [x] 2026-05-21: Added BFF request validation so event create/update rejects city-timezone metadata that does not match the submitted canonical `event.timeZone`, closing the loophole where a client could bypass the city-confirmation UI.
- [x] 2026-05-21: Added the same city-timezone search and validation flow to the direct `/api/events` route used by Web, then replaced Web publish/edit manual timezone input with a shared city-search picker; edit-page timetable times now rehydrate in `event.timeZone` rather than device local time.
- [x] 2026-05-21: Replaced iOS event editor manual timezone picker with shared BFF city-timezone search, added city-timezone metadata to create/update payloads, and rebased editor dates/timetable rows to preserve event-local wall time when the event timezone changes.
- [x] 2026-05-21: Audited iOS event detail and live discussion timetable paths; confirmed detail/routine slot formatting uses `event.eventTimeZone`, changed live active-performer detection to `start <= now < end`, and made the live discussion active window use the event timezone instead of the device calendar.
- [x] 2026-05-21: Audited and fixed Web event detail/routine timetable behavior: grouping now prefers canonical `festivalDayIndex`, fallback grouping uses `event.timeZone + dayRolloverHour`, timeline hour boundaries are aligned in the event timezone with DST-gap-safe ceil behavior, and route switch `datetime-local` values are parsed as event-local wall time rather than browser-local time.
- [x] 2026-05-21: Fixed festival-viewer save normalization so structured and imported timetable rows share the same `festivalDayIndex + Day N + HH:mm-HH:mm` internal shape; event timezone/start-date changes now rebuild UTC instants from wall-clock rows, and Day N after-midnight slots are placed on the correct real local date using `dayRolloverHour`.
- [x] 2026-05-21: Added backend timetable timezone guardrails and validation: `parseEventDateInput` now rejects DST spring-forward nonexistent local times and chooses the earlier DST fall-back occurrence; event/timetable API paths reject malformed, missing, or equal timetable ranges while preserving cross-midnight behavior; existing canonical slots now rebase timezone changes by reading wall-clock time in the previous event timezone and writing UTC in the new event timezone.
- [x] 2026-05-21: Added repeatable verification for the remaining non-iOS timezone path: backend guardrails now cover timezone-change wall-clock preservation and city lookup exact/ambiguous/no-result behavior, and festival-viewer has a Node smoke script that exercises Day 1 local wall time, cross-midnight slots, after-rollover slots, and timezone-change UTC recomputation against the real sync helper.
- [x] 2026-05-21: Completed iOS EventEditor timezone/timetable guardrails: changing event start date now rebases Day N rows while preserving local HH:mm and cross-midnight offset, equal start/end timetable ranges are rejected before save, and DEBUG assertions verify event-local wall-clock conversion is independent from the device timezone.
- [x] 2026-05-21: Completed iOS final guardrails: editor DEBUG assertions now cover Amsterdam cross-midnight and after-midnight Day 1 storage, live current-DJ detection is centralized in `EventLiveSlotResolver`, and the final acceptance checklist is tied back to repeatable guardrails/audits instead of implicit manual assumptions.
