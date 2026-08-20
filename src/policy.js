import { getLocalDateKey } from './date.js';

export const DAY_TYPES = {
  school: 'School day',
  weekend: 'Weekend',
  holiday: 'Holiday',
};

export const POLICY_PRESETS = {
  strict: {
    id: 'strict',
    name: 'Strict Reset',
    description: 'A short reset for families that need firmer boundaries.',
    schoolLimit: 20,
    weekendLimit: 40,
    holidayLimit: 60,
    maxSessionMinutes: 20,
    cooldownMinutes: 10,
    cooldownTriggerMinutes: 20,
    bedtimeBufferMinutes: 60,
  },
  balanced: {
    id: 'balanced',
    name: 'Balanced',
    description: 'A simple everyday plan with room for choice.',
    schoolLimit: 30,
    weekendLimit: 60,
    holidayLimit: 90,
    maxSessionMinutes: 30,
    cooldownMinutes: 10,
    cooldownTriggerMinutes: 20,
    bedtimeBufferMinutes: 60,
  },
};

export const DEFAULT_POLICY = { ...POLICY_PRESETS.balanced };
export const PUBLIC_HEALTH_CEILING_MINUTES = 120;

export function getAutomaticDayType(date = new Date()) {
  const day = date.getDay();
  return day === 0 || day === 6 ? 'weekend' : 'school';
}

export function getDayType({ date = new Date(), dayOverrides = {} } = {}) {
  return dayOverrides[getLocalDateKey(date)] || getAutomaticDayType(date);
}

export function getBaseDailyLimit(policy, dayType) {
  if (dayType === 'holiday') return policy.holidayLimit;
  if (dayType === 'weekend') return policy.weekendLimit;
  return policy.schoolLimit;
}

export function getDailyLimit({ policy, dayType, bonusMinutes = 0 }) {
  const base = getBaseDailyLimit(policy, dayType);
  return Math.min(
    PUBLIC_HEALTH_CEILING_MINUTES,
    Math.max(0, Number(base) + Math.max(0, Number(bonusMinutes))),
  );
}

export function getTodayAvailableMinutes({ balance, todaySpent, dailyLimit }) {
  const remainingLimit = Math.max(0, Number(dailyLimit) - Number(todaySpent));
  return Math.max(0, Math.min(Number(balance), remainingLimit));
}

export function getBedtimeCutoff(bedtime = '20:30', bufferMinutes = 60) {
  const [hours, minutes] = bedtime.split(':').map(Number);
  const bedtimeMinutes = hours * 60 + minutes;
  const cutoffMinutes = (bedtimeMinutes - bufferMinutes + 24 * 60) % (24 * 60);
  const cutoffHours = Math.floor(cutoffMinutes / 60);
  const cutoffMins = cutoffMinutes % 60;
  return `${String(cutoffHours).padStart(2, '0')}:${String(cutoffMins).padStart(2, '0')}`;
}

export function isInsideBedtimeBlock({ date = new Date(), bedtime = '20:30', bufferMinutes = 60 }) {
  const [bedtimeHours, bedtimeMinutes] = bedtime.split(':').map(Number);
  const bedtimeAt = bedtimeHours * 60 + bedtimeMinutes;
  const cutoffAt = (bedtimeAt - bufferMinutes + 24 * 60) % (24 * 60);
  const nowMinutes = date.getHours() * 60 + date.getMinutes();

  // A conservative overnight block ends at 5am. This avoids treating the hours
  // after midnight as a fresh entertainment window.
  if (cutoffAt <= bedtimeAt) {
    return nowMinutes >= cutoffAt || nowMinutes < 5 * 60;
  }
  return nowMinutes >= cutoffAt && nowMinutes < 5 * 60;
}

export function shouldTriggerCooldown(playedMinutes, triggerMinutes = 20) {
  return Number(playedMinutes) >= Number(triggerMinutes);
}

export function getEffectivePlayDuration({
  requestedDuration,
  requestedCost,
  balance,
  remainingDailyMinutes,
  maxSessionMinutes,
}) {
  const duration = Math.max(0, Number(requestedDuration));
  const cost = Math.max(0, Number(requestedCost));
  if (!duration || !cost) return 0;

  const affordableDuration = Math.floor((Math.max(0, Number(balance)) * duration) / cost);
  return Math.max(0, Math.floor(Math.min(
    duration,
    affordableDuration,
    Math.max(0, Number(remainingDailyMinutes)),
    Math.max(0, Number(maxSessionMinutes)),
  )));
}
