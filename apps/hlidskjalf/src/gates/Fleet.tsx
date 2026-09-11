import type { CSSProperties } from 'react';
import { useYmir } from '../state/store';
import { useUI } from '../state/ui';
import { useTenantDef } from '../hooks/useTenantDef';
import { HOUSES, TERMINAL_STATES } from '../data/realms';
import { MetricTile } from '../components/MetricTile';
import { AgentCard } from '../components/AgentCard';
import { StatusChip } from '../components/Status';

const POS: Record<string, { x: number; y: number }> = {
  brokk: { x: 50, y: 24 },
  kaia: { x: 50, y: 62 },
  'eindri-01': { x: 16, y: 82 },
  'eindri-02': { x: 39, y: 90 },
  'eindri-03': { x: 62, y: 90 },
  'eindri-04': { x: 85, y: 82 },
};

const EDGES: [string, string][] = [
  ['brokk', 'kaia'],
  ['kaia', 'eindri-01'],
  ['kaia', 'eindri-02'],
  ['kaia', 'eindri-03'],
  ['kaia', 'eindri-04'],
];

export function Fleet() {
  const agents = useYmir((s) => s.agents);
  const tasks = useYmir((s) => s.tasks);
  const realm = useYmir((s) => s.realm);
  const session = useYmir((s) => s.session);
  const trace = useYmir((s) => s.traceability);
  const { openModal } = useUI();
  const def = useTenantDef(realm, session?.tenants.find((t) => t.realm === realm));

  const online = agents.filter((a) => a.status === 'nominal').length;
  const active = tasks.filter((t) => !TERMINAL_STATES.includes(t.state)).length;
  const working = agents.filter((a) => a.status === 'degraded').length;

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
          house: a.house,
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
            {online}/{agents.length} agents nominal · {def.tenant} · A2A 1.0 cards published
          </p>
        </div>
        <div className="row">
          <StatusChip status="nominal" />
        </div>
      </div>

      <div className="metric-grid" style={{ marginBottom: 'var(--ymir-space-4)' }}>
        <MetricTile label="Agents nominal" value={`${online}/${agents.length}`} delta="+2 this hour" spark={[3, 3, 4, 4, 5, 5, online]} />
        <MetricTile label="Active tasks" value={active} delta={`${tasks.length} total`} spark={[2, 4, 3, 6, 5, 7, active]} />
        <MetricTile label="Traceability" value={trace.toFixed(3)} delta="target 0.984" tone="var(--ymir-ok)" spark={[0.97, 0.975, 0.98, 0.982, 0.981, trace]} />
        <MetricTile label="Utgard workers" value={working} delta={`${agents.filter((a) => a.status === 'down').length} sealed`} tone="var(--ymir-warn)" spark={[1, 2, 2, 3, 2, working]} />
      </div>

      <div className="gate-grid cols-2">
        <section className="panel">
          <div className="panel-head">
            <div className="panel-title">
              <span className="glyph" aria-hidden="true">ᚠ</span>
              Fleet graph — Agent Cards & A2A hops
            </div>
            <span className="mono dim" style={{ fontSize: 10 }}>
              edges animate on activity
            </span>
          </div>
          <div className="panel-body flush">
            <div className="fleet-graph">
              <svg className="fleet-edges" viewBox="0 0 100 100" preserveAspectRatio="none">
                {EDGES.map(([a, b]) => {
                  const A = POS[a];
                  const B = POS[b];
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
                const p = POS[a.id];
                if (!p) return null;
                const house = HOUSES[a.house];
                return (
                  <div
                    key={a.id}
                    className="fleet-node"
                    style={{ left: `${p.x}%`, top: `${p.y}%` }}
                  >
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
