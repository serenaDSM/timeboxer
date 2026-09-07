import { createServer } from 'node:http';

const host = '127.0.0.1';
const port = Number(process.env.TIMEBOXER_RECOVERY_PORT) || 3000;
const projectUrl = process.env.VITE_TIMEBOXER_SUPABASE_URL || '';
const publishableKey = process.env.VITE_TIMEBOXER_SUPABASE_PUBLISHABLE_KEY || '';

if (!projectUrl || !publishableKey) {
  throw new Error('TimeBoxer Supabase public configuration is required.');
}

const publicConfig = JSON.stringify({ projectUrl, publishableKey }).replaceAll('<', '\\u003c');
const html = `<!doctype html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width,initial-scale=1">
  <title>Reset TimeBoxer password</title>
  <style>
    :root { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif; color: #0f172a; background: #f8faf8; }
    * { box-sizing: border-box; }
    body { margin: 0; }
    main { min-height: 100vh; display: grid; place-items: center; padding: 20px; }
    .card { width: min(100%, 390px); padding: 28px; border: 1px solid #e2e8f0; border-radius: 28px; background: white; box-shadow: 0 20px 50px rgba(15,23,42,.12); }
    .brand { display: flex; align-items: center; justify-content: center; gap: 12px; font-size: 19px; font-weight: 900; font-style: italic; letter-spacing: -.5px; }
    .mark { width: 42px; height: 42px; display: grid; place-items: center; border-radius: 12px; background: #0f1115; }
    .mark svg { width: 29px; height: 29px; }
    .green { color: #28dc35; }
    h1 { margin: 30px 0 8px; text-align: center; font-size: 26px; }
    .intro { margin: 0 0 24px; color: #64748b; text-align: center; font-size: 14px; line-height: 1.55; }
    label { display: block; margin: 16px 0 8px; font-size: 14px; font-weight: 700; }
    input { width: 100%; padding: 13px 15px; border: 1px solid #e2e8f0; border-radius: 16px; font: inherit; outline: none; }
    input:focus { border-color: #28dc35; box-shadow: 0 0 0 3px rgba(40,220,53,.12); }
    button { width: 100%; margin-top: 24px; padding: 13px; border: 0; border-radius: 16px; background: #35d532; color: #0f172a; font: inherit; font-weight: 900; cursor: pointer; }
    button:disabled { cursor: wait; opacity: .6; }
    .message { margin-top: 14px; padding: 12px 14px; border-radius: 14px; background: #fff7ed; color: #9a3412; font-size: 14px; font-weight: 600; line-height: 1.45; }
    .success { text-align: center; }
    .success-icon { width: 58px; height: 58px; display: grid; place-items: center; margin: 30px auto 0; border-radius: 18px; background: #ecfdf5; color: #16a34a; font-size: 28px; font-weight: 900; }
    [hidden] { display: none !important; }
  </style>
</head>
<body>
  <main>
    <section class="card">
      <div class="brand">
        <span class="mark" aria-hidden="true">
          <svg viewBox="0 0 48 48" fill="none" stroke="#2cff3b" stroke-width="4" stroke-linejoin="round"><path d="M24 5 41 14.5v19L24 43 7 33.5v-19L24 5Z"/><path d="m7 14.5 17 10 17-10M24 24.5V43"/></svg>
        </span>
        <span>TIME<span class="green">BOXER</span></span>
      </div>
      <div id="form-view">
        <h1>Set a new password</h1>
        <p class="intro">This changes the password for your TimeBoxer parent account.</p>
        <form id="reset-form">
          <label for="password">New password</label>
          <input id="password" type="password" autocomplete="new-password" minlength="8" placeholder="At least 8 characters" required>
          <label for="confirmation">Confirm password</label>
          <input id="confirmation" type="password" autocomplete="new-password" minlength="8" placeholder="Enter it again" required>
          <div id="message" class="message" role="alert" hidden></div>
          <button id="submit" type="submit">Update password</button>
        </form>
      </div>
      <div id="success-view" class="success" hidden>
        <div class="success-icon">✓</div>
        <h1>Password updated</h1>
        <p class="intro">Return to the TimeBoxer Parent app and sign in with your new password.</p>
      </div>
    </section>
  </main>
  <script>
    const config = ${publicConfig};
    const hash = new URLSearchParams(location.hash.slice(1));
    const accessToken = hash.get('access_token') || '';
    const message = document.getElementById('message');
    const form = document.getElementById('reset-form');
    const submit = document.getElementById('submit');
    const showMessage = (text) => { message.textContent = text; message.hidden = false; };

    const linkError = hash.get('error_description') || hash.get('error');
    if (linkError || !accessToken || (hash.get('type') && hash.get('type') !== 'recovery')) {
      showMessage((linkError || 'This reset link is invalid or has expired. Please request a new email.').replace(/\\+/g, ' '));
      submit.disabled = true;
    }

    form.addEventListener('submit', async (event) => {
      event.preventDefault();
      message.hidden = true;
      const password = document.getElementById('password').value;
      const confirmation = document.getElementById('confirmation').value;
      if (password.length < 8) return showMessage('Use at least 8 characters for the new password.');
      if (password !== confirmation) return showMessage('The two passwords do not match.');
      submit.disabled = true;
      submit.textContent = 'Updating…';
      try {
        const response = await fetch(config.projectUrl + '/auth/v1/user', {
          method: 'PUT',
          headers: { apikey: config.publishableKey, Authorization: 'Bearer ' + accessToken, 'Content-Type': 'application/json' },
          body: JSON.stringify({ password }),
        });
        const result = await response.json().catch(() => ({}));
        if (!response.ok) throw new Error(result.msg || result.message || 'The reset link may have expired.');
        history.replaceState({}, '', '/?view=reset-password&complete=1');
        document.getElementById('form-view').hidden = true;
        document.getElementById('success-view').hidden = false;
      } catch (error) {
        showMessage(error.message || 'Password could not be updated.');
        submit.disabled = false;
        submit.textContent = 'Update password';
      }
    });
  </script>
</body>
</html>`;

createServer((request, response) => {
  if (request.method !== 'GET' && request.method !== 'HEAD') {
    response.writeHead(405, { Allow: 'GET, HEAD' });
    response.end();
    return;
  }
  response.writeHead(200, {
    'Content-Type': 'text/html; charset=utf-8',
    'Cache-Control': 'no-store',
    'Referrer-Policy': 'no-referrer',
    'X-Content-Type-Options': 'nosniff',
    'X-Frame-Options': 'DENY',
  });
  response.end(request.method === 'HEAD' ? undefined : html);
}).listen(port, host, () => {
  console.log(`TimeBoxer password recovery is ready at http://${host}:${port}`);
});
