import { useState } from 'react';
import { HOUSES } from '../data/realms';
import { MOCK_IDENTITIES, ROLE_LABEL, type MockIdentity } from '../services/auth';
import { useYmir } from '../state/store';
import type { HouseId } from '../types';

function GitHubMark({ size = 18 }: { size?: number }) {
  return (
    <svg width={size} height={size} viewBox="0 0 16 16" fill="currentColor" aria-hidden="true">
      <path d="M8 0C3.58 0 0 3.58 0 8c0 3.54 2.29 6.53 5.47 7.59.4.07.55-.17.55-.38 0-.19-.01-.82-.01-1.49-2.01.37-2.53-.49-2.69-.94-.09-.23-.48-.94-.82-1.13-.28-.15-.68-.52-.01-.53.63-.01 1.08.58 1.23.82.72 1.21 1.87.87 2.33.66.07-.52.28-.87.51-1.07-1.78-.2-3.64-.89-3.64-3.95 0-.87.31-1.59.82-2.15-.08-.2-.36-1.02.08-2.12 0 0 .67-.21 2.2.82.64-.18 1.32-.27 2-.27.68 0 1.36.09 2 .27 1.53-1.04 2.2-.82 2.2-.82.44 1.1.16 1.92.08 2.12.51.56.82 1.27.82 2.15 0 3.07-1.87 3.75-3.65 3.95.29.25.54.73.54 1.48 0 1.07-.01 1.93-.01 2.2 0 .21.15.46.55.38A8.01 8.01 0 0 0 16 8c0-4.42-3.58-8-8-8Z" />
    </svg>
  );
}

export function Login() {
  const signIn = useYmir((s) => s.signIn);
  const provision = useYmir((s) => s.provision);
  const enterDemo = useYmir((s) => s.enterDemo);

  const [phase, setPhase] = useState<'signin' | 'provision'>('signin');
  const [identity, setIdentity] = useState<MockIdentity | null>(null);
  const [house, setHouse] = useState<HouseId>('ymirlabs');
  const [cloneRepos, setCloneRepos] = useState(true);

  function choose(id: MockIdentity) {
    if (id.firstRun || id.tenants.length === 0) {
      setIdentity(id);
      setPhase('provision');
      return;
    }
    signIn(id);
  }

  function finish() {
    if (!identity) return;
    provision({ login: identity.login, name: identity.name, house, cloneRepos });
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
                The gate opens with GitHub. Every realm is scoped to your grants —
                boundaries are sacred.
              </p>
            </div>

            <span className="mock-flag">Mock · Heimdall W0028 pending</span>

            <button className="gh-btn" onClick={() => choose(MOCK_IDENTITIES[0])}>
              <GitHubMark />
              Continue with GitHub
            </button>

            <div className="divider">or choose an identity</div>

            <button
              className="btn"
              style={{ justifyContent: 'center', width: '100%' }}
              onClick={enterDemo}
              title="Explore Hlidskjalf with seeded data — no runtime required"
            >
              <span aria-hidden="true">ᛟ</span> Enter demo mode
            </button>

            <div className="identity-list">
              {MOCK_IDENTITIES.map((id) => (
                <button key={id.login} className="identity" onClick={() => choose(id)}>
                  <span className="gh-avatar">{id.login.slice(0, 2).toUpperCase()}</span>
                  <span className="who">
                    <div className="gh-login">{id.login}</div>
                    <div className="meta">
                      {id.firstRun
                        ? 'first login — workspace will be provisioned'
                        : id.tenants
                            .map((t) => `${t.tenant} · ${ROLE_LABEL[t.role]}`)
                            .join('  ·  ')}
                    </div>
                  </span>
                  <span className="arrow" aria-hidden="true">
                    →
                  </span>
                </button>
              ))}
            </div>

            <p className="legal">
              In production this is a GitHub App OAuth code flow → httpOnly JWT
              session, tenant mapping, and JWS-signed Agent Cards. No secrets enter
              the client.
            </p>
          </>
        ) : (
          <>
            <div>
              <h1 className="login-title">Provision your workspace</h1>
              <p className="login-deck" style={{ marginTop: 6 }}>
                First login. Choose the house you forge for; Ymir carves an isolated
                realm under <span className="mono">svartalfaheim/</span>.
              </p>
            </div>

            <div className="stepper">
              <span className="on">01 authenticate</span>
              <span>→ 02 house</span>
              <span>→ 03 repos</span>
            </div>

            <div className="house-grid" role="group" aria-label="House">
              {Object.values(HOUSES).map((h) => (
                <button
                  key={h.id}
                  className="house-opt"
                  aria-pressed={house === h.id}
                  onClick={() => setHouse(h.id)}
                >
                  <span className="seal" style={{ color: h.accent }} aria-hidden="true">
                    {h.glyph}
                  </span>
                  {h.name}
                </button>
              ))}
            </div>

            <div className="stack-options">
              <button
                className="opt"
                aria-pressed={cloneRepos}
                onClick={() => setCloneRepos((v) => !v)}
              >
                <span className="box" aria-hidden="true">{cloneRepos ? '✓' : ''}</span>
                Clone the GitHub App installation repos into the realm
              </button>
            </div>

            <div className="wizard-path">
              {`svartalfaheim/${identity?.login ?? 'login'}/`}
              <br />
              ├─ companies/ · projects/ · workspace/
              <br />
              ├─ workspace/{'{company,marketing,development,life,memory/daily}'}
              <br />
              └─ .env.realm · Brokk.md · .well-known/agent-card.json
            </div>

            <div className="row">
              <button className="btn btn-primary grow" onClick={finish} style={{ justifyContent: 'center' }}>
                <span aria-hidden="true">ᛉ</span> Provision & enter
              </button>
              <button className="btn" onClick={() => setPhase('signin')}>
                Back
              </button>
            </div>
          </>
        )}
      </div>
    </div>
  );
}
