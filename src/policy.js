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
    description: 'A short 2–4 week reset with firm, predictable boundaries.',
    schoolLimit: 10,
    weekendLimit: 20,
    holidayLimit: 30,
    schoolEarnCapMinutes: 10,
    weekendEarnCapMinutes: 20,
    holidayEarnCapMinutes: 20,
    maxSessionMinutes: 20,
    cooldownMinutes: 10,
    cooldownTriggerMinutes: 20,
    bedtimeBufferMinutes: 60,
  },
  balanced: {
    id: 'balanced',
    name: 'Balanced',
    description: 'A simple everyday plan with a small base and earnable bonus.',
    schoolLimit: 20,
    weekendLimit: 30,
    holidayLimit: 40,
    schoolEarnCapMinutes: 10,
    weekendEarnCapMinutes: 20,
    holidayEarnCapMinutes: 20,
    maxSessionMinutes: 20,
    cooldownMinutes: 10,
    cooldownTriggerMinutes: 20,
    bedtimeBufferMinutes: 60,
  },
  collaborative: {
    id: 'collaborative',
    name: 'Collaborative',
    description: 'More autonomy after the child is following the plan reliably.',
    schoolLimit: 30,
    weekendLimit: 45,
    holidayLimit: 60,
    schoolEarnCapMinutes: 10,
    weekendEarnCapMinutes: 15,
    holidayEarnCapMinutes: 15,
    maxSessionMinutes: 25,
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

export function getEarnBonusCap(policy, dayType) {
  if (dayType === 'holiday') return Math.max(0, Number(policy.holidayEarnCapMinutes) || 0);
  if (dayType === 'weekend') return Math.max(0, Number(policy.weekendEarnCapMinutes) || 0);
  return Math.max(0, Number(policy.schoolEarnCapMinutes) || 0);
}

export function getMaximumDailyLimit(policy, dayType) {
  return Math.min(
    PUBLIC_HEALTH_CEILING_MINUTES,
    getBaseDailyLimit(policy, dayType) + getEarnBonusCap(policy, dayType),
  );
}

export function getDailyLimit({ policy, dayType, earnedMinutes = 0, bonusMinutes = 0 }) {
  const base = getBaseDailyLimit(policy, dayType);
  const earned = Math.min(getEarnBonusCap(policy, dayType), Math.max(0, Number(earnedMinutes)));
  return Math.min(
    PUBLIC_HEALTH_CEILING_MINUTES,
    Math.max(0, Number(base) + earned + Math.max(0, Number(bonusMinutes))),
  );
}

export function getTodayAvailableMinutes({ todaySpent, dailyLimit }) {
  return Math.max(0, Number(dailyLimit) - Number(todaySpent));
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
  remainingDailyMinutes,
  maxSessionMinutes,
}) {
  const duration = Math.max(0, Number(requestedDuration));
  if (!duration) return 0;

  return Math.max(0, Math.floor(Math.min(
    duration,
    Math.max(0, Number(remainingDailyMinutes)),
    Math.max(0, Number(maxSessionMinutes)),
  )));
}
