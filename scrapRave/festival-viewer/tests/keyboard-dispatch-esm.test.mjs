import test from 'node:test';
import assert from 'node:assert/strict';

import {
  CLOSE_PRIORITY,
  resolveAction,
  getOverlayStateFromElements,
} from '../js/esm/core/bootstrap/keyboard-dispatch.mjs';

test('ESM keyboard dispatch priority keeps source-replace above profile', () => {
  const state = {
    djSourceReplaceOpen: true,
    djProfileOpen: true,
  };
  const action = resolveAction('Escape', state);
  assert.deepEqual(action, { type: 'close', target: 'dj-source-replace' });
});

test('ESM keyboard dispatch resolves lightbox navigation', () => {
  assert.deepEqual(
    resolveAction('ArrowLeft', { lbOpen: true }),
    { type: 'lightbox-navigate', direction: -1 }
  );
  assert.deepEqual(
    resolveAction('ArrowRight', { lbOpen: true }),
    { type: 'lightbox-navigate', direction: 1 }
  );
  assert.equal(resolveAction('ArrowRight', { lbOpen: false }), null);
});

test('ESM keyboard dispatch uses fallback null when no state matched', () => {
  assert.equal(resolveAction('Escape', {}), null);
  assert.equal(resolveAction('x', { lbOpen: true }), null);
});

test('ESM getOverlayStateFromElements maps names to booleans', () => {
  const openSet = new Set(['djProfileOpen', 'lbOpen']);
  const state = getOverlayStateFromElements((name) => openSet.has(name));
  assert.equal(state.djProfileOpen, true);
  assert.equal(state.lbOpen, true);
  assert.equal(state.ttOpen, false);
  assert.equal(state.eventLineupOpen, false);
});

test('ESM close priority table remains stable for startup chain', () => {
  assert.equal(Array.isArray(CLOSE_PRIORITY), true);
  assert.equal(CLOSE_PRIORITY[0].target, 'dj-source-replace');
  assert.equal(CLOSE_PRIORITY[CLOSE_PRIORITY.length - 1].target, 'lightbox');
});
