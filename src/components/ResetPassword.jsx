import { useMemo, useState } from 'react';
import BrandLogo from './BrandLogo.jsx';

function getRecoveryState() {
  const hash = new URLSearchParams(window.location.hash.slice(1));
  const accessToken = hash.get('access_token') || '';
  const error = hash.get('error_description') || hash.get('error') || '';

  return {
    accessToken,
    error,
    isRecovery: hash.get('type') === 'recovery' || Boolean(accessToken),
  };
}

export default function ResetPassword() {
  const recovery = useMemo(getRecoveryState, []);
  const [password, setPassword] = useState('');
  const [confirmation, setConfirmation] = useState('');
  const [status, setStatus] = useState('idle');
  const [message, setMessage] = useState('');

  const projectUrl = import.meta.env.VITE_TIMEBOXER_SUPABASE_URL;
  const publishableKey = import.meta.env.VITE_TIMEBOXER_SUPABASE_PUBLISHABLE_KEY;
  const canReset = recovery.isRecovery && recovery.accessToken && projectUrl && publishableKey;

  const submit = async (event) => {
    event.preventDefault();
    setMessage('');

    if (password.length < 8) {
      setMessage('Use at least 8 characters for the new password.');
      return;
    }
    if (password !== confirmation) {
      setMessage('The two passwords do not match.');
      return;
    }
    if (!canReset) {
      setMessage('This reset link is invalid or has expired. Please request a new email.');
      return;
    }

    setStatus('saving');
    try {
      const response = await fetch(`${projectUrl}/auth/v1/user`, {
        method: 'PUT',
        headers: {
          apikey: publishableKey,
          Authorization: `Bearer ${recovery.accessToken}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({ password }),
      });
      const result = await response.json().catch(() => ({}));
      if (!response.ok) {
        throw new Error(result.msg || result.message || 'The reset link may have expired.');
      }

      window.history.replaceState({}, '', `${window.location.pathname}?view=reset-password&complete=1`);
      setPassword('');
      setConfirmation('');
      setStatus('complete');
    } catch (error) {
      setStatus('error');
      setMessage(error instanceof Error ? error.message : 'Password could not be updated.');
    }
  };

  const linkError = recovery.error
    ? recovery.error.replace(/\+/g, ' ')
    : (!canReset ? 'This reset link is invalid or has expired. Please request a new email.' : '');

  return (
    <main className="flex min-h-[100dvh] items-center justify-center bg-[#f8faf8] p-5 text-slate-950">
      <section className="w-full max-w-sm rounded-[28px] border border-slate-200 bg-white p-7 shadow-xl">
        <BrandLogo compact className="justify-center" />

        {status === 'complete' ? (
          <div className="mt-8 text-center">
            <div className="mx-auto flex h-14 w-14 items-center justify-center rounded-2xl bg-emerald-50 text-2xl text-emerald-600">✓</div>
            <h1 className="mt-5 text-2xl font-black">Password updated</h1>
            <p className="mt-2 text-sm leading-6 text-slate-500">
              You can now return to the TimeBoxer Parent app and sign in with your new password.
            </p>
          </div>
        ) : (
          <>
            <h1 className="mt-8 text-center text-2xl font-black">Set a new password</h1>
            <p className="mt-2 text-center text-sm leading-6 text-slate-500">
              This changes the password for your TimeBoxer parent account.
            </p>

            {linkError ? (
              <div role="alert" className="mt-6 rounded-2xl border border-amber-200 bg-amber-50 px-4 py-3 text-sm font-semibold leading-5 text-amber-800">
                {linkError}
              </div>
            ) : (
              <form onSubmit={submit} className="mt-6">
                <label className="block text-sm font-bold text-slate-700" htmlFor="new-password">New password</label>
                <input
                  id="new-password"
                  type="password"
                  autoComplete="new-password"
                  value={password}
                  onChange={(event) => setPassword(event.target.value)}
                  className="mt-2 w-full rounded-2xl border border-slate-200 px-4 py-3 outline-none focus:border-emerald-500"
                  placeholder="At least 8 characters"
                />

                <label className="mt-4 block text-sm font-bold text-slate-700" htmlFor="confirm-password">Confirm password</label>
                <input
                  id="confirm-password"
                  type="password"
                  autoComplete="new-password"
                  value={confirmation}
                  onChange={(event) => setConfirmation(event.target.value)}
                  className="mt-2 w-full rounded-2xl border border-slate-200 px-4 py-3 outline-none focus:border-emerald-500"
                  placeholder="Enter it again"
                />

                {message && <div role="alert" className="mt-3 text-sm font-semibold text-red-600">{message}</div>}
                <button
                  type="submit"
                  disabled={status === 'saving'}
                  className="mt-6 w-full rounded-2xl bg-[#35d532] py-3 font-black text-slate-950 hover:bg-emerald-400 disabled:cursor-wait disabled:opacity-60"
                >
                  {status === 'saving' ? 'Updating…' : 'Update password'}
                </button>
              </form>
            )}
          </>
        )}
      </section>
    </main>
  );
}
