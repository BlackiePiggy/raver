# iOS Event / DJ Upload Permission & Review Alignment

## Goal

Align the iOS DJ upload/edit flow with the existing iOS event upload/edit model, especially around:

- who can enter create/edit flows
- how admin-capable users are represented
- what happens before upload/submit
- how review / direct-publish results are surfaced
- how draft restore / discard / success states behave

This document reflects the current codebase state and is intended to be the source of truth for the next DJ-side alignment passes.

## Event Side: Current Model

### 1. Create / edit result model

Event upload supports two result branches for both create and edit:

- direct success
- `submittedForReview`

References:

- [WebFeatureService.swift](/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Core/WebFeatureService.swift:20)
- [WebFeatureService.swift](/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Core/WebFeatureService.swift:21)
- [WebFeatureModels.swift](/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Core/WebFeatureModels.swift:943)
- [WebFeatureModels.swift](/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Core/WebFeatureModels.swift:969)

`EventUploadFlowViewModel` explicitly handles all four cases:

- create -> created
- create -> submittedForReview
- edit -> created
- edit -> submittedForReview

Reference:

- [EventUploadFlowViewModel.swift](/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Discover/Events/UploadFlow/EventUploadFlowViewModel.swift:249)

### 2. Pre-submit and pre-image-upload user action gate

Event upload calls `prepareAuthenticatedRequestForUserAction(...)` before:

- final submit
- image upload

References:

- [EventUploadFlowViewModel.swift](/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Discover/Events/UploadFlow/EventUploadFlowViewModel.swift:249)
- [EventUploadFlowViewModel.swift](/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Discover/Events/UploadFlow/EventUploadFlowViewModel.swift:2092)

Important note:

- This is not an explicit iOS-side admin permission system.
- It is a shared authenticated-action gate, mainly ensuring session freshness before a user action.

Implementation reference:

- [LiveWebFeatureService.swift](/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Core/LiveWebFeatureService.swift:61)

### 3. Draft lifecycle is fully modeled

Event upload has a complete draft lifecycle:

- restore previous draft on open
- ask whether to continue or restart
- save on background / disappear
- explicit exit confirmation
- save draft and leave
- discard draft and clean owned uploaded media
- success page replaces editor content instead of dismissing immediately

References:

- [EventUploadFlowView.swift](/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Discover/Events/UploadFlow/EventUploadFlowView.swift:138)
- [EventUploadFlowView.swift](/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Discover/Events/UploadFlow/EventUploadFlowView.swift:199)
- [EventUploadFlowView.swift](/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Discover/Events/UploadFlow/EventUploadFlowView.swift:276)
- [EventUploadFlowViewModel.swift](/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Discover/Events/UploadFlow/EventUploadFlowViewModel.swift:159)
- [EventUploadFlowViewModel.swift](/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Discover/Events/UploadFlow/EventUploadFlowViewModel.swift:164)
- [EventUploadFlowViewModel.swift](/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Discover/Events/UploadFlow/EventUploadFlowViewModel.swift:184)

### 4. Edit entry is not using a generic `canEdit`

The event detail share panel currently shows Edit only when `isMine(event)` is true:

- `isMine(event)` means `event.organizer?.id == appState.session?.user.id`

References:

- [EventDetailView.swift](/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Discover/Events/Views/EventDetailView.swift:2479)
- [EventDetailView.swift](/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Discover/Events/Views/EventDetailView.swift:4684)

This means:

- event detail page edit entry is owner-based
- it is not currently driven by `event.canEdit`
- admin edit access, if any, is likely represented elsewhere in navigation or backend routes rather than this specific quick action

### 5. Edit route loads latest entity before entering editor

Event edit flow uses a loader view to fetch the latest event before opening the upload/edit flow.

Reference:

- [MainTabCoordinator.swift](/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Application/Coordinator/MainTabCoordinator.swift:1895)

This matters because:

- latest permission flags are respected
- latest content / moderation state is used
- stale detail-page snapshots are avoided

## DJ Side: Current Model After Recent Alignment

### 1. Upload flow behavior now matches event much more closely

DJ upload now has:

- restore-draft confirmation
- save / discard exit confirmation
- success page instead of immediate dismiss
- pre-image-upload authenticated action gate
- pre-submit authenticated action gate

References:

- [DJUploadFlowView.swift](/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Discover/DJs/UploadFlow/DJUploadFlowView.swift:43)
- [DJUploadFlowView.swift](/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Discover/DJs/UploadFlow/DJUploadFlowView.swift:509)
- [DJUploadFlowViewModel.swift](/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Discover/DJs/UploadFlow/DJUploadFlowViewModel.swift:142)
- [DJUploadFlowViewModel.swift](/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Discover/DJs/UploadFlow/DJUploadFlowViewModel.swift:200)

### 2. Create path supports review result, edit path still does not

Current DJ service contracts are asymmetric:

- create manual DJ -> `ImportDJResult<...>` so it can be direct import or review
- update DJ -> `WebDJ` only, so iOS currently cannot model `submittedForReview` on edit

References:

- [WebFeatureService.swift](/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Core/WebFeatureService.swift:83)
- [WebFeatureService.swift](/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Core/WebFeatureService.swift:84)
- [LiveWebFeatureService.swift](/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Core/LiveWebFeatureService.swift:720)
- [LiveWebFeatureService.swift](/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Core/LiveWebFeatureService.swift:735)

Implication:

- DJ create can fully mirror event create
- DJ edit cannot fully mirror event edit until backend / contract changes to return a review-aware result type

### 3. DJ detail edit entry now uses an effective editability rule

Unlike event detail's strict owner check, DJ detail now exposes Edit using a shared effective editability rule:

- `dj.canEdit == true`
- or `dj.isContributor == true`
- or `uploadedByUsername` matches the current user
- or `contributorUsernames` contains the current user

Reference:

- [DJsModuleView.swift](/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Discover/DJs/Views/DJsModuleView.swift:3252)

Implication:

- DJ remains flexible for backend-granted editor/admin access
- contributor / uploader access is preserved even if one snapshot flag is stale
- event detail is still stricter and owner-based

### 4. DJ edit route fetches latest entity first and re-checks editability

To move closer to the event pattern, DJ edit entry now routes through a loader that:

- fetches the latest DJ
- re-applies the same effective editability rule
- blocks entry with a clear error state if the latest DJ is no longer editable

Reference:

- [DJsModuleView.swift](/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Discover/DJs/Views/DJsModuleView.swift:1925)
- [DJsModuleView.swift](/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Features/Discover/DJs/Views/DJsModuleView.swift:3532)

This reduces mismatch caused by:

- stale `canEdit`
- stale contributor / uploader access
- stale moderation state
- stale profile fields in the edit seed object

## Admin Semantics: What The Code Actually Says Today

### Frontend does not have a universal content-admin switch

There is no shared iOS-side `isAdminForContent` flag for event / DJ upload flows.

What exists instead:

- entity-level editability fields like `canEdit`
- owner-specific checks in some UI surfaces
- shared authenticated-action gate before user actions
- separate content review / moderation inbox flows

References:

- [WebFeatureModels.swift](/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Core/WebFeatureModels.swift:1227)
- [MainTabCoordinator.swift](/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Application/Coordinator/MainTabCoordinator.swift:139)
- [LiveSocialService.swift](/Users/blackie/Projects/raver/mobile/ios/RaverMVP/RaverMVP/Core/LiveSocialService.swift:1210)

### Practical interpretation

For event / DJ content editing, “admin can do the same” currently means:

- backend may expose edit access through entity data or routing context
- frontend should avoid hardcoding narrower checks when a generic editable flag exists
- frontend can supplement that generic flag with uploader / contributor identity checks when the DJ model already provides them
- edit flows should fetch latest entity before entering editor
- submit and image upload should always pass through the same authenticated-action gate

## Recommended Alignment Rules For DJ

### Rule 1

Keep DJ upload / edit flow behavior aligned with event flow:

- draft restore
- exit confirmation
- background autosave
- success page
- authenticated-action gates

Status:

- already aligned

### Rule 2

Use latest-entity loader before opening DJ edit flow.

Status:

- now aligned

### Rule 3

Do not introduce a local hardcoded admin branch inside DJ upload flow.

Reason:

- event flow does not have one either
- content editability should stay backend-driven or route-driven

### Rule 4

Keep DJ detail edit entry backend-editable aware for now.

Reason:

- event detail currently uses owner-only `isMine(event)`
- DJ already uses `dj.canEdit`
- switching DJ down to owner-only would likely regress legitimate backend-granted editor/admin access

### Rule 5

If product wants true parity, event detail entry should eventually be revisited too.

Specifically:

- either event should move toward `canEdit`
- or both event and DJ should move toward an explicit shared “editable-by-current-user” abstraction

Until that larger change happens, the safe DJ-side direction is:

- preserve `dj.canEdit`
- align everything else around it

## Remaining DJ Gaps

### Gap 1

DJ edit API did not originally return a review-aware result.

Needed to fully match event edit:

- `updateDJ(...)` should return a result like `CreateContentResult<WebDJ>` or a DJ-specific equivalent

Current iOS status:

- the iOS client contract has now been upgraded to consume `CreateContentResult<WebDJ>`
- this is backward-compatible with direct `WebDJ` payloads because `CreateContentResult` already decodes created payloads first
- once backend starts returning `submittedForReview`, DJ edit flow can surface the same two success branches as event without another client-side flow rewrite

### Gap 2

There is no documented shared abstraction for content editor/admin eligibility across event and DJ detail surfaces.

Needed long-term:

- one content-editability policy used by both modules

### Gap 3

DJ entry and event entry still differ at detail level:

- event detail -> owner check
- DJ detail -> `canEdit`

This is a product / platform decision point, not just a styling issue.

## Suggested Next Steps

1. Keep DJ detail using `canEdit` for now, because it is more compatible with admin/editor access than owner-only gating.
2. If backend can support it, change `updateDJ` response to a review-aware result type.
3. After that API change, update DJ edit success handling to mirror event edit exactly:
   - updated directly
   - edit submitted for review
4. Separately evaluate whether event detail should be migrated from `isMine(event)` to a shared editable policy.

## Progress Checklist

- [x] DJ upload/edit page structure and step flow aligned closer to event on iOS
- [x] DJ bottom action bar and previous/next navigation styling aligned closer to event
- [x] DJ localized fields moved toward event-style expandable sections
- [x] DJ aliases / genres use add-item interaction instead of comma-separated user input
- [x] DJ upload flow supports tap-blank-space keyboard dismissal across the full flow
- [x] DJ upload flow uses event-like draft restore / save / discard / success lifecycle
- [x] DJ upload flow uses the same authenticated-action gate pattern before image upload and submit
- [x] DJ detail edit entry now re-checks latest entity before entering editor
- [x] DJ effective editability now stays compatible with contributor / uploader / admin-style access
- [x] DJ edit submit on iOS now supports review-aware result handling
- [x] Server DJ edit route now submits a review task instead of directly mutating the DJ
- [x] Server review approval path now supports applying DJ edit submissions onto an existing DJ
- [x] Event/DJ edit submissions now attach change summaries through the BFF shared submission path
- [x] DJ edit submissions now generate readable field-level change summaries for My Posts / submission detail / notifications
- [x] My Posts / submission detail now exposes DJ submissions and uses clearer create/edit task wording
- [x] Added a regression script for DJ edit submission create-review-approve flow
