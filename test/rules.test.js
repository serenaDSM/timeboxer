import test from 'node:test';
import assert from 'node:assert/strict';
import {
  getPlayedMinutes,
  getPlayedMinutesForCountdown,
  getProratedSpendCost,
  validateTaskInput,
} from '../src/rules.js';
import {
  getAutomaticDayType,
  getBedtimeCutoff,
  getDailyLimit,
  getEffectivePlayDuration,
  getTodayAvailableMinutes,
  isInsideBedtimeBlock,
  POLICY_PRESETS,
  shouldTriggerCooldown,
} from '../src/policy.js';

test('accepts a valid earn task and normalizes its title', () => {
  assert.deepEqual(
    validateTaskInput({ title: '  Reading  ', duration: '30', value: '20', type: 'earn' }),
    { ok: true, title: 'Reading', duration: 30, value: 20 },
  );
});

test('rejects invalid task ranges and negative values', () => {
  assert.equal(validateTaskInput({ title: 'Read', duration: 9, value: 1, type: 'earn' }).ok, false);
  assert.equal(validateTaskInput({ title: 'Read', duration: 181, value: 1, type: 'earn' }).ok, false);
  assert.equal(validateTaskInput({ title: 'Game', duration: 30, value: -5, type: 'spend' }).ok, false);
});

test('rejects an earn reward greater than its duration', () => {
  const result = validateTaskInput({ title: 'Read', duration: 30, value: 31, type: 'earn' });
  assert.equal(result.ok, false);
});

test('rounds partial spend usage up to the next played minute', () => {
  assert.equal(getPlayedMinutes(30, 30 * 60), 0);
  assert.equal(getPlayedMinutes(30, 30 * 60 - 1), 1);
  assert.equal(getPlayedMinutes(30, 30 * 60 - 61), 2);
});

test('scales a quick test countdown back to the real task duration', () => {
  assert.equal(getPlayedMinutesForCountdown(30, 10, 10), 0);
  assert.equal(getPlayedMinutesForCountdown(30, 10, 9), 3);
  assert.equal(getPlayedMinutesForCountdown(30, 10, 5), 15);
  assert.equal(getPlayedMinutesForCountdown(30, 10, 0), 30);
});

test('prorates spend cost and never exceeds the task cost', () => {
  assert.equal(getProratedSpendCost(5, 15, 30), 10);
  assert.equal(getProratedSpendCost(16, 15, 30), 30);
  assert.equal(getProratedSpendCost(0, 15, 30), 0);
});

test('selects school and weekend day types automatically', () => {
  assert.equal(getAutomaticDayType(new Date(2026, 7, 14)), 'school');
  assert.equal(getAutomaticDayType(new Date(2026, 7, 15)), 'weekend');
});

test('applies lightweight plan limits and the public-health ceiling', () => {
  assert.equal(getDailyLimit({ policy: POLICY_PRESETS.strict, dayType: 'school' }), 20);
  assert.equal(getDailyLimit({ policy: POLICY_PRESETS.balanced, dayType: 'holiday' }), 90);
  assert.equal(getDailyLimit({ policy: POLICY_PRESETS.balanced, dayType: 'holiday', bonusMinutes: 50 }), 120);
});

test('shows one usable balance constrained by both coins and daily allowance', () => {
  assert.equal(getTodayAvailableMinutes({ balance: 100, todaySpent: 20, dailyLimit: 30 }), 10);
  assert.equal(getTodayAvailableMinutes({ balance: 8, todaySpent: 0, dailyLimit: 30 }), 8);
});

test('shortens a play session to affordability, daily allowance and session maximum', () => {
  assert.equal(getEffectivePlayDuration({
    requestedDuration: 30,
    requestedCost: 30,
    balance: 100,
    remainingDailyMinutes: 15,
    maxSessionMinutes: 20,
  }), 15);
  assert.equal(getEffectivePlayDuration({
    requestedDuration: 30,
    requestedCost: 60,
    balance: 10,
    remainingDailyMinutes: 30,
    maxSessionMinutes: 30,
  }), 5);
});

test('enforces bedtime buffer and cooldown from actual played time', () => {
  assert.equal(getBedtimeCutoff('20:30', 60), '19:30');
  assert.equal(isInsideBedtimeBlock({ date: new Date(2026, 7, 14, 19, 45), bedtime: '20:30', bufferMinutes: 60 }), true);
  assert.equal(isInsideBedtimeBlock({ date: new Date(2026, 7, 14, 18, 45), bedtime: '20:30', bufferMinutes: 60 }), false);
  assert.equal(shouldTriggerCooldown(19, 20), false);
  assert.equal(shouldTriggerCooldown(20, 20), true);
});
