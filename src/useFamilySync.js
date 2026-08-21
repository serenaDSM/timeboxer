import { useEffect, useState } from 'react';
import { familyStateFingerprint, isFamilyStateEnvelope, pickFamilyState } from './familyState.js';
import { notifyNative } from './nativeBridge.js';
import { useStore } from './store.js';

const sourceId = window.crypto?.randomUUID?.() || `web-${Date.now()}-${Math.random().toString(36).slice(2)}`;
const localSyncEndpoint = '/api/family-state';

const isParentBrowserClient = () => {
  if (window.__TIMEBOXER_MAC__) return false;
  const queryRole = new URLSearchParams(window.location.search).get('view');
  const hashRole = new URLSearchParams(window.location.hash.replace(/^#/, '')).get('view');
  return (queryRole || hashRole) === 'parent';
};

async function fetchFamilyState() {
  const response = await fetch(localSyncEndpoint, { cache: 'no-store' });
  if (!response.ok) throw new Error(`Family sync returned ${response.status}`);
  return response.json();
}

async function saveFamilyState(state) {
  const response = await fetch(localSyncEndpoint, {
    method: 'PUT',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ sourceId, state: pickFamilyState(state) }),
  });
  if (!response.ok) throw new Error(`Family sync returned ${response.status}`);
  return response.json();
}

export function useFamilySync() {
  const [syncStatus, setSyncStatus] = useState(window.__TIMEBOXER_MAC__ ? 'connecting' : 'local');

  useEffect(() => {
    const nativeClient = Boolean(window.__TIMEBOXER_MAC__);
    const parentBrowserClient = isParentBrowserClient();
    if (!nativeClient && !parentBrowserClient) return undefined;

    let active = true;
    let ready = false;
    let applyingRemote = false;
    let lastRevision = 0;
    let lastPushedFingerprint = '';
    let pushTimer;
    let pollTimer;

    const applyEnvelope = (envelope) => {
      if (!active || !isFamilyStateEnvelope(envelope)) return;
      const revision = Number(envelope.revision) || 0;
      if (revision < lastRevision) return;
      lastRevision = revision;

      const remoteFingerprint = familyStateFingerprint(envelope.state);
      const localFingerprint = familyStateFingerprint(useStore.getState());
      if (remoteFingerprint !== localFingerprint) {
        applyingRemote = true;
        useStore.getState().replaceSyncedState(envelope.state);
        applyingRemote = false;
      }
      const normalizedFingerprint = familyStateFingerprint(useStore.getState());
      lastPushedFingerprint = remoteFingerprint;
      if (normalizedFingerprint !== remoteFingerprint) {
        window.clearTimeout(pushTimer);
        pushTimer = window.setTimeout(() => pushNow(), 0);
      }
      setSyncStatus(
        nativeClient || Date.now() - Number(envelope.macHeartbeatAt || 0) < 10_000
          ? 'linked'
          : 'disconnected',
      );
    };

    const pushNow = async () => {
      if (!active || !ready || applyingRemote) return;
      const state = useStore.getState();
      const fingerprint = familyStateFingerprint(state);
      if (fingerprint === lastPushedFingerprint) return;

      if (nativeClient) {
        if (notifyNative('family-state-update', { sourceId, state: pickFamilyState(state) })) {
          lastPushedFingerprint = fingerprint;
          setSyncStatus('linked');
        }
        return;
      }

      try {
        const envelope = await saveFamilyState(state);
        if (active) applyEnvelope(envelope);
      } catch {
        if (active) setSyncStatus('disconnected');
      }
    };

    const schedulePush = () => {
      if (!ready || applyingRemote) return;
      window.clearTimeout(pushTimer);
      pushTimer = window.setTimeout(pushNow, 120);
    };

    const unsubscribe = useStore.subscribe(schedulePush);

    if (nativeClient) {
      const handleNativeSnapshot = (event) => {
        if (event.detail?.type !== 'family-state-snapshot') return;
        const envelope = event.detail.payload;
        if (isFamilyStateEnvelope(envelope)) applyEnvelope(envelope);
        ready = true;
        if (!isFamilyStateEnvelope(envelope)) schedulePush();
      };
      window.addEventListener('timeboxer:native-event', handleNativeSnapshot);
      notifyNative('family-state-request', { sourceId });

      return () => {
        active = false;
        window.clearTimeout(pushTimer);
        unsubscribe();
        window.removeEventListener('timeboxer:native-event', handleNativeSnapshot);
      };
    }

    // During the local prototype the parent client is authoritative on first
    // connection. Afterwards both clients exchange versioned state changes.
    ready = true;
    setSyncStatus('connecting');
    pushNow();
    pollTimer = window.setInterval(async () => {
      try {
        const envelope = await fetchFamilyState();
        if (active && Number(envelope.revision) > lastRevision) {
          applyEnvelope(envelope);
        } else if (active) {
          setSyncStatus(
            Date.now() - Number(envelope.macHeartbeatAt || 0) < 10_000
              ? 'linked'
              : 'disconnected',
          );
        }
      } catch {
        if (active) setSyncStatus('disconnected');
      }
    }, 750);

    return () => {
      active = false;
      window.clearTimeout(pushTimer);
      window.clearInterval(pollTimer);
      unsubscribe();
    };
  }, []);

  return syncStatus;
}
