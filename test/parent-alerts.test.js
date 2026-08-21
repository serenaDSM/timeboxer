import test from 'node:test';
import assert from 'node:assert/strict';
import {
  getParentAlertEvents,
  getParentAlertMetadata,
  getUnreadParentAlerts,
  pickBrowserAlert,
} from '../src/parentAlerts.js';

const events = [
  { id: 'blocked', type: 'blocked', createdAt: 400, message: 'YouTube was blocked.' },
  { id: 'policy', type: 'policy', createdAt: 350, message: 'Plan changed.' },
  { id: 'request', type: 'request', createdAt: 300, message: 'Alex asked for 10 minutes.' },
  { id: 'earned', type: 'earned', createdAt: 200, message: 'Alex earned 10 minutes.' },
];

test('keeps child activity alerts and excludes parent settings changes', () => {
  assert.deepEqual(getParentAlertEvents(events).map((event) => event.id), [
    'blocked',
    'request',
    'earned',
  ]);
});

test('counts only alerts newer than the device read timestamp', () => {
  assert.deepEqual(getUnreadParentAlerts(events, 250).map((event) => event.id), [
    'blocked',
    'request',
  ]);
});

test('prioritises a blocked attempt for one browser notification', () => {
  assert.equal(pickBrowserAlert(events)?.id, 'blocked');
});

test('prioritises an actionable request when there is no blocked attempt', () => {
  assert.equal(pickBrowserAlert(events.slice(1))?.id, 'request');
});

test('maps blocked and request events to distinct visual levels', () => {
  assert.equal(getParentAlertMetadata(events[0]).level, 'critical');
  assert.equal(getParentAlertMetadata(events[2]).level, 'action');
});
