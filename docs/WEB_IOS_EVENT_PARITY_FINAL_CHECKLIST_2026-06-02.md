# Web / iOS Event Final Parity Checklist

Date: 2026-06-02

Scope:
- `web/src/features/admin-content/event-studio/*`
- `web/src/components/admin/EventStudioForm.tsx`
- `mobile/ios/RaverMVP/RaverMVP/Features/Discover/Events/UploadFlow/*`
- `server/src/controllers/event.controller.ts`
- `server/src/services/content-submission-event.service.ts`
- `server/src/services/event-admin-contract-guardrail.service.ts`
- `server/src/routes/bff.web.routes.ts`
- `contracts/openapi/event-admin.v1.yaml`
- `contracts/generated/web/event-admin.ts`

## 0. Canonical Principles

- Event create and edit must use one canonical mutation model across web and iOS.
- Event date, time, `eventDays`, `weeks`, and timetable slots must always be interpreted in the event's local timezone, never the device timezone.
- The write payload must carry canonical business facts only.
- AI import hints, parser intermediates, UI-only state, and provider-specific draft helpers must never leak into canonical event write payloads unless they are part of the formal contract.
- Update semantics must be full-state plus explicit destructive clear flags, not ad hoc partial patching.
- Server normalization is the final source of truth, but both clients must converge on the same intent before the request leaves the device/browser.

## 1. Contract And Payload Canonicalization

- [x] Promote `locationPoint.providerMeta` and `locationPoint.adcode` into the canonical event admin write contract
  - Best solution: add both fields to `EventLocationPoint` in the OpenAPI source contract, regenerate TypeScript and Swift client models, and remove all client-side "contract drift" casts or shadow extensions.
  - Why this is the best solution: the server already normalizes and preserves these fields, so deleting them would lose real location provenance and search-quality metadata.
  - Acceptance:
    - `contracts/openapi/event-admin.v1.yaml` formally declares `providerMeta` and `adcode`
    - regenerated `contracts/generated/web/event-admin.ts` includes them
    - iOS and web can both send and hydrate them without local type hacks

- [x] Establish one canonical `locationPoint.provider` vocabulary and one canonical `sourceMode` taxonomy
  - Best solution: define a closed enum set in the contract, such as `amap`, `apple-mapkit`, `google`, `mapbox`, `geoapify`, and a closed source mode set such as `manual_search`, `picker_search`, `picker_map_tap`, `server_normalized`.
  - Why this is the best solution: free-form strings make parity impossible and create permanent normalization debt in BFF and analytics.
  - Acceptance:
    - contract exposes enums, not plain free-form strings
    - web picker and iOS picker both map to the same values
    - server normalization becomes compatibility-only, not business-as-usual

- [x] Unify `locationPoint` emission rules across web and iOS
  - Best solution: define one shared rule set:
    - send `manualLocation` when the user has meaningful human-readable address text
    - send `locationPoint` only when the client has real POI/provenance data
    - send top-level `latitude` and `longitude` whenever the event has a resolved coordinate
    - never fabricate provider or source metadata
    - preserve hydrated real `locationPoint` provenance on edit only until the user remaps or manually changes coordinates; once remapped without provider metadata, downgrade to `manualLocation + latitude/longitude`
  - Why this is the best solution: it cleanly separates display address, map provenance, and geographic coordinate concerns.
  - Acceptance:
    - web and iOS both follow the same decision table
    - no client sends fake provider defaults
    - edit hydrate and resubmit preserves true location provenance

- [x] Remove `venueName` / `venueAddress` from cross-platform event write semantics and keep only `sourceProvider` / `referenceLinks` as first-class metadata
  - Best solution: both web and iOS align to the canonical address model:
    - no top-level `venueName`
    - no top-level `venueAddress`
    - `manualLocation` carries activity address truth
    - `locationPoint` carries map provenance and venue display truth
  - Why this is the best solution: keeping legacy top-level venue fields would permanently split write semantics between clients and server.
  - Acceptance:
    - iOS draft model does not depend on legacy `venueName` / `venueAddress`
    - iOS create/update payloads do not emit legacy top-level venue fields
    - `sourceProvider` / `referenceLinks` continue to round-trip as event metadata

- [x] Add iOS write support for canonical `socialLinks`
  - Best solution: map `socialLinks` as true arbitrary JSON through the generated EventAdmin Swift contract using the generator's canonical JSON container type, not a lossy string shim and not a second shadow schema.
  - Why this is the best solution: `socialLinks` is contract-level structured data, so iOS should preserve object/array shape exactly instead of flattening it into ad hoc text or dropping it on submit.
  - Current status:
    - iOS now hydrates `socialLinks` into local draft/edit text
    - iOS create/update payload mapping now parses `socialLinksText` into the Swift OpenAPI generator's arbitrary JSON value type
    - update clear semantics are formalized with `clearSocialLinks`
  - Acceptance:
    - iOS draft edit/create surfaces round-trip `socialLinks`
    - iOS create/update payloads emit canonical JSON, not escaped JSON strings
    - parity tests cover object, array, and null cases

- [x] Unify lineup slot time encoding format
  - Best solution: define one canonical write format for `lineupSlots[].startTime` and `endTime`.
  - Recommended canonical choice: event-local logical datetime string without zone, paired with `eventDayId` and the event timezone.
  - Why this is the best solution: slot editing is driven by the event's wall-clock schedule, not absolute device time; local event datetime is the clearest authoring representation.
  - Acceptance:
    - contract documentation explicitly defines slot time format
    - web and iOS both emit the same format
    - server remains backward compatible temporarily, then old alternate formats are deprecated

- [x] Unify lineup slot default stage fallback policy
  - Best solution: formalize one shared fallback rule.
  - Recommended canonical rule: if the slot has no explicit `stageName`, fallback to the first explicit `stageOrder` entry, otherwise `Main Stage`; never generate unstable `Stage 2` / `Stage 3` labels from slot array position alone.
  - Why this is the best solution: deterministic fallback is required for edit round-trip stability and diff readability.
  - Acceptance:
    - web and iOS use the same helper rule
    - create, edit, hydrate, and resubmit all preserve the same fallback result

- [x] Explicitly separate canonical event write fields from AI/import-only fields
  - Best solution: create a strict contract boundary:
    - canonical event write payload contains business facts only
    - AI parsing fields such as `performerType`, parser confidence, raw text, unresolved notes, and provider troubleshooting state live in separate import-preview or draft-only models
  - Why this is the best solution: canonical event storage should not depend on parser scaffolding or UI intermediates.
  - Acceptance:
    - `performerType` stays out of `lineupSlots` write contract unless the server intentionally promotes it to a first-class canonical field
    - AI-only fields live in dedicated preview/import contracts

- [x] Freeze clear-flag policy as a formal invariant, not an implementation detail
  - Best solution: document and enforce one policy:
    - `clearWikiFestivalId`, `clearManualLocation`, `clearLocationPoint`, `clearLatitude`, `clearLongitude`, `clearSocialLinks`, `clearStageOrder`, and `clearLineupSlots` remain explicit destructive flags
    - `clearCityI18n` and `clearCountryI18n` may only be set by explicit user intent, never by blank form state
  - Why this is the best solution: destructive update semantics must be intentional and cross-platform identical.
  - Current status:
    - contract now requires every clear flag on update and documents field-or-clear semantics for destructive fields
    - server guardrail now rejects update payloads that omit `socialLinks` while `clearSocialLinks` is false
    - web parity tests now lock `clearSocialLinks + socialLinks: null` explicit-clear behavior
    - iOS upload validation now blocks invalid `socialLinks` JSON before submit
  - Acceptance:
    - contract docs call this out explicitly
    - web and iOS tests cover destructive and non-destructive update cases
    - UI only emits i18n clear flags from explicit remove actions

- [x] Canonicalize identity rules for `weeks`, `eventDays`, and `ticketTiers`
  - Best solution:
    - `weeks` are keyed by `weekIndex`
    - `eventDays` are keyed by `eventDayId`
    - `ticketTiers` either gain stable IDs as a true update key, or the contract explicitly declares them replace-all semantics
  - Why this is the best solution: mixed hidden identity rules create silent divergence between clients and server sync logic.
  - Current status:
    - contract now states that `EventWeek.id` and `EventDay.id` are hydration-only and ignored on write
    - contract now states that `weekIndex` and `eventDayId` are the canonical write/update identity keys
    - contract now states that `ticketTiers` are replace-all on create/update and tier `id` is ignored on write
  - Acceptance:
    - contract docs define which fields are true stable identities
    - client mappers match those rules exactly
    - server update logic and contract docs stop implying unsupported stable IDs

## 2. Shared Domain Spec And Conformance

- [x] Create one canonical "Event Mutation Spec" document that is authoritative for web, iOS, server, and BFF
  - Best solution: add a single spec document under `docs/` that defines every field's authoring semantics, clear semantics, timezone semantics, and canonical examples.
  - Why this is the best solution: parity work fails when the contract exists but the authoring semantics live only in code and memory.
  - Acceptance:
    - spec covers create, edit, hydrate, clear, timezone, cross-midnight, location, and lineup slot semantics
    - web, iOS, and server teams all treat this as the source of truth

- [x] Generate golden payload fixtures from server-validated canonical examples
  - Best solution: create a fixture set for representative event cases and validate them through server normalization.
  - Suggested fixture families:
    - single-day event
    - multi-day event
    - multi-week event
    - cross-midnight slot event
    - event with POI-backed location
    - event with manual address only
    - direct create and review-submission variants
  - Acceptance:
    - fixtures live in version control
    - both clients can be tested against them

- [x] Add web conformance tests against golden fixtures
  - Best solution: test the mapper output structurally and semantically against the canonical fixture family.
  - Acceptance:
    - web mapper parity tests cover every fixture
    - regressions fail before shipping

- [x] Add iOS conformance tests against the same golden fixtures
  - Best solution: use the same fixture corpus and assert generated Swift payloads match canonical payload intent exactly.
  - Acceptance:
    - iOS mapper tests cover the same fixtures as web
    - parity is enforced in CI, not by manual audit

## 3. Web Workflow Shell Parity

- [ ] Implement durable draft lifecycle parity for web create and edit
  - Best solution:
    - create drafts are keyed by draft ID
    - edit drafts are keyed by event ID plus base revision
    - draft storage preserves step state, media state, unresolved AI issues, and last submission outcome
  - Why this is the best solution: payload parity alone is not enough if web cannot recover or resume like iOS.
  - Acceptance:
    - browser refresh, accidental close, and revisit can resume safely
    - create and edit drafts do not overwrite each other

- [ ] Add autosave and resume semantics equivalent to iOS draft continuity
  - Best solution: web autosaves normalized draft snapshots on meaningful state changes, throttled and revision-tagged.
  - Acceptance:
    - autosave status is visible
    - stale autosave is detected
    - resume prompt is deterministic

- [ ] Add unsaved-changes and exit-recovery protection
  - Best solution: web must guard in-app navigation, browser close, and route transitions with the same business-grade protection the iOS flow implicitly gives through draft persistence.
  - Acceptance:
    - losing unsaved work becomes hard
    - resume behavior is predictable after interruption

- [ ] Add exact submission outcome parity for create and edit
  - Best solution: treat `created` and `submitted for review` as two distinct outcome states with distinct UI, navigation, and follow-up actions.
  - Acceptance:
    - no ambiguous "saved successfully" state
    - web mirrors the real backend outcome class

- [ ] Add submission failure and retry recovery model
  - Best solution: failed submit keeps the exact draft, media ownership state, and last attempted payload fingerprint so the user can retry safely.
  - Acceptance:
    - failed submits are recoverable without rebuilding the event by hand
    - media ownership does not drift after retry

- [ ] Add stale revision conflict flow for edit
  - Best solution: web edit drafts must carry base revision and present a structured reload / compare / overwrite decision when the server revision has advanced.
  - Acceptance:
    - conflict state is explicit
    - user can inspect differences before choosing
    - no silent overwrite

## 4. Media Lifecycle Parity

- [ ] Formalize one cross-platform image ownership state model
  - Best solution: define one canonical media ownership lifecycle across web and iOS:
    - local pending
    - uploaded for create draft
    - uploaded for edit draft
    - attached to content submission
    - attached to persisted event
    - marked deleted
  - Why this is the best solution: media bugs come from ownership ambiguity more than from upload transport.
  - Acceptance:
    - both clients model the same lifecycle
    - server-side ownership transfer points are documented

- [ ] Add full media lifecycle parity tests
  - Best solution: create end-to-end tests for upload, replace, remove, submit, approve, update, and purge.
  - Acceptance:
    - removed cover/lineup/imageAssets are diffed and marked deleted correctly
    - retried submissions do not orphan assets

## 5. AI Import And Timetable Editing Parity

- [ ] Introduce structured unresolved-issues workflow for AI import
  - Best solution: imported data must carry explicit unresolved issue buckets such as missing timezone, ambiguous city, missing performer binding, ambiguous stage, or invalid slot date.
  - Acceptance:
    - imported drafts never silently collapse ambiguities into canonical payload
    - unresolved issues are visible and actionable before submit

- [ ] Define deterministic import apply policy
  - Best solution: every import field must declare one of:
    - auto-apply
    - suggest-only
    - replace-if-empty
    - require-user-confirmation
  - Why this is the best solution: parity is impossible if import application strategy differs by client intuition.
  - Acceptance:
    - web and iOS both follow the same apply table
    - import side effects are testable

- [ ] Preserve import provenance outside canonical event write payload
  - Best solution: parser raw text, confidence, original poster OCR fragments, and recovery notes should live in draft/import state or review telemetry, not in canonical event fields.
  - Acceptance:
    - canonical event write payload stays clean
    - import debugging data remains available when needed

## 6. Validation And Error Mapping

- [ ] Unify validation vocabulary and field-level rules across web and iOS
  - Best solution: define one validation matrix for required fields, formatting rules, timezone consistency, location consistency, schedule consistency, lineup consistency, and media minimums.
  - Acceptance:
    - same invalid input produces the same user-facing result on both clients
    - no platform-specific silent coercion for business-critical fields

- [ ] Unify error code taxonomy and field mapping
  - Best solution: add a shared mapper from server/BFF error codes to domain-level UI states such as active submission conflict, stale revision, invalid timezone selection, invalid slot mapping, or media ownership failure.
  - Acceptance:
    - web and iOS surface equivalent meaning for the same backend error
    - retryable vs blocking errors are classified the same way

## 7. QA And Release Gate

- [ ] Build one shared parity test matrix and make it a release gate
  - Best solution: no event flow release on either platform ships without passing the same matrix.
  - Minimum matrix:
    - direct create
    - create submitted for review
    - direct edit
    - edit submitted for review
    - single-day
    - multi-day
    - multi-week
    - cross-midnight timetable
    - manual address only
    - POI-backed location with provider metadata
    - destructive clear cases
    - stale revision conflict case
    - failed submit and retry case
  - Acceptance:
    - matrix lives in version control
    - web and iOS runs are both recorded against the same checklist

- [ ] Add production payload diff observability
  - Best solution: log normalized payload signatures for web and iOS submissions in a privacy-safe way so parity drift is detectable from real traffic.
  - Acceptance:
    - platform-specific field drift can be queried
    - parity regressions are detected before users report them

## 8. Recommended Execution Order

- [ ] Phase 1: contract and payload canonicalization
- [ ] Phase 2: shared fixtures and mapper conformance tests
- [ ] Phase 3: web draft lifecycle, autosave, resume, and stale-revision shell
- [ ] Phase 4: media lifecycle parity tests and ownership formalization
- [ ] Phase 5: AI import unresolved-issues workflow and deterministic apply policy
- [ ] Phase 6: unified QA matrix and release gate

## 9. Definition Of Done

- [ ] Web and iOS can both create and edit the same event without semantic payload drift
- [ ] Event-local timezone semantics are identical across both clients
- [ ] Location authoring semantics are identical across both clients
- [ ] Lineup and timetable semantics are identical across both clients
- [ ] Draft recovery and submit-retry behavior are equally reliable on both clients
- [ ] Media lifecycle is deterministic and leak-free on both clients
- [ ] Shared conformance tests and QA matrix prevent future drift
