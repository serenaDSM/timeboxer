export const FAMILY_STATE_SCHEMA_VERSION = 1;

export const FAMILY_STATE_FIELDS = [
  'availableMinutes',
  'availableMinutesDate',
  'totalEarned',
  'totalSpent',
  'todaySpent',
  'lastSpentDate',
  'cooldownUntil',
  'testTimerSeconds',
  'parentPIN',
  'hasSeenOnboarding',
  'earnTasks',
  'spendTasks',
  'familyProfile',
  'policy',
  'dayOverrides',
  'dailyBonuses',
  'pendingRequests',
  'recentEvents',
  'childStatus',
  'detectedApplications',
  'detectedApplicationsScannedAt',
  'applicationProtectionOverrides',
  'lastPolicyUpdatedAt',
];

const cloneJsonValue = (value) => JSON.parse(JSON.stringify(value));

const sortJsonValue = (value) => {
  if (Array.isArray(value)) return value.map(sortJsonValue);
  if (!value || typeof value !== 'object') return value;
  return Object.fromEntries(
    Object.keys(value)
      .sort()
      .map((key) => [key, sortJsonValue(value[key])]),
  );
};

export function pickFamilyState(source = {}) {
  const state = {};
  for (const field of FAMILY_STATE_FIELDS) {
    if (source[field] !== undefined) state[field] = cloneJsonValue(source[field]);
  }
  return state;
}

export function familyStateFingerprint(source = {}) {
  return JSON.stringify(sortJsonValue(pickFamilyState(source)));
}

export function isFamilyStateEnvelope(value) {
  return Boolean(
    value
    && typeof value === 'object'
    && Number.isInteger(Number(value.revision))
    && value.state
    && typeof value.state === 'object',
  );
}
