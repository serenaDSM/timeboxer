import test from 'node:test';
import assert from 'node:assert/strict';

import { clientCanOpenRole, getInitialRole, normalizeClientMode } from '../src/clientMode.js';

test('normalizes unknown client modes to the combined development client', () => {
  assert.equal(normalizeClientMode('unknown'), 'combined');
  assert.equal(normalizeClientMode('child'), 'child');
});

test('child releases cannot be switched to the parent role with a URL', () => {
  assert.equal(getInitialRole({ clientMode: 'child', search: '?view=parent' }), 'child');
  assert.equal(clientCanOpenRole('child', 'parent'), false);
  assert.equal(clientCanOpenRole('child', 'child'), true);
});

test('parent releases always start behind the parent lock', () => {
  assert.equal(getInitialRole({ clientMode: 'parent', search: '?view=child' }), 'parent-locked');
  assert.equal(clientCanOpenRole('parent', 'child'), false);
});

test('combined development builds continue to respect the requested role', () => {
  assert.equal(getInitialRole({ clientMode: 'combined', search: '?view=parent' }), 'parent-locked');
  assert.equal(getInitialRole({ clientMode: 'combined', search: '?view=child' }), 'child');
});
