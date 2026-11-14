import { useEffect, useRef, useState, type CSSProperties } from 'react';
import { useYmir, type AgentsStatus } from '../state/store';
import { useUI } from '../state/ui';
import { useTenantDef } from '../hooks/useTenantDef';
import { DOMAINS, TERMINAL_STATES } from '../data/realms';
import type { AgentCard as AgentCardType, AgentStatus, A2AMessage } from '../types';
import { MetricTile } from '../components/MetricTile';
import { AgentCard } from '../components/AgentCard';
import { StatusChip } from '../components/Status';

/* ---- the fleet graph's geometry, in PIXELS -------------------------------- *
 * Until 2026-11-14 this layout placed nodes by PERCENTAGE inside a fixed 340px
 * box: thirty-six agents in five rows gave a ~31px row pitch, and every node was
 * a 46px ring — so each row was drawn on top of the one above it and the labels
 * were buried behind the next row's circles. That is the "the agents are
 * stacking, i dont see their names" the Allfather saw.
 *
 * A node now owns a cell strictly bigger than itself, so overlap is impossible at
 * any count, and the canvas grows (and scrolls) instead of squeezing.
 */
const NODE_W = 118;
const NODE_H = 88;
const GAP_X = 16;
const GAP_Y = 14;
const PAD = 10;

function layout(
  agents: AgentCardType[],
  avail = 0,
): {
  pos: Record<string, { x: number; y: number }>;
  edges: [string, string][];
  width: number;
  height: number;
} {
  // The hub is the hand that delegates, and it is only a hub if it is STANDING:
  // the helm first, then any living agent, then Brokk as the roster's own word.
  const isHelm = (a: AgentCardType) => /^(the helm|brokk)$/i.test(a.name || '');
  const hub =
    agents.find((a) => a.alive && isHelm(a)) ??
    agents.find((a) => a.alive) ??
    agents.find(isHelm) ??
    agents[0];
  const others = agents.filter((a) => a !== hub);
  // The fleet you HAVE first, then the roster you could raise: a dead node below a
  // live one never hides live work, and every name is still on the board.
  const ordered = [...others].sort((a, b) => Number(!!b.alive) - Number(!!a.alive));

  const n = ordered.length;
  // As many columns as the panel can hold at its measured width; a measured width of
  // 0 (first paint) falls back to a square-ish grid, then the observer corrects it.
  const fit = avail > 0 ? Math.floor((avail - PAD * 2 + GAP_X) / (NODE_W + GAP_X)) : Math.ceil(Math.sqrt(n + 1));
  const cols = Math.max(2, Math.min(Math.max(n + 1, 2), fit));
  const rows = Math.ceil(n / cols);
  const width = Math.max(PAD * 2 + cols * NODE_W + Math.max(cols - 1, 0) * GAP_X, PAD * 2 + NODE_W);
  const height = PAD * 2 + (rows + (hub ? 1 : 0)) * NODE_H + Math.max(rows, 0) * GAP_Y;

  const pos: Record<string, { x: number; y: number }> = {};
  if (hub) pos[hub.id] = { x: Math.round(width / 2), y: PAD + NODE_H / 2 };
  const gridW = cols * NODE_W + Math.max(cols - 1, 0) * GAP_X;
  const left0 = (width - gridW) / 2;
  const top0 = PAD + (hub ? NODE_H + GAP_Y : 0);
  ordered.forEach((a, i) => {
    const col = i % cols;
    const row = Math.floor(i / cols);
    pos[a.id] = {
      x: Math.round(left0 + col * (NODE_W + GAP_X) + NODE_W / 2),
      y: Math.round(top0 + row * (NODE_H + GAP_Y) + NODE_H / 2),
    };
  });

  // A delegation edge is a FACT about a living seat. Drawing one to an unseated
  // roster figure would be decoration pretending to be a hop, and it is what made
  // the old graph an unreadable hairball.
  const live = others.filter((o) => o.alive);
  const edges: [string, string][] = hub
    ? live.map((o) => [hub.id, o.id] as [string, string])
    : live.slice(1).map((o, i) => [live[i].id, o.id] as [string, string]);
  return { pos, edges, width, height };
}

/** The `from` field of a recorded message is a full origin; the road is the detail. */
function whoFrom(from: string): string {
  const head = (from || '').split(' · ')[0].trim();
  return head.replace(/^agent\s+/i, '') || 'unknown';
}

function clockOf(ts: string): string {
  const m = /T(\d{2}:\d{2})/.exec(ts || '');
  return m ? m[1] : '';
}

/** The one honest line for the board: an empty fleet has four causes, not one. */
function fleetNote(
  agentsStatus: AgentsStatus,
  count: number,
): { text: string; chip: AgentStatus; detail: string } {
  if (count > 0 && agentsStatus === 'live') {
    return { text: 'published', chip: 'nominal', detail: 'A2A 1.0 cards published.' };
  }
  switch (agentsStatus) {
    case 'unauthorized':
      return {
        text: 'gate unauthorised',
        chip: 'down',
        detail: 'The gate refused the request (401). Sign in, and the roster will load.',
      };
    case 'unreadable':
      return {
        text: 'roster unreadable',
        chip: 'down',
        detail: 'The connector answered with an error; the roster could not be read.',
      };
    case 'offline':
      return {
        text: 'gate offline',
        chip: 'down',
        detail: 'The gate API did not answer; showing the last good data.',
      };
    case 'live':
      return {
        text: 'no agents standing',
        chip: 'degraded',
        detail: 'The gate answered, and no agents are standing.',
      };
    default:
      return { text: 'reading the roster', chip: 'nominal', detail: 'Reading the roster...' };
  }
}

export function Fleet() {
  const agents = useYmir((s) => s.agents);
  const agentsStatus = useYmir((s) => s.agentsStatus);
  const a2a = useYmir((s) => s.a2a);
  const doors = useYmir((s) => s.doors);
  const tasks = useYmir((s) => s.tasks);
  const realm = useYmir((s) => s.realm);
  const session = useYmir((s) => s.session);
  const runes = useYmir((s) => s.runes);
  const integrity = runes.length ? runes.filter((r) => r.checksum).length / runes.length : null;
  const { openModal } = useUI();
  const def = useTenantDef(realm, session?.tenants.find((t) => t.realm === realm));
  const note = fleetNote(agentsStatus, agents.length);

  // NOMINAL is a fact about a pane, never a default: `alive` is the same truth.
  const alive = agents.filter((a) => a.alive || a.status === 'nominal').length;
  const working = agents.filter((a) => a.live?.state === 'working').length;
  const seated = agents.filter((a) => a.pane).length;
  const unseated = agents.length - seated;
  const active = tasks.filter((t) => !TERMINAL_STATES.includes(t.state)).length;
  // The graph is measured, never guessed: the panel's own width decides how many
  // columns fit, so a wide window shows the whole fleet in one screenful.
  const wrapRef = useRef<HTMLDivElement | null>(null);
  const [avail, setAvail] = useState(0);
  useEffect(() => {
    const el = wrapRef.current;
    if (!el) return;
    setAvail(el.clientWidth);
    const ro = new ResizeObserver((entries) => setAvail(entries[0]?.contentRect.width ?? 0));
    ro.observe(el);
    return () => ro.disconnect();
  }, []);
  const { pos, edges, width, height } = layout(agents, avail);

  function inspect(id: string) {
    const a = agents.find((x) => x.id === id);
    if (!a) return;
    const model = a.model
      ? `${a.model}${a.modelSource === 'configured' ? '  (configured — it is not launched)' : ''}`
      : 'unknown — no launch record and no config entry';
    const lines = [
      `status      ${a.status}${a.alive ? '  (alive)' : '  (no pane holds it)'}`,
      `state       ${a.state || '—'}`,
      `errand      ${a.errand || '—'}${a.errandClaim ? `  — ${a.errandClaim}` : ''}`,
      `harness     ${a.harness || '—'}`,
      `model       ${model}`,
      `pane        ${a.paneLabel || '—'}${a.pane ? `  (${a.pane})` : ''}`,
      `machine     ${a.machine || '—'}`,
      `seat        ${a.seat || '—'}`,
      `cwd         ${a.cwd || '—'}`,
      `interface   ${a.interface.protocol} · ${a.interface.endpoint || 'no endpoint'} · ${a.interface.signed ? 'signed' : 'no JWS'}`,
      `last word   ${a.lastMessage ? `${a.lastMessage}  (${a.lastMessageAt})` : '—'}`,
      `skills      ${a.capabilities?.length ? a.capabilities.join(', ') : '—'}`,
    ];
    openModal({
      variant: 'info',
      tone: a.status === 'nominal' ? 'ok' : a.status === 'degraded' ? 'warn' : 'danger',
      glyph: 'ᚠ',
      title: `${a.name} — Agent Card`,
      body: a.errandClaim || a.role,
      content: lines.join('\n'),
    });
  }

  return (
    <>
      <div className="stage-head">
        <div>
          <h1 className="stage-title">The Fleet</h1>
          <p className="stage-deck">
            {alive}/{agents.length} agents standing · {working} working · {def.tenant} · A2A 1.0 cards{' '}
            {note.text}
          </p>
        </div>
        <div className="row">
          <StatusChip status={note.chip} />
        </div>
      </div>

      <div className="metric-grid" style={{ marginBottom: 'var(--ymir-space-4)' }}>
        <MetricTile
          label="Agents standing"
          value={`${alive}/${agents.length}`}
          delta={`${unseated} not seated`}
        />
        <MetricTile label="Working now" value={working} delta={`${seated} in panes`} />
        <MetricTile label="Active tasks" value={active} delta={`${tasks.length} on the board`} />
        <MetricTile
          label="Ledger integrity"
          value={integrity != null ? integrity.toFixed(3) : '—'}
          delta={`${runes.length} runes`}
          tone="var(--ymir-ok)"
        />
      </div>

      {agents.length === 0 && (
        <section className="panel" style={{ marginBottom: 'var(--ymir-space-4)' }}>
          <div className="panel-body">
            <div className="row" style={{ alignItems: 'center', gap: 'var(--ymir-space-3)' }}>
              <StatusChip status={note.chip} />
              <span className="dim">{note.detail}</span>
            </div>
          </div>
        </section>
      )}

      <div className="gate-grid cols-2">
        <section className="panel span-2">
          <div className="panel-head">
            <div className="panel-title">
              <span className="glyph" aria-hidden="true">ᚠ</span>
              Fleet graph — Agent Cards & A2A hops
            </div>
            <span className="mono dim" style={{ fontSize: 10 }}>
              {alive} standing · hub = the helm · edges = delegation
            </span>
          </div>
          <div className="panel-body flush">
            <div className="fleet-graph" ref={wrapRef}>
              <div className="fleet-canvas" style={{ width, height }}>
                <svg className="fleet-edges" viewBox={`0 0 ${width} ${height}`} preserveAspectRatio="none">
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
                  const house = DOMAINS[a.domain] ?? DOMAINS.ymirlabs;
                  return (
                    <div
                      key={a.id}
                      className="fleet-node"
                      data-alive={a.alive ? 'yes' : 'no'}
                      style={
                        {
                          left: p.x,
                          top: p.y,
                          '--house': house.accent,
                        } as CSSProperties
                      }
                      title={[a.name, a.errand, a.paneLabel, a.state].filter(Boolean).join(' · ')}
                      onClick={() => inspect(a.id)}
                      role="button"
                      tabIndex={0}
                      onKeyDown={(e) => {
                        if (e.key === 'Enter' || e.key === ' ') inspect(a.id);
                      }}
                    >
                      <div className="node-ring" data-status={a.status} aria-hidden="true">
                        {house.glyph}
                      </div>
                      <span className="node-label">{a.name}</span>
                      <span className="node-state">
                        {a.errand || a.state || (a.alive ? 'alive' : 'not seated')}
                      </span>
                    </div>
                  );
                })}
              </div>
            </div>
          </div>
        </section>

        <section className="panel span-2">
          <div className="panel-head">
            <div className="panel-title">
              <span className="glyph" aria-hidden="true">ᛏ</span>
              A2A task stream — herdr traffic
            </div>
            <span className="mono dim" style={{ fontSize: 10 }}>
              {a2a.recorded} recorded
            </span>
          </div>
          <div className="panel-body flush">
            {a2a.messages.length === 0 ? (
              <div className="trace-row" style={{ gridTemplateColumns: '1fr' }}>
                <span className="event dim">
                  No message recorded yet. Every{' '}
                  <span className="mono">bin/agents/eindri-send.sh</span> writes one row here — who sent
                  it, to whom, and its first line.
                </span>
              </div>
            ) : (
              a2a.messages.slice(0, 8).map((m: A2AMessage, i: number) => (
                <div className="trace-row" key={`${m.ts}-${i}`} style={{ gridTemplateColumns: '1fr auto' }}>
                  <span className="event truncate" title={`${m.from} → ${m.to}\n${m.text}`}>
                    <span className="module mono">{whoFrom(m.from)}</span>
                    <span className="dim"> → </span>
                    <span className="mono">{m.to}</span>
                    <span className="dim"> · </span>
                    {m.text}
                  </span>
                  <span className="checksum" title={m.ts}>{clockOf(m.ts)}</span>
                </div>
              ))
            )}
            {tasks.length > 0 && (
              <>
                <div className="trace-row" style={{ gridTemplateColumns: '1fr' }}>
                  <span className="event dim mono" style={{ fontSize: 10 }}>
                    the tasks board — errands and forge orders
                  </span>
                </div>
                {tasks.slice(0, 4).map((t) => (
                  <div className="trace-row" key={t.id} style={{ gridTemplateColumns: '1fr auto' }}>
                    <span className="event truncate" title={`${t.agent} · ${t.order}`}>
                      <span className="module mono">{t.agent}</span> · {t.title}
                    </span>
                    <span className="checksum">{t.state}</span>
                  </div>
                ))}
              </>
            )}
          </div>
        </section>

        {/* THE DOORS (plan 275 item 19): every app's DevTools port and every agent's pane,
            so anything can be inspected without a restart. `up` is a probe, not a wish. */}
        <section className="panel span-2">
          <div className="panel-head">
            <div className="panel-title">
              <span className="glyph" aria-hidden="true">ᛞ</span>
              Doors — where each app and each agent is inspected
            </div>
            <span className="mono dim" style={{ fontSize: 10 }}>
              {doors.apps_up}/{doors.apps.length} app doors · {doors.agents_seated} agent doors
            </span>
          </div>
          <div className="panel-body flush">
            <div className="trace-row" style={{ gridTemplateColumns: '1fr' }}>
              <span className="event dim mono" style={{ fontSize: 10 }}>
                app DevTools (CDP) — fixed loopback port per app
              </span>
            </div>
            {doors.apps.map((d) => (
              <div className="trace-row" key={`app-${d.surface}`} style={{ gridTemplateColumns: '1fr auto' }}>
                <span className="event truncate" title={d.url || d.note}>
                  <span className="module mono">{d.surface}</span>
                  <span className="dim"> · </span>
                  <span className="mono">{d.port ? `127.0.0.1:${d.port}` : 'no port'}</span>
                  <span className="dim"> · {d.up ? 'answers CDP' : d.note || 'down'}</span>
                </span>
                <span className="checksum">{d.up ? 'up' : 'down'}</span>
              </div>
            ))}
            <div className="trace-row" style={{ gridTemplateColumns: '1fr' }}>
              <span className="event dim mono" style={{ fontSize: 10 }}>
                agent doors — herdr agent read &lt;pane&gt; (read, never steer)
              </span>
            </div>
            {doors.agents.length === 0 ? (
              <div className="trace-row" style={{ gridTemplateColumns: '1fr' }}>
                <span className="event dim">no pane holds an agent this second</span>
              </div>
            ) : (
              doors.agents.map((d) => (
                <div className="trace-row" key={`agent-${d.pane}`} style={{ gridTemplateColumns: '1fr auto' }}>
                  <span className="event truncate" title={d.label || d.name}>
                    <span className="module mono">{d.name || d.pane}</span>
                    <span className="dim"> · </span>
                    <span className="mono">{d.harness || 'agent'}</span>
                    {d.errand ? <span className="dim"> · {d.errand}</span> : null}
                  </span>
                  <span className="checksum mono" title={d.door}>
                    {d.pane}
                  </span>
                </div>
              ))
            )}
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
