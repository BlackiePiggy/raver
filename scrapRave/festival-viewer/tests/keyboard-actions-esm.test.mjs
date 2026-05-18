import test from 'node:test';
import assert from 'node:assert/strict';

import {
  normalizeLightboxDirection,
  applyResolvedAction,
} from '../js/esm/core/bootstrap/keyboard-actions.mjs';

test('ESM keyboard actions normalize lightbox direction', () => {
  assert.equal(normalizeLightboxDirection(-3), -1);
  assert.equal(normalizeLightboxDirection(9), 1);
  assert.equal(normalizeLightboxDirection(0), null);
  assert.equal(normalizeLightboxDirection('x'), null);
});

test('ESM keyboard actions apply close action with fallback bridge', () => {
  const calls = [];
  const ok = applyResolvedAction(
    { type: 'close', target: 'news-editor' },
    {
      requestClose(target, fallback) {
        calls.push(['requestClose', target]);
        fallback();
      },
      fallbackCloseByTarget(target) {
        calls.push(['fallback', target]);
      },
    }
  );
  assert.equal(ok, true);
  assert.deepEqual(calls, [['requestClose', 'news-editor'], ['fallback', 'news-editor']]);
});

test('ESM keyboard actions apply lightbox navigate action', () => {
  const calls = [];
  const ok = applyResolvedAction(
    { type: 'lightbox-navigate', direction: -9 },
    {
      requestLightboxNavigate(direction) {
        calls.push(direction);
      },
    }
  );
  assert.equal(ok, true);
  assert.deepEqual(calls, [-1]);
});

test('ESM keyboard actions reject invalid payload or missing adapters', () => {
  assert.equal(applyResolvedAction(null, {}), false);
  assert.equal(applyResolvedAction({ type: 'close', target: 'x' }, {}), false);
  assert.equal(applyResolvedAction({ type: 'lightbox-navigate', direction: 0 }, {
    requestLightboxNavigate() {},
  }), false);
});
