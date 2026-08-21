import test from 'node:test';
import assert from 'node:assert/strict';
import {
  getPlayedMinutes,
  getPlayedMinutesForCountdown,
  validateTaskInput,
} from '../src/rules.js';
import {
  getAutomaticDayType,
  getBedtimeCutoff,
  getDailyLimit,
  getEarnBonusCap,
  getEffectivePlayDuration,
  getMaximumDailyLimit,
  getTodayAvailableMinutes,
  isInsideBedtimeBlock,
  POLICY_PRESETS,
  shouldTriggerCooldown,
} from '../src/policy.js';
import {
  DEFAULT_EARN_TASKS,
  DEFAULT_SPEND_TASKS,
  migrateEarnTasks,
  migrateSpendTasks,
} from '../src/defaults.js';
import { FAMILY_STATE_FIELDS, familyStateFingerprint, pickFamilyState } from '../src/familyState.js';

test('accepts a valid earn task and normalizes its title', () => {
  assert.deepEqual(
    validateTaskInput({ title: '  Reading  ', duration: '30', value: '20', type: 'earn' }),
    { ok: true, title: 'Reading', duration: 30, value: 20 },
  );
});

test('rejects invalid task ranges and negative values', () => {
  assert.equal(validateTaskInput({ title: 'Read', duration: 9, value: 1, type: 'earn' }).ok, false);
  assert.equal(validateTaskInput({ title: 'Read', duration: 181, value: 1, type: 'earn' }).ok, false);
  assert.equal(validateTaskInput({ title: 'Read', duration: 30, value: -5, type: 'earn' }).ok, false);
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

test('selects school and weekend day types automatically', () => {
  assert.equal(getAutomaticDayType(new Date(2026, 7, 14)), 'school');
  assert.equal(getAutomaticDayType(new Date(2026, 7, 15)), 'weekend');
});

test('keeps parent-approved time separate and under the health ceiling', () => {
  assert.equal(getDailyLimit({
    policy: POLICY_PRESETS.balanced,
    dayType: 'holiday',
    earnedMinutes: 20,
    bonusMinutes: 80,
  }), 120);
});

test('combines a base allowance with a capped earnable bonus', () => {
  assert.equal(getDailyLimit({ policy: POLICY_PRESETS.strict, dayType: 'school' }), 10);
  assert.equal(getDailyLimit({ policy: POLICY_PRESETS.strict, dayType: 'school', earnedMinutes: 10 }), 20);
  assert.equal(getDailyLimit({ policy: POLICY_PRESETS.balanced, dayType: 'holiday', earnedMinutes: 50 }), 60);
  assert.equal(getEarnBonusCap(POLICY_PRESETS.balanced, 'weekend'), 20);
  assert.equal(getMaximumDailyLimit(POLICY_PRESETS.collaborative, 'holiday'), 75);
});

test('shows the remaining current allowance after today’s use', () => {
  assert.equal(getTodayAvailableMinutes({ todaySpent: 20, dailyLimit: 30 }), 10);
  assert.equal(getTodayAvailableMinutes({ todaySpent: 0, dailyLimit: 20 }), 20);
});

test('shortens a play session to the daily allowance and session maximum', () => {
  assert.equal(getEffectivePlayDuration({
    requestedDuration: 30,
    remainingDailyMinutes: 15,
    maxSessionMinutes: 20,
  }), 15);
  assert.equal(getEffectivePlayDuration({
    requestedDuration: 30,
    remainingDailyMinutes: 30,
    maxSessionMinutes: 20,
  }), 20);
});

test('replaces legacy default earn activities while preserving custom ones', () => {
  const migrated = migrateEarnTasks([
    { id: 'earn-1', title: 'Chinese Reading', duration: 30, reward: 30, icon: 'BookOpen' },
    { id: 'custom-piano', title: 'Piano', duration: 20, reward: 5, icon: 'Sparkles' },
  ]);

  assert.deepEqual(migrated.slice(0, 3), DEFAULT_EARN_TASKS);
  assert.equal(migrated.at(-1).title, 'Piano');
});

test('replaces legacy entertainment defaults while preserving custom activities', () => {
  const migrated = migrateSpendTasks([
    { id: 'spend-1', title: 'Video Games', duration: 30, cost: 30, icon: 'Gamepad2' },
    { id: 'spend-2', title: 'Watch TV', duration: 30, icon: 'Tv' },
    { id: 'custom-music', title: 'Listen to Music', duration: 15, cost: 15, icon: 'Tv' },
  ]);

  assert.deepEqual(migrated.slice(0, 2), DEFAULT_SPEND_TASKS);
  assert.deepEqual(migrated.at(-1), {
    id: 'custom-music', title: 'Listen to Music', duration: 15, icon: 'Tv',
  });
});

test('enforces bedtime buffer and cooldown from actual played time', () => {
  assert.equal(getBedtimeCutoff('20:30', 60), '19:30');
  assert.equal(isInsideBedtimeBlock({ date: new Date(2026, 7, 14, 19, 45), bedtime: '20:30', bufferMinutes: 60 }), true);
  assert.equal(isInsideBedtimeBlock({ date: new Date(2026, 7, 14, 18, 45), bedtime: '20:30', bufferMinutes: 60 }), false);
  assert.equal(shouldTriggerCooldown(19, 20), false);
  assert.equal(shouldTriggerCooldown(20, 20), true);
});

test('shares one explicit family-state contract without store actions', () => {
  const source = {
    availableMinutes: 5,
    todaySpent: 10,
    policy: { id: 'balanced' },
    updatePolicy() {},
    ignoredField: 'not synced',
  };
  const shared = pickFamilyState(source);

  assert.deepEqual(shared, {
    availableMinutes: 5,
    todaySpent: 10,
    policy: { id: 'balanced' },
  });
  assert.equal(FAMILY_STATE_FIELDS.includes('dailyBonuses'), true);
  assert.equal(familyStateFingerprint(source), familyStateFingerprint(shared));
  assert.equal(
    familyStateFingerprint({ policy: { id: 'balanced', schoolLimit: 20 } }),
    familyStateFingerprint({ policy: { schoolLimit: 20, id: 'balanced' } }),
  );
});
