import { useState } from 'react';
import { gateApi } from '../services/api';

/** The gate login — shown when the tunnel origin has not authenticated. */
export function LoginModal({ onAuthed, hint }: { onAuthed: () => void; hint?: string }) {
  const [username, setUsername] = useState('');
  const [password, setPassword] = useState('');
  const [err, setErr] = useState('');
  const [busy, setBusy] = useState(false);

  async function submit(e: React.FormEvent) {
    e.preventDefault();
    if (busy) return;
    setBusy(true);
    setErr('');
    try {
      await gateApi.login(username, password);
      onAuthed();
    } catch {
      setErr('Wrong username or password');
    } finally {
      setBusy(false);
    }
  }

  return (
    <div className="login">
      <form className="login-card" onSubmit={submit}>
        <div className="login-brand">
          <img src="/ymir-mark.svg" alt="Ymir" className="brand-mark" width={44} height={44} />
          <div className="col">
            <span className="name">YMIR</span>
            <span className="sub">Hlidskjalf</span>
          </div>
        </div>

        <div>
          <h1 className="login-title">Sign in</h1>
          <p className="login-deck" style={{ marginTop: 6 }}>
            {hint ?? 'The gate is closed. Enter the Allfather’s credentials.'}
          </p>
        </div>

        <label className="field">
          <span className="eyebrow">Username</span>
          <input
            value={username}
            onChange={(e) => setUsername(e.target.value)}
            autoComplete="username"
            autoFocus
            placeholder="zerwiz"
          />
        </label>

        <label className="field">
          <span className="eyebrow">Password</span>
          <input
            type="password"
            value={password}
            onChange={(e) => setPassword(e.target.value)}
            autoComplete="current-password"
            placeholder="••••••••"
          />
        </label>

        {err ? <span className="mono" style={{ color: 'var(--ymir-danger)', fontSize: 12 }}>{err}</span> : null}

        <button className="btn btn-primary" type="submit" disabled={busy} style={{ justifyContent: 'center' }}>
          <span aria-hidden="true">ᛉ</span> {busy ? 'Opening the gate…' : 'Enter'}
        </button>
      </form>
    </div>
  );
}
