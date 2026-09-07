export const LEGACY_DEFAULT_PARENT_PIN = '1234';

export function isSecureParentPIN(value) {
  const normalized = String(value || '').trim();
  return /^\d{4,8}$/.test(normalized) && normalized !== LEGACY_DEFAULT_PARENT_PIN;
}
