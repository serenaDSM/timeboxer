import { useState } from 'react';
import LockKeyhole from 'lucide-react/dist/esm/icons/lock-keyhole.js';
import BrandLogo from './BrandLogo.jsx';
import { isSecureParentPIN } from '../parentPIN.js';

export default function ParentPINSetup({ onComplete }) {
  const [pin, setPin] = useState('');
  const [confirmation, setConfirmation] = useState('');
  const [message, setMessage] = useState('');
  const [isAuthorizing, setIsAuthorizing] = useState(false);

  const requestMacParentAuthorization = () => new Promise((resolve) => {
    if (!window.__TIMEBOXER_MAC__) {
      resolve(true);
      return;
    }

    const requestId = crypto.randomUUID();
    const handler = window.webkit?.messageHandlers?.timeboxer;
    if (!handler) {
      resolve(false);
      return;
    }
    const timeout = window.setTimeout(() => {
      window.removeEventListener('timeboxer:native-event', handleResult);
      resolve(false);
    }, 90_000);
    function handleResult(event) {
      if (event.detail?.type !== 'parent-authorization-result') return;
      if (event.detail?.payload?.requestId !== requestId) return;
      window.clearTimeout(timeout);
      window.removeEventListener('timeboxer:native-event', handleResult);
      resolve(event.detail?.payload?.allowed === true);
    }
    window.addEventListener('timeboxer:native-event', handleResult);
    handler.postMessage({
      type: 'authorize-parent-pin-setup',
      payload: { requestId },
      sentAt: Date.now(),
    });
  });

  const submit = async (event) => {
    event.preventDefault();
    if (!isSecureParentPIN(pin)) {
      setMessage('Choose 4–8 digits. The old default 1234 cannot be used.');
      return;
    }
    if (pin !== confirmation) {
      setMessage('The two PIN entries do not match.');
      return;
    }
    setIsAuthorizing(true);
    setMessage('Waiting for a parent to approve with a Mac administrator account…');
    const allowed = await requestMacParentAuthorization();
    setIsAuthorizing(false);
    if (!allowed) {
      setMessage('Parent authorization was cancelled or could not be verified.');
      return;
    }
    onComplete(pin);
  };

  return (
    <main className="flex min-h-[100dvh] items-center justify-center bg-[#f8faf8] p-5 text-slate-950">
      <form onSubmit={submit} className="w-full max-w-sm rounded-[28px] border border-slate-200 bg-white p-7 text-center shadow-xl">
        <BrandLogo compact className="justify-center" />
        <div className="mx-auto mt-6 flex h-14 w-14 items-center justify-center rounded-2xl bg-emerald-50 text-emerald-600">
          <LockKeyhole size={24} />
        </div>
        <h1 className="mt-5 text-2xl font-black">Parent setup required</h1>
        <p className="mt-2 text-sm leading-6 text-slate-500">
          Ask a parent to create a private PIN before protection starts. It is required to quit TimeBoxer or leave an Earn activity.
        </p>
        <label className="mt-6 block text-left text-sm font-bold text-slate-700" htmlFor="setup-parent-pin">New parent PIN</label>
        <input
          id="setup-parent-pin"
          autoFocus
          type="password"
          inputMode="numeric"
          autoComplete="new-password"
          value={pin}
          onChange={(event) => {
            setPin(event.target.value.replace(/\D/g, '').slice(0, 8));
            setMessage('');
          }}
          className="mt-2 w-full rounded-2xl border border-slate-200 px-4 py-3 text-center text-xl font-black tracking-[0.35em] outline-none focus:border-emerald-500"
          placeholder="••••"
        />
        <label className="mt-4 block text-left text-sm font-bold text-slate-700" htmlFor="confirm-parent-pin">Confirm PIN</label>
        <input
          id="confirm-parent-pin"
          type="password"
          inputMode="numeric"
          autoComplete="new-password"
          value={confirmation}
          onChange={(event) => {
            setConfirmation(event.target.value.replace(/\D/g, '').slice(0, 8));
            setMessage('');
          }}
          className="mt-2 w-full rounded-2xl border border-slate-200 px-4 py-3 text-center text-xl font-black tracking-[0.35em] outline-none focus:border-emerald-500"
          placeholder="••••"
        />
        <div role="alert" className="mt-3 min-h-5 text-sm font-bold text-red-500">{message}</div>
        <button
          type="submit"
          disabled={isAuthorizing}
          className="mt-3 w-full rounded-2xl bg-[#35d532] py-3 font-black text-slate-950 hover:bg-emerald-400 disabled:cursor-wait disabled:opacity-60"
        >
          {isAuthorizing ? 'Waiting for parent…' : 'Enable protection'}
        </button>
      </form>
    </main>
  );
}
