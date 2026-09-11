import { useEffect, useState } from 'react';
import { gateApi } from '../services/api';
import { useYmir } from '../state/store';
import { LORE_LONG } from '../data/lore';

/** The visitor's telling of the lore — sourced from docs/lore.md, told short. */
const LORE_BEATS: { rune: string; name: string; line: string }[] = [
  {
    rune: 'ᛉ',
    name: 'Ymir',
    line: 'The primordial giant still — one repo, one machine, the body every world of work is carved from.',
  },
  {
    rune: 'ᛇ',
    name: 'Yggdrasil',
    line: 'The tree that binds the realms: parallel work grows in its branches, so no two hands ever collide.',
  },
  {
    rune: 'ᚦ',
    name: 'Utgard',
    line: 'The walled realm outside the halls — untrusted work runs there, so a bad casting never cracks the forge.',
  },
  {
    rune: 'ᛗ',
    name: 'Mimirsbrunn',
    line: 'The well at the root. Kaia drinks before she acts, so nothing is ever spoken dry.',
  },
  {
    rune: 'ᚱ',
    name: 'Ratatoskr',
    line: 'The squirrel on the tree — every word between agents is tracked, observed, and carved into Runes.',
  },
  {
    rune: 'ᚠ',
    name: 'Hlidskjalf',
    line: 'Odin’s high seat: one operator, seeing every realm, every agent, every run.',
  },
];

/** The gate login — shown when the tunnel origin has not authenticated. */
export function LoginModal({ onAuthed, hint }: { onAuthed: () => void; hint?: string }) {
  const enterDemo = useYmir((s) => s.enterDemo);
  const [username, setUsername] = useState('');
  const [password, setPassword] = useState('');
  const [err, setErr] = useState('');
  const [busy, setBusy] = useState(false);
  const [showLore, setShowLore] = useState(false);

  useEffect(() => {
    if (!showLore) return;
    const onKey = (e: KeyboardEvent) => {
      if (e.key === 'Escape') setShowLore(false);
    };
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  }, [showLore]);

  function demo() {
    enterDemo();
    onAuthed();
  }

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
      <div className="gate">
        <aside className="gate-lore" aria-label="The lore of Ymir">
          <span className="lore-kicker">The Lore</span>
          <h2 className="lore-hero">Before the worlds, there was Ymir.</h2>
          <p className="lore-lede">
            In the old telling, nothing lived but frost and ember — until they met in
            the void and the first giant woke. The gods made the world from his body:
            flesh the earth, blood the seas, bones the mountains, skull the sky.
          </p>

          <ul className="lore-beats">
            {LORE_BEATS.map((b) => (
              <li key={b.name}>
                <span className="lore-rune" aria-hidden="true">
                  {b.rune}
                </span>
                <span className="lore-name">{b.name}</span>
                <span className="lore-line">{b.line}</span>
              </li>
            ))}
          </ul>

          <p className="lore-close">
            The giant stands. The forge is lit.
            <span className="lore-cta"> Walk the worlds for yourself — enter demo mode below, no keys required.</span>
          </p>

          <button className="btn lore-more" type="button" onClick={() => setShowLore(true)}>
            <span aria-hidden="true">ᛖ</span> Read the full saga
          </button>
        </aside>

        <form className="login-card" onSubmit={submit}>
          <div className="login-brand">
            <img src="/ymir-mark.svg" alt="Ymir" className="brand-mark" width={44} height={44} />
            <div className="col">
              <span className="name">YMIR</span>
              <span className="sub">Hlidskjalf</span>
            </div>
          </div>

          <div className="login-about">
            <span className="eyebrow">What this is</span>
            <p>
              Ymir is a single-operator agent platform: one person directing a fleet of
              AI agents that build, research, review, and ship. Every agent works in an
              isolated sandbox, drinks from a shared long-term memory before it acts, and
              leaves every move in a ledger that cannot be rewritten.
            </p>
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

          {err ? (
            <span className="mono" style={{ color: 'var(--ymir-danger)', fontSize: 12 }}>
              {err}
            </span>
          ) : null}

          <button className="btn btn-primary" type="submit" disabled={busy} style={{ justifyContent: 'center' }}>
            <span aria-hidden="true">ᛉ</span> {busy ? 'Opening the gate…' : 'Enter'}
          </button>

          <div className="divider">or</div>

          <button
            className="btn"
            type="button"
            onClick={demo}
            title="Explore Hlidskjalf with seeded data — no runtime required"
            style={{ justifyContent: 'center' }}
          >
            <span aria-hidden="true">ᛟ</span> Enter demo mode
          </button>
        </form>
      </div>

      {showLore ? (
        <div
          className="lore-overlay"
          role="dialog"
          aria-modal="true"
          aria-label="The saga of Ymir"
          onClick={(e) => {
            if (e.target === e.currentTarget) setShowLore(false);
          }}
        >
          <div className="lore-parchment">
            <header className="lore-parchment-head">
              <span className="lore-kicker">The Saga of Ymir</span>
              <button className="btn" type="button" onClick={() => setShowLore(false)}>
                Close
              </button>
            </header>

            {LORE_LONG.map((sec) => (
              <section key={sec.id} className="lore-sec">
                <h3 className="lore-sec-title">{sec.title}</h3>
                {sec.paras.map((p, i) => (
                  <p key={i} className="lore-sec-p">
                    {p}
                  </p>
                ))}
                {sec.names ? (
                  <ul className="lore-names">
                    {sec.names.map((n) => (
                      <li key={n.name}>
                        <span className="lore-rune" aria-hidden="true">
                          {n.rune}
                        </span>
                        <span className="lore-name">{n.name}</span>
                        <span className="lore-line">{n.line}</span>
                      </li>
                    ))}
                  </ul>
                ) : null}
              </section>
            ))}

            <p className="lore-sec-p lore-end">The giant stands. The forge is lit. The seat is taken.</p>
          </div>
        </div>
      ) : null}
    </div>
  );
}
