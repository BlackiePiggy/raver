# Raver Flutter Android

This directory is the Android Flutter port workspace for the Raver iOS app.

Current status on 2026-04-19:

- The host macOS environment does not currently have `flutter` on `PATH`.
- The full technical route and implementation plan lives in `docs/RAVER_FLUTTER_ANDROID_TECHNICAL_PLAN.md`.
- The expanded documentation map lives in `docs/DOCUMENTATION_INDEX.md`.
- The iOS/Android parity tracker lives in `docs/IOS_ANDROID_PARITY_CHECKLIST.md`.
- `scripts/bootstrap_flutter_project.sh` creates the Flutter app after Flutter SDK and Android Studio are installed.

Recommended first local steps:

```bash
cd /Users/blackie/Projects/raver/mobile/flutter_raver_android
open docs/RAVER_FLUTTER_ANDROID_TECHNICAL_PLAN.md

# After installing Flutter SDK:
./scripts/bootstrap_flutter_project.sh
```

The generated app path will be:

```text
/Users/blackie/Projects/raver/mobile/flutter_raver_android/app/raver_android
```
