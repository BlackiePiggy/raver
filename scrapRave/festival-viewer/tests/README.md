# Festival Viewer Tests

## Run

```bash
cd /Users/blackie/Projects/raver/scrapRave/festival-viewer
node --test tests/helpers-core-utils.test.js tests/helpers-core-utils-esm.test.mjs tests/keyboard-dispatch-esm.test.mjs tests/keyboard-actions-esm.test.mjs tests/helpers-lineup-sync-payload.test.js tests/helpers-lineup-sync-payload-esm.test.mjs tests/helpers-import-translate-text-plan-esm.test.mjs tests/helpers-import-runtime-transform-esm.test.mjs
```

## Current Scope

- `tests/helpers-core-utils.test.js`
  - Covers pure helper functions in `js/core/helpers/00-festival-core-utils.js`.
- `tests/helpers-core-utils-esm.test.mjs`
  - Covers ESM pilot helper module in `js/esm/core/helpers/festival-core-utils.mjs`.
- `tests/keyboard-dispatch-esm.test.mjs`
  - Covers startup-chain keyboard dispatch ESM pilot in `js/esm/core/bootstrap/keyboard-dispatch.mjs`.
- `tests/helpers-lineup-sync-payload.test.js`
  - Covers payload/date helper chain in `js/core/helpers/20-lineup-sync-and-payload.js`.
- `tests/helpers-lineup-sync-payload-esm.test.mjs`
  - Covers ESM payload/date helper pilot in `js/esm/core/helpers/lineup-sync-payload-utils.mjs`.
- `tests/helpers-import-translate-text-plan-esm.test.mjs`
  - Covers ESM import translate text-plan pilot in `js/esm/features/import/translate/text-plan-utils.mjs`.
- `tests/keyboard-actions-esm.test.mjs`
  - Covers ESM startup-chain keyboard action applier in `js/esm/core/bootstrap/keyboard-actions.mjs`.
- `tests/helpers-import-runtime-transform-esm.test.mjs`
  - Covers ESM import runtime transform mapper pilot in `js/esm/features/import/runtime/transform-mapper-utils.mjs`.
