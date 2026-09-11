import { useYmir } from '../state/store';
import { GATES, TERMINAL_STATES } from '../data/realms';
import { ROLE_LABEL } from '../services/auth';
import { StatusChip } from '../components/Status';
import type { GateId } from '../types';

function gateCount(id: GateId, s: ReturnType<typeof useYmir.getState>): number | undefined {
  switch (id) {
    case 'fleet':
      return s.agents.length;
    case 'tasks':
      return s.tasks.filter((t) => !TERMINAL_STATES.includes(t.state)).length;
    case 'well':
      return s.recall.length;
    case 'runes':
      return s.runes.length;
    case 'reviews':
      return s.reviews.length;
    case 'processes':
      return s.processes.length;
    case 'files':
      return 0;
    case 'chat':
      return s.chat.length;
    case 'forge':
      return s.agents.length + s.skills.length;
    default:
      return undefined;
  }
}

export function Rail() {
  const state = useYmir();
  const setGate = useYmir((s) => s.setGate);
  const setRealm = useYmir((s) => s.setRealm);
  const tenantColors = useYmir((s) => s.tenantColors);
  const tenants = state.session?.tenants ?? [];

  return (
    <aside className="rail" aria-label="Hlidskjalf navigation">
      <div className="brand">
        <img src="/ymir-mark.svg" alt="" className="brand-mark" width={34} height={34} />
        <div className="wordmark">
          <span className="wordmark-name">YMIR</span>
          <span className="wordmark-sub">Hlidskjalf</span>
        </div>
      </div>

      <nav className="nav" aria-label="Gates">
        {GATES.map((g) => {
          const count = gateCount(g.id, state);
          return (
            <button
              key={g.id}
              className="gate"
              aria-current={state.gate === g.id}
              onClick={() => setGate(g.id)}
              title={g.hint}
            >
              <span className="gate-glyph" aria-hidden="true">
                {g.glyph}
              </span>
              <span className="gate-label">{g.label}</span>
              {count ? <span className="gate-count">{count}</span> : null}
            </button>
          );
        })}
      </nav>

      <div className="rail-foot">
        <div className="realm-switch" role="group" aria-label="Tenant">
          <span className="eyebrow" style={{ paddingLeft: 8 }}>
            Tenants · {tenants.length}
          </span>
          {tenants.map((t) => {
            const tint = tenantColors[t.realm] ?? t.tint;
            return (
              <button
                key={t.realm}
                className="realm-opt"
                aria-current={state.realm === t.realm}
                onClick={() => setRealm(t.realm)}
                title={`${t.tenant} · ${ROLE_LABEL[t.role]}`}
              >
                <span className="realm-swatch" style={{ background: tint }} />
                <span className="label grow truncate">{t.tenant}</span>
                <span
                  className="mono dim"
                  style={{ fontSize: 9, textTransform: 'uppercase', letterSpacing: '0.06em' }}
                >
                  {ROLE_LABEL[t.role]}
                </span>
              </button>
            );
          })}
        </div>

        <div className="rail-node">
          <span className="live-dot" aria-hidden="true" />
          <span>Valhalla</span>
          <StatusChip status="nominal" />
        </div>
      </div>
    </aside>
  );
}
