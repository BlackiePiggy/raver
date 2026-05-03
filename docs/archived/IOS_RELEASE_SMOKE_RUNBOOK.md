# iOS Release Smoke Runbook

This checklist is the minimum release gate for the migrated MVVM+Coordinator architecture.

## Scope

- App: `mobile/ios/RaverMVP/RaverMVP`
- Goal: catch route wiring regressions, DI boundary regressions, and high-traffic flow breakages before release.

## 1) Automated Gate (must pass)

Run from repository root:

```bash
scripts/run-coordinator-hardening-preflight.sh
```

Expected result:

- `[PASS] Feature layer has no AppEnvironment service factory calls.`
- `[PASS] No AppState service-locator usage found.`
- `[PASS] AppEnvironment factory usage is limited to allowed bootstrap files.`
- `[PASS] Modal allowlist matches current sheet/fullScreenCover usage.`
- `All coordinator routing regression checks passed.`
- `All coordinator deep-link regression checks passed.`
- `All coordinator route snapshot checks passed.`

## 2) Build Gate (must pass)

Run from repository root:

```bash
xcodebuild -project mobile/ios/RaverMVP/RaverMVP.xcodeproj -scheme RaverMVP -destination 'platform=iOS Simulator,name=iPhone 17' build
```

Expected result:

- `** BUILD SUCCEEDED **`

If local simulator names differ, pick an available simulator from:

```bash
xcodebuild -project mobile/ios/RaverMVP/RaverMVP.xcodeproj -showdestinations -scheme RaverMVP
```

## 3) Manual Smoke (core user paths)

Use a signed-in test account with normal social permissions.

1. Feed
- Open feed list.
- Create a post (text only).
- Edit and save the same post.

2. Search and Notifications to SquadProfile
- In Search, open one squad profile.
- In Notifications, open one squad profile.

3. SquadProfile manage flow
- In squad profile, open manage sheet.
- Update squad info and save.
- If possible, verify avatar/flag upload path once.

4. Circle rating path
- Open Circle rating hub.
- Create one rating event.
- Import one rating event from event.
- Open event detail and create one rating unit.
- Open unit detail and submit one rating comment.

## 4) Pass/Fail Rule

- Pass when automated gate + build gate + all manual smoke items pass.
- Fail when any item fails. Record failure with:
  - app section (Feed/Search/Notifications/Squad/Circle),
  - user action,
  - observed result,
  - expected result,
  - screenshot/video if available.

## 5) Ownership

- Driver: iOS feature owner of current release branch.
- Reviewer: second engineer validates at least one non-happy-path interaction in section 3.

## 6) CI and Branch Protection Recommendation

- Workflow file: `.github/workflows/mvvm-coordinator-guard.yml`
- Required status check (recommended): `Architecture Boundary Guard`
- Optional status check for manual hardening runs: `Optional iOS Simulator Build`

Recommended repository settings:

1. In branch protection for `main` (and `master` if still used), require status check `Architecture Boundary Guard`.
2. Keep `Optional iOS Simulator Build` as non-required and trigger it manually (`workflow_dispatch`) for release candidates or risky refactors.

## 7) Contributor PR Preflight (Required for Route Changes)

When you change any coordinator route enum or destination switch in:

- `Features/Discover/Coordinator/DiscoverRoute.swift`
- `Features/Circle/Coordinator/CircleCoordinator.swift`
- `Features/Messages/Coordinator/MessagesCoordinator.swift`
- `Features/Profile/Coordinator/ProfileCoordinator.swift`

do this before opening a PR:

1. Update route snapshot fixture if route cases changed:
- File: `scripts/fixtures/coordinator-route-snapshots.sh`
- Rule: keep case names sorted alphabetically in each `SNAPSHOT_*` value.

2. Run full guard preflight from repository root:

```bash
scripts/run-coordinator-hardening-preflight.sh
```

3. If the snapshot guard fails:
- Confirm the route case change is intentional.
- Update fixture values in `scripts/fixtures/coordinator-route-snapshots.sh`.
- Re-run preflight until all checks pass.

4. If modal allowlist guard fails:
- Confirm new `sheet/fullScreenCover` usage is product-intentional.
- Update `scripts/modal-allowlist-signatures.txt` using:
  `scripts/check-modal-allowlist.sh --write-allowlist`
- Update `docs/MVVM_COORDINATOR_MIGRATION_PLAN.md` (`P9.4 modal allowlist`) with rationale for the new modal.
