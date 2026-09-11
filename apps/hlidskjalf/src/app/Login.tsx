import { useState } from 'react';
import { DOMAIN_LABEL } from '../data/realms';
import { MOCK_IDENTITIES, type MockIdentity } from '../services/auth';
import { gateApi } from '../services/api';
import { useYmir } from '../state/store';

function GitHubMark({ size = 18 }: { size?: number }) {
  return (
    <svg width={size} height={size} viewBox="0 0 16 16" fill="currentColor" aria-hidden="true">
      <path d="M8 0C3.58 0 0 3.58 0 8c0 3.54 2.29 6.53 5.47 7.59.4.07.55-.17.55-.38 0-.19-.01-.82-.01-1.49-2.01.37-2.53-.49-2.69-.94-.09-.23-.48-.94-.82-1.13-.28-.15-.68-.52-.01-.53.63-.01 1.08.58 1.23.82.72 1.21 1.87.87 2.33.66.07-.52.28-.87.51-1.07-1.78-.2-3.64-.89-3.64-3.95 0-.87.31-1.59.82-2.15-.08-.2-.36-1.02.08-2.12 0 0 .67-.21 2.2.82.64-.18 1.32-.27 2-.27.68 0 1.36.09 2 .27 1.53-1.04 2.2-.82 2.2-.82.44 1.1.16 1.92.08 2.12.51.56.82 1.27.82 2.15 0 3.07-1.87 3.75-3.65 3.95.29.25.54.73.54 1.48 0 1.07-.01 1.93-.01 2.2 0 .21.15.46.55.38A8.01 8.01 0 0 0 16 8c0-4.42-3.58-8-8-8Z" />
    </svg>
  );
}

const DOMAINS = ['company', 'marketing', 'development', 'life', 'me'] as const;
const PRESET: Record<'work' | 'personal', string[]> = {
  work: ['company', 'marketing', 'development', 'life'],
  personal: ['me', 'life', 'development'],
};

export function Login() {
  const provision = useYmir((s) => s.provision);
  const enterDemo = useYmir((s) => s.enterDemo);

  const [phase, setPhase] = useState<'signin' | 'provision'>('signin');
  const [identity, setIdentity] = useState<MockIdentity | null>(null);
  const [name, setName] = useState('Work');
  const [kind, setKind] = useState<'work' | 'personal'>('work');
  const [domains, setDomains] = useState<string[]>(PRESET.work);
  const [busy, setBusy] = useState(false);

  function choose(id: MockIdentity) {
    setIdentity(id);
    setPhase('provision');
  }

  function chooseKind(k: 'work' | 'personal') {
    setKind(k);
    setDomains(PRESET[k]);
  }

  function toggleDomain(d: string) {
    setDomains((cur) => (cur.includes(d) ? cur.filter((x) => x !== d) : [...cur, d]));
  }

  async function finish() {
    if (!identity || busy) return;
    setBusy(true);
    try {
      await gateApi.createWorkspace({ name, kind, domains }).catch(() => null);
      await gateApi.setupRun().catch(() => null);
    } finally {
      provision({ login: identity.login, name, kind, domains });
    }
  }

  return (
    <div className="login">
      <div className="login-card">
        <div className="login-brand">
          <img src="/ymir-mark.svg" alt="Ymir" className="brand-mark" width={44} height={44} />
          <div className="col">
            <span className="name">YMIR</span>
            <span className="sub">Hlidskjalf</span>
          </div>
        </div>

        {phase === 'signin' ? (
          <>
            <div>
              <h1 className="login-title">Sign in</h1>
              <p className="login-deck" style={{ marginTop: 6 }}>
                One operator, one Ymir. Sign in with the Allfather’s own GitHub login —
                a single tenant, many workspaces.
              </p>
            </div>

            <span className="mock-flag">Mock · Heimdall W0028 pending</span>

            <button className="gh-btn" onClick={() => choose(MOCK_IDENTITIES[0])}>
              <GitHubMark />
              Continue with GitHub
            </button>

            <div className="divider">or</div>

            <button
              className="btn"
              style={{ justifyContent: 'center', width: '100%' }}
              onClick={enterDemo}
              title="Explore Hlidskjalf with seeded data — no runtime required"
            >
              <span aria-hidden="true">ᛟ</span> Enter demo mode
            </button>

            <p className="legal">
              In production this is a GitHub App OAuth code flow → httpOnly JWT
              session. No secrets enter the client.
            </p>
          </>
        ) : (
          <>
            <div>
              <h1 className="login-title">Set up your workspace</h1>
              <p className="login-deck" style={{ marginTop: 6 }}>
                Carve a workspace: name it, choose personal or work, and pick the
                knowledge domains it covers. Ymir stands the full system up.
              </p>
            </div>

            <div className="stepper">
              <span className="on">01 authenticate</span>
              <span>→ 02 workspace</span>
              <span>→ 03 domains</span>
            </div>

            <label className="field">
              <span className="eyebrow">Workspace name</span>
              <input value={name} onChange={(e) => setName(e.target.value)} placeholder="Work" />
            </label>

            <div className="stream-tabs" role="group" aria-label="Workspace kind">
              {(['work', 'personal'] as const).map((k) => (
                <button key={k} className="stream-tab" aria-pressed={kind === k} onClick={() => chooseKind(k)}>
                  {k}
                </button>
              ))}
            </div>

            <div className="chips">
              {DOMAINS.map((d) => (
                <button key={d} className="chip" aria-pressed={domains.includes(d)} onClick={() => toggleDomain(d)}>
                  {domains.includes(d) ? '✓ ' : ''}
                  {DOMAIN_LABEL[d]}
                </button>
              ))}
            </div>

            <div className="wizard-path">
              workspace/{name.toLowerCase().replace(/[^a-z0-9-]+/g, '-') || 'workspace'}/
              <br />
              ├─ {domains.join(' · ') || '—'}
              <br />
              └─ memory/ · workspaces.yaml · projects.yaml
            </div>

            <div className="row">
              <button className="btn btn-primary grow" onClick={finish} disabled={busy} style={{ justifyContent: 'center' }}>
                <span aria-hidden="true">ᛉ</span> {busy ? 'Setting up Ymir…' : 'Set up & enter'}
              </button>
              <button className="btn" onClick={() => setPhase('signin')} disabled={busy}>
                Back
              </button>
            </div>
          </>
        )}
      </div>
    </div>
  );
}
