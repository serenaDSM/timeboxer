import test from 'node:test';
import assert from 'node:assert/strict';
import { isSecureParentPIN } from '../src/parentPIN.js';

test('rejects a missing or known default parent PIN', () => {
  assert.equal(isSecureParentPIN(''), false);
  assert.equal(isSecureParentPIN('1234'), false);
});

test('accepts only a private four-to-eight digit parent PIN', () => {
  assert.equal(isSecureParentPIN('2468'), true);
  assert.equal(isSecureParentPIN('135790'), true);
  assert.equal(isSecureParentPIN('12'), false);
  assert.equal(isSecureParentPIN('abcd'), false);
  assert.equal(isSecureParentPIN('123456789'), false);
});
