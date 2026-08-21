const SUPPORTED_CLIENT_MODES = new Set(['combined', 'child', 'parent']);

export function normalizeClientMode(value) {
  return SUPPORTED_CLIENT_MODES.has(value) ? value : 'combined';
}

export function getInitialRole({ clientMode, search = '', hash = '' }) {
  const mode = normalizeClientMode(clientMode);
  if (mode === 'child') return 'child';
  if (mode === 'parent') return 'parent-locked';

  const queryRole = new URLSearchParams(search).get('view');
  const hashRole = new URLSearchParams(hash.replace(/^#/, '')).get('view');
  return (queryRole || hashRole) === 'parent' ? 'parent-locked' : 'child';
}

export function clientCanOpenRole(clientMode, role) {
  const mode = normalizeClientMode(clientMode);
  if (mode === 'combined') return role === 'child' || role === 'parent';
  return mode === role;
}
