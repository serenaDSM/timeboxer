export function notifyNative(type, payload = {}) {
  const handler = window.webkit?.messageHandlers?.timeboxer;
  if (!handler) return false;

  handler.postMessage({
    type,
    payload,
    sentAt: Date.now(),
  });
  return true;
}
