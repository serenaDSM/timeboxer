const ALERTABLE_EVENT_TYPES = new Set([
  'blocked',
  'request',
  'earned',
  'earn-cap',
  'played',
]);

const ALERT_METADATA = {
  offline: {
    level: 'critical',
    title: 'Mac child offline',
    browserTitle: 'TimeBoxer connection lost',
  },
  blocked: {
    level: 'critical',
    title: 'Entertainment blocked',
    browserTitle: 'TimeBoxer blocked entertainment',
  },
  request: {
    level: 'action',
    title: 'Needs your decision',
    browserTitle: 'Extra-time request',
  },
  earned: {
    level: 'positive',
    title: 'Time earned',
    browserTitle: 'TimeBoxer activity completed',
  },
  'earn-cap': {
    level: 'info',
    title: 'Daily reward cap reached',
    browserTitle: 'TimeBoxer daily cap reached',
  },
  played: {
    level: 'info',
    title: 'Entertainment used',
    browserTitle: 'TimeBoxer play update',
  },
};

export function isParentAlertEvent(event) {
  return Boolean(event && ALERTABLE_EVENT_TYPES.has(event.type));
}

export function getParentAlertMetadata(event) {
  return ALERT_METADATA[event?.type] || {
    level: 'info',
    title: 'Family activity',
    browserTitle: 'TimeBoxer update',
  };
}

export function getParentAlertEvents(events = []) {
  return events.filter(isParentAlertEvent);
}

export function getUnreadParentAlerts(events = [], readAt = 0) {
  const timestamp = Number(readAt) || 0;
  return getParentAlertEvents(events).filter((event) => Number(event.createdAt) > timestamp);
}

export function pickBrowserAlert(events = []) {
  const alertEvents = getParentAlertEvents(events);
  return alertEvents.find((event) => event.type === 'blocked')
    || alertEvents.find((event) => event.type === 'request')
    || alertEvents[0]
    || null;
}
