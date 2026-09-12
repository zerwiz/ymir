import type { CSSProperties } from 'react';
import { useYmir } from '../state/store';
import { useUI } from '../state/ui';
import { useTenantDef } from '../hooks/useTenantDef';
import { DOMAINS, TERMINAL_STATES } from '../data/realms';
import type { AgentCard as AgentCardType } from '../types';
import { MetricTile } from '../components/MetricTile';
import { AgentCard } from '../components/AgentCard';
import { StatusChip } from '../components/Status';

/** Lay the real fleet out: the primary (Brokk) as the hub, everyone else fanned below. */
function layout(agents: AgentCardType[]): { pos: Record<string, { x: number; y: number }>; edges: [string, string][] } {
  const hub = agents.find((a) => a.id === 'brokk') ?? agents[0];
  const others = agents.filter((a) => a !== hub);
  const pos: Record<string, { x: number; y: number }> = {};
  if (hub) pos[hub.id] = { x: 50, y: 18 };
  const n = others.length;
  others.forEach((a, i) => {
    const x = n <= 1 ? 50 : 8 + (i / (n - 1)) * 84;
    const y = 62 + (i % 2 === 0 ? 0 : 14);
    pos[a.id] = { x, y };
  });
  const edges: [string, string][] = hub
    ? others.map((o) => [hub.id, o.id] as [string, string])
    : others.slice(1).map((o, i) => [others[i].id, o.id] as [string, string]);
  return { pos, edges };
}

export function Fleet() {
  const agents = useYmir((s) => s.agents);
  const tasks = useYmir((s) => s.tasks);
  const realm = useYmir((s) => s.realm);
  const session = useYmir((s) => s.session);
  const runes = useYmir((s) => s.runes);
  const integrity = runes.length ? runes.filter((r) => r.checksum).length / runes.length : null;
  const live = useYmir((s) => s.live);
  const { openModal } = useUI();
  const def = useTenantDef(realm, session?.tenants.find((t) => t.realm === realm));

  const online = agents.filter((a) => a.status === 'nominal').length;
  const active = tasks.filter((t) => !TERMINAL_STATES.includes(t.state)).length;
  const working = agents.filter((a) => a.status === 'degraded').length;
  const sealed = agents.filter((a) => a.status === 'down').length;
  const { pos, edges } = layout(agents);

  function inspect(id: string) {
    const a = agents.find((x) => x.id === id);
    if (!a) return;
    openModal({
      variant: 'info',
      tone: a.status === 'nominal' ? 'ok' : a.status === 'degraded' ? 'warn' : 'danger',
      glyph: 'ᚠ',
      title: `${a.name} — Agent Card`,
      body: a.role,
      content: JSON.stringify(
        {
          name: a.name,
          status: a.status,
          domain: a.domain,
          capabilities: a.capabilities,
          skills: a.skills,
          interface: a.interface,
          model: a.model,
          tasksDone: a.tasksDone,
          traceability: a.traceability,
        },
        null,
        2,
      ),
    });
  }

  return (
    <>
      <div className="stage-head">
        <div>
          <h1 className="stage-title">The Fleet</h1>
          <p className="stage-deck">
            {online}/{agents.length} agents nominal · {def.tenant} · A2A 1.0 cards {live === false ? '(gate API offline)' : 'published'}
          </p>
        </div>
        <div className="row">
          <StatusChip status={live === false ? 'degraded' : 'nominal'} />
        </div>
      </div>

      <div className="metric-grid" style={{ marginBottom: 'var(--ymir-space-4)' }}>
        <MetricTile label="Agents nominal" value={`${online}/${agents.length}`} delta={`${agents.length} registered`} />
        <MetricTile label="Active tasks" value={active} delta={`${tasks.length} forge orders`} />
        <MetricTile label="Ledger integrity" value={integrity != null ? integrity.toFixed(3) : '—'} delta={`${runes.length} runes`} tone="var(--ymir-ok)" />
        <MetricTile label="Utgard sealed" value={sealed} delta={`${working} degraded`} tone="var(--ymir-warn)" />
      </div>

      <div className="gate-grid cols-2">
        <section className="panel">
          <div className="panel-head">
            <div className="panel-title">
              <span className="glyph" aria-hidden="true">ᚠ</span>
              Fleet graph — Agent Cards & A2A hops
            </div>
            <span className="mono dim" style={{ fontSize: 10 }}>
              hub = Brokk · edges = delegation
            </span>
          </div>
          <div className="panel-body flush">
            <div className="fleet-graph">
              <svg className="fleet-edges" viewBox="0 0 100 100" preserveAspectRatio="none">
                {edges.map(([a, b]) => {
                  const A = pos[a];
                  const B = pos[b];
                  if (!A || !B) return null;
                  return (
                    <line
                      key={`${a}-${b}`}
                      className="fleet-edge"
                      x1={A.x}
                      y1={A.y}
                      x2={B.x}
                      y2={B.y}
                      vectorEffect="non-scaling-stroke"
                    />
                  );
                })}
              </svg>
              {agents.map((a) => {
                const p = pos[a.id];
                if (!p) return null;
                const house = DOMAINS[a.domain];
                return (
                  <div key={a.id} className="fleet-node" style={{ left: `${p.x}%`, top: `${p.y}%` }}>
                    <div
                      className="node-ring"
                      data-status={a.status}
                      style={{ '--house': house.accent } as CSSProperties}
                      aria-hidden="true"
                    >
                      {house.glyph}
                    </div>
                    <span className="node-label">{a.name}</span>
                  </div>
                );
              })}
            </div>
          </div>
        </section>

        <section className="panel">
          <div className="panel-head">
            <div className="panel-title">
              <span className="glyph" aria-hidden="true">ᛏ</span>
              A2A task stream
            </div>
          </div>
          <div className="panel-body flush">
            {tasks.slice(0, 6).map((t) => (
              <div className="trace-row" key={t.id} style={{ gridTemplateColumns: '1fr auto' }}>
                <span className="event truncate">
                  <span className="module mono">{t.agent}</span> · {t.title}
                </span>
                <span className="checksum">{t.state}</span>
              </div>
            ))}
          </div>
        </section>
      </div>

      <div className="gate-grid cols-3" style={{ marginTop: 'var(--ymir-space-4)' }}>
        {agents.map((a) => (
          <AgentCard key={a.id} agent={a} onSelect={inspect} />
        ))}
      </div>
    </>
  );
}
